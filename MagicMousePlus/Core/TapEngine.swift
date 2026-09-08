import AppKit
import ApplicationServices

private let syntheticMarker: Int64 = 0x4D4D504C5553
private func receiveFrame(_ frame: MMFrame) {
    let received = ProcessInfo.processInfo.systemUptime
    DispatchQueue.main.async {
        TapEngine.shared.receive(frame, received: received)
    }
}
private func monitorEvent(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ context: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    // This tap is installed on the main run loop and never alters user input.
    MainActor.assumeIsolated { TapEngine.shared.observe(type, event: event) }
    return Unmanaged.passUnretained(event)
}

@MainActor final class TapEngine {
    static let shared = TapEngine()
    var onStatus: ((String, Bool) -> Void)?
    var onClick: ((TapSide) -> Void)?
    private var recognizer = TapRecognizer()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var refreshTimer: Timer?
    private var started = false
    private var observers: [NSObjectProtocol] = []
    private var enabled = false
    private var left = true
    private var right = true
    private var suspended = false
    private var connected = false
    private var generation: UInt64 = 0
    private var lastInterference = -Double.infinity
    private var pointerOrigin: CGPoint?
    private var previousClick: (TapSide, Double, CGPoint)?
    private var clickCount: Int64 = 0
    private var sessionStart = Double.infinity
    private var lastAccessibilityTrust: Bool?
    private var lastInputMonitoringAccess: Bool?

    func start() {
        guard !started else { return }
        started = true
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.suspended = true
                    self?.stopCapture()
                    self?.scheduleRefreshIfNeeded()
                }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.suspended = false; self?.refresh() }
            })
        }
        refresh()
    }

    private var refreshInterval: TimeInterval {
        if !enabled { return 60 }
        if lastAccessibilityTrust != true || lastInputMonitoringAccess != true { return 20 }
        return connected ? 15 : 4
    }

    private func scheduleRefreshIfNeeded() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        guard started, !suspended else { return }

        let interval = refreshInterval
        let next = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        next.tolerance = min(max(interval * 0.25, 1), 5)
        refreshTimer = next
        RunLoop.main.add(next, forMode: .common)
    }

    func configure(enabled: Bool, left: Bool, right: Bool) {
        self.enabled = enabled; self.left = left; self.right = right
        invalidate(); refresh()
    }
    private func invalidate() {
        generation &+= 1; recognizer.reset(); pointerOrigin = nil; previousClick = nil
        // Discard any contact already held while changing settings / permission.
        recognizer.cancel()
    }
    func refresh() {
        defer { scheduleRefreshIfNeeded() }
        guard enabled && !suspended else {
            stopCapture(); onStatus?(suspended ? "SLEEPING" : "DISABLED", false); return
        }

        let accessibilityTrusted = AXIsProcessTrusted()
        let inputMonitoringAccess = CGPreflightListenEventAccess()
        let permissionChanged = (lastAccessibilityTrust != nil && lastAccessibilityTrust != accessibilityTrusted)
            || (lastInputMonitoringAccess != nil && lastInputMonitoringAccess != inputMonitoringAccess)
        lastAccessibilityTrust = accessibilityTrusted
        lastInputMonitoringAccess = inputMonitoringAccess
        if permissionChanged { stopCapture() }

        guard accessibilityTrusted else {
            stopCapture(); onStatus?("PERMISSION NEEDED", false); return
        }
        guard inputMonitoringAccess else {
            stopCapture(); onStatus?("INPUT ACCESS NEEDED", false); return
        }

        // A session event tap can be disabled by macOS after a timeout or a
        // TCC transition. Do not keep a stale port around: rebuild the whole
        // capture session so the next gesture starts from a clean boundary.
        if let tap, !CGEvent.tapIsEnabled(tap: tap) { stopCapture() }
        if tap == nil && !installMonitor() {
            stopCapture(); onStatus?("INPUT ACCESS NEEDED", false); return
        }
        let result = MMBridgeRefresh(receiveFrame)
        if result != 1 { invalidate() }
        connected = result == 1
        onStatus?(result == 1 ? "ACTIVE" : result == -1 ? "ENGINE UNAVAILABLE" : result == -2 ? "DEVICE START FAILED" : "WAITING FOR MOUSE", connected)
    }
    private func installMonitor() -> Bool {
        let types: [CGEventType] = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .scrollWheel, .leftMouseDragged, .rightMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask, callback: monitorEvent, userInfo: nil),
              let runSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else { return false }
        tap = newTap; source = runSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        guard CGEvent.tapIsEnabled(tap: newTap) else {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runSource, .commonModes)
            CFMachPortInvalidate(newTap)
            tap = nil; source = nil
            return false
        }
        sessionStart = ProcessInfo.processInfo.systemUptime
        return true
    }
    func observe(_ type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            invalidate(); lastInterference = ProcessInfo.processInfo.systemUptime
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard event.getIntegerValueField(.eventSourceUserData) != syntheticMarker else { return }
        lastInterference = ProcessInfo.processInfo.systemUptime
        generation &+= 1; recognizer.cancel(); previousClick = nil
    }
    func receive(_ frame: MMFrame, received: Double) {
        let now = ProcessInfo.processInfo.systemUptime
        guard enabled, connected, !suspended, received >= sessionStart, now-received < 0.08 else { return }
        guard now-lastInterference > 0.12 else { recognizer.cancel(); return }
        let position = NSEvent.mouseLocation
        if frame.count > 0, pointerOrigin == nil { pointerOrigin = position }
        if let origin = pointerOrigin, hypot(position.x-origin.x, position.y-origin.y) > 6 { recognizer.cancel() }
        let result = recognizer.consume(TouchSample(count: Int(frame.count), id: Int(frame.identifier), x: Double(frame.x), y: Double(frame.y), time: frame.time, valid: frame.valid))
        if frame.count == 0 { pointerOrigin = nil }
        guard let side = result, (side == .left ? left : right) else { return }
        let token = generation
        // Small settling window lets the physical mouse event cancel a tap.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { [weak self] in
            let current = NSEvent.mouseLocation
            guard let self, token == self.generation, self.enabled, self.connected, !self.suspended,
                  AXIsProcessTrusted(),
                  !CGEventSource.buttonState(.combinedSessionState, button: .left),
                  !CGEventSource.buttonState(.combinedSessionState, button: .right),
                  hypot(current.x-position.x, current.y-position.y) <= 6 else { return }
            self.click(side, at: current)
        }
    }
    private func click(_ side: TapSide, at point: CGPoint) {
        let now = ProcessInfo.processInfo.systemUptime
        if let previousClick, previousClick.0 == side, now-previousClick.1 <= NSEvent.doubleClickInterval,
           hypot(point.x-previousClick.2.x, point.y-previousClick.2.y) <= 4 {
            clickCount = min(clickCount+1, 3)
        } else { clickCount = 1 }
        let button: CGMouseButton = side == .left ? .left : .right
        guard let eventSource = CGEventSource(stateID: .privateState) ?? CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(mouseEventSource: eventSource, mouseType: side == .left ? .leftMouseDown : .rightMouseDown, mouseCursorPosition: point, mouseButton: button),
              let up = CGEvent(mouseEventSource: eventSource, mouseType: side == .left ? .leftMouseUp : .rightMouseUp, mouseCursorPosition: point, mouseButton: button) else { return }
        for event in [down, up] {
            event.flags = CGEventSource.flagsState(.combinedSessionState)
            event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
            event.setIntegerValueField(.mouseEventClickState, value: clickCount)
            event.post(tap: .cghidEventTap)
        }
        previousClick = (side, now, point); onClick?(side)
    }
    private func stopCapture() {
        connected = false; sessionStart = .infinity; invalidate(); MMBridgeStop()
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil; tap = nil
    }
    func shutdown() {
        started = false
        refreshTimer?.invalidate(); refreshTimer = nil; stopCapture()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
    }
}
