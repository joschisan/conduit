use crate::Args;
use anyhow::{Context, Result};
use std::path::Path;
use std::process::{Child, Command};

pub fn start(args: &Args, data_dir: &Path, api_port: u16, ldk_port: u16) -> Result<Child> {
    Command::new("target/debug/conduit-daemon")
        .arg("--admin-auth")
        .arg("testing-auth")
        .arg("--jwt-secret")
        .arg("testing-jwt-secret")
        .arg("--conduit-data-dir")
        .arg(data_dir.join("conduit"))
        .arg("--ldk-data-dir")
        .arg(data_dir.join("ldk"))
        .arg("--bitcoin-network")
        .arg("regtest")
        .arg("--bitcoind-rpc-url")
        .arg(args.bitcoind_rpc_url.as_str())
        .arg("--public-base-url")
        .arg("http://127.0.0.1:8080")
        .arg("--api-bind")
        .arg(format!("127.0.0.1:{}", api_port))
        .arg("--ldk-bind")
        .arg(format!("127.0.0.1:{}", ldk_port))
        .spawn()
        .context("Failed to start daemon")
}
