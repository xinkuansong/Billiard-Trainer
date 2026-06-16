import SceneKit
import SwiftUI
import UIKit

/// 把走位序列渲染成 SceneKit 真台教学素材（ADR-P11-01 / ADR-P11-11）。
///
/// 复用 `AngleTrainingScene`（USDZ 球桌 + 现成球节点）与 `ShotPredictor`（多球求解）：
/// 逐 Step 摆 `before` 球形 → 真实模拟 → 用 `TrajectoryPlayback.stateAt(t)` 按固定帧率
/// 驱动全部在桌球节点 → `SCNRenderer.snapshot(atTime:)` 取帧。
///
/// 产物（ADR-P11-11 渲染矩阵）：
/// - 视频/GIF：`exportVideo` / `exportGIF`（整段或经 `subSequence` 单杆切片）；
/// - 教学静帧：`renderStills`（开局 / 每杆击球前带预告线 / 终局）；
/// - 卡片素材：`renderCover`（封面）+ `renderPreviewFrames`（卡片动画帧序列），卡片风格球放大。
///
/// 轨迹线契约：**击球前静帧显示预告线（白=母球路线、橙=进球线），出杆瞬间清除**，
/// 运动帧始终无线（与编排台 App 内行为一致）。
///
/// 击球参数 HUD（ADR-P11-13）：teaching 档画面底部追加暗色 HUD 条，显示本杆打点
/// （`BTSpinMiniIcon` 同款球面 + 百分比读数）与力度条（`PowerDisplay` 档名 + m/s），
/// 每杆常驻（设置帧→收尾帧）、换杆更新；HUD 视图经 `ImageRenderer` 直接复用 App 组件，
/// 与 App 内样式单一真源。场景背景改暗色与 App 场景页一致。
@MainActor
enum SequenceVideoExporter {

    // MARK: - Options

    struct Options {
        /// 输出像素尺寸——只影响清晰度，不影响球桌/球比例。
        var size: CGSize = CGSize(width: 1280, height: 640)
        /// 竖版取景：复用 rig 的 rotated 顶视（台面长轴竖直铺满，ADR-P11-08），
        /// 让横向 2:1 球桌在竖屏播放器里铺满画幅。false = 横版顶视（封面/GIF/静帧）。
        var portrait: Bool = false
        /// 60fps + 原速：30fps×1.3 倍速时帧间物理步长 43ms，中速球一帧跳 ~60px、
        /// 无运动模糊肉眼即「卡」（ADR-P11-12）；60fps×1.0 步长 17ms。
        var fps: Int = 60
        var playbackSpeed: Float = 1.0
        /// 开局静帧时长。连续录制的序列首杆 `before` == 开局，与首杆设置静帧重复，默认 0。
        var initialHold: Double = 0
        /// 每杆击球前设置静帧时长（预告线可见段）。
        var setupHold: Double = 0.6
        var tailHold: Double = 0.8
        /// 球节点渲染缩放：1.0 = 真实比例（教学产物默认）；1.6 = 卡片风格（小尺寸可读）。
        var ballScale: Float = 1
        /// 击球前是否显示轨迹预告线；false = clean 版（全程无线）。
        var showTrajectories: Bool = true
        /// 击球前是否渲染球杆运杆/出杆动画（#10）：回杆缓动 → 蓄力停顿 → 匀加速出杆，
        /// 触球瞬间杆速 = 目标球速（公式与编排台 `runStrokeAnimation` 单一同源）。
        var showCueStroke: Bool = true
        /// 画面底部是否追加击球参数 HUD 条（打点 + 力度，ADR-P11-13）。
        /// 开启时输出高度 = `size.height` + HUD 条高；gif/card 档小尺寸下会糊，默认关。
        var showShotHUD: Bool = true

        init() {}

        /// HUD 条像素高。横版按画面宽度等比（1280 宽 → 80px）；竖版画幅窄（720 宽），
        /// 等比会过矮且文本糊，固定 80px 保持 k≈1：HUD 文本与横版同尺寸可读，
        /// 内容自然宽（~650px）< 720 不溢出裁切。
        var hudStripHeight: Int {
            guard showShotHUD else { return 0 }
            return portrait ? 80 : Int((size.width * 0.0625).rounded())
        }

        /// 最终输出像素尺寸（场景画面 + HUD 条）。
        var outputSize: CGSize {
            CGSize(width: size.width, height: size.height + CGFloat(hudStripHeight))
        }

        /// 教学真实风格（横版静帧用）：1280×640 场景 + 80px HUD 条（合计 1280×720，16:9）。
        static func teaching() -> Options { Options() }

        /// 教学视频（竖版，App 内竖屏播放主载体）：720×1280 竖版场景（rotated 顶视，
        /// 台面长轴竖直铺满）+ 80px HUD 条（合计 720×1360）。
        static func teachingVideo() -> Options {
            var o = Options()
            o.size = CGSize(width: 720, height: 1280)
            o.portrait = true
            return o
        }

        /// 卡片风格：640×320、球放大 1.6，仅用于封面静帧与卡片动画帧序列。
        static func card() -> Options {
            var o = Options()
            o.size = CGSize(width: 640, height: 320)
            o.ballScale = 1.6
            o.showShotHUD = false
            return o
        }

        /// 分享 GIF：真实比例、降采样、原速（预览媒介，非教学主载体）。
        static func gif() -> Options {
            var o = Options()
            o.size = CGSize(width: 480, height: 240)
            o.fps = 12
            o.playbackSpeed = 1.0
            o.showShotHUD = false
            return o
        }
    }

    // MARK: - Public: video / GIF

    /// 导出 mp4 到临时目录，返回文件 URL。`progress` ∈ [0,1]。
    static func exportVideo(
        sequence: PositionPlaySequence,
        options: Options = .teachingVideo(),
        progress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let url = tempURL(ext: "mp4", name: sequence.name)
        let writer = try VideoWriter(url: url, size: options.outputSize, fps: options.fps)
        let total = estimatedFrameCount(sequence: sequence, options: options)
        var emitted = 0
        try renderFrames(sequence: sequence, options: options) { image in
            try writer.append(image)
            emitted += 1
            if total > 0 { progress?(min(1, Double(emitted) / Double(total))) }
        }
        try await writer.finish()
        progress?(1)
        return url
    }

    /// 导出 GIF 到临时目录，返回文件 URL。
    static func exportGIF(
        sequence: PositionPlaySequence,
        options: Options = .gif(),
        progress: ((Double) -> Void)? = nil
    ) throws -> URL {
        let url = tempURL(ext: "gif", name: sequence.name)
        var frames: [CGImage] = []
        let total = estimatedFrameCount(sequence: sequence, options: options)
        try renderFrames(sequence: sequence, options: options) { image in
            frames.append(image)
            if total > 0 { progress?(min(0.9, Double(frames.count) / Double(total))) }
        }
        try GIFEncoder.encode(frames: frames, to: url, frameDelay: 1.0 / Double(options.fps))
        progress?(1)
        return url
    }

    /// 单杆切片：第 `stepIndex` 杆（0-based）自成一条可独立渲染的序列（`SequenceStep`
    /// 的 before/after 自含，零新逻辑）。
    static func subSequence(_ sequence: PositionPlaySequence, stepIndex: Int) -> PositionPlaySequence {
        let step = sequence.steps[stepIndex]
        return PositionPlaySequence(
            id: sequence.id,
            name: "\(sequence.name)-s\(String(format: "%02d", stepIndex + 1))",
            initial: step.before,
            steps: [step],
            createdAt: sequence.createdAt,
            updatedAt: sequence.updatedAt
        )
    }

    // MARK: - Public: stills

    /// 教学静帧：`initial` 开局、`s0n_still` 每杆击球前（带预告线）、`final` 终局。
    static func renderStills(
        sequence: PositionPlaySequence,
        options: Options = .teaching()
    ) -> [(name: String, image: CGImage)] {
        guard let ctx = RenderContext(options: options) else { return [] }
        var out: [(String, CGImage)] = []

        ctx.placeBoard(sequence.initial)
        if let img = ctx.snapshot() { out.append(("initial", img)) }

        for (i, step) in sequence.steps.enumerated() {
            ctx.placeBoard(step.before)
            let lines = options.showTrajectories ? ctx.drawAimLines(for: step) : []
            let hud = options.showShotHUD ? makeHUDImage(shot: step.shot, options: options) : nil
            if let img = ctx.snapshot() {
                let framed = options.showShotHUD ? composeWithHUD(scene: img, hud: hud, options: options) : img
                out.append((String(format: "s%02d_still", i + 1), framed))
            }
            lines.forEach { $0.removeFromParentNode() }
            ctx.hideAimDecorations()
        }

        if let last = sequence.steps.last {
            ctx.placeBoard(last.after)
            if let img = ctx.snapshot() { out.append(("final", img)) }
        }
        return out
    }

    /// 封面（卡片风格，球放大）：首杆击球前 + 预告线；空序列退回开局布局。
    static func renderCover(sequence: PositionPlaySequence) -> CGImage? {
        guard let ctx = RenderContext(options: .card()) else { return nil }
        guard let step = sequence.steps.first else {
            ctx.placeBoard(sequence.initial)
            return ctx.snapshot()
        }
        ctx.placeBoard(step.before)
        _ = ctx.drawAimLines(for: step)
        return ctx.snapshot()
    }

    /// 卡片动画帧序列（卡片风格）：整段回放等间隔抽样 `frameCount` 帧，
    /// 供 App 内 `Resources/Previews/<id>/frame_*.png` 模式消费。
    static func renderPreviewFrames(
        sequence: PositionPlaySequence,
        frameCount: Int = 12
    ) throws -> [CGImage] {
        var options = Options.card()
        options.fps = 8
        var all: [CGImage] = []
        try renderFrames(sequence: sequence, options: options) { all.append($0) }
        guard all.count > frameCount, frameCount >= 2 else { return all }
        return (0..<frameCount).map { all[$0 * (all.count - 1) / (frameCount - 1)] }
    }

    // MARK: - Frame generation

    /// 逐帧生成回调：每帧渲染一张 `CGImage` 交给 `emit`（流式，便于视频边渲边写）。
    static func renderFrames(
        sequence: PositionPlaySequence,
        options: Options,
        emit: (CGImage) throws -> Void
    ) throws {
        guard let ctx = RenderContext(options: options) else { return }
        let fps = options.fps

        // 击球参数 HUD：每杆常驻（设置帧→收尾帧），换杆更新；开局帧无内容（空条）。
        var currentHUD: CGImage?

        func snapshot() throws {
            guard let img = ctx.snapshot() else { return }
            try emit(options.showShotHUD ? composeWithHUD(scene: img, hud: currentHUD, options: options) : img)
        }

        // 开局静帧（可选；连续录制序列与首杆设置静帧重复，默认跳过）。
        if options.initialHold > 0 {
            ctx.placeBoard(sequence.initial)
            for _ in 0..<holdFrames(options.initialHold, fps: fps) { try snapshot() }
        }

        for step in sequence.steps {
            ctx.placeBoard(step.before)
            currentHUD = options.showShotHUD ? makeHUDImage(shot: step.shot, options: options) : nil

            // 求解本杆（多球；自由球走直瞄模拟）。
            guard let pred = PositionPlayShotSolver.solve(
                      before: step.before, shot: step.shot, surfaceY: ctx.surfaceY),
                  pred.feasible,
                  let recorder = pred.recorder, pred.duration > 0.02 else {
                // 不可行：直接跳到 after 球形，给一小段静帧。
                ctx.placeBoard(step.after)
                for _ in 0..<holdFrames(options.tailHold, fps: fps) { try snapshot() }
                continue
            }

            // 预告线 + 假想球：击球前设置静帧 + 运杆全程可见，触球瞬间清除（ADR-P11-11 轨迹契约）。
            let lines = options.showTrajectories ? ctx.drawAimLines(for: step, prediction: pred) : []
            for _ in 0..<holdFrames(options.setupHold, fps: fps) { try snapshot() }

            // 运杆/出杆动画（#10，与编排台同源）：回杆→蓄力→匀加速出杆，触球杆速=目标球速。
            if options.showCueStroke {
                try ctx.renderCueStroke(step: step, prediction: pred,
                                        fps: fps, speed: options.playbackSpeed, snapshot: snapshot)
                ctx.scene.hideCueStick()
            }

            // 触球瞬间清线、收掉假想球。
            lines.forEach { $0.removeFromParentNode() }
            ctx.hideAimDecorations()

            // 运动帧（无线）。进袋「匀速入洞 → 撞远端袋弧 → 袋心停顿 → 淡出」
            // （#4 v2，与编排台 `TrajectoryPlayback` 同源求解）。
            let playback = TrajectoryPlayback(recorder: recorder, surfaceY: ctx.yLevel)
            let onKeys = step.before.onTable.keys.map { $0 }
            let nameMap = Dictionary(uniqueKeysWithValues: onKeys.map {
                ($0, PositionPlayShotSolver.predName(boardKey: $0, shot: step.shot))
            })
            let duration = pred.duration
            let pause = TrajectoryPlayback.pocketPauseDuration
            let fade = TrajectoryPlayback.pocketFadeDuration
            // 末尾追加「入洞 + 停顿 + 淡出」的模拟时长，保证收杆前进袋的球也能播完消失动画。
            let tailSim: Float = pred.pocketedBalls.isEmpty
                ? 0 : Float(TrajectoryPlayback.pocketSettleDuration * Double(options.playbackSpeed))
            var potTimes: [String: Float] = [:]
            var potEntries: [String: (start: SCNVector3, legs: [TrajectoryPlayback.PocketEntryLeg])] = [:]
            var lastVel: [String: SCNVector3] = [:]
            var t: Float = 0
            while t <= duration + tailSim + 1e-4 {
                for key in onKeys {
                    guard let node = ctx.scene.allBallNodes[key], let name = nameMap[key],
                          let s = playback.stateAt(ballName: name, time: min(t, duration)) else { continue }
                    if s.motionState == .pocketed {
                        if potTimes[key] == nil {
                            potTimes[key] = t
                            // 捕获点（上一帧真实位置）+ 进袋时真实速度 → 入洞段。
                            let pocket = TrajectoryPlayback.nearestPocket(to: node.position, surfaceY: ctx.yLevel)
                            potEntries[key] = (node.position, TrajectoryPlayback.solvePocketEntry(
                                capture: node.position,
                                velocity: lastVel[key] ?? SCNVector3Zero,
                                pocketCenter: pocket.center, pocketRadius: pocket.radius,
                                speedScale: options.playbackSpeed
                            ))
                        }
                        // 真实播放秒 = 模拟时长 / 播放速度。
                        let real = Double(t - potTimes[key]!) / Double(options.playbackSpeed)
                        if let entry = potEntries[key] {
                            node.position = TrajectoryPlayback.pocketEntryPosition(
                                start: entry.start, legs: entry.legs, at: real
                            )
                            let entryEnd = TrajectoryPlayback.pocketEntryDuration(entry.legs)
                            node.opacity = real <= entryEnd + pause
                                ? 1 : CGFloat(max(0, 1 - (real - entryEnd - pause) / fade))
                        }
                    } else {
                        node.position = SCNVector3(s.position.x, ctx.yLevel, s.position.z)
                        node.opacity = 1
                        lastVel[key] = s.velocity
                    }
                }
                try snapshot()
                t += Float(1.0 / Double(fps)) * options.playbackSpeed
            }

            // 收尾：after 球形（进袋离场）静帧。
            ctx.placeBoard(step.after)
            for _ in 0..<holdFrames(options.tailHold, fps: fps) { try snapshot() }
        }
    }

    // MARK: - Render context

    /// 一次渲染会话的场景与离屏渲染器（USDZ 装载开销集中在 init，一个产物一个 context）。
    private final class RenderContext {
        let scene: AngleTrainingScene
        let surfaceY: Float
        let yLevel: Float
        private let renderer: SCNRenderer
        private let options: Options
        private var clock: TimeInterval = 0
        private let frameDt: TimeInterval

        init?(options: Options) {
            guard let device = MTLCreateSystemDefaultDevice() else { return nil }
            let scene = AngleTrainingScene()
            scene.setupScene(enhancedRendering: false)
            guard scene.cameraNode != nil else { return nil }
            // 暗色背景与 App 场景页一致（ADR-P11-13）；HUD 白字依赖暗底可读。
            scene.background.contents = UIColor.black
            scene.hideAllBalls()
            scene.hideCueStick()
            // 预创建假想球等可视化节点（默认隐藏，drawAimLines 按需点亮）。
            scene.setupVisualizationNodes()
            scene.hideAllVisualization()

            // 顶视正交相机，覆盖整张台。竖版复用 rig 的 rotated 取景（台面长轴竖直铺满，
            // 与 App 内 2D 球桌页同一套，ADR-P11-08）；横版用固定 scale 的横向顶视。
            if let rig = scene.cameraRig {
                rig.topDownPanOffset = .zero
                if options.portrait {
                    rig.fitRotatedTable(viewSize: options.size)
                    rig.applyTopDown2DRotated()
                } else {
                    rig.topDownOrthographicScale = 0.86
                    rig.applyTopDown2D()
                }
            }
            // 卡片风格球放大（顶视下只影响视觉大小，真实风格 ballScale=1 不动）。
            for (_, node) in scene.allBallNodes where options.ballScale != 1 {
                node.scale = SCNVector3(node.scale.x * options.ballScale,
                                        node.scale.y * options.ballScale,
                                        node.scale.z * options.ballScale)
            }
            if options.ballScale != 1, let ghost = scene.ghostBallNode {
                ghost.scale = SCNVector3(ghost.scale.x * options.ballScale,
                                         ghost.scale.y * options.ballScale,
                                         ghost.scale.z * options.ballScale)
            }

            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = scene
            renderer.pointOfView = scene.cameraNode
            renderer.autoenablesDefaultLighting = false

            self.scene = scene
            self.renderer = renderer
            self.options = options
            self.surfaceY = scene.surfaceY
            self.yLevel = scene.surfaceY + AngleSceneCalculator.ballRadius
            self.frameDt = 1.0 / Double(max(1, options.fps))
        }

        func snapshot() -> CGImage? {
            let image = renderer.snapshot(atTime: clock, with: options.size,
                                          antialiasingMode: .multisampling4X)
            clock += frameDt
            return image.cgImage
        }

        func placeBoard(_ board: BoardSnapshot) {
            scene.hideAllBalls()
            for (key, pt) in board.onTable {
                let p = AngleSceneCalculator.normalizedToScene(
                    point: CGPoint(x: pt.x, y: pt.y), surfaceY: surfaceY
                )
                scene.showBall(key: key, scenePosition: p)
                scene.allBallNodes[key]?.opacity = 1   // 上一杆进袋淡出后复用节点需复原
            }
        }

        /// 画一杆的轨迹预告线（白=母球瞄准线、**球色**=进球线，黑 8 亮灰，见 `TrajectoryStyle`），
        /// 并显示假想球（袋口模式）。`prediction` 缺省时现场求解；不可行返回空。
        /// 调用方移除返回的线节点时须同步 `hideAimDecorations()` 收掉假想球。
        func drawAimLines(for step: SequenceStep, prediction: ShotPrediction? = nil) -> [SCNNode] {
            guard let pred = prediction
                    ?? PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: surfaceY),
                  pred.feasible else { return [] }

            var objPath = pred.objectPath
            if pred.objectPocketed, !step.shot.isFree,
               let pocketIndex = ShotIntent.pocketIndex(for: step.shot.pocket) {
                objPath = PositionPlayShotSolver.extendPathToPocketRim(
                    objPath, pocketIndex: pocketIndex, surfaceY: surfaceY
                )
            }
            var lines: [SCNNode] = []
            lines.append(contentsOf: polyline(pred.cuePath, color: TrajectoryStyle.aimColor,
                                              radius: TrajectoryStyle.aimRadius))
            lines.append(contentsOf: polyline(objPath,
                                              color: TrajectoryStyle.potColor(for: step.shot.targetKey),
                                              radius: TrajectoryStyle.potRadius))
            // 联动球路径同样随各自球色（extraBallPaths 键 = 桌面球键）。
            for (key, pts) in pred.extraBallPaths {
                lines.append(contentsOf: polyline(pts, color: TrajectoryStyle.potColor(for: key),
                                                  radius: TrajectoryStyle.potRadius))
            }
            // 假想球：袋口模式显示在母球瞄准终点（与编排台/分离角同语义）。
            if !step.shot.isFree, let ghost = scene.ghostBallNode {
                ghost.position = SCNVector3(pred.ghost.x, yLevel, pred.ghost.z)
                ghost.isHidden = false
            }
            return lines
        }

        /// 收掉假想球等非线节点装饰（与移除 `drawAimLines` 返回的线节点配套调用）。
        func hideAimDecorations() {
            scene.ghostBallNode?.isHidden = true
        }

        /// 运杆参数（#10）：与编排台 `PositionPlayViewModel.Stroke` 单一同源——
        /// 回杆距离 = a + k·v（线性）；出杆 = 静止起步匀加速，触球瞬间杆速恰为目标速度 v。
        private enum Stroke {
            static let basePullBack: Float = 0.05         // a：最小回杆距离 (m)
            static let pullBackPerSpeed: Float = 0.035    // k：每 1 m/s 增加的回杆距离 (s)
            static let backswingDuration: TimeInterval = 0.5   // 回杆时长（缓动）
            static let pauseDuration: TimeInterval = 0.12      // 蓄力停顿
        }

        /// 逐帧渲染一杆的运杆/出杆动画：回杆 smoothstep → 蓄力停顿 → 匀加速出杆，
        /// 触球瞬间杆速 = 目标球速 v。`speed` 与运动帧同一倍速，使运杆/击球节奏一致。
        /// 预告线由调用方在触球后清除；本方法只负责球杆帧。
        func renderCueStroke(step: SequenceStep, prediction: ShotPrediction,
                             fps: Int, speed: Float, snapshot: () throws -> Void) rethrows {
            guard let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
                  let aim = Self.aimDirection(path: prediction.cuePath, from: cueNode.position)
            else { return }
            let strikePos = Self.strikePosition(cue: cueNode.position, aim: aim, spinX: step.shot.spinX)
            let v = max(0.3, Float(step.shot.velocity))
            let d = Stroke.basePullBack + Stroke.pullBackPerSpeed * v
            let accel = v * v / (2 * d)                              // v² = 2·a·d
            let forwardTime = TimeInterval(2 * d / v)               // t = v / a
            let total = Stroke.backswingDuration + Stroke.pauseDuration + forwardTime
            let backswing = Stroke.backswingDuration
            let pause = Stroke.pauseDuration

            let dt = Float(speed) / Float(max(1, fps))
            var t: Float = 0
            while t <= Float(total) + 1e-4 {
                let tt = TimeInterval(t)
                let pull: Float
                if tt < backswing {
                    let u = Float(tt / backswing)
                    pull = d * (u * u * (3 - 2 * u))                // 回杆 smoothstep 0 → d
                } else if tt < backswing + pause {
                    pull = d
                } else {
                    let fdt = Float(tt - backswing - pause)
                    pull = max(0, d - 0.5 * accel * fdt * fdt)      // 出杆 d → 0
                }
                scene.updateCueStick(cueBallPosition: strikePos, aimDirection: aim, pullBack: pull)
                try snapshot()
                t += dt
            }
        }

        /// 母球路线首段方向（跳过过近采样点），与编排台 `aimDirection(path:from:)` 同逻辑。
        private static func aimDirection(path: [SCNVector3], from cue: SCNVector3) -> SCNVector3? {
            for pt in path {
                let dx = pt.x - cue.x, dz = pt.z - cue.z
                let d = sqrtf(dx * dx + dz * dz)
                if d > 0.02 { return SCNVector3(dx / d, 0, dz / d) }
            }
            return nil
        }

        /// 含加塞横向偏移的击球点（与编排台 `strikePosition(cue:)` 同逻辑）。
        private static func strikePosition(cue: SCNVector3, aim: SCNVector3, spinX: Double) -> SCNVector3 {
            let r = AngleSceneCalculator.ballRadius
            let perp = SCNVector3(-aim.z, 0, aim.x)
            let lateral = Float(spinX) * r
            return SCNVector3(cue.x + perp.x * lateral, cue.y, cue.z + perp.z * lateral)
        }

        private func polyline(_ pts: [SCNVector3], color: UIColor, radius: Float) -> [SCNNode] {
            guard pts.count >= 2 else { return [] }
            let lifted = pts.map { SCNVector3($0.x, yLevel, $0.z) }
            var nodes: [SCNNode] = []
            for i in 0..<(lifted.count - 1) {
                nodes.append(scene.addLine(from: lifted[i], to: lifted[i + 1],
                                           color: color, radius: radius))
            }
            return nodes
        }
    }

    // MARK: - Shot HUD (ADR-P11-13)

    /// 把本杆击球参数渲染成 HUD 条图（`ImageRenderer` 直接复用 App 组件，样式单一真源）。
    private static func makeHUDImage(shot: PlannedShot, options: Options) -> CGImage? {
        let strip = CGFloat(options.hudStripHeight)
        guard strip > 0 else { return nil }
        let renderer = ImageRenderer(content: ShotHUDView(
            spinX: shot.spinX, spinY: shot.spinY, velocity: shot.velocity, k: strip / 80
        ))
        renderer.scale = 1
        return renderer.cgImage
    }

    /// 场景帧 + HUD 条 → 最终输出帧（黑底画布，场景在上、HUD 条在下；hud 为 nil 时留空条）。
    private static func composeWithHUD(scene: CGImage, hud: CGImage?, options: Options) -> CGImage {
        let strip = options.hudStripHeight
        let w = Int(options.outputSize.width), h = Int(options.outputSize.height)
        guard strip > 0,
              let cg = CGContext(
                  data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return scene }
        cg.setFillColor(UIColor.black.cgColor)
        cg.fill(CGRect(x: 0, y: 0, width: w, height: h))
        // CGContext 原点在左下：场景画面置顶 → y 从 HUD 条高开始。
        cg.draw(scene, in: CGRect(x: 0, y: CGFloat(strip),
                                  width: options.size.width, height: options.size.height))
        if let hud {
            cg.draw(hud, in: CGRect(x: (w - hud.width) / 2, y: (strip - hud.height) / 2,
                                    width: hud.width, height: hud.height))
        }
        return cg.makeImage() ?? scene
    }

    /// HUD 条内容：打点（`BTSpinMiniIcon` 同款球面，无卡片底）+ 百分比读数 + 力度条 + 档名/数值。
    /// 设计基准 80px 条高（1280 宽），`k` 随条高等比缩放。
    private struct ShotHUDView: View {
        let spinX: Double
        let spinY: Double
        let velocity: Double
        var k: CGFloat = 1

        var body: some View {
            HStack(spacing: 28 * k) {
                HStack(spacing: 12 * k) {
                    // 真实比例（ADR-P11-13）：教学素材上的打点可照搬到真球，
                    // 红斑位置/大小与打点盘同一几何，含打滑极限虚线圈。
                    BTSpinMiniIcon(spinX: spinX, spinY: spinY, diameter: 56 * k, trueScale: true)
                    Text(SpinDisplay.readout(spinX: spinX, spinY: spinY))
                        .font(.system(size: 20 * k, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .monospacedDigit()
                }
                HStack(spacing: 12 * k) {
                    Capsule()
                        .fill(.white.opacity(0.16))
                        .frame(width: 220 * k, height: 8 * k)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.btPrimary)
                                .frame(width: 220 * k * powerFraction)
                        }
                    Text("\(PowerDisplay.name(velocity)) \(String(format: "%.1f", velocity)) m/s")
                        .font(.system(size: 20 * k, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 24 * k)
            .frame(height: 80 * k)
            // ImageRenderer 离屏渲染下防止文本被压窄竖排折行：按理想宽度展开。
            .fixedSize()
        }

        /// 填充比例与编排台力度滑条同量程（0.5–6.0 m/s）。
        private var powerFraction: CGFloat {
            CGFloat(min(max((velocity - 0.5) / 5.5, 0), 1))
        }
    }

    // MARK: - Helpers

    private static func holdFrames(_ seconds: Double, fps: Int) -> Int {
        max(1, Int(seconds * Double(fps)))
    }

    private static func estimatedFrameCount(sequence: PositionPlaySequence, options: Options) -> Int {
        // 粗估：开局静帧 + 每杆（设置静帧 + 运杆 ~0.9s + 平均 2.2s 运动 + 收尾静帧）。
        let initial = options.initialHold > 0 ? holdFrames(options.initialHold, fps: options.fps) : 0
        let setup = holdFrames(options.setupHold, fps: options.fps)
        let tail = holdFrames(options.tailHold, fps: options.fps)
        let stroke = options.showCueStroke
            ? Int(0.9 / Double(options.playbackSpeed) * Double(options.fps)) : 0
        let motion = Int(2.2 / Double(options.playbackSpeed) * Double(options.fps))
        return initial + sequence.steps.count * (setup + stroke + motion + tail)
    }

    private static func tempURL(ext: String, name: String) -> URL {
        let safe = name.replacingOccurrences(of: "/", with: "-")
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("\(safe)-\(UUID().uuidString.prefix(6)).\(ext)")
    }
}
