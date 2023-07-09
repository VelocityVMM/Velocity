//
//  vVirtualMachine.swift
//  velocity
//
//  Created by zimsneexh on 10.06.23.
//

import Foundation
import Virtualization

/// Velocity VirtualMachine
class vVirtualMachine: VZVirtualMachine, VZVirtualMachineDelegate {
    var name: String;
    var cpu_count: UInt;
    var memory_size: UInt;
    var screen_size: NSSize;
    var autostart: Bool;
    var disks: [vDisk];
    var vstate: vVMState;
    var config: VZVirtualMachineConfiguration;

    let window: VWindow?;
    var specific: (vMacOptions?, vEFIOptions?);

    init(name: String, cpu_count: UInt, memory_size: UInt, screen_size: NSSize, autostart: Bool, disks: [vDisk], specific: (vMacOptions?, vEFIOptions?)) throws {

        for vm in Manager.virtual_machines {
            if vm.name == name {
                throw VelocityVZError("Could not add VirtualMachine, because the requested name is in use.")
            }
        }

        self.name = name
        self.cpu_count = cpu_count
        self.memory_size = memory_size
        self.screen_size = screen_size
        self.autostart = autostart
        self.disks = disks

        // VM is stopped on Init
        self.vstate = vVMState.STOPPED
        self.specific = specific

        // Setup the View and Spawn the required Window
        let vm_view = VZVirtualMachineView();
        vm_view.setFrameSize(self.screen_size);
        self.window = VWindow(vm_view: vm_view, vm_name: self.name);

        // Create a new Config
        self.config = VZVirtualMachineConfiguration();
        let storage_config = NSMutableArray();

        // Init config
        self.config.cpuCount = Int(self.cpu_count)
        self.config.memorySize = UInt64(self.memory_size * 1024 * 1024)

        // Check if the Filesystem already contains this VM
        // and all required files
        VTrace("Checking for Bundle and creating if needed..")
        let bundle_path = VelocityConfig.velocity_bundle_dir.appendingPathComponent("/\(self.name).bundle/")
        if !FileManager.default.fileExists(atPath: bundle_path.absoluteString) {
            if(!create_directory_safely(path: bundle_path.absoluteString)) {
                throw VelocityVZError("Could not create VM bundle directory.")
            }
        }

        // Check if disks are available.
        VInfo("Checking Disk Image(s)..")
        for disk in self.disks {
            let disk_path = bundle_path.appendingPathComponent("\(disk.name)").appendingPathExtension("img")

            if !FileManager.default.fileExists(atPath: disk_path.absoluteString) {
                VInfo("Creating new Disk image for \(disk.name).img")

                do {
                    try create_disk_image(pathTo: bundle_path.absoluteString, disk: disk)
                } catch {
                    throw VelocityVZError("Error: \(error.localizedDescription)")
                }
            }

            // Add Disk to config
            VLog("Attaching disk to VM..")
            guard let disk_attachment = try? VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: disk_path.absoluteString), readOnly: false) else {
                VErr("Failed to create disk attachment.")
                throw VelocityVZError("Could not create disk attachment.");
            }

            storage_config.add(VZVirtioBlockDeviceConfiguration(attachment: disk_attachment))
        }

        // Mac specific devices
        if let _ = specific.0 {
            self.config.platform = VZMacPlatformConfiguration();

            let graphics_device = VZMacGraphicsDeviceConfiguration();
            graphics_device.displays = [
                VZMacGraphicsDisplayConfiguration(widthInPixels: Int(self.screen_size.width), heightInPixels: Int(self.screen_size.height), pixelsPerInch: 64)
            ]

            self.config.graphicsDevices = [ graphics_device ]
            self.config.bootLoader = VZMacOSBootLoader()
            self.config.pointingDevices = [ VZMacTrackpadConfiguration() ]
            self.config.keyboards = [ VZUSBKeyboardConfiguration() ]

            VDebug("Adding Virtio Networking (Type NAT)")
            let network_device = VZVirtioNetworkDeviceConfiguration()
            network_device.attachment = VZNATNetworkDeviceAttachment()
            self.config.networkDevices = [ network_device ]
        }

        // EFI specific devices
        if let _ = specific.1 {
            self.config.keyboards = [VZUSBKeyboardConfiguration()]
            self.config.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]

            let platform = VZGenericPlatformConfiguration()
            let bootloader = VZEFIBootLoader()

            // Check for EFI Store and import it
            VDebug("Checking for NVRAM..")
            let efi_stor_path = bundle_path.appendingPathComponent("NVRAM")
            if !FileManager.default.fileExists(atPath: bundle_path.appendingPathComponent("NVRAM").absoluteString) {
                VDebug("No NVRAM. Creating..")
                guard let _ = try? VZEFIVariableStore(creatingVariableStoreAt: efi_stor_path) else {
                    throw VelocityVZError("Could not create EFI Variable storage in bundle.")
                }
            }
            bootloader.variableStore = VZEFIVariableStore(url: efi_stor_path)
            VDebug("NVRAM set.")

            let machine_identifier_path = bundle_path.appendingPathComponent("MachineIdentifier").absoluteString
            if !FileManager.default.fileExists(atPath: machine_identifier_path) {
                VLog("Creating MachineIdentifier..")
                if(!new_generic_machine_identifier(pathTo: machine_identifier_path)) {
                    throw VelocityVZError("Could not create machine identifier.");
                }
            }

            VDebug("Loading Machine identifier..")
            guard let machine_identifier_data = try? Data(contentsOf: URL(fileURLWithPath: bundle_path.appendingPathComponent("MachineIdentifier").absoluteString)) else {
                throw VelocityVZError("Failed to retrieve machine identifier data.")
            }

            VDebug("Setting MachineIdentifier..")
            guard let machine_identifier = VZGenericMachineIdentifier(dataRepresentation: machine_identifier_data) else {
                throw VelocityVZError("Could not load Machine Identifier data.")
            }
            platform.machineIdentifier = machine_identifier
            VDebug("EFI Setup completed.")

            VDebug("Adding platform devices..")
            self.config.platform = platform
            self.config.bootLoader = bootloader
            self.config.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]
            self.config.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]

            VDebug("Adding Virtio Graphics..")
            let graphics_device = VZVirtioGraphicsDeviceConfiguration()
            graphics_device.scanouts = [
                VZVirtioGraphicsScanoutConfiguration(widthInPixels: Int(self.screen_size.width), heightInPixels: Int(self.screen_size.height))
            ]
            self.config.graphicsDevices = [ graphics_device ]

            //MARK: Add NAT networking for now, VelocityConfig should
            //MARK: contain the host adapter we want to use for bridged networking
            VDebug("Adding Virtio Networking (Type NAT)")
            let network_device = VZVirtioNetworkDeviceConfiguration()
            network_device.attachment = VZNATNetworkDeviceAttachment()
            self.config.networkDevices = [ network_device ]


            if(self.specific.1?.iso_path != nil) {
                VDebug("Attaching ISO image at path \(self.specific.1!.iso_path)..")
                guard let installer_disk_attachment = try? VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: self.specific.1!.iso_path), readOnly: true) else {
                    throw VelocityVZError("Could not attach ISO image to VM")
                }
                storage_config.add(VZUSBMassStorageDeviceConfiguration(attachment: installer_disk_attachment))
            }
        }

        // Disks to VZStorageDeviceConfiguration
        guard let disks = storage_config as? [VZStorageDeviceConfiguration] else {
            throw VelocityVZError("Invalid disksArray.")
        }

        self.config.storageDevices = disks

        // Mount IPSW if the machine is a Mac, needs to happen after super.init() because closure.
        if let mac_specific = self.specific.0 {
            self.config.platform = VZMacPlatformConfiguration()

            VInfo("Setting platform..")

            guard let hw_model = Manager.ipsw_hardwaremodel[mac_specific.ipsw_path] else {
                throw VelocityVZError("Could not determine Hardwaremodel for requested IPSW. The ipsw is likely corrupted.")
            }
            (self.config.platform as! VZMacPlatformConfiguration).hardwareModel = hw_model

            VInfo("Attaching Auxiliary storage.")


            let auxiliary_storage_url = URL(fileURLWithPath: bundle_path.appendingPathComponent("AuxiliaryStorage").absoluteString)

            // load AuxiliaryStorage
            if FileManager.default.fileExists(atPath: bundle_path.appendingPathComponent("AuxiliaryStorage").absoluteString) {
                (self.config.platform as! VZMacPlatformConfiguration).auxiliaryStorage = VZMacAuxiliaryStorage(url: auxiliary_storage_url)

            // Create new AuxiliaryStorage
            } else {
                do {
                    (self.config.platform as! VZMacPlatformConfiguration).auxiliaryStorage = try VZMacAuxiliaryStorage(creatingStorageAt: auxiliary_storage_url, hardwareModel: hw_model, options: [])
                } catch {
                    throw VelocityVZError("Could not create AuxiliaryStorage: \(error.localizedDescription)")
                }
            }

            (self.config.platform as! VZMacPlatformConfiguration).machineIdentifier = VZMacMachineIdentifier()
        }

        // Call super constructor
        super.init(configuration: self.config, queue: DispatchQueue.main);

        // Set delegate
        self.delegate = self

        VDebug("HACK: Setting Activation Policy to accessory to Hide NSWindow..")
        NSApp.setActivationPolicy(.accessory)

        // Self as vm_view's VM
        vm_view.virtualMachine = self;

        // Write to Disk
        try? self.get_storageformat().write(atPath: bundle_path.appendingPathComponent("vVM.json").absoluteString)
    }

    public func get_vminfo() -> vVMInfo {
        return vVMInfo(name: self.name, cpu_count: self.cpu_count, memory_size: self.memory_size, screen_size: self.screen_size, autostart: self.autostart, disks: self.disks, state: self.vstate, specific: self.specific)
    }

    public func get_storageformat() -> vVMStorageFormat {
        return vVMStorageFormat(name: self.name, cpu_count: self.cpu_count, memory_size: self.memory_size, screen_size: self.screen_size, autostart: self.autostart, disks: self.disks, specific: self.specific)
    }

    /// Gets the machine type specific information
    /// e.g. ISO for EFI, IPSFW for Mac
    public func get_specific() -> (vMacOptions?, vEFIOptions?) {
        return self.specific
    }

    public static func from_storage_format(storage_format: vVMStorageFormat) throws -> vVirtualMachine? {

        // VM is a mac
        if let specific = storage_format.mac_specific {
            do {
                let vm = try vVirtualMachine(name: storage_format.name, cpu_count: storage_format.cpu_count, memory_size: storage_format.memory_size, screen_size: storage_format.screen_size, autostart: storage_format.autostart, disks: storage_format.disks, specific: (specific, nil))
                return vm;
            } catch {
                throw VelocityVZError(error.localizedDescription)
            }

        }

        // VM is EFI
        if let specific = storage_format.efi_specific {
            do {
                let vm = try vVirtualMachine(name: storage_format.name, cpu_count: storage_format.cpu_count, memory_size: storage_format.memory_size, screen_size: storage_format.screen_size, autostart: storage_format.autostart, disks: storage_format.disks, specific: (nil, specific))

                return vm;
            } catch {
                throw VelocityVZError(error.localizedDescription)
            }
        }

        return nil;
    }

    /// Sends a macOS KeyEvent to the VM's Window
    /// - Parameter key_event: The MacOS KeyEvent from vRFBConvertKey
    /// - Parameter pressed: true -> Press / false -> release
    func send_macos_keyevent(macos_key_event: MacOSKeyEvent, pressed: Bool) {
        var keyevent: NSEvent? = nil;
        var char_ignoring_modifiers: Character? = nil;

        if let char = macos_key_event.char {

            // Set char_ignoring_modifiers if modifier flag .shift is set
            if let modifier_flag = macos_key_event.modifier_flag {
                if modifier_flag.contains(.shift) {
                    char_ignoring_modifiers = char.uppercased().first ?? char;
                } else {
                    char_ignoring_modifiers = char.lowercased().first ?? char;
                }
            }
        }

        // KeyEvent with Char
        if let char = macos_key_event.char {

            // modifier set
            if let char_ignoring_modifiers {
                VTrace("Generating NSEvent with modifiers")
                keyevent = NSEvent.keyEvent(with: pressed ? .keyDown : .keyUp, location: NSPoint.zero, modifierFlags: macos_key_event.modifier_flag ?? [ ], timestamp: TimeInterval(), windowNumber: 0, context: nil, characters: String(char), charactersIgnoringModifiers: String(char_ignoring_modifiers), isARepeat: false, keyCode: UInt16(macos_key_event.keycode))

            // No modifier
            } else {
                VTrace("Generating NSEvent without modifiers")
                keyevent = NSEvent.keyEvent(with: pressed ? .keyDown : .keyUp, location: NSPoint.zero, modifierFlags: macos_key_event.modifier_flag ?? [ ], timestamp: TimeInterval(), windowNumber: 0, context: nil, characters: String(char), charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(macos_key_event.keycode))
            }

        // KeyEvent does not have a char
        } else {
            VTrace("Generating NSEvent without char and modifiers")
            keyevent = NSEvent.keyEvent(with: pressed ? .keyDown : .keyUp, location: NSPoint.zero, modifierFlags: macos_key_event.modifier_flag ?? [ ], timestamp: TimeInterval(), windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(macos_key_event.keycode))
        }

        VTrace("Generated NSEvent: \(String(describing: keyevent))")

        // Execute keyDown immediately
        if let keyevent {
            DispatchQueue.main.async {
                if(pressed) {
                    self.window?.vm_view.keyDown(with: keyevent)
                } else {
                    self.window?.vm_view.keyUp(with: keyevent)
                }
            }
        }
    }

    /// Sends the provided pointerEvent to the window
    func send_pointer_event(pointerEvent: VRFBPointerEvent) {
        let transformed_y_position = UInt16(self.screen_size.height) - pointerEvent.y_position
        VTrace("Moving pointer to x=\(pointerEvent.x_position) y=\(pointerEvent.y_position) (y-transformed=\(transformed_y_position))")

        let move_event = NSEvent.mouseEvent(
                with: .mouseMoved,
                location: NSPoint(x: Int(pointerEvent.x_position), y: Int(transformed_y_position)),
                modifierFlags: [ ],
                timestamp: TimeInterval(),
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 0,
                pressure: 0
            )

        let click_event_left = NSEvent.mouseEvent(
            with: pointerEvent.buttons_pressed[0] ? .leftMouseDown : .leftMouseUp,
            location: NSPoint(x: Int(pointerEvent.x_position), y: Int(transformed_y_position)),
            modifierFlags: [ ],
            timestamp: TimeInterval(),
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        )

        let click_event_right = NSEvent.mouseEvent(
            with: pointerEvent.buttons_pressed[2] ? .rightMouseDown : .rightMouseUp,
            location: NSPoint(x: Int(pointerEvent.x_position), y: Int(transformed_y_position)),
            modifierFlags: [ ],
            timestamp: TimeInterval(),
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        )

        DispatchQueue.main.async {
            if let move_event {
                self.window?.vm_view.mouseMoved(with: move_event)
            }

            if let click_event_left {
                if pointerEvent.buttons_pressed[0] {
                    self.window?.vm_view.mouseDown(with: click_event_left)
                } else {
                    self.window?.vm_view.mouseUp(with: click_event_left)
                }
            }

            if let click_event_right {
                if pointerEvent.buttons_pressed[2] {
                    self.window?.vm_view.mouseDown(with: click_event_right)
                } else {
                    self.window?.vm_view.mouseUp(with: click_event_right)
                }
            }

            VTrace("Mouse events sent.")
        }
    }

    func start() {
        self.start { (result) in
            if case let .failure(error) = result {
                VErr("Failed to start the virtual machine. \(error)")
                self.vstate = vVMState.CRASHED;
            }
            if case .success(_) = result {
                VInfo("'\(self.name)': State changed to: RUNNING.")
                self.vstate = vVMState.RUNNING
            }
        }
    }

    func stop() {
        self.stop { (result) in
            VInfo("'\(self.name)': State changed to: STOPPED.")
            self.vstate = vVMState.STOPPED
        }
    }

    /// Install macOS if the mac_specific member variable is set
    func install_macos() {
        if let mac_specific = self.specific.0 {

            // add a new operation
            let operation = vOperation(name: "Installing macOS on \(self.name)..", description: "Installing macOS will take some time.", progress: 0)
            Manager.operations.append(operation)

            // MARK:  This is not thread-safe, since a new element could have been added
            let index = Manager.operations.count - 1;

            let ipsw_path_absolute = URL(fileURLWithPath: VelocityConfig.velocity_ipsw_dir.appendingPathComponent(mac_specific.ipsw_path).absoluteString)

            VZMacOSRestoreImage.load(from: ipsw_path_absolute, completionHandler: { [self](result: Result<VZMacOSRestoreImage, Error>) in
                switch result {
                    case .failure(_):
                    Manager.operations[index].description = "Could not load requested ipsw."
                    Manager.operations[index].completed = true;

                    case let .success(restoreImage):
                        guard let macOSConfiguration = restoreImage.mostFeaturefulSupportedConfiguration else {
                            Manager.operations[index].description = "No supported macOS configuration is available."
                            Manager.operations[index].completed = true;
                            return;
                        }

                        if !macOSConfiguration.hardwareModel.isSupported {
                            Manager.operations[index].description = "No supported macOS configuration is available."
                            Manager.operations[index].completed = true;
                            return;
                        }

                        DispatchQueue.main.async { [self] in
                            let installer = VZMacOSInstaller(virtualMachine: self, restoringFromImageAt: ipsw_path_absolute)

                            VLog("Starting installation for macOS VM \(self.name).")
                            installer.install(completionHandler: { (result: Result<Void, Error>) in
                                print("result: \(result)")
                                if case let .failure(error) = result {
                                    Manager.operations[index].description = "Could not install macOS: \(error.localizedDescription)"
                                    Manager.operations[index].completed = true;
                                } else {
                                    Manager.operations[index].description = "Installation succeeded \(self.name)."
                                    Manager.operations[index].completed = true;
                                }
                            })

                            // Observe installation progress.
                            _ = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { (progress, change) in
                                Manager.operations[index].progress = Float(change.newValue!)
                            }
                        }
                    }
                })
        } else {
            VWarn("install_macos() called on an EFI machine. Ignored.")
        }
    }

    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        self.vstate = vVMState.STOPPED
    }

    /// Returns the currently displayed frame data
    func get_cur_screen_contents() -> Data? {
        guard let image = self.window?.cur_frame else {
            return nil;
        }
        return NSImage(cgImage: image, size: .zero).pngData;
    }

    func get_window() -> VWindow? {
        return self.window
    }

    func get_png_snapshot() -> Data? {
        if let image = self.window?.cur_frame {
            return NSImage(cgImage: image, size: .zero).pngData;
        }

        return nil;
    }
}
