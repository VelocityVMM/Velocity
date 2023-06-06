//
//  vwindow.swift
//  velocity
//
//  Created by Max Kofler on 31/05/23.
//

import Foundation
import AppKit
import ScreenCaptureKit
import Virtualization

class VWindow : NSWindow {
    var cur_frame: CGImage?;
    var sample_count = 0;
    var vm_view: VZVirtualMachineView;
    var vm_size: CGSize;
    var rfb_sessions: [VRFBSession] = Array();
    var timer: Timer? = nil;

    init(vm_view: VZVirtualMachineView) {
        self.vm_view = vm_view;
        self.vm_size = vm_view.frame.size;

        let content_rect = self.vm_view.frame;

        //MARK: really ugly hack.. but cannot capture framebuffer directly
        let transparent_window_style = NSWindow.StyleMask.init(rawValue: 0);
        super.init(contentRect: content_rect, styleMask: transparent_window_style, backing: .buffered, defer: false);

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

        // position the windows frame at -10k, so it is far offscreen
        let offscreenFrame = CGRect(x: -10000, y: -10000, width: Int(self.vm_size.width), height: Int(self.vm_size.height))
        self.setFrame(offscreenFrame, display: false)

        // Add the VZVirtualMachineView to the offscreen window
        let view_wrapper = NSView(frame: content_rect)
        self.contentView = view_wrapper
        self.contentView?.addSubview(self.vm_view)

        self.orderBack(nil)
        self.displayIfNeeded()

        NSEvent.addLocalMonitorForEvents(matching: .any) { event in
            print("Event: \(event)")
            return event
        }

        self.timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true){ _ in
            if self.rfb_sessions.count == 0 {
                return;
            }

            guard let image = self.capture_window() else {
                return;
            }

            for session in self.rfb_sessions {
                try! session.frame_changed(frame: image);
            }
        }
    }

    /// Captures a screenshot of the current screen contents
    /// - Returns: A `CGImage` with the current contents, `nil` if capturing fails
    func capture_window() -> CGImage? {
        self.sample_count += 1;
        let windowListOption = CGWindowListOption(arrayLiteral: .optionIncludingWindow)
        let imageOption: CGWindowImageOption = [.boundsIgnoreFraming, .nominalResolution]
        let windowImage = CGWindowListCreateImage(.null, windowListOption, CGWindowID(self.windowNumber), imageOption)

        guard let cgImage = windowImage else {
            return nil
        }

        self.cur_frame = cgImage;

        return cgImage;
    }
}
