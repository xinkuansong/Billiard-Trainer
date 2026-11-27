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
func assess(_ l:DefenseBenchLayout,_ p:ShotPrediction)->[String:Any] {
 let k=enemyKey(l,p),c=P(point(p.finalPositions[cueKey]!)),t=P(point(p.finalPositions[k]!))
 let others=l.balls.filter{$0.name != k && !p.pocketedBalls.contains($0.name)}.map{P(point(p.finalPositions[$0.name]!))}
 let a=attack(c,t,others,step:0.01),w=cornerWitnesses(c,t,others,a),m=measures(l,p)
 return ["cueWidth":cueWidth(a),"comfort":maxComfort(a),"metrics":m,"cornerWitnesses":w]
}
func defensePreviewQualifies(_ a:[String:Any])->Bool {
 let m=a["metrics"] as! [String:Double]
 return (a["cornerWitnesses"] as! [Int]).isEmpty && (m["fullBlock"]==1 || ((a["cueWidth"] as! Double)>1e-6 && (a["cueWidth"] as! Double)<=0.008 && (a["comfort"] as! Double)<10))
}
let tactics=["block","distance","cue-rail","target-rail","angle","remove-threat","pot-opponent"]
func pocketDistance(_ p:SCNVector3)->Double{physicalTable.pockets.map{distance(p,$0.center)}.min()!}
func matches(_ t:String,_ l:DefenseBenchLayout,_ r:DefenseBenchResult,_ a:[String:Any])->Bool {
 guard defensePreviewQualifies(a) else{return false}
 let m=a["metrics"] as! [String:Double]
 switch t {
 case "block":return m["fullBlock"]==1
 case "distance":return m["distance"]!>=1.27
 case "cue-rail":return m["cueRailGap"]!<=Double(radius)
 case "target-rail":return m["enemyRailGap"]!<=Double(radius)
 case "angle":return m["fullBlock"]==0
 case "pot-opponent":return l.enemy != "_8" && r.p.pocketedBalls.contains(l.enemy)
 default:
  guard !r.p.pocketedBalls.contains(l.enemy),let before=l.initial[l.enemy],let after=r.p.finalPositions[l.enemy] else{return false}
  return pocketDistance(before)<0.3 && pocketDistance(after)>pocketDistance(before)+0.2
 }
}
func orderValue(_ tactic:String,_ a:[String:Any])->Double {
 let m=a["metrics"] as! [String:Double]
 switch tactic {case "distance":return -m["distance"]!;case "cue-rail":return m["cueRailGap"]!;case "target-rail":return m["enemyRailGap"]!;default:return max((a["cueWidth"] as! Double)/0.008,(a["comfort"] as! Double)/10)}
}
let samples=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/samples.json"))) as! [[String:Any]]
precondition(samples.count==20)
precondition(abs(Double(radius)-0.028575)<1e-7 && abs(Double(TablePhysics.innerLength)-2.54)<1e-6)
try FileManager.default.createDirectory(atPath:out+"/questions",withIntermediateDirectories:true)
var reports=[[String:Any]]();let started=Date()
for (index,row) in samples.enumerated(){try autoreleasepool {
 cache.removeAll(keepingCapacity:true)
 let l=DefenseBenchLayout(row),own=l.initial[l.own]!,heading=atan2(Double(own.z-l.cue.z),Double(own.x-l.cue.x)),half=asin(Double(2*radius)/distance(l.cue,own))
 var results=[DefenseBenchResult](),scores=[[String:Any]](),ledger=[[String:Any]](),seen=Set<String>(),accessRejected=0
 let begin=Date()
 func test(_ s:DefenseBenchStroke,_ stage:String) {
  guard seen.insert(s.key).inserted else{return}
  guard accessible(l,s) else{accessRejected+=1;return}
  let p=simulate(l,s),reason=invalid(p,l)
  var entry:[String:Any]=["shot":s.json,"stage":stage,"reason":reason ?? "legal"]
  if reason==nil {
   let a=assess(l,p);entry["assessment"]=a
   results.append(DefenseBenchResult(s:s,p:p,hybridAccepted:true,stage:stage));scores.append(a)
  }
  ledger.append(entry)
 }
 for j in 0...20 {for sy in [-0.2,0,0.2] {for v in [0.3,0.45,0.7,1,1.4,1.9,2.5,3.2,3.8] {
  test(DefenseBenchStroke(angle:heading+half*(-0.99+1.98*Double(j)/20),v:v,sy:sy),"coarse")
 }}}
 // Refine several geometric strategies and the actual two-indicator candidate.
 var seeds=shortlist(results,l,1)
 if let best=scores.indices.filter({(scores[$0]["cornerWitnesses"] as! [Int]).isEmpty && (scores[$0]["cueWidth"] as! Double)>1e-6}).min(by:{orderValue("angle",scores[$0])<orderValue("angle",scores[$1])}) {seeds.append(results[best])}
 for seed in seeds {
  for dv in [-0.1,0,0.1] {for da in [-0.015,0,0.015] {
   test(DefenseBenchStroke(angle:seed.s.angle+half*da,v:max(0.2,seed.s.v+dv),sy:seed.s.sy),"local-refine")
  }}
 }
 var retained=[Int](),tags=[Int:[String]](),coverage=[[String:Any]](),probeCache=[Int:[[String:Any]]]()
 func probe(_ i:Int)->[[String:Any]] {
  if let known=probeCache[i]{return known}
  var probes=[[String:Any]]()
  for (da,dv) in [(-0.1,1.0),(0.1,1.0),(0.0,0.95),(0.0,1.05)] {
   let s=DefenseBenchStroke(angle:results[i].s.angle+da*Double.pi/180,v:results[i].s.v*dv,sy:results[i].s.sy)
   if !accessible(l,s){probes.append(["angleDeltaDegrees":da,"speedScale":dv,"status":"inaccessible"]);continue}
   let p=simulate(l,s)
   if let why=invalid(p,l){probes.append(["angleDeltaDegrees":da,"speedScale":dv,"status":why]);continue}
   let a=assess(l,p),r=DefenseBenchResult(s:s,p:p,hybridAccepted:true,stage:"probe")
   probes.append(["angleDeltaDegrees":da,"speedScale":dv,"status":"legal","qualifies":defensePreviewQualifies(a),"assessment":a,"tactics":tactics.filter{matches($0,l,r,a)}])
  }
  probeCache[i]=probes;return probes
 }
 for t in tactics {
  let candidates=scores.indices.filter{matches(t,l,results[$0],scores[$0])}.sorted{
   let x=orderValue(t,scores[$0]),y=orderValue(t,scores[$1]);return x==y ? results[$0].s.key<results[$1].s.key:x<y
  }
  // Compare multiple candidates before choosing a teaching reference. Keep both
  // the geometric leaders and evenly spaced alternatives from the eligible set.
  var options=Array(candidates.prefix(12))
  if !candidates.isEmpty{for j in 0..<12{let i=candidates[(candidates.count-1)*j/11];if !options.contains(i){options.append(i)}}}
  func preserved(_ i:Int)->Int{probe(i).filter{($0["tactics"] as? [String] ?? []).contains(t)}.count}
  func effective(_ i:Int)->Int{probe(i).filter{($0["qualifies"] as? Bool)==true}.count}
  let ranked=options.sorted{a,b in
   let pa=preserved(a),pb=preserved(b);if pa != pb{return pa>pb}
   let ea=effective(a),eb=effective(b);if ea != eb{return ea>eb}
   let va=orderValue(t,scores[a]),vb=orderValue(t,scores[b]);return va==vb ? results[a].s.key<results[b].s.key:va<vb
  }
  if let best=ranked.first {
   if tags[best]==nil{retained.append(best);tags[best]=[]};tags[best]!.append(t)
  }
  let applicable = t=="block" ? l.balls.count>1 : t=="pot-opponent" ? l.enemy != "_8" : t=="remove-threat" ? pocketDistance(l.initial[l.enemy]!)<0.3 : true
  coverage.append(["tactic":t,"status":!applicable ? "not-applicable":candidates.isEmpty ? "not-found":"found","candidateCount":candidates.count])
 }
 var references=[[String:Any]]()
 for i in retained {
  var r=finalRecord(l,results[i]);precondition(defensePreviewQualifies(r))
  precondition(abs((r["cueWidth"] as! Double)-(scores[i]["cueWidth"] as! Double))<1e-8)
  r["tactics"]=tags[i]!
  let probes=probe(i)
  r["perturbations"]=probes;references.append(r)
 }
 let report:[String:Any]=["sampleID":l.id,"kind":l.kind,"candidateCount":ledger.count,"legalCount":results.count,"accessRejected":accessRejected,"qualifiedCount":scores.filter{defensePreviewQualifies($0)}.count,"referenceCount":references.count,"coverage":coverage,"seconds":Date().timeIntervalSince(begin)]
 let probeLedger=probeCache.keys.sorted().map{i in ["shot":results[i].s.json,"probes":probeCache[i]!] as [String:Any]}
 try save(["input":row,"summary":report,"references":references,"ledger":ledger,"probeLedger":probeLedger],"questions/\(l.id).json")
 reports.append(report)
 try save(["completed":index+1,"total":samples.count,"elapsedSeconds":Date().timeIntervalSince(started)],"progress.json")
 print("PROGRESS \(index+1)/20 \(l.id) candidates=\(ledger.count) legal=\(results.count) references=\(references.count)");fflush(stdout)
}}
try save(["complete":true,"layouts":samples.count,"questions":reports,"elapsedSeconds":Date().timeIntervalSince(started),"scope":"Full simulation and six-pocket assessment for all legal tested candidates; finite direct-hit search, no side spin; conservative preview threshold, four perturbation probes not success probability."],"summary.json")
