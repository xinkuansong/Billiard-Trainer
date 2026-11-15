try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let original=try String(contentsOf:package.appendingPathComponent("candidate.surface"),encoding:.utf8)
let emitter=String(original[original.range(of:"float3 v62EmitterCenter(")!.lowerBound..<original.range(of:"float v62RectIrradiance(")!.lowerBound])
let c1=try unwrap(StaticClothIrradiance.replacingDiffuse(in:original),"C1 source")
let baseline=try unwrap(ClothShadowProgram.replacingLocalBalls(in:c1),"H9 source")
let field=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:repository.appendingPathComponent("QiuJi/Resources/StaticClothIrradiance-v1.bin"))
enum StateMode:String {
 case reference,domain,coefficients,active,activeCoefficients,compact,compactCoefficients
 var coefficients:Bool {self == .coefficients || self == .activeCoefficients || self == .compactCoefficients}
 var active:Bool {self == .active || self == .activeCoefficients || compact}
 var compact:Bool {self == .compact || self == .compactCoefficients}
}
func replaceOnce(_ s:String,_ from:String,_ to:String)throws->String {
 try need(s.components(separatedBy:from).count==2,"Unique source anchor: \(from.prefix(70))")
 return s.replacingOccurrences(of:from,with:to)
}
func candidate(_ mode:StateMode)throws->String {
 var source=try replaceOnce(baseline,"float4 contactBalls[16];","float4 contactBalls[16];\nfloat4 stateMeta;"+(mode.coefficients ? "\nfloat4 coefficients[16];":""))
 let start=try unwrap(source.range(of:"    for(int i=0;i<16;++i) {"),"Domain loop")
 let end=try unwrap(source.range(of:"    return true;",range:start.upperBound..<source.endIndex),"Domain end")
 source.replaceSubrange(start.lowerBound..<end.upperBound,with:"    return ballDomain>0.0;")
 source=try replaceOnce(source,"legacyConeDomain(float3 p,constant float4 *balls)","legacyConeDomain(float3 p,float ballDomain)")
 source=try replaceOnce(source,"legacyConeDomain(p,contactUniforms.contactBalls)","legacyConeDomain(p,contactUniforms.stateMeta.x)")
 if mode.coefficients {
  for i in 0..<16 {
   source=try replaceOnce(source,"contactBall\(i).z * contactBall\(i).z","contactUniforms.coefficients[\(i)].x")
   source=try replaceOnce(source,"(contactBall\(i).w / 0.85) * 0.0008165306 * contactBall\(i).z","contactUniforms.coefficients[\(i)].y")
  }
  source=try replaceOnce(source,"min(1.0,shadowBall.w/0.85)","contactUniforms.coefficients[shadowIndex].z")
 }
 if mode.active {
  let aoStart=try unwrap(source.range(of:"float4 contactBall0 ="),"AO beginning")
  let aoEnd=try unwrap(source.range(of:"_surface.ambientOcclusion = contactVisibility;"),"AO ending")
  let height=mode.coefficients ? "contactUniforms.coefficients[ballIndex].x":"ball.z * ball.z"
  let coefficient=mode.coefficients ? "contactUniforms.coefficients[ballIndex].y":"(ball.w / 0.85) * 0.0008165306 * ball.z"
  source.replaceSubrange(aoStart.lowerBound..<aoEnd.lowerBound,with:"""
uint activeBalls=uint(contactUniforms.stateMeta.y);
uint aoRemaining=activeBalls;
while(aoRemaining!=0u) {
 uint ballIndex=ctz(aoRemaining);aoRemaining &= aoRemaining-1u;
 float4 ball=contactUniforms.contactBalls[ballIndex];
 float2 offset=contactWorld.xz-ball.xy;
 float inverseDistance=rsqrt(dot(offset,offset)+\(height));
 contactVisibility *= 1.0 - \(coefficient) * inverseDistance * inverseDistance * inverseDistance;
}

""")
  let support="""
float top=ball.z+0.028575;
float bound=0.028575+top/max(0.01,2.2-top)*(length(ball.xy)+3.0931346330254206);
float2 offset=p.xz-ball.xy;
"""
  let possibleStart=try unwrap(source.range(of:"bool shadowPossible=false;"),"Near choice start")
  let possibleEnd=try unwrap(source.range(of:"bool diagnosticConeEligible="),"Near choice end")
  source.replaceSubrange(possibleStart.lowerBound..<possibleEnd.lowerBound,with:"""
bool shadowPossible=false;
uint possibleRemaining=activeBalls;
while(possibleRemaining!=0u) {
 uint ballIndex=ctz(possibleRemaining);possibleRemaining &= possibleRemaining-1u;
 float4 ball=contactUniforms.contactBalls[ballIndex];
 \(support)
 if(top>=2.2 || dot(offset,offset)<=bound*bound) {shadowPossible=true;break;}
}

""")
  let maskStart=try unwrap(source.range(of:"uint shadowMask=0u;"),"Mask start")
  let maskEnd=try unwrap(source.range(of:"uint2 nearLampMasks="),"Mask end")
  source.replaceSubrange(maskStart.lowerBound..<maskEnd.lowerBound,with:"""
uint shadowMask=0u;
if(shadowPossible) {
 bool belowBed=p.y<0.8;
 bool receiverCanPrune=belowBed && (as_type<uint>(p.y)&0x80000000u)==0u && p.y>=0.0
     && abs(p.x)<=2.5399999618530273 && abs(p.z)<=1.2699999809265137;
 uint maskRemaining=activeBalls;
 while(maskRemaining!=0u) {
  uint ballIndex=ctz(maskRemaining);maskRemaining &= maskRemaining-1u;
  float4 ball=contactUniforms.contactBalls[ballIndex];
  \(support)
  if(top>=2.2 || dot(offset,offset)<=bound*bound || (belowBed && (!diagnosticConeEligible || !receiverCanPrune || height_safe_ball_mask(p,ball)))) shadowMask |= (1u<<ballIndex);
 }
}

""")
  try need(!source.contains("contactBall0"),"No unrolled slot dependency remains")
 }
 if mode.compact {
  source=try replaceOnce(source,"float4 stateMeta;","float4 stateMeta;\nfloat4 preparedBalls[16];")
  source=source.replacingOccurrences(of:"contactUniforms.contactBalls[",with:"contactUniforms.preparedBalls[")
  source=try replaceOnce(source,"uint activeBalls=uint(contactUniforms.stateMeta.y);","uint activeCount=uint(contactUniforms.stateMeta.y);")
  for prefix in ["ao","possible","mask"] {
   let old="uint \(prefix)Remaining=activeBalls;\n"+(prefix=="mask" ? " ":"")+"while(\(prefix)Remaining!=0u) {\n"+(prefix=="mask" ? "  ":" ")+"uint ballIndex=ctz(\(prefix)Remaining);\(prefix)Remaining &= \(prefix)Remaining-1u;"
   source=try replaceOnce(source,old,"for(uint ballIndex=0u;ballIndex<activeCount;++ballIndex) {")
  }
 }
 return source
}
let modes:[StateMode]=experimentRound=="initial" ? [.domain,.coefficients]:(experimentRound=="active" ? [.active,.activeCoefficients]:[.compact,.compactCoefficients])
let variants:[(StateMode,String,Int)]=try modes.map{($0,try candidate($0),$0.coefficients ? 1:0)}
let headroom=pow(2.0,0.1)-1
let fragment="""
#pragma body
float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
"""
func install(_ scene:SceneFixture,_ source:String,_ outputFragment:String?=nil){for m in scene.mats{var mods=m.shaderModifiers ?? [:];mods[.surface]=source;mods[.fragment]=outputFragment ?? fragment;m.shaderModifiers=mods};SCNTransaction.flush()}
func pose(_ scene:SceneFixture,_ name:String) {
 scene.eye.simdPosition=name=="single-near" ? SIMD3(0.16,1.15,0.3):(name=="single-low" ? SIMD3(0,1.05,1.8):SIMD3(1.8,2.7,2.1))
 scene.eye.simdLook(at:SIMD3(0,0.8,0));SCNTransaction.flush()
}
func ballState(_ pose:String,_ frame:Int)->[SIMD4<Float>] {
 let points:[SIMD2<Float>]=pose=="scatter-overview" ? [-0.9,-0.3,0.3,0.9].flatMap{x in [-0.45,-0.15,0.15,0.45].map{z in SIMD2<Float>(Float(x),Float(z))}}:[SIMD2(0,0),SIMD2(0.05715,0)]
 var balls=Array(repeating:SIMD4<Float>.zero,count:16)
 for (i,p) in points.enumerated(){balls[i]=SIMD4(p.x+Float(frame)*0.035,p.y+Float(frame%3)*0.025,0.028575,0.85)}
 return balls
}
struct StateCost {let prepare:Double,upload:Double,total:Double,bytes:Int}
final class StateBinding {
 var previous:[SIMD4<Float>]=[]
 var previousMode:StateMode?=nil
 var writes=0
 @discardableResult func update(_ scene:SceneFixture,_ balls:[SIMD4<Float>],_ mode:StateMode)->StateCost {
  let begin=CACurrentMediaTime()
  if previousMode==mode && previous==balls{return StateCost(prepare:0,upload:0,total:(CACurrentMediaTime()-begin)*1000,bytes:0)}
  let values=mode == .reference ? balls:PreparedClothState.values(balls,coefficients:mode.coefficients,compact:mode.compact)
  let blob=values.withUnsafeBytes{Data($0)}
  previous=balls;previousMode=mode
  let prepared=CACurrentMediaTime()
  for m in scene.mats{m.setValue(blob as NSData,forKey:"contactUniforms")}
  SCNTransaction.flush();writes += 1
  let end=CACurrentMediaTime()
  return StateCost(prepare:(prepared-begin)*1000,upload:(end-prepared)*1000,total:(end-begin)*1000,bytes:blob.count)
 }
}
try baseline.write(to:output.appendingPathComponent("baseline.surface"),atomically:true,encoding:.utf8)
for (mode,source,_) in variants{try source.write(to:output.appendingPathComponent(mode.rawValue+".surface"),atomically:true,encoding:.utf8)}
try need(MemoryLayout<SIMD4<Float>>.stride==16,"Float4 ABI")
let preflightScene=try makeScene(package),preflightTarget=try Target(preflightScene.renderer,maxWidth,maxWidth*4/7)
for m in preflightScene.mats{field.install(on:m)}
pose(preflightScene,"single-near")
let binding=StateBinding(),normalBalls=ballState("single-near",0)
if experimentRound=="compact" {
 for bits in UInt32(0)...UInt32(65535) {
  let balls=(0..<16).map{SIMD4<Float>(Float($0),0,0.028575,(bits & (UInt32(1)<<$0)) != 0 ? 0.85:0)}
  let prepared=PreparedClothState.values(balls,coefficients:false,compact:true)
  let expected=balls.filter{$0.w>0}
  try need(prepared[16].y==Float(expected.count) && Array(prepared[17..<(17+expected.count)])==expected,"Stable active ordering")
 }
}
try need(PreparedClothState.values(normalBalls,coefficients:false)[16].x==1,"Normal domain")
var outside=normalBalls;outside[15]=SIMD4(3,0,0.028575,0.85)
try need(PreparedClothState.values(outside,coefficients:false)[16].x==0,"Active out of domain")
outside[15].w=0
try need(PreparedClothState.values(outside,coefficients:false)[16].x==1,"Inactive out of domain")
var sentinelChecks=0
for (mode,source,_) in variants {
 let first=binding.update(preflightScene,normalBalls,mode),writes=binding.writes
 let unchanged=binding.update(preflightScene,normalBalls,mode)
 try need(unchanged.bytes==0 && binding.writes==writes,"Unchanged state must not upload")
 try need(first.bytes==272+(mode.coefficients ? 256:0)+(mode.compact ? 256:0),"One packed upload size")
 // Verify actual SceneKit binding of appended fields, including the final slot.
 let declaration=String(source[..<source.range(of:"#pragma body")!.lowerBound])
 let sentinel=declaration+"#pragma body\n_surface.diffuse.rgb=float3(0.0);\n_surface.emission.rgb=float3(0.0);\n"
 let fields:[(String,Int)]=[("stateMeta",16)] + (mode.compact ? [("preparedBalls[15]",32)]:[]) + (mode.coefficients ? [("coefficients[15]",mode.compact ? 48:32)]:[])
 for (fieldName,slot) in fields {for channel in 0..<3 {
  var values=PreparedClothState.values(normalBalls,coefficients:mode.coefficients,compact:mode.compact)
  values[slot] = .zero;values[slot][channel]=1
  let blob=values.withUnsafeBytes{Data($0)}
  for m in preflightScene.mats{m.setValue(blob as NSData,forKey:"contactUniforms")}
  install(preflightScene,sentinel,"#pragma body\n_output.color=float4(contactUniforms.\(fieldName).xyz,1.0);")
  _=try preflightTarget.batch(3);let actual=try preflightTarget.read()
  let color=(0..<3).map{$0==channel ? "1.0":"0.0"}.joined(separator:",")
  install(preflightScene,sentinel,"#pragma body\n_output.color=float4(\(color),1.0);")
  _=try preflightTarget.batch(3);let expected=try preflightTarget.read()
  try need(difference(actual,expected)["changedPixels"]==0,"SceneKit appended uniform sentinel")
  sentinelChecks += 1
 }}
}
try write(["passed":true,"sceneKitSentinels":sentinelChecks,"referenceBytes":256,"variantBytes":Dictionary(uniqueKeysWithValues:modes.map{($0.rawValue,272+($0.compact ? 256:0)+($0.coefficients ? 256:0))}),"activeSetOrderCases":experimentRound=="compact" ? 65536:0,"unchangedUploads":0,"geometry":"XZ horizontal, Y up, metres; bed 0.8, uniform.z relative ball center height; radius 0.028575"],"preflight.json")
try write(["device":device.name,"os":ProcessInfo.processInfo.operatingSystemVersionString,"width":maxWidth,"baseline":"C1 + H9 production","scope":"Native cloth and imported table; no ball meshes, room, SwiftUI or real shots","timing":"State prepare/upload and render recorded separately; total wall includes state and frame sentinel; ball generation and camera setup excluded identically","newTextures":0],"metadata.json")
var results=[[String:Any]]()
for (mode,source,tolerance) in variants {
 var rows=[[String:Any]](),qualified=true
 for name in ["single-low","single-near","scatter-overview"] {
  try autoreleasepool {
   let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7),binding=StateBinding()
   for m in scene.mats{field.install(on:m)}
   pose(scene,name)
   var cases=(0..<6).map{("frame-\($0)",ballState(name,$0))}
   if name=="single-near" {
    let zero=[SIMD4<Float>](repeating:.zero,count:16)
    cases.append(("empty",zero))
    var last=zero;last[15]=SIMD4(0,0,0.028575,0.425);cases.append(("last-fading",last))
    for (label,ball):(String,SIMD4<Float>) in [("outside",SIMD4(3,0,0.028575,0.85)),("below-min-height",SIMD4(0,0,0,0.85)),("high",SIMD4(0,0,2.2,0.85)),("over-height",SIMD4(0,0,2.21,0.85)),("weight-one",SIMD4(0,0,0.028575,1))] {
     var values=normalBalls;values[15]=ball;cases.append((label,values))
    }
   }
   var maximum=0,aaMax=0,comparisons=[[String:Any]]()
   for (label,balls) in cases {
    install(scene,baseline);binding.update(scene,balls,.reference);_=try target.batch(3);let a=try target.read();_=try target.frame();let aa=try target.read()
    install(scene,source);binding.update(scene,balls,mode);_=try target.batch(3);let b=try target.read()
    let delta=difference(a,b),noise=difference(a,aa)
    maximum=max(maximum,delta["maximumChannelDifference"]!);aaMax=max(aaMax,noise["maximumChannelDifference"]!)
    try target.save(a,"\(mode.rawValue)-\(name)-\(label)-baseline");try target.save(b,"\(mode.rawValue)-\(name)-\(label)-candidate")
    comparisons.append(["case":label,"balls":balls.map{[$0.x,$0.y,$0.z,$0.w]},"delta":delta,"aa":noise])
   }
   qualified = qualified && maximum<=tolerance && aaMax==0
   rows.append(["variant":mode.rawValue,"pose":name,"width":maxWidth,"tolerance":tolerance,"maximumChannelDifference":maximum,"comparisons":comparisons,"times":[[String:Any]]()])
   try write(results+rows,"results.json");print("\(mode.rawValue) \(name) maximum=\(maximum) AA=\(aaMax)");fflush(stdout)
  }
 }
 if qualified {
  for index in rows.indices {
   let name=rows[index]["pose"] as! String
   try autoreleasepool {
    let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7),binding=StateBinding()
    for m in scene.mats{field.install(on:m)};pose(scene,name)
    let states=(0..<6).map{ballState(name,$0)}
    install(scene,baseline);binding.update(scene,states[0],.reference);_=try target.batch(4)
    install(scene,source);binding.update(scene,states[0],mode);_=try target.batch(4)
    var times=[[String:Any]]()
    for kind in ["AA","AB"] {for cycle in 0..<6 {for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
     let actualMode:StateMode=(kind=="AB" && arm) ? mode:.reference
     install(scene,actualMode == .reference ? baseline:source);binding.update(scene,states[0],actualMode);_=try target.batch(3)
     var samples=[FrameTime](),costs=[StateCost](),full=[Double]()
     for frame in 0..<24 {
      let begin=CACurrentMediaTime();costs.append(binding.update(scene,states[(frame+1)%6],actualMode));samples.append(try target.frame());full.append((CACurrentMediaTime()-begin)*1000)
     }
     times.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","gpuMS":samples.map{$0.gpu},"cpuEncodeMS":samples.map{$0.encode},"wallMS":full,"statePrepareMS":costs.map{$0.prepare},"stateUploadMS":costs.map{$0.upload},"stateTotalMS":costs.map{$0.total},"uploadedBytes":costs.map{$0.bytes},"frames":samples.map{$0.json}])
    }}}
    rows[index]["times"]=times;try write(results+rows,"results.json");print("\(mode.rawValue) \(name) timing complete");fflush(stdout)
   }
  }
 }
 results += rows;try write(results,"results.json")
}
