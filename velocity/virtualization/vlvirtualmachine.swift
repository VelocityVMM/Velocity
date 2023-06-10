//
//  vlvirtualmachine.swift
//  velocity
//
//  Created by Max Kofler on 01/06/23.
//

import Foundation
import Virtualization

class VVMDelegate: NSObject { }
extension VVMDelegate: VZVirtualMachineDelegate {
    
    //MARK: How do we handle this callback?
    //MARK: Probably pretty easy?
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        print("The guest shut down or crashed. Exiting.")
        //exit(EXIT_SUCCESS)
    }
}

enum VMState: Codable {
    case RUNNING
    case STOPPED
    case SHUTTING_DOWN
    case CRASHED
    case ABORTED
}

public struct VirtualMachine: Codable {
    var vm_state: VMState
    var vm_info: VMProperties
    
    init(vm_state: VMState, vm_info: VMProperties) {
        self.vm_state = vm_state
        self.vm_info = vm_info
    }
}

public class VLVirtualMachine : VZVirtualMachine {
    let window: VWindow;
    let vm_delegate: VVMDelegate;
    let vm_info: VMProperties;
    var vm_state: VMState;
    var vm_config: VZVirtualMachineConfiguration;

    /// Creates a new VLVirtualMachine from the supplied information
    /// - Parameter vm_config: The VZVirtualMachineConfiguration to use for vm creation
    init(vm_config: VZVirtualMachineConfiguration, vm_info: VMProperties) {
        self.vm_delegate = VVMDelegate();
        self.vm_config = vm_config;
        self.vm_info = vm_info;
        let vm_view = VZVirtualMachineView();
        vm_view.setFrameSize(self.vm_info.screen_size);

        self.window = VWindow(vm_view: vm_view, vm_info: vm_info);

        // The VM is stopped upon creation
        self.vm_state = VMState.STOPPED;

        VDebug("HACK: Setting Activation Policy to accessory to Hide NSWindow..")
        NSApp.setActivationPolicy(.accessory)

        super.init(configuration: self.vm_config, queue: DispatchQueue.main);

        vm_view.virtualMachine = self;
        self.delegate = self.vm_delegate;
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
                    self.window.vm_view.keyDown(with: keyevent)
                } else {
                    self.window.vm_view.keyUp(with: keyevent)
                }
            }
        }
    }

    /// Sends the provided pointerEvent to the window
    func send_pointer_event(pointerEvent: VRFBPointerEvent) {
        let transformed_y_position = UInt16(self.vm_info.screen_size.height) - pointerEvent.y_position
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
                self.window.vm_view.mouseMoved(with: move_event)
            }

            if let click_event_left {
                if pointerEvent.buttons_pressed[0] {
                    self.window.vm_view.mouseDown(with: click_event_left)
                } else {
                    self.window.vm_view.mouseUp(with: click_event_left)
                }
            }

            if let click_event_right {
                if pointerEvent.buttons_pressed[2] {
                    self.window.vm_view.mouseDown(with: click_event_right)
                } else {
                    self.window.vm_view.mouseUp(with: click_event_right)
                }
            }

            VTrace("Mouse events sent.")
        }
    }


    // MARK: Remove this and duplicate in Manager?
    /// Sends the provided keycode to the virtual machine
    /// - Parameter key_code: The code to send
    func send_key_event(key_code: UInt16) {

        let key_event = NSEvent.keyEvent(with: .keyDown, location: NSPoint.zero, modifierFlags: [], timestamp: TimeInterval(), windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: key_code)
        
        let key_release_event = NSEvent.keyEvent(with: .keyUp, location: NSPoint.zero, modifierFlags: [], timestamp: TimeInterval(), windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: key_code)
        
        // Execute keyDown immediately
        if let key_event = key_event {
            DispatchQueue.main.async {
                self.window.vm_view.keyDown(with: key_event)
            }
        }
        
        //Execute keyUp with 0.1 delay
        if let key_release_event = key_release_event {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.window.vm_view.keyUp(with: key_release_event)
            }
        }
    }

    /// Returns the VirtualMachine information for JSON serialization
    func get_vm() -> VirtualMachine {
        return VirtualMachine(vm_state: self.vm_state, vm_info: self.vm_info);
    }

    /// Returns the currently displayed frame data
    func get_cur_screen_contents() -> Data? {
        guard let image = self.window.cur_frame else {
            return nil;
        }
        return NSImage(cgImage: image, size: .zero).pngData;
    }
}
