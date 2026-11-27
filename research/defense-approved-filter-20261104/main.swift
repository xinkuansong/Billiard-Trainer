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
var cache=[String:[String:Any]](),geometries=[Int:[String:Any]](),windowDiff=0.0,edges=0,windowCalls=0
func window(_ b:P,_ p:Int)->[String:Any]{
 let key="\(b.x),\(b.z),\(p)";if let v=cache[key]{return v}
 var a=AngleSceneCalculator.researchWindow(b.scn,pocketIndex:p,stepDegrees:0.05)
 var w=AngleSceneCalculator.researchWindow(b.scn,pocketIndex:p,stepDegrees:0.025)
 func width(_ v:[String:Any])->Double{(v["intervals"] as! [[String:Any]]).map{$0["widthDegrees"] as! Double}.max() ?? 0}
 if abs(width(a)-width(w))>0.001 {a=AngleSceneCalculator.researchWindow(b.scn,pocketIndex:p,stepDegrees:0.005);w=AngleSceneCalculator.researchWindow(b.scn,pocketIndex:p,stepDegrees:0.0025)}
 windowDiff=max(windowDiff,abs(width(a)-width(w)));if (w["edgeStates"] as! [Bool]).contains(true){edges+=1}
 precondition(!(w["edgeStates"] as! [Bool]).contains(true),"Unclosed object window")
 if geometries[p]==nil {geometries[p]=w["geometry"] as? [String:Any]}
 w.removeValue(forKey:"geometry");cache[key]=w;windowCalls+=1;return w
}
func attack(_ cue:P,_ ball:P,_ others:[P],step:Double,early:Bool=false,preferred:Int?=nil)->[String:Any]{
 var options=[[String:Any]]()
 var order=Array(0..<6)
 if let first=preferred {order.removeAll{$0==first};order.insert(first,at:0)}
 else {order.sort {a,b in
  let na=P(Double(table.pockets[a].center.x),Double(table.pockets[a].center.z))-ball
  let nb=P(Double(table.pockets[b].center.x),Double(table.pockets[b].center.z))-ball
  return angleWidth(ball-na*(2*rad/na.length)-cue,na)<angleWidth(ball-nb*(2*rad/nb.length)-cue,nb)
 }}
 for p in order {
  let w=window(ball,p),base=w["baseRadians"] as! Double
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
  let cw=best["cueWidth"] as! Double, cs=(best["comfort"] as? [String:Double])?["total"] ?? 0
  if early && (cw>widthLimit || cs>=comfortLimit) {return ["rejected":true,"witnessPocket":p,"witnessWidth":cw,"witnessComfort":cs]}
 }
 options.sort{($0["pocket"] as! Int)<($1["pocket"] as! Int)}
 let best=options.max{($0["cueWidth"] as! Double)<($1["cueWidth"] as! Double)}!
 return ["options":options,"best":best,"objectBestPocket":options.max{($0["objectWidth"] as! Double)<($1["objectWidth"] as! Double)}!["pocket"] as! Int]
}

let begun=Date()
let controls=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:out+"/controls.json"))) as! [[String:Any]]
var controlDiff=0.0,controlScoreDiff=0.0
for row in controls {
 let cue=P(row["cue"] as! [Double]),balls=(row["positions"] as! [[Double]]).map{P($0)},own=row["own"] as! Int
 let others=balls.indices.filter{$0 != own}.map{balls[$0]}
 let full=attack(cue,balls[own],others,step:0.01)
 let fast=attack(cue,balls[own],others,step:0.01,early:true)
 let w=row["width"] as! Double,c=row["comfort"] as! Double
 controlDiff=max(controlDiff,abs(cueWidth(full)-w));controlScoreDiff=max(controlScoreDiff,abs(maxComfort(full)-c))
 precondition(qualifies(full)==qualifies(fast),"Early exit decision drift")
 precondition(qualifies(full)==(row["accepted"] as! Bool),"Pilot classification drift")
 precondition(completeEndpoints(full,balls[own])==(row["completeEndpoints"] as! Bool),"Endpoint quality regression")
}
precondition(controlDiff<1e-10 && controlScoreDiff<1e-8,"Pilot metric drift")
try save(["passed":true,"cases":controls.count,"maxWidthDifference":controlDiff,"maxComfortDifference":controlScoreDiff],"controls-audit.json")
print("CONTROLS PASSED",controls.count);fflush(stdout)
let chunks=manifest["chunks"] as! [[String:Any]]
try FileManager.default.createDirectory(atPath:out+"/results",withIntermediateDirectories:true)
var totalBoards=0,totalEvaluations=0,totals=[String:Int](),mappingDiff=0.0
let algorithm=try Data(contentsOf:URL(fileURLWithPath:out+"/algorithm.json"));let fingerprint=digest(algorithm)
for (chunkIndex,chunk) in chunks.enumerated(){
 let file=chunk["file"] as! String,stem=URL(fileURLWithPath:file).deletingPathExtension().lastPathComponent
 let inputData=try Data(contentsOf:URL(fileURLWithPath:out+"/"+file));precondition(digest(inputData)==chunk["sha256"] as! String)
 let marker=out+"/results/"+stem+"-done.json"
 if FileManager.default.fileExists(atPath:marker){
  let done=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:marker))) as! [String:Any]
  precondition(done["fingerprint"] as! String==fingerprint && done["inputSHA256"] as! String==digest(inputData))
  for (name,h) in done["outputs"] as! [String:String]{let data=try Data(contentsOf:URL(fileURLWithPath:out+"/"+name));precondition(digest(data)==h)}
  for (k,v) in done["counts"] as! [String:Int]{totals[k,default:0]+=v}
  totalBoards+=done["boards"] as! Int;totalEvaluations+=done["evaluations"] as! Int
  continue
 }
 let boards=try JSONSerialization.jsonObject(with:inputData) as! [[String:Any]]
 precondition(boards.count==chunk["rows"] as! Int)
 var decisions=[[String:Any]](),accepted=[[String:Any]](),unresolved=[[String:Any]](),counts=[String:Int]()
 for row in boards {
  autoreleasepool {
   let cue=P(row["cue"] as! [Double]),balls=(row["positions"] as! [[Double]]).map{P($0)},points=[cue]+balls
   let ordinal=row["ordinal"] as! Int
   var invalid=false
   for (i,p) in points.enumerated(){
    if abs(p.x)>hx-rad+1e-6 || abs(p.z)>hz-rad+1e-6 || table.pockets.contains(where:{$0.containsCapture(p.scn)}){invalid=true}
    for q in points.dropFirst(i+1){if (p-q).length<2*rad-1e-6{invalid=true}}
   }
   for own in balls.indices {
    var ledger:[String:Any]=["ordinal":ordinal,"own":own]
    var status="invalid_placement"
    if !invalid {
     let others=balls.indices.filter{$0 != own}.map{balls[$0]}
     let fine=attack(cue,balls[own],others,step:0.01,early:true,preferred:own==0 ? row["originalPocket"] as? Int:nil)
     if fine["rejected"] != nil {
      status="rejected";ledger.merge(fine){_,new in new}
     } else {
      let w=cueWidth(fine),c=maxComfort(fine);ledger["width"]=w;ledger["comfort"]=c
      if w==0 {status="no_direct_window"}
      else if w<=1e-6 {status="subresolution_window"}
      else {
       let coarse=attack(cue,balls[own],others,step:0.02)
       let a=coarse["options"] as! [[String:Any]],b=fine["options"] as! [[String:Any]]
       let diff=zip(a,b).map{abs(($0["cueWidth"] as! Double)-($1["cueWidth"] as! Double))}.max() ?? 0
       mappingDiff=max(mappingDiff,diff)
       var record=row;record["own"]=own;record["ownAttack"]=fine;record["maxPocketComfort"]=c;record["mappingDifferenceDegrees"]=diff
       if diff>1e-7 || !qualifies(coarse) {status="unresolved_convergence";unresolved.append(record)}
       else if !completeEndpoints(fine,balls[own]) || !completeEndpoints(coarse,balls[own]) {status="unresolved_endpoint";unresolved.append(record)}
       else {status="accepted";accepted.append(record)}
      }
     }
    }
    ledger["status"]=status;counts[status,default:0]+=1;decisions.append(ledger)
   }
  }
 }
 precondition(decisions.count==chunk["evaluations"] as! Int)
 var outputHashes=[String:String]()
 for (suffix,records) in [("decisions",decisions),("accepted",accepted),("unresolved",unresolved)] {
  let name="results/"+stem+"-"+suffix+".json";try save(records,name)
  outputHashes[name]=digest(try Data(contentsOf:URL(fileURLWithPath:out+"/"+name)))
 }
 let done:[String:Any]=["fingerprint":fingerprint,"inputSHA256":digest(inputData),"boards":boards.count,"evaluations":decisions.count,"counts":counts,"outputs":outputHashes]
 try save(done,"results/"+stem+"-done.json")
 totalBoards+=boards.count;totalEvaluations+=decisions.count
 for (k,v) in counts{totals[k,default:0]+=v}
 let progress:[String:Any]=["chunksComplete":chunkIndex+1,"chunksTotal":chunks.count,"boards":totalBoards,"targetEvaluations":totalEvaluations,"counts":totals,"windowQueries":windowCalls,"seconds":Date().timeIntervalSince(begun)]
 try save(progress,"progress.json")
 print("CHUNK",chunkIndex+1,"/",chunks.count,stem,"evaluations",totalEvaluations,"accepted",totals["accepted",default:0],"seconds",Int(Date().timeIntervalSince(begun)));fflush(stdout)
 if cache.count>40000{cache.removeAll(keepingCapacity:true)}
}
precondition(totalBoards==manifest["boards"] as! Int && totalEvaluations==manifest["targetEvaluations"] as! Int)
try save(["pockets":(0..<6).map{geometries[$0]!},"radius":rad,"length":2*hx,"width":2*hz],"geometry.json")
try save(["complete":true,"boards":totalBoards,"targetEvaluations":totalEvaluations,"counts":totals,"chunks":chunks.count,"windowCoarseFineMax":windowDiff,"mappingCoarseFineMax":mappingDiff,"searchEdgeHits":edges,"windowQueries":windowCalls,"seconds":Date().timeIntervalSince(begun)],"summary.json")
