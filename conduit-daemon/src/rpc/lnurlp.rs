use crate::AppState;
use crate::db;
use crate::error::ApiError;
use axum::{
    extract::{Path, Query, State},
    response::Json,
};
use lightning_invoice::{Bolt11InvoiceDescription, Description};
use serde::{Deserialize, Serialize};
use tracing::info;
use url::Url;

#[derive(Serialize)]
pub struct LnurlPayResponse {
    tag: String,
    callback: Url,
    #[serde(rename = "minSendable")]
    min_sendable: u64,
    #[serde(rename = "maxSendable")]
    max_sendable: u64,
    metadata: String,
}

#[derive(Debug, Deserialize)]
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
        .ok_or(ApiError::bad_request("User not found"))?;

    // Encode the username directly in the callback URL path
    let callback = state
        .args
        .public_base_url
        .join("lnurlp/callback/")
        .expect("Failed to join public base URL and callback path")
        .join(&username)
        .expect("Failed to join username and callback URL");

    Ok(Json(LnurlPayResponse {
        tag: "payRequest".to_string(),
        callback,
        min_sendable: state.args.min_amount_sat as u64 * 1000, // Convert sats to millisats
        max_sendable: state.args.max_amount_sat as u64 * 1000, // Convert sats to millisats
        metadata: format!(r#"[["text/plain", "Payment to {}"]]"#, username),
    }))
}

// Invoice generation callback
#[axum::debug_handler]
pub async fn lnurl_pay_callback(
    Path(username): Path<String>,
    Query(params): Query<LnurlPayCallbackParams>,
    State(state): State<AppState>,
) -> Result<Json<LnurlPayCallbackResponse>, ApiError> {
    info!(?params, "lnurl pay callback");

    let pending = db::count_pending_invoices(&state.db, username.clone()).await;

    if pending >= state.args.max_pending_payments_per_user as i64 {
        return Ok(Json(LnurlPayCallbackResponse::Error {
            status: "ERROR".to_string(),
            reason: "Too many pending invoices".to_string(),
        }));
    }

    if params.amount < state.args.min_amount_sat as u64 * 1000 {
        return Ok(Json(LnurlPayCallbackResponse::Error {
            status: "ERROR".to_string(),
            reason: format!("The minimum amount is {} sats", state.args.min_amount_sat),
        }));
    }

    if params.amount > state.args.max_amount_sat as u64 * 1000 {
        return Ok(Json(LnurlPayCallbackResponse::Error {
            status: "ERROR".to_string(),
            reason: format!("The maximum amount is {} sats", state.args.max_amount_sat),
        }));
    }

    let user = db::get_user_by_username(&state.db, username.clone())
        .await
        .ok_or(ApiError::bad_request("User not found"))?;

    let invoice = state
        .node
        .bolt11_payment()
        .receive(
            params.amount,
            &Description::new(params.comment.clone().unwrap_or_default())
                .map(Bolt11InvoiceDescription::Direct)
                .map_err(ApiError::bad_request)?,
            state.args.invoice_expiry_secs,
        )
        .map_err(ApiError::internal_server_error)?;

    db::create_bolt11_invoice(
        &state.db,
        user.username,
        invoice.clone(),
        params.amount as i64,
        params.comment.clone().unwrap_or_default(),
        state.args.invoice_expiry_secs,
    )
    .await;

    Ok(Json(LnurlPayCallbackResponse::Success {
        pr: invoice.to_string(),
    }))
}
