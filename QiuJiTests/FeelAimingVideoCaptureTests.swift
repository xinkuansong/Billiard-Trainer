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
    private let mainRenderSize = CGSize(width: 1440, height: 1916)
    private let mainCropTop: CGFloat = 280
    private let radius = AngleSceneCalculator.ballRadius
    private var centerDistance: Float { middlePocket ? 0.60 : 0.75 }
    private var middlePocket: Bool { env("FEEL_LAYOUT") == "middle" }
    private var pocketIndex: Int { middlePocket ? 4 : 3 }
    private var frameCount: Int { middlePocket ? 1920 : 1440 }

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
        let mainCamera: SCNNode
        let eyeCamera: SCNNode
        let main: SCNRenderer
        let eye: SCNRenderer
        let overheadCamera: SCNNode
        let overhead: SCNRenderer
        let dot: SCNNode
        var guides: [SCNNode] = []
    }

    private func makeCapture() throws -> Capture {
        let scene = AngleTrainingScene()
        scene.setupScene()
        scene.setupVisualizationNodes()
        XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
        XCTAssertTrue(scene.applyClothColor(.green))
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
        XCTAssertTrue(try XCTUnwrap(scene.cueStick).applyStyle(.inkDragon))
        scene.hideAllBalls()
        scene.hideAllVisualization()
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY)[pocketIndex]
        let offset = Float(0.70 / sqrt(2.0))
        let target = middlePocket
            ? SCNVector3(0, scene.surfaceY+radius, -0.125)
            : SCNVector3(pocket.x-offset+number("FEEL_TARGET_SHORT_SHIFT",0.12), scene.surfaceY+radius, pocket.z-offset)
        scene.showBall(key: "_8", scenePosition: target)
        scene.setCurrentTargetNumber(8)
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
        return Capture(scene: scene, target: target, aim: aim, ghost: ghost, clothY: clothY,
                       mainCamera: mainCamera, eyeCamera: eyeCamera, main: renderer(mainCamera), eye: renderer(eyeCamera),
                       overheadCamera: overheadCamera, overhead: renderer(overheadCamera), dot: dot)
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

    private func setState(_ angle: Double, _ c: inout Capture, distance: Float? = nil) throws -> [String: Any] {
        let d = distance ?? centerDistance
        let cue = position(angle: angle, target: c.target, aim: c.aim, distance: d)
        try XCTUnwrap(c.scene.cueBallNode).position = cue
        let direction = simd_normalize(SIMD2<Float>(c.ghost.x-cue.x, c.ghost.z-cue.z))
        let u = SCNVector3(direction.x, 0, direction.y)
        let end = AngleSceneCalculator.rayToInnerRail(from: cue, dir: u, inset: 0)
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
        return ["layout": middlePocket ? "middle" : "corner", "pocketIndex": pocketIndex,
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
        let end = AngleSceneCalculator.rayToInnerRail(from: cue,
            dir: SCNVector3(c.ghost.x-cue.x, 0, c.ghost.z-cue.z), inset: 0)
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
        let m = camera.simdWorldTransform
        return ["points": points, "pocketBounds":pocketBounds, "floorLines":floorLines, "ballDiameterPixels": hypotf(b.x-a.x,b.y-a.y), "position": xyz(camera.position),
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
            let sign: CGFloat = (size.width < 1000 && !pot) || (middlePocket && pot && dx < 0) ? -1 : 1
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
        let metrics = middlePocket ? metricValues(c) : []
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
            let smallAttributes:[NSAttributedString.Key:Any]=[.font:UIFont.systemFont(ofSize:30,weight:.semibold),.foregroundColor:UIColor.white]
            ("局部俯视" as NSString).draw(at:CGPoint(x:overheadFrame.minX+18,y:overheadFrame.minY+10),withAttributes:smallAttributes)
            ctx.cgContext.restoreGState()
            UIColor.white.withAlphaComponent(0.9).setStroke()
            let overheadBorder=UIBezierPath(roundedRect:overheadFrame,cornerRadius:20);overheadBorder.lineWidth=2;overheadBorder.stroke()
            viewBadge("第一人称",rect:CGRect(x:32,y:24,width:200,height:62),gold:gold,context:ctx.cgContext)
            viewBadge("第三人称",rect:CGRect(x:32,y:mainRect.minY+24,width:200,height:62),gold:gold,context:ctx.cgContext)
            if middlePocket { drawMetrics(metrics) }

        }
        func box(_ rect:CGRect)->[CGFloat] { [rect.minX,rect.minY,rect.width,rect.height] }
        return (image,["metricValues":metrics,"main":mainProjection,"eye":eyeProjection,"overhead":overheadProjection,
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
        let samples = middlePocket ? 1500 : 750
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
        let angles: [Double] = middlePocket ? [-75,-60,-45,-30.1,-30,-29.9,-15,0,15,29.9,30,30.1,45,60,75] : [0,15,29.9,30,30.1,45,60,75]
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
