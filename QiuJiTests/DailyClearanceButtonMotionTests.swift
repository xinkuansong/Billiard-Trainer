import XCTest
@testable import QiuJi

final class DailyClearanceButtonMotionTests: XCTestCase {
    func testEntireLoopKeepsWholeBallsInsideCapsuleWithoutOverlappingEachOther() {
        for width in [118.0, 124, 132, 148, 180, 240] {
            for height in [44.0, 48, 56] {
                let motion = DailyClearanceButtonMotion(size: CGSize(width: width, height: height))
                for tick in 0...1440 {
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
        XCTAssertEqual(motion.frame(at: 9.5).balls, motion.home)
        XCTAssertEqual(motion.frame(at: 9.5).rackOpacity, 0.7)
        XCTAssertEqual(motion.frame(at: 11.99).balls, motion.frame(at: 12).balls)
        for t in stride(from: 0.0, through: 12, by: 0.125) {
            XCTAssertEqual(motion.frame(at: t).balls, motion.frame(at: t + 12).balls)
        }
    }
}
