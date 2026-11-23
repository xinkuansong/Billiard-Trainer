import XCTest
import SwiftUI
@testable import QiuJi

/// v14 B1：轻量编译引用——证明学页壳 / 控件条公开 API 进入 app target。
final class LearnDocChromeCompileTests: XCTestCase {

    func testLearnDocTextDefaults() {
        XCTAssertEqual(LearnDocText.bodyLineSpacing, 5, accuracy: 0.001)
    }

    func testLearnControlStripThetaDefaults() {
        XCTAssertEqual(LearnControlStrip.Theta.defaultRange.lowerBound, 5, accuracy: 0.001)
        XCTAssertEqual(LearnControlStrip.Theta.defaultRange.upperBound, 75, accuracy: 0.001)
        XCTAssertEqual(LearnControlStrip.Theta.defaultStep, 1, accuracy: 0.001)
    }

    func testLearnControlStripSpinXReadout() {
        XCTAssertEqual(LearnControlStrip.LiveAxes.defaultSpinXReadout(0), "中塞 0")
        XCTAssertTrue(LearnControlStrip.LiveAxes.defaultSpinXReadout(0.12).contains("左塞"))
        XCTAssertTrue(LearnControlStrip.LiveAxes.defaultSpinXReadout(-0.12).contains("右塞"))
    }

    @MainActor
    func testSectionCardAndStripsAreViews() {
        // 编译期引用公开类型；运行时仅确认非空包装可构造。
        let card = LearnDocSectionCard(title: "T") {
            LearnDocText.body("body")
            LearnDocText.footnote("note")
        }
        let formula = LearnDocFormulaNest(title: "速查") {
            LearnDocText.footnote("d = 2R·sin(θ)")
        }
        let theta = LearnControlStrip.Theta(cutAngleDeg: .constant(30))
        let axes = LearnControlStrip.LiveAxes(
            velocity: .constant(ShotTuning.defaultVelocity),
            spinYTier: .constant(.mid),
            spinX: .constant(0),
            spinXRange: -0.5...0.5
        )
        let row = LearnControlStrip.ReadoutRow(label: "角", value: "30°")
        XCTAssertNotNil(card)
        XCTAssertNotNil(formula)
        XCTAssertNotNil(theta)
        XCTAssertNotNil(axes)
        XCTAssertNotNil(row)
    }
}
