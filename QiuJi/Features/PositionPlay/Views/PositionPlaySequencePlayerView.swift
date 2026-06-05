import SwiftUI

/// 多杆走位序列播放页（走位训练形态消费序列内容，ADR-P11-01）。
struct PositionPlaySequencePlayerView: View {
    @StateObject private var player: PositionPlaySequencePlayer
    @State private var hasAppeared = false

    init(sequence: PositionPlaySequence) {
        _player = StateObject(wrappedValue: PositionPlaySequencePlayer(sequence: sequence))
    }

    var body: some View {
        ZStack {
            AngleSceneView(
                scene: player.scene,
                cameraMode: $player.cameraMode,
                interactionMode: .none
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) { statusCard }
        .safeAreaInset(edge: .bottom, spacing: 0) { controls }
        .navigationTitle(player.sequence.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if !hasAppeared { hasAppeared = true; player.setupScene() }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.btPrimary)
            Text(player.statusText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
            Spacer()
        }
        .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm + 2)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BTRadius.lg))
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, Spacing.md).padding(.top, Spacing.xs)
    }

    private var controls: some View {
        HStack(spacing: Spacing.xl) {
            controlButton(icon: "backward.end.fill", label: "上一杆") {
                player.seek(to: player.currentStep - 1)
            }
            .disabled(player.isPlaying || player.currentStep == 0)

            controlButton(icon: player.autoPlaying ? "play.fill" : "play.circle.fill",
                          label: "连播", tint: Color.btPrimary) {
                player.playAll()
            }
            .disabled(player.isPlaying || player.totalSteps == 0)

            controlButton(icon: "play.fill", label: "单杆") {
                player.playOne()
            }
            .disabled(player.isPlaying || player.totalSteps == 0)

            controlButton(icon: "forward.end.fill", label: "下一杆") {
                player.seek(to: player.currentStep + 1)
            }
            .disabled(player.isPlaying || player.currentStep >= player.totalSteps - 1)

            controlButton(icon: "arrow.counterclockwise", label: "重来") {
                player.reset()
            }
            .disabled(player.isPlaying)
        }
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func controlButton(icon: String, label: String, tint: Color = .white.opacity(0.85),
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                Text(label).font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }
}
