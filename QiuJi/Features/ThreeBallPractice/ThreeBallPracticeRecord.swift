import Foundation

struct ThreeBallPracticeRecord: Codable, Identifiable {
    enum Status: String, Codable { case active, completed, ended }
    struct Attempt: Codable, Identifiable {
        let id, questionID: UUID
        let stage: Int
        let submittedAt: Date
        let score: Double
        let pocket: Int
        let failure: String?
    }
    struct StageCheckpoint: Codable {
        let question: ThreeBallQuestion
        let shot: ThreeBallShot
        let initialPoses: [String: [Float]]
        let finalPoses: [String: [Float]]
        let viewBookmark: CameraRig.TrainingBookmark?
        let shotBookmark: CameraRig.TrainingBookmark?
    }
    static let payloadVersion = 1
    var version = Self.payloadVersion
    let id: UUID
    var logicalSessionID: UUID
    var ownerKey: String
    let is3D: Bool
    var presentation: TrainingPresentation?
    var geometricReference: GeometricReferenceTool.Snapshot?
    let configuration: SceneTrainingConfiguration
    let bankFingerprint: String
    let startedAt: Date
    var updatedAt: Date
    var status: Status = .active
    var activeSeconds: Double = 0
    var questions: [ThreeBallQuestion]
    var cursor = 0
    var attempts: [Attempt] = []
    var latestShot: ThreeBallShot?
    var firstStageScore: Double?
    var firstStageCheckpoint: StageCheckpoint?
    var draftInput = SeparationInput()
    var showingResult = false
    var initialPoses: [String: [Float]] = [:]
    var finalPoses: [String: [Float]] = [:]
    var viewBookmark: CameraRig.TrainingBookmark?
    var shotBookmark: CameraRig.TrainingBookmark?
    var consumed: [UUID: Date] = [:]
    var completedQuestionOffset = 0
    var previousScoreSum: Double = 0
    var previousScoreCount = 0
    var seenContentIDs: Set<String> = []
    var current: ThreeBallQuestion? { questions.indices.contains(cursor) ? questions[cursor] : nil }
    var currentConsumed: Bool { current.map { consumed[$0.id] != nil } ?? false }
    var questionNumber: Int { completedQuestionOffset + cursor + 1 }
    var totalProcessed: Int { completedQuestionOffset + consumed.count }
    var canAdvanceStage: Bool { current?.stage == 0 && latestShot?.failure == nil && latestShot != nil && showingResult }
    var questionComplete: Bool { showingResult && (current?.stage == 1 || latestShot?.failure != nil) }
    var plannedPocketLocked: Bool { showingResult }
    var canRetryPreviousStage: Bool { current?.stage == 1 && latestShot == nil && firstStageCheckpoint != nil }
    var firstAnswerScores: [Double] {
        Dictionary(grouping: attempts, by: \.questionID).values.compactMap { rows in
            guard let first = rows.first(where: { $0.stage == 0 }) else { return nil }
            if let second = rows.first(where: { $0.stage == 1 }) { return (first.score + second.score) / 2 }
            return first.failure == nil ? nil : 0
        }
    }
    var averageScore: Double? {
        let n = previousScoreCount + firstAnswerScores.count
        return n > 0 ? (previousScoreSum + firstAnswerScores.reduce(0,+))/Double(n) : nil
    }
    var questionAverage: Double? {
        guard questionComplete, let shot = latestShot else { return nil }
        return current?.stage == 1 ? ((firstStageScore ?? 0) + shot.freeScore)/2 : 0
    }
    var finishMetrics: [(String,String)] {
        [("已练题数", "\(totalProcessed)"), ("首答均分", averageScore.map { String(format: "%.1f", $0) } ?? "—")]
    }
    var displayName: String { presentation == nil ? ("\(is3D ? "3D" : "2D")三球走位") : "三球走位 · " + (presentation?.summary ?? "") }
    var historyDetail: String {
        "已练\(consumed.count)题 · 首答均分 " + (averageScore.map { String(format: "%.1f", $0) } ?? "—")
    }
    init(ownerKey: String, is3D: Bool, configuration: SceneTrainingConfiguration,
         prepared: ThreeBallQuestionPreparer.Prepared, now: Date = Date()) {
        id = UUID(); logicalSessionID = id; self.ownerKey = ownerKey; self.is3D = is3D
        presentation = .init(is3D: is3D)
        presentation?.observe(.init(is3D: is3D), questionID: prepared.question.id)
        self.configuration = configuration; bankFingerprint = prepared.fingerprint
        startedAt = now; updatedAt = now; questions = [prepared.question]; seenContentIDs = [prepared.question.contentID]
    }
    mutating func selectPocket(_ pocket: Int) {
        guard !showingResult, !plannedPocketLocked, questions.indices.contains(cursor), (0..<6).contains(pocket) else { return }
        questions[cursor].plannedPocket = pocket
    }
    mutating func accept(_ shot: ThreeBallShot) {
        guard shot.questionID == current?.id, shot.stage == current?.stage,
              shot.secondPocket == current?.plannedPocket, latestShot?.id != shot.id else { return }
        if !attempts.contains(where: { $0.questionID == shot.questionID && $0.stage == shot.stage }) {
            attempts.append(.init(id: shot.id, questionID: shot.questionID, stage: shot.stage,
                submittedAt: shot.submittedAt, score: shot.freeScore, pocket: shot.secondPocket, failure: shot.failure))
        }
        consumed[shot.questionID] = consumed[shot.questionID] ?? shot.submittedAt
        latestShot = shot; draftInput = shot.input; showingResult = true; updatedAt = Date()
    }
    mutating func advanceStage() throws {
        guard canAdvanceStage, let shot = latestShot, let q = current,
              let cue = shot.finalPositions[ShotInput.cueBallName],
              let target = shot.finalPositions[ThreeBallQuestionPreparer.secondBallName],
              let third = shot.finalPositions[ThreeBallQuestionPreparer.thirdBallName] else {
            throw SeparationQuestionGenerator.Failure.incomplete
        }
        let board = ThreeBallQuestionPreparer.board(id: q.board.id + "/second", cue: cue.value,
            target: target.value, pocket: shot.secondPocket)
        firstStageCheckpoint = .init(question: q, shot: shot, initialPoses: initialPoses, finalPoses: finalPoses,
                                     viewBookmark: viewBookmark, shotBookmark: shotBookmark)
        let endingPoses = finalPoses
        questions[cursor] = .init(id: q.id, contentID: q.contentID, board: board,
                                  second: .init(third.value), third: nil, stage: 1, identity: q.identity)
        firstStageScore = shot.freeScore
        resetInput()
        initialPoses = endingPoses.filter { $0.key == PositionPlayBall.cueKey || $0.key == current?.secondKey || $0.key == "_\(current?.ballNumber ?? 0)" }
    }
    mutating func retryLastStroke() {
        if canRetryPreviousStage, let checkpoint = firstStageCheckpoint {
            questions[cursor] = checkpoint.question
            latestShot = checkpoint.shot
            initialPoses = checkpoint.initialPoses; finalPoses = checkpoint.finalPoses
            viewBookmark = checkpoint.viewBookmark; shotBookmark = checkpoint.shotBookmark
            firstStageScore = nil; firstStageCheckpoint = nil
        }
        if let latestShot { draftInput = latestShot.input; showingResult = false }
    }
    mutating func resetInput() {
        draftInput = .init(); latestShot = nil; showingResult = false
        initialPoses = [:]; finalPoses = [:]; viewBookmark = nil; shotBookmark = nil
    }
    func continuation(prepared: ThreeBallQuestionPreparer.Prepared) -> Self {
        var next = Self(ownerKey: ownerKey, is3D: is3D, configuration: configuration, prepared: prepared)
        next.presentation = presentation
        next.logicalSessionID = logicalSessionID; next.completedQuestionOffset = totalProcessed
        next.previousScoreSum = previousScoreSum + firstAnswerScores.reduce(0,+)
        next.previousScoreCount = previousScoreCount + firstAnswerScores.count
        next.seenContentIDs.formUnion(seenContentIDs)
        return next
    }
    var isCompatible: Bool {
        version == Self.payloadVersion && questions.indices.contains(cursor)
            && Set(questions.map(\.id)).count == questions.count
            && Set(attempts.map { "\($0.questionID):\($0.stage)" }).count == attempts.count
            && attempts.allSatisfy { $0.score.isFinite && (0...100).contains($0.score) && (0..<6).contains($0.pocket) }
            && questions.allSatisfy { q in
                (q.identity?.isValid ?? true) && (0...1).contains(q.stage) && q.board.cue.isFinite && q.board.target.isFinite && q.second.isFinite
                    && (0..<6).contains(q.board.pocketIndex)
                    && (q.plannedPocket.map { (0..<6).contains($0) } ?? true)
                    && (q.stage == 0 ? q.third?.isFinite == true : q.third == nil)
            }
    }
    private static let magic = Data([0x33,0x42,0x30,0x31])
    func encodedPayload() throws -> Data {
        Self.magic + (try (JSONEncoder().encode(self) as NSData).compressed(using: .lzfse) as Data)
    }
    static func decodePayload(_ data: Data) throws -> Self {
        guard data.starts(with: magic) else { throw ThreeBallBank.Failure.invalid }
        return try JSONDecoder().decode(Self.self, from: (Data(data.dropFirst(4)) as NSData).decompressed(using: .lzfse) as Data)
    }
}
