//
//  VirtualMachineManager
//  velocity
//
//  Created by zimsneexh on 24.05.23.
//

import Foundation
import Virtualization
import Cocoa
import CoreGraphics

enum MachineType: Codable {
    case MAC
    case EFI_BOOTLOADER
    case KERNEL_BOOT
}

class Delegate: NSObject { }

extension VZVirtualMachineView {
    func data(using fileType: NSBitmapImageRep.FileType = .png, properties: [NSBitmapImageRep.PropertyKey: Any] = [:]) -> Data {
        let imageRepresentation = bitmapImageRepForCachingDisplay(in: bounds)!
        cacheDisplay(in: bounds, to: imageRepresentation)
        return imageRepresentation.representation(using: fileType, properties: properties)!
    }
}

extension NSImage {
    func pngWrite(to url: URL, options: Data.WritingOptions = .atomic) -> Bool {
        do {
            let data = self.pngData
            try data?.write(to: url, options: options)
            return true
        } catch {
            print(error)
            return false
        }
    }

    var pngData: Data? {
        guard let tiffRepresentation = tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}

extension Delegate: VZVirtualMachineDelegate {
    
    //MARK: How do we handle this callback?
    //MARK: Probably pretty easy?
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        print("The guest shut down or crashed. Exiting.")
        exit(EXIT_SUCCESS)
    }
}

internal struct VelocityVMMError: Error, LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}

internal struct Disk: Codable {
    var name: String
    var size_mb: UInt64
    
    init(name: String, size_mb: UInt64) {
        self.name = name
        self.size_mb = size_mb
    }
}

public struct VMInfo: Codable {
    var name: String
    var cpu_count: Int
    var machine_type: MachineType
    var iso_image_path: String?
    var rosetta: Bool
    var disks: Array<Disk>
    var memory_size: UInt64
    
    init(name: String, cpu_count: Int, memory_size: UInt64, machine_type: MachineType, iso_image_path: String, rosetta: Bool, disks: Array<Disk>) {
        self.name = name
        self.cpu_count = cpu_count
        self.memory_size = memory_size
        self.machine_type = machine_type
        self.iso_image_path = iso_image_path
        self.rosetta = rosetta
        self.disks = disks
    }
    
    func as_json() throws  -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(self)
            return String(decoding: data, as: UTF8.self)
        } catch {
            throw VelocityVMMError("Could not decode as JSON")
        }
    }
    
    func validate() throws {
        if(!FileManager.default.fileExists(atPath: self.iso_image_path!)) {
            throw VelocityVMMError("Could not find ISO-Image.")
        }
        
        let available_cpus = ProcessInfo.processInfo.processorCount
        if(available_cpus < self.cpu_count) {
            throw VelocityVMMError("Cannot allocate more CPUs than are available.")
        }
        
        
    }
    
    func write(atPath: String) throws {
        do {
            try self.as_json().write(toFile: atPath, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            throw VelocityVMMError(error.localizedDescription)
        }
    }
}

//
// Create a new virtual machine with
// given Struct
//
public func new_vm(velocity_config: VelocityConfig, vm_info: VMInfo) throws {
    NSLog("Creating new virtual machine '\(vm_info.name)'..")
    let bundle_path = velocity_config.velocity_bundle_dir + "/\(vm_info.name).bundle/"
    
    // Check if already exists?
    if(FileManager.default.fileExists(atPath: bundle_path)) {
        throw VelocityVMMError("Could not create VM at path \(bundle_path), because a VM with this name already exists.")
    }
        
    // Create a VM Bundle
    NSLog("Creating Bundle at \(bundle_path)..")
    if(!createDirectorySafely(path: bundle_path)) {
        throw VelocityVMMError("Could not create bundle directory.")
    }
    
    // Write bundle json file to disk
    NSLog("Writing VM.json to disk..")
    do {
        try vm_info.write(atPath: bundle_path + "Velocity.json")
    } catch {
        throw VelocityVMMError(error.localizedDescription)
    }
    
    // Create MachineIdentifier
    let machine_identifier_path = bundle_path + "MachineIdentifier"

    switch(vm_info.machine_type) {
    case MachineType.MAC:
        throw VelocityVMMError("Machine type not implemented.");
        
    case MachineType.EFI_BOOTLOADER:
        if(!new_generic_machine_identifier(pathTo: machine_identifier_path)) {
            throw VelocityVMMError("Could not create machine identifier.");
        }
        
        let efi_stor_path = bundle_path + "NVRAM"
        
        guard let _ = try? VZEFIVariableStore(creatingVariableStoreAt: URL(fileURLWithPath: efi_stor_path)) else {
            throw VelocityVMMError("Could not create EFI Variable storage in bundle.")
        }
        
    case MachineType.KERNEL_BOOT:
        throw VelocityVMMError("Machine type not implemented.");
    
    }
    
    NSLog("Creating Disk Image(s)..")
    for disk in vm_info.disks {
        do {
            try create_disk_image(pathTo: bundle_path, disk: disk)
        } catch {
            throw VelocityVMMError("Error: \(error.localizedDescription)")
        }
    }
}

public func start_vm_by_name(velocity_config: VelocityConfig, vm_name: String) throws {
    let bundle_path = velocity_config.velocity_bundle_dir + "/\(vm_name).bundle/"
    
    if(!FileManager.default.fileExists(atPath: bundle_path)) {
        throw VelocityVMMError("Could not find VM by name '\(vm_name)'")
    }
    
    var file_content: String;
    do {
        file_content = try String(contentsOfFile: bundle_path + "Velocity.json", encoding: .utf8)
    } catch {
        throw VelocityVMMError("Could not read VM definition: \(error)")
    }
    
    let decoder = JSONDecoder()
    let vm_info = try decoder.decode(VMInfo.self, from: Data(file_content.utf8))
    let vm_disks = NSMutableArray()
    
    // Setup the VM
    let virtual_machine_config = VZVirtualMachineConfiguration()
    virtual_machine_config.cpuCount = vm_info.cpu_count
    virtual_machine_config.memorySize = (vm_info.memory_size * 1024 * 1024)
    
    virtual_machine_config.keyboards = [VZUSBKeyboardConfiguration()]
    
    NSLog("Selected Machine type is \(vm_info.machine_type)")
    switch(vm_info.machine_type) {
    case MachineType.EFI_BOOTLOADER:
        let platform = VZGenericPlatformConfiguration()
        let bootloader = VZEFIBootLoader()
        
        // Check for EFI Store and import it
        NSLog("Checking for NVRAM..")
        if !FileManager.default.fileExists(atPath: bundle_path + "NVRAM") {
            throw VelocityVMMError("EFI variable store does not exist.")
        }
        
        bootloader.variableStore = VZEFIVariableStore(url: URL(fileURLWithPath: bundle_path + "NVRAM"))
        
        NSLog("NVRAM set.")
        NSLog("Checking for MachineIdentifier..")
        guard let machine_identifier_data = try? Data(contentsOf: URL(fileURLWithPath: bundle_path + "MachineIdentifier")) else {
            throw VelocityVMMError("Failed to retrieve machine identifier data.")
        }
        
        NSLog("Setting MachineIdentifier..")
        guard let machine_identifier = VZGenericMachineIdentifier(dataRepresentation: machine_identifier_data) else {
            throw VelocityVMMError("Could not load Machine Identifier data.")
        }
        platform.machineIdentifier = machine_identifier
        NSLog("EFI Setup completed.")
        
        virtual_machine_config.platform = platform
        virtual_machine_config.bootLoader = bootloader
        
        virtual_machine_config.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]
        virtual_machine_config.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
        
    case MachineType.KERNEL_BOOT:
        break
        
    case MachineType.MAC:
        break
    }
    
    if(vm_info.iso_image_path != nil) {
        NSLog("Attaching ISO image at path \(vm_info.iso_image_path!)..")
        guard let installer_disk_attachment = try? VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: vm_info.iso_image_path!), readOnly: true) else {
            throw VelocityVMMError("Could not attach ISO image to VM")
        }
        vm_disks.add(VZUSBMassStorageDeviceConfiguration(attachment: installer_disk_attachment))
    }
    
    NSLog("Attaching stdin serial port to the machine.")
    //virtual_machine_config.serialPorts = [ createConsoleConfiguration() ]
    //virtual_machine_config.consoleDevices = [ createSpiceAgentConsoleDeviceConfiguration() ]
    
    
    guard let disks = vm_disks as? [VZStorageDeviceConfiguration] else {
        throw VelocityVMMError("Invalid disksArray.")
    }
    virtual_machine_config.storageDevices = disks
    
    do {
        NSLog("Validating Machine Configuration.")
        try virtual_machine_config.validate()
        NSLog("Machine configuration is valid! Starting..")
    } catch {
        throw VelocityVMMError("Virtual Machine configuration is invalid: \(error)")
    }
    
    let graphicsDevice = VZVirtioGraphicsDeviceConfiguration()
    graphicsDevice.scanouts = [
        VZVirtioGraphicsScanoutConfiguration(widthInPixels: 1920, heightInPixels: 1080)
    ]
    virtual_machine_config.graphicsDevices = [ graphicsDevice ]
    
    let virtualMachine = VZVirtualMachine(configuration: virtual_machine_config)
    let virtualMachineView = VZVirtualMachineView()
    virtualMachineView.setFrameSize(NSSize(width: 1920, height: 1080))
    
    NSLog("HACK: Setting Activation Policy to accessory to Hide NSWindow..")
    NSApp.setActivationPolicy(.accessory)
    //virtualMachineView.layoutSubtreeIfNeeded()
    //virtualMachineView.wantsLayer = true
    //virtualMachineView.layer?.backgroundColor = NSColor.blue.cgColor
    
    virtualMachineView.virtualMachine = virtualMachine
    
    let delegate = Delegate()
    virtualMachine.delegate = delegate
    
    virtualMachine.start { (result) in
        NSLog("Hypervisor called back..")
        
        if case let .failure(error) = result {
            print("Failed to start the virtual machine. \(error)")
            exit(EXIT_FAILURE)
        }
        
        NSLog("Start exiting.")
    }

    /*
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered,
                          defer: false)
    window.contentView = virtualMachineView
    window.makeKeyAndOrderFront(nil)
    */
    var i = 0;
    
    let new_win = createOffscreenWindowAndAddVirtualMachineView(virtualMachineView)
    
    let _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        let capturedImage = captureContentOfWindow(windowNumber: CGWindowID(new_win.windowNumber))
        NSLog("Capturing \(i)")
        capturedImage?.pngWrite(to: URL(filePath: "/Users/zimsneexh/Desktop/sond/sond-\(i).png"))
        i = i + 1
        if(i == 10) {
            sendEnterKeyEvent(to: virtualMachineView)
        }
    }
    
    NSLog("Main loop")
    RunLoop.main.run(until: Date.distantFuture)
}

func sendEnterKeyEvent(to virtualMachineView: VZVirtualMachineView) {
    let enterKeyCode: UInt16 = 0x24
    let enterEvent = NSEvent.keyEvent(with: .keyDown, location: NSPoint.zero, modifierFlags: [], timestamp: TimeInterval(), windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: enterKeyCode)
    
    if let enterEvent = enterEvent {
        virtualMachineView.keyDown(with: enterEvent)
    }
}

func createOffscreenWindowAndAddVirtualMachineView(_ virtualMachineView: VZVirtualMachineView) -> NSWindow {
    let contentRect = virtualMachineView.frame
    
    //MARK: really ugly hack.. but cannot capture framebuffer directly
    let transparentWindowStyle = NSWindow.StyleMask.init(rawValue: 0)
    let offscreenWindow = NSWindow(contentRect: contentRect, styleMask: transparentWindowStyle, backing: .buffered, defer: false)
    
    offscreenWindow.isReleasedWhenClosed = false
    offscreenWindow.isExcludedFromWindowsMenu = true
    offscreenWindow.isMovableByWindowBackground = true
    offscreenWindow.level = .floating
    offscreenWindow.backgroundColor = NSColor.clear
    offscreenWindow.titleVisibility = .hidden
    offscreenWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
    offscreenWindow.standardWindowButton(.closeButton)?.isHidden = true
    offscreenWindow.standardWindowButton(.zoomButton)?.isHidden = true
    
    let offscreenFrame = CGRect(x: -10000, y: -10000, width: 1920, height: 1080)
    offscreenWindow.setFrame(offscreenFrame, display: false)
    
    // Add the VZVirtualMachineView to the offscreen window
    let viewWrapper = NSView(frame: contentRect)
    offscreenWindow.contentView = viewWrapper
    offscreenWindow.contentView?.addSubview(virtualMachineView)
    
    offscreenWindow.orderBack(nil)
    offscreenWindow.displayIfNeeded()

    return offscreenWindow
}

func captureContentOfWindow(windowNumber: CGWindowID) -> NSImage? {
    let windowImageOption = CGWindowListOption(arrayLiteral: .optionIncludingWindow)
    let windowInfoList = CGWindowListCopyWindowInfo(windowImageOption, windowNumber) as? [[String: AnyObject]]
    let windowInfo = windowInfoList?.first
    let windowBoundsDict = (windowInfo?[kCGWindowBounds as String] as! CFDictionary)
    
    let windowBounds = CGRect(dictionaryRepresentation: windowBoundsDict)!
    guard let cgImage = CGWindowListCreateImage(windowBounds, windowImageOption, windowNumber, [.bestResolution]) else {
        return nil
    }

    return NSImage(cgImage: cgImage, size: windowBounds.size)
}



internal func create_disk_image(pathTo: String, disk: Disk) throws {
    let disk_path = pathTo + "/\(disk.name).img"
    
    //MARK: check if disk name is valid.
    
    if !FileManager.default.createFile(atPath: disk_path, contents: nil, attributes: nil) {
        throw VelocityVMMError("Could not write disk image to file.")
    }
    
    guard let main_disk = try? FileHandle(forWritingTo: URL(fileURLWithPath: disk_path)) else {
        throw VelocityVMMError("Could not open the disk image for writing.")
    }

    do {
        try main_disk.truncate(atOffset: disk.size_mb * 1024 * 1024)
        NSLog("Disk image created at \(disk_path).")
    } catch {
        throw VelocityVMMError("Could not truncate the VM's main disk image.")
    }
}

private func createSpiceAgentConsoleDeviceConfiguration() -> VZVirtioConsoleDeviceConfiguration {
        let consoleDevice = VZVirtioConsoleDeviceConfiguration()

        let spiceAgentPort = VZVirtioConsolePortConfiguration()
        spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
        spiceAgentPort.attachment = VZSpiceAgentPortAttachment()
        consoleDevice.ports[0] = spiceAgentPort

        return consoleDevice
}

internal func new_generic_machine_identifier(pathTo: String) -> Bool {
    NSLog("Creating VZGenericMachineIdentifier..")
    let machine_identifier = VZGenericMachineIdentifier()
    
    do {
        try machine_identifier.dataRepresentation.write(to: URL(fileURLWithPath: pathTo))
    } catch {
        NSLog("Could not write bundle file to disk.")
        return false;
    }
    return true;
}


func createConsoleConfiguration() -> VZSerialPortConfiguration {
    NSLog("Creating console device.")
    let consoleConfiguration = VZVirtioConsoleDeviceSerialPortConfiguration()

    let inputFileHandle = FileHandle.standardInput
    let outputFileHandle = FileHandle.standardOutput

    // Put stdin into raw mode, disabling local echo, input canonicalization,
    // and CR-NL mapping.
    var attributes = termios()
    tcgetattr(inputFileHandle.fileDescriptor, &attributes)
    attributes.c_iflag &= ~tcflag_t(ICRNL)
    attributes.c_lflag &= ~tcflag_t(ICANON | ECHO)
    tcsetattr(inputFileHandle.fileDescriptor, TCSANOW, &attributes)

    let stdioAttachment = VZFileHandleSerialPortAttachment(fileHandleForReading: inputFileHandle,
                                                           fileHandleForWriting: outputFileHandle)

    consoleConfiguration.attachment = stdioAttachment
    return consoleConfiguration
}
