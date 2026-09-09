import Foundation

enum TapSide: Equatable { case left, right }
struct TouchSample {
    var count: Int; var id: Int; var x: Double; var y: Double; var time: Double; var valid = true
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
            guard duration >= 0.025, duration <= 0.22, sample.time-lastTap >= 0.065 else { return nil }
            lastTap = sample.time
            return begin.x < 0.5 ? .left : .right
        }
        guard sample.count == 1, sample.x.isFinite, sample.y.isFinite,
              (0.04...0.96).contains(sample.x), (0.04...0.96).contains(sample.y),
              abs(sample.x-0.5) > 0.035 else { cancel(); return nil }
        guard !blocked else { return nil }
        if let begin = initial {
            if sample.id != begin.id || hypot(sample.x-begin.x, sample.y-begin.y) > 0.035 || sample.time-begin.time > 0.22 {
                cancel()
            }
        } else { initial = sample }
        return nil
    }
}
