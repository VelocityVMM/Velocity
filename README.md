# Velocity

This is the repository for the Velocity hypervisor running on MacOS.

Velocity is a Proxmox-VE like virtualization platform that leverages the power of Apple's Virtualization Framework for its VMs. The goal is to provide an easy way of creating, managing and using Virtual machines on a (headless) Mac.

## Building

Velocity is by no means in a stable state and experiences heavy development and frequent breaking changes. If you are interested in trying out Velocity, you can clone the repo, open the XCode project, adjust the signing process for your needs and build it.

## Contributing

We certainly welcome contributions from the community, be it code, documentation or anything else! To contribute, just fork this repo, create your commits, document them and submit a pull request to the main repository explaining clearly what you did and why. If we agree with your changes, we will happily merge them.

## Source code layout

Velocity is written in a combination of `Swift` and `Rust` but can be completely built in XCode. This combines the power of the Rust programming language with the tight integration into the Apple ecosystem of Swift.

The stack of this project can be imagined like a sandwich with very thin Swift layers at the top and bottom of the other Rust code. The bottom layer provides abstractions for interacting with MacOS frameworks while the upper layer acts as a launchpad for the cure Rust implementation.

The repository is split into two parts:

- `Velocity`: The Swift source code
- `libvelocity`: The Rust source code
