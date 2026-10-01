import SwiftUI
import SceneKit

enum FreePlayEntryMode {
    case standard
    case dailyClearance
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

    @StateObject private var vm = PositionPlayViewModel()
    @StateObject private var dailyController = DailyClearanceController()
    @ObservedObject private var preferences = UserPreferences.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var resultActionHeight: CGFloat = 44
    @State private var hasAppeared = false
    @State private var dailyAimWheelIsDragging = false
    @State private var daily3DDiagnostics: Daily3DRenderDiagnostics?
    @State private var showSpinPad = false
    @State private var showBreakPicker = false
    @State private var showDailyGamePicker = false
    @State private var showDailyRerackConfirm = false
    @State private var showDailyBreakChoice = false
    @State private var showDailyGameChangeConfirm = false
    @State private var pendingDailyGame: DailyClearanceGame?

    #if DEBUG
    @State private var cameraPreviewProfile: CameraRig.DailyPreviewProfile = .classic
    @State private var cameraPreviewScenario = 0
    @State private var cameraPreviewSteady = false
    @State private var cameraPreviewExpanded = true
    private var showsCameraPreview: Bool {
        isDailyClearance && ProcessInfo.processInfo.arguments.contains("-dailyClearance.cameraPreview")
    }
    #endif

    @State private var projector = TableProjector()

    @State private var daily3DFeedbackTop: CGFloat?
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
    }

    private var isDailyClearance: Bool { entryMode == .dailyClearance }
    private var isDailyResult: Bool {
        isDailyClearance && (dailyController.isCompleted || dailyController.phase == .failed)
    }
    private var is3D: Bool { vm.cameraMode == .perspective3D }
    private var isDaily2D: Bool { isDailyClearance && !is3D }
    private var pageTitle: String { isDailyClearance ? "每日清台" : "自由击球" }

    var body: some View {
        pageBody
        #if DEBUG
        .overlay(alignment: .bottom) {
            if showsCameraPreview { dailyCameraPreviewControls }
        }
        .task {
            guard showsCameraPreview else { return }
            for _ in 0..<100 {
                if vm.scene.cameraRig != nil, dailyController.phase == .playing { break }
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
            }
            guard !Task.isCancelled, dailyController.phase == .playing else { return }
            loadDailyCameraPreviewScenario(0)
        }
        #endif
        .onChange(of: isDaily2D) { _, active in
            if active, vm.breakRunner?.showsConfirm == true { showDailyBreakChoice = true }
        }
        .overlay {
            Group {
                if isDailyClearance, showDailyBreakChoice || showDailyRerackConfirm {
                    dailyBreakChoice
                } else if isDailyClearance, !dailyController.breakChoices.isEmpty, !isDailyResult {
                    dailyRuleChoice
                } else if isDailyResult {
                    dailyLandscapeFeedback
                }
            }
            .frame(maxWidth: 460)
            .accessibilityAddTraits(.isModal)
        }
        .onChange(of: dailyController.phase) { previous, phase in
            updateDaily3DPlaybackDiagnostics()
            if phase == .manualRacked || phase == .autoBreaking { ruleNotices.clear() }
            if isDailyClearance, previous == .autoBreaking, phase == .playing {
                showDailyBreakChoice = true
            }
        }
        .onChange(of: vm.cameraMode) { _, mode in
            daily3DDiagnostics?.setPage(perspective: mode == .perspective3D)
        }
        .onChange(of: vm.isPlaying) { _, _ in
            updateDaily3DPlaybackDiagnostics()
        }
    }

    private var pageBody: some View {
        GeometryReader { geo in
            if isDailyClearance {
                // Extend the real header hit area, while the table keeps its original safe-area width.
                dailyLandscapeBody(size: geo.size, trailingSafeArea: geo.safeAreaInsets.trailing)
                    .frame(width: geo.size.width + geo.safeAreaInsets.trailing, alignment: .leading)
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
            if isDailyClearance { DailyTableOrientation(landscape: true) }
        }
        .ignoresSafeArea(.container, edges: isDailyClearance ? .bottom : [])
        .animation(BTMotion.springPanel, value: showSpinPad)
        .trainingBackgroundMusic()
        .btDarkToolChrome(pageTitle)
        .toolbar(isDailyClearance ? .hidden : .visible, for: .navigationBar)
        .statusBarHidden(isDailyClearance)
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
        .confirmationDialog(
            "切换玩法会放弃当前进度",
            isPresented: $showDailyGameChangeConfirm,
            titleVisibility: .visible
        ) {
            Button("取消", role: .cancel) { pendingDailyGame = nil }
            Button("放弃并切换", role: .destructive) {
                if let game = pendingDailyGame { dailyController.changeGame(game) }
                pendingDailyGame = nil
            }
        }
        .sheet(isPresented: $showBreakPicker) {
            BreakGamePickerSheet { game in
                pendingGame = game
                rules = nil
                vm.startBreakFlow(game: game, manualDeliver: true)
            }
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDailyGamePicker, onDismiss: {
            // A sheet and confirmation dialog cannot share the presenter during dismissal on iOS 17.
            if let game = pendingDailyGame {
                pendingDailyGame = nil
                selectDailyGame(game)
            }
        }) {
            dailyGamePicker
                .presentationDetents([.height(420)])
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
        .onChange(of: vm.breakRunner?.seed) { _, seed in
            // Removing the runner after delivery is not a request to refocus.
            if is3D, seed != nil, !isDailyClearance { ShotPlayCamera.focus(on: vm) }
        }
        .onChange(of: vm.breakRunner?.phase) { previous, phase in
            updateDaily3DPlaybackDiagnostics()
            if isDailyClearance, phase == .settled, vm.breakRunner?.showsConfirm == true {
                showDailyBreakChoice = true
            }
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
                #if DEBUG
                // Explicit diagnostics can override daily defaults without changing other pages.
                if isDailyClearance {
                    let args = ProcessInfo.processInfo.arguments
                    vm.scene.usesClothLightingPrototype = args.contains("-dailyClearance.clothPrototype")
                    if let index = args.firstIndex(of: "-dailyClearance.exposure"), args.indices.contains(index + 1),
                       let value = Double(args[index + 1]), value.isFinite, (-0.45 ... -0.05).contains(value) {
                        vm.scene.sceneExposureOffset = CGFloat(value)
                    }
                    if let index = args.firstIndex(of: "-dailyClearance.rendering"), args.indices.contains(index + 1),
                       let profile = MobileReferenceLighting.SpecializedProfile(rawValue: args[index + 1]) {
                        vm.scene.renderingProfile = profile
                    }
                }
                #endif
                vm.setupScene()
                vm.enablePlayerCameraControls()
                if isDailyClearance {
                    vm.cameraMode = .topDown2D
                    vm.usesAutomaticPocketFallback = true
                    vm.usesDailyShotRanking = true
                    vm.legalAimTargets = { keys in dailyController.legalTargetKeys(tableKeys: keys) }
                    vm.onAimModeNotice = { text in ruleNotices.show(text, tone: .info, priority: .mode) }
                    vm.onAimSelectionNotice = { text in ruleNotices.show(text, tone: .warning, priority: .selection) }
                } else {
                    vm.usesAutomaticPocketFallback = true
                    vm.legalAimTargets = { keys in rules?.legalTargetKeys(tableKeys: keys) ?? keys }
                    vm.onAimModeNotice = { ruleNotices.show($0, tone: .info, priority: .mode) }
                    vm.onAimSelectionNotice = { ruleNotices.show($0, tone: .warning, priority: .selection) }
                }
                vm.scene.setCameraMode(vm.cameraMode, animated: false)
                vm.onShotSettled = { facts in handleShotSettled(facts) }
                if isDailyClearance { vm.onShotWillStart = { dailyController.prepareShot() } }
                #if DEBUG
                if !isDailyClearance, ProcessInfo.processInfo.arguments.contains("-v63.freePlayScratch") {
                    vm.clearTable()
                    vm.toggleAimMode()
                    vm.placeFromPalette(PositionPlayBall.cueKey,
                        atWorld: SCNVector3(0, vm.scene.surfaceY + BallPhysics.radius, -0.45))
                    vm.velocity = 1.5
                    vm.handleTableTap(world: AngleSceneCalculator.pocketPositions(surfaceY: vm.scene.surfaceY)[4])
                    startGame(.chineseEightBall)
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
            daily3DDiagnostics?.setPage(visible: false)
            vm.cancelPowerRelease()
            dailyAimWheelIsDragging = false
            if isDailyClearance { dailyController.stop() }
        }
        .onChange(of: scenePhase) { _, phase in
            daily3DDiagnostics?.setPage(foreground: phase == .active)
            guard isDailyClearance else { return }
            if phase == .active { dailyController.resumeActivity() }
            else {
                vm.cancelPowerRelease()
                dailyAimWheelIsDragging = false
                dailyController.flushActivity()
            }
        }
        // 工具活跃度（契约 §5.3）：只记停留时长，⛔ 不记引擎进袋结果。
        .toolUsageSession(isDailyClearance ? .dailyClearance : .freePlay)
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
                        if isDailyClearance { requestDailyRerack() }
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
        if isDailyClearance {
            guard let ruling = dailyController.handleShotSettled(facts) else { return }
            if ruling.completed || ruling.failed { ruleNotices.clear() }
            else if ruling.message != "继续击球" {
                ruleNotices.show(ruling.message, tone: ruling.foul ? .warning : .info, priority: .ruling)
            }
            return
        }
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
            onPocketTapped: vm.isBreakMode || vm.isPlaying || isDailyResult ? nil : { vm.selectPocket(at: $0) },
            // P10.1 禁止摆球：非开球模式仅母球可拖（自由球/走位微调）；开球模式拖开球区母球。
            draggableBallNodes: vm.isPlaying || isDailyResult
                || (isDailyClearance && !vm.isBreakMode && dailyController.cuePlacement == .none)
                ? [] : (vm.breakRunner?.draggableCue ?? vm.draggableCueOnly),
            onDragBegan: { node in
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
            selectableBallNodes: vm.isBreakMode || vm.isPlaying || isDailyResult ? [] :
                (isDailyClearance && is3D ? vm.selectableBalls + vm.draggableCueOnly : vm.selectableBalls),
            onBallTapped: { node in handleTargetTap(node) },
            onTableTapped: is3D || isDailyResult ? nil : { if !vm.isBreakMode { vm.handleTableTap(world: $0) } },
            onAimNudged: is3D || isDailyResult ? nil : {
                if let runner = vm.breakRunner { runner.nudgeAim(byDegrees: $0) }
                else { vm.nudgeFreeAim(byDegrees: $0) }
            },
            onAimDragActiveChanged: { vm.setAimTableDragging($0) },
            projector: projector,
            contentIsAnimating: vm.isPlaying || (vm.breakRunner?.isBusy ?? false)
                || (isDailyClearance && dailyAimWheelIsDragging),
            daily3DDiagnostics: daily3DDiagnostics,
            fpsReadoutTrailingInset: fpsTrailingInset
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .allowsHitTesting(!isDailyClearance || (!showDailyBreakChoice && !showDailyRerackConfirm && dailyController.breakChoices.isEmpty))
    }

    /// P10.2：按当前玩法规则拦截不合法目标球选择，并给出提示。
    private func handleTargetTap(_ node: SCNNode) {
        guard !vm.isBreakMode, !vm.isPlaying, !isDailyResult,
              let key = vm.scene.ballKey(for: node) else { return }
        if PositionPlayBall.isCue(key) {
            if isDailyClearance, is3D { vm.requestPlayerView(.firstPerson) }
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
            Text(aimModeLabel)
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
        !showDailyBreakChoice && !showDailyRerackConfirm && !isDailyResult && (!isDailyClearance || dailyController.breakChoices.isEmpty) && !vm.isPlaying && !vm.isComputing && !vm.cameraTransitionBusy && vm.isFeasible
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

    private var aimModeLabel: String { vm.aimMode == .pocket ? "进袋" : "自由" }

    private func trajectoryMenuLabel(_ detail: TrajectoryDetail) -> String {
        switch detail {
        case .full: return "全部"
        case .core: return "双球"
        case .minimal: return "瞄准线"
        }
    }

    @ViewBuilder private var dailySettings: some View {
        Section("击球设置") {
            Menu {
                Picker("瞄准模式", selection: Binding(
                    get: { vm.aimMode },
                    set: { mode in
                        guard mode != vm.aimMode else { return }
                        vm.toggleAimMode()
                    }
                )) {
                    Text("进袋").tag(PositionPlayViewModel.AimMode.pocket)
                    Text("自由").tag(PositionPlayViewModel.AimMode.free)
                }
            } label: {
                Label("瞄准模式 · \(aimModeLabel)", systemImage: "scope")
            }
            .accessibilityIdentifier("dailyClearance.aimModeMenu")

            Menu {
                Picker("轨迹显示", selection: Binding(
                    get: { preferences.trajectoryDetail },
                    set: { detail in
                        guard detail != preferences.trajectoryDetail else { return }
                        preferences.trajectoryDetail = detail
                        vm.recompute()
                    }
                )) {
                    ForEach(TrajectoryDetail.allCases, id: \.self) { detail in
                        Text(trajectoryMenuLabel(detail)).tag(detail)
                    }
                }
            } label: {
                Label("轨迹显示 · \(trajectoryMenuLabel(preferences.trajectoryDetail))",
                      systemImage: preferences.trajectoryDetail.systemImage)
            }
            .accessibilityIdentifier("dailyClearance.trajectoryMenu")
        }
        .disabled(vm.isPlaying || vm.isBreakMode || isDailyResult)
    }

    private var moreMenu: some View {
        // 页特有：对局中「结束对局」与「清空桌面」同 Section（G25 自由击打模板）。
        BTSolverMoreMenu(scene: vm.scene, accessibilityId: "freeplay.moreMenu", showsAimCloseupToggle: true, pageExtras: {
            if isDailyClearance { dailySettings }
            Section {
                if isDailyClearance {
                    Button("重新开球", systemImage: "arrow.counterclockwise") {
                        requestDailyRerack()
                    }
                    .disabled(dailyController.phase == .autoBreaking || dailyController.isCompleted)
                    .accessibilityIdentifier("dailyClearance.rerackMenu")

                    Button("临时换玩法", systemImage: "square.stack.3d.up") {
                        showDailyGamePicker = true
                    }
                    .accessibilityIdentifier("dailyClearance.changeGame")
                } else {
                    if rules != nil {
                        Button("结束对局", systemImage: "flag.checkered") {
                            endGame()
                            flash("对局已结束")
                        }
                    }
                    Button("清空桌面", systemImage: "trash") {
                        showClearTableConfirm = true
                    }
                }
            }
        })
    }

    private var dailyGamePicker: some View {
        NavigationStack {
            List(DailyClearanceGame.allCases) { game in
                Button {
                    pendingDailyGame = game
                    showDailyGamePicker = false
                } label: {
                    HStack {
                        Text(game.displayName)
                        Spacer()
                        if game == dailyController.game {
                            Image(systemName: "checkmark")
                                .foregroundStyle(HUDStyle.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier("dailyClearance.game.\(game.rawValue)")
            }
            .navigationTitle("本局玩法")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showDailyGamePicker = false }
                }
            }
        }
    }

    private var navigationStatusText: String {
        if isDailyClearance { return dailyController.statusText }
        if is3D, vm.breakRunner?.phase == .racked, vm.breakRunner?.simulationFailure == nil {
            return "刻度轮调方向 · 拖动母球摆位"
        }
        return vm.breakRunner?.statusText(isPerspective: is3D)
            ?? (vm.isComputing ? "求解中…"
                : (!vm.isPlaying && !rulingText.isEmpty ? rulingText : vm.statusText))
    }

    private func requestDailyRerack() {
        vm.cancelPowerRelease()
        showDailyRerackConfirm = true
    }

    private func selectDailyGame(_ game: DailyClearanceGame) {
        guard game != dailyController.game else { return }
        if dailyController.shotCount > 0, !dailyController.isCompleted {
            pendingDailyGame = game
            showDailyGameChangeConfirm = true
        } else {
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

    static let cameraPreviewScenarioNames = ["长台远球", "短距离球", "大角度球", "母球近库"]
    var cameraPreviewScenarioTitle: String { Self.cameraPreviewScenarioNames[cameraPreviewScenario] }

    func loadDailyCameraPreviewScenario(_ index: Int) {
        guard showsCameraPreview, !vm.isPlaying, let rig = vm.scene.cameraRig else { return }
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
            (SCNVector3(-1.229, 0, -0.40), SCNVector3(-0.40, 0, -0.03), 3)
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

private extension FreePlayView {
    var dailyControlColumnWidth: CGFloat { 60 }

    func dailyLandscapeBody(size: CGSize, trailingSafeArea: CGFloat) -> some View {
        let headerShift = min(24, max(0, trailingSafeArea))
        // Reserve the outer camera lane symmetrically when the safe area cannot hold it.
        let sideInset = max(0, 48 - trailingSafeArea)
        let sceneWidth = size.width - 2 * dailyControlColumnWidth - 4 * Spacing.xs - 2 * sideInset
        let sceneSize = CGSize(width: max(sceneWidth, 1), height: max(size.height - 44, 1))
        let rulerHeight = ShotStageMetrics.dailyPowerBarHeight
        return ZStack(alignment: .leading) {
            if is3D {
                sceneContainer(fpsTrailingInset: dailyControlColumnWidth + Spacing.xs + sideInset)
                    .ignoresSafeArea()
            }
            VStack(alignment: .leading, spacing: 0) {
                dailyLandscapeHeader(size: size, trailingShift: headerShift)
                    .frame(width: size.width + headerShift, height: 44)
                    .zIndex(1)
                HStack(spacing: Spacing.xs) {
                    dailyLeftControls(rulerHeight: rulerHeight, horizontalActions: sceneSize.height < rulerHeight + 214)
                    GeometryReader { stage in
                        ZStack {
                            if !is3D { sceneContainer() }
                            if !vm.isBreakMode && !isDailyResult {
                                BTAimCloseupOverlay(snapshot: vm.closeupSnapshot,
                                    sceneSize: stage.size, scene: vm.scene,
                                    safeInsets: .init(top: 0, leading: 0, bottom: 28, trailing: 0))
                            }
                            if showSpinPad {
                                let playingRect = dailySpinPadRect(in: stage.size)
                                BTSceneSpinPadOverlay(spinX: dailySpinX, spinY: dailySpinY, scene: vm.scene,
                                    tableWidth: playingRect.width,
                                    bottomPadding: stage.size.height - playingRect.maxY,
                                    onClose: { showSpinPad = false })
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .top) {
                            dailyFeedbackOverlay
                                .padding(.top, dailyFeedbackTop(in: stage))
                                .task(id: dailyFeedbackIdentity) {
                                    if is3D { daily3DFeedbackTop = projectedFeedbackTop(in: stage) }
                                }
                        }
                        .background(Color.clear.accessibilityElement()
                            .accessibilityIdentifier("freeplay.stage"))
                    }
                    dailyRightControls(rulerHeight: rulerHeight)
                }
                .padding(.horizontal, Spacing.xs + sideInset)
                .frame(width: size.width)
            }
            .frame(width: size.width + headerShift, alignment: .leading)
        }
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .coordinateSpace(name: "freeplay")
        .background(Color.clear.accessibilityElement()
            .accessibilityIdentifier("dailyClearance.landscape")
            .accessibilityLabel("每日清台状态")
            .accessibilityValue("\(is3D ? "3D" : "2D")，\(dailyController.visitSummary)，剩余 \(dailyController.remainingBallCount) 球，\(dailyController.foulCount) 次犯规，\(aimModeLabel)模式，目标\(vm.selectedTargetKey ?? "无")，袋口\(vm.selectedPocketIndex)"))
    }

    /// 2D uses the projected upper cushion in stage-local points; 3D keeps a stable HUD anchor.
    func dailyFeedbackTop(in stage: GeometryProxy) -> CGFloat {
        is3D ? (daily3DFeedbackTop ?? stage.size.height * 0.15) : projectedFeedbackTop(in: stage)
    }

    var dailyFeedbackIdentity: String {
        "\(is3D)-\(showDailyBreakChoice)-\(showDailyRerackConfirm)-\(isDailyResult)-\(dailyController.breakChoices)-\(ruleNotices.message?.text ?? "")"
    }

    func projectedFeedbackTop(in stage: GeometryProxy) -> CGFloat {
        let polygon = SpinPadRailAnchor.polygon(scene: vm.scene, projector: projector,
            stageOrigin: stage.frame(in: .global).origin, usesWindowCoordinates: true)
        guard let top = polygon.map(\.y).min(), top.isFinite else { return stage.size.height * 0.15 }
        return max(Spacing.sm, min(top + Spacing.md, stage.size.height / 3))
    }

    @ViewBuilder var dailyFeedbackOverlay: some View {
        VStack(spacing: Spacing.xs) {
            if showDailyBreakChoice || showDailyRerackConfirm || !dailyController.breakChoices.isEmpty {
                EmptyView()
            } else if !isDailyResult, !showSpinPad, let message = ruleNotices.message {
                BTNoticeContent(message: message, compact: true, textOnly: true)
                    .accessibilityIdentifier("dailyClearance.notice")
            }
        }
        .frame(maxWidth: 460)
        .padding(.horizontal, Spacing.sm)
        .accessibilityElement(children: .contain)
    }

    func dailyLeftControls(rulerHeight: CGFloat, horizontalActions: Bool) -> some View {
        VStack(spacing: 6) {
            Button(action: requestDailyRerack) {
                VStack(spacing: 2) {
                    BreakRackGlyph(color: .btText, size: 26)
                        .frame(width: 44, height: 44)
                        .background(HUDStyle.controlBackground, in: Circle())
                        .overlay(Circle().stroke(HUDStyle.hairline, lineWidth: 1))
                    Text("开球").font(.btMicro).foregroundStyle(.btTextSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("break.entry")
            .disabled(dailyController.isCompleted)
            VStack(spacing: 6) {
                BTAimWheel(onNudge: { delta in
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
                    }, visibleWidth: 28, usesCompactAppearance: true, showsDirectionLabel: false)
                    .frame(width: 44, height: rulerHeight)
                Text("方向").font(.btMicro).foregroundStyle(.btTextSecondary)
            }
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: BTRadius.xl).fill(HUDStyle.controlBackground)
                    .overlay(RoundedRectangle(cornerRadius: BTRadius.xl)
                        .stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                    .frame(width: 40)
            }
            .disabled(dailyControlsDisabled)
            if !horizontalActions { Spacer(minLength: 0) }
            let actionLayout = horizontalActions
                ? AnyLayout(HStackLayout(spacing: Spacing.xs))
                : AnyLayout(VStackLayout(spacing: Spacing.xs))
            actionLayout {
            dailyCompactAction("重打", symbol: "arrow.uturn.backward", id: "dailyClearance.undo") {
                daily3DDiagnostics?.input(.undo, intent: .aim)
                vm.cancelPowerRelease()
                dailyController.undoShot()
            }
            .disabled(vm.isPlaying || !dailyController.canUndo || isDailyResult)
            dailyCompactAction("回放", symbol: "play.rectangle", id: "dailyClearance.playback") {
                daily3DDiagnostics?.input(.replay)
                vm.cancelPowerRelease()
                vm.replayLastShot()
            }
            .disabled(vm.isPlaying || !vm.canPlayback)
            }
            .frame(width: horizontalActions ? 92 : 44)
            .frame(width: dailyControlColumnWidth, alignment: horizontalActions ? .trailing : .center)
            .frame(maxHeight: horizontalActions ? .infinity : nil, alignment: .center)
        }
        .frame(width: dailyControlColumnWidth)
        .padding(.vertical, Spacing.sm)
    }

    func dailyRightControls(rulerHeight: CGFloat) -> some View {
        VStack(spacing: Spacing.xs) {
            BTShotInstrumentColumn(spinX: dailySpinX.wrappedValue, spinY: dailySpinY.wrappedValue,
                onSpinTap: {
                    daily3DDiagnostics?.input(.spin, intent: .aim)
                    vm.cancelPowerRelease(); showSpinPad.toggle()
                },
                velocity: dailyVelocity,
                range: vm.isBreakMode ? BreakFlowRunner.breakVelocityRange : ShotTuning.velocityRange,
                isDisabled: dailyControlsDisabled,
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
                fixedPowerBarHeight: rulerHeight)
                .frame(width: 52)
            Button {
                daily3DDiagnostics?.input(.strike)
                vm.cancelPowerRelease()
                if let runner = vm.breakRunner { runner.breakNow() }
                else { vm.play() }
                if (vm.breakRunner?.statusText ?? vm.statusText) == CueStrikeAccess.unavailableMessage {
                    ruleNotices.show(CueStrikeAccess.unavailableMessage, tone: .warning, priority: .selection)
                }
            } label: {
                Text(dailyController.isAutomaticallyBreaking ? "开球中" : (vm.isComputing ? "计算中" : "击球")).font(.btSubheadlineSemibold)
                    .frame(width: dailyControlColumnWidth, height: dailyControlColumnWidth)
                    .background(HUDStyle.accent, in: Circle())
                    .overlay(Circle().stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
            }
            .foregroundStyle(HUDStyle.onAccent)
            .disabled(vm.isBreakMode ? dailyControlsDisabled : !strikeEnabled)
            .opacity((vm.isBreakMode ? dailyControlsDisabled : !strikeEnabled) ? 0.4 : 1)
            .accessibilityLabel("击球")
            .accessibilityHint("按下击球；力度条仅调整力度")
            .accessibilityIdentifier("dailyClearance.strike")
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(width: dailyControlColumnWidth)
        .padding(.vertical, Spacing.sm)
        .overlay(alignment: .topLeading) {
            if is3D, !showSpinPad, let rig = vm.scene.cameraRig {
                ShotPlayerCameraButtons(rig: rig,
                    isEnabled: !vm.isPlaying && !vm.isComputing && vm.currentPlayerAim != nil,
                    onWholeTable: {
                        daily3DDiagnostics?.input(.cameraButton, intent: .orbit)
                        observeWholeTableForPage()
                    }) { view in
                    daily3DDiagnostics?.input(.cameraButton, intent: .orbit)
                    showSpinPad = false
                    vm.requestPlayerView(view)
                }
                    // Header: 44pt icon + 2pt gap + 12pt label; then 6pt gap + 6pt inset.
                    // Three 44pt camera buttons plus two 8pt gaps are centered on the ruler.
                    .offset(x: dailyControlColumnWidth + Spacing.xs,
                            y: Spacing.sm + 58 + 12 + (rulerHeight - 148) / 2)
            }
        }
    }

    var dailyBreakChoice: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Button("重新开球") {
                    showDailyBreakChoice = false
                    showDailyRerackConfirm = false
                    ruleNotices.clear()
                    dailyController.confirmRerack()
                }
                .buttonStyle(BTSceneDecisionActionStyle())
                .accessibilityIdentifier("dailyClearance.rerackAfterBreak")
                Button(showDailyRerackConfirm ? "继续击球" : "完成") {
                    showDailyBreakChoice = false
                    showDailyRerackConfirm = false
                    ruleNotices.clear()
                    if vm.breakRunner?.showsConfirm == true { vm.breakRunner?.confirmSettled() }
                }
                .buttonStyle(BTSceneDecisionActionStyle(isPrimary: true))
                .accessibilityIdentifier("dailyClearance.confirmBreak")
            }
        }
    }

    var dailyRuleChoice: some View {
        VStack(spacing: Spacing.xs) {
            Text(dailyController.statusText).font(.btSubheadline)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.85), radius: 2, y: 1)
                .multilineTextAlignment(.center)
            ForEach(dailyController.breakChoices, id: \.self) { choice in
                Button(choice.label) {
                    ruleNotices.clear()
                    dailyController.resolveBreakChoice(choice)
                    vm.refreshLegalAimSelection()
                }
                .buttonStyle(BTSceneDecisionActionStyle(isPrimary: choice == dailyController.breakChoices.last))
                .accessibilityIdentifier("dailyClearance.ruleChoice.\(choice.rawValue)")
            }
        }
    }

    func observeWholeTableForPage() {
        if isDailyClearance {
            vm.scene.cameraRig?.observeWholeTable(yaw: .pi / 2)
            vm.scene.discardSavedPerspectiveView()
        } else {
            ShotPlayCamera.observeWholeTable(on: vm)
        }
    }

    func toggleDailyCamera() {
        let initialOverview = !is3D && !vm.scene.hasPerspectiveView
        ShotPlayCamera.setMode(is3D ? .topDown2D : .perspective3D, on: vm)
        if initialOverview {
            // Same long-rail overview convention used by the landscape drill scene.
            vm.scene.cameraRig?.observeWholeTable(yaw: .pi / 2)
            vm.scene.discardSavedPerspectiveView()
        }
    }

    func dailyLandscapeHeader(size: CGSize, trailingShift: CGFloat) -> some View {
        let compact = size.width < 740
        // Size the faces first; mirrored cue space only affects the surrounding layout.
        let diameter = dailyPaletteDiameter(width: size.width)
        let separators: CGFloat = dailyPaletteGame == .chineseEightBall ? 10 : 0
        let paletteWidth = CGFloat(dailyPaletteKeys.count + 1) * (diameter + 2) + 8 * Spacing.xs + separators
        let wing = (size.width - paletteWidth) / 2
        let titleShift: CGFloat = compact ? 2 : 12
        return HStack(spacing: 0) {
            // Tighten the visible title while retaining the return button's full hit area.
            HStack(spacing: -12) {
                Button {
                    vm.cancelPowerRelease()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("返回")
                .accessibilityIdentifier("dailyClearance.back")
                Text("每日清台").font(compact ? .btFootnote.weight(.semibold) : .btSubheadlineSemibold)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.trailing, Spacing.xs)
            .background {
                Capsule().fill(is3D ? HUDStyle.controlBackground : Color.clear)
                    .frame(height: 34)
            }
            .frame(width: wing + titleShift, alignment: .leading)
            .offset(x: -titleShift, y: 3)
            .frame(width: wing, alignment: .leading)
            dailyLandscapePalette(width: size.width)
                .frame(width: paletteWidth, height: 44)

            HStack(spacing: 0) {
                Group {
                    Button {
                        vm.cancelPowerRelease()
                        showSpinPad = false
                        toggleDailyCamera()
                    } label: {
                        HStack(spacing: 0) {
                            Text("2D").foregroundStyle(is3D ? Color.btTextSecondary : .white)
                                .frame(width: compact ? 30 : 44, height: 34)
                                .background(is3D ? Color.clear : HUDStyle.selectedBackground, in: Capsule())
                            Text("3D").foregroundStyle(is3D ? Color.white : .btTextSecondary)
                                .frame(width: compact ? 30 : 44, height: 34)
                                .background(is3D ? HUDStyle.selectedBackground : .clear, in: Capsule())
                        }
                        .font(.btFootnote.weight(.semibold))
                        .padding(3)
                        .background(HUDStyle.controlBackground, in: Capsule())
                        .overlay(Capsule().stroke(HUDStyle.hairline, lineWidth: 1))
                        .frame(height: 44)
                    }
                    .accessibilityLabel(is3D ? "切换到2D俯视" : "切换到3D视角")
                    .accessibilityValue(is3D ? "3D" : "2D")
                    .accessibilityIdentifier("freeplay.cameraMode")
                }
                moreMenu.font(.system(size: 22, weight: .medium)).frame(width: 44, height: 44)
                    .background(HUDStyle.controlBackground, in: Circle())
                    .overlay(Circle().stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
            }
            .frame(width: wing + trailingShift, alignment: .trailing)
        }
        .foregroundStyle(.btText)
        .buttonStyle(.plain)
    }

    func dailyCompactAction(_ title: String, symbol: String, id: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                if symbol == "triangle" { BreakRackGlyph(color: .btText, size: 22) }
                else { Image(systemName: symbol).font(.system(size: 18, weight: .medium)) }
                Text(title).font(.btMicro)
            }
            .frame(width: 44, height: 44)
            .background(HUDStyle.controlBackground, in: RoundedRectangle(cornerRadius: BTRadius.md))
            .overlay(RoundedRectangle(cornerRadius: BTRadius.md)
                .stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.btTextSecondary)
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
    }

    func dailyPaletteDiameter(width: CGFloat) -> CGFloat {
        // Larger faces on standard screens; SE keeps enough room for the title and controls.
        width < 740 ? 25 : 30
    }

    var dailyPaletteGame: DailyClearanceGame {
        dailyController.game ?? preferences.dailyClearanceGame
    }

    var dailyPaletteKeys: [String] { dailyPaletteGame.paletteKeys }

    func dailyPaletteActive(_ key: String) -> Bool {
        guard !vm.isBreakMode, !isDailyResult,
              dailyController.game != .chineseEightBall || dailyController.assignedGroup != nil else { return false }
        return dailyController.legalTargetKeys(tableKeys: Set(vm.onTableKeys)).contains(key)
    }

    func dailyPaletteSectionStart(_ key: String) -> Bool {
        dailyPaletteGame == .chineseEightBall && ["_8", "_9"].contains(key)
    }

    func dailyLandscapePalette(width: CGFloat) -> some View {
        let diameter = dailyPaletteDiameter(width: width)
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

    func dailyPaletteBall(_ key: String, diameter: CGFloat) -> some View {
        let onTable = vm.onTableKeys.contains(key)
        return Button {
            if onTable {
                vm.pulseTableBall(key)
                if let node = vm.scene.allBallNodes[key] { handleTargetTap(node) }
            } else { flash("这颗球已进袋", tone: .warning) }
        } label: {
            PoolBallFace(key: key, diameter: diameter)
                .opacity(onTable ? 1 : 0.25)
                .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1)
                    .padding(-1).opacity(onTable && vm.selectedTargetKey == key ? 1 : 0))
                .frame(width: diameter + 2, height: 32)
                .background {
                    let targets = dailyPaletteKeys.filter { !PositionPlayBall.isCue($0) }
                    let isEnd = key == targets.first || key == targets.last
                    RoundedRectangle(cornerRadius: isEnd ? 16 : 4)
                    .fill(onTable && dailyPaletteActive(key) ? HUDStyle.selectedBackground : Color.clear)
                }
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(vm.isPlaying || vm.isBreakMode || showDailyBreakChoice || showDailyRerackConfirm || !dailyController.breakChoices.isEmpty)
        .accessibilityLabel(PositionPlayBall.isCue(key) ? "母球" : "\(PositionPlayBall.shortLabel(for: key))号球")
        .accessibilityValue(onTable ? (dailyPaletteActive(key) ? "本轮可击打" : "在桌上") : "已进袋")
        .accessibilityIdentifier("paletteBall_\(key)")
    }

    func dailySpinPadRect(in size: CGSize) -> CGRect {
        ShotTableLayout.landscapePlayingRect(in: size,
            halfLength: vm.scene.cameraRig?.tableOuterHalfLength ?? CameraRig.defaultTableOuterHalfLength,
            halfWidth: vm.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth)
    }

    var dailyControlsDisabled: Bool {
        showDailyBreakChoice || showDailyRerackConfirm || vm.isPlaying || isDailyResult || !dailyController.breakChoices.isEmpty || (vm.breakRunner.map { $0.phase != .racked } ?? false)
    }

    var dailyVelocity: Binding<Double> {
        Binding(get: { vm.breakRunner?.velocity ?? vm.velocity }, set: { value in
            if let runner = vm.breakRunner { runner.velocity = value }
            else { vm.velocity = value }
        })
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
