let variants:[(String,CGFloat,Int)]=[("explicit16",16,16),("both4",4,4)]
var results=[[String:Any]](),consumers=[[String:Any]]()
func roomInput(_ scene:SceneFixture,_ pose:String,_ frame:Int) {
 _=input(scene,pose=="room-wide" ? "scatter-overview":pose,frame)
 let base:SIMD3<Float>=pose=="room-wide" ? SIMD3(3.3,2.6,2.3):(pose=="single-low" ? SIMD3(0,1.05,1.8):SIMD3(1.8,2.7,2.1))
 scene.eye.simdPosition=base+SIMD3(Float(frame)*0.012,0,Float(frame%3)*0.009)
 scene.eye.simdLook(at:SIMD3(0,0.8,0));SCNTransaction.flush()
}
for style in RoomStyle.allCases {
 for pose in ["single-low","scatter-overview","room-wide"] {
  try autoreleasepool {
   // The production clone path can retain shared SCNMaterialProperty state.
   // Each research fixture must start from an untouched cache.
   BakedTrainingRoom.resetCache()
   let scene=try makeScene(package),room=BakedTrainingRoom.make(style:style)
   scene.scene.rootNode.addChildNode(room)
   for m in scene.mats{m.shaderModifiers=[.surface:baseline,.fragment:fragment];field.install(on:m)}
   var floor=[SCNMaterial](),seen=Set<ObjectIdentifier>()
   room.enumerateHierarchy {node,_ in
    for material in node.geometry?.materials ?? [] where seen.insert(ObjectIdentifier(material)).inserted {
     var modifiers=material.shaderModifiers ?? [:];modifiers[.fragment]=fragment;material.shaderModifiers=modifiers
     if material.name=="Room_\(style.rawValue)_floor_baked" {floor.append(material)}
    }
   }
   try need(!floor.isEmpty,"No actual floor material")
   let originals=floor.map{$0.shaderModifiers!},originalYarn=floor.map{$0.multiply.maxAnisotropy}
   let target=try Target(scene.renderer,maxWidth,maxWidth*4/7)
   for source in originals {try need(source[.surface]!.components(separatedBy:"max_anisotropy(16)").count==2,"Atlas sampler qualification")}
   roomInput(scene,pose,0);_=try target.batch(4);let normal=try target.read()
   for m in floor {var modifiers=m.shaderModifiers!;modifiers[.fragment]="#pragma body\n_output.color=float4(1.0,0.0,1.0,1.0);";m.shaderModifiers=modifiers}
   SCNTransaction.flush();_=try target.batch(3);let marker=try target.read()
   let coverage=difference(normal,marker)
   try need(coverage["changedPixels"]!>0,"Floor consumer invisible")
   try target.save(marker,"floor-marker-\(style.rawValue)-\(pose)")
   for (i,m) in floor.enumerated(){m.shaderModifiers=originals[i]};SCNTransaction.flush()
   consumers.append(["style":style.rawValue,"pose":pose,"floorMaterials":floor.count,"markerDifference":coverage,
                     "yarnAnisotropy":floor[0].multiply.maxAnisotropy,"atlasSamplerAnisotropy":16])
   try write(consumers,"consumers.json")
   for (name,yarn,atlas) in variants {
    func apply(_ candidate:Bool) {
     for (i,m) in floor.enumerated() {
      m.multiply.maxAnisotropy=candidate ? yarn:originalYarn[i]
      var modifiers=originals[i]
      if candidate {modifiers[.surface]=modifiers[.surface]!.replacingOccurrences(of:"max_anisotropy(16)",with:"max_anisotropy(\(atlas))")}
      m.shaderModifiers=modifiers
     };SCNTransaction.flush()
    }
    var comparisons=[[String:Any]](),maximum=0,aaMaximum=0
    let variant=style.rawValue+"-"+name
    for frame in 0..<6 {
     roomInput(scene,pose,frame)
     apply(false);_=try target.batch(3);let a=try target.read();_=try target.frame();let aa=try target.read()
     apply(true);_=try target.batch(3);let b=try target.read()
     let delta=difference(a,b),noise=difference(a,aa)
     maximum=max(maximum,delta["maximumChannelDifference"]!);aaMaximum=max(aaMaximum,noise["maximumChannelDifference"]!)
     comparisons.append(["frame":frame,"delta":delta,"aa":noise])
     if frame==0 || frame==5 {try target.save(a,"\(variant)-\(pose)-\(frame)-baseline");try target.save(b,"\(variant)-\(pose)-\(frame)-candidate")}
    }
    try need(aaMaximum==0,"Carpet AA changed")
    print("\(variant) \(pose) max=\(maximum) AA=\(aaMaximum)");fflush(stdout)
    var times=[[String:Any]]()
    for kind in ["AA","AB"] {for cycle in 0..<6 {for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
     apply(kind=="AB" && arm);roomInput(scene,pose,0);_=try target.batch(4)
     var samples=[FrameTime]()
     for frame in 0..<24 {roomInput(scene,pose,frame%6);samples.append(try target.frame())}
     times.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","gpuMS":samples.map{$0.gpu},"cpuEncodeMS":samples.map{$0.encode},"wallMS":samples.map{$0.syncWall},"frames":samples.map{$0.json}])
    }}}
    results.append(["variant":variant,"pose":pose,"width":maxWidth,"maximumChannelDifference":maximum,"tolerance":1,"diagnosticOnly":true,"comparisons":comparisons,"times":times])
    try write(results,"results.json");print("\(variant) \(pose) timing complete");fflush(stdout)
   }
  }
 }
}
