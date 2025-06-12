use axum::{Json, extract::State};
use serde_json::Value;

use conduit_core::admin::{
    BalancesResponse, ChannelInfo, CloseChannelRequest, ConnectPeerRequest, CreditUserRequest,
    DisconnectPeerRequest, ListChannelsResponse, ListPeersResponse, NewAddressResponse,
    NodeIdResponse, OnchainSendRequest, OpenChannelRequest, OpenChannelResponse, PeerInfo,
};
use ldk_node::UserChannelId;

use crate::AppState;
use crate::db;
use crate::error::ApiError;

#[axum::debug_handler]
pub async fn ldk_node_id(State(state): State<AppState>) -> Json<NodeIdResponse> {
    Json(NodeIdResponse {
        node_id: state.node.node_id(),
    })
}

#[axum::debug_handler]
pub async fn ldk_onchain_receive(
    State(state): State<AppState>,
) -> Result<Json<NewAddressResponse>, ApiError> {
    state
        .node
        .onchain_payment()
        .new_address()
        .map(|address| {
            Json(NewAddressResponse {
                address: address.into_unchecked(),
            })
        })
        .map_err(ApiError::internal_server_error)
}

#[axum::debug_handler]
pub async fn ldk_onchain_send(
    State(state): State<AppState>,
    Json(request): Json<OnchainSendRequest>,
) -> Result<Json<()>, ApiError> {
    state
        .node
        .onchain_payment()
        .send_to_address(
            &request.address.assume_checked(),
            request.amount_sats,
            request.fee_rate,
        )
        .map_err(ApiError::internal_server_error)?;

    Ok(Json(()))
}

#[axum::debug_handler]
pub async fn ldk_balances(
    State(state): State<AppState>,
) -> Result<Json<BalancesResponse>, ApiError> {
    let total_onchain_balance_sats = state.node.list_balances().total_onchain_balance_sats;

    let total_inbound_capacity_msats = state
        .node
        .list_channels()
        .into_iter()
        .filter(|c| c.is_usable)
        .map(|c| c.inbound_capacity_msat)
        .sum::<u64>();

    let total_outbound_capacity_msats = state
        .node
        .list_channels()
        .into_iter()
        .filter(|c| c.is_usable)
        .map(|c| c.outbound_capacity_msat)
        .sum::<u64>();

    Ok(Json(BalancesResponse {
        total_onchain_balance_sats,
        total_inbound_capacity_msats,
        total_outbound_capacity_msats,
    }))
}

#[axum::debug_handler]
pub async fn ldk_channel_open(
    State(state): State<AppState>,
    Json(request): Json<OpenChannelRequest>,
) -> Result<Json<OpenChannelResponse>, ApiError> {
    state
        .node
        .open_announced_channel(
            request.node_id,
            request.address.into(),
            request.channel_amount_sats,
            request.push_to_counterparty_msat,
            None,
        )
        .map(|channel_id| {
            Json(OpenChannelResponse {
                channel_id: channel_id.0.to_string(),
            })
        })
        .map_err(ApiError::internal_server_error)
}

#[axum::debug_handler]
pub async fn ldk_channel_close(
    State(state): State<AppState>,
    Json(request): Json<CloseChannelRequest>,
) -> Result<Json<()>, ApiError> {
    match request.force {
        true => {
            state
                .node
                .force_close_channel(
                    &UserChannelId(request.user_channel_id),
                    request.counterparty_node_id,
                    None,
                )
                .map_err(ApiError::internal_server_error)?;

            Ok(Json(()))
        }
        false => {
            state
                .node
                .close_channel(
                    &UserChannelId(request.user_channel_id),
                    request.counterparty_node_id,
                )
                .map_err(ApiError::internal_server_error)?;

            Ok(Json(()))
        }
    }
}

#[axum::debug_handler]
pub async fn credit_user(
    State(state): State<AppState>,
    Json(request): Json<CreditUserRequest>,
) -> Result<Json<()>, ApiError> {
    db::credit_user(&state.db, request.username, request.amount_msat).await;

    Ok(Json(()))
}

pub async fn ldk_channel_list(
    State(state): State<AppState>,
    Json(_request): Json<Value>,
) -> Result<Json<ListChannelsResponse>, ApiError> {
    let channels = state
        .node
        .list_channels()
        .into_iter()
        .map(|channel| ChannelInfo {
            user_channel_id: channel.user_channel_id.0,
            counterparty_node_id: channel.counterparty_node_id,
            channel_value_sats: channel.channel_value_sats,
            outbound_capacity_msat: channel.outbound_capacity_msat,
            inbound_capacity_msat: channel.inbound_capacity_msat,
            is_channel_ready: channel.is_channel_ready,
            is_usable: channel.is_usable,
            is_outbound: channel.is_outbound,
            confirmations: channel.confirmations,
            confirmations_required: channel.confirmations_required,
        })
        .collect();

    Ok(Json(ListChannelsResponse { channels }))
}

#[axum::debug_handler]
pub async fn ldk_peer_connect(
    State(state): State<AppState>,
    Json(request): Json<ConnectPeerRequest>,
) -> Result<Json<()>, ApiError> {
    state
        .node
        .connect(request.node_id, request.address.into(), request.persist)
        .map_err(ApiError::internal_server_error)?;

    Ok(Json(()))
}

#[axum::debug_handler]
pub async fn ldk_peer_disconnect(
    State(state): State<AppState>,
    Json(request): Json<DisconnectPeerRequest>,
) -> Result<Json<()>, ApiError> {
    state
        .node
        .disconnect(request.counterparty_node_id)
        .map_err(ApiError::internal_server_error)?;

    Ok(Json(()))
}

#[axum::debug_handler]
pub async fn ldk_peer_list(
    State(state): State<AppState>,
    Json(_request): Json<Value>,
) -> Result<Json<ListPeersResponse>, ApiError> {
    let peers = state
        .node
        .list_peers()
        .into_iter()
        .map(|peer| PeerInfo {
            node_id: peer.node_id,
            address: peer.address.to_string(),
            is_persisted: peer.is_persisted,
            is_connected: peer.is_connected,
        })
        .collect();

    Ok(Json(ListPeersResponse { peers }))
}
