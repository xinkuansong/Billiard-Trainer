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

    /// 真实反射模式开关（物理引擎按发力模拟翻库），与翻袋页共享同一持久化设置。
    @Published var realMode: Bool = CushionReflectionSettings.realMode {
        didSet {
            CushionReflectionSettings.realMode = realMode
            recompute()
        }
    }
    /// 发力（m/s）；仅真实模式下生效。
    @Published var reflectionPower: Double = Double(CushionReflectionSettings.power) {
        didSet {
            CushionReflectionSettings.power = Float(reflectionPower)
            if realMode { recompute() }
        }
    }

    /// Cushion options offered in the selector (nil sentinel handled in the View).
    let cushionOptions = [1, 2, 3, 4]

    // MARK: - Scene

    let scene = AngleTrainingScene()
    private var guideNodes: [SCNNode] = []
    private var pathNodes: [SCNNode] = []
    private var pocketMarkers: [SCNNode] = []

    /// Full sorted solution set (all cushion counts) for the current ball positions.
    private var solutions: [DiamondSystemCalculator.Solution] = []
    /// Solutions matching the current cushion filter.
    private var displayed: [DiamondSystemCalculator.Solution] = []
    /// 真实模式下的后台求解任务（引擎射击较重，需离开主线程并去抖）。
    private var solveTask: Task<Void, Never>?
    /// 真实模式正在后台求解（供 UI 显示加载态）。
    @Published private(set) var isSolving = false

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
    ///
    /// 理想模式：镜面展开极快，同步求解。
    /// 真实模式：引擎射击较重（每条解多次正向模拟），离开主线程并去抖（120ms），
    /// 拖动连续触发时只跑最后一次，旧任务取消，避免卡顿。
    func recompute() {
        guard let cue = scene.cueBallNode?.position,
              let target = scene.targetBallNodes.first?.position else { return }

        solveTask?.cancel()
        let prevCushions = currentCushions

        guard realMode else {
            isSolving = false
            let sols = DiamondSystemCalculator.solveAll(cue: cue, target: target,
                                                        surfaceY: scene.surfaceY,
                                                        realMode: false, power: Float(reflectionPower))
            applySolutions(sols, prevCushions: prevCushions)
            return
        }

        isSolving = true
        let cx = cue.x, cz = cue.z, tx = target.x, tz = target.z
        let surfaceY = scene.surfaceY
        let power = Float(reflectionPower)
        solveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            if Task.isCancelled { return }
            let sols = await Task.detached(priority: .userInitiated) {
                DiamondSystemCalculator.solveAll(
                    cue: SCNVector3(cx, 0, cz), target: SCNVector3(tx, 0, tz),
                    surfaceY: surfaceY, realMode: true, power: power)
            }.value
            if Task.isCancelled { return }
            guard let self else { return }
            self.isSolving = false
            self.applySolutions(sols, prevCushions: prevCushions)
        }
    }

    /// 应用求解结果（过滤、选路、绘制）。在主线程执行。
    private func applySolutions(_ sols: [DiamondSystemCalculator.Solution], prevCushions: Int) {
        solutions = sols

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

        // 真实模式：理想对照 = 线语言统一白虚线（T-P18-41，弃浅蓝）。
        if let ideal = sol.idealPath, ideal.count >= 2 {
            for i in 0..<(ideal.count - 1) {
                let dash = scene.addDashedLine(from: ideal[i], to: ideal[i + 1],
                                               color: TrajectoryStyle.hintColor,
                                               radius: TrajectoryStyle.lineHint,
                                               dash: TrajectoryStyle.hintDash,
                                               gap: TrajectoryStyle.hintGap)
                pathNodes.append(dash)
            }
        }

        // 实际走位 = 母球路径 → 身份色白实线（弃黄）+ 金色碰库点（方案标记，弃红）。
        for i in 0..<(path.count - 1) {
            let line = scene.addLine(from: path[i], to: path[i + 1],
                                     color: TrajectoryStyle.aimColor,
                                     radius: TrajectoryStyle.lineMain)
            pathNodes.append(line)
        }
        if path.count > 2 {
            for p in path[1..<(path.count - 1)] {
                let dot = scene.addBall(at: p, color: TrajectoryStyle.traceColor, radius: 0.011)
                pathNodes.append(dot)
            }
        }
    }

    private func clearPath() {
        scene.clearResultNodes(nodes: &pathNodes)
    }
}
