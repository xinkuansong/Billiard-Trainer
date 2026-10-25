import Foundation
enum SeparationTrajectory {
    struct Point { struct Position { let x: Float; let z: Float }; let position: Position }
}
struct Route: Decodable { let comboIndex: Int; let points: [[Double]] }
struct Candidate: Decodable { let cellID: Int; let ranked: [Int] }
struct Input: Decodable { let routes: [Route]; let candidates: [Candidate] }
let start = Date()
let input = try JSONDecoder().decode(Input.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
precondition(Set(input.routes.map(\.comboIndex)).count == input.routes.count)
precondition(input.routes.allSatisfy { $0.comboIndex >= 0 })
// Preserve production's Float coordinate conversion and exact P2 implementation.
let paths = try Dictionary(uniqueKeysWithValues: input.routes.map { row in
    (row.comboIndex, try SeparationArcRMSMetric.sample(row.points.map { SIMD2(Double(Float($0[1])) * 100, Double(Float($0[2])) * 100) }))
})
var cache: [String: Double] = [:]
var hits = 0
func similarity(_ a: Int, _ b: Int) throws -> Double {
    let key = "\(min(a,b)):\(max(a,b))"
    if let value = cache[key] { hits += 1; return value }
    let p = paths[min(a,b)]!, q = paths[max(a,b)]!
    let d = try SeparationArcRMSMetric.distance(p,q)
    let value = SeparationTrajectoryScore(rmsDistanceCM: d, targetSampleCount: p.cells.count, actualSampleCount: q.cells.count).value
    cache[key] = value
    return value
}
let full = CommandLine.arguments.contains("--full")
var results: [[String: Any]] = []
var verifiedPairs = 0
for candidate in input.candidates {
    var kept: [Int] = []
    var visited = 0
    for combo in candidate.ranked {
        visited += 1
        var duplicate = false
        for other in kept {
            if try similarity(combo, other) >= 60 { duplicate = true; break }
        }
        if !duplicate { kept.append(combo) }
        // Later lower-ranked candidates cannot change the first five representatives.
        if !full && kept.count == 5 { break }
    }
    let top = Array(kept.prefix(5))
    for i in top.indices {
        for j in top.indices where j > i {
            let value = try similarity(top[i], top[j])
            precondition(value < 60)
            verifiedPairs += 1
        }
    }
    results.append(["cellID": candidate.cellID, "top5": top, "visited": visited, "representativesComputed": kept.count])
}
let output: [String: Any] = ["algorithm": SeparationTrajectoryScore.algorithm, "results": results,
    "pairComputations": cache.count, "cacheHits": hits, "verifiedTopPairs": verifiedPairs, "nativeSeconds": Date().timeIntervalSince(start)]
try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys]).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
