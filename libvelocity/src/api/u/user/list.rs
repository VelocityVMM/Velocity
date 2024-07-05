//! # `/u/user/list` - Endpoints for listing users
//! ### POST
//! - [`/u/user/list/1 - POST`](u_user_list_post_1): List registered users

use axum::{
    extract::State, http::StatusCode, middleware::from_fn_with_state, response::IntoResponse,
    routing::post, Extension, Router,
};
use log::info;
use serde::Serialize;

use crate::{
    api::{ToJSONPanic, VelocityAPIError, VelocityState},
    authentication::auth_middleware,
    model::{Entitlement, User},
};

#[doc(hidden)]
pub fn get_router(velocity: VelocityState) -> Router {
    Router::new()
        .route("/1", post(u_user_list_post_1))
        .with_state(velocity.clone())
        .layer(from_fn_with_state(velocity, auth_middleware))
}

/// A single user description
#[derive(Serialize)]
pub struct POSTRes1User {
    /// The user id of the user
    pub uid: u32,
    /// The username of the user
    pub username: String,
}

/// The response structure for the `/u/user/list/1 - POST` endpoint
#[derive(Serialize)]
pub struct POSTRes1 {
    pub users: Vec<POSTRes1User>,
}

impl ToJSONPanic for POSTRes1 {}

/// # `/u/user/1 - PUT` - List registered users
///
/// # Permissions
/// The calling user needs the `velocity.user.list` permission
///
/// # Request
/// No body
///
/// # Response
/// #### `200 - OK` [POSTRes1]
/// The list of registered users
///
/// #### `403 - FORBIDDEN`
/// The calling user is not allowed to list users
pub async fn u_user_list_post_1(
    State(velocity): State<VelocityState>,
    Extension(user): Extension<User>,
) -> Result<impl IntoResponse, VelocityAPIError> {
    let req_user = velocity
        .global_permission_guard(user, Entitlement::UserList)
        .await?;

    let users = User::list(&velocity.read().await.db).await?;

    let users: Vec<POSTRes1User> = users
        .into_iter()
        .map(|u| POSTRes1User {
            uid: u.uid(),
            username: u.username,
        })
        .collect();

    info!(
        "[POST/1] {req_user} listed available users - {} users",
        users.len()
    );

    Ok((StatusCode::OK, POSTRes1 { users }.to_json_p()))
}
