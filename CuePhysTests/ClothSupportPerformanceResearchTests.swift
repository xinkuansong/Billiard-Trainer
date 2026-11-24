import XCTest
import SceneKit
import Metal
import UIKit
import CryptoKit
import Combine
@testable import CuePhys

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

    // BEGIN H18 R7 INTEGRATION
    func testNativeClothLTCR7a() throws {
        try runNativeClothLTCR7Cost(finalIntegration: false)
    }

    func testNativeClothLTCR7Final() throws {
        try runNativeClothLTCR7Cost(finalIntegration: true)
    }

    private func runNativeClothLTCR7Cost(finalIntegration: Bool) throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("R7 cost requires native Metal")
        #else
        guard ProcessInfo.processInfo.isiOSAppOnMac else { throw XCTSkip("Native Mac scope") }
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let referenceScene = AngleTrainingScene(); referenceScene.clothLTCRequested = false
        referenceScene.configureDailyClearanceRendering(asynchronousReflection: false)
        referenceScene.setupScene(recipe: .liveReference, roomStyle: .tournament)
        @MainActor func cloth(_ scene: AngleTrainingScene) -> [SCNMaterial] {
            var result = [SCNMaterial](), seen = Set<ObjectIdentifier>()
            scene.rootNode.enumerateChildNodes { node,_ in
                for m in node.geometry?.materials ?? [] where m.name == "TaiNi" && seen.insert(ObjectIdentifier(m)).inserted { result.append(m) }
            }
            return result
        }
        let baseline = try XCTUnwrap(cloth(referenceScene).first?.shaderModifiers?[.surface])
        try require(ClothResearchShaders.sha256(baseline) == ClothShadowProgram.outputSHA256, "R7 exact baseline")
        let scene = AngleTrainingScene()
        try require(scene.clothLTCRequested, "Production default requested")
        scene.configureDailyClearanceRendering(asynchronousReflection: false)
        scene.setupScene(recipe: .liveReference, roomStyle: .tournament)
        try require(scene.clothLTCState == ClothSpecularLTC.identity, "Production installation")
        let mats = cloth(scene), resource = try XCTUnwrap(scene.clothSpecularLTC)
        let candidate = try XCTUnwrap(mats.first?.shaderModifiers?[.surface])
        try require(mats.allSatisfy { $0.shaderModifiers?[.surface] == candidate }, "Shared cloth source")
        try require(ClothSpecularLTC.replacingSpecular(in: baseline) == candidate, "Current generator transformation")
        try require(ClothSpecularLTC.replacingSpecular(in: baseline + " ") == nil && ClothSpecularLTC.replacingSpecular(in: candidate) == nil, "Drift and double-application fallback")
        let duplicate = try ClothSpecularLTC.acquire(emitter: MobileReferenceLighting.emitterGeometry,
            radiance: StaticClothIrradiance.expectedRadiance, device: device)
        try require(resource === duplicate, "LUT shared on same device")
        XCTAssertThrowsError(try ClothSpecularLTC.acquire(emitter: "different", radiance: StaticClothIrradiance.expectedRadiance, device: device))
        XCTAssertThrowsError(try ClothSpecularLTC.acquire(emitter: MobileReferenceLighting.emitterGeometry, radiance: 1, device: device))
        XCTAssertThrowsError(try ClothSpecularLTC.acquire(emitter: MobileReferenceLighting.emitterGeometry, radiance: StaticClothIrradiance.expectedRadiance, device: device, assetURL: nil))
        let invalid = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([0, 1]).write(to: invalid)
        defer { try? FileManager.default.removeItem(at: invalid) }
        XCTAssertThrowsError(try ClothSpecularLTC.acquire(emitter: MobileReferenceLighting.emitterGeometry,
            radiance: StaticClothIrradiance.expectedRadiance, device: device, assetURL: invalid))
        try require(scene.applyClothColor(.green) && scene.applyTableStyle(.charcoal), "Appearance")
        let camera = try XCTUnwrap(scene.cameraNode), size = CGSize(width: 1400, height: 800)
        scene.cameraRig?.viewportSize = size; scene.setCameraMode(.perspective3D, animated: false)
        let appPose = camera.simdTransform
        let appFOV = camera.camera!.fieldOfView
        let target = try RenderTarget(device: device, scene: scene, size: size)
        let probe = H17AnimationProbe(contact: scene.contactOcclusion); target.renderer.delegate = probe
        let carrier = SCNNode(); scene.rootNode.addChildNode(carrier)
        let keys = ["cueBall"] + (1...15).map { "_\($0)" }
        for key in keys { carrier.addChildNode(try XCTUnwrap(scene.allBallNodes[key])) }
        @MainActor func balls(_ count: Int) {
            scene.hideAllBalls()
            for (i,key) in keys.prefix(count).enumerated() {
                scene.allBallNodes[key]?.opacity = 1
                let x: Float = count == 2 ? Float(i) * 0.075 : Float(i / 4) * 0.6 - 0.9
                let z: Float = count == 2 ? 0 : Float(i % 4) * 0.3 - 0.45
                scene.showBall(key: key, scenePosition: SCNVector3(x, scene.surfaceY + AngleSceneCalculator.ballRadius, z))
            }
            SCNTransaction.flush()
        }
        @MainActor func restart() {
            carrier.removeAllActions(); carrier.simdPosition = .zero
            carrier.runAction(.customAction(duration: 600) { node, elapsed in probe.actionStep(node, elapsed: Double(elapsed)) })
            SCNTransaction.flush()
        }
        @MainActor func install(_ source: String) {
            for m in mats { var modifiers = m.shaderModifiers ?? [:]; modifiers[.surface] = source; m.shaderModifiers = modifiers }
            SCNTransaction.flush()
        }
        // Eye and look target in world metres; each boundary is also exercised on the original source.
        let poses: [(String, SIMD3<Float>, SIMD3<Float>, Int)] = finalIntegration ? [
            ("near-empty-fallback", SIMD3(0.16, 1.15, 0.3), SIMD3(0, 0.8, 0), 0),
            ("near-ltc-increment", SIMD3(0.16, 1.15, 0.3), SIMD3(0, 0.8, 0), 2),
            ("near-16-ltc-increment", SIMD3(0.16, 1.15, 0.3), SIMD3(0, 0.8, 0), 16)
        ] : [
            ("near", SIMD3(0.16, 1.15, 0.3), SIMD3(0, 0.8, 0), 2),
            ("near-16", SIMD3(0.16, 1.15, 0.3), SIMD3(0, 0.8, 0), 16),
            ("pitch30", SIMD3(0, 1.15, 0.604), SIMD3(0, 0.8, 0), 2),
            ("pitch65", SIMD3(0, 1.15, 0.164), SIMD3(0, 0.8, 0), 2),
            ("height-upper", SIMD3(0, 1.299, 0.499), SIMD3(0, 0.8, 0), 2),
            ("height-old-upper-fallback", SIMD3(0, 1.449, 0.649), SIMD3(0, 0.8, 0), 2),
            ("height-lower", SIMD3(0, 1.051, 0.251), SIMD3(0, 0.8, 0), 2),
            ("low-fallback", SIMD3(0, 1.05, 1.8), SIMD3(0, 0.8, 0), 2),
            ("overview-fallback", SIMD3(1.8, 2.7, 2.1), SIMD3(0, 0.8, 0), 16),
            ("ortho-fallback", SIMD3(0, 3.5, 0.001), SIMD3(0, 0.8, 0), 16),
            ("app-default", SIMD3.zero, SIMD3.zero, 2)
        ]
        var rows = [[String: Any]](), completed = false, epoch: Double = 20
        defer {
            install(candidate); carrier.removeAllActions()
            attachStrictReport(["study": finalIntegration ? "H18-R7-final" : "H18-R7a", "completed": completed && testRun?.totalFailureCount == 0,
                "device": device.name, "rows": rows, "preparationMS": resource.preparationMilliseconds,
                "lookupBytes": resource.allocatedBytes, "sourceSHA": ClothResearchShaders.sha256(candidate)], name: "h18-r7a.json")
        }
        for (name, eye, aim, count) in poses {
            // Compare LTC to the same function-isolated reference integrator,
            // so the mathematical approximation does not take credit for code layout.
            let reference = name.contains("ltc-increment")
                ? candidate.replacingOccurrences(of: "if(clothLTCCloseView &&", with: "if(false && clothLTCCloseView &&") : baseline
            balls(count); camera.camera?.usesOrthographicProjection = name == "ortho-fallback"
            camera.camera?.orthographicScale = 3.3
            if name == "app-default" { camera.simdTransform = appPose; camera.camera?.fieldOfView = appFOV }
            else {
                let d = eye - aim
                let pose = TwoViewCamera.Pose.looking(eye: eye, yaw: atan2(d.z, d.x), pitch: -atan2(d.y, hypot(d.x, d.z)), fov: 50)
                camera.simdTransform = pose.transform; camera.camera?.fieldOfView = 50
                try require(simd_dot(pose.forward, simd_normalize(-d)) > 0.99999, "Real camera transform")
            }
            SCNTransaction.flush(); target.researchTime = epoch; restart()
            install(reference); _ = try target.render(frames: 3); let a = try target.readback()
            _ = try target.render(frames: 1); let aa = try target.readback()
            install(candidate); _ = try target.render(frames: 3); let b = try target.readback()
            install(reference); _ = try target.render(frames: 3); let restored = try target.readback()
            let delta = difference(a,b)
            if name == "near" || name.contains("ltc-increment") { try require(delta.changedPixels > 100, "LTC actually executes in the close view") }
            try require(difference(a,aa).maximum == 0 && difference(a,restored).maximum == 0, "AA/restoration")
            if name.contains("fallback") { try require(delta.maximum == 0, "Fallback is original pixels") }
            attach(a, "h18-r7a-\(name)-A"); attach(b, "h18-r7a-\(name)-B")
            var times = [[String: Any]]()
            for cycle in 0..<6 { for kind in cycle % 2 == 0 ? ["AA","AB"] : ["AB","AA"] {
                for arm in cycle % 2 == 0 ? [false,true,true,false] : [true,false,false,true] {
                    epoch += 10; target.researchTime = epoch; restart()
                    install(kind == "AB" && arm ? candidate : reference)
                    for f in 0..<24 { target.researchTime = epoch + Double(f)/60; _ = try target.render(frames: 1) }
                    var samples = [[String: Any]]()
                    for f in 0..<32 { target.researchTime = epoch + Double(f+24)/60; samples += try target.render(frames: 1, includeNativeTiming: true).perFrameTiming }
                    times.append(["kind": kind, "cycle": cycle, "arm": arm ? "B" : "A", "frames": samples, "thermal": ProcessInfo.processInfo.thermalState.rawValue])
                }
            }}
            rows.append(["pose": name, "reference": name.contains("ltc-increment") ? "function-isolated original integrator" : "C1/H9", "maximum": delta.maximum, "changedPixels": delta.changedPixels,
                "eye": [camera.simdPosition.x, camera.simdPosition.y, camera.simdPosition.z], "down": camera.simdTransform.columns.2.y,
                "times": times])
        }
        // Actual material refresh on capacity growth must discard all LTC resources and shader bindings.
        let extra = (0..<20).map { _ in PositionPlayBall.instanceKey(number: 1) }
        scene.configureBallInstances(extra)
        try require(scene.contactOcclusion!.capacity > 16 && scene.clothSpecularLTC == nil && scene.clothLTCState != ClothSpecularLTC.identity, "Expanded capacity fallback")
        try require(cloth(scene).allSatisfy { !($0.shaderModifiers?[.surface]?.contains("bool clothLTCCloseView=") ?? true) && $0.value(forKey: "h18Table0") == nil }, "Expanded materials clean")
        completed = true
        #endif
    }

    func testNativeClothLTCR7b() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("R7 native production material verification")
        #else
        guard ProcessInfo.processInfo.isiOSAppOnMac else { throw XCTSkip("Native Mac scope") }
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        @MainActor func materials(_ scene: AngleTrainingScene) -> [SCNMaterial] {
            var result = [SCNMaterial](), seen = Set<ObjectIdentifier>()
            scene.rootNode.enumerateChildNodes { n,_ in for m in n.geometry?.materials ?? [] where m.name == "TaiNi" && seen.insert(ObjectIdentifier(m)).inserted { result.append(m) } }
            return result
        }
        let reference = AngleTrainingScene(); reference.clothLTCRequested = false
        reference.configureDailyClearanceRendering(asynchronousReflection: false)
        reference.setupScene(recipe: .liveReference, roomStyle: .tournament)
        let baseline = try XCTUnwrap(materials(reference).first?.shaderModifiers?[.surface])
        let scene = AngleTrainingScene()
        scene.configureDailyClearanceRendering(asynchronousReflection: false)
        scene.setupScene(recipe: .liveReference, roomStyle: .tournament)
        try require(scene.clothLTCState == ClothSpecularLTC.identity, "R7b shared installation")
        let cloth = materials(scene), ltc = try XCTUnwrap(scene.clothSpecularLTC)
        let candidate = try XCTUnwrap(cloth.first?.shaderModifiers?[.surface])
        let identifiers = cloth.map(ObjectIdentifier.init)
        let target = try RenderTarget(device: device, scene: scene, size: CGSize(width: 700, height: 400))
        scene.cameraRig?.viewportSize = CGSize(width: 700, height: 400)
        scene.setCameraMode(.perspective3D, animated: false)
        let camera = try XCTUnwrap(scene.cameraNode)
        @MainActor func pose(height: Float = 0.35, pitch: Float = 45, yaw: Float = 1.08) {
            let angle = pitch * .pi / 180, radius = height / tan(angle)
            let eye = SIMD3<Float>(radius*cos(yaw), scene.surfaceY+height, radius*sin(yaw))
            camera.simdTransform = TwoViewCamera.Pose.looking(eye: eye, yaw: yaw, pitch: -angle, fov: 50).transform
            camera.camera?.fieldOfView = 50; camera.camera?.usesOrthographicProjection = false
            SCNTransaction.flush()
        }
        @MainActor func balls(_ offset: Float) {
            scene.hideAllBalls()
            for (i,key) in ["cueBall","_1"].enumerated() {
                scene.showBall(key: key, scenePosition: SCNVector3(offset+Float(i)*0.075, scene.surfaceY+AngleSceneCalculator.ballRadius, 0))
            }
            SCNTransaction.flush()
        }
        @MainActor func install(_ source: String) {
            for m in cloth {var mods=m.shaderModifiers ?? [:];mods[.surface]=source;m.shaderModifiers=mods}
            SCNTransaction.flush()
        }
        var rows = [[String: Any]](), completed = false, previous = [Int16]()
        defer {
            install(candidate)
            attachStrictReport(["study":"H18-R7b","completed":completed && testRun?.totalFailureCount == 0,
                "rows":rows,"scope":"Native current-scene pixels, continuous sampled parameter paths; not phone visual acceptance"], name:"h18-r7b.json")
        }
        @MainActor func compare(_ name: String, save: Bool, probe: Bool = false) throws {
            install(baseline); _=try target.render(frames:3); let a=try target.readback()
            let ballState=cloth.first!.value(forKey:"contactUniforms") as! NSData
            let before=Data(bytes:ballState.bytes,count:ballState.length)
            _=try target.render(frames:1); let aa=try target.readback()
            install(candidate); _=try target.render(frames:3); let b=try target.readback()
            let after=cloth.first!.value(forKey:"contactUniforms") as! NSData
            try require(before == Data(bytes:after.bytes,count:after.length),"Same current ball uniforms")
            install(baseline); _=try target.render(frames:3); let restored=try target.readback()
            try require(difference(a,aa).maximum == 0 && difference(a,restored).maximum == 0,"R7b AA/restore")
            let diff=difference(a,b)
            var bins=["1":0,"2":0,"4":0,"8":0], signed=[Int16](), temporal=0
            signed.reserveCapacity(a.bgra.count/4*3)
            for p in stride(from:0,to:a.bgra.count,by:4) {
                var maximum=0
                for c in 0..<3 {
                    let d=Int16(b.bgra[p+c])-Int16(a.bgra[p+c]); maximum=max(maximum,abs(Int(d))); signed.append(d)
                }
                for level in [1,2,4,8] where maximum>level {bins[String(level),default:0]+=1}
            }
            if previous.count == signed.count {for i in signed.indices {temporal=max(temporal,abs(Int(signed[i]-previous[i])))}}
            previous=signed
            var row:[String:Any]=["case":name,"maximum":diff.maximum,"changedPixels":diff.changedPixels,"over":bins,"errorChange":temporal]
            if probe {
                let diagnostic=candidate+"\n_surface.diffuse=float4(0,0,0,1);_surface.emission.rgb=(clothLTCCloseView && _surface.roughness>=0.4 && shadowPossible)?float3(1,0,0):float3(0);\n"
                install(diagnostic);_=try target.render(frames:3);let frame=try target.readback()
                row["eligibleRedPixels"]=stride(from:0,to:frame.bgra.count,by:4).filter{frame.bgra[$0+2]>120 && frame.bgra[$0+1]<80 && frame.bgra[$0]<80}.count
            }
            if save {attach(a,"h18-r7b-\(name)-A");attach(b,"h18-r7b-\(name)-B")}
            install(candidate)
            try require(materials(scene).map(ObjectIdentifier.init)==identifiers && scene.clothSpecularLTC === ltc,"Stable material/LUT ownership")
            rows.append(row)
        }
        pose(); balls(0)
        for color in ClothColor.allCases {for style in TableStyle.allCases {
            try require(scene.applyClothColor(color) && scene.applyTableStyle(style),"All appearance variants")
            try compare("\(color.rawValue)-\(style.rawValue)", save:style == .charcoal)
        }}
        try require(scene.applyClothColor(.green) && scene.applyTableStyle(.charcoal),"Restore appearance")
        let roughness=cloth.map{$0.roughness.contents}
        previous=[]
        for frame in 0..<120 {
            let segment=frame/24,t=Float(frame%24)/23
            for (i,m) in cloth.enumerated(){m.roughness.contents=roughness[i]}
            switch segment {
            case 0:pose(pitch:28+4*t)
            case 1:pose(pitch:63+4*t)
            case 2:pose(height:0.48+0.04*t)
            case 3:
                pose(); for m in cloth {m.roughness.contents=NSNumber(value:0.36+0.08*t)}
            default:pose(height:0.49,pitch:32-3*t)
            }
            balls(-0.25+0.5*t)
            try compare("motion-\(frame)",save:true,probe:true)
        }
        for (i,m) in cloth.enumerated(){m.roughness.contents=roughness[i]}
        // Orthographic renderer shares the exact material objects; no per-camera program rewrite.
        scene.setCameraMode(.topDown2D,animated:false);SCNTransaction.flush()
        try compare("topdown-return",save:true,probe:true)
        // A local asset path exercises weak cache ownership independently of the scene-held resource.
        let temporary=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at:try XCTUnwrap(Bundle.main.url(forResource:ClothSpecularLTC.assetName,withExtension:"bin")),to:temporary)
        weak var released:ClothSpecularLTC?
        do {
            let value=try ClothSpecularLTC.acquire(emitter:MobileReferenceLighting.emitterGeometry,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:temporary)
            released=value
        }
        try require(released == nil,"Weak device cache releases unused wrapper")
        try FileManager.default.removeItem(at:temporary)
        completed=true
        #endif
    }

    // END H18 R7 INTEGRATION

    // BEGIN GENERATED H18 R6
    // H18 R6: generated fixture is research-only, installed on current production materials.
    func testNativeClothLTCR6() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("H18 R6 requires native Metal")
        #else
        guard ProcessInfo.processInfo.isiOSAppOnMac else { throw XCTSkip("H18 R6 authorized native Mac only") }
        let device=try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let candidate=try XCTUnwrap(String(data:XCTUnwrap(Data(base64Encoded:Self.h18R6Source)),encoding:.utf8))
        let scene=AngleTrainingScene(); scene.clothLTCRequested = false // Historical C1/H9 research baseline.

        scene.configureDailyClearanceRendering(asynchronousReflection:false)
        scene.setupScene(recipe:.liveReference,roomStyle:.tournament)
        try require(scene.applyClothColor(.green) && scene.applyTableStyle(.charcoal),"H18 current appearance")
        scene.hideAllBalls()
        let size=CGSize(width:1400,height:800),camera=try XCTUnwrap(scene.cameraNode)
        scene.cameraRig?.viewportSize=size;scene.setCameraMode(.perspective3D,animated:false)
        @MainActor func setCamera(_ frame:Int=0)throws {
            let eye=SIMD3<Float>(0.16+Float(frame)*0.012,1.15+Float(frame)*0.003,0.3)
            let delta=eye-SIMD3<Float>(0,scene.surfaceY,0)
            let pose=TwoViewCamera.Pose.looking(eye:eye,yaw:atan2(delta.z,delta.x),pitch:-atan2(delta.y,hypot(delta.x,delta.z)),fov:50)
            camera.simdTransform=pose.transform;camera.camera?.fieldOfView=50
            try require(camera.camera?.usesOrthographicProjection==false && simd_dot(pose.forward,simd_normalize(-delta))>0.99999,"H18 real perspective camera")
            SCNTransaction.flush()
        }
        try setCamera()
        let keys=["cueBall"]+(1...15).map{"_\($0)"}
        let carrier=SCNNode();scene.rootNode.addChildNode(carrier)
        for key in keys {carrier.addChildNode(try XCTUnwrap(scene.allBallNodes[key]))}
        @MainActor func setBalls(_ state:Int) {
            SCNTransaction.begin();SCNTransaction.disableActions=true
            scene.hideAllBalls()
            let count=state>=8 ? 16:2
            for (i,key) in keys.prefix(count).enumerated() {
                let x:Float=count==16 ? Float(i/4)*0.6-0.9:Float(i)*0.075
                let z:Float=count==16 ? Float(i%4)*0.3-0.45:0
                scene.showBall(key:key,scenePosition:SCNVector3(x,scene.surfaceY+AngleSceneCalculator.ballRadius,z))
                if state==2 && i==0 {scene.allBallNodes[key]?.position.y += 0.06}
                if state==3 && i==0 {scene.allBallNodes[key]?.opacity=0.5}
                if state==4 && i==0 {scene.allBallNodes[key]?.isHidden=true}
                if state==5 {scene.allBallNodes[key]?.isHidden=true}
            }
            SCNTransaction.commit();SCNTransaction.flush()
        }
        setBalls(0)
        var cloth=[SCNMaterial](),solids=[SCNMaterial](),seen=Set<ObjectIdentifier>()
        scene.rootNode.enumerateChildNodes {node,_ in
            for m in node.geometry?.materials ?? [] where seen.insert(ObjectIdentifier(m)).inserted {
                if m.name=="TaiNi" {cloth.append(m)}
                if ["Wood","BlackWood","MG_Gold"].contains(m.name ?? "") {solids.append(m)}
            }
        }
        try require(!cloth.isEmpty && !solids.isEmpty && solids.allSatisfy{!$0.isDoubleSided && $0.cullMode == .back},"H18 current H15 baseline")
        let reference=try XCTUnwrap(cloth.first?.shaderModifiers?[.surface])
        let digest=SHA256.hash(data:Data(reference.utf8)).map{String(format:"%02x",$0)}.joined()
        try require(digest=="14a880284fffc793f01d0357b0a625559101609d7986c9ac0cac72e7085efa4f" && cloth.allSatisfy{$0.shaderModifiers?[.surface]==reference},"H18 current C1/H9 exact source identity")
        var tables=[MTLTexture]()
        for (i,encoded) in [Self.h18R6Table0,Self.h18R6Table1].enumerated() {
            let bytes=try XCTUnwrap(Data(base64Encoded:encoded));try require(bytes.count==48*64*16,"H18 LUT size")
            let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:48,height:64,mipmapped:false)
            d.storageMode = .shared;d.usage = .shaderRead
            let table=try XCTUnwrap(device.makeTexture(descriptor:d))
            bytes.withUnsafeBytes{table.replace(region:MTLRegionMake2D(0,0,48,64),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:48*16)}
            tables.append(table);for m in cloth {m.setValue(SCNMaterialProperty(contents:table),forKey:"h18Table\(i)")}
        }
        let target=try RenderTarget(device:device,scene:scene,size:size)
        let probe=H17AnimationProbe(contact:scene.contactOcclusion);target.renderer.delegate=probe
        target.researchTime=1
        @MainActor func restart() {
            carrier.removeAllActions();carrier.simdPosition = .zero
            carrier.runAction(.customAction(duration:600) { node,elapsed in probe.actionStep(node,elapsed:Double(elapsed)) })
            SCNTransaction.flush()
        }
        @MainActor func install(_ source:String) {
            for m in cloth {var mods=m.shaderModifiers ?? [:];mods[.surface]=source;m.shaderModifiers=mods}
            SCNTransaction.flush()
        }
        @MainActor func uniforms()throws->Data {
            let value=try XCTUnwrap(cloth.first?.value(forKey:"contactUniforms") as? NSData)
            return Data(bytes:value.bytes,count:value.length)
        }
        try require(target.renderer.prepare(scene,shouldAbortBlock:nil),"H18 prepare current complete scene")
        restart();install(reference);_=try target.render(frames:12)
        let roughness=cloth.map{$0.roughness.intensity}
        var quality=[[String:Any]](),times=[[String:Any]](),completed=false
        defer {
            install(reference);carrier.removeAllActions()
            attachStrictReport(["study":"H18-R6-current-scene","completed":completed && testRun?.totalFailureCount==0,"device":device.name,
                "scope":"Current full 3D scene and real SCNAction; no SwiftUI page or phone energy claim","quality":quality,"times":times,
                "sourceSHA":digest,"lookupBytes":tables.reduce(0){$0+$1.allocatedSize},"policy":"2/4/8 are descriptive bins, not automatic visual acceptance"],name:"h18-r6-current-scene.json")
        }
        for state in 0..<16 {
            target.researchTime=1+Double(state)*0.07;setBalls(state)
            try setCamera(state>=6 ? state-6:0)
            for (i,m) in cloth.enumerated(){m.roughness.intensity=roughness[i]*(state>=12 ? 0.65:1)}
            SCNTransaction.flush()
            install(reference);_=try target.render(frames:3);let a=try target.readback(),aUniforms=try uniforms()
            _=try target.render(frames:1);let aa=try target.readback()
            install(candidate);_=try target.render(frames:2);_=probe.take()
            _=try target.render(frames:1);let b=try target.readback(),calls=probe.take()
            try require(calls["update"]==1 && calls["animations"]==1,"H18 one update per rendered frame")
            try require(aUniforms==uniforms(),"H18 reference/candidate same final animated ball state")
            install(reference);_=try target.render(frames:3);let restored=try target.readback()
            let delta=difference(a,b),noise=difference(a,aa),rest=difference(a,restored)
            try require(noise.maximum==0 && rest.maximum==0,"H18 AA/restoration")
            var bins=["1":0,"2":0,"4":0,"8":0],total=0
            for p in stride(from:0,to:a.bgra.count,by:4) {
                let d=(0..<3).map{abs(Int(a.bgra[p+$0])-Int(b.bgra[p+$0]))}.max()!
                for level in [1,2,4,8] where d>level {bins[String(level),default:0]+=1};total+=1
            }
            quality.append(["state":state,"maximum":delta.maximum,"changedPixels":delta.changedPixels,"pixels":total,"over":bins,"aaMaximum":noise.maximum,"restoreMaximum":rest.maximum,"callbacks":calls])
            attach(a,"h18-r6-\(state)-A");attach(b,"h18-r6-\(state)-B")
        }
        for (i,m) in cloth.enumerated(){m.roughness.intensity=roughness[i]}
        try setCamera();setBalls(0);restart()
        install(reference);_=try target.render(frames:3);let controlA=try target.readback()
        install(candidate+"\n_surface.emission.rgb=float3(2,0,0);\n");_=try target.render(frames:3)
        let controlB=try target.readback(),positive=difference(controlA,controlB)
        try require(positive.maximum>8 && positive.changedPixels>100,"H18 active candidate positive control")
        attach(controlB,"h18-r6-positive-control")
        var epoch:Double=20
        for cycle in 0..<6 {for kind in cycle%2==0 ? ["AA","AB"]:["AB","AA"] {
            for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
                epoch+=10;target.researchTime=epoch;setBalls(0);restart()
                install(kind=="AB" && arm ? candidate:reference)
                for f in 0..<24 {target.researchTime=epoch+Double(f)/60;_=try target.render(frames:1)}
                var samples=[[String:Any]]()
                for f in 0..<48 {
                    target.researchTime=epoch+Double(f+24)/60
                    samples += try target.render(frames:1,includeNativeTiming:true).perFrameTiming
                }
                times.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","frames":samples,"thermal":ProcessInfo.processInfo.thermalState.rawValue])
            }
        }}
        completed=true
        #endif
    }

    private static let h18R6Source = "I3ByYWdtYSBhcmd1bWVudHMKdGV4dHVyZTJkPGZsb2F0PiBoMThUYWJsZTA7CnRleHR1cmUyZDxmbG9hdD4gaDE4VGFibGUxOwp0ZXh0dXJlM2Q8ZmxvYXQ+IHRlbXBvcmFsRmllbGQwOwp0ZXh0dXJlM2Q8ZmxvYXQ+IHRlbXBvcmFsRmllbGQxOwojcHJhZ21hIGFyZ3VtZW50cwp0ZXh0dXJlMmQ8ZmxvYXQ+IGJha2VkUmFpbEFPOwojcHJhZ21hIGRlY2xhcmF0aW9uCnN0cnVjdCBRaXVKaUNvbnRhY3RVbmlmb3JtcyB7CmZsb2F0NCBjb250YWN0QmFsbHNbMTZdOwp9OwojcHJhZ21hIGFyZ3VtZW50cwpRaXVKaUNvbnRhY3RVbmlmb3JtcyBjb250YWN0VW5pZm9ybXM7CiNwcmFnbWEgZGVjbGFyYXRpb24KZmxvYXQzIHY2MkVtaXR0ZXJDZW50ZXIoaW50IGkpIHsgY29uc3QgZmxvYXQzIGFbMl09e2Zsb2F0MygwLjAsMy4wLC0wLjYzNDk5OTk5MDQ2MzI1NjgpLGZsb2F0MygwLjAsMy4wLDAuNjM0OTk5OTkwNDYzMjU2OCl9OyByZXR1cm4gYVtpXTsgfQpmbG9hdDMgdjYyRW1pdHRlclUoaW50IGkpIHsgY29uc3QgZmxvYXQzIGFbMl09e2Zsb2F0MygyLjUzOTk5OTk2MTg1MzAyNzMsMC4wLDAuMCksZmxvYXQzKDIuNTM5OTk5OTYxODUzMDI3MywwLjAsMC4wKX07IHJldHVybiBhW2ldOyB9CmZsb2F0MyB2NjJFbWl0dGVyVihpbnQgaSkgeyBjb25zdCBmbG9hdDMgYVsyXT17ZmxvYXQzKDAuMCwwLjAsMC42MzQ5OTk5OTA0NjMyNTY4KSxmbG9hdDMoMC4wLDAuMCwwLjYzNDk5OTk5MDQ2MzI1NjgpfTsgcmV0dXJuIGFbaV07IH0KZmxvYXQzIHY2MkVtaXR0ZXJOb3JtYWwoaW50IGkpIHsgY29uc3QgZmxvYXQzIGFbMl09e2Zsb2F0MygwLjAsLTEuMCwwLjApLGZsb2F0MygwLjAsLTEuMCwwLjApfTsgcmV0dXJuIGFbaV07IH0KZmxvYXQgdjYyRW1pdHRlckdhaW4oaW50IGkpIHsgY29uc3QgZmxvYXQgYVsyXT17MS4wLDEuMH07IHJldHVybiBhW2ldOyB9CmZsb2F0IHY2MkVtaXR0ZXJBcmVhKGludCBpKSB7IGNvbnN0IGZsb2F0IGFbMl09ezYuNDUxNTk5ODA2MjEzMzgsNi40NTE1OTk4MDYyMTMzOH07IHJldHVybiBhW2ldOyB9CmZsb2F0IHY2MlJlY3RJcnJhZGlhbmNlKGZsb2F0MyBwLCBmbG9hdDMgbiwgaW50IHBhbmVsKSB7CiAgICBmbG9hdDMgYz12NjJFbWl0dGVyQ2VudGVyKHBhbmVsKS1wLHU9djYyRW1pdHRlclUocGFuZWwpLHc9djYyRW1pdHRlclYocGFuZWwpOwogICAgaWYoZG90KHY2MkVtaXR0ZXJOb3JtYWwocGFuZWwpLC1jKTw9MC4wKSByZXR1cm4gMC4wOwogICAgZmxvYXQzIHZbNF09e2MtdS13LGMtdSt3LGMrdSt3LGMrdS13fTsKICAgIGZsb2F0MyBjbGlwcGVkWzhdO2ludCBjb3VudD0wOwogICAgZm9yKGludCBpPTA7aTw0OysraSkgewogICAgICAgIGZsb2F0MyBhPXZbaV0sYj12WyhpKzEpJTRdO2Zsb2F0IGRhPWRvdChhLG4pLGRiPWRvdChiLG4pOwogICAgICAgIGlmKGRhPj0wLjApIGNsaXBwZWRbY291bnQrK109YTsKICAgICAgICBpZigoZGE+PTAuMCkhPShkYj49MC4wKSkgY2xpcHBlZFtjb3VudCsrXT1hKyhiLWEpKihkYS8oZGEtZGIpKTsKICAgIH0KICAgIGlmKGNvdW50PDMpIHJldHVybiAwLjA7CiAgICBmbG9hdCBpbnRlZ3JhbD0wLjA7CiAgICBmb3IoaW50IGk9MDtpPGNvdW50OysraSkgewogICAgICAgIGZsb2F0MyBhPW5vcm1hbGl6ZShjbGlwcGVkW2ldKSxiPW5vcm1hbGl6ZShjbGlwcGVkWyhpKzEpJWNvdW50XSk7CiAgICAgICAgZmxvYXQzIGM9Y3Jvc3MoYSxiKTtmbG9hdCBsZW5ndGhDPWxlbmd0aChjKTsKICAgICAgICBpZihsZW5ndGhDPjAuMDAwMDAwMSkgaW50ZWdyYWwrPWF0YW4yKGxlbmd0aEMsZG90KGEsYikpKmRvdChjLG4pL2xlbmd0aEM7CiAgICB9CiAgICByZXR1cm4gYWJzKGludGVncmFsKSowLjU7Cn0KZmxvYXQzIHY2MlBhbmVsRGlmZnVzZShmbG9hdDMgcCwgZmxvYXQzIG4pIHsKICAgIGZsb2F0IHRvdGFsPTAuMDsKICAgIGZvcihpbnQgaT0wO2k8MjsrK2kpIHRvdGFsKz12NjJSZWN0SXJyYWRpYW5jZShwLG4saSkqdjYyRW1pdHRlckdhaW4oaSk7CiAgICByZXR1cm4gZmxvYXQzKDEuMCwwLjk4NSwwLjk2KSooMTIuOTY5NDQxMjMzNzQ1MjcvMy4xNDE1OTI2NSkqdG90YWw7Cn0KLy8gUmVzZWFyY2gtb25seSBtYXNrIHByZWRpY2F0ZS4gS0VFUCBvcmlnaW5hbCBzaGFkb3dQb3NzaWJsZSwgOC82NCBjaG9pY2UsCi8vIG9yaWdpbmFsIGFib3ZlLWJlZCBtYXNrIHByZWRpY2F0ZSBhbmQgb3JpZ2luYWwgYmFsbC9zaGFkb3cgYXJpdGhtZXRpYy4KLy8gVGhpcyBoZWxwZXIgcmVwbGFjZXMgb25seSB0aGUgdW5jb25kaXRpb25hbCBgcC55IDwgMC44YCBPUiB0ZXJtOgovLyAgIChwLnkgPCAwLjggJiYgaGVpZ2h0X3NhZmVfYmVsb3dfbWFzayhwLCBiYWxsKSkgfHwgb3JpZ2luYWxJblN1cHBvcnQKLy8gb3JpZ2luYWxJblN1cHBvcnQgaXMgdG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1vbGRCb3VuZCpvbGRCb3VuZC4KLy8gRG9tYWluOiBjdXJyZW50IHNvdXJjZSByaWcgZm9vdHByaW50IGFuZCB5IGJldHdlZW4gZmxvb3IgYW5kIHBoeXNpY2FsIGJlZC4KLy8gT3V0c2lkZSBkb21haW4gcmV0YWlucyBvbGQgYmVsb3ctYmVkIGFsbC1hY3RpdmUgYmVoYXZpb3IuIE5vIHNuYXBwaW5nLgpib29sIGhlaWdodF9zYWZlX2JhbGxfbWFzayhmbG9hdDMgcCwgZmxvYXQ0IGJhbGwpIHsKICAgIGlmICghKGFicyhiYWxsLngpIDw9IDIuNTM5OTk5OTYxODUzMDI3MyAmJiBhYnMoYmFsbC55KSA8PSAxLjI2OTk5OTk4MDkyNjUxMzcpKSByZXR1cm4gdHJ1ZTsKICAgIC8vIFVwcGVyIGJvdW5kcyBmcm9tIGFjdHVhbCBGbG9hdDMyIG5lYXIgKDh4NCBwZXIgbGFtcCkgc291cmNlIG9wZXJhdGlvbnMuCiAgICBjb25zdCBmbG9hdCBxID0gMC4yNTMzMjgzODI5Njg5MDI2OwogICAgY29uc3QgZmxvYXQgTSA9IDIuNDg0ODMwNjE3OTA0NjYzOwogICAgY29uc3QgZmxvYXQgciA9IDAuMDI4NTc2MDAxNTI0OTI1MjMyOyAvLyBuZXh0VXAoZmxvYXQoUjMyICsgZmxvb3IzMikpCiAgICBmbG9hdCBjZW50ZXJZID0gMC44ICsgYmFsbC56OyAvLyBzYW1lIGJhbGwgY2VudGVyIGV4cHJlc3Npb24gYXMgcHJvZHVjdGlvbgogICAgZmxvYXQgZ2FwID0gMy4wIC0gY2VudGVyWSAtIHIgLSBxOwogICAgaWYgKCEoZ2FwID4gMC4wKSkgcmV0dXJuIHRydWU7CiAgICBmbG9hdCBzdXBwb3J0ID0gciArIChjZW50ZXJZIC0gcC55ICsgcikgLyBnYXAgKiAobGVuZ3RoKGJhbGwueHkpICsgTSArIHEgKyByKTsKICAgIGZsb2F0MiBkZWx0YSA9IHAueHogLSBiYWxsLnh5OwogICAgcmV0dXJuIGRvdChkZWx0YSxkZWx0YSkgPD0gc3VwcG9ydCpzdXBwb3J0Owp9CgovLyBSZXNlYXJjaCBlbGlnaWJpbGl0eSBmb3IgdGhlIGFyY2hpdmVkIGNvbmUsIG5vdCBhIHVuaXZlcnNhbCBzY2VuZSBndWFyYW50ZWUuCmlubGluZSBib29sIGxlZ2FjeUNvbmVEb21haW4oZmxvYXQzIHAsY29uc3RhbnQgZmxvYXQ0ICpiYWxscykgewogICAgaWYoKGFzX3R5cGU8dWludD4ocC55KSYweDgwMDAwMDAwdSkhPTB1KSByZXR1cm4gZmFsc2U7CiAgICBpZighKHAueT49MC4wICYmIHAueTw9MC45ICYmIGFicyhwLngpPD0yLjUzOTk5OTk2MTg1MzAyNzMKICAgICAgICAgJiYgYWJzKHAueik8PTEuMjY5OTk5OTgwOTI2NTEzNykpIHJldHVybiBmYWxzZTsKICAgIGZvcihpbnQgaT0wO2k8MTY7KytpKSB7CiAgICAgICAgZmxvYXQ0IGI9YmFsbHNbaV07CiAgICAgICAgaWYoYi53PjAuMCAmJiAhKGFicyhiLngpPD0yLjUzOTk5OTk2MTg1MzAyNzMgJiYgYWJzKGIueSk8PTEuMjY5OTk5OTgwOTI2NTEzNwogICAgICAgICAgICAgICAgICAgICAgICYmIGIuej49MC4wMjg1NzUgJiYgYi56PD0yLjIpKSByZXR1cm4gZmFsc2U7CiAgICB9CiAgICByZXR1cm4gdHJ1ZTsKfQoKYm9vbCB0ZW1wb3JhbEZpZWxkRWxpZ2libGUoZmxvYXQzIHAsZmxvYXQzIG4pIHsKIGlmKCFhbGwoaXNmaW5pdGUocCkpIHx8IHAueDwtMS42IHx8IHAueD4xLjYgfHwgcC56PC0wLjk1IHx8IHAuej4wLjk1IHx8IHAueTwwLjY1IHx8IHAueT4wLjkpIHJldHVybiBmYWxzZTsKIGZvcihpbnQgcGFuZWw9MDtwYW5lbDwyOysrcGFuZWwpIHsKICBmbG9hdDMgYz12NjJFbWl0dGVyQ2VudGVyKHBhbmVsKS1wLHU9djYyRW1pdHRlclUocGFuZWwpLHc9djYyRW1pdHRlclYocGFuZWwpOwogIGlmKCEoZG90KGMtdS13LG4pPj0wICYmIGRvdChjLXUrdyxuKT49MCAmJiBkb3QoYyt1K3csbik+PTAgJiYgZG90KGMrdS13LG4pPj0wKSkgcmV0dXJuIGZhbHNlOwogfQogcmV0dXJuIHRydWU7Cn0KZmxvYXQzIHRlbXBvcmFsRmllbGREaWZmdXNlKGZsb2F0MyBwLGZsb2F0MyBuLHRleHR1cmUzZDxmbG9hdD4gZmllbGQwLHRleHR1cmUzZDxmbG9hdD4gZmllbGQxKSB7CiBpZighdGVtcG9yYWxGaWVsZEVsaWdpYmxlKHAsbikpIHJldHVybiB2NjJQYW5lbERpZmZ1c2UocCxuKTsKIGZsb2F0MyBnPWZsb2F0MygocC54KzEuNikvMy4yLChwLnorMC45NSkvMS45LChwLnktMC42NSkvMC4yNSk7CiBmbG9hdDMgc2l6ZT1mbG9hdDMoZmllbGQwLmdldF93aWR0aCgpLGZpZWxkMC5nZXRfaGVpZ2h0KCksZmllbGQwLmdldF9kZXB0aCgpKTsKIGZsb2F0MyB1dj0oZyooc2l6ZS0xLjApKzAuNSkvc2l6ZTsKIGNvbnN0ZXhwciBzYW1wbGVyIGxpbmVhclNhbXBsZXIoY29vcmQ6Om5vcm1hbGl6ZWQsYWRkcmVzczo6Y2xhbXBfdG9fZWRnZSxmaWx0ZXI6OmxpbmVhcik7CiBmbG9hdDMgYT1maWVsZDAuc2FtcGxlKGxpbmVhclNhbXBsZXIsdXYsbGV2ZWwoMCkpLnh5eixiPWZpZWxkMS5zYW1wbGUobGluZWFyU2FtcGxlcix1dixsZXZlbCgwKSkueHl6OwogZmxvYXQgdG90YWw9YWJzKGRvdChhLG4pKSowLjUqdjYyRW1pdHRlckdhaW4oMCkrYWJzKGRvdChiLG4pKSowLjUqdjYyRW1pdHRlckdhaW4oMSk7CiByZXR1cm4gZmxvYXQzKDEuMCwwLjk4NSwwLjk2KSooMTIuOTY5NDQxMjMzNzQ1MjcvMy4xNDE1OTI2NSkqdG90YWw7Cn0KLy8gSDE4IGluZGVwZW5kZW50IExUQyBkZW5zaXR5IGFuZCBwb2x5Z29uIGludGVncmFsLCBsb2NhbCBaIGlzIHNoYWRpbmcgbm9ybWFsLgpmbG9hdDMgaDE4VHJhbnNmb3JtKGZsb2F0MyBxLGZsb2F0NCBhLGZsb2F0NCBiKSB7CiByZXR1cm4gZmxvYXQzKGEueCpxLngrYS55KnEueixhLnoqcS55LGEudypxLngrYi54KnEueik7Cn0KZmxvYXQgaDE4RGVuc2l0eShmbG9hdDMgbCxmbG9hdDQgYSxmbG9hdDQgYikgewogZmxvYXQzIHE9aDE4VHJhbnNmb3JtKGwsYSxiKTtmbG9hdCBxMj1kb3QocSxxKTsKIGZsb2F0IGRldGVybWluYW50PWEueiooYS54KmIueC1hLnkqYS53KTsKIHJldHVybiBiLnkqZGV0ZXJtaW5hbnQqbWF4KDAuMCxxLnopLygzLjE0MTU5MjY1KnEyKnEyKTsKfQpmbG9hdCBoMThFZGdlKGZsb2F0MyBwLGZsb2F0MyBxKSB7CiBmbG9hdDMgY3I9Y3Jvc3MocCxxKTtmbG9hdCBzaW5lPWxlbmd0aChjcik7CiByZXR1cm4gY3IueiphdGFuMihzaW5lLGRvdChwLHEpKS9tYXgoMWUtOCxzaW5lKTsKfQpmbG9hdDMgaDE4V29ybGQoZmxvYXQzIHEsZmxvYXQzIHd4LGZsb2F0MyB3eSxmbG9hdDMgd3ope3JldHVybiBmbG9hdDMoZG90KHEsd3gpLGRvdChxLHd5KSxkb3QocSx3eikpO30KZmxvYXQgaDE4UG9seWdvbihmbG9hdDMgYyxmbG9hdDMgdSxmbG9hdDMgdixmbG9hdDMgd3gsZmxvYXQzIHd5LGZsb2F0MyB3eixmbG9hdCBhbXBsaXR1ZGUpIHsKIGZsb2F0MyBxMD1oMThXb3JsZChjLXUtdix3eCx3eSx3eikscTE9aDE4V29ybGQoYyt1LXYsd3gsd3ksd3opOwogZmxvYXQzIHEyPWgxOFdvcmxkKGMrdSt2LHd4LHd5LHd6KSxxMz1oMThXb3JsZChjLXUrdix3eCx3eSx3eik7CiBpZihtaW4obWluKHEwLnoscTEueiksbWluKHEyLnoscTMueikpPjAuMCl7CiAgcTA9bm9ybWFsaXplKHEwKTtxMT1ub3JtYWxpemUocTEpO3EyPW5vcm1hbGl6ZShxMik7cTM9bm9ybWFsaXplKHEzKTsKICByZXR1cm4gYWJzKGgxOEVkZ2UocTAscTEpK2gxOEVkZ2UocTEscTIpK2gxOEVkZ2UocTIscTMpK2gxOEVkZ2UocTMscTApKSphbXBsaXR1ZGUvKDIuMCozLjE0MTU5MjY1KTsKIH0KIGZsb2F0MyB0cmFuc2Zvcm1lZFs0XT17cTAscTEscTIscTN9OwogZmxvYXQzIGNsaXBwZWRbNl07aW50IGNvdW50PTA7CiBmb3IoaW50IGo9MDtqPDQ7KytqKXsKICBmbG9hdDMgcD10cmFuc2Zvcm1lZFtqXSxxPXRyYW5zZm9ybWVkWyhqKzEpJTRdOwogIGlmKHAuej4wLjApY2xpcHBlZFtjb3VudCsrXT1wOwogIGlmKChwLno+MC4wKSE9KHEuej4wLjApKWNsaXBwZWRbY291bnQrK109cCsocS1wKSpwLnovKHAuei1xLnopOwogfQogaWYoY291bnQ8MylyZXR1cm4gMC4wOwogZm9yKGludCBqPTA7ajxjb3VudDsrK2opY2xpcHBlZFtqXT1ub3JtYWxpemUoY2xpcHBlZFtqXSk7CiBmbG9hdCB0b3RhbD0wLjA7CiBmb3IoaW50IGo9MDtqPGNvdW50Oysrail7ZmxvYXQzIHA9Y2xpcHBlZFtqXSxxPWNsaXBwZWRbKGorMSklY291bnRdO2Zsb2F0MyBjcj1jcm9zcyhwLHEpO2Zsb2F0IHNpbmU9bGVuZ3RoKGNyKTt0b3RhbCs9Y3IueiphdGFuMihzaW5lLGRvdChwLHEpKS9tYXgoMWUtOCxzaW5lKTt9CiByZXR1cm4gYWJzKHRvdGFsKSphbXBsaXR1ZGUvKDIuMCozLjE0MTU5MjY1KTsKfQoKI3ByYWdtYSBib2R5CmZsb2F0MyBjb250YWN0V29ybGQgPSAoc2NuX2ZyYW1lLmludmVyc2VWaWV3VHJhbnNmb3JtICogZmxvYXQ0KF9zdXJmYWNlLnBvc2l0aW9uLCAxLjApKS54eXo7CmZsb2F0IGNvbnRhY3RWaXNpYmlsaXR5ID0gMS4wOwpmbG9hdDQgY29udGFjdEJhbGwwID0gY29udGFjdFVuaWZvcm1zLmNvbnRhY3RCYWxsc1swXTsKaWYgKGNvbnRhY3RCYWxsMC53ID4gMC4wKSB7CiAgICBmbG9hdDIgb2Zmc2V0ID0gY29udGFjdFdvcmxkLnh6IC0gY29udGFjdEJhbGwwLnh5OwogICAgZmxvYXQgaW52ZXJzZURpc3RhbmNlID0gcnNxcnQoZG90KG9mZnNldCwgb2Zmc2V0KSArIGNvbnRhY3RCYWxsMC56ICogY29udGFjdEJhbGwwLnopOwogICAgY29udGFjdFZpc2liaWxpdHkgKj0gMS4wIC0gKGNvbnRhY3RCYWxsMC53IC8gMC44NSkgKiAwLjAwMDgxNjUzMDYgKiBjb250YWN0QmFsbDAueiAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZTsKfQpmbG9hdDQgY29udGFjdEJhbGwxID0gY29udGFjdFVuaWZvcm1zLmNvbnRhY3RCYWxsc1sxXTsKaWYgKGNvbnRhY3RCYWxsMS53ID4gMC4wKSB7CiAgICBmbG9hdDIgb2Zmc2V0ID0gY29udGFjdFdvcmxkLnh6IC0gY29udGFjdEJhbGwxLnh5OwogICAgZmxvYXQgaW52ZXJzZURpc3RhbmNlID0gcnNxcnQoZG90KG9mZnNldCwgb2Zmc2V0KSArIGNvbnRhY3RCYWxsMS56ICogY29udGFjdEJhbGwxLnopOwogICAgY29udGFjdFZpc2liaWxpdHkgKj0gMS4wIC0gKGNvbnRhY3RCYWxsMS53IC8gMC44NSkgKiAwLjAwMDgxNjUzMDYgKiBjb250YWN0QmFsbDEueiAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZTsKfQpmbG9hdDQgY29udGFjdEJhbGwyID0gY29udGFjdFVuaWZvcm1zLmNvbnRhY3RCYWxsc1syXTsKaWYgKGNvbnRhY3RCYWxsMi53ID4gMC4wKSB7CiAgICBmbG9hdDIgb2Zmc2V0ID0gY29udGFjdFdvcmxkLnh6IC0gY29udGFjdEJhbGwyLnh5OwogICAgZmxvYXQgaW52ZXJzZURpc3RhbmNlID0gcnNxcnQoZG90KG9mZnNldCwgb2Zmc2V0KSArIGNvbnRhY3RCYWxsMi56ICogY29udGFjdEJhbGwyLnopOwogICAgY29udGFjdFZpc2liaWxpdHkgKj0gMS4wIC0gKGNvbnRhY3RCYWxsMi53IC8gMC44NSkgKiAwLjAwMDgxNjUzMDYgKiBjb250YWN0QmFsbDIueiAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZTsKfQpmbG9hdDQgY29udGFjdEJhbGwzID0gY29udGFjdFVuaWZvcm1zLmNvbnRhY3RCYWxsc1szXTsKaWYgKGNvbnRhY3RCYWxsMy53ID4gMC4wKSB7CiAgICBmbG9hdDIgb2Zmc2V0ID0gY29udGFjdFdvcmxkLnh6IC0gY29udGFjdEJhbGwzLnh5OwogICAgZmxvYXQgaW52ZXJzZURpc3RhbmNlID0gcnNxcnQoZG90KG9mZnNldCwgb2Zmc2V0KSArIGNvbnRhY3RCYWxsMy56ICogY29udGFjdEJhbGwzLnopOwogICAgY29udGFjdFZpc2liaWxpdHkgKj0gMS4wIC0gKGNvbnRhY3RCYWxsMy53IC8gMC44NSkgKiAwLjAwMDgxNjUzMDYgKiBjb250YWN0QmFsbDMueiAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZTsKfQpmbG9hdDQgY29udGFjdEJhbGw0ID0gY29udGFjdFVuaWZvcm1zLmNvbnRhY3RCYWxsc1s0XTsKaWYgKGNvbnRhY3RCYWxsNC53ID4gMC4wKSB7CiAgICBmbG9hdDIgb2Zmc2V0ID0gY29udGFjdFdvcmxkLnh6IC0gY29udGFjdEJhbGw0Lnh5OwogICAgZmxvYXQgaW52ZXJzZURpc3RhbmNlID0gcnNxcnQoZG90KG9mZnNldCwgb2Zmc2V0KSArIGNvbnRhY3RCYWxsNC56ICogY29udGFjdEJhbGw0LnopOwogICAgY29udGFjdFZpc2liaWxpdHkgKj0gMS4wIC0gKGNvbnRhY3RCYWxsNC53IC8gMC44NSkgKiAwLjAwMDgxNjUzMDYgKiBjb250YWN0QmFsbDQueiAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZTsKfQpmbG9hdDQgY29udGFjdEJhbGw1ID0gY29udGFjdFVuaWZvcm1zLmNvbnRhY3RCYWxsc1s1XTsKaWYgKGNvbnRhY3RCYWxsNS53ID4gMC4wKSB7CiAgICBmbG9hdDIgb2Zmc2V0ID0gY29udGFjdFdvcmxkLnh6IC0gY29udGFjdEJhbGw1Lnh5OwogICAgZmxvYXQgaW52ZXJzZURpc3RhbmNlID0gcnNxcnQoZG90KG9mZnNldCwgb2Zmc2V0KSArIGNvbnRhY3RCYWxsNS56ICogY29udGFjdEJhbGw1LnopOwogICAgY29udGFjdFZpc2liaWxpdHkgKj0gMS4wIC0gKGNvbnRhY3RCYWxsNS53IC8gMC44NSkgKiAwLjAwMDgxNjUzMDYgKiBjb250YWN0QmFsbDUueiAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZTsKfQpmbG9hdDQgY29udGFjdEJhbGw2ID0gY29udGFjdFVuaWZvcm1zLmNvbnRhY3RCYWxsc1s2XTsKaWYgKGNvbnRhY3RCYWxsNi53ID4gMC4wKSB7CiAgICBmbG9hdDIgb2Zmc2V0ID0gY29udGFjdFdvcmxkLnh6IC0gY29udGFjdEJhbGw2Lnh5OwogICAgZmxvYXQgaW52ZXJzZURpc3RhbmNlID0gcnNxcnQoZG90KG9mZnNldCwgb2Zmc2V0KSArIGNvbnRhY3RCYWxsNi56ICogY29udGFjdEJhbGw2LnopOwogICAgY29udGFjdFZpc2liaWxpdHkgKj0gMS4wIC0gKGNvbnRhY3RCYWxsNi53IC8gMC44NSkgKiAwLjAwMDgxNjUzMDYgKiBjb250YWN0QmFsbDYueiAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZTsKfQpmbG9hdDQgY29udGFjdEJhbGw3ID0gY29udGFjdFVuaWZvcm1zLmNvbnRhY3RCYWxsc1s3XTsKaWYgKGNvbnRhY3RCYWxsNy53ID4gMC4wKSB7CiAgICBmbG9hdDIgb2Zmc2V0ID0gY29udGFjdFdvcmxkLnh6IC0gY29udGFjdEJhbGw3Lnh5OwogICAgZmxvYXQgaW52ZXJzZURpc3RhbmNlID0gcnNxcnQoZG90KG9mZnNldCwgb2Zmc2V0KSArIGNvbnRhY3RCYWxsNy56ICogY29udGFjdEJhbGw3LnopOwogICAgY29udGFjdFZpc2liaWxpdHkgKj0gMS4wIC0gKGNvbnRhY3RCYWxsNy53IC8gMC44NSkgKiAwLjAwMDgxNjUzMDYgKiBjb250YWN0QmFsbDcueiAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZTsKfQpmbG9hdDQgY29udGFjdEJhbGw4ID0gY29udGFjdFVuaWZvcm1zLmNvbnRhY3RCYWxsc1s4XTsKaWYgKGNvbnRhY3RCYWxsOC53ID4gMC4wKSB7CiAgICBmbG9hdDIgb2Zmc2V0ID0gY29udGFjdFdvcmxkLnh6IC0gY29udGFjdEJhbGw4Lnh5OwogICAgZmxvYXQgaW52ZXJzZURpc3RhbmNlID0gcnNxcnQoZG90KG9mZnNldCwgb2Zmc2V0KSArIGNvbnRhY3RCYWxsOC56ICogY29udGFjdEJhbGw4LnopOwogICAgY29udGFjdFZpc2liaWxpdHkgKj0gMS4wIC0gKGNvbnRhY3RCYWxsOC53IC8gMC44NSkgKiAwLjAwMDgxNjUzMDYgKiBjb250YWN0QmFsbDgueiAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZTsKfQpmbG9hdDQgY29udGFjdEJhbGw5ID0gY29udGFjdFVuaWZvcm1zLmNvbnRhY3RCYWxsc1s5XTsKaWYgKGNvbnRhY3RCYWxsOS53ID4gMC4wKSB7CiAgICBmbG9hdDIgb2Zmc2V0ID0gY29udGFjdFdvcmxkLnh6IC0gY29udGFjdEJhbGw5Lnh5OwogICAgZmxvYXQgaW52ZXJzZURpc3RhbmNlID0gcnNxcnQoZG90KG9mZnNldCwgb2Zmc2V0KSArIGNvbnRhY3RCYWxsOS56ICogY29udGFjdEJhbGw5LnopOwogICAgY29udGFjdFZpc2liaWxpdHkgKj0gMS4wIC0gKGNvbnRhY3RCYWxsOS53IC8gMC44NSkgKiAwLjAwMDgxNjUzMDYgKiBjb250YWN0QmFsbDkueiAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZTsKfQpmbG9hdDQgY29udGFjdEJhbGwxMCA9IGNvbnRhY3RVbmlmb3Jtcy5jb250YWN0QmFsbHNbMTBdOwppZiAoY29udGFjdEJhbGwxMC53ID4gMC4wKSB7CiAgICBmbG9hdDIgb2Zmc2V0ID0gY29udGFjdFdvcmxkLnh6IC0gY29udGFjdEJhbGwxMC54eTsKICAgIGZsb2F0IGludmVyc2VEaXN0YW5jZSA9IHJzcXJ0KGRvdChvZmZzZXQsIG9mZnNldCkgKyBjb250YWN0QmFsbDEwLnogKiBjb250YWN0QmFsbDEwLnopOwogICAgY29udGFjdFZpc2liaWxpdHkgKj0gMS4wIC0gKGNvbnRhY3RCYWxsMTAudyAvIDAuODUpICogMC4wMDA4MTY1MzA2ICogY29udGFjdEJhbGwxMC56ICogaW52ZXJzZURpc3RhbmNlICogaW52ZXJzZURpc3RhbmNlICogaW52ZXJzZURpc3RhbmNlOwp9CmZsb2F0NCBjb250YWN0QmFsbDExID0gY29udGFjdFVuaWZvcm1zLmNvbnRhY3RCYWxsc1sxMV07CmlmIChjb250YWN0QmFsbDExLncgPiAwLjApIHsKICAgIGZsb2F0MiBvZmZzZXQgPSBjb250YWN0V29ybGQueHogLSBjb250YWN0QmFsbDExLnh5OwogICAgZmxvYXQgaW52ZXJzZURpc3RhbmNlID0gcnNxcnQoZG90KG9mZnNldCwgb2Zmc2V0KSArIGNvbnRhY3RCYWxsMTEueiAqIGNvbnRhY3RCYWxsMTEueik7CiAgICBjb250YWN0VmlzaWJpbGl0eSAqPSAxLjAgLSAoY29udGFjdEJhbGwxMS53IC8gMC44NSkgKiAwLjAwMDgxNjUzMDYgKiBjb250YWN0QmFsbDExLnogKiBpbnZlcnNlRGlzdGFuY2UgKiBpbnZlcnNlRGlzdGFuY2UgKiBpbnZlcnNlRGlzdGFuY2U7Cn0KZmxvYXQ0IGNvbnRhY3RCYWxsMTIgPSBjb250YWN0VW5pZm9ybXMuY29udGFjdEJhbGxzWzEyXTsKaWYgKGNvbnRhY3RCYWxsMTIudyA+IDAuMCkgewogICAgZmxvYXQyIG9mZnNldCA9IGNvbnRhY3RXb3JsZC54eiAtIGNvbnRhY3RCYWxsMTIueHk7CiAgICBmbG9hdCBpbnZlcnNlRGlzdGFuY2UgPSByc3FydChkb3Qob2Zmc2V0LCBvZmZzZXQpICsgY29udGFjdEJhbGwxMi56ICogY29udGFjdEJhbGwxMi56KTsKICAgIGNvbnRhY3RWaXNpYmlsaXR5ICo9IDEuMCAtIChjb250YWN0QmFsbDEyLncgLyAwLjg1KSAqIDAuMDAwODE2NTMwNiAqIGNvbnRhY3RCYWxsMTIueiAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZTsKfQpmbG9hdDQgY29udGFjdEJhbGwxMyA9IGNvbnRhY3RVbmlmb3Jtcy5jb250YWN0QmFsbHNbMTNdOwppZiAoY29udGFjdEJhbGwxMy53ID4gMC4wKSB7CiAgICBmbG9hdDIgb2Zmc2V0ID0gY29udGFjdFdvcmxkLnh6IC0gY29udGFjdEJhbGwxMy54eTsKICAgIGZsb2F0IGludmVyc2VEaXN0YW5jZSA9IHJzcXJ0KGRvdChvZmZzZXQsIG9mZnNldCkgKyBjb250YWN0QmFsbDEzLnogKiBjb250YWN0QmFsbDEzLnopOwogICAgY29udGFjdFZpc2liaWxpdHkgKj0gMS4wIC0gKGNvbnRhY3RCYWxsMTMudyAvIDAuODUpICogMC4wMDA4MTY1MzA2ICogY29udGFjdEJhbGwxMy56ICogaW52ZXJzZURpc3RhbmNlICogaW52ZXJzZURpc3RhbmNlICogaW52ZXJzZURpc3RhbmNlOwp9CmZsb2F0NCBjb250YWN0QmFsbDE0ID0gY29udGFjdFVuaWZvcm1zLmNvbnRhY3RCYWxsc1sxNF07CmlmIChjb250YWN0QmFsbDE0LncgPiAwLjApIHsKICAgIGZsb2F0MiBvZmZzZXQgPSBjb250YWN0V29ybGQueHogLSBjb250YWN0QmFsbDE0Lnh5OwogICAgZmxvYXQgaW52ZXJzZURpc3RhbmNlID0gcnNxcnQoZG90KG9mZnNldCwgb2Zmc2V0KSArIGNvbnRhY3RCYWxsMTQueiAqIGNvbnRhY3RCYWxsMTQueik7CiAgICBjb250YWN0VmlzaWJpbGl0eSAqPSAxLjAgLSAoY29udGFjdEJhbGwxNC53IC8gMC44NSkgKiAwLjAwMDgxNjUzMDYgKiBjb250YWN0QmFsbDE0LnogKiBpbnZlcnNlRGlzdGFuY2UgKiBpbnZlcnNlRGlzdGFuY2UgKiBpbnZlcnNlRGlzdGFuY2U7Cn0KZmxvYXQ0IGNvbnRhY3RCYWxsMTUgPSBjb250YWN0VW5pZm9ybXMuY29udGFjdEJhbGxzWzE1XTsKaWYgKGNvbnRhY3RCYWxsMTUudyA+IDAuMCkgewogICAgZmxvYXQyIG9mZnNldCA9IGNvbnRhY3RXb3JsZC54eiAtIGNvbnRhY3RCYWxsMTUueHk7CiAgICBmbG9hdCBpbnZlcnNlRGlzdGFuY2UgPSByc3FydChkb3Qob2Zmc2V0LCBvZmZzZXQpICsgY29udGFjdEJhbGwxNS56ICogY29udGFjdEJhbGwxNS56KTsKICAgIGNvbnRhY3RWaXNpYmlsaXR5ICo9IDEuMCAtIChjb250YWN0QmFsbDE1LncgLyAwLjg1KSAqIDAuMDAwODE2NTMwNiAqIGNvbnRhY3RCYWxsMTUueiAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZSAqIGludmVyc2VEaXN0YW5jZTsKfQpfc3VyZmFjZS5hbWJpZW50T2NjbHVzaW9uID0gY29udGFjdFZpc2liaWxpdHk7CmlmIChhYnMoY29udGFjdFdvcmxkLnkgLSAwLjgpIDwgMC4wMDA1KSB7CiAgICBjb25zdGV4cHIgc2FtcGxlciByYWlsU2FtcGxlcihjb29yZDo6bm9ybWFsaXplZCwgYWRkcmVzczo6Y2xhbXBfdG9fZWRnZSwgZmlsdGVyOjpsaW5lYXIpOwogICAgZmxvYXQyIHJhaWxVViA9IChjb250YWN0V29ybGQueHogKyBmbG9hdDIoMS4yNywgMC42MzUpKSAvIGZsb2F0MigyLjU0LCAxLjI3KTsKICAgIF9zdXJmYWNlLmFtYmllbnRPY2NsdXNpb24gKj0gYmFrZWRSYWlsQU8uc2FtcGxlKHJhaWxTYW1wbGVyLCByYWlsVVYpLnI7Cn0KZmxvYXQgY2xvdGhGaWJlciA9IGNsYW1wKDEuMCArIDQuMCAqIChfc3VyZmFjZS5yb3VnaG5lc3MgLSAwLjgpLCAwLjUsIDEuNSk7Cl9zdXJmYWNlLmRpZmZ1c2UucmdiICo9IGNsb3RoRmliZXI7Ci8vIEg5OiByZWFkIG9yaWdpbmFsIGJhbGwgZGF0YSBkaXJlY3RseSBmcm9tIGNvbnN0YW50IG1lbW9yeS4KZmxvYXQzIHA9Y29udGFjdFdvcmxkOwpmbG9hdDMgbj1ub3JtYWxpemUoKHNjbl9mcmFtZS5pbnZlcnNlVmlld1RyYW5zZm9ybSpmbG9hdDQoX3N1cmZhY2Uubm9ybWFsLDAuMCkpLnh5eik7CmZsb2F0MyBFPWZsb2F0MygwLjApO2Zsb2F0MyB1bm9jY2x1ZGVkRT1mbG9hdDMoMC4wKTtmbG9hdDMgUz1mbG9hdDMoMC4wKTsKZmxvYXQzIHY9bm9ybWFsaXplKHNjbl9mcmFtZS5pbnZlcnNlVmlld1RyYW5zZm9ybVszXS54eXotcCk7CmZsb2F0IG52PW1heCgwLjAwMSxkb3Qobix2KSk7CmZsb2F0IGFscGhhPW1heCgwLjAxLF9zdXJmYWNlLnJvdWdobmVzcypfc3VyZmFjZS5yb3VnaG5lc3MpOwpmbG9hdCBhMj1hbHBoYSphbHBoYTsKYm9vbCBzaGFkb3dQb3NzaWJsZT1mYWxzZTsKaWYoY29udGFjdEJhbGwwLnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGwwLnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDAueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGwwLnh5OwogICAgc2hhZG93UG9zc2libGU9c2hhZG93UG9zc2libGUgfHwgdG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZDsKfWlmKGNvbnRhY3RCYWxsMS53PjAuMCkgewogICAgZmxvYXQgdG9wPWNvbnRhY3RCYWxsMS56KzAuMDI4NTc1OwogICAgZmxvYXQgYm91bmQ9MC4wMjg1NzUrdG9wL21heCgwLjAxLDIuMi10b3ApKihsZW5ndGgoY29udGFjdEJhbGwxLnh5KSszLjA5MzEzNDYzMzAyNTQyMDYpOwogICAgZmxvYXQyIG9mZnNldD1wLnh6LWNvbnRhY3RCYWxsMS54eTsKICAgIHNoYWRvd1Bvc3NpYmxlPXNoYWRvd1Bvc3NpYmxlIHx8IHRvcD49Mi4yIHx8IGRvdChvZmZzZXQsb2Zmc2V0KTw9Ym91bmQqYm91bmQ7Cn1pZihjb250YWN0QmFsbDIudz4wLjApIHsKICAgIGZsb2F0IHRvcD1jb250YWN0QmFsbDIueiswLjAyODU3NTsKICAgIGZsb2F0IGJvdW5kPTAuMDI4NTc1K3RvcC9tYXgoMC4wMSwyLjItdG9wKSoobGVuZ3RoKGNvbnRhY3RCYWxsMi54eSkrMy4wOTMxMzQ2MzMwMjU0MjA2KTsKICAgIGZsb2F0MiBvZmZzZXQ9cC54ei1jb250YWN0QmFsbDIueHk7CiAgICBzaGFkb3dQb3NzaWJsZT1zaGFkb3dQb3NzaWJsZSB8fCB0b3A+PTIuMiB8fCBkb3Qob2Zmc2V0LG9mZnNldCk8PWJvdW5kKmJvdW5kOwp9aWYoY29udGFjdEJhbGwzLnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGwzLnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDMueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGwzLnh5OwogICAgc2hhZG93UG9zc2libGU9c2hhZG93UG9zc2libGUgfHwgdG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZDsKfWlmKGNvbnRhY3RCYWxsNC53PjAuMCkgewogICAgZmxvYXQgdG9wPWNvbnRhY3RCYWxsNC56KzAuMDI4NTc1OwogICAgZmxvYXQgYm91bmQ9MC4wMjg1NzUrdG9wL21heCgwLjAxLDIuMi10b3ApKihsZW5ndGgoY29udGFjdEJhbGw0Lnh5KSszLjA5MzEzNDYzMzAyNTQyMDYpOwogICAgZmxvYXQyIG9mZnNldD1wLnh6LWNvbnRhY3RCYWxsNC54eTsKICAgIHNoYWRvd1Bvc3NpYmxlPXNoYWRvd1Bvc3NpYmxlIHx8IHRvcD49Mi4yIHx8IGRvdChvZmZzZXQsb2Zmc2V0KTw9Ym91bmQqYm91bmQ7Cn1pZihjb250YWN0QmFsbDUudz4wLjApIHsKICAgIGZsb2F0IHRvcD1jb250YWN0QmFsbDUueiswLjAyODU3NTsKICAgIGZsb2F0IGJvdW5kPTAuMDI4NTc1K3RvcC9tYXgoMC4wMSwyLjItdG9wKSoobGVuZ3RoKGNvbnRhY3RCYWxsNS54eSkrMy4wOTMxMzQ2MzMwMjU0MjA2KTsKICAgIGZsb2F0MiBvZmZzZXQ9cC54ei1jb250YWN0QmFsbDUueHk7CiAgICBzaGFkb3dQb3NzaWJsZT1zaGFkb3dQb3NzaWJsZSB8fCB0b3A+PTIuMiB8fCBkb3Qob2Zmc2V0LG9mZnNldCk8PWJvdW5kKmJvdW5kOwp9aWYoY29udGFjdEJhbGw2Lnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGw2LnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDYueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGw2Lnh5OwogICAgc2hhZG93UG9zc2libGU9c2hhZG93UG9zc2libGUgfHwgdG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZDsKfWlmKGNvbnRhY3RCYWxsNy53PjAuMCkgewogICAgZmxvYXQgdG9wPWNvbnRhY3RCYWxsNy56KzAuMDI4NTc1OwogICAgZmxvYXQgYm91bmQ9MC4wMjg1NzUrdG9wL21heCgwLjAxLDIuMi10b3ApKihsZW5ndGgoY29udGFjdEJhbGw3Lnh5KSszLjA5MzEzNDYzMzAyNTQyMDYpOwogICAgZmxvYXQyIG9mZnNldD1wLnh6LWNvbnRhY3RCYWxsNy54eTsKICAgIHNoYWRvd1Bvc3NpYmxlPXNoYWRvd1Bvc3NpYmxlIHx8IHRvcD49Mi4yIHx8IGRvdChvZmZzZXQsb2Zmc2V0KTw9Ym91bmQqYm91bmQ7Cn1pZihjb250YWN0QmFsbDgudz4wLjApIHsKICAgIGZsb2F0IHRvcD1jb250YWN0QmFsbDgueiswLjAyODU3NTsKICAgIGZsb2F0IGJvdW5kPTAuMDI4NTc1K3RvcC9tYXgoMC4wMSwyLjItdG9wKSoobGVuZ3RoKGNvbnRhY3RCYWxsOC54eSkrMy4wOTMxMzQ2MzMwMjU0MjA2KTsKICAgIGZsb2F0MiBvZmZzZXQ9cC54ei1jb250YWN0QmFsbDgueHk7CiAgICBzaGFkb3dQb3NzaWJsZT1zaGFkb3dQb3NzaWJsZSB8fCB0b3A+PTIuMiB8fCBkb3Qob2Zmc2V0LG9mZnNldCk8PWJvdW5kKmJvdW5kOwp9aWYoY29udGFjdEJhbGw5Lnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGw5LnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDkueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGw5Lnh5OwogICAgc2hhZG93UG9zc2libGU9c2hhZG93UG9zc2libGUgfHwgdG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZDsKfWlmKGNvbnRhY3RCYWxsMTAudz4wLjApIHsKICAgIGZsb2F0IHRvcD1jb250YWN0QmFsbDEwLnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDEwLnh5KSszLjA5MzEzNDYzMzAyNTQyMDYpOwogICAgZmxvYXQyIG9mZnNldD1wLnh6LWNvbnRhY3RCYWxsMTAueHk7CiAgICBzaGFkb3dQb3NzaWJsZT1zaGFkb3dQb3NzaWJsZSB8fCB0b3A+PTIuMiB8fCBkb3Qob2Zmc2V0LG9mZnNldCk8PWJvdW5kKmJvdW5kOwp9aWYoY29udGFjdEJhbGwxMS53PjAuMCkgewogICAgZmxvYXQgdG9wPWNvbnRhY3RCYWxsMTEueiswLjAyODU3NTsKICAgIGZsb2F0IGJvdW5kPTAuMDI4NTc1K3RvcC9tYXgoMC4wMSwyLjItdG9wKSoobGVuZ3RoKGNvbnRhY3RCYWxsMTEueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGwxMS54eTsKICAgIHNoYWRvd1Bvc3NpYmxlPXNoYWRvd1Bvc3NpYmxlIHx8IHRvcD49Mi4yIHx8IGRvdChvZmZzZXQsb2Zmc2V0KTw9Ym91bmQqYm91bmQ7Cn1pZihjb250YWN0QmFsbDEyLnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGwxMi56KzAuMDI4NTc1OwogICAgZmxvYXQgYm91bmQ9MC4wMjg1NzUrdG9wL21heCgwLjAxLDIuMi10b3ApKihsZW5ndGgoY29udGFjdEJhbGwxMi54eSkrMy4wOTMxMzQ2MzMwMjU0MjA2KTsKICAgIGZsb2F0MiBvZmZzZXQ9cC54ei1jb250YWN0QmFsbDEyLnh5OwogICAgc2hhZG93UG9zc2libGU9c2hhZG93UG9zc2libGUgfHwgdG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZDsKfWlmKGNvbnRhY3RCYWxsMTMudz4wLjApIHsKICAgIGZsb2F0IHRvcD1jb250YWN0QmFsbDEzLnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDEzLnh5KSszLjA5MzEzNDYzMzAyNTQyMDYpOwogICAgZmxvYXQyIG9mZnNldD1wLnh6LWNvbnRhY3RCYWxsMTMueHk7CiAgICBzaGFkb3dQb3NzaWJsZT1zaGFkb3dQb3NzaWJsZSB8fCB0b3A+PTIuMiB8fCBkb3Qob2Zmc2V0LG9mZnNldCk8PWJvdW5kKmJvdW5kOwp9aWYoY29udGFjdEJhbGwxNC53PjAuMCkgewogICAgZmxvYXQgdG9wPWNvbnRhY3RCYWxsMTQueiswLjAyODU3NTsKICAgIGZsb2F0IGJvdW5kPTAuMDI4NTc1K3RvcC9tYXgoMC4wMSwyLjItdG9wKSoobGVuZ3RoKGNvbnRhY3RCYWxsMTQueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGwxNC54eTsKICAgIHNoYWRvd1Bvc3NpYmxlPXNoYWRvd1Bvc3NpYmxlIHx8IHRvcD49Mi4yIHx8IGRvdChvZmZzZXQsb2Zmc2V0KTw9Ym91bmQqYm91bmQ7Cn1pZihjb250YWN0QmFsbDE1Lnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGwxNS56KzAuMDI4NTc1OwogICAgZmxvYXQgYm91bmQ9MC4wMjg1NzUrdG9wL21heCgwLjAxLDIuMi10b3ApKihsZW5ndGgoY29udGFjdEJhbGwxNS54eSkrMy4wOTMxMzQ2MzMwMjU0MjA2KTsKICAgIGZsb2F0MiBvZmZzZXQ9cC54ei1jb250YWN0QmFsbDE1Lnh5OwogICAgc2hhZG93UG9zc2libGU9c2hhZG93UG9zc2libGUgfHwgdG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZDsKfQpib29sIGRpYWdub3N0aWNDb25lRWxpZ2libGU9IXNoYWRvd1Bvc3NpYmxlIHx8IGxlZ2FjeUNvbmVEb21haW4ocCxjb250YWN0VW5pZm9ybXMuY29udGFjdEJhbGxzKTsKdWludCBzaGFkb3dNYXNrPTB1OwppZihzaGFkb3dQb3NzaWJsZSkgewpib29sIGJlbG93QmVkPXAueTwwLjg7CmJvb2wgcmVjZWl2ZXJDYW5QcnVuZT1iZWxvd0JlZCAmJiAoYXNfdHlwZTx1aW50PihwLnkpJjB4ODAwMDAwMDB1KT09MHUgJiYgcC55Pj0wLjAKICAgICYmIGFicyhwLngpPD0yLjUzOTk5OTk2MTg1MzAyNzMgJiYgYWJzKHAueik8PTEuMjY5OTk5OTgwOTI2NTEzNzsKaWYoY29udGFjdEJhbGwwLnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGwwLnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDAueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGwwLnh5OwogICAgaWYodG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZCB8fCAoYmVsb3dCZWQgJiYgKCFkaWFnbm9zdGljQ29uZUVsaWdpYmxlIHx8ICFyZWNlaXZlckNhblBydW5lIHx8IGhlaWdodF9zYWZlX2JhbGxfbWFzayhwLGNvbnRhY3RCYWxsMCkpKSkgc2hhZG93TWFzayB8PSAoMXU8PDApOwp9aWYoY29udGFjdEJhbGwxLnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGwxLnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDEueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGwxLnh5OwogICAgaWYodG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZCB8fCAoYmVsb3dCZWQgJiYgKCFkaWFnbm9zdGljQ29uZUVsaWdpYmxlIHx8ICFyZWNlaXZlckNhblBydW5lIHx8IGhlaWdodF9zYWZlX2JhbGxfbWFzayhwLGNvbnRhY3RCYWxsMSkpKSkgc2hhZG93TWFzayB8PSAoMXU8PDEpOwp9aWYoY29udGFjdEJhbGwyLnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGwyLnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDIueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGwyLnh5OwogICAgaWYodG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZCB8fCAoYmVsb3dCZWQgJiYgKCFkaWFnbm9zdGljQ29uZUVsaWdpYmxlIHx8ICFyZWNlaXZlckNhblBydW5lIHx8IGhlaWdodF9zYWZlX2JhbGxfbWFzayhwLGNvbnRhY3RCYWxsMikpKSkgc2hhZG93TWFzayB8PSAoMXU8PDIpOwp9aWYoY29udGFjdEJhbGwzLnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGwzLnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDMueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGwzLnh5OwogICAgaWYodG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZCB8fCAoYmVsb3dCZWQgJiYgKCFkaWFnbm9zdGljQ29uZUVsaWdpYmxlIHx8ICFyZWNlaXZlckNhblBydW5lIHx8IGhlaWdodF9zYWZlX2JhbGxfbWFzayhwLGNvbnRhY3RCYWxsMykpKSkgc2hhZG93TWFzayB8PSAoMXU8PDMpOwp9aWYoY29udGFjdEJhbGw0Lnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGw0LnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDQueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGw0Lnh5OwogICAgaWYodG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZCB8fCAoYmVsb3dCZWQgJiYgKCFkaWFnbm9zdGljQ29uZUVsaWdpYmxlIHx8ICFyZWNlaXZlckNhblBydW5lIHx8IGhlaWdodF9zYWZlX2JhbGxfbWFzayhwLGNvbnRhY3RCYWxsNCkpKSkgc2hhZG93TWFzayB8PSAoMXU8PDQpOwp9aWYoY29udGFjdEJhbGw1Lnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGw1LnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDUueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGw1Lnh5OwogICAgaWYodG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZCB8fCAoYmVsb3dCZWQgJiYgKCFkaWFnbm9zdGljQ29uZUVsaWdpYmxlIHx8ICFyZWNlaXZlckNhblBydW5lIHx8IGhlaWdodF9zYWZlX2JhbGxfbWFzayhwLGNvbnRhY3RCYWxsNSkpKSkgc2hhZG93TWFzayB8PSAoMXU8PDUpOwp9aWYoY29udGFjdEJhbGw2Lnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGw2LnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDYueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGw2Lnh5OwogICAgaWYodG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZCB8fCAoYmVsb3dCZWQgJiYgKCFkaWFnbm9zdGljQ29uZUVsaWdpYmxlIHx8ICFyZWNlaXZlckNhblBydW5lIHx8IGhlaWdodF9zYWZlX2JhbGxfbWFzayhwLGNvbnRhY3RCYWxsNikpKSkgc2hhZG93TWFzayB8PSAoMXU8PDYpOwp9aWYoY29udGFjdEJhbGw3Lnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGw3LnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDcueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGw3Lnh5OwogICAgaWYodG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZCB8fCAoYmVsb3dCZWQgJiYgKCFkaWFnbm9zdGljQ29uZUVsaWdpYmxlIHx8ICFyZWNlaXZlckNhblBydW5lIHx8IGhlaWdodF9zYWZlX2JhbGxfbWFzayhwLGNvbnRhY3RCYWxsNykpKSkgc2hhZG93TWFzayB8PSAoMXU8PDcpOwp9aWYoY29udGFjdEJhbGw4Lnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGw4LnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDgueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGw4Lnh5OwogICAgaWYodG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZCB8fCAoYmVsb3dCZWQgJiYgKCFkaWFnbm9zdGljQ29uZUVsaWdpYmxlIHx8ICFyZWNlaXZlckNhblBydW5lIHx8IGhlaWdodF9zYWZlX2JhbGxfbWFzayhwLGNvbnRhY3RCYWxsOCkpKSkgc2hhZG93TWFzayB8PSAoMXU8PDgpOwp9aWYoY29udGFjdEJhbGw5Lnc+MC4wKSB7CiAgICBmbG9hdCB0b3A9Y29udGFjdEJhbGw5LnorMC4wMjg1NzU7CiAgICBmbG9hdCBib3VuZD0wLjAyODU3NSt0b3AvbWF4KDAuMDEsMi4yLXRvcCkqKGxlbmd0aChjb250YWN0QmFsbDkueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGw5Lnh5OwogICAgaWYodG9wPj0yLjIgfHwgZG90KG9mZnNldCxvZmZzZXQpPD1ib3VuZCpib3VuZCB8fCAoYmVsb3dCZWQgJiYgKCFkaWFnbm9zdGljQ29uZUVsaWdpYmxlIHx8ICFyZWNlaXZlckNhblBydW5lIHx8IGhlaWdodF9zYWZlX2JhbGxfbWFzayhwLGNvbnRhY3RCYWxsOSkpKSkgc2hhZG93TWFzayB8PSAoMXU8PDkpOwp9aWYoY29udGFjdEJhbGwxMC53PjAuMCkgewogICAgZmxvYXQgdG9wPWNvbnRhY3RCYWxsMTAueiswLjAyODU3NTsKICAgIGZsb2F0IGJvdW5kPTAuMDI4NTc1K3RvcC9tYXgoMC4wMSwyLjItdG9wKSoobGVuZ3RoKGNvbnRhY3RCYWxsMTAueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGwxMC54eTsKICAgIGlmKHRvcD49Mi4yIHx8IGRvdChvZmZzZXQsb2Zmc2V0KTw9Ym91bmQqYm91bmQgfHwgKGJlbG93QmVkICYmICghZGlhZ25vc3RpY0NvbmVFbGlnaWJsZSB8fCAhcmVjZWl2ZXJDYW5QcnVuZSB8fCBoZWlnaHRfc2FmZV9iYWxsX21hc2socCxjb250YWN0QmFsbDEwKSkpKSBzaGFkb3dNYXNrIHw9ICgxdTw8MTApOwp9aWYoY29udGFjdEJhbGwxMS53PjAuMCkgewogICAgZmxvYXQgdG9wPWNvbnRhY3RCYWxsMTEueiswLjAyODU3NTsKICAgIGZsb2F0IGJvdW5kPTAuMDI4NTc1K3RvcC9tYXgoMC4wMSwyLjItdG9wKSoobGVuZ3RoKGNvbnRhY3RCYWxsMTEueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGwxMS54eTsKICAgIGlmKHRvcD49Mi4yIHx8IGRvdChvZmZzZXQsb2Zmc2V0KTw9Ym91bmQqYm91bmQgfHwgKGJlbG93QmVkICYmICghZGlhZ25vc3RpY0NvbmVFbGlnaWJsZSB8fCAhcmVjZWl2ZXJDYW5QcnVuZSB8fCBoZWlnaHRfc2FmZV9iYWxsX21hc2socCxjb250YWN0QmFsbDExKSkpKSBzaGFkb3dNYXNrIHw9ICgxdTw8MTEpOwp9aWYoY29udGFjdEJhbGwxMi53PjAuMCkgewogICAgZmxvYXQgdG9wPWNvbnRhY3RCYWxsMTIueiswLjAyODU3NTsKICAgIGZsb2F0IGJvdW5kPTAuMDI4NTc1K3RvcC9tYXgoMC4wMSwyLjItdG9wKSoobGVuZ3RoKGNvbnRhY3RCYWxsMTIueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGwxMi54eTsKICAgIGlmKHRvcD49Mi4yIHx8IGRvdChvZmZzZXQsb2Zmc2V0KTw9Ym91bmQqYm91bmQgfHwgKGJlbG93QmVkICYmICghZGlhZ25vc3RpY0NvbmVFbGlnaWJsZSB8fCAhcmVjZWl2ZXJDYW5QcnVuZSB8fCBoZWlnaHRfc2FmZV9iYWxsX21hc2socCxjb250YWN0QmFsbDEyKSkpKSBzaGFkb3dNYXNrIHw9ICgxdTw8MTIpOwp9aWYoY29udGFjdEJhbGwxMy53PjAuMCkgewogICAgZmxvYXQgdG9wPWNvbnRhY3RCYWxsMTMueiswLjAyODU3NTsKICAgIGZsb2F0IGJvdW5kPTAuMDI4NTc1K3RvcC9tYXgoMC4wMSwyLjItdG9wKSoobGVuZ3RoKGNvbnRhY3RCYWxsMTMueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGwxMy54eTsKICAgIGlmKHRvcD49Mi4yIHx8IGRvdChvZmZzZXQsb2Zmc2V0KTw9Ym91bmQqYm91bmQgfHwgKGJlbG93QmVkICYmICghZGlhZ25vc3RpY0NvbmVFbGlnaWJsZSB8fCAhcmVjZWl2ZXJDYW5QcnVuZSB8fCBoZWlnaHRfc2FmZV9iYWxsX21hc2socCxjb250YWN0QmFsbDEzKSkpKSBzaGFkb3dNYXNrIHw9ICgxdTw8MTMpOwp9aWYoY29udGFjdEJhbGwxNC53PjAuMCkgewogICAgZmxvYXQgdG9wPWNvbnRhY3RCYWxsMTQueiswLjAyODU3NTsKICAgIGZsb2F0IGJvdW5kPTAuMDI4NTc1K3RvcC9tYXgoMC4wMSwyLjItdG9wKSoobGVuZ3RoKGNvbnRhY3RCYWxsMTQueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGwxNC54eTsKICAgIGlmKHRvcD49Mi4yIHx8IGRvdChvZmZzZXQsb2Zmc2V0KTw9Ym91bmQqYm91bmQgfHwgKGJlbG93QmVkICYmICghZGlhZ25vc3RpY0NvbmVFbGlnaWJsZSB8fCAhcmVjZWl2ZXJDYW5QcnVuZSB8fCBoZWlnaHRfc2FmZV9iYWxsX21hc2socCxjb250YWN0QmFsbDE0KSkpKSBzaGFkb3dNYXNrIHw9ICgxdTw8MTQpOwp9aWYoY29udGFjdEJhbGwxNS53PjAuMCkgewogICAgZmxvYXQgdG9wPWNvbnRhY3RCYWxsMTUueiswLjAyODU3NTsKICAgIGZsb2F0IGJvdW5kPTAuMDI4NTc1K3RvcC9tYXgoMC4wMSwyLjItdG9wKSoobGVuZ3RoKGNvbnRhY3RCYWxsMTUueHkpKzMuMDkzMTM0NjMzMDI1NDIwNik7CiAgICBmbG9hdDIgb2Zmc2V0PXAueHotY29udGFjdEJhbGwxNS54eTsKICAgIGlmKHRvcD49Mi4yIHx8IGRvdChvZmZzZXQsb2Zmc2V0KTw9Ym91bmQqYm91bmQgfHwgKGJlbG93QmVkICYmICghZGlhZ25vc3RpY0NvbmVFbGlnaWJsZSB8fCAhcmVjZWl2ZXJDYW5QcnVuZSB8fCBoZWlnaHRfc2FmZV9iYWxsX21hc2socCxjb250YWN0QmFsbDE1KSkpKSBzaGFkb3dNYXNrIHw9ICgxdTw8MTUpOwp9Cgp9CnVpbnQyIG5lYXJMYW1wTWFza3M9KHNoYWRvd1Bvc3NpYmxlICYmICFkaWFnbm9zdGljQ29uZUVsaWdpYmxlKSA/IHVpbnQyKHNoYWRvd01hc2spOnVpbnQyKDB1KTsKZm9yKGludCBwYW5lbD0wO3BhbmVsPDI7KytwYW5lbCkgewovLyByNTogYm91bmRzIHRoZSBPUklHSU5BTCA4eDQgc2FtcGxlIGNlbnRyZXMgcGx1cyB0aGVpciBmaWx0ZXJlZCBkaXNrcy4KLy8gRm9yIGEgY29udHJpYnV0aW5nIHJheTogdj11KmRlbHRhK2UsIHxlfCA8IFIrbWF4KDFlLTYscSp1KS4KLy8gSGVuY2UgdSA8PSAodi55K1IrMWUtNikvKEgtcSksIGFuZCBmb3VyIG91dHdhcmQgY29uZSBwbGFuZXMKLy8gY2Fubm90IGV4Y2x1ZGUgYSBjb250cmlidXRpbmcgYmxvY2tlciB3aGVuIGV4cGFuZGVkIGJ5IHRoYXQgcmFkaXVzLgoKaWYoc2hhZG93UG9zc2libGUgJiYgZGlhZ25vc3RpY0NvbmVFbGlnaWJsZSkgewogICAgZmxvYXQzIGRpYWdub3N0aWNMaWdodD12NjJFbWl0dGVyQ2VudGVyKHBhbmVsKTsKICAgIGZsb2F0IGRpYWdub3N0aWNIPWRpYWdub3N0aWNMaWdodC55LXAueTsKICAgIGZsb2F0IGRpYWdub3N0aWNRPXNxcnQodjYyRW1pdHRlckFyZWEocGFuZWwpLygzMi4wKjMuMTQxNTkyNjUpKTsKICAgIGlmKGRpYWdub3N0aWNIPD1kaWFnbm9zdGljUSkgewogICAgICAgIG5lYXJMYW1wTWFza3NbcGFuZWxdPXNoYWRvd01hc2s7IC8vIEtlZXAgb3JpZ2luYWwgbm9uLXBsYW5hci9kZWdlbmVyYXRlIGJlaGF2aW91ci4KICAgIH0gZWxzZSB7CiAgICAgICAgZmxvYXQgZGlhZ25vc3RpY1gwPWRpYWdub3N0aWNMaWdodC54LWxlbmd0aCh2NjJFbWl0dGVyVShwYW5lbCkpKjAuODc1LXAueDsKICAgICAgICBmbG9hdCBkaWFnbm9zdGljWDE9ZGlhZ25vc3RpY0xpZ2h0LngrbGVuZ3RoKHY2MkVtaXR0ZXJVKHBhbmVsKSkqMC44NzUtcC54OwogICAgICAgIGZsb2F0IGRpYWdub3N0aWNaMD1kaWFnbm9zdGljTGlnaHQuei1sZW5ndGgodjYyRW1pdHRlclYocGFuZWwpKSowLjc1LXAuejsKICAgICAgICBmbG9hdCBkaWFnbm9zdGljWjE9ZGlhZ25vc3RpY0xpZ2h0LnorbGVuZ3RoKHY2MkVtaXR0ZXJWKHBhbmVsKSkqMC43NS1wLno7CiAgICAgICAgZmxvYXQzIGRpYWdub3N0aWNQbGFuZXNbNF09e25vcm1hbGl6ZShmbG9hdDMoLWRpYWdub3N0aWNILGRpYWdub3N0aWNYMCwwLjApKSwKICAgICAgICAgICAgbm9ybWFsaXplKGZsb2F0MyhkaWFnbm9zdGljSCwtZGlhZ25vc3RpY1gxLDAuMCkpLAogICAgICAgICAgICBub3JtYWxpemUoZmxvYXQzKDAuMCxkaWFnbm9zdGljWjAsLWRpYWdub3N0aWNIKSksCiAgICAgICAgICAgIG5vcm1hbGl6ZShmbG9hdDMoMC4wLC1kaWFnbm9zdGljWjEsZGlhZ25vc3RpY0gpKX07CiAgICAgICAgdWludCBkaWFnbm9zdGljUmVtYWluaW5nPXNoYWRvd01hc2s7CiAgICAgICAgd2hpbGUoZGlhZ25vc3RpY1JlbWFpbmluZyE9MHUpIHsKICAgICAgICAgICAgdWludCBkaWFnbm9zdGljSW5kZXg9Y3R6KGRpYWdub3N0aWNSZW1haW5pbmcpOwogICAgICAgICAgICBkaWFnbm9zdGljUmVtYWluaW5nICY9IGRpYWdub3N0aWNSZW1haW5pbmctMXU7CiAgICAgICAgICAgIGZsb2F0NCBkaWFnbm9zdGljQmFsbD1jb250YWN0VW5pZm9ybXMuY29udGFjdEJhbGxzW2RpYWdub3N0aWNJbmRleF07CiAgICAgICAgICAgIGZsb2F0MyBkaWFnbm9zdGljQ2VudGVyPWZsb2F0MyhkaWFnbm9zdGljQmFsbC54LDAuOCtkaWFnbm9zdGljQmFsbC56LGRpYWdub3N0aWNCYWxsLnkpOwogICAgICAgICAgICBmbG9hdDMgZGlhZ25vc3RpY1Y9ZGlhZ25vc3RpY0NlbnRlci1wOwogICAgICAgICAgICBmbG9hdCBkaWFnbm9zdGljVT1jbGFtcCgoZGlhZ25vc3RpY1YueSswLjAyODU3NSswLjAwMDAwMSkvKGRpYWdub3N0aWNILWRpYWdub3N0aWNRKSwwLjAsMS4wKTsKICAgICAgICAgICAgLy8gUm91bmRvZmYgZXhwYW5zaW9uIGlzIHByb3BvcnRpb25hbCB0byB3b3JsZC1jb29yZGluYXRlIHNjYWxlLgogICAgICAgICAgICBmbG9hdCBkaWFnbm9zdGljU2NhbGU9bWF4KDEuMCxtYXgobGVuZ3RoKHApLG1heChsZW5ndGgoZGlhZ25vc3RpY0NlbnRlciksbGVuZ3RoKGRpYWdub3N0aWNMaWdodCkpKSk7CiAgICAgICAgICAgIGZsb2F0IGRpYWdub3N0aWNSYWRpdXM9MC4wMjg1NzUrMC4wMDAwMDErZGlhZ25vc3RpY1EqZGlhZ25vc3RpY1UrNjQuMCoxLjE5MjA5Mjg5NTUwNzgxMjVlLTcqZGlhZ25vc3RpY1NjYWxlOwogICAgICAgICAgICBib29sIGRpYWdub3N0aWNJbnNpZGU9ZG90KGRpYWdub3N0aWNQbGFuZXNbMF0sZGlhZ25vc3RpY1YpPD1kaWFnbm9zdGljUmFkaXVzICYmCiAgICAgICAgICAgICAgICBkb3QoZGlhZ25vc3RpY1BsYW5lc1sxXSxkaWFnbm9zdGljVik8PWRpYWdub3N0aWNSYWRpdXMgJiYKICAgICAgICAgICAgICAgIGRvdChkaWFnbm9zdGljUGxhbmVzWzJdLGRpYWdub3N0aWNWKTw9ZGlhZ25vc3RpY1JhZGl1cyAmJgogICAgICAgICAgICAgICAgZG90KGRpYWdub3N0aWNQbGFuZXNbM10sZGlhZ25vc3RpY1YpPD1kaWFnbm9zdGljUmFkaXVzOwogICAgICAgICAgICBpZihkaWFnbm9zdGljSW5zaWRlKXtuZWFyTGFtcE1hc2tzW3BhbmVsXSB8PSAoMXU8PGRpYWdub3N0aWNJbmRleCk7fQogICAgICAgIH0KICAgIH0KfQoKfQppZihfc3VyZmFjZS5yb3VnaG5lc3M+PTAuNCAmJiBzaGFkb3dQb3NzaWJsZSl7CmZsb2F0MyBoMThUPXYtbipkb3Qobix2KTsKaWYoZG90KGgxOFQsaDE4VCk8MWUtMTApaDE4VD1jcm9zcyhhYnMobi55KTwwLjk/ZmxvYXQzKDAsMSwwKTpmbG9hdDMoMSwwLDApLG4pOwpoMThUPW5vcm1hbGl6ZShoMThUKTtmbG9hdDMgaDE4Qj1jcm9zcyhuLGgxOFQpOwpjb25zdGV4cHIgc2FtcGxlciBoMThTYW1wbGVyKGNvb3JkOjpub3JtYWxpemVkLGFkZHJlc3M6OmNsYW1wX3RvX2VkZ2UsZmlsdGVyOjpsaW5lYXIpOwpmbG9hdDIgaDE4VVY9ZmxvYXQyKGNsYW1wKChfc3VyZmFjZS5yb3VnaG5lc3MtMC40KS8wLjYsMC4wLDEuMCksc3FydCgxLjAtY2xhbXAobnYsMC4wLDEuMCkpKTsKaDE4VVY9KGgxOFVWKmZsb2F0Mig0Nyw2MykrMC41KS9mbG9hdDIoNDgsNjQpOwpmbG9hdDQgaDE4QT1oMThUYWJsZTAuc2FtcGxlKGgxOFNhbXBsZXIsaDE4VVYpLGgxOEM9aDE4VGFibGUxLnNhbXBsZShoMThTYW1wbGVyLGgxOFVWKTsKZmxvYXQzIGgxOFdYPWgxOEEueCpoMThUK2gxOEEueSpuLGgxOFdZPWgxOEEueipoMThCLGgxOFdaPWgxOEEudypoMThUK2gxOEMueCpuOwpmbG9hdCBoMThTY2FsZT1oMThDLnkqaDE4QS56KihoMThBLngqaDE4Qy54LWgxOEEueSpoMThBLncpLzMuMTQxNTkyNjU7CmlmKGFsbChuZWFyTGFtcE1hc2tzPT11aW50MigwdSkpICYmIGRvdChuLCh2NjJFbWl0dGVyQ2VudGVyKDApK3Y2MkVtaXR0ZXJDZW50ZXIoMSkpKjAuNS1wKT5hYnMoZG90KG4sdjYyRW1pdHRlclUoMCkpKSthYnMoZG90KG4sdjYyRW1pdHRlclYoMCkqMi4wKSkrMWUtNSl7CiBFPWZsb2F0MygxLjApO3Vub2NjbHVkZWRFPWZsb2F0MygxLjApOwogUz1mbG9hdDMoMSwwLjk4NSwwLjk2KSooMTIuOTY5NDQxMjMzNzQ1MjcvMy4xNDE1OTI2NSkqaDE4UG9seWdvbigodjYyRW1pdHRlckNlbnRlcigwKSt2NjJFbWl0dGVyQ2VudGVyKDEpKSowLjUtcCx2NjJFbWl0dGVyVSgwKSx2NjJFbWl0dGVyVigwKSoyLjAsaDE4V1gsaDE4V1ksaDE4V1osaDE4Qy55KTsKfWVsc2V7Zm9yKGludCBwYW5lbD0wO3BhbmVsPDI7KytwYW5lbCkgewogLy8gNjQgc2FtcGxlcyBuZWFyIHNoYWRvdywgZml4ZWQgZ3JpZCB3aXRoIG5vIHRlbXBvcmFsIGppdHRlci4KIGZsb2F0IGgxOFU9MC4wLGgxOFY9MC4wOwogaW50IHNhbXBsZXNYPXNoYWRvd1Bvc3NpYmxlPzg6MjsKIGludCBzYW1wbGVzWj1zaGFkb3dQb3NzaWJsZT80OjI7CiBmbG9hdCBjZWxsQXJlYT12NjJFbWl0dGVyQXJlYShwYW5lbCkvZmxvYXQoc2FtcGxlc1gqc2FtcGxlc1opOwogZmxvYXQgbGlnaHRDZWxsUmFkaXVzPXNxcnQoY2VsbEFyZWEvMy4xNDE1OTI2NSk7CiBmb3IoaW50IGl4PTA7aXg8c2FtcGxlc1g7KytpeCkgewogIGZvcihpbnQgaXo9MDtpejxzYW1wbGVzWjsrK2l6KSB7CiAgIGZsb2F0MyBscD12NjJFbWl0dGVyQ2VudGVyKHBhbmVsKSt2NjJFbWl0dGVyVShwYW5lbCkqKDIuMCooZmxvYXQoaXgpKzAuNSkvZmxvYXQoc2FtcGxlc1gpLTEuMCkrdjYyRW1pdHRlclYocGFuZWwpKigyLjAqKGZsb2F0KGl6KSswLjUpL2Zsb2F0KHNhbXBsZXNaKS0xLjApOwogICBmbG9hdDMgZGVsdGE9bHAtcDtmbG9hdCByMj1kb3QoZGVsdGEsZGVsdGEpO2Zsb2F0MyBsPWRlbHRhL3NxcnQocjIpOwogICBmbG9hdCB2aXNpYmlsaXR5PTEuMDsKICAgaWYobmVhckxhbXBNYXNrc1twYW5lbF0hPTB1KSB7CnVpbnQgcmVtYWluaW5nU2hhZG93QmFsbHM9bmVhckxhbXBNYXNrc1twYW5lbF07CndoaWxlKHJlbWFpbmluZ1NoYWRvd0JhbGxzIT0wdSkgewp1aW50IHNoYWRvd0luZGV4PWN0eihyZW1haW5pbmdTaGFkb3dCYWxscyk7CnJlbWFpbmluZ1NoYWRvd0JhbGxzICY9IHJlbWFpbmluZ1NoYWRvd0JhbGxzLTF1OwpmbG9hdDQgc2hhZG93QmFsbD1jb250YWN0VW5pZm9ybXMuY29udGFjdEJhbGxzW3NoYWRvd0luZGV4XTsKaWYoc2hhZG93QmFsbC53PjAuMCkgewogICAgZmxvYXQzIGNlbnRlcj1mbG9hdDMoc2hhZG93QmFsbC54LDAuOCtzaGFkb3dCYWxsLnosc2hhZG93QmFsbC55KTsKICAgIGZsb2F0MyB0b0NlbnRlcj1jZW50ZXItcDtmbG9hdCB0PWRvdCh0b0NlbnRlcixsKTsKICAgIGZsb2F0IHBlcnBlbmRpY3VsYXIyPWRvdCh0b0NlbnRlcix0b0NlbnRlciktdCp0OwogICAgaWYodD4wLjAgJiYgdCp0PHIyKSB7CiAgICAgICAgLy8gUHJvamVjdCB0aGUgZXF1YWwtYXJlYSBsaWdodC1zYW1wbGUgZGlzayBvbnRvIHRoZSBibG9ja2VyLgogICAgICAgIC8vIERldGVybWluaXN0aWMgZm9vdHByaW50IGZpbHRlcmluZyByZXBsYWNlcyBiaW5hcnkgc2FtcGxlIGp1bXBzLgogICAgICAgIGZsb2F0IGZpbHRlclJhZGl1cz1tYXgoMC4wMDAwMDEsbGlnaHRDZWxsUmFkaXVzKnQvc3FydChyMikpOwogICAgICAgIGZsb2F0IGRpc3RhbmNlVG9SYXk9c3FydChtYXgoMC4wLHBlcnBlbmRpY3VsYXIyKSk7CiAgICAgICAgZmxvYXQgYmxvY2tlZD0xLjAtc21vb3Roc3RlcCgwLjAyODU3NS1maWx0ZXJSYWRpdXMsMC4wMjg1NzUrZmlsdGVyUmFkaXVzLGRpc3RhbmNlVG9SYXkpOwogICAgICAgIHZpc2liaWxpdHkgKj0gMS4wLW1pbigxLjAsc2hhZG93QmFsbC53LzAuODUpKmJsb2NrZWQ7CiAgICB9Cn0KfQp9CiAgIGZsb2F0IGgxOEQ9MC4wO2lmKG5lYXJMYW1wTWFza3NbcGFuZWxdIT0wdSl7ZmxvYXQzIGgxOFE9aDE4V29ybGQobCxoMThXWCxoMThXWSxoMThXWik7ZmxvYXQgaDE4UTI9ZG90KGgxOFEsaDE4USk7aDE4RD1oMThTY2FsZSptYXgoMC4wLGgxOFEueikvKGgxOFEyKmgxOFEyKTt9CmZsb2F0MyB3ZWlnaHRlZD1mbG9hdDMoMSwwLjk4NSwwLjk2KSooMTIuOTY5NDQxMjMzNzQ1MjcvMy4xNDE1OTI2NSkqbWF4KDAuMCxkb3QobixsKSkqbWF4KDAuMCxkb3QodjYyRW1pdHRlck5vcm1hbChwYW5lbCksLWwpKS9yMipjZWxsQXJlYSp2NjJFbWl0dGVyR2FpbihwYW5lbCk7CiAgIHVub2NjbHVkZWRFKz13ZWlnaHRlZDsgRSs9d2VpZ2h0ZWQqdmlzaWJpbGl0eTsgZmxvYXQgaDE4Vz1oMThEKm1heCgwLjAsZG90KHY2MkVtaXR0ZXJOb3JtYWwocGFuZWwpLC1sKSkvcjIqY2VsbEFyZWEqdjYyRW1pdHRlckdhaW4ocGFuZWwpO2gxOFUrPWgxOFc7aDE4Vis9aDE4Vyp2aXNpYmlsaXR5OwogIH0KIH0KUys9ZmxvYXQzKDEsMC45ODUsMC45NikqKDEyLjk2OTQ0MTIzMzc0NTI3LzMuMTQxNTkyNjUpKnY2MkVtaXR0ZXJHYWluKHBhbmVsKSpoMThQb2x5Z29uKHY2MkVtaXR0ZXJDZW50ZXIocGFuZWwpLXAsdjYyRW1pdHRlclUocGFuZWwpLHY2MkVtaXR0ZXJWKHBhbmVsKSxoMThXWCxoMThXWSxoMThXWixoMThDLnkpKihuZWFyTGFtcE1hc2tzW3BhbmVsXSE9MHUgPyBoMThWL21heChoMThVLDFlLTEyKToxLjApOwp9Cn0KfWVsc2V7CmZvcihpbnQgcGFuZWw9MDtwYW5lbDwyOysrcGFuZWwpIHsKIC8vIDY0IHNhbXBsZXMgbmVhciBzaGFkb3csIGZpeGVkIGdyaWQgd2l0aCBubyB0ZW1wb3JhbCBqaXR0ZXIuCiBpbnQgc2FtcGxlc1g9c2hhZG93UG9zc2libGU/ODoyOwogaW50IHNhbXBsZXNaPXNoYWRvd1Bvc3NpYmxlPzQ6MjsKIGZsb2F0IGNlbGxBcmVhPXY2MkVtaXR0ZXJBcmVhKHBhbmVsKS9mbG9hdChzYW1wbGVzWCpzYW1wbGVzWik7CiBmbG9hdCBsaWdodENlbGxSYWRpdXM9c3FydChjZWxsQXJlYS8zLjE0MTU5MjY1KTsKIGZvcihpbnQgaXg9MDtpeDxzYW1wbGVzWDsrK2l4KSB7CiAgZm9yKGludCBpej0wO2l6PHNhbXBsZXNaOysraXopIHsKICAgZmxvYXQzIGxwPXY2MkVtaXR0ZXJDZW50ZXIocGFuZWwpK3Y2MkVtaXR0ZXJVKHBhbmVsKSooMi4wKihmbG9hdChpeCkrMC41KS9mbG9hdChzYW1wbGVzWCktMS4wKSt2NjJFbWl0dGVyVihwYW5lbCkqKDIuMCooZmxvYXQoaXopKzAuNSkvZmxvYXQoc2FtcGxlc1opLTEuMCk7CiAgIGZsb2F0MyBkZWx0YT1scC1wO2Zsb2F0IHIyPWRvdChkZWx0YSxkZWx0YSk7ZmxvYXQzIGw9ZGVsdGEvc3FydChyMik7CiAgIGZsb2F0IHZpc2liaWxpdHk9MS4wOwogICBpZihuZWFyTGFtcE1hc2tzW3BhbmVsXSE9MHUpIHsKdWludCByZW1haW5pbmdTaGFkb3dCYWxscz1uZWFyTGFtcE1hc2tzW3BhbmVsXTsKd2hpbGUocmVtYWluaW5nU2hhZG93QmFsbHMhPTB1KSB7CnVpbnQgc2hhZG93SW5kZXg9Y3R6KHJlbWFpbmluZ1NoYWRvd0JhbGxzKTsKcmVtYWluaW5nU2hhZG93QmFsbHMgJj0gcmVtYWluaW5nU2hhZG93QmFsbHMtMXU7CmZsb2F0NCBzaGFkb3dCYWxsPWNvbnRhY3RVbmlmb3Jtcy5jb250YWN0QmFsbHNbc2hhZG93SW5kZXhdOwppZihzaGFkb3dCYWxsLnc+MC4wKSB7CiAgICBmbG9hdDMgY2VudGVyPWZsb2F0MyhzaGFkb3dCYWxsLngsMC44K3NoYWRvd0JhbGwueixzaGFkb3dCYWxsLnkpOwogICAgZmxvYXQzIHRvQ2VudGVyPWNlbnRlci1wO2Zsb2F0IHQ9ZG90KHRvQ2VudGVyLGwpOwogICAgZmxvYXQgcGVycGVuZGljdWxhcjI9ZG90KHRvQ2VudGVyLHRvQ2VudGVyKS10KnQ7CiAgICBpZih0PjAuMCAmJiB0KnQ8cjIpIHsKICAgICAgICAvLyBQcm9qZWN0IHRoZSBlcXVhbC1hcmVhIGxpZ2h0LXNhbXBsZSBkaXNrIG9udG8gdGhlIGJsb2NrZXIuCiAgICAgICAgLy8gRGV0ZXJtaW5pc3RpYyBmb290cHJpbnQgZmlsdGVyaW5nIHJlcGxhY2VzIGJpbmFyeSBzYW1wbGUganVtcHMuCiAgICAgICAgZmxvYXQgZmlsdGVyUmFkaXVzPW1heCgwLjAwMDAwMSxsaWdodENlbGxSYWRpdXMqdC9zcXJ0KHIyKSk7CiAgICAgICAgZmxvYXQgZGlzdGFuY2VUb1JheT1zcXJ0KG1heCgwLjAscGVycGVuZGljdWxhcjIpKTsKICAgICAgICBmbG9hdCBibG9ja2VkPTEuMC1zbW9vdGhzdGVwKDAuMDI4NTc1LWZpbHRlclJhZGl1cywwLjAyODU3NStmaWx0ZXJSYWRpdXMsZGlzdGFuY2VUb1JheSk7CiAgICAgICAgdmlzaWJpbGl0eSAqPSAxLjAtbWluKDEuMCxzaGFkb3dCYWxsLncvMC44NSkqYmxvY2tlZDsKICAgIH0KfQp9Cn0KICAgZmxvYXQgbmw9bWF4KDAuMDAxLGRvdChuLGwpKTtmbG9hdDMgaD1ub3JtYWxpemUobCt2KTtmbG9hdCBuaD1tYXgoMC4wLGRvdChuLGgpKTtmbG9hdCB2aD1tYXgoMC4wLGRvdCh2LGgpKTsKICAgZmxvYXQgZGVub209bmgqbmgqKGEyLTEuMCkrMS4wOwogICBmbG9hdCBEPWEyLygzLjE0MTU5MjY1KmRlbm9tKmRlbm9tKTsKICAgZmxvYXQgRz0yLjAqbnYvKG52K3NxcnQoYTIrKDEuMC1hMikqbnYqbnYpKSoyLjAqbmwvKG5sK3NxcnQoYTIrKDEuMC1hMikqbmwqbmwpKTsKICAgZmxvYXQgRj0wLjAxMiswLjk4OCpwb3coMS4wLXZoLDUuMCk7CiAgIGZsb2F0MyB3ZWlnaHRlZD1mbG9hdDMoMSwwLjk4NSwwLjk2KSooMTIuOTY5NDQxMjMzNzQ1MjcvMy4xNDE1OTI2NSkqbWF4KDAuMCxkb3QobixsKSkqbWF4KDAuMCxkb3QodjYyRW1pdHRlck5vcm1hbChwYW5lbCksLWwpKS9yMipjZWxsQXJlYSp2NjJFbWl0dGVyR2FpbihwYW5lbCk7CiAgIHVub2NjbHVkZWRFKz13ZWlnaHRlZDsgRSs9d2VpZ2h0ZWQqdmlzaWJpbGl0eTsgUys9d2VpZ2h0ZWQqdmlzaWJpbGl0eSpEKkcqRi8oNC4wKm52Km5sKTsKICB9CiB9Cn0KCn1FPXRlbXBvcmFsRmllbGREaWZmdXNlKHAsbix0ZW1wb3JhbEZpZWxkMCx0ZW1wb3JhbEZpZWxkMSkqKEUvbWF4KHVub2NjbHVkZWRFLGZsb2F0MygwLjAwMDAwMSkpKTsKLy8gdjY0Q2xvdGhOYXA6IHdlYWsgYWxiZWRvLWNvbG91cmVkIGdyYXppbmcgcmVzcG9uc2U7IHNoYWRvdy9BTyBzdGF5IG11bHRpcGxpY2F0aXZlLgpfc3VyZmFjZS5lbWlzc2lvbi5yZ2IgPSAoX3N1cmZhY2UuZGlmZnVzZS5yZ2IgKiBfc3VyZmFjZS5tdWx0aXBseS5yZ2IpICogKDEuMCswLjEwKnBvdygxLjAtY2xhbXAoYWJzKGRvdChub3JtYWxpemUoKHNjbl9mcmFtZS5pbnZlcnNlVmlld1RyYW5zZm9ybSpmbG9hdDQoX3N1cmZhY2UuZ2VvbWV0cnlOb3JtYWwsMC4wKSkueHl6KSx2KSksMC4wLDEuMCksMy4wKSkgKiAoRS8zLjE0MTU5MjY1KzAuMjYqX3N1cmZhY2UuYW1iaWVudE9jY2x1c2lvbikrMC4zNSpTKzAuMzUqZmxvYXQzKG1heCgwLjAsKCgoKCgoKCgoKC0wLjAyODgwMzMxMDAzMzI1NjkzNCpudiswLjE4NzIwNjEwMDg4Nzk1MjIzKSpudistMC41NTAyNzY3NjM2MDYzNzk3KSpudiswLjk3NTI4ODA1MjI4MjU0NTkpKm52Ky0xLjE3NzM2MjE4ODc5NzYxKSpudisxLjAzOTkwMjM0NDA5NDYzNjIpKm52Ky0wLjY5MzQ2NDUxMDU2MzI1ODEpKm52KzAuMzIxODA0MjUyMDk3OTQ3NDQpKm52Ky0wLjA1MzczNjA4NjE0NzU0Njg5NCkqbnYrLTAuMDQyNjYyODEwNjk4MjU3NykqbnYrMC4wMjM4NjQzMzM3ODE3MTUxMDcpKSk7Cl9zdXJmYWNlLmRpZmZ1c2UucmdiPWZsb2F0MygwLjApOwpfc3VyZmFjZS5tZXRhbG5lc3M9MS4wOwoKX3N1cmZhY2UubXVsdGlwbHkucmdiPWZsb2F0MygxLjApOw=="
    private static let h18R6Table0 = "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"
    private static let h18R6Table1 = "JpxdPu2ZOzwNO9M9osOvO9qeaj6Vgjo8wE3ePWQ2xzujznc+ilQ5PHFL6T0MquA7HpKCPj0PODxzKPQ9j/L7OwlMiT4ZsjY8Ktn+PZhoDDwpEZA+gTw1PBapBD6tehs8cN2WPtKtMzwxxAk+Qf8qPLGsnT5iBTI8lLgOPoe/OjyieqQ+h0IwPDeBEz4agEo85EKrPpZkLjx0GRg+MwNaPAQBsj7xaiw8FH0cPhQLaTyNsLg+DVUqPGSoID6EXHc8D02/Pn0iKDxGmCQ+kWCCPCzSxT750iU8QUooPryEiDynO8w+bWYjPIa8Kz5aB448d4XSPv7cIDz/7S4+7dmSPM+r2D4QNx48St4xPkHzljwuq94+TXUbPLmNND5+T5o8bIDkPqWYGDxL/TY+B/CcPMEo6j5PohU8mS45PhXbnjzMoe8+xZMSPMwjOz4wG6A8l+n0PsNuDzyH3zw+gL6gPJb++T49NQw8z2Q+PhHWoDyn3/4+WOkIPPe2Pz4KdaA8B8YBP2aNBTyJ2UA+7K+fPLgBBD/WIwI8MtBBPt+bnjzkIgY/Xl79O66eQj4LTp08sSkIPw5k9juzSEM+DdubPGkWCj/xXe876dFDPodWmjx26Qs/MlHoO9c9RD7F0pg8W6MNP+hC4Tvej0Q+emCXPLNEDz8GONo7LMtEPpcOljwpzhA/SzXTO7/yRD426pQ8ekASPz0/zDtYCUU+jf6TPGmcEz8aWsU7gxFFPvxUkzzE4hQ/14m+O44NRT4a9ZI8XhQWPxnStzuS/0Q+0+SSPAoyFz8uNrE7b+lEPocokzyhPBg/FLmqO9DMRD4uw5M89jQZP2xdpDsyq0Q+gbaUPNsbGj+DJZ474IVEPiIDljwd8ho/VBOYO/1dRD7BqJc8h7gbP4YokjuDNEQ+RaaZPNxvHD9zZow7SwpEPvD5mzzbGB0/K86GOwzgQz57oZ48PLQdP3hggTtftkM+PpqhPK5CHj/FO3g7xo1DPj7hpDzfxB4/cA1uO6lmQz5Qc6g8S4hdPlSZOzw/MtM9OXuvO0mKaj7ugTo80UTePakNxzt3uXc+41M5PHVC6T2+nuA7SYeCPqEOODx9H/Q9CwL8OwZBiT6QsTY8TtD+PU98DDwIBpA+Ezw1PL6kBD7smBs8Q9KWPoWtMzz3vwk+oyYrPIqhnT44BTI8fLQOPsvuOjyRb6Q+f0IwPEd9Ez4ltko89zerPrBkLjyuFRg+Fj9aPEr2sT4qayw8eHkcPhJMaTwTprg+YVUqPPOkID4Fonc84EK/PugiKDz/lCQ+WIWCPFLIxT540yU8IkcoPl6riDwrMsw+/WYjPI65Kz6zL448X3zSPpvdIDwt6y4+3wOTPCGj2D64Nx48ntsxPq8elzzwot4+/3UbPDGLND5PfJo8onjkPmCZGDzn+jY+HR6dPG8h6j4SoxU8WCw5PlMKnzzzmu8+kZQSPK8hOz5zS6A8OOP0PplvDzyN3Tw+pe+gPLL4+T4eNgw892I+PvEHoTw/2v4+RuoIPEG1Pz58p6A8kMMBP2KOBTz110A+yOKfPH3/Az/hJAI8wM5BPvrOnjzkIAY/l2D9O1ydQj49gZ086icIP2xm9juCR0M+MA6cPNoUCj91YO871tBDPneJmjwc6As/4FPoO+I8RD5iBZk8NaINP8JF4TsEj0Q+qZKXPL1DDz8MO9o7bMpEPkJAljxjzRA/fjjTOxbyRD5JG5U83j8SP5tCzDvFCEU++y6UPPabEz+jXcU7AxFFPr2Ekzx24hQ/io2+OyANRT4pJJM8MxQWP/PVtzsz/0Q+MROTPAAyFz8vOrE7HelEPjdWkzyzPBg/Nr2qO4rMRD438JM8IjUZP61hpDv0qkQ+7eKUPB0cGj/fKZ47qYVEPv0uljx08ho/yBeYO8tdRD4Y1Jc877gbPw0tkjtWNEQ+JtGZPFRwHD8Ja4w7HwpEPmoknDxfGR0/zNKGO+DfQz6ey548ybQdPx9lgTsytkM+GsShPERDHj8YRXg7l41DPuMKpTx6xR4/wRZuO3ZmQz7MnKg8aExdPqqXOzwSGNM9GLauO09Maj4egDo8QirePQKjxju0eXc+ElI5PL4n6T2wiOA7r2aCPu8MODzZBPQ9eTn8O+UfiT4ZsDY89rX+Pdm6DDyU5I8+7Do1PNKXBD5B9hs8r7CWPrusMzxgswk+3p4rPAmAnT7TBDI8TKgOPlN+OzxUTqQ+f0IwPIhxEz7RWUs8LBerPhFlLjxoChg+PfRaPBvWsT7kayw8r24cPoUQajykhrg+a1YqPKeaID4MdHg8UyS/PjYkKDwviyQ+evSCPMOqxT4A1SU8yj0oPhYgiTy1Fcw+tGgjPKywKz6WqY48GGHSPnvfIDy84i4+koKTPBuJ2D66OR48nNMxPt+hlzw5it4+HXgbPJyDND6oA5s8R2HkPpmbGDy98zY+S6mdPHkL6j5lpRU8mCU5PviYnzxphu8+AJcSPFgbOz4r3aA8H9D0PiVyDzyf1zw+AoShPArn+T7LOAw8cV0+Pn6eoTwHyv4+GO0IPCOwPz7BP6E8K7wBP12RBTw900A+R3ygPMz4Az8LKAI8bMpBPjhpnzzjGgY/UWf9O2qZQj7BG548liIIP5Rt9jvvQ0M+hqicPC4QCj8VaO87n81DPjUjmzwR5As//FvoOwI6RD4pnpk8w54NP19O4Tt2jEQ+JCqYPN5ADz8sRNo7K8hEPivWljwOyxA/IkLTOxzwRD5qr5U8DD4SP8NMzDsNB0U+LMGUPJ2aEz9MaMU7hQ9FPuIUlDyP4RQ/r5i+O9cLRT43spM8tBMWP4/htzsX/kQ+Jp+TPOExFz86RrE7KehEPh/gkzzrPBg/p8mqO7bLRD4meJQ8qDUZP3pupDs8qkQ+AGmVPOccGj/9Np47BoVEPlWzljx68xo/KiWYOzddRD7dVpg8KrobP6k6kjvLM0Q+hFKaPLtxHD/SeIw7mwlEPo6knDzrGh0/tOCGO1zfQz63Sp88dLYdPxtzgTurtUM+VkKiPAZFHj8dYXg7CY1DPnOIpTxNxx4/vDJuO95lQz7dGak8pudcPlOVOzxC7dI9VqqtOyvkaT6OfTo81f7dPXogxjuyDnc+gU85PA786D0biOA7CjCCPpEKODxC2fM9U7H8O23oiD4YrjY80Yr+PYMtDTyerI8+aDk1PKGCBD7gmRw8kXiWPsmrMzyyngk+uW0sPBVInT59BDI8PZQOPg5zPDzaFqQ+yEIwPC1eEz6hb0w8duCqPvJlLjzM9xc+AydcPGygsT5RbSw82lwcPthcazw7Urg+VVgqPJqJID4q13k8ZfG+Po0mKDzoeiQ+VrCDPIF5xT6z1yU8Ry4oPmDliTxI5ss+tGsjPOihKz6Yd488pDPSPrviIDy01C4+r1iUPL5d2D4xPR48SsYxPod/mDwOYd4+xHsbPP92ND5O6Js8YDrkPmyfGDzR5zY+W5SePOXm6T5jqRU8Xho5PtWJoDw0ZO8+K5sSPM0QOz4q06E8T7D0PoF2DzzCzTw+a36iPKLJ+T5ePQw8QlQ+Po+cojwFr/4+6fEIPJ+nPz6tQKI8268BP3OWBTxky0A+QX+hPKjtAz9uLQI8OsNBPm9toDzmEAY/wHL9O9uSQj5rIJ88uBkIP7p59jv+PUM+46ydPGUICj/+dO87RshDPpMmnDxU3Qs/smnoOzk1RD7mn5o8B5kNP+pc4Ts2iEQ+tSmZPBc8Dz+RU9o7a8REPhvTlzwuxxA/YlLTO9PsRD5bqZY8BTsSP9xdzDsvBEU+2beVPGKYEz86esU7Cg1FPh4IlTwR4BQ/a6u+O7EJRT7qoZQ85RIWPw71tzs+/EQ+T4uUPLExFz9vWrE7kOZEPs3IlDxLPRg/hd6qO1XKRD56XZU8iTYZP+6DpDsGqUQ+J0uWPD0eGj/3TJ4784NEPoiSlzw19Ro/lTuYOz5cRD5dM5k8PbwbP3JRkjvjMkQ+mCybPBh0HD/jj4w7uwhEPoF8nTyHHR0/+veGO37eQz7YIKA8QrkdP3+KgTvHtEM+8hajPPxHHj/7j3g7GYxDPthbpjxgyh4/hmFuO9xkQz5Z7Kk8BVlcPv+SOzwxs9I9TqCsO/VQaT71ejo86MPdPcy+xTund3Y+6kw5PLfA6D3MyOA7BOOBPjsIODz3nfM9IYv9O1maiD43rDY8BFD+PTXhDTzwXY8+Izg1PK5lBD72jR08vSmWPjurMzxhggk+n5stPI75nD60BDI8sngOPmjUPTwMyaM+xkMwPIVDEz6W/k08xZOqPrBnLjwb3hc+at5dPDZVsT7Cbyw8KkQcPks4bTzSCLg+Z1sqPPNxID4C03s8Faq+PiwqKDxLZCQ+9byEPIw0xT7K2yU8sRgoPnj/ijzno8s+MnAjPFaNKz4inpA8CPTRPo7nIDwjwS4+xoqVPBIh2D5NQh48trMxPle8mTxzJ94+IoEbPGRlND4FL5088wPkPgalGDwu1zY+I+SfPLuz6T47rxU8sAo5PsjhoTxcNO8+QaESPBUCOz5VMqM80YP0Ptx8Dzz9vzw+yeOjPIKg+T4FRAw8cEc+PgsHpDxBif4+5fgIPL6bPz4qr6M8o54BP9CdBTxwwEA+mvCiPBXeAz81NQI8L7lBPoHgoTzvAgY/OIP9O7SJQj4alKA8Ug0IPzCL9ju0NUM+IiCfPIT9CT+Ch+870MBDPmaYnTzr0ws/U33oO40uRD5rD5w8BpENP7Jx4TtJgkQ+JpaaPGw1Dz+Fado7ML9EPtE7mTzHwRA/hWnTOzzoRD7RDZg80DYSPyt2zDsvAEU+qheXPEqVEz+vk8U7kQlFPghjljwC3hQ/+8W+O7EGRT7I95U8yhEWP6sQuDun+UQ+GtyVPHUxFz8Hd7E7VOREPpgUljzbPRg/A/yqO2TIRD5vpJY80DcZPzyipDtTp0Q+g42XPCYgGj/7a547b4JEPpjQmDyt9xo/NVuYO91aRD56bZo8ML8bP5BxkjuZMUQ+JGOcPHV3HD9ksIw7fAdEPuOvnjw8IR0/wBiHO0DdQz59UaE8P70dP26rgTuBs0M+SEWkPDFMHj/v0Xg7wopDPkyIpzy/zh4/WKNuO21jQz5YF6s87Z9bPqeROzzxa9I9QeCrOyWSaD5UeTo8eHvdPUa3xTsctHU+TUs5PJp36D16d+E7bH+BPuMGODy0VPM9oun+O381iD5cqzY8IAf+PZ3jDjxp+I4+8Dc1PKpBBD6v3R48HMSVPs2rMzwDXwk+QzIvPGKUnD4dBjI8KlYOPnCrPzzcZKM+C0YwPPkhEz65D1A8ETGqPstqLjyovRc+3yNgPHH0sD6ocyw85CQcPu2sbzxnqrc+BGAqPOZTID5dcn48YU6+PmwvKDx+RyQ+GyCGPOTbxD6X4SU8J/0nPnx0jDyTTss+eHYjPA9zKz6gI5I8SKLRPj3uIDwcqC4+gR+XPBrT1z5XSR487psxPilfmzxw3d0+fYgbPNpOND7N3p48CL7jPq6sGDzfwTY+up+hPAJy6T4utxU8nPY4Pvynozzo9u4+hakSPDrvOj7gAaU8rkr0PneFDzxbrjw+UrulPLRr+T4BTQw8BTc+PizlpTzFWP4+TwIJPIiMPz5tkqU8iYgBP7OnBTxqskA+hdekPBfKAz+gPwI8VaxBPp3JozwD8QU/N5n9O/59Qj73faI8a/0HP3Ci9jsYK0M+YQmhPJLvCT8ZoO87Q7dDPsR/nzzbxws/UZfoOwMmRD7B8508xIYNPyON4TuzekQ+cXacPOMsDz9zhto7fbhEPjcXmzzfuhA/8IfTO1viRD6g45k8cTESPxGWzDsO+0Q+XeeYPFuREz8GtcU7HAVFPkEsmDxp2xQ/tui+O9YCRT5Uupc8bBAWP7g0uDtR9kQ+6ZeXPDgxFz9QnLE7ceFEPr7JlzyjPhg/bSKrO+DFRD4bU5g8hDkZP6nJpDsdpUQ+/zWZPKwiGj9LlJ47doBEPkJzmjzs+ho/RoSYOw9ZRD7BCpw8EMMbPz6bkjvnL0Q+g/udPN57HD+L2ow72AVEPuBDoDwYJh0/OkOHO53bQz6h4aI8eMIdPxbWgTvSsUM+IdKlPLRRHj9SJ3k7/IhDPmcSqTx61B4/iPhuO4hhQz5An6w88bxaPneSOzwbGtI91aSrOzSoZz7geTo89yfdPQk5xjt1xHQ+2Us5PPki6D2VueI7agWBPq0HODyG//I9X3UAPAC6hz6XrDY8+bH9PQpBEDwifI4+yDk1PGIXBD7MkyA8wEeVPmGuMzxINQk+wjsxPJ0YnD6BCTI8OS0OPl8CQjxT6qI+SEowPAP6Ej7qrVI8XbipPuJvLjzVlhc+PwNjPCF+sD6OeSw8Vf8bPsnHcjz6Nrc+q2YqPLEvID7C4YA8TN69PsE2KDyzJCQ+g+GHPItvxD6H6SU8z9snPqxMjjxR5so+734jPDBTKz7EEJQ8aD7RPir3IDy5iS4+8B+ZPN5z1z6sUh48CH8xPlVxnTwLg90+MZIbPHIzND4zAaE8pmjjPr22GDz1pzY+1dCjPMMh6T6awRU8MN44PjvmpTzjq+4+UbQSPEzYOj6jS6c88AT0Pq2QDzzqmDw+6A6oPEEr+T6sWAw8DyM+PtBAqDyaHf4+fQ4JPAp6Pz5R9Kc8km0BP3S0BTxgoUA+1D2nPLWxAz8ETQI8t5xBPocypjwp2wU/YrX9O8NvQj6456Q8COoHPx3A9js0HkM+S3KjPJPeCT9ev+87qatDPkPmoTwquQs/RLjoO6IbRD5pVqA8SXoNP9Kv4Tt5cUQ+ANSePIMiDz/mqto7V7BEPppunTx/shA/Kq7TOzPbRD73M5w88ioSPw2+zDvN9EQ++i+bPJ6MEz+63sU7rP9EPqtsmjxP2BQ/ERS/Ox7+RD5B8pk81A4WP6RhuDs78kQ+PseZPAIxFz+xyrE75d1EPonwmTywPxg/I1KrO8fCRD6QcZo8sjsZP5D6pDthokQ+b0ybPN0lGj89xp47An5EPhyCnDwB/xo/GbeYO89WRD6IEp487McbP8jOkjvHLUQ+yvyfPGWBHD+eDo07yANEPkc/ojwuLB0/qneHO4zZQz7Q16Q8A8kdP7YKgjuyr0M+w8OnPJtYHj+bkHk7v4ZDPisAqzym2x4/g2FvOyJfQz7Uia48WLJZPpSWOzw7wNE9DBesOx2VZj7LfTo8ysvcPdplxzthqnM+wU85PArF5z38quQ7rnWAPsALODxvoPI9DNMBPGkohz4BsTY8WVL9PRYEEjyI6Y0+rj41PJ7nAz6IuiI8+bSUPuWzMzzeBQk+vsIzPHqGmz66DzI8cP4NPtjkRDyZWaI+RVEwPB3MEj465lU8xSmpPqh3LjwJahc+U4tmPFXyrz4bgiw80dMbPneZdjyWrrY+928qPJgFID5q7II82lm9PrxAKDwf/CM+LguKPIbvwz4i9CU81rQnPsOSkDwia8o+GYojPN4tKz7ocJY8a8jQPtMCITwXZi4+75ebPF8D1z7IXh48Hl0xPhr/nzxJGN0+uZ4bPEITND7AoqM80wPjPq7DGDyEiTY+L4SmPAXD6D70zhU8f8E4PmOpqDxUU+4+HMISPFy9Oj6OHKo8n7LzPvKeDzy7fzw+fOuqPDTf+D55Zww8ngs+PucmqzzM1/0+4h0JPFNkPz674ao8w00BP4PEBTxejUA+XjCqPPSUAz/OXQI8YYpBPgUoqTxlwQU/kNj9Ow5fQj4L3qc8L9MHPwTl9jsSD0M+bmemPI7KCT8b5u87CZ5DPlTYpDzfpws/7eDoO3IPRD6xQ6M8nGsNP3fa4TuiZkQ++bqhPFQWDz+R19o7wqZEPvZNoDytqBA/3dzTO8bSRD6gCp88WiMSP8LuzDtu7UQ+GP2dPB2HEz9lEcY7QPlEPqAvnTy+1BQ/nki/O4r4RD6rqpw8Dw0WP/iXuDti7UQ+73ScPOIwFz+tArI7q9lEPoaTnDwPQRg/oYurOxO/RD4KCp08az4ZP2c1pTsYn0Q+wdqdPMopGj8+Ap87C3tEPr4GnzwABBs/FfSYOxJURD4PjqA82M0bP4wMkzswK0Q+4m+iPB2IHD/3TI07QAFEPqiqpDySMx0/ZLaHOwLXQz5APKc89tAdP51JgjsUrUM+ECKqPP9gHj9cDno7/oNDPiVZrTxg5B4/1N5vOzBcQz5K3rA8JYRYPsieOzwGYNE9IFStO2lcZT70hTo8nGjcPXNXyTvlaHI+8Fc5PGlf5z3SYuc796J/Pg4UODzyOPI9uJgDPL6Bhj6LuTY8p+n8PZw3FDxmQY0+kkc1PACzAz5jXSU8YgyUPj+9MzxV0Qg+9tM2PGfemj6lGTI8UMoNPlRhSDz6sqE+01swPLWYEj49yVk8e4WoPuaCLjyhNxc+9M5qPC1Rrz4Njiw8paIbPiQ3ezxLEbY+m3wqPNvVHz7fZIU8E8G8PgtOKDz7zSM+4amMPNRbwz4PAiY8aIgnPnZUkzwE3ck+mJgjPD8DKz6KUpk8TUDQPtgRITxZPS4+npaePJqB1j5Kbh48TTYxPhwYozwondw+sa4bPGfuMz5206Y8jo/iPhnUGDylZjY+DMqpPMhV6D7V3xU8oKA4PuABrDw97e0+e9MSPICeOj4hha08v1PzPtqwDzzhYjw+lWGuPJGH+D76eQw8xfA9Pu6nrjxgh/0+DTEJPHZLPz4Ua648ISkBP2vYBTx1dkA+cb+tPNhzAz+HcgI8Y3VBPkC6rDy9owU/ygP+O+1LQj7ycKs85rgHPygS9zu+/UI+pPipPImzCT9JFfA7bo5DPqFlqDwBlAs/PRLpO3kBRD4Ny6Y8xFoNP/sN4jszWkQ+ljqlPF4IDz9SDds7wptEPkLEozx0nRA/3BTUOxjJRD5PdqI8tRoSP/oozTvz5EQ+Hl2hPOOAEz/GTcY72PFEPjiDoDzE0BQ/Eoe/OxXyRD5Q8Z88KQsWP2DYuDvB50Q+Xq6fPOYwFz/lRLI7v9REPrW/nzzRQhg/fs+rO7y6RD4lKaA8v0EZP7p6pTs5m0Q+I+2gPIcuGj/USJ87h3dEPuoMojz7CRs/tzuZO89QRD6riKM869QbPwBVkzsUKEQ+rV+lPCCQHD8Elo07Nf5DPniQpzxhPB0/zv+HO/HTQz73GKo8bdodPyuTgjvqqUM+nfasPP5qHj9KoXo7qYBDPnomsDzH7h4/I3FwO6FYQz5dpbM8PTdXPjarOzyp+dA9P3mvO4ACZD6jkjo8xv7bPZoqzDvZA3E+1WQ5PJLy5j25/eo74jR+PiUhODylyfE969QFPFLHhT7cxjY8h3j8PcHqFjzJhIw+LFU1POF5Az6djCg8xk6TPjfLMzwEmAg+QIE6PPsgmj4PKDI8LJENPrSLTDzf9qA+xWowPBpgEj4ubV48wcunPm+SLjzl/xY+8+ZvPNCarj43niw8FGwbPiZegDwtX7U+aI0qPLegHz4pWog8+xO8PnpfKDx6miM+2c2PPHO0wj4bFCY8tlYnPhWjljzwO8k+N6sjPH/TKj7mx5w8BKbPPgElITykDy4+/C6iPIbu1T71gR48twoxPvHPpjydEdw+2cIbPP/EMz5ep6o8zwviPr7oGDx1PzY+xLatPAfa5z779BU8rns4PjoEsDybee0+KekSPM97Oj75mbE8UOjyPh7HDzxzQjw+z4WyPFok+D7kkAw8mNI9Pm/YsjxaLP0+r0gJPIUvPz7HpLI8rf8AP9rwBTy3XEA+Sv+xPGROAz/XiwI8zF1BPkP9sDw2ggU/Vzj+O202Qj49tK88MZsHP8dI9ztD6kI+djmuPIqZCT8aTvA74XxDPmqhrDyXfQs/Wk3pO8DxQz5x/6o8yEcNP3ZL4jsyTEQ+d2WpPKr4Dj81Tds7WY9EPsnjpzzckBA/KVfUOye+RD7riKY8DRESP6htzTtY20Q+jmGlPPt5Ez/ElMY7b+lEPoV4pDxuzBQ/RtC/O7vqRD7T1qM8MwkWP6ojuTtR4UQ+tIOjPB8xFz8akrI7Fs9EPsKEozwIRRg/cR6sO7i1RD4K3qM8xEUZPzXLpTu4lkQ+OZKkPCo0Gj+emp87anNEPryipTwOERs/lI6ZO/dMRD7qD6c8P90bP7GokztlJEQ+L9moPIuZHD9I6o07lfpDPiz9qjy5Rh0/ZVSIO0fQQz7iea08iuUdP9LngjsipkM+z0ywPLt2Hj88Sns7rnxDPg1zszwA+x4/OhlxO2FUQz5u6bY82M9VPlC7Ozymi9A9A6+yO1OLYj5+ozo8Io3bPcAK0DvJfm8+S3Y5PK995j0kqe87L6R8PhozODwBUvE9NJ8IPHH6hD492TY8t/77Pfg1Gjy/tIs+82c1PDg8Az7QYSw8/nySPmfeMzz5WQg+peU+PNNOmT60OzI8IlMNPsWAUTy2JaA+6n4wPHQiEj7/8GM83/ymPiKnLjwCwxY+sfR1PGTPrT6Bsyw8TTAbPnGmgzxImLQ+T6MqPFpmHz6T34s8kVK7Pv91KDzJYSM+oouTPFT5wT45KyY86h8nPlCUmjzQh8g+6cIjPMSeKj6v56A8efnOPkE9ITwe3S0+kXimPApK1T68mh48f9owPsY+qzyTdds+JNwbPCqXMz4fN688g3jhPowCGTwQFDY+T2OyPLFP5z5RDxY8xFI4PpTJtDxg+Ow+EAQTPGVVOj5KdLY8RnDyPqLiDzyKHjw+UnG3PIa19z4WrQw8LbE9PnTRtzy1xvw+o2UJPJMQPz6tp7c8Z9EAP6QOBjw0QEA+gwi3PJkkAz+OqgI8qkNBPlwJtjzPXAU/x3f+O5seQj7kv7Q8FHoHP2GK9zuq1EI+g0GzPJV8CT//kfA7aGlDPueisTykZAs/pZPpO0vgQz6m9688sDINPzuU4jugPEQ+81GuPD/nDj99mNs7iIFEPmXCrDzvghA/9aTUO/KxRD7UV6s8bQYSP+69zTuZ0EQ+QR+qPHNyEz9y58Y7/99EPtgjqTzJxxQ/QCXAO3HiRD7ubqg8PQcWP8t6uTsH2kQ+FgioPKAxFz8167I7pMhEPjP1pzzKRxg/UnmsO/ivRD6fOqg8kUoZP6QnpjuFkUQ+RNuoPM06Gj9d+J87oW5EPszYqTxTGRs/YO2ZO3hIRD6/M6s89OYbP0YIlDsPIEQ+seusPH+kHD9gSo47TPZDPmj/rjy+Uh0/ubSIO/HLQz77bLE8dPIdPx1IgzuloUM+/TG0PF+EHj8yCnw79ndDPpNLtzw3CR8/CthxO1lPQz6Xtro8M1BUPhHOOzxVE9A9zDW3O0L5YD62tzo8YhHbPbk+1Tsh3G0+xYs5PNv+5T24r/U7M/N6PqVJODyF0PA9wh0MPBschD6u8DY8Fnv7Pco/HjwN0oo+KoA1PKP5Aj64AzE8jpeRPk73Mzz3Fgg+lShEPEdomD4/VTI8FBANPkxpVzy0P58+F5kwPL3fET5Uf2o88himPvDBLjwFgRY+DiV9PPrurD70ziw8aO8aPgWMhzyavLM+Z78qPOMmHz7QDZA8v3y6PrqSKDwOJCM+E/2XPFkqwT6TSCY8K+QmPhVDnzyAwMc+3OAjPDZlKj7HzaU8hDrOPsRbITzspS0+EZCrPACU1D7LuR48yqUwPvaBsDzlyNo+uvsbPAplMz6NoLQ8iNXgPqkiGTyY5DU+ze23PKi25j74LxY8/yU4PjVwujxzaew+SiUTPForOj5YMrw8jOvxPnwEEDw89zs+RkK9PAU79z6fzww8mYw9PuywvTxiVvw+8IgJPLLuPj5qkb08SZ4AP8oyBjz7IEA+aPi8PHP2Aj+izwI8CSdBPm/7uzyJMwU/98P+O34EQj5XsLo8jVUHP8LY9zv5vEI+uyy5PKtcCT+y4vA7B1RDPoSFtzwuSQs/x+bpOxrNQz6NzrU8gBsNP97p4jt7K0Q+VRq0PCXUDj+s8Ns7SXJEPsZ5sjy2cxA/r//UO3KkRD4S/LA83/oRPykbzjusxEQ+ma6vPFhqEz8ZR8c7e9VEPuScrjznwhQ/NIfAOyvZRD6k0K08VwUWP+XeuTvU0UQ+ylGtPHwyFz9GUbM7WMFEPpQmrTwsSxg/I+GsO2mpRD6rU608PlAZP/iQpjuMi0Q+SNytPItCGj/wYqA7F2lEPlfCrjzoIhs/7ViaOzlDRD6dBrA8KvIbP4R0lDv6GkQ+4aixPCGxHD8Et447QPFDPhCoszyXYB0/eCGJO9HGQz5kArY8UwEeP6q0gztYnEM+iLW4PBeUHj9X4nw7Y3JDPrO+uzybGR8/qq5yO21JQz7GGr88ZbZSPnfiOzy7jc895WS9O7hKXz5zzjo8zYjaPTIo3DtrGmw+qKQ5PK5z5T2+ev07+SB5Pm5kODwmQ/A9/IcQPOQrgz4fDTc8/+v6PYtBIzyo3Ik+BZ41PH2xAj4LrTY8zp6QPmEWNDyFzgc+mYRKPK9tlz5ldTI8r8cMPjB/XjwARZ4+M7owPMSXET6iUXI84R+lPu7jLjzYORY+4NiCPEH5qz7D8Sw8ZqkaPoEsjDzOy7I+++IqPGTiHj6yA5U8O5K5Pge3KDxh4SI+OUKdPEhHwD6ObSY8lqMmPmfQpDzD5cY+egYkPPUmKj4AnKs86WjNPvuBITwvai0+/ZexPCzM0z6Q4B48t2wwPo28tjxbC9o+ByMcPL8uMz4UB7s8qyLgPnxKGTwosTU+4nm+PL4O5j5TWBY8evU3PtAbwTyszOs+Mk4TPMf9OT7C98I8AFrxPv4tEDydzDs+ERzEPLm09j7K+Qw87GQ9PuuZxDxL2/s+1rMJPO/JPj6nhMQ8SmYAP4BeBjwV/z8+IvHDPOvDAj8//AI87wdBPhr1wjxdBgU/KB//OxroQT6fpsE8my0HPxI2+Dswo0I+hhvAPMs5CT9FQvE7uzxDPv5ovjw0Kws/uEjqOya4Qz4vo7w8OwINP0BO4zu6GEQ+7dy6PGC/Dj+JV9w7kWFEPn0nuTw5YxA/BmnVO5eVRD50krc8bu4RP/CGzjuBt0Q+liu2PLdhEz85tcc70clEPtT+tDzVvRQ/jvfAO9PORD5MFrQ8lQMWP09RujufyEQ+UXqzPMkzFz+PxbM7GLlEPoMxszxHTxg/EFetO/KhRD7sQLM86FYZP0kIpzuxhEQ+HayzPINLGj9g26A7sGJEPlB1tDzxLRs/MtKaOx49RD6RnbU8CP8bP1HulDsGFUQ+4yS3PJi/HD8KMY87UutDPmYKuTxwcB0/aJuJO8rAQz5+TLs8WRIePzYuhDsalkM+8+i9PBamHj8L1H071mtDPhPdwDxkLB8/Y55zO3lCQz7QJcQ8tv5QPvP3Ozw4+M49H8DFOxl9XT485zo80vDZPRpV5TtTOGo+msA5PLzZ5D1YzgM88yt3PlKDODy7p+89GScWPGcpgj6qLjc8j0/6Pd2CKTy904g+6ME1PARjAj76oj0825CPPk88NDwSgAc+6j9SPG9dlj4RnTI8inkMPpsLZzwHNJ0+Y+MwPEVKET5+tHs8khGkPmMOLzxK7RU+XvSHPDfuqj5fHS08LF4aPoCukTyuxbE+nA8rPNWYHj5H55o8n5K4Po/kKDzMmSI+CIGjPGxPvz7kmyY8Ql4mPgJjqzz89sU+hTUkPB3kKT43erI8TYTMPqWxITwBKi0+ELm4PDry0j7MEB88YS8wPpwXvjyoPNk+yVMcPGD0Mj74k8I8pV/fPrx7GTzYeTU+3jDGPLVX5T4PihY8RsE3Ppv1yDzSIes+boATPLnMOT6C7co8b7vwPsJgEDy4njs+VSfMPHgi9j4jLQ08LTo9Ppy0zDxKVfs+1ucJPE2iPj4Bqcw8WikAPzuTBjyD2j8+rRnMPPWMAj/JMQM8WuZAPqYcyzxB1QQ/B4z/O2nJQT5CyMk8NQIHP+Kk+DtGh0I+ozLIPPETCT8ps/E7dSNDPkZxxjy1Cgs/zLvqO2ChQz6omMQ84uYMP5jD4ztJBEQ++rvCPPSoDj8uz9w7Sk9EPufswDx9URA/+OLVO0mFRD5tO788I+ERPyMDzzv9qEQ+wLW9PJpYEz+YM8g75LxEPkNovDyjuBQ/+HfBO0vDRD6GXbs8CQIWP5rTujtJvkQ+T566PJ01Fz+GSbQ7w69EPq0xujw1VBg/edytO26ZRD4RHbo8q14ZP+GOpzvRfEQ+cWS6PNdVGj/gYqE7RVtEPmMKuzySOhs/TVqbOwA2RD5EELw8tQ0cP7h2lTsNDkQ+Xna9PBLQHD9tuY87WuRDPhA8vzx7gh0/dSOKO7K5Qz7vX8E8uiUeP5u1hDvDjkM+69/DPJW6Hj/k4H47JWRDPm65xjzOQR8/sKh0O1U6Qz5/6ck8/xxPPuoOPDw2Uc49+tPQO3GEWz51Ajs8w0fZPXdj8TtzK2g+D+A5PE8v5D0RYgo8PQt1PtemODyS/O490FkdPJARgT71VTc8LqT5PRxpMTxftoc+m+w1PHYNAj4mTkY8Zm6OPg5qNDzyKgc+dr1bPGM3lT56zTI8IiUMPq9ocTyBDZw+DxYxPNX2ED4hfYM8wOqiPg1DLzwymxU+qw2OPDnLqT6oUy08pg0aPtc9mDyqqLA+QUcrPCxKHj6v56E8bn23PlYdKTxFTSI+I+mqPLtCvj6n1SY8LBQmPqUpszzf88Q+HHAkPLScKT4glro8x4vLPu/sITx55Sw+oSDBPGoF0j6oTB883e0vPm3Bxjw5XNg+IJAcPP61Mj4ndss8GozePn64GTyvPjU+i0HPPDiR5D42xxY8a4k3PhEs0jyaaOo++b0TPDWYOT6lQdQ8mQ/wPrWeEDyNbTs+kpHVPAaE9T6Jaw08Vww9Pt0t1jwsxPo+vSYKPMR3Pj6hKtY8x87/PrbSBjw3sz8+aZ3VPH1RAj/rcQM8NcJAPpyc1DwmoAQ/4QYAPFOoQT7pPtM8UNMGPzso+TsfaUI+zZrRPBLrCD9DOPI7GghDPiHGzzyp5wo/w0LrO6eIQz7G1c08cckMP4FM5DsH7kM+UN3LPOCQDj8TWt07TztEPtjuyTyGPhA/2m/WO2NzRD7PGsg8BNMRP/aRzzv3mEQ+4m/GPA1PEz9IxMg7iq5EPvD6xDxfsxQ/ZArCO2e2RD4Gx8M8xAAWP5dnuzunskQ+Z93CPA04Fz/i3rQ7LaVEPp1FwjwQWhg/93KuO7GPRD6RBcI8pWcZPz8mqDu7c0Q+pSHCPKhhGj/V+qE7qVJEPtacwjzySBs/jPKbO7AtRD7ieMM8XR4cP/IOljvgBUQ+aLbEPL/iHD9PUZA7KdxDPgxVxjzqlh0/q7qKO1mxQz6hU8g8rTseP9RLhTsjhkM+R7DKPNHRHj9dBYA7IFtDPo5ozTwaWh8/Sc91O9EwQz6VedA8QQxNPhApPDwtmM09N0nfO9tdWT6lITs8xozYPbKDADyE7mU+agQ6PFdz4z1X1hI8zbpyPljQODx2QO49oX4mPJvBfz5thDc8rej4PRNNOzxrfIY+wR82PGCwAT6OBlE8fS6NPm6hNDzJzgY+VWJnPI31kz6OCDM8HMoLPjsIfjwSzJo+UlQxPDGdED5QT4o8yK2hPvODLzweQxU+Fl+VPLyQqD7ili08jLcZPtgMoDxzc68+YowrPEj2HT47Mao8aU62Pg5kKTzl+yE+fKmzPJ0dvT6QHSc8b8UlPmpYvDzd28M+2rgkPK1QKT4UJsQ8Zn/KPm02IjyBnCw+JQTLPHMF0T65lh88HagvPkrt0DyGadc+n9ocPJNzMj6K39U8M6fdPk8DGjyu/zQ+ed7ZPK264z5DEhc83k03Ph/y3DyqoOk+NwkUPCRgOT58Jt88K1bvPijqEDwBOTs+W4zgPBzZ9D43tw08TNs8Pm824TyyJ/o+sXIKPC9KPj5jOeE8lED/Pv8eBzwJiT8+RqvgPGsRAj+dvgM8WZtAPvWi3zz3ZgQ/DlQAPKyEQT6NN9482aAGP7LD+TuNSEI+9n/cPCG/CD/71PI7dupCPniS2jwHwgo/2eDrO8htQz5dhNg84akMPwvs5Du91UM+sWnWPCF3Dj8d+907ZyVEPgBV1DxUKhA/ZRLXO6pfRD42V9I8FsQRP/s10Ds2h0Q+gn/QPBdFEz+yack7iZ5EPknbzjwWrhQ/FrHCO+2nRD4fds082P8VP2gPvDt7pUQ+0FnMPDA7Fz+fh7U7GZlEPmuOyzzxYBg/ZxyvO36ERD5dGss89nEZPx/QqDs1aUQ+hQLLPBpvGj/fpKI7nkhEPlRKyzw6WRs/dJycO/EjRD7w88s8LjEcP2e4ljtC/EM+WgDNPNH3HD8A+pA7gtJDPo1vzjz3rR0/R2KLO4OnQz6gQNA8clQePwfyhTv9e0M+8HHSPA3sHj/WqYA7i1BDPjsB1TyOdR8/LRR3O7ElQz7A69c8MLdKPj9JPDyizcw9QaHxO/j0Vj55Rzs8DMDXPZtyCjzYb2M+ODA6PLKl4j2vjR08xydwPksCOTwNc+09pAgyPOsifT55vDc8ahz4PWm3Rzw1KoU+ml02PC9LAT6rWl48N9eLPrXkNDzwagY+26d1PP2Ykj7MUDM892cLPpWohjx0bpk+5KAxPPU8ED7meZI8X02gPlnULzwt5RQ+ehuePI02pz5H6i084FsZPtNaqTzRJq4+9+ErPNKcHT6ACLQ8rwm1PqK7KTwwpSE+L/y9PKPiuz6sdic8qnElPmofxzxxqcI+QBMlPDcAKT5VWc88xVrJPo+RIjw9Tyw+A5rWPNnxzz4p8h889l0vPjvV3DxPZNY+XTYdPOosMj74COI8xLDcPjRfGjydvDQ+Yj3mPJHT4j4tbhc8cA43PmJ76Twgyeg+E2UUPF8kOT4w0Os8xo7uPuBFETzYADs+90vtPGQh9D7XEg48y6Y8PpoB7jyOf/k+QM4KPEsZPj6KB+4816f+Pop6BzyyWz8+eXTtPKDMAT80GgQ8eXFAPtNf7DyZKQQ/xK8APCZeQT494eo8uWoGP4N7+js/JUI+HRDpPAqQCD9UjfM7OcpCPjID5zy+mQo/2pnsO29QQz5E0OQ8JYgMP8yl5TsYu0M+2oviPK9bDj+ttd47Qg1EPgJJ4DziFBA/y83XO81JRD4wGd48WLQRPzHy0Dtnc0Q+GgzcPL46Ez+oJso7jYxEPrEv2jzQqBQ/sW7DO4qXRD4ckNg8VP8VP4TNvDt1lkQ+uTfXPBg/Fz8ORrY7NotEPisv1jzyaBg/8dqvO4Z3RD5rfdU8vH0ZP4eOqTvxXEQ+4SfVPFN+Gj/fYqM72DxEPoIy1TyTaxs/xFmdO3kYRD7tn9U8WEYcP7p0lzvo8EM+i3HWPH4PHT8HtZE7HMdDPrqn1zzcxx0/sRuMO+mbQz7oQdk8R3AeP4WphjsLcEM+tT7bPI0JHz8aX4E7H0RDPhec3Tx4lB8/p3l4O7AYQz54V+A8ziVIPn1zPDxh8ss9ITMEPG5JVD7Edzs8FeLWPdfJFjx2rmA+LGc6PJPG4T3s2Co8kFhtPklAOTwrlOw9CkdAPPo5ej6rATg8Nz/3Pb7rVjwIqoM+9Kk2PAPeAD7TlG48wlWKPsA3NTx6/wU+6X+DPH8TkT4SqjM8p/4KPqvnjzzi7Zc+h/8xPOPVDz7UUZw8o9aePno3MDxugBQ+mIGoPKzEpT5WUS483/kYPgJStDw1sqw+oUwsPDM+HT5Fkr88e6GzPqEoKjyBSSE+/hvKPJGPuj735Cc8mxglPp/G0zyfYsE+24IlPIGqKD4Ibtw8myHIPv0BIzz+/Cs+zBHkPPnDzj5DYyA8lw8vPj+m6jyUR9U+eKcdPBTiMT7WKPA8cajbPtLPGjwVdTQ+Mpj0PM7b4T553hc8rco2PjAA+Dz04ec+8dQUPHDkOD5Dc/o8O7jtPkC1ETzBxDo+kgL8PPVb8z6jgQ48dm48PlvC/Dxqy/g+cTwLPKTkPT7Vx/w8QAT+PjroBzy8Kj8+pir8PPmCAT9xhwQ8HURAPsUD+zzr5wM/oRwBPEk0QT51a/k80jAGP6RU+zu9/kE+rHn3PLNdCD8CZvQ76qZCPrNF9Ty4bgo/N3LtOyUwQz7X5fI8LWQMP/V95juhnUM+Jm/wPHw+Dj+3jd87aPJDPjv17Twn/g8/waXYO1YxRD4Uius8xqMRPxXK0TsYXUQ+/T3pPAIwEz9v/so7KXhEPn0f5zyUoxQ/R0bEO9KERD5SO+U8Qf8VP8qkvTsrhUQ+dJzjPNdDFz/cHLc7HntEPiRM4jwqchg/F7GwO2NoRD71UeE8FYsZP8tjqjuJTkQ+5rPgPHSPGj8DN6Q79i5EPnh24DwngBs/hCyeO+cKRD7QnOA8C14cP85FmDt240M+1SjhPP0pHT8lhJI7nLlDPkwb4jzX5B0/juiMOzKOQz4HdOM8cY8eP9Zzhzv1YUM++DHlPJ0qHz+VJoI7iTVDPllT5zwntx8/XQJ6O3sJQz7I1ek8uTdFPv+rPDzUBss9jfgRPBw6UT4Jtzs8XPPVPczEJTy6jF0+8606PGfW4D2WCDs8vB5qPhqPOTxMpOs9mqRRPEDrdj7aWDg8NFH2PeZ3aTw8A4I+Zgk3PHloAD6bJ4E8q6+IPiqfNTzviwU+Ke2NPF5yjz7PGDQ8bY0KPiDnmjzyQpY+UXUyPL9nDz6c56c8by2dPimzMDxhFRQ+HsW0PA4epD4R0i48K5IYPsFBwTxBKas+U9AsPNvYHD4THM08lR2yPpmvKjzS5yA+1THYPJUQuT6Ebig847okPr1i4jwx9r8+jA0mPBxQKD6ol+s8qdHGPoqMIzxHpSs+ibHzPPCDzT4S7iA8nLsuPhCb+jxdGNQ+EzIePOaRMT59MwA9dobaPj1aGzwzKTQ+4YsCPR7Q4D6qZxg8OoI2Pk1aBD0g6+Y+21wVPJWfOD6+ogU9VdPsPhI8Ejzbgzo++nEGPSaJ8j5JBw88fTE8Pg/UBj0ECvg+98ALPKKrPT5D1AY9KVX9PoJrCDx59T4+i34GPUw0AT+SCQU8jRJAPrreBT3HoQM/uJ0BPFwGQT70AQU9AvMFP+VU/DtS1EE+tvQDPfwnCD+DZPU7139CPvDCAj3YQAo/IG/uOzwMQz4SeAE93z0MP2p55zuvfEM+6B4APXMfDj/Vh+A7NNRDPhKD/TwU5g8/m57ZO6YVRD5+0vo8VZIRP7TB0jutQ0Q++Tz4PN0kEz/U9Ms7xGBEPqbR9TxjnhQ/ZzvFOzJvRD7mnfM8qP8VP4+YvjsQcUQ+Va3xPHlJFz8mD7g7RmhEPtIJ8DysfBg/v6GxO5FWRD6Yu+48GpoZP6FSqzuAPUQ+RMntPKCiGj/RI6U7fB5EPvQ37Twflxs/DRefO8X6Qz5gC+08dngcP9QtmTt400M+9UXtPIRHHT9laZM7kqlDPvfo7TwlBR4/xMqNO/B9Qz6g9O48NbIeP75SiDtSUUM+RGjwPIhPHz/qAYM7YSRDPm1C8jzu3R8/YbF7O633Qj75gPQ8qfZBPrf3PDyeCso9BIoiPA/gTT7DCjw8q/PUPUnFNzzpCVo+YAo7PCHV3z1sbE48nYpmPsj0OTwqo+o9CWBmPANUcz4UyDg8yFH1PbJ8fzwHJ4A+doI3PC7V/z2Ux4w8UcGGPgAiNjyrEAU+hTSaPMaDjT6WpDQ8BxUKPvDgpzzWaJQ+lQgzPAnyDj6El7U8BmKbPg9NMTy8ohM+cxTDPGZeoj6hcS883iIYPlYp0DxEWqk+v3UtPFZuHD72sNw8O2SwPg5YKzydgCA+63voPBiBtz6xFyk81lUkPpZE8zxddb4+NbgmPNruJz6U8vw8dFLFPuE4JDwASSs+H78CPc4czD7XmSE8xGIuPqdwBj1s1NI+vNsePH47MT6TgQk9LlXZPskCHDzF1jM+3/QLPXmv3z72Dhk8GDQ2Pt/YDT3A3eU+aAIWPIhVOD6mNA89OtzrPmHfEjyEPTo+ZA8QPWGo8T46qA880O47PoRwED1oPPc+3F8MPP1sPT5PahA9J5r8PmkICTzbuj4+ZAkQPRfgAD98pAU82ds/PnNaDz0EVwM/nzYCPFrTQD7gaQ49IrEFPxOD/Tv9pEE+9EMNPb/uBz9Bj/Y7B1RCPtn1Cz38Dwo/oZbvO8PjQj5Liwo9GxUMP9ud6DtYV0M+Yg8JPXn+DT9fqeE7xrFDPn+MBz2RzA8/Xb3aO+T1Qz42DAY99H8RP8Xd0ztXJkQ+SZcEPUMZEz9ADs07l0VEPps1Az00mRQ/MFLGO+pVRD4u7gE9hgAWP6ysvztqWUQ+J8cAPQZQFz+GILk7/1FEPpiL/zyGiBg/RLCyO2dBRD4Z3f084KoZPyperDs0KUQ+Gor8PPO3Gj8zLKY7zwpEPmGY+zyfsBs/GBygO33nQz5EDPs8xZUcP1MvmjtfwEM+xOj6PEdoHT8hZ5Q7dZZDPrEv+zwEKR4/g8SOO59qQz7B4fs819geP0ZIiTujPUM+sf78PJt4Hz8B84M7LBBDPmiF/jwiCSA/PIp9O8/iQj4LOgA9vGQ+PndcPTzM/Mg94TQ2PJcXSj53eTw8cOLTPfMNTTw8HFY+loM7PEDC3j1fS2U8w25iPgx5OjyckOk9e8t+PJwKbz7RVzk8gEH0PWu1jDxcEnw+TR04PDPI/j1IeJo86puEPgbINjy+jAQ+TJeoPIZxiz5kVDU8u5MJPuXmtjzjUJI+GcIzPGR0Dj6qN8U8CDWZPvYPMjy0KRM+hWjTPKRIoD6/OjA8Sq0XPuJL4TzPf6c+qEEuPJ/6Gz7pkO48e5muPrgnLDynECA+S+j6PL2gtT5C7Ck8AewjPiIpAz2hs7w+N40nPEqIJz6RWAg9GcjDPlcLJTzO4yo+wdwMPYCmyj6SayI8dwEuPoy7ED1RXtE+0K0fPAzgMD6W+xM95AXYPhnRHDyufTM+aJ0WPQN/3j7K2Rk8Dt41PvmVGD0tv+Q+y8oWPPsDOD6v/Bk9LdLqPtCkEzw18Dk+sN0aPaOy8D6QahA8xqU7Pl9EGz2/YfY+Ih4NPDonPT4nOBs9jNP7PofDCTxFeT4+0McaPYCGAD+MXAY8a54/PuUEGj3pBgM/uesCPAGaQD42/Bg9pGoFP1jn/jt7b0E+uroXPdKxBz+z7fc7JCJCPh1MFj362wk/wO/wO3C1Qj4evRQ9uekLP+Tx6TtgLEM+iBkTPWjbDT+J+OI78IlDPgVsET19sQ8/2QfcO+/QQz55vg89hWwRP7sj1TsCBEQ+7xkOPR0NEz/OT847myVEPp6GDD34kxQ/aI/HOwI4RD7cCws91AEWP5jlwDtOPUQ+JLAJPXpXFz8kVbo7aDdEPhV5CD29lRg/i+CzOw8oRD56awc9dr0ZPwWKrTvXEEQ+T4sGPYPPGj+IU6c7LPNDPsvbBT3GzBs/yD6hO1fQQz5wXwU9IbYcPzhNmzt6qUM+EhgFPXiMHT8RgJU7m39DPuEGBT2rUB4/VNiPO51TQz6ALAU9mgMfP8pWijtLJkM+C4kFPSKmHz8L/IQ7VfhCPiscBj0XOSA/BJF/O1PKQj4j5QY9hEE6PjTiPTxR3Mc9l25NPGfFRT6sCz08mb7SPRUfZjwTqVE+niI8PMOc3T16FIA8HNddPlIlOzxXa+g9ta+NPKtqaj5EETo8Bx7zPZvLmzwoUnc+HeQ4PImo/T3oS6o8E1GCPuCaNzz+/gM+VRK5PJL/iD6MNDY84QkJPtwFyDzU648+u6w0POntDT7+E9c8pNCWPoAEMzxPpxI+XvblPD4Inj6mNTE8FC4XPu139DziKaU+lkQvPCKBGz44LAE9JWWsPrYtLTygmh8+dckHPUq/sz4a8Co8fXYjPv7fDT1x4ro+OJIoPPcWJz7GSBM9+eHBPlATJjyceSo+KBsYPc79yD5xbiM8YJgtPppIHD1T488+DKwgPAR5MD7vrR89q5fWPhzNHTy/GzM+dGsiPTck3T5W0ho8u4A1PjqLJD2jlOM+GrwXPAOoNz5qDCY9x7rpPhiSFDztmDk+uOwmPeSw7z5RUxE861I7PshOJz1scvU+rgIOPEDZPD7BPSc98/z6PvOiCjw4Lz4+ncMmPa0nAD/QNgc8Ilg/PnDpJT0lsgI/oMEDPBJYQD4bxCQ93B8FP0xFADy+MUE+BGIjPZhwBz/PiPk7g+hBPsjPIT2fpAk/oILyO4p/Qj4xGSA9h7sLPyl96zsk+kI+XEkePRG2DT+BfOQ7IltDPn1sHD2rlA8/zITdO02lQz6+jBo931cRP+WZ1jtG20M+fLMYPUcAEz9kv887fv9DPjrpFj2SjhQ/lPjIOzcURD6hNRU9eQMWP3pIwjuKG0Q+g58TPcZfFz/Rsbs7YBdEPtssEj1KpBg/Dje1O3cJRD7O4hA93NEZP2Harjto80M+tsUPPVvpGj+4nag7oNZDPifZDj2o6xs/voKiO2q0Qz75Hw49qNkcP+OKnDvujUM+WJwNPT60HT9ct5Y7NGRDPshPDT1OfB4/IwmROyY4Qz44Ow09ujIfPwOBizuQCkM+CV8NPWLYHz+SH4Y7KNxCPiS7DT0fbiA/OeWAO4utQj4ATw49PLE1Ph+TPjyJp8Y9u5JoPPb1QD44zD08aIbRPRifgTzTm0w+KvM8PPli3D3OmI884rNYPqgFPDyEMec9BxyePB4uZT5nATs88+XxPc0MrTyG/nE+0OM5POVz/D1ITLw88wZ/Po6qODyeZwM+VM3LPFxKhj4dUTc8GHUIPnJ02zyhPo0+bNU1PI1cDT71Ges8rFWUPpU1NDx3GBI+D4b6PPxUmz5VczI8n6UWPgDPBD34l6I+jocwPDz8Gj6pIgw94gWqPnpyLjyAGB8+3BATPRFKsT5KOiw8F/siPsxvGT1DnLg+kNopPIOeJj44UR89FgfAPqpSJzyS/yk+znYkPc4exz6brSQ8tSQtPunPKD3SGs4+WuchPNcJMD5ghCw96xzVPpz9HjziqzI+IHovPfy12z7F/hs8ZBY1PnCpMT0ZL+I+geQYPABENz53OTM9d3joPsayFTw8ODk+Pjc0PYig7j7jaRI8kPM6PlKYND0LdfQ+XxMPPCJ/PD46eDQ9nxX6PkitCzzv2T0+Bu0zPa59/z7ZOgg8qwc/Pu8DMz09WAI/EL4EPAoLQD7DxDE9btAEP8Q7ATxT6UA+QD4wPTwrBz9Wavs7n6RBPu+DLj0IaQk/MVn0OwZAQj7noSw92okLP9tI7TujvkI+BaQqPTWODT+QPeY7VCNDPmGUKD3fdQ8/9zvfOxNxQz5TfiY9ykERP4lH2DtVqkM+/2skPYzyEj/RY9E7idFDPjZmIj3RiBQ/EpTKO+/oQz7ydCA9TwUWP0Tbwzuc8kM+Wp8ePctoFz8aPL07e/BDPsHrHD0WtBg//Li2O0vkQz6sXxs9BegZPxNUsDulz0M+0/8ZPXYFGz9BD6o7+7NDPivQGD1MDRw/LOyjO5qSQz7r0xc9agAdPz3snTuubEM+mQ0XPbXfHT+iEJg7Q0NDPhN/Fj0UrB4/VFqSO0gXQz6dKRY9amYfPxjKjDuO6UI+5w0WPZkPID+DYIc7z7pCPh8sFj1/qCA//h2CO6yLQj7+gxY9+2UwPmN9PzyXXMU9DO+DPJhnOz7eyT48vTfQPUhVkjzS5EY+HQQ+PDgS2z22UKE87uRSPpUpPTxI4OU9NMOwPAUmXz6zODw8O5bwPf2KwDzOyGs+5C07PFQn+z2pldA8dSB5PtADOjzAwgI+08TgPO9Lgz6Lujg8ENMHPq778DwZRIo+rEw3PK+9DD66jgA9qC2RPhq8NTy6fhE+OIkIPZNkmD6IADQ8YQ4WPrFkED3g4J8+JRgyPGlnGj7x9hc9+SanPuYLMDyZih4+ZyAfPRGYrj440y08ZnAiPgTrJT2XM7Y+3W0rPFQVJj6dGSw9en69PqPoKDzdfik+a40xPUPSxD5qOyY8PaYsPuVjNj37Psw+n2UjPOmILz5tSjo9VzDTPt95IDyoMzI+HGs9PbUH2j7abh08a580PuHkPz0L0OA+MkUaPBjMNj4mh0E91DLnPswKFzwlxTg+4IVCPXJi7T5vuxM8tYc6PoH5Qj2zcPM+zlYQPAcUPD7b40I96CT5PqjoDDyRdD0+2kBCPZaj/j67bQk8oKc+Pms+QT189AE/QOkFPNywPz4u6D891XkEPxVeAjyuk0A+cUc+Pd7hBj9ynf07QlNBPtpjPD33KQk/bn32O5nzQT6qUzo9+1QLP7Je7zvldkI+SyQ4PQ5jDT+qReg7EuBCPs7gNT3KVA8/SjbhO8wxQz4pkzM9+CkRPwM12jvhbkM+wUQxPaPjEj/qRNM7lJlDPh4ALz1xghQ/NGnMOyG0Qz6JzSw9FQcWP9CkxTudwEM+fLQqPVJyFz9k+r478cBDPqK7KD3zxBg/Tmy4O962Qz7a6CY9zf8ZP6v8sTv/o0M+QUElPb0jGz9Vras7xolDPi7JIz2jMRw/6H+lO4dpQz4+hCI9ZSodP8Z1nztwREM+WHUhPegOHj8WkJk7kRtDPrqeID0T4B4/zc+TO9/vQj4CAiA9zJ4fP6s1jjsxwkI+OaAfPfdLID9Cwog7RJNCPt95Hz116CA/+HWDO8FjQj7yjh893V4qPqGyQDxr+MM9VcKVPJ0oNT6mFkA8+87OPWpApTztWEA+9mg/PK+m2T3gQLU88jFMPnulPjxzc+Q9+JrFPD1LWD5Xyz08rSnvPfE11jx0KmU+ydM8PG+7+T2t8uY8CRZyPv+/OzzxDgI+sbD3PEy3fz5Thzo88iAHPno2BD2JuYY+HSs5PNgODD4/fQw9+/uNPqOhNzyy0BA+Y7EUPfkolT6z8TU8SGQVPmG0HD30kJw+7xI0PG3CGT5ScSQ9swakPscHMjxV6B0+Yu8rPQrKqz5RyS88Ts8hPtz0Mj3+LbM+3GktPEV9JT4+YTk9lri6Pq3bKjww6Sg+zUs/PY+Ywj7uGSg8SA0sPilbRD1838k+m0IlPA/6Lj7Nt0g9CmfRPuM8Ijz1njE+EDtMPQRU2D7nJx88KRA0PrfDTj1JFd8+SvcbPNBFNj4arFA989rlPkKmGDw0PDg+yNdRPSwi7D6DSxU8kgQ6PoVFUj0tKfI+fOARPPyaOz65LFI9QgX4PjBkDjyC/zw+X55RPaC9/T7t1wo87TM+PpWJUD3kigE/XUkHPNlDPz6GFE89iRsEP5yzAzyyLEA+olRNPaKOBj8MGgA8OPJAPp5WSz2w5gg/Ffz4O7WWQT5AH0k9YhwLP2DK8Tt4H0I+zL1GPaw0DT9Tn+o7541CPv5ERD1JMA8/uH7jO5vkQj73vkE9hw8RP2Vs3DspJkM+wzU/PSbTEj+pa9U76VRDPk+xPD0RexQ/Y4DOO0ZzQz6WOzo9cggWP/qsxzswg0M+y9w3PQZ8Fz8H9MA7jYZDPvGbNT2W1hg/31e6OyF/Qz5GfzM98xgaP5DaszuGbkM+RYwxPfhDGz/sfa07NVZDPqzHLz2FWBw/hEOnO4E3Qz6CNS49fVcdP68soTugE0M+GdksPcZBHj+QOps7putCPha1Kz1JGB8/EW6VO4vAQj56yyo97NsfP+/Hjzsuk0I+rh0qPZWNID+4SIo7UmRCPo2sKT0oLiE/zfCEO6Q0Qj5seCk9Y4YjPp9JQjzCdsI99LupPHwILj6KykE8UkfNPUNNujyBJTk+iDhBPFca2D1zQ8s8fp1EPgSSQDxY5OI9i3XcPNi4UD530T88kJjtPVrG7TzaXF0+kPM+PE0q+D26Ef88WTBqPjT3PTzYRgE++iUIPbEOeD4T0Dw8VFkGPqWsED2n8YI+bYQ7PHVICz7uGRk94hKKPiIMOjx1DRA+12AhPayQkT4OYDg8gqEUPm6AKT033Jg+H4w2PBgEGT50bDE9vKGgPvR8NDwRKx0+BQc5PeRIqD6PQjI8bhghPocxQD2U8K8+ptkvPFzIJD5g/0Y9sRG4Ps0zLTxZMSg+2BdNPS6zvz4Icio8nGArPueXUj3Sdcc+coEnPHhLLj59Ulc9d7rOPht7JDyP/jA+4xZbPfv41T67TyE8RnEzPvE3Xj0Ub90+ZvgdPNmdNT4UR2A9LPjjPtWlGjxfpDc+AZdhPQGp6j4/Lhc8WWo5PudRYj2E8vA+Ca0TPHgCOz7HOWI9guj2PpIhEDzFbTw+BKFhPeCk/D5Jigw8KKw9PuGdYD18HwE/J+UIPE+9Pj7DKl89uLkDP6FCBTzTrT8+UEpdPUU4Bj/jmwE8U3pAPvQqWz1wmQg/N+j7O00mQT7i1lg93dwKP8+b9DvVtEE+1VRWPe4CDT+uVu07pShCPoOpUz3+CA8/0h/mO02FQj667FA9lvIQPwD43jtizEI+QylOPQnAEj/U4tc7TwBDPkloSz0rchQ/L+PQOzwjQz6ksUg94ggWP8D8yTtpN0M+QQ1GPW2FFz9vMcM7lz5DPu+DQz2N6Bg/joO8O4o6Qz5HHEE9EDMaPx71tTvgLEM+Kdw+Pc5lGz/kh687ExdDPrzIPD2jgRw/Zz2pO336Qj5y5jo9cYcdP/MWoztW2EI+Dzk5PR94Hj+gFZ07uLFCPqjDNz2UVB8/UjqXO6KHQj6viDY9uB0gP72FkTv4WkI+94k1PXLUID9o+Is7gyxCPr/IND2neSE/sJKGO/n8QT66RTQ9ULkbPrxfRDyw0cA9TbO/PPncJT4wBEQ85ZnLPddB0TzcqTA+/JRDPO1l1j0lDuM8UyI8PgIOQzzSKeE9r+70PJwXSD6ObEI8VdnrPctiAz2SplQ+FqtBPHdn9j3eOAw9ga5hPg3GQDy8YwA+YPYUPX5Sbz4htz88/XUFPvqLHT13lH0+KXk+PA9kCj6n+yU9cOGFPiARPTzgKQ8+GEouPapPjT6VcTs8/b8TPgZnNj3G+5Q+Dpo5PNIhGD6OUT49WtucPrOJNzwESxw+iv9FPX/OpD7SQzU89zggPi9jTT3srKw+ys4yPAXrIz7US1Q9nTa0PtQ1MDwuYyc+5aZaPeh1vD4hUi08GpAqPsCDYD3LNcQ+YFUqPNSDLT6PeGU9WM3LPio0JzxuOTA+I95pPTnJ0z6Y2iM8PaUyPi86bT1eA9s+BHwgPBHiND4p4289/1niPm72HDya3TY+hZNxPafs6D7RdBk827E4Prpbcj0bT+8+xt8VPHZSOj61oHI9Rbv1PgQvEjysujs+hytyPZCR+z7ehA48SQE9PnUhcT1kjQA/ONYKPLcgPj5ktm89p0cDP5cZBzw/FD8+Ne9tPVbcBT+WXQM8P+Y/Pgq4az3jSAg/3Ev/O4SaQD6qRWk9hZUKP83i9zuiMUE+z6RmPeDGDD8pgPA7F61BPqzgYz3E3Q4/VCfpO18PQj5Q+WA9NtIQP4rk4TtBXUI+nABePUSqEj99tdo7hJdCPpsGWz08ZhQ/h53TO2bAQj6QE1g9cwcWP6WezDvJ2UI+bS9VPd2NFz8qvMU7wOVCPpJgUj01+hg/WPi+OwfmQj60r089jE0aP71UuDsx3EI+bSNNPbGIGz8a07E7uslCPlTBSj1+rBw/6nSrOwKwQj5Mjkg907kdP207pTtFkEI+jo5GPZSxHj+vJ587pWtCPqrFRD2mlB8/ijqZOyZDQj6ONkM982MgP6d0kzuyF0I+guNBPWEgIT+G1o07HOpBPjvOQD3XyiE/e2CIOyC7QT7Y9z89juESPuoZRzwgAb89eE7XPJvBHD4U6EY8K73JPT6o6TyTVic+S6FGPBV+1D3cEPw8tqgyPl5ARjzRN989FTAHPVhfPj4XxEU8T97pPXk7ED1H/Uo+WCFFPABk9D3EHRk9HAlYPkBYRDy4vP49FtUhPejIZT7WX0M8fG0EPoVUKj1w+nM+TzZCPJNZCT7hpDI9aX2BPuXQQDzIGw4+p9Y6Pe7oiD7JOz88cbESPsjTQj3JSpA+93M9PF4WFz5SrEo9iU+YPlZeOzzQQBs+z09SPVJPoD5UEjk8UTIfPrKwWT3ge6g+s4g2POblIj76umA916awPhPKMzxaWyY+ZWFnPSnmuD4/1TA86o8pPi1mbT2stMA+s8MtPDCLLD5x7nI9JSHJPrNoKjyeOi8+4pR3PQi/0D71CCc8JrkxPiWTez2Bztg+0WwjPC7uMz5dsH49aIjfPk3vHzyxBTY+/WqAPWhK5z6dHBw8wMY3PnkrgT29y+0+um0YPFVwOT6mVoE9uhX0Pu6vFDwe6jo+cEeBPTlt+j531xA8Iy48PuzrgD0uBwA/lhINPMlXPT48N4A9OsQCP1NECTxCWD4+iKt+PU9jBT8BdAU8ETU/PtGdfD1p8gc/Q50BPDztPz6zL3o9s0oKP5Wr+zsWjkA+1Hd3Pa6HDD9lJPQ76hJBPk+adD2spw4/4arsO8x+QT7ln3E9gK0QPwBA5TuP00E+qYtuPa6QEj8F8d07thVCPothaz2OVxQ/dLrWO+hFQj6oOWg9IwMWP4aezzsVZkI+PhxlPd6TFz/kn8g7LXhCPuoQYj2wChk/aMDBO+t9Qj6+HV89kmcaP/QCuzsNeUI+w0lcPdurGz98aLQ7/GpCPmOcWT1e2Bw/c/KtOxtVQj4AG1c9+e0dP/ihpzuvOEI+UcpUPYztHj8TeKE73xZCPmiuUj351x8/k3WbO7fwQT63ylA9Ka4gPxWblTspx0E+DyJPPQNxIT8O6Y87EJtBPqa2TT1uISI/xl+KOzBtQT4dikw999kIPi6nSjx8+rw9TPHvPACSEj6RpUo8EaXHPWxkAT3c2Bw+OY9KPEZV0j3cugo9tA0oPvZZSjz+/tw9QeoTPX3LMz7UBEo8ApbnPdHjHD2QZkA+FIVJPEgN8j3roSU922tNPi/bSDzAWPw9qSEuPW00Wz6v+0c8mDUDPiNfNj1QcWk+teVGPK8cCD6zaj4956N4PkWKRTzQ2gw+ok9GPRP1gz7H9UM8tGwRPmsMTj3p8os+GhhCPOnLFT4zvFU9mPOTPjP+Pzyf9hk+hjtdPQRDnD7pmT085+YdPlOjZD0VdaQ+2/86PMmdIT7uums97N6sPrQhODyhFSU+o4dyPWiKtD6oMjU8tVkoPvfdeD12mr0+icgxPGdKKz6VsX49sRvFPnB/LjzlFC4+5u2BPRW4zT4Dzyo8howwPvwuhD25AtU+wD0nPF7gMj74+oU9NWvdPvtIIzxj3jQ+fHmHPaBk5D6Rgx88/cI2PvxgiD35wOs+GokbPONkOD7sDYk9hpXyPleTFzw73jk+RRyJPSKP+D4guBM8ST07PqXjiD32yP4+ergPPBRkPD78dIg9kEECP6rFCzwibD0+KKOHPZ7tBD8T2wc8LVU+Puukhj3Sewc/0/EDPDEdPz5qhYU9bPsJP0wEADz1wj8+B0CEPf9BDD9JV/g75FNAPhLLgj2sbQ4/LrPwO9bKQD4FR4E9zHkQP4El6TtfK0E+pWx/Pc5uEj8pqOE75XVBPtU3fD2gRBQ/K0jaO4GuQT4O7Xg9PvsVP9oI0zsz10E+S6J1PfaWFz8W6Ms7FPFBPk1kcj34Fxk/i+jEO/n9QT4FOm89uH8aPxULvjty/0E+rylsPTPOGz9LUrc7GfdBPso4aT09BB0/gb+wO07mQT5Fb2Y97yIeP3xTqjtYzkE+ndJjPSQrHz8vD6Q7Y7BBPnRnYT2/HSA/RvOdO4mNQT7NMV89o/sgP10AmDvDZkE+DTVdPbbFIT/bNpI78zxBPv9zWz3efCI/+JaMO+kQQT7V8Fk9CXj7PYY/TzyZsLo9+lQEPdcBBz4Fek88pkLFPQvJDT0dZxE+CZZPPLHazz1oBhc9rZwcPoqQTzy7bNo9RP8fPcs0KD7BaU88t+zkPWeoKD3G5jQ+jA5PPN1N7z3BBzE9sEZCPst+Tjzng/k97Bc5PYS/Tz69v008/cEBPm7gQD0XOF4+ubhMPHGgBj5jeEg9e4RtPmNmSzyqVws+eehPPS+sfD5y2kk8ueQPPuFHVz2qcYY+lPRHPFtAFD6doF49ynaOPpjRRTwXahg+NOllPXLalj7/WEM8ZlscPoUwbT2qJJ8+WKVAPFcVID5cS3Q9db2nPrehPTybkSM+gj17PaQesD5pbzo8Y9QmPrTtgD28qrg+yPs2PNDXKT4UBoQ9wH7BPmNDMzzqmCw+K+aGPSJ9yT4ajy881CkvPudeiT1jhNI+km8rPPZpMT6HpYs9ocHZPgaZJzwAkjM+Q1KNPUvG4T50biM8bG81Pi3Pjj0vJ+k+z04fPCwjNz4vpo89pwfwPgQzGzw3rjg+70CQPesT9z5J9RY8+gA6PodSkD1fGv0+NOUSPCVAOz7PBJA9/nYBPxDQDjzFVzw+y4qPPTBtBD/NpAo8L0E9Pi23jj1hCAc/G50GPOAXPj4kq409b3oJP+agAjyf0j4+936MPfrmCz9WPP07bms/Piw0iz0ILA4/IlX1O8vsPz5xuIk9VEQQPzqW7TslWkA+7SiIPXFCEj9E7eU7erFAPnCNhj2aJBQ/ql/eO2X1QD496oQ98u0VP5bs1jt6J0E+tj6DPVaVFz/dos87JktBPqyOgT3LIRk/IXzIOwVhQT4vyn89bZQaP4d5wTuwakE+04p8PbvtGz/YnLo7t2lBPgBmeT21Lh0//eazO41fQT6WYHY9YVcePzFarTt6TUE+WIFzPSJpHz989qY7tjRBPtHOcD3RZCA/iLygO18WQT6lTW49UEshP+Csmjt480A+4AFsPYIdIj/Fx5Q79cxAPu/uaT1J3CI/ag2PO66jQD6oF2g9AkLjPdEmVTxpFLg9fSAQPVmP9T3loVU8GIXCPaBPGT2v5wQ+ofxVPOT7zD3SKiI9mDEQPp8qVjw7bdc9FqIqPcTVGz5DM1Y8/MzhPeiyMj2tkSg+df9VPD0P7D2vcTo9Bfw1PtmPVTwbKPY9D9JBPU/AQz7a5FQ8PQYAPlvzSD1ACVM+4NlTPLHXBD7I6E895b9hPoqeUjxnhQk+vcBWPUFxcT4EBVE8HQkOPsOiXT0S7oA+gw9PPGteEj5LjGQ9bfCIPmrdTDywhBY+iZprPYqNkT7UPUo8DnQaPoqocj3lkZo+IDxHPOUpHj6r13k9fgejPvAaRDwMrCE+I2qAPW7Xqz7koUA8GPEkPpnfgz2CVrQ+3gI9PAz/Jz6AKIc9pwm9PoIfOTwgzyo+FUGKPXV+xT4QGzU8TWctPi8ijT0sCc4+IOUwPPPCLz4NoI89zavWPpd/LDy14TE+LPCRPdZi3j4iOSg8fdkzPv2ikz2RyOU+m+gjPOqhNT7PIpU9dcjtPkVUHzzWJjc+sQ+WPZ9s9D5/Bxs8Y5o4PgSylj14m/s+voAWPEvPOT481pY9RMAAP/tEEjzG+To+KYmWPcacAz+CBg48t/47PhMVlj1eiAY/c7IJPPPXPD5rVJU90AYJPxuUBTz7oz0++0qUPTh0Cz8ndwE8hFA+Pjsfkz1OxA0/usn6O6niPj7k2ZE9HggQP4Co8js6WT8+fGuQPVYQEj9zyuo76L8/PkPbjj3z/hM/PQfjO9cRQD5tQI09ENIVPztk2zt7UUA+Cp6LPX6JFz+u5NM7xoBAPkf0iT3rJRk/BYrMO3uhQD5/Qog9TqQaP0VbxTt2tUA+8pSGPU0JHD8XVL47371APtHwhD1kVR0//XW3Oy68QD5DWYM9UYkeP/jBsDu9sUA+B9GBPdulHz/VOKo7zp9APo5agD2eqyA/itujO3eHQD6B8309uJshPxKqnTvVaUA+GWJ7PQh3Ij+vpJc730dAPg8FeT1sPiM/e8uRO3wiQD7x33Y9quvIPeixXDwzFrU9FJYaPTQv2z23c108dlu/PaIqIz23Le895xFePLumyT10TSs9CiEDPutyXjyO7dM9JO4yPcW7Dj5vr148KiPePdweOj0c9hs+hZdePDk96D1I+kA9FWYpPi5HXjy/L/I9DWlHPYOCNz6iqV08L/D7PeSzTT1Nm0Y+8q1cPPK5Aj5r0FM948JVPlxpWzw7WQc+8flZPTnaZT7kulk88tALPvU3YD0ewnU+JsRXPLIeED70q2Y9S1SDPnFaVTwvPRQ+D1ptPXqRiz68sFI8dCwYPuJBdD32fpQ+z4VPPPzkGz6YWHs9H2qdPrEQTDxSaB8+lkiBPQlxpj4ETkg8c7MiPhfZhD235q8+DilEPKXBJT4ZZYg903a4PqYQQDxhoCg+xL+LPXNPwT5prjs850IrPjLwjj3O0Mk+hDg3PG6xLT4065E9bHLSPm+RMjzb5S8+yoSUPdR42j4t9S08su0xPk3ulj1Z3OI+OyApPN+4Mz6dxpg9lzfqPjuAJDxkZTU+3WWaPVFA8j6Ylh88b9A2PiV6mz15z/g+4wsbPMcuOD4POpw90vr/PhNCFjyBUDk+GIicPczgAj9j2BE8ums6PlVRnD0urwU/sm8NPL9jOz4O+Js9NpEIP6vwCDwnMjw+7l2bPRb/Cj9stAQ8XPU8PnNlmj0tXQ0//nsAPMqaPT44Tpk9gJ4PP9Ki+DtTJz4+sR2YPWfVET8lVPA76pk+PprLlj2CzhM/IFXoOzf9Pj5MR5U9pa4VP7d14DvLTD8+triTPW1wFz8vwNg7PYs/Prsfkj0aGhk/Cy7RO6q5Pz52gJA9r6waP+K/yTsB2j8+g9iOPUweHD/FhsI7H+4/PrIujT1+dh0/Y3m7OxX3Pz7OjIs9bbYeP+GXtDtL9j8+8fWJPZ/eHz9I4607DO0/PlxtiD0X8CA/rVunO6DcPz4z9YY95uohP8YCoTvjxT8+7pCFPXDQIj/G15o7/6k/PqZDhD2MoSM/rdqUO+qJPz6JD4M9Y+KsPTZBZjw1qLE9tt8iPRIuwD2aQmc8Tri7PaeFKj3mGNU9XRloPG/OxT0QjjE9liPqPUHQaDzM3s893Aw4PUM9AT7zL2k8auHZPVwcPj2O7Q4+ZC5pPMPK4z3yw0M9DtgbPu4LaTz7je09Sx9JPdxDKz6lUWg8hCP3PZljTj3SJTk+soVnPC5AAD5VjFM9aAtKPiz5ZTyrzQQ+uO5YPeOhWD6vcmQ8ATgJPl97Xj1YTGo+wxhiPKZ4DT5tbWQ9ST97Pt+CXzz3jhE+vbdqPdlThj5kgVw8YHcVPhxrcT3Tto4+XEdZPM4xGT7Ebng9AuCXPhR4VTzbthw+n8B/PRREoD6Mo1E88A0gPv6Zgz1uK6o+rQFNPMEkIz7JWIc9e9mzPiE3SDz4BSY+CxKLPUp3vD4Nl0M8g7soPhKZjj1/bMU+M6k+PFY3Kz6a+ZE9BfbNPrO3OTwhgy0+xSeVPQis1j47lTQ8cJcvPlb0lz2iYd4+FawvPN6IMT6Ik5o9hSPnPpVQKjwbNTM+7KOcPSx07j5EXCU8XMw0Po57nj3uhvY+RxcgPGkkNj5Xy589f3X8Pql7GzwkgDc+vLOgPd8OAj/GPxY8xok4Pr9MoT3D6gQ/FqIRPKWZOT4JQ6E9dYgHP7wlDTxjkDo+ZRShPTtcCj/HfQg8HFo7PrexoD0A5Aw/2QUEPOUQPD5j5J891DMPP61h/zsqszw+sPKePaZZET/G7fY70z89Pn7lnT0MgBM/9HXuO2iyPT45uJw9A34VPyw45jvhEj4+flWbPcRNFz8LP947H2M+Pu7dmT1rBRk/OGzWOzaiPj6DWpg97aIaP67Ezjsk0j4+LM+WPRomHD/ySsc7e/Q+Po47lT2ljx0/b/+/O84KPz46npM9dtweP1DpuDsDFj8+1gWSPW4RID8tArI7rRc/PoZ2kD0OLyE/0kqrOwYRPz5u8449GDYiP4PDpDs1Az8+Nn+NPVUnIz9fbJ47TO8+PjwcjD1mAyQ/xkWYOyHWPj6Jzoo9CQ+RPSovcjx6w609JUYoPYxkpD2ifHM85pO3PeOQLj27z7g9Sp90PD9qwT33NTQ9zNLOPXCDdTxHPcs922A5Pe4p6T1x63U8FAbVPQoJPj0iegE+4CJ2PPi03j3tV0I9bosPPrbpdTxmQ+g9H4xGPbUKHj6uVHU8WabxPT+OSj2gyC0+VjZ0PETW+j3A1049R8s8PuDgcjyu5AE+2zNTPVJUTT7f5nA8FT0GPlknWD0H7Fw+OLtuPBpxCj46dV097IxvPqmXazyAfA4+4m5jPZ1vgD6HVGg8cV4SPsXhaT0tV4k+D5xkPPYTFj5r3nA969ORPnK4YDxinRk+oUJ4PTItmz7bKlw8wPMcPuEAgD2dnKU+QuNWPJgRID60DYQ9hFeuPoUOUjyjByM+aPaHPQyetz4syUw8BMclPqXriz17RMA+xJRHPLhZKD4UuI890VHJPtYOQjyOtSo+1F2TPUTh0T7clzw8UeUsPhbWlj2tqdo+MPE2PFbgLj6F6Zk9bK3iPlJ9MTzZtjA+dNmcPZ4u6z4myys83FUyPugvnz2pdfI+EX4mPObdMz6kVqE95pP6PrXYIDxMKTU+FPOiPUoyAD8AAhw8IXs2PvYipD2MDAQ/U3MWPIN9Nz75EKU9Z9sGP8+jETwNiDg+T0mlPYFqCT+O/Qw89no5Po9YpT2wNgw/2SYIPDNDOj5HQKU9rbMOP/CJAzxq+To+y7CkPZr2ED+VLf47AZw7Pmr1oz0oDxM/hYf1O4kpPD6CF6M9ZxoVP9v27DsroDw+KhuiPdsdFz8adeQ7GAI9PtXuoD114Rg/3FvcOxRVPT5bmp89mo0aPypt1Dtrlz0+WziePYwcHD8StMw7w8o9Pp/KnD30lB0/QifFO8rwPT4KU5s9zPceP2PGvTt4Cz4+m86ZPcA6ID/WpLY7gho+PtFHmD3LZSE/RravO/AfPj5Kx5Y9GHoiP/n5qDsbHT4+EVCVPS94Iz9RcKI7FxM+PoPlkz0QYSQ/rxicOxkDPj69iZI9bh5rPfh5gDwfaKk9zRsqPbaDhz2KUoE8yu6yPbzlLj0vTJ09JfeBPJ2AvD0CETM9+NC0Pb5zgjwEEcY9bZI2PeSazD2y0YI8jpTPPTy3OT1oNOk9vNeCPLoI2T3ztjw9GhsCPibKgjyEWuI9Vnw/PTbNED4mdYI8cIfrPRh2Qj0UKiE+/8aBPEyH9D3DjEU9P54xPvDigDx4T/09pjxJPUfwQD7P1X88J+wCPvVBTT1fPFM+GNN8PFQQBz6HKFI9nxFiPmMuejzGDws+WKBXPYfBdT7xBHY8w+gOPhbgXT1uPYM+OCdyPECaEj41w2Q90XqMPrWDbTxtIBY+QUBsPXz7lD7842g8VX0ZPi4/dD2cBp8+RD5jPH6nHD4Pi3w9mgGpPsZeXTwfoh8+gZSCPRXFsT6V2Fc8hHQiPlbRhj0KJbs+v9lRPGATJT4zF4s9adbDPpICTDz4iCc+UzyPPVDzzD4F3EU8FMspPv41kz14VdY+1H0/PN/aKz64E5c9GGHePl2kOTx6zC0+u3GaPcRL5z6xWTM8poUvPjfLnT0p9e4+J5AtPEolMT5mbaA9fjT2PjDmJzw6ozI+xPWiPZJg/j4Y2yE8XOczPkPrpD3XCgI/s8ccPHQzNT5TeKY9Bu0FP1ThFjyhMzY++8enPTuwCD9R3hE8rDw3PjBVqD0YMgs/BA0NPDAvOD4ptag9lb8NP0gyCDw4ATk+y+moPV1sED8/QQM8jrI5PuO2qD2UlBI/Anb9O/hZOj7FQag9jrAUP26C9Dtu6To+K6KnPY6xFj/Kv+s7o2Q7PgPlpj3srBg/Ig3jO4TMOz5C/aU91GUaP1vR2jtOJDw+NdikPaYEHD/zydI7p2s8Puqioz3ijB0/UPLKO1OkPD5MXKI9VfweP1hPwzvYzzw+3QmhPa9WID+U27s7avA8Pnaqnz30kCE/n6y0O50EPT7PPZ49qrMiP+ezrTsbDz0+hNOcPQHAIz9S8KY7QRE9PmZvmz13tiQ/GGKgOxIMPT7GFJo92FI3PTd+iTyZoaQ9pI4oPchyXD2dcoo8VtytPR6GKz1J2oI9FDyLPFYhtz1c7y09wU6aPVPIizzCacA9xQIwPe7WtT1J/os8867JPYWlMT0BJ889qSqMPAjc0j2JHDM9OlTvPRLKizwv+ds9ucg0PbRdBj5TYIs8QuzkPd56Nj3zqRY+HpKKPGS47T1/uzg9lVwlPrW/iTxJTfY9t1Q7PWH/Nj70Vog8C7H+PRnVPj3xakU+8B6HPJFoAz7BAUM9gQxZPpn/hDy5Wwc+bRtIPXtvaT60FYM87CkLPsgRTj0fIns++8qAPNfTDj6bylQ9K+mGPg9YfDxlVxI+NF5cPWIJkD424XY8i7IVPm5sZD1BDpo+op9wPGjiGD49G209DbuiPvfTajyi6xs+Lfp1PVE0rD7tYGQ828YePjE1fz3W8bQ+oiFePLt6IT7bN4Q9jmS+PiVeVzwd/iM+0tOIPQL8xz6ka1A8YFQmPkdijT1/XNA+dgFKPBOIKD4Xr5E9sjjbPqxVQjwndio+YO2VPT3L4T5Uqzw8g2osPlKqmT3dqus+xG41PDMMLj5vaZ09qnDyPrSeLzyTry8+rmugPb+q+T5BlCk8WycxPn5ioz2F8wA/2x4jPHVoMj5ht6U9xsEDPxzNHTzqsTM+YbOnPbWtBz+dihc83rM0PhtsqT3kZgo/dVISPEu+NT7gXao9Jt0MP6pUDTwEszY+1h6rPV1iDz9bTQg8CIk3Pl20qz1BDBI/kSwDPLZAOD6K5qs9xCkUP04O/Tsd7Tg+hMKrPXY8Fj8R4PM7jII5Pplyqz3mNBg/fejqO1QEOj74Aas93BMaP1Yo4jvZczo+3WOqPcPZGz90oNk7kNI6Pl6CqT3pbx0/1njRO3ogOz5Ng6g9FvAeP+SEyTvuXzs++G+nPTBUID+t0ME7bpE7PthMpj0tpyE/cUi6O9C4Oz4ZGaU9NN4iP+sBszuQ1Ds+etKjPUf6Iz8+/Ks7QuU7PnCGoj3X/yQ/sy+lOyntOz7HPKE9YGn1PH+5lDzedJ89G3AjPe/dJT3rnpU8p2eoPfUhJT3h31Y9/T+WPEZpsT0R2iU9JcWCPQDPljzJaLo9PT8mPWI0nD0TFpc8Q2XDPUijJj0Avrk9Ju6WPAxazD1e1SY9JC7UPaLHljw8L9U9YDAnPeU29z0I15U8X/XdPfD0Jz29HQo+FxaVPJWH5j0QHyk9W7EbPg2rkzxM9u495QwrPZnLKT4lhJI8zyb3PdvDLT0rAj0+zV+QPBst/z2oWDE9j1hOPt1EjjzheAM+uw42PUY1Xj4cK4w8xjkHPoeGOz2W2HI+LB6JPCHcCj61HkI9EcmBPqt4hjxQWQ4+Om9JPW3zij6lZoM8cbIRPjSLUT02fZM+o12APPLmFD5oSlo9nJCdPjN1eTw/8hc+MIljPV0fqD4IsXE8EtMaPoJPbT0s5bA+EtFqPBqRHT6W/XY9Unq6PrRUYzwfIyA+8HuAPdMywz7xPFw8jJEiPsNjhT20lsw+R7VUPLfSJD6PPoo9PEPVPpGFTTxN8SY+owCPPd5q3j4EFEY8NOMoPg93kz1jL+Y+G1c/PNy8Kj4xypc9u3vvPrnbNzzPXSw+gMWbPSOd9T6J9DE8YwIuPnVEnz2U0P4+zZUqPIBaLz5FzKI9k5ECP2WjJDyftzA+hWOlPYqzBT8duh48M/YxPu/spz2PTAk/Sm8YPPUGMz6J/qk9eP0LP3UAEzynFDQ+qGCrPdNpDj/T1A08TA01PpePrD2v6BA/1J4IPB3pNT7Gka09tJETP0pMAzwIqTY+kjOuPTemFT/iDP074Fs3Ph5trj1dsRc/MKHzO7z4Nz7JeK49iZEZP9WR6jsKgjg+dFyuPTtoGz9Ao+E7R/k4PgoRrj0RPB0/BsrYOxliOT4qha09KcseP81/0Du1tzk+3casPepEID/+bMg7D/85Pvjwqz3DoiE/1Z7AOyU4Oj7oA6s9LewiP10HuTsRZjo+KgSqPSMiJD/CpLE7K4s6Pl/wqD3fOCU/W5CqO8iiOj7Uyqc9gv2QPMoTojxdCZo9jaIbPVqr4TyNEaM8VKyiPcvgGz2f0iA9jaujPINkqz0Puxs9yLpZPU3MozzxKrQ9EckaPcjkhT0P+qM88+O8PcLHGT3TnKE9asCjPDeXxT3KFhk9GD/BPWACozw0Ps492F4YPVhu3j1tOKI89cLWPbk7GD0SJQA+9dGgPK8t3z2EhBg9R6URPucRnzxPcOc9S8EZPe9dIT58Xp08iHzvPeGZGz3WyjM+4/aaPI1d9z0ppx49D1REPlGjmDwsAf89BrIiPQ0gVj6u3pU8NTYDPmmyJz0kRWg+WtKSPBzNBj5h5i09vJZ4PsXljzxRQgo+E+E0PeXXhj7694s8jJcNPnTgPD0iUY8+U5qIPJfJED5xdUU9gbyYPrnIhDy31xM+BsVOPVReoT7RH4E8YMMWPhd/WD2H7ao+KCR6PCeIGT5drGI9bqizPgB0cjwWKxw+fAltPeFAvT5HIGo8qqQePmmFdz1CBcc+n6ZhPAn4ID43EIE9l2XPPkEGWjztLCM+uyaGPbcc2T7Nl1E8mzQlPrFRiz23SuE+uBpKPGIiJz7AB5A9IQvpPjXcQjxL8ig+VcyUPbRs8j5KzDo8i40qPhUQmT3Xzfk+S9ozPE4dLD4EM509zOUAPwypLDxBhC0+QvKgPVkJBD8XZyY8seAuPh0DpD1bKAc/7DAgPMMgMD4ICac9ttAKP56GGTyGNTE+mYapPZByDT8R6BM8PUgyPqdgqz3A1g8/c40OPI9FMz69Bq09DFESP10nCTwIKDQ+tn2uPU77FD+YoAM8WvE0Pv+Vrz2DCBc/gXL9O1erNT4QN7A95w0ZP3PG8ztzUDY+96ewPcPnGj+wgOo7xeE2PobosD3WuRw/fF3hOxZiNz5y+bA9gYseP/BO2Du31Tc+4M6wPTQVID/E3887tjM4PtlasD16hiE/NbPHO6KCOD6eyq89NuMiP7PBvzvrxDg+nB2vPd0oJD9wELg7Xfs4PoBarj0VVyU/p6CwO9QmOT4GgK093TDjO8bysTx9cpQ9BmsSPU+TiDzC37I83cucPVRfET1yauE893OzPBA6pT1vJhA9S5MoPR5aszy1v609tM8OPe4JZD2t4bI83Ue2PU+/DD0re4s9FIuyPMC7vj26Cgs9ijqvPasJsTw3Occ9T8QJPWbfyj2CA7A8GYnPPTSlCD2rZu896eqtPHHN1z1LWgg9Ro4GPtMyrDxI3d89HKkIPbiNGD7+o6k8bc3nPdnsCT2orCo+/M6mPByN7z2AUQw9lUM6Pk86pDyxEfc9v4YPPZQ6Tj4FlqA8qmj+PdEFFD1vh14+4W+dPGm/Aj6hjBk91ZtwPofDmTxcLQY+fQwgPY/Ogj4SXpU8PHwJPkmvJz0rNos+RqCRPFWqDD7D4y89BpmUPkFljTwytw8+Dfo4PRQqnT51X4k8+KMSPqaNQj02raY+s+2EPP1sFT6Awkw9TWivPu+2gDw9Fhg+NjxXPd8NuT77Sng8dZkaPisNYj1XzME+W8BvPHv+HD5H+Ww9NVDLPqy0ZjxUPB8++uZ3PekM1D6qMV485FwhPnJxgT2CcN0+EVhVPAJWIz4euoY97tnjPgBgTjxARiU+r92LPSXw7j7+qkQ8B+0mPp8GkT28DPU+tfo9PO+iKD7NfpU96238PoubNjx9Lio+XQ6aPcySAj+4nC4804srPi4mnj3RWgU/J2coPOvvLD6Pr6E9kZkIPy3AITztLi4+hzClPcYoDD933xo8TUsvPugQqD1hxQ4/kggVPA9iMD5wZqo9CyMRPx5+DzzvYzE+yIisPXmaEz+C5gk8JE0yPrR4rj31RxY/eCkEPBsgMz43CrA9j08YP+w+/jtP4TM+3RmxPeRQGj9LUPQ7v440Pvv2sT0IJhw/DdLqOzooNT4hnLI9U/UdP5N34TvOsTU+LhGzPeqsHz9zZNg74Cs2PidLsz3QTCE/yJnPO2CXNj6aLrM9v7oiP3NKxzvu7jY+EuuyPcMUJD+qOb87+jk3PkeHsj3MUyU/Rna3O/x2Nz66BrI9dWoNO0XcwzyB2o49LhkJPe1H0juLlcU8ddKWPS3DBj1jk4w8wuPFPJf/nj0trwQ97LHyPEWaxTzDQqc9lLoCPb0GPz1qHMQ8jKOvPQKoAD3ciHA9rmTDPMzhtz0ISfw8kDuXPcbCwTwAJcA9n5r4PEIKuT0fkr88iVnIPVBV9TzMVdo9ASu9PM9w0D20gvM8rnv9Pa5SujxuaNg9bcfyPFPRED6DILc8FDngPaL48zwHOyA+uUG0PNzV5z1X/vY8mqMyPkOLsDwGSe89Bfj7POmhRT4Pgaw8BYj2PZe4AT2A1FY+JaioPBuN/T1+dgY9LHJoPiqPpDyjLAI+VjoMPav6ej5zH6A8W3UFPrkcEz12MIc+92SbPF6eCD4Lyho9foOQPjW4ljxvqAs+U1sjPYEDmT4WTJI8rJQOPvGDLD0Fe6I+Vm6NPOFeET7SazY9SierPr7WiDyeCxQ+i7ZAPSfMtD5a24M8aZQWPhqBSz16fr0+K3Z+PFABGT7ThFY9YRjHPrSVdDwuSRs+l79hPRDZzz4xXms873UdPiMmbT1GYdk+B7dhPF19Hz7pZ3g9qc7fPiA5WjxWfSE+FZSBPRak5z5i2FE8tlUjPockhz3TVfE+L2xIPJH/JD4dSYw9q9v4Ppd2QDwwoCY+VG2RPVqWAD8MKDg8OhwoPvdQlj33xQM/qhwxPIePKT68epo94oYGP3egKjxb8So+5YaePd3OCj9nhiI8JR4sPt6qoj34XA0/mHAcPIhRLT5CsKU9z/UPP85gFjxoay4+pH+oPWFOEj/VpRA8BXEvPi8fqz17xBQ/u9sKPC1gMD4NiK099XYXP7/mBDwwPDE+H5GvPYN6GT9kcv87+gMyPkUTsT1peRs/GD/1Oze5Mj6oYLI9fEsdP1GG6ztdWjM+kG+zPaMZHz8p8uE77OwzPilOtD3L0CA/Y6rYO3VwND6l7rQ9znAiP4Gvzzvz5TQ+GzS1PQLdIz9fO8c78EU1Pv1DtT3vNSU/8Ai/O7yZNT5NMLU9iUkGO2oZ2DxlRIk9ZggCPYdpDTucaNo8MuyQPYcp+jyGYfQ7aX/bPE2+mD0xYPQ89nafPH252jz4x6A9wonvPPYmAz23hdk8sd2oPUI56zxaT009SajWPKkSsT0RM+Y8fh+CPWSt1DwYJLk95WvhPGtDpz07QtE8Hz3BPS7q3Tzj38M9n5zOPBEryT1Zxto8lUjpPfetyjzFC9E9eibZPPEDBT6+E8c8SMDYPRkV2Tz8dRc+nMvCPORP4D2dddo8/PMqPh4YvjyAsec9sO7dPAL0PT51WLk89N7uPdug4zzeLU8+fNq0PGXW9T0DOOs8ksZgPtsmsDz/lvw9g+X0PFPWdT7yk6o84IwBPuB8AD0/PYM+ueOlPL+zBD6zPAc9cH6MPia5oDwFuwc+XAEPPefwlD4W2ps8daYKPpZ6Fz20VJ4+c4uWPFlwDT63wiA93vGmPtOLkTzgHhA+hZAqPUiJsD60JYw8O6oSPkj2ND33MLk+dCSHPO4bFT7nuz89GczCPubLgTy6aRc+0N1KPan8yT5w1Ho8eagZPrsmVj1oKNU+kS9vPESvGz7V2GE9QZfbPv4jZzwIux0+JtxsPXl84z4UHV48Y6AfPlZ4eD0QXu0+o+JTPGFYIT7U1IE9QHbzPstWTDwuFiM+Gx6HPQT7+j4s8UM8Qa4kPnaJjD0+BwI/1Lw6PH0cJj5Jm5E97NQEP1vQMzyZkic+DiSWPfMICD+LfCw8IuooPorBmj3y5As/wockPPYeKj6T/J49OW4OPwY4HjwiUis+S3uiPXEEET8w7xc8lG0sPnW+pT0kWRM/GQMSPJp1LT4X2Kg9Jc8VP0kGDDwbaS4+x7WrPQ+IGD8q2AU8y0wvPjIwrj30iBo/aoYAPPQZMD6FJbA94oYcPzKT9jvg1TA+GeSxPVJXHj9Anuw7sX0xPjRfsz3WDyA/5P3iO9gTMj5NqLQ9MMUhP6KF2TssnjI+Say1PSOAIz/CIdA7myMzPoxgtj0d7CQ/4obHO32LMz7ayLY9mcb+Olbh7zxqnoM9JTD6PFMdBjs3yPE8cRKLPUAs7Dwz1Aw7brPzPMOUkj1aReI8t2AkPOBH8zwLU5o9Ar3cPKY/tDwSWPE8hDiiPa8l2DzqdRk92g3uPPo4qj2wGNQ8RW1dPXYv6jxcObI9zPLOPCUljD0CruY8ACS6PcL/yjyHdLE9jt3hPJcLwj24icc8qIfVPcUG3TzJ1Mk9ZUjFPGOP9z2XSdg8jnnRPf3gwzzY+Q4+3dbSPDv72D1ID8Q8RNshPnNazTxCT+A9/fbFPCKUND4ezsc8dXLnPTC/yTy6W0c+9ynCPDxh7j3jUM88MQRZPmS4vDzCG/U9ktvWPAH0bT52dbY89pX7PY+44DzPn34+qSaxPOPwAD7EIOw8f4OIPoVrqzzM9gM+y5n5PGrwkD4AB6Y8k+IGPjVZBD3xSJo+hDmgPCmsCT6BuQw9q8+iPgDMmjx/XAw+G8MVPY5QrD4v+ZQ8IekOPiJuHz1W8bQ+ro+PPOpdET5eoyk9g3q+PvnSiTzirhM+Q0k0PX0zxz5oeoQ8wegVPqptPz0m1dA+E7N9PMn+Fz7XyUo9SETXPmcQdTyIExo+cNBVPQAy3z6uX2s8uAEcPkyOYT3sMuk++VdgPD7CHT5UJ209NFXvPiFGWDxFjB8+GR54Pe709j5zQU88vzAhPpvMgT3Qgv8+68pFPHyzIj4nWIc9yvsCP1fmPTxnMSQ+O1aMPQXDBT9MsTY8WqAlPuFJkT0jHAk/r90uPBrxJj6YOZY9qOIMP6uwJjwVJSg+v5yaPQKNDz9x/B88j1QpPj6Fnj2X8hE/1LEZPJ5xKj5AOaI9SUQUPy2VEzzxeSs+HMalPSG7Fj9bZQ083m8sPoEQqT2Gexk/Zv0GPD9ZLT6T8as96HobPxSHATwSKi4+gFeuPR55HT8GTfg7C+suPgOFsD0pSR8/xRruOweYLz7qa7I9zQEhP3FC5DvlMzA+kR20PWm5Ij8Fkto7esUwPhSKtT3peSQ/l/LQO6ZUMT7urLY9z4XxOiLfBT2G3ns9rj/zPCdF/jrLhgY90jGFPb/X4jz4gQU7rCcHPSWIjD2gn9U82d4LO9XDBz0u7ZM98y7NPLK0Sjw4gQY9BJ+bPbGUyDxZANY803MEPfFyoz1Av8Q80PY4PdxfAT0RZKs9OubAPGOjcT1QHf48qjOzPYSJvDxEh549xM73PC4Iuz0CaLk8lvm7PVWd8jxyucI97222PMPr4j2u5es8mlnKPQGEtDwsmQU+0vPkPJDT0T33wbM8XC8YPsJn3jzIIdk9/Uu0PId0Kj7g69c8J0LgPdgutjyh3Tw+DWXRPOUw5z0Purk8Fu5QPiF3yjzB5e09nR+/PObVZT7JXsM8MF30PZOcxjz7oXY+Z069PDGs+j2gnc881rGEPsbPtjzyWwA+aa3aPIT0jD524rA8J0sDPr2I5zxU4JY+OT6qPOERBj4PA/Y8kHChPoBiozwJtQg+ejoDPYAmqD45Up483FcLPou6Cz3jvbA+o3mYPNbPDT68FxU9rC+6PpxWkjwaIxA+ruwePavgwj6Amow8uWASPs5rKT09d8w+mZeGPJN5FD7gNTQ94ubSPoP1gTy1lRY+jf0+PXPW2j5rjnk814kYPrOCSj1s5OQ+ecFtPENOGj4gAlY9Kg7rPnkiZTyMIRw+FBlhPYbA8j6nfFs8CM4dPnHXbD1Zd/s+dFBRPDxYHz7GcXg9igEBP/XhSDwk4SA+XIKBPW/TAz+dM0E8u1wiPiPGhj3jGQc/JwU5PM67Iz5TJ4w9FiILP10JMDww+iQ+Xj2RPZS3DT/+Eyk89TomPjGslT3YXxA/XiQiPD1mJz527pk9RcQSPyWkGzwIgCg+4AmePZdUFT/HCBU8+4cpPvIEoj0q6Rc/coUOPC6BKj6Mv6U9JFIaPyhWCDzLaCs+G+SoPedQHD8yuwI8MjssPvO0qz1hUB4/Lm36Oyv/LD4ATK49BiEgP+387zttry0+cJuwPdraIT+36+U7OU8uPoCzsj3plSM/zgHcO1jmLj63hrQ9bODkOoskFj08fXA9ZtDtPMcA8TqpZRY9+6F+PR6V3DygJv06CZYWPXp8hj1io808ZqcEO5W3Fj3UvI09El3CPAZUdTt7dRY9hxeVPfMqvDyC7YM8udcTPSzDnD14mbg8daX1PLPDED08gqQ9T7i1PK8oST2llww9CVisPSMgsjwb2oE91EYJPTgQtD2J8648AAOoPYElBT03xbs91jysPKBrzj0hAwE9iF7DPQ42qjxUaO890KX6PErVyj3Nr6g8/qYLPjNF8jwcJtI98BmoPH+FHz6lCOo8s0jZPdijqDz6wDM+JtPhPLI34D0dg6o8uEpIPtCs2TzH7uY9O+etPDj7Wj4RI9I8F3btPdDosjwkRW4+z5PKPKPA8z20fLk8Wo2APuhBwzwX0/k9N/DBPCM0iz7Sebs8AJb/PWBvzDx8yJM+V8+0PIOeAj46JNg8RTydPm3arTyBTAU+n9jlPHXNpT4ObKc8D+UHPizk9Dw+Sq8+9LCgPKpWCj52zQI9jPC1Pv9WmzyayQw+kYALPZyavj4eMJU8MQsPPrQTFT3GGsg+YMyOPI8mET6I9h49mo3OPm3RiTwMShM+40ApPTd61j62S4Q81kIVPhA7ND1ag+A+rBB8PGkIFz4AKz893LLmPgbdcjxB4xg+/xxKPaxv7j4Elmg8rpQaPl+9VT2hPvc+oLldPB0iHD4XYmE9E9z9Pti8VDyMsh0+jTZsPZTIAT/5j0w8WDcfPhwadz0ekwQ/n5xEPMemID7RFIE9XUUJP4gsOjwp4iE+17yGPTzpCz8MxTI8dy4jPnOOiz0zow4/q2ErPHxlJD4AR5A9jhYRP5t6JDyJjCU+YdmUPQ94Ez9qyB08yaAmPvRNmT0fCRY/QPgWPOCkJz6AmJ09sfgYPxjWDzx9nyg+a7KhPTYNGz884gk8bIIpPm8bpT3zCx0/6CIEPA5UKj6gTqg9Zg0fP5H0/DuuGCs+1EarPWPfID8jRvI7A8orPsb4rT0zmyI/AvvnO99rLD5vcrA9SeDYOssSKT2ZK2U9DKHoPAF15Dofzyg9/fByPSnR1zxXFfA6CHAoPWt5gD1xjsg8EL/7Oon3Jz3+lIc9DvK7PEC4AzvKaCc9XceOPaQ/szwOKt87FpwlPbQolj2pTK885CKjPI6jIT35y509AtesPI2PFT3CyRw96oelPXrWqjw7EFc9jBcYPak7rT3/z6c8Jc+OPewnEz126LQ9lLClPHGRsT2YVQ49/3+8PfJ+ozxF39g9qzAJPdn8wz0y7aE8otAAPtMNBD3WUss9oOagPCPiFD4nNv48yXzSPemWoDyvbik+hHL0PAt02T30KqE8Fe88Pr5A6zz8OuA9LMaiPNA4UD5bXuI8cMzmPeyRpTwNVGU+IULZPG8X7T1L36k8iFZ4Pjzv0DxfNfM9G7CvPAnUhj7BRMg8XQH5Papotzwafo8+EMvAPIK1/j0CVcA8vvGYPooiuTx5DgI+kzfLPMKOoT4gDrI8cK0EPt6d1zy4/Ko+iMaqPFckBz7bo+U8+USyPtaipDwHmQk+fgn1PEMzvT7cAp08OcALPv0cAz3mxcM+sXqXPFEGDj4HtAs9zL7LPj5zkTzRHRA+414VPbgi1T6t84o88gUSPhWJHz2SHdw+K56FPFb2Ez7idSk9C1PiPrK0gDx62BU+HwM0PVMT6j6ugHY8iI0XPi4tPz016fI+H/1qPNQbGT6oa0o9ZJP5PhFvYTyHsRo+eC1VPf5V/z4Yv1g8QT0cPuolYD00fQI/JU5QPMizHT5ZYms9pEkHP2QkRTwp7R4+NxV3Pcf5CT9dRj08VkEgPj+cgD3iwgw/+Go1PAuAIT71pYU9EUUPP/4VLjxKsCI+/JCKPam2ET+h+SY8Ps4jPnxojz3iEhQ/1BogPInaJD5hJpQ9fqQWP/8XGTz81yU+l62YPXaaGT/ZuxE8/80mPvDxnD2Erhs/qKELPKusJz4WsKA9kq0dP2u+BTwheyg+ijqkPWCxHz+R5P87yj0pPsSIpz0shSE/6Pf0O/TtKT6dlKo95YrNOjf+Pj14/1k95MjiPIGk2DrBEz49Y2VnPVpG0zzPz+M6xAI9PV0RdT27yMQ8NAvvOrHNOz2qfoE9xSK4PKRV+jpYeDo9WZGIPZpSrjwt1wI7lgc5PSi9jz23dKg88LssPDoQNT0OL5c90lamPBPfxjy6ji89Rc6ePZ74pDwhsDA9jc0oPUSFpj3CaaM8QvppPRZbIz1uJa49uWihPKYJmz2Y+hw9o8K1Pc3snzzUYr89o/gWPQZGvT3jlp48BDrkPU8bET1VqsQ9zGGdPCRLBj7yIgs9muTLPcCenDxodBo+SWYFPS3w0j1pYJw8WlovPjyM/zxjxNk9Rc+cPJEwRD5Kw/Q8GWDgPeIMnjwHZ1k+QUzqPOS85j3hUaA8f5luPnY94Dyk2uw9it6jPHMPgD7Detc8gt7yPbevqDxN94o+1vfNPPJ1+D3RDa88U3mUPkx0xTy57P095QG3PGUwnT6clr08NJ0BPvaCwDxumKY+3aa1PLcbBD6Tn8s89U+vPmpDrjyihQY+RnrYPDfKuD7DwKY8X8UIPk6g5jzrcL8+D7WgPDMVCz6Nx/U8kWvHPqY7mjzFMw0+GHQDPQhi0T6uEpM8dRQPPvZiDD3futc+ZqSNPM8XET4iihU9847fPtazhzxN6BI+VaofPXGD6D72cIE8L4wUPpdIKj0IT+8+2HF4PLI8Fj61ZTQ9Hjn1Pg3wbjyt5Bc+tcQ+PY0G+z6Dt2U8g3YZPjePST1m6wA/juBbPK/kGj612FQ9lTYFP1XuUDxVJhw+2TRgPfbwBz8BlUg8G4AdPmOPaj2Gxgo/Hj5APJPDHj7J9XQ9LlUNP4d3ODzm+R8+ETl/PXDUDz9c7TA8Jh4hPjm2hD2FPxI/tKQpPBkxIj66wIk9mOUUPwQwIjwZNCM+FK2OPQiaFz8s0Bo8tyskPgBzkz2tJBo/GNQTPHcVJT6pupc9PjgcP8uUDTxv7SU+sr+bPZ43Hj/Ujgc8HLYmPjOUnz3yPSA/YJ8BPHt0Jz7xKqM9RePCOrs4WD1REU89GsHbPFePzTrkgVY9xRZcPWobzjwNU9g6RJlUPQ5raT26IcE8NC3jOh2CUj0SCXc9Jmy1PBQd7jpDQVA9j3WCPQ62qzxBIvk6mNxNPYeFiT0y3aQ8FXgyO2McSz0RtZA9FtGhPEuqcTw3lUQ9/DmYPcH+oDyH2ec8NJ89PW3Vnz2wjqA8r8lAPZphNT1Ag6c9SWefPOElfD0xii49sB2vPZ9ynjxNXKU9Xc4mPemstj30cJ08oqfLPWSHHz2FHr49hJ6cPM9t9T38Pxg9ZWfFPe3umzwLyQ4+o3kRPZuFzD0nZps8EbEjPpriCj37bdM9Li6bPMitOD4/mgQ9NR7aPZNrmzzkvkw+7YD9PAeb4D3RPpw8VdRgPv1U8jzI2+Y9qdSdPP9Mdj4OTOc8s87sPaZloDxUPYU+pRPdPDKO8j2WOKQ8Er+PPtIU0zy9APg9zW6pPBmOmD7aS8o832H9PW3srzx4B6I+MIrBPC44AT5aArg8O9OqPllpuTz2qgM+NtrBPJpJtD58RrE8BfMFPhD7zDzkDbs+ap2qPIlNCD4yrdk81MnFPotoojzqQAo+HYroPAvwzD7YB5w8FFsMPiI/9zw7WtM+OiiWPG5oDj5g3wM93S7bPlvVjzxUPxA+BfMMPccQ5D5mPYk8iOYRPtRsFj2g5Oo+I6+DPFedEz770x89Z9nwPnA+fTzGTBU+nLQpPfyw9j5dc3M8g+UWPv0XND2y2v0+9MtoPAdRGD7w6D496BMDP36GXTwFlBk+rbZJPb7WBT8arVQ8d/IaPqADVD0htgg/Z9hLPAY5HD4ycF49904LP/ScQzyXcx0+79toPXbZDT/voTs87psePjdPcz3SUBA/kuwzPP2yHz7aun095gcTPwsELDwIuCA+LQaEPdJaFT/Q1CQ8y68hPkQDiT01dBg/bL4cPDWdIj6Iy409FZoaP2QfFjzeeiM+9DCSPeSsHD+JvA881EkkPjxtlj2eyR4/OG8JPBYOJT7+fJo9y+u4Oh8KdT2ge0Q92lrTPAI1wzoGX3I9yR5RPcfhxzybm8064nZvPZYYXj2T4Lw8nB7YOjFWbD3HZGs9A8KyPHa94jopA2k9fP54PX0Kqjzgd+06BoVlPTRwgz1JW6M8o034Oj/kYT1Bgoo9BG6fPMtG0ztCdlw9UcqRPcG0njxetZs8hw5UPc1UmT3v3p489X0PPVy4Sj1e+KA9xiifPFNOUD1C2UE9BZioPWCNnjwaTIo9rxs5PckvsD12XJ48KlauPfGNMD0Qs7c9P+KdPPh61z3U4Cc9UBO/PS5xnTyOFf89XNsfPSVMxj3o/5w8JBMUPjglGD0EU809TJ2cPPfLKD6o1RA9mSPUPUxknDwe7D4+WrYJPXGu2j3PZ5w802FUPvQWAz3k/uA94secPCF9aT4Hvvk8mBHnPR+6nTwfF38+UtHtPOra7D2XeJ88i4yIPnVj4zwykvI9UCOiPNGlkz7ubdg88Mn3PVz9pTz4N50+wLHOPKHs/D3bGKs8Wx2mPjawxTwl8wA+QM6xPDaerz5/ybw8ykQDPg3OuTw30bc+z8+0PHiQBT69s8M87DDBPqufrDxdpQc+lCvPPCRtyD6oq6U8uskJPtJJ2zxTYtA+SKKePB/CCz5V0Ok8nVzZPhNklzyVhg0+scv5PPxV4D5tO5E8Tl0PPv7RBD1md+Y+XZyLPGEtET61VA0943nsPmkzhjzj5RI+L4gWPUZy8z5qh4A8iXAUPodkID1oMvw+Z5B0PP28FT5ooyo9YfIAPzndajxqNRc+1lo0PXboAz8NN2E8kJIYPgxoPj1PmQY/5zZYPHnkGT7JkEg9bjoJP6uCTzz+Ihs+weZSPffNCz/yE0c8pE4cPv9ZXT0tTw4/we8+PIVoHT7Q22c9YBMRP4KTNjxTbR4+zlRyPbByEz/F+y48fWcfPi6WfD33oxY/NmQmPI1PID4kT4M9xtkYP7phHzw9MCE+u/aHPZf9Gj/Knhg8TAIiPkZ+jD0zDx0/IhoSPEDGIj5w4ZA946evOjDSij1xWjo9Ha/JPCyWuToU74g9jJhGPeKEwDxKp8M6tOeGPf0zUz0ouLc8YdrNOiO/hD1WKWA9A5KvPOwu2DpdeYI9gXRtPehsqDynpOI61xqAPQARez2CuKI8YzvtOjpRez3PfIQ9RPqePN3y9zocUHY9OZSLPVXHnTyXejI8CWltPQD7kj2km548AgDEPLgQYz0CjJo9u6KfPGEMLD1sYFc9mjOiPfo7oDzcMmM9+9BNPbXMqT3AcqA8zsCWPUBUQz3AXrE9f7WgPM5gvD3uajk9Qda4PaHUoDxq7eA99TowPbMtwD00vKA8pGIFPsEJJz0dUcc9e4ugPC6ZGj41Yx49Tj7OPchAoDz77zA++hgWPT3o1D3L8J88409GPod9Dj2WWts9TK+fPIGjWj4Sfwc9pJfhPWSXnzzcVnA+4bYAPRGC5z3B0588BkGDPp2E9Dy1Hu09YKegPIrzjD5XAuk8UZ7yPSA1ojxPI5g+OWDdPAmn9z3h56Q8yCGhPrxY0zxDt/w9tpKoPMC4qj5Hhsk8t7cAPvh9rTxyBrM+UrfAPP8NAz5SH7Q8OQS9PqqNtzxTHwU+0WS8PL7Hwz4TLLA8vVsHPod6xTx6zcs+fIqoPN9dCT6BDNE8OL/UPjbOoDwuKws+zv7dPN3K2z7uJ5o8oQsNPkty6zzyAeI+qBWUPGHmDj7zhvo8YB/pPorTjTx+jxA++LkFPX318T7yCoc8yPERPpHgDj2n1fc++66BPPaHEz7Vjxc9+4L9PsIceTwMChU+xrkgPQm+AT9G5G48xWwWPm4/Kj31dQQ/ZlxlPLbEFz7nCzQ9fSAHP2klXDz/Bxk+DRo+PUC5CT9EQlM8ADgaPo5YSD0Hlww/9yVKPCNMGz6ayFI9NBAPP1TcQTwWWRw+wRFdPWz3ET+3Gjk8oUwdPhOEZz19uxQ/w8YwPOo0Hj6McXE9qP4WP9FeKTymFh8+dAd7PeYwGT95OSI8lOkfPkg4gj0FUhs/S1UbPFWuID6K0YY9VB2nOvEJnT3byjA9OA6/POe1sDp+iZo9AaA8PTQ1uDxpdro6U96XPQPYSD31r7E8Cl7EOqMMlT1CcFU9T6+rPEBszjqDGZI9c2ViPQxvpjy+oNg6cQqPPeuzbz0xOaI8TPviOnnliz1GV309GmifPKh77TrksIg9PaWFPbtlnjyGnaQ7/6yEPfrUjD1ph588RUqIPEJqfT2dUJQ9S0mhPLo1/zw3vHA9OuqbPV4Eozx2jz49J3FkPVSJoz3n66M83n98PVXrWD1IJKs98eakPLYFoj2mXE09r6+yPRp7pTyPIcg9JkBCPRcduj3k8KU8T5bwPemeNz2tX8E98COmPHiaDD7Sti09R3LIPZIZpjzmACI+30YkPSFHzz0W1qU8rwo3PvSMGz1C4tU9AWmlPPnvTD4TRBM9/DPcPSvjpDzX2WI+lYULPeM/4j3jX6Q8XZd4PrdKBD1MBug9+AOkPHuKhz4+z/o8RnftPX0VpDyln5A+IeruPOLn8j1mbKQ8KEyaPuFi4zwwAfg9aKOlPA2UpT7uudc8FZP8PWckqDyVxqw+FoDOPA3GAD65Sqs8XHe3PiYuxDyU1AI+4YiwPBzvvj7rvrs8VA4FPhFhtjyaC8c+b2izPK0aBz5ztb48lgvQPqYNqzyt8Ag+enHIPLcj1z6016M8ktwKPjEb0zwUd90+2TydPFfCDD6k0N88c+rkPlRnljwGbQ4+UFTuPIhl7T6SYY88Bd4PPpDR/Tw9WfM+L6KJPAh+ET7mxgY9wH/5PuX8gzxj/hI+ajgPPXQf/z4tdH08NHQUPgkbGD1nUQI/x1JzPNnTFT4/aCE95wAFPyqVaTywHhc+HworPefzBz9DqV88+EYYPkQANT0QhAo/bJxWPKpqGT4u8z49zAQNPyXgTTxHexo+cgdJPb9jED9DAEQ8Q14bPgI8Uz3swRI/Yeg7POhQHD4d8Vw9JhAVP6cYNDxOMx0+q5ZmPVdOFz/sjiw8QwYePm4hcD1kfBk/UUklPI3KHj41h3k9A1WfOiMWsT0+6ic9Z++zPGGaqDor8a09PVEzPSpTrzxpDLI67piqPXgfPz01C6s8TKq7Oj8Tpz0QU0s9eTenPHxzxTqXZqM9oelXPfX9ozycZ8866ZmfPUDgZD1AjaE8ZobZOn60mz1uM3I91x6gPJbP4zrHvZc9B99/PXT4nzzGQu46Or2TPRLvhj1sa6E8aBMqPI9njT1wRI49TwGkPJlIuDyVYoY9vMiVPSmHpjxDESI9h059PZxqnT2Uoag8PLdVPTikcD0MBKU9Ax+qPCxYjj0gBGM9TZysPZGQqzz9p6099PpWPX4jtD1Ql6w8kfPTPYzESj1Kh7s9O0GtPPtg+z2cTz89gr/CPVWhrTyWmxE+9KQ0PbLFyT2xrq08x6woPjwiKj1VedA9hXCtPEbQPT7pwiA9qvvWPWrXrDxvZFM+GfkXPcw13T3OAqw8YGNpPo+5Dz3sIuM9twarPLekfz64/Qc9F8HoPagNqjyjkok+VBwBPcFB7j1MKak8asmUPuqQ9DxFRfM9sK6oPMnlnT64teg8C1D4PdO1qDyegac+mErdPOgB/T3FXak8okGwPsbb0jxhywA+sY6rPLTZuT5LnMg85t8CPgJnrjxPD8I+VnK/PNr2BD5xWLM8sxHLPsxitjxN2AY+5sS5PAVR0j6iea48JM0IPrZBwTyHxdg+3z2nPIa9Cj5sGMs8aKHiPrnjnjy9KAw+AW/XPKDP6D42YZg83ukNPtps4zx+K+8+AwySPHyKDz6cLPE8EQP1PrknjDz+IBE+eh4APaq7+j4phIY8w6ASPoNKCD3CJgA/UR+BPO0KFD4v/BA9nC4DP9dfdzypTRU+jCMaPX/WBT/Abm08XI0WPg92Iz0Dbgg/L95jPEK4Fz6yCS09lt8LPwowWTzVpBg+4dQ2PTBWDj/QVlA8tKwZPgdVQD0qvRA/rs5HPEiiGj5u4Uk9qBQTP9OTPzxyhhs+UW1TPbxcFT8xozc8FVocPkrtXD1qlRc/O/ovPBEeHT4hV2Y9/VqYOlO6xj091R89QN+oPOVMoTra+MI9lccqPSZbpjzcb6o6//a+PXQkNj08MqQ8FcOzOv+8uj286kE9/niiPPpFvTp5U7Y91hhOPUJGoTwg+MY6VMOxPbKsWj0etaA8OdnQOpUVrT23o2c9/+agPPzo2jpFU6g9s/p0Pa0FojwMJ+U6S4WjPd5WgT2qRKQ8hKbnOzEQnT2Ieog90qmnPNldjDxaXpU9mt6PPUUPqzxk6fg8djSNPXxqlz0bOK48M2M3PaFLhT2QBJ89bpCwPNN3bD13XXw9sqCmPVG5sjxulZo9rEltPUc1rj0PbbQ8MU++Pfl3Xz2wsbU9sMi1PBqK5D12VlI9gwi9PZm6tjxCdQU+VzFGPc0zxD36Nbc80t0aPqN5Oj2oG8s9Q0S3PO6SLz4Zzi89CczRPdritjzsqkU+Ya4lPdsr2D2UHbY85GpbPt9cHD17R949Xvy0PFBvcT7XqhM9pBTkPUyWszz514E+ERYMPbPT6T0q5bE8uQiNPklzBD0KBO89lTuwPOPAlj5RVfs8nh70PYuzrjz5BqI+2tvtPIus+D07tK08IoKqPiVv4jyfbP09CS+tPPmItD4M+tY8wM4APh+LrTy01Lw+9d3MPDHxAj7IO688buzFPkXzwjwc3QQ+nHCyPCNHzT7eQLo8ItwGPgKAtjyg3dM+zUqyPIfWCD71/rw8ULXdPihcqTw3Swo+EAPGPMgA5D46QqI8WBYMPpMwzzytduo+V2WbPOfADT7PbNo8O2rwPtMElTwGYg8+GWrnPBs99j5B8Y48puwQPiMF9jwSfvw+euiIPBxOEj4BAgM9aQIBPwVhgzzJrRM+fGQLPWYpBD/EaXs80NoUPqZLFD1eMwc/g5pwPEP3FT4BRh09lcIJP8vgZjzrGRc+l1EmPaFBDD/dhl08aygYPq6HLz3jsA4/i4ZUPGgjGT6T1zg9rxARP6HaSzygCxo+CjNCPU1hEz+qfkM89OEaPuSNSz1dxRU/aTo7PE6jGz7e2FQ9yT2SOsuL3T2tphg94G6ePETZmjqETNk9sxwjPV/UnTz8qaM6lbfUPZn/LT0WoJ08HK+sOvHYzz3rTjk9zt6dPAfotTp7vMo92glFPfycnjxKVL86/m3FPSkvUT0R6J88kvPIOgz5vz0vvV09VtChPJXF0jr2aLo9srFqPQNrpDz/ydw6tMi0PdEJeD1P1Kc8H+iIOytFrj3g74I9yCSsPDQEXDxDkKU9NjCKPc6JsDySu8c8ErucPYWckT1npLQ8FKchPT9Qkz10LZk9wB24PCymUT3RWos91cCgPX4EuzxxHYo9V+6CPeFbqD0dn708ovKlPTtFdz3G7a89cZ6/PPNEzD19/Gc9HmC3PdomwTwfEfE91SlaPfyvvj3kK8I8/zgMPkwXTT3Ry8U9Y63CPMYpID6t/UA9vK/MPQSrwjzVEDU+FqI1PXdN0z2FJcI8k+9KPgH6Kj1cm9k9ax7BPGKXYD5zKiE9d6HfPRGdvzwMd3U+CzAYPT5n5T2ws708y9uFPvqlDz1PyOo9SHu7POQKkT6irgc9T9TvPRY0uTxcJZo+Br8APdHl9D06tbY8jMGjPgM+9Dwcmvk9kFq0PFiKrT44s+c8//v9PRfvsjwiI7Y+tmncPKEpAT4DkLE8Ami+Ps/h0TyPPQM+guqxPNMCyD5sYMc8zQgFPrYmszzqts4+CJe+PCkNBz5uC7Y8/mrWPsvXtTzx1Ag+Nkq7PPH/3j52K608BGAKPrnDwTxTkuU+Z7ClPOATDD4TCco8d6nrPse8njwsvg0+wHbUPKaX8T7WJpg8iFMPPr7q4DxZ7vc+LauRPO2+ED6m8+48VG3+PhZdizzPCRI+02r+PPhXAj++YYU8MkMTPs08Bz0YAwU/DvN/PKiEFD4ujg89vZwHP9WZdTwTsRU+yDYYPWYlCj9rrms8qcgWPnQdIT2bnQw/iShiPMXLFz4MLSo9GiMPP0TSWDyftBg+ClYzPYyAET9y/E88NJAZPjx6PD26yhM/mYBHPEdaGj7JmUU9IA2NOhfv9D2ZdhI94yeVPM1MlTrybfA9ymccPSNFljzCxZ06aXXrPVnHJj0U1pc8IHemOu0W5j1tlTE9TeKZPERgrzo2Y+A969E8PS9vnDyvgLg6VmraPV98SD3agJ88ENjBOqE71D0HlFQ9tBujPB9myzrB5c09pxdhPV1GpzyXKtU6rXbHPWwFbj3bC6w8GkVHO/9vwD1KbHs91HmxPPrcQTxyobY9osqEPV/1tjygxK08ugqtPWsNjD3HFrw8EvISPSpboj2dhpM9GbfAPEjOOj2Jwpk9FwSbPTKKxDzr6HA958qQPZmZoj0MBsg8ACaYPcD4hz3NL6o9D9TKPH/juT2dR3893baxPQsizTxmGNg9rntwPaksuT0szs48tLP9PRGzYT02csA94dzPPBn3Ej6tyFM9IX/HPcBR0Dy2TSc+CPVGPUxQzj0aJdA8Y8U7PnwgOz0h4NQ9plzPPNHLUD5xHTA9sSPbPR/8zTxKWmY+ctslPbUU4T1ZCsw8PUJ8PlRQHD1ysOY9TZzJPFYciD4guhM93h3sPQvHxjxBzZI+rIsLPSsh8T2ulsM8UrGcPm0aBD1Q9fU9hmrAPOdhpT7q1Po8Wrb6PaUTvTzsibA+3S7tPJOw/j0STro8t9i4PriP4TxkegE+IRO4PL/nwT74S9Y89GQDPrjXtjxFU8k+3FPMPM9gBT6LX7Y8RR3RPvO8wjysMgc+0kS4PK7G2T7ITbk85sYIPhimuzw5dOA+kh2xPIqDCj6glcA8BavmPnaCqTyANgw+hvHHPJm67D4dU6I8wNQNPlu80Tw2LPM+mU+bPDVJDz5Kd908wXr6PjA+lDzGfxA+GgPrPPYIAD8GI448OOARPjxA+TzmwQI/hlOIPPArEz74XgQ9Z2gFP3bJgjzUYhQ+D5kMPeP8Bz88/no82IQVPr0tFT3Nnwo/RatwPBeJFj7z+x09jRINPwH3Zjz6gRc+hesmPQ91Dz+Vpl08rmYYPtzuLz3uxxE/BLNUPLc3GT4v9jg9V9iIOuEPBj5ZWQ090YiNPPG0kDpI3AM+ybwWPZQukDzJzpg69VMBPlmPID1cVpM89yShOrMG/T2x0So9KASXPMu2qTpR7PY9T4Q1PZs4mzzCg7I61m7wPX2nQD2r8Z88iIu7Ouui6T1PO0w91yulPOHNxDr3m+I9fj9YPdvjqjyZSs46JmzbPU2zZD2jGLE8eZ5XO3Nj0z2tq3E9Sse3PAoPOzyToMg97WZ/PXNjvjzwuKQ8RhK+PQPGhj3ln8Q8LNj+POE3sz3bDY49qlzKPLU9Lz1r0qg90HaVPWhIzzwY/Vs9jEefPRX2nD1/vNM86KGLPeR6lT1Zh6Q9CIjXPOIUpz3GpIw9YBisPVKr2jyOaMk9FdCDPQCYsz3lEN08x6HqPVWSdz2A/7o9fsfePEjsBz70M2g91TjCPd7L3zxgvBs+Q8lZPWE4yT12GeA8HIcvPneOTD2B/c89za/fPJL4Qz4fQEA9a3rWPfOT3jwQ/1g+y840PcGn3D0mzNw8QWRuPj8wKj3UgeI9lmLaPIkNgD7H6CA9f0voPVNN1zx+DYs+Q64XPTJ77T39wdM8M4+UPnV9Dz2Rk/I9P9TPPASpnz6hdgc9IBT3PS+0yzwFC6g+jJUAPVfF+z08lcc8ce2xPiyd8zyq3/894nfDPBotuj7yj+c8EQUCPgE1wDynvsM+Eq/bPFPPAz7rir08PH/KPtiZ0Tx40QU+FxO8PItF1D4H4MY8Lk0HPgXlvDxxwdo+XQC+PE4dCT5nWr48G2jhPumGtTwuzAo+DFLCPHea5z5tp608vHEMPjj4yDxtKO4+VgamPBzuDT6u/dE8uIX1PvVsnjzgLA8+MyPdPNU8+z66zJc8wpUQPhaA6TwwZwA//oORPILqET6yjfc8Ah0DP8aLizwNKxM+YHoDPQneBT+YxYU8Yk0UPmCrCz0Vbwg/+FqAPCFlFT6/NhQ9Mu4KP15ddjxbaBY+DgMdPQJcDT9td2w8FlcXPh32JT03uQ8/J/tiPHwxGD5g+i49jqyFOi4jET6cXgk9vwqIPLkdjTryNw8+nCsSPVIQjDz+z5Q6+NUMPs1nGz2KpZA8acKcOiUOCj49FCU948uVPEL0pDpZ8AY+8DEvPfOAmzwCZa06dosDPtPBOT3cvqE8VhS2OqTa/z27xEQ9QH2oPA4CvzqSRfg9RztQPZWyrzwLLsg6h2/wPcElXD3LVbc83YukO6mu5j2gs2g96Ui/PGLORzwLQNs96Ol1PW8Gxzwpv6U8LNHPPeHMgT2LZ848bgMHPZAbwz337Ig9N0zVPK0hKT0Mtrg9MSCQPWxf2zwlOlA9MHOuPdN8lz1D7eA8gCaFPS2Hoz2V+549Sc3lPBKtmz0AL5o9KYOmPV/e6Tydfrs9b3uQPdAKrj0XLu089PTcPcxnhz0FgbU9/LXvPHRU+j31xH49+ue8Pd5f8Tw2LxA+VK5uPXkUxD0bO/I8VYEjPjDcXz2FC8s9tUPyPCl9NT4Xi1I9TtbRPXd48TwMJko+k7dFPR5D2D1l5e88519ePub9OT1da949yY/tPEJxcj7rMC89/kjkPQ6C6jzFAoQ+pPgkPQ676T0Pz+Y8NZKNPrPWGz2jB+89k4viPDXClz5TLhM9WujzPabQ3Tz5I6E+cE4LPTab+D3yqNg8w72qPgXkAz0V8/w9wsLTPEAxsz69Zvo84p0APo6DzjzyR7w+Z47tPAiLAj52Wco8FM7EPke44TzfZAQ+ckfGPH1TzD5A8tY8Bz4GPqMAxDyKINU+k0jMPETJBz6zH8M82urbPj/3wjykfgk+iLfDPPA04j4KVbo8FCwLPgXvxjwd3Og+MQGyPM+vDD4458w87J/vPkELqjwFEw4+RE/VPDwj9j5Kj6I8dmUPPml83zyC1fs+ULqbPGjBED62ses898kAPzsulTzxABI+w7z5PISBAz+eB488MDQTPlyQBD1wIgY/NDKJPARVFD5+0Qw9mLAIP9GkgzzvYRU+QXoVPXEsCz81s3w8wloWPiloHj2Ulg0/aZZyPFo/Fz4Nfic915KDOp1OGz5rkAY9Qy+FPDKQijrj7Bk+Yb8OPW9zijw90pE6t+oXPttcFz3zUpA8BFiZOn1dFT49aiA9ls2WPM8goTqfWRI+/OgpPSbfnTwZLKk6ZPIOPo/aMz26f6U8lnmxOso5Cz53QD49WqStPB8JujqNQAc+FBxJPfo/tjzNMhg7DdcCPtl5VD20Q788JVYEPMnn+T3dlGA9ClXIPCMPczxNxO092DptPWkv0TxegrY8cJ/hPQZhej3Ps9k8DK4IPT9r1D2jDYQ907LhPFybKD12Lck9xwqLPS4H6TzaJU89a+a9PUI7kj0Fye88/HeBPVRKsj2llpk96s71PFhulj1bH6g92QWhPWb4+jx5wLM9O6CdPRaFqD2JT/88fA/OPQQ8lD3uBrA9sV0BPd157T2CDos9hHi3PYaYAj2t1Qc+l2CCPeXKvj3KXAM9C6MZPt6YdD0M88U9aKkDPfCBKz6guGU9/urMPdh9Az0Doz0+evVXPaao0z0+2wI9CihQPlwvSz1iIto9wMQBPZZeZD6qFT898TzgPSRBAD0RVHk+eswzPXr65T2pt/w8ztGFPgvCKT1alOs9gy/4PPyKkD4FACA9xZ3wPS8N8zwSS5k+cHAXPUum9T20a+08eYSiPlBWDz3gSfo90FjnPLXhrD7mgQc9CV7+PTRq4TwQU7Q+8s8APdFhAT5iQ9s87GS+PoX18zwBIQM+VvrVPNy1xT59Oeg8rhEFPovt0DyJZs0+GwTdPFbVBj5gtc08juPVPtwk0jxSWgg+Zq7LPAiO3D4Yjcg8kAQKPs2MyzwMzeI+jqG/PBSkCz7ANM48TmfpPtQLtzyVGQ0+f5nTPEK/8D5Gna48E1IOPs9n2zzEjvY+cimnPMGzDz6GUuU8rTv8PsQdoDzhARE+UpTxPN79AD+EXZk8cjISPqC3/zzGrwM/sAuTPBJaEz41tQc91U4GP0oMjTyPbhQ+ZyoQPcT/CD8bPIc8HWIVPhwTGT3leQs/gc6BPOlPFj6KOCI9kY6COkROJD518gQ9ZJWFPOIQiTolsCM+yX0MPeb7izzw2o86FEQiPh52FD0AB5M83uuWOgUjID4i3Rw9ebWaPAFDnjqCZR0+pbQlPVUCozzm36U6ISMaPpn+Lj3v5Ks8TsKtOjpyFj4KvTg9W1G1PJ0tDju1JRI+YPtCPRA4vzzqSek7GEsMPn3pTT0eT8k8L4ZSPAEkBj4KZVk9YV7TPHKonjzdm/89VWxlPXBG3Tw0Id48O5LyPez/cT0y4+Y8JmERPW2u5T2YEH89D/3vPPrmMT2Petk9o0aGPU2Y+Dz/9lM9tqjNPX86jT3XTQA9LcKAPY+CwT2iY5Q9rOoDPRBClD0QlLY9vKybPUYcBz2/lq89SE2rPWcUoz3X2Ak9mY/GPfhUoT06i6o9PhUMPY3Z5D3aTJc9LwCyPW7LDT1P4QE+qP2NPTdouT30+g49h7oRPgVXhT2Kt8A9558PPQEdIj4vkXo9deHHPd+1Dz1c6TI+KZhrPazbzj1IRA89Py9FPtBxXT1Mj9U9ok0OPT2AWD4LMVA9DvPbPaXZDD0Nq2w+4tFDPSj+4T1d8Ao93UJ9PqH4OD3G9ec94o0IPVYeiT7UPC49E07tPfPPBT3xH5I+NbIkPZGK8j2ttQI9XmScPnx9Gz3NOPc9R9r+PDTKoz4CmRM9qB78PQK19zwFiq4+iXQLPZwBAD4qlvA8coa2Pr1tBD2nFgI+HZ/pPPFGvz7xWvs8Uu4DPvgg4zxKc8Y+xErvPFXVBT75Pt08NgrOPj/D4zzOjAc+gCzZPIZm1j51m9g8PAUJPiJL1jwJ/9w++bfOPNqhCj7MntU8DqrjPqhVxTzBHgw+cevXPClw6j5yZ7w8Z3oNPkMK3TyS+fA+TAW0PIrEDj7je+Q8O8D2PgNVrDxeFxA+64vuPCGc/D6I/KQ8aEwRPooT+zzaDwE/tByePJJ4Ej7g0QQ9qb8DP/CZlzwMkhM++PQMPeB/Bj+fUpE8GosUPtLBFT37Cgk/t3WLPEV/FT7b+x49SJyCOnAPLD7ogQQ9TBSKPJueiDpkWCw+82YLPfd/kTzi6o46JagrPny2Ej2Sl5k8b4CVOnYZKj52cho9g1miPL5enDqzxyc+BJ0iPcTAqzyPhaM66c0kPng4Kz3ZxLU89MuRO30nID5lZjQ9FkXAPMAnFDy2oho+PiI+PaAGyzzP8l88DNoUPr9hSD0+8NU8drqdPA2gDj4VMFM95eXgPDbl0zwlFAg+BY5ePXzF6zwRiwc9kXMBPm50aj2jX/Y8d2ghPa1a9j2D0XY9fFUAPW+gPz2lquk9StqBPRNDBT11LGk9f2PcPVqQiD0n5Qk9lpeFPcpu0D0dc489ViQOPXdwmT02oMQ9gIiWPbT9ET2eea89pzK5PV/FnT3JVhU9dXrFPaR8rj2LH6U9gC0YPbtt4D2K7qM9X4msPTxvGj3REP09KPqZPdv0sz3kHBw9VUcMPiHckD1qW7s9MCwdPcJxGj74Vog96q7CPZmZHT3Hqis+twaAPY3MyT3Bah09o8M9PnqGcD1isdA9WqQcPa+3TD6a5WI9NILXPXRAGz2bBWA+SmRVPUjd3T1tURk93ARxPr1VST0vEOQ9W94WPdGogj4znj09i7zpPbr0Ez2R3oo+jFczPR1d7z1bmBA9f7eTPg2YKT0Ok/Q9sOYMPS49nj4SFyA9WyL5PW/1CD3QGqY+st0XPYzb/T2F1wQ9doavPnjSDz0e9wA+l6QAPRBetz4knwg9QAQDPsRA+TztjcA+/ZYBPQ+/BD4SvvE8+QPHPuIH9zx/rwY+LgDrPKdtzz7Q1Oo88TcIPh895jzHt9Y+4cHfPCHHCT4jruI8ijndPqaU1TxMVgs+56fhPJnO4z7A7Ms8AcUMPhHD4zxkf+o+Rb3CPNgRDj7v3eg8VfXwPiAdujzeTA8+RofwPJGv9j5fL7I8LJAQPmoM+zwEgfw+L52qPEu1ET5WFgQ9cf4AP1KGozzE0RI+ocALPXCrAz/Fz5w8vdsTPkNVFD1haAY/jVmWPJLFFD6zmB09TrGDOvi1Mj45NgU93tmTPNExiTqH5DM+6HULPdIknDxf/Y460vczPnUcEj2kIqU8fXpLO0NOMj6jNBk9ociuPOmNyzsGWi8+3sQgPfL1uDytRB48qIYrPtHOKD35nMM8bpFhPGDcJj6NWDE9q63OPA1SkjzluSE+pGA6PcMS2jxRfr08rN4bPrXzQz0jtOU881fsPIarFT4wDk493W7xPLH2Cj3KiA8+16dYPccv/TymkyI9UywJPiPNYz31bAQ9Q/Y9PWejAj5if289ZiUKPUuCXj367vc9kL17PQmqDz2s9ns9iVHrPTo5hD1j6RQ9af2NPSjs3j2l0Yo9rtUZPfjwoT0LcNI9oKWRPZlVHj2sibQ908/GPU+omD2lWyI9ZkHMPTMquz1o1Z89O9glPR/E3z1tv7A9giKnPe+5KD3da/s9GB6mPe5+rj0g+Co94qUJPhCZnD296LU9zoksPa/bFj7WgpM990u9PSxlLT0RBCc+paGKPbeLxD0Kji099M40PgG+gj1Gv8s90gAtPW8gRT7AOHY9/7LSPdPCKz3Q5FU+XwBoPbdq2T1Z3Ck958doPmZtWj2kwt89b1wnPbc3eD4Ke049vQXmPQ86JD0hjoQ+wR9DPQHm6z0AnCA96Z+OPskVOD0hMfE9nZQcPfnFlj7FWi49dHP2PUkkGD0heZ8+BSElPeVG+z3QaRM9hienPpq+HD0C+f89EJwOPX1isD7kixQ9MwACPqG4CT21D7g+sTANPY8GBD4QGAU9zxTBPjcCBj15uAU+QsoAPdZlxz43kf885J8HPm72+Tykqs8+uBTzPM8cCT7mg/Q8HNTWPi655zyynwo+SpLwPOE53T5URN08liEMPtpm7zxstOM+olfTPASCDT7QnPE8dEzqPkbmyTykvw4+zRb3PCCs8D6tBsE83eoPPqhk/zyDVfY+atq4PPMdET7qXgU9ABn8PoMMsTwsMhI+Lm8MPdfEAD9ivKk8zT0TPuWqFD2ObQM/V8+iPOo2FD6j3h09spz8O2ZBNj5S/AY9rhSkPHW+Ijz0Ujc+waUMPWy+rDxaSUw8exk3PiC4Ej3kCbY8hVN5PC+6NT70Nhk9dPK/PJfNlzxUNzM+vSYgPRVwyjyMvbg81qgvPoeMJz2fdtU8DzzVPAaZKz4kZy89afbgPHd19Dyp3yY+Gr03PS/j7Dzf/Qs9SI8hPkqTQD1KJ/k8MtQePWnbGz6R60k95tQCPaAwNT1LuBU+E81TPRsmCT3aKk090GMPPnI2Xj0HdQ89CBVlPYgNCT7eJWk9eLIVPbvHfT1XugI+zpx0PcbMGz3DKY89FEn4PWBSgD0/rSE9VEOdPRTr6z0Ok4Y9AT8nPZsCrj1djN89xBSNPSVwLD2qV8E90lfTPUXRkz3HKDE9MmzSPVkPyD3av5o92VY1PT846T1FrLw9ANuhPePoOD3UA/w9BWuyPR4bqT3Lyzs9Y+sKPk4TqD1YbbA9IfU9PWEfFz7lj549P823PXhYPz1RDiQ+OJKVPUEqvz0l7j89w9swPig3jT3EfMY9ObY/PWmpPz6RLIU9iKXNPUmvPj0e808+RRN7PSGV1D2V4jw9RwRePuFhbT0sa9s9W086PYywbT53UWA9UPDhPXMNNz1kVoA+LZhTPQn25z23LjM9wPGHPnxkSD0l7O097K8uPaE7kD5SvD09a3bzPVS7KT2vKpg+UeIzPSS6+D0rayQ9sp6gPsSKKj0bjf09Xc4ePWkXqD5FByI9ix0BPo0pGT0QHbE+3LIZPcIcAz5zeBM9Lpq4Ptg0Ej1rHQU+YSEOPWjXwD44Ags93dsGPsE5CT3/lsc+e4YEPT6mCD6H8gQ9tcTOPtil/DxRPAo+E90BPb641j5OqPA8hY4LPtK2/zzA/Nw+Re7lPE0DDT7rof48Et7iPnfq2zz+ag4+4JsAPbAg6T4RS9I8eqQPPvq5Az1iGPA+3+nIPBWeED68fgg9d6v1Pkp+wDxRwBE+vMwOPUdc+z7kcrg8ucISPu+XFj2LXgA/XuewPGC8Ez7Omh89bFTDPKOrNj6BsQk98bO5POs91TwMCDg+ldIOPeNuwjwaQeg8NjQ4Pl9WFD2r1ss8Ge/9PE06Nz7lPxo9CunVPJ5DCz3xMzU+IZMgPY2g4Dxl7xg9B0EyPuJTJz2q9Os81VgnPQ+MLj73hS49Ttj3PME4Nj07OCo+0yw2PRYfAj36a0Y9flQlPtJMPj1BiQg9boJYPQf1Hz526kY9bB8PPZ72bD06Lxo+SApQPfDSFT3y64A9KjoUPiqtWT2Jkxw9wUqMPVwXDj6S12M9VFEjPTgblz2gAQg+ZIduPYH4KT2oy6U96Z0BPmvIeT1JdDA9Yz2zPRX09j1ZxoI9QK02PZB2wD3gCes9peqIPQOPPD0wz9I9b8bePYlSjz2DAUI9qm/iPaVq0z1s9JU9XetGPfZ49D2SRsg9Dc6cPc46Sz17bAQ+mXO9PX7Woz0m1k49doQOPn1Csz0rBqs9Hq5RPfrxGT5FbKk9I0+yPeKwUz2zPCQ+yGOgPUivuT2b0VQ9LrMxPspvlz0rA8E9NAtVPRjSPT4pRo89jVbIPS1VVD1NnEs+cXCHPVaFzz2OtlI9JLRYPvk2gD3Al9Y9ny5QPZtiZz5snHI9zWbdPUDQTD0cbXU+QtllPVcD5D3vokg9RnuCPrSrWT17Quo9EsFDPSbYiT64bk49s0LwPSg+Pj2sz5E+4r5DPVDX9T29NTg9aH+ZPhXTOT38H/s9wNAxPRuvoT7MZzA9Q/X/PfcfKz1z8qg+V8onPSFQAj5rdCQ9OLWxPrxcHz3cTAQ+RNAdPUH8uD6NwRc9xkgGPi6iFz0D+cA+dnIQPdsBCD4LEBI9opXHPlrUCT0/wgk+DkUNPQiWzj4PgAM9BU4LPvblCT0sTtY+rMX6PIKWDD7v7wc9B3/cPsLB7zzj+g0+SJUHPac54j5sfOU8plQPPsY/CT12Weg+QJvbPHZ+ED6G/Qw9GJ3uPpgt0jyugxE+5KASPair9D50S8k8inYSPvnYGT1mDfo+4hTBPMxxEz7OmyI9MlY2PReFNj6CNw09WTvVPEj9Pj3uvTc+tNkRPTn33Tx2/0c9V+o3PkHYFj1VaOc8W89RPeIWNz7hNRw9+I7xPJ7cXD0iUzU+yvUhPW1o/DysVGk9vrQyPsgbKD139wM9CWB2PcFhLz4ErC49XwwKPTcHgj3Ocis+Pao1PbhsED0ra4k9j/omPmYaPT1PEBc9zSCRPfwXIj6EAEU9juwdPd21mT2I0xw+PmFNPRX1JD2Bu6I9DU8XPilAVj2mGiw9EmGtPXCCET7Pol894EszPZzHtz02rgs+44lpPQ52Oj3LMMI9l9oFPk/4cz2XhEE9fovOPSLb/z2V8n49AWFIPYrH3D0D9fM9HjyFPVPyTj1+3+k9govoPR5Ciz1IHlU9lTf3PYB23T3hipE9NM1aPb2IAz5kftI9cROYPTLkXz1N0Qw+M7bHPUHVnj1KSWQ9E6MUPmnCvT2mzaU9d+RnPfwaHj6D/7M9AfCsPQehaj057yg+UYyqPX8vtD1Qa2w93a4yPg3ToT0+i7s9QjRtPfLaPT66aJk99OnCPYj0bD1vdEk+P3WRPcNByj1woms9SzdVPtj7iT0Gh9E9i0NpParPYj5qx4I9MZfYPZvfZT1j1W8+eDJ4PVt/3z24f2E9Jm9+PgNlaz2TFOY9yDxcPckahj69jl891HDsPXEnVj2tto0+cTxUPRtj8j0AZE89WnCTPpssSj14Uvg98ghIPT+Kmz69DUA9l4D9PZRRQD3ip6I+EtA2PYRAAT7jUDg9B5+pPjYmLj1qlwM+V2YwPfkpsj7voiU9rJAFPvuhKD2/NLk++/AdPZWIBz71diE9IvnAPnuHFj0AOwk+8yQbPRxgxz6RzQ89cPMKPiLNFT2SGM0+eZEJPUugDD4zGxI9A8bUPo5LAz242A0+LlsQPfFh2z5JGvs8chcPPttqED2WRuE+4nXwPPlTED4uthI928fmPg9/5jwKhBE+LFAXPSWv7D6649w8d4MSPvQKHj0Uu/I+sLPTPD9eEz4SmyY9KKOPPYXwNT7cQxE9GHX2PKVikz1gsjY++3YVPfog/zzUc5c9yZM2PmL/GT27QwQ9YtmbPYmhNT444B49XlUJPWaXoD3v6jM+xRwkPUrFDj2xrqU9hYExPni4KT39kRQ9qHSrPZBwLj5Qti89WbgaPeRTsT1O2So+PBs2PW4zIT1QxLc9z8QmPmTqPD1k/Cc9wHS+PdpNIj5hKEQ9LQovPX+TxT1Hgx0+S9lLPZVRNj0BJ809pnYYPpMBVD0KxT09zUbVPSU3Ez6opVw9nFRFPdvW3T3v1g0+1sllPf3tTD0cXuc9l1oIPnJybz2HfFQ96q/xPabTAj7konk9SulbPXMd/D0/tPo90S6CPXYbYz1cEQQ+jL/vPTTShz3N+Gk9U8YKPjTn5D0Yu409tWRwParvED5AhNo96+iTPbJBdj2hzBc+yFjQPfRYmj31c3s9vW4fPqFvxj2dBqE9Ut5/PZjBJj7MBb09j+6nPYyygT0umzA+Q6KzPZ3/rj3x94I9tq44PnYEqz2bP7Y9xbKDPWd8Qj7umqI97pO9PUbcgz3DH0s+cdGaPS0BxT29bYM9KxhXPlsOkz1cVMw9m2SCPdg4YT4N+Is926rTPZTAgD06O2w+/zKFPeLc2j1RDX09yrZ5PgIufT3KwOE91n53Peo9gz725XA9R3PoPUrqcD17eYg+JrtlPeAM7z0PaWk90ayPPmqWWj3ID/U9iCJhPRallj4XLVA9gMP6PS9IWD3fMp4+szdGPXb9/z0FAk89X7CjPlpdPT1qogI+LH1FPXteqj5ctDQ9KfkEPiEjPD0WpbI+GyosPfzuBj5EGjM9GTG4PrKyJD00DAk+t8EqPZ38vj7XXB09VNQKPvOeIz2oJMc+aCUWPZA8DD428B09faDMPknVDz3/3w0+CAwaPY3m0j6asAk9DD4PPtSTGD2rdto+i54DPYE9ED7RjBk97eLfPl19/DzcdxE+ttccPUqN5T4xL/I8VocSPj2nIj2R0uo+toXoPPSLEz41yio9"

    // END GENERATED H18 R6

    func testNativeClothComputeReuse() throws { try runNativeClothCompute(animated: false) }
    func testNativeClothComputeAnimation() throws { try runNativeClothCompute(animated: true) }

    private func runNativeClothCompute(animated: Bool) throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("H17 requires the authorized native Mac")
        #else
        guard ProcessInfo.processInfo.isiOSAppOnMac else { throw XCTSkip("H17 native Mac only") }
        let device=try XCTUnwrap(MTLCreateSystemDefaultDevice())
        var rows=[[String:Any]](),complete=false
        defer { attachStrictReport(["study":"H17-current-production-compute", "animated":animated, "device":device.name,
            "completed":complete && testRun?.totalFailureCount==0, "rows":rows,
            "scope":"Current production full 3D scene, real ball geometry, same-command compute+render; no SwiftUI page/physical playback/phone claim",
            "timing":"Six AA/AB/DI groups, alternating ABBA/BAAB, twelve frames per arm; first-use captures/prepare separate; no trimmed samples"],name:"h17-current-scene.json") }
        for pose in animated ? ["near"]:["low","near","overview"] {
            try autoreleasepool {
                let scene=AngleTrainingScene(); scene.clothLTCRequested = false // Historical C1/H9 research baseline.

                scene.configureDailyClearanceRendering(asynchronousReflection:false)
                scene.setupScene(recipe:.liveReference,roomStyle:.tournament)
                try require(scene.applyClothColor(.green) && scene.applyTableStyle(.charcoal),"H17 appearance")
                scene.hideAllBalls()
                let keys=Array((["cueBall"]+(1...15).map{"_\($0)"}).prefix(pose=="overview" ? 16:2))
                let size=CGSize(width:1400,height:800),camera=try XCTUnwrap(scene.cameraNode)
                scene.cameraRig?.viewportSize=size
                scene.setCameraMode(.perspective3D,animated:false)
                let initialEye:SIMD3<Float> = pose=="near" ? SIMD3(0.16,1.15,0.3) : (pose=="low" ? SIMD3(0,1.05,1.8):SIMD3(1.8,2.7,2.1))
                @MainActor func cameraPose(_ eye:SIMD3<Float>)throws {
                    let delta=eye-SIMD3<Float>(0,scene.surfaceY,0)
                    let value=TwoViewCamera.Pose.looking(eye:eye,yaw:atan2(delta.z,delta.x),pitch:-atan2(delta.y,hypot(delta.x,delta.z)),fov:50)
                    camera.simdTransform=value.transform;camera.camera?.fieldOfView=50
                    try require(camera.camera?.usesOrthographicProjection==false,"H17 requires perspective projection; setupScene starts top-down")
                    try require(abs(camera.simdWorldTransform.columns.0.y)<0.00001 && simd_length(value.forward-simd_normalize(-delta))<0.00001,"H17 horizontal current camera")
                    SCNTransaction.flush()
                }
                try cameraPose(initialEye)
                @MainActor func updateBalls(_ frame:Int) {
                    SCNTransaction.begin();SCNTransaction.disableActions=true
                    for (i,key) in keys.enumerated() {
                        let x:Float=pose=="overview" ? Float(i/4)*0.6-0.9:Float(i)*0.05715
                        let z:Float=pose=="overview" ? Float(i%4)*0.3-0.45:0
                        scene.showBall(key:key,scenePosition:SCNVector3(x+Float(frame%3)*0.08,scene.surfaceY+AngleSceneCalculator.ballRadius+(frame==3 && i==0 ? 0.03:0),z))
                        if animated && frame==3 && i==0 {scene.allBallNodes[key]?.position.y += 0.03}
                        scene.allBallNodes[key]?.isHidden = frame==5 || (frame==4 && i==0)
                    }
                    SCNTransaction.commit();SCNTransaction.flush()
                }
                updateBalls(0)
                let animationProbe=H17AnimationProbe(contact:scene.contactOcclusion)
                let carrier=SCNNode();carrier.name="H17-moving-ball-parent"
                @MainActor func restartAction() {
                    carrier.removeAllActions();carrier.simdPosition = .zero
                    carrier.runAction(.customAction(duration:600) { node,elapsed in
                        animationProbe.actionStep(node,elapsed:Double(elapsed))
                    })
                    SCNTransaction.flush()
                }
                if animated {
                    scene.rootNode.addChildNode(carrier)
                    for key in keys {carrier.addChildNode(scene.allBallNodes[key]!)}
                    restartAction()
                }
                var cloth=[SCNMaterial](),seen=Set<ObjectIdentifier>(),solids=[SCNMaterial]()
                scene.rootNode.enumerateChildNodes { node,_ in
                    for m in node.geometry?.materials ?? [] where seen.insert(ObjectIdentifier(m)).inserted {
                        if m.name=="TaiNi" {cloth.append(m)}
                        if ["Wood","BlackWood","MG_Gold"].contains(m.name ?? "") {solids.append(m)}
                    }
                }
                try require(!cloth.isEmpty && !solids.isEmpty && solids.allSatisfy{!$0.isDoubleSided && $0.cullMode == .back},"H17 production cloth and H15 raster baseline")
                let target=try RenderTarget(device:device,scene:scene,size:size)
                if animated {target.renderer.delegate=animationProbe;target.researchTime=1}
                try require(target.renderer.prepare(scene,shouldAbortBlock:nil),"H17 prepare production scene")
                _=try target.render(frames:6)
                let cache=try H17Cache(device:device,materials:cloth,target:target)
                let roughness=cloth.map{$0.roughness.intensity}
                let attachment=XCTAttachment(string:cache.computeSource);attachment.name="h17-compute.metal";attachment.lifetime = .keepAlways;add(attachment)
                var preparations=[[String:Any]]()
                @MainActor func captureReceivers(_ epoch:String)throws {
                    target.beforeRender={try cache.encode($0,"clearReceivers")}
                    cache.install(cache.capture)
                    let hidden=keys.map{scene.allBallNodes[$0]!.isHidden}
                    for key in keys {scene.allBallNodes[key]!.isHidden=true}
                    SCNTransaction.flush()
                    let capture=try target.render(frames:epoch=="initial" ? 3:1,includeNativeTiming:true)
                    for (i,key) in keys.enumerated() {scene.allBallNodes[key]!.isHidden=hidden[i]}
                    SCNTransaction.flush()
                    try cache.inputs(scene,target.renderer)
                    let prepare=try cache.prepare(target)
                    preparations.append(["epoch":epoch,"captureFrames":capture.perFrameTiming,"prepare":prepare,"validPixels":cache.validPixels()])
                    try require(cache.validPixels()>0,"H17 missing real receiver inputs")
                }
                @MainActor func apply(_ variant:String?) {
                    target.updatesBeforeRender = animated && variant != nil
                    if let variant {
                        cache.install(cache.consumer)
                        target.beforeRender={ command in try cache.inputs(scene,target.renderer);try cache.encode(command,variant) }
                    } else { target.beforeRender=nil;cache.install(cache.baseline) }
                }
                try captureReceivers("initial")
                var quality=[[String:Any]](),maximum=0,aaMax=0,restoreMax=0
                for frame in 0..<8 {
                    if animated {target.researchTime=1+Double(frame)*0.11}
                    updateBalls(frame)
                    if frame==6 {try cameraPose(initialEye+SIMD3<Float>(0.05,0.02,0));try captureReceivers("camera")}
                    if frame==7 {
                        for (i,m) in cloth.enumerated(){m.roughness.intensity=roughness[i]*0.85}
                        SCNTransaction.flush();try captureReceivers("roughness")
                    }
                    apply(nil);_=try target.render(frames:3);let a=try target.readback()
                    _=try target.render(frames:1);let aa=try target.readback()
                    apply("reuse");_=animationProbe.take()
                    let first=try target.render(frames:1,includeNativeTiming:true);let b=try target.readback()
                    let callbacks=animationProbe.take()
                    var maximumBallDelta:Float=0
                    if animated {
                        try require(callbacks["update"]==1 && callbacks["animations"]==1,"H17 exactly one animation update per consumed frame")
                        let bytes=Data(bytes:cache.balls.contents(),count:256)
                        let production=try XCTUnwrap(cloth.first?.value(forKey:"contactUniforms") as? NSData)
                        try require(bytes==(production as Data),"H17 Compute and final render must use the same uniform version")
                        for (slot,item) in scene.allBallNodes.sorted(by:{$0.key<$1.key}).enumerated() {
                            let value=bytes.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:slot*16,as:SIMD4<Float>.self)}
                            let position=item.value.presentation.simdWorldPosition
                            maximumBallDelta=max(maximumBallDelta,abs(value.x-position.x),abs(value.y-position.z),abs(value.z-max(AngleSceneCalculator.ballRadius,position.y-scene.surfaceY)))
                        }
                        try require(maximumBallDelta<0.000001,"H17 final presentation center mismatch")
                    }
                    apply(nil);_=try target.render(frames:3);let restored=try target.readback()
                    let delta=difference(a,b),noise=difference(a,aa),rest=difference(a,restored)
                    maximum=max(maximum,delta.maximum);aaMax=max(aaMax,noise.maximum);restoreMax=max(restoreMax,rest.maximum)
                    quality.append(["frame":frame,"maximumChannelDifference":delta.maximum,"changedPixels":delta.changedPixels,
                        "aaMaximum":noise.maximum,"restoreMaximum":rest.maximum,"firstConsumeFrame":first.perFrameTiming,
                        "callbacks":callbacks,"maximumBallCenterDelta":maximumBallDelta,
                        "carrierPresentationY":carrier.presentation.position.y])
                    attach(a,"h17-\(pose)-\(frame)-baseline");attach(b,"h17-\(pose)-\(frame)-reuse")
                }
                for (i,m) in cloth.enumerated(){m.roughness.intensity=roughness[i]}
                try cameraPose(initialEye);updateBalls(0);try captureReceivers("restore")
                apply(nil);_=try target.render(frames:3);let controlA=try target.readback()
                apply("reuse")
                cache.install(cache.consumer.replacingOccurrences(of:"E=reuseE.xyz;S=reuseSpecular.read(uint2(reusePixel)).xyz;",with:"E=reuseE.xyz;S=float3(2,0,0);"))
                _=try target.render(frames:3);let controlB=try target.readback(),positive=difference(controlA,controlB)
                attach(controlB,"h17-\(pose)-positive-control")
                try require(positive.maximum>8 && positive.changedPixels>100,"H17 real consumer positive control")
                var times=[[String:Any]](),epochTime:TimeInterval=20
                if maximum<=1 && aaMax==0 && restoreMax==0 {
                    for kind in ["AA","AB","DI"] {for cycle in 0..<6 {
                        for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
                            if animated {epochTime += 1;target.researchTime=epochTime;restartAction()}
                            apply(kind=="DI" ? (arm ? "reuse":"direct"):(kind=="AB" && arm ? "reuse":nil))
                            _=try target.render(frames:6)
                            var frames=[[String:Any]]()
                            for frame in 0..<12 {
                                if animated {target.researchTime=epochTime+Double(frame+1)/60}
                                updateBalls(frame%6);frames += try target.render(frames:1,includeNativeTiming:true).perFrameTiming
                            }
                            times.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","frames":frames])
                        }
                    }}
                }
                apply(nil)
                rows.append(["pose":pose,"allocatedBytes":cache.allocatedBytes,"capturedPixels":cache.validPixels(),
                    "maximumChannelDifference":maximum,"aaMaximum":aaMax,"restoreMaximum":restoreMax,
                    "quality":quality,"preparations":preparations,"positiveControlMaximum":positive.maximum,
                    "positiveControlPixels":positive.changedPixels,"times":times,
                    "cameraTransform":matrixValues(camera.transform),"clothMaterials":cloth.count,"activeBallCapacity":keys.count])
                print("[H17] \(pose) max=\(maximum) AA=\(aaMax) restore=\(restoreMax) arms=\(times.count)")
                target.beforeRender=nil;carrier.removeAllActions()
            }
        }
        complete=true
        #endif
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
                let scene = AngleTrainingScene(); scene.clothLTCRequested = false // Historical C1/H9 research baseline.

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
            let scene = AngleTrainingScene(); scene.clothLTCRequested = false // Historical C1/H9 research baseline.
            ; releasedScene = scene
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
            let scene = AngleTrainingScene(); scene.clothLTCRequested = false // Historical C1/H9 research baseline.

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
            let independent = AngleTrainingScene(); independent.clothLTCRequested = false // Historical C1/H9 research baseline.

            independent.configureReferenceTableRendering(); independent.setupScene(recipe: .liveReference, roomStyle: .tournament)
            try check(independent, culled: true)
            let firstMaterials = Set(solids(scene).map(ObjectIdentifier.init))
            try require(firstMaterials.isDisjoint(with: solids(independent).map(ObjectIdentifier.init)), "H15 live scenes share mutable material containers")
            let first = try XCTUnwrap(solids(scene).first)
            first.isDoubleSided = true; defer { first.isDoubleSided = false }
            try check(independent, culled: true)
            let legacy = AngleTrainingScene(); legacy.clothLTCRequested = false // Historical C1/H9 research baseline.

            legacy.setupScene(enhancedRendering: false, mobileRendering: false, roomStyle: .tournament)
            try check(legacy, culled: false)
            let legacyMobile = AngleTrainingScene(); legacyMobile.clothLTCRequested = false // Historical C1/H9 research baseline.

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
                let scene = AngleTrainingScene(); scene.clothLTCRequested = false // Historical C1/H9 research baseline.

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
        let scene = AngleTrainingScene(); scene.clothLTCRequested = false // Historical C1/H9 research baseline.

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
            let scene = AngleTrainingScene(); scene.clothLTCRequested = false // Historical C1/H9 research baseline.

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
        let donor = AngleTrainingScene(); donor.clothLTCRequested = false // Historical C1/H9 research baseline.

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

    #if DEBUG
    private final class H17AnimationProbe: NSObject, SCNSceneRendererDelegate, @unchecked Sendable {
        let contact: MobileContactOcclusion?
        private let lock=NSLock()
        private var counters=[String:Int]()
        init(contact:MobileContactOcclusion?) {self.contact=contact;super.init()}
        private func count(_ key:String) {lock.lock();counters[key,default:0]+=1;lock.unlock()}
        func take()->[String:Int] {lock.lock();defer{lock.unlock()};let result=counters;counters.removeAll();return result}
        func actionStep(_ node:SCNNode,elapsed:Double) {
            count("action")
            node.simdPosition=SIMD3<Float>(Float(sin(elapsed*5))*0.14,Float(1-cos(elapsed*4))*0.018,Float(sin(elapsed*3))*0.04)
        }
        func renderer(_ renderer:SCNSceneRenderer,updateAtTime time:TimeInterval) {count("update")}
        func renderer(_ renderer:SCNSceneRenderer,didApplyAnimationsAtTime time:TimeInterval) {
            count("animations");contact?.renderer(renderer,didApplyAnimationsAtTime:time)
        }
        func renderer(_ renderer:SCNSceneRenderer,didApplyConstraintsAtTime time:TimeInterval) {count("constraints")}
        func renderer(_ renderer:SCNSceneRenderer,willRenderScene scene:SCNScene,atTime time:TimeInterval) {count("willRender")}
        func renderer(_ renderer:SCNSceneRenderer,didRenderScene scene:SCNScene,atTime time:TimeInterval) {count("didRender")}
    }

    /// H17 research only. No App runtime or material default references this type.
    @MainActor private final class H17Cache {
        let device: MTLDevice
        let materials: [SCNMaterial]
        let baseline: String, consumer: String, capture: String, computeSource: String
        let textures: [MTLTexture], fields: [MTLTexture], balls: MTLBuffer
        var pipelines: [String: MTLComputePipelineState] = [:]
        var camera = SIMD4<Float>(repeating: 0)
        let side = 384
        init(device: MTLDevice, materials: [SCNMaterial], target: RenderTarget) throws {
            self.device=device; self.materials=materials
            let baseline=try XCTUnwrap(materials.first?.shaderModifiers?[.surface])
            try Self.need(ClothResearchShaders.sha256(baseline)=="14a880284fffc793f01d0357b0a625559101609d7986c9ac0cac72e7085efa4f", "H17 current production C1/H9 identity")
            try Self.need(materials.allSatisfy{$0.shaderModifiers?[.surface]==baseline}, "H17 shared cloth identity")
            self.baseline=baseline
            fields=try ["temporalField0","temporalField1"].map { name in
                let property=try XCTUnwrap(materials.first?.value(forKey:name) as? SCNMaterialProperty)
                return try XCTUnwrap(property.contents as? MTLTexture)
            }
            let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:side,height:side,mipmapped:false)
            d.usage=[.shaderRead,.shaderWrite];d.storageMode = .shared
            textures=try (0..<5).map { i in
                let t=try XCTUnwrap(device.makeTexture(descriptor:d));t.label="H17-\(i)";return t
            }
            balls=try XCTUnwrap(device.makeBuffer(length:256,options:.storageModeShared))
            @MainActor func once(_ source:String,_ old:String,_ new:String)throws->String {
                try Self.need(source.components(separatedBy:old).count==2,"H17 unique shader anchor")
                return source.replacingOccurrences(of:old,with:new)
            }
            let brdfStart=try XCTUnwrap(baseline.range(of:"float nl=max(0.001,dot(n,l));",options:.backwards),"BRDF")
            let weightStart=try XCTUnwrap(baseline.range(of:"float3 weighted=",range:brdfStart.upperBound..<baseline.endIndex),"Weight")
            let weightEnd=try XCTUnwrap(baseline.range(of:"unoccludedE+=weighted; E+=weighted*visibility;",range:weightStart.lowerBound..<baseline.endIndex),"Accumulate")
            let brdf=String(baseline[brdfStart.lowerBound..<weightStart.lowerBound])
            let weight=String(baseline[weightStart.lowerBound..<weightEnd.lowerBound])
            let accumulation="S+=weighted*visibility*D*G*F/(4.0*nv*nl);"
            let coreStart=try XCTUnwrap(baseline.range(of:"bool shadowPossible=false;"),"Core start")
            let coreEnd=try XCTUnwrap(baseline.range(of:"// v64ClothNap:"),"Core end")
            let core=String(baseline[coreStart.lowerBound..<coreEnd.lowerBound])
            let declarations=String(baseline[..<baseline.range(of:"#pragma body")!.lowerBound])
             .components(separatedBy:"\n").filter { !$0.hasPrefix("#pragma") && !$0.hasPrefix("texture") && $0 != "QiuJiContactUniforms contactUniforms;" }.joined(separator:"\n")
            let commonInputs="""
            float4 q=receiverPosition.read(id),nr=receiverNormal.read(id);
            if(q.w==0.0){resultDiffuse.write(float4(0),id);resultSpecular.write(float4(0),id);return;}
            float3 p=q.xyz,n=nr.xyz,v=normalize(camera.xyz-p);
            float nv=max(0.001,dot(n,v));float alpha=max(0.01,nr.w*nr.w);float a2=alpha*alpha;
            float3 E=0.0,unoccludedE=0.0,S=0.0;
            \((0..<16).map{"float4 contactBall\($0)=contactUniforms.contactBalls[\($0)];"}.joined(separator:"\n"))
            """
            let signature="""
            texture2d<float,access::read> receiverPosition [[texture(0)]],
            texture2d<float,access::read> receiverNormal [[texture(1)]],
            texture2d<float,access::read> staticSpecular [[texture(2)]],
            texture2d<float,access::write> resultDiffuse [[texture(3)]],
            texture2d<float,access::write> resultSpecular [[texture(4)]],
            texture3d<float> temporalField0 [[texture(5)]],texture3d<float> temporalField1 [[texture(6)]],
            constant QiuJiContactUniforms &contactUniforms [[buffer(0)]],constant float4 &camera [[buffer(1)]],
            uint2 id [[thread_position_in_grid]]
            """
            var separated=try once(core,brdf,"")
            separated=try once(separated,accumulation,"""
            if(!shadowPossible || visibility<1.0) {
             \(brdf)
             S+=weighted*(shadowPossible ? visibility-1.0:visibility)*D*G*F/(4.0*nv*nl);
            }
            """)
            let finalLoop=try XCTUnwrap(separated.range(of:"for(int panel=0;panel<2;++panel) {",options:.backwards),"Final panel loop")
            separated.insert(contentsOf:"if(shadowPossible) S=staticSpecular.read(id).rgb;\n",at:finalLoop.lowerBound)
            let prepare="""
            kernel void prepareSpecular(texture2d<float,access::read> receiverPosition [[texture(0)]],
             texture2d<float,access::read> receiverNormal [[texture(1)]],texture2d<float,access::write> result [[texture(2)]],
             constant float4 &camera [[buffer(0)]],uint2 id [[thread_position_in_grid]]) {
             if(any(id>=uint2(result.get_width(),result.get_height())))return;
             float4 q=receiverPosition.read(id),nr=receiverNormal.read(id);
             if(q.w==0.0){result.write(float4(0),id);return;}
             float3 p=q.xyz,n=nr.xyz,v=normalize(camera.xyz-p),S=0.0;
             float nv=max(0.001,dot(n,v));float alpha=max(0.01,nr.w*nr.w);float a2=alpha*alpha;
             for(int panel=0;panel<2;++panel){
              float cellArea=v62EmitterArea(panel)/32.0;
              for(int ix=0;ix<8;++ix)for(int iz=0;iz<4;++iz){
               float3 lp=v62EmitterCenter(panel)+v62EmitterU(panel)*(2.0*(float(ix)+0.5)/8.0-1.0)+v62EmitterV(panel)*(2.0*(float(iz)+0.5)/4.0-1.0);
               float3 delta=lp-p;float r2=dot(delta,delta);float3 l=delta/sqrt(r2);
               \(brdf)
               \(weight)
               S+=weighted*D*G*F/(4.0*nv*nl);
              }
             }
             result.write(float4(S,1),id);
            }
            """
            let clearKernel="""
            kernel void clearReceivers(texture2d<float,access::write> positions [[texture(0)]],texture2d<float,access::write> normals [[texture(1)]],uint2 id [[thread_position_in_grid]]) {
             if(any(id>=uint2(positions.get_width(),positions.get_height())))return;
             positions.write(float4(0),id);normals.write(float4(0),id);
            }
            """
            let computeSource="#include <metal_stdlib>\nusing namespace metal;\n"+declarations+"\n"+prepare+clearKernel+[ ("direct",core),("reuse",separated) ].map { name,body in
             """
             kernel void \(name)(\(signature)) {
              if(any(id>=uint2(receiverPosition.get_width(),receiverPosition.get_height())))return;
              \(commonInputs)
              \(body)
              resultDiffuse.write(float4(E,1),id);resultSpecular.write(float4(S,1),id);
             }
             """
            }.joined(separator:"\n")
            self.computeSource=computeSource
            let library=try device.makeLibrary(source:computeSource,options:nil)

            for name in ["prepareSpecular","direct","reuse","clearReceivers"] {pipelines[name]=try device.makeComputePipelineState(function:XCTUnwrap(library.makeFunction(name:name),name))}
            let project="""
            float4 reuseClip=scn_frame.projectionTransform*float4(_surface.position,1.0);
            float2 reuseScreen=(reuseClip.xy/reuseClip.w*float2(0.5,-0.5)+0.5)*reuseViewport.xy;
            int2 reusePixel=int2(floor(reuseScreen))-int2(reuseViewport.zw);
            float3 reuseGeometryNormal=normalize((scn_frame.inverseViewTransform*float4(_surface.geometryNormal,0.0)).xyz);
            bool reuseInside=all(reusePixel>=int2(0)) && all(reusePixel<int2(\(384),\(384))) && abs(p.y-0.8)<0.00001 && reuseGeometryNormal.y>0.99999;
            """
            let arguments="""
            #pragma arguments
            texture2d<float> reuseDiffuse;
            texture2d<float> reuseSpecular;
            float4 reuseViewport;
            """
            let consumerBody="""
            \(project)
            float4 reuseE=reuseInside ? reuseDiffuse.read(uint2(reusePixel)):float4(0);
            if(reuseE.w==1.0){E=reuseE.xyz;S=reuseSpecular.read(uint2(reusePixel)).xyz;}
            else {\(core)}
            """
            let consumer=try once(try once(baseline,"#pragma body",arguments+"\n#pragma body"),core,consumerBody)
            let capture="""
            #pragma arguments
            texture2d<float,access::write> reusePositionOut;
            texture2d<float,access::write> reuseNormalOut;
            float4 reuseViewport;
            #pragma body
            float3 p=(scn_frame.inverseViewTransform*float4(_surface.position,1.0)).xyz;
            \(project)
            if(reuseInside){
             reusePositionOut.write(float4(p,1),uint2(reusePixel));
             float3 n=normalize((scn_frame.inverseViewTransform*float4(_surface.normal,0.0)).xyz);
             reuseNormalOut.write(float4(n,_surface.roughness),uint2(reusePixel));
            }
            _surface.emission.rgb=float3(0);_surface.diffuse.rgb=float3(0);_surface.metalness=1.0;
            """
            self.consumer=consumer; self.capture=capture
            let zero=Data(repeating:0,count:side*side*16)
            for t in textures {zero.withUnsafeBytes{t.replace(region:MTLRegionMake2D(0,0,side,side),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:side*16)}}
            for m in materials {
                for (name,index) in [("reusePositionOut",0),("reuseNormalOut",1),("reuseDiffuse",3),("reuseSpecular",4)] {
                    m.setValue(SCNMaterialProperty(contents:textures[index]),forKey:name)
                }
                m.setValue(NSValue(scnVector4:SCNVector4(Float(target.width),Float(target.height),Float((target.width-side)/2),Float((target.height-side)/2))),forKey:"reuseViewport")
            }
            try Self.need(allocatedBytes<=16*1024*1024,"H17 resource budget")
        }
        var allocatedBytes:Int {textures.reduce(0){$0+$1.allocatedSize}+balls.allocatedSize}
        func install(_ source:String) {
            for m in materials {var mods=m.shaderModifiers ?? [:];mods[.surface]=source;m.shaderModifiers=mods}
            SCNTransaction.flush()
        }
        func inputs(_ scene:AngleTrainingScene,_ renderer:SCNRenderer)throws {
            // The compute pass precedes SCNRenderer.render. Refresh through the
            // production callback before copying its ABI, not from the prior frame.
            scene.contactOcclusion?.renderer(renderer,didApplyAnimationsAtTime:1)
            let data=try XCTUnwrap(materials.first?.value(forKey:"contactUniforms") as? NSData)
            try Self.need(data.length==256,"H17 actual production uniform ABI")
            memcpy(balls.contents(),data.bytes,256)
            camera=SIMD4(try XCTUnwrap(scene.cameraNode).simdWorldPosition,1)
        }
        func encode(_ command:MTLCommandBuffer,_ name:String)throws {
            let e=try XCTUnwrap(command.makeComputeCommandEncoder());e.label="H17 \(name)"
            e.setComputePipelineState(pipelines[name]!)
            for i in 0..<3 {e.setTexture(textures[i],index:i)}
            if name=="clearReceivers" {} else if name=="prepareSpecular" {e.setBytes(&camera,length:16,index:0)}
            else {
                e.setTexture(textures[3],index:3);e.setTexture(textures[4],index:4)
                e.setTexture(fields[0],index:5);e.setTexture(fields[1],index:6)
                e.setBuffer(balls,offset:0,index:0);e.setBytes(&camera,length:16,index:1)
            }
            e.dispatchThreads(MTLSize(width:side,height:side,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1));e.endEncoding()
        }
        func prepare(_ target:RenderTarget)throws->[String:Double] {
            let start=CACurrentMediaTime(),command=try XCTUnwrap(target.queue.makeCommandBuffer())
            try encode(command,"prepareSpecular");let encoded=CACurrentMediaTime()
            command.commit();command.waitUntilCompleted()
            try Self.need(command.status == .completed,"H17 preparation failed")
            return ["gpuMS":(command.gpuEndTime-command.gpuStartTime)*1000,"cpuEncodeMS":(encoded-start)*1000,"wallMS":(CACurrentMediaTime()-start)*1000]
        }
        func validPixels()->Int {
            var values=[Float](repeating:0,count:side*side*4)
            values.withUnsafeMutableBytes{textures[0].getBytes($0.baseAddress!,bytesPerRow:side*16,from:MTLRegionMake2D(0,0,side,side),mipmapLevel:0)}
            return (0..<side*side).filter{values[4*$0+3]==1}.count
        }
        private static func need(_ value:Bool,_ text:String)throws {
            if !value {throw NSError(domain:"H17",code:1,userInfo:[NSLocalizedDescriptionKey:text])}
        }
    }
    #endif

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
        var beforeRender: ((MTLCommandBuffer) throws -> Void)?
        var updatesBeforeRender = false
        var researchTime: TimeInterval?
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
                let time=researchTime ?? atTime
                if updatesBeforeRender {renderer.update(atTime:time)}
                try beforeRender?(command)
                if updatesBeforeRender {
                    renderer.render(withViewport:CGRect(x:0,y:0,width:width,height:height),commandBuffer:command,passDescriptor:pass)
                } else {
                    renderer.render(atTime:time,viewport:CGRect(x:0,y:0,width:width,height:height),commandBuffer:command,passDescriptor:pass)
                }
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
