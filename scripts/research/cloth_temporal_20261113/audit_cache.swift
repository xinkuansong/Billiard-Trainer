import Foundation
import Metal
func need<T>(_ x:T?)throws->T {guard let x else{throw NSError(domain:"CacheAudit",code:1)};return x}
let args=CommandLine.arguments,root=URL(fileURLWithPath:args[2]),pose=args[3]
let device=try need(MTLCreateSystemDefaultDevice()),q=try need(device.makeCommandQueue())
let layers=try (0..<5).map{i->[Float] in let d=try Data(contentsOf:root.appendingPathComponent("\(pose)-cache-\(i).bin"));return d.withUnsafeBytes{Array($0.bindMemory(to:Float.self))}}
var inputs=[Float](),expected=[Float](),indices=[Int]()
for i in 0..<layers[0].count/4 where layers[1][i*4+3]==1 && layers[2][i*4+3]==1 {
 inputs += Array(layers[0][i*4..<i*4+3])+[0]
 inputs += Array(layers[1][i*4..<i*4+3])+[0]
 inputs += Array(layers[2][i*4..<i*4+3])+[layers[0][i*4+3]]
 expected += Array(layers[3][i*4..<i*4+4])+Array(layers[4][i*4..<i*4+4]);indices.append(i)
}
let count=indices.count,options=MTLCompileOptions();options.fastMathEnabled=true
let lib=try device.makeLibrary(source:String(contentsOfFile:args[1],encoding:.utf8),options:options)
let pipe=try device.makeComputePipelineState(function:need(lib.makeFunction(name:"baseline")))
let input=try need(inputs.withUnsafeBytes{device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)})
let zero=[Float](repeating:0,count:64)
let balls=try need(zero.withUnsafeBytes{device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)})
let output=try need(device.makeBuffer(length:count*32,options:.storageModeShared)),cb=try need(q.makeCommandBuffer()),e=try need(cb.makeComputeCommandEncoder())
e.setComputePipelineState(pipe);e.setBuffer(input,offset:0,index:0);e.setBuffer(balls,offset:0,index:1);e.setBuffer(output,offset:0,index:2)
var n=UInt32(count);e.setBytes(&n,length:4,index:3);e.dispatchThreads(MTLSize(width:count,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:128,height:1,depth:1));e.endEncoding();cb.commit();cb.waitUntilCompleted()
if cb.status != .completed {throw cb.error ?? NSError(domain:"CacheAudit",code:2)}
let result=output.contents().bindMemory(to:Float.self,capacity:count*8)
var maxError:Float=0,bad=0,worst=[String:Any](),first=[[String:Any]]()
for i in 0..<count {
 var error:Float=0
 for c in [0,1,2,4,5,6] {error=max(error,abs(result[i*8+c]-expected[i*8+c]))}
 if error>0.0001 {bad += 1;if first.count<8 {first.append(["pixel":indices[i],"absoluteError":error])}}
 if error>maxError {maxError=error;worst=["pixel":indices[i],"input":Array(inputs[i*12..<i*12+12]),"expectedFromKeys":Array(UnsafeBufferPointer(start:result+i*8,count:8)),"stored":Array(expected[i*8..<i*8+8])]}
}
let report:[String:Any]=["cachedPixels":count,"over1eMinus4":bad,"maximumAbsoluteError":maxError,"worst":worst,"first":first,"scope":"Detect corrupted cache/value association; normal/view are renormalized by independent math probe, so not a bit-equality test"]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("\(pose)-cache-audit.json"))
print(pose,count,bad,maxError)
