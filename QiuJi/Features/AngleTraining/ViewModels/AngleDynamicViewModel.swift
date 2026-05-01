import Foundation
import SceneKit
import SwiftUI

@MainActor
final class AngleDynamicViewModel: ObservableObject {

    // MARK: - Scene

    let scene = AngleTrainingScene()
    private var pocketMarkers: [SCNNode] = []

    // MARK: - Published State

    @Published var selectedPocketIndex: Int = -1
    @Published private(set) var isDragging: Bool = false
    @Published private(set) var isFeasible: Bool = true
    @Published private(set) var infeasibleReason: String = ""
    /// Soft hint：动态调整后入袋点离袋口标记 > 1.5×R（贴库困难球），
    /// UI 可在数据面板提示"建议改换袋口"，不影响 feasibility。
    @Published private(set) var nearCushionHint: Bool = false

    @Published private(set) var cutAngleDegrees: Double = 0
    @Published private(set) var dOverR: Double = 0
    @Published private(set) var displacementMM: Double = 0
    @Published private(set) var offsetPercent: Double = 0
    @Published private(set) var thicknessName: String = "—"

    // MARK: - Camera

    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2DRotated

    // MARK: - Draggable Nodes

    var draggableBalls: [SCNNode] {
        [scene.cueBallNode, scene.targetBallNodes.first].compactMap { $0 }
    }

    // MARK: - Setup

    func setupScene() {
        scene.setupScene()
        scene.setupVisualizationNodes()
        pocketMarkers = scene.addPocketMarkers()

        placeBallsAtDefaults()
        selectBestPocket()
        updateCalculations()
    }

    // MARK: - Default Ball Positions

    private func placeBallsAtDefaults() {
        let surfaceY = scene.surfaceY
        let r = AngleSceneCalculator.ballRadius

        let cuePos = SCNVector3(
            -AngleSceneCalculator.innerLength / 2 * 0.6,
            surfaceY + r,
            0
        )
        let targetPos = SCNVector3(0, surfaceY + r, 0)

        scene.applyBallLayout(cueBallPosition: cuePos, targetBallNumber: 8, targetPosition: targetPos)
    }

    // MARK: - Drag Handling

    func dragBegan(node: SCNNode) {
        isDragging = true
        scene.hideCueStick()

        // USDZ-extracted balls carry a non-unit world scale on their wrapper.
        // Use a relative scale-by action so we don't clobber that to (1,1,1).
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.15, duration: 0.1), forKey: "dragPulse")
    }

    func dragMoved(node: SCNNode, worldPosition: SCNVector3) {
        let cueBall = scene.cueBallNode
        let targetBall = scene.targetBallNodes.first

        let otherBall: SCNNode?
        if node === cueBall {
            otherBall = targetBall
        } else {
            otherBall = cueBall
        }

        guard let other = otherBall else { return }

        var clamped = AngleSceneCalculator.clampBallPosition(
            worldPosition, otherBall: other.position, surfaceY: scene.surfaceY
        )
        clamped = AngleSceneCalculator.clampAwayFromPockets(clamped, surfaceY: scene.surfaceY)
        node.position = clamped

        // Live update during drag: keep visualization & data panel in sync without
        // hiding anything. Pocket selection stays fixed; calculations recompute.
        updateCalculations()
    }

    func dragEnded(node: SCNNode) {
        isDragging = false

        // Reverse the relative scale applied in dragBegan, preserving worldScale.
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.0 / 1.15, duration: 0.15))

        // 拖动结束后**不**自动重选袋口——用户期望保留当前选择，只有点击袋口或
        // 显式调用 randomize/reset 才会切换目标袋口。
        updatePocketHighlights()
        updateCalculations()
    }

    // MARK: - Pocket Selection

    func selectPocket(at index: Int) {
        selectedPocketIndex = index
        updatePocketHighlights()
        updateCalculations()
    }

    /// 根据当前球位选「最优袋口」——只在初始化 / 随机摆球 / 重置 时调用，
    /// **不在** drag 结束时调用，以避免目标球越过中线时袋口被自动顶替。
    func selectBestPocket() {
        guard let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        let pocketCount = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY).count

        var bestIndex = 0
        var bestAngle: Double = 999

        for i in 0..<pocketCount {
            guard pocketFeasibility(pocketIndex: i, cueBall: cue.position,
                                    targetBall: target.position).feasible else { continue }
            let aim = AngleSceneCalculator.effectivePocketAimPoint(
                targetBall: target.position, pocketIndex: i, surfaceY: scene.surfaceY
            )
            let angle = AngleSceneCalculator.cutAngle(
                cueBall: cue.position, targetBall: target.position, pocket: aim
            )
            if angle < bestAngle {
                bestAngle = angle
                bestIndex = i
            }
        }

        selectedPocketIndex = bestIndex
        updatePocketHighlights()
    }

    /// 综合可行性检查。
    ///
    /// 入袋点经 `effectivePocketAimPoint` 的「进球管道」模型动态调整：
    /// 管道安全时瞄袋口中心；靠库时自动选一条不碰库边的安全中心线。
    /// 本函数只判两种"真正不可进"：
    ///   1. 切球角 ≥ `maxCutAngle`（89°，接近物理极限）；
    ///   2. 白球遮挡进球路线。
    ///
    /// 对极端贴库球（动态调整后入袋点偏离袋口标记 > 1.5×R），不判不可进，
    /// 但在 `nearCushionHint` 上打标，UI 可作软提示。
    /// Returns (feasible, reason).
    private func pocketFeasibility(
        pocketIndex: Int, cueBall: SCNVector3, targetBall: SCNVector3
    ) -> (feasible: Bool, reason: String) {
        let aim = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: targetBall, pocketIndex: pocketIndex, surfaceY: scene.surfaceY
        )
        let angle = AngleSceneCalculator.cutAngle(
            cueBall: cueBall, targetBall: targetBall, pocket: aim
        )
        if angle >= AngleSceneCalculator.maxCutAngle {
            return (false, "切球角过大，该角度不可进球")
        }
        if AngleSceneCalculator.isCueBallBlocking(
            cueBall: cueBall, targetBall: targetBall, pocket: aim
        ) {
            return (false, "白球遮挡进球路线")
        }
        return (true, "")
    }

    private func updatePocketHighlights() {
        guard let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }

        for (i, marker) in pocketMarkers.enumerated() {
            if i == selectedPocketIndex {
                scene.setPocketHighlight(marker, style: .selected)
            } else {
                let feasible = pocketFeasibility(
                    pocketIndex: i, cueBall: cue.position, targetBall: target.position
                ).feasible
                scene.setPocketHighlight(marker, style: feasible ? .viable : .infeasible)
            }
        }
    }

    // MARK: - Calculations

    func updateCalculations() {
        guard let cue = scene.cueBallNode, let target = scene.targetBallNodes.first,
              selectedPocketIndex >= 0 else {
            isFeasible = false
            scene.hideAllVisualization()
            scene.hideCueStick()
            return
        }

        let pocketCount = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY).count
        guard selectedPocketIndex < pocketCount else { return }

        // 用「有效入袋点」代替「袋口中心」——考虑球体积 + 袋口嘴宽，
        // 自动给出贴库球等情况的正确进球点。
        let aim = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target.position,
            pocketIndex: selectedPocketIndex,
            surfaceY: scene.surfaceY
        )

        let result = pocketFeasibility(
            pocketIndex: selectedPocketIndex,
            cueBall: cue.position,
            targetBall: target.position
        )
        isFeasible = result.feasible
        infeasibleReason = result.reason
        // 贴库困难球软提示：动态调整后入袋点偏离袋口标记超过 1.5×R。
        nearCushionHint = result.feasible && !AngleSceneCalculator.isPocketReachable(
            target: target.position, pocketIndex: selectedPocketIndex, surfaceY: scene.surfaceY
        )

        let angle = AngleSceneCalculator.cutAngle(
            cueBall: cue.position, targetBall: target.position, pocket: aim
        )

        cutAngleDegrees = angle
        dOverR = AngleSceneCalculator.lateralDisplacement(cutAngle: angle)
        displacementMM = AngleSceneCalculator.lateralDisplacementMM(
            cutAngle: angle, ballRadius: Double(AngleSceneCalculator.ballRadius) * 1000
        )
        offsetPercent = AngleSceneCalculator.contactPointOffset(cutAngle: angle) * 100
        thicknessName = AngleSceneCalculator.thicknessName(cutAngle: angle)

        // The 角度与打点 page hides the cue stick per spec — only balls + viz lines visible.
        scene.hideCueStick()

        if result.feasible {
            scene.updateVisualization(
                cueBall: cue.position, targetBall: target.position, pocket: aim
            )
        } else {
            scene.hideAllVisualization()
        }
    }

    // MARK: - Random / Reset

    func randomizeBalls() {
        let surfaceY = scene.surfaceY
        let r = AngleSceneCalculator.ballRadius
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let margin = r * 3

        func randomPos() -> SCNVector3 {
            SCNVector3(
                Float.random(in: (-halfL + margin)...(halfL - margin)),
                surfaceY + r,
                Float.random(in: (-halfW + margin)...(halfW - margin))
            )
        }

        var cuePos = randomPos()
        var targetPos = randomPos()

        var attempts = 0
        while AngleSceneCalculator.ballsOverlap(cuePos, targetPos), attempts < 50 {
            targetPos = randomPos()
            attempts += 1
        }

        cuePos = AngleSceneCalculator.clampAwayFromPockets(cuePos, surfaceY: surfaceY)
        targetPos = AngleSceneCalculator.clampAwayFromPockets(targetPos, surfaceY: surfaceY)

        scene.hideAllVisualization()
        scene.hideCueStick()

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        scene.cueBallNode?.position = cuePos
        scene.targetBallNodes.first?.position = targetPos
        SCNTransaction.commit()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.selectBestPocket()
            self?.updateCalculations()
        }
    }

    func resetToDefaults() {
        scene.hideAllVisualization()
        scene.hideCueStick()
        placeBallsAtDefaults()
        selectBestPocket()
        updateCalculations()
    }

    // MARK: - Ball Pulse Animation

    func pulseBalls() {
        for ball in draggableBalls {
            let scaleUp = SCNAction.scale(by: 1.15, duration: 0.25)
            scaleUp.timingMode = .easeInEaseOut
            let scaleDown = SCNAction.scale(by: 1.0 / 1.15, duration: 0.25)
            scaleDown.timingMode = .easeInEaseOut
            ball.runAction(.sequence([scaleUp, scaleDown]))
        }
    }
}
