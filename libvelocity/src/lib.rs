#[swift_bridge::bridge]
mod ffi {
    extern "Rust" {
        type LibVelocity;

        #[swift_bridge(init)]
        fn new() -> LibVelocity;

        fn run(&self);
    }
}

/// The main handle for the Velocity hypervisor
pub struct LibVelocity {}

impl LibVelocity {
    /// Create a new instance of the hypervisor
    pub fn new() -> Self {
        Self {}
    }

    /// Start up and run the hypervisor
    pub fn run(&self) {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("Create async runtime")
            .block_on(self.run_async())
    }

    /// The async main function that runs the hypervisor
    async fn run_async(&self) {
        println!("Velocity");
    }
}
