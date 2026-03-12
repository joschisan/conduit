mod client;
mod db;
mod events;
mod exchange;
mod factory;
mod fountain;
mod frb_generated;
mod lnurl;

use std::path::PathBuf;
use std::str::FromStr;

use bitcoin::address::NetworkUnchecked;
use fedimint_bip39::{Language, Mnemonic};
use fedimint_core::base32::{FEDIMINT_PREFIX, encode_prefixed};
use fedimint_core::db::Database;
use fedimint_core::invite_code::InviteCode;
use fedimint_mint_client::OOBNotes;
use fedimint_rocksdb::RocksDb;
use flutter_rust_bridge::frb;
use lightning_invoice::Bolt11Invoice;

// Re-export types needed by FRB generated code
pub use fedimint_client::OperationId;
pub use fedimint_core::config::FederationId;

// Re-export public API for FRB
pub use client::{ConduitClient, ConduitRecoveryProgress};
pub use events::{ConduitEvent, ConduitPayment, ConduitUpdate, PaymentType};
pub use factory::{ConduitClientFactory, ConduitContact, FederationInfo};
pub use fountain::{OOBNotesDecoder, OOBNotesEncoder};
pub use lnurl::{LnurlWrapper, PayResponseWrapper, lnurl_fetch_limits, lnurl_resolve, parse_lnurl};

#[frb(sync)]
pub fn word_list() -> Vec<String> {
    Language::English
        .word_list()
        .iter()
        .map(|s| s.to_string())
        .collect()
}

#[frb]
pub struct MnemonicWrapper(pub(crate) Mnemonic);

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
pub struct DatabaseWrapper(pub(crate) Database);

#[frb]
pub async fn open_database(db_path: &str) -> DatabaseWrapper {
    fedimint_core::rustls::install_crypto_provider().await;

    let db_path = PathBuf::from_str(&db_path)
        .expect("Could not parse db path")
        .join("client.db");

    RocksDb::open_blocking(db_path, None)
        .map(|db| DatabaseWrapper(db.into()))
        .expect("Could not open database")
}

#[frb]
#[derive(Clone)]
pub struct InviteCodeWrapper(pub(crate) InviteCode);

#[frb(sync)]
pub fn parse_invite_code(invite: &str) -> Option<InviteCodeWrapper> {
    InviteCode::from_str(invite).ok().map(InviteCodeWrapper)
}

#[frb]
pub struct OOBNotesWrapper(pub(crate) OOBNotes);

impl OOBNotesWrapper {
    #[frb(sync)]
    pub fn amount_sats(&self) -> i64 {
        self.0.total_amount().msats as i64 / 1000
    }

    #[frb(sync)]
    pub fn to_string(&self) -> String {
        encode_prefixed(FEDIMINT_PREFIX, &self.0)
    }
}

#[frb(sync)]
pub fn parse_oob_notes(notes: &str) -> Option<OOBNotesWrapper> {
    if let Some(stripped) = notes.strip_prefix("fedimint:") {
        return parse_oob_notes(stripped);
    }

    OOBNotes::from_str(notes).ok().map(OOBNotesWrapper)
}

#[frb]
pub struct Bolt11InvoiceWrapper(pub(crate) Bolt11Invoice);

impl Bolt11InvoiceWrapper {
    #[frb(sync)]
    pub fn amount_sats(&self) -> i64 {
        self.0
            .amount_milli_satoshis()
            .map(|msat| msat as i64 / 1000)
            .unwrap()
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
pub struct BitcoinAddressWrapper(pub(crate) bitcoin::Address<NetworkUnchecked>);

#[frb(sync)]
pub fn parse_bitcoin_address(address: &str) -> Option<BitcoinAddressWrapper> {
    if let Some(stripped) = address.strip_prefix("bitcoin:") {
        return parse_bitcoin_address(stripped);
    }

    // Strip query parameters from BIP21 URIs
    let address = address.split('?').next().unwrap_or(address);

    bitcoin::Address::from_str(address)
        .ok()
        .map(BitcoinAddressWrapper)
}
