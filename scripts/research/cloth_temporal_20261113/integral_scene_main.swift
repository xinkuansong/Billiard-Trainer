let shaderRoot=URL(fileURLWithPath:CommandLine.arguments[5])
let reference=try String(contentsOf:shaderRoot.appendingPathComponent("baseline.surface"),encoding:.utf8)
let candidate=try String(contentsOf:shaderRoot.appendingPathComponent("candidate.surface"),encoding:.utf8)
let headroom=pow(2.0,0.1)-1
let fragment="""
#pragma body
float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
"""
// __HELPERS__
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
var summaries=[[String:Any]]()
for pose in ["single-low","single-near","scatter-overview"] {
 try autoreleasepool {
  let scene=try makeScene(package),w=maxWidth,h=w*4/7,target=try Target(scene.renderer,w,h)
  var comparisons=[[String:Any]](),valid=true
  for frame in 0..<6 {
   _=input(scene,pose,frame)
   install(scene,reference);_ = try target.batch(2);let a=try target.read();_ = try target.frame();let aa=try target.read()
   install(scene,candidate);_ = try target.batch(2);let b=try target.read()
   let d=difference(a,b),noise=difference(a,aa)
   try target.save(a,"\(pose)-\(frame)-reference");try target.save(b,"\(pose)-\(frame)-candidate")
   valid = valid && d["changedPixels"]==0 && noise["changedPixels"]==0
   comparisons.append(["frame":frame,"aa":noise,"candidate":d])
  }
  var times=[[String:Any]]()
  if valid {
   for kind in ["AA","AB"] {
    for cycle in 0..<6 {
     let order=cycle%2==0 ? [false,true,true,false]:[true,false,false,true]
     for b in order {
      install(scene,(kind=="AB" && b) ? candidate:reference);_ = try target.batch(2)
      var frames=[FrameTime]()
      for frame in 0..<12 {_=input(scene,pose,frame%6);frames.append(try target.frame())}
      times.append(["kind":kind,"cycle":cycle,"arm":b ? "B":"A","gpuMS":frames.map{$0.gpu},"cpuEncodeMS":frames.map{$0.encode},"wallMS":frames.map{$0.syncWall}])
     }
    }
   }
  }
  summaries.append(["pose":pose,"width":w,"height":h,"exactFrames":valid,"comparisons":comparisons,"times":times,"extraCacheBytes":0,"extraPasses":0])
  try write(summaries,"results.json");print("\(pose) exact=\(valid)")
 }
}
