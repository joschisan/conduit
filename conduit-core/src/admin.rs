use bitcoin::Address;
use bitcoin::address::NetworkUnchecked;
use bitcoin::secp256k1::PublicKey;
use clap::Args;
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BalancesResponse {
    /// The total balance in the on-chain wallet, in satoshis
    pub total_onchain_balance_sats: u64,
    /// The total inbound capacity across all channels, in millisatoshis
    pub total_inbound_capacity_msats: u64,
    /// The total outbound capacity across all channels, in millisatoshis
    pub total_outbound_capacity_msats: u64,
}

#[derive(Debug, Clone, Args, Serialize, Deserialize)]
pub struct OpenChannelRequest {
    /// The public key of the node to open a channel with
    #[arg(long)]
    pub node_id: PublicKey,
    /// The network address of the node
    #[arg(long)]
    pub address: SocketAddr,
    /// The amount to fund the channel with, in satoshis
    #[arg(long)]
    pub channel_amount_sats: u64,
    /// Amount to push to the counterparty when opening the channel, in millisatoshis
    #[arg(long)]
    pub push_to_counterparty_msat: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OpenChannelResponse {
    /// The channel ID as a string
    pub channel_id: String,
}

#[derive(Debug, Clone, Args, Serialize, Deserialize)]
pub struct CreditUserRequest {
    /// The amount to credit the user with
    pub amount_msat: i64,
    /// The username to credit
    #[arg(long)]
    pub username: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeIdResponse {
    /// The node's public key
    pub node_id: PublicKey,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NewAddressResponse {
    /// The generated Bitcoin address
    pub address: Address<NetworkUnchecked>,
}
