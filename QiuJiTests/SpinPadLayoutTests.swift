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
