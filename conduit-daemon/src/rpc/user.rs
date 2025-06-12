use axum::response::Sse;
use axum::response::sse::Event;
use axum::{
    extract::{Extension, State},
    response::Json,
};
use bitcoin::hashes::Hash;
use conduit_core::user::AppEvent;
use conduit_core::user::InvoicesResponse;
use conduit_core::user::{
    BalanceResponse, Bolt11QuoteResponse, Bolt11ReceiveResponse, PaymentsResponse,
    UserBolt11QuoteRequest, UserBolt11ReceiveRequest, UserBolt11SendRequest,
};
use futures::TryStreamExt;
use futures::stream;
use ldk_node::payment::SendingParameters;
use lightning_invoice::{Bolt11InvoiceDescription, Description};
use std::future;
use std::pin::Pin;
use tokio_stream::Stream;
use tokio_stream::StreamExt;

use crate::AppState;
use crate::Bolt11Receive;
use crate::db;
use crate::error::ApiError;

#[axum::debug_handler]
pub async fn balance(
    State(state): State<AppState>,
    Extension(username): Extension<String>,
) -> Result<Json<BalanceResponse>, ApiError> {
    let balance = db::get_user_balance(&state.db, username).await;

    Ok(Json(BalanceResponse { balance }))
}

#[axum::debug_handler]
pub async fn payments(
    State(state): State<AppState>,
    Extension(username): Extension<String>,
) -> Result<Json<PaymentsResponse>, ApiError> {
    let payments = db::get_user_payments(&state.db, username).await;

    Ok(Json(PaymentsResponse { payments }))
}

#[axum::debug_handler]
pub async fn invoices(
    State(state): State<AppState>,
    Extension(username): Extension<String>,
) -> Result<Json<InvoicesResponse>, ApiError> {
    let invoices = db::get_user_invoices(&state.db, username).await;

    Ok(Json(InvoicesResponse { invoices }))
}

#[axum::debug_handler]
pub async fn bolt11_receive(
    State(state): State<AppState>,
    Extension(username): Extension<String>,
    Json(request): Json<UserBolt11ReceiveRequest>,
) -> Result<Json<Bolt11ReceiveResponse>, ApiError> {
    let invoice = state
        .node
        .bolt11_payment()
        .receive(
            request.amount_msat.into(),
            &Description::new(request.description.clone())
                .map(Bolt11InvoiceDescription::Direct)
                .map_err(ApiError::bad_request)?,
            request.expiry_secs,
        )
        .map_err(ApiError::internal_server_error)?;

    db::create_bolt11_invoice(
        &state.db,
        username,
        invoice.clone(),
        request.amount_msat.into(),
        request.description,
    )
    .await;

    Ok(Json(Bolt11ReceiveResponse { invoice }))
}

#[axum::debug_handler]
pub async fn bolt11_send(
    State(state): State<AppState>,
    Extension(username): Extension<String>,
    Json(request): Json<UserBolt11SendRequest>,
) -> Result<Json<()>, ApiError> {
    let amount_msat = request
        .invoice
        .amount_milli_satoshis()
        .ok_or(ApiError::bad_request("Invoice is missing amount"))?
        .try_into()
        .map_err(|_| ApiError::bad_request("Invalid invoice amount"))?;

    let fee_msat = state.get_fee_msat(amount_msat);

    let send_lock = state.send_lock.lock().await;

    let balance_msat = db::get_user_balance(&state.db, username.clone()).await.msat as i64;

    if balance_msat < amount_msat + fee_msat {
        return Err(ApiError::bad_request("Insufficient balance"));
    }

    let payment_hash = request.invoice.payment_hash().to_byte_array();

    let invoice_opt = db::get_bolt11_invoice(&state.db, payment_hash).await;

    let send_status = if let Some(invoice) = invoice_opt {
        if invoice.username == username {
            return Err(ApiError::bad_request("This is your own invoice"));
        }

        db::create_bolt11_receive_payment(&state.db, invoice.clone().into()).await;

        let balance = db::get_user_balance(&state.db, invoice.username.clone()).await;

        state
            .event_bus
            .send_balance_event(invoice.username.clone(), balance);

        state.event_bus.send_payment_event(
            invoice.username.clone(),
            Into::<Bolt11Receive>::into(invoice).into(),
        );

        "successful".to_string()
    } else {
        state
            .node
            .bolt11_payment()
            .send(&request.invoice, Some(sending_parameters(amount_msat)))
            .map_err(ApiError::internal_server_error)?;

        "pending".to_string()
    };

    let send_record = db::create_bolt11_send_payment(
        &state.db,
        username.clone(),
        request.invoice.clone(),
        amount_msat,
        fee_msat,
        request.lightning_address.clone(),
        send_status,
    )
    .await;

    drop(send_lock);

    let balance = db::get_user_balance(&state.db, username.clone()).await;

    state
        .event_bus
        .send_balance_event(username.clone(), balance);

    state
        .event_bus
        .send_payment_event(username.clone(), send_record.into());

    Ok(Json(()))
}

fn sending_parameters(amount_msat: i64) -> SendingParameters {
    SendingParameters {
        max_total_routing_fee_msat: Some(Some(amount_msat as u64)),
        max_total_cltv_expiry_delta: None,
        max_path_count: None,
        max_channel_saturation_power_of_half: None,
    }
}

#[axum::debug_handler]
pub async fn bolt11_quote(
    State(state): State<AppState>,
    Json(request): Json<UserBolt11QuoteRequest>,
) -> Result<Json<Bolt11QuoteResponse>, ApiError> {
    let amount_msat: i64 = request
        .invoice
        .amount_milli_satoshis()
        .ok_or(ApiError::bad_request("Invoice is missing amount"))?
        .try_into()
        .map_err(|_| ApiError::bad_request("Invalid invoice amount"))?;

    let response = Bolt11QuoteResponse {
        amount_msat: amount_msat as u64,
        fee_msat: state.get_fee_msat(amount_msat) as u64,
        description: request.invoice.description().to_string(),
        expiry_secs: request.invoice.expiry_time().as_secs(),
    };

    Ok(Json(response))
}

/// Event stream for a user
#[axum::debug_handler]
pub async fn events(
    State(state): State<AppState>,
    Extension(username): Extension<String>,
) -> Sse<Pin<Box<dyn Stream<Item = Result<Event, String>> + Send>>> {
    let stream = state
        .event_bus
        .clone()
        .subscribe_to_events(username.clone());

    let balance = db::get_user_balance(&state.db, username.clone()).await;

    let balance_event = AppEvent::Balance(balance.clone());

    let payments = db::get_user_payments(&state.db, username.clone()).await;

    let payment_events = payments.into_iter().map(AppEvent::Payment);

    let stream = stream::once(future::ready(Ok(balance_event)))
        .chain(stream::iter(payment_events.map(Ok)))
        .chain(stream)
        .map_ok(|event| Event::default().data(serde_json::to_string(&event).unwrap()));

    Sse::new(Box::pin(stream))
}
