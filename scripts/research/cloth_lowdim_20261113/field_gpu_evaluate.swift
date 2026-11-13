import Foundation
import Metal

func fail(_ message: String) -> NSError {
    NSError(domain: "ClothFieldResearch", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}
guard (8...9).contains(CommandLine.arguments.count) else {
    throw fail("Usage: field_gpu_evaluate field.metal samples.bin balls.bin output-directory width height repeats [16|32]")
}
let args = CommandLine.arguments
let bits = args.count==9 ? Int(args[8])! : 16
guard bits==16 || bits==32 else { throw fail("Invalid texture precision") }
let out = URL(fileURLWithPath: args[4], isDirectory: true)
guard !FileManager.default.fileExists(atPath: out.path) else { throw fail("Refusing output overwrite") }
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
guard let width=Int(args[5]), let height=Int(args[6]), let repeats=Int(args[7]),
      width>1, height>1, repeats>0 else { throw fail("Invalid grid/repeats") }
let inputData = try Data(contentsOf: URL(fileURLWithPath: args[2]))
let ballData = try Data(contentsOf: URL(fileURLWithPath: args[3]))
guard !inputData.isEmpty, inputData.count % 48 == 0, ballData.count == 256 else { throw fail("Invalid inputs") }
let baseCount = inputData.count/48, count = baseCount*repeats
guard count<=Int(UInt32.max) else { throw fail("Too many samples") }
for data in [inputData,ballData] {
    guard data.withUnsafeBytes({ $0.bindMemory(to: Float.self).allSatisfy { $0.isFinite } }) else { throw fail("Nonfinite input") }
}
guard let device=MTLCreateSystemDefaultDevice(), let queue=device.makeCommandQueue() else { throw fail("No Metal") }
let options=MTLCompileOptions();options.fastMathEnabled=false
let library=try device.makeLibrary(source: String(contentsOfFile: args[1], encoding: .utf8), options: options)
func pipeline(_ name:String) throws -> MTLComputePipelineState {
    guard let function=library.makeFunction(name:name) else { throw fail("Missing function \(name)") }
    return try device.makeComputePipelineState(function:function)
}
let reference=try pipeline("evaluateReference"), generation=try pipeline(bits==16 ? "generateFieldHalf" : "generateField")
let consumption=try pipeline("evaluateField"), point=try pipeline("evaluatePoint")
let read=try pipeline("readField"), sampleRead=try pipeline("readSampledField")
guard let samples=device.makeBuffer(length: inputData.count*repeats, options:.storageModeShared),
      let balls=ballData.withUnsafeBytes({ device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared) }),
      let results=device.makeBuffer(length:count*64,options:.storageModeShared) else { throw fail("Buffer allocation") }
inputData.withUnsafeBytes { raw in
    for i in 0..<repeats { samples.contents().advanced(by:i*inputData.count).copyMemory(from:raw.baseAddress!,byteCount:raw.count) }
}
let desc=MTLTextureDescriptor()
desc.textureType = .type2DArray;desc.pixelFormat = bits==16 ? .rgba16Float : .rgba32Float
desc.width=width;desc.height=height;desc.arrayLength=18
desc.storageMode = .private;desc.usage=[.shaderRead,.shaderWrite]
guard let field=device.makeTexture(descriptor:desc) else { throw fail("Texture allocation") }

func encodeGeneration(_ command:MTLCommandBuffer) throws {
    guard let encoder=command.makeComputeCommandEncoder() else { throw fail("Generation encoder") }
    encoder.label="GenerateRGBA16FMoments"
    encoder.setComputePipelineState(generation);encoder.setBuffer(balls,offset:0,index:1);encoder.setTexture(field,index:0)
    encoder.dispatchThreads(MTLSize(width:width,height:height,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1))
    encoder.endEncoding()
}
func encodeConsumers(_ command:MTLCommandBuffer,_ state:MTLComputePipelineState) throws {
    guard let encoder=command.makeComputeCommandEncoder() else { throw fail("Consumer encoder") }
    var n=UInt32(count)
    encoder.setComputePipelineState(state)
    encoder.setBuffer(samples,offset:0,index:0);encoder.setBuffer(balls,offset:0,index:1)
    encoder.setBuffer(results,offset:0,index:2);encoder.setBytes(&n,length:4,index:3)
    if state === consumption { encoder.setTexture(field,index:0) }
    encoder.dispatchThreads(MTLSize(width:count,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:128,height:1,depth:1))
    encoder.endEncoding()
}
func run(_ mode:String,_ batch:Int=1) throws -> Double {
    guard let command=queue.makeCommandBuffer() else { throw fail("Command buffer") }
    command.label=mode
    for _ in 0..<batch {
        if mode=="total" || mode=="generation" { try encodeGeneration(command) }
        if mode != "generation" {
            try encodeConsumers(command,mode=="reference" ? reference : mode=="point" ? point : consumption)
        }
    }
    command.commit();command.waitUntilCompleted()
    guard command.status == .completed else { throw command.error ?? fail("GPU command failed") }
    return (command.gpuEndTime-command.gpuStartTime)*1000
}
func save(_ name:String) throws {
    let values=results.contents().bindMemory(to:Float.self,capacity:count*16)
    for i in 0..<count*16 {
        guard values[i].isFinite else { throw fail("Nonfinite result \(name)/\(i)") }
        guard values[i].bitPattern==values[i%(baseCount*16)].bitPattern else { throw fail("Repeated sample mismatch") }
    }
    try Data(bytes:results.contents(),count:baseCount*64).write(to:out.appendingPathComponent(name+".bin"))
}
for mode in ["reference","point","total"] { _ = try run(mode);try save(mode) }

// Readback is a separate unmeasured command, strictly after generation+consumption.
guard let fieldValues=device.makeBuffer(length:width*height*18*16,options:.storageModeShared),
      let sampledValues=device.makeBuffer(length:baseCount*18*16,options:.storageModeShared),
      let readCommand=queue.makeCommandBuffer(), let readEncoder=readCommand.makeComputeCommandEncoder() else { throw fail("Readback allocation") }
readEncoder.setComputePipelineState(read);readEncoder.setTexture(field,index:0);readEncoder.setBuffer(fieldValues,offset:0,index:0)
readEncoder.dispatchThreads(MTLSize(width:width*height,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:128,height:1,depth:1))
readEncoder.endEncoding()
guard let sampleEncoder=readCommand.makeComputeCommandEncoder() else { throw fail("Sample read encoder") }
var baseN=UInt32(baseCount)
sampleEncoder.setComputePipelineState(sampleRead);sampleEncoder.setTexture(field,index:0)
sampleEncoder.setBuffer(samples,offset:0,index:0);sampleEncoder.setBuffer(sampledValues,offset:0,index:2);sampleEncoder.setBytes(&baseN,length:4,index:3)
sampleEncoder.dispatchThreads(MTLSize(width:baseCount,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:128,height:1,depth:1))
sampleEncoder.endEncoding();readCommand.commit();readCommand.waitUntilCompleted()
guard readCommand.status == .completed else { throw readCommand.error ?? fail("Readback command failed") }
// Only write the full field once per grid/case (repeat 1); sampled values remain tiny.
if repeats==1 { try Data(bytes:fieldValues.contents(),count:fieldValues.length).write(to:out.appendingPathComponent("field.bin")) }
try Data(bytes:sampledValues.contents(),count:sampledValues.length).write(to:out.appendingPathComponent("sampled-field.bin"))

let batchCount=8
for _ in 0..<4 { _ = try run("reference",batchCount);_ = try run("total",batchCount) }
var cycles=[[String:Any]](),aTimes=[Double](),bTimes=[Double](),pairedChanges=[Double]()
for cycle in 0..<9 {
    var times=[Double]()
    let order=cycle%2==0 ? ["reference","total","total","reference"] : ["total","reference","reference","total"]
    var ca=[Double](),cb=[Double]()
    for mode in order {
        let value=try run(mode,batchCount);times.append(value)
        if mode=="reference" { aTimes.append(value/Double(batchCount));ca.append(value/Double(batchCount)) }
        else { bTimes.append(value/Double(batchCount));cb.append(value/Double(batchCount)) }
    }
    let change=((cb[0]+cb[1])/(ca[0]+ca[1])-1)*100;pairedChanges.append(change)
    cycles.append(["cycle":cycle,"order":order,"gpuCommandSpanMS":times,"batchCount":batchCount,
                   "referencePairMSPerIteration":(ca[0]+ca[1])/2,"totalPairMSPerIteration":(cb[0]+cb[1])/2,"pairedChangePercent":change])
}
func median(_ a:[Double])->Double { let s=a.sorted();return (s[(s.count-1)/2]+s[s.count/2])/2 }
var generationTimes=[Double](),consumptionTimes=[Double]()
for _ in 0..<7 { generationTimes.append(try run("generation",batchCount)/Double(batchCount));consumptionTimes.append(try run("consumption",batchCount)/Double(batchCount)) }
let a=median(aTimes),b=median(bTimes)
let metadata:[String:Any]=[
    "device":device.name,"baseSampleCount":baseCount,"sampleCount":count,"repeats":repeats,
    "width":width,"height":height,"layers":18,"pixelFormat":"RGBA\(bits)Float","fieldPixelDataBytes":width*height*18*4*(bits/8),
    "fieldAllocatedBytes":field.allocatedSize,"fastMathEnabled":false,
    "fieldBinaryLayout":"Float32 little endian [height,width,18,4] with texel raw half values converted to Float32; only repeat 1 saves full field",
    "sampledFieldBinaryLayout":"Float32 [baseSampleCount,18,4] hardware bilinear sampling even for fallback (diagnostic)",
    "resultBinaryLayout":"Float32 [baseSampleCount,16], same core result; corrected.w (index 11)=1 explicitly marks candidate, reference/fallback index 11=0",
    "referenceMedianMS":a,"totalMedianMS":b,"changePercent":(b/a-1)*100,"pairedChangeMedianPercent":median(pairedChanges),"cycles":cycles,
    "batchCount":batchCount,"referenceFirst3MedianMS":median(Array(aTimes.prefix(6))),"referenceLast3MedianMS":median(Array(aTimes.suffix(6))),
    "generationMedianMS":median(generationTimes),"consumptionMedianMS":median(consumptionTimes),
    "generationCommandSpansMS":generationTimes,"consumptionCommandSpansMS":consumptionTimes,
    "synchronization":"Generation and consumption use sequential tracked-resource encoders in one command buffer; CPU wait only after entire command for offline completion",
    "scope":"9 alternating ABBA/BAAB cycles after 4 warmups per arm; each command repeats 8 complete iterations and timings normalized per iteration. Every total iteration regenerates full field then consumes. No SceneKit/present, UI, dynamics, texture material or iOS proof. Separate generation/consumption medians do not sum into total measurement.",
    "diagnosticReadbackBytesNotProduction":fieldValues.length+sampledValues.length]
let encoded=try JSONSerialization.data(withJSONObject:metadata,options:[.prettyPrinted,.sortedKeys])
try encoded.write(to:out.appendingPathComponent("metadata.json"));FileHandle.standardOutput.write(encoded)
