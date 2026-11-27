import Foundation
import SceneKit

struct Stroke:Decodable { let direction:[Double];let speed,spinX,spinY:Float }
struct Sample:Decodable { let source:DefenseBankQuestion;let shot:Stroke }
let output=URL(fileURLWithPath:CommandLine.arguments[1])
let samples=try JSONDecoder().decode([Sample].self,from:Data(contentsOf:output.appendingPathComponent("fixtures.json")))
var rows=[[String:Any]]()
for sample in samples {
 let q=sample.source,s=sample.shot,surface:Float=0.8
 func v(_ a:[Double])->SCNVector3 { .init(Float(a[0]),surface+BallPhysics.radius,Float(a[1])) }
 let direction=SCNVector3(Float(s.direction[0]),0,Float(s.direction[1]))
 let p=ShotPredictor.simulateFree(cueBall:v(q.cue),aimDir:direction,velocity:s.speed,spinX:s.spinX,spinY:s.spinY,
  surfaceY:surface,balls:q.balls.map{.init(name:"_\($0.number)",position:v($0.position))},maxEvents:1500,maxTime:60,
  includePresentation:false,simulationModel:.appDefault,recordedStrikeDirection:direction)
 var durations=[Double]();var last:DefenseEffect?
 for _ in 0..<5 {
  let start=ProcessInfo.processInfo.systemUptime
  let effect=try DefenseEffect.evaluate(question:q,prediction:p)
  durations.append(ProcessInfo.processInfo.systemUptime-start);last=effect
  precondition(effect.failure==nil && effect.attackRoute==nil && effect.cueToleranceDegrees==nil)
 }
 let effect=last!,exact=try DefenseEffect.evaluate(question:q,prediction:p,usePrecomputedWindows:false)
 precondition((effect.score==nil)==(exact.score==nil))
 if let a=effect.score,let b=exact.score {precondition(abs(a-b)<0.05)}
 if q.id=="S01-01-30" {
  precondition(effect.score != nil && effect.targetPipeToleranceDegrees==0 && effect.pipeRoute?.pocket==0)
  precondition(effect.pipeRoute?.zeroWidthEstimate==true && effect.unavailableReason==nil)
  precondition(abs(effect.score!-100*sqrt(1-effect.comfort!/100))<1e-10)
  typealias P=DefenseAttackAssessment.P
  let c=p.finalPositions[ShotInput.cueBallName]!,t=p.finalPositions["_8"]!,aim=effect.pipeRoute!.aim
  let cp=P(Double(c.x),Double(c.z)),tp=P(Double(t.x),Double(t.z)),delta=P(aim)-tp,n=delta*(1/delta.length)
  let ghost=tp-n*Double(2*BallPhysics.radius),block=(cp+ghost)*0.5
  var assessment=DefenseAttackAssessment();assessment.usePrecomputedWindows=true
  let blocked=try assessment.pipeAttack(cp,tp,[block])
  precondition(!blocked.routes.contains(where:{$0.pocket==0}),"Zero width must not bypass ball blocking")
 }
 if ["S03-01-46","S04-01-60"].contains(q.id) {precondition(effect.score==100 && effect.potContactsBlocked==true)}
 let target="_\(effect.opponentBallNumber)"
 if let route=effect.pipeRoute {
  let c=p.finalPositions[ShotInput.cueBallName]!,t=p.finalPositions[target]!
  let comfort=ShotComfortScore.evaluate(cue:(Double(c.x),Double(c.z)),ball:(Double(t.x),Double(t.z)),aim:(route.aim[0],route.aim[1]))!
  precondition(abs(comfort.total-route.comfort)<1e-10)
  precondition(abs(effect.score!-DefenseEffect.value(pipeDegrees:route.tolerance,comfort:comfort.total)!)<1e-10)
 }
 rows.append(["id":q.id,"positions":p.finalPositions.mapValues{[Double($0.x),Double($0.z)]},
  "pocketed":p.pocketedBalls,"ownBall":q.ownBallNumber,"target":target,
  "effect":try JSONSerialization.jsonObject(with:JSONEncoder().encode(effect)),"seconds":durations])
 print("GALLERY \(q.id): \(effect.scoreText), angle=\(String(describing:effect.targetPipeToleranceDegrees)), comfort=\(String(describing:effect.comfort))")
}
precondition(DefensePipeTable.shared != nil)
try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("cases.json"))
try JSONSerialization.data(withJSONObject:["passed":true,"cases":rows.count,"checks":["C zero angle scored","C obstacle counterexample","AB blocked contacts score 100","exact/cache agreement","same-route comfort and formula","no cue-angle payload"]],options:.prettyPrinted).write(to:output.appendingPathComponent("results.json"))
print("PASS: 15 final states, zero-width scoring and blocker counterexample")
