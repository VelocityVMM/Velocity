use error::VResult;
use log::info;

pub mod error;
pub mod model;

#[swift_bridge::bridge]
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
        match tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("Create async runtime")
            .block_on(self.run_async())
        {
            Err(e) => println!("{:?}", e),
            Ok(()) => {}
        };
    }

    /// The async main function that runs the hypervisor
    async fn run_async(&self) -> VResult<()> {
        info!("Starting Velocity");

        Ok(())
    }
}
