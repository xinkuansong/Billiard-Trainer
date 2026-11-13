import Foundation
import Metal

func fail(_ message:String)->NSError { NSError(domain:"SupportGridResearch",code:1,userInfo:[NSLocalizedDescriptionKey:message]) }
guard (8...9).contains(CommandLine.arguments.count) else { throw fail("support_grid_evaluate support.metal inputs.bin balls.bin out width height repeats [check]") }
let args=CommandLine.arguments, checkOnly=CommandLine.arguments.last=="check"
let out=URL(fileURLWithPath:args[4],isDirectory:true)
guard !FileManager.default.fileExists(atPath:out.path) else { throw fail("Refusing overwrite") }
try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
guard let width=Int(args[5]),let height=Int(args[6]),let repeats=Int(args[7]),width>0,height>0,repeats>0,
      width.nonzeroBitCount==1,height.nonzeroBitCount==1 else { throw fail("Power-of-two grid required") }
let input=try Data(contentsOf:URL(fileURLWithPath:args[2])),ballData=try Data(contentsOf:URL(fileURLWithPath:args[3]))
guard !input.isEmpty,input.count%48==0,ballData.count==256 else { throw fail("Invalid input") }
for d in [input,ballData] { guard d.withUnsafeBytes({$0.bindMemory(to:Float.self).allSatisfy{$0.isFinite}}) else { throw fail("Nonfinite input") } }
let baseCount=input.count/48,count=baseCount*repeats
guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else { throw fail("Metal unavailable") }
let options=MTLCompileOptions();options.fastMathEnabled=false
let library=try device.makeLibrary(source:String(contentsOfFile:args[1],encoding:.utf8),options:options)
func pipeline(_ name:String)throws->MTLComputePipelineState {
    guard let f=library.makeFunction(name:name) else { throw fail("Missing \(name)") }
    return try device.makeComputePipelineState(function:f)
}
let reference=try pipeline("evaluateReference"),consumer=try pipeline("evaluateSupport"),generator=try pipeline("generateSupport")
let reader=try pipeline("readSupport"),lookup=try pipeline("readSupportSamples")
guard let samples=device.makeBuffer(length:input.count*repeats,options:.storageModeShared),
      let balls=ballData.withUnsafeBytes({device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)}),
      let results=device.makeBuffer(length:count*64,options:.storageModeShared) else { throw fail("Buffer allocation") }
input.withUnsafeBytes { raw in for i in 0..<repeats { samples.contents().advanced(by:i*raw.count).copyMemory(from:raw.baseAddress!,byteCount:raw.count) } }
let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.r32Uint,width:width,height:height,mipmapped:false)
descriptor.storageMode = .private;descriptor.usage=[.shaderRead,.shaderWrite]
guard let grid=device.makeTexture(descriptor:descriptor) else { throw fail("Grid allocation") }
func generate(_ c:MTLCommandBuffer)throws {
    guard let e=c.makeComputeCommandEncoder() else { throw fail("Generation encoder") }
    e.setComputePipelineState(generator);e.setBuffer(balls,offset:0,index:1);e.setTexture(grid,index:0)
    e.dispatchThreads(MTLSize(width:width,height:height,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1));e.endEncoding()
}
func consume(_ c:MTLCommandBuffer,_ state:MTLComputePipelineState)throws {
    guard let e=c.makeComputeCommandEncoder() else { throw fail("Consumer encoder") }
    var n=UInt32(count);e.setComputePipelineState(state)
    e.setBuffer(samples,offset:0,index:0);e.setBuffer(balls,offset:0,index:1);e.setBuffer(results,offset:0,index:2);e.setBytes(&n,length:4,index:3)
    if state === consumer { e.setTexture(grid,index:0) }
    e.dispatchThreads(MTLSize(width:count,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:128,height:1,depth:1));e.endEncoding()
}
func run(_ mode:String,_ batch:Int=1)throws->Double {
    guard let c=queue.makeCommandBuffer() else { throw fail("Command buffer") }
    c.label=mode
    for _ in 0..<batch {
        if mode=="total" || mode=="generation" { try generate(c) }
        if mode != "generation" { try consume(c,mode=="reference" ? reference : consumer) }
    }
    c.commit();c.waitUntilCompleted()
    guard c.status == .completed else { throw c.error ?? fail("GPU command failed") }
    return (c.gpuEndTime-c.gpuStartTime)*1000
}
func save(_ name:String)throws {
    let f=results.contents().bindMemory(to:Float.self,capacity:count*16)
    for i in 0..<count*16 {
        guard f[i].isFinite,f[i].bitPattern==f[i%(baseCount*16)].bitPattern else { throw fail("Nonfinite/repeat mismatch \(i)") }
    }
    try Data(bytes:results.contents(),count:baseCount*64).write(to:out.appendingPathComponent(name+".bin"))
}
for mode in ["reference","total"] { _ = try run(mode);try save(mode) }
guard let gridValues=device.makeBuffer(length:width*height*4,options:.storageModeShared),
      let lookupValues=device.makeBuffer(length:baseCount*8,options:.storageModeShared),let c=queue.makeCommandBuffer(),let e=c.makeComputeCommandEncoder() else { throw fail("Readback allocation") }
e.setComputePipelineState(reader);e.setTexture(grid,index:0);e.setBuffer(gridValues,offset:0,index:0)
e.dispatchThreads(MTLSize(width:width*height,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:128,height:1,depth:1));e.endEncoding()
guard let l=c.makeComputeCommandEncoder() else { throw fail("Readback lookup encoder") }
var base=UInt32(baseCount)
l.setComputePipelineState(lookup);l.setTexture(grid,index:0);l.setBuffer(samples,offset:0,index:0);l.setBuffer(lookupValues,offset:0,index:2);l.setBytes(&base,length:4,index:3)
l.dispatchThreads(MTLSize(width:baseCount,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:128,height:1,depth:1));l.endEncoding();c.commit();c.waitUntilCompleted()
guard c.status == .completed else { throw c.error ?? fail("Readback failed") }
try Data(bytes:gridValues.contents(),count:gridValues.length).write(to:out.appendingPathComponent("grid.bin"))
try Data(bytes:lookupValues.contents(),count:lookupValues.length).write(to:out.appendingPathComponent("lookup.bin"))
var metadata:[String:Any]=["device":device.name,"sampleCount":count,"baseSampleCount":baseCount,"repeats":repeats,
    "width":width,"height":height,"format":"R32Uint","pixelDataBytes":width*height*4,"allocatedBytes":grid.allocatedSize,
    "representation":"Low16 conservative candidate bits, high16 active bits. Receiver recomputes original exact near/mask; below-bed mask all-active preserved.",
    "lookupBinary":"UInt32 [N,2]: packed cell bits and inside flag; result uses unchanged reference layout",
    "scope":"Extracted production core; includes grid generation and consumption, no SceneKit/frame/iPhone/thermal proof; arbitrary receiver Y retained",
    "synchronization":"Every total iteration generates then consumes grid in sequential tracked-resource encoders of one command buffer. Readback only afterward.",
    "fastMathEnabled":false,"checkOnly":checkOnly]
func median(_ values:[Double])->Double { let s=values.sorted();return (s[(s.count-1)/2]+s[s.count/2])/2 }
if !checkOnly {
    let batch=8
    for _ in 0..<4 { _ = try run("reference",batch);_ = try run("total",batch) }
    var rows=[[String:Any]](),at=[Double](),bt=[Double](),changes=[Double]()
    for cycle in 0..<9 {
        let order=cycle%2==0 ? ["reference","total","total","reference"] : ["total","reference","reference","total"]
        var raw=[Double](),ca=[Double](),cb=[Double]()
        for mode in order {
            let value=try run(mode,batch);raw.append(value)
            if mode=="reference" { at.append(value/Double(batch));ca.append(value/Double(batch)) }
            else { bt.append(value/Double(batch));cb.append(value/Double(batch)) }
        }
        let change=((cb[0]+cb[1])/(ca[0]+ca[1])-1)*100;changes.append(change)
        rows.append(["cycle":cycle,"order":order,"commandSpansMS":raw,"referencePairMS":(ca[0]+ca[1])/2,"totalPairMS":(cb[0]+cb[1])/2,"pairedChangePercent":change])
    }
    metadata["batchCount"]=batch;metadata["cycles"]=rows;metadata["referenceMedianMS"]=median(at);metadata["totalMedianMS"]=median(bt)
    metadata["pairedChangeMedianPercent"]=median(changes)
    metadata["referenceFirst3MedianMS"]=median(Array(at.prefix(6)));metadata["referenceLast3MedianMS"]=median(Array(at.suffix(6)))
    var gen=[Double](),con=[Double]()
    for _ in 0..<7 { gen.append(try run("generation",batch)/Double(batch));con.append(try run("consumption",batch)/Double(batch)) }
    metadata["generationSpansMSPerIteration"]=gen;metadata["consumptionSpansMSPerIteration"]=con
}
let json=try JSONSerialization.data(withJSONObject:metadata,options:[.prettyPrinted,.sortedKeys])
try json.write(to:out.appendingPathComponent("metadata.json"));FileHandle.standardOutput.write(json)
