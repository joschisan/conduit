pub mod account;
pub mod admin;
pub mod user;

use serde::Deserialize;
use serde::Serialize;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Payment {
    /// The payment id
    pub id: String,
    // The payment type
    pub payment_type: String,
    /// The amount in millisatoshis (positive for incoming, negative for outgoing)
    pub amount_msat: i64,
    /// The fee in millisatoshis
    pub fee_msat: i64,
    /// The description of the payment
    pub description: String,
    /// The bolt11 invoice string
    pub bolt11_invoice: String,
    /// The creation time of the payment
    pub created_at: i64,
    /// The status of the payment: "pending", "successful", or "failed"
    pub status: String,
    /// The lightning address of the payment
    pub lightning_address: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Balance {
    /// The user's balance in millisatoshis
    pub msat: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Notification {
    /// The notification message
    pub message: String,
}
