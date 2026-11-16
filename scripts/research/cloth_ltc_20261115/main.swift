// H18 changes only the cloth specular estimator; full production shadow loop survives.
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let guardSource=try String(contentsOf:package.appendingPathComponent("candidate.surface"),encoding:.utf8)
let emitter=String(guardSource[guardSource.range(of:"float3 v62EmitterCenter(")!.lowerBound..<guardSource.range(of:"float v62RectIrradiance(")!.lowerBound])
let c1=try unwrap(StaticClothIrradiance.replacingDiffuse(in:guardSource),"C1")
let baseline=try unwrap(ClothShadowProgram.replacingLocalBalls(in:c1),"Current H9 identity")
let field=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:repository.appendingPathComponent("QiuJi/Resources/StaticClothIrradiance-v1.bin"))
let fit=try JSONSerialization.jsonObject(with:Data(contentsOf:output.appendingPathComponent("fit.json"))) as! [String:Any]
let lw=fit["width"] as! Int,lh=fit["height"] as! Int
let lobeCount=fit["lobes"] as? Int ?? 1
var textures=[MTLTexture]()
for index in 0..<(lobeCount*2) {
 let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:lw,height:lh,mipmapped:false)
 d.storageMode = .shared;d.usage = .shaderRead
 let t=try unwrap(device.makeTexture(descriptor:d),"LTC table")
 let data=try Data(contentsOf:output.appendingPathComponent("ltc\(index).f32"))
 try need(data.count==lw*lh*16,"LUT length")
 data.withUnsafeBytes{t.replace(region:MTLRegionMake2D(0,0,lw,lh),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:lw*16)}
 textures.append(t)
}
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
let brdfStart=baseline.range(of:"float nl=max(0.001,dot(n,l));",options:.backwards)!
let weightStart=baseline.range(of:"float3 weighted=",range:brdfStart.upperBound..<baseline.endIndex)!
let brdf=String(baseline[brdfStart.lowerBound..<weightStart.lowerBound])
let loopStart=baseline.range(of:"for(int panel=0;panel<2;++panel) {",options:.backwards)!
let loopEnd=baseline.range(of:"E=temporalFieldDiffuse",range:loopStart.upperBound..<baseline.endIndex)!
let originalLoop=String(baseline[loopStart.lowerBound..<loopEnd.lowerBound])
let accumulation="S+=weighted*visibility*D*G*F/(4.0*nv*nl);"
let helpers=try String(contentsOf:output.appendingPathComponent("ltc.metal"),encoding:.utf8)
var setup="""
float3 h18T=v-n*dot(n,v);
if(dot(h18T,h18T)<1e-10)h18T=cross(abs(n.y)<0.9?float3(0,1,0):float3(1,0,0),n);
h18T=normalize(h18T);float3 h18B=cross(n,h18T);
constexpr sampler h18Sampler(coord::normalized,address::clamp_to_edge,filter::linear);
float2 h18UV=float2(clamp((_surface.roughness-0.4)/0.6,0.0,1.0),sqrt(1.0-clamp(nv,0.0,1.0)));
h18UV=(h18UV*float2(\(lw-1),\(lh-1))+0.5)/float2(\(lw),\(lh));
float4 h18A=h18Table0.sample(h18Sampler,h18UV),h18C=h18Table1.sample(h18Sampler,h18UV);
float3 h18WX=h18A.x*h18T+h18A.y*n,h18WY=h18A.z*h18B,h18WZ=h18A.w*h18T+h18C.x*n;
float h18Scale=h18C.y*h18A.z*(h18A.x*h18C.x-h18A.y*h18A.w)/3.14159265;
"""
if lobeCount==2 {setup+="""

float4 h18A2=h18Table2.sample(h18Sampler,h18UV),h18C2=h18Table3.sample(h18Sampler,h18UV);
float3 h18WX2=h18A2.x*h18T+h18A2.y*n,h18WY2=h18A2.z*h18B,h18WZ2=h18A2.w*h18T+h18C2.x*n;
float h18Scale2=h18C2.y*h18A2.z*(h18A2.x*h18C2.x-h18A2.y*h18A2.w)/3.14159265;
"""}
if fit["parameterEncoding"] as? Bool == true {
 for i in 0..<lobeCount {
  let suffix=i==0 ? "":"2",a="h18A\(i==0 ? "":"2")",b="h18C\(i==0 ? "":"2")"
  let old="float4 \(a)=h18Table\(i*2).sample(h18Sampler,h18UV),\(b)=h18Table\(i*2+1).sample(h18Sampler,h18UV);"
  let decoded="""
  float4 h18Parameters\(suffix)=h18Table\(i*2).sample(h18Sampler,h18UV);
  float h18Amplitude\(suffix)=h18Table\(i*2+1).sample(h18Sampler,h18UV).x;
  float h18Sin\(suffix)=sin(h18Parameters\(suffix).w),h18Cos\(suffix)=cos(h18Parameters\(suffix).w);
  float2 h18InverseScale\(suffix)=exp(-h18Parameters\(suffix).xy);
  float4 \(a)=float4((h18Cos\(suffix)-h18Parameters\(suffix).z*h18Sin\(suffix))*h18InverseScale\(suffix).x,(-h18Sin\(suffix)-h18Parameters\(suffix).z*h18Cos\(suffix))*h18InverseScale\(suffix).x,h18InverseScale\(suffix).y,h18Sin\(suffix));
  float4 \(b)=float4(h18Cos\(suffix),exp(h18Amplitude\(suffix)),0,0);
  """
  setup=try once(setup,old,decoded)
 }
}
func polygon(_ c:String,_ u:String,_ v:String)->String {
 let first="h18Polygon(\(c),\(u),\(v),h18WX,h18WY,h18WZ,h18C.y)"
 return lobeCount==1 ? first:"(\(first)+h18Polygon(\(c),\(u),\(v),h18WX2,h18WY2,h18WZ2,h18C2.y))"
}
func candidate(_ integral:Bool)throws->String {
 var weightCode="float3 h18Q=h18World(l,h18WX,h18WY,h18WZ);float h18Q2=dot(h18Q,h18Q);h18D=h18Scale*max(0.0,h18Q.z)/(h18Q2*h18Q2);"
 if lobeCount==2 {weightCode+="h18Q=h18World(l,h18WX2,h18WY2,h18WZ2);h18Q2=dot(h18Q,h18Q);h18D+=h18Scale2*max(0.0,h18Q.z)/(h18Q2*h18Q2);"}
 var loop=try once(originalLoop,brdf,"float h18D=0.0;\(integral ? "if(nearLampMasks[panel]!=0u){" : "{")\(weightCode)}\n")
 let solid="max(0.0,dot(v62EmitterNormal(panel),-l))/r2*cellArea*v62EmitterGain(panel)"
 if integral {
  loop=try once(loop,"int samplesX=", "float h18U=0.0,h18V=0.0;\n int samplesX=")
  loop=try once(loop,accumulation,"float h18W=h18D*\(solid);h18U+=h18W;h18V+=h18W*visibility;")
  let end=loop.lastIndex(of:"}")!
  loop.insert(contentsOf:"S+=float3(1,0.985,0.96)*(\(StaticClothIrradiance.expectedRadiance)/3.14159265)*v62EmitterGain(panel)*\(polygon("v62EmitterCenter(panel)-p","v62EmitterU(panel)","v62EmitterV(panel)"))*(nearLampMasks[panel]!=0u ? h18V/max(h18U,1e-12):1.0);\n",at:end)
  loop="""
  if(all(nearLampMasks==uint2(0u)) && dot(n,(v62EmitterCenter(0)+v62EmitterCenter(1))*0.5-p)>abs(dot(n,v62EmitterU(0)))+abs(dot(n,v62EmitterV(0)*2.0))+1e-5){
   E=float3(1.0);unoccludedE=float3(1.0);
   S=float3(1,0.985,0.96)*(\(StaticClothIrradiance.expectedRadiance)/3.14159265)*\(polygon("(v62EmitterCenter(0)+v62EmitterCenter(1))*0.5-p","v62EmitterU(0)","v62EmitterV(0)*2.0"));
  }else{\(loop)}
  """
 } else {
  loop=try once(loop,accumulation,"S+=float3(1,0.985,0.96)*(\(StaticClothIrradiance.expectedRadiance)/3.14159265)*h18D*\(solid)*visibility;")
 }
 var source=try once(baseline,originalLoop,"if(_surface.roughness>=0.4 && shadowPossible){\n\(setup)\n\(loop)\n}else{\n\(originalLoop)\n}")
 source=try once(source,"#pragma body",helpers+"\n#pragma body")
 let arguments=try unwrap(source.range(of:"#pragma arguments"),"Arguments section")
 source.insert(contentsOf:(0..<(lobeCount*2)).map{"\ntexture2d<float> h18Table\($0);"}.joined(),at:arguments.upperBound)
 return source
}
let variants=[("integral",try candidate(true))]
func noShadow(_ source:String)->String {
 // Keep all balls and near/far selection. Only alter evaluated visibility.
 source.replacingOccurrences(of:"float3 weighted=",with:"visibility=1.0;float3 weighted=")
}
for (name,source) in [("baseline",baseline)]+variants {try source.write(to:output.appendingPathComponent(name+".surface"),atomically:true,encoding:.utf8)}
var results=[[String:Any]]()
for pose in ["single-low","single-near","scatter-overview"] {
 try autoreleasepool {
  let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7)
  for m in scene.mats {field.install(on:m);for i in 0..<(lobeCount*2){m.setValue(SCNMaterialProperty(contents:textures[i]),forKey:"h18Table\(i)")}}
  for (name,source) in variants {
   var comparisons=[[String:Any]](),timings=[[String:Any]]()
   let originalRoughness=scene.mats.map{$0.roughness.contents}
   for shadows in [true,false] {for frame in 0..<22 {
    for (i,m) in scene.mats.enumerated(){m.roughness.contents=originalRoughness[i]}
    _=input(scene,pose,frame)
    if frame>=6 && frame<12 {
     let eye=scene.eye.simdPosition+SIMD3<Float>(Float(frame-9)*0.04,Float(frame%3)*0.04,Float(frame-9)*0.02)
     let delta=eye-SIMD3<Float>(0,0.8,0)
     scene.eye.simdTransform=ProductionPose.Pose.looking(eye:eye,yaw:atan2(delta.z,delta.x),pitch: -atan2(delta.y,sqrt(delta.x*delta.x+delta.z*delta.z)),fov:50).transform
    }
    if frame>=12 && frame<18 {for m in scene.mats {m.roughness.contents=Float([0.39,0.4,0.5,0.68,0.85,1.0][frame-12])}}
    if frame>=18 {
     var balls=input(scene,"scatter-overview",0)
     if frame==18 {balls=Array(repeating:SIMD4<Float>(0,0,0,0),count:16)}
     if frame==19 {balls[0].w=0;balls[1].w=0.425}
     if frame==20 {balls[0].z=0.07;balls[1].z=0.12}
     let data=balls.withUnsafeBytes{Data($0)}
     for m in scene.mats {m.setValue(data as NSData,forKey:"contactUniforms")}
     // Restore this pose; input(scatter) above is only a ball-layout generator.
     _=input(scene,pose,0)
     for m in scene.mats {m.setValue(data as NSData,forKey:"contactUniforms")}
    }
    SCNTransaction.flush()
    let aSource=shadows ? baseline:noShadow(baseline),bSource=shadows ? source:noShadow(source)
    install(scene,aSource);_=try target.batch(3);let a=try target.read();_=try target.frame();let aa=try target.read()
    install(scene,bSource);_=try target.batch(3);let b=try target.read()
    install(scene,aSource);_=try target.batch(3);let restored=try target.read()
    let delta=difference(a,b),noise=difference(a,aa),restore=difference(a,restored)
    try need(noise["maximumChannelDifference"]==0 && restore["maximumChannelDifference"]==0,"AA/restore drift")
    try target.save(a,"\(pose)-\(name)-\(shadows)-\(frame)-A");try target.save(b,"\(pose)-\(name)-\(shadows)-\(frame)-B")
    comparisons.append(["frame":frame,"shadows":shadows,"delta":delta,"aa":noise,"restore":restore])
   }}
   for (i,m) in scene.mats.enumerated(){m.roughness.contents=originalRoughness[i]}
   // R3 only ranks candidates which pass this expanded visual scope.
   if measurePerformance && comparisons.allSatisfy({(($0["delta"] as! [String:Int])["maximumChannelDifference"] ?? 999)<=1}) {
   for kind in ["AA","AB"] {for cycle in 0..<6 {for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
    install(scene,kind=="AB" && arm ? source:baseline);_=try target.batch(6)
    var samples=[FrameTime]()
    for f in 0..<12 {_=input(scene,pose,f%6);samples.append(try target.frame())}
    timings.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","frames":samples.map{$0.json},"gpuMS":samples.map{$0.gpu},"cpuEncodeMS":samples.map{$0.encode}])
   }}}}
   let row:[String:Any]=["pose":pose,"variant":name,"width":target.w,"height":target.h,"lutAllocatedBytes":textures.reduce(0){$0+$1.allocatedSize},"comparisons":comparisons,"times":timings]
   results.append(row);try write(results,"results.json")
   print("\(pose) \(name) quality max=\(comparisons.map{(($0["delta"] as! [String:Int])["maximumChannelDifference"]!)} )",terminator:"\n");fflush(stdout)
  }
 }
}
