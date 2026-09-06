import XCTest
@testable import QiuJi

@MainActor
final class V51ResponsiveLayoutTests: XCTestCase {
    func testTimerBoundaryFormatsPreserveFullElapsedTime() {
        let vm = ActiveTrainingViewModel(mode: .free)
        let cases = [
            (0, "00:00:00"),
            (3599, "00:59:59"),
            (3600, "01:00:00"),
            (360_006, "100:00:06"),
        ]

        for (seconds, expected) in cases {
            vm.elapsedSeconds = seconds
            XCTAssertEqual(vm.formattedTime, expected)
        }
    }

    func testFloatingIndicatorUsesHoursInsteadOfUnboundedMinutes() {
        XCTAssertEqual(BTFloatingIndicator.formatElapsedTime(0), "0:00")
        XCTAssertEqual(BTFloatingIndicator.formatElapsedTime(3599), "59:59")
        XCTAssertEqual(BTFloatingIndicator.formatElapsedTime(3600), "1:00:00")
        XCTAssertEqual(BTFloatingIndicator.formatElapsedTime(360_006), "100:00:06")
    }

    func testCompactStageCapsRailsAt180And45PercentOfTable() {
        let proxy = ShotStageProxy(sceneSize: CGSize(width: 375, height: 520))

        XCTAssertLessThanOrEqual(proxy.barLength, 180.001)
        XCTAssertLessThanOrEqual(proxy.barLength, proxy.tableRect.height * 0.45 + 0.001)
        XCTAssertEqual(proxy.aimWheelFrame().height, proxy.barLength, accuracy: 0.001)
        XCTAssertEqual(
            proxy.instrumentFrame().height - ShotStageMetrics.instrumentTopReserve,
            proxy.barLength,
            accuracy: 0.001
        )
        XCTAssertEqual(proxy.aimWheelFrame().maxY, proxy.instrumentFrame().maxY, accuracy: 0.001)
    }

    func testHardAvailableHeightWinsOverVisualMinimum() {
        let length = ShotStageMetrics.resolvedBarLength(
            available: 82,
            tableHeight: 300,
            sceneSize: CGSize(width: 375, height: 420)
        )

        XCTAssertEqual(length, 82, accuracy: 0.001)
    }

    func testCompactRailUsesTableRatioWhenItIsLowerThan180() {
        let length = ShotStageMetrics.resolvedBarLength(
            available: 500,
            tableHeight: 360,
            sceneSize: CGSize(width: 375, height: 480)
        )

        XCTAssertEqual(length, 162, accuracy: 0.001)
    }

    func testNegativeAvailableHeightNeverProducesNegativeRail() {
        let length = ShotStageMetrics.resolvedBarLength(
            available: -20,
            tableHeight: 300,
            sceneSize: CGSize(width: 375, height: 420)
        )

        XCTAssertEqual(length, 0, accuracy: 0.001)
    }

    func testRegularStageRetains264PointMaximum() {
        let length = ShotStageMetrics.resolvedBarLength(
            available: 400,
            tableHeight: 600,
            sceneSize: CGSize(width: 430, height: 800)
        )

        XCTAssertEqual(length, ShotStageMetrics.maxBarLength, accuracy: 0.001)
    }

    func testPaletteUsesCompactVisualsButAtLeast44PointSlotsOnSE() {
        let proxy = ShotStageProxy(sceneSize: CGSize(width: 375, height: 520))
        let columnWidth = proxy.libraryWidth / CGFloat(BTBallPaletteMetrics.columns)

        XCTAssertEqual(proxy.paletteBallDiameter, 30)
        XCTAssertGreaterThanOrEqual(columnWidth, 44)
        XCTAssertEqual(BTBallPaletteMetrics.slotHeight(for: proxy.paletteBallDiameter), 44)
        XCTAssertLessThanOrEqual(proxy.libraryWidth, 375)
    }

    func testPaletteIsWidthCappedAndRegularOnIPad() {
        let proxy = ShotStageProxy(sceneSize: CGSize(width: 1024, height: 900))

        XCTAssertEqual(proxy.libraryWidth, ShotStageMetrics.paletteMaxWidth)
        XCTAssertEqual(proxy.paletteBallDiameter, 36)
    }

    func testPaletteWidthDerivesFromSafePageWidthAcrossTiers() {
        XCTAssertEqual(
            ShotStageMetrics.paletteWidth(sceneSize: CGSize(width: 375, height: 520)),
            352,
            accuracy: 0.001
        )
        XCTAssertEqual(
            ShotStageMetrics.paletteWidth(sceneSize: CGSize(width: 430, height: 700)),
            352,
            accuracy: 0.001
        )
        XCTAssertEqual(
            ShotStageMetrics.paletteWidth(sceneSize: CGSize(width: 1024, height: 900)),
            ShotStageMetrics.paletteMaxWidth,
            accuracy: 0.001
        )
    }

    func testPaletteContainsCueAndAllFifteenObjectBallsInTwoRows() {
        XCTAssertEqual(PositionPlayBall.allKeys.count, 16)
        XCTAssertEqual(PositionPlayBall.allKeys.first, PositionPlayBall.cueKey)
        XCTAssertEqual(PositionPlayBall.allKeys[8], "_8")
        XCTAssertEqual(PositionPlayBall.allKeys.last, "_15")
        XCTAssertEqual(BTBallPaletteMetrics.columns, 8)
    }

    func testPaletteCompactionPreservesBallScaleAndTableBands() {
        XCTAssertEqual(BTBallPaletteMetrics.compactDiameter, 30)
        XCTAssertEqual(BTBallPaletteMetrics.regularDiameter, 36)
        XCTAssertEqual(ShotStageMetrics.BottomBarHeight.composer.rawValue, 94)
        XCTAssertEqual(ShotStageMetrics.BottomBarHeight.planThree.rawValue, 140)
        let paletteHeight = 2 * BTBallPaletteMetrics.slotHeight(for: 36) + BTBallPaletteMetrics.rowSpacing
        XCTAssertLessThanOrEqual(paletteHeight, ShotStageMetrics.BottomBarHeight.composer.rawValue)
        for width: CGFloat in [375, 390, 393, 430, 768, 1024] {
            let column = ShotStageMetrics.paletteWidth(sceneSize: CGSize(width: width, height: 700)) / 8
            XCTAssertEqual(column, 44, accuracy: 0.001)
        }
    }

    func testPowerMappingRoundTripsAcrossCompactAndRegularRailLengths() {
        let velocities = stride(
            from: ShotTuning.velocityRange.lowerBound,
            through: ShotTuning.velocityRange.upperBound,
            by: 0.1
        )

        for railLength in [82.0, 180.0, 264.0] {
            for velocity in velocities {
                let fraction = ShotTuning.fraction(
                    forVelocity: velocity,
                    in: ShotTuning.velocityRange
                )
                let renderedY = railLength * (1 - fraction)
                let recoveredFraction = 1 - renderedY / railLength
                let recovered = ShotTuning.velocity(
                    forFraction: recoveredFraction,
                    in: ShotTuning.velocityRange
                )
                XCTAssertEqual(recovered, velocity, accuracy: 0.000_001)
            }
        }
    }

    func testTableGeometryDoesNotDependOnResponsiveChromeTier() {
        let size = CGSize(width: 375, height: 520)
        let direct = ShotTableLayout.tableRect(
            in: size,
            halfLength: ShotTableLayout.defaultHalfLength,
            halfWidth: ShotTableLayout.defaultHalfWidth
        )
        let proxy = ShotStageProxy(sceneSize: size)

        XCTAssertEqual(proxy.tableRect, direct)
    }
}
