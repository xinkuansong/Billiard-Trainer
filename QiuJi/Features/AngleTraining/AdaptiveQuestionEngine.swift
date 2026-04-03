import Foundation

/// Weighted question engine – zones with higher average error appear more often.
final class AdaptiveQuestionEngine {

    // MARK: - Zone history

    struct ZoneHistory: Codable {
        var errors: [Double] = []

        var averageError: Double {
            guard !errors.isEmpty else { return 0 }
            return errors.reduce(0, +) / Double(errors.count)
        }

        mutating func addError(_ error: Double) {
            errors.append(error)
            if errors.count > 10 { errors.removeFirst() }
        }
    }

    // MARK: - Angle sets

    /// 5° step: 5, 10, 15 … 85  (17 values for corner)
    static let cornerAngles = Array(stride(from: 5, through: 85, by: 5))
    /// 15, 20, 25 … 60  (10 values for side)
    static let sideAngles   = Array(stride(from: 15, through: 60, by: 5))

    // MARK: - Persisted state

    private(set) var cornerZones: [Int: ZoneHistory]
    private(set) var sideZones:   [Int: ZoneHistory]

    private static let storageKey = "AdaptiveQuestionEngine_v1"

    // MARK: - Init

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let state = try? JSONDecoder().decode(PersistedState.self, from: data) {
            self.cornerZones = state.cornerZones
            self.sideZones   = state.sideZones
        } else {
            self.cornerZones = [:]
            self.sideZones   = [:]
        }
    }

    // MARK: - Selection

    func selectPocketType() -> PocketType {
        Double.random(in: 0..<1) < 0.6 ? .corner : .side
    }

    func selectAngle(for pocketType: PocketType) -> Double {
        let angles: [Int]
        let zones: [Int: ZoneHistory]
        switch pocketType {
        case .corner: angles = Self.cornerAngles; zones = cornerZones
        case .side:   angles = Self.sideAngles;   zones = sideZones
        }

        let n = Double(angles.count)
        let baseUnit = 1.0 / n
        let maxAvg = zones.values.compactMap { $0.errors.isEmpty ? nil : $0.averageError }.max() ?? 0
        let norm = max(maxAvg, 1.0)

        var weights = angles.map { angle -> Double in
            let base = 0.3 * baseUnit
            if let z = zones[angle], !z.errors.isEmpty {
                return base + 0.7 * (z.averageError / norm) * baseUnit
            }
            return base + 0.7 * baseUnit
        }

        let total = weights.reduce(0, +)
        var r = Double.random(in: 0..<total)
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return Double(angles[i]) }
        }
        return Double(angles.last!)
    }

    // MARK: - Recording

    func recordResult(angle: Double, error: Double, pocketType: PocketType) {
        let zone = Int(angle.rounded())
        switch pocketType {
        case .corner: cornerZones[zone, default: ZoneHistory()].addError(error)
        case .side:   sideZones[zone, default: ZoneHistory()].addError(error)
        }
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        let state = PersistedState(cornerZones: cornerZones, sideZones: sideZones)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private struct PersistedState: Codable {
        let cornerZones: [Int: ZoneHistory]
        let sideZones:   [Int: ZoneHistory]
    }
}
