use fedimint_core::module::serde_json;
use fedimint_eventlog::{Event, EventLogEntry};
use fedimint_lnv2_client::events::SendPaymentStatus;
use fedimint_mint_client::event::ReceivePaymentStatus;
use fedimint_mintv2_client::ReceivePaymentStatus as MintV2ReceivePaymentStatus;
use fedimint_wallet_client::events::SendPaymentStatus as WalletSendPaymentStatus;
use fedimint_walletv2_client::events::{
    ReceivePaymentStatus as WalletV2ReceivePaymentStatus,
    SendPaymentStatus as WalletV2SendPaymentStatus,
};
use flutter_rust_bridge::frb;

/// Type of payment
#[frb]
pub enum PaymentType {
    Lightning,
    Bitcoin,
    Ecash,
}

/// Payment event - emitted when a payment is initiated or completes
#[frb]
pub struct ConduitPayment {
    pub operation_id: String,
    pub incoming: bool,
    pub payment_type: PaymentType,
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

pub(crate) fn parse_event_log_entry(entry: &EventLogEntry) -> Option<ConduitEvent> {
    // Try to deserialize as SendPaymentEvent
    if let Some(send) = parse::<fedimint_lnv2_client::events::SendPaymentEvent>(entry) {
        return Some(ConduitEvent::Event(ConduitPayment {
            operation_id: format!("lnv2_{}", send.operation_id.fmt_short()),
            incoming: false,
            payment_type: PaymentType::Lightning,
            amount_sats: (send.amount.msats / 1000) as i64,
            fee_sats: send.fee.map(|fee| (fee.msats / 1000) as i64),
            timestamp: (entry.ts_usecs / 1000) as i64,
            success: None,
            oob: None,
        }));
    }

    // Try to deserialize as SendPaymentUpdateEvent
    if let Some(update) = parse::<fedimint_lnv2_client::events::SendPaymentUpdateEvent>(entry) {
        return Some(ConduitEvent::Update(ConduitUpdate {
            operation_id: format!("lnv2_{}", update.operation_id.fmt_short()),
            timestamp: (entry.ts_usecs / 1000) as i64,
            success: matches!(update.status, SendPaymentStatus::Success(_)),
            oob: None,
        }));
    }

    // Try to deserialize as ReceivePaymentEvent
    if let Some(receive) = parse::<fedimint_lnv2_client::events::ReceivePaymentEvent>(entry) {
        return Some(ConduitEvent::Event(ConduitPayment {
            operation_id: format!("lnv2_{}", receive.operation_id.fmt_short()),
            incoming: true,
            payment_type: PaymentType::Lightning,
            amount_sats: (receive.amount.msats / 1000) as i64,
            fee_sats: None,
            timestamp: (entry.ts_usecs / 1000) as i64,
            success: Some(true),
            oob: None,
        }));
    }

    // Try to deserialize as MintSendPaymentEvent
    if let Some(send) = parse::<fedimint_mint_client::event::SendPaymentEvent>(entry) {
        return Some(ConduitEvent::Event(ConduitPayment {
            operation_id: format!("mint_{}", send.operation_id.fmt_short()),
            incoming: false,
            payment_type: PaymentType::Ecash,
            amount_sats: (send.amount.msats / 1000) as i64,
            fee_sats: None,
            timestamp: (entry.ts_usecs / 1000) as i64,
            success: Some(true),
            oob: Some(send.oob_notes),
        }));
    }

    // Try to deserialize as MintReceivePaymentEvent
    if let Some(receive) = parse::<fedimint_mint_client::event::ReceivePaymentEvent>(entry) {
        return Some(ConduitEvent::Event(ConduitPayment {
            operation_id: format!("mint_{}", receive.operation_id.fmt_short()),
            incoming: true,
            payment_type: PaymentType::Ecash,
            amount_sats: (receive.amount.msats / 1000) as i64,
            fee_sats: None,
            timestamp: (entry.ts_usecs / 1000) as i64,
            success: None,
            oob: None,
        }));
    }

    // Try to deserialize as MintReceivePaymentUpdateEvent
    if let Some(update) = parse::<fedimint_mint_client::event::ReceivePaymentUpdateEvent>(entry) {
        return Some(ConduitEvent::Update(ConduitUpdate {
            operation_id: format!("mint_{}", update.operation_id.fmt_short()),
            timestamp: (entry.ts_usecs / 1000) as i64,
            success: matches!(update.status, ReceivePaymentStatus::Success),
            oob: None,
        }));
    }

    // Try to deserialize as WalletSendPaymentEvent
    if let Some(send) = parse::<fedimint_wallet_client::events::SendPaymentEvent>(entry) {
        return Some(ConduitEvent::Event(ConduitPayment {
            operation_id: format!("wallet_{}", send.operation_id.fmt_short()),
            incoming: false,
            payment_type: PaymentType::Bitcoin,
            amount_sats: send.amount.to_sat() as i64,
            fee_sats: Some(send.fee.to_sat() as i64),
            timestamp: (entry.ts_usecs / 1000) as i64,
            success: None,
            oob: None,
        }));
    }

    // Try to deserialize as WalletSendPaymentStatusEvent
    if let Some(status) = parse::<fedimint_wallet_client::events::SendPaymentStatusEvent>(entry) {
        let (success, oob) = match status.status {
            WalletSendPaymentStatus::Success(txid) => (true, Some(txid.to_string())),
            WalletSendPaymentStatus::Aborted => (false, None),
        };

        return Some(ConduitEvent::Update(ConduitUpdate {
            operation_id: format!("wallet_{}", status.operation_id.fmt_short()),
            timestamp: (entry.ts_usecs / 1000) as i64,
            success,
            oob,
        }));
    }

    // Try to deserialize as WalletReceivePaymentEvent
    if let Some(receive) = parse::<fedimint_wallet_client::events::ReceivePaymentEvent>(entry) {
        return Some(ConduitEvent::Event(ConduitPayment {
            operation_id: format!("wallet_{}", receive.operation_id.fmt_short()),
            incoming: true,
            payment_type: PaymentType::Bitcoin,
            amount_sats: (receive.amount.msats / 1000) as i64,
            fee_sats: None,
            timestamp: (entry.ts_usecs / 1000) as i64,
            success: Some(true),
            oob: Some(receive.txid.to_string()),
        }));
    }

    // MintV2 events

    if let Some(send) = parse::<fedimint_mintv2_client::SendPaymentEvent>(entry) {
        return Some(ConduitEvent::Event(ConduitPayment {
            operation_id: format!("mintv2_{}", send.operation_id.fmt_short()),
            incoming: false,
            payment_type: PaymentType::Ecash,
            amount_sats: (send.amount.msats / 1000) as i64,
            fee_sats: None,
            timestamp: (entry.ts_usecs / 1000) as i64,
            success: Some(true),
            oob: Some(send.ecash),
        }));
    }

    if let Some(receive) = parse::<fedimint_mintv2_client::ReceivePaymentEvent>(entry) {
        return Some(ConduitEvent::Event(ConduitPayment {
            operation_id: format!("mintv2_{}", receive.operation_id.fmt_short()),
            incoming: true,
            payment_type: PaymentType::Ecash,
            amount_sats: (receive.amount.msats / 1000) as i64,
            fee_sats: None,
            timestamp: (entry.ts_usecs / 1000) as i64,
            success: None,
            oob: None,
        }));
    }

    if let Some(update) =
        parse::<fedimint_mintv2_client::ReceivePaymentUpdateEvent>(entry)
    {
        return Some(ConduitEvent::Update(ConduitUpdate {
            operation_id: format!("mintv2_{}", update.operation_id.fmt_short()),
            timestamp: (entry.ts_usecs / 1000) as i64,
            success: matches!(update.status, MintV2ReceivePaymentStatus::Success),
            oob: None,
        }));
    }

    // WalletV2 events

    if let Some(send) = parse::<fedimint_walletv2_client::events::SendPaymentEvent>(entry) {
        return Some(ConduitEvent::Event(ConduitPayment {
            operation_id: format!("walletv2_{}", send.operation_id.fmt_short()),
            incoming: false,
            payment_type: PaymentType::Bitcoin,
            amount_sats: send.amount.to_sat() as i64,
            fee_sats: Some(send.fee.to_sat() as i64),
            timestamp: (entry.ts_usecs / 1000) as i64,
            success: None,
            oob: None,
        }));
    }

    if let Some(status) =
        parse::<fedimint_walletv2_client::events::SendPaymentStatusEvent>(entry)
    {
        let (success, oob) = match status.status {
            WalletV2SendPaymentStatus::Success(txid) => (true, Some(txid.to_string())),
            WalletV2SendPaymentStatus::Aborted => (false, None),
        };

        return Some(ConduitEvent::Update(ConduitUpdate {
            operation_id: format!("walletv2_{}", status.operation_id.fmt_short()),
            timestamp: (entry.ts_usecs / 1000) as i64,
            success,
            oob,
        }));
    }

    if let Some(receive) =
        parse::<fedimint_walletv2_client::events::ReceivePaymentEvent>(entry)
    {
        return Some(ConduitEvent::Event(ConduitPayment {
            operation_id: format!("walletv2_{}", receive.operation_id.fmt_short()),
            incoming: true,
            payment_type: PaymentType::Bitcoin,
            amount_sats: receive.amount.to_sat() as i64,
            fee_sats: Some(receive.fee.to_sat() as i64),
            timestamp: (entry.ts_usecs / 1000) as i64,
            success: None,
            oob: None,
        }));
    }

    if let Some(status) =
        parse::<fedimint_walletv2_client::events::ReceivePaymentStatusEvent>(entry)
    {
        return Some(ConduitEvent::Update(ConduitUpdate {
            operation_id: format!("walletv2_{}", status.operation_id.fmt_short()),
            timestamp: (entry.ts_usecs / 1000) as i64,
            success: matches!(status.status, WalletV2ReceivePaymentStatus::Success),
            oob: None,
        }));
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
