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

struct CategoryComparisonData: Identifiable {
    let id: String
    let nameZh: String
    let currentValue: Double
    let previousValue: Double
    let changePercent: Double
    let isNew: Bool
}

/// 一个 drill 分类的成绩聚合（✅ D-v29-2：删全局单一准确率，改按 category 分组）。
///
/// `rate = Σmade / Σtarget`，只在**同一分类内**求和——不同分类的计量单位
/// （球 / 局 / 次）加到同一分母无物理意义（契约 §5.4）。
struct CategorySuccessRate: Identifiable {
    let id: String
    let nameZh: String
    let rate: Double
    let totalSets: Int
    var made: Int = 0
    var target: Int = 0
    /// 该分类各组的 `unitLabel` 快照集合（契约 §5.2）。混单位时如实暴露，不做通分。
    var units: Set<String> = []

    /// "10/14 球"；同分类内若混了多种单位，列出全部而不假装统一。
    var countSummary: String {
        let unit = units.sorted().joined(separator: "/")
        return unit.isEmpty ? "\(made)/\(target)" : "\(made)/\(target) \(unit)"
    }

    var hasMixedUnits: Bool { units.count > 1 }
}

@MainActor
final class StatisticsViewModel: ObservableObject {

    @Published var timeRange: StatisticsTimeRange = .week
    @Published var sessions: [TrainingSession] = []
    @Published var isLoading = false
    /// F-ST-01（统计半条）：失败与空态分流。
    @Published var errorMessage: String?

    var categoryMapping: [String: String] = [:]

    // MARK: - Range Bounds

    private var currentRangeStart: Date {
        let cal = Calendar.current
        let now = Date()
        switch timeRange {
        case .week:  return cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        case .month: return cal.date(byAdding: .month, value: -1, to: cal.startOfDay(for: now)) ?? now
        case .year:  return cal.date(byAdding: .year, value: -1, to: cal.startOfDay(for: now)) ?? now
        }
    }

    private var previousRangeStart: Date {
        let cal = Calendar.current
        let now = Date()
        switch timeRange {
        case .week:  return cal.date(byAdding: .day, value: -13, to: cal.startOfDay(for: now)) ?? now
        case .month: return cal.date(byAdding: .month, value: -2, to: cal.startOfDay(for: now)) ?? now
        case .year:  return cal.date(byAdding: .year, value: -2, to: cal.startOfDay(for: now)) ?? now
        }
    }

    // MARK: - Filtered Sessions（按 kind 分流，契约 §5.3）

    /// **训练量口径** = `drill` + `cognitive`。⛔ `tool` 一律排除：工具使用不是训练量，
    /// 也不计周目标（契约 §5.3 表）。时长 / 天数 / 趋势图都走这一路。
    var filteredSessions: [TrainingSession] {
        let start = currentRangeStart
        return sessions.filter {
            $0.date >= start && TrainingSessionKind.countsTowardGoal($0.kind)
        }
    }

    /// **成绩口径** = 仅 `drill`。cognitive 没有 `DrillEntry`，其成绩在「角度训练」区
    /// 单独展示（契约 §5.3：与 drill 分开展示）；`tool` ⛔ 严禁进入。
    var filteredDrillSessions: [TrainingSession] {
        let start = currentRangeStart
        return sessions.filter {
            $0.date >= start && $0.kind == TrainingSessionKind.drill
        }
    }

    var filteredCognitiveSessions: [TrainingSession] {
        let start = currentRangeStart
        return sessions.filter {
            $0.date >= start && $0.kind == TrainingSessionKind.cognitive
        }
    }

    /// 区间内的工具使用会话。只用于「工具使用」这一条独立展示，⛔ 不进任何聚合。
    var filteredToolSessions: [TrainingSession] {
        let start = currentRangeStart
        return sessions.filter {
            $0.date >= start && $0.kind == TrainingSessionKind.tool
        }
    }

    private var previousPeriodSessions: [TrainingSession] {
        let currentStart = currentRangeStart
        let prevStart = previousRangeStart
        return sessions.filter {
            $0.date >= prevStart && $0.date < currentStart
                && TrainingSessionKind.countsTowardGoal($0.kind)
        }
    }

    private var previousPeriodDrillSessions: [TrainingSession] {
        let currentStart = currentRangeStart
        let prevStart = previousRangeStart
        return sessions.filter {
            $0.date >= prevStart && $0.date < currentStart
                && $0.kind == TrainingSessionKind.drill
        }
    }

    /// 是否有可展示的训练量（drill 或 cognitive）。tool-only 的用户按「无训练数据」处理。
    var hasTrainingSessions: Bool {
        sessions.contains { TrainingSessionKind.countsTowardGoal($0.kind) }
    }

    /// 是否有球台成绩可聚合。无则分类成功率区显示空态而不是一排 0。
    var hasDrillScores: Bool {
        filteredDrillSessions.contains { session in
            session.drillEntries.contains { entry in
                entry.sets.contains { $0.targetBalls > 0 }
            }
        }
    }

    // MARK: - Overview: Training Days

    var trainingDays: Int {
        Set(filteredSessions.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    /// 按 kind 分开的天数（契约 §5.3：drill 与 cognitive 分开展示，tool 单列且不计训练量）。
    var daysByKind: (drill: Int, cognitive: Int, tool: Int) {
        let cal = Calendar.current
        func days(_ list: [TrainingSession]) -> Int {
            Set(list.map { cal.startOfDay(for: $0.date) }).count
        }
        return (days(filteredDrillSessions), days(filteredCognitiveSessions), days(filteredToolSessions))
    }

    /// 按 kind 分开的时长分钟数。`tool` 单列，⛔ 不计入 `totalDurationMinutes`。
    var minutesByKind: (drill: Int, cognitive: Int, tool: Int) {
        (filteredDrillSessions.reduce(0) { $0 + $1.totalDurationMinutes },
         filteredCognitiveSessions.reduce(0) { $0 + $1.totalDurationMinutes },
         filteredToolSessions.reduce(0) { $0 + $1.totalDurationMinutes })
    }

    /// drill 分类的训练天数 Top3。⛔ 只看 `kind="drill"`：cognitive/tool 没有
    /// `DrillEntry`，混进来会被 `primaryCategory` 的兜底全算成「综合」。
    var trainingDaysBreakdown: [(category: String, days: Int)] {
        var catDays: [String: Set<Date>] = [:]
        for session in filteredDrillSessions {
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
        filteredDrillSessions.reduce(0) { sum, session in
            sum + session.drillEntries.reduce(0) { $0 + $1.sets.count }
        }
    }

    // MARK: - Success Rate
    //
    // ✅ D-v29-2（2026-08-06 用户拍板，契约 §5.4）：**统计页不再有全局单一准确率**。
    // 已删除的 `overallSuccessRate` / `successRateChange` / `successRateBarData`
    // 都是「跨全部 session 的单一比率」——把 Ghost Game 的「局」和直线球的「球」
    // 加到同一分母没有物理意义。准确率一律按 category 分组，见
    // `categorySuccessRates` 与 `categoryComparison`。

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

        let currentRates = buildRates(filteredDrillSessions)
        let prevRates = buildRates(previousPeriodDrillSessions)

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

    // MARK: - Category Success Rates（✅ D-v29-2 的唯一准确率口径）

    /// 按 category 分组的成功率：分组内 `Σmade / Σtarget`。
    /// 数据源 ⛔ 只有 `kind="drill"`（`filteredDrillSessions`），`tool` 与 `cognitive` 都不在内。
    /// 单位取 `DrillSet.unitLabel` 快照（契约 §5.2/§6.5），不回查当前内容。
    var categorySuccessRates: [CategorySuccessRate] {
        var categoryStats: [String: (made: Int, total: Int, sets: Int, units: Set<String>)] = [:]

        for session in filteredDrillSessions {
            for entry in session.drillEntries {
                let totalMade = entry.sets.reduce(0) { $0 + $1.madeBalls }
                let totalTarget = entry.sets.reduce(0) { $0 + $1.targetBalls }
                let cat = categoryForDrill(entry.drillId)
                var existing = categoryStats[cat, default: (0, 0, 0, [])]
                existing.made += totalMade
                existing.total += totalTarget
                existing.sets += entry.sets.count
                existing.units.formUnion(entry.sets.map(\.unitLabel))
                categoryStats[cat] = existing
            }
        }

        return DrillCategory.allCases.compactMap { cat in
            guard let stats = categoryStats[cat.rawValue], stats.total > 0 else { return nil }
            return CategorySuccessRate(
                id: cat.rawValue,
                nameZh: cat.nameZh,
                rate: Double(stats.made) / Double(stats.total),
                totalSets: stats.sets,
                made: stats.made,
                target: stats.total,
                units: stats.units
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

    /// drill 归属的分类。⚠️ 这是全仓唯一没有快照字段可用的维度——`DrillEntry`
    /// 里没有 category 快照（加字段属 schema 改动，归 W3 已冻结），故只能按 `drillId`
    /// 查当前内容表。内容删除该 drill 后落到「综合」兜底：**名称与达标线仍走快照**
    /// （契约 §6.5 红线守住），只有分组归属会退化。补 category 快照另立批次。
    private func categoryForDrill(_ drillId: String) -> String {
        categoryMapping[drillId] ?? "combined"
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
            errorMessage = nil
        } catch {
            sessions = []
            errorMessage = "加载统计数据失败"
        }
    }
}
