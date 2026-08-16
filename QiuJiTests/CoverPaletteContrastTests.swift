import XCTest
import SwiftUI
@testable import QiuJi

/// Constraint A（水印可辨）与分区阶梯不变量；DR-055 后封面大字默认深墨、暗底金色回退。
final class CoverPaletteContrastTests: XCTestCase {

    func testAllPracticeCoversMeetWatermarkLuminanceDelta() {
        let minDelta = CoverPalette.Glyph.minLuminanceDelta
        for (idx, pair) in CoverPalette.allPracticePairs.enumerated() {
            let delta = CoverPalette.Glyph.luminanceDelta(against: pair.top)
            XCTAssertGreaterThanOrEqual(
                delta,
                minDelta,
                "zoneLadder[\(idx)] watermark |ΔL|=\(delta) < \(minDelta)"
            )
        }
        for (idx, pair) in CoverPalette.PracticeMulticolor.allPairs.enumerated() {
            let delta = CoverPalette.Glyph.luminanceDelta(against: pair.top)
            XCTAssertGreaterThanOrEqual(
                delta,
                minDelta,
                "multicolor[\(idx)] watermark |ΔL|=\(delta) < \(minDelta)"
            )
        }
    }

    func testAllPlanCoversMeetWatermarkLuminanceDelta() {
        let minDelta = CoverPalette.Glyph.minLuminanceDelta
        for key in CoverPalette.planLevelKeys {
            let top = CoverPalette.PlanStyle.forLevel(key).top
            let delta = CoverPalette.Glyph.luminanceDelta(against: top)
            XCTAssertGreaterThanOrEqual(
                delta,
                minDelta,
                "plan \(key) watermark |ΔL|=\(delta) < \(minDelta)"
            )
        }
    }

    func testCoverGlyphPrefersDarkInkExceptOnCharcoalTops() {
        // Colored plan tops → dark ink (not ghost white).
        for key in ["L0→L1", "L1", "L1→L2"] {
            let top = CoverPalette.PlanStyle.forLevel(key).top
            XCTAssertTrue(
                CoverPalette.Glyph.prefersDarkInk(against: top),
                "plan \(key) should prefer dark ink over gold"
            )
            XCTAssertEqual(
                glyphKey(CoverPalette.Glyph.color(against: top)),
                glyphKey(CoverPalette.Glyph.darkColor.opacity(CoverPalette.Glyph.darkOpacity)),
                "plan \(key) must use dark ink watermark"
            )
        }
        // Charcoal / brown / red editorial tops → gold (better contrast than ink).
        for key in ["L2", "L3", "L3→L4"] {
            let top = CoverPalette.PlanStyle.forLevel(key).top
            XCTAssertFalse(
                CoverPalette.Glyph.prefersDarkInk(against: top),
                "plan \(key) should prefer gold over dark ink"
            )
            XCTAssertEqual(
                glyphKey(CoverPalette.Glyph.color(against: top)),
                glyphKey(CoverPalette.Glyph.goldGlyph.opacity(CoverPalette.Glyph.goldOpacity)),
                "plan \(key) must use gold watermark"
            )
        }
    }

    func testTrainZoneStaysAboveMudBrightnessFloor() {
        // Gold ladder bottom brightness end = 0.44; sample deepest top via UIColor.
        let deep = CoverPalette.aimPointScene3D.top
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(deep).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        XCTAssertGreaterThanOrEqual(b, 0.60, "train deepest topB must stay ≥ 0.60 (no mud-brown)")
        XCTAssertEqual(h, 40.0 / 360.0, accuracy: 0.02, "train stays in gold hue family")
    }

    func testSolveZoneStartsDarkEnoughForGoldWatermark() {
        let top = CoverPalette.positionPlaySolver.top
        let L = CoverPalette.Glyph.relativeLuminance(of: top)
        XCTAssertLessThan(L, CoverPalette.Glyph.charcoalLuminanceCeiling,
                          "solve step0 must stay below charcoal luminance ceiling")
        XCTAssertFalse(CoverPalette.Glyph.prefersDarkInk(against: top))
        let delta = CoverPalette.Glyph.luminanceDelta(against: top)
        XCTAssertGreaterThanOrEqual(delta, CoverPalette.Glyph.minLuminanceDelta)
        XCTAssertEqual(
            glyphKey(CoverPalette.Glyph.color(against: top)),
            glyphKey(CoverPalette.Glyph.goldGlyph.opacity(CoverPalette.Glyph.goldOpacity))
        )
    }

    func testSingleLineCoverGlyphScalesAreTwoThirdsOfPrior() {
        // Plan single-line: 2-char 0.60→0.40, 3-char 0.48→0.32; practice grid 56→37.
        XCTAssertEqual(CoverPalette.Glyph.gridAbsoluteSize, 37, accuracy: 0.5)
        let twoChar = 96 * 0.40
        let threeChar = 96 * 0.32
        XCTAssertEqual(twoChar / (96 * 0.60), 2.0 / 3.0, accuracy: 0.01)
        XCTAssertEqual(threeChar / (96 * 0.48), 2.0 / 3.0, accuracy: 0.01)
    }

    func testWithinZonePairsAreNotIdentical() {
        let train = [
            CoverPalette.geometricQuiz,
            CoverPalette.sceneAiming2D,
            CoverPalette.sceneAiming3D,
            CoverPalette.aimPointTraining,
            CoverPalette.aimPointScene2D,
            CoverPalette.aimPointScene3D
        ]
        let uniqueTops = Set(train.map { colorKey($0.top) })
        XCTAssertEqual(uniqueTops.count, train.count, "train zone must keep visible step differentiation")
    }

    // MARK: - Plan editorial palette

    func testPlanStylesRestoreEditorialSixColorPalette() {
        let styles = CoverPalette.planLevelKeys.map { CoverPalette.PlanStyle.forLevel($0) }
        let uniqueTops = Set(styles.map { colorKey($0.top) })
        XCTAssertEqual(uniqueTops.count, styles.count, "plan levels must not share identical tops")

        XCTAssertEqual(
            styles.map { colorKey($0.top) },
            [
                "0.160-0.550-0.340",
                "0.110-0.460-0.950",
                "0.000-0.600-0.600",
                "0.180-0.180-0.200",
                "0.550-0.320-0.050",
                "0.620-0.140-0.140",
            ]
        )
    }

    func testPlanCoverLabelsUseConciseCourseThemes() {
        let ids = [
            "plan_beginner", "plan_cueball", "plan_accuracy", "plan_force",
            "plan_separation", "plan_english", "plan_positioning",
            "plan_positioning2", "plan_intermediate", "plan_accuracy3", "plan_advanced", "plan_fullskill",
        ]
        XCTAssertEqual(
            ids.map(PlanCoverLabel.text(for:)),
            ["入门", "杆法", "准度", "控力", "分离角", "加塞", "走位Ⅰ",
             "走位Ⅱ", "准度Ⅱ", "准度Ⅲ", "特殊球", "全能综合"]
        )
        XCTAssertEqual(
            ids.map(PlanCoverLabel.displayText(for:)),
            ["入门", "杆法", "准度", "控力", "分离角", "加塞", "走位Ⅰ",
             "走位Ⅱ", "准度Ⅱ", "准度Ⅲ", "特殊球", "全能\n综合"]
        )
    }

    func testPlanStylesDoNotReusePracticePairTops() {
        let practiceTops = Set(CoverPalette.allPracticePairs.map { colorKey($0.top) })
        for key in CoverPalette.planLevelKeys {
            let top = colorKey(CoverPalette.PlanStyle.forLevel(key).top)
            XCTAssertFalse(
                practiceTops.contains(top),
                "plan \(key) must not borrow a practice-zone top color"
            )
        }
    }

    private func colorKey(_ color: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%.3f-%.3f-%.3f", r, g, b)
    }

    private func glyphKey(_ color: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%.3f-%.3f-%.3f-%.2f", r, g, b, a)
    }
}
