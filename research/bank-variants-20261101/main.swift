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
// The pocket is the terminal boundary too: A -> opposite B -> A-side pocket
// is the same redundant return as A -> B -> A, even without a third impact.
func redundantReturn(_ walls:[Int],_ pocket:Int)->Bool {
    if walls.count>=3 {
        for i in 0...(walls.count-3) {
            let a=walls[i],b=walls[i+1]
            if a != b && a/2==b/2 && walls[i+2]==a {return true}
        }
    }
    guard walls.count>=2 else{return false}
    let p=geometry.pockets[pocket].center
    var terminal=[Int]()
    if abs(p.x)>TablePhysics.innerLength/2 {terminal.append(p.x<0 ? 0:1)}
    if abs(p.z)>TablePhysics.innerWidth/2 {terminal.append(p.z<0 ? 2:3)}
    let a=walls[walls.count-2],b=walls.last!
    return a != b && a/2==b/2 && terminal.contains(a)
}
struct EventProof: Codable, Equatable {
    let index: Int
    let time: Double
    let kind: String
    let cue: [Double]?
    let target: [Double]?
    let balls: [String]?
    let ball: String?
    let rail: Int?
    let pocket: String?
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
    if zip(walls,walls.dropFirst()).contains(where:{$0/2 == $1/2}) {return "parallel-successive-rails"}
    if n>0 && pocket>=4 {
        guard let last=rr.last,let q=playback(p).stateAt(ballName:targetName,time:last.time)?.position,
            MiddlePocketRegion.assess(target:q,pocket:pocket,calibration:MiddlePocketRegion.production) == .inside else{return "middle-terminal-region"}
        guard let entry=entryEvidence(p),entry.minimum>=35 else{return "shallow-middle-entry"}
    }
    if redundantReturn(walls,pocket){return "redundant-opposite-return"}
    // A jaw may participate in normal entry only AFTER all main-rail contacts,
    // close to the selected pocket. No jaw-assisted bank route is accepted.
    let lastMain=rr.last?.time ?? p.events[hit].time
    for e in p.events[(hit+1)..<pot] {
        if case let .ballCushion(b)=e.kind,b==targetName,!(0..<6).contains(e.cushionIndex ?? -1) {
            guard e.time>=lastMain,let q=playback(p).stateAt(ballName:targetName,time:e.time)?.position,
                dist(point(q),point(geometry.pockets[pocket].center))<0.18 else{return "jaw-assisted-route"}
        }
    }
    return nil
}

// Actual incoming-to-pocket leg, ending before any jaw contact can change its direction.
// Sample velocities, not the post-capture collection animation or noisy tiny chords.
func entryEvidence(_ p:ShotPrediction)->(minimum:Double,samples:[[Double]])? {
    guard let pot=p.events.first(where:{if case let .pocket(b,_)=$0.kind{return b==targetName};return false}) else{return nil}
    let hits=p.events.filter{e in if case let .ballCushion(b)=e.kind {return b==targetName && (0..<6).contains(e.cushionIndex ?? -1) && e.time<pot.time};return false}
    guard let last=hits.last else{return nil}
    let jaw=p.events.first{e in if case let .ballCushion(b)=e.kind {return b==targetName && !(0..<6).contains(e.cushionIndex ?? -1) && e.time>last.time && e.time<pot.time};return false}
    let start=last.time+0.00001,end=(jaw?.time ?? pot.time)-0.00001
    guard end>start else{return nil}
    let pb=playback(p)
    let samples=(0...32).compactMap{i -> [Double]? in
        let t=start+(end-start)*Float(i)/32
        guard let state=pb.stateAt(ballName:targetName,time:t) else{return nil}
        let v=state.velocity
        guard hypot(Double(v.x),Double(v.z))>1e-6 else{return nil}
        return [Double(t),Double(v.x),Double(v.z),atan2(abs(Double(v.z)),abs(Double(v.x)))*180/Double.pi]
    }
    guard samples.count==33 else{return nil}
    return (samples.map{$0[3]}.min()!,samples)
}

func exact(_ cue:[Float],_ target:[Float],_ d:[Float],_ v:Float,_ sx:Float)->ShotPrediction? {
    let direction=SCNVector3(d[0],0,d[1])
    let access=CueStrikeAccess(cue:vec(cue),aim:direction,obstacles:[vec(target)],surfaceY:surface,profile:profile)
    guard legal(cue.map(Double.init)),legal(target.map(Double.init)),dist(cue.map(Double.init),target.map(Double.init))>Double(2*radius),access.isAvailable(spinX:Double(sx),spinY:0),access.resolvedPose(spinX:Double(sx),spinY:0) != nil else{return nil}
    return ShotPredictor.simulateFree(cueBall:vec(cue),aimDir:direction,velocity:v,spinX:sx,spinY:0,surfaceY:surface,balls:[ObstacleBall(name:targetName,position:vec(target))],maxEvents:1500,maxTime:60,recordedStrikeDirection:direction)
}

// Research bank adaptation: retain the production distance component and aggregation;
// space uses the actual incoming aim, angle uses the outgoing object direction and
// complete object route length. This is comfort ranking, not a bank-pot probability.
func bankComfort(_ cue:[Double],_ target:[Double],_ outgoing:[Double],_ incoming:[Double],_ length:Double)->[String:Double]? {
    let n=hypot(outgoing[0],outgoing[1]),m=hypot(incoming[0],incoming[1])
    guard n>1e-9,m>1e-9,length>1e-9 else{return nil}
    let u=outgoing.map{$0/n},v=incoming.map{$0/m}
    let aim=(target[0]+u[0]*length,target[1]+u[1]*length)
    guard let base=ShotComfortScore.evaluate(cue:(cue[0],cue[1]),ball:(target[0],target[1]),aim:aim) else{return nil}
    let hx=Double(TablePhysics.innerLength/2),hz=Double(TablePhysics.innerWidth/2),r=Double(radius)
    let gaps=[hx-cue[0]-r,hx+cue[0]-r,hz-cue[1]-r,hz+cue[1]-r]
    let directions=[-v[0],v[0],-v[1],v[1]]
    let penalties=zip(gaps,directions).map{gap,direction in (45+15*pow(max(direction,0),2))*exp(-pow(max(gap,0)*100/8,1.2))}
    let main=penalties.indices.max{penalties[$0]<penalties[$1]}!
    let adjacent=main<2 ? max(penalties[2],penalties[3]):max(penalties[0],penalties[1])
    let space=100-penalties[main]-min(8,0.25*adjacent)
    let cut=atan2(abs(v[0]*u[1]-v[1]*u[0]),v[0]*u[0]+v[1]*u[1])*180/Double.pi
    guard cut<90 else{return nil}
    let angle=100*exp(-pow(max(cut-min(15,9/length),0)/min(20,20*sqrt(0.6/length)),2))
    let total=0.5*min(base.distance,space,angle)+0.5*pow(base.distance*space*angle,1.0/3)
    return ["distance":base.distance,"space":space,"angle":angle,"total":total,"cut":cut,"pathLength":length,"cueTargetDistance":dist(cue,target)]
}
func eligibleComfort(_ c:[String:Double])->Bool { c["cueTargetDistance"]!>=0.40 && c["space"]!>=85 && c["cut"]!<=35 }
func comfortSanity()throws {
    var checks=0
    for angle in [0.0,15,30,45] {for dd in [0.25,0.6,1.1] {
        let target=[0.1,0.0],aim=[0.8,0.0],a=angle*Double.pi/180
        let cue=[target[0]-2*Double(radius)-dd*cos(a),-dd*sin(a)]
        let incoming=[cos(a),sin(a)]
        let prod=ShotComfortScore.evaluate(cue:(cue[0],cue[1]),ball:(target[0],target[1]),aim:(aim[0],aim[1]))!
        let bank=bankComfort(cue,target,[1,0],incoming,0.7)!
        for (key,value) in [("distance",prod.distance),("space",prod.space),("angle",prod.angle),("total",prod.total)] {
            guard abs(bank[key]!-value)<1e-8 else{throw NSError(domain:"comfort-straight-parity-"+key,code:1)}
        };checks+=1
    }}
    let regular=bankComfort([-0.6,0],[0,0],[1,0],[1,0],1)!
    let close=bankComfort([-0.15,0],[0,0],[1,0],[1,0],1)!
    let rail=bankComfort([-1.235,0],[-0.6,0],[1,0],[1,0],1)!
    guard regular["distance"]!>close["distance"]!,regular["space"]!>rail["space"]!,!eligibleComfort(close),!eligibleComfort(rail) else{throw NSError(domain:"comfort-penalty-regression",code:1)}
    let far=bankComfort([-0.85,0],[0.85,0],[1,0],[1,0],1)!
    guard far["distance"]!<85,far["total"]!<70,eligibleComfort(far) else{throw NSError(domain:"far-distance-wrongly-rejected",code:6)}
    print("COMFORT SANITY \(checks) production parity + close/rail negatives + far-low-score acceptance");fflush(stdout)
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
    return ["events":events(p),"cueTrack":trajectory(p,cueName,to:hit),"cueAfter":trajectory(p,cueName,from:hit),"targetTrack":tr,"contactTime":Double(hit),"potTime":Double(po),"pathLength":length,"actualCutAngle":angle,"scoreIncoming":[Double(u.x),Double(u.z)],"scoreOutgoing":[Double(w.x),Double(w.z)],"bankComfort":bankComfort(point(playback(p).stateAt(ballName:cueName,time:0)!.position),point(playback(p).stateAt(ballName:targetName,time:0)!.position),[Double(w.x),Double(w.z)],[Double(u.x),Double(u.z)],length)!,"duration":Double(p.duration),"complete":p.hasFinalTableState,"pocketedBalls":p.pocketedBalls]
}
struct Direct {
    let pocket:Int;let aim:SCNVector3;let score:Double;let cut:Double;let distance:Double
    var data:[String:Any] { ["pocket":pocket,"aim":point(aim),"score":score,"cut":cut,"distance":distance] }
}
func directOptions(_ c:[Float],_ o:[Float])->[Direct] {
    (0..<6).compactMap { pk in
        guard let d=DirectAngleResearch.candidate(cue:vec(c),target:vec(o),targetKey:"object",pocketIndex:pk,obstacles:[],surfaceY:surface),let score=d.comfortScore else{return nil}
        return Direct(pocket:pk,aim:d.aim,score:score,cut:d.cutDegrees,distance:d.targetPocketDistance)
    }.sorted { $0.cut < $1.cut }
}
func directComfortOptions(_ cue:[Float],_ target:[Float])->[[String:Any]] {
    (0..<6).compactMap{ pk in
        guard let c=DirectAngleResearch.candidate(cue:vec(cue),target:vec(target),targetKey:"object",pocketIndex:pk,obstacles:[],surfaceY:surface,maximizeTotal:true),let f=c.fullScore else{return nil}
        return ["pocket":pk,"aim":point(c.aim),"cut":c.cutDegrees,"distance":f.distance,"space":f.space,"angle":f.angle,"total":f.total] as [String:Any]
    }.sorted{($0["total"] as! Double)>($1["total"] as! Double)}
}
func category(_ d:Double)->Int { d<55 ? 0 : (d<65 ? 1:2) }
func nearestRail(_ p:[Double])->(Int,Double,Double) {
    let index=(0..<6).min { segdist(p,point(geometry.linearCushions[$0].start),point(geometry.linearCushions[$0].end)) < segdist(p,point(geometry.linearCushions[$1].start),point(geometry.linearCushions[$1].end)) }!
    let q=geometry.linearCushions[index],a=point(q.start),b=point(q.end)
    let dx=b[0]-a[0],dz=b[1]-a[1]
    let u=((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)
    return (index,u,segdist(p,a,b)-Double(radius))
}

func unit(_ v:[Double])->[Double] {let l=hypot(v[0],v[1]);return v.map{$0/l}}
func reflected(_ v:[Double],_ wall:Int)->[Double] {wall<2 ? [-v[0],v[1]]:[v[0],-v[1]]}
func nextBoundary(_ p:[Double],_ d:[Double])->(point:[Double],wall:Int,distance:Double)? {
    let hx=Double(TablePhysics.innerLength/2-radius),hz=Double(TablePhysics.innerWidth/2-radius)
    var options=[(Double,Int)]()
    for (axis,bounds) in [(0,hx),(1,hz)] where abs(d[axis])>1e-10 {
        for side in [-1.0,1] {
            let t=(side*bounds-p[axis])/d[axis]
            if t>1e-6 {options.append((t,axis==0 ? (side<0 ? 0:1):(side<0 ? 2:3)))}
        }
    }
    guard let hit=options.min(by:{$0.0<$1.0}) else{return nil}
    return ([p[0]+hit.0*d[0],p[1]+hit.0*d[1]],hit.1,hit.0)
}
func validRailPoint(_ p:[Double],_ w:Int)->Bool {
    geometry.linearCushions.prefix(6).enumerated().contains {i,r in
        guard wall(i)==w else{return false}
        let a=point(r.start),b=point(r.end),v=[b[0]-a[0],b[1]-a[1]],l=dist(a,b)
        let t=((p[0]-a[0])*v[0]+(p[1]-a[1])*v[1])/l
        return t>=0.04 && t<=l-0.04
    }
}
struct RouteSeed {
    let id:String;let parent:String?;let root:String;let pocket:Int;let region:Int
    let points:[[Double]];let walls:[Int];let aim:[Double];let direction:[Double];let entry:Double
    var data:[String:Any] {["id":id,"parent":parent as Any? ?? NSNull(),"root":root,"pocket":pocket,"region":region,"reversePoints":points,"reverseWalls":walls,"aim":aim,"reverseDirection":direction,"entryAngle":entry]}
}

struct Candidate {
    let target:[Float];let cue:[Float];let pocket:Int;let route:RouteSeed;let cut:Float;let distance:Float
    let options:[Direct];let boundaryPoint:[Double];let fraction:Double;let region:Int;let gap:Double
    let key:String;let rank:Double;let comfort:[String:Double]
}
func mapped(_ p:[Float],_ t:Int)->[Float] { [p[0]*(t==1 || t==3 ? -1:1),p[1]*(t==2 || t==3 ? -1:1)] }
func mapPocket(_ p:Int,_ t:Int)->Int {
    let q=mapped(point(geometry.pockets[p].center).map(Float.init),t)
    return geometry.pockets.indices.min{dist(q.map(Double.init),point(geometry.pockets[$0].center))<dist(q.map(Double.init),point(geometry.pockets[$1].center))}!
}
func mapWall(_ w:Int,_ t:Int)->Int { if w<2 && (t==1 || t==3) {return 1-w};if w>=2 && (t==2 || t==3){return 5-w};return w }
func solved(_ c:[Float],_ o:[Float],_ pk:Int,_ walls:[Int],_ speeds:[Float])->[String:Any]? {
    for v in speeds {
        var input=ShotInput(cueBall:vec(c),targetBall:vec(o),pocketIndex:pk,velocity:v,spinX:0,spinY:0,surfaceY:surface)
        if !walls.isEmpty {input.bankRails=walls.map(rail)}
        let p=ShotPredictor.predict(input,maxEvents:1500,maxTime:60)
        guard reason(p,walls.count,pk,walls)==nil,let d=p.strikeDirection,
              let replay=exact(c,o,[d.x,d.z],v,0),reason(replay,walls.count,pk,walls)==nil else{continue}
        var r=record(replay)
        if let entry=entryEvidence(replay) {r["entryAngleMin"]=entry.minimum;r["entryVelocitySamples"]=entry.samples}
        if !walls.isEmpty && ((r["actualCutAngle"] as! Double)>35 || !eligibleComfort(r["bankComfort"] as! [String:Double])) {continue}
        r.merge(["cue":c.map(Double.init),"target":o.map(Double.init),"pocket":pk,"walls":walls,"n":walls.count,"direction":[Double(d.x),Double(d.z)],"speed":Double(v),"spinX":0,"spinY":0]){_,b in b}
        return r
    };return nil
}
struct ScoreOnly: Decodable {let bankComfort:[String:Double]}
struct ScoreRow: Decodable {let id:String;let bankComfort:[String:Double];let directProof:ScoreOnly}
func verifyShot(_ r:[String:Any],_ expectedScore:[String:Double])throws {
    let c=(r["cue"] as! [Double]).map(Float.init),o=(r["target"] as! [Double]).map(Float.init),d=(r["direction"] as! [Double]).map(Float.init)
    guard let p=exact(c,o,d,Float(r["speed"] as! Double),Float(r["spinX"] as! Double)),reason(p,r["n"] as! Int,r["pocket"] as! Int,r["walls"] as! [Int])==nil else{throw NSError(domain:"replay-failed",code:1)}
    let a=try JSONDecoder().decode([EventProof].self,from:JSONSerialization.data(withJSONObject:r["events"]!))
    let b=try JSONDecoder().decode([EventProof].self,from:JSONSerialization.data(withJSONObject:events(p)))
    let score=record(p)["bankComfort"] as! [String:Double],oldScore=expectedScore
    guard score==oldScore else{throw NSError(domain:"comfort-replay-drift",code:4)}
    if (r["n"] as! Int)>0 && !eligibleComfort(score) {throw NSError(domain:"comfort-ineligible",code:5)}
    guard a==b else{throw NSError(domain:"event-drift",code:2)}
}
func enrich(_ source:[String:Any],_ bank:[String:Any],_ direct:[String:Any],_ opts:[Direct],_ cue:[Float],_ target:[Float],_ pocket:Int,_ walls:[Int],_ transform:Int)->[String:Any] {
    var r=source;r.merge(bank){_,b in b}
    let near=nearestRail(target.map(Double.init)),best=opts.first!
    r["cue"]=cue.map(Double.init);r["target"]=target.map(Double.init);r["pocket"]=pocket;r["walls"]=walls
    r["n"]=walls.count;r["transform"]=transform;r["bestDirect"]=best.data;r["directOptions"]=opts.map{$0.data}
    r["directProof"]=direct;r["angleBand"]=category(best.cut);r["directComfortOptions"]=directComfortOptions(cue,target)
    r["cueRailGap"]=nearestRail(cue.map(Double.init)).2;r["nearRail"]=near.0;r["railFraction"]=near.1;r["railGap"]=near.2
    let distance=dist(cue.map(Double.init),target.map(Double.init)),band=distance<1 ? 0:(distance<1.6 ? 1:2)
    r["distanceBand"]=band;r["sampleIndex"]=band
    return r
}
func mirror(_ source:[String:Any],transform:Int)->([String:Any]?,String?) {
    let c=mapped((source["cue"] as! [Double]).map(Float.init),transform)
    let o=mapped((source["target"] as! [Double]).map(Float.init),transform)
    let d=mapped((source["direction"] as! [Double]).map(Float.init),transform)
    let pk=mapPocket(source["pocket"] as! Int,transform),walls=(source["walls"] as! [Int]).map{mapWall($0,transform)}
    guard let p=exact(c,o,d,Float(source["speed"] as! Double),0) else{return(nil,"strike-unavailable")}
    if let fail=reason(p,walls.count,pk,walls){return(nil,fail)}
    let opts=directOptions(c,o);guard let best=opts.first else{return(nil,"no-legal-direct")}
    guard best.cut>=45 else{return(nil,"easy-direct")}
    var bank=record(p);guard (bank["actualCutAngle"] as! Double)<=35,eligibleComfort(bank["bankComfort"] as! [String:Double]) else{return(nil,"bank-angle-or-space")}
    guard let entry=entryEvidence(p) else{return(nil,"missing-entry")}
    bank["entryAngleMin"]=entry.minimum;bank["entryVelocitySamples"]=entry.samples
    bank["direction"]=d.map(Double.init);bank["speed"]=source["speed"];bank["spinX"]=0.0;bank["spinY"]=0.0
    guard let direct=solved(c,o,best.pocket,[],[1.5,2.0,2.5,3.2,4.0]),(direct["actualCutAngle"] as! Double)>=45 else{return(nil,"direct-reference-not-found")}
    var r=enrich(source,bank,direct,opts,c,o,pk,walls,transform)
    r["id"]=(source["id"] as! String)+"-S\(transform)"
    r["canonicalID"]=source["id"]
    r["seedPath"]=(source["seedPath"] as! [[Double]]).map{mapped($0.map(Float.init),transform).map(Double.init)}
    return(r,nil)
}
func perturb(_ base:[String:Any],attempt:Int,rng:inout RNG)->([String:Any]?,[String:Any]) {
    let o0=base["target"] as! [Double],q=base["seedRailPoint"] as! [Double]
    let path=base["seedPath"] as! [[Double]],walls=base["walls"] as! [Int]
    // Derive the ray from the full-precision reflected route. A Float ball very
    // close to the cushion amplifies quantization if used to recover direction.
    let v=reflected(unit([q[0]-path[2][0],q[1]-path[2][1]]),walls[0])
    let oldT=dist(o0,q),theta=atan2(-v[1],-v[0])
    let dt=(attempt==0 ? -1.0:1.0)*(0.01+Double(rng.uniform())*0.02)
    let dd=(rng.uniform()<0.5 ? -1.0:1.0)*(0.03+Double(rng.uniform())*0.05)
    let da=(rng.uniform()<0.5 ? -1.0:1.0)*(1+Double(rng.uniform())*2)
    var info:[String:Any]=["attempt":attempt,"targetDeltaMeters":dt,"cueDistanceDeltaMeters":dd,"cutDeltaDegrees":da]
    func rejected(_ name:String)->([String:Any]?,[String:Any]) {var x=info;x["rejected"]=name;return(nil,x)}
    guard let boundary=nextBoundary(q,v),oldT+dt>0,oldT+dt<boundary.distance else{return rejected("outside-first-leg")}
    let o=[Float(o0[0]+dt*v[0]),Float(o0[1]+dt*v[1])],wanted=(base["bankComfort"] as! [String:Double])["cueTargetDistance"]!+dd
    let cut=(base["generationCut"] as! Double)+da,rad=cut*Double.pi/180,diameter=2*Double(radius)
    guard wanted>=0.4,abs(cut)<=35 else{return rejected("distance-or-cut")}
    let distance = -diameter*cos(rad)+sqrt(wanted*wanted-pow(diameter*sin(rad),2))
    let ghost=[Double(o[0])-diameter*cos(theta),Double(o[1])-diameter*sin(theta)],ang=theta+rad
    let c=[Float(ghost[0]-distance*cos(ang)),Float(ghost[1]-distance*sin(ang))]
    guard legal(o.map(Double.init)),legal(c.map(Double.init)),nearestRail(o.map(Double.init)).2>=0 else{return rejected("illegal-placement")}
    let length=zip(path,path.dropFirst()).reduce(0.0){$0+dist($1.0,$1.1)}+dt
    guard let comfort=bankComfort(c.map(Double.init),o.map(Double.init),[-v[0],-v[1]],[cos(ang),sin(ang)],length),eligibleComfort(comfort) else{return rejected("comfort")}
    let opts=directOptions(c,o);guard let best=opts.first else{return rejected("no-legal-direct")}
    guard best.cut>=45 else{return rejected("easy-direct")}
    let pk=base["pocket"] as! Int
    guard let bank=solved(c,o,pk,walls,[1.5,2.0,2.5,3.2,4.0,4.8]) else{return rejected("bank-not-found")}
    guard let direct=solved(c,o,best.pocket,[],[1.5,2.0,2.5,3.2,4.0]),(direct["actualCutAngle"] as! Double)>=45 else{return rejected("direct-reference-not-found")}
    var r=enrich(base,bank,direct,opts,c,o,pk,walls,0)
    r["id"]=(base["id"] as! String)+"-P\(attempt)";r["variantKind"]="perturbation"
    r["canonicalCue"]=c.map(Double.init);r["canonicalTarget"]=o.map(Double.init)
    r["seedPath"]=[o.map(Double.init)]+Array(path.dropFirst());r["seedFraction"]=(oldT+dt)/boundary.distance
    r["generationCut"]=cut;r["generationDistance"]=distance;r["seedComfort"]=comfort
    info["accepted"]=true;r["perturbation"]=info
    return(r,info)
}
func variants(input:String,out:String)throws {
    let bases=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:input))) as! [[String:Any]]
    var rows=[[String:Any]](),log=[[String:Any]]()
    for base in bases {
        let baseID=base["id"] as! String,baseIndex=base["baseIndex"] as! Int
        var rng=RNG(x:2026110149 &+ UInt64(baseIndex+1)*104729),original=base
        original["baseID"]=baseID;original["variantKind"]="original"
        var canonical=[original],attempts=[[String:Any]](),successful=[[String:Any]]()
        for attempt in 0..<2 {
            let result:([String:Any]?,[String:Any])=autoreleasepool {perturb(original,attempt:attempt,rng:&rng)}
            attempts.append(result.1);if let row=result.0{successful.append(row)}
        }
        if let selected=successful.max(by:{abs(($0["perturbation"] as! [String:Any])["targetDeltaMeters"] as! Double)<abs(($1["perturbation"] as! [String:Any])["targetDeltaMeters"] as! Double)}) {canonical.append(selected)}
        var outcomes=[[String:Any]]()
        for source in canonical {for transform in ((base["type"] as! String)=="middle" ? [0,2]:[0,1,2,3]) {
            let result:([String:Any]?,String?)=autoreleasepool {mirror(source,transform:transform)}
            var entry:[String:Any]=["canonicalID":source["id"]!,"kind":source["variantKind"]!,"transform":transform]
            if let r=result.0 {rows.append(r);entry["acceptedID"]=r["id"]}
            else {entry["rejected"]=result.1!}
            outcomes.append(entry)
        }}
        log.append(["baseID":baseID,"baseIndex":baseIndex,"perturbationAttempts":attempts,"canonicalPerturbationID":canonical.count==2 ? canonical[1]["id"]! : NSNull(),"outcomes":outcomes])
        try json(["basesCompleted":log.count,"rows":rows.count],out+"/progress.json")
        print("BASE \(baseIndex) selected=\(rows.count)");fflush(stdout)
    }
    try json(rows,out+"/selected.json");try json(log,out+"/decisions.json")
}

do {
    let args=CommandLine.arguments,out=args[2]
    try comfortSanity()
    if args[1]=="regression" {
        let old=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out))) as! [[String:Any]]
        var checks=[[String:Any]]()
        for row in old where ["M-45-2","M-55-2"].contains(row["id"] as! String) {
            let p=exact((row["cue"] as! [Double]).map(Float.init),(row["target"] as! [Double]).map(Float.init),(row["direction"] as! [Double]).map(Float.init),Float(row["speed"] as! Double),0)!
            let rejection=reason(p,1,row["pocket"] as! Int,row["walls"] as! [Int])
            guard rejection=="shallow-middle-entry" else{throw NSError(domain:"old-shallow-not-rejected",code:7)}
            checks.append(["id":row["id"]!,"rejected":rejection!,"entryAngleMin":entryEvidence(p)!.minimum])
        }
        guard checks.count==2 else{throw NSError(domain:"missing-shallow-fixtures",code:8)}
        let a=nextBoundary([0,Double(TablePhysics.innerWidth/2-radius)],unit([-0.8,-0.6]))!
        let b=nextBoundary(a.point,reflected(unit([-0.8,-0.6]),a.wall))!
        guard a.wall==0,b.wall==2,validRailPoint(a.point,a.wall),validRailPoint(b.point,b.wall) else{throw NSError(domain:"extension-axes",code:9)}
        let bad=nextBoundary([0,Double(TablePhysics.innerWidth/2-radius)],unit([0.1,-1]))!
        guard bad.wall/2==3/2 else{throw NSError(domain:"parallel-fixture",code:10)}
        try json(["oldShallowRows":checks,"perpendicularChain":[3,a.wall,b.wall],"parallelRejected":true],args[3]);print("EXTENSION REGRESSIONS passed");exit(0)
    }
    if args[1]=="geometry" {
        try json(["radius":Double(radius),"length":Double(TablePhysics.innerLength),"width":Double(TablePhysics.innerWidth),"rails":geometry.linearCushions.prefix(6).enumerated().map{i,r in ["id":i,"start":point(r.start),"end":point(r.end),"normal":point(r.normal)] as [String:Any]},"pockets":geometry.pockets.map{["id":$0.id,"center":point($0.center),"radius":Double($0.radius),"lip":$0.captureLip.map{[Double($0.x),Double($0.y)]}] as [String:Any]}],out);exit(0)
    }
    if args[1]=="verify" {
        let rows=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/selected.json"))) as! [[String:Any]]
        // Decode floating score fields directly from original JSON bytes. JSONSerialization
        // NSNumber bridging changes some small Double values by multiple ULPs.
        let exactScores=try JSONDecoder().decode([ScoreRow].self,from:Data(contentsOf:URL(fileURLWithPath:out+"/selected.json")))
        var checks=[[String:Any]]()
        for r in rows {
            let scores=exactScores.first{$0.id==r["id"] as! String}!
            try verifyShot(r,scores.bankComfort);try verifyShot(r["directProof"] as! [String:Any],scores.directProof.bankComfort)
            let opts=directOptions((r["cue"] as! [Double]).map(Float.init),(r["target"] as! [Double]).map(Float.init))
            let old=r["bestDirect"] as! [String:Any]
            guard opts.first!.pocket==old["pocket"] as! Int,abs(opts.first!.cut-(old["cut"] as! Double))<1e-10,abs(opts.first!.score-(old["score"] as! Double))<1e-10 else{throw NSError(domain:"direct-rank-drift",code:3)}
            checks.append(["id":r["id"]!,"bankReplay":true,"directReplay":true,"bestDirectRecomputed":true,"fullScoreExactReplay":true])
        };try json(checks,out+"/verification.json");print("VERIFIED \(checks.count) pairs");exit(0)
    }
    try variants(input:args[3],out:out)
} catch {fputs("ERROR \(error)\n",stderr);exit(1)}
