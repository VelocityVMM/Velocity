//! # `/u/user` - Endpoints for managing users
//! ## Routes
//! - [`/u/user/list`](list): List users
//! - [`/u/user/permission`](permission): Manage user permissions
//! ### PUT
//! - [`/u/user/1 - PUT`](u_user_put_1): Create a new user
//! ### DELETE
//! - [`/u/user/1 - DELETE`](u_user_delete_1): Remove a user

pub mod list;
pub mod permission;

use axum::{
    extract::State,
    http::StatusCode,
    middleware::from_fn_with_state,
    response::IntoResponse,
    routing::{delete, put},
    Extension, Json, Router,
};
use log::{error, info};
use serde::{Deserialize, Serialize};

use crate::{
    api::{empty_json, ToJSONPanic, VelocityAPIError},
    authentication::auth_middleware,
    model::{Entitlement, User},
    VelocityState,
};

#[doc(hidden)]
pub fn get_router(velocity: VelocityState) -> Router {
    Router::new()
        .route("/1", put(u_user_put_1))
        .route("/1", delete(u_user_delete_1))
        .with_state(velocity.clone())
        .layer(from_fn_with_state(velocity.clone(), auth_middleware))
        .nest("/list", list::get_router(velocity.clone()))
        .nest("/permission", permission::get_router(velocity))
}

/// The request structure for the `/u/user/1 - PUT` endpoint
#[derive(Deserialize)]
pub struct PUTReq1 {
    /// The username for the user to create
    pub username: String,
    /// The password to use for the newly created user
    pub password: String,
}

/// The response structure for the `/u/user/1 - PUT` endpoint
#[derive(Serialize)]
pub struct PUTRes1 {
    /// The user id of the newly created user
    pub uid: u32,
    /// The username for the new user
    pub username: String,
}

impl ToJSONPanic for PUTRes1 {}

/// # `/u/user/1 - PUT` - Create a new user
/// Takes the request parameters and creates a new user.
///
/// # Permissions
/// The user needs the `velocity.user.create` permission
///
/// # Request
/// A `json` request in the form of [PUTReq1].
///
/// # Response
/// #### `200 - OK` [PUTRes1]
/// A new user was created using the supplied options
///
/// #### `403 - FORBIDDEN`
/// The calling user is not allowed to create new users
///
/// #### `409 - CONFLICT`
/// A user with the supplied `username` does already exist
pub async fn u_user_put_1(
    State(velocity): State<VelocityState>,
    Extension(user): Extension<User>,
    Json(request): Json<PUTReq1>,
) -> Result<impl IntoResponse, VelocityAPIError> {
    let req_user = velocity
        .global_permission_guard(user, Entitlement::UserCreate)
        .await?;

    if let Some(user) =
        User::try_select_username(&velocity.velocity.read().await.db, &request.username).await?
    {
        error!("[PUT/1] {req_user} tried to create existing user {user}");
        return Ok((StatusCode::CONFLICT, empty_json()));
    }

    let new_user = User::create(
        &velocity.velocity.read().await.db,
        &request.username,
        &request.password,
    )
    .await?;

    info!("[PUT/1] {req_user} created new user {new_user}");

    let res = PUTRes1 {
        username: request.username,
        uid: new_user.uid(),
    };

    Ok((StatusCode::OK, res.to_json_p()))
}

/// The request structure for the `/u/user/1 - PUT` endpoint
#[derive(Deserialize)]
pub struct DELETEReq1 {
    /// The user id of the user to remove
    pub uid: u32,
}

/// # `/u/user/1 - DELETE` - Remove a user
/// Takes the request parameters and removes a user.
///
/// # Permissions
/// The user needs the `velocity.user.remove` permission
///
/// # Request
/// A `json` request in the form of [DELETEReq1].
///
/// # Response
/// #### `200 - OK`
/// The user was deleted
///
/// #### `403 - FORBIDDEN`
/// The calling user is not allowed to remove users
///
/// #### `404 - NOT FOUND`
/// The user id to remove has not been found
pub async fn u_user_delete_1(
    State(velocity): State<VelocityState>,
    Extension(user): Extension<User>,
    Json(request): Json<DELETEReq1>,
) -> Result<impl IntoResponse, VelocityAPIError> {
    let req_user = velocity
        .global_permission_guard(user, Entitlement::UserRemove)
        .await?;

    let user = match User::try_select_uid(&velocity.velocity.read().await.db, request.uid).await? {
        None => {
            error!(
                "[DELETE/1] {req_user} tried to remove non-existing UID {}",
                request.uid
            );
            return Ok(StatusCode::NOT_FOUND);
        }
        Some(user) => user,
    };

    let username = user.username.clone();
    user.remove(&velocity.velocity.read().await.db).await?;

    info!("[DELETE/1] {req_user} removed user {username}");

    Ok(StatusCode::OK)
}
