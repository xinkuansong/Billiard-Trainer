//
//  BallFogDiagTests.swift
//  QiuJiTests
//
//  渲染打磨诊断（球面"发雾"问题）：用真实 AngleTrainingScene 离屏渲染球的特写，
//  分别覆盖 plain 顶视（2D 页）与 enhanced 透视（3D 瞄准页）两条管线，供改材质
//  参数（roughness / clearcoat / 母球 diffuseOverride）前后肉眼对比。
//
//  运行：
//    xcodebuild test -scheme QiuJi \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//      -only-testing:QiuJiTests/BallFogDiagTests
//
//  输出：build/ball_fog/scene_2d.png、scene_3d.png
//

import XCTest
import SceneKit
import UIKit
@testable import QiuJi

final class BallFogDiagTests: XCTestCase {

    private let outputDir = "/Users/song/projects/13.billiard_trainer/build/ball_fog"

    @MainActor
    func test_table_vertical_extent_diag() throws {
        let s = AngleTrainingScene()
        s.setupScene(enhancedRendering: true)
        guard let table = s.tableNode else { return XCTFail("no table") }
        let (bbMin, bbMax) = table.boundingBox
        let sc = table.scale.y
        let posY = table.position.y
        let worldMinY = bbMin.y * sc + posY
        let worldMaxY = bbMax.y * sc + posY
        let groundNode = s.rootNode.childNode(withName: "ground_visual", recursively: true)
        print("TABLEDIAG surfaceY=\(s.surfaceY) groundLevelY=\(BTSceneLayout.groundLevelY)")
        print("TABLEDIAG bbMin.y=\(bbMin.y) bbMax.y=\(bbMax.y) scaleY=\(sc) posY=\(posY)")
        print("TABLEDIAG worldMinY(legBottom)=\(worldMinY) worldMaxY(railTop)=\(worldMaxY) heightWorld=\(worldMaxY - worldMinY)")
        print("TABLEDIAG groundPlaneY=\(groundNode?.position.y ?? -999) legsBelowGround=\(worldMinY < (groundNode?.position.y ?? 0))")
    }

    @MainActor
    func test_render_grounding_oblique() throws {
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("no metal device") }
        let r = AngleSceneCalculator.ballRadius

        let s = AngleTrainingScene()
        s.setupScene(enhancedRendering: true)
        let sy = s.surfaceY
        s.applyBallLayout(cueBallPosition: SCNVector3(-0.3, sy + r, 0.15),
                          targetBallNumber: 8, targetPosition: SCNVector3(0.2, sy + r, -0.1))
        s.hideCueStick()

        // 近似出片斜视角：短边后方、抬高俯视，看全桌 + 桌底 + 地板/接地阴影。
        let halfL = AngleSceneCalculator.innerLength / 2
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 48
        cam.camera?.zNear = 0.01
        cam.camera?.zFar = 100
        cam.position = SCNVector3(-(halfL + 1.05), sy + 0.95, 0)
        cam.look(at: SCNVector3(0.05, sy - 0.05, 0))
        s.rootNode.addChildNode(cam)

        let img = snapshot(scene: s, cam: cam, device: device, size: CGSize(width: 720, height: 1280))
        write(img, "grounding_3d.png")
    }

    /// 加塞杆头平移手性：spinX 正 = 左塞 ⇒ 杆头在 −right 侧（right = aim×ŷ = rightOfXZ）。
    /// 左塞挤偏向 right，杆头必须在其对侧；portrait 旋转顶视 aim=+X（屏上）时即屏左（−Z）。
    func test_cue_strikePosition_leftEnglish_oppositeSquirtSide() {
        let r = AngleSceneCalculator.ballRadius
        let cue = SCNVector3(0, 0, 0)

        // aim=+Z：rightOfXZ = −X；左塞杆头 → +X（对侧）
        let aimZ = SCNVector3(0, 0, 1)
        let leftZ = CueStroke.strikePosition(cue: cue, aim: aimZ, spinX: 0.3)
        XCTAssertGreaterThan(leftZ.x, 0, "左塞杆头应在 −right 侧（aim=+Z → +X），got x=\(leftZ.x)")
        XCTAssertEqual(leftZ.x, 0.3 * r, accuracy: 1e-6)
        XCTAssertEqual(leftZ.z, 0, accuracy: 1e-6)

        // aim=+X（旋转顶视「朝屏上」）：rightOfXZ = +Z；左塞杆头 → −Z（屏左）
        let aimX = SCNVector3(1, 0, 0)
        let leftX = CueStroke.strikePosition(cue: cue, aim: aimX, spinX: 0.3)
        XCTAssertLessThan(leftX.z, 0, "左塞杆头应在 −right 侧（aim=+X → −Z / 屏左），got z=\(leftX.z)")
        XCTAssertEqual(leftX.z, -0.3 * r, accuracy: 1e-6)
        XCTAssertEqual(leftX.x, 0, accuracy: 1e-6)

        // 右塞对称
        let rightX = CueStroke.strikePosition(cue: cue, aim: aimX, spinX: -0.3)
        XCTAssertGreaterThan(rightX.z, 0, "右塞应向 +Z（屏右）")
    }

    /// 跟杆运动学：终点 `pullBack ≈ −3R`（杆头越过母球原中心约一颗球 +2R）、
    /// 送杆曲线从 0 单调向前到终点且全程减速（ease-out），停留 0.5s。
    @MainActor
    func test_cue_follow_through_kinematics() {
        let r = AngleSceneCalculator.ballRadius
        XCTAssertEqual(CueStroke.followThroughPull, -3 * r, accuracy: 1e-6)
        XCTAssertEqual(CueStroke.followThrough(at: 0), 0, accuracy: 1e-6)
        XCTAssertEqual(CueStroke.followThrough(at: CueStroke.followThroughDuration),
                       CueStroke.followThroughPull, accuracy: 1e-6)
        XCTAssertEqual(CueStroke.followThroughHold, 1.5, accuracy: 1e-6)

        // 杆头世界位置（pullBack 沿瞄准方向）：tipOffset = (R + 0.001) + pullBack，
        // 杆头 = 中心 − tipOffset·aim。终点 pullBack = −3R ⇒ 杆头落在 中心 + (2R − 0.001)·aim。
        let tipPast = -((r + 0.001) + CueStroke.followThroughPull)   // 杆头相对中心、沿 aim 的前移量
        XCTAssertEqual(tipPast, 2 * r - 0.001, accuracy: 1e-6)
        XCTAssertGreaterThan(tipPast, 2 * r - 0.01, "杆头停点应约一颗球（2R）越过母球原中心")

        // 减速：相邻等步长样本的位移（≈瞬时速度）应非增。
        let dur = CueStroke.followThroughDuration
        var prev: Float = 0
        var prevStep = Float.greatestFiniteMagnitude
        for i in 1...20 {
            let p = CueStroke.followThrough(at: dur * Double(i) / 20)
            XCTAssertLessThanOrEqual(p, prev + 1e-6, "送杆量应单调向前（更负）")
            let step = abs(p - prev)
            XCTAssertLessThanOrEqual(step, prevStep + 1e-4, "应减速：每步位移不增")
            prevStep = step; prev = p
        }
    }

    /// 渲染触球瞬间（pull=0）与跟杆停点两帧，肉眼核对杆头是否越过母球中心约一颗球。
    /// 输出：build/ball_fog/cue_contact.png、cue_follow_through.png
    @MainActor
    func test_render_cue_follow_through() throws {
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("no metal device") }
        let r = AngleSceneCalculator.ballRadius

        let s = AngleTrainingScene()
        s.setupScene(enhancedRendering: true)
        let sy = s.surfaceY
        let cue = SCNVector3(0, sy + r, 0)
        // 目标球放远（+X 方向作参照，不与杆头停点重叠）。
        s.applyBallLayout(cueBallPosition: cue, targetBallNumber: 8,
                          targetPosition: SCNVector3(0.45, sy + r, 0))
        let aim = SCNVector3(1, 0, 0)   // 朝 +X

        // 正交俯视、对准母球：屏幕上能直接看到杆头相对球心的前移量。
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.usesOrthographicProjection = true
        cam.camera?.orthographicScale = 0.16
        cam.camera?.zNear = 0.01
        cam.camera?.zFar = 100
        cam.position = SCNVector3(cue.x, sy + 1.2, cue.z)
        cam.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)   // 俯视 -Y
        s.rootNode.addChildNode(cam)

        s.updateCueStick(cueBallPosition: cue, aimDirection: aim, pullBack: 0)
        write(snapshot(scene: s, cam: cam, device: device, size: CGSize(width: 720, height: 720)),
              "cue_contact.png")

        s.updateCueStick(cueBallPosition: cue, aimDirection: aim, pullBack: CueStroke.followThroughPull)
        write(snapshot(scene: s, cam: cam, device: device, size: CGSize(width: 720, height: 720)),
              "cue_follow_through.png")
    }

    @MainActor
    func test_render_fog_comparison() throws {
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("no metal device")
        }
        let r = AngleSceneCalculator.ballRadius

        // ───────── 2D：plain 管线，正交顶视 ─────────
        let s2d = AngleTrainingScene()
        s2d.setupScene(enhancedRendering: false)
        XCTAssertNotNil(s2d.cameraNode)
        let sy2 = s2d.surfaceY
        s2d.hideAllBalls()
        s2d.hideCueStick()
        s2d.showBall(key: "cueBall", scenePosition: SCNVector3(-0.16, sy2 + r, -0.12))
        s2d.showBall(key: "_2", scenePosition: SCNVector3(0.06, sy2 + r, 0.00))
        s2d.showBall(key: "_3", scenePosition: SCNVector3(0.26, sy2 + r, 0.13))
        // 顶视真实球偏小 → 放大可见球节点，便于肉眼核对球面质感（仅视觉缩放）。
        for (_, n) in s2d.visibleBalls() {
            n.scale = SCNVector3(n.scale.x * 2.4, n.scale.y * 2.4, n.scale.z * 2.4)
        }
        if let rig = s2d.cameraRig {
            rig.topDownOrthographicScale = 0.34
            rig.topDownPanOffset = .zero
            rig.applyTopDown2DRotated()
        }
        let img2d = snapshot(scene: s2d, cam: s2d.cameraNode, device: device,
                             size: CGSize(width: 640, height: 960))
        write(img2d, "scene_2d.png")

        // ───────── 3D：enhanced 管线，瞄准位姿 ─────────
        let s3d = AngleTrainingScene()
        s3d.setupScene(enhancedRendering: true)
        XCTAssertNotNil(s3d.cameraNode)
        let sy3 = s3d.surfaceY
        let cue = SCNVector3(0.0, sy3 + r, 0.22)
        let tgt = SCNVector3(0.0, sy3 + r, -0.18)
        s3d.applyBallLayout(cueBallPosition: cue, targetBallNumber: 8, targetPosition: tgt)
        s3d.hideCueStick()
        // 放大球节点让母球在 aim 位姿下更大，便于核对"磨砂膜"与母球清洁效果（仅视觉缩放）。
        for (_, n) in s3d.visibleBalls() {
            n.scale = SCNVector3(n.scale.x * 1.9, n.scale.y * 1.9, n.scale.z * 1.9)
        }
        // cue→target 方向 = -Z；瞄准相机落在 cue 后方俯视这条线。
        if let rig = s3d.cameraRig {
            rig.enterAiming(cueBallPosition: cue, targetDirection: SCNVector3(0, 0, -1))
            rig.update(deltaTime: 1.0)   // 一步完成 smoothToPose → 落到 aim pose
        }
        let img3d = snapshot(scene: s3d, cam: s3d.cameraNode, device: device,
                             size: CGSize(width: 640, height: 960))
        write(img3d, "scene_3d.png")
    }

    @MainActor
    private func snapshot(scene: SCNScene, cam: SCNNode?, device: MTLDevice, size: CGSize) -> UIImage {
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = cam
        renderer.autoenablesDefaultLighting = false
        return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
    }

    private func write(_ img: UIImage, _ name: String) {
        guard let png = img.pngData() else {
            XCTFail("png encode failed: \(name)")
            return
        }
        try? png.write(to: URL(fileURLWithPath: outputDir + "/" + name))
        print("BALLFOG wrote \(outputDir)/\(name) \(Int(img.size.width))x\(Int(img.size.height)) bytes=\(png.count)")
    }
}
