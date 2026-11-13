import Foundation
import Metal

// Standalone math kernel. It neither presents a frame nor claims iOS performance.
func failure(_ message: String) -> NSError {
    NSError(domain: "ClothReference", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}
guard (5...6).contains(CommandLine.arguments.count) else {
    throw failure("Usage: evaluate reference.metal samples.bin balls.bin results.bin [moments.bin]")
}
let args = CommandLine.arguments
let sourceURL = URL(fileURLWithPath: args[1])
let input = try Data(contentsOf: URL(fileURLWithPath: args[2]))
let ballData = try Data(contentsOf: URL(fileURLWithPath: args[3]))
let outputURL = URL(fileURLWithPath: args[4])
guard !input.isEmpty, input.count % 48 == 0, input.count / 48 <= Int(UInt32.max),
      ballData.count == 16 * 16 else { throw failure("Invalid binary record size") }
let count = input.count / 48
let inputs = input.withUnsafeBytes { raw in Array(raw.bindMemory(to: Float.self)) }
let ballFloats = ballData.withUnsafeBytes { raw in Array(raw.bindMemory(to: Float.self)) }
guard inputs.allSatisfy({ $0.isFinite }), ballFloats.allSatisfy({ $0.isFinite }) else {
    throw failure("Nonfinite input")
}
for i in 0..<count {
    let b = i * 12
    let n2 = inputs[b+4] * inputs[b+4] + inputs[b+5] * inputs[b+5] + inputs[b+6] * inputs[b+6]
    let v2 = inputs[b+8] * inputs[b+8] + inputs[b+9] * inputs[b+9] + inputs[b+10] * inputs[b+10]
    guard n2 > 0, v2 > 0, (0...1).contains(inputs[b+11]) else {
        throw failure("Invalid normal/view/roughness at sample \(i)")
    }
}
var momentData: Data?
var groupCount = 0
if args.count == 6 {
    let data = try Data(contentsOf: URL(fileURLWithPath: args[5]))
    guard data.count % (count*16) == 0 else { throw failure("Moments record count mismatch") }
    groupCount = data.count / (count*16) - 2
    guard (1...64).contains(groupCount) else { throw failure("Moments need 1...64 groups") }
    let values = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    guard values.allSatisfy({ $0.isFinite }) else { throw failure("Nonfinite moment") }
    for i in 0..<count {
        let flag = values[i*(groupCount+2)*4+3]
        guard flag == 0 || flag == 1 else { throw failure("Moment enabledFlag must be 0 or 1") }
    }
    momentData = data
}
guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
    throw failure("Metal unavailable")
}
let options = MTLCompileOptions()
options.fastMathEnabled = false
let library = try device.makeLibrary(source: String(contentsOf: sourceURL, encoding: .utf8), options: options)
func makePipeline(_ name: String) throws -> MTLComputePipelineState {
    guard let function = library.makeFunction(name: name) else { throw failure("Missing kernel \(name)") }
    return try device.makeComputePipelineState(function: function)
}
let reference = try makePipeline("evaluateReference")
let candidate = momentData == nil ? nil : try makePipeline("evaluateCandidate")
let samples = input.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }
let balls = ballData.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }
var momentBuffer: MTLBuffer?
if let data = momentData {
    momentBuffer = data.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }
    guard momentBuffer != nil else { throw failure("Moment allocation failed") }
}
guard let samples, let balls, let results = device.makeBuffer(length: count*64, options: .storageModeShared) else {
    throw failure("Metal allocation failed")
}
func dispatch(_ pipeline: MTLComputePipelineState, useMoments: Bool) throws -> Double {
    guard let command = queue.makeCommandBuffer(), let encoder = command.makeComputeCommandEncoder() else {
        throw failure("Encoder allocation failed")
    }
    command.label = useMoments ? "FrozenMomentsConsumption" : "ProductionRClothMath"
    var sampleCount = UInt32(count), groups = UInt32(groupCount)
    encoder.setComputePipelineState(pipeline)
    encoder.setBuffer(samples, offset: 0, index: 0)
    encoder.setBuffer(balls, offset: 0, index: 1)
    encoder.setBuffer(results, offset: 0, index: 2)
    encoder.setBytes(&sampleCount, length: 4, index: 3)
    if useMoments {
        encoder.setBuffer(momentBuffer, offset: 0, index: 4)
        encoder.setBytes(&groups, length: 4, index: 5)
    }
    let width = min(pipeline.maxTotalThreadsPerThreadgroup, 128)
    encoder.dispatchThreadgroups(MTLSize(width: (count+width-1)/width, height: 1, depth: 1),
                                 threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1))
    encoder.endEncoding()
    command.commit()
    // Offline readback only. This is deliberately not a production frame sync design.
    command.waitUntilCompleted()
    guard command.status == .completed else { throw command.error ?? failure("GPU execution failed") }
    return (command.gpuEndTime-command.gpuStartTime)*1000
}
let initialSpan = try dispatch(candidate ?? reference, useMoments: candidate != nil)
let values = results.contents().bindMemory(to: Float.self, capacity: count*16)
for i in 0..<(count*16) { guard values[i].isFinite else { throw failure("Nonfinite result at \(i)") } }
try Data(bytes: results.contents(), count: count*64).write(to: outputURL)
var metadata: [String: Any] = ["device": device.name, "sampleCount": count,
    "fastMathEnabled": false, "gpuCommandSpanMS": initialSpan,
    "scope": "offline math kernel; no rasterization, spatial texture interpolation, native PBR, UI or actual present; not iOS/full-page performance",
    "output": outputURL.path]
if let candidate {
    for _ in 0..<2 { _ = try dispatch(reference, useMoments: false); _ = try dispatch(candidate, useMoments: true) }
    var rows = [[String:Any]](), referenceTimes = [Double](), candidateTimes = [Double]()
    for cycle in 0..<7 {
        var times = [Double]()
        for name in ["A","B","B","A"] {
            let span = try dispatch(name == "A" ? reference : candidate, useMoments: name == "B")
            times.append(span)
            if name == "A" { referenceTimes.append(span) } else { candidateTimes.append(span) }
        }
        let a = (times[0]+times[3])/2, b = (times[1]+times[2])/2
        rows.append(["cycle": cycle,"order": ["A","B","B","A"],"gpuCommandSpanMS": times,
                     "referencePairMedianMS": a,"candidatePairMedianMS": b,"candidateChangePercent": (b/a-1)*100])
    }
    func median(_ x: [Double]) -> Double { let s=x.sorted(); return (s[(s.count-1)/2]+s[s.count/2])/2 }
    let a=median(referenceTimes), b=median(candidateTimes)
    metadata["frozenConsumptionBenchmark"] = [
        "scope": "7 ABBA cycles after 2 warmups per pipeline; command spans only; excludes moment generation, spatial field reads/interpolation, sync policy and SceneKit passes",
        "groups": groupCount,"momentBufferBytes": momentData!.count,"inputBufferBytes": input.count,"outputBufferBytes": count*64,
        "referenceMedianMS": a,"candidateMedianMS": b,"candidateChangePercent": (b/a-1)*100,"cycles": rows]
}
let meta = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted,.sortedKeys])
try meta.write(to: outputURL.appendingPathExtension("json"))
FileHandle.standardOutput.write(meta)
