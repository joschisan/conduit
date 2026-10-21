use std::collections::BTreeMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex as StdMutex};

use crate::account::Account;
use crate::client::ConduitClient;
use crate::db::{
    ClientConfigKey, ClientConfigPrefix, ContactKey, ContactPrefix, DbKeyPrefix,
    EventLogEntryPrefix, RootEntropyKey, SelectedAccountKey, SelectedCurrencyKey,
};
use crate::exchange::ExchangeRateCache;
use crate::frb_generated::StreamSink;
use crate::lnurl::LnurlWrapper;
use crate::{DatabaseWrapper, InviteCodeWrapper, MnemonicWrapper};
use fedimint_bip39::Bip39RootSecretStrategy;
use fedimint_client::meta::MetaService;
use fedimint_client::module_init::ClientModuleInitRegistry;
use fedimint_client::secret::RootSecretStrategy;
use fedimint_client::{Client, ClientBuilder, ClientHandleArc, ModuleKind, RootSecret};
use fedimint_client_module::meta::LegacyMetaSource;
use fedimint_connectors::ConnectorRegistry;
use fedimint_core::BitcoinHash;
use fedimint_core::config::{ClientConfig, FederationId};
use fedimint_core::db::{Database, IDatabaseTransactionOpsCore, IDatabaseTransactionOpsCoreTyped};
use fedimint_lnv2_client::LightningClientInit;
use fedimint_lnv2_client::common::KIND as LIGHTNING_KIND;
use fedimint_meta_client::{MetaClientInit, MetaModuleMetaSourceWithFallback};
use fedimint_mint_client::{KIND as MINT_KIND, MintClientInit};
use fedimint_mintv2_client::MintClientInit as MintV2ClientInit;
use fedimint_mintv2_client::common::KIND as MINTV2_KIND;
use fedimint_wallet_client::{KIND as WALLET_KIND, WalletClientInit};
use fedimint_walletv2_client::WalletClientInit as WalletV2ClientInit;
use fedimint_walletv2_client::common::KIND as WALLETV2_KIND;
use flutter_rust_bridge::frb;
use futures_util::StreamExt;
use tokio::sync::{Mutex, Notify};

/// Every open client, one per `(federation, account)` of every added mint,
/// ordered mint-major and account-minor — the order the home pager swipes in.
/// The five of a mint are views onto the mint's one fedimint client, which
/// holds every account's balance itself.
type Clients = BTreeMap<(FederationId, Account), ConduitClient>;

#[frb]
pub struct ConduitClientFactory {
    db: Database,
    mnemonic: fedimint_bip39::Mnemonic,
    // Bound once and shared (cheaply cloned) across every client, so every
    // mint reuses the same endpoints instead of each binding an iroh endpoint
    // of its own.
    connectors: ConnectorRegistry,
    /// Every client stays open for as long as its mint is added, so a
    /// balance is always live and switching accounts is a change of view
    /// rather than a teardown. Never held across an await.
    clients: Arc<StdMutex<Clients>>,
    /// Wakes anyone iterating the client set when membership changes.
    /// `notify_waiters` is fire-and-forget; subscribers re-snapshot the set
    /// after waking.
    set_changed: Arc<Notify>,
    /// The currency is one setting for the wallet, and the BTC price it
    /// prices with is global, so one of each is shared by every client.
    currency_code: Arc<StdMutex<String>>,
    exchange_rate_cache: ExchangeRateCache,
}

#[frb]
pub struct FederationInfo {
    pub id: FederationId,
    pub name: String,
    pub guardians: u32,
}

impl FederationInfo {
    pub(crate) fn new(id: FederationId, config: ClientConfig) -> Self {
        let name = config
            .global
            .federation_name()
            .map(|name| name.to_string())
            .unwrap_or(id.to_prefix().to_string());

        let guardians = config.global.api_endpoints.len() as u32;

        Self {
            id,
            name,
            guardians,
        }
    }
}

#[frb(opaque)]
pub struct ConduitContact {
    lnurl: LnurlWrapper,
    name: String,
}

fn contains(haystack: &str, needle: &str) -> bool {
    haystack.to_lowercase().contains(&needle.to_lowercase())
}

impl ConduitContact {
    #[frb(sync, getter)]
    pub fn name(&self) -> String {
        self.name.clone()
    }

    #[frb(sync, getter)]
    pub fn lnurl(&self) -> LnurlWrapper {
        LnurlWrapper(self.lnurl.0.clone())
    }

    #[frb(sync)]
    pub fn match_query(&self, query: &str) -> bool {
        contains(&self.name, query) || contains(&self.lnurl.0, query)
    }
}

fn ensure_one_of(config: &ClientConfig, a: &ModuleKind, b: &ModuleKind) -> Result<(), String> {
    let has_a = config.modules.values().any(|m| m.kind() == a);
    let has_b = config.modules.values().any(|m| m.kind() == b);
    match (has_a, has_b) {
        (true, false) | (false, true) => Ok(()),
        (true, true) => Err(format!("Both {a} and {b} present")),
        (false, false) => Err(format!("Neither {a} nor {b} present")),
    }
}

fn ensure_module(config: &ClientConfig, kind: &ModuleKind) -> Result<(), String> {
    match config.modules.values().any(|module| module.kind() == kind) {
        true => Ok(()),
        false => Err(format!("Module {} is not present", kind)),
    }
}

fn ensure_supported(config: &ClientConfig) -> Result<(), String> {
    ensure_module(config, &LIGHTNING_KIND)?;
    ensure_one_of(config, &MINT_KIND, &MINTV2_KIND)?;
    ensure_one_of(config, &WALLET_KIND, &WALLETV2_KIND)
}

impl ConduitClientFactory {
    #[frb]
    pub async fn init(db: &DatabaseWrapper, mnemonic: &MnemonicWrapper) -> Result<Self, String> {
        let mut dbtx = db.0.begin_transaction().await;

        dbtx.insert_new_entry(&RootEntropyKey, &mnemonic.0.to_entropy())
            .await;

        dbtx.commit_tx_result().await.map_err(|e| e.to_string())?;

        Ok(Self::new(db.0.clone(), mnemonic.0.clone()).await)
    }

    #[frb]
    pub async fn try_load(db: &DatabaseWrapper) -> Option<Self> {
        let entropy =
            db.0.begin_transaction_nc()
                .await
                .get_value(&RootEntropyKey)
                .await?;

        let mnemonic = fedimint_bip39::Mnemonic::from_entropy(&entropy).unwrap();

        Some(Self::new(db.0.clone(), mnemonic).await)
    }

    async fn new(db: Database, mnemonic: fedimint_bip39::Mnemonic) -> Self {
        let currency_code = db
            .begin_transaction_nc()
            .await
            .get_value(&SelectedCurrencyKey)
            .await
            .unwrap_or_else(|| "USD".to_string());

        Self {
            db,
            mnemonic,
            connectors: Self::build_connectors().await,
            clients: Arc::new(StdMutex::new(BTreeMap::new())),
            set_changed: Arc::new(Notify::new()),
            currency_code: Arc::new(StdMutex::new(currency_code)),
            exchange_rate_cache: Arc::new(Mutex::new(None)),
        }
    }

    #[frb]
    pub async fn seed_phrase(&self) -> Vec<String> {
        self.mnemonic.words().map(|s| s.to_string()).collect()
    }

    async fn client_builder(&self) -> ClientBuilder {
        let mut modules = ClientModuleInitRegistry::new();

        modules.attach(MintClientInit);
        modules.attach(MintV2ClientInit);
        modules.attach(LightningClientInit::default());
        modules.attach(WalletClientInit::default());
        modules.attach(WalletV2ClientInit);
        modules.attach(MetaClientInit);

        let meta_source: MetaModuleMetaSourceWithFallback<LegacyMetaSource> = Default::default();
        let meta_service = MetaService::new(meta_source);

        let mut client_builder = Client::builder()
            .await
            .expect("Failed to create client builder");

        client_builder.with_module_inits(modules);
        client_builder.with_meta_service(meta_service);

        client_builder
    }

    /// Fedimint's standard per-federation secret. Primary derives from it
    /// exactly where the wallet did before accounts, so an existing balance
    /// opens as Primary unchanged; the other accounts branch off below the
    /// module secrets inside fedimint.
    fn root_secret(&self) -> RootSecret {
        RootSecret::StandardDoubleDerive(Bip39RootSecretStrategy::<12>::to_root_secret(
            &self.mnemonic,
        ))
    }

    fn client_database(&self, federation_id: FederationId) -> Database {
        self.db.with_prefix(self.client_prefix(federation_id))
    }

    fn client_prefix(&self, federation_id: FederationId) -> Vec<u8> {
        std::iter::once(DbKeyPrefix::ClientDatabase as u8)
            .chain(federation_id.0.to_byte_array())
            .collect()
    }

    /// Builds and binds the connector registry. Called once per factory; the
    /// resulting registry is then shared across all clients.
    async fn build_connectors() -> ConnectorRegistry {
        ConnectorRegistry::build_from_client_defaults()
            .bind()
            .await
            .expect("Failed to bind connector registry")
    }

    fn connectors(&self) -> ConnectorRegistry {
        self.connectors.clone()
    }

    fn has_federation(&self, federation_id: FederationId) -> bool {
        self.clients
            .lock()
            .unwrap()
            .contains_key(&(federation_id, Account::Primary))
    }

    /// Adds a mint: one client, which carries every account from the moment
    /// it is built, since accounts are a split of the mint's seed rather
    /// than something added one by one.
    #[frb]
    pub async fn join(&self, invite: &InviteCodeWrapper) -> Result<(), String> {
        let federation_id = invite.0.federation_id();

        if self.has_federation(federation_id) {
            return Err("This mint is already added".to_string());
        }

        let preview = self
            .client_builder()
            .await
            .preview(self.connectors(), &invite.0)
            .await
            .map_err(|e| e.to_string())?;

        let config = preview.config().clone();

        ensure_supported(&config)?;

        let client = preview
            .join(self.client_database(federation_id), self.root_secret())
            .await
            .map_err(|e| e.to_string())?;

        self.save_config(&config).await;
        self.insert_clients(self.views(Arc::new(client), federation_id).await);

        Ok(())
    }

    /// Adds a mint this seed has used before. One recovery finds the funds
    /// of every account: fedimint scans with one filter and only tries the
    /// handful of outputs that pass it against each account's keys, so a
    /// restore costs what a single-account restore did.
    ///
    /// The recovery itself runs on in the background: the clients come back
    /// with `has_pending_recoveries` set, and the home screen shows its
    /// progress.
    #[frb]
    pub async fn recover(&self, invite: &InviteCodeWrapper) -> Result<(), String> {
        let federation_id = invite.0.federation_id();

        if self.has_federation(federation_id) {
            return Err("This mint is already added".to_string());
        }

        let preview = self
            .client_builder()
            .await
            .preview(self.connectors(), &invite.0)
            .await
            .map_err(|e| e.to_string())?;

        let config = preview.config().clone();

        ensure_supported(&config)?;

        let client = preview
            .recover(
                self.client_database(federation_id),
                self.root_secret(),
                None,
            )
            .await
            .map_err(|e| e.to_string())?;

        self.save_config(&config).await;
        self.insert_clients(self.views(Arc::new(client), federation_id).await);

        Ok(())
    }

    /// Opens every added mint. Called once at startup, so the wallet starts
    /// with every balance live. A mint whose client database is missing is
    /// left listed and skipped; its config is still there to retry from.
    #[frb]
    pub async fn load_all(&self) -> Vec<ConduitClient> {
        for federation in self.list_federations().await {
            if self.has_federation(federation.id) {
                continue;
            }

            if let Some(clients) = self.open(federation.id).await {
                self.insert_clients(clients);
            }
        }

        self.clients()
    }

    /// Opens a mint's client from its database, as every account's view, or
    /// `None` when the mint has no client on this device.
    async fn open(&self, federation_id: FederationId) -> Option<Vec<ConduitClient>> {
        if !Client::is_initialized(&self.client_database(federation_id)).await {
            return None;
        }

        let client = self
            .client_builder()
            .await
            .open(
                self.connectors(),
                self.client_database(federation_id),
                self.root_secret(),
            )
            .await
            .expect("Failed to open client");

        Some(self.views(Arc::new(client), federation_id).await)
    }

    /// Every account's view onto one mint's client, in account order.
    async fn views(
        &self,
        client: ClientHandleArc,
        federation_id: FederationId,
    ) -> Vec<ConduitClient> {
        let mut views = Vec::with_capacity(Account::ALL.len());

        for account in Account::ALL {
            views.push(
                self.create_client(client.clone(), federation_id, account)
                    .await,
            );
        }

        views
    }

    /// The views of a mint's client, in account order, as the pager holds
    /// them.
    fn views_of(&self, federation_id: FederationId) -> Vec<ConduitClient> {
        self.clients
            .lock()
            .unwrap()
            .range((federation_id, Account::Primary)..=(federation_id, Account::Quinary))
            .map(|(_, client)| client.clone())
            .collect()
    }

    /// Reopens a mint once its recovery is done — a module that could not
    /// run mid-recovery only joins the registry on the next open. The new
    /// views replace the old in place, and the set change tells the home
    /// screen to pick them up.
    #[frb]
    pub async fn reload(&self, federation_id: &FederationId) {
        // The views share one client, so it is shut down once.
        if let Some(client) = self.views_of(*federation_id).first() {
            client.shutdown().await;
        }

        if let Some(clients) = self.open(*federation_id).await {
            self.insert_clients(clients);
        }
    }

    /// Remembers the account in view, so the next launch opens on it.
    #[frb]
    pub async fn set_selected(&self, federation_id: &FederationId, account: Account) {
        let mut dbtx = self.db.begin_transaction().await;

        dbtx.insert_entry(&SelectedAccountKey, &(*federation_id, account))
            .await;

        dbtx.commit_tx().await;
    }

    /// The client the wallet was last left on, if it is still open. `None`
    /// when nothing is stored yet or the mint is no longer added; the home
    /// screen then opens on its first page.
    #[frb]
    pub async fn selected_client(&self) -> Option<ConduitClient> {
        let key = self
            .db
            .begin_transaction_nc()
            .await
            .get_value(&SelectedAccountKey)
            .await?;

        self.clients.lock().unwrap().get(&key).cloned()
    }

    /// Every open client, mint-major and account-minor.
    #[frb(sync)]
    pub fn clients(&self) -> Vec<ConduitClient> {
        self.clients.lock().unwrap().values().cloned().collect()
    }

    /// Live snapshot of every open client; re-emits on every set change
    /// (join, recover, reload, leave). Subscribers re-render passively
    /// instead of re-fetching `clients()` after each navigation pop.
    #[frb]
    pub async fn subscribe_clients(&self, sink: StreamSink<Vec<ConduitClient>>) {
        loop {
            let snapshot = self.clients();
            let set_changed = self.set_changed.notified();
            tokio::pin!(set_changed);
            if sink.add(snapshot).is_err() {
                return;
            }
            set_changed.await;
        }
    }

    fn insert_clients(&self, clients: Vec<ConduitClient>) {
        let mut map = self.clients.lock().unwrap();

        for client in clients {
            map.insert((client.federation_id, client.account), client);
        }

        drop(map);

        self.set_changed.notify_waiters();
    }

    async fn save_config(&self, config: &ClientConfig) {
        let mut dbtx = self.db.begin_transaction().await;

        dbtx.insert_entry(&ClientConfigKey(config.calculate_federation_id()), config)
            .await;

        dbtx.commit_tx().await;
    }

    async fn create_client(
        &self,
        client: ClientHandleArc,
        federation_id: FederationId,
        account: Account,
    ) -> ConduitClient {
        static NEXT_INSTANCE: AtomicU64 = AtomicU64::new(0);

        ConduitClient {
            name: FederationInfo::new(federation_id, client.config().await).name,
            instance_id: NEXT_INSTANCE.fetch_add(1, Ordering::Relaxed),
            client,
            db: self.db.clone(),
            federation_id,
            account,
            currency_code: self.currency_code.clone(),
            exchange_rate_cache: self.exchange_rate_cache.clone(),
        }
    }

    #[frb]
    pub async fn list_federations(&self) -> Vec<FederationInfo> {
        self.db
            .begin_transaction_nc()
            .await
            .find_by_prefix(&ClientConfigPrefix)
            .await
            .map(|(key, value)| FederationInfo::new(key.0, value))
            .collect()
            .await
    }

    /// Switches the wallet's currency: persisted, applied to every open
    /// client through the shared setting, and the cached rate dropped so the
    /// next fetch is for the new currency.
    #[frb]
    pub async fn set_currency(&self, currency_code: &str) {
        let mut dbtx = self.db.begin_transaction().await;

        dbtx.insert_entry(&SelectedCurrencyKey, &currency_code.to_string())
            .await;

        dbtx.commit_tx().await;

        *self.currency_code.lock().unwrap() = currency_code.to_string();
        *self.exchange_rate_cache.lock().await = None;
    }

    #[frb(sync)]
    pub fn get_currency(&self) -> String {
        self.currency_code.lock().unwrap().clone()
    }

    /// Removes a mint: every account goes with it, since they live in the
    /// one client. It is shut down before its database is wiped so nothing
    /// reads storage out from under itself.
    #[frb]
    pub async fn leave(&self, federation_id: &FederationId) {
        let removed: Vec<ConduitClient> = {
            let mut map = self.clients.lock().unwrap();
            let keys: Vec<_> = map
                .range((*federation_id, Account::Primary)..=(*federation_id, Account::Quinary))
                .map(|(key, _)| *key)
                .collect();
            keys.into_iter()
                .filter_map(|key| map.remove(&key))
                .collect()
        };

        // The views share one client, so it is shut down once.
        if let Some(client) = removed.first() {
            client.shutdown().await;
        }

        let mut dbtx = self.db.begin_transaction().await;

        dbtx.remove_entry(&ClientConfigKey(*federation_id)).await;

        dbtx.remove_by_prefix(&EventLogEntryPrefix(*federation_id))
            .await;

        dbtx.raw_remove_by_prefix(&self.client_prefix(*federation_id))
            .await
            .expect("unrecoverable error when removing client db");

        dbtx.commit_tx().await;

        self.set_changed.notify_waiters();
    }

    #[frb]
    pub async fn save_contact(&self, lnurl: &LnurlWrapper, name: &str) {
        let mut dbtx = self.db.begin_transaction().await;

        dbtx.insert_entry(&ContactKey(lnurl.0.clone()), &name.to_string())
            .await;

        dbtx.commit_tx().await;
    }

    #[frb]
    pub async fn get_contact_name(&self, lnurl: &LnurlWrapper) -> Option<String> {
        self.db
            .begin_transaction_nc()
            .await
            .get_value(&ContactKey(lnurl.0.clone()))
            .await
    }

    #[frb]
    pub async fn list_contacts(&self) -> Vec<ConduitContact> {
        let mut contacts: Vec<_> = self
            .db
            .begin_transaction_nc()
            .await
            .find_by_prefix(&ContactPrefix)
            .await
            .map(|(key, name)| ConduitContact {
                lnurl: LnurlWrapper(key.0),
                name,
            })
            .collect()
            .await;

        contacts.sort_by_key(|c| c.name.to_lowercase());

        contacts
    }

    #[frb]
    pub async fn delete_contact(&self, lnurl: &LnurlWrapper) {
        let mut dbtx = self.db.begin_transaction().await;

        dbtx.remove_entry(&ContactKey(lnurl.0.clone())).await;

        dbtx.commit_tx().await;
    }
}
