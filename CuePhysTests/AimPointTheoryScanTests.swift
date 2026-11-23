import XCTest
import SceneKit
import UIKit
@testable import QiuJi

/// Opt-in diagnostic; fixtures and results are isolated from production assets.
final class AimPointTheoryScanTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private var dir: URL { root.appendingPathComponent("output/aim-point-theory/W0") }
    struct Fixture: Codable {
        let angle: Int
        let kind: String
        let side: Int
        let cueBucket: Int
        let objectBucket: Int
        let cue: [Float]
        let object: [Float]
        let pocketIndex: Int
        let measuredAngle: Float
        let cueDistance: Float
        let pocketDistance: Float
    }
    struct Trial: Codable {
        let velocity: Float
        let success: Bool
        let scratch: Bool
        let settled: Bool
        let pocket: String?
        let cueRailBeforeContact: Bool
        let objectRail: Bool
        let milliseconds: Double
        let duration: Float
    }
    struct Row: Codable { let fixture: Fixture; let trials: [Trial] }
    private func point(_ a: [Float]) -> SCNVector3 { SCNVector3(a[0], a[1], a[2]) }
    private func length(_ a: SCNVector3, _ b: SCNVector3) -> Float { hypotf(a.x-b.x, a.z-b.z) }
    private func direction(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
        let d = length(a,b); return SCNVector3((b.x-a.x)/d,0,(b.z-a.z)/d)
    }
    private func answer(_ f: Fixture) -> SCNVector3 {
        let t = point(f.object)
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: t, pocketIndex: f.pocketIndex, surfaceY: 0.8)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: t, pocket: aim, ballRadius: BallPhysics.radius)
        return direction(point(f.cue), ghost)
    }
    private func fixtures() throws -> [Fixture] {
        let url = dir.appendingPathComponent("fixtures.json")
        if FileManager.default.fileExists(atPath: url.path) { return try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url)) }
        var result: [Fixture] = []
        for angle in stride(from: 10, through: 80, by: 5) {
            for kind in PocketType.allCases {
                var buckets = Set<String>()
                for _ in 0..<240 {
                    let q = AngleCalculator.generateQuestion(angle: Double(angle), pocketType: kind, targetPocketDistanceRange: 0.15...0.55)
                    let c = AngleSceneCalculator.normalizedToScene(point: q.cueBall, surfaceY: 0.8)
                    let t = AngleSceneCalculator.normalizedToScene(point: q.targetBall, surfaceY: 0.8)
                    let p = AngleSceneCalculator.pocketPositions(surfaceY: 0.8)[q.pocketIndex]
                    let a = AngleSceneCalculator.effectivePocketAimPoint(targetBall: t, pocketIndex: q.pocketIndex, surfaceY: 0.8)
                    let g = AngleSceneCalculator.ghostBallPosition(targetBall: t, pocket: a, ballRadius: BallPhysics.radius)
                    let d = direction(c,g), out = direction(t,a)
                    let measured = acosf(max(-1,min(1,d.x*out.x+d.z*out.z))) * 180 / .pi
                    XCTAssertEqual(measured, Float(angle), accuracy: 0.02)
                    let cd = length(c,t), pd = length(t,p)
                    let cb = cd < 0.57 ? 0 : (cd < 0.74 ? 1 : 2)
                    let ob = pd < 0.72 ? 0 : (pd < 1.06 ? 1 : 2)
                    let side = d.x*out.z-d.z*out.x >= 0 ? 1 : -1
                    let key = "\(side)-\(cb)-\(ob)"
                    guard buckets.insert(key).inserted else { continue }
                    result.append(Fixture(angle: angle, kind: kind.rawValue, side: side, cueBucket: cb, objectBucket: ob,
                                          cue: [c.x,c.y,c.z], object: [t.x,t.y,t.z], pocketIndex: q.pocketIndex,
                                          measuredAngle: measured, cueDistance: cd, pocketDistance: pd))
                }
            }
        }
        try JSONEncoder().encode(result).write(to: url, options: .atomic)
        return result
    }
    private func trial(_ f: Fixture, _ velocity: Float) -> Trial {
        let start = Date()
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: 0.8)
        let engine = EventDrivenEngine(tableGeometry: geometry)
        let strike = CueBallStrike.executeStrike(aimDirection: answer(f), velocity: velocity, spinX: 0, spinY: 0, elevation: 0)
        engine.setBall(BallState(position: point(f.cue), velocity: strike.velocity, angularVelocity: strike.angularVelocity, state: .sliding, name: ShotInput.cueBallName))
        engine.setBall(BallState(position: point(f.object), velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: "object"))
        engine.simulate(maxEvents: 500, maxTime: 15, highFidelityBounds: true)
        let hole = AngleSceneCalculator.pocketPositions(surfaceY: 0.8)[f.pocketIndex]
        let selected = geometry.pockets.min { length($0.center,hole) < length($1.center,hole) }!.id
        var contact = false, cueRail = false, objectRail = false
        var pocket: String?
        for event in engine.resolvedEvents {
            switch event {
            case .ballBall: contact = true
            case let .ballCushion(ball,index,_):
                if ball == ShotInput.cueBallName && !contact { cueRail = true }
                if ball == "object" && index >= 0 && index < 6 && pocket == nil { objectRail = true }
            case let .pocket(ball,id): if ball == "object" { pocket = id }
            default: break
            }
        }
        let settled = engine.getAllBalls().allSatisfy { $0.isPocketed || $0.state == .stationary }
        return Trial(velocity: velocity, success: contact && pocket == selected && !cueRail && !objectRail && settled,
                     scratch: engine.getBall(ShotInput.cueBallName)!.isPocketed, settled: settled, pocket: pocket,
                     cueRailBeforeContact: cueRail, objectRail: objectRail,
                     milliseconds: Date().timeIntervalSince(start)*1000, duration: engine.currentTime)
    }
    func test_scanFixedTheoryDirection() throws {
        guard FileManager.default.fileExists(atPath: dir.appendingPathComponent("RUN").path) else { throw XCTSkip("Opt-in W0 matrix") }
        let fixtures = try fixtures()
        XCTAssertEqual(Set(fixtures.map(\.angle)).count, 15)
        var rows: [Row] = []
        for (index,f) in fixtures.enumerated() {
            var trials = [trial(f,3.3)]
            for step in 0...30 { trials.append(trial(f,0.5+Float(step)*0.25)) }
            // Verify the diagnostic uses the same fixed-direction production path.
            let production = ShotPredictor.simulateFree(cueBall: point(f.cue), aimDir: answer(f), velocity: 3.3, spinX: 0, spinY: 0, surfaceY: 0.8, balls: [ObstacleBall(name: "object", position: point(f.object))], includePresentation: false)
            XCTAssertEqual(production.objectPocketed, trials[0].pocket != nil)
            XCTAssertEqual(production.cuePocketed, trials[0].scratch)
            rows.append(Row(fixture: f,trials: trials))
            try JSONEncoder().encode(rows).write(to: dir.appendingPathComponent("scan.json"), options: .atomic)
            if index % 15 == 0 { print("W0 progress \(index+1)/\(fixtures.count)") }
        }
        print("W0 finished \(rows.count) fixtures")
    }
    func test_probeTermination() throws {
        guard FileManager.default.fileExists(atPath: dir.appendingPathComponent("RUN").path) else { throw XCTSkip("Opt-in W0 probe") }
        let all = try fixtures()
        var records: [[String: Any]] = []
        for angle in [10,45,80] {
            let f = try XCTUnwrap(all.first { $0.angle == angle })
            for speed: Float in [0.5,3.3,8] {
                for horizon: Float in [15,60] {
                    let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: 0.8)
                    let engine = EventDrivenEngine(tableGeometry: geometry)
                    let strike = CueBallStrike.executeStrike(aimDirection: answer(f), velocity: speed, spinX: 0, spinY: 0, elevation: 0)
                    engine.setBall(BallState(position: point(f.cue), velocity: strike.velocity, angularVelocity: strike.angularVelocity, state: .sliding, name: ShotInput.cueBallName))
                    engine.setBall(BallState(position: point(f.object), velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: "object"))
                    engine.simulate(maxEvents: 2000, maxTime: horizon, highFidelityBounds: true)
                    let states: [[String: Any]] = engine.getAllBalls().map { b in
                        ["name":b.name,"state":b.state.rawValue,"pocketed":b.isPocketed,
                         "position":[b.position.x,b.position.y,b.position.z],
                         "velocity":[b.velocity.x,b.velocity.y,b.velocity.z],
                         "angularVelocity":[b.angularVelocity.x,b.angularVelocity.y,b.angularVelocity.z]]
                    }
                    records.append(["angle":angle,"velocity":speed,"horizon":horizon,"duration":engine.currentTime,"eventCount":engine.resolvedEvents.count,"states":states])
                }
            }
        }
        try JSONSerialization.data(withJSONObject: records,options: [.prettyPrinted,.sortedKeys]).write(to: dir.appendingPathComponent("termination-probe.json"),options: .atomic)
    }

    func test_refineUnresolvedExamples() throws {
        guard FileManager.default.fileExists(atPath: dir.appendingPathComponent("RUN").path) else { throw XCTSkip("Opt-in W0 refinement") }
        let rows = try JSONDecoder().decode([Row].self, from: Data(contentsOf: dir.appendingPathComponent("scan.json")))
        var selected = Set<String>()
        var output: [Row] = []
        for row in rows where !row.trials.contains(where: { $0.success && !$0.scratch }) {
            let f = row.fixture
            let key = "\(f.angle)-\(f.kind)"
            guard selected.insert(key).inserted else { continue }
            var trials: [Trial] = []
            for i in 0...150 { trials.append(trial(f,0.5+Float(i)*0.05)) }
            output.append(Row(fixture:f,trials:trials))
            try JSONEncoder().encode(output).write(to: dir.appendingPathComponent("refinement.json"),options:.atomic)
        }
        print("W0 refined \(output.count) unresolved examples at 0.05 m/s")
    }

    func test_probeDistanceCoverageGaps() throws {
        guard FileManager.default.fileExists(atPath: dir.appendingPathComponent("RUN").path) else { throw XCTSkip("Opt-in W0 distance probe") }
        let rows = try JSONDecoder().decode([Row].self, from: Data(contentsOf: dir.appendingPathComponent("scan.json")))
        var output: [Row] = []
        var manifest: [[String: Any]] = []
        for angle in stride(from:10,through:80,by:5) {
            for kind in PocketType.allCases {
                for bucket in 0...2 {
                    let base = rows.filter { $0.fixture.angle == angle && $0.fixture.kind == kind.rawValue && $0.fixture.objectBucket == bucket }
                    guard !base.isEmpty, !base.contains(where: { $0.trials.contains(where: { $0.success && !$0.scratch }) }) else { continue }
                    var added = 0
                    var attempted = 0
                    var rejectedAngles = 0
                    for _ in 0..<1000 {
                        attempted += 1
                        let range: ClosedRange<Double> = 0.15...0.55
                        let q = AngleCalculator.generateQuestion(angle:Double(angle),pocketType:kind,targetPocketDistanceRange:range)
                        let c = AngleSceneCalculator.normalizedToScene(point:q.cueBall,surfaceY:0.8)
                        let t = AngleSceneCalculator.normalizedToScene(point:q.targetBall,surfaceY:0.8)
                        let hole = AngleSceneCalculator.pocketPositions(surfaceY:0.8)[q.pocketIndex]
                        let pd = length(t,hole), cd = length(c,t)
                        let ob = pd < 0.72 ? 0 : (pd < 1.06 ? 1 : 2)
                        guard ob == bucket else { continue }
                        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall:t,pocketIndex:q.pocketIndex,surfaceY:0.8)
                        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall:t,pocket:aim,ballRadius:BallPhysics.radius)
                        let d = direction(c,ghost), out = direction(t,aim)
                        let measured = acosf(max(-1,min(1,d.x*out.x+d.z*out.z))) * 180 / .pi
                        guard abs(measured-Float(angle)) <= 0.02 else {
                            rejectedAngles += 1
                            continue
                        }
                        let f = Fixture(angle:angle,kind:kind.rawValue,side:d.x*out.z-d.z*out.x >= 0 ? 1 : -1,
                                        cueBucket:cd < 0.57 ? 0 : (cd < 0.74 ? 1 : 2),objectBucket:ob,
                                        cue:[c.x,c.y,c.z],object:[t.x,t.y,t.z],pocketIndex:q.pocketIndex,
                                        measuredAngle:measured,cueDistance:cd,pocketDistance:pd)
                        var trials: [Trial] = []
                        for i in 0...30 { trials.append(trial(f,0.5+Float(i)*0.25)) }
                        added += 1
                        // One dense sweep per unresolved distance stratum, others coarse.
                        if added == 1 && !trials.contains(where: { $0.success && !$0.scratch }) {
                            for i in 0...150 where i % 5 != 0 { trials.append(trial(f,0.5+Float(i)*0.05)) }
                        }
                        output.append(Row(fixture:f,trials:trials))
                        try JSONEncoder().encode(output).write(to:dir.appendingPathComponent("distance-gap-probe.json"),options:.atomic)
                        if trials.contains(where: { $0.success && !$0.scratch }) || added >= 8 { break }
                    }
                    manifest.append(["angle":angle,"kind":kind.rawValue,"bucket":bucket,"attempted":attempted,"added":added,"rejectedAngles":rejectedAngles])
                    try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("distance-gap-attempts.json"),options:.atomic)
                    print("W0 distance gap \(angle) \(kind) bucket \(bucket): \(added) new fixtures")
                }
            }
        }
    }

    func test_renderExamples() throws {
        guard FileManager.default.fileExists(atPath: dir.appendingPathComponent("RUN").path) else { throw XCTSkip("Opt-in W0 diagrams") }
        let rows = try JSONDecoder().decode([Row].self,from:Data(contentsOf:dir.appendingPathComponent("scan.json")))
        for angle in [10,40,80] {
            let row = try XCTUnwrap(rows.first { $0.fixture.angle == angle && !$0.trials[0].success && $0.trials.contains(where: { $0.success && !$0.scratch }) })
            let winner = try XCTUnwrap(row.trials.first { $0.success && !$0.scratch })
            let f = row.fixture
            let image = UIGraphicsImageRenderer(size:CGSize(width:1200,height:390)).image { context in
                UIColor.white.setFill(); context.fill(CGRect(x:0,y:0,width:1200,height:390))
                for (panel,speed) in [Float(3.3),winner.velocity].enumerated() {
                    let left = CGFloat(panel)*600+40
                    func xy(_ p: SCNVector3) -> CGPoint { CGPoint(x:left+CGFloat(p.x+1.27)*200,y:70+CGFloat(p.z+0.635)*200) }
                    let rect=CGRect(x:left,y:70,width:508,height:254)
                    UIColor(red:0.90,green:0.96,blue:0.94,alpha:1).setFill(); context.fill(rect)
                    UIColor.darkGray.setStroke(); context.stroke(rect)
                    let prediction=ShotPredictor.simulateFree(cueBall:point(f.cue),aimDir:answer(f),velocity:speed,spinX:0,spinY:0,surfaceY:0.8,balls:[ObstacleBall(name:"object",position:point(f.object))])
                    for pocket in TableGeometry.chineseEightBallQiuJi(surfaceY:0.8).pockets {
                        let c=xy(pocket.center); UIColor.darkGray.setFill()
                        context.cgContext.fillEllipse(in:CGRect(x:c.x-8.4,y:c.y-8.4,width:16.8,height:16.8))
                    }
                    for (path,color) in [(prediction.cuePath,UIColor.systemBlue),(prediction.extraBallPaths["object"] ?? [],UIColor.systemRed)] {
                        guard let first=path.first else {continue}
                        let line=UIBezierPath();line.move(to:xy(first));for p in path.dropFirst(){line.addLine(to:xy(p))}
                        color.setStroke();line.lineWidth=1.5;line.stroke()
                    }
                    let c=point(f.cue), d=answer(f)
                    let aim=UIBezierPath();aim.move(to:xy(c));aim.addLine(to:xy(SCNVector3(c.x+d.x*0.7,c.y,c.z+d.z*0.7)))
                    UIColor.systemTeal.setStroke();aim.lineWidth=2;aim.setLineDash([4,4],count:2,phase:0);aim.stroke()
                    for (p,color) in [(point(f.cue),UIColor.white),(point(f.object),UIColor.systemRed)] {
                        let v=xy(p);color.setFill();context.cgContext.fillEllipse(in:CGRect(x:v.x-5.7,y:v.y-5.7,width:11.4,height:11.4))
                        UIColor.darkGray.setStroke();context.cgContext.strokeEllipse(in:CGRect(x:v.x-5.7,y:v.y-5.7,width:11.4,height:11.4))
                    }
                    let title="\(angle) deg | \(panel == 0 ? "fixed" : "searched") \(String(format:"%.2f",speed)) m/s"
                    (title as NSString).draw(at:CGPoint(x:left,y:20),withAttributes:[.font:UIFont.systemFont(ofSize:17,weight:.semibold),.foregroundColor:UIColor.black])
                    ("Same theoretical aim; blue = cue, red = object" as NSString).draw(at:CGPoint(x:left,y:352),withAttributes:[.font:UIFont.systemFont(ofSize:12),.foregroundColor:UIColor.darkGray])
                }
            }
            try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent("comparison-\(angle).png"),options:.atomic)
        }
    }

}
