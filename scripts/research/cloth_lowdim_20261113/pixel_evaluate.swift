import Foundation
import Metal

func failure(_ m:String)->NSError { NSError(domain:"ClothPixel",code:1,userInfo:[NSLocalizedDescriptionKey:m]) }
func median(_ values:[Double])->Double { let s=values.sorted();return (s[(s.count-1)/2]+s[s.count/2])/2 }
guard (6...7).contains(CommandLine.arguments.count) else { throw failure("pixel_evaluate kernels.metal samples.bin balls.bin moments4.bin output-directory [batch-count]") }
let args=CommandLine.arguments
let batchCount=args.count==7 ? (Int(args[6]) ?? 0) : 8
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
guard momentData.count==count*10*16 else { throw failure("Expected 8 group + MV/M0 float4 moments per receiver") }
for data in [input,ballData,momentData] {
    guard data.withUnsafeBytes({$0.bindMemory(to:Float.self).allSatisfy({$0.isFinite})}) else { throw failure("Nonfinite input") }
}
let flags=momentData.withUnsafeBytes { raw in (0..<count).map { raw.bindMemory(to:Float.self)[$0*40+3] } }
guard flags.allSatisfy({$0==0 || $0==1}) else { throw failure("Invalid eligibility") }
guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else { throw failure("Metal unavailable") }
let opts=MTLCompileOptions();opts.fastMathEnabled=false
let lib=try device.makeLibrary(source:source,options:opts)
let names=["reference":"evaluateReference","grouped2":"evaluateGrouped2","grouped4":"evaluateGrouped4","grouped8":"evaluateGrouped8","frozen4":"evaluateCandidate"]
let modes=["reference","grouped2","grouped4","grouped8","frozen4"]
var psos=[String:MTLComputePipelineState]()
for mode in modes {
    guard let f=lib.makeFunction(name:names[mode]!) else { throw failure("Missing kernel") }
    let p=try device.makeComputePipelineState(function:f)
    guard p.maxTotalThreadsPerThreadgroup>=128 else { throw failure("Unsupported threadgroup capacity") }
    psos[mode]=p
}
func buffer(_ d:Data)throws->MTLBuffer {
    guard let b=d.withUnsafeBytes({device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)}) else { throw failure("Input allocation") };return b
}
let samples=try buffer(input),balls=try buffer(ballData),moments=try buffer(momentData)
guard let result=device.makeBuffer(length:count*64,options:.storageModeShared) else { throw failure("Output allocation") }
var sampleCount=UInt32(count),groupCount:UInt32=8
func run(_ mode:String)throws->Double {
    guard let c=queue.makeCommandBuffer() else { throw failure("Command buffer") };c.label="ClothPixel."+mode
    for _ in 0..<batchCount {
        guard let e=c.makeComputeCommandEncoder() else { throw failure("Encoder") }
        e.setBuffer(samples,offset:0,index:0);e.setBuffer(balls,offset:0,index:1);e.setBuffer(result,offset:0,index:2)
        e.setBytes(&sampleCount,length:4,index:3);e.setBuffer(moments,offset:0,index:4);e.setBytes(&groupCount,length:4,index:5)
        e.setComputePipelineState(psos[mode]!)
        e.dispatchThreadgroups(MTLSize(width:(count+127)/128,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:128,height:1,depth:1));e.endEncoding()
    }
    c.commit();c.waitUntilCompleted()
    guard c.status == .completed else { throw c.error ?? failure("GPU execution") }
    return (c.gpuEndTime-c.gpuStartTime)*1000/Double(batchCount)
}
var values=[String:[Float]]()
for mode in modes {
    _=try run(mode)
    values[mode]=Array(UnsafeBufferPointer(start:result.contents().bindMemory(to:Float.self,capacity:count*16),count:count*16))
    guard values[mode]!.allSatisfy({$0.isFinite}) else { throw failure("Nonfinite output") }
    try Data(bytes:result.contents(),count:count*64).write(to:out.appendingPathComponent(mode+".bin"))
}
var validation=[[String:Any]]()
for mode in modes.dropFirst() {
    let reference=values["reference"]!,candidate=values[mode]!
    var fallbackExact=true,eligible=0
    var diffuseError:Float=0,specularError:Float=0
    for i in 0..<count {
        let flag=mode=="frozen4" ? flags[i] : candidate[i*16+11]
        guard flag==flags[i] else { throw failure("Eligibility mismatch \(mode) at \(i)") }
        if flag==1 { eligible+=1 }
        for j in 0..<16 where j != 11 {
            let delta=abs(candidate[i*16+j]-reference[i*16+j])
            if j<11 && j != 3 && j != 7 {diffuseError=max(diffuseError,delta)}
            if j>=12 {specularError=max(specularError,delta)}
            if flag==0 && candidate[i*16+j].bitPattern != reference[i*16+j].bitPattern { fallbackExact=false }
        }
    }
    guard fallbackExact,diffuseError<=2e-4 else { throw failure("Semantic mismatch \(mode): diffuse=\(diffuseError), fallback=\(fallbackExact)") }
    validation.append(["mode":mode,"eligible":eligible,"fallbackBitIdentical":fallbackExact,"diffuseMaxAbs":diffuseError,"specularReferenceMaxAbs":specularError])
}
for _ in 0..<3 { for mode in modes {_=try run(mode)} }
var comparisons=[[String:Any]]()
for candidate in modes.dropFirst() {
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
let report:[String:Any] = ["device":device.name,"samples":count,"batchCount":batchCount,"eligible":flags.filter({$0==1}).count,
    "scope":"macOS compute using supplied actual pixel or synthetic inputs. Grouped includes original transport plus local moments and BRDF. Frozen4 consumes precomputed FP32 per-receiver moments, excludes all generation/update/spatial lookup costs. Neither includes SceneKit texture/raster/material/present or iOS thermal acceptance.",
    "timingDefinition":"full command span divided by batchCount; every iteration re-encodes its complete kernel",
    "inputBytes":input.count,"frozenMomentBytes":momentData.count,"outputBytes":count*64,"validation":validation,"numericalTolerance":2e-4,"comparisons":comparisons]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("result.json"))
print("samples=\(count) eligible=\(flags.filter({$0==1}).count) output=\(out.path)")
