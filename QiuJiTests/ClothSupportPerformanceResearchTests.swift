import XCTest
import SceneKit
import Metal
import UIKit
import CryptoKit
import Combine
@testable import QiuJi

/// Explicit research selectors: actual production scene, explicit Metal target and same-target proof.
/// Simulator command times are raw harness diagnostics, never a performance ranking.
/// GPU command span is neither displayed FPS nor a complete SwiftUI-page/thermal measurement.
@MainActor
final class ClothSupportPerformanceResearchTests: XCTestCase {
    // H13 measures the current production consumer, not the earlier cloth-only export.
    #if DEBUG
    private final class StageCostDelegate: FrameDelegate, @unchecked Sendable {
        private let costLock = NSLock()
        private var applied: [Double] = []
        private var finished: [Double] = []
        override func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
            let start = CACurrentMediaTime()
            super.renderer(renderer, didApplyAnimationsAtTime: time)
            let elapsed = (CACurrentMediaTime() - start) * 1000
            costLock.lock(); applied.append(elapsed); costLock.unlock()
        }
        override func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            let start = CACurrentMediaTime()
            super.renderer(renderer, didRenderScene: scene, atTime: time)
            let elapsed = (CACurrentMediaTime() - start) * 1000
            costLock.lock(); finished.append(elapsed); costLock.unlock()
        }
        func take() -> [String: [Double]] {
            costLock.lock(); defer { costLock.unlock() }
            let result = ["contactUpdateMS": applied, "postRenderMaintenanceMS": finished]
            applied.removeAll(keepingCapacity: true); finished.removeAll(keepingCapacity: true)
            return result
        }
    }

    func testNativeCurrentMaterialAndCPUCost() throws {
        try runNativeMaterialStudy(vertexDiffuse: false)
    }

    func testNativeVertexDiffuseAndCurrentCPUCost() throws {
        try runNativeMaterialStudy(vertexDiffuse: true)
    }

    func testNativeStreamingDiffuseCost() throws {
        try runNativeMaterialStudy(vertexDiffuse: true, streamingDiffuse: true)
    }

    func testNativeBoundedShaderPrimitives() throws {
        try runNativeMaterialStudy(vertexDiffuse: true, primitiveCandidates: ["wood-atan", "cloth-half-gf"])
    }

    func testNativeUnscaledDiffuseEdges() throws {
        try runNativeMaterialStudy(vertexDiffuse: true, primitiveCandidates: ["wood-unscaled"])
    }

    func testNativeOpaqueBackfaceCulling() throws {
        try runNativeMaterialStudy(vertexDiffuse: true,
                                   primitiveCandidates: ["wood-cull", "legs-cull", "cloth-cull"])
    }

    func testNativeCombinedSolidCulling() throws {
        try runNativeMaterialStudy(vertexDiffuse: true, primitiveCandidates: ["solid-cull"])
    }

    func testNativeGroupedClothSamples() throws {
        try runNativeMaterialStudy(vertexDiffuse: true, primitiveCandidates: ["cloth-batch2", "cloth-batch4"])
    }

    func testNativeClothStripMasks() throws {
        try runNativeMaterialStudy(vertexDiffuse: true, primitiveCandidates: ["cloth-strip1", "cloth-strip2"])
    }

    func testNativePackedClothStripMasks() throws {
        try runNativeMaterialStudy(vertexDiffuse: true, primitiveCandidates: ["cloth-strip-packed"])
    }

    func testNativeSolidCullingExtendedQuality() throws {
        try solidCullingQuality(integrated: true, extended: true)
    }

    func testNativeDefaultSolidCullingQuality() async throws {
        try solidCullingQuality(integrated: true)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        try await solidCullingReuseContract()
    }

    func testNativeDefaultSolidCullingReuse() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("H15 reuse requires the authorized native Mac")
        #else
        guard ProcessInfo.processInfo.isiOSAppOnMac else { throw XCTSkip("H15 native Mac only") }
        try await solidCullingReuseContract()
        #endif
    }

    private func solidCullingQuality(integrated: Bool, extended: Bool = false) throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("H15 requires the authorized native Mac")
        #else
        guard ProcessInfo.processInfo.isiOSAppOnMac else { throw XCTSkip("H15 native Mac only") }
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        var rows: [[String: Any]] = []
        var complete = false, savedPairs = 0
        var savedCases = Set<String>()
        defer {
            attachStrictReport(["study": integrated ? "H15-default-culling-quality" : "H15-candidate-culling-quality",
                "device": device.name, "completed": complete && testRun?.totalFailureCount == 0, "rows": rows,
                "qualityAcceptance": "Separate review required; completion records acquisition, not pixel equivalence",
                "scope": "Native production scene image comparison, all table/cloth colors, opposing cameras, portrait/landscape/high-resolution, three rooms, 2D return and changed balls; no new performance/phone claim"],
                name: integrated ? "h15-default-quality.json" : "h15-candidate-quality.json")
        }
        let targetNames: Set<String> = ["Wood", "BlackWood", "MG_Gold"]
        let poses: [(String, SIMD3<Float>)] = [
            ("low-front", SIMD3(0, 1.05, 1.8)), ("low-back", SIMD3(0, 1.05, -1.8)),
            ("low-right", SIMD3(3.1, 1.02, 0)), ("low-left", SIMD3(-3.1, 1.02, 0)),
            ("oblique-front", SIMD3(1.8, 1.05, 1.4)), ("oblique-back", SIMD3(-1.8, 1.05, -1.4)),
            ("overview", SIMD3(1.8, 2.7, 2.1)), ("near", SIMD3(0.16, 1.15, 0.3))]
        let scopes: [(RoomStyle, CGSize, Bool)] = !extended
            ? [(.eastern, CGSize(width: 1400, height: 800), false),
               (.tournament, CGSize(width: 1920, height: 1080), false),
               (.tournament, CGSize(width: 1400, height: 800), false)] : [
            (.tournament, CGSize(width: 1400, height: 800), true),
            (.tournament, CGSize(width: 800, height: 1400), true),
            (.tournament, CGSize(width: 1920, height: 1080), false),
            (.walnut, CGSize(width: 1400, height: 800), false),
            (.eastern, CGSize(width: 1400, height: 800), false)]
        for (room, size, exhaustive) in scopes {
            try autoreleasepool {
                let scene = AngleTrainingScene()
                scene.configureReferenceTableRendering()
                scene.setupScene(recipe: .liveReference, roomStyle: room)
                let rig = try XCTUnwrap(scene.cameraRig)
                rig.configurePlayerCameraControls(daily: true); rig.viewportSize = size
                scene.setCameraMode(.perspective3D, animated: false)
                for _ in 0..<180 { rig.update(deltaTime: 1 / 60) }
                let target = try RenderTarget(device: device, scene: scene, size: size)
                let camera = try XCTUnwrap(scene.cameraNode)
                @MainActor func configure(_ pose: (String, SIMD3<Float>)) throws {
                    SCNTransaction.begin(); SCNTransaction.disableActions = true
                    defer { SCNTransaction.commit() }
                    scene.setCameraMode(.perspective3D, animated: false)
                    camera.camera?.usesOrthographicProjection = false
                    let offset = pose.1 - SIMD3(0, scene.surfaceY, 0)
                    let view = TwoViewCamera.Pose.looking(eye: pose.1, yaw: atan2(offset.z, offset.x),
                        pitch: -atan2(offset.y, hypot(offset.x, offset.z)), fov: 50)
                    camera.simdTransform = view.transform
                    camera.camera?.fieldOfView = 50
                    try require(abs(camera.simdWorldTransform.columns.0.y) < 0.00001, "H15 inspection camera must keep the production horizontal horizon")
                    try require(simd_length(view.forward - simd_normalize(-offset)) < 0.00001, "H15 inspection camera must face its declared target")
                }
                var appearances: [(TableStyle, ClothColor)] = []
                if exhaustive {
                    for style in TableStyle.allCases { for cloth in ClothColor.allCases { appearances.append((style, cloth)) } }
                } else {
                    for (i, cloth) in ClothColor.allCases.enumerated() { appearances.append((TableStyle.allCases[i % TableStyle.allCases.count], cloth)) }
                }
                @MainActor func compare(_ name: String, style: TableStyle, cloth: ClothColor, balls: Int, save: Bool = false) throws {
                    var materials: [SCNMaterial] = [], seen = Set<ObjectIdentifier>()
                    scene.rootNode.enumerateChildNodes { node, _ in
                        for material in node.geometry?.materials ?? [] where seen.insert(ObjectIdentifier(material)).inserted {
                            materials.append(material)
                        }
                    }
                    var solids: [SCNMaterial] = [], solidIDs = Set<ObjectIdentifier>()
                    scene.tableNode?.enumerateChildNodes { node, _ in
                        for m in node.geometry?.materials ?? [] where targetNames.contains(m.name ?? "") && solidIDs.insert(ObjectIdentifier(m)).inserted { solids.append(m) }
                    }
                    try require(Set(solids.compactMap(\.name)) == targetNames, "H15 all target slots required")
                    try require(solids.allSatisfy { $0.isDoubleSided == !integrated && $0.cullMode == .back }, "H15 actual default raster policy drift")
                    let original = materials.map { ($0.shaderModifiers, $0.lightingModel, $0.isDoubleSided, $0.cullMode) }
                    let clothMaterial = try XCTUnwrap(materials.first { $0.name == "TaiNi" })
                    try require(clothMaterial.isDoubleSided && ClothResearchShaders.sha256(clothMaterial.shaderModifiers?[.surface] ?? "") ==
                        "14a880284fffc793f01d0357b0a625559101609d7986c9ac0cac72e7085efa4f", "H15 preserve actual C1/H9 cloth")
                    @MainActor func apply(_ culled: Bool) {
                        for m in solids { m.isDoubleSided = !culled; m.cullMode = .back }
                        SCNTransaction.flush()
                    }
                    defer { apply(integrated) }
                    apply(false); _ = try target.render(frames: 4); let a = try target.readback()
                    _ = try target.render(frames: 1); let aa = try target.readback()
                    apply(true); _ = try target.render(frames: 4); let b = try target.readback()
                    apply(false); _ = try target.render(frames: 4); let restored = try target.readback()
                    let noise = difference(a, aa), delta = difference(a, b), reset = difference(a, restored)
                    let stable = noise.maximum == 0 && reset.maximum == 0
                    let aColors = a.uniqueColors, bColors = b.uniqueColors
                    let aMagenta = a.magentaPixels, bMagenta = b.magentaPixels
                    let spatial = solidCullingPixelFootprint(a, b)
                    apply(integrated)
                    for (i, m) in materials.enumerated() {
                        try require(m.shaderModifiers == original[i].0 && m.lightingModel == original[i].1 &&
                            m.isDoubleSided == original[i].2 && m.cullMode == original[i].3, "H15 non-target state or restoration changed")
                    }
                    let label = "h15-\(room.rawValue)-\(Int(size.width))x\(Int(size.height))-\(style.rawValue)-\(cloth.rawValue)-\(name)"
                    let saveKey = "\(room.rawValue)-\(size)-\(style.rawValue)-\(name)"
                    let saveChangedBalls = !name.hasPrefix("changed-balls-") || ["changed-balls-0", "changed-balls-6", "changed-balls-11"].contains(name)
                    if savedPairs < 160 && saveChangedBalls && (save || delta.maximum > 1 || !stable || aColors <= 128 || bColors <= 128)
                        && savedCases.insert(saveKey).inserted {
                        attach(a, label + "-reference"); attach(b, label + "-culled"); savedPairs += 1
                        if !stable { attach(aa, label + "-aa"); attach(restored, label + "-restored") }
                    }
                    rows.append(["case": label, "room": room.rawValue, "width": Int(size.width), "height": Int(size.height),
                        "table": style.rawValue, "cloth": cloth.rawValue, "pose": name, "balls": balls,
                        "targetMaterials": solids.count, "maximumDifference": delta.maximum, "changedPixels": delta.changedPixels,
                        "aaMaximum": noise.maximum, "restoreMaximum": reset.maximum,
                        "referenceColors": aColors, "candidateColors": bColors, "referenceMagentaPixels": aMagenta,
                        "candidateMagentaPixels": bMagenta, "pixelFootprint": spatial,
                        "cameraMatrix": matrixValues(camera.presentation.worldTransform), "passed": stable && delta.maximum <= 1,
                        "strictPixelEquivalent": stable && delta.maximum <= 1])
                }
                let keys = ["cueBall"] + (1...15).map { "_\($0)" }
                for (appearanceIndex, appearance) in appearances.enumerated() {
                    let (style, cloth) = appearance
                    try require(scene.applyTableStyle(style) && scene.applyClothColor(cloth), "H15 appearance installation failed")
                    scene.hideAllBalls()
                    let ballCount = [0, 2, 16][appearanceIndex % 3]
                    for (i, key) in keys.prefix(ballCount).enumerated() {
                        scene.showBall(key: key, scenePosition: SCNVector3(Float(i / 4) * 0.6 - 0.9,
                            scene.surfaceY + AngleSceneCalculator.ballRadius, Float(i % 4) * 0.3 - 0.45))
                        try require(abs(scene.visualCenter(of: scene.allBallNodes[key]!).y - scene.surfaceY - AngleSceneCalculator.ballRadius) < 0.0001, "H15 sphere height")
                    }
                    for pose in poses {
                        try configure(pose)
                        try compare(pose.0, style: style, cloth: cloth, balls: ballCount,
                                    save: appearanceIndex == 0 || appearanceIndex % 6 == 0 && pose.0 == "oblique-front")
                    }
                    if exhaustive {
                        SCNTransaction.begin(); SCNTransaction.disableActions = true
                        scene.setCameraMode(.topDown2D, animated: false)
                        for _ in 0..<180 { rig.update(deltaTime: 1 / 60) }
                        SCNTransaction.commit(); SCNTransaction.flush()
                        try compare("2d-return", style: style, cloth: cloth, balls: ballCount)
                    }
                }
                // Same scene, restore the initial style/color and exercise direct changing sphere state.
                try require(scene.applyTableStyle(.charcoal) && scene.applyClothColor(.green), "H15 appearance return")
                try configure(poses[4]); scene.hideAllBalls()
                for frame in 0..<12 {
                    SCNTransaction.begin(); SCNTransaction.disableActions = true
                    for (i, key) in keys.enumerated() {
                        scene.showBall(key: key, scenePosition: SCNVector3(Float(i / 4) * 0.5 - 0.75 + Float(frame) * 0.01,
                            scene.surfaceY + AngleSceneCalculator.ballRadius, Float(i % 4) * 0.26 - 0.39))
                    }
                    SCNTransaction.commit(); SCNTransaction.flush()
                    try compare("changed-balls-\(frame)", style: .charcoal, cloth: .green, balls: 16)
                }
                print("[H15] \(room.rawValue) \(size) complete; \(rows.count) pairs")
            }
        }
        let rejected = rows.filter { ($0["passed"] as? Bool) != true }
        print("[H15] strict pixel-equivalence rejected \(rejected.count) of \(rows.count); separate visual review required")
        // Keep the original strict result in every row. Complete acquisition even
        // when it rejects, so a review can distinguish seams from isolated edge pixels.
        try require(rows.allSatisfy { ($0["referenceColors"] as? Int ?? 0) > 1 &&
            ($0["candidateColors"] as? Int ?? 0) > 1 && ($0["referenceMagentaPixels"] as? Int) == 0 &&
            ($0["candidateMagentaPixels"] as? Int) == 0 }, "H15 empty or shader-error frame; inspect retained originals")
        complete = true
        #endif
    }

    private func solidCullingPixelFootprint(_ a: Frame, _ b: Frame) -> [String: Any] {
        let width = a.image.cgImage!.width, height = a.image.cgImage!.height
        var hot = Set<Int>(), aboveThree = 0, aboveTen = 0, sum = 0
        for i in 0..<a.pixelCount {
            var maximum = 0
            for c in 0..<3 {
                let d = abs(Int(a.bgra[i * 4 + c]) - Int(b.bgra[i * 4 + c]))
                maximum = max(maximum, d); sum += d
            }
            if maximum > 1 { hot.insert(i) }
            if maximum > 3 { aboveThree += 1 }
            if maximum > 10 { aboveTen += 1 }
        }
        let aboveOne = hot.count
        var components: [[String: Any]] = []
        while let start = hot.first {
            hot.remove(start)
            var queue = [start], head = 0, xmin = width, xmax = 0, ymin = height, ymax = 0
            while head < queue.count {
                let p = queue[head]; head += 1
                let x = p % width, y = p / width
                xmin = min(xmin, x); xmax = max(xmax, x); ymin = min(ymin, y); ymax = max(ymax, y)
                for dy in -1...1 { for dx in -1...1 {
                    let nx = x + dx, ny = y + dy
                    if nx >= 0 && nx < width && ny >= 0 && ny < height,
                       hot.remove(ny * width + nx) != nil { queue.append(ny * width + nx) }
                } }
            }
            components.append(["pixels": queue.count, "bounds": [xmin, ymin, xmax, ymax]])
        }
        return ["pixelsAboveOne": aboveOne, "pixelsAboveThree": aboveThree, "pixelsAboveTen": aboveTen,
            "meanAbsoluteRGBByteDifference": Double(sum) / Double(a.pixelCount * 3),
            "largestComponentAboveOne": components.compactMap { $0["pixels"] as? Int }.max() ?? 0,
            "componentsAboveOne": components]
    }

    private func solidCullingReuseContract() async throws {
        let cache = TableResourceCache.shared
        try require(cache.activeScenes == 0, "H15 quality scenes must release before reuse checks")
        cache.purge(); defer { cache.purge() }
        let names: Set<String> = ["Wood", "BlackWood", "MG_Gold"]
        @MainActor func solids(_ scene: AngleTrainingScene) -> [SCNMaterial] {
            var result: [SCNMaterial] = [], seen = Set<ObjectIdentifier>()
            scene.tableNode?.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] where names.contains(m.name ?? "") && seen.insert(ObjectIdentifier(m)).inserted { result.append(m) }
            }
            return result
        }
        @MainActor func check(_ scene: AngleTrainingScene, culled: Bool) throws {
            let values = solids(scene)
            try require(Set(values.compactMap(\.name)) == names && values.allSatisfy {
                $0.isDoubleSided == !culled && $0.cullMode == .back
            }, "H15 material policy did not survive consumer lifecycle")
        }
        @MainActor func capture(_ scene: AngleTrainingScene) throws -> (culled: Frame, doubleSided: Frame, camera: [String: Any]) {
            try require(scene.applyTableStyle(.charcoal) && scene.applyClothColor(.green), "H15 reused appearance reset")
            scene.setCameraMode(.perspective3D, animated: false)
            scene.cameraNode.camera?.usesOrthographicProjection = false
            let eye = SIMD3<Float>(0, 1.05, 1.8), offset = eye - SIMD3(0, scene.surfaceY, 0)
            scene.cameraNode.simdTransform = TwoViewCamera.Pose.looking(eye: eye,
                yaw: atan2(offset.z, offset.x), pitch: -atan2(offset.y, hypot(offset.x, offset.z)), fov: 50).transform
            scene.cameraNode.camera?.fieldOfView = 50
            scene.hideAllBalls()
            scene.showBall(key: "cueBall", scenePosition: SCNVector3(0, scene.surfaceY + AngleSceneCalculator.ballRadius, 0))
            let target = try RenderTarget(device: XCTUnwrap(MTLCreateSystemDefaultDevice()), scene: scene,
                                          size: CGSize(width: 1400, height: 800))
            defer { target.renderer.scene = nil; target.renderer.delegate = nil; target.renderer.pointOfView = nil }
            SCNTransaction.flush(); _ = try target.render(frames: 4)
            let culled = try target.readback()
            var metadata = cameraMetadata(scene.cameraNode.camera!)
            metadata["worldTransform"] = matrixValues(scene.cameraNode.presentation.worldTransform)
            let materials = solids(scene)
            for m in materials { m.isDoubleSided = true }
            defer { for m in materials { m.isDoubleSided = false }; SCNTransaction.flush() }
            SCNTransaction.flush(); _ = try target.render(frames: 4)
            return (culled, try target.readback(), metadata)
        }
        var reference: (culled: Frame, doubleSided: Frame, camera: [String: Any])?, firstTable: ObjectIdentifier?
        weak var releasedScene: AngleTrainingScene?
        try autoreleasepool {
            let scene = AngleTrainingScene(); releasedScene = scene
            scene.configureReferenceTableRendering(); scene.setupScene(recipe: .liveReference, roomStyle: .tournament)
            _ = scene.addPocketMarkers()
            firstTable = ObjectIdentifier(try XCTUnwrap(scene.tableNode))
            try check(scene, culled: true); reference = try capture(scene)
            for style in TableStyle.allCases {
                try require(scene.applyTableStyle(style), "H15 theme change failed"); try check(scene, culled: true)
            }
            try require(scene.applyTableStyle(.ivory) && scene.applyClothColor(.burgundy), "H15 final theme before release")
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        try require(releasedScene == nil && cache.activeScenes == 0, "H15 scene ownership did not release")
        try require(cache.idleTable.map { ObjectIdentifier($0.node) } == firstTable, "H15 idle cache did not own the tested table")
        var maxDifference = 0, referenceMaxDifference = 0, incrementalResidual = 0
        var freshCullingDifference = 0, reusedCullingDifference = 0
        var meanDifference = 0.0, referenceMeanDifference = 0.0
        try autoreleasepool {
            let scene = AngleTrainingScene()
            scene.configureDailyClearanceRendering(asynchronousReflection: false)
            scene.setupScene(recipe: .liveReference, roomStyle: .tournament)
            try require(ObjectIdentifier(try XCTUnwrap(scene.tableNode)) == firstTable, "H15 must consume exact cached table")
            _ = scene.addPocketMarkers(); try check(scene, culled: true)
            let image = try capture(scene), a = try XCTUnwrap(reference)
            try require(NSDictionary(dictionary: a.camera).isEqual(to: image.camera), "H15 reuse compared different cameras")
            maxDifference = difference(a.culled, image.culled).maximum
            referenceMaxDifference = difference(a.doubleSided, image.doubleSided).maximum
            freshCullingDifference = difference(a.culled, a.doubleSided).maximum
            reusedCullingDifference = difference(image.culled, image.doubleSided).maximum
            var sum = 0, referenceSum = 0
            for i in a.culled.bgra.indices {
                let current = Int(a.culled.bgra[i]) - Int(image.culled.bgra[i])
                let old = Int(a.doubleSided.bgra[i]) - Int(image.doubleSided.bgra[i])
                sum += abs(current); referenceSum += abs(old)
                incrementalResidual = max(incrementalResidual, abs(current - old))
            }
            meanDifference = Double(sum) / Double(a.culled.bgra.count)
            referenceMeanDifference = Double(referenceSum) / Double(a.culled.bgra.count)
            attach(a.culled, "h15-default-fresh"); attach(image.culled, "h15-default-cache-reused")
            attach(a.doubleSided, "h15-double-sided-fresh"); attach(image.doubleSided, "h15-double-sided-cache-reused")
            attachStrictReport(["study": "H15-reuse-paired-images", "culledMaximum": maxDifference,
                "doubleSidedMaximum": referenceMaxDifference, "culledMean": meanDifference,
                "doubleSidedMean": referenceMeanDifference, "incrementalResidualMaximum": incrementalResidual,
                "freshCullingMaximum": freshCullingDifference, "reusedCullingMaximum": reusedCullingDifference,
                "sameCamera": a.camera], name: "h15-reuse-paired-images.json")
            // The established cross-renderer reuse test uses mean < 0.5, not
            // byte identity. Each matched renderer must retain the original
            // <=1-code culling bound; their drift residual is then bounded by 2.
            try require(meanDifference < 0.5 && referenceMeanDifference < 0.5 &&
                        freshCullingDifference <= 1 && reusedCullingDifference <= 1 && incrementalResidual <= 2,
                        "H15 culling adds cached appearance drift beyond the old rendering path")
            let independent = AngleTrainingScene()
            independent.configureReferenceTableRendering(); independent.setupScene(recipe: .liveReference, roomStyle: .tournament)
            try check(independent, culled: true)
            let firstMaterials = Set(solids(scene).map(ObjectIdentifier.init))
            try require(firstMaterials.isDisjoint(with: solids(independent).map(ObjectIdentifier.init)), "H15 live scenes share mutable material containers")
            let first = try XCTUnwrap(solids(scene).first)
            first.isDoubleSided = true; defer { first.isDoubleSided = false }
            try check(independent, culled: true)
            let legacy = AngleTrainingScene()
            legacy.setupScene(enhancedRendering: false, mobileRendering: false, roomStyle: .tournament)
            try check(legacy, culled: false)
            let legacyMobile = AngleTrainingScene()
            legacyMobile.setupScene(recipe: .legacyMobile, roomStyle: .tournament)
            try check(legacyMobile, culled: false)
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        try require(cache.activeScenes == 0, "H15 integration scenes leaked")
        attachStrictReport(["study": "H15-default-reuse-contract", "completed": true,
            "freshToReusedMaximumDifference": maxDifference, "sameTableIdentityReused": true,
            "doubleSidedFreshToReusedMaximumDifference": referenceMaxDifference,
            "incrementalResidualMaximum": incrementalResidual,
            "freshCullingMaximum": freshCullingDifference, "reusedCullingMaximum": reusedCullingDifference,
            "freshToReusedMeanDifference": meanDifference, "doubleSidedFreshToReusedMeanDifference": referenceMeanDifference,
            "allFiveThemeCopiesPreserveCulling": true, "liveMaterialContainersIndependent": true,
            "legacyOfflineRemainsDoubleSided": true, "activeScenesAfterRelease": cache.activeScenes],
            name: "h15-reuse-contract.json")
    }

    private func boundedPrimitive(_ source: String, group: String) throws -> String {
        if group == "cloth-strip-packed" { return try packedStripClothSamples(source) }
        if group.hasPrefix("cloth-strip") {
            return try stripClothSamples(source, width: group == "cloth-strip1" ? 1 : 2)
        }
        if group.hasPrefix("cloth-batch") {
            return try groupedClothSamples(source, width: group == "cloth-batch2" ? 2 : 4)
        }
        func replaceOnce(_ input: String, _ before: String, _ after: String) throws -> String {
            try require(input.components(separatedBy: before).count == 2, "H14 exact unique shader anchor")
            return input.replacingOccurrences(of: before, with: after)
        }
        if group == "wood-unscaled" {
            let raw = try replaceOnce(source,
                "float3 a=normalize(clipped[i]),b=normalize(clipped[(i+1)%count]);",
                "float3 a=clipped[i],b=clipped[(i+1)%count];")
            return try replaceOnce(raw,
                "float3 c=cross(a,b);float lengthC=length(c);\n        if(lengthC>0.0000001) integral+=atan2(lengthC,dot(a,b))*dot(c,n)/lengthC;",
                "float3 c=cross(a,b);float c2=dot(c,c);\n        if(c2>0.00000000000001*dot(a,a)*dot(b,b)) {float lengthC=sqrt(c2);integral+=atan2(lengthC,dot(a,b))*dot(c,n)/lengthC;}")
        }
        if group == "wood-atan" {
            // Independently generated by fit_atan.py; Float32/FMA angular error < 3e-7 radians.
            let function = """
            float h14PositiveAtan2(float y,float x) {
                float ax=abs(x);float t=min(y,ax)/max(y,ax);float u=t*t;
                float value=-0.0017437011702;
                value=fma(value,u,0.0106807192788);
                value=fma(value,u,-0.0307175088674);
                value=fma(value,u,0.0574635565281);
                value=fma(value,u,-0.083720639348);
                value=fma(value,u,0.109401986003);
                value=fma(value,u,-0.142615735531);
                value=fma(value,u,0.199982300401);
                value=fma(value,u,-0.333332836628);
                value=fma(value,u,1.0);
                float angle=t*value;
                angle=y>ax ? 1.5707963267948966-angle : angle;
                return x<0.0 ? 3.141592653589793-angle : angle;
            }

            """
            let withFunction = try replaceOnce(source, "float v62RectIrradiance(", function + "float v62RectIrradiance(")
            return try replaceOnce(withFunction, "atan2(lengthC,dot(a,b))", "h14PositiveAtan2(lengthC,dot(a,b))")
        }
        try require(group == "cloth-half-gf", "H14 unknown candidate")
        // Keep geometry, D (including its small denominator), visibility and all accumulation Float32.
        let withConstants = try replaceOnce(source, "float a2=alpha*alpha;",
            "float a2=alpha*alpha;half h14a2=half(a2),h14nv=half(nv);")
        let withG = try replaceOnce(withConstants,
            "float G=2.0*nv/(nv+sqrt(a2+(1.0-a2)*nv*nv))*2.0*nl/(nl+sqrt(a2+(1.0-a2)*nl*nl));",
            "half h14nl=half(nl);half h14G=half(2)*h14nv/(h14nv+sqrt(h14a2+(half(1)-h14a2)*h14nv*h14nv))*half(2)*h14nl/(h14nl+sqrt(h14a2+(half(1)-h14a2)*h14nl*h14nl));float G=float(h14G);")
        return try replaceOnce(withG, "float F=0.012+0.988*pow(1.0-vh,5.0);",
            "half h14F=half(0.012)+half(0.988)*pow(half(1)-half(vh),half(5));float F=float(h14F);")
    }

    private func streamedDiffuse(_ source: String) throws -> String {
        let begin = try XCTUnwrap(source.range(of: "float v62RectIrradiance("))
        let end = try XCTUnwrap(source.range(of: "float3 v62PanelDiffuse(", range: begin.upperBound..<source.endIndex))
        var program = """
        float h13RectEdge(float3 a,float3 b,float3 n) {
            a=normalize(a);b=normalize(b);
            float3 c=cross(a,b);float lengthC=length(c);
            return lengthC>0.0000001 ? atan2(lengthC,dot(a,b))*dot(c,n)/lengthC : 0.0;
        }
        float v62RectIrradiance(float3 p,float3 n,int panel) {
            float3 c=v62EmitterCenter(panel)-p,u=v62EmitterU(panel),w=v62EmitterV(panel);
            if(dot(v62EmitterNormal(panel),-c)<=0.0) return 0.0;
            float integral=0.0;float3 entry=float3(0.0),exitPoint=float3(0.0);bool crossed=false;

        """
        let corners = ["c-u-w", "c-u+w", "c+u+w", "c+u-w"]
        for i in 0..<4 {
            program += """
            {
                float3 a=\(corners[i]),b=\(corners[(i+1)%4]);
                float da=dot(a,n),db=dot(b,n);
                if(da>=0.0) {
                    if(db>=0.0) integral+=h13RectEdge(a,b,n);
                    else {
                        exitPoint=a+(b-a)*(da/(da-db));crossed=true;
                        integral+=h13RectEdge(a,exitPoint,n);
                    }
                } else if(db>=0.0) {
                    entry=a+(b-a)*(da/(da-db));
                    integral+=h13RectEdge(entry,b,n);
                }
            }

            """
        }
        program += """
            if(crossed) integral+=h13RectEdge(exitPoint,entry,n);
            return abs(integral)*0.5;
        }

        """
        var result = source
        result.replaceSubrange(begin.lowerBound..<end.lowerBound, with: program)
        return result
    }

    /// H16 research only: transpose adjacent emitter samples into vector lanes.
    /// Keep sample count, ball order and final RGB accumulation order unchanged.
    private func groupedClothSamples(_ source: String, width: Int) throws -> String {
        try require([2, 4].contains(width) &&
            ClothResearchShaders.sha256(source) == ClothShadowProgram.outputSHA256,
            "H16 requires current production C1/H9 source")
        let begin = try XCTUnwrap(source.range(of: "for(int ix=0;ix<samplesX;++ix) {"))
        let end = try XCTUnwrap(source.range(of: "E=temporalFieldDiffuse", range: begin.upperBound..<source.endIndex))
        let old = String(source[begin.lowerBound..<end.lowerBound])
        try require(old.contains("uint remainingShadowBalls=nearLampMasks[panel];") &&
                    old.contains("float4 shadowBall=contactUniforms.contactBalls[shadowIndex];"),
                    "H16 requires original ascending per-lamp blocker mask")
        let weightedStart = try XCTUnwrap(old.range(of: "float3 weighted="))
        let weightedEnd = try XCTUnwrap(old.range(of: ";\n", range: weightedStart.upperBound..<old.endIndex))
        let originalWeighted = String(old[weightedStart.lowerBound...weightedEnd.lowerBound])
        let vector = "float\(width)"
        let offsets = (0..<width).map { "\(Double($0) + 0.5)" }.joined(separator: ",")
        var body = """
        // H16: independent sample lanes; no cross-lane reduction.
        for(int ix=0;ix<samplesX;++ix) {
         for(int iz=0;iz<samplesZ;iz+=\(width)) {
          float h16U=2.0*(float(ix)+0.5)/float(samplesX)-1.0;
          \(vector) h16V=2.0*(float(iz)+\(vector)(\(offsets)))/float(samplesZ)-1.0;
          float3 h16C=v62EmitterCenter(panel),h16EU=v62EmitterU(panel),h16EV=v62EmitterV(panel);
          \(vector) dx=h16C.x+h16EU.x*h16U+h16EV.x*h16V-p.x;
          \(vector) dy=h16C.y+h16EU.y*h16U+h16EV.y*h16V-p.y;
          \(vector) dz=h16C.z+h16EU.z*h16U+h16EV.z*h16V-p.z;
          \(vector) h16R2=dx*dx+dy*dy+dz*dz;
          \(vector) h16R=sqrt(h16R2);
          \(vector) lx=dx/h16R,ly=dy/h16R,lz=dz/h16R;
          \(vector) h16Visibility=1.0;
          if(nearLampMasks[panel]!=0u) {
           uint remainingShadowBalls=nearLampMasks[panel];
           while(remainingShadowBalls!=0u) {
            uint shadowIndex=ctz(remainingShadowBalls);
            remainingShadowBalls &= remainingShadowBalls-1u;
            float4 shadowBall=contactUniforms.contactBalls[shadowIndex];
            if(shadowBall.w>0.0) {
             float3 toCenter=float3(shadowBall.x,0.8+shadowBall.z,shadowBall.y)-p;
             \(vector) t=toCenter.x*lx+toCenter.y*ly+toCenter.z*lz;
             \(vector) perpendicular2=dot(toCenter,toCenter)-t*t;
             \(vector) filterRadius=max(\(vector)(0.000001),lightCellRadius*t/h16R);
             \(vector) distanceToRay=sqrt(max(\(vector)(0.0),perpendicular2));
             \(vector) blocked=1.0-smoothstep(0.028575-filterRadius,0.028575+filterRadius,distanceToRay);
             \(vector) transmission=1.0-min(1.0,shadowBall.w/0.85)*blocked;
             h16Visibility *= select(\(vector)(1.0),transmission,(t>0.0) & (t*t<h16R2));
            }
           }
          }
          \(vector) h16NL=max(\(vector)(0.001),n.x*lx+n.y*ly+n.z*lz);
          \(vector) hx=lx+v.x,hy=ly+v.y,hz=lz+v.z;
          \(vector) h16InverseH=rsqrt(hx*hx+hy*hy+hz*hz);
          hx*=h16InverseH;hy*=h16InverseH;hz*=h16InverseH;
          \(vector) nh=max(\(vector)(0.0),n.x*hx+n.y*hy+n.z*hz);
          \(vector) vh=max(\(vector)(0.0),v.x*hx+v.y*hy+v.z*hz);
          \(vector) denom=nh*nh*(a2-1.0)+1.0;
          \(vector) h16D=a2/(3.14159265*denom*denom);
          \(vector) h16G=2.0*nv/(nv+sqrt(a2+(1.0-a2)*nv*nv))*2.0*h16NL/(h16NL+sqrt(a2+(1.0-a2)*h16NL*h16NL));
          \(vector) h16F=0.012+0.988*pow(1.0-vh,\(vector)(5.0));

        """
        for lane in 0..<width {
            body += """
              if(iz+\(lane)<samplesZ) {
               float3 l=float3(lx[\(lane)],ly[\(lane)],lz[\(lane)]);
               float r2=h16R2[\(lane)],visibility=h16Visibility[\(lane)],nl=h16NL[\(lane)];
               float D=h16D[\(lane)],G=h16G[\(lane)],F=h16F[\(lane)];
               \(originalWeighted)
               unoccludedE+=weighted; E+=weighted*visibility; S+=weighted*visibility*D*G*F/(4.0*nv*nl);
              }

            """
        }
        body += " }\n}\n}\n"
        var result = source
        result.replaceSubrange(begin.lowerBound..<end.lowerBound, with: body)
        return result
    }

    /// H16 R2 research: reject blockers outside a filtered emitter strip.
    /// World XZ / Y up; the frozen rig has U on X and V on Z.
    private func stripClothSamples(_ source: String, width: Int) throws -> String {
        try require([1, 2].contains(width) &&
                    ClothResearchShaders.sha256(source) == ClothShadowProgram.outputSHA256,
                    "H16 strip requires the frozen production rig and source")
        let anchor = "for(int ix=0;ix<samplesX;++ix) {"
        try require(source.components(separatedBy: anchor).count == 2 &&
                    source.components(separatedBy: "uint remainingShadowBalls=nearLampMasks[panel];").count == 2,
                    "H16 strip source anchors")
        let predicate = width == 1
            ? "abs(dot(h16Plane0,h16Delta))<=h16Radius"
            : "dot(h16Plane0,h16Delta)<=h16Radius && dot(h16Plane1,h16Delta)<=h16Radius"
        let planes = width == 1
            ? "float3 h16Plane0=normalize(float3(h16H,-h16X0,0.0));"
            : """
              float h16X1=h16Light.x+v62EmitterU(panel).x*(2.0*(float(ix+1)+0.5)/float(samplesX)-1.0)-p.x;
              float3 h16Plane0=normalize(float3(-h16H,h16X0,0.0));
              float3 h16Plane1=normalize(float3(h16H,-h16X1,0.0));
              """
        let replacement = """
        uint h16StripMask=nearLampMasks[panel];
        for(int ix=0;ix<samplesX;++ix) {
         if(ix%\(width)==0) {
          h16StripMask=nearLampMasks[panel];
          if(diagnosticConeEligible && h16StripMask!=0u) {
           float3 h16Light=v62EmitterCenter(panel);
           float h16H=h16Light.y-p.y;
           if(h16H>lightCellRadius) {
            float h16X0=h16Light.x+v62EmitterU(panel).x*(2.0*(float(ix)+0.5)/float(samplesX)-1.0)-p.x;
            \(planes)
            uint h16Remaining=h16StripMask;h16StripMask=0u;
            while(h16Remaining!=0u) {
             uint h16Index=ctz(h16Remaining);h16Remaining &= h16Remaining-1u;
             float4 h16Ball=contactUniforms.contactBalls[h16Index];
             float3 h16Center=float3(h16Ball.x,0.8+h16Ball.z,h16Ball.y);
             float3 h16Delta=h16Center-p;
             float h16U=clamp((h16Delta.y+0.028575+0.000001)/(h16H-lightCellRadius),0.0,1.0);
             float h16Scale=max(1.0,max(length(p),max(length(h16Center),length(h16Light))));
             float h16Radius=0.028575+0.000001+lightCellRadius*h16U+64.0*1.1920928955078125e-7*h16Scale;
             if(\(predicate)) h16StripMask |= 1u<<h16Index;
            }
           }
          }
         }
        """
        return source.replacingOccurrences(of: anchor, with: replacement)
            .replacingOccurrences(of: "uint remainingShadowBalls=nearLampMasks[panel];",
                                  with: "uint remainingShadowBalls=h16StripMask;")
    }

    /// H16 R3: form four two-row masks in a single ascending ball traversal.
    private func packedStripClothSamples(_ source: String) throws -> String {
        try require(ClothResearchShaders.sha256(source) == ClothShadowProgram.outputSHA256,
                    "H16 packed strip requires current source and fixed axis-aligned rig")
        let anchor = "for(int ix=0;ix<samplesX;++ix) {"
        try require(source.components(separatedBy: anchor).count == 2 &&
                    source.components(separatedBy: "uint remainingShadowBalls=nearLampMasks[panel];").count == 2,
                    "H16 packed strip anchors")
        let replacement = """
        uint4 h16StripMasks=uint4(nearLampMasks[panel]);
        if(diagnosticConeEligible && nearLampMasks[panel]!=0u) {
         float3 h16Light=v62EmitterCenter(panel);
         float h16H=h16Light.y-p.y;
         if(h16H>lightCellRadius) {
          float4 h16X0=h16Light.x+v62EmitterU(panel).x*(2.0*float4(0.5,2.5,4.5,6.5)/float(samplesX)-1.0)-p.x;
          float4 h16X1=h16Light.x+v62EmitterU(panel).x*(2.0*float4(1.5,3.5,5.5,7.5)/float(samplesX)-1.0)-p.x;
          float4 h16Inv0=rsqrt(h16H*h16H+h16X0*h16X0);
          float4 h16Inv1=rsqrt(h16H*h16H+h16X1*h16X1);
          float4 h16NX0=-h16H*h16Inv0,h16NY0=h16X0*h16Inv0;
          float4 h16NX1=h16H*h16Inv1,h16NY1=-h16X1*h16Inv1;
          uint h16Remaining=nearLampMasks[panel];h16StripMasks=uint4(0u);
          while(h16Remaining!=0u) {
           uint h16Index=ctz(h16Remaining);h16Remaining &= h16Remaining-1u;
           float4 h16Ball=contactUniforms.contactBalls[h16Index];
           float3 h16Center=float3(h16Ball.x,0.8+h16Ball.z,h16Ball.y),h16Delta=h16Center-p;
           float h16U=clamp((h16Delta.y+0.028575+0.000001)/(h16H-lightCellRadius),0.0,1.0);
           float h16Scale=max(1.0,max(length(p),max(length(h16Center),length(h16Light))));
           float h16Radius=0.028575+0.000001+lightCellRadius*h16U+64.0*1.1920928955078125e-7*h16Scale;
           bool4 h16Inside=(h16NX0*h16Delta.x+h16NY0*h16Delta.y<=h16Radius) &
                           (h16NX1*h16Delta.x+h16NY1*h16Delta.y<=h16Radius);
           h16StripMasks |= select(uint4(0u),uint4(1u<<h16Index),h16Inside);
          }
         }
        }
        for(int ix=0;ix<samplesX;++ix) {
        """
        return source.replacingOccurrences(of: anchor, with: replacement)
            .replacingOccurrences(of: "uint remainingShadowBalls=nearLampMasks[panel];",
                                  with: "uint remainingShadowBalls=h16StripMasks[ix/2];")
    }

    private func runNativeMaterialStudy(vertexDiffuse: Bool, streamingDiffuse: Bool = false,
                                        primitiveCandidates: [String] = []) throws {
        let primitiveStudy = !primitiveCandidates.isEmpty
        let groupedStudy = primitiveCandidates.contains { $0.hasPrefix("cloth-batch") || $0.hasPrefix("cloth-strip") }
        #if targetEnvironment(simulator)
        throw XCTSkip("H13 requires native Designed for iPad execution")
        #else
        guard ProcessInfo.processInfo.isiOSAppOnMac else {
            throw XCTSkip("H13 is restricted to the authorized native Mac")
        }
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        var rows: [[String: Any]] = [], cpuRows: [[String: Any]] = [], inventory: [[String: Any]] = []
        var complete = false
        defer {
            attachStrictReport(["study": primitiveStudy ? "\(groupedStudy ? "H16" : "H14")-\(primitiveCandidates.joined(separator: "+"))" : streamingDiffuse ? "H13-streaming-diffuse-candidate" :
                (vertexDiffuse ? "H13-vertex-diffuse-candidate" : "H13-current-production-cost"), "device": device.name,
                "completed": complete && testRun?.totalFailureCount == 0,
                "rows": rows, "cpuRows": cpuRows, "inventory": inventory,
                "scope": primitiveStudy ? "Native current production scene; independent shader arithmetic candidates: \(primitiveCandidates.joined(separator: ",")); original clipping and per-pixel shading retained; maximum added image difference 1/255; no page/phone claim" : streamingDiffuse ? "Native current scene; streaming exact clipped rectangle edges; per-pixel normal and all original shading retained; no page/phone claim" : vertexDiffuse
                    ? "Native current scene; vertex diffuse approximation; maximum new image error 1/255 before timing; no full page or phone claim"
                    : "Native iOS production scene, no SwiftUI page/physical shot/phone; diagnostic cheap shaders are intentionally not equivalent; deltas are nonadditive",
                "timing": "6 AA/AB groups; alternating ABBA/BAAB; 24 frames per arm per group; raw per-frame timestamps; no trimmed samples"],
                name: primitiveStudy ? "\(groupedStudy ? "h16" : "h14")-\(primitiveCandidates.joined(separator: "-" )).json" : streamingDiffuse ? "h13-streaming-diffuse.json" :
                    (vertexDiffuse ? "h13-vertex-diffuse-cpu.json" : "h13-current-material-cpu.json"))
        }
        let size = CGSize(width: 1400, height: 800)
        for pose in ["low", "near", "overview"] {
            try autoreleasepool {
                let scene = AngleTrainingScene()
                scene.configureDailyClearanceRendering(asynchronousReflection: false)
                scene.setupScene(recipe: .liveReference, roomStyle: .tournament)
                try require(scene.applyClothColor(.green) && scene.applyTableStyle(.charcoal), "H13 appearance missing")
                scene.hideAllBalls()
                let keys = ["cueBall"] + (1...15).map { "_\($0)" }
                let activeKeys = Array(keys.prefix(pose == "overview" ? 16 : 2))
                for (i, key) in activeKeys.enumerated() {
                    let x = pose == "overview" ? Float(i / 4) * 0.6 - 0.9 : Float(i) * 0.05715
                    let z = pose == "overview" ? Float(i % 4) * 0.3 - 0.45 : 0
                    scene.showBall(key: key, scenePosition: SCNVector3(x, scene.surfaceY + AngleSceneCalculator.ballRadius, z))
                }
                for key in activeKeys {
                    let node = try XCTUnwrap(scene.allBallNodes[key])
                    try require(abs(scene.visualCenter(of: node).y - scene.surfaceY - AngleSceneCalculator.ballRadius) < 0.0001,
                                "H13 production ball center height")
                }
                let rig = try XCTUnwrap(scene.cameraRig)
                if vertexDiffuse { rig.configurePlayerCameraControls(daily: true) }
                rig.viewportSize = size
                scene.setCameraMode(.perspective3D, animated: false)
                try require(rig.observeWholeTable(yaw: .pi / 2), "H13 camera controller setup")
                for _ in 0..<180 { rig.update(deltaTime: 1 / 60) }
                if vertexDiffuse { try require(rig.usesTwoViewPoseControl, "H13 CPU must enter current camera policy") }
                // Measure actual stable maintenance without adding a live display link.
                let window = UIWindow(frame: CGRect(origin: .zero, size: size))
                let view = SCNView(frame: window.bounds)
                window.addSubview(view)
                let coordinator = AngleSceneView.Coordinator(scene: scene, cameraMode: .perspective3D,
                                                             interactionMode: .cameraControl)
                coordinator.scnView = view
                coordinator.twoViewReadableFrameInWindow = window.bounds.insetBy(dx: 24, dy: 30)
                coordinator.updateViewport(size)
                var cameraTimes: [Double] = [], viewportTimes: [Double] = []
                for _ in 0..<12 {
                    var start = CACurrentMediaTime()
                    for _ in 0..<240 { rig.update(deltaTime: 1 / 60) }
                    cameraTimes.append((CACurrentMediaTime() - start) * 1000 / 240)
                    start = CACurrentMediaTime()
                    for _ in 0..<240 { coordinator.updateViewport(size) }
                    viewportTimes.append((CACurrentMediaTime() - start) * 1000 / 240)
                }
                cpuRows.append(["pose": pose, "stableCameraUpdateMS": cameraTimes,
                                "stableViewportUpdateMS": viewportTimes, "callsPerGroup": 240,
                                "usesTwoViewPoseControl": rig.usesTwoViewPoseControl])
                coordinator.scnView = nil
                let camera = try XCTUnwrap(scene.cameraNode)
                camera.simdPosition = pose == "near" ? SIMD3(0.16, 1.15, 0.3)
                    : (pose == "low" ? SIMD3(0, 1.05, 1.8) : SIMD3(1.8, 2.7, 2.1))
                if groupedStudy {
                    let eye = camera.simdPosition, offset = eye - SIMD3(0, scene.surfaceY, 0)
                    let view = TwoViewCamera.Pose.looking(eye: eye, yaw: atan2(offset.z, offset.x),
                        pitch: -atan2(offset.y, hypot(offset.x, offset.z)), fov: 50)
                    camera.simdTransform = view.transform
                    try require(abs(camera.simdWorldTransform.columns.0.y) < 0.00001 &&
                                simd_length(view.forward - simd_normalize(-offset)) < 0.00001,
                                "H16 must use a verified horizontal production camera transform")
                } else { camera.simdLook(at: SIMD3(0, scene.surfaceY, 0)) }
                camera.camera?.fieldOfView = 50
                let balls = Set(scene.allBallNodes.values.map(ObjectIdentifier.init))
                var groups: [String: [SCNMaterial]] = [:], seen: [ObjectIdentifier: String] = [:]
                var slotCounts: [String: Int] = [:]
                @MainActor func visit(_ node: SCNNode, owner inherited: String?) throws {
                    let owner = balls.contains(ObjectIdentifier(node)) ? "balls"
                        : (node.name == "reference_room" ? "room" : inherited)
                    for material in node.geometry?.materials ?? [] {
                        let group = owner ?? (["TaiNi": "cloth", "Wood": "wood", "BlackWood": "wood",
                                               "Leather": "leather", "MG_Gold": "legs"][material.name ?? ""] ?? "other")
                        slotCounts[group, default: 0] += 1
                        let id = ObjectIdentifier(material)
                        if let previous = seen[id] {
                            try require(previous == group, "Material shared across diagnostic groups")
                        } else {
                            seen[id] = group
                            groups[group, default: []].append(material)
                        }
                    }
                    for child in node.childNodes { try visit(child, owner: owner) }
                }
                try visit(scene.rootNode, owner: nil)
                let cloth = try XCTUnwrap(groups["cloth"]?.first)
                inventory.append(["pose": pose, "materialCounts": groups.mapValues(\.count), "geometryMaterialSlots": slotCounts,
                    "clothSHA256": ClothResearchShaders.sha256(cloth.shaderModifiers?[.surface] ?? ""),
                    "surfaceSHAs": groups.mapValues { $0.map { ClothResearchShaders.sha256($0.shaderModifiers?[.surface] ?? "") } },
                    "materialRasterState": groups.mapValues { $0.map { ["name": $0.name ?? "", "doubleSided": $0.isDoubleSided,
                        "cullMode": $0.cullMode.rawValue, "depthRead": $0.readsFromDepthBuffer,
                        "depthWrite": $0.writesToDepthBuffer, "transparency": $0.transparency] as [String: Any] } },
                    "activeBalls": activeKeys, "hdr": camera.camera?.wantsHDR ?? false])
                try require(ClothResearchShaders.sha256(cloth.shaderModifiers?[.surface] ?? "") ==
                            "14a880284fffc793f01d0357b0a625559101609d7986c9ac0cac72e7085efa4f",
                            "H13 must use installed current C1/H9")
                if groupedStudy {
                    try require(((groups["wood"] ?? []) + (groups["legs"] ?? [])).allSatisfy {
                        !$0.isDoubleSided && $0.cullMode == .back
                    }, "H16 baseline must include the accepted H15 culling")
                }
                for m in groups["balls"] ?? [] {
                    let program = m.shaderModifiers?[.surface] ?? ""
                    try require(program.contains("float3 spec=v2FilteredReflection(filteredRoom,") &&
                                program.contains("reflectionResponse.sample(responseSampler,") &&
                                m.value(forKey: "filteredRoom") != nil && m.value(forKey: "reflectionResponse") != nil,
                                "H13 requires actual R ball installation and bound resources")
                }
                for group in ["wood", "leather", "legs"] {
                    let materials = groups[group] ?? []
                    try require(!materials.isEmpty && materials.allSatisfy { $0.lightingModel == .constant },
                                "Missing current production finish: \(group)")
                }
                let target = try RenderTarget(device: device, scene: scene, size: size)
                let delegate = StageCostDelegate(); delegate.contact = scene.contactOcclusion
                target.renderer.delegate = delegate
                SCNTransaction.flush()
                try require(target.renderer.prepare(scene, shouldAbortBlock: nil), "H13 prepare failed")
                _ = try target.render(frames: 6)
                attach(try target.readback(), "h13-\(pose)-production-baseline")
                // Actual callback costs, with and without changed ball positions.
                for changing in [false, true] {
                    _ = delegate.take()
                    var frames: [[String: Any]] = []
                    let initial = activeKeys.map { scene.allBallNodes[$0]!.simdPosition }
                    for frame in 0..<96 {
                        if changing {
                            SCNTransaction.begin(); SCNTransaction.disableActions = true
                            for (i, key) in activeKeys.enumerated() {
                                scene.allBallNodes[key]!.simdPosition = initial[i] + SIMD3(Float(frame % 6) * 0.002, 0, 0)
                            }
                            SCNTransaction.commit(); SCNTransaction.flush()
                        }
                        frames += try target.render(frames: 1, includeNativeTiming: true).perFrameTiming
                    }
                    cpuRows.append(["pose": pose, "changingBallState": changing, "frames": frames, "callbacks": delegate.take()])
                    for (i, key) in activeKeys.enumerated() { scene.allBallNodes[key]!.simdPosition = initial[i] }
                    SCNTransaction.flush(); _ = try target.render(frames: 3)
                }
                for group in primitiveStudy ? primitiveCandidates : streamingDiffuse ? ["wood-legs"] : vertexDiffuse ? ["legs", "wood"] : ["cloth", "balls", "wood", "leather", "legs", "room"] {
                    let culling = group.hasSuffix("-cull")
                    let materials = group == "solid-cull" ? (groups["wood"] ?? []) + (groups["legs"] ?? [])
                        : culling ? (groups[String(group.dropLast(5))] ?? [])
                        : streamingDiffuse || group.hasPrefix("wood-") ? (groups["legs"] ?? []) + (groups["wood"] ?? []) : (groups[primitiveStudy ? "cloth" : group] ?? [])
                    let originals = materials.map { ($0.shaderModifiers, $0.lightingModel, $0.isDoubleSided, $0.cullMode) }
                    if culling { try require(!materials.isEmpty && originals.allSatisfy { $0.2 }, "H14 culling must change actual production raster state") }
                    let streamingPrograms = try (streamingDiffuse || primitiveStudy) && !culling ? originals.map { original -> [SCNShaderModifierEntryPoint: String] in
                        var program = original.0 ?? [:]
                        let surface = try XCTUnwrap(program[.surface])
                        program[.surface] = try primitiveStudy ? boundedPrimitive(surface, group: group) : streamedDiffuse(surface)
                        return program
                    } : []
                    let vertexProgram = """
                    #pragma varyings
                    float3 h13PanelDiffuseValue;
                    #pragma declaration
                    """ + "\n" + MobileReferenceLighting.analyticPanelDiffuse.replacingOccurrences(of: "v62", with: "h13") + """

                    #pragma body
                    float3 h13P=(scn_node.modelTransform*_geometry.position).xyz;
                    float3 h13N=normalize((scn_frame.inverseViewTransform*scn_node.normalTransform*float4(_geometry.normal,0.0)).xyz);
                    out.h13PanelDiffuseValue=h13PanelDiffuse(h13P,h13N);
                    """
                    if vertexDiffuse && !primitiveStudy {
                        for original in originals {
                            try require(original.0?[.geometry] == nil &&
                                original.0?[.surface]?.contains("v62PanelDiffuse(p,n)") == true,
                                "H13 vertex candidate requires exact original consumer")
                        }
                    }
                    func apply(_ cheap: Bool) {
                        for (i, material) in materials.enumerated() {
                            if culling {
                                material.isDoubleSided = cheap ? false : originals[i].2
                                material.cullMode = cheap ? .back : originals[i].3
                                continue
                            }
                            if vertexDiffuse {
                                var program = originals[i].0 ?? [:]
                                if cheap {
                                    if streamingDiffuse || primitiveStudy { program = streamingPrograms[i] }
                                    else {
                                        program[.geometry] = vertexProgram
                                        program[.surface] = program[.surface]!.replacingOccurrences(
                                            of: "v62PanelDiffuse(p,n)", with: "in.h13PanelDiffuseValue")
                                    }
                                }
                                material.shaderModifiers = program
                                continue
                            }
                            material.lightingModel = cheap ? .constant : originals[i].1
                            material.shaderModifiers = cheap
                                ? [.fragment: "#pragma body\n_output.color=float4(0.3,0.05,0.3,1.0);"]
                                : originals[i].0
                        }
                        SCNTransaction.flush()
                    }
                    defer { apply(false) }
                    apply(false); _ = try target.render(frames: 4); let a = try target.readback()
                    _ = try target.render(frames: 1); let aa = try target.readback()
                    apply(true); _ = try target.render(frames: 4); let b = try target.readback()
                    apply(false); _ = try target.render(frames: 4); let restored = try target.readback()
                    let noise = difference(a, aa), delta = difference(a, b), restoration = difference(a, restored)
                    if groupedStudy {
                        try require(a.magentaPixels == 0 && b.magentaPixels == 0 && a.uniqueColors > 16 && b.uniqueColors > 16,
                                    "H16 requires actual visible shader output without SceneKit errors")
                    }
                    try require(noise.maximum == 0 && restoration.maximum == 0, "H13 AA/restoration drift")
                    attach(b, "h13-\(pose)-\(group)-cheap-diagnostic")
                    var times: [[String: Any]] = []
                    var warmups: [[String: Any]] = []
                    if vertexDiffuse ? delta.maximum <= 1 : delta.changedPixels > 0 {
                        for kind in ["AA", "AB"] {
                            if group == "cloth-strip-packed" {
                                apply(false)
                                let warmup = try target.render(frames: 120, includeNativeTiming: true)
                                warmups.append(["kind": kind, "frames": warmup.perFrameTiming])
                                _ = delegate.take()
                            }
                            for cycle in 0..<6 {
                                for arm in cycle % 2 == 0 ? [false, true, true, false] : [true, false, false, true] {
                                    try require(ProcessInfo.processInfo.thermalState != .serious &&
                                                ProcessInfo.processInfo.thermalState != .critical, "H13 thermal limit")
                                    apply(kind == "AB" && arm)
                                    _ = try target.render(frames: 3); _ = delegate.take()
                                    let timing = try target.render(frames: 12, includeNativeTiming: true)
                                    times.append(["kind": kind, "cycle": cycle, "arm": arm ? "B" : "A",
                                                  "frames": timing.perFrameTiming, "callbacks": delegate.take()])
                                }
                            }
                        }
                    }
                    rows.append(["pose": pose, "group": group, "materials": materials.count,
                                 "variant": primitiveStudy ? group : streamingDiffuse ? "streaming-diffuse" : (vertexDiffuse ? "vertex-diffuse" : "cheap-diagnostic"),
                                 "qualityPassed": !vertexDiffuse || delta.maximum <= 1,
                                 "changedPixels": delta.changedPixels, "maximumChannelDifference": delta.maximum,
                                 "aaMaximum": noise.maximum, "restoreMaximum": restoration.maximum, "times": times,
                                 "fixedWarmupFramesBeforeEachKind": group == "cloth-strip-packed" ? 120 : 0,
                                 "warmups": warmups])
                    print("[H13] \(pose) \(group) visiblePixels=\(delta.changedPixels) complete")
                }
            }
        }
        complete = true
        #endif
    }
    #endif

    func testProductionSceneHeightSafeSupportGPUComparison() throws {
        try compareProductionScene(installedGuard: nil)
    }

    #if DEBUG
    func testProductionInstalledGuardComboFullSceneImageEquality() throws {
        // Read the program from a separately configured production scene. No
        // external surface file or test-side guard shader builder is used here.
        let installed = try productionInstalledGuardProgram()
        try compareProductionScene(installedGuard: installed)
    }

    func testNativeProductionGuardComboGPUComparison() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Native Mac GPU study requires the Designed for iPad host, not Simulator")
        #else
        guard ProcessInfo.processInfo.isiOSAppOnMac else {
            throw XCTSkip("This explicit selector is restricted to native Designed for iPad execution on Mac")
        }
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let calibration = try calibrateNativeGPU(device: device)
        let installed = try productionInstalledGuardProgram()
        try compareProductionScene(installedGuard: installed, nativeMacCalibration: calibration)
        #endif
    }

    /// R23: one real break, including production pocket/rail actions and spin tail.
    /// Only explicit native selection runs this study. No user page or saved board is touched.
    func testNativeProductionGuardComboDynamicBreakComparison() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Dynamic native study requires Designed for iPad on Mac")
        #else
        guard ProcessInfo.processInfo.isiOSAppOnMac else {
            throw XCTSkip("Dynamic native study is restricted to the authorized Mac host")
        }
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let calibration = try calibrateNativeGPU(device: device)
        let installed = try productionInstalledGuardProgram()
        try autoreleasepool {
            try compareNativeDynamicBreak(caseID: "spin-tail", seed: 1972274182705165791,
                requiresPocket: false, requiresSpinTail: true, device: device, calibration: calibration, installed: installed)
        }
        try autoreleasepool {
            try compareNativeDynamicBreak(caseID: "pocket-rail", seed: 1180286254055038828,
                requiresPocket: true, requiresSpinTail: false, device: device, calibration: calibration, installed: installed)
        }
        #endif
    }

    private final class DynamicClockReceipt: @unchecked Sendable {
        private let lock = NSLock()
        private var samples: [Double] = []
        func append(_ value: Double) { lock.lock(); samples.append(value); lock.unlock() }
        func read() -> [Double] { lock.lock(); defer { lock.unlock() }; return samples }
    }

    private func compareNativeDynamicBreak(caseID: String, seed: UInt64,
                                           requiresPocket: Bool, requiresSpinTail: Bool,
                                           device: MTLDevice, calibration: [String: Any],
                                           installed: InstalledGuardProgram) throws {
        var report: [String: Any] = [
            "schema": 1, "study": "native-production-dynamic-break-r23",
            "caseID": caseID, "requiresPocket": requiresPocket, "requiresSpinTail": requiresSpinTail,
            "executionPlatform": "MacNative-isiOSAppOnMac", "device": device.name,
            "gpuCalibration": calibration, "installedProgram": installed.metadata,
            "resolution": [1400, 800], "sampleHz": 60,
            "harness": "same-timestamp-production-actions-r14",
            "scope": "Complete real production break actions at consecutive 60 Hz timestamps. Each actual frame is rendered R/guard/repeat/restore at the same timestamp without writing ball or rail transforms. Same R room reflection probe. No SwiftUI page, presentation FPS, probe generation, physics-solve cost or action-scheduling performance claim.",
            "timingScope": "Nine trajectory state anchors, each nine ABBA/BAAB cycles of six synchronous frames per slot, with equal two-frame post-switch warmup. Direct scene-render cost at real dynamic states, not a continuous real-time playback benchmark. Readback, state verification, compilation and CPU physics/action updates are outside GPU spans.",
            "imageRetention": "Streaming SHA/strict RGBA comparison; only selected keyframes and failures become PNG attachments. Only current and previous images are retained transiently; no pose history or static-room copies.",
            "completed": false, "performanceRankingAllowed": false
        ]
        var qualityRows: [[String: Any]] = [], timingRows: [[String: Any]] = []
        var completed = false
        defer {
            report["qualityFrames"] = qualityRows; report["timingAnchors"] = timingRows
            report["recordedXCTestFailureCount"] = testRun?.totalFailureCount ?? -1
            report["completed"] = completed && testRun?.totalFailureCount == 0
            report["performanceRankingAllowed"] = completed && testRun?.totalFailureCount == 0
            attachStrictReport(report, name: "cloth-native-dynamic-break-\(caseID).json")
        }
        let scene = AngleTrainingScene()
        scene.configureDailyClearanceRendering(asynchronousReflection: false)
        scene.configureClothSupportExperiment(request: .off)
        scene.setupScene(mobileRendering: true, roomStyle: .tournament)
        try require(scene.renderingProfile == .reflection && !scene.mergesDailyClothSupport
                    && !scene.factorsDailyClothBRDF, "Dynamic baseline must retain production R")
        try require(scene.applyClothColor(.green) && scene.applyTableStyle(.charcoal), "Missing production appearance")
        scene.railInventory.watchesBoard = false // Offline playback uses the production absolute rail clock, not a wall timer.
        scene.railInventory.clear()
        scene.hideAllBalls()
        // Both seeds come from existing real-break regressions; no favorable-case search.
        let rack = RackLayout.make(.chineseEightBall, seed: seed, surfaceY: scene.surfaceY)
        scene.showBall(key: "cueBall", scenePosition: rack.cue)
        for ball in rack.balls { scene.showBall(key: ball.key, scenePosition: ball.position) }
        let keys = scene.allBallNodes.keys.sorted()
        try require(keys.count == 16, "Dynamic break must begin with all 16 production balls")
        let sourceNodes = keys.map { scene.allBallNodes[$0]! }
        let identities = sourceNodes.map(ObjectIdentifier.init)
        let contact = try XCTUnwrap(scene.contactOcclusion)
        try require(contact.capacity == 16, "Dynamic contact capacity must remain 16")
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.viewportSize = CGSize(width: 1400, height: 800)
        scene.setCameraMode(.perspective3D, animated: false)
        try require(rig.observeWholeTable(yaw: .pi / 2), "Dynamic overview unavailable")
        for _ in 0..<180 { rig.update(deltaTime: 1/60) }
        let camera = try XCTUnwrap(scene.cameraNode)
        let cameraTransform = camera.transform
        var seen = Set<ObjectIdentifier>()
        var materials: [(SCNMaterial, [SCNShaderModifierEntryPoint: String])] = []
        scene.rootNode.enumerateHierarchy { node, _ in
            for material in node.geometry?.materials ?? []
            where material.name == "TaiNi" && seen.insert(ObjectIdentifier(material)).inserted {
                materials.append((material, material.shaderModifiers ?? [:]))
            }
        }
        try require(!materials.isEmpty, "Dynamic scene has no TaiNi materials")
        for (material, original) in materials {
            try require(ClothResearchShaders.sha256(original[.surface] ?? "") == "9495698875cd01a4ecd8d00708ce88bf9989c6e118805620f99a11d03dcca390"
                        && abs(material.normal.intensity - 0.65) < 0.00001, "Dynamic R material/source drift")
        }
        func install(_ variant: String) {
            for (material, original) in materials {
                var modifiers = original
                if variant == "candidate" { modifiers[.surface] = installed.surface }
                if variant == "red-control" {
                    modifiers[.fragment] = (modifiers[.fragment] ?? "#pragma body") + "\n_output.color.rgb=float3(1,0,0);\n"
                }
                material.shaderModifiers = modifiers
            }
            SCNTransaction.flush()
        }
        defer { install("reference"); scene.railInventory.clear() }
        let target = try RenderTarget(device: device, scene: scene, size: CGSize(width: 1400, height: 800))
        try require(target.renderer.prepare(scene, shouldAbortBlock: nil), "Dynamic SceneKit prepare failed")
        var renderClock = 1.0
        func render(_ count: Int = 1, at time: Double? = nil) throws -> BatchTiming {
            try require(ProcessInfo.processInfo.thermalState != .serious && ProcessInfo.processInfo.thermalState != .critical
                        && UIApplication.shared.applicationState == .active, "Native dynamic host/thermal gate failed")
            if let time { renderClock = time } else { renderClock += 1.0/60.0 }
            return try target.render(frames: count, includeNativeTiming: true, atTime: renderClock)
        }
        func identity(_ variant: String) throws {
            try require(scene.contactOcclusion === contact && contact.capacity == 16
                        && keys.map { ObjectIdentifier(scene.allBallNodes[$0]!) } == identities,
                        "Ball/contact identity or capacity changed as balls left the cloth")
            try require(SCNMatrix4EqualToMatrix4(camera.transform, cameraTransform)
                        && scene.clothSupportRequest == .off && !scene.safeClothSupportState.effective,
                        "Dynamic scene must keep its R camera/probe recipe")
            var current = Set<ObjectIdentifier>()
            scene.rootNode.enumerateHierarchy { node, _ in
                for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                    current.insert(ObjectIdentifier(material))
                }
            }
            try require(current == seen, "Cloth material identities changed")
            for (material, original) in materials {
                try require(material.shaderModifiers?[.surface] == (variant == "candidate" ? installed.surface : original[.surface])
                            && material.shaderModifiers?[.geometry] == original[.geometry], "Dynamic installed surface/geometry drift")
            }
        }
        func uniforms() throws -> Data {
            let data = try XCTUnwrap(materials[0].0.value(forKey: "contactUniforms") as? Data)
            try require(data.count == 16 * MemoryLayout<SIMD4<Float>>.stride, "Unexpected packed contact layout")
            for (material, _) in materials {
                try require(material.value(forKey: "contactUniforms") as? Data == data, "Contact material bindings disagree")
            }
            let actual = data.withUnsafeBytes { bytes in
                (0..<64).map { bytes.loadUnaligned(fromByteOffset: $0 * 4, as: Float.self) }
            }
            for (index, node) in sourceNodes.enumerated() {
                let rendered = node.presentation, p = rendered.worldPosition
                let h = p.y - scene.surfaceY, radius = AngleSceneCalculator.ballRadius
                let w: Float = node.isHidden || node.parent == nil ? 0
                    : MobileContactOcclusion.encodedOpacityScale * Float(rendered.opacity) * min(1, max(0, h / radius))
                let expected: [Float] = [p.x, p.z, max(radius, h), w]
                // Match production's Float equality (which intentionally treats +0/-0 alike).
                try require((0..<4).allSatisfy { actual[index*4+$0] == expected[$0] },
                            "Contact uniform does not match this frame's presentation ball: \(keys[index])")
                if node.isHidden || node.parent == nil || h <= 0 || rendered.opacity == 0 {
                    try require(actual[index*4+3] == 0, "Pocketed/hidden source retained nonzero cloth shadow weight")
                }
            }
            return data
        }
        func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        func imageDigest(_ frame: Frame) -> String { digest(Data(frame.bgra)) }
        _ = try render(8)

        // Public render(atTime:) supplies system time, not an action-seeking API.
        // Prove the actual customAction clock before trusting any physics frame.
        let clockProbe = DynamicClockReceipt(), clockNode = SCNNode()
        scene.rootNode.addChildNode(clockNode)
        target.renderer.isPlaying = true
        clockNode.runAction(.customAction(duration: 1) { _, elapsed in clockProbe.append(Double(elapsed)) })
        SCNTransaction.flush() // Commit action registration before this synchronous offscreen loop.
        let clockOrigin = renderClock
        for index in 0..<3 { _ = try render(at: clockOrigin + Double(index)/60) }
        let clockSamples = clockProbe.read()
        report["actionClockProbe"] = clockSamples
        clockNode.removeAllActions(); clockNode.removeFromParentNode()
        try require(clockSamples.count == 3 && zip(clockSamples, [0.0, 1.0/60, 2.0/60]).allSatisfy { abs($0.0-$0.1) < 0.00001 },
                    "SCNAction clock is not the requested 60 Hz timeline; stop, do not substitute partial motion")

        // Prepare all three programs before installing real motion; no action seeks or pose resets.
        install("reference"); _ = try render(8)
        let initial = try target.readback()
        install("red-control"); _ = try render(4)
        let red = try target.readback(); attach(red, "cloth-dynamic-\(caseID)-red-control")
        try require(red.redPixels > initial.redPixels + initial.pixelCount/100, "Dynamic installed cloth red control ineffective")
        report["redControlChangedPixels"] = difference(initial, red).changedPixels
        install("candidate"); _ = try render(8)
        install("reference"); _ = try render(4)

        let result = BreakSimulator.breakShot(rack: rack, power: 10)
        report["physics"] = ["seed": String(seed), "power": 10, "termination": String(describing: result.termination),
                              "duration": result.recorder.duration, "pocketed": result.pocketed]
        try require(result.settled, "Real break must settle; do not replace with synthetic motion")
        if requiresPocket { try require(!result.pocketed.isEmpty, "Pocket/rail fixture must contain actual pockets") }
        func physicsDigest() throws -> String {
            var hasher = SHA256()
            for name in result.recorder.framesByBallName.keys.sorted() {
                let values = result.recorder.framesByBallName[name]!.map { frame -> [String: Any] in
                    ["time": frame.time, "position": [frame.position.x, frame.position.y, frame.position.z],
                     "velocity": [frame.velocity.x, frame.velocity.y, frame.velocity.z],
                     "omega": [frame.angularVelocity.x, frame.angularVelocity.y, frame.angularVelocity.z, frame.angularVelocity.w],
                     "state": String(describing: frame.state)]
                }
                hasher.update(data: try JSONSerialization.data(withJSONObject: ["name": name, "frames": values], options: [.sortedKeys]))
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }
        let originalPhysicsSHA = try physicsDigest()
        report["physicsFramesSHA256"] = originalPhysicsSHA
        report["physicsSolveCount"] = 1
        let playback = TrajectoryPlayback(recorder: result.recorder,
            surfaceY: scene.surfaceY + AngleSceneCalculator.ballRadius, railInventory: scene.railInventory)
        let spinTail = playback.finalBreakSpinTail()
        if requiresSpinTail { try require(spinTail != nil, "Spin-tail fixture must exercise its known production spin tail") }
        if let spinTail { report["spinTail"] = ["ball": spinTail.ballName, "start": spinTail.start, "end": spinTail.end, "displayEnd": spinTail.displayEnd] }
        for (key, node) in zip(keys, sourceNodes) {
            if let action = playback.action(for: node, ballName: key, removeOnPocket: false,
                                           breakSpinTail: key == spinTail?.ballName ? spinTail : nil) {
                node.runAction(action, forKey: "cloth-research-real-break")
            }
        }
        SCNTransaction.flush() // Includes production action registration and its newly bound rail clones.
        // All incoming clones are bound by the production action construction, before frame zero.
        let railNodes = scene.rootNode.childNodes.filter { $0.name?.hasSuffix("#rail") == true }.sorted { ($0.name ?? "") < ($1.name ?? "") }
        let nodes = sourceNodes + railNodes
        let nodeIDs = Set(nodes.map(ObjectIdentifier.init))
        let names = nodes.map { $0.name ?? "unnamed" }
        if !result.pocketed.isEmpty { try require(!railNodes.isEmpty, "Real pocket rail clones were not created") }
        let displayEnd = Double(spinTail?.displayEnd ?? playback.duration)
        let railEnd = playback.railShot?.timeline.railMotionEnd ?? 0
        let finishPadding = spinTail == nil ? TrajectoryPlayback.pocketSettleDuration + 0.15 : 0.0
        let end = max(displayEnd + finishPadding, railEnd, Double(playback.collectionPresentationEnd))
        try require(end.isFinite && end > 0 && end < 120, "Unbounded or invalid complete break timeline")
        let frameCount = Int(ceil(end*60)) + 2 // One real 60 Hz frame after production rail completion.
        report["timeline"] = ["displayEnd": displayEnd, "railMotionEnd": railEnd,
                              "requiredMotionEnd": end, "completeEnd": Double(frameCount-1)/60,
                              "frameCount": frameCount, "nodes": names,
                              "origin": "Production actions created once; monotonic render time. Live spin-tail mapping is retained. Full pocket/rail completion is included; no re-solve, re-attach, or action seek."]
        let actionOrigin = renderClock
        report["timelineMode"] = "One monotonic production action run; repeated draws use the same exact timestamp. No transform assignment, action re-creation or clock rewind."
        var stateHasher = SHA256(), captureHashes: [String] = []
        var sawPocketWeightZero = Set<String>(), sawRailVisible = false
        var previous: Frame?, movingTransitions = 0
        var keyframes = Set([0, frameCount-1])
        let eventTimes = [result.recorder.firstBallContacts.values.map(\.time).min(),
                          result.recorder.pocketEntries.map(\.time).min(),
                          result.recorder.pocketEntries.map(\.time).max(), spinTail?.start].compactMap { $0 }
        for time in eventTimes { keyframes.insert(min(frameCount-1, max(0, Int(ceil(Double(time)*60))))) }
        report["retainedPNGFrameIndices"] = keyframes.sorted()
        let anchorIndices = (0..<9).map { $0*(frameCount-1)/8 }
        func stateSignature() throws -> Data {
            let currentRails = Set(scene.rootNode.childNodes.filter { $0.name?.hasSuffix("#rail") == true }.map(ObjectIdentifier.init))
            try require(currentRails.isSubset(of: nodeIDs), "Late rail node missing from current-state verification")
            let values = try nodes.map { node -> [String: Any] in
                try require(node.parent == nil || node.parent === scene.rootNode, "Unexpected dynamic ball parent")
                return ["matrixBits": matrixValues(node.presentation.transform).map(\.bitPattern),
                        "opacity": Double(node.presentation.opacity), "hidden": node.isHidden,
                        "attached": node.parent != nil]
            }
            return try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
        }
        for index in 0..<frameCount {
            // Synchronous native loops do not reach the run-loop autorelease boundary.
            try autoreleasepool {
                if index.isMultiple(of: 120) { print("[ClothDynamicResearch] case=\(caseID) phase=direct-quality frame=\(index)/\(frameCount)") }
                let time = Double(index)/60, timestamp = actionOrigin + Double(index)/60
                if index == frameCount-1 {
                    scene.railInventory.finishPlayback()
                    for node in nodes { node.removeAllActions() }
                    SCNTransaction.flush()
                }
                install("reference"); _ = try render(at: timestamp)
                try identity("reference")
                let currentUniforms = try uniforms(), currentState = try stateSignature()
                for (key, node) in zip(keys, sourceNodes) where !node.isHidden && node.parent != nil {
                    let sampleTime = key == spinTail?.ballName ? spinTail!.simulationTime(at: Float(time)) : Float(time)
                    if let state = playback.stateAt(ballName: key, time: min(sampleTime, playback.duration)), state.motionState != .pocketed {
                        try require((node.presentation.position-state.position).length() < 0.0001,
                                    "Production action clock/position differs from real trajectory at \(index): \(key)")
                    }
                }
                for key in result.pocketed where scene.allBallNodes[key]?.isHidden == true { sawPocketWeightZero.insert(key) }
                sawRailVisible = sawRailVisible || railNodes.contains { $0.parent != nil && !$0.isHidden && $0.opacity > 0 }
                let reference = try target.readback(), hash = imageDigest(reference)
                if index == 0 || index == frameCount-1 {
                    try validFrame(reference); attach(reference, "cloth-dynamic-\(caseID)-capture-\(index)")
                }
                captureHashes.append(hash); stateHasher.update(data: currentState)
                report["capturedFrames"] = index+1
                @MainActor func verifyCurrent(_ variant: String) throws {
                    do {
                        try identity(variant)
                        try require(try uniforms() == currentUniforms, "Same-timestamp contact uniforms changed")
                        try require(try stateSignature() == currentState,
                                    "Same-timestamp action call changed ball/rail parent, visibility, opacity or transform")
                    } catch {
                        attach(reference, "cloth-dynamic-\(caseID)-failure-state-reference-\(index)")
                        if let current = try? target.readback() { attach(current, "cloth-dynamic-\(caseID)-failure-state-current-\(index)") }
                        throw error
                    }
                }
                install("candidate"); _ = try render(at: timestamp); try verifyCurrent("candidate")
                let candidate = try target.readback()
                if reference.bgra != candidate.bgra {
                    attach(reference, "cloth-dynamic-\(caseID)-failure-reference-\(index)"); attach(candidate, "cloth-dynamic-\(caseID)-failure-guard-\(index)")
                    throw failure("Dynamic R/guard RGBA mismatch at \(index)")
                }
                _ = try render(at: timestamp); try verifyCurrent("candidate")
                let repeated = try target.readback()
                if candidate.bgra != repeated.bgra {
                    attach(candidate, "cloth-dynamic-\(caseID)-failure-repeat-before-\(index)"); attach(repeated, "cloth-dynamic-\(caseID)-failure-repeat-after-\(index)")
                    throw failure("Dynamic candidate repeat changed at \(index)")
                }
                install("reference"); _ = try render(at: timestamp); try verifyCurrent("reference")
                let restored = try target.readback()
                if reference.bgra != restored.bgra {
                    attach(reference, "cloth-dynamic-\(caseID)-failure-restore-before-\(index)"); attach(restored, "cloth-dynamic-\(caseID)-failure-restore-after-\(index)")
                    throw failure("Dynamic R restore changed at \(index)")
                }
                let changed = previous.map { difference($0, reference).changedPixels } ?? 0
                if changed > 0 { movingTransitions += 1 }
                qualityRows.append(["index": index, "simulationTime": time, "rgbaSHA256": hash,
                                    "changedPixelsFromPrevious": changed, "candidateRGBAExact": true,
                                    "repeatRGBAExact": true, "restoreRGBAExact": true, "uniformsExact": true,
                                    "sameTimestampStateExact": true])
                if keyframes.contains(index) {
                    attach(reference, "cloth-dynamic-\(caseID)-reference-\(index)"); attach(candidate, "cloth-dynamic-\(caseID)-guard-\(index)")
                }
                previous = reference
                // No replay: measure this actual state while its action time is unchanged.
                if let anchor = anchorIndices.firstIndex(of: index) {
                    print("[ClothDynamicResearch] case=\(caseID) phase=timing anchor=\(anchor+1)/9")
                    var cycles: [[String: Any]] = [], changes: [Double] = []
                    timingRows.append(["anchor": anchor, "frameIndex": index, "simulationTime": time, "cycles": cycles])
                    for cycle in 0..<9 {
                        let order = cycle.isMultiple(of: 2) ? ["reference", "candidate", "candidate", "reference"] : ["candidate", "reference", "reference", "candidate"]
                        var a: [Double] = [], b: [Double] = [], slots: [[String: Any]] = []
                        for (slot, variant) in order.enumerated() {
                            install(variant)
                            for _ in 0..<2 { _ = try render(at: timestamp); try verifyCurrent(variant) }
                            var rawFrames: [[String: Any]] = [], gpuMS = 0.0
                            for frameIndex in 0..<6 {
                                let measurement = try render(at: timestamp)
                                try verifyCurrent(variant) // Outside the measured command, after every draw.
                                var frame = measurement.perFrameTiming[0]; frame["frame"] = frameIndex
                                rawFrames.append(frame); gpuMS += measurement.gpuSpanMS
                            }
                            let last = try target.readback()
                            if last.bgra != reference.bgra {
                                attach(last, "cloth-dynamic-\(caseID)-failure-timing-\(anchor)-\(cycle)-\(slot)")
                                throw failure("Same-timestamp measured target changed")
                            }
                            let mean = gpuMS/6
                            if variant == "reference" { a.append(mean) } else { b.append(mean) }
                            slots.append(["slot": slot, "variant": variant, "perFrameTiming": rawFrames,
                                          "sameLastTargetSHA256": hash, "sameTimestampStateExact": true])
                        }
                        let change = (median(b)/median(a)-1)*100
                        changes.append(change)
                        cycles.append(["index": cycle, "order": order, "slots": slots,
                                       "referenceMeanMS": median(a), "candidateMeanMS": median(b), "pairedChangePercent": change,
                                       "referenceEndpointDriftPercent": abs(a[1]-a[0])/median(a)*100])
                        timingRows[timingRows.count-1] = ["anchor": anchor, "frameIndex": index, "simulationTime": time,
                            "cycles": cycles, "pairedChangeMedianPercent": median(changes),
                            "candidateFasterCycles": changes.filter { $0 < 0 }.count]
                    }
                }
            }
        }
        if !result.pocketed.isEmpty {
            try require(sawRailVisible && Set(result.pocketed).isSubset(of: sawPocketWeightZero),
                        "Full actions did not include every real pocket's hidden source/zero weight and visible rail tail")
        }
        target.renderer.isPlaying = false
        try require(nodes.allSatisfy { !$0.hasActions }, "Dynamic nodes retained actions after complete playback")
        for key in keys where !result.pocketed.contains(key) {
            let state = try XCTUnwrap(playback.stateAt(ballName: key, time: playback.duration))
            try require(state.motionState == .stationary && (scene.allBallNodes[key]!.position-state.position).length() < 0.0001,
                        "Nonpocketed ball did not reach the actual settled endpoint")
        }
        try require(try physicsDigest() == originalPhysicsSHA, "Presentation changed the solved physics frame record")
        try require(movingTransitions > 30, "Sequence lacks actual multi-frame motion")
        report["finalRailPositions"] = scene.railInventory.visiblePositions.mapValues { [$0.x, $0.y, $0.z] }
        report["presentationTailCount"] = result.recorder.collectionTailsByBallName.count
        report["businessBoundary"] = "All real motion/rail completion is covered. Subsequent editor-board delivery or cue-scratch reseating from BreakFlowRunner.finishBreak is not part of this rendering comparison."
        report["actionStateSHA256"] = stateHasher.finalize().map { String(format: "%02x", $0) }.joined()
        report["captureImageSHA256"] = captureHashes
        report["pocketZeroWeightKeys"] = sawPocketWeightZero.sorted()
        report["railVisibleObserved"] = sawRailVisible
        report["adjacentDifferenceProof"] = "Every R and guard RGBA frame is byte-identical; therefore every corresponding signed adjacent-frame difference is exactly identical. Changed-pixel counts retain actual motion; no temporal image approximation is used."
        report["movingTransitions"] = movingTransitions
        report["timedFrames"] = 9*9*4*6
        report["sameTargetChecks"] = 9*9*4
        completed = true
    }
    #endif

    #if DEBUG
    /// R24 measures VM/scene entry, not SwiftUI layout, saved-board restoration or presentation.
    func testNativeProductionGuardComboEntryComparison() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Native entry study requires Designed for iPad on Mac")
        #else
        guard ProcessInfo.processInfo.isiOSAppOnMac else {
            throw XCTSkip("Native entry study is restricted to the authorized Mac host")
        }
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let appearance = EntryAppearance()
        let cache = TableResourceCache.shared
        var rows: [[String: Any]] = [], timingCompleted = false
        var goldenProbe: EntryProof?
        var goldenFrames: [String: Frame] = [:]
        defer {
            let timingFinished = timingCompleted && testRun?.totalFailureCount == 0
            let nonExactEntries = rows.filter {
                $0["sameSceneReferenceControlRGBAExact"] as? Bool != true
                    || $0["sameSceneOriginalRestoreRGBAExact"] as? Bool != true
            }.count
            attachStrictReport([
                "schema": 2, "study": "native-production-async-entry-r24",
                "executionPlatform": "MacNative-isiOSAppOnMac", "device": device.name,
                "scope": "Actual PositionPlayViewModel/scene setup with asynchronous production reflection, fixed rack and first offscreen GPU target frame. No SwiftUI layout, saved-board restoration, displayed/presented frame, user defaults mutation or whole-page launch claim. Entry timing uses each arm's own production surface and reflection probe. Subsequent same-scene R-surface correctness controls are outside all entry timing.",
                "coldDefinition": "TableResourceCache.purge application-resource cold; same process and driver. Static Metal/SceneKit/OS caches may remain warm.",
                "timingDefinition": "CACurrentMediaTime seconds for event boundaries; durations in ms. Probe-installed receipt is taken synchronously in objectWillChange after matching production installation. Initial GPU may overlap background probe work; setup, initial frame and probe-ready intervals overlap and must not be added. Texture/image verification and cleanup are outside measured render spans.",
                "imageContract": "Each own-variant ready frame is compared without tolerance to an R-surface control and an original-surface restore in the same scene, ball state, camera, target and own probe. Reference entries repeat R. Every nonzero difference retains counts, maximum channel error, hashes and uniquely named original/control PNGs; it makes qualityAccepted false without aborting cost collection. Reference self-differences do not excuse candidate differences. Cross-entry image differences remain descriptive. All probe textures/SH/floor and scene-state checks remain strict. The same two controls occur after measured entry draws.",
                "order": "9 alternating ABBA/BAAB cycles; each variant slot is cold then immediately same-variant warm",
                "expectedEntries": 72, "resolution": [1400, 800], "fixture": "rack-16-overview-seed52",
                "selectedAppearance": appearance.json, "entries": rows,
                "recordedXCTestFailureCount": testRun?.totalFailureCount ?? -1,
                "completed": timingFinished, "timingCompleted": timingFinished,
                "qualityAccepted": timingFinished && nonExactEntries == 0,
                "qualityStatus": !timingFinished ? "incomplete"
                    : nonExactEntries == 0 ? "exact-recorded-controls" : "unresolved-nonzero-control-differences",
                "nonExactEntryCount": nonExactEntries, "promotionAllowed": false
            ], name: "cloth-native-async-entry.json")
        }
        for cycle in 0..<9 {
            let order = cycle.isMultiple(of: 2) ? ["reference", "candidate", "candidate", "reference"]
                : ["candidate", "reference", "reference", "candidate"]
            for (slot, variant) in order.enumerated() {
                try require(cache.activeScenes == 0, "Prior entry still owns a production scene")
                cache.purge()
                try require(cache.idleTable == nil, "Cold entry retained a prepared table")
                var cold: EntryProof?
                for cacheState in ["cold", "warm"] {
                    print("[ClothEntryResearch] cycle=\(cycle + 1)/9 slot=\(slot) variant=\(variant) cache=\(cacheState)")
                    let result = try await nativeEntry(variant: variant, cacheState: cacheState,
                        cycle: cycle, slot: slot, device: device, appearance: appearance, previous: cold,
                        referenceSurface: goldenProbe?.referenceSurface)
                    try autoreleasepool {
                        if let goldenProbe {
                            try require(result.probeBytes == goldenProbe.probeBytes && result.shBits == goldenProbe.shBits
                                && result.floorBits == goldenProbe.floorBits, "Own production probe bytes/SH/floor differ across entries")
                        } else { goldenProbe = result }
                        if goldenFrames[cacheState] == nil {
                            try require(variant == "reference", "Each cache state must first establish its reference image")
                            goldenFrames[cacheState] = result.frame
                        }
                        if cycle == 0 && slot < 2 {
                            attach(result.frame, "cloth-entry-\(variant)-\(cacheState)-ready")
                        }
                    }
                    var row = result.row
                    row["probeBytesSHFloorExactToFirstReference"] = true
                    let sameCache = difference(result.frame, goldenFrames[cacheState]!)
                    row["crossEntryReadyRGBAExactToSameCacheReference"] = sameCache.changedPixels == 0
                    row["crossEntryReadyVsSameCacheChangedPixels"] = sameCache.changedPixels
                    row["crossEntryReadyVsSameCacheMaximumRGBAError"] = sameCache.maximum
                    let crossCache = difference(result.frame, goldenFrames["cold"]!)
                    row["crossEntryReadyRGBAExactToFirstReference"] = crossCache.changedPixels == 0
                    row["crossEntryReadyChangedPixels"] = crossCache.changedPixels
                    row["crossEntryReadyMaximumChannelDifference"] = crossCache.maximum
                    row["readyVsFirstColdMaximumRGBAError"] = crossCache.maximum
                    row["readyVsFirstColdChangedPixels"] = crossCache.changedPixels
                    rows.append(row)
                    if cacheState == "cold" { cold = result }
                }
                cold = nil
            }
        }
        try require(rows.count == 72 && appearance == EntryAppearance(), "Entry count/selected appearance changed")
        timingCompleted = true
        #endif
    }

    private struct EntryAppearance: Equatable {
        let room: RoomStyle
        let table: TableStyle
        let cloth: ClothColor
        let sights: Bool
        let ball: BallStickerStyle
        @MainActor init() {
            let preferences = UserPreferences.shared
            room = preferences.roomStyle; table = preferences.tableStyle
            cloth = preferences.clothColor; sights = preferences.showsTableSights
            ball = preferences.ballStickerStyle
        }
        var json: [String: Any] {
            ["room": room.rawValue, "table": table.rawValue, "cloth": cloth.rawValue,
             "sights": sights, "ballSticker": ball.rawValue]
        }
    }
    @MainActor private final class EntryReceipt {
        var installedAt: Double?
        var sends = 0
    }
    private struct EntryProof {
        var row: [String: Any]
        let tableID: ObjectIdentifier
        let tableKey: String
        let probe: RoomReflectionProbe
        let probeBytes: [Data]
        let shBits: [[UInt32]]
        let floorBits: [UInt32]
        let frame: Frame
        let referenceSurface: String
    }

    private func nativeEntry(variant: String, cacheState: String, cycle: Int, slot: Int,
                             device: MTLDevice, appearance: EntryAppearance,
                             previous: EntryProof?, referenceSurface: String?) async throws -> EntryProof {
        let request: DailyClothSupportExperiment.Request = variant == "reference" ? .off : .guardCombo
        let receipt = EntryReceipt()
        let ready = expectation(description: "\(cycle)-\(slot)-\(cacheState)-production-probe-installed")
        var vm: PositionPlayViewModel?, target: RenderTarget?, token: AnyCancellable?
        weak var weakVM: PositionPlayViewModel?
        weak var weakScene: AngleTrainingScene?
        weak var weakRenderer: SCNRenderer?
        var row: [String: Any] = ["cycle": cycle, "slot": slot, "variant": variant, "cacheState": cacheState]
        var setupStart = 0.0, setupEnd = 0.0
        defer {
            token?.cancel(); token = nil
            target?.renderer.delegate = nil; target?.renderer.pointOfView = nil; target?.renderer.scene = nil
            target = nil; vm = nil
        }
        try autoreleasepool {
            try require(appearance == EntryAppearance() && RoomStyle.selected == appearance.room,
                        "Selected appearance drift; do not rewrite user preferences to fit this study")
            vm = PositionPlayViewModel(); weakVM = vm; weakScene = vm!.scene
            let scene = vm!.scene
            scene.configureDailyClearanceRendering(asynchronousReflection: true)
            scene.configureClothSupportExperiment(request: request)
            scene.tablePreferencePage = .dailyClearance
            // These calls stage requested appearance before the model exists; no rebake is started.
            scene.applyTableStyle(appearance.table, showsSights: appearance.sights)
            scene.applyClothColor(appearance.cloth)
            token = scene.objectWillChange.sink { [weak scene] in
                MainActor.assumeIsolated {
                    receipt.sends += 1
                    guard receipt.installedAt == nil, let scene, let probe = scene.roomReflectionProbe,
                          probe.style == appearance.room, scene.clothSupportRequest == request,
                          scene.safeClothSupportState.effective == (request == .guardCombo),
                          let cached = RoomReflectionProbe.cached(for: .init(style: appearance.room, scene: scene)),
                          cached === probe else { return }
                    receipt.installedAt = CACurrentMediaTime()
                    ready.fulfill()
                }
            }
            setupStart = CACurrentMediaTime()
            vm!.setupScene(mobileRendering: true, loadsDefaultLayout: false)
            setupEnd = CACurrentMediaTime()
            row["setupStartSeconds"] = setupStart; row["setupEndSeconds"] = setupEnd
            row["vmSetupWallMS"] = (setupEnd - setupStart) * 1000
            row["sceneSetupTimingMS"] = scene.setupTiming; row["vmEntryTimingMS"] = vm!.entryTiming
            try require(scene.installedClothColor == appearance.cloth && scene.installedTableStyle == appearance.table
                        && scene.showsTableSights == appearance.sights && scene.ballStickerStyle == appearance.ball,
                        "Selected production appearance was not installed")
            let fixtureStart = CACurrentMediaTime()
            scene.hideAllBalls()
            let rack = RackLayout.make(.chineseEightBall, seed: 52, surfaceY: scene.surfaceY)
            scene.showBall(key: "cueBall", scenePosition: rack.cue)
            for ball in rack.balls { scene.showBall(key: ball.key, scenePosition: ball.position) }
            let rig = try XCTUnwrap(scene.cameraRig)
            rig.viewportSize = CGSize(width: 1400, height: 800)
            scene.setCameraMode(.perspective3D, animated: false)
            try require(rig.observeWholeTable(yaw: .pi / 2), "Entry overview unavailable")
            for _ in 0..<180 { rig.update(deltaTime: 1/60) }
            row["fixtureWallMS"] = (CACurrentMediaTime() - fixtureStart) * 1000
            let targetStart = CACurrentMediaTime()
            target = try RenderTarget(device: device, scene: scene, size: CGSize(width: 1400, height: 800))
            weakRenderer = target!.renderer
            row["renderTargetConstructionWallMS"] = (CACurrentMediaTime() - targetStart) * 1000
            row["initialProbeAlreadyInstalled"] = scene.roomReflectionProbe != nil
            row["initialFrameStartSeconds"] = CACurrentMediaTime()
            let initial = try target!.render(frames: 1, includeNativeTiming: true)
            row["initialFrameEndSeconds"] = CACurrentMediaTime()
            row["initialFrame"] = initial.perFrameTiming[0]
            row["initialInstalledState"] = try entryInstalledState(scene, request: request)
        }
        // Suspension permits the production bake's main-queue installation, including any queued cache warmup.
        await fulfillment(of: [ready], timeout: 60)
        let installedAt = try XCTUnwrap(receipt.installedAt, "No matching asynchronous production probe receipt")
        var result: EntryProof = try autoreleasepool {
            let scene = try XCTUnwrap(vm?.scene)
            let target = try XCTUnwrap(target)
            let probe = try XCTUnwrap(scene.roomReflectionProbe)
            let cached = try XCTUnwrap(RoomReflectionProbe.cached(for: .init(style: appearance.room, scene: scene)))
            try require(cached === probe && appearance == EntryAppearance(), "Ready probe/appearance identity drift")
            let tableID = ObjectIdentifier(try XCTUnwrap(scene.tableNode))
            if let previous {
                try require(tableID == previous.tableID && probe === previous.probe,
                            "Warm entry did not reuse both the actual table node and own variant probe")
            }
            row["probeInstalledSeconds"] = installedAt
            row["probeReadyFromSetupStartMS"] = (installedAt - setupStart) * 1000
            row["probeInstalledBeforeSetupReturned"] = installedAt <= setupEnd
            row["probeReceiptSignalCount"] = receipt.sends
            // The offscreen target has not rendered again. Delay readback/analysis until
            // after the receipt so image hashing/validation cannot defer main-queue installation.
            let initialImage = try target.readback()
            let readyWasInitial = row["initialProbeAlreadyInstalled"] as? Bool == true
            row["readyFrameIsInitialFrame"] = readyWasInitial
            let frame: Frame
            if readyWasInitial {
                // A synchronous warm hit makes the initial draw the first fully reflected frame.
                row["readyFrameStartSeconds"] = row["initialFrameStartSeconds"]
                row["readyFrameEndSeconds"] = row["initialFrameEndSeconds"]
                row["readyFrame"] = row["initialFrame"]
                frame = initialImage
            } else {
                row["readyFrameStartSeconds"] = CACurrentMediaTime()
                let readyTiming = try target.render(frames: 1, includeNativeTiming: true)
                row["readyFrameEndSeconds"] = CACurrentMediaTime()
                row["readyFrame"] = readyTiming.perFrameTiming[0]
                frame = try target.readback()
            }
            row["readyInstalledState"] = try entryInstalledState(scene, request: request)
            // CPU image analysis and attachment encoding run only after the ready draw.
            try require(initialImage.uniqueColors > 128 && initialImage.magentaPixels == 0,
                        "Initial selected-appearance frame is empty or shader-error magenta")
            row["initialRGBA_SHA256"] = SHA256.hash(data: Data(initialImage.bgra)).map { String(format: "%02x", $0) }.joined()
            if cycle == 0 && slot < 2 { attach(initialImage, "cloth-entry-\(variant)-\(cacheState)-initial") }
            try require(frame.uniqueColors > 128 && frame.magentaPixels == 0, "Ready frame lacks production image or has shader-error magenta")
            let filtered = try XCTUnwrap(probe.prefiltered(), "Production R prefiltered probe was not prepared")
            let bytes = try [probe.texture, filtered.environment, filtered.response].map { try entryTextureBytes($0) }
            let sh = probe.irradianceSH.map { [$0.x.bitPattern, $0.y.bitPattern, $0.z.bitPattern] }
            let floor = [probe.floorRadiance.x.bitPattern, probe.floorRadiance.y.bitPattern, probe.floorRadiance.z.bitPattern]
            row["probeTextureSHA256"] = bytes.map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }
            row["probeTextureReadbackBytes"] = bytes.map(\.count)
            row["probeSHFloat32Bits"] = sh; row["probeFloorFloat32Bits"] = floor
            row["probeAllocatedBytes"] = probe.texture.allocatedSize
            row["prefilterAllocatedBytes"] = filtered.allocatedBytes; row["prefilterTexelBytes"] = filtered.texelBytes
            row["prefilterGenerationMS"] = filtered.generationMilliseconds
            row["harnessAllocatedBytes"] = target.allocatedBytes
            row["resourceScope"] = "Existing probe/prefilter and explicit target allocations only; not total App/driver memory. Warm generationMS belongs to the retained cold probe, not new warm work."
            row["readyRGBA_SHA256"] = SHA256.hash(data: Data(frame.bgra)).map { String(format: "%02x", $0) }.joined()
            row["tableIdentity"] = String(describing: tableID); row["probeIdentity"] = String(describing: ObjectIdentifier(probe))
            row["warmTableIdentityHit"] = previous != nil; row["warmProbeIdentityHit"] = previous != nil
            row["visibleBalls"] = scene.allBallNodes.values.filter { !$0.isHidden }.count
            try require(row["visibleBalls"] as? Int == 16, "Entry fixture must retain all 16 rack balls")
            let controlSurface = try entrySameSceneImageControl(scene: scene, target: target,
                ownFrame: frame, referenceSurface: referenceSurface,
                entryID: "\(cycle)-\(slot)-\(cacheState)-\(variant)", row: &row)
            return EntryProof(row: row, tableID: tableID, tableKey: "", probe: probe,
                              probeBytes: bytes, shBits: sh, floorBits: floor, frame: frame,
                              referenceSurface: controlSurface)
        }
        autoreleasepool {
            token?.cancel(); token = nil
            target?.renderer.delegate = nil; target?.renderer.pointOfView = nil; target?.renderer.scene = nil
            target = nil; vm = nil
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        try require(weakVM == nil && weakScene == nil && weakRenderer == nil,
                    "Entry VM/scene/renderer retained after explicit release")
        let idle = try XCTUnwrap(TableResourceCache.shared.idleTable, "Released table did not return to application cache")
        try require(TableResourceCache.shared.activeScenes == 0 && ObjectIdentifier(idle.node) == result.tableID,
                    "Released table/cache lease identity mismatch")
        if let previous { try require(idle.key == previous.tableKey, "Warm table cache key changed") }
        result.row["releasedVMSceneRenderer"] = true; result.row["activeScenesAfterRelease"] = 0
        result.row["returnedTableIdentityExact"] = true; result.row["returnedTableKey"] = idle.key
        return EntryProof(row: result.row, tableID: result.tableID, tableKey: idle.key, probe: result.probe,
                          probeBytes: result.probeBytes, shBits: result.shBits, floorBits: result.floorBits,
                          frame: result.frame, referenceSurface: result.referenceSurface)
    }

    /// Correctness-only draws after the entry receipts, using the same live scene and own probe.
    private func entrySameSceneImageControl(scene: AngleTrainingScene, target: RenderTarget,
                                            ownFrame: Frame, referenceSurface: String?,
                                            entryID: String, row: inout [String: Any]) throws -> String {
        var seen = Set<ObjectIdentifier>()
        var materials: [(SCNMaterial, [SCNShaderModifierEntryPoint: String])] = []
        scene.rootNode.enumerateHierarchy { node, _ in
            for material in node.geometry?.materials ?? []
            where material.name == "TaiNi" && seen.insert(ObjectIdentifier(material)).inserted {
                materials.append((material, material.shaderModifiers ?? [:]))
            }
        }
        try require(!materials.isEmpty, "Entry image control has no cloth")
        let source: String
        if let referenceSurface { source = referenceSurface }
        else {
            try require(scene.clothSupportRequest == .off, "First entry must supply the actual production R surface")
            source = try XCTUnwrap(materials.first?.1[.surface])
        }
        try require(ClothResearchShaders.sha256(source) == "9495698875cd01a4ecd8d00708ce88bf9989c6e118805620f99a11d03dcca390",
                    "Same-scene control must use the verified production R surface")
        @MainActor func restore() {
            for (material, original) in materials { material.shaderModifiers = original }
            SCNTransaction.flush()
        }
        defer { restore() }
        @MainActor func stateData() throws -> Data {
            let balls: [[String: Any]] = scene.allBallNodes.sorted { $0.key < $1.key }.map { key, node in
                ["key": key, "identity": String(describing: ObjectIdentifier(node)),
                 "transformBits": matrixValues(node.presentation.worldTransform).map(\.bitPattern),
                 "opacityBits": Double(node.presentation.opacity).bitPattern,
                 "hidden": node.isHidden, "attached": node.parent != nil]
            }
            let camera = try XCTUnwrap(scene.cameraNode)
            let probe = try XCTUnwrap(scene.roomReflectionProbe)
            let uniforms = try materials.map { material, _ in
                try XCTUnwrap(material.value(forKey: "contactUniforms") as? Data).base64EncodedString()
            }
            return try JSONSerialization.data(withJSONObject: ["balls": balls,
                "cameraIdentity": String(describing: ObjectIdentifier(camera)),
                "cameraTransformBits": matrixValues(camera.presentation.worldTransform).map(\.bitPattern),
                "probeIdentity": String(describing: ObjectIdentifier(probe)), "uniforms": uniforms], options: [.sortedKeys])
        }
        let before = try stateData()
        for (material, original) in materials {
            var modifiers = original; modifiers[.surface] = source; material.shaderModifiers = modifiers
        }
        SCNTransaction.flush()
        _ = try target.render(frames: 1)
        try require(try stateData() == before, "Same-scene R control changed balls/camera/probe/contact uniforms")
        let reference = try target.readback()
        let referenceDifference = difference(ownFrame, reference)
        let referenceExact = referenceDifference.changedPixels == 0
        restore()
        _ = try target.render(frames: 1)
        try require(try stateData() == before, "Same-scene restore changed balls/camera/probe/contact uniforms")
        let restored = try target.readback()
        let restoreDifference = difference(ownFrame, restored)
        let restoreExact = restoreDifference.changedPixels == 0
        var differencePNGs: [String: String] = [:]
        if !referenceExact || !restoreExact {
            let name = "cloth-entry-\(entryID)-same-scene-own-ready"
            attach(ownFrame, name); differencePNGs["ownReady"] = name
        }
        if !referenceExact {
            let name = "cloth-entry-\(entryID)-same-scene-R-control"
            attach(reference, name); differencePNGs["referenceControl"] = name
        }
        if !restoreExact {
            let name = "cloth-entry-\(entryID)-same-scene-original-restore"
            attach(restored, name); differencePNGs["originalRestore"] = name
        }
        _ = try entryInstalledState(scene, request: scene.clothSupportRequest)
        row["sameSceneReferenceControlKind"] = scene.clothSupportRequest == .off ? "referenceSelf" : "candidateVsReference"
        row["sameSceneReferenceControlRGBAExact"] = referenceExact
        row["sameSceneReferenceControlChangedPixels"] = referenceDifference.changedPixels
        row["sameSceneReferenceControlMaximumRGBAError"] = referenceDifference.maximum
        row["sameSceneOriginalRestoreRGBAExact"] = restoreExact
        row["sameSceneOriginalRestoreChangedPixels"] = restoreDifference.changedPixels
        row["sameSceneOriginalRestoreMaximumRGBAError"] = restoreDifference.maximum
        row["sameSceneQualityStatus"] = referenceExact && restoreExact ? "exact" : "unresolved-nonzero-difference"
        row["sameSceneDifferencePNGs"] = differencePNGs
        row["sameSceneStateExact"] = true
        row["sameSceneReferenceControlSHA256"] = SHA256.hash(data: Data(reference.bgra)).map { String(format: "%02x", $0) }.joined()
        row["sameSceneRestoredSHA256"] = SHA256.hash(data: Data(restored.bgra)).map { String(format: "%02x", $0) }.joined()
        row["sameSceneReferenceSurfaceSHA256"] = ClothResearchShaders.sha256(source)
        row["sameSceneControlsOutsideEntryTiming"] = true
        row["sameSceneControlDrawCount"] = 2
        return source
    }

    private func entryInstalledState(_ scene: AngleTrainingScene,
                                      request: DailyClothSupportExperiment.Request) throws -> [String: Any] {
        let state = scene.safeClothSupportState
        let expected = request == .off ? "9495698875cd01a4ecd8d00708ce88bf9989c6e118805620f99a11d03dcca390"
            : "ca5acc70043f0da620e2c6501188063c78027c8e26b62233d128ced01f81aabd"
        var hashes: [String] = [], seen = Set<ObjectIdentifier>(), completeMaterial = true
        scene.rootNode.enumerateHierarchy { node, _ in
            for material in node.geometry?.materials ?? []
            where material.name == "TaiNi" && seen.insert(ObjectIdentifier(material)).inserted {
                hashes.append(ClothResearchShaders.sha256(material.shaderModifiers?[.surface] ?? ""))
                completeMaterial = completeMaterial && material.shaderModifiers?[.geometry] != nil
                    && abs(material.normal.intensity - 0.65) < 0.00001
            }
        }
        try require(scene.clothSupportRequest == request && state.request == request && state.effective == (request == .guardCombo)
                    && state.profile == "R" && state.sampling == "reference" && state.capacity == 16
                    && scene.contactOcclusion?.capacity == 16 && !hashes.isEmpty && hashes.allSatisfy { $0 == expected }
                    && completeMaterial && !scene.mergesDailyClothSupport && !scene.factorsDailyClothBRDF,
                    "Actual entry production recipe/source/material drift; no surface transplant or preference rewrite permitted")
        return ["request": state.requestedVariant, "effective": state.effective, "variant": state.variant,
                "profile": state.profile, "sampling": state.sampling, "capacity": state.capacity,
                "fallbackReason": state.fallbackReason ?? "none", "surfaceSHA256": hashes,
                "probeCacheIdentity": state.probeCacheIdentity]
    }

    /// Same half-texture blit as RoomReflectionProbeTests, retaining exact bits and stripping row padding.
    private func entryTextureBytes(_ texture: MTLTexture) throws -> Data {
        try require(texture.pixelFormat == .rgba16Float || texture.pixelFormat == .rg16Float,
                    "Unexpected production reflection texture format")
        let channels = texture.pixelFormat == .rg16Float ? 2 : 4
        let queue = try XCTUnwrap(texture.device.makeCommandQueue())
        var data = Data()
        for mip in 0..<texture.mipmapLevelCount {
            let width = max(1, texture.width >> mip), height = max(1, texture.height >> mip)
            let packedRow = width * channels * 2, rowBytes = ((packedRow + 255) / 256) * 256
            let buffer = try XCTUnwrap(texture.device.makeBuffer(length: rowBytes * height, options: .storageModeShared))
            let command = try XCTUnwrap(queue.makeCommandBuffer()), blit = try XCTUnwrap(command.makeBlitCommandEncoder())
            blit.copy(from: texture, sourceSlice: 0, sourceLevel: mip, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                      sourceSize: MTLSize(width: width, height: height, depth: 1), to: buffer, destinationOffset: 0,
                      destinationBytesPerRow: rowBytes, destinationBytesPerImage: rowBytes * height)
            blit.endEncoding(); command.commit(); command.waitUntilCompleted()
            try require(command.status == .completed && command.error == nil, "Reflection texture readback failed")
            for y in 0..<height { data.append(buffer.contents().advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self), count: packedRow) }
        }
        return data
    }
    #endif

    private struct InstalledGuardProgram {
        let surface: String
        let identity: String
        let metadata: [String: Any]
    }

    private func compareProductionScene(installedGuard: InstalledGuardProgram?,
                                        nativeMacCalibration: [String: Any]? = nil) throws {
        let nativeMac = nativeMacCalibration != nil
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        try require(device.supportsTextureSampleCount(4), "Metal MSAA4 is unavailable")
        let fixtures = try nativeMac ? nativeMacFixtureMatrix() : fixtureMatrix()
        let framesPerBatch = 6
        let cycleCount = nativeMac || installedGuard == nil ? 9 : 2
        let attachmentPrefix = nativeMac ? "cloth-native-mac-guard" : (installedGuard == nil ? "cloth-support" : "cloth-guard-installed")
        var rows: [[String: Any]] = []
        var nativeStudyCompleted = false
        var report: [String: Any] = [
            "schema": 2, "candidate": installedGuard?.identity ?? ClothResearchShaders.identity, "harness": "sequential-command-buffer-r4",
            "scope": "Controlled complete production SceneKit scene to explicit native Metal target. Not SwiftUI page, presented FPS, live interaction or sustained phone thermal acceptance.",
            "timing": "Sum of six independently committed MTLCommandBuffer GPU spans / 6 complete fixed-time renders; independent sentinel clear before every frame and same-target readback outside measured commands; no reciprocal-FPS conversion",
            "renderEncoding": "Every batch calls SCNRenderer.render(atTime:1) once in each of six command buffers. Each command is immediately committed and waited before encoding the next frame; no snapshot path. This avoids SceneKit in-flight semaphore backpressure from multiple uncommitted render calls.",
            "cpuTiming": "CPU encode: sum of each frame's command creation/pass descriptor/render encoding through immediately before commit. CPU wall: sum of each frame's interval through commit/wait, excluding sentinel clear. Separately named batchWallMSIncludingHarness spans all six frames including sentinel clear, validation and bookkeeping. Raw values are separate from GPU spans; never added together or converted to FPS.",
            "device": device.name, "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "MSAA": 4, "fixtureCount": fixtures.count,
            "format": "BGRA8Unorm_sRGB with depth32Float_stencil8", "framesPerBatch": framesPerBatch,
            "cycles": cycleCount, "thermalStart": ProcessInfo.processInfo.thermalState.rawValue,
            "emitterSHA256": ClothResearchShaders.emitterSHA256,
            "referenceCoreSHA256": ClothResearchShaders.referenceCoreSHA256
        ]
        if let installedGuard {
            report["installedProgram"] = installedGuard.metadata
            report["purpose"] = "Strict full-room image equality of the production DEBUG-installed guard program, transplanted onto the unchanged R scene's TaiNi surface. Original room, ball materials, reflection probe and geometry modifiers remain from the R scene. Guard probe/cache identity is covered independently by unit/UI tests. Two ABBA/BAAB cycles retain the same-last-target contract; times are raw diagnostics only."
            report["performanceRankingAllowed"] = false
        } else {
            report["helperSHA256"] = ClothResearchShaders.sha256(ClothResearchShaders.heightSafeBelow)
        }
        #if targetEnvironment(simulator)
        report["environment"] = "iOS Simulator; raw command times are not suitable for performance ranking or iPhone performance conclusions"
        report["performanceRankingAllowed"] = false
        #else
        report["environment"] = "physical iOS device; controlled offscreen scene, not presented application page"
        #endif
        if let nativeMacCalibration {
            try require(installedGuard != nil && nativeMacCalibration["passed"] as? Bool == true,
                        "Native comparison requires the installed guard and a passed workload calibration")
            report["environment"] = "MacNative: Designed for iPad App host on macOS; native Metal device, not Simulator"
            report["executionPlatform"] = "MacNative-isiOSAppOnMac"
            report["isiOSAppOnMac"] = ProcessInfo.processInfo.isiOSAppOnMac
            report["deviceRegistryID"] = String(device.registryID)
            report["physicalMemoryBytes"] = ProcessInfo.processInfo.physicalMemory
            report["gpuCalibration"] = nativeMacCalibration
            report["performanceRankingAllowed"] = false
            report["purpose"] = "Paired native Mac complete production fixed-scene render cost. Actual production-installed guard surface replaces only TaiNi.surface on the unchanged R full-room scene. No presented FPS, SwiftUI scheduling, live input, camera/physics update or sustained device claim."
            report["probeCostScope"] = "Both arms share the already prepared production R room reflection probe, actual ball materials and all non-cloth work. Scene setup/probe generation is outside timed slots. Guard-specific probe generation, cache identity and lifecycle costs are separate evidence, not included here."
            report["nativeCPUMetricDefinitions"] = "cpuEncodeMS: command/pass/render encoding through before commit. cpuCommitWaitMS: commit plus waitUntilCompleted. cpuWallMS: encode plus commit/wait, excludes sentinel. cpuFullSyncWallMS: sentinel clear plus encode/commit/wait; excludes readback and later validation. Raw CPU/GPU intervals remain separate."
            report["fixturePolicy"] = "Fixed 2-ball near and 16-ball scatter at 700x400 and 1400x800, plus one 16-ball rack overview at 1400x800; only CLOTH_RESEARCH_MAC_2800=1 explicitly adds both 2800x1600 pair/scatter cases. Other selector fixture defaults remain unchanged."
        }
        defer {
            report["rows"] = rows
            report["thermalEnd"] = ProcessInfo.processInfo.thermalState.rawValue
            if nativeMac {
                let recordedFailures = testRun?.totalFailureCount
                let completeWithoutFailure = nativeStudyCompleted && recordedFailures == 0
                report["recordedXCTestFailureCount"] = recordedFailures ?? -1
                report["completed"] = completeWithoutFailure
                report["performanceRankingAllowed"] = completeWithoutFailure
                attachStrictReport(report, name: "cloth-native-mac-production-guard-gpu.json")
            } else if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = installedGuard == nil ? "cloth-support-production-gpu.json" : "cloth-guard-installed-full-scene-quality.json"
                attachment.lifetime = .keepAlways; add(attachment)
            }
        }

        for configuration in fixtures {
            let fixture = configuration.id
            print("[ClothSupportResearch] fixture=\(fixture) phase=setup")
            let size = configuration.size
            let scene = AngleTrainingScene()
            scene.configureDailyClearanceRendering(asynchronousReflection: false)
            // Both research candidates retain the original R scene/probe baseline,
            // independently of the production default selected by configuration.
            scene.configureClothSupportExperiment(request: .off)
            scene.setupScene(mobileRendering: true, roomStyle: .tournament)
            try require(scene.renderingProfile == .reflection, "Must use production R")
            try require(!scene.mergesDailyClothSupport && !scene.factorsDailyClothBRDF,
                        "Other shader experiments must be disabled for paired A/B")
            try require(scene.applyClothColor(.green), "Production cloth appearance unavailable")
            try require(scene.applyTableStyle(.charcoal), "Production table appearance unavailable")
            try require(scene.clothSupportRequest == .off && !scene.safeClothSupportState.effective,
                        "Full-scene reference must keep the original installed recipe/probe identity")
            scene.hideAllBalls()
            let keys = ["cueBall"] + (1...15).map { "_\($0)" }
            try require(Set(scene.allBallNodes.keys) == Set(keys), "Missing production USDZ ball identities")
            let expectedKeys = Array(keys.prefix(configuration.activeBalls))
            if configuration.layout == "rack" {
                let rack = RackLayout.make(.chineseEightBall, seed: 52, surfaceY: scene.surfaceY)
                scene.showBall(key: "cueBall", scenePosition: rack.cue)
                for ball in rack.balls { scene.showBall(key: ball.key, scenePosition: ball.position) }
            } else if configuration.activeBalls == 2 {
                let positions: [SCNVector3] = configuration.pose == "pocket"
                    ? [SCNVector3(1.17, scene.surfaceY, 0.55), SCNVector3(1.11, scene.surfaceY, 0.50)]
                    : [SCNVector3(0, scene.surfaceY, 0), SCNVector3(0.05715, scene.surfaceY, 0)]
                for (key, point) in zip(expectedKeys, positions) { scene.showBall(key: key, scenePosition: point) }
            } else {
                for (index, key) in expectedKeys.enumerated() {
                    let rowsPerColumn = configuration.activeBalls == 8 ? 2 : 4
                    scene.showBall(key: key, scenePosition: SCNVector3(
                        Float(index / rowsPerColumn) * 0.6 - 0.9, scene.surfaceY + AngleSceneCalculator.ballRadius,
                        configuration.activeBalls == 8 ? Float(index % 2) * 0.6 - 0.3 : Float(index % 4) * 0.3 - 0.45))
                }
            }
            try require(Set(scene.allBallNodes.filter { !$0.value.isHidden }.keys) == Set(expectedKeys),
                        "Guard against empty or partial ball fixtures")
            for node in scene.allBallNodes.values {
                var geometryCount = node.geometry == nil ? 0 : 1
                node.enumerateChildNodes { child, _ in if child.geometry != nil { geometryCount += 1 } }
                try require(geometryCount > 0 && node.parent != nil && node.opacity == 1,
                            "Every expected ball must retain attached production geometry")
            }
            let rig = try XCTUnwrap(scene.cameraRig)
            rig.viewportSize = size
            scene.setCameraMode(.perspective3D, animated: false)
            try require(rig.observeWholeTable(yaw: .pi / 2), "Production overview camera failed")
            if configuration.pose == "near" {
                rig.enterAiming(cueBallPosition: scene.allBallNodes["cueBall"]!.worldPosition,
                                targetDirection: SCNVector3(1, 0, 0), entryZoom: 0.25)
            } else if configuration.pose == "pocket" {
                rig.observe(at: SCNVector3(1.2, scene.surfaceY, 0.58))
                rig.handlePinch(scale: 1.8)
            }
            for _ in 0..<180 { rig.update(deltaTime: 1/60) }
            let room = try XCTUnwrap(scene.rootNode.childNode(withName: "reference_room", recursively: false))
            try require(!room.isHidden && !room.childNodes.isEmpty, "Production room must remain visible")
            let camera = try XCTUnwrap(scene.cameraNode)
            let frozenCamera = camera.transform
            let frozenPositions = scene.allBallNodes.mapValues(\.simdWorldPosition)
            let contact = try XCTUnwrap(scene.contactOcclusion)
            try require(contact.capacity == 16, "Unexpected contact uniform capacity")
            var seen = Set<ObjectIdentifier>()
            var materials: [(material: SCNMaterial, original: [SCNShaderModifierEntryPoint: String], candidate: String)] = []
            var builderError: Error?
            scene.rootNode.enumerateHierarchy { node, _ in
                for material in node.geometry?.materials ?? [] where material.name == "TaiNi" && seen.insert(ObjectIdentifier(material)).inserted {
                    do {
                        let original = try XCTUnwrap(material.shaderModifiers)
                        let source = try XCTUnwrap(original[.surface])
                        let candidate: String
                        if let installedGuard {
                            try require(ClothResearchShaders.sha256(source) == "9495698875cd01a4ecd8d00708ce88bf9989c6e118805620f99a11d03dcca390",
                                        "Original complete production R surface changed; do not silently substitute a different baseline")
                            candidate = installedGuard.surface
                        } else {
                            candidate = try ClothResearchShaders.heightSafeSurface(source, ballCount: contact.capacity)
                        }
                        materials.append((material, original, candidate))
                    } catch { builderError = error }
                }
            }
            if let builderError { throw builderError }
            try require(!materials.isEmpty, "No production TaiNi shader installed")
            for item in materials {
                try require(abs(item.material.normal.intensity - 0.65) < 0.00001, "Unexpected normal intensity")
            }
            func install(_ variant: String) {
                for item in materials {
                    var modifiers = item.original
                    if variant == "candidate" { modifiers[.surface] = item.candidate }
                    if variant == "red-control" {
                        modifiers[.fragment] = (modifiers[.fragment] ?? "#pragma body")
                            + "\n_output.color.rgb=float3(1.0,0.0,0.0);\n"
                    }
                    item.material.shaderModifiers = modifiers
                }
                SCNTransaction.flush()
            }
            func verifyInstalledVariant(_ variant: String) throws {
                guard installedGuard != nil else { return }
                for item in materials {
                    let expectedSurface = variant == "candidate" ? item.candidate : item.original[.surface]
                    try require(item.material.shaderModifiers?[.surface] == expectedSurface,
                                "Rendered material no longer holds the selected installed program")
                    try require(item.material.shaderModifiers?[.geometry] == item.original[.geometry],
                                "Candidate must retain the R scene's production geometry modifier")
                }
                #if DEBUG
                try require(scene.clothSupportRequest == .off && !scene.safeClothSupportState.effective,
                            "Surface-only image comparison must not switch the reference scene's probe/cache recipe")
                #endif
            }
            defer { install("reference") }
            let target = try RenderTarget(device: device, scene: scene, size: size)
            if nativeMac {
                try require(target.allocatedBytes.values.allSatisfy { $0 > 0 },
                            "Native MSAA4 color/depth/staging allocations must all report positive actual bytes")
            }
            print("[ClothSupportResearch] fixture=\(fixture) phase=prepare")
            try require(target.renderer.prepare(scene, shouldAbortBlock: nil), "SceneKit resource preparation failed")
            func render(_ count: Int) throws -> BatchTiming {
                try require(ProcessInfo.processInfo.thermalState != .serious && ProcessInfo.processInfo.thermalState != .critical,
                            "Thermal state invalidates this controlled batch; stop and retain evidence")
                #if !targetEnvironment(simulator)
                try require(UIApplication.shared.applicationState == .active, "Device test host must remain foreground active")
                #endif
                return try target.render(frames: count, includeNativeTiming: nativeMac)
            }
            func capture(_ name: String) throws -> Frame {
                let frame = try target.readback()
                attach(frame, "\(attachmentPrefix)-\(fixture)-\(name)")
                return frame
            }
            install("reference")
            print("[ClothSupportResearch] fixture=\(fixture) phase=reference-warmup")
            _ = try render(8)
            try verifyInstalledVariant("reference")
            let before = try capture("reference")
            try validFrame(before)
            _ = try render(1)
            let repeated = try target.readback()
            try require(before.bgra == repeated.bgra, "Fixed reference target must repeat exactly")
            install("red-control")
            print("[ClothSupportResearch] fixture=\(fixture) phase=red-control")
            _ = try render(4)
            let control = try capture("red-control")
            let controlChange = difference(before, control)
            try require(controlChange.changedPixels > before.pixelCount / 100,
                        "Red control must affect at least 1% of actual target pixels")
            try require(control.redPixels > before.redPixels + before.pixelCount / 100,
                        "Control must visibly turn the installed cloth red")
            install("candidate")
            print("[ClothSupportResearch] fixture=\(fixture) phase=candidate-warmup")
            _ = try render(8)
            try verifyInstalledVariant("candidate")
            let candidate = try capture("candidate")
            try validFrame(candidate)
            let candidateDifference = difference(before, candidate)
            try require(candidateDifference.maximum == 0,
                        "Conservative mask must preserve complete rendered RGBA exactly; retain images on failure")
            if installedGuard != nil {
                _ = try render(1)
                try verifyInstalledVariant("candidate")
                let candidateRepeat = try capture("candidate-repeat")
                try require(candidateRepeat.bgra == candidate.bgra, "Installed guard candidate target must repeat exactly")
            }
            install("reference")
            print("[ClothSupportResearch] fixture=\(fixture) phase=restore")
            _ = try render(4)
            try verifyInstalledVariant("reference")
            let restored = try capture("restored")
            try require(before.bgra == restored.bgra, "Original complete target must restore exactly")

            var cycles: [[String: Any]] = []
            var changes: [Double] = []
            var allA: [Double] = [], allB: [Double] = []
            var encodeA: [Double] = [], encodeB: [Double] = [], wallA: [Double] = [], wallB: [Double] = []
            var nativeFramesA: [[String: Any]] = [], nativeFramesB: [[String: Any]] = []
            var row: [String: Any] = [
                "fixture": fixture, "ballKeys": expectedKeys, "room": "tournament", "cloth": "green", "table": "charcoal",
                "resolution": [Int(size.width), Int(size.height)], "pixels": Int(size.width*size.height),
                "pose": configuration.pose, "layout": configuration.layout, "contactSlots": contact.capacity,
                "harnessAllocatedBytes": target.allocatedBytes,
                "harnessMemoryScope": "Only explicit color/MSAA/depth/staging targets. Not candidate-added memory, SceneKit internals, shader registers or complete App memory.",
                "clothMaterials": materials.count, "visibleBalls": scene.allBallNodes.filter { !$0.value.isHidden }.count,
                "referenceSurfaceSHA256": materials.map { ClothResearchShaders.sha256($0.original[.surface]!) },
                "candidateSurfaceSHA256": materials.map { ClothResearchShaders.sha256($0.candidate) },
                "controlChangedPixels": controlChange.changedPixels, "candidateMaximumRGBAError": candidateDifference.maximum,
                "baselineGreenPixels": before.greenPixels, "baselineUniqueRGB565": before.uniqueColors,
                "controlAffectedPixelFraction": Double(controlChange.changedPixels)/Double(before.pixelCount),
                "controlCoverageDefinition": "Pixels changed by cloth-only red override; includes SceneKit postprocessing spread, not an exact fragment mask",
                "cameraTransform": matrixValues(frozenCamera),
                "cameraSettings": cameraMetadata(try XCTUnwrap(camera.camera)),
                "balls": expectedKeys.map { key -> [String: Any] in
                    let p = scene.allBallNodes[key]!.worldPosition
                    return ["id": key, "position": [p.x, p.y, p.z]]
                }
            ]
            if let installedGuard { row["installedProgram"] = installedGuard.metadata }
            rows.append(row)
            for cycle in 0..<cycleCount {
                print("[ClothSupportResearch] fixture=\(fixture) phase=\(nativeMac ? "native-mac-timing" : (installedGuard == nil ? "timing" : "image-proof")) cycle=\(cycle+1)/\(cycleCount)")
                let order = cycle.isMultiple(of: 2)
                    ? ["reference", "candidate", "candidate", "reference"]
                    : ["candidate", "reference", "reference", "candidate"]
                var spans: [Double] = [], a: [Double] = [], b: [Double] = []
                var rawTiming: [[String: Any]] = []
                for (slot, variant) in order.enumerated() {
                    install(variant)
                    _ = try render(2) // same bounded post-switch warmup on A and B
                    let timing = try render(framesPerBatch)
                    try verifyInstalledVariant(variant)
                    let span = timing.gpuSpanMS / Double(framesPerBatch)
                    let proof = try target.readback() // exact last measured target; no second render
                    if proof.bgra != before.bgra {
                        attach(proof, "\(attachmentPrefix)-\(fixture)-failure-cycle\(cycle)-slot\(slot)-\(variant)")
                        throw failure("Measured target changed or became empty; abort this timing batch")
                    }
                    try require(SCNMatrix4EqualToMatrix4(camera.transform, frozenCamera)
                        && scene.allBallNodes.mapValues(\.simdWorldPosition) == frozenPositions,
                        "Frozen fixture moved during paired measurement")
                    spans.append(span)
                    rawTiming.append(["variant": variant, "frames": framesPerBatch,
                                      "gpuSpanMS": timing.gpuSpanMS, "cpuEncodeMS": timing.cpuEncodeMS,
                                      "cpuWallMS": timing.cpuWallMS,
                                      "batchWallMSIncludingHarness": timing.batchWallMSIncludingHarness,
                                      "perFrameTiming": timing.perFrameTiming])
                    if variant == "reference" {
                        a.append(span); allA.append(span)
                        encodeA.append(timing.cpuEncodeMS/Double(framesPerBatch)); wallA.append(timing.cpuWallMS/Double(framesPerBatch))
                        if nativeMac { nativeFramesA += timing.perFrameTiming }
                    } else {
                        b.append(span); allB.append(span)
                        encodeB.append(timing.cpuEncodeMS/Double(framesPerBatch)); wallB.append(timing.cpuWallMS/Double(framesPerBatch))
                        if nativeMac { nativeFramesB += timing.perFrameTiming }
                    }
                }
                if installedGuard == nil || nativeMac {
                    let change = (median(b) / median(a) - 1) * 100
                    changes.append(change)
                    var measuredCycle: [String: Any] = ["index": cycle, "order": order, "gpuMillisecondsPerRender": spans, "rawBatchTiming": rawTiming,
                                   "referenceMedianMS": median(a), "candidateMedianMS": median(b),
                                   "pairedChangePercent": change, "referenceEndpointDriftPercent": abs(a[1]-a[0])/median(a)*100]
                    if nativeMac {
                        measuredCycle["candidateEndpointDriftPercent"] = abs(b[1]-b[0])/median(b)*100
                        measuredCycle["sameLastTargetBitwiseExact"] = true
                    }
                    cycles.append(measuredCycle)
                } else {
                    cycles.append(["index": cycle, "order": order, "rawBatchTiming": rawTiming,
                                   "sameLastTargetBitwiseExact": true, "purpose": "image proof; no timing ranking"])
                }
                row["cycles"] = cycles
                row["completedCycles"] = cycles.count
                rows[rows.count - 1] = row // retain partial raw evidence if a later batch fails
            }
            if installedGuard == nil {
                row["pairedChangeMedianPercent"] = median(changes)
                row["referenceMedianMS"] = median(allA)
                row["candidateMedianMS"] = median(allB)
                row["referenceBatchMeanP50MS"] = percentile(allA, 0.5)
                row["referenceBatchMeanP95MS"] = percentile(allA, 0.95)
                row["candidateBatchMeanP50MS"] = percentile(allB, 0.5)
                row["candidateBatchMeanP95MS"] = percentile(allB, 0.95)
                row["referenceCPUEncodeMedianMSPerRender"] = median(encodeA)
                row["candidateCPUEncodeMedianMSPerRender"] = median(encodeB)
                row["referenceCPUWallMedianMSPerRender"] = median(wallA)
                row["candidateCPUWallMedianMSPerRender"] = median(wallB)
                row["referenceGPUNanosecondsPerTargetPixel"] = median(allA)*1_000_000/(size.width*size.height)
                row["candidateGPUNanosecondsPerTargetPixel"] = median(allB)*1_000_000/(size.width*size.height)
                row["pixelNormalizationScope"] = "Whole render-target pixels; not executed fragment count, cloth-only cost or universal throughput"
                row["percentileDefinition"] = "Distribution of six independently committed GPU-span means; not frame pacing or present latency"
                row["status"] = "completed; no visual or device-wide performance acceptance implied"
            } else if nativeMac {
                try require(nativeFramesA.count == 108 && nativeFramesB.count == 108,
                            "Native frame distributions require all 9 cycles, 2 slots per arm and 6 frames per slot")
                row["pairedChangeMedianPercent"] = median(changes)
                row["pairedChangeMinimumPercent"] = changes.min()!
                row["pairedChangeMaximumPercent"] = changes.max()!
                row["candidateFasterCycles"] = changes.filter { $0 < 0 }.count
                row["referenceMaximumEndpointDriftPercent"] = cycles.compactMap { $0["referenceEndpointDriftPercent"] as? Double }.max()!
                row["candidateMaximumEndpointDriftPercent"] = cycles.compactMap { $0["candidateEndpointDriftPercent"] as? Double }.max()!
                row["referenceFrameDistribution"] = try nativeFrameDistribution(nativeFramesA)
                row["candidateFrameDistribution"] = try nativeFrameDistribution(nativeFramesB)
                row["percentileDefinition"] = "Per independently committed synchronous offscreen frame: P50 median; P95/P99 nearest rank ceil(p*n)-1; n=108 per arm. Not batch means, present latency, sustained tail stability or displayed FPS."
                row["sameLastTargetChecks"] = cycleCount * 4
                row["performanceRankingAllowed"] = true
                row["probeCostScope"] = report["probeCostScope"]
                row["status"] = "completed native Mac full-room fixed-scene comparison; same-target RGBA exact; no whole-page or device-wide acceptance implied"
            } else {
                row["sameLastTargetChecks"] = cycleCount * 4
                row["performanceRankingAllowed"] = false
                row["status"] = "production-installed guard complete-scene image equality passed; no performance ranking"
            }
            rows[rows.count - 1] = row
            print("[ClothSupportResearch] fixture=\(fixture) phase=completed")
        }
        nativeStudyCompleted = nativeMac && testRun?.totalFailureCount == 0
    }

    #if DEBUG
    private func productionInstalledGuardProgram() throws -> InstalledGuardProgram {
        let donor = AngleTrainingScene()
        donor.configureDailyClearanceRendering(asynchronousReflection: false)
        donor.configureClothSupportExperiment(request: .guardCombo)
        donor.setupScene(mobileRendering: true, roomStyle: .tournament)
        try require(donor.applyClothColor(.green), "Installed guard donor cloth appearance unavailable")
        try require(donor.applyTableStyle(.charcoal), "Installed guard donor table appearance unavailable")
        let state = donor.safeClothSupportState
        let contact = try XCTUnwrap(donor.contactOcclusion)
        var seen = Set<ObjectIdentifier>()
        var surfaces: [String] = []
        var normalIntensities: [CGFloat] = []
        var geometryModifiers: [String] = []
        donor.rootNode.enumerateHierarchy { node, _ in
            for material in node.geometry?.materials ?? []
            where material.name == "TaiNi" && seen.insert(ObjectIdentifier(material)).inserted {
                if let source = material.shaderModifiers?[.surface] { surfaces.append(source) }
                normalIntensities.append(material.normal.intensity)
                if let geometry = material.shaderModifiers?[.geometry] { geometryModifiers.append(geometry) }
            }
        }
        let expectedVariant = "legacy-cone-plus-safe-hoisted-finite-domain-guard-r1-20261113"
        let expectedSurface = "ca5acc70043f0da620e2c6501188063c78027c8e26b62233d128ced01f81aabd"
        let surfaceHashes = surfaces.map { ClothResearchShaders.sha256($0) }
        let metadata: [String: Any] = [
            "source": "Production DEBUG configureClothSupportExperiment(request: .guardCombo), setupScene, applyClothColor(.green), applyTableStyle(.charcoal), then read actual TaiNi shaderModifiers[.surface]",
            "requested": state.requested, "requestedVariant": state.requestedVariant,
            "effective": state.effective, "variant": state.variant,
            "fallbackReason": state.fallbackReason ?? "none", "capacity": state.capacity,
            "profile": state.profile, "sampling": state.sampling,
            "contactSlots": contact.capacity, "clothMaterials": seen.count,
            "surfaceSHA256": surfaceHashes, "expectedSurfaceSHA256": expectedSurface,
            "normalIntensities": normalIntensities, "geometryModifierCount": geometryModifiers.count,
            "probeScope": "Donor establishes production installation provenance only. Rendering compares this installed surface on a separate unchanged R full-room scene. Cache/probe variant behavior is verified by separate unit/UI selectors."
        ]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: metadata,
            options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "cloth-guard-production-installed-program.json"
        attachment.lifetime = .keepAlways; add(attachment)
        try require(donor.clothSupportRequest == .guardCombo && state.requested && state.effective,
                    "Guard must be effective through the production installed path: \(metadata)")
        try require(state.requestedVariant == "guard-combo" && state.variant == expectedVariant
                    && state.fallbackReason == nil && state.capacity == 16 && contact.capacity == 16
                    && state.profile == "R" && state.sampling == "reference",
                    "Unexpected installed guard recipe: \(metadata)")
        try require(!surfaces.isEmpty && surfaces.count == seen.count
                    && surfaceHashes.allSatisfy { $0 == expectedSurface },
                    "Production-installed complete guard surface differs from the independently validated native material")
        try require(normalIntensities.allSatisfy { abs($0 - 0.65) < 0.00001 }
                    && geometryModifiers.count == seen.count,
                    "Installed donor must retain production cloth material and geometry lift")
        return InstalledGuardProgram(surface: surfaces[0], identity: state.variant, metadata: metadata)
    }
    #endif

    /// Same fragment recurrence, target and ABBA/BAAB gates as the independently
    /// validated native_scene_benchmark.swift calibrate(), ported to XCTest.
    private func calibrateNativeGPU(device: MTLDevice) throws -> [String: Any] {
        var samples: [[String: Any]] = [], warmups: [[String: Any]] = []
        var ratios: [Double] = []
        var report: [String: Any] = ["schema": 1, "passed": false, "device": device.name,
            "scope": "Native fullscreen Metal fragment recurrence: 32 versus 1024 iterations on the same 512x512 RGBA16F target. Confirms timestamps respond to work; not an App benchmark.",
            "source": "scripts/research/cloth_lowdim_20261113/native_scene_benchmark.swift calibrate()",
            "executionPlatform": "MacNative-isiOSAppOnMac", "isiOSAppOnMac": ProcessInfo.processInfo.isiOSAppOnMac]
        defer {
            report["raw"] = samples; report["warmups"] = warmups; report["pairedRatios"] = ratios
            attachStrictReport(report, name: "cloth-native-mac-fill-calibration.json")
        }
        do {
            let source = """
            #include <metal_stdlib>
            using namespace metal;
            vertex float4 vertex_main(uint i [[vertex_id]]) {
              float2 p[3]={float2(-1,-1),float2(3,-1),float2(-1,3)};return float4(p[i],0,1);
            }
            fragment half4 fragment_main(float4 p [[position]],constant uint &iterations [[buffer(0)]]) {
              float x=0.01+p.x*0.00012+p.y*0.00017;
              for(uint i=0;i<iterations;i++){x=sin(x*1.0101+0.0001*float(i))*0.999+0.02;}
              return half4(half(x),half(x*0.7),half(x*0.3),1);
            }
            """
            report["shaderSHA256"] = ClothResearchShaders.sha256(source)
            let library = try device.makeLibrary(source: source, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "vertex_main")
            descriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
            descriptor.colorAttachments[0].pixelFormat = .rgba16Float
            let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            let queue = try XCTUnwrap(device.makeCommandQueue())
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 512, height: 512, mipmapped: false)
            td.storageMode = .private; td.usage = .renderTarget
            let texture = try XCTUnwrap(device.makeTexture(descriptor: td))
            report["targetAllocatedBytes"] = texture.allocatedSize
            try require(texture.allocatedSize > 0, "Native calibration target must report a real allocation")
            func sample(_ iterations: UInt32, cycle: Int, slot: Int, warmup: Bool) throws -> Double {
                let command = try XCTUnwrap(queue.makeCommandBuffer())
                let pass = MTLRenderPassDescriptor()
                pass.colorAttachments[0].texture = texture
                pass.colorAttachments[0].loadAction = .dontCare; pass.colorAttachments[0].storeAction = .store
                let start = CACurrentMediaTime()
                let encoder = try XCTUnwrap(command.makeRenderCommandEncoder(descriptor: pass))
                var n = iterations
                encoder.setRenderPipelineState(pipeline)
                encoder.setFragmentBytes(&n, length: 4, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                encoder.endEncoding()
                let encoded = CACurrentMediaTime()
                command.commit(); command.waitUntilCompleted()
                let ended = CACurrentMediaTime()
                let span = (command.gpuEndTime-command.gpuStartTime)*1000
                let row: [String: Any] = ["iterations": iterations, "cycle": cycle, "slot": slot,
                    "gpuMS": span, "gpuStartTime": command.gpuStartTime, "gpuEndTime": command.gpuEndTime,
                    "cpuEncodeMS": (encoded-start)*1000, "cpuCommitWaitMS": (ended-encoded)*1000,
                    "syncWallMS": (ended-start)*1000, "commandStatus": command.status.rawValue]
                if warmup { warmups.append(row) } else { samples.append(row) }
                if command.status != .completed { throw command.error ?? failure("Calibration command failed") }
                try require(span.isFinite && span > 0 && command.gpuStartTime.isFinite && command.gpuStartTime > 0
                    && command.gpuEndTime.isFinite && command.gpuEndTime > command.gpuStartTime,
                    "Unavailable native GPU timestamps; do not substitute CPU time")
                return span
            }
            for index in 0..<4 {
                _ = try sample(32, cycle: index, slot: 0, warmup: true)
                _ = try sample(1024, cycle: index, slot: 1, warmup: true)
            }
            for cycle in 0..<9 {
                var low: [Double] = [], high: [Double] = []
                let order: [UInt32] = cycle.isMultiple(of: 2) ? [32,1024,1024,32] : [1024,32,32,1024]
                for (slot, iterations) in order.enumerated() {
                    let span = try sample(iterations, cycle: cycle, slot: slot, warmup: false)
                    if iterations == 32 { low.append(span) } else { high.append(span) }
                }
                ratios.append(median(high)/median(low))
            }
            let buffer = try XCTUnwrap(device.makeBuffer(length: 256, options: .storageModeShared))
            let command = try XCTUnwrap(queue.makeCommandBuffer())
            let blit = try XCTUnwrap(command.makeBlitCommandEncoder())
            blit.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 256,y: 256,z: 0),
                sourceSize: MTLSize(width: 1,height: 1,depth: 1), to: buffer, destinationOffset: 0,
                destinationBytesPerRow: 256, destinationBytesPerImage: 256)
            blit.endEncoding(); command.commit(); command.waitUntilCompleted()
            if command.status != .completed { throw command.error ?? failure("Calibration readback failed") }
            let bits = Array(UnsafeBufferPointer(start: buffer.contents().assumingMemoryBound(to: UInt16.self), count: 4))
            let passed = median(ratios) > 1.5 && ratios.allSatisfy { $0 > 1.2 } && bits[0] != 0 && bits[3] == 0x3c00
            report["medianHeavyLightRatio"] = median(ratios); report["lastPixelHalfBits"] = bits
            report["passed"] = passed
            try require(passed, "Native GPU workload calibration failed; no scene ranking")
            report["raw"] = samples; report["warmups"] = warmups; report["pairedRatios"] = ratios
            return report
        } catch {
            report["error"] = String(describing: error)
            throw error
        }
    }

    private func attachStrictReport(_ report: [String: Any], name: String) {
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        } catch {
            let fallback = XCTAttachment(string: "JSON serialization failed: \(error)\nRaw report: \(report)")
            fallback.name = name + ".serialization-failure.txt"; fallback.lifetime = .keepAlways; add(fallback)
            XCTFail("Required native research report could not be serialized: \(error)")
        }
    }

    private func nativeFrameDistribution(_ frames: [[String: Any]]) throws -> [String: Any] {
        var result: [String: Any] = ["n": frames.count]
        for key in ["gpuSpanMS", "cpuEncodeMS", "cpuCommitWaitMS", "cpuWallMS", "cpuFullSyncWallMS"] {
            let values = frames.compactMap { $0[key] as? Double }
            try require(values.count == frames.count && !values.isEmpty
                && values.allSatisfy { $0.isFinite && $0 > 0 }, "Missing/nonpositive native frame metric: \(key)")
            let sorted = values.sorted()
            result[key] = ["n": values.count, "p50": median(values),
                "p95": sorted[Int(ceil(0.95*Double(sorted.count)))-1],
                "p99": sorted[Int(ceil(0.99*Double(sorted.count)))-1],
                "minimum": sorted.first!, "maximum": sorted.last!]
        }
        return result
    }

    private func nativeMacFixtureMatrix() throws -> [Fixture] {
        let environment = ProcessInfo.processInfo.environment
        let large = environment["CLOTH_RESEARCH_MAC_2800"] ?? environment["TEST_RUNNER_CLOTH_RESEARCH_MAC_2800"] ?? "0"
        try require(["0", "1"].contains(large), "CLOTH_RESEARCH_MAC_2800 must be explicitly 0 or 1")
        var sizes = [CGSize(width: 700, height: 400), CGSize(width: 1400, height: 800)]
        if large == "1" { sizes.append(CGSize(width: 2800, height: 1600)) }
        return sizes.flatMap { size in
            [Fixture(activeBalls: 2, layout: "pair", pose: "near", size: size),
             Fixture(activeBalls: 16, layout: "scatter", pose: "overview", size: size)]
        } + [Fixture(activeBalls: 16, layout: "rack", pose: "overview", size: CGSize(width: 1400, height: 800))]
    }

    private struct Fixture {
        let activeBalls: Int
        let layout: String
        let pose: String
        let size: CGSize
        var id: String { "\(layout)-\(activeBalls)-\(pose)-\(Int(size.width))x\(Int(size.height))" }
    }

    private func fixtureMatrix() throws -> [Fixture] {
        let env = ProcessInfo.processInfo.environment
        let setting = env["CLOTH_RESEARCH_SIZE"] ?? env["TEST_RUNNER_CLOTH_RESEARCH_SIZE"]
        var sizes: [CGSize]
        if let setting, setting != "native" {
            let parts = setting.lowercased().split(separator: "x").compactMap { Int($0) }
            try require(parts.count == 2 && parts.allSatisfy { (256...4096).contains($0) }, "Use native or WIDTHxHEIGHT")
            sizes = [CGSize(width: parts[0], height: parts[1])]
        } else if setting == "native" {
            sizes = [UIScreen.main.nativeBounds.size]
        } else {
            #if targetEnvironment(simulator)
            sizes = [CGSize(width: 700, height: 400), CGSize(width: 1400, height: 800)]
            #else
            sizes = [UIScreen.main.nativeBounds.size]
            #endif
        }
        var fixtures = sizes.flatMap { size in
            [Fixture(activeBalls: 2, layout: "pair", pose: "near", size: size),
             Fixture(activeBalls: 16, layout: "scatter", pose: "overview", size: size)]
        }
        let matrix = env["CLOTH_RESEARCH_MATRIX"] ?? env["TEST_RUNNER_CLOTH_RESEARCH_MATRIX"] ?? "smoke"
        try require(["smoke", "extended"].contains(matrix), "Use smoke or extended matrix")
        if matrix == "extended" {
            fixtures += sizes.map { Fixture(activeBalls: 8, layout: "scatter", pose: "overview", size: $0) }
            let medium = sizes.last!
            fixtures += [Fixture(activeBalls: 16, layout: "rack", pose: "overview", size: medium),
                         Fixture(activeBalls: 2, layout: "pair", pose: "pocket", size: medium)]
            if setting == nil {
                fixtures.append(Fixture(activeBalls: 16, layout: "scatter", pose: "overview", size: CGSize(width: 2800, height: 1600)))
            }
        }
        return fixtures
    }

    private func validFrame(_ frame: Frame) throws {
        try require(frame.uniqueColors > 128 && frame.greenPixels > frame.pixelCount / 100,
                    "Native target lacks visible production green cloth / image variation")
        try require(frame.magentaPixels == 0, "Native target contains SceneKit shader-error magenta")
    }

    private func attach(_ frame: Frame, _ name: String) {
        let attachment = XCTAttachment(image: frame.image)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func difference(_ a: Frame, _ b: Frame) -> (maximum: Int, changedPixels: Int) {
        var maximum = 0, changed = 0
        for offset in stride(from: 0, to: a.bgra.count, by: 4) {
            var pixelMaximum = 0
            for channel in 0..<4 { pixelMaximum = max(pixelMaximum, abs(Int(a.bgra[offset+channel])-Int(b.bgra[offset+channel]))) }
            maximum = max(maximum, pixelMaximum)
            if pixelMaximum > 0 { changed += 1 }
        }
        return (maximum, changed)
    }

    private func median(_ values: [Double]) -> Double {
        let s = values.sorted(); return (s[(s.count-1)/2] + s[s.count/2])/2
    }

    private func percentile(_ values: [Double], _ fraction: Double) -> Double {
        let s = values.sorted(), position = Double(values.count-1)*fraction
        let lo = Int(position.rounded(.down)), hi = Int(position.rounded(.up))
        return s[lo] + (s[hi]-s[lo])*(position-Double(lo))
    }

    private func matrixValues(_ m: SCNMatrix4) -> [Float] {
        [m.m11,m.m12,m.m13,m.m14,m.m21,m.m22,m.m23,m.m24,m.m31,m.m32,m.m33,m.m34,m.m41,m.m42,m.m43,m.m44]
    }

    private func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw failure(message) }
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "ClothSupportPerformanceResearch", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func cameraMetadata(_ camera: SCNCamera) -> [String: Any] {
        ["wantsHDR": camera.wantsHDR, "exposureOffset": camera.exposureOffset,
         "minimumExposure": camera.minimumExposure, "maximumExposure": camera.maximumExposure,
         "wantsExposureAdaptation": camera.wantsExposureAdaptation,
         "exposureAdaptationBrighteningSpeedFactor": camera.exposureAdaptationBrighteningSpeedFactor,
         "exposureAdaptationDarkeningSpeedFactor": camera.exposureAdaptationDarkeningSpeedFactor,
         "averageGray": camera.averageGray, "whitePoint": camera.whitePoint,
         "bloomIntensity": camera.bloomIntensity, "bloomThreshold": camera.bloomThreshold,
         "bloomBlurRadius": camera.bloomBlurRadius,
         "screenSpaceAmbientOcclusionIntensity": camera.screenSpaceAmbientOcclusionIntensity,
         "screenSpaceAmbientOcclusionRadius": camera.screenSpaceAmbientOcclusionRadius,
         "screenSpaceAmbientOcclusionBias": camera.screenSpaceAmbientOcclusionBias,
         "screenSpaceAmbientOcclusionDepthThreshold": camera.screenSpaceAmbientOcclusionDepthThreshold,
         "screenSpaceAmbientOcclusionNormalThreshold": camera.screenSpaceAmbientOcclusionNormalThreshold]
    }

    private struct Frame {
        let image: UIImage
        let bgra: [UInt8]
        var pixelCount: Int { bgra.count / 4 }
        var greenPixels: Int { count { r,g,b in g > 35 && Int(g)*10 > Int(r)*11 && Int(g)*10 > Int(b)*11 } }
        var redPixels: Int { count { r,g,b in r > 100 && Int(r) > Int(g)*2 && Int(r) > Int(b)*2 } }
        var magentaPixels: Int { count { r,g,b in r > 230 && g < 30 && b > 230 } }
        var uniqueColors: Int {
            Set(stride(from: 0, to: bgra.count, by: 4).map { offset in
                (UInt16(bgra[offset+2] >> 3) << 11) | (UInt16(bgra[offset+1] >> 2) << 5) | UInt16(bgra[offset] >> 3)
            }).count
        }
        private func count(_ predicate: (UInt8, UInt8, UInt8) -> Bool) -> Int {
            stride(from: 0, to: bgra.count, by: 4).reduce(0) { total, offset in
                total + (predicate(bgra[offset+2], bgra[offset+1], bgra[offset]) ? 1 : 0)
            }
        }
    }

    private struct BatchTiming {
        let gpuSpanMS: Double
        let cpuEncodeMS: Double
        let cpuWallMS: Double
        let batchWallMSIncludingHarness: Double
        let perFrameTiming: [[String: Any]]
    }

    @MainActor private final class RenderTarget {
        let renderer: SCNRenderer
        let queue: MTLCommandQueue
        let color: MTLTexture
        let multisample: MTLTexture
        let depth: MTLTexture
        let staging: MTLBuffer
        let width: Int, height: Int, rowBytes: Int
        var allocatedBytes: [String: Int] {
            ["color": color.allocatedSize, "MSAA": multisample.allocatedSize, "depthStencil": depth.allocatedSize,
             "staging": staging.allocatedSize, "total": color.allocatedSize + multisample.allocatedSize + depth.allocatedSize + staging.allocatedSize]
        }

        init(device: MTLDevice, scene: AngleTrainingScene, size: CGSize) throws {
            width = Int(size.width); height = Int(size.height); rowBytes = ((Int(size.width)*4+255)/256)*256
            queue = try XCTUnwrap(device.makeCommandQueue())
            renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = scene; renderer.pointOfView = scene.cameraNode
            renderer.delegate = scene.contactOcclusion; renderer.autoenablesDefaultLighting = false
            renderer.isPlaying = false
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead]; descriptor.storageMode = .private
            color = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
            descriptor.textureType = .type2DMultisample; descriptor.sampleCount = 4
            multisample = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
            descriptor.pixelFormat = .depth32Float_stencil8; descriptor.usage = .renderTarget
            depth = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
            staging = try XCTUnwrap(device.makeBuffer(length: rowBytes*height, options: .storageModeShared))
        }

        func render(frames: Int, includeNativeTiming: Bool = false, atTime: TimeInterval = 1) throws -> BatchTiming {
            // SceneKit consumes an internal in-flight slot on every render.
            // Commit each frame immediately so its completion can release that
            // slot before another render asks for it. A shared uncommitted
            // command buffer deadlocked the r3 host during its first warmup.
            var gpuSpanMS = 0.0, cpuEncodeMS = 0.0, cpuWallMS = 0.0
            var perFrameTiming: [[String: Any]] = []
            let batchStart = CACurrentMediaTime()
            for frame in 0..<frames {
                // Every frame starts with a completed sentinel clear, outside
                // that frame's CPU/GPU timing. The final target cannot reuse
                // an earlier valid image when the final render is a no-op.
                let sentinelStart = CACurrentMediaTime()
                try clearTarget()
                let sentinelWallMS = (CACurrentMediaTime()-sentinelStart)*1000
                let encodeStart = CACurrentMediaTime()
                let command = try XCTUnwrap(queue.makeCommandBuffer())
                command.label = "ClothSupportProductionScene-frame-\(frame)"
                let pass = MTLRenderPassDescriptor()
                pass.colorAttachments[0].texture = multisample; pass.colorAttachments[0].resolveTexture = color
                pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .multisampleResolve
                pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
                pass.depthAttachment.texture = depth; pass.depthAttachment.loadAction = .clear
                pass.depthAttachment.storeAction = .dontCare; pass.depthAttachment.clearDepth = 1
                pass.stencilAttachment.texture = depth; pass.stencilAttachment.loadAction = .clear
                pass.stencilAttachment.storeAction = .dontCare; pass.stencilAttachment.clearStencil = 0
                renderer.render(atTime: atTime, viewport: CGRect(x: 0, y: 0, width: width, height: height),
                                commandBuffer: command, passDescriptor: pass)
                let encodeEnd = CACurrentMediaTime()
                command.commit(); command.waitUntilCompleted()
                let wallEnd = CACurrentMediaTime()
                try completed(command)
                let span = (command.gpuEndTime-command.gpuStartTime)*1000
                guard span.isFinite, span > 0, command.gpuStartTime > 0 else {
                    throw NSError(domain: "ClothSupportPerformanceResearch", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "Unavailable/nonpositive GPU timestamps; no CPU-time substitution"])
                }
                let encode = (encodeEnd-encodeStart)*1000
                let wall = (wallEnd-encodeStart)*1000
                gpuSpanMS += span; cpuEncodeMS += encode; cpuWallMS += wall
                var record: [String: Any] = ["frame": frame, "gpuStartTime": command.gpuStartTime,
                    "gpuEndTime": command.gpuEndTime, "gpuSpanMS": span,
                    "cpuEncodeMS": encode, "cpuWallMS": wall, "sentinelClearWallMSExcluded": sentinelWallMS]
                if includeNativeTiming {
                    record["cpuCommitWaitMS"] = (wallEnd-encodeEnd)*1000
                    record["cpuFullSyncWallMS"] = (wallEnd-sentinelStart)*1000
                }
                perFrameTiming.append(record)
            }
            let batchEnd = CACurrentMediaTime()
            return BatchTiming(gpuSpanMS: gpuSpanMS, cpuEncodeMS: cpuEncodeMS,
                               cpuWallMS: cpuWallMS, batchWallMSIncludingHarness: (batchEnd-batchStart)*1000,
                               perFrameTiming: perFrameTiming)
        }

        private func clearTarget() throws {
            let clear = try XCTUnwrap(queue.makeCommandBuffer())
            clear.label = "ClothSupportSentinelOutsideTiming"
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = color
            pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 1, 1)
            let encoder = try XCTUnwrap(clear.makeRenderCommandEncoder(descriptor: pass)); encoder.endEncoding()
            clear.commit(); clear.waitUntilCompleted(); try completed(clear)
        }

        func readback() throws -> Frame {
            let command = try XCTUnwrap(queue.makeCommandBuffer())
            let blit = try XCTUnwrap(command.makeBlitCommandEncoder())
            blit.copy(from: color, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0,y: 0,z: 0),
                      sourceSize: MTLSize(width: width,height: height,depth: 1), to: staging, destinationOffset: 0,
                      destinationBytesPerRow: rowBytes, destinationBytesPerImage: rowBytes*height)
            blit.endEncoding(); command.commit(); command.waitUntilCompleted(); try completed(command)
            let data = Data(bytes: staging.contents(), count: rowBytes*height)
            let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
            let cg = try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: rowBytes, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
            var tight = [UInt8](); tight.reserveCapacity(width*height*4)
            for row in 0..<height { tight.append(contentsOf: data[(row*rowBytes)..<(row*rowBytes+width*4)]) }
            return Frame(image: UIImage(cgImage: cg), bgra: tight)
        }

        private func completed(_ command: MTLCommandBuffer) throws {
            if command.status != .completed {
                throw command.error ?? NSError(domain: "ClothSupportPerformanceResearch", code: 3,
                                                userInfo: [NSLocalizedDescriptionKey: "Metal command failed"])
            }
        }
    }
}
