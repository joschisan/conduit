use std::time::Duration;

use fedimint_client::{ClientHandleArc, OperationId};
use fedimint_core::config::FederationId;
use fedimint_core::db::{Database, IDatabaseTransactionOpsCoreTyped};
use fedimint_core::module::AmountUnit;
use fedimint_core::task::sleep;
use fedimint_core::util::SafeUrl;
use fedimint_core::Amount;
use fedimint_eventlog::EventLogId;
use fedimint_lnv2_client::LightningClientModule;
use fedimint_lnv2_common::Bolt11InvoiceDescription;
use fedimint_mint_client::MintClientModule;
use fedimint_wallet_client::client_db::TweakIdx;
use fedimint_wallet_client::{WalletClientModule, WalletOperationMeta, WalletOperationMetaVariant};
use flutter_rust_bridge::frb;
use futures_util::StreamExt;

use crate::db::{EventLogEntryKey, EventLogEntryPrefix};
use crate::events::{parse_event_log_entry, ConduitEvent};
use crate::exchange::{fetch_exchange_rate, ExchangeRateCache};
use crate::frb_generated::StreamSink;
use crate::{BitcoinAddressWrapper, Bolt11InvoiceWrapper, OOBNotesWrapper};

#[frb]
pub struct ConduitRecoveryProgress {
    pub module_id: i64,
    pub complete: i64,
    pub total: i64,
}

#[frb]
#[derive(Clone)]
pub struct ConduitClient {
    pub(crate) client: ClientHandleArc,
    pub(crate) db: Database,
    pub(crate) federation_id: FederationId,
    pub(crate) currency_code: String,
    pub(crate) exchange_rate_cache: ExchangeRateCache,
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
        tokio::task::spawn(fetch_exchange_rate(
            self.exchange_rate_cache.clone(),
            self.currency_code.clone(),
        ));
    }

    #[frb]
    pub async fn fiat_to_sats(&self, amount_fiat_cents: i64) -> Result<i64, String> {
        // cents -> currency -> BTC -> sats
        fetch_exchange_rate(self.exchange_rate_cache.clone(), self.currency_code.clone())
            .await
            .map(|r| (amount_fiat_cents as f64 / 100.0 / r * 100_000_000.0).round() as i64)
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

    #[frb]
    pub async fn subscribe_connection_status(&self, sink: StreamSink<Vec<bool>>) {
        let mut stream = self.client.connection_status_stream();

        while let Some(status_map) = stream.next().await {
            if sink.add(status_map.into_values().collect()).is_err() {
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
    pub async fn subscribe_recovery_progress(&self, sink: StreamSink<ConduitRecoveryProgress>) {
        let mut stream = self.client.subscribe_to_recovery_progress();

        while let Some((module_id, progress)) = stream.next().await {
            let conduit_progress = ConduitRecoveryProgress {
                module_id: module_id as i64,
                complete: progress.complete as i64,
                total: progress.total as i64,
            };

            if sink.add(conduit_progress).is_err() {
                break;
            }
        }
    }

    #[frb]
    pub async fn ecash_send(&self, amount_sat: i64) -> Result<OOBNotesWrapper, String> {
        self.client
            .get_first_module::<MintClientModule>()
            .unwrap()
            .send_oob_notes(Amount::from_sats(amount_sat as u64), ())
            .await
            .map(OOBNotesWrapper)
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
        let recurringd = SafeUrl::parse("https://recurringd-ytcf5.ondigitalocean.app").unwrap();

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
        let mut position = EventLogId::LOG_START;

        let history = self
            .db
            .begin_transaction_nc()
            .await
            .find_by_prefix(&EventLogEntryPrefix(self.federation_id))
            .await
            .collect::<Vec<_>>()
            .await;

        for (key, entry) in history {
            if let Some(event) = parse_event_log_entry(&entry) {
                if sink.add(event).is_err() {
                    return;
                }
            }

            position = key.1.saturating_add(1);
        }

        loop {
            let batch = self.client.get_event_log(Some(position), 100).await;

            for persisted_entry in &batch {
                if let Some(event) = parse_event_log_entry(persisted_entry.as_raw()) {
                    if sink.add(event).is_err() {
                        return;
                    }

                    let mut dbtx = self.db.begin_transaction().await;

                    dbtx.insert_entry(
                        &EventLogEntryKey(self.federation_id, persisted_entry.id()),
                        persisted_entry.as_raw(),
                    )
                    .await;

                    if dbtx.commit_tx_result().await.is_err() {
                        return;
                    }
                }

                position = persisted_entry.id().saturating_add(1);
            }

            if batch.len() < 100 {
                sleep(Duration::from_millis(250)).await;
            }
        }
    }
}
