use fedimint_core::{
    config::ClientConfig,
    config::FederationId,
    encoding::{Decodable, Encodable},
    impl_db_lookup, impl_db_record,
};
use fedimint_eventlog::EventLogId;
use flutter_rust_bridge::frb;

#[repr(u8)]
#[derive(Clone, Debug)]
pub enum DbKeyPrefix {
    RootEntropy = 0x00,
    ClientDatabase = 0x01,
    ClientConfig = 0x02,
    EventLogStartPosition = 0x03,
    SelectedCurrency = 0x04,
    SelectedFederation = 0x05,
}

#[frb(ignore)]
#[derive(Clone, Debug, Encodable, Decodable)]
pub struct RootEntropyKey;

impl_db_record!(
    key = RootEntropyKey,
    value = Vec<u8>,
    db_prefix = DbKeyPrefix::RootEntropy,
);

#[frb(ignore)]
#[derive(Clone, Debug, Encodable, Decodable)]
pub struct ClientConfigKey(pub FederationId);

#[frb(ignore)]
#[derive(Clone, Debug, Encodable, Decodable)]
pub struct ClientConfigPrefix;

impl_db_record!(
    key = ClientConfigKey,
    value = ClientConfig,
    db_prefix = DbKeyPrefix::ClientConfig,
);

impl_db_lookup!(key = ClientConfigKey, query_prefix = ClientConfigPrefix);

#[frb(ignore)]
#[derive(Clone, Debug, Encodable, Decodable)]
pub struct EventLogStartPositionKey(pub FederationId);

impl_db_record!(
    key = EventLogStartPositionKey,
    value = EventLogId,
    db_prefix = DbKeyPrefix::EventLogStartPosition,
);

#[frb(ignore)]
#[derive(Clone, Debug, Encodable, Decodable)]
pub struct SelectedCurrencyKey;

impl_db_record!(
    key = SelectedCurrencyKey,
    value = String,
    db_prefix = DbKeyPrefix::SelectedCurrency,
);

#[frb(ignore)]
#[derive(Clone, Debug, Encodable, Decodable)]
pub struct SelectedFederationKey;

impl_db_record!(
    key = SelectedFederationKey,
    value = FederationId,
    db_prefix = DbKeyPrefix::SelectedFederation,
);
