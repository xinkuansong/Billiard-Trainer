// Concatenated after guarded, verbatim production Swift extraction by
// support_program_cpu.py. This file does not construct a SceneKit renderer.
import Foundation

enum ProgramMode: String, CaseIterable {
    case original, debugOff, safeOn, guardOn
}

struct GeneratedProgram {
    let source: String
    let declaration: String
    let declarationSuffix: String
    let requested: Bool
    let effective: Bool
    let capacity: Int
    let reason: String?
}

@inline(never)
func constructProgram(_ mode: ProgramMode, capacity: Int) -> GeneratedProgram {
    switch mode {
    case .original:
        return GeneratedProgram(source: MobileReferenceLighting.directShadowShader(
            ballCount: capacity, profile: .reflection), declaration: "", declarationSuffix: "", requested: false,
            effective: false, capacity: capacity, reason: "not-requested")
    case .debugOff, .safeOn, .guardOn:
        let program = MobileReferenceLighting.directShadowProgram(ballCount: capacity,
            profile: .reflection, safeSupportRequested: mode == .safeOn,
            supportRequest: mode == .guardOn ? .guardCombo : nil)
        return GeneratedProgram(source: program.source, declaration: program.declaration, declarationSuffix: program.declarationSuffix,
            requested: program.state.requested, effective: program.state.effective,
            capacity: program.state.capacity, reason: program.state.fallbackReason)
    }
}

func uptime() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
func elapsedMS(_ start: UInt64, _ end: UInt64) -> Double { Double(end - start) / 1_000_000 }
func quantile(_ values: [Double], _ probability: Double) -> Double {
    let ordered = values.sorted()
    let position = probability * Double(ordered.count - 1)
    let low = Int(position.rounded(.down)), high = Int(position.rounded(.up))
    return ordered[low] + (ordered[high] - ordered[low]) * (position - Double(low))
}
func distribution(_ values: [Double]) -> [String: Any] {
    ["count": values.count, "min": values.min()!, "p25": quantile(values, 0.25),
     "p50": quantile(values, 0.50), "p75": quantile(values, 0.75),
     "p95": quantile(values, 0.95), "max": values.max()!]
}

let args = CommandLine.arguments
guard args.count == 6, let capacity = Int(args[2]), capacity == 16,
      let cycles = Int(args[3]), cycles >= 3 && cycles <= 21,
      let batchSize = Int(args[4]), batchSize >= 1 && batchSize <= 64 else {
    fatalError("usage: cpu-program reference.surface 16 cycles batchSize output.json")
}
let fullReference = try String(contentsOfFile: args[1], encoding: .utf8)
let thermalStart = ProcessInfo.processInfo.thermalState.rawValue
let referenceSHA = "9495698875cd01a4ecd8d00708ce88bf9989c6e118805620f99a11d03dcca390"
precondition(ClothResearchShaders.sha256(fullReference) == referenceSHA)

// These first calls share a process and run in a fixed order. Preserve them as
// observations; they are NOT comparable cold-start estimates for three apps.
var firstCalls: [[String: Any]] = []
var expected: [ProgramMode: GeneratedProgram] = [:]
for mode in ProgramMode.allCases {
    let start = uptime()
    let program = constructProgram(mode, capacity: capacity)
    let end = uptime()
    firstCalls.append(["mode": mode.rawValue, "ms": elapsedMS(start, end)])
    expected[mode] = program
}
let original = expected[.original]!, off = expected[.debugOff]!, safe = expected[.safeOn]!, guarded = expected[.guardOn]!
precondition(original.source == off.source && off.declaration.isEmpty && !off.effective)
precondition(safe.requested && safe.effective && safe.reason == nil && safe.capacity == 16)
precondition(ClothResearchShaders.sha256(original.source) == ClothResearchShaders.referenceCoreSHA256)
precondition(fullReference.components(separatedBy: original.source).count == 2)
precondition(fullReference.components(separatedBy: MobileReferenceLighting.analyticPanelDiffuse).count == 2)
let fullCandidate = fullReference.replacingOccurrences(of: original.source, with: safe.source)
    .replacingOccurrences(of: MobileReferenceLighting.analyticPanelDiffuse,
                          with: safe.declaration + MobileReferenceLighting.analyticPanelDiffuse)
let independentCandidate = try ClothResearchShaders.heightSafeSurface(fullReference, ballCount: 16)
precondition(fullCandidate == independentCandidate)
let fullGuard = fullReference.replacingOccurrences(of: original.source, with: guarded.source)
    .replacingOccurrences(of: MobileReferenceLighting.analyticPanelDiffuse,
                          with: guarded.declaration + MobileReferenceLighting.analyticPanelDiffuse + guarded.declarationSuffix)
precondition(guarded.requested && guarded.effective && guarded.reason == nil)
precondition(ClothResearchShaders.sha256(fullGuard) == "ca5acc70043f0da620e2c6501188063c78027c8e26b62233d128ced01f81aabd")
var contractCases = 0
for request in DailyClothSupportExperiment.Request.allCases {
    for count in [0, 1, 16, 32, 48] {
      for masked in [false, true] {
        for merged in [false, true] {
          for factored in [false, true] {
            let reference = MobileReferenceLighting.directShadowShader(ballCount: count, usesMask: masked,
                profile: .reflection, mergesSupport: merged, factorsBRDF: factored)
            let trial = MobileReferenceLighting.directShadowProgram(ballCount: count, usesMask: masked,
                profile: .reflection, mergesSupport: merged, factorsBRDF: factored, supportRequest: request)
            let supported = (request == .plainSafe || request == .guardCombo) && count == 16 && masked && !merged && !factored
            precondition(trial.state.effective == supported)
            precondition(trial.state.requestedVariant == request.rawValue)
            if !supported {
                precondition(trial.source == reference && trial.declaration.isEmpty && trial.declarationSuffix.isEmpty)
            }
            contractCases += 1
          }
        }
      }
    }
}

var checksum: UInt64 = 0
func validateAndConsume(_ program: GeneratedProgram, mode: ProgramMode) {
    let comparison = expected[mode]!
    precondition(program.source == comparison.source && program.declaration == comparison.declaration)
    precondition(program.declarationSuffix == comparison.declarationSuffix)
    precondition(program.requested == comparison.requested && program.effective == comparison.effective)
    precondition(program.capacity == comparison.capacity && program.reason == comparison.reason)
    checksum &+= UInt64(program.source.utf8.count + program.declaration.utf8.count + program.declarationSuffix.utf8.count + program.capacity)
}
let warmups = 24
for _ in 0..<warmups {
    for mode in ProgramMode.allCases { validateAndConsume(constructProgram(mode, capacity: capacity), mode: mode) }
}

var batches: [[String: Any]] = []
var pairs: [[String: Any]] = []
var callsByMode: [ProgramMode: [Double]] = [:]
var meansByMode: [ProgramMode: [Double]] = [:]
var orderIndex = 0
for cycle in 0..<cycles {
    // Alternate which comparison runs first. Each pair is independently ABBA
    // or BAAB, so each arm has the same average temporal position.
    let baseCompetitors: [ProgramMode] = [.debugOff, .safeOn, .guardOn]
    let competitors = Array(baseCompetitors[(cycle % 3)...]) + Array(baseCompetitors[..<(cycle % 3)])
    for competitor in competitors {
        let sequence: [ProgramMode] = cycle.isMultiple(of: 2)
            ? [.original, competitor, competitor, .original]
            : [competitor, .original, .original, competitor]
        var armMeans: [ProgramMode: [Double]] = [:]
        for (position, mode) in sequence.enumerated() {
            var retained: [GeneratedProgram] = []
            retained.reserveCapacity(batchSize)
            var callTimes: [Double] = []
            callTimes.reserveCapacity(batchSize)
            let batchStart = uptime()
            for _ in 0..<batchSize {
                let start = uptime()
                let program = constructProgram(mode, capacity: capacity)
                let end = uptime()
                // Array writes, correctness checks and hashing are outside each
                // individual construction interval. Keep real outputs observable.
                retained.append(program)
                callTimes.append(elapsedMS(start, end))
            }
            let batchEnd = uptime()
            for program in retained { validateAndConsume(program, mode: mode) }
            let mean = callTimes.reduce(0, +) / Double(batchSize)
            callsByMode[mode, default: []] += callTimes
            meansByMode[mode, default: []].append(mean)
            armMeans[mode, default: []].append(mean)
            batches.append(["order": orderIndex, "cycle": cycle, "competitor": competitor.rawValue,
                "position": position, "mode": mode.rawValue, "singleConstructionMS": callTimes,
                "meanConstructionMS": mean, "batchWallIncludingArrayWritesMS": elapsedMS(batchStart, batchEnd)])
            orderIndex += 1
        }
        let a = armMeans[.original]!, b = armMeans[competitor]!
        let meanA = (a[0] + a[1]) / 2, meanB = (b[0] + b[1]) / 2
        pairs.append(["cycle": cycle, "competitor": competitor.rawValue,
            "sequence": sequence.map(\.rawValue), "originalMeanMS": meanA,
            "candidateMeanMS": meanB, "deltaMS": meanB - meanA,
            "deltaPercent": 100 * (meanB / meanA - 1),
            "originalSecondVsFirstPercent": 100 * (a[1] / a[0] - 1)])
    }
}
var summaries: [String: Any] = [:]
for mode in ProgramMode.allCases {
    summaries[mode.rawValue] = ["singleConstructionMS": distribution(callsByMode[mode]!),
        "batchMeanConstructionMS": distribution(meansByMode[mode]!)]
}
var pairedSummaries: [String: Any] = [:]
for competitor in [ProgramMode.debugOff, .safeOn, .guardOn] {
    let selected = pairs.filter { $0["competitor"] as? String == competitor.rawValue }
    pairedSummaries[competitor.rawValue] = [
        "deltaMS": distribution(selected.map { $0["deltaMS"] as! Double }),
        "deltaPercent": distribution(selected.map { $0["deltaPercent"] as! Double }),
        "originalSecondVsFirstPercent": distribution(selected.map { $0["originalSecondVsFirstPercent"] as! Double })]
}
var sourceBytes: [String: Any] = [:]
sourceBytes["referenceCore"] = original.source.utf8.count
sourceBytes["safeCore"] = safe.source.utf8.count
sourceBytes["helperWithoutTrailingNewline"] = DailyClothSupportExperiment.heightSafeBelow.utf8.count
sourceBytes["helperDeclaration"] = safe.declaration.utf8.count
sourceBytes["fullReferenceSurface"] = fullReference.utf8.count
sourceBytes["fullSafeSurface"] = fullCandidate.utf8.count
sourceBytes["fullSurfaceDelta"] = fullCandidate.utf8.count - fullReference.utf8.count
sourceBytes["guardCore"] = guarded.source.utf8.count
sourceBytes["guardDeclarationSuffix"] = guarded.declarationSuffix.utf8.count
sourceBytes["fullGuardSurface"] = fullGuard.utf8.count
sourceBytes["fullGuardSurfaceDelta"] = fullGuard.utf8.count - fullReference.utf8.count
sourceBytes["referenceCoreSHA256"] = ClothResearchShaders.sha256(original.source)
sourceBytes["safeCoreSHA256"] = ClothResearchShaders.sha256(safe.source)
sourceBytes["referenceSurfaceSHA256"] = referenceSHA
sourceBytes["safeSurfaceSHA256"] = ClothResearchShaders.sha256(fullCandidate)
sourceBytes["guardCoreSHA256"] = ClothResearchShaders.sha256(guarded.source)
sourceBytes["guardSurfaceSHA256"] = ClothResearchShaders.sha256(fullGuard)
let result: [String: Any] = [
    "scope": "macOS pure CPU string construction wall time; no GPU, no SceneKit material install/compiler, no App frame timing",
    "capacity": capacity, "profile": "R", "sampling": "reference", "warmupCallsPerMode": warmups,
    "pairedCyclesPerComparison": cycles, "callsPerBatch": batchSize,
    "untimedSourceContractCases": contractCases,
    "clock": "DispatchTime monotonic uptime nanoseconds; individual interval includes constructProgram return but excludes array writes/validation",
    "firstCallFixedOrderNotComparableColdStarts": firstCalls,
    "thermalStateStart": thermalStart, "thermalStateEnd": ProcessInfo.processInfo.thermalState.rawValue,
    "summaries": summaries, "pairedSummaries": pairedSummaries, "rawBatches": batches, "rawPairs": pairs,
    "outputChecksum": checksum,
    "sourceBytes": sourceBytes,
    "sourceSizeCaveat": "UTF-8 shader source length only; not MTLFunction/pipeline/driver allocations or GPU memory",
    "productionInvocationBoundary": "refreshClothLighting during initial install or contact capacity expansion; no shader generation/hash during per-frame camera/uniform updates"
]
let encoded = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
try encoded.write(to: URL(fileURLWithPath: args[5]), options: .atomic)
print("CPU program construction: \(orderIndex) batches; checksum \(checksum); correctness preserved")
