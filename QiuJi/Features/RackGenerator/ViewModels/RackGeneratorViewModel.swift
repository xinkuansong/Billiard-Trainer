//
//  RackGeneratorViewModel.swift
//  QiuJi
//
//  P17「球形生成器」UI 层（ADR-P17-01）。复用 `AngleTrainingScene` + `AngleSceneView`：
//  选玩法 → 摆好球架（`RackLayout`）→ 拖母球定开球区/角度（**自动锁顶球**瞄准）→ 设力度/打点
//  → 真实物理开球（`BreakSimulator`，livesim）→ 回放散开动画 → 停稳后把散开 `BoardSnapshot`
//  交付给走位编排台 / 思路训练器。
//
//  WYSIWYG（用户拍板）：不做可玩性筛选；废局（刮杆 / 8 号落袋）只提示，由用户「换一局」。
//  斯诺克不接开球（用户拍板）。无 Freemium 闸、暂不接开球音效（用户拍板）。
//

import Foundation
import SceneKit
import SwiftUI

@MainActor
final class RackGeneratorViewModel: ObservableObject {

    // MARK: - Phase

    enum Phase: Equatable {
        /// 球架摆好、母球可拖、待开球。
        case racked
        /// 物理求解中（后台）。
        case computing
        /// 开球动画回放中。
        case breaking
        /// 已停稳，可交付。
        case settled
    }

    // MARK: - Game selection

    /// UI 玩法大类：中式八球 / 9 球（含 4/5/6 少球玩法与标准 9 球）。
    enum GameKind: Equatable { case eightBall, zhuifen }

    /// 9 球系可选球数（9 球走钻石阵 `nineBall`，4/5/6 走少球布局 `zhuifen`）。
    static let zhuifenOptions = [4, 5, 6, 9]

    @Published var gameKind: GameKind = .eightBall {
        didSet { if oldValue != gameKind { rebuildRack(resetSeed: true) } }
    }
    @Published var zhuifenBalls = 9 {
        didSet { if oldValue != zhuifenBalls { rebuildRack(resetSeed: true) } }
    }

    /// 当前玩法 → Core 球架类型。
    var game: RackGame {
        switch gameKind {
        case .eightBall: return .chineseEightBall
        case .zhuifen: return zhuifenBalls == 9 ? .nineBall : .zhuifen(balls: zhuifenBalls)
        }
    }

    // MARK: - Shot params

    /// 杆头速度 (m/s)。开球是重杆：默认中大力，区间覆盖中力到爆杆。
    /// 注：母球实际出射速度 ≈ 1.54×杆头速度（杆-球碰撞，正中无塞）。
    @Published var power: Double = 7.0
    @Published var spinX: Double = 0
    @Published var spinY: Double = 0

    static let powerRange: ClosedRange<Double> = 4.0...9.0

    // MARK: - Scene

    let scene = AngleTrainingScene()
    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2DRotated
    private var aimNodes: [SCNNode] = []

    // MARK: - Published state

    @Published private(set) var phase: Phase = .racked
    @Published private(set) var statusText = "拖动母球定开球点 · 设力度后点「开球」"
    /// 本杆结果摘要（落袋数 / 刮杆 / 8 号落袋废局），供顶栏副标题。
    @Published private(set) var resultSummary: String?

    var isBusy: Bool { phase == .computing || phase == .breaking }
    var canBreak: Bool { phase == .racked }
    var canDeliver: Bool { phase == .settled && !lastBoard.onTable.isEmpty }

    // MARK: - Internals

    private var rack: Rack = RackLayout.make(.chineseEightBall)
    private var seed: UInt64 = 1
    private var lastBoard = BoardSnapshot()
    private var lastResult: BreakResult?
    private let breakQueue = DispatchQueue(label: "com.qiuji.rack-break", qos: .userInitiated)
    private var breakGeneration = 0
    /// 开球收尾延时任务（#11：在感知静止时刻收尾）；换局/取消时撤销。
    private var breakFinishTask: Task<Void, Never>?
    private var surfaceY: Float { scene.surfaceY }

    /// 桌面所有球键（母球 + 当前球架目标球），用于回放/收尾遍历。
    private var allKeys: [String] { [PositionPlayBall.cueKey] + rack.balls.map { $0.key } }

    // MARK: - Setup

    func setupScene() {
        scene.setupScene()
        scene.setupVisualizationNodes()
        scene.hideAllBalls()
        scene.hideCueStick()
        scene.cameraRig?.topDownPanOffset = .zero
        rebuildRack(resetSeed: false)
    }

    /// 重摆球架：按当前玩法 + seed 生成 `Rack`，铺到场景，母球落在球架默认开球点。
    private func rebuildRack(resetSeed: Bool) {
        if resetSeed { seed = 1 }
        cancelBreak()
        rack = RackLayout.make(game, seed: seed, surfaceY: surfaceY)
        scene.hideAllBalls()
        for b in rack.balls { scene.showBall(key: b.key, scenePosition: b.position) }
        scene.showBall(key: PositionPlayBall.cueKey, scenePosition: rack.cue)
        phase = .racked
        resultSummary = nil
        lastBoard = BoardSnapshot()
        lastResult = nil
        statusText = "拖动母球定开球点 · 设力度后点「开球」"
        drawAimLine()
    }

    /// 「换一局」：换一个随机种子重摆同玩法球架。
    func nextRack() {
        guard !isBusy else { return }
        seed &+= 1
        rebuildRack(resetSeed: false)
    }

    // MARK: - Cue dragging (only node on table that the user moves)

    var draggableCue: [SCNNode] {
        guard phase == .racked, let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden else { return [] }
        return [cue]
    }

    func dragBegan(node: SCNNode) {
        guard phase == .racked else { return }
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.15, duration: 0.1), forKey: "dragPulse")
    }

    func dragMoved(node: SCNNode, worldPosition: SCNVector3) {
        guard phase == .racked else { return }
        node.position = clampToBreakBox(worldPosition)
        drawAimLine()
    }

    func dragEnded(node: SCNNode) {
        guard phase == .racked else { return }
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.0 / 1.15, duration: 0.15))
        drawAimLine()
    }

    /// 把母球钳在开球区（厨房：开球线 → 顶库之间的半区），并避开袋口。
    private func clampToBreakBox(_ pos: SCNVector3) -> SCNVector3 {
        let r = AngleSceneCalculator.ballRadius
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let headLine = AngleSceneCalculator.innerLength / 4   // 开球线（与球架 headX 同源）
        var p = AngleSceneCalculator.clampAwayFromPockets(pos, surfaceY: surfaceY)
        p.x = max(headLine, min(halfL - r, p.x))
        p.z = max(-halfW + r, min(halfW - r, p.z))
        return SCNVector3(p.x, surfaceY + r, p.z)
    }

    // MARK: - Aim line (cue → apex，锁顶球瞄准的可视化)

    private func drawAimLine() {
        scene.clearResultNodes(nodes: &aimNodes)
        guard phase == .racked,
              let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden,
              let apex = rack.balls.max(by: { $0.position.x < $1.position.x })?.position else { return }
        let dir = BreakSimulator.aimAtApex(rack: rack, from: cue.position)
        // 瞄准虚线：母球 → 顶角球心方向，延伸到顶角球前。
        let end = SCNVector3(apex.x, apex.y, apex.z)
        aimNodes.append(scene.addLine(from: cue.position, to: end,
                                      color: UIColor.white.withAlphaComponent(0.5),
                                      radius: 0.0022))
        // 方向短箭杆（母球后方一点点），强调击球方向。
        let tail = SCNVector3(cue.position.x - dir.x * AngleSceneCalculator.ballRadius * 2,
                              cue.position.y,
                              cue.position.z - dir.z * AngleSceneCalculator.ballRadius * 2)
        aimNodes.append(scene.addLine(from: tail, to: cue.position,
                                      color: UIColor(red: 0.36, green: 0.92, blue: 0.55, alpha: 0.85),
                                      radius: 0.003))
    }

    // MARK: - Break (background sim → playback)

    func breakNow() {
        guard phase == .racked,
              let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden else { return }
        let cuePos = cueNode.position
        let theRack = rack
        let p = Float(power)
        // 开球随机性：在用户打点基础上叠加一点点 seed 驱动的随机塞（同一局可复现、换一局即变）
        // ——让「换一局」真正换出不同散开。
        let jitter = breakJitter(seed: seed)
        let (sx, sy) = clampSpin(Float(spinX) + jitter.spinX, Float(spinY) + jitter.spinY)
        breakGeneration += 1
        let gen = breakGeneration
        phase = .computing
        statusText = "开球计算中…"
        resultSummary = nil
        scene.clearResultNodes(nodes: &aimNodes)

        breakQueue.async { [weak self] in
            let result = BreakSimulator.breakShot(
                rack: theRack, cuePosition: cuePos, power: p,
                spinX: sx, spinY: sy)
            DispatchQueue.main.async {
                guard let self, self.breakGeneration == gen, self.phase == .computing else { return }
                self.startPlayback(result)
            }
        }
    }

    private func startPlayback(_ result: BreakResult) {
        lastResult = result
        phase = .breaking
        // 运杆 / 出杆动画（#10，单一权威 `CueStroke`，与击球各页同源）：母球沿瞄准方向（→ 顶角球）
        // 回杆 → 蓄力 → 匀加速出杆，触球瞬间收杆并启动散开回放。无球杆时直接散开。
        guard let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden else {
            runBreakMotion(result)
            return
        }
        statusText = "运杆…"
        let aim = BreakSimulator.aimAtApex(rack: rack, from: cueNode.position)
        let strikePos = CueStroke.strikePosition(cue: cueNode.position, aim: aim, spinX: spinX)
        scene.runCueStroke(strikePosition: strikePos, aim: aim, velocity: Float(power)) { [weak self] in
            guard let self, self.phase == .breaking else { return }
            // 收杆不在此处：触球后球杆继续减速跟杆 + 停留一拍再消失（由 `runCueStroke` 接管）。
            self.runBreakMotion(result)
        }
    }

    /// 散开回放（出杆触球后）：按 recorder 让所有球沿真实轨迹运动；在「感知静止时刻」收尾。
    private func runBreakMotion(_ result: BreakResult) {
        statusText = "开球中…"
        let playback = TrajectoryPlayback(recorder: result.recorder,
                                          surfaceY: surfaceY + AngleSceneCalculator.ballRadius)
        for key in allKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            if let action = playback.action(for: node, ballName: key, speed: 1.0, removeOnPocket: false) {
                node.runAction(action)
            }
        }
        // #11：以「感知静止时刻」收尾而非整段 recorder 时长——末段慢速 creep 肉眼不可见，
        // 否则球看着停了仍停留在开球态数秒。进袋入洞动画用 tail 兜住其真实时长。
        let settle = playback.perceptibleSettleTime()
        let tail: TimeInterval = result.pocketed.isEmpty ? 0.15
            : TrajectoryPlayback.pocketSettleDuration + 0.15
        let finishAfter = max(0.05, TimeInterval(settle) + tail)
        breakFinishTask?.cancel()
        breakFinishTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(finishAfter * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finishBreak(result)
        }
    }

    /// 回放收尾：球停在散开终点（与思路训练器一致的真实语义）；进袋球离场；母球刮杆则补回开球区。
    private func finishBreak(_ result: BreakResult) {
        guard phase == .breaking else { return }
        for key in allKeys { scene.allBallNodes[key]?.removeAllActions() }

        // 进袋球（含母球 scratch）离场。
        for key in result.pocketed { scene.hideBall(key: key) }

        // 存活球钉到散开终点（消除回放末帧的细微漂移）。
        var board = result.board
        for (key, pt) in board.onTable {
            let pos = AngleSceneCalculator.normalizedToScene(
                point: CGPoint(x: pt.x, y: pt.y), surfaceY: surfaceY)
            scene.showBall(key: key, scenePosition: pos)
        }

        // 母球刮杆：补回开球区（默认开球点），既能交付也便于「换一局」前预览。
        if result.cueScratched {
            scene.showBall(key: PositionPlayBall.cueKey, scenePosition: rack.cue)
            let c = AngleSceneCalculator.sceneToNormalized(position: rack.cue)
            board.onTable[PositionPlayBall.cueKey] = CanvasPoint(x: Double(c.x), y: Double(c.y))
        }

        lastBoard = board
        phase = .settled
        statusText = settledHint(result)
        resultSummary = resultLine(result)
    }

    private func cancelBreak() {
        breakGeneration += 1
        breakFinishTask?.cancel()
        breakFinishTask = nil
        for key in allKeys { scene.allBallNodes[key]?.removeAllActions() }
    }

    // MARK: - Break randomness（seed 驱动，一点点）

    /// 一局开球的随机扰动量。绑定 rack `seed`：同一局可复现（守 WYSIWYG / 确定性），换一局即变。
    private struct BreakJitter { let spinX: Float; let spinY: Float }

    /// 量级（「一点点」）：左右塞 ±0.10、上下塞 ±0.15（接触点偏移/R）。
    private func breakJitter(seed: UInt64) -> BreakJitter {
        var rng = SeededGenerator(seed: seed &* 0x2545_F491_4F6C_DD1D ^ 0x9E37_79B9_7F4A_7C15)
        let sx = Float.random(in: -0.10...0.10, using: &rng)
        let sy = Float.random(in: -0.15...0.15, using: &rng)
        return BreakJitter(spinX: sx, spinY: sy)
    }

    /// 把打点钳到打滑极限内（与全局 miscue 约束一致），叠加随机后不越界。
    private func clampSpin(_ x: Float, _ y: Float) -> (Float, Float) {
        let lim = CuePhysics.miscueLimitFraction
        let r = sqrtf(x * x + y * y)
        guard r > lim else { return (x, y) }
        let s = lim / r
        return (x * s, y * s)
    }

    // MARK: - Delivery

    /// 交付给消费工具的散开球形（停稳板；母球刮杆已补回开球区）。
    func deliveredBoard() -> BoardSnapshot { lastBoard }

    // MARK: - Hints

    private func settledHint(_ result: BreakResult) -> String {
        if result.eightOnBreak { return "8 号开球落袋（按规则废局）· 换一局重开，或仍可用此球形" }
        if result.cueScratched { return "母球进袋（刮杆）· 已补回开球区 · 可换一局或直接使用" }
        return "已停稳 · 送入编排台 / 思路训练器，或换一局"
    }

    private func resultLine(_ result: BreakResult) -> String {
        let objectPocketed = result.pocketed.filter { $0 != PositionPlayBall.cueKey }.count
        var parts: [String] = ["进 \(objectPocketed) 颗"]
        if result.cueScratched { parts.append("刮杆") }
        if result.eightOnBreak { parts.append("8 号落袋") }
        if !result.settled { parts.append("未停稳") }
        return parts.joined(separator: " · ")
    }
}
