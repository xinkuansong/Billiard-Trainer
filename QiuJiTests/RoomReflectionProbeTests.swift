import XCTest
import SceneKit
import Metal
@testable import QiuJi

/// Ball reflection probe (room-baked environment) — deterministic checks plus
/// optional evidence renders (`TEST_RUNNER_V62_SHOT_DIR`).
@MainActor
final class RoomReflectionProbeTests: XCTestCase {
    private var shotDirectory: URL? {
        guard let path = ProcessInfo.processInfo.environment["V62_SHOT_DIR"], path != "device" else { return nil }
        return URL(fileURLWithPath: path)
    }

    private func scene(style: RoomStyle = .tournament) throws -> AngleTrainingScene {
        let scene = AngleTrainingScene()
        scene.setupScene(mobileRendering: true)
        scene.installReferenceRoom(style: style)
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        scene.applyBallLayout(cueBallPosition: SCNVector3(-0.45, y, 0), targetBallNumber: 13,
                              targetPosition: SCNVector3(0.35, y, 0.12))
        scene.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)))
        scene.setCameraMode(.perspective3D, animated: false)
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.enterAiming(cueBallPosition: SCNVector3(-0.45, y, 0), targetDirection: SCNVector3(0.8, 0, 0.12))
        for _ in 0..<120 { rig.update(deltaTime: 1 / 60) }
        return scene
    }

    private func capture(_ scene: AngleTrainingScene, name: String, pointOfView: SCNNode? = nil) throws {
        guard let shotDirectory else { return }
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene
        renderer.pointOfView = pointOfView ?? scene.cameraNode
        renderer.delegate = scene.contactOcclusion
        renderer.autoenablesDefaultLighting = false
        let size = CGSize(width: 1176, height: 2000)
        _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        let shot = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        let dest = shotDirectory.appendingPathComponent(name + ".png")
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try XCTUnwrap(shot.pngData()).write(to: dest)
    }

    // MARK: - Mapping

    func testEquirectMappingRoundTrip() {
        let samples: [SIMD3<Float>] = [
            SIMD3(1, 0, 0), SIMD3(-1, 0, 0), SIMD3(0, 0, 1), SIMD3(0, 0, -1),
            simd_normalize(SIMD3(0.3, 0.8, -0.5)), simd_normalize(SIMD3(-0.6, -0.2, 0.7))
        ]
        for d in samples {
            let uv = RoomReflectionProbe.uv(for: d)
            XCTAssert((0...1).contains(uv.x) && (0...1).contains(uv.y), "uv out of range for \(d)")
            let back = RoomReflectionProbe.direction(u: uv.x, v: uv.y)
            XCTAssertLessThan(simd_length(back - d), 1e-4, "round trip failed for \(d)")
        }
        // Convention anchors shared with the Metal side: -Z is the seam-free centre, +Y is the top row.
        XCTAssertEqual(RoomReflectionProbe.uv(for: SIMD3(0, 0, -1)).x, 0.5, accuracy: 1e-5)
        XCTAssertEqual(RoomReflectionProbe.uv(for: SIMD3(0, 1, 0)).y, 0, accuracy: 1e-5)
    }

    func testFaceProjectionPlacesSolidColours() {
        let size = 8
        let colours: [SIMD3<Float>] = [
            SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1), SIMD3(1, 1, 0), SIMD3(0, 1, 1), SIMD3(1, 0, 1)
        ]
        let faces = zip(RoomReflectionProbe.faceBases, colours).map { basis, colour in
            RoomReflectionProbe.Face(forward: basis.forward, up: basis.up, size: size,
                                     linear: Array(repeating: colour, count: size * size))
        }
        let width = 64, height = 32
        let map = RoomReflectionProbe.equirect(faces: faces, width: width, height: height)
        func sample(_ d: SIMD3<Float>) -> SIMD3<Float> {
            let uv = RoomReflectionProbe.uv(for: d)
            let x = min(width - 1, Int(uv.x * Float(width)))
            let y = min(height - 1, Int(uv.y * Float(height)))
            return map[y * width + x]
        }
        XCTAssertEqual(sample(SIMD3(1, 0, 0)), colours[0])
        XCTAssertEqual(sample(SIMD3(-1, 0, 0)), colours[1])
        XCTAssertEqual(sample(SIMD3(0, 1, 0)), colours[2])
        XCTAssertEqual(sample(SIMD3(0, -1, 0)), colours[3])
        XCTAssertEqual(sample(SIMD3(0, 0, 1)), colours[4])
        XCTAssertEqual(sample(SIMD3(0, 0, -1)), colours[5])
    }

    func testFaceProjectionRespectsScreenOrientation() {
        // +X face with a bright top-left quadrant. SceneKit camera space is -Z forward /
        // +X right / +Y up, so world right = cross(forward, up) = cross(+X,+Y) = +Z and left = -Z.
        let size = 16
        var pixels = [SIMD3<Float>](repeating: .zero, count: size * size)
        for y in 0..<(size / 2) { for x in 0..<(size / 2) { pixels[y * size + x] = SIMD3(1, 1, 1) } }
        var faces = RoomReflectionProbe.faceBases.map {
            RoomReflectionProbe.Face(forward: $0.forward, up: $0.up, size: size,
                                     linear: Array(repeating: .zero, count: size * size))
        }
        faces[0] = RoomReflectionProbe.Face(forward: SIMD3(1, 0, 0), up: SIMD3(0, 1, 0), size: size, linear: pixels)
        let width = 128, height = 64
        let map = RoomReflectionProbe.equirect(faces: faces, width: width, height: height)
        func sample(_ d: SIMD3<Float>) -> Float {
            let uv = RoomReflectionProbe.uv(for: simd_normalize(d))
            return map[min(height - 1, Int(uv.y * Float(height))) * width + min(width - 1, Int(uv.x * Float(width)))].x
        }
        XCTAssertEqual(sample(SIMD3(1, 0.4, -0.4)), 1, "up-left of +X should be lit")
        XCTAssertEqual(sample(SIMD3(1, -0.4, -0.4)), 0, "down-left should be dark")
        XCTAssertEqual(sample(SIMD3(1, 0.4, 0.4)), 0, "up-right should be dark")
    }

    // MARK: - SH irradiance

    func testUniformHemisphereIrradiance() {
        let width = 128, height = 64
        let radiance: Float = 0.4
        let map = [SIMD3<Float>](repeating: SIMD3(repeating: radiance), count: width * height)
        let sh = RoomReflectionProbe.irradianceSH(equirect: map, width: width, height: height)
        // Full hemisphere seen by an upward normal: E/π == L.
        let up = RoomReflectionProbe.irradianceOverPi(sh, normal: SIMD3(0, 1, 0))
        XCTAssertEqual(up.x, radiance, accuracy: radiance * 0.05)
        // Sideways normal sees half of the lit hemisphere: E/π == L/2.
        let side = RoomReflectionProbe.irradianceOverPi(sh, normal: SIMD3(1, 0, 0))
        XCTAssertEqual(side.x, radiance / 2, accuracy: radiance * 0.06)
        // Downward normal sees only the (excluded) cloth hemisphere.
        let down = RoomReflectionProbe.irradianceOverPi(sh, normal: SIMD3(0, -1, 0))
        XCTAssertLessThan(down.x, radiance * 0.12)
        // Full sphere control: uniform everywhere ⇒ E/π == L for any normal.
        let full = RoomReflectionProbe.irradianceSH(equirect: map, width: width, height: height, upperHemisphereOnly: false)
        XCTAssertEqual(RoomReflectionProbe.irradianceOverPi(full, normal: simd_normalize(SIMD3(1, -1, 0.5))).y,
                       radiance, accuracy: radiance * 0.02)
    }

    func testHalfEncoding() {
        XCTAssertEqual(RoomReflectionProbe.half(0), 0)
        XCTAssertEqual(RoomReflectionProbe.half(1), 0x3C00)
        XCTAssertEqual(RoomReflectionProbe.half(-2), 0xC000)
        XCTAssertEqual(RoomReflectionProbe.half(0.5), 0x3800)
        XCTAssertEqual(RoomReflectionProbe.half(65504), 0x7BFF)
        XCTAssertEqual(RoomReflectionProbe.half(1e6), 0x7C00)
        // Subnormal: 2^-24 is the smallest half.
        XCTAssertEqual(RoomReflectionProbe.half(Float(pow(2.0, -24))), 0x0001)
    }

    // MARK: - Scene integration

    func testSceneBakesProbeAndBindsBallMaterials() throws {
        try XCTSkipUnless(MTLCreateSystemDefaultDevice() != nil, "Metal device required")
        RoomReflectionProbe.resetCache()
        let s = try scene(style: .walnut)
        let probe = try XCTUnwrap(s.roomReflectionProbe)
        XCTAssertEqual(probe.style, .walnut)
        XCTAssertEqual(probe.texture.width, RoomReflectionProbe.width)
        XCTAssertEqual(probe.texture.mipmapLevelCount, 10)
        // The room has real content: the map is neither black nor flat.
        let up = RoomReflectionProbe.irradianceOverPi(probe.irradianceSH, normal: SIMD3(0, 1, 0))
        XCTAssertGreaterThan(up.x + up.y + up.z, 0.01, "room irradiance should not be black")
        XCTAssertLessThan(up.x + up.y + up.z, 3, "room irradiance should stay within room brightness")
        // Floor under the table is a dark carpet: present, darker than the room above, not cloth-coloured.
        let floor = probe.floorRadiance
        XCTAssertGreaterThan(floor.x + floor.y + floor.z, 0.003, "floor radiance should not be black")
        XCTAssertLessThan(floor.x + floor.y + floor.z, up.x + up.y + up.z, "floor should be darker than the lit room")
        let clothG = ClothColor.green.linearAlbedo
        XCTAssertLessThan(floor.y / max(0.0001, floor.x + floor.y + floor.z), Float(clothG.y) / (clothG.x + clothG.y + clothG.z) * 0.8,
                          "floor must not carry the cloth's green dominance")
        // Every ball material carries the probe binding.
        var bound = 0, shaded = 0
        for node in s.allBallNodes.values {
            node.enumerateHierarchy { n, _ in
                for m in n.geometry?.materials ?? [] where m.shaderModifiers?[.surface]?.contains("roomReflection") == true {
                    shaded += 1
                    if (m.value(forKey: "roomReflection") as? SCNMaterialProperty) === probe.property,
                       m.value(forKey: "roomSH8") != nil, m.value(forKey: "roomFloor") != nil { bound += 1 }
                }
            }
        }
        XCTAssertGreaterThan(shaded, 0)
        XCTAssertEqual(bound, shaded)
        // Bake left visibility as it was.
        XCTAssertFalse(s.rootNode.childNode(withName: "reference_room", recursively: false)!.isHidden)
        XCTAssertNil(s.rootNode.childNode(withName: "roomReflectionProbeCamera", recursively: false))
        // Switching style swaps the binding on the same balls.
        s.installReferenceRoom(style: .eastern)
        let second = try XCTUnwrap(s.roomReflectionProbe)
        XCTAssertEqual(second.style, .eastern)
        XCTAssertFalse(second === probe)
        for node in s.allBallNodes.values {
            node.enumerateHierarchy { n, _ in
                for m in n.geometry?.materials ?? [] where m.shaderModifiers?[.surface]?.contains("roomReflection") == true {
                    XCTAssertTrue((m.value(forKey: "roomReflection") as? SCNMaterialProperty) === second.property)
                }
            }
        }
    }

    // MARK: - Evidence renders

    func testBallReflectionEvidence() throws {
        try XCTSkipUnless(shotDirectory != nil, "Explicit evidence run required")
        for style in RoomStyle.allCases {
            let s = try scene(style: style)
            try capture(s, name: "\(style.rawValue)-aiming")
            // Close-up on the two balls; camera placed directly so the rig cannot pull back.
            let y = s.surfaceY + AngleSceneCalculator.ballRadius
            let closeup = SCNNode()
            closeup.camera = s.cameraNode.camera?.copy() as? SCNCamera
            closeup.camera?.fieldOfView = 40
            closeup.position = SCNVector3(0.20, y + 0.07, 0.36)
            closeup.look(at: SCNVector3(0.35, y - 0.01, 0.12))
            s.rootNode.addChildNode(closeup)
            try capture(s, name: "\(style.rawValue)-closeup", pointOfView: closeup)
            closeup.position = SCNVector3(-0.60, y + 0.07, 0.24)
            closeup.look(at: SCNVector3(-0.45, y - 0.01, 0))
            try capture(s, name: "\(style.rawValue)-cueball", pointOfView: closeup)
            // Ball resting below the table plane at return-rail height (DR-303): the
            // cloth bounce / cloth reflection must be gone, replaced by the floor.
            if let ball = s.allBallNodes["_13"] {
                let railY = s.surfaceY - 0.25
                ball.position = SCNVector3(1.45, railY, 0.55)
                closeup.position = SCNVector3(1.30, railY + 0.06, 0.80)
                closeup.look(at: SCNVector3(1.45, railY, 0.55))
                try capture(s, name: "\(style.rawValue)-rail-ball", pointOfView: closeup)
            }
            closeup.removeFromParentNode()
        }
    }
}
