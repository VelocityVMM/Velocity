//! # `/u/user/permission` - Endpoints for managing user permissions
//! ### PUT
//! - [`/u/user/permission/1 - PUT`](u_user_permission_put_1): Grant a user a permission
//! ### DELETE
//! - [`/u/user/permission/1 - DELETE`](u_user_permission_delete_1): Revoke a permission from a user

use axum::{
    extract::State,
    http::StatusCode,
    middleware::from_fn_with_state,
    response::IntoResponse,
    routing::{delete, put},
    Extension, Json, Router,
};
use log::{error, info};
use serde::Deserialize;

use crate::{
    api::{VelocityAPIError, VelocityState},
    authentication::auth_middleware,
    model::{Entitlement, Group, Permission, User},
};

#[doc(hidden)]
pub fn get_router(velocity: VelocityState) -> Router {
    Router::new()
        .route("/1", put(u_user_permission_put_1))
        .route("/1", delete(u_user_permission_delete_1))
        .with_state(velocity.clone())
        .layer(from_fn_with_state(velocity, auth_middleware))
}

/// The request structure for the `/u/user/permission/1 - PUT` endpoint
#[derive(Deserialize)]
pub struct PUTReq1 {
    /// The user id of the user to permit
    pub uid: u32,
    /// The group id of the group to permit the user to
    pub gid: u32,
    /// The permission to grant the user on that group
    pub permission: String,
    /// Whether the user should be able to delegate this
    /// permission to other users
    pub delegable: bool,
}

/// # `/u/user/permission/1 - PUT` - Grant a user a permission on a group
///
/// # Permissions
/// The calling user needs the permission on the target group and `delegable`
/// to be set to `true` for that membership
///
/// # Request
/// A `json` request in the form of [PUTReq1].
///
/// # Response
/// #### `200 - OK`
/// The permission has been granted
///
/// #### `403 - FORBIDDEN`
/// The calling user cannot execute this action due to one of
/// the following reasons:
/// - The user doesn't have the permission on the group
/// - The user is not allowed to delegate the permission
///
/// #### `404 - NOT FOUND`
/// One of the following entities was not found in the Velocity system:
/// - The permission to be granted
/// - The user to be granted the permission
/// - The group to grant the user permission for
pub async fn u_user_permission_put_1(
    State(velocity): State<VelocityState>,
    Extension(user): Extension<User>,
    Json(request): Json<PUTReq1>,
) -> Result<impl IntoResponse, VelocityAPIError> {
    let req_user = velocity
        .global_permission_guard(user, Entitlement::UserList)
        .await?;

    let db = &velocity.read().await.db;

    let permission = match Permission::try_select_name(db, &request.permission).await? {
        Some(permission) => permission,
        None => return Ok(StatusCode::NOT_FOUND),
    };

    let user = match User::try_select_uid(db, request.uid).await? {
        Some(user) => user,
        None => return Ok(StatusCode::NOT_FOUND),
    };

    let group = match Group::try_select_gid(db, request.gid).await? {
        Some(group) => group,
        None => return Ok(StatusCode::NOT_FOUND),
    };

    if !permission.can_delegate(db, &req_user, &group).await? {
        error!(
            "[PUT/1] User {req_user} cannot delegate permission {} on {group} without delegation permission",
            permission.name
        );
        return Ok(StatusCode::FORBIDDEN);
    }

    permission
        .grant(db, &user, &group, request.delegable)
        .await?;

    info!(
        "[PUT/1] {req_user} granted {user} permission '{}' on {group}, delegate={}",
        permission.name, request.delegable
    );

    Ok(StatusCode::OK)
}

/// The request structure for the `/u/user/permission/1 - DELETE` endpoint
#[derive(Deserialize)]
pub struct DELETEReq1 {
    /// The user id of the user to revoke the permission of
    pub uid: u32,
    /// The group id of the group to revoke the
    /// user's permission from
    pub gid: u32,
    /// The permission to revoke from user on that group
    pub permission: String,
}

/// # `/u/user/permission/1 - DELETE` - Revoke a user's permission on a group
///
/// # Permissions
/// The calling user needs the permission on the target group and `delegable`
/// to be set to `true` for that membership
///
/// # Request
/// A `json` request in the form of [DELETEReq1].
///
/// # Response
/// #### `200 - OK`
/// The permission has been revoked
///
/// #### `403 - FORBIDDEN`
/// The calling user cannot execute this action due to one of
/// the following reasons:
/// - The user doesn't have the permission on the group
/// - The user is not allowed to delegate the permission
///
/// #### `404 - NOT FOUND`
/// One of the following entities was not found in the Velocity system:
/// - The permission to be revoked
/// - The user to revoke the permission of
/// - The group to revoke the permission from
pub async fn u_user_permission_delete_1(
    State(velocity): State<VelocityState>,
    Extension(user): Extension<User>,
    Json(request): Json<DELETEReq1>,
) -> Result<impl IntoResponse, VelocityAPIError> {
    let req_user = velocity
        .global_permission_guard(user, Entitlement::UserList)
        .await?;

    let db = &velocity.read().await.db;

    let permission = match Permission::try_select_name(db, &request.permission).await? {
        Some(permission) => permission,
        None => return Ok(StatusCode::NOT_FOUND),
    };

    let user = match User::try_select_uid(db, request.uid).await? {
        Some(user) => user,
        None => return Ok(StatusCode::NOT_FOUND),
    };

    let group = match Group::try_select_gid(db, request.gid).await? {
        Some(group) => group,
        None => return Ok(StatusCode::NOT_FOUND),
    };

    if !permission.can_delegate(db, &req_user, &group).await? {
        error!(
            "[DELETE/1] User {req_user} cannot revoke permission {} on {group} without delegation permission",
            permission.name
        );
        return Ok(StatusCode::FORBIDDEN);
    }

    permission.revoke(db, &user, &group).await?;

    info!(
        "[DELETE/1] {req_user} revoked permission '{}' from {user} on {group}",
        permission.name
    );

    Ok(StatusCode::OK)
}
