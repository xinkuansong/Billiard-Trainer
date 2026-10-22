import Foundation
import SceneKit

/// Versioned, immutable physical recording. Presentation tails are rebuilt from the capture facts.
struct SeparationShot: Codable, Identifiable {
    struct Vector: Codable {
        let x: Float, y: Float, z: Float
        init(_ v: SCNVector3) { x = v.x; y = v.y; z = v.z }
        var value: SCNVector3 { .init(x, y, z) }
    }
    struct Frame: Codable {
        let time: Float
        let position: Vector
        let velocity: Vector
        let omega: Vector
        let state: String
        init(_ f: BallFrame) {
            time = f.time; position = .init(f.position); velocity = .init(f.velocity)
            omega = .init(.init(f.angularVelocity.x, f.angularVelocity.y, f.angularVelocity.z))
            state = f.state.rawValue
        }
        var value: BallFrame {
            .init(time: time, position: position.value, velocity: velocity.value,
                  angularVelocity: .init(omega.x, omega.y, omega.z, 0), state: BallMotionState(rawValue: state) ?? .stationary)
        }
    }
    struct Capture: Codable {
        let name: String, pocket: String
        let frame: Frame
    }
    struct Sound: Codable {
        let time: Float, speed: Float
        let ball: String, other: String, surface: String
    }
    let id: UUID
    let questionID: UUID
    let submittedAt: Date
    let input: SeparationInput
    let direction: TrainingBankPoint
    let trajectory: [SeparationTrajectory.Point]
    let frames: [String: [Frame]]
    let captures: [Capture]
    let sounds: [Sound]
    let events: [TrainingProofEvent]
    let finalPositions: [String: Vector]
    let pocketedBalls: [String]
    let duration: Float
    let surfaceY: Float
    let specifiedPocket: Bool
    var score: SeparationTrajectoryScore?
    /// Nil preserves animated results from older records.
    var playsStroke: Bool?
    var isTrajectoryOnly: Bool { playsStroke == false }

    init(question: SeparationQuestion, input: SeparationInput, prediction: ShotPrediction,
         surfaceY: Float, now: Date = Date()) throws {
        guard prediction.hasFinalTableState, let recorder = prediction.recorder,
              let direction = prediction.strikeDirection else { throw SeparationQuestionGenerator.Failure.incomplete }
        id = UUID(); questionID = question.id; submittedAt = now; self.input = input
        self.direction = .init(direction); self.surfaceY = surfaceY
        trajectory = try SeparationTrajectory.extract(prediction)
        score = try SeparationTrajectoryScore.evaluate(target: question.target, actual: trajectory)
        frames = recorder.framesByBallName.mapValues { $0.map(Frame.init) }
        captures = recorder.pocketEntries.map {
            .init(name: $0.ball.name, pocket: $0.pocketID,
                  frame: .init(.init(time: $0.time, position: $0.ball.position, velocity: $0.ball.velocity,
                      angularVelocity: .init($0.ball.angularVelocity.x, $0.ball.angularVelocity.y, $0.ball.angularVelocity.z, 0),
                      state: $0.ball.state)))
        }
        sounds = recorder.contactSounds.map { .init(time: $0.time, speed: $0.approachSpeed,
            ball: $0.ball, other: $0.other, surface: $0.surface.rawValue) }
        events = prediction.events.map(TrainingProofEvent.init)
        finalPositions = prediction.finalPositions.mapValues(Vector.init)
        pocketedBalls = prediction.pocketedBalls; duration = prediction.duration
        specifiedPocket = SeparationQuestionGenerator.potsSpecifiedPocket(prediction, pocket: question.board.pocketIndex)
    }
    /// Derived from the durable raw recording, including legacy shots without a stored object path.
    var objectTrajectory: [SeparationTrajectory.Point] {
        (try? SeparationTrajectory.extractObject(prediction())) ?? []
    }
    /// No solver or new simulation on replay or process restoration.
    func prediction() -> ShotPrediction {
        let recorder = TrajectoryRecorder()
        for (name, list) in frames { for frame in list { recorder.recordFrame(ballName: name, frame: frame.value) } }
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY)
        for capture in captures {
            let f = capture.frame
            recorder.recordPocketEntry(ball: .init(position: f.position.value, velocity: f.velocity.value,
                angularVelocity: f.omega.value, state: BallMotionState(rawValue: f.state) ?? .rolling, name: capture.name),
                pocketID: capture.pocket, time: f.time, source: .event, geometry: geometry)
        }
        recorder.hasContactSoundFacts = true; recorder.cueStrikeSpeed = input.velocity
        for sound in sounds {
            if let surface = ContactSoundEvent.Surface(rawValue: sound.surface) {
                recorder.recordContactSound(.init(time: sound.time, ball: sound.ball, other: sound.other,
                                                  surface: surface, approachSpeed: sound.speed))
            }
        }
        var result = ShotPrediction()
        result.termination = .settled; result.aimDirection = direction.vector; result.strikeDirection = direction.vector
        result.recorder = recorder; result.duration = duration; result.pocketedBalls = pocketedBalls
        result.finalPositions = finalPositions.mapValues(\.value)
        result.cuePocketed = pocketedBalls.contains(ShotInput.cueBallName)
        result.objectPocketed = pocketedBalls.contains(ShotInput.targetBallName)
        result.events = events.compactMap { e in
            let kind: ShotEvent.Kind
            switch e.kind {
            case "ballBall": guard let other = e.otherBall else { return nil }; kind = .ballBall(ballA: e.ball, ballB: other)
            case "ballCushion": kind = .ballCushion(ball: e.ball)
            case "pocket": guard let id = e.pocketID else { return nil }; kind = .pocket(ball: e.ball, pocketId: id)
            default: return nil
            }
            return .init(time: e.time, kind: kind, cushionIndex: e.cushionIndex)
        }
        return result
    }
    var scoreText: String {
        if let score { return "本杆得分 \(score.formatted)分" }
        return trajectory.isEmpty ? "未碰到目标球 · 无法评分" : "未评分"
    }
    var resultText: String {
        guard !trajectory.isEmpty else { return scoreText }
        if pocketedBalls.contains(ShotInput.cueBallName) { return scoreText + " · 母球落袋" }
        return specifiedPocket ? scoreText : scoreText + " · 目标球未进指定袋"
    }
    var outcomeText: String {
        if trajectory.isEmpty { return "未碰到目标球，没有分离后轨迹" }
        if pocketedBalls.contains(ShotInput.cueBallName) { return "母球落袋 · 可重打比较轨迹" }
        return specifiedPocket ? "目标球进指定袋 · 对照两条完整轨迹" : "目标球未进指定袋 · 可调整打点和力度重打"
    }
}

struct SeparationPracticeRecord: Codable, Identifiable {
    enum Status: String, Codable { case active, completed, ended }
    static let payloadVersion = 1
    var version = Self.payloadVersion
    var physicsVersion = SeparationQuestionGenerator.version
    let id: UUID
    var ownerKey: String
    let is3D: Bool
    let configuration: SceneTrainingConfiguration
    let bankFingerprint: String
    let startedAt: Date
    var updatedAt: Date
    var status: Status = .active
    // Optional for compatibility with recordings created before segmented free practice.
    var completedQuestionOffset: Int?
    var completedScoreSum: Double?
    var completedScoreCount: Int?
    var scoredAttempts: [SeparationTrajectoryScore] { attempts.compactMap(\.score) }
    var segmentAverageScore: Double? {
        let scores = scoredAttempts
        return scores.isEmpty ? nil : scores.reduce(0) { $0 + $1.value } / Double(scores.count)
    }
    var totalScoredCount: Int { (completedScoreCount ?? 0) + scoredAttempts.count }
    var totalScoreSum: Double { (completedScoreSum ?? 0) + scoredAttempts.reduce(0) { $0 + $1.value } }
    var averageScore: Double? { totalScoredCount == 0 ? nil : totalScoreSum / Double(totalScoredCount) }
    var finishMetrics: [(String, String)] {
        var result = [("已练题数", "\(totalAttemptCount)"),
                      ("首杆均分", averageScore.map { String(format: "%.1f", $0) } ?? "—")]
        if totalScoredCount != totalAttemptCount { result.append(("已评分题数", "\(totalScoredCount)")) }
        return result
    }
    var historyDetail: String {
        let score = segmentAverageScore.map { "首杆均分 " + String(format: "%.1f", $0) } ?? "未评分"
        let coverage = scoredAttempts.count == attempts.count ? "" : " · 已评分 \(scoredAttempts.count)题"
        return "已练 \(attempts.count) 题 · " + score + coverage
    }
    var totalAttemptCount: Int { (completedQuestionOffset ?? 0) + attempts.count }
    var questionNumber: Int { (completedQuestionOffset ?? 0) + cursor + 1 }
    var activeSeconds: Double = 0
    var questions: [SeparationQuestion]
    var cursor = 0
    var attempts: [SeparationShot] = []
    var latestShot: SeparationShot?
    /// Only scores are needed for repeat-practice statistics; retain no duplicate
    /// physical recordings. Optional so older payloads remain readable.
    struct QuestionScores: Codable {
        let questionID: UUID
        var values: [UUID: Double]
    }
    var currentQuestionScores: QuestionScores?
    private var currentQuestionScoreValues: [UUID: Double] {
        if let stored = currentQuestionScores, stored.questionID == current?.id { return stored.values }
        // Legacy recordings kept the first and latest shots only. Use those known
        // facts without inventing scores for overwritten intermediate retries.
        var values: [UUID: Double] = [:]
        for shot in [currentAttempt, latestShot].compactMap({ $0 }) where shot.questionID == current?.id {
            if let score = shot.score, values[shot.id] == nil { values[shot.id] = score.value }
        }
        return values
    }
    func currentQuestionAverage(excluding shotID: UUID? = nil) -> Double? {
        let values = currentQuestionScoreValues.filter { $0.key != shotID }.values
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
    var draftInput = SeparationInput()
    /// A suspended reveal needs a fresh explicit strike, even if already accounted.
    var showingResult = false
    var initialPoses: [String: [Float]] = [:]
    var finalPoses: [String: [Float]] = [:]
    var viewBookmark: CameraRig.TrainingBookmark?
    var shotBookmark: CameraRig.TrainingBookmark?
    var current: SeparationQuestion? { questions.indices.contains(cursor) ? questions[cursor] : nil }
    var currentAttempt: SeparationShot? { attempts.first { $0.questionID == current?.id } }
    var displayName: String { is3D ? "3D分离角练习" : "2D分离角练习" }
    init(ownerKey: String, is3D: Bool, configuration: SceneTrainingConfiguration,
         prepared: SeparationQuestionGenerator.Prepared, now: Date = Date()) {
        id = UUID(); self.ownerKey = ownerKey; self.is3D = is3D; self.configuration = configuration
        bankFingerprint = prepared.fingerprint; startedAt = now; updatedAt = now; questions = [prepared.question]
    }
    mutating func accept(_ shot: SeparationShot) {
        guard shot.questionID == current?.id else { return }
        var values = currentQuestionScoreValues
        if let score = shot.score, values[shot.id] == nil { values[shot.id] = score.value }
        currentQuestionScores = .init(questionID: shot.questionID, values: values)
        if currentAttempt == nil { attempts.append(shot) }
        latestShot = shot; draftInput = shot.input; updatedAt = Date()
    }
    /// Free practice remains continuous; each durable segment has its own history row.
    func continuation(prepared: SeparationQuestionGenerator.Prepared) -> Self {
        var next = Self(ownerKey: ownerKey, is3D: is3D, configuration: configuration, prepared: prepared)
        next.completedQuestionOffset = totalAttemptCount
        next.completedScoreSum = totalScoreSum; next.completedScoreCount = totalScoredCount
        return next
    }
    var isCompatible: Bool { version == Self.payloadVersion && physicsVersion == SeparationQuestionGenerator.version }

    // Lossless payload compression preserves the full physical recording while staying
    // within the existing session API body budget for ordinary rounds.
    private static let payloadMagic = Data([0x53, 0x50, 0x30, 0x31]) // SP01 / LZFSE
    func encodedPayload() throws -> Data {
        let raw = try JSONEncoder().encode(self)
        return Self.payloadMagic + (try (raw as NSData).compressed(using: .lzfse) as Data)
    }
    static func decodePayload(_ payload: Data) throws -> Self {
        let raw: Data
        if payload.starts(with: payloadMagic) {
            raw = try (Data(payload.dropFirst(payloadMagic.count)) as NSData).decompressed(using: .lzfse) as Data
        } else { raw = payload }
        return try JSONDecoder().decode(Self.self, from: raw)
    }
}
