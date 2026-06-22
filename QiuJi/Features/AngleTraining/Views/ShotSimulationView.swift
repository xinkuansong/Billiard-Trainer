import SwiftUI
import SceneKit

/// 分离角与轨迹动态演示页：拖动摆球、点选目标袋口，调节速度与塞，
/// 后台实时预测母球/目标球轨迹与瞄准夹角；可一键播放球沿轨迹真实运动，播放后复位并恢复轨迹。
///
/// 布局（与走位编排台同语言，ADR-P11-09）：球桌全宽零叠层；底部条 = 控制行
/// （打点小图标 + 连续力度滑条）+ 右侧「重置 / 击球」操作钮；点打点图标弹出打点盘 sheet。
struct ShotSimulationView: View {
    @StateObject private var vm = ShotSimulationViewModel()
    @State private var hasAppeared = false
    @State private var showSpinPad = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    sceneLayer
                    // 打点盘浮层贴球桌底缘：半透明材质透出桌面绿色（系统 sheet 底下是
                    // 纯黑+压暗层会显得过深，用户点名要这种「有些透明」的观感）。
                    if showSpinPad {
                        spinPadCard
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                bottomBar
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showSpinPad)
        .safeAreaInset(edge: .top, spacing: 0) { topCard }
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
            autoFitsRotatedTable: true,
            onPocketTapped: { vm.selectPocket(at: $0) },
            draggableBallNodes: vm.draggableBalls,
            onDragBegan: { vm.dragBegan(node: $0) },
            onDragMoved: { vm.dragMoved(node: $0, worldPosition: $1) },
            onDragEnded: { vm.dragEnded(node: $0) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - Top result card

    /// 顶部指标胶囊（统一设计语言，ADR-P11-07/08）：与「角度与打点 / 2D / 反射 / 翻袋」
    /// 同款单行 capsule，统一左对齐 —— 瞄准夹角 + 状态 + 计算中指示。
    private var topCard: some View {
        HStack {
            topCapsule
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
    }

    private var topCapsule: some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: 4) {
                Text("夹角")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Text(vm.cutAngleDeg.map { String(format: "%.0f°", $0) } ?? "—")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 14)

            HStack(spacing: 4) {
                Image(systemName: statusIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(statusTint)
                Text(vm.statusText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if vm.isComputing {
                ProgressView().scaleEffect(0.6).tint(.white.opacity(0.6))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
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

    // MARK: - Bottom bar（与走位编排台同语言：控制行 + 右侧操作钮，ADR-P11-09）

    private var bottomBar: some View {
        HStack(spacing: Spacing.sm) {
            Button { showSpinPad = true } label: {
                BTSpinMiniIcon(spinX: vm.spinX, spinY: vm.spinY, diameter: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打点")
            .disabled(vm.isPlaying)

            Slider(value: $vm.velocity, in: 0.5...6.0, step: 0.1)
                .tint(Color.btPrimary)
                .disabled(vm.isPlaying)

            Text("\(PowerDisplay.name(vm.velocity)) \(String(format: "%.1f", vm.velocity))")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(width: 58, alignment: .trailing)

            Button { vm.reset() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 43, height: 42)
                    .background(.white.opacity(0.14), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重置")
            .disabled(vm.isPlaying)

            Button { vm.play() } label: {
                HStack(spacing: 5) {
                    CueStickShape().frame(width: 15, height: 15).foregroundStyle(.white)
                    Text(vm.isPlaying ? "击球中" : "击球")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 92, height: 42)
                .background(playEnabled ? Color.btPrimary : Color.btPrimary.opacity(0.3),
                            in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!playEnabled)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .background(Color(white: 0.11))
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .environment(\.colorScheme, .dark)
    }

    private var playEnabled: Bool {
        !vm.isPlaying && vm.isFeasible
    }

    // MARK: - Spin pad card（浮在球桌上的半透明卡片，与旧「击球设置」HUD 同材质）

    private var spinPadCard: some View {
        BTSpinPadCard(
            spinX: $vm.spinX,
            spinY: $vm.spinY,
            onClose: { showSpinPad = false }
        )
        .frame(maxWidth: 240)
        .padding(.bottom, 80)
    }
}

#Preview("Dark") {
    NavigationStack { ShotSimulationView() }
        .preferredColorScheme(.dark)
}
