/// Research consumer only. App engine, input geometry and formal banks are read-only.
final class CB01MasseSearchTests: XCTestCase {
    private let bed = BTTablePhysics.surfaceY + BallPhysics.radius
    private let r = Double(BallPhysics.radius)
    private var simulations = 0
    private var incomplete = 0
    private var diagnostics = [String: Int]()
    private var cueProfile = CueSection.fallback

    private func point(_ p: [String: Any]) -> SCNVector3 {
        SCNVector3(Float(p["x"] as! Double), bed, Float(p["z"] as! Double))
    }
    private func dist(_ a: SCNVector3, _ b: SCNVector3) -> Double {
        hypot(Double(a.x-b.x), Double(a.z-b.z))
    }
    private func bearing(_ a: SCNVector3, _ b: SCNVector3) -> Double {
        atan2(Double(b.z-a.z), Double(b.x-a.x))
    }
    private func wrap(_ a: Double) -> Double { atan2(sin(a), cos(a)) }
    private func segmentDistance(_ p: SCNVector3, _ a: SCNVector3, _ b: SCNVector3) -> Double {
        let dx=Double(b.x-a.x), dz=Double(b.z-a.z), d2=dx*dx+dz*dz
        if d2 == 0 { return dist(p,a) }
        let t=max(0,min(1,(Double(p.x-a.x)*dx+Double(p.z-a.z)*dz)/d2))
        return hypot(Double(p.x-a.x)-t*dx,Double(p.z-a.z)-t*dz)
    }
    private func pathGap(_ p: SCNVector3, _ frames: [BallFrame]) -> Double {
        zip(frames,frames.dropFirst()).map { segmentDistance(p,$0.0.position,$0.1.position)-2*r }.min() ?? -2*r
    }
    private func frames(_ p: ShotPrediction, _ name: String) -> [BallFrame] {
        p.recorder?.framesByBallName[name] ?? []
    }
    private func cueTargetTime(_ p: ShotPrediction) -> Float? {
        p.events.first {
            if case let .ballBall(a,b) = $0.kind { return Set([a,b]) == Set(["cueBall","object"]) }
            return false
        }?.time
    }
    private func precontact(_ p: ShotPrediction) -> [BallFrame] {
        guard let t=cueTargetTime(p) else { return [] }
        return frames(p,"cueBall").filter { $0.time <= t }
    }
    private func potted(_ p: ShotPrediction, _ pocket: Int) -> Bool {
        p.events.contains {
            if case let .pocket(ball,id) = $0.kind { return ball == "object" && id == "pocket_\(pocket)" }
            return false
        }
    }
    private func cueRailBeforeTarget(_ p: ShotPrediction) -> Bool {
        let t=cueTargetTime(p) ?? .infinity
        return p.events.contains {
            if case let .ballCushion(ball) = $0.kind { return ball == "cueBall" && $0.time < t }
            return false
        }
    }
    private func cueOnTable(_ p: ShotPrediction) -> Bool {
        let values=frames(p,"cueBall")
        guard let last=values.last, SpatialPracticeGeometry.isOnBed(last.position), !p.cuePocketed else { return false }
        return !values.contains {
            abs($0.position.x)>TablePhysics.innerLength/2+BallPhysics.radius ||
            abs($0.position.z)>TablePhysics.innerWidth/2+BallPhysics.radius || $0.position.y<bed-0.001
        }
    }
    private func cloth(_ p: ShotPrediction) -> Bool {
        !frames(p,"cueBall").isEmpty && frames(p,"cueBall").allSatisfy { $0.position.y <= bed+0.001 }
    }
    private func accessible(cue: SCNVector3, target: SCNVector3, obstacle: SCNVector3?, yaw: Double, param: [Double]) -> Bool {
        let obstacles = obstacle.map { [target,$0] } ?? [target]
        let access=CueStrikeAccess(cue:cue,aim:SCNVector3(Float(cos(yaw)),0,Float(sin(yaw))),
            obstacles:obstacles,surfaceY:BTTablePhysics.surfaceY,profile:cueProfile,fixedElevation:Float(param[0]*Double.pi/180))
        return access.isAvailable(spinX:param[2],spinY:param[3])
    }
    private func simulate(cue: SCNVector3, target: SCNVector3?, obstacle: SCNVector3?, yaw: Double, param: [Double], seed: Bool=false) -> ShotPrediction {
        simulations += 1
        var balls=[ObstacleBall](), positions=["cueBall":cue]
        if let target { balls.append(ObstacleBall(name:"object",position:target)); positions["object"]=target }
        if let obstacle { balls.append(ObstacleBall(name:"obstacle",position:obstacle));positions["obstacle"]=obstacle }
        let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:SCNVector3(Float(cos(yaw)),0,Float(sin(yaw))),
            velocity:Float(param[1]),spinX:Float(param[2]),spinY:Float(param[3]),surfaceY:BTTablePhysics.surfaceY,
            balls:balls,maxEvents:3000,maxTime:seed ? 4 : 40,includePresentation:false,simulationModel:.spatialPractice,
            elevation:Float(param[0]*Double.pi/180),initialSpatialPositions:positions,buildPolylines:false)
        if !seed && !p.hasFinalTableState { incomplete += 1 }
        return p
    }
    // First outward crossing, cut off before any rail contact: only a search seed.
    private func seedYaw(cue: SCNVector3, ghost: SCNVector3, param: [Double]) -> Double? {
        let nominal=bearing(cue,ghost), distance=dist(cue,ghost)
        let p=simulate(cue:cue,target:nil,obstacle:nil,yaw:nominal,param:param,seed:true)
        let rail=p.events.first {
            if case let .ballCushion(ball) = $0.kind { return ball == "cueBall" }; return false
        }?.time ?? .infinity
        let values=frames(p,"cueBall").filter { $0.time < rail }
        for (a,b) in zip(values,values.dropFirst()) {
            let da=dist(cue,a.position), db=dist(cue,b.position)
            if da < distance && db >= distance {
                let t=Float((distance-da)/(db-da))
                let crossing=SCNVector3(a.position.x+t*(b.position.x-a.position.x),bed,a.position.z+t*(b.position.z-a.position.z))
                return nominal+wrap(nominal-bearing(cue,crossing))
            }
        }
        return nil
    }
    private func impactError(_ p: ShotPrediction, target: SCNVector3, pocket: SCNVector3) -> Double? {
        guard cueTargetTime(p) != nil, !cueRailBeforeTarget(p),
              let moving=frames(p,"object").first(where: { hypotf($0.velocity.x,$0.velocity.z)>0.01 }) else { return nil }
        return wrap(atan2(Double(moving.velocity.z),Double(moving.velocity.x))-bearing(target,pocket))
    }
    private func metrics(_ p: ShotPrediction, pocket: Int, obstacle: SCNVector3) -> [String:Any] {
        let pre=precontact(p), cueFrames=frames(p,"cueBall"), targetFrames=frames(p,"object")
        let curvature = pre.first.flatMap { first in pre.last.map { last in pre.map { segmentDistance($0.position,first.position,last.position) }.max() ?? 0 } } ?? 0
        let touchedObstacle=p.events.contains {
            if case let .ballBall(a,b) = $0.kind { return a == "obstacle" || b == "obstacle" };return false
        }
        let first=p.events.first { if case .ballBall = $0.kind { return true };return false }
        let firstTarget=first.map { if case let .ballBall(a,b) = $0.kind { return Set([a,b]) == Set(["cueBall","object"]) }; return false } ?? false
        return ["settled":p.hasFinalTableState,"objectPotted":potted(p,pocket),"cueOnTable":cueOnTable(p),
            "cueStayedOnCloth":cloth(p),"firstContactIsTarget":firstTarget,"obstacleContact":touchedObstacle,
            "cueRailBeforeTarget":cueRailBeforeTarget(p),"precontactChordDeviationMetres":curvature,
            "minimumPrecontactObstacleGapMetres":pathGap(obstacle,pre),
            "cueMaximumHeightMetres":cueFrames.map { Double($0.position.y-bed) }.max() ?? 0,
            "targetMaximumHeightMetres":targetFrames.map { Double($0.position.y-bed) }.max() ?? 0,
            "termination":String(describing:p.termination)]
    }
    private func qualifies(_ m: [String:Any]) -> Bool {
        ["settled","objectPotted","cueOnTable","cueStayedOnCloth","firstContactIsTarget"].allSatisfy { m[$0] as? Bool == true } &&
        m["obstacleContact"] as? Bool == false && m["cueRailBeforeTarget"] as? Bool == false &&
        (m["precontactChordDeviationMetres"] as! Double)>0.001 && (m["minimumPrecontactObstacleGapMetres"] as! Double)>0
    }
    private func trace(_ p: ShotPrediction) -> [String: Any] {
        var out=[String:Any]()
        for name in ["cueBall","object","obstacle"] {
            out[name]=frames(p,name).map { [Double($0.time),Double($0.position.x),Double($0.position.y),Double($0.position.z)] }
        }
        return out
    }
    private func search(_ shape: [String:Any], params: [[Double]]) -> [String:Any] {
        diagnostics = [:]
        let cue=point(shape["cue"] as! [String:Any]),target=point(shape["target"] as! [String:Any])
        let ghost=point(shape["ghost"] as! [String:Any]),pocket=point(shape["pocketCenter"] as! [String:Any])
        let pocketID=shape["pocket"] as! Int, positions=shape["obstacleCandidates"] as! [[String:Any]]
        var audit=[[String:Any]](), best: [String:Any]?, diagnosticExample: [String:Any]?
        let start=simulations, failedStart=incomplete
        for param in params {
            let up=CueBallStrike.contactCoordinates(spinX:Float(param[2]),spinY:Float(param[3]),elevation:Float(param[0]*Double.pi/180)).up
            guard up < 0 else { continue }
            guard let yaw=seedYaw(cue:cue,ghost:ghost,param:param) else { diagnostics["seedDidNotReach",default:0]+=1;continue }
            var probes=[(Double,Double)](), tried=[Double]()
            var offsets=[0.0,-0.25,0.25,-0.5,0.5,-1,1,-2,2]
            var checks=0
            while !offsets.isEmpty && checks < 18 {
                let offset=offsets.removeFirst(), angle=yaw+offset*Double.pi/180
                if tried.contains(where:{abs($0-offset)<0.0001}) {continue};tried.append(offset);checks += 1
                if !accessible(cue:cue,target:target,obstacle:nil,yaw:angle,param:param) { diagnostics["cueInaccessible",default:0]+=1;continue }
                let baseline=autoreleasepool { simulate(cue:cue,target:target,obstacle:nil,yaw:angle,param:param) }
                let error=impactError(baseline,target:target,pocket:pocket)
                audit.append(["parameter":param,"yawRadians":angle,"phase":"targetAim","potted":potted(baseline,pocketID),"settled":baseline.hasFinalTableState,"impactError":error as Any? ?? NSNull()])
                if potted(baseline,pocketID) {
                    diagnostics["targetPotted",default:0]+=1
                    if !cloth(baseline) {diagnostics["potRejectedAirborne",default:0]+=1}
                    if !cueOnTable(baseline) {diagnostics["potRejectedCueOffTable",default:0]+=1}
                    if cueRailBeforeTarget(baseline) {diagnostics["potRejectedPriorRail",default:0]+=1}
                    if diagnosticExample == nil {
                        diagnosticExample=["parameter":param,"yawRadians":angle,"trajectory":trace(baseline),
                            "cueStayedOnCloth":cloth(baseline),"cueOnTable":cueOnTable(baseline),
                            "cueMaximumHeightMetres":frames(baseline,"cueBall").map { Double($0.position.y-bed) }.max() ?? 0]
                    }
                }
                if let error, abs(error)<Double.pi/2 {
                    probes.append((offset,error));probes.sort{$0.0<$1.0}
                    if let pair=zip(probes,probes.dropFirst()).first(where:{$0.0.1 * $0.1.1 < 0}) {
                        offsets.insert((pair.0.0+pair.1.0)/2,at:0)
                    }
                }
                guard potted(baseline,pocketID), baseline.hasFinalTableState, cloth(baseline), cueOnTable(baseline), !cueRailBeforeTarget(baseline) else {continue}
                diagnostics["unobstructedPot",default:0]+=1
                let path=precontact(baseline)
                for obstacleData in positions {
                    let obstacle=point(obstacleData["center"] as! [String:Any])
                    // Candidate placement is a search, not a robustness perturbation.
                    guard pathGap(obstacle,path)>0.001 else {continue}
                    guard accessible(cue:cue,target:target,obstacle:obstacle,yaw:angle,param:param) else {continue}
                    let full=autoreleasepool { simulate(cue:cue,target:target,obstacle:obstacle,yaw:angle,param:param) }
                    let m=metrics(full,pocket:pocketID,obstacle:obstacle)
                    audit.append(["parameter":param,"yawRadians":angle,"phase":"obstacle","obstacle":obstacleData,"metrics":m])
                    if qualifies(m) {
                        best=["technique":"masse","parameter":param,"yawRadians":angle,
                            "aimOffsetDegrees":wrap(angle-bearing(cue,ghost))*180/Double.pi,
                            "actualContactUpOverR":up,"cueAccessible":true,"obstacle":obstacleData,"metrics":m,"trajectory":trace(full)]
                        break
                    }
                }
                if best != nil {break}
            }
            if best != nil {break}
        }
        return ["sampleIndex":shape["sampleIndex"]!,"source":shape,"status":best != nil ? "solved" : "searchExhausted",
            "solution":best as Any? ?? NSNull(),"diagnosticExample":diagnosticExample as Any? ?? NSNull(),
            "simulations":simulations-start,"incompleteFinalSimulations":incomplete-failedStart,"attempts":audit]
    }
    func testMasseSearch() throws {
        let name=ProcessInfo.processInfo.environment["CB01_MASSE_REQUEST"] ?? "masse-request.json"
        let url=Bundle(for:Self.self).resourceURL!.appendingPathComponent(name)
        let request=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:url)) as? [String:Any])
        let shapes=try XCTUnwrap(request["shapes"] as? [[String:Any]])
        let params=try XCTUnwrap(request["parameters"] as? [[Double]])
        // Use the same measured cue mesh profile as the interactive table.
        let model=try XCTUnwrap(TableModelLoader.loadTable())
        let cue=try XCTUnwrap(model.cueStickNode)
        cueProfile=CueStick(modelCueStickNode:cue).clearanceProfile
        XCTAssertFalse(cueProfile.isEmpty)
        for shape in shapes {
            var result=autoreleasepool { search(shape,params:params) }
            result["runIdentity"]=request["runIdentity"]!
            result["diagnostics"]=diagnostics
            let data=try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys])
            print("CB01_MASSE "+String(decoding:data,as:UTF8.self));fflush(stdout)
        }
        XCTAssertFalse(shapes.isEmpty)
        print("CB01_MASSE_COMPLETE shapes=\(shapes.count) simulations=\(simulations)")
    }
    func testSearchGeometry() {
        let a=SCNVector3(0,0,0),b=SCNVector3(1,0,0)
        XCTAssertEqual(segmentDistance(SCNVector3(2,0,1),a,b),sqrt(2),accuracy:1e-6)
        XCTAssertEqual(segmentDistance(SCNVector3(0.5,0,0.1),a,b),0.1,accuracy:1e-6)
        XCTAssertEqual(wrap(359*Double.pi/180), -Double.pi/180,accuracy:1e-9)
        XCTAssertEqual(bearing(a,SCNVector3(0,0,1)),Double.pi/2,accuracy:1e-9)
        XCTAssertFalse(qualifies(["settled":true,"objectPotted":true,"cueOnTable":true,"cueStayedOnCloth":true,
            "firstContactIsTarget":true,"obstacleContact":false,"cueRailBeforeTarget":false,
            "precontactChordDeviationMetres":0.0,"minimumPrecontactObstacleGapMetres":0.01]))
    }
}
