import Foundation
import SceneKit
import SwiftUI

@MainActor
final class AngleDynamicViewModel: ObservableObject {

    // MARK: - Scene

    let scene = AngleTrainingScene()
    private var pocketMarkers: [SCNNode] = []

    // MARK: - Published State

    /// 在桌球键（条 2：球库加减球）。
    @Published private(set) var onTableKeys: [String] = []
    /// 当前目标球键（条 2：目标球可选换号）。
    @Published private(set) var selectedTargetKey: String?

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

    // MARK: - Draggable / Selectable Nodes

    var draggableBalls: [SCNNode] {
        onTableKeys.compactMap { scene.allBallNodes[$0] }
    }

    /// 可点选为目标球的节点（在桌、非母球）。
    var selectableBalls: [SCNNode] {
        onTableKeys
            .filter { !PositionPlayBall.isCue($0) }
            .compactMap { scene.allBallNodes[$0] }
    }

    /// 当前目标球节点。
    var targetNode: SCNNode? {
        selectedTargetKey.flatMap { scene.allBallNodes[$0] }
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

        scene.hideAllBalls()
        scene.showBall(key: PositionPlayBall.cueKey,
                       scenePosition: SCNVector3(
                           -AngleSceneCalculator.innerLength / 2 * 0.6, surfaceY + r, 0))
        scene.showBall(key: "_8", scenePosition: SCNVector3(0, surfaceY + r, 0))
        selectedTargetKey = "_8"
        scene.setCurrentTargetNumber(8)
        refreshOnTableKeys()
    }

    // MARK: - Palette (条 2：加减球 / 目标球可选)

    private func refreshOnTableKeys() {
        onTableKeys = PositionPlayBall.allKeys.filter {
            !(scene.allBallNodes[$0]?.isHidden ?? true)
        }
    }

    /// 从球库上一颗球（自动找空位）；若为目标球且当前无目标则自动选中。
    func placeFromPalette(_ key: String) {
        guard scene.allBallNodes[key]?.isHidden ?? false else { return }
        let surfaceY = scene.surfaceY
        let r = AngleSceneCalculator.ballRadius
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2

        var pos = SCNVector3(0, surfaceY + r, 0)
        var found = false
        outer: for x in stride(from: -0.7, through: 0.7, by: 0.2) {
            for z in stride(from: -0.35, through: 0.35, by: 0.14) {
                let candidate = SCNVector3(Float(x) * halfL, surfaceY + r, Float(z) * halfW)
                if !overlapsExisting(candidate) {
                    pos = candidate
                    found = true
                    break outer
                }
            }
        }
        guard found else { return }
        scene.showBall(key: key, scenePosition: pos)
        refreshOnTableKeys()
        if !PositionPlayBall.isCue(key), selectedTargetKey == nil {
            selectTarget(key: key)
        } else {
            updatePocketHighlights()
            updateCalculations()
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
        updateCalculations()
    }

    /// 点选目标球（条 2：目标球可换号，进球线取色随之切换）。
    func selectTarget(key: String) {
        guard !PositionPlayBall.isCue(key), onTableKeys.contains(key) else { return }
        selectedTargetKey = key
        scene.setCurrentTargetNumber(PositionPlayBall.number(for: key))
        selectBestPocket()
        updateCalculations()
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

    /// 其余在桌球（排除母球与目标球）作为遮挡障碍。
    private var obstaclePositions: [SCNVector3] {
        onTableKeys.compactMap { key in
            guard key != selectedTargetKey, !PositionPlayBall.isCue(key),
                  let node = scene.allBallNodes[key], !node.isHidden else { return nil }
            return node.position
        }
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
        var clamped = clampMultiBall(worldPosition, movingNode: node)
        clamped = AngleSceneCalculator.clampAwayFromPockets(clamped, surfaceY: scene.surfaceY)
        node.position = clamped

        // Live update during drag: keep visualization & data panel in sync without
        // hiding anything. Pocket selection stays fixed; calculations recompute.
        updateCalculations()
    }

    /// 多球互斥钳制：台面范围内推开与其它在桌球的重叠。
    private func clampMultiBall(_ worldPosition: SCNVector3, movingNode: SCNNode) -> SCNVector3 {
        let r = AngleSceneCalculator.ballRadius
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let minDist = 2 * r * 1.02
        var p = worldPosition

        for _ in 0..<6 {
            var moved = false
            for k in onTableKeys {
                guard let other = scene.allBallNodes[k], other !== movingNode,
                      !other.isHidden else { continue }
                let dx = p.x - other.position.x
                let dz = p.z - other.position.z
                let dist = sqrtf(dx * dx + dz * dz)
                if dist < minDist {
                    if dist > 0.0001 {
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
        guard let cue = scene.cueBallNode, let target = targetNode else { return }
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
            return (false, "切角过大，该角度不可进球")
        }
        if AngleSceneCalculator.isCueBallBlocking(
            cueBall: cueBall, targetBall: targetBall, pocket: aim
        ) {
            return (false, "白球遮挡进球路线")
        }
        // 其余在桌球遮挡「母球→假想球」或「目标球→进球点」路径（条 2 多球）。
        let obstacles = obstaclePositions
        if !obstacles.isEmpty {
            let ghost = AngleSceneCalculator.ghostBallPosition(
                targetBall: targetBall, pocket: aim,
                ballRadius: AngleSceneCalculator.ballRadius
            )
            if AngleSceneCalculator.isPathBlocked(from: cueBall, to: ghost, obstacles: obstacles)
                || AngleSceneCalculator.isPathBlocked(from: targetBall, to: aim, obstacles: obstacles) {
                return (false, "有球遮挡进球路线")
            }
        }
        return (true, "")
    }

    private func updatePocketHighlights() {
        guard let cue = scene.cueBallNode, let target = targetNode else { return }

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
        guard let cue = scene.cueBallNode, let target = targetNode,
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

        // 为全部在桌球生成互不重叠的随机位。
        var placed: [SCNVector3] = []
        var newPositions: [String: SCNVector3] = [:]
        for key in onTableKeys {
            var pos = randomPos()
            var attempts = 0
            while placed.contains(where: { AngleSceneCalculator.ballsOverlap(pos, $0) }),
                  attempts < 50 {
                pos = randomPos()
                attempts += 1
            }
            pos = AngleSceneCalculator.clampAwayFromPockets(pos, surfaceY: surfaceY)
            placed.append(pos)
            newPositions[key] = pos
        }

        scene.hideAllVisualization()
        scene.hideCueStick()

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        for (key, pos) in newPositions {
            scene.allBallNodes[key]?.position = pos
        }
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
