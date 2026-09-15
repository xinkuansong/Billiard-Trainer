@testable import QiuJi

@MainActor
final class MockTrainingMusicPlayback: TrainingMusicPlaying {
    private(set) var isPlaying = false
    private(set) var starts = 0

    func play() -> Bool {
        isPlaying = true
        starts += 1
        return true
    }

    func pause() { isPlaying = false }
}
