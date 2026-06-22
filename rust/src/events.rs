use fedimint_core::module::serde_json;
use fedimint_eventlog::{Event, EventLogEntry};
use fedimint_lnv2_client::events::SendPaymentStatus;
use fedimint_mint_client::events::ReceivePaymentStatus;
use fedimint_mintv2_client::ReceivePaymentStatus as MintV2ReceivePaymentStatus;
use fedimint_wallet_client::events::SendPaymentStatus as WalletSendPaymentStatus;
use fedimint_walletv2_client::events::{
    ReceivePaymentStatus as WalletV2ReceivePaymentStatus,
    SendPaymentStatus as WalletV2SendPaymentStatus,
};
use bitcoin::hex::DisplayHex;
use flutter_rust_bridge::frb;

use crate::OperationId;

/// Type of payment
#[frb]
#[derive(Clone)]
pub enum PaymentType {
    Lightning,
    Bitcoin,
    Ecash,
}

/// Payment with all updates folded in
#[frb]
#[derive(Clone)]
pub struct ConduitPayment {
    pub operation_id: String,
    pub incoming: bool,
    pub payment_type: PaymentType,
    pub amount_sats: i64,
    pub fee_sats: Option<i64>,
    pub timestamp: i64,
    pub success: Option<bool>,
    pub ecash: Option<String>,
    pub txid: Option<String>,
    pub preimage: Option<String>,
    pub address: Option<String>,
    /// Fiat value of `amount_sats` at the rate snapshotted when the payment was
    /// first observed live. `None` for payments that predate the feature or
    /// landed with no fresh rate cached.
    pub fiat_amount: Option<f64>,
    pub fiat_currency_code: Option<String>,
}

/// Notification for a recent payment event
#[frb]
pub struct PaymentNotification {
    pub incoming: bool,
    pub success: bool,
    pub amount_sats: i64,
    pub payment_type: PaymentType,
}

/// Snapshot of recent payments plus an optional notification
#[frb]
pub struct RecentPaymentsUpdate {
    pub payments: Vec<ConduitPayment>,
    pub notification: Option<PaymentNotification>,
}

pub(crate) enum ParsedEvent {
    Payment {
        payment: ConduitPayment,
        operation_id: OperationId,
    },
    Update {
        operation_id: OperationId,
        success: bool,
        txid: Option<String>,
        preimage: Option<String>,
    },
}

/// Fold an update into a payment list by operation_id
pub(crate) fn apply_update(
    payments: &mut [ConduitPayment],
    operation_id: &OperationId,
    success: bool,
    txid: Option<String>,
    preimage: Option<String>,
) -> Option<PaymentNotification> {
    let operation_id = operation_id.fmt_full().to_string();

    let payment = payments
        .iter_mut()
        .rfind(|p| p.operation_id == operation_id)?;

    payment.success = Some(success);
    payment.txid = txid;
    payment.preimage = preimage;

    Some(PaymentNotification {
        incoming: payment.incoming,
        success,
        amount_sats: payment.amount_sats,
        payment_type: payment.payment_type.clone(),
    })
}

/// Snapshot the last `count` payments in newest-first order
pub(crate) fn snapshot(payments: &[ConduitPayment], count: usize) -> Vec<ConduitPayment> {
    payments.iter().rev().take(count).cloned().collect()
}

pub(crate) fn parse_event_log_entry(entry: &EventLogEntry) -> Option<ParsedEvent> {
    if let Some(send) = parse::<fedimint_lnv2_client::events::SendPaymentEvent>(entry) {
        return Some(ParsedEvent::Payment {
            operation_id: send.operation_id,
            payment: ConduitPayment {
                operation_id: send.operation_id.fmt_full().to_string(),
                incoming: false,
                payment_type: PaymentType::Lightning,
                amount_sats: (send.amount.msats / 1000) as i64,
                fee_sats: Some((send.fee.msats / 1000) as i64),
                timestamp: (entry.ts_usecs / 1000) as i64,
                success: None,
                ecash: None,
                txid: None,
                address: None,
                fiat_amount: None,
                fiat_currency_code: None,
                preimage: None,
            },
        });
    }

    if let Some(update) = parse::<fedimint_lnv2_client::events::SendPaymentUpdateEvent>(entry) {
        // The preimage arrives here, on the terminal update, not on the
        // SendPaymentEvent that created the payment — fold it in like the txid.
        let (success, preimage) = match update.status {
            SendPaymentStatus::Success(preimage) => {
                (true, Some(preimage.as_slice().to_lower_hex_string()))
            }
            SendPaymentStatus::Refunded => (false, None),
        };

        return Some(ParsedEvent::Update {
            operation_id: update.operation_id,
            success,
            txid: None,
            preimage,
        });
    }

    if let Some(receive) = parse::<fedimint_lnv2_client::events::ReceivePaymentEvent>(entry) {
        return Some(ParsedEvent::Payment {
            operation_id: receive.operation_id,
            payment: ConduitPayment {
                operation_id: receive.operation_id.fmt_full().to_string(),
                incoming: true,
                payment_type: PaymentType::Lightning,
                amount_sats: (receive.amount.msats / 1000) as i64,
                fee_sats: None,
                timestamp: (entry.ts_usecs / 1000) as i64,
                success: Some(true),
                ecash: None,
                txid: None,
                address: None,
                fiat_amount: None,
                fiat_currency_code: None,
                preimage: None,
            },
        });
    }

    if let Some(send) = parse::<fedimint_mint_client::events::SendPaymentEvent>(entry) {
        return Some(ParsedEvent::Payment {
            operation_id: send.operation_id,
            payment: ConduitPayment {
                operation_id: send.operation_id.fmt_full().to_string(),
                incoming: false,
                payment_type: PaymentType::Ecash,
                amount_sats: (send.amount.msats / 1000) as i64,
                fee_sats: None,
                timestamp: (entry.ts_usecs / 1000) as i64,
                success: Some(true),
                ecash: Some(send.oob_notes),
                txid: None,
                address: None,
                fiat_amount: None,
                fiat_currency_code: None,
                preimage: None,
            },
        });
    }

    if let Some(receive) = parse::<fedimint_mint_client::events::ReceivePaymentEvent>(entry) {
        return Some(ParsedEvent::Payment {
            operation_id: receive.operation_id,
            payment: ConduitPayment {
                operation_id: receive.operation_id.fmt_full().to_string(),
                incoming: true,
                payment_type: PaymentType::Ecash,
                amount_sats: (receive.amount.msats / 1000) as i64,
                fee_sats: None,
                timestamp: (entry.ts_usecs / 1000) as i64,
                success: None,
                ecash: None,
                txid: None,
                address: None,
                fiat_amount: None,
                fiat_currency_code: None,
                preimage: None,
            },
        });
    }

    if let Some(update) = parse::<fedimint_mint_client::events::ReceivePaymentUpdateEvent>(entry) {
        return Some(ParsedEvent::Update {
            operation_id: update.operation_id,
            success: matches!(update.status, ReceivePaymentStatus::Success),
            txid: None,
            preimage: None,
        });
    }

    if let Some(send) = parse::<fedimint_wallet_client::events::SendPaymentEvent>(entry) {
        return Some(ParsedEvent::Payment {
            operation_id: send.operation_id,
            payment: ConduitPayment {
                operation_id: send.operation_id.fmt_full().to_string(),
                incoming: false,
                payment_type: PaymentType::Bitcoin,
                amount_sats: send.amount.to_sat() as i64,
                fee_sats: Some(send.fee.to_sat() as i64),
                timestamp: (entry.ts_usecs / 1000) as i64,
                success: None,
                ecash: None,
                txid: None,
                address: None,
                fiat_amount: None,
                fiat_currency_code: None,
                preimage: None,
            },
        });
    }

    if let Some(status) = parse::<fedimint_wallet_client::events::SendPaymentStatusEvent>(entry) {
        let (success, txid) = match status.status {
            WalletSendPaymentStatus::Success(txid) => (true, Some(txid.to_string())),
            WalletSendPaymentStatus::Aborted => (false, None),
        };

        return Some(ParsedEvent::Update {
            operation_id: status.operation_id,
            success,
            txid,
            preimage: None,
        });
    }

    if let Some(receive) = parse::<fedimint_wallet_client::events::ReceivePaymentEvent>(entry) {
        return Some(ParsedEvent::Payment {
            operation_id: receive.operation_id,
            payment: ConduitPayment {
                operation_id: receive.operation_id.fmt_full().to_string(),
                incoming: true,
                payment_type: PaymentType::Bitcoin,
                amount_sats: (receive.amount.msats / 1000) as i64,
                fee_sats: None,
                timestamp: (entry.ts_usecs / 1000) as i64,
                success: Some(true),
                ecash: None,
                txid: Some(receive.txid.to_string()),
                address: None,
                fiat_amount: None,
                fiat_currency_code: None,
                preimage: None,
            },
        });
    }

    // MintV2 events

    if let Some(send) = parse::<fedimint_mintv2_client::SendPaymentEvent>(entry) {
        return Some(ParsedEvent::Payment {
            operation_id: send.operation_id,
            payment: ConduitPayment {
                operation_id: send.operation_id.fmt_full().to_string(),
                incoming: false,
                payment_type: PaymentType::Ecash,
                amount_sats: (send.amount.msats / 1000) as i64,
                fee_sats: None,
                timestamp: (entry.ts_usecs / 1000) as i64,
                success: Some(true),
                ecash: Some(send.ecash),
                txid: None,
                address: None,
                fiat_amount: None,
                fiat_currency_code: None,
                preimage: None,
            },
        });
    }

    if let Some(receive) = parse::<fedimint_mintv2_client::ReceivePaymentEvent>(entry) {
        return Some(ParsedEvent::Payment {
            operation_id: receive.operation_id,
            payment: ConduitPayment {
                operation_id: receive.operation_id.fmt_full().to_string(),
                incoming: true,
                payment_type: PaymentType::Ecash,
                amount_sats: (receive.amount.msats / 1000) as i64,
                fee_sats: None,
                timestamp: (entry.ts_usecs / 1000) as i64,
                success: None,
                ecash: None,
                txid: None,
                address: None,
                fiat_amount: None,
                fiat_currency_code: None,
                preimage: None,
            },
        });
    }

    if let Some(update) = parse::<fedimint_mintv2_client::ReceivePaymentUpdateEvent>(entry) {
        return Some(ParsedEvent::Update {
            operation_id: update.operation_id,
            success: matches!(update.status, MintV2ReceivePaymentStatus::Success),
            txid: None,
            preimage: None,
        });
    }

    // WalletV2 events

    if let Some(send) = parse::<fedimint_walletv2_client::events::SendPaymentEvent>(entry) {
        return Some(ParsedEvent::Payment {
            operation_id: send.operation_id,
            payment: ConduitPayment {
                operation_id: send.operation_id.fmt_full().to_string(),
                incoming: false,
                payment_type: PaymentType::Bitcoin,
                amount_sats: send.value.to_sat() as i64,
                fee_sats: Some(send.fee.to_sat() as i64),
                timestamp: (entry.ts_usecs / 1000) as i64,
                success: None,
                ecash: None,
                txid: None,
                address: Some(send.address.clone().assume_checked().to_string()),
                fiat_amount: None,
                fiat_currency_code: None,
                preimage: None,
            },
        });
    }

    if let Some(status) = parse::<fedimint_walletv2_client::events::SendPaymentUpdateEvent>(entry) {
        let (success, txid) = match status.status {
            WalletV2SendPaymentStatus::Success(txid) => (true, Some(txid.to_string())),
            WalletV2SendPaymentStatus::Aborted => (false, None),
        };

        return Some(ParsedEvent::Update {
            operation_id: status.operation_id,
            success,
            txid,
            preimage: None,
        });
    }

    if let Some(receive) = parse::<fedimint_walletv2_client::events::ReceivePaymentEvent>(entry) {
        return Some(ParsedEvent::Payment {
            operation_id: receive.operation_id,
            payment: ConduitPayment {
                operation_id: receive.operation_id.fmt_full().to_string(),
                incoming: true,
                payment_type: PaymentType::Bitcoin,
                amount_sats: receive.value.to_sat() as i64,
                fee_sats: Some(receive.fee.to_sat() as i64),
                timestamp: (entry.ts_usecs / 1000) as i64,
                success: None,
                ecash: None,
                txid: None,
                address: Some(receive.address.clone().assume_checked().to_string()),
                fiat_amount: None,
                fiat_currency_code: None,
                preimage: None,
            },
        });
    }

    if let Some(status) =
        parse::<fedimint_walletv2_client::events::ReceivePaymentUpdateEvent>(entry)
    {
        return Some(ParsedEvent::Update {
            operation_id: status.operation_id,
            success: matches!(status.status, WalletV2ReceivePaymentStatus::Success),
            txid: None,
            preimage: None,
        });
    }

    None
}

fn parse<T: Event>(entry: &EventLogEntry) -> Option<T> {
    if entry.module.clone().map(|m| m.0) != T::MODULE {
        return None;
    }

    if entry.kind != T::KIND {
        return None;
    }

    serde_json::from_slice::<T>(&entry.payload).ok()
}
