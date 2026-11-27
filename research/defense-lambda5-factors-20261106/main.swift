import Foundation
import SceneKit
struct Sample:Codable {let id,name,note:String;let cue,target:[Double];let blockers:[[Double]];let group:String;let focusPocket:Int}
let output=URL(fileURLWithPath:CommandLine.arguments[1])
let samples=try JSONDecoder().decode([Sample].self,from:Data(contentsOf:output.appendingPathComponent("cases.json")))
func encoded<T:Encodable>(_ x:T)throws->Any {try JSONSerialization.jsonObject(with:JSONEncoder().encode(x))}
typealias P=DefenseAttackAssessment.P
var rows=[[String:Any]]()
for s in samples {
 var variants=[[String:Any]]()
 let weights=try JSONDecoder().decode([Double].self,from:Data(contentsOf:output.appendingPathComponent("weights.json")))
 for weight in weights {
  let revised=weight>=0
  defenseAngleExperiment=revised
  defenseAngleWeight=max(0,weight)
  var assessment=DefenseAttackAssessment()
  func fp(_ a:[Double])->P { P(Double(Float(a[0])),Double(Float(a[1]))) }
  let cue=fp(s.cue),ball=fp(s.target),others=s.blockers.map(fp)
  let attack=try assessment.pipeAttack(cue,ball,others)
  let effect=try DefenseEffect.regionState(cue:cue.scn,target:ball.scn,blockers:others.map(\.scn),windows:assessment)
  var row:[String:Any]=["revised":revised,"lambda":weight,"effect":try encoded(effect),"routes":try attack.routes.map(encoded),"closedPockets":Array(attack.confirmedClosedPockets).sorted()]
  row["pockets"] = (0..<6).map { i -> [String:Any] in
   let routes=attack.routes.filter{$0.pocket==i}
   var p:[String:Any] = ["pocket":i,"confirmedClosed":attack.confirmedClosedPockets.contains(i),"routeCount":routes.count]
   if let r=routes.min(by:{$0.score < $1.score}) {
    p["route"]=try! encoded(r);p["score"]=r.score
    let c=ShotComfortScore.evaluate(cue:(cue.x,cue.z),ball:(ball.x,ball.z),aim:(r.aim[0],r.aim[1]))!
    p["components"]=["distance":c.distance,"space":c.space,"angle":c.angle,"total":c.total]
   }
   return p
  }
  if let route=effect.pipeRoute {
   let p=route.aim;let c=ShotComfortScore.evaluate(cue:(cue.x,cue.z),ball:(ball.x,ball.z),aim:(p[0],p[1]))!
   row["components"]=["distance":c.distance,"space":c.space,"angle":c.angle,"total":c.total]
   row["cutDegrees"]=defenseExperimentCut(cue,ball,P(p))
  }
  precondition(effect.score != nil && effect.score!.isFinite && (0...100).contains(effect.score!))
  variants.append(row)
 }
 for i in variants.indices where i >= 2 {
  precondition((variants[i]["effect"] as! [String:Any])["score"] as! Double >= (variants[i-1]["effect"] as! [String:Any])["score"] as! Double - 1e-6)
 }
 rows.append(["case":try encoded(s),"variants":variants])
 print("FINISH \(s.id) \(s.name) \(variants.map{($0["effect"] as! [String:Any])["score"]!})");fflush(stdout)
}
try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("results.json"))
