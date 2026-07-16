import SwiftUI
import SceneKit

/// 走位编排台（ADR-P11-01 / ADR-P11-03 / ADR-P11-04）：自由摆球 + 连续击打，用于走位演示与教学素材录制。
///
/// 布局：左侧信息栏（进袋/自由切换、角度/厚薄、母球进袋警示、录制指示，从上往下排）+
/// 球桌区（完整外框取景，零叠层遮挡）；底部条 = 控制行（打点图标 + 力度滑条）+
/// 微边框球库（两行固定序）+ 右下操作列（击球 / 录制 / 重打）。状态文案上移到导航栏。
/// 交互：球库球拖到桌面落位、桌面球拖回底部条移除、点桌上球选目标（袋口模式）/ 设定瞄准（自由模式）。
/// 击球后桌面前进为新真相（进袋回库、母球停在走位终点，自动选下一杆）；「重打」退回上一杆
/// 击打前并恢复该杆全部参数。「录制」开关（仅模拟器构建，ADR-P11-10）：开启后每次击球
/// 自动记一杆，结束后序列 JSON 直写仓库 `content/position_play/sequences/`（内容生产采集口）。
struct PositionPlayComposerView: View {
    /// 可选初始球形（如「拍照建球形」产出的快照）。nil = 默认开箱球形。
    let initialBoard: BoardSnapshot?
    /// 可选初始瞄准模式（ADR-P18-01「自由击球」入口传 `.free`）。nil = 默认（进袋）。
    let initialMode: PositionPlayViewModel.AimMode?
    /// 试打模式来源 drill（方案 20260709-动作库试打模式）：非 nil 时进入试打变体——
    /// 标题 = drill 名、隐藏开球/重命名、左下「重摆球形」一键回 drill 初始布局、
    /// 进场说明卡（§1.8）；球库与拖球保持编排台原样。默认自由模式（§1.1 自己上手试线路）。
    let sourceDrill: DrillContent?
    /// 试打球形（D4，与视频示范同源的出片序列）：非 nil 时初始布局/重摆目标/说明卡
    /// 均取该序列；nil 回退 `DrillBoardBuilder` 的 shotIntent 路径。
    let tryoutFormation: DrillTryoutFormation?

    init(initialBoard: BoardSnapshot? = nil,
         initialMode: PositionPlayViewModel.AimMode? = nil,
         sourceDrill: DrillContent? = nil,
         tryoutFormation: DrillTryoutFormation? = nil) {
        self.initialBoard = initialBoard
        self.initialMode = initialMode
        self.sourceDrill = sourceDrill
        self.tryoutFormation = tryoutFormation
    }

    private var isTryout: Bool { sourceDrill != nil }

    @StateObject private var vm = PositionPlayViewModel()
    @State private var hasAppeared = false
    @State private var showSpinPad = false

    @State private var projector = TableProjector()

    // Palette drag-to-place state (composer coordinate space)
    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false

    // Frames in "composer" coordinate space
    @State private var sceneFrame: CGRect = .zero
    @State private var paletteFrame: CGRect = .zero

    @State private var showRename = false
    @State private var renameText = ""
    @State private var toast: BTToastMessage?

    // Tryout mode state（试打变体）
    /// drill 初始布局快照（「重摆球形」回退目标）。
    @State private var tryoutBoard: BoardSnapshot?
    /// 进场说明卡显示态：落位后淡入，首次交互/点卡淡出，顶栏 info 召回。
    @State private var showBrief = false
    /// 首次手势提示（D3）：合并为说明卡底部一行，跨启动记忆（参照「角度与打点」首拖提示模式）。
    @AppStorage("drillTryout.hasSeenGestureHint") private var hasSeenGestureHint = false
    /// 进场淡入（D3）：试打变体球形落位后台面淡入。
    @State private var stageRevealed = false

    // Destructive confirmations
    @State private var showClearTableConfirm = false
    @State private var showResetConfirm = false

    /// G10：顶栏 / 底栏固定高度 ⇒ scene 区域高度恒定 ⇒ 球桌渲染尺寸锁定。
    private static let topRowHeight = ShotStageMetrics.topRowHeight
    private static let bottomBarHeight = ShotStageMetrics.BottomBarHeight.composer.rawValue

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
                        // D3 进场淡入：仅试打变体，球形落位后台面淡入（非试打路径恒为 1，零影响）。
                        .opacity(isTryout && !stageRevealed ? 0 : 1)
                    bottomBar(proxy)
                        .frame(height: Self.bottomBarHeight)
                }
                if let key = draggingKey {
                    BTBallPaletteDragGhost(key: key, location: dragLocation, overTable: dragOverTable)
                }
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showSpinPad)
        .btToast($toast)
        .coordinateSpace(name: "composer")
        .onPreferenceChange(BTShotPageFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
        .navigationTitle(navTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                BTSolverNavStatus(
                    title: navTitleText,
                    isBusy: vm.isComputing,
                    statusText: vm.breakRunner?.statusText
                        ?? (vm.isComputing ? "求解中…" : vm.statusText)
                )
            }
            ToolbarItem(placement: .topBarTrailing) { moreMenu }
        }
        .alert("命名走位序列", isPresented: $showRename) {
            TextField("名称", text: $renameText)
            Button("保存") { vm.renameSequence(renameText) }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog(
            clearTableWarning,
            isPresented: $showClearTableConfirm, titleVisibility: .visible
        ) {
            Button("取消", role: .cancel) {}
            Button("清空桌面", role: .destructive) { vm.clearTable() }
        }
        .confirmationDialog(
            vm.isRecording
                ? "清空并重来将丢弃录制中的 \(vm.stepCount) 杆。"
                : "回到默认球形并重新开始？",
            isPresented: $showResetConfirm, titleVisibility: .visible
        ) {
            Button("取消", role: .cancel) {}
            Button("清空并重来", role: .destructive) { vm.resetAll() }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
                if let sourceDrill {
                    // 试打变体：载入球形（优先出片序列 D4，兜底 shotIntent），
                    // 默认自由模式（§1.1），球落位后说明卡淡入。
                    if let board = tryoutFormation?.initial
                        ?? DrillBoardBuilder.board(for: sourceDrill) {
                        tryoutBoard = board
                        vm.loadBoard(board)
                    }
                    // Q19.2④：有逐杆序列 ⇒ 默认「序列」模式；无序列 drill 降级为自由模式（保持既有行为）。
                    if let steps = tryoutFormation?.steps, !steps.isEmpty {
                        vm.configureSequence(steps)
                        vm.enterSequenceMode()
                    } else {
                        vm.aimMode = initialMode ?? .free
                    }
                    withAnimation(BTMotion.easeChrome.delay(0.1)) { stageRevealed = true }
                    withAnimation(.easeInOut(duration: 0.35).delay(0.6)) { showBrief = true }
                } else {
                    if let initialBoard { vm.loadBoard(initialBoard) }
                    if let initialMode { vm.aimMode = initialMode }
                }
            }
        }
    }

    // MARK: - Tryout helpers（试打变体）

    /// 首次交互（拖瞄/拖球/击球/点桌面）自动淡出说明卡（§1.8 交互红线：不阻断操作）；
    /// 首次交互同时记忆「已见手势提示」（D3，跨启动）。
    private func dismissBriefOnInteraction() {
        if isTryout, !hasSeenGestureHint { hasSeenGestureHint = true }
        guard showBrief else { return }
        withAnimation(.easeOut(duration: 0.25)) { showBrief = false }
    }

    /// 左下「重摆球形」（一等公民，替代清空桌面/清空重来）：一键回 drill 初始布局。
    /// `loadBoard` 有 `!isPlaying` 闸 ⇒ 回放中禁用。
    private var rearrangeButton: some View {
        Button {
            // 序列模式：从头重演；其余模式：回 drill 初始布局。
            if vm.isSequenceMode {
                vm.restartSequence()
            } else if let tryoutBoard {
                vm.loadBoard(tryoutBoard)
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                Text("重摆球形")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(tryoutBoard != nil ? Color.btPrimary : .white.opacity(0.35))
            .frame(width: 52, height: 46)
            .btHudGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(tryoutBoard == nil || vm.isPlaying)
        .accessibilityIdentifier("tryout.rearrange")
        .accessibilityLabel("重摆球形")
    }

    private var clearTableWarning: String {
        vm.isRecording
            ? "清空桌面将丢弃录制中的 \(vm.stepCount) 杆。"
            : "清空桌面上所有球？"
    }

    // MARK: - Stage（scene + 贴边控件，G3–G11 走 ShotStageProxy）

    private func stage(_ proxy: ShotStageProxy) -> some View {
        ZStack(alignment: .topLeading) {
            sceneContainer

            // G18/V6：开球模式贴边仪表（左瞄准轮 + 右力度柱），共享单一真源。
            if let runner = vm.breakRunner {
                BreakInstrumentsOverlay(runner: runner, proxy: proxy)
            }

            if !vm.isBreakMode && proxy.isValid {
                // G3 轨迹档位 chip：下沿贴球桌上沿、靠屏幕最右。
                BTTrajectoryDetailChip { vm.recompute() }
                    .btChipBandPlacement(proxy)
                    .allowsHitTesting(!vm.isPlaying)

                // Q19.2④ 序列模式：隐藏打点盘/力度条/瞄准条，仅逐杆播放。
                if vm.isSequenceMode {
                    rearrangeButton
                        .btStageFrame(proxy.bottomLeadingFrame(size: CGSize(width: 52, height: 46)))

                    // 右下角单「击打」按钮：一次点击走完整条序列。
                    BTShotActionColumn(
                        strikeTitle: vm.isSequencePlaying ? "演示中" : "击打",
                        strikeEnabled: !vm.isSequencePlaying && !vm.isPlaying,
                        onStrike: {
                            dismissBriefOnInteraction()
                            vm.playSequence()
                        },
                        undoEnabled: false,
                        onUndo: {},
                        playbackEnabled: false,
                        onPlayback: {}
                    )
                    .btStageFrame(proxy.actionColumnFrame())
                } else {
                    // G4/G5/G7 瞄准刻度轮（自由模式）：右缘贴球桌左侧、底部对齐。
                    if vm.aimMode == .free {
                        BTAimWheel(onNudge: { vm.nudgeFreeAim(byDegrees: $0) })
                            .btStageFrame(proxy.aimWheelFrame())
                            .allowsHitTesting(!vm.isPlaying)
                    }

                    // G6 左下角：试打变体 = 「重摆球形」一等公民（§1.7 隐藏开球）；
                    // 编排台 = 开球按钮（条 19.2 本页无开球，禁用态）。底边齐球桌底线。
                    if isTryout {
                        rearrangeButton
                            .btStageFrame(proxy.bottomLeadingFrame(size: CGSize(width: 52, height: 46)))
                    } else {
                        BTBreakSideButton(isEnabled: false) {}
                            .btStageFrame(proxy.breakButtonFrame())
                    }

                    // G4/G5/G7 打点+力度仪表柱：左缘贴球桌右侧、力度条本体底部对齐。
                    BTShotInstrumentColumn(
                        spinX: vm.spinX, spinY: vm.spinY,
                        onSpinTap: { showSpinPad = true },
                        velocity: $vm.velocity,
                        range: ShotTuning.velocityRange,
                        isDisabled: vm.isPlaying
                    )
                    .btStageFrame(proxy.instrumentFrame())

                    // 条 18.2：击球/上一杆/回放竖排，右下角底边齐球桌底线。
                    BTShotActionColumn(
                        strikeTitle: vm.isPlaying ? "击球中" : "击球",
                        strikeEnabled: strikeEnabled,
                        onStrike: {
                            dismissBriefOnInteraction()
                            vm.play()
                        },
                        undoTitle: "重打",
                        undoEnabled: !vm.isPlaying && vm.canReplay,
                        onUndo: { vm.replayCurrent() },
                        playbackEnabled: !vm.isPlaying && vm.canPlayback,
                        onPlayback: { vm.replayLastShot() }
                    )
                    .btStageFrame(proxy.actionColumnFrame())
                }
            }

            // 进场说明卡（§1.8）：贴球桌上方淡入，非 modal 不阻断操作。
            if isTryout, showBrief, let sourceDrill {
                DrillTryoutBriefCard(
                    drill: sourceDrill,
                    formation: tryoutFormation,
                    footnote: hasSeenGestureHint
                        ? nil
                        : "拖动台面瞄准 · 拖动球改摆 · 点「击球」试打"
                ) {
                    // 点卡关闭也视为「已见手势提示」（D3 跨启动记忆）。
                    if !hasSeenGestureHint { hasSeenGestureHint = true }
                    withAnimation(.easeOut(duration: 0.25)) { showBrief = false }
                }
                .padding(.horizontal, 64)
                .padding(.top, proxy.isValid ? max(proxy.tableRect.minY + 6, 6) : 40)
                .frame(maxWidth: .infinity, alignment: .center)
                .transition(.opacity)
                .zIndex(5)
            }

            // 打点盘浮层贴球桌底缘：半透明材质透出桌面绿色（ADR-P11-09）。
            if showSpinPad {
                BTSpinPadOverlay(spinX: $vm.spinX, spinY: $vm.spinY,
                                 onClose: { showSpinPad = false })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    // MARK: - Scene container (table only, zero overlays #2/#3)

    private var sceneContainer: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            interactionMode: .tapsOnly,
            autoFitsRotatedTable: true,
            onPocketTapped: { if !vm.isBreakMode && !vm.isSequenceMode { vm.selectPocket(at: $0) } },
            // 开球模式：仅母球可拖（限开球区）；序列模式：台面只读（逐杆演示），其余台面交互挂起。
            draggableBallNodes: vm.isSequenceMode ? [] : (vm.breakRunner?.draggableCue ?? vm.draggableBalls),
            onDragBegan: { node in
                dismissBriefOnInteraction()
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
            selectableBallNodes: (vm.isBreakMode || vm.isSequenceMode) ? [] : vm.selectableBalls,
            onBallTapped: { if !vm.isSequenceMode { vm.selectTarget(node: $0) } },
            onTableTapped: {
                dismissBriefOnInteraction()
                if !vm.isBreakMode && !vm.isSequenceMode { vm.handleTableTap(world: $0) }
            },
            onAimNudged: {
                dismissBriefOnInteraction()
                if vm.isSequenceMode { return }
                if let runner = vm.breakRunner { runner.nudgeAim(byDegrees: $0) }
                else { vm.nudgeFreeAim(byDegrees: $0) }
            },
            projector: projector
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(frameReader(id: "scene"))
        .clipped()
    }

    /// 首次进入不暴露「未命名走位」（T-P18-37 / 条 19.4）：默认名时标题显示「自由走位」；
    /// 用户重命名后才显示文档名。试打变体标题 = drill 名（§1.7）。
    private var navTitleText: String {
        if let sourceDrill { return sourceDrill.nameZh }
        return vm.sequence.name == "未命名走位" ? "自由走位" : vm.sequence.name
    }

    // MARK: - Top info row（ADR-P11-08：信息行上移球桌上方，球桌全宽居中）

    /// 顶部信息行：进袋/自由切换 + 角度胶囊 + 母球进袋警示 + 录制指示。
    /// 与其他 2D 场景页的「顶部控件行 + 信息胶囊」同一套语言，左对齐。
    private var topInfoRow: some View {
        HStack(spacing: Spacing.sm) {
            if vm.isBreakMode {
                breakModePill
            } else if isTryout && vm.hasSequence {
                // Q19.2④：试打三模式选择（序列/进袋/自由）。
                tryoutModeSelector
                if vm.isSequenceMode {
                    sequenceStepBar
                } else {
                    aimCapsule
                    if vm.cuePocketed { scratchPill }
                }
            } else {
                // 条 15.2/15.3：进袋/自由单按钮点击切换，切自由保留进袋瞄准方向。
                BTAimModeToggleButton(isFree: vm.aimMode == .free,
                                      isDisabled: vm.isPlaying) {
                    vm.toggleAimMode()
                }

                aimCapsule

                if vm.cuePocketed { scratchPill }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxHeight: .infinity)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Tryout sequence mode (Q19.2④)

    /// 试打三模式选择：序列 / 进袋 / 自由。切换即刷新台面与控件。
    private enum TryoutMode: String, CaseIterable { case sequence = "序列", pocket = "进袋", free = "自由" }

    private var currentTryoutMode: TryoutMode {
        if vm.isSequenceMode { return .sequence }
        return vm.aimMode == .free ? .free : .pocket
    }

    private var tryoutModeSelector: some View {
        HStack(spacing: 2) {
            ForEach(TryoutMode.allCases, id: \.self) { mode in
                let selected = currentTryoutMode == mode
                Button {
                    selectTryoutMode(mode)
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected ? .black : .white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selected ? Color.btPrimary : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tryoutMode_\(mode.rawValue)")
            }
        }
        .padding(3)
        .btHudGlass(in: Capsule())
        .disabled(vm.isPlaying || vm.isSequencePlaying)
        .opacity(vm.isPlaying || vm.isSequencePlaying ? 0.5 : 1)
    }

    private func selectTryoutMode(_ mode: TryoutMode) {
        guard !vm.isPlaying, !vm.isSequencePlaying, mode != currentTryoutMode else { return }
        switch mode {
        case .sequence:
            vm.enterSequenceMode()
        case .pocket:
            vm.exitSequenceMode()
            if let tryoutBoard { vm.loadBoard(tryoutBoard) }
            vm.aimMode = .pocket
        case .free:
            vm.exitSequenceMode()
            if let tryoutBoard { vm.loadBoard(tryoutBoard) }
            vm.aimMode = .free
        }
    }

    /// 序列模式当前杆信息条：第 n/N 杆 · 打 X 号 → 袋口 · 打点 · 力度。
    @ViewBuilder
    private var sequenceStepBar: some View {
        if let info = vm.currentSequenceInfo {
            HStack(spacing: 6) {
                Text("第 \(info.index + 1)/\(info.total) 杆")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.btPrimary)
                Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 12)
                if info.isFree {
                    Text("自由球")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    Text("\(info.targetLabel ?? "") 号" + (info.pocketName.map { " → \($0)" } ?? ""))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
                Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 12)
                Text("\(info.spinPhrase) · \(info.powerPhrase)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .btHudGlass()
            .accessibilityIdentifier("tryout.sequenceStepBar")
        } else if vm.sequenceFinished {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.btPrimary)
                Text("序列演示完成")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .btHudGlass()
        }
    }

    /// 角度/厚薄（袋口模式）或自由球标识——统一信息胶囊样式。
    private var aimCapsule: some View {
        HStack(spacing: 4) {
            if vm.aimMode == .free {
                // 首碰读数（T-P18-06/08）：厚度重叠图示 + 切角 + 厚度名 + 首碰球号；
                // 空杆（射线不碰任何球）退回「自由球」标识。
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

    /// 开球模式标识胶囊（T-P18-47）：玩法名 + 提示（G9：摆架图形与开球按钮同源）。
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

    /// 母球进袋（失误）警示胶囊。
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

    // MARK: - Bottom bar (布局规范 v2：动作按钮上移球桌区，底部只留球库，条 18)

    private func bottomBar(_ proxy: ShotStageProxy) -> some View {
        Group {
            if vm.isBreakMode {
                breakBar
            } else {
                paletteBar(proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HUDStyle.panelBackground)
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .background(frameReader(id: "palette"))
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Break bar（T-P18-47：开球模式底部条，共享 `BreakControlBar`）

    @ViewBuilder
    private var breakBar: some View {
        if let runner = vm.breakRunner {
            BreakControlBar(runner: runner, onCancel: { vm.cancelBreakFlow() })
        }
    }

    private var strikeEnabled: Bool {
        !vm.isPlaying && !vm.isComputing && vm.isFeasible
    }

    // MARK: - Palette bar (G21：BTBallPaletteBar)

    private func paletteBar(_ proxy: ShotStageProxy) -> some View {
        let libraryWidth = proxy.isValid ? proxy.libraryWidth : proxy.sceneSize.width
        return BTBallPaletteBar(
            coordinateSpace: "composer",
            ballDiameter: BTBallPaletteMetrics.regularDiameter,
            isPlaying: vm.isPlaying,
            libraryWidth: libraryWidth,
            isOnTable: { vm.onTableKeys.contains($0) },
            sceneFrame: sceneFrame,
            unproject: { projector.unproject?($0) },
            onTap: { key in
                if vm.onTableKeys.contains(key) { vm.pulseTableBall(key) }
                else { vm.placeFromPalette(key) }
            },
            onPlace: { key, world in
                if let world { vm.placeFromPalette(key, atWorld: world) }
                else { vm.placeFromPalette(key) }
            },
            onDragInteraction: { dismissBriefOnInteraction() },
            draggingKey: $draggingKey,
            dragLocation: $dragLocation,
            dragOverTable: $dragOverTable
        )
    }

    // MARK: - Table ball dragged back to palette → remove

    private func handleTableDragEnd(node: SCNNode, localPoint: CGPoint) {
        guard BTBallPaletteDragBack.hitPalette(localPoint: localPoint,
                                               sceneFrame: sceneFrame,
                                               paletteFrame: paletteFrame),
              let key = vm.scene.ballKey(for: node) else { return }
        vm.removeFromTable(key)
        flash("已移回球库")
    }

    // MARK: - Toolbar menu

    /// 试打变体（§1.7）：隐藏「重命名」，清空桌面/清空重来由「重摆球形」一等公民按钮取代。
    private var moreMenu: some View {
        Menu {
            if isTryout {
                // Q19.2③：右上角 i 内容并入三点菜单（G19 口径）——说明卡召回入口。
                Button("试打说明", systemImage: "info.circle") {
                    withAnimation(.easeInOut(duration: 0.25)) { showBrief.toggle() }
                }
                .accessibilityIdentifier("tryout.info")
            }
            if !isTryout {
                Button("重命名", systemImage: "pencil") {
                    renameText = vm.sequence.name
                    showRename = true
                }
            }
            Section("显示") {
                BTTableGridMenuToggle(scene: vm.scene)
            }
            if !isTryout {
                Section {
                    Button("清空桌面", systemImage: "trash", role: vm.isRecording ? .destructive : nil) {
                        if vm.isRecording { showClearTableConfirm = true } else { vm.clearTable() }
                    }
                    Button("清空并重来", systemImage: "arrow.counterclockwise", role: .destructive) {
                        showResetConfirm = true
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityIdentifier("composer.more")
    }

    private func flash(_ message: String, tone: BTToastTone = .success) {
        BTToast.present(message, tone: tone) { toast = $0 }
    }

    // MARK: - Frame reader

    private func frameReader(id: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: BTShotPageFramePreference.self,
                                   value: [id: geo.frame(in: .named("composer"))])
        }
    }
}

#Preview("Dark") {
    NavigationStack { PositionPlayComposerView() }
        .preferredColorScheme(.dark)
}
