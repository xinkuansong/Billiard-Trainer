import Foundation

// MARK: - Window-relative individual controls (v2)

enum FreeControlLayoutMode: String, Codable, CaseIterable {
    case twoD, threeD
    var title: String { self == .twoD ? "2D" : "3D" }
}

/// Window-normalized center, top-left origin, +x right/+y down. Values are not clamped to the safe area.
struct FreeControlPlacement: Codable, Equatable {
    var x: Double
    var y: Double
    var scale: Double = 1
    func validate() throws {
        guard x.isFinite, y.isFinite, scale.isFinite, scale > 0 else {
            throw ControlLayoutError.invalidConfiguration
        }
    }
}

typealias FreeControlValues = [String: FreeControlPlacement]

/// Capacity fallback for opted-in pages after an actual window size change.
/// It never writes back or rescales the saved layout.
enum FreeControlResizeSafety {
    static func needsNativeSlots(values: FreeControlValues, frames: [String: CGRect],
                                 window: CGSize, source: FreeControlWindow?) -> Bool {
        guard !values.isEmpty, window.width > 0, window.height > 0 else { return false }
        // Applied values survive template deletion, so missing provenance must not
        // re-enable a known overlapping placement.
        if let source, abs(window.width-source.width) <= 1 && abs(window.height-source.height) <= 1 { return false }
        let bounds = CGRect(origin: .zero, size: window)
        let actual = frames.map { id, base in
            values[id].map { p in
                CGRect(x: p.x*window.width-base.width*p.scale/2, y: p.y*window.height-base.height*p.scale/2,
                       width: base.width*p.scale, height: base.height*p.scale)
            } ?? base
        }.filter { $0.width > 0 && $0.height > 0 }
        if actual.contains(where: { !bounds.insetBy(dx: -1, dy: -1).contains($0) }) { return true }
        for a in actual.indices {
            for b in actual.indices where b > a {
                let overlap = actual[a].intersection(actual[b])
                if !overlap.isNull && overlap.width > 2 && overlap.height > 2 { return true }
            }
        }
        return false
    }
}

struct FreeControlWindow: Codable, Equatable {
    var width: Double
    var height: Double
}

struct FreeControlLegacyRecord: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var page: String
    var mode: FreeControlLayoutMode
    var domain: ControlLayoutDomain
    var templateID: UUID?
    var detail: String
}

/// Includes legitimate controls in other stages, independently of current visibility.
enum FreeControlCatalog {
    static func ids(page: TablePreferencePage, mode: FreeControlLayoutMode) -> Set<String> {
        var ids: Set<String>
        switch page {
        case .dailyClearance, .freePlay:
            ids = ["shot.undo", "shot.replay", "shot.aim", "shot.spin", "shot.power", "shot.strike",
                   "break.entry", "break.rerack", "break.strike"]
        case .silu, .planThree:
            ids = ["shot.undo", "shot.replay", "shot.aim", "shot.spin", "shot.power", "shot.strike",
                   "break.rerack", "break.strike", "break.confirm", "planning.constraintTool",
                   "planning.clearConstraint", "planning.solve", "planning.nextSolution"]
            if page == .planThree { ids.insert("planning.roles") }
        case .snookerTactics:
            ids = ["shot.undo", "shot.replay", "shot.spin", "shot.power", "shot.strike",
                   "defense.targetTool", "defense.clearSelection", "planning.solve", "planning.nextSolution"]
        case .bankShot, .diamondSystem:
            ids = ["shot.undo", "shot.replay", "shot.aim", "shot.spin", "shot.power", "shot.strike",
                   "solver.mode", "solver.cushions", "planning.nextSolution"]
        case .sceneAiming2D, .sceneAiming3D:
            guard (page == .sceneAiming2D) == (mode == .twoD) else { return [] }
            ids = Set((0...9).map { "angle.digit." + String($0) })
            ids.formUnion(["angle.erase", "angle.submit", "angle.cancel", "angle.assist", "angle.answer", "angle.next"])
        case .aimPointScene2D, .aimPointScene3D:
            guard (page == .aimPointScene2D) == (mode == .twoD) else { return [] }
            ids = ["shot.aim", "aimPoint.hint", "aimPoint.submit", "aimPoint.next"]
        case .separationPractice2D, .separationPractice3D:
            guard (page == .separationPractice2D) == (mode == .twoD) else { return [] }
            ids = ["shot.spin", "shot.power", "shot.strike", "shot.undo", "shot.replay"]
        case .accuracy2D, .accuracy3D:
            guard (page == .accuracy2D) == (mode == .twoD) else { return [] }
            ids = ["shot.aim", "shot.spin", "shot.power", "shot.strike", "shot.replay"]
        case .customFormationPractice:
            ids = ["shot.undo", "shot.aim", "shot.spin", "shot.power", "shot.strike", "formation.restart"]
        case .customFormationEditor:
            guard mode == .twoD else { return [] }
            ids = ["formation.tool.line", "formation.tool.distance", "formation.tool.angle",
                   "formation.edit.undo", "formation.edit.redo", "formation.edit.clearMeasure", "formation.edit.finish",
                   "formation.edit.sort", "formation.edit.delete", "formation.edit.deleteLine", "formation.edit.save",
                   "formation.nudge.up", "formation.nudge.down", "formation.nudge.left", "formation.nudge.right"]
        case .angleDynamic:
            ids = [] // Readouts are fixed; only the real 3D camera controls are editable.
        case .separationAngleAtlas, .cushionEnglishAtlas:
            let legend = page == .separationAngleAtlas ? "separation.legend." : "cushion.legend."
            ids = Set((0..<8).map { legend + String($0) })
            ids.formUnion(["shot.spin", "shot.power"])
        case .shotSimulation:
            ids = ["shot.undo", "shot.replay", "shot.aim", "shot.spin", "shot.power", "shot.strike"]
        case .composer:
            ids = ["shot.undo", "shot.replay", "shot.aim", "shot.spin", "shot.power", "shot.strike",
                   "break.entry", "break.rerack", "break.strike"]
        case .snakePractice:
            ids = ["shot.undo", "shot.replay", "shot.aim", "shot.spin", "shot.power", "shot.strike",
                   "snake.restart", "snake.next"]
        case .drillTryout:
            ids = ["shot.aim", "shot.spin", "shot.power", "shot.strike", "tryout.previous", "tryout.next",
                   "tryout.rearrange", "tryout.retry", "sequence.play"]
        default: return []
        }
        if mode == .threeD {
            ids.formUnion(["camera.overview", "camera.thirdPerson", "camera.firstPerson", "camera.temporaryTopDown"])
        }
        return ids
    }
}

struct FreeControlTemplate: Codable, Equatable, Identifiable {
    var id: UUID
    var baseName: String
    var mode: FreeControlLayoutMode
    var sourcePage: String
    var createdAt: Date = Date()
    var values: FreeControlValues
    var sourceWindow: FreeControlWindow?
    var sourceTemplateID: UUID?
    var pinnedAt: Date?
    var displayName: String { "\(Self.userName(baseName)) · \(mode.title)" }

    static func userName(_ input: String) -> String {
        var result = input.trimmingCharacters(in: .whitespacesAndNewlines)
        while let suffix = [" · 2D", " · 3D"].first(where: { result.hasSuffix($0) }) {
            result = String(result.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if result == "· 2D" || result == "· 3D" { result = "" }
        return result
    }

    func merging(into current: FreeControlValues, page: TablePreferencePage,
                 mode targetMode: FreeControlLayoutMode) throws -> FreeControlValues {
        guard mode == targetMode else { throw ControlLayoutError.modeMismatch }
        let shared = values.filter { FreeControlCatalog.ids(page: page, mode: targetMode).contains($0.key) }
        guard !shared.isEmpty else { throw ControlLayoutError.noCommonControls }
        return current.merging(shared) { _, source in source }
    }
}

struct FreeControlArchive: Codable, Equatable {
    var schemaVersion = 2
    var revision: UInt64 = 0
    var templates: [FreeControlTemplate] = []
    /// Applied values are independent snapshots; deleting a template cannot change them.
    var pages: [String: FreeControlValues] = [:]
    // Optional for archives produced before page-scoped conflict detection was added.
    var pageRevisions: [String: UInt64]?
    var pageSources: [String: UUID]?
    var legacyRecords: [String: FreeControlLegacyRecord]?
    var legacyBackups: [String]?
    var legacyImportDisabled: Bool?

    func pageRevision(_ key: String) -> UInt64 { pageRevisions?[key] ?? 0 }
    mutating func changedPage(_ key: String, source: UUID?) throws {
        let previous = pageRevision(key)
        guard previous < UInt64.max else { throw ControlLayoutError.invalidConfiguration }
        if pageRevisions == nil { pageRevisions = [:] }
        if pageSources == nil { pageSources = [:] }
        pageRevisions?[key] = previous + 1
        pageSources?[key] = source
    }

    static func key(page: TablePreferencePage, mode: FreeControlLayoutMode) -> String {
        "\(page.rawValue):\(mode.rawValue)"
    }
    func validate() throws {
        guard schemaVersion == 2 else { throw ControlLayoutError.unsupportedVersion(schemaVersion) }
        guard Set(templates.map(\.id)).count == templates.count else { throw ControlLayoutError.duplicateTemplate }
        for template in templates {
            guard !template.baseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ControlLayoutError.invalidConfiguration
            }
            for value in template.values.values { try value.validate() }
            if let window = template.sourceWindow {
                guard window.width.isFinite, window.height.isFinite, window.width > 0, window.height > 0 else {
                    throw ControlLayoutError.invalidConfiguration
                }
            }
        }
        for page in pages.values { for value in page.values { try value.validate() } }
    }
}

enum ControlLayoutFamily: String, CaseIterable, Codable {
    case shot, planning, teaching, angleQuiz, aimPointQuiz
}

extension TablePreferencePage {
    /// One page-local editor for every interactive table page.
    var usesFreeControlLayout: Bool { supportsControlLayoutEditing }
    var supportsControlLayoutEditing: Bool {
        self != .drillDetailPreview && self != .drillRecordPreview
    }
    var fixedControlLayoutMode: ControlLayoutLayer? {
        switch self {
        case .sceneAiming2D, .aimPointScene2D, .accuracy2D, .separationPractice2D, .customFormationEditor: return .twoD
        case .sceneAiming3D, .aimPointScene3D, .accuracy3D, .separationPractice3D: return .threeD
        default: return nil
        }
    }
    var controlLayoutFamily: ControlLayoutFamily? {
        switch self {
        case .dailyClearance, .freePlay, .shotSimulation, .snakePractice, .composer, .drillTryout, .accuracy2D, .accuracy3D, .separationPractice2D, .separationPractice3D: return .shot
        case .silu, .planThree, .snookerTactics, .bankShot, .diamondSystem: return .planning
        case .angleDynamic, .separationAngleAtlas, .cushionEnglishAtlas: return .teaching
        case .sceneAiming2D, .sceneAiming3D: return .angleQuiz
        case .aimPointScene2D, .aimPointScene3D: return .aimPointQuiz
        case .customFormationPractice, .customFormationEditor, .drillDetailPreview, .drillRecordPreview: return nil
        }
    }
}

enum ControlLayoutDomain: String, CaseIterable, Codable { case phoneLandscape, padLandscape, padPortrait }
enum ControlLayoutLayer: String, CaseIterable, Codable { case common, twoD, threeD }
enum ControlLayoutGroup: String, CaseIterable, Codable {
    case direction, instrument, primary, replay, planning, camera, information, keyboard
}
enum ControlLayoutProperty: String, CaseIterable, Codable { case lane, offset, order, size, cameraSlot }
enum ControlLayoutLane: String, Codable { case leading, trailing }
enum ControlLayoutSize: String, CaseIterable, Codable { case automatic, compact, regular }
enum ControlLayoutCameraSlot: String, Codable { case automatic, mirrored }

/// Intent only. No rendered frames, camera poses, or training parameters enter this archive.
struct ControlLayoutAddress: Hashable, Codable {
    var domain: ControlLayoutDomain
    var layer: ControlLayoutLayer
    var group: ControlLayoutGroup
    var property: ControlLayoutProperty
}

enum ControlLayoutValue: Equatable, Codable {
    case lane(ControlLayoutLane)
    /// Logical points within a declared column; the placement layer limits actual travel.
    case offset(Double)
    case order(Int)
    case size(ControlLayoutSize)
    case cameraSlot(ControlLayoutCameraSlot)

    func validate(at address: ControlLayoutAddress) throws {
        let valid: Bool
        switch (address.property, self) {
        case (.lane, .lane): valid = address.group != .camera
        case (.offset, .offset(let value)): valid = address.group != .camera && value.isFinite && abs(value) <= 2048
        case (.order, .order(let value)): valid = address.group != .camera && (0..<ControlLayoutGroup.allCases.count).contains(value)
        case (.size, .size(let value)):
            valid = value == .automatic || [.direction, .replay].contains(address.group)
        case (.cameraSlot, .cameraSlot): valid = address.group == .camera
        default: valid = false
        }
        guard valid else { throw ControlLayoutError.invalidConfiguration }
    }
}

typealias ControlLayoutPatch = [ControlLayoutAddress: ControlLayoutValue]

struct ControlLayoutTemplate: Identifiable, Equatable, Codable {
    var id: UUID
    var name: String
    var revision: UInt64 = 1
    var baselineVersion: Int = 1
    var sourceID: UUID?
    var values: ControlLayoutPatch = [:]
}

enum ControlLayoutSelection: Equatable, Codable {
    case familyDefault
    case builtIn
    case template(UUID)
}

struct ControlLayoutBinding: Equatable, Codable {
    var selection: ControlLayoutSelection = .familyDefault
    var overrides: ControlLayoutPatch = [:]
}

struct ControlLayoutArchive: Equatable, Codable {
    var schemaVersion = 1
    var revision: UInt64 = 0
    var templates: [UUID: ControlLayoutTemplate] = [:]
    var bindings: [TablePreferencePage: ControlLayoutBinding] = [:]
    var familyDefaults: [ControlLayoutFamily: UUID] = [:]

    func templateID(for page: TablePreferencePage) -> UUID? {
        switch bindings[page]?.selection ?? .familyDefault {
        case .builtIn: return nil
        case .template(let id): return id
        case .familyDefault: return page.controlLayoutFamily.flatMap { familyDefaults[$0] }
        }
    }

    func validate() throws {
        guard schemaVersion == 1 else { throw ControlLayoutError.unsupportedVersion(schemaVersion) }
        guard revision < UInt64.max else { throw ControlLayoutError.invalidConfiguration }
        for (id, template) in templates {
            guard id == template.id, template.revision > 0, template.revision < UInt64.max,
                  template.baselineVersion == 1,
                  !template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  template.name.count <= 80 else { throw ControlLayoutError.invalidConfiguration }
            try Self.validate(template.values)
        }
        for binding in bindings.values {
            if case .template(let id) = binding.selection, templates[id] == nil { throw ControlLayoutError.missingTemplate }
            try Self.validate(binding.overrides)
        }
        guard familyDefaults.values.allSatisfy({ templates[$0] != nil }) else { throw ControlLayoutError.missingTemplate }
    }

    static func validate(_ patch: ControlLayoutPatch) throws {
        for (address, value) in patch { try value.validate(at: address) }
    }
}

struct ControlLayoutResolved: Equatable {
    var values: [ControlLayoutGroup: [ControlLayoutProperty: ControlLayoutValue]] = [:]
    var overridden: Set<ControlLayoutAddress> = []
    var inactive: Set<ControlLayoutAddress> = []
    subscript(_ group: ControlLayoutGroup, _ property: ControlLayoutProperty) -> ControlLayoutValue? {
        values[group]?[property]
    }
}

enum ControlLayoutResolver {
    static func resolve(_ archive: ControlLayoutArchive, page: TablePreferencePage,
                        domain: ControlLayoutDomain, mode: ControlLayoutLayer,
                        capabilities: Set<ControlLayoutGroup>) -> ControlLayoutResolved {
        guard page.controlLayoutFamily != nil else { return ControlLayoutResolved() }
        let template = archive.templateID(for: page).flatMap { archive.templates[$0] }?.values ?? [:]
        let overrides = archive.bindings[page]?.overrides ?? [:]
        var result = ControlLayoutResolved()
        for (patch, local) in [(template, false), (overrides, true)] {
            for layer in mode == .common ? [.common] : [.common, mode] {
                for (address, value) in patch where address.domain == domain && address.layer == layer {
                    guard capabilities.contains(address.group) else { result.inactive.insert(address); continue }
                    result.values[address.group, default: [:]][address.property] = value
                    if local { result.overridden.insert(address) }
                }
            }
        }
        return result
    }
}

enum ControlLayoutError: Error, LocalizedError, Equatable {
    case invalidConfiguration, unsupportedVersion(Int), missingTemplate, unsupportedPage, conflict, recoveryRequired, duplicateTemplate
    case modeMismatch, noCommonControls
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: return "布局配置无效，请检查名称和调整范围。"
        case .unsupportedVersion: return "布局来自更新版本，原始配置已保留。请升级应用或备份后恢复默认。"
        case .missingTemplate: return "引用的模板不存在，请重新载入。"
        case .unsupportedPage: return "此页面尚未支持操作布局。"
        case .conflict: return "布局已在另一处更新。请重新载入，或将草稿另存为新模板。"
        case .recoveryRequired: return "布局归档暂时无法读取。原始文件已保留，请重试读取或备份后恢复默认。"
        case .duplicateTemplate: return "此模板已保存，请重新载入。"
        case .modeMismatch: return "请在模板对应的 2D 或 3D 模式下使用。"
        case .noCommonControls: return "当前页面没有可应用的按键。"
        }
    }
}
