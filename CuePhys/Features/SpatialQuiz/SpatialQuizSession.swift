import Foundation
import Combine

/// Transactional session logic shared by both modes. Scene playback is a consumer,
/// never an alternate path for scoring, demo unlocking or quota consumption.
@MainActor
final class SpatialQuizSession: ObservableObject {
    enum Activity: Equatable { case idle, calculating, unconfirmed, saveFailed, playing, replaying, demonstrating }
    @Published private(set) var record: SpatialQuizRecord?
    @Published private(set) var activity: Activity = .idle
    @Published private(set) var message: String?
    let mode: SpatialQuizMode
    let limiter: AngleUsageLimiter
    let repository: any SpatialQuizRepository
    private var pendingResult: SpatialQuizShot?
    private var returnPhase: SpatialQuizRecord.Phase?
    var onMutation: (() -> Void)?
    var canAdjust: Bool { activity == .idle && record?.phase == .aiming && ownsRecord &&
        (record?.configuration.freePractice != true || limiter.isPremium || record?.currentFirst != nil) }
    var canDemonstrate: Bool { activity == .idle && record?.phase == .result && record?.demonstrationProgress.unlocked == true && ownsRecord }
    var ownsRecord: Bool { record?.ownerKey == repository.ownerKey }
    init(mode: SpatialQuizMode, repository: any SpatialQuizRepository, limiter: AngleUsageLimiter) {
        self.mode = mode; self.repository = repository; self.limiter = limiter
    }
    private func commit(_ next: SpatialQuizRecord) throws {
        try repository.save(next); record = next; onMutation?()
    }
    func restore(bank: SpatialQuizBank.Bank) throws {
        let value = try repository.resumable(mode: mode) {
            $0.isCurrentCompatible && $0.bankFingerprint == bank.fingerprint
        }
        if repository.unreadableCount > 0 {
            message = "有\(repository.unreadableCount)条记录暂时无法读取，原记录已保留；可继续其他练习"
        } else if value == nil && repository.incompatibleCount > 0 {
            message = "题库或规则已更新，原成绩已保留，请开始新的练习"
        }
        guard let value else { return }
        record = value
        guard reconcile() else { return }
        // A frozen attempt resumes under its original ID/input; saved results need no re-solve.
        activity = value.pending == nil ? .idle : .unconfirmed
    }
    func start(configuration: SpatialQuizConfiguration, bank: SpatialQuizBank.Bank) throws {
        guard activity == .idle || activity == .unconfirmed else { return }
        guard bank.manifest.mode == mode, limiter.isPremium || (!configuration.freePractice && !limiter.isLimitReached) else {
            throw SpatialQuizBank.Failure.invalid("今日题数已用完，或当前训练需要Pro")
        }
        let available = bank.questions.filter { configuration.filter.accepts($0) }.count
        let count = configuration.freePractice ? min(10,available) : 15
        let selected = try bank.draw(count: count, filter: configuration.filter)
        let next = SpatialQuizRecord(owner: repository.ownerKey, mode: mode, configuration: configuration, bank: bank, questions: selected)
        guard limiter.reserve(questionID: next.current.id, replacing: record?.current.id) else {
            throw SpatialQuizBank.Failure.invalid(limiter.quotaError ?? "今日题数已用完")
        }
        do {
            if var previous = record, previous.status == .active {
                previous.status = .ended; previous.pending = nil
                previous.phase = previous.latestShot == nil ? .aiming : .result
                try repository.saveAtomically([previous,next]); record = next; onMutation?()
            } else { try commit(next) }
        } catch { limiter.release(questionID: next.current.id); throw error }
        pendingResult = nil; activity = .idle; message = nil
    }
    func savePresentation(bookmark:CameraRig.TrainingBookmark?,elapsed:Double) throws {
        guard ownsRecord,elapsed.isFinite,elapsed>=0,var next=record else { return }
        next.bookmark=bookmark;next.activeSeconds += elapsed;next.updatedAt=Date();try commit(next)
    }
    func reviewLastQuestion() throws {
        guard ownsRecord,activity == .idle,var next=record,next.phase == .summary,next.latestShot != nil else { return }
        next.phase = .result;try commit(next)
    }
    func updateDraft(_ input: SpatialQuizPhysics.Input) throws {
        guard canAdjust, input.valid, var next = record else { return }
        next.draft = input; next.updatedAt = Date(); try commit(next)
    }
    /// Persist before beginning async physics. Resuming an incomplete calculation reuses this value.
    func freeze(now: Date = Date()) throws -> SpatialQuizRecord.Pending? {
        guard ownsRecord, var next = record,
              canAdjust || activity == .unconfirmed else { return nil }
        guard !next.configuration.freePractice || limiter.isPremium || next.currentFirst != nil || next.pending != nil else {
            throw SpatialQuizBank.Failure.invalid("不限题练习需要Pro，已完成题目仍可复练")
        }
        guard next.currentFirst != nil || limiter.reserve(questionID: next.current.id) else {
            throw SpatialQuizBank.Failure.invalid(limiter.quotaError ?? "今日题数已用完")
        }
        let pending = next.pending ?? .init(id: UUID(), questionID: next.current.id, input: next.draft,
            submittedAt: now, premium: limiter.isPremium)
        next.pending = pending; next.phase = .calculating; try commit(next)
        activity = .calculating; message = nil; return pending
    }
    func calculationUnconfirmed(_ pending: SpatialQuizRecord.Pending, message: String) {
        guard ownsRecord, record?.pending == pending, activity == .calculating else { return }
        activity = .unconfirmed; self.message = message
    }
    @discardableResult func accept(_ shot: SpatialQuizShot, pending: SpatialQuizRecord.Pending) -> Bool {
        guard ownsRecord, activity == .calculating, let record,
              record.pending == pending, shot.id == pending.id, shot.questionID == record.current.id,
              shot.valid, shot.facts.mode == mode, shot.physical.input == pending.input.spatialInput,
              shot.physical.before == record.current.board else { return false }
        pendingResult = shot
        return saveResult()
    }
    @discardableResult func retrySave() -> Bool {
        guard ownsRecord, activity == .saveFailed else { return false }
        return pendingResult == nil ? reconcile() : saveResult()
    }
    @discardableResult private func saveResult() -> Bool {
        guard let shot = pendingResult, var next = record else { return false }
        next.accept(shot)
        do {
            try commit(next); pendingResult = nil
            guard reconcile() else { return false }
            // Always play the accepted stroke; legacy playsStroke=false is archive-only.
            activity = .playing; message = nil
            return true
        } catch { message = error.localizedDescription; activity = .saveFailed; return false }
    }
    @discardableResult func reconcile() -> Bool {
        guard ownsRecord, let record else { return false }
        for answer in record.firstAnswers where !limiter.reconcile(answer.receipt) {
            message = limiter.quotaError; activity = .saveFailed; return false
        }
        activity = .idle; return true
    }
    func retry() throws {
        guard ownsRecord, activity == .idle || activity == .unconfirmed, var next = record,
              next.latestShot != nil || next.pending != nil else { return }
        next.pending = nil; next.phase = .aiming; try commit(next)
        pendingResult = nil; activity = .idle; message = nil
    }
    func playbackFinished() { if [.playing,.replaying,.demonstrating].contains(activity) { activity = .idle; returnPhase = nil } }
    func beginReplay() -> SpatialQuizShot? {
        guard ownsRecord, activity == .idle, let record, let shot = record.latestShot else { return nil }
        returnPhase = record.phase; activity = .replaying; return shot
    }
    func beginDemonstration() -> SpatialQuizInstance? {
        guard canDemonstrate, let record else { return nil }
        returnPhase = record.phase; activity = .demonstrating; return record.current
    }
    func suspend() {
        if activity == .calculating { activity = .unconfirmed }
        else if [.playing,.replaying,.demonstrating].contains(activity) { playbackFinished() }
    }
    func invalidateOwner() { record = nil; pendingResult = nil; activity = .idle; message = nil }
    func next(bank: SpatialQuizBank.Bank) throws {
        guard ownsRecord, activity == .idle, var next = record, next.phase == .result, next.currentFirst != nil else { return }
        if next.status != .active { next.phase = .summary;try commit(next);return }
        guard !next.configuration.freePractice || limiter.isPremium else {
            throw SpatialQuizBank.Failure.invalid("继续不限题练习需要Pro，已完成题目仍可复练")
        }
        guard bank.manifest.mode == mode, next.bankFingerprint == bank.fingerprint else {
            throw SpatialQuizBank.Failure.invalid("题库已更新，请结束本轮并重新开始")
        }
        if (!next.configuration.freePractice && next.cursor == next.questions.count-1) || limiter.isLimitReached {
            next.status = .completed; next.phase = .summary; try commit(next); return
        }
        let payloadSize = try next.encodedPayload().count
        if next.configuration.freePractice && (next.cursor == next.questions.count-1 || payloadSize > 512_000) {
            let remaining = next.questions.dropFirst(next.cursor+1).map(\.source)
            let selected: [SpatialQuizQuestion]
            if !remaining.isEmpty { selected = Array(remaining) }
            else {
                let available = bank.questions.filter { next.configuration.filter.accepts($0) && !next.seenContentIDs.contains($0.id) }.count
                selected = try bank.draw(count: min(10,available), filter: next.configuration.filter, excluding: next.seenContentIDs)
            }
            var continuation = SpatialQuizRecord(owner: next.ownerKey, mode: mode, configuration: next.configuration, bank: bank, questions: selected)
            continuation.logicalSessionID = next.logicalSessionID; continuation.previousCount = next.totalCount
            continuation.previousSuccessCount = next.successCount; continuation.seenContentIDs.formUnion(next.seenContentIDs)
            next.status = .completed
            guard limiter.reserve(questionID: continuation.current.id) else { throw SpatialQuizBank.Failure.invalid("今日题数已用完") }
            do { try repository.saveAtomically([next,continuation]); record = continuation; onMutation?() }
            catch { limiter.release(questionID: continuation.current.id); throw error }
        } else {
            next.advance()
            guard limiter.reserve(questionID: next.current.id) else { throw SpatialQuizBank.Failure.invalid("今日题数已用完") }
            do { try commit(next) } catch { limiter.release(questionID: next.current.id); throw error }
        }
    }
    func finish() throws {
        guard ownsRecord, activity == .idle || activity == .unconfirmed, var next = record else { return }
        next.pending = nil; next.status = .ended; next.phase = .summary
        try commit(next); limiter.release(questionID: next.current.id); activity = .idle
    }
}
