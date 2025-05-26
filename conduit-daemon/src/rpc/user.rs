use axum::response::Sse;
use axum::response::sse::Event;
use axum::{
    extract::{Extension, State},
    response::Json,
};
use conduit_core::user::AppEvent;
use conduit_core::user::InvoicesResponse;
use conduit_core::user::{
    BalanceResponse, Bolt11QuoteResponse, Bolt11ReceiveResponse, PaymentsResponse,
    UserBolt11QuoteRequest, UserBolt11ReceiveRequest, UserBolt11SendRequest,
};
use futures::TryStreamExt;
use futures::stream;
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
    let payment_hash = *request.invoice.payment_hash().as_ref();

    let invoice_opt = db::get_bolt11_invoice(&state.db, payment_hash).await;

    if let Some(invoice) = invoice_opt {
        if invoice.username == username {
            return Err(ApiError::bad_request(
                "Invoice was created by the same user",
            ));
        }

        let send_record = db::create_bolt11_send_payment(
            &state.db,
            username.clone(),
            request.invoice.clone(),
            request.lightning_address.clone(),
            "successful".to_string(),
        )
        .await
        .map_err(ApiError::bad_request)?;

        let balance = db::get_user_balance(&state.db, username.clone()).await;

        state
            .event_bus
            .send_balance_event(username.clone(), balance);

        state
            .event_bus
            .send_payment_event(username.clone(), send_record.into());

        db::create_bolt11_receive_payment(&state.db, invoice.clone().into()).await;

        let balance = db::get_user_balance(&state.db, invoice.username.clone()).await;

        state
            .event_bus
            .send_balance_event(invoice.username.clone(), balance);

        state.event_bus.send_payment_event(
            invoice.username.clone(),
            Into::<Bolt11Receive>::into(invoice).into(),
        );
    } else {
        let send_record = db::create_bolt11_send_payment(
            &state.db,
            username.clone(),
            request.invoice.clone(),
            request.lightning_address.clone(),
            "pending".to_string(),
        )
        .await
        .map_err(ApiError::bad_request)?;

        state
            .node
            .bolt11_payment()
            .send(&request.invoice, None)
            .map_err(ApiError::internal_server_error)?;

        let balance = db::get_user_balance(&state.db, username.clone()).await;

        state
            .event_bus
            .send_balance_event(username.clone(), balance);

        state
            .event_bus
            .send_payment_event(username, send_record.into());
    }

    Ok(Json(()))
}

#[axum::debug_handler]
pub async fn bolt11_quote(
    Json(request): Json<UserBolt11QuoteRequest>,
) -> Result<Json<Bolt11QuoteResponse>, ApiError> {
    let amount_msat = request
        .invoice
        .amount_milli_satoshis()
        .ok_or(ApiError::bad_request("Invoice is missing amount"))?;

    let response = Bolt11QuoteResponse {
        amount_msat: amount_msat,
        fee_msat: (amount_msat / 100) + 5_000,
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
