import XCTest
import SceneKit
import simd
@testable import QiuJi

@MainActor
final class AngleDynamicAssistTests: XCTestCase {
    private func defaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: "AngleDynamicAssistTests.\(UUID().uuidString)"))
    }

    func testAllCombinationsPreserveRingBallsAndMetricsInBothViews() throws {
        let vm = AngleDynamicViewModel(displayDefaults: try defaults())
        vm.setupScene()
        let ring = try XCTUnwrap(vm.scene.ghostBallNode)
        let children = ring.childNodes
        let geometries = children.map { $0.geometry }
        let colors = children.map { $0.geometry?.firstMaterial?.diffuse.contents as? UIColor }
        let hidden = children.map(\.isHidden)
        let angle = vm.cutAngleDegrees, pocket = vm.selectedPocketIndex
        let balls = vm.scene.allBallNodes.mapValues { $0.simdPosition }
        let root = try XCTUnwrap(vm.scene.rootNode.childNode(withName: "angleDynamic.assists", recursively: false))
        for mode in [AngleTrainingScene.CameraMode.topDown2D, .perspective3D] {
            vm.setCameraMode(mode)
            for mask in 0..<8 {
                vm.showsGhost3D = mask & 1 != 0
                vm.showsAimPipe = mask & 2 != 0
                vm.showsPotPipe = mask & 4 != 0
                vm.updateCalculations()
                XCTAssertEqual(root.isHidden, mask == 0)
                for (name, bit) in [("ghost3D", 1), ("aimPipe", 2), ("potPipe", 4)] where mask != 0 {
                    let group = try XCTUnwrap(root.childNode(withName: "angleDynamic." + name, recursively: false))
                    XCTAssertEqual(group.isHidden, mask & bit == 0)
                    if mask & bit != 0 { XCTAssertFalse(group.childNodes.isEmpty) }
                }
                XCTAssertFalse(ring.isHidden)
                XCTAssertEqual(ring.childNodes, children)
                for i in children.indices {
                    XCTAssertTrue(children[i].geometry === geometries[i])
                    XCTAssertEqual(children[i].geometry?.firstMaterial?.diffuse.contents as? UIColor, colors[i])
                    XCTAssertEqual(children[i].isHidden, hidden[i])
                }
                XCTAssertEqual(vm.cutAngleDegrees, angle)
                XCTAssertEqual(vm.selectedPocketIndex, pocket)
                XCTAssertEqual(vm.scene.allBallNodes.mapValues { $0.simdPosition }, balls)
            }
        }
        XCTAssertEqual(root.childNodes.count, 3)
        XCTAssertEqual(root.childNode(withName: "angleDynamic.aimPipe", recursively: false)?.childNodes.count, 3)
        XCTAssertEqual(root.childNode(withName: "angleDynamic.potPipe", recursively: false)?.childNodes.count, 3)
        let unrelated = AngleTrainingScene()
        unrelated.setupVisualizationNodes()
        XCTAssertNil(unrelated.rootNode.childNode(withName: "angleDynamic.assists", recursively: true))
    }

    func testUpdatesInvalidationAndTemporaryViewClone() throws {
        let vm = AngleDynamicViewModel(displayDefaults: try defaults())
        vm.setupScene()
        vm.showsGhost3D = true; vm.showsAimPipe = true; vm.showsPotPipe = true
        let root = try XCTUnwrap(vm.scene.rootNode.childNode(withName: "angleDynamic.assists", recursively: false))
        let volume = try XCTUnwrap(root.childNode(withName: "angleDynamic.ghost3D", recursively: false))
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        vm.dragBegan(node: cue)
        vm.dragMoved(node: cue, worldPosition: SCNVector3(-0.55, cue.position.y, 0.08))
        vm.dragEnded(node: cue)
        XCTAssertTrue(vm.isFeasible)
        XCTAssertEqual(volume.simdPosition, vm.scene.ghostBallNode?.simdPosition)
        let clone = vm.scene.makeTemporaryTopDownRenderScene()
        XCTAssertNotNil(clone.rootNode.childNode(withName: "angleDynamic.assists", recursively: true))
        vm.selectedPocketIndex = -1; vm.updateCalculations()
        XCTAssertTrue(root.isHidden)
        vm.showsGhost3D = false; vm.showsGhost3D = true
        XCTAssertTrue(root.isHidden, "Toggling cannot revive stale geometry")
        vm.resetToDefaults()
        XCTAssertFalse(root.isHidden)
        vm.selectedPocketIndex = 99; vm.updateCalculations()
        XCTAssertTrue(root.isHidden)
        vm.resetToDefaults()
        vm.removeFromTable(try XCTUnwrap(vm.selectedTargetKey))
        XCTAssertTrue(root.isHidden)
    }

    func testRandomizationHidesAssistsUntilNewPositionsSettle() async throws {
        let vm = AngleDynamicViewModel(displayDefaults: try defaults())
        vm.setupScene(); vm.showsGhost3D = true; vm.showsAimPipe = true
        let root = try XCTUnwrap(vm.scene.rootNode.childNode(withName: "angleDynamic.assists", recursively: false))
        vm.randomizeBalls()
        XCTAssertTrue(root.isHidden)
        vm.showsPotPipe = true
        XCTAssertTrue(root.isHidden)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(root.isHidden, !vm.isFeasible)
    }

    func testPreferencesAreIndependentAndPageScoped() throws {
        let store = try defaults()
        let vm = AngleDynamicViewModel(displayDefaults: store)
        XCTAssertFalse(vm.showsGhost3D || vm.showsAimPipe || vm.showsPotPipe)
        XCTAssertTrue(vm.showsAimLine && vm.showsPotLine)
        vm.showsAimLine = false
        let aimOff = AngleDynamicViewModel(displayDefaults: store)
        XCTAssertFalse(aimOff.showsAimLine)
        XCTAssertTrue(aimOff.showsPotLine)
        vm.showsPotLine = false
        vm.showsGhost3D = true; vm.showsPotPipe = true
        let restored = AngleDynamicViewModel(displayDefaults: store)
        XCTAssertFalse(restored.showsAimLine || restored.showsPotLine)
        XCTAssertTrue(restored.showsGhost3D && restored.showsPotPipe)
        XCTAssertFalse(restored.showsAimPipe)
        vm.showsGhost3D = false; vm.showsPotPipe = false
        XCTAssertTrue(restored.showsGhost3D && restored.showsPotPipe, "Existing scenes own independent display state")
    }

    func testLineVisibilityPreservesRingPipesAndMetricsAcrossCameraChanges() throws {
        let vm = AngleDynamicViewModel(displayDefaults: try defaults())
        vm.setupScene()
        vm.showsGhost3D = true; vm.showsAimPipe = true; vm.showsPotPipe = true
        let ring = try XCTUnwrap(vm.scene.ghostBallNode)
        let ringChildren = ring.childNodes
        let angle = vm.cutAngleDegrees
        let root = try XCTUnwrap(vm.scene.rootNode.childNode(withName: "angleDynamic.assists", recursively: false))
        for mode in [AngleTrainingScene.CameraMode.topDown2D, .perspective3D] {
            vm.setCameraMode(mode)
            for mask in 0..<4 {
                vm.showsAimLine = mask & 1 != 0; vm.showsPotLine = mask & 2 != 0
                vm.updateCalculations()
                XCTAssertEqual(vm.scene.strikeLineNode?.isHidden, !vm.showsAimLine)
                XCTAssertEqual(vm.scene.pocketLineNode?.isHidden, !vm.showsPotLine)
                if !vm.showsAimLine {
                    XCTAssertEqual(vm.scene.rootNode.childNode(withName: "strikeContinuation", recursively: true)?.isHidden, true)
                }
                XCTAssertEqual(vm.scene.diagramVisibleLabelIndices, [0] + (vm.showsAimLine ? [1] : []) + (vm.showsPotLine ? [2] : []))
                XCTAssertFalse(ring.isHidden)
                XCTAssertEqual(ring.childNodes, ringChildren)
                XCTAssertFalse(root.isHidden)
                XCTAssertTrue(root.childNodes.allSatisfy { !$0.isHidden })
                XCTAssertEqual(vm.cutAngleDegrees, angle)
            }
        }
        vm.selectedPocketIndex = -1; vm.updateCalculations()
        vm.showsAimLine = false; vm.showsAimLine = true
        XCTAssertEqual(vm.scene.strikeLineNode?.isHidden, true)
        vm.showsAimLine = false; vm.showsPotLine = false
        vm.resetToDefaults()
        XCTAssertEqual(vm.scene.strikeLineNode?.isHidden, true)
        XCTAssertEqual(vm.scene.pocketLineNode?.isHidden, true)
        let g = try XCTUnwrap(vm.scene.diagramLabelGeometry)
        vm.scene.updateVisualization(cueBall: g.cue, targetBall: g.target, pocket: g.pocket)
        XCTAssertEqual(vm.scene.strikeLineNode?.isHidden, false, "Shared consumers retain visible defaults")
        XCTAssertEqual(vm.scene.pocketLineNode?.isHidden, false)
    }

    func testAdaptiveLabelsTrackIndependentLinesAndInvalidateCache() throws {
        let vm = AngleDynamicViewModel(displayDefaults: try defaults()); vm.setupScene()
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        view.scene = vm.scene; view.pointOfView = vm.scene.cameraNode
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = view.bounds.size
        vm.scene.setCameraMode(.topDown2D, animated: false)
        rig.snapToTarget(); SCNTransaction.flush()
        let overlay = DiagramLabelOverlay()
        for mask in [3, 2, 0, 1, 3] {
            vm.showsAimLine = mask & 1 != 0; vm.showsPotLine = mask & 2 != 0
            overlay.update(scene: vm.scene, in: view)
            for index in 0..<3 {
                let label = try XCTUnwrap(view.subviews.compactMap { $0 as? UILabel }.first {
                    $0.accessibilityIdentifier == "angleDiagram.label.\(index)"
                })
                XCTAssertEqual(label.isHidden, !vm.scene.diagramVisibleLabelIndices.contains(index))
            }
        }
    }

    func testPipeWidthAndSharedJointAcrossAnglesAndDirections() throws {
        let r = AngleSceneCalculator.ballRadius
        for rotation in stride(from: 0.0, to: 360.0, by: 30) {
            for cut in stride(from: -85.0, through: 85.0, by: 5) {
                let a = Float(rotation * .pi / 180), p = Float((rotation + cut) * .pi / 180)
                let aim = SIMD3<Float>(cos(a), 0, sin(a)), pot = SIMD3<Float>(cos(p), 0, sin(p))
                let g = SIMD3<Float>(0.13, 0.828575, -0.09)
                let shape = try XCTUnwrap(AngleDynamicAssistOverlay.pipeOutline(cue: g - aim * 0.5,
                    ghost: g, pocket: g + pot * 0.4, radius: r))
                XCTAssertEqual(shape.aim.filter { shape.pot.contains($0) }.count, 2)
                for (vertices, direction) in [(shape.aim, aim), (shape.pot, pot)] {
                    let side = SIMD3(-direction.z, 0, direction.x)
                    for v in vertices { XCTAssertEqual(abs(simd_dot(v - g, side)), r, accuracy: 0.000001) }
                }
            }
        }
        XCTAssertNil(AngleDynamicAssistOverlay.pipeOutline(cue: .zero, ghost: .zero, pocket: SIMD3(1, 0, 0), radius: r))
    }

    func testShortPipeRemainsConvexAndInsideEndpointAndJointPlanes() throws {
        let r = AngleSceneCalculator.ballRadius
        for cut in [-85.0, -45, 0, 45, 85] {
            let a = SIMD3<Float>(1, 0, 0)
            let angle = Float(cut * .pi / 180), p = SIMD3<Float>(cos(angle), 0, sin(angle))
            for length: Float in [0.001, 0.01, 0.1] {
                let cue = -a * length, pocket = p * length
                let shape = try XCTUnwrap(AngleDynamicAssistOverlay.pipeOutline(cue: cue, ghost: .zero, pocket: pocket, radius: r))
                for (polygon, endpoint, normal, sign) in [(shape.aim, cue, a, Float(-1)), (shape.pot, pocket, -p, Float(1))] {
                    XCTAssertGreaterThanOrEqual(polygon.count, 3)
                    for i in polygon.indices {
                        let v = polygon[i], next = polygon[(i + 1) % polygon.count], after = polygon[(i + 2) % polygon.count]
                        XCTAssertGreaterThanOrEqual(simd_dot(v - endpoint, normal), -0.000001)
                        XCTAssertGreaterThanOrEqual(sign * simd_dot(v, a + p), -0.000001)
                        XCTAssertGreaterThanOrEqual(simd_cross(next - v, after - next).y, -0.000001)
                    }
                }
            }
        }
    }

    func testCaptureCurrentSceneWithRingAndOptionalAssists() throws {
        let vm = AngleDynamicViewModel(displayDefaults: try defaults())
        vm.setupScene(); vm.setCameraMode(.perspective3D)
        let scene = vm.scene
        let camera = try XCTUnwrap(scene.cameraNode)
        let cue = try XCTUnwrap(scene.cueBallNode).position
        let ghost = try XCTUnwrap(scene.ghostBallNode).position
        let direction = simd_normalize(SIMD3(ghost.x - cue.x, 0, ghost.z - cue.z))
        camera.position = SCNVector3(cue.x - 0.28 * direction.x, scene.surfaceY + 0.40, cue.z - 0.28 * direction.z)
        camera.look(at: ghost, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene; renderer.pointOfView = camera
        renderer.delegate = scene.contactOcclusion
        for enabled in [false, true, false] {
            vm.showsGhost3D = enabled; vm.showsAimPipe = enabled; vm.showsPotPipe = enabled
            SCNTransaction.flush()
            let shot = renderer.snapshot(atTime: 0, with: CGSize(width: 1600, height: 1000), antialiasingMode: .multisampling4X)
            let attachment = XCTAttachment(image: shot)
            attachment.name = enabled ? "angle-assists-on" : "angle-assists-off"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
