use fedimint_core::module::serde_json;
use fedimint_eventlog::{Event, EventLogEntry};
use fedimint_lnv2_client::events::SendPaymentStatus;
use fedimint_mint_client::event::ReceivePaymentStatus;
use fedimint_wallet_client::events::SendPaymentStatus as WalletSendPaymentStatus;
use flutter_rust_bridge::frb;

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
    pub oob: Option<String>,
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
    Payment(ConduitPayment),
    Update {
        operation_id: String,
        success: bool,
        oob: Option<String>,
    },
}

/// Fold an update into a payment list by operation_id
pub(crate) fn apply_update(
    payments: &mut [ConduitPayment],
    operation_id: &str,
    success: bool,
    oob: Option<String>,
) -> Option<PaymentNotification> {
    let payment = payments
        .iter_mut()
        .rfind(|p| p.operation_id == operation_id)?;

    payment.success = Some(success);
    payment.oob = oob;

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
        return Some(ParsedEvent::Payment(ConduitPayment {
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

    if let Some(update) = parse::<fedimint_lnv2_client::events::SendPaymentUpdateEvent>(entry) {
        return Some(ParsedEvent::Update {
            operation_id: format!("lnv2_{}", update.operation_id.fmt_short()),
            success: matches!(update.status, SendPaymentStatus::Success(_)),
            oob: None,
        });
    }

    if let Some(receive) = parse::<fedimint_lnv2_client::events::ReceivePaymentEvent>(entry) {
        return Some(ParsedEvent::Payment(ConduitPayment {
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

    if let Some(send) = parse::<fedimint_mint_client::event::SendPaymentEvent>(entry) {
        return Some(ParsedEvent::Payment(ConduitPayment {
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

    if let Some(receive) = parse::<fedimint_mint_client::event::ReceivePaymentEvent>(entry) {
        return Some(ParsedEvent::Payment(ConduitPayment {
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

    if let Some(update) = parse::<fedimint_mint_client::event::ReceivePaymentUpdateEvent>(entry) {
        return Some(ParsedEvent::Update {
            operation_id: format!("mint_{}", update.operation_id.fmt_short()),
            success: matches!(update.status, ReceivePaymentStatus::Success),
            oob: None,
        });
    }

    if let Some(send) = parse::<fedimint_wallet_client::events::SendPaymentEvent>(entry) {
        return Some(ParsedEvent::Payment(ConduitPayment {
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

    if let Some(status) = parse::<fedimint_wallet_client::events::SendPaymentStatusEvent>(entry) {
        let (success, oob) = match status.status {
            WalletSendPaymentStatus::Success(txid) => (true, Some(txid.to_string())),
            WalletSendPaymentStatus::Aborted => (false, None),
        };

        return Some(ParsedEvent::Update {
            operation_id: format!("wallet_{}", status.operation_id.fmt_short()),
            success,
            oob,
        });
    }

    if let Some(receive) = parse::<fedimint_wallet_client::events::ReceivePaymentEvent>(entry) {
        return Some(ParsedEvent::Payment(ConduitPayment {
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
