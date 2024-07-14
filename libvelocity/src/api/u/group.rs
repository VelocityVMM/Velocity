//! # `/u/group` - Endpoints for managing groups
//! ### PUT
//! - [`/u/group/1 - PUT`](u_group_put_1): Create a new group
//! ### DELETE
//! - [`/u/group/1 - DELETE`](u_group_delete_1): Remove a group

use axum::{
    extract::State,
    http::StatusCode,
    middleware::from_fn_with_state,
    response::IntoResponse,
    routing::{delete, put},
    Extension, Json, Router,
};
use log::info;
use serde::{Deserialize, Serialize};

use crate::{
    api::{ToJSONPanic, VelocityAPIError},
    authentication::auth_middleware,
    model::{Entitlement, Group, GroupError, User},
    VelocityState,
};

#[doc(hidden)]
pub fn get_router(velocity: VelocityState) -> Router {
    Router::new()
        .route("/1", put(u_group_put_1))
        .route("/1", delete(u_group_delete_1))
        .with_state(velocity.clone())
        .layer(from_fn_with_state(velocity.clone(), auth_middleware))
}

/// The request structure for the `/u/group/1 - PUT` endpoint
#[derive(Deserialize)]
pub struct PUTReq1 {
    /// The name of the new group
    pub groupname: String,
    /// The group id of the parent group
    pub parent_gid: u32,
}

/// The response structure for the `/u/group/1 - PUT` endpoint
#[derive(Serialize)]
pub struct PUTRes1 {
    /// The group id of the newly created group
    pub gid: u32,
    /// The groupname for the new group
    pub groupname: String,
    /// The group id of the parent group
    pub parent_gid: u32,
}

impl ToJSONPanic for PUTRes1 {}

/// # `/u/group/1 - PUT` - Create a new group
/// Takes the request parameters and creates a new group.
///
/// # Permissions
/// The calling user needs the `velocity.group.create`
/// permission on the parent group
///
/// # Request
/// A `json` request in the form of [PUTReq1].
///
/// # Response
/// #### `200 - OK` [PUTRes1]
/// A new group was created using the supplied options
///
/// #### `403 - FORBIDDEN`
/// The calling user is not allowed to create new groups
/// within the parent group
///
/// #### `409 - CONFLICT`
/// A group with the supplied `groupname` does already exist
/// in the parent group
pub async fn u_group_put_1(
    State(velocity): State<VelocityState>,
    Extension(user): Extension<User>,
    Json(request): Json<PUTReq1>,
) -> Result<impl IntoResponse, VelocityAPIError> {
    let req_user = velocity
        .global_permission_guard(user, Entitlement::GroupCreate)
        .await?;

    if let Some(group) =
        Group::try_select_groupname(&velocity.read().await.db, &request.groupname).await?
    {
        return Err(GroupError::GroupDuplicate(group.groupname).into());
    }

    let parent_group = Group::select_gid(&velocity.read().await.db, request.parent_gid).await?;

    let new_group = Group::create(
        &velocity.read().await.db,
        &request.groupname,
        Some(&parent_group),
    )
    .await?;

    info!("[PUT/1] {req_user} created new group {new_group}");

    let res = PUTRes1 {
        gid: new_group.gid(),
        parent_gid: new_group.parent_gid().unwrap_or(0),
        groupname: new_group.groupname,
    };

    Ok((StatusCode::OK, res.to_json_p()))
}

/// The request structure for the `/u/group/1 - DELETE` endpoint
#[derive(Deserialize)]
pub struct DELETEReq1 {
    /// The group id of the group to remove
    pub gid: u32,
}

/// # `/u/group/1 - DELETE` - Remove a group
/// Takes the request parameters and removes a group.
///
/// # Permissions
/// The calling user needs the `velocity.group.remove`
/// permission on the parent group
///
/// # Request
/// A `json` request in the form of [DELETEReq1].
///
/// # Response
/// #### `200 - OK`
/// The group was deleted
///
/// #### `403 - FORBIDDEN`
/// The calling user is not allowed to remove groups from the parent group
///
/// #### `404 - NOT FOUND`
/// The group id to remove has not been found
pub async fn u_group_delete_1(
    State(velocity): State<VelocityState>,
    Extension(user): Extension<User>,
    Json(request): Json<DELETEReq1>,
) -> Result<impl IntoResponse, VelocityAPIError> {
    let req_user = velocity
        .global_permission_guard(user, Entitlement::GroupRemove)
        .await?;

    let group = Group::select_gid(&velocity.read().await.db, request.gid).await?;

    let gid = group.gid();
    let groupname = group.groupname.clone();

    group.remove(&velocity.read().await.db).await?;

    info!("[DELETE/1] {req_user} removed group {groupname} ({gid})");

    Ok(StatusCode::OK)
}
