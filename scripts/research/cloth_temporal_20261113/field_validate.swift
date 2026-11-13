import Foundation
import Metal
import CryptoKit

func need<T>(_ value:T?,_ message:String)throws->T {guard let value else{throw NSError(domain:"FieldValidation",code:1,userInfo:[NSLocalizedDescriptionKey:message])};return value}
func require(_ value:Bool,_ message:String)throws{if !value{throw NSError(domain:"FieldValidation",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
let root=URL(fileURLWithPath:CommandLine.arguments[1]),shader=URL(fileURLWithPath:CommandLine.arguments[2])
let output=URL(fileURLWithPath:CommandLine.arguments[3])
try require(!FileManager.default.fileExists(atPath:output.path),"Refuse overwrite")
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let device=try need(MTLCreateSystemDefaultDevice(),"No Metal"),queue=try need(device.makeCommandQueue(),"No queue")
let manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:shader.appendingPathComponent("manifest.json"))) as! [String:Any]
let dimensions=manifest["size"] as! [Int]
let d=MTLTextureDescriptor();d.textureType = .type3D;d.pixelFormat = .rgba32Float;d.width=dimensions[0];d.height=dimensions[1];d.depth=dimensions[2];d.usage=[.shaderRead,.shaderWrite];d.storageMode = .shared
let f0=try need(device.makeTexture(descriptor:d),"Field0"),f1=try need(device.makeTexture(descriptor:d),"Field1")
let gen=try String(contentsOf:shader.appendingPathComponent("generate.metal"),encoding:.utf8)
let surface=try String(contentsOf:shader.appendingPathComponent("candidate.surface"),encoding:.utf8)
let functions=String(surface[surface.range(of:"float3 v62EmitterCenter(")!.lowerBound..<surface.range(of:"// Research-only mask predicate.")!.lowerBound])
let source="""
#include <metal_stdlib>
using namespace metal;
\(functions)
struct Input {float4 p,n,v;};
struct Output {float4 reference,candidate;};
kernel void checkField(device const Input *input [[buffer(0)]],device Output *output [[buffer(1)]],constant uint &count [[buffer(2)]],texture3d<float> f0 [[texture(0)]],texture3d<float> f1 [[texture(1)]],uint i [[thread_position_in_grid]]) {
 if(i>=count)return;
 float3 p=input[i].p.xyz,n=input[i].n.xyz;
 output[i]={float4(v62PanelDiffuse(p,n),0),float4(temporalFieldDiffuse(p,n,f0,f1),float(temporalFieldEligible(p,n)))};
}
"""
try source.write(to:output.appendingPathComponent("check.metal"),atomically:true,encoding:.utf8)
let gl=try device.makeLibrary(source:gen,options:nil),gp=try device.makeComputePipelineState(function:need(gl.makeFunction(name:"generateField"),"Generator"))
let cb=try need(queue.makeCommandBuffer(),"Command"),e=try need(cb.makeComputeCommandEncoder(),"Encoder")
e.setComputePipelineState(gp);e.setTexture(f0,index:0);e.setTexture(f1,index:1);e.dispatchThreads(MTLSize(width:d.width,height:d.height,depth:d.depth),threadsPerThreadgroup:MTLSize(width:8,height:4,depth:4));e.endEncoding();cb.commit();cb.waitUntilCompleted();try require(cb.status == .completed,"Generation failed")
let names=["single-low","single-near","edge-low","rack-overview","scatter-overview"]
var fixtures=names.map{root.appendingPathComponent("output/render-lowdim-20261113/pixel-lowk-r3/\($0)/samples.bin")}
fixtures.append(root.appendingPathComponent("output/render-activity-20261113/c1-static-field-compact/boundary.bin"))
var summaries=[[String:Any]]()
for fast in [false,true] {
 let opts=MTLCompileOptions();opts.fastMathEnabled=fast
 let lib=try device.makeLibrary(source:source,options:opts),pipeline=try device.makeComputePipelineState(function:need(lib.makeFunction(name:"checkField"),"Check"))
 for fixture in fixtures {
  try autoreleasepool {
   let data=try Data(contentsOf:fixture),count=data.count/48
   let input=try need(data.withUnsafeBytes{device.makeBuffer(bytes:$0.baseAddress!,length:data.count,options:.storageModeShared)},"Input")
   let result=try need(device.makeBuffer(length:count*32,options:.storageModeShared),"Result")
   let command=try need(queue.makeCommandBuffer(),"Command"),encoder=try need(command.makeComputeCommandEncoder(),"Encoder")
   encoder.setComputePipelineState(pipeline);encoder.setBuffer(input,offset:0,index:0);encoder.setBuffer(result,offset:0,index:1);var n=UInt32(count);encoder.setBytes(&n,length:4,index:2);encoder.setTexture(f0,index:0);encoder.setTexture(f1,index:1);encoder.dispatchThreads(MTLSize(width:count,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:128,height:1,depth:1));encoder.endEncoding();command.commit();command.waitUntilCompleted();try require(command.status == .completed,"Check GPU failure")
   let values=result.contents().bindMemory(to:Float.self,capacity:count*8)
   var hits=0,fallbackChanges=0,nonfinite=0,maxAbs=0.0,maxRelative=0.0,squared=0.0
   for i in 0..<count {
    let hit=values[i*8+7]>0;if hit{hits+=1}
    for j in 0..<3 {
     let a=values[i*8+j],b=values[i*8+j+4],error=abs(Double(b)-Double(a))
     if !a.isFinite || !b.isFinite {nonfinite+=1;continue}
     if !hit && a.bitPattern != b.bitPattern {fallbackChanges+=1}
     maxAbs=max(maxAbs,error);squared+=error*error
     if abs(a)>0.001 {maxRelative=max(maxRelative,error/abs(Double(a)))}
    }
   }
   summaries.append(["fixture":fixture.path,"inputSHA256":SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined(),"fastMath":fast,"inputs":count,"hits":hits,"fallback":count-hits,"fallbackChangedChannels":fallbackChanges,"nonfinite":nonfinite,"maxAbsoluteIrradiance":maxAbs,"maxRelativeAbove001":maxRelative,"rmsIrradiance":sqrt(squared/Double(count*3))])
   print(fixture.deletingLastPathComponent().lastPathComponent,fast,count,hits,maxAbs,maxRelative,fallbackChanges,nonfinite)
   try require(nonfinite==0 && fallbackChanges==0,"Invalid/fallback mismatch")
  }
 }
}
try JSONSerialization.data(withJSONObject:summaries,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("results.json"))
