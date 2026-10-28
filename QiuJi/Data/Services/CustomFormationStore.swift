import Foundation
import CryptoKit

struct FormationRemoteRecord: Codable {
    let clientId: UUID
    let revision: Int
    let deleted: Bool
    let schemaVersion: Int
    let template: CustomFormationTemplate?
    let modifiedAt: Date

    func validate() throws {
        guard revision > 0, schemaVersion == 1,
              deleted ? template == nil : template?.id == clientId else {
            throw CustomFormationError.invalid("云端球形版本无效，本机模板已保留")
        }
        if let template { try template.validateForSync() }
    }
}

struct FormationMutation: Codable {
    var operationId = UUID()
    let clientId: UUID
    let generation: Int
    let baseRevision: Int
    var schemaVersion = 1
    let template: CustomFormationTemplate?
    var deleted: Bool { template == nil }
}

struct FormationSyncMetadata: Codable {
    var revision = 0
    var generation = 0
    var acknowledged = 0
    var deleted = false
    var pending: FormationMutation?
    var dirty: Bool { generation > acknowledged || pending != nil }
}

/// All read/modify/write operations share MainActor serialization, including UI and
/// background-sync callbacks. Network awaits never hold a stale archive to write back.
@MainActor
struct CustomFormationRepository {
    struct Archive: Codable {
        var version = 2
        var templates: [CustomFormationTemplate] = []
        var selectedID: UUID?
        var metadata: [String: FormationSyncMetadata] = [:]
        var cursor = 0
        var notice: String?
        var syncError: String?
        // Durable destination receipts make cross-file owner moves restartable.
        var transfers: [String: UUID] = [:]

        enum CodingKeys: String, CodingKey { case version, templates, selectedID, metadata, cursor, notice, syncError, transfers }
        init(templates: [CustomFormationTemplate] = [], selectedID: UUID? = nil) {
            self.templates = templates; self.selectedID = selectedID
            for t in templates { metadata[t.id.uuidString] = .init(generation: 1) }
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            version = try c.decode(Int.self, forKey: .version)
            templates = try c.decode([CustomFormationTemplate].self, forKey: .templates)
            selectedID = try c.decodeIfPresent(UUID.self, forKey: .selectedID)
            if version == 2 {
                metadata = try c.decode([String: FormationSyncMetadata].self, forKey: .metadata)
                cursor = try c.decode(Int.self, forKey: .cursor)
                transfers = try c.decode([String: UUID].self, forKey: .transfers)
                notice = try c.decodeIfPresent(String.self, forKey: .notice)
                syncError = try c.decodeIfPresent(String.self, forKey: .syncError)
            }
        }
        func meta(_ id: UUID) -> FormationSyncMetadata { metadata[id.uuidString] ?? .init() }
        var pendingCount: Int { metadata.values.filter(\.dirty).count }
    }
    let url: URL
    let ownerKey: String
    init(ownerKey: String, directory: URL? = nil) {
        self.ownerKey = ownerKey
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CustomFormations", isDirectory: true)
        let owner = Data(ownerKey.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
        url = root.appendingPathComponent(owner + ".json")
    }
    func load() throws -> Archive {
        guard FileManager.default.fileExists(atPath: url.path) else { return Archive() }
        let bytes = try Data(contentsOf: url)
        var archive = try JSONDecoder().decode(Archive.self, from: bytes)
        guard [1, 2].contains(archive.version) else { throw CustomFormationError.invalid("模板版本暂不支持，原文件已保留") }
        try validate(archive)
        if archive.version == 1 {
            let backup = url.appendingPathExtension("v1-backup")
            if !FileManager.default.fileExists(atPath: backup.path) { try bytes.write(to: backup, options: .atomic) }
            archive.version = 2
            for t in archive.templates { archive.metadata[t.id.uuidString] = .init(generation: 1) }
            try save(archive)
        }
        return archive
    }
    private func validate(_ archive: Archive) throws {
        for t in archive.templates { _ = try t.validated() }
        guard Set(archive.templates.map(\.id)).count == archive.templates.count, archive.cursor >= 0 else {
            throw CustomFormationError.invalid("模板数据重复或游标无效，原文件已保留")
        }
        if archive.version == 2 {
            guard archive.templates.allSatisfy({ archive.metadata[$0.id.uuidString] != nil }) else {
                throw CustomFormationError.invalid("模板同步记录缺失，原文件已保留")
            }
            for (key, meta) in archive.metadata {
                guard let id = UUID(uuidString: key), meta.revision >= 0, meta.generation >= meta.acknowledged,
                      meta.acknowledged >= 0, meta.deleted == !archive.templates.contains(where: { $0.id == id }) else {
                    throw CustomFormationError.invalid("模板同步记录无效，原文件已保留")
                }
                if let pending = meta.pending {
                    guard pending.clientId == id, pending.generation <= meta.generation, pending.baseRevision >= 0 else {
                        throw CustomFormationError.invalid("待同步操作无效，原文件已保留")
                    }
                    if let template = pending.template { try template.validateForSync() }
                }
            }
        }
    }
    func save(_ archive: Archive) throws {
        try validate(archive)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(archive).write(to: url, options: .atomic)
    }
    @discardableResult
    func transaction(_ edit: (inout Archive) throws -> Void) throws -> Archive {
        var archive = try load()
        try edit(&archive)
        try save(archive)
        NotificationCenter.default.post(name: .formationStoreChanged, object: ownerKey)
        return archive
    }
    @discardableResult
    func put(_ template: CustomFormationTemplate, basedOn original: CustomFormationTemplate? = nil) throws -> Archive {
        try template.validateForPractice()
        try template.validateForSync()
        return try transaction { archive in
            var value = template
            let current = archive.templates.first { $0.id == template.id }
            if let original, (current == nil || !current!.sameContent(as: original)) && !(current?.sameContent(as: template) ?? false) {
                value.id = UUID(); value.name = Self.copyName(template.name)
                archive.notice = "其他设备也修改或删除了此球形，已将当前修改保留为副本"
            }
            if archive.meta(value.id).deleted {
                value.id = UUID(); value.name = Self.copyName(value.name)
                archive.notice = "原球形已删除，当前修改已保存为副本"
            }
            archive.templates.removeAll { $0.id == value.id }
            archive.templates.append(value)
            var meta = archive.meta(value.id); meta.generation += 1; meta.deleted = false
            archive.metadata[value.id.uuidString] = meta
            archive.selectedID = value.id
        }
    }
    func remove(_ id: UUID) throws -> Archive {
        try transaction { archive in
            guard archive.templates.contains(where: { $0.id == id }) else { return }
            archive.templates.removeAll { $0.id == id }
            var meta = archive.meta(id); meta.generation += 1; meta.deleted = true
            archive.metadata[id.uuidString] = meta
            if archive.selectedID == id { archive.selectedID = nil }
        }
    }
    func nextOperation(_ id: UUID) throws -> FormationMutation? {
        var result: FormationMutation?
        _ = try transaction { archive in
            var meta = archive.meta(id)
            if let pending = meta.pending { result = pending; return }
            guard meta.dirty else { return }
            let template = archive.templates.first { $0.id == id }
            if !meta.deleted {
                guard let template else { throw CustomFormationError.invalid("待同步模板缺失") }
                try template.validateForSync()
            }
            let op = FormationMutation(clientId: id, generation: meta.generation, baseRevision: meta.revision, template: template)
            meta.pending = op; archive.metadata[id.uuidString] = meta; result = op
        }
        return result
    }
    func acknowledge(_ op: FormationMutation, record: FormationRemoteRecord, conflict: Bool) throws {
        try record.validate()
        guard record.clientId == op.clientId else { throw CustomFormationError.invalid("同步应答标识不符") }
        _ = try transaction { archive in
            var meta = archive.meta(op.clientId)
            guard meta.pending?.operationId == op.operationId else { return }
            if conflict {
                let current = archive.templates.first { $0.id == op.clientId }
                if let current, !(record.template?.sameContent(as: current) ?? false) {
                    var copy = current; copy.id = UUID(); copy.name = Self.copyName(copy.name)
                    archive.templates.append(copy)
                    archive.metadata[copy.id.uuidString] = .init(generation: 1)
                    if archive.selectedID == op.clientId { archive.selectedID = copy.id }
                    archive.notice = "其他设备也修改了此球形，已保留两个版本"
                } else if meta.deleted && !record.deleted {
                    archive.notice = "其他设备已更新此球形，如需删除请再次操作"
                }
                meta.acknowledged = meta.generation
                Self.install(record, into: &archive)
            } else {
                meta.acknowledged = op.generation
                if meta.generation == op.generation { Self.install(record, into: &archive) }
            }
            meta.pending = nil
            meta.revision = record.revision
            meta.deleted = !archive.templates.contains { $0.id == op.clientId }
            archive.metadata[op.clientId.uuidString] = meta
        }
    }
    func apply(_ records: [FormationRemoteRecord], cursor: Int) throws {
        for r in records { try r.validate() }
        _ = try transaction { archive in
            guard cursor >= archive.cursor else { throw CustomFormationError.invalid("同步游标倒退") }
            for record in records {
                var meta = archive.meta(record.clientId)
                // Pending writes must settle their immutable receipt before pulling over them.
                guard !meta.dirty, record.revision > meta.revision else { continue }
                Self.install(record, into: &archive)
                meta.revision = record.revision; meta.deleted = record.deleted
                archive.metadata[record.clientId.uuidString] = meta
            }
            archive.cursor = cursor
        }
    }
    private static func install(_ record: FormationRemoteRecord, into archive: inout Archive) {
        archive.templates.removeAll { $0.id == record.clientId }
        if let template = record.template { archive.templates.append(template) }
        else if archive.selectedID == record.clientId { archive.selectedID = nil }
    }
    static func copyName(_ name: String) -> String { String(String.UnicodeScalarView(name.unicodeScalars.prefix(115))) + " 冲突副本" }

    static func transfer(from source: Self, to destination: Self) throws {
        guard source.url != destination.url else { return }
        let snapshot = try source.load()
        _ = try destination.transaction { target in
            for template in snapshot.templates {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                let fingerprint = SHA256.hash(data: try encoder.encode(template)).map { String(format: "%02x", $0) }.joined()
                let receipt = source.ownerKey + ":" + template.id.uuidString + ":" + fingerprint
                if target.transfers[receipt] != nil { continue }
                var value = template
                if let existing = target.templates.first(where: { $0.id == value.id }) {
                    if existing.sameContent(as: value) { target.transfers[receipt] = existing.id; continue }
                    value.id = UUID(); value.name = copyName(value.name)
                } else if target.meta(value.id).deleted { value.id = UUID() }
                target.templates.append(value)
                target.metadata[value.id.uuidString] = .init(generation: 1)
                target.transfers[receipt] = value.id
            }
        }
        // Destination is durable before source is cleared. Retrying uses its receipts.
        _ = try source.transaction { archive in archive = Archive() }
    }
}

extension Notification.Name {
    static let formationStoreChanged = Notification.Name("formationStoreChanged")
    static let formationNeedsSync = Notification.Name("formationNeedsSync")
}

extension CustomFormationTemplate {
    func sameContent(as other: Self) -> Bool {
        id == other.id && name == other.name && ballKeys == other.ballKeys && drawing == other.drawing &&
        board.onTable.count == other.board.onTable.count && board.onTable.allSatisfy { key, point in
            other.board.onTable[key]?.x == point.x && other.board.onTable[key]?.y == point.y
        }
    }
    func validateForSync() throws {
        _ = try validated()
        guard name.unicodeScalars.count <= 120 else { throw CustomFormationError.invalid("模板名称最多120字") }
        // The existing wire contract must still accept pending/downloaded legacy templates.
        // New local saves use validateForPractice() before reaching this compatibility boundary.
        guard ballKeys.count <= 25 else { throw CustomFormationError.invalid("同步球形超过旧版25颗目标球上限") }
        guard (drawing?.lines.count ?? 0) <= 256, (drawing?.vertices.count ?? 0) <= 512 else { throw CustomFormationError.invalid("最多256条辅助线和512个端点") }
        guard try JSONEncoder().encode(self).count <= 262144 else { throw CustomFormationError.invalid("球形数据超过256KB") }
    }
}
