mod db;
mod frb_generated;

use std::path::PathBuf;
use std::str::FromStr;
use std::sync::Arc;
use std::time::{Duration, UNIX_EPOCH};

use fedimint_bip39::{Bip39RootSecretStrategy, Language, Mnemonic};
use fedimint_client::{
    module::oplog::OperationLogEntry, module_init::ClientModuleInitRegistry,
    secret::RootSecretStrategy, Client, ClientHandleArc, OperationId, RootSecret,
};
use fedimint_client::{ClientBuilder, ModuleKind};
use fedimint_core::config::ClientConfig;
use fedimint_core::config::FederationId;
use fedimint_core::db::IDatabaseTransactionOpsCoreTyped;
use fedimint_core::encoding::Decodable;
use fedimint_core::encoding::Encodable;
use fedimint_core::module::registry::ModuleDecoderRegistry;
use fedimint_core::util::SafeUrl;
use fedimint_core::BitcoinHash;
use fedimint_core::{db::Database, invite_code::InviteCode, Amount};
use fedimint_lnv2_client::{
    FinalSendOperationState, LightningClientInit, LightningClientModule, LightningOperationMeta,
};
use fedimint_lnv2_common::KIND as LIGHTNING_KIND;
use fedimint_lnv2_common::{Bolt11InvoiceDescription, LightningInvoice};
use fedimint_mint_client::{
    MintClientInit, MintClientModule, MintOperationMeta, MintOperationMetaVariant, OOBNotes,
    ReissueExternalNotesState, SelectNotesWithAtleastAmount, KIND as MINT_KIND,
};
use fedimint_rocksdb::RocksDb;
use flutter_rust_bridge::frb;
use futures_util::StreamExt;
use lightning_invoice::{Bolt11Invoice, Bolt11InvoiceDescriptionRef};
use lnurl_pay::LightningAddress;
use lnurl_pay::LnUrl;
use serde::Deserialize;

use crate::db::ClientConfigKey;
use crate::db::ClientConfigPrefix;
use crate::db::DbKeyPrefix;
use crate::db::RootEntropyKey;
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
struct InitializedDatabase {
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

impl InitializedDatabase {
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

        let mut client_builder = Client::builder()
            .await
            .expect("Failed to create client builder");

        client_builder.with_module_inits(modules);
        client_builder.with_primary_module_kind(MINT_KIND);

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

    #[frb]
    pub async fn join(&self, invite: &InviteCodeWrapper) -> Result<FClient, String> {
        if let Some(client) = self.load(&invite.0.federation_id()).await {
            return Ok(client);
        }

        let preview = self
            .client_builder()
            .await
            .preview(&invite.0)
            .await
            .map_err(|e| e.to_string())?;

        ensure_module(&preview.config(), &LIGHTNING_KIND)?;

        ensure_module(&preview.config(), &MINT_KIND)?;

        let client = preview
            .join(
                self.client_database(invite.0.federation_id()),
                self.root_secret(),
            )
            .await
            .map_err(|e| e.to_string())?;

        self.save_config(&client.config().await).await;

        Ok(FClient(Arc::new(client)))
    }

    #[frb]
    pub async fn recover(&self, invite: &InviteCodeWrapper) -> Result<FClient, String> {
        if let Some(client) = self.load(&invite.0.federation_id()).await {
            return Ok(client);
        }

        let preview = self
            .client_builder()
            .await
            .preview(&invite.0)
            .await
            .map_err(|e| e.to_string())?;

        ensure_module(&preview.config(), &LIGHTNING_KIND)?;

        ensure_module(&preview.config(), &MINT_KIND)?;

        let client = preview
            .recover(
                self.client_database(invite.0.federation_id()),
                self.root_secret(),
                None,
            )
            .await
            .map_err(|e| e.to_string())?;

        self.save_config(&client.config().await).await;

        Ok(FClient(Arc::new(client)))
    }

    #[frb]
    pub async fn load(&self, federation_id: &FederationId) -> Option<FClient> {
        if !Client::is_initialized(&self.client_database(*federation_id)).await {
            return None;
        }

        let client = self
            .client_builder()
            .await
            .open(self.client_database(*federation_id), self.root_secret())
            .await
            .expect("Failed to open client");

        self.save_config(&client.config().await).await;

        Some(FClient(Arc::new(client)))
    }

    async fn save_config(&self, config: &ClientConfig) {
        let mut dbtx = self.db.begin_transaction().await;

        dbtx.insert_entry(&ClientConfigKey(config.calculate_federation_id()), config)
            .await;

        dbtx.commit_tx().await;
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

#[frb]
#[derive(Clone)]
struct FClient(ClientHandleArc);

#[frb]
struct FTransaction {
    pub incoming: bool,
    pub amount_sats: i64,
    pub fee_sats: i64,
    pub timestamp: i64,
    pub oob: Option<String>,
}

impl FClient {
    #[frb]
    pub async fn federation_name(&self) -> Option<String> {
        self.0
            .config()
            .await
            .global
            .federation_name()
            .map(|name| name.to_string())
    }

    #[frb]
    pub async fn subscribe_balance(&self, sink: StreamSink<i64>) {
        let mut stream = self.0.subscribe_balance_changes().await;

        while let Some(amount) = stream.next().await {
            if sink.add((amount.msats / 1000) as i64).is_err() {
                break;
            }
        }
    }

    #[frb(sync)]
    pub fn has_pending_recoveries(&self) -> bool {
        self.0.has_pending_recoveries()
    }

    #[frb]
    pub async fn wait_for_all_recoveries(&self) -> Result<(), String> {
        self.0
            .wait_for_all_recoveries()
            .await
            .map_err(|e| e.to_string())
    }

    #[frb]
    pub async fn invite_code(&self) -> String {
        self.0.invite_code(0.into()).await.unwrap().to_string()
    }

    #[frb]
    pub async fn ecash_send(&self, amount_sat: i64) -> Result<String, String> {
        for _ in 0..5 {
            let notes = self
                .0
                .get_first_module::<MintClientModule>()
                .unwrap()
                .spend_notes_with_selector(
                    &SelectNotesWithAtleastAmount,
                    Amount::from_sats(amount_sat as u64),
                    Duration::from_secs(60 * 60 * 24),
                    true,
                    (),
                )
                .await
                .map_err(|e| e.to_string())?
                .1;

            if notes.total_amount() == Amount::from_sats(amount_sat as u64) {
                return Ok(notes.to_string());
            }

            let operation_id = self
                .0
                .get_first_module::<MintClientModule>()
                .unwrap()
                .reissue_external_notes(notes, ())
                .await
                .map_err(|e| e.to_string())?;

            self.await_ecash_reissue(operation_id).await?;
        }

        Err("Failed to reissue the required denominations".to_string())
    }

    async fn await_ecash_reissue(&self, operation_id: OperationId) -> Result<(), String> {
        let mut updates = self
            .0
            .get_first_module::<MintClientModule>()
            .unwrap()
            .subscribe_reissue_external_notes(operation_id)
            .await
            .map_err(|e| e.to_string())?
            .into_stream();

        while let Some(update) = updates.next().await {
            match update {
                ReissueExternalNotesState::Done => {
                    return Ok(());
                }
                ReissueExternalNotesState::Failed(e) => {
                    return Err(e);
                }
                _ => {}
            }
        }

        Err("Unexpected state".to_string())
    }

    #[frb]
    pub async fn ecash_receive(&self, notes: &OOBNotesWrapper) -> Result<OperationId, String> {
        if self.0.federation_id().to_prefix() != notes.0.federation_id_prefix() {
            return Err("ECash is from a different federation".to_string());
        }

        let operation_id = self
            .0
            .get_first_module::<MintClientModule>()
            .unwrap()
            .reissue_external_notes(notes.0.clone(), ())
            .await
            .map_err(|e| e.to_string())?;

        Ok(operation_id)
    }

    #[frb]
    pub async fn ln_receive(&self, amount_sat: i64) -> Result<String, String> {
        let invoice = self
            .0
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
    pub async fn ln_send(&self, invoice: &Bolt11InvoiceWrapper) -> Result<(), String> {
        let operation_id = self
            .0
            .get_first_module::<LightningClientModule>()
            .unwrap()
            .send(invoice.0.clone(), None, ().into())
            .await
            .map_err(|e| e.to_string())?;

        let state = self
            .0
            .get_first_module::<LightningClientModule>()
            .unwrap()
            .await_final_send_operation_state(operation_id)
            .await
            .map_err(|e| e.to_string())?;

        if state != FinalSendOperationState::Success {
            return Err("Payment has failed".to_string());
        }

        Ok(())
    }

    #[frb]
    pub async fn lnurl(&self) -> Result<String, String> {
        let recurringd = SafeUrl::parse("https://lnurl.ecash.love").unwrap();

        self.0
            .get_first_module::<LightningClientModule>()
            .unwrap()
            .generate_lnurl(recurringd, None)
            .await
            .map_err(|e| e.to_string())
    }

    #[frb]
    pub async fn mint_transaction_history(&self) -> Vec<FTransaction> {
        let mut collected = Vec::new();
        let mut next_key = None;

        while collected.len() < 20 {
            let page = self
                .0
                .operation_log()
                .paginate_operations_rev(50, next_key.clone())
                .await;

            if page.is_empty() {
                break;
            }

            for (key, entry) in &page {
                if collected.len() >= 20 {
                    break;
                }

                if entry.operation_module_kind() != "mint" {
                    continue;
                }

                let timestamp = key
                    .creation_time
                    .duration_since(UNIX_EPOCH)
                    .expect("Cannot be before unix epoch")
                    .as_millis() as i64;

                if let Some(tx) = Self::parse_mint_transaction(entry, timestamp) {
                    collected.push(tx);
                }
            }

            next_key = page.last().map(|entry| entry.0.clone());
        }

        collected
    }

    #[frb]
    pub async fn lnv2_transaction_history(&self) -> Vec<FTransaction> {
        let mut collected = Vec::new();
        let mut next_key = None;

        while collected.len() < 20 {
            let page = self
                .0
                .operation_log()
                .paginate_operations_rev(50, next_key.clone())
                .await;

            if page.is_empty() {
                break;
            }

            for (key, entry) in &page {
                if collected.len() >= 20 {
                    break;
                }

                if entry.operation_module_kind() != "lnv2" {
                    continue;
                }

                let timestamp = key
                    .creation_time
                    .duration_since(UNIX_EPOCH)
                    .expect("Cannot be before unix epoch")
                    .as_millis() as i64;

                if let Some(tx) = Self::parse_lnv2_transaction(entry, timestamp) {
                    collected.push(tx);
                }
            }

            next_key = page.last().map(|entry| entry.0.clone());
        }

        collected
    }

    fn parse_mint_transaction(entry: &OperationLogEntry, timestamp: i64) -> Option<FTransaction> {
        let meta = entry.meta::<MintOperationMeta>();

        match meta.variant {
            MintOperationMetaVariant::SpendOOB { oob_notes, .. } => Some(FTransaction {
                incoming: false,
                amount_sats: meta.amount.msats as i64 / 1000,
                fee_sats: 0,
                timestamp,
                oob: Some(oob_notes.to_string()),
            }),
            MintOperationMetaVariant::Reissuance { .. } => Some(FTransaction {
                incoming: true,
                amount_sats: meta.amount.msats as i64 / 1000,
                fee_sats: 0,
                timestamp,
                oob: None,
            }),
        }
    }

    fn parse_lnv2_transaction(entry: &OperationLogEntry, timestamp: i64) -> Option<FTransaction> {
        match entry.meta::<LightningOperationMeta>() {
            LightningOperationMeta::Receive(receive) => {
                let LightningInvoice::Bolt11(bolt11) = &receive.invoice;

                Some(FTransaction {
                    incoming: true,
                    amount_sats: bolt11.amount_milli_satoshis().unwrap() as i64 / 1000,
                    fee_sats: receive.gateway_fee().msats as i64 / 1000,
                    timestamp,
                    oob: Some(bolt11.to_string()),
                })
            }
            LightningOperationMeta::Send(send) => {
                let LightningInvoice::Bolt11(bolt11) = &send.invoice;

                Some(FTransaction {
                    incoming: false,
                    amount_sats: bolt11.amount_milli_satoshis().unwrap() as i64 / 1000,
                    fee_sats: send.gateway_fee().msats as i64 / 1000,
                    timestamp,
                    oob: Some(bolt11.to_string()),
                })
            }
            LightningOperationMeta::LnurlReceive(receive) => Some(FTransaction {
                incoming: true,
                amount_sats: receive.contract.commitment.amount.msats as i64 / 1000,
                fee_sats: 0,
                timestamp,
                oob: None,
            }),
        }
    }
}

#[frb(opaque)]
pub struct OOBNotesEncoder {
    encoder: FountainEncoder,
}

impl OOBNotesEncoder {
    #[frb]
    pub fn new(notes: &OOBNotesWrapper) -> Self {
        Self {
            encoder: FountainEncoder::new(&notes.0.consensus_encode_to_vec()),
        }
    }

    #[frb]
    pub fn next_part(&mut self) -> String {
        minicbor::to_vec(self.encoder.next_part())
            .map(|bytes| format!("fedimint{}", fedimint_core::base32::encode(&bytes)))
            .unwrap()
    }
}

#[frb(opaque)]
pub struct OOBNotesDecoder {
    decoder: FountainDecoder,
}

impl OOBNotesDecoder {
    #[frb(sync)]
    pub fn new() -> Self {
        Self {
            decoder: FountainDecoder::new(),
        }
    }

    #[frb(sync)]
    pub fn add_part(&mut self, part: &str) -> Option<OOBNotesWrapper> {
        if !part.starts_with("fedimint") {
            return None;
        }

        let bytes = fedimint_core::base32::decode(&part[8..]).ok()?;

        let part = minicbor::decode(&bytes).ok()?;

        let data = self.decoder.add_part(&part)?;

        OOBNotes::consensus_decode_whole(&data, &ModuleDecoderRegistry::default())
            .ok()
            .map(OOBNotesWrapper)
    }
}

/// Wrapper around UR encoder for generating fountain-encoded frames on demand
struct FountainEncoder {
    encoder: ur::fountain::Encoder,
}

impl FountainEncoder {
    fn new(data: &[u8]) -> Self {
        Self {
            encoder: ur::fountain::Encoder::new(data, 500).unwrap(),
        }
    }

    /// Get the next frame. Can be called indefinitely - fountain codes don't repeat
    fn next_part(&mut self) -> ur::fountain::Part {
        self.encoder.next_part()
    }
}

/// Decoder for fountain-encoded frames
struct FountainDecoder {
    decoder: ur::fountain::Decoder,
}

impl FountainDecoder {
    fn new() -> Self {
        Self {
            decoder: ur::fountain::Decoder::default(),
        }
    }

    /// Add a scanned part. Returns Some(data) when decoding is complete
    fn add_part(&mut self, part: &ur::fountain::Part) -> Option<Vec<u8>> {
        // If the frame is invalid, reset the decoder
        if self.decoder.receive(part.clone()).is_err() {
            self.decoder = ur::fountain::Decoder::default();
        }

        self.decoder.receive(part.clone()).unwrap();

        self.decoder.message().unwrap()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fountain_encode_decode() {
        let original_data = b"FEDIMINT11002L85AHAK2L85AHAK2L85AHAK2L85AHAK2L85AHAK2".repeat(100);

        let mut encoder = FountainEncoder::new(&original_data);

        let mut decoder = FountainDecoder::new();

        let decoded = loop {
            let part = encoder.next_part();

            if let Some(data) = decoder.add_part(&part) {
                break data;
            }

            assert!(decoder.add_part(&part).is_none(), "Should not decode yet");

            let _ = encoder.next_part();
        };

        assert_eq!(decoded, original_data);
    }
}
