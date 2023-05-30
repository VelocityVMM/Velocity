//
//  VZVirtualMachineView Capture Functions
//  velocity
//
//  Created by zimsneexh on 26.05.23.
//

import Foundation
import Cocoa
import CoreGraphics
import Virtualization
import Quartz

public struct VMViewSize {
    var width: UInt32
    var height: UInt32
    
    init(width: UInt32, height: UInt32) {
        self.width = width
        self.height = height
    }
}

//
// Capture a given NSWindow -> NSImage?
//
func capture_hidden_window(windowNumber: CGWindowID) -> NSImage? {
    let windowListOption = CGWindowListOption(arrayLiteral: .optionIncludingWindow)
    let imageOption: CGWindowImageOption = [.boundsIgnoreFraming, .nominalResolution]
    let windowImage = CGWindowListCreateImage(.null, windowListOption, windowNumber, imageOption)
    
    guard let cgImage = windowImage else {
        return nil
    }
    
    let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
    let nsImage = NSImage(cgImage: cgImage, size: imageSize)
    
    return nsImage
}

//
// Create a new, completely hidden, NSWindow
//
func create_hidden_window(_ virtual_machine_view: VZVirtualMachineView, vm_view_size: VMViewSize) -> NSWindow {
    let content_rect = virtual_machine_view.frame
    
    //MARK: really ugly hack.. but cannot capture framebuffer directly
    let transparent_window_style = NSWindow.StyleMask.init(rawValue: 0)
    let offscreen_window = NSWindow(contentRect: content_rect, styleMask: transparent_window_style, backing: .buffered, defer: false)
    
    // Set Options for the window to be transparent and off-screen
    offscreen_window.isReleasedWhenClosed = false
    offscreen_window.isExcludedFromWindowsMenu = true
    offscreen_window.isMovableByWindowBackground = true
    offscreen_window.level = .floating
    offscreen_window.backgroundColor = NSColor.clear
    offscreen_window.titleVisibility = .hidden
    offscreen_window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    offscreen_window.standardWindowButton(.closeButton)?.isHidden = true
    offscreen_window.standardWindowButton(.zoomButton)?.isHidden = true
     
    // position the windows frame at -10k, so it is far offscreen
    let offscreenFrame = CGRect(x: -10000, y: -10000, width: Int(vm_view_size.width), height: Int(vm_view_size.height))
    offscreen_window.setFrame(offscreenFrame, display: false)
    
    // Add the VZVirtualMachineView to the offscreen window
    let view_wrapper = NSView(frame: content_rect)
    offscreen_window.contentView = view_wrapper
    offscreen_window.contentView?.addSubview(virtual_machine_view)
    
    offscreen_window.orderBack(nil)
    offscreen_window.displayIfNeeded()
    
    NSEvent.addLocalMonitorForEvents(matching: .any) { event in
        print("Event: \(event)")
        return event
    }

    return offscreen_window
}
