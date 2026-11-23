import XCTest
import SceneKit
@testable import QiuJi

/// DR-296 (2026-09-14): 3D assist visuals + 2D zoom/pan + 2D/3D orientation parity.
/// Coordinate contract: SceneKit world, X = long axis (+X = head/break-line end), Z = short axis,
/// Y up, metres. Rotated 2D: screen-up = +X, screen-right = +Z. Landscape 2D: screen-right = +X,
/// screen-down = +Z.
@MainActor
final class TableAssistDR296Tests: XCTestCase {

    private func makeRig() -> CameraRig {
        let cam = SCNNode(); cam.camera = SCNCamera()
        return CameraRig(cameraNode: cam, tableSurfaceY: 0)
    }

    // MARK: 2D zoom / pan

    func testFitIsMinimumAndZoomIsClampedToRange() {
        let rig = makeRig()
        let view = CGSize(width: 402, height: 700)
        rig.fitRotatedTable(viewSize: view)
        let fit = rig.topDownOrthographicScale
        rig.applyTopDownZoom(factor: 0.5, focalOffset: .zero, viewSize: view, rotated: true)
        XCTAssertEqual(rig.topDownOrthographicScale, fit, accuracy: 1e-9, "cannot shrink below the fit")
        XCTAssertEqual(rig.topDownPanOffset, .zero)
        rig.applyTopDownZoom(factor: 100, focalOffset: .zero, viewSize: view, rotated: true)
        XCTAssertEqual(rig.topDownOrthographicScale, fit / CameraRig.topDownMaxZoom, accuracy: 1e-9)
        // A per-frame re-fit (auto-fit pages) must keep the user's zoom.
        rig.fitRotatedTable(viewSize: view)
        XCTAssertEqual(rig.topDownOrthographicScale, fit / CameraRig.topDownMaxZoom, accuracy: 1e-9)
        rig.resetTopDownZoom()
        XCTAssertEqual(rig.topDownOrthographicScale, fit, accuracy: 1e-9)
        XCTAssertEqual(rig.topDownPanOffset, .zero)
    }

    func testManualScalePageTreatsCurrentScaleAsMinimum() {
        let rig = makeRig()
        rig.topDownOrthographicScale = 1.5
        let view = CGSize(width: 402, height: 700)
        rig.applyTopDownZoom(factor: 0.3, focalOffset: .zero, viewSize: view, rotated: true)
        XCTAssertEqual(rig.topDownOrthographicScale, 1.5, accuracy: 1e-9)
        rig.applyTopDownZoom(factor: 2, focalOffset: .zero, viewSize: view, rotated: true)
        XCTAssertEqual(rig.topDownOrthographicScale, 0.75, accuracy: 1e-9)
    }

    /// The world point under the pinch centre must not move.
    func testAnchoredZoomKeepsFocalWorldPointFixed() {
        for rotated in [true, false] {
            let rig = makeRig()
            let view = rotated ? CGSize(width: 402, height: 700) : CGSize(width: 700, height: 402)
            if rotated { rig.fitRotatedTable(viewSize: view) } else { rig.fitLandscapeTable(viewSize: view) }
            func world(_ focal: CGPoint) -> (x: Double, z: Double) {
                let k = 2 * rig.topDownOrthographicScale / Double(view.height)
                let pan = rig.topDownPanOffset
                return rotated
                    ? (Double(pan.x) - Double(focal.y) * k, Double(pan.y) + Double(focal.x) * k)
                    : (Double(pan.x) + Double(focal.x) * k, Double(pan.y) + Double(focal.y) * k)
            }
            let focal = CGPoint(x: 60, y: -120)
            let before = world(focal)
            rig.applyTopDownZoom(factor: 1.6, focalOffset: focal, viewSize: view, rotated: rotated)
            let after = world(focal)
            // Only exact when the clamp does not bite (60/120 pt at 1.6× stays inside the table).
            XCTAssertEqual(after.x, before.x, accuracy: 1e-6, "rotated=\(rotated)")
            XCTAssertEqual(after.z, before.z, accuracy: 1e-6, "rotated=\(rotated)")
        }
    }

    /// Dragging the finger right must move the content right: rotated screen-right = +Z
    /// (camera moves −Z), landscape screen-right = +X (camera moves −X).
    func testScreenPanFollowsFingerPerMode() {
        let view = CGSize(width: 402, height: 700)
        let rotated = makeRig()
        rotated.fitRotatedTable(viewSize: view)
        rotated.applyTopDownZoom(factor: 3, focalOffset: .zero, viewSize: view, rotated: true)
        rotated.applyTopDownScreenPan(dx: 50, dy: 0, viewSize: view, rotated: true)
        XCTAssertLessThan(rotated.topDownPanOffset.y, 0)
        XCTAssertEqual(rotated.topDownPanOffset.x, 0, accuracy: 1e-9)
        rotated.applyTopDownScreenPan(dx: 0, dy: 50, viewSize: view, rotated: true)
        XCTAssertGreaterThan(rotated.topDownPanOffset.x, 0, "finger down ⇒ camera toward screen-up = +X")

        let landscape = makeRig()
        landscape.fitLandscapeTable(viewSize: CGSize(width: 700, height: 402))
        landscape.applyTopDownZoom(factor: 3, focalOffset: .zero, viewSize: CGSize(width: 700, height: 402), rotated: false)
        landscape.applyTopDownScreenPan(dx: 50, dy: 0, viewSize: CGSize(width: 700, height: 402), rotated: false)
        XCTAssertLessThan(landscape.topDownPanOffset.x, 0)
        XCTAssertEqual(landscape.topDownPanOffset.y, 0, accuracy: 1e-9)
    }

    func testPanIsClampedToTableEdgeAndZeroAtFit() {
        let rig = makeRig()
        let view = CGSize(width: 402, height: 700)
        rig.fitRotatedTable(viewSize: view)
        rig.applyTopDownScreenPan(dx: 500, dy: 500, viewSize: view, rotated: true)
        XCTAssertEqual(rig.topDownPanOffset, .zero, "whole table visible ⇒ nothing to pan to")
        rig.applyTopDownZoom(factor: 2, focalOffset: .zero, viewSize: view, rotated: true)
        rig.applyTopDownScreenPan(dx: 0, dy: 100_000, viewSize: view, rotated: true)
        let maxX = rig.tableOuterHalfLength - rig.topDownOrthographicScale
        XCTAssertEqual(Double(rig.topDownPanOffset.x), maxX, accuracy: 1e-9)
        rig.applyTopDownScreenPan(dx: -100_000, dy: 0, viewSize: view, rotated: true)
        let maxZ = max(0, rig.tableOuterHalfWidth - rig.topDownOrthographicScale * Double(view.width / view.height))
        XCTAssertEqual(Double(rig.topDownPanOffset.y), maxZ, accuracy: 1e-9)
    }

    // MARK: 2D / 3D orientation

    /// 3D overview looks from the −X (foot) end so +X (head string) is far/up like rotated 2D.
    func testOverviewCameraSitsOnFootSideLookingTowardHead() {
        let cam = SCNNode(); cam.camera = SCNCamera()
        let rig = CameraRig(cameraNode: cam, tableSurfaceY: 0)
        rig.viewportSize = CGSize(width: 402, height: 700)
        XCTAssertTrue(rig.observeWholeTable())
        rig.snapToTarget()
        XCTAssertLessThan(cam.position.x, -0.5, "camera on −X side")
        let forward = cam.simdWorldFront
        XCTAssertGreaterThan(forward.x, 0.5, "looking toward +X")
        // Default heading at init is the same.
        XCTAssertEqual(CameraRig.overviewYaw, .pi)
    }

    // MARK: Cue strike point

    func testStrikePositionAppliesVerticalSpin() {
        let cue = SCNVector3(0, 1, 0), aim = SCNVector3(1, 0, 0)
        let r = AngleSceneCalculator.ballRadius
        let high = CueStroke.strikePosition(cue: cue, aim: aim, spinX: 0, spinY: 0.5)
        XCTAssertEqual(high.y, 1 + 0.5 * r, accuracy: 1e-6)
        XCTAssertEqual(high.x, 0, accuracy: 1e-6); XCTAssertEqual(high.z, 0, accuracy: 1e-6)
        let low = CueStroke.strikePosition(cue: cue, aim: aim, spinX: 0, spinY: -0.5)
        XCTAssertEqual(low.y, 1 - 0.5 * r, accuracy: 1e-6)
        // Default keeps the legacy centre-height contract.
        XCTAssertEqual(CueStroke.strikePosition(cue: cue, aim: aim, spinX: 0.4).y, 1, accuracy: 1e-6)
    }

    func testTipInsetFollowsSphereSurface() throws {
        let r = AngleSceneCalculator.ballRadius
        XCTAssertEqual(CueStroke.tipInset(spinX: 0, spinY: 0), 0, accuracy: 1e-7)
        XCTAssertEqual(CueStroke.tipInset(spinX: 0.6, spinY: 0), r * (1 - 0.8), accuracy: 1e-6)
        XCTAssertEqual(CueStroke.tipInset(spinX: 1, spinY: 1), r, accuracy: 1e-6, "clamped at the equator")
        let scene = AngleTrainingScene(); scene.setupScene()
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        scene.applyBallLayout(cueBallPosition: SCNVector3(-0.5, y, 0), targetBallNumber: 1, targetPosition: SCNVector3(0.3, y, 0))
        let cue = try XCTUnwrap(scene.cueBallNode)
        XCTAssertFalse(cue.isHidden)
        let strike = CueStroke.strikePosition(cue: cue.position, aim: SCNVector3(1, 0, 0), spinX: 0, spinY: 0.6)
        XCTAssertEqual(try XCTUnwrap(scene.cueTipInset(forStrike: strike)), CueStroke.tipInset(spinX: 0, spinY: 0.6), accuracy: 1e-6)
        XCTAssertNil(scene.cueTipInset(forStrike: SCNVector3(cue.position.x + 1, cue.position.y, cue.position.z)))
    }

    // MARK: Ghost ring on the cloth, merged dashes

    func testGhostRingDashesLieOnClothNotAtBallCentre() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        scene.setupVisualizationNodes()
        let ghost = try XCTUnwrap(scene.ghostBallNode)
        let dashes = ghost.childNodes.filter { $0.geometry is SCNCylinder }
        XCTAssertFalse(dashes.isEmpty)
        for dash in dashes {
            // Ghost node sits at centre height; dash bottom must touch (not sink below) the cloth.
            let bottom = dash.position.y - TrajectoryStyle.lineHint
            XCTAssertEqual(bottom, -AngleSceneCalculator.ballRadius + 0.0005, accuracy: 1e-6)
        }
        // The ghost-centre red dot rests on the cloth too (same X/Z as the centre).
        let dot = try XCTUnwrap(ghost.childNode(withName: "ghostAimDot", recursively: false))
        let dotRadius = Float(try XCTUnwrap(dot.geometry as? SCNSphere).radius)
        XCTAssertEqual(dot.position.y - dotRadius, -AngleSceneCalculator.ballRadius + 0.0005, accuracy: 1e-6)
        XCTAssertEqual(dot.position.x, 0); XCTAssertEqual(dot.position.z, 0)
    }

    func testTableDashedPolylineIsOneMergedGeometry() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        var nodes: [SCNNode] = []
        scene.addDashedPolyline([SCNVector3(-0.8, y, 0.2), SCNVector3(0.3, y, -0.3), SCNVector3(0.9, y, 0.4)],
                                color: .white, placement: .table, into: &nodes)
        XCTAssertEqual(nodes.count, 1, "all dashes of one polyline share one node")
        let vertices = try XCTUnwrap(nodes[0].geometry?.sources(for: .vertex).first)
        let period = TrajectoryStyle.mainDash + TrajectoryStyle.mainGap
        let length = hypotf(1.1, 0.5) + hypotf(0.6, 0.7)
        // ≥ 2 triangles (6 vertices) per dash; count dashes rather than exact vertex count.
        XCTAssertGreaterThanOrEqual(vertices.vectorCount, Int(length / period) * 6)
        let single = scene.addDashedLine(from: SCNVector3(-0.5, y, 0), to: SCNVector3(0.5, y, 0), color: .white, placement: .table)
        XCTAssertEqual(single.childNodes.filter { $0.geometry != nil }.count, 1)
        // Dash rhythm: denser than the pre-DR-296 values.
        XCTAssertLessThanOrEqual(period, 0.032 + 1e-6)
        XCTAssertLessThanOrEqual(TrajectoryStyle.hintDash + TrajectoryStyle.hintGap, 0.024 + 1e-6)
    }
}
