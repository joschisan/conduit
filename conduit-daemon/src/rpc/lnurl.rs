use axum::{
    extract::{Path, Query, State},
    response::Json,
};
use lightning_invoice::{Bolt11InvoiceDescription, Description};
use serde::{Deserialize, Serialize};

use crate::AppState;
use crate::db;
use crate::error::ApiError;

#[derive(Serialize)]
pub struct LnurlPayResponse {
    tag: String,
    callback: String,
    #[serde(rename = "minSendable")]
    min_sendable: u64,
    #[serde(rename = "maxSendable")]
    max_sendable: u64,
    metadata: String,
}

#[derive(Deserialize)]
pub struct LnurlPayCallbackParams {
    amount: u64,
    comment: Option<String>,
}

#[derive(Serialize)]
#[serde(untagged)]
pub enum LnurlPayCallbackResponse {
    Success { pr: String },
    Error { status: String, reason: String },
}

// Lightning Address discovery endpoint
#[axum::debug_handler]
pub async fn lnurl_pay_info(
    Path(username): Path<String>,
    State(state): State<AppState>,
) -> Result<Json<LnurlPayResponse>, ApiError> {
    db::get_user_by_username(&state.db, username.clone())
        .await
        .ok_or(ApiError::not_found("User not found"))?;

    // Encode the username directly in the callback URL path
    let callback_url = format!("http://{}/lnurl/pay/callback/{}", state.api_bind, username);

    Ok(Json(LnurlPayResponse {
        tag: "payRequest".to_string(),
        callback: callback_url,
        min_sendable: 1000,        // 1 sat minimum
        max_sendable: 100_000_000, // 100k sats maximum
        metadata: format!(
            r#"[["text/plain", "Payment to {}@{}"]]"#,
            username, state.api_bind
        ),
    }))
}

// Invoice generation callback
#[axum::debug_handler]
pub async fn lnurl_pay_callback(
    Path(username): Path<String>,
    Query(params): Query<LnurlPayCallbackParams>,
    State(state): State<AppState>,
) -> Result<Json<LnurlPayCallbackResponse>, ApiError> {
    // Validate amount range
    if params.amount < 1000 || params.amount > 100_000_000 {
        return Ok(Json(LnurlPayCallbackResponse::Error {
            status: "ERROR".to_string(),
            reason: "Amount must be between 1 and 100,000 sats".to_string(),
        }));
    }

    let user = db::get_user_by_username(&state.db, username.clone())
        .await
        .ok_or(ApiError::not_found("User not found"))?;

    // Create description
    let description = match params.comment {
        Some(comment) => comment,
        None => format!("{}@{}", username, state.api_bind),
    };

    // Generate invoice using existing LDK logic
    let invoice = state
        .node
        .bolt11_payment()
        .receive(
            params.amount,
            &Description::new(description.clone())
                .map(Bolt11InvoiceDescription::Direct)
                .map_err(ApiError::bad_request)?,
            3600, // 1 hour expiry
        )
        .map_err(ApiError::internal_server_error)?;

    db::create_bolt11_invoice(
        &state.db,
        user.username,
        invoice.clone(),
        params.amount as i64,
        description,
    )
    .await;

    Ok(Json(LnurlPayCallbackResponse::Success {
        pr: invoice.to_string(),
    }))
}
