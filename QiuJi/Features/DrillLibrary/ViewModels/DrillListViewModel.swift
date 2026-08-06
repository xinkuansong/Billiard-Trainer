import Foundation
import SwiftData
import Combine
import SwiftUI

enum BallTypeFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case chinese8 = "中式台球"
    case nineBall = "9球"
    case universal = "通用"

    var id: String { rawValue }

    static let displayCases: [BallTypeFilter] = [.all, .chinese8, .nineBall]

    func matches(_ drill: DrillContent) -> Bool {
        switch self {
        case .all:
            return true
        case .chinese8:
            return drill.ballType.contains("chinese8") || drill.ballType.contains("universal")
        case .nineBall:
            return drill.ballType.contains("nineBall") || drill.ballType.contains("universal")
        case .universal:
            return drill.ballType.contains("universal")
        }
    }
}

/// Level chips for the drill library — labels / mapping aligned with Training Tab
/// `PlanLevelFilter`（入门/初级/中级/高级 ≈ L0–L3；高级含 L4）。
enum DrillLevelFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case beginner = "入门"
    case elementary = "初级"
    case intermediate = "中级"
    case advanced = "高级"

    var id: String { rawValue }

    func matches(_ level: String) -> Bool {
        switch self {
        case .all:
            return true
        case .beginner:
            return level == "L0"
        case .elementary:
            return level == "L1"
        case .intermediate:
            return level == "L2"
        case .advanced:
            return level == "L3" || level == "L4"
        }
    }
}

/// Corner-badge filters (E19 → v26 W0): tutorial presence / template kind / completion.
enum DrillBadgeFilter: String, CaseIterable, Identifiable {
    case all = "全部角标"
    case hasTutorial = "有精讲"
    case singleShotTutorial = "单杆技术课"
    case multiShotTutorial = "应用课"
    case rulesetTutorial = "规则流程课"
    case completed = "已完成"

    var id: String { rawValue }

    /// Labels for the search-bar filter Menu (R2).
    var menuLabel: String {
        switch self {
        case .all: return "全部角标"
        case .hasTutorial: return "有精讲"
        case .singleShotTutorial: return DrillTutorialKind.singleShot.filterLabel
        case .multiShotTutorial: return DrillTutorialKind.multiShot.filterLabel
        case .rulesetTutorial: return DrillTutorialKind.ruleset.filterLabel
        case .completed: return "已完成"
        }
    }

    /// Short label kept for tests / accessibility aliases.
    var chipLabel: String { menuLabel }

    func matches(
        _ drill: DrillContent,
        completedIds: Set<String>
    ) -> Bool {
        let kind = DrillTutorialKindResolver.resolve(for: drill)
        switch self {
        case .all:
            return true
        case .hasTutorial:
            return kind != nil
        case .singleShotTutorial:
            return kind == .singleShot
        case .multiShotTutorial:
            return kind == .multiShot
        case .rulesetTutorial:
            return kind == .ruleset
        case .completed:
            return completedIds.contains(drill.id)
        }
    }
}

@MainActor
final class DrillListViewModel: ObservableObject {
    @Published var drillsByCategory: [(category: DrillCategory, drills: [DrillContent])] = []
    @Published var searchText: String = ""
    @Published var ballTypeFilter: BallTypeFilter = .all
    @Published var categoryFilter: DrillCategory? = nil
    @Published var levelFilter: DrillLevelFilter = .all
    @Published var badgeFilter: DrillBadgeFilter = .all
    /// Drill IDs that appear in any persisted `TrainingSession` entry (ever practiced).
    @Published var completedDrillIds: Set<String> = []
    @Published var isLoading = true

    private var allDrills: [DrillContent] = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        let primary = Publishers.CombineLatest3($searchText, $ballTypeFilter, $categoryFilter)
        let secondary = Publishers.CombineLatest3($levelFilter, $badgeFilter, $completedDrillIds)
        primary.combineLatest(secondary)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }

    func loadDrills() async {
        isLoading = true
        let service = DrillContentService.shared
        let drills = await service.loadFallbackDrills()
        allDrills = drills
        applyFilters()
        // F-ST-03: drive the opacity transition declared on DrillListView.
        withAnimation(BTMotion.easeFast) {
            isLoading = false
        }
    }

    func updateCompletedDrillIds(_ ids: Set<String>) {
        guard ids != completedDrillIds else { return }
        completedDrillIds = ids
        applyFilters()
    }

    #if DEBUG
    func applyFiltersSync() { applyFilters() }
    #endif

    private func applyFilters() {
        var filtered = allDrills

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter {
                $0.nameZh.lowercased().contains(query) ||
                $0.nameEn.lowercased().contains(query)
            }
        }

        filtered = filtered.filter { ballTypeFilter.matches($0) }

        if let categoryFilter {
            filtered = filtered.filter { $0.category == categoryFilter.rawValue }
        }

        if levelFilter != .all {
            filtered = filtered.filter { levelFilter.matches($0.level) }
        }

        if badgeFilter != .all {
            let completed = completedDrillIds
            filtered = filtered.filter { badgeFilter.matches($0, completedIds: completed) }
        }

        let grouped = Dictionary(grouping: filtered) { $0.category }

        drillsByCategory = DrillCategory.allCases.compactMap { cat in
            guard let drills = grouped[cat.rawValue], !drills.isEmpty else { return nil }
            return (category: cat, drills: drills)
        }
    }
}
