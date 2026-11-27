import Foundation
import SceneKit
let out=CommandLine.arguments[1]
let table=TableGeometry.chineseEightBallQiuJi(surfaceY:0)
let radius=Double(AngleSceneCalculator.ballRadius)
let hx=Double(AngleSceneCalculator.innerLength)/2-radius,hz=Double(AngleSceneCalculator.innerWidth)/2-radius
func axis(_ half:Double)->[Double] {
 let n=Int(ceil(2*half/0.01))
 var values=(0...n).map{-half+2*half*Double($0)/Double(n)}
 for gap in [0.001,0.002,0.005] {values += [-half+gap,half-gap]}
 return Array(Set(values)).sorted()
}
let xs=axis(hx),zs=axis(hz)
func save(_ object:Any,_ name:String)throws {
 try JSONSerialization.data(withJSONObject:object,options:[.sortedKeys]).write(to:URL(fileURLWithPath:out+"/"+name))
}
var calls=0,refinements=0,maxDifference=0.0,openEdges=0,unresolved=0
// Every contiguous interval is retained; a zero-width tangency is separate.
func evaluate(_ x:Double,_ z:Double,_ pocket:Int)->[String:Any] {
 let point=SCNVector3(Float(x),Float(radius),Float(z))
 func run(_ step:Double)->[String:Any] {calls += 1;return AngleSceneCalculator.defenseCleanWindow(point,pocketIndex:pocket,stepDegrees:step)}
 func intervals(_ r:[String:Any])->[[Double]] {
  (r["intervals"] as! [[String:Any]]).map{[$0["leftDegrees"] as! Double,$0["rightDegrees"] as! Double]}
 }
 func difference(_ a:[String:Any],_ b:[String:Any])->Double {
  let aa=intervals(a),bb=intervals(b)
  if aa.count != bb.count{return 360}
  return zip(aa,bb).map{max(abs($0[0]-$1[0]),abs($0[1]-$1[1]))}.max() ?? 0
 }
 var a=run(0.05),b=run(0.025)
 if difference(a,b)>0.001 {refinements += 1;a=run(0.005);b=run(0.0025)}
 let error=difference(a,b);maxDifference=max(maxDifference,error)
 let open=(b["edgeStates"] as! [Bool]).contains(true)
 if open{openEdges += 1};if error>0.001{unresolved += 1}
 return ["intervals":intervals(b),"isolated":b["isolatedDirections"] as! [Double],"closed":!open,
         "converged":error<=0.001,"difference":error]
}
let start=Date()
var cells=[[[String:Any]]]()
var valid=[Bool]()
for (ix,x) in xs.enumerated() {
 for z in zs {
  let point=SCNVector3(Float(x),Float(radius),Float(z))
  let yes = !table.pockets.contains{$0.containsCapture(point)}
  valid.append(yes)
  cells.append(yes ? (0..<6).map{evaluate(x,z,$0)}:[])
 }
 if ix%10==0 {print("GRID",ix+1,"/",xs.count,"seconds",Date().timeIntervalSince(start));fflush(stdout)}
}
try save(["schema":"target-pipe-grid-v1","x":xs,"z":zs,"radius":radius,"length":Double(AngleSceneCalculator.innerLength),
 "width":Double(AngleSceneCalculator.innerWidth),"pockets":table.pockets.enumerated().map{["index":$0.offset,"center":[Double($0.element.center.x),Double($0.element.center.z)]]},
 "valid":valid,"cells":cells],"grid-raw.json")
let gridSeconds=Date().timeIntervalSince(start)
// Deterministic, off-grid holdouts: interior, near rails, near corners, real ABC.
var state:UInt64=20261104
func random()->Double {state=state &* 6364136223846793005 &+ 1442695040888963407;return Double(state>>11)/Double(UInt64(1)<<53)}
var points=[(String,Double,Double)]()
for i in 0..<2400 {points.append(("interior-\(i)",(2*random()-1)*hx,(2*random()-1)*hz))}
for i in 0..<800 {
 let gap=random()*0.035,side=i%4
 let x=side<2 ? (side==0 ? -hx+gap:hx-gap):(2*random()-1)*hx
 let z=side>=2 ? (side==2 ? -hz+gap:hz-gap):(2*random()-1)*hz
 points.append(("rail-\(i)",x,z))
}
for i in 0..<400 {
 let x=(i%2==0 ? -1.0:1.0)*(hx-random()*0.15)
 let z=(i%4<2 ? -1.0:1.0)*(hz-random()*0.15)
 points.append(("corner-\(i)",x,z))
}
points += [("A",-0.6880903840,-0.1894574463),("B",-1.1271903515,0.1300215721),("C",-1.2274777889,-0.4381169081)]
var holdouts=[[String:Any]]()
for (i,p) in points.enumerated() {
 let yes = !table.pockets.contains{$0.containsCapture(SCNVector3(Float(p.1),Float(radius),Float(p.2)))}
 holdouts.append(["id":p.0,"position":[p.1,p.2],"valid":yes,"pockets":yes ? (0..<6).map{evaluate(p.1,p.2,$0)}:[]])
 if i%500==0 {print("HOLDOUT",i,"/",points.count,"seconds",Date().timeIntervalSince(start));fflush(stdout)}
}
try save(holdouts,"holdouts.json")
try save(["nx":xs.count,"nz":zs.count,"points":cells.count,"pocketRecords":valid.filter{$0}.count*6,
 "calls":calls,"refinements":refinements,"maxBoundaryDifferenceDegrees":maxDifference,"openEdges":openEdges,
 "unresolved":unresolved,"gridSeconds":gridSeconds,"totalSeconds":Date().timeIntervalSince(start)],"summary.json")
print("COMPLETE",cells.count,"points",Date().timeIntervalSince(start),"seconds")
