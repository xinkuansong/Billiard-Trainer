import SwiftUI
import SceneKit

/// 分离角与走位（条 17）：教学演示页，看懂碰撞后母球走向。
///
/// v3（E4）：与自由走位/自由击球同一套引擎与布局语言（`PositionPlayViewModel` + 条 18 布局）。
/// 差异点：目标球**强制最多 2 颗**（专注感受角度/力度/打点对母球轨迹的影响）、无开球
/// （左下开球按钮禁用态）、「重置」回默认教学球形（母球 + 黑 8 中等角度可进袋）。
struct ShotSimulationView: View {
    @StateObject private var vm = PositionPlayViewModel()
    @State private var hasAppeared = false
    @State private var showSpinPad = false

    @State private var projector = TableProjector()

    // Palette drag-to-place state (simulation coordinate space)
    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false

    @State private var sceneFrame: CGRect = .zero
    @State private var paletteFrame: CGRect = .zero

    @State private var toast: BTToastMessage?

    private static let paletteColumns = 8
    /// G10：顶栏 / 底栏固定高度 ⇒ scene 区域高度恒定 ⇒ 球桌渲染尺寸锁定。
    private static let topRowHeight: CGFloat = 46
    private static let bottomBarHeight: CGFloat = 94

    /// 默认教学球形：母球左下、黑 8 靠右上角袋（沿用 v2 的 placeBallsAtDefaults 坐标）。
    private static var defaultBoard: BoardSnapshot {
        let y = BTTablePhysics.surfaceY + AngleSceneCalculator.ballRadius
        let cueN = AngleSceneCalculator.sceneToNormalized(position: SCNVector3(-0.35, y, 0.22))
        let tgtN = AngleSceneCalculator.sceneToNormalized(position: SCNVector3(0.55, y, -0.18))
        return BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: Double(cueN.x), y: Double(cueN.y)),
            "_8": CanvasPoint(x: Double(tgtN.x), y: Double(tgtN.y)),
        ])
    }

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
                if let key = draggingKey { dragGhost(key) }
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showSpinPad)
        .btToast($toast)
        .coordinateSpace(name: "simulation")
        .onPreferenceChange(SimulationFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
        .navigationTitle("分离角与走位")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) { navStatus }
            ToolbarItem(placement: .topBarTrailing) { moreMenu }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.maxTargetBalls = 2
                vm.setupScene()
                vm.loadBoard(Self.defaultBoard)
            }
        }
    }

    // MARK: - Stage（scene + 贴边控件，G3–G11 走 ShotStageProxy）

    private func stage(_ proxy: ShotStageProxy) -> some View {
        ZStack(alignment: .topLeading) {
            sceneContainer

            if proxy.isValid {
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

                // G6 开球按钮（本页无开球，禁用态）：左下角，底边齐球桌底线。
                BTBreakSideButton(isEnabled: false) {}
                    .btStageFrame(proxy.breakButtonFrame())

                // G4/G5/G7 打点+力度仪表柱：左缘贴球桌右侧、力度条本体底部对齐。
                BTShotInstrumentColumn(
                    spinX: vm.spinX, spinY: vm.spinY,
                    onSpinTap: { showSpinPad = true },
                    velocity: $vm.velocity,
                    range: ShotTuning.velocityRange,
                    isDisabled: vm.isPlaying
                )
                .btStageFrame(proxy.instrumentFrame())

                // 18.2 击球/上一杆/回放：右下角，底边齐球桌底线。
                BTShotActionColumn(
                    strikeTitle: vm.isPlaying ? "击球中" : "击球",
                    strikeEnabled: strikeEnabled,
                    onStrike: { vm.play() },
                    undoEnabled: !vm.isPlaying && vm.canReplay,
                    onUndo: { vm.replayCurrent() },
                    playbackEnabled: !vm.isPlaying && vm.canPlayback,
                    onPlayback: { vm.replayLastShot() }
                )
                .btStageFrame(proxy.actionColumnFrame())
            }

            if showSpinPad {
                BTSpinPadOverlay(spinX: $vm.spinX, spinY: $vm.spinY,
                                 onClose: { showSpinPad = false })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    // MARK: - Scene container

    private var sceneContainer: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            interactionMode: .tapsOnly,
            autoFitsRotatedTable: true,
            onPocketTapped: { vm.selectPocket(at: $0) },
            draggableBallNodes: vm.draggableBalls,
            onDragBegan: { vm.dragBegan(node: $0) },
            onDragMoved: { vm.dragMoved(node: $0, worldPosition: $1) },
            onDragEnded: { vm.dragEnded(node: $0) },
            onDragEndedAt: { node, localPoint in
                handleTableDragEnd(node: node, localPoint: localPoint)
            },
            selectableBallNodes: vm.selectableBalls,
            onBallTapped: { vm.selectTarget(node: $0) },
            onTableTapped: { vm.handleTableTap(world: $0) },
            onAimNudged: { vm.nudgeFreeAim(byDegrees: $0) },
            projector: projector
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(frameReader(id: "scene"))
        .clipped()
    }

    // MARK: - Nav status

    private var navStatus: some View {
        VStack(spacing: 1) {
            Text("分离角与走位")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.btPrimary)
                .lineLimit(1)
            HStack(spacing: 4) {
                if vm.isComputing {
                    ProgressView().controlSize(.mini).tint(.white)
                }
                Text(vm.isComputing ? "求解中…" : vm.statusText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Top info row

    private var topInfoRow: some View {
        HStack(spacing: Spacing.sm) {
            // 条 17.1：自动/手动 → 进袋/自由 单按钮点击切换。
            BTAimModeToggleButton(isFree: vm.aimMode == .free,
                                  isDisabled: vm.isPlaying) {
                vm.toggleAimMode()
            }

            aimCapsule

            if vm.cuePocketed { scratchPill }

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

    // MARK: - Bottom bar (条 18：底部只留球库)

    private func bottomBar(_ proxy: ShotStageProxy) -> some View {
        paletteBar(proxy)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(HUDStyle.panelBackground)
            .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
            .background(frameReader(id: "palette"))
            .environment(\.colorScheme, .dark)
    }

    private var strikeEnabled: Bool {
        !vm.isPlaying && !vm.isComputing && vm.isFeasible
    }

    // MARK: - Palette bar（条 17.2/17.4：球库开放，摆球上限 2 由 VM 校验；G8 总宽=球桌宽）

    private func paletteBar(_ proxy: ShotStageProxy) -> some View {
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
        DragGesture(minimumDistance: 10, coordinateSpace: .named("simulation"))
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
                Button("重置默认球形", systemImage: "arrow.counterclockwise") {
                    vm.loadBoard(Self.defaultBoard)
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func flash(_ message: String, tone: BTToastTone = .success) {
        withAnimation(BTMotion.easeChrome) {
            toast = BTToastMessage(message, tone: tone)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + BTToast.defaultDuration) {
            withAnimation(BTMotion.easeChrome) {
                if toast?.text == message { toast = nil }
            }
        }
    }

    // MARK: - Frame reader

    private func frameReader(id: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: SimulationFramePreference.self,
                                   value: [id: geo.frame(in: .named("simulation"))])
        }
    }
}

// MARK: - Frame preference

private struct SimulationFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

#Preview("Dark") {
    NavigationStack { ShotSimulationView() }
        .preferredColorScheme(.dark)
}
