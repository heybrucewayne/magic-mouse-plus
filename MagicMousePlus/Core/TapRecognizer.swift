import Foundation

enum TapSide: Equatable { case left, right }
struct TouchSample {
    var count: Int; var id: Int; var x: Double; var y: Double; var time: Double; var valid = true
}
enum TapTuning {
    static let minimumDuration = 0.020
    static let maximumDuration = 0.250
    static let maximumMovement = 0.045
    static let minimumReleaseGap = 0.020
    static let clickSettlingDelay = 0.025
}

/// Physical button release should not impose the longer scrolling cooldown.
struct TapSuppression {
    enum Kind { case button, scrollOrDrag, interruption }
    private var deadline = -Double.infinity
    mutating func observe(_ kind: Kind, at time: Double) {
        let interval = kind == .button ? 0.040 : 0.120
        deadline = max(deadline, time + interval)
    }
    func isActive(at time: Double) -> Bool { time < deadline }
}

/// Pure state machine; all mutation belongs to the main thread.
struct TapRecognizer {
    private var initial: TouchSample?
    private var blocked = false
    private var lastTime = -Double.infinity
    private var lastTap = -Double.infinity
    mutating func reset() { self = TapRecognizer() }
    mutating func cancel() { initial = nil; blocked = true }
    // Physical clicks/selection tools suppress output, not the release boundary.
    // A valid release must re-arm the next gesture even during suppression.
    mutating func consumeSuppressed(_ sample: TouchSample) {
        cancel()
        if sample.count == 0 { _ = consume(sample) }
    }
    mutating func consume(_ sample: TouchSample) -> TapSide? {
        guard sample.valid, sample.time.isFinite, sample.time > lastTime,
              sample.count >= 0, sample.count <= 16 else { cancel(); return nil }
        lastTime = sample.time
        if sample.count == 0 {
            defer { initial = nil; blocked = false }
            guard !blocked, let begin = initial else { return nil }
            let duration = sample.time - begin.time
            guard duration >= TapTuning.minimumDuration, duration <= TapTuning.maximumDuration else { return nil }
            lastTap = sample.time
            return begin.x < 0.5 ? .left : .right
        }
        guard sample.count == 1, sample.x.isFinite, sample.y.isFinite,
              (0.04...0.96).contains(sample.x), (0.04...0.96).contains(sample.y),
              abs(sample.x-0.5) > 0.035 else { cancel(); return nil }
        guard !blocked else { return nil }
        if let begin = initial {
            if sample.id != begin.id || hypot(sample.x-begin.x, sample.y-begin.y) > TapTuning.maximumMovement || sample.time-begin.time > TapTuning.maximumDuration {
                cancel()
            }
        } else {
            // Reject contact bounce by its off-surface gap. A valid fast second
            // tap must not be discarded simply because two releases are close.
            guard sample.time-lastTap >= TapTuning.minimumReleaseGap else { cancel(); return nil }
            initial = sample
        }
        return nil
    }
}
