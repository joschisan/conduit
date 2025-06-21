mod account;
mod admin;
mod daemon;
mod user;

use anyhow::{Context, Result};
use bitcoincore_rpc::bitcoin::Address;
use bitcoincore_rpc::bitcoin::address::NetworkUnchecked;
use bitcoincore_rpc::{Auth, Client, RpcApi};
use clap::Parser;
use rand::Rng;
use std::path::PathBuf;
use std::thread::sleep;
use std::time::Duration;
use url::Url;

#[derive(Parser, Debug)]
struct Args {
    #[arg(long, default_value = "./data-dir-testing")]
    data_dir: PathBuf,

    #[arg(long, default_value = "http://bitcoin:bitcoin@127.0.0.1:18443")]
    bitcoind_rpc_url: Url,
}

fn main() -> Result<()> {
    let args = Args::parse();

    let rpc = Client::new(
        args.bitcoind_rpc_url.as_str(),
        Auth::UserPass(
            args.bitcoind_rpc_url.username().to_string(),
            args.bitcoind_rpc_url.password().unwrap_or("").to_string(),
        ),
    )
    .context("Failed to connect to Bitcoin RPC")?;

    let (api_port_a, ldk_port_a, api_port_b, ldk_port_b) = (8080, 8081, 8082, 8083);

    daemon::start(&args, &args.data_dir.join("a"), api_port_a, ldk_port_a)?;
    daemon::start(&args, &args.data_dir.join("b"), api_port_b, ldk_port_b)?;

    sleep(Duration::from_secs(1)); // Wait for daemons to start their APIs

    fund_daemon(&rpc, api_port_a)?;
    fund_daemon(&rpc, api_port_b)?;

    let node_id_b = admin::node_id(api_port_b)?;

    admin::open_channel(api_port_a, node_id_b, ldk_port_b)?;

    sleep(Duration::from_secs(1)); // Wait for funding tx to enter the mempool

    rpc.generate_to_address(6, &dummy_address())?;

    await_channel_capacity(api_port_a)?;
    await_channel_capacity(api_port_b)?;

    let jwt_a = account::register(api_port_a, "a", "pass_a")?;
    let jwt_b = account::register(api_port_a, "b", "pass_b")?;

    assert_eq!(user::balance(api_port_a, &jwt_a.token)?.balance.msat, 0);

    admin::user_credit(api_port_a, "a", 1000000)?;

    assert_eq!(
        user::balance(api_port_a, &jwt_a.token)?.balance.msat,
        1000000
    );

    user::bolt11_send(
        api_port_a,
        &jwt_a.token,
        user::bolt11_receive(api_port_a, &jwt_b.token, 250000)?.invoice,
        None,
    )?;

    sleep(Duration::from_secs(1));

    assert_eq!(
        user::balance(api_port_a, &jwt_a.token)?.balance.msat,
        699975
    );
    assert_eq!(
        user::balance(api_port_a, &jwt_b.token)?.balance.msat,
        250000
    );

    let jwt_c = account::register(api_port_b, "c", "pass_c")?;

    user::bolt11_send(
        api_port_a,
        &jwt_a.token,
        user::bolt11_receive(api_port_b, &jwt_c.token, 250000)?.invoice,
        None,
    )?;

    sleep(Duration::from_secs(1));

    assert_eq!(
        user::balance(api_port_a, &jwt_a.token)?.balance.msat,
        399950
    );
    assert_eq!(
        user::balance(api_port_b, &jwt_c.token)?.balance.msat,
        250000
    );

    user::bolt11_quote(
        api_port_a,
        &jwt_a.token,
        user::bolt11_receive(api_port_a, &jwt_a.token, 250000)?.invoice,
    )?;

    // sleep(Duration::from_secs(1000));

    Ok(())
}

#[allow(dead_code)]
fn allocate_ports() -> (u16, u16, u16, u16) {
    loop {
        let base_port = rand::thread_rng().gen_range(10000..65535);

        if (0..4).all(|i| portpicker::is_free(base_port + i)) {
            return (base_port, base_port + 1, base_port + 2, base_port + 3);
        }
    }
}

fn dummy_address() -> Address {
    "bcrt1qsurq86f2kdlce0tflgznehpzx275d93wvvxsml"
        .parse::<Address<NetworkUnchecked>>()
        .unwrap()
        .assume_checked()
}

fn fund_daemon(rpc: &Client, api_port: u16) -> Result<()> {
    let address = admin::onchain_receive(api_port)?;

    rpc.generate_to_address(101, &address)?;

    loop {
        let balances = admin::balances(api_port)?;

        if balances.total_onchain_balance_sats > 10_000_000 {
            break;
        }

        sleep(Duration::from_secs(1));
    }

    Ok(())
}

fn await_channel_capacity(api_port: u16) -> Result<()> {
    loop {
        let balances = admin::balances(api_port)?;

        if balances.total_outbound_capacity_msats > 1_000_000_000
            && balances.total_inbound_capacity_msats > 1_000_000_000
        {
            break;
        }

        sleep(Duration::from_secs(1));
    }

    Ok(())
}
