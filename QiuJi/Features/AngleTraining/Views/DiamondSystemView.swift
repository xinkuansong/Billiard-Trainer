import SwiftUI
import SceneKit

/// 反射解球器 — 2D top-down bank/kick-shot solver.
/// Place the cue & target balls anywhere; the app solves the minimum-cushion
/// pure-reflection trajectory between them and lets you cycle through alternatives.
struct DiamondSystemView: View {
    @StateObject private var vm = DiamondSystemViewModel()
    @State private var showInfo = false
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            sceneFullscreen
            overlayLayer
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) { topInset }
        .navigationTitle("反射解球器")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(.white.opacity(0.75))
                }
                .accessibilityLabel("原理")
            }
        }
        .sheet(isPresented: $showInfo) {
            ReflectionSolverInfoSheet().presentationDetents([.medium, .large])
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
            }
        }
    }

    // MARK: - Scene

    private var sceneFullscreen: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: .constant(.topDown2DRotated),
            interactionMode: .tapsOnly,
            autoFitsRotatedTable: true,
            draggableBallNodes: vm.draggableNodes,
            onDragBegan: { node in vm.dragBegan(node: node) },
            onDragMoved: { node, world in vm.handleDrag(node: node, to: world) },
            onDragEnded: { node in vm.dragEnded(node: node) }
        )
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Top inset

    /// SPEC §8.4：顶部控制区 ≤2 行 —— 库数 / 理想·真实（含内联发力）两行；
    /// 求解状态 pill 改浮层（不挤压球桌）。
    private var topInset: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            cushionPicker
            ScrollView(.horizontal, showsIndicators: false) {
                ReflectionModeControl(realMode: $vm.realMode, power: $vm.reflectionPower)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .animation(.easeInOut(duration: 0.2), value: vm.currentIndex)
        .animation(.easeInOut(duration: 0.2), value: vm.hasSolution)
    }

    private var cushionPicker: some View {
        BTChipRow(
            options: ["自动"] + vm.cushionOptions.map { "\($0)库" },
            selection: Binding(
                get: { vm.selectedCushions ?? 0 },
                set: { vm.selectCushions($0 == 0 ? nil : $0) }
            )
        )
    }

    @ViewBuilder
    private var infoPill: some View {
        HStack {
            if vm.isSolving {
                solvingPill
            } else if vm.hasSolution {
                solutionPill
            } else {
                noSolutionPill
            }
            Spacer()
        }
    }

    private var solvingPill: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView().scaleEffect(0.7).tint(.white)
            Text("真实物理求解中…")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .btHudGlass()
    }

    private var solutionPill: some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: 4) {
                Image(systemName: "scope").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.btAccent)
                // 库数 = 方案量值 → 金（HUD 状态语法：金管数值）。
                BTReadout(value: "\(vm.currentCushions) 库", emphasis: .adjustable)
            }
            divider
            Text(vm.currentRailText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
            if vm.solutionCount > 1 {
                divider
                BTReadout(value: "\(vm.currentIndex + 1)/\(vm.solutionCount)", size: .compact)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .btHudGlass()
    }

    private var noSolutionText: String {
        if vm.selectedCushions != nil { return "该库数下无解，换库数或移动球位" }
        return "该位置暂无解，移动球位再试"
    }

    private var noSolutionPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill").font(.btCaption)
            Text(noSolutionText)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.btWarning)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .btHudGlass()
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 14)
    }

    // MARK: - Overlay (FABs)

    private var overlayLayer: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
            // 求解状态 pill：浮层贴左下（SPEC §8.4，不占顶部行、不挤压球桌）。
            VStack {
                Spacer()
                HStack {
                    infoPill
                    Spacer()
                }
                .padding(.leading, Spacing.lg)
                .padding(.bottom, Spacing.xl + 16)
            }
            VStack(spacing: Spacing.md) {
                if vm.solutionCount > 1 {
                    BTSceneFAB(icon: "arrow.triangle.2.circlepath", title: "下一解",
                               variant: .primary) { vm.nextSolution() }
                        .transition(.scale.combined(with: .opacity))
                }
                BTSceneFAB(icon: "arrow.counterclockwise", title: "重置") { vm.reset() }
            }
            .padding(.trailing, Spacing.lg)
            .padding(.bottom, Spacing.xl + 16)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: vm.solutionCount)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: vm.hasSolution)
    }
}

// MARK: - Principle sheet

private struct ReflectionSolverInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    principleBlock(
                        title: "这是什么",
                        body: "一个通用的反射解球器：把母球和目标球放到台面任意位置，自动计算母球经过 1 库、2 库、3 库直至多库反弹后击中目标球的走位路线。"
                    )
                    principleBlock(
                        title: "原理：入射角 = 反射角",
                        body: "采用无侧旋的理想物理模型，球碰库遵循镜面反射（入射角等于反射角）。这是台球走位的几何基础，著名的颗星 / 钻石公式（CB − TR = FR）正是该反射模型在「母球贴库、平行库」特例下的算术近似。"
                    )
                    principleBlock(
                        title: "怎么算的：镜像展开",
                        body: "将目标球依次对各条库边做镜像，把折线「展开」成一条直线，即可精确求出每一次的反射点。本页会枚举所有撞库顺序，自动给出库数最少、路径最短的解。"
                    )
                    principleBlock(
                        title: "操作",
                        body: "拖动母球（白）与目标球（黑）到任意位置；顶部选「自动」求最少库数，或手选 1–4 库。白色实线即母球走位、金点是碰库点。多条解时点「下一解」切换不同撞库顺序；点「重置」恢复默认摆球。"
                    )
                    principleBlock(
                        title: "理想 / 真实模式",
                        body: "顶部可切换「理想 / 真实」。真实模式用真实物理引擎按力度模拟反射：力越大越接近镜面反射，力越小反射越「偏短」（反射角相对法线略小于入射角，模拟真实库呢吸收），并用白色虚线叠加理想路线作对照。拖动力度滑块（m/s），几次试打后即可拟合你常玩球台与力度的手感；该设置与翻袋解球器共享并会被记住。"
                    )
                    principleBlock(
                        title: "实战提示",
                        body: "理想反射模型在真实球台上需用中等力度配合跟随 / 顺塞旋转来贴近；台呢、库边弹性也会带来偏差。本工具用于建立几何直觉，实战仍需按球台微调。"
                    )
                }
                .padding(Spacing.lg)
            }
            .navigationTitle("反射解球原理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        // §1.6：Z7 浮出层统一暗材质（T-P18-49）。
        .preferredColorScheme(.dark)
    }

    private func principleBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.btHeadline).foregroundStyle(.btText)
            Text(body).font(.btSubheadline).foregroundStyle(.btTextSecondary)
        }
    }
}
