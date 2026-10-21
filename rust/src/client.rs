use fedimint_client::{ClientHandleArc, OperationId};
use fedimint_core::Amount;
use fedimint_core::config::FederationId;
use fedimint_core::db::{Database, IDatabaseTransactionOpsCoreTyped};
use fedimint_core::module::AmountUnit;
use fedimint_core::module::serde_json;
use fedimint_core::util::SafeUrl;
use fedimint_eventlog::EventLogId;
use fedimint_lnv2_client::LightningClientModule;
use fedimint_lnv2_client::common::Bolt11InvoiceDescription;
use fedimint_mint_client::MintClientModule;
use fedimint_mintv2_client::MintClientModule as MintV2ClientModule;
use fedimint_wallet_client::client_db::TweakIdx;
use fedimint_wallet_client::{WalletClientModule, WalletOperationMeta, WalletOperationMetaVariant};
use fedimint_walletv2_client::WalletClientModule as WalletV2ClientModule;
use flutter_rust_bridge::frb;
use futures_util::StreamExt;

use std::str::FromStr;
use std::sync::{Arc, Mutex};

use crate::account::Account;
use crate::db::{EventLogEntryKey, EventLogEntryPrefix, OperationFiatKey};
use crate::events::{
    ConduitPayment, ParsedEvent, PaymentNotification, RecentPaymentsUpdate, apply_update,
    parse_event_log_entry, snapshot,
};
use crate::exchange::{EXCHANGE_RATE_TTL, ExchangeRateCache, fetch_exchange_rate};
use crate::frb_generated::StreamSink;
use crate::{
    BitcoinAddressWrapper, Bolt11InvoiceWrapper, ECashWrapper, EcashToken, InviteCodeWrapper,
};
use fedimint_eventlog::EventLogEntry;

#[frb]
pub struct FederationStats {
    pub total_value_sat: i64,
    pub block_count: i64,
    pub feerate: Option<i64>,
}

#[frb]
pub struct LnSendFees {
    pub gateway_url: String,
    pub fee_sats: i64,
    /// Whether the payment is settled as a direct swap between fedimints rather
    /// than routed over the lightning network. True when the invoice's payee is
    /// the selected gateway's own lightning node.
    pub is_direct: bool,
}

#[frb]
pub struct LnReceiveInvoice {
    pub invoice: String,
    pub gateway_url: String,
    pub fee_sats: i64,
}

/// One account's view onto a mint: the five views of a mint share its one
/// fedimint client and differ only in the account they hand to it.
#[frb]
#[derive(Clone)]
pub struct ConduitClient {
    pub(crate) client: ClientHandleArc,
    pub(crate) db: Database,
    pub(crate) federation_id: FederationId,
    pub(crate) account: Account,
    /// The mint's name from its config, or its id prefix when it has none.
    pub(crate) name: String,
    pub(crate) instance_id: u64,
    pub(crate) currency_code: Arc<Mutex<String>>,
    pub(crate) exchange_rate_cache: ExchangeRateCache,
}

impl ConduitClient {
    #[frb(sync)]
    pub fn federation_name(&self) -> String {
        self.name.clone()
    }

    #[frb(sync)]
    pub fn federation_id(&self) -> FederationId {
        self.federation_id
    }

    #[frb(sync)]
    pub fn account(&self) -> Account {
        self.account
    }

    /// The federation id as hex, for keying by federation on the Dart side,
    /// where the id itself is opaque.
    #[frb(sync)]
    pub fn federation_id_hex(&self) -> String {
        self.federation_id.to_string()
    }

    /// Tells one open of an account from the next. Every `clients()`
    /// snapshot hands Dart fresh handles, so this is how the home screen
    /// knows a client was reopened (after a recovery) rather than re-listed,
    /// and that its streams need re-subscribing.
    #[frb(sync)]
    pub fn instance_id(&self) -> u64 {
        self.instance_id
    }

    #[frb(sync)]
    pub fn currency_code(&self) -> String {
        self.currency_code.lock().unwrap().clone()
    }

    #[frb]
    pub async fn shutdown(&self) {
        self.client.executor().stop_executor();
        self.client
            .task_group()
            .clone()
            .shutdown_join_all(None)
            .await
            .expect("Client shutdown failed");
    }

    /// Warms the exchange rate cache so a subsequent [`Self::sats_to_fiat`] can
    /// convert without a network round trip. Awaits the fetch so callers can
    /// rebuild once a rate is on hand; errors are ignored since this is only a
    /// best-effort prefetch.
    #[frb]
    pub async fn prefetch_exchange_rates(&self) {
        let currency_code = self.currency_code.lock().unwrap().clone();
        let _ = fetch_exchange_rate(self.exchange_rate_cache.clone(), currency_code).await;
    }

    #[frb]
    pub async fn fiat_to_sats(&self, amount_fiat: f64) -> Result<i64, String> {
        let currency_code = self.currency_code.lock().unwrap().clone();
        fetch_exchange_rate(self.exchange_rate_cache.clone(), currency_code)
            .await
            .map(|r| ((amount_fiat / r) * 100_000_000.0).round() as i64)
    }

    /// Converts `amount_sats` to the user's fiat currency using the cached
    /// exchange rate, without triggering a network fetch. Returns `None` when
    /// no fresh rate has been cached yet (or the cache is momentarily locked) so
    /// callers can show fiat opportunistically without blocking on the network.
    #[frb(sync)]
    pub fn sats_to_fiat(&self, amount_sats: i64) -> Option<f64> {
        let guard = self.exchange_rate_cache.try_lock().ok()?;
        if let Some((rate, timestamp)) = guard.as_ref() {
            if timestamp.elapsed() < EXCHANGE_RATE_TTL {
                return Some((amount_sats as f64 / 100_000_000.0) * rate);
            }
        }
        None
    }

    /// Freezes the current exchange rate against `operation_id` so history can
    /// later show the fiat value as of the time of the payment. Uses only the
    /// cached rate — never the network — and is a no-op when no fresh rate is
    /// cached (the payment simply shows no fiat) or a snapshot already exists.
    /// The rate is snapshotted in `self.currency_code`, the same currency the
    /// cache was fetched against, so the stored code and rate can never disagree.
    async fn snapshot_fiat(&self, operation_id: OperationId) {
        let rate = {
            let Ok(guard) = self.exchange_rate_cache.try_lock() else {
                return;
            };

            match guard.as_ref() {
                Some((rate, timestamp)) if timestamp.elapsed() < EXCHANGE_RATE_TTL => *rate,
                _ => return,
            }
        };

        let currency_code = self.currency_code.lock().unwrap().clone();

        let mut dbtx = self.db.begin_transaction().await;

        if dbtx
            .get_value(&OperationFiatKey(operation_id))
            .await
            .is_none()
        {
            dbtx.insert_entry(
                &OperationFiatKey(operation_id),
                &(currency_code, rate.to_be_bytes()),
            )
            .await;

            dbtx.commit_tx().await;
        }
    }

    /// Fills `payment`'s fiat fields from the rate snapshotted at payment time,
    /// converting `amount_sats` at that frozen BTC price. Leaves them `None`
    /// when no snapshot was recorded for the operation.
    async fn attach_fiat(&self, payment: &mut ConduitPayment, operation_id: OperationId) {
        let Some((currency_code, rate_bytes)) = self
            .db
            .begin_transaction_nc()
            .await
            .get_value(&OperationFiatKey(operation_id))
            .await
        else {
            return;
        };

        let rate = f64::from_be_bytes(rate_bytes);

        payment.fiat_amount = Some((payment.amount_sats as f64 / 100_000_000.0) * rate);
        payment.fiat_currency_code = Some(currency_code);
    }

    #[frb]
    pub async fn subscribe_balance(&self, sink: StreamSink<i64>) {
        let mut stream = self
            .client
            .subscribe_balance_changes(AmountUnit::bitcoin(), self.account.into())
            .await;

        while let Some(amount) = stream.next().await {
            if sink.add((amount.msats / 1000) as i64).is_err() {
                break;
            }
        }
    }

    /// Every event log entry stored for this mint, in log order: one log for
    /// all five accounts, since they share the client. Each entry names its
    /// account; the caller keeps the ones it is a view of.
    async fn stored_event_log(&self) -> Vec<(EventLogId, EventLogEntry)> {
        self.db
            .begin_transaction_nc()
            .await
            .find_by_prefix(&EventLogEntryPrefix(self.federation_id))
            .await
            .map(|(key, entry)| (key.1, entry))
            .collect()
            .await
    }

    /// Stores an event log entry under the mint's key. Only Primary's view
    /// writes: every view walks the same log, and one writer means no two
    /// transactions ever race on the same entry. The others still read the
    /// client's own log past whatever is stored, so they lag nothing. Fails
    /// only when the database is shutting down.
    async fn store_event_log_entry(&self, id: EventLogId, entry: &EventLogEntry) -> bool {
        if self.account != Account::Primary {
            return true;
        }

        let mut dbtx = self.db.begin_transaction().await;

        dbtx.insert_entry(&EventLogEntryKey(self.federation_id, id), entry)
            .await;

        dbtx.commit_tx_result().await.is_ok()
    }

    /// A module from before accounts keeps one balance, Primary's. Refused
    /// up front for any other view, before anything is handed out or spent
    /// on its behalf.
    fn ensure_primary(&self) -> Result<(), String> {
        match self.account {
            Account::Primary => Ok(()),
            _ => Err("This mint keeps a single account".to_string()),
        }
    }

    #[frb]
    pub async fn subscribe_connection_status(&self, sink: StreamSink<Vec<(String, bool)>>) {
        let names: Vec<String> = self
            .client
            .config()
            .await
            .global
            .api_endpoints
            .iter()
            .map(|(_, peer)| peer.name.clone())
            .collect();

        let mut stream = self.client.connection_status_stream();

        while let Some(status_map) = stream.next().await {
            let statuses: Vec<(String, bool)> = names
                .iter()
                .zip(status_map.into_values())
                .map(|(name, status)| {
                    (
                        name.clone(),
                        matches!(status, fedimint_connectors::PeerStatus::Connected(_)),
                    )
                })
                .collect();

            if sink.add(statuses).is_err() {
                break;
            }
        }
    }

    #[frb(sync)]
    pub fn has_pending_recoveries(&self) -> bool {
        self.client.has_pending_recoveries()
    }

    /// Whether every module can be used right now. `false` while a module that
    /// cannot operate mid-recovery is held out of the registry, in which case
    /// the app must wait for the recovery and reopen; `true` when a recovery is
    /// running but the wallet is already usable (e.g. mintv2/walletv2).
    #[frb(sync)]
    pub fn all_modules_usable(&self) -> bool {
        self.client.all_modules_usable()
    }

    #[frb]
    pub async fn expiration_date(&self) -> Option<i64> {
        self.client
            .meta_service()
            .get_field::<u64>(self.client.db(), "federation_expiry_timestamp")
            .await
            .and_then(|mv| mv.value)
            .map(|ts| ts as i64)
    }

    #[frb]
    pub async fn expiration_successor(&self) -> Option<InviteCodeWrapper> {
        self.client
            .meta_service()
            .get_field::<String>(self.client.db(), "federation_successor")
            .await
            .and_then(|mv| mv.value)
            .and_then(|s| fedimint_core::invite_code::InviteCode::from_str(&s).ok())
            .map(InviteCodeWrapper)
    }

    #[frb]
    pub async fn wait_for_all_recoveries(&self) -> Result<(), String> {
        self.client
            .wait_for_all_recoveries()
            .await
            .map_err(|e| e.to_string())
    }

    /// Streams the overall recovery progress as a percentage (0..=100).
    ///
    /// Each module reports its own scan progress; the overall figure is the
    /// least-advanced module, so it never runs ahead of the slowest recovery.
    /// The underlying stream re-emits every recovering module on each tick, so
    /// the minimum is taken over the full set rather than a single module.
    #[frb]
    pub async fn subscribe_recovery_progress(&self, sink: StreamSink<i64>) {
        let mut latest: std::collections::HashMap<u16, (u32, u32)> =
            std::collections::HashMap::new();

        let mut stream = self.client.subscribe_to_recovery_progress();

        while let Some((module_id, progress)) = stream.next().await {
            latest.insert(module_id, (progress.complete, progress.total));

            let percent = latest
                .values()
                .map(|(complete, total)| match total {
                    // A module reports (0, 0) before its scan bound is known, so
                    // treat a not-yet-started module as 0%, not complete.
                    0 => 0,
                    total => (*complete as u64 * 100 / *total as u64) as i64,
                })
                .min()
                .unwrap_or(0);

            if sink.add(percent).is_err() {
                break;
            }
        }
    }

    #[frb]
    pub async fn ecash_send(&self, amount_sat: i64) -> Result<ECashWrapper, String> {
        let amount = Amount::from_sats(amount_sat as u64);

        if let Ok(module) = self.client.get_first_module::<MintV2ClientModule>() {
            return module
                .send(self.account.into(), amount, serde_json::Value::Null, false)
                .await
                .map(|(_, ecash)| ECashWrapper(EcashToken::V2(ecash)))
                .map_err(|e| e.to_string());
        }

        self.ensure_primary()?;

        self.client
            .get_first_module::<MintClientModule>()
            .unwrap()
            .send_oob_notes(amount, ())
            .await
            .map(|notes| ECashWrapper(EcashToken::V1(notes)))
            .map_err(|e| e.to_string())
    }

    /// Everything the account holds, as one bundle of the notes themselves:
    /// no transaction and no fee, which `ecash_send` with the balance as its
    /// amount could not promise. Mint v2 only: a legacy mint cannot offer it
    /// and says so.
    #[frb]
    pub async fn ecash_send_max(&self) -> Result<ECashWrapper, String> {
        self.client
            .get_first_module::<MintV2ClientModule>()
            .map_err(|_| "This mint does not support sending the full balance".to_string())?
            .send_max(self.account.into(), serde_json::Value::Null, false)
            .await
            .map(|(_, ecash)| ECashWrapper(EcashToken::V2(ecash)))
            .ok_or_else(|| "This account is empty".to_string())
    }

    #[frb]
    pub async fn ecash_receive(&self, notes: &ECashWrapper) -> Result<(), String> {
        match &notes.0 {
            EcashToken::V2(ecash) => self
                .client
                .get_first_module::<MintV2ClientModule>()
                .map_err(|e| e.to_string())?
                .receive(self.account.into(), ecash.clone(), serde_json::Value::Null)
                .await
                .map(|_| ())
                .map_err(|e| e.to_string()),
            EcashToken::V1(oob) => {
                self.ensure_primary()?;

                self.client
                    .get_first_module::<MintClientModule>()
                    .map_err(|e| e.to_string())?
                    .reissue_external_notes(oob.clone(), ())
                    .await
                    .map(|_| ())
                    .map_err(|e| e.to_string())
            }
        }
    }

    /// Generates an invoice to receive `amount_sat`. The gateway is selected up
    /// front so the gateway and its (deducted) receive fee can be shown
    /// alongside the invoice; the same gateway is then used to mint it. The
    /// recipient receives `amount_sat` minus `fee_sats`.
    #[frb]
    pub async fn ln_receive(&self, amount_sat: i64) -> Result<LnReceiveInvoice, String> {
        let module = self
            .client
            .get_first_module::<LightningClientModule>()
            .unwrap();

        let (gateway, routing_info) = module
            .select_gateway(None)
            .await
            .map_err(|e| e.to_string())?;

        let amount = Amount::from_sats(amount_sat as u64);

        let fee_sats = routing_info
            .receive_fee
            .fee(amount.msats)
            .msats
            .div_ceil(1000) as i64;

        let invoice = module
            .receive(
                self.account.into(),
                amount,
                60 * 60 * 24,
                Bolt11InvoiceDescription::Direct(String::new()),
                Some(gateway.clone()),
                ().into(),
            )
            .await
            .map_err(|e| e.to_string())?
            .0;

        Ok(LnReceiveInvoice {
            invoice: invoice.to_string(),
            gateway_url: gateway.to_string(),
            fee_sats,
        })
    }

    /// Selects the gateway that would auto-route this invoice and quotes the
    /// fee for it, mirroring the selection [`Self::ln_send`] performs with
    /// `None`. Intended for display on the send confirmation screen; the actual
    /// fee charged is fixed when the payment is submitted.
    #[frb]
    pub async fn ln_calculate_fees(
        &self,
        invoice: &Bolt11InvoiceWrapper,
    ) -> Result<LnSendFees, String> {
        let module = self
            .client
            .get_first_module::<LightningClientModule>()
            .unwrap();

        let (gateway, routing_info) = module
            .select_gateway(Some(invoice.0.clone()))
            .await
            .map_err(|e| e.to_string())?;

        let amount_msats = invoice
            .0
            .amount_milli_satoshis()
            .ok_or("Invoice has no amount")?;

        let (send_fee, _) = routing_info.send_parameters(&invoice.0);

        let fee_sats = send_fee.fee(amount_msats).msats.div_ceil(1000) as i64;

        // A direct swap settles between fedimints when the invoice's payee is
        // the gateway's own lightning node; otherwise it routes over lightning.
        let is_direct = invoice.0.recover_payee_pub_key() == routing_info.lightning_public_key;

        Ok(LnSendFees {
            gateway_url: gateway.to_string(),
            fee_sats,
            is_direct,
        })
    }

    /// Sends a payment for `invoice`. When `gateway` is `Some`, that gateway
    /// (as returned by [`Self::ln_calculate_fees`]) is used directly so the fee
    /// quoted on the confirmation screen matches what is charged; `None` lets
    /// the module auto-select.
    #[frb]
    pub async fn ln_send(
        &self,
        invoice: &Bolt11InvoiceWrapper,
        gateway: Option<String>,
    ) -> Result<OperationId, String> {
        let gateway = match gateway {
            Some(url) => Some(SafeUrl::parse(&url).map_err(|e| e.to_string())?),
            None => None,
        };

        self.client
            .get_first_module::<LightningClientModule>()
            .unwrap()
            .send(self.account.into(), invoice.0.clone(), gateway, ().into())
            .await
            .map_err(|e| e.to_string())
    }

    #[frb]
    pub async fn lnurl(&self) -> Result<String, String> {
        let recurringd = SafeUrl::parse("https://lnurl.fedimint.org").unwrap();

        self.client
            .get_first_module::<LightningClientModule>()
            .unwrap()
            .generate_lnurl(self.account.into(), recurringd, None)
            .await
            .map_err(|e| e.to_string())
    }

    #[frb]
    pub async fn onchain_calculate_fees(
        &self,
        address: &BitcoinAddressWrapper,
        amount_sats: i64,
    ) -> Result<i64, String> {
        if let Ok(module) = self.client.get_first_module::<WalletV2ClientModule>() {
            return module
                .send_fee()
                .await
                .map(|fee| fee.to_sat() as i64)
                .map_err(|e| e.to_string());
        }

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
    ) -> Result<(), String> {
        let amount = bitcoin::Amount::from_sat(amount_sats as u64);

        if let Ok(module) = self.client.get_first_module::<WalletV2ClientModule>() {
            return module
                .send(
                    self.account.into(),
                    address.0.clone(),
                    amount,
                    None,
                    serde_json::Value::Null,
                )
                .await
                .map(|_| ())
                .map_err(|e| e.to_string());
        }

        self.ensure_primary()?;

        let wallet_module = self
            .client
            .get_first_module::<WalletClientModule>()
            .map_err(|e| e.to_string())?;

        let address_checked = address
            .0
            .clone()
            .require_network(wallet_module.get_network())
            .map_err(|e| e.to_string())?;

        let fees = wallet_module
            .get_withdraw_fees(&address_checked, amount)
            .await
            .map_err(|e| e.to_string())?;

        wallet_module
            .withdraw(&address_checked, amount, fees, ())
            .await
            .map(|_| ())
            .map_err(|e| e.to_string())
    }

    #[frb]
    pub async fn onchain_receive_address(&self) -> Result<String, String> {
        self.ensure_primary()?;

        let wallet_module = self
            .client
            .get_first_module::<WalletClientModule>()
            .map_err(|e| e.to_string())?;

        let info = wallet_module
            .safe_allocate_deposit_address(())
            .await
            .map_err(|e| e.to_string())?;

        Ok(info.address.to_string())
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
    pub async fn wallet_v2_receive(&self) -> Option<String> {
        let address = self
            .client
            .get_first_module::<WalletV2ClientModule>()
            .ok()?
            .receive(self.account.into())
            .await
            .ok()?;

        Some(address.to_string())
    }

    #[frb]
    pub async fn federation_stats(&self) -> Option<FederationStats> {
        let module = self
            .client
            .get_first_module::<WalletV2ClientModule>()
            .ok()?;

        Some(FederationStats {
            total_value_sat: module.total_value().await.ok()?.to_sat() as i64,
            block_count: module.block_count().await.ok()? as i64,
            feerate: module.feerate().await.ok().flatten().map(|f| f as i64),
        })
    }

    #[frb]
    pub async fn get_payment_history(&self) -> Vec<ConduitPayment> {
        let mut payments = Vec::new();

        // The log is the mint's; this view keeps its own account's payments.
        // An update for another account's payment finds nothing here and
        // folds into nothing.
        for (_, entry) in self.stored_event_log().await {
            if let Some(parsed) = parse_event_log_entry(&entry) {
                match parsed {
                    ParsedEvent::Payment {
                        mut payment,
                        operation_id,
                        account,
                    } => {
                        if account != self.account {
                            continue;
                        }

                        self.attach_fiat(&mut payment, operation_id).await;
                        payments.push(payment);
                    }
                    ParsedEvent::Update {
                        operation_id,
                        success,
                        txid,
                        preimage,
                    } => {
                        apply_update(&mut payments, &operation_id, success, txid, preimage);
                    }
                }
            }
        }

        payments.reverse();

        payments
    }

    /// Federation fees paid over the course of an operation, excluding fees
    /// paid to service providers like the lightning gateway. Returns None for
    /// unknown operations and operations recorded before the federation
    /// tracked fee data. The amount may still increase while the operation is
    /// active.
    #[frb]
    pub async fn operation_fee_msats(&self, operation_id: String) -> Option<i64> {
        let operation_id = OperationId::from_str(&operation_id).ok()?;

        self.client
            .get_operation_fees(operation_id)
            .await
            .ok()
            .flatten()
            .map(|fees| {
                fees.get(&AmountUnit::BITCOIN)
                    .map_or(0, |amount| amount.msats as i64)
            })
    }

    #[frb]
    pub async fn subscribe_event_log(&self, sink: StreamSink<RecentPaymentsUpdate>) {
        let mut position = EventLogId::LOG_START;
        let mut payments = Vec::new();

        // Load historical events from our database. The log is the mint's;
        // this view keeps its own account's payments, and an update for
        // another account's payment finds nothing here and folds into
        // nothing.
        for (id, entry) in self.stored_event_log().await {
            position = id.saturating_add(1);

            if let Some(parsed) = parse_event_log_entry(&entry) {
                match parsed {
                    ParsedEvent::Payment {
                        mut payment,
                        operation_id,
                        account,
                    } => {
                        if account != self.account {
                            continue;
                        }

                        self.attach_fiat(&mut payment, operation_id).await;
                        payments.push(payment);
                    }
                    ParsedEvent::Update {
                        operation_id,
                        success,
                        txid,
                        preimage,
                    } => {
                        apply_update(&mut payments, &operation_id, success, txid, preimage);
                    }
                }
            }
        }

        let mut n_display = 3;

        // Send initial snapshot without notifications
        if sink
            .add(RecentPaymentsUpdate {
                payments: snapshot(&payments, n_display),
                notification: None,
            })
            .is_err()
        {
            return;
        }

        let mut log_event_rx = self.client.log_event_added_rx();

        loop {
            let changed = log_event_rx.changed();

            let batch = self.client.get_event_log(Some(position), 100).await;

            for persisted_entry in &batch {
                position = persisted_entry.id().saturating_add(1);

                let Some(parsed) = parse_event_log_entry(persisted_entry.as_raw()) else {
                    continue;
                };

                let notification = match parsed {
                    ParsedEvent::Payment {
                        mut payment,
                        operation_id,
                        account,
                    } => {
                        // Another account's payment: not this view's to show
                        // or announce, though its entry is still mirrored.
                        if account != self.account {
                            if !self
                                .store_event_log_entry(
                                    persisted_entry.id(),
                                    persisted_entry.as_raw(),
                                )
                                .await
                            {
                                return;
                            }

                            continue;
                        }

                        n_display += 1;

                        // First live sighting of this payment: freeze the fiat
                        // rate, then fold it into the payment we hand to the UI.
                        self.snapshot_fiat(operation_id).await;
                        self.attach_fiat(&mut payment, operation_id).await;

                        payments.push(payment.clone());

                        payment.success.map(|success| PaymentNotification {
                            incoming: payment.incoming,
                            success,
                            amount_sats: payment.amount_sats,
                            payment_type: payment.payment_type.clone(),
                        })
                    }
                    ParsedEvent::Update {
                        operation_id,
                        success,
                        txid,
                        preimage,
                    } => apply_update(&mut payments, &operation_id, success, txid, preimage),
                };

                if sink
                    .add(RecentPaymentsUpdate {
                        payments: snapshot(&payments, n_display),
                        notification,
                    })
                    .is_err()
                {
                    return;
                }

                if !self
                    .store_event_log_entry(persisted_entry.id(), persisted_entry.as_raw())
                    .await
                {
                    return;
                }
            }

            if batch.len() < 100 {
                if changed.await.is_err() {
                    return;
                }
            }
        }
    }
}
