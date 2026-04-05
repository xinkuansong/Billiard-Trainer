import Foundation
import SwiftData

enum AngleTimeRange: String, CaseIterable, Hashable {
    case week = "本周"
    case month = "本月"
    case all = "全部"
}

@MainActor
final class AngleHistoryViewModel: ObservableObject {

    // MARK: - Published

    @Published var allResults: [AngleTestResult] = []
    @Published var timeRange: AngleTimeRange = .all {
        didSet { applyTimeFilter() }
    }
    @Published private(set) var filteredResults: [AngleTestResult] = []
    @Published var overallTrend: [TrendPoint] = []
    @Published var cornerTrend:  [TrendPoint] = []
    @Published var sideTrend:    [TrendPoint] = []
    @Published var rangeStats:   [RangeStat] = []

    struct TrendPoint: Identifiable {
        let id: Int
        let groupIndex: Int
        let averageError: Double
    }

    struct RangeStat: Identifiable {
        let id: Int
        let label: String
        let accurateRate: Double
    }

    // MARK: - Computed stats

    var totalQuestions: Int { filteredResults.count }

    var overallAverageError: Double {
        guard !filteredResults.isEmpty else { return 0 }
        return filteredResults.map(\.error).reduce(0, +) / Double(filteredResults.count)
    }

    var bestScore: Double {
        filteredResults.map(\.error).min() ?? 0
    }

    var accurateRate: Double {
        guard !filteredResults.isEmpty else { return 0 }
        return Double(filteredResults.filter { $0.error <= 3 }.count) / Double(filteredResults.count)
    }

    // MARK: - Repository

    private var repository: AngleTestRepositoryProtocol?

    func configure(context: ModelContext) {
        repository = LocalAngleTestRepository(context: context)
    }

    func loadData() async {
        guard let repository else { return }
        do {
            let results = try await repository.fetchAll()
            allResults = results
            applyTimeFilter()
        } catch { /* silently degrade */ }
    }

    private func applyTimeFilter() {
        let cutoff: Date?
        switch timeRange {
        case .week:
            cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now)
        case .month:
            cutoff = Calendar.current.date(byAdding: .month, value: -1, to: .now)
        case .all:
            cutoff = nil
        }
        if let cutoff {
            filteredResults = allResults.filter { $0.date >= cutoff }
        } else {
            filteredResults = allResults
        }
        buildTrends(from: filteredResults)
        buildRangeStats(from: filteredResults)
    }

    // MARK: - Trend calculation

    private func buildTrends(from results: [AngleTestResult]) {
        let sorted = results.sorted { $0.date < $1.date }
        overallTrend = grouped(sorted)
        cornerTrend  = grouped(sorted.filter { $0.pocketType == PocketType.corner.rawValue })
        sideTrend    = grouped(sorted.filter { $0.pocketType == PocketType.side.rawValue })
    }

    private func grouped(_ results: [AngleTestResult], size: Int = 5) -> [TrendPoint] {
        guard !results.isEmpty else { return [] }
        var pts: [TrendPoint] = []
        var i = 0
        while i < results.count {
            let end = min(i + size, results.count)
            let avg = results[i..<end].map(\.error).reduce(0, +) / Double(end - i)
            pts.append(TrendPoint(id: pts.count, groupIndex: pts.count + 1, averageError: avg))
            i = end
        }
        return pts
    }

    // MARK: - Range analysis

    private static let ranges: [(label: String, low: Double, high: Double)] = [
        ("0° - 15°", 0, 15),
        ("15° - 30°", 15, 30),
        ("30° - 45°", 30, 45),
        ("45° - 60°", 45, 60),
        ("60° - 75°", 60, 75),
        ("75° - 90°", 75, 90),
    ]

    private func buildRangeStats(from results: [AngleTestResult]) {
        rangeStats = Self.ranges.enumerated().map { idx, range in
            let inRange = results.filter { $0.actualAngle >= range.low && $0.actualAngle < range.high }
            let rate: Double
            if inRange.isEmpty {
                rate = 0
            } else {
                rate = Double(inRange.filter { $0.error <= 3 }.count) / Double(inRange.count)
            }
            return RangeStat(id: idx, label: range.label, accurateRate: rate)
        }
    }
}
