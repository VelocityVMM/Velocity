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
import Vapor

extension VAPI {
    /// Registers all endpoints within the namespace `/v/vm`
    func register_endpoints_v_vm(route: RoutesBuilder) throws {
        route.put("efi") { req in
            let request: Structs.V.VM.EFI.PUT.Req = try req.content.decode(Structs.V.VM.EFI.PUT.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return try self.error(code: .UNAUTHORIZED)
            }

            let c_user = key.user

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
    }
}

extension VAPI.Structs.V {
    /// `/v/vm`
    struct VM {
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
                struct Display : Decodable {
                    let name: String
                    let width: Int64
                    let height: Int64
                    let ppi: Int64
                }
                struct Disk : Decodable {
                    let mid: MID
                    let mode: VDB.TVMDisks.DiskMode
                    let readonly: Bool
                }
                struct NIC : Decodable {
                    let type: VDB.TVMNICs.NICType
                    let host: NICID?
                }

                struct Res: Encodable {
                    let vmid: VMID
                }
            }
        }
    }
}
