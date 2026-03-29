import Foundation
import SwiftData
import Combine

enum BallTypeFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case chinese8 = "中式台球"
    case nineBall = "9球"

    var id: String { rawValue }

    func matches(_ drill: DrillContent) -> Bool {
        switch self {
        case .all:
            return true
        case .chinese8:
            return drill.ballType.contains("chinese8") || drill.ballType.contains("universal")
        case .nineBall:
            return drill.ballType.contains("nineBall") || drill.ballType.contains("universal")
        }
    }
}

@MainActor
final class DrillListViewModel: ObservableObject {
    @Published var drillsByCategory: [(category: DrillCategory, drills: [DrillContent])] = []
    @Published var searchText: String = ""
    @Published var ballTypeFilter: BallTypeFilter = .all
    @Published var isLoading = true

    private var allDrills: [DrillContent] = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        Publishers.CombineLatest($searchText, $ballTypeFilter)
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
        isLoading = false
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
                $0.nameEn.lowercased().contains(query) ||
                $0.description.lowercased().contains(query)
            }
        }

        filtered = filtered.filter { ballTypeFilter.matches($0) }

        let grouped = Dictionary(grouping: filtered) { $0.category }

        drillsByCategory = DrillCategory.allCases.compactMap { cat in
            guard let drills = grouped[cat.rawValue], !drills.isEmpty else { return nil }
            return (category: cat, drills: drills)
        }
    }
}
