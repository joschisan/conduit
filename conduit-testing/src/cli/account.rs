use anyhow::Result;
use conduit_core::account::LoginResponse;
use conduit_core::account::RegisterResponse;
use std::process::Command;

use super::RunConduitCli;

pub fn register(api_port: u16, username: &str, password: &str) -> Result<RegisterResponse> {
    Command::new("target/debug/conduit-cli")
        .arg("--api-url")
        .arg(format!("http://127.0.0.1:{}", api_port))
        .arg("account")
        .arg("register")
        .arg("--username")
        .arg(username)
        .arg("--password")
        .arg(password)
        .run_conduit_cli::<RegisterResponse>()
}

#[allow(dead_code)]
pub fn login(api_port: u16, username: &str, password: &str) -> Result<LoginResponse> {
    Command::new("target/debug/conduit-cli")
        .arg("--api-url")
        .arg(format!("http://127.0.0.1:{}", api_port))
        .arg("account")
        .arg("login")
        .arg("--username")
        .arg(username)
        .arg("--password")
        .arg(password)
        .run_conduit_cli::<LoginResponse>()
}
