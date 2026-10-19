import Foundation
import Combine

struct CustomFormationTemplate: Codable, Identifiable {
    static let maximumTargetBalls = 25
    var id = UUID()
    var name: String
    var updatedAt = Date()
    var ballKeys: [String]
    var board: BoardSnapshot
    var drawing: FormationDrawing? = nil


    func validated() throws -> Self {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CustomFormationError.invalid("请填写模板名称")
        }
        guard !ballKeys.isEmpty, Set(ballKeys).count == ballKeys.count,
              ballKeys.allSatisfy(PositionPlayBall.isInstance), board.hasCue,
              Set(board.onTable.keys) == Set(ballKeys + [PositionPlayBall.cueKey]) else {
            throw CustomFormationError.invalid("模板需要一颗母球和至少一颗目标球")
        }
        for point in board.onTable.values {
            guard point.x.isFinite, point.y.isFinite, (0...1).contains(point.x), (0...0.5).contains(point.y) else {
                throw CustomFormationError.invalid("球位超出台面，请重新摆放")
            }
        }
        if let drawing {
            let vertices = Set(drawing.vertices.map(\.id))
            guard vertices.count == drawing.vertices.count,
                  Set(drawing.lines.map(\.id)).count == drawing.lines.count,
                  drawing.vertices.allSatisfy({ $0.x.isFinite && $0.z.isFinite && abs($0.x) <= AngleSceneCalculator.innerLength/2 && abs($0.z) <= AngleSceneCalculator.innerWidth/2 }),
                  drawing.lines.allSatisfy({ vertices.contains($0.start) && vertices.contains($0.end) && $0.start != $0.end && Set($0.balls).count == $0.balls.count && Set($0.balls).isSubset(of:Set(board.onTable.keys)) }) else {
                throw CustomFormationError.invalid("辅助线数据无效，原模板已保留")
            }
        }
        return self
    }

    func copied() -> Self {
        var copy = self
        copy.id = UUID(); copy.name += " 副本"; copy.updatedAt = Date()
        var positions = [PositionPlayBall.cueKey: board.onTable[PositionPlayBall.cueKey]!]
        var replacements = [PositionPlayBall.cueKey:PositionPlayBall.cueKey]
        copy.ballKeys = ballKeys.map { old in
            let key = PositionPlayBall.instanceKey(number: PositionPlayBall.number(for: old)!)
            positions[key] = board.onTable[old]
            replacements[old] = key
            return key
        }
        copy.board = BoardSnapshot(onTable: positions)
        if var drawing = copy.drawing {
            for i in drawing.lines.indices { drawing.lines[i].balls = drawing.lines[i].balls.compactMap { replacements[$0] } }
            copy.drawing = drawing
        }
        return copy
    }
}

enum CustomFormationError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case let .invalid(message): return message } }
}

@MainActor
final class CustomFormationLibrary: ObservableObject {
    @Published private(set) var archive = CustomFormationRepository.Archive()
    @Published var error: String?
    @Published private(set) var failedToLoad = false
    private let repository: CustomFormationRepository
    var templates: [CustomFormationTemplate] { archive.templates.sorted { $0.updatedAt > $1.updatedAt } }
    var selected: CustomFormationTemplate? { templates.first { $0.id == archive.selectedID } }

    init(ownerKey: String, directory: URL? = nil) {
        repository = .init(ownerKey: ownerKey, directory: directory)
        reload()
    }

    func reload() {
        do { archive = try repository.load(); failedToLoad = false; error = nil }
        catch { failedToLoad = true; self.error = "读取球形模板失败：\(error.localizedDescription)" }
    }

    @discardableResult
    private func change(_ action: () throws -> CustomFormationRepository.Archive) -> Bool {
        guard !failedToLoad else { error = "请先重新读取模板，避免覆盖原文件"; return false }
        do {
            archive = try action()
            NotificationCenter.default.post(name: .formationNeedsSync, object: repository.ownerKey)
            return true
        } catch { self.error = "保存球形模板失败：\(error.localizedDescription)"; return false }
    }

    @discardableResult
    func save(_ template: CustomFormationTemplate, basedOn original: CustomFormationTemplate? = nil) -> Bool {
        change { try repository.put(template, basedOn: original) }
    }
    func select(_ id: UUID) {
        _ = change { try repository.transaction { $0.selectedID = id } }
    }
    func delete(_ id: UUID) { _ = change { try repository.remove(id) } }
    func rename(_ template: CustomFormationTemplate, name: String) {
        var updated = template; updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.updatedAt = Date(); _ = save(updated, basedOn: template)
    }
    func duplicate(_ template: CustomFormationTemplate) { _ = save(template.copied()) }
    func syncLabel(for id: UUID, enabled: Bool) -> String {
        guard enabled, OwnerKey.isAccount(repository.ownerKey) else { return "已保存到本机" }
        if archive.syncError != nil { return "同步未完成，本机模板已保留" }
        return archive.meta(id).dirty ? "已保存到本机，待同步" : "已同步"
    }
}
