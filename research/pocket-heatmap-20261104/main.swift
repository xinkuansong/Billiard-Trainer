import Foundation
import SceneKit
let out=CommandLine.arguments[1]
let config=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/candidate-input.json"))) as! [String:Any]
let nx=config["nx"] as! Int,nz=config["nz"] as! Int
let table=TableGeometry.chineseEightBallQiuJi(surfaceY:0)
let radius=Double(AngleSceneCalculator.ballRadius)
let hx=Double(AngleSceneCalculator.innerLength)/2-radius,hz=Double(AngleSceneCalculator.innerWidth)/2-radius
let xs=(0..<nx).map{ -hx+2*hx*Double($0)/Double(nx-1) },zs=(0..<nz).map{ -hz+2*hz*Double($0)/Double(nz-1) }
func save(_ obj:Any,_ name:String)throws {try JSONSerialization.data(withJSONObject:obj,options:[.sortedKeys]).write(to:URL(fileURLWithPath:out+"/"+name))}
var cells=[[String:Any]](),convergence=0.0,edgeCount=0,multiple=0,masked=0,adaptive=0
let begun=Date()
for (ix,x) in xs.enumerated() {
 for (iz,z) in zs.enumerated() {
  let target=SCNVector3(Float(x),Float(radius),Float(z))
  if table.pockets.contains(where:{$0.containsCapture(target)}) {
   cells.append(["ix":ix,"iz":iz,"valid":false]);masked+=1;continue
  }
  var widths=[Double](),coarseWidths=[Double](),options=[[String:Any]]()
  for pocket in 0..<6 {
   var coarse=AngleSceneCalculator.researchWindow(target,pocketIndex:pocket,stepDegrees:0.05)
   var fine=AngleSceneCalculator.researchWindow(target,pocketIndex:pocket,stepDegrees:0.025)
   func width(_ result:[String:Any])->Double { (result["intervals"] as! [[String:Any]]).map{$0["widthDegrees"] as! Double}.max() ?? 0 }
   if abs(width(coarse)-width(fine))>0.001 {
    adaptive+=1
    coarse=AngleSceneCalculator.researchWindow(target,pocketIndex:pocket,stepDegrees:0.005)
    fine=AngleSceneCalculator.researchWindow(target,pocketIndex:pocket,stepDegrees:0.0025)
   }
   let c=(coarse["intervals"] as! [[String:Any]]).map{$0["widthDegrees"] as! Double}.max() ?? 0
   let intervals=fine["intervals"] as! [[String:Any]]
   let best=intervals.max { ($0["widthDegrees"] as! Double)<($1["widthDegrees"] as! Double) }
   let w=best?["widthDegrees"] as? Double ?? 0
   coarseWidths.append(c);widths.append(w);convergence=max(convergence,abs(w-c))
   if intervals.count>1 { multiple+=1 }
   if (fine["edgeStates"] as! [Bool]).contains(true) { edgeCount+=1 }
   options.append(best ?? [:])
  }
  let maxW=widths.max()!,best=widths.firstIndex(of:maxW)!
  let ties=maxW>0 ? widths.indices.filter{maxW-widths[$0]<=0.001}:[]
  cells.append(["ix":ix,"iz":iz,"valid":true,"widths":widths,"coarseWidths":coarseWidths,"bestPocket":maxW>0 ? best:-1,"maxDegrees":maxW,"ties":ties,"bestInterval":options[best]])
 }
 if ix%10==0 {print("GRID",ix+1,"/",nx,"elapsed",Date().timeIntervalSince(begun));fflush(stdout)}
}
try save(["nx":nx,"nz":nz,"x":xs,"z":zs,"radius":radius,"length":Double(AngleSceneCalculator.innerLength),"width":Double(AngleSceneCalculator.innerWidth),"cells":cells,"pockets":table.pockets.enumerated().map{["index":$0.offset,"center":[Double($0.element.center.x),Double($0.element.center.z)]]}],"grid.json")
try save(["cells":cells.count,"valid":cells.count-masked,"masked":masked,"pocketEvaluations":(cells.count-masked)*12,"maxCoarseFineDifferenceDegrees":convergence,"adaptiveRefinements":adaptive,"multipleIntervals":multiple,"searchEdgeHits":edgeCount,"seconds":Date().timeIntervalSince(begun)],"summary.json")
