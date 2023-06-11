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
    var fps = 25;
    let queue: DispatchQueue;

    init(vm_view: VZVirtualMachineView, vm_name: String) {
        self.vm_view = vm_view;
        self.vm_size = vm_view.frame.size;
        self.queue = DispatchQueue(label: "eu.zimsneexh.Velocity.vwindow.\(vm_name)", qos: .userInteractive);

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

        // Window accepts MouseMovedEvents
        self.acceptsMouseMovedEvents = true

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
        self.timer = Timer.scheduledTimer(timeInterval: 1.0 / Double(self.fps), target: self, selector: #selector(self.update_frame), userInfo: nil, repeats: true);
    }

    @objc func update_frame() {
        self.queue.sync {
            if self.rfb_sessions.count == 0 {
                return;
            }

            guard let new_image = self.capture_window() else {
                return;
            }

            do {
                // If we have a previous image, check if it is the same
                if let cur_image = self.cur_frame {
                    if !cur_image.is_equal(to: new_image) {
                        for session in self.rfb_sessions {
                            try session.frame_changed(frame: new_image);
                        }
                        self.cur_frame = new_image;
                    }
                } else {
                    for session in self.rfb_sessions {
                        try session.frame_changed(frame: new_image);
                    }
                    self.cur_frame = new_image;
                }

            } catch {
                VErr("Failed to update remote framebuffers");
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

        return cgImage;
    }
}

extension CGImage {
    /// Compares this image to another and returns if they are the same
    /// - Parameter to: The image to compare this image to
    func is_equal(to: CGImage) -> Bool {
        // Compare dimensions
        if self.width != to.width || self.height != to.height {
            return false
        }

        guard let data_1 = self.dataProvider?.data else {
            VErr("Failed to get dataProvider.data of image 1");
            return false;
        }

        guard let data_2 = to.dataProvider?.data else {
            VErr("Failed to get dataProvider.data of image 2");
            return false;
        }

        return (data_1 as Data).withUnsafeBytes { rd_1 in
            (data_2 as Data).withUnsafeBytes { rd_2 in
                return memcmp(rd_1.baseAddress!, rd_2.baseAddress!, CFDataGetLength(data_1)) == 0;
            }
        }
    }
}
