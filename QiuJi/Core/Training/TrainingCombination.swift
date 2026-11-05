import Foundation

/// Persisted inventory categories are filters only, never sampling quotas.
struct TrainingCombination: Decodable {
    let id: String
    let angleIndex: Int
    let pocketType: Int
    let cueIndex: Int
    let objectIndex: Int
    let railIndex: Int
    var axes: [Int] { [angleIndex, pocketType, cueIndex, objectIndex, railIndex] }

    func matches(_ configuration: SceneTrainingConfiguration) -> Bool {
        let angles: [SceneTrainingConfiguration.AngleRange] = [.straight, .small, .medium, .large, .thin]
        let distances: [SceneTrainingConfiguration.Distance] = [.short, .middle, .long]
        return configuration.angleBands.contains(angles[angleIndex])
            && configuration.pocketTypes.contains(pocketType == 0 ? .corner : .side)
            && configuration.cueBands.contains(distances[cueIndex])
            && configuration.pocketBands.contains(distances[objectIndex])
            && (configuration.railDistanceSelection.contains(.mixed)
                || (railIndex == 1 && configuration.railDistanceSelection.contains(.near))
                || (railIndex == 2 && configuration.railDistanceSelection.contains(.frozen)))
    }
}
