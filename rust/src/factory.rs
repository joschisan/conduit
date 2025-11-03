use std::sync::Arc;

use fedimint_bip39::Bip39RootSecretStrategy;
use fedimint_client::module_init::ClientModuleInitRegistry;
use fedimint_client::secret::RootSecretStrategy;
use fedimint_client::{Client, ClientBuilder, ClientHandleArc, ModuleKind, RootSecret};
use fedimint_connectors::ConnectorRegistry;
use fedimint_core::base32::{encode_prefixed, FEDIMINT_PREFIX};
use fedimint_core::config::{ClientConfig, FederationId};
use fedimint_core::db::{Database, IDatabaseTransactionOpsCore, IDatabaseTransactionOpsCoreTyped};
use fedimint_core::invite_code::InviteCode;
use fedimint_core::BitcoinHash;
use fedimint_lnv2_client::LightningClientInit;
use fedimint_lnv2_common::KIND as LIGHTNING_KIND;
use fedimint_mint_client::{MintClientInit, KIND as MINT_KIND};
use fedimint_wallet_client::{WalletClientInit, KIND as WALLET_KIND};
use flutter_rust_bridge::frb;
use futures_util::StreamExt;
use tokio::sync::Mutex;

use crate::client::ConduitClient;
use crate::db::{
    ClientConfigKey, ClientConfigPrefix, ContactKey, ContactPrefix, DbKeyPrefix,
    EventLogEntryPrefix, RootEntropyKey, SelectedCurrencyKey, SelectedFederationKey,
};
use crate::lnurl::LnurlWrapper;
use crate::{DatabaseWrapper, InviteCodeWrapper, MnemonicWrapper};

#[frb]
pub struct ConduitClientFactory {
    db: Database,
    mnemonic: fedimint_bip39::Mnemonic,
}

#[frb]
pub struct FederationInfo {
    pub id: FederationId,
    pub name: String,
    pub invite: String,
}

impl FederationInfo {
    pub(crate) fn new(id: FederationId, config: ClientConfig) -> Self {
        let name = config
            .global
            .federation_name()
            .map(|name| name.to_string())
            .unwrap_or(id.to_prefix().to_string());

        let api_endpoints = config
            .global
            .api_endpoints
            .into_iter()
            .map(|(id, peer)| (id, peer.url))
            .collect();

        let invite = InviteCode::new_with_essential_num_guardians(&api_endpoints, id);

        let invite = encode_prefixed(FEDIMINT_PREFIX, &invite);

        Self { id, name, invite }
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

fn ensure_module(config: &ClientConfig, kind: &ModuleKind) -> Result<(), String> {
    match config.modules.values().any(|module| module.kind() == kind) {
        true => Ok(()),
        false => Err(format!("{} module is not present", kind)),
    }
}

impl ConduitClientFactory {
    #[frb]
    pub async fn init(db: &DatabaseWrapper, mnemonic: &MnemonicWrapper) -> Result<Self, String> {
        let mut dbtx = db.0.begin_transaction().await;

        dbtx.insert_new_entry(&RootEntropyKey, &mnemonic.0.to_entropy())
            .await;

        dbtx.commit_tx_result().await.map_err(|e| e.to_string())?;

        Ok(Self {
            db: db.0.clone(),
            mnemonic: mnemonic.0.clone(),
        })
    }

    #[frb]
    pub async fn try_load(db: &DatabaseWrapper) -> Option<Self> {
        db.0.begin_transaction_nc()
            .await
            .get_value(&RootEntropyKey)
            .await
            .map(|entropy| fedimint_bip39::Mnemonic::from_entropy(&entropy).unwrap())
            .map(|mnemonic| Self {
                db: db.0.clone(),
                mnemonic,
            })
    }

    #[frb]
    pub async fn seed_phrase(&self) -> Vec<String> {
        self.mnemonic.words().map(|s| s.to_string()).collect()
    }

    async fn client_builder(&self) -> ClientBuilder {
        let mut modules = ClientModuleInitRegistry::new();

        modules.attach(MintClientInit);
        modules.attach(LightningClientInit::default());
        modules.attach(WalletClientInit::default());

        let mut client_builder = Client::builder()
            .await
            .expect("Failed to create client builder");

        client_builder.with_module_inits(modules);

        client_builder
    }

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
            .collect::<Vec<u8>>()
    }

    async fn connectors(&self) -> ConnectorRegistry {
        ConnectorRegistry::build_from_client_defaults()
            .iroh_next(false)
            .bind()
            .await
            .expect("Failed to bind connector registry")
    }

    #[frb]
    pub async fn join(&self, invite: &InviteCodeWrapper) -> Result<ConduitClient, String> {
        if let Some(client) = self.load(&invite.0.federation_id()).await {
            return Ok(client);
        }

        let preview = self
            .client_builder()
            .await
            .preview(self.connectors().await, &invite.0)
            .await
            .map_err(|e| e.to_string())?;

        ensure_module(&preview.config(), &LIGHTNING_KIND)?;

        ensure_module(&preview.config(), &MINT_KIND)?;

        ensure_module(&preview.config(), &WALLET_KIND)?;

        let federation_id = invite.0.federation_id();

        let client = preview
            .join(self.client_database(federation_id), self.root_secret())
            .await
            .map_err(|e| e.to_string())?;

        self.save_config(&client.config().await).await;

        Ok(self.create_client(Arc::new(client), federation_id).await)
    }

    #[frb]
    pub async fn recover(&self, invite: &InviteCodeWrapper) -> Result<ConduitClient, String> {
        if let Some(client) = self.load(&invite.0.federation_id()).await {
            return Ok(client);
        }

        let preview = self
            .client_builder()
            .await
            .preview(self.connectors().await, &invite.0)
            .await
            .map_err(|e| e.to_string())?;

        ensure_module(&preview.config(), &LIGHTNING_KIND)?;

        ensure_module(&preview.config(), &MINT_KIND)?;

        ensure_module(&preview.config(), &WALLET_KIND)?;

        let federation_id = invite.0.federation_id();

        let client = preview
            .recover(
                self.client_database(federation_id),
                self.root_secret(),
                None,
            )
            .await
            .map_err(|e| e.to_string())?;

        self.save_config(&client.config().await).await;

        Ok(self.create_client(Arc::new(client), federation_id).await)
    }

    #[frb]
    pub async fn load(&self, federation_id: &FederationId) -> Option<ConduitClient> {
        if !Client::is_initialized(&self.client_database(*federation_id)).await {
            return None;
        }

        let client = self
            .client_builder()
            .await
            .open(
                self.connectors().await,
                self.client_database(*federation_id),
                self.root_secret(),
            )
            .await
            .expect("Failed to open client");

        self.save_config(&client.config().await).await;

        if !client.has_pending_recoveries() {
            self.set_selected_federation(*federation_id).await;
        }

        Some(self.create_client(Arc::new(client), *federation_id).await)
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
    ) -> ConduitClient {
        let currency_code = self
            .db
            .begin_transaction_nc()
            .await
            .get_value(&SelectedCurrencyKey)
            .await
            .unwrap_or_else(|| "USD".to_string());

        ConduitClient {
            client,
            db: self.db.clone(),
            federation_id,
            currency_code,
            exchange_rate_cache: Arc::new(Mutex::new(None)),
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

    #[frb]
    pub async fn set_currency(&self, currency_code: &str) {
        let mut dbtx = self.db.begin_transaction().await;

        dbtx.insert_entry(&SelectedCurrencyKey, &currency_code.to_string())
            .await;

        dbtx.commit_tx().await;
    }

    #[frb]
    pub async fn get_currency(&self) -> String {
        self.db
            .begin_transaction_nc()
            .await
            .get_value(&SelectedCurrencyKey)
            .await
            .unwrap_or_else(|| "USD".to_string())
    }

    async fn set_selected_federation(&self, federation_id: FederationId) {
        let mut dbtx = self.db.begin_transaction().await;

        dbtx.insert_entry(&SelectedFederationKey, &federation_id)
            .await;

        dbtx.commit_tx().await;
    }

    #[frb]
    pub async fn load_selected(&self) -> Option<ConduitClient> {
        let federation_id = self
            .db
            .begin_transaction_nc()
            .await
            .get_value(&SelectedFederationKey)
            .await?;

        self.load(&federation_id).await
    }

    #[frb]
    pub async fn leave(&self, federation_id: &FederationId) {
        let mut dbtx = self.db.begin_transaction().await;

        dbtx.remove_entry(&ClientConfigKey(*federation_id)).await;

        dbtx.remove_by_prefix(&EventLogEntryPrefix(*federation_id))
            .await;

        dbtx.raw_remove_by_prefix(&self.client_prefix(*federation_id))
            .await
            .expect("unrecoverable error when removing client db");

        dbtx.commit_tx().await;
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
