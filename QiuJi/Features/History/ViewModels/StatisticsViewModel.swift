import Foundation
import SwiftData

enum StatisticsTimeRange: String, CaseIterable {
    case week = "周"
    case month = "月"
    case year = "年"
}

struct FrequencyDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let date: Date
    let count: Int
}

struct CategorySuccessRate: Identifiable {
    let id: String
    let nameZh: String
    let rate: Double
    let totalSets: Int
}

@MainActor
final class StatisticsViewModel: ObservableObject {

    @Published var timeRange: StatisticsTimeRange = .week
    @Published var sessions: [TrainingSession] = []
    @Published var isLoading = false

    // MARK: - Filtered Sessions

    var filteredSessions: [TrainingSession] {
        let cal = Calendar.current
        let now = Date()
        let start: Date
        switch timeRange {
        case .week:
            start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        case .month:
            start = cal.date(byAdding: .month, value: -1, to: cal.startOfDay(for: now)) ?? now
        case .year:
            start = cal.date(byAdding: .year, value: -1, to: cal.startOfDay(for: now)) ?? now
        }
        return sessions.filter { $0.date >= start }
    }

    // MARK: - Summary Cards

    var trainingDays: Int {
        let days = Set(filteredSessions.map {
            Calendar.current.startOfDay(for: $0.date)
        })
        return days.count
    }

    var totalDurationMinutes: Int {
        filteredSessions.reduce(0) { $0 + $1.totalDurationMinutes }
    }

    var formattedDuration: String {
        let hours = totalDurationMinutes / 60
        let mins = totalDurationMinutes % 60
        if hours > 0 {
            return "\(hours)h\(mins)m"
        }
        return "\(mins)m"
    }

    var totalSets: Int {
        filteredSessions.reduce(0) { sum, session in
            sum + session.drillEntries.reduce(0) { $0 + $1.sets.count }
        }
    }

    // MARK: - Frequency Chart Data

    var frequencyData: [FrequencyDataPoint] {
        let cal = Calendar.current
        let now = Date()

        switch timeRange {
        case .week:
            return (0..<7).reversed().map { offset in
                let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: now))!
                let count = filteredSessions.filter { cal.isDate($0.date, inSameDayAs: day) }.count
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "zh_CN")
                fmt.dateFormat = "E"
                return FrequencyDataPoint(label: fmt.string(from: day), date: day, count: count)
            }
        case .month:
            return (0..<4).reversed().map { weekOffset in
                let weekEnd = cal.date(byAdding: .day, value: -weekOffset * 7, to: cal.startOfDay(for: now))!
                let weekStart = cal.date(byAdding: .day, value: -6, to: weekEnd)!
                let count = filteredSessions.filter { $0.date >= weekStart && $0.date <= cal.date(byAdding: .day, value: 1, to: weekEnd)! }.count
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "zh_CN")
                fmt.dateFormat = "M/d"
                return FrequencyDataPoint(label: fmt.string(from: weekStart), date: weekStart, count: count)
            }
        case .year:
            return (0..<12).reversed().map { monthOffset in
                let month = cal.date(byAdding: .month, value: -monthOffset, to: now)!
                let comps = cal.dateComponents([.year, .month], from: month)
                let monthStart = cal.date(from: comps)!
                let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)!
                let count = filteredSessions.filter { $0.date >= monthStart && $0.date < monthEnd }.count
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "zh_CN")
                fmt.dateFormat = "M月"
                return FrequencyDataPoint(label: fmt.string(from: month), date: monthStart, count: count)
            }
        }
    }

    // MARK: - Category Success Rates

    var categorySuccessRates: [CategorySuccessRate] {
        let drillService = DrillContentService.shared
        var categoryStats: [String: (made: Int, total: Int, sets: Int)] = [:]

        for session in filteredSessions {
            for entry in session.drillEntries {
                let totalMade = entry.sets.reduce(0) { $0 + $1.madeBalls }
                let totalTarget = entry.sets.reduce(0) { $0 + $1.targetBalls }
                let cat = drillIdToCategory(entry.drillId)
                var existing = categoryStats[cat, default: (0, 0, 0)]
                existing.made += totalMade
                existing.total += totalTarget
                existing.sets += entry.sets.count
                categoryStats[cat] = existing
            }
        }

        return DrillCategory.allCases.compactMap { cat in
            guard let stats = categoryStats[cat.rawValue], stats.total > 0 else { return nil }
            return CategorySuccessRate(
                id: cat.rawValue,
                nameZh: cat.nameZh,
                rate: Double(stats.made) / Double(stats.total),
                totalSets: stats.sets
            )
        }.sorted { $0.rate > $1.rate }
    }

    private func drillIdToCategory(_ drillId: String) -> String {
        let knownPrefixes: [(prefix: String, category: String)] = [
            ("drill_c006", "fundamentals"), ("drill_c007", "fundamentals"),
            ("drill_c008", "fundamentals"), ("drill_c009", "fundamentals"),
            ("drill_c010", "fundamentals"), ("drill_c022", "fundamentals"),
            ("drill_c023", "fundamentals"), ("drill_c043", "fundamentals"),
            ("drill_c001", "accuracy"), ("drill_c002", "accuracy"),
            ("drill_c011", "accuracy"), ("drill_c012", "accuracy"),
            ("drill_c013", "accuracy"), ("drill_c033", "accuracy"),
            ("drill_c032", "accuracy"), ("drill_c053", "accuracy"),
            ("drill_c052", "accuracy"), ("drill_c063", "accuracy"),
            ("drill_c062", "accuracy"), ("drill_c072", "accuracy"),
            ("drill_c014", "cueAction"), ("drill_c015", "cueAction"),
            ("drill_c016", "cueAction"), ("drill_c017", "cueAction"),
            ("drill_c018", "cueAction"), ("drill_c019", "cueAction"),
            ("drill_c020", "cueAction"), ("drill_c021", "cueAction"),
        ]

        for entry in knownPrefixes {
            if drillId == entry.prefix { return entry.category }
        }

        if let content = _cachedDrillContents[drillId] {
            return content
        }

        return "combined"
    }

    private var _cachedDrillContents: [String: String] = [:]

    func loadCategoryMapping() async {
        let service = DrillContentService.shared
        let drills = await service.loadFallbackDrills()
        var map: [String: String] = [:]
        for drill in drills {
            map[drill.id] = drill.category
        }
        _cachedDrillContents = map
    }

    // MARK: - Data Loading

    func loadSessions(context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        await loadCategoryMapping()

        let repo = LocalTrainingSessionRepository(context: context)
        do {
            sessions = try await repo.fetchAll()
        } catch {
            sessions = []
        }
    }
}
