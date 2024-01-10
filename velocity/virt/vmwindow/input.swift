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
import AppKit

extension VirtualMachineWindow {

    /// A structure to store the current mouse state to be able to respond to event efficiently
    /// without firing unnecessary events into the VM window
    struct MouseState : Loggable{
        let context = "[MouseState]"

        /// The last position of the mouse cursor
        var last_position: NSPoint = NSPoint()
        /// The last state of the left mouse button
        var last_lmb: Bool = false

        /// Handles an incoming event
        /// - Parameter event: The event to handle
        /// - Returns: An array of events that should be fired
        ///
        /// This function will mutate the inner state of this class to keep track of the current mouse state.
        /// This allows it to save on unnecessary events.
        mutating func handle(event: VRFBPointerEvent) -> [NSEvent] {
            var res: [NSEvent] = []
            let new_point = NSPoint(x: CGFloat(event.x_position), y: CGFloat(event.y_position))

            // Check if we have moved the cursor
            if new_point != last_position {

                // Construct an event for that
                let ns_event = NSEvent.mouseEvent(
                    with: event.get_move_eventtype(),
                    location: new_point,
                    modifierFlags: [],
                    timestamp: TimeInterval(),
                    windowNumber: 0,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 0,
                    pressure: 0
                )

                // If we constructed a valid event, execute it
                if let ns_event = ns_event {
                    self.last_position = new_point
                    res.append(ns_event)
                } else {
                    VWarn("Failed to construct pointer mouse moved event to \(new_point)")
                }
            }

            // Check for changed button state: LMB
            if event.pressed_buttons.button_left != self.last_lmb {
                let is_down = event.pressed_buttons.button_left

                let ns_event = NSEvent.mouseEvent(
                    with: is_down ? .leftMouseDown : .leftMouseUp,
                    location: self.last_position,
                    modifierFlags: [],
                    timestamp: TimeInterval(),
                    windowNumber: 0,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 0,
                    pressure: 0
                )

                VTrace("LMB changed from \(self.last_lmb) to \(is_down)")
                self.last_lmb = is_down

                if let ns_event = ns_event {
                    res.append(ns_event)
                } else {
                    VWarn("Failed to construct LEFT mouse button event to \(is_down)")
                }
            }

            return res
        }

    }
}
