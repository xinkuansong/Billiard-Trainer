import Foundation
import SwiftUI
import SceneKit

/// 驱动「翻袋解球」页：2D 顶视图，母球与目标球均可自由摆放，用户再选定要翻进的袋口。
/// 求解器把目标球经 1/2/3 库纯反射送进该袋，并反推母球的瞄准线 / 幽灵球 / 接触点。
@MainActor
final class BankShotViewModel: ObservableObject {

    // MARK: - Published state

    /// 当前选定的袋口（与 `AngleSceneCalculator.pocketPositions` 索引一致）。
    @Published private(set) var selectedPocket: Int = 0
    /// nil = 自动（最少库）；否则为用户指定库数。
    @Published private(set) var selectedCushions: Int? = nil
    @Published private(set) var solutionCount: Int = 0
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var currentCushions: Int = 0
    @Published private(set) var currentRailText: String = ""
    @Published private(set) var currentCutAngle: Int = 0
    @Published private(set) var hasSolution: Bool = false

    let cushionOptions = [1, 2, 3]

    /// 各袋口名称（顺序同 pocketPositions：左上/右上/左下/右下/上中/下中）。
    let pocketNames = ["左上", "右上", "左下", "右下", "上中", "下中"]

    // MARK: - Scene

    let scene = AngleTrainingScene()
    private var guideNodes: [SCNNode] = []
    private var pathNodes: [SCNNode] = []
    private var pocketMarkers: [SCNNode] = []

    private var solutions: [BankShotCalculator.Solution] = []
    private var displayed: [BankShotCalculator.Solution] = []

    var draggableNodes: [SCNNode] {
        [scene.cueBallNode, scene.targetBallNodes.first].compactMap { $0 }
    }

    // MARK: - Setup

    func setupScene() {
        scene.setupScene(enhancedRendering: false)
        pocketMarkers = scene.addPocketMarkers()
        scene.setCameraMode(.topDown2DRotated, animated: false)
        rebuildGuides()
        placeBalls()
        recompute()
    }

    private func rebuildGuides() {
        scene.clearResultNodes(nodes: &guideNodes)
        let labels = DiamondSystemCalculator.diamondLabels(surfaceY: scene.surfaceY)
        let ticks = DiamondSystemCalculator.diamondTicks(surfaceY: scene.surfaceY)
        guideNodes = scene.addDiamondGuides(
            labels: labels,
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

    func dragBegan(node: SCNNode) {
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.15, duration: 0.1), forKey: "dragPulse")
    }

    func dragEnded(node: SCNNode) {
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.0 / 1.15, duration: 0.15))
        recompute()
    }

    func handleDrag(node: SCNNode, to worldPos: SCNVector3) {
        let other = (node === scene.cueBallNode) ? scene.targetBallNodes.first : scene.cueBallNode
        var clamped = AngleSceneCalculator.clampBallPosition(
            worldPos, otherBall: other?.position ?? worldPos, surfaceY: scene.surfaceY
        )
        clamped = AngleSceneCalculator.clampAwayFromPockets(clamped, surfaceY: scene.surfaceY)
        node.position = clamped
        recompute()
    }

    // MARK: - Pocket selection

    func selectPocket(_ index: Int) {
        guard index >= 0, index < pocketMarkers.count else { return }
        selectedPocket = index
        currentIndex = 0
        recompute()
    }

    // MARK: - Cushion selection

    func selectCushions(_ n: Int?) {
        selectedCushions = n
        currentIndex = 0
        recompute()
    }

    // MARK: - Solving

    func recompute() {
        guard let cue = scene.cueBallNode?.position,
              let object = scene.targetBallNodes.first?.position else { return }

        let prevCushions = currentCushions
        solutions = BankShotCalculator.solveAll(
            cue: cue, object: object, pocketIndex: selectedPocket, surfaceY: scene.surfaceY
        )

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
            clearPath()
            return
        }

        if selectedCushions == nil, prevCushions > 0,
           let idx = displayed.firstIndex(where: { $0.cushions == prevCushions }) {
            currentIndex = idx
        } else if currentIndex >= displayed.count {
            currentIndex = 0
        }
        drawCurrent()
    }

    func nextSolution() {
        guard !displayed.isEmpty else { return }
        currentIndex = (currentIndex + 1) % displayed.count
        drawCurrent()
    }

    func reset() {
        placeBalls()
        selectedPocket = 0
        selectedCushions = nil
        currentCushions = 0
        currentIndex = 0
        recompute()
    }

    private var currentSolution: BankShotCalculator.Solution? {
        displayed.indices.contains(currentIndex) ? displayed[currentIndex] : nil
    }

    private func drawCurrent() {
        guard let sol = currentSolution else { clearPath(); return }
        hasSolution = true
        currentCushions = sol.cushions
        currentRailText = sol.railSequenceText
        currentCutAngle = Int(sol.cutAngle.rounded())
        drawSolution(sol)
    }

    // MARK: - Pocket highlight

    private func updatePocketHighlights() {
        let feasiblePockets = Set(solutions.map(\.pocketIndex))
        for (i, marker) in pocketMarkers.enumerated() {
            if i == selectedPocket {
                scene.setPocketHighlight(marker, style: .selected)
            } else {
                scene.setPocketHighlight(marker, style: feasiblePockets.contains(i) ? .viable : .infeasible)
            }
        }
    }

    // MARK: - Drawing

    private func drawSolution(_ sol: BankShotCalculator.Solution) {
        clearPath()
        guard let cue = scene.cueBallNode?.position else { return }
        let path = sol.objectPath
        guard path.count >= 2 else { return }

        // 进球线（目标球的翻袋路线）：黄线 + 反弹红点。
        for i in 0..<(path.count - 1) {
            let line = scene.addLine(from: path[i], to: path[i + 1],
                                     color: UIColor.systemYellow, radius: 0.0045)
            pathNodes.append(line)
        }
        for p in sol.cushionPoints {
            let dot = scene.addBall(at: p, color: UIColor.systemRed, radius: 0.012)
            pathNodes.append(dot)
            // 反射法线：在反弹点画一条短的库面法线，直观体现「入射角 = 反射角」。
            if let normal = railNormalSegment(at: p) {
                let nLine = scene.addLine(from: normal.0, to: normal.1,
                                          color: UIColor.systemTeal.withAlphaComponent(0.85), radius: 0.0022)
                pathNodes.append(nLine)
            }
        }

        // 瞄准线（母球 → 幽灵球）：白线。
        let aim = scene.addLine(from: cue, to: sol.ghost, color: UIColor.white, radius: 0.004)
        pathNodes.append(aim)

        // 幽灵球（半透明）+ 接触点。
        pathNodes.append(addGhostSphere(at: sol.ghost))
        let contactDot = scene.addBall(at: SCNVector3(sol.contact.x, sol.contact.y + 0.001, sol.contact.z),
                                       color: UIColor.systemGreen, radius: 0.009)
        pathNodes.append(contactDot)

        // 行内文字标注。
        if let firstHop = path.dropFirst().first {
            pathNodes.append(scene.addFlatLabel(
                text: "进球线",
                at: midpoint(path[0], firstHop, lift: 0.004),
                color: UIColor.systemYellow, fontSize: 14))
        }
        pathNodes.append(scene.addFlatLabel(
            text: "瞄准线",
            at: midpoint(cue, sol.ghost, lift: 0.004),
            color: UIColor.white, fontSize: 14))
    }

    /// 在反弹点构造一条垂直于库面的短法线段（用于可视化反射对称）。
    private func railNormalSegment(at p: SCNVector3) -> (SCNVector3, SCNVector3)? {
        let eps: Float = 0.004
        let len: Float = AngleSceneCalculator.ballRadius * 2.2
        let halfL = BankShotCalculator.halfL
        let halfW = BankShotCalculator.halfW
        // 判断该点贴在哪条库上，法线指向台面内侧。
        if abs(p.z - (-halfW)) < eps { // 左库 → +Z
            return (p, SCNVector3(p.x, p.y, p.z + len))
        } else if abs(p.z - halfW) < eps { // 右库 → -Z
            return (p, SCNVector3(p.x, p.y, p.z - len))
        } else if abs(p.x - (-halfL)) < eps { // 底库 → +X
            return (SCNVector3(p.x, p.y, p.z), SCNVector3(p.x + len, p.y, p.z))
        } else if abs(p.x - halfL) < eps { // 顶库 → -X
            return (SCNVector3(p.x, p.y, p.z), SCNVector3(p.x - len, p.y, p.z))
        }
        return nil
    }

    private func addGhostSphere(at pos: SCNVector3) -> SCNNode {
        let sphere = SCNSphere(radius: CGFloat(AngleSceneCalculator.ballRadius))
        sphere.segmentCount = 24
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white.withAlphaComponent(0.45)
        mat.emission.contents = UIColor(white: 0.5, alpha: 1)
        mat.lightingModel = .constant
        sphere.materials = [mat]
        let node = SCNNode(geometry: sphere)
        node.position = pos
        scene.rootNode.addChildNode(node)
        return node
    }

    private func midpoint(_ a: SCNVector3, _ b: SCNVector3, lift: Float) -> SCNVector3 {
        SCNVector3((a.x + b.x) / 2, (a.y + b.y) / 2 + lift, (a.z + b.z) / 2)
    }

    private func clearPath() {
        scene.clearResultNodes(nodes: &pathNodes)
    }
}
