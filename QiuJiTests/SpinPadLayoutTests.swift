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
}
