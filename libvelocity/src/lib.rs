//! # Velocity
//!
//! The Velocity hypervisor is a Proxmox-VE like hypervisor and
//! virtual machine manager for macOS. It leverages the power
//! of the Virtualization framework for fast and efficient virtual
//! machines.
//!
//! Velocity is a mixture of `Rust` and `Swift` and this is the `Rust`
//! part. There is an effort of stuffing as much code as possible into
//! the `Rust` portion, as the language provides excellent safety and
//! speed. There should be as little `Swift` code as possible.
//!
//! # API
//! Velocity can be controlled entirely through a REST API.
//!
//! [The documentation for the API can be found here](api).
//!

use std::path::PathBuf;

use api::VelocityState;
use error::VResult;
use home::home_dir;
use log::info;

use axum::{
    body::Body,
    extract::Request,
    http::{Response, StatusCode},
    middleware::{self, Next},
};
use log::trace;
use model::{AuthManager, Group, Permission};
use sqlx::SqlitePool;
use tower_http::cors::CorsLayer;

use crate::{error::VErrorExt, model::User};

pub mod api;
pub mod error;
pub mod model;

pub mod authentication;

#[swift_bridge::bridge]
#[allow(clippy::unnecessary_cast)]
mod ffi {
    extern "Rust" {
        type LibVelocity;

        #[swift_bridge(init)]
        fn new(loglevel: u32) -> LibVelocity;

        fn run(&self);
    }
}

/// The main handle for the Velocity hypervisor
pub struct LibVelocity {}

impl LibVelocity {
    /// Create a new instance of the hypervisor
    pub fn new(loglevel: u32) -> Self {
        if std::env::var("RUST_LOG").is_err() {
            match loglevel {
                0 => std::env::set_var("RUST_LOG", "info"),
                1 => std::env::set_var("RUST_LOG", "debug"),
                _ => std::env::set_var("RUST_LOG", "trace"),
            }
        }
        pretty_env_logger::init();

        Self {}
    }

    /// Start up and run the hypervisor
    pub fn run(&self) {
        if let Err(e) = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("Create async runtime")
            .block_on(self.run_async())
        {
            println!("{e}");
        }
    }

    /// The async main function that runs the hypervisor
    async fn run_async(&self) -> VResult<()> {
        info!("Starting Velocity...");

        let home_dir = home_dir().unwrap_or(PathBuf::from("./"));

        let url = format!(
            "sqlite://{}/Velocity/db.sqlite?mode=rwc",
            home_dir.to_string_lossy()
        );

        let db = SqlitePool::connect(&url)
            .await
            .ctx(|| "Connecting to database")?;

        sqlx::migrate!().run(&db).await.expect("Run migrations");

        let u_root = User::try_select_uid(&db, 0)
            .await
            .ctx(|| "Failed to retrieve root user")?;

        let u_root = match u_root {
            None => User::create_with_uid(&db, 0, "root", "root")
                .await
                .ctx(|| "Failed to create root user")?,
            Some(u) => u,
        };

        let g_root = Group::try_select_gid(&db, 0)
            .await
            .ctx(|| "Failed to retrieve root group")?;

        let g_root = match g_root {
            None => Group::create_with_gid(&db, 0, "root", None)
                .await
                .ctx(|| "Failed to create root group")?,
            Some(g) => g,
        };

        Permission::ensure_default_permissions(&db, &u_root, &g_root)
            .await
            .ctx(str!("Ensuring default permissions"))?;

        // Create the initial app route
        let app = api::get_router(VelocityState::new(Velocity {
            db,
            auth_manager: AuthManager::default(),
        }))
        .layer(CorsLayer::permissive());

        let app = app.fallback(fallback).layer(middleware::from_fn(printer));

        let listener = tokio::net::TcpListener::bind("0.0.0.0:8090")
            .await
            .ctx(|| "Binding TCP socket")?;

        info!("Velocity has started and can accept connections");

        axum::serve(listener, app)
            .await
            .ctx(|| "Serving Velocity API")?;

        Ok(())
    }
}

async fn fallback() -> (StatusCode, &'static str) {
    (StatusCode::NOT_FOUND, "Not Found")
}

pub struct Velocity {
    db: SqlitePool,
    auth_manager: AuthManager,
}

async fn printer(request: Request, next: Next) -> Response<Body> {
    trace!("[{}] {}", request.method(), request.uri());

    next.run(request).await
}

impl Velocity {
    /// Tries to get the owner of the supplied authkey
    /// # Arguments
    /// * `key` - The key string to check for
    /// # Returns
    /// The user that is authenticated by `key` or `None`
    pub async fn get_authkey_owner(&self, key: &str) -> VResult<Option<User>> {
        self.auth_manager.get_user(key, &self.db).await
    }
}
