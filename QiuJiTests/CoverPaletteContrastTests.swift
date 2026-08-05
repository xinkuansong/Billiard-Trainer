import XCTest
import SwiftUI
@testable import QiuJi

/// v27 W2 返工：Constraint A（水印可辨）与分区阶梯不变量。
final class CoverPaletteContrastTests: XCTestCase {

    func testAllPracticeCoversMeetWatermarkLuminanceDelta() {
        let minDelta = CoverPalette.Glyph.minLuminanceDelta
        for (idx, pair) in CoverPalette.allPracticePairs.enumerated() {
            let delta = CoverPalette.Glyph.luminanceDelta(against: pair.top)
            XCTAssertGreaterThanOrEqual(
                delta,
                minDelta,
                "pair[\(idx)] watermark |ΔL|=\(delta) < \(minDelta)"
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

    func testSolveZoneStartsDarkEnoughForWhiteWatermark() {
        let L = CoverPalette.Glyph.relativeLuminance(of: CoverPalette.positionPlaySolver.top)
        // With white opacity 0.26: need L ≤ 1 − 0.14/0.26 ≈ 0.462; graphite start is ~0.10.
        XCTAssertLessThan(L, 0.20, "solve step0 must be mid-dark graphite, not light gray")
        let delta = CoverPalette.Glyph.luminanceDelta(against: CoverPalette.positionPlaySolver.top)
        XCTAssertGreaterThanOrEqual(delta, CoverPalette.Glyph.minLuminanceDelta)
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
            "plan_intermediate", "plan_advanced", "plan_fullskill",
        ]
        XCTAssertEqual(
            ids.map(PlanCoverLabel.text(for:)),
            ["入门", "杆法", "准度", "控力", "分离角", "加塞", "走位", "中级综合", "高级综合", "全能综合"]
        )
        XCTAssertEqual(
            ids.map(PlanCoverLabel.displayText(for:)),
            ["入门", "杆法", "准度", "控力", "分离角", "加塞", "走位", "中级\n综合", "高级\n综合", "全能\n综合"]
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
}
