import Foundation
import SceneKit
import CryptoKit

let out=CommandLine.arguments[1]
let manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/input-manifest.json"))) as! [String:Any]
let policy=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/protocol.json"))) as! [String:Any]
let widthLimit=policy["cueWidthLimitDegrees"] as! Double,comfortLimit=policy["maxRepresentativeComfortLimit"] as! Double
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
func digest(_ data:Data)->String{SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()}
func maxComfort(_ a:[String:Any])->Double{(a["options"] as! [[String:Any]]).map{($0["comfort"] as? [String:Double])?["total"] ?? 0}.max() ?? 0}
func cueWidth(_ a:[String:Any])->Double{(a["best"] as! [String:Any])["cueWidth"] as! Double}
func qualifies(_ a:[String:Any])->Bool{a["rejected"]==nil && cueWidth(a)>1e-6 && cueWidth(a)<=widthLimit && maxComfort(a)<comfortLimit}
func completeEndpoints(_ a:[String:Any],_ ball:P)->Bool{
 for o in a["options"] as! [[String:Any]] where (o["cueWidth"] as! Double)>0 {
  for k in ["leftEnd","aim","rightEnd"] {guard let point=o[k] as? [Double],(P(point)-ball).length>1e-8 else{return false}}
 }
 return true
}
func dist(_ p:P,_ a:P,_ b:P)->Double{
 let v=b-a;let t=max(0,min(1,(p-a).dot(v)/max(1e-20,v.dot(v))));return (p-(a+v*t)).length
}
func angleWidth(_ a:P,_ b:P)->Double{abs(atan2(a.cross(b),a.dot(b)))*180/Double.pi}
func save(_ a:Any,_ name:String)throws{try JSONSerialization.data(withJSONObject:a,options:[.sortedKeys]).write(to:URL(fileURLWithPath:out+"/"+name))}
var checks=[[String:Any]]()
var cache=[String:[String:Any]](),geometries=[Int:[String:Any]](),windowDiff=0.0,edges=0,windowCalls=0
func window(_ b:P,_ p:Int)->[String:Any]{
 let key="\(b.x),\(b.z),\(p)";if let v=cache[key]{return v}
 var a=AngleSceneCalculator.researchWindow(b.scn,pocketIndex:p,stepDegrees:0.05)
 var w=AngleSceneCalculator.researchWindow(b.scn,pocketIndex:p,stepDegrees:0.025)
 func width(_ v:[String:Any])->Double{(v["intervals"] as! [[String:Any]]).map{$0["widthDegrees"] as! Double}.max() ?? 0}
 if abs(width(a)-width(w))>0.001 {a=AngleSceneCalculator.researchWindow(b.scn,pocketIndex:p,stepDegrees:0.005);w=AngleSceneCalculator.researchWindow(b.scn,pocketIndex:p,stepDegrees:0.0025)}
 checks.append(["target":b.json,"pocket":p,"difference":abs(width(a)-width(w)),"coarseWidth":width(a),"fineWidth":width(w)])
 windowDiff=max(windowDiff,abs(width(a)-width(w)));if (w["edgeStates"] as! [Bool]).contains(true){edges+=1}
 precondition(!(w["edgeStates"] as! [Bool]).contains(true),"Unclosed object window")
 if geometries[p]==nil {geometries[p]=w["geometry"] as? [String:Any]}
 w.removeValue(forKey:"geometry");cache[key]=w;windowCalls+=1;return w
}

let positions=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/positions.json"))) as! [[Double]]
for (i,position) in positions.enumerated() {
 for p in 0..<6 {_ = window(P(position),p)}
 if i % 1000 == 0 {print("WINDOW AUDIT",i,"/",positions.count);fflush(stdout)}
 if cache.count>40000{cache.removeAll(keepingCapacity:true)}
}
try save(checks,"checks.json")
try save(["complete":true,"positions":positions.count,"checks":checks.count,"maximumDifference":windowDiff,"searchEdgeHits":edges],"summary.json")
