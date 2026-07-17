import Foundation
import SceneKit
import SwiftUI

/// 「分离角图谱」交互页 VM（v11 Y3）：真台 + 可拖双球 + 8 档 spinY 碰后轨迹。
///
/// 性能契约：力度/拖球变更 → `SolveDebounceScheduler` ~20ms 去抖 + 单飞 + 末班车；
/// 后台 `DispatchQueue.concurrentPerform` 并行 8 次 `simulateFree`。
@MainActor
final class SeparationAngleAtlasViewModel: ObservableObject {

    let scene = AngleTrainingScene()
    private var pocketMarkers: [SCNNode] = []
    private var trajectoryNodes: [SCNNode] = []
    private var labelNodes: [SCNNode] = []

    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2DRotated
    @Published var velocity: Double = ShotTuning.defaultVelocity
    @Published private(set) var cutAngleDegrees: Double = 0
    @Published private(set) var isDragging = false
    @Published private(set) var isComputing = false
    @Published private(set) var statusText: String?
    @Published private(set) var showSpinPad = false

    /// 打点盘只读：固定展示中心（spinX=0）；8 点由 overlay 自绘。
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
        [scene.cueBallNode, scene.allBallNodes["_8"]].compactMap { $0 }.filter { !$0.isHidden }
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
        scene.setCurrentTargetNumber(8)
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
              let target = scene.allBallNodes["_8"], !target.isHidden else { return }
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
              let target = scene.allBallNodes["_8"], !target.isHidden else { return }
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

    // MARK: - Velocity / spin pad

    func onVelocityChanged() {
        scheduleRecompute(interactive: false)
    }

    func toggleSpinPad() {
        showSpinPad.toggle()
    }

    func closeSpinPad() {
        showSpinPad = false
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

    private func currentIntent() -> Intent? {
        guard let cueNode = scene.cueBallNode,
              let targetNode = scene.allBallNodes["_8"], !targetNode.isHidden,
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
        return Intent(
            cue: cueNode.position,
            aim: aim,
            balls: [ObstacleBall(name: ShotInput.targetBallName, position: targetNode.position)],
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
        scene.clearResultNodes(nodes: &labelNodes)
    }

    private func drawTrajectories(_ paths: [[SCNVector3]]) {
        clearTrajectories()
        for (i, path) in paths.enumerated() where path.count >= 2 {
            scene.addDashedPolyline(
                path,
                color: SeparationAngleAtlasGeometry.trackColor(at: i),
                radius: TrajectoryStyle.lineMain,
                into: &trajectoryNodes)
        }
        // 仅两端标注：纯高杆 / 纯低杆
        if let high = paths.first, high.count >= 2 {
            let mid = high[high.count / 2]
            let pos = SCNVector3(mid.x, mid.y + 0.004, mid.z)
            labelNodes.append(scene.addFlatLabel(
                text: "纯高杆",
                at: pos,
                color: SeparationAngleAtlasGeometry.trackColor(at: 0),
                fontSize: 16))
        }
        if let low = paths.last, low.count >= 2 {
            let mid = low[low.count / 2]
            let pos = SCNVector3(mid.x, mid.y + 0.004, mid.z)
            labelNodes.append(scene.addFlatLabel(
                text: "纯低杆",
                at: pos,
                color: SeparationAngleAtlasGeometry.trackColor(at: SeparationAngleAtlasGeometry.sampleCount - 1),
                fontSize: 16))
        }
    }
}
