// H17: exact-sample compute preparation and same-frame shadow consumption.
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let guardSource=try String(contentsOf:package.appendingPathComponent("candidate.surface"),encoding:.utf8)
let emitter=String(guardSource[guardSource.range(of:"float3 v62EmitterCenter(")!.lowerBound..<guardSource.range(of:"float v62RectIrradiance(")!.lowerBound])
let c1=try unwrap(StaticClothIrradiance.replacingDiffuse(in:guardSource),"C1")
let baseline=try unwrap(ClothShadowProgram.replacingLocalBalls(in:c1),"H9 current production identity")
let field=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:repository.appendingPathComponent("QiuJi/Resources/StaticClothIrradiance-v1.bin"))
let headroom=pow(2.0,0.1)-1
let fragment="""
#pragma body
float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
"""
func install(_ scene:SceneFixture,_ source:String) {
 for m in scene.mats {var mods=m.shaderModifiers ?? [:];mods[.surface]=source;mods[.fragment]=fragment;m.shaderModifiers=mods}
 SCNTransaction.flush()
}
func once(_ source:String,_ old:String,_ new:String)throws->String {
 try need(source.components(separatedBy:old).count==2,"Unique anchor: \(old.prefix(80))")
 return source.replacingOccurrences(of:old,with:new)
}
let brdfStart=try unwrap(baseline.range(of:"float nl=max(0.001,dot(n,l));",options:.backwards),"BRDF")
let weightStart=try unwrap(baseline.range(of:"float3 weighted=",range:brdfStart.upperBound..<baseline.endIndex),"Weight")
let weightEnd=try unwrap(baseline.range(of:"unoccludedE+=weighted; E+=weighted*visibility;",range:weightStart.lowerBound..<baseline.endIndex),"Accumulate")
let brdf=String(baseline[brdfStart.lowerBound..<weightStart.lowerBound])
let weight=String(baseline[weightStart.lowerBound..<weightEnd.lowerBound])
let accumulation="S+=weighted*visibility*D*G*F/(4.0*nv*nl);"
let coreStart=try unwrap(baseline.range(of:"bool shadowPossible=false;"),"Core start")
let coreEnd=try unwrap(baseline.range(of:"// v64ClothNap:"),"Core end")
let core=String(baseline[coreStart.lowerBound..<coreEnd.lowerBound])
let declarations=String(baseline[..<baseline.range(of:"#pragma body")!.lowerBound])
 .components(separatedBy:"\n").filter { !$0.hasPrefix("#pragma") && !$0.hasPrefix("texture") && $0 != "QiuJiContactUniforms contactUniforms;" }.joined(separator:"\n")
let commonInputs="""
float4 q=receiverPosition.read(id),nr=receiverNormal.read(id);
if(q.w==0.0){resultDiffuse.write(float4(0),id);resultSpecular.write(float4(0),id);return;}
float3 p=q.xyz,n=nr.xyz,v=normalize(camera.xyz-p);
float nv=max(0.001,dot(n,v));float alpha=max(0.01,nr.w*nr.w);float a2=alpha*alpha;
float3 E=0.0,unoccludedE=0.0,S=0.0;
\((0..<16).map{"float4 contactBall\($0)=contactUniforms.contactBalls[\($0)];"}.joined(separator:"\n"))
"""
let signature="""
texture2d<float,access::read> receiverPosition [[texture(0)]],
texture2d<float,access::read> receiverNormal [[texture(1)]],
texture2d<float,access::read> staticSpecular [[texture(2)]],
texture2d<float,access::write> resultDiffuse [[texture(3)]],
texture2d<float,access::write> resultSpecular [[texture(4)]],
texture3d<float> temporalField0 [[texture(5)]],texture3d<float> temporalField1 [[texture(6)]],
constant QiuJiContactUniforms &contactUniforms [[buffer(0)]],constant float4 &camera [[buffer(1)]],
uint2 id [[thread_position_in_grid]]
"""
var separated=try once(core,brdf,"")
separated=try once(separated,accumulation,"""
if(!shadowPossible || visibility<1.0) {
 \(brdf)
 S+=weighted*(shadowPossible ? visibility-1.0:visibility)*D*G*F/(4.0*nv*nl);
}
""")
let finalLoop=try unwrap(separated.range(of:"for(int panel=0;panel<2;++panel) {",options:.backwards),"Final panel loop")
separated.insert(contentsOf:"if(shadowPossible) S=staticSpecular.read(id).rgb;\n",at:finalLoop.lowerBound)
let prepare="""
kernel void prepareSpecular(texture2d<float,access::read> receiverPosition [[texture(0)]],
 texture2d<float,access::read> receiverNormal [[texture(1)]],texture2d<float,access::write> result [[texture(2)]],
 constant float4 &camera [[buffer(0)]],uint2 id [[thread_position_in_grid]]) {
 if(any(id>=uint2(result.get_width(),result.get_height())))return;
 float4 q=receiverPosition.read(id),nr=receiverNormal.read(id);
 if(q.w==0.0){result.write(float4(0),id);return;}
 float3 p=q.xyz,n=nr.xyz,v=normalize(camera.xyz-p),S=0.0;
 float nv=max(0.001,dot(n,v));float alpha=max(0.01,nr.w*nr.w);float a2=alpha*alpha;
 for(int panel=0;panel<2;++panel){
  float cellArea=v62EmitterArea(panel)/32.0;
  for(int ix=0;ix<8;++ix)for(int iz=0;iz<4;++iz){
   float3 lp=v62EmitterCenter(panel)+v62EmitterU(panel)*(2.0*(float(ix)+0.5)/8.0-1.0)+v62EmitterV(panel)*(2.0*(float(iz)+0.5)/4.0-1.0);
   float3 delta=lp-p;float r2=dot(delta,delta);float3 l=delta/sqrt(r2);
   \(brdf)
   \(weight)
   S+=weighted*D*G*F/(4.0*nv*nl);
  }
 }
 result.write(float4(S,1),id);
}
"""
let clearKernel="""
kernel void clearReceivers(texture2d<float,access::write> positions [[texture(0)]],texture2d<float,access::write> normals [[texture(1)]],uint2 id [[thread_position_in_grid]]) {
 if(any(id>=uint2(positions.get_width(),positions.get_height())))return;
 positions.write(float4(0),id);normals.write(float4(0),id);
}
"""
let computeSource="#include <metal_stdlib>\nusing namespace metal;\n"+declarations+"\n"+prepare+clearKernel+[ ("direct",core),("reuse",separated) ].map { name,body in
 """
 kernel void \(name)(\(signature)) {
  if(any(id>=uint2(receiverPosition.get_width(),receiverPosition.get_height())))return;
  \(commonInputs)
  \(body)
  resultDiffuse.write(float4(E,1),id);resultSpecular.write(float4(S,1),id);
 }
 """
}.joined(separator:"\n")
try computeSource.write(to:output.appendingPathComponent("compute.metal"),atomically:true,encoding:.utf8)
let library=try device.makeLibrary(source:computeSource,options:nil)
var pipelines=[String:MTLComputePipelineState]()
for name in ["prepareSpecular","direct","reuse","clearReceivers"] {pipelines[name]=try device.makeComputePipelineState(function:unwrap(library.makeFunction(name:name),name))}
let project="""
float4 reuseClip=scn_frame.projectionTransform*float4(_surface.position,1.0);
float2 reuseScreen=(reuseClip.xy/reuseClip.w*float2(0.5,-0.5)+0.5)*reuseViewport.xy;
int2 reusePixel=int2(floor(reuseScreen))-int2(reuseViewport.zw);
float3 reuseGeometryNormal=normalize((scn_frame.inverseViewTransform*float4(_surface.geometryNormal,0.0)).xyz);
bool reuseInside=all(reusePixel>=int2(0)) && all(reusePixel<int2(\(384),\(384))) && abs(p.y-0.8)<0.00001 && reuseGeometryNormal.y>0.99999;
"""
let arguments="""
#pragma arguments
texture2d<float> reuseDiffuse;
texture2d<float> reuseSpecular;
float4 reuseViewport;
"""
let consumerBody="""
\(project)
float4 reuseE=reuseInside ? reuseDiffuse.read(uint2(reusePixel)):float4(0);
if(reuseE.w==1.0){E=reuseE.xyz;S=reuseSpecular.read(uint2(reusePixel)).xyz;}
else {\(core)}
"""
let consumer=try once(try once(baseline,"#pragma body",arguments+"\n#pragma body"),core,consumerBody)
let capture="""
#pragma arguments
texture2d<float,access::write> reusePositionOut;
texture2d<float,access::write> reuseNormalOut;
float4 reuseViewport;
#pragma body
float3 p=(scn_frame.inverseViewTransform*float4(_surface.position,1.0)).xyz;
\(project)
if(reuseInside){
 reusePositionOut.write(float4(p,1),uint2(reusePixel));
 float3 n=normalize((scn_frame.inverseViewTransform*float4(_surface.normal,0.0)).xyz);
 reuseNormalOut.write(float4(n,_surface.roughness),uint2(reusePixel));
}
_surface.emission.rgb=float3(0);_surface.diffuse.rgb=float3(0);_surface.metalness=1.0;
"""
for (name,source) in [("baseline",baseline),("consumer",consumer),("capture",capture)] {try source.write(to:output.appendingPathComponent(name+".surface"),atomically:true,encoding:.utf8)}

final class ComputeCache {
 let textures:[MTLTexture],balls:MTLBuffer
 let side=384
 var camera=SIMD4<Float>(0,0,0,0)
 init(_ scene:SceneFixture,_ target:Target)throws {
  let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:side,height:side,mipmapped:false)
  d.usage=[.shaderRead,.shaderWrite];d.storageMode = .shared
  textures=try (0..<5).map { i in let t=try unwrap(device.makeTexture(descriptor:d),"H17 texture");t.label="H17-\(i)";return t }
  balls=try unwrap(device.makeBuffer(length:256,options:.storageModeShared),"H17 balls")
  let zero=Data(repeating:0,count:side*side*16)
  for t in textures {zero.withUnsafeBytes{t.replace(region:MTLRegionMake2D(0,0,side,side),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:side*16)}}
  for m in scene.mats {
   for (name,index) in [("reusePositionOut",0),("reuseNormalOut",1),("reuseDiffuse",3),("reuseSpecular",4)] {m.setValue(SCNMaterialProperty(contents:textures[index]),forKey:name)}
   m.setValue(NSValue(scnVector4:SCNVector4(Float(target.w),Float(target.h),Float((target.w-side)/2),Float((target.h-side)/2))),forKey:"reuseViewport")
  }
  try need(allocatedBytes<=16*1024*1024,"H17 texture budget")
 }
 var allocatedBytes:Int {textures.reduce(0){$0+$1.allocatedSize}+balls.allocatedSize}
 func inputs(_ values:[SIMD4<Float>],_ scene:SceneFixture){
  values.withUnsafeBytes{memcpy(balls.contents(),$0.baseAddress!,256)}
  camera=SIMD4(scene.eye.simdWorldPosition,1)
 }
 func encode(_ command:MTLCommandBuffer,_ name:String)throws {
  let e=try unwrap(command.makeComputeCommandEncoder(),"H17 encoder")
  e.label="H17 \(name)";e.setComputePipelineState(pipelines[name]!)
  for i in 0..<3 {e.setTexture(textures[i],index:i)}
  if name=="clearReceivers" { /* Only textures zero and one are used. */ }
  else if name=="prepareSpecular" {e.setBytes(&camera,length:16,index:0)}
  else {
   e.setTexture(textures[3],index:3);e.setTexture(textures[4],index:4)
   e.setTexture(field.fields[0],index:5);e.setTexture(field.fields[1],index:6)
   e.setBuffer(balls,offset:0,index:0);e.setBytes(&camera,length:16,index:1)
  }
  e.dispatchThreads(MTLSize(width:side,height:side,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1));e.endEncoding()
 }
 func prepare(_ target:Target)throws->[String:Double] {
  let start=CACurrentMediaTime(),cb=try unwrap(target.queue.makeCommandBuffer(),"Prepare")
  try encode(cb,"prepareSpecular");let encoded=CACurrentMediaTime()
  cb.commit();cb.waitUntilCompleted();try done(cb)
  return ["gpuMS":(cb.gpuEndTime-cb.gpuStartTime)*1000,"cpuEncodeMS":(encoded-start)*1000,"wallMS":(CACurrentMediaTime()-start)*1000]
 }
 func validPixels()->Int {
  var values=[Float](repeating:0,count:side*side*4)
  values.withUnsafeMutableBytes{textures[0].getBytes($0.baseAddress!,bytesPerRow:side*16,from:MTLRegionMake2D(0,0,side,side),mipmapLevel:0)}
  return (0..<side*side).filter{values[4*$0+3]==1}.count
 }
}

var results=[[String:Any]]()
for pose in ["single-low","single-near","scatter-overview"] {
 try autoreleasepool {
  let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7)
  for m in scene.mats {field.install(on:m)}
  let cache=try ComputeCache(scene,target)
  cache.inputs(input(scene,pose,0),scene)
  install(scene,baseline);_=try target.batch(8)
  let cameraIdentity=Array(0..<4).flatMap{i in [scene.eye.simdTransform[i].x,scene.eye.simdTransform[i].y,scene.eye.simdTransform[i].z,scene.eye.simdTransform[i].w]}
  install(scene,capture)
  let captures=try target.batch(3)
  let preparation=try cache.prepare(target)
  let valid=cache.validPixels();try need(valid>0,"No actual captured bed pixels")
  for variant in ["direct","reuse"] {
   var comparisons=[[String:Any]](),maximum=0,aaMax=0,restoreMax=0
   for frame in 0..<6 {
    cache.inputs(input(scene,pose,frame),scene)
    target.beforeRender=nil;install(scene,baseline);_=try target.batch(3)
    let a=try target.read();_=try target.frame();let aa=try target.read()
    target.beforeRender={try cache.encode($0,variant)};install(scene,consumer);_=try target.batch(3);let b=try target.read()
    target.beforeRender=nil;install(scene,baseline);_=try target.batch(3);let restored=try target.read()
    let delta=difference(a,b),noise=difference(a,aa),restore=difference(a,restored)
    maximum=max(maximum,delta["maximumChannelDifference"]!);aaMax=max(aaMax,noise["maximumChannelDifference"]!);restoreMax=max(restoreMax,restore["maximumChannelDifference"]!)
    if frame==0 || delta["maximumChannelDifference"]!>1 {try target.save(a,"\(pose)-\(variant)-\(frame)-baseline");try target.save(b,"\(pose)-\(variant)-\(frame)-candidate")}
    comparisons.append(["frame":frame,"delta":delta,"aa":noise,"restore":restore])
   }
   var times=[[String:Any]]()
   if maximum<=1 && aaMax==0 && restoreMax==0 {
    let kinds=experimentRound=="refine" && variant=="reuse" ? ["AA","AB","DI"]:["AA","AB"]
    for kind in kinds {for cycle in 0..<6 {for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
     let active=kind=="DI" || (kind=="AB" && arm)
     let program=kind=="DI" && !arm ? "direct":variant
     target.beforeRender=active ? {try cache.encode($0,program)}:nil
     install(scene,active ? consumer:baseline);_=try target.batch(6)
     var samples=[FrameTime]()
     for frame in 0..<12 {cache.inputs(input(scene,pose,frame%6),scene);samples.append(try target.frame())}
     times.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","frames":samples.map{$0.json},"gpuMS":samples.map{$0.gpu},"cpuEncodeMS":samples.map{$0.encode},"wallMS":samples.map{$0.syncWall}])
    }}}
   }
   var motion=[[String:Any]](),positiveControl=[String:Int]()
   if experimentRound=="refine" {
    cache.inputs(input(scene,pose,0),scene)
    target.beforeRender=nil;install(scene,baseline);_=try target.batch(3);let original=try target.read()
    let red=try once(consumer,"E=reuseE.xyz;S=reuseSpecular.read(uint2(reusePixel)).xyz;","E=reuseE.xyz;S=float3(2,0,0);")
    install(scene,red);target.beforeRender={try cache.encode($0,variant)};_=try target.batch(3)
    let controlled=try target.read();positiveControl=difference(original,controlled)
    try need(positiveControl["maximumChannelDifference"]!>8 && positiveControl["changedPixels"]!>100,"Compute consumer positive control")
    try target.save(controlled,"\(pose)-\(variant)-positive-control")
    for frame in 0..<6 {
     let values=input(scene,pose,frame)
     let eye=scene.eye.simdPosition+SIMD3<Float>(Float(frame+1)*0.025,Float(frame%2)*0.015,0)
     let delta=eye-SIMD3<Float>(0,0.8,0)
     let cameraPose=ProductionPose.Pose.looking(eye:eye,yaw:atan2(delta.z,delta.x),pitch:-atan2(delta.y,sqrt(delta.x*delta.x+delta.z*delta.z)),fov:50)
     scene.eye.simdTransform=cameraPose.transform;SCNTransaction.flush();cache.inputs(values,scene)
     target.beforeRender=nil;install(scene,baseline);_=try target.batch(3);let a=try target.read()
     let aTime=try target.frame();let aa=try target.read()
     install(scene,capture);target.beforeRender={try cache.encode($0,"clearReceivers")}
     let captureTime=try target.frame()
     let prepareTime=variant=="reuse" ? try cache.prepare(target):["gpuMS":0,"cpuEncodeMS":0,"wallMS":0]
     install(scene,consumer);target.beforeRender={try cache.encode($0,variant)}
     let consumeTime=try target.frame();let b=try target.read()
     let diff=difference(a,b),noise=difference(a,aa)
     motion.append(["frame":frame,"delta":diff,"aa":noise,"baseline":aTime.json,"capture":captureTime.json,"prepare":prepareTime,"consume":consumeTime.json,"candidateTotalGPU_MS":captureTime.gpu+prepareTime["gpuMS"]!+consumeTime.gpu])
     try target.save(a,"\(pose)-\(variant)-motion-\(frame)-baseline");try target.save(b,"\(pose)-\(variant)-motion-\(frame)-candidate")
    }
    // Restore the original view and its receivers before evaluating the next arm.
    cache.inputs(input(scene,pose,0),scene);install(scene,capture);target.beforeRender={try cache.encode($0,"clearReceivers")};_=try target.frame();_=try cache.prepare(target)
   }
   target.beforeRender=nil
   results.append(["variant":variant,"pose":pose,"width":maxWidth,"height":target.h,"allocatedBytes":cache.allocatedBytes,"capturedPixels":valid,"cameraTransform":cameraIdentity,"captureFrames":captures.map{$0.json},"prepare":preparation,"maximumChannelDifference":maximum,"aaMaximum":aaMax,"restoreMaximum":restoreMax,"comparisons":comparisons,"times":times,"positiveControl":positiveControl,"cameraRebuild":motion])
   try write(["baseline":"dd6476979 C1+H9; isolated actual cloth material","scope":"Native SceneKit, same-command compute+render; synthetic changing ball uniforms, no physical shots/UI; cold capture/prepare reported separately","rows":results],"results.json")
   print("\(pose) \(variant) max=\(maximum) AA=\(aaMax) restore=\(restoreMax) valid=\(valid) timingArms=\(times.count)",terminator:"\n");fflush(stdout)
  }
 }
}
