import SwiftUI
import SceneKit

/// 自由击球（条 15 / ADR-P18-01 拆页）：球库 + 开球 + 对局的独立页面。
///
/// 与「自由走位」（编排台）的分工：自由走位 = 纯摆球/编排推演（无开球）；
/// 自由击球 = 从开球开始的完整对局体验。开球按钮状态机（条 15.8/15.9）：
/// 开球 → 开球中 → 重开（换 seed 重摆）；停稳后点「完成」才送入击打阶段。
///
/// 布局（问题集合 v3 §S1 基准页）：控件相对**屏幕内实际球桌矩形**贴边定位
/// （`ShotStageProxy`，G3–G11），顶栏/底栏高度固定 ⇒ 球桌尺寸严格锁定不抖动（G10）。
struct FreePlayView: View {
    @StateObject private var vm = PositionPlayViewModel()
    @State private var hasAppeared = false
    @State private var showSpinPad = false
    @State private var showBreakPicker = false

    @State private var projector = TableProjector()

    @State private var banner: String?
    @State private var showClearTableConfirm = false

    // 规则对局（条 15.10）：开球「完成」后按玩法启用引擎；引擎只做裁决与轮转提示，
    // 台面操作仍全开放（单机一人扮两方，自由球=用户自行拖母球）。
    @State private var rules: (any BilliardRulesEngine)?
    @State private var pendingGame: RackGame?
    @State private var rulingText = ""
    @State private var scoreboardText = ""
    @State private var currentPlayerLabel = ""

    private static let paletteColumns = 8
    /// G10：顶栏 / 底栏固定高度 ⇒ scene 区域高度恒定 ⇒ 球桌渲染尺寸锁定。
    private static let topRowHeight: CGFloat = 46
    private static let bottomBarHeight: CGFloat = 94

    var body: some View {
        GeometryReader { geo in
            let extents = vm.tableOuterHalfExtents
            let sceneH = max(geo.size.height - Self.topRowHeight - Self.bottomBarHeight, 1)
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
                        .frame(height: Self.bottomBarHeight)
                }
                bannerView
            }
            .coordinateSpace(name: "freeplay")
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showSpinPad)
        .navigationTitle("自由击球")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) { navStatus }
            ToolbarItem(placement: .topBarTrailing) { moreMenu }
        }
        .confirmationDialog("清空桌面上所有球？",
                            isPresented: $showClearTableConfirm, titleVisibility: .visible) {
            Button("清空桌面", role: .destructive) {
                endGame()
                vm.clearTable()
            }
            Button("取消", role: .cancel) {}
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
        .onChange(of: vm.isBreakMode) { _, inBreak in
            // 开球「完成」交付击打阶段 → 按玩法启动规则对局（取消开球时 pendingGame 已清）。
            if !inBreak, let game = pendingGame {
                pendingGame = nil
                startGame(game)
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
                vm.onShotSettled = { facts in handleShotSettled(facts) }
            }
        }
    }

    // MARK: - Stage（scene + 贴边控件，G3–G11）

    private func stage(_ proxy: ShotStageProxy) -> some View {
        ZStack(alignment: .topLeading) {
            sceneContainer

            if !vm.isBreakMode && proxy.isValid {
                // G3 轨迹档位 chip：下沿贴球桌上沿、靠屏幕最右（放球桌上方空隙带内）。
                BTTrajectoryDetailChip { vm.recompute() }
                    .padding(.trailing, 8)
                    .padding(.bottom, 2)
                    .frame(maxWidth: .infinity,
                           maxHeight: proxy.chipBandHeight,
                           alignment: .bottomTrailing)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(!vm.isPlaying)

                // G4/G5/G7 瞄准刻度轮（自由模式）：右缘贴球桌左侧、底部对齐。
                if vm.aimMode == .free {
                    let f = proxy.aimWheelFrame()
                    BTAimWheel(onNudge: { vm.nudgeFreeAim(byDegrees: $0) })
                        .frame(width: f.width, height: f.height)
                        .position(x: f.midX, y: f.midY)
                        .allowsHitTesting(!vm.isPlaying)
                }

                // G6/G9 开球按钮：左下角，底边齐球桌底线（本页有真实开球流程）。
                let bf = proxy.breakButtonFrame()
                BTBreakSideButton(isEnabled: !vm.isPlaying) { showBreakPicker = true }
                    .frame(width: bf.width, height: bf.height)
                    .position(x: bf.midX, y: bf.midY)

                // G4/G5/G7 打点+力度仪表柱：左缘贴球桌右侧、力度条本体底部对齐。
                let inf = proxy.instrumentFrame()
                BTShotInstrumentColumn(
                    spinX: vm.spinX, spinY: vm.spinY,
                    onSpinTap: { showSpinPad = true },
                    velocity: $vm.velocity,
                    range: ShotTuning.velocityRange,
                    isDisabled: vm.isPlaying
                )
                .frame(width: inf.width, height: inf.height)
                .position(x: inf.midX, y: inf.midY)

                // 18.2 击球/上一杆/回放：右下角，底边齐球桌底线。
                let af = proxy.actionColumnFrame()
                BTShotActionColumn(
                    strikeTitle: vm.isPlaying ? "击球中" : "击球",
                    strikeEnabled: strikeEnabled,
                    onStrike: { vm.play() },
                    undoEnabled: !vm.isPlaying && vm.canReplay,
                    onUndo: { vm.replayCurrent() },
                    playbackEnabled: !vm.isPlaying && vm.canPlayback,
                    onPlayback: { vm.replayLastShot() }
                )
                .frame(width: af.width, height: af.height)
                .position(x: af.midX, y: af.midY)
            }

            if showSpinPad {
                BTSpinPadOverlay(spinX: $vm.spinX, spinY: $vm.spinY,
                                 onClose: { showSpinPad = false })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
            interactionMode: .tapsOnly,
            autoFitsRotatedTable: true,
            onPocketTapped: { if !vm.isBreakMode { vm.selectPocket(at: $0) } },
            // P10.1 禁止摆球：非开球模式仅母球可拖（自由球/走位微调）；开球模式拖开球区母球。
            draggableBallNodes: vm.breakRunner?.draggableCue ?? vm.draggableCueOnly,
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
            selectableBallNodes: vm.isBreakMode ? [] : vm.selectableBalls,
            onBallTapped: { node in handleTargetTap(node) },
            onTableTapped: { if !vm.isBreakMode { vm.handleTableTap(world: $0) } },
            onAimDragged: { if !vm.isBreakMode { vm.handleAimDrag(world: $0) } },
            projector: projector
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    /// P10.2：按当前玩法规则拦截不合法目标球选择，并给出提示。
    private func handleTargetTap(_ node: SCNNode) {
        guard !vm.isBreakMode else { return }
        if let rules, vm.aimMode == .pocket, let key = vm.scene.ballKey(for: node),
           !PositionPlayBall.isCue(key) {
            let tableTargets = Set(vm.onTableKeys.filter { $0 != PositionPlayBall.cueKey })
            let legal = rules.legalTargetKeys(tableKeys: tableTargets)
            if !legal.contains(key) {
                flash("按当前规则不能打 \(PositionPlayBall.shortLabel(for: key)) 号球")
                return
            }
        }
        vm.selectTarget(node: node)
    }

    // MARK: - Nav status

    private var navStatus: some View {
        VStack(spacing: 1) {
            Text("自由击球")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.btPrimary)
                .lineLimit(1)
            HStack(spacing: 4) {
                if vm.isComputing {
                    ProgressView().controlSize(.mini).tint(.white)
                }
                Text(vm.breakRunner?.statusText
                     ?? (vm.isComputing ? "求解中…"
                         : (!vm.isPlaying && !rulingText.isEmpty ? rulingText : vm.statusText)))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Top info row

    private var topInfoRow: some View {
        HStack(spacing: Spacing.sm) {
            if vm.isBreakMode {
                breakModePill
            } else {
                BTAimModeToggleButton(isFree: vm.aimMode == .free,
                                      isDisabled: vm.isPlaying) {
                    vm.toggleAimMode()
                }

                aimCapsule

                if rules != nil { gamePill }

                if vm.cuePocketed { scratchPill }
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
                        Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 12)
                        Text(name)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 12)
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
                    Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 12)
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

    /// 规则对局 HUD（条 15.10）：记分牌 + 当前击球方。
    private var gamePill: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.btPrimary)
            Text(scoreboardText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
            if !currentPlayerLabel.isEmpty {
                Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 12)
                Text("轮到 \(currentPlayerLabel)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.btPrimary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .btHudGlass()
    }

    private var scratchPill: some View {
        HStack(spacing: 4) {
            Circle().fill(Color.btDestructive).frame(width: 6, height: 6)
            Text("母球进袋")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.btDestructive)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .background(Color.btDestructive.opacity(0.16), in: Capsule())
    }

    // MARK: - Bottom bar

    private func bottomBar(_ proxy: ShotStageProxy) -> some View {
        Group {
            if let runner = vm.breakRunner {
                FreePlayBreakBar(runner: runner, onCancel: {
                    pendingGame = nil
                    vm.cancelBreakFlow()
                })
            } else {
                paletteBar(proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.11))
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .environment(\.colorScheme, .dark)
    }

    private var strikeEnabled: Bool {
        !vm.isPlaying && !vm.isComputing && vm.isFeasible
    }

    // MARK: - Palette bar（G8：排球总宽 = 球桌宽、居中；P10.1：只读参考，禁止摆球）

    private func paletteBar(_ proxy: ShotStageProxy) -> some View {
        let all = PositionPlayBall.allKeys
        let row1 = Array(all.prefix(Self.paletteColumns))
        let row2 = Array(all.dropFirst(Self.paletteColumns))
        // G8：排球总宽 = 球桌宽——固定列宽求和 = 球桌宽，居中，两侧留白给按键让位。
        let libraryWidth = proxy.isValid ? proxy.libraryWidth : proxy.sceneSize.width
        let columnWidth = max(libraryWidth / CGFloat(Self.paletteColumns), 1)
        return VStack(spacing: 3) {
            paletteRow(row1, columnWidth: columnWidth)
            paletteRow(row2, columnWidth: columnWidth)
        }
        .frame(maxWidth: .infinity)
    }

    private func paletteRow(_ keys: [String], columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<Self.paletteColumns, id: \.self) { i in
                Group {
                    if i < keys.count {
                        ballToken(keys[i])
                    } else {
                        Color.clear
                    }
                }
                .frame(width: columnWidth, height: 38)
            }
        }
    }

    /// P10.1：本页禁止手动摆球——球库仅作剩余球参考，点击提示「开球后自动摆球」。
    private func ballToken(_ key: String) -> some View {
        let onTable = vm.onTableKeys.contains(key)
        return PoolBallFace(key: key, diameter: 34)
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.5))
            .frame(width: 36, height: 36)
            .contentShape(Circle())
            .opacity(onTable ? 0.28 : 0.85)
            .onTapGesture {
                if onTable { vm.pulseTableBall(key) }
                else { flash("本页从开球开始，不支持手动摆球") }
            }
    }

    // MARK: - Toolbar menu

    private var moreMenu: some View {
        Menu {
            Section("显示") {
                BTTableGridMenuToggle(scene: vm.scene)
            }
            Section {
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
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    @ViewBuilder
    private var bannerView: some View {
        if let banner {
            VStack {
                Text(banner)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.sm)
                    .background(Color.btSuccess, in: Capsule())
                    .padding(.top, 60)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func flash(_ message: String) {
        withAnimation { banner = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { banner = nil }
        }
    }
}

// MARK: - 自由击球开球条（条 15.8/15.9 状态机：开球 → 开球中 → 重开；完成 = 手动进击打）

private struct FreePlayBreakBar: View {
    @ObservedObject var runner: BreakFlowRunner
    let onCancel: () -> Void

    /// 主按钮标题随状态机：racked=开球、computing/breaking=开球中、settled=重开。
    private var mainTitle: String {
        switch runner.phase {
        case .racked: return "开球"
        case .computing, .breaking: return "开球中"
        case .settled: return "重开"
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Button("取消") { onCancel() }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, Spacing.lg)
                .frame(height: 42)
                .background(Color.white.opacity(0.10), in: Capsule())
                .buttonStyle(.plain)
                .disabled(runner.isBusy)

            Spacer(minLength: 0)

            // 「完成」（条 15.9）：停稳后手动送入击打阶段。
            if runner.phase == .settled {
                Button {
                    runner.confirmSettled()
                } label: {
                    Text("完成")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 84, height: 42)
                        .background(Color.btPrimary, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("break.confirm")
            }

            Button {
                switch runner.phase {
                case .racked: runner.breakNow()
                case .settled: runner.reRack()
                default: break
                }
            } label: {
                HStack(spacing: 5) {
                    if runner.phase == .settled {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        CueStickShape().frame(width: 15, height: 15).foregroundStyle(.white)
                    }
                    Text(mainTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 92, height: 42)
                .background(runner.isBusy ? Color.btPrimary.opacity(0.3)
                            : (runner.phase == .settled ? Color.white.opacity(0.14) : Color.btPrimary),
                            in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(runner.isBusy)
            .accessibilityIdentifier("break.strike")
        }
        .padding(.horizontal, Spacing.lg)
    }
}

#Preview("Dark") {
    NavigationStack { FreePlayView() }
        .preferredColorScheme(.dark)
}
