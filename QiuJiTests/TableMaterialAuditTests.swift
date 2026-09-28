import XCTest
import SceneKit
import Metal
import MetalKit
@testable import QiuJi

/// Opt-in evidence capture of the complete production scene, not a material-ball renderer.
@MainActor
final class TableMaterialAuditTests: XCTestCase {
    /// Inspect the wall from the playing surface, which the original outside
    /// pocket cameras did not cover. Optical coordinates only; no geometry edit.
    func testLeatherInnerWallDetail() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["V64_MATERIAL_AUDIT"] == "1" || env["TEST_RUNNER_V64_MATERIAL_AUDIT"] == "1" else {
            throw XCTSkip("Opt-in leather wall evidence")
        }
        let leaf = env["V64_AUDIT_LEAF"] ?? env["TEST_RUNNER_V64_AUDIT_LEAF"] ?? UUID().uuidString
        XCTAssertFalse(leaf.contains("/"))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let out = root.appendingPathComponent("output/table-materials-v64/W5/" + leaf)
        guard !FileManager.default.fileExists(atPath: out.path) else { XCTFail("Existing evidence"); return }
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let scene = AngleTrainingScene()
        scene.setupScene(mobileRendering: true)
        XCTAssertTrue(scene.applyTableStyle(.charcoal))
        scene.setCameraMode(.perspective3D, animated: false)
        scene.hideCueStick()
        XCTAssertEqual(scene.addPocketMarkers().count, 6)
        let y = scene.surfaceY
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: y)
        let middle = pockets[4], corner = pockets[0]
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene; renderer.pointOfView = scene.cameraNode
        renderer.delegate = scene.contactOcclusion
        let shots: [(String, SCNVector3, SCNVector3, Double)] = [
            ("middle-inside", SCNVector3(0.08,y+0.09,middle.z+0.32), SCNVector3(0,y+0.018,middle.z),0.115),
            ("middle-playing-distance", SCNVector3(0.16,y+0.20,middle.z+0.80), SCNVector3(0,y+0.018,middle.z),0.36),
            ("corner-inside", SCNVector3(corner.x+0.28,y+0.17,corner.z+0.28), SCNVector3(corner.x,y+0.018,corner.z),0.14),
            ("player-wide", SCNVector3(0.9,y+0.48,1.65), SCNVector3(0,y,0),1.02)
        ]
        func capture(_ shot: (String, SCNVector3, SCNVector3, Double), _ variant: String) throws {
            SCNTransaction.begin(); SCNTransaction.disableActions = true
            scene.cameraNode.camera?.usesOrthographicProjection = true
            scene.cameraNode.camera?.orthographicScale = shot.3
            scene.cameraNode.position = shot.1
            scene.cameraNode.look(at: shot.2, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,-1))
            SCNTransaction.commit(); SCNTransaction.flush()
            XCTAssertTrue(renderer.prepare(scene, shouldAbortBlock: nil))
            let size = CGSize(width: 1200,height: 900)
            _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            let png = try XCTUnwrap(renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X).pngData())
            try png.write(to: out.appendingPathComponent(shot.0 + "-" + variant + ".png"))
        }
        for shot in shots { try capture(shot,"current") }
        for index in 0..<16 {
            let shot = shots[0]
            let moving = ("inside-orbit-\(index)",
                SCNVector3(shot.1.x + Float(index)*0.006,shot.1.y,shot.1.z),
                shot.2,shot.3*(1-Double(index)*0.004))
            try capture(moving,"current")
        }
        let leather = materials(scene,named: "Leather")
        XCTAssertFalse(leather.isEmpty)
        let originals = leather.map { $0.shaderModifiers }
        for material in leather {
            var shader = material.shaderModifiers ?? [:]
            shader[.surface] = shader[.surface]?.replacingOccurrences(of:
                "clamp(pow(max(leatherLuma,0.0001)/0.03437944,0.20),0.85,1.15)", with: "1.0")
                .replacingOccurrences(of:
                "clamp(pow(max(leatherLuma,0.0001)/0.03437944,0.05),0.97,1.03)", with: "1.0")
            material.shaderModifiers = shader
        }
        for shot in shots.prefix(3) { try capture(shot,"without-source-clouding") }
        for (material, original) in zip(leather,originals) { material.shaderModifiers = original }
        let configuration: [String:Any] = ["space":"SceneKit metres, X/Z horizontal, Y up",
            "exposure":scene.cameraNode.camera?.exposureOffset ?? 0,
            "shots":shots.map { ["name":$0.0,"eye":[$0.1.x,$0.1.y,$0.1.z],"target":[$0.2.x,$0.2.y,$0.2.z],"scale":$0.3] as [String:Any] }]
        try JSONSerialization.data(withJSONObject:configuration,options:[.prettyPrinted,.sortedKeys])
            .write(to:out.appendingPathComponent("config.json"))
    }

    func testProductionBaselineAndChannelAblations() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["V64_MATERIAL_AUDIT"] == "1" || env["TEST_RUNNER_V64_MATERIAL_AUDIT"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_V64_MATERIAL_AUDIT=1 for material evidence capture")
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let leaf = env["V64_AUDIT_LEAF"] ?? env["TEST_RUNNER_V64_AUDIT_LEAF"] ?? "capture-" + UUID().uuidString
        XCTAssertFalse(leaf.contains("/"), "Use a single output leaf")
        let stage = env["V64_AUDIT_STAGE"] ?? env["TEST_RUNNER_V64_AUDIT_STAGE"] ?? "W0"
        let out = root.appendingPathComponent("output/table-materials-v64/" + stage + "/" + leaf)
        guard !FileManager.default.fileExists(atPath: out.path) else {
            XCTFail("Evidence directory already exists: \(out.path)"); return
        }
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let scene = AngleTrainingScene()
        _ = scene.applyTableStyle(.standard)
        scene.setupScene(mobileRendering: true)
        scene.setCameraMode(.perspective3D, animated: false)
        scene.hideCueStick()
        let sourceLeather = try XCTUnwrap(materials(scene, named: "Leather").first?.copy() as? SCNMaterial)
        XCTAssertTrue(scene.applyTableStyle(.charcoal))
        let y = scene.surfaceY
        scene.applyBallLayout(cueBallPosition: SCNVector3(-0.35, y + AngleSceneCalculator.ballRadius, 0.12),
                              targetBallNumber: 3, targetPosition: SCNVector3(0.2, y + AngleSceneCalculator.ballRadius, 0.03))
        XCTAssertNotNil(scene.rootNode.childNode(withName: "reference_room", recursively: false))
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.delegate = scene.contactOcclusion
        struct Shot {
            let name: String
            let eye: SCNVector3
            let target: SCNVector3
            let scale: Double
        }
        // SceneKit metres: X/Z horizontal, Y up. Camera samples only; model is untouched.
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: y)
        let corner = pockets[0]
        let middle = pockets[4]
        let shots = [
            Shot(name: "overview", eye: SCNVector3(1.6, 2.55, 2.2), target: SCNVector3(0, 0.68, 0), scale: 1.72),
            Shot(name: "midrange", eye: SCNVector3(-1.3, 1.65, -1.4), target: SCNVector3(-0.45, y, -0.30), scale: 0.68),
            Shot(name: "corner", eye: SCNVector3(corner.x + 0.20, y + 0.32, corner.z - 0.25), target: corner, scale: 0.16),
            Shot(name: "middle", eye: SCNVector3(0.1, y + 0.32, middle.z - 0.28), target: middle, scale: 0.16),
            Shot(name: "wood", eye: SCNVector3(-0.6, y + 0.34, -1.05), target: SCNVector3(-0.55, y, -0.73), scale: 0.28),
            Shot(name: "cloth", eye: SCNVector3(-0.35, y + 0.17, -0.52), target: SCNVector3(-0.25, y, 0), scale: 0.29)
        ]
        func capture(_ shot: Shot, _ suffix: String) throws -> Data {
            SCNTransaction.begin()
            SCNTransaction.disableActions = true
            scene.cameraNode.camera?.usesOrthographicProjection = true
            scene.cameraNode.camera?.orthographicScale = shot.scale
            scene.cameraNode.position = shot.eye
            scene.cameraNode.look(at: shot.target, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
            SCNTransaction.commit()
            SCNTransaction.flush()
            XCTAssertTrue(renderer.prepare(scene, shouldAbortBlock: nil))
            let size = CGSize(width: 1200, height: 900)
            _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            let result = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            let projected = renderer.projectPoint(shot.target)
            XCTAssertEqual(projected.x, Float(size.width / 2), accuracy: 0.2)
            XCTAssertEqual(projected.y, Float(size.height / 2), accuracy: 0.2)
            let data = try XCTUnwrap(result.pngData())
            try data.write(to: out.appendingPathComponent(shot.name + "-" + suffix + ".png"))
            return data
        }
        var inventory = [[String: Any]]()
        var nodes = 0, materialSlots = 0, elements = 0, primitives = 0
        var materialIDs = Set<ObjectIdentifier>()
        scene.tableNode?.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry else { return }
            nodes += 1
            materialSlots += geometry.materials.count
            elements += geometry.elements.count
            primitives += geometry.elements.reduce(0) { $0 + $1.primitiveCount }
            for m in geometry.materials { materialIDs.insert(ObjectIdentifier(m)) }
        }
        let maps: [(String, MTLTexture)] = [("leather-normal", TableSurfaceTextures.leatherNormal),
            ("leather-roughness", TableSurfaceTextures.leatherRoughness), ("wood-roughness", TableSurfaceTextures.woodRoughness)]
        let resourceCounts: [String: Any] = ["textures": maps.map { name, texture in
            ["name": name, "width": texture.width, "height": texture.height,
             "pixelFormat": texture.pixelFormat.rawValue, "mipLevels": texture.mipmapLevelCount,
             "allocatedBytes": texture.allocatedSize] as [String: Any]
        }, "geometryNodes": nodes, "materialSlots": materialSlots,
            "uniqueMaterials": materialIDs.count, "geometryElements": elements, "sourcePrimitives": primitives,
            "note": "Scene structure counters; not measured GPU draw calls or resident bytes"]
        try JSONSerialization.data(withJSONObject: resourceCounts, options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent("resources.json"))
        scene.tableNode?.enumerateChildNodes { node, _ in
            for m in node.geometry?.materials ?? [] {
                inventory.append(["node": node.name ?? "", "material": m.name ?? "", "lighting": m.lightingModel.rawValue,
                                  "diffuse": String(describing: m.diffuse.contents), "normal": String(describing: m.normal.contents),
                                  "normalIntensity": m.normal.intensity, "roughness": String(describing: m.roughness.contents),
                                  "roughnessIntensity": m.roughness.intensity, "uvScale": [m.normal.contentsTransform.m11, m.normal.contentsTransform.m22],
                                  "surfaceShader": m.shaderModifiers?[.surface] ?? ""])
            }
        }
        try JSONSerialization.data(withJSONObject: inventory, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("materials.json"))
        let config: [String: Any] = ["tableStyle": "charcoal", "clothColor": "green", "mobileRendering": true,
            "exposure": scene.cameraNode.camera?.exposureOffset ?? 0,
            "shots": shots.map { ["name": $0.name, "eye": [$0.eye.x, $0.eye.y, $0.eye.z], "target": [$0.target.x, $0.target.y, $0.target.z], "scale": $0.scale] as [String: Any] }]
        try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("config.json"))
        // Compare identical extraction states: compacting the same polygons can
        // change a few quantized edge pixels through raster/derivative ordering.
        if env["V64_BASELINE_ONLY"] == "1" || env["TEST_RUNNER_V64_BASELINE_ONLY"] == "1" {
            XCTAssertEqual(scene.addPocketMarkers().count, 6)
        }
        var baselines: [String: Data] = [:]
        for shot in shots { baselines[shot.name] = try capture(shot, "baseline") }
        if env["V64_BASELINE_ONLY"] == "1" || env["TEST_RUNNER_V64_BASELINE_ONLY"] == "1" {
            if stage == "W3" && leaf == "app-r1" {
                let cloth = materials(scene, named: "TaiNi")
                let saved = cloth.map { ($0.normal.intensity, $0.shaderModifiers) }
                for strength: CGFloat in [0.65, 0.9, 1.15] {
                    for m in cloth { m.normal.intensity = strength }
                    _ = try capture(shots[5], "normal-\(strength)")
                }
                for (m, original) in zip(cloth, saved) { m.normal.intensity = original.0 }
                for m in cloth {
                    var mods = m.shaderModifiers ?? [:]
                    mods[.surface] = mods[.surface]?.replacingOccurrences(of: "_surface.emission.rgb =", with: """
                    float3 napN=normalize((scn_frame.inverseViewTransform*float4(_surface.geometryNormal,0.0)).xyz);
                    float nap=1.0+0.10*pow(1.0-abs(dot(napN,v)),3.0);
                    _surface.diffuse.rgb *= nap;
                    _surface.emission.rgb =
                    """)
                    m.shaderModifiers = mods
                }
                _ = try capture(shots[5], "nap-candidate")
                for (m, original) in zip(cloth, saved) { m.normal.intensity = original.0; m.shaderModifiers = original.1 }
            }
            for i in 0..<16 {
                let c = shots[2]
                let orbit = Shot(name: "corner-orbit-\(i)", eye: SCNVector3(c.eye.x + Float(i) * 0.01, c.eye.y, c.eye.z), target: c.target, scale: c.scale)
                _ = try capture(orbit, "candidate")
            }
            let markers = scene.addPocketMarkers().compactMap { $0 as? PocketLeatherMarker }
            XCTAssertEqual(markers.count, 6)
            for (i, marker) in markers.enumerated() {
                scene.setPocketHighlight(marker, style: .selected)
                _ = try capture(shots[0], "selected-\(i)")
                scene.clearPocketHighlights()
            }
            for style in TableStyle.allCases {
                XCTAssertTrue(scene.applyTableStyle(style))
                _ = try capture(shots[2], "theme-" + style.rawValue)
                _ = try capture(shots[4], "theme-" + style.rawValue)
                scene.setPocketRoles(first: 4, second: nil)
                _ = try capture(shots[3], "first-" + style.rawValue)
                scene.setPocketRoles(first: nil, second: 4)
                _ = try capture(shots[3], "second-" + style.rawValue)
                scene.setPocketRoles(first: 4, second: 4)
                _ = try capture(shots[3], "both-" + style.rawValue)
                scene.clearPocketHighlights()
            }
            if stage == "W3" || stage == "W4" {
                XCTAssertTrue(scene.applyTableStyle(.charcoal))
                for color in ClothColor.allCases {
                    XCTAssertTrue(scene.applyClothColor(color))
                    _ = try capture(shots[5], "color-" + color.rawValue)
                    _ = try capture(shots[0], "color-" + color.rawValue)
                    if color == .green || color == .tournamentBlue {
                        for i in 0..<24 {
                            let c = shots[5]
                            let moving = Shot(name: "cloth-\(color.rawValue)-motion-\(i)",
                                eye: SCNVector3(c.eye.x + Float(i)*0.005, c.eye.y + Float(i)*0.001, c.eye.z),
                                target: c.target, scale: c.scale*(1.0-Double(i)*0.004))
                            _ = try capture(moving, "candidate")
                        }
                    }
                }
                XCTAssertTrue(scene.applyClothColor(.green))
                for i in 0..<24 {
                    let c = shots[4]
                    let moving = Shot(name: "wood-motion-\(i)",
                        eye: SCNVector3(c.eye.x+Float(i)*0.008,c.eye.y,c.eye.z), target: c.target,
                        scale: c.scale*(1.0-Double(i)*0.005))
                    _ = try capture(moving, "candidate")
                }
            }
            XCTAssertTrue(scene.applyTableStyle(.charcoal))
            try assertQuantizedRestoration(capture(shots[2], "restored"), XCTUnwrap(baselines["corner"]))
            try assertQuantizedRestoration(capture(shots[3], "restored"), XCTUnwrap(baselines["middle"]))
            return
        }
        let leather = materials(scene, named: "Leather")
        let originals = leather.map { $0.copy() as! SCNMaterial }
        for strength: CGFloat in [0, 1] {
            for m in leather { m.normal.intensity = strength }
            for shot in shots[2...3] { _ = try capture(shot, "normal-\(Int(strength))") }
        }
        for (m, original) in zip(leather, originals) { m.normal.intensity = original.normal.intensity; m.shaderModifiers = sourceLeather.shaderModifiers }
        for shot in shots[2...3] { _ = try capture(shot, "untinted") }
        for (m, original) in zip(leather, originals) { m.shaderModifiers = original.shaderModifiers; m.roughness.contents = 0.65 }
        for shot in shots[2...3] { _ = try capture(shot, "roughness-flat") }
        for (m, original) in zip(leather, originals) { m.roughness.contents = original.roughness.contents }
        for shot in shots[2...3] { XCTAssertEqual(try capture(shot, "restored"), baselines[shot.name], "Ablation must restore exact pixels and camera") }
        let sourceTextureDirectory = root.appendingPathComponent("output/table-materials-v64/W0/source-textures/textures")
        let normal = try XCTUnwrap(UIImage(contentsOfFile: sourceTextureDirectory.appendingPathComponent("Leather_normal.png").path))
        let roughness = try XCTUnwrap(UIImage(contentsOfFile: sourceTextureDirectory.appendingPathComponent("Leather_roughness.png").path))
        let textureLoader = MTKTextureLoader(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let linearNormal = try textureLoader.newTexture(cgImage: XCTUnwrap(normal.cgImage), options: [.SRGB: false, .generateMipmaps: true])
        let linearRoughness = try textureLoader.newTexture(cgImage: XCTUnwrap(roughness.cgImage), options: [.SRGB: false, .generateMipmaps: true])
        for mode in ["roughness", "normal", "both"] {
            for (m, original) in zip(leather, originals) {
                m.setValue(SCNMaterialProperty(contents: linearNormal), forKey: "auditNormal")
                m.setValue(SCNMaterialProperty(contents: linearRoughness), forKey: "auditRoughness")
                let sample = """
                constexpr sampler auditSampler(coord::normalized, address::repeat, filter::linear, mip_filter::linear);
                float3 auditN = normalize(_surface.geometryNormal);
                float3 auditDP1 = dfdx(_surface.position), auditDP2 = dfdy(_surface.position);
                float2 auditUV1 = dfdx(_surface.diffuseTexcoord), auditUV2 = dfdy(_surface.diffuseTexcoord);
                float3 auditP2 = cross(auditDP2,auditN), auditP1 = cross(auditN,auditDP1);
                float3 auditT = auditP2*auditUV1.x + auditP1*auditUV2.x;
                float3 auditB = auditP2*auditUV1.y + auditP1*auditUV2.y;
                float auditInv = rsqrt(max(1e-12,max(dot(auditT,auditT),dot(auditB,auditB))));
                float3 auditTS = auditNormal.sample(auditSampler,_surface.diffuseTexcoord).rgb*2.0-1.0;
                \(mode != "roughness" ? "_surface.normal=normalize((auditT*auditTS.x+auditB*auditTS.y)*auditInv+auditN*auditTS.z);" : "")
                \(mode != "normal" ? "_surface.roughness=auditRoughness.sample(auditSampler,_surface.diffuseTexcoord).r;" : "")
                """
                var mods = original.shaderModifiers ?? [:]
                mods[.surface] = "#pragma arguments\ntexture2d<float> auditNormal;\ntexture2d<float> auditRoughness;\n#pragma declaration\n"
                    + (mods[.surface] ?? "").replacingOccurrences(of: "#pragma body", with: "#pragma body\n" + sample)
                m.shaderModifiers = mods
            }
            for shot in shots[2...3] { _ = try capture(shot, "explicit-" + mode) }
        }
        for (m, original) in zip(leather, originals) { m.shaderModifiers = original.shaderModifiers }
        // Isolate native PBR response; this is a diagnostic, not a production candidate.
        let wood = materials(scene, named: "Wood") + materials(scene, named: "BlackWood")
        let woodOriginals = wood.map { $0.copy() as! SCNMaterial }
        for m in wood { m.lightingModel = .physicallyBased; var mods = m.shaderModifiers ?? [:]; mods[.surface] = nil; m.shaderModifiers = mods }
        _ = try capture(shots[4], "native-pbr")
        for (m, original) in zip(wood, woodOriginals) { m.lightingModel = original.lightingModel; m.shaderModifiers = original.shaderModifiers }
        let cloth = materials(scene, named: "TaiNi")
        for m in cloth { m.normal.intensity = 0 }
        _ = try capture(shots[5], "normal-0")
        for m in cloth { m.normal.intensity = 0.65 }
        let clothTransforms = cloth.map { ($0.normal.contentsTransform, $0.roughness.contentsTransform) }
        for factor: Float in [1, 4] {
            for m in cloth {
                m.normal.contentsTransform = SCNMatrix4MakeScale(factor, factor, 1)
                m.roughness.contentsTransform = SCNMatrix4MakeScale(factor, factor, 1)
            }
            for shot in [shots[0], shots[5]] { _ = try capture(shot, "cloth-uv-\(Int(factor))") }
        }
        for (m, transforms) in zip(cloth, clothTransforms) {
            m.normal.contentsTransform = transforms.0; m.roughness.contentsTransform = transforms.1
        }
        XCTAssertEqual(try capture(shots[5], "restored"), baselines["cloth"])
        for i in 0..<5 {
            let c = shots[2]
            let shot = Shot(name: "corner-orbit-\(i)", eye: SCNVector3(c.eye.x + Float(i) * 0.04, c.eye.y, c.eye.z), target: c.target, scale: c.scale)
            _ = try capture(shot, "baseline")
        }
        XCTAssertEqual(scene.installedTableStyle, .charcoal)
        XCTAssertEqual(scene.installedClothColor, .green)
    }

    func testOfflineAppearanceBranches() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["V64_MATERIAL_AUDIT"] == "1" || env["TEST_RUNNER_V64_MATERIAL_AUDIT"] == "1" else {
            throw XCTSkip("Opt-in material export verification")
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("content/position_play/sequences")
        let source = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.hasPrefix("drill_c001__") && $0.pathExtension == "json" })
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let sequence = try decoder.decode(PositionPlaySequence.self, from: Data(contentsOf: source))
        for mobile in [false, true] {
            var options = SequenceVideoExporter.Options.teaching()
            options.size = CGSize(width: 360, height: 640); options.useAppAppearance = mobile
            let frames = SequenceVideoExporter.renderStills(sequence: sequence, options: options)
            let shot = try XCTUnwrap(frames.first { $0.name == "s01_still" })
            XCTAssertEqual(shot.image.width, Int(options.outputSize.width))
            XCTAssertEqual(shot.image.height, Int(options.outputSize.height))
            let attachment = XCTAttachment(image: UIImage(cgImage: shot.image))
            attachment.name = "offline-appearance-\(mobile)"; attachment.lifetime = .keepAlways; add(attachment)
        }
    }

    private func assertQuantizedRestoration(_ actual: Data, _ expected: Data) throws {
        func rgba(_ data: Data) throws -> [UInt8] {
            let image = try XCTUnwrap(UIImage(data: data)?.cgImage)
            let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return Array(UnsafeBufferPointer(start: try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self), count: image.width * image.height * 4))
        }
        let a = try rgba(actual), b = try rgba(expected)
        XCTAssertEqual(a.count, b.count)
        // Recompiled derivative-based micro normals can straddle one RGBA8
        // quantization boundary (observed: one edge pixel / 1,080,000 pixels).
        // Compare decoded channels; do not widen to image-average tolerance.
        let maximum = zip(a, b).map { abs(Int($0) - Int($1)) }.max() ?? 0
        XCTAssertLessThanOrEqual(maximum, 1, "Restoration exceeds one 8-bit quantization step")
    }

    private func materials(_ scene: AngleTrainingScene, named name: String) -> [SCNMaterial] {
        var seen = Set<ObjectIdentifier>()
        var result: [SCNMaterial] = []
        scene.tableNode?.enumerateChildNodes { node, _ in
            for m in node.geometry?.materials ?? [] where m.name == name {
                if seen.insert(ObjectIdentifier(m)).inserted { result.append(m) }
            }
        }
        return result
    }
}
