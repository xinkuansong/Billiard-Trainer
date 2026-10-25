import Foundation
import SceneKit

struct TwoBallPracticeRecord: Codable, Identifiable {
    enum Status: String, Codable { case active, completed, ended }
    struct Attempt: Codable, Identifiable {
        let id, questionID: UUID
        let comboIndex: Int
        let submittedAt: Date
        let skipped: Bool
        let score: Double?
        let difficulty: Double?
        let failure: String?
        var comfortScore: Double? = nil
    }
    static let payloadVersion = 1
    var version = Self.payloadVersion
    var physicsVersion = TwoBallQuestionPreparer.version
    // Optional for decoding historical payloads; old sessions remain readable in history.
    var trainingBankPolicyVersion: String? = TwoBallBankStore.policyVersion
    var canResumeCurrentTraining: Bool {
        trainingBankPolicyVersion == TwoBallBankStore.policyVersion
            && questions.allSatisfy { question in
                question.routes.allSatisfy { $0.recommendation.comfort?.isQualified == true
                    && $0.source.executionDifficulty?.version == TwoBallExecutionDifficulty.version }
                && zip(question.routes, question.routes.dropFirst()).allSatisfy {
                    ($0.source.executionDifficulty?.effort ?? .infinity) <= ($1.source.executionDifficulty?.effort ?? -.infinity)
                }
            }
    }
    let id: UUID
    var logicalSessionID: UUID
    var ownerKey: String
    let is3D: Bool
    let configuration: SceneTrainingConfiguration
    let mode: TwoBallMode
    let bankFingerprint: String
    let startedAt: Date
    var updatedAt: Date
    var status: Status = .active
    var activeSeconds: Double = 0
    var questions: [TwoBallQuestion]
    var cursor = 0
    var attempts: [Attempt] = []
    var latestShot: TwoBallShot?
    var draftInput = SeparationInput()
    var retryOverride = false
    var showingResult = false
    var initialPoses: [String: [Float]] = [:]
    var finalPoses: [String: [Float]] = [:]
    var viewBookmark: CameraRig.TrainingBookmark?
    var shotBookmark: CameraRig.TrainingBookmark?
    var current: TwoBallQuestion? { questions.indices.contains(cursor) ? questions[cursor] : nil }
    var currentAttempt: Attempt? {
        attempts.first { $0.questionID == current?.id && $0.comboIndex == current?.route.source.comboIndex }
    }
    var consumed: [UUID: Date] = [:]
    var currentConsumed: Bool { current.map { consumed[$0.id] != nil } ?? false }
    var retryCount = 0
    var currentScoreSum: Double = 0
    var currentScoreCount = 0
    var currentComfortSum: Double?
    var currentComfortCount: Int?
    var previousComfortSum: Double?
    var previousComfortCount: Int?
    var completedQuestionOffset = 0
    var previousPracticed = 0
    var previousScoreSum: Double = 0
    var previousScoreCount = 0
    var previousValid = 0
    var previousDifficultySum: Double = 0
    var previousSkipped = 0
    var previousSkippedQuestions = 0
    var previousProcessedRoutes = 0
    var seenContentIDs: Set<String> = []
    var questionNumber: Int { completedQuestionOffset + cursor + 1 }
    var hasNextRoute: Bool { mode == .trajectory && current.map { $0.routeIndex+1 < $0.routes.count } == true }
    var isUnchanged: Bool { draftInput == SeparationInput() && !retryOverride }
    var shouldSkip: Bool { mode == .trajectory && current.map { $0.routeIndex > 0 } == true && isUnchanged }
    var totalAttemptCount: Int { previousPracticed + Set(attempts.filter { !$0.skipped }.map(\.questionID)).count }
    var totalProcessed: Int { completedQuestionOffset + consumed.count }
    var skippedRoutes: Int { previousSkipped + attempts.filter(\.skipped).count }
    var skippedQuestions: Int {
        previousSkippedQuestions + questions.filter { question in
            let rows = attempts.filter { $0.questionID == question.id }
            return rows.count == question.routes.count && rows.allSatisfy(\.skipped)
        }.count
    }
    var processedRoutes: Int { previousProcessedRoutes + attempts.count }
    var scoredQuestionValues: [Double] {
        Dictionary(grouping: attempts.filter { !$0.skipped }, by: \.questionID).values.compactMap { rows in
            let scores = rows.compactMap(\.score)
            return scores.isEmpty ? nil : scores.reduce(0,+)/Double(scores.count)
        }
    }
    var totalScoredCount: Int { previousScoreCount + scoredQuestionValues.count }
    var totalScoreSum: Double { previousScoreSum + scoredQuestionValues.reduce(0,+) }
    var comfortValues: [Double] { attempts.compactMap(\.comfortScore) }
    var comfortCount: Int { (previousComfortCount ?? 0) + comfortValues.count }
    var comfortSum: Double { (previousComfortSum ?? 0) + comfortValues.reduce(0,+) }
    var averageScore: Double? {
        if mode == .free { return comfortCount > 0 ? comfortSum/Double(comfortCount) : nil }
        return totalScoredCount > 0 ? totalScoreSum/Double(totalScoredCount) : nil
    }
    var validCount: Int { previousValid + attempts.compactMap(\.difficulty).count }
    var difficultySum: Double { previousDifficultySum + attempts.compactMap(\.difficulty).reduce(0,+) }
    var averageDifficulty: Double? { validCount > 0 ? difficultySum/Double(validCount) : nil }
    var validRate: String { SceneTrainingMetrics.percentage(validCount, of: totalAttemptCount) }
    func currentQuestionAverage(excluding shotID: UUID? = nil) -> Double? {
        let scores = attempts.filter { $0.questionID == current?.id && $0.id != shotID }.compactMap(\.score)
        return scores.isEmpty ? nil : scores.reduce(0,+)/Double(scores.count)
    }
    func currentRouteAverage(excluding shotID: UUID? = nil) -> Double? {
        if mode == .free {
            let excluded = latestShot.flatMap { $0.id == shotID ? $0.freeScore : nil }
            let count = (currentComfortCount ?? 0) - (excluded == nil ? 0 : 1)
            return count > 0 ? ((currentComfortSum ?? 0) - (excluded ?? 0)) / Double(count) : nil
        }
        let excluded = latestShot.flatMap { $0.id == shotID ? $0.trajectoryScore : nil }
        let count = currentScoreCount - (excluded == nil ? 0 : 1)
        return count > 0 ? (currentScoreSum - (excluded ?? 0)) / Double(count) : nil
    }
    var finishMetrics: [(String,String)] {
        if mode == .trajectory {
            return [("已练题数", "\(totalAttemptCount)"), ("首答均分", averageScore.map { String(format: "%.1f", $0) } ?? "—"),
                    ("路线练/总", "\(processedRoutes-skippedRoutes)/\(processedRoutes)"),
                    ("跳过线/题", "\(skippedRoutes)/\(skippedQuestions)")]
        }
        if comfortCount > 0 || totalAttemptCount == 0 {
            return [("已练题数", "\(totalAttemptCount)"), ("首答均分", averageScore.map { String(format: "%.1f", $0) } ?? "—"),
                    ("评分题数", "\(comfortCount)")]
        }
        return [("已练题数", "\(totalAttemptCount)"), ("首杆有效率", validRate),
                ("首杆均难度", averageDifficulty.map { String(format: "%.3f", $0) } ?? "—"), ("有效样本", "\(validCount)")]
    }
    var displayName: String { "\(is3D ? "3D" : "2D")两球走位" }
    var historyDetail: String {
        if mode == .trajectory {
            return "轨迹走位 · 已练\(Set(attempts.filter { !$0.skipped }.map(\.questionID)).count)题 · 首答均分 "
                + (scoredQuestionValues.isEmpty ? "—" : String(format:"%.1f", scoredQuestionValues.reduce(0,+)/Double(scoredQuestionValues.count)))
                + " · 跳过\(attempts.filter(\.skipped).count)条"
        }
        if !comfortValues.isEmpty {
            return "自由走位 · 已评分\(comfortValues.count)题 · 首答均分 "
                + String(format: "%.1f", comfortValues.reduce(0,+)/Double(comfortValues.count))
        }
        let values = attempts.compactMap(\.difficulty)
        return "自由走位 · 有效\(values.count)/\(attempts.count)题 · 旧版难度 "
            + (values.isEmpty ? "—" : String(format:"%.3f",values.reduce(0,+)/Double(values.count))) + "（越低越好）"
    }
    init(ownerKey: String, is3D: Bool, configuration: SceneTrainingConfiguration, mode: TwoBallMode,
         prepared: TwoBallQuestionPreparer.Prepared, now: Date = Date()) {
        id = UUID(); logicalSessionID = id; self.ownerKey = ownerKey; self.is3D = is3D
        self.configuration = configuration; self.mode = mode; bankFingerprint = prepared.fingerprint
        startedAt = now; updatedAt = now; questions = [prepared.question]; seenContentIDs = [prepared.question.contentID]
    }
    mutating func accept(_ shot: TwoBallShot) {
        guard shot.questionID == current?.id, shot.comboIndex == current?.route.source.comboIndex else { return }
        guard latestShot?.id != shot.id else { return }
        let hasFirstScore = mode == .trajectory ? currentAttempt != nil : attempts.contains {
            $0.questionID == shot.questionID && $0.comfortScore != nil
        }
        if !hasFirstScore {
            attempts.append(.init(id: shot.id, questionID: shot.questionID, comboIndex: shot.comboIndex,
                submittedAt: shot.submittedAt, skipped: false, score: mode == .trajectory ? shot.trajectoryScore : nil,
                difficulty: mode == .free ? shot.difficulty?.value : nil, failure: shot.failure,
                comfortScore: mode == .free ? shot.freeScore : nil))
        }
        consumed[shot.questionID] = consumed[shot.questionID] ?? shot.submittedAt
        retryCount += 1; currentScoreSum += shot.trajectoryScore; currentScoreCount += 1
        if mode == .free, let value = shot.freeScore {
            currentComfortSum = (currentComfortSum ?? 0) + value
            currentComfortCount = (currentComfortCount ?? 0) + 1
        }
        latestShot = shot; draftInput = shot.input; updatedAt = Date()
    }
    mutating func skip(now: Date = Date()) {
        guard let q = current, currentAttempt == nil, shouldSkip else { return }
        attempts.append(.init(id: UUID(), questionID: q.id, comboIndex: q.route.source.comboIndex,
            submittedAt: now, skipped: true, score: nil, difficulty: nil, failure: nil))
        consumed[q.id] = consumed[q.id] ?? now; showingResult = true; updatedAt = now
    }
    mutating func advanceRoute() {
        guard hasNextRoute, currentAttempt != nil else { return }
        questions[cursor].routeIndex += 1
        resetInput()
    }
    mutating func resetInput() {
        draftInput = .init(); latestShot = nil; retryOverride = false; showingResult = false
        retryCount = 0; currentScoreSum = 0; currentScoreCount = 0
        currentComfortSum = nil; currentComfortCount = nil
        initialPoses = [:]; finalPoses = [:]; viewBookmark = nil; shotBookmark = nil
    }
    func continuation(prepared: TwoBallQuestionPreparer.Prepared) -> Self {
        var next = Self(ownerKey: ownerKey, is3D: is3D, configuration: configuration, mode: mode, prepared: prepared)
        next.logicalSessionID = logicalSessionID; next.completedQuestionOffset = totalProcessed
        next.previousPracticed = totalAttemptCount; next.previousScoreCount = totalScoredCount
        next.previousScoreSum = totalScoreSum; next.previousValid = validCount; next.previousDifficultySum = difficultySum
        next.previousComfortSum = comfortSum; next.previousComfortCount = comfortCount
        next.previousSkipped = skippedRoutes; next.previousProcessedRoutes = processedRoutes
        next.previousSkippedQuestions = skippedQuestions
        next.seenContentIDs.formUnion(seenContentIDs)
        return next
    }
    var isCompatible: Bool {
        version == Self.payloadVersion && physicsVersion == TwoBallQuestionPreparer.version
            && questions.indices.contains(cursor) && Set(questions.map(\.id)).count == questions.count
            && questions.allSatisfy { question in
                !question.routes.isEmpty && question.routes.count <= 5 && question.routes.indices.contains(question.routeIndex)
                && question.second.x.isFinite && question.second.z.isFinite
                && Set(question.routes.map { $0.source.comboIndex }).count == question.routes.count
                && question.routes.allSatisfy { route in
                    let source = route.source, line = source.trajectory2mm
                    return source.input.isValid && source.strikeDirection.count == 2 && source.cueStop.count == 2
                        && source.strikeDirection.allSatisfy(\.isFinite) && source.cueStop.allSatisfy(\.isFinite)
                        && !line.points.isEmpty && line.points.allSatisfy { $0.count == 3 && $0.allSatisfy(\.isFinite) }
                        && line.coordinateUnit == "meter-XZ" && line.timeOrigin == "firstTargetContact"
                        && route.recommendation.comboIndex == source.comboIndex && (0..<6).contains(route.recommendation.pocket)
                }
            }
    }
    private static let magic = Data([0x54,0x42,0x30,0x31])
    func encodedPayload() throws -> Data {
        Self.magic + (try (JSONEncoder().encode(self) as NSData).compressed(using: .lzfse) as Data)
    }
    static func decodePayload(_ data: Data) throws -> Self {
        guard data.starts(with: magic) else { throw TwoBallBankStore.Failure.invalid("记录版本") }
        return try JSONDecoder().decode(Self.self, from: (Data(data.dropFirst(4)) as NSData).decompressed(using: .lzfse) as Data)
    }
}
