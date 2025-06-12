use anyhow::ensure;
use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use conduit_core::account::{LoginRequest, RegisterRequest};
use conduit_core::admin::{
    CloseChannelRequest, ConnectPeerRequest, CreditUserRequest, DisconnectPeerRequest,
    OnchainSendRequest, OpenChannelRequest,
};
use conduit_core::user::{UserBolt11QuoteRequest, UserBolt11ReceiveRequest, UserBolt11SendRequest};
use serde::Serialize;
use serde_json::Value;
use url::Url;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// The URL of the daemon's API
    #[arg(long, default_value = "http://127.0.0.1:8080")]
    api_url: Url,
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Admin commands for daemon management
    Admin {
        #[arg(long)]
        auth: String,
        #[command(subcommand)]
        command: AdminCommands,
    },
    /// Account management commands
    Account {
        #[command(subcommand)]
        command: AccountCommands,
    },
    /// User commands for payments
    User {
        /// JWT authentication token
        #[arg(long)]
        auth: String,
        #[command(subcommand)]
        command: UserCommands,
    },
}

#[derive(Subcommand, Debug)]
enum AdminCommands {
    /// Credit amount to a user
    CreditUser(CreditUserRequest),
    /// List all users
    ListUsers,
    /// LDK node management commands
    Ldk {
        #[command(subcommand)]
        command: AdminLdkCommands,
    },
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

#[derive(Subcommand, Debug)]
enum AccountCommands {
    /// Register a new user account
    Register(RegisterRequest),
    /// Login to an existing account
    Login(LoginRequest),
}

#[derive(Subcommand, Debug)]
enum UserCommands {
    /// Get the user's balance
    Balance,
    /// List all payments
    Payments,
    /// List all invoices
    Invoices,
    /// BOLT-11 invoice operations (create and pay)
    Bolt11 {
        #[command(subcommand)]
        command: UserBolt11Commands,
    },
}

#[derive(Subcommand, Debug)]
enum UserBolt11Commands {
    /// Create a new BOLT-11 invoice
    Receive(UserBolt11ReceiveRequest),
    /// Pay a BOLT-11 invoice
    Send(UserBolt11SendRequest),
    /// Get a quote for a BOLT-11 invoice
    Quote(UserBolt11QuoteRequest),
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Admin { auth, command } => match command {
            AdminCommands::CreditUser(req) => {
                request(cli.api_url, Some(auth), "admin/credit-user", req)
            }
            AdminCommands::ListUsers => request(cli.api_url, Some(auth), "admin/list-users", ()),
            AdminCommands::Ldk { command } => match command {
                AdminLdkCommands::NodeId => {
                    request(cli.api_url, Some(auth), "admin/ldk/node-id", ())
                }
                AdminLdkCommands::Balances => {
                    request(cli.api_url, Some(auth), "admin/ldk/balances", ())
                }
                AdminLdkCommands::Onchain { command } => match command {
                    AdminOnchainCommands::Receive => {
                        request(cli.api_url, Some(auth), "admin/ldk/onchain/receive", ())
                    }
                    AdminOnchainCommands::Send(req) => {
                        request(cli.api_url, Some(auth), "admin/ldk/onchain/send", req)
                    }
                },
                AdminLdkCommands::Channel { command } => match command {
                    AdminChannelCommands::Open(req) => {
                        request(cli.api_url, Some(auth), "admin/ldk/channel/open", req)
                    }
                    AdminChannelCommands::Close(req) => {
                        request(cli.api_url, Some(auth), "admin/ldk/channel/close", req)
                    }
                    AdminChannelCommands::List => {
                        request(cli.api_url, Some(auth), "admin/ldk/channel/list", ())
                    }
                },
                AdminLdkCommands::Peer { command } => match command {
                    AdminPeerCommands::Connect(req) => {
                        request(cli.api_url, Some(auth), "admin/ldk/peer/connect", req)
                    }
                    AdminPeerCommands::Disconnect(req) => {
                        request(cli.api_url, Some(auth), "admin/ldk/peer/disconnect", req)
                    }
                    AdminPeerCommands::List => {
                        request(cli.api_url, Some(auth), "admin/ldk/peer/list", ())
                    }
                },
            },
        },
        Commands::Account { command } => match command {
            AccountCommands::Register(req) => request(cli.api_url, None, "account/register", req),
            AccountCommands::Login(req) => request(cli.api_url, None, "account/login", req),
        },
        Commands::User { auth, command } => match command {
            UserCommands::Balance => request(cli.api_url, Some(auth), "user/balance", ()),
            UserCommands::Payments => request(cli.api_url, Some(auth), "user/payments", ()),
            UserCommands::Invoices => request(cli.api_url, Some(auth), "user/invoices", ()),
            UserCommands::Bolt11 { command } => match command {
                UserBolt11Commands::Receive(req) => {
                    request(cli.api_url, Some(auth), "user/bolt11/receive", req)
                }
                UserBolt11Commands::Send(req) => {
                    request(cli.api_url, Some(auth), "user/bolt11/send", req)
                }
                UserBolt11Commands::Quote(req) => {
                    request(cli.api_url, Some(auth), "user/bolt11/quote", req)
                }
            },
        },
    }
}

fn request<R: Serialize>(
    api_url: Url,
    auth: Option<String>,
    route: &str,
    request: R,
) -> Result<()> {
    let request_url = api_url.join(route).context("Failed to construct URL")?;

    let mut post = reqwest::blocking::Client::new().post(request_url);

    if let Some(auth) = auth {
        post = post.header("Authorization", format!("Bearer {}", auth));
    }

    let response = post
        .json(&serde_json::to_value(request)?)
        .send()
        .context("Failed to connect to daemon")?;

    ensure!(
        response.status().is_success(),
        "API error ({}): {}",
        response.status().as_u16(),
        response.text()?
    );

    println!("{}", serde_json::to_string_pretty(&response.json::<Value>()?)?);

    Ok(())
}
