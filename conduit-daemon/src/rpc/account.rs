use axum::{Json, extract::State};
use bitcoin::hashes::Hash;
use bitcoin::hashes::sha256;
use bitcoin::hex::DisplayHex;
use conduit_core::account::{LoginRequest, LoginResponse, RegisterRequest, RegisterResponse};
use jsonwebtoken::{EncodingKey, Header, encode};
use tracing::info;

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
    if db::count_users_created(&state.db, 24 * 60 * 60).await
        > state.args.max_daily_new_users as i64
    {
        return Err(ApiError::bad_request("Please try again later"));
    }

    db::register_user(
        &state.db,
        req.username.clone(),
        hash_password(&req.password),
    )
    .await
    .map_err(ApiError::bad_request)?;

    info!(username = ?req.username.clone(), "user registered");

    let claims = Claims {
        sub: req.username.clone(),
        exp: (chrono::Utc::now() + chrono::Duration::days(30)).timestamp() as usize,
    };

    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(state.args.jwt_secret.as_bytes()),
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

    db::validate_credentials(&db, req.username.clone(), hash_password(&req.password))
        .await
        .map_err(ApiError::bad_request)?;

    info!(username = ?req.username.clone(), "user logged in");

    let claims = Claims {
        sub: req.username.clone(),
        exp: (chrono::Utc::now() + chrono::Duration::days(30)).timestamp() as usize,
    };

    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(state.args.jwt_secret.as_bytes()),
    )
    .expect("Failed to encode JWT token");

    Ok(Json(LoginResponse { token }))
}
