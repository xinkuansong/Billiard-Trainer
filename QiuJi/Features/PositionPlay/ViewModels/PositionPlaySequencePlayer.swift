import Foundation
import SceneKit

/// 多杆走位序列播放器（ADR-P11-01）：把一条 `PositionPlaySequence` 在 SceneKit 真台上逐杆串播。
///
/// 每杆：摆 `before` 球形 → `ShotPredictor` 多球求解 → `TrajectoryPlayback` 驱动全部在桌球
/// 运动 → 进袋离场 → 推进到下一杆。供「走位训练」形态消费（不复用单杆 `DrillSceneView`）。
@MainActor
final class PositionPlaySequencePlayer: ObservableObject {

    let scene = AngleTrainingScene()
    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2DRotated
    @Published private(set) var currentStep = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var autoPlaying = false
    @Published private(set) var statusText = "准备就绪"

    private(set) var sequence: PositionPlaySequence
    private var trajectoryNodes: [SCNNode] = []

    var totalSteps: Int { sequence.steps.count }
    private var surfaceY: Float { scene.surfaceY }

    init(sequence: PositionPlaySequence) {
        self.sequence = sequence
    }

    func setupScene() {
        scene.setupScene()
        _ = scene.addPocketMarkers()
        scene.hideAllBalls()
        scene.hideCueStick()
        applyBoard(sequence.initial)
        currentStep = 0
        statusText = sequence.steps.isEmpty ? "空序列" : "第 1 / \(totalSteps) 杆"
    }

    // MARK: - Controls

    /// 从当前杆开始自动播放到结束。
    func playAll() {
        guard !isPlaying, !sequence.steps.isEmpty else { return }
        autoPlaying = true
        playCurrent()
    }

    /// 播放当前一杆（不自动续播）。
    func playOne() {
        guard !isPlaying, !sequence.steps.isEmpty else { return }
        autoPlaying = false
        playCurrent()
    }

    /// 跳到指定杆的开始球形（不播放）。
    func seek(to index: Int) {
        guard !isPlaying else { return }
        let clamped = max(0, min(index, max(0, totalSteps - 1)))
        currentStep = clamped
        if sequence.steps.isEmpty {
            applyBoard(sequence.initial)
        } else {
            applyBoard(sequence.steps[clamped].before)
            drawPlannedTrajectory(for: sequence.steps[clamped])
            statusText = "第 \(clamped + 1) / \(totalSteps) 杆"
        }
    }

    func reset() {
        guard !isPlaying else { return }
        autoPlaying = false
        currentStep = 0
        clearTrajectory()
        applyBoard(sequence.initial)
        statusText = sequence.steps.isEmpty ? "空序列" : "第 1 / \(totalSteps) 杆"
        if !sequence.steps.isEmpty { drawPlannedTrajectory(for: sequence.steps[0]) }
    }

    // MARK: - Play one step

    private func playCurrent() {
        guard currentStep < totalSteps else { autoPlaying = false; return }
        let step = sequence.steps[currentStep]
        applyBoard(step.before)
        clearTrajectory()

        guard let pred = solve(step), pred.feasible, let recorder = pred.recorder, pred.duration > 0.02 else {
            // 不可行：直接落到 after，推进。
            applyBoard(step.after)
            advanceAfterStep()
            return
        }

        isPlaying = true
        statusText = "第 \(currentStep + 1) / \(totalSteps) 杆 · 击球中…"

        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let speed: Float = 1.3

        let onKeys = step.before.onTable.keys.map { $0 }
        var cueAction: SCNAction?
        for key in onKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let name = predName(boardKey: key, targetKey: step.shot.targetKey)
            let action = playback.action(for: node, ballName: name, speed: speed, removeOnPocket: false)
            if key == PositionPlayBall.cueKey {
                cueAction = action
            } else if let action {
                node.runAction(action)
            }
        }

        if let cueAction, let cueNode = scene.allBallNodes[PositionPlayBall.cueKey] {
            cueNode.runAction(cueAction) { [weak self] in
                Task { @MainActor in self?.finishStep(step) }
            }
        } else {
            finishStep(step)
        }
    }

    private func finishStep(_ step: SequenceStep) {
        isPlaying = false
        applyBoard(step.after)
        advanceAfterStep()
    }

    private func advanceAfterStep() {
        if currentStep + 1 < totalSteps {
            currentStep += 1
            if autoPlaying {
                // 小停顿后续播下一杆。
                statusText = "第 \(currentStep + 1) / \(totalSteps) 杆"
                drawPlannedTrajectory(for: sequence.steps[currentStep])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self, self.autoPlaying else { return }
                    self.playCurrent()
                }
            } else {
                statusText = "第 \(currentStep + 1) / \(totalSteps) 杆"
                drawPlannedTrajectory(for: sequence.steps[currentStep])
            }
        } else {
            autoPlaying = false
            statusText = "完成 · 共 \(totalSteps) 杆"
        }
    }

    // MARK: - Board / trajectory

    private func applyBoard(_ board: BoardSnapshot) {
        scene.hideAllBalls()
        for (key, pt) in board.onTable {
            let p = AngleSceneCalculator.normalizedToScene(
                point: CGPoint(x: pt.x, y: pt.y), surfaceY: surfaceY
            )
            scene.showBall(key: key, scenePosition: p)
        }
    }

    /// 画出该杆的规划轨迹（淡色，作为练习参考）。
    private func drawPlannedTrajectory(for step: SequenceStep) {
        clearTrajectory()
        guard let pred = solve(step), pred.feasible else { return }
        let y = surfaceY + AngleSceneCalculator.ballRadius
        addPolyline(pred.cuePath, color: UIColor.white.withAlphaComponent(0.5), y: y)
        addPolyline(pred.objectPath,
                    color: UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.5), y: y)
    }

    private func addPolyline(_ pts: [SCNVector3], color: UIColor, y: Float) {
        guard pts.count >= 2 else { return }
        let lifted = pts.map { SCNVector3($0.x, y, $0.z) }
        for i in 0..<(lifted.count - 1) {
            trajectoryNodes.append(scene.addLine(from: lifted[i], to: lifted[i + 1], color: color, radius: 0.0035))
        }
    }

    private func clearTrajectory() {
        scene.clearResultNodes(nodes: &trajectoryNodes)
    }

    // MARK: - Solve

    private func solve(_ step: SequenceStep) -> ShotPrediction? {
        let before = step.before
        guard let cuePt = before.onTable[PositionPlayBall.cueKey],
              let targetPt = before.onTable[step.shot.targetKey],
              let pocketIndex = ShotIntent.pocketIndex(for: step.shot.pocket) else { return nil }
        let cue = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: cuePt.x, y: cuePt.y), surfaceY: surfaceY)
        let target = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: targetPt.x, y: targetPt.y), surfaceY: surfaceY)
        let obstacles: [ObstacleBall] = before.onTable.compactMap { key, pt in
            guard key != PositionPlayBall.cueKey, key != step.shot.targetKey else { return nil }
            let p = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: pt.x, y: pt.y), surfaceY: surfaceY)
            return ObstacleBall(name: key, position: p)
        }
        let input = ShotInput(
            cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
            velocity: Float(step.shot.velocity), spinX: Float(step.shot.spinX), spinY: Float(step.shot.spinY),
            surfaceY: surfaceY, obstacles: obstacles
        )
        return ShotPredictor.predict(input)
    }

    private func predName(boardKey: String, targetKey: String) -> String {
        if boardKey == PositionPlayBall.cueKey { return ShotInput.cueBallName }
        if boardKey == targetKey { return ShotInput.targetBallName }
        return boardKey
    }
}
