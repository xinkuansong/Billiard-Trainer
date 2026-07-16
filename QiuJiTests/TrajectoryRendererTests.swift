import XCTest
import SceneKit
@testable import QiuJi

/// W8 helpers: TrajectoryRenderer options, SceneStroke constants, pulse/spin/palette.
final class TrajectoryRendererTests: XCTestCase {

    func testPositionPlayOptionsExpressFullSemantics() {
        let o = TrajectoryRenderer.Options.positionPlay
        XCTAssertTrue(o.includeObjectPath)
        XCTAssertTrue(o.extendToPocketRim)
        XCTAssertEqual(o.ghostSource, .ghost)
        XCTAssertEqual(o.extraBallMode, .fullOnly)
        XCTAssertFalse(o.requireVisibleTargetForGhost)
    }

    func testSnookerDefenseOptionsExpressDefenseSemantics() {
        let o = TrajectoryRenderer.Options.snookerDefense
        XCTAssertFalse(o.includeObjectPath, "D2: snooker defense omits objectPath")
        XCTAssertFalse(o.extendToPocketRim)
        XCTAssertEqual(o.ghostSource, .firstContact)
        XCTAssertEqual(o.extraBallMode, .coreTargetAndFull)
        XCTAssertTrue(o.requireVisibleTargetForGhost)
    }

    func testSceneStrokeConstantsMatchPriorCopies() {
        XCTAssertEqual(SceneStroke.circleSegments, 36)
        XCTAssertEqual(SceneStroke.lineRadius, 0.0022, accuracy: 1e-6)
    }

    func testConstraintCyanSingleDefinition() {
        let c = BTScenePalette.constraintCyan
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        XCTAssertEqual(r, 0.2, accuracy: 1e-3)
        XCTAssertEqual(g, 0.85, accuracy: 1e-3)
        XCTAssertEqual(b, 0.95, accuracy: 1e-3)
        XCTAssertEqual(a, 0.95, accuracy: 1e-3)
    }

    func testShotSpinLabelCenterAndCombinations() {
        XCTAssertEqual(ShotSpinLabel.text(spinX: 0, spinY: 0), "中心球")
        let lim = Double(CuePhysics.miscueLimitFraction)
        XCTAssertEqual(ShotSpinLabel.text(spinX: 0, spinY: lim * 0.5), "高杆")
        XCTAssertEqual(ShotSpinLabel.text(spinX: lim * 0.5, spinY: 0), "左塞")
        XCTAssertEqual(ShotSpinLabel.text(spinX: -lim * 0.5, spinY: -lim * 0.5), "低杆右塞")
    }

    func testTableBallPulseActionKey() {
        XCTAssertEqual(TableBallPulse.actionKey, "libraryPulse")
        let node = SCNNode()
        node.scale = SCNVector3(1, 1, 1)
        TableBallPulse.pulse(node)
        XCTAssertNotNil(node.action(forKey: TableBallPulse.actionKey))
    }
}