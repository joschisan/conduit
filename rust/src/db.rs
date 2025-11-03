use fedimint_core::config::{ClientConfig, FederationId};
use fedimint_core::encoding::{Decodable, Encodable};
use fedimint_core::{impl_db_lookup, impl_db_record};
use fedimint_eventlog::{EventLogEntry, EventLogId};

#[repr(u8)]
#[derive(Clone, Debug)]
pub(crate) enum DbKeyPrefix {
    RootEntropy = 0x00,
    ClientDatabase = 0x01,
    ClientConfig = 0x02,
    // EventLogStartPosition = 0x03, Deprecated
    SelectedCurrency = 0x04,
    SelectedFederation = 0x05,
    EventLogEntry = 0x06,
    Contact = 0x07,
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
