import Foundation
import ApplicationServices

@main struct FrameInboxChecks {
    @MainActor static func main() {
        precondition(MouseClickEvents.eventSource?.localEventsSuppressionInterval == 0)
        // Construct, but never post, mouse events. Cover offset/negative displays
        // and fractional coordinates: neither Y inversion nor scaling is allowed.
        for point in [CGPoint(x: 120, y: 80), CGPoint(x: 120, y: 900),
                      CGPoint(x: -1200, y: 300), CGPoint(x: 2100, y: -700),
                      CGPoint(x: 400.5, y: 240.25)] {
            for side in [TapSide.left, .right] {
                let events = MouseClickEvents.make(side, at: point, clickCount: 2)!
                precondition(events.count == 2)
                precondition(events[0].type == (side == .left ? .leftMouseDown : .rightMouseDown))
                precondition(events[1].type == (side == .left ? .leftMouseUp : .rightMouseUp))
                for event in events {
                    precondition(event.location == point)
                    precondition(event.getIntegerValueField(.mouseEventClickState) == 2)
                }
            }
        }
        precondition(MouseClickEvents.make(.left, at: CGPoint(x: Double.nan, y: 0), clickCount: 1) == nil)
        print("PASS: left/right click coordinates, offset displays and invalid positions (no events posted)")
        let inbox = FrameInbox()
        var frame = MMFrame()
        frame.valid = true
        for index in 0..<32 {
            frame.identifier = Int32(index)
            precondition(inbox.append(frame, received: Double(index)) == (index == 0))
        }
        let ordered = inbox.drain()
        precondition(!ordered.overflow && ordered.frames.count == 32)
        precondition(ordered.frames.enumerated().allSatisfy { $0.element.0.identifier == Int32($0.offset) })
        for index in 0..<10_000 {
            precondition(inbox.append(frame, received: Double(index)) == (index == 0))
        }
        let overloaded = inbox.drain()
        precondition(overloaded.overflow && overloaded.frames.count <= 32)
        precondition(inbox.append(frame, received: 10_001))
        precondition(!inbox.drain().overflow)
        DispatchQueue.concurrentPerform(iterations: 10_000) { index in
            var sample = MMFrame()
            sample.identifier = Int32(index)
            _ = inbox.append(sample, received: Double(index))
        }
        let concurrent = inbox.drain()
        precondition(concurrent.overflow && concurrent.frames.count <= 32)
        precondition(inbox.drain().frames.isEmpty)
        print("PASS: bounded backlog, ordered frames, overflow recovery and concurrent producers")
    }
}
