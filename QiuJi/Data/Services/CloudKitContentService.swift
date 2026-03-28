import Foundation

// MARK: - DTOs (Bundle JSON & CloudKit)

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

    struct DrillSetsConfig: Codable {
        let defaultSets: Int
        let defaultBallsPerSet: Int
    }
}

struct DrillIndex: Codable {
    let version: Int
    let drills: [String]
}

// MARK: - Service

actor CloudKitContentService {

    static let shared = CloudKitContentService()
    private init() {}

    // MARK: Bundle Fallback

    func loadFallbackDrills() -> [DrillContent] {
        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "Drills") else {
            return []
        }
        guard let indexData = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode(DrillIndex.self, from: indexData) else {
            return []
        }

        return index.drills.compactMap { drillId in
            loadDrillFromBundle(id: drillId)
        }
    }

    private func loadDrillFromBundle(id: String) -> DrillContent? {
        let categories = ["accuracy", "cueAction", "positioning", "fundamentals",
                          "separation", "forceControl", "specialShots", "combined"]
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
