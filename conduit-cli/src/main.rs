use anyhow::ensure;
use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use conduit_core::admin::{
    CloseChannelRequest, ConnectPeerRequest, CreditUserRequest, DisconnectPeerRequest,
    OnchainSendRequest, OpenChannelRequest,
};
use serde::Serialize;
use serde_json::Value;
use url::Url;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// The URL of the daemon's API
    #[arg(long, default_value = "http://127.0.0.1:8080")]
    api_url: Url,
    /// Admin authentication token
    #[arg(long)]
    auth: String,
    #[command(subcommand)]
    command: AdminCommands,
}

#[derive(Subcommand, Debug)]
enum AdminCommands {
    /// User management commands
    User {
        #[command(subcommand)]
        command: AdminUserCommands,
    },
    /// LDK node management commands
    Ldk {
        #[command(subcommand)]
        command: AdminLdkCommands,
    },
}

#[derive(Subcommand, Debug)]
enum AdminUserCommands {
    /// Credit amount to a user
    Credit(CreditUserRequest),
    /// List all users
    List,
}

#[derive(Subcommand, Debug)]
enum AdminLdkCommands {
    /// Get the node ID
    NodeId,
    /// Get node balances
    Balances,
    /// On-chain operations
    Onchain {
        #[command(subcommand)]
        command: AdminOnchainCommands,
    },
    /// Channel operations
    Channel {
        #[command(subcommand)]
        command: AdminChannelCommands,
    },
    /// Peer management operations
    Peer {
        #[command(subcommand)]
        command: AdminPeerCommands,
    },
}

#[derive(Subcommand, Debug)]
enum AdminOnchainCommands {
    /// Generate a new Bitcoin address to receive funds
    Receive,
    /// Send Bitcoin to an address
    Send(OnchainSendRequest),
}

#[derive(Subcommand, Debug)]
enum AdminChannelCommands {
    /// Open a Lightning channel
    Open(OpenChannelRequest),
    /// Close a Lightning channel
    Close(CloseChannelRequest),
    /// List all Lightning channels
    List,
}

#[derive(Subcommand, Debug)]
enum AdminPeerCommands {
    /// Connect to a Lightning peer
    Connect(ConnectPeerRequest),
    /// Disconnect from a Lightning peer
    Disconnect(DisconnectPeerRequest),
    /// List all connected peers
    List,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        AdminCommands::User { command } => match command {
            AdminUserCommands::Credit(req) => {
                request(cli.api_url, cli.auth, "admin/user/credit", req)
            }
            AdminUserCommands::List => request(cli.api_url, cli.auth, "admin/user/list", ()),
        },
        AdminCommands::Ldk { command } => match command {
            AdminLdkCommands::NodeId => request(cli.api_url, cli.auth, "admin/ldk/node-id", ()),
            AdminLdkCommands::Balances => request(cli.api_url, cli.auth, "admin/ldk/balances", ()),
            AdminLdkCommands::Onchain { command } => match command {
                AdminOnchainCommands::Receive => {
                    request(cli.api_url, cli.auth, "admin/ldk/onchain/receive", ())
                }
                AdminOnchainCommands::Send(req) => {
                    request(cli.api_url, cli.auth, "admin/ldk/onchain/send", req)
                }
            },
            AdminLdkCommands::Channel { command } => match command {
                AdminChannelCommands::Open(req) => {
                    request(cli.api_url, cli.auth, "admin/ldk/channel/open", req)
                }
                AdminChannelCommands::Close(req) => {
                    request(cli.api_url, cli.auth, "admin/ldk/channel/close", req)
                }
                AdminChannelCommands::List => {
                    request(cli.api_url, cli.auth, "admin/ldk/channel/list", ())
                }
            },
            AdminLdkCommands::Peer { command } => match command {
                AdminPeerCommands::Connect(req) => {
                    request(cli.api_url, cli.auth, "admin/ldk/peer/connect", req)
                }
                AdminPeerCommands::Disconnect(req) => {
                    request(cli.api_url, cli.auth, "admin/ldk/peer/disconnect", req)
                }
                AdminPeerCommands::List => {
                    request(cli.api_url, cli.auth, "admin/ldk/peer/list", ())
                }
            },
        },
    }
}

fn request<R: Serialize>(api_url: Url, auth: String, route: &str, request: R) -> Result<()> {
    let request_url = api_url.join(route).context("Failed to construct URL")?;

    let response = reqwest::blocking::Client::new()
        .post(request_url)
        .header("Authorization", format!("Bearer {}", auth))
        .json(&serde_json::to_value(request)?)
        .send()
        .context("Failed to connect to daemon")?;

    ensure!(
        response.status().is_success(),
        "API error ({}): {}",
        response.status().as_u16(),
        response.text()?
    );

    println!(
        "{}",
        serde_json::to_string_pretty(&response.json::<Value>()?)?
    );

    Ok(())
}
