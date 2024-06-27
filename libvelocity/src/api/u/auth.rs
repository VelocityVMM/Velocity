//! # `/u/auth` - Endpoints for managing authentication
//! ### POST
//! - [`/u/auth/1 - POST`](u_auth_post_1): Authenticate a user
//! ### PATCH
//! - [`/u/auth/1 - PATCH`](u_auth_patch_1): Refresh an authkey lease
//! ### DELETE
//! - [`/u/auth/1 - DELETE`](u_auth_delete_1): Revoke an authkey

use std::time::Duration;

use axum::{extract::State, http::StatusCode, response::IntoResponse, routing::post, Json, Router};
use log::{info, warn};
use serde::Deserialize;
use serde_json::json;

use crate::{
    api::{ToJSONPanic, VelocityAPIError},
    model::User,
    VelocityState,
};

#[doc(hidden)]
pub fn get_router(velocity: VelocityState) -> Router {
    Router::new()
        .route(
            "/1",
            post(u_auth_post_1)
                .patch(u_auth_patch_1)
                .delete(u_auth_delete_1),
        )
        .with_state(velocity)
}

/// The request structure for the `/u/auth/1 - POST` endpoint
#[derive(Deserialize)]
pub struct POSTReq1 {
    /// The username for the user to authenticate as
    pub username: String,
    /// The password to use for authentication
    pub password: String,
}

/// # `/u/auth/1 - POST` - Authenticate a user
/// Takes the request parameters and tries to authenticate a user.
///
/// # Request
/// A `json` request in the form of [POSTReq1].
///
/// # Response
/// #### `200 - OK`
/// The authentication was successful.
///
/// The returned `authkey` can be used for privileged actions.
/// ```json
/// {
///     "authkey": "<authkey>",
///     "expires": "<UNIX time>"
/// }
/// ```
///
/// #### `403 - FORBIDDEN`
/// Authentication failed due to one of the following reasons:
/// - The `username` did not match any registered user
/// - The `password` did not match
/// - An internal server error happened
pub async fn u_auth_post_1(
    State(velocity): State<VelocityState>,
    Json(payload): Json<POSTReq1>,
) -> Result<impl IntoResponse, VelocityAPIError> {
    let user =
        User::try_select_username(&velocity.velocity.read().await.db, &payload.username).await?;

    let user = match user {
        Some(user) => user,
        None => {
            warn!("[POST/1] User '{}' not found", payload.username);
            return Ok((StatusCode::UNAUTHORIZED, Json(json!({}))));
        }
    };

    if user.pwhash == payload.password {
        let key = velocity
            .velocity
            .write()
            .await
            .auth_manager
            .generate_now(user.uid(), Duration::from_secs(10));
        info!(
            "[POST/1] Authenticated user '{}' ({})",
            user.username,
            key.uid()
        );
        Ok((StatusCode::OK, key.to_json_p()))
    } else {
        warn!("[POST/1] User '{}' failed to authenticate", user.username);
        Ok((StatusCode::UNAUTHORIZED, Json(json!({}))))
    }
}

/// The request structure for the `/u/auth/1 - PATCH` endpoint
#[derive(Deserialize)]
pub struct PATCHReq1 {
    /// The `authkey` to revoke
    pub authkey: String,
}

/// # `/u/auth/1 - PATCH` - Renew an existing authkey
/// Takes an existing, valid `authkey` and exchanges it for a new one.
/// This will drop the old one and return a new key.
///
/// # Request
/// A `json` request in the form of [PATCHReq1].
///
/// # Response
/// #### `200 - OK`
/// The `authkey` was refreshed successfully.
/// ```json
/// {
///     "authkey": "<authkey>",
///     "expires": "<UNIX time>"
/// }
/// ```
///
/// #### `403 - FORBIDDEN`
/// The authkey renewal failed due to one of the following reasons:
/// - The `authkey` is not registered or unknown
/// - The `authkey` is expired
/// - An internal server error happened
pub async fn u_auth_patch_1(
    State(velocity): State<VelocityState>,
    Json(payload): Json<PATCHReq1>,
) -> impl IntoResponse {
    let key = velocity
        .velocity
        .write()
        .await
        .auth_manager
        .refresh_key(&payload.authkey, Duration::from_secs(10));

    match key {
        None => {
            warn!(
                "[PATCH/1] Tried to reauthenticate unknown authkey {}",
                payload.authkey
            );
            (StatusCode::UNAUTHORIZED, Json(json!({})))
        }
        Some(key) => {
            info!("Reauthenticated UID {}", key.uid());
            (StatusCode::OK, key.to_json_p())
        }
    }
}

/// The request structure for the `/u/auth/1 - DELETE` endpoint
#[derive(Deserialize)]
pub struct DELETEReq1 {
    /// The `authkey` to refresh
    pub authkey: String,
}

/// # `/u/auth/1 - DELETE` - Revoke an authkey
/// Takes an `authkey` and de-authenticates it.
///
/// This revokes any permission to perform privileged actions.
///
/// # Request
/// A `json` request in the form of [DELETEReq1].
///
/// # Response
/// Due to security reasons, dropping an invalid
/// authkey still results in a `200 - OK` response.
///
/// #### `200 - OK`
/// The authkey was revoked successfully
pub async fn u_auth_delete_1(
    State(velocity): State<VelocityState>,
    Json(payload): Json<DELETEReq1>,
) -> impl IntoResponse {
    velocity
        .velocity
        .write()
        .await
        .auth_manager
        .drop_key(&payload.authkey);

    StatusCode::OK
}
