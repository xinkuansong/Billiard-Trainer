let shaderRoot=URL(fileURLWithPath:CommandLine.arguments[5])
let reference=try String(contentsOf:shaderRoot.appendingPathComponent("baseline.surface"),encoding:.utf8)
let emitter=String(reference[reference.range(of:"float3 v62EmitterCenter(")!.lowerBound..<reference.range(of:"float v62RectIrradiance(")!.lowerBound])
let candidate=try unwrap(StaticClothIrradiance.replacingDiffuse(in:reference),"Actual source transform")
let headroom=pow(2.0,0.1)-1
let fragment="""
#pragma body
float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
"""
// __HELPERS__
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
try candidate.write(to:output.appendingPathComponent("actual-candidate.surface"),atomically:true,encoding:.utf8)
try need(StaticClothIrradiance.requested(arguments:[]),"Phone preview must work on icon launch")
try need(StaticClothIrradiance.requested(arguments:[StaticClothIrradiance.launchArgument]),"Flag not accepted")
try need(!StaticClothIrradiance.requested(arguments:[StaticClothIrradiance.disableArgument]),"Baseline override lost")
try need(!StaticClothIrradiance.requested(arguments:[StaticClothIrradiance.launchArgument,StaticClothIrradiance.disableArgument]),"Disable must win")
try need(!StaticClothIrradiance.requested(arguments:[StaticClothIrradiance.launchArgument,"-rendering.referenceCloth"]),"Reference override lost")
try need(StaticClothIrradiance.replacingDiffuse(in:"#pragma body") == nil,"Drift must fail closed")
try need(StaticClothIrradiance.replacingDiffuse(in:candidate) == nil,"Duplicate transform")
for (e,r) in [(emitter+"\n",StaticClothIrradiance.expectedRadiance),(emitter,1.0)] {
 var rejected=false
 do {_ = try StaticClothIrradiance.acquire(emitter:e,radiance:r,device:device)}catch{rejected=true}
 try need(rejected,"Rig drift accepted")
}
weak var released:StaticClothIrradiance?
try autoreleasepool {
 let first=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device)
 let second=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device)
 try need(first === second,"Shared resource not reused")
 released=first
 try need(first.allocatedBytes<=2*1024*1024,"Field budget exceeded")
 try write(["sharedIdentity":true,"bytes":first.allocatedBytes,"prepareMS":first.preparationMilliseconds,"generationMS":first.generationMilliseconds],"resource.json")
}
try need(released == nil,"Weak cache retained last owner")
try write(["defaultOnDebug":true,"explicitOn":true,"baselineOverride":true,"referenceOverride":true,"driftRejected":true,"duplicateRejected":true,"rigDriftRejected":true,"lastOwnerReleased":true],"contracts.json")
let field=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device)
let colors:[(String,[Double])]=[("green",[48,155,32]),("tournamentBlue",[50,141,181]),("mistGray",[133,140,139]),("burgundy",[121,62,75]),("blueGray",[88,126,142]),("camel",[171,146,108])]
var comparisons=[[String:Any]](),largest=0,aaChanges=0
for pose in ["single-low","single-near","scatter-overview"] {
 try autoreleasepool {
  let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7)
  for m in scene.mats {field.install(on:m)}
  var variants=colors.map{($0.0,$0.1,Double(0.65),Double(-1))}
  if pose=="single-near" {variants += [("normal-zero",[48,155,32],0,-1),("normal-one",[48,155,32],1,-1),("rough-low",[48,155,32],0.65,0.05),("rough-high",[48,155,32],0.65,1)]}
  for (name,rgb,normal,roughness) in variants {
   for m in scene.mats {
    m.diffuse.contents=NSColor(srgbRed:rgb[0]/255,green:rgb[1]/255,blue:rgb[2]/255,alpha:1)
    m.multiply.contents=(name=="green" || name.hasPrefix("normal") || name.hasPrefix("rough")) ? NSColor(srgbRed:0.54,green:0.73,blue:0.54,alpha:1):NSColor.white
    m.normal.intensity=CGFloat(normal)
    if roughness>=0 {m.roughness.contents=Float(roughness)}
   }
   for state in [0,5] {
    _=input(scene,pose,state)
    install(scene,reference);_=try target.batch(2);let a=try target.read();_=try target.frame();let aa=try target.read()
    install(scene,candidate);_=try target.batch(2);let b=try target.read()
    let delta=difference(a,b),noise=difference(a,aa);largest=max(largest,delta["maximumChannelDifference"]!);aaChanges+=noise["changedPixels"]!
    let name="\(pose)-\(name)-\(state)"
    try target.save(a,name+"-reference");try target.save(b,name+"-candidate")
    comparisons.append(["name":name,"candidate":delta,"aa":noise])
   }
  }
 }
}
try write(["cases":comparisons,"maximumChannelDifference":largest,"aaChangedPixels":aaChanges,"experimentalQualityBound":1,"defaultProductionEnabled":false],"results.json")
try need(largest<=1 && aaChanges==0,"Expanded material quality bound failed")
print("Actual field code: resource contracts and \(comparisons.count) material comparisons passed; max channel difference \(largest)")
