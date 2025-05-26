use clap::Args;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Args, Serialize, Deserialize)]
pub struct RegisterRequest {
    /// Username for the new account
    #[arg(long)]
    pub username: String,
    /// Password for the new account
    #[arg(long)]
    pub password: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegisterResponse {
    /// JWT token for authentication
    pub token: String,
}

#[derive(Debug, Clone, Args, Serialize, Deserialize)]
pub struct LoginRequest {
    /// Username for authentication
    #[arg(long)]
    pub username: String,
    /// Password for authentication
    #[arg(long)]
    pub password: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoginResponse {
    /// JWT token for authentication
    pub token: String,
}
