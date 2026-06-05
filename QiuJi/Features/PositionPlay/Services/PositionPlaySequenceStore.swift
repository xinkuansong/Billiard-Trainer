import Foundation
import SwiftData

/// 走位序列本地存取（SwiftData，ADR-P11-01）。
/// 以 `PositionPlaySequenceEntity`（JSON blob）持久化值类型 `PositionPlaySequence`，
/// 支持保存/更新（按 id upsert）、列表、删除。
@MainActor
struct PositionPlaySequenceStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// 保存或更新一条序列（按 id upsert）。
    func save(_ sequence: PositionPlaySequence) throws {
        let id = sequence.id
        let descriptor = FetchDescriptor<PositionPlaySequenceEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.apply(sequence)
        } else {
            context.insert(PositionPlaySequenceEntity.make(from: sequence))
        }
        try context.save()
    }

    /// 全部序列（按更新时间倒序）。
    func all() -> [PositionPlaySequence] {
        let descriptor = FetchDescriptor<PositionPlaySequenceEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.compactMap { $0.decoded() }
    }

    /// 删除一条序列。
    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<PositionPlaySequenceEntity>(
            predicate: #Predicate { $0.id == id }
        )
        for entity in try context.fetch(descriptor) {
            context.delete(entity)
        }
        try context.save()
    }
}
