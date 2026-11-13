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
