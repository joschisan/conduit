use bitcoin::Address;
use bitcoin::FeeRate;
use bitcoin::address::NetworkUnchecked;
use bitcoin::secp256k1::PublicKey;
use clap::Args;
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;

use crate::Balance;

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

#[derive(Debug, Clone, Args, Serialize, Deserialize)]
pub struct OnchainSendRequest {
    /// Bitcoin address to send to
    pub address: Address<NetworkUnchecked>,
    /// Amount in satoshis
    pub amount_sats: u64,
    /// Fee rate (optional)
    #[arg(long)]
    pub fee_rate: Option<FeeRate>,
}

#[derive(Debug, Clone, Args, Serialize, Deserialize)]
pub struct CloseChannelRequest {
    /// User channel ID (u128)
    pub user_channel_id: u128,
    /// Counterparty node public key
    pub counterparty_node_id: PublicKey,
    /// Force close the channel
    #[arg(long)]
    pub force: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChannelInfo {
    pub user_channel_id: u128,
    pub counterparty_node_id: PublicKey,
    pub channel_value_sats: u64,
    pub outbound_capacity_msat: u64,
    pub inbound_capacity_msat: u64,
    pub is_channel_ready: bool,
    pub is_usable: bool,
    pub is_outbound: bool,
    pub confirmations: Option<u32>,
    pub confirmations_required: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ListChannelsResponse {
    pub channels: Vec<ChannelInfo>,
}

// Peer management structs
#[derive(Debug, Clone, Args, Serialize, Deserialize)]
pub struct ConnectPeerRequest {
    /// The public key of the peer to connect to
    pub node_id: PublicKey,
    /// The network address of the peer (IP:PORT format)
    #[arg(long)]
    pub address: std::net::SocketAddr,
    /// Whether to persist the connection (reconnect on restart)
    #[arg(long, default_value = "false")]
    pub persist: bool,
}

#[derive(Debug, Clone, Args, Serialize, Deserialize)]
pub struct DisconnectPeerRequest {
    /// The public key of the peer to disconnect from
    pub counterparty_node_id: PublicKey,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerInfo {
    /// The peer's public key
    pub node_id: PublicKey,
    /// The peer's network address (if known)
    pub address: String,
    /// Whether the peer is persisted between restarts
    pub is_persisted: bool,
    /// Whether the peer is currently connected
    pub is_connected: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ListPeersResponse {
    pub peers: Vec<PeerInfo>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserInfo {
    pub username: String,
    pub password_hash: String,
    pub balance: Balance,
    pub created_at: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ListUsersResponse {
    pub users: Vec<UserInfo>,
}
