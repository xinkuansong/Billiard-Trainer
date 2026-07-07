import SwiftUI
import SceneKit

/// 翻袋解球 — 2D 顶视图。把母球、目标球放到任意位置，点选要翻进的袋口，
/// 求解器给出目标球经 1/2/3 库纯反射进袋的路线，并反推母球瞄准线 / 幽灵球 / 接触点。
struct BankShotView: View {
    @StateObject private var vm = BankShotViewModel()
    @State private var showInfo = false
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            sceneFullscreen
            overlayLayer
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) { topInset }
        .navigationTitle("翻袋解球器")
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
            BankShotInfoSheet().presentationDetents([.medium, .large])
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
            onPocketTapped: { vm.selectPocket($0) },
            draggableBallNodes: vm.draggableNodes,
            onDragBegan: { node in vm.dragBegan(node: node) },
            onDragMoved: { node, world in vm.handleDrag(node: node, to: world) },
            onDragEnded: { node in vm.dragEnded(node: node) }
        )
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Top inset

    /// SPEC §8.4 + T-P18-50 顶部重排：袋口选择改**台面直点**（点袋口即选中，
    /// 高亮圈是唯一指示，袋口 chip 行删除）；行 1 = 库数，行 2 = 理想/真实 +
    /// 力度滑块整行铺开（治横滚截断）。求解状态 pill 仍为左下浮层。
    private var topInset: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            cushionPicker
            ReflectionModeControl(realMode: $vm.realMode, power: $vm.reflectionPower)
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
            ),
            scrollable: false
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
                Image(systemName: "arrow.uturn.left").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.btAccent)
                // 库数 = 方案量值 → 金（HUD 状态语法：金管数值）。
                BTReadout(value: "\(vm.currentCushions) 库", emphasis: .adjustable)
            }
            divider
            Text(vm.currentRailText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
            divider
            BTReadout(label: "切角", value: "\(vm.currentCutAngle)°")
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
        if vm.selectedCushions != nil { return "该库数下无解，换库数 / 袋口或移动球位" }
        return "该袋暂无翻袋解，换袋口或移动球位再试"
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

private struct BankShotInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    principleBlock(
                        title: "这是什么",
                        body: "翻袋（bank shot）解球器：把母球和目标球放到台面任意位置，再选定一个想翻进的袋口，自动计算目标球经 1 库、2 库、3 库纯反射后落袋的路线，并反推母球该如何瞄准。"
                    )
                    principleBlock(
                        title: "进球线：入射角 = 反射角",
                        body: "与目标球同色的实线是它的进袋路线，金点是碰库点，白色短线是该处库面法线——入射角与反射角关于法线对称，这是无侧旋理想反射模型的几何基础。计算用「镜像展开」：把袋口沿各库依次镜像成虚像，目标球到虚像连一条直线即得各反弹点。"
                    )
                    principleBlock(
                        title: "瞄准线与接触点",
                        body: "确定了目标球的出发方向后，反推出「假想球」（绿色虚线圈，= 目标球沿出发方向反向 2R）。母球只要沿白色瞄准线撞向假想球位置，就能把目标球送上翻袋路线。绿点是母球与目标球的接触点（目标球表面，偏移 R·sinθ）。"
                    )
                    principleBlock(
                        title: "操作",
                        body: "拖动母球（白）与目标球（黑）到任意位置；直接点台面上的袋口即可选定翻进的袋（高亮圈）；选「自动」求最少库数，或手选 1–3 库。多条解时点「下一解」切换不同撞库顺序；点「重置」恢复默认。"
                    )
                    principleBlock(
                        title: "理想 / 真实模式",
                        body: "顶部可切换「理想 / 真实」。真实模式用真实物理引擎按力度模拟翻库：力越大越接近镜面反射，力越小翻库越「偏短」（反射角相对法线略小于入射角），并用白色虚线叠加理想进球线作对照，瞄准线会据真实路线重新反推。拖动力度滑块（m/s），几次试打后拟合你常玩球台与力度；该设置与反射解球器共享并会被记住。"
                    )
                    principleBlock(
                        title: "实战提示",
                        body: "纯几何反射模型不含侧旋、力度与库边吸收。真实翻袋会因目标球的旋转、击打厚薄与库呢弹性产生偏移（一般略「缩短」反射角），需按球台与手感微调。本工具用于建立翻袋的几何直觉。"
                    )
                }
                .padding(Spacing.lg)
            }
            .navigationTitle("翻袋解球原理")
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
