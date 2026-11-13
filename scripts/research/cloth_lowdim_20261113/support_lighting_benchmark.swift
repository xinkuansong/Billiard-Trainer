import Foundation
import Metal
import CryptoKit

func failure(_ message: String) -> NSError { NSError(domain: "SupportLighting", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
func median(_ values: [Double]) -> Double { let s=values.sorted();return (s[(s.count-1)/2]+s[s.count/2])/2 }
func sha(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
func writeJSON(_ object: [String: Any], _ url: URL) throws {
    try JSONSerialization.data(withJSONObject:object,options:[.prettyPrinted,.sortedKeys]).write(to:url)
}
guard (6...7).contains(CommandLine.arguments.count) else {
    throw failure("support_lighting_benchmark kernel.metal samples.bin balls.bin new-output batchCount [expected-reference.bin]")
}
let args=CommandLine.arguments
let batchCount=Int(args[5]) ?? 0
guard (1...32).contains(batchCount) else {throw failure("Invalid batch count")}
let original=try String(contentsOfFile:args[1],encoding:.utf8)
let input=try Data(contentsOf:URL(fileURLWithPath:args[2]))
let ballData=try Data(contentsOf:URL(fileURLWithPath:args[3]))
let out=URL(fileURLWithPath:args[4],isDirectory:true)
guard !FileManager.default.fileExists(atPath:out.path),input.count>0,input.count%48==0,ballData.count==256 else {throw failure("Invalid input/output")}
try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
for data in [input,ballData] {
    guard data.withUnsafeBytes({$0.bindMemory(to:Float.self).allSatisfy({$0.isFinite})}) else {throw failure("Nonfinite inputs")}
}
let wrappers="""

// Only actual corrected diffuse irradiance and specular are observable here.
// The original diagnostic entry points remain solely for independent validation.
struct LightingResult { float4 corrected; float4 specular; };
kernel void evaluateLightingReference(device const Input *inputs [[buffer(0)]],
    constant float4 *balls [[buffer(1)]],device LightingResult *output [[buffer(2)]],
    constant uint &count [[buffer(3)]],uint index [[thread_position_in_grid]]) {
    if(index<count) { Result value=referenceAt(inputs[index],balls);
        output[index]={float4(value.corrected.xyz,0.0),float4(value.specular.xyz,0.0)}; }
}
kernel void evaluateLightingHeight(device const Input *inputs [[buffer(0)]],
    constant float4 *balls [[buffer(1)]],device LightingResult *output [[buffer(2)]],
    constant uint &count [[buffer(3)]],uint index [[thread_position_in_grid]]) {
    if(index<count) { Result value=heightSupportAt(inputs[index],balls);
        output[index]={float4(value.corrected.xyz,0.0),float4(value.specular.xyz,0.0)}; }
}
"""
let source=original+wrappers
try source.write(to:out.appendingPathComponent("compiled.metal"),atomically:true,encoding:.utf8)
guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else {throw failure("No Metal")}
let options=MTLCompileOptions();options.fastMathEnabled=false
let library=try device.makeLibrary(source:source,options:options)
let names=["reference-diagnostic":"evaluateReference","height-diagnostic":"evaluateHeightSupport",
           "reference-lighting":"evaluateLightingReference","height-lighting":"evaluateLightingHeight"]
let validationModes=["reference-diagnostic","height-diagnostic","reference-lighting","height-lighting"]
var pipelines=[String:MTLComputePipelineState]()
for mode in validationModes {
    guard let function=library.makeFunction(name:names[mode]!) else {throw failure("Missing kernel")}
    let pipeline=try device.makeComputePipelineState(function:function)
    guard pipeline.maxTotalThreadsPerThreadgroup>=128 else {throw failure("Insufficient threadgroup size")}
    pipelines[mode]=pipeline
}
func buffer(_ data:Data)throws->MTLBuffer {
    guard let result=data.withUnsafeBytes({device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)}) else {throw failure("Allocation")};return result
}
let samples=try buffer(input),balls=try buffer(ballData),count=input.count/48
guard let output=device.makeBuffer(length:count*64,options:.storageModeShared) else {throw failure("Output allocation")}
var sampleCount=UInt32(count)
func run(_ mode:String)throws->Double {
    guard let command=queue.makeCommandBuffer() else {throw failure("Command")}
    for _ in 0..<batchCount {
        guard let encoder=command.makeComputeCommandEncoder() else {throw failure("Encoder")}
        encoder.setComputePipelineState(pipelines[mode]!)
        encoder.setBuffer(samples,offset:0,index:0);encoder.setBuffer(balls,offset:0,index:1);encoder.setBuffer(output,offset:0,index:2)
        encoder.setBytes(&sampleCount,length:4,index:3)
        encoder.dispatchThreadgroups(MTLSize(width:(count+127)/128,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:128,height:1,depth:1));encoder.endEncoding()
    }
    command.commit();command.waitUntilCompleted()
    guard command.status == .completed else {throw command.error ?? failure("GPU execution")}
    let span=(command.gpuEndTime-command.gpuStartTime)*1000
    guard span.isFinite,span>0,command.gpuStartTime>0 else {throw failure("Invalid GPU timestamp")}
    return span
}
var values=[String:[Float]]()
for mode in validationModes {
    _=try run(mode)
    let width=mode.hasSuffix("diagnostic") ? 16:8
    let data=Data(bytes:output.contents(),count:count*width*4)
    try data.write(to:out.appendingPathComponent(mode+".bin"))
    values[mode]=data.withUnsafeBytes{Array($0.bindMemory(to:Float.self))}
    guard values[mode]!.allSatisfy({$0.isFinite}) else {throw failure("Nonfinite output")}
}
let ref=values["reference-diagnostic"]!,height=values["height-diagnostic"]!
let lightRef=values["reference-lighting"]!,lightHeight=values["height-lighting"]!
let radiometric=[0,1,2,4,5,6,8,9,10,12,13,14]
var changedRadiometric=0,changedPure=0,changedRefContract=0,changedCandidateContract=0
var nearExact=true,maskSubset=true,changedMasks=0
for i in 0..<count {
    for channel in radiometric {if ref[i*16+channel].bitPattern != height[i*16+channel].bitPattern {changedRadiometric+=1}}
    nearExact = nearExact && ref[i*16+3].bitPattern==height[i*16+3].bitPattern
    let a=UInt32(ref[i*16+7]),b=UInt32(height[i*16+7])
    maskSubset = maskSubset && (b & ~a)==0
    if a != b {changedMasks+=1}
    for channel in [0,1,2,4,5,6] {
        let old=channel+8
        if lightRef[i*8+channel].bitPattern != ref[i*16+old].bitPattern {changedRefContract+=1}
        if lightHeight[i*8+channel].bitPattern != height[i*16+old].bitPattern {changedCandidateContract+=1}
        if lightRef[i*8+channel].bitPattern != lightHeight[i*8+channel].bitPattern {changedPure+=1}
    }
    guard lightRef[i*8+3]==0,lightRef[i*8+7]==0,lightHeight[i*8+3]==0,lightHeight[i*8+7]==0 else {throw failure("Invalid lighting padding")}
}
var externalExact:Bool?=nil
if args.count==7 {
    let external=try Data(contentsOf:URL(fileURLWithPath:args[6]))
    let actual=try Data(contentsOf:out.appendingPathComponent("reference-diagnostic.bin"))
    externalExact=external==actual
}
var validation:[String:Any]=["diagnosticRadiometricChangedChannels":changedRadiometric,"nearBitIdentical":nearExact,"maskSubset":maskSubset,
    "changedMasks":changedMasks,"pureLightingChangedChannels":changedPure,"referenceContractChangedChannels":changedRefContract,
    "candidateContractChangedChannels":changedCandidateContract]
validation["externalReferenceBitIdentical"]=externalExact.map { $0 as Any } ?? NSNull()
try writeJSON(validation,out.appendingPathComponent("validation.json"))
guard changedRadiometric==0,nearExact,maskSubset,changedPure==0,changedRefContract==0,changedCandidateContract==0,externalExact != false else {
    throw failure("Output contract or radiometric mismatch; timings withheld")
}
for _ in 0..<4 {for mode in ["reference-lighting","height-lighting"] {_=try run(mode)}}
var rows=[[String:Any]](),changes=[Double](),allA=[Double](),allB=[Double]()
for cycle in 0..<9 {
    let order=cycle%2==0 ? ["reference-lighting","height-lighting","height-lighting","reference-lighting"] : ["height-lighting","reference-lighting","reference-lighting","height-lighting"]
    var raw=[Double](),a=[Double](),b=[Double]()
    for mode in order {
        let commandSpan=try run(mode),span=commandSpan/Double(batchCount);raw.append(commandSpan)
        if mode=="reference-lighting" {a.append(span);allA.append(span)} else {b.append(span);allB.append(span)}
    }
    let change=(median(b)/median(a)-1)*100;changes.append(change)
    rows.append(["cycle":cycle,"order":order,"rawCommandSpanMS":raw,"spanPerIterationMS":raw.map{$0/Double(batchCount)},
                 "pairedChangePercent":change,"referenceEndpointDriftPercent":abs(a[0]-a[1])/median(a)*100])
}
let report:[String:Any]=["device":device.name,"samples":count,"batchCount":batchCount,
    "scope":"Only corrected diffuse and specular math compute outputs; allows dead diagnostic elimination. Not SceneKit material/raster/present, complete production performance or phone thermal acceptance.",
    "diagnosticContract":"16 Float32: E0.xyz/near, sampledE.xyz/mask, corrected.xyz/0, specular.xyz/0. Validation only, not timed ABBA.",
    "lightingContract":"8 Float32: corrected.xyz/0, specular.xyz/0. Only this contract is timed; no near/mask/E0/sampledE side effects.",
    "sourceSHA256":sha(Data(original.utf8)),"compiledSHA256":sha(Data(source.utf8)),"inputSHA256":sha(input),"ballsSHA256":sha(ballData),
    "lightingOutputBytes":count*32,"diagnosticOutputBytes":count*64,"validation":validation,
    "pairedChangeMedianPercent":median(changes),"referenceMedianMS":median(allA),"candidateMedianMS":median(allB),"cycles":rows]
try writeJSON(report,out.appendingPathComponent("result.json"))
print("samples=\(count) lightingChange=\(median(changes))% six-channel contracts bit-identical")
