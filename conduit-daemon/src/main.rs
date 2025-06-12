mod auth;
mod db;
mod error;
mod events;
mod models;
mod rpc;
mod schema;

use anyhow::{Context, Result};
use axum::{
    Router, middleware,
    routing::{get, post},
};
use clap::{ArgGroup, Parser};
use ldk_node::Event;
use ldk_node::bitcoin::Network;
use ldk_node::{Builder, Node};
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;
use tracing::info;
use url::Url;

use auth::{admin_auth_middleware, user_auth_middleware};
use db::{DbConnection, setup_database};

use crate::events::EventBus;
use crate::models::Bolt11Receive;

#[derive(Parser, Debug, Clone)]
#[command(group(
    ArgGroup::new("chain_source")
        .required(true)
        .multiple(false)
        .args(["bitcoind_rpc_url", "esplora_rpc_url"])
))]
struct Args {
    #[arg(long, env = "ADMIN_AUTH")]
    admin_auth: String,

    #[arg(long, env = "JWT_SECRET")]
    jwt_secret: String,

    #[arg(long, env = "CONDUIT_DATA_DIR")]
    conduit_data_dir: PathBuf,

    #[arg(long, env = "LDK_DATA_DIR")]
    ldk_data_dir: PathBuf,

    #[arg(long, env = "BITCOIN_NETWORK")]
    bitcoin_network: Network,

    #[arg(long, env = "BITCOIN_RPC_URL")]
    bitcoind_rpc_url: Option<Url>,

    #[arg(long, env = "ESPLORA_RPC_URL")]
    esplora_rpc_url: Option<Url>,

    #[arg(long, env = "FEE_PPM", default_value = "10000")]
    fee_ppm: u32,

    #[arg(long, env = "BASE_FEE_MSAT", default_value = "50000")]
    base_fee_msat: u32,

    #[arg(long, env = "API_BIND", default_value = "0.0.0.0:8080")]
    api_bind: SocketAddr,

    #[arg(long, env = "LDK_BIND", default_value = "0.0.0.0:9735")]
    ldk_bind: SocketAddr,
}

#[derive(Clone)]
struct AppState {
    admin_auth: String,
    jwt_secret: String,
    db: DbConnection,
    node: Arc<Node>,
    event_bus: EventBus,
    fee_ppm: u32,
    base_fee_msat: u32,
    api_bind: SocketAddr,
    send_lock: Arc<tokio::sync::Mutex<()>>,
}

impl AppState {
    fn get_fee_msat(&self, amount_msat: i64) -> i64 {
        (amount_msat / self.fee_ppm as i64) + self.base_fee_msat as i64
    }
}

async fn shutdown_signal() {
    tokio::signal::ctrl_c()
        .await
        .expect("Failed to install CTRL+C handler");

    info!("Signal received, shutting down gracefully...");
}

fn main() -> Result<()> {
    // Initialize tracing subscriber
    tracing_subscriber::fmt::init();

    let args = Args::parse();

    info!("Starting Conduit Daemon...");

    let mut builder = Builder::new();

    builder.set_node_alias("conduit-daemon".to_string())?;

    builder.set_storage_dir_path(args.ldk_data_dir.to_string_lossy().to_string());

    builder.set_network(args.bitcoin_network);

    // Set chain source based on which URL was provided
    match (args.bitcoind_rpc_url, args.esplora_rpc_url) {
        (Some(bitcoind_url), None) => {
            builder.set_chain_source_bitcoind_rpc(
                bitcoind_url
                    .host_str()
                    .context("Invalid bitcoind RPC URL: missing host")?
                    .to_string(),
                bitcoind_url
                    .port()
                    .context("Invalid bitcoind RPC URL: missing port")?,
                bitcoind_url.username().to_string(),
                bitcoind_url
                    .password()
                    .context("Invalid bitcoind RPC URL: missing password")?
                    .to_string(),
            );
        }
        (None, Some(esplora_url)) => {
            builder.set_chain_source_esplora(esplora_url.to_string(), None);
        }
        _ => panic!("XOR relation is enforced by argument group"),
    }

    builder
        .set_listening_addresses(vec![args.ldk_bind.into()])
        .context("Failed to set listening address")?;

    let node = Arc::new(builder.build().context("Failed to build LDK Node")?);

    let runtime = Arc::new(tokio::runtime::Runtime::new()?);

    node.start_with_runtime(runtime.clone())
        .context("Failed to start LDK Node")?;

    let db = setup_database(args.conduit_data_dir.clone())?;

    let event_bus = EventBus::new(1000);

    runtime.spawn(process_events(node.clone(), db.clone(), event_bus.clone()));

    let app_state = AppState {
        admin_auth: args.admin_auth.clone(),
        jwt_secret: args.jwt_secret.clone(),
        db: db.clone(),
        node: node.clone(),
        event_bus,
        fee_ppm: args.fee_ppm,
        base_fee_msat: args.base_fee_msat,
        api_bind: args.api_bind,
        send_lock: Arc::new(tokio::sync::Mutex::new(())),
    };

    let onchain_router = Router::new()
        .route("/receive", post(rpc::admin::ldk_onchain_receive))
        .route("/send", post(rpc::admin::ldk_onchain_send));

    let channel_router = Router::new()
        .route("/open", post(rpc::admin::ldk_channel_open))
        .route("/close", post(rpc::admin::ldk_channel_close))
        .route("/list", post(rpc::admin::ldk_channel_list));

    let peer_router = Router::new()
        .route("/connect", post(rpc::admin::ldk_peer_connect))
        .route("/disconnect", post(rpc::admin::ldk_peer_disconnect))
        .route("/list", post(rpc::admin::ldk_peer_list));

    let ldk_router = Router::new()
        .route("/node-id", post(rpc::admin::ldk_node_id))
        .route("/balances", post(rpc::admin::ldk_balances))
        .nest("/onchain", onchain_router)
        .nest("/channel", channel_router)
        .nest("/peer", peer_router);

    let admin_router = Router::new()
        .route("/credit-user", post(rpc::admin::credit_user))
        .nest("/ldk", ldk_router)
        .layer(middleware::from_fn_with_state(
            app_state.clone(),
            admin_auth_middleware,
        ));

    let account_router = Router::new()
        .route("/register", post(rpc::account::register))
        .route("/login", post(rpc::account::login));

    let bolt11_router = Router::new()
        .route("/receive", post(rpc::user::bolt11_receive))
        .route("/send", post(rpc::user::bolt11_send))
        .route("/quote", post(rpc::user::bolt11_quote));

    let user_router = Router::new()
        .route("/balance", post(rpc::user::balance))
        .route("/payments", post(rpc::user::payments))
        .route("/invoices", post(rpc::user::invoices))
        .route("/events", get(rpc::user::events))
        .nest("/bolt11", bolt11_router)
        .layer(middleware::from_fn_with_state(
            app_state.clone(),
            user_auth_middleware,
        ));

    let lnurl_router = Router::new()
        .route(
            "/.well-known/lnurlp/:username",
            get(rpc::lnurl::lnurl_pay_info),
        )
        .route(
            "/lnurl/pay/callback/:username",
            get(rpc::lnurl::lnurl_pay_callback),
        );

    let app = Router::new()
        .nest("/admin", admin_router)
        .nest("/account", account_router)
        .nest("/user", user_router)
        .merge(lnurl_router)
        .with_state(app_state);

    info!("Starting API server at {}", args.api_bind);

    runtime.block_on(async {
        let listener = tokio::net::TcpListener::bind(args.api_bind)
            .await
            .context("Failed to bind to API address")?;

        axum::serve(listener, app)
            .with_graceful_shutdown(shutdown_signal())
            .await
            .context("Failed to start HTTP server")
    })?;

    node.stop().context("Failed to stop LDK Node")?;

    info!("Graceful shutdown complete");

    Ok(())
}

async fn process_events(node: Arc<Node>, db: DbConnection, event_bus: EventBus) {
    loop {
        match node.next_event_async().await {
            Event::PaymentReceived {
                payment_hash,
                amount_msat,
                ..
            } => {
                let receive_record: Bolt11Receive = db::get_bolt11_invoice(&db, payment_hash.0)
                    .await
                    .expect("Invoice not found")
                    .into();

                assert_eq!(receive_record.amount_msat as u64, amount_msat);

                db::create_bolt11_receive_payment(&db, receive_record.clone()).await;

                let balance = db::get_user_balance(&db, receive_record.username.clone()).await;

                event_bus.send_balance_event(receive_record.username.clone(), balance);

                event_bus
                    .send_payment_event(receive_record.username.clone(), receive_record.into());
            }
            Event::PaymentSuccessful { payment_hash, .. } => {
                let payment_record = db::update_bolt11_send_payment_status(
                    &db,
                    payment_hash.0,
                    "successful".to_string(),
                )
                .await;

                let balance = db::get_user_balance(&db, payment_record.username.clone()).await;

                event_bus.send_balance_event(payment_record.username.clone(), balance);

                event_bus
                    .send_payment_event(payment_record.username.clone(), payment_record.into());
            }
            Event::PaymentFailed { payment_hash, .. } => {
                let payment_record = db::update_bolt11_send_payment_status(
                    &db,
                    payment_hash.unwrap().0,
                    "failed".to_string(),
                )
                .await;

                event_bus
                    .send_payment_event(payment_record.username.clone(), payment_record.into());
            }
            _ => {}
        }

        node.event_handled().expect("Failed to handle event");
    }
}
