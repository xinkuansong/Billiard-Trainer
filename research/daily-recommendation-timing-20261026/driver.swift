func comfort(cue:SCNVector3,target:SCNVector3,aim:SCNVector3,angle:Double)->Double {
 let x=Double(target.x),z=Double(target.z),cx=Double(cue.x),cz=Double(cue.z)
 let hx=Double(AngleSceneCalculator.innerLength)/2,hz=Double(AngleSceneCalculator.innerWidth)/2,r=Double(AngleSceneCalculator.ballRadius)
 let length=hypot(Double(aim.x)-x,Double(aim.z)-z)
 guard length>0.0001 else{return 0}
 let nx=(Double(aim.x)-x)/length,nz=(Double(aim.z)-z)/length
 let depth=max(0,zip([x,z],zip([-nx,-nz],[hx-r,hz-r])).compactMap{pos,axis ->Double? in
  let (direction,bound)=axis;guard abs(direction)>1e-12 else{return nil};return ((direction>0 ? bound : -bound)-pos)/direction
 }.min() ?? 0)
 let scale=min(1,max(0.4,depth/0.9)),lo=0.5*scale,hi=0.8*scale,d=hypot(cx-x,cz-z)
 let near=max(lo-d,0)/(0.8*lo),far=max(d-hi,0)/0.75,D=100*exp(-near*near-far*far)
 let vx=x-2*r*nx-cx,vz=z-2*r*nz-cz,norm=hypot(vx,vz)
 guard norm>1e-9 else{return 0}
 let bx = -vx/norm,bz = -vz/norm
 let gaps=[hx-cx-r,hx+cx-r,hz-cz-r,hz+cz-r],directions=[bx,-bx,bz,-bz]
 let penalties=zip(gaps,directions).map { gap,direction -> Double in
  let t=max(direction,0);return (45+15*t*t)*exp(-pow(max(gap,0)*100/8,1.2))
 }
 let main=penalties.indices.max(by:{penalties[$0]<penalties[$1]}) ?? 0
 let adj=main<2 ? max(penalties[2],penalties[3]) : max(penalties[0],penalties[1])
 let E=100-penalties[main]-min(8,0.25*adj),alpha=min(15,9/length),beta=min(20,20*sqrt(0.6/length))
 let A=100*exp(-pow(max(angle-alpha,0)/beta,2))
 return 0.5*min(D,E,A)+0.5*pow(D*E*A,1.0/3)
}
struct RNG {var state:UInt64=20261026; mutating func next()->Float{state=state &* 6364136223846793005 &+ 1442695040888963407;return Float(Double(state>>11)/9007199254740992)}}
struct Board {let cue:SCNVector3;let balls:[SCNVector3]}
var rng=RNG()
func makeBoard(_ n:Int)->Board {
 var positions:[SCNVector3]=[]
 while positions.count<n+1 {
  let p=SCNVector3((rng.next()*2-1)*1.239,0.8,(rng.next()*2-1)*0.604)
  if positions.allSatisfy({AngleSceneCalculator.horizontalDistance($0,p)>0.058}){positions.append(p)}
 }
 return Board(cue:positions[0],balls:Array(positions.dropFirst()))
}
@inline(never) func run(_ b:Board,mode:Int)->Double {
 var best = -1.0
 for (i,t) in b.balls.enumerated() {
  let obstacles=b.balls.enumerated().filter{$0.offset != i}.map{$0.element}
  for pocket in 0..<6 {
   let candidate = mode==0 ? AngleSceneCalculator.dailyPocketCandidate(cue:b.cue,target:t,targetKey:String(i),pocketIndex:pocket,obstacles:obstacles,surfaceY:0.8) : AngleSceneCalculator.proposedCandidate(cue:b.cue,target:t,targetKey:String(i),pocketIndex:pocket,obstacles:obstacles,surfaceY:0.8)
   if let c=candidate {best=max(best,mode==0 ? c.score : comfort(cue:b.cue,target:t,aim:c.aim,angle:c.cutDegrees))}
  }
 }
 return best
}
func summary(_ a:[Double])->[String:Double]{let s=a.sorted();return ["mean_ms":s.reduce(0,+)/Double(s.count),"p50_ms":s[s.count/2],"p95_ms":s[Int(Double(s.count)*0.95)],"p99_ms":s[Int(Double(s.count)*0.99)],"max_ms":s.last!]}
var results:[[String:Any]]=[];var checksum=0.0
for n in [1,5,9,15] {
 let boards=(0..<400).map{_ in makeBoard(n)}
 for b in boards.prefix(40){checksum+=run(b,mode:1)}
 for mode in [0,1] {
  var times:[Double]=[]
  for _ in 0..<20 {for b in boards {
   let start=DispatchTime.now().uptimeNanoseconds
   let score=run(b,mode:mode)
   let end=DispatchTime.now().uptimeNanoseconds
   times.append(Double(end-start)/1e6);checksum+=score
  }}
  results.append(["targets":n,"mode":mode==0 ? "existing_geometry_full_enumeration" : "proposed_region_all_aims_W","boards":400,"iterations":times.count,"timing":summary(times)])
 }
}
let output:[String:Any]=["environment":"Apple M5 Pro arm64 macOS; Swift -O; standalone no UI/physics; no candidate cache","results":results,"checksum":checksum]
let data=try JSONSerialization.data(withJSONObject:output,options:[.prettyPrinted,.sortedKeys]);print(String(decoding:data,as:UTF8.self))
