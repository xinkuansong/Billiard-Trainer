import Foundation
import SwiftData

@MainActor
protocol SeparationPracticeRepository {
    var ownerKey: String { get }
    func save(_ record: SeparationPracticeRecord) throws
    func saveAtomically(_ records: [SeparationPracticeRecord]) throws
    func resumable(is3D: Bool) throws -> SeparationPracticeRecord?
    func resumable(is3D: Bool, compatible: (SeparationPracticeRecord) -> Bool) throws -> SeparationPracticeRecord?
}

extension SeparationPracticeRepository {
    func resumable(is3D: Bool, compatible: (SeparationPracticeRecord) -> Bool) throws -> SeparationPracticeRecord? {
        try resumable(is3D: is3D).flatMap { compatible($0) ? $0 : nil }
    }
}

/// Versioned physical recordings use the existing session transport and frozen ownership.
@MainActor
final class LocalSeparationPracticeRepository: SeparationPracticeRepository {
    enum Failure: LocalizedError {
        case ownerChanged, invalidRecord, oversizedRecord
        var errorDescription: String? {
            switch self {
            case .ownerChanged: "账号已切换，请重新进入分离角练习。"
            case .invalidRecord: "这条分离角记录暂时无法读取，请保留记录后重试。"
            case .oversizedRecord: "本题的轨迹记录过大，请返回训练设置重新出题。"
            }
        }
    }
    static let kind = TrainingSessionKind.separationPractice
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

    func save(_ record: SeparationPracticeRecord) throws { try saveAtomically([record]) }

    func saveAtomically(_ records: [SeparationPracticeRecord]) throws {
        var undo: [() -> Void] = []
        do {
            for record in records {
                guard record.ownerKey == owner.ownerKey else { throw Failure.ownerChanged }
                guard record.isCompatible,
                      Set(record.attempts.map(\.id)).count == record.attempts.count,
                      Set(record.attempts.map(\.questionID)).count == record.attempts.count,
                      record.attempts.allSatisfy({ attempt in
                          record.questions.contains { $0.id == attempt.questionID }
                      }) else { throw Failure.invalidRecord }
                let data = try record.encodedPayload()
                // Base64 plus DTO metadata must fit the existing 2 MiB request envelope.
                guard data.count < 1_450_000 else { throw Failure.oversizedRecord }
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
                    session.sourceKind = Self.kind; session.sourceId = record.is3D ? "separationPractice3D" : "separationPractice2D"
                    session.sourcePayloadVersion = SeparationPracticeRecord.payloadVersion
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
        for record in records where !record.attempts.isEmpty { enqueue(record.id, record.ownerKey) }
    }

    func resumable(is3D: Bool) throws -> SeparationPracticeRecord? {
        try resumable(is3D: is3D, compatible: { _ in true })
    }
    func resumable(is3D: Bool, compatible: (SeparationPracticeRecord) -> Bool) throws -> SeparationPracticeRecord? {
        let key = owner.ownerKey, kind = Self.kind
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.ownerKey == key && $0.kind == kind },
            sortBy: [SortDescriptor(\.date, order: .reverse)]))
        var candidates: [SeparationPracticeRecord] = []
        for session in sessions where ["separationPractice2D", "separationPractice3D"].contains(session.sourceId ?? "") {
            guard let data = session.sourcePayloadSnapshot else { throw Failure.invalidRecord }
            let record = try SeparationPracticeRecord.decodePayload(data)
            guard record.isCompatible, record.ownerKey == key,
                  record.id == session.id else { throw Failure.invalidRecord }
            if record.status == .active, compatible(record) { candidates.append(record) }
        }
        return candidates.max { $0.updatedAt < $1.updatedAt }
    }
}
