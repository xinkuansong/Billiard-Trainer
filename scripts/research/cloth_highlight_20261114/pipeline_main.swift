try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let guardSource=try String(contentsOf:package.appendingPathComponent("candidate.surface"),encoding:.utf8)
let emitter=String(guardSource[guardSource.range(of:"float3 v62EmitterCenter(")!.lowerBound..<guardSource.range(of:"float v62RectIrradiance(")!.lowerBound])
let baseline=try unwrap(StaticClothIrradiance.replacingDiffuse(in:guardSource),"Current C1 baseline")
let field=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:repository.appendingPathComponent("QiuJi/Resources/StaticClothIrradiance-v1.bin"))
try baseline.write(to:output.appendingPathComponent("baseline.surface"),atomically:true,encoding:.utf8)
let headroom=pow(2.0,0.1)-1
let tone="""
float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
"""
func install(_ scene:SceneFixture,_ variant:String,_ diagnostic:String="") {
 for m in scene.mats {
  m.lightingModel=variant.hasPrefix("constant") ? .constant:.physicallyBased
  var mods=m.shaderModifiers ?? [:]
  mods[.surface]=baseline+diagnostic
  mods[.fragment]="#pragma body\n"+((variant.contains("emission") || !diagnostic.isEmpty) ? "_output.color.rgb=_surface.emission.rgb;\n":"")+tone
  m.shaderModifiers=mods
 }
 SCNTransaction.flush()
}
var results=[[String:Any]]()
for pose in ["single-low","single-near","scatter-overview"] {
 try autoreleasepool {
  let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7)
  for m in scene.mats {field.install(on:m)}
  for variant in ["pbr-emission","constant","constant-emission"] {
   var comparisons=[[String:Any]](),maximum=0,noiseMax=0
   for state in [0,5] {
    _=input(scene,pose,state)
    install(scene,"baseline");_=try target.batch(3);let a=try target.read();_=try target.frame();let aa=try target.read()
    install(scene,variant);_=try target.batch(3);let b=try target.read()
    let delta=difference(a,b),noise=difference(a,aa)
    maximum=max(maximum,delta["maximumChannelDifference"]!);noiseMax=max(noiseMax,noise["maximumChannelDifference"]!)
    try target.save(a,"\(pose)-\(state)-\(variant)-baseline");try target.save(b,"\(pose)-\(state)-\(variant)")
    comparisons.append(["state":state,"delta":delta,"aa":noise])
   }
   var diagnostics=[String:Any]()
   for (key,expr) in [("roughness","float3(_surface.roughness)"),("normal","n*0.5+0.5"),("ao","float3(_surface.ambientOcclusion)")] {
    let suffix="\n_surface.emission.rgb=\(expr);"
    install(scene,"baseline",suffix);_=try target.batch(2);let a=try target.read()
    install(scene,variant,suffix);_=try target.batch(2);let b=try target.read()
    diagnostics[key]=difference(a,b)
    try target.save(a,"\(pose)-\(variant)-\(key)-baseline");try target.save(b,"\(pose)-\(variant)-\(key)")
   }
   var times=[[String:Any]]()
   if maximum==0 && noiseMax==0 {
    for kind in ["AA","AB"] {for cycle in 0..<6 {for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
     install(scene,(kind=="AB" && arm) ? variant:"baseline");_=try target.batch(3)
     var samples=[FrameTime]()
     for frame in 0..<12 {_=input(scene,pose,frame%6);samples.append(try target.frame())}
     times.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","gpuMS":samples.map{$0.gpu},"cpuEncodeMS":samples.map{$0.encode},"wallMS":samples.map{$0.syncWall}])
    }}}
   }
   results.append(["pose":pose,"variant":variant,"width":maxWidth,"maximumChannelDifference":maximum,"comparisons":comparisons,"diagnostics":diagnostics,"times":times])
   try write(results,"results.json");print("\(pose) \(variant) maximum=\(maximum)")
  }
 }
}
