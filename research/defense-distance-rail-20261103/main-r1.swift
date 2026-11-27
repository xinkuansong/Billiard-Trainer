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
        return ["pocket":index,"aim":point(p.aim),"cutDegrees":p.cutDegrees,"score":s.total,"distance":s.distance,"space":s.space,"angle":s.angle] as [String:Any]
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
// Exact angular exposure for a blocker whose entire expanded disc precedes target.
// Reject unproven depth ordering; no finite-ray rounding can promote a boundary case.
func visibleFraction(_ c:SCNVector3,_ blocker:SCNVector3,_ target:SCNVector3) -> Double {
    let db=distance(c,blocker),dt=distance(c,target),r=Double(2*radius)
    guard db>r,dt>r,dt-db-2*r>0 else { return -1 }
    let a=atan2(Double(blocker.z-c.z),Double(blocker.x-c.x))-atan2(Double(target.z-c.z),Double(target.x-c.x))
    let delta=atan2(sin(a),cos(a)),h=asin(r/dt),bh=asin(r/db)
    return 1-max(0,min(h,delta+bh)-max(-h,delta-bh))/(2*h)
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
    let black:SCNVector3?
    let ownKey:String
    let enemyKey:String
    var balls:[ObstacleBall] {
        var a=[ObstacleBall(name:ownKey,position:own),ObstacleBall(name:enemyKey,position:enemy)]
        if let black { a.append(ObstacleBall(name:"_8",position:black)) };return a
    }
    var keys:[String] { [cueKey]+balls.map(\.name) }
    var json:[String:Any] { var a:[String:Any]=[cueKey:point(cue)];for b in balls { a[b.name]=point(b.position) };return a }
}
var simulations=0
func simulate(_ c:SCNVector3,_ balls:[ObstacleBall],_ shot:Stroke) -> ShotPrediction {
    simulations += 1
    return ShotPredictor.simulateFree(cueBall:c,aimDir:shot.direction,velocity:shot.speed,spinX:0,spinY:shot.spinY,surfaceY:surface,
        balls:balls,maxEvents:1500,maxTime:60,recordedStrikeDirection:shot.direction)
}
func simulate(_ l:DefensePilotLayout,_ s:Stroke) -> ShotPrediction {
    simulate(l.cue,l.balls,s)
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
func record(_ l:DefensePilotLayout,_ p:ShotPrediction,_ s:Stroke,_ includeTracks:Bool=true) -> [String:Any] {
    let c=p.finalPositions[cueKey]!,b=p.finalPositions[l.ownKey]!,t=p.finalPositions[l.enemyKey]!
    let bs=[b]+(l.black == nil ? []:[p.finalPositions["_8"]!])
    let occ=unionProof(c,bs,t),options=opportunities(c,t,l.enemyKey,bs)
    var positions=[String:[Double]]();for key in l.keys { positions[key]=point(p.finalPositions[key]!) }
    var result:[String:Any]=["shot":s.json,"positions":positions,
        "settled":p.hasFinalTableState,"pocketed":p.pocketedBalls,"events":events(p),"occlusion":occ,
        "visibleFractionSampled":visibleUnion(c,bs,t),"opportunities":options]
    if occ["full"] as! Bool { result["defenseScore"]=100 }
    else if let top=options.first { result["defenseScore"]=100-(top["score"] as! Double) }
    else { result["scoreStatus"]="unrated-no-direct-pot-candidate" }
    var tracks=[String:[[Double]]]()
    for key in l.keys where includeTracks {
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
func tactic(_ p:ShotPrediction,_ l:DefensePilotLayout) -> String {
    let c=p.finalPositions[cueKey]!,b=p.finalPositions[l.ownKey]!,t=p.finalPositions[l.enemyKey]!
    if l.black == nil { return occlusion(c,b,t).full ? "two":"unproven" }
    let k=p.finalPositions["_8"]!
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

struct GeneratorRNG {
    var state:UInt64=20261103501
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11)/9007199254740992
    }
    mutating func range(_ a:Double,_ b:Double) -> Double { a+(b-a)*next() }
    mutating func index(_ n:Int) -> Int { min(n-1,Int(next()*Double(n))) }
}
func zone(_ p:SCNVector3) -> String {
    if Double(TablePhysics.innerLength/2-abs(p.x)-radius)<0.18 { return "short" }
    if Double(TablePhysics.innerWidth/2-abs(p.z)-radius)<0.18 { return "long" }
    return "open"
}
func nearBase(_ c:SCNVector3,_ b:SCNVector3,_ previous:[(SCNVector3,SCNVector3)]) -> Bool {
    for (a,d) in previous {
        for sx:Float in [-1,1] { for sz:Float in [-1,1] {
            if distance(c,SCNVector3(a.x*sx,a.y,a.z*sz))<0.06 && distance(b,SCNVector3(d.x*sx,d.y,d.z*sz))<0.06 { return true }
        } }
    }
    return false
}

func metrics(_ l:DefensePilotLayout,_ p:ShotPrediction) -> [String:Double]? {
    let c=p.finalPositions[cueKey]!,t=p.finalPositions[l.enemyKey]!,b=p.finalPositions[l.ownKey]!
    let blockers=[b]+(l.black == nil ? []:[p.finalPositions["_8"]!])
    guard let best=opportunities(c,t,l.enemyKey,blockers).first else { return nil }
    let d=best["distance"] as! Double,a=best["angle"] as! Double,s=best["space"] as! Double,total=best["score"] as! Double
    let withoutSpace=0.5*min(d,a)+0.5*pow(d*100*a,1.0/3)
    return ["ballDistance":distance(c,t),"distanceGain":distance(c,t)-distance(l.cue,l.enemy),"cueRailGap":gap(c),"enemyRailGap":gap(t),"comfort":total,"distanceComponent":d,"angleComponent":a,"spaceComponent":s,"spacePenalty":withoutSpace-total,"visibility":visibleUnion(c,blockers,t)]
}
func qualifies(_ m:[String:Double],_ kind:String,_ probe:Bool=false) -> Bool {
    guard m["visibility"]!>0.95 else { return false }
    if kind=="long" {
        if probe { return m["ballDistance"]!>=1.35 && m["distanceGain"]!>=0.30 && m["comfort"]!<=45 }
        return m["ballDistance"]!>=1.5 && m["distanceGain"]!>=0.45 && m["cueRailGap"]!>=0.04 && m["comfort"]!<=35 && m["angleComponent"]!>=50 && m["distanceComponent"]!<=min(m["spaceComponent"]!,m["angleComponent"]!)
    }
    if probe { return m["cueRailGap"]!<=0.05 && m["comfort"]!<=60 }
    return m["cueRailGap"]!<=0.015 && m["ballDistance"]!<1.4 && m["comfort"]!<=50 && m["spacePenalty"]!>=5
}
do {
 let out=CommandLine.arguments[1]
 guard let model=TableModelLoader.loadTable(includeVisual:false),let node=model.cueStickNode else { throw NSError(domain:"cue-profile",code:1) }
 let profile=CueStick(modelCueStickNode:node).clearanceProfile
 func access(_ l:DefensePilotLayout,_ s:Stroke) -> Bool {
  let a=CueStrikeAccess(cue:l.cue,aim:s.direction,obstacles:l.balls.map(\.position),surfaceY:surface,profile:profile)
  return a.isAvailable(spinX:0,spinY:Double(s.spinY)) && (a.resolvedPose(spinX:0,spinY:Double(s.spinY))?.elevation ?? 100)<=CueStick.minElevationRadians+0.000001
 }
 func valid(_ p:ShotPrediction,_ l:DefensePilotLayout) -> Bool {
  if rejection(p,l.ownKey,l.keys) != nil || !clean(p) { return false }
  if distance(p.finalPositions[l.enemyKey]!,l.enemy)>0.00001 { return false }
  if let k=l.black,distance(p.finalPositions["_8"]!,k)>0.00001 { return false };return true
 }
 func pos(_ a:Any) -> SCNVector3 { let p=a as! [Double];return vector(p[0],p[1]) }
 let seeds=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/candidate-input.json"))) as! [[String:Any]]
 try write(["length":Double(TablePhysics.innerLength),"width":Double(TablePhysics.innerWidth),"radius":Double(radius),"cueKey":cueKey,"pockets":table.pockets.map { ["id":$0.id,"center":point($0.center)] },"cueProfileSections":profile.count],out+"/geometry.json")
 var selected=[[String:Any]](),inventory=[[String:Any]]()
 let started=Date()
 for (seedIndex,seed) in seeds.enumerated() {
  let ps=seed["positions"] as! [String:Any],ownKey=seed["ownKey"] as! String,enemyKey=seed["enemyKey"] as! String,kind=seed["kind"] as! String
  let l=DefensePilotLayout(cue:pos(ps[cueKey]!),own:pos(ps[ownKey]!),enemy:pos(ps[enemyKey]!),black:ps.count==4 ? pos(ps["_8"]!):nil,ownKey:ownKey,enemyKey:enemyKey)
  if kind=="rail" && gap(l.cue)<=0.06 { continue }
  let opening=opportunities(l.cue,l.own,ownKey,[l.enemy]+(l.black == nil ? []:[l.black!]))
  guard let initial=opening.first,initial["score"] as! Double<=40 else { continue }
  let enemyOpening=opportunities(l.cue,l.enemy,enemyKey,[l.own]+(l.black == nil ? []:[l.black!]))
  let s=seed["shot"] as! [String:Any],dir=pos(s["direction"]!),angle=atan2f(dir.z,dir.x),speed=Float(s["speed"] as! Double),spin=Float(s["spinY"] as! Double)
  var best:[String:Any]?,bestMetric=Double.infinity,loose:[String:Any]?,looseComfort = -1.0
  for da:Float in [0,-0.6,0.6,-0.3,0.3] { for sf:Float in [1,0.9,1.1,0.8,1.2,0.65,1.4] {
   let a=angle+da*Float.pi/180,shot=Stroke(direction:SCNVector3(cosf(a),0,sinf(a)),speed:speed*sf,spinY:spin)
   if !access(l,shot) { continue }
   let p=simulate(l,shot)
   guard valid(p,l),let m=metrics(l,p) else { continue }
   if m["visibility"]!>0.95 && m["comfort"]!>looseComfort { looseComfort=m["comfort"]!;loose=record(l,p,shot) }
   guard qualifies(m,kind),m["comfort"]!<bestMetric else { continue }
   var probes=[[String:Any]](),good=true
   probeLoop: for delta:Float in [-0.15,0,0.15] { for factor:Float in [0.95,1,1.05] where delta != 0 || factor != 1 {
    let pa=a+delta*Float.pi/180,probe=Stroke(direction:SCNVector3(cosf(pa),0,sinf(pa)),speed:shot.speed*factor,spinY:spin)
    if !access(l,probe) { good=false;break probeLoop }
    let pp=simulate(l,probe)
    guard valid(pp,l),let mm=metrics(l,pp),qualifies(mm,kind,true) else { good=false;break probeLoop }
    probes.append(["angleDeltaDegrees":Double(delta),"speedFactor":Double(factor),"metrics":mm,"result":record(l,pp,probe,false)])
   } }
   if !good { continue }
   let reference=record(l,p,shot),replay=record(l,simulate(l,shot),shot)
   guard try JSONSerialization.data(withJSONObject:reference,options:.sortedKeys)==JSONSerialization.data(withJSONObject:replay,options:.sortedKeys) else { throw NSError(domain:"replay",code:2) }
   bestMetric=m["comfort"]!
   best=["id":String(format:"DR-%@-%03d",kind,seedIndex+1),"family":kind,"layoutFamily":seed["layoutFamily"]!,"ownKey":ownKey,"enemyKey":enemyKey,"positions":l.json,"openingComfort":initial["score"]!,"openingOpportunities":opening,"openingEnemyOpportunities":enemyOpening,"sourceProposal":seed,"reference":reference,"metrics":m,"perturbations":probes,"exactReplay":true]
  } }
  inventory.append(["seed":seed["id"]!,"kind":kind,"enemyOpening":enemyOpening.first?["score"] ?? -1,"bestComfort":bestMetric.isFinite ? bestMetric:-1,"looseComfort":looseComfort])
  if var b=best,let loose,looseComfort-bestMetric>=10 { b["comparison"]=loose;b["comparisonComfort"]=looseComfort;selected.append(b) }
  try write(selected,out+"/candidates.json");try write(inventory,out+"/inventory.json")
  print("PROGRESS \(seedIndex+1)/\(seeds.count) accepted=\(selected.count) sims=\(simulations)");fflush(stdout)
 }
 try write(["candidates":selected.count,"simulations":simulations,"elapsedSeconds":Date().timeIntervalSince(started),"scope":"finite candidate study; not global optimum, no App UI tested"],out+"/summary.json")
} catch { fputs("ERROR \(error)\n",stderr);exit(1) }
