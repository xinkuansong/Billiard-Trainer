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
let prepareStart=CACurrentMediaTime()
// __DIMENSIONS__
let fieldDescriptor=MTLTextureDescriptor()
fieldDescriptor.textureType = .type3D;fieldDescriptor.pixelFormat = .rgba32Float
fieldDescriptor.width=fieldWidth;fieldDescriptor.height=fieldHeight;fieldDescriptor.depth=fieldDepth
fieldDescriptor.usage=[.shaderRead,.shaderWrite];fieldDescriptor.storageMode = .shared
let field0=try unwrap(device.makeTexture(descriptor:fieldDescriptor),"Field0"),field1=try unwrap(device.makeTexture(descriptor:fieldDescriptor),"Field1")
let genSource=try String(contentsOf:shaderRoot.appendingPathComponent("generate.metal"),encoding:.utf8)
let library=try device.makeLibrary(source:genSource,options:nil)
let pipeline=try device.makeComputePipelineState(function:unwrap(library.makeFunction(name:"generateField"),"Field function"))
let queue=try unwrap(device.makeCommandQueue(),"Field queue"),cb=try unwrap(queue.makeCommandBuffer(),"Field command"),encoder=try unwrap(cb.makeComputeCommandEncoder(),"Field encoder")
encoder.setComputePipelineState(pipeline);encoder.setTexture(field0,index:0);encoder.setTexture(field1,index:1)
encoder.dispatchThreads(MTLSize(width:fieldWidth,height:fieldHeight,depth:fieldDepth),threadsPerThreadgroup:MTLSize(width:8,height:4,depth:4));encoder.endEncoding();cb.commit();cb.waitUntilCompleted();try done(cb)
let generation=(cb.gpuEndTime-cb.gpuStartTime)*1000,prepareWall=(CACurrentMediaTime()-prepareStart)*1000
var finite=true
for (i,field) in [field0,field1].enumerated() {
 var values=[Float](repeating:0,count:fieldWidth*fieldHeight*fieldDepth*4)
 values.withUnsafeMutableBytes{field.getBytes($0.baseAddress!,bytesPerRow:fieldWidth*16,bytesPerImage:fieldWidth*fieldHeight*16,from:MTLRegionMake3D(0,0,0,fieldWidth,fieldHeight,fieldDepth),mipmapLevel:0,slice:0)}
 finite = finite && values.allSatisfy{$0.isFinite}
 try values.withUnsafeBytes{Data($0)}.write(to:output.appendingPathComponent("field-\(i).bin"))
}
try need(finite,"Nonfinite field")
try write(["generationGPU_MS":generation,"prepareWallIncludingCompileMS":prepareWall,"bytes":field0.allocatedSize+field1.allocatedSize,"allFinite":finite],"generation.json")
var summaries=[[String:Any]]()
for pose in ["single-low","single-near","scatter-overview"] {
 try autoreleasepool {
  let scene=try makeScene(package),w=maxWidth,h=w*4/7,target=try Target(scene.renderer,w,h)
  for m in scene.mats {m.setValue(SCNMaterialProperty(contents:field0),forKey:"temporalField0");m.setValue(SCNMaterialProperty(contents:field1),forKey:"temporalField1")}
  var comparisons=[[String:Any]](),exact=true,maxError=0
  for frame in 0..<6 {
   _=input(scene,pose,frame)
   install(scene,reference);_ = try target.batch(2);let a=try target.read();_ = try target.frame();let aa=try target.read()
   install(scene,candidate);_ = try target.batch(2);let b=try target.read()
   let d=difference(a,b),noise=difference(a,aa)
   try target.save(a,"\(pose)-\(frame)-reference");try target.save(b,"\(pose)-\(frame)-candidate")
   exact = exact && d["changedPixels"]==0 && noise["changedPixels"]==0;maxError=max(maxError,d["maximumChannelDifference"]!)
   comparisons.append(["frame":frame,"aa":noise,"candidate":d])
  }
  install(scene,candidate+"\nif(temporalFieldEligible(p,n)) _surface.emission.rgb=float3(1,0,0);");_ = try target.batch(2)
  let hitMap=try target.read();try target.save(hitMap,"\(pose)-hit-map")
  var times=[[String:Any]]()
  // Investigational limit fixed before results: >3 codes is not cost-ranked.
  // Even <=3 is not production acceptance; every raw pixel difference is retained.
  if maxError<=3 {
   for kind in ["AA","AB"] {for cycle in 0..<6 {
    for b in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
     install(scene,(kind=="AB" && b) ? candidate:reference);_ = try target.batch(2)
     var frames=[FrameTime]()
     for frame in 0..<12 {_=input(scene,pose,frame%6);frames.append(try target.frame())}
     times.append(["kind":kind,"cycle":cycle,"arm":b ? "B":"A","gpuMS":frames.map{$0.gpu},"cpuEncodeMS":frames.map{$0.encode},"wallMS":frames.map{$0.syncWall}])
    }
   }}
  }
  summaries.append(["pose":pose,"width":w,"height":h,"pixelExact":exact,"maximumChannelDifference":maxError,"comparisons":comparisons,"times":times,"hitCounts":counts(hitMap),"productionAllowed":false])
  try write(summaries,"results.json");print("\(pose) exact=\(exact), max difference=\(maxError)")
 }
}
