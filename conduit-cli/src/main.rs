use anyhow::ensure;
use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use conduit_core::account::{LoginRequest, RegisterRequest};
use conduit_core::admin::{CreditUserRequest, OpenChannelRequest};
use conduit_core::user::{UserBolt11QuoteRequest, UserBolt11ReceiveRequest, UserBolt11SendRequest};
use serde::Serialize;
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
    /// Get the node's public key
    NodeId,
    /// Generate a new Bitcoin address
    NewAddress,
    /// List the node's balances
    Balances,
    /// Open a Lightning Network channel
    OpenChannel(OpenChannelRequest),
    /// Credit amount to a user
    CreditUser(CreditUserRequest),
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
            AdminCommands::NodeId => request(cli.api_url, Some(auth), "admin/node_id", ()),
            AdminCommands::NewAddress => request(cli.api_url, Some(auth), "admin/new_address", ()),
            AdminCommands::Balances => request(cli.api_url, Some(auth), "admin/balances", ()),
            AdminCommands::OpenChannel(req) => {
                request(cli.api_url, Some(auth), "admin/open-channel", req)
            }
            AdminCommands::CreditUser(req) => {
                request(cli.api_url, Some(auth), "admin/credit-user", req)
            }
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

    println!("{}", response.text()?);

    Ok(())
}
