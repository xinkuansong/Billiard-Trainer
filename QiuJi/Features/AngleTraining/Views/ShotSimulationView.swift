import SwiftUI
import SceneKit

/// 分离角与轨迹动态演示页：拖动摆球、点选目标袋口，调节速度与塞，
/// 后台实时预测母球/目标球轨迹与瞄准夹角；可一键播放球沿轨迹真实运动，播放后复位并恢复轨迹。
///
/// 布局：球桌全屏不被长期遮挡；右侧竖排「调整 / 重置 / 播放」圆形按钮；
/// 点「调整」从底部弹出 HUD（打点盘 + 5 档速度），改完收起。
struct ShotSimulationView: View {
    @StateObject private var vm = ShotSimulationViewModel()
    @State private var hasAppeared = false
    @State private var showHUD = false
    /// 弹出的 HUD 卡片高度（实测），用于把侧边按钮顶到 HUD 上方紧贴。
    @State private var hudHeight: CGFloat = 0

    var body: some View {
        ZStack {
            sceneLayer
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) { topCard }
        .overlay(alignment: .bottomTrailing) { sideButtons }
        .overlay(alignment: .bottom) { hudLayer }
        .onPreferenceChange(HUDHeightKey.self) { hudHeight = $0 }
        .navigationTitle("分离角与走位")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
            }
        }
    }

    // MARK: - Scene

    private var sceneLayer: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            interactionMode: .tapsOnly,
            onPocketTapped: { vm.selectPocket(at: $0) },
            draggableBallNodes: vm.draggableBalls,
            onDragBegan: { vm.dragBegan(node: $0) },
            onDragMoved: { vm.dragMoved(node: $0, worldPosition: $1) },
            onDragEnded: { vm.dragEnded(node: $0) }
        )
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Top result card

    private var topCard: some View {
        HStack(spacing: Spacing.md) {
            // 瞄准夹角（瞄准线 ∠ 进球线）
            VStack(spacing: 2) {
                Text("瞄准夹角")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Text(vm.cutAngleDeg.map { String(format: "%.0f°", $0) } ?? "—")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(width: 64)

            Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 36)

            // 状态
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(statusTint)
                Text(vm.statusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if vm.isComputing {
                    ProgressView().scaleEffect(0.7).tint(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BTRadius.lg))
        .environment(\.colorScheme, .dark)
        .overlay(RoundedRectangle(cornerRadius: BTRadius.lg).stroke(.white.opacity(0.08), lineWidth: 0.5))
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
    }

    private var statusIcon: String {
        if !vm.isFeasible { return "xmark.octagon.fill" }
        if vm.cuePocketed { return "exclamationmark.triangle.fill" }
        if vm.objectPocketed { return "checkmark.circle.fill" }
        return "scope"
    }

    private var statusTint: Color {
        if !vm.isFeasible || vm.cuePocketed { return .btDestructive }
        if vm.objectPocketed { return .btSuccess }
        return .white.opacity(0.7)
    }

    // MARK: - Side action buttons

    private var sideButtons: some View {
        VStack(spacing: Spacing.md) {
            circleButton(
                icon: showHUD ? "slider.horizontal.3" : "slider.horizontal.3",
                label: "调整",
                tint: showHUD ? Color.btPrimary : Color.white.opacity(0.16),
                fg: .white
            ) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { showHUD.toggle() }
            }
            .disabled(vm.isPlaying)

            circleButton(
                icon: "arrow.counterclockwise",
                label: "重置",
                tint: Color.white.opacity(0.16),
                fg: .white
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { showHUD = false }
                vm.reset()
            }
            .disabled(vm.isPlaying)

            circleButton(
                icon: "play.fill",
                label: vm.isPlaying ? "击球中" : "击球",
                tint: playEnabled ? Color.btPrimary : Color.btPrimary.opacity(0.35),
                fg: .white
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { showHUD = false }
                vm.play()
            }
            .disabled(!playEnabled)
        }
        .padding(.trailing, Spacing.md)
        // HUD 弹出时把按钮组顶到 HUD 顶缘上方约 8pt（播放按钮几乎贴住 HUD）；收起时靠下放置。
        .padding(.bottom, showHUD ? hudHeight + 8 : 28)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showHUD)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: hudHeight)
    }

    @ViewBuilder
    private func circleButton(icon: String, label: String, tint: Color, fg: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(fg)
            .frame(width: 56, height: 56)
            .background(tint, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var playEnabled: Bool {
        !vm.isPlaying && vm.isFeasible
    }

    // MARK: - HUD (spin pad + speed)

    @ViewBuilder
    private var hudLayer: some View {
        if showHUD {
            hudCard
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var hudCard: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("击球设置")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { showHUD = false }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .center, spacing: Spacing.lg) {
                // 击球点（塞）
                VStack(spacing: 6) {
                    SpinPadView(spinX: $vm.spinX, spinY: $vm.spinY)
                        .frame(width: 92, height: 92)
                    HStack(spacing: Spacing.md) {
                        spinReadout(label: "高低", value: vm.spinY, plus: "高", minus: "低")
                        spinReadout(label: "左右", value: vm.spinX, plus: "左", minus: "右")
                    }
                }

                // 速度（5 档）
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Label("速度", systemImage: "speedometer")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                    speedSelector
                }
            }
        }
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BTRadius.xl))
        .environment(\.colorScheme, .dark)
        .overlay(RoundedRectangle(cornerRadius: BTRadius.xl).stroke(.white.opacity(0.08), lineWidth: 0.5))
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: HUDHeightKey.self, value: proxy.size.height)
            }
        )
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    private var speedSelector: some View {
        HStack(spacing: 6) {
            ForEach(StrokePhysics.SpeedLevel.allCases) { level in
                let selected = vm.speedLevel == level
                Button {
                    vm.speedLevel = level
                } label: {
                    Text(level.label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected ? .white : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            selected ? Color.btPrimary : Color.white.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: BTRadius.sm)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func spinReadout(label: String, value: Double, plus: String, minus: String) -> some View {
        let mag = Int((abs(value) * 100).rounded())
        let tag: String = mag == 0 ? "无" : "\(value > 0 ? plus : minus)\(mag)%"
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            Text(tag)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(mag == 0 ? .white.opacity(0.5) : Color.btPrimary)
                .monospacedDigit()
        }
    }
}

// MARK: - HUD height preference

/// 把弹出的 HUD 卡片实测高度上报给父视图，用于定位侧边按钮。
private struct HUDHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Spin Pad

/// 打点盘：圆形母球示意，拖动选择击球点 (spinX 左右塞, spinY 高低杆)，范围限制在单位圆内。
/// 击球点圆点使用**红色**（贴近真实白球上的红色定位点）。
private struct SpinPadView: View {
    @Binding var spinX: Double
    @Binding var spinY: Double

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let r = size / 2
            let inset: CGFloat = 10
            // spinX 正=左塞→屏幕左；spinY 正=高杆→屏幕上
            let dot = CGPoint(
                x: r - CGFloat(spinX) * (r - inset),
                y: r - CGFloat(spinY) * (r - inset)
            )
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, Color(white: 0.86)],
                            center: .init(x: 0.38, y: 0.34), startRadius: 2, endRadius: size
                        )
                    )
                    .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                Path { p in
                    p.move(to: CGPoint(x: r, y: 8)); p.addLine(to: CGPoint(x: r, y: size - 8))
                    p.move(to: CGPoint(x: 8, y: r)); p.addLine(to: CGPoint(x: size - 8, y: r))
                }
                .stroke(.black.opacity(0.16), lineWidth: 1)
                Circle()
                    .fill(Color.red)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .position(dot)
                    .shadow(color: .black.opacity(0.35), radius: 2)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let nx = Double((r - value.location.x) / (r - inset))
                        let ny = Double((r - value.location.y) / (r - inset))
                        let mag = (nx * nx + ny * ny).squareRoot()
                        if mag > 1 {
                            spinX = nx / mag
                            spinY = ny / mag
                        } else {
                            spinX = max(-1, min(1, nx))
                            spinY = max(-1, min(1, ny))
                        }
                    }
            )
        }
    }
}

#Preview("Dark") {
    NavigationStack { ShotSimulationView() }
        .preferredColorScheme(.dark)
}
