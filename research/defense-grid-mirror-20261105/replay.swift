import Foundation
import SceneKit
let out=URL(fileURLWithPath:CommandLine.arguments[1])
func read(_ name:String)throws->Data {try Data(contentsOf:out.appendingPathComponent(name))}
func save(_ name:String,_ x:Any)throws {try JSONSerialization.data(withJSONObject:x,options:[.sortedKeys]).write(to:out.appendingPathComponent(name),options:.atomic)}
struct Mirror:Decodable {let newID:String;let sx,sz:Int}
let meta=try JSONDecoder().decode([Mirror].self,from:read("mirror-and-dedup-ledger.json"))
let mirrors=Dictionary(uniqueKeysWithValues:meta.map{($0.newID,$0)})
let qs=try JSONDecoder().decode([DefenseBankQuestion].self,from:read("trajectory-candidate.json"))
func require(_ okay:Bool,_ message:String="Invariant failed") {if !okay {print("FAIL: \(message)");fflush(stdout);exit(1)}}
let table=TableGeometry.chineseEightBallQiuJi(surfaceY:0.8)
func point(_ p:SCNVector3)->[Double] {[Double(p.x),Double(p.z)]}
try save("native-geometry.json",["linear":table.linearCushions.map{["start":point($0.start),"end":point($0.end),"normal":point($0.normal)]},"circular":table.circularCushions.map{["center":point($0.center),"radius":Double($0.radius),"startAngle":Double($0.startAngle),"endAngle":Double($0.endAngle)]},"pockets":table.pockets.map{point($0.center)}])
func dist(_ a:SCNVector3,_ b:SCNVector3)->Double {hypot(Double(a.x-b.x),Double(a.z-b.z))}
var maps=[String:[String:[Int]]]();var maximumMapError=0.0
for (sx,sz) in [(1,1),(-1,1),(1,-1),(-1,-1)] {
 func mirror(_ p:SCNVector3)->SCNVector3 {.init(p.x*Float(sx),p.y,p.z*Float(sz))}
 var rails=[Int]()
 for (sourceIndex,line) in table.linearCushions.enumerated() {
  let a=mirror(line.start),b=mirror(line.end)
  let errors=table.linearCushions.map{max(dist(mirror(line.normal),$0.normal),min(max(dist(a,$0.start),dist(b,$0.end)),max(dist(a,$0.end),dist(b,$0.start))))}
  // CAD includes coincident jaw and twin-wall surfaces. Preserve each
  // occurrence's identity rather than mapping both to the first endpoint match.
  let candidates=errors.indices.filter{errors[$0]<0.000002}
  let originals=table.linearCushions.indices.filter { j in
   let other=table.linearCushions[j]
   return max(dist(line.normal,other.normal),min(max(dist(line.start,other.start),dist(line.end,other.end)),max(dist(line.start,other.end),dist(line.end,other.start))))<0.000002
  }
  require(candidates.count==originals.count && !candidates.isEmpty,"Linear surface multiplicity mismatch")
  let idx=candidates[originals.firstIndex(of:sourceIndex)!]
  require(errors[idx]<0.000002,"Non-symmetric linear geometry")
  maximumMapError=max(maximumMapError,errors[idx]);rails.append(idx)
 }
 for arc in table.circularCushions {
  let center=mirror(arc.center)
  func sample(_ a:Float)->SCNVector3 {.init(arc.center.x+arc.radius*cos(a),arc.center.y,arc.center.z+arc.radius*sin(a))}
  let a=mirror(sample(arc.startAngle)),b=mirror(sample(arc.endAngle))
  let errors=table.circularCushions.map { other -> Double in
   func pt(_ angle:Float)->SCNVector3 {.init(other.center.x+other.radius*cos(angle),other.center.y,other.center.z+other.radius*sin(angle))}
   return max(dist(center,other.center),min(max(dist(a,pt(other.startAngle)),dist(b,pt(other.endAngle))),max(dist(a,pt(other.endAngle)),dist(b,pt(other.startAngle)))))
  }
  let idx=errors.indices.min{errors[$0]<errors[$1]}!
  require(errors[idx]<0.000002,"Non-symmetric circular geometry")
  maximumMapError=max(maximumMapError,errors[idx]);rails.append(table.linearCushions.count+idx)
 }
 let pockets=table.pockets.map{p -> Int in
  let errors=table.pockets.map{dist(mirror(p.center),$0.center)}
  let idx=errors.indices.min{errors[$0]<errors[$1]}!;require(errors[idx]<0.000002);return idx
 }
 try save("map-diagnostic.json",["sx":sx,"sz":sz,"rails":rails,"pockets":pockets])
 require(Set(rails).count==rails.count && rails.indices.allSatisfy{rails[rails[$0]] == $0},"Rail map not bijective/self inverse")
 require(pockets.indices.allSatisfy{pockets[pockets[$0]] == $0})
 maps["\(sx),\(sz)"]=["rails":rails,"pockets":pockets]
}
try save("geometry-maps.json",maps)
var failures=[[String:Any]]();var done=0;var maxEndError=0.0;let start=ProcessInfo.processInfo.systemUptime
func number(_ name:String)->Int {name==ShotInput.cueBallName ? 0:Int(name.dropFirst())!}
for (qi,q) in qs.enumerated() {
 let m=mirrors[q.id]!,mapping=maps["\(m.sx),\(m.sz)"]!
 let surface:Float=0.8
 func v(_ a:[Double])->SCNVector3 {.init(Float(a[0]),surface+BallPhysics.radius,Float(a[1]))}
 for r in q.references {
  let s=r.parameters,d=SCNVector3(Float(s.direction[0]),0,Float(s.direction[1]))
  let p=ShotPredictor.simulateFree(cueBall:v(q.cue),aimDir:d,velocity:Float(s.velocity),spinX:Float(s.spinX),spinY:Float(s.spinY),surfaceY:surface,
   balls:q.balls.map{.init(name:"_\($0.number)",position:v($0.position))},maxEvents:1500,maxTime:60,includePresentation:false,simulationModel:.appDefault,recordedStrikeDirection:d)
  var reasons=[String]();var endError=0.0
  if !p.hasFinalTableState {reasons.append("incomplete")}
  if let failure=DefenseEffect.failure(q,p) {reasons.append(failure)}
  let potted=Set(p.pocketedBalls.map(number))
  if potted != Set(r.expected.pocketedBallNumbers) {reasons.append("potted")}
  if p.events.count != r.expected.events.count {reasons.append("event-count")}
  else {
   for (a,b) in zip(p.events,r.expected.events) {
    var matches=false
    switch a.kind {
    case let .ballBall(x,y):matches=b.kind=="ballBall" && Set([number(x),number(y)])==Set(b.ballNumbers)
    case let .ballCushion(x):matches=b.kind=="cushion" && [number(x)]==b.ballNumbers && b.railIndex.map{mapping["rails"]![$0]}==a.cushionIndex
    case let .pocket(x,id):matches=b.kind=="pocket" && [number(x)]==b.ballNumbers && b.pocketIndex.map{mapping["pockets"]![$0]}==Int(id.replacingOccurrences(of:"pocket_",with:""))
    }
    if !matches {reasons.append("event-identity");break}
   }
  }
  for b in r.expected.finalBalls where !potted.contains(b.number) {
   if let actual=p.finalPositions[b.number==0 ? ShotInput.cueBallName:"_\(b.number)"] {endError=max(endError,dist(actual,v(b.position)))}
   else {reasons.append("missing-final-ball")}
  }
  if endError>0.002 {reasons.append("final-position")}
  var touched=false,bounced=false;var railCounts=[String:Int]()
  for e in p.events {
   switch e.kind {
   case let .ballBall(a,b):if Set([number(a),number(b)])==Set([0,q.ownBallNumber]) {if touched && bounced {reasons.append("forbidden-recontact")};touched=true}
   case let .ballCushion(ball):if let i=e.cushionIndex,(0..<6).contains(i) {railCounts[ball,default:0]+=1;if touched && number(ball)==q.ownBallNumber {bounced=true}}
   default:break
   }
  }
  if railCounts.values.contains(where:{$0>1}) || railCounts.values.reduce(0,+)>2 {reasons.append("rail-limit")}
  maxEndError=max(maxEndError,endError);done+=1
  if !reasons.isEmpty {failures.append(["questionID":q.id,"referenceID":r.id,"reasons":reasons,"finalError":endError,"mirror":[m.sx,m.sz]])}
 }
 if qi%100==0 {try save("replay-progress.json",["questions":qi+1,"total":qs.count,"references":done,"failures":failures.count,"seconds":ProcessInfo.processInfo.systemUptime-start]);print("REPLAY \(qi+1)/\(qs.count) refs=\(done) failures=\(failures.count)");fflush(stdout)}
}
try save("replay-results.json",["passed":failures.isEmpty,"questions":qs.count,"references":done,"failures":failures,"maxFinalError":maxEndError,"geometryMapError":maximumMapError,"seconds":ProcessInfo.processInfo.systemUptime-start])
print("REPLAY COMPLETE \(done) refs, \(failures.count) failures, max end error \(maxEndError)")
