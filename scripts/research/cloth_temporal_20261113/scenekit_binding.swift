import Foundation
import AppKit
import SceneKit
import Metal
import QuartzCore
import Darwin

// Capability probe only: prove SceneKit's actual generated shader can bind a
// writable custom texture. No performance or production-equivalence claim.
func need<T>(_ x:T?,_ s:String)throws->T { guard let x else {throw NSError(domain:"ClothBinding",code:1,userInfo:[NSLocalizedDescriptionKey:s])};return x }
let out=URL(fileURLWithPath:CommandLine.arguments[1])
try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
DispatchQueue.global().asyncAfter(deadline:.now()+45){fputs("binding timeout\n",stderr);_exit(124)}
let device=try need(MTLCreateSystemDefaultDevice(),"device"),queue=try need(device.makeCommandQueue(),"queue")
let w=64,h=64
let cacheD=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:w,height:h,mipmapped:false)
cacheD.usage=[.shaderRead,.shaderWrite];cacheD.storageMode = .shared
let cache=try need(device.makeTexture(descriptor:cacheD),"cache")
let zeros=[Float](repeating:0,count:w*h*4)
zeros.withUnsafeBytes{cache.replace(region:MTLRegionMake2D(0,0,w,h),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:w*16)}
let property=SCNMaterialProperty(contents:cache)
let material=SCNMaterial();material.lightingModel = .constant;material.diffuse.contents=NSColor.green
material.setValue(property,forKey:"temporalOut")
let modifier="""
#pragma arguments
texture2d<float, access::write> temporalOut;
#pragma body
float4 clip=scn_frame.projectionTransform*float4(_surface.position,1.0);
float2 uv=clip.xy/clip.w*float2(0.5,-0.5)+0.5;
uint2 pixel=uint2(uv*float2(temporalOut.get_width(),temporalOut.get_height()));
temporalOut.write(float4(0.125,0.25,0.5,1.0),pixel);
"""
try modifier.write(to:out.appendingPathComponent("modifier.metal"),atomically:true,encoding:.utf8)
material.shaderModifiers=[.surface:modifier]
let plane=SCNPlane(width:2,height:2);plane.firstMaterial=material
let scene=SCNScene();scene.rootNode.addChildNode(SCNNode(geometry:plane))
let eye=SCNNode();eye.camera=SCNCamera();eye.camera!.usesOrthographicProjection=true;eye.camera!.orthographicScale=1.2;eye.position=SCNVector3(0,0,4)
scene.rootNode.addChildNode(eye)
let renderer=SCNRenderer(device:device,options:nil);renderer.scene=scene;renderer.pointOfView=eye
let colorD=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm,width:w,height:h,mipmapped:false)
colorD.usage = .renderTarget;colorD.storageMode = .private
let color=try need(device.makeTexture(descriptor:colorD),"color")
SCNTransaction.flush()
for _ in 0..<2 {
 let command=try need(queue.makeCommandBuffer(),"command"),pass=MTLRenderPassDescriptor()
 pass.colorAttachments[0].texture=color;pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store
 renderer.render(atTime:1,viewport:CGRect(x:0,y:0,width:w,height:h),commandBuffer:command,passDescriptor:pass)
 command.commit();command.waitUntilCompleted()
 if command.status != .completed {throw command.error ?? NSError(domain:"ClothBinding",code:2)}
}
var values=[Float](repeating:0,count:w*h*4)
values.withUnsafeMutableBytes{cache.getBytes($0.baseAddress!,bytesPerRow:w*16,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)}
let written=(0..<w*h).filter{values[$0*4+3]==1}.count
let result:[String:Any]=["device":device.name,"writtenPixels":written,"center":Array(values[(32*w+32)*4..<(32*w+32)*4+4]),"scope":"SCNRenderer synthetic-plane writable texture binding only; no performance/MSAA/production proof"]
try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("result.json"))
print("written pixels \(written)")
if written==0 {exit(2)}
