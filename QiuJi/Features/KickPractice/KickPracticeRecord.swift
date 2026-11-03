import Foundation
import SceneKit

struct KickConfiguration: Codable, Equatable {
    var railCount: Int? = nil
    var freePractice = false
    var playsStroke = true
    // Optional storage preserves configurations saved before color hints existed.
    var railColorHints: Bool? = nil
    var showsRailColors: Bool {
        get { railColorHints ?? true }
        set { railColorHints = newValue }
    }
}

struct KickQuestion: Codable, Identifiable {
    let id: UUID
    let source: KickBankQuestion
    var railSegments: [Int]? = nil
    var board: TrainingBankBoard { source.board }
    var contentID: String { source.id }
    var ballNumber: Int { 1 }
    var isLastRailOptional: Bool { source.walls.count > 1 }
    var requirementText: String {
        isLastRailOptional ? "按顺序碰前\(source.walls.count - 1)库后碰目标球，末库可选" : "先碰指定库，再碰目标球"
    }
    var label: String { "\(source.walls.count)库" }
    /// World XZ, metres. Long walls have two independent main rail segments.
    var initialAimPoint: SCNVector3 {
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: 0)
        let first = railSegments?.first.flatMap { (0..<6).contains($0) ? $0 : nil }
        // Legacy records lack segment IDs; recover the first segment from their reference ray.
        let reference = AnalyticShotRollout.earliestCushionEvent(
            position: source.cue.vector, velocity: source.direction.vector, accel: SCNVector3Zero,
            geometry: geometry, horizon: 4, reach: 4 + BallPhysics.radius)?.cushionIndex
        let index = first ?? reference.flatMap { (0..<6).contains($0) ? $0 : nil }
            ?? (0..<6).first { KickWall.from(cushion: $0) == source.walls.first } ?? 0
        let rail = geometry.linearCushions[index]
        return (rail.start + rail.end) * 0.5 - rail.normal * BallPhysics.radius
    }
    var initialDirection: TrainingBankPoint {
        let delta = initialAimPoint - source.cue.vector
        return .init(delta * (1 / hypot(delta.x, delta.z)))
    }
    /// Geometric aiming guard, independent of stroke speed/spin. Reuses production CCD,
    /// including finite rails and jaws, and the combined radii for thin object-ball hits.
    func aimsDirectlyAtTarget(_ direction: SCNVector3) -> Bool {
        let length = hypot(direction.x, direction.z)
        guard length.isFinite, length > 0 else { return false }
        let aim = SCNVector3(direction.x / length, 0, direction.z / length)
        let cue = source.cue.vector, target = source.target.vector
        let horizon = cue.distanceXZ(to: target) + 2 * BallPhysics.radius
        guard let contact = CollisionDetector.ballBallCollisionTime(
            p1: cue, p2: target, v1: aim, v2: SCNVector3Zero,
            a1: SCNVector3Zero, a2: SCNVector3Zero,
            R: Double(BallPhysics.radius), maxTime: Double(horizon)) else { return false }
        let cushion = AnalyticShotRollout.earliestCushionEvent(
            position: cue, velocity: aim, accel: SCNVector3Zero,
            geometry: .chineseEightBallQiuJi(surfaceY: 0),
            horizon: contact, reach: contact + BallPhysics.radius)
        return cushion == nil || contact < cushion!.time
    }
    var separation: SeparationQuestion {
        .init(id: id, board: board, minimumCenterSpeed: 0, answer: .init(),
              answerDirection: source.direction,
              target: [], audit: .init())
    }
}

@dynamicMemberLookup
struct KickShot: Codable, Identifiable {
    var physical: SeparationShot
    let failure: KickJudgement.Failure?
    var id: UUID { physical.id }
    subscript<T>(dynamicMember key: KeyPath<SeparationShot, T>) -> T { physical[keyPath: key] }
    var playsStroke: Bool? { get { physical.playsStroke } set { physical.playsStroke = newValue } }
    init(question: KickQuestion, input: SeparationInput, prediction: ShotPrediction, surfaceY: Float) throws {
        physical = try .init(question: question.separation, input: input, prediction: prediction,
                             surfaceY: surfaceY, scoresTrajectory: false)
        failure = KickJudgement.failure(events: prediction.events, complete: prediction.hasFinalTableState, walls: question.source.walls, segments: question.railSegments)
    }
    func prediction() -> ShotPrediction { physical.prediction() }
    var trajectory: [SeparationTrajectory.Point] { (try? SeparationTrajectory.extractCue(prediction())) ?? [] }
    var resultText: String {
        if let failure { return failure.rawValue + " · 失败" }
        return "按指定库序解到目标球 · 成功"
    }
}

/// The ledger stores only the first accepted answer; latestShot is the independent retry/replay fact.
struct KickPracticeRecord: Codable, Identifiable {
    enum Status: String, Codable { case active, completed, ended }
    struct Attempt: Codable, Identifiable {
        let id, questionID: UUID
        let submittedAt: Date
        let failure: KickJudgement.Failure?
    }
    static let payloadVersion = 1
    var version = Self.payloadVersion
    var judgementVersion: Int? = 4
    let id: UUID
    var logicalSessionID: UUID
    var ownerKey: String
    let is3D: Bool
    let configuration: KickConfiguration
    let bankFingerprint: String
    let startedAt: Date
    var updatedAt: Date
    var status: Status = .active
    var activeSeconds: Double = 0
    var presentation: TrainingPresentation?
    var geometricReference: GeometricReferenceTool.Snapshot?
    var questions: [KickQuestion]
    var cursor = 0
    var attempts: [Attempt] = []
    var latestShot: KickShot?
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
    var current: KickQuestion? { questions.indices.contains(cursor) ? questions[cursor] : nil }
    var currentAttempt: Attempt? { attempts.first { $0.questionID == current?.id } }
    var currentConsumed: Bool { currentAttempt != nil }
    var consumed: [UUID: Date] { Dictionary(uniqueKeysWithValues: attempts.map { ($0.questionID, $0.submittedAt) }) }
    var totalProcessed: Int { completedQuestionOffset + attempts.count }
    var questionNumber: Int { completedQuestionOffset + cursor + 1 }
    var successCount: Int { previousSuccessCount + attempts.filter { $0.failure == nil }.count }
    var successRate: String { SceneTrainingMetrics.percentage(successCount, of: totalProcessed) }
    var finishMetrics: [(String, String)] { [("已练题数", "\(totalProcessed)"), ("成功率", successRate)] }
    var displayName: String { "解球练习 · " + (presentation?.summary ?? (is3D ? "3D" : "2D")) }
    var historyDetail: String {
        "已练\(attempts.count)题 · 成功率 " + SceneTrainingMetrics.percentage(attempts.filter { $0.failure == nil }.count, of: attempts.count)
    }
    init(ownerKey: String, is3D: Bool, configuration: KickConfiguration,
         prepared: KickQuestionPreparer.Prepared, now: Date = Date()) {
        id = UUID(); logicalSessionID = id; self.ownerKey = ownerKey; self.is3D = is3D
        self.configuration = configuration; bankFingerprint = prepared.fingerprint
        startedAt = now; updatedAt = now; questions = [prepared.question]
        seenContentIDs = [prepared.question.contentID]
        draftDirection = prepared.question.initialDirection
        presentation = .init(is3D: is3D)
        presentation?.observe(.init(is3D: is3D), questionID: prepared.question.id)
    }
    mutating func accept(_ shot: KickShot) {
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
    func continuation(prepared: KickQuestionPreparer.Prepared) -> Self {
        var next = Self(ownerKey: ownerKey, is3D: is3D, configuration: configuration, prepared: prepared)
        next.logicalSessionID = logicalSessionID; next.presentation = presentation
        next.completedQuestionOffset = totalProcessed; next.previousSuccessCount = successCount
        next.seenContentIDs.formUnion(seenContentIDs)
        return next
    }
    var canResumeCurrentTraining: Bool {
        isCompatible && judgementVersion == 4 && bankFingerprint == KickBankStore.fingerprint
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
    private static let magic = Data([0x4b, 0x50, 0x30, 0x31])
    func encodedPayload() throws -> Data {
        Self.magic + (try (JSONEncoder().encode(self) as NSData).compressed(using: .lzfse) as Data)
    }
    static func decodePayload(_ data: Data) throws -> Self {
        guard data.starts(with: magic) else { throw KickBankStore.Failure.invalid("记录版本") }
        return try JSONDecoder().decode(Self.self, from: (Data(data.dropFirst(4)) as NSData).decompressed(using: .lzfse) as Data)
    }
}
