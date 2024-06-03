//! # Documentation for the Velocity API
//! This part of the documentation is less focussed on
//! documenting the internal workings of the code, but rather
//! on documenting the interaction between a client and the
//! Velocity hypervisor. Functions defined in this module and all
//! submodules may not represent callable functions, but rather
//! API endpoints and their workings.
//!
//! The primary language of communication is `json` due to its
//! human-readable qualities and clear syntax. Most endpoints
//! do only accept `json` and document the request structure thoroughly.
//!
//! ## API versioning
//! The Velocity API allows for versioning every endpoint individually
//! by appending the version number to the end. The `/u/auth` endpoint in
//! version `1` is available under `/u/auth/1`. If the version changes to `2`,
//! a new endpoint will be created that is mounted at `/u/auth/2`.
//!
//! This mechanism is individual per method, meaning that a `/u/auth` can have
//! its `POST` method at version `1` and its `DELETE` method at version `2`.
//!
//! ## Routes
//! - [`/u`: User management](u)

use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json, Router,
};
use log::error;
use serde::Serialize;
use serde_json::{json, Value};

use crate::{error::VError, VelocityState};

pub mod u;

#[doc(hidden)]
pub fn get_router(velocity: VelocityState) -> Router {
    Router::new().nest("/u", u::get_router(velocity))
}

/// All errors that can be transmitted via the velocity API
pub struct VelocityAPIError(VError);

impl IntoResponse for VelocityAPIError {
    fn into_response(self) -> Response {
        error!("{:?}", self.0);
        let err = self.0.error.to_string();
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({
                "code": 1000,
                "message": err
            })),
        )
            .into_response()
    }
}

impl<E> From<E> for VelocityAPIError
where
    E: Into<VError>,
{
    fn from(err: E) -> Self {
        Self(err.into())
    }
}

/// Implement a JSON utility function to convert
/// a structure to a [Value] or panic
pub trait ToJSONPanic: Serialize {
    /// Convert `self` to a [`Value`] or panic.
    ///
    /// This is safe as no structures should be able to produce invalid JSON
    /// values.
    fn to_json_p(&self) -> Json<Value> {
        let val = serde_json::to_value(self);

        match val {
            Ok(val) => Json(val),
            Err(e) => {
                panic!("Expected flawless conversion to JSON value: {e}")
            }
        }
    }
}
