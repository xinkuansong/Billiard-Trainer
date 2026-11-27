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
    let black:SCNVector3
    let ownKey:String
    let enemyKey:String
    var json:[String:Any] { [cueKey:point(cue),ownKey:point(own),enemyKey:point(enemy),"_8":point(black)] }
}
var simulations=0
func simulate(_ c:SCNVector3,_ balls:[ObstacleBall],_ shot:Stroke) -> ShotPrediction {
    simulations += 1
    return ShotPredictor.simulateFree(cueBall:c,aimDir:shot.direction,velocity:shot.speed,spinX:0,spinY:shot.spinY,surfaceY:surface,
        balls:balls,maxEvents:1500,maxTime:60,recordedStrikeDirection:shot.direction)
}
func simulate(_ l:DefensePilotLayout,_ s:Stroke) -> ShotPrediction {
    simulate(l.cue,[ObstacleBall(name:l.ownKey,position:l.own),ObstacleBall(name:l.enemyKey,position:l.enemy),ObstacleBall(name:"_8",position:l.black)],s)
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
    let black=p.finalPositions["_8"]!
    let occ=unionProof(c,[b,black],t),options=opportunities(c,t,l.enemyKey,[b,black])
    var result:[String:Any]=["shot":s.json,"positions":[cueKey:point(c),l.ownKey:point(b),l.enemyKey:point(t),"_8":point(black)],
        "settled":p.hasFinalTableState,"pocketed":p.pocketedBalls,"events":events(p),"occlusion":occ,
        "visibleFractionSampled":visibleUnion(c,[b,black],t),"opportunities":options]
    if occ["full"] as! Bool { result["defenseScore"]=100 }
    else if let top=options.first { result["defenseScore"]=100-(top["score"] as! Double) }
    else { result["scoreStatus"]="unrated-no-direct-pot-candidate" }
    var tracks=[String:[[Double]]]()
    for key in [cueKey,l.ownKey,l.enemyKey,"_8"] {
        tracks[key]=p.recorder!.framesByBallName[key]!.map { [Double($0.time),Double($0.position.x),Double($0.position.z)] }
    }
    result["tracks"]=tracks
    return result
}

func hasCueBank(_ p:ShotPrediction) -> Bool {
    guard let hit=p.events.first(where:{ if case .ballBall = $0.kind { return true };return false }) else { return false }
    return p.events.contains { e in
        if case let .ballCushion(name)=e.kind {
            return name==cueKey && e.time>hit.time && (0..<6).contains(e.cushionIndex ?? -1)
        }
        return false
    }
}

// Conservative continuous angular-union proof. Each included blocker is entirely
// nearer than the target. Shrinking intervals adds a numerical margin; false means
// unproven, never automatically exposed. Full union need not be full for either ball.
func unionProof(_ c:SCNVector3,_ bs:[SCNVector3],_ t:SCNVector3) -> [String:Any] {
    let dt=distance(c,t),r=Double(2*radius)
    guard dt>r else { return ["full":false,"intervals":[],"halfAngle":0] }
    let at=atan2(Double(t.z-c.z),Double(t.x-c.x)),half=asin(r/dt)
    var intervals=[[Double]]()
    for b in bs {
        let db=distance(c,b)
        guard db>r,dt-db-2*r>0 else { continue }
        let ab=atan2(Double(b.z-c.z),Double(b.x-c.x))
        let delta=atan2(sin(ab-at),cos(ab-at)),h=asin(r/db)
        intervals.append([delta-h+1e-6,delta+h-1e-6])
    }
    intervals.sort { $0[0]<$1[0] }
    var end = -half
    for interval in intervals {
        if interval[0]<=end { end=max(end,interval[1]) }
    }
    return ["full":end>=half,"intervals":intervals,"halfAngle":half]
}
func visibleUnion(_ c:SCNVector3,_ bs:[SCNVector3],_ t:SCNVector3) -> Double {
    let d=distance(c,t);if d<=Double(2*radius) { return 1 }
    let a=atan2(Double(t.z-c.z),Double(t.x-c.x)),h=asin(Double(2*radius)/d)
    var visible=0
    for i in 0...256 {
        let angle=a+h*(Double(i)/128-1)
        guard let td=rayEntry(c,t,angle) else { continue }
        if bs.contains(where:{ (rayEntry(c,$0,angle) ?? Double.infinity)<td }) { continue }
        visible += 1
    }
    return Double(visible)/257
}
func tactic(_ p:ShotPrediction) -> String {
    let c=p.finalPositions[cueKey]!,b=p.finalPositions["_1"]!,k=p.finalPositions["_8"]!,t=p.finalPositions["_9"]!
    guard unionProof(c,[b,k],t)["full"] as! Bool else { return "unproven" }
    let own=occlusion(c,b,t).full,black=occlusion(c,k,t).full
    if own && !black { return "own" }
    if black && !own { return "black" }
    if !own && !black && visibleFraction(c,b,t)>0.05 && visibleFraction(c,k,t)>0.05 { return "joint" }
    return "redundant"
}
func clean(_ p:ShotPrediction) -> Bool {
    !p.events.contains { e in if case .ballCushion = e.kind { return !(0..<6).contains(e.cushionIndex ?? -1) };return false }
}

do {
    let out=CommandLine.arguments[1]
    guard let model=TableModelLoader.loadTable(includeVisual:false),let node=model.cueStickNode else { throw NSError(domain:"cue-profile",code:1) }
    let profile=CueStick(modelCueStickNode:node).clearanceProfile
    precondition(!profile.isEmpty)
    func access(_ l:DefensePilotLayout,_ s:Stroke) -> Bool {
        let a=CueStrikeAccess(cue:l.cue,aim:s.direction,obstacles:[l.own,l.enemy,l.black],surfaceY:surface,profile:profile)
        return a.isAvailable(spinX:0,spinY:Double(s.spinY)) && (a.resolvedPose(spinX:0,spinY:Double(s.spinY))?.elevation ?? 100)<=CueStick.minElevationRadians+0.000001
    }
    let keys=[cueKey,"_1","_8","_9"]
    func valid(_ p:ShotPrediction,_ l:DefensePilotLayout) -> String? {
        if let why=rejection(p,"_1",keys) { return why }
        if !clean(p) { return "pocket-jaw-contact" }
        // This first teaching batch uses an existing black screen, without a cannon.
        if distance(p.finalPositions["_8"]!,l.black)>0.00001 || distance(p.finalPositions["_9"]!,l.enemy)>0.00001 { return "black-or-enemy-moved" }
        return nil
    }
    try write(["length":Double(TablePhysics.innerLength),"width":Double(TablePhysics.innerWidth),"radius":Double(radius),"cueKey":cueKey,
        "pockets":table.pockets.map { ["id":$0.id,"center":point($0.center)] },"cueProfileSections":profile.count],out+"/geometry.json")
    let seeds=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/proposals.json"))) as! [[String:Any]]
    var selected=[[String:Any]](),diagnostics=[[String:Any]](),counts=[String:Int](),familyCounts=[String:Int]()
    var candidates=0
    func fail(_ why:String) { counts[why,default:0] += 1 }
    func pos(_ a:Any) -> SCNVector3 { let v=a as! [Double];return vector(v[0],v[1]) }
    for family in ["own","black","joint"] {
      seedSearch: for (seedIndex,seed) in seeds.enumerated() {
        if familyCounts[family,default:0]>=2 { break }
        let c=pos(seed["cue"]!),b=pos(seed["own"]!),oldEnemy=pos(seed["enemy"]!)
        let shot=seed["shot"] as! [String:Any],dir=pos(shot["direction"]!)
        let base=atan2f(dir.z,dir.x),sy=Float(shot["spinY"] as! Double),speed=Float(shot["speed"] as! Double)
        print("SEED \(family) \(seedIndex) selected=\(selected.count)");fflush(stdout)
        for factor:Float in [1,0.9,1.1,0.8,1.2] {
          let s=Stroke(direction:SCNVector3(cosf(base),0,sinf(base)),speed:speed*factor,spinY:sy)
          let proto=simulate(c,[ObstacleBall(name:"_1",position:b)],s)
          guard rejection(proto,"_1",[cueKey,"_1"])==nil,clean(proto) else { continue }
          let fc=proto.finalPositions[cueKey]!,fb=proto.finalPositions["_1"]!,db=distance(fc,fb)
          guard db>Double(2*radius)+0.02 else { continue }
          let ab=atan2(Double(fb.z-fc.z),Double(fb.x-fc.x)),hb=asin(Double(2*radius)/db)
          func polar(_ length:Double,_ angle:Double) -> SCNVector3 { vector(Double(fc.x)+length*cos(angle),Double(fc.z)+length*sin(angle)) }
          var proposals=[(SCNVector3,SCNVector3)]() // black, enemy; proposal only
          if family=="own" {
            for x in [-0.8,-0.35,0.15,0.65] { for z in [-0.4,0.0,0.4] { proposals.append((vector(x,z),oldEnemy)) } }
          } else if family=="black" {
            for offset in [Double.pi/2,-Double.pi/2,Double.pi/3,-Double.pi/3,Double.pi,0.35,-0.35] {
              for d in [0.16,0.24,0.34,0.48] { for extra in [0.45,0.7,1.0] {
                proposals.append((polar(d,ab+offset),polar(d+extra,ab+offset)))
              } }
            }
          } else {
            for sign in [-1.0,1.0] { for fraction in [0.65,0.75,0.85,0.95] {
              for extra in [0.35,0.5,0.7,1.0] { for depth in [0.8,1.0,1.2] {
                let targetAngle=ab+sign*hb*fraction
                let blackAngle=targetAngle+sign*asin(Double(2*radius)/(db*depth))*fraction
                proposals.append((polar(db*depth,blackAngle),polar(db+extra,targetAngle)))
              } }
            } }
          }
          for (black,enemy) in proposals {
            candidates += 1
            let l=DefensePilotLayout(cue:c,own:b,enemy:enemy,black:black,ownKey:"_1",enemyKey:"_9")
            guard placement([c,b,black,enemy]) else { fail("placement");continue }
            guard visibleUnion(c,[b,black],enemy)>0.5 else { fail("opening-already-obscured");continue }
            let initial=opportunities(c,b,"_1",[black,enemy])
            guard let best=initial.first,let comfort=best["score"] as? Double,comfort<=40 else { fail("opening-not-rated-difficult");continue }
            guard access(l,s) else { fail("cue-access");continue }
            let full=simulate(l,s)
            if let why=valid(full,l) { fail(why);continue }
            guard tactic(full)==family else { fail("tactic-mismatch");continue }
            var probes=[[String:Any]](),robust=true
            for da:Float in [-0.15,0,0.15] { for sf:Float in [0.95,1,1.05] where da != 0 || sf != 1 {
                let a=base+da*Float.pi/180
                let ps=Stroke(direction:SCNVector3(cosf(a),0,sinf(a)),speed:s.speed*sf,spinY:sy)
                var r:[String:Any]=["angleDeltaDegrees":Double(da),"speedFactor":Double(sf),"shot":ps.json]
                if !access(l,ps) { r["rejection"]="cue-access";robust=false }
                else {
                    let p=simulate(l,ps)
                    if let why=valid(p,l) { r["rejection"]=why;robust=false }
                    else {
                        r["result"]=record(l,p,ps);r["tactic"]=tactic(p)
                        if !(unionProof(p.finalPositions[cueKey]!,[p.finalPositions["_1"]!,p.finalPositions["_8"]!],p.finalPositions["_9"]!)["full"] as! Bool) { robust=false }
                    }
                }
                probes.append(r)
            } }
            guard robust else {
                fail("not-robust-eight")
                if diagnostics.count<12 { diagnostics.append(["family":family,"positions":l.json,"reference":record(l,full,s),"probes":probes]) }
                continue
            }
            var comparison:[String:Any]?
            comparisonSearch: for sf:Float in [1.35,0.7,1.7,0.5,2] { for da:Float in [-2,2,-1,1,0,-4,4] {
                let a=base+da*Float.pi/180
                let cs=Stroke(direction:SCNVector3(cosf(a),0,sinf(a)),speed:s.speed*sf,spinY:sy)
                if !access(l,cs) { continue }
                let cp=simulate(l,cs)
                if rejection(cp,"_1",keys) != nil { continue }
                let cr=record(l,cp,cs)
                if cr["visibleFractionSampled"] as! Double>0.25 { comparison=cr;break comparisonSearch }
            } }
            guard let comparison else { fail("no-exposed-comparison");continue }
            let reference=record(l,full,s),replay=record(l,simulate(l,s),s)
            guard try JSONSerialization.data(withJSONObject:reference,options:.sortedKeys)==JSONSerialization.data(withJSONObject:replay,options:.sortedKeys) else { throw NSError(domain:"replay-mismatch",code:2) }
            var stress=[[String:Any]]()
            for (tier,angular,relativeSpeed) in [("medium",Float(0.3),Float(0.1)),("wide",Float(0.6),Float(0.15))] {
              for da in [-angular,0,angular] { for sf in [1-relativeSpeed,1,1+relativeSpeed] where da != 0 || sf != 1 {
                let a=base+da*Float.pi/180
                let ps=Stroke(direction:SCNVector3(cosf(a),0,sinf(a)),speed:s.speed*sf,spinY:sy)
                var r:[String:Any]=["tier":tier,"angleDeltaDegrees":Double(da),"speedFactor":Double(sf),"shot":ps.json]
                if !access(l,ps) { r["rejection"]="cue-access" }
                else {
                    let p=simulate(l,ps)
                    if let why=rejection(p,"_1",keys) { r["rejection"]=why;r["events"]=events(p) }
                    else { r["result"]=record(l,p,ps) }
                }
                stress.append(r)
              } }
            }
            familyCounts[family,default:0] += 1
            let id="D3-\(family)-\(familyCounts[family]!)"
            selected.append(["id":id,"family":family,"ownKey":"_1","enemyKey":"_9","blackKey":"_8","positions":l.json,
                "sourceProposal":seed,"openingComfort":comfort,"openingOpportunities":initial,"openingEnemyVisibilitySampled":visibleUnion(c,[b,black],enemy),
                "reference":reference,"comparison":comparison,"perturbations":probes,"stressProbes":stress,"exactReplay":true])
            try write(selected,out+"/questions.json");try write(diagnostics,out+"/diagnostics.json")
            print("ACCEPT \(id) comfort=\(comfort) simulations=\(simulations)");fflush(stdout)
            continue seedSearch
          }
        }
      }
    }
    try write(["selected":selected.count,"simulations":simulations,"proposals":candidates,"familyCounts":familyCounts,"rejections":counts,
        "scope":"bounded four-ball simulation; own-first, no pot, post-contact rail; straight planar access only"],out+"/summary.json")
    guard familyCounts["own",default:0]>=1,familyCounts["black",default:0]>=1,familyCounts["joint",default:0]>=1 else { throw NSError(domain:"unfilled-tactic-family",code:selected.count) }
    print("DONE \(selected.count) samples / \(simulations) simulations")
} catch { fputs("ERROR \(error)\n",stderr);exit(1) }
