import Foundation
import SwiftUI
import SceneKit

/// 驱动「翻袋解球」页：2D 顶视图，母球与目标球均可自由摆放，用户再选定要翻进的袋口。
/// 求解走真实物理引擎反解（W3，`ShotPredictor.predictBankAll` 四层管线）：解 = 引擎全保真
/// `ShotPrediction`，按「好打优先」（难度 + 扰动容错，`BankKickDifficulty`）排序，配 LRU 解缓存。
@MainActor
final class BankShotViewModel: ObservableObject {

    // MARK: - Published state

    /// 当前选定的袋口（与 `AngleSceneCalculator.pocketPositions` 索引一致）。
    @Published private(set) var selectedPocket: Int = 0
    /// nil = 自动（好打优先全库数）；否则为用户指定库数。
    @Published private(set) var selectedCushions: Int? = nil
    @Published private(set) var solutionCount: Int = 0
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var currentCushions: Int = 0
    @Published private(set) var currentRailText: String = ""
    @Published private(set) var currentCutAngle: Int = 0
    /// 难度档（易/中/难，`BankKickDifficulty` 档位）。
    @Published private(set) var currentDifficultyTier: BankKickDifficultyTier = .easy
    /// 扰动容错（E5 同款「容错 N%」；nil = 该解未测出容错）。
    @Published private(set) var currentRobustnessPercent: Int? = nil
    @Published private(set) var hasSolution: Bool = false
    /// 拖动中：只清线不重算（求解在拖球结束触发），pill 隐藏。
    @Published private(set) var isDragging: Bool = false
    /// 击打演示 / 自由击球回放中（W5/W6）：拖球/chips/力度柱/球库锁定。
    @Published private(set) var isPlaying: Bool = false

    // MARK: - Mode（W6：求解 / 自由，方案 §1.1）

    @Published private(set) var mode: BankKickPageMode = .solve
    /// 打点（接触点偏移/R）：spinX +左/−右、spinY +高/−低。
    /// 自由模式：sheet 写入后刷新瞄准；求解模式：由 `adjustCurrentSolution` / `presentDisplayedSolution` 写入。
    @Published var spinX: Double = 0 { didSet { if mode == .free { refreshFreeAim() } } }
    @Published var spinY: Double = 0
    /// 自由模式首碰预览（纯几何，`AngleSceneCalculator.freeAimFirstContact`）；
    /// nil = 空杆（当前方向碰不到球）。
    @Published private(set) var freeAimContact: AngleSceneCalculator.FreeAimContact?
    /// 自由模式「上一杆 / 回放」可用性。
    @Published private(set) var canUndoShot = false
    @Published private(set) var canPlaybackShot = false
    /// 求解模式「上一杆 / 回放」可用性（G17，条 17.5）。
    @Published private(set) var canUndoSolve = false
    @Published private(set) var canReplaySolve = false

    /// 自由模式瞄准方向（场景 XZ 单位向量）。
    private var freeAimDir: SCNVector3?
    private var freeAimNodes: [SCNNode] = []
    /// 选中解暗虚线参考（自由模式 hint token，照着练）。
    private var referenceNodes: [SCNNode] = []
    /// 最近求解快照（方案 §4.1）：每次求解成功存球位 + 袋口，供「恢复球形」。
    private var lastSolveSnapshot: (board: [String: SCNVector3], pocket: Int)?
    /// 上一杆（自由击球）：击打前球形 + 引擎预测（供上一杆 / 回放）。
    private var lastShot: (before: [String: SCNVector3], prediction: ShotPrediction)?
    /// 自由模拟中目标球（黑 8）的引擎名（球名沿用 USDZ 键约定）。
    private static let freeTargetName = "_8"

    /// 求解模式「上一杆」完整上下文（G17，条 17.5）：击打（演示）前的**完整求解状态**——
    /// 球形 + 袋口 + 库数 + 已求出的全部解（缓存回填，免重解）+ 当前解档位 + 力度。页面特有
    /// 选择模型（袋口/库数/解索引）随本上下文携带。翻袋/反射引擎解为 `BankEngineSolution`
    /// （非 PositionPlay 的 `PositionPlaySolution`），与共享 `SolveShotSnapshot` 类型不兼容，
    /// 故按方案「用 VM 层已有 solutions 即可」以本页原生类型承载（如实说明选址取舍）。
    struct SolveUndoContext {
        var board: [String: SCNVector3]
        var pocket: Int
        var cushions: Int?
        var solutions: [BankEngineSolution]
        var currentIndex: Int
        /// Catalog 全量反解时的力度（恢复 catalog 展示用）。
        var catalogPower: Double
        /// K11：击打时展示/演示用的力度与塞（可能是草稿）。
        var struckPower: Double
        var struckSpinX: Double
        var struckSpinY: Double
        var struckPrediction: ShotPrediction
    }
    private var lastSolveUndo: SolveUndoContext?
    /// 恢复期抑制 `reflectionPower.didSet` 触发重求解（「上一杆」= 免重解，G17）。
    private var isRestoringSolve = false
    /// 展示 catalog/草稿时写入力度/塞，禁止误触发全量重解。
    private var isPresentingSolution = false
    /// 最近一次 `applySolutions` 时的反解力度（catalog 真源，微调不改写）。
    private var catalogSolvePower: Double = Double(CushionReflectionSettings.power)

    // MARK: - Adjustment draft (K11 / X5 — transplant of X6 K13 semantics)
    //
    // Contract (same state machine as SiluTrainerViewModel):
    // - `solutions` / `displayed` catalog immutable after solve; fine-tune never mutates them.
    // - `adjustmentDraft` = forward-repredicted display/strike candidate for `currentIndex`.
    // - `currentSolution` = draft ?? displayed[currentIndex]
    // Transitions: adjust → Drafted; nextSolution / show catalog / recompute → Clean (draft discarded).

    private var adjustmentDraft: BankEngineSolution?
    /// Fine-tune re-predict generation (discard stale async results).
    private var adjustGeneration = 0

    var canRestoreSnapshot: Bool { lastSolveSnapshot != nil }
    var canFreeStrike: Bool {
        mode == .free && !isPlaying && freeAimDir != nil
            && !(scene.cueBallNode?.isHidden ?? true)
    }

    /// 力度（m/s）：无解时 = 全量反解输入；有解时由 Chrome 走 `adjustCurrentSolution` 草稿微调。
    /// 直接赋值（摆球后首解 / 恢复）仍触发去抖重解。
    @Published var reflectionPower: Double = Double(CushionReflectionSettings.power) {
        didSet {
            CushionReflectionSettings.power = Float(reflectionPower)
            if isRestoringSolve || isPresentingSolution { return }
            if mode == .solve { recompute() }
        }
    }

    let cushionOptions = [1, 2, 3]

    /// 各袋口名称（顺序同 pocketPositions：左上/右上/左下/右下/上中/下中）。
    let pocketNames = ["左上", "右上", "左下", "右下", "上中", "下中"]

    // MARK: - Obstacles（W4 球库带：拖入 = 真实碰撞体，方案 §4.3）

    /// 球库可拖入的障碍球键（目标球固定黑 8，`_8` 不进球库）。
    static let paletteKeys: [String] = PositionPlayBall.objectKeys.filter { $0 != "_8" }

    /// 在桌障碍球（名序稳定，供求解装配与球库变暗）。
    @Published private(set) var onTableObstacleKeys: [String] = []

    // MARK: - Scene

    let scene = AngleTrainingScene()
    private var guideNodes: [SCNNode] = []
    private var pathNodes: [SCNNode] = []
    private var pocketMarkers: [SCNNode] = []

    private var solutions: [BankEngineSolution] = []
    private var displayed: [BankEngineSolution] = []
    /// 引擎反解后台求解任务（并行全枚举较重，需离开主线程并去抖）。
    private var solveTask: Task<Void, Never>?
    /// 正在后台求解（供 UI 显示加载态）。
    @Published private(set) var isSolving = false
    /// 解缓存（方案 §4.1）：key = 全部球位毫米 + 袋口 + 力度步进；LRU 8 条，页面退出释放。
    private var solveCache = BankKickSolveCache<BankKickSolveKey, [BankEngineSolution]>()

    var draggableNodes: [SCNNode] {
        guard !isPlaying else { return [] }   // 演示中锁拖球（W5）。
        return [scene.cueBallNode, scene.targetBallNodes.first].compactMap { $0 }
            + onTableObstacleKeys.compactMap { scene.allBallNodes[$0] }
    }

    // MARK: - Setup

    func setupScene() {
        scene.setupScene(enhancedRendering: false)
        // L0 假想球虚线圈 + 接触点绿点（与思路训练 / 编排台 / 打三同口径）。
        // 未调用则 `ghostBallNode == nil`，TrajectoryRenderer 的 showGhost 静默空转。
        scene.setupVisualizationNodes()
        pocketMarkers = scene.addPocketMarkers()
        scene.setCameraMode(.topDown2DRotated, animated: false)
        rebuildGuides()
        placeBalls()
        recompute()
    }

    /// 长库钻石刻度点（无数字）。数字标注已去掉——翻袋页不依赖钻石计数。
    private func rebuildGuides() {
        scene.clearResultNodes(nodes: &guideNodes)
        let ticks = DiamondSystemCalculator.diamondTicks(surfaceY: scene.surfaceY)
        guideNodes = scene.addDiamondGuides(
            labels: [],
            ticks: ticks,
            labelColor: UIColor.white.withAlphaComponent(0.55),
            tickColor: UIColor.white.withAlphaComponent(0.4)
        )
    }

    private func placeBalls() {
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        let cuePos = SCNVector3(BankShotCalculator.halfL * 0.35, y, -BankShotCalculator.halfW * 0.3)
        let objPos = SCNVector3(-BankShotCalculator.halfL * 0.05, y, BankShotCalculator.halfW * 0.4)
        scene.applyBallLayout(cueBallPosition: cuePos, targetBallNumber: 8, targetPosition: objPos)
    }

    // MARK: - Dragging (both balls free)

    /// 拖动中只清线不重算（引擎反解重于旧追迹，拖动中连续重算无意义）；求解在拖球结束触发。
    func dragBegan(node: SCNNode) {
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.15, duration: 0.1), forKey: "dragPulse")
        solveTask?.cancel()
        isSolving = false
        isDragging = true
        clearPath()
    }

    func dragEnded(node: SCNNode) {
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.0 / 1.15, duration: 0.15))
        isDragging = false
        if mode == .free {
            refreshFreeAim()   // 自由模式拖球只刷新瞄准预览，不触发反解。
        } else {
            recompute()
        }
    }

    func handleDrag(node: SCNNode, to worldPos: SCNVector3) {
        node.position = clampMultiBall(worldPos, movingNode: node)
        if mode == .free { refreshFreeAim() }
    }

    /// 多球摆位钳制（编排台同款）：库内 + 远离袋口 + 不与任意其他在桌球重叠（迭代推开）。
    private func clampMultiBall(_ pos: SCNVector3, movingNode: SCNNode) -> SCNVector3 {
        var p = AngleSceneCalculator.clampAwayFromPockets(pos, surfaceY: scene.surfaceY)
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let r = AngleSceneCalculator.ballRadius
        let minDist: Float = 2 * r + 0.001
        let others = ([scene.cueBallNode, scene.targetBallNodes.first].compactMap { $0 }
            + onTableObstacleKeys.compactMap { scene.allBallNodes[$0] })
            .filter { $0 !== movingNode && !$0.isHidden }
        for _ in 0..<6 {
            var moved = false
            for other in others {
                let dx = p.x - other.position.x, dz = p.z - other.position.z
                let dist = sqrtf(dx * dx + dz * dz)
                if dist < minDist {
                    if dist > 0.0001 {
                        p.x = other.position.x + (dx / dist) * minDist
                        p.z = other.position.z + (dz / dist) * minDist
                    } else { p.x += minDist }
                    moved = true
                }
            }
            p.x = max(-halfL + r, min(halfL - r, p.x))
            p.z = max(-halfW + r, min(halfW - r, p.z))
            if !moved { break }
        }
        return SCNVector3(p.x, scene.surfaceY + r, p.z)
    }

    // MARK: - Obstacle palette（拖入落位 / 点击落空位 / 拖回移除，编排台同款交互）

    /// 从球库放一颗障碍球到指定世界坐标（nil = 自动找空位）。
    func placeObstacle(_ key: String, atWorld world: SCNVector3? = nil) {
        guard !isPlaying else { return }
        guard Self.paletteKeys.contains(key), !onTableObstacleKeys.contains(key),
              let node = scene.allBallNodes[key] else { return }
        let target = world ?? freeObstacleSlot()
        scene.showBall(key: key, scenePosition: target)
        node.position = clampMultiBall(node.position, movingNode: node)
        onTableObstacleKeys = (onTableObstacleKeys + [key]).sorted()
        if mode == .free { refreshFreeAim() } else { recompute() }
    }

    /// 把一颗在桌障碍球撤下回库。
    func removeObstacle(_ key: String) {
        guard !isPlaying, onTableObstacleKeys.contains(key) else { return }
        scene.hideBall(key: key)
        onTableObstacleKeys.removeAll { $0 == key }
        if mode == .free { refreshFreeAim() } else { recompute() }
    }

    /// 点在桌球的球库槽位 → 桌上对应球放大脉冲提示位置（编排台同款）。
    func pulseTableBall(_ key: String) {
        guard let node = scene.allBallNodes[key], !node.isHidden else { return }
        TableBallPulse.pulse(node)
    }

    /// 台面上找一个不与在桌球重叠的空位（场景系网格扫描）。
    private func freeObstacleSlot() -> SCNVector3 {
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let occupied = ([scene.cueBallNode, scene.targetBallNodes.first].compactMap { $0 }
            + onTableObstacleKeys.compactMap { scene.allBallNodes[$0] })
            .filter { !$0.isHidden }.map(\.position)
        for x in stride(from: -halfL * 0.7, through: halfL * 0.7, by: halfL * 0.2) {
            for z in stride(from: -halfW * 0.6, through: halfW * 0.6, by: halfW * 0.3) {
                let p = SCNVector3(x, y, z)
                let clear = occupied.allSatisfy {
                    AngleSceneCalculator.horizontalDistance(p, $0) > 2.5 * AngleSceneCalculator.ballRadius
                }
                if clear { return p }
            }
        }
        return SCNVector3(0, y, 0)
    }

    /// 当前在桌障碍球 → 引擎碰撞体（名序稳定，与缓存 key 同序）。
    private func currentObstacles() -> [ObstacleBall] {
        onTableObstacleKeys.compactMap { key in
            guard let node = scene.allBallNodes[key], !node.isHidden else { return nil }
            return ObstacleBall(name: key, position: node.position)
        }
    }

    // MARK: - Strike demo（W5：快照 → 出杆 → 播 ShotPrediction → 自动复位，方案 §1.1）

    /// 击打前球形快照（复位真源）：cue/target 用固定键，障碍球用球键。
    private var strikeSnapshot: [String: SCNVector3] = [:]
    private var playbackFinishTask: Task<Void, Never>?
    private static let snapshotCueKey = "__cue"
    private static let snapshotTargetKey = "__target"

    var canStrike: Bool { hasSolution && !isPlaying && !isSolving && !isDragging }

    /// 求解模式「击打」= 演示：回放该解的引擎全保真 `ShotPrediction`（含母球碰后去向、
    /// 障碍球被扰动等全部真实物理），结束自动复原击打前球形。画面=物理=回放单一口径。
    func strike() {
        guard canStrike, mode == .solve, let sol = currentSolution else { return }
        // G17（条 17.5）：击打（演示）前捕获完整上下文，供「上一杆」全量恢复。
        lastSolveUndo = makeSolveUndo()
        canUndoSolve = false
        canReplaySolve = false
        runSolveDemo(sol)
    }

    /// 运行一次求解模式演示（出杆 → 回放 → 自动复位），不捕获上下文（供击打与「回放」复用）。
    private func runSolveDemo(_ sol: BankEngineSolution) {
        guard let cueNode = scene.cueBallNode,
              sol.prediction.recorder != nil, sol.prediction.duration > 0.05 else { return }
        solveTask?.cancel()
        isSolving = false
        isPlaying = true

        strikeSnapshot = captureBoard()

        // 出杆动画（运杆/出杆单一权威 `CueStroke`）：触球瞬间起播球体回放。
        scene.runCueStroke(
            strikePosition: cueNode.position,
            aim: sol.prediction.aimDirection,
            velocity: Float(reflectionPower)
        ) { [weak self] in
            self?.launchPlayback(sol)
        }
    }

    // MARK: - 求解模式「上一杆 / 回放」（G17，条 17.5）

    /// 捕获当前求解状态为「上一杆」上下文（仅在有解时有意义）。
    /// （internal：`strike()` 与单测共用同一处捕获逻辑，单一真源。）
    func makeSolveUndo() -> SolveUndoContext? {
        guard hasSolution, let shown = currentSolution else { return nil }
        return SolveUndoContext(
            board: captureBoard(), pocket: selectedPocket, cushions: selectedCushions,
            solutions: solutions, currentIndex: currentIndex,
            catalogPower: catalogSolvePower,
            struckPower: reflectionPower,
            struckSpinX: Double(shown.spinX), struckSpinY: Double(shown.spinY),
            struckPrediction: shown.prediction)
    }

    /// 把击打前完整状态原样恢复（G17，免重解）。catalog 原样回填；若击打用了微调则重建草稿层。
    func restoreSolve(from ctx: SolveUndoContext) {
        guard mode == .solve, !isPlaying else { return }
        solveTask?.cancel()
        isSolving = false
        adjustGeneration += 1
        catalogSolvePower = ctx.catalogPower
        isRestoringSolve = true
        reflectionPower = ctx.catalogPower
        isRestoringSolve = false
        applyBoard(ctx.board)
        selectedPocket = ctx.pocket
        selectedCushions = ctx.cushions
        solutions = ctx.solutions
        adjustmentDraft = nil
        displayed = ctx.cushions.map { n in solutions.filter { $0.cushions == n } } ?? solutions
        solutionCount = displayed.count
        updatePocketHighlights()
        if displayed.isEmpty {
            hasSolution = false
            currentIndex = 0
            currentCushions = 0
            currentRailText = ""
            currentCutAngle = 0
            currentRobustnessPercent = nil
            clearPath()
        } else {
            currentIndex = min(max(ctx.currentIndex, 0), displayed.count - 1)
            let catalog = displayed[currentIndex]
            let paramsDiffer =
                abs(catalog.spinX - Float(ctx.struckSpinX)) > 1e-6
                || abs(catalog.spinY - Float(ctx.struckSpinY)) > 1e-6
                || abs(ctx.struckPower - ctx.catalogPower) > 1e-9
            if paramsDiffer {
                adjustmentDraft = BankEngineSolution(
                    rails: catalog.rails, seedRails: catalog.seedRails,
                    prediction: ctx.struckPrediction,
                    cushions: catalog.cushions,
                    difficultyScore: catalog.difficultyScore,
                    difficultyTier: catalog.difficultyTier,
                    robustness: catalog.robustness, pathLength: catalog.pathLength,
                    spinX: Float(ctx.struckSpinX), spinY: Float(ctx.struckSpinY),
                    usedFrozenRailSeed: catalog.usedFrozenRailSeed
                )
                presentDisplayedSolution(adjustmentDraft!, power: ctx.struckPower)
            } else {
                showSolution(at: currentIndex)
            }
        }
    }

    /// 上一杆（G17）：回到上次击打（演示）前的完整状态（球形 + 袋口 + 库数 + 解集 + 档位 + 力度）。
    func undoSolveShot() {
        guard mode == .solve, !isPlaying, let ctx = lastSolveUndo else { return }
        restoreSolve(from: ctx)
        lastSolveUndo = nil
        canUndoSolve = false
        canReplaySolve = false
    }

    /// 回放上一杆：恢复击打前状态并重放该解的演示。
    func replaySolveShot() {
        guard mode == .solve, !isPlaying, let ctx = lastSolveUndo else { return }
        restoreSolve(from: ctx)
        guard let sol = currentSolution else { return }
        runSolveDemo(sol)
    }

    /// 回放中「停止」：立即复位（快照即真源）。
    func stopStrike() {
        guard isPlaying else { return }
        playbackFinishTask?.cancel()
        ShotAudioScheduler.shared.cancel()
        finishStrike()
    }

    private func launchPlayback(_ sol: BankEngineSolution) {
        guard isPlaying, let recorder = sol.prediction.recorder else {
            finishStrike()
            return
        }
        clearPath()   // 触球清线：演示期间不叠预告线（编排台/导出器同口径）。
        ShotAudioScheduler.shared.play(prediction: sol.prediction)

        let playback = TrajectoryPlayback(
            recorder: recorder, surfaceY: scene.surfaceY + AngleSceneCalculator.ballRadius
        )
        // G15：播到引擎自然静止（不做 0.07 感知截断），球停止前无最后一跳/瞬移。
        let settle = playback.duration

        var pairs: [(SCNNode, String)] = []
        if let cue = scene.cueBallNode { pairs.append((cue, ShotInput.cueBallName)) }
        if let target = scene.targetBallNodes.first { pairs.append((target, ShotInput.targetBallName)) }
        for key in onTableObstacleKeys {
            if let node = scene.allBallNodes[key] { pairs.append((node, key)) }
        }
        var anyPocketed = false
        for (node, name) in pairs {
            if playback.willBePocketed(name) { anyPocketed = true }
            // removeOnPocket 必须 false：可复用回放场景，进袋只淡出保留节点（复位重显）。
            if let action = playback.action(for: node, ballName: name, speed: 1.0,
                                            removeOnPocket: false, maxSimTime: settle) {
                node.runAction(action, forKey: "strikeDemo")
            }
        }

        // 结束 = 感知静止（+ 进袋沉入/停顿/淡出收尾）后停一拍再复位。
        let total = TimeInterval(settle)
            + (anyPocketed ? TrajectoryPlayback.pocketSettleDuration : 0) + 0.45
        playbackFinishTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(total * 1_000_000_000))
            if Task.isCancelled { return }
            self?.finishStrike()
        }
    }

    /// 复位：快照即真源（演示不改变球形）；解列表/序号不变，重绘当前解线。
    private func finishStrike() {
        playbackFinishTask = nil
        scene.hideCueStick()
        applyBoard(strikeSnapshot)
        strikeSnapshot = [:]
        isPlaying = false
        canUndoSolve = lastSolveUndo != nil
        canReplaySolve = lastSolveUndo != nil
        drawCurrent()
    }

    private func restoreBall(_ node: SCNNode, to position: SCNVector3) {
        node.removeAllActions()
        node.opacity = 1
        node.isHidden = false
        BallSpinIntegrator.resetPose(node)
        node.position = position
    }

    // MARK: - Board snapshot（W5/W6 共用：快照 = 复位 / 上一杆 / 恢复球形的真源）

    private func captureBoard() -> [String: SCNVector3] {
        var board: [String: SCNVector3] = [:]
        if let cue = scene.cueBallNode, !cue.isHidden { board[Self.snapshotCueKey] = cue.position }
        if let target = scene.targetBallNodes.first, !target.isHidden {
            board[Self.snapshotTargetKey] = target.position
        }
        for key in onTableObstacleKeys {
            if let node = scene.allBallNodes[key], !node.isHidden { board[key] = node.position }
        }
        return board
    }

    /// 按快照恢复球形：cue/target 归位重显，障碍球增删同步 `onTableObstacleKeys`。
    private func applyBoard(_ board: [String: SCNVector3]) {
        if let cue = scene.cueBallNode, let p = board[Self.snapshotCueKey] {
            restoreBall(cue, to: p)
        }
        if let target = scene.targetBallNodes.first, let p = board[Self.snapshotTargetKey] {
            restoreBall(target, to: p)
        }
        var keys: [String] = []
        for key in Self.paletteKeys {
            if let p = board[key], let node = scene.allBallNodes[key] {
                restoreBall(node, to: p)
                keys.append(key)
            } else if onTableObstacleKeys.contains(key) {
                scene.hideBall(key: key)
            }
        }
        onTableObstacleKeys = keys.sorted()
    }

    // MARK: - Free mode（W6：模式切换 / 瞄准 / simulateFree 试手 / 上一杆 / 恢复球形）

    /// 求解 ⇄ 自由切换。进自由默认沿用选中解瞄准方向（照着练，方案 §1.1）；
    /// 回求解触发 recompute——球形未变则命中解缓存直显（§4.1）。
    func toggleMode() {
        guard !isPlaying else { return }
        if mode == .solve {
            solveTask?.cancel()
            isSolving = false
            if let aim = currentSolution?.prediction.aimDirection {
                freeAimDir = aim
            } else if freeAimDir == nil {
                freeAimDir = defaultFreeAim()
            }
            mode = .free
            clearPath()
            drawReferenceSolution()
            refreshFreeAim()
        } else {
            mode = .solve
            clearFreeOverlays()
            scene.hideCueStick()
            recompute()
        }
    }

    private func defaultFreeAim() -> SCNVector3 {
        guard let cue = scene.cueBallNode?.position,
              let target = scene.targetBallNodes.first?.position else { return SCNVector3(1, 0, 0) }
        let dx = target.x - cue.x, dz = target.z - cue.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 1e-4 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(dx / len, 0, dz / len)
    }

    /// 自由模式瞄准相对调整（G13）：`delta > 0` = 屏幕顺时针。台面空白处拖动（`onAimNudged`）与
    /// 左缘刻度齿轮（`BTAimWheel`）共用本入口——均为对**当前**瞄准方向的增量旋转（第一落点只选中
    /// 不转向由手势层保证）。自由模式为纯几何预览（`freeAimFirstContact`），本就不求解，不受 G14 影响。
    func nudgeFreeAim(byDegrees delta: Float) {
        guard mode == .free, !isPlaying, abs(delta) > 1e-4 else { return }
        let base = freeAimDir ?? defaultFreeAim()
        freeAimDir = AngleSceneCalculator.rotatedAim(base, byDegrees: delta)
        refreshFreeAim()
    }

    /// 自由模式首碰查询的在桌球（目标球 + 障碍球，纯几何）。
    private func freeContactBalls() -> [(key: String, pos: SCNVector3)] {
        var balls: [(String, SCNVector3)] = []
        if let target = scene.targetBallNodes.first, !target.isHidden {
            balls.append((Self.freeTargetName, target.position))
        }
        for key in onTableObstacleKeys {
            if let node = scene.allBallNodes[key], !node.isHidden { balls.append((key, node.position)) }
        }
        return balls
    }

    /// 刷新自由瞄准覆盖：瞄准线（至假想球 / 空杆至库边）+ 标准假想球（ghostBallNode）+ 接触点 + 球杆摆位；
    /// 首碰胶囊数据走 `freeAimFirstContact`（纯几何，方案 §1.3）。
    func refreshFreeAim() {
        scene.clearResultNodes(nodes: &freeAimNodes)
        guard mode == .free, !isPlaying,
              let cue = scene.cueBallNode, !cue.isHidden,
              let dir = freeAimDir else {
            freeAimContact = nil
            scene.ghostBallNode?.isHidden = true
            scene.contactDotNode?.isHidden = true
            if mode == .free { scene.hideCueStick() }
            return
        }
        let contact = AngleSceneCalculator.freeAimFirstContact(
            cue: cue.position, dir: dir, balls: freeContactBalls()
        )
        freeAimContact = contact

        let end: SCNVector3
        if let contact {
            end = SCNVector3(contact.ghost.x, cue.position.y, contact.ghost.z)
        } else {
            end = rayToRail(from: cue.position, dir: dir)
        }
        freeAimNodes.append(scene.addLine(from: cue.position, to: end,
                                          color: TrajectoryStyle.aimColor,
                                          radius: TrajectoryStyle.aimRadius))
        if let contact {
            if let ghost = scene.ghostBallNode {
                ghost.position = end
                ghost.isHidden = false
            }
            if let targetNode = freeBallNode(for: contact.targetKey) {
                scene.updateContactDot(ghostCenter: end, targetCenter: targetNode.position)
            }
        } else {
            scene.ghostBallNode?.isHidden = true
            scene.contactDotNode?.isHidden = true
        }
        scene.updateCueStick(
            cueBallPosition: CueStroke.strikePosition(cue: cue.position, aim: dir, spinX: spinX),
            aimDirection: dir
        )
    }

    private func freeBallNode(for key: String) -> SCNNode? {
        key == Self.freeTargetName ? scene.targetBallNodes.first : scene.allBallNodes[key]
    }

    /// 空杆瞄准线终点：射线与库内边界（缩一颗球半径）的首个交点（几何单一真源）。
    private func rayToRail(from p: SCNVector3, dir: SCNVector3) -> SCNVector3 {
        AngleSceneCalculator.rayToInnerRail(from: p, dir: dir)
    }

    /// 选中解暗虚线参考（hint token）：目标球翻袋路线 + 母球瞄准段，供照着练。
    private func drawReferenceSolution() {
        scene.clearResultNodes(nodes: &referenceNodes)
        guard mode == .free, let sol = currentSolution else { return }
        let pred = sol.prediction
        appendReferenceDashes(pred.objectPath)
        if let start = pred.cuePath.first {
            appendReferenceDashes([start, pred.ghost])
        }
    }

    private func appendReferenceDashes(_ path: [SCNVector3]) {
        guard path.count >= 2 else { return }
        for i in 0..<(path.count - 1) {
            referenceNodes.append(scene.addDashedLine(
                from: path[i], to: path[i + 1],
                color: TrajectoryStyle.hintColor, radius: TrajectoryStyle.lineHint,
                dash: TrajectoryStyle.hintDash, gap: TrajectoryStyle.hintGap
            ))
        }
    }

    private func clearFreeOverlays() {
        scene.clearResultNodes(nodes: &freeAimNodes)
        scene.clearResultNodes(nodes: &referenceNodes)
        scene.ghostBallNode?.isHidden = true
        scene.contactDotNode?.isHidden = true
        freeAimContact = nil
    }

    /// 自由击球（试手）：`simulateFree` 真物理，球停在哪是哪；进袋球离场（恢复球形/上一杆可回）。
    func freeStrike() {
        guard canFreeStrike, let cueNode = scene.cueBallNode, let dir = freeAimDir else { return }
        isPlaying = true
        let before = captureBoard()
        scene.clearResultNodes(nodes: &freeAimNodes)
        scene.clearResultNodes(nodes: &referenceNodes)

        let balls = freeContactBalls().map { ObstacleBall(name: $0.key, position: $0.pos) }
        let cuePos = cueNode.position
        let velocity = Float(reflectionPower)
        let sx = Float(spinX), sy = Float(spinY)
        let surfaceY = scene.surfaceY

        Task { [weak self] in
            let pred = await Task.detached(priority: .userInitiated) {
                ShotPredictor.simulateFree(
                    cueBall: cuePos, aimDir: dir, velocity: velocity,
                    spinX: sx, spinY: sy, surfaceY: surfaceY, balls: balls
                )
            }.value
            guard let self, self.isPlaying else { return }
            let strikePos = CueStroke.strikePosition(cue: cuePos, aim: dir, spinX: Double(sx))
            self.scene.runCueStroke(strikePosition: strikePos, aim: dir,
                                    velocity: velocity) { [weak self] in
                self?.launchFreePlayback(pred, before: before)
            }
        }
    }

    /// 上一杆：恢复自由击打前球形（一步撤销）。
    func undoLastShot() {
        guard mode == .free, !isPlaying, let shot = lastShot else { return }
        applyBoard(shot.before)
        canUndoShot = false
        refreshFreeAim()
        drawReferenceSolution()
    }

    /// 回放上一杆：摆回击打前球形并重播引擎 recorder（结束停在终态，同「球停在哪是哪」）。
    func replayLastShot() {
        guard mode == .free, !isPlaying, let shot = lastShot,
              shot.prediction.recorder != nil else { return }
        isPlaying = true
        scene.clearResultNodes(nodes: &freeAimNodes)
        scene.clearResultNodes(nodes: &referenceNodes)
        applyBoard(shot.before)
        launchFreePlayback(shot.prediction, before: shot.before)
    }

    /// 恢复球形：回最近求解快照（含袋口，方案 §4.1）；切回求解模式必命中缓存直显。
    func restoreSolveSnapshot() {
        guard mode == .free, !isPlaying, let snap = lastSolveSnapshot else { return }
        applyBoard(snap.board)
        selectedPocket = snap.pocket
        updatePocketHighlights()
        canUndoShot = false
        refreshFreeAim()
        drawReferenceSolution()
    }

    private func launchFreePlayback(_ pred: ShotPrediction, before: [String: SCNVector3]) {
        guard let recorder = pred.recorder else {
            settleFreeShot(pred, before: before)
            return
        }
        ShotAudioScheduler.shared.play(prediction: pred)
        let playback = TrajectoryPlayback(
            recorder: recorder, surfaceY: scene.surfaceY + AngleSceneCalculator.ballRadius
        )
        let settle = playback.duration   // G15：播到引擎自然静止（不做感知截断）

        var pairs: [(SCNNode, String)] = []
        if let cue = scene.cueBallNode { pairs.append((cue, ShotInput.cueBallName)) }
        if let target = scene.targetBallNodes.first, !target.isHidden {
            pairs.append((target, Self.freeTargetName))
        }
        for key in onTableObstacleKeys {
            if let node = scene.allBallNodes[key] { pairs.append((node, key)) }
        }
        var anyPocketed = false
        for (node, name) in pairs {
            if playback.willBePocketed(name) { anyPocketed = true }
            if let action = playback.action(for: node, ballName: name, speed: 1.0,
                                            removeOnPocket: false, maxSimTime: settle) {
                node.runAction(action, forKey: "freeShot")
            }
        }
        let total = TimeInterval(settle)
            + (anyPocketed ? TrajectoryPlayback.pocketSettleDuration : 0) + 0.2
        playbackFinishTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(total * 1_000_000_000))
            if Task.isCancelled { return }
            self?.settleFreeShot(pred, before: before)
        }
    }

    /// 自由击打收尾：终态取引擎 `finalPositions`（球停在哪是哪）；进袋球离场
    ///（母球/目标球进袋 = 试手事实，靠上一杆 / 恢复球形找回）。
    private func settleFreeShot(_ pred: ShotPrediction, before: [String: SCNVector3]) {
        playbackFinishTask = nil
        scene.hideCueStick()
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        func settle(_ node: SCNNode, name: String) {
            node.removeAllActions()
            node.opacity = 1
            if pred.pocketedBalls.contains(name) {
                node.isHidden = true
            } else if let p = pred.finalPositions[name] {
                node.position = SCNVector3(p.x, y, p.z)
            }
        }
        if let cue = scene.cueBallNode { settle(cue, name: ShotInput.cueBallName) }
        if let target = scene.targetBallNodes.first { settle(target, name: Self.freeTargetName) }
        for key in onTableObstacleKeys {
            if let node = scene.allBallNodes[key] { settle(node, name: key) }
        }
        onTableObstacleKeys.removeAll { pred.pocketedBalls.contains($0) }
        lastShot = (before, pred)
        canUndoShot = true
        canPlaybackShot = true
        isPlaying = false
        refreshFreeAim()
        drawReferenceSolution()
    }

    // MARK: - Pocket selection

    func selectPocket(_ index: Int) {
        guard !isPlaying, mode == .solve else { return }
        guard index >= 0, index < pocketMarkers.count else { return }
        selectedPocket = index
        currentIndex = 0
        recompute()
    }

    // MARK: - Cushion selection

    func selectCushions(_ n: Int?) {
        guard !isPlaying, mode == .solve else { return }
        selectedCushions = n
        currentIndex = 0
        recompute()
    }

    // MARK: - Solving

    /// 引擎反解（全枚举并行 + 好打排序 + 容错）较重：先查解缓存（球位/袋口/力度量化 key，
    /// 命中直显），miss 才离开主线程求解（120ms 去抖合并连续触发，如力度滑块）。
    func recompute() {
        guard !isPlaying, mode == .solve,
              let cue = scene.cueBallNode?.position,
              let object = scene.targetBallNodes.first?.position else { return }

        solveTask?.cancel()
        let prevCushions = currentCushions

        let obstacles = currentObstacles()
        let key = BankKickSolveKey.make(
            cue: cue, object: object, obstacles: obstacles,
            pocketIndex: selectedPocket, power: reflectionPower
        )
        if let cached = solveCache.value(for: key) {
            isSolving = false
            applySolutions(cached, prevCushions: prevCushions)
            return
        }

        isSolving = true
        let cx = cue.x, cz = cue.z, ox = object.x, oz = object.z
        let pocket = selectedPocket
        let surfaceY = scene.surfaceY
        let power = Float(reflectionPower)
        // 球位 y 必须是真实球心高度：管线的 ghost/瞄准几何直接沿用输入 y（画线用）。
        let ballY = surfaceY + AngleSceneCalculator.ballRadius
        solveTask = Task { [weak self] in
            // G14：求解模式拖球/连续调节期间不求解——每次触发取消上一 task 并重排，
            // 停 0.5s（无新输入）后才离开主线程反解（缓存命中直显，不受此延时影响）。
            try? await Task.sleep(nanoseconds: UInt64(SolveDebounceScheduler.defaultIdleInterval * 1_000_000_000))
            if Task.isCancelled { return }
            let sols = await Task.detached(priority: .userInitiated) {
                BankKickSolvePipeline.solveBank(
                    cue: SCNVector3(cx, ballY, cz), object: SCNVector3(ox, ballY, oz),
                    pocketIndex: pocket, surfaceY: surfaceY, power: power,
                    obstacles: obstacles)
            }.value
            if Task.isCancelled { return }
            guard let self else { return }
            self.isSolving = false
            self.solveCache.insert(sols, for: key)
            self.applySolutions(sols, prevCushions: prevCushions)
        }
    }

    /// 应用求解结果（过滤、选路、绘制）。在主线程执行。
    private func applySolutions(_ sols: [BankEngineSolution], prevCushions: Int) {
        adjustGeneration += 1
        adjustmentDraft = nil
        solutions = sols
        catalogSolvePower = reflectionPower
        // 最近求解快照（方案 §4.1）：求解成功即存球位 + 袋口，供自由模式「恢复球形」。
        if !sols.isEmpty {
            lastSolveSnapshot = (captureBoard(), selectedPocket)
        }

        // 库数过滤 = 展示层后处理（分桶，不进缓存 key）。
        if let n = selectedCushions {
            displayed = solutions.filter { $0.cushions == n }
        } else {
            displayed = solutions
        }
        solutionCount = displayed.count
        updatePocketHighlights()

        guard !displayed.isEmpty else {
            hasSolution = false
            currentIndex = 0
            currentCushions = 0
            currentRailText = ""
            currentCutAngle = 0
            currentRobustnessPercent = nil
            clearPath()
            return
        }

        if selectedCushions == nil, prevCushions > 0,
           let idx = displayed.firstIndex(where: { $0.cushions == prevCushions }) {
            currentIndex = idx
        } else if currentIndex >= displayed.count {
            currentIndex = 0
        }
        showSolution(at: currentIndex)
    }

    func nextSolution() {
        guard !isPlaying, !displayed.isEmpty else { return }
        // Discard draft before advancing — cycling back must show the catalog original.
        adjustmentDraft = nil
        currentIndex = (currentIndex + 1) % displayed.count
        showSolution(at: currentIndex)
    }

    /// K11 微调草稿层：改打点/力度后按当前解库序正向 `ShotPredictor.predict` 重算，
    /// 写入 `adjustmentDraft`，**不**改写 `solutions`/`displayed`。再次微调以草稿为基底。
    func adjustCurrentSolution(velocity v: Double? = nil,
                               spinX sx: Double? = nil, spinY sy: Double? = nil) {
        guard mode == .solve, !isPlaying, !isDragging else { return }
        guard displayed.indices.contains(currentIndex) else { return }
        let catalog = displayed[currentIndex]
        let base = adjustmentDraft ?? catalog
        let newPower = v ?? reflectionPower
        let newSX = Float(sx ?? Double(base.spinX))
        let newSY = Float(sy ?? Double(base.spinY))
        guard let cue = scene.cueBallNode?.position,
              let object = scene.targetBallNodes.first?.position else { return }
        let surfaceY = scene.surfaceY
        let pocket = selectedPocket
        // 重算沿**种子库序**（搜索锚）predict；展示库序按重算结果实测重标。
        let rails = catalog.seedRails
        let obstacles = currentObstacles()
        let idx = currentIndex
        // Supersede in-flight adjust (spin-pad continuous updates).
        adjustGeneration += 1
        let gen = adjustGeneration
        isSolving = true

        Task { [weak self] in
            var input = ShotInput(
                cueBall: cue, targetBall: object, pocketIndex: pocket,
                velocity: Float(newPower), spinX: newSX, spinY: newSY,
                surfaceY: surfaceY, bankRails: rails
            )
            input.obstacles = obstacles
            let pred = await Task.detached(priority: .userInitiated) {
                ShotPredictor.predict(input)
            }.value
            await MainActor.run {
                guard let self, self.adjustGeneration == gen, !self.isPlaying else { return }
                self.isSolving = false
                guard self.displayed.indices.contains(idx), self.currentIndex == idx else { return }
                // 草稿库序同解集口径：实测主库序重标（重算轨迹可能已换拓扑/脱靶，
                // 脱靶时保留原解标签避免 chip 闪变）。
                let actualRails = BankShotCalculator.reconstructedRailContacts(
                    object: object, departure: pred.objectDepartureDir,
                    engineRails: pred.objectRailContacts
                )
                let frozenSet = BankShotCalculator.frozenRails(for: object)
                let drafted = BankEngineSolution(
                    rails: actualRails.isEmpty ? catalog.rails : actualRails,
                    seedRails: rails, prediction: pred,
                    cushions: actualRails.isEmpty ? catalog.cushions : actualRails.count,
                    difficultyScore: catalog.difficultyScore,
                    difficultyTier: catalog.difficultyTier,
                    robustness: catalog.robustness, pathLength: catalog.pathLength,
                    spinX: newSX, spinY: newSY,
                    usedFrozenRailSeed: actualRails.first.map(frozenSet.contains) ?? false
                )
                self.adjustmentDraft = drafted
                self.presentDisplayedSolution(drafted, power: newPower)
            }
        }
    }

    func reset() {
        guard !isPlaying else { return }
        // applyBallLayout 会隐藏全部非 cue/target 球 ⇒ 障碍球一并清场回库。
        placeBalls()
        onTableObstacleKeys = []
        selectedPocket = 0
        selectedCushions = nil
        currentCushions = 0
        currentIndex = 0
        recompute()
    }

    /// Display / strike path: draft overrides catalog at `currentIndex` (X6 same contract).
    var currentSolution: BankEngineSolution? {
        guard displayed.indices.contains(currentIndex) else { return nil }
        return adjustmentDraft ?? displayed[currentIndex]
    }

    /// Catalog entry at `currentIndex` (ignores draft) — for tests / immutability asserts.
    var catalogSolution: BankEngineSolution? {
        displayed.indices.contains(currentIndex) ? displayed[currentIndex] : nil
    }

    /// Present a catalog solution at `index`, clearing any fine-tune draft.
    private func showSolution(at index: Int) {
        guard displayed.indices.contains(index) else { return }
        adjustmentDraft = nil
        currentIndex = index
        presentDisplayedSolution(displayed[index], power: catalogSolvePower)
    }

    /// Apply power/spin/trajectory from a solution (catalog or draft) without clearing draft.
    private func presentDisplayedSolution(_ sol: BankEngineSolution, power: Double) {
        isPresentingSolution = true
        reflectionPower = power
        spinX = Double(sol.spinX)
        spinY = Double(sol.spinY)
        isPresentingSolution = false
        hasSolution = true
        currentCushions = sol.cushions
        currentRailText = sol.railSequenceText
        currentCutAngle = Int((sol.prediction.cutAngleDeg ?? 0).rounded())
        currentDifficultyTier = sol.difficultyTier
        currentRobustnessPercent = sol.robustness.map { Int(($0 * 100).rounded()) }
        drawSolution(sol)
    }

    // MARK: - Status text（条 17.1/17.2/17.7：解描述 / 无解说明入 principal 副标题）

    /// 无解说明（含「暂无翻袋解」以便 UI 测试判定）。
    /// 贴库球形给出扎库语义提示——与求解门控 `maybePreReflectFrozenRailDeparture` 同口径。
    var noSolutionText: String {
        let frozen = scene.targetBallNodes.first.map {
            BankShotCalculator.isFrozenToAnyRail($0.position)
        } ?? false
        if frozen {
            if selectedCushions != nil {
                return "目标球贴库，该库数下无可行翻袋解（需先扎库弹出），换库数 / 袋口或移动球位"
            }
            return "目标球贴库，暂无可行翻袋解（贴库翻袋需先扎库弹出），换袋口或移动球位再试"
        }
        if selectedCushions != nil { return "该库数下无解，换库数 / 袋口或移动球位" }
        return "该袋暂无翻袋解，换袋口或移动球位再试"
    }

    /// principal 副标题文案：求解态 = 解读数 / 求解中 / 无解；自由态 = 首碰通称（替代原左下 pill）。
    var statusText: String {
        if mode == .free {
            if isPlaying { return "击球中…" }
            guard let c = freeAimContact else { return "空杆 — 拖动台面或刻度轮瞄准" }
            let name = BankKickFreePill.ballName(c.targetKey)
            let deg = Int(c.cutAngleDeg.rounded())
            let thick = AngleSceneCalculator.thicknessName(cutAngle: c.cutAngleDeg)
            return thick == "—" ? "首碰 \(name) · 切角 \(deg)°" : "首碰 \(name) · 切角 \(deg)° · \(thick)"
        }
        if isPlaying { return "演示中…" }
        if isDragging { return "拖动中 · 松手后求解" }
        if isSolving { return "真实物理求解中…" }
        guard hasSolution, let sol = currentSolution else { return noSolutionText }
        var parts = ["\(currentCushions) 库"]
        if !currentRailText.isEmpty { parts.append(currentRailText) }
        parts.append("切角 \(currentCutAngle)°")
        parts.append(sol.spinLabel)
        parts.append(currentDifficultyTier.label)
        if let robust = currentRobustnessPercent { parts.append("容错 \(robust)%") }
        if solutionCount > 1 { parts.append("解 \(currentIndex + 1)/\(solutionCount)") }
        return parts.joined(separator: " · ")
    }

    /// 球库点击在桌固定球（母球 / 黑 8）→ 桌上对应球放大脉冲提示位置（条 17.8）。
    func pulsePaletteBall(_ key: String) {
        let node: SCNNode? = key == PositionPlayBall.cueKey
            ? scene.cueBallNode
            : (key == Self.freeTargetName ? scene.targetBallNodes.first : scene.allBallNodes[key])
        guard let node, !node.isHidden else { return }
        node.removeAction(forKey: "palettePulse")
        node.runAction(SCNAction.sequence([
            SCNAction.scale(by: 1.35, duration: 0.15),
            SCNAction.scale(by: 1.0 / 1.35, duration: 0.25)
        ]), forKey: "palettePulse")
    }

    private func drawCurrent() {
        guard let sol = currentSolution else { clearPath(); return }
        presentDisplayedSolution(sol, power: adjustmentDraft == nil ? catalogSolvePower : reflectionPower)
    }

    // MARK: - Pocket highlight

    private func updatePocketHighlights() {
        // 单次求解只针对选定袋（引擎全枚举按袋进行）；其余袋口维持中性可选高亮。
        let feasiblePockets: Set<Int> = solutions.isEmpty ? [] : [selectedPocket]
        for (i, marker) in pocketMarkers.enumerated() {
            if i == selectedPocket {
                scene.setPocketHighlight(marker, style: .selected)
            } else {
                scene.setPocketHighlight(marker, style: feasiblePockets.contains(i) ? .viable : .infeasible)
            }
        }
    }

    // MARK: - Drawing

    /// 绘制引擎全保真解（K14）：走共享 `TrajectoryRenderer` / scene API——
    /// 进球线本色虚线、母球白实/虚分段、假想球虚线环+红心；**保留** full 档吃库金点+法线。
    ///
    /// 三档轨迹标注（C28/D15，与 Composer/Silu `positionPlay` 同口径）：
    /// `.minimal` = 瞄准实线段 + 假想球；
    /// `.core`    = + 进球虚线 + 母球碰后虚线 + 接触点；
    /// `.full`    = + 碰库金点/库面法线（翻袋特有释义层；线旁无「瞄准线/进球线」文字）。
    private func drawSolution(_ sol: BankEngineSolution) {
        clearPath()
        guard scene.cueBallNode?.position != nil else { return }
        let pred = sol.prediction
        guard pred.cuePath.count >= 2 || pred.objectPath.count >= 2 else { return }

        let detail = UserPreferences.shared.trajectoryDetail

        TrajectoryRenderer.draw(
            prediction: pred,
            options: .positionPlay,
            context: .init(
                prediction: pred,
                targetKey: Self.freeTargetName,
                pocket: ShotIntent.pocketId(for: selectedPocket),
                surfaceY: scene.surfaceY,
                showGhost: true
            ),
            scene: scene,
            into: &pathNodes
        )

        if detail == .full {
            // 翻袋特有：碰库金点 + 库面法线（用户要求保留）。
            for touch in BankKickSolvePipeline.cushionTouchPoints(pred.objectPath) {
                let dot = scene.addBall(at: touch.point, color: TrajectoryStyle.traceColor, radius: 0.012)
                pathNodes.append(dot)
                let len = AngleSceneCalculator.ballRadius * 2.2
                let normalEnd = SCNVector3(touch.point.x + touch.inwardNormal.x * len,
                                           touch.point.y,
                                           touch.point.z + touch.inwardNormal.z * len)
                let nLine = scene.addLine(from: touch.point, to: normalEnd,
                                          color: TrajectoryStyle.hintColor,
                                          radius: TrajectoryStyle.lineHint)
                pathNodes.append(nLine)
            }
        }
    }

    private func clearPath() {
        scene.clearResultNodes(nodes: &pathNodes)
        scene.ghostBallNode?.isHidden = true
        scene.contactDotNode?.isHidden = true
    }
}
