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

class VWindow : NSWindow, SCStreamOutput {
    var cur_frame: CGImage?;
    var sample_count = 0;
    var sc_stream: SCStream?;
    var vm_view: VZVirtualMachineView;
    var vm_size: CGSize;
    
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

        // Create the stream configuration
        let stream_conf = SCStreamConfiguration();
        stream_conf.width = Int(self.vm_size.width);
        stream_conf.height = Int(self.vm_size.height);
        VInfo("[VWindow] Setting up capture with \(stream_conf.width)x\(stream_conf.height)px resolution")

        stream_conf.minimumFrameInterval = CMTime(value: 1, timescale: 60);
        stream_conf.queueDepth = 5;
        
        Task {
            let sc_window = await filter_window(window: self);
            let filter = SCContentFilter(desktopIndependentWindow: sc_window!);
            self.sc_stream = SCStream(filter: filter, configuration: stream_conf, delegate: nil);
            let queue = DispatchQueue.global();
            try! self.sc_stream!.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue);
            try! await self.sc_stream!.startCapture();
        };
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        // Return early if the sample buffer is invalid.
        guard sampleBuffer.isValid else { return }
        
        switch outputType {
        case .audio:
            return;
        case .screen:
            // Retrieve the array of metadata attachments from the sample buffer.
            guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let attachments = attachmentsArray.first else { return; }
            // Validate the status of the frame. If it isn't `.complete`, return nil.
            guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
                  let status = SCFrameStatus(rawValue: statusRawValue), status == .complete else { return; }
            
            guard let pixelBuffer = sampleBuffer.imageBuffer else { return; }
            
            guard let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else { return; }
            let surface = unsafeBitCast(surfaceRef, to: IOSurface.self)
            
            
            // Retrieve the content rectangle, scale, and scale factor.
            guard let contentRectDict = attachments[.contentRect],
                  let cr2 = CGRect(dictionaryRepresentation: contentRectDict as! CFDictionary)
                  //let contentScale = attachments[.contentScale] as? CGFloat,
                  //let scaleFactor = attachments[.scaleFactor] as? CGFloat else { return; }
            else { return; }
            
            let ciImage = CIImage(ioSurface: surface);
            let context = CIContext();
            
            let contentRect = CGRect(x: cr2.minX, y: cr2.minY, width: CGFloat(self.self.vm_size.width), height: CGFloat(self.self.vm_size.height));

            guard let cgImage = context.createCGImage(ciImage, from: contentRect) else {
                VWarn("[capture] Failed to convert CIImage to CGImage")
                return
            }

            self.cur_frame = cgImage;

            sample_count += 1;
            VDebug("[capture] Processing screen sample #\(sample_count): \(self.vm_size.width)x\(self.vm_size.height)");

        default:
            VWarn("[capture] Unexpected [unsupported] stream type encountered!");
        }
    }

            // Get the data of the bitmap representation
            guard let imageData = bitmapRep.representation(using: .png, properties: [:]) else {
                print("Failed to get image data.")
                return
            }

            let filePath = "/Users/max/Velocity/Capture/\(sample_count).png";
            // Write the image data to a file
            do {
                try imageData.write(to: URL(fileURLWithPath: filePath))
                print("Image saved successfully at \(filePath)")
            } catch {
                print("Failed to save image: \(error)")
            }

        self.cur_frame = cgImage;

        return cgImage;

        /*let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let nsImage = NSImage(cgImage: cgImage, size: imageSize)

        return nsImage*/
    }
}

func filter_window(window: NSWindow) async -> SCWindow? {
    let window_title = await window.title;
    let available = try! await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false);
    for cwindow in available.windows {
        if let title = cwindow.title, title == window_title {
            VLog("Got the window: '\(window_title)'");
            return cwindow;
        }
    }
    return nil;
}
