import Foundation
import SceneKit

extension SpatialQuizMode {
    var title: String { self == .masse ? "扎杆练习" : "跳球练习" }
    var kind: String { self == .masse ? TrainingSessionKind.massePractice : TrainingSessionKind.jumpPractice }
}
struct SpatialQuizConfiguration: Codable, Equatable {
    var filter = SpatialQuizFilter()
    var freePractice = false
    var playsStroke = true
}
struct SpatialQuizInstance: Codable, Identifiable {
    let id: UUID
    let source: SpatialQuizQuestion
    init(_ source: SpatialQuizQuestion) { id = UUID(); self.source = source }
    var board: [String: SpatialPracticeRecord.Pose] {
        let b = source.board
        return [PositionPlayBall.cueKey: b.cue, b.targetName: b.target, "_8": b.obstacle].mapValues {
            .init(position: .init($0), rotation: [0,0,0,1], disposition: "bed")
        }
    }
    var initialInput: SpatialQuizPhysics.Input {
        .init(yaw: atan2(source.target.z-source.cue.z,source.target.x-source.cue.x), speed: 2, spinX: 0, spinY: 0, elevation: source.mode == .masse ? 25 : 45)
    }
}
struct SpatialQuizShot: Codable, Identifiable {
    let id, questionID: UUID
    let submittedAt: Date
    var physical: SpatialPracticeRecord.Shot
    let facts: SpatialQuizFacts
    let outcome: SpatialQuizJudgement.Outcome
    static func make(_ result: SpatialQuizPhysics.Result, pending: SpatialQuizRecord.Pending,
                     question: SpatialQuizInstance, cancellation: PredictionCancellation? = nil) throws -> Self {
        guard pending.questionID == question.id, result.facts.mode == question.source.mode, result.outcome.confirmed,
              let physical = SpatialPracticeRecord.freeze(prediction: result.prediction,
                input: pending.input.spatialInput, before: question.board, cancellation: cancellation) else {
            throw SpatialQuizBank.Failure.invalid("本次未能完成计算，请重试")
        }
        return .init(id: pending.id, questionID: question.id, submittedAt: pending.submittedAt,
            physical: physical, facts: result.facts, outcome: result.outcome)
    }
    var valid: Bool {
        facts.mode != nil && outcome.confirmed && outcome == SpatialQuizJudgement.evaluate(facts) &&
        SpatialPracticeRecord.validShot(physical) && physical.recovered == nil && physical.recoveries == nil &&
        physical.before.count == 3 && physical.after.count == 3 && physical.paths.count == 3
    }
    /// History may keep an older ruling/geometry. Validate stored values without
    /// replaying them or applying today's geometry and scoring to past answers.
    var archiveValid: Bool {
        let p = physical
        func boardValid(_ board: [String: SpatialPracticeRecord.Pose]) -> Bool {
            board.count == 3 && board.allSatisfy { key, pose in
                PositionPlayBall.allKeys.contains(key) && pose.position.finite &&
                pose.rotation.count == 4 && pose.rotation.allSatisfy(\.isFinite) &&
                ["bed","pocket","outside","escaped"].contains(pose.disposition)
            }
        }
        guard outcome.confirmed, facts.archiveValid, !p.geometryVersion.isEmpty,
              p.input.valid, p.duration.isFinite, (0...45).contains(p.duration),
              p.maximumHeight.isFinite, p.maximumHeight >= 0,
              boardValid(p.before), boardValid(p.after), p.paths.count == 3,
              Set(p.before.keys) == Set(p.after.keys), Set(p.paths.keys) == Set(p.before.keys),
              p.recovered == nil, p.recoveries == nil else { return false }
        return p.paths.values.allSatisfy { samples in
            guard !samples.isEmpty, samples.count <= 100_000 else { return false }
            var previous: Float = -1
            for sample in samples {
                guard sample.time.isFinite, sample.time >= previous, sample.time >= 0,
                      sample.time <= p.duration, sample.position.finite,
                      sample.rotation.count == 4, sample.rotation.allSatisfy(\.isFinite) else { return false }
                previous = sample.time
            }
            return true
        }
    }
}
extension SpatialQuizFacts {
    var archiveValid: Bool {
        complete && issues.isEmpty && (technique?.valid ?? true) && duration.isFinite && (0...45).contains(duration) &&
        events.allSatisfy { event in
            guard event.time.isFinite, event.time >= 0,
                  event.time <= duration + SpatialQuizJudgement.contactTimeGroup,
                  !event.source.isEmpty,
                  event.physicalTime.map({ $0.isFinite && $0 >= 0 }) ?? true else { return false }
            switch event.kind {
            case let .balls(a,b): return a != b
            case let .pocket(_,id): return !id.isEmpty
            default: return true
            }
        }
    }
}
extension SpatialQuizPhysics.Input {
    var spatialInput: SpatialPracticeRecord.Input {
        .init(yaw: yaw, speed: speed, spinX: spinX, spinY: spinY, elevation: elevation, preferredElevation: preferredElevation)
    }
}
struct SpatialQuizRecord: Codable, Identifiable {
    enum Phase: String, Codable { case aiming, calculating, result, summary }
    enum Status: String, Codable { case active, completed, ended }
    struct Pending: Codable, Equatable, Identifiable {
        let id, questionID: UUID
        let input: SpatialQuizPhysics.Input
        let submittedAt: Date
        let premium: Bool
    }
    struct FirstAnswer: Codable, Identifiable {
        let id, questionID: UUID
        let input: SpatialPracticeRecord.Input
        let facts: SpatialQuizFacts
        let outcome: SpatialQuizJudgement.Outcome
        let receipt: TrainingConsumptionReceipt
    }
    static let version = 1
    var version = Self.version
    var judgementVersion = SpatialQuizJudgement.version
    var geometryVersion = SpatialPracticeGeometry.version
    let id: UUID
    var logicalSessionID: UUID
    var ownerKey: String
    let mode: SpatialQuizMode
    let configuration: SpatialQuizConfiguration
    let bankFingerprint: String
    let startedAt: Date
    var updatedAt: Date
    var activeSeconds: Double = 0
    var status: Status = .active
    var phase: Phase = .aiming
    var questions: [SpatialQuizInstance]
    var cursor = 0
    var firstAnswers: [FirstAnswer] = []
    var latestShot: SpatialQuizShot?
    var pending: Pending?
    var draft: SpatialQuizPhysics.Input
    var demonstrationProgress = PracticeDemonstrationProgress()
    var bookmark: CameraRig.TrainingBookmark?
    var seenContentIDs: Set<String>
    var previousCount = 0
    var previousSuccessCount = 0
    var current: SpatialQuizInstance { questions[cursor] }
    var currentFirst: FirstAnswer? { firstAnswers.first { $0.questionID == current.id } }
    var totalCount: Int { previousCount + firstAnswers.count }
    var successCount: Int { previousSuccessCount + firstAnswers.filter { $0.outcome.succeeded }.count }
    var successRate: String { SceneTrainingMetrics.percentage(successCount, of: totalCount) }
    var questionNumber: Int { previousCount + cursor + 1 }
    var displayName: String { mode.title }
    var historyDetail: String { "已练\(firstAnswers.count)题 · 成功\(firstAnswers.filter { $0.outcome.succeeded }.count)题 · 成功率 " + SceneTrainingMetrics.percentage(firstAnswers.filter { $0.outcome.succeeded }.count, of: firstAnswers.count) }
    var isCurrentCompatible: Bool {
        judgementVersion == SpatialQuizJudgement.version && geometryVersion == SpatialPracticeGeometry.version && valid
    }
    init(owner: String, mode: SpatialQuizMode, configuration: SpatialQuizConfiguration,
         bank: SpatialQuizBank.Bank, questions: [SpatialQuizQuestion], now: Date = Date()) {
        precondition(!questions.isEmpty)
        id = UUID(); logicalSessionID = id; ownerKey = owner; self.mode = mode
        self.configuration = configuration; bankFingerprint = bank.fingerprint
        startedAt = now; updatedAt = now; self.questions = questions.map(SpatialQuizInstance.init)
        draft = self.questions[0].initialInput; seenContentIDs = Set(questions.map(\.id))
    }
    mutating func accept(_ shot: SpatialQuizShot) {
        guard shot.questionID == current.id, pending?.id == shot.id, latestShot?.id != shot.id else { return }
        if currentFirst == nil {
            firstAnswers.append(.init(id: shot.id, questionID: shot.questionID,
                input: shot.physical.input, facts: shot.facts, outcome: shot.outcome,
                receipt: .init(questionID: shot.questionID, acceptedAt: shot.submittedAt, charged: pending?.premium == false)))
        }
        demonstrationProgress.accept(id: shot.id, qualified: shot.outcome.succeeded)
        latestShot = shot; pending = nil; phase = .result; updatedAt = Date()
    }
    mutating func advance() {
        cursor += 1; draft = current.initialInput; latestShot = nil; pending = nil
        demonstrationProgress = .init(); bookmark = nil; phase = .aiming; updatedAt = Date()
    }
    var valid: Bool {
        let currentRule = judgementVersion == SpatialQuizJudgement.version
        let currentGeometry = geometryVersion == SpatialPracticeGeometry.version
        guard version == Self.version, !judgementVersion.isEmpty, !geometryVersion.isEmpty, !ownerKey.isEmpty,
              !questions.isEmpty, questions.indices.contains(cursor), draft.valid,
              activeSeconds.isFinite, activeSeconds >= 0, previousCount >= 0,
              previousSuccessCount >= 0, previousSuccessCount <= previousCount,
              Set(questions.map(\.id)).count == questions.count,
              Set(questions.map { $0.source.id }).count == questions.count,
              questions.allSatisfy({ q in
                  let s=q.source
                  return s.mode == mode && s.reference.valid && (1...15).contains(s.targetNumber) && s.targetNumber != 8 &&
                    [s.cue.x,s.cue.z,s.target.x,s.target.z,s.obstacle.x,s.obstacle.z].allSatisfy(\.isFinite) &&
                    (!currentGeometry || s.board.valid)
              }),
              Set(firstAnswers.map(\.id)).count == firstAnswers.count,
              Set(firstAnswers.map(\.questionID)).count == firstAnswers.count,
              firstAnswers.allSatisfy({ a in questions.contains { $0.id == a.questionID } && a.input.valid &&
                  a.outcome.confirmed && a.facts.archiveValid &&
                  (!currentRule || (a.facts.mode == mode && a.outcome == SpatialQuizJudgement.evaluate(a.facts))) && a.receipt.questionID == a.questionID }),
              pending.map({ $0.questionID == current.id && $0.input.valid }) ?? true,
              latestShot.map({ $0.questionID == current.id &&
                  (currentRule && currentGeometry ? $0.valid : $0.archiveValid) &&
                  (!currentRule || $0.facts.mode == mode) &&
                  (!currentGeometry || $0.physical.before == current.board)
                  && Set($0.physical.paths.keys) == Set(current.board.keys) }) ?? true else { return false }
        if phase == .calculating && pending == nil { return false }
        if phase == .result && (latestShot == nil || currentFirst == nil) { return false }
        return true
    }
    static let payloadLimit = 1_450_000
    private static let magic = Data([0x53,0x51,0x30,0x31])
    func encodedPayload() throws -> Data {
        guard valid else { throw SpatialQuizBank.Failure.invalid("练习记录校验失败") }
        let data = Self.magic + (try (JSONEncoder().encode(self) as NSData).compressed(using: .lzfse) as Data)
        guard data.count < Self.payloadLimit else { throw SpatialQuizBank.Failure.invalid("本题轨迹记录过大，请保留当前击打后重试") }
        return data
    }
    static func decodePayload(_ data: Data) throws -> Self {
        guard data.starts(with: magic), data.count < payloadLimit else { throw SpatialQuizBank.Failure.invalid("练习记录版本或大小异常") }
        let raw = try (Data(data.dropFirst(4)) as NSData).decompressed(using: .lzfse) as Data
        guard raw.count < 32_000_000 else { throw SpatialQuizBank.Failure.invalid("练习记录解压过大") }
        let record = try JSONDecoder().decode(Self.self, from: raw)
        guard record.valid else { throw SpatialQuizBank.Failure.invalid("练习记录内容异常，原记录已保留") }
        return record
    }
}
