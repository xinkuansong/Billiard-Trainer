import Foundation
import Metal
import CryptoKit

func require(_ ok: Bool, _ text: String) throws { if !ok { throw NSError(domain:"ClothTemporal",code:1,userInfo:[NSLocalizedDescriptionKey:text]) } }
func need<T>(_ value:T?,_ text:String)throws->T { try require(value != nil,text);return value! }
func median(_ v:[Double])->Double { let s=v.sorted();return (s[(s.count-1)/2]+s[s.count/2])/2 }
func json(_ o:Any,_ path:URL)throws { try JSONSerialization.data(withJSONObject:o,options:[.prettyPrinted,.sortedKeys]).write(to:path) }
let args=CommandLine.arguments
try require(args.count==5,"source.metal fixture-directory new-output strict|fast")
let fixture=URL(fileURLWithPath:args[2]),out=URL(fileURLWithPath:args[3])
try require(!FileManager.default.fileExists(atPath:out.path),"Output exists")
try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
let input=try Data(contentsOf:fixture.appendingPathComponent("samples.bin"))
let ballData=try Data(contentsOf:fixture.appendingPathComponent("balls.bin"))
try require(input.count>0 && input.count%48==0 && ballData.count==256,"Input contract")
let count=input.count/48,device=try need(MTLCreateSystemDefaultDevice(),"Metal")
let queue=try need(device.makeCommandQueue(),"Queue")
func buffer(_ data:Data)throws->MTLBuffer { try need(data.withUnsafeBytes{device.makeBuffer(bytes:$0.baseAddress!,length:data.count,options:.storageModeShared)},"Buffer") }
let samples=try buffer(input),empty=try buffer(Data(repeating:0,count:256))
let cache=try need(device.makeBuffer(length:count*32,options:.storageModeShared),"Cache")
let result=try need(device.makeBuffer(length:count*32,options:.storageModeShared),"Result")
let options=MTLCompileOptions();options.fastMathEnabled=args[4]=="fast"
let source=try String(contentsOfFile:args[1],encoding:.utf8)
let lib=try device.makeLibrary(source:source,options:options)
var pipes=[String:MTLComputePipelineState]()
for name in ["baseline","generate","consume","classify"] {
    pipes[name]=try device.makeComputePipelineState(function:need(lib.makeFunction(name:name),name))
}
// Synthetic ball translations test cache independence, not billiard physics.
let originalBalls=ballData.withUnsafeBytes{Array($0.bindMemory(to:Float.self))}
var frames=[MTLBuffer]()
for frame in 0..<8 {
    var values=originalBalls
    for b in 0..<16 where values[b*4+3]>0 {
        values[b*4] += Float(frame)*0.035
        values[b*4+1] += Float(frame%3-1)*0.025
    }
    if frame==6 { for b in 0..<16 { values[b*4+3]=0 } }
    if frame==7 { values[0]=0;values[1]=0;values[2]=2.3;values[3]=0.85 }
    frames.append(try buffer(values.withUnsafeBytes{Data($0)}))
}
func encode(_ command:MTLCommandBuffer,_ name:String,_ balls:MTLBuffer,_ valid:Bool=true,_ inputs:MTLBuffer?=nil)throws {
    let e=try need(command.makeComputeCommandEncoder(),"Encoder")
    e.setComputePipelineState(pipes[name]!)
    e.setBuffer(inputs ?? samples,offset:0,index:0);e.setBuffer(balls,offset:0,index:1)
    e.setBuffer(name=="generate" ? cache:result,offset:0,index:2)
    var n=UInt32(count),v:UInt32=valid ? 1:0
    e.setBytes(&n,length:4,index:3)
    if name=="consume" { e.setBuffer(cache,offset:0,index:4);e.setBytes(&v,length:4,index:5) }
    e.dispatchThreads(MTLSize(width:count,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:128,height:1,depth:1))
    e.endEncoding()
}
func run(_ mode:String,_ n:Int=1,_ frame:Int=0,_ valid:Bool=true,_ inputs:MTLBuffer?=nil)throws->Double {
    try require(ProcessInfo.processInfo.thermalState != .serious && ProcessInfo.processInfo.thermalState != .critical,"Host thermal")
    let cb=try need(queue.makeCommandBuffer(),"Command")
    if mode=="total" { try encode(cb,"generate",empty,true,inputs) }
    for i in 0..<n {
        try encode(cb,mode=="total" ? "consume":mode,mode=="generate" ? empty:frames[(frame+i)%frames.count],valid,inputs)
    }
    cb.commit();cb.waitUntilCompleted()
    try require(cb.status == .completed,"GPU failure \(String(describing:cb.error))")
    let t=(cb.gpuEndTime-cb.gpuStartTime)*1000
    try require(t>0 && t.isFinite,"GPU time missing");return t
}
func bytes()->Data { Data(bytes:result.contents(),count:count*32) }
_ = try run("generate")
var checks=[[String:Any]](),nearFractions=[Double]()
for frame in 0..<8 {
    _ = try run("baseline",1,frame);let a=bytes()
    _ = try run("consume",1,frame);let b=bytes()
    _ = try run("consume",1,frame,false);let fallback=bytes()
    try require(a==b && a==fallback,"Lighting mismatch at frame \(frame)")
    try require(a.withUnsafeBytes{$0.bindMemory(to:Float.self).allSatisfy{$0.isFinite}},"Nonfinite")
    _ = try run("classify",1,frame)
    let near=result.contents().bindMemory(to:UInt32.self,capacity:count)
    let n=(0..<count).reduce(0){$0+Int(near[$1])};nearFractions.append(Double(n)/Double(count))
    checks.append(["frame":frame,"bitExact":true,"fallbackExact":true,"nearCount":n])
}
// Any actual input change invalidates the generation. Exercise view, geometry,
// normal and roughness separately, plus rebuild; no fuzzy input key.
var invalidation=[[String:Any]]()
for (name,index,delta) in [("position",0,Float(0.005)),("normal",4,0.04),("view",8,0.03),("roughness",11,0.02)] {
    var f=input.withUnsafeBytes{Array($0.bindMemory(to:Float.self))}
    for i in 0..<count { f[i*12+index] += delta }
    let changed=try buffer(f.withUnsafeBytes{Data($0)})
    _ = try run("baseline",1,0,true,changed);let a=bytes()
    _ = try run("consume",1,0,false,changed);try require(a==bytes(),"Invalidation \(name)")
    _ = try run("generate",1,0,true,changed)
    _ = try run("consume",1,0,true,changed);try require(a==bytes(),"Rebuild \(name)")
    invalidation.append(["input":name,"fallbackExact":true,"rebuildExact":true])
}
_ = try run("generate")
try json(["frames":checks,"invalidations":invalidation,"fastMath":options.fastMathEnabled],out.appendingPathComponent("validation.json"))
if options.fastMathEnabled { print("fast validation passed");exit(0) }
for _ in 0..<3 { _ = try run("baseline",8);_ = try run("consume",8) }
func pair(_ a:String,_ b:String,_ n:Int)throws->[String:Any] {
    var rows=[[String:Any]](),changes=[Double](),av=[Double](),bv=[Double]()
    for cycle in 0..<6 {
        let order=cycle%2==0 ? [false,true,true,false]:[true,false,false,true]
        var aa=[Double](),bb=[Double](),raw=[Double]()
        for useB in order {
            let value=try run(useB ? b:a,n)
            raw.append(value);if useB {bb.append(value);bv.append(value)}else{aa.append(value);av.append(value)}
        }
        let change=(median(bb)/median(aa)-1)*100;changes.append(change)
        rows.append(["cycle":cycle,"order":order.map{$0 ? "B":"A"},"gpuMS":raw,"changePercent":change])
    }
    return ["referenceMedianMS":median(av),"candidateMedianMS":median(bv),"pairedChangePercent":median(changes),"cycles":rows]
}
let aa=try pair("baseline","baseline",8)
var reports=[String:Any]()
reports["aa"]=aa;reports["steady"]=try pair("baseline","consume",8)
for n in [1,2,8,60] { reports["generationPlus\(n)Frames"]=try pair("baseline","total",n) }
var gen=[Double]()
for _ in 0..<9 {gen.append(try run("generate"))}
let report:[String:Any]=["device":device.name,"inputs":count,"cacheBytes":cache.allocatedSize,"minimumCacheBytes":count*32,
 "generationMedianMS":median(gen),"nearFractions":nearFractions,"comparisons":reports,
 "scope":"Real pixel inputs, synthetic moving-ball dependency test; math compute plus cache generation/read only. Excludes SceneKit capture/raster/MSAA/synchronization and full viewport allocation."]
try json(report,out.appendingPathComponent("result.json"))
print("\(fixture.lastPathComponent): \(count) pixels; all outputs exact; steady \((reports["steady"] as! [String:Any])["pairedChangePercent"]!)%")
