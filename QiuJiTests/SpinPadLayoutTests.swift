import XCTest
@testable import QiuJi

final class SpinPadLayoutTests: XCTestCase {

    func testPadDiameterCapsAtMaxWhenTableIsWide() {
        let d = SpinPadLayout.padDiameter(tableWidth: 520)
        XCTAssertEqual(d, SpinPadLayout.maxPadDiameter, accuracy: 0.01)
    }

    func testPadDiameterLeavesRoomForKeys() {
        let tableW: CGFloat = 520
        let d = SpinPadLayout.padDiameter(tableWidth: tableW)
        let contentW = tableW - 2 * SpinPadLayout.horizontalPadding
        let occupied = d + 2 * SpinPadLayout.keyHit + 2 * SpinPadLayout.crossGap
        XCTAssertLessThanOrEqual(occupied, contentW + 0.01)
    }

    func testPadDiameterNeverCrowdsKeysOnNarrowTable() {
        let tableW: CGFloat = 200
        let d = SpinPadLayout.padDiameter(tableWidth: tableW)
        let contentW = tableW - 2 * SpinPadLayout.horizontalPadding
        let occupied = d + 2 * SpinPadLayout.keyHit + 2 * SpinPadLayout.crossGap
        XCTAssertLessThanOrEqual(occupied, contentW + 0.01)
        XCTAssertGreaterThan(d, 0)
    }

    func testResolvedTableWidthFallback() {
        XCTAssertEqual(SpinPadLayout.resolvedTableWidth(0), SpinPadLayout.fallbackTableWidth)
        XCTAssertEqual(SpinPadLayout.resolvedTableWidth(480), 480)
    }
    func testRailAnchorFitsEntirePanelSpanOnSlopingRail() {
        let polygon = [CGPoint(x: 0, y: 0), CGPoint(x: 600, y: 0),
                       CGPoint(x: 600, y: 360), CGPoint(x: 0, y: 240)]
        XCTAssertEqual(SpinPadRailAnchor.bottom(polygon: polygon, panelWidth: 200,
            stageSize: CGSize(width: 600, height: 400)), 280, accuracy: 0.01)
    }

    func testRailAnchorUsesInnerEdgeAndFallsBackForInvisibleTable() {
        let size = CGSize(width: 600, height: 400)
        let polygon = [CGPoint(x: 10, y: 10), CGPoint(x: 590, y: 10),
                       CGPoint(x: 590, y: 350), CGPoint(x: 10, y: 350)]
        XCTAssertEqual(SpinPadRailAnchor.bottom(polygon: polygon, panelWidth: 336, stageSize: size), 350)
        XCTAssertEqual(SpinPadRailAnchor.bottom(polygon: [], panelWidth: 336, stageSize: size), 392)
    }
}

extension SpinPadLayoutTests {
    func testNarrowTableProjectionShrinksCardBeforeFindingNearRail() {
        let size = CGSize(width: 400, height: 640)
        let polygon = [CGPoint(x: 100, y: 160), CGPoint(x: 300, y: 160),
                       CGPoint(x: 355, y: 540), CGPoint(x: 45, y: 540)]
        let width = SpinPadRailAnchor.panelWidth(polygon: polygon, stageSize: size)
        XCTAssertLessThan(width, 310)
        XCTAssertGreaterThanOrEqual(width, 220)
        let bottom = SpinPadRailAnchor.bottom(polygon: polygon, panelWidth: width, stageSize: size)
        XCTAssertEqual(bottom, 540, accuracy: 0.001)
        XCTAssertGreaterThan(SpinPadLayout.padDiameter(tableWidth: width), 100)
    }
}


extension SpinPadLayoutTests {
    func testDailyLandscapePlayfieldTracksBothViewportConstraints() {
        for size in [CGSize(width: 535, height: 331), CGSize(width: 638, height: 358),
                     CGSize(width: 1080, height: 700)] {
            let rect = ShotTableLayout.landscapePlayingRect(in: size,
                halfLength: 1.4055, halfWidth: 0.7995)
            XCTAssertEqual(rect.midX, size.width / 2, accuracy: 0.001)
            XCTAssertEqual(rect.midY, size.height / 2, accuracy: 0.001)
            XCTAssertEqual(rect.width / rect.height, 2, accuracy: 0.001)
            XCTAssertGreaterThan(rect.minY, 0)
            XCTAssertLessThan(rect.maxY, size.height)
            XCTAssertLessThan(rect.width, size.width)
        }
    }
}

extension SpinPadLayoutTests {
    func testSpinDragPickupAndClearanceDoNotMoveExistingPoint() {
        let dot = CGPoint(x: 70, y: 90)
        var drag = SpinPadDragSession(start: CGPoint(x: 80, y: 80), initialPoint: dot)
        for point in [CGPoint(x: 80, y: 80), CGPoint(x: 100, y: 80), CGPoint(x: 132, y: 80), CGPoint(x: 134, y: 80)] {
            XCTAssertEqual(drag.sample(point), dot)
        }
        XCTAssertTrue(drag.isFollowing)
        XCTAssertFalse(drag.isTap)
        XCTAssertEqual(drag.sample(CGPoint(x: 144, y: 85)), CGPoint(x: 80, y: 95))
    }

    func testSpinDragReversePreservesFingerGapInsteadOfRearmingDeadZone() {
        let start = CGPoint(x: 80, y: 80)
        var drag = SpinPadDragSession(start: start, initialPoint: start)
        _ = drag.sample(CGPoint(x: 134, y: 80))
        for finger in [CGPoint(x: 154, y: 80), CGPoint(x: 140, y: 85), CGPoint(x: 130, y: 80), start] {
            let dot = drag.sample(finger)
            XCTAssertEqual(finger.x - dot.x, 54, accuracy: 0.001)
            XCTAssertEqual(finger.y - dot.y, 0, accuracy: 0.001)
        }
    }

    func testSpinDragTapSlopAndFreshPickup() {
        var drag = SpinPadDragSession(start: .zero, initialPoint: CGPoint(x: 12, y: 30))
        _ = drag.sample(CGPoint(x: 3, y: 4))
        XCTAssertTrue(drag.isTap)
        _ = drag.sample(CGPoint(x: 30, y: 0))
        _ = drag.sample(.zero)
        XCTAssertFalse(drag.isTap, "Returning a drag to its start must not turn it into a tap")
        XCTAssertFalse(drag.isFollowing)
        var fresh = SpinPadDragSession(start: CGPoint(x: 40, y: 70), initialPoint: CGPoint(x: 12, y: 30))
        XCTAssertEqual(fresh.sample(CGPoint(x: 42, y: 72)), CGPoint(x: 12, y: 30))
        XCTAssertFalse(fresh.isFollowing)
    }

    func testSpinDragConversionPreservesAxesAndLimits() {
        let center = CGPoint(x: 80, y: 80)
        let left = SpinPadMath.contact(at: CGPoint(x: 60, y: 80), center: center, radius: 78, locksSideSpin: false)
        let high = SpinPadMath.contact(at: CGPoint(x: 80, y: 60), center: center, radius: 78, locksSideSpin: false)
        XCTAssertGreaterThan(left.x, 0)
        XCTAssertEqual(left.y, 0)
        XCTAssertGreaterThan(high.y, 0)
        XCTAssertEqual(high.x, 0)
        for x in stride(from: -200, through: 300, by: 25) {
            for y in stride(from: -200, through: 300, by: 25) {
                let point = CGPoint(x: x, y: y)
                let free = SpinPadMath.contact(at: point, center: center, radius: 78, locksSideSpin: false)
                XCTAssertLessThanOrEqual(hypot(free.x, free.y), SpinPadMath.miscueLimit + 1e-9)
                let locked = SpinPadMath.contact(at: point, center: center, radius: 78, locksSideSpin: true)
                XCTAssertEqual(locked.x, 0)
                XCTAssertLessThanOrEqual(abs(locked.y), SpinPadMath.miscueLimit + 1e-9)
            }
        }
    }
}
