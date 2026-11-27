import Foundation
import SceneKit
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
        if let state=play.stateAt(ballName:targetName,time:e.time){r["target"]=point(state.position)}
        return r
    }
}
struct RNG {
    var x:UInt64=2026110108
    mutating func next()->UInt64 { x = x &* 6364136223846793005 &+ 1442695040888963407;return x }
    mutating func uniform()->Float { Float(Double(next()>>11)/9007199254740992.0) }
}
func rail(_ i:Int)->BankShotCalculator.Rail { [.far,.near,.left,.right][i] }
func wall(_ i:Int)->Int { let n=geometry.linearCushions[i].normal;return abs(n.x)>0.5 ? (n.x>0 ? 0:1):(n.z>0 ? 2:3) }
func sequences(_ n:Int)->[[Int]] {
    var result=[[Int]]()
    func add(_ a:[Int]) {
        if a.count==n {result.append(a);return}
        for i in 0..<4 {
            if a.last==i {continue}
            if a.count>=2 && a[a.count-2]==i && a.last!/2==i/2 {continue}
            add(a+[i])
        }
    };add([]);return result
}
func reason(_ p:ShotPrediction,_ n:Int,_ pocket:Int,_ expected:[Int])->String? {
    guard p.hasFinalTableState,p.recorder != nil else{return "incomplete"}
    guard let hit=p.events.firstIndex(where:{if case .ballBall = $0.kind{return true};return false}) else{return "no-contact"}
    guard case let .ballBall(a,b)=p.events[hit].kind,Set([a,b])==Set([cueName,targetName]) else{return "wrong-first-contact"}
    guard !p.events[..<hit].contains(where:{if case let .ballCushion(b)=$0.kind{return b==cueName};return false}) else{return "cue-first-rail"}
    guard let pot=p.events.firstIndex(where:{if case let .pocket(b,id)=$0.kind{return b==targetName && id==geometry.pockets[pocket].id};return false}) else{return "not-selected-pocket"}
    if p.pocketedBalls.contains(cueName){return "scratch"}
    if p.events[(hit+1)..<pot].contains(where:{if case .ballBall = $0.kind{return true};return false}){return "second-ball-contact"}
    let rr=p.events[(hit+1)..<pot].filter{if case let .ballCushion(b)=$0.kind{return b==targetName && ($0.cushionIndex ?? -1)>=0 && ($0.cushionIndex ?? 99)<6};return false}
    let walls=rr.map{wall($0.cushionIndex!)}
    if walls.count != n || walls != expected{return "route-mismatch"}
    // A jaw may participate in normal entry only AFTER all main-rail contacts,
    // close to the selected pocket. No jaw-assisted bank route is accepted.
    let lastMain=rr.last!.time
    for e in p.events[(hit+1)..<pot] {
        if case let .ballCushion(b)=e.kind,b==targetName,!(0..<6).contains(e.cushionIndex ?? -1) {
            guard e.time>=lastMain,let q=playback(p).stateAt(ballName:targetName,time:e.time)?.position,
                dist(point(q),point(geometry.pockets[pocket].center))<0.18 else{return "jaw-assisted-route"}
        }
    }
    return nil
}
func exact(_ cue:[Float],_ target:[Float],_ d:[Float],_ v:Float,_ sx:Float)->ShotPrediction? {
    let direction=SCNVector3(d[0],0,d[1])
    let access=CueStrikeAccess(cue:vec(cue),aim:direction,obstacles:[vec(target)],surfaceY:surface,profile:profile)
    guard legal(cue.map(Double.init)),legal(target.map(Double.init)),dist(cue.map(Double.init),target.map(Double.init))>Double(2*radius),access.isAvailable(spinX:Double(sx),spinY:0),access.resolvedPose(spinX:Double(sx),spinY:0) != nil else{return nil}
    return ShotPredictor.simulateFree(cueBall:vec(cue),aimDir:direction,velocity:v,spinX:sx,spinY:0,surfaceY:surface,balls:[ObstacleBall(name:targetName,position:vec(target))],maxEvents:1500,maxTime:60,recordedStrikeDirection:direction)
}
func record(_ p:ShotPrediction)->[String:Any] {
    let hit=p.events.first(where:{if case .ballBall = $0.kind{return true};return false})!.time
    let po=p.events.first(where:{if case let .pocket(b,_)=$0.kind{return b==targetName};return false})!.time
    let tr=trajectory(p,targetName,from:hit,to:po)
    let length=zip(tr,tr.dropFirst()).reduce(0.0){$0+dist(Array($1.0.suffix(2)),Array($1.1.suffix(2)))}
    let before=playback(p).stateAt(ballName:cueName,time:max(0,hit-0.00001))!
    let after=playback(p).stateAt(ballName:targetName,time:hit+0.00001)!
    let u=before.velocity,w=after.velocity
    let angle=acos(max(-1,min(1,Double(u.x*w.x+u.z*w.z)/max(1e-12,hypot(Double(u.x),Double(u.z))*hypot(Double(w.x),Double(w.z))))))*180/Double.pi
    return ["events":events(p),"cueTrack":trajectory(p,cueName,to:hit),"cueAfter":trajectory(p,cueName,from:hit),"targetTrack":tr,"contactTime":Double(hit),"potTime":Double(po),"pathLength":length,"actualCutAngle":angle,"duration":Double(p.duration),"complete":p.hasFinalTableState,"pocketedBalls":p.pocketedBalls]
}
struct Candidate { let target:[Float];let cue:[Float];let pocket:Int;let walls:[Int];let cut:Float;let distance:Float;let order:UInt64 }
do {
    let args=CommandLine.arguments,out=args[2]
    if args[1]=="geometry" {
        try json(["radius":Double(radius),"length":Double(TablePhysics.innerLength),"width":Double(TablePhysics.innerWidth),"rails":geometry.linearCushions.prefix(6).enumerated().map{i,r in ["id":i,"start":point(r.start),"end":point(r.end),"normal":point(r.normal)] as [String:Any]},"pockets":geometry.pockets.map{["id":$0.id,"center":point($0.center),"radius":Double($0.radius),"lip":$0.captureLip.map{[Double($0.x),Double($0.y)]}] as [String:Any]}],out);exit(0)
    }
    if args[1]=="verify" {
        let rows=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/selected.json"))) as! [[String:Any]]
        var proofs=[[String:Any]]()
        for r in rows {
            let c=(r["cue"] as! [Double]).map(Float.init),o=(r["target"] as! [Double]).map(Float.init),d=(r["direction"] as! [Double]).map(Float.init)
            guard let p=exact(c,o,d,Float(r["speed"] as! Double),Float(r["spinX"] as! Double)),reason(p,r["n"] as! Int,r["pocket"] as! Int,r["walls"] as! [Int])==nil else{throw NSError(domain:"replay-failed",code:1)}
            let old=try JSONSerialization.data(withJSONObject:r["events"]!,options:.sortedKeys),new=try JSONSerialization.data(withJSONObject:events(p),options:.sortedKeys)
            guard old==new else{throw NSError(domain:"event-replay-drift",code:2)}
            proofs.append(["id":r["id"]!,"exactReplay":true,"events":p.events.count])
        }
        try json(proofs,out+"/verification.json");print("VERIFIED \(proofs.count)");exit(0)
    }
    var rng=RNG(),targets=[[Float]]()
    for ix in 0..<10 {for iz in 0..<6 {
        let x:Float = -1.14+(Float(ix)+rng.uniform())*0.228
        let z:Float = -0.50+(Float(iz)+rng.uniform())/6.0
        targets.append([x,z])
    }}
    var selected=[[String:Any]](),stats=[[String:Any]]()
    for type in 0..<2 {for n in 1...4 {
        var candidates=[Candidate]()
        let pockets=type==0 ? [4,5]:[0,1,2,3]
        for o in targets {for pk in pockets {for walls in sequences(n) {
            guard let path=BankShotCalculator.bankSeedPath(object:vec(o),pocketIndex:pk,rails:walls.map(rail),surfaceY:surface),path.count==n+2 else{continue}
            let length=zip(path,path.dropFirst()).reduce(Float(0)){$0+hypot($1.1.x-$1.0.x,$1.1.z-$1.0.z)}
            guard length<8.5 else{continue}
            // Candidate contacts must lie on finite production main rails, not in pocket openings.
            guard path[1...n].allSatisfy({q in geometry.linearCushions.prefix(6).contains{r in segdist(point(q),point(r.start),point(r.end))<0.003 && dist(point(q),point(r.start))>0.035 && dist(point(q),point(r.end))>0.035}}) else{continue}
            let theta=atan2(path[1].z-o[1],path[1].x-o[0])
            let ghost:[Float]=[o[0]-2*radius*cos(theta),o[1]-2*radius*sin(theta)]
            for cut:Float in [-50,-30,-12,12,30,50] {
                let a=theta+cut*Float.pi/180
                let distance:Float=[0.30,0.45,0.60,0.75,0.90,1.05][Int(rng.next()%6)]
                let c=[ghost[0]-distance*cos(a),ghost[1]-distance*sin(a)]
                guard legal(c.map(Double.init)),legal(o.map(Double.init)) else{continue}
                candidates.append(Candidate(target:o,cue:c,pocket:pk,walls:walls,cut:cut,distance:distance,order:rng.next()))
            }
        }}}
        candidates.sort{$0.order<$1.order}
        print("CATEGORY \(type)-\(n) candidates=\(candidates.count)");fflush(stdout)
        var accepted=[[String:Any]](),attempts=0,rejections=[String:Int](),seqCounts=[String:Int](),pocketCounts=[Int:Int]()
        outer:for sx:Float in [0,-0.15,0.15] {
            for c in candidates {
                if accepted.count==6 {break outer}
                if attempts>=3000 {break outer}
                let seq=c.walls.map(String.init).joined(separator:"-")
                if seqCounts[seq,default:0]>=2 || pocketCounts[c.pocket,default:0]>=(type==0 ? 3:2) {continue}
                if accepted.contains(where:{dist($0["target"] as! [Double],c.target.map(Double.init))<0.16}) {continue}
                let speeds:[Float]=n==1 ? [1.8,2.5,3.2,4.0] : (n==2 ? [2.5,3.2,4.0,4.8]:[3.2,4.0,4.8,5.6])
                for v in speeds {
                    attempts+=1
                    let result:([String:Any]?,String)=autoreleasepool {
                        var input=ShotInput(cueBall:vec(c.cue),targetBall:vec(c.target),pocketIndex:c.pocket,velocity:v,spinX:sx,spinY:0,surfaceY:surface)
                        input.bankRails=c.walls.map(rail)
                        let p=ShotPredictor.predict(input,maxEvents:1500,maxTime:60)
                        if let why=reason(p,n,c.pocket,c.walls){return(nil,why)}
                        guard let d=p.strikeDirection,let replay=exact(c.cue,c.target,[d.x,d.z],v,sx) else{return(nil,"inaccessible")}
                        if let why=reason(replay,n,c.pocket,c.walls){return(nil,"replay-"+why)}
                        var r=record(replay)
                        r.merge(["id":"\(type==0 ? "M":"C")\(n)-\(String(format:"%02d",accepted.count+1))","n":n,"type":type==0 ? "middle":"corner","cue":c.cue.map(Double.init),"target":c.target.map(Double.init),"pocket":c.pocket,"walls":c.walls,"direction":[Double(d.x),Double(d.z)],"speed":Double(v),"spinX":Double(sx),"spinY":0,"generationCut":Double(c.cut),"generationDistance":Double(c.distance),"seedOrder":String(c.order)]){_,b in b}
                        return(r,"")
                    }
                    if let r=result.0 {
                        accepted.append(r);selected.append(r);seqCounts[seq,default:0]+=1;pocketCounts[c.pocket,default:0]+=1
                        try json(selected,out+"/selected.json")
                        print("ACCEPT \(r["id"]!) speed=\(v) spin=\(sx) trials=\(attempts)");fflush(stdout);break
                    } else {rejections[result.1,default:0]+=1}
                    if attempts%50==0 {print("PROGRESS \(type)-\(n) \(attempts) accepted=\(accepted.count) rejects=\(rejections)");fflush(stdout)}
                }
            }
        }
        stats.append(["type":type,"n":n,"candidateCount":candidates.count,"attempts":attempts,"accepted":accepted.count,"rejections":rejections]);try json(stats,out+"/generation-summary.json")
    }}
    guard selected.count==48 else{throw NSError(domain:"quota-not-filled",code:selected.count)}
    print("GENERATED \(selected.count)")
} catch {fputs("ERROR \(error)\n",stderr);exit(1)}
