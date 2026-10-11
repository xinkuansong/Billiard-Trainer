import XCTest
import CoreGraphics
@testable import QiuJi

/// Capacity tests protect visible content and interaction slots. They do not
/// substitute for Menu hit testing, glyph rendering, or system window resizing.
final class DailyLayoutMetricsTests: XCTestCase {
    func testThreeRowStatusFitsCompactPaletteCornerWithoutShrinking() {
        let status = CGRect(x: 582, y: 1.5, width: 32, height: 41)
        let palette = CGRect(x: 84.5, y: 45, width: 498, height: 34)
        XCTAssertTrue(DailyDeviceStatus.fits(status, in: CGRect(x: 0, y: 0, width: 667, height: 375),
                                            obstacles: [palette], clearance: 2))
        XCTAssertFalse(DailyDeviceStatus.fits(status, in: CGRect(x: 0, y: 0, width: 667, height: 375),
                                             obstacles: [palette.offsetBy(dx: 0, dy: -2)], clearance: 2))
    }

    func testDeviceClockRollsOverInLocalTime() {
        let utc = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(DailyDeviceStatus.clockText(Date(timeIntervalSince1970: 86399), timeZone: utc), "23:59")
        XCTAssertEqual(DailyDeviceStatus.clockText(Date(timeIntervalSince1970: 86400), timeZone: utc), "00:00")
        XCTAssertEqual(DailyDeviceStatus.clockText(Date(timeIntervalSince1970: 86400), timeZone: TimeZone(secondsFromGMT: 28800)!), "08:00")
    }

    func testDeviceBatteryUnknownDoesNotBecomeFullOrEmpty() {
        XCTAssertNil(DailyDeviceStatus.fraction(level: -1, state: .unknown))
        XCTAssertNil(DailyDeviceStatus.fraction(level: 0.8, state: .unknown))
        for value: Float in [-1, 1.1, .nan, .infinity] {
            XCTAssertNil(DailyDeviceStatus.fraction(level: value, state: .unplugged))
        }
        XCTAssertEqual(DailyDeviceStatus.fraction(level: 0, state: .unplugged), 0)
        XCTAssertEqual(DailyDeviceStatus.fraction(level: 1, state: .full), 1)
        XCTAssertEqual(DailyDeviceStatus.fraction(level: 0.5, state: .charging), 0.5)
    }

    func testDeviceStatusDoesNotOverlapOrResizeOtherContent() {
        let bounds = CGRect(x: 0, y: 0, width: 667, height: 375)
        let status = CGRect(x: 582, y: 7, width: 32, height: 30)
        XCTAssertTrue(DailyDeviceStatus.fits(status, in: bounds,
            obstacles: [CGRect(x: 100, y: 45, width: 500, height: 30)]))
        XCTAssertFalse(DailyDeviceStatus.fits(status, in: bounds,
            obstacles: [CGRect(x: 100, y: 0, width: 500, height: 44)]))
        XCTAssertFalse(DailyDeviceStatus.fits(status, in: CGRect(x: 0, y: 0, width: 600, height: 375), obstacles: []))
    }

    func testC51PaletteCapacityWithoutTableFeedback() {
        for count in [4, 5, 6, 9, 15] {
            for width in stride(from: CGFloat(320), through: 1400, by: 10) {
                for height: CGFloat in [350, 800, 1180] {
                    let size = CGSize(width: width, height: height)
                    let reserved = DailyLayoutMetrics.FoundationReservation(width: width - 8,
                        targetCount: count, chineseEightBall: count == 15,
                        titleWidth: 92, actionWidth: 138,
                        prefersSeparateRow: height > width || height >= 600,
                        separateWidth: width > height && height < 600 ? width - 144 : nil)
                    let f = DailyLayoutMetrics.Foundation(size: size, leadingSafeArea: 0, trailingSafeArea: 0,
                        halfLength: CameraRig.defaultTableOuterHalfLength,
                        halfWidth: CameraRig.defaultTableOuterHalfWidth,
                        instrumentHeight: 259, palette: reserved)
                    let obstacles = [CGRect(x: 4, y: 0, width: 44, height: 44),
                        CGRect(x: 36, y: 13, width: 60, height: 18),
                        CGRect(x: width - 48, y: 0, width: 44, height: 44), f.left, f.right]
                    let p = DailyLayoutMetrics.Palette(size: size, sideInset: 4, table: f.table,
                        targetCount: count, chineseEightBall: count == 15, obstacles: obstacles)
                    XCTAssertLessThanOrEqual(p.diameter, 36)
                    XCTAssertGreaterThanOrEqual(p.diameter, 25)
                    if width >= height { XCTAssertFalse(p.twoRows, "Landscape never wraps") }
                    if p.fits {
                        let grid = CGRect(x: f.table.midX - p.targetWidth / 2, y: f.table.minY - p.height,
                                          width: p.targetWidth, height: p.height)
                        XCTAssertGreaterThanOrEqual(grid.minX, 4)
                        XCTAssertLessThanOrEqual(grid.maxX + (p.wingWidth > 0 ? 4 + p.wingWidth : 0), width - 4)
                        XCTAssertGreaterThanOrEqual(grid.minY, 0)
                        XCTAssertEqual(grid.maxY, f.table.minY, accuracy: 0.001)
                        for obstacle in obstacles { XCTAssertFalse(grid.intersects(obstacle)) }
                    }
                }
            }
        }
    }

    func testC51CompactHeaderUsesGlyphBoundsAndReportsImpossibleLandscape() {
        let table = CGRect(x: 68, y: 79, width: 531, height: 296)
        let obstacles = [CGRect(x: 4, y: 0, width: 44, height: 44),
            CGRect(x: 36, y: 13, width: 60, height: 18),
            CGRect(x: 619, y: 0, width: 44, height: 44),
            CGRect(x: 4, y: 61, width: 60, height: 314),
            CGRect(x: 603, y: 61, width: 60, height: 314)]
        let p = DailyLayoutMetrics.Palette(size: CGSize(width: 667, height: 375), sideInset: 4,
            table: table, targetCount: 15, chineseEightBall: true, obstacles: obstacles)
        XCTAssertEqual(p.diameter, 30)
        XCTAssertFalse(p.twoRows)
        XCTAssertTrue(p.fits)
        let constrained = DailyLayoutMetrics.Palette(size: CGSize(width: 400, height: 350), sideInset: 4,
            table: CGRect(x: 100, y: 44, width: 200, height: 112), targetCount: 15,
            chineseEightBall: true, obstacles: [])
        XCTAssertFalse(constrained.fits)
        XCTAssertFalse(constrained.twoRows)
    }

    func testCameraLaneCentersAllFourControlsOnMeasuredOuterShell() {
        // Readout/type size changes the shell height independently of ruler travel.
        for rulerHeight: CGFloat in [120, 144, 200] {
            for shellHeight: CGFloat in [166, 190, 246, 280] {
                let column = CGRect(x: 600, y: 44, width: 60, height: 360)
                let shell = CGRect(x: 8, y: 70, width: 44, height: shellHeight)
                let lane = DailyLayoutMetrics.CameraLane(column: column,
                    rulerHeight: rulerHeight, powerShell: shell, stackHeight: 188)
                let controls = CGRect(origin: CGPoint(x: lane.offset.width, y: lane.offset.height), size: CGSize(width: 44, height: 188))
                XCTAssertEqual(controls.midY, shell.midY, accuracy: 0.001)
                XCTAssertEqual(controls.maxX, column.width / 2 - 22 - (rulerHeight < 144 ? 4 : 8), accuracy: 0.001)
                XCTAssertLessThan(controls.maxX, shell.minX)
                XCTAssertFalse(lane.isOuter)
            }
        }
    }

    func testPaletteWrapPreservesAllSlotsWithoutReducingBallFaces() {
        for count in [4, 5, 6, 9, 15] {
            for width in stride(from: CGFloat(280), through: 1300, by: 1) {
                let p = DailyLayoutMetrics.FoundationReservation(width: width, targetCount: count,
                    chineseEightBall: count == 15, titleWidth: 92, actionWidth: 138,
                    prefersSeparateRow: true)
                XCTAssertGreaterThanOrEqual(p.diameter, 25)
                if p.fits { XCTAssertLessThanOrEqual(p.totalWidth, width + 1e-8) }
                XCTAssertFalse(p.sharesNavigation)
            }
        }
        let narrow = DailyLayoutMetrics.FoundationReservation(width: 412, targetCount: 15,
            chineseEightBall: true, titleWidth: 92, actionWidth: 138, prefersSeparateRow: true)
        XCTAssertTrue(narrow.twoRows)
        XCTAssertEqual(narrow.targetWidth, 7 * 27 + 8)
        XCTAssertEqual(narrow.height, 62)
        let wide = DailyLayoutMetrics.FoundationReservation(width: 592, targetCount: 15,
            chineseEightBall: true, titleWidth: 92, actionWidth: 138, prefersSeparateRow: true)
        XCTAssertFalse(wide.twoRows)
    }

    func testDailyCardUsesAvailableInnerSpaceAndLeavesSharedDefaultUnchanged() {
        for width in stride(from: CGFloat(210), through: 650, by: 3) {
            let rect = CGRect(x: 10, y: 20, width: width, height: 700)
            let pad = DailyLayoutMetrics.SpinPad(playingRect: rect, displayScale: 2, maximumExtent: 310)
            XCTAssertTrue(pad.fits)
            XCTAssertLessThanOrEqual(pad.extent, min(width, 310))
            XCTAssertGreaterThanOrEqual(pad.extent - 2 * SpinPadLayout.keyHit - 16, 104)
            let original = DailyLayoutMetrics.SpinPad(playingRect: rect, displayScale: 2)
            XCTAssertLessThanOrEqual(original.extent, 264)
        }
    }

    func testFoundationKeepsRealRatioSymmetricLanesAndBoundedControls() {
        for width in stride(from: CGFloat(360), through: 1400, by: 23) {
            for height in stride(from: CGFloat(300), through: 1400, by: 29) {
                let f = DailyLayoutMetrics.Foundation(size: .init(width: width, height: height),
                    leadingSafeArea: 0, trailingSafeArea: 0, halfLength: 1.405481, halfWidth: 0.7775,
                    instrumentHeight: 258)
                XCTAssertEqual(f.table.width / f.table.height,
                    f.rotated ? 0.7775 / 1.405481 : 1.405481 / 0.7775, accuracy: 1e-9)
                XCTAssertEqual(f.table.minX - f.left.midX, f.right.midX - f.table.maxX, accuracy: 1e-9)
                XCTAssertEqual(f.left.minY, f.right.minY)
                XCTAssertEqual(f.stage.midX, f.table.midX)
                XCTAssertEqual(f.stage.midY, f.table.midY)
                XCTAssertEqual(f.table.width * CGFloat(CameraRig.rotatedFitMargin), f.stage.width, accuracy: 1e-9)
                XCTAssertTrue([120, 144].contains(f.rulerLength))
                if f.fits {
                    XCTAssertGreaterThanOrEqual(f.left.minX, 4 - 1e-8)
                    XCTAssertLessThanOrEqual(f.right.maxX, width - 4 + 1e-8)
                    XCTAssertLessThanOrEqual(f.left.maxY, height + 1e-8)
                    XCTAssertGreaterThanOrEqual(f.table.minY, 44)
                    XCTAssertLessThanOrEqual(f.table.maxY, height + 1e-8)
                }
            }
        }
    }

    func testFoundationReferenceCapacitiesAndSafeArea() {
        for (w,h,safe) in [(667.0,375.0,0.0),(874,382,62),(956,420,62),(1210,809,0),(834,1153,0),(1024,719,0),(760,735,0)] {
            let f = DailyLayoutMetrics.Foundation(size: .init(width:w,height:h),
                leadingSafeArea:safe,trailingSafeArea:safe,halfLength:1.405481,halfWidth:0.7775,instrumentHeight:258)
            XCTAssertTrue(f.fits, "\(w)x\(h)")
            XCTAssertGreaterThanOrEqual(f.left.minX, safe - 1e-8)
            XCTAssertLessThanOrEqual(f.right.maxX,w-safe+1e-8)
            if h > w { XCTAssertEqual(f.left.midY, f.table.midY, accuracy: 0.5) }
            if h == 375 { XCTAssertEqual(f.rulerLength,120); XCTAssertFalse(f.horizontalActions) }
            if w == 874 { XCTAssertEqual(f.rulerLength,144); XCTAssertEqual(f.topDiameter,48) }
            if w == 956 { XCTAssertEqual(f.rulerLength,144); XCTAssertEqual(f.topDiameter,56) }
        }
    }

    func testSpaceProtectsReferenceAndUsesDockOnlyForLargerProportionalTable() {
        func space(_ width: CGFloat, _ height: CGFloat, safe: CGFloat = 0) -> DailyLayoutMetrics.Space {
            DailyLayoutMetrics.Space(size: CGSize(width: width, height: height), trailingSafeArea: safe,
                halfLength: 1.4055, halfWidth: 0.7995, instrumentHeight: 258, displayScale: 3)
        }
        let pro = space(750, 402, safe: 62)
        XCTAssertFalse(pro.docked)
        XCTAssertEqual(pro.stage, CGRect(x: 68, y: 36, width: 614, height: 358))
        XCTAssertEqual(pro.topDiameter, 48)
        XCTAssertEqual(pro.auxiliarySize, 44)
        // Loaded USDZ has a narrower outer Z extent than the bootstrap fallback.
        let loadedPro = DailyLayoutMetrics.Space(size: CGSize(width: 750, height: 402), trailingSafeArea: 62,
            halfLength: 1.4055, halfWidth: 0.7775, instrumentHeight: 257.6667, displayScale: 3)
        XCTAssertEqual(loadedPro.left.minY, 44)
        XCTAssertFalse(loadedPro.controls.horizontalActions)
        XCTAssertTrue(space(320, 800).isLimited, "Tall height cannot compensate for an unusably narrow playfield")
        XCTAssertTrue(space(600, 300).isLimited, "A short container cannot clip the instruments")
        for (width, height, safe) in [(CGFloat(750), CGFloat(402), CGFloat(62)), (667, 375, 0),
                                      (832, 440, 62), (1210, 834, 0), (760, 760, 0)] {
            XCTAssertFalse(space(width, height, safe: safe).isLimited)
        }
        let square = space(760, 760)
        XCTAssertTrue(square.docked)
        XCTAssertEqual(square.strikeSize, 72)
        XCTAssertEqual(square.columnWidth, 60)
        XCTAssertGreaterThan(square.dockTableWidth, square.sideTableWidth)
        XCTAssertGreaterThanOrEqual(square.left.minY, square.stage.maxY + 16)
        XCTAssertGreaterThanOrEqual(square.right.minX, square.left.maxX + 8)
        XCTAssertLessThanOrEqual(square.right.maxX + 48, 760)
        let maxPhone = space(832, 440, safe: 62)
        XCTAssertFalse(maxPhone.docked)
        XCTAssertEqual(maxPhone.stage.width, 696, "Button growth cannot steal stage width")
        XCTAssertGreaterThan(maxPhone.topDiameter, pro.topDiameter)
        XCTAssertLessThan(maxPhone.topDiameter, maxPhone.strikeSize)
        XCTAssertEqual(DailyLayoutMetrics.rulerHeight, 144)
        for width in stride(from: CGFloat(480), through: 1400, by: 20) {
            for height in stride(from: CGFloat(375), through: 1100, by: 25) {
                let candidate = space(width, height)
                if candidate.docked {
                    XCTAssertGreaterThan(candidate.dockTableWidth, candidate.sideTableWidth)
                    XCTAssertLessThanOrEqual(candidate.stage.maxY + 16, candidate.left.minY + 0.001)
                    XCTAssertLessThanOrEqual(candidate.right.maxY, height + 0.001)
                }
                XCTAssertLessThanOrEqual(candidate.topDiameter, 56)
                XCTAssertLessThanOrEqual(candidate.auxiliarySize, 48)
            }
        }
    }

    func testDailySpinCardFitsInnerRailsAndStopsGrowingAtReferenceSize() {
        for scale in [CGFloat(2), 3] {
            for height in stride(from: CGFloat(148), through: 900, by: 0.5) {
                let inner = CGRect(x: 23, y: 61, width: height * 2, height: height)
                let card = DailyLayoutMetrics.SpinPad(playingRect: inner, displayScale: scale)
                XCTAssertTrue(card.fits)
                XCTAssertLessThanOrEqual(card.extent, inner.height)
                XCTAssertLessThanOrEqual(card.extent, 264)
                XCTAssertGreaterThanOrEqual(card.extent - 104, 44)
                if height >= 264 { XCTAssertEqual(card.extent, 264) }

            }
            for delta in [-1 / scale, CGFloat(0), 1 / scale] {
                let inner = CGRect(x: 0, y: 0, width: 600, height: 264 + delta)
                let fit = DailyLayoutMetrics.SpinPad(playingRect: inner, displayScale: scale)
                XCTAssertEqual(fit.extent, min(264, 264 + delta), accuracy: 1e-10)
            }
        }
        XCTAssertFalse(DailyLayoutMetrics.SpinPad(playingRect: .zero, displayScale: 3).fits)
        XCTAssertFalse(DailyLayoutMetrics.SpinPad(playingRect: CGRect(x: 0, y: 0, width: 200, height: 147), displayScale: 3).fits)
    }

    func testControlCapacityPreservesProAndFitsSEWithoutShorteningRulers() {
        let pro = DailyLayoutMetrics.Controls(stageHeight: 358, instrumentHeight: 257.9167, displayScale: 3)
        XCTAssertEqual(pro.verticalPadding, 8)
        XCTAssertFalse(pro.horizontalActions)
        XCTAssertEqual(pro.minimumRequiredHeight, 340)
        let se = DailyLayoutMetrics.Controls(stageHeight: 331, instrumentHeight: 258.25, displayScale: 2)
        XCTAssertTrue(se.horizontalActions)
        XCTAssertEqual(se.minimumRequiredHeight, 322.25)
        XCTAssertEqual(se.verticalPadding, 4)
        XCTAssertTrue(se.fitsWithoutPadding)
        XCTAssertLessThanOrEqual(se.minimumRequiredHeight + 2 * se.verticalPadding, 331)
        let bootstrap = DailyLayoutMetrics.Controls(stageHeight: 331, instrumentHeight: 259, displayScale: 2)
        XCTAssertEqual(bootstrap.verticalPadding, se.verticalPadding)
        XCTAssertEqual(DailyLayoutMetrics.rulerHeight, 144)
        let max = DailyLayoutMetrics.Controls(stageHeight: 396, instrumentHeight: 257.9167, displayScale: 3)
        XCTAssertEqual(max.verticalPadding, 8)
        XCTAssertFalse(max.horizontalActions)
    }

    func testControlPaddingNeverSpendsMoreHeightThanAvailableAcrossDisplayPixels() {
        for scale in [CGFloat(1), 2, 3] {
            // Right column: independent 258.25 + 4 gap + 60 strike = 322.25.
            for extra in [CGFloat(-1), 0, 1 / scale, 8.75, 16, 100] {
                let available = 322.25 + extra
                let result = DailyLayoutMetrics.Controls(stageHeight: available,
                    instrumentHeight: 258.25, displayScale: scale)
                XCTAssertGreaterThanOrEqual(result.verticalPadding, 0)
                XCTAssertLessThanOrEqual(result.verticalPadding, 8)
                XCTAssertEqual(result.verticalPadding * scale, floor(result.verticalPadding * scale))
                XCTAssertEqual(result.fitsWithoutPadding, extra >= 0)
                if result.fitsWithoutPadding {
                    XCTAssertLessThanOrEqual(result.minimumRequiredHeight + 2 * result.verticalPadding, available)
                }
            }
        }
        let below = DailyLayoutMetrics.Controls(stageHeight: 357.999, instrumentHeight: 258.25, displayScale: 3)
        let at = DailyLayoutMetrics.Controls(stageHeight: 358, instrumentHeight: 258.25, displayScale: 3)
        XCTAssertTrue(below.horizontalActions)
        XCTAssertFalse(at.horizontalActions)
        XCTAssertEqual(at.minimumRequiredHeight, 340, "Both columns, including stacked left actions, must fit")
    }

    func testInvalidControlProposalsRemainFiniteAndReportInsufficientCapacity() {
        for height in [CGFloat(-1), 0, .nan, .infinity] {
            for instrument in [CGFloat(-1), 0, .nan, .infinity] {
                for scale in [CGFloat(0), -1, .nan, .infinity] {
                    let result = DailyLayoutMetrics.Controls(stageHeight: height, instrumentHeight: instrument, displayScale: scale)
                    XCTAssertTrue(result.minimumRequiredHeight.isFinite)
                    XCTAssertEqual(result.verticalPadding, 0)
                    XCTAssertFalse(result.fitsWithoutPadding)
                }
            }
        }
    }

    func testSettingsAnchorAndCapacityKeepSpinCardCentred() {
        for width in stride(from: CGFloat(320), through: 1366, by: 7) {
            for safe in [CGFloat(0), 44, 62] {
                for y in [CGFloat(70), 450] {
                    let card = CGRect(x: width / 2 - 121, y: y, width: 242, height: 242)
                    let panel = DailyLayoutMetrics.Panels(pageWidth: width, trailingSafeArea: safe, spinFrame: card)
                    XCTAssertEqual(panel.settingsLeading + panel.settingsWidth, width - max(4, safe), accuracy: 0.001)
                    XCTAssertGreaterThanOrEqual(panel.settingsLeading, max(4, safe))
                    XCTAssertGreaterThanOrEqual(panel.settingsWidth, 44)
                    XCTAssertLessThanOrEqual(panel.settingsWidth, 252)
                    if y == 450 { XCTAssertEqual(panel.settingsWidth, min(252, width - 2 * max(4, safe))) }
                }
            }
        }
        let se = DailyLayoutMetrics.Panels(pageWidth: 667, trailingSafeArea: 0,
            spinFrame: CGRect(x: 212.5, y: 80, width: 242, height: 242))
        XCTAssertEqual(se.settingsWidth, 202)
        XCTAssertEqual(se.settingsLeading, 461)
        XCTAssertEqual(DailyLayoutMetrics.Panels.top, 44 + 2)
    }

    func testSettingsViewportRespectsMeasuredStrikeWithoutMovingNaturalContent() {
        let plan = DailyLayoutMetrics.Panels(pageWidth: 667, trailingSafeArea: 0,
            spinFrame: CGRect(x: 212.5, y: 80, width: 242, height: 242))
        for y in stride(from: CGFloat(160), through: 500, by: 0.5) {
            let strike = CGRect(x: 610, y: y, width: 44, height: 44)
            let available = plan.settingsHeight(pageHeight: 375, strikeFrame: strike)
            XCTAssertLessThanOrEqual(46 + available + 8, min(y, 375))
            XCTAssertGreaterThanOrEqual(available, 0)
        }
        XCTAssertEqual(plan.settingsHeight(pageHeight: 375, strikeFrame: .null), 321)
        XCTAssertEqual(plan.settingsHeight(pageHeight: 375, strikeFrame: CGRect(x: 0, y: 100, width: 44, height: 44)), 321)
    }

    private typealias Header = DailyLayoutMetrics.Header
    private let regularTitle: CGFloat = 60
    private let compactTitle: CGFloat = 52

    private func plan(_ width: CGFloat, balls: Int = 15, leading: CGFloat = 62,
                      trailing: CGFloat = 24) -> Header {
        Header(width: width, targetCount: balls, separators: balls == 15 ? 10 : 0,
               regularTitleWidth: regularTitle, compactTitleWidth: compactTitle,
               leadingAllowance: leading, trailingExtension: trailing)
    }

    private func threshold(_ style: Header.Style, balls: Int = 15,
                           leading: CGFloat, trailing: CGFloat) -> CGFloat {
        Header.minimumWidth(targetCount: balls, separators: balls == 15 ? 10 : 0,
                            style: style, titleWidth: style == .regular ? regularTitle : compactTitle,
                            leadingAllowance: leading, trailingExtension: trailing)
    }

    func testQualifiedProAndUninsetSmallPhonePreserveDesignIntent() {
        let pro = plan(750)
        XCTAssertEqual(pro.presentation, .fullRow)
        XCTAssertEqual(pro.style, .regular)
        XCTAssertEqual(pro.paletteWidth, 586, accuracy: 0.001)
        XCTAssertEqual(pro.titleShift, 12)
        let small = plan(667, leading: 0, trailing: 0)
        XCTAssertEqual(small.presentation, .fullRow)
        XCTAssertEqual(small.style, .compact)
        XCTAssertEqual(small.titleShift, 0, "An uninset back button must not shift outside the window")
    }

    func testBothStyleCapacityBoundariesRespectTMinusOneTAndTPlusOne() {
        for leading in [CGFloat(0), 62] {
            for trailing in [CGFloat(0), 24] {
                let regularT = threshold(.regular, leading: leading, trailing: trailing)
                XCTAssertEqual(plan(regularT - 1, leading: leading, trailing: trailing).style, .compact)
                for width in [regularT, regularT + 1] {
                    let result = plan(width, leading: leading, trailing: trailing)
                    XCTAssertEqual(result.style, .regular)
                    XCTAssertEqual(result.presentation, .fullRow)
                }
                let compactT = threshold(.compact, leading: leading, trailing: trailing)
                XCTAssertNotEqual(plan(compactT - 1, leading: leading, trailing: trailing).presentation, .fullRow)
                for width in [compactT, compactT + 1] {
                    XCTAssertEqual(plan(width, leading: leading, trailing: trailing).presentation, .fullRow)
                }
            }
        }
    }

    func testFullRowsKeepVisibleTitleAndActualBallHitsClearOfActions() {
        for balls in [4, 5, 6, 9, 15] {
            for leading in [CGFloat(0), 62] {
                for trailing in [CGFloat(0), 24] {
                    for width in [CGFloat(400), 600, 667, 739, 740, 750, 900] {
                        let result = plan(width, balls: balls, leading: leading, trailing: trailing)
                        guard result.presentation == .fullRow else { continue }
                        let paletteStart = (width - result.paletteWidth) / 2
                        let hitWidth = result.style.diameter + 2
                        let cueHitStart = paletteStart + 4
                        let titleWidth = result.style == .regular ? regularTitle : compactTitle
                        let allowedExistingFit: CGFloat = result.style == .regular ? 2 : 0
                        let titleVisibleEnd = -result.titleShift + 44 - 12 + titleWidth - allowedExistingFit
                        XCTAssertGreaterThanOrEqual(cueHitStart - titleVisibleEnd, 2 - 0.001)
                        XCTAssertGreaterThanOrEqual(-result.titleShift, -leading)
                        let lastBallHitEnd = paletteStart + result.paletteWidth - hitWidth - 16
                        // The 1pt outline is part of the measured mode envelope.
                        let actionsStart = width + trailing - (2 * result.style.modeSegmentWidth + 6 + 44 + 1)
                        XCTAssertGreaterThanOrEqual(actionsStart - lastBallHitEnd, 2 - 0.001)
                        XCTAssertGreaterThanOrEqual(cueHitStart, 0)
                        XCTAssertLessThanOrEqual(lastBallHitEnd, width + trailing)
                    }
                }
            }
        }
    }

    func testFewerBallsAndMoreSafeSpaceNeverDemandMoreWidth() {
        for style in [Header.Style.regular, .compact] {
            var previous: CGFloat = 0
            for balls in [4, 5, 6, 9, 15] {
                let current = threshold(style, balls: balls, leading: 0, trailing: 0)
                XCTAssertGreaterThan(current, previous, "Adding roster slots must consume capacity")
                previous = current
                XCTAssertLessThanOrEqual(threshold(style, balls: balls, leading: 62, trailing: 24), current)
            }
        }
        XCTAssertEqual(plan(600, balls: 4).style, .regular,
                       "Short rosters can retain normal faces without a device-width classification")
        XCTAssertNotEqual(plan(600, balls: 15).presentation, .fullRow)
    }

    func testOverflowReservesFixedActionsAndACompleteTargetSlot() {
        var scrollingCases = 0
        for trailing in [CGFloat(0), 24] {
            for width in stride(from: CGFloat(0), through: CGFloat(650), by: CGFloat(1)) {
                let result = plan(width, leading: 0, trailing: trailing)
                guard result.presentation == .scrolling else { continue }
                scrollingCases += 1
                XCTAssertGreaterThanOrEqual(result.leadingWidth, 44, "Return remains a full interaction slot")
                XCTAssertGreaterThanOrEqual(result.targetViewportWidth, 52,
                                           "One 44pt target plus both shell insets must be revealable")
                let cueStart = result.leadingWidth + 4
                let targetStart = cueStart + 52 + 4
                let targetEnd = targetStart + result.targetViewportWidth
                let modeStart = targetEnd + 4
                let actionsEnd = modeStart + 66 + 44
                XCTAssertLessThanOrEqual(actionsEnd, width + trailing + 0.001)
                XCTAssertGreaterThanOrEqual(modeStart - targetEnd, 4,
                                           "A 1pt outline must not consume the whole inter-group gap")
                XCTAssertEqual(Header.overflowSlotWidth, 44,
                               "Overflow must reserve separate standard interaction slots")
            }
        }
        XCTAssertGreaterThan(scrollingCases, 0, "This test must exercise the actual overflow presentation")
    }

    func testWidthRoundTripHasNoHistoryAndTinyWidthsStayFinite() {
        let original = plan(750)
        for width in [CGFloat(667), 300, 44, 0, -1, CGFloat.leastNormalMagnitude, CGFloat.nan, CGFloat.infinity] {
            let result = plan(width, leading: 0, trailing: 0)
            XCTAssertTrue(result.paletteWidth.isFinite)
            XCTAssertTrue(result.leadingWidth.isFinite)
            XCTAssertTrue(result.targetViewportWidth.isFinite)
            XCTAssertGreaterThanOrEqual(result.targetViewportWidth, 0)
            if width < 44 { XCTAssertEqual(result.presentation, .limited) }
            let restored = plan(750)
            XCTAssertEqual(restored.style, original.style)
            XCTAssertEqual(restored.presentation, original.presentation)
            XCTAssertEqual(restored.paletteWidth, original.paletteWidth)
            XCTAssertEqual(restored.titleShift, original.titleShift)
        }
    }
}

extension DailyLayoutMetricsTests {
    func testTeachingInformationUsesUnzoomedInnerFrameAcrossWindowShapes() {
        for size in [CGSize(width: 874, height: 402), CGSize(width: 667, height: 375),
                     CGSize(width: 1180, height: 820), CGSize(width: 820, height: 1180)] {
            let halfLength = CameraRig.defaultTableOuterHalfLength
            let halfWidth = CameraRig.defaultTableOuterHalfWidth
            let foundation = DailyLayoutMetrics.Foundation(size: size, leadingSafeArea: 0, trailingSafeArea: 0,
                halfLength: halfLength, halfWidth: halfWidth,
                instrumentHeight: DailyLayoutMetrics.Controls.initialInstrumentHeight)
            let instruments = BTTeachingInstrumentLayout(foundation: foundation)
            let points = foundation.table.height / CGFloat(2 * (foundation.rotated ? halfLength : halfWidth))
            let layout = BTTeachingPageLayout(stageSize: foundation.stage.size, rotated: foundation.rotated,
                pointsPerMetre: points, instruments: instruments, spinPadPresented: false)
            // Independently use the same orthographic fit used by the native 2D camera.
            let scale = CameraRig.landscapeOrthographicScale(viewSize: foundation.stage.size,
                halfLength: foundation.rotated ? halfWidth : halfLength,
                halfWidth: foundation.rotated ? halfLength : halfWidth)!
            let nativePoints = foundation.stage.height / CGFloat(2 * scale)
            let innerHeight = CGFloat(foundation.rotated ? AngleSceneCalculator.innerLength : AngleSceneCalculator.innerWidth) * nativePoints
            XCTAssertEqual(layout.informationTop, (foundation.stage.height - innerHeight) / 2 + Spacing.md, accuracy: 0.001)
            XCTAssertEqual(layout.innerRect.midX, foundation.stage.width / 2, accuracy: 0.001)
            XCTAssertEqual(layout.innerRect.midY, foundation.stage.height / 2, accuracy: 0.001)
            XCTAssertGreaterThan(layout.informationTop, layout.innerRect.minY)
            XCTAssertEqual(instruments.rulerLength, foundation.rulerLength)
            XCTAssertEqual(instruments.rulerWidth, 32)
            XCTAssertEqual(instruments.topDiameter, foundation.topDiameter)
            XCTAssertEqual(instruments.strikeDiameter, 60)
        }
    }

    func testTeachingSpinEditorSuppressesOnlyOrdinaryInformation() {
        let notice = BTTeachingInformation(text: "已恢复上一杆")
        let readout = BTTeachingInformation(text: "①球：1号球", kind: .readout)
        XCTAssertTrue(notice.isVisible(spinPadPresented: false))
        XCTAssertFalse(notice.isVisible(spinPadPresented: true))
        XCTAssertTrue(readout.isVisible(spinPadPresented: true))
        XCTAssertFalse(BTTeachingInformation(text: " \n").isVisible(spinPadPresented: false))
        XCTAssertEqual(notice.effectiveSymbol, "info.circle")
        XCTAssertNil(readout.effectiveSymbol)
        XCTAssertEqual(BTTeachingInformation(text: "完成", symbol: "checkmark.circle").effectiveSymbol, "checkmark.circle")
    }

    func testTeachingTemporaryViewCannotEnablePrimaryOrParameterActions() {
        for hostEnabled in [false, true] {
            XCTAssertFalse(BTTeachingInstrumentLayout.effectiveEnabled(hostEnabled, temporaryTopDownActive: true))
            XCTAssertEqual(BTTeachingInstrumentLayout.effectiveEnabled(hostEnabled, temporaryTopDownActive: false), hostEnabled)
        }
    }

    func testTeachingTitleKeepsFourCharactersOnOneLineAndSplitsEvenly() {
        let four = BTTablePageTitleLayout("思路\n训练")
        XCTAssertEqual(four.upper, "思路训练")
        XCTAssertNil(four.lower)
        XCTAssertEqual(four.fontSize, 15)
        let six = BTTablePageTitleLayout("打一走二想三")
        XCTAssertEqual(six.upper, "打一走")
        XCTAssertEqual(six.lower, "二想三")
        XCTAssertNil(six.middle)
        XCTAssertEqual(six.fontSize, 13)
        XCTAssertEqual(six.width, four.width, "Wrapping cannot enlarge the title reservation or push the palette")
    }

    func testTeachingOddTitleHasSeparateVerticallyCentredMiddleCharacter() {
        let five = BTTablePageTitleLayout("旋转与加塞")
        XCTAssertEqual(five.upper, "旋转")
        XCTAssertEqual(five.lower, "加塞")
        XCTAssertEqual(five.middle, "与")
        let compact = BTTablePageTitleLayout("旋转与加塞", width: 60, compact: true)
        XCTAssertEqual(compact.fontSize, 12)
        XCTAssertEqual(BTTablePageTitleLayout("防守", compact: true).fontSize, 13)
    }
}
