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

    private func colorKey(_ color: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%.3f-%.3f-%.3f", r, g, b)
    }
}
