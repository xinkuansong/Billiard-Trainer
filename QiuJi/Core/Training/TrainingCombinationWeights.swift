import Foundation

/// Policy is independent of inventory size. All values refer to persisted combination axes.
enum TrainingCombinationWeights {
    static let version = "calibrated-combinations-v1"
    static let defaults: [[Double]] = [
        [0.15, 0.25, 0.30, 0.20, 0.10], [0.60, 0.40],
        [0.30, 0.45, 0.25], [0.30, 0.45, 0.25], [0.70, 0.20, 0.10]
    ]
    struct Cell: Decodable {
        let id: String
        let angleIndex: Int
        let pocketType: Int
        let cueIndex: Int
        let objectIndex: Int
        let railIndex: Int
        var axes: [Int] { [angleIndex, pocketType, cueIndex, objectIndex, railIndex] }
    }
    struct Distribution {
        let probabilities: [Double]
        let calibrated: Bool
        let restrictedSupport: Bool
        let maxError: Double
        var notice: String? {
            if !calibrated { return "当前条件无法同时满足预设比例，已在所选条件的有题组合内按相对权重抽题。" }
            if restrictedSupport { return "部分条件组合暂无球形，已在所选条件的有题组合内分配比例。" }
            return nil
        }
    }
    static func targets(_ c: SceneTrainingConfiguration) -> [[Double]] {
        func axis<T: Hashable>(_ selected: Set<T>, _ random: T, _ values: [T], _ weights: [Double]) -> [Double] {
            if selected.contains(random) { return weights }
            let n = Double(selected.count)
            return values.map { selected.contains($0) && n > 0 ? 1 / n : 0 }
        }
        return [axis(c.angleSelection, .mixed, [.straight, .small, .medium, .large, .thin], defaults[0]),
                axis(c.pocketSelection, .mixed, [.corner, .side], defaults[1]),
                axis(c.cueDistanceSelection, .mixed, [.short, .middle, .long], defaults[2]),
                axis(c.pocketDistanceSelection, .mixed, [.short, .middle, .long], defaults[3]),
                // .mixed includes off-rail; the explicit choices only offer near/frozen.
                c.railDistanceSelection.contains(.mixed) ? defaults[4] :
                    [0, c.railDistanceSelection.contains(.near) ? 1 / Double(c.railDistanceSelection.count) : 0,
                     c.railDistanceSelection.contains(.frozen) ? 1 / Double(c.railDistanceSelection.count) : 0]]
    }

    /// IPF preserves angle × pocket jointly and the three other marginal distributions.
    /// A finite iteration budget prevents incompatible user filters from hanging preparation.
    static func fit(cells: [Cell], counts: [Int], targets: [[Double]]) throws -> Distribution {
        guard cells.count == counts.count, targets.map(\.count) == defaults.map(\.count),
              targets.allSatisfy({ $0.allSatisfy { $0.isFinite && $0 >= 0 } && $0.reduce(0, +) > 0 }) else {
            throw TrainingQuestionBank.Failure.invalid("Invalid sampling targets")
        }
        let axes = cells.map(\.axes)
        var initial = cells.indices.map { i in counts[i] > 0 ? (0..<5).reduce(1.0) { $0 * targets[$1][axes[i][$1]] } : 0 }
        let total = initial.reduce(0, +)
        guard total > 0 else { throw TrainingQuestionBank.Failure.coverage("所选组合暂无球形") }
        initial = initial.map { $0 / total }
        let groups = [axes.map { $0[0] * 2 + $0[1] }, axes.map { $0[2] }, axes.map { $0[3] }, axes.map { $0[4] }]
        var wanted = [targets[0].flatMap { a in targets[1].map { a * $0 } }, targets[2], targets[3], targets[4]]
        var restricted = false
        for k in groups.indices {
            let supported = Set(cells.indices.filter { initial[$0] > 0 }.map { groups[k][$0] })
            for v in wanted[k].indices where !supported.contains(v) {
                if wanted[k][v] > 0 { restricted = true }; wanted[k][v] = 0
            }
            let sum = wanted[k].reduce(0, +)
            wanted[k] = wanted[k].map { $0 / sum }
        }
        func marginal(_ p: [Double], _ k: Int) -> [Double] {
            var sums = Array(repeating: 0.0, count: wanted[k].count)
            for i in p.indices { sums[groups[k][i]] += p[i] }
            return sums
        }
        func error(_ p: [Double]) -> Double {
            groups.indices.map { k in zip(marginal(p, k), wanted[k]).map { abs($0 - $1) }.max() ?? 0 }.max() ?? 0
        }
        var p = initial
        for iteration in 0..<2_000 {
            if iteration % 32 == 0 { try Task.checkCancellation() }
            for k in groups.indices {
                let sums = marginal(p, k)
                for i in p.indices where p[i] > 0 {
                    let g = groups[k][i]
                    p[i] *= wanted[k][g] / sums[g]
                }
            }
            let residual = error(p)
            if residual < 1e-10 {
                return .init(probabilities: p, calibrated: true, restrictedSupport: restricted, maxError: residual)
            }
        }
        // Explicit fallback for incompatible marginals: condition the independent
        // target product on live selected cells. Never use the last IPF cycle,
        // which would privilege whichever constraint happened to run last.
        return .init(probabilities: initial, calibrated: false, restrictedSupport: restricted, maxError: error(initial))
    }
}
