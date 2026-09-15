import SwiftUI

extension View {
    /// Applied to exercise page roots, never a table preview or list cell.
    func trainingBackgroundMusic(isEnabled: Bool = true) -> some View {
        modifier(BTTrainingMusic(isEnabled: isEnabled))
    }
}

private struct BTTrainingMusic: ViewModifier {
    let isEnabled: Bool
    @State private var owner = UUID()
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                isVisible = true
                update()
            }
            .onDisappear {
                isVisible = false
                TrainingMusicPlayer.shared.leave(owner)
            }
            .onChange(of: isEnabled) { _, _ in update() }
    }

    private func update() {
        if isVisible && isEnabled {
            TrainingMusicPlayer.shared.enter(owner)
        } else {
            TrainingMusicPlayer.shared.leave(owner)
        }
    }
}
