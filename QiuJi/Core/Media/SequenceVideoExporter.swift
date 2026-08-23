import SceneKit
import SwiftUI
import UIKit
import simd

/// 把走位序列渲染成 SceneKit 真台教学素材（ADR-P11-01 / ADR-P11-11）。
///
/// 复用 `AngleTrainingScene`（USDZ 球桌 + 现成球节点）与 `ShotPredictor`（多球求解）：
/// 逐 Step 摆 `before` 球形 → 真实模拟 → 用 `TrajectoryPlayback.stateAt(t)` 按固定帧率
/// 驱动全部在桌球节点 → `SCNRenderer.snapshot(atTime:)` 取帧。
///
/// 产物（ADR-P11-11 渲染矩阵）：
/// - 视频/GIF：`exportVideo` / `exportGIF`（整段或经 `subSequence` 单杆切片）；
/// - 教学静帧：`renderStills`（开局 / 每杆击球前：预告线 + 瞄准位球杆 + HUD / 终局）；
/// - 卡片素材：`renderCover`（封面）+ `renderPreviewFrames`（卡片动画帧序列），卡片风格球放大。
///
/// 轨迹线契约：**击球前静帧显示预告线（白=母球路线、橙=进球线），出杆瞬间清除**，
/// 运动帧始终无线（与编排台 App 内行为一致）。有预告线时同步摆静止瞄准位球杆
/// （与视频「亮方案」拍、DR-028 C1 同口径；开局/终局无线不摆杆）。
///
/// 击球参数 HUD（ADR-P11-13）：teaching 档画面底部追加暗色 HUD 条，显示本杆打点
/// （`BTSpinMiniIcon` 同款球面 + 百分比读数）与力度条（`PowerDisplay` 档名 + m/s），
/// 每杆常驻（设置帧→收尾帧）、换杆更新；HUD 视图经 `ImageRenderer` 直接复用 App 组件，
/// 与 App 内样式单一真源。场景背景改暗色与 App 场景页一致。
@MainActor
enum SequenceVideoExporter {

    // MARK: - Options

    /// 相机取景模式（ADR-P11-15）：顶视正交（教学静帧/2D 视频默认）或静态斜视角透视（3D 视频）。
    enum CameraMode {
        case topDown2D
        case perspective3D(Perspective3DConfig)
    }

    /// 静态斜视角（短边后方、沿长轴看进去）透视取景配置。
    /// 看全桌面 = 把球桌**外框 8 角点**全装进画面：相机只暴露「俯角 + FOV + 取景端」，
    /// 距离/高度由 `solvePerspectiveCamera` 按外框角点 + 视口宽高比自动解出（禁 magic number）。
    struct Perspective3DConfig {
        /// 相机机位所在的短库端（看向另一端）。`.plusX` = 相机在 +X 端看向 −X。
        enum NearEnd: Equatable { case plusX, minusX }
        /// 俯角（度，正值；越小越平视、越大越接近顶视）。下界受近库遮挡约束（≈28°）。
        var pitchDeg: Float = 30
        /// 竖直方向 FOV（度）；水平 FOV 由视口宽高比推出。
        var fovDeg: Float = 46
        var nearEnd: NearEnd = .plusX
        /// 看向点沿长轴偏移（米，正=偏远端，把远端抬入画面重心）。
        var lookAtBiasMeters: Float = 0
        /// 外框角点入框安全余量（比例）。
        var fitMargin: Float = 0.06
        /// 是否把整张桌（库顶 → 桌腿底/地面）都装进画面。false = 仅装库顶平面（旧行为，近端桌腿被裁）。
        var fitFullTableHeight: Bool = true
        /// 轨迹线半径放大（3D 远端线变细，补粗）。
        var lineRadiusScale: Float = 1.3
        /// studio 光照 + IBL + 接地阴影（`Scene3DAimingView` 同款，球读作立体接地）。
        var studioLook: Bool = true
    }

    struct Options {
        /// 相机取景模式。默认顶视 2D（不改变既有 2D 产物行为）。
        var cameraMode: CameraMode = .topDown2D
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
        /// 第1拍·读球形：每杆开始**只摆球**（无预告线/假想球/球杆/HUD）的观察停顿，给观众看清球形。
        /// 默认 0（仅教学视频档开启，GIF/卡片不开）。
        var observeHold: Double = 0
        /// 第2拍·亮方案 + 出杆前设置静帧时长（预告线 + 假想球 + 静止球杆 + HUD 可见段）。
        var setupHold: Double = 0.6
        var tailHold: Double = 0.8
        /// 球节点渲染缩放：1.0 = 真实比例（教学产物默认）；1.6 = 卡片风格（小尺寸可读）。
        var ballScale: Float = 1
        /// 击球前是否显示轨迹预告线；false = clean 版（全程无线）。
        var showTrajectories: Bool = true
        /// 导出预告线（瞄准线/进球线）粗细系数：<1 变细。**仅作用于导出线**——App 与导出共用
        /// `TrajectoryStyle` 常量，此系数只在导出器 `drawAimLines` 叠加，故不影响 App。
        /// 默认 1（教学视频档取 0.65 变细）。
        var aimLineScale: Float = 1
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
            // 竖版按宽度等比（720→80、1440→160），保证高分档 HUD 文本同样可读；
            // 横版维持原口径（1280→80）不动既有 2D 静帧产物。
            return portrait
                ? Int((size.width / 720 * 80).rounded())
                : Int((size.width * 0.0625).rounded())
        }

        /// 最终输出像素尺寸（场景画面 + HUD 条）。
        var outputSize: CGSize {
            CGSize(width: size.width, height: size.height + CGFloat(hudStripHeight))
        }

        /// 教学真实风格（竖版静帧用，#5b）：球桌长轴沿屏幕长边竖直铺满，
        /// 1440×2560 场景（rotated 顶视）+ 160px HUD 条（合计 1440×2720）。
        /// 静帧高于视频档，便于精讲页放大查看球/线仍清晰。
        static func teaching() -> Options {
            var o = Options()
            o.size = CGSize(width: 1440, height: 2560)
            o.portrait = true
            return o
        }

        /// 教学视频（竖版，App 内竖屏播放主载体）：1080×1920 竖版场景（rotated 顶视，
        /// 台面长轴竖直铺满）+ 120px HUD 条（合计 1080×2040）。
        /// 介于旧 720 档与 1440 静帧之间，兼顾清晰度与体积（正式分发走 OTA）。
        static func teachingVideo() -> Options {
            var o = Options()
            o.size = CGSize(width: 1080, height: 1920)
            o.portrait = true
            // 三拍教学叙事：读球形 1.5s → 亮方案 1.5s → 执行；预告线变细。
            o.observeHold = 1.5
            o.setupHold = 1.5
            o.aimLineScale = 0.65
            return o
        }

        /// 卡片风格：1280×640、球放大 1.6，仅用于封面静帧与卡片动画帧序列。
        static func card() -> Options {
            var o = Options()
            o.size = CGSize(width: 1280, height: 640)
            o.ballScale = 1.6
            o.showShotHUD = false
            return o
        }

        /// 分享 GIF（竖版，#5b）：球桌长轴沿屏幕长边竖直铺满，与静帧/视频取向一致。
        /// 720×1280 原速（预览/分享媒介，非教学主载体；GIF 256 色 + 体积约束下不拉满到视频档）。
        static func gif() -> Options {
            var o = Options()
            o.size = CGSize(width: 720, height: 1280)
            o.portrait = true
            o.fps = 12
            o.playbackSpeed = 1.0
            o.showShotHUD = false
            // 分享 GIF 要短平快：跳过读球形 / 亮方案两拍静停（线在运杆起手时出现）。
            o.observeHold = 0
            o.setupHold = 0
            return o
        }

        /// 3D 教学视频（手机档，App 内竖屏播放主载体，ADR-P11-15）：1080×1920 竖屏 +
        /// 静态斜视角透视（短边后方沿长轴）+ 120px HUD 条（合计 1080×2040），与 2D 视频同档。
        static func teachingVideo3D() -> Options {
            var o = Options()
            o.size = CGSize(width: 1080, height: 1920)
            o.portrait = true
            o.cameraMode = .perspective3D(Perspective3DConfig())
            // 三拍教学叙事：读球形 1.5s → 亮方案 1.5s → 执行；预告线变细（高分档 Hi 继承本预设）。
            o.observeHold = 1.5
            o.setupHold = 1.5
            o.aimLineScale = 0.65
            return o
        }

        /// 3D 教学视频（高分档，外站备用）：2160×3840（4K 竖版）+ 240px HUD 条（合计 2160×4080）。
        /// 当前出片默认配方**不调用**本档（用户拍板：本地预览/回填阶段不出 4K）。
        static func teachingVideo3DHi() -> Options {
            var o = teachingVideo3D()
            o.size = CGSize(width: 2160, height: 3840)
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

    /// 教学静帧：`initial` 开局、`s0n_still` 每杆击球前（预告线 + 瞄准位球杆 + HUD）、`final` 终局。
    ///
    /// 开局图取「第一杆击球前」盘面（`steps[0].before`），不盲信 `sequence.initial`。
    /// 批量录制序列里 `initial` 常只剩母球，而真实开局在首杆 `before`（2026-08-03 实测 61 条）。
    /// 逐杆静帧与视频「亮方案」拍同口径：有预告线且 `showCueStroke`、杆可解时 `showCueAtRest`；
    /// 开局/终局无线，不摆杆。拍完藏杆，避免终局图吃到上一杆残留。
    static func renderStills(
        sequence: PositionPlaySequence,
        options: Options = .teaching()
    ) -> [(name: String, image: CGImage)] {
        guard let ctx = RenderContext(options: options) else { return [] }
        var out: [(String, CGImage)] = []

        let openingBoard = sequence.steps.first?.before ?? sequence.initial
        if openingBoard.onTable.count != sequence.initial.onTable.count {
            print("SEQ-EXPORT ⚠️ \(sequence.name)：initial 球数 \(sequence.initial.onTable.count)"
                  + " ≠ 首杆 before \(openingBoard.onTable.count)，开局图改用首杆 before")
        }
        ctx.placeBoard(openingBoard)
        if let img = ctx.snapshot() { out.append(("initial", img)) }

        for (i, step) in sequence.steps.enumerated() {
            ctx.placeBoard(step.before)
            ctx.scene.hideCueStick()
            let pred = options.showTrajectories
                ? PositionPlayShotSolver.solve(
                    before: step.before, shot: step.shot, surfaceY: ctx.surfaceY)
                : nil
            let lines = options.showTrajectories
                ? ctx.drawAimLines(for: step, prediction: pred)
                : []
            if options.showCueStroke, let pred, pred.feasible {
                _ = ctx.showCueAtRest(step: step, prediction: pred)
            }
            let hud = options.showShotHUD ? makeHUDImage(shot: step.shot, options: options) : nil
            if let img = ctx.snapshot() {
                let framed = options.showShotHUD ? composeWithHUD(scene: img, hud: hud, options: options) : img
                out.append((String(format: "s%02d_still", i + 1), framed))
            }
            lines.forEach { $0.removeFromParentNode() }
            ctx.hideAimDecorations()
            ctx.scene.hideCueStick()
        }

        if let last = sequence.steps.last {
            ctx.placeBoard(last.after)
            ctx.scene.hideCueStick()
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

        // 每帧包 autoreleasepool：高分辨率下单帧位图 16–35MB（1440/4K），长循环里
        // `ctx.snapshot()` 产出的 UIImage/CGImage 若不及时释放会累积到 jetsam 被 SIGKILL
        // （旧 720 档 ~4MB/帧侥幸不越线，提分辨率后必越线）。pool 把驻留压到 ~1 帧。
        func snapshot() throws {
            try autoreleasepool {
                guard let img = ctx.snapshot() else { return }
                try emit(options.showShotHUD ? composeWithHUD(scene: img, hud: currentHUD, options: options) : img)
            }
        }

        // 开局静帧（可选；连续录制序列与首杆设置静帧重复，默认跳过）。
        if options.initialHold > 0 {
            ctx.placeBoard(sequence.initial)
            for _ in 0..<holdFrames(options.initialHold, fps: fps) { try snapshot() }
        }

        for step in sequence.steps {
            ctx.placeBoard(step.before)
            ctx.scene.hideCueStick()
            // 第1拍·读球形：只摆球，HUD 置空（不剧透打点/力度），预告线/假想球/球杆均不出现。
            currentHUD = nil

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

            // 第1拍·读球形停顿：仅摆球，给观众观察局面的时间（教学视频档 1.5s；GIF/卡片档为 0 跳过）。
            for _ in 0..<holdFrames(options.observeHold, fps: fps) { try snapshot() }

            // 第2拍·亮方案：预告线 + 假想球 + 静止瞄准位球杆 + HUD 一起出现并停顿观察。
            // 预告线/假想球在运杆/出杆全程**保留**，直到触球瞬间才清除（ADR-P11-11 轨迹契约）。
            currentHUD = options.showShotHUD ? makeHUDImage(shot: step.shot, options: options) : nil
            let lines = options.showTrajectories ? ctx.drawAimLines(for: step, prediction: pred) : []
            _ = options.showCueStroke ? ctx.showCueAtRest(step: step, prediction: pred) : nil
            for _ in 0..<holdFrames(options.setupHold, fps: fps) { try snapshot() }

            // 运杆/出杆动画（#10，与编排台同源）：回杆→蓄力→匀加速出杆，渲染到触球为止。
            // 跟杆/短停改由下面的运动帧循环**并行叠加**：母球离位与球杆送杆同刻发生，
            // 杜绝导出中「球静止时杆头穿过母球」（App 实时路径本就并行，此处对齐）。
            var cueAnchor: RenderContext.CueStrokeAnchor?
            if options.showCueStroke {
                cueAnchor = try ctx.renderStrokeToContact(step: step, prediction: pred,
                                                          fps: fps, speed: options.playbackSpeed,
                                                          snapshot: snapshot)
            }
            // 触球瞬间清线、收掉假想球（运动/跟杆期间不再显示预告线）。
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
            // 跟杆叠加时窗（模拟秒）：0→followSim 送杆，随后 holdSim 短停，之后收杆。
            // Clearance：与实时 `runCueStroke` 同口径——全场球探测，预测碰撞则提前抽杆淡出。
            let followSim = Float(CueStroke.followThroughDuration)
            let holdSim = Float(CueStroke.exportFollowThroughHold) * options.playbackSpeed
            var cueOverlayEndSim = followSim + holdSim
            if var anchor = cueAnchor,
               let tStar = CueClearance.firstCollisionTime(
                strikePosition: anchor.strikePos,
                aimDirection: anchor.aim,
                elevation: anchor.elevation,
                endPull: anchor.endPull,
                holdDuration: TimeInterval(holdSim),
                ballsAt: { playback.allBallCentersByName(at: Float($0)) }
               ) {
                let retractStart = max(0, Float(tStar - CueClearance.retractLead))
                cueOverlayEndSim = retractStart + Float(CueClearance.retractFade)
                anchor.collisionRetractStart = retractStart
                cueAnchor = anchor
            }
            // 循环至少跑到跟杆结束：短杆（球早停）时也保证跟杆完整播完再收杆。
            let loopEndSim = max(duration + tailSim, cueAnchor != nil ? cueOverlayEndSim : 0)
            var cueHidden = false
            var potTimes: [String: Float] = [:]
            var potEntries: [String: (start: SCNVector3, legs: [TrajectoryPlayback.PocketEntryLeg])] = [:]
            var lastVel: [String: SCNVector3] = [:]
            // 逐帧自转：记录各球上一帧角速度，与本帧取均值做梯形积分（与 App `action(for:)` 同源）。
            var lastOmega: [String: SCNVector3] = [:]
            let frameSimDt = Float(1.0 / Double(fps)) * options.playbackSpeed
            var t: Float = 0
            while t <= loopEndSim + 1e-4 {
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
                            // 3D 斜视下进袋须真「落袋」：到达袋心后沿 Y 下沉再淡出，
                            // 否则球在台面平面凭空淡掉会穿帮（仅导出层加 Y，不动物理）。
                            if ctx.is3D, real > entryEnd {
                                let sink = max(0, min(1, (real - entryEnd) / (pause + fade)))
                                let p = node.position
                                node.position = SCNVector3(p.x, ctx.yLevel - Float(sink) * 0.07, p.z)
                            }
                        }
                    } else {
                        node.position = SCNVector3(s.position.x, ctx.yLevel, s.position.z)
                        node.opacity = 1
                        lastVel[key] = s.velocity
                        // 球面自转：按引擎角速度 ω 逐帧四元数积分（v17，与 App
                        // `TrajectoryPlayback.action` 同一口径 `BallSpinIntegrator`），
                        // 加塞竖轴自转、低杆倒旋、定杆不转在导出视频里与 App 内一致。
                        if let prev = lastOmega[key] {
                            BallSpinIntegrator.advance(node: node, from: prev,
                                                       to: s.angularVelocity, dt: frameSimDt)
                        }
                        lastOmega[key] = s.angularVelocity
                    }
                }
                // 跟杆叠加：球杆锚定在击球点；仰角整杆冻结（elevationOverride），与实时同口径。
                if let anchor = cueAnchor, !cueHidden {
                    if let retractStart = anchor.collisionRetractStart, t >= retractStart - 1e-4 {
                        let u = min(1, max(0, (t - retractStart) / Float(CueClearance.retractFade)))
                        let pullAt = CueClearance.pullBackAfterContact(
                            tau: TimeInterval(retractStart), endPull: anchor.endPull
                        )
                        let pull = pullAt + u * (CueClearance.retractPullExtra - min(0, pullAt))
                        ctx.scene.updateCueStick(
                            cueBallPosition: anchor.strikePos, aimDirection: anchor.aim,
                            pullBack: pull, elevationOverride: anchor.elevation
                        )
                        ctx.scene.cueStick?.rootNode.opacity = CGFloat(1 - u)
                        if u >= 1 - 1e-3 {
                            ctx.scene.hideCueStick()
                            cueHidden = true
                        }
                    } else if t <= followSim + 1e-4 {
                        ctx.scene.updateCueStick(
                            cueBallPosition: anchor.strikePos, aimDirection: anchor.aim,
                            pullBack: CueStroke.followThrough(at: TimeInterval(t), endPull: anchor.endPull),
                            elevationOverride: anchor.elevation
                        )
                    } else if t <= cueOverlayEndSim + 1e-4 {
                        ctx.scene.updateCueStick(
                            cueBallPosition: anchor.strikePos, aimDirection: anchor.aim,
                            pullBack: anchor.endPull, elevationOverride: anchor.elevation
                        )
                    } else {
                        ctx.scene.hideCueStick()
                        cueHidden = true
                    }
                }
                try snapshot()
                t += frameSimDt
            }
            if cueAnchor != nil, !cueHidden { ctx.scene.hideCueStick() }

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
        /// 静态斜视角透视档（影响进袋 Y 下沉、轨迹线加粗等 3D 专属契约）。
        let is3D: Bool
        /// 轨迹线半径放大系数（3D 远端补粗；2D 恒 1）。
        let lineScale: Float
        private let renderer: SCNRenderer
        private let options: Options
        private var clock: TimeInterval = 0
        private let frameDt: TimeInterval

        init?(options: Options) {
            guard let device = MTLCreateSystemDefaultDevice() else { return nil }

            let persp: Perspective3DConfig?
            switch options.cameraMode {
            case .perspective3D(let c): persp = c
            case .topDown2D: persp = nil
            }
            self.is3D = persp != nil
            self.lineScale = persp?.lineRadiusScale ?? 1

            let scene = AngleTrainingScene()
            // 3D 档启用 studio 光照 + IBL + 接地阴影（与 Scene3DAimingView 同款，球读作立体接地）。
            scene.setupScene(enhancedRendering: persp?.studioLook ?? false)
            guard scene.cameraNode != nil else { return nil }
            // 暗色背景与 App 场景页一致（ADR-P11-13）；HUD 白字依赖暗底可读。
            scene.background.contents = UIColor.black
            scene.hideAllBalls()
            scene.hideCueStick()
            // 预创建假想球等可视化节点（默认隐藏，drawAimLines 按需点亮）。
            scene.setupVisualizationNodes()
            scene.hideAllVisualization()

            if let cfg = persp {
                // 静态斜视角透视（短边后方沿长轴）：解出机位 → 直接驱动 cameraNode，
                // 帧循环不动相机（与「静态斜视角」决策一致）。FOV 锁竖直方向使 fit 数学确定。
                let cam = scene.cameraNode!.camera!
                cam.usesOrthographicProjection = false
                cam.projectionDirection = .vertical
                cam.fieldOfView = CGFloat(cfg.fovDeg)
                cam.zNear = 0.05
                cam.zFar = 100
                let sol = SequenceVideoExporter.solvePerspectiveCamera(
                    config: cfg, renderSize: options.size, surfaceY: scene.surfaceY,
                    tableBottomY: scene.measuredTableBottomY()
                )
                scene.cameraNode!.position = sol.position
                scene.cameraNode!.look(
                    at: sol.lookAt, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1)
                )
            } else if let rig = scene.cameraRig {
                // 顶视正交相机，覆盖整张台。竖版复用 rig 的 rotated 取景（台面长轴竖直铺满，
                // 与 App 内 2D 球桌页同一套，ADR-P11-08）；横版用固定 scale 的横向顶视。
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

        /// 首帧新摆球随机母球朝向；后续杆保留上一杆回放终态（`.unchanged`）。
        private var hasSeatedCuePose = false

        func placeBoard(_ board: BoardSnapshot) {
            scene.hideAllBalls()
            let cuePose: CueBallPosePolicy = hasSeatedCuePose ? .unchanged : .reseat
            hasSeatedCuePose = true
            for (key, pt) in board.onTable {
                let p = AngleSceneCalculator.normalizedToScene(
                    point: CGPoint(x: pt.x, y: pt.y), surfaceY: surfaceY
                )
                scene.showBall(key: key, scenePosition: p,
                               cuePose: PositionPlayBall.isCue(key) ? cuePose : .home)
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
            // 导出线粗细 = 基础常量 × 3D 远端补粗系数 × 导出变细系数（App 不受影响）。
            let aimR = TrajectoryStyle.aimRadius * lineScale * options.aimLineScale
            let potR = TrajectoryStyle.potRadius * lineScale * options.aimLineScale
            var lines: [SCNNode] = []
            // 线语言 v2（条 12，渲染管线与 App 同源）：母球碰前白实线 + 碰后白虚线；
            // 目标球/联动球本色虚线（extraBallPaths 键 = 桌面球键）。
            let liftedCue = pred.cuePath.map { SCNVector3($0.x, yLevel, $0.z) }
            let liftedContact = pred.firstContact.map { SCNVector3($0.x, yLevel, $0.z) }
            var cueNodes: [SCNNode] = []
            scene.addCueTrajectory(liftedCue, contact: liftedContact, into: &cueNodes)
            // 导出线宽需按 3D 远端补粗 × 导出变细缩放——覆写共享方法产出的半径。
            for n in cueNodes { (n.geometry as? SCNCylinder)?.radius = CGFloat(aimR) }
            lines.append(contentsOf: cueNodes)
            var objNodes: [SCNNode] = []
            scene.addObjectTrajectory(objPath.map { SCNVector3($0.x, yLevel, $0.z) },
                                      ballKey: step.shot.targetKey, into: &objNodes)
            for (key, pts) in pred.extraBallPaths {
                scene.addObjectTrajectory(pts.map { SCNVector3($0.x, yLevel, $0.z) },
                                          ballKey: key, into: &objNodes)
            }
            for n in objNodes { (n.geometry as? SCNCylinder)?.radius = CGFloat(potR) }
            lines.append(contentsOf: objNodes)
            // 假想球：袋口模式显示在母球瞄准终点（重叠标注 L0：绿虚线圈 + 接触点绿点，
            // 与 App 内同语义同源，T-P18-42）。
            if !step.shot.isFree, let ghost = scene.ghostBallNode {
                ghost.position = SCNVector3(pred.ghost.x, yLevel, pred.ghost.z)
                ghost.isHidden = false
                if let target = scene.allBallNodes[step.shot.targetKey], !target.isHidden {
                    scene.updateContactDot(ghostCenter: ghost.position,
                                           targetCenter: target.position)
                }
            }
            return lines
        }

        /// 收掉假想球等非线节点装饰（与移除 `drawAimLines` 返回的线节点配套调用）。
        func hideAimDecorations() {
            scene.ghostBallNode?.isHidden = true
            scene.hideContactDot()
        }

        /// Frozen cue pose for follow-through overlay (elevation frozen for whole stroke).
        struct CueStrokeAnchor {
            let strikePos: SCNVector3
            let aim: SCNVector3
            let elevation: Float
            let endPull: Float
            /// When set, start retract+fade at this sim-time (seconds after contact).
            var collisionRetractStart: Float?
        }

        /// 第2拍·亮方案：把球杆摆到**静止瞄准位**（`pullBack=0`，杆头贴母球击球点）并显示。
        /// 母球此刻未动，锚点与随后 `renderStrokeToContact` 一致，故起杆无缝衔接。
        /// 无球杆节点 / 瞄准方向缺失时不显示。Blocked elevation → hide.
        @discardableResult
        func showCueAtRest(step: SequenceStep, prediction: ShotPrediction)
            -> CueStrokeAnchor? {
            guard let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
                  let aim = Self.aimDirection(path: prediction.cuePath, from: cueNode.position)
            else { return nil }
            let strikePos = CueStroke.strikePosition(cue: cueNode.position, aim: aim, spinX: step.shot.spinX)
            let obstacles = scene.cueObstacleCenters(excludingStrikeNear: strikePos)
            switch CueStick.requiredElevation(
                cueBallPosition: strikePos, aimDirection: aim, obstacleCenters: obstacles
            ) {
            case .blocked:
                scene.hideCueStick()
                return nil
            case .angle(let elev):
                let endPull = CueStroke.clampedFollowThroughPull(
                    cueBallPosition: strikePos, aimDirection: aim, obstacleCenters: obstacles
                )
                scene.updateCueStick(
                    cueBallPosition: strikePos, aimDirection: aim, pullBack: 0,
                    elevationOverride: elev
                )
                return CueStrokeAnchor(strikePos: strikePos, aim: aim, elevation: elev,
                                       endPull: endPull, collisionRetractStart: nil)
            }
        }

        /// 逐帧渲染一杆的运杆/出杆动画**直到触球**：回杆 smoothstep → 蓄力停顿 → 匀加速出杆，
        /// 触球瞬间杆速 = 目标球速 v。`speed` 与运动帧同一倍速，使运杆/击球节奏一致。
        /// 返回击球锚点（含冻结仰角与钳制跟杆量）供触球后的跟杆叠加使用；无球杆/瞄准方向时返回 nil。
        ///
        /// **跟杆/短停不在此处**：改由运动帧循环与球运动**并行**驱动（母球一边离位、球杆一边送杆），
        /// 与实时场景一致——否则球静止时杆头越过母球原中心会视觉穿球（导出专属回归修复）。
        func renderStrokeToContact(step: SequenceStep, prediction: ShotPrediction,
                                   fps: Int, speed: Float, snapshot: () throws -> Void) rethrows
            -> CueStrokeAnchor? {
            guard let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
                  let aim = Self.aimDirection(path: prediction.cuePath, from: cueNode.position)
            else { return nil }
            let strikePos = CueStroke.strikePosition(cue: cueNode.position, aim: aim, spinX: step.shot.spinX)
            let obstacles = scene.cueObstacleCenters(excludingStrikeNear: strikePos)
            guard case .angle(let elev) = CueStick.requiredElevation(
                cueBallPosition: strikePos, aimDirection: aim, obstacleCenters: obstacles
            ) else {
                scene.hideCueStick()
                return nil
            }
            let endPull = CueStroke.clampedFollowThroughPull(
                cueBallPosition: strikePos, aimDirection: aim, obstacleCenters: obstacles
            )
            let v = max(0.3, Float(step.shot.velocity))
            let total = CueStroke.totalDuration(velocity: v)

            let dt = Float(speed) / Float(max(1, fps))
            var t: Float = 0
            while t <= Float(total) + 1e-4 {
                let pull = CueStroke.pullBack(at: TimeInterval(t), velocity: v)
                scene.updateCueStick(
                    cueBallPosition: strikePos, aimDirection: aim, pullBack: pull,
                    elevationOverride: elev
                )
                try snapshot()
                t += dt
            }
            return CueStrokeAnchor(strikePos: strikePos, aim: aim, elevation: elev,
                                   endPull: endPull, collisionRetractStart: nil)
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

    }

    // MARK: - Shot HUD (ADR-P11-13)

    /// 把本杆击球参数渲染成 HUD 条图（`ImageRenderer` 直接复用 App 组件，样式单一真源）。
    private static func makeHUDImage(shot: PlannedShot, options: Options) -> CGImage? {
        let strip = CGFloat(options.hudStripHeight)
        guard strip > 0 else { return nil }
        let k = strip / 80
        let renderer = ImageRenderer(content: BTShotHUDBar(
            spinX: shot.spinX, spinY: shot.spinY, velocity: shot.velocity,
            k: k, powerBarWidth: 220 * k, fixedWidth: true
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

    // MARK: - Perspective fit (ADR-P11-15)

    /// 球桌外框半长（世界 X，长轴）/ 半宽（世界 Z，短轴），来自 `CameraRig` 装桌实测。
    static let tableOuterHalfLength: Float = 1.4055
    static let tableOuterHalfWidth: Float = 0.7995

    /// 解出静态斜视角相机位姿：固定俯角 + FOV，沿后退方向二分推距离 `D`，
    /// 使球桌外框 8 角点（库顶高）全部落入画面（含 `fitMargin` 余量）。
    /// 因球恒在 playfield 内（除非进袋），外框装下即「任意一杆所有在桌球可见」（与球形无关的不变量）。
    /// 返回相机世界坐标 + 看向点 + 解出的距离。
    nonisolated static func solvePerspectiveCamera(
        config: Perspective3DConfig,
        renderSize: CGSize,
        surfaceY: Float,
        tableBottomY: Float? = nil
    ) -> (position: SCNVector3, lookAt: SCNVector3, distance: Float) {
        let sign: Float = (config.nearEnd == .plusX) ? 1 : -1
        let th = config.pitchDeg * .pi / 180
        // 朝远端（−sign·X）并向下俯 th 的单位视线。
        let viewDir = SCNVector3(-sign * cosf(th), -sinf(th), 0).normalized()
        let railTop = surfaceY + 0.05
        // 桌腿底真实世界 Y：优先用实测值（模型按外框长宽缩放、非按高度，桌腿底无法由常量推得）；
        // 缺省退回「台面下一个桌高」的近似。fit 需装下整桌（库顶 → 桌腿底），否则近端桌腿掉出画面底被裁。
        let legBottom = config.fitFullTableHeight
            ? (tableBottomY ?? surfaceY - BTTablePhysics.height)
            : railTop
        // 看向点取桌体垂直中点：让整桌（含腿）在画幅内上下居中，避免顶部留黑或底部裁腿。
        let lookAtY = (railTop + legBottom) / 2
        let lookAt = SCNVector3(-sign * config.lookAtBiasMeters, lookAtY, 0)

        let halfL = tableOuterHalfLength, halfW = tableOuterHalfWidth
        let corners: [SCNVector3] = [railTop, legBottom].flatMap { y in
            [SCNVector3(-halfL, y, -halfW), SCNVector3(-halfL, y, halfW),
             SCNVector3( halfL, y, -halfW), SCNVector3( halfL, y, halfW)]
        }
        let aspect = Float(renderSize.width / renderSize.height)
        let vfov = config.fovDeg * .pi / 180
        let hfov = 2 * atanf(aspect * tanf(vfov / 2))
        let halfV = vfov / 2 * (1 - config.fitMargin)
        let halfH = hfov / 2 * (1 - config.fitMargin)

        func fits(_ D: Float) -> Bool {
            let cam = lookAt - viewDir * D
            let f = viewDir
            let right = f.cross(SCNVector3(0, 1, 0)).normalized()
            let upC = right.cross(f).normalized()
            for p in corners {
                let v = p - cam
                let depth = v.dot(f)
                if depth <= 0 { return false }
                if abs(atan2f(v.dot(right), depth)) > halfH { return false }
                if abs(atan2f(v.dot(upC), depth)) > halfV { return false }
            }
            return true
        }

        // 二分最小可行距离（越远角度越小越易装下 → 求最近能看全的机位）。
        var lo: Float = 0.5, hi: Float = 15
        for _ in 0..<60 {
            let mid = (lo + hi) / 2
            if fits(mid) { hi = mid } else { lo = mid }
        }
        let D = hi
        return (lookAt - viewDir * D, lookAt, D)
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
