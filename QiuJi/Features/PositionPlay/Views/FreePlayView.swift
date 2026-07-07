import SwiftUI
import SceneKit

/// 自由击球（条 15 / ADR-P18-01 拆页）：球库 + 开球 + 对局的独立页面。
///
/// 与「自由走位」（编排台）的分工：自由走位 = 纯摆球/编排推演（无开球）；
/// 自由击球 = 从开球开始的完整对局体验。开球按钮状态机（条 15.8/15.9）：
/// 开球 → 开球中 → 重开（换 seed 重摆）；停稳后点「完成」才送入击打阶段。
/// E3 将在本页接入中八/追分完整规则引擎。
struct FreePlayView: View {
    @StateObject private var vm = PositionPlayViewModel()
    @State private var hasAppeared = false
    @State private var showSpinPad = false
    @State private var showBreakPicker = false

    @State private var projector = TableProjector()

    // Palette drag-to-place state (freeplay coordinate space)
    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false

    @State private var sceneFrame: CGRect = .zero
    @State private var paletteFrame: CGRect = .zero

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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topInfoRow
                ZStack(alignment: .bottom) {
                    sceneContainer
                    if !vm.isBreakMode {
                        VStack(spacing: 10) {
                            Spacer(minLength: 0)
                            if vm.aimMode == .free {
                                BTAimWheel(onNudge: { vm.nudgeFreeAim(byDegrees: $0) })
                                    .frame(width: 34, height: 220)
                                    .allowsHitTesting(!vm.isPlaying)
                            }
                            // 条 18.3：开球按钮固定左下——本页有真实开球流程。
                            BTBreakSideButton(isEnabled: !vm.isPlaying) {
                                showBreakPicker = true
                            }
                        }
                        .padding(.leading, 8)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottomLeading)

                        VStack(spacing: 10) {
                            Spacer(minLength: 0)
                            BTShotInstrumentColumn(
                                spinX: vm.spinX, spinY: vm.spinY,
                                onSpinTap: { showSpinPad = true },
                                velocity: $vm.velocity,
                                range: ShotTuning.velocityRange,
                                isDisabled: vm.isPlaying
                            )
                            .frame(width: 36, height: 240)
                            BTShotActionColumn(
                                strikeTitle: vm.isPlaying ? "击球中" : "击球",
                                strikeEnabled: strikeEnabled,
                                onStrike: { vm.play() },
                                undoEnabled: !vm.isPlaying && vm.canReplay,
                                onUndo: { vm.replayCurrent() },
                                playbackEnabled: !vm.isPlaying && vm.canPlayback,
                                onPlayback: { vm.replayLastShot() }
                            )
                        }
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottomTrailing)
                    }
                    if showSpinPad {
                        BTSpinPadOverlay(spinX: $vm.spinX, spinY: $vm.spinY,
                                         onClose: { showSpinPad = false })
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                bottomBar
            }
            if let key = draggingKey { dragGhost(key) }
            bannerView
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showSpinPad)
        .coordinateSpace(name: "freeplay")
        .onPreferenceChange(FreePlayFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
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
            draggableBallNodes: vm.breakRunner?.draggableCue ?? vm.draggableBalls,
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
            onDragEndedAt: { node, localPoint in
                guard !vm.isBreakMode else { return }
                handleTableDragEnd(node: node, localPoint: localPoint)
            },
            selectableBallNodes: vm.isBreakMode ? [] : vm.selectableBalls,
            onBallTapped: { vm.selectTarget(node: $0) },
            onTableTapped: { if !vm.isBreakMode { vm.handleTableTap(world: $0) } },
            onAimDragged: { if !vm.isBreakMode { vm.handleAimDrag(world: $0) } },
            projector: projector
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(frameReader(id: "scene"))
        .clipped()
        .overlay(alignment: .topTrailing) {
            if !vm.isBreakMode {
                BTTrajectoryDetailChip { vm.recompute() }
                    .padding(Spacing.sm)
            }
        }
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
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xs)
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
            Image(systemName: "triangle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.btPrimary)
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

    private var bottomBar: some View {
        Group {
            if let runner = vm.breakRunner {
                FreePlayBreakBar(runner: runner, onCancel: {
                    pendingGame = nil
                    vm.cancelBreakFlow()
                })
            } else {
                paletteBar
            }
        }
        .background(Color(white: 0.11))
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .background(frameReader(id: "palette"))
        .environment(\.colorScheme, .dark)
    }

    private var strikeEnabled: Bool {
        !vm.isPlaying && !vm.isComputing && vm.isFeasible
    }

    // MARK: - Palette bar

    private var paletteBar: some View {
        let all = PositionPlayBall.allKeys
        let row1 = Array(all.prefix(Self.paletteColumns))
        let row2 = Array(all.dropFirst(Self.paletteColumns))
        return VStack(spacing: 3) {
            paletteRow(row1)
            paletteRow(row2)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    private func paletteRow(_ keys: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<Self.paletteColumns, id: \.self) { i in
                Group {
                    if i < keys.count {
                        ballToken(keys[i])
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
            }
        }
    }

    private func ballToken(_ key: String) -> some View {
        let onTable = vm.onTableKeys.contains(key)
        return PoolBallFace(key: key, diameter: 36)
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.5))
            .frame(width: 38, height: 38)
            .contentShape(Circle())
            .opacity(draggingKey == key ? 0.3 : (onTable ? 0.3 : 1))
            .onTapGesture {
                if onTable { vm.pulseTableBall(key) } else { vm.placeFromPalette(key) }
            }
            .gesture(paletteDrag(key), including: onTable ? .subviews : .all)
    }

    private func paletteDrag(_ key: String) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named("freeplay"))
            .onChanged { value in
                guard !vm.isPlaying else { return }
                draggingKey = key
                dragLocation = value.location
                dragOverTable = sceneFrame.contains(value.location)
            }
            .onEnded { value in
                let loc = value.location
                defer { draggingKey = nil; dragOverTable = false }
                guard !vm.isPlaying, sceneFrame.contains(loc) else { return }
                let local = CGPoint(x: loc.x - sceneFrame.minX, y: loc.y - sceneFrame.minY)
                if let world = projector.unproject?(local) {
                    vm.placeFromPalette(key, atWorld: world)
                } else {
                    vm.placeFromPalette(key)
                }
            }
    }

    @ViewBuilder
    private func dragGhost(_ key: String) -> some View {
        PoolBallFace(key: key, diameter: 42)
            .overlay(Circle().stroke(dragOverTable ? Color.btSuccess : .white.opacity(0.4),
                                     lineWidth: dragOverTable ? 2.5 : 1))
            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            .position(dragLocation)
            .allowsHitTesting(false)
    }

    // MARK: - Table ball dragged back to palette → remove

    private func handleTableDragEnd(node: SCNNode, localPoint: CGPoint) {
        guard sceneFrame != .zero, paletteFrame != .zero else { return }
        let composerPoint = CGPoint(x: localPoint.x + sceneFrame.minX, y: localPoint.y + sceneFrame.minY)
        guard paletteFrame.contains(composerPoint), let key = vm.scene.ballKey(for: node) else { return }
        vm.removeFromTable(key)
        flash("已移回球库")
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

    // MARK: - Frame reader

    private func frameReader(id: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: FreePlayFramePreference.self,
                                   value: [id: geo.frame(in: .named("freeplay"))])
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
        .padding(.vertical, 12)
    }
}

// MARK: - Frame preference

private struct FreePlayFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

#Preview("Dark") {
    NavigationStack { FreePlayView() }
        .preferredColorScheme(.dark)
}
