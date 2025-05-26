use axum::{Json, extract::State};
use bitcoin::hashes::Hash;
use bitcoin::hashes::sha256;
use bitcoin::hex::DisplayHex;
use conduit_core::account::{LoginRequest, LoginResponse, RegisterRequest, RegisterResponse};
use jsonwebtoken::{EncodingKey, Header, encode};

use crate::AppState;
use crate::auth::Claims;
use crate::db;
use crate::error::ApiError;

fn hash_password(password: &str) -> String {
    sha256::Hash::hash(password.as_bytes())
        .to_byte_array()
        .as_hex()
        .to_string()
}

#[axum::debug_handler]
pub async fn register(
    State(state): State<AppState>,
    Json(req): Json<RegisterRequest>,
) -> Result<Json<RegisterResponse>, ApiError> {
    let username = db::register_user(&state.db, req.username, hash_password(&req.password))
        .await
        .map_err(ApiError::bad_request)?;

    let claims = Claims {
        sub: username.clone(),
        exp: (chrono::Utc::now() + chrono::Duration::days(30)).timestamp() as usize,
    };

    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(state.jwt_secret.as_bytes()),
    )
    .expect("Failed to encode JWT token");

    Ok(Json(RegisterResponse { token }))
}

#[axum::debug_handler]
pub async fn login(
    State(state): State<AppState>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, ApiError> {
    let db = state.db.clone();

    let username =
        db::validate_credentials(&db, req.username.clone(), hash_password(&req.password))
            .await
            .map_err(ApiError::bad_request)?;

    let claims = Claims {
        sub: username.clone(),
        exp: (chrono::Utc::now() + chrono::Duration::days(30)).timestamp() as usize,
    };

    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(state.jwt_secret.as_bytes()),
    )
    .expect("Failed to encode JWT token");

    Ok(Json(LoginResponse { token }))
}
