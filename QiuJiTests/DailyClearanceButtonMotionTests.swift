import XCTest
@testable import QiuJi

final class DailyClearanceButtonMotionTests: XCTestCase {
    func testEntireLoopKeepsWholeBallsInsideCapsuleWithoutOverlappingEachOther() {
        for width in [118.0, 124, 132, 148, 180, 240] {
            for height in [44.0, 48, 56] {
                let motion = DailyClearanceButtonMotion(size: CGSize(width: width, height: height))
                for tick in 0...Int(ceil(DailyClearanceButtonMotion.duration * 120)) {
                    let points = motion.frame(at: Double(tick) / 120).balls
                    XCTAssertEqual(points.count, 6)
                    for (index, p) in points.enumerated() {
                        let cap = height / 2
                        let capX = min(width - cap, max(cap, p.x))
                        XCTAssertGreaterThanOrEqual(cap - hypot(p.x - capX, p.y - cap) - motion.radius, 1.4)
                        for other in points.dropFirst(index + 1) {
                            XCTAssertGreaterThanOrEqual(hypot(p.x - other.x, p.y - other.y), 2 * motion.radius - 0.04)
                        }
                    }
                }
            }
        }
    }

    func testPhaseSequenceRestAndSeamlessLoop() {
        let motion = DailyClearanceButtonMotion(size: CGSize(width: 124, height: 44))
        XCTAssertEqual(motion.frame(at: 0).balls, motion.home)
        XCTAssertEqual(motion.frame(at: 0).rackOpacity, 0.7)
        XCTAssertEqual(motion.frame(at: 1).rackOpacity, 0)
        XCTAssertNotEqual(motion.frame(at: 2).balls, motion.home)
        XCTAssertTrue(motion.rolling.contains { $0.contains { $0.x > 90 } }, "Balls must explore the button, not just the icon slot")
        let titleRect = CGRect(x: 42, y: 13, width: 74, height: 18)
        XCTAssertTrue(motion.rolling.contains { $0.contains { titleRect.contains($0) } },
                      "Balls must travel through the title area rather than treating it as an obstacle")
        XCTAssertEqual(motion.frame(at: 6).balls, motion.frame(at: 6.4).balls)
        let settled = DailyClearanceButtonMotion.gatherEnd + 1
        let duration = DailyClearanceButtonMotion.duration
        XCTAssertEqual(motion.frame(at: settled).balls, motion.home)
        XCTAssertEqual(motion.frame(at: settled).rackOpacity, 0.7)
        XCTAssertEqual(motion.frame(at: duration - 0.01).balls, motion.frame(at: duration).balls)
        for t in stride(from: 0.0, through: duration, by: 0.125) {
            for (a, b) in zip(motion.frame(at: t).balls, motion.frame(at: t + duration).balls) {
                XCTAssertEqual(a.x, b.x, accuracy: 1e-9)
                XCTAssertEqual(a.y, b.y, accuracy: 1e-9)
            }
        }
        // Equal intervals in either direction must cover the same path at the same speed.
        for tick in 0...624 {
            let t = Double(tick) / 120
            let outward = motion.frame(at: 0.65 + t).balls
            let returning = motion.frame(at: DailyClearanceButtonMotion.gatherEnd - t).balls
            for (a, b) in zip(outward, returning) {
                XCTAssertEqual(a.x, b.x, accuracy: 1e-9)
                XCTAssertEqual(a.y, b.y, accuracy: 1e-9)
            }
        }
    }
}
