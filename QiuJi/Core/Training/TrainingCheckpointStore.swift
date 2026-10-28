import Foundation
import CryptoKit

/// Owner-scoped, per-session atomic checkpoints. Two open sessions never overwrite
/// one another; migration/resume chooses the newest compatible active checkpoint.
final class TrainingCheckpointStore<Value: Codable> {
    private struct Envelope: Codable {
        var version = 1
        let owner: String
        let project: TrainingProject
        let id: UUID
        let updatedAt: Date
        let value: Value
    }
    private let owner: String
    private let project: TrainingProject
    private let directory: URL
    private static var testRoot: URL { FileManager.default.temporaryDirectory.appendingPathComponent("training-checkpoints-test-\(ProcessInfo.processInfo.processIdentifier)") }
    init(project: TrainingProject, owner: String, root: URL? = nil) {
        self.owner = owner; self.project = project
        let hash = SHA256.hash(data: Data(owner.utf8)).map { String(format: "%02x", $0) }.joined()
        var base = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QiuJi/TrainingCheckpoints")
        #if DEBUG
        if root == nil, ProcessInfo.processInfo.arguments.contains("-v50.inMemoryStore") { base = Self.testRoot }
        #endif
        directory = base.appendingPathComponent(hash).appendingPathComponent(project.rawValue)
    }
    func save(_ value: Value, id: UUID, now: Date = Date()) throws {
        let data = try JSONEncoder().encode(Envelope(owner: owner, project: project, id: id, updatedAt: now, value: value))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(id.uuidString + ".json"), options: .atomic)
    }
    func latest(where compatible: (Value) -> Bool) throws -> Value? {
        guard FileManager.default.fileExists(atPath: directory.path) else { return nil }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let candidates = try files.filter { $0.pathExtension == "json" }.map { file in
            let value = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: file))
            guard value.version == 1, value.owner == owner, value.project == project,
                  file.deletingPathExtension().lastPathComponent == value.id.uuidString else { throw TrainingQuotaLedger.Failure.unreadable }
            return value
        }
        return candidates.sorted { $0.updatedAt > $1.updatedAt }.first { compatible($0.value) }?.value
    }
}

struct SavedTrainingAnswer: Codable {
    let id: UUID
    let owner: String
    let date: Date
    let actual, answer, errorMM: Double
    let pocket, quiz: String
    let metadata: String?
    let sessionID: UUID?
    var trainingMetadata: SceneTrainingMetadata? {
        metadata?.data(using: .utf8).flatMap { try? JSONDecoder().decode(SceneTrainingMetadata.self, from: $0) }
    }
    var question: AngleQuestion? {
        guard let m = trainingMetadata, m.cue.count == 2, m.target.count == 2,
              AngleCalculator.pockets.indices.contains(m.pocketIndex) else { return nil }
        return .init(targetBall: .init(x: m.target[0], y: m.target[1]), cueBall: .init(x: m.cue[0], y: m.cue[1]),
            pocket: AngleCalculator.pockets[m.pocketIndex], actualAngle: m.angle,
            pocketType: m.pocketIndex < 4 ? .corner : .side, pocketIndex: m.pocketIndex)
    }
    @MainActor init(_ result: AngleTestResult) {
        id = result.id; owner = result.ownerKey; date = result.date
        actual = result.actualAngle; answer = result.userAngle; errorMM = result.errorMM
        pocket = result.pocketType; quiz = result.quizType; metadata = result.trainingMetadataJSON; sessionID = result.sessionId
    }
    @MainActor var result: AngleTestResult {
        let result = AngleTestResult(actualAngle: actual, userAngle: answer, pocketType: pocket,
            quizType: quiz, errorMM: errorMM, sessionId: sessionID, ownerKey: owner)
        result.id = id; result.date = date; result.trainingMetadataJSON = metadata
        return result
    }
}

struct SceneTrainingCheckpoint: Codable {
    var run: SceneTrainingRun
    var presentation: TrainingPresentation
    var targetNumber: Int
    var input = ""
    var inputPhase: String?
    var hintVisible: Bool?
    var direction: TrainingBankPoint?
    var finished = false
    var lastAnswer: SavedTrainingAnswer?
    var pending: [SavedTrainingAnswer] = []
    var answers: [SavedTrainingAnswer] = []
}

@MainActor
final class SceneTrainingPersistence {
    let owner: String
    private let store: TrainingCheckpointStore<SceneTrainingCheckpoint>
    private(set) var current: SceneTrainingCheckpoint?
    init(project: TrainingProject, owner: String, root: URL? = nil) throws {
        self.owner = owner; store = .init(project: project, owner: owner, root: root)
        current = try store.latest { !$0.finished || !$0.pending.isEmpty }
    }
    func save(run: SceneTrainingRun, presentation: TrainingPresentation, targetNumber: Int,
              input: String = "", direction: TrainingBankPoint? = nil, finished: Bool = false,
              inputPhase: String? = nil, hintVisible: Bool? = nil,
              accepting answer: SavedTrainingAnswer? = nil) throws {
        guard owner == CurrentOwnerContext.shared.ownerKey else { throw TrainingQuotaLedger.Failure.unreadable }
        let previous = current?.run.id == run.id ? current : nil
        var next = SceneTrainingCheckpoint(run: run, presentation: presentation, targetNumber: targetNumber,
            input: input, direction: direction, finished: finished,
            lastAnswer: previous?.lastAnswer, pending: previous?.pending ?? [], answers: previous?.answers ?? [])
        next.inputPhase = inputPhase ?? previous?.inputPhase
        next.hintVisible = hintVisible ?? previous?.hintVisible
        if let answer, !next.answers.contains(where: { $0.id == answer.id }) {
            next.lastAnswer = answer; next.answers.append(answer); next.pending.append(answer)
        }
        try store.save(next, id: run.id); current = next
    }
    func acknowledge(_ id: UUID) throws {
        guard var next = current else { return }
        next.pending.removeAll { $0.id == id }
        try store.save(next, id: next.run.id); current = next
    }
}
