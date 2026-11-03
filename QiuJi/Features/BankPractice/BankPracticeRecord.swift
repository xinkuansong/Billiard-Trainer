import Foundation
import SceneKit

enum BankPocketType: String, Codable, CaseIterable {
    case middle, corner
    var title: String { self == .middle ? "中袋" : "底袋" }
}

struct BankConfiguration: Codable, Equatable {
    static let availableRailCounts = 1...3
    /// Normalize only a new settings draft; historical records retain their original configuration.
    var forCurrentBank: Self {
        var draft = self
        if let count = draft.railCount, !Self.availableRailCounts.contains(count) { draft.railCount = nil }
        return draft
    }
    var railCount: Int? = nil
    var pocketType: BankPocketType? = nil
    var freePractice = false
    var playsStroke = true
    // Optional storage preserves configurations saved before color hints existed.
    var railColorHints: Bool? = nil
    var showsRailColors: Bool {
        get { railColorHints ?? true }
        set { railColorHints = newValue }
    }
}

struct BankQuestion: Codable, Identifiable {
    let id: UUID
    let source: BankPracticeBankQuestion
    var railSegments: [Int] { source.railSegments }
    var board: TrainingBankBoard { source.board }
    var contentID: String { source.id }
    var ballNumber: Int { 1 }
    var requirementText: String {
        "\(label) · 目标球按指定库序进入标记袋"
    }
    var label: String { "\(source.walls.count)库翻\(source.pocketType.title)" }
    var initialDirection: TrainingBankPoint {
        let delta = source.target.vector - source.cue.vector
        return .init(delta * (1 / hypot(delta.x, delta.z)))
    }
    var separation: SeparationQuestion {
        .init(id: id, board: board, minimumCenterSpeed: 0, answer: .init(),
              answerDirection: source.direction,
              target: [], audit: .init())
    }
}

@dynamicMemberLookup
struct BankShot: Codable, Identifiable {
    var physical: SeparationShot
    let judgement: BankJudgement.Result
    var failure: BankJudgement.Failure? { judgement.failures.first }
    var id: UUID { physical.id }
    subscript<T>(dynamicMember key: KeyPath<SeparationShot, T>) -> T { physical[keyPath: key] }
    var playsStroke: Bool? { get { physical.playsStroke } set { physical.playsStroke = newValue } }
    init(question: BankQuestion, input: SeparationInput, prediction: ShotPrediction, surfaceY: Float) throws {
        physical = try .init(question: question.separation, input: input, prediction: prediction,
                             surfaceY: surfaceY, scoresTrajectory: false)
        judgement = BankJudgement.evaluate(prediction, question: question.source, surfaceY: surfaceY)
    }
    func prediction() -> ShotPrediction { physical.prediction() }
    var trajectory: [SeparationTrajectory.Point] { (try? SeparationTrajectory.extractCue(prediction())) ?? [] }
    var resultText: String {
        if let failure { return failure.rawValue + " · 失败" }
        return "按指定库序进袋 · 成功"
    }
}

/// The ledger stores only the first accepted answer; latestShot is the independent retry/replay fact.
struct BankPracticeRecord: Codable, Identifiable {
    enum Status: String, Codable { case active, completed, ended }
    struct Attempt: Codable, Identifiable {
        let id, questionID: UUID
        let submittedAt: Date
        let failure: BankJudgement.Failure?
    }
    static let payloadVersion = 1
    var version = Self.payloadVersion
    var judgementVersion: Int? = 1
    let id: UUID
    var logicalSessionID: UUID
    var ownerKey: String
    let is3D: Bool
    let configuration: BankConfiguration
    let bankFingerprint: String
    let startedAt: Date
    var updatedAt: Date
    var status: Status = .active
    var activeSeconds: Double = 0
    var presentation: TrainingPresentation?
    var geometricReference: GeometricReferenceTool.Snapshot?
    var questions: [BankQuestion]
    var cursor = 0
    var attempts: [Attempt] = []
    var latestShot: BankShot?
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
    var current: BankQuestion? { questions.indices.contains(cursor) ? questions[cursor] : nil }
    var currentAttempt: Attempt? { attempts.first { $0.questionID == current?.id } }
    var currentConsumed: Bool { currentAttempt != nil }
    var consumed: [UUID: Date] { Dictionary(uniqueKeysWithValues: attempts.map { ($0.questionID, $0.submittedAt) }) }
    var totalProcessed: Int { completedQuestionOffset + attempts.count }
    var questionNumber: Int { completedQuestionOffset + cursor + 1 }
    var successCount: Int { previousSuccessCount + attempts.filter { $0.failure == nil }.count }
    var successRate: String { SceneTrainingMetrics.percentage(successCount, of: totalProcessed) }
    var finishMetrics: [(String, String)] { [("已练题数", "\(totalProcessed)"), ("成功率", successRate)] }
    var displayName: String { "翻袋练习 · " + (presentation?.summary ?? (is3D ? "3D" : "2D")) }
    var historyDetail: String {
        "已练\(attempts.count)题 · 成功率 " + SceneTrainingMetrics.percentage(attempts.filter { $0.failure == nil }.count, of: attempts.count)
    }
    init(ownerKey: String, is3D: Bool, configuration: BankConfiguration,
         prepared: BankQuestionPreparer.Prepared, now: Date = Date()) {
        id = UUID(); logicalSessionID = id; self.ownerKey = ownerKey; self.is3D = is3D
        self.configuration = configuration; bankFingerprint = prepared.fingerprint
        startedAt = now; updatedAt = now; questions = [prepared.question]
        seenContentIDs = [prepared.question.contentID]
        draftDirection = prepared.question.initialDirection
        presentation = .init(is3D: is3D)
        presentation?.observe(.init(is3D: is3D), questionID: prepared.question.id)
    }
    mutating func accept(_ shot: BankShot) {
        guard shot.questionID == current?.id, latestShot?.id != shot.id else { return }
        if currentAttempt == nil {
            attempts.append(.init(id: shot.id, questionID: shot.questionID, submittedAt: shot.submittedAt, failure: shot.failure))
        }
        latestShot = shot; draftInput = shot.input; draftDirection = shot.direction; updatedAt = Date()
    }
    mutating func resetInput() {
        draftInput = .init(); latestShot = nil; showingResult = false; geometricReference = nil
        if let current { draftDirection = current.initialDirection }
        initialPoses = [:]; finalPoses = [:]; viewBookmark = nil; shotBookmark = nil
    }
    func continuation(prepared: BankQuestionPreparer.Prepared) -> Self {
        var next = Self(ownerKey: ownerKey, is3D: is3D, configuration: configuration, prepared: prepared)
        next.logicalSessionID = logicalSessionID; next.presentation = presentation
        next.completedQuestionOffset = totalProcessed; next.previousSuccessCount = successCount
        next.seenContentIDs.formUnion(seenContentIDs)
        return next
    }
    var canResumeCurrentTraining: Bool {
        isCompatible && judgementVersion == 1 && bankFingerprint == BankPracticeBankStore.fingerprint
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
    private static let magic = Data([0x42, 0x50, 0x30, 0x31])
    func encodedPayload() throws -> Data {
        Self.magic + (try (JSONEncoder().encode(self) as NSData).compressed(using: .lzfse) as Data)
    }
    static func decodePayload(_ data: Data) throws -> Self {
        guard data.starts(with: magic) else { throw BankPracticeBankStore.Failure.invalid("记录版本") }
        return try JSONDecoder().decode(Self.self, from: (Data(data.dropFirst(4)) as NSData).decompressed(using: .lzfse) as Data)
    }
}
