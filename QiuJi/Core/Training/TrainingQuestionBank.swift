import CryptoKit
import Foundation
import SceneKit

/// Persisted values use world X/Z metres; tip offsets are in cue coordinates / ball radius.
/// A board, an existence proof and a fixed-tip exercise deliberately have separate identities.
struct TrainingBankPoint: Codable, Equatable {
    let x: Float
    let z: Float
    init(_ p: SCNVector3) { x = p.x; z = p.z }
    var vector: SCNVector3 { SCNVector3(x, 0, z) }
    var isFinite: Bool { x.isFinite && z.isFinite }
}

enum TrainingFixedTip: String, Codable, CaseIterable {
    case center, high, low, left, right, highLeft, highRight, lowLeft, lowRight
    // Moderate discrete offsets. Production coverage must verify each exact pair.
    var x: Float {
        switch self { case .left, .highLeft, .lowLeft: 0.25
        case .right, .highRight, .lowRight: -0.25
        default: 0 }
    }
    var y: Float {
        switch self { case .high, .highLeft, .highRight: 0.25
        case .low, .lowLeft, .lowRight: -0.25
        default: 0 }
    }
    var label: String {
        switch self {
        case .center: "中杆"; case .high: "高杆"; case .low: "低杆"
        case .left: "左塞"; case .right: "右塞"
        case .highLeft: "高杆左塞"; case .highRight: "高杆右塞"
        case .lowLeft: "低杆左塞"; case .lowRight: "低杆右塞"
        }
    }
    static func quota(_ configuration: SceneTrainingConfiguration) -> [Self] {
        let allowed = allCases.filter {
            (configuration.allowsVerticalSpin || $0.y == 0) && (configuration.allowsSideSpin || $0.x == 0)
        }
        guard allowed.count > 1 else { return Array(repeating: .center, count: 20) }
        return Array(repeating: .center, count: 4)
            + allowed.filter { $0 != .center }.flatMap { Array(repeating: $0, count: 16 / (allowed.count - 1)) }
    }
}

struct TrainingBankBoard: Codable, Identifiable {
    let id: String
    let seed: UInt64
    let cue: TrainingBankPoint
    let target: TrainingBankPoint
    let effectiveAim: TrainingBankPoint
    let pocketIndex: Int
    let angle: Double
    let side: Int
    let cueBand: SceneTrainingConfiguration.Distance
    let pocketBand: SceneTrainingConfiguration.Distance
    /// Present for the current grid bank; nil in historical saved practice records.
    var combinationID: String? = nil
    var qualification: String? = nil
    /// Inventory classification parameter, never the graded angle.
    var generationAngle: Double? = nil

    init(gridID: String, seed: UInt64, cue: SCNVector3, target: SCNVector3, aim: SCNVector3,
         pocket: Int, angle: Double, side: Int, cueBand: SceneTrainingConfiguration.Distance,
         pocketBand: SceneTrainingConfiguration.Distance, combinationID: String, qualification: String,
         generationAngle: Double) {
        id = gridID; self.seed = seed; self.cue = .init(cue); self.target = .init(target)
        effectiveAim = .init(aim); pocketIndex = pocket; self.angle = angle; self.side = side
        self.cueBand = cueBand; self.pocketBand = pocketBand
        self.combinationID = combinationID; self.qualification = qualification
        self.generationAngle = generationAngle
    }

    init(question: SceneTrainingQuestion, seed: UInt64) {
        let q = question.geometry
        cue = .init(AngleSceneCalculator.normalizedToScene(point: q.cueBall, surfaceY: 0))
        target = .init(AngleSceneCalculator.normalizedToScene(point: q.targetBall, surfaceY: 0))
        effectiveAim = .init(AngleSceneCalculator.effectivePocketAimPoint(targetBall: target.vector, pocketIndex: q.pocketIndex, surfaceY: 0))
        pocketIndex = q.pocketIndex; angle = q.actualAngle; side = question.side
        cueBand = question.cueBand; pocketBand = question.pocketBand; self.seed = seed
        id = TrainingBankIdentity.hash("board-v1:\(cue.x.bitPattern):\(cue.z.bitPattern):\(target.x.bitPattern):\(target.z.bitPattern):\(pocketIndex)")
    }
    func matches(_ c: SceneTrainingConfiguration) -> Bool {
        c.angleBands.contains { $0.degrees.contains(Int((generationAngle ?? angle).rounded())) }
            && c.cueBands.contains(cueBand) && c.pocketBands.contains(pocketBand)
            && c.pocketTypes.contains(pocketIndex < 4 ? .corner : .side)
            && SceneTrainingRailGeometry.matches(target.vector, selection: c.railDistanceSelection)
    }
    var question: SceneTrainingQuestion {
        .init(id: UUID(), geometry: .init(targetBall: AngleSceneCalculator.sceneToNormalized(position: target.vector),
              cueBall: AngleSceneCalculator.sceneToNormalized(position: cue.vector), pocket: AngleCalculator.pockets[pocketIndex],
              actualAngle: angle, pocketType: pocketIndex < 4 ? .corner : .side, pocketIndex: pocketIndex),
              side: side, cueBand: cueBand, pocketBand: pocketBand, sourceBoardID: id)
    }
}

enum TrainingBankIdentity {
    static func hash(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }
}

struct TrainingProofEvent: Codable {
    let time: Float
    let kind: String
    let ball: String
    let otherBall: String?
    let pocketID: String?
    let cushionIndex: Int?
    init(_ event: ShotEvent) {
        time = event.time; cushionIndex = event.cushionIndex
        switch event.kind {
        case let .ballBall(a, b): kind = "ballBall"; ball = a; otherBall = b; pocketID = nil
        case let .ballCushion(name): kind = "ballCushion"; ball = name; otherBall = nil; pocketID = nil
        case let .pocket(name, id): kind = "pocket"; ball = name; otherBall = nil; pocketID = id
        }
    }
}

struct TrainingToleranceSample: Codable {
    let angleDeltaDegrees: Float
    let velocityDelta: Float
    let outcome: AccuracyShotJudgement.Outcome
}

struct TrainingPotProof: Codable, Identifiable {
    // At the shortest 0.30 m cue distance, this spans 3.27 screen points
    // of the existing 0.4 mm/pt × 0.1 slow-drag gain. All nine samples must pot.
    static let angleRadius: Float = 0.025
    static let speedRadius: Float = 0.05
    let id: String
    let boardID: String
    let direction: TrainingBankPoint
    let velocity: Float
    let tip: TrainingFixedTip
    let policyVersion: String
    let settled: Bool
    let specifiedPocket: Bool
    let outcome: AccuracyShotJudgement.Outcome
    let events: [TrainingProofEvent]
    /// Nine samples: centre and eight corners/edges of direction × speed neighbourhood.
    let samples: [TrainingToleranceSample]
    let directionRadiusDegrees: Float
    let velocityRadius: Float
    var accuracySuccess: Bool { outcome == .success }
    var perturbationSuccesses: Int { samples.filter { $0.outcome == .success }.count }

    init(board: TrainingBankBoard, prediction: ShotPrediction, velocity: Float, tip: TrainingFixedTip,
         samples: [TrainingToleranceSample]) {
        boardID = board.id; direction = .init(prediction.strikeDirection ?? prediction.aimDirection)
        self.velocity = velocity; self.tip = tip
        policyVersion = AccuracyShotJudgement.version; settled = prediction.hasFinalTableState
        events = prediction.events.map(TrainingProofEvent.init)
        specifiedPocket = events.contains { $0.ball == ShotInput.targetBallName && $0.pocketID == "pocket_\(board.pocketIndex)" }
        outcome = AccuracyShotJudgement.evaluate(prediction, pocketIndex: board.pocketIndex)
        self.samples = samples
        directionRadiusDegrees = Self.angleRadius; velocityRadius = Self.speedRadius
        id = TrainingBankIdentity.hash("proof-v1:\(boardID):\(tip.rawValue):\(direction.x.bitPattern):\(direction.z.bitPattern):\(velocity.bitPattern):\(policyVersion)")
    }
    var qualifiesForAccuracy: Bool {
        let expected = [-Self.angleRadius, 0, Self.angleRadius].flatMap { angle in
            [-Self.speedRadius, 0, Self.speedRadius].map { speed in "\(angle.bitPattern):\(speed.bitPattern)" }
        }
        let actual = samples.map { "\($0.angleDeltaDegrees.bitPattern):\($0.velocityDelta.bitPattern)" }
        return settled && specifiedPocket && accuracySuccess && perturbationSuccesses == 9
            && samples.count == 9 && Set(actual) == Set(expected)
            && directionRadiusDegrees == Self.angleRadius && velocityRadius == Self.speedRadius
    }
}

struct TrainingAccuracyVariant: Codable, Identifiable {
    let boardID: String
    let proofID: String
    let tip: TrainingFixedTip
    var id: String { TrainingBankIdentity.hash("variant-v1:\(boardID):\(proofID):\(tip.rawValue)") }
}

struct TrainingQuestionBank: Codable {
    static let schema = 1
    let schemaVersion: Int
    /// Hash of the actual physics/geometry source inputs, checked by the offline gate.
    let sourceFingerprint: String
    let boards: [TrainingBankBoard]
    let proofs: [TrainingPotProof]
    let variants: [TrainingAccuracyVariant]

    enum Failure: LocalizedError {
        case invalid(String), coverage(String), strikeAccess
        var errorDescription: String? {
            switch self {
            case .invalid: "题库暂不可用，请稍后重试。"
            case .strikeAccess: "当前组合未找到可用打点，请调整练习条件后重试。"
            case .coverage(let detail): "当前条件下题库不足（\(detail)）。请调整条件后再试。"
            }
        }
    }
    func validate(expectedFingerprint: String) throws {
        guard schemaVersion == Self.schema, sourceFingerprint == expectedFingerprint,
              !boards.isEmpty, Set(boards.map(\.id)).count == boards.count,
              Set(proofs.map(\.id)).count == proofs.count,
              Set(variants.map(\.id)).count == variants.count else { throw Failure.invalid("Manifest or identity mismatch") }
        let boardIDs = Set(boards.map(\.id))
        let boardsByID = Dictionary(uniqueKeysWithValues: boards.map { ($0.id, $0) })
        let proofsByID = Dictionary(uniqueKeysWithValues: proofs.map { ($0.id, $0) })
        let provenBoards = Set(proofs.filter { $0.settled && $0.specifiedPocket }.map(\.boardID))
        for board in boards {
            guard board.cue.isFinite, board.target.isFinite, board.effectiveAim.isFinite,
                  (0..<6).contains(board.pocketIndex), (0...85).contains(board.angle),
                  board.cueBand != .mixed, board.pocketBand != .mixed,
                  provenBoards.contains(board.id) else {
                throw Failure.invalid("Board has no existence proof")
            }
        }
        for proof in proofs {
            let length = hypot(proof.direction.x, proof.direction.z)
            guard boardIDs.contains(proof.boardID), proof.policyVersion == AccuracyShotJudgement.version,
                  proof.direction.isFinite, abs(length - 1) < 0.00001,
                  proof.velocity.isFinite, ShotTuning.velocityRange.contains(Double(proof.velocity)), proof.settled, proof.specifiedPocket,
                  (0...9).contains(proof.perturbationSuccesses) else { throw Failure.invalid("Invalid proof") }
            guard let board = boardsByID[proof.boardID],
                  proof.events.contains(where: { $0.ball == ShotInput.targetBallName && $0.pocketID == "pocket_\(board.pocketIndex)" }) else {
                throw Failure.invalid("Missing specified-pocket event")
            }
        }
        for variant in variants {
            guard let proof = proofsByID[variant.proofID], proof.boardID == variant.boardID,
                  proof.tip == variant.tip, proof.qualifiesForAccuracy else { throw Failure.invalid("Fixed tip proof mismatch") }
        }
    }

    /// Exact constraints only. Deterministic seed, no board reuse inside the twenty-question batch.
    func accuracyBatch(_ config: SceneTrainingConfiguration, seed: UInt64, excluding excluded: Set<String> = []) throws -> [(TrainingBankBoard, TrainingAccuracyVariant)] {
        try Task.checkCancellation()
        var random = SceneTrainingGenerator.SeededRandom(state: seed)
        let eligible = boards.filter { !excluded.contains($0.id) && $0.matches(config) }
        let byID = Dictionary(uniqueKeysWithValues: eligible.map { ($0.id, $0) })
        var tips = TrainingFixedTip.quota(config).shuffled(using: &random)
        let bands = config.angleBands
        guard !bands.isEmpty else { throw Failure.invalid("Empty angle selection") }
        var requests = bands.enumerated().flatMap { index, band in
            Array(repeating: band, count: 20 / bands.count + (index < 20 % bands.count ? 1 : 0))
        }.shuffled(using: &random)
        let allowedVariants = variants.filter { tips.contains($0.tip) && byID[$0.boardID] != nil }
        for band in bands {
            let available = Set(allowedVariants.filter {
                byID[$0.boardID].map { band.degrees.contains(Int($0.angle.rounded())) } == true
            }.map(\.boardID)).count
            guard available >= requests.filter({ $0 == band }).count else { throw Failure.coverage(band.label) }
        }
        for tip in Set(tips) {
            guard Set(allowedVariants.filter { $0.tip == tip }.map(\.boardID)).count >= tips.filter({ $0 == tip }).count else {
                throw Failure.coverage(tip.label)
            }
        }
        // A bounded backtracking matching avoids a greedy early choice starving rare tip/band pairs.
        var used: Set<String> = []
        var result: [(TrainingBankBoard, TrainingAccuracyVariant)] = []
        var budget = 2_000
        func match(_ depth: Int) -> Bool {
            if depth == 20 { return true }
            budget -= 1
            guard budget > 0, !Task.isCancelled else { return false }
            let tip = tips[depth], band = requests[depth]
            let options = allowedVariants.filter {
                $0.tip == tip && !used.contains($0.boardID) && byID[$0.boardID].map { band.degrees.contains(Int($0.angle.rounded())) } == true
            }.shuffled(using: &random)
            for variant in options {
                guard let board = byID[variant.boardID] else { continue }
                used.insert(board.id); result.append((board, variant))
                if match(depth + 1) { return true }
                result.removeLast(); used.remove(board.id)
            }
            return false
        }
        // Re-pair the independent quotas without changing either selected condition set.
        for _ in 0..<64 {
            try Task.checkCancellation()
            tips.shuffle(using: &random); requests.shuffle(using: &random)
            let ordered = Array(zip(tips, requests)).sorted { a, b in
                func count(_ request: (TrainingFixedTip, SceneTrainingConfiguration.AngleRange)) -> Int {
                    allowedVariants.filter { variant in
                        variant.tip == request.0 && byID[variant.boardID].map {
                            request.1.degrees.contains(Int($0.angle.rounded()))
                        } == true
                    }.count
                }
                return count(a) < count(b)
            }
            tips = ordered.map(\.0); requests = ordered.map(\.1)
            if match(0) { return result.shuffled(using: &random) }
            budget = 2_000
        }
        throw Failure.coverage("未凑齐20个不同球形及指定杆法")
    }
}

/// Uses actual events from simulateFree. Geometric answers and solver feasibility are never scores.
enum AccuracyShotJudgement {
    static let version = "direct-pot-fixed-tip-v3"
    enum Outcome: String, Codable { case success, missed, wrongPocket, scratch, indirect, technicalFailure }
    static func evaluate(_ prediction: ShotPrediction, pocketIndex: Int) -> Outcome {
        guard prediction.hasFinalTableState else { return .technicalFailure }
        let cue = ShotInput.cueBallName, target = ShotInput.targetBallName
        if prediction.pocketedBalls.contains(cue) || prediction.cuePocketed { return .scratch }
        var contact = false
        var indirect = false
        var targetPocket: String?
        for event in prediction.events {
            switch event.kind {
            case let .ballBall(a, b):
                if !contact { contact = Set([a, b]) == Set([cue, target]); if !contact { indirect = true } }
            case let .ballCushion(ball):
                if ball == cue && !contact { indirect = true }
                if ball == target && targetPocket == nil {
                    guard let index = event.cushionIndex else { return .technicalFailure }
                    if (0..<6).contains(index) {
                        // A ball initially frozen to this rail may compress it as
                        // it is struck. A return after leaving the rail is a bank.
                        if contact && !isInitialFrozenContact(prediction, event: event, railIndex: index) {
                            indirect = true
                        }
                    } else {
                        guard let owner = mouthOwner(cushionIndex: index) else { return .technicalFailure }
                        if owner != pocketIndex { indirect = true }
                    }
                }
            case let .pocket(ball, id): if ball == target { targetPocket = id }
            }
        }
        guard let targetPocket else { return .missed }
        guard targetPocket == "pocket_\(pocketIndex)" else { return .wrongPocket }
        return contact && !indirect ? .success : .indirect
    }
    private static func isInitialFrozenContact(_ prediction: ShotPrediction, event: ShotEvent, railIndex: Int) -> Bool {
        guard let frames = prediction.recorder?.framesByBallName[ShotInput.targetBallName],
              let first = frames.first, first.time <= 0.00001 else { return false }
        let rail = TableGeometry.chineseEightBallQiuJi(surfaceY: 0).linearCushions[railIndex]
        let delta = rail.end - rail.start
        let length2 = delta.x * delta.x + delta.z * delta.z
        let projection = ((first.position.x - rail.start.x) * delta.x
            + (first.position.z - rail.start.z) * delta.z) / length2
        guard (0...1).contains(projection),
              abs((first.position - rail.start).dot(rail.normal) - BallPhysics.radius)
                <= SceneTrainingRailGeometry.contactRoundoff else { return false }
        // 0.1 mm separates numerical contact/compression from a departed ball.
        // Evidence comes from the actual recording, never from a geometric answer.
        return frames.filter { $0.time <= event.time }.allSatisfy {
            ($0.position - rail.start).dot(rail.normal) - BallPhysics.radius <= 0.0001
        }
    }
    /// The QiuJi factory adds 26 throat walls to the base factory's 18 lines.
    /// Base CAD corner order is LD/LU/RD/RU; public pocket order is LD/RD/LU/RU.
    /// Unknown geometry fails closed; regression tests also compare every actual segment to its pocket.
    static func mouthOwner(cushionIndex: Int) -> Int? {
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: 0)
        guard geometry.linearCushions.count == 44, geometry.circularCushions.count == 12 else { return nil }
        let cornerOrder = [0, 2, 1, 3]
        switch cushionIndex {
        case 6..<14: return cornerOrder[(cushionIndex - 6) / 2]
        case 14..<18: return 4 + (cushionIndex - 14) / 2
        case 18..<38: return [3, 2, 1, 0][(cushionIndex - 18) / 5]
        case 38..<44: return 4 + (cushionIndex - 38) / 3
        case 44..<52: return cornerOrder[(cushionIndex - 44) / 2]
        case 52..<56: return 4 + (cushionIndex - 52) / 2
        default: return nil
        }
    }
}
