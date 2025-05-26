use anyhow::Result;
use conduit_core::user::{BalanceResponse, Bolt11QuoteResponse, Bolt11ReceiveResponse};
use lightning_invoice::Bolt11Invoice;
use std::process::Command;

use super::RunConduitCli;

pub fn balance(api_port: u16, jwt: &String) -> Result<u64> {
    Command::new("target/debug/conduit-cli")
        .arg("--api-url")
        .arg(format!("http://127.0.0.1:{}", api_port))
        .arg("user")
        .arg("--auth")
        .arg(jwt)
        .arg("balance")
        .run_conduit_cli::<BalanceResponse>()
        .map(|response| response.balance.msat)
}

pub fn bolt11_receive(api_port: u16, jwt: &String, amount_msat: u64) -> Result<Bolt11Invoice> {
    Command::new("target/debug/conduit-cli")
        .arg("--api-url")
        .arg(format!("http://127.0.0.1:{}", api_port))
        .arg("user")
        .arg("--auth")
        .arg(jwt)
        .arg("bolt11")
        .arg("receive")
        .arg(amount_msat.to_string())
        .run_conduit_cli::<Bolt11ReceiveResponse>()
        .map(|response| response.invoice)
}

pub fn bolt11_send(api_port: u16, jwt: &String, invoice: &Bolt11Invoice) -> Result<()> {
    Command::new("target/debug/conduit-cli")
        .arg("--api-url")
        .arg(format!("http://127.0.0.1:{}", api_port))
        .arg("user")
        .arg("--auth")
        .arg(jwt)
        .arg("bolt11")
        .arg("send")
        .arg(invoice.to_string())
        .run_conduit_cli::<()>()
}

pub fn bolt11_quote(
    api_port: u16,
    jwt: &String,
    invoice: &Bolt11Invoice,
) -> Result<Bolt11QuoteResponse> {
    Command::new("target/debug/conduit-cli")
        .arg("--api-url")
        .arg(format!("http://127.0.0.1:{}", api_port))
        .arg("user")
        .arg("--auth")
        .arg(jwt)
        .arg("bolt11")
        .arg("quote")
        .arg(invoice.to_string())
        .run_conduit_cli::<Bolt11QuoteResponse>()
}
