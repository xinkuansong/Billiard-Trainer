try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let guardSource=try String(contentsOf:package.appendingPathComponent("candidate.surface"),encoding:.utf8)
let emitter=String(guardSource[guardSource.range(of:"float3 v62EmitterCenter(")!.lowerBound..<guardSource.range(of:"float v62RectIrradiance(")!.lowerBound])
let baseline=try unwrap(StaticClothIrradiance.replacingDiffuse(in:guardSource),"C1 baseline")
let field=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:repository.appendingPathComponent("QiuJi/Resources/StaticClothIrradiance-v1.bin"))
let brdfStart=try unwrap(baseline.range(of:"float nl=max(0.001,dot(n,l));",options:.backwards),"BRDF start")
let brdfEnd=try unwrap(baseline.range(of:"float3 weighted=",range:brdfStart.upperBound..<baseline.endIndex),"BRDF end")
let brdf=String(baseline[brdfStart.lowerBound..<brdfEnd.lowerBound])
let accumulation="S+=weighted*visibility*D*G*F/(4.0*nv*nl);"
try need(baseline.contains(accumulation),"Accumulation anchor drift")
let responseFunction="""
float nearResponse(float3 l,float3 n,float3 v,float nv,float a2) {
\(brdf)
return D*G*F/(4.0*nv*nl);
}
"""
func sharedResponse(_ linear:Bool)->String {
 let endpoint:Float=linear ? 0.75:0.5
 let preparation="""
float2 sharedBRDF=float2(0.0);
if(shadowPossible){
 float3 anchor=v62EmitterCenter(panel)+v62EmitterU(panel)*(2.0*(float(ix)+0.5)/float(samplesX)-1.0);
 sharedBRDF.x=nearResponse(normalize(anchor-v62EmitterV(panel)*\(endpoint)-p),n,v,nv,a2);
 sharedBRDF.y=nearResponse(normalize(anchor+v62EmitterV(panel)*\(endpoint)-p),n,v,nv,a2);
}
"""
 let response=linear ? "mix(sharedBRDF.x,sharedBRDF.y,float(iz)/3.0)":"(iz<2 ? sharedBRDF.x:sharedBRDF.y)"
 let evaluation="""
float response;
if(shadowPossible){response=\(response);}else{\(brdf)response=D*G*F/(4.0*nv*nl);}
"""
 return baseline
  .replacingOccurrences(of:"for(int iz=0;iz<samplesZ;++iz) {",with:preparation+"\nfor(int iz=0;iz<samplesZ;++iz) {")
  .replacingOccurrences(of:brdf,with:evaluation)
  .replacingOccurrences(of:accumulation,with:"S+=weighted*visibility*response;")
  .replacingOccurrences(of:"#pragma body",with:responseFunction+"\n#pragma body")
}
let zeroVisibility=baseline.replacingOccurrences(of:brdf,with:"")
 .replacingOccurrences(of:accumulation,with:"if(visibility>0.0){\n"+brdf+accumulation+"\n}")
func rowResponse(_ weightedDirection:Bool,_ groupSize:Int=1)->String {
 let rowDirection=weightedDirection ? "normalize(rowDirection)" : "normalize(v62EmitterCenter(panel)+v62EmitterU(panel)*(2.0*(float(ix)+0.5)/float(samplesX)-1.0)-p)"
 let rowAdd=weightedDirection ? "rowDirection+=l*(weighted.x*visibility);" : ""
 let completion="""
  }
  if(shadowPossible && ((ix+1)%\(groupSize))==0){
   if(rowEnergy.x>0.0){S+=rowEnergy*nearResponse(\(rowDirection),n,v,nv,a2);}
   rowEnergy=float3(0.0);rowDirection=float3(0.0);
  }
 }
}
E=temporalFieldDiffuse
"""
 return baseline
  .replacingOccurrences(of:"for(int ix=0;ix<samplesX;++ix) {",with:"float3 rowEnergy=float3(0.0);float3 rowDirection=float3(0.0);\nfor(int ix=0;ix<samplesX;++ix) {")
  .replacingOccurrences(of:brdf,with:"")
  .replacingOccurrences(of:accumulation,with:"if(shadowPossible){rowEnergy+=weighted*visibility;\(rowAdd)}else{\(brdf)\(accumulation)}")
  .replacingOccurrences(of:"  }\n }\n}\nE=temporalFieldDiffuse",with:completion)
  .replacingOccurrences(of:"#pragma body",with:responseFunction+"\n#pragma body")
}
try need(baseline.contains("  }\n }\n}\nE=temporalFieldDiffuse"),"Row loop end anchor")
func perLampMasks()->String {
 baseline
  .replacingOccurrences(of:"bool diagnosticGlobalQuality=shadowPossible && !diagnosticConeEligible;",with:"uint2 nearLampMasks=(shadowPossible && !diagnosticConeEligible) ? uint2(shadowMask):uint2(0u);")
  .replacingOccurrences(of:"bool diagnosticHighQuality=false;",with:"")
  .replacingOccurrences(of:"diagnosticHighQuality=true;",with:"nearLampMasks[panel]=shadowMask;")
  .replacingOccurrences(of:"diagnosticHighQuality=diagnosticHighQuality || diagnosticInside;",with:"if(diagnosticInside){nearLampMasks[panel] |= (1u<<diagnosticIndex);}")
  .replacingOccurrences(of:"diagnosticGlobalQuality=diagnosticGlobalQuality || diagnosticHighQuality;",with:"")
  .replacingOccurrences(of:"if(diagnosticGlobalQuality) {",with:"if(nearLampMasks[panel]!=0u) {")
  .replacingOccurrences(of:"uint remainingShadowBalls=shadowMask;",with:"uint remainingShadowBalls=nearLampMasks[panel];")
}
let lampCandidate=perLampMasks()
try need(!lampCandidate.contains("diagnosticGlobalQuality") && !lampCandidate.contains("diagnosticHighQuality"),"Lamp mask anchors")
func relativeBlockers(_ source:String,_ mask:String)throws->String {
 let bodyLoop=try unwrap(source.range(of:"for(int panel=0;panel<2;++panel) {",options:.backwards),"Final lamp loop")
 let preparation="""
uint nearPreparationMask=\(mask);
while(nearPreparationMask!=0u){
 uint nearIndex=ctz(nearPreparationMask);nearPreparationMask &= nearPreparationMask-1u;
 float4 nearBall=shadowBalls[nearIndex];
 shadowBalls[nearIndex].xyz=float3(nearBall.x,0.8+nearBall.z,nearBall.y)-p;
}
"""
 let old="float3 center=float3(shadowBall.x,0.8+shadowBall.z,shadowBall.y);\n    float3 toCenter=center-p;"
 try need(source.contains(old),"Blocker vector anchor")
 var result=source
 result.insert(contentsOf:preparation,at:bodyLoop.lowerBound)
 return result.replacingOccurrences(of:old,with:"float3 toCenter=shadowBall.xyz;")
}
func squaredBlockers(_ source:String,_ mask:String)throws->String {
 let relative=try relativeBlockers(source,mask)
 return relative
  .replacingOccurrences(of:"shadowBalls[nearIndex].xyz=float3(nearBall.x,0.8+nearBall.z,nearBall.y)-p;",with:"float3 nearVector=float3(nearBall.x,0.8+nearBall.z,nearBall.y)-p;shadowBalls[nearIndex]=float4(nearVector,dot(nearVector,nearVector));")
  .replacingOccurrences(of:"float4 shadowBall=shadowBalls[shadowIndex];",with:"""
float4 shadowBall=shadowBalls[shadowIndex];
uint nearColumn=shadowIndex&3u;
float shadowOpacity=shadowIndex<4u ? contactUniforms.contactGroup0[nearColumn].w :
 (shadowIndex<8u ? contactUniforms.contactGroup1[nearColumn].w :
 (shadowIndex<12u ? contactUniforms.contactGroup2[nearColumn].w : contactUniforms.contactGroup3[nearColumn].w));
""")
  .replacingOccurrences(of:"if(shadowBall.w>0.0)",with:"if(shadowOpacity>0.0)")
  .replacingOccurrences(of:"float perpendicular2=dot(toCenter,toCenter)-t*t;",with:"float perpendicular2=shadowBall.w-t*t;")
  .replacingOccurrences(of:"shadowBall.w/0.85",with:"shadowOpacity/0.85")
}
func constantArray(_ source:String)throws->String {
 let old="float4x4 contactGroup0;\nfloat4x4 contactGroup1;\nfloat4x4 contactGroup2;\nfloat4x4 contactGroup3;"
 let local="float4 shadowBalls[16]={"+(0..<16).map{"contactBall\($0)"}.joined(separator:",")+"};"
 try need(source.components(separatedBy:old).count==2 && source.components(separatedBy:local).count==2,"Constant array anchors")
 var result=source.replacingOccurrences(of:old,with:"float4 contactBalls[16];")
  .replacingOccurrences(of:local,with:"// H9: read original ball data directly from constant memory.")
 for i in 0..<16 {
  let entry="contactUniforms.contactGroup\(i/4)[\(i%4)]"
  try need(result.contains(entry),"Constant ball index \(i)")
  result=result.replacingOccurrences(of:entry,with:"contactUniforms.contactBalls[\(i)]")
 }
 result=result.replacingOccurrences(of:"shadowBalls[",with:"contactUniforms.contactBalls[")
 let domainSignature="legacyConeDomain(float3 p,thread const float4 *balls)"
 let domainCall="legacyConeDomain(p,shadowBalls)"
 try need(result.contains(domainSignature) && result.contains(domainCall),"Constant eligibility helper anchors")
 result=result.replacingOccurrences(of:domainSignature,with:"legacyConeDomain(float3 p,constant float4 *balls)")
  .replacingOccurrences(of:domainCall,with:"legacyConeDomain(p,contactUniforms.contactBalls)")
 try need(!result.contains("shadowBalls") && !result.contains("contactGroup"),"No local array remains")
 return result
}
func checkConstantArrayABI()throws {
 try need(MemoryLayout<SIMD4<Float>>.stride==16 && MemoryLayout<simd_float4x4>.stride==64,"Host ABI sizes")
 let code="""
 #include <metal_stdlib>
 using namespace metal;
 struct Old {float4x4 g0,g1,g2,g3;};
 struct New {float4 balls[16];};
 kernel void verifyLayout(constant Old& old [[buffer(0)]],constant New& newer [[buffer(1)]],device float4* out [[buffer(2)]],uint i [[thread_position_in_grid]]) {
  if(i>=16)return;
  uint column=i&3u;
  out[i]=i<4?old.g0[column]:(i<8?old.g1[column]:(i<12?old.g2[column]:old.g3[column]));
  out[16+i]=newer.balls[i];
 }
 """
 let library=try device.makeLibrary(source:code,options:nil)
 let pipeline=try device.makeComputePipelineState(function:try unwrap(library.makeFunction(name:"verifyLayout"),"Layout function"))
 let values=(0..<64).map{Float($0-32)/8.0}
 let input=try values.withUnsafeBytes {try unwrap(device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared),"Layout input")}
 let outputBuffer=try unwrap(device.makeBuffer(length:512,options:.storageModeShared),"Layout output")
 let queue=try unwrap(device.makeCommandQueue(),"Layout queue")
 let command=try unwrap(queue.makeCommandBuffer(),"Layout command")
 let encoder=try unwrap(command.makeComputeCommandEncoder(),"Layout encoder")
 encoder.setComputePipelineState(pipeline)
 encoder.setBuffer(input,offset:0,index:0);encoder.setBuffer(input,offset:0,index:1);encoder.setBuffer(outputBuffer,offset:0,index:2)
 encoder.dispatchThreads(MTLSize(width:16,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:16,height:1,depth:1));encoder.endEncoding()
 command.commit();command.waitUntilCompleted()
 try need(command.status == .completed,"Layout GPU completion")
 let result=outputBuffer.contents().bindMemory(to:Float.self,capacity:128)
 try need((0..<64).allSatisfy{result[$0]==values[$0] && result[64+$0]==values[$0]},"Old/new layout and sentinel values")
 try write(["device":device.name,"uniformBytes":256,"balls":16,"componentsPerRepresentation":64,"exact":true,"bothComparedToCPUSentinels":true],"constant-array-abi.json")
}
if experimentRound.hasPrefix("constant-") {try checkConstantArrayABI()}
let variants:[(String,String,Int)]=experimentRound=="constant-lamp" ? [("constant-lamp",try constantArray(lampCandidate),0)] : experimentRound=="constant-array" ? [("constant-array",try constantArray(baseline),0)] : experimentRound=="squared" ?
 [("squared-blockers",try squaredBlockers(baseline,"diagnosticGlobalQuality ? shadowMask:0u"),0),
  ("lamp-squared-blockers",try squaredBlockers(lampCandidate,"nearLampMasks.x | nearLampMasks.y"),0)] : experimentRound=="relative" ?
 [("relative-blockers",try relativeBlockers(baseline,"diagnosticGlobalQuality ? shadowMask:0u"),0),
  ("lamp-relative-blockers",try relativeBlockers(lampCandidate,"nearLampMasks.x | nearLampMasks.y"),0)] :
 experimentRound=="lamp-mask" ? [("per-lamp-mask",lampCandidate,0)] : experimentRound=="group2" ? [("group2-visible-direction",rowResponse(true,2),1)] : experimentRound=="row" ?
 [("row-center",rowResponse(false),1),("row-visible-direction",rowResponse(true),1)] :
 [("pair-center",sharedResponse(false),1),("endpoint-linear",sharedResponse(true),1),("zero-visibility",zeroVisibility,0)]
let headroom=pow(2.0,0.1)-1
let fragment="""
#pragma body
float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
"""
func install(_ scene:SceneFixture,_ source:String){for m in scene.mats{var mods=m.shaderModifiers ?? [:];mods[.surface]=source;mods[.fragment]=fragment;m.shaderModifiers=mods};SCNTransaction.flush()}
try baseline.write(to:output.appendingPathComponent("baseline.surface"),atomically:true,encoding:.utf8)
try write(["device":device.name,"os":ProcessInfo.processInfo.operatingSystemVersionString,"width":maxWidth,"additionalTextures":0,"baseline":"C1 default","scope":"native cloth, no ball geometry, no UI or physical shot"],"metadata.json")
var results=[[String:Any]]()
for (name,candidate,tolerance) in variants {
 try candidate.write(to:output.appendingPathComponent(name+".surface"),atomically:true,encoding:.utf8)
 for pose in ["single-low","single-near","scatter-overview"] {
  try autoreleasepool {
   let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7)
   for m in scene.mats{field.install(on:m)}
   var comparisons=[[String:Any]](),maximum=0,aaMax=0
   for frame in 0..<6 {
    let balls=input(scene,pose,frame)
    try need(balls.filter{$0.w>0}.allSatisfy{abs((0.8+$0.z)-0.828575)<1e-6},"Ball height")
    install(scene,baseline);_=try target.batch(3);let a=try target.read();_=try target.frame();let aa=try target.read()
    install(scene,candidate);_=try target.batch(3);let b=try target.read()
    let delta=difference(a,b),noise=difference(a,aa)
    maximum=max(maximum,delta["maximumChannelDifference"]!);aaMax=max(aaMax,noise["maximumChannelDifference"]!)
    try target.save(a,"\(name)-\(pose)-\(frame)-baseline");try target.save(b,"\(name)-\(pose)-\(frame)-candidate")
    comparisons.append(["frame":frame,"delta":delta,"aa":noise])
   }
   var times=[[String:Any]]()
   if maximum<=tolerance && aaMax==0 {
    for kind in ["AA","AB"] {for cycle in 0..<6 {for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
     install(scene,(kind=="AB" && arm) ? candidate:baseline);_=try target.batch(3)
     var samples=[FrameTime]()
     for frame in 0..<12 {_=input(scene,pose,frame%6);samples.append(try target.frame())}
     times.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","gpuMS":samples.map{$0.gpu},"cpuEncodeMS":samples.map{$0.encode},"wallMS":samples.map{$0.syncWall},"frames":samples.map{$0.json}])
    }}}
   }
   results.append(["variant":name,"pose":pose,"width":maxWidth,"maximumChannelDifference":maximum,"tolerance":tolerance,"comparisons":comparisons,"times":times])
   try write(results,"results.json");print("\(name) \(pose) maximum=\(maximum)")
  }
 }
}
