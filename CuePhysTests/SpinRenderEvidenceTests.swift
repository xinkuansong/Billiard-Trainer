//
//  SpinRenderEvidenceTests.swift
//  QiuJiTests
//
//  问题集合 v17 W1 取证：球体自转的渲染可见性与旋向符号实证。
//
//  1. `test_dv174_pureYawSpin_visibility`（D-v17-4 停批闸门）：给母球施加**纯竖轴（ω_y）**
//     姿态序列，在三种取景下出图——App 真实 2D 顶视全台、顶视特写、3D 斜视——
//     用于人工判定「加塞自转肉眼是否可辨」。不可辨则停批回报，不得擅自改材质。
//  2. `test_spinSignEvidence_leftRightDraw`（W1 完成标准 4）：左塞 / 右塞 / 低杆各出一组
//     **真实物理回放**姿态序列，验证竖轴旋向左右相反、低杆段球面倒转。
//
//  运行：
//    xcodebuild test -scheme QiuJi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//      -only-testing:QiuJiTests/SpinRenderEvidenceTests
//

import XCTest
import UIKit
import SceneKit
import simd
@testable import QiuJi

final class SpinRenderEvidenceTests: XCTestCase {

    private let outputDir = "/Users/song/projects/13.billiard_trainer/build/v17-evidence"

    // MARK: - D-v17-4 可见性闸门

    @MainActor
    func test_dv174_pureYawSpin_visibility() throws {
        let dir = "\(outputDir)/dv174-visibility"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let rig = try makeRig()
        let ball = try XCTUnwrap(rig.scene.allBallNodes[PositionPlayBall.cueKey], "缺母球节点")

        // 纯 ω_y：绕世界 +Y 轴自转，8 档 45°。顶视下即「原地打转」。
        let steps = 8
        for i in 0..<steps {
            let yaw = Float(i) * 2 * .pi / Float(steps)
            ball.simdOrientation = simd_quatf(angle: yaw, axis: simd_float3(0, 1, 0))
            let tag = String(format: "yaw%03d", Int(yaw * 180 / .pi))

            rig.applyTopDown2DPortrait()
            try write(rig.snapshot(size: CGSize(width: 780, height: 1688)),
                      to: "\(dir)/topdown_full_\(tag).png")

            rig.applyTopDownCloseUp(on: ball)
            try write(rig.snapshot(size: CGSize(width: 512, height: 512)),
                      to: "\(dir)/topdown_zoom_\(tag).png")

            rig.applyPerspective(on: ball)
            try write(rig.snapshot(size: CGSize(width: 640, height: 480)),
                      to: "\(dir)/persp3d_\(tag).png")
        }

        // 倾斜基姿态对照：静止姿态恰好把红点摆在极点附近（纯 yaw 只让它原地转）。
        // 先绕世界 X 轴翻 90°（模拟球在一杆中途翻滚后的任意姿态），再扫 yaw，
        // 用于区分「贴图上半球本就没有可辨特征」与「恰好这一姿态不利」。
        let tiltDir = "\(dir)/tilted"
        try FileManager.default.createDirectory(atPath: tiltDir, withIntermediateDirectories: true)
        let tilt = simd_quatf(angle: .pi / 2, axis: simd_float3(1, 0, 0))
        // 45° 倾斜：母球是 6 点「麻点球」（±X/±Y/±Z 各一点），90° 翻转后仍有点落在极点，
        // 45° 才能让点离开极点——这才是「点不在极点」时的可辨性上界。
        let tilt45 = simd_quatf(angle: .pi / 4, axis: simd_float3(1, 0, 0))
        for i in 0..<steps {
            let yaw = Float(i) * 2 * .pi / Float(steps)
            let tag = String(format: "yaw%03d", Int(yaw * 180 / .pi))
            let spin = simd_quatf(angle: yaw, axis: simd_float3(0, 1, 0))
            ball.simdOrientation = spin * tilt
            rig.applyTopDownCloseUp(on: ball)
            try write(rig.snapshot(size: CGSize(width: 512, height: 512)),
                      to: "\(tiltDir)/topdown_zoom_\(tag).png")
            ball.simdOrientation = spin * tilt45
            rig.applyTopDownCloseUp(on: ball)
            try write(rig.snapshot(size: CGSize(width: 512, height: 512)),
                      to: "\(tiltDir)/tilt45_topdown_zoom_\(tag).png")
            rig.applyTopDown2DPortrait()
            let full = rig.snapshot(size: CGSize(width: 780, height: 1688))
            try write(full, to: "\(tiltDir)/tilt45_topdown_full_\(tag).png")
            // App 真实 2D 取景下球只有 ~14 px：裁球心 60×60 并**最近邻**放大 8×，
            // 保真呈现「真实上屏像素」，供人工判断这个尺寸能否看出自转。
            try write(try nearestNeighborCrop(full, side: 60, magnify: 8),
                      to: "\(tiltDir)/tilt45_appscale_crop_\(tag).png")
        }

        // 量化：三种取景各测「yaw 0 → 45°」的平均像素差，作为可辨性的客观参考。
        // 是否**肉眼**可辨仍须人工看图裁决（D-v17-4）。
        let framings: [(String, () -> Void, CGSize)] = [
            ("顶视全台(App 2D 真实尺寸)", { rig.applyTopDown2DPortrait() }, CGSize(width: 780, height: 1688)),
            ("顶视特写", { rig.applyTopDownCloseUp(on: ball) }, CGSize(width: 512, height: 512)),
            ("3D 斜视", { rig.applyPerspective(on: ball) }, CGSize(width: 640, height: 480))
        ]
        for (label, apply, size) in framings {
            for (poseName, base) in [("静止基姿态", simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))),
                                     ("倾斜基姿态", tilt)] {
                ball.simdOrientation = base
                apply()
                let a = try XCTUnwrap(rig.snapshot(size: size))
                ball.simdOrientation = simd_quatf(angle: .pi / 4, axis: simd_float3(0, 1, 0)) * base
                apply()
                let b = try XCTUnwrap(rig.snapshot(size: size))
                let diff = try meanAbsDifference(a, b)
                print(String(format: "📐 [v17] %@ / %@：yaw 0→45° 平均像素差 = %.3f/255", label, poseName, diff))
            }
        }
    }

    // MARK: - 旋向符号实证（W1 完成标准 4）

    /// 左塞 / 右塞 / 低杆各出一组**真实物理回放**姿态序列（顶视 + 3D），并量化断言旋向：
    /// 左右塞的竖轴分量 ω_y 必须反号；低杆开局球面必须倒转（ω 的滚动分量与位移反向）。
    @MainActor
    func test_spinSignEvidence_leftRightAndDraw() throws {
        let dir = "\(outputDir)/spin-sign"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // 打向 +X（顶视屏幕：世界 +X 为竖轴上方，见 CameraRig.applyTopDown2DRotated）。
        let aim = SCNVector3(1, 0, 0)
        let cases: [(name: String, spinX: Float, spinY: Float)] = [
            ("leftEnglish", 0.6, 0),    // 左塞（spinX > 0）
            ("rightEnglish", -0.6, 0),  // 右塞（spinX < 0）
            ("draw", 0, -0.6)           // 低杆（spinY < 0）
        ]

        var initialOmegaY: [String: Float] = [:]
        for c in cases {
            let rig = try makeRig()
            let ball = try XCTUnwrap(rig.scene.allBallNodes[PositionPlayBall.cueKey])
            let yLevel = rig.scene.surfaceY + AngleSceneCalculator.ballRadius
            let start = SCNVector3(-0.9, rig.scene.surfaceY, 0)
            let pred = ShotPredictor.simulateFree(
                cueBall: start, aimDir: aim, velocity: 1.6,
                spinX: c.spinX, spinY: c.spinY, surfaceY: rig.scene.surfaceY, balls: []
            )
            let recorder = try XCTUnwrap(pred.recorder, "\(c.name) 无 recorder")
            let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
            initialOmegaY[c.name] = playback.stateAt(ballName: ShotInput.cueBallName,
                                                     time: 0)?.angularVelocity.y ?? 0

            // 1× 实时（1/60 s 一张）：本档 ω≈76–84 rad/s ⇒ 每张之间转约 80°，
            //   能看出在转，但**方向须配合慢放判读**（方案 §〇 预告的频闪，D-v17-3 如实渲染）。
            // 0.25× 慢放（1/240 s 一张，等价 `action(speed: 0.25)`）：每张约 20°，旋向明确可判。
            try renderPoseSequence(rig: rig, ball: ball, playback: playback, yLevel: yLevel,
                                   step: 1.0 / 60, frames: 12, prefix: "\(dir)/\(c.name)_x1")
            try renderPoseSequence(rig: rig, ball: ball, playback: playback, yLevel: yLevel,
                                   step: 1.0 / 240, frames: 12, prefix: "\(dir)/\(c.name)_slowmo")

            print(String(format: "📐 [v17] %@：ω_y(0) = %.2f rad/s，回放 %.2fs",
                         c.name, initialOmegaY[c.name] ?? 0, playback.duration))
        }

        // 量化断言（防坐标系搞反）：左右塞竖轴旋向必须相反且量级相当。
        let left = try XCTUnwrap(initialOmegaY["leftEnglish"])
        let right = try XCTUnwrap(initialOmegaY["rightEnglish"])
        XCTAssertGreaterThan(abs(left), 1.0, "左塞应产生可观的竖轴角速度")
        XCTAssertLessThan(left * right, 0, "左塞与右塞的 ω_y 必须反号（左 \(left) / 右 \(right)）")
        XCTAssertEqual(abs(left), abs(right), accuracy: abs(left) * 0.05, "对称打点的 |ω_y| 应相当")
        // 低杆：无侧塞 ⇒ 竖轴分量应近零，倒旋体现在水平轴分量上。
        let draw = try XCTUnwrap(initialOmegaY["draw"])
        XCTAssertLessThan(abs(draw), 0.5, "纯低杆不应产生竖轴自转（实测 \(draw)）")
    }

    /// 低杆倒旋方向实证：打向 +X 时纯滚动的 ω 应为 (0,0,−v/R)；低杆开局 ω_z 必须**同号相反**
    /// （即 ω_z > 0，球面向后转），且随滑动摩擦逐步翻正到纯滚动值。
    func test_drawShot_surfaceSpinsBackwardBeforeRolling() throws {
        let surfaceY: Float = 0.8
        let pred = ShotPredictor.simulateFree(
            cueBall: SCNVector3(-0.9, surfaceY, 0), aimDir: SCNVector3(1, 0, 0),
            velocity: 1.6, spinX: 0, spinY: -0.6, surfaceY: surfaceY, balls: []
        )
        let recorder = try XCTUnwrap(pred.recorder)
        let playback = TrajectoryPlayback(recorder: recorder,
                                          surfaceY: surfaceY + AngleSceneCalculator.ballRadius)
        let s0 = try XCTUnwrap(playback.stateAt(ballName: ShotInput.cueBallName, time: 0))
        XCTAssertGreaterThan(s0.velocity.x, 0, "母球应向 +X 前进")
        XCTAssertGreaterThan(s0.angularVelocity.z, 0,
                             "低杆开局球面应倒转：+X 前进时纯滚动 ω_z<0，倒旋须 ω_z>0（实测 \(s0.angularVelocity.z)）")

        // 滑动摩擦把倒旋磨掉后转为纯滚动：末段 ω_z 应回到 −v/R 附近。
        var rollingChecked = false
        var t = playback.duration
        while t > 0 {
            if let s = playback.stateAt(ballName: ShotInput.cueBallName, time: t),
               s.motionState == .rolling, s.velocity.length() > 0.05 {
                let expected = -s.velocity.x / BallPhysics.radius
                XCTAssertEqual(s.angularVelocity.z, expected, accuracy: abs(expected) * 0.02,
                               "滚动段 ω_z 应等于 −v/R")
                rollingChecked = true
                break
            }
            t -= 0.02
        }
        XCTAssertTrue(rollingChecked, "未找到可校验的滚动段")
    }

    // MARK: - Helpers

    /// 从 t=0 起以 `step`（模拟秒）为步长积分姿态并逐步出图（顶视特写 + 3D 斜视）。
    /// 相机跟随球心，故画面里只剩自转，位移不干扰旋向判读。
    @MainActor
    private func renderPoseSequence(rig: EvidenceRig, ball: SCNNode, playback: TrajectoryPlayback,
                                    yLevel: Float, step: Float, frames: Int, prefix: String) throws {
        BallSpinIntegrator.resetPose(ball)
        var prevOmega = playback.stateAt(ballName: ShotInput.cueBallName, time: 0)?.angularVelocity
            ?? SCNVector3Zero
        for i in 0..<frames {
            let t = Float(i) * step
            if let s = playback.stateAt(ballName: ShotInput.cueBallName, time: t) {
                ball.position = SCNVector3(s.position.x, yLevel, s.position.z)
                if i > 0 {
                    BallSpinIntegrator.advance(node: ball, from: prevOmega,
                                               to: s.angularVelocity, dt: step)
                }
                prevOmega = s.angularVelocity
            }
            let tag = String(format: "%02d", i)
            rig.applyTopDownCloseUp(on: ball)
            try write(rig.snapshot(size: CGSize(width: 400, height: 400)), to: "\(prefix)_top_\(tag).png")
            rig.applyPerspective(on: ball)
            try write(rig.snapshot(size: CGSize(width: 480, height: 360)), to: "\(prefix)_3d_\(tag).png")
        }
    }

    private func write(_ image: UIImage?, to path: String) throws {
        let img = try XCTUnwrap(image, "渲染失败：\(path)")
        let data = try XCTUnwrap(img.pngData())
        try data.write(to: URL(fileURLWithPath: path))
    }

    /// 从图像中心裁 `side`×`side` 像素并以最近邻放大 `magnify` 倍（不引入插值柔化）。
    private func nearestNeighborCrop(_ image: UIImage?, side: Int, magnify: Int) throws -> UIImage {
        let cg = try XCTUnwrap(image?.cgImage)
        let rect = CGRect(x: (cg.width - side) / 2, y: (cg.height - side) / 2, width: side, height: side)
        let cropped = try XCTUnwrap(cg.cropping(to: rect))
        let out = side * magnify
        let ctx = try XCTUnwrap(CGContext(
            data: nil, width: out, height: out, bitsPerComponent: 8, bytesPerRow: out * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        ctx.interpolationQuality = .none
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: out, height: out))
        return UIImage(cgImage: try XCTUnwrap(ctx.makeImage()))
    }

    /// 两图平均逐像素 RGB 绝对差（0–255）。
    private func meanAbsDifference(_ a: UIImage, _ b: UIImage) throws -> Double {
        let pa = try rgbaBytes(a), pb = try rgbaBytes(b)
        XCTAssertEqual(pa.count, pb.count, "两图尺寸不一致")
        var sum = 0.0
        var count = 0
        for i in stride(from: 0, to: pa.count, by: 4) {
            for ch in 0..<3 {
                sum += abs(Double(pa[i + ch]) - Double(pb[i + ch]))
                count += 1
            }
        }
        return count > 0 ? sum / Double(count) : 0
    }

    private func rgbaBytes(_ image: UIImage) throws -> [UInt8] {
        let cg = try XCTUnwrap(image.cgImage)
        let w = cg.width, h = cg.height
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        try buffer.withUnsafeMutableBytes { raw in
            let ctx = try XCTUnwrap(CGContext(
                data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return buffer
    }

    @MainActor
    private func makeRig() throws -> EvidenceRig {
        let rig = try XCTUnwrap(EvidenceRig(), "无 Metal 设备或场景装载失败")
        return rig
    }

    /// 离屏取证台：一张真实球桌 + 母球 + 三种取景（App 2D 顶视全台 / 顶视特写 / 3D 斜视）。
    @MainActor
    private final class EvidenceRig {
        let scene: AngleTrainingScene
        private let renderer: SCNRenderer

        init?() {
            guard let device = MTLCreateSystemDefaultDevice() else { return nil }
            let scene = AngleTrainingScene()
            scene.setupScene(enhancedRendering: false)
            guard scene.cameraNode != nil else { return nil }
            scene.background.contents = UIColor.black
            scene.hideAllBalls()
            scene.hideCueStick()
            scene.showBall(key: PositionPlayBall.cueKey,
                           scenePosition: SCNVector3(0, scene.surfaceY, 0))

            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = scene
            renderer.pointOfView = scene.cameraNode
            renderer.autoenablesDefaultLighting = false

            self.scene = scene
            self.renderer = renderer
        }

        /// App 内 2D 球桌页同款取景（竖版整台自适应，ADR-P11-08）——球的**真实上屏尺寸**。
        func applyTopDown2DPortrait() {
            guard let rig = scene.cameraRig else { return }
            rig.topDownPanOffset = .zero
            rig.fitRotatedTable(viewSize: CGSize(width: 390, height: 844))
            rig.applyTopDown2DRotated()
        }

        /// 顶视特写（正交，视野约 ±3R）：证明贴图特征本身是否存在。
        func applyTopDownCloseUp(on ball: SCNNode) {
            guard let cam = scene.cameraNode?.camera, let node = scene.cameraNode else { return }
            cam.usesOrthographicProjection = true
            cam.orthographicScale = Double(AngleSceneCalculator.ballRadius) * 1.6
            cam.zNear = 0.001
            cam.zFar = 10
            node.position = SCNVector3(ball.position.x, ball.position.y + 1.0, ball.position.z)
            node.look(at: ball.position, up: SCNVector3(1, 0, 0), localFront: SCNVector3(0, 0, -1))
        }

        /// 3D 斜视（透视）：约 30° 俯角、0.45 m 距离，接近瞄准视角下球的观感。
        func applyPerspective(on ball: SCNNode) {
            guard let cam = scene.cameraNode?.camera, let node = scene.cameraNode else { return }
            cam.usesOrthographicProjection = false
            cam.projectionDirection = .vertical
            cam.fieldOfView = 30
            cam.zNear = 0.01
            cam.zFar = 50
            let d: Float = 0.45
            let pitch: Float = 30 * .pi / 180
            node.position = SCNVector3(ball.position.x - d * cosf(pitch),
                                       ball.position.y + d * sinf(pitch),
                                       ball.position.z)
            node.look(at: ball.position, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        }

        func snapshot(size: CGSize) -> UIImage? {
            renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        }
    }
}
