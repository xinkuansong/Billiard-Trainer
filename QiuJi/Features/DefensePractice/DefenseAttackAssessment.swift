import Foundation
import SceneKit
import CryptoKit

/// Per-evaluation state; concurrent question prefetch cannot share mutable caches.
struct DefenseAttackAssessment {
let widthLimit=0.008,comfortLimit=10.0
let rad=Double(AngleSceneCalculator.ballRadius), hx=Double(AngleSceneCalculator.innerLength)/2, hz=Double(AngleSceneCalculator.innerWidth)/2
let table=TableGeometry.chineseEightBallQiuJi(surfaceY:0)
var mainRails: [(P,P)] {
 table.linearCushions.filter { $0.soundSurface == .cushion }.map {
  (P(Double($0.start.x),Double($0.start.z)),P(Double($0.end.x),Double($0.end.z)))
 }
}
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

var cache=[String:[String:Any]](),geometries=[Int:[String:Any]](),windowDiff=0.0,edges=0,windowCalls=0
var incompleteComfort = false
// Bank qualification retains its exact scan; runtime scoring opts into the table.
var usePrecomputedWindows = false
var tableHits = 0
struct PipeRoute: Codable {
 let pocket: Int
 let leftDegrees, rightDegrees, comfort: Double
 let aim: [Double]
 var zeroWidthEstimate: Bool? = nil
 // Missing only in historical v4–v8 payloads; never invent a cut for those records.
 var cutDegrees: Double? = nil
 var tolerance: Double { rightDegrees-leftDegrees }
 var score: Double {
  if let cutDegrees { return DefenseEffect.value(pipeDegrees:tolerance,comfort:comfort,cutDegrees:cutDegrees)! }
  return sqrt(100 * (DefenseEffect.pipeReferenceDegrees / (DefenseEffect.pipeReferenceDegrees + tolerance)) * (100-comfort))
 }
}
/// Angle between cue-to-ghost travel and object-to-aim travel, in world XZ metres.
static func cutDegrees(cue:P, ball:P, aim:P) -> Double {
 let n=(aim-ball)*(1/(aim-ball).length), incoming=ball-n*Double(2*AngleSceneCalculator.ballRadius)-cue
 return atan2(abs(incoming.cross(n)),incoming.dot(n))*180/Double.pi
}
struct PipeResult {
 var routes = [PipeRoute]()
 var confirmedClosedPockets = Set<Int>()
 var best: PipeRoute? { routes.min { $0.score < $1.score } }
 var allPotContactsBlocked: Bool { confirmedClosedPockets.count == 6 && routes.isEmpty }
}
/// Runtime scoring: object-ball opening and comfort of a reachable aim in THAT
/// opening. No cue-angle width, speed search or physical strike perturbation.
mutating func pipeAttack(_ cue:P,_ ball:P,_ others:[P]) throws -> PipeResult {
 var result = PipeResult()
 for pocket in 0..<6 {
  try Task.checkCancellation()
  let w = window(ball,pocket), base = w["baseRadians"] as! Double
  let ranges = w["intervals"] as! [[String:Any]]
  let reachability = PipeReachability(cue:cue,ball:ball,obstacles:others,pocket:table.pockets[pocket],rails:mainRails)
  var closed = true
  func route(_ angle:Double, left:Double, right:Double, estimated:Bool = false) -> PipeRoute? {
   guard let end = reachability.reachableEnd(angle) else { return nil }
   guard let comfort = ShotComfortScore.evaluate(cue:(cue.x,cue.z),ball:(ball.x,ball.z),aim:(end.x,end.z)) else {
    incompleteComfort = true; return nil
   }
   return .init(pocket:pocket,leftDegrees:left,rightDegrees:right,comfort:comfort.total,aim:end.json,
       zeroWidthEstimate:estimated ? true:nil,cutDegrees:Self.cutDegrees(cue:cue,ball:ball,aim:end))
  }
  // A zero-width route still participates in the score. If the clean scan has
  // no positive window, use a reachable geometric opening candidate and label
  // the zero-angle estimate; this is not a physical pot-success guarantee.
  if ranges.isEmpty,
     let candidate = AngleSceneCalculator.dailyPocketCandidate(cue:cue.scn,target:ball.scn,
         targetKey:"target",pocketIndex:pocket,obstacles:others.map(\.scn),surfaceY:0),
     zeroWidthPathsClear(cue:cue,ball:ball,aim:P(Double(candidate.aim.x),Double(candidate.aim.z)),obstacles:others),
     let comfort = ShotComfortScore.evaluate(cue:(cue.x,cue.z),ball:(ball.x,ball.z),
         aim:(Double(candidate.aim.x),Double(candidate.aim.z))) {
   let angle = atan2(Double(candidate.aim.z)-ball.z,Double(candidate.aim.x)-ball.x)-base
   let offset = atan2(sin(angle),cos(angle))*180/Double.pi
   var route = PipeRoute(pocket:pocket,leftDegrees:offset,rightDegrees:offset,
       comfort:comfort.total,aim:[Double(candidate.aim.x),Double(candidate.aim.z)],
       cutDegrees:Self.cutDegrees(cue:cue,ball:ball,aim:P(Double(candidate.aim.x),Double(candidate.aim.z))))
   route.zeroWidthEstimate = true
   result.routes.append(route)
  }
  // Exactly tangent directions are not represented by a positive-width interval.
  for offset in w["isolatedDirections"] as? [Double] ?? [] {
   if let candidate = route(base+offset*Double.pi/180,left:offset,right:offset) {
    result.routes.append(candidate)
   }
  }
  for range in ranges {
   let left = range["leftDegrees"] as! Double, right = range["rightDegrees"] as! Double
   guard right>left else { continue }
   let count = max(2,Int(ceil((right-left)/0.01)))
   var best: PipeRoute?
   for i in 0...count {
    let angle = base+(left+(right-left)*Double(i)/Double(count))*Double.pi/180
    if let candidate = route(angle,left:left,right:right), best == nil || candidate.score<best!.score {
     best = candidate
    }
   }
   if best == nil {
    // Missing grid samples are NOT proof of blocking. Cover the entire closed
    // interval, including both limits, or find a narrower reachable witness.
    switch try reachability.search((base+left*Double.pi/180)...(base+right*Double.pi/180)) {
    case .reachable(let angle): best = route(angle,left:left,right:right); closed = false
    case .blocked: break
    case .unresolved: closed = false
    }
   }
   if let best { result.routes.append(best) }
  }
  if !result.routes.contains(where: { $0.pocket == pocket }) {
   // With no positive window, absence of a preferred aiming candidate is not
   // evidence. Use a conservative envelope of the ENTIRE capture opening.
   // It may include jaw-invalid directions; failing to close it stays unknown.
   if ranges.isEmpty || !(w["isolatedDirections"] as? [Double] ?? []).isEmpty {
    if let envelope = reachability.captureEnvelope,
       case .blocked = try reachability.search(envelope) {} else { closed = false }
   }
   if closed { result.confirmedClosedPockets.insert(pocket) }
  }
 }
 return result
}

// The geometric fallback uses the SAME 2R ball clearance as positive windows;
// the recommendation helper's looser epsilon cannot admit an intruding ball.
private func zeroWidthPathsClear(cue:P,ball:P,aim:P,obstacles:[P]) -> Bool {
 let delta=aim-ball
 guard delta.length>0 else { return false }
 let ghost=ball-delta*(2*rad/delta.length)
 return !obstacles.contains { dist($0,cue,ghost)<2*rad || dist($0,ball,aim)<2*rad }
}

/// Fallback opportunity estimate, NOT a clean-window / physical pot certificate.
/// Retains both ball-clearance checks, but permits directions in the capture
/// envelope that the jaw/window model could not classify. No confirmed window
/// means 0 degrees, matching the user-approved zero-window scoring contract.
func estimatedAttack(_ cue:P,_ ball:P,_ others:[P]) throws -> PipeRoute? {
 var best:PipeRoute?
 for pocket in 0..<6 {
  try Task.checkCancellation()
  let reach=PipeReachability(cue:cue,ball:ball,obstacles:others,pocket:table.pockets[pocket],rails:mainRails)
  guard let envelope=reach.captureEnvelope else { continue }
  let count=max(2,min(3600,Int(ceil((envelope.upperBound-envelope.lowerBound)*180/Double.pi/0.1))))
  var angles=(0...count).map { envelope.lowerBound+(envelope.upperBound-envelope.lowerBound)*Double($0)/Double(count) }
  // A witness found by continuous subdivision must not be lost by this grid.
  if case .reachable(let angle)=try reach.search(envelope) { angles.append(angle) }
  let w=cache["\(ball.x),\(ball.z),\(pocket)"],base=w?["baseRadians"] as? Double ?? 0
  let ranges=w?["intervals"] as? [[String:Any]] ?? []
  for angle in angles {
   guard let end=reach.reachableEnd(angle),
         let comfort=ShotComfortScore.evaluate(cue:(cue.x,cue.z),ball:(ball.x,ball.z),aim:(end.x,end.z)) else { continue }
   let offset=atan2(sin(angle-base),cos(angle-base))*180/Double.pi
   let interval=ranges.first { offset>=($0["leftDegrees"] as! Double) && offset<=($0["rightDegrees"] as! Double) }
   let left=interval?["leftDegrees"] as? Double ?? offset,right=interval?["rightDegrees"] as? Double ?? offset
   let candidate=PipeRoute(pocket:pocket,leftDegrees:left,rightDegrees:right,comfort:comfort.total,aim:end.json,
       zeroWidthEstimate:interval == nil ? true:nil,cutDegrees:Self.cutDegrees(cue:cue,ball:ball,aim:end))
   if best == nil || candidate.score<best!.score { best=candidate }
  }
 }
 return best
}

/// Ball-width paths in world XZ metres. A branch is discarded only when a
/// distance bound proves EVERY direction in it invalid. Endpoints alone and
/// an exhausted sampling budget never establish full defensive marks.
struct PipeReachability {
 let cue, ball: P
 let obstacles: [P]
 let pocket: Pocket
 var rails: [(P,P)] = []
 let radius = Double(AngleSceneCalculator.ballRadius)
 var diameter: Double { 2*radius }
 var halfX: Double { Double(AngleSceneCalculator.innerLength)/2-radius+1e-7 }
 var halfZ: Double { Double(AngleSceneCalculator.innerWidth)/2-radius+1e-7 }
 var center: P { P(Double(pocket.center.x),Double(pocket.center.z)) }
 var lip: [P] { pocket.captureLip.map { P($0.x,$0.y) } }
 // Capture entry is Float; keep its roundoff outside any blocking proof.
 var roundoff: Double { 8*Double(Float.ulpOfOne)*max(1,cue.length,ball.length,center.length) }
 enum SearchResult {
  case reachable(Double), blocked, unresolved
 }
 static func distance(_ point:P, _ a:P, _ b:P) -> Double {
  let v=b-a, denominator=v.dot(v)
  let t=denominator>0 ? max(0,min(1,(point-a).dot(v)/denominator)):0
  return (point-(a+v*t)).length
 }
 static func segmentDistance(_ a:P,_ b:P,_ c:P,_ d:P) -> Double {
  let u=b-a,v=d-c,denominator=u.cross(v)
  if denominator != 0 {
   let t=(c-a).cross(v)/denominator,s=(c-a).cross(u)/denominator
   if (0...1).contains(t) && (0...1).contains(s) { return 0 }
  }
  return min(distance(a,c,d),distance(b,c,d),distance(c,a,b),distance(d,a,b))
 }
 func reachableEnd(_ angle:Double) -> P? {
  let n=P(cos(angle),sin(angle)), ghost=ball-n*diameter
  guard (ghost-cue).dot(n)>1e-12,abs(ghost.x)<=halfX,abs(ghost.z)<=halfZ,
        let travel=pocket.entryTime(position:ball.scn,velocity:n.scn,
            acceleration:SCNVector3Zero,maxTime:4) else { return nil }
  let end=ball+n*Double(travel)
  guard !obstacles.contains(where: {
   Self.distance($0,cue,ghost)<diameter || Self.distance($0,ball,end)<diameter
  }), !rails.contains(where: {
   Self.segmentDistance(cue,ghost,$0.0,$0.1)<radius || Self.segmentDistance(ball,end,$0.0,$0.1)<radius
  }) else { return nil }
  return end
 }
 /// Superset of all directions hitting the deep circle OR exposed capture lip.
 /// Used only to PROVE closure when the clean-window model has no interval.
 var captureEnvelope: ClosedRange<Double>? {
  let delta=center-ball, d=delta.length, r=Double(pocket.radius)
  guard d>r, !pocket.containsLip(ball.scn) else { return nil }
  let base=atan2(delta.z,delta.x), half=asin(r/d)
  var lo = -half, hi = half
  for vertex in lip {
   let v=vertex-ball, a=atan2(v.z,v.x)-base, offset=atan2(sin(a),cos(a))
   lo=min(lo,offset);hi=max(hi,offset)
  }
  guard hi-lo<Double.pi else { return nil }
  // Expand outwards rather than accidentally omitting a tangent limit.
  return (base+lo-1e-10)...(base+hi+1e-10)
 }
 /// Common prefix before ANY capture point, using support bounds of the circle
 /// and lip. Never extend a blocker check past the earliest possible pocket entry.
 private func capturePrefix(_ n:P, chord:Double) -> Double {
  let delta=center-ball
  var lower=delta.dot(n)-Double(pocket.radius)-delta.length*chord
  if !lip.isEmpty {
   let lipLower=lip.map { v -> Double in
    let delta=v-ball;return delta.dot(n)-delta.length*chord
   }.min()!
   lower=min(lower,lipLower)
  }
  return max(0,lower-roundoff)
 }
 func provesClosed(_ range:ClosedRange<Double>) -> Bool {
  let mid=(range.lowerBound+range.upperBound)/2
  let half=(range.upperBound-range.lowerBound)/2
  guard half>=0,half<=Double.pi else { return false }
  let n=P(cos(mid),sin(mid)), chord=2*sin(half/2), motion=diameter*chord
  let ghost=ball-n*diameter, incoming=ball-cue, epsilon=roundoff
  if incoming.dot(n)-diameter+incoming.length*chord < -epsilon { return true }
  if abs(ghost.x)-motion>halfX+epsilon || abs(ghost.z)-motion>halfZ+epsilon { return true }
  let prefix=capturePrefix(n,chord:chord), end=ball+n*prefix
  for blocker in obstacles {
   // Segment Hausdorff displacement is bounded by its moving endpoint.
   if Self.distance(blocker,cue,ghost)+motion<diameter-epsilon { return true }
   if Self.distance(blocker,ball,end)+prefix*chord<diameter-epsilon { return true }
  }
  for rail in rails {
   if Self.segmentDistance(cue,ghost,rail.0,rail.1)+motion<radius-epsilon { return true }
   if Self.segmentDistance(ball,end,rail.0,rail.1)+prefix*chord<radius-epsilon { return true }
  }
  return false
 }
 func search(_ range:ClosedRange<Double>, maxNodes:Int = 8192) throws -> SearchResult {
  guard range.lowerBound.isFinite,range.upperBound.isFinite,maxNodes>0 else { return .unresolved }
  for angle in [range.lowerBound,range.upperBound] where reachableEnd(angle) != nil { return .reachable(angle) }
  var stack=[(range,0)], visited=0, unresolved=false
  while let (interval,depth)=stack.popLast() {
   try Task.checkCancellation()
   visited += 1
   guard visited<=maxNodes else { return .unresolved }
   if provesClosed(interval) { continue }
   let mid=(interval.lowerBound+interval.upperBound)/2
   if reachableEnd(mid) != nil { return .reachable(mid) }
   guard depth<40,mid>interval.lowerBound,mid<interval.upperBound else {
    unresolved=true;continue
   }
   stack.append((mid...interval.upperBound,depth+1))
   stack.append((interval.lowerBound...mid,depth+1))
  }
  return unresolved ? .unresolved:.blocked
 }
}
mutating func window(_ b:P,_ p:Int)->[String:Any]{
 let key="\(b.x),\(b.z),\(p)";if let v=cache[key]{return v}
 if usePrecomputedWindows, let w = DefensePipeTable.shared?.window(b.scn, pocket: p) {
  cache[key] = w; tableHits += 1; return w
 }
 var a=AngleSceneCalculator.defenseCleanWindow(b.scn,pocketIndex:p,stepDegrees:0.05)
 var w=AngleSceneCalculator.defenseCleanWindow(b.scn,pocketIndex:p,stepDegrees:0.025)
 func width(_ v:[String:Any])->Double{(v["intervals"] as! [[String:Any]]).map{$0["widthDegrees"] as! Double}.max() ?? 0}
 if abs(width(a)-width(w))>0.001 {a=AngleSceneCalculator.defenseCleanWindow(b.scn,pocketIndex:p,stepDegrees:0.005);w=AngleSceneCalculator.defenseCleanWindow(b.scn,pocketIndex:p,stepDegrees:0.0025)}
 windowDiff=max(windowDiff,abs(width(a)-width(w)));if (w["edgeStates"] as! [Bool]).contains(true){edges+=1}
 if (w["edgeStates"] as! [Bool]).contains(true) { w["intervals"] = [[String:Any]]() }
 if geometries[p]==nil {geometries[p]=w["geometry"] as? [String:Any]}
 w.removeValue(forKey:"geometry");cache[key]=w;windowCalls+=1;return w
}
mutating func attack(_ cue:P,_ ball:P,_ others:[P],step:Double,early:Bool=false,preferred:Int?=nil)->[String:Any]{
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
   guard let comfort=ShotComfortScore.evaluate(cue:(cue.x,cue.z),ball:(ball.x,ball.z),aim:(s.2.x,s.2.z)) else { incompleteComfort = true; continue }
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


func cornerWitnesses(_ c:P,_ t:P,_ others:[P],_ a:[String:Any])->[Int]{
 let options=a["options"] as! [[String:Any]],selected=(a["best"] as! [String:Any])["pocket"] as! Int
 let sa=P([Double(table.pockets[selected].center.x),Double(table.pockets[selected].center.z)])
 let sd=(sa-t).length,sn=(sa-t)*(1/sd),sg=t-sn*(2*rad),scut=angleWidth(sg-c,sn)
 var found=[Int]()
 for i in 0..<4 where i != selected && (options[i]["cueWidth"] as! Double)==0 {
  let aim=P([Double(table.pockets[i].center.x),Double(table.pockets[i].center.z)]),d=(aim-t).length,n=(aim-t)*(1/d),g=t-n*(2*rad)
  if abs(g.x)>hx-rad || abs(g.z)>hz-rad{continue}
  if others.contains(where:{dist($0,c,g)<2*rad || dist($0,t,aim)<2*rad}){continue}
  if let s=ShotComfortScore.evaluate(cue:(c.x,c.z),ball:(t.x,t.z),aim:(aim.x,aim.z)),s.total>maxComfort(a),d<sd,angleWidth(g-c,n)<scut{found.append(i)}
 };return found
}

}

/// Historical v3 payload only. Runtime scoring never probes cue-angle tolerance.
enum DefensePhysicalAttack {
    struct Route: Codable {
        let pocket: Int
        let speed: Float
        let direction, aim: [Float]
        let leftDegrees, rightDegrees, tolerance, comfort: Double
        var score: Double { sqrt(100 * (0.008 / (0.008 + tolerance)) * (100 - comfort)) }
    }
}
