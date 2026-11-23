import Foundation

extension TrainingQuestionBank {
    /// The four geometric quizzes need an existence proof, not a particular tip.
    /// Their answer remains the board's geometric angle/contact point.
    func baseBatch(_ config: SceneTrainingConfiguration, seed: UInt64,
                   excluding excluded: Set<String> = []) throws -> [TrainingBankBoard] {
        try Task.checkCancellation()
        var random = SceneTrainingGenerator.SeededRandom(state: seed)
        let candidates = boards.filter { !excluded.contains($0.id) && $0.matches(config) }
        var result: [TrainingBankBoard] = []
        let bands = config.angleBands
        guard !bands.isEmpty else { throw Failure.invalid("Empty angle selection") }
        for (index, band) in bands.enumerated() {
            let count = 20 / bands.count + (index < 20 % bands.count ? 1 : 0)
            var pool = candidates.filter { band.degrees.contains(Int($0.angle.rounded())) }.shuffled(using: &random)
            guard pool.count >= count else { throw Failure.coverage(band.label) }
            for _ in 0..<count {
                try Task.checkCancellation()
                // Balance eligible pocket kinds, cut sides and distances without
                // silently widening any user-selected condition.
                func weight(_ board: TrainingBankBoard) -> Int {
                    result.filter { ($0.pocketIndex < 4) == (board.pocketIndex < 4) }.count * 8
                        + result.filter { $0.side == board.side }.count * 4
                        + result.filter { $0.cueBand == board.cueBand }.count
                        + result.filter { $0.pocketBand == board.pocketBand }.count
                }
                guard let selected = pool.indices.min(by: { weight(pool[$0]) < weight(pool[$1]) }) else {
                    throw Failure.coverage(band.label)
                }
                result.append(pool.remove(at: selected))
            }
        }
        return result.shuffled(using: &random)
    }
}
