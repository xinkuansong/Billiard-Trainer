//
//  ReachabilityVizTests.swift
//  QiuJiTests
//
//  走位可视化 → 短视频引流 · Pilot ①「可达轨迹绽放」（方案见
//  docs/research/20260624-走位可视化-短视频引流方案.md §3.1 Hero / §4 表 ①）。
//
//  这是一个 **dev-only 素材生成器**，刻意做成测试（零产品侵入、零架构债，验证三指标
//  通过后再决定是否产品化、补 ADR）。物理**全程同源** `ShotPredictor`——固定母球/目标球/
//  袋口，扫一遍 (高低杆 spinY × 力度 V0)，把每条「能把这颗球打进」的母球轨迹（保留到
//  最多 3 库）累积叠加，**直接画在 USDZ 真台上**，交替配色以区分不同轨迹。
//
//  诚实红线（方案 §4）：
//   1. 最多三库——字幕显式标注「教学示意 · 最多三库」，不冒充全程真实可达区。
//   2. 所有轨迹由 App 内 ShotPredictor 跑出、不手调，用户可在 App 复现。
//
//  坐标契约（与 .kiro/steering/table-geometry.md + AngleSceneCalculator 对齐）：
//   - 物理/渲染系：SceneKit 世界系，水平面 X–Z，Y 朝上；surfaceY≈0.80，球心 y = surfaceY + R。
//     轨迹线直接用世界坐标喂 `AngleTrainingScene.addLine`，**不做像素映射**（真台渲染由
//     SCNRenderer 投影），竖屏取景复用 cameraRig 的 rotated 顶视（与 App 2D 球桌页同源）。
//   - 扫描：spinX=0（无塞），spinY=b∈[-0.5,0.5]（打滑极限 √(a²+b²)≤0.5 ⇒ |b|≤0.5），
//     velocity∈[0.6,6.5]（≤ BallPhysics.maxVelocity）。
//
//  运行：
//    xcodebuild test -scheme QiuJi \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
//      -only-testing:QiuJiTests/ReachabilityVizTests/test_reach_still   （快：仅静帧 PNG，调坐标用）
//      -only-testing:QiuJiTests/ReachabilityVizTests/test_reach_video   （慢：竖屏 mp4）
//
//  输出目录：build/reach_viz/{reach_still.png, reach_pilot1.mp4}
//

import XCTest
import UIKit
import SceneKit
@testable import QiuJi

final class ReachabilityVizTests: XCTestCase {

    private let outputDir = "/Users/song/projects/13.billiard_trainer/build/reach_viz"
    private let sY = BTTablePhysics.surfaceY
    private var R: Float { AngleSceneCalculator.ballRadius }

    // MARK: - 场景（可调）

    /// 选定袋：右上角袋（idx1）。
    private let pocketIndex = 1
    /// 目标球：台面中心。
    private var target: SCNVector3 { SCNVector3(0.0, sY + R, 0.0) }
    /// 切角（度）：中等切角，扇形最舒展。
    private let cutDeg: Float = 35
    /// 母球到幽灵球距离（米）。
    private let cueDist: Float = 0.55

    /// 扫描网格（适度密度：既够「绽放」又能用交替色区分单条轨迹）。
    private let bSteps = 15           // 高低杆 spinY: -0.5 → +0.5
    private let vSteps = 18           // 力度 V0: 0.6 → 6.5
    private let vMin: Float = 0.6
    private let vMax: Float = 6.5
    private let bLimit: Float = 0.5   // |spinY| ≤ miscueLimitFraction（spinX=0 时）

    /// 最多展示的母球吃库数。
    private let maxCushions = 3

    // MARK: - 画布（竖屏 9:16）

    private let W: CGFloat = 1080
    private let H: CGFloat = 1920

    /// 交替配色调色板（暗台上高亮，`.constant` 材质不吃光照恒显色）。
    private let palette: [UIColor] = [
        UIColor(red: 0.20, green: 0.85, blue: 1.00, alpha: 1),   // cyan
        UIColor(red: 1.00, green: 0.45, blue: 0.82, alpha: 1),   // pink
        UIColor(red: 1.00, green: 0.82, blue: 0.25, alpha: 1),   // amber
        UIColor(red: 0.55, green: 1.00, blue: 0.45, alpha: 1),   // green
        UIColor(red: 1.00, green: 0.55, blue: 0.30, alpha: 1),   // orange
        UIColor(red: 0.66, green: 0.60, blue: 1.00, alpha: 1)    // violet
    ]

    // MARK: - 一条扫出来的母球轨迹（世界坐标）

    private struct ReachPath {
        let world: [SCNVector3]   // 母球轨迹折线（世界系，已重采样 + 简化，保留到 ≤3 库）
        let colorIndex: Int
        let b: Float
        let v: Float
    }

    // MARK: - 摆位：由切角反推母球

    /// 与 ShotScenarioRenderTests.placeCue 同口径：把进球线(target→pocket)逆时针转 cut 得撞击线。
    private func placeCue(cutDeg: Float, dist: Float) -> SCNVector3 {
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: target, pocket: pocket, ballRadius: R)
        let pdx = pocket.x - target.x, pdz = pocket.z - target.z
        let pl = max(sqrtf(pdx * pdx + pdz * pdz), 1e-5)
        let pd = SCNVector3(pdx / pl, 0, pdz / pl)
        let th = cutDeg * .pi / 180
        let strikeDir = SCNVector3(pd.x * cosf(th) - pd.z * sinf(th), 0,
                                   pd.x * sinf(th) + pd.z * cosf(th))
        let raw = SCNVector3(ghost.x - strikeDir.x * dist, sY + R, ghost.z - strikeDir.z * dist)
        let halfL = AngleSceneCalculator.innerLength / 2 - R - 0.01
        let halfW = AngleSceneCalculator.innerWidth / 2 - R - 0.01
        return SCNVector3(max(-halfL, min(halfL, raw.x)), sY + R, max(-halfW, min(halfW, raw.z)))
    }

    // MARK: - 批量扫描（ShotPredictor 同源真算）

    /// 扫 (spinY × V0)，返回「能把目标球打进选定袋、母球未刮杆」的母球轨迹（世界系，≤3 库）。
    private func sweepReachPaths(cue: SCNVector3, yLevel: Float) -> [ReachPath] {
        var out: [ReachPath] = []
        var potted = 0, total = 0
        var idx = 0
        for vi in 0..<vSteps {
            let v = vMin + (vMax - vMin) * Float(vi) / Float(max(1, vSteps - 1))
            for bi in 0..<bSteps {
                let b = -bLimit + 2 * bLimit * Float(bi) / Float(max(1, bSteps - 1))
                total += 1
                let pred = ShotPredictor.predict(ShotInput(
                    cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                    velocity: v, spinX: 0, spinY: b, surfaceY: sY))
                guard pred.feasible, pred.objectPocketed, !pred.cuePocketed,
                      pred.cuePath.count >= 2 else { continue }
                let world = cuePathToCushions(pred, maxCushions: maxCushions, yLevel: yLevel)
                guard world.count >= 2 else { continue }
                potted += 1
                out.append(ReachPath(world: world, colorIndex: idx % palette.count, b: b, v: v))
                idx += 1
            }
        }
        print("[reach] swept \(total) shots, potted+reachable=\(potted)")
        return out
    }

    /// 母球轨迹保留到「最多 maxCushions 库」：取母球第 (maxCushions+1) 次吃库时刻为截断点
    /// （超过该库数的轨迹段不展示）；吃库不足 maxCushions 则保留到停稳。轨迹从同源
    /// `TrajectoryPlayback` 按 120Hz 重采样后简化，避免与简化折线做就近匹配的歧义。
    private func cuePathToCushions(_ pred: ShotPrediction, maxCushions: Int, yLevel: Float) -> [SCNVector3] {
        guard let recorder = pred.recorder else { return pred.cuePath }
        let cushionTimes: [Float] = pred.events.compactMap { ev in
            if case .ballCushion(let ball) = ev.kind, ball == ShotInput.cueBallName { return ev.time }
            return nil
        }.sorted()
        let cut: Float = cushionTimes.count > maxCushions ? cushionTimes[maxCushions] : pred.duration
        guard cut > 0 else { return pred.cuePath }

        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        var pts: [SCNVector3] = []
        let dt: Float = 1.0 / 120
        var t: Float = 0
        while t < cut {
            if let s = playback.stateAt(ballName: ShotInput.cueBallName, time: t) { pts.append(s.position) }
            t += dt
        }
        if let s = playback.stateAt(ballName: ShotInput.cueBallName, time: cut) { pts.append(s.position) }
        return simplify(pts)
    }

    /// 折线简化：保留拐点（吃库反射处角度大）与长段端点，压低节点数（控制 SceneKit 圆柱数量）。
    private func simplify(_ pts: [SCNVector3]) -> [SCNVector3] {
        guard pts.count > 2 else { return pts }
        var out: [SCNVector3] = [pts[0]]
        for i in 1..<(pts.count - 1) {
            let prev = out.last!
            let cur = pts[i], nxt = pts[i + 1]
            let segLen = hypotf(cur.x - prev.x, cur.z - prev.z)
            let a1 = SCNVector3(cur.x - prev.x, 0, cur.z - prev.z)
            let a2 = SCNVector3(nxt.x - cur.x, 0, nxt.z - cur.z)
            if segLen > 0.12 || angleXZ(a1, a2) > 3 * .pi / 180 { out.append(cur) }
        }
        out.append(pts[pts.count - 1])
        return out
    }

    private func angleXZ(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let la = hypotf(a.x, a.z), lb = hypotf(b.x, b.z)
        guard la > 1e-5, lb > 1e-5 else { return 0 }
        let c = max(-1, min(1, (a.x * b.x + a.z * b.z) / (la * lb)))
        return acosf(c)
    }

    // MARK: - SceneKit / USDZ 渲染器（竖屏旋转顶视，与 SequenceVideoExporter.RenderContext 同源）

    private struct RenderCtx {
        let scene: AngleTrainingScene
        let renderer: SCNRenderer
        let yLevel: Float
    }

    @MainActor
    private func makeRenderer() -> RenderCtx? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        guard scene.cameraNode != nil else { return nil }
        scene.background.contents = UIColor.black
        scene.hideAllBalls()
        scene.hideCueStick()
        if let rig = scene.cameraRig {
            rig.topDownPanOffset = .zero
            rig.fitRotatedTable(viewSize: CGSize(width: W, height: H))
            rig.applyTopDown2DRotated()
        }
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.autoenablesDefaultLighting = false
        return RenderCtx(scene: scene, renderer: renderer, yLevel: scene.surfaceY + R)
    }

    /// 摆母球（白）+ 目标球（USDZ 编号球）。
    @MainActor
    private func placeBalls(_ ctx: RenderCtx, cue: SCNVector3) {
        ctx.scene.showBall(key: PositionPlayBall.cueKey, scenePosition: cue)
        ctx.scene.showBall(key: "_1", scenePosition: target)
    }

    /// 把一条轨迹折线建成一组圆柱线节点，挂到 scene；`hidden` 控制初始可见性（视频里逐条点亮）。
    @MainActor
    private func buildLineNodes(_ ctx: RenderCtx, path: ReachPath, hidden: Bool) -> [SCNNode] {
        let color = palette[path.colorIndex]
        var nodes: [SCNNode] = []
        for i in 0..<(path.world.count - 1) {
            let n = ctx.scene.addLine(from: path.world[i], to: path.world[i + 1],
                                      color: color, radius: 0.0042)
            n.isHidden = hidden
            nodes.append(n)
        }
        return nodes
    }

    // MARK: - 字幕合成（在 SCNRenderer 快照上叠中文字幕）

    @MainActor
    private func snapshot(_ ctx: RenderCtx, subtitle: String, subtitleAlpha: CGFloat) -> CGImage {
        let base = ctx.renderer.snapshot(atTime: 0, with: CGSize(width: W, height: H),
                                         antialiasingMode: .multisampling4X)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1; fmt.opaque = true
        let r = UIGraphicsImageRenderer(size: CGSize(width: W, height: H), format: fmt)
        let img = r.image { _ in
            base.draw(in: CGRect(x: 0, y: 0, width: W, height: H))
            if !subtitle.isEmpty, subtitleAlpha > 0.001 {
                drawSubtitle(subtitle, alpha: subtitleAlpha)
            }
        }
        return img.cgImage!
    }

    private func drawSubtitle(_ s: String, alpha: CGFloat) {
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let font = UIFont.systemFont(ofSize: 58, weight: .heavy)
        let shadow = NSShadow(); shadow.shadowColor = UIColor.black.withAlphaComponent(0.9 * alpha)
        shadow.shadowBlurRadius = 8; shadow.shadowOffset = CGSize(width: 0, height: 2)
        let attr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(alpha),
            .paragraphStyle: para,
            .shadow: shadow
        ]
        let inset: CGFloat = 56
        let box = CGRect(x: inset, y: H - 360, width: W - 2 * inset, height: 300)
        (s as NSString).draw(in: box, withAttributes: attr)
    }

    // MARK: - 测试①：静帧（快，调坐标 / 配色用）

    @MainActor
    func test_reach_still() throws {
        try ensureDir()
        guard let ctx = makeRenderer() else { XCTFail("无 Metal 设备 / 场景"); return }
        let cue = placeCue(cutDeg: cutDeg, dist: cueDist)
        placeBalls(ctx, cue: cue)
        let paths = sweepReachPaths(cue: cue, yLevel: ctx.yLevel)
        XCTAssertGreaterThan(paths.count, 20, "可达轨迹过少，检查摆位/切角")
        for p in paths { _ = buildLineNodes(ctx, path: p, hidden: false) }

        let img = snapshot(ctx, subtitle: "这一杆白球能到的地方\n（教学示意 · 最多三库）", subtitleAlpha: 1)
        let path = "\(outputDir)/reach_still.png"
        try UIImage(cgImage: img).pngData()!.write(to: URL(fileURLWithPath: path))
        add(XCTAttachment(image: UIImage(cgImage: img)))
        print("[reach] wrote \(path) (\(Int(W))x\(Int(H))) paths=\(paths.count)")
    }

    // MARK: - 测试②：竖屏 mp4（慢）

    @MainActor
    func test_reach_video() async throws {
        try ensureDir()
        guard let ctx = makeRenderer() else { XCTFail("无 Metal 设备 / 场景"); return }
        let cue = placeCue(cutDeg: cutDeg, dist: cueDist)
        placeBalls(ctx, cue: cue)
        let paths = sweepReachPaths(cue: cue, yLevel: ctx.yLevel)
        XCTAssertGreaterThan(paths.count, 20, "可达轨迹过少，检查摆位/切角")
        let nodesByTraj: [[SCNNode]] = paths.map { buildLineNodes(ctx, path: $0, hidden: true) }

        let fps = 30
        let url = URL(fileURLWithPath: "\(outputDir)/reach_pilot1.mp4")
        let writer = try VideoWriter(url: url, size: CGSize(width: W, height: H), fps: fps)

        func frames(_ sec: Double) -> Int { max(1, Int(sec * Double(fps))) }
        func smoothstep(_ t: Double) -> Double { let x = max(0, min(1, t)); return x * x * (3 - 2 * x) }
        func setReveal(_ count: Int) {
            for (i, group) in nodesByTraj.enumerated() {
                let show = i < count
                for n in group { n.isHidden = !show }
            }
        }

        // 分阶段时间轴（秒）。
        let introHold = 1.2
        let bloom     = 7.0
        let cloudHold = 2.0
        let endHold   = 2.8

        // 1) 开场：空台 + 母/目标，钩子谜面。
        setReveal(0)
        for _ in 0..<frames(introHold) {
            try writer.append(snapshot(ctx, subtitle: "下一颗总走不到位？\n先看看白球能去哪", subtitleAlpha: 1))
        }
        // 2) 绽放：逐条点亮轨迹，交替色累积成可达云。
        let bloomFrames = frames(bloom)
        for f in 0..<bloomFrames {
            let p = smoothstep(Double(f) / Double(max(1, bloomFrames - 1)))
            setReveal(Int((p * Double(paths.count)).rounded()))
            try writer.append(snapshot(ctx, subtitle: "白球能到的每个落点\n都在这了", subtitleAlpha: 1))
        }
        // 3) 满云停留。
        setReveal(paths.count)
        for _ in 0..<frames(cloudHold) {
            try writer.append(snapshot(ctx, subtitle: "", subtitleAlpha: 0))
        }
        // 4) 收尾停留 + 诚实红线说明。
        for _ in 0..<frames(endHold) {
            try writer.append(snapshot(ctx, subtitle: "走位是「选位」，不是硬凑\n（教学示意 · 最多三库 · 同源真算）", subtitleAlpha: 1))
        }

        try await writer.finish()
        print("[reach] wrote \(url.path) paths=\(paths.count)")
    }

    // MARK: - Helpers

    private func ensureDir() throws {
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
    }
}
