import Foundation
import SceneKit

struct KBallConfiguration: Codable, Equatable {
    var filter = KBallBankFilter()
    var freePractice = false
    var playsStroke = true
}

struct KBallQuestion: Codable, Identifiable {
    let id: UUID
    let layout: KBallBankLayout
    let source: KBallBankQuestion
    let board: TrainingBankBoard
    var contentID: String { source.id }
    var second: TrainingBankPoint { .init(.init(Float(source.b[0]), 0, Float(source.b[1]))) }
    var ballNumber: Int { 1 }
    var secondBallNumber: Int { 8 }
    var requirementText: String { "要求：" + ([1: "一库", 2: "两库", 3: "三库"][source.rail] ?? "—") }
    var label: String { "\(source.rail)库 · \(source.timing.title)" }
    var separation: SeparationQuestion {
        .init(id: id, board: board, minimumCenterSpeed: 0, answer: .init(),
              answerDirection: .init(.init(Float(source.dir[0]), 0, Float(source.dir[1]))),
              target: [], audit: .init())
    }
}

@dynamicMemberLookup
struct KBallShot: Codable, Identifiable {
    var physical: SeparationShot
    let failure: KBallJudgement.Failure?
    let observedRail: Int?
    var id: UUID { physical.id }
    subscript<T>(dynamicMember key: KeyPath<SeparationShot, T>) -> T { physical[keyPath: key] }
    var playsStroke: Bool? { get { physical.playsStroke } set { physical.playsStroke = newValue } }
    init(question: KBallQuestion, input: SeparationInput, prediction: ShotPrediction, surfaceY: Float) throws {
        physical = try .init(question: question.separation, input: input, prediction: prediction,
                             surfaceY: surfaceY, scoresTrajectory: false)
        observedRail = KBallJudgement.observedRail(prediction, railID: question.source.railID)
        failure = KBallJudgement.failure(prediction, pocket: question.board.pocketIndex, question: question.source)
    }
    func prediction() -> ShotPrediction { physical.prediction() }
    var resultText: String {
        if failure == .rail, let observedRail { return "K球库次不符（本杆：\(observedRail)库）" }
        return failure?.rawValue ?? "进A并按要求K到B · 成功"
    }
}

/// The ledger stores only the first accepted answer; latestShot is the independent retry/replay fact.
struct KBallPracticeRecord: Codable, Identifiable {
    enum Status: String, Codable { case active, completed, ended }
    struct Attempt: Codable, Identifiable {
        let id, questionID: UUID
        let submittedAt: Date
        let failure: KBallJudgement.Failure?
    }
    static let payloadVersion = 1
    var version = Self.payloadVersion
    var judgementVersion: Int? = 2
    let id: UUID
    var logicalSessionID: UUID
    var ownerKey: String
    let is3D: Bool
    let configuration: KBallConfiguration
    let bankFingerprint: String
    let startedAt: Date
    var updatedAt: Date
    var status: Status = .active
    var activeSeconds: Double = 0
    var presentation: TrainingPresentation?
    var geometricReference: GeometricReferenceTool.Snapshot?
    var questions: [KBallQuestion]
    var cursor = 0
    var attempts: [Attempt] = []
    var latestShot: KBallShot?
    var draftInput = SeparationInput()
    var showingResult = false
    var initialPoses: [String: [Float]] = [:]
    var finalPoses: [String: [Float]] = [:]
    var viewBookmark: CameraRig.TrainingBookmark?
    var shotBookmark: CameraRig.TrainingBookmark?
    var seenContentIDs: Set<String> = []
    var completedQuestionOffset = 0
    var previousSuccessCount = 0
    var current: KBallQuestion? { questions.indices.contains(cursor) ? questions[cursor] : nil }
    var currentAttempt: Attempt? { attempts.first { $0.questionID == current?.id } }
    var currentConsumed: Bool { currentAttempt != nil }
    var consumed: [UUID: Date] { Dictionary(uniqueKeysWithValues: attempts.map { ($0.questionID, $0.submittedAt) }) }
    var totalProcessed: Int { completedQuestionOffset + attempts.count }
    var questionNumber: Int { completedQuestionOffset + cursor + 1 }
    var successCount: Int { previousSuccessCount + attempts.filter { $0.failure == nil }.count }
    var successRate: String { SceneTrainingMetrics.percentage(successCount, of: totalProcessed) }
    var finishMetrics: [(String, String)] { [("已练题数", "\(totalProcessed)"), ("成功率", successRate)] }
    var displayName: String { "K球练习 · " + (presentation?.summary ?? (is3D ? "3D" : "2D")) }
    var historyDetail: String {
        "已练\(attempts.count)题 · 成功率 " + SceneTrainingMetrics.percentage(attempts.filter { $0.failure == nil }.count, of: attempts.count)
    }
    init(ownerKey: String, is3D: Bool, configuration: KBallConfiguration,
         prepared: KBallQuestionPreparer.Prepared, now: Date = Date()) {
        id = UUID(); logicalSessionID = id; self.ownerKey = ownerKey; self.is3D = is3D
        self.configuration = configuration; bankFingerprint = prepared.fingerprint
        startedAt = now; updatedAt = now; questions = [prepared.question]
        seenContentIDs = [prepared.question.contentID]
        presentation = .init(is3D: is3D)
        presentation?.observe(.init(is3D: is3D), questionID: prepared.question.id)
    }
    mutating func accept(_ shot: KBallShot) {
        guard shot.questionID == current?.id, latestShot?.id != shot.id else { return }
        if currentAttempt == nil {
            attempts.append(.init(id: shot.id, questionID: shot.questionID, submittedAt: shot.submittedAt, failure: shot.failure))
        }
        latestShot = shot; draftInput = shot.input; updatedAt = Date()
    }
    mutating func resetInput() {
        draftInput = .init(); latestShot = nil; showingResult = false
        initialPoses = [:]; finalPoses = [:]; viewBookmark = nil; shotBookmark = nil
        geometricReference = nil
    }
    func continuation(prepared: KBallQuestionPreparer.Prepared) -> Self {
        var next = Self(ownerKey: ownerKey, is3D: is3D, configuration: configuration, prepared: prepared)
        next.logicalSessionID = logicalSessionID; next.presentation = presentation
        next.completedQuestionOffset = totalProcessed; next.previousSuccessCount = successCount
        next.seenContentIDs.formUnion(seenContentIDs)
        return next
    }
    var canResumeCurrentTraining: Bool { isCompatible && judgementVersion == 2 }
    var isCompatible: Bool {
        version == Self.payloadVersion && questions.indices.contains(cursor) && draftInput.isValid
            && Set(questions.map(\.id)).count == questions.count
            && Set(attempts.map(\.questionID)).count == attempts.count
            && attempts.allSatisfy { a in questions.contains { $0.id == a.questionID } }
            && questions.allSatisfy { q in
                (try? KBallBankStore.validate(q.layout, radius: Double(BallPhysics.radius))) != nil
                    && q.layout.questions.contains(q.source) && q.board.id == q.layout.id
                    && q.board.pocketIndex == q.layout.board.pocket
                    && abs(Double(q.board.cue.x) - q.layout.board.cue[0]) < 1e-5
                    && abs(Double(q.board.cue.z) - q.layout.board.cue[1]) < 1e-5
                    && abs(Double(q.board.target.x) - q.layout.board.object[0]) < 1e-5
                    && abs(Double(q.board.target.z) - q.layout.board.object[1]) < 1e-5
            }
            && (latestShot == nil || latestShot?.questionID == current?.id)
    }
    private static let magic = Data([0x4b, 0x42, 0x30, 0x31])
    func encodedPayload() throws -> Data {
        Self.magic + (try (JSONEncoder().encode(self) as NSData).compressed(using: .lzfse) as Data)
    }
    static func decodePayload(_ data: Data) throws -> Self {
        guard data.starts(with: magic) else { throw KBallBankStore.Failure.invalid("记录版本") }
        return try JSONDecoder().decode(Self.self, from: (Data(data.dropFirst(4)) as NSData).decompressed(using: .lzfse) as Data)
    }
}
