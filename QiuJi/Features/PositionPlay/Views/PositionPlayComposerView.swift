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

    init(initialBoard: BoardSnapshot? = nil,
         initialMode: PositionPlayViewModel.AimMode? = nil) {
        self.initialBoard = initialBoard
        self.initialMode = initialMode
    }

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

    // Destructive confirmations
    @State private var showClearTableConfirm = false
    @State private var showResetConfirm = false

    /// 球库固定序（#1）：第一行 = 母球 + 1–7，第二行 = 8–15；每行 8 个槽位。
    private static let paletteColumns = 8

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topInfoRow
                ZStack(alignment: .bottom) {
                    sceneContainer
                    // 布局规范 v2（条 18）：动作列贴底部角袋区，仪表柱在其上方
                    // （柱底 ≈ 下角袋橡胶上沿）；左 = 瞄准刻度轮 + 开球，右 = 打点/力度 + 动作列。
                    if !vm.isBreakMode {
                        VStack(spacing: 10) {
                            Spacer(minLength: 0)
                            if vm.aimMode == .free {
                                BTAimWheel(onNudge: { vm.nudgeFreeAim(byDegrees: $0) })
                                    .frame(width: 34, height: 220)
                                    .allowsHitTesting(!vm.isPlaying)
                            }
                            // 条 19.2：自由走位无开球——按条 18.4 显示禁用态。
                            BTBreakSideButton(isEnabled: false) {}
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
                            // 条 18.2：击球/上一杆/回放竖排贴右下角袋区。
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
                    // 打点盘浮层贴球桌底缘：半透明材质透出桌面绿色（系统 sheet 底下是
                    // 纯黑+压暗层会显得过深，ADR-P11-09）。
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
                if let initialBoard { vm.loadBoard(initialBoard) }
                if let initialMode { vm.aimMode = initialMode }
            }
        }
    }

    private var clearTableWarning: String {
        vm.isRecording
            ? "清空桌面将丢弃录制中的 \(vm.stepCount) 杆。"
            : "清空桌面上所有球？"
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
        // 三档轨迹标注切换（条 12.5）：全击打页统一放球桌区右上角。
        .overlay(alignment: .topTrailing) {
            if !vm.isBreakMode {
                BTTrajectoryDetailChip { vm.recompute() }
                    .padding(Spacing.sm)
            }
        }
    }

    // MARK: - Nav status (#2：状态文案上移导航栏，不占球桌)

    /// 首次进入不暴露「未命名走位」（T-P18-37）：默认名时标题显示页面名「自由走位」
    /// （条 19.4 改名），用户重命名后才显示文档名。
    private var navTitleText: String {
        vm.sequence.name == "未命名走位" ? "自由走位" : vm.sequence.name
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
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xs)
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

    /// 开球模式标识胶囊（T-P18-47）：玩法名 + 提示。
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

    private var bottomBar: some View {
        Group {
            if vm.isBreakMode {
                breakBar
            } else {
                paletteBar
            }
        }
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

    private var paletteBar: some View {
        // #5a：球库常显全部 16 颗（母球 + 1–7 / 8–15 固定槽位）；在桌球变暗、不可拖，
        // 点击在桌球 = 让桌上对应球放大脉冲提示其位置。
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

    /// 一行球库槽位：固定 8 槽，每槽一颗球（含在桌变暗球）。
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

    // MARK: - Ball token (real face + drag to place)

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
        DragGesture(minimumDistance: 10, coordinateSpace: .named("composer"))
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

    private var moreMenu: some View {
        Menu {
            Button("重命名", systemImage: "pencil") {
                renameText = vm.sequence.name
                showRename = true
            }
            Section("显示") {
                BTTableGridMenuToggle(scene: vm.scene)
            }
            Section {
                Button("清空桌面", systemImage: "trash", role: vm.isRecording ? .destructive : nil) {
                    if vm.isRecording { showClearTableConfirm = true } else { vm.clearTable() }
                }
                Button("清空并重来", systemImage: "arrow.counterclockwise", role: .destructive) {
                    showResetConfirm = true
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
