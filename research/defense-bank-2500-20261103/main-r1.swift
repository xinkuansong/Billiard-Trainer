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
    var state:UInt64=20261103500
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

do {
    let out=CommandLine.arguments[1],target=Int(CommandLine.arguments[2])!,maxBases=Int(CommandLine.arguments[3])!
    guard let model=TableModelLoader.loadTable(includeVisual:false),let node=model.cueStickNode else { throw NSError(domain:"cue-profile",code:1) }
    let profile=CueStick(modelCueStickNode:node).clearanceProfile
    precondition(!profile.isEmpty)
    func access(_ l:DefensePilotLayout,_ s:Stroke) -> Bool {
        let a=CueStrikeAccess(cue:l.cue,aim:s.direction,obstacles:l.balls.map(\.position),surfaceY:surface,profile:profile)
        return a.isAvailable(spinX:0,spinY:Double(s.spinY)) && (a.resolvedPose(spinX:0,spinY:Double(s.spinY))?.elevation ?? 100)<=CueStick.minElevationRadians+0.000001
    }
    func valid(_ p:ShotPrediction,_ l:DefensePilotLayout) -> String? {
        if let why=rejection(p,l.ownKey,l.keys) { return why }
        if !clean(p) { return "pocket-jaw-contact" }
        if distance(p.finalPositions[l.enemyKey]!,l.enemy)>0.00001 { return "enemy-moved" }
        if let black=l.black,distance(p.finalPositions["_8"]!,black)>0.00001 { return "black-moved" }
        return nil
    }
    func blocked(_ p:ShotPrediction,_ l:DefensePilotLayout) -> Bool {
        let bs=[p.finalPositions[l.ownKey]!]+(l.black == nil ? []:[p.finalPositions["_8"]!])
        return unionProof(p.finalPositions[cueKey]!,bs,p.finalPositions[l.enemyKey]!)["full"] as! Bool
    }
    let seeds=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/proposals.json"))) as! [[String:Any]]
    func pos(_ a:Any) -> SCNVector3 { let v=a as! [Double];return vector(v[0],v[1]) }
    try write(["length":Double(TablePhysics.innerLength),"width":Double(TablePhysics.innerWidth),"radius":Double(radius),"cueKey":cueKey,
        "pockets":table.pockets.map { ["id":$0.id,"center":point($0.center)] },"cueProfileSections":profile.count],out+"/geometry.json")
    var rng=GeneratorRNG(),counts=[String:Int](),familyCounts=[String:Int](),coverage=[String:[String:Int]](),manifest=[[String:Any]]()
    var baseAttempts=0,proposals=0
    let started=Date()
    func fail(_ why:String) { counts[why,default:0] += 1 }
    func progress() throws {
        try write(["targetPerFamily":target,"selected":manifest.count,"familyCounts":familyCounts,"coverage":coverage,"simulations":simulations,"baseAttempts":baseAttempts,"proposals":proposals,"rejections":counts,"elapsedSeconds":Date().timeIntervalSince(started)],out+"/progress.json")
        try write(manifest,out+"/index.json")
        print("PROGRESS selected=\(manifest.count) bases=\(baseAttempts) sims=\(simulations) counts=\(familyCounts)");fflush(stdout)
    }
    for family in ["twoA","twoB","own","black","joint"] {
      var used=[(SCNVector3,SCNVector3)]()
      let expected=(family=="twoA" || family=="twoB") ? "two":family
      let ownKey=family=="twoB" ? "_8":"_1",enemyKey=family=="twoA" ? "_8":"_9"
      try FileManager.default.createDirectory(atPath:out+"/questions/"+family,withIntermediateDirectories:true)
      for z in ["long","short","open"] {
        let quota=z=="long" ? target/2:z=="short" ? Int((Double(target)*0.3).rounded()):target-target/2-Int((Double(target)*0.3).rounded())
        let pool=seeds.filter { $0["zone"] as! String==z }
        var attempts=0,accepted=0
        baseSearch: while accepted<quota && attempts<maxBases {
          attempts += 1;baseAttempts += 1
          if baseAttempts%200==0 { try progress() }
          let seed=pool[rng.index(pool.count)],originalC=pos(seed["cue"]!),originalB=pos(seed["own"]!)
          let c=vector(Double(originalC.x)+rng.range(-0.55,0.55),Double(originalC.z)+rng.range(-0.3,0.3))
          let b=vector(Double(originalB.x)+rng.range(-0.4,0.4),Double(originalB.z)+rng.range(-0.22,0.22))
          guard placement([c,b]),zone(b)==z,distance(c,b)>0.18 else { fail("base-placement");continue }
          guard !nearBase(c,b,used) else { fail("near-or-mirror-base");continue }
          let heading=atan2f(b.z-c.z,b.x-c.x),half=asinf(2*radius/Float(distance(c,b)))
          let sourceShot=seed["shot"] as! [String:Any],sourceSpeed=sourceShot["speed"] as! Double
          let fraction=seed["cutFraction"] as! Double
          for trial in 0..<12 {
            let cut=Float(max(-0.98,min(0.98,fraction+rng.range(-0.22,0.22))))
            let angle=heading+half*cut
            let speed=Float(trial<8 ? sourceSpeed*rng.range(0.7,1.5):rng.range(0.4,1.8))
            let spin=Float(trial<8 ? sourceShot["spinY"] as! Double:[-0.2,0,0.2][rng.index(3)])
            let shot=Stroke(direction:SCNVector3(cosf(angle),0,sinf(angle)),speed:speed,spinY:spin)
            let prototype=autoreleasepool { simulate(c,[ObstacleBall(name:ownKey,position:b)],shot) }
            guard rejection(prototype,ownKey,[cueKey,ownKey])==nil,clean(prototype) else { fail("prototype-illegal");continue }
            let fc=prototype.finalPositions[cueKey]!,fb=prototype.finalPositions[ownKey]!,db=distance(fc,fb)
            guard db>Double(2*radius)+0.02,db<0.95 else { fail("prototype-separation");continue }
            let ab=atan2(Double(fb.z-fc.z),Double(fb.x-fc.x)),hb=asin(Double(2*radius)/db)
            func polar(_ distance:Double,_ angle:Double) -> SCNVector3 { vector(Double(fc.x)+distance*cos(angle),Double(fc.z)+distance*sin(angle)) }
            for proposalIndex in 0..<24 {
              proposals += 1
              var black:SCNVector3?=nil
              let enemy:SCNVector3
              if expected=="two" || family=="own" {
                enemy=polar(db+rng.range(0.35,1.4),ab+rng.range(-0.02,0.02))
                if family=="own" { black=vector(rng.range(-1.1,1.1),rng.range(-0.48,0.48)) }
              } else if family=="black" {
                let a=ab+rng.range(-Double.pi,Double.pi),d=rng.range(0.14,0.5)
                black=polar(d,a);enemy=polar(d+rng.range(0.35,1.2),a)
              } else {
                let sign=proposalIndex%2==0 ? 1.0:-1.0,portion=rng.range(0.65,0.96),depth=rng.range(0.8,1.2)
                let a=ab+sign*hb*portion,kAngle=a+sign*asin(Double(2*radius)/(db*depth))*portion
                black=polar(db*depth,kAngle);enemy=polar(db+rng.range(0.35,0.9),a)
              }
              let l=DefensePilotLayout(cue:c,own:b,enemy:enemy,black:black,ownKey:ownKey,enemyKey:enemyKey)
              let obstacles=[b]+(black == nil ? []:[black!])
              guard placement([c]+l.balls.map(\.position)) else { fail("full-placement");continue }
              guard visibleUnion(c,obstacles,enemy)>0.5 else { fail("already-obscured");continue }
              let options=opportunities(c,b,ownKey,[enemy]+(black == nil ? []:[black!]))
              guard let best=options.first,let comfort=best["score"] as? Double,comfort<=40 else { fail("opening-comfort");continue }
              guard access(l,shot) else { fail("cue-access");continue }
              let full=simulate(l,shot)
              if let why=valid(full,l) { fail(why);continue }
              guard tactic(full,l)==expected else { fail("tactic");continue }
              var probes=[[String:Any]](),robust=true
              probeLoop: for da:Float in [-0.15,0,0.15] { for sf:Float in [0.95,1,1.05] where da != 0 || sf != 1 {
                let a=angle+da*Float.pi/180
                let ps=Stroke(direction:SCNVector3(cosf(a),0,sinf(a)),speed:speed*sf,spinY:spin)
                if !access(l,ps) { robust=false;break probeLoop }
                let p=simulate(l,ps)
                if valid(p,l) != nil || !blocked(p,l) { robust=false;break probeLoop }
                probes.append(["angleDeltaDegrees":Double(da),"speedFactor":Double(sf),"shot":ps.json,"result":record(l,p,ps,false)])
              } }
              guard robust else { fail("small-probes");continue }
              var comparison:[String:Any]?
              comparisonSearch: for sf:Float in [1.35,0.7,1.7,0.5,2] { for da:Float in [-2,2,-1,1,0] {
                let a=angle+da*Float.pi/180
                let cs=Stroke(direction:SCNVector3(cosf(a),0,sinf(a)),speed:speed*sf,spinY:spin)
                if !access(l,cs) { continue }
                let p=simulate(l,cs)
                if rejection(p,ownKey,l.keys) != nil { continue }
                let r=record(l,p,cs)
                if r["visibleFractionSampled"] as! Double>0.25 { comparison=r;break comparisonSearch }
              } }
              guard let comparison else { fail("no-comparison");continue }
              let reference=record(l,full,shot),replay=record(l,simulate(l,shot),shot)
              guard try JSONSerialization.data(withJSONObject:reference,options:.sortedKeys)==JSONSerialization.data(withJSONObject:replay,options:.sortedKeys) else { throw NSError(domain:"replay-mismatch",code:2) }
              var stress=[[String:Any]]()
              for (tier,angular,relativeSpeed) in [("medium",Float(0.3),Float(0.1)),("wide",Float(0.6),Float(0.15))] {
                for da in [-angular,0,angular] { for sf in [1-relativeSpeed,1,1+relativeSpeed] where da != 0 || sf != 1 {
                  let a=angle+da*Float.pi/180
                  let ps=Stroke(direction:SCNVector3(cosf(a),0,sinf(a)),speed:speed*sf,spinY:spin)
                  var r:[String:Any]=["tier":tier,"angleDeltaDegrees":Double(da),"speedFactor":Double(sf),"shot":ps.json]
                  if !access(l,ps) { r["rejection"]="cue-access" }
                  else { let p=simulate(l,ps);if let why=rejection(p,ownKey,l.keys) { r["rejection"]=why;r["events"]=events(p) } else { r["result"]=record(l,p,ps,false) } }
                  stress.append(r)
                } }
              }
              familyCounts[family,default:0] += 1;accepted += 1
              coverage[family,default:[:]][z]=accepted
              let id=String(format:"DB-%@-%04d",family,familyCounts[family]!)
              let q:[String:Any]=["id":id,"family":family,"zone":z,"ownKey":ownKey,"enemyKey":enemyKey,"positions":l.json,"sourceProposal":seed,"generationBase":baseAttempts,
                "openingComfort":comfort,"openingOpportunities":options,"openingEnemyVisibilitySampled":visibleUnion(c,obstacles,enemy),"reference":reference,"comparison":comparison,"perturbations":probes,"stressProbes":stress,"exactReplay":true]
              let path="questions/\(family)/\(id).json"
              try write(q,out+"/"+path)
              manifest.append(["id":id,"family":family,"zone":z,"file":path,"openingComfort":comfort,"positions":l.json])
              used.append((c,b))
              if manifest.count%25==0 { try progress() }
              continue baseSearch
            }
          }
        }
        try progress()
        if accepted<quota { print("SHORTFALL \(family) \(z): \(accepted)/\(quota)");fflush(stdout) }
      }
    }
    try progress()
    try write(["complete":familyCounts.values.reduce(0,+)==target*5,"familyCounts":familyCounts,"coverage":coverage,"simulations":simulations,"baseAttempts":baseAttempts,"proposals":proposals,"elapsedSeconds":Date().timeIntervalSince(started)],out+"/summary.json")
    guard manifest.count==target*5 else { throw NSError(domain:"quota-shortfall",code:manifest.count) }
    print("DONE \(manifest.count) questions / \(simulations) simulations")
} catch { fputs("ERROR \(error)\n",stderr);exit(1) }
