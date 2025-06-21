use anyhow::Result;
use bitcoin::Address;
use bitcoin::secp256k1::PublicKey;
use conduit_core::admin::{
    BalancesResponse, NewAddressResponse, NodeIdResponse, OpenChannelResponse,
};
use std::process::Command;

use super::RunConduitCli;

pub fn new_address(api_port: u16) -> Result<Address> {
    Command::new("target/debug/conduit-cli")
        .arg("--api-url")
        .arg(format!("http://127.0.0.1:{}", api_port))
        .arg("admin")
        .arg("--auth")
        .arg("testing-auth")
        .arg("ldk")
        .arg("onchain")
        .arg("receive")
        .run_conduit_cli::<NewAddressResponse>()
        .map(|response| response.address.assume_checked())
}

pub fn balances(api_port: u16) -> Result<BalancesResponse> {
    Command::new("target/debug/conduit-cli")
        .arg("--api-url")
        .arg(format!("http://127.0.0.1:{}", api_port))
        .arg("admin")
        .arg("--auth")
        .arg("testing-auth")
        .arg("ldk")
        .arg("balances")
        .run_conduit_cli::<BalancesResponse>()
}

pub fn node_id(api_port: u16) -> Result<PublicKey> {
    Command::new("target/debug/conduit-cli")
        .arg("--api-url")
        .arg(format!("http://127.0.0.1:{}", api_port))
        .arg("admin")
        .arg("--auth")
        .arg("testing-auth")
        .arg("ldk")
        .arg("node-id")
        .run_conduit_cli::<NodeIdResponse>()
        .map(|response| response.node_id)
}

pub fn open_channel(api_port_a: u16, node_id_b: PublicKey, ldk_port_b: u16) -> Result<String> {
    Command::new("target/debug/conduit-cli")
        .arg("--api-url")
        .arg(format!("http://127.0.0.1:{}", api_port_a))
        .arg("admin")
        .arg("--auth")
        .arg("testing-auth")
        .arg("ldk")
        .arg("channel")
        .arg("open")
        .arg("--node-id")
        .arg(node_id_b.to_string())
        .arg("--address")
        .arg(format!("127.0.0.1:{}", ldk_port_b))
        .arg("--channel-amount-sats")
        .arg("4000000")
        .arg("--push-to-counterparty-msat")
        .arg("2000000000")
        .run_conduit_cli::<OpenChannelResponse>()
        .map(|response| response.channel_id)
}

pub fn credit_user(api_port: u16, username: String, amount_msat: i64) -> Result<()> {
    Command::new("target/debug/conduit-cli")
        .arg("--api-url")
        .arg(format!("http://127.0.0.1:{}", api_port))
        .arg("admin")
        .arg("--auth")
        .arg("testing-auth")
        .arg("user")
        .arg("credit")
        .arg(amount_msat.to_string())
        .arg("--username")
        .arg(&username)
        .run_conduit_cli::<()>()
}
