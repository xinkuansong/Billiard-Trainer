import Foundation
import SceneKit

/// Current solution-free bank. The shared target geometry stays compact; only the
/// selected boards are restored. Stored combination IDs are authoritative.
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
        let combinationTable: [TrainingCombination]
        let targets: [Target]
    }
    struct Draw {
        let boards: [TrainingBankBoard]
    }
    let sourceFingerprint: String // content identity, not a claim of physics qualification
    let payload: Payload
    let pools: [[UInt32]]
    private let targetIndexByInventory: [Int: Int]
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
        // Each remaining layout owns one integer rank in the filtered union.
        // Selecting a rank, rather than a category, makes every layout equally likely.
        var remaining = pools.indices.map {
            payload.combinationTable[$0].matches(config) ? pools[$0].count - blocked[$0].count : 0
        }
        var total = remaining.reduce(0, +)
        guard count > 0, total >= count else {
            throw TrainingQuestionBank.Failure.coverage("不足\(count)个不同球形")
        }
        // Preserve bounded admission work without discarding a whole category
        // because some of its layouts failed. This is a work limit, not a quota.
        let rejectionLimit = 256 * remaining.filter { $0 > 0 }.count
        var rejections = 0
        var random = SceneTrainingGenerator.SeededRandom(state: seed)
        var boards: [TrainingBankBoard] = []
        while boards.count < count {
            try Task.checkCancellation()
            guard total >= count - boards.count else { throw TrainingQuestionBank.Failure.strikeAccess }
            var rank = Int.random(in: 0..<total, using: &random)
            var code = 0
            while rank >= remaining[code] { rank -= remaining[code]; code += 1 }
            for excluded in blocked[code] { if excluded <= rank { rank += 1 } else { break } }
            let candidate = board(reference: pools[code][rank], combination: code)
            blocked[code].append(rank); blocked[code].sort()
            remaining[code] -= 1; total -= 1
            if accepting?(candidate) ?? true {
                boards.append(candidate)
            } else {
                rejections += 1
                guard rejections < rejectionLimit else { throw TrainingQuestionBank.Failure.strikeAccess }
            }
        }
        return .init(boards: boards)
    }

    func baseBatch(_ config: SceneTrainingConfiguration, seed: UInt64, excluding: Set<String> = [], count: Int = 20) throws -> [TrainingBankBoard] {
        try draw(config, seed: seed, excluding: excluding, count: count).boards
    }
}
