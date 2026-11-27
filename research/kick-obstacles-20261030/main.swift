import Foundation
import SceneKit

// World X–Z plane, metres, +Y up. All geometry/strike/physics from frozen production.
struct Seed: Codable {
    let id: String
    let cell, side, slot, rail: Int
    let cue, dir, railPoint: [Float]
    let initialAngle, v, sx, sy: Float
    let samples: [[Float]]
}
struct EventProof: Codable, Equatable {
    let index: Int
    let time: Double
    let kind: String
    let cue: [Double]?
    let balls: [String]?
    let ball: String?
    let rail: Int?
    let pocket: String?
}
func eventProof(_ value:Any)throws -> [EventProof] {
    try JSONDecoder().decode([EventProof].self,from:JSONSerialization.data(withJSONObject:value))
}
let cueName=ShotInput.cueBallName, targetName=ShotInput.targetBallName
let surface=BTTablePhysics.surfaceY, radius=BallPhysics.radius
let geometry=TableGeometry.chineseEightBallQiuJi(surfaceY:surface)
let profile=AccuracyTipSelector.renderedProfile()
func vec(_ a:[Float])->SCNVector3 { .init(a[0],surface+radius,a[1]) }
func point(_ a:SCNVector3)->[Double] { [Double(a.x),Double(a.z)] }
func json(_ a:Any,_ path:String)throws { try JSONSerialization.data(withJSONObject:a,options:[.sortedKeys]).write(to:URL(fileURLWithPath:path),options:.atomic) }
func plain<T:Encodable>(_ a:T)throws -> Any { try JSONSerialization.jsonObject(with:JSONEncoder().encode(a)) }
func dist(_ a:[Double],_ b:[Double])->Double { hypot(a[0]-b[0],a[1]-b[1]) }
func segdist(_ p:[Double],_ a:[Double],_ b:[Double])->Double {
    let dx=b[0]-a[0], dz=b[1]-a[1], l=dx*dx+dz*dz
    let u=l>0 ? max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/l)) : 0
    return hypot(p[0]-a[0]-u*dx,p[1]-a[1]-u*dz)
}
func legal(_ p:[Double])->Bool {
    guard abs(p[0])<Double(TablePhysics.innerLength/2-radius),abs(p[1])<Double(TablePhysics.innerWidth/2-radius) else { return false }
    // Conservative supported-plane placement; do not use the deep pocket circle alone.
    for pocket in geometry.pockets {
        let lip=pocket.captureLip.map { [Double($0.x),Double($0.y)] }
        if !lip.isEmpty {
            for i in lip.indices where segdist(p,lip[i],lip[(i+1)%lip.count])<Double(radius)+0.002 {return false}
        }
        if dist(p,point(pocket.center))<Double(pocket.radius+radius) {return false}
    }
    return true
}
func simulate(_ s:Seed,_ target:[Float]?,_ obstacles:[[Float]]=[])->ShotPrediction? {
    guard legal(s.cue.map(Double.init)) else{return nil}
    let d=SCNVector3(s.dir[0],0,s.dir[1])
    let balls=(target.map{[ObstacleBall(name:targetName,position:vec($0))]} ?? []) + obstacles.enumerated().map{ObstacleBall(name:"blocker-\($0.offset+1)",position:vec($0.element))}
    let sx=s.sx
    let access=CueStrikeAccess(cue:vec(s.cue),aim:d,obstacles:balls.map(\.position),surfaceY:surface,profile:profile)
    guard access.isAvailable(spinX:Double(sx),spinY:Double(s.sy)),access.resolvedPose(spinX:Double(sx),spinY:Double(s.sy)) != nil else{return nil}
    return ShotPredictor.simulateFree(cueBall:vec(s.cue),aimDir:d,velocity:s.v,
        spinX:sx,spinY:s.sy,surfaceY:surface,balls:balls,maxEvents:1500,maxTime:60,recordedStrikeDirection:d)
}
func playback(_ p:ShotPrediction)->TrajectoryPlayback { TrajectoryPlayback(recorder:p.recorder!,surfaceY:surface+radius) }
func trajectory(_ p:ShotPrediction,_ name:String,from:Float=0,to:Float?=nil)->[[Double]] {
    let end=min(to ?? p.duration,p.events.first(where:{ if case let .pocket(b,_)=$0.kind{return b==name};return false })?.time ?? p.duration)
    guard end>=from,p.recorder != nil else{return []}
    let play=playback(p)
    var times=Set((0...Int(ceil(Double(end-from)*60))).map{min(end,from+Float($0)/60)})
    for e in p.events where e.time>=from && e.time<=end {times.insert(e.time)}
    return times.sorted().compactMap{t in play.stateAt(ballName:name,time:t).map{[Double(t),Double($0.position.x),Double($0.position.z)]}}
}
func events(_ p:ShotPrediction)->[[String:Any]] {
    let play=playback(p)
    return p.events.enumerated().map{i,e in
        var r:[String:Any]=["index":i,"time":Double(e.time)]
        switch e.kind {
        case let .ballBall(a,b):r["kind"]="ballBall";r["balls"]=[a,b]
        case let .ballCushion(b):r["kind"]="cushion";r["ball"]=b;r["rail"]=e.cushionIndex ?? -1
        case let .pocket(b,id):r["kind"]="pocket";r["ball"]=b;r["pocket"]=id
        }
        if let state=play.stateAt(ballName:cueName,time:e.time){r["cue"]=point(state.position)}
        return r
    }
}
func railEvents(_ p:ShotPrediction,before:Int?=nil)->[Int] {
    p.events.indices.filter{i in
        guard i<(before ?? p.events.count) else{return false}
        if case let .ballCushion(b)=p.events[i].kind{return b==cueName};return false
    }
}
func safeRail(_ p:ShotPrediction,_ idx:Int)->Bool {
    let e=p.events[idx]
    guard let id=e.cushionIndex,id>=0,id<6,let q=playback(p).stateAt(ballName:cueName,time:e.time)?.position else{return false}
    let r=geometry.linearCushions[id],a=point(r.start),b=point(r.end),c=point(q)
    let l=dist(a,b),t=((c[0]-a[0])*(b[0]-a[0])+(c[1]-a[1])*(b[1]-a[1]))/l
    return t>=0.10 && t<=l-0.10
}
func angle(_ p:ShotPrediction,_ idx:Int)->Double {
    let e=p.events[idx]
    guard let id=e.cushionIndex,id>=0,id<6,let v=playback(p).stateAt(ballName:cueName,time:max(0,e.time-0.00001))?.velocity else{return -1}
    let n=geometry.linearCushions[id].normal, speed=hypot(Double(v.x),Double(v.z))
    return asin(min(1,abs(Double(v.x*n.x+v.z*n.z))/max(speed,1e-10)))*180/Double.pi
}
// Research-only thresholds, not formal bank rules.
func wall(_ id:Int)->Int {
    let n=geometry.linearCushions[id].normal
    return abs(n.x)>0.5 ? (n.x>0 ? 0:1) : (n.z>0 ? 2:3)
}
func hasOppositeReturn(_ walls:[Int])->Bool {
    guard walls.count>=3 else{return false}
    for i in 0...(walls.count-3) {
        let a=walls[i],b=walls[i+1]
        if a != b && a/2==b/2 && walls[i+2]==a {return true}
    }
    return false
}
func quota(_ n:Int)->Int {n==4 ? 4:8}
func routeFailure(_ p:ShotPrediction,_ ri:[Int])->String? {
    guard !ri.isEmpty else{return "no-cushion"}
    guard ri.allSatisfy({safeRail(p,$0)}) else{return "rail-pocket-buffer"}
    let angles=ri.map{angle(p,$0)}
    if angles.contains(where:{$0<15}) {return "shallow-angle"}
    if angles.contains(where:{$0>75}) {return "steep-angle"}
    let first=trajectory(p,cueName,to:p.events[ri[0]].time)
    let length=zip(first,first.dropFirst()).reduce(0.0){$0+dist(Array($1.0.suffix(2)),Array($1.1.suffix(2)))}
    if length<0.20 {return "short-first-leg"}
    let walls=ri.map{wall(p.events[$0].cushionIndex!)}
    if hasOppositeReturn(walls) {return "opposite-wall-return"}
    return nil
}
func evaluate(_ p:ShotPrediction,_ n:Int,_ expected:[Int])->(String?,Int,[Int]) {
    guard p.hasFinalTableState,p.recorder != nil,p.finalPositions.values.allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite}) else{return("incomplete",-1,[])}
    guard let hit=p.events.firstIndex(where:{if case let .ballBall(a,b)=$0.kind{return Set([a,b])==Set([cueName,targetName])};return false}) else{return("no-target-contact",-1,[])}
    let ri=railEvents(p,before:hit),ids=ri.map{p.events[$0].cushionIndex ?? -1}
    guard ids.count==n,ids==expected else{return("earlier-contact-or-route-changed",hit,ids)}
    guard ri.allSatisfy({safeRail(p,$0)}) else{return("rail-pocket-buffer",hit,ids)}
    if let reason=routeFailure(p,ri) {return(reason,hit,ids)}
    guard !p.pocketedBalls.contains(cueName) else{return("scratch",hit,ids)}
    return(nil,hit,ids)
}
func details(_ p:ShotPrediction,_ hit:Int)->[String:Any] {
    let t=hit>=0 ? p.events[hit].time:p.duration
    var row:[String:Any]=["events":events(p),"complete":p.hasFinalTableState,"termination":String(describing:p.termination),
        "duration":Double(p.duration),"pocketedBalls":p.pocketedBalls,"finalPositions":p.finalPositions.mapValues(point),
        "cueTrack":trajectory(p,cueName,to:t),"cueAfter":trajectory(p,cueName,from:t),"targetTrack":trajectory(p,targetName)]
    if hit>=0,let state=playback(p).stateAt(ballName:cueName,time:max(0,t-0.00001)) {
        row["contactSpeed"]=hypot(Double(state.velocity.x),Double(state.velocity.z));row["contactCue"]=point(state.position);row["contactTime"]=Double(t)
    }
    return row
}
func altered(_ s:Seed,_ degrees:Float,_ speed:Float,_ spin:Float)->Seed {
    let a=degrees * .pi / 180
    return Seed(id:s.id,cell:s.cell,side:s.side,slot:s.slot,rail:s.rail,cue:s.cue,dir:[cos(a),sin(a)],railPoint:s.railPoint,initialAngle:s.initialAngle,v:speed,sx:spin,sy:0,samples:s.samples)
}
func firstContact(_ p:ShotPrediction)->(Int,String)? {
    for (i,e) in p.events.enumerated() {
        if case let .ballBall(a,b)=e.kind, a==cueName || b==cueName {return(i,a==cueName ? b:a)}
    }
    return nil
}
func lowerSolution(_ p:ShotPrediction,_ n:Int)->Int? {
    guard p.hasFinalTableState,!p.pocketedBalls.contains(cueName),let (i,b)=firstContact(p),b==targetName else{return nil}
    let k=railEvents(p,before:i).count
    return k<n ? i:nil
}
func compactTrack(_ p:ShotPrediction,_ hit:Int)->[[Double]] {
    let t=trajectory(p,cueName,to:p.events[hit].time)
    // Preserve first/last and events; geometry is a placement heuristic only.
    var kept=[[Double]]()
    for q in t {if kept.isEmpty || dist(Array(q.suffix(2)),Array(kept.last!.suffix(2)))>0.012 {kept.append(q)}}
    if let last=t.last, kept.last != last {kept.append(last)}
    return kept
}
do {
    let args=CommandLine.arguments,mode=args[1],out=args[3]
    let requests=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:args[2]))) as! [[String:Any]]
    for (index,request) in requests.enumerated() {try autoreleasepool {
        let row=request["row"] as! [String:Any],id=request["id"] as! String,n=row["n"] as! Int
        let original=try JSONDecoder().decode(Seed.self,from:JSONSerialization.data(withJSONObject:row["seed"]!))
        let target=(row["target"] as! [Double]).map(Float.init)
        let blocks=(request["obstacles"] as? [[Double]] ?? []).map{$0.map(Float.init)}
        var result:[String:Any]=["id":id,"sourceID":row["id"]!,"n":n], solutions=[[String:Any]]()
        var calls=0,unavailable=0,incomplete=0
        if mode=="check" {
            guard let p=simulate(original,target,blocks),let (hit,first)=firstContact(p),first==targetName,
                  evaluate(p,n,row["rails"] as! [Int]).0==nil else {
                try json(["id":id,"referencePassed":false],out+"/"+id+"-check.json");return
            }
            let replay=simulate(original,target,blocks)!
            guard try eventProof(events(p))==eventProof(events(replay)) else{throw NSError(domain:"replay",code:1)}
            result["referencePassed"]=true;result["exactReplay"]=true;result["reference"]=details(p,hit)
            result["reference"]=(["success":true] as [String:Any]).merging(details(p,hit),uniquingKeysWith:{$1})
        }
        let step:Float=mode=="scan" ? 1:0.5
        let speeds:[Float]=mode=="scan" ? [1.5,2.5,3.5,4.5]:[1,1.5,2,2.5,3,3.5,4,4.5]
        let spins:[Float]=mode=="scan" ? [0,-0.25,0.25,-0.5,0.5]:[0,-0.125,0.125,-0.25,0.25,-0.375,0.375,-0.5,0.5]
        let angleCount=Int(360/step)
        for ai in 0..<angleCount {
            for speed in speeds {for spin in spins {autoreleasepool {
                let degrees=Float(ai)*step,s=altered(original,degrees,speed,spin)
                guard let p=simulate(s,target,blocks) else{unavailable+=1;return};calls+=1
                if !p.hasFinalTableState {incomplete+=1;return}
                if let hit=lowerSolution(p,n) {
                    solutions.append(["degrees":degrees,"v":speed,"sx":spin,"n":railEvents(p,before:hit).count,"track":compactTrack(p,hit),"rails":railEvents(p,before:hit).map{p.events[$0].cushionIndex ?? -1}])
                }
            }}}
            if ai%180==0 {print("\(mode) \(id) angle=\(Float(ai)*step) calls=\(calls) lower=\(solutions.count)");fflush(stdout)}
        }
        result["simulations"]=calls;result["unavailable"]=unavailable;result["incomplete"]=incomplete
        result["angleStepDegrees"]=step;result["speeds"]=speeds;result["spins"]=spins;result["spinY"]=0
        result["solutions"]=solutions;result["lowerSolutionCount"]=solutions.count
        try json(result,out+"/"+id+"-"+mode+".json")
        print("DONE \(index+1)/\(requests.count) \(mode) \(id) calls=\(calls) lower=\(solutions.count) incomplete=\(incomplete)");fflush(stdout)
    }}
}catch{fputs("ERROR \(error)\n",stderr);exit(1)}
