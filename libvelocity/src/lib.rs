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
use std::sync::Arc;

use error::VResult;
use log::info;

use axum::{
    extract::Request,
    http::StatusCode,
    middleware::{self, Next},
    response::Response,
};
use log::trace;
use model::{AuthManager, Permission};
use sqlx::SqlitePool;
use tokio::sync::RwLock;

use crate::{error::VErrorExt, model::User};

pub mod api;
pub mod error;
pub mod model;

pub type VelocityState = Arc<RwLock<Velocity>>;

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

        let db = SqlitePool::connect("sqlite:///Users/max/Velocity/db.sqlite?mode=rwc")
            .await
            .ctx(|| "Connecting to database")?;

        sqlx::migrate!().run(&db).await.expect("Run migrations");

        let u_root = User::try_select_uid(&db, 0)
            .await
            .ctx(|| "Failed to retrieve root user")?;

        match u_root {
            None => User::create_with_uid(&db, 0, "root", "root")
                .await
                .ctx(|| "Failed to create root user")?,
            Some(u) => u,
        };

        Permission::ensure_default_permissions(&db)
            .await
            .ctx(str!("Ensuring default permissions"))?;

        // Create the initial app route
        let app = api::get_router(Arc::new(RwLock::new(Velocity {
            db,
            auth_manager: AuthManager::default(),
        })));

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

async fn printer(request: Request, next: Next) -> Response {
    trace!("[{}] {}", request.method(), request.uri());

    next.run(request).await
}
