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
struct Candidate {
    let target:[Float];let cue:[Float];let pocket:Int;let wall:Int;let cut:Float;let distance:Float
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
do {
    let args=CommandLine.arguments,out=args[2]
    try comfortSanity()
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
    var rng=RNG(x:2026110147),buckets=[String:[Candidate]](),stats=[String:Int]()
    let halfX=Double(TablePhysics.innerLength/2-radius),halfZ=Double(TablePhysics.innerWidth/2-radius)
    // Seed from one corner and one middle pocket. Split surviving physical rail intervals,
    // then jitter each region. Reflections are on ball-centre contact lines.
    for pk in [4,0] {
        let p=geometry.pockets[pk].center
        let walls=pk==4 ? [0,1,3]:[1,3]
        for w in walls {
            let rr=geometry.linearCushions.prefix(6).enumerated().filter{wall($0.offset)==w}
            let lengths=rr.map{max(0,dist(point($0.element.start),point($0.element.end))-0.08)}
            let total=lengths.reduce(0,+),count=w<2 ? 24:48
            for region in 0..<count {
                var offset=(Double(region)+Double(rng.uniform()))/Double(count)*total
                var chosen=rr[0].element
                for (i,item) in rr.enumerated(){if offset<=lengths[i]{chosen=item.element;break};offset-=lengths[i]}
                let a=point(chosen.start),b=point(chosen.end),len=dist(a,b),u=(0.04+offset)/len
                var q=[a[0]+u*(b[0]-a[0]),a[1]+u*(b[1]-a[1])]
                q[0]+=Double(chosen.normal.x*radius);q[1]+=Double(chosen.normal.z*radius)
                let aim=AngleSceneCalculator.effectivePocketAimPoint(targetBall:vec(q.map(Float.init)),pocketIndex:pk,surfaceY:surface)
                var dx=q[0]-Double(aim.x),dz=q[1]-Double(aim.z);let length=hypot(dx,dz);dx/=length;dz/=length
                if w<2{dx = -dx}else{dz = -dz}
                var limits=[Double]()
                if abs(dx)>1e-10{limits.append(((dx>0 ? halfX : -halfX)-q[0])/dx)}
                if abs(dz)>1e-10{limits.append(((dz>0 ? halfZ : -halfZ)-q[1])/dz)}
                guard let maxT=limits.filter({$0>1e-6}).min(),maxT>0.04 else{continue}
                for f in [0.005,0.015,0.035,0.065,0.10,0.16,0.24,0.34,0.46,0.60,0.76,0.91,0.98] {
                    let t=f*maxT
                    let o=[Float(q[0]+t*dx),Float(q[1]+t*dz)]
                    guard legal(o.map(Double.init)) else{continue}
                    let near=nearestRail(o.map(Double.init))
                    guard near.2>=0 else{continue} // Physical legality only; no location quota.
                    let theta=atan2(-dz,-dx),ghost=[Double(o[0])-2*Double(radius)*cos(theta),Double(o[1])-2*Double(radius)*sin(theta)]
                    let gap=near.2
                    for cut in [-35.0,-25,-15,-5,0,5,15,25,35] {
                        for distance in [0.35,0.50,0.65,0.80,0.95,1.10,1.25,1.40,1.55,1.70,1.85,2.00,2.20] {
                            let ang=theta+cut*Double.pi/180,c=[Float(ghost[0]-distance*cos(ang)),Float(ghost[1]-distance*sin(ang))]
                            guard legal(c.map(Double.init)),dist(c.map(Double.init),o.map(Double.init))>Double(2*radius) else{continue}
                            let routeLength=dist(o.map(Double.init),q)+dist(q,point(aim))
                            guard let comfort=bankComfort(c.map(Double.init),o.map(Double.init),[-dx,-dz],[cos(ang),sin(ang)],routeLength),eligibleComfort(comfort) else{stats["comfortRejected",default:0]+=1;continue}
                            let options=directOptions(c,o);guard let best=options.first else{stats["noDirect",default:0]+=1;continue}
                            guard best.cut>=45 else{continue}
                            let scoreBin=category(best.cut),distanceBin=comfort["cueTargetDistance"]!<1.0 ? 0:1
                            let key="\(pk==4 ? "M":"C")-\(scoreBin)-\(distanceBin)"
                            // Sampling coverage, not a comfort penalty for long shots.
                            let representative=distanceBin==0 ? [0.55,0.70,0.85][scoreBin]:[1.25,1.55,1.85][scoreBin]
                            let rank=10*abs(comfort["cueTargetDistance"]!-representative)+0.1*abs(cut)+0.05*abs(best.cut-Double(50+scoreBin*10))+0.05*(100-comfort["space"]!)
                            let candidate=Candidate(target:o,cue:c,pocket:pk,wall:w,cut:Float(cut),distance:Float(distance),options:options,boundaryPoint:q,fraction:f,region:region,gap:gap,key:key,rank:rank,comfort:comfort)
                            buckets[key,default:[]].append(candidate)
                        }
                    }
                }
            }
        }
    }
    for k in buckets.keys {buckets[k]!.sort{$0.rank<$1.rank}}
    try json(buckets.mapValues{items in ["count":items.count,"maxGap":items.map{$0.gap}.max() ?? 0,"outsideOldZone":items.filter{ let q=nearestRail($0.target.map(Double.init));return q.1<0.25 || q.1>0.75 || q.2>0.1 }.count] as [String:Any]},out+"/candidate-coverage.json")
    try json(buckets.mapValues{$0.count},out+"/candidate-counts.json")
    print("CANDIDATES \(buckets.mapValues{$0.count})");fflush(stdout)
    var rows=[[String:Any]](),attempts=0
    for typ in ["M","C"] {for score in 0..<3 {for depth in 0..<2 {
        let key="\(typ)-\(score)-\(depth)";var found=false
        // Stratified distances with angle/space preference; full total is informational.
        let ordered=(buckets[key] ?? []).sorted {
            if abs($0.rank-$1.rank)>1e-8 {return $0.rank<$1.rank}
            let old=rows.filter{($0["type"] as! String)==(typ=="M" ? "middle":"corner")}
            func diversity(_ c:Candidate)->Double {old.map{dist($0["canonicalTarget"] as! [Double],c.target.map(Double.init))}.min() ?? c.gap}
            return diversity($0)>diversity($1)
        }
        for c in ordered.prefix(500) {
            if rows.contains(where:{ ($0["type"] as! String)==(typ=="M" ? "middle":"corner") && dist($0["canonicalTarget"] as! [Double],c.target.map(Double.init))<0.08 }) {continue}
            attempts+=1
            let transform=(score*2+depth+(typ=="M" ? 0:2))%4
            let cue=mapped(c.cue,transform),target=mapped(c.target,transform),pocket=mapPocket(c.pocket,transform),w=mapWall(c.wall,transform)
            let opts=directOptions(cue,target);guard let best=opts.first else{continue}
            guard best.cut>=45,category(best.cut)==score else{continue}
            let pair:([String:Any]?,[String:Any]?)=autoreleasepool {
                guard let bank=solved(cue,target,pocket,[w],[1.5,2.0,2.5,3.2,4.0,4.8]) else{return(nil,nil)}
                guard let direct=solved(cue,target,best.pocket,[],[1.5,2.0,2.5,3.2,4.0]) else{return(nil,nil)}
                guard category(direct["actualCutAngle"] as! Double)==score,(direct["actualCutAngle"] as! Double)>=45 else{return(nil,nil)}
                return(bank,direct)
            }
            if var r=pair.0,let direct=pair.1 {
                let id="\(typ)-\(45+score*10)-\(depth+1)"
                r.merge(["id":id,"type":typ=="M" ? "middle":"corner","bestDirect":best.data,"directOptions":opts.map{$0.data},"directProof":direct,"angleBand":score,"sampleIndex":depth,"distanceBand":depth,"seedComfort":c.comfort,"directComfortOptions":directComfortOptions(cue,target),"cueRailGap":nearestRail(cue.map(Double.init)).2,"nearRail":nearestRail(target.map(Double.init)).0,"railFraction":nearestRail(target.map(Double.init)).1,"railGap":c.gap,"canonicalTarget":c.target.map(Double.init),"canonicalCue":c.cue.map(Double.init),"canonicalPocket":c.pocket,"canonicalWall":c.wall,"seedRailPoint":c.boundaryPoint,"seedRegion":c.region,"seedFraction":c.fraction,"generationCut":Double(c.cut),"generationDistance":Double(c.distance),"transform":transform]){_,b in b}
                rows.append(r);try json(rows,out+"/selected.json")
                print("ACCEPT \(id) directCut=\(best.cut) gap=\(c.gap) comfort=\(r["bankComfort"]!) attempts=\(attempts)");fflush(stdout);found=true;break
            }
            if attempts%20==0{print("SEARCH \(key) trials=\(attempts)");fflush(stdout)}
        }
        if !found {print("UNFILLED \(key) sample=\(depth)");fflush(stdout)}
    }}}
    try json(["selected":rows.count,"attemptedPairs":attempts,"screening":stats,"seed":2026110147],out+"/generation-summary.json")
    guard rows.count==12 else{throw NSError(domain:"unfilled-12-pair-quota",code:rows.count)}
    print("GENERATED 12 pairs")
} catch {fputs("ERROR \(error)\n",stderr);exit(1)}
