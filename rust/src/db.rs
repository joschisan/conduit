use fedimint_core::{
    config::ClientConfig,
    config::FederationId,
    encoding::{Decodable, Encodable},
    impl_db_lookup, impl_db_record,
};
use flutter_rust_bridge::frb;

#[repr(u8)]
#[derive(Clone, Debug)]
pub enum DbKeyPrefix {
    RootEntropy = 0x00,
    ClientDatabase = 0x01,
    ClientConfig = 0x02,
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
