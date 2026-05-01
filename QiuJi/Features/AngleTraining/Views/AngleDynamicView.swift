import SwiftUI
import SceneKit

struct AngleDynamicView: View {
    @StateObject private var vm = AngleDynamicViewModel()
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            sceneFullscreen
            overlayLayer
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            // 横向滚动兜底：极窄设备（如 iPhone SE）也能完整看到所有指标
            ScrollView(.horizontal, showsIndicators: false) {
                primaryMetricChip
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xs)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle("角度与打点")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
            }
        }
    }

    // MARK: - Scene (fullscreen)

    private var sceneFullscreen: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            interactionMode: .tapsOnly,
            onPocketTapped: { index in
                vm.selectPocket(at: index)
            },
            draggableBallNodes: vm.draggableBalls,
            onDragBegan: { node in vm.dragBegan(node: node) },
            onDragMoved: { node, pos in vm.dragMoved(node: node, worldPosition: pos) },
            onDragEnded: { node in vm.dragEnded(node: node) }
        )
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Floating overlays (status banner only — all metrics live in the top chip)

    private var overlayLayer: some View {
        VStack {
            Spacer()
            if let banner = statusBannerText {
                statusBanner(text: banner.0, icon: banner.1, tint: banner.2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
        .animation(.easeInOut(duration: 0.25), value: statusBannerKey)
        .allowsHitTesting(false)
    }

    // MARK: - Primary metric chip (常驻：角度 / 厚度图示 / d/R / 横移 / 偏移 一排展示)

    private var primaryMetricChip: some View {
        let hasSelection = vm.selectedPocketIndex >= 0
        return HStack(spacing: Spacing.sm) {
            metricItem(icon: "angle",
                       value: hasSelection ? "\(Int(vm.cutAngleDegrees.rounded()))°" : "—°")
            divider
            thicknessItem(cutAngle: vm.cutAngleDegrees, enabled: hasSelection)
            divider
            metricItem(label: "d/R",
                       value: hasSelection ? String(format: "%.2f", vm.dOverR) : "—")
            divider
            metricItem(label: "横移",
                       value: hasSelection ? String(format: "%.1fmm", vm.displacementMM) : "—")
            divider
            metricItem(label: "偏移",
                       value: hasSelection ? String(format: "%.0f%%", vm.offsetPercent) : "—")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }

    @ViewBuilder
    private func metricItem(icon: String? = nil, label: String? = nil, value: String) -> some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            if let label {
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    /// 厚度指标：用两个互相错位的球图形表示重叠度，并附上厚度名称（极薄/半球…）。
    @ViewBuilder
    private func thicknessItem(cutAngle: Double, enabled: Bool) -> some View {
        HStack(spacing: 4) {
            ThicknessOverlapIcon(cutAngle: enabled ? cutAngle : 0)
                .frame(width: 26, height: 14)
                .opacity(enabled ? 1 : 0.4)
            Text(enabled ? AngleSceneCalculator.thicknessName(cutAngle: cutAngle) : "—")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("厚度 \(enabled ? AngleSceneCalculator.thicknessName(cutAngle: cutAngle) : "未选择")")
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 12)
    }

    // MARK: - Status banner (bottom)

    private var statusBannerKey: String {
        if vm.isDragging { return "drag" }
        if vm.selectedPocketIndex < 0 { return "hint" }
        if !vm.isFeasible { return "infeasible:\(vm.infeasibleReason)" }
        return ""
    }

    /// Returns text/icon/tint when a banner should appear; nil otherwise.
    private var statusBannerText: (String, String, Color)? {
        if vm.isDragging {
            return ("拖动中…", "hand.draw.fill", .btPrimary)
        }
        if vm.selectedPocketIndex < 0 {
            return ("点击袋口选择目标", "scope", .white.opacity(0.7))
        }
        if !vm.isFeasible {
            return (vm.infeasibleReason, "exclamationmark.triangle.fill", .btDestructive)
        }
        return nil
    }

    private func statusBanner(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
            Text(text)
                .font(.btSubheadlineMedium)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(
            // 双层背景：底层近黑色保证对比度，上层 thinMaterial 提供毛玻璃质感。
            ZStack {
                Color.black.opacity(0.72)
                Rectangle().fill(.thinMaterial)
            }
        )
        .environment(\.colorScheme, .dark)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
    }
}

// MARK: - Thickness Overlap Icon

/// 用两个等大圆形错位重叠表示"厚度"：
/// 在击球瞬间，沿瞄准方向看，目标球与白球的中心横向偏移量为 `2R · sin(α)`。
/// 把它直接映射到画布即可：α 越小重叠越多 ("厚")，α 越大错位越多 ("薄")。
private struct ThicknessOverlapIcon: View {
    /// 切球角，单位：度。
    let cutAngle: Double

    var body: some View {
        Canvas { ctx, size in
            // 单球半径选择：让最大错位（α=90°，offset=2R）时两球刚好首尾相接、不出画布。
            // 因此 r = size.width / 4。再做一次 0.96 收缩留 1px 描边的余量。
            let r = (size.width / 4) * 0.96
            let centerY = size.height / 2

            let alphaRad = max(0, min(90, cutAngle)) * .pi / 180
            let offset = CGFloat(2 * r * sin(alphaRad))  // 球心横向偏移量

            // 让两个球关于画布中心对称错开：目标球居左、白球居右。
            let targetCenter = CGPoint(x: size.width / 2 - offset / 2, y: centerY)
            let cueCenter    = CGPoint(x: size.width / 2 + offset / 2, y: centerY)

            // 目标球（暖色）：实心 + 描边
            let targetRect = CGRect(x: targetCenter.x - r, y: targetCenter.y - r,
                                    width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: targetRect),
                     with: .color(Color(red: 0.96, green: 0.65, blue: 0.14)))
            ctx.stroke(Path(ellipseIn: targetRect),
                       with: .color(.white.opacity(0.5)), lineWidth: 0.5)

            // 白球：实心白 + 微弱描边，覆盖在目标球之上以呈现"被遮挡"的厚度
            let cueRect = CGRect(x: cueCenter.x - r, y: cueCenter.y - r,
                                 width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: cueRect), with: .color(.white))
            ctx.stroke(Path(ellipseIn: cueRect),
                       with: .color(.white.opacity(0.6)), lineWidth: 0.5)
        }
    }
}

#Preview("Light") {
    NavigationStack { AngleDynamicView() }
}

#Preview("Dark") {
    NavigationStack { AngleDynamicView() }
        .preferredColorScheme(.dark)
}
