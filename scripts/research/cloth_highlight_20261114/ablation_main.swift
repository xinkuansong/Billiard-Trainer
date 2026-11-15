try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let guardSource=try String(contentsOf:package.appendingPathComponent("candidate.surface"),encoding:.utf8)
let emitter=String(guardSource[guardSource.range(of:"float3 v62EmitterCenter(")!.lowerBound..<guardSource.range(of:"float v62RectIrradiance(")!.lowerBound])
let baseline=try unwrap(StaticClothIrradiance.replacingDiffuse(in:guardSource),"C1 baseline")
let diffuseField=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:repository.appendingPathComponent("QiuJi/Resources/StaticClothIrradiance-v1.bin"))
let fields:[MTLTexture]=[]
let loop=try unwrap(baseline.range(of:"for(int panel=0;panel<2;++panel) {",options:.backwards),"Loop")
let end=try unwrap(baseline.range(of:"E=temporalFieldDiffuse",range:loop.upperBound..<baseline.endIndex),"Diffuse end")
let oldLoop=String(baseline[loop.lowerBound..<end.lowerBound])
try need(oldLoop.contains("int samplesX=shadowPossible?8:2;") && oldLoop.contains("int samplesZ=shadowPossible?4:2;"),"Sampling anchor drift")

let specTerm="S+=weighted*visibility*D*G*F/(4.0*nv*nl);"
try need(baseline.contains(specTerm),"Specular anchor drift")
let variants:[(String,String)]=[
 ("far-loop-off",baseline.replacingOccurrences(of:oldLoop,with:"if(shadowPossible){\n"+oldLoop+"\n}else{E=float3(1.0);unoccludedE=float3(1.0);S=float3(0.0);}")),
 ("all-specular-off",baseline.replacingOccurrences(of:specTerm,with:"")),
 ("all-loop-off",baseline.replacingOccurrences(of:oldLoop,with:"E=float3(1.0);unoccludedE=float3(1.0);S=float3(0.0);")),
 ("pbr-emission",baseline)
]
try baseline.write(to:output.appendingPathComponent("baseline.surface"),atomically:true,encoding:.utf8)
for (name,source) in variants {try source.write(to:output.appendingPathComponent(name+".surface"),atomically:true,encoding:.utf8)}
let headroom=pow(2.0,0.1)-1
let fragment="""
#pragma body
float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
"""
func install(_ scene:SceneFixture,_ source:String,_ emissionOnly:Bool=false){for m in scene.mats{var mods=m.shaderModifiers ?? [:];mods[.surface]=source;mods[.fragment]=emissionOnly ? fragment.replacingOccurrences(of:"#pragma body",with:"#pragma body\n_output.color.rgb=_surface.emission.rgb;") : fragment;m.shaderModifiers=mods};SCNTransaction.flush()}
var results=[[String:Any]]()
for (variant,candidate) in variants {
for pose in ["single-low","single-near","scatter-overview"] {
 try autoreleasepool {
  let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7)
  for m in scene.mats{diffuseField.install(on:m);for(i,f) in fields.enumerated(){m.setValue(SCNMaterialProperty(contents:f),forKey:"sampleField\(i)")}}
  var comparisons=[[String:Any]](),maximum=0,aaMax=0
  for frame in 0..<6 {
   _=input(scene,pose,frame)
   install(scene,baseline);_=try target.batch(3);let a=try target.read();_=try target.frame();let aa=try target.read()
   install(scene,candidate,variant=="pbr-emission");_=try target.batch(3);let b=try target.read()
   let delta=difference(a,b),noise=difference(a,aa)
   maximum=max(maximum,delta["maximumChannelDifference"]!);aaMax=max(aaMax,noise["maximumChannelDifference"]!)
   try target.save(a,"\(variant)-\(pose)-\(frame)-baseline");try target.save(b,"\(variant)-\(pose)-\(frame)-candidate")
   comparisons.append(["frame":frame,"delta":delta,"aa":noise])
  }
  var times=[[String:Any]]()
  if aaMax==0 {
   for kind in ["AA","AB"] {for cycle in 0..<6 {for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
    install(scene,(kind=="AB" && arm) ? candidate:baseline,kind=="AB" && arm && variant=="pbr-emission");_=try target.batch(3)
    var samples=[FrameTime]()
    for frame in 0..<12 {_=input(scene,pose,frame%6);samples.append(try target.frame())}
    times.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","gpuMS":samples.map{$0.gpu},"cpuEncodeMS":samples.map{$0.encode},"wallMS":samples.map{$0.syncWall}])
   }}}
  }
  results.append(["diagnosticOnly":true,"variant":variant,"pose":pose,"width":maxWidth,"maximumChannelDifference":maximum,"comparisons":comparisons,"times":times])
  try write(results,"results.json");print("\(variant) \(pose) maximum=\(maximum)")
 }
}

}
