import Foundation
@main struct Checks {
 static func main() {
    var checks = 0
    func expect(_ condition: Bool, _ name: String) { precondition(condition, name); checks += 1 }
    func sample(_ time: Double, _ x: Double = 0.25, _ y: Double = 0.5, _ count: Int = 1, _ id: Int = 1) -> TouchSample { TouchSample(count: count, id: id, x: x, y: y, time: time) }
    func run(_ frames: [TouchSample]) -> [TapSide] { var r = TapRecognizer(); return frames.compactMap { r.consume($0) } }
    expect(run([sample(1),sample(1.1,0,0,0)]) == [.left], "left tap")
    expect(run([sample(1,0.75),sample(1.1,0,0,0)]) == [.right], "right tap")
    expect(run([sample(1),sample(1.3,0,0,0)]).isEmpty, "long rest")
    expect(run([sample(1),sample(1.01,0,0,0)]).isEmpty, "noise")
    expect(run([sample(1),sample(1.05,0.32),sample(1.1,0,0,0)]).isEmpty, "scroll movement")
    expect(run([sample(1),sample(1.04,0.25,0.5,2),sample(1.1,0,0,0)]).isEmpty, "multiple fingers")
    expect(run([sample(1,0.5),sample(1.1,0,0,0)]).isEmpty, "center seam")
    expect(run([sample(1,0.01),sample(1.1,0,0,0)]).isEmpty, "edge")
    expect(run([sample(1),sample(1.05,0.25,0.5,1,2),sample(1.1,0,0,0)]).isEmpty, "identity replacement")
    expect(run([sample(1),sample(0.9),sample(1.1,0,0,0)]).isEmpty, "out of order")
    expect(run([sample(1),sample(1.05,.nan),sample(1.1,0,0,0)]).isEmpty, "nonfinite")
    expect(run([sample(1),sample(1.1,0,0,0),sample(1.18),sample(1.27,0,0,0)]) == [.left,.left], "double tap")
    expect(run([sample(1),sample(1.1,0,0,0),sample(1.11),sample(1.14,0,0,0)]) == [.left], "debounce")
    var r = TapRecognizer(); _ = r.consume(sample(1)); r.cancel()
    expect(r.consume(sample(1.1,0,0,0)) == nil, "physical click cancellation")
    _ = r.consume(sample(1.3)); expect(r.consume(sample(1.4,0,0,0)) == .left, "recovery")
    print("PASS: \(checks) tap recognizer checks")
 }
}
