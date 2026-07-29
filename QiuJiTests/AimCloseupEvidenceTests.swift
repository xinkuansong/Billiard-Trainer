import SceneKit
import SwiftUI
import XCTest
@testable import QiuJi

/// Visual evidence for the aim-closeup fixes (UR-20260728 / 问题集合 v23 W1):
/// composites the loupe over the **same** plain-pipeline rotated top-down render
/// the 2D aim page uses, at the corner the placement rule picks, from the same
/// user geometry the scene draws. Lets line angles, fill colour and corner be
/// checked side by side without a device.
@MainActor
final class AimCloseupEvidenceTests: XCTestCase {

    /// Host path (simulator CWD is `/`) — same convention as `SpinExportParityTests`.
    private let outputDir = "/Users/song/projects/13.billiard_trainer"
        + "/build/v23-evidence/w1-position-color"

    func test_writeCompositeEvidence() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("无 Metal 设备") }
        let size = CGSize(width: 470, height: 900)

        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        scene.setupVisualizationNodes()
        let rig = try XCTUnwrap(scene.cameraRig)
        scene.hideAllBalls()
        scene.hideCueStick()

        let surfaceY = scene.surfaceY
        let r = AngleSceneCalculator.ballRadius
        let y = surfaceY + r
        // Screenshot-like pose: object ball high (screen-up = +X) and just right
        // of the centre line, cue ball below it.
        let target = SCNVector3(0.79, surfaceY, 0.06)
        let cue = SCNVector3(0.05, surfaceY, -0.16)
        scene.applyBallLayout(cueBallPosition: cue, targetBallNumber: 3,
                              targetPosition: target)

        // Aim just thin of centre so the closeup is in its contact band.
        let straight = normalizedXZ(from: cue, to: target)
        let aimDir = rotatedXZ(straight, byDegrees: 1.6)

        // Pocket = top-trailing on screen (max +X, max +Z).
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        let pocketIndex = try XCTUnwrap(pockets.indices.max {
            (pockets[$0].x + pockets[$0].z) < (pockets[$1].x + pockets[$1].z)
        })
        let potEnd = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target, pocketIndex: pocketIndex, surfaceY: surfaceY)

        // Scene lines — same calls as `AimPointSceneQuizViewModel.redrawLines`.
        _ = scene.addDashedLine(from: SCNVector3(target.x, y, target.z),
                                to: SCNVector3(potEnd.x, y, potEnd.z),
                                color: TrajectoryStyle.potColor(forNumber: 3))
        let n = SCNVector3(-aimDir.z, 0, aimDir.x)
        let auxHalf = r * 7
        _ = scene.addDashedLine(
            from: SCNVector3(target.x - n.x * auxHalf, y, target.z - n.z * auxHalf),
            to: SCNVector3(target.x + n.x * auxHalf, y, target.z + n.z * auxHalf),
            color: TrajectoryStyle.hintColor, radius: 0.0016, dash: 0.018, gap: 0.014)
        let railEnd = AngleSceneCalculator.rayToInnerRail(from: cue, dir: aimDir)
        let res = AimLineGeometry.resolve(
            cue: xz(cue), dir: xz(aimDir), target: xz(target),
            ballRadius: CGFloat(r), railEnd: xz(railEnd))
        _ = scene.addLine(from: SCNVector3(cue.x, y, cue.z),
                          to: SCNVector3(Float(res.lineEnd.x), y, Float(res.lineEnd.y)),
                          color: .white)
        if res.touchesBall {
            _ = scene.addAimPointMarker(
                at: SCNVector3(Float(res.aimPoint.x), y, Float(res.aimPoint.y)),
                color: TrajectoryStyle.aimPointColor)
            if let contact = res.contactPoint {
                _ = scene.addAimPointMarker(
                    at: SCNVector3(Float(contact.x), y, Float(contact.y)),
                    color: TrajectoryStyle.aimPointColor)
            }
        }
        XCTAssertTrue(res.touchesBall, "取景姿态应处于接触带，否则特写不该显示")

        rig.topDownPanOffset = .zero
        rig.fitRotatedTable(viewSize: size)
        rig.applyTopDown2DRotated()
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.autoenablesDefaultLighting = false
        let table = try XCTUnwrap(renderer.snapshot(atTime: 0, with: size,
                                                    antialiasingMode: .multisampling4X))

        // Loupe from the same geometry.
        let halfWorld = CGFloat(r) * 3.2
        let snapshot = AimCloseupSnapshot(
            band: .contact,
            focus: xz(target),
            ballRadius: CGFloat(r),
            halfWorld: halfWorld,
            showsTargetBall: true,
            targetBallNumber: 3,
            cue: nil,
            aimLine: AimCloseupSegment(start: xz(cue), end: res.lineEnd),
            potLine: AimCloseupSegment(start: xz(target), end: xz(potEnd)),
            auxLine: AimCloseupSegment(
                start: CGPoint(x: CGFloat(target.x - n.x * auxHalf),
                               y: CGFloat(target.z - n.z * auxHalf)),
                end: CGPoint(x: CGFloat(target.x + n.x * auxHalf),
                             y: CGFloat(target.z + n.z * auxHalf))),
            aimPointMarker: res.aimPoint,
            contactMarker: res.contactPoint)
        let diameter: CGFloat = 128
        let hudRenderer = ImageRenderer(content:
            BTAimCloseupHUD(snapshot: snapshot, diameter: diameter)
                .frame(width: diameter, height: diameter))
        hudRenderer.scale = 1
        let loupe = try XCTUnwrap(hudRenderer.uiImage)

        let focusNorm = AimCloseupPlacement.focusNormInRotatedTopDown(
            worldXZ: xz(target),
            halfLength: rig.tableOuterHalfLength,
            halfWidth: rig.tableOuterHalfWidth)
        let center = AimCloseupPlacement.center(
            focusNorm: focusNorm, sceneSize: size, diameter: diameter,
            safeInsets: .aimWheelPage, blockedSide: .leading, previous: nil)
        let focusPx = CGPoint(x: focusNorm.x * size.width, y: focusNorm.y * size.height)
        let sep = hypot(center.x - focusPx.x, center.y - focusPx.y)
        XCTAssertGreaterThanOrEqual(sep, diameter * 0.92 - 0.5,
                                    "特写圆心必须离开焦点球")
        XCTAssertGreaterThan(sep, diameter / 2 + 8,
                             "焦点须落在特写圆外")
        XCTAssertGreaterThan(center.x, focusPx.x, "轮在左侧 ⇒ 特写应在焦点右侧")
        // May sit beside (same y) or below-right — only the cover invariant matters.

        let originX = center.x - diameter / 2
        let originY = center.y - diameter / 2
        let composite = UIGraphicsImageRenderer(size: size).image { _ in
            table.draw(in: CGRect(origin: .zero, size: size))
            loupe.draw(in: CGRect(x: originX, y: originY,
                                  width: diameter, height: diameter))
        }

        try FileManager.default.createDirectory(atPath: outputDir,
                                                withIntermediateDirectories: true)
        let path = outputDir + "/composite.png"
        try XCTUnwrap(composite.pngData()).write(to: URL(fileURLWithPath: path))
        print("[evidence] \(path)")
    }

    // MARK: - Helpers

    private func xz(_ v: SCNVector3) -> CGPoint {
        CGPoint(x: CGFloat(v.x), y: CGFloat(v.z))
    }

    private func normalizedXZ(from a: SCNVector3, to b: SCNVector3) -> SCNVector3 {
        let dx = b.x - a.x, dz = b.z - a.z
        let len = sqrtf(dx * dx + dz * dz)
        return SCNVector3(dx / len, 0, dz / len)
    }

    private func rotatedXZ(_ v: SCNVector3, byDegrees deg: Float) -> SCNVector3 {
        let t = deg * .pi / 180
        return SCNVector3(v.x * cosf(t) - v.z * sinf(t), 0,
                          v.x * sinf(t) + v.z * cosf(t))
    }
}
