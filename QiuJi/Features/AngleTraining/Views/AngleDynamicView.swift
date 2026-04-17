import SwiftUI
import SceneKit

struct AngleDynamicView: View {
    @StateObject private var vm = AngleDynamicViewModel()
    @State private var hasAppeared = false

    var body: some View {
        ZStack(alignment: .bottom) {
            sceneContainer
            infoPanel
        }
        .ignoresSafeArea(edges: .bottom)
        .background(.black)
        .navigationTitle("角度与打点")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                randomButton
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    vm.pulseBalls()
                }
            }
        }
    }

    // MARK: - Scene

    private var sceneContainer: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            onPocketTapped: { index in
                vm.selectPocket(at: index)
            },
            draggableBallNodes: vm.draggableBalls,
            onDragBegan: { node in vm.dragBegan(node: node) },
            onDragMoved: { node, pos in vm.dragMoved(node: node, worldPosition: pos) },
            onDragEnded: { node in vm.dragEnded(node: node) }
        )
    }

    // MARK: - Info Panel

    private var infoPanel: some View {
        Group {
            if vm.isDragging {
                hintPanel(text: "拖动球到目标位置")
            } else if vm.selectedPocketIndex < 0 {
                hintPanel(text: "点击袋口选择目标")
            } else if !vm.isFeasible {
                infeasiblePanel
            } else {
                dataPanel
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }

    private func hintPanel(text: String) -> some View {
        Text(text)
            .font(.btSubheadlineMedium)
            .foregroundStyle(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private var infeasiblePanel: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.btDestructive)
            Text(vm.infeasibleReason)
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btDestructive)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private var dataPanel: some View {
        VStack(spacing: Spacing.xs) {
            HStack {
                dataItem(label: "切球角", value: "\(Int(vm.cutAngleDegrees))°")
                Spacer()
                Text(vm.thicknessName)
                    .font(.btCaption)
                    .foregroundStyle(.btPrimary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.btPrimaryMuted)
                    .clipShape(Capsule())
                Spacer()
                dataItem(label: "d/R", value: String(format: "%.2f", vm.dOverR))
            }

            HStack {
                dataItem(label: "横移", value: String(format: "%.1fmm", vm.displacementMM))
                Spacer()
                dataItem(label: "偏移", value: String(format: "%.0f%%", vm.offsetPercent))
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func dataItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.btCaption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Random / Reset

    private var randomButton: some View {
        Button {
            vm.randomizeBalls()
        } label: {
            Image(systemName: "dice.fill")
                .foregroundStyle(.btPrimary)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    vm.resetToDefaults()
                }
        )
    }
}

#Preview("Light") {
    NavigationStack { AngleDynamicView() }
}

#Preview("Dark") {
    NavigationStack { AngleDynamicView() }
        .preferredColorScheme(.dark)
}
