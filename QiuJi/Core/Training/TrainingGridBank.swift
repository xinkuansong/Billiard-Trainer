import Foundation
import SceneKit

/// Current solution-free bank. The shared target geometry stays compact; only the
/// twenty selected boards are restored. Stored combination IDs are authoritative.
final class TrainingGridBank {
    struct Point: Decodable {
        let x: Double
        let z: Double
        var finite: Bool { x.isFinite && z.isFinite }
        var vector: SCNVector3 { SCNVector3(Float(x), 0, Float(z)) }
    }
    struct Target: Decodable {
        let aim: Point
        let ghost: Point
        let object: Point
        let pocket: Int
        let inventoryTargetIndex: Int
        let masks: [UInt16]
        let combinationIndices: [UInt16]
    }
    struct Payload: Decodable {
        let schema: String
        let validationSourceFingerprint: String
        let distanceSamples: [Double]
        let counts: [String: Int]
        let combinationTable: [TrainingCombinationWeights.Cell]
        let targets: [Target]
    }
    struct Draw {
        let boards: [TrainingBankBoard]
        let distribution: TrainingCombinationWeights.Distribution
        var inaccessibleCombinations: [String] = []
    }
    let sourceFingerprint: String // content identity, not a claim of physics qualification
    let payload: Payload
    let pools: [[UInt32]]
    private let targetIndexByInventory: [Int: Int]
    private let distributionLock = NSLock()
    private var distributions: [String: TrainingCombinationWeights.Distribution] = [:]
    private let aimLock = NSLock()
    private var runtimeAims: [Int: SCNVector3] = [:]

    init(data: Data, fingerprint: String) throws {
        let p = try JSONDecoder().decode(Payload.self, from: data)
        guard p.schema == "layout-bank-grid-v2-combination-ids", p.combinationTable.count == 270,
              p.distanceSamples.count == 11, p.distanceSamples.allSatisfy({ $0.isFinite && $0 > 0 }),
              p.targets.count < (1 << 20), !p.targets.isEmpty else {
            throw TrainingQuestionBank.Failure.invalid("Unsupported grid bank")
        }
        for (code, cell) in p.combinationTable.enumerated() {
            guard zip(cell.axes, [5, 2, 3, 3, 3]).allSatisfy({ (0..<$1).contains($0) }),
                  code == (((cell.angleIndex * 2 + cell.pocketType) * 3 + cell.cueIndex) * 3 + cell.objectIndex) * 3 + cell.railIndex,
                  cell.id == "a\(cell.angleIndex)-p\(cell.pocketType)-c\(cell.cueIndex)-o\(cell.objectIndex)-r\(cell.railIndex)" else {
                throw TrainingQuestionBank.Failure.invalid("Invalid combination definition")
            }
        }
        var groups = Array(repeating: [UInt32](), count: 270)
        var lookup: [Int: Int] = [:]
        var totals = [0, 0]
        for (ti, t) in p.targets.enumerated() {
            try Task.checkCancellation()
            guard lookup[t.inventoryTargetIndex] == nil, t.inventoryTargetIndex >= 0,
                  (0..<6).contains(t.pocket), t.masks.count == 171,
                  t.masks.allSatisfy({ $0 < (1 << 11) }),
                  t.masks.reduce(0, { $0 + $1.nonzeroBitCount }) == t.combinationIndices.count,
                  t.aim.finite, t.object.finite, t.ghost.finite,
                  hypot(t.ghost.x - t.object.x, t.ghost.z - t.object.z) > 0 else {
                throw TrainingQuestionBank.Failure.invalid("Invalid grid target")
            }
            lookup[t.inventoryTargetIndex] = ti
            var ordinal = 0
            for mi in t.masks.indices {
                for bit in p.distanceSamples.indices where t.masks[mi] & (1 << bit) != 0 {
                    let code = Int(t.combinationIndices[ordinal]); ordinal += 1
                    guard (0..<270).contains(code), p.combinationTable[code].pocketType == (t.pocket < 4 ? 0 : 1) else {
                        throw TrainingQuestionBank.Failure.invalid("Invalid layout combination reference")
                    }
                    groups[code].append(UInt32(ti << 12 | mi << 4 | bit))
                    totals[t.pocket < 4 ? 0 : 1] += 1
                }
            }
        }
        guard totals == [p.counts["corner"], p.counts["middle"]] else {
            throw TrainingQuestionBank.Failure.invalid("Grid counts mismatch")
        }
        payload = p; pools = groups; targetIndexByInventory = lookup; sourceFingerprint = fingerprint
    }
    var counts: [Int] { pools.map(\.count) }

    /// Resolve a content identity without sampling or broadening its conditions.
    func board(id: String) -> TrainingBankBoard? {
        let parts = id.split(separator: ":")
        guard parts.count == 4, parts[0] == "grid-v3", let inventory = Int(parts[1]),
              let ti = targetIndexByInventory[inventory], let mi = Int(parts[2]), (0..<171).contains(mi),
              let bit = Int(parts[3]), payload.distanceSamples.indices.contains(bit) else { return nil }
        let target = payload.targets[ti]
        guard target.masks[mi] & (1 << bit) != 0 else { return nil }
        let ordinal = target.masks.prefix(mi).reduce(0) { $0 + $1.nonzeroBitCount }
            + (target.masks[mi] & UInt16((1 << bit)-1)).nonzeroBitCount
        return board(reference: UInt32(ti << 12 | mi << 4 | bit), combination: Int(target.combinationIndices[ordinal]))
    }

    private func runtimeAim(targetIndex: Int) -> SCNVector3 {
        aimLock.lock()
        defer { aimLock.unlock() }
        if let aim = runtimeAims[targetIndex] { return aim }
        let target = payload.targets[targetIndex]
        let aim = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target.object.vector, pocketIndex: target.pocket, surfaceY: 0)
        runtimeAims[targetIndex] = aim
        return aim
    }

    func distribution(_ config: SceneTrainingConfiguration, counts: [Int]? = nil) throws -> TrainingCombinationWeights.Distribution {
        let targets = TrainingCombinationWeights.targets(config)
        let liveCounts = counts ?? self.counts
        // Probabilities depend on support, not the number of layouts in each cell.
        let key = targets.description + liveCounts.map { $0 > 0 ? "1" : "0" }.joined()
        distributionLock.lock()
        let cached = distributions[key]
        distributionLock.unlock()
        if let cached { return cached }
        let result = try TrainingCombinationWeights.fit(cells: payload.combinationTable, counts: liveCounts, targets: targets)
        distributionLock.lock()
        if distributions.count >= 64 { distributions.removeAll(keepingCapacity: true) }
        distributions[key] = result
        distributionLock.unlock()
        return result
    }

    func board(reference: UInt32, combination: Int) -> TrainingBankBoard {
        let ti = Int(reference >> 12), mi = Int((reference >> 4) & 255), bit = Int(reference & 15)
        let t = payload.targets[ti], cell = payload.combinationTable[combination]
        let dx = t.ghost.x - t.object.x, dz = t.ghost.z - t.object.z
        let length = hypot(dx, dz), a = Double(mi - 85) * .pi / 180, d = payload.distanceSamples[bit]
        let cue = SCNVector3(Float(t.ghost.x + d * (dx * cos(a) - dz * sin(a)) / length), 0,
                            Float(t.ghost.z + d * (dx * sin(a) + dz * cos(a)) / length))
        let distances: [SceneTrainingConfiguration.Distance] = [.short, .middle, .long]
        // P/ghost/beta above reconstruct the generated placement only. Answers
        // use the production pocket-aim model, not those generation parameters.
        let aim = runtimeAim(targetIndex: ti)
        let actualAngle = AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: t.object.vector, pocket: aim)
        return TrainingBankBoard(gridID: "grid-v3:\(t.inventoryTargetIndex):\(mi):\(bit)", seed: UInt64(reference),
            cue: cue, target: t.object.vector, aim: aim, pocket: t.pocket,
            angle: actualAngle, side: mi < 85 ? -1 : 1,
            cueBand: distances[cell.cueIndex], pocketBand: distances[cell.objectIndex],
            combinationID: cell.id, qualification: t.pocket < 4 ? "geometry-candidate" : "center-direct-five-v4",
            generationAngle: Double(abs(mi - 85)))
    }

    private func excludedRanks(_ ids: Set<String>) -> [[Int]] {
        var blocked = Array(repeating: [Int](), count: 270)
        for id in ids {
            let parts = id.split(separator: ":")
            guard parts.count == 4, parts[0] == "grid-v3", let inventory = Int(parts[1]),
                  let ti = targetIndexByInventory[inventory], let mi = Int(parts[2]), (0..<171).contains(mi),
                  let bit = Int(parts[3]), payload.distanceSamples.indices.contains(bit) else { continue }
            let t = payload.targets[ti]
            guard t.masks[mi] & (1 << bit) != 0 else { continue }
            let ordinal = t.masks.prefix(mi).reduce(0) { $0 + $1.nonzeroBitCount }
                + (t.masks[mi] & UInt16((1 << bit) - 1)).nonzeroBitCount
            let code = Int(t.combinationIndices[ordinal]), ref = UInt32(ti << 12 | mi << 4 | bit)
            let pool = pools[code]
            var lo = 0, hi = pool.count
            while lo < hi { let mid = (lo + hi) / 2; if pool[mid] < ref { lo = mid + 1 } else { hi = mid } }
            if lo < pool.count, pool[lo] == ref { blocked[code].append(lo) }
        }
        return blocked.map { Array(Set($0)).sorted() }
    }

    func draw(_ config: SceneTrainingConfiguration, seed: UInt64, excluding: Set<String> = [], count: Int = 20,
              accepting: ((TrainingBankBoard) -> Bool)? = nil) throws -> Draw {
        try Task.checkCancellation()
        var blocked = excludedRanks(excluding)
        let remaining = pools.indices.map { pools[$0].count - blocked[$0].count }
        var fitted = try distribution(config, counts: remaining)
        guard pools.indices.reduce(0, { $0 + (fitted.probabilities[$1] > 0 ? remaining[$1] : 0) }) >= count, count > 0 else {
            throw TrainingQuestionBank.Failure.coverage("不足\(count)个不同球形")
        }
        var random = SceneTrainingGenerator.SeededRandom(state: seed)
        var probabilities = fitted.probabilities
        var boards: [TrainingBankBoard] = []
        var inaccessible: Set<Int> = []
        while boards.count < count {
            try Task.checkCancellation()
            let total = probabilities.reduce(0, +)
            guard total > 0 else { throw TrainingQuestionBank.Failure.coverage("本轮可用组合已耗尽") }
            let pick = Double.random(in: 0..<total, using: &random)
            var cumulative = 0.0
            guard let code = probabilities.indices.first(where: { cumulative += probabilities[$0]; return pick < cumulative }) else {
                throw TrainingQuestionBank.Failure.invalid("Invalid combination probabilities")
            }
            // Keep this combination's draw weight while replacing inaccessible layouts.
            // Exhausted/bounded inaccessible support is reported to the caller;
            // refitting never broadens the user's selected conditions.
            var accepted = false
            for _ in 0..<256 {
                try Task.checkCancellation()
                guard blocked[code].count < pools[code].count else { break }
                var rank = Int.random(in: 0..<(pools[code].count - blocked[code].count), using: &random)
                for excluded in blocked[code] { if excluded <= rank { rank += 1 } else { break } }
                let candidate = board(reference: pools[code][rank], combination: code)
                blocked[code].append(rank); blocked[code].sort()
                if accepting?(candidate) ?? true {
                    boards.append(candidate); accepted = true; break
                }
            }
            guard accepted else {
                inaccessible.insert(code)
                let live = pools.indices.map { inaccessible.contains($0) ? 0 : pools[$0].count - blocked[$0].count }
                guard pools.indices.contains(where: { probabilities[$0] > 0 && live[$0] > 0 }) else {
                    throw TrainingQuestionBank.Failure.strikeAccess
                }
                fitted = try distribution(config, counts: live)
                probabilities = fitted.probabilities
                continue
            }
            if blocked[code].count == pools[code].count { probabilities[code] = 0 }
        }
        return .init(boards: boards, distribution: fitted,
                     inaccessibleCombinations: inaccessible.sorted().map { payload.combinationTable[$0].id })
    }
    func baseBatch(_ config: SceneTrainingConfiguration, seed: UInt64, excluding: Set<String> = [], count: Int = 20) throws -> [TrainingBankBoard] {
        try draw(config, seed: seed, excluding: excluding, count: count).boards
    }
}
