import Foundation
import Metal
let root=URL(fileURLWithPath:CommandLine.arguments[1]),device=MTLCreateSystemDefaultDevice()!
let queue=device.makeCommandQueue()!
let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:1024,height:512,mipmapped:false);d.usage=[.renderTarget,.shaderRead];d.storageMode = .shared
let target=device.makeTexture(descriptor:d)!
let td=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.r16Float,width:1,height:1,mipmapped:false);td.usage = .shaderRead
let neutral=device.makeTexture(descriptor:td)!;var one:UInt16=Float16(1).bitPattern
neutral.replace(region:MTLRegionMake2D(0,0,1,1),mipmapLevel:0,withBytes:&one,bytesPerRow:2)
var positions=(0..<16).map{i in SIMD4<Float>(-0.9+Float(i%4)*0.6,-0.45+Float(i/4)*0.3,0.028575,0.85)}
let balls=device.makeBuffer(bytes:&positions,length:16*MemoryLayout<SIMD4<Float>>.stride,options:.storageModeShared)!
var pipelines=[String:MTLRenderPipelineState]()
for name in ["A","S"] {
 let source=try String(contentsOf:root.appendingPathComponent("cloth-\(name).metal"),encoding:.utf8)
 let lib=try device.makeLibrary(source:source,options:nil),p=MTLRenderPipelineDescriptor()
 p.vertexFunction=lib.makeFunction(name:"vertexMain");p.fragmentFunction=lib.makeFunction(name:"fragmentMain");p.colorAttachments[0].pixelFormat=target.pixelFormat
 pipelines[name]=try device.makeRenderPipelineState(descriptor:p)
}
func render(_ name:String)->Double {
 let c=queue.makeCommandBuffer()!,p=MTLRenderPassDescriptor();p.colorAttachments[0].texture=target;p.colorAttachments[0].loadAction = .dontCare;p.colorAttachments[0].storeAction = .store
 let e=c.makeRenderCommandEncoder(descriptor:p)!;e.setRenderPipelineState(pipelines[name]!);e.setFragmentTexture(neutral,index:0);e.setFragmentBuffer(balls,offset:0,index:0);e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3);e.endEncoding();c.commit();c.waitUntilCompleted();precondition(c.status == .completed)
 return (c.gpuEndTime-c.gpuStartTime)*1000
}
for name in ["A","S"] {for _ in 0..<10 {_=render(name)}}
var rows=[[String:Any]]()
for name in ["A","S","A","S","A"] {let values=(0..<30).map{_ in render(name)};rows.append(["profile":name,"samplesMS":values,"medianMS":values.sorted()[15]]);print(name,values.sorted()[15])}
try JSONSerialization.data(withJSONObject:["gpu":device.name,"scope":"isolated cloth production surface, flat normal, 16 uniform grid balls, 1024x512, no SceneKit passes; not full app", "rows":rows],options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("native-cloth.json"))
