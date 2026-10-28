import Foundation

/// Business identity is independent of the camera. Legacy routes remain readable.
enum TrainingProject: String, Codable, CaseIterable {
    case angle, aimPoint, accuracy, separation, twoBall, threeBall, multiBall
    static let ordinaryRoundCount = 15
    var roundCount: Int { self == .multiBall ? 3 : Self.ordinaryRoundCount }
    var title: String {
        switch self {
        case .angle: "角度练习"
        case .aimPoint: "瞄准点练习"
        case .accuracy: "准度练习"
        case .separation: "分离角练习"
        case .twoBall: "两球走位"
        case .threeBall: "三球走位"
        case .multiBall: "多球走位"
        }
    }
    var page2D: TablePreferencePage {
        switch self {
        case .angle: .sceneAiming2D
        case .aimPoint: .aimPointScene2D
        case .accuracy: .accuracy2D
        case .separation: .separationPractice2D
        case .twoBall: .twoBallPractice2D
        case .threeBall: .threeBallPractice2D
        case .multiBall: .multiBallPractice
        }
    }
    var page3D: TablePreferencePage {
        switch self {
        case .angle: .sceneAiming3D
        case .aimPoint: .aimPointScene3D
        case .accuracy: .accuracy3D
        case .separation: .separationPractice3D
        case .twoBall: .twoBallPractice3D
        case .threeBall: .threeBallPractice3D
        case .multiBall: .multiBallPractice3D
        }
    }
    static func from(route: String) -> Self? {
        if route.hasPrefix("scene") { return .angle }
        if route.hasPrefix("aimPointScene") || ["aimPoint2D", "aimPoint3D"].contains(route) { return .aimPoint }
        if route.hasPrefix("accuracy") { return .accuracy }
        if route.hasPrefix("separationPractice") { return .separation }
        if route.hasPrefix("twoBallPractice") { return .twoBall }
        if route.hasPrefix("threeBallPractice") { return .threeBall }
        if route.hasPrefix("multiBallPractice") { return .multiBall }
        return nil
    }
}

enum TrainingViewMode: String, Codable, Hashable {
    case twoD = "2D", threeD = "3D"
    init(is3D: Bool) { self = is3D ? .threeD : .twoD }
    var is3D: Bool { self == .threeD }
}

/// Saved with the business fact before the local quota ledger is reconciled.
/// Premium provenance is frozen at acceptance, never inferred during recovery.
struct TrainingConsumptionReceipt: Codable, Equatable {
    let questionID: UUID
    let acceptedAt: Date
    let charged: Bool
}

/// Optional addition to existing payloads; legacy source IDs and scores stay intact.
struct TrainingPresentation: Codable {
    var current: TrainingViewMode
    var observed: [UUID: Set<TrainingViewMode>] = [:]
    var submitted: [UUID: TrainingViewMode] = [:]
    var receipts: [UUID: TrainingConsumptionReceipt] = [:]
    /// Adoption of an old draft must not retrospectively bill old 3D/Pro answers.
    var legacyConsumed: Set<UUID> = []

    init(is3D: Bool, legacyConsumed: Set<UUID> = []) {
        current = .init(is3D: is3D); self.legacyConsumed = legacyConsumed
    }
    mutating func observe(_ mode: TrainingViewMode, questionID: UUID?) {
        guard let questionID, submitted[questionID] == nil else { return }
        observed[questionID, default: []].insert(mode)
    }
    mutating func accept(questionID: UUID, at date: Date, premium: Bool) {
        guard receipts[questionID] == nil, !legacyConsumed.contains(questionID) else { return }
        observe(current, questionID: questionID)
        submitted[questionID] = current
        receipts[questionID] = .init(questionID: questionID, acceptedAt: date, charged: !premium)
    }
    var summary: String {
        let modes = Set(observed.values.flatMap { $0 })
        return modes.count > 1 ? "混合视图" : (modes.first ?? current).rawValue
    }
    func label(for questionID: UUID) -> String {
        let views = observed[questionID] ?? []
        return views.count > 1 ? "混合视图" : (submitted[questionID] ?? current).rawValue
    }
}

extension TablePreferencePage {
    var trainingProject: TrainingProject? { TrainingProject.from(route: rawValue) }
}

/// Frozen with each accepted physical stroke; historical shots decode as nil.
struct TrainingShotPresentation: Codable {
    let view: TrainingViewMode
    let observed: Set<TrainingViewMode>
    let wasPremium: Bool
    var label: String { observed.count > 1 ? "混合视图" : view.rawValue }
    init(view: TrainingViewMode, observed: Set<TrainingViewMode>, premium: Bool) {
        self.view = view; self.observed = observed.union([view]); wasPremium = premium
    }
}
