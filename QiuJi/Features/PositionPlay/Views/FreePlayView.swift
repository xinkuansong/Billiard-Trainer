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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var resultActionHeight: CGFloat = 44
    @State private var hasAppeared = false
    @State private var showSpinPad = false
    @State private var showBreakPicker = false
    @State private var showDailyGamePicker = false
    @State private var showDailyRerackConfirm = false
    @State private var showDailyGameChangeConfirm = false
    @State private var pendingDailyGame: DailyClearanceGame?

    @State private var projector = TableProjector()

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
    private var pageTitle: String { isDailyClearance ? "每日清台" : "自由击球" }

    var body: some View {
        GeometryReader { geo in
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
        .animation(BTMotion.springPanel, value: showSpinPad)
        .btDarkToolChrome(pageTitle)
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
                moreMenu.accessibilityIdentifier("freeplay.moreMenu")
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
            "重新开球会放弃当前进度",
            isPresented: $showDailyRerackConfirm,
            titleVisibility: .visible
        ) {
            Button("取消", role: .cancel) {}
            Button("放弃并重新开球", role: .destructive) {
                dailyController.confirmRerack()
            }
        } message: {
            Text("本局杆数、犯规和用时将重新计算，今天已完成的记录不会被清除。")
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
        .sheet(isPresented: $showDailyGamePicker) {
            dailyGamePicker
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: vm.isBreakMode) { _, inBreak in
            if is3D, inBreak {
                if isDailyClearance && dailyController.isAutomaticallyBreaking {
                    ShotPlayCamera.observeWholeTable(on: vm)
                } else { ShotPlayCamera.focus(on: vm) }
            }
            // 开球「完成」交付击打阶段 → 按玩法启动规则对局（取消开球时 pendingGame 已清）。
            if !isDailyClearance, !inBreak, let game = pendingGame {
                pendingGame = nil
                startGame(game)
            }
        }
        .onChange(of: vm.breakRunner?.seed) { _, seed in
            // Removing the runner after delivery is not a request to refocus.
            if is3D, seed != nil {
                if isDailyClearance && dailyController.isAutomaticallyBreaking {
                    ShotPlayCamera.observeWholeTable(on: vm)
                } else { ShotPlayCamera.focus(on: vm) }
            }
        }
        .onChange(of: vm.breakRunner?.phase) { previous, phase in
            // A single framing request at the shot boundary; subsequent playback,
            // settle and user gestures retain ownership of the current camera.
            if is3D, previous == .racked,
               phase == .computing || phase == .breaking {
                ShotPlayCamera.observeWholeTable(on: vm)
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
                vm.scene.setCameraMode(vm.cameraMode, animated: false)
                vm.onShotSettled = { facts in handleShotSettled(facts) }
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
                    // Completion records contain totals, not a resumable board.
                    // Do not present the scene's initialization example as that game.
                    if dailyController.isCompleted { vm.clearTable() }
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-dailyClearance.fixture=scratch") {
                        vm.toggleAimMode()
                        vm.handleTableTap(world: AngleSceneCalculator.pocketPositions(surfaceY: vm.scene.surfaceY)[4])
                    }
                    #endif
                }
            }
        }
        .onDisappear {
            if isDailyClearance { dailyController.stop() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard isDailyClearance else { return }
            if phase == .active { dailyController.resumeActivity() }
            else { dailyController.flushActivity() }
        }
        // 工具活跃度（契约 §5.3）：只记停留时长，⛔ 不记引擎进袋结果。
        .toolUsageSession(isDailyClearance ? .dailyClearance : .freePlay)
    }

    // MARK: - Stage（scene + 贴边控件，G3–G11）

    private func stage(_ proxy: ShotStageProxy) -> some View {
        ZStack(alignment: .topLeading) {
            sceneContainer

            // G18/V6：开球模式贴边仪表（左瞄准轮 + 右力度柱，默认 6 m/s），共享单一真源。
            if let runner = vm.breakRunner {
                BreakInstrumentsOverlay(runner: runner, proxy: proxy, isPerspective: is3D)
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

                // G4/G5/G7 瞄准刻度轮（自由模式）：右缘贴球桌左侧、底部对齐。
                if vm.aimMode == .free {
                    BTAimWheel(
                        onNudge: { vm.nudgeFreeAim(byDegrees: $0) },
                        degreesPerPoint: vm.aimWheelDegreesPerPoint,
                        degreeHapticEnabled: false,
                        onDragActiveChanged: { vm.setAimWheelDragging($0) }
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
                BTSpinPadOverlay(spinX: $vm.spinX, spinY: $vm.spinY,
                                 tableWidth: is3D ? proxy.sceneSize.width - Spacing.lg * 2 : proxy.playingRect.width,
                                 bottomPadding: is3D ? Spacing.sm : proxy.spinPadBottomPadding,
                                 usesCompactLayout: is3D,
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
            flash(ruling.message, tone: ruling.failed ? .warning : .success)
            if ruling.ballInHand, !ruling.failed {
                flash(is3D ? "自由球：切回2D拖放母球" : "自由球：可任意拖放母球")
            }
            return
        }
        guard let rules else { return }
        let ruling = rules.judge(facts)
        refreshRulesHUD(message: ruling.message)
        if ruling.ballInHand, !ruling.gameOver {
            flash("自由球：可任意拖放母球")
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

    private var sceneContainer: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            interactionMode: is3D ? .cameraControl : .tapsOnly,
            autoFitsRotatedTable: !is3D,
            onPocketTapped: vm.isBreakMode || vm.isPlaying || isDailyResult ? nil : { vm.selectPocket(at: $0) },
            // P10.1 禁止摆球：非开球模式仅母球可拖（自由球/走位微调）；开球模式拖开球区母球。
            draggableBallNodes: is3D || isDailyResult ? [] : (vm.breakRunner?.draggableCue ?? vm.draggableCueOnly),
            onDragBegan: { node in
                if let runner = vm.breakRunner { runner.dragBegan(node: node) }
                else { vm.dragBegan(node: node) }
            },
            onDragMoved: { node, world in
                if let runner = vm.breakRunner {
                    runner.dragMoved(node: node, worldPosition: world)
                } else {
                    vm.dragMoved(node: node, worldPosition: world)
                }
            },
            onDragEnded: { node in
                if let runner = vm.breakRunner { runner.dragEnded(node: node) }
                else { vm.dragEnded(node: node) }
            },
            selectableBallNodes: vm.isBreakMode || isDailyResult ? [] : vm.selectableBalls,
            onBallTapped: { node in handleTargetTap(node) },
            onTableTapped: is3D || isDailyResult ? nil : { if !vm.isBreakMode { vm.handleTableTap(world: $0) } },
            onAimNudged: is3D || isDailyResult ? nil : {
                if let runner = vm.breakRunner { runner.nudgeAim(byDegrees: $0) }
                else { vm.nudgeFreeAim(byDegrees: $0) }
            },
            onAimDragActiveChanged: { vm.setAimTableDragging($0) },
            projector: projector,
            contentIsAnimating: vm.isPlaying || (vm.breakRunner?.isBusy ?? false)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    /// P10.2：按当前玩法规则拦截不合法目标球选择，并给出提示。
    private func handleTargetTap(_ node: SCNNode) {
        guard !vm.isBreakMode else { return }
        if vm.aimMode == .pocket, let key = vm.scene.ballKey(for: node),
           !PositionPlayBall.isCue(key) {
            let tableTargets = Set(vm.onTableKeys.filter { $0 != PositionPlayBall.cueKey })
            let legal: Set<String>
            if isDailyClearance {
                legal = dailyController.legalTargetKeys(tableKeys: tableTargets)
            } else if let rules {
                legal = rules.legalTargetKeys(tableKeys: tableTargets)
            } else {
                legal = []
            }
            guard !legal.isEmpty else {
                vm.selectTarget(node: node)
                return
            }
            if !legal.contains(key) {
                flash("按当前规则不能打 \(PositionPlayBall.shortLabel(for: key)) 号球", tone: .warning)
                return
            }
        }
        vm.selectTarget(node: node)
    }

    // MARK: - Top info row

    private var topInfoRow: some View {
        HStack(spacing: Spacing.sm) {
            if vm.isBreakMode {
                isDailyClearance ? AnyView(dailyBreakModePill) : AnyView(breakModePill)
            } else {
                BTAimModeToggleButton(isFree: vm.aimMode == .free,
                                      isDisabled: vm.isPlaying || isDailyResult) {
                    vm.toggleAimMode()
                }
                .fixedSize(horizontal: true, vertical: false)

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
                        .font(.system(size: 12, weight: .semibold))
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
            BreakRackGlyph(color: .btPrimary, size: 13)
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
            BreakRackGlyph(color: .btPrimary, size: 13)
            Text(dailyController.game?.displayName ?? preferences.dailyClearanceGame.displayName)
            BTHudMetricSeparator()
            if dailyController.isAutomaticallyBreaking {
                ProgressView().controlSize(.mini).tint(.btPrimary)
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
                .foregroundStyle(.btPrimary)
            BTHudMetricSeparator()
            Text("余 \(dailyController.remainingBallCount)")
            BTHudMetricSeparator()
            Text("\(dailyController.shotCount) 杆")
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
        .accessibilityLabel("每日清台，\(dailyController.game?.displayName ?? "清台")，剩余 \(dailyController.remainingBallCount) 球，\(dailyController.shotCount) 杆，\(dailyController.foulCount) 次犯规，用时 \(formatDuration(dailyController.elapsedSeconds))")
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
                .foregroundStyle(.btPrimary)
            Text(scoreboardText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
        }
    }

    private var gamePlayerLabel: some View {
        Text(currentPlayerLabel)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.btPrimary)
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
            showSpinPad = false
            ShotPlayCamera.setMode(is3D ? .topDown2DRotated : .perspective3D, on: vm)
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
            .foregroundStyle(Color.btPrimary)
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
                    Text(vm.onTableKeys.contains(PositionPlayBall.cueKey) ? "移母球切回2D" : "切回2D补回母球")
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
            ProgressView().tint(.btPrimary)
            Text("正在自动开球，停稳后直接开始")
                .font(.btCallout)
                .foregroundStyle(.white.opacity(0.88))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dailyClearance.autoBreaking")
    }

    private var dailyCompletionBar: some View {
        dailyResultLayout {
            VStack(alignment: .leading, spacing: 2) {
                Text("今日已清台")
                    .font(.btHeadline)
                    .foregroundStyle(.white)
                Text("\(dailyController.shotCount) 杆 · \(dailyController.foulCount) 犯 · \(formatDuration(dailyController.elapsedSeconds))")
                    .font(.btCaption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            Button("再来一局") { dailyController.replay() }
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                .buttonStyle(.borderedProminent)
                .tint(.btPrimary)
                .accessibilityIdentifier("dailyClearance.replay")
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var dailyFailureBar: some View {
        dailyResultLayout {
            Text(dailyController.statusText)
                .font(.btCallout)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(2)
            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            Button("重新开球") { requestDailyRerack() }
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                .buttonStyle(.borderedProminent)
                .tint(.btPrimary)
                .accessibilityIdentifier("dailyClearance.rerack")
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var strikeEnabled: Bool {
        !isDailyResult && !vm.isPlaying && !vm.isComputing && vm.isFeasible
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

    private var moreMenu: some View {
        // 页特有：对局中「结束对局」与「清空桌面」同 Section（G25 自由击打模板）。
        BTSolverMoreMenu(scene: vm.scene, showsAimCloseupToggle: true, pageExtras: {
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
                    showDailyGamePicker = false
                    selectDailyGame(game)
                } label: {
                    HStack {
                        Text(game.displayName)
                        Spacer()
                        if game == dailyController.game {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.btPrimary)
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
            return "刻度轮调方向 · 移母球切回2D"
        }
        return vm.breakRunner?.statusText(isPerspective: is3D)
            ?? (vm.isComputing ? "求解中…"
                : (!vm.isPlaying && !rulingText.isEmpty ? rulingText : vm.statusText))
    }

    private func requestDailyRerack() {
        switch dailyController.requestRerack() {
        case .started:
            flash("已重新摆架")
        case .confirmationRequired:
            showDailyRerackConfirm = true
        case .unavailable:
            flash("正在开球，请稍候", tone: .warning)
        }
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
        BTToast.present(message, tone: tone) { toast = $0 }
    }
}

#Preview("Dark") {
    NavigationStack { FreePlayView() }
        .preferredColorScheme(.dark)
}

/// Viewing actions deliberately use ShotPlayCamera, never the shot-selection handlers.
struct ShotObservationMenu: View {
    @ObservedObject var vm: PositionPlayViewModel
    let identifierPrefix: String

    var body: some View {
        Menu {
            Button("查看全桌", systemImage: "rectangle") {
                ShotPlayCamera.observeWholeTable(on: vm)
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
        .foregroundStyle(Color.btPrimary)
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
