import XCTest
import SceneKit
import UIKit
import simd
@testable import QiuJi

/// V014: opt-in production-scene capture. No application defaults are changed.
@MainActor
final class FeelAimingVideoCaptureTests: XCTestCase {
    private let size = CGSize(width: 1440, height: 2280)
    private let pipRect = CGRect(x: 0, y: 0, width: 1440, height: 640)
    private let mainRect = CGRect(x: 0, y: 644, width: 1440, height: 1636)
    private let overheadFrame = CGRect(x: 36, y: 1500, width: 444, height: 620)
    private let overheadRect = CGRect(x: 36, y: 1556, width: 444, height: 564)
    private let pocketFrame = CGRect(x: 1071, y: 1420, width: 333, height: 342)
    private let pocketRect = CGRect(x: 1071, y: 1462, width: 333, height: 300)
    private let mainRenderSize = CGSize(width: 1440, height: 1916)
    private let mainCropTop: CGFloat = 280
    private let radius = AngleSceneCalculator.ballRadius
    private var centerDistance: Float { shortRail ? 0.65 : (halfRail ? 0.90 : (middlePocket ? 0.60 : 0.75)) }
    private var middlePocket: Bool { env("FEEL_LAYOUT") == "middle" }
    private var shortRail: Bool { env("FEEL_LAYOUT") == "short-half" || env("FEEL_LAYOUT") == "short-frozen" }
    private var frozenRail: Bool { env("FEEL_LAYOUT") == "frozen-rail" || env("FEEL_LAYOUT") == "short-frozen" }
    private var halfRail: Bool { env("FEEL_LAYOUT") == "half-rail" || frozenRail || shortRail }
    private var railCenterDistance: Float { frozenRail ? radius : (shortRail ? 3*radius : 2*radius) }
    private var targetNumber: Int { halfRail || middlePocket ? 1 : 8 }
    private var pocketIndex: Int { halfRail ? 0 : (middlePocket ? 4 : 3) }
    private var frameCount: Int { halfRail ? 1020 : (middlePocket ? 1920 : 1440) }

    private func env(_ key: String) -> String? {
        let values = ProcessInfo.processInfo.environment
        return values[key] ?? values["TEST_RUNNER_" + key]
    }

    private func number(_ key: String, _ fallback: Float) -> Float {
        env(key).flatMap(Float.init) ?? fallback
    }

    private func output() throws -> URL {
        guard let path = env("FEEL_AIM_DIR"), !path.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_FEEL_AIM_DIR for V014 media capture")
        }
        let result = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: result.appendingPathComponent("frames"), withIntermediateDirectories: true)
        return result
    }

    private struct Rig {
        var height: Float
        var back: Float
        var side: Float
        var fov: CGFloat
        var pocketWeight: Float = 0
    }

    private var mainRig: Rig {
        Rig(height: number("FEEL_MAIN_HEIGHT", 1.10), back: number("FEEL_MAIN_BACK", 1.65),
            side: number("FEEL_MAIN_SIDE", 0), fov: CGFloat(number("FEEL_MAIN_FOV", 44)),
            pocketWeight: number("FEEL_MAIN_POCKET_WEIGHT", 0))
    }

    private var eyeRig: Rig {
        Rig(height: number("FEEL_EYE_HEIGHT", 0.18), back: number("FEEL_EYE_BACK", 0.90),
            side: 0, fov: CGFloat(number("FEEL_EYE_FOV", 26)))
    }

    private struct Capture {
        let scene: AngleTrainingScene
        let target: SCNVector3
        let aim: SCNVector3
        let ghost: SCNVector3
        let clothY: Float
        let clothSurface: TableAssistSurface
        let mainCamera: SCNNode
        let eyeCamera: SCNNode
        let main: SCNRenderer
        let eye: SCNRenderer
        let overheadCamera: SCNNode
        let overhead: SCNRenderer
        let pocketCamera: SCNNode
        let pocketRenderer: SCNRenderer
        let dot: SCNNode
        var guides: [SCNNode] = []
    }

    private func makeCapture(targetXZ: SIMD2<Float>? = nil) throws -> Capture {
        let scene = AngleTrainingScene()
        scene.setupScene()
        scene.setupVisualizationNodes()
        XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
        XCTAssertTrue(scene.applyClothColor(.green))
        // Preserve the original table markings in both rail episodes.
        if !halfRail {
            // Suppress the USDZ's printed
            // cloth marks, preserving the rail sights and lower pocket basket nets.
            var printedMarkMaterials = 0
            scene.tableNode?.enumerateChildNodes { node, _ in
                guard let geometry = node.geometry else { return }
                geometry.materials = geometry.materials.map { original in
                    guard original.name == "White" else { return original }
                    let material = original.copy() as! SCNMaterial
                    var modifiers = material.shaderModifiers ?? [:]
                    let operation = """
                    float3 markWorld = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;
                    if (abs(markWorld.y - \(scene.surfaceY)) < 0.012 &&
                        abs(markWorld.x) < \(AngleSceneCalculator.innerLength/2) &&
                        abs(markWorld.z) < \(AngleSceneCalculator.innerWidth/2)) { discard_fragment(); }
                    """
                    let previous = modifiers[.surface] ?? "#pragma body"
                    modifiers[.surface] = previous.replacingOccurrences(of: "#pragma body", with: "#pragma body\n" + operation)
                    material.shaderModifiers = modifiers
                    printedMarkMaterials += 1
                    return material
                }
            }
            XCTAssertGreaterThan(printedMarkMaterials, 0)
        }
        XCTAssertTrue(try XCTUnwrap(scene.cueStick).applyStyle(.inkDragon))
        scene.hideAllBalls()
        scene.hideAllVisualization()
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY)[pocketIndex]
        let offset = Float(0.70 / sqrt(2.0))
        let target: SCNVector3
        if let targetXZ {
            target = SCNVector3(targetXZ.x, scene.surfaceY+radius, targetXZ.y)
        } else if shortRail {
            target = SCNVector3(-AngleSceneCalculator.innerLength/2+railCenterDistance, scene.surfaceY+radius, -6*radius)
        } else if halfRail {
            // Production head string is +X. Looking toward the foot end (-X),
            // the right long cushion is -Z. Pass the side pocket by three diameters.
            target = SCNVector3(-6*radius, scene.surfaceY+radius, -AngleSceneCalculator.innerWidth/2+railCenterDistance)
        } else if middlePocket {
            target = SCNVector3(0, scene.surfaceY+radius, -0.125)
        } else {
            target = SCNVector3(pocket.x-offset+number("FEEL_TARGET_SHORT_SHIFT",0.12), scene.surfaceY+radius, pocket.z-offset)
        }
        scene.showBall(key: "_\(targetNumber)", scenePosition: target)
        scene.setCurrentTargetNumber(targetNumber)
        scene.showBall(key: PositionPlayBall.cueKey, scenePosition: SCNVector3(0, target.y, 0))
        scene.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)))
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: scene.surfaceY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: radius)
        let surface = try TableAssistSurface.load(from: scene)
        let lift = scene.surfaceY-surface.sourceY
        let clothY = scene.mobileRendering && lift > 0.0001 && lift < radius/2 ? scene.surfaceY : surface.topY
        scene.setCameraMode(.perspective3D, animated: false)
        let mainCamera = try XCTUnwrap(scene.cameraNode)
        let eyeCamera = SCNNode()
        eyeCamera.camera = SCNCamera()
        scene.rootNode.addChildNode(eyeCamera)
        for node in [mainCamera, eyeCamera] {
            let camera = try XCTUnwrap(node.camera)
            camera.usesOrthographicProjection = false
            camera.projectionDirection = .vertical
            camera.zNear = 0.01
            camera.zFar = 100
            camera.wantsExposureAdaptation = false
        }
        func renderer(_ node: SCNNode) -> SCNRenderer {
            let result = SCNRenderer(device: nil, options: nil)
            result.scene = scene
            result.pointOfView = node
            result.autoenablesDefaultLighting = false
            result.delegate = scene.contactOcclusion
            return result
        }
        let red = SCNMaterial()
        red.lightingModel = .constant
        red.diffuse.contents = UIColor(red: 0.95, green: 0.04, blue: 0.06, alpha: 1)
        red.readsFromDepthBuffer = true
        let dotGeometry = SCNCylinder(radius: 0.006, height: 0.0003)
        dotGeometry.radialSegmentCount = 32
        dotGeometry.materials = [red]
        let dot = SCNNode(geometry: dotGeometry)
        dot.name = "feelAimCenter"
        dot.position = SCNVector3(ghost.x, clothY+0.0012, ghost.z)
        dot.castsShadow = false
        scene.rootNode.addChildNode(dot)
        let overheadCamera = SCNNode()
        overheadCamera.camera = SCNCamera()
        overheadCamera.camera?.usesOrthographicProjection = true
        overheadCamera.camera?.orthographicScale = 0.13
        overheadCamera.camera?.zNear = 0.01
        overheadCamera.camera?.zFar = 10
        scene.rootNode.addChildNode(overheadCamera)
        let pocketCamera = SCNNode()
        pocketCamera.camera = SCNCamera()
        pocketCamera.camera?.usesOrthographicProjection = true
        pocketCamera.camera?.orthographicScale = 0.20
        pocketCamera.camera?.zNear = 0.01
        pocketCamera.camera?.zFar = 10
        let potDirection = simd_normalize(SIMD2<Float>(aim.x-target.x, aim.z-target.z))
        let pocketFocus = SCNVector3(pocket.x-potDirection.x*0.07, clothY, pocket.z-potDirection.y*0.07)
        pocketCamera.position = SCNVector3(pocketFocus.x, clothY+1, pocketFocus.z)
        pocketCamera.look(at:pocketFocus, up:shortRail ? SCNVector3(0,0,-1) : SCNVector3(potDirection.x,0,potDirection.y), localFront:SCNVector3(0,0,-1))
        scene.rootNode.addChildNode(pocketCamera)
        return Capture(scene: scene, target: target, aim: aim, ghost: ghost, clothY: clothY, clothSurface: surface,
                       mainCamera: mainCamera, eyeCamera: eyeCamera, main: renderer(mainCamera), eye: renderer(eyeCamera),
                       overheadCamera: overheadCamera, overhead: renderer(overheadCamera),
                       pocketCamera:pocketCamera, pocketRenderer:renderer(pocketCamera), dot: dot)
    }

    private func position(angle: Double, target: SCNVector3, aim: SCNVector3, distance: Float, side: Float = -1) -> SCNVector3 {
        let n = simd_normalize(SIMD2<Float>(aim.x-target.x, aim.z-target.z))
        let s = SIMD2<Float>(-n.y, n.x)
        let a = Float(angle * .pi/180)
        let u = n*cos(a)+side*s*sin(a)
        let q = 2*radius
        let length = -q*cos(a)+sqrt(distance*distance-q*q*sin(a)*sin(a))
        return SCNVector3(target.x-q*n.x-length*u.x, target.y, target.z-q*n.y-length*u.y)
    }

    /// First exit from the connected measured bed footprint, not the ideal rail rectangle.
    private func clothEnd(from start: SCNVector3, toward direction: SCNVector3, capture c: Capture) -> SCNVector3 {
        guard halfRail else { return AngleSceneCalculator.rayToInnerRail(from:start, dir:direction, inset:0) }
        // Seek the forward exit from the aiming reference on the bed. The cue can
        // sit on a model tile seam; that unrelated seam must not truncate the extension.
        let origin = SIMD2<Double>(Double(c.ghost.x), Double(c.ghost.z))
        let u = simd_normalize(SIMD2<Double>(Double(direction.x), Double(direction.z)))
        func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x*b.y-a.y*b.x }
        var intervals: [(Double,Double)] = []
        for triangle in c.clothSurface.triangles {
            let sign = TableAssistSurface.signedArea(triangle) >= 0 ? 1.0 : -1.0
            var lo = 0.0, hi = Double.infinity
            for i in triangle.indices {
                let a = triangle[i], edge = triangle[(i+1)%triangle.count]-a
                let value = sign*cross(edge,origin-a), slope = sign*cross(edge,u)
                if abs(slope) < 1e-12 {
                    if value < -1e-10 { hi = -1; break }
                } else if slope > 0 { lo = max(lo,-value/slope) }
                else { hi = min(hi,-value/slope) }
            }
            if hi >= lo { intervals.append((lo,hi)) }
        }
        intervals.sort { $0.0 < $1.0 }
        var exit = 0.0
        for interval in intervals {
            if interval.0 > exit+1e-7 { break }
            exit = max(exit,interval.1)
        }
        if !(exit.isFinite && exit > 0) { print("CLOTH_EXIT_DIAGNOSTIC origin=\(origin) intervals=\(intervals.prefix(8)) triangles=\(c.clothSurface.triangles.count)") }
        XCTAssertTrue(exit.isFinite && exit > 0)
        let end = origin+u*exit
        return SCNVector3(Float(end.x),start.y,Float(end.y))
    }

    private func setState(_ angle: Double, _ c: inout Capture, distance: Float? = nil) throws -> [String: Any] {
        let d = distance ?? centerDistance
        let cue = position(angle: angle, target: c.target, aim: c.aim, distance: d, side: halfRail && !shortRail ? 1 : -1)
        if shortRail {
            XCTAssertEqual(AngleSceneCalculator.innerLength/2 + c.target.x, railCenterDistance, accuracy: 0.000001)
            XCTAssertEqual(c.target.z, -6*radius, accuracy: 0.000001)
        } else if halfRail {
            XCTAssertEqual(AngleSceneCalculator.innerWidth/2 + c.target.z, railCenterDistance, accuracy: 0.000001)
            XCTAssertEqual(c.target.x, -6*radius, accuracy: 0.000001)
        }
        try XCTUnwrap(c.scene.cueBallNode).position = cue
        let direction = simd_normalize(SIMD2<Float>(c.ghost.x-cue.x, c.ghost.z-cue.z))
        let u = SCNVector3(direction.x, 0, direction.y)
        let end = clothEnd(from: cue, toward: u, capture: c)
        let hit = AngleSceneCalculator.aimRayTargetEntry(from: cue, toward: end, target: c.target)
        c.guides.forEach { $0.removeFromParentNode() }
        c.guides = []
        let lineWidth = number("FEEL_LINE_WIDTH", 0.003)
        c.guides.append(c.scene.addLine(from: cue, to: hit ?? end, color: .white,
                                       radius: lineWidth/2, placement: .table, layer: .aiming))
        if let hit {
            c.guides.append(c.scene.addDashedLine(from: hit, to: end, color: .white,
                                                 radius: lineWidth/2, dash: 0.018, gap: 0.012, placement: .table, layer: .aiming))
        }
        if halfRail, hit != nil {
            let tail = min(Float(0.018), AngleSceneCalculator.horizontalDistance(hit!, end))
            let tailStart = SCNVector3(end.x-u.x*tail, end.y, end.z-u.z*tail)
            c.guides.append(c.scene.addLine(from:tailStart, to:end, color:.white,
                                          radius:lineWidth/2, placement:.table, layer:.aiming))
        }
        c.guides.append(c.scene.addDashedLine(from: c.target, to: c.aim, color: .black,
                                             radius: lineWidth/2, dash: 0.018, gap: 0.012, placement: .table, layer: .aiming))
        c.scene.updateCueStick(cueBallPosition: cue, aimDirection: u)
        let measured = AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: c.target, pocket: c.aim)
        XCTAssertEqual(measured, abs(angle), accuracy: 0.01)
        XCTAssertEqual(AngleSceneCalculator.horizontalDistance(cue, c.target), d, accuracy: 0.00001)
        XCTAssertLessThan(abs(cue.x)+radius, AngleSceneCalculator.innerLength/2)
        XCTAssertLessThan(abs(cue.z)+radius, AngleSceneCalculator.innerWidth/2)
        XCTAssertFalse(try XCTUnwrap(c.scene.cueStick).rootNode.isHidden)
        XCTAssertTrue(c.scene.ghostBallNode?.isHidden == true)
        XCTAssertTrue(c.scene.pocketLineNode?.isHidden == true)
        XCTAssertTrue(c.scene.angleArcNode?.isHidden == true)
        XCTAssertNil(c.scene.rootNode.childNode(withName: "feelAimColumn", recursively: true))
        XCTAssertNil(c.dot.physicsBody)
        if abs(angle) < 29.9 { XCTAssertNotNil(hit) }
        if abs(angle) > 30.1 { XCTAssertNil(hit) }
        SCNTransaction.flush()
        return ["layout": shortRail ? (frozenRail ? "short-frozen" : "short-half") : frozenRail ? "frozen-rail" : (halfRail ? "half-rail" : (middlePocket ? "middle" : "corner")), "pocketIndex": pocketIndex,
                "targetNumber": targetNumber, "railPointMarked": halfRail,
                "angle": angle, "measuredAngle": measured, "distance": Double(AngleSceneCalculator.horizontalDistance(cue, c.target)),
                "cue": xyz(cue), "target": xyz(c.target), "ghost": xyz(c.ghost), "aim": xyz(c.aim),
                "lineEnd": xyz(end), "lineEntry": hit.map(xyz) as Any? ?? NSNull(),
                "clothY": c.clothY, "guideNodes": c.guides.count, "aimLineColor": "white", "potLineColor": "black", "markerColor": "red", "markerShape": "floor-dot", "dotDiameterMeters": 0.012]
    }

    private func xyz(_ p: SCNVector3) -> [Float] { [p.x, p.y, p.z] }

    private func camera(_ node: SCNNode, rig: Rig, capture c: Capture, eye: Bool) throws {
        let cue = try XCTUnwrap(c.scene.cueBallNode).position
        let u = simd_normalize(SIMD2<Float>(c.ghost.x-cue.x, c.ghost.z-cue.z))
        let side = SIMD2<Float>(-u.y, u.x)
        node.position = SCNVector3(cue.x-rig.back*u.x+rig.side*side.x, c.scene.surfaceY+rig.height,
                                  cue.z-rig.back*u.y+rig.side*side.y)
        var focus = eye ? SCNVector3((cue.x+c.ghost.x)/2, c.target.y, (cue.z+c.ghost.z)/2)
            : SCNVector3(cue.x, c.clothY, cue.z)
        if !eye {
            focus.x += rig.pocketWeight*(c.aim.x-c.ghost.x)
            focus.z += rig.pocketWeight*(c.aim.z-c.ghost.z)
        }
        node.camera?.fieldOfView = rig.fov
        if middlePocket {
            // Analytic yaw/pitch avoids SCNNode.look(at:) precision loss near a cardinal axis.
            let forward = simd_normalize(SIMD3<Float>(focus.x-node.position.x, focus.y-node.position.y, focus.z-node.position.z))
            let yaw = atan2(-forward.x, -forward.z)
            let pitch = asin(forward.y)
            node.simdOrientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0,1,0))
                * simd_quatf(angle: pitch, axis: SIMD3<Float>(1,0,0))
        } else {
            node.look(at: focus, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,-1))
        }
        if eye || (rig.side == 0 && rig.pocketWeight == 0) {
            let forward = node.simdOrientation.act(SIMD3<Float>(0,0,-1))
            XCTAssertEqual(simd_dot(simd_normalize(SIMD2<Float>(forward.x,forward.z)),u), 1, accuracy: 0.00001)
        }
        XCTAssertEqual(node.position.y-c.scene.surfaceY, rig.height, accuracy: 0.00001)
        SCNTransaction.flush()
    }

    private func projected(_ renderer: SCNRenderer, camera: SCNNode, size: CGSize, capture c: Capture, cropTop: Float = 0) throws -> [String: Any] {
        let cue = try XCTUnwrap(c.scene.cueBallNode).position
        let end = clothEnd(from: cue, toward: SCNVector3(c.ghost.x-cue.x, 0, c.ghost.z-cue.z), capture: c)
        var points: [String: [Float]] = [:]
        for (name, point) in [("cue",cue),("target",c.target),("ghost",c.ghost),("pocket",c.aim),("lineEnd",end),
                              ("dot",c.dot.position)] {
            let p = renderer.projectPoint(point)
            points[name] = [p.x, Float(size.height)-p.y-cropTop, p.z]
        }
        let pocketBounds = (0..<16).flatMap { i -> [[Float]] in
            let a = Float(i) * .pi / 8
            return [c.clothY, c.clothY + 0.06].map { y in
                let p = renderer.projectPoint(SCNVector3(c.aim.x+0.07*cos(a), y, c.aim.z+0.07*sin(a)))
                return [p.x, Float(size.height)-p.y-cropTop, p.z]
            }
        }
        let right = camera.simdOrientation.act(SIMD3<Float>(1,0,0))
        let a = renderer.projectPoint(SCNVector3(c.target.x-right.x*radius,c.target.y-right.y*radius,c.target.z-right.z*radius))
        let b = renderer.projectPoint(SCNVector3(c.target.x+right.x*radius,c.target.y+right.y*radius,c.target.z+right.z*radius))
        let floorStart=SCNVector3(cue.x,c.clothY,cue.z)
        let floorEnd=SCNVector3(end.x,c.clothY,end.z)
        let floorTarget=SCNVector3(c.target.x,c.clothY,c.target.z)
        let floorAim=SCNVector3(c.aim.x,c.clothY,c.aim.z)
        let floorLines=[[floorStart,floorEnd],[floorTarget,floorAim]].map { line in
            line.map { point in let p=renderer.projectPoint(point);return [p.x,Float(size.height)-p.y-cropTop] }
        }
        let nominalEnd = AngleSceneCalculator.rayToInnerRail(from:cue, dir:SCNVector3(c.ghost.x-cue.x,0,c.ghost.z-cue.z), inset:0)
        let marker = renderer.projectPoint(SCNVector3(nominalEnd.x,c.clothY,nominalEnd.z))
        let m = camera.simdWorldTransform
        return ["railMarker":[marker.x,Float(size.height)-marker.y-cropTop], "points": points, "pocketBounds":pocketBounds, "floorLines":floorLines, "ballDiameterPixels": hypotf(b.x-a.x,b.y-a.y), "position": xyz(camera.position),
                "fov": camera.camera!.fieldOfView, "matrix": (0..<4).flatMap { i in (0..<4).map { j in m[i][j] } }]
    }

    /// Screen-space labels follow the same projected floor lines in every view.
    /// Plain text and thin leaders follow the existing V009 instructional style.
    private func labels(_ renderer: SCNRenderer, size: CGSize, capture c: Capture, small: Bool = false) -> [[String: Any]] {
        let cue = c.scene.cueBallNode!.position
        let n = simd_normalize(SIMD2<Float>(c.aim.x-c.target.x,c.aim.z-c.target.z))
        let u = simd_normalize(SIMD2<Float>(c.ghost.x-cue.x,c.ghost.z-cue.z))
        let aimPoint = small
            ? SCNVector3(c.ghost.x-u.x*0.075,c.clothY,c.ghost.z-u.y*0.075)
            : SCNVector3(cue.x*0.55+c.ghost.x*0.45,c.clothY,cue.z*0.55+c.ghost.z*0.45)
        let potPoint = SCNVector3(c.target.x+n.x*(small ? 0.055 : 0.20),c.clothY,c.target.z+n.y*(small ? 0.055 : 0.20))
        return [("瞄准线",aimPoint,false),("进球线",potPoint,true)].map { title, point, pot in
            let p = renderer.projectPoint(point)
            let anchor = CGPoint(x:CGFloat(p.x),y:size.height-CGFloat(p.y))
            let fontSize: CGFloat = small ? 30 : (size.width > 1000 ? 36 : 32)
            let font = UIFont.systemFont(ofSize:fontSize,weight:.semibold)
            let textSize = (title as NSString).size(withAttributes:[.font:font])
            let next = pot ? SCNVector3(point.x+n.x*0.05,c.clothY,point.z+n.y*0.05)
                : SCNVector3(point.x+u.x*0.05,c.clothY,point.z+u.y*0.05)
            let q=renderer.projectPoint(next)
            let dx=CGFloat(q.x)-anchor.x, dy=size.height-CGFloat(q.y)-anchor.y
            let length=hypot(dx,dy)
            // Right side of each directed floor line; the small aiming label
            // sits left in both insets, keeping the two labels separated.
            let sign: CGFloat = (size.width < 1000 && !pot) || (halfRail && !shortRail && pot) || (middlePocket && pot && dx < 0) ? -1 : 1
            let nx = -dy/length*sign, ny = dx/length*sign
            let gap: CGFloat = small ? 55 : (size.width > 1000 ? 90 : 65)
            let clearance=abs(nx)*textSize.width/2+abs(ny)*textSize.height/2+gap
            let x=min(size.width-textSize.width-12,max(12,anchor.x+nx*clearance-textSize.width/2))
            let y=min(size.height-textSize.height-12,max(12,anchor.y+ny*clearance-textSize.height/2))
            // Closest point on the text bounds gives a long, clean side leader.
            let ex=min(x+textSize.width,max(x,anchor.x))
            let ey=min(y+textSize.height,max(y,anchor.y))
            let leaderLength=hypot(ex-anchor.x,ey-anchor.y)
            let endpoint=CGPoint(x:ex-(ex-anchor.x)/leaderLength*6,y:ey-(ey-anchor.y)/leaderLength*6)
            let opacity: CGFloat = middlePocket && pot ? min(1, CGFloat(AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: c.target, pocket: c.aim)) / 1.5) : 1
            return ["text":title,"pot":pot,"opacity":opacity,"fontSize":fontSize,"anchor":[anchor.x,anchor.y],
                    "rect":[x,y,textSize.width,textSize.height],"leaderEnd":[endpoint.x,endpoint.y],
                    "leaderLengthPixels":leaderLength-6]
        }
    }

    private func drawLabels(_ values: [[String:Any]], offset: CGPoint, context: CGContext) {
        for value in values {
            context.saveGState()
            context.setAlpha(value["opacity"] as? CGFloat ?? 1)
            let r=value["rect"] as! [CGFloat], a=value["anchor"] as! [CGFloat]
            let rect=CGRect(x:r[0]+offset.x,y:r[1]+offset.y,width:r[2],height:r[3])
            let pot=value["pot"] as! Bool
            let color: UIColor = pot ? .black : .white
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1.5)
            context.move(to:CGPoint(x:a[0]+offset.x,y:a[1]+offset.y))
            let end=value["leaderEnd"] as! [CGFloat]
            context.addLine(to:CGPoint(x:end[0]+offset.x,y:end[1]+offset.y))
            context.strokePath()
            let shadow=NSShadow()
            shadow.shadowColor=UIColor(white:pot ? 1 : 0,alpha:0.45)
            shadow.shadowBlurRadius=2
            (value["text"] as! NSString).draw(in:rect,withAttributes:[.font:UIFont.systemFont(ofSize:value["fontSize"] as! CGFloat,weight:.semibold),.foregroundColor:color,.shadow:shadow])
            context.restoreGState()
        }
    }

    private func metricValues(_ c: Capture) -> [String] {
        let cue = c.scene.cueBallNode!.position
        let angle = AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: c.target, pocket: c.aim)
        let thinness = sin(angle * .pi / 180)
        let displacement = Double(2 * radius * 1000) * thinness
        func fraction(_ eighths: Int) -> String {
            if eighths == 0 { return "0" }
            if eighths == 8 { return "1" }
            var n = eighths, d = 8
            while n % 2 == 0 && d % 2 == 0 { n /= 2; d /= 2 }
            return "\(n)/\(d)"
        }
        let exact = Int((thinness * 8).rounded())
        let ratio: String
        if abs(thinness - Double(exact) / 8) < 0.00001 {
            ratio = fraction(exact)
        } else if thinness < 0.125 {
            ratio = "＜1/8"
        } else {
            let lower = Int(floor(thinness * 8))
            ratio = "\(fraction(lower))–\(fraction(lower + 1))"
        }
        return [String(format: "%.1f°", angle), String(format: "%.1f mm", displacement), ratio + " 球"]
    }

    private func drawMetrics(_ values: [String]) {
        let shadow = NSShadow()
        shadow.shadowColor = UIColor(white: 0, alpha: 0.7)
        shadow.shadowOffset = CGSize(width: 0, height: 1)
        shadow.shadowBlurRadius = 3
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 40, weight: .medium),
            .foregroundColor: UIColor.white, .shadow: shadow
        ]
        for (row, label) in ["角度", "横移", "薄度"].enumerated() {
            (label as NSString).draw(at: CGPoint(x: 56, y: 1200 + row * 62), withAttributes: attributes)
            (values[row] as NSString).draw(at: CGPoint(x: 172, y: 1200 + row * 62), withAttributes: attributes)
        }
    }

    private func viewBadge(_ text: String, rect: CGRect, gold: UIColor, context: CGContext) {
        let border=UIBezierPath(roundedRect:rect,cornerRadius:14)
        UIColor.black.withAlphaComponent(0.76).setFill();border.fill()
        gold.setStroke();border.lineWidth=2;border.stroke()
        let attributes:[NSAttributedString.Key:Any]=[.font:UIFont.systemFont(ofSize:34,weight:.semibold),.foregroundColor:UIColor.white]
        let textSize=(text as NSString).size(withAttributes:attributes)
        (text as NSString).draw(at:CGPoint(x:rect.midX-textSize.width/2,y:rect.midY-textSize.height/2),withAttributes:attributes)
    }

    /// A screen-space teaching marker anchored to the existing floor-line endpoint.
    /// Keep its true projection; clipping must not relocate it to a viewport edge.
    private func drawRailPoint(_ projection: [String: Any], in viewport: CGRect, context: CGContext) {
        guard halfRail else { return }
        let point = projection["railMarker"] as! [Float]
        let center = CGPoint(x: viewport.minX + CGFloat(point[0]), y: viewport.minY + CGFloat(point[1]))
        guard viewport.insetBy(dx: 9, dy: 9).contains(center) else { return }
        context.saveGState()
        context.clip(to: viewport)
        context.setFillColor(UIColor.white.cgColor)
        context.setStrokeColor(UIColor(white: 0.12, alpha: 1).cgColor)
        context.setLineWidth(3)
        context.addEllipse(in: CGRect(x: center.x-7, y: center.y-7, width: 14, height: 14))
        context.drawPath(using: .fillStroke)
        context.restoreGState()
    }

    private func render(_ c: Capture, time: Double, main: Rig? = nil, eye: Rig? = nil) throws -> (UIImage, [String: Any]) {
        try camera(c.mainCamera, rig: main ?? mainRig, capture: c, eye: false)
        try camera(c.eyeCamera, rig: eye ?? eyeRig, capture: c, eye: true)
        let cue=c.scene.cueBallNode!.position
        let u=simd_normalize(SIMD2<Float>(c.ghost.x-cue.x,c.ghost.z-cue.z))
        let center=SCNVector3((c.target.x+c.ghost.x)/2,c.clothY,(c.target.z+c.ghost.z)/2)
        c.overheadCamera.position=SCNVector3(center.x,c.clothY+1,center.z)
        c.overheadCamera.look(at:center,up:SCNVector3(u.x,0,u.y),localFront:SCNVector3(0,0,-1))
        SCNTransaction.flush()
        let shot=c.main.snapshot(atTime:time,with:mainRenderSize,antialiasingMode:.multisampling4X)
        let mainProjection=try projected(c.main,camera:c.mainCamera,size:mainRenderSize,capture:c,cropTop:Float(mainCropTop))
        let detail=c.eye.snapshot(atTime:time,with:pipRect.size,antialiasingMode:.multisampling4X)
        let eyeProjection=try projected(c.eye,camera:c.eyeCamera,size:pipRect.size,capture:c)
        let overhead=c.overhead.snapshot(atTime:time,with:overheadRect.size,antialiasingMode:.multisampling4X)
        let overheadProjection=try projected(c.overhead,camera:c.overheadCamera,size:overheadRect.size,capture:c)
        let pocketImage = halfRail ? c.pocketRenderer.snapshot(atTime:time,with:pocketRect.size,antialiasingMode:.multisampling4X) : nil
        var pocketProjection: [String:Any] = [:]
        if halfRail {
            // Overlay is the world aim point projected onto the cloth plane, not
            // the pocket leather center or a screen-position approximation.
            let p = c.pocketRenderer.projectPoint(SCNVector3(c.aim.x,c.clothY,c.aim.z))
            let marker = CGPoint(x:CGFloat(p.x),y:pocketRect.height-CGFloat(p.y))
            XCTAssertGreaterThan(marker.x, 16); XCTAssertLessThan(marker.x, pocketRect.width-16)
            XCTAssertGreaterThan(marker.y, 16); XCTAssertLessThan(marker.y, pocketRect.height-16)
            pocketProjection = ["aimPointLocal":[marker.x,marker.y], "aimPointWorld":[c.aim.x,c.clothY,c.aim.z],
                                "position":xyz(c.pocketCamera.position),"orthographicScale":0.20,
                                "orientation":"screen up follows target-to-pocket direction"]
        }
        let mainLabels=labels(c.main,size:mainRenderSize,capture:c).map { original -> [String:Any] in
            var value=original
            for key in ["rect","anchor","leaderEnd"] {
                var coordinates=value[key] as! [CGFloat]
                coordinates[1] -= mainCropTop
                value[key]=coordinates
            }
            return value
        }
        // The top and overhead views retain all world guides/markers but no
        // line names or annotation leaders. View badges are separate chrome.
        let emptyLabels:[[String:Any]]=[]
        let metrics = middlePocket || halfRail ? metricValues(c) : []
        let gold=UIColor(red:0.87,green:0.73,blue:0.42,alpha:1)
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let image=UIGraphicsImageRenderer(size:size,format:format).image { ctx in
            UIColor(white:0.055,alpha:1).setFill();ctx.fill(CGRect(origin:.zero,size:size))
            ctx.cgContext.saveGState()
            ctx.cgContext.clip(to:mainRect)
            shot.draw(in:CGRect(x:0,y:mainRect.minY-mainCropTop,width:mainRenderSize.width,height:mainRenderSize.height))
            ctx.cgContext.restoreGState()
            drawLabels(mainLabels,offset:mainRect.origin,context:ctx.cgContext)
            detail.draw(in:pipRect)
            gold.setFill();ctx.fill(CGRect(x:0,y:640,width:1440,height:4))
            // A narrow header above the overhead content never covers its guides.
            ctx.cgContext.saveGState()
            UIBezierPath(roundedRect:overheadFrame,cornerRadius:20).addClip()
            UIColor(white:0.045,alpha:1).setFill();ctx.fill(overheadFrame)
            overhead.draw(in:overheadRect)
            drawRailPoint(overheadProjection, in:overheadRect, context:ctx.cgContext)
            let smallAttributes:[NSAttributedString.Key:Any]=[.font:UIFont.systemFont(ofSize:30,weight:.semibold),.foregroundColor:UIColor.white]
            ("局部俯视" as NSString).draw(at:CGPoint(x:overheadFrame.minX+18,y:overheadFrame.minY+10),withAttributes:smallAttributes)
            ctx.cgContext.restoreGState()
            UIColor.white.withAlphaComponent(0.9).setStroke()
            let overheadBorder=UIBezierPath(roundedRect:overheadFrame,cornerRadius:20);overheadBorder.lineWidth=2;overheadBorder.stroke()
            viewBadge("第一人称",rect:CGRect(x:32,y:24,width:200,height:62),gold:gold,context:ctx.cgContext)
            viewBadge("第三人称",rect:CGRect(x:32,y:mainRect.minY+24,width:200,height:62),gold:gold,context:ctx.cgContext)
            if middlePocket || halfRail { drawMetrics(metrics) }
            if let pocketImage {
                ctx.cgContext.saveGState()
                UIBezierPath(roundedRect:pocketFrame,cornerRadius:20).addClip()
                UIColor(white:0.045,alpha:1).setFill();ctx.fill(pocketFrame)
                pocketImage.draw(in:pocketRect)
                ("袋口瞄准点" as NSString).draw(at:CGPoint(x:pocketFrame.minX+13.5,y:pocketFrame.minY+7.5),withAttributes:[.font:UIFont.systemFont(ofSize:22.5,weight:.semibold),.foregroundColor:UIColor.white])
                let point = pocketProjection["aimPointLocal"] as! [CGFloat]
                let dot = CGPoint(x:pocketRect.minX+point[0],y:pocketRect.minY+point[1])
                ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
                ctx.cgContext.setFillColor(UIColor(red:0.95,green:0.04,blue:0.06,alpha:1).cgColor)
                ctx.cgContext.setLineWidth(2)
                ctx.cgContext.addEllipse(in:CGRect(x:dot.x-4.5,y:dot.y-4.5,width:9,height:9))
                ctx.cgContext.drawPath(using:.fillStroke)
                ctx.cgContext.restoreGState()
                UIColor.white.withAlphaComponent(0.9).setStroke()
                let border=UIBezierPath(roundedRect:pocketFrame,cornerRadius:20);border.lineWidth=2;border.stroke()
            }

        }
        func box(_ rect:CGRect)->[CGFloat] { [rect.minX,rect.minY,rect.width,rect.height] }
        return (image,["metricValues":metrics,"main":mainProjection,"eye":eyeProjection,"overhead":overheadProjection,
                       "pocketInset":pocketProjection,"pocketFrame":box(pocketFrame),"pocketRect":box(pocketRect),
                       "mainRect":box(mainRect),"pipRect":box(pipRect),"overheadRect":box(overheadRect),
                       "overheadFrame":box(overheadFrame),"mainCropTop":mainCropTop,"outputSize":[size.width,size.height],"focus":["main":"cue projected to cloth","eye":"0.5*C+0.5*G"],
                       "labels":["main":mainLabels,"eye":emptyLabels,"overhead":emptyLabels]])
    }

    private func write(_ value: Any, _ url: URL) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted,.sortedKeys]).write(to: url)
    }

    func testGeometry() throws {
        let directory = try output()
        var c = try makeCapture()
        var records: [[String: Any]] = []
        XCTAssertTrue(AngleSceneCalculator.isPocketReachable(target:c.target,pocketIndex:pocketIndex,surfaceY:c.scene.surfaceY))
        let samples = halfRail ? 750 : (middlePocket ? 1500 : 750)
        for sample in 0...samples {
            let degrees = Double(sample)/10 - (middlePocket ? 75 : 0)
            let record = try setState(degrees, &c)
            records.append(record)
        }
        try write(records, directory.appendingPathComponent("geometry.json"))
        print("FEEL_AIM geometry \(samples+1) samples; fixed center distance \(centerDistance)m")
    }

    func testCameraCandidates() async throws {
        let directory = try output()
        var c = try makeCapture()
        var records: [[String: Any]] = []
        var variants: [(String,Rig,Rig)] = [("baseline",mainRig,eyeRig)]
        variants.append(("previous-eye",mainRig,Rig(height:0.20,back:0.45,side:0,fov:40)))
        variants.append(("lower-eye",mainRig,Rig(height:0.20,back:0.75,side:0,fov:40)))
        for (name,main,eye) in variants {
            for angle in [0.0,30,75] {
                try autoreleasepool {
                    var record = try setState(angle, &c)
                    _ = try render(c,time:0,main:main,eye:eye)
                    let (image,projection) = try render(c,time:0,main:main,eye:eye)
                    let filename="\(name)-\(Int(angle)).png"
                    try XCTUnwrap(image.pngData()).write(to:directory.appendingPathComponent("frames/"+filename))
                    record["file"]=filename;record["projection"]=projection
                    records.append(record)
                }
                await Task.yield()
            }
        }
        try write(records,directory.appendingPathComponent("candidates.json"))
    }

    func testKeyframes() async throws {
        let directory = try output()
        var c = try makeCapture()
        var records: [[String: Any]] = []
        let angles: [Double] = halfRail ? [0,15,29.9,30,30.1,45,60,75] : (middlePocket ? [-75,-60,-45,-30.1,-30,-29.9,-15,0,15,29.9,30,30.1,45,60,75] : [0,15,29.9,30,30.1,45,60,75])
        for angle in angles {
            try autoreleasepool {
                var record = try setState(angle, &c)
                _ = try render(c,time:0)
                let (image,projection) = try render(c,time:0)
                let filename=String(format:"angle-%05.1f.png",angle)
                try XCTUnwrap(image.pngData()).write(to:directory.appendingPathComponent("frames/"+filename))
                record["file"]=filename;record["projection"]=projection
                records.append(record)
            }
            await Task.yield()
        }
        try write(records,directory.appendingPathComponent("keyframes.json"))
    }

    private func angle(at time: Double) -> Double {
        if halfRail { return max(0, min(75, (time-1)*5.0)) }
        if middlePocket { return max(-75, min(75, -75 + (time-1)*5.0)) }
        let hold = 2.0
        if time <= hold { return 0 }
        if time <= hold+20 { return (time-hold)*3.75 }
        return 75
    }

    func testExport() async throws {
        let directory = try output()
        var c = try makeCapture()
        _ = try setState(angle(at:0),&c)
        _ = try render(c,time:0)
        _ = try render(c,time:0)
        let writer = try VideoWriter(url:directory.appendingPathComponent("feel-aiming-v014-native.mp4"),size:size,fps:60,averageBitRate:32_000_000)
        var records:[[String:Any]]=[]
        for frame in 0..<frameCount {
            try autoreleasepool {
                let time=Double(frame)/60
                var record=try setState(angle(at:time),&c)
                let (image,projection)=try render(c,time:time)
                record["frame"]=frame;record["time"]=time;record["projection"]=projection
                records.append(record)
                try writer.append(XCTUnwrap(image.cgImage))
            }
            if frame % 60 == 0 { print("FEEL_AIM export \(frame)/\(frameCount)") }
            try await Task.sleep(nanoseconds:1_000_000)
        }
        try await writer.finish()
        try write(records,directory.appendingPathComponent("frames.json"))
    }
}

// AB point construction: opt-in keyframes using the original corner-shot scene.
extension FeelAimingVideoCaptureTests {
    func testABPointKeyframes() async throws {
        guard let path = env("AB_POINT_DIR") else { throw XCTSkip("Set TEST_RUNNER_AB_POINT_DIR") }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var c = try makeCapture()
        c.scene.installReferenceRoom(style: .walnut)
        XCTAssertEqual(c.scene.installedReferenceRoomStyle, .walnut)
        if let asset = env("AB_LASER_ASSET") {
            let imported = try SCNScene(url:URL(fileURLWithPath:asset),options:nil)
            let mount = SCNNode(); mount.name = "videoLaserMount"
            for node in imported.rootNode.childNodes { mount.addChildNode(node.clone()) }
            mount.scale = SCNVector3(1.3,1.3,1.3)
            mount.position = SCNVector3(0,0,0.65)
            try XCTUnwrap(c.scene.cueStick).rootNode.addChildNode(mount)
            print("AB_LASER bounds \(mount.boundingBox)")
        }
        var records: [[String: Any]] = []
        let canvas = CGSize(width: 1440, height: 1660)
        let cyan = UIColor(red: 0.1, green: 0.95, blue: 0.95, alpha: 1)
        let yellow = UIColor(red: 1, green: 0.88, blue: 0.05, alpha: 1)
        let ghostColor = UIColor(red: 0.72, green: 0.10, blue: 0.12, alpha: 1)
        let centerColor = TrajectoryStyle.aimPointColor
        let pink = UIColor(red: 1, green: 0.35, blue: 0.63, alpha: 1)
        let exporting = env("AB_POINT_VIDEO") == "1"
        let writer = exporting ? try VideoWriter(url:directory.appendingPathComponent("point-to-point-v020-r12.mp4"),size:canvas,fps:60,averageBitRate:32_000_000) : nil
        let angles: [Double]
        if exporting {
            angles = (0..<1080).map { frame -> Double in
                let elapsed = Double(frame) / 60.0 - 1.0
                return min(75.0, max(0.0, elapsed * (75.0 / 16.0)))
            }
        } else { angles = [0,15,30,45,60,75] }
        for (frame, angle) in angles.enumerated() {
            try autoreleasepool {
                _ = try setState(angle, &c)
                c.guides.forEach { $0.removeFromParentNode() }; c.guides = []
                c.dot.isHidden = true
                let cue = try XCTUnwrap(c.scene.cueBallNode).position
                func v(_ p: SCNVector3) -> SIMD2<Double> { SIMD2(Double(p.x), Double(p.z)) }
                let C = v(cue), T = v(c.target)
                let P = v(AngleSceneCalculator.pocketPositions(surfaceY: c.scene.surfaceY)[3])
                let r = Double(radius), n = simd_normalize(P-T), m = simd_normalize(P-C)
                let A = C+r*m, B = T-r*n, G = T-2*r*n
                let u = simd_normalize(B-A), H = C+simd_dot(G-C,u)*u
                let d = simd_length(G-H)
                let measuredAngle = AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: c.target, pocket: c.aim)
                func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x*b.y-a.y*b.x }
                XCTAssertEqual(simd_length(A-C), r, accuracy: 1e-10)
                XCTAssertEqual(simd_length(B-T), r, accuracy: 1e-10)
                XCTAssertEqual(simd_dot(G-H,u), 0, accuracy: 1e-10)
                XCTAssertEqual(cross(H-C,u), 0, accuracy: 1e-10)
                XCTAssertEqual(d, abs(cross(G-C,u)), accuracy: 1e-10)
                XCTAssertEqual(simd_length(G-T), 2*r, accuracy: 1e-10)
                if angle == 0 { XCTAssertLessThan(d, 1e-7) }
                else {
                    // The six keyframes start at 15 degrees; continuous frames also include near-zero cuts.
                    XCTAssertGreaterThan(d, 0)
                    if angle >= 15 { XCTAssertGreaterThan(d, 0.001) }
                }
                func world(_ p: SIMD2<Double>) -> SCNVector3 { SCNVector3(Float(p.x), cue.y, Float(p.y)) }
                func line(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ color: UIColor, dashed: Bool = false) {
                    let node: SCNNode
                    if dashed { node = c.scene.addDashedLine(from: world(a), to: world(b), color: color, radius: 0.0011, dash: 0.016, gap: 0.012, placement: .table, layer: .aiming) }
                    else { node = c.scene.addLine(from: world(a), to: world(b), color: color, radius: 0.0012, placement: .table, layer: .aiming) }
                    c.guides.append(node)
                }
                let end = AngleSceneCalculator.rayToInnerRail(from: cue, dir: SCNVector3(Float(u.x),0,Float(u.y)), inset:0)
                line(C,v(end),.white)
                // Pocket reference uses the cue-center projection on cloth; A remains on the actual sphere.
                let pocketReference = c.scene.addDashedLine(from:world(C),to:world(P),color:yellow,radius:0.0011,dash:0.016,gap:0.012,placement:.table,layer:.aiming)
                c.guides.append(pocketReference)
                XCTAssertEqual(cross(A-C,P-C),0,accuracy:1e-10)
                line(B,P,.black,dashed:true)
                line(A,B,cyan)
                for (p,color) in [(A,UIColor.red),(B,cyan)] {
                    let material=SCNMaterial(); material.lightingModel = .constant; material.diffuse.contents=color
                    let sphere=SCNSphere(radius:0.0035);sphere.materials=[material]
                    let marker=SCNNode(geometry:sphere);marker.position=world(p);marker.castsShadow=false
                    c.scene.rootNode.addChildNode(marker);c.guides.append(marker)
                }
                c.scene.updateCueStick(cueBallPosition:cue,aimDirection:SCNVector3(Float(u.x),0,Float(u.y)))
                let mainSize = canvas
                let mainHeight = number("AB_MAIN_HEIGHT", 0.65)
                let forwardFocus = number("AB_MAIN_FOCUS", 0.40)
                let back: Float = 1.65
                c.mainCamera.position = SCNVector3(cue.x-back*Float(u.x), c.scene.surfaceY+mainHeight, cue.z-back*Float(u.y))
                c.mainCamera.camera?.fieldOfView = 44
                c.mainCamera.look(at: SCNVector3(cue.x+forwardFocus*Float(u.x), c.clothY, cue.z+forwardFocus*Float(u.y)), up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,-1))
                let ghostRing = try XCTUnwrap(c.scene.ghostBallNode)
                ghostRing.position = SCNVector3(Float(G.x),c.clothY+radius,Float(G.y))
                ghostRing.isHidden = false
                ghostRing.childNode(withName:"ghostAimDot",recursively:true)?.isHidden = true
                for segment in ghostRing.childNodes where segment.name != "ghostAimDot" {
                    segment.geometry?.materials.forEach { $0.diffuse.contents = ghostColor }
                }
                SCNTransaction.flush()
                _ = c.main.snapshot(atTime:0,with:mainSize,antialiasingMode:.multisampling4X)
                let sceneImage=c.main.snapshot(atTime:0,with:mainSize,antialiasingMode:.multisampling4X)
                func projectedPoint(_ p: SIMD2<Double>, floor: Bool = false) -> CGPoint {
                    let point = floor ? SCNVector3(Float(p.x),c.clothY,Float(p.y)) : world(p)
                    let q=c.main.projectPoint(point);return CGPoint(x:CGFloat(q.x),y:mainSize.height-CGFloat(q.y))
                }
                // Same scene, real object ball and the production ghost ring (video convention).
                let insetRect = CGRect(x:42,y:640,width:400,height:280)
                let detailSize = CGSize(width:800,height:560)
                let zoom: Double = 2100
                let detailCenter = (G+T)/2-u*(15/zoom)
                let focus = SCNVector3(Float(detailCenter.x),c.clothY+radius/2,Float(detailCenter.y))
                c.overheadCamera.camera?.projectionDirection = .vertical
                c.overheadCamera.camera?.orthographicScale = Double(insetRect.height)/(2*zoom)
                let insetPitch: Float = 35 * .pi / 180
                c.overheadCamera.position = SCNVector3(focus.x-0.65*cos(insetPitch)*Float(u.x),focus.y+0.65*sin(insetPitch),focus.z-0.65*cos(insetPitch)*Float(u.y))
                c.overheadCamera.look(at:focus,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
                let ghostAxis = c.scene.addDashedLine(from:world(G),to:world(B),color:.black,radius:0.00065,dash:0.01,gap:0.007,placement:.table,layer:.aiming)
                SCNTransaction.flush()
                _ = c.overhead.snapshot(atTime:0,with:detailSize,antialiasingMode:.multisampling4X)
                let detailImage = c.overhead.snapshot(atTime:0,with:detailSize,antialiasingMode:.multisampling4X)
                func detailProject(_ p: SIMD2<Double>, floor: Bool = true) -> CGPoint {
                    let q=c.overhead.projectPoint(floor ? SCNVector3(Float(p.x),c.clothY,Float(p.y)) : world(p))
                    return CGPoint(x:insetRect.minX+CGFloat(q.x)/2,y:insetRect.maxY-CGFloat(q.y)/2)
                }
                let actualScale = hypot(detailProject(G+u*0.01).x-detailProject(G).x,detailProject(G+u*0.01).y-detailProject(G).y)/0.01
                XCTAssertEqual(actualScale,zoom*Double(sin(insetPitch)),accuracy:0.1)
                XCTAssertEqual(hypot(detailProject(G).x-detailProject(H).x,detailProject(G).y-detailProject(H).y),d*zoom,accuracy:0.02)
                let cueRect = CGRect(x:detailProject(H).x-130,y:942,width:260,height:250)
                let cueSize = CGSize(width:520,height:500)
                c.pocketCamera.camera?.projectionDirection = .vertical
                c.pocketCamera.camera?.orthographicScale = Double(cueRect.height)/(2*zoom)
                c.pocketCamera.position = SCNVector3(cue.x,c.clothY+2,cue.z)
                c.pocketCamera.look(at:SCNVector3(cue.x,c.clothY,cue.z),up:SCNVector3(Float(u.x),0,Float(u.y)),localFront:SCNVector3(0,0,-1))
                SCNTransaction.flush()
                _ = c.pocketRenderer.snapshot(atTime:0,with:cueSize,antialiasingMode:.multisampling4X)
                let cueImage = c.pocketRenderer.snapshot(atTime:0,with:cueSize,antialiasingMode:.multisampling4X)
                func cueProject(_ p: SIMD2<Double>) -> CGPoint {
                    let q=c.pocketRenderer.projectPoint(SCNVector3(Float(p.x),c.clothY,Float(p.y)))
                    return CGPoint(x:cueRect.minX+CGFloat(q.x)/2,y:cueRect.maxY-CGFloat(q.y)/2)
                }
                XCTAssertEqual(cueProject(C).x,detailProject(H).x,accuracy:0.02)
                XCTAssertEqual(cueProject(A).x,detailProject(B).x,accuracy:0.02)
                ghostRing.isHidden = true
                ghostAxis.removeFromParentNode()
                let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
                let image=UIGraphicsImageRenderer(size:canvas,format:format).image { context in
                    let ctx=context.cgContext
                    UIColor(white:0.035,alpha:1).setFill();ctx.fill(CGRect(origin:.zero,size:canvas))
                    sceneImage.draw(at:.zero)
                    func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat=30,_ color:UIColor = .white) {
                        let shadow=NSShadow();shadow.shadowColor=UIColor.black.withAlphaComponent(0.35);shadow.shadowBlurRadius=2
                        (s as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:UIFont.systemFont(ofSize:size,weight:.semibold),.foregroundColor:color,.shadow:shadow])
                    }
                    func stroke(_ a:CGPoint,_ b:CGPoint,_ color:UIColor,_ width:CGFloat=3,_ dash:[CGFloat]=[]) {
                        ctx.saveGState();ctx.setStrokeColor(color.cgColor);ctx.setLineWidth(width);ctx.setLineDash(phase:0,lengths:dash)
                        ctx.move(to:a);ctx.addLine(to:b);ctx.strokePath();ctx.restoreGState()
                    }
                    func dot(_ p:CGPoint,_ color:UIColor,_ radius:CGFloat=5) {color.setFill();ctx.fillEllipse(in:CGRect(x:p.x-radius,y:p.y-radius,width:2*radius,height:2*radius))}
                    func leader(_ label:String, anchor:CGPoint, offset:CGPoint, color:UIColor) {
                        let font=UIFont.systemFont(ofSize:30,weight:.semibold)
                        let labelSize=(label as NSString).size(withAttributes:[.font:font])
                        let origin=CGPoint(x:anchor.x+offset.x,y:anchor.y+offset.y)
                        let edge=CGPoint(x:offset.x<0 ? origin.x+labelSize.width+10 : origin.x-10,y:origin.y+labelSize.height/2)
                        let elbow=CGPoint(x:edge.x+(offset.x<0 ? 20 : -20),y:edge.y)
                        stroke(anchor,elbow,color,2);stroke(elbow,edge,color,2)
                        dot(anchor,color,3)
                        text(label,origin.x,origin.y,30,color)
                        XCTAssertGreaterThan(origin.x,12);XCTAssertLessThan(origin.x+labelSize.width,canvas.width-12)
                    }
                    leader("A",anchor:projectedPoint(A),offset:CGPoint(x:95,y:55),color:yellow)
                    dot(projectedPoint(A),.red,4)
                    leader("B",anchor:projectedPoint(B),offset:CGPoint(x:-140,y:-85),color:.white)
                    dot(projectedPoint(B),cyan,4)
                    leader("C",anchor:projectedPoint(G,floor:true),offset:CGPoint(x:-160,y:22),color:.white)
                    dot(projectedPoint(G,floor:true),centerColor,4)
                    leader("瞄准线",anchor:projectedPoint(C+(H-C)*0.47,floor:true),offset:CGPoint(x:-230,y:12),color:.white)
                    leader("进球线",anchor:projectedPoint(T+(P-T)*0.48,floor:true),offset:CGPoint(x:70,y:-62),color:.black)
                    func panel(_ rect: CGRect, image: UIImage) {
                        let shape=UIBezierPath(roundedRect:rect,cornerRadius:18)
                        ctx.saveGState();shape.addClip();image.draw(in:rect);ctx.restoreGState()
                        UIColor.white.withAlphaComponent(0.38).setStroke();shape.lineWidth=2;shape.stroke()
                    }
                    let box=insetRect
                    let titleBox=CGRect(x:insetRect.minX,y:insetRect.minY-90,width:insetRect.width,height:90)
                    let titleShape=UIBezierPath(roundedRect:titleBox,byRoundingCorners:[.topLeft,.topRight],cornerRadii:CGSize(width:18,height:18))
                    UIColor(white:0.035,alpha:1).setFill();titleShape.fill()
                    panel(insetRect,image:detailImage)
                    text(String(format:"角度：%.1f 度",measuredAngle),insetRect.minX+6,insetRect.minY-82,27)
                    text(String(format:"瞄准线误差：%.2f 毫米",d*1000),insetRect.minX+6,insetRect.minY-42,27)
                    let gp=detailProject(G),hp=detailProject(H),bb=detailProject(B,floor:false)
                    ctx.saveGState();UIBezierPath(roundedRect:box,cornerRadius:18).addClip();ctx.clip(to:insetRect)
                    stroke(gp,hp,pink,5);dot(hp,.white,4);dot(gp,centerColor,6);dot(bb,cyan,6)
                    if d>1e-7 {let sign:CGFloat=gp.x>hp.x ? 1 : -1;stroke(CGPoint(x:hp.x+sign*13,y:hp.y),CGPoint(x:hp.x+sign*13,y:hp.y-13),pink,2);stroke(CGPoint(x:hp.x+sign*13,y:hp.y-13),CGPoint(x:hp.x,y:hp.y-13),pink,2)}
                    ctx.restoreGState()
                    panel(cueRect,image:cueImage)
                    text("A：母球近袋点",50,1226,30)
                    text("B：目标球远袋点",50,1274,30)
                    text("C：假想球中心",50,1322,30)
                }
                let filename = exporting ? String(format:"frame-%04d.png",frame) : String(format:"ab-%02.0f.png",angle)
                if !exporting || [0,60,252,444,636,828,1020,1079].contains(frame) {
                    try XCTUnwrap(image.pngData()).write(to:directory.appendingPathComponent(filename))
                }
                if let writer { try writer.append(XCTUnwrap(image.cgImage)) }
                func arr(_ p:SIMD2<Double>)->[Double] {[p.x,p.y]}
                records.append(["frame":frame,"time":Double(frame)/60,"angle":angle,"C":arr(C),"T":arr(T),"P":arr(P),"A":arr(A),"B":arr(B),"G":arr(G),"H":arr(H),"u":arr(u),"radius":r,"distanceMM":d*1000,"insetPixelsPerMeter":zoom,"file":filename,"version":"ab-native-r12","measuredAngle":measuredAngle,"roomStyle":"walnut","linePlacement":"table","targetInsetPitch":35,"mainGhostVisible":true,"mainCameraHeight":mainHeight,"mainFocusForward":forwardFocus,"nativeInset":true])
            }
            if exporting && frame % 60 == 0 { print("AB_POINT export \(frame)/\(angles.count)") }
            try await Task.sleep(nanoseconds:1_000_000)
        }
        if let writer { try await writer.finish() }
        try write(records,directory.appendingPathComponent("geometry.json"))
    }
}

// V021: fixed 30-degree shot, continuous camera rise with a decreasing radius.
// This opt-in exporter only adds a video fixture; application camera defaults are untouched.
extension FeelAimingVideoCaptureTests {
    func testPerspectiveAngleVideo() async throws {
        guard let path = env("PERSPECTIVE_ANGLE_DIR") else {
            throw XCTSkip("Set TEST_RUNNER_PERSPECTIVE_ANGLE_DIR for V021")
        }
        let directory = URL(fileURLWithPath:path,isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let exporting = env("PERSPECTIVE_ANGLE_VIDEO") == "1"
        let canvas = CGSize(width:1440,height:2280)
        let viewport = CGRect(origin:.zero,size:canvas)
        let gold = UIColor(red:1,green:0.83,blue:0.35,alpha:1)
        var c = try makeCapture()
        let geometry = try setState(30,&c,distance:1.20)
        // Video-only frosted ghost: stable world-space illustrative lighting.
        let ghost = try XCTUnwrap(c.scene.ghostBallNode)
        ghost.position = c.ghost
        ghost.isHidden = false
        ghost.childNodes.forEach { $0.isHidden = true }
        let sphere = SCNSphere(radius:CGFloat(radius))
        sphere.segmentCount = 96
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.white
        material.blendMode = .alpha
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = true
        material.shaderModifiers = [.fragment: """
        #pragma transparent
        #pragma body
        float3 N = normalize((scn_frame.inverseViewTransform * float4(_surface.normal, 0.0)).xyz);
        float3 V = normalize((scn_frame.inverseViewTransform * float4(-_surface.position, 0.0)).xyz);
        float3 L = normalize(float3(-0.55, 0.80, -0.35));
        float diffuse = max(dot(N, L), 0.0);
        float highlight = pow(max(dot(N, normalize(L + V)), 0.0), 28.0);
        float rim = pow(1.0 - abs(dot(N, V)), 3.0);
        float shade = 0.20 + 0.67 * diffuse;
        float3 color = float3(0.90, 0.96, 1.0) * shade + float3(0.6) * highlight;
        float alpha = clamp(0.43 + 0.18 * rim + 0.24 * highlight, 0.0, 0.85);
        _output.color = float4(min(color, float3(1.0)) * alpha, alpha);
        """]
        sphere.materials = [material]
        let shell = SCNNode(geometry:sphere)
        shell.castsShadow = false
        ghost.addChildNode(shell)
        // Soft cloth contact cue, confined to this preview's ghost footprint.
        let contact = SCNPlane(width:CGFloat(radius*2.0),height:CGFloat(radius*2.0))
        let shadowMaterial = SCNMaterial()
        shadowMaterial.lightingModel = .constant
        shadowMaterial.diffuse.contents = UIColor.black
        shadowMaterial.writesToDepthBuffer = false
        shadowMaterial.blendMode = .alpha
        let shadowFormat = UIGraphicsImageRendererFormat()
        shadowFormat.scale = 1
        shadowFormat.opaque = false
        let shadowImage = UIGraphicsImageRenderer(size:CGSize(width:256,height:256),format:shadowFormat).image { renderer in
            let colors = [UIColor.black.withAlphaComponent(0.58).cgColor,
                          UIColor.black.withAlphaComponent(0.30).cgColor,
                          UIColor.clear.cgColor] as CFArray
            let gradient = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0,0.38,1])!
            renderer.cgContext.drawRadialGradient(gradient,startCenter:CGPoint(x:128,y:128),startRadius:0,
                                                  endCenter:CGPoint(x:128,y:128),endRadius:128,options:[])
        }
        shadowMaterial.diffuse.contents = shadowImage
        contact.materials = [shadowMaterial]
        let contactNode = SCNNode(geometry:contact)
        contactNode.eulerAngles.x = -.pi/2
        contactNode.position = SCNVector3(c.ghost.x,c.clothY+0.0002,c.ghost.z)
        c.scene.rootNode.addChildNode(contactNode)
        // Video-only footprint: a true cloth-plane ring, projected in both views.
        let footprint = SCNTorus(ringRadius:CGFloat(radius),pipeRadius:0.0008)
        footprint.ringSegmentCount = 128
        footprint.pipeSegmentCount = 8
        let footprintMaterial = SCNMaterial()
        footprintMaterial.lightingModel = .constant
        footprintMaterial.diffuse.contents = UIColor(red:0.88,green:1.0,blue:0.94,alpha:0.92)
        footprintMaterial.writesToDepthBuffer = false
        footprintMaterial.shaderModifiers = [.fragment: """
        #pragma body
        float3 world = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;
        float angle = atan2(world.z - \(c.ghost.z), world.x - \(c.ghost.x));
        float dash = fract((angle / 6.28318530718 + 0.5) * 16.0);
        if (dash > 0.60) { discard_fragment(); }
        """]

        footprint.materials = [footprintMaterial]
        let footprintNode = SCNNode(geometry:footprint)
        footprintNode.name = "videoGhostFootprintRing"
        footprintNode.position = SCNVector3(c.ghost.x,c.clothY+0.001,c.ghost.z)
        footprintNode.castsShadow = false
        c.scene.rootNode.addChildNode(footprintNode)

        XCTAssertEqual(AngleSceneCalculator.horizontalDistance(c.ghost,c.target),2*radius,accuracy:0.000001)
        let cue = try XCTUnwrap(c.scene.cueBallNode).position
        let u = simd_normalize(SIMD2<Float>(c.ghost.x-cue.x,c.ghost.z-cue.z))
        let n = simd_normalize(SIMD2<Float>(c.aim.x-c.target.x,c.aim.z-c.target.z))
        let vertex = SCNVector3(c.ghost.x,c.clothY,c.ghost.z)
        let measured = AngleSceneCalculator.cutAngle(cueBall:cue,targetBall:c.target,pocket:c.aim)
        XCTAssertEqual(measured,30,accuracy:0.0001)
        // The aiming line and the target-to-pocket line intersect at the ghost center.
        c.guides.append(c.scene.addDashedLine(from:vertex,to:c.target,color:.black,radius:0.0015,
                                             dash:0.012,gap:0.009,placement:.table,layer:.aiming))
        let startAngle = atan2(u.y,u.x)
        let sweep = atan2(u.x*n.y-u.y*n.x,simd_dot(u,n))
        let arcRadius:Float = 0.12
        func arcPoint(_ a:Float)->SCNVector3 {
            SCNVector3(vertex.x+arcRadius*cos(a),c.clothY,vertex.z+arcRadius*sin(a))
        }
        for i in 0..<48 {
            c.guides.append(c.scene.addLine(from:arcPoint(startAngle+sweep*Float(i)/48),
                                           to:arcPoint(startAngle+sweep*Float(i+1)/48),color:gold,
                                           radius:0.0018,placement:.table,layer:.aiming))
        }
        let actualArcNodes = Array(c.guides.suffix(48))
        // World X-Z cloth / Y-up, meters. Match the previous cue-relative eye position.
        let oldCue = position(angle:30,target:c.target,aim:c.aim,distance:0.75)
        let cueShift = Double(AngleSceneCalculator.horizontalDistance(oldCue,cue))
        let initialBack = 1.75*cos(6*Double.pi/180)+cueShift
        let initialHeight = 1.75*sin(6*Double.pi/180)
        let finalCue = position(angle:30,target:c.target,aim:c.aim,distance:0.40)
        let cueTravel = Double(AngleSceneCalculator.horizontalDistance(cue,finalCue))
        let standingBack = 1.90
        let followingBack = standingBack-cueTravel-0.05
        let fps = 60
        func frameAligned(_ t:Double)->Double { ceil(t*Double(fps))/Double(fps) }
        // Uniform time dilation of the approved r13 motion; render new native frames at 60fps.
        let standingPitch = atan2(0.85,followingBack)*180/Double.pi
        let baseRise = frameAligned((0.85-initialHeight)/0.25)
        let basePush = cueTravel/0.15+1
        let baseEnd = frameAligned(baseRise+basePush+(90-standingPitch)/12)
        let frameCount = 18*fps
        let endTime = Double(frameCount-1)/Double(fps)
        let timeScale = endTime/baseEnd
        let riseAverageSpeed = 0.25/timeScale
        let pushCruiseSpeed = 0.15/timeScale
        let pushRamp = timeScale
        let orbitAverageDegrees = 12.0/timeScale
        let riseDuration = baseRise*timeScale
        let pushDuration = basePush*timeScale
        let pushEnd = riseDuration+pushDuration
        let keyFrames = [0,Int(riseDuration/2*60),Int(riseDuration*60),Int((riseDuration+pushDuration/2)*60),Int(ceil(pushEnd*60)),Int((pushEnd+endTime)/2*60),frameCount-1]
        let frames = exporting ? Array(0..<frameCount) : keyFrames
        let writer = exporting ? try VideoWriter(url:directory.appendingPathComponent("perspective-angle-v021.mp4"),size:canvas,fps:fps,averageBitRate:32_000_000) : nil
        var records:[[String:Any]] = []
        try write(["timeScale":timeScale,"riseDuration":riseDuration,"pushDuration":pushDuration,"pushEnd":pushEnd,
                   "orbitDuration":endTime-pushEnd,"endTime":endTime,"cueTravel":cueTravel,
                   "riseAverageSpeed":riseAverageSpeed,"pushCruiseSpeed":pushCruiseSpeed,
                   "pushRamp":pushRamp,"orbitAverageDegrees":orbitAverageDegrees,"standingPitch":standingPitch],directory.appendingPathComponent("timing.json"))
        func hermite(_ a:Double,_ b:Double,_ va:Double,_ vb:Double,_ s:Double)->Double {
            (2*s*s*s-3*s*s+1)*a+(s*s*s-2*s*s+s)*va+(-2*s*s*s+3*s*s)*b+(s*s*s-s*s)*vb
        }
        func progress(_ t:Double)->Double {
            let elapsed = min(pushDuration,max(0,t-riseDuration))
            func rampDistance(_ t:Double)->Double {
                0.5*pushCruiseSpeed*(t-pushRamp/Double.pi*sin(Double.pi*t/pushRamp))
            }
            if elapsed < pushRamp { return rampDistance(elapsed)/cueTravel }
            if elapsed > pushDuration-pushRamp { return 1-rampDistance(pushDuration-elapsed)/cueTravel }
            return pushCruiseSpeed*(elapsed-0.5*pushRamp)/cueTravel
        }
        func pathPoint(_ t:Double)->SIMD2<Double> {
            if t < riseDuration {
                let s=t/riseDuration
                return SIMD2(hermite(initialBack,standingBack,-0.25,-0.05/pushDuration*riseDuration,s),
                             hermite(initialHeight,0.85,0.50,0,s))
            } else if t < pushEnd {
                let s=(t-riseDuration)/pushDuration
                return SIMD2(standingBack-cueTravel*progress(t)-0.05*s,0.85)
            } else {
                let duration=endTime-pushEnd, s=(t-pushEnd)/duration
                return SIMD2(hermite(followingBack,0,-0.05/pushDuration*duration,-1.60,s),
                             hermite(0.85,1.15,0,0,s))
            }
        }
        func parameters(_ t:Double)->(Double,Double,Double,String) {
            let point=pathPoint(t)
            let phase=t < riseDuration ? "俯身 → 站立" : (t < pushEnd ? "站立视角靠近" : "转为俯视")
            return (atan2(point.y,point.x)*180/Double.pi,simd_length(point),60,phase)
        }
        var pathRecords:[[String:Double]]=[]
        for i in 0..<frameCount {
            let t=Double(i)/Double(fps)
            let (angle,r,_,_)=parameters(t)
            let horizontal=r*cos(angle*Double.pi/180), height=r*sin(angle*Double.pi/180)
            if let previous=pathRecords.last {
                XCTAssertGreaterThanOrEqual(height+0.0000001,previous["height"]!)
                XCTAssertLessThan(r,previous["radius"]!)
            }
            pathRecords.append(["time":t,"horizontalToGhost":horizontal,"height":height,"radius":r,"pitch":angle,"cueProgress":progress(t)])
        }
        try write(pathRecords,directory.appendingPathComponent("camera-path.json"))
        var previousDistance = Double.infinity
        var previousTargetDistance:Float = .infinity
        for frame in frames {
            try autoreleasepool {
                let time = Double(frame)/Double(fps)
                let movement = Float(progress(time))
                let movingCue = SCNVector3(cue.x+(finalCue.x-cue.x)*movement,cue.y,cue.z+(finalCue.z-cue.z)*movement)
                c.scene.cueBallNode?.position = movingCue
                c.scene.updateCueStick(cueBallPosition:movingCue,aimDirection:SCNVector3(u.x,0,u.y))
                let lineEnd = clothEnd(from:movingCue,toward:SCNVector3(u.x,0,u.y),capture:c)
                c.guides[0].removeFromParentNode()
                c.guides[0] = c.scene.addLine(from:movingCue,to:lineEnd,color:.white,radius:0.0015,placement:.table,layer:.aiming)
                let ballDistance = AngleSceneCalculator.horizontalDistance(movingCue,c.target)
                XCTAssertEqual(AngleSceneCalculator.cutAngle(cueBall:movingCue,targetBall:c.target,pocket:c.aim),30,accuracy:0.0001)
                var currentGeometry = geometry
                currentGeometry["cue"] = xyz(movingCue)
                currentGeometry["distance"] = Double(ballDistance)

                let (degrees,distance,baseFov,phase) = parameters(time)
                let beta = Float(degrees * .pi/180)
                c.mainCamera.position = SCNVector3(vertex.x-Float(distance)*cos(beta)*u.x,
                                                  vertex.y+Float(distance)*sin(beta),
                                                  vertex.z-Float(distance)*cos(beta)*u.y)
                let forward = SIMD3<Float>(cos(beta)*u.x,-sin(beta),cos(beta)*u.y)
                let right = SIMD3<Float>(-u.y,0,u.x)
                let cameraUp = simd_cross(right,forward)
                c.mainCamera.simdOrientation = simd_quatf(simd_float3x3(columns:(right,cameraUp,-forward)))
                // Fixed lens: retain target and pocket; the cue may leave the frame naturally.
                let landmarks = [(c.target,Float(0.08)),(c.aim,Float(0.08))]
                let fov = baseFov
                c.mainCamera.camera?.fieldOfView = fov
                SCNTransaction.flush()
                if frame == 0 {
                    _ = c.main.snapshot(atTime:0,with:viewport.size,antialiasingMode:.multisampling4X)
                    _ = c.main.snapshot(atTime:0,with:viewport.size,antialiasingMode:.multisampling4X)
                }
                let shot = c.main.snapshot(atTime:time,with:viewport.size,antialiasingMode:.multisampling4X)
                func project(_ p:SCNVector3)->CGPoint {
                    let q=c.main.projectPoint(p)
                    return CGPoint(x:CGFloat(q.x),y:viewport.height-CGFloat(q.y))
                }
                let o = project(vertex)
                let a = project(SCNVector3(vertex.x+u.x*0.30,vertex.y,vertex.z+u.y*0.30))
                let b = project(SCNVector3(vertex.x+n.x*0.30,vertex.y,vertex.z+n.y*0.30))
                let va=SIMD2<Double>(Double(a.x-o.x),Double(a.y-o.y))
                let vb=SIMD2<Double>(Double(b.x-o.x),Double(b.y-o.y))
                let projectedAngle = atan2(abs(va.x*vb.y-va.y*vb.x),simd_dot(va,vb))*180/Double.pi
                let predictedAngle = atan(tan(measured * .pi/180)/sin(Double(beta)))*180/Double.pi
                let increase = max(0,projectedAngle-measured)
                XCTAssertEqual(projectedAngle,predictedAngle,accuracy:0.003)
                XCTAssertEqual(o.x,viewport.width/2,accuracy:0.05)
                XCTAssertEqual(o.y,viewport.height/2,accuracy:0.05)
                XCTAssertLessThanOrEqual(distance,previousDistance+0.000001)
                previousDistance=distance
                let projection = try projected(c.main,camera:c.mainCamera,size:viewport.size,capture:c)
                let targetDiameter = projection["ballDiameterPixels"] as! Float
                XCTAssertGreaterThan(targetDiameter,35)
                for (anchor,_) in landmarks {
                    let point = project(anchor)
                    XCTAssertTrue(CGRect(x:60,y:60,width:1320,height:2160).contains(point))
                    XCTAssertFalse(CGRect(x:345,y:9,width:730,height:680).contains(point), "Pocket/target overlaps inset")
                }
                let targetScreen = project(c.target)
                XCTAssertTrue(CGRect(x:70,y:70,width:viewport.width-140,height:viewport.height-140).contains(targetScreen))
                let targetDistance = simd_distance(c.mainCamera.simdPosition,SIMD3<Float>(c.target.x,c.target.y,c.target.z))
                XCTAssertLessThanOrEqual(targetDistance,previousTargetDistance+0.000002)
                previousTargetDistance=targetDistance
                actualArcNodes.forEach { $0.isHidden = true }
                SCNTransaction.flush()
                // Render the inset optically enlarged, avoiding pixelated upscaling of the wide view.
                let localZoom = 200/CGFloat(targetDiameter)
                c.mainCamera.camera?.fieldOfView = atan(tan(fov*Double.pi/360)/Double(localZoom))*360/Double.pi
                SCNTransaction.flush()
                let localShot = c.main.snapshot(atTime:time,with:viewport.size,antialiasingMode:.multisampling4X)
                c.mainCamera.camera?.fieldOfView = fov
                actualArcNodes.forEach { $0.isHidden = false }
                SCNTransaction.flush()
                let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
                let image=UIGraphicsImageRenderer(size:canvas,format:format).image { renderer in
                    let ctx=renderer.cgContext
                    UIColor(white:0.045,alpha:1).setFill();renderer.fill(CGRect(origin:.zero,size:canvas))
                    shot.draw(in:viewport)
                    func text(_ value:String,_ x:CGFloat,_ y:CGFloat,_ fontSize:CGFloat,_ color:UIColor = .white) {
                        (value as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:UIFont.systemFont(ofSize:fontSize,weight:.semibold),.foregroundColor:color])
                    }
                    func line(_ a:CGPoint,_ b:CGPoint,_ color:UIColor,_ width:CGFloat=3) {
                        ctx.setStrokeColor(color.cgColor);ctx.setLineWidth(width);ctx.setLineDash(phase:0,lengths:[])
                        ctx.move(to:a);ctx.addLine(to:b);ctx.strokePath()
                    }
                    // Main labels follow real world anchors, with matching semantic colors.
                    let arcLabel=project(arcPoint(startAngle+sweep/2))
                    text("实际 30°",o.x-295,arcLabel.y-54,54,gold)
                    line(CGPoint(x:o.x-60,y:arcLabel.y-18),CGPoint(x:o.x-12,y:arcLabel.y-18),gold,2)
                    let aimLabel = project(SCNVector3(vertex.x-u.x*0.22,vertex.y,vertex.z-u.y*0.22))
                    text("瞄准线",aimLabel.x-245,aimLabel.y-28,50)
                    line(CGPoint(x:aimLabel.x-70,y:aimLabel.y+6),CGPoint(x:aimLabel.x-12,y:aimLabel.y+6),.white,2)
                    let potLabel=project(SCNVector3(vertex.x+n.x*0.32,vertex.y,vertex.z+n.y*0.32))
                    if potLabel.x < viewport.width-230 && potLabel.y > 40 {
                        text("进球线",potLabel.x+40,potLabel.y-28,50,.black)
                        line(CGPoint(x:potLabel.x+8,y:potLabel.y+6),CGPoint(x:potLabel.x+30,y:potLabel.y+6),.black,2)
                    }
                    // Same-view optical magnification preserves the projected angle.
                    let panel=CGRect(x:400,y:64,width:620,height:570)
                    let content=CGRect(x:panel.minX,y:panel.minY+76,width:panel.width,height:panel.height-76)
                    let localOrigin=CGPoint(x:o.x,y:content.maxY-105)
                    let zoom:CGFloat=200/CGFloat(targetDiameter)
                    XCTAssertGreaterThan(zoom,1)
                    let localX=localOrigin.x+(a.x-o.x)*zoom
                    XCTAssertEqual(localX,a.x,accuracy:0.05)
                    ctx.saveGState()
                    UIBezierPath(roundedRect:panel,cornerRadius:24).addClip()
                    UIColor(red:0.11,green:0.19,blue:0.16,alpha:0.91).setFill()
                    ctx.fill(panel)
                    ctx.saveGState()
                    ctx.clip(to:content)
                    localShot.draw(in:CGRect(x:localOrigin.x-o.x,y:localOrigin.y-o.y,
                                        width:canvas.width,height:canvas.height))
                    // Projected aim extension remains on the same screen axis as the main view.
                    line(CGPoint(x:localOrigin.x,y:content.minY),localOrigin,.white,4)
                    let theta=CGFloat(projectedAngle * Double.pi/180)
                    ctx.setStrokeColor(gold.cgColor);ctx.setLineWidth(4)
                    ctx.addArc(center:localOrigin,radius:300,startAngle:-.pi/2,endAngle:-.pi/2+theta,clockwise:false)
                    ctx.strokePath()
                    text(String(format:"%.1f°",projectedAngle),panel.minX+24,content.minY+30,62,gold)
                    ctx.restoreGState()
                    text("局部放大",panel.minX+28,panel.minY+14,44)
                    ctx.restoreGState()
                    UIColor(white:0.92,alpha:0.85).setStroke()
                    let border=UIBezierPath(roundedRect:panel,cornerRadius:24);border.lineWidth=2;border.stroke()
                    let explanation=CGRect(x:44,y:760,width:354,height:230)
                    UIColor(red:0.12,green:0.22,blue:0.18,alpha:0.90).setFill()
                    UIBezierPath(roundedRect:explanation,cornerRadius:24).fill()
                    text("观察过程",explanation.minX+24,explanation.minY+20,32)
                    text(phase,explanation.minX+24,explanation.minY+78,38,gold)
                    text(String(format:"球距 %.0f 厘米",ballDistance*100),explanation.minX+24,explanation.minY+146,36)
                    // User-selected left cloth area, with labels stacked above large values.
                    let stats=CGRect(x:44,y:1030,width:354,height:580)
                    UIColor(red:0.12,green:0.22,blue:0.18,alpha:0.86).setFill()
                    UIBezierPath(roundedRect:stats,cornerRadius:24).fill()
                    UIColor(white:0.92,alpha:0.65).setStroke()
                    let statsBorder=UIBezierPath(roundedRect:stats,cornerRadius:24);statsBorder.lineWidth=2;statsBorder.stroke()
                    let rows:[(String,String,UIColor)] = [
                        ("真实角度",String(format:"%.0f°",measured),.white),
                        ("观察角度",String(format:"%.1f°",projectedAngle),gold),
                        ("角度偏差",String(format:"+%.1f°",increase),gold)]
                    for (index,row) in rows.enumerated() {
                        let y=stats.minY+28+CGFloat(index)*184
                        text(row.0,stats.minX+28,y,40)
                        text(row.1,stats.minX+28,y+55,64,row.2)
                        if index < 2 {
                            line(CGPoint(x:stats.minX+28,y:y+153),CGPoint(x:stats.maxX-28,y:y+153),UIColor.white.withAlphaComponent(0.2),1)
                        }
                    }

                }
                let filename=String(format:"frame-%04d.png",frame)
                if !exporting || keyFrames.contains(frame) {
                    try XCTUnwrap(image.pngData()).write(to:directory.appendingPathComponent(filename))
                }
                if let writer { try writer.append(XCTUnwrap(image.cgImage)) }
                records.append(["version":"perspective-angle-v021-r16-dashed","frame":frame,"time":time,"file":filename,
                                "phase":phase,"depressionDegrees":degrees,"radiusToVertex":distance,
                                "distanceToTarget":targetDistance,"fov":fov,"cameraPosition":xyz(c.mainCamera.position),
                                "vertex":xyz(vertex),"aimDirection":[u.x,u.y],"potDirection":[n.x,n.y],
                                "actualAngle":measured,"screenAngle":projectedAngle,"formulaAngle":predictedAngle,
                                "increase":increase,"targetDiameterPixels":targetDiameter,
                                "screenCue":[project(movingCue).x,project(movingCue).y],"screenPocket":[project(c.aim).x,project(c.aim).y],"screenTarget":[targetScreen.x,targetScreen.y],"screenVertex":[o.x,o.y],"screenAim":[a.x,a.y],"screenPot":[b.x,b.y],
                                "geometry":currentGeometry,"projection":projection])
            }
            if exporting && frame % 60 == 0 { print("PERSPECTIVE_ANGLE export \(frame)/\(frameCount)") }
            try await Task.sleep(nanoseconds:1_000_000)
        }
        if let writer { try await writer.finish() }
        try write(records,directory.appendingPathComponent("frames.json"))
    }
}


// MARK: - V022 overlap: opt-in native still, isolated from application defaults.
extension FeelAimingVideoCaptureTests {
    private func installOverlapGhost(_ c: Capture) throws {
        // Video-only frosted ghost: stable world-space illustrative lighting.
        let ghost = try XCTUnwrap(c.scene.ghostBallNode)
        ghost.position = c.ghost
        ghost.isHidden = false
        ghost.childNodes.forEach { $0.isHidden = true }
        let sphere = SCNSphere(radius:CGFloat(radius))
        sphere.segmentCount = 96
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.white
        material.blendMode = .alpha
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = true
        material.shaderModifiers = [.fragment: """
        #pragma transparent
        #pragma body
        float3 N = normalize((scn_frame.inverseViewTransform * float4(_surface.normal, 0.0)).xyz);
        float3 V = normalize((scn_frame.inverseViewTransform * float4(-_surface.position, 0.0)).xyz);
        float3 L = normalize(float3(-0.55, 0.80, -0.35));
        float diffuse = max(dot(N, L), 0.0);
        float highlight = pow(max(dot(N, normalize(L + V)), 0.0), 28.0);
        float rim = pow(1.0 - abs(dot(N, V)), 3.0);
        float shade = 0.20 + 0.67 * diffuse;
        float3 color = float3(0.90, 0.96, 1.0) * shade + float3(0.6) * highlight;
        float alpha = clamp(0.43 + 0.18 * rim + 0.24 * highlight, 0.0, 0.85);
        _output.color = float4(min(color, float3(1.0)) * alpha, alpha);
        """]
        sphere.materials = [material]
        let shell = SCNNode(geometry:sphere)
        shell.castsShadow = false
        ghost.addChildNode(shell)
        // Soft cloth contact cue, confined to this preview's ghost footprint.
        let contact = SCNPlane(width:CGFloat(radius*2.0),height:CGFloat(radius*2.0))
        let shadowMaterial = SCNMaterial()
        shadowMaterial.lightingModel = .constant
        shadowMaterial.diffuse.contents = UIColor.black
        shadowMaterial.writesToDepthBuffer = false
        shadowMaterial.blendMode = .alpha
        let shadowFormat = UIGraphicsImageRendererFormat()
        shadowFormat.scale = 1
        shadowFormat.opaque = false
        let shadowImage = UIGraphicsImageRenderer(size:CGSize(width:256,height:256),format:shadowFormat).image { renderer in
            let colors = [UIColor.black.withAlphaComponent(0.58).cgColor,
                          UIColor.black.withAlphaComponent(0.30).cgColor,
                          UIColor.clear.cgColor] as CFArray
            let gradient = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0,0.38,1])!
            renderer.cgContext.drawRadialGradient(gradient,startCenter:CGPoint(x:128,y:128),startRadius:0,
                                                  endCenter:CGPoint(x:128,y:128),endRadius:128,options:[])
        }
        shadowMaterial.diffuse.contents = shadowImage
        contact.materials = [shadowMaterial]
        let contactNode = SCNNode(geometry:contact)
        contactNode.eulerAngles.x = -.pi/2
        contactNode.position = SCNVector3(c.ghost.x,c.clothY+0.0002,c.ghost.z)
        c.scene.rootNode.addChildNode(contactNode)
        // Video-only footprint: a true cloth-plane ring, projected in both views.
        let footprint = SCNTorus(ringRadius:CGFloat(radius),pipeRadius:0.0008)
        footprint.ringSegmentCount = 128
        footprint.pipeSegmentCount = 8
        let footprintMaterial = SCNMaterial()
        footprintMaterial.lightingModel = .constant
        footprintMaterial.diffuse.contents = UIColor(red:0.88,green:1.0,blue:0.94,alpha:0.92)
        footprintMaterial.writesToDepthBuffer = false
        footprintMaterial.shaderModifiers = [.fragment: """
        #pragma body
        float3 world = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;
        float angle = atan2(world.z - \(c.ghost.z), world.x - \(c.ghost.x));
        float dash = fract((angle / 6.28318530718 + 0.5) * 16.0);
        if (dash > 0.60) { discard_fragment(); }
        """]

        footprint.materials = [footprintMaterial]
        let footprintNode = SCNNode(geometry:footprint)
        footprintNode.name = "videoGhostFootprintRing"
        footprintNode.position = SCNVector3(c.ghost.x,c.clothY+0.001,c.ghost.z)
        footprintNode.castsShadow = false
        c.scene.rootNode.addChildNode(footprintNode)

    }

    func testOverlapAimingKeyframe() async throws {
        guard let path = env("OVERLAP_AIM_DIR") else { throw XCTSkip("Set TEST_RUNNER_OVERLAP_AIM_DIR") }
        let directory = URL(fileURLWithPath:path,isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let angle = Double(number("OVERLAP_ANGLE",30))
        let canvas = CGSize(width:1440,height:2280)
        let gold = UIColor(red:1,green:0.83,blue:0.35,alpha:1)
        let cyan = UIColor(red:0.63,green:0.82,blue:0.80,alpha:1)
        let secondary = UIColor(red:0.78,green:0.86,blue:0.82,alpha:1)
        let cardScale:CGFloat = 0.65
        var c = try makeCapture(targetXZ:SIMD2<Float>(0,0.10))
        let a = Float(angle * .pi/180), length:Float = 0.52
        let centreDistance = sqrt(length*length+4*radius*length*cos(a)+4*radius*radius)
        let geometry = try setState(angle,&c,distance:centreDistance)
        let cue = try XCTUnwrap(c.scene.cueBallNode).position
        let u = simd_normalize(SIMD2<Float>(c.ghost.x-cue.x,c.ghost.z-cue.z))
        let n = simd_normalize(SIMD2<Float>(c.aim.x-c.target.x,c.aim.z-c.target.z))
        let right = SIMD2<Float>(u.y,-u.x)
        let delta = SIMD2<Float>(c.target.x-c.ghost.x,c.target.z-c.ghost.z)
        let lateral = abs(simd_dot(delta,right))
        let measured = AngleSceneCalculator.cutAngle(cueBall:cue,targetBall:c.target,pocket:c.aim)
        let overlap = 1-Double(lateral/(2*radius))
        XCTAssertEqual(AngleSceneCalculator.horizontalDistance(cue,c.ghost),length,accuracy:0.000001)
        XCTAssertEqual(overlap,AimingMethodsGeometry.classicOverlap(cutAngleDegrees:measured),accuracy:0.000001)
        XCTAssertEqual(AngleSceneCalculator.horizontalDistance(c.ghost,c.target),2*radius,accuracy:0.000001)
        c.dot.isHidden = true
        try installOverlapGhost(c)
        func world(_ p:SCNVector3,_ dir:SIMD2<Float>,_ distance:Float)->SCNVector3 {
            SCNVector3(p.x+dir.x*distance,c.clothY,p.z+dir.y*distance)
        }
        let vertex = SCNVector3(c.ghost.x,c.clothY,c.ghost.z)
        c.guides.append(c.scene.addDashedLine(from:vertex,to:c.target,color:.black,radius:0.0012,
                                             dash:0.012,gap:0.008,placement:.table,layer:.aiming))
        // Main view follows the actual cue-to-ghost axis, zero side offset.
        try camera(c.mainCamera,rig:Rig(height:0.55,back:0.80,side:0,fov:52),capture:c,eye:true)
        for _ in 0..<3 { _ = c.main.snapshot(atTime:0,with:canvas,antialiasingMode:.multisampling4X) }
        let mainShot = c.main.snapshot(atTime:0,with:canvas,antialiasingMode:.multisampling4X)
        func mainPoint(_ p:SCNVector3)->CGPoint {
            let q=c.main.projectPoint(p);return CGPoint(x:CGFloat(q.x),y:canvas.height-CGFloat(q.y))
        }
        let mainCue=mainPoint(cue), mainTarget=mainPoint(c.target), mainGhost=mainPoint(c.ghost)
        let topPanel=CGRect(x:44,y:56,width:650,height:712)
        let curvePanel=CGRect(x:730,y:56,width:666,height:712)
        let topContent=CGRect(x:topPanel.minX+2,y:topPanel.minY+70,width:topPanel.width-4,height:topPanel.height-72)
        let detailCard=CGRect(x:44,y:56,width:topPanel.width*cardScale,height:topPanel.height*cardScale)
        let graphCard=CGRect(x:490,y:56,width:curvePanel.width*cardScale,height:curvePanel.height*cardScale)
        let mainPocket=mainPoint(SCNVector3(c.aim.x,c.clothY,c.aim.z))
        for step in 0...64 {
            let f=CGFloat(step)/64
            let point=CGPoint(x:mainTarget.x+(mainPocket.x-mainTarget.x)*f,y:mainTarget.y+(mainPocket.y-mainTarget.y)*f)
            XCTAssertFalse(detailCard.insetBy(dx:-12,dy:-12).contains(point), "Detail must clear potting geometry")
            XCTAssertFalse(graphCard.insetBy(dx:-12,dy:-12).contains(point), "Graph must clear potting geometry")
        }
        for point in [mainCue,mainTarget,mainGhost] {
            XCTAssertTrue(CGRect(x:36,y:790,width:1368,height:1430).contains(point))
        }
        let centre=SCNVector3((c.target.x+c.ghost.x)/2,c.clothY,(c.target.z+c.ghost.z)/2)
        c.overheadCamera.position=SCNVector3(centre.x,c.clothY+1,centre.z)
        c.overheadCamera.camera?.orthographicScale=0.115
        c.overheadCamera.look(at:centre,up:SCNVector3(u.x,0,u.y),localFront:SCNVector3(0,0,-1))
        let centreLine=c.scene.addDashedLine(from:world(c.target,u,-0.13),to:world(c.target,u,0.13),
                         color:cyan,radius:0.0006,dash:0.006,gap:0.005,placement:.table,layer:.aiming)
        let cueNode=try XCTUnwrap(c.scene.cueBallNode)
        let cueStick=try XCTUnwrap(c.scene.cueStick)
        cueNode.isHidden=true;cueStick.rootNode.isHidden=true
        SCNTransaction.flush()
        let overhead=c.overhead.snapshot(atTime:0,with:topContent.size,antialiasingMode:.multisampling4X)
        func topPoint(_ p:SCNVector3)->CGPoint {
            let q=c.overhead.projectPoint(p)
            return CGPoint(x:topContent.minX+CGFloat(q.x),y:topContent.maxY-CGFloat(q.y))
        }
        let g=topPoint(vertex),t=topPoint(SCNVector3(c.target.x,c.clothY,c.target.z))
        let edge=topPoint(world(vertex,right,radius))
        let rp=abs(edge.x-g.x)
        let left=max(g.x-rp,t.x-rp),rightEdge=min(g.x+rp,t.x+rp)
        XCTAssertEqual(abs(t.x-g.x)/(2*rp),1-overlap,accuracy:0.00001)
        XCTAssertEqual((rightEdge-left)/(2*rp),overlap,accuracy:0.00001)
        centreLine.removeFromParentNode();cueNode.isHidden=false;cueStick.rootNode.isHidden=false
        SCNTransaction.flush()
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let image=UIGraphicsImageRenderer(size:canvas,format:format).image { renderer in
            let ctx=renderer.cgContext
            UIColor(white:0.045,alpha:1).setFill();renderer.fill(CGRect(origin:.zero,size:canvas))
            mainShot.draw(in:CGRect(origin:.zero,size:canvas))
            func text(_ value:String,_ x:CGFloat,_ y:CGFloat,_ font:CGFloat,_ color:UIColor = .white) {
                (value as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:UIFont.systemFont(ofSize:font,weight:.semibold),.foregroundColor:color])
            }
            func line(_ from:CGPoint,_ to:CGPoint,_ color:UIColor,_ width:CGFloat = 3,_ dashed:Bool = false) {
                ctx.setStrokeColor(color.cgColor);ctx.setLineWidth(width)
                ctx.setLineDash(phase:0,lengths:dashed ? [9,7] : [])
                ctx.move(to:from);ctx.addLine(to:to);ctx.strokePath();ctx.setLineDash(phase:0,lengths:[])
            }
            func panel(_ rect:CGRect) {
                UIColor(red:0.16,green:0.23,blue:0.20,alpha:0.82).setFill()
                UIBezierPath(roundedRect:rect,cornerRadius:22).fill()
            }
            func border(_ rect:CGRect) {
                UIColor.white.withAlphaComponent(0.28).setStroke()
                let path=UIBezierPath(roundedRect:rect,cornerRadius:22);path.lineWidth=1.5;path.stroke()
            }
            ctx.saveGState()
            ctx.translateBy(x:detailCard.minX,y:detailCard.minY)
            ctx.scaleBy(x:cardScale,y:cardScale)
            ctx.translateBy(x:-topPanel.minX,y:-topPanel.minY)
            panel(topPanel)
            ctx.saveGState();UIBezierPath(roundedRect:topPanel,cornerRadius:22).addClip()
            overhead.draw(in:topContent,blendMode:.normal,alpha:0.86)
            text("俯视关系",topPanel.minX+22,topPanel.minY+13,42,secondary)
            let rulerY=topContent.maxY-100
            // The overlap is the intersection of transverse diameter intervals.
            ctx.setFillColor(secondary.withAlphaComponent(0.08).cgColor)
            ctx.fill(CGRect(x:left,y:topContent.minY+100,width:rightEdge-left,height:rulerY-topContent.minY-100))
            for x in [g.x-rp,g.x+rp,t.x-rp,t.x+rp] {
                line(CGPoint(x:x,y:topContent.minY+110),CGPoint(x:x,y:rulerY+18),secondary.withAlphaComponent(0.38),2,true)
            }
            line(CGPoint(x:left,y:rulerY),CGPoint(x:rightEdge,y:rulerY),gold,6)
            for x in [left,rightEdge] { line(CGPoint(x:x,y:rulerY-12),CGPoint(x:x,y:rulerY+12),gold,4) }
            text(String(format:"重合 %.0f%%",overlap*100),topPanel.minX+190,rulerY+25,42,gold)
            // Thin centre guides are projected world lines, perpendicular span uses the same basis.
            let centreAnchor=topPoint(world(c.target,u,0.078))
            line(centreAnchor,CGPoint(x:topPanel.maxX-170,y:topContent.minY+60),cyan,2)
            text("中心线",topPanel.maxX-188,topContent.minY+14,40,cyan)
            let aimAnchor=topPoint(world(vertex,u,-0.060))
            line(aimAnchor,CGPoint(x:topPanel.minX+130,y:aimAnchor.y),.white,2)
            text("瞄准线",topPanel.minX+20,aimAnchor.y-44,40)
            // Entire arc clears the target's transverse circle (centre distance 2R).
            let arcRadius:CGFloat=rp*3.3
            let tangent=topPoint(world(vertex,n,0.10))
            let endAngle=atan2(tangent.y-g.y,tangent.x-g.x)
            ctx.setStrokeColor(gold.cgColor);ctx.setLineWidth(4)
            ctx.addArc(center:g,radius:arcRadius,startAngle:-.pi/2,endAngle:endAngle,clockwise:false)
            ctx.strokePath()
            text(String(format:"%.0f°",measured),g.x+42,g.y-arcRadius-14,38,gold)
            ctx.restoreGState();border(topPanel)
            ctx.restoreGState()

            ctx.saveGState()
            ctx.translateBy(x:graphCard.minX,y:graphCard.minY)
            ctx.scaleBy(x:cardScale,y:cardScale)
            ctx.translateBy(x:-curvePanel.minX,y:-curvePanel.minY)
            panel(curvePanel)
            text("重合度曲线",curvePanel.minX+26,curvePanel.minY+13,42,secondary)
            text("重合度 = 1 − sin θ",curvePanel.minX+26,curvePanel.minY+77,40,secondary)
            let plot=CGRect(x:curvePanel.minX+88,y:curvePanel.minY+162,width:532,height:354)
            func curvePoint(_ theta:Double)->CGPoint {
                CGPoint(x:plot.minX+plot.width*theta/90,y:plot.maxY-plot.height*AimingMethodsGeometry.classicOverlap(cutAngleDegrees:theta))
            }
            for v in [0.0,0.5,1.0] {
                let y=plot.maxY-plot.height*v
                line(CGPoint(x:plot.minX,y:y),CGPoint(x:plot.maxX,y:y),UIColor.white.withAlphaComponent(0.15),1)
                text(String(format:"%.0f%%",v*100),curvePanel.minX+14,y-21,32,secondary)
            }
            for theta in [0.0,30,90] {
                let x=curvePoint(theta).x
                line(CGPoint(x:x,y:plot.minY),CGPoint(x:x,y:plot.maxY),UIColor.white.withAlphaComponent(0.12),1)
                text(String(format:"%.0f°",theta),x-24,plot.maxY+14,34,secondary)
            }
            line(CGPoint(x:plot.minX,y:plot.minY),CGPoint(x:plot.minX,y:plot.maxY),.white,2)
            line(CGPoint(x:plot.minX,y:plot.maxY),CGPoint(x:plot.maxX,y:plot.maxY),.white,2)
            ctx.setStrokeColor(secondary.withAlphaComponent(0.80).cgColor);ctx.setLineWidth(3)
            for k in 0...180 { let p=curvePoint(Double(k)/2); if k == 0 { ctx.move(to:p) } else { ctx.addLine(to:p) } }
            ctx.strokePath()
            for theta in [14.477512,30,48.590378] {
                let p=curvePoint(theta)
                ctx.setFillColor(secondary.withAlphaComponent(0.50).cgColor)
                ctx.fillEllipse(in:CGRect(x:p.x-5,y:p.y-5,width:10,height:10))
            }
            let current=curvePoint(measured)
            line(CGPoint(x:plot.minX,y:current.y),current,secondary.withAlphaComponent(0.50),2,true)
            line(CGPoint(x:current.x,y:plot.maxY),current,secondary.withAlphaComponent(0.50),2,true)
            ctx.setFillColor(gold.cgColor);ctx.setStrokeColor(UIColor.white.cgColor);ctx.setLineWidth(3)
            ctx.addEllipse(in:CGRect(x:current.x-10,y:current.y-10,width:20,height:20));ctx.drawPath(using:.fillStroke)
            text(String(format:"%.0f° · %.0f%%",measured,overlap*100),current.x+18,current.y-52,38,gold)
            text("切球角度 θ",plot.midX-100,plot.maxY+64,38,secondary)
            border(curvePanel)
            ctx.restoreGState()

            // One type/leader system for all three main-scene labels.
            let labelFont=UIFont.systemFont(ofSize:44,weight:.semibold)
            func sceneLabel(_ value:String,_ anchor:CGPoint,_ onRight:Bool,_ color:UIColor) {
                let attributes:[NSAttributedString.Key:Any]=[.font:labelFont,.foregroundColor:color]
                let width=(value as NSString).size(withAttributes:attributes).width
                let sign:CGFloat=onRight ? 1 : -1
                line(CGPoint(x:anchor.x+sign*12,y:anchor.y),CGPoint(x:anchor.x+sign*76,y:anchor.y),color,2)
                (value as NSString).draw(at:CGPoint(x:onRight ? anchor.x+92 : anchor.x-92-width,y:anchor.y-27),withAttributes:attributes)
            }
            sceneLabel("瞄准线",mainPoint(world(vertex,u,-0.23)),false,.white)
            sceneLabel("进球线",mainPoint(world(c.target,n,0.24)),true,.black)
            sceneLabel("假想球",mainGhost,false,.white)
            // The conclusion belongs next to the collision geometry, clear of the cue axis.
            let conclusionOrigin=CGPoint(x:mainGhost.x-610,y:mainGhost.y+100)
            let conclusion=NSMutableAttributedString(string:"")
            for (value,color) in [(String(format:"%.0f°",measured),gold),("切球 ≈ ",UIColor.white),
                                  (String(format:"%.0f%%",overlap*100),gold),("重合",UIColor.white)] {
                conclusion.append(NSAttributedString(string:value,attributes:[.font:UIFont.systemFont(ofSize:48,weight:.semibold),.foregroundColor:color]))
            }
            conclusion.draw(at:conclusionOrigin)
            text("半球",conclusionOrigin.x,conclusionOrigin.y+68,36,.white)

        }
        let filename=String(format:"overlap-%.0f.png",angle)
        try XCTUnwrap(image.pngData()).write(to:directory.appendingPathComponent(filename))
        try XCTUnwrap(mainShot.pngData()).write(to:directory.appendingPathComponent("main-native.png"))
        try XCTUnwrap(overhead.pngData()).write(to:directory.appendingPathComponent("overhead-native.png"))
        try write(["video":"V022","revision":"r3-hierarchy","size":[1440,2280],"geometry":geometry,
                   "cutAngle":measured,"overlap":overlap,"lateralM":lateral,"cueToGhostM":length,
                   "mainCamera":xyz(c.mainCamera.position),"mainFOV":52,"clothY":c.clothY,
                   "layout":["cardScale":cardScale,"cardLinearReduction":0.35,"cardAreaReduction":1-cardScale*cardScale,
                             "detailCard":[detailCard.minX,detailCard.minY,detailCard.width,detailCard.height],
                             "graphCard":[graphCard.minX,graphCard.minY,graphCard.width,graphCard.height],
                             "mainLabelFont":44,"mainLabelWeight":"semibold","leaderWidth":2,"leaderLength":64,
                             "conclusionOrigin":[mainGhost.x-610,mainGhost.y+100]],
                   "topProjection":["ghost":[g.x,g.y],"target":[t.x,t.y],"radiusPixels":rp,
                                    "overlapLeft":left,"overlapRight":rightEdge],
                   "mainProjection":["cue":[mainCue.x,mainCue.y],"target":[mainTarget.x,mainTarget.y],"ghost":[mainGhost.x,mainGhost.y]]],
                  directory.appendingPathComponent("manifest.json"))
    }
}
