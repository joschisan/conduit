use axum::extract::Request;
use axum::extract::State;
use axum::http::StatusCode;
use axum::http::header;
use axum::middleware::Next;
use axum::response::IntoResponse;
use jsonwebtoken::{DecodingKey, Validation, decode};
use serde::{Deserialize, Serialize};

use crate::AppState;
use crate::error::ApiError;

// Add middleware function to check admin authentication
pub async fn admin_auth_middleware(
    State(state): State<AppState>,
    request: Request,
    next: Next,
) -> Result<impl IntoResponse, ApiError> {
    let auth_header = request
        .headers()
        .get(header::AUTHORIZATION)
        .and_then(|header| header.to_str().ok())
        .map(|s| s.trim_start_matches("Bearer ").to_string());

    match auth_header {
        Some(token) if token == state.admin_auth => Ok(next.run(request).await),
        _ => Err(ApiError {
            code: StatusCode::UNAUTHORIZED,
            error: "Invalid authorization token".to_string(),
        }),
    }
}

// Add middleware function to check user JWT authentication
pub async fn user_auth_middleware(
    State(state): State<AppState>,
    mut request: Request,
    next: Next,
) -> Result<impl IntoResponse, ApiError> {
    let auth_header = request
        .headers()
        .get(header::AUTHORIZATION)
        .and_then(|header| header.to_str().ok())
        .map(|s| s.trim_start_matches("Bearer ").to_string());

    match auth_header {
        Some(token) => {
            // Decode and validate JWT
            let token_data = decode::<Claims>(
                &token,
                &DecodingKey::from_secret(state.jwt_secret.as_bytes()),
                &Validation::default(),
            )
            .map_err(|_| ApiError {
                code: StatusCode::UNAUTHORIZED,
                error: "Invalid authorization token".to_string(),
            })?;

            // Add the username to the request extensions
            request.extensions_mut().insert(token_data.claims.sub);

            Ok(next.run(request).await)
        }
        None => Err(ApiError {
            code: StatusCode::UNAUTHORIZED,
            error: "Missing authorization token".to_string(),
        }),
    }
}

#[derive(Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,
    pub exp: usize,
}
