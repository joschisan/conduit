use anyhow::Result;
use conduit_core::user::{
    BalanceResponse, Bolt11QuoteResponse, Bolt11ReceiveResponse, PaymentsResponse,
    UserBolt11QuoteRequest, UserBolt11ReceiveRequest, UserBolt11SendRequest,
};
use lightning_invoice::Bolt11Invoice;

pub fn balance(api_port: u16, jwt: &str) -> Result<BalanceResponse> {
    let response = reqwest::blocking::Client::new()
        .post(format!("http://127.0.0.1:{}/user/balance", api_port))
        .header("Authorization", format!("Bearer {}", jwt))
        .json(&())
        .send()?
        .json()?;

    Ok(response)
}

#[allow(dead_code)]
pub fn payments(api_port: u16, jwt: &str) -> Result<PaymentsResponse> {
    let response = reqwest::blocking::Client::new()
        .post(format!("http://127.0.0.1:{}/user/payments", api_port))
        .header("Authorization", format!("Bearer {}", jwt))
        .json(&())
        .send()?
        .json()?;

    Ok(response)
}

pub fn bolt11_receive(api_port: u16, jwt: &str, amount_msat: i64) -> Result<Bolt11ReceiveResponse> {
    let response = reqwest::blocking::Client::new()
        .post(format!("http://127.0.0.1:{}/user/bolt11/receive", api_port))
        .header("Authorization", format!("Bearer {}", jwt))
        .json(&UserBolt11ReceiveRequest {
            amount_msat: amount_msat.try_into().unwrap(),
            description: Some("Test payment".to_string()),
        })
        .send()?
        .json()?;

    Ok(response)
}

pub fn bolt11_send(
    api_port: u16,
    jwt: &str,
    invoice: Bolt11Invoice,
    ln_address: Option<String>,
) -> Result<()> {
    reqwest::blocking::Client::new()
        .post(format!("http://127.0.0.1:{}/user/bolt11/send", api_port))
        .header("Authorization", format!("Bearer {}", jwt))
        .json(&UserBolt11SendRequest {
            invoice,
            ln_address,
        })
        .send()?;

    Ok(())
}

pub fn bolt11_quote(
    api_port: u16,
    jwt: &str,
    invoice: Bolt11Invoice,
) -> Result<Bolt11QuoteResponse> {
    let response = reqwest::blocking::Client::new()
        .post(format!("http://127.0.0.1:{}/user/bolt11/quote", api_port))
        .header("Authorization", format!("Bearer {}", jwt))
        .json(&UserBolt11QuoteRequest { invoice })
        .send()?
        .json()?;

    Ok(response)
}
