import Foundation
import SceneKit

// Research pilot: XZ metres, Y up. Portrait up +X, right +Z.
let surface = BTTablePhysics.surfaceY
let radius = BallPhysics.radius
let cueKey = ShotInput.cueBallName
let table = TableGeometry.chineseEightBallQiuJi(surfaceY: surface)
func point(_ p: SCNVector3) -> [Double] { [Double(p.x), Double(p.z)] }
func vector(_ x: Double, _ z: Double) -> SCNVector3 { SCNVector3(Float(x),surface+radius,Float(z)) }
func distance(_ a: SCNVector3, _ b: SCNVector3) -> Double { hypot(Double(a.x-b.x),Double(a.z-b.z)) }
func write(_ x: Any, _ path: String) throws {
    try JSONSerialization.data(withJSONObject:x,options:[.sortedKeys,.prettyPrinted]).write(to:URL(fileURLWithPath:path),options:.atomic)
}
func gap(_ p: SCNVector3) -> Double {
    Double(min(TablePhysics.innerLength/2-abs(p.x),TablePhysics.innerWidth/2-abs(p.z))-radius)
}
func placement(_ ps: [SCNVector3]) -> Bool {
    for (i,p) in ps.enumerated() {
        if gap(p)<0.005 { return false }
        if table.pockets.contains(where:{ distance(p,$0.center)<Double($0.radius+radius)+0.05 }) { return false }
        for q in ps.dropFirst(i+1) { if distance(p,q)<Double(2*radius)+0.015 { return false } }
    }
    return true
}
func opportunities(_ c: SCNVector3, _ b: SCNVector3, _ key: String, _ obstacles:[SCNVector3]) -> [[String:Any]] {
    (0..<6).compactMap { index in
        guard let p=DailyShotRecommendation.candidate(cue:c,target:b,targetKey:key,pocketIndex:index,obstacles:obstacles,surfaceY:surface),
              let s=ShotComfortScore.evaluate(cue:(Double(c.x),Double(c.z)),ball:(Double(b.x),Double(b.z)),aim:(Double(p.aim.x),Double(p.aim.z))) else { return nil }
        return ["pocket":index,"aim":point(p.aim),"score":s.total,"distance":s.distance,"space":s.space,"angle":s.angle] as [String:Any]
    }.sorted { ($0["score"] as! Double)>($1["score"] as! Double) }
}
struct Occlusion {
    let angularMargin: Double
    let depthGap: Double
    var full: Bool { angularMargin>1e-6 && depthGap>0 }
    var json: [String:Any] { ["full":full,"angularMarginDegrees":angularMargin*180/Double.pi,"depthGapMeters":depthGap] }
}
func occlusion(_ cue: SCNVector3, _ blocker: SCNVector3, _ target: SCNVector3) -> Occlusion {
    // Sufficient, conservative proof: the blocker's 2R angular disc contains
    // the whole target 2R disc AND its farthest point is nearer than the target's nearest.
    // Equal ball radii: this tests cue-centre access, not visual centre-line occlusion.
    let db=distance(cue,blocker),dt=distance(cue,target),r=Double(2*radius)
    guard db>r,dt>r else { return Occlusion(angularMargin:-Double.pi,depthGap:-1) }
    let ab=atan2(Double(blocker.z-cue.z),Double(blocker.x-cue.x))
    let at=atan2(Double(target.z-cue.z),Double(target.x-cue.x))
    let delta=abs(atan2(sin(ab-at),cos(ab-at)))
    return Occlusion(angularMargin:asin(r/db)-delta-asin(r/dt),depthGap:dt-db-2*r)
}
func rayEntry(_ c: SCNVector3, _ b: SCNVector3, _ angle:Double) -> Double? {
    let x=Double(b.x-c.x),z=Double(b.z-c.z),proj=x*cos(angle)+z*sin(angle)
    let cross=x*sin(angle)-z*cos(angle),rr=Double(2*radius)
    let d=rr*rr-cross*cross
    guard proj>0,d >= -1e-12 else { return nil }
    return proj-sqrt(max(0,d))
}
func visibleFraction(_ c:SCNVector3,_ blocker:SCNVector3,_ target:SCNVector3) -> Double {
    let d=distance(c,target); if d<=Double(2*radius) { return 1 }
    let angle=atan2(Double(target.z-c.z),Double(target.x-c.x)),half=asin(Double(2*radius)/d)
    var visible=0
    for i in 0...128 {
        let a=angle+half*(Double(i)/64-1)
        guard let t=rayEntry(c,target,a) else { continue }
        if let b=rayEntry(c,blocker,a),b<t { continue }
        visible += 1
    }
    return Double(visible)/129
}
struct Stroke {
    let direction: SCNVector3
    let speed: Float
    let spinY: Float
    var json:[String:Any] { ["direction":point(direction),"speed":Double(speed),"spinX":0,"spinY":Double(spinY)] }
}
struct DefensePilotLayout {
    let cue:SCNVector3
    let own:SCNVector3
    let enemy:SCNVector3
    let ownKey:String
    let enemyKey:String
    var json:[String:Any] { [cueKey:point(cue),ownKey:point(own),enemyKey:point(enemy)] }
}
var simulations=0
func simulate(_ c:SCNVector3,_ balls:[ObstacleBall],_ shot:Stroke) -> ShotPrediction {
    simulations += 1
    return ShotPredictor.simulateFree(cueBall:c,aimDir:shot.direction,velocity:shot.speed,spinX:0,spinY:shot.spinY,surfaceY:surface,
        balls:balls,maxEvents:1500,maxTime:60,recordedStrikeDirection:shot.direction)
}
func simulate(_ l:DefensePilotLayout,_ s:Stroke) -> ShotPrediction {
    simulate(l.cue,[ObstacleBall(name:l.ownKey,position:l.own),ObstacleBall(name:l.enemyKey,position:l.enemy)],s)
}
func rejection(_ p:ShotPrediction,_ own:String,_ keys:[String]) -> String? {
    if !p.hasFinalTableState { return "incomplete" }
    if p.cuePocketed || !p.pocketedBalls.isEmpty { return "pocketed" }
    guard let hit=p.events.first(where:{ if case .ballBall = $0.kind { return true };return false }),
          case let .ballBall(a,b)=hit.kind, Set([a,b])==Set([cueKey,own]) else { return "wrong-first-contact" }
    guard p.events.contains(where:{ e in if case .ballCushion = e.kind { return e.time>hit.time };return false }) else { return "no-rail-after-contact" }
    for (i,key) in keys.enumerated() {
        guard let a=p.finalPositions[key],gap(a) >= -0.00001 else { return "invalid-final" }
        for key2 in keys.dropFirst(i+1) {
            guard let b=p.finalPositions[key2],distance(a,b)>=Double(2*radius)-0.00001 else { return "overlap" }
        }
    }
    return nil
}
func events(_ p:ShotPrediction) -> [[String:Any]] {
    p.events.map { e in
        var r:[String:Any]=["time":Double(e.time)]
        switch e.kind {
        case let .ballBall(a,b):r["kind"]="ballBall";r["balls"]=[a,b]
        case let .ballCushion(b):r["kind"]="cushion";r["ball"]=b;r["index"]=e.cushionIndex ?? -1
        case let .pocket(b,id):r["kind"]="pocket";r["ball"]=b;r["pocket"]=id
        }
        return r
    }
}
func record(_ l:DefensePilotLayout,_ p:ShotPrediction,_ s:Stroke) -> [String:Any] {
    let c=p.finalPositions[cueKey]!,b=p.finalPositions[l.ownKey]!,t=p.finalPositions[l.enemyKey]!
    let occ=occlusion(c,b,t),options=opportunities(c,t,l.enemyKey,[b])
    var result:[String:Any]=["shot":s.json,"positions":[cueKey:point(c),l.ownKey:point(b),l.enemyKey:point(t)],
        "settled":p.hasFinalTableState,"pocketed":p.pocketedBalls,"events":events(p),"occlusion":occ.json,
        "visibleFractionSampled":visibleFraction(c,b,t),"opportunities":options]
    if occ.full { result["defenseScore"]=100 }
    else if let top=options.first { result["defenseScore"]=100-(top["score"] as! Double) }
    else { result["scoreStatus"]="unrated-no-direct-pot-candidate" }
    var tracks=[String:[[Double]]]()
    for key in [cueKey,l.ownKey,l.enemyKey] {
        tracks[key]=p.recorder!.framesByBallName[key]!.map { [Double($0.time),Double($0.position.x),Double($0.position.z)] }
    }
    result["tracks"]=tracks
    return result
}

do {
    let out=CommandLine.arguments[1]
    guard let model=TableModelLoader.loadTable(includeVisual:false),let node=model.cueStickNode else { throw NSError(domain:"cue-profile",code:1) }
    let profile=CueStick(modelCueStickNode:node).clearanceProfile
    precondition(!profile.isEmpty)
    func access(_ c:SCNVector3,_ balls:[SCNVector3],_ s:Stroke) -> Bool {
        let a=CueStrikeAccess(cue:c,aim:s.direction,obstacles:balls,surfaceY:surface,profile:profile)
        return a.isAvailable(spinX:0,spinY:Double(s.spinY)) && (a.resolvedPose(spinX:0,spinY:Double(s.spinY))?.elevation ?? 100)<=CueStick.minElevationRadians+0.000001
    }
    try write(["length":Double(TablePhysics.innerLength),"width":Double(TablePhysics.innerWidth),"radius":Double(radius),"cueKey":cueKey,
        "pockets":table.pockets.map { ["id":$0.id,"center":point($0.center)] },"cueProfileSections":profile.count],out+"/geometry.json")
    var selected=[[String:Any]](),diagnostics=[[String:Any]](),counts=[String:Int]()
    var used=[(SCNVector3,SCNVector3)]()
    func fail(_ key:String) { counts[key,default:0] += 1 }
    var layouts=[(SCNVector3,SCNVector3)]()
    for x in [-1.18,-1.08,-0.9,-0.6] {
        for z in [0.0,0.28,-0.28] {
            for c in [[-0.6,0.38],[0.0,-0.38],[0.6,0.25],[-0.2,0.32]] { layouts.append((vector(c[0],c[1]),vector(x,z))) }
        }
    }
    search: for (index,pair) in layouts.enumerated() {
        let (c,b)=pair
        guard placement([c,b]) else { continue }
        if used.contains(where:{distance(c,$0.0)<0.25 && distance(b,$0.1)<0.15}) { continue }
        let base=atan2f(b.z-c.z,b.x-c.x),half=asinf(2*radius/Float(distance(c,b)))
        print("LAYOUT \(index) selected=\(selected.count)");fflush(stdout)
        for sy:Float in [0,-0.2,0.2] {
            for speed:Float in [0.5,0.7,0.9,1.1,1.4,1.8] {
                for aimIndex in -20...20 {
                    let a=base+half*Float(aimIndex)/20*0.98
                    let s=Stroke(direction:SCNVector3(cosf(a),0,sinf(a)),speed:speed,spinY:sy)
                    guard access(c,[b],s) else { fail("prototype-cue-access");continue }
                    let p=autoreleasepool { simulate(c,[ObstacleBall(name:"_1",position:b)],s) }
                    guard rejection(p,"_1",[cueKey,"_1"])==nil else { fail("prototype-illegal");continue }
                    let fc=p.finalPositions[cueKey]!,fb=p.finalPositions["_1"]!,d=distance(fc,fb)
                    guard d>Double(2*radius)+0.01,d<0.55 else { continue }
                    for extensionDistance in [0.55,0.85,1.15] {
                        let e=vector(Double(fb.x)+(Double(fb.x-fc.x)/d)*extensionDistance,
                                     Double(fb.z)+(Double(fb.z-fc.z)/d)*extensionDistance)
                        guard placement([c,b,e]) else { fail("enemy-placement");continue }
                        let branch=selected.count%2==0 ? "A":"B"
                        let l=DefensePilotLayout(cue:c,own:b,enemy:e,ownKey:branch=="A" ? "_1":"_8",enemyKey:branch=="A" ? "_8":"_9")
                        guard visibleFraction(c,b,e)>0.5 else { fail("already-obscured");continue }
                        let initial=opportunities(c,b,l.ownKey,[e])
                        guard let best=initial.first,let comfort=best["score"] as? Double,comfort<=40 else { fail("opening-not-rated-difficult");continue }
                        guard access(c,[b,e],s) else { fail("full-cue-access");continue }
                        let full=simulate(l,s)
                        if let why=rejection(full,l.ownKey,[cueKey,l.ownKey,l.enemyKey]) { fail(why);continue }
                        let occ=occlusion(full.finalPositions[cueKey]!,full.finalPositions[l.ownKey]!,full.finalPositions[l.enemyKey]!)
                        guard occ.full else { fail("not-fully-blocked");continue }
                        var probes=[[String:Any]](),robust=true
                        for da:Float in [-0.15,0,0.15] {
                            for factor:Float in [0.95,1,1.05] where da != 0 || factor != 1 {
                                let angle=a+da*Float.pi/180
                                let ps=Stroke(direction:SCNVector3(cosf(angle),0,sinf(angle)),speed:speed*factor,spinY:sy)
                                var r:[String:Any]=["angleDeltaDegrees":Double(da),"speedFactor":Double(factor),"shot":ps.json]
                                if !access(c,[b,e],ps) { r["rejection"]="cue-access";robust=false }
                                else {
                                    let pp=simulate(l,ps)
                                    if let why=rejection(pp,l.ownKey,[cueKey,l.ownKey,l.enemyKey]) { r["rejection"]=why;robust=false }
                                    else {
                                        let pr=record(l,pp,ps);r["result"]=pr
                                        if (pr["occlusion"] as! [String:Any])["full"] as! Bool == false { robust=false }
                                    }
                                }
                                probes.append(r)
                            }
                        }
                        guard robust else {
                            fail("not-robust-eight-probes")
                            if diagnostics.count<8 { diagnostics.append(["positions":l.json,"ownKey":l.ownKey,"enemyKey":l.enemyKey,"reference":record(l,full,s),"probes":probes]) }
                            continue
                        }
                        // Same opening, legal alternative with exposed target. Not a manufactured final state.
                        var comparison:[String:Any]?
                        comparisonSearch: for factor:Float in [1.35,0.7,1.7] {
                            for da:Float in [-2,2,-1,1,0] {
                                let angle=a+da*Float.pi/180
                                let cs=Stroke(direction:SCNVector3(cosf(angle),0,sinf(angle)),speed:speed*factor,spinY:sy)
                                if !access(c,[b,e],cs) { continue }
                                let cp=simulate(l,cs)
                                if rejection(cp,l.ownKey,[cueKey,l.ownKey,l.enemyKey]) != nil { continue }
                                let cr=record(l,cp,cs)
                                if cr["visibleFractionSampled"] as! Double > 0.25 { comparison=cr;break comparisonSearch }
                            }
                        }
                        guard let comparison else { fail("no-exposed-comparison");continue }
                        let replay=simulate(l,s)
                        let reference=record(l,full,s),repeated=record(l,replay,s)
                        guard try JSONSerialization.data(withJSONObject:reference,options:.sortedKeys)==JSONSerialization.data(withJSONObject:repeated,options:.sortedKeys) else { throw NSError(domain:"replay-mismatch",code:2) }
                        let id="D2-\(branch)-\(selected.count/2+1)"
                        selected.append(["id":id,"branch":branch,"ownKey":l.ownKey,"enemyKey":l.enemyKey,"positions":l.json,
                            "sourceIdea":"c060 steps 2/6: hide the cue/target using a ball; new generated layout, not replay of original",
                            "generation":"simulate cue+own, extend final cue-own line to propose enemy, then full three-ball revalidation",
                            "openingComfort":comfort,"openingOpportunities":initial,"openingEnemyVisibilitySampled":visibleFraction(c,b,e),
                            "reference":reference,"comparison":comparison,"perturbations":probes,"exactReplay":true])
                        used.append((c,b))
                        try write(selected,out+"/questions.json")
                        try write(diagnostics,out+"/diagnostics.json")
                        print("ACCEPT \(id) initial=\(comfort) margin=\(occ.angularMargin*180/Double.pi) sims=\(simulations)");fflush(stdout)
                        if selected.count>=6 { break search }
                        continue search
                    }
                }
            }
        }
    }
    try write(["selected":selected.count,"simulations":simulations,"rejections":counts,"searchLayouts":layouts.count,
        "scope":"bounded generated samples; straight planar access only, no claim about kicks/jumps or win probability"],out+"/summary.json")
    guard selected.count>=2,selected.contains(where:{$0["branch"] as! String=="A"}),selected.contains(where:{$0["branch"] as! String=="B"}) else { throw NSError(domain:"insufficient-two-branch-samples",code:selected.count) }
    print("DONE \(selected.count) samples / \(simulations) simulations")
} catch { fputs("ERROR \(error)\n",stderr);exit(1) }
