import XCTest
import SceneKit
import UIKit
@testable import QiuJi

/// Opt-in research harness. Uses production physics without changing its constants.
final class SixPocketSearchTests: XCTestCase {
    private let y: Float = 0.8
    private let numbers = [1, 2, 3, 4, 5, 8]
    private let pocketIndices = [1, 3, 5, 2, 0, 4]
    private var evaluationSimulationCalls = 0
    private var speedRange: ClosedRange<Double> { 0.5...min(10, max(0.5, Double(env("SIX_MAX_SPEED") ?? "9") ?? 9)) }
    private var seedMinimumSpeed: Float { min(Float(speedRange.upperBound), max(Float(speedRange.lowerBound), Float(env("SIX_SEED_MIN_SPEED") ?? "0.5") ?? 0.5)) }
    private var hangingLayout: Bool { env("SIX_LAYOUT") == "hanging" }
    private var distanceOverride: Float?
    private var commonDistance: Float? { distanceOverride ?? env("SIX_COMMON_DISTANCE").flatMap(Float.init) }
    private var fixtureName: String {
        if let d=commonDistance { return String(format:"six-pocket-v3-uniform-%.6fm",Double(d)) }
        return hangingLayout ? "six-pocket-v2-hanging" : "six-pocket-v1"
    }
    private var geometry: TableGeometry { .chineseEightBallQiuJi(surfaceY: y) }
    private var positions: [SCNVector3] {
        pocketIndices.map { i in
            let p = geometry.pockets[i].center
            if i < 4 {
                let d: Float = (commonDistance ?? (hangingLayout ? 0.085 : 0.13)) / sqrtf(2)
                return SCNVector3(p.x - (p.x > 0 ? d : -d), y + BallPhysics.radius,
                                  p.z - (p.z > 0 ? d : -d))
            }
            return SCNVector3(0, y + BallPhysics.radius, p.z - (p.z > 0 ? 1 : -1) * (commonDistance ?? (hangingLayout ? 0.075 : 0.08)))
        }
    }
    private func env(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_" + key]
    }
    private func output() throws -> URL {
        guard let path = env("SIX_SEARCH_DIR") else { throw XCTSkip("Opt-in research search") }
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func write(_ value: Any, _ name: String, to out: URL) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent(name), options: .atomic)
    }
    private func point(_ p: SCNVector3) -> [Float] { [p.x, p.z] }
    private func distance(_ a: SCNVector3, _ b: SCNVector3) -> Float { hypotf(a.x-b.x, a.z-b.z) }
    private func segmentDistance(_ p: SCNVector3, _ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx=b.x-a.x, dz=b.z-a.z, l=dx*dx+dz*dz
        let t=l > 0 ? max(0,min(1,((p.x-a.x)*dx+(p.z-a.z)*dz)/l)) : 0
        return hypotf(p.x-a.x-t*dx,p.z-a.z-t*dz)
    }
    private func clearance(_ p: SCNVector3) -> Float {
        var result=Float.infinity
        for s in geometry.linearCushions { result=min(result,segmentDistance(p,s.start,s.end)) }
        for s in geometry.circularCushions {
            let a=atan2f(p.z-s.center.z,p.x-s.center.x)
            if s.isAngleInRange(a) { result=min(result,abs(distance(p,s.center)-s.radius)) }
            for t in [s.startAngle,s.endAngle] {
                result=min(result,distance(p,SCNVector3(s.center.x+s.radius*cosf(t),y,s.center.z+s.radius*sinf(t))))
            }
        }
        return result
    }
    private func engine(_ q: [Float]?) -> EventDrivenEngine {
        let e=EventDrivenEngine(tableGeometry: geometry)
        if let q {
            // Match ShotPredictor.simulateFree exactly: normalize direction and insert
            // the cue before obstacles. Contact ordering affects narrow multi-ball paths.
            let raw=SCNVector3(cosf(q[2]),0,sinf(q[2]))
            let length=sqrtf(raw.x*raw.x+raw.z*raw.z)
            let strike=CueBallStrike.executeStrike(aimDirection:SCNVector3(raw.x/length,0,raw.z/length),
                velocity:q[3],spinX:q[4],spinY:q[5])
            e.setBall(BallState(position:SCNVector3(q[0],y+BallPhysics.radius,q[1]),velocity:strike.velocity,
                angularVelocity:strike.angularVelocity,state:.sliding,name:ShotInput.cueBallName))
        }
        for (i,p) in positions.enumerated() {
            e.setBall(BallState(position:p,velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,
                                state:.stationary,name:"_\(numbers[i])"))
        }
        return e
    }
    func testFixture() throws {
        let out=try output()
        var rows:[[String:Any]]=[]
        for (i,p) in positions.enumerated() {
            XCTAssertGreaterThan(clearance(p),BallPhysics.radius)
            let pocket=geometry.pockets[pocketIndices[i]]
            XCTAssertGreaterThan(distance(p,pocket.center),pocket.radius)
            if let d=commonDistance { XCTAssertEqual(distance(p,pocket.center),d,accuracy:1e-6) }
            for j in positions.indices where j != i { XCTAssertGreaterThan(distance(p,positions[j]),2*BallPhysics.radius) }
            rows.append(["ball":numbers[i],"key":"_\(numbers[i])","xzMeters":point(p),"pocket":pocket.id,
                         "cushionClearanceMeters":clearance(p)-BallPhysics.radius])
        }
        let e=engine(nil)
        XCTAssertEqual(e.simulatePrediction(model:.appDefault,maxTime:30,highFidelityBounds:true),.settled)
        XCTAssertTrue(e.getTrajectoryRecorder().pocketEntries.isEmpty)
        for (i,p) in positions.enumerated() { XCTAssertLessThan(distance(try XCTUnwrap(e.getBall("_\(numbers[i])")).position,p),1e-7) }
        try write(["fixture":fixtureName,"units":"meters; XZ; portrait up=+X right=+Z",
                   "balls":rows,"radius":BallPhysics.radius,"model":"appDefault planarReference",
                   "cueBaselineXZ":[0,0],"velocityRange":[speedRange.lowerBound,speedRange.upperBound],
                   "miscueLimitFraction":CuePhysics.miscueLimitFraction],"fixture.json",to:out)
        try diagram(nil, to:out.appendingPathComponent("fixture.png"))
    }
    func testUniformSurvey() throws {
        let out=try output()
        defer {distanceOverride=nil}
        var rows:[[String:Any]]=[]
        for d:Float in [0.055,0.065,0.075,0.085,0.095,0.105,0.115,0.125,0.13] {
            distanceOverride=d
            let margins=positions.map{clearance($0)-BallPhysics.radius}
            let safe=positions.enumerated().allSatisfy{distance($0.element,geometry.pockets[pocketIndices[$0.offset]].center)>geometry.pockets[pocketIndices[$0.offset]].radius}
                && margins.allSatisfy{$0>0.001}
            var stationary=false
            if safe {
                let e=engine(nil)
                stationary=e.simulatePrediction(model:.appDefault,maxTime:30,highFidelityBounds:true) == .settled
                    && e.getTrajectoryRecorder().pocketEntries.isEmpty
                for (i,p) in positions.enumerated() {
                    XCTAssertEqual(distance(p,geometry.pockets[pocketIndices[i]].center),d,accuracy:1e-6)
                    XCTAssertLessThan(distance(try XCTUnwrap(e.getBall("_\(numbers[i])")).position,p),1e-7)
                }
            }
            rows.append(["distance":d,"fixture":fixtureName,"minimumCushionMargin":margins.min()!,
                         "valid":safe && stationary,"balls":positions.enumerated().map{["number":numbers[$0.offset],"xz":point($0.element)] as [String:Any]}])
        }
        XCTAssertTrue(rows.contains{($0["valid"] as? Bool)==true})
        try write(rows,"uniform-survey.json",to:out)
    }
    @MainActor
    func testFixtureScene() throws {
        let out=try output()
        let scene=AngleTrainingScene();scene.setupScene()
        scene.hideAllBalls()
        for (i,p) in positions.enumerated() { scene.showBall(key:"_\(numbers[i])",scenePosition:p) }
        scene.showBall(key:PositionPlayBall.cueKey,scenePosition:SCNVector3Zero)
        XCTAssertEqual(scene.visibleBalls().count,7)
        let camera=try XCTUnwrap(scene.cameraNode)
        camera.camera?.usesOrthographicProjection=true
        camera.camera?.projectionDirection = .vertical
        camera.camera?.orthographicScale=1.58
        camera.camera?.wantsExposureAdaptation=false
        camera.position=SCNVector3(0,scene.surfaceY+4,0)
        camera.look(at:SCNVector3(0,scene.surfaceY,0),up:SCNVector3(1,0,0),localFront:SCNVector3(0,0,-1))
        let renderer=SCNRenderer(device:nil,options:nil)
        renderer.scene=scene;renderer.pointOfView=camera
        renderer.autoenablesDefaultLighting=false;renderer.delegate=scene.contactOcclusion
        SCNTransaction.flush()
        let img=renderer.snapshot(atTime:0,with:CGSize(width:1080,height:1920),antialiasingMode:.multisampling4X)
        try XCTUnwrap(img.pngData()).write(to:out.appendingPathComponent("fixture-scene.png"))
        for (i,p) in positions.enumerated() {
            let actual=try XCTUnwrap(scene.allBallNodes["_\(numbers[i])"]).position
            XCTAssertLessThan(distance(actual,p),1e-7)
            XCTAssertEqual(actual.y,scene.surfaceY+BallPhysics.radius)
        }
    }
    private struct Result {
        var q:[Float]; var score:Float; var count:Int; var scratch:Bool; var mask:Int; var cueCushions:Int
        var termination:EventDrivenEngine.Termination
        var route: String = ""
        var gapLoss: Double = 1000
        var feasibilityLoss: Double = 1000
        var deficits: [Double] = []
    }
    private func valid(_ q:[Float]) -> Bool {
        guard q.allSatisfy({$0.isFinite}),abs(q[0])<TablePhysics.innerLength/2-BallPhysics.radius,
              abs(q[1])<TablePhysics.innerWidth/2-BallPhysics.radius,
              speedRange.contains(Double(q[3])),
              q[4]*q[4]+q[5]*q[5]<=CuePhysics.miscueLimitFraction*CuePhysics.miscueLimitFraction else { return false }
        let p=SCNVector3(q[0],y,q[1])
        return positions.allSatisfy({distance($0,p)>2*BallPhysics.radius+0.001}) && clearance(p)>BallPhysics.radius+0.001
    }
    private func evaluate(_ q:[Float], save:URL?=nil) throws -> Result {
        guard valid(q) else { return Result(q:q,score:-10000,count:0,scratch:false,mask:0,cueCushions:0,termination:.candidateRejected) }
        evaluationSimulationCalls += 1
        let e=engine(q)
        var term=e.simulatePrediction(model:.appDefault,maxEvents:4000,maxTime:90,highFidelityBounds:true)
        term=e.completePlanarSpinTail(after:term,surfaceY:y)
        let rec=e.getTrajectoryRecorder()
        let count=numbers.filter { rec.isBallPocketed("_\($0)") }.count
        let scratch=rec.isBallPocketed(ShotInput.cueBallName)
        var score=Float(count)*100 - (scratch ? 40 : 0)
        let cue=rec.framesByBallName[ShotInput.cueBallName] ?? []
        // Geometric distance only guides exploration. It never establishes a pot or success.
        for (i,p) in positions.enumerated() where !rec.isBallPocketed("_\(numbers[i])") {
            var nearest:Float=3
            for (a,b) in zip(cue,cue.dropFirst()) { nearest=min(nearest,segmentDistance(p,a.position,b.position)) }
            score -= min(2,max(0,nearest-2*BallPhysics.radius))*8
            if let final=e.getBall("_\(numbers[i])") {
                score -= min(2,distance(final.position,geometry.pockets[pocketIndices[i]].center))*3
            }
        }
        if env("SIX_SOFT_SCORE") == "1" {
            // Continuous search loss permits a near-miss on one pocket while improving another.
            // Capture itself is still established exclusively by production pocket events.
            score = scratch ? -100 : 0
            for number in numbers where !rec.isBallPocketed("_\(number)") {
                var gap=Float.infinity
                for frame in rec.framesByBallName["_\(number)"] ?? [] {
                    for pocket in geometry.pockets { gap=min(gap,max(0,distance(frame.position,pocket.center)-pocket.radius)) }
                }
                score -= 1000*gap*gap
            }
        }
        var gapLoss=Double(0)
        if env("SIX_ROUTE_SCORE") == "1" {
            score=Float(count)*100 - (scratch ? 1000 : 0)
            for (i,p) in positions.enumerated() where !rec.isBallPocketed("_\(numbers[i])") {
                let frames=rec.framesByBallName["_\(numbers[i])"] ?? []
                var gap=Float.infinity
                for pocket in geometry.pockets {
                    var closest=distance(p,pocket.center)
                    for (a,b) in zip(frames,frames.dropFirst()) {
                        closest=min(closest,segmentDistance(pocket.center,a.position,b.position))
                    }
                    gap=min(gap,max(0,closest-pocket.radius))
                }
                score -= 50*min(1,gap)
                gapLoss += Double(gap)
                // A stationary missed ball has constant pocket gap. Retain an approach
                // hint so five-pot candidates can improve before making the sixth contact.
                var approach:Float=3
                for (a,b) in zip(cue,cue.dropFirst()) {approach=min(approach,segmentDistance(p,a.position,b.position))}
                score -= 2*max(0,approach-2*BallPhysics.radius)
            }
        }
        if env("SIX_FINISH_SCORE") == "1" {
            // Local completion stage: a transit ball must finish in a pocket, not merely
            // have started near one before delivering other balls.
            gapLoss=0
            for number in numbers where !rec.isBallPocketed("_\(number)") {
                if let ball=e.getBall("_\(number)") {
                    let gap=geometry.pockets.map{max(0,distance(ball.position,$0.center)-$0.radius)}.min() ?? 3
                    gapLoss+=Double(gap)
                } else {gapLoss+=3}
            }
            score=Float(count)*100-Float(gapLoss)*50-(scratch ? 1000 : 0)
        }
        if term != .settled { score -= 500 }
        let mask=numbers.enumerated().reduce(0) { $0 | (rec.isBallPocketed("_\($1.element)") ? (1 << $1.offset) : 0) }
        if let required=env("SIX_REQUIRED_POT_MASK").flatMap(Int.init), mask & required != required {
            // Local completion only: preserve the already achieved pot constraints.
            score -= 2000
        }
        let cushions=e.resolvedEvents.filter { event in
            if case let .ballCushion(ball,_,_)=event { return ball==ShotInput.cueBallName };return false
        }.count
        let route=e.resolvedEvents.compactMap { event -> String? in
            switch event {
            case let .ballBall(a,b): return "B:"+[a,b].sorted().joined(separator:",")
            case let .ballCushion(ball,index,_) where ball==ShotInput.cueBallName: return "C:\(index)"
            default: return nil
            }
        }.prefix(24).joined(separator:"/")+"|\(mask)"
        var deficits:[Double]=[],constraintRows:[[String:Any]]=[]
        if env("SIX_FEASIBILITY_SCORE") == "1" {
            for (i,p) in positions.enumerated() {
                let name="_\(numbers[i])",potted=rec.isBallPocketed(name)
                let touched=e.resolvedEvents.contains { event in
                    if case let .ballBall(a,b)=event {return a==name || b==name};return false
                }
                var baseline=Float.infinity,gap=Float.infinity,approach:Float=3
                var nearestActor=""
                let frames=rec.framesByBallName[name] ?? []
                for pocket in geometry.pockets {
                    baseline=min(baseline,max(0,distance(p,pocket.center)-pocket.radius))
                    var closest=distance(p,pocket.center)
                    for (a,b) in zip(frames,frames.dropFirst()) {closest=min(closest,segmentDistance(pocket.center,a.position,b.position))}
                    gap=min(gap,max(0,closest-pocket.radius))
                }
                if touched {approach=0}
                else {
                    // Untouched target is stationary. All other balls can deliver the hit.
                    for (actor,path) in rec.framesByBallName where actor != name {
                        for (a,b) in zip(path,path.dropFirst()) {
                            let separation=max(0,segmentDistance(p,a.position,b.position)-2*BallPhysics.radius)
                            if separation<approach {approach=separation;nearestActor=actor}
                        }
                    }
                }
                let deficit=potted ? 0 : max(1e-5,Double(gap/max(1e-6,baseline)))
                    + 0.5*Double(approach/(approach+2*BallPhysics.radius))
                deficits.append(deficit)
                constraintRows.append(["ball":numbers[i],"potted":potted,"touched":touched,
                    "initialPocketGap":baseline,"remainingPocketGap":gap,"contactGap":approach,
                    "nearestPotentialActor":nearestActor,"deficit":deficit])
            }
        }
        let feasibility=deficits.isEmpty ? 1000 : (deficits.max() ?? 0)+0.25*deficits.reduce(0,+)/6
            + (scratch ? 2 : 0) + (term == .settled ? 0 : 10)
        if env("SIX_FEASIBILITY_SCORE") == "1" {score = -Float(feasibility)}
        let result=Result(q:q,score:score,count:count,scratch:scratch,mask:mask,cueCushions:cushions,termination:term,route:route,gapLoss:gapLoss,feasibilityLoss:feasibility,deficits:deficits)
        if let save {
            let trajectories=rec.framesByBallName.mapValues { frames in frames.map { f in
                ["t":f.time,"x":f.position.x,"z":f.position.z,"vx":f.velocity.x,"vz":f.velocity.z,
                 "wx":f.angularVelocity.x,"wy":f.angularVelocity.y,"wz":f.angularVelocity.z]
            } }
            try write(["fixture":fixtureName,"parameters":q,"parameterOrder":["cueX","cueZ","aimRadians","cueSpeed","spinX","spinY"],
                       "scoreMode":env("SIX_FEASIBILITY_SCORE") == "1" ? "normalized-six-constraint-deficits" : (env("SIX_FINISH_SCORE") == "1" ? "completion-final-position-gap" : (env("SIX_ROUTE_SCORE") == "1" ? "pot-count-and-pocket-gap" : (env("SIX_SOFT_SCORE") == "1" ? "squared-pocket-gap" : "pot-count-and-distance"))),
                       "feasibilityLoss":feasibility,"constraintDeficits":constraintRows,
                       "route":route,
                       "gapLossMeters":gapLoss,
                       "cueCushions":cushions,"score":score,"potted":count,"scratch":scratch,"termination":String(describing:term),
                       "success":count==6 && !scratch && term == .settled,
                       "resolvedEvents":e.resolvedEvents.map { String(describing:$0) },
                       "pocketEvents":rec.pocketEntries.map { ["ball":$0.ball.name,"pocket":$0.pocketID,"time":$0.time] as [String:Any] },
                       "trajectories":trajectories],"best.json",to:save)
            try diagram(rec,to:save.appendingPathComponent("best.png"),cue:SCNVector3(q[0],y,q[1]))
        }
        return result
    }
    private struct RNG {
        var state:UInt64=20260917
        mutating func next() -> Float {
            state=state &* 6364136223846793005 &+ 1442695040888963407
            return Float((state >> 40) & 0xffffff)/Float(0x1000000)
        }
        mutating func index(_ n:Int) -> Int { min(n-1,Int(next()*Float(n))) }
    }
    private func seed(_ rng:inout RNG, fixed:Bool) -> [Float] {
        let i=rng.index(6), p=positions[i], pk=geometry.pockets[pocketIndices[i]].center
        let toward=atan2f(pk.z-p.z,pk.x-p.x)
        let normal=toward+(rng.next()-0.5)*0.6
        let incoming=toward+(rng.next()-0.5)*2.8
        let d:Float=0.08+rng.next()*2.5
        var x=p.x-2*BallPhysics.radius*cosf(normal)-d*cosf(incoming)
        var z=p.z-2*BallPhysics.radius*sinf(normal)-d*sinf(incoming)
        if fixed { x=0;z=0 }
        let sx=(rng.next()-0.5)*0.95,sy=(rng.next()-0.5)*0.95
        let target=SCNVector3(p.x-2*BallPhysics.radius*cosf(normal),y,p.z-2*BallPhysics.radius*sinf(normal))
        let angle=atan2f(target.z-z,target.x-x)
        let strike=CueBallStrike.executeStrike(aimDirection:SCNVector3(1,0,0),velocity:3,spinX:sx,spinY:sy)
        let compensation=atan2f(strike.velocity.z,strike.velocity.x)
        return [x,z,angle-compensation,seedMinimumSpeed+rng.next()*(Float(speedRange.upperBound)-seedMinimumSpeed),sx,sy]
    }
    func testSearch() throws {
        let out=try output(), started=Date()
        let budget=Double(env("SIX_SEARCH_SECONDS") ?? "180") ?? 180
        let limit=Int(env("SIX_SEARCH_TRIALS") ?? "50000") ?? 50000
        let fixed=env("SIX_FIXED_CUE") == "1"
        var rng=RNG(), trials=0, population:[Result]=[], best:Result?
        var niches:[Int:Result]=[:]
        var speedBands=[Int](repeating:0,count:11)
        var minimums=[Float](repeating:.infinity,count:6)
        var maximums=[Float](repeating:-.infinity,count:6)
        if let value=env("SIX_SEARCH_SEED"),let s=UInt64(value) { rng.state=s }
        let initialSeed=rng.state
        let size=192
        func run(_ q:[Float]) throws -> Result {
            trials+=1
            speedBands[min(10,max(0,Int(q[3])))]+=1
            for j in 0..<6 { minimums[j]=min(minimums[j],q[j]);maximums[j]=max(maximums[j],q[j]) }
            let r=try autoreleasepool { try evaluate(q) }
            if !r.scratch && r.termination == .settled && r.score > (niches[r.mask]?.score ?? -Float.infinity) { niches[r.mask]=r }
            if r.score > (best?.score ?? -Float.infinity) {
                best=r
                _=try evaluate(q,save:out)
                print("SIX BEST trials=\(trials) pots=\(r.count) scratch=\(r.scratch) score=\(r.score) elapsed=\(Date().timeIntervalSince(started))")
            }
            return r
        }
        if let source=env("SIX_RESUME_JSON") {
            let saved=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:source))) as? [String:Any])
            XCTAssertEqual(saved["fixture"] as? String,fixtureName)
            let q=try XCTUnwrap(saved["parameters"] as? [NSNumber]).map { $0.floatValue }
            XCTAssertEqual(q.count,6)
            if valid(q) && (!fixed || (q[0]==0 && q[1]==0)) { population.append(try run(q)) }
        }
        while population.count<size && Date().timeIntervalSince(started)<budget {
            let q=seed(&rng,fixed:fixed)
            if valid(q) { population.append(try run(q)) }
        }
        var generation=0
        while trials<limit && Date().timeIntervalSince(started)<budget && population.count==size {
            generation+=1
            let ranked=population.sorted{$0.score>$1.score}
            for i in 0..<size {
                if trials>=limit || Date().timeIntervalSince(started)>=budget { break }
                var q=population[i].q
                if rng.next()<0.15 { q=seed(&rng,fixed:fixed) }
                else if rng.next()<0.5 {
                    let archive=niches.keys.sorted().compactMap { niches[$0] }
                    q = !archive.isEmpty && rng.next()<0.5 ? archive[rng.index(archive.count)].q : ranked[rng.index(24)].q
                    let scale=powf(10,-rng.next()*3)
                    let ranges:[Float]=[0.5,0.3,1.2,3,0.5,0.5]
                    for j in 0..<6 { q[j]+=(rng.next()-0.5)*ranges[j]*scale }
                } else {
                    let a=population[rng.index(size)].q,b=population[rng.index(size)].q,c=population[rng.index(size)].q
                    let forced=rng.index(6),f:Float=0.3+rng.next()*0.6
                    for j in 0..<6 where j==forced || rng.next()<0.7 { q[j]=a[j]+f*(b[j]-c[j]) }
                }
                if fixed { q[0]=0;q[1]=0 }
                if !valid(q) { continue }
                let r=try run(q)
                if r.score>population[i].score { population[i]=r }
                if r.count==6 && !r.scratch && r.termination == .settled { break }
            }
            if let r=best,r.count==6 && !r.scratch && r.termination == .settled { break }
            if generation % 10 == 0 { print("SIX generation=\(generation) trials=\(trials)") }
        }
        let r=try XCTUnwrap(best)
        let repeatResult=try evaluate(r.q,save:out)
        XCTAssertEqual(r.score,repeatResult.score)
        XCTAssertEqual(r.count,repeatResult.count)
        try write(["trials":trials,"generations":generation,"seconds":Date().timeIntervalSince(started),
                   "seed":initialSeed,"fixedCue":fixed,"coverageMasks":niches.keys.sorted(),"bestPotted":r.count,"scratch":r.scratch,
                   "searchMaxSpeed":speedRange.upperBound,"seedMinimumSpeed":seedMinimumSpeed,
                   "evaluationsByFloorSpeed":speedBands,"parameterMinimums":minimums,"parameterMaximums":maximums,
                   "success":r.count==6 && !r.scratch && r.termination == .settled,
                   "scope":"bounded stochastic search; failure to find is not proof of impossibility"],"search-summary.json",to:out)
    }
    /// Isolated post-impact reachability probe, never a complete-shot success claim.
    func testTerminalConstraint() throws {
        let out=try output(),source=try XCTUnwrap(env("SIX_RESUME_JSON"))
        let saved=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:source))) as? [String:Any])
        let q=try XCTUnwrap(saved["parameters"] as? [NSNumber]).map{$0.floatValue}
        let e=engine(q)
        XCTAssertEqual(e.simulatePrediction(model:.appDefault,maxEvents:2000,maxTime:45,highFidelityBounds:true),.settled)
        let rec=e.getTrajectoryRecorder()
        let missing=numbers.filter{!rec.isBallPocketed("_\($0)")}
        XCTAssertEqual(missing.count,1)
        let number=try XCTUnwrap(missing.first),name="_\(number)"
        let frame=try XCTUnwrap(rec.framesByBallName[name]?.first{hypotf($0.velocity.x,$0.velocity.z)>0.001})
        let speed=hypotf(frame.velocity.x,frame.velocity.z),angle=atan2f(frame.velocity.z,frame.velocity.x)
        func captured(_ factor:Float,_ offset:Float)->Bool {
            let probe=EventDrivenEngine(tableGeometry:geometry)
            let w=frame.angularVelocity
            let angular=SCNVector3((w.x*cosf(offset)-w.z*sinf(offset))*factor,w.y*factor,
                                  (w.x*sinf(offset)+w.z*cosf(offset))*factor)
            probe.setBall(BallState(position:frame.position,
                velocity:SCNVector3(speed*factor*cosf(angle+offset),0,speed*factor*sinf(angle+offset)),
                angularVelocity:angular,state:frame.state,name:name))
            let end=probe.simulatePrediction(model:.appDefault,maxEvents:2000,maxTime:45,highFidelityBounds:true)
            return end == .settled && probe.getTrajectoryRecorder().isBallPocketed(name)
        }
        XCTAssertFalse(captured(1,0))
        var rows:[[String:Any]]=[]
        for degrees in stride(from:-24,through:24,by:2) {
            let offset=Float(degrees)*Float.pi/180
            // Scan before bisection: cushion/jaw outcomes need not be globally monotonic.
            var previous:Float=0.5,found:Float?
            for k in 1...175 {
                let f=0.5+Float(k)*0.02
                if captured(f,offset) {
                    var low=previous,high=f
                    for _ in 0..<14 { let mid=(low+high)/2;if captured(mid,offset) {high=mid}else{low=mid} }
                    found=high;break
                }
                previous=f
            }
            if let factor=found { rows.append(["angleOffsetDegrees":degrees,"speedFactor":factor,"targetSpeed":speed*factor]) }
        }
        try write(["ball":number,"postImpactTime":frame.time,"observedTargetSpeed":speed,
                   "observedDirectionRadians":angle,"thresholdSamples":rows,
                   "scope":"isolated target after impact; velocity and angular velocity scale together; local brackets only; not a feasible full shot or cue-speed bound"],"terminal-constraint.json",to:out)
    }
    /// Finite-difference trust-region descent with the successful collision prefix retained.
    func testConstrainedSearch() throws {
        let out=try output(),started=Date()
        XCTAssertEqual(env("SIX_ROUTE_SCORE"),"1")
        let budget=Double(env("SIX_SEARCH_SECONDS") ?? "300") ?? 300
        let source=try XCTUnwrap(env("SIX_CANDIDATES_JSON"))
        let rows=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:source))) as? [[String:Any]])
        var trials=0,best:Result?,summaries:[[String:Any]]=[]
        let scales:[Float]=[0.1,0.1,0.1,1,0.1,0.1]
        func run(_ q:[Float]) throws -> Result? {
            guard valid(q) else {return nil}
            trials+=1
            let r=try autoreleasepool{try evaluate(q)}
            if !r.scratch && r.termination == .settled && (r.count>(best?.count ?? -1) || (r.count==best?.count && r.gapLoss<(best?.gapLoss ?? .infinity))) {
                best=r;_=try evaluate(q,save:out)
                print("SIX CONSTRAINT trials=\(trials) pots=\(r.count) gap=\(r.gapLoss)")
            }
            return r
        }
        for row in rows where (row["potted"] as? Int)==5 {
            if Date().timeIntervalSince(started)>=budget || best?.count==6 {break}
            let q=try XCTUnwrap(row["parameters"] as? [NSNumber]).map{$0.floatValue}
            guard var current=try run(q),current.count==5,!current.scratch else {continue}
            let initial=current
            let missing=try XCTUnwrap(numbers.enumerated().first{current.mask & (1 << $0.offset)==0}).element
            let parts=current.route.split(separator:"|")[0].split(separator:"/").map(String.init)
            guard let last=parts.firstIndex(where:{$0.hasPrefix("B:") && $0.dropFirst(2).split(separator:",").contains(Substring("_\(missing)"))}) else {continue}
            let prefix=parts.prefix(last+1).joined(separator:"/")
            func acceptable(_ r:Result)->Bool {
                !r.scratch && r.termination == .settled && (r.count==6 || (r.mask==initial.mask && r.route.hasPrefix(prefix)))
            }
            var radius:Float=0.03,steps=0
            for iteration in 0..<80 {
                if Date().timeIntervalSince(started)>=budget || best?.count==6 {break}
                steps+=1
                let h:Float=[0.001,0.0003,0.0001,0.00003][iteration % 4]
                var gradient=[Double](repeating:0,count:6),neighbor=current
                for j in 0..<6 {
                    var plus=current.q,minus=current.q;plus[j]+=scales[j]*h;minus[j]-=scales[j]*h
                    let a=try run(plus),b=try run(minus)
                    let goodA=a.map(acceptable) ?? false,goodB=b.map(acceptable) ?? false
                    if let a,goodA,a.gapLoss<neighbor.gapLoss {neighbor=a}
                    if let b,goodB,b.gapLoss<neighbor.gapLoss {neighbor=b}
                    if let a,let b,goodA,goodB {gradient[j]=(a.gapLoss-b.gapLoss)/(2*Double(h))}
                    else if let a,goodA {gradient[j]=(a.gapLoss-current.gapLoss)/Double(h)}
                    else if let b,goodB {gradient[j]=(current.gapLoss-b.gapLoss)/Double(h)}
                }
                let norm=sqrt(gradient.reduce(0){$0+$1*$1})
                if norm>1e-12 {
                    for k in 0..<12 {
                        let alpha=Double(radius)*pow(0.5,Double(k))
                        let candidate=(0..<6).map{current.q[$0]-Float(alpha*gradient[$0]/norm)*scales[$0]}
                        if let r=try run(candidate),acceptable(r),r.gapLoss<neighbor.gapLoss {neighbor=r;break}
                    }
                }
                if neighbor.gapLoss<current.gapLoss-1e-8 {current=neighbor;radius=min(0.1,radius*1.3)}
                else {radius*=0.5}
                if radius<0.000001 {break}
            }
            summaries.append(["route":initial.route,"beforeGap":initial.gapLoss,"afterGap":current.gapLoss,"steps":steps,"parameters":current.q])
        }
        let r=try XCTUnwrap(best),repeated=try evaluate(r.q,save:out)
        XCTAssertEqual(r.gapLoss,repeated.gapLoss);XCTAssertEqual(r.count,repeated.count)
        try write(summaries,"constraint-routes.json",to:out)
        try write(["algorithm":"collision-prefix constrained finite-difference trust region","trials":trials,
                   "routesRefined":summaries.count,"bestPotted":r.count,"gapLossMeters":r.gapLoss,
                   "searchMaxSpeed":speedRange.upperBound,"seconds":Date().timeIntervalSince(started),
                   "success":r.count==6 && !r.scratch && r.termination == .settled],"search-summary.json",to:out)
    }
    func testFeasibilityAudit() throws {
        let out=try output();XCTAssertEqual(env("SIX_FEASIBILITY_SCORE"),"1")
        defer {distanceOverride=nil}
        let source=try XCTUnwrap(env("SIX_CANDIDATES_JSON"))
        let rows=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:source))) as? [[String:Any]])
        var results:[(r:Result,d:Float)]=[]
        for row in rows {
            let q=try XCTUnwrap(row["parameters"] as? [NSNumber]).map{$0.floatValue}
            let d=(row["commonDistanceMeters"] as? NSNumber)?.floatValue ?? 0.055
            distanceOverride=d
            guard valid(q) else {continue}
            let r=try autoreleasepool{try evaluate(q)}
            XCTAssertEqual(r.deficits.count,6)
            XCTAssertTrue(r.deficits.allSatisfy{$0.isFinite && $0>=0})
            results.append((r,d))
        }
        results.sort{$0.r.feasibilityLoss<$1.r.feasibilityLoss}
        let objective=try XCTUnwrap(results.first)
        let incumbent=try XCTUnwrap(results.filter{!$0.r.scratch && $0.r.termination == .settled}.sorted{
            $0.r.count == $1.r.count ? $0.r.feasibilityLoss<$1.r.feasibilityLoss : $0.r.count>$1.r.count
        }.first)
        XCTAssertGreaterThanOrEqual(incumbent.r.count,5)
        for (name,candidate) in [("objective",objective),("incumbent",incumbent)] {
            let folder=out.appendingPathComponent(name);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            distanceOverride=candidate.d
            let repeated=try evaluate(candidate.r.q,save:folder)
            XCTAssertEqual(repeated.feasibilityLoss,candidate.r.feasibilityLoss)
        }
        try write(results.map{["parameters":$0.r.q,"commonDistanceMeters":$0.d,"potted":$0.r.count,
            "loss":$0.r.feasibilityLoss,"deficits":$0.r.deficits,"route":$0.r.route] as [String:Any]},"feasibility-candidates.json",to:out)
        try write(["evaluations":results.count,"bestPotCount":incumbent.r.count,
                   "lowestLossPotCount":objective.r.count,"lowestLoss":objective.r.feasibilityLoss,
                   "incumbentLoss":incumbent.r.feasibilityLoss],"objective-audit.json",to:out)
    }
    /// Smoothed full-covariance cross-entropy distribution, not an implementation of CMA-ES.
    private struct AdaptiveGaussian {
        var mean:[Double]
        var covariance:[[Double]]
        init(_ center:[Double],sigma:Double) {
            mean=center
            covariance=center.indices.map{i in center.indices.map{j in i==j ? sigma*sigma : 0}}
        }
        func sample(_ rng:inout RNG)->[Double] {
            let n=mean.count
            var l=Array(repeating:[Double](repeating:0,count:n),count:n)
            for i in 0..<n {for j in 0...i {
                var sum=covariance[i][j]
                if j>0 {for k in 0..<j {sum-=l[i][k]*l[j][k]}}
                l[i][j]=i==j ? sqrt(max(1e-14,sum)) : sum/l[j][j]
            }}
            let z=(0..<n).map{_ in sqrt(-2*log(max(1e-12,Double(rng.next()))))*cos(2*Double.pi*Double(rng.next()))}
            var sample=mean
            for i in 0..<n {for j in 0...i {sample[i]+=l[i][j]*z[j]}}
            return sample
        }
        mutating func update(_ elites:[[Double]]) {
            guard !elites.isEmpty else {return}
            let n=mean.count,m=Double(elites.count)
            let center=(0..<n).map{i in elites.reduce(0){$0+$1[i]}/m}
            for i in 0..<n {for j in 0..<n {
                let empirical=elites.reduce(0){$0+($1[i]-center[i])*($1[j]-center[j])}/m
                let drift=(center[i]-mean[i])*(center[j]-mean[j])
                covariance[i][j]=0.75*covariance[i][j]+0.25*empirical+0.1*drift+(i==j ? 1e-12 : 0)
            }}
            mean=(0..<n).map{0.5*mean[$0]+0.5*center[$0]}
        }
    }
    func testAdaptiveDistribution() throws {
        let out=try output()
        var rng=RNG(),distribution=AdaptiveGaussian([3,2],sigma:1),best=Double.infinity,strongestCorrelation=Double(0)
        for _ in 0..<180 {
            let samples=(0..<32).map{_ in distribution.sample(&rng)}
            func loss(_ x:[Double])->Double {1000*pow(x[0]+x[1]+0.4,2)+pow(x[0]-x[1]-1,2)}
            let ranked=samples.sorted{loss($0)<loss($1)}
            best=min(best,loss(ranked[0]));distribution.update(Array(ranked.prefix(8)))
            let c=distribution.covariance
            strongestCorrelation=max(strongestCorrelation,abs(c[0][1]/sqrt(c[0][0]*c[1][1])))
        }
        XCTAssertLessThan(best,1e-4)
        XCTAssertGreaterThan(strongestCorrelation,0.9)
        try write(["rotatedQuadraticMinimum":best,"strongestAbsoluteCorrelation":strongestCorrelation,
                   "scope":"optimizer numerical check only, not billiards feasibility"],"adaptive-distribution-check.json",to:out)
    }
    /// A pre-expanded two-level UCB region tree. This is not an implementation of HOO.
    private struct RegionTree {
        var visits=[Int](repeating:0,count:16)
        var rewardSums=[Double](repeating:0,count:16)
        func select() -> Int {
            if let unvisited=visits.firstIndex(of:0) {return unvisited}
            let total=visits.reduce(0,+)
            func ucb(_ sum:Double,_ n:Int,_ parent:Int)->Double {
                sum/Double(n)+0.2*sqrt(log(Double(parent+1))/Double(n))
            }
            var group=0,groupScore = -Double.infinity
            for g in 0..<4 {
                let ids=(g*4)..<(g*4+4),n=ids.reduce(0){$0+visits[$1]},sum=ids.reduce(0.0){$0+rewardSums[$1]}
                let score=ucb(sum,n,total)
                if score>groupScore {group=g;groupScore=score}
            }
            let ids=(group*4)..<(group*4+4),parent=ids.reduce(0){$0+visits[$1]}
            var selected=group*4,score = -Double.infinity
            for i in ids {
                let candidate=ucb(rewardSums[i],visits[i],parent)
                if candidate>score {selected=i;score=candidate}
            }
            return selected
        }
        mutating func record(_ index:Int,_ reward:Double) {
            visits[index]+=1;rewardSums[index]+=reward
        }
    }
    func testRegionTreeScheduler() throws {
        let out=try output();var tree=RegionTree()
        for _ in 0..<500 {let i=tree.select();tree.record(i,i==6 ? 0.9 : 0.2)}
        XCTAssertTrue(tree.visits.allSatisfy{$0>0})
        XCTAssertGreaterThan(tree.visits[6],250)
        XCTAssertEqual(tree.visits.reduce(0,+),500)
        try write(["visits":tree.visits,"scope":"selection and backup check, not billiards success"],"tree-scheduler-check.json",to:out)
    }
    func testRegionComparison() throws {
        let out=try output(),started=Date(),callsAtStart=evaluationSimulationCalls
        defer {distanceOverride=nil}
        XCTAssertEqual(env("SIX_FEASIBILITY_SCORE"),"1")
        let policy=env("SIX_REGION_POLICY") ?? "tree"
        XCTAssertTrue(["tree","round-robin"].contains(policy))
        let initialSeed=UInt64(env("SIX_SEARCH_SEED") ?? "2026091792") ?? 2026091792
        let limit=Int(env("SIX_SEARCH_TRIALS") ?? "10000") ?? 10000
        let budget=Double(env("SIX_SEARCH_SECONDS") ?? "180") ?? 180
        let source=try XCTUnwrap(env("SIX_CANDIDATES_JSON"))
        let rows=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:source))) as? [[String:Any]])
        let widths:[Double]=[Double(TablePhysics.innerLength),Double(TablePhysics.innerWidth),2*Double.pi,speedRange.upperBound,1,1,0.075]
        func encode(_ q:[Float],_ d:Float)->[Double] {
            var x=(q+[d-0.055]).enumerated().map{Double($0.element)/widths[$0.offset]}
            // Canonical periodic direction; actual decoded parameters are always re-simulated.
            x[2]=atan2(sin(Double(q[2])),cos(Double(q[2])))/(2*Double.pi)
            return x
        }
        func decode(_ x:[Double])->([Float],Float) {((0..<6).map{Float(x[$0]*widths[$0])},Float(0.055+x[6]*0.075))}
        func cellID(_ x:[Double])->Int {min(3,max(0,Int(x[6]*4)))*4+min(3,max(0,Int((x[2]+0.5)*4)))}
        var trials=0,attempts=0,duplicates=0,seen=Set<String>()
        var incumbent:(r:Result,d:Float)?,objective:(r:Result,d:Float)?
        var progress:[[String:Any]]=[]
        func run(_ x:[Double]) throws -> Result? {
            attempts+=1
            guard trials<limit,x.allSatisfy({$0.isFinite}) else {return nil}
            let (q,d)=decode(x)
            guard (0.055...0.13).contains(d) else {return nil};distanceOverride=d
            guard valid(q),positions.allSatisfy({clearance($0)>BallPhysics.radius+0.001}) else {return nil}
            let identity=(q+[d]).map{String($0.bitPattern)}.joined(separator:",")
            guard seen.insert(identity).inserted else {duplicates+=1;return nil}
            trials+=1
            let r=try autoreleasepool{try evaluate(q)}
            if r.feasibilityLoss<(objective?.r.feasibilityLoss ?? .infinity) {
                objective=(r,d)
                print("SIX REGION policy=\(policy) trials=\(trials) loss=\(r.feasibilityLoss) pots=\(r.count)")
            }
            if !r.scratch && r.termination == .settled && (r.count>(incumbent?.r.count ?? -1) ||
                (r.count==incumbent?.r.count && r.feasibilityLoss<(incumbent?.r.feasibilityLoss ?? .infinity))) {incumbent=(r,d)}
            if trials % 1000 == 0 {progress.append(["trials":trials,"bestPotted":incumbent?.r.count ?? 0,"lowestLoss":objective?.r.feasibilityLoss ?? 1000])}
            return r
        }
        struct Cell {
            var low:[Double];var high:[Double];var distribution:AdaptiveGaussian;var rng:RNG
            var bestX:[Double];var bestLoss:Double = .infinity;var stale:Int=0;var evaluations:Int=0
        }
        var cells:[Cell]=[]
        for i in 0..<16 {
            var low:[Double]=[-0.5,-0.5,-0.5,0.5/speedRange.upperBound,-0.5,-0.5,0]
            var high:[Double]=[0.5,0.5,0.5,1,0.5,0.5,1]
            low[6]=Double(i/4)/4;high[6]=Double(i/4+1)/4
            low[2] = -0.5+Double(i%4)/4;high[2]=low[2]+0.25
            let center=(0..<7).map{(low[$0]+high[$0])/2}
            var distribution=AdaptiveGaussian(center,sigma:0.12)
            for j in 0..<7 {distribution.covariance[j][j]=pow(0.12*(high[j]-low[j]),2)}
            var rng=RNG();rng.state=initialSeed &+ UInt64(i+1) &* 1000003
            cells.append(Cell(low:low,high:high,distribution:distribution,rng:rng,bestX:center))
        }
        for row in rows {
            let q=try XCTUnwrap(row["parameters"] as? [NSNumber]).map{$0.floatValue}
            let d=(row["commonDistanceMeters"] as? NSNumber)?.floatValue ?? 0.055,x=encode(q,d)
            if let r=try run(x) {
                let i=cellID(x)
                if r.feasibilityLoss<cells[i].bestLoss {
                    cells[i].bestLoss=r.feasibilityLoss;cells[i].bestX=x
                    cells[i].distribution=AdaptiveGaussian(x,sigma:0.0003)
                }
            }
        }
        let initializationTrials=trials
        var tree=RegionTree(),batches=0
        while trials<limit && Date().timeIntervalSince(started)<budget && incumbent?.r.count != 6 {
            let index=policy=="tree" ? tree.select() : batches % 16
            var cell=cells[index],batch:[(x:[Double],loss:Double)]=[],tries=0
            while batch.count<24 && tries<1000 && trials<limit && Date().timeIntervalSince(started)<budget && incumbent?.r.count != 6 {
                tries+=1
                let x:[Double]
                if tries % 4 == 0 {x=(0..<7).map{cell.low[$0]+Double(cell.rng.next())*(cell.high[$0]-cell.low[$0])}}
                else {x=cell.distribution.sample(&cell.rng)}
                guard (0..<7).allSatisfy({x[$0]>=cell.low[$0] && x[$0]<=cell.high[$0]}) else {continue}
                if let r=try run(x) {batch.append((x,r.feasibilityLoss));cell.evaluations+=1}
            }
            batch.sort{$0.loss<$1.loss}
            if let first=batch.first {
                tree.record(index,1/(1+first.loss))
                if first.loss<cell.bestLoss-1e-9 {
                    cell.bestLoss=first.loss;cell.bestX=first.x;cell.stale=0
                    cell.distribution.update(batch.prefix(6).map{$0.x})
                } else {
                    cell.stale+=1;cell.distribution.mean=cell.bestX
                    for a in 0..<7 {for b in 0..<7 {cell.distribution.covariance[a][b]=0.5*cell.distribution.covariance[a][b]+(a==b ? 1e-14 : 0)}}
                }
            } else {tree.record(index,0)}
            cells[index]=cell;batches+=1
        }
        let searchCalls=evaluationSimulationCalls-callsAtStart
        XCTAssertEqual(searchCalls,trials)
        let winner=try XCTUnwrap(incumbent),lowest=try XCTUnwrap(objective)
        for (name,item) in [("incumbent",winner),("objective",lowest)] {
            let folder=out.appendingPathComponent(name);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            distanceOverride=item.d;let repeated=try evaluate(item.r.q,save:folder)
            XCTAssertEqual(repeated.feasibilityLoss,item.r.feasibilityLoss)
            try write(["commonDistanceMeters":item.d,"allSixBallsShareDistance":true],"selected-layout.json",to:folder)
        }
        try write(progress,"progress.json",to:out)
        try write(cells.enumerated().map{["index":$0.offset,"low":$0.element.low,"high":$0.element.high,
            "evaluations":$0.element.evaluations,"batches":tree.visits[$0.offset],"bestLoss":$0.element.bestLoss] as [String:Any]},"regions.json",to:out)
        try write(["policy":policy,"seed":initialSeed,"trials":trials,"searchPhysicsCalls":searchCalls,
            "totalPhysicsCallsIncludingVerification":evaluationSimulationCalls-callsAtStart,"initializationTrials":initializationTrials,
            "attempts":attempts,"duplicatesSkipped":duplicates,"batches":batches,"budgetReached":trials==limit,
            "bestPotted":winner.r.count,"bestPotLoss":winner.r.feasibilityLoss,"lowestLossPotCount":lowest.r.count,
            "lowestLoss":lowest.r.feasibilityLoss,"searchMaxSpeed":speedRange.upperBound,
            "seconds":Date().timeIntervalSince(started),"success":winner.r.count==6],"search-summary.json",to:out)
    }
    func testAdaptiveFeasibilitySearch() throws {
        let out=try output(),started=Date();XCTAssertEqual(env("SIX_FEASIBILITY_SCORE"),"1")
        defer {distanceOverride=nil}
        let source=try XCTUnwrap(env("SIX_CANDIDATES_JSON"))
        let rows=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:source))) as? [[String:Any]])
        let budget=Double(env("SIX_SEARCH_SECONDS") ?? "300") ?? 300
        let limit=Int(env("SIX_SEARCH_TRIALS") ?? "20000") ?? 20000
        var rng=RNG(),trials=0,seen=Set<String>(),best: (r:Result,d:Float)?,lowest: (r:Result,d:Float)?
        if let value=env("SIX_SEARCH_SEED"),let s=UInt64(value) {rng.state=s}
        let initialSeed=rng.state
        let widths:[Double]=[Double(TablePhysics.innerLength),Double(TablePhysics.innerWidth),2*Double.pi,speedRange.upperBound,1,1,0.075]
        func encode(_ q:[Float],_ d:Float)->[Double] {(q+[d-0.055]).enumerated().map{Double($0.element)/widths[$0.offset]}}
        func decode(_ x:[Double])->([Float],Float) {((0..<6).map{Float(x[$0]*widths[$0])},Float(0.055+x[6]*0.075))}
        func run(_ x:[Double]) throws -> Result? {
            guard x.allSatisfy({$0.isFinite}) else {return nil}
            let (q,d)=decode(x)
            guard (0.055...0.13).contains(d) else {return nil};distanceOverride=d
            guard valid(q),positions.allSatisfy({clearance($0)>BallPhysics.radius+0.001}) else {return nil}
            let identity=(q+[d]).map{String($0.bitPattern)}.joined(separator:",")
            guard seen.insert(identity).inserted else {return nil}
            trials+=1
            let r=try autoreleasepool{try evaluate(q)}
            if r.feasibilityLoss<(lowest?.r.feasibilityLoss ?? .infinity) {
                lowest=(r,d)
                print("SIX ADAPTIVE loss=\(r.feasibilityLoss) pots=\(r.count) trials=\(trials)")
            }
            if !r.scratch && r.termination == .settled && (r.count>(best?.r.count ?? -1) ||
                (r.count==best?.r.count && r.feasibilityLoss<(best?.r.feasibilityLoss ?? .infinity))) {
                best=(r,d);_=try evaluate(q,save:out)
                try write(["commonDistanceMeters":d,"allSixBallsShareDistance":true],"selected-layout.json",to:out)
            }
            return r
        }
        var seeds:[(x:[Double],r:Result)]=[]
        for row in rows {
            let q=try XCTUnwrap(row["parameters"] as? [NSNumber]).map{$0.floatValue}
            let d=(row["commonDistanceMeters"] as? NSNumber)?.floatValue ?? 0.055
            let x=encode(q,d);if let r=try run(x) {seeds.append((x,r))}
        }
        seeds.sort{$0.r.feasibilityLoss<$1.r.feasibilityLoss}
        struct Basin {var distribution:AdaptiveGaussian;var best:Double;var stale:Int=0}
        var basins:[Basin]=[],routes=Set<String>()
        for seed in seeds where basins.count<12 && routes.insert(seed.r.route).inserted {
            basins.append(Basin(distribution:AdaptiveGaussian(seed.x,sigma:[0.0003,0.003,0.03][basins.count % 3]),best:seed.r.feasibilityLoss))
        }
        XCTAssertFalse(basins.isEmpty)
        var generations=0,restarts=0
        while trials<limit && Date().timeIntervalSince(started)<budget && best?.r.count != 6 {
            for i in basins.indices {
                if trials>=limit || Date().timeIntervalSince(started)>=budget || best?.r.count==6 {break}
                var batch:[(x:[Double],r:Result)]=[],attempts=0
                while batch.count<24 && attempts<240 && trials<limit && Date().timeIntervalSince(started)<budget && best?.r.count != 6 {
                    attempts+=1
                    let x=basins[i].distribution.sample(&rng)
                    if let r=try run(x) {batch.append((x,r))}
                }
                batch.sort{$0.r.feasibilityLoss<$1.r.feasibilityLoss}
                if let first=batch.first {
                    if first.r.feasibilityLoss<basins[i].best-1e-7 {basins[i].best=first.r.feasibilityLoss;basins[i].stale=0}
                    else {basins[i].stale+=1}
                    basins[i].distribution.update(batch.prefix(6).map{$0.x})
                } else {basins[i].stale+=4}
                if basins[i].stale>=16 {
                    restarts+=1
                    var x:[Double]?
                    if restarts % 2 == 0 {x=seeds[rng.index(min(64,seeds.count))].x}
                    else {
                        for _ in 0..<1000 {
                            let d:Float=0.055+rng.next()*0.075;distanceOverride=d
                            let q=seed(&rng,fixed:false)
                            if valid(q) {x=encode(q,d);break}
                        }
                    }
                    if let x {basins[i]=Basin(distribution:AdaptiveGaussian(x,sigma:restarts % 2 == 0 ? 0.003 : 0.03),best:.infinity)}
                }
            }
            generations+=1
        }
        let winner=try XCTUnwrap(best),objective=try XCTUnwrap(lowest)
        distanceOverride=winner.d;let repeated=try evaluate(winner.r.q,save:out)
        XCTAssertEqual(repeated.feasibilityLoss,winner.r.feasibilityLoss)
        let folder=out.appendingPathComponent("objective-best");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        distanceOverride=objective.d;_=try evaluate(objective.r.q,save:folder)
        try write(["algorithm":"normalized all-ball deficits; multiple full-covariance cross-entropy basins",
                   "seed":initialSeed,"trials":trials,"generations":generations,"restarts":restarts,
                   "bestPotted":winner.r.count,"bestPotLoss":winner.r.feasibilityLoss,
                   "lowestLossPotCount":objective.r.count,"lowestLoss":objective.r.feasibilityLoss,
                   "commonDistanceMeters":winner.d,"searchMaxSpeed":speedRange.upperBound,
                   "seconds":Date().timeIntervalSince(started),"success":winner.r.count==6],"search-summary.json",to:out)
    }
    /// The only layout degree of freedom is one distance shared by all six balls.
    func testUniformSearch() throws {
        let out=try output(),started=Date(),initialDistance=try XCTUnwrap(commonDistance)
        defer {distanceOverride=nil}
        XCTAssertEqual(env("SIX_ROUTE_SCORE"),"1")
        let budget=Double(env("SIX_SEARCH_SECONDS") ?? "300") ?? 300
        struct Candidate {var result:Result;var distance:Float}
        var rng=RNG(),trials=0,best:Candidate?,archive:[String:Candidate]=[:],keys:[String]=[],five:[String]=[]
        if let value=env("SIX_SEARCH_SEED"),let s=UInt64(value) {rng.state=s}
        var seen=Set<String>(),minimumDistance:Float=1,maximumDistance:Float=0
        var speedBands=[Int](repeating:0,count:11)
        func run(_ q:[Float],_ d:Float) throws -> Candidate? {
            guard (0.055...0.13).contains(d) else {return nil}
            distanceOverride=d
            guard positions.allSatisfy({clearance($0)>BallPhysics.radius+0.001}),valid(q) else {return nil}
            let identity=(q+[d]).map{String($0.bitPattern)}.joined(separator:",")
            guard seen.insert(identity).inserted else {return nil}
            trials+=1;minimumDistance=min(minimumDistance,d);maximumDistance=max(maximumDistance,d)
            speedBands[min(10,max(0,Int(q[3])))]+=1
            let r=try autoreleasepool{try evaluate(q)},candidate=Candidate(result:r,distance:d)
            if !r.scratch && r.termination == .settled {
                if archive[r.route] == nil {keys.append(r.route);if r.count>=5 {five.append(r.route)}}
                if r.score>(archive[r.route]?.result.score ?? -.infinity) {archive[r.route]=candidate}
            }
            if r.score>(best?.result.score ?? -.infinity) {
                best=candidate;_=try evaluate(q,save:out)
                try write(["commonDistanceMeters":d,"allSixBallsShareDistance":true,"fixture":fixtureName,
                           "maximumCueHeadSpeed":speedRange.upperBound],"selected-layout.json",to:out)
                print("SIX UNIFORM trials=\(trials) pots=\(r.count) d=\(d) score=\(r.score)")
            }
            return candidate
        }
        if let source=env("SIX_CANDIDATES_JSON") {
            let rows=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:source))) as? [[String:Any]])
            for row in rows {
                if let q=row["parameters"] as? [NSNumber],q.count==6 {
                    let d=(row["commonDistanceMeters"] as? NSNumber)?.floatValue ?? initialDistance
                    _=try run(q.map{$0.floatValue},d)
                }
            }
        }
        while Date().timeIntervalSince(started)<budget && best?.result.count != 6 {
            var d:Float,q:[Float]
            if keys.isEmpty || rng.next()<0.2 {
                d=0.055+rng.next()*0.075;distanceOverride=d;q=seed(&rng,fixed:false)
            } else {
                let pool = !five.isEmpty && rng.next()<0.6 ? five : keys
                let parent=try XCTUnwrap(archive[pool[rng.index(pool.count)]])
                q=parent.result.q;d=parent.distance
                let scale=powf(10,-3.5*rng.next()),ranges:[Float]=[0.5,0.3,1.2,3,0.5,0.5]
                for j in 0..<6 {q[j]+=(rng.next()-0.5)*ranges[j]*scale}
                d+=(rng.next()-0.5)*0.075*scale
            }
            _=try run(q,d)
        }
        let selected=try XCTUnwrap(best);distanceOverride=selected.distance
        let r=try evaluate(selected.result.q,save:out)
        XCTAssertEqual(r.count,selected.result.count);XCTAssertEqual(r.score,selected.result.score)
        for (i,p) in positions.enumerated() {XCTAssertEqual(distance(p,geometry.pockets[pocketIndices[i]].center),selected.distance,accuracy:1e-6)}
        try write(archive.values.sorted{$0.result.score>$1.result.score}.prefix(512).map{
            ["parameters":$0.result.q,"commonDistanceMeters":$0.distance,"potted":$0.result.count,"score":$0.result.score] as [String:Any]
        },"uniform-candidates.json",to:out)
        try write(["algorithm":"single shared layout distance and six strike parameters; event-sequence archive",
                   "trials":trials,"routes":keys.count,"bestPotted":r.count,"scratch":r.scratch,
                   "commonDistanceMeters":selected.distance,"testedDistanceRange":[minimumDistance,maximumDistance],
                   "evaluationsByFloorSpeed":speedBands,
                   "searchMaxSpeed":speedRange.upperBound,"seconds":Date().timeIntervalSince(started),
                   "success":r.count==6 && !r.scratch && r.termination == .settled],"search-summary.json",to:out)
    }
    /// Preserve distinct event sequences even when their current pot count is lower.
    func testRouteSearch() throws {
        let out=try output(),started=Date()
        let budget=Double(env("SIX_SEARCH_SECONDS") ?? "300") ?? 300
        var rng=RNG(),trials=0,best:Result?
        if let value=env("SIX_SEARCH_SEED"),let s=UInt64(value) { rng.state=s }
        let initialSeed=rng.state
        var archive:[String:Result]=[:],keys:[String]=[],promising:[String]=[],fivePotRoutes:[String]=[]
        var speedBands=[Int](repeating:0,count:11),unique=Set<String>(),duplicates=0
        var continuation:[Float]?
        func run(_ q:[Float]) throws -> Result? {
            guard valid(q) else { return nil }
            let identity=q.map{String($0.bitPattern)}.joined(separator:",")
            guard unique.insert(identity).inserted else { duplicates+=1;return nil }
            trials+=1;speedBands[min(10,max(0,Int(q[3])))]+=1
            let r=try autoreleasepool { try evaluate(q) }
            if !r.scratch && r.termination == .settled {
                if archive[r.route] == nil {
                    keys.append(r.route)
                    if r.count>=4 { promising.append(r.route) }
                    if r.count>=5 { fivePotRoutes.append(r.route) }
                }
                if r.score>(archive[r.route]?.score ?? -.infinity) { archive[r.route]=r }
            }
            if r.score>(best?.score ?? -.infinity) {
                best=r;_=try evaluate(q,save:out)
                print("SIX ROUTE BEST trials=\(trials) pots=\(r.count) score=\(r.score) routes=\(keys.count)")
            }
            return r
        }
        if let source=env("SIX_RESUME_JSON") {
            let saved=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:source))) as? [String:Any])
            XCTAssertEqual(saved["fixture"] as? String,fixtureName)
            _=try run(try XCTUnwrap(saved["parameters"] as? [NSNumber]).map{$0.floatValue})
        }
        if let source=env("SIX_CANDIDATES_JSON") {
            let rows=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:source))) as? [[String:Any]])
            for row in rows {
                if let q=row["parameters"] as? [NSNumber],q.count==6 { _=try run(q.map{$0.floatValue}) }
            }
        }
        while Date().timeIntervalSince(started)<budget {
            if let r=best,r.count==6 && !r.scratch && r.termination == .settled { break }
            var parent:Result?,q:[Float]
            if let next=continuation { q=next;continuation=nil }
            else if keys.isEmpty || rng.next()<0.2 {
                q=seed(&rng,fixed:false)
                // Include bank-first shots outside the contact-directed seed family.
                if rng.next()<0.25 {
                    q[0]=(rng.next()-0.5)*(TablePhysics.innerLength-2*BallPhysics.radius)
                    q[1]=(rng.next()-0.5)*(TablePhysics.innerWidth-2*BallPhysics.radius)
                    q[2]=rng.next()*2*Float.pi
                }
            } else {
                let choice=rng.next()
                let pool = !fivePotRoutes.isEmpty && choice<0.5 ? fivePotRoutes :
                    (!promising.isEmpty && choice<0.8 ? promising : keys)
                parent=archive[pool[rng.index(pool.count)]]
                q=try XCTUnwrap(parent).q
                let scale=powf(10,-4*rng.next()),ranges:[Float]=[0.5,0.3,1.2,3,0.5,0.5]
                let coordinate=rng.next()<0.3 ? rng.index(6) : -1
                for j in 0..<6 where coordinate == -1 || coordinate == j {
                    q[j]+=(rng.next()-0.5)*ranges[j]*scale
                }
            }
            if let r=try run(q),let p=parent,r.route==p.route,r.score>p.score {
                continuation=(0..<6).map{r.q[$0]+0.7*(r.q[$0]-p.q[$0])}
            }
            if trials>0 && trials % 5000 == 0 { print("SIX ROUTE trials=\(trials) routes=\(keys.count) promising=\(promising.count)") }
        }
        let r=try XCTUnwrap(best),repeated=try evaluate(r.q,save:out)
        XCTAssertEqual(r.score,repeated.score);XCTAssertEqual(r.route,repeated.route)
        try write(archive.values.sorted{$0.score>$1.score}.prefix(512).map{
            ["parameters":$0.q,"route":$0.route,"potted":$0.count,"score":$0.score] as [String:Any]
        },"route-candidates.json",to:out)
        try write(["algorithm":"event-sequence archive with independent immigrants and directional refinement",
                   "fixture":fixtureName,"trials":trials,"exactDuplicatesSkipped":duplicates,"routes":keys.count,
                   "fourOrMorePotRoutes":promising.count,"fiveOrMorePotRoutes":fivePotRoutes.count,
                   "seed":initialSeed,"searchMaxSpeed":speedRange.upperBound,
                   "seedMinimumSpeed":seedMinimumSpeed,"evaluationsByFloorSpeed":speedBands,
                   "seconds":Date().timeIntervalSince(started),"bestPotted":r.count,"scratch":r.scratch,
                   "success":r.count==6 && !r.scratch && r.termination == .settled],"search-summary.json",to:out)
    }
    /// A separate search in first-contact coordinates, retaining six independent islands.
    /// Genes: contact-normal offset, incoming-angle offset, approach distance, speed, sx, sy.
    func testContactSearch() throws {
        let out=try output(), started=Date()
        let budget=Double(env("SIX_SEARCH_SECONDS") ?? "300") ?? 300
        var rng=RNG(),trials=0,best:Result?
        if let value=env("SIX_SEARCH_SEED"),let seed=UInt64(value) { rng.state=seed }
        let initialSeed=rng.state
        func decode(_ g:[Float],_ first:Int)->[Float] {
            let p=positions[first],pk=geometry.pockets[pocketIndices[first]].center
            let toward=atan2f(pk.z-p.z,pk.x-p.x)
            let normal=toward+g[0],incoming=toward+g[1]
            let x=p.x-2*BallPhysics.radius*cosf(normal)-g[2]*cosf(incoming)
            let z=p.z-2*BallPhysics.radius*sinf(normal)-g[2]*sinf(incoming)
            let strike=CueBallStrike.executeStrike(aimDirection:SCNVector3(1,0,0),velocity:g[3],spinX:g[4],spinY:g[5])
            return [x,z,incoming-atan2f(strike.velocity.z,strike.velocity.x),g[3],g[4],g[5]]
        }
        func genes()->[Float] {
            [(rng.next()-0.5)*0.8,(rng.next()-0.5)*3.0,0.08+rng.next()*2.5,
             seedMinimumSpeed+rng.next()*(Float(speedRange.upperBound)-seedMinimumSpeed),
             (rng.next()-0.5)*0.95,(rng.next()-0.5)*0.95]
        }
        func run(_ q:[Float],_ g:[Float],_ first:Int) throws -> Result {
            trials+=1
            let r=try autoreleasepool { try evaluate(q) }
            if r.score>(best?.score ?? -Float.infinity) {
                best=r
                _=try evaluate(q,save:out)
                try write(["seedTargetBall":numbers[first],"genes":g,"trial":trials],"contact-seed.json",to:out)
                print("SIX CONTACT BEST trials=\(trials) pots=\(r.count) scratch=\(r.scratch) score=\(r.score) seconds=\(Date().timeIntervalSince(started))")
            }
            return r
        }
        let size=64
        var populations=[[(g:[Float],r:Result)]](repeating:[],count:6)
        for first in 0..<6 {
            while populations[first].count<size && Date().timeIntervalSince(started)<budget {
                let g=genes(),q=decode(g,first)
                if valid(q) { populations[first].append((g,try run(q,g,first))) }
            }
        }
        var generation=0
        while Date().timeIntervalSince(started)<budget {
            generation+=1
            for first in 0..<6 where populations[first].count==size {
                for i in 0..<size {
                    if Date().timeIntervalSince(started)>=budget { break }
                    let pop=populations[first],ranked=pop.sorted{$0.r.score>$1.r.score}
                    var g=pop[i].g
                    if rng.next()<0.1 { g=genes() }
                    else if rng.next()<0.65 {
                        g=ranked[rng.index(12)].g
                        let scale=powf(10,-rng.next()*3.5)
                        let ranges:[Float]=[0.8,2,1,3,0.5,0.5]
                        for j in 0..<6 { g[j]+=(rng.next()-0.5)*ranges[j]*scale }
                    } else {
                        let a=pop[rng.index(size)].g,b=pop[rng.index(size)].g,c=pop[rng.index(size)].g
                        let f:Float=0.3+rng.next()*0.6,forced=rng.index(6)
                        for j in 0..<6 where j==forced || rng.next()<0.7 { g[j]=a[j]+f*(b[j]-c[j]) }
                    }
                    guard abs(g[0])<0.65,abs(g[1])<1.56,g[2]>0.05,g[2]<2.8 else { continue }
                    let q=decode(g,first)
                    if !valid(q) { continue }
                    let r=try run(q,g,first)
                    if r.score>pop[i].r.score { populations[first][i]=(g,r) }
                }
            }
            if let r=best,r.count==6 && !r.scratch && r.termination == .settled { break }
        }
        try write(populations.enumerated().flatMap { island in
            island.element.sorted{$0.r.score>$1.r.score}.prefix(12).map { candidate in
                ["seedTargetBall":numbers[island.offset],"genes":candidate.g,"parameters":candidate.r.q,
                 "score":candidate.r.score,"potted":candidate.r.count,"scratch":candidate.r.scratch] as [String:Any]
            }
        },"island-candidates.json",to:out)
        let r=try XCTUnwrap(best)
        let repeated=try evaluate(r.q,save:out)
        XCTAssertEqual(r.score,repeated.score)
        try write(["algorithm":"first-contact six islands","seed":initialSeed,"trials":trials,
                   "generations":generation,"seconds":Date().timeIntervalSince(started),"bestPotted":r.count,
                   "scratch":r.scratch,"success":r.count==6 && !r.scratch && r.termination == .settled,
                   "islandPots":populations.map{$0.map{$0.r.count}.max() ?? 0}],"search-summary.json",to:out)
    }
    func testPowerSweep() throws {
        let out=try output(),started=Date()
        let source=try XCTUnwrap(env("SIX_RESUME_JSON"))
        let saved=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:source))) as? [String:Any])
        XCTAssertEqual(saved["fixture"] as? String,fixtureName)
        let initial=try XCTUnwrap(saved["parameters"] as? [NSNumber]).map{$0.floatValue}
        var bases=[initial]
        if let path=env("SIX_CANDIDATES_JSON") {
            let rows=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:path))) as? [[String:Any]])
            for row in rows where (row["potted"] as? Int ?? 0)>=4 {
                if let q=row["parameters"] as? [NSNumber] { bases.append(q.map{$0.floatValue}) }
            }
        }
        let budget=Double(env("SIX_SEARCH_SECONDS") ?? "180") ?? 180
        var trials=0,best=try evaluate(initial,save:out)
        let powerStep=Float(env("SIX_POWER_STEP") ?? "0.01") ?? 0.01
        outer: for base in bases {
            let lower=max(Float(env("SIX_MIN_SWEEP") ?? "0") ?? 0, max(Float(speedRange.lowerBound),base[3]-0.3))
            let speeds=Array(stride(from:lower,through:Float(speedRange.upperBound),by:powerStep))+[Float(speedRange.upperBound)]
            for speed in speeds {
                if Date().timeIntervalSince(started)>=budget { break outer }
                var q=base;q[3]=speed
                let r=try autoreleasepool { try evaluate(q) };trials+=1
                if r.score>best.score {
                    best=r;_=try evaluate(q,save:out)
                    print("SIX POWER BEST trials=\(trials) pots=\(r.count) speed=\(q[3]) score=\(r.score)")
                }
                if r.count==6 && !r.scratch && r.termination == .settled { break outer }
            }
        }
        _=try evaluate(best.q,save:out)
        try write(["algorithm":"power continuation from saved candidates","trials":trials,
                   "bases":bases.count,"powerStep":powerStep,"seconds":Date().timeIntervalSince(started),"bestPotted":best.count,
                   "scratch":best.scratch,"searchMaxSpeed":speedRange.upperBound,
                   "success":best.count==6 && !best.scratch && best.termination == .settled],"search-summary.json",to:out)
    }
    func testLocalSearch() throws {
        let out=try output(), started=Date()
        let source=try XCTUnwrap(env("SIX_RESUME_JSON"))
        let saved=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:source))) as? [String:Any])
        XCTAssertEqual(saved["fixture"] as? String,fixtureName)
        let initial=try XCTUnwrap(saved["parameters"] as? [NSNumber]).map{$0.floatValue}
        let budget=Double(env("SIX_SEARCH_SECONDS") ?? "300") ?? 300
        var rng=RNG(),trials=0,restarts=0
        var best=try evaluate(initial,save:out)
        if let required=env("SIX_REQUIRED_POT_MASK").flatMap(Int.init) {
            XCTAssertTrue((1...63).contains(required))
            XCTAssertEqual(best.mask & required,required)
        }
        let scales:[Float]=[1,0.5,2,5,0.5,0.5]
        func run(_ q:[Float]) throws -> Result {
            trials+=1
            let r=try autoreleasepool { try evaluate(q) }
            if r.score>best.score {
                best=r;_=try evaluate(q,save:out)
                print("SIX LOCAL BEST trials=\(trials) pots=\(r.count) score=\(r.score) seconds=\(Date().timeIntervalSince(started))")
            }
            return r
        }
        while Date().timeIntervalSince(started)<budget && !(best.count==6 && !best.scratch && best.termination == .settled) {
            restarts+=1
            let h=powf(10,-2-rng.next()*3)
            var simplex=[best]
            for j in 0..<6 {
                var q=best.q;q[j]+=scales[j]*h*(rng.next()<0.5 ? -1 : 1)
                simplex.append(try run(q))
            }
            var stale=0
            for _ in 0..<300 {
                if Date().timeIntervalSince(started)>=budget || (best.count==6 && !best.scratch && best.termination == .settled) || stale>60 { break }
                simplex.sort{$0.score>$1.score}
                let previous=best.score
                var center=[Float](repeating:0,count:6)
                for j in 0..<6 { for k in 0..<6 { center[j]+=simplex[k].q[j]/6 } }
                let worst=simplex[6]
                let reflected=try run((0..<6).map{center[$0]+(center[$0]-worst.q[$0])})
                if reflected.score>simplex[0].score {
                    let expanded=try run((0..<6).map{center[$0]+2*(reflected.q[$0]-center[$0])})
                    simplex[6]=expanded.score>reflected.score ? expanded : reflected
                } else if reflected.score>simplex[5].score { simplex[6]=reflected }
                else {
                    let contracted=try run((0..<6).map{center[$0]+0.5*(worst.q[$0]-center[$0])})
                    if contracted.score>worst.score { simplex[6]=contracted }
                    else {
                        for k in 1..<7 { simplex[k]=try run((0..<6).map{simplex[0].q[$0]+0.5*(simplex[k].q[$0]-simplex[0].q[$0])}) }
                    }
                }
                stale=best.score>previous+0.00001 ? 0 : stale+1
            }
        }
        let r=try evaluate(best.q,save:out)
        XCTAssertEqual(r.score,best.score)
        try write(["algorithm":"multiscale restarted Nelder-Mead","trials":trials,"restarts":restarts,
                   "seconds":Date().timeIntervalSince(started),"bestPotted":r.count,"scratch":r.scratch,
                   "success":r.count==6 && !r.scratch && r.termination == .settled],"search-summary.json",to:out)
    }
    func testOptimize() throws {
        let out=try output(),started=Date()
        let source=try XCTUnwrap(env("SIX_RESUME_JSON"))
        let saved=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:source))) as? [String:Any])
        XCTAssertEqual(saved["fixture"] as? String,fixtureName)
        let q=try XCTUnwrap(saved["parameters"] as? [NSNumber]).map{$0.floatValue}
        let initial=try evaluate(q,save:out)
        _=try XCTUnwrap(initial.count==6 && !initial.scratch && initial.termination == .settled ? true : nil)
        var frontier=[initial],rng=RNG(),trials=0,successes=0
        let budget=Double(env("SIX_SEARCH_SECONDS") ?? "180") ?? 180
        func dominates(_ a:Result,_ b:Result)->Bool {
            a.q[3]<=b.q[3] && a.cueCushions<=b.cueCushions && (a.q[3]<b.q[3] || a.cueCushions<b.cueCushions)
        }
        func preferred()->Result {
            frontier.sorted { $0.cueCushions == $1.cueCushions ? $0.q[3]<$1.q[3] : $0.cueCushions<$1.cueCushions }[0]
        }
        while Date().timeIntervalSince(started)<budget {
            trials+=1
            let parent=frontier[rng.index(frontier.count)]
            var q=parent.q
            let scale=powf(10,-rng.next()*4)
            if trials % 7 == 0 { q[3]-=scale }
            else {
                let ranges:[Float]=[0.04,0.04,0.15,1,0.08,0.08]
                for j in 0..<6 { q[j]+=(rng.next()-(j==3 ? 0.7 : 0.5))*ranges[j]*scale }
            }
            if !valid(q) { continue }
            let r=try autoreleasepool { try evaluate(q) }
            guard r.count==6 && !r.scratch && r.termination == .settled else { continue }
            successes+=1
            if frontier.contains(where:{dominates($0,r) || ($0.q[3]==r.q[3] && $0.cueCushions==r.cueCushions)}) { continue }
            frontier.removeAll{dominates(r,$0)};frontier.append(r)
            if successes % 20 == 0 { print("SIX OPT trials=\(trials) speed=\(preferred().q[3]) cushions=\(preferred().cueCushions)") }
        }
        let best=preferred();_=try evaluate(best.q,save:out)
        try write(frontier.map{["parameters":$0.q,"cueCushions":$0.cueCushions,"cueSpeed":$0.q[3]]},"pareto.json",to:out)
        try write(["trials":trials,"successfulTrials":successes,"seconds":Date().timeIntervalSince(started),
                   "initialSpeed":initial.q[3],"finalSpeed":best.q[3],"initialCushions":initial.cueCushions,
                   "finalCushions":best.cueCushions,"selection":"fewest measured cue cushion events, then lower speed; frontier retained",
                   "success":true],"optimization-summary.json",to:out)
    }
    @MainActor
    func testFiveBallVideo() async throws {
        let out=try output(), source=try XCTUnwrap(env("SIX_RESUME_JSON"))
        let saved=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:source))) as? [String:Any])
        let q=try XCTUnwrap(saved["parameters"] as? [NSNumber]).map{$0.floatValue}
        XCTAssertEqual(saved["fixture"] as? String,fixtureName)
        let scene=AngleTrainingScene();scene.setupScene(enhancedRendering:false,mobileRendering:true)
        XCTAssertEqual(scene.surfaceY,y)
        XCTAssertTrue(scene.applyTableStyle(.charcoal,showsSights:true))
        XCTAssertTrue(scene.applyClothColor(.tournamentBlue))
        scene.hideAllBalls();scene.hideCueStick()
        let cue=SCNVector3(q[0],y+BallPhysics.radius,q[1]),aim=SCNVector3(cosf(q[2]),0,sinf(q[2]))
        let pred=ShotPredictor.simulateFree(cueBall:cue,aimDir:aim,velocity:q[3],spinX:q[4],spinY:q[5],surfaceY:y,
            balls:positions.enumerated().map{ObstacleBall(name:"_\(numbers[$0.offset])",position:$0.element)},
            maxEvents:4000,maxTime:90,includePresentation:true)
        XCTAssertEqual(Set(pred.pocketedBalls),Set(["_1","_2","_4","_5","_8"]))
        XCTAssertFalse(pred.cuePocketed);XCTAssertTrue(pred.hasFinalTableState)
        let recorder=try XCTUnwrap(pred.recorder),playback=TrajectoryPlayback(recorder:recorder,surfaceY:y+BallPhysics.radius)
        let names=[ShotInput.cueBallName]+numbers.map{"_\($0)"}
        scene.setCueBallHomeOrientation(BallSpinIntegrator.identityOrientation)
        scene.showBall(key:PositionPlayBall.cueKey,scenePosition:cue)
        for (i,p) in positions.enumerated() {scene.showBall(key:"_\(numbers[i])",scenePosition:p)}
        let camera=try XCTUnwrap(scene.cameraNode)
        camera.camera?.usesOrthographicProjection=true;camera.camera?.projectionDirection = .vertical
        camera.camera?.orthographicScale=1.68;camera.camera?.wantsExposureAdaptation=false
        camera.position=SCNVector3(0,y+4,0)
        camera.look(at:SCNVector3(0,y,0),up:SCNVector3(1,0,0),localFront:SCNVector3(0,0,-1))
        let renderer=SCNRenderer(device:nil,options:nil)
        renderer.scene=scene;renderer.pointOfView=camera;renderer.delegate=scene.contactOcclusion
        renderer.autoenablesDefaultLighting=false
        let size=CGSize(width:1080,height:1920),fps=60,rate:Float=0.5
        let impact=1.0+CueStroke.totalDuration(velocity:q[3])/Double(rate)
        let motionEnd=max(pred.duration,playback.collectionPresentationEnd)+Float(TrajectoryPlayback.pocketSettleDuration)
        let frameCount=Int(ceil((impact+Double(motionEnd/rate)+1.0)*Double(fps)))
        let export=env("SIX_VIDEO_EXPORT")=="1"
        let writer:VideoWriter?=export ? try VideoWriter(url:out.appendingPathComponent("five-ball-preview.mp4"),size:size,fps:fps):nil
        let frameTimes:[Double]=[0,impact,impact+0.6,impact+2.6,impact+6.2,Double(frameCount-1)/Double(fps)]
        let keyIndices=Set(frameTimes.map{Int(($0*Double(fps)).rounded())})
        var lastOmega:[String:SCNVector3]=[:],ledger:[[String:Any]]=[]
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let compositor=UIGraphicsImageRenderer(size:size,format:format)
        let entries=Dictionary(uniqueKeysWithValues:recorder.pocketEntries.map{($0.ball.name,$0)})
        for _ in 0..<3 {_=renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)}
        for i in 0..<frameCount {
            let wall=Double(i)/Double(fps),t=max(0,min(motionEnd,Float(wall-impact)*rate))
            SCNTransaction.begin();SCNTransaction.animationDuration=0;SCNTransaction.disableActions=true
            for name in names {
                let key=name==ShotInput.cueBallName ? PositionPlayBall.cueKey:name
                let node=try XCTUnwrap(scene.allBallNodes[key])
                guard let s=playback.stateAt(ballName:name,time:min(t,pred.duration)) else {continue}
                node.position=s.position;node.opacity=1
                if let opacity=playback.collectionOpacity(ballName:name,time:t),
                   let presented=playback.stateAt(ballName:name,time:t) {
                    node.position=presented.position;node.opacity=opacity
                } else if let entry=entries[name],t>=entry.time {
                    let pocket=TrajectoryPlayback.nearestPocket(to:entry.ball.position,surfaceY:y+BallPhysics.radius)
                    let legs=TrajectoryPlayback.solvePocketEntry(capture:entry.ball.position,velocity:entry.ball.velocity,
                        pocketCenter:pocket.center,pocketRadius:pocket.radius,speedScale:1)
                    let elapsed=Double(t-entry.time),end=TrajectoryPlayback.pocketEntryDuration(legs)
                    node.position=TrajectoryPlayback.pocketEntryPosition(start:entry.ball.position,legs:legs,at:elapsed)
                    node.opacity=CGFloat(max(0,min(1,1-(elapsed-end-TrajectoryPlayback.pocketPauseDuration)/TrajectoryPlayback.pocketFadeDuration)))
                }
                if wall>=impact {
                    let previous=lastOmega[name] ?? s.angularVelocity
                    BallSpinIntegrator.advance(node:node,from:previous,to:s.angularVelocity,dt:rate/Float(fps))
                    lastOmega[name]=s.angularVelocity
                }
            }
            if wall<impact {
                let pull=CueStroke.pullBack(at:max(0,(wall-1)*Double(rate)),velocity:q[3])
                scene.updateCueStick(cueBallPosition:CueStroke.strikePosition(cue:cue,aim:aim,spinX:Double(q[4]),spinY:Double(q[5])),
                    aimDirection:aim,pullBack:pull,elevationOverride:0)
            } else {scene.hideCueStick()}
            SCNTransaction.commit();SCNTransaction.flush()
            let pots=recorder.pocketEntries.filter{$0.time<=t}.count
            if i%fps==0 || keyIndices.contains(i) {
                let visible=names.map { name -> [String:Any] in
                    let node=scene.allBallNodes[name==ShotInput.cueBallName ? PositionPlayBall.cueKey:name]!
                    return ["name":name,"position":[node.position.x,node.position.y,node.position.z],"opacity":node.opacity,"hidden":node.isHidden]
                }
                ledger.append(["frame":i,"time":wall,"simulationTime":t,"potted":pots,"balls":visible])
            }
            if export || keyIndices.contains(i) {
                let raw=renderer.snapshot(atTime:wall,with:size,antialiasingMode:.multisampling4X)
                let image=compositor.image { context in
                    UIColor.black.setFill();context.fill(CGRect(origin:.zero,size:size));raw.draw(in:CGRect(origin:.zero,size:size))
                    ("旧路线预览 · 一杆进五球" as NSString).draw(at:CGPoint(x:66,y:42),withAttributes:[.font:UIFont.boldSystemFont(ofSize:40),.foregroundColor:UIColor.white])
                    ("不符合新增约束  ·  0.5 倍速" as NSString).draw(at:CGPoint(x:68,y:108),withAttributes:[.font:UIFont.systemFont(ofSize:26),.foregroundColor:UIColor.lightGray])
                    let label=wall<impact ? "六球等距摆放  ·  仅击打一次母球" : (pots==5 ? "已进 5 / 6  ·  剩余 3 号球" : "已进 \(pots) / 6")
                    (label as NSString).draw(at:CGPoint(x:68,y:1810),withAttributes:[.font:UIFont.systemFont(ofSize:30,weight:.medium),.foregroundColor:UIColor.white])
                }
                if keyIndices.contains(i) {
                    try XCTUnwrap(image.pngData()).write(to:out.appendingPathComponent(String(format:"frame-%04d.png",i)))
                    let node=scene.allBallNodes["_4"]!,p=node.presentation.worldPosition
                    let orientation=node.simdOrientation.vector
                    print("SIX RENDER FOUR frame=\(i) presentation=\(p) scale=\(node.scale) orientation=\(orientation) bbox=\(node.boundingBox) children=\(node.childNodes.map{($0.name ?? "",$0.isHidden,$0.opacity)})")
                }
                if let writer {try writer.append(try XCTUnwrap(image.cgImage))}
            }
            if i%120==0 {print("SIX VIDEO frame=\(i)/\(frameCount)");await Task.yield()}
        }
        if let writer {try await writer.finish()}
        try write(["width":1080,"height":1920,"fps":fps,"frames":frameCount,"duration":Double(frameCount)/Double(fps),
            "impactTime":impact,"playbackRate":rate,"parameters":q,"commonDistanceMeters":try XCTUnwrap(commonDistance),
            "pottedBalls":pred.pocketedBalls.sorted(),"scratch":pred.cuePocketed,"productionReplayCompleted":pred.hasFinalTableState,
            "simulationDuration":pred.duration,"exported":export,"ledger":ledger],"video-manifest.json",to:out)
    }

    @MainActor
    func testReplayInputAudit() throws {
        let out=try output()
        let path=try XCTUnwrap(env("SIX_RESUME_JSON"))
        let saved=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:path))) as? [String:Any])
        let q=try XCTUnwrap(saved["parameters"] as? [NSNumber]).map{$0.floatValue}
        let scene=AngleTrainingScene();scene.setupScene()
        let actualY=scene.surfaceY
        let prediction=ShotPredictor.simulateFree(cueBall:SCNVector3(q[0],actualY,q[1]),
            aimDir:SCNVector3(cosf(q[2]),0,sinf(q[2])),velocity:q[3],spinX:q[4],spinY:q[5],surfaceY:actualY,
            balls:positions.enumerated().map{ObstacleBall(name:"_\(numbers[$0.offset])",position:$0.element)},
            maxEvents:4000,maxTime:90,includePresentation:true)
        let aligned=try evaluate(q,save:out)
        XCTAssertEqual(aligned.count,prediction.pocketedBalls.count)
        XCTAssertEqual(aligned.termination,prediction.termination)
        XCTAssertEqual(aligned.scratch,prediction.cuePocketed)
        var rows:[[String:Any]]=[]
        for actualHeight in [false,true] {
            for cueFirst in [false,true] {
                for normalize in [false,true] {
                    let height=actualHeight ? actualY:y
                    let e=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:height))
                    var dir=SCNVector3(cosf(q[2]),0,sinf(q[2]))
                    let length=sqrtf(dir.x*dir.x+dir.z*dir.z)
                    if normalize {dir=SCNVector3(dir.x/length,0,dir.z/length)}
                    let strike=CueBallStrike.executeStrike(aimDirection:dir,velocity:q[3],spinX:q[4],spinY:q[5])
                    func addCue() {e.setBall(BallState(position:SCNVector3(q[0],height+BallPhysics.radius,q[1]),velocity:strike.velocity,
                        angularVelocity:strike.angularVelocity,state:.sliding,name:ShotInput.cueBallName))}
                    if cueFirst {addCue()}
                    for (i,p) in positions.enumerated() {
                        e.setBall(BallState(position:SCNVector3(p.x,height+BallPhysics.radius,p.z),velocity:SCNVector3Zero,
                            angularVelocity:SCNVector3Zero,state:.stationary,name:"_\(numbers[i])"))
                    }
                    if !cueFirst {addCue()}
                    var term=e.simulatePrediction(model:.appDefault,maxEvents:4000,maxTime:90,highFidelityBounds:true)
                    term=e.completePlanarSpinTail(after:term,surfaceY:height)
                    let pots=e.getTrajectoryRecorder().pocketEntries.map{$0.ball.name}.sorted()
                    rows.append(["actualHeight":actualHeight,"surfaceY":height,"cueFirst":cueFirst,"normalizedAim":normalize,
                                 "aimLength":length,"pottedBalls":pots,"termination":String(describing:term)])
                    if actualHeight && cueFirst && normalize {
                        XCTAssertEqual(pots,prediction.pocketedBalls.sorted())
                        XCTAssertEqual(term,prediction.termination)
                    }
                }
            }
        }
        try write(["productionPottedBalls":prediction.pocketedBalls.sorted(),"variants":rows],"input-audit.json",to:out)
    }
    @MainActor
    func testReplay() throws {
        let out=try output()
        let source=try XCTUnwrap(env("SIX_RESUME_JSON"))
        let saved=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:source))) as? [String:Any])
        XCTAssertEqual(saved["fixture"] as? String,fixtureName)
            let q=try XCTUnwrap(saved["parameters"] as? [NSNumber]).map { $0.floatValue }
        XCTAssertEqual(q.count,6)
        XCTAssertTrue(valid(q))
        let direct=try evaluate(q,save:out)
        let expected=try XCTUnwrap(saved["potted"] as? Int)
        XCTAssertEqual(direct.count,expected)
        XCTAssertEqual(direct.termination,.settled)
        XCTAssertFalse(direct.scratch)
        let scene=AngleTrainingScene();scene.setupScene()
        let actualY=scene.surfaceY
        let pred=ShotPredictor.simulateFree(cueBall:SCNVector3(q[0],actualY,q[1]),
            aimDir:SCNVector3(cosf(q[2]),0,sinf(q[2])),velocity:q[3],spinX:q[4],spinY:q[5],surfaceY:actualY,
            balls:positions.enumerated().map { ObstacleBall(name:"_\(numbers[$0.offset])",position:$0.element) },
            maxEvents:4000,maxTime:90,includePresentation:true)
        XCTAssertTrue(pred.hasFinalTableState)
        XCTAssertFalse(pred.cuePocketed)
        XCTAssertEqual(Set(pred.pocketedBalls),Set((saved["pocketEvents"] as? [[String:Any]] ?? []).compactMap {$0["ball"] as? String}))
        XCTAssertEqual(pred.pocketedBalls.count,expected)
        try write(["directEnginePots":direct.count,"productionPredictorPots":pred.pocketedBalls,
                   "completed":pred.hasFinalTableState,"scratch":pred.cuePocketed,
                   "sixBallSuccess":expected==6 && pred.hasFinalTableState && !pred.cuePocketed],"replay-verification.json",to:out)
    }
    private func diagram(_ rec:TrajectoryRecorder?,to url:URL,cue:SCNVector3=SCNVector3Zero) throws {
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let image=UIGraphicsImageRenderer(size:CGSize(width:800,height:1500),format:format).image { context in
            let c=context.cgContext
            UIColor(white:0.08,alpha:1).setFill();c.fill(CGRect(x:0,y:0,width:800,height:1500))
            let s:CGFloat=500
            func p(_ v:SCNVector3)->CGPoint { CGPoint(x:400+CGFloat(v.z)*s,y:750-CGFloat(v.x)*s) }
            UIColor(red:0.08,green:0.35,blue:0.4,alpha:1).setFill()
            c.fill(CGRect(x:400-CGFloat(TablePhysics.innerWidth)/2*s,y:750-CGFloat(TablePhysics.innerLength)/2*s,
                          width:CGFloat(TablePhysics.innerWidth)*s,height:CGFloat(TablePhysics.innerLength)*s))
            UIColor.lightGray.setStroke();c.setLineWidth(2)
            for line in geometry.linearCushions { c.move(to:p(line.start));c.addLine(to:p(line.end));c.strokePath() }
            for pocket in geometry.pockets {
                let pt=p(pocket.center),r=CGFloat(pocket.radius)*s
                UIColor.black.setFill();c.fillEllipse(in:CGRect(x:pt.x-r,y:pt.y-r,width:2*r,height:2*r))
            }
            if let frames=rec?.framesByBallName[ShotInput.cueBallName] {
                UIColor(white:1,alpha:0.65).setStroke();c.setLineWidth(1.5)
                for (a,b) in zip(frames,frames.dropFirst()) { c.move(to:p(a.position));c.addLine(to:p(b.position));c.strokePath() }
            }
            let colors:[UIColor]=[.systemYellow,.systemBlue,.systemRed,.systemPurple,.systemOrange,.black]
            for (i,position) in positions.enumerated() {
                let pt=p(position),r=CGFloat(BallPhysics.radius)*s
                colors[i].setFill();c.fillEllipse(in:CGRect(x:pt.x-r,y:pt.y-r,width:2*r,height:2*r))
                UIColor.white.setFill();c.fillEllipse(in:CGRect(x:pt.x-8,y:pt.y-8,width:16,height:16))
                ("\(numbers[i])" as NSString).draw(at:CGPoint(x:pt.x-4,y:pt.y-7),withAttributes:[.font:UIFont.boldSystemFont(ofSize:12),.foregroundColor:UIColor.black])
            }
            let pt=p(cue),r=CGFloat(BallPhysics.radius)*s
            UIColor.white.setFill();c.fillEllipse(in:CGRect(x:pt.x-r,y:pt.y-r,width:2*r,height:2*r))
            ((rec == nil ? "V011 / \(fixtureName)" : "V011 / Search diagnostic (not final video)") as NSString)
                .draw(at:CGPoint(x:45,y:30),withAttributes:[.font:UIFont.systemFont(ofSize:22),.foregroundColor:UIColor.white])
        }
        try XCTUnwrap(image.pngData()).write(to:url)
    }
}
