//
//  SpinExportParityTests.swift
//  QiuJiTests
//
//  问题集合 v17 W2 完成标准 ①「同源一致性」：离线出片的球体自转与 App 内回放同口径。
//
//  取 `content/position_play/sequences/` 里加塞最强的一条单杆序列（drill_c019 右塞一库变线，
//  spinX = −0.405），用与 `SequenceVideoExporter` 完全相同的求解入口（`PositionPlayShotSolver`）
//  复现这一杆，然后：
//    A. **真实 App 路径**——把 `TrajectoryPlayback.action(for:)` 挂到球节点上，由
//       `SCNRenderer.snapshot(atTime:)` 推进场景时钟逐帧求值（走的是线上那段 `customAction` 闭包本体，
//       不是测试里手抄的等价实现）；
//    B. **导出器路径**——按 `SequenceVideoExporter.renderFrames` 运动帧循环的口径
//       （固定 `frameSimDt = playbackSpeed / fps` + `stateAt` + `BallSpinIntegrator.advance`）积分。
//  两条路径的逐帧姿态必须一致，且这一杆确实转过可观角度（排除「两边都不转所以也一致」）。
//
//  同时按视频帧的模拟时刻出 App 侧顶视截图，落 `build/v17-evidence/w2-export-parity/app_*.png`，
//  与 `ffmpeg` 抽出的视频帧裁剪图人工对照（旋向一致、无「App 内转、视频不转」）。
//
//  运行：
//    xcodebuild test -scheme QiuJi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//      -only-testing:QiuJiTests/SpinExportParityTests
//

import XCTest
import UIKit
import SceneKit
import simd
@testable import QiuJi

final class SpinExportParityTests: XCTestCase {

    /// 出片验证选用的序列（加塞最强的单杆：spinX = −0.405、v = 3.3，母球撞球后带强右塞离台）。
    private let sequencePath = "/Users/song/projects/13.billiard_trainer/content/position_play/sequences/"
        + "drill_c019__Snipaste_2026_06_01_23_34_29-右塞一库变线 · 球形6-1杆.json"
    private let evidenceDir = "/Users/song/projects/13.billiard_trainer/build/v17-evidence/w2-export-parity"

    /// 导出档 `Options.teachingVideo()` 的运动帧节奏：60fps、原速 ⇒ 每帧模拟步长 1/60 s。
    private let exportFPS: Float = 60
    private let exportSpeed: Float = 1.0

    // MARK: - 完成标准 ①：App 路径 vs 导出器路径，逐帧姿态一致

    @MainActor
    func test_w2_exporterLoop_matchesRealAppActionPath() throws {
        let (recorder, cueName, surfaceY) = try solveExportedShot()
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let frameDt = exportSpeed / exportFPS
        let frames = 120

        // A. 真实 App 路径：SCNAction 由渲染时钟驱动。
        let app = try XCTUnwrap(ActionDrivenRig(), "无 Metal 设备")
        let playbackApp = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let action = try XCTUnwrap(playbackApp.action(for: app.ball, ballName: cueName,
                                                      removeOnPocket: false),
                                   "回放动作为空")
        BallSpinIntegrator.resetPose(app.ball)
        app.ball.runAction(action)
        var appPoses: [simd_quatf] = []
        for i in 0...frames {
            app.step(to: TimeInterval(Float(i) * frameDt / exportSpeed))
            appPoses.append(app.ball.simdOrientation)
        }

        // B. 导出器路径：固定步长梯形积分（SequenceVideoExporter 运动帧循环口径）。
        let playbackExp = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let node = SCNNode()
        var lastOmega: SCNVector3?
        var exportPoses: [simd_quatf] = []
        for i in 0...frames {
            let t = Float(i) * frameDt
            guard let s = playbackExp.stateAt(ballName: cueName, time: min(t, playbackExp.duration)) else {
                continue
            }
            if let prev = lastOmega {
                BallSpinIntegrator.advance(node: node, from: prev, to: s.angularVelocity, dt: frameDt)
            }
            lastOmega = s.angularVelocity
            exportPoses.append(node.simdOrientation)
        }

        XCTAssertEqual(appPoses.count, exportPoses.count, "两条路径采样帧数不一致")
        // 排除「两边都没转」的平凡一致。
        let total = angleBetween(appPoses[0], appPoses[appPoses.count - 1])
        XCTAssertGreaterThan(total, 1.0,
                             "这一杆 App 路径应转过可观角度（实测 \(total) rad），否则一致性无意义")

        var worst: (i: Int, diff: Float) = (0, 0)
        for i in 0..<appPoses.count {
            let d = angleBetween(appPoses[i], exportPoses[i])
            if d > worst.diff { worst = (i, d) }
        }
        // App 路径的 Δt 由渲染时钟给出（此处与导出器同为 1/60），残差只来自浮点。
        XCTAssertLessThan(worst.diff, 1e-3,
                          "导出器与 App 内姿态不同源：第 \(worst.i) 帧偏差 \(worst.diff) rad")
        print(String(format: "📐 [v17-W2] 同源比对：%d 帧，总转角 %.2f rad，最大逐帧偏差 %.2e rad",
                     appPoses.count, total, worst.diff))
    }

    /// 视频里母球的实测像素球心（`s01.mp4` 第 250–261 帧，`ffmpeg` 抽帧 + 最大白团质心；
    /// 该窗口是母球撞目标球后的慢速段，每帧转角小、旋向肉眼可判）。
    /// 视频画幅 1440×2720 = 场景 1440×2560（顶部）+ HUD 条 160（底部），故与场景渲染同坐标。
    private let videoCentroids: [(frame: Int, x: Float, y: Float)] = [
        (250, 789.9, 2258.1), (251, 784.0, 2251.9), (252, 778.3, 2246.1), (253, 772.4, 2240.8),
        (254, 766.4, 2235.7), (255, 760.8, 2230.3), (256, 755.0, 2225.5), (257, 749.1, 2220.0),
        (258, 743.4, 2215.1), (259, 737.9, 2209.9), (260, 731.9, 2205.0), (261, 726.1, 2199.7)
    ]

    /// App 内截图：与导出 2D 档**同一套取景**（`fitRotatedTable` + `applyTopDown2DRotated`，
    /// 1440×2560），并用视频实测球心**反解**每一帧对应的模拟时刻，从而在同相位下对照旋向。
    /// 位置残差同时是「两条管线摆位一致」的量化证据。
    @MainActor
    func test_w2_appSideFramesForVideoComparison() throws {
        try FileManager.default.createDirectory(atPath: evidenceDir, withIntermediateDirectories: true)
        let (recorder, cueName, _) = try solveExportedShot()

        let size = CGSize(width: 1440, height: 2560)
        let rig = try XCTUnwrap(ExportFramingRig(size: size), "无 Metal 设备")
        let ball = try XCTUnwrap(rig.scene.allBallNodes[PositionPlayBall.cueKey], "缺母球节点")
        let yLevel = rig.scene.surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)

        // 1) 时间配准：在细网格上找出投影球心最接近视频实测球心的模拟时刻。
        let grid = stride(from: Float(0), through: min(playback.duration, 1.2), by: 1.0 / 600)
        var projections: [(t: Float, p: CGPoint)] = []
        for t in grid {
            guard let s = playback.stateAt(ballName: cueName, time: t) else { continue }
            ball.position = SCNVector3(s.position.x, yLevel, s.position.z)
            projections.append((t, rig.project(ball.position)))
        }
        XCTAssertFalse(projections.isEmpty, "配准网格为空")

        var matches: [(frame: Int, t: Float, residual: Float)] = []
        for c in videoCentroids {
            var best: (t: Float, d: Float) = (0, .greatestFiniteMagnitude)
            for pr in projections {
                let dx = Float(pr.p.x) - c.x, dy = Float(pr.p.y) - c.y
                let d = sqrtf(dx * dx + dy * dy)
                if d < best.d { best = (pr.t, d) }
            }
            matches.append((c.frame, best.t, best.d))
        }
        let worst = matches.max(by: { $0.residual < $1.residual })!
        print(String(format: "📐 [v17-W2] 时间配准：n%d..n%d → t %.4f..%.4f s，最大位置残差 %.1f px",
                     matches[0].frame, matches[matches.count - 1].frame,
                     matches[0].t, matches[matches.count - 1].t, worst.residual))
        // 两条管线若摆位/取景同源，残差应在亚球径量级（母球直径此取景下约 44 px）。
        XCTAssertLessThan(worst.residual, 8,
                          "App 取景与导出视频摆位不一致：第 \(worst.frame) 帧残差 \(worst.residual) px")
        // 配准出的时刻必须与视频帧率同步递增（相邻帧 1/60 s），否则说明匹配到了别的时段。
        for i in 1..<matches.count {
            XCTAssertEqual(matches[i].t - matches[i - 1].t, 1.0 / 60, accuracy: 1.0 / 300,
                           "配准时刻未按 1/60 s 递进（第 \(matches[i].frame) 帧）")
        }

        // 2) 从 t=0 起按导出器口径逐帧积分姿态，走到配准时刻时出图。
        let frameDt = exportSpeed / exportFPS
        let startT = matches[0].t
        BallSpinIntegrator.resetPose(ball)
        var prevOmega = playback.stateAt(ballName: cueName, time: 0)?.angularVelocity ?? SCNVector3Zero
        var k = 0
        var emitted = 0
        while Float(k) * frameDt <= matches[matches.count - 1].t + frameDt {
            let t = Float(k) * frameDt
            guard let s = playback.stateAt(ballName: cueName, time: min(t, playback.duration)) else { break }
            ball.position = SCNVector3(s.position.x, yLevel, s.position.z)
            if k > 0 {
                BallSpinIntegrator.advance(node: ball, from: prevOmega, to: s.angularVelocity, dt: frameDt)
            }
            prevOmega = s.angularVelocity
            if t >= startT - 1e-4, emitted < matches.count {
                let full = try XCTUnwrap(rig.snapshot(size: size), "渲染失败")
                let center = rig.project(ball.position)
                let tag = String(format: "%02d_n%d", emitted, matches[emitted].frame)
                try write(try nearestNeighborCrop(full, center: center, side: 90, magnify: 6),
                          to: "\(evidenceDir)/app_2d_f\(tag).png")
                emitted += 1
            }
            k += 1
        }
        XCTAssertEqual(emitted, matches.count, "对照帧数不足")
        print("📐 [v17-W2] App 侧对照截图（导出同取景，6× 最近邻放大）→ \(evidenceDir)/app_2d_f*.png")
    }

    // MARK: - Helpers

    /// 用导出器同一入口复现被出片那一杆，返回 (recorder, 母球在 recorder 里的名字, surfaceY)。
    @MainActor
    private func solveExportedShot() throws -> (TrajectoryRecorder, String, Float) {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sequencePath),
                          "缺序列文件：\(sequencePath)")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sequence = try decoder.decode(PositionPlaySequence.self,
                                          from: Data(contentsOf: URL(fileURLWithPath: sequencePath)))
        let step = try XCTUnwrap(sequence.steps.first, "空序列")
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        let surfaceY = scene.surfaceY
        let pred = try XCTUnwrap(PositionPlayShotSolver.solve(before: step.before, shot: step.shot,
                                                             surfaceY: surfaceY),
                                 "求解失败")
        XCTAssertTrue(pred.feasible, "这一杆不可行，换一条序列")
        let recorder = try XCTUnwrap(pred.recorder, "无 recorder")
        let cueName = PositionPlayShotSolver.predName(boardKey: PositionPlayBall.cueKey, shot: step.shot)
        return (recorder, cueName, surfaceY)
    }

    private func angleBetween(_ a: simd_quatf, _ b: simd_quatf) -> Float {
        let d = simd_normalize(simd_mul(b, a.inverse))
        return 2 * acos(min(1, abs(d.real)))
    }

    private func write(_ image: UIImage?, to path: String) throws {
        let img = try XCTUnwrap(image, "渲染失败：\(path)")
        try XCTUnwrap(img.pngData()).write(to: URL(fileURLWithPath: path))
    }

    /// 以 `center`（像素）为心裁 `side`×`side` 并最近邻放大——与视频抽帧裁剪同口径。
    private func nearestNeighborCrop(_ image: UIImage, center: CGPoint,
                                     side: Int, magnify: Int) throws -> UIImage {
        let cg = try XCTUnwrap(image.cgImage)
        let scale = CGFloat(cg.width) / image.size.width
        let cx = Int(center.x * scale) - side / 2
        let cy = Int(center.y * scale) - side / 2
        let rect = CGRect(x: max(0, min(cg.width - side, cx)), y: max(0, min(cg.height - side, cy)),
                          width: side, height: side)
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

    /// 只为「让 SCNAction 真的跑起来」的最小离屏台：SCNRenderer 每次 `snapshot(atTime:)`
    /// 会把场景时钟推进到该时刻并求值节点动作，等价 App 内每帧渲染。
    @MainActor
    private final class ActionDrivenRig {
        let ball = SCNNode()
        private let renderer: SCNRenderer

        init?() {
            guard let device = MTLCreateSystemDefaultDevice() else { return nil }
            let scene = SCNScene()
            ball.geometry = SCNSphere(radius: CGFloat(AngleSceneCalculator.ballRadius))
            scene.rootNode.addChildNode(ball)
            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = scene
            self.renderer = renderer
        }

        /// 推进渲染时钟到 `time`（秒）——动作按此求值。
        func step(to time: TimeInterval) {
            _ = renderer.snapshot(atTime: time, with: CGSize(width: 8, height: 8),
                                  antialiasingMode: .none)
        }
    }

    /// 与导出 2D 档同一套取景的离屏台（`SequenceVideoExporter.RenderContext` 顶视竖版分支同款）。
    @MainActor
    private final class ExportFramingRig {
        let scene: AngleTrainingScene
        private let renderer: SCNRenderer
        private let size: CGSize

        init?(size: CGSize) {
            guard let device = MTLCreateSystemDefaultDevice() else { return nil }
            let scene = AngleTrainingScene()
            scene.setupScene(enhancedRendering: false)
            guard scene.cameraNode != nil, let rig = scene.cameraRig else { return nil }
            scene.background.contents = UIColor.black
            scene.hideAllBalls()
            scene.hideCueStick()
            scene.showBall(key: PositionPlayBall.cueKey,
                           scenePosition: SCNVector3(0, scene.surfaceY, 0))
            rig.topDownPanOffset = .zero
            rig.fitRotatedTable(viewSize: size)
            rig.applyTopDown2DRotated()

            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = scene
            renderer.pointOfView = scene.cameraNode
            renderer.autoenablesDefaultLighting = false
            self.scene = scene
            self.renderer = renderer
            self.size = size
        }

        /// 世界坐标 → 画幅像素（左上原点，与抽帧图同向）。
        /// 自己走「视图矩阵 × 投影矩阵 → NDC」而不用 `projectPoint`：后者依赖渲染器视口状态，
        /// 离屏渲染下不确定；这里显式用取景尺寸算，结果可复现。
        func project(_ p: SCNVector3) -> CGPoint {
            guard let camNode = scene.cameraNode, let cam = camNode.camera else { return .zero }
            let view = simd_inverse(simd_float4x4(camNode.worldTransform))
            let proj = simd_float4x4(cam.projectionTransform(withViewportSize: size))
            let clip = proj * (view * simd_float4(p.x, p.y, p.z, 1))
            let w = clip.w == 0 ? 1 : clip.w
            let ndc = simd_float3(clip.x / w, clip.y / w, clip.z / w)
            return CGPoint(x: CGFloat((ndc.x * 0.5 + 0.5) * Float(size.width)),
                           y: CGFloat((1 - (ndc.y * 0.5 + 0.5)) * Float(size.height)))
        }

        func snapshot(size: CGSize) -> UIImage? {
            renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        }
    }
}
