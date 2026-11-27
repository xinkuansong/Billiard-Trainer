import Foundation
import SceneKit
let out=CommandLine.arguments[1]
let input=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/candidate-input.json"))) as! [[String:Any]]
let table=TableGeometry.chineseEightBallQiuJi(surfaceY:0)
let r=BallPhysics.radius
func save(_ x:Any,_ name:String) throws {try JSONSerialization.data(withJSONObject:x,options:[.sortedKeys,.prettyPrinted]).write(to:URL(fileURLWithPath:out+"/"+name))}
var rows=[[String:Any]](), sims=0
let begun=Date()
for item in input {
 let pos=item["target"] as! [Double],pocket=item["pocket"] as! Int
 let target=SCNVector3(Float(pos[0]),r,Float(pos[1]))
 var row=item
 let coarse=AngleSceneCalculator.researchWindow(target,pocketIndex:pocket,stepDegrees:0.05)
 let fine=AngleSceneCalculator.researchWindow(target,pocketIndex:pocket,stepDegrees:0.025)
 row["window"]=fine;row["coarseWidth"]=coarse["totalWidthDegrees"]
 var probes=[[String:Any]]()
 let base=fine["baseRadians"] as! Double
 for interval in fine["intervals"] as! [[String:Any]] {
  let l=interval["leftDegrees"] as! Double,h=interval["rightDegrees"] as! Double
  for fraction in [-0.1,0.05,0.5,0.95,1.1] {
   let delta=l+(h-l)*fraction,angle=base+delta*Double.pi/180
   for speed:Float in [0.8,1.4,2.0] {
    let engine=EventDrivenEngine(tableGeometry:table)
    let v=SCNVector3(Float(cos(angle))*speed,0,Float(sin(angle))*speed)
    let omega=SCNVector3(v.z/r,0,-v.x/r)
    engine.setBall(BallState(position:target,velocity:v,angularVelocity:omega,state:.rolling,name:"object"))
    let termination=engine.simulate(maxEvents:1000,maxTime:30,highFidelityBounds:true)
    var events=[[String:Any]](),captured="",contacts=0
    for (e,time) in zip(engine.resolvedEvents,engine.resolvedEventTimes) {
     switch e {
     case let .pocket(_,id):captured=id;events.append(["kind":"pocket","pocket":id,"time":Double(time)])
     case let .ballCushion(_,index,_): contacts+=1;events.append(["kind":"cushion","index":index,"time":Double(time)])
     default:break
     }
    }
    probes.append(["fraction":fraction,"angleDeltaDegrees":delta,"speed":Double(speed),"pocket":captured,"railContacts":contacts,"termination":String(describing:termination),"cleanPot":captured=="pocket_\(pocket)" && contacts==0,"events":events]);sims+=1
   }
  }
 }

 if (fine["intervals"] as! [[String:Any]]).isEmpty {
  let aim=AngleSceneCalculator.effectivePocketAimPoint(targetBall:target,pocketIndex:pocket,surfaceY:0)
  let seed=atan2(Double(aim.z-target.z),Double(aim.x-target.x))
  var fallback=[[String:Any]]()
  for step in -40...40 {
   let delta=Double(step)*0.05, angle=seed+delta*Double.pi/180
   for speed:Float in [1.4,2.0,3.0] {
    let engine=EventDrivenEngine(tableGeometry:table)
    let v=SCNVector3(Float(cos(angle))*speed,0,Float(sin(angle))*speed)
    engine.setBall(BallState(position:target,velocity:v,angularVelocity:SCNVector3(v.z/r,0,-v.x/r),state:.rolling,name:"object"))
    let termination=engine.simulate(maxEvents:1000,maxTime:30,highFidelityBounds:true)
    var captured="",contacts=[Int](),eventRows=[[String:Any]]()
    for (event,time) in zip(engine.resolvedEvents,engine.resolvedEventTimes) {
     switch event {
     case let .pocket(_,id):captured=id;eventRows.append(["time":Double(time),"pocket":id])
     case let .ballCushion(_,index,_):contacts.append(index);eventRows.append(["time":Double(time),"cushion":index])
     default:break
     }
    }
    fallback.append(["seedRadians":seed,"deltaDegrees":delta,"speed":Double(speed),"pocket":captured,"cushions":contacts,"termination":String(describing:termination),"events":eventRows]);sims+=1
   }
  }
  row["zeroWindowSearch"]=fallback
 }
 row["rollingProbes"]=probes;rows.append(row)
 print(item["id"]!,fine["totalWidthDegrees"]!,"degrees",probes.filter{$0["cleanPot"] as! Bool}.count,"clean /",probes.count)
 fflush(stdout)
}
try save(rows,"results.json")
try save(["cases":rows.count,"simulations":sims,"seconds":Date().timeIntervalSince(begun),"scope":"clean geometric windows and finite rolling-object probes; no cue strike or success probability"],"summary.json")
