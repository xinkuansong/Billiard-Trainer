try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let guardSource=try String(contentsOf:package.appendingPathComponent("candidate.surface"),encoding:.utf8)
let emitter=String(guardSource[guardSource.range(of:"float3 v62EmitterCenter(")!.lowerBound..<guardSource.range(of:"float v62RectIrradiance(")!.lowerBound])
let baseline=try unwrap(StaticClothIrradiance.replacingDiffuse(in:guardSource),"C1 baseline")
let diffuseField=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:repository.appendingPathComponent("QiuJi/Resources/StaticClothIrradiance-v1.bin"))
let width=sampleFieldWidth,height=sampleFieldHeight,depth=sampleFieldDepth
let start=CACurrentMediaTime()
let descriptor=MTLTextureDescriptor()
descriptor.textureType = .type3D;descriptor.pixelFormat = sampleFieldFormat
descriptor.width=width;descriptor.height=height;descriptor.depth=depth
descriptor.storageMode = .shared;descriptor.usage=[.shaderRead,.shaderWrite]
let fields=try (0..<8).map{i in try unwrap(device.makeTexture(descriptor:descriptor),"Sample field \(i)")}
let textureArgs=(0..<8).map{"texture3d<float,access::write> f\($0) [[texture(\($0))]]"}.joined(separator:",")
let writes=(0..<8).map{"if(i==\($0)) f\($0).write(float4(l,w),id);"}.joined(separator:"\n")
let generator="""
#include <metal_stdlib>
using namespace metal;
\(emitter)
kernel void generate(\(textureArgs),uint3 id [[thread_position_in_grid]]) {
 uint3 size=uint3(f0.get_width(),f0.get_height(),f0.get_depth());if(any(id>=size))return;
 float3 g=float3(id)/float3(size-1),p=float3(-1.6+3.2*g.x,0.65+0.25*g.z,-0.95+1.9*g.y);
 for(int i=0;i<8;++i){int panel=i/4,ix=(i%4)/2,iz=i%2;
  float3 lp=v62EmitterCenter(panel)+v62EmitterU(panel)*(float(ix)-0.5)+v62EmitterV(panel)*(float(iz)-0.5);
  float3 delta=lp-p;float r2=dot(delta,delta);float3 l=delta/sqrt(r2);
  float w=max(0.0,dot(v62EmitterNormal(panel),-l))/r2*(v62EmitterArea(panel)/4.0)*v62EmitterGain(panel);
  \(writes)
 }
}
"""
try generator.write(to:output.appendingPathComponent("generator.metal"),atomically:true,encoding:.utf8)
let library=try device.makeLibrary(source:generator,options:nil)
let pipeline=try device.makeComputePipelineState(function:unwrap(library.makeFunction(name:"generate"),"Generator"))
let queue=try unwrap(device.makeCommandQueue(),"Queue"),cb=try unwrap(queue.makeCommandBuffer(),"Command"),encoder=try unwrap(cb.makeComputeCommandEncoder(),"Encoder")
encoder.setComputePipelineState(pipeline)
for(i,texture) in fields.enumerated(){encoder.setTexture(texture,index:i)}
encoder.dispatchThreads(MTLSize(width:width,height:height,depth:depth),threadsPerThreadgroup:MTLSize(width:8,height:4,depth:4))
encoder.endEncoding();cb.commit();cb.waitUntilCompleted();try done(cb)
try write(["bytes":fields.reduce(0){$0+$1.allocatedSize},"pixelFormat":sampleFieldFormat.rawValue,"prepareIncludingCompileMS":(CACurrentMediaTime()-start)*1000,"generationGPU_MS":(cb.gpuEndTime-cb.gpuStartTime)*1000,"dimensions":[width,height,depth]],"resources.json")
let declarations="#pragma arguments\n"+(0..<8).map{"texture3d<float> sampleField\($0);\n"}.joined()
var far="""
float3 fieldGrid=float3((p.x+1.6)/3.2,(p.z+0.95)/1.9,(p.y-0.65)/0.25);
float3 fieldSize=float3(\(width),\(height),\(depth));float3 fieldUV=(fieldGrid*(fieldSize-1.0)+0.5)/fieldSize;
constexpr sampler fieldSampler(coord::normalized,address::clamp_to_edge,filter::linear);
"""
for i in 0..<8 {
 far += """
 {
 float4 geometry=sampleField\(i).sample(fieldSampler,fieldUV,level(0));float3 l=geometry.xyz;
 float nl=max(0.001,dot(n,l));float3 h=normalize(l+v);float nh=max(0.0,dot(n,h));float vh=max(0.0,dot(v,h));
 float denom=nh*nh*(a2-1.0)+1.0;float D=a2/(3.14159265*denom*denom);
 float G=2.0*nv/(nv+sqrt(a2+(1.0-a2)*nv*nv))*2.0*nl/(nl+sqrt(a2+(1.0-a2)*nl*nl));
 float F=0.012+0.988*pow(1.0-vh,5.0);
 float3 weighted=float3(1,0.985,0.96)*(12.96944123374527/3.14159265)*max(0.0,dot(n,l))*geometry.w;
 unoccludedE+=weighted;E+=weighted;S+=weighted*D*G*F/(4.0*nv*nl);
 }
 """
}
let loop=try unwrap(baseline.range(of:"for(int panel=0;panel<2;++panel) {",options:.backwards),"Loop")
let end=try unwrap(baseline.range(of:"E=temporalFieldDiffuse",range:loop.upperBound..<baseline.endIndex),"Diffuse end")
let oldLoop=String(baseline[loop.lowerBound..<end.lowerBound])
let eligible="!shadowPossible && all(isfinite(p)) && p.x>=-1.6 && p.x<=1.6 && p.z>=-0.95 && p.z<=0.95 && p.y>=0.65 && p.y<=0.9"
let candidate=declarations+baseline.replacingOccurrences(of:oldLoop,with:"if(\(eligible)){\n"+far+"\n}else{\n"+oldLoop+"\n}\n")
try baseline.write(to:output.appendingPathComponent("baseline.surface"),atomically:true,encoding:.utf8)
try candidate.write(to:output.appendingPathComponent("candidate.surface"),atomically:true,encoding:.utf8)
let headroom=pow(2.0,0.1)-1
let fragment="""
#pragma body
float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
"""
func install(_ scene:SceneFixture,_ source:String){for m in scene.mats{var mods=m.shaderModifiers ?? [:];mods[.surface]=source;mods[.fragment]=fragment;m.shaderModifiers=mods};SCNTransaction.flush()}
var results=[[String:Any]]()
for pose in ["single-low","single-near","scatter-overview"] {
 try autoreleasepool {
  let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7)
  for m in scene.mats{diffuseField.install(on:m);for(i,f) in fields.enumerated(){m.setValue(SCNMaterialProperty(contents:f),forKey:"sampleField\(i)")}}
  var comparisons=[[String:Any]](),maximum=0,aaMax=0
  for frame in 0..<6 {
   _=input(scene,pose,frame)
   install(scene,baseline);_=try target.batch(3);let a=try target.read();_=try target.frame();let aa=try target.read()
   install(scene,candidate);_=try target.batch(3);let b=try target.read()
   let delta=difference(a,b),noise=difference(a,aa)
   maximum=max(maximum,delta["maximumChannelDifference"]!);aaMax=max(aaMax,noise["maximumChannelDifference"]!)
   try target.save(a,"\(pose)-\(frame)-baseline");try target.save(b,"\(pose)-\(frame)-candidate")
   comparisons.append(["frame":frame,"delta":delta,"aa":noise])
  }
  var times=[[String:Any]]()
  if maximum<=1 && aaMax==0 {
   for kind in ["AA","AB"] {for cycle in 0..<6 {for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
    install(scene,(kind=="AB" && arm) ? candidate:baseline);_=try target.batch(3)
    var samples=[FrameTime]()
    for frame in 0..<12 {_=input(scene,pose,frame%6);samples.append(try target.frame())}
    times.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","gpuMS":samples.map{$0.gpu},"cpuEncodeMS":samples.map{$0.encode},"wallMS":samples.map{$0.syncWall}])
   }}}
  }
  results.append(["pose":pose,"width":maxWidth,"maximumChannelDifference":maximum,"comparisons":comparisons,"times":times])
  try write(results,"results.json");print("\(pose) maximum=\(maximum)")
 }
}
