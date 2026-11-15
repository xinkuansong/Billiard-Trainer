try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let guardSource=try String(contentsOf:package.appendingPathComponent("candidate.surface"),encoding:.utf8)
let emitter=String(guardSource[guardSource.range(of:"float3 v62EmitterCenter(")!.lowerBound..<guardSource.range(of:"float v62RectIrradiance(")!.lowerBound])
let c1=try unwrap(StaticClothIrradiance.replacingDiffuse(in:guardSource),"C1 source")
let baseline=try unwrap(ClothShadowProgram.replacingLocalBalls(in:c1),"Current production H9 source")
let field=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:repository.appendingPathComponent("QiuJi/Resources/StaticClothIrradiance-v1.bin"))
let brdfStart=try unwrap(baseline.range(of:"float nl=max(0.001,dot(n,l));",options:.backwards),"BRDF start")
let brdfEnd=try unwrap(baseline.range(of:"float3 weighted=",range:brdfStart.upperBound..<baseline.endIndex),"BRDF end")
let brdf=String(baseline[brdfStart.lowerBound..<brdfEnd.lowerBound])
let weightedEnd=try unwrap(baseline.range(of:"unoccludedE+=weighted; E+=weighted*visibility;",range:brdfEnd.lowerBound..<baseline.endIndex),"Diffuse accumulation")
let weight=String(baseline[brdfEnd.lowerBound..<weightedEnd.lowerBound])
let accumulation="S+=weighted*visibility*D*G*F/(4.0*nv*nl);"
let loopAnchor="for(int ix=0;ix<samplesX;++ix) {"
try need(baseline.components(separatedBy:accumulation).count==2 && baseline.components(separatedBy:loopAnchor).count==2,"Unique H9 loop anchors")

func separation(_ nx:Int,_ nz:Int)throws->String {
 let preparation="""
 // H10: unoccluded quadrature plus same-sample visibility correction.
 if(shadowPossible) {
  float cellArea=v62EmitterArea(panel)/float(\(nx*nz));
  for(int sx=0;sx<\(nx);++sx) {for(int sz=0;sz<\(nz);++sz) {
   float3 lp=v62EmitterCenter(panel)+v62EmitterU(panel)*(2.0*(float(sx)+0.5)/float(\(nx))-1.0)+v62EmitterV(panel)*(2.0*(float(sz)+0.5)/float(\(nz))-1.0);
   float3 delta=lp-p;float r2=dot(delta,delta);float3 l=delta/sqrt(r2);
   \(brdf)
   \(weight)
   S+=weighted*D*G*F/(4.0*nv*nl);
  }}
 }
 """
 let replacement="""
 if(shadowPossible) {
  if(visibility<1.0) {
   \(brdf)
   S+=weighted*(visibility-1.0)*D*G*F/(4.0*nv*nl);
  }
 } else {
  \(brdf)
  \(accumulation)
 }
 """
 var source=baseline.replacingOccurrences(of:brdf,with:"")
 source=source.replacingOccurrences(of:accumulation,with:replacement)
 source=source.replacingOccurrences(of:loopAnchor,with:preparation+"\n"+loopAnchor)
 try need(source.contains("if(nearLampMasks[panel]!=0u)") && source.contains("visibility-1.0"),"H9 visibility coupling preserved")
 return source
}

func unoccludedOnly(_ nx:Int,_ nz:Int,_ roughnessFloor:Float?=nil)throws->String {
 // Retain the original diffuse quadrature, including its 1e-6 denominator.
 // The eligibility condition affects only the specular approximation.
 let gate="bool separatedUnoccluded=shadowPossible && nearLampMasks.x==0u && nearLampMasks.y==0u" + (roughnessFloor.map{" && _surface.roughness>=\($0)"} ?? "") + ";\n"
 var source=try separation(nx,nz)
 let finalLampLoop=try unwrap(source.range(of:"for(int panel=0;panel<2;++panel) {",options:.backwards),"Final H9 lamp loop")
 source.insert(contentsOf:gate,at:finalLampLoop.lowerBound)
 source=source.replacingOccurrences(of:"// H10: unoccluded quadrature plus same-sample visibility correction.\nif(shadowPossible)",with:"// H10 R2: approximate only where both H9 masks prove no blockers.\nif(separatedUnoccluded)")
 let correction="""
if(shadowPossible) {
 if(visibility<1.0) {
  \(brdf)
  S+=weighted*(visibility-1.0)*D*G*F/(4.0*nv*nl);
 }
} else {
 \(brdf)
 \(accumulation)
}
"""
 try need(source.components(separatedBy:correction).count==2,"Correction replacement anchor")
 source=source.replacingOccurrences(of:correction,with:"if(!separatedUnoccluded){\n\(brdf)\(accumulation)\n}")
 try need(source.contains("if(separatedUnoccluded)") && !source.contains("visibility-1.0"),"Unoccluded path and original occluded BRDF")
 return source
}

let variants:[(String,String,Bool)] = experimentRound=="refine" ? [
 ("unoccluded16",try unoccludedOnly(4,2),false),
 ("unoccluded8",try unoccludedOnly(2,2),false)
] : experimentRound=="final" ? [
 ("unoccluded16-rough",try unoccludedOnly(4,2,0.5),false),
 ("unoccluded8-rough",try unoccludedOnly(2,2,0.5),false)
] : [
 ("same64-control",try separation(8,4),true),
 ("base32-correction64",try separation(8,2),false),
 ("base16-correction64",try separation(4,2),false)
]
let headroom=pow(2.0,0.1)-1
let fragment="""
#pragma body
float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
"""
func install(_ scene:SceneFixture,_ source:String){for m in scene.mats{var mods=m.shaderModifiers ?? [:];mods[.surface]=source;mods[.fragment]=fragment;m.shaderModifiers=mods};SCNTransaction.flush()}
try baseline.write(to:output.appendingPathComponent("baseline.surface"),atomically:true,encoding:.utf8)
try write(["device":device.name,"os":ProcessInfo.processInfo.operatingSystemVersionString,"width":maxWidth,"additionalTextures":0,"additionalUniformBytes":0,"baseline":"C1 + H9 production","scope":"native cloth and imported table; no ball geometry, room, UI or physical shot"],"metadata.json")
var results=[[String:Any]]()
for (name,candidate,diagnostic) in variants {
 try candidate.write(to:output.appendingPathComponent(name+".surface"),atomically:true,encoding:.utf8)
 var qualifying=true,controlsValid=true,variantResults=[[String:Any]]()
 // Qualify all three poses before starting a timing batch.
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
   if experimentRound != "initial" && pose=="single-near" {
    let original=scene.mats.map{$0.roughness.contents}
    let challenges:[(String,Float,Float)] = [("normal-zero",0,-1),("normal-one",1,-1),("rough-low",0.65,0.05),("rough-high",0.65,1)] + (experimentRound=="final" ? [("rough-below",0.65,0.4999),("rough-edge",0.65,0.5),("rough-above",0.65,0.5001),("rough-mid",0.65,0.65)] : [])
    for (label,normal,roughness) in challenges {
     for (i,m) in scene.mats.enumerated(){m.normal.intensity=CGFloat(normal);m.roughness.contents=roughness<0 ? original[i]:roughness}
     _=input(scene,pose,0)
     install(scene,baseline);_=try target.batch(3);let a=try target.read();_=try target.frame();let aa=try target.read()
     install(scene,candidate);_=try target.batch(3);let b=try target.read()
     let delta=difference(a,b),noise=difference(a,aa)
     maximum=max(maximum,delta["maximumChannelDifference"]!);aaMax=max(aaMax,noise["maximumChannelDifference"]!)
     try target.save(a,"\(name)-\(label)-baseline");try target.save(b,"\(name)-\(label)-candidate")
     comparisons.append(["challenge":label,"delta":delta,"aa":noise])
    }
   }
   qualifying = qualifying && maximum<=1 && aaMax==0
   controlsValid = controlsValid && maximum<=1 && aaMax==0
   variantResults.append(["variant":name,"pose":pose,"width":maxWidth,"diagnosticOnly":diagnostic,"maximumChannelDifference":maximum,"tolerance":1,"comparisons":comparisons,"times":[[String:Any]]()])
   try write(results+variantResults,"results.json")
   print("\(name) \(pose) maximum=\(maximum) AA=\(aaMax)");fflush(stdout)
  }
 }
 if diagnostic {try need(controlsValid,"Same-grid algebraic control failed")}
 if qualifying && !diagnostic {
  for index in variantResults.indices {
   let pose=variantResults[index]["pose"] as! String
   try autoreleasepool {
    let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7)
    for m in scene.mats{field.install(on:m)}
    _=input(scene,pose,0)
    // Force both programs to compile before collecting either timing arm.
    install(scene,baseline);_=try target.batch(4)
    install(scene,candidate);_=try target.batch(4)
    var times=[[String:Any]]()
    for kind in ["AA","AB"] {for cycle in 0..<6 {for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
     install(scene,(kind=="AB" && arm) ? candidate:baseline);_=try target.batch(3)
     var samples=[FrameTime]()
     for frame in 0..<24 {_=input(scene,pose,frame%6);samples.append(try target.frame())}
     times.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","gpuMS":samples.map{$0.gpu},"cpuEncodeMS":samples.map{$0.encode},"wallMS":samples.map{$0.syncWall},"frames":samples.map{$0.json}])
    }}}
    variantResults[index]["times"]=times
    try write(results+variantResults,"results.json")
    print("\(name) \(pose) timing complete");fflush(stdout)
   }
  }
 }
 results += variantResults
 try write(results,"results.json")
}
