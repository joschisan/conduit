use fedimint_core::config::{ClientConfig, FederationId};
use fedimint_core::encoding::{Decodable, Encodable};
use fedimint_core::{impl_db_lookup, impl_db_record};
use fedimint_eventlog::{EventLogEntry, EventLogId};

use crate::OperationId;

#[repr(u8)]
#[derive(Clone, Debug)]
pub(crate) enum DbKeyPrefix {
    RootEntropy = 0x00,
    ClientDatabase = 0x01,
    ClientConfig = 0x02,
    #[allow(dead_code)]
    EventLogStartPosition = 0x03, // Deprecated
    SelectedCurrency = 0x04,
    #[allow(dead_code)]
    SelectedFederation = 0x05, // Deprecated
    EventLogEntry = 0x06,
    Contact = 0x07,
    OperationFiat = 0x08,
}

#[derive(Clone, Debug, Encodable, Decodable)]
pub(crate) struct RootEntropyKey;

impl_db_record!(
    key = RootEntropyKey,
    value = Vec<u8>,
    db_prefix = DbKeyPrefix::RootEntropy,
);

#[derive(Clone, Debug, Encodable, Decodable)]
pub(crate) struct ClientConfigKey(pub(crate) FederationId);

#[derive(Clone, Debug, Encodable, Decodable)]
pub(crate) struct ClientConfigPrefix;

impl_db_record!(
    key = ClientConfigKey,
    value = ClientConfig,
    db_prefix = DbKeyPrefix::ClientConfig,
);

impl_db_lookup!(key = ClientConfigKey, query_prefix = ClientConfigPrefix);

#[derive(Clone, Debug, Encodable, Decodable)]
pub(crate) struct SelectedCurrencyKey;

impl_db_record!(
    key = SelectedCurrencyKey,
    value = String,
    db_prefix = DbKeyPrefix::SelectedCurrency,
);

#[allow(dead_code)]
#[derive(Clone, Debug, Encodable, Decodable)]
pub(crate) struct SelectedFederationKey;

impl_db_record!(
    key = SelectedFederationKey,
    value = FederationId,
    db_prefix = DbKeyPrefix::SelectedFederation,
);

#[derive(Clone, Debug, Encodable, Decodable)]
pub(crate) struct EventLogEntryKey(pub(crate) FederationId, pub(crate) EventLogId);

#[derive(Clone, Debug, Encodable, Decodable)]
pub(crate) struct EventLogEntryPrefix(pub(crate) FederationId);

impl_db_record!(
    key = EventLogEntryKey,
    value = EventLogEntry,
    db_prefix = DbKeyPrefix::EventLogEntry,
);

impl_db_lookup!(key = EventLogEntryKey, query_prefix = EventLogEntryPrefix);

/// Exchange rate snapshotted against an operation when its payment is first
/// observed live, so history can show the fiat value as of the time of the
/// payment. The value is `(currency_code, btc_price_bytes)`, where the BTC price
/// (in `currency_code`) is stored as `f64::to_be_bytes` since fedimint's
/// `Encodable` has no `f64` impl (and a `u64` would be BigSize var-int encoded).
/// Absent for operations that predate the feature or landed with no fresh rate
/// cached.
#[derive(Clone, Debug, Encodable, Decodable)]
pub(crate) struct OperationFiatKey(pub(crate) OperationId);

impl_db_record!(
    key = OperationFiatKey,
    value = (String, [u8; 8]),
    db_prefix = DbKeyPrefix::OperationFiat,
);

#[derive(Clone, Debug, Encodable, Decodable)]
pub(crate) struct ContactKey(pub(crate) String);

#[derive(Clone, Debug, Encodable, Decodable)]
pub(crate) struct ContactPrefix;

impl_db_record!(
    key = ContactKey,
    value = String,
    db_prefix = DbKeyPrefix::Contact,
);

impl_db_lookup!(key = ContactKey, query_prefix = ContactPrefix);
