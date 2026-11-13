// Appended to the archived, source-identified native renderer/asset setup.
let shaderRoot=URL(fileURLWithPath:CommandLine.arguments[5])
let reference=try String(contentsOf:shaderRoot.appendingPathComponent("baseline.surface"),encoding:.utf8)
let candidate=try String(contentsOf:shaderRoot.appendingPathComponent("candidate.surface"),encoding:.utf8)
let generator=try String(contentsOf:shaderRoot.appendingPathComponent("generate.surface"),encoding:.utf8)
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
func cache(_ scene:SceneFixture,_ w:Int,_ h:Int)throws->MTLTexture {
 let cw=min(w,512),ch=min(h,512)
 let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:cw,height:ch,mipmapped:false)
 d.textureType = .type2DArray;d.arrayLength=5;d.storageMode = .shared;d.usage=[.shaderRead,.shaderWrite]
 let texture=try unwrap(device.makeTexture(descriptor:d),"Temporal cache")
 let zeros=[Float](repeating:0,count:cw*ch*4)
 for layer in 0..<5 {zeros.withUnsafeBytes{texture.replace(region:MTLRegionMake2D(0,0,cw,ch),mipmapLevel:0,slice:layer,withBytes:$0.baseAddress!,bytesPerRow:cw*16,bytesPerImage:cw*ch*16)}}
 let prop=SCNMaterialProperty(contents:texture)
 for m in scene.mats {
  m.setValue(prop,forKey:"temporalCache")
  m.setValue(NSValue(scnVector4:SCNVector4(Float(w),Float(h),Float((w-cw)/2),Float((h-ch)/2))),forKey:"temporalViewport")
  m.setValue(Float(1),forKey:"temporalEnabled")
 }
 return texture
}
func difference(_ a:Data,_ b:Data)->[String:Int] {
 let x=[UInt8](a),y=[UInt8](b);var maximum=0,channels=0,pixels=0
 for i in stride(from:0,to:x.count,by:4) {var changed=false
  for c in 0..<3 {let d=abs(Int(x[i+c])-Int(y[i+c]));maximum=max(maximum,d);channels += d==0 ? 0:1;changed = changed || d>0}
  pixels += changed ? 1:0
 }
 return ["maximumChannelDifference":maximum,"changedChannels":channels,"changedPixels":pixels]
}
func input(_ s:SceneFixture,_ pose:String,_ frame:Int)->[SIMD4<Float>] {
 let R:Float=0.028575
 let points:[SIMD2<Float>]=pose=="scatter-overview" ? [-0.9,-0.3,0.3,0.9].flatMap{x in [-0.45,-0.15,0.15,0.45].map{z in SIMD2<Float>(Float(x),Float(z))}}:[SIMD2(0,0),SIMD2(0.05715,0)]
 var balls=Array(repeating:SIMD4<Float>(0,0,0,0),count:16)
 for (i,p) in points.enumerated(){balls[i]=SIMD4(p.x+Float(frame)*0.035,p.y+Float(frame%3)*0.025,R,0.85)}
 let blob=balls.withUnsafeBytes{Data($0)}
 for m in s.mats{m.setValue(blob as NSData,forKey:"contactUniforms")}
 // The first screen comparison does not add diagnostic sphere geometry: only
 // ball-driven shading changes, exposing formerly shadowed receiver pixels.
 s.eye.simdPosition=pose=="single-near" ? SIMD3(0.16,1.15,0.3):(pose=="single-low" ? SIMD3(0,1.05,1.8):SIMD3(1.8,2.7,2.1))
 s.eye.simdLook(at:SIMD3(0,0.8,0));SCNTransaction.flush();return balls
}
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
var summaries=[[String:Any]]()
for pose in ["single-low","single-near","scatter-overview"] {
 try autoreleasepool {
  let scene=try makeScene(package),w=maxWidth,h=maxWidth*4/7,target=try Target(scene.renderer,w,h)
  let texture=try cache(scene,w,h)
  var comparisons=[[String:Any]](),valid=true
  for frame in 0..<6 {
   _=input(scene,pose,frame)
   install(scene,reference);_ = try target.batch(2);let a=try target.read();_ = try target.frame();let aa=try target.read()
   install(scene,generator)
   for m in scene.mats {m.setValue(Float(1),forKey:"temporalEnabled")}
   let cold=try target.frame();let b0=try target.read()
   install(scene,candidate)
   for m in scene.mats {m.setValue(Float(2),forKey:"temporalEnabled")}
   _ = try target.batch(2);let b=try target.read()
   let d=difference(a,b),dc=difference(a,b0),noise=difference(a,aa)
   if frame==0 {
    for layer in 0..<5 {
     var pixels=[Float](repeating:0,count:texture.width*texture.height*4)
     pixels.withUnsafeMutableBytes{texture.getBytes($0.baseAddress!,bytesPerRow:texture.width*16,bytesPerImage:texture.width*texture.height*16,from:MTLRegionMake2D(0,0,texture.width,texture.height),mipmapLevel:0,slice:layer)}
     try pixels.withUnsafeBytes{Data($0)}.write(to:output.appendingPathComponent("\(pose)-cache-\(layer).bin"))
    }
   }
   try target.save(a,"\(pose)-\(frame)-reference");try target.save(b,"\(pose)-\(frame)-candidate")
   if d["changedPixels"]!>0 || dc["changedPixels"]!>0 || noise["changedPixels"]!>0 {valid=false}
   comparisons.append(["frame":frame,"aa":noise,"candidateCold":dc,"candidateWarm":d,"firstCandidateGPU_MS":cold.gpu])
  }
  var times=[[String:Any]]()
  if valid {
   _=input(scene,pose,0)
   for cycle in 0..<6 {
    let order=cycle%2==0 ? ["A","B","B","A"]:["B","A","A","B"]
    for mode in order {
     install(scene,mode=="A" ? reference:candidate);_ = try target.batch(2)
     let t=try target.batch(6)
     times.append(["cycle":cycle,"mode":mode,"gpuMS":t.map{$0.gpu},"cpuEncodeMS":t.map{$0.encode},"wallMS":t.map{$0.syncWall}])
    }
   }
  }
  let row:[String:Any]=["pose":pose,"width":w,"height":h,"exactFrames":valid,"comparisons":comparisons,"times":times,"cacheBytes":texture.allocatedSize,"targetBytes":target.bytes]
  summaries.append(row);try write(summaries,"results.json")
  print("\(pose) exact=\(valid) cache=\(texture.allocatedSize)")
 }
}
