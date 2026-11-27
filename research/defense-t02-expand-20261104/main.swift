import Foundation
import SceneKit

let out=CommandLine.arguments[1]
let rows=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/candidate-input.json"))) as! [[String:Any]]
let rad=Double(AngleSceneCalculator.ballRadius), hx=Double(AngleSceneCalculator.innerLength)/2, hz=Double(AngleSceneCalculator.innerWidth)/2
let table=TableGeometry.chineseEightBallQiuJi(surfaceY:0)
struct P {
 let x,z:Double
 init(_ a:[Double]) {x=a[0];z=a[1]}
 init(_ x:Double,_ z:Double){self.x=x;self.z=z}
 var json:[Double]{[x,z]};var length:Double{hypot(x,z)}
 var scn:SCNVector3{SCNVector3(Float(x),0,Float(z))}
 static func +(_ a:P,_ b:P)->P{P(a.x+b.x,a.z+b.z)}
 static func -(_ a:P,_ b:P)->P{P(a.x-b.x,a.z-b.z)}
 static func *(_ a:P,_ b:Double)->P{P(a.x*b,a.z*b)}
 func dot(_ b:P)->Double{x*b.x+z*b.z}
 func cross(_ b:P)->Double{x*b.z-z*b.x}
}
func dist(_ p:P,_ a:P,_ b:P)->Double{
 let v=b-a;let t=max(0,min(1,(p-a).dot(v)/max(1e-20,v.dot(v))));return (p-(a+v*t)).length
}
func angleWidth(_ a:P,_ b:P)->Double{abs(atan2(a.cross(b),a.dot(b)))*180/Double.pi}
func save(_ a:Any,_ name:String)throws{try JSONSerialization.data(withJSONObject:a,options:[.sortedKeys]).write(to:URL(fileURLWithPath:out+"/"+name))}
var cache=[String:[[String:Any]]](),geometries=[[String:Any]](),windowDiff=0.0,edges=0
func windows(_ b:P)->[[String:Any]]{
 let key="\(b.x),\(b.z)";if let v=cache[key]{return v}
 var options=[[String:Any]]()
 for p in 0..<6 {
  var a=AngleSceneCalculator.researchWindow(b.scn,pocketIndex:p,stepDegrees:0.05)
  var w=AngleSceneCalculator.researchWindow(b.scn,pocketIndex:p,stepDegrees:0.025)
  func width(_ v:[String:Any])->Double{(v["intervals"] as! [[String:Any]]).map{$0["widthDegrees"] as! Double}.max() ?? 0}
  if abs(width(a)-width(w))>0.001 {a=AngleSceneCalculator.researchWindow(b.scn,pocketIndex:p,stepDegrees:0.005);w=AngleSceneCalculator.researchWindow(b.scn,pocketIndex:p,stepDegrees:0.0025)}
  windowDiff=max(windowDiff,abs(width(a)-width(w)));if (w["edgeStates"] as! [Bool]).contains(true){edges+=1}
  if cache.isEmpty {geometries.append(w["geometry"] as! [String:Any])}
  w.removeValue(forKey:"geometry");options.append(w)
 }
 cache[key]=options;return options
}
func attack(_ cue:P,_ ball:P,_ others:[P],_ ws:[[String:Any]],step:Double)->[String:Any]{
 var options=[[String:Any]]()
 for p in 0..<6 {
  let w=ws[p],base=w["baseRadians"] as! Double
  let ranges=w["intervals"] as! [[String:Any]]
  let objectWidth=ranges.map{$0["widthDegrees"] as! Double}.max() ?? 0
  func state(_ offset:Double)->(Bool,P,P,P){
   let a=base+offset*Double.pi/180,n=P(cos(a),sin(a)),g=ball-n*(2*rad),v=g-cue
   guard let d=table.pockets[p].entryTime(position:ball.scn,velocity:n.scn,acceleration:SCNVector3Zero,maxTime:4) else{return(false,g,ball,n)}
   let end=ball+n*Double(d)
   // Always retain the pot-ray endpoint, including a zero-contact boundary.
   guard v.dot(n)>1e-12,abs(g.x)<=hx-rad+1e-7,abs(g.z)<=hz-rad+1e-7 else{return(false,g,end,n)}
   for o in others {if dist(o,cue,g)<2*rad || dist(o,ball,end)<2*rad{return(false,g,end,n)}}
   return(true,g,end,n)
  }
  var validRanges=[[Double]]()
  func refine(_ a:Double,_ b:Double,_ left:Bool)->Double{
   var lo=a,hi=b
   for _ in 0..<30{let mid=(lo+hi)/2;if state(mid).0==left{lo=mid}else{hi=mid}}
   return (lo+hi)/2
  }
  for r in ranges {
   let lo=r["leftDegrees"] as! Double,hi=r["rightDegrees"] as! Double
   let count=max(2,Int(ceil((hi-lo)/step)));var start:Double?=nil,prev=false
   for i in 0...count {
    let a=lo+(hi-lo)*Double(i)/Double(count),yes=state(a).0
    if yes && !prev{start=i==0 ? lo:refine(a-(hi-lo)/Double(count),a,false)}
    if !yes && prev{validRanges.append([start!,refine(a-(hi-lo)/Double(count),a,true)]);start=nil}
    prev=yes
   }
   if prev{validRanges.append([start!,hi])}
  }
  var best:[String:Any]=["pocket":p,"objectWidth":objectWidth,"cueWidth":0.0,"status":objectWidth==0 ? "no_clean_window":"inaccessible","validIntervals":validRanges]
  for r in validRanges {
   let a=state(r[0]),b=state(r[1]);let width=angleWidth(a.1-cue,b.1-cue)
   if width <= (best["cueWidth"] as! Double){continue}
   // Monotone contact map: choose the midpoint in CUE angle, not object angle.
   let av=a.1-cue,bv=b.1-cue,dir=av*(1/av.length)+bv*(1/bv.length)
   var lo=r[0],hi=r[1]
   for _ in 0..<35{let m=(lo+hi)/2;if (state(m).1-cue).cross(dir)<0{lo=m}else{hi=m}}
   let mid=(lo+hi)/2
   let s=state(mid),cut=angleWidth(s.1-cue,s.3)
   let comfort=ShotComfortScore.evaluate(cue:(cue.x,cue.z),ball:(ball.x,ball.z),aim:(s.2.x,s.2.z))!
   best=["pocket":p,"objectWidth":objectWidth,"cueWidth":width,"status":"open","validIntervals":validRanges,
    "objectInterval":r,"objectUsedWidth":r[1]-r[0],"ghost":s.1.json,"aim":s.2.json,"leftGhost":a.1.json,"rightGhost":b.1.json,
    "leftEnd":a.2.json,"rightEnd":b.2.json,"cut":cut,"cueDistance":(s.1-cue).length,"potDistance":(s.2-ball).length,
    "comfort":["total":comfort.total,"angle":comfort.angle,"distance":comfort.distance,"space":comfort.space]]
  }
  options.append(best)
 }
 let best=options.max{($0["cueWidth"] as! Double)<($1["cueWidth"] as! Double)}!
 return ["options":options,"best":best,"objectBestPocket":ws.indices.max{((ws[$0]["intervals"] as! [[String:Any]]).map{$0["widthDegrees"] as! Double}.max() ?? 0)<((ws[$1]["intervals"] as! [[String:Any]]).map{$0["widthDegrees"] as! Double}.max() ?? 0)}!]
}
// Numerical coordinate-contract checks: straight and 45-degree contact normals.
let n=P(1,0),target=P(0,0),ghost=target-n*(2*rad)
assert(abs((ghost-target).length-2*rad)<1e-12)
assert(angleWidth(ghost-P(-1,0),n)<1e-10)
assert(abs(angleWidth(ghost-(ghost-P(1,1)),n)-45)<1e-10)
var result=[[String:Any]](),mappingDiff=0.0
let begun=Date()
for (i,row) in rows.enumerated(){
 let cue=P(row["cue"] as! [Double]),balls=(row["positions"] as! [[Double]]).map{P($0)}
 let own=row["own"] as! Int,enemy=row["enemy"] as! Int
 var q=row
 for (key,index) in [("ownAttack",own),("enemyAttack",enemy)]{
  let ws=windows(balls[index]),others=balls.indices.filter{$0 != index}.map{balls[$0]}
  let a=attack(cue,balls[index],others,ws,step:0.02),b=attack(cue,balls[index],others,ws,step:0.01)
  let aa=a["options"] as! [[String:Any]],bb=b["options"] as! [[String:Any]]
  for p in 0..<6{mappingDiff=max(mappingDiff,abs((aa[p]["cueWidth"] as! Double)-(bb[p]["cueWidth"] as! Double)))}
  q[key]=b
 }
 result.append(q)
 if i%200==0{print("EVALUATED",i,"/",rows.count,"seconds",Date().timeIntervalSince(begun));fflush(stdout)}
}
try save(result,"evaluated.json")
try save(["pockets":geometries,"radius":rad,"length":2*hx,"width":2*hz],"geometry.json")
try save(cache,"windows.json")
try save(["candidates":rows.count,"targetPositions":cache.count,"windowCoarseFineMax":windowDiff,"mappingCoarseFineMax":mappingDiff,"searchEdgeHits":edges,"seconds":Date().timeIntervalSince(begun),"scope":"Static clean direct-pot geometry. No speed, throw, cue-stick clearance, safety stroke, or pot probability."],"summary.json")
