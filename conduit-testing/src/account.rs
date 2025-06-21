use anyhow::Result;
use conduit_core::account::{LoginRequest, LoginResponse, RegisterRequest, RegisterResponse};

pub fn register(api_port: u16, username: &str, password: &str) -> Result<RegisterResponse> {
    let response = reqwest::blocking::Client::new()
        .post(format!("http://127.0.0.1:{}/account/register", api_port))
        .json(&RegisterRequest {
            username: username.to_string(),
            password: password.to_string(),
        })
        .send()?
        .json()?;

    Ok(response)
}

#[allow(dead_code)]
pub fn login(api_port: u16, username: &str, password: &str) -> Result<LoginResponse> {
    let response = reqwest::blocking::Client::new()
        .post(format!("http://127.0.0.1:{}/account/login", api_port))
        .json(&LoginRequest {
            username: username.to_string(),
            password: password.to_string(),
        })
        .send()?
        .json()?;

    Ok(response)
}
