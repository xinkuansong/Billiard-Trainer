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
        .navigationTitle("翻袋解球")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(.white.opacity(0.75))
                }
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

    private var topInset: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            pocketPicker
            cushionPicker
            ReflectionModeControl(realMode: $vm.realMode, factor: $vm.reflectionFactor)
            infoPill
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .animation(.easeInOut(duration: 0.2), value: vm.currentIndex)
        .animation(.easeInOut(duration: 0.2), value: vm.hasSolution)
    }

    private var pocketPicker: some View {
        BTChipRow(
            options: vm.pocketNames,
            selection: Binding(get: { vm.selectedPocket }, set: { vm.selectPocket($0) }),
            tint: .btAccent
        )
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
            if vm.hasSolution {
                solutionPill
            } else {
                noSolutionPill
            }
            Spacer()
        }
    }

    private var solutionPill: some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.left").font(.system(size: 12, weight: .semibold))
                Text("\(vm.currentCushions) 库")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.btAccent)
            divider
            Text(vm.currentRailText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
            divider
            Text("切球 \(vm.currentCutAngle)°")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            if vm.solutionCount > 1 {
                divider
                Text("\(vm.currentIndex + 1)/\(vm.solutionCount)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
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
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 14)
    }

    // MARK: - Overlay (FABs)

    private var overlayLayer: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
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
                        body: "黄线是目标球的进袋路线，红点是碰库点，青色短线是该处库面法线——入射角与反射角关于法线对称，这是无侧旋理想反射模型的几何基础。计算用「镜像展开」：把袋口沿各库依次镜像成虚像，目标球到虚像连一条直线即得各反弹点。"
                    )
                    principleBlock(
                        title: "瞄准线与接触点",
                        body: "确定了目标球的出发方向后，反推出「幽灵球」（白色半透明，= 目标球沿出发方向反向 2R）。母球只要沿白色瞄准线撞向幽灵球位置，就能把目标球送上翻袋路线。绿点是母球与目标球的接触点（目标球表面，偏移 R·sinα）。"
                    )
                    principleBlock(
                        title: "操作",
                        body: "拖动母球（白）与目标球（黑）到任意位置；点选顶部袋口标签或直接点台面上的袋口；选「自动」求最少库数，或手选 1–3 库。多条解时点「下一解」切换不同撞库顺序；点「重置」恢复默认。"
                    )
                    principleBlock(
                        title: "理想 / 真实模式",
                        body: "顶部可切换「理想 / 真实」。真实模式按缩小因子让翻库「偏短」（反射角相对法线略小于入射角），并用蓝色虚线叠加理想进球线作对照，瞄准线会据真实路线重新反推。拖动缩小因子滑块（0.50–1.00），几次试打后拟合你常玩球台与发力；该因子与反射解球器共享并会被记住。"
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
    }

    private func principleBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.btHeadline).foregroundStyle(.btText)
            Text(body).font(.btSubheadline).foregroundStyle(.btTextSecondary)
        }
    }
}
