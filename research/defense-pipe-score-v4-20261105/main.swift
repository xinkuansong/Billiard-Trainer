import Foundation
import SceneKit

struct Stroke: Decodable { let direction:[Double]; let speed,spinX,spinY:Float }
struct Sample: Decodable { let source:DefenseBankQuestion; let shot:Stroke }
let output = URL(fileURLWithPath:CommandLine.arguments[1])
let samples = try JSONDecoder().decode([Sample].self,from:Data(contentsOf:output.appendingPathComponent("fixtures.json")))
func prediction(_ sample:Sample) -> ShotPrediction {
 let q=sample.source,s=sample.shot,surface:Float=0.8
 func v(_ a:[Double])->SCNVector3 { .init(Float(a[0]),surface+BallPhysics.radius,Float(a[1])) }
 let direction=SCNVector3(Float(s.direction[0]),0,Float(s.direction[1]))
 return ShotPredictor.simulateFree(cueBall:v(q.cue),aimDir:direction,velocity:s.speed,spinX:s.spinX,spinY:s.spinY,
  surfaceY:surface,balls:q.balls.map { .init(name:"_\($0.number)",position:v($0.position)) },maxEvents:1500,maxTime:60,
  includePresentation:false,simulationModel:.appDefault,recordedStrikeDirection:direction)
}
func evaluate(_ q:DefenseBankQuestion,_ p:ShotPrediction,_ cached:Bool) throws -> (DefenseEffect,[String:Any]) {
 var t=DefenseEffect.Timing();let start=ProcessInfo.processInfo.systemUptime
 let result=try DefenseEffect.evaluate(question:q,prediction:p,usePrecomputedWindows:cached) { t=$0 }
 precondition(t.physicalSeconds==0 && result.cueToleranceDegrees==nil && result.attackRoute==nil)
 return(result,["seconds":ProcessInfo.processInfo.systemUptime-start,"geometrySeconds":t.geometrySeconds,
  "blockConfirmationSeconds":t.blockConfirmationSeconds,"tableHits":t.tableHits,"exactWindows":t.exactWindows])
}
func object<T:Encodable>(_ value:T)throws->Any { try JSONSerialization.jsonObject(with:JSONEncoder().encode(value)) }
func same(_ a:DefenseEffect,_ b:DefenseEffect)throws->Bool {
 let e=JSONEncoder();e.outputFormatting = .sortedKeys;return try e.encode(a)==e.encode(b)
}
let ids=["S03-01-46","S04-01-60","S01-01-30"]
var rows=[[String:Any]]()
for id in ids {
 let s=samples.first { $0.source.id==id }!,p=prediction(s)
 let (first,firstTiming)=try evaluate(s.source,p,true)
 precondition(first.failure==nil)
 if id==ids[2] { precondition(first.score==nil && first.unavailableReason?.contains("管道模型")==true) }
 else { precondition(first.score==95 && first.potContactsBlocked==true) }
 var old=[[String:Any]](),current=[[String:Any]](),exact=[[String:Any]]()
 for round in 0..<9 {
  for mode in (round.isMultiple(of:2) ? [0,1,2] : [2,1,0]) {
   try autoreleasepool {
    if mode==0 {
     let start=ProcessInfo.processInfo.systemUptime
     let effect=try LegacyDefenseEffect.evaluate(question:s.source,prediction:p)
     old.append(["seconds":ProcessInfo.processInfo.systemUptime-start,"effect":try object(effect)])
    } else {
     let (effect,timing)=try evaluate(s.source,p,mode==2)
     let equal=try same(first,effect);precondition(equal,"ABC exact/cache result mismatch")
     if mode==2 {current.append(timing)} else {exact.append(timing)}
    }
   }
  }
 }
 rows.append(["id":id,"firstV4":firstTiming,"v3":old,"v4":current,"v4Exact":exact,"effect":try object(first)])
 print("BENCH \(id) v4=\(current.map{$0["seconds"]!}) score=\(first.scoreText)")
}
precondition(DefensePipeTable.shared != nil,"Bundled table must load")
// Independent cue locations retain the identical target-only interval, while comfort changes.
typealias P=DefenseAttackAssessment.P
let ball=P(-0.2,0),pc=AngleSceneCalculator.pocketPositions(surfaceY:0)[1]
let delta=P(Double(pc.x),Double(pc.z))-ball,n=delta*(1/delta.length)
var witnesses=[DefenseAttackAssessment.PipeRoute]()
for d in [0.4,0.9] {
 var assessment=DefenseAttackAssessment();assessment.usePrecomputedWindows=true
 let attack=try assessment.pipeAttack(ball-n*d,ball,[])
 guard let route=attack.routes.first(where:{$0.pocket==1}) else {fatalError("Missing open pipe witness")}
 witnesses.append(route)
 let measured=ShotComfortScore.evaluate(cue:(ball.x-n.x*d,ball.z-n.z*d),ball:(ball.x,ball.z),aim:(route.aim[0],route.aim[1]))!
 precondition(abs(measured.total-route.comfort)<1e-12)
}
precondition(witnesses[0].tolerance==witnesses[1].tolerance && witnesses[0].comfort != witnesses[1].comfort)
precondition((65...70).contains(DefenseEffect.value(pipeDegrees:1,comfort:10)!))
precondition((50...60).contains(DefenseEffect.value(pipeDegrees:2,comfort:10)!))
precondition(DefenseEffect.value(pipeDegrees:.nan,comfort:0)==nil)
for angle in [0.0,0.1,1,5] {
 var previous=101.0
 for comfort in stride(from:0.0,through:100,by:1) {
  let score=DefenseEffect.value(pipeDegrees:angle,comfort:comfort)!
  precondition(score<=previous && score>=0);previous=score
 }
}
let legacy=LegacyDefenseEffect(scoringVersion:"defense-physical-paired-angle008-comfort-v3",failure:nil,
 fullDirectBlock:false,cueToleranceDegrees:0.213359375,comfort:6.7153189,opponentBallNumber:8,
 score:18.3612058314,unavailableReason:nil)
let restored=try JSONDecoder().decode(DefenseEffect.self,from:JSONEncoder().encode(legacy))
precondition(restored.score==legacy.score && restored.targetPipeToleranceDegrees==nil && restored.detail.contains("0.008°"))
var coverage=[[String:Any]]()
for s in samples {
 let p=prediction(s),a=try evaluate(s.source,p,false).0,b=try evaluate(s.source,p,true).0
 precondition(a.failure==b.failure && a.fullDirectBlock==b.fullDirectBlock && a.potContactsBlocked==b.potContactsBlocked)
 precondition((a.score==nil)==(b.score==nil))
 if let x=a.score,let y=b.score {precondition(abs(x-y)<0.05)}
 if let route=b.pipeRoute {
  precondition(b.targetPipeToleranceDegrees==route.tolerance && b.comfort==route.comfort && b.score==route.score)
 }
 coverage.append(["id":s.source.id,"exact":try object(a),"cached":try object(b)])
}
let result:[String:Any]=["passed":true,"rows":rows,"coverage":coverage,"cueIndependence":try witnesses.map(object),
 "scope":"Same optimized simulator binary; frozen v3 versus production v4, 9 alternating repetitions. Original shot simulation/UI excluded. V4 has no physical scoring calls. C intentionally unscored pending pipe model correction."]
try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("results.json"))
print("PASS: ABC, 15-case exact/cache comparison, formula, cue independence, paired comfort, historical score preservation")
