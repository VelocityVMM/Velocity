//
// MIT License
//
// Copyright (c) 2023 The Velocity contributors
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
import Vapor

extension VAPI {
    /// Registers all endpoints within the namespace `/v/vm`
    func register_endpoints_v_vm(route: RoutesBuilder) throws {
        route
            .grouped(self.authenticator)
            .grouped(VDB.User.guardMiddleware())
            .post("list") { req in

            let c_user = try req.auth.require(VDB.User.self)
            let request: Structs.V.VM.LIST.POST.Req = try req.content.decode(Structs.V.VM.LIST.POST.Req.self)

            guard let group = try self.db.group_select(gid: request.gid) else {
                self.VDebug("\(c_user.info()) tried to list VMs: GROUP \(request.gid) NOT FOUND")
                return try self.error(code: .V_VM_LIST_POST_GROUP_NOT_FOUND)
            }

            guard try c_user.has_permission(permission: "velocity.vm.view", group: group) else {
                self.VDebug("\(c_user.info()) tried to list VMs: FORBIDDEN")
                return try self.error(code: .V_VM_EFI_PUT_PERMISSION)
            }

            var vms: [Structs.V.VM.LIST.POST.Res.VMInfo] = []

            for vm in try self.db.vms_get(group: group) {
                vms.append(Structs.V.VM.LIST.POST.Res.VMInfo(
                    vmid: vm.vmid,
                    name: vm.name,
                    cpus: vm.cpu_count,
                    memory_mib: vm.memory_size_mib))
            }

            return try self.response(Structs.V.VM.LIST.POST.Res(vms: vms))
        }

        route
            .grouped(self.authenticator)
            .grouped(VDB.User.guardMiddleware())
            .post { req in

            let c_user = try req.auth.require(VDB.User.self)
            let request: Structs.V.VM.POST.Req = try req.content.decode(Structs.V.VM.POST.Req.self)

            guard let vm = self.vm_manager.get_vm(vmid: request.vmid) else {
                self.VDebug("\(c_user.info()) tried to retrieve VM info: VMID (\(request.vmid)) NOT FOUND")
                return try self.error(code: .V_VM_EFI_PUT_PERMISSION)
            }

            if try !c_user.add_permission(group: vm.vvm.group, permission: "velocity.vm.view") {
                self.VDebug("\(c_user.info()) tried to retrieve VM info: FORBIDDEN \(request.vmid)")
                return try self.error(code: .V_VM_EFI_PUT_PERMISSION)
            }

            let disks = try self.db.t_vmdisks.select_vm_disks(vm: vm.vvm).0
            let displays = try self.db.t_vmdisplays.select_vm_displays(vm: vm.vvm)
            let nics = try self.db.t_vmnics.select_vm_nics(vm: vm.vvm).0

            let res = Structs.V.VM.POST.Res(
                vmid: vm.vvm.vmid,
                name: vm.vvm.name,
                type: "EFI",
                state: vm.get_state(),
                cpus: vm.vvm.cpu_count,
                memory_mib: vm.vvm.memory_size_mib,
                displays: displays,
                media: disks,
                nics: nics,
                rosetta: vm.vvm.rosetta,
                autostart: vm.vvm.autostart)

            return try self.response(res)
        }

        route
            .grouped(self.authenticator)
            .grouped(VDB.User.guardMiddleware())
            .put("efi") { req in

            let c_user = try req.auth.require(VDB.User.self)
            let request: Structs.V.VM.EFI.PUT.Req = try req.content.decode(Structs.V.VM.EFI.PUT.Req.self)

            guard try c_user.has_permission(permission: "velocity.vm.create", group: nil) else {
                self.VDebug("\(c_user.info()) tried to create EFI VM: FORBIDDEN")
                return try self.error(code: .V_VM_EFI_PUT_PERMISSION)
            }

            guard let group = try self.db.group_select(gid: request.gid) else {
                self.VDebug("\(c_user.info()) tried to create EFI VM: GROUP NOT FOUND")
                return try self.error(code: .V_VM_EFI_PUT_GROUP_NOT_FOUND)
            }

            self.VDebug("\(c_user.info()) is creating VM: \(request)")

            let vminfo = VDB.VM.Info(name: request.name,
                                     group: group,
                                     cpu_count: UInt64(request.cpus),
                                     memory_size_mib: UInt64(request.memory_mib),
                                     rosetta: request.rosetta,
                                     autostart: request.autostart);

            var vmid: VMID? = nil;
            var error: Response? = nil;

            // Create a transaction
            try self.db.db.transaction {

                // Insert the base virtual machine
                let vm = try self.db.vm_insert(info: vminfo);
                vmid = vm.vmid;

                // Insert all NICs
                for nic in request.nics {
                    if let err = try self.db.vmnic_insert(vm: vm, type: nic.type, host: nic.host) {
                        switch err {
                        case .HostNICRequired:
                            self.VDebug("\(c_user.info()) tried to create EFI VM: 'BRIDGE' NIC NEEDS A HOST NIC")
                            error = try self.error(code: .V_VM_EFI_PUT_HOST_NIC_REQUIRED)
                        case .HostNICNotFound:
                            self.VDebug("\(c_user.info()) tried to create EFI VM: HOST NIC {\(String(describing: nic.host))} NOT FOUND")
                            error = try self.error(code: .V_VM_EFI_PUT_HOST_NIC_NOT_FOUND)
                        }
                        return
                    }
                }

                // Insert all disks
                for disk in request.disks {
                    switch try self.db.media_select(mid: disk.mid) {
                    case .success(let m):
                        try self.db.disk_insert(vm: vm, media: m, mode: disk.mode, readonly: disk.readonly)
                    case .failure(let e):
                        switch e {case .MediaNotFound:
                            self.VDebug("\(c_user.info()) tried to create EFI VM: MEDIA {\(disk.mid)} NOT FOUND")
                            error = try self.error(code: .V_VM_EFI_PUT_MEDIA_NOT_FOUND)
                        case .GroupNotFound:
                            self.VDebug("\(c_user.info()) tried to create EFI VM: GROUP FOR MEDIA {\(disk.mid)} NOT FOUND")
                            error = try self.error(code: .V_VM_EFI_PUT_MEDIA_GROUP_NOT_FOUND)
                        case .MediapoolNotFound:
                            self.VDebug("\(c_user.info()) tried to create EFI VM: MEDIAPOOL FOR MEDIA {\(disk.mid)} NOT FOUND")
                            error = try self.error(code: .V_VM_EFI_PUT_MEDIA_MEDIAPOOL_NOT_FOUND)
                        }
                        return;
                    }
                }

                // Insert all displays
                for display in request.displays {
                    if try self.db.display_insert(
                        vm: vm,
                        name: display.name,
                        width: display.width,
                        height: display.height,
                        ppi: display.ppi) == false {

                        // Report the error
                        self.VDebug("\(c_user.info()) tried to create EFI VM: DISPLAY \(display.name) DOES ALREADY EXIST")
                        error = try self.error(code: .V_VM_EFI_PUT_DISPLAY_CONFLICT)
                        return
                    }
                }
            }

            // If there is an error, return that, else assume a valid vmid and respond with success
            if let error = error {
                return error
            } else {
                guard let vmid = vmid else {
                    self.VErr("FATAL: Expected either error or valid vmid after VM insertion")
                    return try self.response(nil, status: .internalServerError)
                }

                self.VDebug("\(c_user.info()) created a new virtual machine: {\(vmid)}")
                return try self.response(Structs.V.VM.EFI.PUT.Res(vmid: vmid))
            }

        }

        route
            .grouped(self.authenticator)
            .grouped(VDB.User.guardMiddleware())
            .post("state") { req in

            let c_user = try req.auth.require(VDB.User.self)
            let request: Structs.V.VM.STATE.POST.Req = try req.content.decode(Structs.V.VM.STATE.POST.Req.self)

            guard try c_user.has_permission(permission: "velocity.vm.view", group: nil) else {
                self.VDebug("\(c_user.info()) tried to retrieve VM state: FORBIDDEN")
                return try self.error(code: .V_VM_STATE_POST_PERMISSION)
            }

            guard let vm = self.vm_manager.get_vm(vmid: request.vmid) else {
                self.VDebug("\(c_user.info()) tried to retrieve VM state: VM NOT FOUND")
                return try self.error(code: .V_VM_STATE_POST_VM_NOT_FOUND)
            }

            return try self.response(Structs.V.VM.STATE.Res(vmid: vm.vvm.vmid, state: vm.get_state().rawValue))
        }

        route
            .grouped(self.authenticator)
            .grouped(VDB.User.guardMiddleware())
            .put("state") { req in

            let c_user = try req.auth.require(VDB.User.self)
            let request: Structs.V.VM.STATE.PUT.Req = try req.content.decode(Structs.V.VM.STATE.PUT.Req.self)

            guard try c_user.has_permission(permission: "velocity.vm.state", group: nil) else {
                self.VDebug("\(c_user.info()) tried to change VM state: FORBIDDEN")
                return try self.error(code: .V_VM_STATE_PUT_PERMISSION)
            }

            guard let vm = self.vm_manager.get_vm(vmid: request.vmid) else {
                self.VDebug("\(c_user.info()) tried to retrieve VM state: VM NOT FOUND")
                return try self.error(code: .V_VM_STATE_POST_VM_NOT_FOUND)
            }

            let res = try vm.request_state_transition(state: request.state, force: request.force)

            if res {
                return try self.response(Structs.V.VM.STATE.Res(vmid: vm.vvm.vmid, state: vm.get_state().rawValue))
            } else {
                return try self.error(code: .V_VM_STATE_PUT_NOT_ALLOWED)
            }
        }
    }
}

extension VAPI.Structs.V {
    /// `/v/vm`
    struct VM {
        /// `/v/vm` - POST
        struct POST {
            struct Req : Decodable {
                let authkey: String
                let vmid: VMID
            }
            struct Res : Encodable {
                let vmid: VMID
                let name: String
                let type: String
                let state: VirtualMachine.State

                let cpus: UInt64
                let memory_mib: UInt64

                let displays: [VZ.DisplayConfiguration]
                let media: [VZ.DiskConfiguration]
                let nics: [VZ.NICConfiguration]

                let rosetta: Bool
                let autostart: Bool
            }
        }

        /// `/v/vm/list`
        struct LIST {
            /// `/v/vm/list` - POST
            struct POST {
                struct Req : Decodable {
                    let authkey: String
                    let gid: GID
                }
                struct Res : Encodable {
                    let vms: [VMInfo]

                    struct VMInfo: Encodable {
                        let vmid: VMID
                        let name: String
                        let cpus: UInt64
                        let memory_mib: UInt64

                        init(vmid: VMID, name: String, cpus: UInt64, memory_mib: UInt64) {
                            self.vmid = vmid
                            self.name = name
                            self.cpus = cpus
                            self.memory_mib = memory_mib
                        }
                    }
                }
            }
        }

        /// `/v/vm/efi`
        struct EFI {
            /// `/v/vm/efi` - PUT
            struct PUT {
                struct Req : Decodable {
                    let authkey: String
                    let name: String
                    let gid: GID

                    let cpus: Int64
                    let memory_mib: Int64

                    let displays: [Display]
                    let disks: [Disk]
                    let nics: [NIC]

                    let rosetta: Bool
                    let autostart: Bool
                }

                struct Res: Encodable {
                    let vmid: VMID
                }
            }
        }
        /// `/v/vm/state`
        struct STATE {
            /// `/v/vm/state` - POST
            struct POST {
                struct Req : Decodable {
                    let authkey: String
                    let vmid: VMID
                }
            }
            /// `/v/vm/state` - PUT
            struct PUT : Decodable{
                struct Req : Decodable {
                    let authkey: String
                    let vmid: VMID
                    let state: VirtualMachine.StateRequest
                    let force: Bool
                }
            }

            /// `/v/vm/state` - Common response structure
            struct Res : Encodable {
                let vmid: VMID
                let state: String
            }
        }

        struct Display : Decodable, Encodable {
            let name: String
            let width: Int64
            let height: Int64
            let ppi: Int64
        }
        struct Disk : Decodable, Encodable {
            let mid: MID
            let mode: VDB.TVMDisks.DiskMode
            let readonly: Bool
        }
        struct NIC : Decodable, Encodable {
            let type: VDB.TVMNICs.NICType
            let host: NICID?
        }
    }
}
