import Foundation
import SceneKit

struct AccuracyPracticeQuestion: Codable, Identifiable {
    let id: UUID
    let board: TrainingBankBoard
    let variantID: String
    let tip: TrainingFixedTip
    let ballNumber: Int
    let railClearance: Float
    var exactTip: AccuracyTip? = nil
    var fixedTip: AccuracyTip { exactTip ?? AccuracyTip(legacy: tip) }

    init(board: TrainingBankBoard, variant: TrainingAccuracyVariant) {
        id = UUID(); self.board = board; variantID = variant.id; tip = variant.tip
        ballNumber = Int(board.seed % 15) + 1
        railClearance = SceneTrainingRailGeometry.clearance(board.target.vector)
    }

    /// Tip is assigned after drawing geometry; it is not a stored solution/proof.
    init(board: TrainingBankBoard, tip: TrainingFixedTip) {
        id = UUID(); self.board = board; self.tip = tip
        variantID = TrainingBankIdentity.hash("grid-exercise-v1:\(board.id):\(tip.rawValue)")
        ballNumber = Int(board.seed % 15) + 1
        railClearance = SceneTrainingRailGeometry.clearance(board.target.vector)
    }
    init(board: TrainingBankBoard, selectedTip: AccuracyTip) {
        id = UUID(); self.board = board; tip = selectedTip.category; exactTip = selectedTip
        variantID = TrainingBankIdentity.hash("grid-exercise-v2:\(board.id):\(selectedTip.x.bitPattern):\(selectedTip.y.bitPattern)")
        ballNumber = Int(board.seed % 15) + 1
        railClearance = SceneTrainingRailGeometry.clearance(board.target.vector)
    }

}

struct AccuracyPracticeAttempt: Codable, Identifiable {
    struct Result: Codable {
        let outcome: AccuracyShotJudgement.Outcome
        let specifiedPocket: Bool
        let scratch: Bool
        let events: [TrainingProofEvent]
        let duration: Float
        let ruleVersion: String
        let finalPositions: [String: TrainingBankPoint]
        let pocketedBalls: Set<String>

        init(prediction: ShotPrediction, pocketIndex: Int) {
            outcome = AccuracyShotJudgement.evaluate(prediction, pocketIndex: pocketIndex)
            events = prediction.events.map(TrainingProofEvent.init)
            specifiedPocket = events.contains { $0.ball == ShotInput.targetBallName && $0.pocketID == "pocket_\(pocketIndex)" }
            scratch = events.contains { $0.kind == "pocket" && $0.ball == ShotInput.cueBallName }
            duration = prediction.duration
            ruleVersion = AccuracyShotJudgement.version
            finalPositions = prediction.finalPositions.mapValues(TrainingBankPoint.init)
            pocketedBalls = Set(prediction.pocketedBalls)
        }
        var countsAsAttempt: Bool { outcome != .technicalFailure }
    }
    let id: UUID
    let questionID: UUID
    let submittedAt: Date
    let direction: TrainingBankPoint
    let velocity: Float
    let tip: TrainingFixedTip
    let observations: Set<String>
    var result: Result?
    var exactTip: AccuracyTip? = nil
    var fixedTip: AccuracyTip { exactTip ?? AccuracyTip(legacy: tip) }
}

struct AccuracyPracticeRecord: Codable, Identifiable {
    enum Status: String, Codable { case active, completed, ended }
    static let payloadVersion = 1
    var version = Self.payloadVersion
    let id: UUID
    let ownerKey: String
    let is3D: Bool
    let configuration: SceneTrainingConfiguration
    let bankFingerprint: String
    let startedAt: Date
    var updatedAt: Date
    var endedAt: Date?
    var status: Status = .active
    var questions: [AccuracyPracticeQuestion]
    var cursor = 0
    var attempts: [AccuracyPracticeAttempt] = []
    var draftDirection: TrainingBankPoint
    var draftVelocity: Double = ShotTuning.defaultVelocity
    /// Optional for compatibility with records created before manual spin controls.
    var draftTip: AccuracyTip? = nil
    var observations: Set<String> = []

    var current: AccuracyPracticeQuestion? { questions.indices.contains(cursor) ? questions[cursor] : nil }
    var currentAttempt: AccuracyPracticeAttempt? { attempts.first { $0.questionID == current?.id } }
    var validAttempts: [AccuracyPracticeAttempt] { attempts.filter { $0.result?.countsAsAttempt == true } }
    var successCount: Int { validAttempts.filter { $0.result?.outcome == .success }.count }
    var displayName: String { is3D ? "3D准度" : "2D准度" }
    var currentTip: AccuracyTip {
        let base = current?.fixedTip ?? .center
        return constrainedTip(x: Double(draftTip?.x ?? base.x), y: Double(draftTip?.y ?? base.y)) ?? base
    }

    /// Project only editable axes onto the existing contact disc. A prescribed
    /// axis must never drift when the other axis reaches the circular limit.
    func constrainedTip(x requestedX: Double, y requestedY: Double) -> AccuracyTip? {
        guard requestedX.isFinite, requestedY.isFinite else { return nil }
        let base = current?.fixedTip ?? .center
        let side = configuration.allowsManualSideSpin
        let vertical = configuration.allowsManualVerticalSpin
        if !side && !vertical { return base }
        let limit = Double(CuePhysics.miscueLimitFraction)
        var x = side ? requestedX : Double(base.x)
        var y = vertical ? requestedY : Double(base.y)
        if side && vertical {
            let magnitude = hypot(x, y)
            if magnitude > limit { x *= limit / magnitude; y *= limit / magnitude }
        } else if side {
            let edge = sqrt(max(0, limit * limit - y * y))
            x = min(edge, max(-edge, x))
        } else {
            let edge = sqrt(max(0, limit * limit - x * x))
            y = min(edge, max(-edge, y))
        }
        return .init(x: Float(x), y: Float(y),
                     raisedForClearance: !vertical && base.raisedForClearance)
    }

    init(ownerKey: String, is3D: Bool, configuration: SceneTrainingConfiguration,
         bankFingerprint: String, questions: [AccuracyPracticeQuestion], now: Date = Date()) throws {
        guard let first = questions.first, questions.count == 20,
              Set(questions.map { $0.board.id }).count == 20 else {
            throw TrainingQuestionBank.Failure.invalid("A round requires twenty distinct boards")
        }
        id = UUID(); self.ownerKey = ownerKey; self.is3D = is3D
        self.configuration = configuration; self.bankFingerprint = bankFingerprint
        startedAt = now; updatedAt = now; self.questions = questions
        draftDirection = Self.initialDirection(for: first)
    }
    static func initialDirection(for question: AccuracyPracticeQuestion) -> TrainingBankPoint {
        let cue = question.board.cue, target = question.board.target
        let length = hypot(target.x - cue.x, target.z - cue.z)
        return .init(SCNVector3((target.x - cue.x) / length, 0, (target.z - cue.z) / length))
    }
    /// Ephemeral retry input. It has no ledger entry and cannot replace the first score.
    func practiceAttempt(now: Date = Date()) throws -> AccuracyPracticeAttempt {
        guard currentAttempt?.result?.countsAsAttempt == true, let current,
              draftDirection.isFinite, abs(hypot(draftDirection.x, draftDirection.z) - 1) < 0.0001,
              ShotTuning.velocityRange.contains(draftVelocity) else {
            throw TrainingQuestionBank.Failure.invalid("Invalid practice input")
        }
        return AccuracyPracticeAttempt(id: UUID(), questionID: current.id, submittedAt: now,
            direction: draftDirection, velocity: Float(draftVelocity), tip: currentTip.category,
            observations: observations, exactTip: currentTip)
    }
    mutating func freezeAttempt(now: Date = Date()) throws -> AccuracyPracticeAttempt {
        if let currentAttempt { return currentAttempt }
        guard status == .active, let current, draftDirection.isFinite,
              abs(hypot(draftDirection.x, draftDirection.z) - 1) < 0.0001,
              ShotTuning.velocityRange.contains(draftVelocity) else {
            throw TrainingQuestionBank.Failure.invalid("Invalid frozen input")
        }
        let attempt = AccuracyPracticeAttempt(id: UUID(), questionID: current.id, submittedAt: now,
            direction: draftDirection, velocity: Float(draftVelocity), tip: currentTip.category, observations: observations, exactTip: currentTip)
        attempts.append(attempt); updatedAt = now
        return attempt
    }
    /// A completed result is immutable. Technical retries keep the same frozen input/id.
    @discardableResult
    mutating func accept(_ result: AccuracyPracticeAttempt.Result, attemptID: UUID, now: Date = Date()) -> Bool {
        guard let index = attempts.firstIndex(where: { $0.id == attemptID }),
              attempts[index].result?.countsAsAttempt != true else { return false }
        attempts[index].result = result; updatedAt = now
        return true
    }
    mutating func advance(now: Date = Date()) throws {
        guard currentAttempt?.result?.countsAsAttempt == true else {
            throw TrainingQuestionBank.Failure.invalid("Current attempt is not complete")
        }
        if !configuration.freePractice && validAttempts.count == 20 {
            status = .completed; endedAt = now
        } else {
            guard questions.indices.contains(cursor + 1) else { throw TrainingQuestionBank.Failure.coverage("下一组题目") }
            cursor += 1
            draftDirection = Self.initialDirection(for: questions[cursor])
            draftVelocity = ShotTuning.defaultVelocity; draftTip = nil; observations = []
        }
        updatedAt = now
    }
}
