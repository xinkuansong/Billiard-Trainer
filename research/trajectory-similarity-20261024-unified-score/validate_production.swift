// Standalone parity runner. Compile together with the complete production score source.
// Only the SceneKit-backed trajectory DTO is replaced by the same Float X/Z storage.
import Foundation
enum SeparationTrajectory {
    struct Point: Decodable { let position: Position }
    struct Position: Decodable { let x: Float; let z: Float }
}
@main struct ValidateProduction {
    struct Native: Decodable {
        struct Row: Decodable { let comboIndex: Int; let comparisonLine: [SeparationTrajectory.Point] }
        let rows: [Row]
    }
    struct Reference: Decodable {
        struct Pair: Decodable { let a: Int; let b: Int; let p2: Double }
        let allPairs: [Pair]
    }
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let source = try JSONDecoder().decode(Native.self, from: Data(contentsOf: root.appendingPathComponent(
            "output/two-ball-b42-dedup75-20261024/native-result.json")))
        let reference = try JSONDecoder().decode(Reference.self, from: Data(contentsOf: root.appendingPathComponent(
            "research/trajectory-similarity-20261024-unified-score/p2-results.json")))
        let lines = Dictionary(uniqueKeysWithValues: source.rows.map { ($0.comboIndex, $0.comparisonLine) })
        var maximumError = 0.0, focus = [[String: Any]]()
        for p in reference.allPairs {
            guard let score = try SeparationTrajectoryScore.evaluate(target: lines[p.a]!, actual: lines[p.b]!) else {
                throw NSError(domain: "MissingScore", code: 1)
            }
            let error = abs(score.value - p.p2)
            guard error < 0.0001 else {
                throw NSError(domain: "ParityFailure", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(p.a)/\(p.b): \(error)"])
            }
            maximumError = max(maximumError, error)
            if Set([p.a, p.b]) == Set([237, 235]) {
                focus.append(["a":p.a, "b":p.b, "score":score.value, "reference":p.p2,
                              "version":score.version, "rmsDistanceCM":score.distanceCM])
            }
            let restored = try JSONDecoder().decode(SeparationTrajectoryScore.self, from: JSONEncoder().encode(score))
            precondition(restored == score)
        }
        let result: [String: Any] = ["pairs":reference.allPairs.count, "maximumScoreError":maximumError,
                                     "roundTrips":reference.allPairs.count, "focus":focus,
                                     "scope":"Actual production evaluate(), Float coordinate storage; all 4278 research pairs"]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: root.appendingPathComponent("output/separation-p2-integration-20261024/production-parity.json"))
        print(String(data:data,encoding:.utf8)!)
    }
}
