import SwiftUI
import SceneKit

/// 「分离角图谱」（v11 Y3）：学分段交互页——同一杆 8 种高低杆碰后轨迹对比。
///
/// 布局：`ShotStageProxy` 定高锁桌（G10）+ 右缘 `BTShotInstrumentColumn` 贴边同底（G5）。
/// 打点盘只读展示 8 个纵向采样点（与 8 色轨迹同色）；力度可调。
struct SeparationAngleAtlasView: View {
    @StateObject private var vm = SeparationAngleAtlasViewModel()
    @State private var hasAppeared = false

    private static let topRowHeight = ShotStageMetrics.topRowHeight
    private static let bottomBarHeight = ShotStageMetrics.BottomBarHeight.paletteOnly.rawValue

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
                    bottomHint
                        .frame(height: Self.bottomBarHeight)
                }
            }
        }
        .navigationTitle("分离角图谱")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
                Text("8 档高低杆 · 碰后→第一库")
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
                onDragEnded: { vm.dragEnded(node: $0) }
            )
            .clipped()

            if proxy.isValid {
                BTShotInstrumentColumn(
                    spinX: vm.displaySpinX,
                    spinY: vm.displaySpinY,
                    onSpinTap: { vm.toggleSpinPad() },
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

            if vm.showSpinPad {
                SeparationAngleAtlasSpinPadOverlay(onClose: { vm.closeSpinPad() })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
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
        .animation(BTMotion.springPanel, value: vm.showSpinPad)
    }

    // MARK: - Bottom

    private var bottomHint: some View {
        Text("拖母球/目标球改切角 · 调力度看分离轨迹 · 打点盘只读展示 8 档")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.55))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.11))
            .overlay(alignment: .top) {
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
            }
            .environment(\.colorScheme, .dark)
    }
}

// MARK: - Read-only 8-dot spin pad

/// 只读打点盘：纵向 8 个采样点与页内色板同色对应，不可拖（D-v11-3）。
private struct SeparationAngleAtlasSpinPadOverlay: View {
    var onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture { onClose() }
            VStack(spacing: Spacing.sm) {
                Text("8 档打点（只读）")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                SeparationAngleAtlasSpinPad()
                    .frame(width: 140, height: 140)
                    .accessibilityIdentifier("separationAngleAtlas.spinPad")
                Text("高杆 ↑ · 低杆 ↓ · 与台面轨迹同色")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: BTRadius.xl, style: .continuous)
                    .fill(Color.black.opacity(0.22))
                    .background(RoundedRectangle(cornerRadius: BTRadius.xl, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.5)))
                    .environment(\.colorScheme, .dark)
            }
            .overlay(RoundedRectangle(cornerRadius: BTRadius.xl, style: .continuous)
                .strokeBorder(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
            .padding(.bottom, 80)
            .environment(\.colorScheme, .dark)
        }
    }
}

private struct SeparationAngleAtlasSpinPad: View {
    private let miscue = Double(CuePhysics.miscueLimitFraction)
    private let pull = Double(CuePhysics.tipContactPullFactor)
    private let levels = SeparationAngleAtlasGeometry.spinYLevels()

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cx = geo.size.width / 2, cy = geo.size.height / 2
            let ballR = size / 2 - 2
            let placementLimit = miscue / pull
            let miscueR = ballR * CGFloat(placementLimit)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.white, Color(white: 0.86)],
                                         center: .init(x: 0.38, y: 0.34),
                                         startRadius: 2, endRadius: ballR * 2))
                    .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                    .frame(width: ballR * 2, height: ballR * 2)
                    .position(x: cx, y: cy)
                Path { p in
                    p.move(to: CGPoint(x: cx, y: cy - ballR))
                    p.addLine(to: CGPoint(x: cx, y: cy + ballR))
                    p.move(to: CGPoint(x: cx - ballR, y: cy))
                    p.addLine(to: CGPoint(x: cx + ballR, y: cy))
                }
                .stroke(.black.opacity(0.14), lineWidth: 1)
                Circle()
                    .stroke(.black.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: miscueR * 2, height: miscueR * 2)
                    .position(x: cx, y: cy)
                ForEach(0..<levels.count, id: \.self) { i in
                    let sy = Double(levels[i])
                    let placeY = sy / pull
                    let dy = -CGFloat(placeY) * ballR
                    Circle()
                        .fill(Color(uiColor: SeparationAngleAtlasGeometry.trackColor(at: i)))
                        .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1))
                        .frame(width: 10, height: 10)
                        .position(x: cx, y: cy + dy)
                }
            }
            .allowsHitTesting(false)
        }
    }
}
