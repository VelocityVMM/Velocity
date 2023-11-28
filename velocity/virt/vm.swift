//
// MIT License
//
// Copyright (c) 2023 zimsneexh
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Foundation
import Virtualization

/// A virtual machine `Velocity` can work with. It wraps `VZVirtualMachine`
/// and wraps it in convenient functions with better error handling
class VirtualMachine : VZVirtualMachine, Loggable {
    let context: String

    /// The `DispatchQueue` to use for all interactions with this VirtualMachine
    /// including the VirtualMachine itself
    let queue: DispatchQueue
    /// The VM struct this VirtualMachine represents and implements. This is the
    /// blueprint for the real virtual machine
    let vvm: VDB.VM

    /// The constructor is private, allow only guarded creation
    private init(config: VirtualMachineConfiguration, vvm: VDB.VM) {
        self.vvm = vvm
        self.queue = DispatchQueue(label: "vm_\(vvm.vmid)")
        self.context = "[VM (\(vvm.name))]"

        super.init(configuration: config, queue: queue)
    }

    /// Returns the current state of the virtual machine
    func get_state() -> State {
        return State.from_vz_state(state: self.state)
    }

    /// Requests a state transition for the virtual machine
    /// - Parameter state: The state to transition to
    /// - Parameter force: If the transition should be enforced (kill vs shutdown)
    /// - Returns: If the transition request succeeded or the VM is already in the requested state
    /// (`false` if the transition is not allowed)
    func request_state_transition(state: StateRequest, force: Bool = false) throws -> Bool {
        VInfo("Requested state transition from \(self.get_state()) to \(state)")

        switch state {

        // Transition to a STOPPED virtual machine
        case .STOPPED:
            return try self.transition_STOPPED(force: force)

        // Transition to a running virtual machine
        case .RUNNING:
            return self.transition_RUNNING()

        // Transition to a paused virtual machine
        case .PAUSED:
            return self.transition_PAUSED()
        }
    }

    /// Transition to the `RUNNING` state
    /// - Returns: `true` if already in the requested state or the transition succeeded, `false` if the transition is not allowed
    func transition_RUNNING() -> Bool {
        let state = self.get_state()

        // If we are already running, we're done here
        if state == .RUNNING {
            return true
        }

        // We can only transition to RUNNING from a STOPPED or PAUSED machine
        if state == .STOPPED {
            self.queue.sync {
                // TODO: Handle the error here
                self.start() {e in
                    switch e {
                    case .success():
                        self.VInfo("Transitioned to \(self.get_state())")
                    case .failure(let e):
                        self.VErr("Failed to transition to \(state): \(e)")
                    }
                }
            }
        } else if state == .PAUSED {
            self.queue.sync {
                // TODO: Handle the error here
                self.resume() {e in
                    switch e {
                    case .success():
                        self.VInfo("Transitioned to \(self.get_state())")
                    case .failure(let e):
                        self.VErr("Failed to transition to \(state): \(e)")
                    }
                }
            }
        } else {
            return false
        }

        return true
    }

    /// Transition to the `PAUSED` state
    /// - Returns: `true` if already in the requested state or the transition succeeded, `false` if the transition is not allowed
    func transition_PAUSED() -> Bool {
        let state = self.get_state()

        // If we are already paused, we're done here
        if state == .PAUSED {
            return true
        }

        // We can only transition to PAUSED from a RUNNING machine
        if state != .RUNNING {
            return false
        }

        self.queue.sync {
            // TODO: Handle the error here
            self.pause() {e in
                switch e {
                case .success():
                    self.VInfo("Transitioned to \(self.get_state())")
                case .failure(let e):
                    self.VErr("Failed to transition to \(state): \(e)")
                }
            }
        }

        return true
    }

    /// Transition to the `STOPPED` state
    /// - Returns: `true` if already in the requested state or the transition succeeded, `false` if the transition is not allowed
    func transition_STOPPED(force: Bool) throws -> Bool {
        let state = self.get_state()

        // If we are already stopped, we're done here
        if state == .STOPPED {
            return true
        }

        // We can only transition to STOPPED from a RUNNING or PAUSED machine
        if state != .RUNNING && state != .PAUSED  {
            return false
        }

        if force {
            // A forced shutdown (kills the virtual machine)
            // TODO: Handle the error here
            self.queue.async {
                self.stop() {e in

                }
            }
        } else {
            // A graceful shutdown (requests the guest to stop)
            try self.queue.sync {
                try self.requestStop()
            }
        }

        return true
    }

    /// Creates a new VirtualMachine from the `VDB.VM` and the manager
    /// - Parameter vm: The `VDB.VM` struct to use for VM configuration
    /// - Parameter manager: The `Manager` struct to use for obtaining the EFIStore etc.
    static func new(vm: VDB.VM, manager: VMManager) throws -> Result<VirtualMachine, CreationError> {
        switch try VirtualMachineConfiguration.new(vm: vm, manager: manager) {
        case .failure(let e): return .failure(.Config(e))
        case .success(let config):


            let vm = VirtualMachine(config: config, vvm: vm)
            return .success(vm)

        }
    }

    /// An error that can occur on virtual machine creation
    enum CreationError : Error, CustomStringConvertible {

        /// A configuration error occured
        case Config(VirtualMachineConfiguration.ConfigurationError)

        var description: String {
            var res = "Virtual machine creation failed: "

            switch self {
            case .Config(let e): res.append(e.description)
            }

            return res
        }
    }

    /// Possible states of a virtual machine
    enum State : String, Encodable {
        case STOPPED = "STOPPED"
        case STARTING = "STARTING"
        case RUNNING = "RUNNING"
        case PAUSING = "PAUSING"
        case PAUSED = "PAUSED"
        case RESUMING = "RESUMING"
        case STOPPING = "STOPPING"
        case SAVING = "SAVING"
        case RESTORING = "RESTORING"

        case ERROR = "ERROR"

        case UNKNOWN = "UNKNOWN"

        /// Encodes the state into a string for transmission
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }

        /// Parses the state of a `VZVirtualMachine` into this enum
        static func from_vz_state(state: VZVirtualMachine.State) -> Self {
            switch state {
            case .stopped:
                return .STOPPED
            case .running:
                return .RUNNING
            case .paused:
                return .PAUSED
            case .error:
                return .ERROR
            case .starting:
                return .STARTING
            case .pausing:
                return .PAUSING
            case .resuming:
                return .RESUMING
            case .stopping:
                return .STOPPING
            case .saving:
                return .SAVING
            case .restoring:
                return .RESTORING
            default:
                return .UNKNOWN
            }
        }
    }

    /// The possible states that can be requested
    enum StateRequest : String, Decodable {
        case STOPPED = "STOPPED"
        case RUNNING = "RUNNING"
        case PAUSED = "PAUSED"
    }
}
