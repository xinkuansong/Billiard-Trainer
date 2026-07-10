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

    init(initialBoard: BoardSnapshot? = nil,
         initialMode: PositionPlayViewModel.AimMode? = nil,
         sourceDrill: DrillContent? = nil) {
        self.initialBoard = initialBoard
        self.initialMode = initialMode
        self.sourceDrill = sourceDrill
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
    @State private var banner: String?

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

    /// 球库固定序（#1）：第一行 = 母球 + 1–7，第二行 = 8–15；每行 8 个槽位。
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
                        // D3 进场淡入：仅试打变体，球形落位后台面淡入（非试打路径恒为 1，零影响）。
                        .opacity(isTryout && !stageRevealed ? 0 : 1)
                    bottomBar(proxy)
                        .frame(height: Self.bottomBarHeight)
                }
                if let key = draggingKey { dragGhost(key) }
                bannerView
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showSpinPad)
        .coordinateSpace(name: "composer")
        .onPreferenceChange(ComposerFramePreference.self) { frames in
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
            ToolbarItem(placement: .principal) { navStatus }
            if isTryout {
                ToolbarItem(placement: .topBarTrailing) { briefInfoButton }
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
            Button("清空桌面", role: .destructive) { vm.clearTable() }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog(
            vm.isRecording
                ? "清空并重来将丢弃录制中的 \(vm.stepCount) 杆。"
                : "回到默认球形并重新开始？",
            isPresented: $showResetConfirm, titleVisibility: .visible
        ) {
            Button("清空并重来", role: .destructive) { vm.resetAll() }
            Button("取消", role: .cancel) {}
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
                if let sourceDrill {
                    // 试打变体：载入 drill 根级球局，默认自由模式（§1.1），球落位后说明卡淡入。
                    if let board = DrillBoardBuilder.board(for: sourceDrill) {
                        tryoutBoard = board
                        vm.loadBoard(board)
                    }
                    vm.aimMode = initialMode ?? .free
                    withAnimation(.easeIn(duration: 0.45).delay(0.1)) { stageRevealed = true }
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

    /// 顶栏 info：召回说明卡。
    private var briefInfoButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { showBrief.toggle() }
        } label: {
            Image(systemName: "info.circle")
        }
        .accessibilityLabel("试打说明")
        .accessibilityIdentifier("tryout.info")
    }

    /// 左下「重摆球形」（一等公民，替代清空桌面/清空重来）：一键回 drill 初始布局。
    /// `loadBoard` 有 `!isPlaying` 闸 ⇒ 回放中禁用。
    private var rearrangeButton: some View {
        Button {
            if let tryoutBoard { vm.loadBoard(tryoutBoard) }
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

            if !vm.isBreakMode && proxy.isValid {
                // G3 轨迹档位 chip：下沿贴球桌上沿、靠屏幕最右。
                BTTrajectoryDetailChip { vm.recompute() }
                    .btChipBandPlacement(proxy)
                    .allowsHitTesting(!vm.isPlaying)

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
                    undoEnabled: !vm.isPlaying && vm.canReplay,
                    onUndo: { vm.replayCurrent() },
                    playbackEnabled: !vm.isPlaying && vm.canPlayback,
                    onPlayback: { vm.replayLastShot() }
                )
                .btStageFrame(proxy.actionColumnFrame())
            }

            // 进场说明卡（§1.8）：贴球桌上方淡入，非 modal 不阻断操作。
            if isTryout, showBrief, let sourceDrill {
                DrillTryoutBriefCard(
                    drill: sourceDrill,
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
            onPocketTapped: { if !vm.isBreakMode { vm.selectPocket(at: $0) } },
            // 开球模式：仅母球可拖（限开球区），其余台面交互挂起。
            draggableBallNodes: vm.breakRunner?.draggableCue ?? vm.draggableBalls,
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
            selectableBallNodes: vm.isBreakMode ? [] : vm.selectableBalls,
            onBallTapped: { vm.selectTarget(node: $0) },
            onTableTapped: {
                dismissBriefOnInteraction()
                if !vm.isBreakMode { vm.handleTableTap(world: $0) }
            },
            onAimDragged: {
                dismissBriefOnInteraction()
                if !vm.isBreakMode { vm.handleAimDrag(world: $0) }
            },
            projector: projector
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(frameReader(id: "scene"))
        .clipped()
    }

    // MARK: - Nav status (#2：状态文案上移导航栏，不占球桌)

    /// 首次进入不暴露「未命名走位」（T-P18-37）：默认名时标题显示页面名「自由走位」
    /// （条 19.4 改名），用户重命名后才显示文档名。试打变体标题 = drill 名（§1.7）。
    private var navTitleText: String {
        if let sourceDrill { return sourceDrill.nameZh }
        return vm.sequence.name == "未命名走位" ? "自由走位" : vm.sequence.name
    }

    private var navStatus: some View {
        VStack(spacing: 1) {
            Text(navTitleText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.btPrimary)   // 与其他场景页品牌绿标题统一（ADR-P11-07）
                .lineLimit(1)
            HStack(spacing: 4) {
                if vm.isComputing {
                    ProgressView().controlSize(.mini).tint(.white)
                }
                Text(vm.breakRunner?.statusText ?? (vm.isComputing ? "求解中…" : vm.statusText))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Top info row（ADR-P11-08：信息行上移球桌上方，球桌全宽居中）

    /// 顶部信息行：进袋/自由切换 + 角度胶囊 + 母球进袋警示 + 录制指示。
    /// 与其他 2D 场景页的「顶部控件行 + 信息胶囊」同一套语言，左对齐。
    private var topInfoRow: some View {
        HStack(spacing: Spacing.sm) {
            if vm.isBreakMode {
                breakModePill
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
        .background(Color(white: 0.11))
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

    // MARK: - Palette bar (条 18.4：两排中心与球桌中心对齐、球加大、高度缩减)

    private func paletteBar(_ proxy: ShotStageProxy) -> some View {
        // #5a：球库常显全部 16 颗（母球 + 1–7 / 8–15 固定槽位）；在桌球变暗、不可拖，
        // 点击在桌球 = 让桌上对应球放大脉冲提示其位置。G8：排球总宽 = 球桌宽、居中。
        let all = PositionPlayBall.allKeys
        let row1 = Array(all.prefix(Self.paletteColumns))
        let row2 = Array(all.dropFirst(Self.paletteColumns))
        let libraryWidth = proxy.isValid ? proxy.libraryWidth : proxy.sceneSize.width
        let columnWidth = max(libraryWidth / CGFloat(Self.paletteColumns), 1)
        return VStack(spacing: 3) {
            paletteRow(row1, columnWidth: columnWidth)
            paletteRow(row2, columnWidth: columnWidth)
        }
        .frame(maxWidth: .infinity)
    }

    /// 一行球库槽位：固定 8 槽，每槽一颗球（含在桌变暗球）。
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

    // MARK: - Ball token (real face + drag to place)

    private func ballToken(_ key: String) -> some View {
        let onTable = vm.onTableKeys.contains(key)
        return PoolBallFace(key: key, diameter: 36)
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.5))
            .frame(width: 38, height: 38)
            .contentShape(Circle())
            .opacity(draggingKey == key ? 0.3 : (onTable ? 0.3 : 1))
            .accessibilityElement()
            .accessibilityIdentifier("paletteBall_\(key)")
            .onTapGesture {
                if onTable { vm.pulseTableBall(key) } else { vm.placeFromPalette(key) }
            }
            .gesture(paletteDrag(key), including: onTable ? .subviews : .all)
    }

    private func paletteDrag(_ key: String) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named("composer"))
            .onChanged { value in
                guard !vm.isPlaying else { return }
                dismissBriefOnInteraction()
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

    // Floating ghost following the finger during a palette drag.
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

    /// 试打变体（§1.7）：隐藏「重命名」，清空桌面/清空重来由「重摆球形」一等公民按钮取代。
    private var moreMenu: some View {
        Menu {
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
            Color.clear.preference(key: ComposerFramePreference.self,
                                   value: [id: geo.frame(in: .named("composer"))])
        }
    }
}

// MARK: - Frame preference

private struct ComposerFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

#Preview("Dark") {
    NavigationStack { PositionPlayComposerView() }
        .preferredColorScheme(.dark)
}
