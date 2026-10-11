import SwiftUI
import SceneKit

enum FreePlayEntryMode {
    case standard
    case dailyClearance
    case shotSimulation
}

/// 自由击球（条 15 / ADR-P18-01 拆页）：球库 + 开球 + 对局的独立页面。
///
/// 与「自由走位」（编排台）的分工：自由走位 = 纯摆球/编排推演（无开球）；
/// 自由击球 = 从开球开始的完整对局体验。开球按钮状态机（条 15.8/15.9）：
/// 开球 → 开球中 → 重开（换 seed 重摆）；停稳后点「完成」才送入击打阶段。
///
/// 布局（问题集合 v3 §S1 基准页）：控件相对**屏幕内实际球桌矩形**贴边定位
/// （`ShotStageProxy`，G3–G11），顶栏/底栏高度固定 ⇒ 球桌尺寸严格锁定不抖动（G10）。
struct FreePlayView: View {
    let entryMode: FreePlayEntryMode
    private let editor: PositionPlayEditorConfiguration?

    @StateObject private var vm: PositionPlayViewModel
    @StateObject private var dailyController = DailyClearanceController()
    @ObservedObject private var preferences = UserPreferences.shared
    @AppStorage("shotSimulation.spinDiscTransparency") private var simulationSpinTransparency = 0.5
    @AppStorage("shotSimulation.3DTrajectoryHidden") private var simulation3DHidden = false
    @AppStorage("composer.spinDiscTransparency") private var editorSpinTransparency = 0.5
    @AppStorage("composer.3DTrajectoryHidden") private var editor3DHidden = false
    @AppStorage("freePlay.spinDiscTransparency") private var standardSpinTransparency = 0.5
    @AppStorage("freePlay.3DTrajectoryHidden") private var standard3DHidden = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale
    @ScaledMetric(relativeTo: .body) private var resultActionHeight: CGFloat = 44
    @State private var hasAppeared = false
    @State private var dailyAimWheelIsDragging = false
    @State private var daily3DDiagnostics: Daily3DRenderDiagnostics?
    @State private var showSpinPad = false
    @State private var dailyPresentation: DailyHUDPresentation?
    @AccessibilityFocusState private var dailyMoreFocused: Bool
    private var showSpinTransparency: Bool {
        get { dailyPresentation == .transparency }
        nonmutating set { dailyPresentation = newValue ? .transparency : nil }
    }
    private var showDailyRerackConfirm: Bool { dailyPresentation == .rerack }
    private var dailyDecisionActive: Bool { dailyPresentation?.isDecision == true }
    @State private var showBreakPicker = false

    #if DEBUG
    @State private var dailyHeaderAuditStep = 0
    @State private var cameraPreviewProfile: CameraRig.DailyPreviewProfile = .classic
    @State private var cameraPreviewScenario = 0
    @State private var cameraPreviewSteady = false
    @State private var cameraPreviewExpanded = true
    private var showsCameraPreview: Bool {
        isDailyClearance && ProcessInfo.processInfo.arguments.contains("-dailyClearance.cameraPreview")
    }
    private var cameraReviewScenario: Int? {
        guard isDailyClearance, let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("-dailyClearance.cameraScenario=")
        }), let index = Int(argument.components(separatedBy: "=").last ?? ""),
              (0..<Self.cameraPreviewScenarioNames.count).contains(index) else { return nil }
        return index
    }
    #endif

    @State private var projector = TableProjector()
    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false
    @State private var sceneFrame: CGRect = .zero
    @State private var paletteFrame: CGRect = .zero

    @State private var dailyCameraReadableFrame: CGRect?
    @State private var dailyPortrait = false
    @State private var dailyCameraControlStackHeight: CGFloat = 188
    @State private var dailyHeaderTitleWidths: [Int: CGFloat] = [:]
    @State private var dailyHeaderTitleHeight: CGFloat = 44
    @State private var dailyWindowControlInsets = UIEdgeInsets.zero
    @State private var dailyWindowSafeAreaInsets = UIEdgeInsets.zero
    @State private var dailySystemStatusVisible = true
    // State owns the model; only DailyStatusCluster observes its once-per-second publications.
    @State private var dailyFPSReadout = TableFPSReadoutState()
    @State private var dailyInstrumentHeight = DailyLayoutMetrics.Controls.initialInstrumentHeight
    @State private var dailyStrikeFrame: CGRect?
    @StateObject private var ruleNotices = BTRuleNoticeCenter()
    @State private var toast: BTToastMessage?
    @State private var showClearTableConfirm = false

    // 规则对局（条 15.10）：开球「完成」后按玩法启用引擎；引擎只做裁决与轮转提示，
    // 台面操作仍全开放（单机一人扮两方，自由球=用户自行拖母球）。
    @State private var rules: (any BilliardRulesEngine)?
    @State private var pendingGame: RackGame?
    @State private var rulingText = ""
    @State private var scoreboardText = ""
    @State private var currentPlayerLabel = ""

    /// G10：顶栏 / 底栏固定高度 ⇒ scene 区域高度恒定 ⇒ 球桌渲染尺寸锁定。
    private static let topRowHeight = ShotStageMetrics.topRowHeight
    private static let bottomBarHeight = ShotStageMetrics.BottomBarHeight.composer.rawValue

    init(entryMode: FreePlayEntryMode = .standard) {
        self.entryMode = entryMode
        self.editor = nil
        self._vm = StateObject(wrappedValue: PositionPlayViewModel())
    }

    init(editorModel: PositionPlayViewModel, editor: PositionPlayEditorConfiguration) {
        self.entryMode = .standard
        self.editor = editor
        self._vm = StateObject(wrappedValue: editorModel)
    }

    private var isDailyClearance: Bool { entryMode == .dailyClearance }
    private var isShotSimulation: Bool { entryMode == .shotSimulation }
    private var isStandard: Bool { entryMode == .standard && editor == nil }
    private var isEditor: Bool { editor != nil }
    private var isManualBreakPage: Bool { isStandard || isEditor }
    private var editablePalette: Bool { isShotSimulation || isEditor }
    private var sequenceReadOnly: Bool { isEditor && vm.isSequenceMode }
    private var usesCoreTemplate: Bool { true }
    private var isDailyResult: Bool {
        isDailyClearance && (dailyController.isCompleted || dailyController.phase == .failed)
    }
    private var is3D: Bool { vm.cameraMode == .perspective3D }
    private var isDaily2D: Bool { usesCoreTemplate && !is3D }
    private var pageTitle: String { if let editor { return editor.title }; return isShotSimulation ? "分离角与走位" : (isDailyClearance ? "每日清台" : "自由击球") }
    private var page3DHidden: Bool {
        get { if isEditor { return editor3DHidden }; return isShotSimulation ? simulation3DHidden : (isStandard ? standard3DHidden : preferences.daily3DTrajectoryHidden) }
        nonmutating set {
            if isEditor { editor3DHidden = newValue }
            else if isShotSimulation { simulation3DHidden = newValue }
            else if isStandard { standard3DHidden = newValue }
            else { preferences.daily3DTrajectoryHidden = newValue }
        }
    }
    private var pageSpinTransparency: Binding<Double> {
        Binding(get: { if isEditor { return editorSpinTransparency }; return isShotSimulation ? simulationSpinTransparency : (isStandard ? standardSpinTransparency : preferences.dailySpinDiscTransparency) },
                set: { value in
            if isEditor { editorSpinTransparency = value }
            else if isShotSimulation { simulationSpinTransparency = value }
            else if isStandard { standardSpinTransparency = value }
            else { preferences.dailySpinDiscTransparency = value }
        })
    }

    private var templateStateDescription: String {
        let selection = "\(is3D ? "3D" : "2D")，\(aimModeLabel)模式，目标\(vm.selectedTargetKey ?? "无")，袋口\(vm.selectedPocketIndex)"
        if isShotSimulation {
            return selection + "，目标球\(vm.onTableKeys.filter { !PositionPlayBall.isCue($0) }.count)/2，在桌\(vm.onTableKeys.joined(separator: ","))"
        }
        if isEditor { return selection + "，\(vm.statusText)，在桌\(vm.onTableKeys.joined(separator: ","))" }
        if isStandard { return selection + "，\(scoreboardText)，\(currentPlayerLabel)，\(rulingText)" }
        return selection + "，\(dailyController.visitSummary)，剩余 \(dailyController.remainingBallCount) 球，\(dailyController.foulCount) 次犯规"
    }

    private var simulationReadout: some View {
        let angle = vm.aimMode == .free ? vm.freeAimContact?.cutAngleDeg : vm.cutAngleDeg
        return VStack(spacing: 2) {
            Text(angle.map { "切角 \(Int($0.rounded()))°" } ?? "切角 —")
            ThicknessOverlapIcon(cutAngle: angle ?? 0)
                .opacity(angle == nil ? 0.3 : 1)
                .accessibilityHidden(true)
            Text(angle.map { AngleSceneCalculator.thicknessName(cutAngle: $0) } ?? "厚薄 —")
        }
        .font(.btCaption2).monospacedDigit().foregroundStyle(HUDStyle.valueMeasured)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("shotSimulation.readout")
        .allowsHitTesting(false)
    }

    private func templateFrameReader(_ id: String) -> some View {
        GeometryReader { geometry in
            Color.clear.preference(key: BTShotPageFramePreference.self,
                value: [id: geometry.frame(in: .named("freeplay"))])
        }
    }

    private func cancelPaletteDrag() {
        draggingKey = nil
        dragOverTable = false
    }

    private func placeSimulationBall(_ key: String, world: SCNVector3?) {
        guard editablePalette, !is3D, !dailyControlsDisabled else { return }
        editor?.onInteraction()
        if let world { vm.placeFromPalette(key, atWorld: world) }
        else { vm.placeFromPalette(key) }
        if !vm.onTableKeys.contains(key) { flash(vm.statusText, tone: .warning) }
    }

    private func simulationPaletteDrag(_ key: String) -> some Gesture {
        DragGesture(minimumDistance: BTBallPaletteMetrics.dragMinimumDistance, coordinateSpace: .named("freeplay"))
            .onChanged { value in
                guard editablePalette, !is3D, !dailyControlsDisabled else { return }
                draggingKey = key
                dragLocation = value.location
                dragOverTable = sceneFrame.contains(value.location)
            }
            .onEnded { value in
                defer { cancelPaletteDrag() }
                guard draggingKey == key, sceneFrame.contains(value.location) else { return }
                let local = CGPoint(x: value.location.x - sceneFrame.minX, y: value.location.y - sceneFrame.minY)
                guard let world = projector.unproject?(local) else { return }
                placeSimulationBall(key, world: world)
            }
    }

    var body: some View {
        Group {
            if isShotSimulation || isEditor { coreBody }
            else { coreBody.toolUsageSession(isDailyClearance ? .dailyClearance : .freePlay) }
        }
    }

    private var coreBody: some View {
        pageBody
        #if DEBUG
        .overlay(alignment: .bottom) {
            if showsCameraPreview { dailyCameraPreviewControls }
            if isDailyClearance, ProcessInfo.processInfo.arguments.contains("-dailyLayout.headerAudit") {
                Button("切换顶栏验证宽度") { dailyHeaderAuditStep += 1 }
                    .font(.system(size: 12)).padding(8).background(.black.opacity(0.8))
                    .accessibilityIdentifier("dailyLayout.toggleHeaderWidth")
            }
        }
        .task {
            guard showsCameraPreview || cameraReviewScenario != nil else { return }
            for _ in 0..<100 {
                if vm.scene.cameraRig != nil, dailyController.phase == .playing { break }
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
            }
            guard !Task.isCancelled, dailyController.phase == .playing else { return }
            if let scenario = cameraReviewScenario {
                cameraPreviewProfile = .current
                loadDailyCameraPreviewScenario(scenario)
            } else { loadDailyCameraPreviewScenario(0) }
        }
        #endif
        .onChange(of: dailyController.phase) { _, phase in
            updateDaily3DPlaybackDiagnostics()
            if phase == .manualRacked || phase == .autoBreaking { ruleNotices.clear() }
        }
        .onChange(of: vm.cameraMode) { _, mode in
            daily3DDiagnostics?.setPage(perspective: mode == .perspective3D)
            cancelPaletteDrag()
        }
        .onChange(of: vm.isPlaying) { _, _ in
            updateDaily3DPlaybackDiagnostics()
        }
    }

    private var dailyAuditAllowsDock: Bool {
        #if DEBUG
        !ProcessInfo.processInfo.arguments.contains("-dailyLayout.forceSide")
        #else
        true
        #endif
    }

    private var dailyHasAuditSize: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-dailyLayout.viewport=") }
        #else
        false
        #endif
    }

    /// Controlled native container evidence only; this is not a system window resize.
    private func dailyAuditSize(_ available: CGSize) -> CGSize {
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-dailyLayout.viewport=") }) {
            let values = argument.split(separator: "=").last?.split(separator: "x").compactMap { Double($0) } ?? []
            if values.count == 2, values.allSatisfy({ $0.isFinite && $0 > 0 }) {
                return CGSize(width: min(available.width, values[0]), height: min(available.height, values[1]))
            }
        }
        #endif
        return available
    }

    private var pageBody: some View {
        GeometryReader { geo in
            if usesCoreTemplate {
                // iPadOS may retain the floating host's SwiftUI insets after maximizing.
                // Account only for the part of the live window safe area not already consumed.
                let extraTop = UIDevice.current.userInterfaceIdiom == .pad && !dailyHasAuditSize
                    ? max(0, dailyWindowSafeAreaInsets.top - geo.safeAreaInsets.top) : 0
                let extraBottom = UIDevice.current.userInterfaceIdiom == .pad && !dailyHasAuditSize
                    ? max(0, dailyWindowSafeAreaInsets.bottom - geo.safeAreaInsets.bottom) : 0
                dailyLandscapeBody(size: dailyAuditSize(CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing, height: max(0, geo.size.height - extraTop - extraBottom))), leadingSafeArea: geo.safeAreaInsets.leading,
                                   trailingSafeArea: dailyHasAuditSize ? 0 : geo.safeAreaInsets.trailing)
                    .frame(width: geo.size.width + geo.safeAreaInsets.trailing, alignment: .leading)
                    .padding(.top, extraTop)
                    .padding(.bottom, extraBottom)
                    .offset(x: -geo.safeAreaInsets.leading)
                    .ignoresSafeArea(.container, edges: .trailing)
            } else {
            let extents = vm.tableOuterHalfExtents
            let bottomHeight = isDailyResult && dynamicTypeSize.isAccessibilitySize
                ? max(Self.bottomBarHeight, resultActionHeight + 64)
                : (is3D && !vm.isBreakMode && !isDailyResult ? Self.topRowHeight : Self.bottomBarHeight)
            let sceneH = max(geo.size.height - Self.topRowHeight - bottomHeight, 1)
            let proxy = ShotStageProxy(
                sceneSize: CGSize(width: geo.size.width, height: sceneH),
                halfLength: extents.length, halfWidth: extents.width
            )
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    topInfoRow
                        .frame(height: Self.topRowHeight)
                    stage(proxy)
                        .frame(height: sceneH)
                    bottomBar(proxy)
                        .frame(height: bottomHeight)
                }
            }
            .coordinateSpace(name: "freeplay")
            .btToast($toast)
            }
        }
        .background {
            if usesCoreTemplate { DailyTableOrientation(landscape: true, allowsTabletRotation: true) }
        }

        .animation(BTMotion.springPanel, value: showSpinPad)
        .trainingBackgroundMusic()
        .btDarkToolChrome(pageTitle)
        .toolbar(usesCoreTemplate ? .hidden : .visible, for: .navigationBar)
        // Keep the tablet's system chrome reservation, including window controls
        // in landscape. Hiding it puts the custom back button under that chrome.
        .statusBarHidden(usesCoreTemplate && UIDevice.current.userInterfaceIdiom != .pad)
        .toolbar {
            ToolbarItem(placement: .principal) {
                BTSolverNavStatus(
                    title: pageTitle,
                    isBusy: vm.isComputing,
                    statusText: navigationStatusText
                )
            }
            ToolbarItem(placement: .topBarTrailing) {
                cameraToggle
            }
            ToolbarItem(placement: .topBarTrailing) {
                moreMenu
            }
        }
        .confirmationDialog("清空桌面上所有球？",
                            isPresented: $showClearTableConfirm, titleVisibility: .visible) {
            Button("取消", role: .cancel) {}
            Button("清空桌面", role: .destructive) {
                endGame()
                vm.clearTable()
            }
        }
        .sheet(isPresented: $showBreakPicker) {
            BreakGamePickerSheet { game in
                pendingGame = isStandard ? game : nil
                rules = nil
                vm.startBreakFlow(game: game, manualDeliver: true)
            }
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: vm.isBreakMode) { _, inBreak in
            updateDaily3DPlaybackDiagnostics()
            if is3D, inBreak, !isDailyClearance { ShotPlayCamera.focus(on: vm) }
            // 开球「完成」交付击打阶段 → 按玩法启动规则对局（取消开球时 pendingGame 已清）。
            if !isDailyClearance, !inBreak, let game = pendingGame {
                pendingGame = nil
                startGame(game)
            }
        }
        .onChange(of: vm.breakRunner?.seed) { previous, seed in
            // A new rack resets the 3D framing; delivery removes the runner without moving the camera.
            if is3D, seed != nil {
                if isDailyClearance || previous != nil { observeWholeTableForPage() }
                else { ShotPlayCamera.focus(on: vm) }
            }
        }
        .onChange(of: vm.breakRunner?.phase) { previous, phase in
            updateDaily3DPlaybackDiagnostics()
            // A single framing request at the shot boundary; subsequent playback,
            // settle and user gestures retain ownership of the current camera.
            if is3D, !isDailyClearance, previous == .racked,
               phase == .computing || phase == .breaking {
                observeWholeTableForPage()
            }
        }
        .onAppear {
            if isDailyClearance, Daily3DRenderDiagnostics.isEnabled, daily3DDiagnostics == nil {
                daily3DDiagnostics = Daily3DRenderDiagnostics()
            }
            if !hasAppeared {
                hasAppeared = true
                if isDailyClearance { vm.scene.configureDailyClearanceRendering() }
                if !isDailyClearance {
                    if isShotSimulation { vm.maxTargetBalls = 2 }
                    vm.scene.configureReferenceTableRendering()
                    vm.scene.configureShotAwareCamera()
                }
                vm.setupScene(loadsDefaultLayout: isStandard || isEditor)
                vm.enablePlayerCameraControls()
                #if DEBUG
                if isDailyClearance,
                   let argument = ProcessInfo.processInfo.arguments.first(where: {
                       $0.hasPrefix("-dailyClearance.overviewAngle=")
                   }),
                   let degrees = Float(argument.split(separator: "=").last ?? ""),
                   [Float(45), 40, 35, 30].contains(degrees) {
                    vm.scene.cameraRig?.dailyOverviewPreviewDegrees = degrees
                }
                #endif
                if usesCoreTemplate {
                    vm.hides3DShotAssists = page3DHidden
                    vm.cameraMode = .topDown2D
                    vm.usesAutomaticPocketFallback = true
                    vm.usesDailyShotRanking = isDailyClearance
                    vm.usesContinuousTrajectoryPreview = true
                    if isDailyClearance {
                        vm.legalAimTargets = { keys in dailyController.legalTargetKeys(tableKeys: keys) }
                    } else if isStandard {
                        vm.legalAimTargets = { keys in rules?.legalTargetKeys(tableKeys: keys) ?? keys }
                    }
                    vm.onAimModeNotice = { text in ruleNotices.show(text, tone: .info, priority: .mode) }
                    vm.onAimSelectionNotice = { text in ruleNotices.show(text, tone: .warning, priority: .selection) }
                } else {
                    vm.usesAutomaticPocketFallback = true
                    vm.legalAimTargets = { keys in rules?.legalTargetKeys(tableKeys: keys) ?? keys }
                    vm.onAimModeNotice = { ruleNotices.show($0, tone: .info, priority: .mode) }
                    vm.onAimSelectionNotice = { ruleNotices.show($0, tone: .warning, priority: .selection) }
                }
                if isShotSimulation { vm.loadBoard(ShotSimulationView.defaultBoard) }
                editor?.setup()
                vm.scene.setCameraMode(vm.cameraMode, animated: false)
                vm.onShotSettled = { facts in handleShotSettled(facts) }
                if isDailyClearance { vm.onShotWillStart = { dailyController.prepareShot() } }
                #if DEBUG
                if !isDailyClearance, ProcessInfo.processInfo.arguments.contains("-v63.freePlayScratch") {
                    vm.clearTable()
                    if isShotSimulation { vm.setPreferredAimMode(.free) }
                    else { vm.toggleAimMode() }
                    vm.placeFromPalette(PositionPlayBall.cueKey,
                        atWorld: SCNVector3(0, vm.scene.surfaceY + BallPhysics.radius, -0.45))
                    vm.velocity = 1.5
                    vm.handleTableTap(world: AngleSceneCalculator.pocketPositions(surfaceY: vm.scene.surfaceY)[4])
                    if isShotSimulation {
                        // Occupy the first free slots to exercise scratch return without overlap.
                        vm.placeFromPalette("_1")
                        vm.placeFromPalette("_8")
                    } else { startGame(.chineseEightBall) }
                }
                #endif
                if isDailyClearance {
                    dailyController.start(host: vm, defaultGame: preferences.dailyClearanceGame)
                    vm.refreshLegalAimSelection()
                    // Completion records contain totals, not a resumable board.
                    // Do not present the scene's initialization example as that game.
                    if dailyController.isCompleted { vm.clearTable() }
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-dailyClearance.fixture=scratch") {
                        vm.aimMode = .free
                        vm.handleTableTap(world: AngleSceneCalculator.pocketPositions(surfaceY: vm.scene.surfaceY)[4])
                    }
                    #endif
                }
            }
            daily3DDiagnostics?.setPage(visible: true, foreground: scenePhase == .active, perspective: is3D)
            updateDaily3DPlaybackDiagnostics()
        }
        .onReceive(ruleNotices.$message) { toast = $0 }
        .onDisappear {
            if sequenceReadOnly { vm.exitSequenceMode() }
            daily3DDiagnostics?.setPage(visible: false)
            vm.endTemporaryTopDown()
            vm.cancelPowerRelease()
            dailyAimWheelIsDragging = false
            cancelPaletteDrag()
            if usesCoreTemplate { vm.cancelInteractiveTrajectoryPreview() }
            if isDailyClearance {
                dailyController.stop()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            daily3DDiagnostics?.setPage(foreground: phase == .active)
            guard usesCoreTemplate else { return }
            if phase == .active {
                if isDailyClearance { dailyController.resumeActivity() }
                if !vm.isPlaying && !vm.isBreakMode { vm.recompute() }
            }
            else {
                vm.endTemporaryTopDown()
                vm.cancelPowerRelease()
                dailyAimWheelIsDragging = false
                vm.cancelInteractiveTrajectoryPreview()
                cancelPaletteDrag()
                if isDailyClearance { dailyController.flushActivity() }
            }
        }
        .onPreferenceChange(BTShotPageFramePreference.self) { frames in
            if let frame = frames["scene"] { sceneFrame = frame }
            if let frame = frames["palette"] { paletteFrame = frame }
        }
    }

    private func updateDaily3DPlaybackDiagnostics() {
        daily3DDiagnostics?.setPlayback(breaking: vm.breakRunner?.phase == .breaking,
                                       shooting: vm.isPlaying)
    }

    // MARK: - Stage（scene + 贴边控件，G3–G11）

    private func stage(_ proxy: ShotStageProxy) -> some View {
        ZStack(alignment: .topLeading) {
            sceneContainer()

            // G18/V6：开球模式贴边仪表（左瞄准轮 + 右力度柱，默认 6 m/s），共享单一真源。
            if let runner = vm.breakRunner {
                BreakInstrumentsOverlay(runner: runner, proxy: proxy, scene: vm.scene, projector: projector, isPerspective: is3D)
                if is3D {
                    HStack(spacing: Spacing.sm) {
                        ShotObservationMenu(vm: vm, identifierPrefix: "freeplay")
                        cameraFocus
                    }
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }

            if !vm.isBreakMode && !isDailyResult && proxy.isValid {
                // G3 轨迹档位 chip：下沿贴球桌上沿、靠屏幕最右（放球桌上方空隙带内）。
                // C12（v7 W6）：贴边定位统一走共享修饰器，与 ShotSimulationView 同源。
                if !isDailyClearance {
                    if is3D {
                        BTTrajectoryDetailChip { vm.recompute() }
                            .padding(Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .topTrailing)
                            .allowsHitTesting(!vm.isPlaying)
                    } else {
                        BTTrajectoryDetailChip { vm.recompute() }
                            .btChipBandPlacement(proxy)
                            .allowsHitTesting(!vm.isPlaying)
                    }
                }

                // G4/G5/G7 瞄准刻度轮（自由模式）：右缘贴球桌左侧、底部对齐。
                if vm.aimMode == .free {
                    BTAimWheel(
                        onNudge: { vm.nudgeFreeAim(byDegrees: $0) },
                        degreesPerPoint: vm.aimWheelDegreesPerPoint,
                        degreeHapticEnabled: false,
                        onDragActiveChanged: { active in
                            if isDailyClearance { dailyAimWheelIsDragging = active }
                            vm.setAimWheelDragging(active)
                        }
                    )
                        .btStageFrame(is3D ? ShotPerspectiveLayout(sceneSize: proxy.sceneSize).aimWheelFrame : proxy.aimWheelFrame())
                        .allowsHitTesting(!vm.isPlaying)
                        .disabled(vm.isPlaying)
                }

                // 左下：翻袋备选「下一解」（仅直击失败且多解时）+ 开球。
                VStack(spacing: 8) {
                    if vm.canCycleBankAlternatives {
                        BTTextActionButton(
                            title: "下一解",
                            isDisabled: false,
                            width: ShotStageMetrics.actionColumnWidth,
                            action: { vm.nextBankAlternative() }
                        )
                        .accessibilityIdentifier("freeplay.nextBankAlternative")
                    }
                    BTBreakSideButton(isEnabled: !vm.isPlaying) {
                        editor?.onInteraction()
                    if editor?.isTryout == true { showSpinPad = false; editor?.onRearrange() }
                    else if isDailyClearance { requestDailyRerack() }
                        else { showBreakPicker = true }
                    }
                }
                .btStageFrame(
                    breakEntryFrame(proxy)
                )

                // G4/G5/G7 打点+力度仪表柱：左缘贴球桌右侧、力度条本体底部对齐。
                BTShotInstrumentColumn(
                    spinX: vm.spinX, spinY: vm.spinY,
                    onSpinTap: { showSpinPad = true },
                    velocity: $vm.velocity,
                    range: ShotTuning.velocityRange,
                    isDisabled: vm.isPlaying
                )
                .btStageFrame(is3D ? ShotPerspectiveLayout(sceneSize: proxy.sceneSize).instrumentFrame : proxy.instrumentFrame())

                if is3D, !showSpinPad, let rig = vm.scene.cameraRig {
                    ShotPlayerCameraButtons(rig: rig,
                        isEnabled: !vm.isPlaying && !vm.isComputing && vm.currentPlayerAim != nil) { view in
                        showSpinPad = false
                        vm.requestPlayerView(view)
                    }
                    .btStageFrame(ShotPerspectiveLayout(sceneSize: proxy.sceneSize).instrumentFrame)
                    .offset(x: -52)
                }

                // 18.2 击球/上一杆/回放：右下角，底边齐球桌底线。
                BTShotActionColumn(
                    strikeTitle: vm.isPlaying ? BTStrikeTitle.freePlayBusy : BTStrikeTitle.freePlay,
                    strikeEnabled: strikeEnabled,
                    onStrike: { vm.play() },
                    undoTitle: "重打",
                    undoEnabled: !vm.isPlaying && vm.canReplay,
                    onUndo: { vm.replayCurrent() },
                    playbackEnabled: !vm.isPlaying && vm.canPlayback,
                    onPlayback: { vm.replayLastShot() }
                )
                .btStageFrame(is3D ? ShotPerspectiveLayout(sceneSize: proxy.sceneSize).actionFrame : proxy.actionColumnFrame())
            }

            // v23 W3：近区瞄准特写（自由模式；三点菜单可关）。
            if !vm.isBreakMode {
                BTAimCloseupOverlay(snapshot: vm.closeupSnapshot, sceneSize: proxy.sceneSize,
                                    scene: vm.scene, safeInsets: is3D
                                        ? .init(top: 56, leading: 56, bottom: 46, trailing: 62)
                                        : proxy.aimCloseupSafeInsets)
            }

            if showSpinPad {
                BTProjectedSpinPadOverlay(spinX: $vm.spinX, spinY: $vm.spinY,
                                 scene: vm.scene, projector: projector,
                                 onClose: { showSpinPad = false })
                    // F-PP-07：与同系页对齐贴底；不动 ShotStageProxy。
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        // G10：stage 区域高度恒定（顶/底栏固定）⇒ 球桌尺寸锁定。
        // 标识放在铺满 stage 的 background 元素上：frame 稳定（不随子控件增减联动），
        // 且不改变子控件（break.entry 等）的可及性树。
        .background(
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("freeplay.stage")
        )
    }

    // MARK: - Rules session (条 15.10)

    private func startGame(_ game: RackGame) {
        switch game {
        case .chineseEightBall:
            rules = ChineseEightBallRules()
        case .nineBall, .zhuifen:
            rules = ZhuifenRules()
        }
        refreshRulesHUD(message: "对局开始：玩家 A 先击球")
    }

    private func handleShotSettled(_ facts: ShotFacts) {
        if sequenceReadOnly { return }
        if isShotSimulation {
            if facts.cuePocketed { vm.placeFromPalette(PositionPlayBall.cueKey) }
            return
        }
        if isDailyClearance {
            guard let ruling = dailyController.handleShotSettled(facts) else { return }
            if ruling.completed || ruling.failed { ruleNotices.clear() }
            else if ruling.message != "继续击球" {
                ruleNotices.show(ruling.message, tone: ruling.foul ? .warning : .info, priority: .ruling)
            }
            return
        }
        // Judge the recorded scratch before restoring the cue for the next shot.
        defer { if facts.cuePocketed { vm.placeFromPalette(PositionPlayBall.cueKey) } }
        guard let rules else { return }
        let ruling = rules.judge(facts)
        refreshRulesHUD(message: ruling.message)
        if ruling.ballInHand, !ruling.gameOver {
            ruleNotices.show(ruling.message + "；自由球：可任意拖放母球", tone: .warning, priority: .ruling)
        }
    }

    private func refreshRulesHUD(message: String) {
        guard let rules else { return }
        rulingText = message
        scoreboardText = rules.scoreboardText
        currentPlayerLabel = rules.isGameOver ? "" : rules.playerLabel(rules.currentPlayer)
    }

    private func endGame() {
        rules = nil
        rulingText = ""
        scoreboardText = ""
        currentPlayerLabel = ""
    }

    // MARK: - Scene container

    private func sceneContainer(fpsTrailingInset: CGFloat? = nil) -> some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            interactionMode: is3D ? .cameraControl : .tapsOnly,
            autoFitsRotatedTable: !is3D && !isDaily2D,
            autoFitsLandscapeTable: isDaily2D,
            backgroundColor: isDaily2D ? .clear : .black,
            onPocketTapped: sequenceReadOnly || vm.isBreakMode || vm.isPlaying || isDailyResult || (isTemporaryTopDown && !usesMergedCamera) ? nil : { vm.selectPocket(at: $0) },
            // P10.1 禁止摆球：非开球模式仅母球可拖（自由球/走位微调）；开球模式拖开球区母球。
            draggableBallNodes: sequenceReadOnly || vm.isPlaying || isDailyResult || (isTemporaryTopDown && !usesMergedCamera)
                || (isDailyClearance && !vm.isBreakMode && dailyController.cuePlacement == .none)
                ? [] : (vm.breakRunner?.draggableCue ?? (editablePalette ? vm.draggableBalls : vm.draggableCueOnly)),
            onDragBegan: { node in
                editor?.onInteraction()
                if let runner = vm.breakRunner { runner.dragBegan(node: node) }
                else if isDailyClearance && dailyController.cuePlacement == .none {
                    flash("当前不是自由球，母球不能移动", tone: .warning)
                } else { vm.dragBegan(node: node) }
            },
            onDragMoved: { node, world in
                if let runner = vm.breakRunner {
                    runner.dragMoved(node: node, worldPosition: world)
                } else {
                    if isDailyClearance && dailyController.cuePlacement == .none { return }
                    var constrained = world
                    if isDailyClearance, dailyController.cuePlacement == .behindHeadString {
                        if constrained.x <= AngleSceneCalculator.innerLength / 4 {
                            flash("开球犯规后，请在线后摆放母球", tone: .warning)
                        }
                        constrained.x = max(constrained.x, AngleSceneCalculator.innerLength / 4 + 0.001)
                    }
                    if isDailyClearance {
                        if !vm.moveDailyCue(node: node, world: constrained, placement: dailyController.cuePlacement) {
                            flash("此处不能放球，请移到台内空位", tone: .warning)
                        }
                    } else { vm.dragMoved(node: node, worldPosition: constrained) }
                }
            },
            onDragEnded: { node in
                if let runner = vm.breakRunner { runner.dragEnded(node: node) }
                else if !isDailyClearance || dailyController.cuePlacement != .none {
                    vm.dragEnded(node: node)
                    if isDailyClearance { dailyController.savePlacedBoard() }
                }
            },
            onDragEndedAt: { node, point in
                guard editablePalette, !is3D,
                      BTBallPaletteDragBack.hitPalette(localPoint: point, sceneFrame: sceneFrame, paletteFrame: paletteFrame),
                      let key = vm.scene.ballKey(for: node), !PositionPlayBall.isCue(key) else { return }
                vm.removeFromTable(key)
                flash("已移回球库")
            },
            selectableBallNodes: sequenceReadOnly || vm.isBreakMode || vm.isPlaying || isDailyResult || (isTemporaryTopDown && !usesMergedCamera) ? [] :
                (isDailyClearance && is3D ? vm.selectableBalls + vm.draggableCueOnly : vm.selectableBalls),
            onBallTapped: { node in handleTargetTap(node) },
            onTableTapped: is3D || isDailyResult ? nil : {
                editor?.onInteraction()
                if !vm.isBreakMode && !sequenceReadOnly { vm.handleTableTap(world: $0) }
            },
            onAimNudged: is3D || isDailyResult || sequenceReadOnly ? nil : {
                editor?.onInteraction()
                if let runner = vm.breakRunner { runner.nudgeAim(byDegrees: $0) }
                else { vm.nudgeFreeAim(byDegrees: $0) }
            },
            onAimDragActiveChanged: { vm.setAimTableDragging($0) },
            projector: projector,
            contentIsAnimating: vm.isPlaying || (vm.breakRunner?.isBusy ?? false)
                || (usesCoreTemplate && dailyAimWheelIsDragging)
                || (usesDailyTwoViewControls && vm.cameraTransitionBusy),
            daily3DDiagnostics: daily3DDiagnostics,
            fpsReadoutTrailingInset: fpsTrailingInset,
            fpsReadoutState: usesCoreTemplate ? dailyFPSReadout : nil,
            twoViewReadableFrameInWindow: usesCoreTemplate ? dailyCameraReadableFrame : nil,
            onCameraObservationBegan: usesDailyTwoViewControls ? { vm.beginCameraObservation() } : nil,
            onCameraObservationEnded: usesDailyTwoViewControls ? { vm.endCameraObservation() } : nil,
            twoViewAutomaticEntryCount: dailyTwoViewAutomaticEntryCount,
            twoViewSolverDiagnostics: dailyTwoViewSolverDiagnostics,
            onThirdPersonAimNudged: usesDailyTwoViewControls && !sequenceReadOnly ? { vm.nudgeThirdPersonAim(byDegrees: $0) } : nil,
            onTemporaryTopDownDismiss: { vm.endTemporaryTopDown() },
            topDownContentRevision: vm.topDownContentRevision,
            usesStandardTemporaryTable: isStandard || isEditor
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(templateFrameReader("scene"))
        .clipped()
        .allowsHitTesting((!isTemporaryTopDown || usesMergedCamera) && (!isDailyClearance || (!dailyDecisionActive && dailyController.breakChoices.isEmpty)))
    }

    /// P10.2：按当前玩法规则拦截不合法目标球选择，并给出提示。
    private func handleTargetTap(_ node: SCNNode) {
        guard !sequenceReadOnly, !vm.isBreakMode, !vm.isPlaying, !isDailyResult, (!isTemporaryTopDown || usesMergedCamera),
              let key = vm.scene.ballKey(for: node) else { return }
        editor?.onInteraction()
        if PositionPlayBall.isCue(key) {
            if isDailyClearance, is3D, !isTemporaryTopDown { vm.requestPlayerView(usesMergedCamera ? .thirdPerson : .firstPerson) }
            return
        }
        let tableTargets = Set(vm.onTableKeys.filter { !PositionPlayBall.isCue($0) })
        if isDailyClearance {
            if let message = dailyController.selectionMessage(for: key, tableKeys: tableTargets) {
                flash(message, tone: .warning)
                return
            }
        } else if let rules, !rules.legalTargetKeys(tableKeys: tableTargets).contains(key) {
            flash("按当前规则不能打 \(PositionPlayBall.shortLabel(for: key)) 号球", tone: .warning)
            return
        }
        if vm.selectTarget(key: key) { ruleNotices.clearSelectionNotice() }
    }

    // MARK: - Top info row

    private var topInfoRow: some View {
        HStack(spacing: Spacing.sm) {
            if vm.isBreakMode {
                isDailyClearance ? AnyView(dailyBreakModePill) : AnyView(breakModePill)
            } else {
                if !isDailyClearance {
                    BTAimModeToggleButton(isFree: vm.aimMode == .free,
                                      isDisabled: vm.isPlaying || isDailyResult) {
                        vm.toggleAimMode()
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                if isDailyClearance {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        dailyStatusPill
                    }
                } else {
                    if vm.cuePocketed { scratchPill }
                    else { aimCapsule }
                    if rules != nil { gamePill }
                }

                if isDailyClearance, vm.cuePocketed { scratchPill }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxHeight: .infinity)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }

    private var aimCapsule: some View {
        HStack(spacing: 4) {
            if vm.aimMode == .free {
                if let contact = vm.freeAimContact {
                    ThicknessOverlapIcon(cutAngle: contact.cutAngleDeg,
                                         size: CGSize(width: 22, height: 12))
                    BTReadout(value: "\(Int(contact.cutAngleDeg.rounded()))°", size: .compact)
                    let name = AngleSceneCalculator.thicknessName(cutAngle: contact.cutAngleDeg)
                    if name != "—" {
                        BTHudMetricSeparator()
                        Text(name)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    BTHudMetricSeparator()
                    Text("碰 \(PositionPlayBall.shortLabel(for: contact.targetKey))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                } else {
                    Image(systemName: "scope")
                        .font(.btCaption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    Text("自由球")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                }
            } else {
                BTReadout(value: vm.cutAngleDeg.map { "\(Int($0.rounded()))°" } ?? "—°",
                          size: .compact)
                if let angle = vm.cutAngleDeg {
                    BTHudMetricSeparator()
                    Text(AngleSceneCalculator.thicknessName(cutAngle: angle))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .btHudGlass()
    }

    private var breakModePill: some View {
        HStack(spacing: 4) {
            BreakRackGlyph(color: HUDStyle.accent, size: 13)
            Text("开球 · \(vm.breakRunner.map { BreakFlowRunner.title(for: $0.game) } ?? "")")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .btHudGlass()
    }

    private var dailyBreakModePill: some View {
        HStack(spacing: 6) {
            BreakRackGlyph(color: HUDStyle.accent, size: 13)
            Text(dailyController.game?.displayName ?? preferences.dailyClearanceGame.displayName)
            BTHudMetricSeparator()
            if dailyController.isAutomaticallyBreaking {
                ProgressView().controlSize(.mini).tint(HUDStyle.accent)
                Text("正在开球")
            } else {
                Text("待手动开球")
            }
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .btHudGlass()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dailyClearance.breakStatus")
    }

    private var dailyStatusPill: some View {
        HStack(spacing: 4) {
            Text(dailyController.game?.displayName ?? "清台")
                .foregroundStyle(HUDStyle.accent)
            BTHudMetricSeparator()
            Text(dailyController.assignedGroup?.displayName ?? (dailyController.game == .chineseEightBall ? "开放局" : "第\(dailyController.visitCount)次上手"))
            BTHudMetricSeparator()
            Text(vm.aimSelectionLabel)
            BTHudMetricSeparator()
            Text("余 \(dailyController.remainingBallCount)")
            BTHudMetricSeparator()
            Text("\(dailyController.visitSummary)")
            BTHudMetricSeparator()
            Text("\(dailyController.foulCount) 犯")
            BTHudMetricSeparator()
            Text(formatDuration(dailyController.elapsedSeconds))
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.92))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 7)
        .btHudGlass()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("每日清台，\(dailyController.game?.displayName ?? "清台")，\(aimModeLabel)模式，剩余 \(dailyController.remainingBallCount) 球，\(dailyController.visitSummary)，\(dailyController.foulCount) 次犯规，用时 \(formatDuration(dailyController.elapsedSeconds))")
        .accessibilityIdentifier("dailyClearance.hud")
    }

    /// 规则对局 HUD（条 15.10）：记分牌 + 当前击球方。
    private var gamePill: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                gameScoreLabel
                if !currentPlayerLabel.isEmpty {
                    BTHudMetricSeparator()
                    gamePlayerLabel
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 2) {
                gameScoreLabel
                if !currentPlayerLabel.isEmpty { gamePlayerLabel }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .btHudGlass()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("freeplay.gameStatus")
    }

    private var gameScoreLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(HUDStyle.accent)
            Text(scoreboardText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
        }
    }

    private var gamePlayerLabel: some View {
        Text(currentPlayerLabel)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(HUDStyle.accent)
            .lineLimit(1)
            .accessibilityLabel("轮到 \(currentPlayerLabel)")
    }

    private var scratchPill: some View {
        HStack(spacing: 4) {
            Circle().fill(Color.btDestructive).frame(width: 6, height: 6)
            Text("预计母球进袋")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.btDestructive)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .background(Color.btDestructive.opacity(0.16), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Bottom bar

    private var cameraToggle: some View {
        Button(is3D ? "3D" : "2D") {
            vm.cancelPowerRelease()
            showSpinPad = false
            if isDailyClearance { toggleDailyCamera() }
            else { ShotPlayCamera.setMode(is3D ? .topDown2DRotated : .perspective3D, on: vm) }
        }
        .font(.btSubheadlineSemibold)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(is3D ? "切换到2D俯视" : "切换到3D视角")
        .accessibilityValue(is3D ? "3D" : "2D")
        .accessibilityIdentifier("freeplay.cameraMode")
    }

    private var cameraFocus: some View {
        Button(vm.isBreakMode ? "开球视角" : "回到瞄准") { ShotPlayCamera.focus(on: vm) }
            .font(.btFootnote)
            .foregroundStyle(HUDStyle.accent)
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: 44)
            .disabled(!ShotPlayCamera.canFocus(on: vm))
            .accessibilityIdentifier("freeplay.focus")
    }

    private func breakEntryFrame(_ proxy: ShotStageProxy) -> CGRect {
        let size = vm.canCycleBankAlternatives
            ? CGSize(width: 48, height: 30 + 8 + ShotStageMetrics.breakButtonSize.height)
            : ShotStageMetrics.breakButtonSize
        return is3D ? ShotPerspectiveLayout(sceneSize: proxy.sceneSize).bottomLeadingFrame(size: size)
            : proxy.bottomLeadingFrame(size: size)
    }

    private func bottomBar(_ proxy: ShotStageProxy) -> some View {
        Group {
            if let runner = vm.breakRunner {
                if isDailyClearance, dailyController.isAutomaticallyBreaking {
                    dailyAutomaticBreakBar
                } else {
                    BreakControlBar(runner: runner, showsCancel: !isDailyClearance,
                                    onRerack: isDailyClearance ? { dailyController.confirmRerack() } : nil, onCancel: {
                        pendingGame = nil
                        vm.cancelBreakFlow()
                    })
                }
            } else if isDailyClearance, dailyController.isCompleted {
                dailyCompletionBar
            } else if isDailyClearance, dailyController.phase == .failed {
                dailyFailureBar
            } else if is3D {
                HStack(spacing: Spacing.sm) {
                    ShotObservationMenu(vm: vm, identifierPrefix: "freeplay")
                    Text(vm.onTableKeys.contains(PositionPlayBall.cueKey) ? "拖动母球摆位" : "切回2D补回母球")
                        .font(.btCaption)
                        .foregroundStyle(Color.btTextSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    cameraFocus
                }
                .padding(.horizontal, Spacing.lg)
            } else {
                paletteBar(proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HUDStyle.panelBackground)
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .environment(\.colorScheme, .dark)
    }

    private var dailyAutomaticBreakBar: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView().tint(HUDStyle.accent)
            Text("正在自动开球，停稳后直接开始")
                .font(.btCallout)
                .foregroundStyle(.white.opacity(0.88))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dailyClearance.autoBreaking")
    }

    private var dailyCompletionBar: some View {
        VStack(spacing: Spacing.xs) {
            BTNoticeContent(message: .init(dailyResultSummary, tone: .success), compact: true, textOnly: true)
            Button("再来一局") { dailyController.replay() }
                .buttonStyle(BTSceneDecisionActionStyle(isPrimary: true))
                .accessibilityIdentifier("dailyClearance.replay")
        }
    }

    private var dailyResultSummary: String {
        let kind = dailyController.completion?.completionKind
        let title = kind == .systemBreakRun
            ? "\(dailyController.game?.displayName ?? "")清台（系统开球）"
            : (kind?.displayName ?? "今日已清台")
        let foul = dailyController.foulCount > 0 ? " · 犯规\(dailyController.foulCount)次" : ""
        return "\(title) · \(dailyController.visitSummary)\(foul) · \(formatDuration(dailyController.elapsedSeconds))"
    }

    private var dailyFailureBar: some View {
        VStack(spacing: Spacing.xs) {
            BTNoticeContent(message: .init(dailyController.statusText, tone: .warning), compact: true, textOnly: true)
            Button("重新开球") { requestDailyRerack() }
                .buttonStyle(BTSceneDecisionActionStyle(isPrimary: true))
                .accessibilityIdentifier("dailyClearance.rerack")
        }
    }

    private var strikeEnabled: Bool {
        !isTemporaryTopDown && !dailyDecisionActive && !isDailyResult && (!isDailyClearance || dailyController.breakChoices.isEmpty) && !vm.isPlaying && !vm.isComputing && !vm.cameraTransitionBusy && vm.isFeasible
    }

    private var dailyResultLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Spacing.md))
    }

    // MARK: - Palette bar（G8 + G21：BTReferenceBallPalette；P10.1 只读参考）

    private func paletteBar(_ proxy: ShotStageProxy) -> some View {
        let libraryWidth = proxy.libraryWidth
        return BTReferenceBallPalette(
            ballDiameter: proxy.paletteBallDiameter,
            libraryWidth: libraryWidth,
            isOnTable: { vm.onTableKeys.contains($0) },
            onTap: { key, onTable in
                if onTable { vm.pulseTableBall(key) }
                else if !isDailyClearance, key == PositionPlayBall.cueKey {
                    vm.placeFromPalette(key)
                }
                else { flash("本页从开球开始，不支持手动摆球") }
            }
        )
    }

    // MARK: - Toolbar menu

    private var aimModeLabel: String { if sequenceReadOnly { return "序列" }; return vm.aimMode == .pocket ? "进袋" : "自由" }

    private func trajectoryMenuLabel(_ detail: TrajectoryDetail) -> String {
        switch detail {
        case .full: return "全部"
        case .core: return "双线"
        case .minimal: return "瞄准线"
        }
    }

    private var dailyTrajectorySelection: Int {
        is3D && page3DHidden ? 3 : preferences.trajectoryDetail.rawValue
    }

    private var dailyTrajectoryLabel: String {
        dailyTrajectorySelection == 3 ? "关闭" : trajectoryMenuLabel(preferences.trajectoryDetail)
    }

    @ViewBuilder private var moreMenu: some View {
        if usesCoreTemplate {
            Button { presentDaily(.more) } label: {
                Image(systemName: BTIcon.menuCircle)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
                    .background { BTHUDControlBackground(shape: Circle(), normal: HUDStyle.controlBackground) }
            }
            .buttonStyle(.plain).foregroundStyle(.white)
            .disabled(vm.isPlaying || dailyDecisionActive || !dailyController.breakChoices.isEmpty)
            .accessibilityLabel("更多").accessibilityIdentifier("freeplay.moreMenu")
            .accessibilityFocused($dailyMoreFocused)
        } else {
            BTSolverMoreMenu(scene: vm.scene, labelOpacity: 0.9, accessibilityId: "freeplay.moreMenu",
                showsAimCloseupToggle: true, pageExtras: {
                    Section {
                        if rules != nil {
                            Button("结束对局", systemImage: "flag.checkered") { endGame(); flash("对局已结束") }
                        }
                        Button("清空桌面", systemImage: "trash") { showClearTableConfirm = true }
                    }
                })
        }
    }

    private func presentDaily(_ presentation: DailyHUDPresentation) {
        vm.cancelPowerRelease()
        showSpinPad = presentation == .transparency
        dailyPresentation = presentation
    }

    private func closeDailyPresentation() {
        dailyPresentation = nil
        dailyMoreFocused = true
    }

    private var dailyMenuTitle: String? {
        switch dailyPresentation {
        case .aim: return "瞄准模式"
        case .trajectory: return "轨迹显示"
        case .games: return "本局玩法"
        default: return nil
        }
    }

    private var dailyMenuItems: [DailyHUDMenuItem] {
        let disabled = vm.isPlaying || vm.isBreakMode || isDailyResult
        switch dailyPresentation {
        case .aim:
            if let items = editor?.aimItems { return closingEditorMenuItems(items) }
            return [("进袋", PositionPlayViewModel.AimMode.pocket), ("自由", .free)].map { title, mode in
                DailyHUDMenuItem(id: "dailyClearance.aim.\(mode == .free ? "free" : "pocket")", title: title,
                    selected: vm.aimMode == mode, disabled: disabled, action: {
                        if editablePalette { vm.setPreferredAimMode(mode) }
                        else if mode != vm.aimMode { vm.toggleAimMode() }
                        closeDailyPresentation()
                    })
            }
        case .trajectory:
            let values = (is3D ? [3] : []) + [TrajectoryDetail.minimal.rawValue, TrajectoryDetail.core.rawValue, TrajectoryDetail.full.rawValue]
            return values.map { value in
                DailyHUDMenuItem(id: "dailyClearance.trajectory.\(value)",
                    title: value == 3 ? "关闭" : trajectoryMenuLabel(TrajectoryDetail(rawValue: value)!),
                    selected: dailyTrajectorySelection == value, disabled: disabled, action: {
                        if value == 3 { page3DHidden = true }
                        else if let detail = TrajectoryDetail(rawValue: value) {
                            if is3D { page3DHidden = false }
                            preferences.trajectoryDetail = detail
                        }
                        vm.hides3DShotAssists = page3DHidden
                        vm.refreshShotAssistVisibility()
                        closeDailyPresentation()
                    })
            }
        case .games:
            return DailyClearanceGame.allCases.map { game in
                DailyHUDMenuItem(id: "dailyClearance.game.\(game.rawValue)", title: game.displayName,
                    selected: game == dailyController.game, action: { selectDailyGame(game) })
            } + [DailyHUDMenuItem(id: "dailyClearance.gameCancel", title: "取消", action: closeDailyPresentation)]
        default:
            var items: [DailyHUDMenuItem] = [
                .init(id: "dailyClearance.displaySettings", title: "显示"),
                .init(id: "freeplay.cameraMode", title: "视图", detail: is3D ? "3D" : "2D",
                      segments: ["2D", "3D"], disabled: isTemporaryTopDown, action: {
                    vm.cancelPowerRelease()
                    showSpinPad = false
                    toggleDailyCamera()
                }),
                .init(id: "dailyClearance.spinTransparencyMenu", title: "打点盘透明度",
                      detail: "\(Int((pageSpinTransparency.wrappedValue * 100).rounded()))%", action: { presentDaily(.transparency) }),
                .init(id: "menu.tableGrid", title: "台面网格 4×8", selected: preferences.showTableGrid, action: {
                    preferences.showTableGrid.toggle(); vm.scene.setTableGridVisible(preferences.showTableGrid)
                    closeDailyPresentation()
                }),
                .init(id: "menu.aimCloseup", title: "瞄准特写", selected: preferences.showAimCloseup, action: {
                    preferences.showAimCloseup.toggle()
                    closeDailyPresentation()
                }),
                .init(id: "dailyClearance.shotSettings", title: "击球设置"),
                .init(id: "dailyClearance.aimModeMenu", title: "瞄准模式 · \(aimModeLabel)", disclosure: true,
                      disabled: vm.isPlaying || vm.isSequencePlaying || vm.isBreakMode || isDailyResult, action: { showSpinPad = false; dailyPresentation = .aim }),
                .init(id: "dailyClearance.trajectoryMenu", title: "轨迹显示 · \(dailyTrajectoryLabel)", disclosure: true,
                      disabled: disabled, action: { dailyPresentation = .trajectory }),
            ]
            if isShotSimulation {
                items.append(.init(id: "shotSimulation.reset", title: "恢复默认球形", disabled: disabled, action: {
                    closeDailyPresentation(); ruleNotices.clear(); vm.loadBoard(ShotSimulationView.defaultBoard)
                }))
            } else if isDailyClearance {
                items.append(.init(id: "dailyClearance.changeGame", title: "临时换玩法", disclosure: true, action: { dailyPresentation = .games }))
            } else if isStandard {
                items.append(.init(id: "freeplay.clearTable", title: "清空桌面", disabled: disabled, action: {
                    closeDailyPresentation(); showClearTableConfirm = true
                }))
            }
            items += closingEditorMenuItems(editor?.menuItems ?? [])
            if isEditor && vm.canCycleBankAlternatives {
                items.append(.init(id: "composer.nextBankAlternative", title: "下一解", disabled: disabled, action: { closeDailyPresentation(); vm.nextBankAlternative() }))
            }
            if isStandard && rules != nil {
                items.append(.init(id: "freeplay.endGame", title: "结束对局", disabled: disabled, action: {
                    closeDailyPresentation(); endGame(); flash("对局已结束")
                }))
            }
            if isManualBreakPage && vm.isBreakMode {
                items.append(.init(id: "freeplay.cancelBreak", title: "取消开球", disabled: vm.breakRunner?.isBusy == true, action: {
                    closeDailyPresentation(); pendingGame = nil; vm.cancelBreakFlow()
                }))
            }
            return items
        }
    }

    private func closingEditorMenuItems(_ items: [DailyHUDMenuItem]) -> [DailyHUDMenuItem] {
        items.map { item in
            var result = item
            if let action = item.action { result.action = { showSpinPad = false; closeDailyPresentation(); action() } }
            return result
        }
    }

    private var navigationStatusText: String {
        if isDailyClearance { return dailyController.statusText }
        if is3D, vm.breakRunner?.phase == .racked, vm.breakRunner?.simulationFailure == nil {
            return "刻度轮调方向 · 拖动母球摆位"
        }
        if !vm.isPlaying, vm.breakRunner == nil, rulingText.isEmpty { return vm.aimSelectionLabel }
        return vm.breakRunner?.statusText(isPerspective: is3D)
            ?? (vm.isComputing ? "求解中…"
                : (!vm.isPlaying && !rulingText.isEmpty ? rulingText : vm.statusText))
    }

    private func requestDailyRerack() {
        guard !isTemporaryTopDown else { return }
        vm.cancelPowerRelease()
        presentDaily(.rerack)
    }

    private func selectDailyGame(_ game: DailyClearanceGame) {
        guard game != dailyController.game else { closeDailyPresentation(); return }
        if dailyController.shotCount > 0, !dailyController.isCompleted {
            dailyPresentation = .gameChange(game)
        } else {
            closeDailyPresentation()
            dailyController.changeGame(game)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func flash(_ message: String, tone: BTToastTone = .success) {
        ruleNotices.show(message, tone: tone, priority: tone == .warning ? .selection : .ruling)
    }
}

#if DEBUG
private extension FreePlayView {
    var dailyCameraPreviewControls: some View {
        VStack(spacing: Spacing.xs) {
            if cameraPreviewExpanded {
                HStack(spacing: Spacing.sm) {
                    ForEach(CameraRig.DailyPreviewProfile.allCases, id: \.rawValue) { profile in
                        Button(profile.title) {
                            cameraPreviewProfile = profile
                            vm.scene.cameraRig?.dailyPreviewProfile = profile
                            vm.requestPlayerView(.thirdPerson, focusTarget: true)
                        }
                        .foregroundStyle(cameraPreviewProfile == profile ? HUDStyle.accent : HUDStyle.valueMeasured)
                        .accessibilityIdentifier("cameraPreview.profile.\(profile.rawValue)")
                        .accessibilityValue(cameraPreviewProfile == profile ? "已选中" : "未选中")
                    }
                    Menu(cameraPreviewScenarioTitle) {
                        ForEach(0..<4) { index in
                            Button(Self.cameraPreviewScenarioNames[index]) { loadDailyCameraPreviewScenario(index) }
                        }
                    }
                    .accessibilityIdentifier("cameraPreview.scenario")
                    Button(cameraPreviewSteady ? "定高低敏 ✓" : "原有手势") {
                        cameraPreviewSteady.toggle()
                        vm.scene.cameraRig?.dailyPreviewSteadyInput = cameraPreviewSteady
                    }
                    .foregroundStyle(cameraPreviewSteady ? HUDStyle.accent : HUDStyle.valueMeasured)
                    .accessibilityIdentifier("cameraPreview.gesture")
                    Button("回到沿杆") { vm.requestPlayerView(.thirdPerson, focusTarget: true) }
                        .accessibilityIdentifier("cameraPreview.reset")
                }
                .disabled(vm.isPlaying || vm.isComputing || vm.cameraTransitionBusy)
                Text("仅观察效果对照 · B：眼高84cm / 库外38cm · C：眼高80cm / 库外50cm · 均48°")
                    .font(.btCaption)
                    .foregroundStyle(HUDStyle.labelColor)
                    .allowsHitTesting(false)
            }
            Button(cameraPreviewExpanded ? "收起对照" : "展开对照") { cameraPreviewExpanded.toggle() }
                .accessibilityIdentifier("cameraPreview.collapse")
        }
        .font(.btCaption)
        .buttonStyle(.borderless)
        .controlSize(.regular)
        .padding(Spacing.sm)
        .background(HUDStyle.panelBackground, in: RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.bottom, Spacing.xs)
    }

    static let cameraPreviewScenarioNames = ["长台远球", "短距离球", "大角度球", "母球近库", "母球近长库", "反向长台", "目标贴短库", "反侧近长库", "中袋右切", "中袋左切", "同库薄球", "反角袋", "紧邻直球", "大切角近角库"]
    var cameraPreviewScenarioTitle: String { Self.cameraPreviewScenarioNames[cameraPreviewScenario] }

    func loadDailyCameraPreviewScenario(_ index: Int) {
        guard showsCameraPreview || cameraReviewScenario != nil, !vm.isPlaying, let rig = vm.scene.cameraRig else { return }
        cameraPreviewScenario = index
        showSpinPad = false
        rig.dailyPreviewProfile = cameraPreviewProfile
        rig.dailyPreviewSteadyInput = cameraPreviewSteady
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        // Fixture inputs are world X/Z metres. The normal daily solver determines the actual cue direction.
        let configurations: [(SCNVector3, SCNVector3, Int)] = [
            (SCNVector3(-1.05, 0, -0.34), SCNVector3(0.80, 0, 0.36), 3),
            (SCNVector3(0.25, 0, 0.04), SCNVector3(0.58, 0, 0.22), 3),
            (SCNVector3(-0.65, 0, 0.48), SCNVector3(0.05, 0, 0.05), 4),
            (SCNVector3(-1.229, 0, -0.40), SCNVector3(-0.40, 0, -0.03), 3),
            (SCNVector3(-0.35, 0, -0.592), SCNVector3(0.45, 0, 0.20), 3),
            (SCNVector3(1.05, 0, 0.34), SCNVector3(-0.80, 0, -0.36), 0),
            (SCNVector3(0.25, 0, -0.30), SCNVector3(1.20, 0, 0.32), 3),
            (SCNVector3(0.35, 0, 0.592), SCNVector3(-0.45, 0, -0.20), 0),
            (SCNVector3(-0.80, 0, -0.12), SCNVector3(-0.12, 0, 0.30), 5),
            (SCNVector3(0.80, 0, 0.12), SCNVector3(0.12, 0, -0.30), 4),
            (SCNVector3(-0.95, 0, -0.55), SCNVector3(0.70, 0, -0.52), 1),
            (SCNVector3(0.75, 0, -0.40), SCNVector3(-0.55, 0, 0.25), 2),
            (SCNVector3(0, 0, -0.40), SCNVector3(0, 0, -0.45725), 4),
            (SCNVector3(-1.20, 0, -0.57), SCNVector3(1.20, 0, -0.38), 3)
        ]
        let config = configurations[index]
        func normalized(_ point: SCNVector3) -> CanvasPoint {
            let p = AngleSceneCalculator.sceneToNormalized(position: point)
            return CanvasPoint(x: Double(p.x), y: Double(p.y))
        }
        vm.loadBoard(BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: normalized(config.0), "_1": normalized(config.1),
            "_2": normalized(SCNVector3(-0.95, 0, 0.36)),
            "_8": normalized(SCNVector3(0.91, 0, -0.16))
        ]))
        vm.velocity = 2.5
        vm.selectTarget(key: "_1")
        vm.selectPocket(at: config.2)
        dailyController.savePlacedBoard()
    }
}
#endif

#Preview("Dark") {
    NavigationStack { FreePlayView() }
        .preferredColorScheme(.dark)
}

/// Viewing actions deliberately use ShotPlayCamera, never the shot-selection handlers.
struct ShotObservationMenu: View {
    @ObservedObject var vm: PositionPlayViewModel
    let identifierPrefix: String
    var overviewYaw: Float? = nil

    var body: some View {
        Menu {
            Button("查看全桌", systemImage: "rectangle") {
                if let overviewYaw {
                    vm.scene.cameraRig?.observeWholeTable(yaw: overviewYaw)
                    vm.scene.discardSavedPerspectiveView()
                } else { ShotPlayCamera.observeWholeTable(on: vm) }
            }
            .accessibilityIdentifier("\(identifierPrefix).observe.table")
            Button("查看母球", systemImage: "circle") {
                ShotPlayCamera.observeBall(PositionPlayBall.cueKey, on: vm)
            }
            .disabled(!isVisible(PositionPlayBall.cueKey))
            .accessibilityIdentifier("\(identifierPrefix).observe.cue")
            Button("查看目标球", systemImage: "scope") {
                if let key = vm.selectedTargetKey { ShotPlayCamera.observeBall(key, on: vm) }
            }
            .disabled(!isVisible(vm.selectedTargetKey))
            .accessibilityIdentifier("\(identifierPrefix).observe.target")
            Button("查看目标袋", systemImage: "viewfinder") {
                ShotPlayCamera.observePocket(vm.selectedPocketIndex, on: vm)
            }
            .disabled(!(0..<6).contains(vm.selectedPocketIndex))
            .accessibilityIdentifier("\(identifierPrefix).observe.pocket")
        } label: {
            Label("视角", systemImage: "viewfinder")
                .font(.btFootnote)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .foregroundStyle(HUDStyle.accent)
        .accessibilityHint("查看全桌、母球、目标球或目标袋，不改变击球选择")
        .accessibilityIdentifier("\(identifierPrefix).observation")
    }

    private func isVisible(_ key: String?) -> Bool {
        guard let key, let node = vm.scene.allBallNodes[key] else { return false }
        return !node.isHidden
    }
}

#Preview("Observation Light") {
    ShotObservationMenu(vm: PositionPlayViewModel(), identifierPrefix: "preview")
        .preferredColorScheme(.light)
}

#Preview("Observation Dark") {
    ShotObservationMenu(vm: PositionPlayViewModel(), identifierPrefix: "preview")
        .preferredColorScheme(.dark)
}

// MARK: - Daily 2D landscape stage

/// Static top-down carpet; the atlas repeats use the same metre scale as BakedTrainingRoom.

private extension FreePlayView {
    var dailyControlColumnWidth: CGFloat { DailyLayoutMetrics.controlColumnWidth }
    var dailyTableLift: CGFloat { DailyLayoutMetrics.tableLift }
    var dailyRulerWidth: CGFloat { DailyLayoutMetrics.rulerWidth }
    var dailyTopButtonDiameter: CGFloat { DailyLayoutMetrics.topButtonDiameter }
    var dailySpinDiscOpacity: Double {
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("-dailyClearance.spinDiscOpacity=")
        }), let value = Double(argument.components(separatedBy: "=").last ?? ""), value.isFinite {
            return min(1, max(0, value))
        }
        #endif
        return 1 - pageSpinTransparency.wrappedValue
    }

    func dailyCarpetUnderlay(sceneSize: CGSize) -> some View {
        DailyCarpetBackground(style: preferences.roomStyle,
            pointsPerMetre: dailySpinPadRect(in: sceneSize).width / CGFloat(dailyPortrait ? AngleSceneCalculator.innerWidth : AngleSceneCalculator.innerLength))
            .ignoresSafeArea()
    }

    func dailyLandscapeBody(size: CGSize, leadingSafeArea: CGFloat, trailingSafeArea: CGFloat) -> some View {
        let foundation: DailyLayoutMetrics.Foundation? = .init(size: size,
            leadingSafeArea: dailyHasAuditSize ? 0 : leadingSafeArea, trailingSafeArea: trailingSafeArea,
            halfLength: vm.scene.cameraRig?.tableOuterHalfLength ?? CameraRig.defaultTableOuterHalfLength,
            halfWidth: vm.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth,
            instrumentHeight: dailyInstrumentHeight,
            palette: dailyFoundationReservation(size: size, safe: dailyHasAuditSize ? 0 : max(leadingSafeArea, trailingSafeArea)))
        let container = DailyLayoutMetrics.Container(size: size, trailingSafeArea: trailingSafeArea)
        // iOS 17's native Menu includes the window safe area in its intrinsic
        // button width when this row extends past the safe boundary. Keep the
        // whole header inside that boundary on the compatibility path; content
        // capacity chooses the appropriate density. iOS 26 keeps its baseline.
        let headerShift: CGFloat
        if foundation != nil { headerShift = 0 }
        else if #available(iOS 26, *) { headerShift = container.headerShift }
        else { headerShift = 0 }
        let sideInset = container.sideInset
        let space = DailyLayoutMetrics.Space(size: size, trailingSafeArea: trailingSafeArea,
            halfLength: vm.scene.cameraRig?.tableOuterHalfLength ?? CameraRig.defaultTableOuterHalfLength,
            halfWidth: vm.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth,
            instrumentHeight: dailyInstrumentHeight, displayScale: displayScale, allowsDock: dailyAuditAllowsDock, foundation: foundation)
        let isLimited = space.isLimited || (foundation.map {
            !dailyPalettePlan(size: size, safe: max(leadingSafeArea, trailingSafeArea), foundation: $0).fits
        } ?? false)
        let sceneSize = space.stage.size
        let rulerHeight = foundation?.rulerLength ?? DailyLayoutMetrics.rulerHeight
        let spinBounds = dailySpinPadRect(in: sceneSize)
        let spinLayout = DailyLayoutMetrics.SpinPad(playingRect: spinBounds, displayScale: displayScale,
            maximumExtent: UIDevice.current.userInterfaceIdiom == .pad ? 310 : max(spinBounds.width, spinBounds.height))
        let spinFrame = CGRect(x: space.stage.minX + spinBounds.midX - spinLayout.extent / 2,
                               y: space.stage.minY + spinBounds.midY - spinLayout.extent / 2,
                               width: spinLayout.extent, height: spinLayout.extent)
        let panelTrailingInset = max(4, max(leadingSafeArea, trailingSafeArea)) + dailyWindowControlInsets.right
        let panels = DailyLayoutMetrics.Panels(pageWidth: size.width,
            trailingSafeArea: panelTrailingInset, spinFrame: spinFrame)
        let controls = space.controls
        let hudContent = ZStack(alignment: .topLeading) {
                if let foundation {
                    dailyFoundationHeader(size: size, safe: max(leadingSafeArea, trailingSafeArea), foundation: foundation)
                        .zIndex(1)
                } else {
                    dailyLandscapeHeader(size: size, leadingAllowance: leadingSafeArea, trailingShift: headerShift)
                        .frame(width: size.width + headerShift, height: DailyLayoutMetrics.headerHeight)
                        .zIndex(1)
                }
                dailyLeftControls(rulerHeight: rulerHeight, space: space)
                    .frame(width: space.left.width, height: space.left.height, alignment: .top)
                    .position(x: space.left.midX, y: space.left.midY)
                    .opacity(isLimited ? 0 : 1)
                    .allowsHitTesting(!isLimited)
                    .accessibilityHidden(isLimited)
                GeometryReader { stage in
                        ZStack {
                            if !vm.isBreakMode && !isDailyResult && vm.showsShotAssists && !showSpinPad && ruleNotices.message == nil {
                                BTAimCloseupOverlay(snapshot: vm.closeupSnapshot,
                                    sceneSize: stage.size, scene: vm.scene,
                                    safeInsets: .init(top: 0, leading: 0, bottom: 28, trailing: 0),
                                    blockedSide: nil, protectsDailySight: true, frameInWindow: stage.frame(in: .global),
                                    placementBounds: dailySpinPadRect(in: stage.size))
                            }
                            if showSpinPad {
                                let playingRect = dailySpinPadRect(in: stage.size)
                                BTSceneSpinPadOverlay(spinX: dailySpinX, spinY: dailySpinY, scene: vm.scene,
                                    tableWidth: playingRect.width,
                                    bottomPadding: stage.size.height - playingRect.midY - spinLayout.extent / 2,
                                    fixedCardExtent: spinLayout.extent,
                                    discOpacity: dailySpinDiscOpacity,
                                    cardHorizontalOffset: 0,
                                    isReadOnly: sequenceReadOnly,
                                    onSpinChange: updateDailySpin,
                                    onClose: { showSpinPad = false })
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        #if DEBUG
                        .background {
                            if DailyLayoutProbe.enabled {
                                let bounds = dailySpinPadRect(in: stage.size)
                                let frame = stage.frame(in: .global)
                                Color.clear.accessibilityElement()
                                    .accessibilityIdentifier("dailyLayout.spinGeometry")
                                    .accessibilityValue("innerX=\(frame.minX + bounds.minX) innerY=\(frame.minY + bounds.minY) innerWidth=\(bounds.width) innerHeight=\(bounds.height) extent=\(spinLayout.extent) fits=\(spinLayout.fits)")
                            }
                        }
                        #endif
                        .overlay(alignment: .top) {
                            VStack(spacing: 4) {
                                dailyFeedbackOverlay
                                editor?.overlay
                            }
                                .padding(.top, dailyFeedbackTop(in: stage.size))
                        }
                        .background(Color.clear.accessibilityElement()
                            .accessibilityIdentifier("freeplay.stage"))
                        // The actual central stage excludes the header, fixed control lanes
                        // and safe-area/padding. Measure in window points, not a guessed ratio.
                        .preference(key: DailyCameraReadableFrameKey.self,
                                    value: stage.frame(in: .global))
                        .anchorPreference(key: DailyCameraReadableBoundsKey.self, value: .bounds) { $0 }
                    }
                    .frame(width: sceneSize.width, height: sceneSize.height)
                    .position(x: space.stage.midX, y: space.stage.midY)
                    .allowsHitTesting(!isLimited)
                dailyRightControls(rulerHeight: rulerHeight, space: space, pageWidth: size.width, trailingSafeArea: trailingSafeArea)
                    .frame(width: space.right.width, height: space.right.height, alignment: .top)
                    .position(x: space.right.midX, y: space.right.midY)
                    .opacity(isLimited ? 0 : 1)
                    .allowsHitTesting(!isLimited)
                    .accessibilityHidden(isLimited)
        }
        .frame(width: size.width + headerShift, alignment: .leading)
        // Measure the background from the page's actual height, not the controls' minimum.
        .frame(height: size.height)
        let sceneContent = hudContent
        .backgroundPreferenceValue(DailyCameraReadableBoundsKey.self) { readableBounds in
            // Resolve the stage anchor in the renderer parent's local coordinates.
            // Navigation hosting can transform window/global frames during entry; caching
            // one frame then subtracting a later global origin leaves the SCNView offscreen.
            // This keeps the same renderer alive as its local frame and projection change.
            GeometryReader { viewport in
                let fullFrame = CGRect(origin: .zero, size: viewport.size)
                let renderFrame = is3D ? fullFrame : (readableBounds.map { viewport[$0] } ?? fullFrame)
                sceneContainer(fpsTrailingInset: is3D ? dailyControlColumnWidth + Spacing.xs + sideInset : nil)
                    .frame(width: renderFrame.width, height: renderFrame.height)
                    .position(x: renderFrame.midX, y: renderFrame.midY)
                    .opacity(is3D || readableBounds != nil ? 1 : 0)
                    .allowsHitTesting(!isLimited)
            }
            .ignoresSafeArea()
        }
        .background {
            // Keep the underlay alive while SceneKit resizes its surface between modes.
            // Removing it first exposes the hosting view for one frame on device.
            dailyCarpetUnderlay(sceneSize: sceneSize)
        }
        .environment(\.colorScheme, .dark)
        return sceneContent
        .overlay {
            if isLimited {
                VStack(spacing: Spacing.sm) {
                    Text("扩大窗口后继续击球").font(.btSubheadlineSemibold)
                        .accessibilityIdentifier("dailyLayout.limited")
                    Text("当前空间无法完整放下球桌和操作控件。").font(.btFootnote)
                        .multilineTextAlignment(.center)
                    Button("返回") { vm.cancelPowerRelease(); dismiss() }
                        .buttonStyle(BTSceneDecisionActionStyle())
                        .accessibilityIdentifier("dailyLayout.limitedBack")
                }
                .padding(Spacing.md)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: BTRadius.md))
            }
        }
        .overlay(alignment: .topLeading) {
            if dailyPresentation == nil, manualBreakNeedsConfirmation || !dailyController.breakChoices.isEmpty || isDailyResult {
                Group {
                    if manualBreakNeedsConfirmation { manualBreakConfirmationActions }
                    else if isDailyResult { dailyResultActions }
                    else { dailyRuleChoice }
                }
                .frame(width: min(460, max(148, space.stage.width - 16)))
                .position(x: foundation?.table.midX ?? size.width / 2,
                          y: foundation?.table.midY ?? size.height / 2)
                .accessibilityAddTraits(.isModal)
            }
        }
        .overlay(alignment: .topTrailing) {
            if showSpinTransparency {
                ZStack(alignment: .topTrailing) {
                    Button { showSpinTransparency = false } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭透明度设置")
                    DailySpinTransparencyPanel(transparency: pageSpinTransparency,
                        availableSize: CGSize(width: min(panels.settingsWidth, max(0, size.width - 2 * Spacing.sm)),
                            height: panels.settingsHeight(pageHeight: size.height, strikeFrame: dailyStrikeFrame)),
                        onClose: { showSpinTransparency = false })
                        .padding(.top, DailyLayoutMetrics.Panels.top)
                        .padding(.trailing, panels.settingsTrailingPadding)
                        .accessibilityAddTraits(.isModal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let presentation = dailyPresentation, presentation != .transparency {
                ZStack(alignment: .topTrailing) {
                    Button { if !presentation.isDecision { closeDailyPresentation() } } label: {
                        Color.clear.contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("关闭菜单")
                    if presentation.isDecision {
                        let centerY = is3D ? size.height / 2 : (foundation?.table.midY ?? size.height / 2)
                        let decisionHeight = 2 * min(centerY, size.height - centerY) - 16
                        let decisionWidth = size.width - 2 * max(4, max(leadingSafeArea, trailingSafeArea))
                        Group {
                            if case .gameChange(let game) = presentation {
                                DailyConfirmationCard(title: "切换玩法会放弃当前进度", availableHeight: decisionHeight, availableWidth: decisionWidth, firstTitle: "放弃并切换", secondTitle: "取消",
                                    firstID: "dailyClearance.gameChangeConfirm", secondID: "dailyClearance.gameChangeCancel",
                                    first: { closeDailyPresentation(); dailyController.changeGame(game) },
                                    second: closeDailyPresentation)
                            } else if presentation == .breakRerack {
                                DailyHUDMenuPanel(title: "重新开球", items: dailyBreakRerackItems,
                                    availableSize: CGSize(width: size.width - 2 * max(4, max(leadingSafeArea, trailingSafeArea)), height: decisionHeight),
                                    onBack: closeDailyPresentation, onClose: closeDailyPresentation)
                            } else { dailyRerackConfirmation(availableHeight: decisionHeight, availableWidth: decisionWidth) }
                        }
                        .position(x: foundation?.table.midX ?? size.width / 2,
                                  y: is3D ? size.height / 2 : (foundation?.table.midY ?? size.height / 2))
                    } else {
                        DailyHUDMenuPanel(title: dailyMenuTitle, items: dailyMenuItems,
                            availableSize: CGSize(width: size.width - 2 * panelTrailingInset,
                                                  height: size.height - DailyLayoutMetrics.Panels.top - 8),
                            onBack: { dailyPresentation = .more }, onClose: closeDailyPresentation)
                            .padding(.top, DailyLayoutMetrics.Panels.top)
                            .padding(.trailing, panelTrailingInset)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .coordinateSpace(name: "freeplay")
        .overlay {
            if let key = draggingKey {
                BTBallPaletteDragGhost(key: key, location: dragLocation, overTable: dragOverTable)
            }
        }
        .onChange(of: size) { _, _ in cancelPaletteDrag() }
        .onChange(of: size.height > size.width, initial: true) { _, portrait in
            dailyPortrait = portrait
            if !is3D { ShotPlayCamera.setMode(portrait ? .topDown2DRotated : .topDown2D, on: vm) }
        }
        .onPreferenceChange(DailyStrikeFrameKey.self) { frame in
            if dailyStrikeFrame != frame { dailyStrikeFrame = frame }
        }
        .environment(\.dailyHUDControls, true)
        .onPreferenceChange(DailyCameraReadableFrameKey.self) { frame in
            if dailyCameraReadableFrame != frame { dailyCameraReadableFrame = frame }
        }
        .onPreferenceChange(DailyInstrumentHeightKey.self) { height in
            if height.isFinite, height > 0, dailyInstrumentHeight != height {
                dailyInstrumentHeight = height
            }
        }
        #if DEBUG
        .background {
            if ProcessInfo.processInfo.arguments.contains("-dailyLayout.probe") {
                Color.clear.accessibilityElement()
                    .accessibilityIdentifier("dailyLayout.spaceProbe")
                    .accessibilityValue("pageWidth=\(size.width) pageHeight=\(size.height) docked=\(space.docked) limited=\(isLimited) sideTableWidth=\(space.sideTableWidth) dockTableWidth=\(space.dockTableWidth) halfLength=\(vm.scene.cameraRig?.tableOuterHalfLength ?? CameraRig.defaultTableOuterHalfLength) halfWidth=\(vm.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth)")
                Color.clear.accessibilityElement()
                    .accessibilityIdentifier("dailyLayout.controlsProbe")
                    .accessibilityValue(dailyControlsProbe(stageHeight: sceneSize.height, controls: controls, foundation: foundation)
                        + " panelWidth=\(panels.settingsWidth) panelLeading=\(panels.settingsLeading) docked=\(space.docked) sideTableWidth=\(space.sideTableWidth) dockTableWidth=\(space.dockTableWidth) pageWidth=\(size.width) pageHeight=\(size.height)")
            }
        }
        #endif
        .background(Color.clear.accessibilityElement()
            .accessibilityIdentifier(isShotSimulation ? "shotSimulation.landscape" : (isEditor ? "composer.landscape" : (isStandard ? "freeplay.landscape" : "dailyClearance.landscape")))
            .accessibilityLabel(pageTitle + "状态")
            .accessibilityValue(templateStateDescription))
    }

    /// Both modes use the unzoomed 2D playfield in stage-local points, independent of camera motion.
    func dailyFeedbackTop(in size: CGSize) -> CGFloat {
        max(Spacing.sm, min(dailySpinPadRect(in: size).minY + Spacing.md, size.height / 3))
    }

    @ViewBuilder var dailyFeedbackOverlay: some View {
        Group {
            if dailyDecisionActive { EmptyView() }
            else if isManualBreakPage, let runner = vm.breakRunner {
                dailyInformation(runner.statusText(isPerspective: is3D))
            } else if isStandard, rules != nil, ruleNotices.message == nil, !showSpinPad {
                VStack(spacing: 4) {
                    gamePill
                    if !rulingText.isEmpty, rulingText != scoreboardText {
                        Text(rulingText).font(.btCaption).foregroundStyle(.white)
                    }
                }
            }
            else if !dailyController.breakChoices.isEmpty {
                dailyInformation(dailyController.statusText)
            } else if dailyController.isCompleted {
                dailyInformation(dailyResultSummary)
            } else if dailyController.phase == .failed {
                dailyInformation(dailyController.statusText)
            } else if !showSpinPad, let message = ruleNotices.message {
                BTNoticeContent(message: message, compact: true, textOnly: true)
                    .accessibilityIdentifier("dailyClearance.notice")
            } else if isEditor {
                dailyInformation(sequenceReadOnly ? vm.statusText : vm.aimSelectionLabel)
                    .accessibilityIdentifier("composer.status")
            } else if isShotSimulation, vm.cuePocketed, !showSpinPad {
                dailyInformation("母球进袋")
            }
        }
        .frame(maxWidth: 460)
        .padding(.horizontal, Spacing.sm)
        .accessibilityElement(children: .contain)
    }

    private func dailyInformation(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle").accessibilityHidden(true)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline).foregroundStyle(.white)
        .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dailyClearance.notice")
    }

    func dailyLeftControls(rulerHeight: CGFloat, space: DailyLayoutMetrics.Space) -> some View {
        let horizontalActions = space.foundation?.horizontalActions ?? (!space.docked && space.controls.horizontalActions)
        let verticalPadding = space.foundation != nil ? 0 : (space.docked ? Spacing.sm : space.controls.verticalPadding)
        let dailyTopButtonDiameter = space.topDiameter
        let auxiliary = space.auxiliarySize
        let group = space.docked ? AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.sm))
            : AnyLayout(VStackLayout(spacing: space.foundation == nil ? 6 : 4))
        return group {
            VStack(spacing: space.foundation == nil ? 6 : 4) {
                if isShotSimulation {
                    simulationReadout.frame(width: dailyControlColumnWidth, height: dailyTopButtonDiameter + 14)
                } else if manualBreakNeedsConfirmation {
                    // Preserve the control lane height without an invisible actionable button.
                    VStack(spacing: 2) {
                        Color.clear.frame(width: dailyTopButtonDiameter, height: dailyTopButtonDiameter)
                        Text("重开").font(.btMicro).hidden()
                    }
                    .accessibilityHidden(true)
                } else {
                Button(action: {
                    editor?.onInteraction()
                    if editor?.isTryout == true { showSpinPad = false; editor?.onRearrange() }
                    else if isDailyClearance { requestDailyRerack() }
                    else {
                        vm.cancelPowerRelease(); showSpinPad = false
                        if let runner = vm.breakRunner { runner.reRack() }
                        else { showBreakPicker = true }
                    }
                }) {
                    VStack(spacing: 2) {
                        // Meet the inner edge of the surrounding 1pt circle stroke.
                        BreakRackGlyph(color: HUDStyle.valueMeasured, size: dailyTopButtonDiameter - 1, hollowBalls: true)
                            .btHUDActionContent()
                            .frame(width: dailyTopButtonDiameter, height: dailyTopButtonDiameter)
                            .background { BTHUDControlBackground(shape: Circle()) }
                            .overlay(Circle().stroke(HUDStyle.hairline, lineWidth: 1))
                        Text(editor?.isTryout == true ? "重摆" : (isManualBreakPage && vm.isBreakMode ? "重开" : "开球")).font(.btMicro).btHUDActionContent()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(BTHUDPressStyle())
                .accessibilityIdentifier(editor?.isTryout == true ? "tryout.rearrange" : (isManualBreakPage && vm.isBreakMode ? "break.rerack" : "break.entry"))
                .disabled(templateRerackDisabled)
                }
                VStack(spacing: 6) {
                    BTAimWheel(onNudge: { delta in
                        editor?.onInteraction()
                        vm.cancelPowerRelease()
                        if let runner = vm.breakRunner { runner.nudgeAim(byDegrees: delta) }
                        else { vm.nudgeFreeAim(byDegrees: delta) }
                    }, degreesPerPoint: vm.breakRunner?.aimWheelDegreesPerPoint ?? vm.aimWheelDegreesPerPoint,
                        degreeHapticEnabled: false, travelHapticEnabled: true,
                        onDragActiveChanged: { active in
                            if active { daily3DDiagnostics?.input(.aimWheel, intent: .aim) }
                            daily3DDiagnostics?.setInteraction(.aimWheel, stage: .aim, active: active)
                            dailyAimWheelIsDragging = active
                            vm.setAimWheelDragging(active)
                        }, visibleWidth: dailyRulerWidth, usesCompactAppearance: true, showsDirectionLabel: false)
                        .frame(width: 44, height: rulerHeight)
                    Text("方向").font(.btMicro).foregroundStyle(.btTextSecondary)
                }
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: BTRadius.xl).fill(HUDStyle.controlBackground)
                        .overlay(RoundedRectangle(cornerRadius: BTRadius.xl)
                            .stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                        .frame(width: dailyRulerWidth + 12)
                }
                .disabled(dailyControlsDisabled)
            }
            .frame(width: dailyControlColumnWidth)
            let actionLayout = horizontalActions
                ? AnyLayout(HStackLayout(spacing: Spacing.xs))
                : AnyLayout(VStackLayout(spacing: Spacing.xs))
            dailyActionSlot(height: horizontalActions ? auxiliary : auxiliary * 2 + Spacing.xs, originalTopFraction: space.docked ? 1 : (horizontalActions ? 0.5 : 1), natural: space.foundation != nil) {
                actionLayout {
                    dailyCompactAction(sequenceReadOnly ? "上一杆" : "重打", symbol: "arrow.uturn.backward", id: "dailyClearance.undo", size: auxiliary) {
                        daily3DDiagnostics?.input(.undo, intent: .aim)
                        vm.cancelPowerRelease()
                        if sequenceReadOnly { vm.replayPreviousSequenceStep() }
                        else if isDailyClearance { dailyController.undoShot() } else { vm.replayCurrent() }
                    }
                    .disabled(vm.isPlaying || !(sequenceReadOnly ? vm.canReplayPreviousStep : (isDailyClearance ? dailyController.canUndo : vm.canReplay)) || isDailyResult || isTemporaryTopDown)
                    dailyCompactAction(sequenceReadOnly ? "重播" : "回放", symbol: "play.rectangle", id: "dailyClearance.playback", size: auxiliary) {
                        daily3DDiagnostics?.input(.replay)
                        vm.cancelPowerRelease()
                        if sequenceReadOnly { vm.replayCurrentSequenceStep() } else { vm.replayLastShot() }
                    }
                    .disabled(vm.isPlaying || !(sequenceReadOnly ? vm.canReplayCurrentStep : vm.canPlayback) || isTemporaryTopDown)
                }
                .frame(width: horizontalActions ? auxiliary * 2 + Spacing.xs : auxiliary)
                .frame(width: space.docked ? auxiliary : dailyControlColumnWidth, alignment: horizontalActions ? .trailing : .center)
            }
            .frame(width: space.docked ? auxiliary : dailyControlColumnWidth,
                   height: space.docked ? space.left.height - 2 * verticalPadding : nil)
        }
        .frame(width: space.left.width)
        .padding(.vertical, verticalPadding)
    }

    /// Halve the former flexible gap above each action group while keeping its hit size.
    @ViewBuilder func dailyActionSlot<Content: View>(height: CGFloat, originalTopFraction: CGFloat, precedingGap: CGFloat = 0, natural: Bool = false,
                                        @ViewBuilder content: @escaping () -> Content) -> some View {
        if natural { content().fixedSize() } else {
        GeometryReader { slot in
            content()
                .fixedSize()
                .position(x: slot.size.width / 2,
                          y: height / 2 + max(0, slot.size.height - height) * originalTopFraction / 2 - precedingGap / 2)
        }
        .frame(minHeight: height)
        }
    }

    var templateStrikeTitle: String {
        if sequenceReadOnly {
            switch vm.sequencePlayState {
            case .idle: return BTStrikeTitle.solutionDemo
            case .playing: return BTStrikeTitle.sequencePause
            case .paused: return BTStrikeTitle.sequenceResume
            }
        }
        if isManualBreakPage, let runner = vm.breakRunner {
            return runner.showsConfirm ? "完成" : (runner.isBusy ? "开球中" : "开球")
        }
        return dailyController.isAutomaticallyBreaking ? "开球中" : (vm.isComputing ? "计算中" : "击球")
    }

    var templateStrikeDisabled: Bool {
        if sequenceReadOnly { return isTemporaryTopDown || vm.isSequencePausePending || (!vm.isSequencePlaying && vm.isPlaying) }
        if isManualBreakPage, let runner = vm.breakRunner {
            return isTemporaryTopDown || dailyDecisionActive || runner.isBusy
        }
        return vm.isBreakMode ? dailyControlsDisabled : !strikeEnabled
    }

    func dailyRightControls(rulerHeight: CGFloat, space: DailyLayoutMetrics.Space, pageWidth: CGFloat, trailingSafeArea: CGFloat) -> some View {
        let verticalPadding = space.foundation != nil ? 0 : (space.docked ? Spacing.sm : space.controls.verticalPadding)
        let dailyTopButtonDiameter = space.topDiameter
        let group = space.docked ? AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.sm))
            : AnyLayout(VStackLayout(spacing: Spacing.xs))
        return group {
            BTShotInstrumentColumn(spinX: dailySpinX.wrappedValue, spinY: dailySpinY.wrappedValue,
                onSpinTap: {
                    editor?.onInteraction()
                    daily3DDiagnostics?.input(.spin, intent: .aim)
                    vm.cancelPowerRelease(); showSpinPad.toggle()
                },
                velocity: dailyVelocity,
                range: vm.isBreakMode ? BreakFlowRunner.breakVelocityRange : ShotTuning.velocityRange,
                isDisabled: sequenceReadOnly ? false : dailyControlsDisabled,
                isReadOnly: sequenceReadOnly, spinTapEnabled: !sequenceReadOnly || vm.isSequencePaused,
                onPowerDragBegan: {
                    daily3DDiagnostics?.input(.power, intent: .aim)
                    daily3DDiagnostics?.setInteraction(.power, stage: .aim, active: true)
                    showSpinPad = false; vm.beginPowerDrag()
                },
                onPowerDragEnded: { _ in
                    daily3DDiagnostics?.setInteraction(.power, stage: .aim, active: false)
                    vm.endPowerDrag(commit: false)
                },
                usesCompactAppearance: true,
                fixedPowerBarHeight: rulerHeight,
                powerLabel: "杆速",
                compactPowerBarWidth: dailyRulerWidth,
                compactSpinButtonDiameter: dailyTopButtonDiameter,
                compactGroupSpacing: space.foundation == nil ? 6 : 4,
                reportsPowerShellBounds: true)
                .frame(width: max(52, dailyTopButtonDiameter))
                .frame(width: dailyControlColumnWidth)
                .environment(\.layoutDirection, .leftToRight)
                .background(GeometryReader { instrument in
                    Color.clear.preference(key: DailyInstrumentHeightKey.self, value: instrument.size.height - (dailyTopButtonDiameter - DailyLayoutMetrics.topButtonDiameter)
                        + (DailyLayoutMetrics.rulerHeight - rulerHeight) + (space.foundation == nil ? 0 : 2))
                })
                // The panel covers the lane visually; its dismissal layer owns input.
                .accessibilityHidden(showSpinTransparency)
            dailyActionSlot(height: space.strikeSize, originalTopFraction: space.docked ? 1 : 0.5, precedingGap: space.docked ? 0 : Spacing.xs, natural: space.foundation != nil) {
                Group {
                    if manualBreakNeedsConfirmation {
                        Color.clear.frame(width: space.strikeSize, height: space.strikeSize)
                            .accessibilityHidden(true)
                    } else {
                        Button {
                            daily3DDiagnostics?.input(.strike)
                            vm.cancelPowerRelease()
                            editor?.onInteraction()
                            showSpinPad = false
                            if sequenceReadOnly { vm.toggleSequencePlayback() }
                            else if let runner = vm.breakRunner {
                                if isManualBreakPage && runner.showsConfirm { runner.confirmSettled() }
                                else { runner.breakNow() }
                            } else { vm.play() }
                            if (vm.breakRunner?.statusText ?? vm.statusText) == CueStrikeAccess.unavailableMessage {
                                ruleNotices.show(CueStrikeAccess.unavailableMessage, tone: .warning, priority: .selection)
                            }
                        } label: {
                            Text(templateStrikeTitle).font(.btSubheadlineSemibold)
                                .frame(width: space.strikeSize, height: space.strikeSize)
                        }
                        .buttonStyle(DailyStrikeButtonStyle())
                        .disabled(templateStrikeDisabled)
                        .opacity(templateStrikeDisabled ? 0.4 : 1)
                        .accessibilityLabel(templateStrikeTitle)
                        .accessibilityHint("按下击球；杆速条仅调整杆头速度")
                        .accessibilityIdentifier(isManualBreakPage && vm.isBreakMode ? (vm.breakRunner?.showsConfirm == true ? "break.confirm" : "break.strike") : "dailyClearance.strike")
                    }
                }
                .background(GeometryReader { strike in
                    Color.clear.preference(key: DailyStrikeFrameKey.self,
                                           value: strike.frame(in: .named("freeplay")))
                })
            }
            .frame(width: space.strikeSize, height: space.docked ? space.right.height - 2 * verticalPadding : nil)
            .environment(\.layoutDirection, .leftToRight)
        }
        .environment(\.layoutDirection, space.docked ? .rightToLeft : .leftToRight)
        .frame(width: space.right.width)
        .padding(.vertical, verticalPadding)
        .overlayPreferenceValue(BTPowerShellBoundsKey.self) { bounds in
            GeometryReader { overlay in
            if let bounds, is3D, let rig = vm.scene.cameraRig, !showSpinPad || rig.usesTwoViewCameraControls {
                ShotPlayerCameraButtons(controlSpacing: 4, rig: rig,
                    isEnabled: vm.temporaryTopDownActive || (!vm.isPlaying && !vm.isComputing && vm.currentPlayerAim != nil),
                    onWholeTable: {
                        daily3DDiagnostics?.input(.cameraButton, intent: .orbit)
                        // A user overview request is independent of break/rerack framing.
                        if rig.usesSurfaceCamera { vm.requestSurfaceOverview() }
                        else { observeWholeTableForPage() }
                    }, usesTwoViewControls: rig.usesTwoViewCameraControls,
                    temporaryTopDownActive: vm.temporaryTopDownActive,
                    onTemporaryTopDownBegan: { vm.beginTemporaryTopDown() },
                    onTemporaryTopDownEnded: { vm.endTemporaryTopDown() }) { view in
                    daily3DDiagnostics?.input(.cameraButton, intent: .orbit)
                    showSpinPad = false
                    vm.requestPlayerView(view)
                }
                    .background(GeometryReader { controls in
                        Color.clear.preference(key: DailyCameraControlHeightKey.self,
                                               value: controls.size.height)
                    })
                    .onPreferenceChange(DailyCameraControlHeightKey.self) { height in
                        if height > 0, dailyCameraControlStackHeight != height {
                            dailyCameraControlStackHeight = height
                        }
                    }
                    .offset(DailyLayoutMetrics.CameraLane(column: space.right,
                        rulerHeight: rulerHeight, powerShell: overlay[bounds],
                        stackHeight: dailyCameraControlStackHeight).offset)
            }
            }
        }
    }

    func dailyRerackConfirmation(availableHeight: CGFloat, availableWidth: CGFloat) -> some View {
        DailyConfirmationCard(title: "重新开始这一局？", availableHeight: availableHeight, availableWidth: availableWidth, firstTitle: "重新开球", secondTitle: "继续击球",
            firstID: "dailyClearance.rerackAfterBreak", secondID: "dailyClearance.confirmBreak",
            first: { closeDailyPresentation(); ruleNotices.clear(); dailyController.confirmRerack() },
            second: { closeDailyPresentation(); ruleNotices.clear() })
    }

    private func resolveDailyBreak(_ choice: DailyBreakChoice) {
        closeDailyPresentation()
        ruleNotices.clear()
        dailyController.resolveBreakChoice(choice)
        vm.refreshLegalAimSelection()
    }

    private var dailyBreakRerackItems: [DailyHUDMenuItem] {
        dailyController.breakChoices.filter { $0 == .rerackByBreaker || $0 == .rerackByIncoming }.map { choice in
            DailyHUDMenuItem(id: "dailyClearance.ruleChoice.\(choice.rawValue)", title: choice.label,
                detail: choice == .rerackByBreaker ? "记警告" : "换方",
                action: { resolveDailyBreak(choice) })
        } + [.init(id: "dailyClearance.ruleChoice.back", title: "返回处理方式", action: closeDailyPresentation)]
    }

    private var templateRerackDisabled: Bool {
        isDailyResult || isTemporaryTopDown || (isManualBreakPage &&
            (vm.isPlaying || vm.isSequencePlaying || vm.isRecording || vm.breakRunner?.isBusy == true))
    }

    private var manualBreakNeedsConfirmation: Bool {
        isManualBreakPage && vm.breakRunner?.showsConfirm == true
    }

    private var manualBreakConfirmationActions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Button("重开") {
                editor?.onInteraction()
                vm.cancelPowerRelease(); showSpinPad = false
                vm.breakRunner?.reRack()
            }
                .buttonStyle(BTSceneDecisionActionStyle())
                .disabled(templateRerackDisabled)
                .opacity(templateRerackDisabled ? 0.4 : 1)
                .accessibilityIdentifier("break.rerack")
            Button("完成") {
                daily3DDiagnostics?.input(.strike)
                editor?.onInteraction()
                vm.cancelPowerRelease(); showSpinPad = false
                vm.breakRunner?.confirmSettled()
            }
                .buttonStyle(BTSceneDecisionActionStyle(isPrimary: true))
                .disabled(templateStrikeDisabled)
                .opacity(templateStrikeDisabled ? 0.4 : 1)
                .accessibilityIdentifier("break.confirm")
        }
        .accessibilityElement(children: .contain)
    }

    var dailyRuleChoice: some View {
        let choices = dailyController.breakChoices
        let weakBreak = Set(choices) == Set([DailyBreakChoice.rerackByIncoming, .rerackByBreaker, .acceptBallInHand])
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            if weakBreak {
                Button("重新开球") { presentDaily(.breakRerack) }
                    .buttonStyle(BTSceneDecisionActionStyle())
                    .accessibilityIdentifier("dailyClearance.ruleChoice.rerack")
                Button("继续击球") { resolveDailyBreak(.acceptBallInHand) }
                    .buttonStyle(BTSceneDecisionActionStyle(isPrimary: true))
                    .accessibilityHint("换方并获得全台自由球")
                    .accessibilityIdentifier("dailyClearance.ruleChoice.acceptBallInHand")
            } else {
                ForEach(choices, id: \.self) { choice in
                    Button(choice.label) { resolveDailyBreak(choice) }
                        .buttonStyle(BTSceneDecisionActionStyle(isPrimary: choice == choices.last))
                        .accessibilityIdentifier("dailyClearance.ruleChoice.\(choice.rawValue)")
                }
            }
        }
    }

    @ViewBuilder private var dailyResultActions: some View {
        if dailyController.isCompleted {
            Button("再来一局") { dailyController.replay() }
                .buttonStyle(BTSceneDecisionActionStyle(isPrimary: true))
                .accessibilityIdentifier("dailyClearance.replay")
        } else if dailyController.phase == .failed {
            Button("重新开球") { requestDailyRerack() }
                .buttonStyle(BTSceneDecisionActionStyle(isPrimary: true))
                .accessibilityIdentifier("dailyClearance.rerack")
        }
    }

    func observeWholeTableForPage() {
        if vm.scene.cameraRig?.usesSurfaceCamera == true {
            if vm.isBreakMode { vm.requestPlayerView(.thirdPerson) }
            else { vm.requestSurfaceOverview() }
        } else if usesMergedCamera {
            vm.scene.cameraRig?.enterMergedGlobal(aim: vm.currentPlayerAim)
            vm.scene.discardSavedPerspectiveView()
        } else if usesCoreTemplate, usesDailyTwoViewControls {
            vm.requestPlayerView(.thirdPerson)
        } else if isDailyClearance {
            vm.scene.cameraRig?.observeDailyWholeTable(aimDirection: vm.currentPlayerAim)
            vm.scene.discardSavedPerspectiveView()
        } else {
            ShotPlayCamera.observeWholeTable(on: vm)
        }
    }

    func toggleDailyCamera() {
        guard !isTemporaryTopDown else { return }
        let initialOverview = !is3D && !vm.scene.hasPerspectiveView
        let initializedPerspective = ShotPlayCamera.setMode(is3D ? (dailyPortrait ? .topDown2DRotated : .topDown2D) : .perspective3D, on: vm)
        if initializedPerspective { return }
        if is3D, vm.isBreakMode, vm.scene.cameraRig?.usesSurfaceCamera == true {
            vm.requestPlayerView(.thirdPerson)
        } else if initialOverview {
            if usesCoreTemplate, usesDailyTwoViewControls {
                if vm.scene.cameraRig?.usesSurfaceCamera == true, vm.isBreakMode { vm.requestSurfaceOverview() }
                else { vm.requestPlayerView(.thirdPerson) }
            } else {
                vm.scene.cameraRig?.observeDailyWholeTable(aimDirection: vm.currentPlayerAim)
                vm.scene.discardSavedPerspectiveView()
            }
        }
    }

    /// Anchor the palette to the unzoomed table frame in window points in both modes.
    func dailyPaletteDrop(headerFrame: CGRect) -> CGFloat {
        guard let stage = dailyCameraReadableFrame,
              let scale = CameraRig.landscapeOrthographicScale(viewSize: stage.size,
                halfLength: vm.scene.cameraRig?.tableOuterHalfLength ?? CameraRig.defaultTableOuterHalfLength,
                halfWidth: vm.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth)
        else { return 0 }
        let halfWidth = vm.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth
        let tableTop = stage.midY - CGFloat(halfWidth / scale) * stage.height / 2
        // Center the 34pt capsule inside its 44pt hit row, with a two-point rail gap.
        let capsuleBottom = headerFrame.midY + 34 / 2
        let railDrop = max(0, tableTop - 2 - capsuleBottom)
        // Narrow screens place the cue wing above the break lane. Stop before its hit area.
        if headerFrame.minX < stage.minX {
            let controls = DailyLayoutMetrics.Controls(stageHeight: stage.height,
                instrumentHeight: dailyInstrumentHeight, displayScale: displayScale)
            let controlsTop = stage.minY + dailyTableLift + controls.verticalPadding
            return min(railDrop, max(0, controlsTop - 2 - headerFrame.maxY))
        }
        return railDrop
    }

    /// Navigation and the table-anchored palette have independent vertical
    /// positions. Target slots remain centred even for a short ruleset.
    func dailyFoundationReservation(size: CGSize, safe: CGFloat) -> DailyLayoutMetrics.FoundationReservation {
        .init(width: size.width - 2 * max(4, safe),
              targetCount: templatePaletteKeys.count,
              chineseEightBall: dailyPaletteGame == .chineseEightBall,
              titleWidth: 32 + dailyHeaderTitleWidth(size: 15), actionWidth: 138,
              prefersSeparateRow: size.height > size.width || size.height >= 600,
              // A separate row in a shallow landscape must leave both side
              // lanes free: its cue wing must not cover the break control.
              separateWidth: size.width > size.height && size.height < 600
                ? size.width - 2 * (max(4, safe) + 60 + 8) : nil)
    }

    func dailyPalettePlan(size: CGSize, safe: CGFloat, foundation: DailyLayoutMetrics.Foundation) -> DailyLayoutMetrics.Palette {
        let side = max(4, safe)
        return DailyLayoutMetrics.Palette(size: size, sideInset: side, table: foundation.table,
            targetCount: templatePaletteKeys.count, chineseEightBall: dailyPaletteGame == .chineseEightBall,
            obstacles: [
                CGRect(x: side + dailyWindowControlInsets.left, y: 0, width: 44, height: 44),
                CGRect(x: side + dailyWindowControlInsets.left + 32, y: (44 - dailyHeaderTitleHeight) / 2,
                       width: dailyHeaderTitleWidth(size: 15), height: dailyHeaderTitleHeight),
                CGRect(x: size.width - side - dailyWindowControlInsets.right - 44, y: 0, width: 44, height: 44),
                foundation.left, foundation.right
            ])
    }

    func dailyFoundationHeader(size: CGSize, safe: CGFloat, foundation: DailyLayoutMetrics.Foundation) -> some View {
        let plan = dailyPalettePlan(size: size, safe: safe, foundation: foundation)
        return DailyTemplateHeader(size: size, safe: safe, foundation: foundation, plan: plan,
            targets: templatePaletteKeys, chineseEightBall: dailyPaletteGame == .chineseEightBall,
            titleWidth: dailyHeaderTitleWidth(size: 15), titleHeight: dailyHeaderTitleHeight,
            windowControlInsets: dailyWindowControlInsets, fps: dailyFPSReadout,
            showsDeviceStatus: !dailySystemStatusVisible,
            title: { dailyHeaderTitle(compact: false) },
            actions: { dailyHeaderActions(compact: false).disabled(isTemporaryTopDown) },
            ball: { key, diameter, height in dailyPaletteBall(key, diameter: diameter, slotHeight: height) },
            paletteMarker: { templateFrameReader("palette") })
        .background(DailyWindowControlInsets { controls, window, statusVisible in
            dailyWindowControlInsets = controls
            dailyWindowSafeAreaInsets = window
            dailySystemStatusVisible = statusVisible
        }.allowsHitTesting(false))
        .background {
            HStack {
                dailyHeaderTitleText(compact: false).fixedSize()
                    .background(GeometryReader { text in
                        Color.clear.preference(key: DailyHeaderTitleWidthsKey.self, value: [15: text.size.width])
                            .preference(key: DailyHeaderTitleHeightKey.self, value: text.size.height)
                    })
            }.hidden().allowsHitTesting(false).accessibilityHidden(true)
        }
        .onPreferenceChange(DailyHeaderTitleHeightKey.self) { height in
            if height.isFinite, height > 0 { dailyHeaderTitleHeight = height }
        }
        .onPreferenceChange(DailyHeaderTitleWidthsKey.self) { value in
            if let width = value[15], width.isFinite, width > 0 { dailyHeaderTitleWidths[15] = width }
        }
    }

    @ViewBuilder func dailyLandscapeHeader(size: CGSize, leadingAllowance: CGFloat, trailingShift: CGFloat) -> some View {
        let headerSize = dailyHeaderAuditSize(size, leadingAllowance: leadingAllowance, trailingShift: trailingShift)
        let plan = DailyLayoutMetrics.Header(width: headerSize.width,
            targetCount: templatePaletteKeys.count,
            separators: dailyPaletteGame == .chineseEightBall ? 10 : 0,
            regularTitleWidth: dailyHeaderTitleWidth(size: 15), compactTitleWidth: dailyHeaderTitleWidth(size: 13),
            leadingAllowance: leadingAllowance, trailingExtension: trailingShift)
        Group {
            if plan.presentation == .fullRow {
                dailyFullHeader(size: headerSize, trailingShift: trailingShift, plan: plan)
            } else if plan.presentation == .scrolling {
                dailyScrollingHeader(plan: plan)
            } else {
                HStack(spacing: Spacing.sm) {
                    dailyHeaderTitle(compact: true, showsTitle: false)
                    Text("请扩大窗口").font(.btFootnote)
                    Spacer(minLength: 0)
                }
            }
        }
        .foregroundStyle(.btText)
        .buttonStyle(BTHUDPressStyle())
        .frame(width: headerSize.width + trailingShift, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topLeading) {
            // Measure the same SwiftUI fonts used by the visible title. UIFont's
            // NSString estimate differs from Text at exact capacity boundaries.
            HStack(spacing: 0) {
                ForEach([15, 13], id: \.self) { size in
                    dailyHeaderTitleText(compact: size == 13)
                        .fixedSize()
                        .background(GeometryReader { title in
                            Color.clear.preference(key: DailyHeaderTitleWidthsKey.self,
                                                   value: [size: title.size.width])
                        })
                }
            }
            .hidden().allowsHitTesting(false).accessibilityHidden(true)
        }
        .onPreferenceChange(DailyHeaderTitleWidthsKey.self) { widths in
            let valid = widths.filter { $0.value.isFinite && $0.value > 0 }
            if !valid.isEmpty, valid != dailyHeaderTitleWidths { dailyHeaderTitleWidths = valid }
        }
        #if DEBUG
        .background {
            if ProcessInfo.processInfo.arguments.contains("-dailyLayout.probe") {
                Color.clear.accessibilityElement()
                    .accessibilityIdentifier("dailyLayout.headerProbe")
                    .accessibilityValue("proposal=\(headerSize.width) style=\(plan.style) presentation=\(plan.presentation) palette=\(plan.paletteWidth) shift=\(plan.titleShift) title15=\(dailyHeaderTitleWidth(size: 15)) title13=\(dailyHeaderTitleWidth(size: 13)) targetViewport=\(plan.targetViewportWidth) regularThreshold=\(dailyRegularHeaderThreshold(leadingAllowance: leadingAllowance, trailingShift: trailingShift)) displayScale=\(displayScale)")
            }
        }
        #endif
    }

    /// Explicit controlled-header host, not evidence of an iPad system resize.
    /// It leaves the scene/stage proposal unchanged and is absent in release.
    func dailyRegularHeaderThreshold(leadingAllowance: CGFloat, trailingShift: CGFloat) -> CGFloat {
        DailyLayoutMetrics.Header.minimumWidth(
            targetCount: templatePaletteKeys.count,
            separators: dailyPaletteGame == .chineseEightBall ? 10 : 0, style: .regular,
            titleWidth: dailyHeaderTitleWidth(size: 15), leadingAllowance: leadingAllowance,
            trailingExtension: trailingShift)
    }

    func dailyHeaderAuditSize(_ size: CGSize, leadingAllowance: CGFloat, trailingShift: CGFloat) -> CGSize {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-dailyLayout.headerAudit") {
            if ProcessInfo.processInfo.arguments.contains("-dailyLayout.headerBoundaryAudit") {
                let step = dailyHeaderAuditStep % 7
                if (1...5).contains(step) {
                    let threshold = dailyRegularHeaderThreshold(leadingAllowance: leadingAllowance, trailingShift: trailingShift)
                    let pixel = 1 / max(displayScale, 1)
                    let offsets: [CGFloat] = [-1, -pixel, 0, pixel, 1]
                    return CGSize(width: min(threshold + offsets[step - 1], size.width), height: size.height)
                }
            } else if !dailyHeaderAuditStep.isMultiple(of: 2) {
                return CGSize(width: min(480, size.width), height: size.height)
            }
        }
        #endif
        return size
    }

    /// Before the first measurement, four CJK ems retain the qualified baseline
    /// budget. Subsequent capacity decisions use Text's actual ideal width.
    func dailyHeaderTitleWidth(size: CGFloat) -> CGFloat {
        let width = dailyHeaderTitleWidths[Int(size)] ?? 4 * size
        // Keep the template's four-character title budget for shorter wrapped lines,
        // so the palette does not grow into the shared time/battery/FPS region.
        return dailyHeaderTitleIsMultiline ? max(4 * size, width) : width
    }

    private var dailyHeaderTitleLabel: String {
        isShotSimulation ? "分离角\n与走位" : pageTitle
    }

    private var dailyHeaderTitleIsMultiline: Bool {
        dailyHeaderTitleLabel.contains("\n")
    }

    func dailyHeaderTitleText(compact: Bool) -> some View {
        // An intentional line break does not trigger minimumScaleFactor.
        // Two-line titles use a smaller token while retaining the width budget.
        let font: Font = dailyHeaderTitleIsMultiline
            ? (compact ? .btCaption : .btFootnote)
            : (compact ? .btFootnote : .btSubheadline)
        return Text(dailyHeaderTitleLabel)
            .accessibilityLabel(pageTitle)
            .font(font.weight(.semibold))
    }

    func dailyFullHeader(size: CGSize, trailingShift: CGFloat, plan: DailyLayoutMetrics.Header) -> some View {
        let compact = plan.style == .compact
        let paletteWidth = plan.paletteWidth
        let wing = (size.width - paletteWidth) / 2
        let titleShift = plan.titleShift
        return HStack(spacing: 0) {
            dailyHeaderTitle(compact: compact, preservesBaselineTextFit: !compact)
                .padding(.trailing, Spacing.xs)
                .frame(width: wing + titleShift, alignment: .leading)
                .offset(x: -titleShift, y: 3)
                .frame(width: wing, alignment: .leading)
            GeometryReader { palette in
                dailyLandscapePalette(diameter: plan.style.diameter)
                    .frame(width: paletteWidth, height: 44)
                    .offset(y: dailyPaletteDrop(headerFrame: palette.frame(in: .global)))
            }
            .frame(width: paletteWidth, height: 44)
            dailyHeaderActions(compact: compact)
                .disabled(isTemporaryTopDown)
                .offset(y: 3)
                .frame(width: wing + trailingShift, alignment: .trailing)
        }
    }

    func dailyHeaderTitle(compact: Bool, showsTitle: Bool = true,
                      preservesBaselineTextFit: Bool = false) -> some View {
        HStack(spacing: -12) {
            Button {
                vm.cancelPowerRelease()
                dismiss()
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background { BTHUDControlBackground(shape: Capsule(), normal: .clear) }
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("返回")
            .accessibilityIdentifier("dailyClearance.back")
            if showsTitle {
                dailyHeaderTitleText(compact: compact)
                    .lineLimit(dailyHeaderTitleIsMultiline ? 2 : 1)
                    // Capacity limits fitting to the baseline's existing 2pt.
                    // Keep the original Text rasterization/fitting behavior.
                    .minimumScaleFactor(preservesBaselineTextFit ? 0.7 : 1)
            }
        }
        .fixedSize(horizontal: !preservesBaselineTextFit, vertical: false)
    }

    func dailyHeaderActions(compact: Bool) -> some View {
        moreMenu.buttonStyle(BTHUDPressStyle()).font(.system(size: 22, weight: .medium))
            .frame(width: 44, height: 44)
            .overlay(Circle().stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
    }

    func dailyScrollingHeader(plan: DailyLayoutMetrics.Header) -> some View {
        HStack(spacing: Spacing.xs) {
            dailyHeaderTitle(compact: true, showsTitle: plan.showsTitle)
                .frame(width: plan.leadingWidth, alignment: .leading)
            dailyPaletteBall(PositionPlayBall.cueKey, diameter: plan.style.diameter,
                             slotWidth: DailyLayoutMetrics.Header.overflowSlotWidth)
                .padding(.horizontal, Spacing.xs)
                .background { dailyPaletteBackground }
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(dailyPaletteKeys.filter { !PositionPlayBall.isCue($0) }, id: \.self) { key in
                        HStack(spacing: 0) {
                            if dailyPaletteSectionStart(key) {
                                Rectangle().fill(HUDStyle.hairline).frame(width: 1, height: 18)
                                    .padding(.horizontal, 2).accessibilityHidden(true)
                            }
                            dailyPaletteBall(key, diameter: plan.style.diameter,
                                             slotWidth: DailyLayoutMetrics.Header.overflowSlotWidth)
                        }
                    }
                }
                .padding(.horizontal, Spacing.xs)
            }
            .scrollIndicators(.hidden)
            .frame(width: plan.targetViewportWidth, height: 44)
            .background { dailyPaletteBackground }
            .clipped()
            .contentShape(Rectangle())
            .accessibilityIdentifier("dailyClearance.scrollingPalette")
            dailyHeaderActions(compact: true)
                .fixedSize(horizontal: true, vertical: false)
                .disabled(isTemporaryTopDown)
        }
        .offset(y: 3)
    }

    func dailyCompactAction(_ title: String, symbol: String, id: String, size: CGFloat = 44,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                if symbol == "triangle" { BreakRackGlyph(color: .btText, size: 22) }
                else { Image(systemName: symbol).font(.system(size: 18, weight: .medium)) }
                Text(title).font(.btMicro)
            }
            .btHUDActionContent()
            .frame(width: size, height: size)
            .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: BTRadius.md)) }
            .overlay(RoundedRectangle(cornerRadius: BTRadius.md)
                .stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
            .contentShape(Rectangle())
        }
        .buttonStyle(BTHUDPressStyle())
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
    }

    var dailyPaletteGame: DailyClearanceGame {
        !isDailyClearance ? .chineseEightBall : (dailyController.game ?? preferences.dailyClearanceGame)
    }

    var dailyPaletteKeys: [String] { !isDailyClearance ? PositionPlayBall.allKeys : dailyPaletteGame.paletteKeys }
    var templatePaletteKeys: [String] { dailyPaletteKeys.filter { !PositionPlayBall.isCue($0) } }

    func dailyPaletteActive(_ key: String) -> Bool {
        if editablePalette { return !PositionPlayBall.isCue(key) && vm.onTableKeys.contains(key) }
        if isStandard {
            guard !vm.isBreakMode, vm.onTableKeys.contains(key) else { return false }
            return rules?.legalTargetKeys(tableKeys: Set(vm.onTableKeys)).contains(key) ?? false
        }
        guard !vm.isBreakMode, !isDailyResult,
              dailyController.game != .chineseEightBall || dailyController.assignedGroup != nil else { return false }
        return dailyController.legalTargetKeys(tableKeys: Set(vm.onTableKeys)).contains(key)
    }

    func dailyPaletteSectionStart(_ key: String) -> Bool {
        dailyPaletteGame == .chineseEightBall && ["_8", "_9"].contains(key)
    }

    func dailyLandscapePalette(diameter: CGFloat) -> some View {
        let cueWidth = diameter + 2 + 2 * Spacing.xs
        return HStack(spacing: Spacing.xs) {
            dailyPaletteBall(PositionPlayBall.cueKey, diameter: diameter)
                .padding(.horizontal, Spacing.xs)
                .background { dailyPaletteBackground }
            HStack(spacing: 0) {
                ForEach(dailyPaletteKeys.filter { !PositionPlayBall.isCue($0) }, id: \.self) { key in
                    HStack(spacing: 0) {
                        if dailyPaletteSectionStart(key) {
                            Rectangle().fill(HUDStyle.hairline).frame(width: 1, height: 18)
                                .padding(.horizontal, 2).accessibilityHidden(true)
                        }
                        dailyPaletteBall(key, diameter: diameter)
                    }
                }
            }
            .padding(.horizontal, Spacing.xs)
            .background { dailyPaletteBackground }
            // A matching empty wing keeps the target row centered for every game.
            Color.clear.frame(width: cueWidth, height: 44)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear.accessibilityElement()
            .accessibilityIdentifier("dailyClearance.singleRowPalette"))
    }

    var dailyPaletteBackground: some View {
        Capsule().fill(HUDStyle.controlBackground)
            .overlay(Capsule().stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
            .frame(height: 34)
            .allowsHitTesting(false)
    }

    func dailyPaletteBall(_ key: String, diameter: CGFloat, slotWidth: CGFloat? = nil, slotHeight: CGFloat = 44) -> some View {
        let onTable = vm.onTableKeys.contains(key)
        return Button {
            editor?.onInteraction()
            if editablePalette {
                if onTable { vm.pulseTableBall(key) }
                else if is3D { flash("切到2D摆球", tone: .info) }
                else { placeSimulationBall(key, world: nil) }
            } else if onTable {
                if PositionPlayBall.isCue(key) { vm.pulseTableBall(key) }
                if let node = vm.scene.allBallNodes[key] { handleTargetTap(node) }
            } else { flash("这颗球已进袋", tone: .warning) }
        } label: {
            PoolBallFace(key: key, diameter: diameter)
                .opacity(editablePalette ? (onTable ? 0.3 : 1) : (onTable ? 1 : 0.25))
                .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1)
                    .padding(-1).opacity(onTable && vm.selectedTargetKey == key ? 1 : 0))
                .frame(width: slotWidth ?? diameter + 2, height: min(max(32, diameter), slotHeight))
                .background {
                    let targets = templatePaletteKeys
                    let isEnd = key == targets.first || key == targets.last
                    BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: isEnd ? 16 : 4),
                        selected: onTable && dailyPaletteActive(key), normal: .clear)
                }
                .frame(height: slotHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(BTHUDPressStyle())
        .disabled(sequenceReadOnly || vm.isPlaying || vm.isBreakMode || dailyDecisionActive || !dailyController.breakChoices.isEmpty || isTemporaryTopDown)
        .accessibilityLabel(PositionPlayBall.isCue(key) ? "母球" : "\(PositionPlayBall.shortLabel(for: key))号球")
        .accessibilityValue(vm.isBreakMode ? "开球准备，不可选" : (onTable ? (dailyPaletteActive(key) ? "本轮可击打" : "在桌上") : (editablePalette ? "未在桌上" : "已进袋")))
        .accessibilityIdentifier("paletteBall_\(key)")
        .accessibilityHint(editablePalette ? (is3D ? "切到2D摆球" : "点按或拖到台面摆球，拖回球库移除") : "")
        .simultaneousGesture(simulationPaletteDrag(key), including: editablePalette && !is3D && !onTable ? .all : .subviews)
    }

    func dailySpinPadRect(in size: CGSize) -> CGRect {
        let halfLength = vm.scene.cameraRig?.tableOuterHalfLength ?? CameraRig.defaultTableOuterHalfLength
        let halfWidth = vm.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth
        let rotated = dailyPortrait
        guard let scale = CameraRig.landscapeOrthographicScale(viewSize: size,
            halfLength: rotated ? halfWidth : halfLength, halfWidth: rotated ? halfLength : halfWidth) else { return .zero }
        let points = size.height / CGFloat(2 * scale)
        let width = CGFloat(rotated ? AngleSceneCalculator.innerWidth : AngleSceneCalculator.innerLength) * points
        let height = CGFloat(rotated ? AngleSceneCalculator.innerLength : AngleSceneCalculator.innerWidth) * points
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    var dailyControlsDisabled: Bool {
        sequenceReadOnly || isTemporaryTopDown || dailyDecisionActive || vm.isPlaying || isDailyResult || !dailyController.breakChoices.isEmpty || (vm.breakRunner.map { $0.phase != .racked } ?? false)
    }

    private var usesMergedCamera: Bool { vm.scene.cameraRig?.usesMergedCamera == true }

    private var usesDailyTwoViewControls: Bool {
        usesCoreTemplate && vm.scene.cameraRig?.usesTwoViewCameraControls == true
    }

    private var isTemporaryTopDown: Bool {
        usesDailyTwoViewControls && vm.temporaryTopDownActive
    }

    private var dailyTwoViewAutomaticEntryCount: Int {
        #if DEBUG
        return vm.twoViewAutomaticThirdPersonEntryCount
        #else
        return 0
        #endif
    }

    private var dailyTwoViewSolverDiagnostics: String {
        #if DEBUG
        let completed = Int(vm.entryTiming["completedSolves", default: 0])
        return " dailyShotCount=\(dailyController.shotCount) livePreviewDuringDrag=\(Int(vm.entryTiming["livePreviewDuringDrag", default: 0])) livePreviewDeliveries=\(Int(vm.entryTiming["livePreviewDeliveries", default: 0])) twoViewCompletedSolves=\(completed) twoViewComputing=\(vm.isComputing) twoViewCameraBusy=\(vm.cameraTransitionBusy) twoViewFeasible=\(vm.isFeasible) mergedTarget=\(vm.selectedTargetKey ?? "none") mergedPocket=\(vm.selectedPocketIndex) mergedCuePlacement=\(dailyController.cuePlacement)"
        #else
        return ""
        #endif
    }

    #if DEBUG
    func dailyControlsProbe(stageHeight: CGFloat, controls: DailyLayoutMetrics.Controls,
                            foundation: DailyLayoutMetrics.Foundation? = nil) -> String {
        let aim = vm.currentPlayerAim
        let range = vm.isBreakMode ? BreakFlowRunner.breakVelocityRange : ShotTuning.velocityRange
        return "stageHeight=\(stageHeight) instrumentHeight=\(dailyInstrumentHeight) controlsVerticalPadding=\(foundation == nil ? controls.verticalPadding : 0) controlsFit=\(foundation?.fits ?? controls.fitsWithoutPadding) minimumRequiredHeight=\(foundation?.left.height ?? controls.minimumRequiredHeight) horizontalActions=\(foundation?.horizontalActions ?? controls.horizontalActions) rulerHeight=\(foundation?.rulerLength ?? DailyLayoutMetrics.rulerHeight) aimX=\(aim.map { String(format: "%.8f", $0.x) } ?? "nil") aimZ=\(aim.map { String(format: "%.8f", $0.z) } ?? "nil") velocityMin=\(range.lowerBound) velocityMax=\(range.upperBound) velocity=\(dailyVelocity.wrappedValue) spinX=\(dailySpinX.wrappedValue) spinY=\(dailySpinY.wrappedValue) showAimCloseup=\(preferences.showAimCloseup) phase=\(dailyController.phase?.rawValue ?? "none") game=\(dailyController.game?.rawValue ?? "none") breakChoiceCount=\(dailyController.breakChoices.count) cuePlacement=\(dailyController.cuePlacement) dailyShotCount=\(dailyController.shotCount)"
    }
    #endif

    var dailyVelocity: Binding<Double> {
        Binding(get: { vm.breakRunner?.velocity ?? vm.velocity }, set: { value in
            if let runner = vm.breakRunner { runner.velocity = value }
            else { vm.velocity = value }
        })
    }

    func updateDailySpin(_ x: Double, _ y: Double) {
        guard !sequenceReadOnly else { return }
        vm.cancelPowerRelease()
        if let runner = vm.breakRunner {
            runner.spinX = x
            runner.spinY = y
        } else {
            vm.updateSpin(x: x, y: y)
        }
    }

    var dailySpinX: Binding<Double> {
        Binding(get: { vm.breakRunner?.spinX ?? vm.spinX }, set: { value in
            vm.cancelPowerRelease()
            if let runner = vm.breakRunner { runner.spinX = value }
            else { vm.spinX = value }
        })
    }

    var dailySpinY: Binding<Double> {
        Binding(get: { vm.breakRunner?.spinY ?? vm.spinY }, set: { value in
            vm.cancelPowerRelease()
            if let runner = vm.breakRunner { runner.spinY = value }
            else { vm.spinY = value }
        })
    }

    @ViewBuilder var dailyLandscapeFeedback: some View {
        if dailyController.isCompleted {
            dailyCompletionBar
        } else if dailyController.phase == .failed {
            dailyFailureBar
        }
    }
}

struct DailyStrikeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.btText)
            .background(configuration.isPressed ? HUDStyle.selectedBackground : HUDStyle.controlBackground, in: Circle())
            .overlay(Circle().stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
            .contentShape(Circle())
    }
}

private struct DailyCameraReadableBoundsKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        if let next = nextValue() { value = next }
    }
}

private struct DailyCameraReadableFrameKey: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        if let next = nextValue() { value = next }
    }
}

private struct DailyCameraControlHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct DailyHeaderTitleWidthsKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private struct DailyInstrumentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct DailyStrikeFrameKey: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        if let next = nextValue(), !next.isNull, !next.isInfinite,
           next.width > 0, next.height > 0 { value = next }
    }
}

private struct DailyHeaderTitleHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
