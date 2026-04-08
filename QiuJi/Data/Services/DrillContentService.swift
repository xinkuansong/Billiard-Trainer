import Foundation

// MARK: - DTOs (Bundle JSON; future: REST API OTA)

struct DrillContent: Codable, Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let category: String
    let subcategory: String
    let ballType: [String]
    let level: String
    let difficulty: Int
    let isPremium: Bool
    let description: String
    let coachingPoints: [String]
    let standardCriteria: String
    let sets: DrillSetsConfig
    let animation: DrillAnimation
    let tutorial: DrillTutorial?

    struct DrillSetsConfig: Codable {
        let defaultSets: Int
        let defaultBallsPerSet: Int
    }
}

struct DrillTutorial: Codable {
    let sections: [TutorialSection]
}

struct TutorialSection: Codable, Identifiable {
    let title: String
    let content: String

    var id: String { title }
}

// MARK: - Animation Types

struct DrillAnimation: Codable {
    let cueBall: BallAnimation
    let targetBall: BallAnimation
    let pocket: String
    let cueDirection: CanvasPoint
}

struct BallAnimation: Codable {
    let start: CanvasPoint
    let path: [PathPoint]
}

struct CanvasPoint: Codable {
    let x: Double
    let y: Double
}

struct PathPoint: Codable {
    let x: Double
    let y: Double
    let cp1: CanvasPoint?
    let cp2: CanvasPoint?

    init(x: Double, y: Double, cp1: CanvasPoint? = nil, cp2: CanvasPoint? = nil) {
        self.x = x
        self.y = y
        self.cp1 = cp1
        self.cp2 = cp2
    }

    var isCurve: Bool {
        cp1 != nil && cp2 != nil
    }

    var endPoint: CanvasPoint {
        CanvasPoint(x: x, y: y)
    }
}

// MARK: - Index

struct DrillIndex: Codable {
    let version: Int
    let categories: [CategoryGroup]

    struct CategoryGroup: Codable {
        let category: String
        let drills: [String]
    }

    var allDrillIds: [String] {
        categories.flatMap(\.drills)
    }
}

// MARK: - Category Metadata

enum DrillCategory: String, CaseIterable, Identifiable {
    case fundamentals
    case accuracy
    case cueAction
    case separation
    case positioning
    case forceControl
    case specialShots
    case combined

    var id: String { rawValue }

    var nameZh: String {
        switch self {
        case .fundamentals:  return "基础功"
        case .accuracy:      return "准度训练"
        case .cueAction:     return "杆法训练"
        case .separation:    return "分离角"
        case .positioning:   return "走位训练"
        case .forceControl:  return "控力训练"
        case .specialShots:  return "特殊球路"
        case .combined:      return "综合球形"
        }
    }

    var icon: String {
        switch self {
        case .fundamentals:  return "figure.stand"
        case .accuracy:      return "scope"
        case .cueAction:     return "arrow.up.and.down"
        case .separation:    return "arrow.triangle.branch"
        case .positioning:   return "arrow.triangle.turn.up.right.diamond"
        case .forceControl:  return "gauge.with.dots.needle.33percent"
        case .specialShots:  return "sparkles"
        case .combined:      return "square.grid.3x3"
        }
    }
}

// MARK: - Service

/// Loads bundled Drill JSON. Future: merge with self-hosted `GET /drills` for OTA updates (ADR-002).
actor DrillContentService {

    static let shared = DrillContentService()
    private init() {}

    // MARK: Bundle

    func loadFallbackDrills() -> [DrillContent] {
        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "Drills") else {
            return []
        }
        guard let indexData = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode(DrillIndex.self, from: indexData) else {
            return []
        }

        return index.allDrillIds.compactMap { drillId in
            loadDrillFromBundle(id: drillId)
        }
    }

    func loadDrillIndex() -> DrillIndex? {
        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "Drills"),
              let indexData = try? Data(contentsOf: indexURL) else {
            return nil
        }
        return try? JSONDecoder().decode(DrillIndex.self, from: indexData)
    }

    func loadDrillFromBundle(id: String) -> DrillContent? {
        let categories = DrillCategory.allCases.map(\.rawValue)
        for category in categories {
            let subdir = "Drills/\(category)"
            if let url = Bundle.main.url(forResource: id, withExtension: "json", subdirectory: subdir),
               let data = try? Data(contentsOf: url),
               let drill = try? JSONDecoder().decode(DrillContent.self, from: data) {
                return drill
            }
        }
        return nil
    }
}
