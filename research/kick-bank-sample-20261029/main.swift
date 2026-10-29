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
func simulate(_ s:Seed,_ target:[Float]?,aimDelta:Float=0,speedFactor:Float=1,spinDelta:Float=0)->ShotPrediction? {
    let theta=atan2(s.dir[1],s.dir[0])+aimDelta
    let d=aimDelta==0 ? SCNVector3(s.dir[0],0,s.dir[1]) : SCNVector3(cos(theta),0,sin(theta))
    let balls=target.map{[ObstacleBall(name:targetName,position:vec($0))]} ?? []
    let sx=s.sx+spinDelta
    let access=CueStrikeAccess(cue:vec(s.cue),aim:d,obstacles:balls.map(\.position),surfaceY:surface,profile:profile)
    guard access.isAvailable(spinX:Double(sx),spinY:Double(s.sy)),access.resolvedPose(spinX:Double(sx),spinY:Double(s.sy)) != nil else{return nil}
    return ShotPredictor.simulateFree(cueBall:vec(s.cue),aimDir:d,velocity:s.v*speedFactor,
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
func evaluate(_ p:ShotPrediction,_ n:Int,_ expected:[Int])->(String?,Int,[Int]) {
    guard p.hasFinalTableState,p.recorder != nil,p.finalPositions.values.allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite}) else{return("incomplete",-1,[])}
    guard let hit=p.events.firstIndex(where:{if case let .ballBall(a,b)=$0.kind{return Set([a,b])==Set([cueName,targetName])};return false}) else{return("no-target-contact",-1,[])}
    let ri=railEvents(p,before:hit),ids=ri.map{p.events[$0].cushionIndex ?? -1}
    guard ids.count==n,ids==expected else{return("earlier-contact-or-route-changed",hit,ids)}
    guard ri.allSatisfy({safeRail(p,$0)}) else{return("rail-pocket-buffer",hit,ids)}
    let a=angle(p,ri[0]);guard a>=20 && a<=(n==1 ? 75:65) else{return("actual-first-angle",hit,ids)}
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
do {
    let args=CommandLine.arguments
    if args[1]=="geometry" {
        try json(["radius":Double(radius),"length":Double(TablePhysics.innerLength),"width":Double(TablePhysics.innerWidth),
            "rails":geometry.linearCushions.prefix(6).enumerated().map{i,r in ["id":i,"start":point(r.start),"end":point(r.end),"normal":point(r.normal)] as [String:Any]},
            "pockets":geometry.pockets.map{["id":$0.id,"center":point($0.center),"radius":Double($0.radius),"lip":$0.captureLip.map{[Double($0.x),Double($0.y)]}] as [String:Any]}],args[2]);exit(0)
    }
    if args[1]=="verify" {
        let rows=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:args[2]))) as! [[String:Any]]
        var reports=[[String:Any]]()
        for row in rows { try autoreleasepool {
            let s=try JSONDecoder().decode(Seed.self,from:JSONSerialization.data(withJSONObject:row["seed"]!))
            let target=(row["target"] as! [Double]).map(Float.init),n=row["n"] as! Int,rails=row["rails"] as! [Int]
            guard let p=simulate(s,target),evaluate(p,n,rails).0==nil else{throw NSError(domain:"exact-replay",code:1)}
            // Compare ordered numeric event values exactly. JSON text can encode equal
            // numbers differently (for example integer-looking Double / signed zero).
            // No geometric/time tolerance is used here.
            let same=try eventProof(events(p))==eventProof(row["events"]!)
            guard same else{
                try json(["id":row["id"]!,"old":row["events"]!,"new":events(p),"seed":try plain(s)],args[3]+".drift.json")
                throw NSError(domain:"event-drift",code:2)
            }
            var probes=[[String:Any]]()
            for axis in ["aim","speed","spin"] {for sign:Float in [-1,1] {
                let pp=simulate(s,target,aimDelta:axis=="aim" ? sign*Float.pi/1800:0,speedFactor:axis=="speed" ? 1+sign*0.03:1,spinDelta:axis=="spin" ? sign*0.02:0)
                let reason=pp.map{evaluate($0,n,rails).0} ?? "inaccessible"
                probes.append(["axis":axis,"sign":Double(sign),"success":reason==nil,"reason":reason as Any? ?? NSNull()])
            }}
            reports.append(["id":row["id"]!,"exactReplay":same,"probes":probes])
        }}
        try json(reports,args[3]);print("VERIFIED \(reports.count) exact + \(reports.count*6) perturbations");exit(0)
    }
    let seeds=try JSONDecoder().decode([Seed].self,from:Data(contentsOf:URL(fileURLWithPath:args[2])))
    let out=args[3];var accepted=[[String:Any]](),contrasts=[[String:Any]](),trials=[[String:Any]](),bases=[[String:Any]]()
    var counts=[String:Int](),reject=[String:Int](),simCount=0
    func rejection(_ reason:String){reject[reason,default:0]+=1}
    for (si,s) in seeds.enumerated() { try autoreleasepool {
        let category=s.sx==0 ? "zero":(s.sx>0 ? "left":"right"),quota=s.sx==0 ? 12:6
        if (1...5).allSatisfy({counts["\($0)-\(category)",default:0]>=quota}) {return}
        guard let p=simulate(s,nil) else{rejection("baseline-inaccessible");return};simCount+=1
        guard p.hasFinalTableState,p.recorder != nil else{rejection("baseline-incomplete");return}
        let rs=railEvents(p),firstAngle=rs.isEmpty ? -1:angle(p,rs[0])
        bases.append(["id":s.id,"cell":s.cell,"v":Double(s.v),"sx":Double(s.sx),"rails":rs.map{p.events[$0].cushionIndex ?? -1},"firstAngle":firstAngle,"pocketed":p.pocketedBalls])
        guard !rs.isEmpty else{rejection("no-cushion");return}
        for n in 1...min(5,rs.count) {
            let key="\(n)-\(category)"
            if counts[key,default:0]>=quota{continue}
            guard firstAngle>=20 && firstAngle<=(n==1 ? 75:65) else{rejection("baseline-angle");continue}
            let prefix=Array(rs.prefix(n))
            guard prefix.allSatisfy({safeRail(p,$0)}) else{rejection("baseline-rail-pocket-buffer");continue}
            let t0=p.events[rs[n-1]].time,t1=n<rs.count ? p.events[rs[n]].time:p.duration
            let tr=trajectory(p,cueName,from:t0,to:t1)
            guard tr.count>=2 else{continue}
            var cumulative=[Double](repeating:0,count:tr.count)
            for i in 1..<tr.count{cumulative[i]=cumulative[i-1]+dist(Array(tr[i].suffix(2)),Array(tr[i-1].suffix(2)))}
            let length=cumulative.last!;guard length>0.22 else{rejection("segment-too-short");continue}
            let earlier=trajectory(p,cueName,to:t0)
            let expected=prefix.map{p.events[$0].cushionIndex!}
            for j in 0..<3 {
                if counts[key,default:0]>=quota{break}
                let sample=s.samples[(n-1)*3+j], fraction=(Double(j)+Double(sample[0]))/3
                let arc=0.09+fraction*(length-0.18)
                guard let k=(1..<tr.count).first(where:{cumulative[$0]>=arc}) else{continue}
                let a=tr[k-1],b=tr[k],ll=cumulative[k]-cumulative[k-1];guard ll>1e-9 else{continue}
                let u=(arc-cumulative[k-1])/ll, dx=(b[1]-a[1])/ll,dz=(b[2]-a[2])/ll,off=Double(sample[1])*Double(radius)
                let center=[a[1]+u*(b[1]-a[1]),a[2]+u*(b[2]-a[2])]
                let target=[center[0]-off*dz,center[1]+off*dx]
                var row:[String:Any]=["id":"\(s.id)-N\(n)-P\(j)","seed":try plain(s),"target":target,"n":n,"rails":expected,"category":category,"offsetR":Double(sample[1]),"segmentFraction":fraction,"segmentLength":length,"baselineFirstAngle":firstAngle,"baselineSegment":tr,"placementCenter":center]
                var reason:String?
                if !legal(target){reason="illegal-target-position"}
                else if dist(target,s.cue.map(Double.init))<=2*Double(radius){reason="initial-overlap"}
                else if zip(earlier,earlier.dropFirst()).contains(where:{segdist(target,Array($0.0.suffix(2)),Array($0.1.suffix(2)))<=2*Double(radius)+0.001}){reason="earlier-path-overlap"}
                if let reason {rejection(reason);trials.append(["id":row["id"]!,"reason":reason]);continue}
                guard let actual=simulate(s,target.map(Float.init)) else{rejection("target-inaccessible");continue};simCount+=1
                let outcome=evaluate(actual,n,expected);reason=outcome.0
                row["success"]=reason==nil;row["reason"]=reason as Any? ?? NSNull()
                row["actualRails"]=outcome.2
                trials.append(["id":row["id"]!,"reason":reason as Any? ?? NSNull(),"n":n,"category":category])
                if reason==nil {
                    row.merge(details(actual,outcome.1),uniquingKeysWith:{$1});accepted.append(row);counts[key,default:0]+=1
                } else {
                    rejection(reason!)
                    if contrasts.count<10 && !contrasts.contains(where:{$0["reason"] as? String==reason && $0["n"] as? Int==n}) {
                        row.merge(details(actual,outcome.1),uniquingKeysWith:{$1});contrasts.append(row)
                    }
                }
            }
        }
    }
        if si%100==0 {
            try json(accepted,out+"/accepted.json");try json(bases,out+"/baselines.json")
            print("SEED \(si)/\(seeds.count) sims=\(simCount) accepted=\(accepted.count) \(counts)");fflush(stdout)
        }
        if (1...5).allSatisfy({n in ["zero","left","right"].allSatisfy{counts["\(n)-\($0)",default:0]>=($0=="zero" ? 12:6)}}){break}
    }
    try json(accepted,out+"/accepted.json");try json(contrasts,out+"/contrasts.json");try json(trials,out+"/trials.json");try json(bases,out+"/baselines.json")
    try json(["accepted":accepted.count,"counts":counts,"rejections":reject,"simulations":simCount,"baselineSimulations":bases.count,"proposedSeeds":seeds.count],out+"/generation-summary.json")
    print("GENERATED \(accepted.count) \(counts)")
}catch{fputs("ERROR \(error)\n",stderr);exit(1)}
