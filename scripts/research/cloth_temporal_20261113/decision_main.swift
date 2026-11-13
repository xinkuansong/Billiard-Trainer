// Cost diagnosis for a candidate that FAILED the prior zero-difference gate.
// This file never upgrades quality status or grants production acceptance.
let shaderRoot=URL(fileURLWithPath:CommandLine.arguments[5])
let reference=try String(contentsOf:shaderRoot.appendingPathComponent("baseline.surface"),encoding:.utf8)
let candidate=try String(contentsOf:shaderRoot.appendingPathComponent("candidate.surface"),encoding:.utf8)
let generator=try String(contentsOf:shaderRoot.appendingPathComponent("generate.surface"),encoding:.utf8)
let headroom=pow(2.0,0.1)-1
let fragment="""
#pragma body
float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
"""
// __CACHE_HELPERS__
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
var reports=[[String:Any]]()
for pose in ["single-low","single-near","scatter-overview"] {
 try autoreleasepool {
  let scene=try makeScene(package),w=maxWidth,h=w*4/7,target=try Target(scene.renderer,w,h)
  let texture=try cache(scene,w,h)
  _=input(scene,pose,0)
  // Prime both compiled programs outside measurement, never inferred as cold launch.
  install(scene,reference);_ = try target.batch(2)
  install(scene,generator);_ = try target.batch(2)
  for m in scene.mats {m.setValue(Float(2),forKey:"temporalEnabled")}
  install(scene,candidate);_ = try target.batch(2)
  install(scene,candidate+"\nif(temporalHit) _surface.emission.rgb=float3(1,0,0);")
  _ = try target.batch(2);let hitImage=try target.read();try target.save(hitImage,"\(pose)-hit-map")
  var rows=[[String:Any]]()
  for kind in ["AA","AB"] {
   for cycle in 0..<6 {
    let order=cycle%2==0 ? [false,true,true,false]:[true,false,false,true]
    for b in order {
     let useCache=kind=="AB" && b
     _=input(scene,pose,0)
     var generation:FrameTime?=nil
     if useCache {
      for m in scene.mats{m.setValue(Float(1),forKey:"temporalEnabled")}
      install(scene,generator);generation=try target.frame()
      for m in scene.mats{m.setValue(Float(2),forKey:"temporalEnabled")}
     }
     install(scene,useCache ? candidate:reference)
     var frames=[FrameTime]()
     for frame in 0..<60 {
      _=input(scene,pose,frame%6)
      frames.append(try target.frame())
     }
     let gpu=frames.map{$0.gpu},cpu=frames.map{$0.encode}
     rows.append(["kind":kind,"cycle":cycle,"arm":b ? "B":"A","usesCache":useCache,
       "generationGPU_MS":generation?.gpu ?? 0,"generationCPUEncodeMS":generation?.encode ?? 0,
       "frameGPU_MS":gpu,"frameCPUEncodeMS":cpu,"totalGPU_MS":gpu.reduce(0,+)+(generation?.gpu ?? 0),
       "totalCPUEncodeMS":cpu.reduce(0,+)+(generation?.encode ?? 0)])
    }
   }
  }
  let row:[String:Any]=["pose":pose,"width":w,"height":h,"cacheBytes":texture.allocatedSize,
   "qualityAccepted":false,"productionAllowed":false,"diagnosticHitColorCounts":counts(hitImage),"rows":rows,
   "scope":"Isolated real material, 60 synthetic moving-shadow frames, generation full draw included; no app UI, balls geometry, system present or thermal claim. Shader compilation primed outside measurement."]
  reports.append(row);try write(reports,"results.json");print("\(pose) cost diagnosis complete; quality remains failed")
 }
}
