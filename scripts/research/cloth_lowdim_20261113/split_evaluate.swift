import Foundation
import Metal

func failure(_ m:String)->NSError { NSError(domain:"ClothSplit",code:1,userInfo:[NSLocalizedDescriptionKey:m]) }
func median(_ values:[Double])->Double { let s=values.sorted();return (s[(s.count-1)/2]+s[s.count/2])/2 }
guard (6...7).contains(CommandLine.arguments.count) else { throw failure("split_evaluate kernels.metal samples.bin balls.bin moments.bin output-directory [batch-count]") }
let args=CommandLine.arguments
let batchCount=args.count==7 ? (Int(args[6]) ?? 0) : 1
guard (1...32).contains(batchCount) else { throw failure("Invalid batch count") }
let source=try String(contentsOfFile:args[1],encoding:.utf8)
let input=try Data(contentsOf:URL(fileURLWithPath:args[2]))
let ballData=try Data(contentsOf:URL(fileURLWithPath:args[3]))
let momentData=try Data(contentsOf:URL(fileURLWithPath:args[4]))
let out=URL(fileURLWithPath:args[5],isDirectory:true)
guard !FileManager.default.fileExists(atPath:out.path) else { throw failure("Output exists") }
try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
guard input.count>0,input.count%48==0,ballData.count==256 else { throw failure("Invalid records") }
let count=input.count/48
let groups=momentData.count/(count*16)-2
guard momentData.count%(count*16)==0,(1...64).contains(groups) else { throw failure("Invalid moments") }
for data in [input,ballData,momentData] {
    guard data.withUnsafeBytes({$0.bindMemory(to:Float.self).allSatisfy({$0.isFinite})}) else { throw failure("Nonfinite input") }
}
let flags=momentData.withUnsafeBytes { raw in (0..<count).map { raw.bindMemory(to:Float.self)[$0*(groups+2)*4+3] } }
guard flags.allSatisfy({$0==0 || $0==1}) else { throw failure("Invalid eligibility flag") }
guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else { throw failure("Metal unavailable") }
let opts=MTLCompileOptions();opts.fastMathEnabled=false
let lib=try device.makeLibrary(source:source,options:opts)
var psos=[String:MTLComputePipelineState]()
for name in ["evaluateReference","evaluateCandidate","classifyRecords","makeIndirectArguments","evaluateSplitCandidate","evaluateSplitFallback"] {
    guard let f=lib.makeFunction(name:name) else { throw failure("Missing kernel \(name)") }
    let p=try device.makeComputePipelineState(function:f)
    guard p.maxTotalThreadsPerThreadgroup>=128 else { throw failure("Unsupported threadgroup capacity") }
    psos[name]=p
}
func buffer(_ d:Data)throws->MTLBuffer {
    guard let b=d.withUnsafeBytes({device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)}) else { throw failure("Input allocation") };return b
}
func allocate(_ size:Int)throws->MTLBuffer {
    guard let b=device.makeBuffer(length:size,options:.storageModeShared) else { throw failure("Output allocation") };return b
}
let samples=try buffer(input),balls=try buffer(ballData),moments=try buffer(momentData)
let result=try allocate(count*64),counts=try allocate(8),eligible=try allocate(count*4),fallback=try allocate(count*4),indirect=try allocate(24)
var sampleCount=UInt32(count),groupCount=UInt32(groups)
let threads=MTLSize(width:128,height:1,depth:1)
func bind(_ e:MTLComputeCommandEncoder) {
    e.setBuffer(samples,offset:0,index:0);e.setBuffer(balls,offset:0,index:1);e.setBuffer(result,offset:0,index:2)
    e.setBytes(&sampleCount,length:4,index:3);e.setBuffer(moments,offset:0,index:4);e.setBytes(&groupCount,length:4,index:5)
}
func run(_ mode:String)throws->Double {
    guard let c=queue.makeCommandBuffer() else { throw failure("Command buffer") };c.label="ClothSplit."+mode
    for _ in 0..<batchCount {
    if mode=="split" {
        guard let b=c.makeBlitCommandEncoder() else { throw failure("Clear encoder") }
        b.fill(buffer:counts,range:0..<8,value:0);b.endEncoding()
        guard let classify=c.makeComputeCommandEncoder() else { throw failure("Classify encoder") }
        classify.setComputePipelineState(psos["classifyRecords"]!);classify.setBuffer(moments,offset:0,index:0)
        classify.setBuffer(counts,offset:0,index:1);classify.setBuffer(eligible,offset:0,index:2);classify.setBuffer(fallback,offset:0,index:3)
        classify.setBytes(&sampleCount,length:4,index:4);classify.setBytes(&groupCount,length:4,index:5)
        classify.dispatchThreadgroups(MTLSize(width:(count+127)/128,height:1,depth:1),threadsPerThreadgroup:threads);classify.endEncoding()
        guard let finish=c.makeComputeCommandEncoder() else { throw failure("Arguments encoder") }
        finish.setComputePipelineState(psos["makeIndirectArguments"]!);finish.setBuffer(counts,offset:0,index:0);finish.setBuffer(indirect,offset:0,index:1)
        finish.dispatchThreadgroups(MTLSize(width:1,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:2,height:1,depth:1));finish.endEncoding()
        guard let consume=c.makeComputeCommandEncoder() else { throw failure("Consume encoder") }
        bind(consume);consume.setBuffer(counts,offset:0,index:7)
        consume.setComputePipelineState(psos["evaluateSplitCandidate"]!);consume.setBuffer(eligible,offset:0,index:6)
        consume.dispatchThreadgroups(indirectBuffer:indirect,indirectBufferOffset:0,threadsPerThreadgroup:threads)
        consume.setComputePipelineState(psos["evaluateSplitFallback"]!);consume.setBuffer(fallback,offset:0,index:6)
        consume.dispatchThreadgroups(indirectBuffer:indirect,indirectBufferOffset:12,threadsPerThreadgroup:threads);consume.endEncoding()
    } else {
        guard let e=c.makeComputeCommandEncoder() else { throw failure("Encoder") };bind(e)
        e.setComputePipelineState(psos[mode=="reference" ? "evaluateReference":"evaluateCandidate"]!)
        e.dispatchThreadgroups(MTLSize(width:(count+127)/128,height:1,depth:1),threadsPerThreadgroup:threads);e.endEncoding()
    }
    }
    c.commit();c.waitUntilCompleted()
    guard c.status == .completed else { throw c.error ?? failure("GPU execution") }
    return (c.gpuEndTime-c.gpuStartTime)*1000/Double(batchCount)
}
func floats(_ b:MTLBuffer,_ number:Int)->[Float] { Array(UnsafeBufferPointer(start:b.contents().bindMemory(to:Float.self,capacity:number),count:number)) }
var values=[String:[Float]]()
for mode in ["reference","mixed","split"] {
    _=try run(mode)
    values[mode]=floats(result,count*16)
    guard values[mode]!.allSatisfy({$0.isFinite}) else { throw failure("Nonfinite output") }
    try Data(bytes:result.contents(),count:count*64).write(to:out.appendingPathComponent(mode+".bin"))
}
let cpuCounts=counts.contents().bindMemory(to:UInt32.self,capacity:2)
let expectedEligible=flags.filter({$0==1}).count
let actualEligible=Int(cpuCounts[0]),actualFallback=Int(cpuCounts[1])
guard actualEligible==expectedEligible,actualEligible+actualFallback==count else { throw failure("Classification count mismatch") }
let idsA=Array(UnsafeBufferPointer(start:eligible.contents().bindMemory(to:UInt32.self,capacity:count),count:actualEligible))
let idsB=Array(UnsafeBufferPointer(start:fallback.contents().bindMemory(to:UInt32.self,capacity:count),count:actualFallback))
guard Set(idsA+idsB).count==count,Set(idsA+idsB)==Set((0..<count).map(UInt32.init)),
      idsA.allSatisfy({flags[Int($0)]==1}),idsB.allSatisfy({flags[Int($0)]==0}) else { throw failure("Classification partition incorrect") }
var maxError:Float=0
var fallbackExact=true
for i in 0..<count {
    for j in 0..<16 {
        maxError=max(maxError,abs(values["split"]![i*16+j]-values["mixed"]![i*16+j]))
        if flags[i]==0 && values["split"]![i*16+j].bitPattern != values["reference"]![i*16+j].bitPattern { fallbackExact=false }
    }
}
guard maxError<=2e-4,fallbackExact else { throw failure("Output mismatch max=\(maxError) fallbackExact=\(fallbackExact)") }
for _ in 0..<3 { for mode in ["reference","mixed","split"] {_=try run(mode)} }
var comparisons=[[String:Any]]()
for candidate in ["mixed","split"] {
    var rows=[[String:Any]](),changes=[Double](),baseline=[Double](),trial=[Double]()
    for cycle in 0..<9 {
        let order = cycle%2==0 ? ["reference",candidate,candidate,"reference"] : [candidate,"reference","reference",candidate]
        var times=[Double](),a=[Double](),b=[Double]()
        for mode in order {
            let t=try run(mode);times.append(t)
            if mode=="reference" {a.append(t);baseline.append(t)} else {b.append(t);trial.append(t)}
        }
        let change=(median(b)/median(a)-1)*100;changes.append(change)
        rows.append(["cycle":cycle,"order":order,"commandSpanMS":times,"referencePairMedianMS":median(a),"candidatePairMedianMS":median(b),
                     "pairedChangePercent":change,"referenceEndpointDriftPercent":abs(a[1]-a[0])/median(a)*100])
    }
    comparisons.append(["candidate":candidate,"pairedChangeMedianPercent":median(changes),"referenceMedianMS":median(baseline),"candidateMedianMS":median(trial),"cycles":rows])
}
let report:[String:Any] = ["device":device.name,"samples":count,"batchCount":batchCount,"timingDefinition":"full command span divided by batchCount; each iteration redoes all its passes and counter clear","groups":groups,"eligible":actualEligible,"fallback":actualFallback,
    "scope":"Frozen FP32 moment consumption on macOS. split includes counter clear, atomic classification, index construction, indirect args and both consumption dispatches. Excludes eligibility calculation and moment generation/spatial interpolation, SceneKit, iOS present, thermal acceptance.",
    "inputBytes":input.count,"momentBytes":momentData.count,"splitTemporaryBytes":8+24+count*8,"outputBytes":count*64,
    "validation":["partitionExact":true,"fallbackBitIdentical":fallbackExact,"mixedSplitMaxAbs":maxError,"numericalTolerance":2e-4],
    "comparisons":comparisons]
let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
try data.write(to:out.appendingPathComponent("result.json"))
print("samples=\(count) eligible=\(actualEligible) groups=\(groups) split/mixed error=\(maxError) output=\(out.path)")
