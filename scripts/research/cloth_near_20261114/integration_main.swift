func need(_ ok: Bool, _ message: String) throws {
    if !ok { throw NSError(domain: "ClothIntegration", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}
func sha(_ source: String) -> String { SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined() }
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2]), mode = CommandLine.arguments[3]
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let evidence = root.appendingPathComponent("output/local-test-runs/e20798afc1d24a04a6a908a8a51c23bf/evidence")
let measured = try String(contentsOf: evidence.appendingPathComponent("constant-lamp.surface"), encoding: .utf8)
let baseline = try String(contentsOf: evidence.appendingPathComponent("baseline.surface"), encoding: .utf8)
try need(sha(measured) == ClothShadowProgram.outputSHA256, "Measured output identity")
try need(ClothShadowProgram.replacingLocalBalls(in: baseline) == measured, "Actual transformer differs from measured shader")
for invalid in [baseline + "\n", baseline.replacingOccurrences(of: "0.85", with: "0.84"), measured, "#pragma body", baseline + baseline] {
    try need(ClothShadowProgram.replacingLocalBalls(in: invalid) == nil, "Unvalidated shader accepted")
}
try need(ClothShadowProgram.requested(arguments: []), "Default must enable H9")
#if DEBUG
try need(!ClothShadowProgram.requested(arguments: [ClothShadowProgram.disableArgument]), "Debug baseline override")
let expectsH9 = mode == "default"
#else
try need(ClothShadowProgram.requested(arguments: [ClothShadowProgram.disableArgument, "-rendering.referenceCloth"]), "Production diagnostic isolation")
let expectsH9 = true
#endif
// Keep the real asset resource alive through the real production weak cache.
// This CLI harness is not an iOS bundle and supplies the repository asset URL.
let field = try StaticClothIrradiance.acquire(emitter: MobileReferenceLighting.emitterGeometry,
    radiance: MobileReferenceLighting.rig.radiance, device: MTLCreateSystemDefaultDevice()!,
    assetURL: root.appendingPathComponent("QiuJi/Resources/StaticClothIrradiance-v1.bin"))
var reports = [[String: Any]]()
withExtendedLifetime(field) {
    do {
        for capacity in [16, 32] {
            let scene = AngleTrainingScene()
            let geometry = SCNSphere(radius: 1), material = SCNMaterial()
            material.name = "TaiNi"
            material.shaderModifiers = [.surface: MobileContactOcclusion.source(capacity: capacity)]
            geometry.materials = [material]
            scene.tableNode!.addChildNode(SCNNode(geometry: geometry))
            MobileReferenceLighting.refreshClothLighting(in: scene, ballCount: capacity)
            let actual = material.shaderModifiers![.surface]!
            try actual.write(to: output.appendingPathComponent("capacity-\(capacity).surface"), atomically: true, encoding: .utf8)
            if capacity == 16 {
                if expectsH9 { try need(actual == measured, "Shared refresh did not install the measured H9 shader") }
                #if DEBUG
                if mode == "c1" { try need(actual == baseline, "C1 override changed") }
                if mode == "no-field" || mode == "original" {
                    try need(!actual.contains("temporalFieldDiffuse") && !actual.contains("nearLampMasks"), "Reference override changed")
                }
                #endif
            } else {
                try need(!actual.contains("nearLampMasks") && !actual.contains("temporalFieldDiffuse"), "Unsupported capacity did not fall back")
                try need(scene.recordedState?.effective == false && scene.staticClothIrradiance == nil, "Fallback state/resource")
            }
            try need(material.lightingModel == .physicallyBased, "PBR must remain")
            reports.append(["capacity": capacity, "sha256": sha(actual), "h9": actual == measured,
                            "c1": actual == baseline, "pbr": true])
        }
    } catch { fatalError(String(describing: error)) }
}
try JSONSerialization.data(withJSONObject: ["mode": mode, "expectsH9": expectsH9,
    "actualSharedRefresh": true, "invalidSourcesRejected": 5, "cases": reports], options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("result.json"))
print("Shared refresh passed: \(mode)")
