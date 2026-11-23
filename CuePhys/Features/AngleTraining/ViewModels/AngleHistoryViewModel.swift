import Foundation
import SwiftData

enum AngleTimeRange: String, CaseIterable, Hashable {
    case week = "本周"
    case month = "本月"
    case all = "全部"
}

enum AngleQuizTypeFilter: String, CaseIterable, Hashable {
    case all, geometric, table2D, scene2D, scene3D, aimPoint, aimPoint2D, aimPoint3D

    var queryValue: String? { self == .all ? nil : rawValue }

    var title: String {
        guard let queryValue else { return "全部" }
        return AngleQuizType(rawValue: queryValue).displayNameZh
    }
}

@MainActor
final class AngleHistoryViewModel: ObservableObject {

    // MARK: - Published

    @Published var cohortSelection: String? { didSet { applyFilters() } }
    @Published private(set) var availableCohorts: [String] = []
    var unit: String { filteredResults.first?.measurementUnit ?? "°" }
    var validSampleCount: Int { filteredResults.compactMap(\.measurementError).count }
    var invalidCount: Int { filteredResults.count - validSampleCount }
    @Published var allResults: [AngleTestResult] = []
    @Published var timeRange: AngleTimeRange = .all {
        didSet { applyFilters() }
    }
    @Published var quizTypeFilter: AngleQuizTypeFilter = .all {
        didSet { applyFilters() }
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
        var sampleCount: Int? = nil
        var meanError: Double? = nil
    }

    // MARK: - Computed stats

    var totalQuestions: Int { filteredResults.count }

    var overallAverageError: Double {
        guard !filteredResults.isEmpty else { return 0 }
        let values = filteredResults.compactMap(\.measurementError)
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    var bestScore: Double {
        filteredResults.compactMap(\.measurementError).min() ?? 0
    }

    var accurateRate: Double {
        guard !filteredResults.isEmpty else { return 0 }
        return Double(filteredResults.filter { ($0.measurementError ?? .infinity) <= $0.measurementThreshold }.count) / Double(filteredResults.count)
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
            applyFilters()
        } catch { /* silently degrade */ }
    }

    private func applyFilters() {
        var results = allResults

        // Time filter
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
            results = results.filter { $0.date >= cutoff }
        }

        // Quiz type filter
        if let queryValue = quizTypeFilter.queryValue {
            if queryValue == "table2D" {
                // Backward compatible: old data without quizType shows under "球台 2D"
                results = results.filter { $0.quizType == "table2D" }
            } else {
                results = results.filter { $0.quizType == queryValue }
            }
        }

        results = results.filter(\.isFirstAnswer)
        availableCohorts = Array(Set(results.map(\.cohort))).sorted()
        let selected = cohortSelection.flatMap { availableCohorts.contains($0) ? $0 : nil }
            ?? results.sorted { $0.date > $1.date }.first?.cohort
        filteredResults = results.filter { $0.cohort == selected && $0.isFirstAnswer }
        buildTrends(from: filteredResults)
        buildRangeStats(from: filteredResults)
    }

    // MARK: - Trend calculation

    private func buildTrends(from results: [AngleTestResult]) {
        let sorted = results.filter { $0.measurementError != nil }.sorted { $0.date < $1.date }
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
            let avg = results[i..<end].compactMap(\.measurementError).reduce(0, +) / Double(end - i)
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

    private func meanError(_ results: [AngleTestResult]) -> Double? {
        let errors = results.compactMap(\.measurementError).filter { $0.isFinite }.map(abs)
        return errors.isEmpty ? nil : errors.reduce(0,+) / Double(errors.count)
    }

    private func buildRangeStats(from results: [AngleTestResult]) {
        if results.first?.trainingMetadata != nil {
            rangeStats = SceneTrainingConfiguration.AngleRange.allCases.filter { $0 != .mixed }.enumerated().map { idx, range in
                // Formal cut angles can exceed the construction grid's 85° ceiling.
                let degrees = range == .thin ? 71...90 : range.degrees
                let samples = results.filter { degrees.contains(Int(($0.trainingMetadata?.angle ?? $0.actualAngle).rounded())) }
                let rate = samples.isEmpty ? 0 : Double(samples.filter { ($0.measurementError ?? .infinity) <= $0.measurementThreshold }.count) / Double(samples.count)
                return RangeStat(id:idx,label:range == .thin ? "极薄球 · 71–90°" : range.label,accurateRate:rate,sampleCount:samples.count,meanError:meanError(samples))
            }
            return
        }
        rangeStats = Self.ranges.enumerated().map { idx, range in
            let inRange = results.filter { ($0.trainingMetadata?.angle ?? $0.actualAngle) >= range.low && (($0.trainingMetadata?.angle ?? $0.actualAngle) < range.high || (range.high == 90 && ($0.trainingMetadata?.angle ?? $0.actualAngle) == 90)) }
            let rate: Double
            if inRange.isEmpty {
                rate = 0
            } else {
                rate = Double(inRange.filter { ($0.measurementError ?? .infinity) <= $0.measurementThreshold }.count) / Double(inRange.count)
            }
            return RangeStat(id: idx, label: range.label, accurateRate: rate, sampleCount: inRange.count, meanError: meanError(inRange))
        }
    }
}
