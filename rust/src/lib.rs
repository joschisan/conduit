mod db;
mod frb_generated;

use std::collections::{BTreeMap, VecDeque};
use std::path::PathBuf;
use std::str::FromStr;
use std::sync::Arc;
use std::time::{Duration, Instant};

use tokio::sync::Mutex;

use bitcoin::address::NetworkUnchecked;
use fedimint_api_client::api::ConnectorRegistry;
use fedimint_bip39::{Bip39RootSecretStrategy, Language, Mnemonic};
use fedimint_client::{
    module_init::ClientModuleInitRegistry, secret::RootSecretStrategy, Client, ClientHandleArc,
    OperationId, RootSecret,
};
use fedimint_client::{ClientBuilder, ModuleKind};
use fedimint_core::base32::{decode_prefixed, encode_prefixed, FEDIMINT_PREFIX};
use fedimint_core::config::ClientConfig;
use fedimint_core::config::FederationId;
use fedimint_core::db::IDatabaseTransactionOpsCoreTyped;
use fedimint_core::encoding::Encodable;
use fedimint_core::module::serde_json;
use fedimint_core::module::AmountUnit;
use fedimint_core::util::SafeUrl;
use fedimint_core::BitcoinHash;
use fedimint_core::{db::Database, invite_code::InviteCode, Amount};
use fedimint_eventlog::Event;
use fedimint_eventlog::EventLogId;
use fedimint_eventlog::PersistedLogEntry;
use fedimint_fountain::{FountainDecoder, FountainEncoder};
use fedimint_lnv2_client::{events::SendPaymentStatus, LightningClientInit, LightningClientModule};
use fedimint_lnv2_common::Bolt11InvoiceDescription;
use fedimint_lnv2_common::KIND as LIGHTNING_KIND;
use fedimint_mint_client::{
    event::ReceivePaymentStatus, MintClientInit, MintClientModule, OOBNotes,
    SelectNotesWithExactAmount, KIND as MINT_KIND,
};
use fedimint_rocksdb::RocksDb;
use fedimint_wallet_client::{
    client_db::TweakIdx, events::SendPaymentStatus as WalletSendPaymentStatus, WalletClientInit,
    WalletClientModule, WalletOperationMeta, WalletOperationMetaVariant, KIND as WALLET_KIND,
};
use flutter_rust_bridge::frb;
use futures_util::StreamExt;
use lightning_invoice::{Bolt11Invoice, Bolt11InvoiceDescriptionRef};
use lnurl_pay::LightningAddress;
use lnurl_pay::LnUrl;
use serde::Deserialize;

use crate::db::ClientConfigKey;
use crate::db::ClientConfigPrefix;
use crate::db::DbKeyPrefix;
use crate::db::EventLogStartPositionKey;
use crate::db::RootEntropyKey;
use crate::db::SelectedCurrencyKey;
use crate::frb_generated::StreamSink;

#[frb(sync)]
pub fn word_list() -> Vec<String> {
    Language::English
        .word_list()
        .iter()
        .map(|s| s.to_string())
        .collect()
}

#[frb]
pub struct MnemonicWrapper(Mnemonic);

#[frb]
pub fn parse_mnemonic(words: Vec<String>) -> Option<MnemonicWrapper> {
    Mnemonic::from_str(&words.join(" "))
        .ok()
        .map(MnemonicWrapper)
}

#[frb]
pub fn generate_mnemonic() -> MnemonicWrapper {
    MnemonicWrapper(Mnemonic::generate(12).unwrap())
}

#[frb]
pub struct DatabaseWrapper(Database);

#[frb]
pub async fn open_database(db_path: &str) -> DatabaseWrapper {
    fedimint_core::rustls::install_crypto_provider().await;

    let db_path = PathBuf::from_str(&db_path)
        .expect("Could not parse db path")
        .join("client.db");

    RocksDb::open(db_path)
        .await
        .map(|db| DatabaseWrapper(db.into()))
        .expect("Could not open database")
}

#[frb]
pub struct InviteCodeWrapper(InviteCode);

#[frb(sync)]
pub fn parse_invite_code(invite: &str) -> Option<InviteCodeWrapper> {
    InviteCode::from_str(invite).ok().map(InviteCodeWrapper)
}

#[frb]
pub struct OOBNotesWrapper(OOBNotes);

impl OOBNotesWrapper {
    #[frb(sync)]
    pub fn amount_sats(&self) -> i64 {
        self.0.total_amount().msats as i64 / 1000
    }

    #[frb(sync)]
    pub fn encode_prefixed(&self) -> String {
        encode_prefixed(FEDIMINT_PREFIX, &self.0.consensus_encode_to_vec())
    }
}

#[frb(sync)]
pub fn parse_oob_notes(notes: &str) -> Option<OOBNotesWrapper> {
    OOBNotes::from_str(notes).ok().map(OOBNotesWrapper)
}

#[frb]
pub struct Bolt11InvoiceWrapper(Bolt11Invoice);

impl Bolt11InvoiceWrapper {
    #[frb(sync)]
    pub fn amount_sats(&self) -> i64 {
        self.0
            .amount_milli_satoshis()
            .map(|msat| msat as i64 / 1000)
            .unwrap()
    }

    #[frb(sync)]
    pub fn description(&self) -> String {
        match self.0.description() {
            Bolt11InvoiceDescriptionRef::Direct(desc) => desc.to_string(),
            Bolt11InvoiceDescriptionRef::Hash(_) => String::new(),
        }
    }
}

#[frb(sync)]
pub fn parse_bolt11_invoice(invoice: &str) -> Option<Bolt11InvoiceWrapper> {
    if let Some(invoice) = invoice.strip_prefix("lightning:") {
        return parse_bolt11_invoice(invoice);
    }

    Bolt11Invoice::from_str(invoice)
        .ok()
        .filter(|invoice| invoice.amount_milli_satoshis().is_some())
        .map(Bolt11InvoiceWrapper)
}

#[frb]
pub struct LnurlWrapper(String);

#[frb(sync)]
pub fn parse_lnurl(request: String) -> Option<LnurlWrapper> {
    if let Some(stripped) = request.strip_prefix("lnurl:") {
        return parse_lnurl(stripped.to_string());
    }

    if let Ok(lnurl) = LnUrl::from_str(&request) {
        return Some(LnurlWrapper(lnurl.endpoint()));
    }

    if let Ok(lightning_address) = LightningAddress::from_str(&request) {
        return Some(LnurlWrapper(lightning_address.endpoint()));
    }

    None
}

#[derive(Deserialize)]
struct LnUrlPayResponse {
    callback: String,
    #[serde(alias = "minSendable")]
    min_sendable: i64,
    #[serde(alias = "maxSendable")]
    max_sendable: i64,
}

#[derive(Deserialize)]
struct LnUrlPayInvoiceResponse {
    pr: Bolt11Invoice,
}

#[frb]
pub async fn resolve_lnurl(
    lnurl: LnurlWrapper,
    amount_sats: i64,
) -> Result<Bolt11InvoiceWrapper, String> {
    let response = reqwest::get(lnurl.0)
        .await
        .map_err(|_| "Failed to fetch LNURL".to_string())?
        .json::<LnUrlPayResponse>()
        .await
        .map_err(|_| "Failed to parse LNURL response".to_string())?;

    if amount_sats * 1000 < response.min_sendable {
        return Err("Amount too low".to_string());
    }

    if amount_sats * 1000 > response.max_sendable {
        return Err("Amount too high".to_string());
    }

    let callback_url = format!("{}?amount={}", response.callback, amount_sats * 1000);

    let response = reqwest::get(callback_url)
        .await
        .map_err(|_| "Failed to fetch LNURL callback".to_string())?
        .json::<LnUrlPayInvoiceResponse>()
        .await
        .map_err(|_| "Failed to parse LNURL callback response".to_string())?;

    if response.pr.amount_milli_satoshis() != Some((amount_sats * 1000) as u64) {
        return Err("Invoice response amount mismatch".to_string());
    }

    Ok(Bolt11InvoiceWrapper(response.pr))
}

#[frb]
pub struct BitcoinAddressWrapper(bitcoin::Address<NetworkUnchecked>);

#[frb(sync)]
pub fn parse_bitcoin_address(address: &str) -> Option<BitcoinAddressWrapper> {
    if let Some(stripped) = address.strip_prefix("bitcoin:") {
        return parse_bitcoin_address(stripped);
    }

    bitcoin::Address::from_str(address)
        .ok()
        .map(BitcoinAddressWrapper)
}

#[frb]
struct ConduitClientFactory {
    db: Database,
    mnemonic: Mnemonic,
}

#[frb]
struct FederationInfo {
    pub id: FederationId,
    pub name: String,
    pub invite: String,
}

impl FederationInfo {
    pub fn new(id: FederationId, config: ClientConfig) -> Self {
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

        let invite = InviteCode::new_with_essential_num_guardians(&api_endpoints, id).to_string();

        Self { id, name, invite }
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
            .map(|entropy| Mnemonic::from_entropy(&entropy).unwrap())
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

        Ok(self.create_fclient(Arc::new(client), federation_id).await)
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

        Ok(self.create_fclient(Arc::new(client), federation_id).await)
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

        Some(self.create_fclient(Arc::new(client), *federation_id).await)
    }

    async fn save_config(&self, config: &ClientConfig) {
        let mut dbtx = self.db.begin_transaction().await;

        dbtx.insert_entry(&ClientConfigKey(config.calculate_federation_id()), config)
            .await;

        dbtx.commit_tx().await;
    }

    async fn create_fclient(
        &self,
        client: ClientHandleArc,
        federation_id: FederationId,
    ) -> ConduitClient {
        let position = EventLogStartPosition::new(self.db.clone(), federation_id);

        // Read selected currency from database, default to "USD"
        let currency_code = self
            .db
            .begin_transaction_nc()
            .await
            .get_value(&SelectedCurrencyKey)
            .await
            .unwrap_or_else(|| "USD".to_string());

        ConduitClient {
            client,
            event_log_start_position: position,
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

    #[frb]
    pub async fn leave(&self, federation_id: &FederationId) {
        let mut dbtx = self.db.begin_transaction().await;

        dbtx.remove_entry(&ClientConfigKey(*federation_id)).await;

        dbtx.commit_tx().await;
    }
}

fn ensure_module(config: &ClientConfig, kind: &ModuleKind) -> Result<(), String> {
    match config.modules.values().any(|module| module.kind() == kind) {
        true => Ok(()),
        false => Err(format!("{} module is not present", kind)),
    }
}

#[derive(Clone)]
struct EventLogStartPosition {
    db: Database,
    federation_id: FederationId,
}

impl EventLogStartPosition {
    fn new(db: Database, federation_id: FederationId) -> Self {
        Self { db, federation_id }
    }

    async fn update_position(&self, event_id: EventLogId) {
        let mut dbtx = self.db.begin_transaction().await;

        dbtx.insert_entry(&EventLogStartPositionKey(self.federation_id), &event_id)
            .await;

        dbtx.commit_tx().await;
    }

    async fn get_position(&self) -> Option<EventLogId> {
        self.db
            .begin_transaction_nc()
            .await
            .get_value(&EventLogStartPositionKey(self.federation_id))
            .await
    }
}

#[derive(Deserialize, Clone)]
struct FediPriceResponse {
    prices: BTreeMap<String, ExchangeRate>,
}

#[derive(Deserialize, Clone)]
struct ExchangeRate {
    rate: f64,
}

#[frb]
#[derive(Clone)]
struct ConduitClient {
    client: ClientHandleArc,
    event_log_start_position: EventLogStartPosition,
    currency_code: String,
    exchange_rate_cache: Arc<Mutex<Option<(FediPriceResponse, Instant)>>>,
}

/// Payment event - emitted when a payment is initiated or completes
#[frb]
pub struct ConduitPayment {
    pub operation_id: String,
    pub incoming: bool,
    pub amount_sats: i64,
    pub fee_sats: Option<i64>,
    pub timestamp: i64,
    pub success: Option<bool>,
    pub oob: Option<String>, // eCash notes for mint send operations
}

/// Payment update - emitted when a send payment reaches a final state
#[frb]
pub struct ConduitUpdate {
    pub operation_id: String,
    pub timestamp: i64,
    pub success: bool,
    pub oob: Option<String>,
}

/// Event message - either a new payment or a status update
#[frb]
pub enum ConduitEvent {
    Event(ConduitPayment),
    Update(ConduitUpdate),
}

impl ConduitClient {
    #[frb]
    pub async fn federation_name(&self) -> Option<String> {
        self.client
            .config()
            .await
            .global
            .federation_name()
            .map(|name| name.to_string())
    }

    #[frb(sync)]
    pub fn currency_code(&self) -> String {
        self.currency_code.clone()
    }

    #[frb]
    pub async fn prefetch_exchange_rates(&self) {
        tokio::task::spawn(fetch_exchange_rate(self.exchange_rate_cache.clone()));
    }

    #[frb]
    pub async fn fiat_to_sats(&self, amount_fiat_cents: i64) -> Result<i64, String> {
        let exchange_response = fetch_exchange_rate(self.exchange_rate_cache.clone()).await?;

        // Step 1: Convert minor units to major units (e.g., 1234 cents → 12.34 EUR)
        let amount_fiat = amount_fiat_cents as f64 / 100.0;

        // Step 2: Convert currency to USD (via exchange rate)
        let amount_in_usd = if self.currency_code == "USD" {
            amount_fiat
        } else {
            let currency_to_usd_rate = exchange_response
                .prices
                .get(&format!("{}/USD", self.currency_code))
                .ok_or("Selected currency not supported".to_string())?
                .rate;

            amount_fiat * currency_to_usd_rate
        };

        // Step 3: Convert USD to BTC
        let usd_to_btc_rate = exchange_response
            .prices
            .get("BTC/USD")
            .ok_or("BTC/USD rate not found".to_string())?
            .rate;

        let amount_in_btc = amount_in_usd / usd_to_btc_rate;

        // Step 4: Convert BTC to satoshis (1 BTC = 100,000,000 sats), rounded
        let amount_sats = (amount_in_btc * 100_000_000.0).round() as i64;

        Ok(amount_sats)
    }

    #[frb]
    pub async fn subscribe_balance(&self, sink: StreamSink<i64>) {
        let mut stream = self
            .client
            .subscribe_balance_changes(AmountUnit::bitcoin())
            .await;

        while let Some(amount) = stream.next().await {
            if sink.add((amount.msats / 1000) as i64).is_err() {
                break;
            }
        }
    }

    #[frb(sync)]
    pub fn has_pending_recoveries(&self) -> bool {
        self.client.has_pending_recoveries()
    }

    #[frb]
    pub async fn wait_for_all_recoveries(&self) -> Result<(), String> {
        self.client
            .wait_for_all_recoveries()
            .await
            .map_err(|e| e.to_string())
    }

    #[frb]
    pub async fn invite_code(&self) -> String {
        self.client.invite_code(0.into()).await.unwrap().to_string()
    }

    #[frb]
    pub async fn ecash_send(&self, amount_sat: i64) -> Result<OOBNotesWrapper, String> {
        self.client
            .get_first_module::<MintClientModule>()
            .unwrap()
            .spend_notes_with_selector(
                &SelectNotesWithExactAmount,
                Amount::from_sats(amount_sat as u64),
                Duration::from_secs(60 * 60 * 24),
                true,
                (),
            )
            .await
            .map(|entry| OOBNotesWrapper(entry.1))
            .map_err(|e| e.to_string())
    }

    #[frb]
    pub async fn ecash_receive(&self, notes: &OOBNotesWrapper) -> Result<OperationId, String> {
        if self.client.federation_id().to_prefix() != notes.0.federation_id_prefix() {
            return Err("eCash is from a different federation".to_string());
        }

        self.client
            .get_first_module::<MintClientModule>()
            .unwrap()
            .reissue_external_notes(notes.0.clone(), ())
            .await
            .map_err(|e| e.to_string())
    }

    #[frb]
    pub async fn ln_receive(&self, amount_sat: i64) -> Result<String, String> {
        let invoice = self
            .client
            .get_first_module::<LightningClientModule>()
            .unwrap()
            .receive(
                Amount::from_sats(amount_sat as u64),
                60 * 60 * 24,
                Bolt11InvoiceDescription::Direct(String::new()),
                None,
                ().into(),
            )
            .await
            .map_err(|e| e.to_string())?
            .0;

        Ok(invoice.to_string())
    }

    #[frb]
    pub async fn ln_send(&self, invoice: &Bolt11InvoiceWrapper) -> Result<OperationId, String> {
        self.client
            .get_first_module::<LightningClientModule>()
            .unwrap()
            .send(invoice.0.clone(), None, ().into())
            .await
            .map_err(|e| e.to_string())
    }

    #[frb]
    pub async fn lnurl(&self) -> Result<String, String> {
        let recurringd = SafeUrl::parse("https://lnurl.ecash.love").unwrap();

        self.client
            .get_first_module::<LightningClientModule>()
            .unwrap()
            .generate_lnurl(recurringd, None)
            .await
            .map_err(|e| e.to_string())
    }

    #[frb]
    pub async fn onchain_calculate_fees(
        &self,
        address: &BitcoinAddressWrapper,
        amount_sats: i64,
    ) -> Result<i64, String> {
        let wallet_module = self
            .client
            .get_first_module::<WalletClientModule>()
            .map_err(|e| e.to_string())?;

        let address_checked = address
            .0
            .clone()
            .require_network(wallet_module.get_network())
            .map_err(|e| e.to_string())?;

        let amount = bitcoin::Amount::from_sat(amount_sats as u64);

        let fees = wallet_module
            .get_withdraw_fees(&address_checked, amount)
            .await
            .map_err(|e| e.to_string())?;

        Ok(fees.amount().to_sat() as i64)
    }

    #[frb]
    pub async fn onchain_send(
        &self,
        address: &BitcoinAddressWrapper,
        amount_sats: i64,
    ) -> Result<OperationId, String> {
        let wallet_module = self
            .client
            .get_first_module::<WalletClientModule>()
            .map_err(|e| e.to_string())?;

        let address_checked = address
            .0
            .clone()
            .require_network(wallet_module.get_network())
            .map_err(|e| e.to_string())?;

        let amount = bitcoin::Amount::from_sat(amount_sats as u64);

        let fees = wallet_module
            .get_withdraw_fees(&address_checked, amount)
            .await
            .map_err(|e| e.to_string())?;

        wallet_module
            .withdraw(&address_checked, amount, fees, ())
            .await
            .map_err(|e| e.to_string())
    }

    #[frb]
    pub async fn onchain_receive_address(&self) -> Result<String, String> {
        let wallet_module = self
            .client
            .get_first_module::<WalletClientModule>()
            .map_err(|e| e.to_string())?;

        let (_, address, _) = wallet_module
            .safe_allocate_deposit_address(())
            .await
            .map_err(|e| e.to_string())?;

        Ok(address.to_string())
    }

    #[frb]
    pub async fn onchain_list_addresses(&self) -> Vec<(i64, String)> {
        let operation_log = self.client.operation_log();
        let mut addresses = Vec::new();
        let mut next_key = None;

        // Paginate through all operations
        loop {
            let page = operation_log.paginate_operations_rev(100, next_key).await;

            if page.is_empty() {
                break;
            }

            for (_key, op_log_entry) in &page {
                if op_log_entry.operation_module_kind() != "wallet" {
                    continue;
                }

                match op_log_entry.meta::<WalletOperationMeta>().variant {
                    WalletOperationMetaVariant::Deposit {
                        address, tweak_idx, ..
                    } => {
                        if let Some(tweak_idx) = tweak_idx {
                            addresses.push((
                                tweak_idx.0 as i64,
                                address.clone().assume_checked().to_string(),
                            ));
                        }
                    }
                    _ => continue,
                }
            }

            next_key = page.last().map(|entry| entry.0.clone());
        }

        addresses.into_iter().rev().collect()
    }

    #[frb]
    pub async fn onchain_recheck_address(&self, tweak_idx: i64) -> Result<(), String> {
        let wallet_module = self
            .client
            .get_first_module::<WalletClientModule>()
            .map_err(|e| e.to_string())?;

        wallet_module
            .recheck_pegin_address(TweakIdx(tweak_idx as u64))
            .await
            .map_err(|e| e.to_string())?;

        Ok(())
    }

    #[frb]
    pub async fn subscribe_event_log(&self, sink: StreamSink<ConduitEvent>) {
        let mut log_event_added_rx = self.client.log_event_added_rx();

        let mut position = self
            .event_log_start_position
            .get_position()
            .await
            .unwrap_or(EventLogId::LOG_START);

        let mut parsed_entry_ids = VecDeque::new();

        loop {
            let batch = self.client.get_event_log(Some(position), 1000).await;

            if batch.is_empty() {
                if log_event_added_rx.changed().await.is_err() {
                    return;
                }
            } else {
                for entry in &batch {
                    if let Some(event) = Self::parse_event_log_entry(&entry) {
                        if sink.add(event).is_err() {
                            return;
                        }

                        // Track this entry ID
                        parsed_entry_ids.push_back(entry.event_id);

                        // If we've tracked 1000 entries, update position to the oldest
                        if parsed_entry_ids.len() == 10 {
                            if let Some(oldest_id) = parsed_entry_ids.pop_front() {
                                self.event_log_start_position
                                    .update_position(oldest_id)
                                    .await;
                            }
                        }
                    }
                }

                position = batch
                    .last()
                    .expect("Batch is not empty")
                    .event_id
                    .saturating_add(1);
            }
        }
    }

    fn parse_event_log_entry(entry: &PersistedLogEntry) -> Option<ConduitEvent> {
        // Try to deserialize as SendPaymentEvent
        if entry.event_kind == fedimint_lnv2_client::events::SendPaymentEvent::KIND {
            return serde_json::from_value::<fedimint_lnv2_client::events::SendPaymentEvent>(
                entry.value.clone(),
            )
            .ok()
            .map(|send| {
                ConduitEvent::Event(ConduitPayment {
                    operation_id: send.operation_id.fmt_short().to_string(),
                    incoming: false,
                    amount_sats: (send.amount.msats / 1000) as i64,
                    fee_sats: send.fee.map(|fee| (fee.msats / 1000) as i64),
                    timestamp: (entry.timestamp / 1000) as i64,
                    success: None,
                    oob: None,
                })
            });
        }

        // Try to deserialize as SendPaymentUpdateEvent
        if entry.event_kind == fedimint_lnv2_client::events::SendPaymentUpdateEvent::KIND {
            return serde_json::from_value::<fedimint_lnv2_client::events::SendPaymentUpdateEvent>(
                entry.value.clone(),
            )
            .ok()
            .map(|update| {
                ConduitEvent::Update(ConduitUpdate {
                    operation_id: update.operation_id.fmt_short().to_string(),
                    timestamp: (entry.timestamp / 1000) as i64,
                    success: matches!(update.status, SendPaymentStatus::Success(_)),
                    oob: None,
                })
            });
        }

        // Try to deserialize as ReceivePaymentEvent
        if entry.event_kind == fedimint_lnv2_client::events::ReceivePaymentEvent::KIND {
            return serde_json::from_value::<fedimint_lnv2_client::events::ReceivePaymentEvent>(
                entry.value.clone(),
            )
            .ok()
            .map(|receive| {
                ConduitEvent::Event(ConduitPayment {
                    operation_id: receive.operation_id.fmt_short().to_string(),
                    incoming: true,
                    amount_sats: (receive.amount.msats / 1000) as i64,
                    fee_sats: None,
                    timestamp: (entry.timestamp / 1000) as i64,
                    success: Some(true),
                    oob: None,
                })
            });
        }

        // Try to deserialize as MintSendPaymentEvent
        if entry.event_kind == fedimint_mint_client::event::SendPaymentEvent::KIND {
            return serde_json::from_value::<fedimint_mint_client::event::SendPaymentEvent>(
                entry.value.clone(),
            )
            .ok()
            .map(|send| {
                ConduitEvent::Event(ConduitPayment {
                    operation_id: send.operation_id.fmt_short().to_string(),
                    incoming: false,
                    amount_sats: (send.amount.msats / 1000) as i64,
                    fee_sats: None,
                    timestamp: (entry.timestamp / 1000) as i64,
                    success: Some(true),
                    oob: Some(send.oob_notes),
                })
            });
        }

        // Try to deserialize as MintReceivePaymentEvent
        if entry.event_kind == fedimint_mint_client::event::ReceivePaymentEvent::KIND {
            return serde_json::from_value::<fedimint_mint_client::event::ReceivePaymentEvent>(
                entry.value.clone(),
            )
            .ok()
            .map(|receive| {
                ConduitEvent::Event(ConduitPayment {
                    operation_id: receive.operation_id.fmt_short().to_string(),
                    incoming: true,
                    amount_sats: (receive.amount.msats / 1000) as i64,
                    fee_sats: None,
                    timestamp: (entry.timestamp / 1000) as i64,
                    success: None,
                    oob: None,
                })
            });
        }

        // Try to deserialize as MintReceivePaymentUpdateEvent
        if entry.event_kind == fedimint_mint_client::event::ReceivePaymentUpdateEvent::KIND {
            return serde_json::from_value::<fedimint_mint_client::event::ReceivePaymentUpdateEvent>(
                entry.value.clone(),
            )
            .ok()
            .map(|update| {
                ConduitEvent::Update(ConduitUpdate {
                    operation_id: update.operation_id.fmt_short().to_string(),
                    timestamp: (entry.timestamp / 1000) as i64,
                    success: matches!(update.status, ReceivePaymentStatus::Success),
                    oob: None,
                })
            });
        }

        // Try to deserialize as WalletSendPaymentEvent
        if entry.event_kind == fedimint_wallet_client::events::SendPaymentEvent::KIND {
            return serde_json::from_value::<fedimint_wallet_client::events::SendPaymentEvent>(
                entry.value.clone(),
            )
            .ok()
            .map(|send| {
                ConduitEvent::Event(ConduitPayment {
                    operation_id: send.operation_id.fmt_short().to_string(),
                    incoming: false,
                    amount_sats: send.amount.to_sat() as i64,
                    fee_sats: Some(send.fee.to_sat() as i64),
                    timestamp: (entry.timestamp / 1000) as i64,
                    success: None,
                    oob: None,
                })
            });
        }

        // Try to deserialize as WalletSendPaymentStatusEvent
        if entry.event_kind == fedimint_wallet_client::events::SendPaymentStatusEvent::KIND {
            return serde_json::from_value::<fedimint_wallet_client::events::SendPaymentStatusEvent>(
                entry.value.clone(),
            )
            .ok()
            .map(|status| {
                let (success, oob) = match status.status {
                    WalletSendPaymentStatus::Success(txid) => (true, Some(txid.to_string())),
                    WalletSendPaymentStatus::Aborted => (false, None),
                };

                ConduitEvent::Update(ConduitUpdate {
                    operation_id: status.operation_id.fmt_short().to_string(),
                    timestamp: (entry.timestamp / 1000) as i64,
                    success,
                    oob,
                })
            });
        }

        // Try to deserialize as WalletReceivePaymentEvent
        if entry.event_kind == fedimint_wallet_client::events::ReceivePaymentEvent::KIND {
            return serde_json::from_value::<fedimint_wallet_client::events::ReceivePaymentEvent>(
                entry.value.clone(),
            )
            .ok()
            .map(|receive| {
                ConduitEvent::Event(ConduitPayment {
                    operation_id: receive.operation_id.fmt_short().to_string(),
                    incoming: true,
                    amount_sats: (receive.amount.msats / 1000) as i64,
                    fee_sats: None,
                    timestamp: (entry.timestamp / 1000) as i64,
                    success: Some(true),
                    oob: Some(receive.txid.to_string()),
                })
            });
        }

        None
    }
}

#[frb(opaque)]
pub struct OOBNotesEncoder(FountainEncoder);

impl OOBNotesEncoder {
    #[frb(sync)]
    pub fn new(notes: &OOBNotesWrapper) -> Self {
        Self(FountainEncoder::new(
            &notes.0.consensus_encode_to_vec(),
            512,
        ))
    }

    #[frb]
    pub fn next_fragment(&mut self) -> String {
        encode_prefixed(FEDIMINT_PREFIX, &self.0.next_fragment())
    }
}

#[frb(opaque)]
pub struct OOBNotesDecoder(FountainDecoder<OOBNotes>);

impl OOBNotesDecoder {
    #[frb(sync)]
    pub fn new() -> Self {
        Self(FountainDecoder::default())
    }

    #[frb(sync)]
    pub fn add_fragment(&mut self, part: &str) -> Option<OOBNotesWrapper> {
        decode_prefixed(FEDIMINT_PREFIX, part)
            .ok()
            .and_then(|fragment| self.0.add_fragment(&fragment))
            .map(OOBNotesWrapper)
    }
}

async fn fetch_exchange_rate(
    cache: Arc<Mutex<Option<(FediPriceResponse, Instant)>>>,
) -> Result<FediPriceResponse, String> {
    let mut guard = cache.lock().await;

    #[allow(clippy::collapsible_if)]
    if let Some((value, timestamp)) = guard.as_ref() {
        if timestamp.elapsed() < Duration::from_secs(600) {
            return Ok(value.clone());
        }
    }

    let value = reqwest::get("https://price-feed.dev.fedibtc.com/latest")
        .await
        .map_err(|_| "Failed to fetch exchange rates".to_string())?
        .json::<FediPriceResponse>()
        .await
        .map_err(|_| "Failed to parse exchange rates".to_string())?;

    *guard = Some((value.clone(), Instant::now()));

    Ok(value)
}
