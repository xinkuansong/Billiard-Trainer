import SwiftUI
import SceneKit

/// 「分离角图谱」（v11 Y3 / v15 W1）：学分段交互页——同一杆 8 种高低杆碰后轨迹对比。
///
/// 布局：`ShotStageProxy` 定高锁桌（G10）+ 右缘纯力度柱（G5，`onSpinTap=nil`）
/// + 左缘 8 可点选迷你打点盘（`aimWheelFrame`，开关对应色轨迹）+ 底栏 `BTBallPaletteBar`（点+拖）。
struct SeparationAngleAtlasView: View {
    @StateObject private var vm = SeparationAngleAtlasViewModel()
    @State private var hasAppeared = false

    @State private var projector = TableProjector()
    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false
    @State private var sceneFrame: CGRect = .zero
    @State private var paletteFrame: CGRect = .zero

    private static let topRowHeight = ShotStageMetrics.topRowHeight
    private static let bottomBarHeight = ShotStageMetrics.BottomBarHeight.composer.rawValue
    private static let coordinateSpace = "separationAngleAtlas"

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
                    topChipRow
                        .frame(height: Self.topRowHeight)
                    stage(proxy)
                        .frame(height: sceneH)
                    bottomBar(proxy)
                        .frame(height: Self.bottomBarHeight)
                }
                if let key = draggingKey {
                    BTBallPaletteDragGhost(key: key, location: dragLocation, overTable: dragOverTable)
                }
            }
        }
        .coordinateSpace(name: Self.coordinateSpace)
        .onPreferenceChange(BTShotPageFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
        .btDarkToolChrome("分离角图谱")
        .toolbar {
            ToolbarItem(placement: .principal) {
                BTSolverNavStatus(
                    title: "分离角图谱",
                    isBusy: vm.isComputing,
                    statusText: vm.statusText
                )
            }
            ToolbarItem(placement: .topBarTrailing) {
                BTSolverMoreMenu(scene: vm.scene, labelOpacity: 0.7)
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
            }
        }
        .onChange(of: vm.velocity) { _, _ in
            vm.onVelocityChanged()
        }
        .background(
            Color.clear
                .accessibilityIdentifier("separationAngleAtlas.root")
        )
    }

    // MARK: - Top

    private var topChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                metricItem(label: "切角",
                           value: vm.cutAngleDegrees > 0
                           ? "\(Int(vm.cutAngleDegrees.rounded()))°" : "—°")
                BTHudMetricSeparator()
                metricItem(label: "力度",
                           value: String(format: "%.1f", vm.velocity))
                BTHudMetricSeparator()
                Text("已选 \(vm.enabledTracks.count)/8 · 高低杆碰后→第一库")
                    .font(HUDStyle.labelFontCompact)
                    .foregroundStyle(HUDStyle.labelColor)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .btHudGlass()
            .padding(.horizontal, Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .infinity, alignment: .center)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }

    private func metricItem(label: String, value: String) -> some View {
        BTReadout(label: label, value: value)
            .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Stage

    private func stage(_ proxy: ShotStageProxy) -> some View {
        ZStack(alignment: .topLeading) {
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
                onBallTapped: { node in
                    if let key = vm.scene.ballKey(for: node) {
                        vm.selectTarget(key: key)
                    }
                },
                projector: projector
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(frameReader(id: "scene"))
            .clipped()

            if proxy.isValid {
                // A2：左缘 8 迷你打点盘（高→低自上而下；点选开关对应色轨迹）
                SeparationAngleAtlasSpinLegend(
                    enabledTracks: vm.enabledTracks,
                    onToggle: { vm.toggleTrack($0) }
                )
                    .btStageFrame(proxy.aimWheelFrame())
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("separationAngleAtlas.spinLegend")
                    .zIndex(2)

                // 右缘纯力度柱（打点盘已退役至左缘图例；onSpinTap=nil）
                BTShotInstrumentColumn(
                    spinX: vm.displaySpinX,
                    spinY: vm.displaySpinY,
                    onSpinTap: nil,
                    velocity: $vm.velocity,
                    range: ShotTuning.velocityRange
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("solver.power")
                .accessibilityLabel("力度")
                .accessibilityValue(String(format: "%.1f", vm.velocity))
                .accessibilityAdjustableAction { direction in
                    let step = 1.0
                    switch direction {
                    case .increment:
                        vm.velocity = min(ShotTuning.velocityRange.upperBound,
                                          vm.velocity + step)
                    case .decrement:
                        vm.velocity = max(ShotTuning.velocityRange.lowerBound,
                                          vm.velocity - step)
                    @unknown default: break
                    }
                }
                .zIndex(2)
                .btStageFrame(proxy.instrumentFrame())
            }

            // UI 测钩子：SceneKit 叠层下合成拖力度柱不可靠；显式 bump 验证「高力度轨迹变化」。
            if ProcessInfo.processInfo.arguments.contains("-y3.uiHooks") {
                Button {
                    vm.velocity = 5.5
                    vm.onVelocityChanged()
                } label: {
                    Text("高力度")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.btPrimary.opacity(0.85), in: Capsule())
                }
                .accessibilityIdentifier("y3.bumpPower")
                .position(x: 52, y: 36)
                .zIndex(5)

                // 性能取证读数：最近一次 8×simulateFree 并行耗时（ms）。
                Text(String(format: "%.1f", vm.lastParallelSimMs))
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.4))
                    .accessibilityIdentifier("y3.parallelSimMs")
                    .position(x: 52, y: 60)
                    .zIndex(5)
            }
        }
    }

    // MARK: - Bottom (BTBallPaletteBar：点击 + 拖放)

    private func bottomBar(_ proxy: ShotStageProxy) -> some View {
        let libraryWidth = proxy.libraryWidth
        return VStack(spacing: 2) {
            Text("点/拖球库上桌 · 拖回库撤下 · 点台面换目标 · 点左侧白球开关轨迹")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            BTBallPaletteBar(
                coordinateSpace: Self.coordinateSpace,
                ballDiameter: proxy.paletteBallDiameter,
                libraryWidth: libraryWidth,
                isOnTable: { vm.onTableKeys.contains($0) },
                sceneFrame: sceneFrame,
                unproject: { projector.unproject?($0) },
                onTap: { key in
                    if PositionPlayBall.isCue(key), vm.onTableKeys.contains(key) {
                        vm.pulseTableBall(key)
                    } else if vm.onTableKeys.contains(key) {
                        // 角度与瞄准语义：在桌非母球 → 撤下
                        vm.removeFromTable(key)
                    } else {
                        vm.placeFromPalette(key)
                    }
                },
                onPlace: { key, world in
                    if let world { vm.placeFromPalette(key, atWorld: world) }
                    else { vm.placeFromPalette(key) }
                },
                draggingKey: $draggingKey,
                dragLocation: $dragLocation,
                dragOverTable: $dragOverTable
            )
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.11))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
        .background(frameReader(id: "palette"))
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Table ball dragged back to palette → remove

    private func handleTableDragEnd(node: SCNNode, localPoint: CGPoint) {
        guard BTBallPaletteDragBack.hitPalette(localPoint: localPoint,
                                               sceneFrame: sceneFrame,
                                               paletteFrame: paletteFrame),
              let key = vm.scene.ballKey(for: node) else { return }
        vm.removeFromTable(key)
    }

    private func frameReader(id: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: BTShotPageFramePreference.self,
                                   value: [id: geo.frame(in: .named(Self.coordinateSpace))])
        }
    }
}

// MARK: - Left-edge 8 mini spin pads (A2 / D-v15-2)

/// 左缘竖列 8 个迷你打点盘：每档一点、与 `trackColors`/spinY 档一一对应。
/// 高杆（index 0）在上 → 低杆（index 7）在下；点选开关对应色轨迹。
private struct SeparationAngleAtlasSpinLegend: View {
    let enabledTracks: Set<Int>
    let onToggle: (Int) -> Void

    private let levels = SeparationAngleAtlasGeometry.spinYLevels()
    private let pull = Double(CuePhysics.tipContactPullFactor)
    private let miscue = Double(CuePhysics.miscueLimitFraction)

    var body: some View {
        GeometryReader { geo in
            let count = levels.count
            let spacing: CGFloat = 3
            let pad = max(min(geo.size.width - 2, (geo.size.height - spacing * CGFloat(count - 1)) / CGFloat(count)), 16)
            VStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    miniPad(index: i, size: pad)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityLabel("8 档高低杆色序，点选开关轨迹，高杆在上低杆在下，至少留一档")
    }

    private func miniPad(index: Int, size: CGFloat) -> some View {
        let sy = Double(levels[index])
        let placeY = sy / pull
        let ballR = size / 2 - 1
        let placementLimit = miscue / pull
        let dy = -CGFloat(placeY) * ballR
        let enabled = enabledTracks.contains(index)
        return Button {
            onToggle(index)
        } label: {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.white, Color(white: 0.86)],
                                         center: .init(x: 0.38, y: 0.34),
                                         startRadius: 1, endRadius: ballR * 2))
                    .overlay(Circle().stroke(.white.opacity(enabled ? 0.45 : 0.22), lineWidth: 0.8))
                Circle()
                    .stroke(.black.opacity(0.28), style: StrokeStyle(lineWidth: 0.7, dash: [2, 2]))
                    .frame(width: ballR * 2 * CGFloat(placementLimit),
                           height: ballR * 2 * CGFloat(placementLimit))
                Circle()
                    .fill(Color(uiColor: SeparationAngleAtlasGeometry.trackColor(at: index)))
                    .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 0.8))
                    .frame(width: max(size * 0.22, 4), height: max(size * 0.22, 4))
                    .offset(y: dy)
            }
            .frame(width: size, height: size)
            .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("separationAngleAtlas.spinLegend.\(index)")
        .accessibilityAddTraits(enabled ? .isSelected : [])
        .accessibilityValue(enabled ? "已选" : "未选")
    }
}
