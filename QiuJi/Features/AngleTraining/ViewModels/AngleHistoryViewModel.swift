import Foundation
import SwiftData

@MainActor
final class AngleHistoryViewModel: ObservableObject {

    // MARK: - Published

    @Published var allResults: [AngleTestResult] = []
    @Published var overallTrend: [TrendPoint] = []
    @Published var cornerTrend:  [TrendPoint] = []
    @Published var sideTrend:    [TrendPoint] = []

    struct TrendPoint: Identifiable {
        let id: Int
        let groupIndex: Int
        let averageError: Double
    }

    // MARK: - Computed stats

    var totalQuestions: Int { allResults.count }

    var overallAverageError: Double {
        guard !allResults.isEmpty else { return 0 }
        return allResults.map(\.error).reduce(0, +) / Double(allResults.count)
    }

    var accurateRate: Double {
        guard !allResults.isEmpty else { return 0 }
        return Double(allResults.filter { $0.error <= 3 }.count) / Double(allResults.count)
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
            buildTrends(from: results)
        } catch { /* silently degrade */ }
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
}
