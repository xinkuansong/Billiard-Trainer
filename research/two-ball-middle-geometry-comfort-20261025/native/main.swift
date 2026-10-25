import Foundation
import SceneKit
func emit(_ name:String,_ value:Any)throws {let d=try JSONSerialization.data(withJSONObject:value);FileHandle.standardOutput.write(Data((name+"\t"+String(data:d,encoding:.utf8)!+"\n").utf8))}
try emit("READY",["pid":ProcessInfo.processInfo.processIdentifier])
while let line=readLine() {
 do {try autoreleasepool {
 let input=try JSONSerialization.jsonObject(with:Data(line.utf8)) as! [[String:Any]]
 var output:[[String:Any]]=[]
 for q in input {try autoreleasepool {
 let b=q["object"] as! [Double],pocket=q["pocket"] as! Int,y=BTTablePhysics.surfaceY,r=BallPhysics.radius
 let start=SCNVector3(Float(b[0]),y+r,Float(b[1])),anchor=SCNVector3(0,y+r,(pocket==4 ? -1:1)*TablePhysics.innerWidth/2),direction=(anchor-start).normalized()
 var lo:Float=0.5,hi:Float=8,trials:[[String:Any]]=[],passed=false
 for _ in 0..<5 {
 let speed=(lo+hi)/2
 // The sole moving ball represents B; cueBallName is only the engine's name.
 // No cue ball, strike-access test or scratch gate exists in this experiment.
 let p=ShotPredictor.simulateFree(cueBall:start,aimDir:direction,velocity:speed,spinX:0,spinY:0,surfaceY:y,balls:[],recordedStrikeDirection:direction)
 var route="missed",valid=true,events:[[String:Any]]=[]
 for e in p.events {
 switch e.kind {
 case let .ballCushion(ball):
  events.append(["kind":"cushion","ball":ball,"index":e.cushionIndex as Any? ?? NSNull(),"time":Double(e.time)])
  if let i=e.cushionIndex {if i<6 || AccuracyShotJudgement.mouthOwner(cushionIndex:i) != pocket {valid=false}} else {valid=false}
 case let .pocket(ball,id):events.append(["kind":"pocket","ball":ball,"pocket":id,"time":Double(e.time)]);route=(id=="pocket_\(pocket)" && valid) ? "direct-pot":"wrong-pocket-or-bank"
 case .ballBall:valid=false
 }
 }
 passed=route=="direct-pot" && p.hasFinalTableState
 var minimum=Float.greatestFiniteMagnitude,maximum:Float=0
 for i in p.cuePath.indices {
 let pt=SCNVector3(p.cuePath[i].x,y+r,p.cuePath[i].z);minimum=min(minimum,(pt-anchor).length());maximum=max(maximum,(pt-start).dot(direction))
 if i>0 {let a=SCNVector3(p.cuePath[i-1].x,y+r,p.cuePath[i-1].z),d=pt-a,ll=d.dot(d);if ll>0 {minimum=min(minimum,(a+d*max(0,min(1,(anchor-a).dot(d)/ll))-anchor).length())}}
 }
 var feedback="pot"
 if !passed {if !p.hasFinalTableState {feedback="incomplete"} else if p.cuePocketed || minimum<=2*r || p.events.contains(where:{if case .ballCushion=$0.kind{return true};return false}) || maximum>=(anchor-start).length() {feedback="probe-lower";hi=speed} else {feedback="short-increase";lo=speed}}
 trials.append(["speed":Double(speed),"passed":passed,"route":route,"settled":p.hasFinalTableState,"feedback":feedback,"events":events])
 if passed || !p.hasFinalTableState {break}
 }
 output.append(["key":q["key"]!,"passed":passed,"object":b,"pocket":pocket,"trials":trials])
 }}
 try emit("RESULT",output)
 }} catch {try emit("ERROR",["error":String(describing:error)]);exit(1)}
}
