import Foundation
import SceneKit

let out=CommandLine.arguments[1]
let surface=BTTablePhysics.surfaceY, radius=BallPhysics.radius
let physicalTable=TableGeometry.chineseEightBallQiuJi(surfaceY:surface)
let cueKey=ShotInput.cueBallName
func point(_ p:SCNVector3)->[Double]{[Double(p.x),Double(p.z)]}
func vec(_ a:[Double])->SCNVector3{SCNVector3(Float(a[0]),surface+radius,Float(a[1]))}
func distance(_ a:SCNVector3,_ b:SCNVector3)->Double{hypot(Double(a.x-b.x),Double(a.z-b.z))}
func save(_ a:Any,_ name:String)throws{try JSONSerialization.data(withJSONObject:a,options:[.sortedKeys]).write(to:URL(fileURLWithPath:out+"/"+name),options:.atomic)}
struct DefenseBenchLayout {
 let row:[String:Any], id:String, kind:String, cue:SCNVector3, balls:[ObstacleBall], own:String, enemy:String
 init(_ q:[String:Any]) {
  row=q;id=q["sampleID"] as! String;kind=q["kind"] as! String;cue=vec(q["cue"] as! [Double])
  let numbers=q["numbers"] as! [Int],positions=q["positions"] as! [[Double]]
  balls=zip(numbers,positions).map{ObstacleBall(name:"_\($0.0)",position:vec($0.1))}
  own="_\(numbers[q["own"] as! Int])";enemy="_\(numbers[q["enemy"] as! Int])"
 }
 var initial:[String:SCNVector3]{var p=[cueKey:cue];for b in balls{p[b.name]=b.position};return p}
}
struct DefenseBenchStroke {
 let angle:Double,v:Double,sy:Double
 var direction:SCNVector3{SCNVector3(Float(cos(angle)),0,Float(sin(angle)))}
 var key:String{"\(angle)|\(v)|\(sy)"}
 var json:[String:Any]{["angle":angle,"direction":point(direction),"speed":v,"spinX":0,"spinY":sy]}
}
struct DefenseBenchResult {
 let s:DefenseBenchStroke,p:ShotPrediction,hybridAccepted:Bool,stage:String
}
func simulate(_ l:DefenseBenchLayout,_ s:DefenseBenchStroke,_ presentation:Bool=false)->ShotPrediction {
 ShotPredictor.simulateFree(cueBall:l.cue,aimDir:s.direction,velocity:Float(s.v),spinX:0,spinY:Float(s.sy),surfaceY:surface,balls:l.balls,maxEvents:1500,maxTime:60,includePresentation:presentation,recordedStrikeDirection:s.direction)
}
func invalid(_ p:ShotPrediction,_ l:DefenseBenchLayout)->String? {
 if !p.hasFinalTableState{return "incomplete"}
 if p.cuePocketed{return "scratch"}
 if p.pocketedBalls.contains("_8"){return "black-terminal"}
 if p.pocketedBalls.contains(l.own){return "own-pot-not-pure-safety"}
 guard let e=p.events.first(where:{if case .ballBall = $0.kind{return true};return false}),case let .ballBall(a,b)=e.kind,Set([a,b])==Set([cueKey,l.own]) else{return "wrong-first-hit"}
 guard p.events.contains(where:{ev in
  guard ev.time>e.time else{return false}
  if case .ballCushion = ev.kind{return true};if case .pocket = ev.kind{return true};return false
 }) else{return "no-post-contact-rail-or-pot"}
 if p.cueFinalSpeed>=0.01{return "cue-not-rested"}
 let active=([cueKey]+l.balls.map(\.name)).filter{!p.pocketedBalls.contains($0)}
 for (i,k) in active.enumerated(){
  guard let p1=p.finalPositions[k],p1.x.isFinite,p1.z.isFinite else{return "missing-final"}
  for other in active.dropFirst(i+1){guard let p2=p.finalPositions[other],distance(p1,p2)>=Double(2*radius)-0.00001 else{return "overlap"}}
 }
 return nil
}
func fastReason(_ f:AnalyticShotRollout.FreeShotOutcome,_ l:DefenseBenchLayout)->String? {
 if f.cuePocketed{return "scratch"}
 if !f.cueRested{return "incomplete"}
 if f.firstBallHit != l.own{return "wrong-first-hit"}
 if f.firstHitPocketed{return "own-pot-not-pure-safety"}
 if !f.railOrPocketAfterContact{return "no-post-contact-rail-or-pot"}
 return nil
}
func enemyKey(_ l:DefenseBenchLayout,_ p:ShotPrediction)->String{p.pocketedBalls.contains(l.enemy) ? "_8":l.enemy}
func railGap(_ p:SCNVector3)->Double {
 var best=Double.infinity
 for c in physicalTable.linearCushions.prefix(6){
  best=min(best,dist(P(point(p)),P([Double(c.start.x),Double(c.start.z)]),P([Double(c.end.x),Double(c.end.z)])))
 }
 return best-Double(radius)
}
// Conservative continuous angular union: only wholly nearer blockers contribute.
func blockage(_ c:SCNVector3,_ target:SCNVector3,_ blockers:[SCNVector3])->(Bool,Double) {
 let d=distance(c,target),r=Double(2*radius)
 if d<=r{return(false,0)}
 let h=asin(r/d),at=atan2(Double(target.z-c.z),Double(target.x-c.x))
 var intervals=[(Double,Double)]()
 for b in blockers {
  let db=distance(c,b);if db<=r || d-db-2*r<=0{continue}
  let a=atan2(Double(b.z-c.z),Double(b.x-c.x))-at
  let delta=atan2(sin(a),cos(a)),bh=asin(r/db)
  intervals.append((max(-h,delta-bh+1e-6),min(h,delta+bh-1e-6)))
 }
 intervals.sort{$0.0<$1.0};var end = -h,covered=0.0
 for (a,b) in intervals where b>a{if b>end{covered+=max(0,b-max(a,end));end=b}}
 let fraction=max(0,min(1,covered/(2*h)))
 return(fraction>=1-1e-12,fraction)
}
func measures(_ l:DefenseBenchLayout,_ p:ShotPrediction)->[String:Double] {
 measureState(l,p.finalPositions,p.pocketedBalls)
}
func measureState(_ l:DefenseBenchLayout,_ positions:[String:SCNVector3],_ pocketed:[String])->[String:Double] {
 let k=pocketed.contains(l.enemy) ? "_8":l.enemy,c=positions[cueKey]!,t=positions[k]!
 let bs=l.balls.filter{$0.name != k && !pocketed.contains($0.name)}.compactMap{positions[$0.name]}
 let b=blockage(c,t,bs)
 var cheap=0.0
 for pocket in physicalTable.pockets {
  if let s=ShotComfortScore.evaluate(cue:(Double(c.x),Double(c.z)),ball:(Double(t.x),Double(t.z)),aim:(Double(pocket.center.x),Double(pocket.center.z))){cheap=max(cheap,s.total)}
 }
 return ["coverageProof":b.1,"fullBlock":b.0 ? 1:0,"distance":distance(c,t),"cueRailGap":railGap(c),"enemyRailGap":railGap(t),"centerProbeComfort":cheap]
}
func rank(_ m:[String:Double],_ axis:Int)->Double {
 switch axis{case 0:return -(m["coverageProof"]!);case 1:return -(m["distance"]!);case 2:return m["cueRailGap"]!;case 3:return m["centerProbeComfort"]!;default:return m["enemyRailGap"]!}
}
func shortlist(_ records:[DefenseBenchResult],_ l:DefenseBenchLayout,_ count:Int)->[DefenseBenchResult] {
 let decorated=records.map{($0,measures(l,$0.p))};var seen=Set<String>(),result=[DefenseBenchResult]()
 for axis in 0..<5{
  let sorted=decorated.sorted{a,b in let x=rank(a.1,axis),y=rank(b.1,axis);return x==y ? a.0.s.key<b.0.s.key:x<y}
  for item in sorted.prefix(count) where seen.insert(item.0.s.key).inserted{result.append(item.0)}
 }
 return result
}
guard let model=TableModelLoader.loadTable(includeVisual:false),let cueNode=model.cueStickNode else{fatalError("Missing cue model")}
struct DefenseFastState {
 let s:DefenseBenchStroke,positions:[String:SCNVector3],pocketed:[String],stage:String
 let fallback:ShotPrediction?
}
let profile=CueStick(modelCueStickNode:cueNode).clearanceProfile
precondition(!profile.isEmpty)
func accessible(_ l:DefenseBenchLayout,_ s:DefenseBenchStroke)->Bool {
 let a=CueStrikeAccess(cue:l.cue,aim:s.direction,obstacles:l.balls.map(\.position),surfaceY:surface,profile:profile)
 return a.isAvailable(spinX:0,spinY:s.sy) && (a.resolvedPose(spinX:0,spinY:s.sy)?.elevation ?? 100)<=CueStick.minElevationRadians+0.000001
}
func eventJSON(_ p:ShotPrediction)->[[String:Any]]{
 p.events.map{e in var a:[String:Any]=["time":Double(e.time)]
 switch e.kind{case let .ballBall(a1,b):a["kind"]="ballBall";a["balls"]=[a1,b]
 case let .ballCushion(b):a["kind"]="cushion";a["ball"]=b;a["index"]=e.cushionIndex ?? -1
 case let .pocket(b,id):a["kind"]="pocket";a["ball"]=b;a["pocket"]=id};return a}
}
func cornerWitnesses(_ c:P,_ t:P,_ others:[P],_ a:[String:Any])->[Int]{
 let options=a["options"] as! [[String:Any]],selected=(a["best"] as! [String:Any])["pocket"] as! Int
 let sa=P([Double(table.pockets[selected].center.x),Double(table.pockets[selected].center.z)])
 let sd=(sa-t).length,sn=(sa-t)*(1/sd),sg=t-sn*(2*rad),scut=angleWidth(sg-c,sn)
 var found=[Int]()
 for i in 0..<4 where i != selected && (options[i]["cueWidth"] as! Double)==0 {
  let aim=P([Double(table.pockets[i].center.x),Double(table.pockets[i].center.z)]),d=(aim-t).length,n=(aim-t)*(1/d),g=t-n*(2*rad)
  if abs(g.x)>hx-rad || abs(g.z)>hz-rad{continue}
  if others.contains(where:{dist($0,c,g)<2*rad || dist($0,t,aim)<2*rad}){continue}
  if let s=ShotComfortScore.evaluate(cue:(c.x,c.z),ball:(t.x,t.z),aim:(aim.x,aim.z)),s.total>maxComfort(a),d<sd,angleWidth(g-c,n)<scut{found.append(i)}
 };return found
}
func finalRecord(_ l:DefenseBenchLayout,_ r:DefenseBenchResult)->[String:Any] {
 let p=simulate(l,r.s,true),k=enemyKey(l,p)
 precondition(invalid(p,l)==nil)
 let c=P(point(p.finalPositions[cueKey]!)),t=P(point(p.finalPositions[k]!))
 let others=l.balls.filter{$0.name != k && !p.pocketedBalls.contains($0.name)}.map{P(point(p.finalPositions[$0.name]!))}
 let a=attack(c,t,others,step:0.01),witness=cornerWitnesses(c,t,others,a),m=measures(l,p)
 var paths=[String:[[Double]]]();paths[cueKey]=p.cuePath.map{point($0)}
 for b in l.balls {paths[b.name]=(p.extraBallPaths[b.name] ?? []).map{point($0)}}
 return ["shot":r.s.json,"stage":r.stage,"hybridAccepted":r.hybridAccepted,"finalPositions":p.finalPositions.mapValues{point($0)},"pocketed":Array(p.pocketedBalls),"events":eventJSON(p),"paths":paths,"metrics":m,"opponentKey":k,"attack":a,"cornerWitnesses":witness,"ratingStatus":witness.isEmpty ? "model-scored":"quarantine-pocket-coverage","cueWidth":cueWidth(a),"comfort":maxComfort(a)]
}
let samples=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/samples.json"))) as! [[String:Any]]
precondition(samples.count==80)
precondition(abs(Double(radius)-0.028575)<1e-7 && abs(Double(TablePhysics.innerLength)-2.54)<1e-6)
var allSummary=[[String:Any]](),totalA=0.0,totalB=0.0,totalCandidates=0,totalSkipped=0,totalFallback=0,totalMissed=0,totalFull=0
let started=Date()
try FileManager.default.createDirectory(atPath:out+"/questions",withIntermediateDirectories:true)
for (index,row) in samples.enumerated(){try autoreleasepool{
 let l=DefenseBenchLayout(row),own=l.balls.first{$0.name==l.own}!.position
 let heading=atan2(Double(own.z-l.cue.z),Double(own.x-l.cue.x)),half=asin(Double(2*radius)/distance(l.cue,own))
 var fastStates=[DefenseFastState]()
 var results=[DefenseBenchResult](),ledger=[[String:Any]](),seen=Set<String>(),aTime=0.0,bTime=0.0,skipped=0,fallback=0,missed=0,accessRejected=0,maxFastError=0.0
 func pair(_ s:DefenseBenchStroke,_ stage:String){
  guard seen.insert(s.key).inserted else{return}
  guard accessible(l,s) else{accessRejected+=1;return}
  var base:ShotPrediction!,hybrid:ShotPrediction?,fast:AnalyticShotRollout.FreeShotOutcome!,reason:String?
  func runA(){let st=Date();base=simulate(l,s);aTime+=Date().timeIntervalSince(st)}
  func runB(){let st=Date();fast=AnalyticShotRollout.evaluateFreeShot(cueBall:l.cue,aimDir:s.direction,velocity:Float(s.v),spinX:0,spinY:Float(s.sy),surfaceY:surface,balls:l.balls,geometry:physicalTable,maxTime:60)
   reason=fastReason(fast,l)
   if fast.needsFullSim || reason != nil{fallback+=1;hybrid=simulate(l,s)}
   bTime+=Date().timeIntervalSince(st)
  }
  if ledger.count%2==0{runA();runB()}else{runB();runA()}
  let why=invalid(base,l)
  let okB = hybrid.map{invalid($0,l)==nil} ?? (reason==nil)
  if okB {
   if let h=hybrid {fastStates.append(DefenseFastState(s:s,positions:h.finalPositions,pocketed:h.pocketedBalls,stage:stage,fallback:h))}
   else {
    var positions=l.initial;positions[cueKey]=fast.cueFinalPos!;positions[l.own]=fast.firstHitFinalPos!
    fastStates.append(DefenseFastState(s:s,positions:positions,pocketed:[],stage:stage,fallback:nil))
   }
  }
  if why==nil && !okB{missed+=1}
  if !fast.needsFullSim,let fc=fast.cueFinalPos,let bc=base.finalPositions[cueKey],!base.cuePocketed{maxFastError=max(maxFastError,distance(fc,bc))}
  var line:[String:Any]=["shot":s.json,"stage":stage,"baselineReason":why ?? "legal","hybridLegal":okB,"fastFallback":fast.fallbackReason ?? "none","fastReason":reason ?? "pass","aOrderFirst":ledger.count%2==0]
  if why==nil{results.append(DefenseBenchResult(s:s,p:base,hybridAccepted:okB,stage:stage));line["metrics"]=measures(l,base)}
  ledger.append(line)
 }
 // Warm both paths before timing; cache-free simulation state per call.
 let warm=DefenseBenchStroke(angle:heading,v:1,sy:0);_=simulate(l,warm);_=AnalyticShotRollout.evaluateFreeShot(cueBall:l.cue,aimDir:warm.direction,velocity:1,spinX:0,spinY:0,surfaceY:surface,balls:l.balls,geometry:physicalTable,maxTime:60)
 for f in [-0.98,-0.9,-0.75,-0.5,-0.25,0,0.25,0.5,0.75,0.9,0.98]{for sy in [-0.2,0,0.2]{for v in [0.45,0.7,1,1.4,1.9,2.5,3.2]{pair(DefenseBenchStroke(angle:heading+half*f,v:v,sy:sy),"coarse")}}}
 let coarseCount=ledger.count,coarseLegal=results.count
 // Shared fixed refinement proposals isolate kernel acceleration from search-policy changes.
 let seeds=Array(shortlist(results,l,1).prefix(4))
 for (axis,seed) in seeds.enumerated(){
  var best=seed,lo=max(0.3,seed.s.v-0.3),hi=min(3.5,seed.s.v+0.3)
  let originalCushions=seed.p.events.compactMap{e->String? in if case let .ballCushion(b)=e.kind{return "\(b):\(e.cushionIndex ?? -1)"};return nil}
  for round in 0..<2{
   let startIndex=results.count
   for j in 0...8{pair(DefenseBenchStroke(angle:seed.s.angle,v:lo+(hi-lo)*Double(j)/8,sy:seed.s.sy),"refine-\(round)")}
   for r in results.dropFirst(startIndex){let route=r.p.events.compactMap{e->String? in if case let .ballCushion(b)=e.kind{return "\(b):\(e.cushionIndex ?? -1)"};return nil}
    if route==originalCushions && rank(measures(l,r.p),axis)<rank(measures(l,best.p),axis){best=r}
   }
   let span=(hi-lo)/8;lo=max(0.3,best.s.v-span);hi=min(3.5,best.s.v+span)
  }
 }
 let aShort=shortlist(results,l,3)
 let shortlistStart=Date()
 var confirmed=[String:ShotPrediction](),rejected=Set<String>(),bShort=[DefenseBenchResult](),bSeen=Set<String>(),verificationCalls=0
 for axis in 0..<5 {
  let sorted=fastStates.map{($0,measureState(l,$0.positions,$0.pocketed))}.sorted{a,b in
   let x=rank(a.1,axis),y=rank(b.1,axis);return x==y ? a.0.s.key<b.0.s.key:x<y
  }
  var accepted=0
  for (f,_) in sorted {
   if accepted>=3{break};if rejected.contains(f.s.key){continue}
   let p:ShotPrediction
   if let known=confirmed[f.s.key]{p=known}
   else if let known=f.fallback{p=known;confirmed[f.s.key]=p}
   else {p=simulate(l,f.s);verificationCalls+=1;if invalid(p,l) != nil{rejected.insert(f.s.key);continue};confirmed[f.s.key]=p}
   accepted+=1
   if bSeen.insert(f.s.key).inserted{bShort.append(DefenseBenchResult(s:f.s,p:p,hybridAccepted:true,stage:f.stage))}
  }
 }
 let shortlistSeconds=Date().timeIntervalSince(shortlistStart);bTime+=shortlistSeconds
 var chosen=[DefenseBenchResult](),unique=Set<String>();for r in aShort+bShort where unique.insert(r.s.key).inserted{chosen.append(r)}
 let scoreStart=Date();let references=chosen.map{finalRecord(l,$0)};let scoringSeconds=Date().timeIntervalSince(scoreStart)
 let report:[String:Any]=["sampleID":l.id,"kind":l.kind,"candidateCount":ledger.count,"coarseCount":coarseCount,"coarseLegal":coarseLegal,"legalBaseline":results.count,"legalHybrid":results.filter{$0.hybridAccepted}.count,"fastRejected":skipped,"fallback":fallback,"missedLegal":missed,"accessRejected":accessRejected,"baselineSeconds":aTime,"hybridSeconds":bTime,"scoringSeconds":scoringSeconds,"maxFastCueErrorMeters":maxFastError,"shortlistBaseline":aShort.map{$0.s.key},"shortlistHybrid":bShort.map{$0.s.key},"shortlistsEqual":Set(aShort.map{$0.s.key})==Set(bShort.map{$0.s.key}),"verificationCalls":verificationCalls,"verificationRejected":rejected.count,"shortlistSeconds":shortlistSeconds]
 try save(["input":row,"summary":report,"ledger":ledger,"references":references],"questions/\(l.id).json")
 allSummary.append(report);totalA+=aTime;totalB+=bTime;totalCandidates+=ledger.count;totalSkipped+=skipped;totalFallback+=fallback;totalMissed+=missed;totalFull+=results.count
 try save(["completed":allSummary.count,"total":80,"baselineSeconds":totalA,"hybridSeconds":totalB,"missedLegal":totalMissed,"elapsedSeconds":Date().timeIntervalSince(started)],"progress.json")
 print("PROGRESS \(index+1)/80 \(l.id) samples=\(ledger.count) legal=\(results.count) missed=\(missed) A=\(aTime) B=\(bTime) scoring=\(scoringSeconds)");fflush(stdout)
}}
try save(["complete":true,"layouts":80,"candidates":totalCandidates,"baselineSeconds":totalA,"hybridSeconds":totalB,"kernelSpeedup":totalA/max(1e-9,totalB),"fastRejected":totalSkipped,"fallback":totalFallback,"missedLegal":totalMissed,"legalBaseline":totalFull,"elapsedSeconds":Date().timeIntervalSince(started),"questions":allSummary,"scope":"Fast terminal-state shortlist then full verification, same candidate proposals including baseline-selected velocity refinement. Exact baseline shortlist identities may differ; final attack-quality and missing-baseline-best checks required. No independent search-policy or parallel scaling claim."],"summary.json")
print("DONE A=\(totalA) B=\(totalB) missed=\(totalMissed)")
