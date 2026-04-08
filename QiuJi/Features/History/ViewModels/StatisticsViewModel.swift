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

struct DurationBarData: Identifiable {
    let id = UUID()
    let label: String
    let date: Date
    let hours: Double
}

struct SuccessRateBarData: Identifiable {
    let id = UUID()
    let label: String
    let date: Date
    let rate: Double
}

struct CategoryComparisonData: Identifiable {
    let id: String
    let nameZh: String
    let currentValue: Double
    let previousValue: Double
    let changePercent: Double
    let isNew: Bool
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

    var categoryMapping: [String: String] = [:]

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

    private var previousPeriodSessions: [TrainingSession] {
        let cal = Calendar.current
        let now = Date()
        let currentStart: Date
        let prevStart: Date
        switch timeRange {
        case .week:
            currentStart = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
            prevStart = cal.date(byAdding: .day, value: -13, to: cal.startOfDay(for: now)) ?? now
        case .month:
            currentStart = cal.date(byAdding: .month, value: -1, to: cal.startOfDay(for: now)) ?? now
            prevStart = cal.date(byAdding: .month, value: -2, to: cal.startOfDay(for: now)) ?? now
        case .year:
            currentStart = cal.date(byAdding: .year, value: -1, to: cal.startOfDay(for: now)) ?? now
            prevStart = cal.date(byAdding: .year, value: -2, to: cal.startOfDay(for: now)) ?? now
        }
        return sessions.filter { $0.date >= prevStart && $0.date < currentStart }
    }

    // MARK: - Overview: Training Days

    var trainingDays: Int {
        Set(filteredSessions.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    var trainingDaysBreakdown: [(category: String, days: Int)] {
        var catDays: [String: Set<Date>] = [:]
        for session in filteredSessions {
            let day = Calendar.current.startOfDay(for: session.date)
            let cat = primaryCategory(for: session)
            catDays[cat, default: []].insert(day)
        }
        let mapped: [(category: String, days: Int)] = catDays.map { key, value in
            let name = DrillCategory(rawValue: key)?.shortNameZh ?? key
            return (category: name, days: value.count)
        }
        return Array(mapped.sorted { $0.days > $1.days }.prefix(3))
    }

    // MARK: - Duration

    var totalDurationMinutes: Int {
        filteredSessions.reduce(0) { $0 + $1.totalDurationMinutes }
    }

    var averageDurationHoursPerPeriod: Double {
        let mins = Double(totalDurationMinutes)
        switch timeRange {
        case .week:  return mins / 60.0
        case .month: return mins / (60.0 * 4.0)
        case .year:  return mins / (60.0 * 52.0)
        }
    }

    var formattedDuration: String {
        let hours = totalDurationMinutes / 60
        let mins = totalDurationMinutes % 60
        if hours > 0 { return "\(hours)h\(mins)m" }
        return "\(mins)m"
    }

    var durationChange: (value: Double, percent: Double) {
        let current = Double(totalDurationMinutes)
        let prev = Double(previousPeriodSessions.reduce(0) { $0 + $1.totalDurationMinutes })
        guard prev > 0 else { return (current / 60.0, 0) }
        let change = (current - prev) / 60.0
        let pct = ((current - prev) / prev) * 100
        return (change, pct)
    }

    var totalSets: Int {
        filteredSessions.reduce(0) { sum, session in
            sum + session.drillEntries.reduce(0) { $0 + $1.sets.count }
        }
    }

    // MARK: - Success Rate

    var overallSuccessRate: Double {
        let totalMade = filteredSessions.flatMap(\.drillEntries).flatMap(\.sets).reduce(0) { $0 + $1.madeBalls }
        let totalTarget = filteredSessions.flatMap(\.drillEntries).flatMap(\.sets).reduce(0) { $0 + $1.targetBalls }
        guard totalTarget > 0 else { return 0 }
        return Double(totalMade) / Double(totalTarget)
    }

    var successRateChange: (value: Double, percent: Double) {
        let prevMade = previousPeriodSessions.flatMap(\.drillEntries).flatMap(\.sets).reduce(0) { $0 + $1.madeBalls }
        let prevTarget = previousPeriodSessions.flatMap(\.drillEntries).flatMap(\.sets).reduce(0) { $0 + $1.targetBalls }
        let prevRate = prevTarget > 0 ? Double(prevMade) / Double(prevTarget) : 0
        let curRate = overallSuccessRate
        let change = (curRate - prevRate) * 100
        let pct = prevRate > 0 ? ((curRate - prevRate) / prevRate) * 100 : 0
        return (change, pct)
    }

    // MARK: - Duration Bar Chart Data

    var durationBarData: [DurationBarData] {
        let cal = Calendar.current
        let now = Date()

        switch timeRange {
        case .week:
            return (0..<7).reversed().map { offset in
                let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: now))!
                let dayEnd = cal.date(byAdding: .day, value: 1, to: day)!
                let mins = filteredSessions.filter { $0.date >= day && $0.date < dayEnd }
                    .reduce(0) { $0 + $1.totalDurationMinutes }
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "zh_CN")
                fmt.dateFormat = "E"
                return DurationBarData(label: fmt.string(from: day), date: day, hours: Double(mins) / 60.0)
            }
        case .month:
            return (0..<4).reversed().map { weekOffset in
                let weekEnd = cal.date(byAdding: .day, value: -weekOffset * 7, to: cal.startOfDay(for: now))!
                let weekStart = cal.date(byAdding: .day, value: -6, to: weekEnd)!
                let weekEndNext = cal.date(byAdding: .day, value: 1, to: weekEnd)!
                let mins = filteredSessions.filter { $0.date >= weekStart && $0.date < weekEndNext }
                    .reduce(0) { $0 + $1.totalDurationMinutes }
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "zh_CN")
                fmt.dateFormat = "M/d"
                return DurationBarData(label: fmt.string(from: weekStart), date: weekStart, hours: Double(mins) / 60.0)
            }
        case .year:
            return (0..<12).reversed().map { monthOffset in
                let month = cal.date(byAdding: .month, value: -monthOffset, to: now)!
                let comps = cal.dateComponents([.year, .month], from: month)
                let monthStart = cal.date(from: comps)!
                let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)!
                let mins = filteredSessions.filter { $0.date >= monthStart && $0.date < monthEnd }
                    .reduce(0) { $0 + $1.totalDurationMinutes }
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "zh_CN")
                fmt.dateFormat = "M月"
                return DurationBarData(label: fmt.string(from: month), date: monthStart, hours: Double(mins) / 60.0)
            }
        }
    }

    // MARK: - Success Rate Bar Chart Data

    var successRateBarData: [SuccessRateBarData] {
        let cal = Calendar.current
        let now = Date()

        switch timeRange {
        case .week:
            return (0..<7).reversed().map { offset in
                let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: now))!
                let dayEnd = cal.date(byAdding: .day, value: 1, to: day)!
                let daySessions = filteredSessions.filter { $0.date >= day && $0.date < dayEnd }
                let rate = computeRate(for: daySessions)
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "zh_CN")
                fmt.dateFormat = "E"
                return SuccessRateBarData(label: fmt.string(from: day), date: day, rate: rate)
            }
        case .month:
            return (0..<4).reversed().map { weekOffset in
                let weekEnd = cal.date(byAdding: .day, value: -weekOffset * 7, to: cal.startOfDay(for: now))!
                let weekStart = cal.date(byAdding: .day, value: -6, to: weekEnd)!
                let weekEndNext = cal.date(byAdding: .day, value: 1, to: weekEnd)!
                let weekSessions = filteredSessions.filter { $0.date >= weekStart && $0.date < weekEndNext }
                let rate = computeRate(for: weekSessions)
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "zh_CN")
                fmt.dateFormat = "M/d"
                return SuccessRateBarData(label: fmt.string(from: weekStart), date: weekStart, rate: rate)
            }
        case .year:
            return (0..<12).reversed().map { monthOffset in
                let month = cal.date(byAdding: .month, value: -monthOffset, to: now)!
                let comps = cal.dateComponents([.year, .month], from: month)
                let monthStart = cal.date(from: comps)!
                let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)!
                let monthSessions = filteredSessions.filter { $0.date >= monthStart && $0.date < monthEnd }
                let rate = computeRate(for: monthSessions)
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "zh_CN")
                fmt.dateFormat = "M月"
                return SuccessRateBarData(label: fmt.string(from: month), date: monthStart, rate: rate)
            }
        }
    }

    // MARK: - Category Comparison Grid

    var categoryComparison: [CategoryComparisonData] {
        func buildRates(_ sessions: [TrainingSession]) -> [String: Double] {
            var stats: [String: (made: Int, total: Int)] = [:]
            for session in sessions {
                for entry in session.drillEntries {
                    let cat = categoryForDrill(entry.drillId)
                    let m = entry.sets.reduce(0) { $0 + $1.madeBalls }
                    let t = entry.sets.reduce(0) { $0 + $1.targetBalls }
                    var e = stats[cat, default: (0, 0)]
                    e.made += m
                    e.total += t
                    stats[cat] = e
                }
            }
            return stats.mapValues { $0.total > 0 ? Double($0.made) / Double($0.total) * 100 : 0 }
        }

        let currentRates = buildRates(filteredSessions)
        let prevRates = buildRates(previousPeriodSessions)

        return DrillCategory.allCases.compactMap { cat in
            let current = currentRates[cat.rawValue]
            let prev = prevRates[cat.rawValue]
            guard current != nil || prev != nil else { return nil }
            let cur = current ?? 0
            let prv = prev ?? 0
            let isNew = prev == nil && current != nil
            let change = isNew ? 0 : cur - prv
            return CategoryComparisonData(
                id: cat.rawValue,
                nameZh: cat.shortNameZh,
                currentValue: cur,
                previousValue: prv,
                changePercent: change,
                isNew: isNew
            )
        }
    }

    // MARK: - Category Success Rates (bar chart)

    var categorySuccessRates: [CategorySuccessRate] {
        var categoryStats: [String: (made: Int, total: Int, sets: Int)] = [:]

        for session in filteredSessions {
            for entry in session.drillEntries {
                let totalMade = entry.sets.reduce(0) { $0 + $1.madeBalls }
                let totalTarget = entry.sets.reduce(0) { $0 + $1.targetBalls }
                let cat = categoryForDrill(entry.drillId)
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

    // MARK: - Date Range Label

    var dateRangeLabel: String {
        let cal = Calendar.current
        let now = Date()
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy-MM-dd"

        let start: Date
        switch timeRange {
        case .week:  start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        case .month: start = cal.date(byAdding: .month, value: -1, to: cal.startOfDay(for: now)) ?? now
        case .year:  start = cal.date(byAdding: .year, value: -1, to: cal.startOfDay(for: now)) ?? now
        }
        return "\(fmt.string(from: start)) ~ \(fmt.string(from: now))"
    }

    var periodLabel: String {
        switch timeRange {
        case .week:  return "小时/周"
        case .month: return "小时/月"
        case .year:  return "小时/年"
        }
    }

    var periodCompareLabel: String {
        switch timeRange {
        case .week:  return "环比上周"
        case .month: return "环比上月"
        case .year:  return "环比上年"
        }
    }

    // MARK: - Helpers

    private func primaryCategory(for session: TrainingSession) -> String {
        var counts: [String: Int] = [:]
        for entry in session.drillEntries {
            let cat = categoryForDrill(entry.drillId)
            counts[cat, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? "combined"
    }

    private func categoryForDrill(_ drillId: String) -> String {
        categoryMapping[drillId] ?? "combined"
    }

    private func computeRate(for sessions: [TrainingSession]) -> Double {
        let made = sessions.flatMap(\.drillEntries).flatMap(\.sets).reduce(0) { $0 + $1.madeBalls }
        let target = sessions.flatMap(\.drillEntries).flatMap(\.sets).reduce(0) { $0 + $1.targetBalls }
        guard target > 0 else { return 0 }
        return Double(made) / Double(target)
    }

    // MARK: - Data Loading

    func loadSessions(context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        let drills = await DrillContentService.shared.loadFallbackDrills()
        var map: [String: String] = [:]
        for drill in drills {
            map[drill.id] = drill.category
        }
        categoryMapping = map

        let repo = LocalTrainingSessionRepository(context: context)
        do {
            sessions = try await repo.fetchAll()
        } catch {
            sessions = []
        }
    }
}
