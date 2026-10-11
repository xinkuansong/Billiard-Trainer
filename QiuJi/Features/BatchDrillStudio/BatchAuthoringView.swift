//
//  BatchAuthoringView.swift
//  QiuJi
//
//  批量出片台 · 编排求解二合一（仅模拟器，内容生产工具）。
//
//  把「走位编排台」（摆球 + 手动设打点/力度 + 连续击打 + 录制成序列）与「思路训练器」
//  （画落区/落点反解出打点与力度）合到一页：
//  - 引擎复用 `PositionPlayViewModel`（已验证的录制状态机：摆球→击球→桌面前进→记一杆）；
//  - 反解复用 `PositionPlaySolver`（思路训练器同一求解器）：画约束 → 求出最优解 →
//    把解的塞/力度写回编排引擎的参数（target/pocket 已选中），再由「击球」记入序列。
//  默认「求解」（落区工具激活），可切「摆球」调整导入球形（拖球 / 球库增删）+ 手动设打点
//  力度；序列按 **drill_cNNN** 稳定键直写内容库，供 `make position-export` 出片并接入精讲页。
//

#if targetEnvironment(simulator)
import SwiftUI
import SceneKit

// MARK: - 反解层（在编排引擎之上叠加思路训练器的约束求解）

/// 操作传入的 `PositionPlayViewModel` 与其场景：画约束 → 反解 → 把最优解写回编排参数。
@MainActor
final class BatchShotSolver: ObservableObject {

    /// 摆球（arrange）= 调整球形（拖球 / 球库增删）+ 手动设打点力度；
    /// 自由（free）= 不选目标球/袋口，点桌面/球/袋口直瞄母球方向（安全球 / 解球 / 纯走位）；
    /// 其余为反解约束工具。
    enum Tool: Equatable { case arrange, free, region, restPoint, passPoint }

    @Published var activeTool: Tool = .region
    @Published var regionShape: SiluTrainerViewModel.RegionShape = .rect
    @Published var allowSideSpin = true
    @Published var basicPositionOnly = false
    @Published private(set) var hasConstraint = false
    @Published private(set) var isComputing = false
    @Published private(set) var solutions: [PositionPlaySolution] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var statusText =
        "默认求解：画落区/落点后点「求解」；或切「摆球」调整球形 + 手动设打点力度"

    /// 反解约束工具（落区/落点/过点）才覆盖绘制层并禁拖球；摆球不属此列。
    var isSolvingTool: Bool {
        activeTool == .region || activeTool == .restPoint || activeTool == .passPoint
    }

    var pointTolerance: Double = 0.02
    var passVMin: Double = 0.3

    private var draft: SiluTrainerViewModel.Draft?
    private var constraintNodes: [SCNNode] = []
    private let solveQueue = DispatchQueue(label: "com.qiuji.batch-solve", qos: .userInitiated)
    private var solveGeneration = 0

    var currentSolution: PositionPlaySolution? {
        solutions.indices.contains(currentIndex) ? solutions[currentIndex] : nil
    }
    var hasSolutions: Bool { !solutions.isEmpty }

    // MARK: 击球后/换杆：清掉上一杆的约束与解

    func resetForNextShot(scene: AngleTrainingScene) {
        draft = nil
        hasConstraint = false
        solutions = []
        currentIndex = 0
        clearConstraintNodes(scene: scene)
        if isSolvingTool {
            statusText = toolHint()
        }
    }

    // MARK: 约束绘制（归一化系）

    func toolDrag(start: CanvasPoint, current: CanvasPoint, ended: Bool,
                  scene: AngleTrainingScene, surfaceY: Float) {
        switch activeTool {
        case .arrange, .free:
            return
        case .passPoint:
            draft = .passPoint(current)
        case .restPoint:
            draft = .restPoint(current)
        case .region:
            switch regionShape {
            case .rect:
                let cx = (start.x + current.x) / 2, cy = (start.y + current.y) / 2
                let hw = max(0.01, abs(current.x - start.x) / 2)
                let hh = max(0.005, abs(current.y - start.y) / 2)
                draft = .region(.rect(center: CanvasPoint(x: cx, y: cy), halfWidth: hw, halfHeight: hh))
            case .circle:
                let dx = current.x - start.x, dy = current.y - start.y
                let r = max(0.01, (dx * dx + dy * dy).squareRoot())
                draft = .region(.circle(center: start, radius: r))
            }
        }
        hasConstraint = draft != nil
        renderConstraint(scene: scene, surfaceY: surfaceY)
        if ended, currentConstraint() != nil { statusText = "已就绪，点「求解」反解走位" }
    }

    func clearConstraint(scene: AngleTrainingScene) {
        draft = nil
        hasConstraint = false
        solutions = []
        currentIndex = 0
        clearConstraintNodes(scene: scene)
        statusText = toolHint()
    }

    private func currentConstraint() -> SolveConstraint? {
        switch draft {
        case .region(let r): return .restRegion(r)
        case .restPoint(let p): return .restRegion(.point(center: p, tolerance: pointTolerance))
        case .passPoint(let p): return .passThrough(point: p, vMin: passVMin)
        case nil: return nil
        }
    }

    // MARK: 反解（后台），结果把最优解的塞/力度写回编排引擎

    func solve(composer: PositionPlayViewModel, apply: @escaping (PlannedShot) -> Void) {
        guard let targetKey = composer.selectedTargetKey,
              composer.selectedPocketIndex >= 0,
              let pocketId = ShotIntent.pocketId(for: composer.selectedPocketIndex),
              let constraint = currentConstraint() else {
            statusText = "请先选目标球 + 袋口，并画一个约束"
            return
        }
        let before = composer.currentSnapshot()
        let y = composer.scene.surfaceY
        let params = searchParams(for: constraint)
        solveGeneration += 1
        let gen = solveGeneration
        isComputing = true
        statusText = "求解中…"

        solveQueue.async { [weak self] in
            let result = PositionPlaySolver.solve(
                before: before, targetKey: targetKey, pocket: pocketId,
                constraint: constraint, surfaceY: y, params: params)
            DispatchQueue.main.async {
                guard let self, self.solveGeneration == gen else { return }
                self.isComputing = false
                self.solutions = result
                self.currentIndex = 0
                if let best = result.first {
                    self.statusText = self.solutionStatus(best)
                    apply(best.shot)
                } else {
                    self.statusText = "未找到解（放大落区或换目标袋口）"
                }
            }
        }
    }

    func nextSolution(apply: (PlannedShot) -> Void) {
        guard !solutions.isEmpty else { return }
        currentIndex = (currentIndex + 1) % solutions.count
        let sol = solutions[currentIndex]
        statusText = solutionStatus(sol)
        apply(sol.shot)
    }

    private func searchParams(for constraint: SolveConstraint) -> PositionPlaySolver.SearchParams {
        var params: PositionPlaySolver.SearchParams
        switch constraint {
        case .restRegion: params = .standard
        case .passThrough: params = .passThrough
        }
        if !allowSideSpin { params.spinXValues = [0] }
        params.maxCushions = basicPositionOnly ? 1 : nil
        return params
    }

    private func solutionStatus(_ sol: PositionPlaySolution) -> String {
        let prefix = solutions.count > 1 ? "解 \(currentIndex + 1)/\(solutions.count) · " : ""
        let advanced = sol.beyondCushionBudget ? "进阶 · " : ""
        if !sol.satisfiesConstraint { return prefix + advanced + "最接近解 · " + sol.summary }
        return prefix + advanced + sol.summary
    }

    func toolHint() -> String {
        switch activeTool {
        case .arrange: return "摆球：拖/点球调位（含母球）· 左侧四键 0.5mm 精调 · 球库增删 · 设打点力度后击球"
        case .free: return "自由瞄：点桌面 / 球 / 袋口设定母球方向，右侧设打点 + 杆速点「击球」（不进球的安全球 / 走位）"
        case .region: return "在球桌上拖出\(regionShape.rawValue)可行落区，点「求解」"
        case .restPoint: return "点按球桌标出母球期望停的落点，点「求解」"
        case .passPoint: return "点按球桌标出母球需经过的 K 球点，点「求解」"
        }
    }

    // MARK: 约束渲染（青色落区 / 琥珀落点 / 青色过点十字）

    private func renderConstraint(scene: AngleTrainingScene, surfaceY: Float) {
        clearConstraintNodes(scene: scene)
        let cyan = BTScenePalette.constraintCyan
        let amber = UIColor(red: 1.0, green: 0.78, blue: 0.28, alpha: 0.95)
        let y = surfaceY + 0.002
        switch draft {
        case .region(let region):
            switch region {
            case let .circle(center, radius):
                SceneStroke.strokeCircle(center: scenePoint(center, y: y),
                                         radius: Float(radius) * SolveRegion.sceneScale,
                                         color: cyan, scene: scene, into: &constraintNodes)
            case let .rect(center, hw, hh):
                SceneStroke.strokeRect(center: scenePoint(center, y: y),
                                       halfX: Float(hw) * SolveRegion.sceneScale,
                                       halfZ: Float(hh) * SolveRegion.sceneScale,
                                       color: cyan, scene: scene, into: &constraintNodes)
            case let .point(center, tol):
                SceneStroke.strokeCircle(center: scenePoint(center, y: y),
                                         radius: Float(tol) * SolveRegion.sceneScale,
                                         color: cyan, scene: scene, into: &constraintNodes)
            case .sector:
                // 批量台 draft 不进 sector；穷尽分支。
                break
            }
        case .restPoint(let pt):
            let c = scenePoint(pt, y: y)
            SceneStroke.strokeCircle(center: c, radius: Float(pointTolerance) * SolveRegion.sceneScale,
                                     color: amber, scene: scene, into: &constraintNodes)
            strokeCross(center: c, arm: AngleSceneCalculator.ballRadius * 1.4, color: amber, scene: scene)
        case .passPoint(let pt):
            let c = scenePoint(pt, y: y)
            SceneStroke.strokeCircle(center: c, radius: AngleSceneCalculator.ballRadius,
                                     color: cyan, scene: scene, into: &constraintNodes)
            strokeCross(center: c, arm: AngleSceneCalculator.ballRadius * 1.6, color: cyan, scene: scene)
        case nil:
            break
        }
    }

    private func scenePoint(_ p: CanvasPoint, y: Float) -> SCNVector3 {
        AngleSceneCalculator.normalizedToScene(point: CGPoint(x: p.x, y: p.y), surfaceY: y)
    }

    private func strokeCross(center c: SCNVector3, arm r: Float, color: UIColor, scene: AngleTrainingScene) {
        constraintNodes.append(scene.addLine(from: SCNVector3(c.x - r, c.y, c.z),
                                             to: SCNVector3(c.x + r, c.y, c.z), color: color, radius: 0.0024, placement: .table))
        constraintNodes.append(scene.addLine(from: SCNVector3(c.x, c.y, c.z - r),
                                             to: SCNVector3(c.x, c.y, c.z + r), color: color, radius: 0.0024, placement: .table))
    }

    private func clearConstraintNodes(scene: AngleTrainingScene) {
        scene.clearResultNodes(nodes: &constraintNodes)
    }
}

// MARK: - 编排求解二合一视图

struct BatchAuthoringView: View {
    @ObservedObject var context: BatchAuthoringContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var composer = PositionPlayViewModel()
    @StateObject private var solver = BatchShotSolver()

    @State private var hasAppeared = false
    @State private var showSpinPad = false
    @State private var projector = TableProjector()

    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false
    @State private var sceneFrame: CGRect = .zero
    @State private var sceneFrameInWindow: CGRect?
    @State private var paletteFrame: CGRect = .zero
    @State private var toast: BTToastMessage?
    @State private var toastGeneration = 0
    @Environment(\.displayScale) private var displayScale
    @ObservedObject private var preferences = UserPreferences.shared
    @StateObject private var fps = TableFPSReadoutState()
    @State private var windowControls = UIEdgeInsets.zero
    @State private var windowSafeArea = UIEdgeInsets.zero
    @State private var systemStatusVisible = true
    @State private var portrait = false
    @State private var menu: AuthorMenu?
    @AppStorage("batchAuthor.spinDiscTransparency") private var spinTransparency = 0.5
    private enum AuthorMenu { case more, tools, trajectory, transparency }
    private let paletteKeys = (1...15).map { "_\($0)" }
    /// F-BD-01：覆盖确认（仅目标文件已存在时）。
    @State private var pendingOverwriteStay = false
    @State private var showOverwriteConfirm = false

    // 点换（条 20.3）：激活后点桌上另一颗球，与母球交换位置。
    @State private var swapMode = false

    /// 摆球精调焦点（含母球）。无选中时隐藏左侧四向键；离开摆球工具时清空。
    @State private var arrangeFocusKey: String?

    // 辅助线（条 20.4–20.9）：两步确认起/终点，±10° 吸附水平/垂直，白色；
    // 在线上的球自动均分；不进 JSON（仅场景节点）；击球时隐藏。
    @StateObject private var guide = BatchGuideLine()


    private var drill: BatchDrill? { context.current }

    var body: some View {
        GeometryReader { geo in
            let extraTop = UIDevice.current.userInterfaceIdiom == .pad ? max(0, windowSafeArea.top - geo.safeAreaInsets.top) : 0
            let extraBottom = UIDevice.current.userInterfaceIdiom == .pad ? max(0, windowSafeArea.bottom - geo.safeAreaInsets.bottom) : 0
            let size = CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                              height: max(0, geo.size.height - extraTop - extraBottom))
            ZStack(alignment: .topLeading) {
                template(size: size, safe: max(geo.safeAreaInsets.leading, geo.safeAreaInsets.trailing))
                    .frame(width: geo.size.width + geo.safeAreaInsets.trailing, alignment: .leading)
                    .padding(.top, extraTop).padding(.bottom, extraBottom)
                    .offset(x: -geo.safeAreaInsets.leading)
                    .ignoresSafeArea(.container, edges: .trailing)
                // DragGesture locations use the outer batchAuthor space, before safe-area offsets.
                if let draggingKey {
                    BTBallPaletteDragGhost(key: draggingKey, location: dragLocation, overTable: dragOverTable)
                }
            }.frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .animation(BTMotion.springPanel, value: showSpinPad)
        .coordinateSpace(name: "batchAuthor")
        .onPreferenceChange(BTShotPageFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let s = frames["scene.window"] { sceneFrameInWindow = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
        .background { DailyTableOrientation(landscape: true, allowsTabletRotation: true) }
        .environment(\.colorScheme, .dark)
        .environment(\.dailyHUDControls, true)
        .btDarkToolChrome("编排求解")
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(UIDevice.current.userInterfaceIdiom != .pad)
        .confirmationDialog(
            "覆盖已存序列？",
            isPresented: $showOverwriteConfirm,
            titleVisibility: .visible
        ) {
            Button("取消", role: .cancel) {}
            Button("覆盖", role: .destructive) {
                performSave(mode: pendingOverwriteStay ? .stay : .nextDrill)
            }
        } message: {
            Text("同图已有存档，保存将覆盖原杆序。")
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                composer.setupScene()
                updateProjection()
                if let editing = context.editingSequence {
                    // 存档 + 在原有基础上修改：用当前引擎重放重建，跳过拍照建球形。
                    let result = composer.loadSequenceForEditing(editing)
                    context.editingSequence = nil
                    if result.replayed < result.total {
                        flash("已重放 \(result.replayed)/\(result.total) 杆 · 第 \(result.replayed + 1) 杆在新物理下不可行，从此处修", tone: .warning)
                    } else {
                        flash("存档已载入 · \(result.total) 杆（末杆可「重打」重编）", tone: .success)
                    }
                } else {
                    if let board = context.confirmedBoard { composer.loadBoard(board) }
                    if let drill {
                        composer.renameSequence(
                            context.defaultSequenceName(
                                for: drill,
                                imageURL: context.sourceImageURL,
                                manualToken: context.manualFormationStem
                            ))
                    }
                    composer.startRecording()
                }
            }
        }
    }

    // MARK: - Daily Foundation (page points; scene gestures remain SCNView-local)

    private func template(size: CGSize, safe: CGFloat) -> some View {
        let side = max(4, safe)
        let extents = composer.tableOuterHalfExtents
        let reservation = DailyLayoutMetrics.FoundationReservation(width: size.width - 2 * side,
            targetCount: 15, chineseEightBall: true, titleWidth: 92, actionWidth: 138,
            prefersSeparateRow: size.height > size.width || size.height >= 600,
            separateWidth: size.width > size.height && size.height < 600 ? size.width - 2 * (side + 68) : nil)
        let f = DailyLayoutMetrics.Foundation(size: size, leadingSafeArea: safe, trailingSafeArea: safe,
            halfLength: extents.length, halfWidth: extents.width,
            instrumentHeight: DailyLayoutMetrics.Controls.initialInstrumentHeight, palette: reservation)
        let plan = DailyLayoutMetrics.Palette(size: size, sideInset: side, table: f.table,
            targetCount: 15, chineseEightBall: true, obstacles: [
                CGRect(x: side + windowControls.left, y: 0, width: 92, height: 44),
                CGRect(x: size.width - side - windowControls.right - 44, y: 0, width: 44, height: 44), f.left, f.right])
        let scale = f.table.height / CGFloat(2 * (f.rotated ? extents.length : extents.width))
        let innerSize = CGSize(width: CGFloat(f.rotated ? AngleSceneCalculator.innerWidth : AngleSceneCalculator.innerLength) * scale,
                               height: CGFloat(f.rotated ? AngleSceneCalculator.innerLength : AngleSceneCalculator.innerWidth) * scale)
        let inner = CGRect(x: f.table.midX - innerSize.width / 2, y: f.table.midY - innerSize.height / 2,
                           width: innerSize.width, height: innerSize.height)
        let metrics = BTTeachingInstrumentLayout(foundation: f)
        return ZStack(alignment: .topLeading) {
            // The actual SCNView has the Foundation stage's aspect and fit margin.
            // Its measured frame, not T/I, is the origin for all unprojection.
            sceneContainer
                .frame(width: f.stage.width, height: f.stage.height)
                .position(x: f.stage.midX, y: f.stage.midY)
                .allowsHitTesting(menu == nil && !showSpinPad && !editingBusy)
            if solver.isSolvingTool && !guide.isPicking && !swapMode && !showSpinPad && menu == nil {
                drawingOverlay.frame(width: f.stage.width, height: f.stage.height)
                    .position(x: f.stage.midX, y: f.stage.midY).allowsHitTesting(!editingBusy)
            }
            if guide.isPicking && !showSpinPad && menu == nil {
                guideOverlay.frame(width: f.stage.width, height: f.stage.height)
                    .position(x: f.stage.midX, y: f.stage.midY).allowsHitTesting(!editingBusy)
            }
            DailyTemplateHeader(size: size, safe: safe, foundation: f, plan: plan,
                targets: paletteKeys, chineseEightBall: true, titleWidth: 60, titleHeight: 34,
                windowControlInsets: windowControls, fps: fps, showsDeviceStatus: !systemStatusVisible,
                title: {
                    HStack(spacing: -12) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                        }.accessibilityLabel("返回").accessibilityIdentifier("batch.back")
                        BTTablePageTitle("编排求解", width: 60, compact: plan.diameter < DailyLayoutMetrics.regularBallDiameter)
                    }.fixedSize(horizontal: true, vertical: false)
                }, actions: {
                    Button { showSpinPad = false; menu = .more } label: {
                        Image(systemName: BTIcon.menuCircle).font(.system(size: 22, weight: .medium))
                            .frame(width: 44, height: 44).background { BTHUDControlBackground(shape: Circle()) }
                    }.buttonStyle(BTHUDPressStyle()).accessibilityLabel("更多").accessibilityIdentifier("batch.more")
                }, ball: { key, diameter, height in ballToken(key, diameter: diameter, slotHeight: height) },
                paletteMarker: { frameReader(id: "palette") })
                .background(DailyWindowControlInsets { controls, window, visible in
                    windowControls = controls; windowSafeArea = window; systemStatusVisible = visible
                }.allowsHitTesting(false))
            if solver.activeTool == .free {
                freeControls(metrics).frame(width: f.left.width, height: f.left.height, alignment: .top)
                    .position(x: f.left.midX, y: f.left.midY).accessibilityHidden(menu != nil)
            } else {
                let top = max(44, f.table.minY)
                let height = max(44, min(420, size.height - top))
                ScrollView(.vertical) { editorControls.padding(.vertical, 2) }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(width: 60, height: height).position(x: f.left.midX, y: top + height / 2)
                    .accessibilityIdentifier("batch.toolScroll").accessibilityHidden(menu != nil)
            }
            VStack(spacing: metrics.groupSpacing) {
                BTShotInstrumentColumn(spinX: composer.spinX, spinY: composer.spinY,
                    onSpinTap: { menu = nil; showSpinPad = true }, velocity: $composer.velocity,
                    range: ShotTuning.velocityRange, isDisabled: editingBusy,
                    fixedPowerBarHeight: metrics.rulerLength, powerLabel: "杆速", compactPowerBarWidth: metrics.rulerWidth,
                    compactSpinButtonDiameter: metrics.topDiameter, compactGroupSpacing: metrics.groupSpacing)
                Button { showSpinPad = false; strike() } label: {
                    Text(sequenceBusy ? BTStrikeTitle.freePlayBusy : BTStrikeTitle.freePlay)
                        .font(.btSubheadlineSemibold).frame(width: 60, height: 60)
                }.buttonStyle(DailyStrikeButtonStyle()).disabled(!strikeEnabled || solver.isComputing)
                    .opacity(strikeEnabled && !solver.isComputing ? 1 : 0.3).accessibilityIdentifier("batch.strike")
            }.frame(width: f.right.width, height: f.right.height, alignment: .top)
                .position(x: f.right.midX, y: f.right.midY)
            if !showSpinPad {
                BTNoticeContent(message: toast ?? BTToastMessage(guide.hint ?? (solver.isSolvingTool ? solver.statusText : composer.statusText), tone: .info), textOnly: true)
                    .frame(width: max(1, inner.width - 16))
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(x: inner.minX + 8, y: inner.minY + Spacing.md)
                    .allowsHitTesting(false).accessibilityIdentifier(toast == nil ? "batch.status" : "batch.notice")
            }
            if guide.isPicking && !showSpinPad && menu == nil {
                guideControls.position(x: inner.midX, y: inner.midY)
            }
            if showSpinPad {
                let layout = DailyLayoutMetrics.SpinPad(playingRect: inner, displayScale: displayScale,
                    maximumExtent: UIDevice.current.userInterfaceIdiom == .pad ? 310 : max(inner.width, inner.height))
                BTSceneSpinPadOverlay(spinX: $composer.spinX, spinY: $composer.spinY, scene: composer.scene,
                    tableWidth: inner.width, bottomPadding: (f.stage.height - layout.extent) / 2,
                    fixedCardExtent: layout.extent, discOpacity: 1 - spinTransparency, onClose: { showSpinPad = false })
                    .frame(width: f.stage.width, height: f.stage.height)
                    .position(x: f.stage.midX, y: f.stage.midY)
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-batchAuthor.audit")
                || ProcessInfo.processInfo.arguments.contains("-batchAuthor.markers") {
                TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                    ZStack(alignment: .topLeading) {
                        if BatchNudgeAudit.enabled {
                            Color.clear.frame(width: 2, height: 2)
                                .accessibilityElement().accessibilityLabel("微移触控事件")
                                .accessibilityIdentifier("batch.nudgeAudit")
                                .accessibilityValue(BatchNudgeAudit.snapshot)
                                .allowsHitTesting(false)
                        }
                        ForEach(composer.onTableKeys.sorted(), id: \.self) { key in
                            if let node = composer.scene.allBallNodes[key], !node.isHidden,
                               let point = projector.project?(node.position) {
                                Color.clear.frame(width: 2, height: 2).contentShape(Rectangle())
                                    .accessibilityElement().accessibilityIdentifier("batch.ball." + key)
                                    .accessibilityLabel(key)
                                    .accessibilityValue("x=\(node.position.x);z=\(node.position.z)")
                                    .position(point).allowsHitTesting(false)
                            }
                        }
                    }.frame(width: f.stage.width, height: f.stage.height)
                }.frame(width: f.stage.width, height: f.stage.height)
                    .position(x: f.stage.midX, y: f.stage.midY).allowsHitTesting(false)
            }
            #endif
            boundsMarker(f.table, id: "batch.tableBounds", value: f.rotated ? "竖桌" : "横桌")
            boundsMarker(inner, id: "batch.playingBounds", value: toolTitle)
            if let menu {
                Button { self.menu = nil } label: { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityLabel("关闭菜单").accessibilityIdentifier("batch.dismissMenu")
                Group {
                    if menu == .transparency {
                        DailySpinTransparencyPanel(transparency: $spinTransparency,
                            availableSize: CGSize(width: size.width - 2 * side, height: size.height - DailyLayoutMetrics.Panels.top - 8),
                            onClose: { self.menu = nil })
                    } else {
                        DailyHUDMenuPanel(title: menu == .tools ? "工具" : (menu == .trajectory ? "轨迹显示" : nil), items: menuItems,
                            availableSize: CGSize(width: size.width - 2 * side, height: size.height - DailyLayoutMetrics.Panels.top - 8),
                            onBack: { self.menu = .more }, onClose: { self.menu = nil })
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, DailyLayoutMetrics.Panels.top).padding(.trailing, side + windowControls.right)
            }
        }
        .foregroundStyle(.white).frame(width: size.width, height: size.height)
        .background { DailyCarpetBackground(style: preferences.roomStyle, pointsPerMetre: scale).ignoresSafeArea() }
        .onChange(of: f.rotated, initial: true) { _, value in portrait = value; updateProjection() }
        .onChange(of: size) { _, _ in menu = nil }
    }

    private func boundsMarker(_ rect: CGRect, id: String, value: String) -> some View {
        Color.clear.frame(width: rect.width, height: rect.height)
            .contentShape(Rectangle()).accessibilityElement().accessibilityLabel(id).accessibilityValue(value)
            .accessibilityIdentifier(id).allowsHitTesting(false).position(x: rect.midX, y: rect.midY)
    }

    private func updateProjection() {
        composer.cameraMode = portrait ? .topDown2DRotated : .topDown2D
        composer.scene.setCameraMode(composer.cameraMode, animated: false)
    }

    private var editingBusy: Bool { sequenceBusy || solver.isComputing }
    private var toolTitle: String {
        switch solver.activeTool {
        case .arrange: return "摆球"
        case .free: return "自由"
        case .region: return "落区"
        case .restPoint: return "落点"
        case .passPoint: return "过点"
        }
    }

    private func selectTool(_ tool: BatchShotSolver.Tool) {
        solver.activeTool = tool
        if tool != .arrange { arrangeFocusKey = nil }
        composer.aimMode = tool == .free ? .free : .pocket
        solver.clearConstraint(scene: composer.scene)
        swapMode = false; menu = nil
    }

    private func control(_ title: String, icon: String, id: String, enabled: Bool = true,
                         selected: Bool = false, size: CGFloat = 44, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 16, weight: .medium))
                Text(title).font(.btMicro).lineLimit(1)
            }.foregroundStyle(.white).frame(width: size, height: size)
                .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 14), selected: selected) }
        }.buttonStyle(BTHUDPressStyle()).disabled(!enabled).opacity(enabled ? 1 : 0.3)
            .accessibilityLabel(title).accessibilityIdentifier(id)
    }

    private var editorControls: some View {
        VStack(spacing: 4) {
            control(toolTitle, icon: "chevron.down", id: "batch.tool", enabled: !editingBusy) { showSpinPad = false; menu = .tools }
                .accessibilityValue(toolTitle).accessibilityHint("选择落区、落点、过点、摆球或自由")
            if solver.activeTool == .region {
                control(solver.regionShape.rawValue, icon: solver.regionShape == .rect ? "rectangle" : "circle", id: "batch.shape", enabled: !editingBusy) {
                    solver.regionShape = solver.regionShape == .rect ? .circle : .rect
                }
            }
            if solver.isSolvingTool {
                control("求解", icon: "scope", id: "batch.solve", enabled: !editingBusy && solver.hasConstraint) { solver.solve(composer: composer, apply: applyShot) }
                control("下一解", icon: "arrow.triangle.2.circlepath", id: "batch.nextSolution", enabled: !editingBusy && solver.solutions.count > 1) { solver.nextSolution(apply: applyShot) }
                control("清除", icon: "eraser", id: "batch.clearConstraint", enabled: !editingBusy && solver.hasConstraint) { solver.clearConstraint(scene: composer.scene) }
            }
            control("点换", icon: "arrow.left.arrow.right", id: "batch.swap", enabled: !editingBusy, selected: swapMode) { toggleSwapMode() }
            control(guide.phase == .off ? "辅助线" : "清除线", icon: "line.diagonal", id: "batch.guide", enabled: !editingBusy) { guideButtonTapped() }
            if solver.activeTool == .arrange && arrangeFocusKey != nil { ballNudgePad.disabled(editingBusy) }
            control("播序列", icon: "play.rectangle", id: "batch.playSequence", enabled: !editingBusy && composer.stepCount > 0) { composer.previewPlayRecordedSequence() }
                .accessibilityLabel("播放当前录制序列")
            control("重打", icon: "arrow.uturn.backward", id: "batch.rehit", enabled: !editingBusy && composer.canReplay) { composer.replayCurrent() }
            control("回放", icon: "play", id: "batch.replay", enabled: !editingBusy && composer.canPlayback) { composer.replayLastShot() }
        }
    }

    private func freeControls(_ metrics: BTTeachingInstrumentLayout) -> some View {
        VStack(spacing: metrics.groupSpacing) {
            BTTeachingInstrumentEntry(layout: metrics, label: "工具") {
                Button { showSpinPad = false; menu = .tools } label: {
                    VStack(spacing: 2) { Text("自由").font(.btFootnote); Image(systemName: "chevron.down").font(.btMicro) }
                        .foregroundStyle(.white).frame(width: metrics.topDiameter, height: metrics.topDiameter)
                        .background { BTHUDControlBackground(shape: Circle()) }
                }.buttonStyle(BTHUDPressStyle()).disabled(editingBusy)
                    .accessibilityIdentifier("batch.tool").accessibilityLabel("工具").accessibilityValue(toolTitle)
            }
            BTTeachingAimRuler(layout: metrics, enabled: !editingBusy, onNudge: { composer.nudgeFreeAim(byDegrees: $0) })
            let layout = metrics.horizontalActions ? AnyLayout(HStackLayout(spacing: 4)) : AnyLayout(VStackLayout(spacing: 4))
            layout {
                control("重打", icon: "arrow.uturn.backward", id: "batch.rehit", enabled: !editingBusy && composer.canReplay, size: metrics.auxiliarySize) { composer.replayCurrent() }
                control("回放", icon: "play", id: "batch.replay", enabled: !editingBusy && composer.canPlayback, size: metrics.auxiliarySize) { composer.replayLastShot() }
            }
        }
    }

    /// 把反解出的解写回编排引擎（target/pocket 已选中，只需设塞与力度）。
    private func applyShot(_ shot: PlannedShot) {
        composer.aimMode = .pocket
        composer.velocity = shot.velocity
        composer.spinX = shot.spinX
        composer.spinY = shot.spinY
    }

    private var ballNudgePad: some View {
        VStack(spacing: 6) {
            nudgeButton(dir: .up, icon: "chevron.up", label: "球位上移 0.5 毫米")
            nudgeButton(dir: .down, icon: "chevron.down", label: "球位下移 0.5 毫米")
            nudgeButton(dir: .left, icon: "chevron.left", label: "球位左移 0.5 毫米")
            nudgeButton(dir: .right, icon: "chevron.right", label: "球位右移 0.5 毫米")
        }
    }

    private func nudgeButton(dir: BallNudgeDirection, icon: String, label: String) -> some View {
        BatchScrollNudgeButton(icon: icon, accessibility: label) {
            guard let key = arrangeFocusKey else { return false }
            guard !editingBusy, let project = projector.project,
                  let node = composer.scene.allBallNodes[key], let origin = project(node.position) else { return false }
            // Select the world-axis step whose rendered direction matches the button.
            // This remains correct after either orientation, without changing the VM's portrait contract.
            let desired: CGPoint
            switch dir {
            case .up: desired = CGPoint(x: 0, y: -1)
            case .down: desired = CGPoint(x: 0, y: 1)
            case .left: desired = CGPoint(x: -1, y: 0)
            case .right: desired = CGPoint(x: 1, y: 0)
            }
            let mapped = BallNudgeDirection.allCases.max { a, b in
                func score(_ direction: BallNudgeDirection) -> CGFloat {
                    let d = BallNudgeMath.delta(for: direction, stepMeters: 0.1)
                    guard let point = project(SCNVector3(node.position.x + d.dx, node.position.y, node.position.z + d.dz)) else { return -.greatestFiniteMagnitude }
                    return (point.x - origin.x) * desired.x + (point.y - origin.y) * desired.y
                }
                return score(a) < score(b)
            } ?? dir
            return composer.nudgeBall(key: key, direction: mapped)
        }.accessibilityIdentifier("batch.nudge.\(dir)")
    }

    // MARK: - Scene

    private var sceneContainer: some View {
        AngleSceneView(
            scene: composer.scene,
            cameraMode: $composer.cameraMode,
            interactionMode: .tapsOnly,
            autoFitsLandscapeTable: true,
            backgroundColor: .clear,
            onPocketTapped: { composer.selectPocket(at: $0) },
            draggableBallNodes: solver.activeTool == .arrange ? composer.draggableBalls : [],
            onDragBegan: { node in
                composer.dragBegan(node: node)
                if solver.activeTool == .arrange,
                   let key = composer.scene.ballKey(for: node) {
                    arrangeFocusKey = key
                }
            },
            onDragMoved: { composer.dragMoved(node: $0, worldPosition: $1) },
            onDragEnded: { node in
                composer.dragEnded(node: node)
                redistributeGuideBalls()   // 拖球落在辅助线上 → 自动均分（条 20.6）
            },
            onDragEndedAt: { node, localPoint in handleTableDragEnd(node: node, localPoint: localPoint) },
            // 摆球态可选中母球（精调焦点）；其余态保持「仅目标球」点选。
            selectableBallNodes: solver.activeTool == .arrange
                ? composer.draggableBalls : composer.selectableBalls,
            onBallTapped: { handleBallTapped($0) },
            onTableTapped: { composer.handleTableTap(world: $0) },
            onAimNudged: { composer.nudgeFreeAim(byDegrees: $0) },
            projector: projector,
            contentIsAnimating: sequenceBusy,
            fpsReadoutState: fps,
            twoViewReadableFrameInWindow: sceneFrameInWindow
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(frameReader(id: "scene"))
        .background(GeometryReader { geometry in
            Color.clear.preference(key: BTShotPageFramePreference.self,
                value: ["scene.window": geometry.frame(in: .global)])
        })
        .clipped()
    }

    private var drawingOverlay: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("batchAuthor"))
                    .onChanged { handleDraw(start: $0.startLocation, current: $0.location, ended: false) }
                    .onEnded { handleDraw(start: $0.startLocation, current: $0.location, ended: true) }
            )
    }

    private func handleDraw(start: CGPoint, current: CGPoint, ended: Bool) {
        guard sceneFrame != .zero,
              let s = normalized(start), let c = normalized(current) else { return }
        solver.toolDrag(start: s, current: c, ended: ended,
                        scene: composer.scene, surfaceY: composer.scene.surfaceY)
    }

    private func normalized(_ point: CGPoint) -> CanvasPoint? {
        let local = CGPoint(x: point.x - sceneFrame.minX, y: point.y - sceneFrame.minY)
        guard let world = projector.unproject?(local) else { return nil }
        let n = AngleSceneCalculator.sceneToNormalized(position: world)
        return CanvasPoint(x: Double(n.x), y: Double(n.y))
    }

    /// 单杆回放中，或整段序列预览中（含杆间停顿）——禁止序列级操作。
    private var sequenceBusy: Bool {
        composer.isPlaying || composer.isSequencePlaying
    }

    private var strikeEnabled: Bool {
        !sequenceBusy && !composer.isComputing && composer.isFeasible
    }

    // MARK: - 点换（条 20.3）

    private func toggleSwapMode() {
        swapMode.toggle()
        if swapMode {
            guard composer.onTableKeys.contains(PositionPlayBall.cueKey) else {
                swapMode = false
                flash("桌面无母球，无法点换", tone: .warning)
                return
            }
            if guide.isPicking { guide.clear(scene: composer.scene) }
            flash("点目标球，与母球换位")
        }
    }

    /// 点球分流：点换 / 摆球焦点（含母球）/ 目标球选择。
    private func handleBallTapped(_ node: SCNNode) {
        if swapMode {
            performSwap(node)
            return
        }
        if solver.activeTool == .arrange,
           let key = composer.scene.ballKey(for: node) {
            arrangeFocusKey = key
            if !PositionPlayBall.isCue(key) {
                composer.selectTarget(key: key)
            }
            return
        }
        composer.selectTarget(node: node)
    }

    private func performSwap(_ node: SCNNode) {
        swapMode = false
        guard let key = composer.scene.ballKey(for: node),
              key != PositionPlayBall.cueKey,
              let cue = composer.scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden else {
            flash("请点击桌上一颗非母球", tone: .warning)
            return
        }
        let cuePos = cue.position
        cue.position = node.position
        node.position = cuePos
        composer.recompute()
        flash("已交换母球与 \(PositionPlayBall.shortLabel(for: key)) 的位置", tone: .success)
    }

    // MARK: - 辅助线（条 20.4–20.9）

    private func guideButtonTapped() {
        if guide.phase == .off {
            swapMode = false
            guide.begin()
        } else {
            guide.clear(scene: composer.scene)
        }
    }

    /// 辅助线取点覆盖层：拖/点选起点或终点（世界坐标经 projector 反投影）。
    private var guideOverlay: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("batchAuthor"))
                    .onChanged { setGuidePoint(at: $0.location) }
                    .onEnded { setGuidePoint(at: $0.location) }
            )

    }

    private func setGuidePoint(at location: CGPoint) {
        guard sceneFrame != .zero else { return }
        let local = CGPoint(x: location.x - sceneFrame.minX, y: location.y - sceneFrame.minY)
        guard let world = projector.unproject?(local) else { return }
        guide.setPoint(world, scene: composer.scene)
    }

    /// Prompt stays at the inner-cloth top; these independent actions stay at table centre.
    private var guideControls: some View {
        HStack(spacing: Spacing.sm) {
            control("确认", icon: "checkmark", id: "batch.guideConfirm", enabled: guide.hasCurrentPoint && !editingBusy) {
                if guide.confirm(scene: composer.scene) { redistributeGuideBalls() }
            }
            control("取消", icon: "xmark", id: "batch.guideCancel") { guide.clear(scene: composer.scene) }
        }.fixedSize()
    }

    /// 均分摆球（条 20.6）：把落在辅助线上的球调整到均分位置（1 球中点、2 球 1/3 与 2/3，
    /// 端点不放球），然后触发重算。
    private func redistributeGuideBalls() {
        if guide.redistribute(keys: composer.onTableKeys, scene: composer.scene) {
            composer.recompute()
            flash("在线球已均分排布", tone: .success)
        }
    }

    /// 击球：消费编排引擎的当前解推演并记一杆；完成后清掉本杆约束/解，准备下一杆。
    /// 辅助线在击球时隐藏（条 20.8）。
    private func strike() {
        guide.clear(scene: composer.scene)
        composer.play()
        // 击球后桌面前进、自动选下一杆（由 composer 处理）；清掉求解层上一杆约束。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            solver.resetForNextShot(scene: composer.scene)
        }
    }

    // MARK: - Palette

    private func ballToken(_ key: String, diameter: CGFloat, slotHeight: CGFloat) -> some View {
        let onTable = composer.onTableKeys.contains(key)
        let selected = composer.selectedTargetKey == key
        return Button {
            if onTable { composer.pulseTableBall(key) } else { composer.placeFromPalette(key); redistributeGuideBalls() }
        } label: {
            PoolBallFace(key: key, diameter: diameter).opacity(onTable ? 0.3 : 1)
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1).padding(-1).opacity(selected ? 1 : 0))
                .frame(width: diameter + 2, height: min(max(32, diameter), slotHeight))
                .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 4), selected: selected, normal: .clear) }
                .frame(height: slotHeight).contentShape(Rectangle())
        }.buttonStyle(BTHUDPressStyle()).disabled(editingBusy)
            .simultaneousGesture(DragGesture(minimumDistance: BTBallPaletteMetrics.dragMinimumDistance, coordinateSpace: .named("batchAuthor"))
                .onChanged { value in
                    guard !editingBusy, !onTable else { return }
                    draggingKey = key; dragLocation = value.location; dragOverTable = sceneFrame.contains(value.location)
                }.onEnded { value in
                    defer { draggingKey = nil; dragOverTable = false }
                    guard !editingBusy, !onTable, sceneFrame.contains(value.location) else { return }
                    let local = CGPoint(x: value.location.x - sceneFrame.minX, y: value.location.y - sceneFrame.minY)
                    if let world = projector.unproject?(local) { composer.placeFromPalette(key, atWorld: world); redistributeGuideBalls() }
                }, including: !onTable ? .all : .subviews)
            .accessibilityLabel("\(PositionPlayBall.shortLabel(for: key))号球")
            .accessibilityValue(onTable ? "在桌上" : "未在桌上")
            .accessibilityIdentifier("paletteBall_\(key)")
    }

    private func handleTableDragEnd(node: SCNNode, localPoint: CGPoint) {
        guard BTBallPaletteDragBack.hitPalette(localPoint: localPoint,
                                               sceneFrame: sceneFrame,
                                               paletteFrame: paletteFrame),
              let key = composer.scene.ballKey(for: node) else { return }
        composer.removeFromTable(key)
        if arrangeFocusKey == key { arrangeFocusKey = nil }
        flash("已移回球库", tone: .success)
    }

    // MARK: - More menu

    private var menuItems: [DailyHUDMenuItem] {
        if menu == .tools {
            return [("落区", BatchShotSolver.Tool.region), ("落点", .restPoint), ("过点", .passPoint), ("摆球", .arrange), ("自由", .free)].map { title, tool in
                DailyHUDMenuItem(id: "batch.tool." + title, title: title, selected: solver.activeTool == tool,
                    disabled: editingBusy, action: { selectTool(tool) })
            }
        }
        if menu == .trajectory {
            return TrajectoryDetail.allCases.map { detail in
                DailyHUDMenuItem(id: "batch.trajectory." + String(detail.rawValue), title: detail.label,
                    selected: preferences.trajectoryDetail == detail, disabled: editingBusy,
                    action: { preferences.trajectoryDetail = detail; composer.recompute(); menu = nil })
            }
        }
        return [
            .init(id: "batch.displayHeading", title: "显示"),
            .init(id: "batch.trajectory", title: "轨迹显示", detail: preferences.trajectoryDetail.label, disclosure: true,
                  action: { menu = .trajectory }),
            .init(id: "batch.transparency", title: "打点盘透明度", detail: "\(Int((spinTransparency * 100).rounded()))%",
                  action: { showSpinPad = true; menu = .transparency }),
            .init(id: "menu.tableGrid", title: "台面网格 4×8", selected: preferences.showTableGrid,
                  action: { preferences.showTableGrid.toggle(); composer.scene.setTableGridVisible(preferences.showTableGrid) }),
            .init(id: "batch.context", title: "\(drill?.drillId ?? "编排求解") · \(composer.stepCount) 杆"),
            .init(id: "batch.guide", title: guide.phase == .off ? "辅助线" : "清除辅助线", disabled: editingBusy,
                  action: { guideButtonTapped(); menu = nil }),
            .init(id: "batch.swap", title: "点换母球与目标球", selected: swapMode, disabled: editingBusy,
                  action: { toggleSwapMode(); menu = nil }),
            .init(id: "batch.playSequence", title: "播放当前录制序列", disabled: editingBusy || composer.stepCount < 1,
                  action: { composer.previewPlayRecordedSequence(); menu = nil }),
            .init(id: "batch.previousBoard", title: "回上一杆球形", disabled: editingBusy || !composer.canReplay,
                  action: { composer.restorePreviousBoard(); menu = nil }),
            .init(id: "batch.cue", title: "母球", detail: composer.onTableKeys.contains(PositionPlayBall.cueKey) ? "定位" : "摆回球桌", disabled: editingBusy,
                  action: {
                      if composer.onTableKeys.contains(PositionPlayBall.cueKey) { composer.pulseTableBall(PositionPlayBall.cueKey) }
                      else { composer.placeFromPalette(PositionPlayBall.cueKey) }
                      menu = nil
                  }),
            .init(id: "batch.solverHeading", title: "求解范围"),
            .init(id: "batch.sideSpin", title: "允许左右塞", selected: solver.allowSideSpin, disabled: editingBusy,
                  action: { solver.allowSideSpin.toggle() }),
            .init(id: "batch.basicPosition", title: "仅基础走位（≤1 库）", selected: solver.basicPositionOnly, disabled: editingBusy,
                  action: { solver.basicPositionOnly.toggle() }),
            .init(id: "batch.saveHeading", title: "保存去向"),
            .init(id: "batch.saveImage", title: "保存并选择下一张图", disabled: editingBusy,
                  action: { menu = nil; requestSave(mode: .stay) }),
            .init(id: "batch.saveDrill", title: "保存并进入下一个练习", disabled: editingBusy,
                  action: { menu = nil; requestSave(mode: .nextDrill) })
        ]
    }

    // MARK: - Save / advance

    /// 保存后的去向：`stay` 留在本 drill 回选图栅格挑下一张图（= 下一个球形）；
    /// `nextDrill` 跳到下一个还没有任何球形的 drill。
    private enum SaveMode { case stay, nextDrill }

    /// F-BD-01：仅当目标文件已存在时弹确认；不加「记住不再问」。
    /// 人工无图路径允许 `steps:[]`（initial-only）；截图来源路径仍要求 ≥1 杆。
    private func requestSave(mode: SaveMode) {
        guard let drill = context.current else { return }
        if !context.isManualFormationPath, composer.sequence.steps.isEmpty {
            flash("尚无击打：先「击球」记录至少一杆", tone: .info)
            return
        }
        let stem = archiveImageStem(for: drill)
        let legacy = context.editingLegacyArchive
        if BatchSequenceArchive.hasExistingArchive(drillId: drill.drillId, imageStem: stem, legacy: legacy) {
            pendingOverwriteStay = (mode == .stay)
            showOverwriteConfirm = true
        } else {
            performSave(mode: mode)
        }
    }

    private func performSave(mode: SaveMode) {
        guard let drill = context.current else { return }
        var seq = composer.sequence
        if !context.isManualFormationPath, seq.steps.isEmpty {
            flash("尚无击打：先「击球」记录至少一杆", tone: .info)
            return
        }
        // initial-only：录制后若又摆过球，以当前桌面为 initial（steps 仍为空）。
        if seq.steps.isEmpty {
            seq.initial = composer.currentSnapshot()
        }
        let imageURL = context.sourceImageURL
        // 球形 token：截图 stem / 人工 manualNN /（旧路径）drillId 单键。
        let stem = archiveImageStem(for: drill)
        // 旧版存档编辑：保留原序列名（未绑定截图，defaultSequenceName 的「球形K」不适用）。
        if !context.editingLegacyArchive {
            seq.name = context.defaultSequenceName(
                for: drill, imageURL: imageURL, manualToken: context.manualFormationStem)
        }
        seq.updatedAt = Date()
        do {
            _ = try BatchSequenceArchive.archive(seq, drillId: drill.drillId, imageStem: stem,
                                                 legacy: context.editingLegacyArchive)
            context.editingLegacyArchive = false
            context.refreshSaved()
            switch mode {
            case .stay:
                // 回拍照建球形选图栅格（同 drill），已存图打勾，自由挑下一张或跳过。
                context.confirmedBoard = nil
                context.sourceImageURL = nil
                context.manualFormationStem = nil
                context.pickerResetToken = UUID()
                dismiss()
            case .nextDrill:
                if context.advanceToNextUnsaved() {
                    dismiss()   // drillId 变 → 拍照页 onChange 重置到下一 drill 的选图
                } else {
                    flash("全部 drill 均已开工（≥1 球形）🎉", tone: .success)
                }
            }
        } catch {
            flash("保存失败：\(error.localizedDescription)", tone: .error)
        }
    }

    /// 归档用 imageStem：人工路径用 `manualFormationStem`；截图路径用文件名；否则 drillId。
    private func archiveImageStem(for drill: BatchDrill) -> String {
        if let manual = context.manualFormationStem { return manual }
        if let url = context.sourceImageURL {
            return url.deletingPathExtension().lastPathComponent
        }
        return drill.drillId
    }

    private func flash(_ message: String, tone: BTToastTone = .info) {
        toastGeneration += 1
        let generation = toastGeneration
        BTToast.present(message, tone: tone) { value in
            guard generation == toastGeneration else { return }
            toast = value
        }
    }

    private func frameReader(id: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: BTShotPageFramePreference.self,
                                   value: [id: geo.frame(in: .named("batchAuthor"))])
        }
    }
}

#if DEBUG
/// Diagnostic ring buffer only; the existing audit-only TimelineView reads it.
/// Recording never publishes state or invalidates the live gesture view.
private enum BatchNudgeAudit {
    private struct Entry {
        let time: TimeInterval
        let key: String
        let event: String
        var count: Int
    }
    private static var entries: [Entry] = []
    static let enabled = ProcessInfo.processInfo.arguments.contains("-batchAuthor.audit")

    static func record(key: String, event: String) {
        guard enabled else { return }
        if let last = entries.lastIndex(where: { $0.key == key }), entries[last].event == event {
            entries[last].count += 1
        } else {
            entries.append(Entry(time: ProcessInfo.processInfo.systemUptime, key: key, event: event, count: 1))
            if entries.count > 256 { entries.removeFirst(entries.count - 256) }
        }
    }

    static var snapshot: String {
        entries.map { String(format: "%.3f", $0.time) + " " + $0.key + " " + $0.event + " ×" + String($0.count) }
            .joined(separator: "\n")
    }
}
#endif

// MARK: - Scroll-compatible editor nudge

/// A scroll must be distinguishable from a nudge before mutating the ball.
/// Tap commits on release; a stationary 0.4s hold starts the same accelerating
/// 0.5mm action. This local policy leaves non-scrolling shared controls unchanged.
private struct BatchScrollNudgeButton: View {
    let icon: String
    let accessibility: String
    let onStep: () -> Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isPressing = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white.opacity(isPressing ? 1 : 0.82))
            .frame(width: 30, height: 30)
            .background(isPressing ? HUDStyle.selectedBackground : .white.opacity(0.12), in: Circle())
            .frame(width: 44, height: 44)
            .overlay {
                BatchNudgeGestureSurface(enabled: isEnabled, isPressing: $isPressing, auditKey: icon, onStep: onStep)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibility)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if isEnabled { _ = onStep() } }
    }
}

private struct BatchNudgeGestureSurface: UIViewRepresentable {
    let enabled: Bool
    @Binding var isPressing: Bool
    let auditKey: String
    let onStep: () -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.hold(_:)))
        hold.minimumPressDuration = 0.4
        hold.allowableMovement = 10
        // A completed hold must never also commit the release as a single tap.
        tap.require(toFail: hold)
        // Install the same explicit touch gate in normal and diagnostic runs.
        // Audit recording must not alter the recognizers' delegate arrangement.
        tap.delegate = context.coordinator
        hold.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(hold)
        context.coordinator.trace("make view=\(ObjectIdentifier(view))")
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.trace("update view=\(ObjectIdentifier(view)) enabled=\(enabled) states=\((view.gestureRecognizers ?? []).map { "\(type(of: $0)):\($0.state.rawValue):\($0.isEnabled)" }.joined(separator: ","))")
        for gesture in view.gestureRecognizers ?? [] { gesture.isEnabled = enabled }
        if !enabled { context.coordinator.stop() }
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.trace("dismantle view=\(ObjectIdentifier(view))")
        coordinator.stop()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: BatchNudgeGestureSurface
        private var timer: Timer?
        private var ticks = 0
        private var repeating = false

        init(parent: BatchNudgeGestureSurface) { self.parent = parent }

        func trace(_ event: @autoclosure () -> String) {
            #if DEBUG
            guard BatchNudgeAudit.enabled else { return }
            BatchNudgeAudit.record(key: parent.auditKey, event: event())
            #endif
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            trace("receive \(type(of: gestureRecognizer)) enabled=\(gestureRecognizer.isEnabled) point=\(touch.location(in: gestureRecognizer.view)) window=\(touch.location(in: nil)) view=\(gestureRecognizer.view.map { String(describing: ObjectIdentifier($0)) } ?? "nil") bounds=\(gestureRecognizer.view?.bounds ?? .zero) frameWindow=\(gestureRecognizer.view.map { $0.convert($0.bounds, to: nil) } ?? .zero)")
            return parent.enabled
        }

        @objc func tap(_ gesture: UITapGestureRecognizer) {
            trace("tap state=\(gesture.state.rawValue) enabled=\(parent.enabled)")
            guard gesture.state == .ended, parent.enabled else { return }
            _ = step()
        }

        @objc func hold(_ gesture: UILongPressGestureRecognizer) {
            trace("hold state=\(gesture.state.rawValue) enabled=\(parent.enabled)")
            switch gesture.state {
            case .began:
                guard parent.enabled else { return }
                repeating = true
                parent.isPressing = true
                if step() { scheduleNext(after: 0.12) } else { stop() }
            case .ended, .cancelled, .failed:
                stop()
            default:
                break
            }
        }

        private func step() -> Bool {
            guard parent.enabled else { return false }
            let moved = parent.onStep()
            trace("step moved=\(moved) repeating=\(repeating) ticks=\(ticks)")
            UIImpactFeedbackGenerator(style: moved ? .light : .rigid)
                .impactOccurred(intensity: moved ? 0.6 : 0.9)
            return moved
        }

        private func scheduleNext(after delay: TimeInterval) {
            timer?.invalidate()
            let next = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
                guard let self, self.repeating else { return }
                guard self.step() else { self.stop(); return }
                self.ticks += 1
                self.scheduleNext(after: max(0.05, 0.12 - Double(self.ticks) * 0.005))
            }
            timer = next
            RunLoop.main.add(next, forMode: .common)
        }

        func stop() {
            trace("stop repeating=\(repeating) ticks=\(ticks)")
            timer?.invalidate()
            timer = nil
            repeating = false
            ticks = 0
            if parent.isPressing { parent.isPressing = false }
        }
    }
}

// MARK: - 辅助线（条 20.4–20.9）

/// 出片台辅助线状态机：起点/终点两步确认；终点与水平/垂直夹角 < 10° 自动吸附
/// （SceneKit X–Z 台面系：吸附 = 对齐 X 轴向或 Z 轴向）；白色；只存在于场景节点
/// （不进 JSON）；击球时由宿主 `clear` 隐藏。
@MainActor
final class BatchGuideLine: ObservableObject {
    enum Phase: Equatable { case off, pickStart, pickEnd, placed }

    @Published private(set) var phase: Phase = .off
    // P12.1：必须 @Published——「确认」按钮 enabled 依赖 `hasCurrentPoint`，
    // 选点只改这两个属性不改 phase，非 @Published 时视图不重渲、按钮永远禁用。
    @Published private(set) var startPoint: SCNVector3?
    @Published private(set) var endPoint: SCNVector3?
    private var nodes: [SCNNode] = []

    /// 吸附阈值（度）：与水平/垂直夹角小于该值时归为轴向线（条 20.4）。
    static let snapDeg: Float = 10

    var isPicking: Bool { phase == .pickStart || phase == .pickEnd }

    /// 当前阶段是否已有可确认的点。
    var hasCurrentPoint: Bool {
        switch phase {
        case .pickStart: return startPoint != nil
        case .pickEnd: return endPoint != nil
        default: return false
        }
    }

    var hint: String? {
        switch phase {
        case .off, .placed: return nil
        case .pickStart: return startPoint == nil ? "点按球桌选起点" : "可拖动微调起点"
        case .pickEnd: return endPoint == nil ? "点按球桌选终点" : "±10° 自动吸附水平/垂直"
        }
    }

    func begin() {
        startPoint = nil
        endPoint = nil
        phase = .pickStart
    }

    /// 取点（世界坐标）：pickStart 设起点，pickEnd 设终点（带轴向吸附）。
    func setPoint(_ world: SCNVector3, scene: AngleTrainingScene) {
        let y = scene.surfaceY + 0.003
        let p = SCNVector3(world.x, y, world.z)
        switch phase {
        case .pickStart:
            startPoint = p
        case .pickEnd:
            guard let a = startPoint else { return }
            endPoint = snapped(end: p, from: a)
        default:
            return
        }
        render(scene: scene)
    }

    /// 确认当前点：起点 → 进入终点阶段；终点 → 定线。返回 true = 辅助线已就位
    /// （宿主随即做一次均分摆球）。
    @discardableResult
    func confirm(scene: AngleTrainingScene) -> Bool {
        switch phase {
        case .pickStart where startPoint != nil:
            phase = .pickEnd
            return false
        case .pickEnd where endPoint != nil:
            phase = .placed
            render(scene: scene)
            return true
        default:
            return false
        }
    }

    func clear(scene: AngleTrainingScene) {
        scene.clearResultNodes(nodes: &nodes)
        startPoint = nil
        endPoint = nil
        phase = .off
    }

    /// 终点吸附：与 X 轴向夹角 < 10° → 对齐起点 Z（水平）；与 Z 轴向夹角 < 10° →
    /// 对齐起点 X（垂直）；其余保留原始终点（条 20.4）。
    private func snapped(end: SCNVector3, from start: SCNVector3) -> SCNVector3 {
        let dx = abs(end.x - start.x)
        let dz = abs(end.z - start.z)
        guard dx > 1e-5 || dz > 1e-5 else { return end }
        let angleToXAxis = atan2f(dz, dx) * 180 / .pi
        if angleToXAxis < Self.snapDeg { return SCNVector3(end.x, end.y, start.z) }
        if angleToXAxis > 90 - Self.snapDeg { return SCNVector3(start.x, end.y, end.z) }
        return end
    }

    /// 渲染：白色细线 + 起/终点小十字（条 20.9）。
    private func render(scene: AngleTrainingScene) {
        scene.clearResultNodes(nodes: &nodes)
        let white = UIColor.white.withAlphaComponent(0.9)
        func cross(_ c: SCNVector3) {
            let r: Float = 0.018
            nodes.append(scene.addLine(from: SCNVector3(c.x - r, c.y, c.z),
                                       to: SCNVector3(c.x + r, c.y, c.z), color: white, radius: 0.0022, placement: .table))
            nodes.append(scene.addLine(from: SCNVector3(c.x, c.y, c.z - r),
                                       to: SCNVector3(c.x, c.y, c.z + r), color: white, radius: 0.0022, placement: .table))
        }
        if let a = startPoint { cross(a) }
        if let b = endPoint { cross(b) }
        if let a = startPoint, let b = endPoint {
            nodes.append(scene.addLine(from: a, to: b, color: white, radius: 0.0018, placement: .table))
        }
    }

    /// 均分摆球（条 20.6）：统计球心落在线上（距线段 < 1.2R 且不在端点）的在桌球，
    /// 按沿线投影排序后摆到 i/(n+1) 等分点（端点不放球）。返回 true = 有球被调整。
    func redistribute(keys: [String], scene: AngleTrainingScene) -> Bool {
        guard phase == .placed, let a = startPoint, let b = endPoint else { return false }
        let abx = b.x - a.x, abz = b.z - a.z
        let len2 = abx * abx + abz * abz
        guard len2 > 1e-6 else { return false }
        let r = AngleSceneCalculator.ballRadius

        var onLine: [(key: String, t: Float)] = []
        for key in keys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let px = node.position.x - a.x, pz = node.position.z - a.z
            let t = (px * abx + pz * abz) / len2
            guard t > 0.02, t < 0.98 else { continue }        // 端点不算
            let cx = a.x + abx * t, cz = a.z + abz * t
            let dx = node.position.x - cx, dz = node.position.z - cz
            if sqrtf(dx * dx + dz * dz) < r * 1.2 { onLine.append((key, t)) }
        }
        guard !onLine.isEmpty else { return false }

        onLine.sort { $0.t < $1.t }
        let n = onLine.count
        let y = scene.surfaceY + r
        for (i, item) in onLine.enumerated() {
            let f = Float(i + 1) / Float(n + 1)
            scene.allBallNodes[item.key]?.position =
                SCNVector3(a.x + abx * f, y, a.z + abz * f)
        }
        return true
    }
}

// 注：自由瞄准角度齿轮 `BTAimWheel` 已下沉至 `Core/Components/BTAimWheel.swift`（P18 B2 T-P18-05），
// 本文件直接引用共享版。
#endif
