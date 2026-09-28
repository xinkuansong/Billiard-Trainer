import Foundation
import Metal
import CoreGraphics
import ImageIO
let root=URL(fileURLWithPath:CommandLine.arguments[1]),device=MTLCreateSystemDefaultDevice()!
let queue=device.makeCommandQueue()!
let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:1024,height:512,mipmapped:false);d.usage=[.renderTarget,.shaderRead];d.storageMode = .shared
let target=device.makeTexture(descriptor:d)!
let td=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.r16Float,width:1,height:1,mipmapped:false);td.usage = .shaderRead
let neutral=device.makeTexture(descriptor:td)!;var one:UInt16=Float16(1).bitPattern
neutral.replace(region:MTLRegionMake2D(0,0,1,1),mipmapLevel:0,withBytes:&one,bytesPerRow:2)
let lutRoot=URL(fileURLWithPath:CommandLine.arguments[2])
let meta=try JSONSerialization.jsonObject(with:Data(contentsOf:lutRoot.appendingPathComponent("lut.json"))) as! [String:Any]
let caseIndex=CommandLine.arguments.count>3 ? Int(CommandLine.arguments[3])! : 0
let first=(meta["cases"] as! [[String:Any]])[caseIndex]
let extent=Float(first["extent"] as! Double)
let center=first["ball"] as! [Double]
var positions=(0..<16).map{i in SIMD4<Float>(-0.9+Float(i%4)*0.6,-0.45+Float(i/4)*0.3,0.028575,0.85)}
positions = [SIMD4<Float>(Float(center[0]),Float(center[2]),Float(center[1]-0.8),0.85)] + Array(repeating:SIMD4<Float>(0,0,0.028575,0),count:15)
let balls=device.makeBuffer(bytes:&positions,length:16*MemoryLayout<SIMD4<Float>>.stride,options:.storageModeShared)!
var pipelines=[String:MTLRenderPipelineState]()
for name in ["A","S","L"] {
 let source=try String(contentsOf:root.appendingPathComponent("cloth-\(name).metal"),encoding:.utf8)
 let lib=try device.makeLibrary(source:source,options:nil),p=MTLRenderPipelineDescriptor()
 p.vertexFunction=lib.makeFunction(name:"vertexMain");p.fragmentFunction=lib.makeFunction(name:"fragmentMain");p.colorAttachments[0].pixelFormat=target.pixelFormat
 pipelines[name]=try device.makeRenderPipelineState(descriptor:p)
}
let patchDescriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.r16Float,width:128,height:128,mipmapped:false);patchDescriptor.usage = .shaderRead
var patches=[MTLTexture]()
for index in [caseIndex,caseIndex+1] {
 let texture=device.makeTexture(descriptor:patchDescriptor)!,data=try Data(contentsOf:lutRoot.appendingPathComponent("patch-\(index).r16f"))
 data.withUnsafeBytes{texture.replace(region:MTLRegionMake2D(0,0,128,128),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:256)};patches.append(texture)
}
let visibilityDescriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rg16Float,width:512,height:256,mipmapped:false);visibilityDescriptor.usage=[.renderTarget,.shaderRead];visibilityDescriptor.storageMode = .private
let visibility=device.makeTexture(descriptor:visibilityDescriptor)!
let localSource="""
#include <metal_stdlib>
using namespace metal;
struct Out {float4 position [[position]];float2 uv;};
vertex Out localVertex(uint id [[vertex_id]],constant float& extent [[buffer(0)]],constant float4& ball [[buffer(1)]]) {
 float2 p[6]={float2(-1,-1),float2(1,-1),float2(-1,1),float2(-1,1),float2(1,-1),float2(1,1)};
 return {float4((p[id]*extent+ball.xy)/float2(1.27,0.635),0,1),p[id]*0.5+0.5};
}
fragment half2 localFragment(Out in [[stage_in]],texture2d<float> p0 [[texture(0)]],texture2d<float> p1 [[texture(1)]]) {
 constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::linear);
 return half2(1.0-p0.sample(s,in.uv).r,1.0-p1.sample(s,in.uv).r);
}
"""
let localLibrary=try device.makeLibrary(source:localSource,options:nil),localDescriptor=MTLRenderPipelineDescriptor()
localDescriptor.vertexFunction=localLibrary.makeFunction(name:"localVertex");localDescriptor.fragmentFunction=localLibrary.makeFunction(name:"localFragment");localDescriptor.colorAttachments[0].pixelFormat = .rg16Float
let localPipeline=try device.makeRenderPipelineState(descriptor:localDescriptor)
func image(_ name:String) throws {
 var half=[UInt16](repeating:0,count:target.width*target.height*4)
 half.withUnsafeMutableBytes{target.getBytes($0.baseAddress!,bytesPerRow:target.width*8,from:MTLRegionMake2D(0,0,target.width,target.height),mipmapLevel:0)}
 var bytes=[UInt8](repeating:255,count:half.count)
 for i in 0..<half.count where i%4 != 3 {let f=Float(Float16(bitPattern:half[i]));precondition(f.isFinite);bytes[i]=UInt8(min(255,max(0,pow(max(0,f),1/2.2)*255)))}
 let data=Data(bytes),provider=CGDataProvider(data:data as CFData)!
 let cg=CGImage(width:target.width,height:target.height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:target.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
 let dest=CGImageDestinationCreateWithURL(root.appendingPathComponent("local-\(name).png") as CFURL,"public.png" as CFString,1,nil)!
 CGImageDestinationAddImage(dest,cg,nil);precondition(CGImageDestinationFinalize(dest))
 half.withUnsafeBytes{try! Data($0).write(to:root.appendingPathComponent("local-\(name).rgba16f"))}
}
func render(_ name:String)->Double {
 let c=queue.makeCommandBuffer()!,p=MTLRenderPassDescriptor();p.colorAttachments[0].texture=target;p.colorAttachments[0].loadAction = .dontCare;p.colorAttachments[0].storeAction = .store
 if name == "L" {
  let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=visibility;pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store;pass.colorAttachments[0].clearColor=MTLClearColorMake(1,1,1,1)
  let encoder=c.makeRenderCommandEncoder(descriptor:pass)!;encoder.setRenderPipelineState(localPipeline);var value=extent;encoder.setVertexBytes(&value,length:4,index:0);encoder.setVertexBuffer(balls,offset:0,index:1);encoder.setFragmentTexture(patches[0],index:0);encoder.setFragmentTexture(patches[1],index:1);encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6);encoder.endEncoding()
 }
 let e=c.makeRenderCommandEncoder(descriptor:p)!;e.setFragmentTexture(visibility,index:1);e.setRenderPipelineState(pipelines[name]!);e.setFragmentTexture(neutral,index:0);e.setFragmentBuffer(balls,offset:0,index:0);e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3);e.endEncoding();c.commit();c.waitUntilCompleted();precondition(c.status == .completed)
 return (c.gpuEndTime-c.gpuStartTime)*1000
}
for name in ["A","S","L"] {for _ in 0..<10 {_=render(name)}}
var rows=[[String:Any]]()
for name in ["A","S","A","L","A","L","A","S","A"] {let values=(0..<30).map{_ in render(name)};rows.append(["profile":name,"samplesMS":values,"medianMS":values.sorted()[15]]);print(name,values.sorted()[15]);try image(name)}
try JSONSerialization.data(withJSONObject:["fixture":first,"gpu":device.name,"scope":"isolated cloth, flat normal, one selected offline LUT fixture ball, 1024x512. L includes 512x256 RG16F visibility generation via local quad plus cloth consumption each frame; not moving-ball/full-app acceptance", "rows":rows],options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("native-local-shadow.json"))
