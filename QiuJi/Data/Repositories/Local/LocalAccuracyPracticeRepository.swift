import Foundation
import SwiftData

/// Versioned simulation records share the existing session transport, while
/// retaining their own scoring semantics and frozen account ownership.
@MainActor
final class LocalAccuracyPracticeRepository {
    enum Failure: LocalizedError {
        case ownerChanged, invalidRecord
        var errorDescription: String? {
            switch self {
            case .ownerChanged: "账号已切换，请重新进入准度练习。"
            case .invalidRecord: "这条准度记录暂时无法读取，请保留记录后重试。"
            }
        }
    }
    static let kind = TrainingSessionKind.simulatedAccuracy
    private let context: ModelContext
    private let owner: CurrentOwnerContext
    private let enqueue: @MainActor (UUID, String) -> Void
    init(context: ModelContext, owner: CurrentOwnerContext? = nil,
         enqueue: @escaping @MainActor (UUID, String) -> Void = { id, key in
             SyncQueueManager.shared.enqueue(entityType: "TrainingSession", entityId: id,
                 operation: "update", ownerKey: key)
         }) {
        self.context = context; self.owner = owner ?? .shared
        self.enqueue = enqueue
    }
    var ownerKey: String { owner.ownerKey }

    func save(_ record: AccuracyPracticeRecord) throws {
        guard record.ownerKey == owner.ownerKey else { throw Failure.ownerChanged }
        guard record.version == AccuracyPracticeRecord.payloadVersion,
              Set(record.attempts.map(\.id)).count == record.attempts.count,
              Set(record.attempts.map(\.questionID)).count == record.attempts.count,
              record.attempts.allSatisfy({ attempt in
                  guard let question = record.questions.first(where: { $0.id == attempt.questionID }) else { return false }
                  let actual = attempt.fixedTip, prescribed = question.fixedTip
                  return actual.x.isFinite && actual.y.isFinite && actual.category == attempt.tip
                      && hypot(actual.x, actual.y) <= CuePhysics.miscueLimitFraction + 1e-6
                      && (record.configuration.allowsManualSideSpin || actual.x == prescribed.x)
                      && (record.configuration.allowsManualVerticalSpin || actual.y == prescribed.y)
              }) else { throw Failure.invalidRecord }
        let data = try JSONEncoder().encode(record)
        let id = record.id
        let existing = try context.fetch(FetchDescriptor<TrainingSession>(predicate: #Predicate { $0.id == id })).first
        guard existing == nil || existing?.ownerKey == record.ownerKey else { throw Failure.ownerChanged }
        guard existing == nil || existing?.kind == Self.kind else { throw Failure.invalidRecord }
        let session = existing ?? TrainingSession(kind: Self.kind, ownerKey: record.ownerKey)
        let previousPayload = session.sourcePayloadSnapshot
        let previousDuration = session.totalDurationMinutes
        if existing == nil {
            session.id = record.id; session.date = record.startedAt
            session.note = record.displayName; session.sourceTitleSnapshot = record.displayName
            session.sourceKind = Self.kind; session.sourceId = record.is3D ? "accuracy3D" : "accuracy2D"
            session.sourcePayloadVersion = AccuracyPracticeRecord.payloadVersion
            context.insert(session)
        }
        session.sourcePayloadSnapshot = data
        session.totalDurationMinutes = max(0, Int(record.updatedAt.timeIntervalSince(record.startedAt) / 60))
        do { try context.save() }
        catch {
            // Do not roll back unrelated changes in the shared ModelContext.
            if existing == nil { context.delete(session) }
            else { session.sourcePayloadSnapshot = previousPayload; session.totalDurationMinutes = previousDuration }
            throw error
        }
        // An untouched draft stays local and never creates an empty history entry.
        if !record.attempts.isEmpty {
            enqueue(record.id, record.ownerKey)
        }
    }

    func resumable(is3D: Bool) throws -> AccuracyPracticeRecord? {
        let key = owner.ownerKey, kind = Self.kind
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.ownerKey == key && $0.kind == kind },
            sortBy: [SortDescriptor(\.date, order: .reverse)]))
        for session in sessions where session.sourceId == (is3D ? "accuracy3D" : "accuracy2D") {
            guard let data = session.sourcePayloadSnapshot else { throw Failure.invalidRecord }
            let record = try JSONDecoder().decode(AccuracyPracticeRecord.self, from: data)
            guard record.version == AccuracyPracticeRecord.payloadVersion, record.ownerKey == key,
                  record.id == session.id else { throw Failure.invalidRecord }
            if record.status == .active { return record }
        }
        return nil
    }
}
