import Foundation
import SwiftUI
import SceneKit

/// Drives the 反射解球器 page: a 2D top-down table where the cue and target balls can be
/// placed **anywhere**, and the app solves pure-reflection bank-shot trajectories between
/// them. The user can pick a cushion count (or 自动 = minimum) and cycle through
/// alternative routes.
@MainActor
final class DiamondSystemViewModel: ObservableObject {

    // MARK: - Published state

    /// nil = 自动 (minimum cushions); otherwise the user-selected cushion count.
    @Published private(set) var selectedCushions: Int? = nil
    @Published private(set) var solutionCount: Int = 0      // count within the current filter
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var currentCushions: Int = 0
    @Published private(set) var currentRailText: String = ""
    @Published private(set) var hasSolution: Bool = false

    /// 真实反射模式开关（库边「偏短」），与翻袋页共享同一持久化设置。
    @Published var realMode: Bool = CushionReflectionSettings.realMode {
        didSet {
            CushionReflectionSettings.realMode = realMode
            recompute()
        }
    }
    /// 缩小因子（0.50–1.00）；仅真实模式下生效。
    @Published var reflectionFactor: Double = Double(CushionReflectionSettings.factor) {
        didSet {
            CushionReflectionSettings.factor = Float(reflectionFactor)
            if realMode { recompute() }
        }
    }

    /// Cushion options offered in the selector (nil sentinel handled in the View).
    let cushionOptions = [1, 2, 3, 4]

    private var effectiveFactor: Float { realMode ? Float(reflectionFactor) : 1.0 }

    // MARK: - Scene

    let scene = AngleTrainingScene()
    private var guideNodes: [SCNNode] = []
    private var pathNodes: [SCNNode] = []
    private var pocketMarkers: [SCNNode] = []

    /// Full sorted solution set (all cushion counts) for the current ball positions.
    private var solutions: [DiamondSystemCalculator.Solution] = []
    /// Solutions matching the current cushion filter.
    private var displayed: [DiamondSystemCalculator.Solution] = []

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
            labelColor: UIColor.white.withAlphaComponent(0.6),
            tickColor: UIColor.white.withAlphaComponent(0.45)
        )
    }

    private func placeBalls() {
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        let cuePos = SCNVector3(DiamondSystemCalculator.halfL * 0.55, y, DiamondSystemCalculator.halfW * 0.45)
        let targetPos = SCNVector3(-DiamondSystemCalculator.halfL * 0.45, y, -DiamondSystemCalculator.halfW * 0.3)
        scene.applyBallLayout(cueBallPosition: cuePos, targetBallNumber: 8, targetPosition: targetPos)
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

    // MARK: - Cushion selection

    func selectCushions(_ n: Int?) {
        selectedCushions = n
        currentIndex = 0
        recompute()
    }

    // MARK: - Solving

    /// Recompute solutions for current ball positions and redraw the current route.
    func recompute() {
        guard let cue = scene.cueBallNode?.position,
              let target = scene.targetBallNodes.first?.position else { return }

        let prevCushions = currentCushions
        solutions = DiamondSystemCalculator.solveAll(cue: cue, target: target,
                                                     surfaceY: scene.surfaceY, factor: effectiveFactor)

        if let n = selectedCushions {
            displayed = solutions.filter { $0.cushions == n }
        } else {
            displayed = solutions
        }
        solutionCount = displayed.count

        guard !displayed.isEmpty else {
            hasSolution = false
            currentIndex = 0
            currentCushions = 0
            currentRailText = ""
            clearPath()
            return
        }

        // Keep the same cushion count across drags when possible (feels stable).
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
        currentCushions = 0
        recompute()
    }

    private var currentSolution: DiamondSystemCalculator.Solution? {
        displayed.indices.contains(currentIndex) ? displayed[currentIndex] : nil
    }

    private func drawCurrent() {
        guard let sol = currentSolution else { clearPath(); return }
        hasSolution = true
        currentCushions = sol.cushions
        currentRailText = sol.railSequenceText
        drawSolution(sol)
    }

    // MARK: - Drawing

    private func drawSolution(_ sol: DiamondSystemCalculator.Solution) {
        clearPath()
        let path = sol.path
        guard path.count >= 2 else { return }

        // 真实模式：先画理想对照路线（浅蓝虚线）。
        if let ideal = sol.idealPath, ideal.count >= 2 {
            for i in 0..<(ideal.count - 1) {
                let dash = scene.addDashedLine(from: ideal[i], to: ideal[i + 1],
                                               color: UIColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 0.8),
                                               radius: 0.003)
                pathNodes.append(dash)
            }
        }

        // 实际走位（真实模式按缩小因子追迹）：黄色实线 + 红色碰库点。
        for i in 0..<(path.count - 1) {
            let line = scene.addLine(from: path[i], to: path[i + 1],
                                     color: UIColor.systemYellow, radius: 0.0045)
            pathNodes.append(line)
        }
        if path.count > 2 {
            for p in path[1..<(path.count - 1)] {
                let dot = scene.addBall(at: p, color: UIColor.systemRed, radius: 0.011)
                pathNodes.append(dot)
            }
        }
    }

    private func clearPath() {
        scene.clearResultNodes(nodes: &pathNodes)
    }
}
