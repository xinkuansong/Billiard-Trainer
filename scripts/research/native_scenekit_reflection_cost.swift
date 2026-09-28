// Native macOS Metal isolation of exported production ball surface programs.
// Synthetic shared environment/LUT: algorithm cost only, NOT scene/visual/phone acceptance.
import Foundation
import Metal
import SceneKit
import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
func texture(_ format: MTLPixelFormat, _ width: Int, _ height: Int, _ mips: Bool) -> MTLTexture {
    let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: mips)
    d.usage = [.shaderRead, .renderTarget]; d.storageMode = .shared
    return device.makeTexture(descriptor:d)!
}
let env=texture(.rgba16Float,512,256,true), lut=texture(.rg16Float,128,128,false)
for (t,components) in [(env,4),(lut,2)] {
    for level in 0..<t.mipmapLevelCount {
        let w=max(1,t.width>>level), h=max(1,t.height>>level)
        var pixels=[UInt16](repeating:0,count:w*h*components)
        for y in 0..<h { for x in 0..<w { for c in 0..<components {
            let value:Float = components==2 ? (c==0 ? 0.8:0.04) : (c==3 ? 1 : 0.1+Float(x+y+c)/Float(w+h))
            pixels[(y*w+x)*components+c]=Float16(value).bitPattern
        } } }
        pixels.withUnsafeBytes { t.replace(region:MTLRegionMake2D(0,0,w,h),mipmapLevel:level,withBytes:$0.baseAddress!,bytesPerRow:w*components*2) }
    }
}
// Optional screen-footprint fixture. Still an isolated draw, not SceneKit.
let footprint: [String: Any]? = CommandLine.arguments.count > 3 ? try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3]))) as? [String: Any] : nil
let width = footprint?["width"] as? Int ?? 1024
let height = footprint?["height"] as? Int ?? 1024
let diameter = footprint.map { sqrt(($0["ballPixels"] as! Double) * 4 / Double.pi) } ?? 1024
let color=texture(.rgba16Float,width,height,false)
var pipelines=[String:MTLRenderPipelineState]()
var originals=[String:String]()
for (name,index) in [("A",0),("E",1),("EL",3),("R",5)] {
    let data=try Data(contentsOf:root.appendingPathComponent("ab-specialized-2d-\(index)-\(name)-programs.json"))
    let programs=try JSONSerialization.jsonObject(with:data) as! [String:Any]
    let original=(programs["ballPrograms"] as! [String])[0]
    originals[name] = original
    let declaration=original.components(separatedBy:"#pragma declaration")[1].components(separatedBy:"#pragma body")[0]
    var body=original.components(separatedBy:"#pragma body")[1]
    body=body.replacingOccurrences(of:"(scn_frame.inverseViewTransform*float4(_surface.position,1.0)).xyz",with:"_surface.position")
      .replacingOccurrences(of:"(scn_frame.inverseViewTransform*float4(_surface.normal,0.0)).xyz",with:"_surface.normal")
      .replacingOccurrences(of:"scn_frame.inverseViewTransform[3].xyz",with:"float3(0.0,1.0,1.0)")
    let constants=(0..<9).map{"float3 roomSH\($0)=float3(0.1);"}.joined(separator:"\n")
    let source="""
    #include <metal_stdlib>
    using namespace metal;
    struct VS { float4 position [[position]]; float2 uv; };
    vertex VS vertexMain(uint id [[vertex_id]]) {
       float2 p[3]={float2(-1,-1),float2(3,-1),float2(-1,3)};
       return {float4(p[id],0,1),p[id]};
    }
    struct Surface { float3 position; float3 normal; float4 diffuse; };
    \(declaration)
    fragment half4 fragmentMain(VS in [[stage_in]], texture2d<float> roomReflection [[texture(0)]], texture2d<float> filteredRoom [[texture(1)]], texture2d<float> reflectionResponse [[texture(2)]]) {
      float r2=dot(in.uv,in.uv); if(r2>=1) return half4(0,0,0,1);
      Surface _surface; _surface.normal=normalize(float3(in.uv.x,in.uv.y,sqrt(1-r2)));
      _surface.position=float3(0,0.828575,0)+_surface.normal*0.028575;
      _surface.diffuse=float4(0.2,0.1,0.05,1);
      float3 selectedClothAlbedo=float3(0.0074764,0.1612358,0.0036536),roomFloor=float3(0.02);
      \(constants)
      \(body)
      return half4(half3(_surface.diffuse.rgb),1);
    }
    """
    try source.write(to:output.deletingLastPathComponent().appendingPathComponent("native-\(name).metal"),atomically:true,encoding:.utf8)
    let library=try device.makeLibrary(source:source,options:nil)
    let p=MTLRenderPipelineDescriptor();p.vertexFunction=library.makeFunction(name:"vertexMain");p.fragmentFunction=library.makeFunction(name:"fragmentMain");p.colorAttachments[0].pixelFormat=color.pixelFormat
    pipelines[name]=try device.makeRenderPipelineState(descriptor:p)
}
let scene = SCNScene()
let sphere = SCNSphere(radius: 0.028575); sphere.segmentCount = 48
let ball = SCNNode(geometry: sphere); ball.position = SCNVector3(0, 0.828575, 0)
scene.rootNode.addChildNode(ball)
let camera = SCNNode();camera.camera = SCNCamera();camera.position = SCNVector3(0,0.828575,1)
camera.camera!.usesOrthographicProjection = true
camera.camera!.orthographicScale = 0.028575 * Double(height) / diameter
camera.camera!.zNear = 0.01;camera.camera!.zFar = 10
scene.rootNode.addChildNode(camera)
let renderer = SCNRenderer(device: device,options:nil);renderer.scene=scene;renderer.pointOfView=camera
renderer.autoenablesDefaultLighting = false
var materials=[String:SCNMaterial]()
for name in ["A","E","EL","R"] {
 let m=SCNMaterial();m.lightingModel = .constant;m.diffuse.contents = NSColor(red:0.2,green:0.1,blue:0.05,alpha:1)
 m.shaderModifiers = [.surface: originals[name]!]
 for (key,texture) in [("roomReflection",env),("filteredRoom",env),("reflectionResponse",lut)] {m.setValue(SCNMaterialProperty(contents:texture),forKey:key)}
 m.setValue(NSValue(scnVector3:SCNVector3(0.0074764,0.1612358,0.0036536)),forKey:"selectedClothAlbedo")
 m.setValue(NSValue(scnVector3:SCNVector3(0.02,0.02,0.02)),forKey:"roomFloor")
 for i in 0..<9 {m.setValue(NSValue(scnVector3:SCNVector3(0.1,0.1,0.1)),forKey:"roomSH\(i)")}
 materials[name]=m
}
func render(_ name:String)->Double {
 sphere.materials=[materials[name]!]
 SCNTransaction.flush()
 let c=queue.makeCommandBuffer()!,p=MTLRenderPassDescriptor()
 p.colorAttachments[0].texture=color;p.colorAttachments[0].loadAction = .clear;p.colorAttachments[0].storeAction = .store
 renderer.render(atTime:ProcessInfo.processInfo.systemUptime,viewport:CGRect(x:0,y:0,width:width,height:height),commandBuffer:c,passDescriptor:p)
 c.commit();c.waitUntilCompleted();precondition(c.status == .completed)
 return (c.gpuEndTime-c.gpuStartTime)*1000
}
for name in ["A","E","EL","R"] {for _ in 0..<10 {_=render(name)}}
var rows=[[String:Any]]()
for name in ["A","E","A","EL","A","R","A","R","A","EL","A","E","A"] {
 let samples=(0..<30).map{_ in render(name)};let sorted=samples.sorted()
 rows.append(["profile":name,"samplesMS":samples,"medianMS":sorted[15]])
 print(name,sorted[15])
}
let report:[String:Any]=["gpu":device.name,"scope":"Native macOS isolated exported ball shader, synthetic environment and LUT, SceneKit sphere with exported surface shader and synthetic environment/LUT; not full scene, not visual acceptance, not iPhone","width":width,"height":height,"sphereDiameter":diameter,"footprintMode":footprint != nil,"rows":rows]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output)

for name in ["A","R"] {
 _=render(name)
 var pixels=[UInt16](repeating:0,count:width*height*4)
 pixels.withUnsafeMutableBytes { color.getBytes($0.baseAddress!,bytesPerRow:width*8,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0) }
 let data=pixels.withUnsafeBytes { Data($0) }
 try data.write(to:output.deletingPathExtension().appendingPathExtension("\(name).rgba16f"))
}
