import Foundation
import SceneKit
import AppKit
import Metal
import simd

let root=URL(fileURLWithPath:CommandLine.arguments[1]),out=URL(fileURLWithPath:CommandLine.arguments[2])
func fail(_ s:String) throws -> Never {throw NSError(domain:"ClothVisual",code:1,userInfo:[NSLocalizedDescriptionKey:s])}
guard let device=MTLCreateSystemDefaultDevice() else {try fail("No Metal device")}
let loaded=try SCNScene(url:root.appendingPathComponent("QiuJi/Resources/ModelTrial20261010_TaiQiuZhuo.usdz"),options:nil)
let scene=SCNScene(),container=SCNNode(),table=SCNNode()
if SCNMatrix4IsIdentity(loaded.rootNode.transform) {container.simdEulerAngles.x = -.pi/2} else {container.transform=loaded.rootNode.transform}
for child in loaded.rootNode.childNodes {container.addChildNode(child.clone())}
table.addChildNode(container);scene.rootNode.addChildNode(table)
let removeNames=Set(["QiuGan","_0","BaiQiu"]+(1...15).map{"_\($0)"})
var remove=[SCNNode]()
container.enumerateHierarchy {n,_ in if removeNames.contains(n.name ?? "") {remove.append(n)};n.physicsBody=nil;if n.camera != nil || n.light != nil {remove.append(n)}}
for n in remove {n.removeFromParentNode()}
let (bmin,bmax)=table.boundingBox
let actualLength=Float(bmax.x-bmin.x),actualWidth=max(Float(bmax.z-bmin.z),Float(bmax.y-bmin.y))
let scale=((2.54+2*0.05+0.18)/actualLength+(1.27+2*0.05+0.18)/actualWidth)/2
if !scale.isFinite || scale<=0 {try fail("Invalid model bounds")}
table.simdScale=SIMD3(repeating:scale)
let modelSurface=Float(bmax.y)*scale-0.037
table.simdPosition=SIMD3(-Float((bmin.x+bmax.x)/2)*scale,0.8-modelSurface,-Float((bmin.z+bmax.z)/2)*scale)
let alignmentScene=AngleTrainingScene(scene:scene,table:table)
let measuredBedY=try MobileClothAlignment.measuredBedY(in:alignmentScene)
MobileClothAlignment.apply(to:alignmentScene)
var mats=[SCNMaterial](),seen=Set<ObjectIdentifier>()
table.enumerateHierarchy {n,_ in
 for m in n.geometry?.materials ?? [] where m.name == "TaiNi" && seen.insert(ObjectIdentifier(m)).inserted {
  mats.append(m)
  m.lightingModel = .physicallyBased
  m.diffuse.contents=NSColor(srgbRed:48/255,green:155/255,blue:32/255,alpha:1)
  m.multiply.contents=NSColor(srgbRed:0.54,green:0.73,blue:0.54,alpha:1)
  m.normal.intensity=0.65
  m.metalness.contents=Float(0)
  for p in [m.normal,m.roughness] {p.contentsTransform=SCNMatrix4MakeScale(2,2,1);p.wrapS = .repeat;p.wrapT = .repeat}
  m.setValue(SCNMaterialProperty(contents:root.appendingPathComponent("QiuJi/Resources/MobileRailOcclusion.png")),forKey:"bakedRailAO")
 }
}
if mats.isEmpty {try fail("No TaiNi material")}
scene.lightingEnvironment.contents=out.appendingPathComponent("reference-environment.hdr")
scene.lightingEnvironment.intensity=1
scene.background.contents=NSColor(srgbRed:0.04,green:0.04,blue:0.04,alpha:1)
let rigURL=root.appendingPathComponent("output/render-lowdim-20261113/native-reference/generated-production-core.json")
guard let rigJSON=try JSONSerialization.jsonObject(with:Data(contentsOf:rigURL)) as? [String:Any],let rig=rigJSON["rig"] as? [String:Any],let panels=rig["panels"] as? [[String:Any]],let radiance=rig["radiance"] as? Double else {try fail("Bad rig")}
func vector(_ x:Any?) throws -> SIMD3<Float> {guard let a=x as? [Double],a.count==3 else {try fail("Bad vector")};return SIMD3(Float(a[0]),Float(a[1]),Float(a[2]))}
for p in panels {
 let u=try vector(p["u"]),v=try vector(p["v"]),normal=try vector(p["normal"]),center=try vector(p["center"])
 let light=SCNLight();light.type = .area;light.areaType = .rectangle;light.areaExtents=SIMD3(2*simd_length(u),2*simd_length(v),0)
 guard let area=p["area"] as? Double,let gain=p["gain"] as? Double else {try fail("Bad lamp")}
 light.intensity=CGFloat(15000*radiance/44.5714854*area*gain);light.drawsArea=false;light.doubleSided=true;light.attenuationEndDistance=10
 let node=SCNNode();node.light=light;node.simdTransform=simd_float4x4(SIMD4(simd_normalize(u),0),SIMD4(-simd_normalize(v),0),SIMD4(-normal,0),SIMD4(center,1));scene.rootNode.addChildNode(node)
}
let camera=SCNCamera();camera.zNear=0.01;camera.zFar=50;camera.fieldOfView=50;camera.wantsHDR=true;camera.wantsExposureAdaptation=false;camera.exposureOffset = -0.1;camera.minimumExposure = -2;camera.maximumExposure=2;camera.screenSpaceAmbientOcclusionIntensity=0
let eye=SCNNode();eye.camera=camera;scene.rootNode.addChildNode(eye)
let renderer=SCNRenderer(device:device,options:nil);renderer.scene=scene;renderer.pointOfView=eye;renderer.autoenablesDefaultLighting=false
let reference=try String(contentsOf:out.appendingPathComponent("reference.surface"),encoding:.utf8)
let supportOnly=CommandLine.arguments.contains("--support-only")
let candidates:[(String,String)]=try supportOnly ? [("height-safe",String(contentsOf:out.appendingPathComponent("height-safe.surface"),encoding:.utf8))] : [2,4,8].map { k in ("k\(k)",try String(contentsOf:out.appendingPathComponent("candidate-k\(k).surface"),encoding:.utf8)) }
let coverage=try String(contentsOf:out.appendingPathComponent(supportOnly ? "height-safe-coverage.surface" : "candidate-coverage.surface"),encoding:.utf8)
let normal=try String(contentsOf:out.appendingPathComponent("normal.surface"),encoding:.utf8)
let headroom=pow(2.0,0.1)-1
let fragment="""
#pragma body
float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
"""
let size=CGSize(width:1200,height:800)
func png(_ img:NSImage) throws -> Data {
 var rect=CGRect(origin:.zero,size:img.size)
 guard let cg=img.cgImage(forProposedRect:&rect,context:nil,hints:nil),let data=NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:]) else {try fail("PNG encode")}
 return data
}
func capture(_ source:String,_ file:String,diagnostic:Bool=false) throws -> Data {
 for m in mats {var mods=m.shaderModifiers ?? [:];mods[.surface]=source;mods[.fragment]=diagnostic ? "#pragma body\n_output.color.rgb=_surface.emission.rgb;" : fragment;m.shaderModifiers=mods}
 camera.wantsHDR = !diagnostic;camera.exposureOffset = diagnostic ? 0 : -0.1
 SCNTransaction.flush()
 for _ in 0..<3 {_=renderer.snapshot(atTime:1,with:size,antialiasingMode:.multisampling4X)}
 let data=try png(renderer.snapshot(atTime:1,with:size,antialiasingMode:.multisampling4X));try data.write(to:out.appendingPathComponent(file));return data
}
// Float render target bypasses PNG quantization. Calibration below must prove
// no nonlinear transfer before consumers interpret actual SceneKit normals.
func captureRaw(_ suffix:String,_ expression:String) throws {
 let w=600,h=400
 for m in mats {var mods=m.shaderModifiers ?? [:];mods[.surface]=reference;mods[.fragment]="#pragma body\n_output.color="+expression+";";m.shaderModifiers=mods}
 camera.wantsHDR=false;camera.exposureOffset=0
 SCNTransaction.flush()
 let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:w,height:h,mipmapped:false)
 descriptor.usage=[.renderTarget,.shaderRead];descriptor.storageMode = .shared
 guard let texture=device.makeTexture(descriptor:descriptor),let queue=device.makeCommandQueue() else {try fail("Float target")}
 for _ in 0..<2 {
  let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=texture;pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store
  guard let command=queue.makeCommandBuffer() else {try fail("Command buffer")}
  renderer.render(atTime:1,viewport:CGRect(x:0,y:0,width:w,height:h),commandBuffer:command,passDescriptor:pass)
  command.commit();command.waitUntilCompleted()
  if let error=command.error {try fail("Float render: \(error)")}
 }
 var pixels=Array<Float>(repeating:0,count:w*h*4)
 texture.getBytes(&pixels,bytesPerRow:w*16,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)
 try pixels.withUnsafeBytes{Data($0)}.write(to:out.appendingPathComponent(suffix+".rgba32f"))
}
let diagnosticsOnly=CommandLine.arguments.contains("--diagnostics-only")
let R:Float=0.028575
let scatter:[SIMD2<Float>]=[-0.9,-0.3,0.3,0.9].flatMap {x in [-0.45,-0.15,0.15,0.45].map {z in SIMD2<Float>(Float(x),Float(z))}}
var rack=[SIMD2<Float>]()
for row in 0..<5 {for j in 0...row {rack.append(SIMD2(-0.5+Float(row)*sqrt(3)*R,(Float(j)-Float(row)/2)*2*R))}}
rack.append(SIMD2(0.65,0.2))
let single=[SIMD2<Float>(0,0),SIMD2<Float>(0.05715,0)]
let edge=[SIMD2<Float>(1.20,0.58),SIMD2<Float>(1.14,0.54)]
var sphereNodes=[SCNNode]()
var records=[[String:Any]]()
var fixtures:[(String,[SIMD2<Float>])]=[("single",single),("edge",edge),("rack",rack),("scatter",scatter)]
if supportOnly {for frame in 0..<12 {fixtures.append((String(format:"move-%02d",frame),[SIMD2(-0.18+0.03*Float(frame),0),SIMD2(0.2,0.12)]))}}
for (fixture,points) in fixtures {
 for n in sphereNodes {n.removeFromParentNode()};sphereNodes=[]
 var balls=Array(repeating:SIMD4<Float>(0,0,0,0),count:16)
 for (i,p) in points.enumerated() {
  balls[i]=SIMD4(p.x,p.y,R,0.85)
  let sphere=SCNSphere(radius:CGFloat(R));sphere.segmentCount=48
  let m=SCNMaterial();m.diffuse.contents=NSColor(srgbRed:0.8,green:0.8,blue:0.8,alpha:1);m.roughness.contents=Float(0.34);m.lightingModel = .physicallyBased;sphere.materials=[m]
  let n=SCNNode(geometry:sphere);n.simdPosition=SIMD3(p.x,0.8+R,p.y);scene.rootNode.addChildNode(n);sphereNodes.append(n)
 }
 let blob=balls.withUnsafeBytes {Data($0)}
 for m in mats {m.setValue(blob as NSData,forKey:"contactUniforms")}
 let poses:[(String,SIMD3<Float>,SIMD3<Float>)]
 if fixture.hasPrefix("move-") {poses=[("low",SIMD3(0.28,1.0,0.6),SIMD3(0,0.8,0))]}
 else if fixture=="edge" {poses=[("low",SIMD3(1.65,1.03,1.03),SIMD3(1.14,0.8,0.53))]}
 else if fixture=="single" {poses=[("low",SIMD3(0.28,1.0,0.6),SIMD3(0,0.8,0)),("near",SIMD3(0.16,1.15,0.3),SIMD3(0,0.8,0))]}
 else {poses=[("overview",SIMD3(1.8,2.7,2.1),SIMD3(0,0.8,0))]}
 for (pose,e,t) in poses {
  eye.simdPosition=e;eye.simdLook(at:t)
  let id=fixture+"-"+pose
  if diagnosticsOnly {
   try captureRaw(id+"-calibration","float4(0.25,0.5,0.75,1)")
   try captureRaw(id+"-mask-black","float4(0,0,0,1)")
   try captureRaw(id+"-normal-roughness","float4(0.5+0.5*normalize((scn_frame.inverseViewTransform*float4(_surface.normal,0.0)).xyz),_surface.roughness)")
   try captureRaw(id+"-geometry-normal","float4(0.5+0.5*normalize((scn_frame.inverseViewTransform*float4(_surface.geometryNormal,0.0)).xyz),1)")
   try captureRaw(id+"-world-position","float4((scn_frame.inverseViewTransform*float4(_surface.position,1.0)).xyz,1)")
   try captureRaw(id+"-tangent","float4(0.5+0.5*normalize((scn_frame.inverseViewTransform*float4(_surface.tangent,0.0)).xyz),1)")
   try captureRaw(id+"-bitangent","float4(0.5+0.5*normalize((scn_frame.inverseViewTransform*float4(_surface.bitangent,0.0)).xyz),1)")
   print(id,"float diagnostics captured")
   continue
  }
  let ref=try capture(reference,id+"-reference.png")
  let restored=try capture(reference,id+"-repeat.png")
  let control=try capture(reference+"\n_surface.emission.rgb=float3(1,0,0);",id+"-red-control.png")
  if control==ref {try fail("Shader red control has no effect: "+id)}
  for (k,source) in candidates {_=try capture(source,id+"-\(k).png")}
  let restore=try capture(reference,id+"-restored.png")
  _=try capture(coverage,id+"-coverage.png",diagnostic:true)
  _=try capture(normal,id+"-normal.png",diagnostic:true)
  records.append(["id":id,"eye":[e.x,e.y,e.z],"target":[t.x,t.y,t.z],"samePNGRepeat":ref==restored,"samePNGRestore":ref==restore,"sphereCount":points.count,"packedBalls":balls.map{[$0.x,$0.y,$0.z,$0.w]}])
  print(id,"captured")
 }
}
let data:[String:Any] = ["gpu":device.name,"scope":"macOS SceneKit actual USDZ cloth with production shader, AO, textures, native PBR, lights/exposure. Other table materials imported; balls are diagnostic spheres, no R ball probe/baked room; not full App or phone performance.","size":[1200,800],"MSAA":4,"normalIntensity":0.65,"multiplySRGB":[0.54,0.73,0.54],"modelScale":scale,"modelSurfaceBeforeCorrection":modelSurface,"tablePosition":[table.simdPosition.x,table.simdPosition.y,table.simdPosition.z],"clothMaterials":mats.count,"measuredBedY":measuredBedY ?? -99,"alignmentLift":0.8-(measuredBedY ?? 0.8),"records":records]
if !diagnosticsOnly {try JSONSerialization.data(withJSONObject:data,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("captures.json"))}
else {try JSONSerialization.data(withJSONObject:["size":[600,400],"format":"little endian rgba32 float, no MSAA; calibration required", "scope":"native SceneKit actual final world normal and roughness; no assumed tangent basis"],options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("float-diagnostics.json"))}
