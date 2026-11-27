import Foundation
import SwiftData

@MainActor
protocol SpatialQuizRepository {
    var ownerKey: String { get }
    var unreadableCount: Int { get }
    var incompatibleCount: Int { get }
    func save(_ record: SpatialQuizRecord) throws
    func saveAtomically(_ records: [SpatialQuizRecord]) throws
    func resumable(mode: SpatialQuizMode) throws -> SpatialQuizRecord?
    func resumable(mode: SpatialQuizMode, compatible: (SpatialQuizRecord) -> Bool) throws -> SpatialQuizRecord?
}

extension SpatialQuizRepository {
    var unreadableCount: Int { 0 }
    var incompatibleCount: Int { 0 }
    func resumable(mode: SpatialQuizMode, compatible: (SpatialQuizRecord) -> Bool) throws -> SpatialQuizRecord? {
        try resumable(mode: mode).flatMap { compatible($0) ? $0 : nil }
    }
}

/// Versioned physical recordings use the existing session transport and frozen ownership.
@MainActor
final class LocalSpatialQuizRepository: SpatialQuizRepository {
    enum Failure: LocalizedError {
        case ownerChanged, invalidRecord, oversizedRecord
        var errorDescription: String? {
            switch self {
            case .ownerChanged: "账号已切换，请重新进入空间练习。"
            case .invalidRecord: "这条空间记录暂时无法读取，请保留记录后重试。"
            case .oversizedRecord: "本题的轨迹记录过大，请返回训练设置重新出题。"
            }
        }
    }
    private let context: ModelContext
    private(set) var unreadableCount = 0
    private(set) var incompatibleCount = 0
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

    func save(_ record: SpatialQuizRecord) throws { try saveAtomically([record]) }

    func saveAtomically(_ records: [SpatialQuizRecord]) throws {
        var undo: [() -> Void] = []
        do {
            for record in records {
                guard record.ownerKey == owner.ownerKey else { throw Failure.ownerChanged }
                guard record.isCurrentCompatible,
                      Set(record.firstAnswers.map(\.id)).count == record.firstAnswers.count else { throw Failure.invalidRecord }
                let data = try record.encodedPayload()
                // Base64 plus DTO metadata must fit the existing 2 MiB request envelope.
                guard data.count < 1_450_000 else { throw Failure.oversizedRecord }
                let id = record.id
                let existing = try context.fetch(FetchDescriptor<TrainingSession>(predicate: #Predicate { $0.id == id })).first
                guard existing == nil || existing?.ownerKey == record.ownerKey else { throw Failure.ownerChanged }
                guard existing == nil || existing?.kind == record.mode.kind else { throw Failure.invalidRecord }
                let session = existing ?? TrainingSession(kind: record.mode.kind, ownerKey: record.ownerKey)
                let previousPayload = session.sourcePayloadSnapshot
                let previousDuration = session.totalDurationMinutes
                if existing == nil {
                    session.id = record.id; session.date = record.startedAt
                    session.note = record.displayName; session.sourceTitleSnapshot = record.displayName
                    session.sourceKind = record.mode.kind; session.sourceId = record.mode.kind
                    session.sourcePayloadVersion = SpatialQuizRecord.version
                    context.insert(session)
                }
                session.sourcePayloadSnapshot = data
                session.totalDurationMinutes = max(0, Int(record.activeSeconds / 60))
                undo.append {
                    if existing == nil { self.context.delete(session) }
                    else { session.sourcePayloadSnapshot = previousPayload; session.totalDurationMinutes = previousDuration }
                }
            }
            try context.save()
        } catch {
            // Roll back only our fields, including a partially prepared continuation.
            for restore in undo.reversed() { restore() }
            throw error
        }
        for record in records where !record.firstAnswers.isEmpty { enqueue(record.id, record.ownerKey) }
    }

    func resumable(mode: SpatialQuizMode) throws -> SpatialQuizRecord? {
        try resumable(mode: mode, compatible: { _ in true })
    }
    func resumable(mode: SpatialQuizMode, compatible: (SpatialQuizRecord) -> Bool) throws -> SpatialQuizRecord? {
        let key = owner.ownerKey, kind = mode.kind
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.ownerKey == key && $0.kind == kind },
            sortBy: [SortDescriptor(\.date, order: .reverse)]))
        var candidates: [SpatialQuizRecord] = []
        unreadableCount = 0; incompatibleCount = 0
        for session in sessions where session.sourceId == mode.kind {
            do {
                guard let data = session.sourcePayloadSnapshot else { throw Failure.invalidRecord }
                let record = try SpatialQuizRecord.decodePayload(data)
                guard record.ownerKey == key, record.id == session.id, record.mode == mode else { throw Failure.invalidRecord }
                if record.status == .active {
                    if record.isCurrentCompatible && compatible(record) { candidates.append(record) }
                    else { incompatibleCount += 1 }
                }
            } catch {
                // Preserve unsupported/damaged bytes, report them, and do not let
                // one old row prevent another compatible session from resuming.
                unreadableCount += 1
            }
        }
        return candidates.max { $0.updatedAt < $1.updatedAt }
    }
}
