import Foundation
import Metal

func failure(_ message: String) -> NSError {
    NSError(domain: "ClothSupportHeight", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}
func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    return (sorted[(sorted.count-1)/2]+sorted[sorted.count/2])/2
}
guard CommandLine.arguments.count == 6 else { throw failure("kernel inputs balls output batchCount") }
let args = CommandLine.arguments
let batchCount = Int(args[5]) ?? 0
guard (1...32).contains(batchCount) else { throw failure("Invalid batch count") }
let input = try Data(contentsOf: URL(fileURLWithPath: args[2]))
let ballData = try Data(contentsOf: URL(fileURLWithPath: args[3]))
let out = URL(fileURLWithPath: args[4], isDirectory: true)
guard !FileManager.default.fileExists(atPath: out.path), input.count > 0, input.count % 48 == 0, ballData.count == 256 else {
    throw failure("Invalid input or output exists")
}
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { throw failure("No Metal device") }
let options = MTLCompileOptions(); options.fastMathEnabled = false
let library = try device.makeLibrary(source: String(contentsOfFile: args[1], encoding: .utf8), options: options)
var pipelines = [String: MTLComputePipelineState]()
for (mode, name) in [("reference", "evaluateReference"), ("height", "evaluateHeightSupport")] {
    guard let function = library.makeFunction(name: name) else { throw failure("Missing kernel") }
    pipelines[mode] = try device.makeComputePipelineState(function: function)
}
func buffer(_ data: Data) throws -> MTLBuffer {
    guard let result = data.withUnsafeBytes({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }) else {
        throw failure("Allocation failed")
    }
    return result
}
let samples = try buffer(input), balls = try buffer(ballData)
let count = input.count/48
guard let result = device.makeBuffer(length: count*64, options: .storageModeShared) else { throw failure("Result allocation") }
var sampleCount = UInt32(count)
func run(_ mode: String) throws -> Double {
    guard let command = queue.makeCommandBuffer() else { throw failure("Command buffer") }
    for _ in 0..<batchCount {
        guard let encoder = command.makeComputeCommandEncoder(), let pipeline = pipelines[mode] else { throw failure("Encoder") }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(samples, offset: 0, index: 0)
        encoder.setBuffer(balls, offset: 0, index: 1)
        encoder.setBuffer(result, offset: 0, index: 2)
        encoder.setBytes(&sampleCount, length: 4, index: 3)
        encoder.dispatchThreadgroups(MTLSize(width: (count+127)/128, height: 1, depth: 1),
                                     threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
        encoder.endEncoding()
    }
    command.commit(); command.waitUntilCompleted()
    guard command.status == .completed else { throw command.error ?? failure("Execution failed") }
    return (command.gpuEndTime-command.gpuStartTime)*1000/Double(batchCount)
}
var outputs = [String: [Float]]()
for mode in ["reference", "height"] {
    _ = try run(mode)
    let values = Array(UnsafeBufferPointer(start: result.contents().bindMemory(to: Float.self, capacity: count*16), count: count*16))
    guard values.allSatisfy({ $0.isFinite }) else { throw failure("Nonfinite output") }
    outputs[mode] = values
    try Data(bytes: result.contents(), count: count*64).write(to: out.appendingPathComponent(mode+".bin"))
}
let reference = outputs["reference"]!, candidate = outputs["height"]!
var maxError: Float = 0, changedChannels = 0, changedMasks = 0, referenceBalls = 0, candidateBalls = 0
var nearExact = true, maskSubset = true
let channels = [0, 1, 2, 4, 5, 6, 8, 9, 10, 12, 13, 14]
for i in 0..<count {
    for j in channels {
        let a = reference[i*16+j], b = candidate[i*16+j]
        maxError = max(maxError, abs(a-b))
        if a.bitPattern != b.bitPattern { changedChannels += 1 }
    }
    nearExact = nearExact && reference[i*16+3].bitPattern == candidate[i*16+3].bitPattern
    let a = UInt32(reference[i*16+7]), b = UInt32(candidate[i*16+7])
    maskSubset = maskSubset && (b & ~a) == 0
    if a != b { changedMasks += 1 }
    if reference[i*16+3] != 0 {
        referenceBalls += a.nonzeroBitCount
        candidateBalls += b.nonzeroBitCount
    }
}
let validation: [String: Any] = ["radiometricMaxAbs": maxError, "radiometricChangedChannels": changedChannels,
    "nearBitIdentical": nearExact, "maskSubset": maskSubset, "changedMasks": changedMasks,
    "nearReferenceBallChecks": referenceBalls, "nearCandidateBallChecks": candidateBalls]
try JSONSerialization.data(withJSONObject: validation, options: [.prettyPrinted, .sortedKeys])
    .write(to: out.appendingPathComponent("validation.json"))
guard changedChannels == 0, nearExact, maskSubset else {
    throw failure("Height support changed output: max=\(maxError), channels=\(changedChannels), near=\(nearExact), subset=\(maskSubset)")
}
for _ in 0..<4 { for mode in ["reference", "height"] { _ = try run(mode) } }
var rows = [[String: Any]](), changes = [Double](), baseline = [Double](), trial = [Double]()
for cycle in 0..<9 {
    let order = cycle % 2 == 0 ? ["reference", "height", "height", "reference"] : ["height", "reference", "reference", "height"]
    var times = [Double](), a = [Double](), b = [Double]()
    for mode in order {
        let span = try run(mode); times.append(span)
        if mode == "reference" { a.append(span); baseline.append(span) } else { b.append(span); trial.append(span) }
    }
    let change = (median(b)/median(a)-1)*100; changes.append(change)
    rows.append(["cycle": cycle, "order": order, "spanPerIterationMS": times,
                 "pairedChangePercent": change, "referenceEndpointDriftPercent": abs(a[0]-a[1])/median(a)*100])
}
let report: [String: Any] = ["device": device.name, "samples": count, "batchCount": batchCount,
    "scope": "Actual SceneKit pixel inputs in offline math compute, height-aware blocker support only; not complete material/raster/present/iOS performance",
    "validation": validation, "pairedChangeMedianPercent": median(changes),
    "referenceMedianMS": median(baseline), "candidateMedianMS": median(trial), "cycles": rows]
try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    .write(to: out.appendingPathComponent("result.json"))
print("samples=\(count) change=\(median(changes)) validation=\(validation)")
