import Foundation
import SwiftData

/// Manual records reuse the versioned source snapshot already preserved by sync.
struct ManualTrainingSource: Codable, Equatable {
    let year: Int
    let month: Int
    let day: Int
}

extension TrainingSession {
    var isManualTraining: Bool { sourceKind == "manualTraining" }
    var reportingDate: Date {
        guard isManualTraining, sourcePayloadVersion == 1,
              let data = sourcePayloadSnapshot,
              let source = try? JSONDecoder().decode(ManualTrainingSource.self, from: data) else { return date }
        return Calendar(identifier: .gregorian).date(from: DateComponents(
            year: source.year, month: source.month, day: source.day, hour: 12)) ?? date
    }
}

@MainActor
enum TrainingUtilityStore {
    enum Failure: LocalizedError {
        case invalid, ownerChanged, historyLocked, recordUnavailable
        var errorDescription: String? {
            switch self {
            case .invalid: return "请填写训练内容和 1–1440 分钟的训练用时，并选择今天或以前的日期。"
            case .ownerChanged: return "账号已变化，请返回后重新打开。"
            case .historyLocked: return "这条记录已超出当前可查看的历史范围，请开通 Pro 后再编辑。"
            case .recordUnavailable: return "这条训练记录已不存在，请返回后重新查看。"
            }
        }
    }

    static func saveManual(context: ModelContext, ownerKey: String, existing: TrainingSession? = nil,
                           date: Date, minutes: Int, ballType: String, content: String, note: String,
                           isPremium: Bool = false, recordID: UUID = UUID(),
                           save: (ModelContext) throws -> Void = { try $0.save() }) throws {
        guard ownerKey == CurrentOwnerContext.shared.ownerKey,
              existing == nil || existing?.ownerKey == ownerKey else { throw Failure.ownerChanged }
        if let existing, !HistoryAccessController.isAccessible(existing, isPremium: isPremium) { throw Failure.historyLocked }
        let title = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 100, (1...1440).contains(minutes),
              Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: Date()),
              existing == nil || existing?.isManualTraining == true else { throw Failure.invalid }
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        let payload = try JSONEncoder().encode(ManualTrainingSource(year: parts.year!, month: parts.month!, day: parts.day!))
        // A dedicated context keeps failed utility writes from rolling back an active training draft.
        let writer = ModelContext(context.container)
        writer.autosaveEnabled = false
        let record: TrainingSession
        if let existing {
            let id = existing.id
            guard let stored = try writer.fetch(FetchDescriptor<TrainingSession>(predicate: #Predicate { $0.id == id && $0.ownerKey == ownerKey })).first else { throw Failure.recordUnavailable }
            record = stored
        } else {
            let id = recordID
            if try writer.fetchCount(FetchDescriptor<TrainingSession>(predicate: #Predicate { $0.id == id && $0.ownerKey == ownerKey })) > 0 { return }
            record = TrainingSession(ballType: ballType, ownerKey: ownerKey)
            record.id = recordID
            writer.insert(record)
        }
        record.date = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        record.ballType = ballType
        record.totalDurationMinutes = minutes
        record.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        record.sourceKind = "manualTraining"
        record.sourceTitleSnapshot = title
        record.sourcePayloadVersion = 1
        record.sourcePayloadSnapshot = payload
        writer.insert(SyncPendingItem(entityType: SyncEntityType.trainingSession, entityId: record.id,
                                      operation: existing == nil ? SyncOperation.create : SyncOperation.update, ownerKey: ownerKey))
        try save(writer)
        // The caller may already hold this model in another context. Update its view immediately.
        if let existing {
            existing.date = record.date
            existing.ballType = record.ballType
            existing.totalDurationMinutes = record.totalDurationMinutes
            existing.note = record.note
            existing.sourceTitleSnapshot = record.sourceTitleSnapshot
            existing.sourcePayloadVersion = record.sourcePayloadVersion
            existing.sourcePayloadSnapshot = record.sourcePayloadSnapshot
        }
    }

    static func saveNote(context: ModelContext, session: TrainingSession, entryID: UUID?, text: String,
                         isPremium: Bool, save: (ModelContext) throws -> Void = { try $0.save() }) throws {
        guard session.ownerKey == CurrentOwnerContext.shared.ownerKey else { throw Failure.ownerChanged }
        guard HistoryAccessController.isAccessible(session, isPremium: isPremium) else { throw Failure.historyLocked }
        let old = session.note
        let entry = entryID.flatMap { id in session.drillEntries.first { $0.id == id } }
        if entryID != nil && entry == nil { throw Failure.recordUnavailable }
        let oldEntry = entry?.note
        let pending = SyncPendingItem(entityType: SyncEntityType.trainingSession, entityId: session.id,
                                      operation: SyncOperation.update, ownerKey: session.ownerKey)
        if let entry { entry.note = text } else { session.note = text }
        context.insert(pending)
        do { try save(context) }
        catch {
            session.note = old
            if let entry, let oldEntry { entry.note = oldEntry }
            context.delete(pending)
            throw error
        }
    }
}
