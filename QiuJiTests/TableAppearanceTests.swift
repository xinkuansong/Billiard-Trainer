import XCTest
import SceneKit
import Metal
import SwiftUI
@testable import QiuJi

@MainActor
final class TableAppearanceTests: XCTestCase {
    func testCombinationPreviewFrustumStaysInsideRoom() async throws {
        let host = UIHostingController(rootView:
            AppearanceCombinationPreview(label: "预览", identifier: "appearance.preview"))
        let window = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow))
        host.view.frame = CGRect(x: 0, y: 0, width: 370, height: 236.8)
        window.addSubview(host.view)
        defer { host.view.removeFromSuperview() }
        host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000)
        func findSceneView(_ view: UIView) -> SCNView? {
            if let sceneView = view as? SCNView { return sceneView }
            return view.subviews.lazy.compactMap { findSceneView($0) }.first
        }
        let view = try XCTUnwrap(findSceneView(host.view))
        let scene = try XCTUnwrap(view.scene as? AngleTrainingScene)
        let camera = try XCTUnwrap(scene.cameraNode)
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        func capture(_ name: String) {
            SCNTransaction.flush()
            let size = CGSize(width: 1000, height: 640)
            _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            let attachment = XCTAttachment(image: image)
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        scene.applyTableStyle(.charcoal, showsSights: true)
        scene.applyClothColor(.green)
        scene.installReferenceRoom(style: .tournament)
        let fixedTransform = camera.transform
        let fixedScale = try XCTUnwrap(camera.camera).orthographicScale
        camera.position = SCNVector3(1.595, 1.8425, 1.925)
        camera.look(at: SCNVector3(0, 0.55, 0))
        camera.camera?.orthographicScale = 1.35
        capture("appearance-camera-before")
        camera.transform = fixedTransform
        camera.camera?.orthographicScale = fixedScale
        for style in RoomStyle.allCases {
            scene.installReferenceRoom(style: style)
            capture("appearance-camera-after-" + style.rawValue)
        }
        // Exercise the actual SCNView projection at compact, standard and capped
        // tablet widths. A centre-inside-room check missed the original defect.
        for width: CGFloat in [343, 370, 608] {
            view.frame = CGRect(x: 0, y: 0, width: width, height: width * 0.64)
            view.layoutIfNeeded()
            SCNTransaction.flush()
            _ = view.snapshot()
            for x in [Float(0), Float(view.bounds.width)] {
                for y in [Float(0), Float(view.bounds.height)] {
                    let corner = view.unprojectPoint(SCNVector3(x, y, 0))
                    XCTAssertLessThan(abs(corner.x), BakedTrainingRoom.roomLength / 2 - 0.1)
                    XCTAssertLessThan(abs(corner.z), BakedTrainingRoom.roomWidth / 2 - 0.1)
                    XCTAssertGreaterThan(corner.y, 0)
                    XCTAssertLessThan(corner.y, BakedTrainingRoom.ceilingHeight)
                }
            }
        }
        view.scene = nil
        view.pointOfView = nil
    }

    func testPackagedPreviewsAndTexturesDecode() throws {
        for style in TableStyle.allCases {
            for suffix in ["", "_noSights"] {
                let url = try XCTUnwrap(Bundle.main.url(forResource: style.previewName + suffix, withExtension: "png"))
                let preview = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
                XCTAssertEqual(preview.width, 1000); XCTAssertEqual(preview.height, 640)
            }
            if style != .standard {
                let textureURL = try XCTUnwrap(Bundle.main.url(forResource: "TableWood_" + style.rawValue, withExtension: "png"))
                let texture = try XCTUnwrap(UIImage(contentsOfFile: textureURL.path)?.cgImage)
                XCTAssertEqual(texture.width, 1024); XCTAssertEqual(texture.height, 1024)
            }
        }
    }
    func testPreferencePersistsAndUnknownValueFallsBack() throws {
        let name = "TableStyleTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertTrue(UserPreferences(defaults: defaults).showsTableSights)
        let preferences = UserPreferences(defaults: defaults)
        preferences.showsTableSights = false
        XCTAssertFalse(UserPreferences(defaults: defaults).showsTableSights)
        preferences.showsTableSights = true
        XCTAssertTrue(UserPreferences(defaults: defaults).showsTableSights)
        XCTAssertEqual(UserPreferences(defaults: defaults).tableStyle, .charcoal)
        for style in TableStyle.allCases {
            let prefs = UserPreferences(defaults: defaults)
            prefs.tableStyle = style
            XCTAssertEqual(UserPreferences(defaults: defaults).tableStyle, style)
        }
        defaults.set("future-style", forKey: TableStyle.preferenceKey)
        XCTAssertEqual(UserPreferences(defaults: defaults).tableStyle, .charcoal)
    }

    func testSwitchingRestoresStandardAndIsolatesScenes() throws {
        for pipeline in 0..<3 {
            let scene = AngleTrainingScene()
            scene.setupScene(enhancedRendering: pipeline == 1, mobileRendering: pipeline == 2)
            XCTAssertEqual(scene.installedTableStyle, .charcoal)
            XCTAssertTrue(scene.applyTableStyle(.standard))
            let untouched = AngleTrainingScene(); untouched.setupScene()
            let table = try XCTUnwrap(scene.tableNode)
            let legShell = try XCTUnwrap(table.childNode(withName: "Plane_007", recursively: true))
            XCTAssertEqual(legShell.renderingOrder, pipeline == 2 ? -1 : 0,
                           "Only mobile materials stabilize the duplicate leg shell; legacy export is preserved")
            var before: [(SCNGeometry, [SCNMaterial])] = []
            table.enumerateChildNodes { node, _ in
                if let geometry = node.geometry { before.append((geometry, geometry.materials)) }
            }
            let camera = scene.cameraNode.transform
            let ballPositions = scene.allBallNodes.mapValues { $0.simdPosition }
            for style in [TableStyle.walnut, .blossom, .ivory, .charcoal, .walnut] {
                XCTAssertTrue(scene.applyTableStyle(style))
                XCTAssertEqual(scene.installedTableStyle, style)
                XCTAssertEqual(untouched.installedTableStyle, .charcoal)
                XCTAssertEqual(scene.allBallNodes.mapValues { $0.simdPosition }, ballPositions)
                XCTAssertTrue(SCNMatrix4EqualToMatrix4(scene.cameraNode.transform, camera))
                var changed = 0
                for (geometry, originals) in before {
                    XCTAssertEqual(geometry.materials.count, originals.count)
                    for (index, original) in originals.enumerated() {
                        if TableAppearance.materialNames.contains(original.name ?? "") {
                            changed += 1
                            XCTAssertFalse(geometry.materials[index] === original)
                            if original.name == "White" {
                                XCTAssertNotEqual(geometry.materials[index].shaderModifiers?[.surface], original.shaderModifiers?[.surface])
                            } else { XCTAssertNotNil(geometry.materials[index].diffuse.contents) }
                        } else { XCTAssertTrue(geometry.materials[index] === original) }
                    }
                }
                XCTAssertGreaterThan(changed, 0)
            }
            XCTAssertTrue(scene.applyTableStyle(.standard))
            for (geometry, originals) in before {
                for (index, original) in originals.enumerated() {
                    XCTAssertTrue(geometry.materials[index] === original)
                }
            }
        }
    }

    func testRenderAllStylesAndStandardRestoration() throws {
        let scene = AngleTrainingScene()
        scene.setupScene(mobileRendering: true)
        XCTAssertTrue(scene.applyTableStyle(.standard))
        scene.setCameraMode(.perspective3D, animated: false)
        scene.rootNode.childNode(withName: "reference_room", recursively: false)?.isHidden = true
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        scene.applyBallLayout(cueBallPosition: SCNVector3(-0.45,y,0), targetBallNumber: 3,
                              targetPosition: SCNVector3(0.35,y,0.12))
        scene.cameraNode.position = SCNVector3(2.9, 2.9, 3.5)
        scene.cameraNode.look(at: SCNVector3(0, 0.55, 0))
        scene.cameraNode.camera?.usesOrthographicProjection = true
        scene.cameraNode.camera?.orthographicScale = 1.35
        scene.background.contents = UIColor(white: 0.14, alpha: 1)
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene; renderer.pointOfView = scene.cameraNode
        renderer.delegate = scene.contactOcclusion
        func snapshot() -> UIImage {
            _ = renderer.snapshot(atTime: 0, with: CGSize(width: 1000, height: 640), antialiasingMode: .multisampling4X)
            return renderer.snapshot(atTime: 0, with: CGSize(width: 1000, height: 640), antialiasingMode: .multisampling4X)
        }
        let standard = snapshot()
        var images: [Data] = []
        for style in TableStyle.allCases {
            XCTAssertTrue(scene.applyTableStyle(style))
            let image = snapshot()
            let data = try XCTUnwrap(image.pngData()); images.append(data)
            let attachment = XCTAttachment(image: image)
            attachment.name = style.previewName; attachment.lifetime = .keepAlways; add(attachment)
            XCTAssertTrue(scene.applyTableStyle(style, showsSights: false))
            let hidden = snapshot()
            XCTAssertNotEqual(hidden.pngData(), data)
            let hiddenAttachment = XCTAttachment(image: hidden)
            hiddenAttachment.name = style.previewName + "_noSights"
            hiddenAttachment.lifetime = .keepAlways; add(hiddenAttachment)
            XCTAssertTrue(scene.applyTableStyle(style, showsSights: true))
            XCTAssertEqual(snapshot().pngData(), data, "Showing sights restores exact pixels")
        }
        XCTAssertEqual(Set(images).count, TableStyle.allCases.count, "Every style must visibly render differently")
        XCTAssertTrue(scene.applyTableStyle(.standard))
        XCTAssertEqual(snapshot().pngData(), standard.pngData(), "Returning to standard must restore original pixels")
    }

    func testBasketNetAndCoordinatedSupportsStayIndependentOfSights() throws {
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
        XCTAssertTrue(scene.applyTableStyle(.standard))
        scene.rootNode.childNode(withName: "reference_room", recursively: false)?.isHidden = true
        scene.setCameraMode(.perspective3D, animated: false)
        let camera = SCNNode()
        camera.camera = scene.cameraNode.camera?.copy() as? SCNCamera
        scene.rootNode.addChildNode(camera)
        camera.position = SCNVector3(1.85, 0.60, 1.20)
        camera.look(at: SCNVector3(1.28, 0.60, 0.67))
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 0.19
        scene.background.contents = UIColor(white: 0.14, alpha: 1)
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene; renderer.pointOfView = camera
        var supports: [SCNMaterial] = []
        var gold: SCNMaterial?
        scene.tableNode?.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] {
                if material.name == "Gold" { gold = material }
                if material.name == "Black" { supports.append(material) }
            }
        }
        let ring = try XCTUnwrap(gold)
        XCTAssertNotNil(ring.diffuse.contents as? UIColor)
        XCTAssertFalse(supports.isEmpty)
        for material in supports {
            XCTAssertEqual(material.diffuse.contents as? UIColor, ring.diffuse.contents as? UIColor)
            XCTAssertEqual(material.metalness.contents as? NSNumber, ring.metalness.contents as? NSNumber)
        }
        func snapshot() -> UIImage {
            _ = renderer.snapshot(atTime: 0, with: CGSize(width: 900, height: 900), antialiasingMode: .multisampling4X)
            return renderer.snapshot(atTime: 0, with: CGSize(width: 900, height: 900), antialiasingMode: .multisampling4X)
        }
        for style in TableStyle.allCases {
            XCTAssertTrue(scene.applyTableStyle(style))
            var hardware: [SCNMaterial] = []
            scene.tableNode?.enumerateChildNodes { node, _ in
                hardware += (node.geometry?.materials ?? []).filter { $0.name == "Gold" || $0.name == "Black" }
            }
            XCTAssertFalse(hardware.isEmpty)
            for material in hardware {
                XCTAssertEqual(material.diffuse.contents as? UIColor, style.pocketColor ?? ring.diffuse.contents as? UIColor)
            }
            let visible = snapshot()
            let beforeAttachment = XCTAttachment(image: visible)
            beforeAttachment.name = "basket-visible-" + style.rawValue
            beforeAttachment.lifetime = .keepAlways; add(beforeAttachment)
            XCTAssertTrue(scene.applyTableStyle(style, showsSights: false))
            let hidden = snapshot()
            // Changing the Metal discard path changes a few thin-net edge samples.
            // Measured baseline MAE < 0.001 on the 0...255 scale; preserve appearance
            // within 0.01, far below one channel quantisation step on average.
            XCTAssertLessThanOrEqual(try pixelDifference(visible, hidden), 0.01,
                                     "Basket must remain visible: \(style)")
            let attachment = XCTAttachment(image: hidden)
            attachment.name = "basket-" + style.rawValue
            attachment.lifetime = .keepAlways; add(attachment)
        }
        let basket = snapshot()
        scene.tableNode?.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry else { return }
            geometry.materials = geometry.materials.map { original in
                guard original.name == "White" else { return original }
                let removed = original.copy() as! SCNMaterial
                removed.shaderModifiers = [.surface: "#pragma body\ndiscard_fragment();"]
                return removed
            }
        }
        // Negative control reproduces the former whole-White visibility error.
        let missingBasket = snapshot()
        XCTAssertGreaterThan(try pixelDifference(basket, missingBasket), 0.1,
                             "Image check must reject a missing white basket")
        let rejected = XCTAttachment(image: missingBasket)
        rejected.name = "negative-control-missing-net"; rejected.lifetime = .keepAlways; add(rejected)
    }

    private func pixelDifference(_ a: UIImage, _ b: UIImage) throws -> Double {
        func pixels(_ image: UIImage) throws -> [UInt8] {
            let source = try XCTUnwrap(image.cgImage)
            var bytes = [UInt8](repeating: 0, count: source.width * source.height * 4)
            let rendered = bytes.withUnsafeMutableBytes { raw -> Bool in
                guard let context = CGContext(data: raw.baseAddress, width: source.width, height: source.height,
                    bitsPerComponent: 8, bytesPerRow: source.width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
                return true
            }
            XCTAssertTrue(rendered)
            return bytes
        }
        let first = try pixels(a), second = try pixels(b)
        XCTAssertEqual(first.count, second.count)
        let total = zip(first, second).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        return Double(total) / Double(first.count)
    }

    func testPocketThemeRestoresAndKeepsSelectionRoles() throws {
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
        XCTAssertTrue(scene.applyTableStyle(.standard))
        let markers = scene.addPocketMarkers().compactMap { $0 as? PocketLeatherMarker }
        XCTAssertEqual(markers.count, 6)
        let standard = markers.map { $0.childNode(withName: "leather_original", recursively: false)!.geometry!.materials[0] }
        for style in TableStyle.allCases where style != .standard {
            scene.setPocketRoles(first: 0, second: 0)
            XCTAssertTrue(scene.applyTableStyle(style))
            XCTAssertEqual(markers[0].style, .bothRoles)
            for (index, marker) in markers.enumerated() {
                XCTAssertTrue(marker.childNode(withName: "leather_target", recursively: false)!.geometry!.materials[0] === marker.childNode(withName: "leather_original", recursively: false)!.geometry!.materials[0])
                XCTAssertFalse(marker.childNode(withName: "leather_original", recursively: false)!.geometry!.materials[0] === standard[index])
            }
            scene.setPocketRoles(first: nil, second: nil)
            XCTAssertTrue(markers.allSatisfy { $0.style == .original })
        }
        XCTAssertTrue(scene.applyTableStyle(.standard))
        for (index, marker) in markers.enumerated() {
            XCTAssertTrue(marker.childNode(withName: "leather_original", recursively: false)!.geometry!.materials[0] === standard[index])
        }
    }

    func testStyleSurvivesPocketExtractionAndSceneRebuild() throws {
        let scene = AngleTrainingScene()
        XCTAssertFalse(scene.applyTableStyle(.blossom))
        scene.setupScene(mobileRendering: true)
        XCTAssertEqual(scene.installedTableStyle, .blossom)
        XCTAssertEqual(scene.addPocketMarkers().count, 6)
        XCTAssertTrue(scene.applyTableStyle(.ivory))
        var changed = 0
        scene.tableNode?.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] where TableAppearance.materialNames.contains(material.name ?? "") {
                XCTAssertNotNil(material.diffuse.contents)
                changed += 1
            }
        }
        XCTAssertGreaterThan(changed, 0)
        XCTAssertTrue(scene.applyTableStyle(.standard))
        scene.tableNode?.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] where material.name == "MG_Gold" {
                XCTAssertNotNil(material.diffuse.contents as? UIColor, "Leg finish must restore after geometry replacement")
            }
        }
        XCTAssertTrue(scene.applyTableStyle(.charcoal))
        scene.setupScene(mobileRendering: true)
        XCTAssertEqual(scene.installedTableStyle, .charcoal)
    }
}

// Rail sights must divide the cushion-nose playing rectangle, independently of
// the imported rail furniture's outer dimensions or the selected camera.
extension TableAppearanceTests {
    private func railSightCenters(in table: SCNNode) throws -> [SIMD3<Float>] {
        var groups: [[SIMD3<Float>]] = []
        var failure: Error?
        table.enumerateChildNodes { node, _ in
            guard failure == nil, let geometry = node.geometry,
                  let sourceIndex = geometry.sources.firstIndex(where: { $0.semantic == .vertex }) else { return }
            let source = geometry.sources[sourceIndex]
            let channel = geometry.geometrySourceChannels?[sourceIndex].intValue ?? 0
            do {
                var indices = Set<Int>()
                for (index, element) in geometry.elements.enumerated()
                    where geometry.materials[index % geometry.materials.count].name == "White" {
                    for face in try PocketLeatherMesh.decode(element) {
                        for slot in stride(from: channel, to: face.count, by: element.indicesChannelCount) {
                            indices.insert(Int(face[slot]))
                        }
                    }
                }
                for index in indices.sorted() {
                    let offset = source.dataOffset + index * source.dataStride
                    let local = source.data.withUnsafeBytes { bytes in
                        SCNVector3(bytes.loadUnaligned(fromByteOffset: offset, as: Float.self),
                                   bytes.loadUnaligned(fromByteOffset: offset + 4, as: Float.self),
                                   bytes.loadUnaligned(fromByteOffset: offset + 8, as: Float.self))
                    }
                    let position = node.convertPosition(local, to: nil)
                    let world = SIMD3<Float>(position.x, position.y, position.z)
                    // Isolate rail inlays from the same material's cloth spots and basket nets.
                    guard world.y > BTTablePhysics.surfaceY + 0.02,
                          abs(world.x) > TablePhysics.innerLength / 2 || abs(world.z) > TablePhysics.innerWidth / 2 else { continue }
                    if let group = groups.firstIndex(where: { simd_distance($0[0], world) < 0.06 }) {
                        groups[group].append(world)
                    } else { groups.append([world]) }
                }
            } catch { failure = error }
        }
        if let failure { throw failure }
        return groups.map { points in
            var low = points[0], high = points[0]
            for point in points { low = simd_min(low, point); high = simd_max(high, point) }
            return (low + high) / 2
        }
    }

    func testRailSightsDividePlayingSurfaceInBothAssetVariantsAndCameraModes() throws {
        let preference = "modelAssetTrialUseOriginal"
        let previous = UserDefaults.standard.object(forKey: preference)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: preference) }
            else { UserDefaults.standard.removeObject(forKey: preference) }
            TableModelLoader.resetCache()
        }
        for original in [false, true] {
            UserDefaults.standard.set(original, forKey: preference)
            TableModelLoader.resetCache()
            let scene = AngleTrainingScene()
            scene.setupScene(mobileRendering: true)
            let table = try XCTUnwrap(scene.tableNode)
            for mode: AngleTrainingScene.CameraMode in [.topDown2D, .perspective3D] {
                scene.setCameraMode(mode, animated: false)
                let centers = try railSightCenters(in: table)
                XCTAssertEqual(centers.count, 18, "Both packaged assets must retain all rail sights")
                for sign: Float in [-1, 1] {
                    let long = centers.filter { $0.z * sign > TablePhysics.innerWidth / 2 && abs($0.x) < TablePhysics.innerLength / 2 }.sorted { $0.x < $1.x }
                    let short = centers.filter { $0.x * sign > TablePhysics.innerLength / 2 }.sorted { $0.z < $1.z }
                    XCTAssertEqual(long.count, 6); XCTAssertEqual(short.count, 3)
                    for (center, station) in zip(long, [-3, -2, -1, 1, 2, 3]) {
                        XCTAssertEqual(center.x, Float(station) * TablePhysics.innerLength / 8, accuracy: 0.00001)
                        XCTAssertEqual(abs(center.z), 0.72657125, accuracy: 0.00001, "Perpendicular rail inset stays unchanged")
                    }
                    for (center, station) in zip(short, [-1, 0, 1]) {
                        XCTAssertEqual(center.z, Float(station) * TablePhysics.innerWidth / 4, accuracy: 0.00001)
                        XCTAssertEqual(abs(center.x), 1.36185843, accuracy: 0.00001, "Perpendicular rail inset stays unchanged")
                    }
                }
            }
        }
    }

    func testCorrectedRailSightsRenderIn2DAnd3D() throws {
        for mobile in [false, true] {
            let scene = AngleTrainingScene()
            scene.setupScene(mobileRendering: mobile)
            XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
            scene.rootNode.childNode(withName: "reference_room", recursively: false)?.isHidden = true
            let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
            renderer.scene = scene; renderer.pointOfView = scene.cameraNode
            renderer.delegate = scene.contactOcclusion
            for (name, mode) in [("2d", AngleTrainingScene.CameraMode.topDown2D), ("3d", AngleTrainingScene.CameraMode.perspective3D)] {
                scene.setCameraMode(mode, animated: false)
                // Mode switching restores room visibility; isolate the table after switching.
                scene.rootNode.childNode(withName: "reference_room", recursively: false)?.isHidden = true
                scene.cameraNode.position = name == "2d" ? SCNVector3(0, 4, 0) : SCNVector3(2.9, 3.5, 3.5)
                scene.cameraNode.look(at: SCNVector3(0, scene.surfaceY, 0), up: name == "2d" ? SCNVector3(0, 0, -1) : SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
                scene.cameraNode.camera?.usesOrthographicProjection = true
                scene.cameraNode.camera?.orthographicScale = name == "2d" ? 1.05 : 1.3
                SCNTransaction.flush()
                let size = CGSize(width: 1600, height: 1000)
                _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
                let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
                XCTAssertEqual(image.cgImage?.width, 1600)
                let attachment = XCTAttachment(image: image)
                attachment.name = "corrected-sights-\(mobile ? "mobile" : "plain")-\(name)"
                attachment.lifetime = .keepAlways; add(attachment)
            }
        }
    }
}
