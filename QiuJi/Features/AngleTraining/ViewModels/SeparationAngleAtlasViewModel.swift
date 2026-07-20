import Foundation
import SceneKit
import SwiftUI

/// 「分离角图谱」交互页 VM（v11 Y3 / v15 W1）：真台 + 可拖多球 + 8 档 spinY 碰后轨迹。
///
/// 性能契约：力度/拖球变更 → `SolveDebounceScheduler` ~20ms 去抖 + 单飞 + 末班车；
/// 后台 `DispatchQueue.concurrentPerform` 并行 8 次 `simulateFree`。
/// 球库语义对齐「角度与瞄准」：换目标 / 加减障碍 / 母球不可撤（D-v15-1/3）。
@MainActor
final class SeparationAngleAtlasViewModel: ObservableObject {

    let scene = AngleTrainingScene()
    private var pocketMarkers: [SCNNode] = []
    private var trajectoryNodes: [SCNNode] = []

    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2DRotated
    @Published var velocity: Double = ShotTuning.defaultVelocity
    @Published private(set) var cutAngleDegrees: Double = 0
    @Published private(set) var isDragging = false
    @Published private(set) var isComputing = false
    @Published private(set) var statusText: String?

    /// 在桌球键（球库加减）。
    @Published private(set) var onTableKeys: [String] = []
    /// 当前目标球键（换号后进球线 / 切角 / 轨迹瞄准随之切换）。
    @Published private(set) var selectedTargetKey: String?

    /// 右侧仪表柱只读展示中心（spinX/Y=0）；左缘 8 盘图例为真源色序。
    let displaySpinX: Double = 0
    let displaySpinY: Double = 0

    private let solveScheduler = SolveDebounceScheduler(
        idleInterval: SolveDebounceScheduler.defaultFastInterval,
        fastInterval: SolveDebounceScheduler.defaultFastInterval
    )
    private let predictQueue = DispatchQueue(label: "qiuji.separationAngleAtlas.predict",
                                             qos: .userInitiated)
    private var predictInFlight = false
    private var predictRerunWanted = false
    private var predictGeneration = 0

    /// 最近一次 8 路并行耗时（ms），供性能取证；0 = 尚未跑过。
    /// `-y3.uiHooks` 下由 View 以只读读数暴露，UI 测抽取实测值。
    @Published private(set) var lastParallelSimMs: Double = 0

    var tableOuterHalfExtents: (length: Double, width: Double) {
        if let rig = scene.cameraRig {
            return (rig.tableOuterHalfLength, rig.tableOuterHalfWidth)
        }
        return (ShotTableLayout.defaultHalfLength, ShotTableLayout.defaultHalfWidth)
    }

    var draggableBalls: [SCNNode] {
        onTableKeys.compactMap { scene.allBallNodes[$0] }.filter { !$0.isHidden }
    }

    /// 可点选为目标球的节点（在桌、非母球）。
    var selectableBalls: [SCNNode] {
        onTableKeys
            .filter { !PositionPlayBall.isCue($0) }
            .compactMap { scene.allBallNodes[$0] }
    }

    var targetNode: SCNNode? {
        selectedTargetKey.flatMap { scene.allBallNodes[$0] }
    }

    // MARK: - Setup

    func setupScene() {
        scene.setupScene()
        scene.setupVisualizationNodes()
        pocketMarkers = scene.addPocketMarkers()
        placeDefaultBalls()
        selectBestPocket()
        updateAimVisualization()
        scheduleRecompute(interactive: false)
    }

    private func placeDefaultBalls() {
        let y = SeparationAngleAtlasGeometry.sceneKitBallY(surfaceY: scene.surfaceY)
        let s = SeparationAngleAtlasGeometry.defaultTeachingScene()
        scene.hideAllBalls()
        scene.showBall(key: PositionPlayBall.cueKey,
                       scenePosition: SCNVector3(Float(s.cue.x), y, Float(s.cue.y)))
        scene.showBall(key: "_8",
                       scenePosition: SCNVector3(Float(s.target.x), y, Float(s.target.y)))
        selectedTargetKey = "_8"
        scene.setCurrentTargetNumber(8)
        refreshOnTableKeys()
    }

    // MARK: - Palette (D-v15-1/3：对齐角度与瞄准语义)

    private func refreshOnTableKeys() {
        onTableKeys = PositionPlayBall.allKeys.filter {
            !(scene.allBallNodes[$0]?.isHidden ?? true)
        }
    }

    /// 从球库上一颗球（自动找空位）；若当前无目标则自动选中非母球。
    func placeFromPalette(_ key: String) {
        guard scene.allBallNodes[key]?.isHidden ?? false else { return }
        guard let pos = freeSlot() else { return }
        scene.showBall(key: key, scenePosition: pos)
        refreshOnTableKeys()
        if !PositionPlayBall.isCue(key), selectedTargetKey == nil {
            selectTarget(key: key)
        } else {
            updatePocketHighlights()
            updateAimVisualization()
            scheduleRecompute(interactive: false)
        }
    }

    /// 从球库拖放到指定世界坐标（落点钳制 + 互斥）。
    func placeFromPalette(_ key: String, atWorld world: SCNVector3) {
        guard scene.allBallNodes[key]?.isHidden ?? false else { return }
        guard let node = scene.allBallNodes[key] else { return }
        var p = clampBall(world, moving: node)
        p = AngleSceneCalculator.clampAwayFromPockets(p, surfaceY: scene.surfaceY)
        scene.showBall(key: key, scenePosition: p)
        refreshOnTableKeys()
        if !PositionPlayBall.isCue(key), selectedTargetKey == nil {
            selectTarget(key: key)
        } else {
            updatePocketHighlights()
            updateAimVisualization()
            scheduleRecompute(interactive: false)
        }
    }

    /// 撤下一颗在桌球（母球不可撤）。
    func removeFromTable(_ key: String) {
        guard !PositionPlayBall.isCue(key), onTableKeys.contains(key) else { return }
        scene.hideBall(key: key)
        refreshOnTableKeys()
        if selectedTargetKey == key {
            selectedTargetKey = onTableKeys.first { !PositionPlayBall.isCue($0) }
            scene.setCurrentTargetNumber(selectedTargetKey.flatMap { PositionPlayBall.number(for: $0) })
            selectBestPocket()
        }
        updatePocketHighlights()
        updateAimVisualization()
        scheduleRecompute(interactive: false)
    }

    /// 点选目标球（换号后切角 / 轨迹瞄准随之切换）。
    func selectTarget(key: String) {
        guard !PositionPlayBall.isCue(key), onTableKeys.contains(key) else { return }
        selectedTargetKey = key
        scene.setCurrentTargetNumber(PositionPlayBall.number(for: key))
        selectBestPocket()
        updateAimVisualization()
        scheduleRecompute(interactive: false)
    }

    /// 点在桌球的球库槽位 → 脉冲提示位置。
    func pulseTableBall(_ key: String) {
        guard let node = scene.allBallNodes[key], !node.isHidden else { return }
        TableBallPulse.pulse(node)
    }

    private func freeSlot() -> SCNVector3? {
        let surfaceY = scene.surfaceY
        let r = AngleSceneCalculator.ballRadius
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        for x in stride(from: -0.7, through: 0.7, by: 0.2) {
            for z in stride(from: -0.35, through: 0.35, by: 0.14) {
                let candidate = SCNVector3(Float(x) * halfL, surfaceY + r, Float(z) * halfW)
                if !overlapsExisting(candidate) { return candidate }
            }
        }
        return nil
    }

    private func overlapsExisting(_ pos: SCNVector3) -> Bool {
        for k in onTableKeys {
            guard let node = scene.allBallNodes[k], !node.isHidden else { continue }
            if AngleSceneCalculator.horizontalDistance(pos, node.position)
                < 2.2 * AngleSceneCalculator.ballRadius {
                return true
            }
        }
        return false
    }

    // MARK: - Pocket

    @Published private(set) var selectedPocketIndex: Int = -1

    func selectPocket(at index: Int) {
        selectedPocketIndex = index
        updatePocketHighlights()
        updateAimVisualization()
        scheduleRecompute(interactive: false)
    }

    func selectBestPocket() {
        guard let cue = scene.cueBallNode,
              let target = targetNode, !target.isHidden else { return }
        let count = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY).count
        var best = 0
        var bestAngle = Double.greatestFiniteMagnitude
        for i in 0..<count {
            let aim = AngleSceneCalculator.effectivePocketAimPoint(
                targetBall: target.position, pocketIndex: i, surfaceY: scene.surfaceY)
            let angle = AngleSceneCalculator.cutAngle(
                cueBall: cue.position, targetBall: target.position, pocket: aim)
            if angle < bestAngle, angle < AngleSceneCalculator.maxCutAngle {
                bestAngle = angle
                best = i
            }
        }
        selectedPocketIndex = best
        updatePocketHighlights()
    }

    private func updatePocketHighlights() {
        guard let cue = scene.cueBallNode,
              let target = targetNode, !target.isHidden else { return }
        for (i, marker) in pocketMarkers.enumerated() {
            if i == selectedPocketIndex {
                scene.setPocketHighlight(marker, style: .selected)
            } else {
                let aim = AngleSceneCalculator.effectivePocketAimPoint(
                    targetBall: target.position, pocketIndex: i, surfaceY: scene.surfaceY)
                let ok = AngleSceneCalculator.isFeasible(
                    cueBall: cue.position, targetBall: target.position, pocket: aim)
                scene.setPocketHighlight(marker, style: ok ? .viable : .infeasible)
            }
        }
    }

    // MARK: - Drag

    func dragBegan(node: SCNNode) {
        isDragging = true
        scene.hideCueStick()
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.15, duration: 0.1), forKey: "dragPulse")
    }

    func dragMoved(node: SCNNode, worldPosition: SCNVector3) {
        var p = clampBall(worldPosition, moving: node)
        p = AngleSceneCalculator.clampAwayFromPockets(p, surfaceY: scene.surfaceY)
        node.position = p
        updateAimVisualization()
        scheduleRecompute(interactive: true)
    }

    func dragEnded(node: SCNNode) {
        isDragging = false
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.0 / 1.15, duration: 0.15))
        updatePocketHighlights()
        updateAimVisualization()
        scheduleRecompute(interactive: false)
    }

    private func clampBall(_ world: SCNVector3, moving: SCNNode) -> SCNVector3 {
        let r = AngleSceneCalculator.ballRadius
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let minDist = 2 * r * 1.02
        var p = world
        let others = draggableBalls.filter { $0 !== moving }
        for _ in 0..<6 {
            var moved = false
            for other in others {
                let dx = p.x - other.position.x, dz = p.z - other.position.z
                let dist = sqrtf(dx * dx + dz * dz)
                if dist < minDist {
                    if dist > 1e-4 {
                        p.x = other.position.x + (dx / dist) * minDist
                        p.z = other.position.z + (dz / dist) * minDist
                    } else {
                        p.x += minDist
                    }
                    moved = true
                }
            }
            p.x = max(-halfL + r, min(halfL - r, p.x))
            p.z = max(-halfW + r, min(halfW - r, p.z))
            if !moved { break }
        }
        return SCNVector3(p.x, scene.surfaceY + r, p.z)
    }

    // MARK: - Velocity

    func onVelocityChanged() {
        scheduleRecompute(interactive: false)
    }

    // MARK: - Recompute (debounce + single-flight + last bus)

    func scheduleRecompute(interactive: Bool) {
        predictGeneration += 1
        isComputing = true
        statusText = "计算中…"
        solveScheduler.schedule(interactive: interactive) { [weak self] in
            self?.launchIfIdle()
        }
    }

    private func launchIfIdle() {
        if predictInFlight {
            predictRerunWanted = true
            return
        }
        guard let intent = currentIntent() else {
            isComputing = false
            statusText = "请摆好母球与目标球"
            clearTrajectories()
            return
        }
        let gen = predictGeneration
        let cue = intent.cue
        let aim = intent.aim
        let v = Float(velocity)
        let y = scene.surfaceY
        let balls = intent.balls
        let spins = SeparationAngleAtlasGeometry.spinYLevels()
        predictInFlight = true
        isComputing = true

        predictQueue.async { [weak self] in
            let t0 = CFAbsoluteTimeGetCurrent()
            var paths = Array(repeating: [SCNVector3](), count: spins.count)
            DispatchQueue.concurrentPerform(iterations: spins.count) { i in
                let pred = ShotPredictor.simulateFree(
                    cueBall: cue, aimDir: aim, velocity: v,
                    spinX: 0, spinY: spins[i],
                    surfaceY: y, balls: balls
                )
                paths[i] = SeparationAngleAtlasGeometry.pathAfterContactToFirstCueCushion(pred)
            }
            let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
#if DEBUG
            print(String(format: "[SeparationAngleAtlas] 8×simulateFree parallel %.1f ms", ms))
#endif
            DispatchQueue.main.async {
                guard let self else { return }
                self.lastParallelSimMs = ms
                self.predictInFlight = false
                if self.predictRerunWanted {
                    self.predictRerunWanted = false
                    self.launchIfIdle()
                }
                guard self.predictGeneration == gen else { return }
                self.isComputing = false
                self.statusText = nil
                self.drawTrajectories(paths)
            }
        }
    }

    private struct Intent {
        let cue: SCNVector3
        let aim: SCNVector3
        let balls: [ObstacleBall]
        let ghost: SCNVector3
        let potAim: SCNVector3
        let target: SCNVector3
    }

    /// 目标球 + 全部障碍球进入 `simulateFree`（D-v15-3）。
    private func currentIntent() -> Intent? {
        guard let cueNode = scene.cueBallNode,
              let targetKey = selectedTargetKey,
              let targetNode = scene.allBallNodes[targetKey], !targetNode.isHidden,
              selectedPocketIndex >= 0 else { return nil }
        let potAim = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: targetNode.position,
            pocketIndex: selectedPocketIndex,
            surfaceY: scene.surfaceY
        )
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: targetNode.position, pocket: potAim,
            ballRadius: AngleSceneCalculator.ballRadius
        )
        let dx = ghost.x - cueNode.position.x
        let dz = ghost.z - cueNode.position.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 1e-4 else { return nil }
        let aim = SCNVector3(dx / len, 0, dz / len)

        // 目标球用引擎具名；其余在桌非母球作障碍（真实碰撞体）。
        var balls: [ObstacleBall] = [
            ObstacleBall(name: ShotInput.targetBallName, position: targetNode.position)
        ]
        for key in onTableKeys where key != targetKey && !PositionPlayBall.isCue(key) {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            balls.append(ObstacleBall(name: key, position: node.position))
        }

        return Intent(
            cue: cueNode.position,
            aim: aim,
            balls: balls,
            ghost: ghost,
            potAim: potAim,
            target: targetNode.position
        )
    }

    // MARK: - Visualization

    private func updateAimVisualization() {
        scene.hideCueStick()
        guard let intent = currentIntent() else {
            cutAngleDegrees = 0
            scene.hideAllVisualization()
            return
        }
        cutAngleDegrees = AngleSceneCalculator.cutAngle(
            cueBall: intent.cue, targetBall: intent.target, pocket: intent.potAim)
        // 瞄准线 / 假想球 / 进球线 / 90° 短虚线走共享可视化；碰后 8 色轨迹另画。
        scene.updateVisualization(
            cueBall: intent.cue, targetBall: intent.target, pocket: intent.potAim,
            showAngleAnnotations: false, showOverlapMarkers: true, showLineLabels: false)
    }

    private func clearTrajectories() {
        scene.clearResultNodes(nodes: &trajectoryNodes)
    }

    /// 仅画 8 色碰后轨迹；端点文字标注已退役（v15 A1），改由左缘色盘图例表达。
    private func drawTrajectories(_ paths: [[SCNVector3]]) {
        clearTrajectories()
        for (i, path) in paths.enumerated() where path.count >= 2 {
            scene.addDashedPolyline(
                path,
                color: SeparationAngleAtlasGeometry.trackColor(at: i),
                radius: TrajectoryStyle.lineMain,
                into: &trajectoryNodes)
        }
    }
}
