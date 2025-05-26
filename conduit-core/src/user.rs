use clap::Args;
use lightning_invoice::Bolt11Invoice;
use serde::{Deserialize, Serialize};

use crate::Balance;
use crate::Notification;
use crate::Payment;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BalanceResponse {
    /// The user's balance
    pub balance: Balance,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaymentsResponse {
    /// List of payments
    pub payments: Vec<Payment>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "variant")]
pub enum AppEvent {
    Balance(Balance),
    Payment(Payment),
    Notification(Notification),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InvoicesResponse {
    /// List of invoices
    pub invoices: Vec<InvoiceInfo>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InvoiceInfo {
    /// The invoice itself
    pub invoice: String,
    /// The payment hash as a hex string
    pub payment_hash: String,
    /// The amount in millisatoshis
    pub amount_msat: i64,
    /// The description of the invoice
    pub description: String,
    /// The creation time of the invoice
    pub created_at: i64,
}

#[derive(Debug, Clone, Args, Serialize, Deserialize)]
pub struct UserBolt11ReceiveRequest {
    /// Amount in millisatoshis
    pub amount_msat: u32,
    /// Description of the invoice
    #[arg(long, default_value = "Conduit payment")]
    pub description: String,
    /// Expiry time in seconds
    #[arg(long, default_value = "3600")]
    pub expiry_secs: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Bolt11ReceiveResponse {
    /// The generated invoice
    pub invoice: Bolt11Invoice,
}

#[derive(Debug, Clone, Args, Serialize, Deserialize)]
pub struct UserBolt11SendRequest {
    /// The invoice to pay
    pub invoice: Bolt11Invoice,
    /// The lightning address we retrived the invoice from
    pub lightning_address: Option<String>,
}

#[derive(Debug, Clone, Args, Serialize, Deserialize)]
pub struct UserBolt11QuoteRequest {
    /// The BOLT11 invoice to quote
    pub invoice: Bolt11Invoice,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Bolt11QuoteResponse {
    /// Amount in millisatoshis
    pub amount_msat: u64,
    /// Fee in millisatoshis
    pub fee_msat: u64,
    /// Description of the invoice
    pub description: String,
    /// Expiry time in seconds
    pub expiry_secs: u64,
}
