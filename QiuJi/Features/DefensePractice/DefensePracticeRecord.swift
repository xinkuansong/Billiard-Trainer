import Foundation
import SceneKit

enum DefenseMode: String, Codable, CaseIterable {
    case trajectory, free
    var title: String { self == .trajectory ? "轨迹模式" : "自由模式" }
}
enum DefenseKind: String, Codable, CaseIterable {
    case one, two_black, two_own, three
    var title: String { switch self {
    case .one: "单球 · 双方打8号"
    case .two_black: "两球 · 我方8号／对方9号"
    case .two_own: "两球 · 我方1号／对方8号"
    case .three: "三球 · 我方1号／对方9号"
    } }
}
struct DefenseConfiguration: Codable, Equatable {
    var mode: DefenseMode = .trajectory
    var kind: DefenseKind?
    // Retained only for decoding old records; none of these removed filters affect new draws.
    var tactic: String?
    var tactics: Set<String>?
    var spin: String?
    var distance: String?
    var freePractice = false // continuous training, distinct from free mode.
    var playsStroke = true
    var forCurrentBank: Self {
        var current = self
        current.tactic = nil; current.tactics = nil
        current.spin = nil; current.distance = nil
        return current
    }
}
struct DefenseQuestion: Codable, Identifiable {
    let id: UUID
    let source: DefenseBankQuestion
    let referenceIndex: Int?
    let referencePaths: [String: [SeparationTrajectory.Point]]
    var reference: DefenseBankQuestion.Reference? {
        guard let i = referenceIndex, source.references.indices.contains(i) else { return nil }
        return source.references[i]
    }
    var board: TrainingBankBoard {
        .init(gridID: source.id, seed: 0, cue: source.cueVector, target: source.ownVector, aim: source.ownVector, pocket: 0,
              angle: 0, side: 0, cueBand: .middle, pocketBand: .middle, combinationID: source.id,
              qualification: "defense-parameters-v1", generationAngle: 0)
    }
    var contentID: String { source.id }
    var ballNumber: Int { source.ownBallNumber }
    var requirementText: String { "先碰\(ballNumber)号，合法防守 · 对方打\(source.opponentBallNumber)号" }
    var initialDirection: TrainingBankPoint {
        let d = source.ownVector - source.cueVector
        return .init(d * (1 / hypot(d.x, d.z)))
    }
    var separation: SeparationQuestion {
        .init(id: id, board: board, minimumCenterSpeed: 0, answer: .init(),
              answerDirection: initialDirection, target: [], audit: .init())
    }
}
@dynamicMemberLookup
struct DefenseShot: Codable, Identifiable {
    var physical: SeparationShot
    let effect: DefenseEffect
    let trajectoryScore: Double?
    let trajectoryDistanceCM: Double?
    let trajectoryErrorsCM: [String: Double]
    var failure: String? { effect.failure }
    var id: UUID { physical.id }
    subscript<T>(dynamicMember key: KeyPath<SeparationShot, T>) -> T { physical[keyPath: key] }
    var playsStroke: Bool? { get { physical.playsStroke } set { physical.playsStroke = newValue } }
    init(question: DefenseQuestion, input: SeparationInput, prediction: ShotPrediction, surfaceY: Float) throws {
        physical = try .init(question: question.separation, input: input, prediction: prediction, surfaceY: surfaceY, scoresTrajectory: false)
        effect = try DefenseEffect.evaluate(question: question.source, prediction: prediction)
        var distances = [Double]()
        var errors = [String: Double]()
        for (name, reference) in question.referencePaths {
            let actual = try SeparationTrajectory.extractBall(prediction, name: name)
            let a = try SeparationArcRMSMetric.sample(reference.map { .init(Double($0.position.x)*100, Double($0.position.z)*100) })
            let b = try SeparationArcRMSMetric.sample(actual.map { .init(Double($0.position.x)*100, Double($0.position.z)*100) })
            if a.length > 0.1 || b.length > 0.1 {
                let distance = try SeparationArcRMSMetric.distance(a, b)
                distances.append(distance); errors[name] = distance
            }
        }
        trajectoryErrorsCM = errors
        trajectoryDistanceCM = distances.isEmpty ? nil : sqrt(distances.map { $0*$0 }.reduce(0,+) / Double(distances.count))
        if let d = trajectoryDistanceCM { trajectoryScore = effect.failure == nil ? 100 * exp2(-d / 20) : 0 }
        else { trajectoryScore = nil }
    }
    func prediction() -> ShotPrediction { physical.prediction() }
    var trajectory: [SeparationTrajectory.Point] { (try? SeparationTrajectory.extractCue(prediction())) ?? [] }
    var resultText: String { effect.resultText }
    var detail: String {
        var lines = [effect.detail]
        if let trajectoryScore, let trajectoryDistanceCM {
            lines += [String(format: "轨迹偏差：%.1f cm", trajectoryDistanceCM), String(format: "轨迹得分：%.1f", trajectoryScore)]
        }
        for key in trajectoryErrorsCM.keys.sorted() {
            let name = key == ShotInput.cueBallName ? "母球" : String(key.dropFirst()) + "号球"
            lines.append(String(format: "%@偏差：%.1f cm", name, trajectoryErrorsCM[key]!))
        }
        lines.append("重打不改首答成绩；轨迹与防守分别计分。")
        return lines.joined(separator: "\n")
    }
}

/// The ledger stores only the first accepted answer; latestShot is the independent retry/replay fact.
struct DefensePracticeRecord: Codable, Identifiable {
    enum Status: String, Codable { case active, completed, ended }
    struct Attempt: Codable, Identifiable {
        let id, questionID: UUID
        let submittedAt: Date
        let failure: String?
        let effectScore: Double?
        let trajectoryScore: Double?
    }
    static let payloadVersion = 1
    var version = Self.payloadVersion
    var judgementVersion: Int? = 1
    var physicsVersion = "planarReference-20261104"
    var scoringVersion = DefenseEffect.version
    let id: UUID
    var logicalSessionID: UUID
    var ownerKey: String
    let is3D: Bool
    let configuration: DefenseConfiguration
    let bankFingerprint: String
    let startedAt: Date
    var updatedAt: Date
    var status: Status = .active
    var activeSeconds: Double = 0
    var presentation: TrainingPresentation?
    var geometricReference: GeometricReferenceTool.Snapshot?
    var questions: [DefenseQuestion]
    var cursor = 0
    var attempts: [Attempt] = []
    var latestShot: DefenseShot?
    var draftInput = SeparationInput()
    var draftDirection: TrainingBankPoint
    var showingResult = false
    var initialPoses: [String: [Float]] = [:]
    var finalPoses: [String: [Float]] = [:]
    var viewBookmark: CameraRig.TrainingBookmark?
    var shotBookmark: CameraRig.TrainingBookmark?
    var seenContentIDs: Set<String> = []
    var completedQuestionOffset = 0
    var previousSuccessCount = 0
    var previousScoreSum = 0.0
    var previousScoredCount = 0
    var current: DefenseQuestion? { questions.indices.contains(cursor) ? questions[cursor] : nil }
    var currentAttempt: Attempt? { attempts.first { $0.questionID == current?.id } }
    var currentConsumed: Bool { currentAttempt != nil }
    var consumed: [UUID: Date] { Dictionary(uniqueKeysWithValues: attempts.map { ($0.questionID, $0.submittedAt) }) }
    var totalProcessed: Int { completedQuestionOffset + attempts.count }
    var questionNumber: Int { completedQuestionOffset + cursor + 1 }
    var successCount: Int { previousSuccessCount + attempts.filter { $0.failure == nil }.count }
    var scoreSum: Double { previousScoreSum + attempts.compactMap(\.effectScore).reduce(0, +) }
    var scoredCount: Int { previousScoredCount + attempts.compactMap(\.effectScore).count }
    var average: String { scoredCount == 0 ? "—" : String(format: "%.1f", scoreSum / Double(scoredCount)) }
    var successRate: String { SceneTrainingMetrics.percentage(successCount, of: totalProcessed) }
    var finishMetrics: [(String, String)] { [("已练题数", "\(totalProcessed)"), ("防守均分", average)] }
    var displayName: String { "防守练习 · " + (presentation?.summary ?? (is3D ? "3D" : "2D")) }
    var historyDetail: String {
        "已练\(totalProcessed)题 · 防守均分 " + average
    }
    init(ownerKey: String, is3D: Bool, configuration: DefenseConfiguration,
         prepared: DefenseQuestionPreparer.Prepared, now: Date = Date()) {
        id = UUID(); logicalSessionID = id; self.ownerKey = ownerKey; self.is3D = is3D
        self.configuration = configuration; bankFingerprint = prepared.fingerprint
        startedAt = now; updatedAt = now; questions = [prepared.question]
        seenContentIDs = [prepared.question.contentID]
        draftDirection = prepared.question.initialDirection
        presentation = .init(is3D: is3D)
        presentation?.observe(.init(is3D: is3D), questionID: prepared.question.id)
    }
    mutating func accept(_ shot: DefenseShot) {
        guard shot.questionID == current?.id, latestShot?.id != shot.id else { return }
        if currentAttempt == nil {
            attempts.append(.init(id: shot.id, questionID: shot.questionID, submittedAt: shot.submittedAt, failure: shot.failure, effectScore: shot.effect.score, trajectoryScore: shot.trajectoryScore))
        }
        latestShot = shot; draftInput = shot.input; draftDirection = shot.direction; updatedAt = Date()
    }
    mutating func resetInput() {
        draftInput = .init(); latestShot = nil; showingResult = false; geometricReference = nil
        if let current { draftDirection = current.initialDirection }
        initialPoses = [:]; finalPoses = [:]; viewBookmark = nil; shotBookmark = nil
    }
    func continuation(prepared: DefenseQuestionPreparer.Prepared) -> Self {
        var next = Self(ownerKey: ownerKey, is3D: is3D, configuration: configuration, prepared: prepared)
        next.logicalSessionID = logicalSessionID; next.presentation = presentation
        next.completedQuestionOffset = totalProcessed; next.previousSuccessCount = successCount
        next.previousScoreSum = scoreSum; next.previousScoredCount = scoredCount
        next.seenContentIDs.formUnion(seenContentIDs)
        return next
    }
    var canResumeCurrentTraining: Bool {
        isCompatible && judgementVersion == 1 && physicsVersion == "planarReference-20261104" && scoringVersion == DefenseEffect.version && bankFingerprint == DefenseBankStore.fingerprint
    }
    var isCompatible: Bool {
        version == Self.payloadVersion && questions.indices.contains(cursor) && draftInput.isValid
            && Set(questions.map(\.id)).count == questions.count
            && Set(attempts.map(\.questionID)).count == attempts.count
            && attempts.allSatisfy { a in questions.contains { $0.id == a.questionID } }
            && questions.allSatisfy { $0.source.isValid }
            && draftDirection.isFinite && abs(hypot(draftDirection.x, draftDirection.z)-1) < 0.0001
            && (latestShot == nil || latestShot?.questionID == current?.id)
    }
    private static let magic = Data([0x44, 0x50, 0x30, 0x31])
    func encodedPayload() throws -> Data {
        Self.magic + (try (JSONEncoder().encode(self) as NSData).compressed(using: .lzfse) as Data)
    }
    static func decodePayload(_ data: Data) throws -> Self {
        guard data.starts(with: magic) else { throw DefenseBankStore.Failure.invalid("记录版本") }
        return try JSONDecoder().decode(Self.self, from: (Data(data.dropFirst(4)) as NSData).decompressed(using: .lzfse) as Data)
    }
}
