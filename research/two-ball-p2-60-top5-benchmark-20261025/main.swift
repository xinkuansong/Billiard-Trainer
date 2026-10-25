import Foundation
enum SeparationTrajectory {
    struct Point { struct Position { let x: Float; let z: Float }; let position: Position }
}
struct Route: Decodable { let comboIndex: Int; let points: [[Double]] }
struct Candidate: Decodable { let cellID: Int; let ranked: [Int] }
struct Input: Decodable { let routes: [Route]; let candidates: [Candidate] }
let start = Date()
let input = try JSONDecoder().decode(Input.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
// Preserve production's Float coordinate conversion and exact P2 implementation.
let paths = try Dictionary(uniqueKeysWithValues: input.routes.map { row in
    (row.comboIndex, try SeparationArcRMSMetric.sample(row.points.map { SIMD2(Double(Float($0[1])) * 100, Double(Float($0[2])) * 100) }))
})
var cache: [Int: Double] = [:]
var hits = 0
func similarity(_ a: Int, _ b: Int) throws -> Double {
    let key = min(a,b) * 1000 + max(a,b)
    if let value = cache[key] { hits += 1; return value }
    let p = paths[min(a,b)]!, q = paths[max(a,b)]!
    let d = try SeparationArcRMSMetric.distance(p,q)
    let value = SeparationTrajectoryScore(rmsDistanceCM: d, targetSampleCount: p.cells.count, actualSampleCount: q.cells.count).value
    cache[key] = value
    return value
}
let full = CommandLine.arguments.contains("--full")
var results: [[String: Any]] = []
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
    results.append(["cellID": candidate.cellID, "top5": Array(kept.prefix(5)), "visited": visited, "representativesComputed": kept.count])
}
let output: [String: Any] = ["algorithm": SeparationTrajectoryScore.algorithm, "results": results,
    "pairComputations": cache.count, "cacheHits": hits, "nativeSeconds": Date().timeIntervalSince(start)]
try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys]).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
