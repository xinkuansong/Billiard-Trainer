// Frozen R3 shader, new measurement and visual-review contract only.
let candidateR3=variants[0].1
try need(baseline == String(contentsOf:output.appendingPathComponent("frozen-baseline.surface"),encoding:.utf8),"R3 baseline identity")
try need(candidateR3 == String(contentsOf:output.appendingPathComponent("frozen-integral.surface"),encoding:.utf8),"R3 candidate identity")
try write(["device":device.name,"os":ProcessInfo.processInfo.operatingSystemVersionString,"thermalAtStart":ProcessInfo.processInfo.thermalState.rawValue,"candidate":"frozen H18 R3","mode":reviewMode],"environment.json")

func clothMask(_ scene:SceneFixture,_ target:Target)throws->Data {
 let ids=Set(scene.mats.map{ObjectIdentifier($0)})
 let black=SCNMaterial();black.lightingModel = .constant;black.diffuse.contents=NSColor.black;black.isDoubleSided=true
 var entries=[(SCNGeometry,[SCNMaterial])](),seen=Set<ObjectIdentifier>()
 scene.table.enumerateHierarchy {node,_ in
  guard let geometry=node.geometry,seen.insert(ObjectIdentifier(geometry)).inserted else{return}
  let original=geometry.materials;entries.append((geometry,original))
  geometry.materials=original.map {m in
   if !ids.contains(ObjectIdentifier(m)){return black}
   let white=m.copy() as! SCNMaterial
   white.lightingModel = .constant;white.diffuse.contents=NSColor.white;white.multiply.contents=NSColor.white;white.emission.contents=NSColor.black
   white.normal.contents=nil;white.metalness.contents=Float(0);white.roughness.contents=Float(1)
   white.shaderModifiers=m.shaderModifiers?.filter{$0.key == .geometry}
   return white
  }
 }
 SCNTransaction.flush();_=try target.batch(3);let mask=try target.read()
 for (g,m) in entries {g.materials=m}
 SCNTransaction.flush();return mask
}

func motionInput(_ scene:SceneFixture,_ pose:String,_ frame:Int) {
 let t=Float(frame)/59,angle=(t-0.5)*0.35
 _=input(scene,pose,0)
 let eye=scene.eye.simdPosition,center=SIMD3<Float>(0,0.8,0),offset=eye-center
 let moved=SIMD3<Float>(offset.x*cos(angle)-offset.z*sin(angle),offset.y+0.015*sin(t*2*Float.pi),offset.x*sin(angle)+offset.z*cos(angle))+center
 let delta=moved-center
 let look=ProductionPose.Pose.looking(eye:moved,yaw:atan2(delta.z,delta.x),pitch: -atan2(delta.y,sqrt(delta.x*delta.x+delta.z*delta.z)),fov:50)
 precondition(simd_dot(look.forward,simd_normalize(-delta))>0.99999)
 scene.eye.simdTransform=look.transform
 var balls=[SIMD4<Float>](repeating:.zero,count:16)
 balls[0]=SIMD4<Float>((t-0.5)*0.24,0,0.028575,0.85)
 balls[1]=SIMD4<Float>(balls[0].x+0.075,0.05*sin(t*Float.pi),0.028575,0.85)
 // Continuous shader-only occluder paths, with a proven minimum separation.
 let d=SIMD2<Float>(balls[0].x-balls[1].x,balls[0].y-balls[1].y)
 precondition(simd_length(d)>=0.075-1e-6)
 let bytes=balls.withUnsafeBytes{Data($0)}
 for m in scene.mats{m.setValue(bytes as NSData,forKey:"contactUniforms")}
 SCNTransaction.flush()
}

var reviewResults=[[String:Any]]()
for pose in reviewMode=="motion" ? [reviewPose]:["single-low","single-near","scatter-overview"] {
 try autoreleasepool {
  let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7)
  let maskScene=try makeScene(package),maskTarget=try Target(maskScene.renderer,maxWidth,maxWidth*4/7)
  for m in scene.mats {field.install(on:m);for i in 0..<2{m.setValue(SCNMaterialProperty(contents:textures[i]),forKey:"h18Table\(i)")}}
  var comparisons=[[String:Any]](),times=[[String:Any]]()
  let states=reviewMode=="motion" ? 60:6
  for frame in 0..<states {
   if reviewMode=="motion" {motionInput(scene,pose,frame)} else {_=input(scene,pose,frame)}
   install(scene,baseline);_=try target.batch(3);let a=try target.read();_=try target.frame();let aa=try target.read()
   install(scene,candidateR3);_=try target.batch(3);let b=try target.read()
   install(scene,baseline);_=try target.batch(3);let restored=try target.read()
   let noise=difference(a,aa),restore=difference(a,restored),delta=difference(a,b)
   try need(noise["maximumChannelDifference"]==0 && restore["maximumChannelDifference"]==0,"AA/restore drift")
   try need(counts(a)["green"]!>100 && counts(a)["magenta"]==0,"Nonblank valid rendered frame")
   if reviewMode=="motion" {
    try a.write(to:output.appendingPathComponent("\(pose)-\(frame)-A.bgra8"));try b.write(to:output.appendingPathComponent("\(pose)-\(frame)-B.bgra8"))
   }else{
    try target.save(a,"\(pose)-\(frame)-A");try target.save(b,"\(pose)-\(frame)-B")
   }
   do {
    maskScene.eye.simdTransform=scene.eye.simdTransform;SCNTransaction.flush()
    let mask=try clothMask(maskScene,maskTarget);try target.save(mask,"\(pose)-\(frame)-mask")
    install(scene,baseline);_=try target.batch(3)
    try need(difference(a,try target.read())["maximumChannelDifference"]==0,"Mask must not mutate primary scene")
   }
   comparisons.append(["frame":frame,"delta":delta,"aa":noise,"restore":restore])
  }
  if reviewMode=="cost" {
   // Interleave AA and AB cycles, avoid comparing distinct periods of machine load.
   for cycle in 0..<6 {for kind in cycle%2==0 ? ["AA","AB"]:["AB","AA"] {
    for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
     install(scene,kind=="AB" && arm ? candidateR3:baseline)
     for f in 0..<24 {_=input(scene,pose,f%6);_=try target.frame()}
     var samples=[FrameTime]()
     for f in 0..<48 {_=input(scene,pose,f%6);samples.append(try target.frame())}
     times.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","frames":samples.map{$0.json},"gpuMS":samples.map{$0.gpu},"cpuEncodeMS":samples.map{$0.encode},"thermal":ProcessInfo.processInfo.thermalState.rawValue])
    }
   }}
  }
  reviewResults.append(["pose":pose,"width":target.w,"height":target.h,"mode":reviewMode,"comparisons":comparisons,"times":times,"lutAllocatedBytes":textures.reduce(0){$0+$1.allocatedSize}])
  try write(reviewResults,"results.json");print("R6 \(pose) \(reviewMode) complete");fflush(stdout)
 }
}
