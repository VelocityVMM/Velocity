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
class VirtualMachine : VZVirtualMachine {

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

        super.init(configuration: config, queue: queue)
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
}
