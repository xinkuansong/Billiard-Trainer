import Foundation
import SceneKit
import Darwin
// Research entry only. Explicit parameters; no production source mutation.
func emit(_ tag:String,_ value:Any) throws {
 let data=try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys])
 FileHandle.standardOutput.write(Data((tag+"\t"+String(decoding:data,as:UTF8.self)+"\n").utf8))
}
func xy(_ p:SCNVector3)->[Double] {[Double(p.x),Double(p.z)]}
let surface=BTTablePhysics.surfaceY, radius=BallPhysics.radius
let profile=AccuracyTipSelector.renderedProfile()
func point(_ a:[Double])->SCNVector3 {SCNVector3(Float(a[0]),surface+radius,Float(a[1]))}
func run(_ q:[String:Any])->[String:Any] {
 if q["command"] as? String == "middle_regions" {
  let pts=q["points"] as! [[Double]]
  return ["calibrated":MiddlePocketRegion.production != nil, "version":MiddlePocketRegion.production?.version ?? "unavailable", "allowed":pts.map { a in (0..<6).map { p in p<4 || MiddlePocketRegion.assess(target:point(a),pocket:p,calibration:MiddlePocketRegion.production) == .inside }}]
 }
 if q["command"] as? String == "legal" {
  let pts=q["points"] as! [[Double]]
  return ["legal":pts.map { a -> Bool in
   let p=point(a), clamped=AngleSceneCalculator.clampAwayFromPockets(p,surfaceY:surface)
   return abs(p.x)<=TablePhysics.innerLength/2-radius && abs(p.z)<=TablePhysics.innerWidth/2-radius && (clamped-p).length()<=0.000001
  }]
 }
 let cue=point(q["cue"] as! [Double]), target=point(q["object"] as! [Double]), anchor=point(q["aim"] as! [Double])
 let pocket=q["pocket"] as! Int, v=Float(q["v"] as! Double), sx=Float(q["sx"] as! Double), sy=Float(q["sy"] as! Double)
 let obstacles=(q["obstacles"] as? [[Double]] ?? []).map(point)
 var out:[String:Any]=["id":q["id"]!,"v":Double(v),"sx":Double(sx),"sy":Double(sy),"success":false]
 if q["enforceMiddle"] as? Bool == true && pocket>=4 {
  guard MiddlePocketRegion.assess(target:target,pocket:pocket,calibration:MiddlePocketRegion.production) == .inside else {out["reason"]="outside_middle_region";return out}
 }
 let dir:SCNVector3
 if let d=q["dir"] as? [Double] {dir=SCNVector3(Float(d[0]),0,Float(d[1]))}
 else {
  let input=ShotInput(cueBall:cue,targetBall:target,pocketIndex:pocket,velocity:v,spinX:sx,spinY:sy,surfaceY:surface,pocketAimOverride:anchor)
  var seed=ShotPrediction()
  guard let ctx=ShotPredictor.prepareAim(input,into:&seed) else {out["reason"]="aim_unavailable";return out}
  let offset=ShotPredictor.positionAimOffset(input:input,context:ctx)
  dir=ctx.aimDir.rotatedY(offset)
 }
 out["dir"]=xy(dir)
 let access=CueStrikeAccess(cue:cue,aim:dir,obstacles:[target]+obstacles,surfaceY:surface,profile:profile)
 guard v>=0.5 && v<=4.5 && sx*sx+sy*sy<=0.250001,
       access.isAvailable(spinX:Double(sx),spinY:Double(sy)),
       let pose=access.resolvedPose(spinX:Double(sx),spinY:Double(sy)) else {out["reason"]="stroke_inaccessible";return out}
 out["accessElevation"]=Double(pose.elevation)
 var balls=[ObstacleBall(name:ShotInput.targetBallName,position:target)]
 for (i,p) in obstacles.enumerated() {balls.append(.init(name:"obstacle\(i)",position:p))}
 let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:dir,velocity:v,spinX:sx,spinY:sy,surfaceY:surface,balls:balls,maxEvents:1500,maxTime:60,recordedStrikeDirection:dir)
 var targetPocket:String?=nil, foreign=false, contacted=false, rails:[Int]=[], jaw=false
 var events:[[String:Any]]=[]
 for e in p.events {
  var ev:[String:Any]=["time":Double(e.time)]
  switch e.kind {
  case let .ballBall(a,b):
   ev["kind"]="ball";ev["balls"]=[a,b]
   if a.hasPrefix("obstacle") || b.hasPrefix("obstacle") {foreign=true}
   if Set([a,b])==Set([ShotInput.cueBallName,ShotInput.targetBallName]) {contacted=true}
  case let .ballCushion(b):
   ev["kind"]="cushion";ev["ball"]=b;ev["rail"]=e.cushionIndex ?? -1
   if b==ShotInput.cueBallName {
    if let i=e.cushionIndex,(0..<6).contains(i) {if contacted {rails.append(i)}} else {jaw=true}
   }
  case let .pocket(b,id):
   ev["kind"]="pocket";ev["ball"]=b;ev["pocket"]=id
   if b==ShotInput.targetBallName {targetPocket=id}
   if b.hasPrefix("obstacle") {foreign=true}
  }
  events.append(ev)
 }
 let first=p.recorder?.firstBallContacts[ShotInput.cueBallName]?.other.name
 var reasons:[String]=[]
 if !p.hasFinalTableState {reasons.append("incomplete")}
 if p.pocketedBalls.contains(ShotInput.cueBallName) {reasons.append("scratch")}
 if first != ShotInput.targetBallName {reasons.append("wrong_first_contact")}
 if targetPocket != "pocket_\(pocket)" {reasons.append("target_miss")}
 if foreign {reasons.append("disturbed_remaining_ball")}
 if jaw {reasons.append("cue_jaw")}
 for (i,o) in obstacles.enumerated() {
  guard let end=p.finalPositions["obstacle\(i)"],(end-o).length()<=0.000001 else {reasons.append("remaining_ball_moved");continue}
 }
 out["success"]=reasons.isEmpty;out["reasons"]=reasons;out["reason"]=reasons.first ?? "success"
 out["settled"]=p.hasFinalTableState;out["termination"]=String(describing:p.termination)
 out["duration"]=Double(p.duration);out["rails"]=rails;out["events"]=events;out["pocketed"]=p.pocketedBalls
 out["finals"]=p.finalPositions.mapValues(xy);out["firstContact"]=first ?? "none"
 if let stop=p.finalPositions[ShotInput.cueBallName] {out["stop"]=xy(stop)}
 if reasons.isEmpty && (q["paths"] as? Bool ?? true) {
  out["cuePath"]=p.cuePath.map(xy)
  out["targetPath"]=(p.extraBallPaths[ShotInput.targetBallName] ?? []).map(xy)
  // Diagram evidence ends at the physical pocket entry, excluding below-table collection motion.
  if let rec=p.recorder {
   let playback=TrajectoryPlayback(recorder:rec,surfaceY:surface+radius)
   var paths:[String:[[Double]]]=[:]
   for name in [ShotInput.cueBallName,ShotInput.targetBallName] {
    let entry=rec.pocketEntries.first(where:{$0.ball.name==name})
    let end=entry?.time ?? rec.duration
    var times=Set<Float>([0,end]);let n=Int(ceil(Double(end)*120))
    for i in 0...n {times.insert(min(end,Float(i)/120))}
    for frame in rec.framesByBallName[name] ?? [] where frame.time<=end {times.insert(frame.time)}
    paths[name]=times.sorted().compactMap { t in
     if let entry, t==end {return [Double(t),Double(entry.ball.position.x),Double(entry.ball.position.z)]}
     guard let state=playback.stateAt(ballName:name,time:t) else {return nil}
     return [Double(t),Double(state.position.x),Double(state.position.z)]
    }
   }
   out["physicalPaths"]=paths
  }

 }
 return out
}
try emit("READY",["pid":ProcessInfo.processInfo.processIdentifier,"length":Double(TablePhysics.innerLength),"width":Double(TablePhysics.innerWidth),"radius":Double(radius),"surface":Double(surface)])
while let line=readLine() {
 do {
  try autoreleasepool {
   let q=try JSONSerialization.jsonObject(with:Data(line.utf8)) as! [String:Any]
   try emit("RESULT",run(q))
  }
 } catch {try emit("ERROR",["error":String(describing:error)]);exit(1)}
}
