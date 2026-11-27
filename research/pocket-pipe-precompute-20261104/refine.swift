import Foundation
import SceneKit
let out=CommandLine.arguments[1]
let rows=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/refine-input.json"))) as! [[String:Any]]
var results=[[String:Any]]()
for row in rows {
 let p=row["position"] as! [Double],pocket=row["pocket"] as! Int
 var checks=[[String:Any]]()
 for step in [0.001,0.0005] {
  let w=AngleSceneCalculator.defenseCleanWindow(SCNVector3(Float(p[0]),AngleSceneCalculator.ballRadius,Float(p[1])),pocketIndex:pocket,stepDegrees:step)
  let intervals=(w["intervals"] as! [[String:Any]]).map{[$0["leftDegrees"] as! Double,$0["rightDegrees"] as! Double]}
  checks.append(["step":step,"intervals":intervals,"closed": !(w["edgeStates"] as! [Bool]).contains(true),"isolated":w["isolatedDirections"] as! [Double]])
 }
 var result=row;result["refinedChecks"]=checks;results.append(result)
 print("REFINED",p,pocket,checks)
}
try JSONSerialization.data(withJSONObject:results,options:[.sortedKeys]).write(to:URL(fileURLWithPath:out+"/refined.json"))
