import Foundation
import SceneKit

struct Stroke: Decodable { let direction: [Double]; let speed, spinX, spinY: Float }
struct Sample: Decodable { let source: DefenseBankQuestion; let shot: Stroke }
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let samples = try JSONDecoder().decode([Sample].self, from: Data(contentsOf: output.appendingPathComponent("fixtures.json")))
func prediction(_ sample: Sample) -> ShotPrediction {
    let q = sample.source, s = sample.shot, surface: Float = 0.8
    func v(_ a: [Double]) -> SCNVector3 { .init(Float(a[0]),surface+BallPhysics.radius,Float(a[1])) }
    let direction = SCNVector3(Float(s.direction[0]),0,Float(s.direction[1]))
    return ShotPredictor.simulateFree(cueBall: v(q.cue), aimDir: direction, velocity: s.speed,
        spinX: s.spinX, spinY: s.spinY, surfaceY: surface,
        balls: q.balls.map { .init(name: "_\($0.number)", position: v($0.position)) },
        maxEvents: 1500, maxTime: 60, includePresentation: false,
        simulationModel: .appDefault, recordedStrikeDirection: direction)
}
func encoded(_ effect: DefenseEffect) throws -> Data {
    let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
    return try encoder.encode(effect)
}
func evaluate(_ q: DefenseBankQuestion, _ p: ShotPrediction, _ enabled: Bool) throws -> (DefenseEffect,[String:Any]) {
    var timing = DefenseEffect.Timing()
    let start = ProcessInfo.processInfo.systemUptime
    let effect = try DefenseEffect.evaluate(question:q,prediction:p,usePrecomputedWindows:enabled) { timing = $0 }
    let elapsed = ProcessInfo.processInfo.systemUptime-start
    return (effect,["seconds":elapsed,"geometrySeconds":timing.geometrySeconds,"physicalSeconds":timing.physicalSeconds,
        "blockConfirmationSeconds":timing.blockConfirmationSeconds,"tableHits":timing.tableHits,"exactWindows":timing.exactWindows])
}
let ids = ["S03-01-46","S04-01-60","S01-01-30"]
var rows = [[String:Any]]()
for id in ids {
    let sample = samples.first { $0.source.id == id }!, p = prediction(sample)
    let (cold, first) = try evaluate(sample.source,p,true)
    precondition(cold.failure == nil && cold.unavailableReason == nil)
    if id == ids[2] { precondition(cold.attackRoute?.pocket == 0 && cold.score! < 95) }
    else { precondition(cold.score == 95 && cold.potContactsBlocked == true) }
    var baseline = [[String:Any]](), cached = [[String:Any]]()
    for round in 0..<9 {
        for enabled in (round.isMultiple(of:2) ? [false,true] : [true,false]) {
            let (effect, timing) = try autoreleasepool { try evaluate(sample.source,p,enabled) }
            let identical = try encoded(effect) == encoded(cold)
            precondition(identical, "ABC result changed: \(id)")
            if enabled { cached.append(timing) } else { baseline.append(timing) }
        }
    }
    rows.append(["id":id,"firstCached":first,"baseline":baseline,"cached":cached,
                 "effect":try JSONSerialization.jsonObject(with:encoded(cold))])
    print("BENCH \(id) before=\(baseline.map{$0["seconds"]!}) after=\(cached.map{$0["seconds"]!})")
}
guard let table = DefensePipeTable.shared else { fatalError("Bundled lookup table did not load") }
// Compare the Swift consumer against independent native geometry holdouts.
let holdouts = try JSONSerialization.jsonObject(with:Data(contentsOf:output.appendingPathComponent("holdouts.json"))) as! [[String:Any]]
var accepted = 0, maxWidthError = 0.0
for row in holdouts where row["valid"] as! Bool {
    let pos = row["position"] as! [Double], point = SCNVector3(Float(pos[0]),0,Float(pos[1]))
    for (p,truth) in (row["pockets"] as! [[String:Any]]).enumerated() {
        guard let w = table.window(point,pocket:p) else { continue }
        let intervals = truth["intervals"] as! [[Double]]
        precondition(intervals.count == 1)
        let width = (w["intervals"] as! [[String:Any]])[0]["widthDegrees"] as! Double
        maxWidthError = max(maxWidthError,abs(width-(intervals[0][1]-intervals[0][0]))); accepted += 1
    }
}
precondition(accepted > 10000 && maxWidthError < 0.005)
precondition(table.window(.init(-1.2274778,0,-0.4381169),pocket:0) == nil)
precondition(table.window(.init(Float.nan,0,0),pocket:0) == nil)
let meta = try Data(contentsOf:Bundle.main.url(forResource:"pipe-grid",withExtension:"json",subdirectory:"PocketPipe")!)
var bad = try Data(contentsOf:Bundle.main.url(forResource:"pipe-grid",withExtension:"bin",subdirectory:"PocketPipe")!)
bad[100] ^= 1
do { _ = try DefensePipeTable(metadata:meta,binary:bad); fatalError("Corrupt binary accepted") } catch { print("Corrupt table rejected: \(error)") }
var coverage = [[String:Any]]()
for sample in samples {
    let p = prediction(sample)
    let (a,_) = try evaluate(sample.source,p,false), (b,_) = try evaluate(sample.source,p,true)
    let same = try encoded(a) == encoded(b)
    precondition(a.failure == b.failure && a.fullDirectBlock == b.fullDirectBlock && a.potContactsBlocked == b.potContactsBlocked)
    precondition((a.score == nil) == (b.score == nil))
    if let x = a.score, let y = b.score { precondition(abs(x-y) < 0.01) }
    coverage.append(["id":sample.source.id,"identical":same])
}
let result: [String:Any] = ["passed":true,"rows":rows,"coverage":coverage,
    "lookupValidation":["holdoutPositions":holdouts.count,"accepted":accepted,"maxWidthError":maxWidthError],
    "scope":"Production DefenseEffect.evaluate, same optimized simulator CLI, alternating 9 repetitions each; excludes original shot simulation/UI; first A includes table load. Scoring formula remains v3."]
try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("results.json"))
print("PASS: ABC paired timings, 15-position coverage, holdouts and resource rejection")
