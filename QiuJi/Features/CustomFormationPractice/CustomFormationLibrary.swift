import Foundation
import Combine

struct CustomFormationTemplate: Codable, Identifiable {
    static let maximumTargetBalls = 15
    var id = UUID()
    var name: String
    var updatedAt = Date()
    var ballKeys: [String]
    var board: BoardSnapshot
    var drawing: FormationDrawing? = nil

    /// Keep archive decoding compatible; apply current ball rules at edit/save/start boundaries.
    static func ballRuleIssue(for keys: [String]) -> String? {
        guard keys.count <= maximumTargetBalls else { return "最多15颗目标球（母球另计）" }
        let numbers = keys.compactMap(PositionPlayBall.number)
        guard numbers.count == keys.count, numbers.allSatisfy({ (1...15).contains($0) }) else {
            return "目标球只能使用1至15号球"
        }
        guard Set(numbers).count == numbers.count else { return "每个球号只能有一颗" }
        return nil
    }

    var practiceIssue: String? { Self.ballRuleIssue(for: ballKeys) }

    func validateForPractice() throws {
        _ = try validated()
        if let issue = practiceIssue { throw CustomFormationError.invalid(issue) }
    }


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

/// Bundled layouts stay outside the user's archive. Coordinates are normalized by table length.
/// Source diagrams and the local spacing/numbering adaptation are recorded in
/// docs/research/20261028-自定义球形内置模板图文调研.md.
enum BuiltInCustomFormations {
    static let fourFourFourThreeID = UUID(uuidString: "B4443000-0000-4000-8000-000000000001")!
    static let lShapeID = UUID(uuidString: "B1115000-0000-4000-8000-000000000002")!

    static let templates: [CustomFormationTemplate] = {
        // Four short rows in the four quarters, parallel to the short cushions.
        let radius = Double(AngleSceneCalculator.ballRadius) / Double(AngleSceneCalculator.innerLength)
        // Ball surface to either long cushion = one ball diameter (center margin 3R).
        let margin = 3 * radius
        let upper = (0..<4).map { margin + Double($0) * 0.045 }
        let lower = (0..<4).map { 0.5 - margin - Double(3 - $0) * 0.045 }
        let lowerThree = (0..<3).map { 0.5 - margin - Double(2 - $0) * 0.045 }
        let fourFourFourThree = (upper + lower).map { CanvasPoint(x: 0.75, y: $0) }
            + (upper + lowerThree).map { CanvasPoint(x: 0.25, y: $0) }
        // Two eight-ball arms share the 8 ball at the corner: 8 + 8 - 1 = 15.
        let spacing = (0.25 - radius) / 7
        // The two outer balls touch the cushion with their surfaces, not their centers.
        let lShape = (0..<8).map { CanvasPoint(x: 0.25, y: 0.5 - radius - Double($0) * spacing) }
            + (1...7).map { CanvasPoint(x: 0.25 - Double($0) * spacing, y: 0.25) }
        return [
            make(id: fourFourFourThreeID, name: "4443球形", points: fourFourFourThree, cue: .init(x: 0.5, y: 0.25)),
            make(id: lShapeID, name: "L型球形", points: lShape, cue: .init(x: 0.5, y: 0.25))
        ]
    }()

    static func contains(_ id: UUID) -> Bool { templates.contains { $0.id == id } }

    private static func make(id: UUID, name: String, points: [CanvasPoint], cue: CanvasPoint) -> CustomFormationTemplate {
        let keys = points.indices.map { PositionPlayBall.instanceKey(number: $0 + 1, id: id) }
        var positions = Dictionary(uniqueKeysWithValues: zip(keys, points))
        positions[PositionPlayBall.cueKey] = cue
        return .init(id: id, name: name, updatedAt: Date(timeIntervalSince1970: 0),
                     ballKeys: keys, board: .init(onTable: positions))
    }
}

@MainActor
final class CustomFormationLibrary: ObservableObject {
    @Published private(set) var archive = CustomFormationRepository.Archive()
    @Published var error: String?
    @Published private(set) var failedToLoad = false
    @Published private(set) var selectedBuiltInID: UUID?
    private let repository: CustomFormationRepository
    var templates: [CustomFormationTemplate] { archive.templates.sorted { $0.updatedAt > $1.updatedAt } }
    var selectedID: UUID? { selectedBuiltInID ?? archive.selectedID }
    var selected: CustomFormationTemplate? {
        if let selectedBuiltInID { return BuiltInCustomFormations.templates.first { $0.id == selectedBuiltInID } }
        return templates.first { $0.id == archive.selectedID }
    }

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
        guard !BuiltInCustomFormations.contains(template.id) else {
            error = "请先复制内置球形再修改"; return false
        }
        let saved = change { try repository.put(template, basedOn: original) }
        if saved { selectedBuiltInID = nil }
        return saved
    }
    func select(_ id: UUID) {
        if BuiltInCustomFormations.contains(id) { selectedBuiltInID = id; return }
        if change({ try repository.transaction { $0.selectedID = id } }) { selectedBuiltInID = nil }
    }
    func delete(_ id: UUID) {
        guard !BuiltInCustomFormations.contains(id) else { return }
        if change({ try repository.remove(id) }) {
            do { try CustomFormationProgressStore(repository: repository).remove(id) }
            catch { self.error = "模板已删除，但清理练习进度失败：\(error.localizedDescription)" }
        }
    }
    func practiceSession(for template: CustomFormationTemplate) -> CustomFormationSession? {
        do {
            try template.validateForPractice()
            let store = CustomFormationProgressStore(repository: repository)
            let progress = try store.load(for: template)
            return .init(template: template, editing: false, progress: progress, progressStore: store)
        } catch { self.error = "无法开始练习：\(error.localizedDescription)"; return nil }
    }
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
