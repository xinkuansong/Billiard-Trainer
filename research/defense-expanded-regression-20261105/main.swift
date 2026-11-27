import Foundation
import SceneKit

struct Sample:Decodable {
 let id:String
 let source:DefenseBankQuestion
 let expected:DefenseBankQuestion.Reference.Expected
}
let output=URL(fileURLWithPath:CommandLine.arguments[1])
let samples=try JSONDecoder().decode([Sample].self,from:Data(contentsOf:output.appendingPathComponent("fixtures.json")))
func key(_ n:Int)->String { n==0 ? ShotInput.cueBallName:"_\(n)" }
func object<T:Encodable>(_ value:T)throws->Any {try JSONSerialization.jsonObject(with:JSONEncoder().encode(value))}
func write(_ value:Any,_ name:String)throws {
 try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent(name),options:.atomic)
}
var rows=[[String:Any]](),issues=[[String:String]]()
let start=ProcessInfo.processInfo.systemUptime
for (index,sample) in samples.enumerated() {
 let q=sample.source,e=sample.expected
 var p=ShotPrediction()
 // This adapter uses the bank's recorded completed solution; no simulator or solver is called.
 p.termination = .settled
 p.finalPositions=Dictionary(uniqueKeysWithValues:e.finalBalls.map {(key($0.number),SCNVector3(Float($0.position[0]),0,Float($0.position[1])))})
 p.pocketedBalls=e.pocketedBallNumbers.map(key)
 p.cuePocketed=e.pocketedBallNumbers.contains(0)
 p.events=try e.events.map { event in
  let kind:ShotEvent.Kind
  switch event.kind {
  case "ballBall": precondition(event.ballNumbers.count==2);kind = .ballBall(ballA:key(event.ballNumbers[0]),ballB:key(event.ballNumbers[1]))
  case "cushion": precondition(event.ballNumbers.count==1);kind = .ballCushion(ball:key(event.ballNumbers[0]))
  case "pocket": precondition(event.ballNumbers.count==1 && event.pocketIndex != nil);kind = .pocket(ball:key(event.ballNumbers[0]),pocketId:"pocket_\(event.pocketIndex!)")
  default: throw NSError(domain:"Unexpected bank event \(event.kind)",code:1)
  }
  return ShotEvent(time:Float(event.timeSeconds),kind:kind,cushionIndex:event.railIndex)
 }
 var row:[String:Any]=["id":sample.id,"kind":q.kind,"positions":p.finalPositions.mapValues{[Double($0.x),Double($0.z)]},"pocketed":p.pocketedBalls]
 do {
  let begin=ProcessInfo.processInfo.systemUptime
  let effect=try DefenseEffect.evaluate(question:q,prediction:p)
  row["cachedSeconds"]=ProcessInfo.processInfo.systemUptime-begin
  let exactStart=ProcessInfo.processInfo.systemUptime
  let exact=try DefenseEffect.evaluate(question:q,prediction:p,usePrecomputedWindows:false)
  row["exactSeconds"]=ProcessInfo.processInfo.systemUptime-exactStart
  row["effect"]=try object(effect);row["exact"]=try object(exact)
  func check(_ yes:Bool,_ message:String) {if !yes {issues.append(["id":sample.id,"issue":message])}}
  check(effect.score.map{$0.isFinite && (0...100).contains($0)}==true,"No finite score in 0...100")
  check(effect.unavailableReason==nil,"Unavailable result")
  check(effect.failure==nil,"Existing reference reported failure: \(effect.failure ?? "")")
  check(effect.failure==exact.failure && effect.fullDirectBlock==exact.fullDirectBlock && effect.potContactsBlocked==exact.potContactsBlocked,"Cache/exact classification differs")
  if let a=effect.score,let b=exact.score {row["scoreDelta"]=abs(a-b);check(abs(a-b)<0.05,"Cache/exact score differs by \(abs(a-b))")}
  if let route=effect.pipeRoute,let cue=p.finalPositions[ShotInput.cueBallName],let target=p.finalPositions[key(effect.opponentBallNumber)] {
   let comfort=ShotComfortScore.evaluate(cue:(Double(cue.x),Double(cue.z)),ball:(Double(target.x),Double(target.z)),aim:(route.aim[0],route.aim[1]))
   check(comfort.map{abs($0.total-route.comfort)<1e-10}==true,"Route comfort mismatch")
   check(abs(effect.score!-DefenseEffect.value(pipeDegrees:route.tolerance,comfort:route.comfort)!)<1e-10,"Formula mismatch")
  }
  // Export exact clean windows for an independently implemented dense closure audit.
  if effect.fullDirectBlock || effect.potContactsBlocked==true {
   var a=DefenseAttackAssessment()
   let target=p.finalPositions[key(effect.opponentBallNumber)]!
   row["windows"]=(0..<6).map{a.window(.init(Double(target.x),Double(target.z)),$0)}
  }
 } catch {row["error"]=String(describing:error);issues.append(["id":sample.id,"issue":String(describing:error)])}
 rows.append(row)
 if (index+1)%20==0 || index+1==samples.count {
  try write(rows,"cases.json");try write(issues,"issues.json")
  print("PROGRESS \(index+1)/\(samples.count), issues=\(issues.count), elapsed=\(Int(ProcessInfo.processInfo.systemUptime-start))s")
  fflush(stdout)
 }
}
let a=DefenseAttackAssessment()
try write(["radius":a.rad,"halfX":a.hx,"halfZ":a.hz,
 "rails":a.mainRails.map{[$0.0.json,$0.1.json]},
 "pockets":a.table.pockets.map{p -> [String:Any] in ["center":[Double(p.center.x),Double(p.center.z)],"radius":Double(p.radius),"lip":p.captureLip.map{[$0.x,$0.y]}]}],"geometry.json")
try write(["count":rows.count,"issues":issues,"passed":issues.isEmpty,"seconds":ProcessInfo.processInfo.systemUptime-start,"scoringVersion":DefenseEffect.version],"native-results.json")
precondition(DefensePipeTable.shared != nil)
if !issues.isEmpty {exit(2)}
