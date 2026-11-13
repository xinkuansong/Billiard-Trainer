import Foundation
import Metal

func failure(_ m:String)->NSError { NSError(domain:"ClothInline",code:1,userInfo:[NSLocalizedDescriptionKey:m]) }
func median(_ values:[Double])->Double { let s=values.sorted();return (s[(s.count-1)/2]+s[s.count/2])/2 }
guard (5...6).contains(CommandLine.arguments.count) else { throw failure("inline_evaluate kernels.metal samples.bin balls.bin output-directory [batch-count]") }
let args=CommandLine.arguments
let batchCount=args.count==6 ? (Int(args[5]) ?? 0) : 8
guard (1...32).contains(batchCount) else { throw failure("Invalid batch count") }
let source=try String(contentsOfFile:args[1],encoding:.utf8)
let input=try Data(contentsOf:URL(fileURLWithPath:args[2]))
let ballData=try Data(contentsOf:URL(fileURLWithPath:args[3]))
let out=URL(fileURLWithPath:args[4],isDirectory:true)
guard !FileManager.default.fileExists(atPath:out.path) else { throw failure("Output exists") }
try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
guard input.count>0,input.count%48==0,ballData.count==256 else { throw failure("Invalid records") }
let count=input.count/48
for data in [input,ballData] {
    guard data.withUnsafeBytes({$0.bindMemory(to:Float.self).allSatisfy({$0.isFinite})}) else { throw failure("Nonfinite input") }
}
guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else { throw failure("Metal unavailable") }
let opts=MTLCompileOptions();opts.fastMathEnabled=false
let lib=try device.makeLibrary(source:source,options:opts)
var psos=[String:MTLComputePipelineState]()
for name in ["evaluateReference","evaluateInline"] {
    guard let f=lib.makeFunction(name:name) else { throw failure("Missing kernel \(name)") }
    let p=try device.makeComputePipelineState(function:f)
    guard p.maxTotalThreadsPerThreadgroup>=128 else { throw failure("Unsupported threadgroup capacity") }
    psos[name]=p
}
func buffer(_ d:Data)throws->MTLBuffer {
    guard let b=d.withUnsafeBytes({device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)}) else { throw failure("Input allocation") };return b
}
let samples=try buffer(input),balls=try buffer(ballData)
guard let result=device.makeBuffer(length:count*64,options:.storageModeShared) else { throw failure("Output allocation") }
var sampleCount=UInt32(count)
func run(_ mode:String)throws->Double {
    guard let c=queue.makeCommandBuffer() else { throw failure("Command buffer") };c.label="ClothInline."+mode
    for _ in 0..<batchCount {
        guard let e=c.makeComputeCommandEncoder() else { throw failure("Encoder") }
        e.setBuffer(samples,offset:0,index:0);e.setBuffer(balls,offset:0,index:1);e.setBuffer(result,offset:0,index:2)
        e.setBytes(&sampleCount,length:4,index:3)
        e.setComputePipelineState(psos[mode=="reference" ? "evaluateReference":"evaluateInline"]!)
        e.dispatchThreadgroups(MTLSize(width:(count+127)/128,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:128,height:1,depth:1));e.endEncoding()
    }
    c.commit();c.waitUntilCompleted()
    guard c.status == .completed else { throw c.error ?? failure("GPU execution") }
    return (c.gpuEndTime-c.gpuStartTime)*1000/Double(batchCount)
}
func floats()->[Float] { Array(UnsafeBufferPointer(start:result.contents().bindMemory(to:Float.self,capacity:count*16),count:count*16)) }
var values=[String:[Float]]()
for mode in ["reference","inline"] {
    _=try run(mode);values[mode]=floats()
    guard values[mode]!.allSatisfy({$0.isFinite}) else { throw failure("Nonfinite output") }
    try Data(bytes:result.contents(),count:count*64).write(to:out.appendingPathComponent(mode+".bin"))
}
let reference=values["reference"]!,candidate=values["inline"]!
var fallbackExact=true,eligible=0
var diffuseError:Float=0,specularError:Float=0
for i in 0..<count {
    let flag=candidate[i*16+11]
    guard flag==0 || flag==1 else { throw failure("Invalid enabled flag") }
    if flag==1 { eligible+=1 }
    for j in 0..<16 where j != 11 {
        let delta=abs(candidate[i*16+j]-reference[i*16+j])
        if j<11 {diffuseError=max(diffuseError,delta)} else {specularError=max(specularError,delta)}
        if flag==0 && candidate[i*16+j].bitPattern != reference[i*16+j].bitPattern { fallbackExact=false }
    }
}
// Candidate specular is intentionally approximate; do not require it to equal reference.
guard fallbackExact,diffuseError<=2e-4 else { throw failure("Semantic mismatch diffuse=\(diffuseError) fallbackExact=\(fallbackExact)") }
for _ in 0..<3 { for mode in ["reference","inline"] {_=try run(mode)} }
var rows=[[String:Any]](),changes=[Double](),baseline=[Double](),trial=[Double]()
for cycle in 0..<9 {
    let order = cycle%2==0 ? ["reference","inline","inline","reference"] : ["inline","reference","reference","inline"]
    var times=[Double](),a=[Double](),b=[Double]()
    for mode in order {
        let t=try run(mode);times.append(t)
        if mode=="reference" {a.append(t);baseline.append(t)} else {b.append(t);trial.append(t)}
    }
    let change=(median(b)/median(a)-1)*100;changes.append(change)
    rows.append(["cycle":cycle,"order":order,"commandSpanMS":times,"referencePairMedianMS":median(a),"candidatePairMedianMS":median(b),
                 "pairedChangePercent":change,"referenceEndpointDriftPercent":abs(a[1]-a[0])/median(a)*100])
}
let report:[String:Any] = ["device":device.name,"samples":count,"batchCount":batchCount,"eligible":eligible,
    "scope":"macOS mathematical compute invocation: original transport/visibility plus local 16 moment accumulation and 16 BRDFs; no moment cache/field. Excludes SceneKit texture sampling/material composition/raster/present/iOS/thermal acceptance.",
    "timingDefinition":"full command span divided by batchCount; each iteration recomputes transport, eligibility, moments and BRDF from inputs",
    "inputBytes":input.count,"momentBufferBytes":0,"outputBytes":count*64,
    "validation":["fallbackBitIdentical":fallbackExact,"diffuseMaxAbs":diffuseError,"specularReferenceMaxAbs":specularError,"numericalTolerance":2e-4],
    "pairedChangeMedianPercent":median(changes),"referenceMedianMS":median(baseline),"candidateMedianMS":median(trial),"cycles":rows]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("result.json"))
print("samples=\(count) eligible=\(eligible) diffuseError=\(diffuseError) output=\(out.path)")
