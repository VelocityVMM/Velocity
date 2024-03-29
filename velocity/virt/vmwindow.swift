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
import AppKit
import Virtualization

/// A wrapper for a virtual machine display. This class provides functions for
/// creating windows and capturing them for RFB delivery
class VirtualMachineWindow : NSWindow, Loggable {
    let context: String = "[VMWindow]"

    /// The virtual machine view that this window holds and displays
    let vm_view: VZVirtualMachineView

    /// The size of the screen. This is mainly for the RFB implementation to
    /// have a quick and safe way to infer the screen size
    let screen_size: NSSize

    /// The last captured frame
    var last_frame: CGImage? = nil

    init(vm_view: VZVirtualMachineView, size: NSSize) {
        self.vm_view = vm_view
        self.screen_size = size

        // Create a style mask
        let transparent_window_style = NSWindow.StyleMask.init(rawValue: 0);

        // Setup the content rect
        let content_rect = NSRect(origin: .zero, size: size)
        super.init(contentRect: content_rect, styleMask: transparent_window_style, backing: .buffered, defer: false)

        // Set Options for the window to be transparent and off-screen
        self.isReleasedWhenClosed = false
        self.isExcludedFromWindowsMenu = true
        self.isMovableByWindowBackground = true
        self.level = .floating
        self.backgroundColor = NSColor.clear
        self.titleVisibility = .hidden
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        let window_uuid = UUID().uuidString;
        self.title = window_uuid;

        // Window accepts MouseMovedEvents
        self.acceptsMouseMovedEvents = true

        // position the windows frame at -10k, so it is far offscreen
        let offscreenFrame = CGRect(x: -10000, y: -10000, width: Int(size.width), height: Int(size.height))
        self.setFrame(offscreenFrame, display: false)

        // Add the vm view to the offscreen window
        self.contentView = self.vm_view
        self.makeKeyAndOrderFront(nil)

        // Show the window
        self.orderBack(nil)
        self.displayIfNeeded()

        // HACK: Set activation policy to .accessory to hide the window (dock...)
        NSApp.setActivationPolicy(.accessory)
        self.makeKeyAndOrderFront(nil)
    }

    /// Captures the current contents of this virtual machine window and updates
    /// the internally held image
    /// - Returns: If the capturing succeeded
    func capture() -> Bool {
        // Setup the screenshot capture
        let windowListOption = CGWindowListOption(arrayLiteral: .optionIncludingWindow)
        let imageOption: CGWindowImageOption = [.boundsIgnoreFraming, .nominalResolution]
        let window_image = DispatchQueue.main.sync {
            return CGWindowListCreateImage(.null, windowListOption, CGWindowID(self.windowNumber), imageOption)
        }

        // Check if the new image is valid
        guard let new_image = window_image else {
            return false
        }

        // Replace the old image, if it differs
        if let old_image = self.last_frame {
            if !old_image.is_equal(to: new_image) {
                self.update_last_frame(new_image)
            }
        } else {
            self.update_last_frame(new_image)
        }

        return true
    }

    /// Updates the internally held image of the last screenshot of the virtual machine
    /// - Parameter frame: The frame to set
    func update_last_frame(_ frame: CGImage) {
        VTrace("Updating last frame")
        self.last_frame = frame
    }
}
