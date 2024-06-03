//! # User management
//! The `/u` group of endpoints houses functions for working
//! with users, groups and authentication.
//!
//! ## Routes
//! - [`/u/auth`: Manage user authentication](auth)

use axum::Router;

use crate::VelocityState;

pub mod auth;

#[doc(hidden)]
pub fn get_router(velocity: VelocityState) -> Router {
    Router::new().nest("/auth", auth::get_router(velocity))
}
