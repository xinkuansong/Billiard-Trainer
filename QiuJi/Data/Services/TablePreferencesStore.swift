import Foundation
import Combine

extension TablePreferencePage {
    var fields: Set<TablePreferenceField> {
        switch self {
        case .multiBallPractice, .multiBallPractice3D: return Set(TablePreferenceField.allCases).subtracting([.view3D])
        case .sceneAiming2D, .sceneAiming3D: return [.grid]
        case .separationPractice2D, .separationPractice3D, .twoBallPractice2D, .twoBallPractice3D, .threeBallPractice2D, .threeBallPractice3D: return [.grid, .transparency]
        case .accuracy2D, .accuracy3D: return [.grid, .transparency, .closeup]
        case .aimPointScene2D, .aimPointScene3D: return [.grid, .closeup]
        case .angleDynamic, .separationAngleAtlas, .cushionEnglishAtlas,
             .drillDetailPreview, .drillRecordPreview: return [.view3D, .grid]
        default: return Set(TablePreferenceField.allCases)
        }
    }
}

enum TablePreferenceField: String, CaseIterable, Codable {
    case view3D, grid, closeup, transparency, trajectory, shows3DTrajectory, separation, rehearsal
    var title: String {
        switch self {
        case .view3D: return "默认视图"
        case .grid: return "台面网格 4×8"
        case .closeup: return "瞄准特写"
        case .transparency: return "打点盘透明度"
        case .trajectory: return "轨迹档位"
        case .shows3DTrajectory: return "3D 显示轨迹"
        case .separation: return "分离角辅助线"
        case .rehearsal: return "运杆演示"
        }
    }
    var initialValue: Double { self == .transparency ? 0.5 : (self == .shows3DTrajectory ? 1 : 0) }
    func validated(_ value: Double) -> Double {
        guard value.isFinite else { return initialValue }
        if self == .transparency { return min(1, max(0, value)) }
        if self == .trajectory { return [0, 1, 2].contains(value) ? value : initialValue }
        return value == 1 ? 1 : 0
    }
}

/// A value snapshot can be held by a scene throughout an active shot. Applying it
/// never loads a board, touches scores, or restarts a physics/playback operation.
struct TablePreferenceSnapshot: Equatable {
    var values: [TablePreferenceField: Double] = [:]
    subscript(_ field: TablePreferenceField) -> Double { values[field] ?? field.initialValue }
    func enabled(_ field: TablePreferenceField) -> Bool { self[field] == 1 }
    var trajectoryDetail: TrajectoryDetail { TrajectoryDetail(rawValue: Int(self[.trajectory])) ?? .full }
}

@MainActor
final class TablePreferencesStore: ObservableObject {
    static let shared = TablePreferencesStore()
    static let storageKey = "tablePreferences.v1"
    private struct Archive: Codable {
        var version = 1
        var general: [String: Double] = [:]
        var pages: [String: [String: Double]] = [:]
    }
    private let defaults: UserDefaults
    private var archive: Archive
    @Published private(set) var revision: UInt64 = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(Archive.self, from: data), saved.version == 1 {
            archive = saved
        } else {
            archive = Self.migrate(defaults)
            persist()
        }
    }

    var general: TablePreferenceSnapshot { snapshot(page: nil) }
    func snapshot(for page: TablePreferencePage) -> TablePreferenceSnapshot { snapshot(page: page) }
    private func snapshot(page: TablePreferencePage?) -> TablePreferenceSnapshot {
        var result = TablePreferenceSnapshot()
        for field in TablePreferenceField.allCases {
            guard page == nil || page!.fields.contains(field) else { continue }
            // Rehearsal is controlled only by My → Settings; ignore legacy page overrides.
            let local = field == .rehearsal ? nil : page.flatMap { archive.pages[$0.rawValue]?[field.rawValue] }
            result.values[field] = field.validated(local ?? archive.general[field.rawValue] ?? field.initialValue)
        }
        return result
    }

    /// Explicit user action: same-value applications intentionally publish too.
    func apply(_ field: TablePreferenceField, value: Double, to page: TablePreferencePage? = nil) {
        guard page == nil || (field != .rehearsal && page!.fields.contains(field)) else { return }
        write(field, value: field.validated(value), page: page)
        if field == .trajectory { write(.shows3DTrajectory, value: 1, page: page) }
        persist()
        revision &+= 1
    }
    func reapply(_ field: TablePreferenceField) { apply(field, value: general[field]) }
    private func write(_ field: TablePreferenceField, value: Double, page: TablePreferencePage?) {
        if let page {
            archive.pages[page.rawValue, default: [:]][field.rawValue] = value
        } else {
            archive.general[field.rawValue] = value
            for page in TablePreferencePage.allCases where page.fields.contains(field) {
                archive.pages[page.rawValue]?[field.rawValue] = nil
            }
        }
    }
    private func persist() {
        guard let data = try? JSONEncoder().encode(archive) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// Read old values once; do not rewrite/delete them or invoke a global action.
    private static func migrate(_ defaults: UserDefaults) -> Archive {
        var result = Archive()
        let globals: [(TablePreferenceField, String)] = [(.grid, "showTableGrid"),
            (.closeup, PracticeStorageKey.showAimCloseup), (.trajectory, "trajectoryDetail"),
            (.separation, "showSeparationAngle"), (.rehearsal, "cueRehearsalEnabled")]
        for (field, key) in globals {
            if let value = defaults.object(forKey: key) as? NSNumber {
                result.general[field.rawValue] = field.validated(value.doubleValue)
            }
        }
        let legacy: [(TablePreferencePage, String, String)] = [
            (.dailyClearance, "dailyClearance.spinDiscTransparency", "dailyClearance.3DTrajectoryHidden"),
            (.freePlay, "freePlay.spinDiscTransparency", "freePlay.3DTrajectoryHidden"),
            (.shotSimulation, "shotSimulation.spinDiscTransparency", "shotSimulation.3DTrajectoryHidden"),
            (.snakePractice, "snakePractice.spinDiscTransparency", "snakePractice.3DTrajectoryHidden"),
            (.composer, "composer.spinDiscTransparency", "composer.3DTrajectoryHidden"),
            (.drillTryout, "composer.spinDiscTransparency", "composer.3DTrajectoryHidden"),
            (.bankShot, "bankKick.spinTransparency", "bankKick.hides3DAssists"),
            (.diamondSystem, "bankKick.spinTransparency", "bankKick.hides3DAssists"),
            (.silu, "silu.spinTransparency", "silu.hides3DAssists"),
            (.planThree, "planthree.spinTransparency", "planthree.hides3DAssists"),
            (.snookerTactics, "snooker.spinTransparency", "snooker.hides3DAssists")]
        for (page, opacity, hidden) in legacy {
            if let value = defaults.object(forKey: opacity) as? NSNumber {
                result.pages[page.rawValue, default: [:]][TablePreferenceField.transparency.rawValue] = TablePreferenceField.transparency.validated(value.doubleValue)
            }
            if let value = defaults.object(forKey: hidden) as? Bool {
                result.pages[page.rawValue, default: [:]][TablePreferenceField.shows3DTrajectory.rawValue] = value ? 0 : 1
            }
        }
        if let view3D = defaults.object(forKey: "snakePractice.view3D") as? Bool {
            result.pages[TablePreferencePage.snakePractice.rawValue, default: [:]][TablePreferenceField.view3D.rawValue] = view3D ? 1 : 0
        }
        return result
    }
}
