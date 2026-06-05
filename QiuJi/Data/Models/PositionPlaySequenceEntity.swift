import Foundation
import SwiftData

/// 走位序列的本地持久化实体（SwiftData，ADR-P11-01）。
///
/// 走位序列是值类型 `PositionPlaySequence`（含嵌套快照/步骤），结构会演进，故以 **JSON blob**
/// 存储（`payload`），避免为每层嵌套建关系表与迁移。顶层只冗余 `name`/`updatedAt` 便于列表与排序。
/// 现有 `CustomPlan` 只能引用内置 `drillId`，无法内嵌自定义内容，故新增本实体（纯新增，向后兼容）。
@Model
final class PositionPlaySequenceEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    /// JSON 编码的 `PositionPlaySequence`。
    var payload: Data

    init(id: UUID, name: String, createdAt: Date, updatedAt: Date, payload: Data) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.payload = payload
    }
}

extension PositionPlaySequenceEntity {

    /// 用值类型序列构造实体。
    static func make(from sequence: PositionPlaySequence) -> PositionPlaySequenceEntity {
        let data = (try? JSONEncoder().encode(sequence)) ?? Data()
        return PositionPlaySequenceEntity(
            id: sequence.id, name: sequence.name,
            createdAt: sequence.createdAt, updatedAt: sequence.updatedAt,
            payload: data
        )
    }

    /// 用最新值类型序列覆盖本实体。
    func apply(_ sequence: PositionPlaySequence) {
        name = sequence.name
        updatedAt = sequence.updatedAt
        payload = (try? JSONEncoder().encode(sequence)) ?? payload
    }

    /// 解码回值类型序列。
    func decoded() -> PositionPlaySequence? {
        try? JSONDecoder().decode(PositionPlaySequence.self, from: payload)
    }
}
