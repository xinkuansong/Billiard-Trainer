import XCTest
import SceneKit
import AVFoundation
@testable import QiuJi

/// W8 helpers: TrajectoryRenderer options, SceneStroke constants, pulse/spin/palette.
final class TrajectoryRendererTests: XCTestCase {

    func testPositionPlayOptionsExpressFullSemantics() {
        let o = TrajectoryRenderer.Options.positionPlay
        XCTAssertTrue(o.includeObjectPath)
        XCTAssertTrue(o.extendToPocketRim)
        XCTAssertEqual(o.ghostSource, .ghost)
        XCTAssertEqual(o.extraBallMode, .fullOnly)
        XCTAssertFalse(o.requireVisibleTargetForGhost)
    }

    func testSnookerDefenseOptionsExpressDefenseSemantics() {
        let o = TrajectoryRenderer.Options.snookerDefense
        XCTAssertFalse(o.includeObjectPath, "D2: snooker defense omits objectPath")
        XCTAssertFalse(o.extendToPocketRim)
        XCTAssertEqual(o.ghostSource, .firstContact)
        XCTAssertEqual(o.extraBallMode, .coreTargetAndFull)
        XCTAssertTrue(o.requireVisibleTargetForGhost)
    }

    func testSceneStrokeConstantsMatchPriorCopies() {
        XCTAssertEqual(SceneStroke.circleSegments, 36)
        XCTAssertEqual(SceneStroke.lineRadius, 0.0022, accuracy: 1e-6)
    }

    func testConstraintCyanSingleDefinition() {
        let c = BTScenePalette.constraintCyan
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        XCTAssertEqual(r, 0.2, accuracy: 1e-3)
        XCTAssertEqual(g, 0.85, accuracy: 1e-3)
        XCTAssertEqual(b, 0.95, accuracy: 1e-3)
        XCTAssertEqual(a, 0.95, accuracy: 1e-3)
    }

    func testShotSpinLabelCenterAndCombinations() {
        XCTAssertEqual(ShotSpinLabel.text(spinX: 0, spinY: 0), "中心球")
        let lim = Double(CuePhysics.miscueLimitFraction)
        XCTAssertEqual(ShotSpinLabel.text(spinX: 0, spinY: lim * 0.5), "高杆")
        XCTAssertEqual(ShotSpinLabel.text(spinX: lim * 0.5, spinY: 0), "左塞")
        XCTAssertEqual(ShotSpinLabel.text(spinX: -lim * 0.5, spinY: -lim * 0.5), "低杆右塞")
    }

    func testTableBallPulseActionKey() {
        XCTAssertEqual(TableBallPulse.actionKey, "libraryPulse")
        let node = SCNNode()
        node.scale = SCNVector3(1, 1, 1)
        TableBallPulse.pulse(node)
        XCTAssertNotNil(node.action(forKey: TableBallPulse.actionKey))
    }
}

@MainActor
final class TableAssistSurfaceV63Tests: XCTestCase {
    typealias Point = TableAssistSurface.Point

    private func triangleArea(_ vertices: [SCNVector3]) -> Double {
        stride(from: 0, to: vertices.count, by: 3).reduce(0) { sum, i in
            let a = vertices[i], b = vertices[i+1], c = vertices[i+2]
            return sum + abs(Double((b.x-a.x)*(c.z-a.z) - (b.z-a.z)*(c.x-a.x))) / 2
        }
    }

    func testConcaveClothNotchIsNotFilledByTriangulation() throws {
        let polygon = [Point(0,0), Point(2,0), Point(2,1), Point(1,1), Point(1,2), Point(0,2)]
        for vertices in [polygon, Array(polygon.reversed())] {
            let triangles = try TableAssistSurface.triangulate(vertices)
            XCTAssertEqual(triangles.reduce(0) { $0 + TableAssistSurface.signedArea($1) }, 3, accuracy: 1e-9)
            let surface = TableAssistSurface(triangles: triangles, sourceY: 0.8)
            XCTAssertTrue(surface.ribbon(from: SCNVector3(1.2,9,1.5), to: SCNVector3(1.8,-9,1.5),
                                         width: 0.1, at: 0.801).isEmpty)
        }
        XCTAssertTrue(try TableAssistSurface.triangulate([]).isEmpty)
    }

    func testRibbonClipsWidthAndEndpointsAndKeepsRequestedHeight() throws {
        let triangles = try TableAssistSurface.triangulate([Point(0,0), Point(2,0), Point(2,2), Point(0,2)])
        let surface = TableAssistSurface(triangles: triangles, sourceY: 0.8)
        let from = SCNVector3(-1,3,0), to = SCNVector3(3,-4,0)
        let vertices = surface.ribbon(from: from, to: to, width: 0.2, at: 0.801)
        XCTAssertEqual(triangleArea(vertices), 0.2, accuracy: 1e-6)
        XCTAssertTrue(vertices.allSatisfy { $0.x >= 0 && $0.x <= 2 && $0.z >= 0 && $0.z <= 0.100001 })
        XCTAssertTrue(vertices.allSatisfy { abs($0.y-0.801) < 1e-6 })
        XCTAssertEqual(from.y, 3); XCTAssertEqual(to.y, -4)
        for i in stride(from: 0, to: vertices.count, by: 3) {
            let a = vertices[i], b = vertices[i+1], c = vertices[i+2]
            XCTAssertGreaterThan((b.z-a.z)*(c.x-a.x) - (b.x-a.x)*(c.z-a.z), 0)
        }
    }

    func testDisconnectedClothLeavesHoleEmpty() throws {
        let left = try TableAssistSurface.triangulate([Point(0,0), Point(0.8,0), Point(0.8,2), Point(0,2)])
        let right = try TableAssistSurface.triangulate([Point(1.2,0), Point(2,0), Point(2,2), Point(1.2,2)])
        let surface = TableAssistSurface(triangles: left+right, sourceY: 0.8)
        let vertices = surface.ribbon(from: SCNVector3(-1,0,1), to: SCNVector3(3,0,1), width: 0.2, at: 0.8)
        XCTAssertEqual(triangleArea(vertices), 0.32, accuracy: 1e-6)
        for i in stride(from: 0, to: vertices.count, by: 3) {
            let xs = vertices[i...i+2].map(\.x)
            XCTAssertTrue(xs.max()! <= 0.800001 || xs.min()! >= 1.199999)
        }
    }

    func testLoadedClothFootprintAndRenderEvidence() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        let surface = try TableAssistSurface.load(from: scene)
        XCTAssertFalse(surface.triangles.isEmpty)
        let area = surface.triangles.reduce(0) { $0 + TableAssistSurface.signedArea($1) }
        XCTAssertGreaterThan(area, 0)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/3d-v63/W03/footprint-r1")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY)
        let probes = pockets.enumerated().map { index, p in
            ["id": Double(index), "clippedArea": triangleArea(surface.ribbon(
                from: SCNVector3(p.x-0.002,0,p.z), to: SCNVector3(p.x+0.002,0,p.z), width: 0.004, at: surface.sourceY))]
        }
        let report: [String: Any] = ["triangleCount": surface.triangles.count, "area": area,
                                   "sourceY": surface.sourceY, "physicalY": scene.surfaceY, "pocketProbes": probes]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: root.appendingPathComponent("measurement.json"))
        let view = SCNView(frame: CGRect(x:0,y:0,width:402,height:650))
        view.scene = scene; view.pointOfView = scene.cameraNode
        scene.setCameraMode(.perspective3D, animated: false)
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.viewportSize = view.bounds.size
        rig.observe(at: pockets[0]); rig.handleVerticalSwipe(delta: -10000)
        rig.handlePinch(scale: 100); rig.snapToTarget()
        let start = SCNVector3(0, scene.surfaceY + AngleSceneCalculator.ballRadius, 0)
        let end = SCNVector3(pockets[0].x, start.y, pockets[0].z)
        let old = scene.addLine(from: start, to: end, color: .white, radius: 0.002)
        func capture(_ name: String) throws {
            SCNTransaction.flush(); view.layoutIfNeeded()
            let png = try XCTUnwrap(view.snapshot().pngData())
            try png.write(to: root.appendingPathComponent(name + ".png"))
        }
        try capture("before"); old.removeFromParentNode()
        let vertices = surface.ribbon(from: start, to: end, width: 0.004, at: surface.sourceY + 0.001)
        XCTAssertFalse(vertices.isEmpty)
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices)], elements: [
            SCNGeometryElement(indices: (0..<vertices.count).map(Int32.init), primitiveType: .triangles)])
        let material = SCNMaterial(); material.diffuse.contents = UIColor.white; material.lightingModel = .constant
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry); node.castsShadow = false; scene.rootNode.addChildNode(node)
        try capture("projected")
    }

    /// Regression for the head-half rail bands (X ∈ [0.04, 1.15], |Z| ∈ (0.512, 0.642))
    /// where 12 bed faces were dropped by a 1e-5 height filter and every projected
    /// line disappeared. Samples the whole playfield interior; both halves must be
    /// fully covered exactly once (no holes, no double-covered overlaps).
    func testLoadedClothFootprintHasNoHolesOrOverlapsInsidePlayfield() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        let surface = try TableAssistSurface.load(from: scene)
        func contains(_ t: [Point], _ p: Point) -> Bool {
            func cross(_ a: Point, _ b: Point) -> Double { a.x*b.y - a.y*b.x }
            let d0 = cross(t[1]-t[0], p-t[0]), d1 = cross(t[2]-t[1], p-t[1]), d2 = cross(t[0]-t[2], p-t[2])
            return (d0 >= 0 && d1 >= 0 && d2 >= 0) || (d0 <= 0 && d1 <= 0 && d2 <= 0)
        }
        // Stay 4 cm inside the cushion noses so pocket mouths never count as holes.
        let halfX = Double(AngleSceneCalculator.innerLength) / 2 - 0.04
        let halfZ = Double(AngleSceneCalculator.innerWidth) / 2 - 0.04
        var holes: [Point] = [], overlaps: [Point] = []
        var x = -halfX
        while x <= halfX {
            var z = -halfZ
            while z <= halfZ {
                let p = Point(x, z)
                let n = surface.triangles.filter { contains($0, p) }.count
                if n == 0 { holes.append(p) } else if n > 1 { overlaps.append(p) }
                z += 0.01
            }
            x += 0.01
        }
        XCTAssertTrue(holes.isEmpty, "footprint holes at \(holes.prefix(8))… (\(holes.count) samples)")
        XCTAssertTrue(overlaps.isEmpty, "double-covered footprint at \(overlaps.prefix(8))… (\(overlaps.count))")
        // The line that visibly broke in the 2026-09-14 report: table centre → +X/−Z corner.
        let ribbon = surface.ribbon(from: SCNVector3(0, 0, 0), to: SCNVector3(1.20, 0, -0.60),
                                    width: 0.0056, at: surface.sourceY + 0.001)
        XCTAssertEqual(triangleArea(ribbon), Double(hypot(1.20, 0.60)) * 0.0056, accuracy: 1e-5)
    }

    func testSceneSeparatesProjectedAssistsFromSpatialLines() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        let surface = try TableAssistSurface.load(from: scene)
        let from = SCNVector3(-0.4, scene.surfaceY + 0.04, 0)
        let to = SCNVector3(0.4, scene.surfaceY + 0.1, 0)
        let spatial = scene.addLine(from: from, to: to, color: .white)
        XCTAssertNotNil(spatial.geometry as? SCNCylinder)
        let projected = scene.addLine(from: from, to: to, color: .white, placement: .table)
        XCTAssertNil(projected.geometry as? SCNCylinder)
        let geometry = try XCTUnwrap(projected.geometry)
        XCTAssertTrue(try XCTUnwrap(geometry.firstMaterial).readsFromDepthBuffer)
        XCTAssertFalse(try XCTUnwrap(geometry.firstMaterial).writesToDepthBuffer)
        let positions = try XCTUnwrap(geometry.sources(for: .vertex).first)
        for i in 0..<positions.vectorCount {
            let y = positions.data.withUnsafeBytes { bytes in
                bytes.loadUnaligned(fromByteOffset: positions.dataOffset + i*positions.dataStride + 4, as: Float.self)
            }
            XCTAssertEqual(y, surface.sourceY + 0.001, accuracy: 1e-6)
        }
        var spaceNodes: [SCNNode] = [], projectedNodes: [SCNNode] = []
        let vertical = [SCNVector3(0,0.8,0), SCNVector3(0,1.1,0)]
        scene.addDashedPolyline(vertical, color: .white, into: &spaceNodes)
        scene.addDashedPolyline(vertical, color: .white, placement: .table, into: &projectedNodes)
        XCTAssertFalse(spaceNodes.isEmpty, "A real vertical path needs spatial arc length")
        XCTAssertTrue(projectedNodes.isEmpty, "A vertical path has zero table-projected length")
    }
    private func components(_ source: SCNGeometrySource) throws -> [[Float]] {
        XCTAssertTrue(source.usesFloatComponents)
        guard source.usesFloatComponents, [4, 8].contains(source.bytesPerComponent) else {
            throw NSError(domain: "AssistGeometryTest", code: 1)
        }
        return source.data.withUnsafeBytes { raw in
            (0..<source.vectorCount).map { index in
                (0..<source.componentsPerVector).map { component in
                    let offset = source.dataOffset + index * source.dataStride + component * source.bytesPerComponent
                    return source.bytesPerComponent == 4
                        ? raw.loadUnaligned(fromByteOffset: offset, as: Float.self)
                        : Float(raw.loadUnaligned(fromByteOffset: offset, as: Double.self))
                }
            }
        }
    }

    func testClippedRibbonTextureRetainsOriginalDistance() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        let start = SCNVector3(-4, 2, 0), end = SCNVector3(4, -1, 0)
        let node = scene.addLine(from: start, to: end, color: .white, placement: .table)
        let geometry = try XCTUnwrap(node.geometry)
        let vertices = try components(XCTUnwrap(geometry.sources(for: .vertex).first))
        let uv = try components(XCTUnwrap(geometry.sources(for: .texcoord).first))
        XCTAssertFalse(vertices.isEmpty)
        XCTAssertEqual(vertices.count, uv.count)
        for (point, tex) in zip(vertices, uv) {
            XCTAssertEqual(tex[0], 0.5, accuracy: 1e-6)
            XCTAssertEqual(tex[1], (point[0] + 4) / 8, accuracy: 1e-6)
        }
        XCTAssertGreaterThan(try XCTUnwrap(uv.map { $0[1] }.min()), 0)
        XCTAssertLessThan(try XCTUnwrap(uv.map { $0[1] }.max()), 1)
    }

    func testTrainingGuidesSurviveClippingAndKeepSpatialMarkers() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        scene.setupVisualizationNodes(usesTrainingAssistStyle: true)
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        let cue = SCNVector3(-0.6, y, 0.2), target = SCNVector3(0.3, y, -0.1)
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: y)[0]
        let potMaterial = try XCTUnwrap(scene.pocketLineNode?.geometry?.firstMaterial)
        func update(_ offset: Float) {
            func shifted(_ p: SCNVector3) -> SCNVector3 { SCNVector3(p.x + offset, p.y, p.z) }
            scene.updateVisualization(cueBall: shifted(cue), targetBall: shifted(target), pocket: shifted(pocket))
        }
        update(0)
        let initial = try XCTUnwrap(scene.pocketLineNode?.geometry?.sources(for: .vertex).first)
        let initialPositions = try components(initial)
        update(20)
        XCTAssertTrue(scene.pocketLineNode?.geometry?.sources(for: .vertex).isEmpty == true)
        XCTAssertTrue(scene.pocketLineNode?.geometry?.firstMaterial === potMaterial)
        update(0)
        XCTAssertTrue(scene.pocketLineNode?.geometry?.firstMaterial === potMaterial)
        XCTAssertEqual(try components(XCTUnwrap(scene.pocketLineNode?.geometry?.sources(for: .vertex).first)), initialPositions)
        let expectedY = try XCTUnwrap(MobileClothAlignment.measuredBedY(in: scene)) + 0.001
        let roots = [scene.pocketLineNode, scene.strikeLineNode, scene.perpLineNode, scene.angleArcNode]
        for root in roots {
            let root = try XCTUnwrap(root)
            var meshNodes = [root]
            root.enumerateChildNodes { node, _ in meshNodes.append(node) }
            let meshes = meshNodes.filter { $0.geometry != nil && !($0.geometry is SCNText) }
            XCTAssertFalse(meshes.isEmpty, root.name ?? "guide")
            for node in meshes {
                let geometry = try XCTUnwrap(node.geometry)
                XCTAssertEqual(geometry.elements.first?.primitiveType, .triangles)
                XCTAssertTrue(try XCTUnwrap(geometry.firstMaterial).readsFromDepthBuffer)
                XCTAssertFalse(try XCTUnwrap(geometry.firstMaterial).writesToDepthBuffer)
                for p in try components(XCTUnwrap(geometry.sources(for: .vertex).first)) {
                    XCTAssertEqual(node.convertPosition(SCNVector3(p[0], p[1], p[2]), to: nil).y, expectedY, accuracy: 1e-6)
                }
            }
        }
        XCTAssertEqual(try XCTUnwrap(scene.ghostBallNode).position.y, y, accuracy: 1e-6)
        XCTAssertGreaterThan(try XCTUnwrap(scene.contactDotNode).position.y, scene.surfaceY)
    }

    func testConstraintStrokesUseClothHeight() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        var nodes: [SCNNode] = []
        SceneStroke.strokeCircle(center: SCNVector3(0, 3, 0), radius: 0.15, color: .cyan, scene: scene, into: &nodes)
        SceneStroke.strokeRect(center: SCNVector3(0, -1, 0), halfX: 0.2, halfZ: 0.1, color: .cyan, scene: scene, into: &nodes)
        XCTAssertEqual(nodes.count, SceneStroke.circleSegments + 4)
        let expectedY = try XCTUnwrap(MobileClothAlignment.measuredBedY(in: scene)) + 0.001
        for node in nodes {
            let geometry = try XCTUnwrap(node.geometry)
            XCTAssertEqual(geometry.elements.first?.primitiveType, .triangles)
            for p in try components(XCTUnwrap(geometry.sources(for: .vertex).first)) {
                XCTAssertEqual(p[1], expectedY, accuracy: 1e-6)
            }
        }
    }

    func testTrainingGuideUpdateCostEvidence() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        scene.setupVisualizationNodes(usesTrainingAssistStyle: true)
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        var timings: [Double] = []
        for index in 0..<120 {
            let start = CACurrentMediaTime()
            scene.updateVisualization(cueBall: SCNVector3(-0.6, y, 0.1),
                                      targetBall: SCNVector3(0.3, y, Float(index % 20) * 0.005),
                                      pocket: SCNVector3(-1.312, y, -0.677))
            timings.append((CACurrentMediaTime() - start) * 1000)
        }
        let sorted = timings.dropFirst(20).sorted()
        let report: [String: Any] = ["scope": "simulator Debug CPU update only; not device frame-rate acceptance",
                                   "samples": sorted.count, "p50ms": sorted[sorted.count / 2],
                                   "p95ms": sorted[Int(Double(sorted.count - 1) * 0.95)], "maxms": sorted.last!]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "training-guide-update-cost"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testConvexFillClipsHolesWithEitherWinding() throws {
        let left = try TableAssistSurface.triangulate([Point(0,0), Point(0.8,0), Point(0.8,2), Point(0,2)])
        let right = try TableAssistSurface.triangulate([Point(1.2,0), Point(2,0), Point(2,2), Point(1.2,2)])
        let surface = TableAssistSurface(triangles: left + right, sourceY: 0.8)
        let region = [Point(-1,0.9), Point(3,0.9), Point(3,1.1), Point(-1,1.1)]
        for polygon in [region, Array(region.reversed())] {
            let vertices = surface.clippedConvexPolygon(polygon, at: 0.8005)
            XCTAssertEqual(triangleArea(vertices), 0.32, accuracy: 1e-6)
            for i in stride(from: 0, to: vertices.count, by: 3) {
                let xs = vertices[i...i+2].map(\.x)
                XCTAssertTrue(xs.max()! <= 0.800001 || xs.min()! >= 1.199999)
            }
        }
    }

    func testGridRebuildsAfterModelLoadAndFillKeepsDepth() throws {
        let scene = AngleTrainingScene()
        scene.setTableGridVisible(true) // Existing preference-before-model lifecycle.
        let previous = try XCTUnwrap(scene.rootNode.childNode(withName: "tableGrid", recursively: false))
        scene.setupScene()
        let grid = try XCTUnwrap(scene.rootNode.childNode(withName: "tableGrid", recursively: false))
        XCTAssertFalse(grid === previous)
        XCTAssertEqual(grid.childNodes.count, 10)
        let clothY = try XCTUnwrap(MobileClothAlignment.measuredBedY(in: scene))
        for node in grid.childNodes {
            let geometry = try XCTUnwrap(node.geometry)
            XCTAssertEqual(geometry.elements.first?.primitiveType, .triangles)
            for p in try components(XCTUnwrap(geometry.sources(for: .vertex).first)) {
                XCTAssertEqual(node.convertPosition(SCNVector3(p[0], p[1], p[2]), to: nil).y, clothY + 0.001, accuracy: 1e-6)
            }
        }
        scene.setTableGridVisible(false); XCTAssertTrue(grid.isHidden)
        scene.setTableGridVisible(true); XCTAssertFalse(grid.isHidden)
        XCTAssertTrue(grid === scene.rootNode.childNode(withName: "tableGrid", recursively: false))
        let fill = try XCTUnwrap(scene.makeTableFill(triangles: [
            [SCNVector3(-0.2, 3, -0.2), SCNVector3(0.2, -3, -0.2), SCNVector3(0, 2, 0.2)]
        ], color: UIColor.cyan.withAlphaComponent(0.2)))
        let geometry = try XCTUnwrap(fill.geometry)
        let material = try XCTUnwrap(geometry.firstMaterial)
        XCTAssertTrue(material.readsFromDepthBuffer)
        XCTAssertFalse(material.writesToDepthBuffer)
        for p in try components(XCTUnwrap(geometry.sources(for: .vertex).first)) {
            XCTAssertEqual(p[1], clothY + 0.0005, accuracy: 1e-6)
        }
    }

    func testDenseProjectedAssistsRenderEvidence() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        scene.setupVisualizationNodes(usesTrainingAssistStyle: true)
        scene.setTableGridVisible(true)
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        let cue = SCNVector3(-0.45, y, 0.15), target = SCNVector3(0.35, y, -0.1)
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: y)
        scene.applyBallLayout(cueBallPosition: cue, targetBallNumber: 6, targetPosition: target)
        scene.updateVisualization(cueBall: cue, targetBall: target, pocket: pockets[0], showLineLabels: false)
        var nodes: [SCNNode] = []
        for (index, pocket) in pockets.enumerated() {
            nodes.append(scene.addDashedLine(from: target, to: pocket,
                                             color: TrajectoryStyle.potColor(forNumber: index + 1), placement: .table))
            SceneStroke.strokeCircle(center: pocket, radius: 0.09, color: .cyan, scene: scene, into: &nodes)
        }
        let fill = try XCTUnwrap(scene.makeTableFill(triangles: [
            [SCNVector3(-1.5,y,-0.85), SCNVector3(0.5,y,-0.85), SCNVector3(0.5,y,0.15)],
            [SCNVector3(-1.5,y,-0.85), SCNVector3(0.5,y,0.15), SCNVector3(-1.5,y,0.15)]
        ], color: UIColor.cyan.withAlphaComponent(0.2)))
        scene.rootNode.addChildNode(fill)
        let size = UIScreen.main.bounds.size
        let view = SCNView(frame: CGRect(origin: .zero, size: size))
        view.antialiasingMode = .multisampling4X // Match AngleSceneView's production sampling.
        view.scene = scene; view.pointOfView = scene.cameraNode
        scene.setCameraMode(.perspective3D, animated: false)
        let rig = try XCTUnwrap(scene.cameraRig); rig.viewportSize = size
        for pose in ["whole", "pocket-low"] {
            if pose == "whole" { rig.observeWholeTable() }
            else {
                rig.observe(at: pockets[0]); rig.handleVerticalSwipe(delta: -10000); rig.handlePinch(scale: 100)
            }
            rig.snapToTarget(); SCNTransaction.flush(); view.layoutIfNeeded()
            let attachment = XCTAttachment(image: view.snapshot())
            attachment.name = "dense-assists-\(pose)-\(Int(size.width))"
            attachment.lifetime = .keepAlways; add(attachment)
        }
    }

    func testAngleValueFacesObserverAndRestoresTwoDimensionalLayout() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        scene.setupVisualizationNodes(usesTrainingAssistStyle: true)
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        scene.updateVisualization(cueBall: SCNVector3(-0.45, y, 0.15),
                                  targetBall: SCNVector3(0.35, y, -0.1),
                                  pocket: SCNVector3(0, y, -0.677), showLineLabels: true)
        let label = try XCTUnwrap(scene.angleArcNode?.childNode(withName: "angleValueLabel", recursively: false))
        let text = try XCTUnwrap(label.childNodes.first)
        let originalYaw = label.eulerAngles.y
        let originalPosition = label.position
        let value = try XCTUnwrap(text.geometry as? SCNText).string as? String
        let lineLabels = try XCTUnwrap(scene.angleArcNode).childNodes.filter { $0.name == "inlineLineLabel" }
        XCTAssertEqual(lineLabels.count, 2)
        let lineStates = lineLabels.map { ($0, $0.position, $0.eulerAngles.y) }
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene; renderer.pointOfView = scene.cameraNode
        scene.setCameraMode(.perspective3D, animated: false)
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.viewportSize = CGSize(width: 402, height: 700)
        XCTAssertTrue(rig.observeWholeTable())
        for index in 0..<4 {
            if index > 0 { rig.handleHorizontalSwipe(delta: Float.pi / 2 / 0.0025) }
            rig.snapToTarget(); SCNTransaction.flush()
            let image = renderer.snapshot(atTime: Double(index), with: CGSize(width: 804, height: 1400), antialiasingMode: .multisampling4X)
            let attachment = XCTAttachment(image: image)
            attachment.name = "angle-value-observer-\(index)"; attachment.lifetime = .keepAlways; add(attachment)
            let camera = try XCTUnwrap(scene.cameraNode).presentation.simdWorldTransform
            let glyph = text.presentation.simdWorldTransform
            func direction(_ v: SIMD4<Float>) -> SIMD3<Float> { simd_normalize(SIMD3(v.x, v.y, v.z)) }
            XCTAssertGreaterThan(simd_dot(direction(camera.columns.0), direction(glyph.columns.0)), 0.99)
            XCTAssertGreaterThan(simd_dot(direction(camera.columns.1), direction(glyph.columns.1)), 0.99)
            XCTAssertEqual(label.position.x, originalPosition.x, accuracy: 1e-6)
            XCTAssertEqual(label.position.z, originalPosition.z, accuracy: 1e-6)
            XCTAssertEqual((text.geometry as? SCNText)?.string as? String, value)
            for (line, position, _) in lineStates {
                let glyph = try XCTUnwrap(line.childNodes.first).presentation.simdWorldTransform
                XCTAssertGreaterThan(simd_dot(direction(camera.columns.0), direction(glyph.columns.0)), 0.99)
                XCTAssertGreaterThan(simd_dot(direction(camera.columns.1), direction(glyph.columns.1)), 0.99)
                XCTAssertEqual(line.position.x, position.x, accuracy: 1e-6)
                XCTAssertEqual(line.position.z, position.z, accuracy: 1e-6)
            }
        }
        scene.setCameraMode(.topDown2DRotated, animated: false)
        for (line, _, yaw) in lineStates {
            XCTAssertTrue(line.constraints?.isEmpty ?? true)
            XCTAssertEqual(line.eulerAngles.y, yaw, accuracy: 1e-6)
            XCTAssertEqual(try XCTUnwrap(line.childNodes.first).eulerAngles.x, -.pi / 2, accuracy: 1e-6)
        }
        XCTAssertTrue(label.constraints?.isEmpty ?? true)
        XCTAssertEqual(label.eulerAngles.y, originalYaw, accuracy: 1e-6)
        XCTAssertEqual(text.eulerAngles.x, -Float.pi / 2, accuracy: 1e-6)
        scene.setCameraMode(.perspective3D, animated: false)
        XCTAssertTrue(label.constraints?.first is SCNBillboardConstraint)
    }

    func testCoplanarLineDepthComparisonEvidence() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        let start = SCNVector3(0, y, 0)
        let end = AngleSceneCalculator.pocketPositions(surfaceY: y)[0]
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 402, height: 700))
        view.antialiasingMode = .multisampling4X
        view.scene = scene; view.pointOfView = scene.cameraNode
        scene.setCameraMode(.perspective3D, animated: false)
        let rig = try XCTUnwrap(scene.cameraRig); rig.viewportSize = view.bounds.size
        rig.observe(at: end); rig.handleVerticalSwipe(delta: -10000); rig.handlePinch(scale: 100); rig.snapToTarget()
        for kind in ["same-solid", "reverse-solid", "mixed-dash"] {
            var nodes: [SCNNode] = []
            if kind == "mixed-dash" {
                nodes.append(scene.addDashedLine(from: start, to: end, color: .white, radius: 0.003,
                                                dash: 0.04, gap: 0.03, placement: .table, layer: .reference))
                nodes.append(scene.addDashedLine(from: start, to: end, color: .yellow, radius: 0.003,
                                                dash: 0.07, gap: 0.04, placement: .table))
            } else {
                nodes.append(scene.addLine(from: start, to: end, color: .white, placement: .table, layer: .reference))
                nodes.append(scene.addLine(from: kind == "reverse-solid" ? end : start,
                                           to: kind == "reverse-solid" ? start : end,
                                           color: .yellow, placement: .table))
            }
            for policy in ["production", "legacy-depth-write"] {
                for (index, root) in nodes.enumerated() {
                    var all = [root]; root.enumerateChildNodes { node, _ in all.append(node) }
                    for node in all where node.geometry != nil {
                        if policy == "production" {
                            let material = try XCTUnwrap(node.geometry?.firstMaterial)
                            XCTAssertTrue(material.readsFromDepthBuffer)
                            XCTAssertFalse(material.writesToDepthBuffer)
                            XCTAssertEqual(node.renderingOrder, index == 0 ? 10 : 20)
                        } else {
                            node.geometry?.materials.forEach { $0.writesToDepthBuffer = true }
                            node.renderingOrder = 0
                        }
                    }
                }
                SCNTransaction.flush(); view.layoutIfNeeded()
                let attachment = XCTAttachment(image: view.snapshot())
                attachment.name = "overlap-\(kind)-\(policy)"; attachment.lifetime = .keepAlways; add(attachment)
            }
            scene.clearResultNodes(nodes: &nodes)
        }
    }

}

/// W05 geometry evidence uses loaded consumer transforms, not raw USD axes.
@MainActor
final class PocketGeometryV63Tests: XCTestCase {
    func testLoadedPocketContactGeometryEvidence() throws {
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
        let table = try XCTUnwrap(scene.tableNode)
        let bedY = try XCTUnwrap(MobileClothAlignment.measuredBedY(in: scene))
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY)
        var nodes = [table]
        table.enumerateChildNodes { node, _ in nodes.append(node) }
        var facesByPocket = Array(repeating: [[String: Any]](), count: pockets.count)
        for node in nodes {
            guard let geometry = node.geometry,
                  let sourceIndex = geometry.sources.firstIndex(where: { $0.semantic == .vertex }) else { continue }
            let source = geometry.sources[sourceIndex]
            let channel = geometry.geometrySourceChannels?[sourceIndex].intValue ?? 0
            XCTAssertTrue(source.usesFloatComponents)
            XCTAssertEqual(source.bytesPerComponent, 4)
            XCTAssertEqual(source.componentsPerVector, 3)
            guard source.usesFloatComponents, source.bytesPerComponent == 4, source.componentsPerVector == 3 else {
                throw NSError(domain: "PocketGeometry", code: 1)
            }
            for (elementIndex, element) in geometry.elements.enumerated() {
                XCTAssertLessThan(channel, element.indicesChannelCount)
                let material = geometry.materials.isEmpty ? "none" : geometry.materials[elementIndex % geometry.materials.count].name ?? "unnamed"
                for indices in try PocketLeatherMesh.decode(element) {
                    var points: [[Float]] = []
                    for offset in stride(from: channel, to: indices.count, by: element.indicesChannelCount) {
                        let index = Int(indices[offset])
                        let address = source.dataOffset + index * source.dataStride
                        guard index < source.vectorCount, address >= 0, address + 12 <= source.data.count else {
                            throw NSError(domain: "PocketGeometry", code: 2)
                        }
                        let p = source.data.withUnsafeBytes { bytes in
                            SCNVector3(bytes.loadUnaligned(fromByteOffset: address, as: Float.self),
                                       bytes.loadUnaligned(fromByteOffset: address+4, as: Float.self),
                                       bytes.loadUnaligned(fromByteOffset: address+8, as: Float.self))
                        }
                        let w = node.convertPosition(p, to: scene.rootNode)
                        guard w.x.isFinite, w.y.isFinite, w.z.isFinite else { throw NSError(domain: "PocketGeometry", code: 3) }
                        points.append([w.x,w.y,w.z])
                    }
                    guard points.count >= 3 else { continue }
                    let minX = points.map { $0[0] }.min()!, maxX = points.map { $0[0] }.max()!
                    let minY = points.map { $0[1] }.min()!, maxY = points.map { $0[1] }.max()!
                    let minZ = points.map { $0[2] }.min()!, maxZ = points.map { $0[2] }.max()!
                    for (i, pocket) in pockets.enumerated() {
                        // Broad measurement window, not a physics activation boundary.
                        let extent: Float = 0.18
                        guard maxX >= pocket.x-extent, minX <= pocket.x+extent,
                              maxZ >= pocket.z-extent, minZ <= pocket.z+extent,
                              maxY >= bedY-0.3, minY <= bedY+0.1 else { continue }
                        facesByPocket[i].append(["node": node.name ?? "unnamed", "material": material, "vertices": points])
                    }
                }
            }
        }
        for faces in facesByPocket { XCTAssertFalse(faces.isEmpty) }
        let report: [String: Any] = ["coordinateSystem": "SceneKit world XZ plane, Y up, meters",
            "sourceBedY": bedY, "physicalBedY": scene.surfaceY, "ballRadius": BallPhysics.radius,
            "note": "Raw loaded faces; mobile cloth shader lift is not baked into positions. Broad AABB selection can include long faces.",
            "pockets": pockets.enumerated().map { i, p in
                ["id": "pocket_\(i)", "center": [p.x,p.y,p.z], "faces": facesByPocket[i]] as [String: Any]
            }]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "loaded-pocket-contact-geometry"; attachment.lifetime = .keepAlways; add(attachment)
    }
}

extension PocketGeometryV63Tests {
    func testNearPocketMotionFrames() throws {
        for index in [0,4] {
            let scene=AngleTrainingScene();scene.setupScene(mobileRendering:true);scene.hideAllBalls()
            let cue=try XCTUnwrap(scene.cueBallNode)
            cue.isHidden=false;cue.opacity=1
            let pocket=AngleSceneCalculator.pocketPositions(surfaceY:scene.surfaceY)[index]
            let radius=Double(BallPhysics.radius),bed=Double(scene.surfaceY)
            let inward=index==0 ? SIMD3<Double>(1/sqrt(2),0,1/sqrt(2)) : SIMD3<Double>(0,0,1)
            let across=SIMD3(inward.z,0,-inward.x)
            let center=SIMD3(Double(pocket.x),bed,Double(pocket.z))
            let camera=scene.cameraNode.clone()
            camera.camera=scene.cameraNode.camera?.copy() as? SCNCamera
            camera.camera?.usesOrthographicProjection=false;camera.camera?.fieldOfView=45
            camera.camera?.zNear=0.001;camera.camera?.zFar=10
            let eye=center+inward*0.36+across*0.16+SIMD3(0,0.28,0)
            camera.position=SCNVector3(Float(eye.x),Float(eye.y),Float(eye.z))
            let focus=center+inward*0.025+SIMD3(0,-0.025,0)
            camera.look(at:SCNVector3(Float(focus.x),Float(focus.y),Float(focus.z)))
            scene.rootNode.addChildNode(camera)
            let view=SCNView(frame:CGRect(x:0,y:0,width:402,height:500))
            view.scene=scene;view.pointOfView=camera;view.backgroundColor = .black
            let mesh=try PocketContactMesh.load(from:scene,pocketIndex:index)
            let solver=LocalPocketSimulation(surfaces:mesh.patches.map { .init(triangle:$0.triangle,restitution:0.3,friction:0.2) },
                radius:radius,gravity:SIMD3(0,-9.81,0),tolerance:1e-6)
            var outside=0.0,inside=0.12
            for _ in 0..<32 {
                let middle=(outside+inside)/2,p=center+inward*middle
                let supported=mesh.patches.contains { patch in
                    let d=patch.triangle.closestPoint(to:p)-p
                    return d.x*d.x+d.y*d.y+d.z*d.z<1e-20
                }
                if supported { inside=middle } else { outside=middle }
            }
            let edge=(outside+inside)/2
            for (name,speed,offset,distance) in [("entry",0.5,0.0,0.12),("jaw",1.0,0.025,0.12),
                ("return",4.0,0.0,0.12),("slow",0.15,0.0,0.12),
                ("hang",0.0,0.0,edge+0.0002),("fall",0.0,0.0,edge-0.0002)] {
                print("[W05 frame case] pocket=\(index) case=\(name)")
                let v = -inward*speed
                let result=try solver.run(from:.init(time:0,position:center+inward*distance+across*offset+SIMD3(0,radius,0),
                    velocity:v,omega:SIMD3(v.z/radius,0,-v.x/radius)),duration:name=="slow" ? 0.8 : 0.35,maxStep:0.00025)
                BallSpinIntegrator.resetPose(cue)
                var cursor=0
                for time in (name=="slow" ? [0.0,0.3,0.4,0.5,0.6,0.7,0.8] : [0.0,0.05,0.1,0.15,0.2,0.25,0.3]) {
                    let sample=try XCTUnwrap(result.states.indices.min { abs(result.states[$0].time-time)<abs(result.states[$1].time-time) })
                    while cursor<sample {
                        let a=result.states[cursor],b=result.states[cursor+1]
                        BallSpinIntegrator.advance(node:cue,
                            from:SCNVector3(Float(a.omega.x),Float(a.omega.y),Float(a.omega.z)),
                            to:SCNVector3(Float(b.omega.x),Float(b.omega.y),Float(b.omega.z)),dt:Float(b.time-a.time))
                        cursor+=1
                    }
                    let state=result.states[sample]
                    cue.position=SCNVector3(Float(state.position.x),Float(state.position.y),Float(state.position.z))
                    SCNTransaction.flush();view.layoutIfNeeded()
                    if time==0 {
                        let p=view.projectPoint(cue.position)
                        XCTAssertTrue(p.x>0 && p.x<402 && p.y>0 && p.y<500)
                    }
                    let attachment=XCTAttachment(image:view.snapshot())
                    attachment.name="near-pocket-\(index)-\(name)-t\(state.time)"
                    attachment.lifetime = .keepAlways;add(attachment)
                }
            }
        }
    }
    func testCriticalPocketStepConvergence() throws {
        let scene=AngleTrainingScene();scene.setupScene(mobileRendering:true)
        let radius=Double(BallPhysics.radius),bed=Double(scene.surfaceY)
        for index in [0,4] {
            let mesh=try PocketContactMesh.load(from:scene,pocketIndex:index)
            let pocket=AngleSceneCalculator.pocketPositions(surfaceY:scene.surfaceY)[index]
            let center=SIMD3(Double(pocket.x),bed,Double(pocket.z))
            let inward=index==0 ? SIMD3<Double>(1/sqrt(2),0,1/sqrt(2)) : SIMD3<Double>(0,0,1)
            var outside=0.0,inside=0.12
            for _ in 0..<32 {
                let middle=(outside+inside)/2,p=center+inward*middle
                if mesh.patches.contains(where:{ patch in
                    let d=patch.triangle.closestPoint(to:p)-p
                    return d.x*d.x+d.y*d.y+d.z*d.z<1e-20
                }) { inside=middle } else { outside=middle }
            }
            let solver=LocalPocketSimulation(surfaces:mesh.patches.map { .init(triangle:$0.triangle,restitution:0.3,friction:0.2) },
                radius:radius,gravity:SIMD3(0,-9.81,0),tolerance:1e-6)
            for offset in [0.0002,-0.0002] {
                let p=center+inward*((inside+outside)/2+offset)+SIMD3(0,radius,0)
                var finals:[SIMD3<Double>]=[]
                for step in [0.0005,0.00025,0.000125] {
                    print("[W05 critical] pocket=\(index) offset=\(offset) step=\(step)")
                    let result=try solver.run(from:.init(time:0,position:p,velocity:.zero,omega:.zero),duration:1,maxStep:step)
                    for s in result.states {
                        let v=s.velocity,w=s.omega
                        let energy=0.5*(v.x*v.x+v.y*v.y+v.z*v.z)+0.2*radius*radius*(w.x*w.x+w.y*w.y+w.z*w.z)+9.81*s.position.y
                        XCTAssertLessThanOrEqual(energy,9.81*p.y+4*9.81*solver.tolerance)
                    }
                    let data=try JSONSerialization.data(withJSONObject:["pocket":index,"offset":offset,"step":step,
                        "states":result.states.map { [$0.time,$0.position.x,$0.position.y,$0.position.z,$0.velocity.x,$0.velocity.y,$0.velocity.z,$0.omega.x,$0.omega.y,$0.omega.z] },
                        "contacts":result.contacts.map { [$0.time,Double($0.surface),$0.normal.x,$0.normal.y,$0.normal.z] }])
                    let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
                    attachment.name="critical-pocket-\(index)-offset-\(offset)-step-\(step)";attachment.lifetime = .keepAlways;add(attachment)
                    let last=try XCTUnwrap(result.states.last);finals.append(last.position)
                    if offset>0 { XCTAssertEqual(last.velocity,.zero);XCTAssertEqual(last.position.y,p.y,accuracy:1e-6) }
                    else { XCTAssertLessThan(last.position.y,bed-0.02) }
                    XCTAssertLessThanOrEqual(result.maxCorrection,4*solver.tolerance)
                }
                let d=finals[0]-finals[1]
                let coarse=sqrt(d.x*d.x+d.y*d.y+d.z*d.z)
                let fineDifference=finals[1]-finals[2]
                let fine=sqrt(fineDifference.x*fineDifference.x+fineDifference.y*fineDifference.y+fineDifference.z*fineDifference.z)
                print("[W05 critical convergence] pocket=\(index) offset=\(offset) coarse=\(coarse) fine=\(fine)")
                XCTAssertLessThan(coarse,0.002)
                XCTAssertLessThan(fine,0.002)
                if offset<0 { XCTAssertLessThan(fine,0.6*coarse) }
            }
        }
    }
    func testOffsetAndReturnEnergyConvergence() throws {
        let scene=AngleTrainingScene();scene.setupScene(mobileRendering:true)
        let pockets=AngleSceneCalculator.pocketPositions(surfaceY:scene.surfaceY)
        let bed=Double(scene.surfaceY),radius=Double(BallPhysics.radius)
        func energy(_ s:LocalPocketSimulation.State)->Double {
            let v=s.velocity,w=s.omega
            return 0.5*(v.x*v.x+v.y*v.y+v.z*v.z)+0.2*radius*radius*(w.x*w.x+w.y*w.y+w.z*w.z)+9.81*s.position.y
        }
        for index in [0,4] {
            let mesh=try PocketContactMesh.load(from:scene,pocketIndex:index)
            let solver=LocalPocketSimulation(surfaces:mesh.patches.map { .init(triangle:$0.triangle,restitution:0.3,friction:0.2) },
                radius:radius,gravity:SIMD3(0,-9.81,0),tolerance:1e-6)
            let inward=index==0 ? SIMD3<Double>(1/sqrt(2),0,1/sqrt(2)) : SIMD3<Double>(0,0,1)
            let across=SIMD3(inward.z,0,-inward.x)
            let center=SIMD3(Double(pockets[index].x),bed,Double(pockets[index].z))
            for (speed,offset) in [(1.0,-0.025),(1.0,0.025),(4.0,0.0)] {
                var finals:[SIMD3<Double>]=[]
                for step in [0.0005,0.00025] {
                    let v = -inward*speed
                    let initial=LocalPocketSimulation.State(time:0,
                        position:center+inward*0.12+across*offset+SIMD3(0,radius,0),velocity:v,
                        omega:SIMD3(v.z/radius,0,-v.x/radius))
                    let result=try solver.run(from:initial,duration:0.3,maxStep:step)
                    let last=try XCTUnwrap(result.states.last);finals.append(last.position)
                    XCTAssertLessThanOrEqual(result.states.map(energy).max()!,energy(initial)+4*9.81*solver.tolerance)
                    XCTAssertLessThanOrEqual(result.maxCorrection,4*solver.tolerance)
                    XCTAssertFalse(result.contacts.isEmpty,"Case must exercise an actual surface collision")
                    XCTAssertTrue(zip(result.contacts,result.contacts.dropFirst()).allSatisfy { $0.time != $1.time || $0.surface != $1.surface })
                    let data=try JSONSerialization.data(withJSONObject:["pocket":index,"speed":speed,"offset":offset,"step":step,
                        "states":result.states.map { [$0.time,$0.position.x,$0.position.y,$0.position.z,$0.velocity.x,$0.velocity.y,$0.velocity.z,energy($0)] },
                        "contacts":result.contacts.map { [$0.time,Double($0.surface),$0.normal.x,$0.normal.y,$0.normal.z] }])
                    let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
                    attachment.name="offset-pocket-\(index)-speed-\(speed)-offset-\(offset)-dt-\(step)"
                    attachment.lifetime = .keepAlways;add(attachment)
                    print("[W05 offset] pocket=\(index) speed=\(speed) offset=\(offset) dt=\(step) final=\(last.position) hits=\(result.contacts.count)")
                }
                let d=finals[0]-finals[1]
                XCTAssertLessThan(sqrt(d.x*d.x+d.y*d.y+d.z*d.z),0.002)
            }
        }
    }
    func testPocketEdgeAndReturnCharacterization() throws {
        let scene=AngleTrainingScene();scene.setupScene(mobileRendering:true)
        let pockets=AngleSceneCalculator.pocketPositions(surfaceY:scene.surfaceY)
        let bed=Double(scene.surfaceY),radius=Double(BallPhysics.radius)
        for index in [0,4] {
            let mesh=try PocketContactMesh.load(from:scene,pocketIndex:index)
            let solver=LocalPocketSimulation(surfaces:mesh.patches.map { .init(triangle:$0.triangle,restitution:0.3,friction:0.2) },
                radius:radius,gravity:SIMD3(0,-9.81,0),tolerance:1e-6)
            let inward=index==0 ? SIMD3<Double>(1/sqrt(2),0,1/sqrt(2)) : SIMD3<Double>(0,0,1)
            let center=SIMD3(Double(pockets[index].x),bed,Double(pockets[index].z))
            func flatSupport(_ distance:Double)->Bool {
                let p=center+inward*distance
                return mesh.patches.contains { patch in
                    let q=patch.triangle.closestPoint(to:p),d=q-p
                    return d.x*d.x+d.y*d.y+d.z*d.z<1e-20
                }
            }
            var outside=0.0,inside=0.12
            XCTAssertFalse(flatSupport(outside));XCTAssertTrue(flatSupport(inside))
            for _ in 0..<32 {
                let middle=(outside+inside)/2
                if flatSupport(middle) { inside=middle } else { outside=middle }
            }
            let edge=(outside+inside)/2
            for offset in [0.0002,-0.0002] {
                let p=center+inward*(edge+offset)+SIMD3(0,radius,0)
                let result=try solver.run(from:.init(time:0,position:p,velocity:.zero,omega:.zero),duration:1,maxStep:0.0005)
                let last=try XCTUnwrap(result.states.last)
                if offset>0 {
                    XCTAssertEqual(last.position.y,p.y,accuracy:1e-6)
                    XCTAssertEqual(last.velocity,.zero)
                } else { XCTAssertLessThan(last.position.y,bed-0.02) }
                print("[W05 edge] pocket=\(index) edge=\(edge) offset=\(offset) final=\(last.position) contacts=\(result.contacts.count)")
            }
            for speed in [2.0,4,6,8] {
                let v = -inward*speed
                let result=try solver.run(from:.init(time:0,position:center+inward*0.12+SIMD3(0,radius,0),
                    velocity:v,omega:SIMD3(v.z/radius,0,-v.x/radius)),duration:0.5,maxStep:0.0005)
                let firstHit=result.contacts.first?.time ?? .infinity
                let returned=result.states.first { s in
                    let delta=s.position-center
                    return s.time>firstHit && delta.x*inward.x+delta.z*inward.z>0.1 && s.position.y>=bed+radius-4e-6
                }
                if speed==4 {
                    XCTAssertNotNil(returned,"Measured 4m/s shot must return above the inner table")
                    XCTAssertTrue(result.states.contains { s in
                        let delta=s.position-center
                        return s.time>firstHit && delta.x*inward.x+delta.z*inward.z>0.1
                            && abs(s.position.y-bed-radius)<4e-6 && abs(s.velocity.y)<1e-6
                    },"Return must regain planar support, not only cross above the table in flight")
                }
                let rows=result.states.map { [$0.time,$0.position.x,$0.position.y,$0.position.z,$0.velocity.x,$0.velocity.y,$0.velocity.z] }
                let data=try JSONSerialization.data(withJSONObject:["pocket":index,"speed":speed,"states":rows,
                    "contacts":result.contacts.map { [$0.time,Double($0.surface)] }])
                let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
                attachment.name="return-pocket-\(index)-speed-\(speed)";attachment.lifetime = .keepAlways;add(attachment)
                print("[W05 return search] pocket=\(index) speed=\(speed) returned=\(String(describing:returned?.time)) final=\(result.states.last!.position)")
            }
        }
    }
    func testSpatialIndexMatchesExhaustiveMotion() throws {
        let scene=AngleTrainingScene();scene.setupScene(mobileRendering:true)
        let mesh=try PocketContactMesh.load(from:scene,pocketIndex:4)
        let pocket=AngleSceneCalculator.pocketPositions(surfaceY:scene.surfaceY)[4]
        let radius=Double(BallPhysics.radius)
        let surfaces=mesh.patches.map { LocalPocketSimulation.Surface(triangle:$0.triangle,restitution:0.3,friction:0.2) }
        let initial=LocalPocketSimulation.State(time:0,
            position:SIMD3(Double(pocket.x),Double(scene.surfaceY)+radius,Double(pocket.z)+0.12),
            velocity:SIMD3(0,0,-0.15),omega:SIMD3(-0.15/radius,0,0))
        var results:[LocalPocketSimulation.Result]=[]
        for indexed in [false,true] {
            let start=Date()
            let solver=LocalPocketSimulation(surfaces:surfaces,radius:radius,gravity:SIMD3(0,-9.81,0),tolerance:1e-6,useSpatialIndex:indexed)
            let result=try solver.run(from:initial,duration:0.65,maxStep:0.0005)
            results.append(result)
            print("[W05 index timing] indexed=\(indexed) seconds=\(Date().timeIntervalSince(start)) states=\(result.states.count)")
        }
        XCTAssertEqual(results[0].states.count,results[1].states.count)
        for (a,b) in zip(results[0].states,results[1].states) {
            XCTAssertEqual(a.time,b.time);XCTAssertEqual(a.position,b.position)
            XCTAssertEqual(a.velocity,b.velocity);XCTAssertEqual(a.omega,b.omega)
        }
        XCTAssertEqual(results[0].contacts.count,results[1].contacts.count)
        for (a,b) in zip(results[0].contacts,results[1].contacts) {
            XCTAssertEqual(a.time,b.time);XCTAssertEqual(a.surface,b.surface);XCTAssertEqual(a.normal,b.normal)
        }
        XCTAssertEqual(results[0].rejectedSteps,results[1].rejectedSteps)
    }
    func testSlowMiddleInitialSymmetry() throws {
        let scene=AngleTrainingScene();scene.setupScene(mobileRendering:true)
        let mesh=try PocketContactMesh.load(from:scene,pocketIndex:4)
        let pocket=AngleSceneCalculator.pocketPositions(surfaceY:scene.surfaceY)[4]
        let radius=Double(BallPhysics.radius)
        let solver=LocalPocketSimulation(surfaces:mesh.patches.map {
            .init(triangle:$0.triangle,restitution:0.3,friction:0.2)
        },radius:radius,gravity:SIMD3(0,-9.81,0),tolerance:1e-6)
        for step in [0.0005,0.00025] {
            let result=try solver.run(from:.init(time:0,
                position:SIMD3(Double(pocket.x),Double(scene.surfaceY)+radius,Double(pocket.z)+0.12),
                velocity:SIMD3(0,0,-0.15),omega:SIMD3(-0.15/radius,0,0)),duration:0.46,maxStep:step)
            print("[W05 initial symmetry] step=\(step) final=\(result.states.last!)")
            XCTAssertLessThan(result.states.map { abs($0.position.x) }.max()!,1e-10)
        }
    }
    func testLoadedPocketSpeedAndStepMatrix() throws {
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY)
        let radius = Double(BallPhysics.radius)
        func energy(_ s: LocalPocketSimulation.State) -> Double {
            let v = s.velocity, w = s.omega
            return 0.5*(v.x*v.x+v.y*v.y+v.z*v.z)+0.2*radius*radius*(w.x*w.x+w.y*w.y+w.z*w.z)+9.81*s.position.y
        }
        for index in [0,4] {
            let mesh = try PocketContactMesh.load(from:scene,pocketIndex:index)
            let solver = LocalPocketSimulation(surfaces:mesh.patches.map {
                .init(triangle:$0.triangle,restitution:0.3,friction:0.2)
            },radius:radius,gravity:SIMD3(0,-9.81,0),tolerance:1e-6)
            let inward = index == 0 ? SIMD3<Double>(1/sqrt(2),0,1/sqrt(2)) : SIMD3<Double>(0,0,1)
            let pocket = pockets[index]
            let position = SIMD3(Double(pocket.x),Double(scene.surfaceY)+radius,Double(pocket.z))+inward*0.12
            for speed in [0.15,0.5,2.0] {
                var finals: [SIMD3<Double>] = []
                for step in [0.0005,0.00025] {
                    let velocity = -inward*speed
                    let initial = LocalPocketSimulation.State(time:0,position:position,velocity:velocity,
                        omega:SIMD3(velocity.z/radius,0,-velocity.x/radius))
                    let duration = 0.12/speed+0.35
                    let result = try solver.run(from:initial,duration:duration,maxStep:step)
                    let last = try XCTUnwrap(result.states.last); finals.append(last.position)
                    XCTAssertEqual(last.time,duration,accuracy:1e-10)
                    XCTAssertLessThanOrEqual(result.states.map(energy).max()!,energy(initial)+4*9.81*solver.tolerance)
                    XCTAssertTrue(zip(result.contacts,result.contacts.dropFirst()).allSatisfy {
                        $0.time != $1.time || $0.surface != $1.surface
                    })
                    let rows = result.states.map { [$0.time,$0.position.x,$0.position.y,$0.position.z,
                                                    $0.velocity.x,$0.velocity.y,$0.velocity.z,energy($0)] }
                    let data = try JSONSerialization.data(withJSONObject:["pocket":index,"speed":speed,"step":step,
                        "states":rows,"contacts":result.contacts.map { [$0.time,Double($0.surface)] }])
                    let attachment = XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
                    attachment.name = "matrix-pocket-\(index)-speed-\(speed)-step-\(step)"
                    attachment.lifetime = .keepAlways; add(attachment)
                    print("[W05 matrix] pocket=\(index) speed=\(speed) step=\(step) final=\(last.position) contacts=\(result.contacts.count)")
                }
                let difference = finals[0]-finals[1]
                XCTAssertLessThan(sqrt(difference.x*difference.x+difference.y*difference.y+difference.z*difference.z),0.002)
            }
        }
    }
    func testLocalMotionOnLoadedPocketGeometry() throws {
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY)
        let radius = Double(BallPhysics.radius)
        for index in [0, 4] {
            let mesh = try PocketContactMesh.load(from: scene, pocketIndex: index)
            let simulator = LocalPocketSimulation(surfaces: mesh.patches.map {
                .init(triangle: $0.triangle, restitution: 0.3, friction: 0.2)
            }, radius: radius, gravity: SIMD3(0, -9.81, 0), tolerance: 1e-6)
            let inward = index == 0 ? SIMD3<Double>(1/sqrt(2), 0, 1/sqrt(2)) : SIMD3<Double>(0, 0, 1)
            let pocket = pockets[index]
            let position = SIMD3(Double(pocket.x), Double(scene.surfaceY)+radius, Double(pocket.z))+inward*0.12
            let velocity = -inward*0.5
            let omega = SIMD3(velocity.z/radius, 0, -velocity.x/radius)
            let result = try simulator.run(from: .init(time: 0, position: position, velocity: velocity, omega: omega),
                                           duration: 0.5, maxStep: 0.0005)
            let rows = result.states.map { s in
                [s.time, s.position.x, s.position.y, s.position.z,
                 s.velocity.x, s.velocity.y, s.velocity.z, s.omega.x, s.omega.y, s.omega.z]
            }
            let data = try JSONSerialization.data(withJSONObject: ["pocket": index, "states": rows,
                "contacts": result.contacts.map { [$0.time, Double($0.surface), $0.normal.x, $0.normal.y, $0.normal.z] }])
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "local-motion-pocket-\(index)"; attachment.lifetime = .keepAlways; add(attachment)
            let repeatedContacts = zip(result.contacts, result.contacts.dropFirst()).filter {
                $0.time == $1.time && $0.surface == $1.surface
            }
            XCTAssertTrue(repeatedContacts.isEmpty, "Repeated zero-time impacts indicate unresolved support constraints")
            let last = try XCTUnwrap(result.states.last)
            XCTAssertEqual(last.time, 0.5, accuracy: 1e-10)
            XCTAssertLessThan(last.position.y, Double(scene.surfaceY))
            XCTAssertLessThanOrEqual(result.maxCorrection, 4e-6)
            print("[W05 local motion] pocket=\(index) final=\(last.position) contacts=\(result.contacts.count)")
        }
    }
    func testContactMeshPreservesMobileSupportAndOpenPocket() throws {
        let scene=AngleTrainingScene();scene.setupScene(mobileRendering:true)
        let pockets=AngleSceneCalculator.pocketPositions(surfaceY:scene.surfaceY)
        for index in [0,4] {
            let mesh=try PocketContactMesh.load(from:scene,pocketIndex:index)
            XCTAssertEqual(mesh.pocketID,"pocket_\(index)")
            XCTAssertTrue(mesh.patches.allSatisfy { ["TaiNi","Leather"].contains($0.material) })
            let pocket=pockets[index]
            // Corner inward bisector keeps a sphere clear of both adjacent cushions.
            let inward = index == 0 ? SIMD3<Double>(1/sqrt(2),0,1/sqrt(2)) : SIMD3<Double>(0,0,1)
            let above=SIMD3(Double(pocket.x),Double(scene.surfaceY)+0.15,Double(pocket.z))+inward*0.12
            let hits=mesh.patches.compactMap { $0.triangle.firstContact(position:above,velocity:SIMD3(0,-1,0),
                        acceleration:.zero,radius:Double(BallPhysics.radius),horizon:0.2) }
            let first=try XCTUnwrap(hits.min { $0.time<$1.time })
            XCTAssertEqual(first.point.y,Double(scene.surfaceY),accuracy:1e-6)
            XCTAssertEqual(first.normal.y,1,accuracy:1e-6)
            XCTAssertEqual(first.time,0.15-Double(BallPhysics.radius),accuracy:1e-6)
            let center=SIMD3(Double(pocket.x),Double(scene.surfaceY)+0.15,Double(pocket.z))
            let holeHits=mesh.patches.compactMap { $0.triangle.firstContact(position:center,velocity:SIMD3(0,-1,0),
                            acceleration:.zero,radius:Double(BallPhysics.radius),horizon:0.15) }
            for patch in mesh.patches {
                if let hit=patch.triangle.firstContact(position:center,velocity:SIMD3(0,-1,0),acceleration:.zero,
                                                     radius:Double(BallPhysics.radius),horizon:0.15) {
                    print("[W05 center contact] pocket=\(index) material=\(patch.material) time=\(hit.time) point=\(hit.point) normal=\(hit.normal) triangle=\(patch.triangle)")
                }
            }
            // The loaded corner leather is within one ball radius of the legacy center.
            // A sphere can legitimately hit that wall; an invented horizontal cap cannot.
            XCTAssertTrue(holeHits.allSatisfy { $0.normal.y < 0.999 },
                          "Pocket center must not acquire a fabricated horizontal lid")
            print("[W05 contact mesh] pocket=\(index) patches=\(mesh.patches.count) supportTime=\(first.time)")
        }
    }
    func testVerticalConcaveFaceRetainsNotch() throws {
        let points:[SIMD3<Double>]=[SIMD3(0,0,0),SIMD3(0,2,0),SIMD3(0,2,1),SIMD3(0,1,1),SIMD3(0,1,2),SIMD3(0,0,2)]
        let triangles=try PocketContactMesh.triangulate(points)
        XCTAssertEqual(triangles.count,4)
        let misses=triangles.compactMap { $0.firstContact(position:SIMD3(1,1.5,1.5),velocity:SIMD3(-1,0,0),
                                         acceleration:.zero,radius:0.1,horizon:2) }
        XCTAssertTrue(misses.isEmpty)
    }
}

final class PocketGeometryInjectionV63Tests: XCTestCase {
    @MainActor
    func testPortraitExportPitchCandidates() throws {
        let source=URL(fileURLWithPath:"/Users/song/projects/13.billiard_trainer/content/position_play/sequences/drill_c042__manual01-初级蛇彩走位 · 球形1-8杆.json")
        let decoder=JSONDecoder();decoder.dateDecodingStrategy = .iso8601
        let sequence=try decoder.decode(PositionPlaySequence.self,from:Data(contentsOf:source))
        let oneShot=SequenceVideoExporter.subSequence(sequence,stepIndex:0)
        for pitch:Float in [30,45,60] {
            var options=SequenceVideoExporter.Options.teachingVideo3D()
            options.size=CGSize(width:402,height:716)
            var config=SequenceVideoExporter.Perspective3DConfig();config.pitchDeg=pitch
            options.cameraMode = .perspective3D(config)
            let stills=SequenceVideoExporter.renderStills(sequence:oneShot,options:options)
            let shot=try XCTUnwrap(stills.first { $0.name == "s01_still" })
            let attachment=XCTAttachment(image:UIImage(cgImage:shot.image))
            attachment.name="portrait-pitch-\(Int(pitch))";attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    func testPottedSequenceEncodesAtTwoFrameRates() async throws {
        let source=URL(fileURLWithPath:"/Users/song/projects/13.billiard_trainer/content/position_play/sequences/drill_c042__manual01-初级蛇彩走位 · 球形1-8杆.json")
        let decoder=JSONDecoder();decoder.dateDecodingStrategy = .iso8601
        let sequence=try decoder.decode(PositionPlaySequence.self,from:Data(contentsOf:source))
        XCTAssertFalse(sequence.steps.isEmpty)
        let oneShot=SequenceVideoExporter.subSequence(sequence,stepIndex:0)
        let scene=AngleTrainingScene();scene.setupScene(enhancedRendering:false)
        let step=try XCTUnwrap(oneShot.steps.first)
        let prediction=try XCTUnwrap(PositionPlayShotSolver.solve(before:step.before,shot:step.shot,surfaceY:scene.surfaceY))
        XCTAssertTrue(prediction.hasFinalTableState)
        let recorder=try XCTUnwrap(prediction.recorder)
        // W17-A: default verdict is planar; W17-D attaches the scripted net tail on playback.
        XCTAssertTrue(prediction.objectPocketed,"Fixture must pot the object ball")
        XCTAssertTrue(recorder.isBallPocketed(ShotInput.targetBallName))
        let output=URL(fileURLWithPath:"/Users/song/projects/13.billiard_trainer/output/3d-v63/W08/encoded-sequence",isDirectory:true).appendingPathComponent(UUID().uuidString,isDirectory:true)
        print("[W08 encoded output] \(output.path)")
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let expectedPlayback = TrajectoryPlayback(recorder: recorder, surfaceY: scene.surfaceY + BallPhysics.radius)
        let captureNames = Set(recorder.collectionTailsByBallName.keys)
        XCTAssertEqual(captureNames,[ShotInput.targetBallName],"W17-D: the planar pot must carry a net tail")
        let netTail=try XCTUnwrap(recorder.collectionTailsByBallName[ShotInput.targetBallName])
        XCTAssertNotNil(netTail.samples);XCTAssertNil(netTail.fadeStart,"a ball resting in the net never fades")
        for speed: Float in [0.5, 1] {
        var durations:[Double]=[]
        for fps in [30,60] {
            var options=SequenceVideoExporter.Options.teachingVideo3D()
            options.size=CGSize(width:402,height:716);options.fps=fps
            options.playbackSpeed = speed
            var comparedFrames = 0
            var hiddenCaptures = Set<String>()
            options.motionFrameObserver = { _, time, positions, opacities, _ in
                for name in captureNames {
                    guard let expected = expectedPlayback.stateAt(ballName: name, time: time),
                          let actual = positions[name], let opacity = opacities[name],
                          let expectedOpacity = expectedPlayback.collectionOpacity(ballName: name, time: time) else {
                        XCTFail("Missing actual export capture state: \(name) at \(time)")
                        continue
                    }
                    XCTAssertEqual(actual.x, expected.position.x, accuracy: 0.00001)
                    XCTAssertEqual(actual.y, expected.position.y, accuracy: 0.00001)
                    XCTAssertEqual(actual.z, expected.position.z, accuracy: 0.00001)
                    XCTAssertEqual(opacity, expectedOpacity, accuracy: 0.00001)
                    if opacity <= 0.00001 { hiddenCaptures.insert(name) }
                }
                comparedFrames += 1
            }
            let url=try await SequenceVideoExporter.exportVideo(sequence:oneShot,options:options)
            XCTAssertGreaterThan(comparedFrames, 1)
            XCTAssertTrue(hiddenCaptures.isEmpty, "W17-D: a potted ball stays visible in the net (no fade) across the whole export")
            print("[W08 export states] speed=\(speed) fps=\(fps) comparedFrames=\(comparedFrames) captures=\(captureNames.count)")
            let data=try Data(contentsOf:url)
            XCTAssertGreaterThan(data.count,1024)
            try data.write(to:output.appendingPathComponent("capture-\(speed)x-\(fps)fps.mp4"))
            let asset=AVURLAsset(url:url)
            let duration=try await asset.load(.duration).seconds
            XCTAssertGreaterThan(duration,Double(prediction.duration))
            durations.append(duration)
            let tracks=try await asset.loadTracks(withMediaType:.video)
            let track=try XCTUnwrap(tracks.first)
            let rate=try await track.load(.nominalFrameRate)
            XCTAssertEqual(rate,Float(fps),accuracy:0.1)
            print("[W08 encoded sequence] speed=\(speed) fps=\(fps) duration=\(duration) bytes=\(data.count)")
        }
        XCTAssertEqual(durations[0],durations[1],accuracy:1.0/30,
            "Frame rate must not change the shot or its collection tail duration")
        }
    }

    @MainActor
    func testExportSettledFramesPreservePredictedBoardWhenSavedOutcomeDiffers() async throws {
        continueAfterFailure = false
        let source = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/content/position_play/sequences/drill_c039__manual01-直线球组合走位 · 球形1-8杆.json")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var fixture = try decoder.decode(PositionPlaySequence.self, from: Data(contentsOf: source))
        // W17-C: deliberately model a stale saved outcome in memory. The shot input and
        // all authored next-shot starts stay unchanged; no bundled content is rewritten.
        // A successful pot must not be resurrected by this saved "still on table" state.
        let target = fixture.steps[1].shot.targetKey
        fixture.steps[1].after.onTable[target] = try XCTUnwrap(fixture.steps[1].before.onTable[target])
        fixture.steps[1].potted.removeAll { $0 == target }
        fixture.steps[1].objectPocketed = false
        let sequence = fixture
        XCTAssertEqual(sequence.steps.count, 8)
        let scene = AngleTrainingScene(); scene.setupScene(enhancedRendering: false)
        var predictions: [UUID: ShotPrediction] = [:]
        for (index, step) in sequence.steps.enumerated() {
            let prediction = try XCTUnwrap(PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: scene.surfaceY))
            XCTAssertTrue(prediction.hasFinalTableState,
                "Shot \(index + 1) \(step.id): termination=\(String(describing: prediction.termination)), duration=\(prediction.duration), events=\(prediction.events)")
            predictions[step.id] = prediction
        }
        let second = sequence.steps[1]
        XCTAssertNotNil(second.after.onTable[second.shot.targetKey])
        XCTAssertTrue(try XCTUnwrap(predictions[second.id]).objectPocketed,
            "Fixture must exercise a real predicted pot that disagrees with the stale saved board")
        // Capture the real live consumer at each authored start and paused end.
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.configureSequence(sequence.steps)
        vm.enterSequenceMode()
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 402, height: 716))
        view.scene = vm.scene
        view.pointOfView = vm.scene.cameraNode
        let window = UIWindow(windowScene: try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene))
        let controller = UIViewController()
        controller.view = view
        window.rootViewController = controller
        window.makeKeyAndVisible()
        view.isPlaying = true
        defer { vm.exitSequenceMode(); view.isPlaying = false; window.isHidden = true }
        func visibleBoard() -> [String: SCNVector3] {
            vm.scene.allBallNodes.reduce(into: [:]) { result, entry in
                if !entry.value.isHidden && entry.value.opacity > 0 {
                    result[entry.key] = entry.value.worldPosition
                }
            }
        }
        var liveStarts: [UUID: [String: SCNVector3]] = [:]
        var liveEnds: [UUID: [String: SCNVector3]] = [:]
        var liveEvents: [UUID: [ShotEvent]] = [:]
        vm.sequenceShotEventsObserver = { id, events in
            XCTAssertNil(liveEvents[id], "Each shot must be consumed once")
            liveEvents[id] = events
        }
        for (index, step) in sequence.steps.enumerated() {
            vm.toggleSequencePlayback()
            XCTAssertEqual(vm.sequenceStepIndex, index)
            liveStarts[step.id] = visibleBoard()
            XCTAssertEqual(Set(visibleBoard().keys), Set(step.before.onTable.keys))
            for (key, point) in step.before.onTable {
                let expected = PositionPlayShotSolver.scenePoint(point, surfaceY: vm.scene.surfaceY)
                let actual = try XCTUnwrap(visibleBoard()[key])
                XCTAssertEqual(actual.x, expected.x, accuracy: 0.00001)
                XCTAssertEqual(actual.z, expected.z, accuracy: 0.00001)
            }
            vm.requestSequencePause()
            let deadline = Date().addingTimeInterval(45)
            while !vm.isSequencePaused, Date() < deadline {
                try await Task.sleep(for: .milliseconds(100))
            }
            XCTAssertTrue(vm.isSequencePaused)
            XCTAssertEqual(vm.sequenceStepIndex, index)
            liveEnds[step.id] = visibleBoard()
        }
        var frames: [UUID: Int] = [:]
        var observationFrames: [UUID: Int] = [:]
        var options = SequenceVideoExporter.Options.teachingVideo3D()
        options.size = CGSize(width: 402, height: 716)
        options.fps = 30
        var exportEventSteps = Set<UUID>()
        options.shotEventsObserver = { id, events in
            XCTAssertTrue(exportEventSteps.insert(id).inserted)
            guard let live = liveEvents[id] else { XCTFail("Missing live events"); return }
            XCTAssertFalse(live.isEmpty)
            XCTAssertEqual(events.count, live.count)
            for (actual, expected) in zip(events, live) {
                XCTAssertEqual(actual.time, expected.time, accuracy: 0.000001)
                switch (actual.kind, expected.kind) {
                case let (.ballBall(a, b), .ballBall(c, d)):
                    XCTAssertEqual(a, c); XCTAssertEqual(b, d)
                case let (.ballCushion(a), .ballCushion(b)):
                    XCTAssertEqual(a, b)
                case let (.pocket(a, p), .pocket(b, q)):
                    XCTAssertEqual(a, b); XCTAssertEqual(p, q)
                default: XCTFail("Different event kinds for shot \(id)")
                }
            }
        }
        func compareBoards(_ actual: [String: SCNVector3], _ expected: [String: SCNVector3]) {
            XCTAssertEqual(Set(actual.keys), Set(expected.keys))
            for (key, point) in expected {
                guard let value = actual[key] else { XCTFail("Missing ball: \(key)"); continue }
                XCTAssertEqual(value.x, point.x, accuracy: 0.00001)
                XCTAssertEqual(value.y, point.y, accuracy: 0.00001)
                XCTAssertEqual(value.z, point.z, accuracy: 0.00001)
            }
        }
        options.observationFrameObserver = { id, visible in
            guard let live = liveStarts[id] else { XCTFail("Unexpected start"); return }
            compareBoards(visible, live)
            observationFrames[id, default: 0] += 1
        }
        options.settledFrameObserver = { id, visible in
            guard let live = liveEnds[id] else { XCTFail("Unexpected end"); return }
            compareBoards(visible, live)
            guard let step = sequence.steps.first(where: { $0.id == id }),
                  let prediction = predictions[id] else { XCTFail("Unexpected step"); return }
            let expectedKeys = Set(step.before.onTable.keys.filter {
                !prediction.pocketedBalls.contains(PositionPlayShotSolver.predName(boardKey: $0, shot: step.shot))
            })
            XCTAssertEqual(Set(visible.keys), expectedKeys)
            for key in expectedKeys {
                guard let point = visible[key], let expected = prediction.finalPositions[
                    PositionPlayShotSolver.predName(boardKey: key, shot: step.shot)] else {
                    XCTFail("Missing settled ball: \(key)"); continue
                }
                XCTAssertEqual(point.x, expected.x, accuracy: 0.00001)
                XCTAssertEqual(point.y, scene.surfaceY + AngleSceneCalculator.ballRadius, accuracy: 0.00001)
                XCTAssertEqual(point.z, expected.z, accuracy: 0.00001)
            }
            frames[id, default: 0] += 1
        }
        let video = try await SequenceVideoExporter.exportVideo(sequence: sequence, options: options)
        let data = try Data(contentsOf: video)
        XCTAssertGreaterThan(data.count, 1024)
        for step in sequence.steps {
            XCTAssertGreaterThan(frames[step.id, default: 0], 0)
            XCTAssertGreaterThan(observationFrames[step.id, default: 0], 0)
        }
        XCTAssertEqual(exportEventSteps, Set(sequence.steps.map(\.id)))
        XCTAssertEqual(Set(liveEvents.keys), exportEventSteps)
        let output = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/output/3d-v63/W08")
            .appendingPathComponent("predicted-rest-\(UUID().uuidString).mp4")
        try data.write(to: output)
        print("[W08 predicted rest] frames=\(frames) video=\(output.path)")
    }

    func testFourthAuthoredShotReachesSettledState() throws {
        let source = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/content/position_play/sequences/drill_c039__manual01-直线球组合走位 · 球形1-8杆.json")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let sequence = try decoder.decode(PositionPlaySequence.self, from: Data(contentsOf: source))
        let step = sequence.steps[3]
        let prediction = try XCTUnwrap(PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: BTTablePhysics.surfaceY))
        let recorder = try XCTUnwrap(prediction.recorder)
        let boundaries = try PocketGeometryAsset.load().captureBoundaries()
        for handoff in recorder.localHandoffs {
            guard let pocketID = handoff.pocketID, let boundary = boundaries[pocketID],
                  let spans = recorder.localIntervalsByBallName[handoff.ballName] else { continue }
            print("[W08 shot4 handoff] \(handoff) plane=\(boundary.centerPlaneY) outline=\(boundary.outline)")
            if let span = spans.first(where: { $0.end.position.y <= boundary.centerPlaneY }) {
                print("[W08 shot4 plane] \(span) contained=\(boundary.containsProjection(span.end.position))")
            }
        }
        for name in recorder.framesByBallName.keys.sorted() {
            print("[W08 shot4 planar \(name)] \(recorder.framesByBallName[name]!.suffix(2))")
            if let spans = recorder.localIntervalsByBallName[name] {
                print("[W08 shot4 local \(name)] \(spans.suffix(2))")
            }
        }
        XCTAssertTrue(prediction.hasFinalTableState, "Shot 4: \(String(describing: prediction.termination))")
    }

    func testCornerSequenceSecondShotModelComparison() throws {
        let source = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/content/position_play/sequences/drill_c039__manual01-直线球组合走位 · 球形1-8杆.json")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let sequence = try decoder.decode(PositionPlaySequence.self, from: Data(contentsOf: source))
        let step = sequence.steps[1]
        let surfaceY = BTTablePhysics.surfaceY
        let cue = PositionPlayShotSolver.scenePoint(try XCTUnwrap(step.before.onTable[PositionPlayBall.cueKey]), surfaceY: surfaceY)
        let target = PositionPlayShotSolver.scenePoint(try XCTUnwrap(step.before.onTable[step.shot.targetKey]), surfaceY: surfaceY)
        let index = try XCTUnwrap(ShotIntent.pocketIndex(for: step.shot.pocket))
        let obstacles = step.before.onTable.compactMap { key, point -> ObstacleBall? in
            guard key != PositionPlayBall.cueKey, key != step.shot.targetKey else { return nil }
            return ObstacleBall(name: key, position: PositionPlayShotSolver.scenePoint(point, surfaceY: surfaceY))
        }
        var input = ShotInput(cueBall: cue, targetBall: target, pocketIndex: index,
            velocity: Float(step.shot.velocity), spinX: Float(step.shot.spinX), spinY: Float(step.shot.spinY), surfaceY: surfaceY, obstacles: obstacles)
        var fixedOffset: Float?
        for (label, model) in [("planar", EventDrivenEngine.SimulationModel.planarReference), ("local", .spatialPockets)] {
            input.simulationModel = model
            let prediction = ShotPredictor.predictForPositionSolve(input, aimOffset: fixedOffset)
            if fixedOffset == nil { fixedOffset = prediction.aimOffsetUsed }
            let pocket = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)[index]
            let nearest = prediction.objectPath.min { a, b in
                hypotf(a.x-pocket.x,a.z-pocket.z) < hypotf(b.x-pocket.x,b.z-pocket.z)
            }
            print("[W08 corner compare] model=\(label) termination=\(String(describing: prediction.termination)) potted=\(prediction.pocketedBalls) offset=\(String(describing: prediction.aimOffsetUsed)) nearest=\(String(describing: nearest)) final=\(String(describing: prediction.finalPositions[ShotInput.targetBallName]))")
            print("[W08 corner events \(label)] \(prediction.events.map { String(describing: $0) })")
            XCTAssertTrue(prediction.hasFinalTableState)
        }
    }

    @MainActor
    func testTwoCornerShotsExportWithoutRevivingPreviousCapture() async throws {
        continueAfterFailure = false
        let source = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/content/position_play/sequences/drill_c039__manual01-直线球组合走位 · 球形1-8杆.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var sequence = try decoder.decode(PositionPlaySequence.self, from: Data(contentsOf: source))
        sequence.steps = Array(sequence.steps.prefix(2))
        XCTAssertEqual(sequence.steps.count, 2)
        let preceding = sequence.steps[0].after.onTable
        let following = sequence.steps[1].before.onTable
        XCTAssertEqual(Set(preceding.keys), Set(following.keys))
        for (key, point) in preceding {
            let next = try XCTUnwrap(following[key])
            XCTAssertEqual(point.x, next.x)
            XCTAssertEqual(point.y, next.y)
        }
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        var playbacks: [UUID: TrajectoryPlayback] = [:]
        var captures: [UUID: Set<String>] = [:]
        for step in sequence.steps {
            let prediction = try XCTUnwrap(PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: scene.surfaceY))
            print("[W08 corner fixture] id=\(step.id) target=\(step.shot.targetKey) pocket=\(step.shot.pocket) feasible=\(prediction.feasible) reason=\(prediction.infeasibleReason) termination=\(String(describing: prediction.termination)) objectPocketed=\(prediction.objectPocketed) duration=\(prediction.duration) final=\(prediction.finalPositions) potted=\(prediction.pocketedBalls)")
            XCTAssertTrue(prediction.hasFinalTableState)
            XCTAssertTrue(prediction.objectPocketed)
            let recorder = try XCTUnwrap(prediction.recorder)
            // W17-A: planar verdict records pocket entries, not bag captures; W17-D attaches
            // the scripted net tail when the playback is built, so the comparison below is live.
            XCTAssertTrue(recorder.isBallPocketed(ShotInput.targetBallName))
            XCTAssertTrue(recorder.confirmedCaptures.isEmpty)
            playbacks[step.id] = TrajectoryPlayback(recorder: recorder, surfaceY: scene.surfaceY + BallPhysics.radius)
            captures[step.id] = Set(recorder.collectionTailsByBallName.keys)
            XCTAssertEqual(captures[step.id], [ShotInput.targetBallName], "W17-D net tail for the potted target")
        }
        let firstTarget = sequence.steps[0].shot.targetKey
        XCTAssertFalse(sequence.steps[1].before.onTable.keys.contains(firstTarget))
        var frames: [UUID: Int] = [:]
        var options = SequenceVideoExporter.Options.teachingVideo3D()
        options.size = CGSize(width: 402, height: 716)
        options.fps = 30
        options.motionFrameObserver = { id, time, positions, opacities, visibleKeys in
            guard let playback = playbacks[id], let names = captures[id] else {
                XCTFail("Unexpected exported step"); return
            }
            if id == sequence.steps[1].id {
                XCTAssertFalse(visibleKeys.contains(firstTarget), "Previous shot's captured ball must remain invisible")
            }
            for name in names {
                guard let expected = playback.stateAt(ballName: name, time: time),
                      let actual = positions[name], let opacity = opacities[name],
                      let expectedOpacity = playback.collectionOpacity(ballName: name, time: time) else {
                    XCTFail("Missing corner capture state"); return
                }
                XCTAssertEqual(actual.x, expected.position.x, accuracy: 0.00001)
                XCTAssertEqual(actual.y, expected.position.y, accuracy: 0.00001)
                XCTAssertEqual(actual.z, expected.position.z, accuracy: 0.00001)
                XCTAssertEqual(opacity, expectedOpacity, accuracy: 0.00001)
            }
            frames[id, default: 0] += 1
        }
        let video = try await SequenceVideoExporter.exportVideo(sequence: sequence, options: options)
        for step in sequence.steps { XCTAssertGreaterThan(frames[step.id, default: 0], 1) }
        let output = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/output/3d-v63/W08").appendingPathComponent("two-corner-\(UUID().uuidString).mp4")
        try Data(contentsOf: video).write(to: output)
        print("[W08 two corners] frames=\(frames) video=\(output.path)")
    }

    @MainActor
    func testDetachedTableMatchesSceneGeometryAndOwnsValueSnapshot() throws {
        let scene=AngleTrainingScene();scene.setupScene(mobileRendering:true)
        let table=try XCTUnwrap(scene.tableNode)
        let bed=try XCTUnwrap(MobileClothAlignment.measuredBedY(in:scene))
        let root=SCNNode(),detached=table.clone()
        root.addChildNode(detached)
        let pockets=AngleSceneCalculator.pocketPositions(surfaceY:scene.surfaceY)
        for index in [0,4] {
            let expected=try PocketContactMesh.load(from:scene,pocketIndex:index)
            let actual=try PocketContactMesh.load(table:detached,worldRoot:root,pocketID:expected.pocketID,
                center:pockets[index],surfaceY:scene.surfaceY,bedY:bed,alignCloth:true)
            XCTAssertEqual(actual.pocketID,expected.pocketID)
            XCTAssertEqual(actual.patches.count,expected.patches.count)
            XCTAssertGreaterThan(actual.patches.count,1000)
            for (a,b) in zip(actual.patches,expected.patches) {
                XCTAssertEqual(a.material,b.material)
                XCTAssertEqual(a.triangle.a,b.triangle.a)
                XCTAssertEqual(a.triangle.b,b.triangle.b)
                XCTAssertEqual(a.triangle.c,b.triangle.c)
            }
            // Results are numeric snapshots, not live node references.
            let original=try XCTUnwrap(actual.patches.first).triangle.a
            detached.position.y+=1
            XCTAssertEqual(actual.patches.first?.triangle.a,original)
            detached.position.y-=1
        }
        XCTAssertThrowsError(try PocketContactMesh.load(table:detached,worldRoot:root,pocketID:"bad",
            center:SCNVector3(Float.nan,0,0),surfaceY:scene.surfaceY,bedY:bed,alignCloth:true))
    }
}

extension PocketGeometryInjectionV63Tests {
    @MainActor
    func testBundledNumericAssetMatchesAllSixPocketsAndReusesSnapshot() throws {
        // Load before constructing any training scene in this test.
        let asset=try PocketGeometryAsset.load()
        XCTAssertTrue(asset === (try PocketGeometryAsset.load()))
        XCTAssertEqual(asset.pockets.count,6)
        XCTAssertEqual(Set(asset.regionsByPocketID.keys),Set(asset.pockets.map(\.pocketID)))
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)
        let scene=AngleTrainingScene();scene.setupScene(mobileRendering:true)
        XCTAssertEqual(asset.surfaceY,scene.surfaceY)
        XCTAssertEqual(asset.measuredBedY,try XCTUnwrap(MobileClothAlignment.measuredBedY(in:scene)))
        for index in asset.pockets.indices {
            let expected=try PocketContactMesh.load(from:scene,pocketIndex:index)
            let actual=asset.pockets[index]
            XCTAssertLessThanOrEqual(actual.maximumBedAdjustment,Double(asset.surfaceY.ulp))
            XCTAssertEqual(actual.maximumBedAdjustment,expected.maximumBedAdjustment)
            let region=try XCTUnwrap(asset.regionsByPocketID[actual.pocketID])
            XCTAssertEqual(region.center.x,Double(centers[index].x))
            XCTAssertEqual(region.center.z,Double(centers[index].z))
            XCTAssertEqual(region.halfExtent,PocketContactMesh.localHalfExtent)
            XCTAssertEqual(actual.pocketID,expected.pocketID)
            XCTAssertEqual(actual.patches.count,expected.patches.count)
            for (a,b) in zip(actual.patches,expected.patches) {
                XCTAssertEqual(a.material,b.material)
                XCTAssertEqual(a.triangle.a,b.triangle.a)
                XCTAssertEqual(a.triangle.b,b.triangle.b)
                XCTAssertEqual(a.triangle.c,b.triangle.c)
            }
        }
    }
}

extension PocketGeometryInjectionV63Tests {
    func testRealPocketMeshCouplesFallingAndSupportedBalls() throws {
        typealias V=SIMD3<Double>
        let asset=try PocketGeometryAsset.load(),radius=Double(BallPhysics.radius)
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)
        for index in [0,4] {
            let inward=index == 0 ? V(1/sqrt(2),0,1/sqrt(2)) : V(0,0,1)
            let center=centers[index]
            let base=V(Double(center.x),Double(asset.surfaceY)+radius,Double(center.z))+inward*0.15
            let initial=[LocalPocketSimulation.State(time:0,position:base+V(0,2*radius+0.005,0),velocity:.zero,omega:.zero),
                         .init(time:0,position:base,velocity:.zero,omega:.zero)]
            let solver=LocalPocketSimulation(surfaces:asset.pockets[index].patches.map{.init(triangle:$0.triangle,restitution:0.3,friction:0.2)},
                radius:radius,gravity:V(0,-9.81,0),tolerance:1e-6)
            let result=try solver.advanceTogether(from:initial,duration:0.045,maxStep:0.01,pairRestitution:0.8,pairFriction:0)
            XCTAssertEqual(result.time,sqrt(2*0.005/9.81),accuracy:1e-8,"pocket \(index)")
            XCTAssertEqual(result.states[0].velocity.y,0.8*sqrt(2*9.81*0.005),accuracy:1e-7)
            XCTAssertEqual(result.states[1].velocity.y,0,accuracy:1e-7)
            XCTAssertEqual(result.states[1].position.y,base.y,accuracy:1e-8)
            XCTAssertTrue(result.constraints.contains{$0.b != nil})
            XCTAssertTrue(result.constraints.contains{$0.b == nil})
        }
    }
}

extension PocketGeometryInjectionV63Tests {
    func testMixedImmediateEntryKeepsIndependentPlanarContactAtSameTime() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        func make(_ local:Bool)->EventDrivenEngine {
            let e=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
            e.setBall(.init(position:SCNVector3(0,asset.surfaceY+r,0),velocity:SCNVector3(0.5,0,0),
                angularVelocity:SCNVector3(0,0,-0.5/r),state:.rolling,name:"a"))
            e.setBall(.init(position:SCNVector3(2*r,asset.surfaceY+r,0),velocity:SCNVector3Zero,
                angularVelocity:SCNVector3Zero,state:.stationary,name:"b"))
            if local {
                let c=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
                e.setBall(.init(position:SCNVector3(c.x,asset.surfaceY+r,c.z+0.12),velocity:SCNVector3(0,0,0.5),
                    angularVelocity:SCNVector3(0.5/r,0,0),state:.rolling,name:"local"))
            }
            return e
        }
        let mixed=make(true),reference=make(false)
        let event=try XCTUnwrap(mixed.findNextEvent(maxTimeRemaining:0))
        XCTAssertEqual(event.time,0)
        guard case .ballBall(let a,let b)=event.type else { return XCTFail("Fixture must start with a due collision") }
        XCTAssertEqual(Set([a,b]),Set(["a","b"]))
        try mixed.simulateMixedWithLocalPockets(maxTime:0.001,pairRestitution:0.8,pairFriction:0)
        try reference.simulateMixedWithLocalPockets(maxTime:0.001,pairRestitution:0.8,pairFriction:0)
        let hits=mixed.resolvedEvents.indices.filter{if case .ballBall=mixed.resolvedEvents[$0] { return true };return false}
        XCTAssertEqual(hits.count,1)
        XCTAssertEqual(hits.first.map{mixed.resolvedEventTimes[$0]},0)
        XCTAssertEqual(mixed.getTrajectoryRecorder().localHandoffs.first?.state.time,0)
        for name in ["a","b"] {
            let x=try XCTUnwrap(mixed.getBall(name)),y=try XCTUnwrap(reference.getBall(name))
            XCTAssertEqual(x.position.x,y.position.x)
            XCTAssertEqual(x.velocity.x,y.velocity.x)
            XCTAssertEqual(x.angularVelocity.z,y.angularVelocity.z)
        }
    }

    func testMixedSymmetricSimultaneousImpactAtHighSpeedsIsDeterministic() throws {
        typealias V=SIMD3<Double>
        func v(_ x:SCNVector3)->V { V(Double(x.x),Double(x.y),Double(x.z)) }
        func length(_ x:V)->Double { sqrt(x.x*x.x+x.y*x.y+x.z*x.z) }
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        func energy(_ values:[BallState])->Double {
            values.reduce(0.0) { total,ball in
                let linear=0.5*pow(length(v(ball.velocity)),2)
                let rotational=0.2*Double(r)*Double(r)*pow(length(v(ball.angularVelocity)),2)
                return total+linear+rotational+Double(TablePhysics.gravity)*Double(ball.position.y)
            }
        }
        for speed:Float in [2,8,12] {
            func run(_ step:Double) throws -> EventDrivenEngine {
                let e=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
                for (name,x):(String,Float) in [("left",-0.04),("right",0.04)] {
                    e.setBall(.init(position:SCNVector3(center.x+x,asset.surfaceY+r+0.02,center.z+0.17),
                        velocity:SCNVector3(0,0,speed),angularVelocity:SCNVector3Zero,state:.sliding,name:name))
                }
                e.setBall(.init(position:SCNVector3(center.x,asset.surfaceY+r,center.z+0.225),
                    velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,state:.stationary,name:"target"))
                let initialEnergy=energy(e.getAllBalls())
                try e.simulateMixedWithLocalPockets(maxTime:0.025/Double(speed)+0.001,maxStep:step,pairRestitution:0.8,pairFriction:0)
                let hits=e.resolvedEvents.indices.filter { if case .ballBall=e.resolvedEvents[$0] { return true };return false }
                XCTAssertEqual(hits.count,2,"Two simultaneous contacts, speed=\(speed)")
                if hits.count==2 { XCTAssertEqual(e.resolvedEventTimes[hits[0]],e.resolvedEventTimes[hits[1]]) }
                let left=try XCTUnwrap(e.getBall("left")),right=try XCTUnwrap(e.getBall("right")),target=try XCTUnwrap(e.getBall("target"))
                XCTAssertEqual(left.velocity.x,-right.velocity.x,accuracy:1e-6)
                XCTAssertEqual(left.velocity.z,right.velocity.z,accuracy:1e-6)
                XCTAssertEqual(target.velocity.x,0,accuracy:1e-6)
                XCTAssertGreaterThan(target.velocity.z,0)
                XCTAssertGreaterThanOrEqual(target.position.y,asset.surfaceY+r-1e-6)
                XCTAssertLessThanOrEqual(energy(e.getAllBalls()),initialEnergy+0.001)
                let spans=try ["left","right","target"].map { try XCTUnwrap(e.getTrajectoryRecorder().localIntervalsByBallName[$0]) }
                for a in spans.indices { for b in spans.indices where b>a {
                    assertContinuousPairClearance([spans[a],spans[b]],radius:Double(r),tolerance:1e-6)
                } }
                return e
            }
            let coarse=try run(0.0025),repeatRun=try run(0.0025),fine=try run(0.00125)
            XCTAssertEqual(coarse.resolvedEventTimes,repeatRun.resolvedEventTimes)
            var maximumError=0.0
            for name in ["left","right","target"] {
                let a=try XCTUnwrap(coarse.getBall(name)),b=try XCTUnwrap(repeatRun.getBall(name)),c=try XCTUnwrap(fine.getBall(name))
                XCTAssertEqual(v(a.position),v(b.position))
                XCTAssertEqual(v(a.velocity),v(b.velocity))
                XCTAssertEqual(v(a.angularVelocity),v(b.angularVelocity))
                let error=max(length(v(a.position)-v(c.position)),0.0025*length(v(a.velocity)-v(c.velocity)),
                              Double(r)*0.0025*length(v(a.angularVelocity)-v(c.angularVelocity)))
                maximumError=max(maximumError,error)
                XCTAssertLessThanOrEqual(error,4e-6,"Shared spatial error budget, speed=\(speed), ball=\(name)")
            }
            print("[W06 high speed symmetric] speed=\(speed) maximumSpatialError=\(maximumError)")
        }
    }

    func testMixedStaticContactsRespectAcceptedTimeAndContinuation() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        let startY=asset.surfaceY+r+0.02
        func make()->EventDrivenEngine {
            let e=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
            e.setBall(.init(position:SCNVector3(center.x+0.02,startY,center.z+0.12),
                velocity:SCNVector3(0,-0.5,0),angularVelocity:SCNVector3Zero,state:.sliding,name:"air"))
            e.setBall(.init(position:SCNVector3(0.5,asset.surfaceY+r,0),velocity:SCNVector3Zero,
                angularVelocity:SCNVector3Zero,state:.stationary,name:"rest"))
            return e
        }
        let whole=make(),split=make()
        try whole.simulateMixedWithLocalPockets(maxTime:0.08,pairRestitution:0.8,pairFriction:0)
        try split.simulateMixedWithLocalPockets(maxTime:0.01,pairRestitution:0.8,pairFriction:0)
        XCTAssertTrue(split.getTrajectoryRecorder().localStaticContacts.isEmpty)
        try split.simulateMixedWithLocalPockets(maxTime:0.0337,pairRestitution:0.8,pairFriction:0)
        XCTAssertTrue(split.getTrajectoryRecorder().localStaticContacts.allSatisfy{$0.contact.time<=0.0337})
        try split.simulateMixedWithLocalPockets(maxTime:0.08,pairRestitution:0.8,pairFriction:0)
        let a=whole.getTrajectoryRecorder().localStaticContacts,b=split.getTrajectoryRecorder().localStaticContacts
        let first=try XCTUnwrap(a.first)
        let gap=Double(startY)-Double(asset.surfaceY)-Double(r),g=Double(TablePhysics.gravity)
        let expected=2*gap/(0.5+sqrt(0.25+2*g*gap))
        XCTAssertEqual(first.contact.time,expected,accuracy:1e-8)
        XCTAssertEqual(first.ballName,"air")
        XCTAssertEqual(first.geometryID,"table-contact-geometry")
        XCTAssertEqual(a.count,b.count)
        for (x,y) in zip(a,b) {
            XCTAssertEqual(x.ballName,y.ballName)
            XCTAssertEqual(x.geometryID,y.geometryID)
            XCTAssertEqual(x.contact.time,y.contact.time)
            XCTAssertEqual(x.contact.surface,y.contact.surface)
            XCTAssertEqual(x.contact.normal,y.contact.normal)
            XCTAssertTrue(asset.tablePatches.indices.contains(x.contact.surface))
        }
        XCTAssertTrue(zip(a,a.dropFirst()).allSatisfy{$0.contact.time<=$1.contact.time})
    }

    func testMixedMainLoopReentersPocketRegionAfterPlanarCollision() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        for (name,offset,speed):(String,Float,Float) in [("cue",0.12,0.5),("incoming",0.45,-0.5)] {
            engine.setBall(.init(position:SCNVector3(center.x,asset.surfaceY+r,center.z+offset),
                velocity:SCNVector3(0,0,speed),angularVelocity:SCNVector3(speed/r,0,0),state:.rolling,name:name))
        }
        try engine.simulateMixedWithLocalPockets(maxTime:1.4,pairRestitution:0.8,pairFriction:0)
        let handoffs=engine.getTrajectoryRecorder().localHandoffs.filter{$0.ballName=="cue"}
        print("[W06 reentry] handoffs=\(handoffs) events=\(engine.resolvedEvents) states=\(engine.getAllBalls())")
        XCTAssertGreaterThanOrEqual(handoffs.count,3)
        guard handoffs.count>=3 else { return }
        XCTAssertEqual(handoffs[0].kind,.entered)
        XCTAssertEqual(handoffs[1].kind,.returned)
        XCTAssertEqual(handoffs[2].kind,.entered)
        XCTAssertTrue(handoffs.allSatisfy{$0.pocketID=="pocket_4"})
        XCTAssertLessThan(handoffs[0].state.time,handoffs[1].state.time)
        XCTAssertLessThan(handoffs[1].state.time,handoffs[2].state.time)
        let contact=try XCTUnwrap(engine.resolvedEvents.firstIndex { if case .ballBall = $0 { return true };return false })
        XCTAssertEqual(engine.firstBallBallCollisionTime,engine.resolvedEventTimes[contact],
                       "First contact metadata must use the same absolute clock")
        XCTAssertTrue(zip(engine.resolvedEventTimes,engine.resolvedEventTimes.dropFirst()).allSatisfy{$0<=$1})
        XCTAssertEqual(engine.spatialTime,1.4)
        XCTAssertTrue(engine.getTrajectoryRecorder().pocketEntries.isEmpty)
    }

    func testMixedContinuationPreservesTrajectoryAcrossArbitraryRequestBoundary() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        func make()->EventDrivenEngine {
            let e=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
            e.setBall(.init(position:SCNVector3(center.x,asset.surfaceY+r+0.02,center.z+0.17),
                velocity:SCNVector3(0,0,0.5),angularVelocity:SCNVector3Zero,state:.sliding,name:"air"))
            e.setBall(.init(position:SCNVector3(center.x,asset.surfaceY+r,center.z+0.225),
                velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,state:.stationary,name:"table"))
            return e
        }
        let whole=make(),split=make()
        try whole.simulateMixedWithLocalPockets(maxTime:0.0307,pairRestitution:0.8,pairFriction:0)
        try split.simulateMixedWithLocalPockets(maxTime:0.0001,pairRestitution:0.8,pairFriction:0)
        XCTAssertTrue(split.resolvedEvents.isEmpty,"Do not publish speculative impact before its time")
        XCTAssertEqual(split.getTrajectoryRecorder().localHandoffs.count,1,"Planar receiver is not promoted early")
        XCTAssertThrowsError(try split.simulateMixedWithLocalPockets(maxTime:0.00015,pairRestitution:0.9,pairFriction:0))
        XCTAssertEqual(split.spatialTime,0.0001,"Changing coefficients must not consume stale motion")
        try split.simulateMixedWithLocalPockets(maxTime:0.00015,pairRestitution:0.8,pairFriction:0)
        XCTAssertTrue(split.resolvedEvents.isEmpty)
        try split.simulateMixedWithLocalPockets(maxTime:0.0073,pairRestitution:0.8,pairFriction:0)
        try split.simulateMixedWithLocalPockets(maxTime:0.0109,pairRestitution:0.8,pairFriction:0)
        try split.simulateMixedWithLocalPockets(maxTime:0.0307,pairRestitution:0.8,pairFriction:0)
        let frameCount=split.getTrajectoryRecorder().framesByBallName["air"]?.count
        try split.simulateMixedWithLocalPockets(maxTime:0.0307,pairRestitution:0.8,pairFriction:0)
        XCTAssertEqual(split.getTrajectoryRecorder().framesByBallName["air"]?.count,frameCount)
        let a=try XCTUnwrap(whole.getTrajectoryRecorder().localIntervalsByBallName["air"]?.last?.end)
        let b=try XCTUnwrap(split.getTrajectoryRecorder().localIntervalsByBallName["air"]?.last?.end)
        XCTAssertEqual(a.time,b.time)
        XCTAssertEqual(a.position,b.position,"Request cuts must not change the accepted spatial trajectory")
        XCTAssertEqual(a.velocity,b.velocity)
        XCTAssertEqual(a.omega,b.omega)
        XCTAssertEqual(whole.resolvedEventTimes,split.resolvedEventTimes)
        XCTAssertEqual(whole.getTrajectoryRecorder().localHandoffs.count,split.getTrajectoryRecorder().localHandoffs.count)
    }

    func testMixedMainLoopTwoConsecutiveBallsFallThroughSamePocket() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)
        func energy(_ balls:[BallState])->Double {
            balls.reduce(0) { total,b in
                let speed=Double(b.velocity.x)*Double(b.velocity.x)+Double(b.velocity.y)*Double(b.velocity.y)+Double(b.velocity.z)*Double(b.velocity.z)
                let spin=Double(b.angularVelocity.x)*Double(b.angularVelocity.x)+Double(b.angularVelocity.y)*Double(b.angularVelocity.y)+Double(b.angularVelocity.z)*Double(b.angularVelocity.z)
                return total+0.5*speed+0.2*Double(r)*Double(r)*spin+Double(TablePhysics.gravity)*Double(b.position.y)
            }
        }
        for index in [0,4] {
            let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
            let direction=index == 0 ? SCNVector3(1/sqrtf(2),0,1/sqrtf(2)) : SCNVector3(0,0,1)
            for ball in 0..<2 {
                var p=centers[index]+direction*(0.36+Float(ball)*0.065);p.y=asset.surfaceY+r
                let velocity=direction * -0.5
                engine.setBall(.init(position:p,velocity:velocity,
                    angularVelocity:SCNVector3(velocity.z/r,0,-velocity.x/r),state:.rolling,name:"ball_\(ball)"))
            }
            let initialEnergy=energy(engine.getAllBalls())
            try engine.simulateMixedWithLocalPockets(maxTime:1.4,pairRestitution:0.8,pairFriction:0)
            XCTAssertEqual(engine.spatialTime,1.4)
            let recorder=engine.getTrajectoryRecorder()
            for name in ["ball_0","ball_1"] {
                XCTAssertLessThan(try XCTUnwrap(engine.getBall(name)).position.y,asset.surfaceY-r)
                let handoffs=recorder.localHandoffs.filter{$0.ballName==name}
                XCTAssertEqual(handoffs.count,1)
                XCTAssertEqual(handoffs.first?.pocketID,"pocket_\(index)")
            }
            let spans=try ["ball_0","ball_1"].map { try XCTUnwrap(recorder.localIntervalsByBallName[$0]) }
            assertContinuousPairClearance(spans,radius:Double(r),tolerance:1e-6)
            XCTAssertLessThanOrEqual(energy(engine.getAllBalls()),initialEnergy+0.001)
            XCTAssertTrue(recorder.pocketEntries.isEmpty)
        }
    }

    func testMixedMainLoopReturnsSupportedBallToPlanarMotion() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        engine.setBall(.init(position:SCNVector3(center.x,asset.surfaceY+r,center.z+0.12),velocity:SCNVector3(0,0,0.5),
            angularVelocity:SCNVector3(0.5/r,0,0),state:.rolling,name:"cue"))
        engine.setBall(.init(position:SCNVector3(0.5,asset.surfaceY+r,0),velocity:SCNVector3Zero,
            angularVelocity:SCNVector3Zero,state:.stationary,name:"rest"))
        try engine.simulateMixedWithLocalPockets(maxTime:0.5,pairRestitution:0.8,pairFriction:0)
        let handoffs=engine.getTrajectoryRecorder().localHandoffs
        XCTAssertEqual(handoffs.count,2)
        XCTAssertEqual(handoffs.first?.kind,.entered)
        XCTAssertEqual(handoffs.last?.kind,.returned)
        let ball=try XCTUnwrap(engine.getBall("cue"))
        XCTAssertEqual(ball.position.y,asset.surfaceY+r,accuracy:1e-7)
        XCTAssertEqual(ball.velocity.y,0)
        XCTAssertGreaterThan(ball.velocity.z,0)
        XCTAssertEqual(ball.state,.rolling)
    }

    func testMixedMainLoopOwnsTwoPocketRegionsAndPreservesDistantRestBall() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        for index in [0,4] {
            let direction=index == 0 ? SCNVector3(1/sqrtf(2),0,1/sqrtf(2)) : SCNVector3(0,0,1)
            var position=centers[index]+direction*0.36;position.y=asset.surfaceY+r
            let velocity=direction * -0.5
            engine.setBall(.init(position:position,velocity:velocity,
                angularVelocity:SCNVector3(velocity.z/r,0,-velocity.x/r),state:.rolling,name:"ball_\(index)"))
        }
        let rest=BallState(position:SCNVector3(0,asset.surfaceY+r,0),velocity:SCNVector3Zero,
                           angularVelocity:SCNVector3Zero,state:.stationary,name:"rest")
        engine.setBall(rest)
        try engine.simulateMixedWithLocalPockets(maxTime:1.1,pairRestitution:0.8,pairFriction:0)
        XCTAssertEqual(engine.spatialTime,1.1)
        for index in [0,4] {
            let ball=try XCTUnwrap(engine.getBall("ball_\(index)"))
            XCTAssertLessThan(ball.position.y,asset.surfaceY-r)
            XCTAssertLessThan(ball.velocity.y,0)
            let handoffs=engine.getTrajectoryRecorder().localHandoffs.filter{$0.ballName=="ball_\(index)"}
            XCTAssertEqual(handoffs.count,1)
            XCTAssertEqual(handoffs.first?.pocketID,"pocket_\(index)")
        }
        let result=try XCTUnwrap(engine.getBall("rest"))
        XCTAssertEqual(result.position.x,rest.position.x)
        XCTAssertEqual(result.position.y,rest.position.y)
        XCTAssertEqual(result.position.z,rest.position.z)
        XCTAssertEqual(result.velocity.x,rest.velocity.x)
        XCTAssertEqual(result.velocity.y,rest.velocity.y)
        XCTAssertEqual(result.velocity.z,rest.velocity.z)
        XCTAssertEqual(result.state,.stationary)
        XCTAssertTrue(engine.getTrajectoryRecorder().pocketEntries.isEmpty)
    }

    func testMixedMainLoopTransfersImpactToPlanarNeighborOutsidePocketRegion() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        engine.setBall(.init(position:SCNVector3(center.x,asset.surfaceY+r+0.02,center.z+0.17),
                             velocity:SCNVector3(0,0,0.5),angularVelocity:SCNVector3Zero,state:.sliding,name:"air"))
        engine.setBall(.init(position:SCNVector3(center.x,asset.surfaceY+r,center.z+0.225),
                             velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,state:.stationary,name:"table"))
        try engine.simulateMixedWithLocalPockets(maxTime:0.015,pairRestitution:0.8,pairFriction:0)
        XCTAssertEqual(engine.spatialTime,0.015)
        let target=try XCTUnwrap(engine.getBall("table"))
        XCTAssertGreaterThan(target.velocity.z,0.1,"Cross-owner collision must transfer momentum")
        XCTAssertEqual(engine.resolvedEvents.filter { if case .ballBall = $0 { return true };return false }.count,1)
        XCTAssertEqual(engine.resolvedEventTimes.count,engine.resolvedEvents.count)
        XCTAssertNotNil(engine.firstBallBallCollisionTime)
        XCTAssertGreaterThanOrEqual(target.position.y,asset.surfaceY+r-1e-6)
        let recorder=engine.getTrajectoryRecorder()
        XCTAssertTrue(recorder.localHandoffs.contains{$0.ballName=="table" && $0.kind == .entered})
        XCTAssertTrue(recorder.pocketEntries.isEmpty)
        XCTAssertFalse(try XCTUnwrap(recorder.localIntervalsByBallName["air"]).isEmpty)
    }

    func testFullTableContactGeometryCoversDomainExternalNeighbors() throws {
        typealias V=SIMD3<Double>
        let asset=try PocketGeometryAsset.load(),r=Double(BallPhysics.radius),y=Double(asset.surfaceY)
        func key(_ patch:PocketContactMesh.Patch)->String {
            "\(patch.material)|\(patch.triangle.a)|\(patch.triangle.b)|\(patch.triangle.c)"
        }
        let full=Set(asset.tablePatches.map(key))
        XCTAssertGreaterThan(full.count,0)
        for mesh in asset.pockets {
            XCTAssertTrue(Set(mesh.patches.map(key)).isSubset(of:full),"Pocket geometry must remain an exact subset")
        }
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)
        var probes=[V(0,y+3*r,0)]
        for (i,center) in centers.enumerated() {
            let region=try XCTUnwrap(asset.regionsByPocketID["pocket_\(i)"])
            let inward=simd_normalize(V(-Double(center.x),0,-Double(center.z)))
            let edgeDistance=region.halfExtent/max(abs(inward.x),abs(inward.z))
            let p=V(Double(center.x),y+3*r,Double(center.z))+inward*(edgeDistance+2*r)
            XCTAssertFalse(region.contains(p))
            probes.append(p)
        }
        let solver=LocalPocketSimulation(surfaces:asset.tablePatches.map {
            .init(triangle:$0.triangle,restitution:0.3,friction:0.2)
        },radius:r,gravity:V(0,-9.81,0),tolerance:1e-6)
        for p in probes {
            let hit=try XCTUnwrap(asset.tablePatches.compactMap {
                $0.triangle.firstContact(position:p,velocity:V(0,-1,0),acceleration:.zero,radius:r,horizon:3*r)
            }.min(by:{$0.time<$1.time}))
            XCTAssertEqual(p.y-hit.time,y+r,accuracy:1e-7,
                           "Real table support must exist beyond the pocket ownership window")
            let base=p+V(0,-hit.time,0)
            let response=try solver.resolveContactGroup([
                .init(time:1,position:base+V(0,2*r,0),velocity:V(0,-0.5,0),omega:.zero),
                .init(time:1,position:base,velocity:.zero,omega:.zero)
            ],accelerations:[V(0,-9.81,0),.zero],pairRestitution:0.8,pairFriction:0)
            XCTAssertEqual(response.states[0].velocity.y,0.4,accuracy:1e-8)
            XCTAssertEqual(response.states[1].velocity.y,0,accuracy:1e-8)
            XCTAssertTrue(response.constraints.contains{$0.b == nil})
            XCTAssertTrue(response.constraints.contains{$0.b != nil})
        }
    }

    func testCrossOwnerImpactResolvesTableSupportInSameEvent() throws {
        typealias V=SIMD3<Double>
        let r=Double(BallPhysics.radius),y=0.8
        let floor=PocketContactTriangle(a:V(-1,y,-1),b:V(1,y,-1),c:V(0,y,1))
        let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0.3,friction:0)],
            radius:r,gravity:V(0,-9.81,0),tolerance:1e-6)
        let incoming=[LocalPocketSimulation.State(time:0.2,position:V(0,y+3*r,0),velocity:V(0,-0.5,0),omega:.zero),
                      .init(time:0.2,position:V(0,y+r,0),velocity:.zero,omega:.zero)]
        let result=try solver.resolveContactGroup(incoming,accelerations:[V(0,-9.81,0),.zero],
                                                  pairRestitution:0.8,pairFriction:0)
        XCTAssertEqual(result.time,0.2)
        XCTAssertEqual(result.states[0].velocity.y,0.4,accuracy:1e-10)
        XCTAssertEqual(result.states[1].velocity.y,0,accuracy:1e-10,
                       "The planar receiver must not be driven through its support")
        XCTAssertTrue(result.constraints.contains{$0.b == nil})
        XCTAssertTrue(result.constraints.contains{$0.b != nil})
        XCTAssertEqual(result.states[0].position.y,incoming[0].position.y,accuracy:1e-12)
        XCTAssertEqual(result.states[1].position.y,incoming[1].position.y,accuracy:1e-12)
        XCTAssertTrue(result.intervals.allSatisfy(\.isEmpty),"Instant response must not invent motion intervals")
        var mismatched=incoming;mismatched[1].time=0.1
        XCTAssertThrowsError(try solver.resolveContactGroup(mismatched,accelerations:[.zero,.zero],
                                                           pairRestitution:0.8,pairFriction:0))
    }

    func testCrossOwnerLowSpeedPredictionMatchesPlanarEvolutionAcceleration() throws {
        typealias V=SIMD3<Double>
        let r=BallPhysics.radius,y:Float=0.8+r
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:0.8))
        let a=BallState(position:SCNVector3(0,y,0),velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,state:.stationary,name:"local")
        let b=BallState(position:SCNVector3(2*r+1e-8,y,0),velocity:SCNVector3(-0.0005,0,0),
            angularVelocity:SCNVector3Zero,state:.sliding,name:"planar")
        engine.setBall(a);engine.setBall(b)
        let start=LocalPocketSimulation.State(time:0,position:V(0,Double(y),0),velocity:.zero,omega:.zero)
        var end=start;end.time=0.001
        let interval=LocalPocketSimulation.Interval(start:start,duration:end.time,acceleration:.zero,angularAcceleration:.zero,end:end)
        let local=LocalPocketSimulation.Result(states:[start,end],contacts:[],maxCorrection:0,rejectedSteps:0,intervals:[interval])
        let hit=try XCTUnwrap(engine.firstLocalPlanarContact(local:["local":local],until:end.time))
        let gap=Double(b.position.x)-2*Double(r),speed = -Double(b.velocity.x)
        let deceleration=Double(SpinPhysics.slidingFriction*TablePhysics.gravity)
        let expected=2*gap/(speed+sqrt(speed*speed-2*deceleration*gap))
        XCTAssertEqual(hit.time,expected,accuracy:1e-10,
                       "Prediction must use the acceleration of the actual sliding equation")
    }

    func testCrossOwnerPredictionUsesHeightAndStopsAtPlanarEvent() throws {
        typealias V=SIMD3<Double>
        let asset=try PocketGeometryAsset.load(),r=Double(BallPhysics.radius)
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        let base=V(Double(center.x),Double(asset.surfaceY)+r,Double(center.z)+0.15)
        let start=LocalPocketSimulation.State(time:0,position:base+V(0,2*r+0.005,0),velocity:.zero,omega:.zero)
        let solver=LocalPocketSimulation(surfaces:asset.pockets[4].patches.map{.init(triangle:$0.triangle,restitution:0.3,friction:0.2)},
            radius:r,gravity:V(0,-9.81,0),tolerance:1e-6)
        let prediction=try solver.run(from:start,duration:0.045,maxStep:0.0025)
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        engine.setBall(.init(position:SCNVector3(Float(start.position.x),Float(start.position.y),Float(start.position.z)),
            velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,state:.sliding,name:"falling"))
        let target=BallState(position:SCNVector3(Float(base.x),Float(base.y),Float(base.z)),velocity:SCNVector3Zero,
            angularVelocity:SCNVector3Zero,state:.stationary,name:"target")
        engine.setBall(target)
        XCTAssertNil(try engine.firstLocalPlanarContact(local:["falling":prediction],until:0.01),
                     "Equal XZ does not imply contact while the spheres are vertically separated")
        let hit=try XCTUnwrap(engine.firstLocalPlanarContact(local:["falling":prediction],until:0.045))
        // The planar target's stored Float position is the actual input.
        let gap=start.position.y-Double(target.position.y)-2*r
        XCTAssertEqual(hit.time,sqrt(2*gap/9.81),accuracy:1e-8)
        XCTAssertEqual(hit.localBall,"falling");XCTAssertEqual(hit.planarBall,"target")
        XCTAssertEqual(hit.planarState.velocity,.zero)
        XCTAssertEqual(hit.normal.y,-1,accuracy:1e-10)
        var spinning=target;spinning.state = .spinning;spinning.angularVelocity.y=0.0001
        engine.setBall(spinning)
        XCTAssertNil(try engine.firstLocalPlanarContact(local:["falling":prediction],until:0.045),
                     "A preceding planar transition must be processed before predicting beyond it")
    }

    func testPlanarEventQueryExcludesLocalOwnersWithoutRemovingBalls() throws {
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:0.8))
        let r=BallPhysics.radius,y:Float=0.8+r
        let a=BallState(position:SCNVector3(-0.2,y,0),velocity:SCNVector3(0.5,0,0),
            angularVelocity:SCNVector3(0,0,-0.5/r),state:.rolling,name:"a")
        let b=BallState(position:SCNVector3(0,y,0),velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,state:.stationary,name:"b")
        engine.setBall(a);engine.setBall(b)
        let original=try XCTUnwrap(engine.findNextEvent(maxTimeRemaining:0.5))
        guard case .ballBall(let first,let second)=original.type else { return XCTFail("Fixture must schedule the pair") }
        XCTAssertEqual(Set([first,second]),Set(["a","b"]))
        XCTAssertNil(engine.findNextEvent(maxTimeRemaining:0.5,excluding:["a"]))
        XCTAssertNil(engine.findNextEvent(maxTimeRemaining:0.5,excluding:["b"]))
        XCTAssertEqual(engine.getAllBalls().count,2)
        XCTAssertEqual(engine.getBall("a")?.position.x,a.position.x)
        let restored=try XCTUnwrap(engine.findNextEvent(maxTimeRemaining:0.5))
        XCTAssertEqual(restored.time,original.time)
    }

    func testMainSpatialContinuationKeepsDoubleClockAndOwnership() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        let ball=BallState(position:SCNVector3(center.x,asset.surfaceY+r,center.z+0.36),velocity:SCNVector3(0,0,-0.5),
            angularVelocity:SCNVector3(-0.5/r,0,0),state:.rolling,name:"cue")
        let whole=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        let split=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        whole.setBall(ball);split.setBall(ball)
        try whole.simulateWithLocalPockets(maxTime:1.1)
        try split.simulateWithLocalPockets(maxTime:0.6)
        let count=split.getTrajectoryRecorder().localIntervalsByBallName["cue"]?.count
        let frameCount=split.getTrajectoryRecorder().framesByBallName["cue"]?.count
        try split.simulateWithLocalPockets(maxTime:0.6)
        XCTAssertEqual(split.getTrajectoryRecorder().localIntervalsByBallName["cue"]?.count,count)
        XCTAssertEqual(split.getTrajectoryRecorder().framesByBallName["cue"]?.count,frameCount)
        try split.simulateWithLocalPockets(maxTime:1.1)
        let a=try XCTUnwrap(whole.getTrajectoryRecorder().localIntervalsByBallName["cue"]?.last?.end)
        let b=try XCTUnwrap(split.getTrajectoryRecorder().localIntervalsByBallName["cue"]?.last?.end)
        XCTAssertEqual(a.time,b.time)
        XCTAssertEqual(a.position,b.position)
        XCTAssertEqual(a.velocity,b.velocity)
        XCTAssertEqual(a.omega,b.omega)
        XCTAssertEqual(split.getTrajectoryRecorder().localHandoffs.count,1,"Continuation must not enter twice")
        for axis in 0..<3 {
            XCTAssertEqual(a.position[axis],b.position[axis],accuracy:1e-6)
            XCTAssertEqual(a.velocity[axis],b.velocity[axis],accuracy:1e-6)
        }
    }

    func testMainEngineOwnsNaturalPocketDescentBeforeLegacyCapture() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)
        for index in [0,4] {
            let direction=index == 0 ? SCNVector3(1/sqrtf(2),0,1/sqrtf(2)) : SCNVector3(0,0,1)
            var position=centers[index]+direction*0.36;position.y=asset.surfaceY+r
            let velocity=direction * -0.5
            let initial=BallState(position:position,velocity:velocity,
                angularVelocity:SCNVector3(velocity.z/r,0,-velocity.x/r),state:.rolling,name:"cue")
            let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
            engine.setBall(initial)
            try engine.simulateWithLocalPockets(maxTime:1.1)
            let final=try XCTUnwrap(engine.getBall("cue")),recorder=engine.getTrajectoryRecorder()
            XCTAssertLessThan(final.position.y,asset.surfaceY-r)
            XCTAssertEqual(try XCTUnwrap(engine.spatialTime),1.1,accuracy:1e-12)
            XCTAssertEqual(recorder.localHandoffs.count,1)
            XCTAssertEqual(recorder.localHandoffs.first?.pocketID,"pocket_\(index)")
            XCTAssertTrue(recorder.pocketEntries.isEmpty,"No old snap/clear capture on the local path")
            let spans=try XCTUnwrap(recorder.localIntervalsByBallName["cue"])
            XCTAssertFalse(spans.isEmpty)
            XCTAssertEqual(spans.first?.start.time,recorder.localHandoffs.first?.state.time)
            XCTAssertEqual(try XCTUnwrap(spans.last?.end.time),1.1,accuracy:1e-12)
            XCTAssertLessThan(final.velocity.y,0)
            print("[W06 engine descent] pocket=\(index) entry=\(recorder.localHandoffs[0].state.time) final=\(final)")
        }
    }

    func testMainEngineReturnsFromLocalRegionToPlanarMotion() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        let velocity=SCNVector3(0,0,0.5)
        engine.setBall(.init(position:SCNVector3(center.x,asset.surfaceY+r,center.z+0.12),velocity:velocity,
            angularVelocity:SCNVector3(velocity.z/r,0,0),state:.rolling,name:"cue"))
        try engine.simulateWithLocalPockets(maxTime:0.5)
        let recorder=engine.getTrajectoryRecorder(),final=try XCTUnwrap(engine.getBall("cue"))
        XCTAssertEqual(recorder.localHandoffs.count,2)
        XCTAssertEqual(recorder.localHandoffs.first?.kind,.entered)
        XCTAssertEqual(recorder.localHandoffs.last?.kind,.returned)
        XCTAssertEqual(final.position.y,asset.surfaceY+r,accuracy:1e-7)
        XCTAssertGreaterThan(final.position.z,center.z+Float(PocketContactMesh.localHalfExtent))
        XCTAssertTrue(recorder.pocketEntries.isEmpty)
    }

    func testRealPocketApproachBoundariesStillHavePlanarSupport() throws {
        typealias V=SIMD3<Double>
        func length(_ v:V)->Double { sqrt(v.x*v.x+v.y*v.y+v.z*v.z) }
        let asset=try PocketGeometryAsset.load(),radius=Double(BallPhysics.radius)
        for mesh in asset.pockets {
            let region=try XCTUnwrap(asset.regionsByPocketID[mesh.pocketID])
            let inward=V(region.center.x == 0 ? 0 : (region.center.x>0 ? -1 : 1),0,region.center.z>0 ? -1 : 1)
            let direction=inward/length(inward),velocity = -direction*0.5
            var start=region.center+direction*(2*region.halfExtent)
            start.y=Double(asset.surfaceY)+radius
            let time=try XCTUnwrap(region.firstCrossing(position:start,velocity:velocity,acceleration:.zero,
                horizon:1,direction:.entering))
            let boundary=start+velocity*time
            let above=boundary+V(0,radius,0)
            let contact=try XCTUnwrap(mesh.patches.compactMap {
                $0.triangle.firstContact(position:above,velocity:V(0,-1,0),acceleration:.zero,
                                         radius:radius,horizon:2*radius)
            }.min(by:{$0.time<$1.time}))
            let supported=above+V(0,-contact.time,0)
            let solver=LocalPocketSimulation(surfaces:mesh.patches.map{.init(triangle:$0.triangle,restitution:0.3,friction:0.2)},
                radius:radius,gravity:V(0,-9.81,0),tolerance:1e-6)
            var tangent = -velocity
            tangent.y = -(tangent.x*contact.normal.x+tangent.z*contact.normal.z)/contact.normal.y
            let outgoing=LocalPocketSimulation.State(time:time,position:supported,velocity:tangent,omega:.zero)
            let nearest=mesh.patches.enumerated().map { i,patch in
                let delta=supported-patch.triangle.closestPoint(to:supported),distance=length(delta)
                return "\(i):d=\(distance),n=\(delta/distance),vertices=\(patch.triangle)"
            }
            let touching=mesh.patches.indices.filter {
                length(supported-mesh.patches[$0].triangle.closestPoint(to:supported))<=radius+1e-10
            }
            print("[W06 boundary contacts] pocket=\(mesh.pocketID) contacts=\(touching.map{nearest[$0]})")
            let returned=try XCTUnwrap(solver.planarReturn(from:outgoing,region:region,surfaceY:Double(asset.surfaceY)),
                                      "Representative approach boundary must still be planar: \(mesh.pocketID), \(supported)")
            XCTAssertEqual(returned.position.x,supported.x)
            XCTAssertEqual(returned.position.z,supported.z)
            XCTAssertEqual(returned.velocity.x,outgoing.velocity.x)
            XCTAssertEqual(returned.velocity.z,outgoing.velocity.z)
            XCTAssertEqual(returned.velocity.y,0)
            XCTAssertEqual(returned.time,time)
            XCTAssertLessThanOrEqual(abs(returned.position.y-supported.y),4*solver.tolerance)
            print("[W06 boundary support] pocket=\(mesh.pocketID) entry=\(time) point=\(supported)")
        }
    }

    func testLocalOwnershipReturnsSupportedBallAndRejectsStaleReentry() throws {
        typealias V=SIMD3<Double>
        let floor=PocketContactTriangle(a:V(-2,0,-2),b:V(2,0,-2),c:V(0,0,2))
        let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0.3,friction:0)],
            radius:0.1,gravity:V(0,-9.81,0),tolerance:1e-6)
        let region=PocketLocalRegion(center:.zero,halfExtent:0.2)
        let initial=LocalPocketSimulation.State(time:1,position:V(-0.2,0.1,0),velocity:V(1,0,0),omega:V(0,0,-10))
        var ownership=LocalPocketOwnership()
        try ownership.enter(ballName:"cue",pocketID:"pocket_0",state:initial)
        let entry=try XCTUnwrap(ownership.entries["cue"])
        XCTAssertThrowsError(try ownership.enter(ballName:"cue",pocketID:"pocket_0",state:initial))
        XCTAssertNil(try ownership.returnToPlanar(ballName:"cue",pocketID:"pocket_0",revision:entry.revision,
            solver:solver,region:region,surfaceY:0),"The entering boundary is not an outgoing handoff")
        let run=try solver.run(from:initial,duration:0.4,maxStep:0.01)
        let end=try XCTUnwrap(run.states.last)
        try ownership.commit(states:["cue":end],revisions:["cue":entry.revision])
        let updated=try XCTUnwrap(ownership.entries["cue"])
        XCTAssertThrowsError(try ownership.commit(states:["cue":end],revisions:["cue":entry.revision]))
        let returned=try XCTUnwrap(ownership.returnToPlanar(ballName:"cue",pocketID:"pocket_0",revision:updated.revision,
            solver:solver,region:region,surfaceY:0))
        XCTAssertEqual(returned.time,end.time)
        XCTAssertEqual(returned.position,end.position)
        XCTAssertEqual(returned.velocity,end.velocity)
        XCTAssertEqual(returned.omega,end.omega)
        XCTAssertNil(ownership.entries["cue"])
        var reversed=returned;reversed.velocity.x = -1;reversed.omega.z=10
        try ownership.enter(ballName:"cue",pocketID:"pocket_0",state:reversed)
        XCTAssertNotEqual(ownership.entries["cue"]?.revision,updated.revision)
        XCTAssertThrowsError(try ownership.commit(states:["cue":end],revisions:["cue":updated.revision]))
    }

    func testLocalReturnRejectsAirborneAndWallContactAndCommitsAtomically() throws {
        typealias V=SIMD3<Double>
        let floor=PocketContactTriangle(a:V(-2,0,-2),b:V(2,0,-2),c:V(0,0,2))
        let wall=PocketContactTriangle(a:V(0.3,-1,-1),b:V(0.3,1,-1),c:V(0.3,0,1))
        let solver=LocalPocketSimulation(surfaces:[floor,wall].map{.init(triangle:$0,restitution:0.3,friction:0.2)},
            radius:0.1,gravity:V(0,-9.81,0),tolerance:1e-6)
        let region=PocketLocalRegion(center:.zero,halfExtent:0.2)
        var state=LocalPocketSimulation.State(time:0,position:V(0.2,0.1,0),velocity:V(1,0,0),omega:.zero)
        XCTAssertNil(solver.planarReturn(from:state,region:region,surfaceY:0),"A ball touching a wall stays local")
        state.position.x = -0.21;state.velocity.x = -1;state.velocity.y=0.01
        XCTAssertNil(solver.planarReturn(from:state,region:region,surfaceY:0))
        state.velocity.y=0;state.position.y=0.101
        XCTAssertNil(solver.planarReturn(from:state,region:region,surfaceY:0),"An unsupported sphere cannot be flattened")
        var ownership=LocalPocketOwnership()
        try ownership.enter(ballName:"a",pocketID:"pocket_0",state:state)
        try ownership.enter(ballName:"b",pocketID:"pocket_0",state:state)
        let a=try XCTUnwrap(ownership.entries["a"]),b=try XCTUnwrap(ownership.entries["b"])
        var later=state;later.time=1
        XCTAssertThrowsError(try ownership.commit(states:["a":later,"b":state],revisions:["a":a.revision,"b":b.revision]))
        XCTAssertEqual(ownership.entries["a"]?.state.time,0)
        XCTAssertEqual(ownership.entries["b"]?.revision,b.revision)
    }

    func testLocalRegionCrossingsDoNotUseCaptureOrTimeEpsilon() throws {
        typealias V=SIMD3<Double>
        let region=PocketLocalRegion(center:.zero,halfExtent:1)
        XCTAssertEqual(try XCTUnwrap(region.firstCrossing(position:V(-2,5,0),velocity:V(2,0,0),acceleration:.zero,
            horizon:2,direction:.entering)),0.5,accuracy:1e-14)
        XCTAssertEqual(try XCTUnwrap(region.firstCrossing(position:V(-2,5,0),velocity:V(2,0,0),acceleration:.zero,
            horizon:2,direction:.leaving)),1.5,accuracy:1e-14)
        // x=-2+2t-t² touches x=-1 at t=1 without entering.
        XCTAssertNil(region.firstCrossing(position:V(-2,0,0),velocity:V(2,0,0),acceleration:V(-2,0,0),
            horizon:1,direction:.entering))
        XCTAssertNil(region.firstCrossing(position:V(-2,0,2),velocity:V(2,0,0),acceleration:.zero,
            horizon:2,direction:.entering),"An infinite side plane is not the finite region")
        XCTAssertEqual(try XCTUnwrap(region.firstCrossing(position:V(-1,0,0),velocity:V(1,0,0),acceleration:.zero,
            horizon:1,direction:.entering)),0)
        // x=2t-t² leaves at x=1 only tangentially, then leaves at x=-1.
        XCTAssertEqual(try XCTUnwrap(region.firstCrossing(position:.zero,velocity:V(2,0,0),acceleration:V(-2,0,0),
            horizon:3,direction:.leaving)),1+sqrt(2),accuracy:1e-14)
        XCTAssertEqual(try XCTUnwrap(region.firstCrossing(position:V(-2,0,0),velocity:V(1e9,0,0),acceleration:.zero,
            horizon:1e-8,direction:.entering)),1e-9,accuracy:1e-22)
    }

    /// Certify every overlapping polynomial interval with a conservative
    /// displacement bound; include corrected endpoints separately. This does
    /// not call the production CCD or assume a display sampling frequency.
    private func assertContinuousPairClearance(_ spans:[[LocalPocketSimulation.Interval]],radius:Double,
                                               tolerance:Double,file:StaticString=#filePath,line:UInt=#line) {
        guard spans.count == 2 else { return XCTFail("Expected two paths",file:file,line:line) }
        typealias V=SIMD3<Double>
        func length(_ v:V)->Double { sqrt(v.x*v.x+v.y*v.y+v.z*v.z) }
        let minimum=2*radius-4*tolerance
        var i=0,j=0
        while i<spans[0].count && j<spans[1].count {
            let a=spans[0][i],b=spans[1][j]
            let start=max(a.start.time,b.start.time),end=min(a.end.time,b.end.time)
            if end>=start {
                var pending=[(start,end)]
                while let (lo,hi)=pending.popLast() {
                    let mid=lo+(hi-lo)/2
                    guard let sa=a.sample(at:mid,beforeEndpoint:true),let sb=b.sample(at:mid,beforeEndpoint:true) else {
                        return XCTFail("Missing interval sample at \(mid)",file:file,line:line)
                    }
                    let distance=length(sb.position-sa.position),half=(hi-lo)/2
                    guard distance>=minimum else {
                        return XCTFail("Continuous gap \(distance-2*radius) at \(mid)",file:file,line:line)
                    }
                    let bound=length(sb.velocity-sa.velocity)*half+0.5*length(b.acceleration-a.acceleration)*half*half
                    if distance-bound>=minimum { continue }
                    guard mid>lo && mid<hi else {
                        return XCTFail("Cannot certify pair clearance at \(mid)",file:file,line:line)
                    }
                    pending.append((lo,mid));pending.append((mid,hi))
                }
                for t in [start,end] {
                    guard let sa=a.sample(at:t),let sb=b.sample(at:t) else {
                        return XCTFail("Missing corrected endpoint",file:file,line:line)
                    }
                    XCTAssertGreaterThanOrEqual(length(sb.position-sa.position),minimum,file:file,line:line)
                }
            }
            if a.end.time<=b.end.time { i+=1 }
            if b.end.time<=a.end.time { j+=1 }
        }
    }

    func testFallingBallsCollideBelowRealPocketSupport() throws {
        typealias V=SIMD3<Double>
        func length(_ v:V)->Double { sqrt(v.x*v.x+v.y*v.y+v.z*v.z) }
        let asset=try PocketGeometryAsset.load(),radius=Double(BallPhysics.radius)
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)
        for index in [0,4] {
            let inward=index == 0 ? V(1/sqrt(2),0,1/sqrt(2)) : V(0,0,1)
            let c=centers[index],center=V(Double(c.x),Double(asset.surfaceY)+radius,Double(c.z))
            let solver=LocalPocketSimulation(surfaces:asset.pockets[index].patches.map {
                .init(triangle:$0.triangle,restitution:0.3,friction:0.2)
            },radius:radius,gravity:V(0,-9.81,0),tolerance:1e-6)
            let velocity = -inward*0.5
            let seed=LocalPocketSimulation.State(time:0,position:center+inward*0.12,velocity:velocity,
                omega:V(velocity.z/radius,0,-velocity.x/radius))
            let fallen=try XCTUnwrap(solver.run(from:seed,duration:0.4,maxStep:0.001).states.last)
            let trailing=LocalPocketSimulation.State(time:fallen.time,position:fallen.position+V(0,2*radius+0.01,0),
                velocity:fallen.velocity+V(0,-0.5,0),omega:fallen.omega)
            let initial=[fallen,trailing]
            for state in initial {
                XCTAssertLessThan(state.position.y+radius,Double(asset.surfaceY))
                XCTAssertGreaterThanOrEqual(try XCTUnwrap(solver.surfaces.map {
                    length(state.position-$0.triangle.closestPoint(to:state.position))
                }.min()),radius-1e-12)
            }
            func energy(_ states:[LocalPocketSimulation.State])->Double {
                states.reduce(0) { $0+0.5*pow(length($1.velocity),2)+0.2*radius*radius*pow(length($1.omega),2)+9.81*$1.position.y }
            }
            let hit=try solver.advanceTogether(from:initial,duration:0.1,maxStep:0.0025,pairRestitution:0.9,pairFriction:0.05)
            XCTAssertTrue(hit.constraints.contains{$0.b != nil},"Actual falling pair impact required")
            XCTAssertEqual(hit.time,fallen.time+0.01/0.5,accuracy:1e-8)
            assertContinuousPairClearance(hit.intervals,radius:radius,tolerance:solver.tolerance)
            XCTAssertLessThanOrEqual(energy(hit.states),energy(initial)+0.001)
            let tail=try solver.advanceTogether(from:hit.states,duration:0.5-hit.time,maxStep:0.0025,
                pairRestitution:0.9,pairFriction:0.05)
            XCTAssertEqual(tail.time,0.5,accuracy:1e-12)
            assertContinuousPairClearance(tail.intervals,radius:radius,tolerance:solver.tolerance)
            XCTAssertLessThanOrEqual(energy(tail.states),energy(initial)+0.001)
            print("[W06 falling pair impact] pocket=\(index) time=\(hit.time) states=\(tail.states)")
        }
    }

    func testContinuousClearanceRejectsCrossingWithSafeEndpoints() {
        typealias V=SIMD3<Double>
        let moving=LocalPocketSimulation.State(time:0,position:V(-1,0,0),velocity:V(2,0,0),omega:.zero)
        let fixed=LocalPocketSimulation.State(time:0,position:.zero,velocity:.zero,omega:.zero)
        let a=LocalPocketSimulation.Interval(start:moving,duration:1,acceleration:.zero,angularAcceleration:.zero,
            end:.init(time:1,position:V(1,0,0),velocity:moving.velocity,omega:.zero))
        let b=LocalPocketSimulation.Interval(start:fixed,duration:1,acceleration:.zero,angularAcceleration:.zero,
            end:.init(time:1,position:.zero,velocity:.zero,omega:.zero))
        XCTExpectFailure("Endpoint-only checks miss the spheres crossing at t=0.5") {
            assertContinuousPairClearance([[a],[b]],radius:0.1,tolerance:1e-6)
        }
    }

    func testTwoConsecutiveBallsActuallyFallThroughEachPocket() throws {
        try runConsecutivePocketEntry(includeBag:false)
    }

    func testTwoConsecutiveTableBallsEnterAndInteractInsideBundledBag() throws {
        try runConsecutivePocketEntry(includeBag:true)
    }

    private func runConsecutivePocketEntry(includeBag:Bool) throws {
        typealias V=SIMD3<Double>
        func length(_ v:V)->Double { sqrt(v.x*v.x+v.y*v.y+v.z*v.z) }
        let asset=try PocketGeometryAsset.load(),radius=Double(BallPhysics.radius)
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)
        for index in [0,4] {
            let inward=index == 0 ? V(1/sqrt(2),0,1/sqrt(2)) : V(0,0,1)
            let c=centers[index],center=V(Double(c.x),Double(asset.surfaceY)+radius,Double(c.z))
            let velocity = -inward*0.5
            var states=try [0.12,0.19].map { offset -> LocalPocketSimulation.State in
                let above=center+inward*offset+V(0,radius,0)
                let landing=try XCTUnwrap(asset.pockets[index].patches.compactMap {
                    $0.triangle.firstContact(position:above,velocity:V(0,-1,0),acceleration:.zero,
                                             radius:radius,horizon:2*radius)
                }.min(by:{$0.time<$1.time}))
                let position=above+V(0,-landing.time,0)
                let clearance=try XCTUnwrap(asset.pockets[index].patches.map {
                    length(position-$0.triangle.closestPoint(to:position))
                }.min())
                XCTAssertGreaterThanOrEqual(clearance,radius-1e-12)
                return .init(time:0,position:position,velocity:velocity,
                             omega:V(velocity.z/radius,0,-velocity.x/radius))
            }
            func energy(_ values:[LocalPocketSimulation.State])->Double {
                values.reduce(0) { $0+0.5*pow(length($1.velocity),2)+0.2*radius*radius*pow(length($1.omega),2)+9.81*$1.position.y }
            }
            let initialEnergy=energy(states),end=0.8
            var surfaces=asset.pockets[index].patches.map {
                .init(triangle:$0.triangle,restitution:0.3,friction:0.2)
            } as [LocalPocketSimulation.Surface]
            var bagBottom:Double?
            if includeBag {
                let pocketID=asset.pockets[index].pocketID
                let bag=try PocketBagEnvelope.build(pocketID:pocketID,
                    strands:try XCTUnwrap(asset.bagSourceTrianglesByPocketID[pocketID]),surfaceY:Double(asset.surfaceY))
                bagBottom=bag.bottom
                surfaces+=bag.triangles.map{.init(triangle:$0,restitution:0.1,friction:0.2,
                    rollingFriction:Double(SpinPhysics.rollingFriction),spinFriction:Double(SpinPhysics.spinFriction))}
            }
            let solver=LocalPocketSimulation(surfaces:surfaces,radius:radius,gravity:V(0,-9.81,0),tolerance:1e-6)
            var epochs=0,pairEvents=0,rows:[[Double]]=[]
            while states[0].time<end {
                epochs+=1
                guard epochs<100 else { return XCTFail("Repeated events at pocket \(index)") }
                let step=try solver.advanceTogether(from:states,duration:end-states[0].time,
                    maxStep:0.0025,pairRestitution:0.9,pairFriction:0.05)
                assertContinuousPairClearance(step.intervals,radius:radius,tolerance:solver.tolerance)
                pairEvents+=step.constraints.filter{$0.b != nil}.count
                states=step.states
                XCTAssertTrue(states.allSatisfy{$0.time == step.time})
                XCTAssertGreaterThanOrEqual(length(states[1].position-states[0].position),2*radius-4e-6)
                XCTAssertLessThanOrEqual(energy(states),initialEnergy+0.001)
                for (ball,path) in step.intervals.enumerated() {
                    for interval in path {
                        let state=interval.end
                        if let bottom=bagBottom {
                            XCTAssertGreaterThanOrEqual(state.position.y,bottom+radius-4*solver.tolerance)
                        }
                        rows.append([Double(ball),state.time,state.position.x,state.position.y,state.position.z,
                            state.velocity.x,state.velocity.y,state.velocity.z,state.omega.x,state.omega.y,state.omega.z])
                    }
                }
            }
            XCTAssertEqual(states[0].time,end,accuracy:1e-12)
            for state in states {
                XCTAssertLessThan(state.position.y,Double(asset.surfaceY)-radius,
                                  "Both balls must actually descend through pocket \(index)")
            }
            if includeBag { XCTAssertGreaterThan(pairEvents,0,"Two entering balls must interact inside the bag") }
            let attachment=XCTAttachment(data:try JSONSerialization.data(withJSONObject:rows),uniformTypeIdentifier:"public.json")
            attachment.name="consecutive-entry-\(index)-bag-\(includeBag)";attachment.lifetime = .keepAlways;add(attachment)
            print("[W07 consecutive fall] pocket=\(index) bag=\(includeBag) states=\(states) epochs=\(epochs) pairs=\(pairEvents)")
        }
    }

    func testLoadedPressureContactDoesNotTurnIntoAnImpactAtHalfStep() throws {
        typealias V=SIMD3<Double>
        let asset=try PocketGeometryAsset.load(),radius=Double(BallPhysics.radius)
        let time=0.08938354101148452,dt=6.103515625e-7
        let states:[LocalPocketSimulation.State]=[
            .init(time:time,position:V(-1.2458996271124012,0.828575011342763,-0.5717721153686776),
                  velocity:V(0.003370256996167363,-7.853988515947055e-23,0.012113271659013967),
                  omega:V(-9.950157906973379,0.9224555445569895,2.912365942535428)),
            .init(time:time,position:V(-1.2075767004242146,0.8285750113427628,-0.6141687621450533),
                  velocity:V(-0.016116200598399008,-1.19861030193901e-22,-0.005500812061992417),
                  omega:V(-3.5702046210315608,-1.3718516411643922,10.460897571926699))]
        let solver=LocalPocketSimulation(surfaces:asset.pockets[0].patches.map{.init(triangle:$0.triangle,restitution:0.3,friction:0.2)},
            radius:radius,gravity:V(0,-9.81,0),tolerance:1e-6)
        let whole=try solver.advanceTogether(from:states,duration:dt,maxStep:dt,pairRestitution:0.9,pairFriction:0.05,useSharedErrorControl:false)
        let half=try solver.advanceTogether(from:states,duration:dt/2,maxStep:dt/2,pairRestitution:0.9,pairFriction:0.05,useSharedErrorControl:false)
        let fine=try solver.advanceTogether(from:half.states,duration:time+dt-half.time,maxStep:dt/2,pairRestitution:0.9,pairFriction:0.05,useSharedErrorControl:false)
        print("[W06 pressure split] whole=\(whole.states) half=\(half.states) fine=\(fine.states)")
        XCTAssertTrue(whole.constraints.isEmpty)
        XCTAssertTrue(half.constraints.isEmpty)
        XCTAssertTrue(fine.constraints.isEmpty,"Splitting a sustained pressure step must not create an instantaneous impact")
        XCTAssertEqual(fine.time,whole.time,accuracy:1e-12)
    }

    func testCapturedCornerStateStaticCorrectionsRemainPairCompatible() throws {
        typealias V=SIMD3<Double>
        func length(_ v:V)->Double { sqrt(v.x*v.x+v.y*v.y+v.z*v.z) }
        let asset=try PocketGeometryAsset.load(),radius=Double(BallPhysics.radius),time=0.15536576580755695
        let states:[LocalPocketSimulation.State]=[
            .init(time:time,position:V(-1.2456063483648288,0.8285750113427639,-0.5707173961674449),
                  velocity:V(0.004928236323948591,-6.084496084545281e-24,0.017689334647132397),
                  omega:V(0.6192360165678096,0.2308761190843525,-0.17231240030832498)),
            .init(time:time,position:V(-1.2091933717885006,0.8285750113427638,-0.614765296284059),
                  velocity:V(-0.03045028238661787,-1.8347816972892975e-15,-0.011556944283374544),
                  omega:V(-0.4058587189735167,-1.2226590750278556,1.065005455848155))]
        let surfaces=asset.pockets[0].patches.map{LocalPocketSimulation.Surface(triangle:$0.triangle,restitution:0.3,friction:0.2)}
        let solver=LocalPocketSimulation(surfaces:surfaces,radius:radius,gravity:V(0,-9.81,0),tolerance:1e-6)
        for (i,s) in states.enumerated() {
            let distances=surfaces.enumerated().map { j,surface in
                (j,length(s.position-surface.triangle.closestPoint(to:s.position)))
            }.sorted{$0.1<$1.1}
            print("[W06 captured geometry] ball=\(i) nearest=\(distances.prefix(4)) radius=\(radius)")
            let next=try solver.run(from:s,duration:1e-8,maxStep:1e-8)
            print("[W06 captured static shift] ball=\(i) correction=\(next.maxCorrection) end=\(next.states.last!)")
            // This historical input deliberately retains the old group's
            // sub-budget static penetration; validate repaired output below.
            XCTAssertLessThan(distances[0].1,radius)
        }
        let repaired=try solver.advanceTogether(from:states,duration:1e-6,maxStep:1e-6,pairRestitution:0.9,pairFriction:0.05)
        for s in repaired.states {
            let distance=surfaces.map{length(s.position-$0.triangle.closestPoint(to:s.position))}.min()!
            XCTAssertGreaterThanOrEqual(distance,radius-1e-12,"Accepted group state must satisfy static geometry")
        }
        XCTAssertGreaterThanOrEqual(length(repaired.states[0].position-repaired.states[1].position),2*radius-1e-12)
    }

    func testTwoBallsApproachTheSameRealPocketOnOneClock() throws {
        typealias V=SIMD3<Double>
        func length(_ v:V)->Double { sqrt(v.x*v.x+v.y*v.y+v.z*v.z) }
        let asset=try PocketGeometryAsset.load(),radius=Double(BallPhysics.radius)
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)
        for index in [0,4] {
            let inward=index == 0 ? V(1/sqrt(2),0,1/sqrt(2)) : V(0,0,1)
            let across=V(inward.z,0,-inward.x),c=centers[index]
            let center=V(Double(c.x),Double(asset.surfaceY)+radius,Double(c.z))
            var states=try [-1.0,1.0].map { side -> LocalPocketSimulation.State in
                let offset=inward*0.15+across*(side*(radius+0.005))
                let velocity = -offset*(0.5/length(offset))
                // The loaded cloth has local vertex-height variation. Place
                // the fixture on its actual sphere-offset surface, retaining
                // the chosen horizontal arrangement and clearance assertion.
                let above=center+offset+V(0,radius,0)
                let landing=try XCTUnwrap(asset.pockets[index].patches.compactMap {
                    $0.triangle.firstContact(position:above,velocity:V(0,-1,0),acceleration:.zero,
                                             radius:radius,horizon:2*radius)
                }.min(by:{$0.time<$1.time}))
                let position=above+V(0,-landing.time,0)
                return .init(time:0,position:position,velocity:velocity,
                             omega:V(velocity.z/radius,0,-velocity.x/radius))
            }
            func energy(_ values:[LocalPocketSimulation.State])->Double {
                values.reduce(0) { total,s in
                    let linear=0.5*pow(length(s.velocity),2)
                    let rotational=0.2*radius*radius*pow(length(s.omega),2)
                    return total+linear+rotational+9.81*s.position.y
                }
            }
            for (ball,state) in states.enumerated() {
                let nearest=asset.pockets[index].patches.map{length(state.position-$0.triangle.closestPoint(to:state.position))}.min()!
                XCTAssertGreaterThanOrEqual(nearest,radius-1e-12,"Initial fixture must not penetrate the table mesh")
                let message="[W06 fixture clearance] pocket=\(index) ball=\(ball) nearest=\(nearest) radius=\(radius)\n"
                FileHandle.standardError.write(Data(message.utf8))
            }
            let initialEnergy=energy(states),end=0.35
            let solver=LocalPocketSimulation(surfaces:asset.pockets[index].patches.map{.init(triangle:$0.triangle,restitution:0.3,friction:0.2)},
                radius:radius,gravity:V(0,-9.81,0),tolerance:1e-6)
            var events=0,epochs=0,minDistance=Double.infinity,minY=Double.infinity
            while states[0].time<end {
                epochs+=1
                XCTAssertLessThan(epochs,100,"Repeated same-time event at pocket \(index)")
                guard epochs<100 else { return }
                let before=states[0].time
                let step=try solver.advanceTogether(from:states,duration:end-before,maxStep:0.01,pairRestitution:0.9,pairFriction:0.05)
                assertContinuousPairClearance(step.intervals,radius:radius,tolerance:solver.tolerance)
                XCTAssertTrue(step.time>before || !step.constraints.isEmpty)
                XCTAssertTrue(step.states.allSatisfy{$0.time == step.time})
                states=step.states
                if !step.constraints.isEmpty { events+=1 }
                minDistance=min(minDistance,length(states[0].position-states[1].position))
                minY=min(minY,states.map{$0.position.y}.min()!)
                XCTAssertGreaterThanOrEqual(length(states[0].position-states[1].position),2*radius-4e-6)
                XCTAssertLessThanOrEqual(energy(states),initialEnergy+0.001)
                print("[W06 real pair] pocket=\(index) time=\(step.time) events=\(events) states=\(states)")
            }
            XCTAssertEqual(states[0].time,end,accuracy:1e-12)
            XCTAssertGreaterThan(events,0)
            print("[W06 real pair final] pocket=\(index) minDistance=\(minDistance) minY=\(minY) energy=\(energy(states))")
        }
    }
}

extension PocketGeometryV63Tests {
    /// W07 exploration fixture: measured net envelope with an explicitly added
    /// bottom cap. This is not loaded by the App or a production capture test.
    func testMeasuredBagCandidateSupportsNaturalDescent() throws {
        try runMeasuredBagCandidate(fromRepeatedContact: false)
    }

    func testBagCandidateRepeatedFloorContactAdvances() throws {
        try runMeasuredBagCandidate(fromRepeatedContact: true)
    }

    private func runMeasuredBagCandidate(fromRepeatedContact: Bool) throws {
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY)
        let radius = Double(BallPhysics.radius)
        for index in (fromRepeatedContact ? [0] : [0, 4]) {
            let bag = try measuredBag(scene:scene,index:index)
            let mesh = try PocketContactMesh.load(from: scene, pocketIndex: index)
            var surfaces = mesh.patches.map {
                LocalPocketSimulation.Surface(triangle: $0.triangle, restitution: 0.3, friction: 0.2)
            }
            for triangle in bag.triangles {
                surfaces.append(.init(triangle:triangle,
                                      restitution: 0.1, friction: 0.2,
                                      rollingFriction: Double(SpinPhysics.rollingFriction),
                                      spinFriction: Double(SpinPhysics.spinFriction)))
            }
            let solver = LocalPocketSimulation(surfaces: surfaces, radius: radius,
                                               gravity: SIMD3(0, -9.81, 0), tolerance: 1e-6)
            let pocket = pockets[index]
            // Drop from above the measured lip: the old XZ pocket center at
            // bed + R overlaps the imported leather by 0.21mm (r1 evidence).
            let start = SIMD3(Double(pocket.x), Double(scene.surfaceY) + radius + 0.05, Double(pocket.z))
            let initial = fromRepeatedContact
                ? LocalPocketSimulation.State(time: 0.7857299573644045,
                    position: SIMD3(-1.2896644296349722, 0.6973144374787807, -0.6672735859089418),
                    velocity: SIMD3(0.0023218250814073843, 0, -0.035935713578871355),
                    omega: SIMD3(-1.1840415166541725, -1.4496997382950005, -0.2385748281926426))
                : .init(time: 0, position: start, velocity: .zero, omega: .zero)
            let result = try solver.run(from: initial,
                duration: fromRepeatedContact ? 0.002 : 4, maxStep: 0.001,
                maxIterations: fromRepeatedContact ? 32 : 4096)
            let final = try XCTUnwrap(result.states.last)
            if fromRepeatedContact {
                XCTAssertEqual(final.time, initial.time + 0.002, accuracy: 1e-12)
                XCTAssertLessThanOrEqual(result.contacts.count, 8, "Resting floor must not create an impact storm")
                continue
            }
            XCTAssertLessThan(final.position.y, Double(scene.surfaceY) - radius)
            XCTAssertGreaterThanOrEqual(final.position.y, bag.bottom + radius - 4 * solver.tolerance)
            XCTAssertLessThan(simd_length(final.velocity), 0.005, "Candidate must actually settle, not free-fall")
            XCTAssertLessThan(simd_length(final.omega), 0.01, "Bag motion must include normal-spin decay")
            XCTAssertFalse(result.contacts.isEmpty)
            for state in result.states {
                let energy = 0.5 * simd_length_squared(state.velocity)
                    + 0.2 * radius * radius * simd_length_squared(state.omega) + 9.81 * state.position.y
                XCTAssertLessThanOrEqual(energy, 9.81 * start.y + 4 * 9.81 * solver.tolerance)
            }
            let rows = result.states.map { [$0.time, $0.position.x, $0.position.y, $0.position.z,
                                           $0.velocity.x, $0.velocity.y, $0.velocity.z] }
            let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: rows),
                                           uniformTypeIdentifier: "public.json")
            attachment.name = "bag-candidate-descent-\(index)"; attachment.lifetime = .keepAlways; add(attachment)
            print("[W07 bag candidate] pocket=\(index) final=\(final) contacts=\(result.contacts.count)")
        }
    }
}

extension PocketGeometryV63Tests {
    func testLocalReboundResolutionPreservesVisibleFlight() throws {
        let radius = Double(BallPhysics.radius), gravity = 9.81, tolerance = 1e-6
        let floor = PocketContactTriangle(a: SIMD3(-1, 0, -1), b: SIMD3(1, 0, -1), c: SIMD3(0, 0, 1))
        let solver = LocalPocketSimulation(surfaces: [.init(triangle: floor, restitution: 0.1, friction: 0)],
            radius: radius, gravity: SIMD3(0, -gravity, 0), tolerance: tolerance)
        for speed in [0.001, 0.01] {
            let initial = LocalPocketSimulation.State(time: 0, position: SIMD3(0, radius, 0),
                velocity: SIMD3(0.02, speed, 0), omega: SIMD3(0, 1, 0))
            let duration = 0.0005
            let result = try solver.run(from: initial, duration: duration, maxStep: duration, maxIterations: 32)
            let final = try XCTUnwrap(result.states.last)
            XCTAssertEqual(final.position.x, 0.02 * duration, accuracy: 1e-12)
            XCTAssertEqual(final.velocity.x, 0.02, accuracy: 1e-12)
            XCTAssertEqual(final.omega, initial.omega)
            if speed * speed / (2 * gravity) <= tolerance {
                XCTAssertEqual(final.position.y, radius, accuracy: 1e-12)
                XCTAssertEqual(final.velocity.y, 0, accuracy: 1e-12)
            } else {
                XCTAssertEqual(final.position.y, radius + speed * duration - gravity * duration * duration / 2, accuracy: 1e-12)
                XCTAssertEqual(final.velocity.y, speed - gravity * duration, accuracy: 1e-12)
            }
        }
    }
}

extension PocketGeometryV63Tests {
    /// Exact noncoplanar seam from the measured bag candidate, independent of output files.
    func testNoncoplanarSharedEdgeDoesNotDuplicateFaceSupport() throws {
        typealias V = SIMD3<Double>
        let a=V(-1.287404539934595,0.695000011920929,-0.7122617528246404)
        let b=V(-1.2869198161315436,0.6925000119209289,-0.7119075737279146)
        let c=V(-1.2836742603620601,0.6925000119209289,-0.7106974171507776)
        let d=V(-1.28397399450271,0.695000011920929,-0.7110753333939178)
        let triangles=[PocketContactTriangle(a:a,b:b,c:c),.init(a:a,b:c,c:d),
            .init(a:V(-1.2958261110471445,0.6687394380569458,-0.678730899798849),
                  b:V(-1.2962725619740643,0.6687394380569458,-0.71002919834205),
                  c:V(-1.293301457417149,0.6687394380569458,-0.7102959203200413))]
        let initial=LocalPocketSimulation.State(time:1.365928889792294,
            position:V(-1.2957508050634894,0.6973144374787806,-0.6850044487405662),
            velocity:V(-0.029720386222384036,1.808184210434105e-19,-0.010278494888655032),
            omega:V(-0.359702365739037,-0.9923261565732426,1.0400835283363945))
        let radius=Double(BallPhysics.radius)
        let solver=LocalPocketSimulation(surfaces:triangles.map{.init(triangle:$0,restitution:0.1,friction:0.2)},
            radius:radius,gravity:V(0,-9.81,0),tolerance:1e-6)
        let result=try solver.run(from:initial,duration:0.002,maxStep:0.001,maxIterations:32)
        XCTAssertEqual(try XCTUnwrap(result.states.last).time,initial.time+0.002,accuracy:1e-12)
        for state in result.states {
            for triangle in triangles {
                XCTAssertGreaterThanOrEqual(simd_length(state.position-triangle.closestPoint(to:state.position)),radius-4e-6)
            }
            let energy=0.5*simd_length_squared(state.velocity)+0.2*radius*radius*simd_length_squared(state.omega)+9.81*state.position.y
            let initialEnergy=0.5*simd_length_squared(initial.velocity)+0.2*radius*radius*simd_length_squared(initial.omega)+9.81*initial.position.y
            XCTAssertLessThanOrEqual(energy,initialEnergy+4*9.81e-6)
        }
    }
}

extension PocketGeometryV63Tests {
    func testDistinctCreaseFacesBothRetainSupport() throws {
        typealias V = SIMD3<Double>
        let radius=Double(BallPhysics.radius)
        let floor=PocketContactTriangle(a:V(-1,0,-1),b:V(1,0,-1),c:V(0,0,1))
        let wall=PocketContactTriangle(a:V(0,-1,-1),b:V(0,1,-1),c:V(0,0,1))
        let solver=LocalPocketSimulation(surfaces:[floor,wall].map{.init(triangle:$0,restitution:0,friction:0)},
            radius:radius,gravity:V(-9.81,-9.81,0),tolerance:1e-6)
        let result=try solver.run(from:.init(time:0,position:V(radius,radius,0),
            velocity:V(-0.001,-0.001,0.02),omega:.zero),duration:0.002,maxStep:0.001,maxIterations:32)
        let final=try XCTUnwrap(result.states.last)
        XCTAssertEqual(final.position.x,radius,accuracy:1e-12)
        XCTAssertEqual(final.position.y,radius,accuracy:1e-12)
        XCTAssertEqual(final.position.z,0.00004,accuracy:1e-12)
        XCTAssertEqual(final.velocity.x,0,accuracy:1e-12)
        XCTAssertEqual(final.velocity.y,0,accuracy:1e-12)
        XCTAssertEqual(final.velocity.z,0.02,accuracy:1e-12)
    }
}

extension PocketGeometryV63Tests {
    func testSubcriticalSlopeDoesNotProduceStepDependentCreep() throws {
        typealias V = SIMD3<Double>
        let radius=Double(BallPhysics.radius),g=9.81,mu=0.01
        let floor=PocketContactTriangle(a:V(-1,0,-1),b:V(1,0,-1),c:V(0,0,1))
        // Tangential force 0.005*g is balanced by static contact friction.
        // Its required opposing moment is 2.5*0.005*g/R, below 3.5*mu*g/R.
        for step in [0.0025,0.00125] {
            let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0,
                friction:0.2,rollingFriction:mu)],radius:radius,gravity:V(0.005*g,-g,0),tolerance:1e-6)
            let initial=LocalPocketSimulation.State(time:0,position:V(0,radius,0),velocity:.zero,omega:.zero)
            let result=try solver.run(from:initial,duration:0.25,maxStep:step)
            let final=try XCTUnwrap(result.states.last)
            print("[W07 slope rest] step=\(step) final=\(final)")
            XCTAssertEqual(final.position.x,0,accuracy:1e-6)
            XCTAssertEqual(final.velocity.x,0,accuracy:1e-8)
        }
    }

    func testSupercriticalSlopeStillAccelerates() throws {
        typealias V = SIMD3<Double>
        let radius=Double(BallPhysics.radius),g=9.81,mu=0.01
        let floor=PocketContactTriangle(a:V(-1,0,-1),b:V(1,0,-1),c:V(0,0,1))
        let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0,
            friction:0.2,rollingFriction:mu)],radius:radius,gravity:V(0.04*g,-g,0),tolerance:1e-6)
        let result=try solver.run(from:.init(time:0,position:V(0,radius,0),velocity:.zero,omega:.zero),
                                  duration:0.25,maxStep:0.00125)
        let final=try XCTUnwrap(result.states.last)
        let acceleration=(5.0/7.0)*0.04*g-mu*g
        XCTAssertEqual(final.velocity.x,acceleration*0.25,accuracy:1e-4)
        XCTAssertEqual(final.position.x,0.5*acceleration*0.25*0.25,accuracy:1e-5)
    }

    func testRollingResistanceMatchesPlanarDecelerationAndDoesNotReverse() throws {
        typealias V = SIMD3<Double>
        let radius=Double(BallPhysics.radius),g=9.81,mu=0.01,speed=0.02
        let floor=PocketContactTriangle(a:V(-1,0,-1),b:V(1,0,-1),c:V(0,0,1))
        for coefficient in [0.0,mu] {
            let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0.1,
                friction:0.2,rollingFriction:coefficient)],radius:radius,gravity:V(0,-g,0),tolerance:1e-6)
            let initial=LocalPocketSimulation.State(time:0,position:V(0,radius,0),
                velocity:V(speed,0,0),omega:V(0,0,-speed/radius))
            let result=try solver.run(from:initial,duration:0.4,maxStep:0.001,maxIterations:1024)
            let final=try XCTUnwrap(result.states.last)
            if coefficient == 0 {
                XCTAssertEqual(final.velocity.x,speed,accuracy:1e-10)
                XCTAssertEqual(final.position.x,speed*0.4,accuracy:1e-10)
            } else {
                XCTAssertEqual(final.velocity.x,0,accuracy:1e-8)
                XCTAssertEqual(final.position.x,speed*speed/(2*mu*g),accuracy:1e-6)
                for state in result.states {
                    XCTAssertGreaterThanOrEqual(state.velocity.x,-1e-10)
                    XCTAssertEqual(state.velocity.x,max(0,speed-mu*g*state.time),accuracy:1e-5)
                    XCTAssertEqual(state.velocity.x+radius*state.omega.z,0,accuracy:1e-8)
                }
            }
        }
    }
}

extension PocketGeometryV63Tests {
    func testRollingCoupleWithoutSlidingFrictionDoesNotCreateSpinEnergy() throws {
        typealias V = SIMD3<Double>
        let radius=Double(BallPhysics.radius)
        let floor=PocketContactTriangle(a:V(-1,0,-1),b:V(1,0,-1),c:V(0,0,1))
        let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0,
            friction:0,rollingFriction:0.01)],radius:radius,gravity:V(0,-9.81,0),tolerance:1e-6)
        let result=try solver.run(from:.init(time:0,position:V(0,radius,0),velocity:.zero,
            omega:V(0,0,-0.01)),duration:0.005,maxStep:0.001,maxIterations:64)
        for state in result.states {
            XCTAssertLessThanOrEqual(state.omega.z,1e-12,"Resisting couple must not reverse spin on its own")
            XCTAssertEqual(state.velocity,.zero)
        }
        for (a,b) in zip(result.states,result.states.dropFirst()) {
            XCTAssertLessThanOrEqual(simd_length_squared(b.omega),simd_length_squared(a.omega)+1e-14)
        }
    }
}

extension PocketGeometryV63Tests {
    func testLocalNormalSpinDecayMatchesPlanarLawInBothDirections() throws {
        typealias V=SIMD3<Double>
        let radius=Double(BallPhysics.radius),g=9.81,coefficient=Double(SpinPhysics.spinFriction)
        let floor=PocketContactTriangle(a:V(-1,0,-1),b:V(1,0,-1),c:V(0,0,1))
        for spin in [-0.03,0.03] {
            for mu in [0.0,coefficient] {
                let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0,friction:0,
                    spinFriction:mu)],radius:radius,gravity:V(0,-g,0),tolerance:1e-6)
                let initial=LocalPocketSimulation.State(time:0,position:V(0,radius,0),velocity:.zero,omega:V(0.1,spin,-0.1))
                let result=try solver.run(from:initial,duration:0.01,maxStep:0.001,maxIterations:64)
                let deceleration=2.5*mu*g/radius
                for state in result.states {
                    let expected=(spin>0 ? 1.0 : -1.0)*max(0,abs(spin)-deceleration*state.time)
                    XCTAssertEqual(state.omega.y,expected,accuracy:1e-10)
                    XCTAssertEqual(state.omega.x,initial.omega.x,accuracy:1e-12)
                    XCTAssertEqual(state.omega.z,initial.omega.z,accuracy:1e-12)
                    XCTAssertEqual(state.velocity,.zero)
                }
                for (a,b) in zip(result.states,result.states.dropFirst()) {
                    XCTAssertLessThanOrEqual(simd_length_squared(b.omega),simd_length_squared(a.omega)+1e-14)
                }
            }
        }
    }
}

extension PocketGeometryV63Tests {
    func testStackedRollingBallsIncludeSurfaceMomentInPairSupport() throws {
        typealias V=SIMD3<Double>
        let r=Double(BallPhysics.radius),g=9.81,mu=0.01,speed=0.1
        let motions:[SpatialBallContact.Motion]=[
            .init(velocity:V(speed,0,0),angularVelocity:V(0,0,-speed/r)),
            .init(velocity:V(speed,0,0),angularVelocity:V(0,0,speed/r))]
        let response=try SpatialBallContact.resolveSupport(motions,
            external:Array(repeating:.init(linear:V(0,-g,0),angular:.zero),count:2),
            constraints:[
                .init(contact:.init(a:0,b:nil,normal:V(0,1,0),restitution:0,friction:0.2),
                      normalRate:.zero,rollingFriction:mu),
                .init(contact:.init(a:0,b:1,normal:V(0,-1,0),restitution:0,friction:0.2),normalRate:.zero)
            ],radius:r,duration:0.001)
        // Force balance, floor no-slip and pair no-slip give a0=-98*mu*g/89.
        let a0 = -98*mu*g/89,a1=4*a0/7
        XCTAssertEqual(response.accelerations[0].linear.x,a0,accuracy:1e-10)
        XCTAssertEqual(response.accelerations[1].linear.x,a1,accuracy:1e-10)
        XCTAssertEqual(response.forcesOnA[0].y,2*g,accuracy:1e-10)
        XCTAssertEqual(response.forcesOnA[1].y,-g,accuracy:1e-10)
        XCTAssertEqual(response.accelerations[0].angular.z,-a0/r,accuracy:1e-9)
        XCTAssertEqual(response.accelerations[1].angular.z,2.5*a1/r,accuracy:1e-9)
        let power=zip(motions,response.accelerations).reduce(0.0) { sum,pair in
            sum+simd_dot(pair.0.velocity,pair.1.linear)+0.4*r*r*simd_dot(pair.0.angularVelocity,pair.1.angular)
        }
        XCTAssertEqual(power,-2.8*mu*g*speed,accuracy:1e-10)
    }
}

extension PocketGeometryV63Tests {
    func testStackedRollingBallsAdvanceAndConvergeNearStop() throws {
        typealias V=SIMD3<Double>
        let r=Double(BallPhysics.radius),g=9.81
        let floor=PocketContactTriangle(a:V(-1,0,-1),b:V(1,0,-1),c:V(0,0,1))
        func energy(_ states:[LocalPocketSimulation.State])->Double {
            states.reduce(0) { $0 + 0.5*simd_length_squared($1.velocity) +
                0.2*r*r*simd_length_squared($1.omega) + g*$1.position.y }
        }
        for speed in [0.1,0.0002] {
            let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0,friction:0.2,
                rollingFriction:0.01,spinFriction:Double(SpinPhysics.spinFriction))],radius:r,
                gravity:V(0,-g,0),tolerance:min(1e-8,speed*speed*1e-4))
            let initial:[LocalPocketSimulation.State]=[
                .init(time:0,position:V(0,r,0),velocity:V(speed,0,0),omega:V(0,0,-speed/r)),
                .init(time:0,position:V(0,3*r,0),velocity:V(speed,0,0),omega:V(0,0,speed/r))]
            var results:[[LocalPocketSimulation.State]]=[]
            for step in [0.001,0.0005,0.00025] {
                var states=initial
                var events=0
                while states[0].time<0.01 {
                    let result=try solver.advanceTogether(from:states,duration:0.01-states[0].time,
                        maxStep:step,pairRestitution:0,pairFriction:0.2)
                    XCTAssertGreaterThanOrEqual(result.time,states[0].time)
                    states=result.states;events+=1
                    XCTAssertLessThan(events,128)
                    if events>=128 { return }
                    XCTAssertLessThanOrEqual(energy(states),energy(initial)+4*g*solver.tolerance)
                    XCTAssertGreaterThanOrEqual(simd_length(states[0].position-states[1].position),2*r-1e-10)
                    XCTAssertGreaterThanOrEqual(states[0].position.y,r-1e-10)
                }
                print("[W07 stacked advance] speed=\(speed) step=\(step) final=\(states)")
                results.append(states)
            }
            for coarse in results.dropLast() {
                for (a,b) in zip(coarse,results.last!) {
                    XCTAssertLessThan(simd_length(a.position-b.position),2e-6)
                    XCTAssertLessThan(simd_length(a.velocity-b.velocity),min(1e-4,speed*0.01))
                    XCTAssertLessThan(r*simd_length(a.omega-b.omega),min(1e-4,speed*0.01))
                }
            }
        }
    }
}

extension PocketGeometryV63Tests {
    func testOccupiedBagWallFloorPairSupportConverges() throws {
        typealias V=SIMD3<Double>
        let r=Double(BallPhysics.radius)
        let motions:[SpatialBallContact.Motion]=[
        .init(velocity:V(-0.0036559742777515264,4.704786907283598e-15,0.056584858390928056),angularVelocity:V(1.9807737400154406,1.6635684042586416,0.11924553912986739)),
        .init(velocity:V(-0.03138907877979023,-0.004476180202066569,0.10484800798447176),angularVelocity:V(0.3391110665561451,-2.6193713107129772,5.045052286919478))]
        let external=Array(repeating:SpatialBallContact.Acceleration(linear:V(0,-9.81,0),angular:.zero),count:2)
        let constraints:[SpatialBallContact.SupportConstraint]=[
        .init(contact:.init(a:0,b:nil,normal:V(-0.9831406111641049,0.1714631120569993,-0.06352117665471248),restitution:0,friction:0.2),normalRate:.zero,rollingFriction:0.009999999776482582,spinFriction:0.01269999984651804),
        .init(contact:.init(a:0,b:nil,normal:V(0,1,0),restitution:0,friction:0.2),normalRate:.zero,rollingFriction:0.009999999776482582,spinFriction:0.01269999984651804),
        .init(contact:.init(a:0,b:1,normal:V(0.5902137690621749,-0.7612691241828887,0.2685461363997616),restitution:0,friction:0.05),normalRate:V(0.48526868002048434,0.07832336470056674,-0.8444995725295436)),
        .init(contact:.init(a:1,b:nil,normal:V(0.938785659643189,0.1874302124173951,0.2890525916186748),restitution:0,friction:0.2),normalRate:.zero,rollingFriction:0.009999999776482582,spinFriction:0.01269999984651804)]
        // Evaluate the solver's Double coefficient convention explicitly;
        // SIMD reciprocal normalization changes vn by a few ULP before /dt.
        func dot(_ a:V,_ b:V)->Double { a.x*b.x+a.y*b.y+a.z*b.z }
        for exponent in 0...20 {
            let dt=0.0025/pow(2,Double(exponent))
            let response=try SpatialBallContact.resolveSupport(motions,external:external,
                constraints:constraints,radius:r,duration:dt)
            for (j,support) in constraints.enumerated() {
                let c=support.contact,n=c.normal/sqrt(dot(c.normal,c.normal)),force=response.forcesOnA[j]
                let pressure=simd_dot(force,n)
                XCTAssertGreaterThanOrEqual(pressure,-1e-12)
                XCTAssertLessThanOrEqual(simd_length(force-n*pressure),c.friction*max(0,pressure)+1e-12)
                var velocity=motions[c.a].velocity,acceleration=response.accelerations[c.a].linear
                if let b=c.b { velocity-=motions[b].velocity;acceleration-=response.accelerations[b].linear }
                let normalResidual=dot(velocity,n)/dt+dot(acceleration,n)+dot(velocity,support.normalRate)
                XCTAssertGreaterThanOrEqual(normalResidual,-1e-12)
                if pressure>1e-12 { XCTAssertEqual(normalResidual,0,accuracy:1e-12) }
                let sn=simd_normalize(c.normal)
                let endpointNormal=simd_dot(velocity,sn)+dt*(simd_dot(acceleration,sn)+simd_dot(velocity,support.normalRate))
                let velocityRounding=64*Double.ulpOfOne*max(1,simd_length(velocity),dt*simd_length(acceleration))
                XCTAssertGreaterThanOrEqual(endpointNormal,-velocityRounding)
                if pressure>1e-12 { XCTAssertLessThanOrEqual(abs(endpointNormal),velocityRounding) }
            }
        }
    }

    func testOccupiedBagWallFloorPairImpactConverges() throws {
        typealias V=SIMD3<Double>
        let motions:[SpatialBallContact.Motion]=[
            .init(velocity:V(0.0012574007064006926,-8.515295624564497e-20,-0.019461253145367077),
                angularVelocity:V(-0.7109172118977376,-0.5610155846865644,-0.07476758390121462)),
            .init(velocity:V(-0.012667963636225379,0.004891396591746081,0.05720260833801164),
                angularVelocity:V(1.6662668368109552,-2.110078139277094,0.6783572973166484))]
        let contacts:[SpatialBallContact.Constraint]=[
            .init(a:0,b:nil,normal:V(-0.9831406111641042,0.17146311205700288,-0.06352117665471309),restitution:0,friction:0.2),
            .init(a:0,b:nil,normal:V(0,1,0),restitution:0,friction:0.2),
            .init(a:0,b:1,normal:V(0.6057450237953014,-0.767780929933743,0.2087711900078806),restitution:0,friction:0.05)]
        let r=Double(BallPhysics.radius)
        let result=try SpatialBallContact.resolveInstant(motions,constraints:contacts,radius:r)
        func energy(_ states:[SpatialBallContact.Motion])->Double {
            states.reduce(0){$0+0.5*simd_length_squared($1.velocity)+0.2*r*r*simd_length_squared($1.angularVelocity)}
        }
        XCTAssertLessThanOrEqual(energy(result.motions),energy(motions)+1e-12)
        for c in contacts {
            let n=simd_normalize(c.normal)
            var v=result.motions[c.a].velocity
            if let b=c.b { v-=result.motions[b].velocity }
            XCTAssertGreaterThanOrEqual(simd_dot(v,n),-64*Double.ulpOfOne)
        }
    }

    func testFiniteTriangleDistanceBoundMatchesUnfilteredContact() throws {
        typealias V = SIMD3<Double>
        let triangles = [
            PocketContactTriangle(a: V(0,0,0), b: V(1,0,0), c: V(0,1,0)),
            PocketContactTriangle(a: V(0,0,0), b: V(0,1,0), c: V(0,0,1)),
            PocketContactTriangle(a: V(0,0,0), b: V(0,0,0), c: V(0,0,0))
        ]
        var hits = 0, misses = 0
        for triangle in triangles {
            for x in [-0.2, 0.0, 0.25, 0.8, 1.2] {
                for y in [-0.2, 0.0, 0.25, 0.8, 1.2] {
                    for z in [-0.1, 0.0, 0.03, 0.1] {
                        for speed in [-2.0, 0.0, 2.0] {
                            for acceleration in [-9.8, 0.0, 9.8] {
                                for horizon in [0.0025, 0.2] {
                                    let p=V(x,y,z),v=V(speed,0,-speed),a=V(0,0,acceleration)
                                    let reference=triangle.firstContact(position:p,velocity:v,acceleration:a,
                                        radius:0.028575,horizon:horizon,useDistanceBound:false)
                                    let bounded=triangle.firstContact(position:p,velocity:v,acceleration:a,
                                        radius:0.028575,horizon:horizon)
                                    XCTAssertEqual(bounded?.time,reference?.time)
                                    XCTAssertEqual(bounded?.point,reference?.point)
                                    XCTAssertEqual(bounded?.normal,reference?.normal)
                                    if reference == nil { misses += 1 } else { hits += 1 }
                                }
                            }
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(hits,0)
        XCTAssertGreaterThan(misses,hits)
        print("[W07 finite triangle bound] hits=\(hits) misses=\(misses)")
    }

    func testContactReachBoundPreservesTurnaroundAndEndpointHits() throws {
        typealias V=SIMD3<Double>
        let vertex=PocketContactTriangle(a:.zero,b:.zero,c:.zero)
        // The center returns to its initial point at t=.1, but crosses the
        // sphere boundary earlier. Net endpoint displacement is not a bound.
        let turning=try XCTUnwrap(vertex.firstContact(position:V(0,0,0.1),velocity:V(0,0,-1),
            acceleration:V(0,0,20),radius:0.09,horizon:0.1))
        XCTAssertEqual(turning.time,(1-sqrt(0.6))/20,accuracy:1e-12)
        let endpoint=try XCTUnwrap(vertex.firstContact(position:V(0,0,0.125),velocity:V(0,0,-1),
            acceleration:.zero,radius:0.0625,horizon:0.0625))
        XCTAssertEqual(endpoint.time,0.0625,accuracy:1e-12)
        XCTAssertNil(vertex.firstContact(position:V(0,0,0.1),velocity:V(0,0,-1),
            acceleration:.zero,radius:0.09,horizon:0.001))
    }

    func testPairSupportSlipRoundingIncludesBothBodies() throws {
        typealias V=SIMD3<Double>
        let r=Double(BallPhysics.radius),g=9.81,n=V(0,1,0)
        let stationary=SpatialBallContact.Motion(velocity:.zero,angularVelocity:.zero)
        // The contact velocity cancellation is within the arithmetic rounding
        // bound of the moving body's velocity and angular contribution.
        let rolling=SpatialBallContact.Motion(velocity:V(0,0,-1),
            angularVelocity:V((1/r).nextUp,0,0))
        let down=SpatialBallContact.Acceleration(linear:V(0,-g,0),angular:.zero)
        let up=SpatialBallContact.Acceleration(linear:V(0,g,0),angular:.zero)
        let forward=try SpatialBallContact.resolveSupport([stationary,rolling],external:[down,up],
            constraints:[.init(contact:.init(a:0,b:1,normal:n,restitution:0,friction:0.2),normalRate:.zero)],
            radius:r,duration:1e-6)
        let reverse=try SpatialBallContact.resolveSupport([rolling,stationary],external:[up,down],
            constraints:[.init(contact:.init(a:0,b:1,normal:-n,restitution:0,friction:0.2),normalRate:.zero)],
            radius:r,duration:1e-6)
        XCTAssertEqual(forward.forcesOnA[0].z,0,accuracy:1e-14)
        XCTAssertEqual(reverse.forcesOnA[0].z,0,accuracy:1e-14)
        XCTAssertLessThan(simd_length(forward.forcesOnA[0]+reverse.forcesOnA[0]),1e-14)
        for (a,b) in zip(forward.accelerations,reverse.accelerations.reversed()) {
            XCTAssertLessThan(simd_length(a.linear-b.linear),1e-14)
            XCTAssertLessThan(r*simd_length(a.angular-b.angular),1e-14)
        }
    }

    func testPairSupportFrictionStopsSlipWithinStepWithoutReversing() throws {
        typealias V=SIMD3<Double>
        let r=Double(BallPhysics.radius),g=9.81,mu=0.2,dt=0.001,n=V(0,1,0)
        for speed in [-0.1,-0.001,0.001,0.1] {
            let response=try SpatialBallContact.resolveSupport([
                .init(velocity:V(speed,0,0),angularVelocity:.zero),
                .init(velocity:.zero,angularVelocity:.zero)],
                external:[.init(linear:V(0,-g,0),angular:.zero),.init(linear:V(0,g,0),angular:.zero)],
                constraints:[.init(contact:.init(a:0,b:1,normal:n,restitution:0,friction:mu),normalRate:.zero)],
                radius:r,duration:dt)
            let a=response.accelerations
            let derivative=a[0].linear-a[1].linear-simd_cross(a[0].angular+a[1].angular,n*r)
            let slip=speed+dt*derivative.x
            let expected=(speed>0 ? 1.0 : -1.0)*max(0,abs(speed)-7*mu*g*dt)
            XCTAssertEqual(slip,expected,accuracy:1e-12)
            XCTAssertEqual(response.forcesOnA[0].y,g,accuracy:1e-12)
            XCTAssertLessThanOrEqual(abs(response.forcesOnA[0].x),mu*g+1e-12)
        }
    }
}

extension PocketGeometryV63Tests {
    private func measuredBag(scene:AngleTrainingScene,index:Int,
                             configuration:PocketBagEnvelope.Configuration = .init()) throws -> PocketBagEnvelope {
        let strands=try measuredBagStrands(scene:scene,index:index)
        return try PocketBagEnvelope.build(pocketID:"pocket_\(index)",strands:strands,
            surfaceY:Double(scene.surfaceY),configuration:configuration)
    }

    private func measuredBagStrands(scene:AngleTrainingScene,index:Int) throws -> [PocketContactTriangle] {
        let table=try XCTUnwrap(scene.tableNode),bed=try XCTUnwrap(MobileClothAlignment.measuredBedY(in:scene))
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:scene.surfaceY)
        return try PocketContactMesh.load(table:table,worldRoot:scene.rootNode,pocketID:"pocket_\(index)",
            center:centers[index],surfaceY:scene.surfaceY,bedY:bed,alignCloth:true,materials:["White"]).patches.map(\.triangle)
    }

    func testBagEnvelopeBuildsFromBundledNetForAllSixPockets() throws {
        let scene=AngleTrainingScene();scene.setupScene(mobileRendering:true)
        let asset=try PocketGeometryAsset.load(),cached=try asset.bagEnvelopes()
        XCTAssertEqual(Set(cached.keys),Set(asset.regionsByPocketID.keys))
        var rows:[[String:Any]]=[]
        for index in 0..<6 {
            let bag=try measuredBag(scene:scene,index:index)
            let shared=try XCTUnwrap(cached[bag.pocketID])
            XCTAssertEqual(shared.rings,bag.rings,"Cached numeric proxy must match independently loaded visible geometry")
            XCTAssertEqual(shared.bottom,bag.bottom)
            XCTAssertEqual(shared.triangles.count,bag.triangles.count)
            XCTAssertEqual(bag.pocketID,"pocket_\(index)")
            XCTAssertEqual(bag.rings.count,72)
            XCTAssertEqual(bag.triangles.count,18304)
            XCTAssertEqual(bag.bottom,index<4 ? 0.6687394380569458 : 0.6680201292037964,accuracy:1e-6)
            XCTAssertEqual(bag.top,Double(scene.surfaceY)-0.04,accuracy:1e-12)
            for pair in zip(bag.rings,bag.rings.dropFirst()) { XCTAssertGreaterThan(pair.0[0].y,pair.1[0].y) }
            let strands=try measuredBagStrands(scene:scene,index:index)
            rows.append(["id":bag.pocketID,"bottom":bag.bottom,"surfaceY":Double(scene.surfaceY),
                "sourceTriangleCount":bag.sourceTriangleCount,"selectedTriangleCount":bag.selectedTriangleCount,
                "triangles":strands.map{[$0.a,$0.b,$0.c].map{[$0.x,$0.y,$0.z]}},
                "rings":bag.rings.map{$0.map{[$0.x,$0.y,$0.z]}}])
        }
        let attachment=XCTAttachment(data:try JSONSerialization.data(withJSONObject:rows),uniformTypeIdentifier:"public.json")
        attachment.name="bundled-bag-envelopes";attachment.lifetime = .keepAlways;add(attachment)
    }
}

extension PocketGeometryV63Tests {
    func testBundledBagAcceptsNormalTableEntry() throws {
        typealias V=SIMD3<Double>
        let scene=AngleTrainingScene();scene.setupScene(mobileRendering:true)
        let r=Double(BallPhysics.radius),g=9.81
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:scene.surfaceY)
        for index in [0,4] {
            let bag=try measuredBag(scene:scene,index:index),mesh=try PocketContactMesh.load(from:scene,pocketIndex:index)
            let surfaces=mesh.patches.map{LocalPocketSimulation.Surface(triangle:$0.triangle,restitution:0.3,friction:0.2)} +
                bag.triangles.map{.init(triangle:$0,restitution:0.1,friction:0.2,
                    rollingFriction:Double(SpinPhysics.rollingFriction),spinFriction:Double(SpinPhysics.spinFriction))}
            let solver=LocalPocketSimulation(surfaces:surfaces,radius:r,gravity:V(0,-g,0),tolerance:1e-6)
            let inward=index == 0 ? V(1/sqrt(2),0,1/sqrt(2)) : V(0,0,1)
            let c=centers[index],velocity = -inward*0.7
            let initial=LocalPocketSimulation.State(time:0,
                position:V(Double(c.x),Double(scene.surfaceY)+r,Double(c.z))+inward*0.15,
                velocity:velocity,omega:V(velocity.z/r,0,-velocity.x/r))
            let result=try solver.run(from:initial,duration:0.7,maxStep:0.0025,maxIterations:2048)
            let final=try XCTUnwrap(result.states.last)
            XCTAssertLessThan(final.position.y,Double(scene.surfaceY)-r)
            XCTAssertGreaterThanOrEqual(final.position.y,bag.bottom+r-4*solver.tolerance)
            let energy0=0.5*simd_length_squared(initial.velocity)+0.2*r*r*simd_length_squared(initial.omega)+g*initial.position.y
            for state in result.states {
                let energy=0.5*simd_length_squared(state.velocity)+0.2*r*r*simd_length_squared(state.omega)+g*state.position.y
                XCTAssertLessThanOrEqual(energy,energy0+4*g*solver.tolerance)
            }
            let rows=result.states.map{[$0.time,$0.position.x,$0.position.y,$0.position.z,$0.velocity.x,$0.velocity.y,$0.velocity.z]}
            let attachment=XCTAttachment(data:try JSONSerialization.data(withJSONObject:rows),uniformTypeIdentifier:"public.json")
            attachment.name="normal-bag-entry-\(index)";attachment.lifetime = .keepAlways;add(attachment)
            print("[W07 normal bag entry] pocket=\(index) final=\(final)")
        }
    }
}

extension PocketGeometryV63Tests {
    func testBagEnvelopeIgnoresCoplanarTriangulationDensity() throws {
        typealias V=SIMD3<Double>
        let corners=[SIMD2<Double>(-0.05,-0.03),.init(0.07,-0.03),.init(0.07,0.08),.init(-0.05,0.08)]
        var faces:[PocketContactTriangle]=[]
        for i in corners.indices {
            let a=corners[i],b=corners[(i+1)%corners.count]
            let topA=V(a.x,1,a.y),topB=V(b.x,1,b.y),lowA=V(a.x,0.8,a.y),lowB=V(b.x,0.8,b.y)
            faces.append(.init(a:topA,b:lowA,c:lowB));faces.append(.init(a:topA,b:lowB,c:topB))
        }
        let refined=faces.flatMap { t -> [PocketContactTriangle] in
            let ab=(t.a+t.b)/2,bc=(t.b+t.c)/2,ca=(t.c+t.a)/2
            return [.init(a:t.a,b:ab,c:ca),.init(a:ab,b:t.b,c:bc),.init(a:ca,b:bc,c:t.c),.init(a:ab,b:bc,c:ca)]
        }
        var c=PocketBagEnvelope.Configuration();c.layerHeight=0.02;c.maximumAngularGap = .pi
        let a=try PocketBagEnvelope.build(pocketID:"box",strands:faces,surfaceY:1.02,configuration:c)
        let b=try PocketBagEnvelope.build(pocketID:"box",strands:refined,surfaceY:1.02,configuration:c)
        let fitting=PocketContactTriangle(a:V(0.2,0.99,0),b:V(0.2,0.95,0),c:V(0.2,0.97,0.03))
        let withFitting=try PocketBagEnvelope.build(pocketID:"box",strands:faces+[fitting],surfaceY:1.02,configuration:c)
        XCTAssertEqual(withFitting.sourceTriangleCount,faces.count+1)
        XCTAssertEqual(withFitting.selectedTriangleCount,faces.count)
        XCTAssertEqual(withFitting.rings,a.rings,"Disconnected shallow material must not expand the bag")
        XCTAssertEqual(a.rings.count,b.rings.count)
        XCTAssertGreaterThan(a.rings.count,8)
        for (x,y) in zip(a.rings.joined(),b.rings.joined()) { XCTAssertLessThan(simd_length(x-y),1e-12) }
        XCTAssertThrowsError(try PocketBagEnvelope.build(pocketID:"empty",strands:[],surfaceY:1))
    }
}

extension PocketGeometryV63Tests {
    func testBagMotionConvergesAcrossEnvelopeResolutions() throws {
        try runBagMotionConvergence(refinements:[1,2])
    }

    private func runBagMotionConvergence(refinements:[Int]) throws {
        typealias V=SIMD3<Double>
        let asset=try PocketGeometryAsset.load()
        let r=Double(BallPhysics.radius),g=9.81
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)
        for index in [0,4] {
            let mesh=asset.pockets[index]
            let inward=index == 0 ? V(1/sqrt(2),0,1/sqrt(2)) : V(0,0,1)
            let c=centers[index],v = -inward*0.7
            let initial=LocalPocketSimulation.State(time:0,
                position:V(Double(c.x),Double(asset.surfaceY)+r,Double(c.z))+inward*0.15,
                velocity:v,omega:V(v.z/r,0,-v.x/r))
            var paths:[[V]]=[]
            for refinement in refinements {
                var configuration=PocketBagEnvelope.Configuration()
                configuration.layerHeight/=Double(refinement);configuration.radialSamples*=refinement
                let bag=try PocketBagEnvelope.build(pocketID:mesh.pocketID,
                    strands:try XCTUnwrap(asset.bagSourceTrianglesByPocketID[mesh.pocketID]),
                    surfaceY:Double(asset.surfaceY),configuration:configuration)
                let surfaces=mesh.patches.map{LocalPocketSimulation.Surface(triangle:$0.triangle,restitution:0.3,friction:0.2)} +
                    bag.triangles.map{.init(triangle:$0,restitution:0.1,friction:0.2,
                        rollingFriction:Double(SpinPhysics.rollingFriction),spinFriction:Double(SpinPhysics.spinFriction))}
                let solver=LocalPocketSimulation(surfaces:surfaces,radius:r,gravity:V(0,-g,0),tolerance:1e-6)
                let result=try solver.run(from:initial,duration:0.7,maxStep:0.00125,maxIterations:2048)
                let final=try XCTUnwrap(result.states.last)
                XCTAssertLessThan(final.position.y,Double(asset.surfaceY)-r)
                XCTAssertGreaterThanOrEqual(final.position.y,bag.bottom+r-4*solver.tolerance)
                let energy0=0.7*simd_length_squared(v)+g*initial.position.y
                for state in result.states {
                    let energy=0.5*simd_length_squared(state.velocity)+0.2*r*r*simd_length_squared(state.omega)+g*state.position.y
                    XCTAssertLessThanOrEqual(energy,energy0+4*g*solver.tolerance)
                }
                var samples:[V]=[]
                for tick in 0...700 {
                    let time=Double(tick)/1000
                    if tick==0 { samples.append(initial.position);continue }
                    if tick==700 { samples.append(final.position);continue }
                    let interval=try XCTUnwrap(result.intervals.first{$0.start.time<=time && $0.end.time>=time})
                    samples.append(try XCTUnwrap(interval.sample(at:time)).position)
                }
                paths.append(samples)
                let rows=zip(0...700,samples).map{[Double($0.0)/1000,$0.1.x,$0.1.y,$0.1.z]}
                let attachment=XCTAttachment(data:try JSONSerialization.data(withJSONObject:rows),uniformTypeIdentifier:"public.json")
                attachment.name="bag-motion-resolution-\(index)-\(refinement)";attachment.lifetime = .keepAlways;add(attachment)
            }
            let differences=zip(paths[0],paths[1]).map{simd_length($0-$1)}
            let maximum=try XCTUnwrap(differences.max())
            print("[W07 bag geometry motion] pocket=\(index) maxDistance=\(maximum) at=\(Double(differences.firstIndex(of:maximum)!)/1000)")
            XCTAssertLessThanOrEqual(maximum,0.002,"Preserve the existing 2mm spatial comparison budget")
        }
    }
}

extension PocketGeometryInjectionV63Tests {
    func testDuplicateStaticContactsPreserveCoupledImpactResponse() throws {
        typealias V=SIMD3<Double>
        let r=Double(BallPhysics.radius),speed=sqrt(2*9.81*0.005),e=Double(BallPhysics.restitution)
        let floor=SpatialBallContact.Constraint(a:0,b:nil,normal:V(0,1,0),restitution:0,friction:0.2)
        let pair=SpatialBallContact.Constraint(a:0,b:1,normal:V(0,-1,0),restitution:e,friction:0.05)
        for tangent in [0.0,0.1] {
            let initial:[SpatialBallContact.Motion]=[
                .init(velocity:.zero,angularVelocity:.zero),
                .init(velocity:V(tangent,-speed,0),angularVelocity:.zero)]
            let reference=try SpatialBallContact.resolveCoupled(initial,constraints:[floor,pair],radius:r)
            if tangent == 0 {
                XCTAssertLessThan(simd_length(reference[0].velocity),1e-12)
                XCTAssertEqual(reference[1].velocity.y,e*speed,accuracy:1e-12)
            }
            for count in [2,64,128,256] {
                let contacts=Array(repeating:floor,count:count)+[pair]
                for ordered in [contacts,Array(contacts.reversed())] {
                    let result=try SpatialBallContact.resolveCoupled(initial,constraints:ordered,radius:r)
                    for (actual,expected) in zip(result,reference) {
                        XCTAssertLessThan(simd_length(actual.velocity-expected.velocity),1e-12)
                        XCTAssertLessThan(r*simd_length(actual.angularVelocity-expected.angularVelocity),1e-12)
                    }
                }
            }
        }
    }

    func testBundledBagSupportsAnIncomingBallAboveAnOccupiedBottom() throws {
        typealias V=SIMD3<Double>
        let asset=try PocketGeometryAsset.load(),r=Double(BallPhysics.radius),g=9.81
        func energy(_ states:[LocalPocketSimulation.State])->Double {
            states.reduce(0) { $0 + 0.5*simd_length_squared($1.velocity) +
                0.2*r*r*simd_length_squared($1.omega) + g*$1.position.y }
        }
        for index in [0,4] {
            let mesh=asset.pockets[index]
            var configuration=PocketBagEnvelope.Configuration()
            configuration.radialSamples=128;configuration.layerHeight=0.00125
            let bag=try PocketBagEnvelope.build(pocketID:mesh.pocketID,
                strands:try XCTUnwrap(asset.bagSourceTrianglesByPocketID[mesh.pocketID]),
                surfaceY:Double(asset.surfaceY),configuration:configuration)
            let ring=try XCTUnwrap(bag.rings.last)
            let center=ring.reduce(V.zero,+)/Double(ring.count)
            let surfaces=mesh.patches.map{LocalPocketSimulation.Surface(triangle:$0.triangle,restitution:0.3,friction:0.2)} +
                bag.triangles.map{.init(triangle:$0,restitution:0.1,friction:0.2,
                    rollingFriction:Double(SpinPhysics.rollingFriction),spinFriction:Double(SpinPhysics.spinFriction))}
            let solver=LocalPocketSimulation(surfaces:surfaces,radius:r,gravity:V(0,-g,0),tolerance:1e-6)
            let initial:[LocalPocketSimulation.State]=[
                .init(time:0,position:center+V(0,r,0),velocity:.zero,omega:.zero),
                .init(time:0,position:center+V(0,3*r+0.005,0),velocity:.zero,omega:.zero)]
            // Validate the fixture against every finite face before trusting a projected state.
            for state in initial {
                let clearance=try XCTUnwrap(surfaces.map{simd_length(state.position-$0.triangle.closestPoint(to:state.position))}.min())
                XCTAssertGreaterThanOrEqual(clearance,r-1e-12,"Initial fixture intersects pocket \(index)")
                guard clearance>=r-1e-12 else { return }
            }
            XCTAssertEqual(simd_length(initial[1].position-initial[0].position),2*r+0.005,accuracy:1e-12)
            var states=initial,events=0,pairEvents=0,rows:[[Double]]=[]
            let end=0.12,initialEnergy=energy(initial)
            while states[0].time<end {
                events+=1
                guard events<=128 else { return XCTFail("Repeated bag pair events at pocket \(index)") }
                let result=try solver.advanceTogether(from:states,duration:end-states[0].time,
                    maxStep:0.00125,pairRestitution:Double(BallPhysics.restitution),pairFriction:0.05)
                assertContinuousPairClearance(result.intervals,radius:r,tolerance:solver.tolerance)
                pairEvents+=result.constraints.filter{$0.b != nil}.count
                states=result.states
                XCTAssertTrue(states.allSatisfy{$0.time == result.time})
                XCTAssertLessThanOrEqual(energy(states),initialEnergy+8*g*solver.tolerance)
                for (ball,state) in states.enumerated() {
                    XCTAssertGreaterThanOrEqual(state.position.y,bag.bottom+r-4*solver.tolerance)
                    rows.append([Double(ball),state.time,state.position.x,state.position.y,state.position.z,
                        state.velocity.x,state.velocity.y,state.velocity.z,state.omega.x,state.omega.y,state.omega.z])
                }
            }
            XCTAssertEqual(states[0].time,end,accuracy:1e-12)
            XCTAssertGreaterThan(pairEvents,0,"The falling ball must actually interact with the occupied bag")
            let attachment=XCTAttachment(data:try JSONSerialization.data(withJSONObject:rows),uniformTypeIdentifier:"public.json")
            attachment.name="occupied-bag-\(index)";attachment.lifetime = .keepAlways;add(attachment)
            print("[W07 occupied bag] pocket=\(index) events=\(events) pairEvents=\(pairEvents) states=\(states)")
        }
    }
}

extension PocketGeometryV63Tests {
    func testBagFirstContactGeometryAndStepDiagnostics() throws {
        try runBagContactDiagnostics(cases:[(1,0.00125),(1,0.000625),(2,0.000625)])
    }

    func testBagFirstContactFinerGeometryDiagnostics() throws {
        try runBagContactDiagnostics(cases:[(4,0.000625)])
    }

    private func runBagContactDiagnostics(cases:[(Int,Double)]) throws {
        typealias V=SIMD3<Double>
        func row(_ s:LocalPocketSimulation.State)->[Double] {
            [s.time,s.position.x,s.position.y,s.position.z,s.velocity.x,s.velocity.y,s.velocity.z,s.omega.x,s.omega.y,s.omega.z]
        }
        let scene=AngleTrainingScene();scene.setupScene(mobileRendering:true)
        let radius=Double(BallPhysics.radius),centers=AngleSceneCalculator.pocketPositions(surfaceY:scene.surfaceY)
        for index in [0,4] {
            let mesh=try PocketContactMesh.load(from:scene,pocketIndex:index)
            let inward=index == 0 ? V(1/sqrt(2),0,1/sqrt(2)) : V(0,0,1),v = -inward*0.7,c=centers[index]
            let initial=LocalPocketSimulation.State(time:0,
                position:V(Double(c.x),Double(scene.surfaceY)+radius,Double(c.z))+inward*0.15,
                velocity:v,omega:V(v.z/radius,0,-v.x/radius))
            for (refinement,step) in cases {
                // Historical diagnosis remains anchored to the original 64-point
                // candidate, independently of the accepted default resolution.
                var config=PocketBagEnvelope.Configuration()
                config.layerHeight=0.0025/Double(refinement);config.radialSamples=64*refinement
                let bag=try measuredBag(scene:scene,index:index,configuration:config)
                let surfaces=mesh.patches.map{LocalPocketSimulation.Surface(triangle:$0.triangle,restitution:0.3,friction:0.2)} +
                    bag.triangles.map{.init(triangle:$0,restitution:0.1,friction:0.2,
                        rollingFriction:Double(SpinPhysics.rollingFriction),spinFriction:Double(SpinPhysics.spinFriction))}
                let solver=LocalPocketSimulation(surfaces:surfaces,radius:radius,gravity:V(0,-9.81,0),tolerance:1e-6)
                let result=try solver.run(from:initial,duration:0.3,maxStep:step,maxIterations:2048)
                XCTAssertEqual(try XCTUnwrap(result.states.last).time,0.3,accuracy:1e-12)
                let contacts:[[String:Any]]=result.contacts.map { contact in
                    let span=result.intervals.first{$0.end.time==contact.time},triangle=surfaces[contact.surface].triangle
                    return ["time":contact.time,"surface":contact.surface,"bagSurface":contact.surface>=mesh.patches.count,
                        "normal":[contact.normal.x,contact.normal.y,contact.normal.z],
                        "triangle":[triangle.a,triangle.b,triangle.c].map{[$0.x,$0.y,$0.z]},
                        "before":span.flatMap{$0.sample(at:contact.time,beforeEndpoint:true)}.map(row) ?? [],
                        "after":span.map{row($0.end)} ?? []]
                }
                let payload:[String:Any]=["pocket":index,"refinement":refinement,"step":step,
                    "contacts":contacts,"states":result.states.map(row),"final":row(try XCTUnwrap(result.states.last))]
                let attachment=XCTAttachment(data:try JSONSerialization.data(withJSONObject:payload),uniformTypeIdentifier:"public.json")
                attachment.name="bag-contact-diagnostic-\(index)-\(refinement)-\(step)";attachment.lifetime = .keepAlways;add(attachment)
            }
        }
    }
}

extension PocketGeometryV63Tests {
    func testCachedBagSourcesMatchVisibleTableCoordinates() throws {
        let asset=try PocketGeometryAsset.load()
        XCTAssertTrue(asset === (try PocketGeometryAsset.load()))
        XCTAssertEqual(asset.bagSourceTrianglesByPocketID.count,6)
        let scene=AngleTrainingScene();scene.setupScene(mobileRendering:true)
        XCTAssertEqual(asset.surfaceY,scene.surfaceY)
        for index in 0..<6 {
            let expected=try measuredBagStrands(scene:scene,index:index)
            let actual=try XCTUnwrap(asset.bagSourceTrianglesByPocketID["pocket_\(index)"])
            XCTAssertEqual(actual.count,expected.count)
            var maximum=0.0
            for (a,b) in zip(actual,expected) {
                maximum=max(maximum,simd_length(a.a-b.a),simd_length(a.b-b.b),simd_length(a.c-b.c))
            }
            XCTAssertLessThanOrEqual(maximum,1e-12,"Detached numeric source must match the visible table")
        }
    }
}


extension PocketGeometryInjectionV63Tests {
    func testOccupiedBagPressureProjectionAtSharedTriangleEdge() throws {
        typealias V=SIMD3<Double>
        let asset=try PocketGeometryAsset.load(),mesh=asset.pockets[0]
        let bag=try PocketBagEnvelope.build(pocketID:mesh.pocketID,
            strands:try XCTUnwrap(asset.bagSourceTrianglesByPocketID[mesh.pocketID]),surfaceY:Double(asset.surfaceY))
        let triangles=mesh.patches.map(\.triangle)+bag.triangles
        let solver=LocalPocketSimulation(surfaces:triangles.map{.init(triangle:$0,restitution:0.1,friction:0.2)},
            radius:Double(BallPhysics.radius),gravity:V(0,-9.81,0),tolerance:1e-6)
        let original:[LocalPocketSimulation.State]=[
            .init(time:0.6893224432611166,position:V(-1.289665597731121,0.6973144374787807,-0.6672400507206437),
                velocity:V(0.00020506006243802572,1.857233013088701e-15,-0.003173789997707781),
                omega:V(-0.11106876858025161,-0.09360265542226996,-0.007176205305591205)),
            .init(time:0.6893224432611166,position:V(-1.324382822124108,0.7412456326387499,-0.6786806061860771),
                velocity:V(-0.011742417924709299,0.004884032936799839,0.051898613912106074),
                omega:V(1.4127676816569297,-1.848774241852028,1.0409330376411725))]
        let selected=[22064,26426,13230,13231]
        let payload:[String:Any]=["triangles":selected.map { i in [triangles[i].a,triangles[i].b,triangles[i].c].map{[$0.x,$0.y,$0.z]} },
            "indices":selected,"states":original.map{[$0.time,$0.position.x,$0.position.y,$0.position.z,$0.velocity.x,$0.velocity.y,$0.velocity.z]}]
        let attachment=XCTAttachment(data:try JSONSerialization.data(withJSONObject:payload),uniformTypeIdentifier:"public.json")
        attachment.name="pressure-shared-edge-fixture";attachment.lifetime = .keepAlways;add(attachment)
        let result=try solver.projectPressure(original,contacts:[.surface(0,22064),.surface(0,26426),.pair(0,1),.surface(1,13230),.surface(1,13231)])
        for i in original.indices {
            XCTAssertEqual(result[i].time,original[i].time)
            XCTAssertEqual(result[i].omega,original[i].omega)
            XCTAssertLessThanOrEqual(simd_length(result[i].position-original[i].position),4e-6)
        }
        let radius=Double(BallPhysics.radius)
        for (body,index) in [(0,22064),(0,26426),(1,13230),(1,13231)] {
            let delta=result[body].position-triangles[index].closestPoint(to:result[body].position)
            let distance=simd_length(delta)
            let rounding=64*Double.ulpOfOne*max(1,simd_length(result[body].position))
            XCTAssertGreaterThanOrEqual(distance,radius-rounding)
            if index != 13231 {
                XCTAssertEqual(distance,radius,accuracy:rounding)
                XCTAssertEqual(simd_dot(result[body].velocity,delta/distance),0,accuracy:64*Double.ulpOfOne)
            }
        }
        let delta=result[0].position-result[1].position,distance=simd_length(delta)
        XCTAssertEqual(distance,2*radius,accuracy:64*Double.ulpOfOne*max(1,simd_length(result[0].position),simd_length(result[1].position)))
        XCTAssertEqual(simd_dot(result[0].velocity-result[1].velocity,delta/distance),0,accuracy:64*Double.ulpOfOne)
    }
}


extension PocketGeometryInjectionV63Tests {
    func testMiddleBagNewWallContactInterruptsLoadedGroup() throws {
        typealias V=SIMD3<Double>
        let asset=try PocketGeometryAsset.load(),mesh=asset.pockets[4]
        let bag=try XCTUnwrap(asset.bagEnvelopes()[mesh.pocketID])
        let surfaces=mesh.patches.map{LocalPocketSimulation.Surface(triangle:$0.triangle,restitution:0.3,friction:0.2)} +
            bag.triangles.map{.init(triangle:$0,restitution:0.1,friction:0.2,
                rollingFriction:Double(SpinPhysics.rollingFriction),spinFriction:Double(SpinPhysics.spinFriction))}
        let solver=LocalPocketSimulation(surfaces:surfaces,radius:Double(BallPhysics.radius),gravity:V(0,-9.81,0),tolerance:1e-6)
        let time=0.664386295473439,dt=1.953125e-05
        let states:[LocalPocketSimulation.State]=[
            .init(time:time,position:V(-0.0017916923799616263, 0.6965951286256213, -0.6651191406084929),velocity:V(-0.005735419795727358, -6.338954622288445e-15, 0.00011612003823306418),omega:V(0.004063685978145921, 0.12883504080593056, 0.2007146082594686)),
            .init(time:time,position:V(-0.005609597573767046, 0.7376052378508613, -0.704738793674804),velocity:V(0.012147979819822276, -0.0005937005631834256, -0.0022217310546018562),omega:V(-0.18567086152318787, -0.2345943715732923, -0.9525400817966843))]
        let whole=try solver.advanceTogether(from:states,duration:dt,maxStep:dt,pairRestitution:0.9,pairFriction:0.05,useSharedErrorControl:false)
        let half=try solver.advanceTogether(from:states,duration:dt/2,maxStep:dt/2,pairRestitution:0.9,pairFriction:0.05,useSharedErrorControl:false)
        for (label,values) in [("initial",states),("half",half.states)] {
            let plan=try solver.sustainedPairAcceleration(values,friction:0.05,duration:dt/2)
            print("[W07 middle pressure plan] label=\(label) plan=\(plan)")
            for (body,state) in values.enumerated() {
                let closest=surfaces.indices.sorted { i,j in
                    simd_length(state.position-surfaces[i].triangle.closestPoint(to:state.position)) <
                    simd_length(state.position-surfaces[j].triangle.closestPoint(to:state.position))
                }.prefix(6)
                for index in closest {
                    let t=surfaces[index].triangle,delta=state.position-t.closestPoint(to:state.position),distance=simd_length(delta)
                    print("[W07 middle support feature] label=\(label) ball=\(body) index=\(index) gap=\(distance-solver.radius) vn=\(simd_dot(state.velocity,delta/distance)) triangle=\(t)")
                }
            }
        }
        let fine=half.constraints.isEmpty ? try solver.advanceTogether(from:half.states,duration:time+dt-half.time,
            maxStep:dt/2,pairRestitution:0.9,pairFriction:0.05,useSharedErrorControl:false) : half
        print("[W07 middle pressure split] whole=\(whole) half=\(half) fine=\(fine)")
        for result in [whole,half] {
            let contact=try XCTUnwrap(result.staticContacts[0].first(where:{$0.surface==21489}))
            XCTAssertEqual(result.time,contact.time,accuracy:1e-12,
                "A new wall impact must end the loaded group's speculative pressure segment")
            XCTAssertFalse(result.constraints.isEmpty)
        }
        let prepared=try solver.preparedGroupSupport(whole.states,friction:0.05,duration:0.00025)
        XCTAssertTrue(prepared.plan.pressure.contains(.surface(0,24275)))
        XCTAssertLessThanOrEqual(abs(prepared.states[0].velocity.y),64*Double.ulpOfOne)
        var beforeEnergy=0.0,afterEnergy=0.0
        for i in states.indices {
            XCTAssertEqual(prepared.states[i].position,whole.states[i].position)
            XCTAssertEqual(prepared.states[i].omega,whole.states[i].omega)
            XCTAssertEqual(prepared.states[i].time,whole.states[i].time)
            beforeEnergy+=simd_length_squared(whole.states[i].velocity)
            afterEnergy+=simd_length_squared(prepared.states[i].velocity)
        }
        XCTAssertLessThanOrEqual(afterEnergy,beforeEnergy+64*Double.ulpOfOne)
        var incoming=whole.states;incoming[0].velocity.y = -0.1
        let unresolved=try solver.preparedGroupSupport(incoming,friction:0.05,duration:0.00025)
        XCTAssertEqual(unresolved.states.map(\.velocity),incoming.map(\.velocity),"A real incoming impact must not be collapsed")
        var continuing=states,events=0
        let end=time+0.001
        while continuing[0].time<end {
            events+=1
            guard events<1000 else { return XCTFail("Repeated middle-bag events prevent time advancement") }
            let step=try solver.advanceTogether(from:continuing,duration:end-continuing[0].time,
                maxStep:0.00025,pairRestitution:0.9,pairFriction:0.05)
            assertContinuousPairClearance(step.intervals,radius:solver.radius,tolerance:solver.tolerance)
            continuing=step.states
        }
        XCTAssertEqual(continuing[0].time,end,accuracy:1e-12)
        XCTAssertEqual(continuing[1].time,end,accuracy:1e-12)
        print("[W07 middle continuation] events=\(events) end=\(continuing)")

    }
}


extension PocketGeometryInjectionV63Tests {
    func testCornerBagLoadedGroupRetainsContactAtNewWallEvent() throws {
        typealias V=SIMD3<Double>
        let asset=try PocketGeometryAsset.load(),mesh=asset.pockets[0]
        let bag=try XCTUnwrap(asset.bagEnvelopes()[mesh.pocketID])
        let surfaces=mesh.patches.map{LocalPocketSimulation.Surface(triangle:$0.triangle,restitution:0.3,friction:0.2)} +
            bag.triangles.map{.init(triangle:$0,restitution:0.1,friction:0.2,
                rollingFriction:Double(SpinPhysics.rollingFriction),spinFriction:Double(SpinPhysics.spinFriction))}
        let solver=LocalPocketSimulation(surfaces:surfaces,radius:Double(BallPhysics.radius),gravity:V(0,-9.81,0),tolerance:1e-6)
        let time=0.6395079239818969,dt=0.0010955921681824476
        let states:[LocalPocketSimulation.State]=[
            .init(time:time,position:V(-1.2896713464954683, 0.6973144374787718, -0.6671510755497577),velocity:V(-0.012648752188028148, 0.00048676544419080356, 0.05683719471764008),omega:V(1.9704096030820013, 1.6816810469241785, 0.347669458271727)),
            .init(time:time,position:V(-1.323467338612214, 0.7408120104998367, -0.6823798123966153),velocity:V(-0.03172019890230492, 0.0014980543692200829, 0.10204955104084087),omega:V(0.44559210774886354, -2.6952555674702436, 4.5862140518506145))]
        let prepared=try solver.preparedGroupSupport(states,friction:0.05,duration:dt)
        XCTAssertTrue(prepared.plan.pressure.contains(.pair(0,1)))
        print("[W07 corner loaded event plan] \(prepared)")
        let result=try solver.advanceTogether(from:states,duration:dt,maxStep:dt,
            pairRestitution:0.9,pairFriction:0.05)
        XCTAssertGreaterThan(result.time,time)
        XCTAssertLessThanOrEqual(result.time,time+dt)
        XCTAssertTrue(result.constraints.contains{$0.b != nil})
        XCTAssertTrue(result.staticContacts.contains{!$0.isEmpty})
        assertContinuousPairClearance(result.intervals,radius:solver.radius,tolerance:solver.tolerance)
        XCTAssertEqual(result.states[0].time,result.states[1].time)
        XCTAssertGreaterThanOrEqual(simd_length(result.states[0].position-result.states[1].position),2*solver.radius-4*solver.tolerance)
    }
}


extension PocketGeometryInjectionV63Tests {
    func testCornerBagFiveConstraintSupportConverges() throws {
        typealias V=SIMD3<Double>
        let motions=[SpatialBallContact.Motion(velocity: V(-0.013624569721588077, -7.196047497484725e-15, 0.0009542805584047761), angularVelocity: V(0.033395649963044, 0.5179762849632842, 0.47680040980527005)), SpatialBallContact.Motion(velocity: V(-0.022577081112738807, 0.02059091230317697, 0.08480672247283753), angularVelocity: V(1.1794043397792864, -2.839054061841668, 2.22950170760919))]
        let external=[SpatialBallContact.Acceleration(linear: V(0.0, -9.81, 0.0), angular: V(0.0, 0.0, 0.0)), SpatialBallContact.Acceleration(linear: V(0.0, -9.81, 0.0), angular: V(0.0, 0.0, 0.0))]
        let constraints=[SpatialBallContact.SupportConstraint(contact: SpatialBallContact.Constraint(a: 0, b: nil, normal: V(-0.06388357241108789, 0.40499079227933116, -0.9120862609122873), restitution: 0.0, friction: 0.2), normalRate: V(-0.17881707215814416, 0.21304216555749705, 0.10712099609730143), rollingFriction: 0.009999999776482582, spinFriction: 0.01269999984651804), SpatialBallContact.SupportConstraint(contact: SpatialBallContact.Constraint(a: 0, b: nil, normal: V(-0.06388357241109563, 0.404990792279331, -0.9120862609122868), restitution: 0.0, friction: 0.2), normalRate: V(-0.1788170721581439, 0.21304216555749556, 0.10712099609730481), rollingFriction: 0.009999999776482582, spinFriction: 0.01269999984651804), SpatialBallContact.SupportConstraint(contact: SpatialBallContact.Constraint(a: 0, b: nil, normal: V(0.0, 1.0, 0.0), restitution: 0.0, friction: 0.2), normalRate: V(0.0, 0.0, 0.0), rollingFriction: 0.009999999776482582, spinFriction: 0.01269999984651804), SpatialBallContact.SupportConstraint(contact: SpatialBallContact.Constraint(a: 0, b: 1, normal: V(0.5922583685957103, -0.7655806807726647, 0.2512294689243495), restitution: 0.0, friction: 0.05), normalRate: V(0.15664937134378135, -0.36029593560482226, -1.4672343588982892), rollingFriction: 0.0, spinFriction: 0.0), SpatialBallContact.SupportConstraint(contact: SpatialBallContact.Constraint(a: 1, b: nil, normal: V(0.9614560918179658, 0.17257517785825818, 0.21405604755136853), restitution: 0.0, friction: 0.2), normalRate: V(0.0, 0.0, 0.0), rollingFriction: 0.009999999776482582, spinFriction: 0.01269999984651804)]
        let r=Double(BallPhysics.radius),dt=3.9062500000075495e-05
        // Evaluate the solver's Double coefficient convention explicitly;
        // SIMD reciprocal normalization changes vn by a few ULP before /dt.
        func dot(_ a:V,_ b:V)->Double { a.x*b.x+a.y*b.y+a.z*b.z }
        for dt in [dt] {
            let response=try SpatialBallContact.resolveSupport(motions,external:external,
                constraints:constraints,radius:r,duration:dt)
            for (j,support) in constraints.enumerated() {
                let c=support.contact,n=c.normal/sqrt(dot(c.normal,c.normal)),force=response.forcesOnA[j]
                let pressure=simd_dot(force,n)
                XCTAssertGreaterThanOrEqual(pressure,-1e-12)
                XCTAssertLessThanOrEqual(simd_length(force-n*pressure),c.friction*max(0,pressure)+1e-12)
                var velocity=motions[c.a].velocity,acceleration=response.accelerations[c.a].linear
                if let b=c.b { velocity-=motions[b].velocity;acceleration-=response.accelerations[b].linear }
                let normalResidual=dot(velocity,n)/dt+dot(acceleration,n)+dot(velocity,support.normalRate)
                XCTAssertGreaterThanOrEqual(normalResidual,-1e-12)
                if pressure>1e-12 { XCTAssertEqual(normalResidual,0,accuracy:1e-12) }
                let sn=simd_normalize(c.normal)
                let endpointNormal=simd_dot(velocity,sn)+dt*(simd_dot(acceleration,sn)+simd_dot(velocity,support.normalRate))
                let velocityRounding=64*Double.ulpOfOne*max(1,simd_length(velocity),dt*simd_length(acceleration))
                XCTAssertGreaterThanOrEqual(endpointNormal,-velocityRounding)
                if pressure>1e-12 { XCTAssertLessThanOrEqual(abs(endpointNormal),velocityRounding) }
            }
        }
    }
}


extension PocketGeometryInjectionV63Tests {
    func testCornerBagPairTOIRetainsWitnessAtSharedEvent() throws {
        typealias V=SIMD3<Double>
        let asset=try PocketGeometryAsset.load(),mesh=asset.pockets[0]
        let bag=try XCTUnwrap(asset.bagEnvelopes()[mesh.pocketID])
        let surfaces=mesh.patches.map{LocalPocketSimulation.Surface(triangle:$0.triangle,restitution:0.3,friction:0.2)} +
            bag.triangles.map{.init(triangle:$0,restitution:0.1,friction:0.2,
                rollingFriction:Double(SpinPhysics.rollingFriction),spinFriction:Double(SpinPhysics.spinFriction))}
        let solver=LocalPocketSimulation(surfaces:surfaces,radius:Double(BallPhysics.radius),gravity:V(0,-9.81,0),tolerance:1e-6)
        let time=0.6438657338656617,dt=0.0025
        let states:[LocalPocketSimulation.State]=[
            .init(time:time,position:V(-1.28975618972227, 0.6973144374787804, -0.6669274855322223),velocity:V(-0.03629767207125718, 3.198245873769199e-05, 0.031752234013032295),omega:V(1.1670679052043764, 1.2979529363159827, 1.1329136495995633)),
            .init(time:time,position:V(-1.323606886003159, 0.7408420313531023, -0.6819475155136342),velocity:V(-0.034010858891198634, 0.023874576961586107, 0.09449198564931649),omega:V(0.7595659392425196, -2.834853609179709, 3.56619987973865))]
        let prepared=try solver.preparedGroupSupport(states,friction:0.05,duration:dt)
        XCTAssertFalse(prepared.plan.pressure.contains(.pair(0,1)))
        print("[W07 returning pair plan] \(prepared)")
        let result=try solver.advanceTogether(from:states,duration:dt,maxStep:dt,
            pairRestitution:0.9,pairFriction:0.05)
        XCTAssertGreaterThan(result.time,time)
        XCTAssertLessThanOrEqual(result.time,time+dt)
        XCTAssertTrue(result.constraints.contains{$0.b != nil})
        // The old wall-event fixture required a new static impact. Here the
        // walls provide existing support while the separating pair returns.
        XCTAssertTrue(result.constraints.contains{$0.b == nil})
        let incoming=try result.intervals.map { path in
            try XCTUnwrap(path.last?.sample(at:result.time,beforeEndpoint:true))
        }
        let normal=simd_normalize(result.states[0].position-result.states[1].position)
        XCTAssertGreaterThan(simd_dot(states[0].velocity-states[1].velocity,
            simd_normalize(states[0].position-states[1].position)),0)
        XCTAssertLessThan(simd_dot(incoming[0].velocity-incoming[1].velocity,normal),0)
        XCTAssertGreaterThanOrEqual(simd_dot(result.states[0].velocity-result.states[1].velocity,normal),-64*Double.ulpOfOne)
        func kinetic(_ values:[LocalPocketSimulation.State])->Double {
            values.reduce(0){$0+0.5*simd_length_squared($1.velocity)+0.2*solver.radius*solver.radius*simd_length_squared($1.omega)}
        }
        XCTAssertLessThanOrEqual(kinetic(result.states),kinetic(incoming)+64*Double.ulpOfOne*max(1,kinetic(incoming)))
        assertContinuousPairClearance(result.intervals,radius:solver.radius,tolerance:solver.tolerance)
        XCTAssertEqual(result.states[0].time,result.states[1].time)
        XCTAssertGreaterThanOrEqual(simd_length(result.states[0].position-result.states[1].position),2*solver.radius-4*solver.tolerance)
    }
}

extension PocketGeometryV63Tests {
    private func collectionBoundaryFixture() throws -> PocketCaptureBoundary {
        typealias V=SIMD3<Double>
        func ring(_ y:Double)->[V] { [V(-0.06,y,-0.06),V(0.06,y,-0.06),V(0.06,y,0.06),V(-0.06,y,0.06)] }
        let bag=PocketBagEnvelope(pocketID:"test",rings:[ring(0.76),ring(0.60)],triangles:[],
            bottom:0.60,top:0.76,sourceTriangleCount:0,selectedTriangleCount:0)
        return try PocketCaptureBoundary(bag:bag,hardSurfaces:[.init(a:V(-0.1,0.74,0),b:V(0.1,0.74,0),c:V(0,0.80,0))],radius:0.028575)
    }

    func testCollectionBoundaryPreservesDownwardCrossingAndRejectsOutside() throws {
        typealias V=SIMD3<Double>
        let boundary=try collectionBoundaryFixture()
        XCTAssertEqual(boundary.centerPlaneY,0.74-0.028575,accuracy:1e-15)
        func interval(_ position:V,_ velocity:V,_ duration:Double)->LocalPocketSimulation.Interval {
            let state=LocalPocketSimulation.State(time:2,position:position,velocity:velocity,omega:V(1,2,3))
            let acceleration=V(0,-9.81,0)
            let end=LocalPocketSimulation.State(time:2+duration,position:position+velocity*duration+acceleration*(0.5*duration*duration),
                velocity:velocity+acceleration*duration,omega:state.omega)
            return .init(start:state,duration:duration,acceleration:acceleration,angularAcceleration:.zero,end:end)
        }
        let span=interval(V(0,0.80,0),V(0,-0.2,0),0.5)
        let hit=try XCTUnwrap(boundary.firstCandidate(in:span))
        let expected=(sqrt(0.2*0.2+2*9.81*(0.80-boundary.centerPlaneY))-0.2)/9.81
        XCTAssertEqual(hit.time,2+expected,accuracy:1e-12)
        XCTAssertEqual(hit.position.y,boundary.centerPlaneY,accuracy:1e-12)
        XCTAssertLessThan(hit.velocity.y,0)
        XCTAssertEqual(hit.omega,span.start.omega)
        XCTAssertFalse(boundary.containsProjection(V(0.07,boundary.centerPlaneY,0)))
        XCTAssertNotNil(boundary.firstCandidate(in:interval(V(0.07,0.80,0),V(0,-0.2,0),0.5)),
            "The sphere touches the soft bag even though its center is outside")
        XCTAssertTrue(boundary.intersectsBallProjection(V(0.08,boundary.centerPlaneY,0.08)))
        XCTAssertFalse(boundary.intersectsBallProjection(V(0.081,boundary.centerPlaneY,0.081)),
            "Corner distance must use the circular footprint, not an expanded square")
        XCTAssertNil(boundary.firstCandidate(in:interval(V(0.2,0.80,0),V(0,-0.2,0),0.5)))
        XCTAssertNil(boundary.firstCandidate(in:interval(V(0,0.80,0),V(0,1,0),0.05)))
        let returning=try XCTUnwrap(boundary.firstCandidate(in:interval(V(0,0.70,0),V(0,2,0),0.6)))
        XCTAssertGreaterThan(returning.time,2+2/9.81)
        XCTAssertLessThan(returning.velocity.y,0)
    }

    func testCollectionDefersWhileAnotherActiveBallTouches() throws {
        typealias V=SIMD3<Double>
        let b=try collectionBoundaryFixture()
        let s=LocalPocketSimulation.State(time:1,position:V(0,b.centerPlaneY,0),velocity:V(0,-1,0),omega:.zero)
        var other=s;other.position.x=2*b.radius
        XCTAssertFalse(b.isClearOfActiveBalls(s,others:[other],positionUncertainty:1e-6))
        other.position.x+=2e-6
        XCTAssertTrue(b.isClearOfActiveBalls(s,others:[other],positionUncertainty:1e-6))
        other.time+=0.01
        XCTAssertFalse(b.isClearOfActiveBalls(s,others:[other],positionUncertainty:1e-6))
    }

    func testCollectionBoundaryFitsAllSixMeasuredPockets() throws {
        let asset=try PocketGeometryAsset.load(),bags=try asset.bagEnvelopes(),r=Double(BallPhysics.radius)
        var report:[[String:Any]]=[]
        for mesh in asset.pockets {
            let bag=try XCTUnwrap(bags[mesh.pocketID])
            let b=try PocketCaptureBoundary(bag:bag,hardSurfaces:mesh.patches.map(\.triangle),radius:r)
            let hardBottom=try XCTUnwrap(mesh.patches.flatMap{[$0.triangle.a.y,$0.triangle.b.y,$0.triangle.c.y]}.min())
            XCTAssertLessThanOrEqual(b.centerPlaneY+r,hardBottom)
            XCTAssertLessThanOrEqual(b.centerPlaneY+r,bag.top)
            XCTAssertGreaterThan(b.centerPlaneY,bag.bottom+r)
            let center=b.outline.reduce(SIMD2<Double>.zero,+)/Double(b.outline.count)
            XCTAssertTrue(b.containsProjection(.init(center.x,b.centerPlaneY,center.y)))
            report.append(["id":mesh.pocketID,"centerPlaneY":b.centerPlaneY,"hardBottom":hardBottom,"bagBottom":bag.bottom,
                           "outline":b.outline.map{[$0.x,$0.y]}])
        }
        XCTAssertEqual(report.count,6)
        let attachment=XCTAttachment(data:try JSONSerialization.data(withJSONObject:report),uniformTypeIdentifier:"public.json")
        attachment.name="collection-boundaries";attachment.lifetime = .keepAlways;add(attachment)
    }
}

extension PocketGeometryV63Tests {
    func testNormalPocketEntryReachesCollectionBoundary() throws {
        typealias V=SIMD3<Double>
        let asset=try PocketGeometryAsset.load(),bags=try asset.bagEnvelopes(),r=Double(BallPhysics.radius)
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)
        var rows:[[String:Any]]=[]
        for index in [0,4] {
            let mesh=asset.pockets[index],bag=try XCTUnwrap(bags[mesh.pocketID])
            let boundary=try PocketCaptureBoundary(bag:bag,hardSurfaces:mesh.patches.map(\.triangle),radius:r)
            let inward=index == 0 ? V(1/sqrt(2),0,1/sqrt(2)) : V(0,0,1)
            let c=centers[index],velocity = -inward*0.5
            let above=V(Double(c.x),Double(asset.surfaceY)+2*r,Double(c.z))+inward*0.12
            let landing=try XCTUnwrap(mesh.patches.compactMap {
                $0.triangle.firstContact(position:above,velocity:V(0,-1,0),acceleration:.zero,radius:r,horizon:2*r)
            }.min(by:{$0.time<$1.time}))
            let initial=LocalPocketSimulation.State(time:0,position:above+V(0,-landing.time,0),velocity:velocity,
                omega:V(velocity.z/r,0,-velocity.x/r))
            let solver=LocalPocketSimulation(surfaces:mesh.patches.map{.init(triangle:$0.triangle,restitution:0.3,friction:0.2)},
                radius:r,gravity:V(0,-9.81,0),tolerance:1e-6)
            let path=try solver.run(from:initial,duration:0.6,maxStep:0.0025)
            let capture=try XCTUnwrap(path.intervals.compactMap{boundary.firstCandidate(in:$0)}.first)
            XCTAssertGreaterThan(capture.time,0)
            XCTAssertLessThan(capture.time,0.6)
            XCTAssertEqual(capture.position.y,boundary.centerPlaneY,accuracy:1e-10)
            XCTAssertTrue(boundary.isClearOfActiveBalls(capture,others:[],positionUncertainty:solver.tolerance))
            XCTAssertFalse(boundary.containsProjection(initial.position))
            let energy0=0.5*simd_length_squared(initial.velocity)+0.2*r*r*simd_length_squared(initial.omega)+9.81*initial.position.y
            let energy=0.5*simd_length_squared(capture.velocity)+0.2*r*r*simd_length_squared(capture.omega)+9.81*capture.position.y
            XCTAssertLessThanOrEqual(energy,energy0+4*9.81*solver.tolerance)
            rows.append(["id":mesh.pocketID,"time":capture.time,"position":[capture.position.x,capture.position.y,capture.position.z],
                         "velocity":[capture.velocity.x,capture.velocity.y,capture.velocity.z]])
        }
        let attachment=XCTAttachment(data:try JSONSerialization.data(withJSONObject:rows),uniformTypeIdentifier:"public.json")
        attachment.name="normal-entry-collection";attachment.lifetime = .keepAlways;add(attachment)
    }
}

extension PocketGeometryInjectionV63Tests {
    private func makeCollectionEntryEngine(pocketIndex:Int) throws -> EventDrivenEngine {
        typealias V=SIMD3<Double>
        let asset=try PocketGeometryAsset.load(),r=Double(BallPhysics.radius)
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[pocketIndex]
        let inward=pocketIndex==0 ? V(1/sqrt(2),0,1/sqrt(2)) : V(0,0,1)
        let above=V(Double(center.x),Double(asset.surfaceY)+2*r,Double(center.z))+inward*0.12
        let hit=try XCTUnwrap(asset.pockets[pocketIndex].patches.compactMap {
            $0.triangle.firstContact(position:above,velocity:V(0,-1,0),acceleration:.zero,radius:r,horizon:2*r)
        }.min(by:{$0.time<$1.time}))
        let position=above+V(0,-hit.time,0),velocity = -inward*0.5
        func scn(_ v:V)->SCNVector3 { .init(Float(v.x),Float(v.y),Float(v.z)) }
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        engine.setBall(.init(position:scn(position),velocity:scn(velocity),angularVelocity:scn(V(velocity.z/r,0,-velocity.x/r)),state:.rolling,name:"cue"))
        return engine
    }

    func testMixedCollectionRecordsPhysicalEntryAndStops() throws {
        for index in [0,4] {
            let engine=try makeCollectionEntryEngine(pocketIndex:index)
            try engine.simulateMixedWithLocalPockets(maxTime:1,pairRestitution:0.9,pairFriction:0.05,collectsPocketedBalls:true)
            let recorder=engine.getTrajectoryRecorder(),capture=try XCTUnwrap(recorder.confirmedCaptures.first)
            XCTAssertEqual(recorder.confirmedCaptures.count,1)
            XCTAssertEqual(capture.pocketID,"pocket_\(index)")
            XCTAssertLessThan(capture.state.velocity.y,0)
            XCTAssertLessThan(capture.state.time,0.5)
            XCTAssertTrue(capture.geometryVersion.hasPrefix("soft-bag-v1:"))
            XCTAssertFalse(recorder.isBallPocketed("cue",at:capture.state.time-1e-6))
            XCTAssertTrue(recorder.isBallPocketed("cue",at:capture.state.time))
            XCTAssertTrue(try XCTUnwrap(engine.getBall("cue")).isPocketed)
            XCTAssertTrue(recorder.pocketEntries.isEmpty,"Collection must not call the legacy planar capture")
            XCTAssertEqual(engine.resolvedEvents.filter{if case .pocket = $0 { return true };return false}.count,1)
            let end=try XCTUnwrap(recorder.localIntervalsByBallName["cue"]?.last?.end)
            XCTAssertEqual(end.time,capture.state.time)
            XCTAssertEqual(end.position,capture.state.position)
            XCTAssertEqual(end.velocity,capture.state.velocity)
            XCTAssertEqual(engine.spatialTime,capture.state.time)
            try engine.simulateMixedWithLocalPockets(maxTime:1,pairRestitution:0.9,pairFriction:0.05,collectsPocketedBalls:true)
            XCTAssertEqual(recorder.confirmedCaptures.count,1)
            XCTAssertEqual(engine.resolvedEvents.filter{if case .pocket = $0 { return true };return false}.count,1)
        }
    }

    func testMixedCollectionSplitResumePreservesCapture() throws {
        let whole=try makeCollectionEntryEngine(pocketIndex:4),split=try makeCollectionEntryEngine(pocketIndex:4)
        try whole.simulateMixedWithLocalPockets(maxTime:1,pairRestitution:0.9,pairFriction:0.05,collectsPocketedBalls:true)
        for end in [0.1201,0.2587,1.0] {
            try split.simulateMixedWithLocalPockets(maxTime:end,pairRestitution:0.9,pairFriction:0.05,collectsPocketedBalls:true)
        }
        let a=try XCTUnwrap(whole.getTrajectoryRecorder().confirmedCaptures.first)
        let b=try XCTUnwrap(split.getTrajectoryRecorder().confirmedCaptures.first)
        XCTAssertEqual(a.state.time,b.state.time)
        XCTAssertEqual(a.state.position,b.state.position)
        XCTAssertEqual(a.state.velocity,b.state.velocity)
        XCTAssertEqual(a.state.omega,b.state.omega)
        XCTAssertEqual(a.geometryVersion,b.geometryVersion)
    }
}

extension PocketGeometryInjectionV63Tests {
    func testMixedCollectionHandlesConsecutiveNormalEntries() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        for index in [0,4] {
            let engine=try makeCollectionEntryEngine(pocketIndex:index),first=try XCTUnwrap(engine.getBall("cue"))
            let dx:Float=index==0 ? Float(0.07/sqrt(2)):0
            let dz:Float=index==0 ? Float(0.07/sqrt(2)):0.07
            engine.setBall(.init(position:SCNVector3(first.position.x+dx,first.position.y,first.position.z+dz),
                velocity:first.velocity,angularVelocity:first.angularVelocity,state:first.state,name:"object"))
            let far=SCNVector3(0,asset.surfaceY+r,0)
            engine.setBall(.init(position:far,velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,state:.stationary,name:"far"))
            try engine.simulateMixedWithLocalPockets(maxTime:1,pairRestitution:0.9,pairFriction:0.05,collectsPocketedBalls:true)
            let captures=engine.getTrajectoryRecorder().confirmedCaptures
            XCTAssertEqual(captures.map(\.ballName),["cue","object"])
            XCTAssertTrue(captures.allSatisfy{$0.pocketID=="pocket_\(index)"})
            XCTAssertLessThan(captures.first?.state.time ?? 1,captures.last?.state.time ?? 0)
            XCTAssertEqual(engine.resolvedEvents.filter{if case .pocket = $0 { return true };return false}.count,2)
            for name in ["cue","object"] { XCTAssertTrue(try XCTUnwrap(engine.getBall(name)).isPocketed) }
            let untouched=try XCTUnwrap(engine.getBall("far"))
            XCTAssertEqual(untouched.position.x,far.x);XCTAssertEqual(untouched.position.y,far.y);XCTAssertEqual(untouched.position.z,far.z)
            XCTAssertFalse(untouched.isPocketed)
        }
    }
}

extension PocketGeometryV63Tests {
    func testCollectionTailContinuesGravityThenRemainsStill() throws {
        typealias V=SIMD3<Double>
        let start=LocalPocketSimulation.State(time:0.3,position:V(0.01,0.715,-0.68),velocity:V(0.2,-1.5,-0.4),omega:V(1,2,3))
        let tail=try PocketCollectionTail(start:start,restingCenterY:0.697,gravity:9.81)
        let first=try XCTUnwrap(tail.sample(at:start.time))
        XCTAssertEqual(first.position,start.position);XCTAssertEqual(first.velocity,start.velocity);XCTAssertEqual(first.omega,start.omega)
        let t=(tail.end.time+start.time)/2,dt=t-start.time,mid=try XCTUnwrap(tail.sample(at:t))
        XCTAssertEqual(mid.position.y,start.position.y+start.velocity.y*dt-0.5*9.81*dt*dt,accuracy:1e-14)
        XCTAssertEqual(mid.position.x,start.position.x+start.velocity.x*dt,accuracy:1e-14)
        XCTAssertEqual(mid.velocity.y,start.velocity.y-9.81*dt,accuracy:1e-14)
        XCTAssertEqual(mid.omega,start.omega)
        XCTAssertEqual(tail.end.position.y,0.697)
        let late=try XCTUnwrap(tail.sample(at:tail.end.time+10))
        XCTAssertEqual(late.position,tail.end.position);XCTAssertEqual(late.velocity,.zero);XCTAssertEqual(late.omega,.zero)
        XCTAssertNil(tail.sample(at:start.time-0.01))
    }
}

extension PocketGeometryInjectionV63Tests {
    func testFarTableKeepsPlanarMotionWithoutSpatialStepBudget() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let geometry=TableGeometry.chineseEightBallQiuJi(surfaceY:asset.surfaceY)
        let initial=BallState(position:SCNVector3(0,asset.surfaceY+r,0),velocity:SCNVector3(0.3,0,0),
                              angularVelocity:SCNVector3(0,0,-0.3/r),state:.rolling,name:"cue")
        let mixed=EventDrivenEngine(tableGeometry:geometry),planar=EventDrivenEngine(tableGeometry:geometry)
        mixed.setBall(initial);planar.setBall(initial)
        try mixed.simulateMixedWithLocalPockets(maxTime:0.5,pairRestitution:0.8,pairFriction:0,maxEvents:32,
            collectsPocketedBalls:true,ballMaterial:.ballPhysics,staticMaterial:.tablePhysics(clothRestitution:0.3))
        planar.simulate(maxTime:0.5,highFidelityBounds:true)
        let a=try XCTUnwrap(mixed.getBall("cue")),b=try XCTUnwrap(planar.getBall("cue"))
        XCTAssertEqual(a.position.x,b.position.x,accuracy:1e-6)
        XCTAssertEqual(a.velocity.x,b.velocity.x,accuracy:1e-6)
        XCTAssertEqual(a.angularVelocity.z,b.angularVelocity.z,accuracy:1e-5)
        XCTAssertEqual(a.state,b.state)
        XCTAssertTrue(mixed.getTrajectoryRecorder().localHandoffs.isEmpty)
        XCTAssertEqual(mixed.resolvedEvents.count,planar.resolvedEvents.count)
    }

    /// DR-292: the liner is dissipative, so the 4 m/s entry that the rigid liner used to
    /// return is now captured as well; energy must still be non-increasing inside the bag.
    func testCombinedPocketMaterialsCaptureSlowAndFastEntries() throws {
        let g=Double(TablePhysics.gravity),r=Double(BallPhysics.radius)
        func energy(_ s:LocalPocketSimulation.State)->Double {
            0.5*simd_length_squared(s.velocity)+0.2*r*r*simd_length_squared(s.omega)+g*s.position.y
        }
        for index in [0,4] {
            for speed:Float in [0.5,4] {
                let engine=try makeCollectionEntryEngine(pocketIndex:index)
                var initial=try XCTUnwrap(engine.getBall("cue"))
                initial.velocity=initial.velocity*(speed/0.5);initial.angularVelocity=initial.angularVelocity*(speed/0.5)
                engine.setBall(initial)
                try engine.simulateMixedWithLocalPockets(maxTime:0.5,pairRestitution:0.9,pairFriction:0.05,
                    collectsPocketedBalls:true,ballMaterial:.ballPhysics,staticMaterial:.tablePhysics(clothRestitution:0.3))
                let recorder=engine.getTrajectoryRecorder()
                let spans=try XCTUnwrap(recorder.localIntervalsByBallName["cue"]),start=try XCTUnwrap(spans.first?.start)
                for span in spans {
                    XCTAssertLessThanOrEqual(energy(span.end),energy(start)+4*g*1e-6)
                }
                XCTAssertEqual(recorder.confirmedCaptures.count,1,"speed=\(speed) pocket=\(index)")
                XCTAssertEqual(recorder.confirmedCaptures.first?.pocketID,"pocket_\(index)")
                XCTAssertNotNil(recorder.collectionTailsByBallName["cue"],"speed=\(speed) pocket=\(index)")
                XCTAssertFalse(recorder.localHandoffs.contains{$0.kind == .returned},"speed=\(speed) pocket=\(index)")
            }
        }
    }

    func testTableSurfaceProfilePreservesIndicesAndSeparatesMaterials() throws {
        let asset=try PocketGeometryAsset.load(),roles=try asset.surfaceRoles()
        let surfaces=try asset.contactSurfaces(material:.tablePhysics(clothRestitution:0.3))
        let prototype=try asset.contactSurfaces(material:.prototype)
        XCTAssertEqual(surfaces.count,asset.tablePatches.count)
        for i in surfaces.indices {
            XCTAssertEqual(surfaces[i].triangle.a,asset.tablePatches[i].triangle.a)
            XCTAssertEqual(surfaces[i].triangle.b,asset.tablePatches[i].triangle.b)
            XCTAssertEqual(surfaces[i].triangle.c,asset.tablePatches[i].triangle.c)
            XCTAssertEqual(prototype[i].restitution,0.3);XCTAssertEqual(prototype[i].friction,0.2)
            if roles[i] == .clothBed {
                XCTAssertEqual(surfaces[i].rollingFriction,Double(SpinPhysics.rollingFriction))
                XCTAssertEqual(surfaces[i].spinFriction,Double(SpinPhysics.spinFriction))
            } else { XCTAssertEqual(surfaces[i].rollingFriction,0);XCTAssertEqual(surfaces[i].spinFriction,0) }
        }
        XCTAssertThrowsError(try asset.contactSurfaces(material:.tablePhysics(clothRestitution:.nan)))
    }

    func testMixedTableClothMatchesExistingRollingMotion() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        let position=SCNVector3(0,asset.surfaceY+r,center.z+0.14),velocity=SCNVector3(0.2,0,0)
        let omega=SCNVector3(0,2,-0.2/r)
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        engine.setBall(.init(position:position,velocity:velocity,angularVelocity:omega,state:.rolling,name:"cue"))
        try engine.simulateMixedWithLocalPockets(maxTime:0.1,pairRestitution:0.8,pairFriction:0,
                                                staticMaterial:.tablePhysics(clothRestitution:0.3))
        // Float bed+radius is 3.725nm above the exact Double support plane.
        // Compare from physical landing, rather than charging cloth friction
        // during that real (albeit visually negligible) free-flight interval.
        let gap=Double(position.y)-Double(asset.surfaceY)-Double(r)
        let landingTime=try XCTUnwrap(engine.getTrajectoryRecorder().localStaticContacts.first?.contact.time)
        XCTAssertEqual(landingTime,sqrt(2*gap/Double(TablePhysics.gravity)),accuracy:1e-9)
        let landedPosition=position+velocity*Float(landingTime)
        let expected=AnalyticalMotion.evolveRolling(position:landedPosition,velocity:velocity,angularVelocity:omega,dt:Float(0.1-landingTime))
        let actual=try XCTUnwrap(engine.getBall("cue"))
        XCTAssertEqual(actual.position.x,expected.position.x,accuracy:2e-6)
        XCTAssertEqual(actual.velocity.x,expected.velocity.x,accuracy:2e-6)
        XCTAssertEqual(actual.angularVelocity.y,expected.angularVelocity.y,accuracy:2e-6)
        XCTAssertEqual(actual.angularVelocity.z,expected.angularVelocity.z,accuracy:2e-5)
        XCTAssertTrue(engine.resolvedEvents.isEmpty)
    }

    func testMeasuredCushionTableProfileResponse() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        engine.setBall(.init(position:SCNVector3(0.14,asset.surfaceY+r,center.z+0.12),velocity:SCNVector3(0,0,-1),
                            angularVelocity:SCNVector3(-1/r,0,0),state:.rolling,name:"cue"))
        try engine.simulateMixedWithLocalPockets(maxTime:0.15,pairRestitution:0.8,pairFriction:0,
                                                staticMaterial:.tablePhysics(clothRestitution:0.3))
        let recorder=engine.getTrajectoryRecorder(),roles=try asset.surfaceRoles()
        let hit=try XCTUnwrap(recorder.localStaticContacts.first{roles[$0.contact.surface] == .cushion}).contact
        let span=try XCTUnwrap(recorder.localIntervalsByBallName["cue"]?.first{$0.start.time<=hit.time && $0.end.time>=hit.time})
        let before=try XCTUnwrap(span.sample(at:hit.time,beforeEndpoint:true)),after=try XCTUnwrap(span.sample(at:hit.time))
        XCTAssertLessThan(before.velocity.z,0);XCTAssertGreaterThan(after.velocity.z,0)
        let legacy=CollisionResolver.resolveCushionCollisionPure(velocity:SCNVector3(Float(before.velocity.x),Float(before.velocity.y),Float(before.velocity.z)),
            angularVelocity:SCNVector3(Float(before.omega.x),Float(before.omega.y),Float(before.omega.z)),normal:SCNVector3(0,0,1))
        let rows:[String:Any]=["time":hit.time,"normal":[hit.normal.x,hit.normal.y,hit.normal.z],
            "incoming":[before.velocity.x,before.velocity.y,before.velocity.z],"spatialOutgoing":[after.velocity.x,after.velocity.y,after.velocity.z],
            "legacyOutgoing":[legacy.velocity.x,legacy.velocity.y,legacy.velocity.z]]
        let attachment=XCTAttachment(data:try JSONSerialization.data(withJSONObject:rows),uniformTypeIdentifier:"public.json")
        attachment.name="cushion-table-profile-response";attachment.lifetime = .keepAlways;add(attachment)
    }

    func testSpatialCushionIDsRetainMainRailsAndFiniteArcs() throws {
        let geometry=TableGeometry.chineseEightBallQiuJi(surfaceY:BTTablePhysics.surfaceY)
        for i in 0..<6 {
            let rail=geometry.linearCushions[i]
            let p=SIMD3(Double(rail.start.x+rail.end.x)/2,0,Double(rail.start.z+rail.end.z)/2)
            XCTAssertEqual(geometry.nearestCushionIndex(to:p),i)
        }
        for (i,arc) in geometry.circularCushions.enumerated() {
            let tau=2*Double.pi
            let span=(Double(arc.endAngle-arc.startAngle)+tau).truncatingRemainder(dividingBy:tau)
            let angle=Double(arc.startAngle)+span/2
            let p=SIMD3(Double(arc.center.x)+Double(arc.radius)*cos(angle),0,Double(arc.center.z)+Double(arc.radius)*sin(angle))
            XCTAssertEqual(geometry.nearestCushionIndex(to:p),geometry.linearCushions.count+i)
        }
    }

    func testMixedCushionContactEmitsOnceAcrossContinuation() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        func make()->EventDrivenEngine {
            let e=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
            e.setBall(.init(position:SCNVector3(0.14,asset.surfaceY+r,center.z+0.12),velocity:SCNVector3(0,0,-1),
                            angularVelocity:SCNVector3(-1/r,0,0),state:.rolling,name:"cue"))
            return e
        }
        let whole=make(),split=make()
        try whole.simulateMixedWithLocalPockets(maxTime:0.2,pairRestitution:0.8,pairFriction:0)
        try split.simulateMixedWithLocalPockets(maxTime:0.041,pairRestitution:0.8,pairFriction:0)
        XCTAssertTrue(split.resolvedEvents.isEmpty)
        try split.simulateMixedWithLocalPockets(maxTime:0.2,pairRestitution:0.8,pairFriction:0)
        for e in [whole,split] {
            let events=e.resolvedEvents.filter { if case .ballCushion = $0 { return true };return false }
            XCTAssertEqual(events.count,1)
            guard case .ballCushion(let ball,let index,let normal)=try XCTUnwrap(events.first) else { return XCTFail("Expected cushion") }
            XCTAssertEqual(ball,"cue");XCTAssertEqual(index,3)
            XCTAssertGreaterThan(normal.z,0.9)
            XCTAssertGreaterThan(try XCTUnwrap(e.getBall("cue")).velocity.z,0)
            XCTAssertFalse(e.getTrajectoryRecorder().localStaticContacts.isEmpty)
        }
        XCTAssertEqual(whole.resolvedEventTimes,split.resolvedEventTimes)
    }

    func testMixedClothLandingDoesNotCountAsCushion() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        let e=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        e.setBall(.init(position:SCNVector3(0,asset.surfaceY+r+0.01,center.z+0.10),velocity:SCNVector3(0,-0.5,0),
                        angularVelocity:SCNVector3Zero,state:.sliding,name:"cue"))
        try e.simulateMixedWithLocalPockets(maxTime:0.05,pairRestitution:0.8,pairFriction:0)
        XCTAssertFalse(e.getTrajectoryRecorder().localStaticContacts.isEmpty,"Exercise an actual cloth impact")
        XCTAssertFalse(e.resolvedEvents.contains { if case .ballCushion = $0 { return true };return false })
        XCTAssertTrue(e.getTrajectoryRecorder().confirmedCaptures.isEmpty)
    }

    func testPhysicalSurfaceRolesUseConnectedComponents() throws {
        let asset=try PocketGeometryAsset.load(),roles=try asset.surfaceRoles()
        XCTAssertEqual(roles.count,asset.tablePatches.count)
        XCTAssertEqual(roles,try asset.surfaceRoles())
        XCTAssertEqual(Set(roles.map(\.rawValue)),Set(["clothBed","cushion","leather"]))
        var counts:[String:Int]=[:],rows:[[String:Any]]=[]
        for (patch,role) in zip(asset.tablePatches,roles) {
            counts[role.rawValue,default:0]+=1
            if role == .leather { XCTAssertEqual(patch.material,"Leather") }
            else { XCTAssertEqual(patch.material,"TaiNi") }
            let t=patch.triangle,center=(t.a+t.b+t.c)/3
            rows.append(["role":role.rawValue,"center":[center.x,center.y,center.z]])
        }
        // The bed's folded lip remains cloth even below the playing plane.
        XCTAssertTrue(zip(asset.tablePatches,roles).contains { p,r in
            r == .clothBed && min(p.triangle.a.y,p.triangle.b.y,p.triangle.c.y)<Double(asset.surfaceY)-0.02
        })
        // Winding and input order cannot change a physical component's role.
        let reversed=asset.tablePatches.reversed().map { p in
            PocketContactMesh.Patch(triangle:.init(a:p.triangle.c,b:p.triangle.b,c:p.triangle.a),material:p.material)
        }
        XCTAssertEqual(try PocketSurfaceRoles.classify(reversed,surfaceY:asset.surfaceY),Array(roles.reversed()))
        XCTAssertThrowsError(try PocketSurfaceRoles.classify(Array(asset.tablePatches.prefix(1)),surfaceY:asset.surfaceY))
        let data=try JSONSerialization.data(withJSONObject:["surfaceY":asset.surfaceY,"counts":counts,"faces":rows])
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name="physical-surface-roles";attachment.lifetime = .keepAlways;add(attachment)
    }

    func testSharedBallMaterialPreservesPlanarFitAndUsesContactSpin() throws {
        typealias V=SIMD3<Double>
        let r=Double(BallPhysics.radius)
        for i in 0...1000 {
            let speed=Float(i)/100
            let old:Float=0.009951+0.108*expf(-1.088*speed)
            XCTAssertEqual(BallPhysics.contactFriction(relativeSurfaceSpeed:speed).bitPattern,old.bitPattern)
        }
        let zero=SpatialBallContact.Motion(velocity:.zero,angularVelocity:.zero)
        for omegaY in [0.0,1/r,-1/r] {
            let a=SpatialBallContact.Motion(velocity:V(2,0,1),angularVelocity:V(0,omegaY,0))
            let m=SpatialBallContact.material(source:.ballPhysics,a:a,b:zero,normal:V(-1,0,0),radius:r,restitution:0.1,friction:0.9)
            // A's +X contact point has tangential speed 1 - R*omegaY.
            XCTAssertEqual(m.friction,Double(BallPhysics.contactFriction(relativeSurfaceSpeed:Float(abs(1-r*omegaY)))))
            XCTAssertEqual(m.restitution,Double(BallPhysics.restitution))
            let swapped=SpatialBallContact.material(source:.ballPhysics,a:zero,b:a,normal:V(1,0,0),radius:r,restitution:0.1,friction:0.9)
            XCTAssertEqual(m.friction,swapped.friction)
        }
        let supplied=SpatialBallContact.material(source:.supplied,a:zero,b:zero,normal:V(1,0,0),radius:r,restitution:0.7,friction:0.03)
        XCTAssertEqual(supplied.restitution,0.7);XCTAssertEqual(supplied.friction,0.03)
    }

    func testStandardSpatialBallMaterialMatchesObliqueImpulse() throws {
        typealias V=SIMD3<Double>
        let r=Double(BallPhysics.radius)
        let solver=LocalPocketSimulation(surfaces:[],radius:r,gravity:.zero,tolerance:1e-6,ballMaterial:.ballPhysics)
        let response=try solver.resolveContactGroup([
            .init(time:0,position:.zero,velocity:V(1,0,1),omega:.zero),
            .init(time:0,position:V(2*r,0,0),velocity:.zero,omega:.zero)
        ],accelerations:[.zero,.zero],pairRestitution:0.1,pairFriction:0.9)
        let normalImpulse=(1+Double(BallPhysics.restitution))/2
        let tangentImpulse=Double(BallPhysics.contactFriction(relativeSurfaceSpeed:1))*normalImpulse
        XCTAssertEqual(response.states[0].velocity.x,1-normalImpulse,accuracy:1e-12)
        XCTAssertEqual(response.states[1].velocity.x,normalImpulse,accuracy:1e-12)
        XCTAssertEqual(response.states[0].velocity.z,1-tangentImpulse,accuracy:1e-12)
        XCTAssertEqual(response.states[1].velocity.z,tangentImpulse,accuracy:1e-12)
        XCTAssertEqual(response.states[0].omega.y,2.5*tangentImpulse/r,accuracy:1e-10)
        XCTAssertEqual(response.states[1].omega.y,2.5*tangentImpulse/r,accuracy:1e-10)
    }

    func testMixedStandardMaterialSurvivesContinuationAndRejectsSwitch() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        for (name,x,vx):(String,Float,Float) in [("cue",-0.04,1),("object",0.04,-1)] {
            engine.setBall(.init(position:SCNVector3(x,asset.surfaceY+r+0.04,center.z+0.10),
                                 velocity:SCNVector3(vx,0,0),angularVelocity:SCNVector3Zero,state:.sliding,name:name))
        }
        try engine.simulateMixedWithLocalPockets(maxTime:0.0041,pairRestitution:0.1,pairFriction:0.9,ballMaterial:.ballPhysics)
        XCTAssertThrowsError(try engine.simulateMixedWithLocalPockets(maxTime:0.0042,pairRestitution:0.1,pairFriction:0.9))
        try engine.simulateMixedWithLocalPockets(maxTime:0.02,pairRestitution:0.1,pairFriction:0.9,ballMaterial:.ballPhysics)
        XCTAssertEqual(try XCTUnwrap(engine.getBall("cue")).velocity.x,-BallPhysics.restitution,accuracy:1e-6)
        XCTAssertEqual(try XCTUnwrap(engine.getBall("object")).velocity.x,BallPhysics.restitution,accuracy:1e-6)
        XCTAssertEqual(engine.resolvedEvents.count,1)
    }

    func testSpatialRuleEventsExcludeSupportAndSeparation() throws {
        typealias V=SIMD3<Double>
        let constraint=SpatialBallContact.Constraint(a:0,b:1,normal:V(-1,0,0),restitution:0.95,friction:0.05)
        for (relativeX,expected) in [(0.0,0),(-0.5,0),(0.5,1)] {
            let incoming=[LocalPocketSimulation.State(time:0.2,position:.zero,velocity:V(relativeX,0,0),omega:.zero),
                          LocalPocketSimulation.State(time:0.2,position:V(2*Double(BallPhysics.radius),0,0),velocity:.zero,omega:.zero)]
            let events=EventDrivenEngine.spatialImpactEvents(names:["cue","object"],incoming:incoming,constraints:[constraint])
            XCTAssertEqual(events.count,expected,"Relative X velocity: \(relativeX)")
            if let event=events.first,expected==1 {
                guard case .ballBall(let a,let b)=event else { return XCTFail("Expected ball contact") }
                XCTAssertEqual(a,"cue");XCTAssertEqual(b,"object")
            }
        }
    }

    func testLocalPairRuleEventUsesIncomingStateAndCommitsOnce() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        for (name,x,vx):(String,Float,Float) in [("cue",-0.04,1),("object",0.04,-1)] {
            engine.setBall(.init(position:SCNVector3(x,asset.surfaceY+r+0.04,center.z+0.10),
                                 velocity:SCNVector3(vx,0,0),angularVelocity:SCNVector3Zero,state:.sliding,name:name))
        }
        try engine.simulateMixedWithLocalPockets(maxTime:0.005,pairRestitution:0.8,pairFriction:0)
        XCTAssertTrue(engine.resolvedEvents.isEmpty,"Do not publish the future contact at a request boundary")
        try engine.simulateMixedWithLocalPockets(maxTime:0.02,pairRestitution:0.8,pairFriction:0)
        XCTAssertEqual(engine.resolvedEvents.count,1)
        guard case .ballBall(let a,let b)=try XCTUnwrap(engine.resolvedEvents.first) else { return XCTFail("Expected pair impact") }
        XCTAssertEqual(Set([a,b]),Set(["cue","object"]))
        XCTAssertEqual(engine.firstBallBallCollisionTime,engine.resolvedEventTimes.first)
        XCTAssertLessThan(try XCTUnwrap(engine.getBall("cue")).velocity.x,0)
        XCTAssertGreaterThan(try XCTUnwrap(engine.getBall("object")).velocity.x,0)
        try engine.simulateMixedWithLocalPockets(maxTime:0.025,pairRestitution:0.8,pairFriction:0)
        XCTAssertEqual(engine.resolvedEvents.count,1,"Separating continuation must not emit another contact")
    }

    func testMixedCollectionDoesNotCapturePocketRebounds() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        for index in [0,4] {
            let engine=try makeCollectionEntryEngine(pocketIndex:index)
            var initial=try XCTUnwrap(engine.getBall("cue"))
            initial.velocity=initial.velocity*8
            initial.angularVelocity=initial.angularVelocity*8
            engine.setBall(initial)
            try engine.simulateMixedWithLocalPockets(maxTime:0.5,pairRestitution:0.9,pairFriction:0.05,collectsPocketedBalls:true)
            let recorder=engine.getTrajectoryRecorder()
            XCTAssertTrue(recorder.confirmedCaptures.isEmpty)
            XCTAssertTrue(recorder.collectionTailsByBallName.isEmpty)
            XCTAssertTrue(recorder.pocketEntries.isEmpty)
            XCTAssertFalse(recorder.localStaticContacts.isEmpty,"Exercise a real pocket collision")
            XCTAssertTrue(recorder.localHandoffs.contains{$0.ballName=="cue" && $0.kind == .returned},"Rebound must regain planar ownership")
            let final=try XCTUnwrap(engine.getBall("cue"))
            XCTAssertFalse(final.isPocketed)
            XCTAssertEqual(final.position.y,asset.surfaceY+r,accuracy:1e-6)
            XCTAssertEqual(final.velocity.y,0)
            let inward=index==0 ? SCNVector3(1/sqrtf(2),0,1/sqrtf(2)) : SCNVector3(0,0,1)
            XCTAssertGreaterThan(final.velocity.x*inward.x+final.velocity.z*inward.z,0)
            XCTAssertFalse(engine.resolvedEvents.contains{if case .pocket = $0 { return true };return false})
        }
    }

    func testMixedCollectionDistinguishesSupportedAndUnsupportedPocketEdge() throws {
        try verifySupportedAndUnsupportedPocketEdge(useAppDefault:false)
    }

    func testAppDefaultDistinguishesSupportedAndUnsupportedPocketEdge() throws {
        try verifySupportedAndUnsupportedPocketEdge(useAppDefault:true)
    }

    func testDefaultPocketEdgeStepSensitivity() throws {
        let asset=try PocketGeometryAsset.load()
        // Exact Float input measured by the shared middle-pocket boundary fixture.
        let initial=SCNVector3(0,asset.surfaceY+BallPhysics.radius,-0.62423384)
        var positions:[SCNVector3]=[]
        for step in [0.0025,0.00125] {
            let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
            engine.setBall(.init(position:initial,velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,state:.stationary,name:"cue"))
            let termination=try engine.simulateMixedWithLocalPockets(maxTime:0.25,maxStep:step,
                pairRestitution:Double(BallPhysics.restitution),pairFriction:0,collectsPocketedBalls:true,
                ballMaterial:.ballPhysics,staticMaterial:.tablePhysics(clothRestitution:0.3))
            let final=try XCTUnwrap(engine.getBall("cue"))
            positions.append(final.position)
            print("[W07 edge step] step=\(step) termination=\(termination) final=\(final)")
        }
        XCTAssertEqual(positions[0].z,positions[1].z,accuracy:1e-6,"静止临界球的步长差异必须受已有空间误差预算约束")
    }

    private func verifySupportedAndUnsupportedPocketEdge(useAppDefault:Bool) throws {
        let asset=try PocketGeometryAsset.load(),r=Double(BallPhysics.radius)
        for index in [0,4] {
            let pocket=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[index]
            let center=SIMD3(Double(pocket.x),Double(asset.surfaceY),Double(pocket.z))
            let inward=index==0 ? SIMD3<Double>(1/sqrt(2),0,1/sqrt(2)) : SIMD3<Double>(0,0,1)
            let mesh=asset.pockets[index]
            func supported(_ distance:Double)->Bool {
                let p=center+inward*distance
                return mesh.patches.contains { simd_length_squared($0.triangle.closestPoint(to:p)-p)<1e-20 }
            }
            var outside=0.0,inside=0.12
            XCTAssertFalse(supported(outside));XCTAssertTrue(supported(inside))
            for _ in 0..<32 {
                let mid=(outside+inside)/2
                if supported(mid) { inside=mid } else { outside=mid }
            }
            for offset in (useAppDefault ? [0.0002,-0.0002,-0.002] : [0.0002,-0.0002]) {
                let p=center+inward*((outside+inside)/2+offset)+SIMD3(0,r,0)
                let initial=SCNVector3(Float(p.x),Float(p.y),Float(p.z))
                let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
                engine.setBall(.init(position:initial,velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,state:.stationary,name:"cue"))
                if useAppDefault {
                    let termination=engine.simulatePrediction(model:.spatialPockets,maxTime:1)
                    XCTAssertEqual(termination,.settled,"pocket=\(index) offset=\(offset)")
                } else {
                    try engine.simulateMixedWithLocalPockets(maxTime:1,pairRestitution:0.9,pairFriction:0.05,collectsPocketedBalls:true)
                }
                let recorder=engine.getTrajectoryRecorder(),final=try XCTUnwrap(engine.getBall("cue"))
                if useAppDefault {
                    print("[W07 default edge state] pocket=\(index) offset=\(offset) initial=\(initial) final=\(final) local=\(String(describing:recorder.localIntervalsByBallName["cue"]?.last))")
                }
                if offset>0 || (useAppDefault && offset == -0.0002) {
                    XCTAssertTrue(recorder.confirmedCaptures.isEmpty)
                    XCTAssertFalse(final.isPocketed)
                    XCTAssertEqual(final.position.y,initial.y,accuracy:1e-6)
                    XCTAssertEqual(final.velocity.x,0);XCTAssertEqual(final.velocity.y,0);XCTAssertEqual(final.velocity.z,0)
                } else {
                    XCTAssertEqual(recorder.confirmedCaptures.count,1)
                    XCTAssertTrue(final.isPocketed)
                    XCTAssertEqual(recorder.confirmedCaptures.first?.pocketID,"pocket_\(index)")
                    XCTAssertLessThan(try XCTUnwrap(recorder.confirmedCaptures.first).state.velocity.y,0)
                }
                XCTAssertTrue(recorder.pocketEntries.isEmpty)
            }
        }
    }

    @MainActor
    func testMixedCollectionPlaybackUsesSharedSpatialTail() throws {
        let asset=try PocketGeometryAsset.load()
        for index in [0,4] {
            let engine=try makeCollectionEntryEngine(pocketIndex:index)
            try engine.simulateMixedWithLocalPockets(maxTime:1,pairRestitution:0.9,pairFriction:0.05,collectsPocketedBalls:true)
            let recorder=engine.getTrajectoryRecorder(),tail=try XCTUnwrap(recorder.collectionTailsByBallName["cue"])
            let playback=TrajectoryPlayback(recorder:recorder,surfaceY:asset.surfaceY+BallPhysics.radius)
            for t in [Float(tail.start.time-0.001),Float((tail.start.time+tail.end.time)/2),Float(tail.end.time+0.1)] {
                let spatial=try XCTUnwrap(recorder.spatialStateAt(ballName:"cue",time:Double(t)))
                let display=try XCTUnwrap(playback.stateAt(ballName:"cue",time:t))
                XCTAssertEqual(display.position.x,Float(spatial.position.x))
                XCTAssertEqual(display.position.y,Float(spatial.position.y))
                XCTAssertEqual(display.position.z,Float(spatial.position.z))
                XCTAssertEqual(display.velocity.y,Float(spatial.velocity.y))
                XCTAssertLessThan(display.position.y,asset.surfaceY)
            }
            XCTAssertEqual(playback.collectionOpacity(ballName:"cue",time:Float(tail.end.time)),1)
            let fadeMiddle=Float(tail.end.time+TrajectoryPlayback.pocketPauseDuration+TrajectoryPlayback.pocketFadeDuration/2)
            XCTAssertEqual(try XCTUnwrap(playback.collectionOpacity(ballName:"cue",time:fadeMiddle)),0.5,accuracy:1e-6)
            XCTAssertEqual(playback.collectionOpacity(ballName:"cue",time:Float(tail.end.time+2)),0)
            for speed:Float in [0.5,1,2] {
                let action=try XCTUnwrap(playback.action(for:SCNNode(),ballName:"cue",speed:speed,removeOnPocket:false))
                XCTAssertEqual(action.duration,(tail.end.time+TrajectoryPlayback.pocketPauseDuration+TrajectoryPlayback.pocketFadeDuration)/Double(speed),accuracy:1e-6)
                let exportEnd=SequenceVideoExporter.motionEndTime(duration:playback.duration,playback:playback,
                    pocketedBallNames:["cue"],speed:speed)
                XCTAssertEqual(Double(exportEnd)/Double(speed),action.duration,accuracy:1e-6,
                    "Spatial export must finish with the live action, without an extra legacy tail")
                let laterTableEnd=playback.collectionPresentationEnd+2
                XCTAssertEqual(SequenceVideoExporter.motionEndTime(duration:laterTableEnd,playback:playback,
                    pocketedBallNames:["cue"],speed:speed),laterTableEnd,
                    "An early capture must not add waiting after the other balls finish")
                XCTAssertEqual(SequenceVideoExporter.motionEndTime(duration:laterTableEnd,playback:playback,
                    pocketedBallNames:["cue","legacy"],speed:speed),
                    laterTableEnd+Float(TrajectoryPlayback.pocketSettleDuration)*speed,
                    "Mixed records must retain the frame-only capture allowance")
            }
        }
    }

    @MainActor
    func testCollectionQueriesRemainIndependentAcrossBackwardAndForwardTimes() throws {
        for index in [0, 4] {
            let engine = try makeCollectionEntryEngine(pocketIndex: index)
            try engine.simulateMixedWithLocalPockets(maxTime: 1, pairRestitution: 0.9,
                pairFriction: 0.05, collectsPocketedBalls: true)
            let recorder = engine.getTrajectoryRecorder()
            let tail = try XCTUnwrap(recorder.collectionTailsByBallName["cue"])
            let playback = TrajectoryPlayback(recorder: recorder,
                surfaceY: BTTablePhysics.surfaceY + BallPhysics.radius)
            let middle = Float((tail.start.time + tail.end.time) / 2)
            let hidden = playback.collectionPresentationEnd + 1
            let midBefore = try XCTUnwrap(playback.stateAt(ballName: "cue", time: middle))
            for time in [hidden, Float(0), middle, hidden + 10, middle, hidden] {
                let state = try XCTUnwrap(playback.stateAt(ballName: "cue", time: time))
                if time >= hidden {
                    XCTAssertEqual(state.position.x, Float(tail.end.position.x), accuracy: 0.00001)
                    XCTAssertEqual(state.position.y, Float(tail.end.position.y), accuracy: 0.00001)
                    XCTAssertEqual(state.position.z, Float(tail.end.position.z), accuracy: 0.00001)
                    XCTAssertEqual(playback.collectionOpacity(ballName: "cue", time: time), 0)
                } else if time == middle {
                    XCTAssertEqual(state.position.x, midBefore.position.x)
                    XCTAssertEqual(state.position.y, midBefore.position.y)
                    XCTAssertEqual(state.position.z, midBefore.position.z)
                    XCTAssertEqual(playback.collectionOpacity(ballName: "cue", time: time), 1)
                }
            }
            XCTAssertEqual(recorder.collectionTailsByBallName.count, 1)
        }
    }

    @MainActor
    func testSpatialActionMatchesTimeQueryAcrossFrameRatesAndSpeeds() throws {
        continueAfterFailure = false
        for pocketIndex in [0, 4] {
            let engine = try makeCollectionEntryEngine(pocketIndex: pocketIndex)
            try engine.simulateMixedWithLocalPockets(maxTime: 1, pairRestitution: 0.9,
                pairFriction: 0.05, collectsPocketedBalls: true)
            let recorder = engine.getTrajectoryRecorder()
            let playback = TrajectoryPlayback(recorder: recorder, surfaceY: BTTablePhysics.surfaceY + BallPhysics.radius)
            XCTAssertNotNil(recorder.collectionTailsByBallName["cue"])
            for speed: Float in [0.5, 1, 2] {
                for fps in [30, 60] {
                    let scene = SCNScene()
                    let node = SCNNode(geometry: SCNSphere(radius: 0.03))
                    scene.rootNode.addChildNode(node)
                    let camera = SCNNode()
                    camera.camera = SCNCamera()
                    camera.position = SCNVector3(0, 0, 5)
                    scene.rootNode.addChildNode(camera)
                    let renderer = SCNRenderer(device: nil, options: nil)
                    renderer.scene = scene
                    renderer.pointOfView = camera
                    let action = try XCTUnwrap(playback.action(for: node, ballName: "cue", speed: speed, removeOnPocket: false))
                    node.runAction(action)
                    let frameCount = Int(ceil(action.duration * Double(fps)))
                    for frame in 0...frameCount {
                        let wallTime = Double(frame) / Double(fps)
                        _ = renderer.snapshot(atTime: wallTime, with: CGSize(width: 16, height: 16), antialiasingMode: .none)
                        let t = min(Float(wallTime) * speed, Float(action.duration) * speed)
                        let expected = try XCTUnwrap(playback.stateAt(ballName: "cue", time: t))
                        let context = "pocket=\(pocketIndex) speed=\(speed) fps=\(fps) frame=\(frame)"
                        XCTAssertEqual(node.position.x, expected.position.x, accuracy: 0.00001, context)
                        XCTAssertEqual(node.position.y, expected.position.y, accuracy: 0.00001, context)
                        XCTAssertEqual(node.position.z, expected.position.z, accuracy: 0.00001, context)
                        XCTAssertEqual(node.opacity, try XCTUnwrap(playback.collectionOpacity(ballName: "cue", time: t)), accuracy: 0.00001, context)
                    }
                    XCTAssertEqual(node.opacity, 0, accuracy: 0.00001,
                        "The Float animation endpoint uses the same opacity tolerance as each frame")
                }
            }
        }
    }

    @MainActor
    func testSpatialActionPauseResumesWithoutAdvancingCapture() throws {
        continueAfterFailure = false
        for pocketIndex in [0, 4] {
            let engine = try makeCollectionEntryEngine(pocketIndex: pocketIndex)
            try engine.simulateMixedWithLocalPockets(maxTime: 1, pairRestitution: 0.9,
                pairFriction: 0.05, collectsPocketedBalls: true)
            let recorder = engine.getTrajectoryRecorder()
            let playback = TrajectoryPlayback(recorder: recorder, surfaceY: BTTablePhysics.surfaceY + BallPhysics.radius)
            let tail = try XCTUnwrap(recorder.collectionTailsByBallName["cue"])
            for speed: Float in [0.5, 1, 2] {
                for fps in [30, 60] {
                    let scene = SCNScene()
                    let node = SCNNode(geometry: SCNSphere(radius: 0.03))
                    scene.rootNode.addChildNode(node)
                    let camera = SCNNode()
                    camera.camera = SCNCamera()
                    camera.position = SCNVector3(0, 0, 5)
                    scene.rootNode.addChildNode(camera)
                    let renderer = SCNRenderer(device: nil, options: nil)
                    renderer.scene = scene
                    renderer.pointOfView = camera
                    let action = try XCTUnwrap(playback.action(for: node, ballName: "cue", speed: speed, removeOnPocket: false))
                    var actionElapsed: CGFloat = 0
                    let clockProbe = SCNAction.customAction(duration: action.duration) { _, elapsed in
                        actionElapsed = elapsed
                    }
                    node.runAction(.group([action, clockProbe]))
                    let frameCount = Int(ceil(action.duration * Double(fps)))
                    let pauseFrame = max(1, Int(((tail.start.time + tail.end.time) / 2) / Double(speed) * Double(fps)))
                    var resumeClock: Double?
                    var frozenElapsed: CGFloat = 0
                    var prePauseBudget: Double = 0
                    for frame in 0...frameCount {
                        if frame > 0 { Thread.sleep(forTimeInterval: 1.0 / Double(fps)) }
                        let renderClock = CACurrentMediaTime()
                        _ = renderer.snapshot(atTime: renderClock, with: CGSize(width: 16, height: 16), antialiasingMode: .none)
                        if let resumedAt = resumeClock {
                            // Bracket actual elapsed time instead of mixing a synthetic
                            // render clock with SceneKit's real-time pause bookkeeping.
                            XCTAssertLessThanOrEqual(Double(actionElapsed - frozenElapsed),
                                prePauseBudget + CACurrentMediaTime() - resumedAt)
                            resumeClock = nil
                        }
                        let t = min(Float(actionElapsed) * speed, Float(action.duration) * speed)
                        let expected = try XCTUnwrap(playback.stateAt(ballName: "cue", time: t))
                        let context = "pocket=\(pocketIndex) speed=\(speed) fps=\(fps) frame=\(frame)"
                        XCTAssertEqual(node.position.x, expected.position.x, accuracy: 0.00001, context)
                        XCTAssertEqual(node.position.y, expected.position.y, accuracy: 0.00001, context)
                        XCTAssertEqual(node.position.z, expected.position.z, accuracy: 0.00001, context)
                        XCTAssertEqual(node.opacity, try XCTUnwrap(playback.collectionOpacity(ballName: "cue", time: t)), accuracy: 0.00001, context)
                        if frame == pauseFrame {
                            let position = node.position
                            let opacity = node.opacity
                            frozenElapsed = actionElapsed
                            node.isPaused = true
                            prePauseBudget = CACurrentMediaTime() - renderClock
                            for _ in 1...5 {
                                Thread.sleep(forTimeInterval: 1.0 / Double(fps))
                                _ = renderer.snapshot(atTime: CACurrentMediaTime(),
                                    with: CGSize(width: 16, height: 16), antialiasingMode: .none)
                                XCTAssertEqual(node.position.x, position.x)
                                XCTAssertEqual(node.position.y, position.y)
                                XCTAssertEqual(node.position.z, position.z)
                                XCTAssertEqual(node.opacity, opacity)
                                XCTAssertEqual(actionElapsed, frozenElapsed)
                            }
                            resumeClock = CACurrentMediaTime()
                            node.isPaused = false
                        }
                    }
                    XCTAssertEqual(node.opacity, 0, accuracy: 0.00001,
                        "The Float animation endpoint uses the same opacity tolerance as each frame")
                }
            }
        }
    }

    func testMixedCollectionNearPocketFrames() throws {
        for index in [0,4] {
            let engine=try makeCollectionEntryEngine(pocketIndex:index)
            try engine.simulateMixedWithLocalPockets(maxTime:1,pairRestitution:0.9,pairFriction:0.05,collectsPocketedBalls:true)
            let recorder=engine.getTrajectoryRecorder(),tail=try XCTUnwrap(recorder.collectionTailsByBallName["cue"])
            let scene=AngleTrainingScene();scene.setupScene(mobileRendering:true);scene.hideAllBalls()
            let cue=try XCTUnwrap(scene.cueBallNode);cue.isHidden=false
            let playback=TrajectoryPlayback(recorder:recorder,surfaceY:scene.surfaceY+BallPhysics.radius)
            let pocket=AngleSceneCalculator.pocketPositions(surfaceY:scene.surfaceY)[index]
            let inward=index==0 ? SIMD3<Double>(1/sqrt(2),0,1/sqrt(2)) : SIMD3<Double>(0,0,1)
            let across=SIMD3(inward.z,0,-inward.x)
            let center=SIMD3(Double(pocket.x),Double(scene.surfaceY),Double(pocket.z))
            let camera=scene.cameraNode.clone()
            camera.camera=scene.cameraNode.camera?.copy() as? SCNCamera
            camera.camera?.usesOrthographicProjection=false;camera.camera?.fieldOfView=45
            camera.camera?.zNear=0.001;camera.camera?.zFar=10
            let eye=center+inward*0.36+across*0.16+SIMD3(0,0.28,0)
            camera.position=SCNVector3(Float(eye.x),Float(eye.y),Float(eye.z))
            let focus=center+inward*0.025+SIMD3(0,-0.025,0)
            camera.look(at:SCNVector3(Float(focus.x),Float(focus.y),Float(focus.z)))
            scene.rootNode.addChildNode(camera)
            let view=SCNView(frame:CGRect(x:0,y:0,width:402,height:500))
            view.scene=scene;view.pointOfView=camera;view.backgroundColor = .black
            let times=[0.0,tail.start.time-0.06,tail.start.time-0.02,tail.start.time,
                       tail.end.time,tail.end.time+0.475,tail.end.time+0.61]
            var frames:[UIImage]=[]
            for time in times {
                let state=try XCTUnwrap(playback.stateAt(ballName:"cue",time:Float(time)))
                cue.position=state.position
                cue.opacity=try XCTUnwrap(playback.collectionOpacity(ballName:"cue",time:Float(time)))
                SCNTransaction.flush();view.layoutIfNeeded()
                let projected=view.projectPoint(cue.position)
                XCTAssertTrue(projected.x>0 && projected.x<402 && projected.y>0 && projected.y<500)
                frames.append(view.snapshot())
            }
            let format=UIGraphicsImageRendererFormat();format.scale=1
            let sheet=UIGraphicsImageRenderer(size:CGSize(width:402*4,height:530*2),format:format).image { context in
                UIColor.black.setFill();context.fill(CGRect(x:0,y:0,width:1608,height:1060))
                for (i,frame) in frames.enumerated() {
                    let x=(i%4)*402,y=(i/4)*530
                    frame.draw(in:CGRect(x:x,y:y+30,width:402,height:500))
                    let label=String(format:"pocket %d | t=%.4f s",index,times[i])
                    (label as NSString).draw(at:CGPoint(x:x+8,y:y+5),withAttributes:[.font:UIFont.monospacedSystemFont(ofSize:16,weight:.regular),.foregroundColor:UIColor.white])
                }
            }
            let attachment=XCTAttachment(image:sheet)
            attachment.name="collection-near-pocket-\(index)";attachment.lifetime = .keepAlways;add(attachment)
        }
    }
}

extension PocketGeometryInjectionV63Tests {
    func testMixedContactStopCommitsImpactAndCanResume() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        func make()->EventDrivenEngine {
            let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
            for (name,x,vx):(String,Float,Float) in [("cue",-0.04,1),("object",0.04,-1)] {
                engine.setBall(.init(position:SCNVector3(x,asset.surfaceY+r+0.04,center.z+0.10),
                    velocity:SCNVector3(vx,0,0),angularVelocity:SCNVector3Zero,state:.sliding,name:name))
            }
            return engine
        }
        let full=make(),stopped=make()
        try full.simulateMixedWithLocalPockets(maxTime:0.025,pairRestitution:0.8,pairFriction:0)
        try stopped.simulateMixedWithLocalPockets(maxTime:0.005,pairRestitution:0.8,pairFriction:0,
            stopAfterContactBetween:("object","cue"))
        XCTAssertEqual(stopped.spatialTime,0.005)
        XCTAssertTrue(stopped.resolvedEvents.isEmpty)
        let reason=try stopped.simulateMixedWithLocalPockets(maxTime:0.025,pairRestitution:0.8,pairFriction:0,
            stopAfterContactBetween:("object","cue"))
        XCTAssertEqual(reason,.contactResolved)
        let t=try XCTUnwrap(stopped.spatialTime)
        XCTAssertLessThan(t,0.025)
        XCTAssertEqual(Float(t),full.firstBallBallCollisionTime)
        XCTAssertEqual(stopped.resolvedEvents.count,1)
        for name in ["cue","object"] {
            let expected=try XCTUnwrap(full.getTrajectoryRecorder().spatialStateAt(ballName:name,time:t))
            let actual=try XCTUnwrap(stopped.getBall(name))
            XCTAssertEqual(Double(actual.velocity.x),expected.velocity.x,accuracy:1e-7)
            XCTAssertEqual(Double(actual.velocity.y),expected.velocity.y,accuracy:1e-7)
            XCTAssertEqual(Double(actual.position.y),expected.position.y,accuracy:1e-7)
        }
        // A historical contact cannot trigger another stop during continuation.
        try stopped.simulateMixedWithLocalPockets(maxTime:0.025,pairRestitution:0.8,pairFriction:0,
            stopAfterContactBetween:("cue","object"))
        XCTAssertEqual(stopped.spatialTime,full.spatialTime)
        XCTAssertEqual(stopped.resolvedEventTimes,full.resolvedEventTimes)
        for name in ["cue","object"] {
            let a=try XCTUnwrap(stopped.getBall(name)),b=try XCTUnwrap(full.getBall(name))
            XCTAssertEqual(a.position.x,b.position.x);XCTAssertEqual(a.position.y,b.position.y)
            XCTAssertEqual(a.velocity.x,b.velocity.x);XCTAssertEqual(a.velocity.y,b.velocity.y)
        }
    }

    func testMixedInterestStopDoesNotDiscardAirbornePotentialEnergy() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        for mode in 0...2 {
            let airborne=mode==1
            let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
            engine.setBall(.init(position:SCNVector3(0,asset.surfaceY+r,0),velocity:SCNVector3Zero,
                angularVelocity:SCNVector3Zero,state:.stationary,name:"object"))
            let position=mode==0 ? SCNVector3(0.5,asset.surfaceY+r,0) :
                SCNVector3(0,asset.surfaceY+r+(airborne ? 0.04:0),center.z+(airborne ? 0.10:0.03))
            engine.setBall(.init(position:position,
                velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,state:airborne ? .sliding:.stationary,name:"cue"))
            let reason=try engine.simulateMixedWithLocalPockets(maxTime:0.02,pairRestitution:0.8,pairFriction:0,
                earlyStopBallNames:["object"])
            XCTAssertEqual(reason,mode==0 ? .interestResolved:.timeLimit)
            XCTAssertEqual(engine.spatialTime,mode==0 ? 0:0.02)
            if mode != 0 {
                XCTAssertFalse(engine.getTrajectoryRecorder().localHandoffs.isEmpty)
                XCTAssertLessThan(try XCTUnwrap(engine.getBall("cue")).velocity.y,0)
            }
        }
    }
}

extension PocketGeometryInjectionV63Tests {
    func testMixedContactStopPreservesSimultaneousGroup() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        let center=AngleSceneCalculator.pocketPositions(surfaceY:asset.surfaceY)[4]
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
        for (name,x):(String,Float) in [("left",-0.04),("right",0.04)] {
            engine.setBall(.init(position:SCNVector3(center.x+x,asset.surfaceY+r+0.02,center.z+0.17),
                velocity:SCNVector3(0,0,8),angularVelocity:SCNVector3Zero,state:.sliding,name:name))
        }
        engine.setBall(.init(position:SCNVector3(center.x,asset.surfaceY+r,center.z+0.225),
            velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,state:.stationary,name:"target"))
        try engine.simulateMixedWithLocalPockets(maxTime:0.01,pairRestitution:0.8,pairFriction:0,
            stopAfterContactBetween:("left","target"))
        let hits=engine.resolvedEvents.indices.filter{if case .ballBall=engine.resolvedEvents[$0] {return true};return false}
        XCTAssertEqual(hits.count,2)
        let t=try XCTUnwrap(engine.spatialTime)
        XCTAssertLessThan(t,0.01)
        for index in hits { XCTAssertEqual(engine.resolvedEventTimes[index],Float(t)) }
        let left=try XCTUnwrap(engine.getBall("left")),right=try XCTUnwrap(engine.getBall("right"))
        XCTAssertEqual(left.velocity.x,-right.velocity.x,accuracy:1e-6)
        XCTAssertEqual(left.velocity.z,right.velocity.z,accuracy:1e-6)
        XCTAssertGreaterThan(try XCTUnwrap(engine.getBall("target")).velocity.z,0)
    }
}

extension PocketGeometryInjectionV63Tests {
    func testSimulationTerminationSeparatesRestTimeAndBudget() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        func make(moving:Bool=true)->EventDrivenEngine {
            let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
            engine.setBall(.init(position:SCNVector3(0,asset.surfaceY+r,0),
                velocity:SCNVector3(moving ? 0.3:0,0,0),
                angularVelocity:SCNVector3(0,0,moving ? -0.3/r:0),state:moving ? .rolling:.stationary,name:"cue"))
            return engine
        }
        XCTAssertEqual(make(moving:false).simulate(),.settled)
        let budget=make()
        XCTAssertEqual(budget.simulate(maxEvents:0,maxTime:1),.eventLimit)
        XCTAssertEqual(budget.currentTime,0)
        XCTAssertGreaterThan(try XCTUnwrap(budget.getBall("cue")).velocity.x,0)
        XCTAssertEqual(make().simulate(maxTime:0.01),.timeLimit)
        XCTAssertEqual(try make(moving:false).simulateMixedWithLocalPockets(maxTime:0.01,
            pairRestitution:0.8,pairFriction:0),.settled)
        XCTAssertEqual(try make().simulateMixedWithLocalPockets(maxTime:0.01,
            pairRestitution:0.8,pairFriction:0),.timeLimit)
        XCTAssertThrowsError(try make().simulateMixedWithLocalPockets(maxTime:0.5,
            pairRestitution:0.8,pairFriction:0,maxEvents:1)) { error in
            guard case EventDrivenEngine.LocalIntegrationFailure.eventBudget=error else {
                return XCTFail("Expected explicit work-budget failure, got \(error)")
            }
        }
    }

    func testFreePredictionPropagatesPartialSimulationStatus() {
        func run(events:Int,time:Float)->ShotPrediction {
            ShotPredictor.simulateFree(cueBall:SCNVector3Zero,aimDir:SCNVector3(1,0,0),velocity:0.3,
                spinX:0,spinY:0,surfaceY:0.8,balls:[],maxEvents:events,maxTime:time,includePresentation:false)
        }
        XCTAssertNil(ShotPrediction().termination)
        let budget=run(events:0,time:1),horizon=run(events:500,time:0.01)
        XCTAssertEqual(budget.termination,.eventLimit)
        XCTAssertEqual(horizon.termination,.timeLimit)
        XCTAssertGreaterThan(budget.cueFinalSpeed,0)
        XCTAssertGreaterThan(horizon.cueFinalSpeed,0)
    }
}

extension PocketGeometryInjectionV63Tests {
    @MainActor
    func testIncompletePredictionCannotEnableShotOrExport() throws {
        let vm=PositionPlayViewModel()
        func apply(_ prediction:ShotPrediction) {
            vm.applySolvedShot(.init(before:BoardSnapshot(onTable:[:]),
                shot:PlannedShot(targetKey:"",pocket:"",velocity:0.3,spinX:0,spinY:0,
                                 freeAim:CanvasPoint(x:1,y:0)),prediction:prediction))
        }
        func prediction(time:Float)->ShotPrediction {
            ShotPredictor.simulateFree(cueBall:SCNVector3Zero,aimDir:SCNVector3(1,0,0),velocity:0.3,
                spinX:0,spinY:0,surfaceY:0.8,balls:[],maxTime:time)
        }
        let complete=prediction(time:15),partial=prediction(time:0.01)
        XCTAssertEqual(complete.termination,.settled)
        XCTAssertEqual(partial.termination,.timeLimit)
        apply(complete)
        XCTAssertTrue(vm.isFeasible)
        XCTAssertNotNil(vm.solvedShot)
        XCTAssertNoThrow(try SequenceVideoExporter.validateCompletedSimulation(complete))
        apply(partial)
        XCTAssertFalse(vm.isFeasible)
        XCTAssertNil(vm.solvedShot)
        XCTAssertTrue(vm.statusText.contains("模拟未完成"))
        vm.play()
        XCTAssertFalse(vm.isPlaying)
        XCTAssertThrowsError(try SequenceVideoExporter.validateCompletedSimulation(partial))
        // Stopping a search after its requested contact/interest is insufficient
        // for publishing an entire table's terminal positions.
        for reason:EventDrivenEngine.Termination? in [nil,.eventLimit,.contactResolved,.interestResolved,.failed("local solve failed")] {
            var candidate=complete;candidate.termination=reason
            apply(candidate)
            XCTAssertFalse(vm.isFeasible)
            XCTAssertThrowsError(try SequenceVideoExporter.validateCompletedSimulation(candidate))
            XCTAssertEqual(candidate.hasResolvedSearchState,reason == .interestResolved)
        }
        apply(complete)
        XCTAssertTrue(vm.isFeasible,"A later valid result must recover normally")
    }
}

extension PocketGeometryInjectionV63Tests {
    func testRealFreePredictionUsesLocalCaptureWithoutPlanarFallback() throws {
        let model=EventDrivenEngine.SimulationModel.localPockets(material:.tablePhysics(clothRestitution:0.3))
        for index in [0,4] {
            let source=try makeCollectionEntryEngine(pocketIndex:index)
            let ball=try XCTUnwrap(source.getBall("cue"))
            let direction=ball.velocity*2
            let prediction=ShotPredictor.simulateFree(cueBall:ball.position,aimDir:direction,velocity:0.5,
                spinX:0,spinY:0,surfaceY:ball.position.y-BallPhysics.radius,balls:[],maxTime:1,
                simulationModel:model)
            XCTAssertEqual(prediction.termination,.settled)
            XCTAssertTrue(prediction.cuePocketed)
            let recorder=try XCTUnwrap(prediction.recorder)
            XCTAssertEqual(recorder.confirmedCaptures.count,1)
            XCTAssertEqual(recorder.confirmedCaptures.first?.pocketID,"pocket_\(index)")
            XCTAssertNotNil(recorder.collectionTailsByBallName[ShotInput.cueBallName])
            XCTAssertTrue(recorder.pocketEntries.isEmpty,"Do not substitute the old capture-circle result")
        }
    }

    func testRealPocketPredictionPreservesSelectedSimulationModel() throws {
        let source=try makeCollectionEntryEngine(pocketIndex:4)
        let object=try XCTUnwrap(source.getBall("cue")),r=BallPhysics.radius
        let direction=object.velocity*2
        let input=ShotInput(simulationModel:.localPockets(material:.tablePhysics(clothRestitution:0.3)),
            cueBall:object.position-direction*0.2,targetBall:object.position,pocketIndex:4,
            velocity:1,spinX:0,spinY:0,surfaceY:object.position.y-r)
        let prediction=ShotPredictor.predictForPositionSolve(input,aimOffset:0,maxTime:1,includePresentation:false)
        if case .failed(let diagnostic)=prediction.termination { XCTFail(diagnostic) }
        let recorder=try XCTUnwrap(prediction.recorder)
        XCTAssertTrue(prediction.simObjectPotted)
        XCTAssertTrue(recorder.confirmedCaptures.contains{$0.ballName==ShotInput.targetBallName})
        XCTAssertTrue(recorder.pocketEntries.isEmpty)
    }

    func testPredictionAdapterSeparatesEventBudgetFromLocalWorkFailure() throws {
        let asset=try PocketGeometryAsset.load(),r=BallPhysics.radius
        func make()->EventDrivenEngine {
            let e=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:asset.surfaceY))
            e.setBall(.init(position:SCNVector3(0,asset.surfaceY+r,0),velocity:SCNVector3(0.3,0,0),
                angularVelocity:SCNVector3(0,0,-0.3/r),state:.rolling,name:"cue"))
            return e
        }
        let model=EventDrivenEngine.SimulationModel.localPockets(material:.tablePhysics(clothRestitution:0.3))
        XCTAssertEqual(make().simulatePrediction(model:model,maxEvents:0,maxTime:1),.eventLimit)
        let failing=make()
        XCTAssertEqual(failing.simulatePrediction(model:model,maxTime:1,maxLocalSteps:1),.failed("eventBudget"))
        XCTAssertEqual(failing.currentTime,0)
        XCTAssertTrue(failing.resolvedEvents.isEmpty)
        XCTAssertTrue(failing.getTrajectoryRecorder().confirmedCaptures.isEmpty)
        XCTAssertEqual(make().simulatePrediction(model:model,maxEvents:32,maxTime:0.5),.timeLimit)
    }
}

extension PocketGeometryInjectionV63Tests {
    func testWarmLocalPredictionPreparationCost() throws {
        let asset=try PocketGeometryAsset.load()
        let model=EventDrivenEngine.SimulationModel.localPockets(material:.tablePhysics(clothRestitution:0.3))
        var milliseconds:[Double]=[]
        for _ in 0..<5 {
            let start=DispatchTime.now().uptimeNanoseconds
            let result=ShotPredictor.simulateFree(cueBall:SCNVector3Zero,aimDir:SCNVector3(1,0,0),velocity:0.3,
                spinX:0,spinY:0,surfaceY:asset.surfaceY,balls:[],maxTime:0.01,includePresentation:false,
                simulationModel:model)
            milliseconds.append(Double(DispatchTime.now().uptimeNanoseconds-start)/1_000_000)
            XCTAssertEqual(result.termination,.timeLimit)
        }
        print("[W07 warm preparation ms] \(milliseconds)")
        let data=try JSONSerialization.data(withJSONObject:["milliseconds":milliseconds],options:[.prettyPrinted])
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name="warm-local-prediction-cost";attachment.lifetime = .keepAlways;add(attachment)
    }
}

extension PocketGeometryInjectionV63Tests {
    func testSupportedStationaryPocketBallEndsShot() throws {
        let engine=try makeCollectionEntryEngine(pocketIndex:4)
        var cue=try XCTUnwrap(engine.getBall("cue"))
        cue.velocity=SCNVector3Zero;cue.angularVelocity=SCNVector3Zero;cue.state = .stationary
        engine.setBall(cue)
        let result=engine.simulatePrediction(model:.localPockets(material:.tablePhysics(clothRestitution:0.3)),maxTime:0.1)
        print("[W07 resting local] \(result) \(String(describing:engine.getBall("cue")))")
        XCTAssertEqual(result,.settled)
        XCTAssertLessThan(engine.currentTime,0.1)
        XCTAssertTrue(engine.getTrajectoryRecorder().confirmedCaptures.isEmpty)
    }

    func testCompletePocketPredictionEndsWithRestingCue() throws {
        let source=try makeCollectionEntryEngine(pocketIndex:4)
        let object=try XCTUnwrap(source.getBall("cue")),r=BallPhysics.radius
        let direction=object.velocity*2
        let input=ShotInput(simulationModel:.localPockets(material:.tablePhysics(clothRestitution:0.3)),
            cueBall:object.position-direction*0.2,targetBall:object.position,pocketIndex:4,
            velocity:1,spinX:0,spinY:0,surfaceY:object.position.y-r)
        let prediction=ShotPredictor.predictForPositionSolve(input,aimOffset:0,maxTime:3)
        print("[W07 complete prediction] \(String(describing:prediction.termination)) speed=\(prediction.cueFinalSpeed)")
        XCTAssertEqual(prediction.termination,.settled)
        XCTAssertTrue(prediction.simObjectPotted)
        XCTAssertTrue(prediction.hasFinalTableState)
    }
}

extension PocketGeometryInjectionV63Tests {
    @MainActor
    func testBankKickRejectIncompleteFreePredictionsAndRecover() throws {
        let complete=ShotPredictor.simulateFree(cueBall:SCNVector3Zero,aimDir:SCNVector3(1,0,0),velocity:0.3,
            spinX:0,spinY:0,surfaceY:0.8,balls:[])
        XCTAssertTrue(complete.hasFinalTableState)
        let bank=BankShotViewModel(),kick=DiamondSystemViewModel()
        func verify(scene:AngleTrainingScene,accept:(ShotPrediction,[String:BallRestState])->Bool,
                    notice:()->String?,playing:()->Bool) throws {
            let cueStart=SCNVector3(0.2,0.8+BallPhysics.radius,0)
            let targetStart=SCNVector3(-0.2,0.8+BallPhysics.radius,0)
            scene.applyBallLayout(cueBallPosition:cueStart,targetBallNumber:8,targetPosition:targetStart)
            let cue=try XCTUnwrap(scene.cueBallNode)
            let before=["__cue":BallRestState(position:cueStart,orientation:BallSpinIntegrator.identityOrientation),
                        "__target":BallRestState(position:targetStart,orientation:BallSpinIntegrator.identityOrientation)]
            for reason:EventDrivenEngine.Termination? in [nil,.timeLimit,.eventLimit,.contactResolved,.interestResolved,.failed("test failure")] {
                var partial=complete;partial.termination=reason
                cue.position=SCNVector3(0.8,cueStart.y,0.2)
                XCTAssertFalse(accept(partial,before))
                XCTAssertEqual(cue.position.x,cueStart.x);XCTAssertEqual(cue.position.z,cueStart.z)
                XCTAssertFalse(playing())
                XCTAssertTrue(notice()?.contains("模拟未完成") == true)
            }
            XCTAssertTrue(accept(complete,before))
            XCTAssertNil(notice())
        }
        try verify(scene:bank.scene,accept:bank.acceptFreePrediction,notice:{bank.simulationNotice},playing:{bank.isPlaying})
        try verify(scene:kick.scene,accept:kick.acceptFreePrediction,notice:{kick.simulationNotice},playing:{kick.isPlaying})
    }
}

extension PocketGeometryInjectionV63Tests {
    func testLocalPocketPredictionCompletesActualAimSearch() throws {
        let source = try makeCollectionEntryEngine(pocketIndex: 4)
        let object = try XCTUnwrap(source.getBall("cue"))
        let direction = object.velocity * 2
        let input = ShotInput(simulationModel: .localPockets(material: .tablePhysics(clothRestitution: 0.3)),
            cueBall: object.position-direction*0.2, targetBall: object.position, pocketIndex: 4,
            velocity: 1, spinX: 0, spinY: 0, surfaceY: object.position.y-BallPhysics.radius)
        let begin = CFAbsoluteTimeGetCurrent()
        let prediction = ShotPredictor.predict(input)
        print("[W07 local aim search] \(CFAbsoluteTimeGetCurrent()-begin)s termination=\(String(describing: prediction.termination))")
        XCTAssertTrue(prediction.hasFinalTableState)
        XCTAssertTrue(prediction.simObjectPotted)
        XCTAssertTrue(try XCTUnwrap(prediction.recorder).confirmedCaptures.contains {
            $0.ballName == ShotInput.targetBallName
        })
    }
}

extension PocketGeometryInjectionV63Tests {
    /// W17-A (user decision 2026-09-14): the default verdict is the planar drop-circle
    /// rule; physical bag capture only runs when a caller asks for `.spatialPockets`.
    func testDefaultPredictionUsesPlanarVerdictAndSpatialOnlyWhenRequested() throws {
        let source = try makeCollectionEntryEngine(pocketIndex: 4)
        let object = try XCTUnwrap(source.getBall("cue"))
        let planar = ShotPredictor.simulateFree(cueBall: object.position,
            aimDir: object.velocity * 2, velocity: 0.5, spinX: 0, spinY: 0,
            surfaceY: object.position.y-BallPhysics.radius, balls: [])
        XCTAssertTrue(planar.hasFinalTableState)
        let planarRecorder = try XCTUnwrap(planar.recorder)
        XCTAssertTrue(planar.cuePocketed)
        XCTAssertTrue(planarRecorder.confirmedCaptures.isEmpty, "default path must not run bag physics")
        XCTAssertFalse(planarRecorder.pocketEntries.isEmpty)

        let spatial = ShotPredictor.simulateFree(cueBall: object.position,
            aimDir: object.velocity * 2, velocity: 0.5, spinX: 0, spinY: 0,
            surfaceY: object.position.y-BallPhysics.radius, balls: [],
            simulationModel: .spatialPockets)
        XCTAssertTrue(spatial.hasFinalTableState)
        let spatialRecorder = try XCTUnwrap(spatial.recorder)
        XCTAssertTrue(spatialRecorder.confirmedCaptures.contains { $0.ballName == ShotInput.cueBallName })
        XCTAssertTrue(spatialRecorder.pocketEntries.isEmpty)
    }
}

extension PocketGeometryInjectionV63Tests {
    func testSingleBodyOuterControlMatchesExistingAdaptiveTrials() throws {
        typealias V = SIMD3<Double>
        let asset = try PocketGeometryAsset.load()
        let r = Double(BallPhysics.radius)
        let solver = try asset.localSimulation(material: .tablePhysics(clothRestitution: 0.3), ballMaterial: .ballPhysics)
        let centers = AngleSceneCalculator.pocketPositions(surfaceY: asset.surfaceY)
        var comparisons = 0
        for index in centers.indices {
            let c = centers[index]
            let inward = simd_normalize(V(c.x == 0 ? 0 : (c.x > 0 ? -1 : 1), 0, c.z > 0 ? -1 : 1))
            let above = V(Double(c.x), Double(asset.surfaceY) + 2*r, Double(c.z)) + inward*0.12
            let hit = try XCTUnwrap(asset.pockets[index].patches.compactMap {
                $0.triangle.firstContact(position: above, velocity: V(0,-1,0), acceleration: .zero, radius: r, horizon: 2*r)
            }.min(by: { $0.time < $1.time }))
            let velocity = -inward*0.5
            let initial = LocalPocketSimulation.State(time: 0, position: above + V(0,-hit.time,0),
                velocity: velocity, omega: V(velocity.z/r,0,-velocity.x/r))
            let path = try solver.run(from: initial, duration: 0.5, maxStep: 0.0025)
            for t in [0.0, 0.1, 0.2, 0.3, 0.4] {
                let state = t == 0 ? initial : try XCTUnwrap(path.intervals.first(where: {
                    $0.start.time <= t && $0.end.time >= t
                })?.sample(at: t))
                let dt = 0.0025
                let shared = try solver.advanceTogether(from: [state], duration: dt, maxStep: dt,
                    pairRestitution: 0.9, pairFriction: 0.05, useSingleBodyShortcut: false)
                let independent = try solver.advanceTogether(from: [state], duration: dt, maxStep: dt,
                    pairRestitution: 0.9, pairFriction: 0.05)
                let a = try XCTUnwrap(shared.states.first), b = try XCTUnwrap(independent.states.first)
                XCTAssertEqual(shared.time, independent.time, accuracy: 1e-12)
                XCTAssertLessThanOrEqual(simd_length(a.position-b.position), solver.tolerance, "pocket \(index), t \(t)")
                XCTAssertLessThanOrEqual(dt*simd_length(a.velocity-b.velocity), solver.tolerance)
                XCTAssertLessThanOrEqual(r*dt*simd_length(a.omega-b.omega), solver.tolerance)
                XCTAssertTrue(shared.constraints.isEmpty && independent.constraints.isEmpty)
                XCTAssertEqual(shared.staticContacts[0].count, independent.staticContacts[0].count)
                for (x,y) in zip(shared.staticContacts[0], independent.staticContacts[0]) {
                    XCTAssertEqual(x.surface,y.surface)
                    XCTAssertEqual(x.time,y.time,accuracy: 1e-6)
                }
                comparisons += 1
            }
        }
        XCTAssertEqual(comparisons, 30)
    }
}


extension PocketGeometryInjectionV63Tests {
    func testSlidingPocketEntryComparesSingleAndSharedControl() throws {
        let solver = try PocketGeometryAsset.load().localSimulation(
            material: .tablePhysics(clothRestitution: 0.3), ballMaterial: .ballPhysics)
        func vector(_ p: SCNVector3) -> SIMD3<Double> { .init(Double(p.x), Double(p.y), Double(p.z)) }
        for index in [0, 4] {
            let engine = try makeCollectionEntryEngine(pocketIndex: index)
            let ball = try XCTUnwrap(engine.getBall("cue"))
            let strike = CueBallStrike.executeStrike(aimDirection: ball.velocity * 2,
                velocity: 0.5, spinX: 0, spinY: 0, elevation: 0)
            let initial = LocalPocketSimulation.State(time: 0, position: vector(ball.position),
                velocity: vector(strike.velocity), omega: vector(strike.angularVelocity))
            for shortcut in [false, true] {
                do {
                    let result = try solver.advanceTogether(from: [initial], duration: 0.1, maxStep: 0.0025,
                        pairRestitution: Double(BallPhysics.restitution), pairFriction: 0,
                        useSingleBodyShortcut: shortcut)
                    print("[W07 sliding control] pocket=\(index) shortcut=\(shortcut) time=\(result.time) end=\(result.states)")
                    XCTAssertEqual(result.time, 0.1, accuracy: 1e-12)
                } catch {
                    XCTFail("pocket=\(index) shortcut=\(shortcut): \(error)")
                }
            }
        }
    }
}
