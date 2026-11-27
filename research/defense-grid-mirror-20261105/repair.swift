import Foundation
import SceneKit
let out=URL(fileURLWithPath:CommandLine.arguments[1])
func read(_ n:String)throws->Data {try Data(contentsOf:out.appendingPathComponent(n))}
func write(_ n:String,_ x:Any)throws {try JSONSerialization.data(withJSONObject:x,options:[.sortedKeys]).write(to:out.appendingPathComponent(n),options:.atomic)}
let all=try JSONDecoder().decode([DefenseBankQuestion].self,from:read("trajectory-candidate.json"))
let diagnostics=try JSONSerialization.jsonObject(with:read("replay-results.json")) as! [String:Any]
let failures=diagnostics["failures"] as! [[String:Any]],ids=Set(failures.map{$0["referenceID"] as! String})
func num(_ k:String)->Int {k==ShotInput.cueBallName ? 0:Int(k.dropFirst())!}
func simulate(_ q:DefenseBankQuestion,_ r:DefenseBankQuestion.Reference,_ delta:Double=0,_ scale:Double=1)->ShotPrediction {
 let surface:Float=0.8,s=r.parameters
 func v(_ a:[Double])->SCNVector3 {.init(Float(a[0]),surface+BallPhysics.radius,Float(a[1]))}
 let angle=atan2(s.direction[1],s.direction[0])+delta*Double.pi/180
 let d=delta==0 ? SCNVector3(Float(s.direction[0]),0,Float(s.direction[1])):SCNVector3(Float(cos(angle)),0,Float(sin(angle)))
 return ShotPredictor.simulateFree(cueBall:v(q.cue),aimDir:d,velocity:Float(s.velocity*scale),spinX:Float(s.spinX),spinY:Float(s.spinY),surfaceY:surface,balls:q.balls.map{.init(name:"_\($0.number)",position:v($0.position))},maxEvents:1500,maxTime:60,includePresentation:false,simulationModel:.appDefault,recordedStrikeDirection:d)
}
func routeAllowed(_ q:DefenseBankQuestion,_ p:ShotPrediction)->Bool {
 guard p.hasFinalTableState,DefenseEffect.failure(q,p)==nil else{return false}
 var hit=false,bounced=false;var rails=[Int:Int]()
 for e in p.events {
  switch e.kind {
  case let .ballBall(a,b):if Set([num(a),num(b)])==Set([0,q.ownBallNumber]) {if hit && bounced {return false};hit=true}
  case let .ballCushion(b):
   if !hit {return false}
   if let i=e.cushionIndex,(0..<6).contains(i) {rails[num(b),default:0]+=1;if num(b)==q.ownBallNumber{bounced=true}}
  default:break
  }
 }
 return rails.values.allSatisfy{$0<=1} && rails.values.reduce(0,+)<=2
}
func events(_ p:ShotPrediction)->[[String:Any]] {p.events.map{e in
 var row:[String:Any]=["timeSeconds":Double(e.time)]
 switch e.kind {
 case let .ballBall(a,b):row["kind"]="ballBall";row["ballNumbers"]=[num(a),num(b)]
 case let .ballCushion(a):row["kind"]="cushion";row["ballNumbers"]=[num(a)];if let i=e.cushionIndex{row["railIndex"]=i}
 case let .pocket(a,b):row["kind"]="pocket";row["ballNumbers"]=[num(a)];row["pocketIndex"]=Int(b.replacingOccurrences(of:"pocket_",with:""))!
 };return row
}}
var repairs=[[String:Any]](),rejected=[[String:Any]]()
for q in all {
 for r in q.references where ids.contains(r.id) {
  let p=simulate(q,r)
  let effect=try DefenseEffect.evaluate(question:q,prediction:p)
  let qualifies=routeAllowed(q,p) && effect.score != nil && DefenseQuestionPreparer.referenceGeometryQualifies(effect:effect,source:q,prediction:p)
  if !qualifies {rejected.append(["questionID":q.id,"referenceID":r.id,"score":effect.score as Any? ?? NSNull(),"failure":effect.failure as Any? ?? NSNull()]);continue}
  let expected:[String:Any]=["events":events(p),"finalBalls":p.finalPositions.keys.sorted().map{k in ["number":num(k),"position":[Double(p.finalPositions[k]!.x),Double(p.finalPositions[k]!.z)]]},"pocketedBallNumbers":p.pocketedBalls.map(num).sorted()]
  let decoded=try JSONDecoder().decode(DefenseBankQuestion.Reference.Expected.self,from:JSONSerialization.data(withJSONObject:expected))
  let check=simulate(q,r)
  precondition(DefenseQuestionPreparer.eventsMatch(check,decoded.events) && check.hasFinalTableState)
  for b in decoded.finalBalls where !decoded.pocketedBallNumbers.contains(b.number) {let v=check.finalPositions[b.number==0 ? ShotInput.cueBallName:"_\(b.number)"]!;precondition(hypot(Double(v.x)-b.position[0],Double(v.z)-b.position[1])<=0.002)}
  let opponent=effect.opponentBallNumber
  typealias P=DefenseAttackAssessment.P
  func point(_ v:SCNVector3)->P {.init(Double(v.x),Double(v.z))}
  let c=point(p.finalPositions[ShotInput.cueBallName]!),target=point(p.finalPositions["_\(opponent)"]!)
  let others=q.keys.filter{$0 != "_\(opponent)" && !p.pocketedBalls.contains($0)}.map{point(p.finalPositions[$0]!)}
  var assessment=DefenseAttackAssessment();let a=assessment.attack(c,target,others,step:0.01)
  let isBlock=DefenseEffect.fullyBlocked(p.finalPositions[ShotInput.cueBallName]!,p.finalPositions["_\(opponent)"]!,q.keys.filter{$0 != "_\(opponent)" && !p.pocketedBalls.contains($0)}.map{p.finalPositions[$0]!})
  var rails=[String:Int]();for e in p.events {if case let .ballCushion(b)=e.kind,let i=e.cushionIndex,(0..<6).contains(i){rails[String(num(b)),default:0]+=1}}
  var travel=0.0
  for (k,frames) in p.recorder!.framesByBallName {
   let end=p.events.first{if case let .pocket(ball,_) = $0.kind{return ball==k};return false}?.time ?? .infinity
   let f=frames.filter{$0.time<=end};for (a,b) in zip(f,f.dropFirst()){travel+=hypot(Double(a.position.x-b.position.x),Double(a.position.z-b.position.z))}
  }
  var probes=[[String:Any]]()
  for (da,scale) in [(-0.1,1.0),(0.1,1.0),(0.0,0.95),(0.0,1.05)] {
   let pp=simulate(q,r,da,scale);var okay=false
   if routeAllowed(q,pp) {let e=try DefenseEffect.evaluate(question:q,prediction:pp);okay=e.score != nil && DefenseQuestionPreparer.referenceGeometryQualifies(effect:e,source:q,prediction:pp)}
   probes.append(["angleDeltaDegrees":da,"speedScale":scale,"status":okay ? "qualified":"not-qualified","qualifies":okay,"tactics":[]])
  }
  repairs.append(["questionID":q.id,"referenceID":r.id,"expected":expected,"effect":["fullDirectBlock":isBlock,"score":isBlock ? 100 as Any:NSNull(),"opponentBallNumber":opponent,"cueToleranceDegrees":isBlock ? 0:assessment.cueWidth(a),"comfort":isBlock ? 0:assessment.maxComfort(a)],"mainCushionsByBall":rails,"totalTravelMeters":travel,"probes":probes])
  print("REPAIRED \(repairs.count)/\(ids.count) \(q.sampleID)");fflush(stdout)
 }
}
try write("repair-results.json",["passed":rejected.isEmpty,"repairs":repairs,"rejected":rejected,"tested":ids.count])
print("REPAIR COMPLETE \(repairs.count), rejected \(rejected.count)")
