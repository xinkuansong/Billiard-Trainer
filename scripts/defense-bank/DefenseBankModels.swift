// Standalone Foundation DTOs for defense-parameters-v1; copy/import into the page module.
// Coordinates/directions are [x,z], metres; no axis swap or quantization.
import Foundation
struct DefenseBankIndex: Codable {
    struct Counts: Codable { let inputs, questions, references: Int }
    struct Geometry: Codable { let length, width, radius: Double }
    struct Shard: Codable { let name, sha256: String; let bytes: Int }
    struct Entry: Codable { let id, kind, shard: String; let line: Int }
    let schema, policyVersion, physicsModel, assessmentVersion, coordinateSystem, fingerprint: String
    let geometry: Geometry
    let sourceFingerprints: [String:String]
    let counts: Counts
    let shards: [Shard]
    let questions: [Entry]
}
struct DefenseBankQuestion: Codable {
    struct Ball: Codable { let number: Int; let position: [Double] }
    struct Reference: Codable {
        struct Parameters: Codable { let direction: [Double]; let velocity, spinX, spinY: Double }
        struct Effect: Codable {
            let fullDirectBlock: Bool
            let score: Double? // 100 for full direct blocking; nil otherwise, never invent 100 - comfort.
            let opponentBallNumber: Int
            let cueToleranceDegrees, comfort: Double
        }
        struct Execution: Codable {
            let firstContactCutDegrees, projectedThicknessFraction, totalTravelMeters: Double
            let mainCushionCount: Int
            let mainCushionsByBall: [String:Int]
        }
        struct Probe: Codable {
            let angleDeltaDegrees, speedScale: Double
            let status: String
            let qualifies: Bool
            let tactics: [String]
        }
        struct Expected: Codable {
            struct Event: Codable {
                let kind: String
                let timeSeconds: Double
                let ballNumbers: [Int]
                let railIndex, pocketIndex: Int?
                private enum CodingKeys: String, CodingKey { case kind, timeSeconds, ballNumbers, railIndex, pocketIndex }
                init(from decoder: Decoder) throws {
                    let values = try decoder.container(keyedBy: CodingKeys.self)
                    kind = try values.decode(String.self, forKey: .kind)
                    timeSeconds = try values.decode(Double.self, forKey: .timeSeconds)
                    ballNumbers = try values.decode([Int].self, forKey: .ballNumbers)
                    railIndex = try values.decodeIfPresent(Int.self, forKey: .railIndex)
                    // The v1 exporter also emitted SceneKit names such as "pocket_2".
                    // Normalize that exact historical representation without changing bank bytes.
                    if try !values.contains(.pocketIndex) || values.decodeNil(forKey: .pocketIndex) {
                        pocketIndex = nil
                    } else {
                        let index: Int?
                        if let integer = try? values.decode(Int.self, forKey: .pocketIndex) { index = integer }
                        else {
                            let name = try values.decode(String.self, forKey: .pocketIndex)
                            index = (0..<6).first { name == "pocket_\($0)" }
                        }
                        guard let index, (0..<6).contains(index) else {
                            throw DecodingError.dataCorruptedError(forKey: .pocketIndex, in: values, debugDescription: "Invalid pocket index")
                        }
                        pocketIndex = index
                    }
                }
            }
            let finalBalls: [Ball]
            let pocketedBallNumbers: [Int]
            let events: [Event]
        }
        let id: String
        let parameters: Parameters
        let tactics: [String]
        let effect: Effect
        let execution: Execution
        let selectionProbes: [Probe]
        let expected: Expected
    }
    let id, sourceFormationID, sampleID, kind: String
    let cue: [Double]
    let balls: [Ball]
    let ownBallNumber, opponentBallNumber: Int
    let references: [Reference]
}
