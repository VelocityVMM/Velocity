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
        println!("Velocity")
    }
}
