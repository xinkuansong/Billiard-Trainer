import SceneKit
import UIKit

/// 把走位序列渲染成 SceneKit 真台逐帧视频 / GIF（ADR-P11-01）。
///
/// 复用 `AngleTrainingScene`（USDZ 球桌 + 现成球节点）与 `ShotPredictor`（多球求解）：
/// 逐 Step 摆 `before` 球形 → 真实模拟 → 用 `TrajectoryPlayback.stateAt(t)` 按固定帧率
/// 驱动全部在桌球节点 → `SCNRenderer.snapshot(atTime:)` 取帧 → 喂 `VideoWriter`(mp4) / `GIFEncoder`。
@MainActor
enum SequenceVideoExporter {

    struct Options {
        var size: CGSize = CGSize(width: 640, height: 320)
        var fps: Int = 30
        var playbackSpeed: Float = 1.3
        var setupHold: Double = 0.6
        var tailHold: Double = 0.8
        var ballScale: Float = 1.6
        init() {}
    }

    private static let cueColor = UIColor.white.withAlphaComponent(0.95)
    private static let objectColor = UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.95)

    // MARK: - Public

    /// 导出 mp4 到临时目录，返回文件 URL。`progress` ∈ [0,1]。
    static func exportVideo(
        sequence: PositionPlaySequence,
        options: Options = Options(),
        progress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let url = tempURL(ext: "mp4", name: sequence.name)
        let writer = try VideoWriter(url: url, size: options.size, fps: options.fps)
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

    /// 导出 GIF 到临时目录（降采样到较低帧率/尺寸以控体积），返回文件 URL。
    static func exportGIF(
        sequence: PositionPlaySequence,
        progress: ((Double) -> Void)? = nil
    ) throws -> URL {
        var options = Options()
        options.size = CGSize(width: 400, height: 200)
        options.fps = 12
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

    // MARK: - Frame generation

    /// 逐帧生成回调：每帧渲染一张 `CGImage` 交给 `emit`（流式，便于视频边渲边写）。
    static func renderFrames(
        sequence: PositionPlaySequence,
        options: Options,
        emit: (CGImage) throws -> Void
    ) throws {
        guard let device = MTLCreateSystemDefaultDevice() else { return }

        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        guard scene.cameraNode != nil else { return }
        scene.hideAllBalls()
        scene.hideCueStick()

        // 顶视正交相机，覆盖整张台。
        if let rig = scene.cameraRig {
            rig.topDownOrthographicScale = 0.86
            rig.topDownPanOffset = .zero
            rig.applyTopDown2D()
        }
        // 放大球节点，提升视觉可读性（顶视下只影响视觉大小）。
        for (_, node) in scene.allBallNodes where options.ballScale != 1 {
            node.scale = SCNVector3(node.scale.x * options.ballScale,
                                    node.scale.y * options.ballScale,
                                    node.scale.z * options.ballScale)
        }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.autoenablesDefaultLighting = false

        let surfaceY = scene.surfaceY
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        var clock: TimeInterval = 0
        let frameDt = 1.0 / Double(max(1, options.fps))

        func snapshot() throws {
            let image = renderer.snapshot(atTime: clock, with: options.size,
                                          antialiasingMode: .multisampling4X)
            if let cg = image.cgImage { try emit(cg) }
            clock += frameDt
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

        // 起始球形（开局）静帧。
        placeBoard(sequence.initial)
        for _ in 0..<holdFrames(options.setupHold, fps: options.fps) { try snapshot() }

        for step in sequence.steps {
            placeBoard(step.before)

            // 求解本杆（多球；自由球走直瞄模拟）。
            guard let pred = PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: surfaceY),
                  pred.feasible,
                  let recorder = pred.recorder, pred.duration > 0.02 else {
                // 不可行：直接跳到 after 球形，给一小段静帧。
                placeBoard(step.after)
                for _ in 0..<holdFrames(options.tailHold, fps: options.fps) { try snapshot() }
                continue
            }

            // 轨迹线（贯穿本杆，教学可见）。进球线延伸到袋口圆边缘（#8，与编排台同源）。
            var objPath = pred.objectPath
            if pred.objectPocketed, !step.shot.isFree,
               let pocketIndex = ShotIntent.pocketIndex(for: step.shot.pocket) {
                objPath = PositionPlayShotSolver.extendPathToPocketRim(
                    objPath, pocketIndex: pocketIndex, surfaceY: surfaceY
                )
            }
            var lines: [SCNNode] = []
            lines.append(contentsOf: polyline(pred.cuePath, color: cueColor, scene: scene, y: yLevel))
            lines.append(contentsOf: polyline(objPath, color: objectColor, scene: scene, y: yLevel))
            for (_, pts) in pred.extraBallPaths {
                lines.append(contentsOf: polyline(pts, color: objectColor, scene: scene, y: yLevel))
            }

            // 设置静帧（含轨迹）。
            for _ in 0..<holdFrames(options.setupHold, fps: options.fps) { try snapshot() }

            // 运动帧。进袋「匀速入洞 → 撞远端袋弧 → 袋心停顿 → 淡出」
            // （#4 v2，与编排台 `TrajectoryPlayback` 同源求解）。
            let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
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
                    guard let node = scene.allBallNodes[key], let name = nameMap[key],
                          let s = playback.stateAt(ballName: name, time: min(t, duration)) else { continue }
                    if s.motionState == .pocketed {
                        if potTimes[key] == nil {
                            potTimes[key] = t
                            // 捕获点（上一帧真实位置）+ 进袋时真实速度 → 入洞段。
                            let pocket = TrajectoryPlayback.nearestPocket(to: node.position, surfaceY: yLevel)
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
                        node.position = SCNVector3(s.position.x, yLevel, s.position.z)
                        node.opacity = 1
                        lastVel[key] = s.velocity
                    }
                }
                try snapshot()
                t += Float(frameDt) * options.playbackSpeed
            }

            for line in lines { line.removeFromParentNode() }

            // 收尾：after 球形（进袋离场）静帧。
            placeBoard(step.after)
            for _ in 0..<holdFrames(options.tailHold, fps: options.fps) { try snapshot() }
        }
    }

    // MARK: - Helpers

    private static func polyline(_ pts: [SCNVector3], color: UIColor, scene: AngleTrainingScene, y: Float) -> [SCNNode] {
        guard pts.count >= 2 else { return [] }
        var nodes: [SCNNode] = []
        let lifted = pts.map { SCNVector3($0.x, y, $0.z) }
        for i in 0..<(lifted.count - 1) {
            nodes.append(scene.addLine(from: lifted[i], to: lifted[i + 1], color: color, radius: 0.006))
        }
        return nodes
    }

    private static func holdFrames(_ seconds: Double, fps: Int) -> Int {
        max(1, Int(seconds * Double(fps)))
    }

    private static func estimatedFrameCount(sequence: PositionPlaySequence, options: Options) -> Int {
        // 粗估：开局静帧 + 每杆（设置静帧 + 平均 2.2s 运动 + 收尾静帧）。
        let setup = holdFrames(options.setupHold, fps: options.fps)
        let tail = holdFrames(options.tailHold, fps: options.fps)
        let motion = Int(2.2 / Double(options.playbackSpeed) * Double(options.fps))
        return setup + sequence.steps.count * (setup + motion + tail)
    }

    private static func tempURL(ext: String, name: String) -> URL {
        let safe = name.replacingOccurrences(of: "/", with: "-")
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("\(safe)-\(UUID().uuidString.prefix(6)).\(ext)")
    }
}
