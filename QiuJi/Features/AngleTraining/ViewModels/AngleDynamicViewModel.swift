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
        scene.hideAllVisualization()
        scene.hideCueStick()

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.1
        node.scale = SCNVector3(1.2, 1.2, 1.2)
        SCNTransaction.commit()
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
    }

    func dragEnded(node: SCNNode) {
        isDragging = false

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.15
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
        node.scale = SCNVector3(1, 1, 1)
        SCNTransaction.commit()

        selectBestPocket()
        updateCalculations()
    }

    // MARK: - Pocket Selection

    func selectPocket(at index: Int) {
        selectedPocketIndex = index
        updatePocketHighlights()
        updateCalculations()
    }

    func selectBestPocket() {
        guard let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY)

        var bestIndex = 0
        var bestAngle: Double = 999

        for (i, pocket) in pockets.enumerated() {
            let angle = AngleSceneCalculator.cutAngle(
                cueBall: cue.position, targetBall: target.position, pocket: pocket
            )
            let feasible = AngleSceneCalculator.isFeasible(
                cueBall: cue.position, targetBall: target.position, pocket: pocket
            )
            if feasible, angle < bestAngle {
                bestAngle = angle
                bestIndex = i
            }
        }

        selectedPocketIndex = bestIndex
        updatePocketHighlights()
    }

    private func updatePocketHighlights() {
        guard let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY)

        for (i, marker) in pocketMarkers.enumerated() {
            if i == selectedPocketIndex {
                scene.setPocketHighlight(marker, style: .selected)
            } else {
                let feasible = AngleSceneCalculator.isFeasible(
                    cueBall: cue.position, targetBall: target.position, pocket: pockets[i]
                )
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

        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY)
        guard selectedPocketIndex < pockets.count else { return }
        let pocket = pockets[selectedPocketIndex]

        let feasible = AngleSceneCalculator.isFeasible(
            cueBall: cue.position, targetBall: target.position, pocket: pocket
        )

        isFeasible = feasible

        let angle = AngleSceneCalculator.cutAngle(
            cueBall: cue.position, targetBall: target.position, pocket: pocket
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

        if feasible {
            infeasibleReason = ""
            scene.updateVisualization(
                cueBall: cue.position, targetBall: target.position, pocket: pocket
            )
        } else {
            if angle >= AngleSceneCalculator.maxCutAngle {
                infeasibleReason = "切球角过大，该角度不可进球"
            } else {
                infeasibleReason = "白球遮挡进球路线"
            }
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
            let scaleUp = SCNAction.scale(to: 1.15, duration: 0.25)
            scaleUp.timingMode = .easeInEaseOut
            let scaleDown = SCNAction.scale(to: 1.0, duration: 0.25)
            scaleDown.timingMode = .easeInEaseOut
            ball.runAction(.sequence([scaleUp, scaleDown]))
        }
    }
}
