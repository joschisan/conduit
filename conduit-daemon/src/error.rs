use axum::http::StatusCode;
use axum::response::IntoResponse;
use std::fmt::Display;

// Custom error type that produces JSON responses
pub struct ApiError {
    pub code: StatusCode,
    pub error: String,
}

impl ApiError {
    pub fn bad_request(error: impl Display) -> Self {
        Self {
            code: StatusCode::BAD_REQUEST,
            error: error.to_string(),
        }
    }

    pub fn not_found(error: impl Display) -> Self {
        Self {
            code: StatusCode::NOT_FOUND,
            error: error.to_string(),
        }
    }

    pub fn internal_server_error(error: impl Display) -> Self {
        Self {
            code: StatusCode::INTERNAL_SERVER_ERROR,
            error: error.to_string(),
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> axum::response::Response {
        (self.code, self.error).into_response()
    }
}
