//! # User management
//! The `/u` group of endpoints houses functions for working
//! with users, groups and authentication.
//!
//! ## Routes
//! - [`/u/auth`: Manage user authentication](auth)
//! - [`/u/user`: Manage users](user)

use axum::Router;

use crate::VelocityState;

pub mod auth;
pub mod user;

#[doc(hidden)]
pub fn get_router(velocity: VelocityState) -> Router {
    Router::new()
        .nest("/auth", auth::get_router(velocity.clone()))
        .nest("/user", user::get_router(velocity.clone()))
}
