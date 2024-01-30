# Velocity

Velocity is a Proxmox-VE like virtualization platform that leverages the power of Apple's Virtualization Framework for its VMs. The goal is to provide an easy way of creating, managing and using Virtual machines on a (headless) Mac.

Velocity exposes an API that allows interfacing with the Velocity daemon. This allows Velocity to run completely headless and use only a  [web interface](https://github.com/VelocityVMM/webinterface) for interaction and management. Users can also automate the process of creating and managing VMs through this API.

## API

Velocity can be controlled using an API exposed from the hypervisor. You can read more in the [APISPEC](docs/APISPEC/README.md).

## Building

Velocity is by no means in a stable state and experiences heavy development and frequent breaking changes. If you are interested in trying out Velocity, you can clone the repo, open the XCode project, adjust the signing process for your needs and build it.

## Contributing

We certainly welcome contributions from the community, be it code, documentation or anything else! To contribute, just fork this repo, create your commits, document them and submit a pull request to the main repository explaining clearly what you did and why. If we agree with your changes, we will happily merge them.
