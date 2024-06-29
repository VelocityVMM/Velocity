use axum::{
    body::Body,
    extract::{Request, State},
    http::{Response, StatusCode},
    middleware::Next,
};
use log::error;

use crate::api::VelocityState;

/// The Velocity authentication middleware handler
pub async fn auth_middleware(
    State(state): State<VelocityState>,
    mut req: Request,
    next: Next,
) -> Response<Body> {
    // Get the "AUTH" header value
    let auth_header = req
        .headers()
        .get(axum::http::header::AUTHORIZATION)
        .and_then(|header| header.to_str().ok());

    // Construct a result with the UNAUTHORIZED status code
    // for later returns
    let unauthorized_res: Response<Body> = Response::builder()
        .status(StatusCode::UNAUTHORIZED)
        .body(Body::empty())
        .expect("Construct response");

    // Get the auth header
    let auth_header = if let Some(auth_header) = auth_header {
        auth_header
    } else {
        return unauthorized_res;
    };

    // Strip the "Bearer " id string
    let key = auth_header.replace("Bearer ", "");

    // Look for the user
    let user = match state.velocity.read().await.get_authkey_owner(&key).await {
        Ok(user) => user,
        Err(e) => {
            error!("Failed to authenticate: {e}");
            return unauthorized_res;
        }
    };

    // Continue or abort if the key is not registered
    if let Some(user) = user {
        req.extensions_mut().insert(user);
        next.run(req).await
    } else {
        unauthorized_res
    }
}
