import Foundation
import SceneKit
import zlib

struct ParamRoute: Decodable { let id: Int; let v,sx,sy: Double; let dir:[Float]; let rails:[Int] }
struct ParamQuestion: Decodable { let id:Int; let p:[Double]; let refs:[[Int]] }
struct ParamBoard: Decodable {let id:String;let cue,object,aim:[Double];let pocket:Int;let angle:Double}
struct ParamLayout: Decodable {let id:String;let board:ParamBoard;let routes:[ParamRoute];let questions:[ParamQuestion]}
struct ParamIndex: Decodable {
 struct Entry:Decodable {let id,shard:String;let line:Int}
 let layouts:[Entry]
}
struct AuditCase: Decodable {
 struct Ref:Decodable {let comboIndex:Int;let comfort:Comfort;struct Comfort:Decodable {let totalScore:Double}}
 struct Candidate:Decodable {let top5:[Ref]}
 struct Route:Decodable {
  struct Line:Decodable {let points:[[Double]];let mandatoryPointIndices:[Int]}
  struct Difficulty:Decodable {let effort,difficulty:Double}
  let comboIndex:Int;let cueStop:[Double];let trajectory2mm:Line;let executionDifficulty:Difficulty
 }
 let key,layoutID:String;let cellID:Int;let cohorts:[String];let candidate:Candidate;let routes:[Route]
}
func unzip(_ input:Data)throws->Data {
 var s=z_stream();guard inflateInit2_(&s,15+32,ZLIB_VERSION,Int32(MemoryLayout<z_stream>.size))==Z_OK else {throw NSError(domain:"gzip-init",code:1)}
 defer{inflateEnd(&s)}
 return try input.withUnsafeBytes {ptr in
  s.next_in=UnsafeMutablePointer(mutating:ptr.bindMemory(to:Bytef.self).baseAddress);s.avail_in=uInt(input.count)
  var out=Data(),buf=[UInt8](repeating:0,count:65536),status:Int32=Z_OK
  repeat {status=buf.withUnsafeMutableBytes {b in s.next_out=b.bindMemory(to:Bytef.self).baseAddress;s.avail_out=uInt(b.count);return inflate(&s,Z_NO_FLUSH)}
   guard status==Z_OK || status==Z_STREAM_END else {throw NSError(domain:"gzip",code:Int(status))}
   out.append(contentsOf:buf.prefix(buf.count-Int(s.avail_out)))
   guard out.count<=32_000_000 else {throw NSError(domain:"gzip-limit",code:1)}
  }while status != Z_STREAM_END
  return out
 }
}
func clockMS()->Double {Double(DispatchTime.now().uptimeNanoseconds)/1e6}
func write(_ value:Any,_ path:String)throws {try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]).write(to:URL(fileURLWithPath:path),options:.atomic)}
func xy(_ p:SCNVector3)->[Double] {[Double(p.x),Double(p.z)]}
func board(_ b:ParamBoard)->TrainingBankBoard {
 .init(gridID:b.id,seed:0,cue:.init(Float(b.cue[0]),0,Float(b.cue[1])),target:.init(Float(b.object[0]),0,Float(b.object[1])),aim:.init(Float(b.aim[0]),0,Float(b.aim[1])),pocket:b.pocket,angle:b.angle,side:0,cueBand:.mixed,pocketBand:.mixed,combinationID:"",qualification:"",generationAngle:b.angle)
}
func effort(_ r:ParamRoute,_ length:Double,_ n:Int)->Double {
 let s=abs(r.sx),u=r.v/4.5
 return (2.5*s+0.8*max(r.sy,0)+1.2*max(-r.sy,0))+0.8*u*u+(0.12*Double(n)+0.06*length)+(0.6*s*u+0.15*Double(n)*s)
}
// This generation entry has ONLY parameter-bank types. Offline paths never enter it.
func generate(_ b:ParamBoard,_ q:ParamQuestion,_ r:ParamRoute,_ pocket:Int,_ profile:[CueSection]) -> [String:Any] {
 let start=clockMS()
 do {
  let second=TrainingBankPoint(.init(Float(q.p[0]),0,Float(q.p[1])))
  let prediction=try ParameterReplaySolver.solve(board:board(b),second:second,input:.init(spinX:Float(r.sx),spinY:Float(r.sy),velocity:Float(r.v)),surfaceY:BTTablePhysics.surfaceY,profile:profile,direction:.init(r.dir[0],0,r.dir[1]))
  let physicsEnd=clockMS()
  if let failure=ParameterReplaySolver.failure(prediction,pocket:b.pocket) {return ["status":"rejected","reason":failure,"totalMS":clockMS()-start,"physicsMS":physicsEnd-start]}
  let line=try SeparationTrajectory.extract(prediction)
  let compact=try compactTrajectory(line,prediction:prediction)
  let points=compact["points"] as! [[Double]]
  // Same event-order rule as the frozen source contract.normalize: a rail at
  // the exact contact timestamp can still precede that contact in event order.
  var contacted=false, rails=[Int](), excludedAtContact=[Int]()
  let contactTime=prediction.recorder!.firstBallContacts[ShotInput.cueBallName]!.time
  for event in prediction.events {
   switch event.kind {
   case let .ballBall(a,b):
    if Set([a,b])==Set([ShotInput.cueBallName,ShotInput.targetBallName]) {contacted=true}
   case let .ballCushion(ball):
    if ball==ShotInput.cueBallName, let id=event.cushionIndex {
     if contacted {rails.append(id)}
     else if event.time>=contactTime {
      guard event.time==contactTime else {throw NSError(domain:"precontact-event-order",code:1)}
      excludedAtContact.append(id)
     }
    }
   default: break
   }
  }
  let stop=prediction.finalPositions[ShotInput.cueBallName]!
  let score=TwoBallComfortScore.evaluate(cue:(Double(stop.x),Double(stop.z)),ball:(Double(second.x),Double(second.z)),pocket:pocket)
  let length=zip(points,points.dropFirst()).reduce(0.0){$0+hypot($1.1[1]-$1.0[1],$1.1[2]-$1.0[2])}
  let e=effort(r,length,rails.count)
  let end=clockMS()
  return ["status":"generated","totalMS":end-start,"physicsMS":physicsEnd-start,"postprocessMS":end-physicsEnd,"points":points,"rails":rails,"excludedAtContact":excludedAtContact,"stop":xy(stop),"comfort":score.map{["distance":$0.distance,"space":$0.space,"angle":$0.angle,"total":$0.total]} as Any? ?? NSNull(),"effort":e,"difficulty":100*e/(1+e),"lengthMeters":length,"railMatch":rails==r.rails,"jawFree":!SeparationQuestionGenerator.hasCueJawContact(prediction),"fullPoints":line.map{[Double($0.position.x)*100,Double($0.position.z)*100]},"fullPointCount":line.count,"mandatoryPointIndices":compact["mandatoryPointIndices"]!]
 } catch {return ["status":"rejected","reason":String(describing:error),"totalMS":clockMS()-start]}
}
let startup=clockMS()
do {
 let args=CommandLine.arguments;let root=URL(fileURLWithPath:args[1]);let cases=try JSONDecoder().decode([AuditCase].self,from:Data(contentsOf:URL(fileURLWithPath:args[2])))
 let tIndex=clockMS();let index=try JSONDecoder().decode(ParamIndex.self,from:Data(contentsOf:root.appendingPathComponent("index.json")));let indexMS=clockMS()-tIndex
 let profileStart=clockMS();let profile=AccuracyTipSelector.renderedProfile();let profileMS=clockMS()-profileStart
 var cache:[String:[ParamLayout]]=[:],lru:[String]=[],records:[[String:Any]]=[],questions:[[String:Any]]=[]
 let warmup=clockMS()-startup
 for (ci,c) in cases.enumerated() {
  let loadStart=clockMS();let entry=index.layouts.first{$0.id==c.layoutID}!
  let hit=cache[entry.shard] != nil
  if !hit {let raw=try Data(contentsOf:root.appendingPathComponent(entry.shard+".jsonl.gz"));let plain=try unzip(raw);let layouts=try plain.split(separator:10).map{try JSONDecoder().decode(ParamLayout.self,from:Data($0))};if cache.count>=2 {cache.removeValue(forKey:lru.removeFirst())};cache[entry.shard]=layouts}
  lru.removeAll{$0==entry.shard};lru.append(entry.shard)
  let layout=cache[entry.shard]![entry.line];let q=layout.questions.first{$0.id==c.cellID}!;let lookup=Dictionary(uniqueKeysWithValues:layout.routes.map{($0.id,$0)});let loadMS=clockMS()-loadStart
  var questionTimes=[Double](),liveEfforts=[Double](),allGenerated=true
  for repeatIndex in 0..<3 {
   var sum=0.0
   for pair in q.refs {
    let route=lookup[pair[0]]!;var result=autoreleasepool {generate(layout.board,q,route,pair[1],profile)};sum+=result["totalMS"] as! Double
    result["question"]=c.key;result["routeID"]=route.id;result["repeat"]=repeatIndex;result["cohorts"]=c.cohorts
    // Reference audits happen AFTER generation timer has stopped.
    if result["status"] as? String=="generated" {
     let old=c.routes.first{$0.comboIndex==route.id}!;let ref=c.candidate.top5.first{$0.comboIndex==route.id}!
     let pts=result["points"] as! [[Double]],stop=result["stop"] as! [Double]
     let a=try SeparationArcRMSMetric.sample(old.trajectory2mm.points.map{SIMD2($0[1]*100,$0[2]*100)})
     let b=try SeparationArcRMSMetric.sample(pts.map{SIMD2($0[1]*100,$0[2]*100)})
     result["rmsCM"]=try SeparationArcRMSMetric.distance(a,b)
     let full=result.removeValue(forKey:"fullPoints") as! [[Double]]
     result["rmsFullCM"]=try SeparationArcRMSMetric.distance(a,SeparationArcRMSMetric.sample(full.map{SIMD2($0[0],$0[1])}))
     result["stopErrorMeters"]=hypot(stop[0]-old.cueStop[0],stop[1]-old.cueStop[1]);result["exactCompactPoints"]=pts==old.trajectory2mm.points
     let comfort=result["comfort"] as? [String:Double];result["comfortDelta"]=(comfort?["total"] ?? -1)-ref.comfort.totalScore;result["qualified85"]=(comfort?["total"] ?? -1)>=85
     result["effortDelta"]=(result["effort"] as! Double)-old.executionDifficulty.effort
     if repeatIndex==0 {liveEfforts.append(result["effort"] as! Double)}
    } else if repeatIndex==0 {allGenerated=false}
    records.append(result)
   }
   questionTimes.append(sum)
  }
  questions.append(["key":c.key,"cohorts":c.cohorts,"routes":q.refs.count,"loadMS":loadMS,"cacheHit":hit,"pipelineMS":questionTimes,"allGenerated":allGenerated,"liveOrderAscending":zip(liveEfforts,liveEfforts.dropFirst()).allSatisfy{$0 <= $1}])
  if ci%25==0 {print("PROGRESS \(ci+1)/\(cases.count)");fflush(stdout)}
 }
 try write(["state":"complete","indexDecodeMS":indexMS,"profileMS":profileMS,"setupMS":warmup,"elapsedMS":clockMS()-startup,"records":records,"questions":questions,"physicalModel":"planarReference","timingScope":"single serial optimized simulator process; pipeline includes access, physics, extract, RDP, comfort/E; excludes reference audit/JSON output/UI; no warmup route discarded","os":ProcessInfo.processInfo.operatingSystemVersionString,"pid":ProcessInfo.processInfo.processIdentifier],args[3])
 print("COMPLETE");fflush(stdout)
} catch {fputs("ERROR \(error)\n",stderr);exit(1)}
