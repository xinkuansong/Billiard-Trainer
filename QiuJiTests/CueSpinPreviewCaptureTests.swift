import XCTest
import SceneKit
import UIKit
import simd
import SwiftUI
@testable import QiuJi

/// Opt-in, isolated V019 visual experiment. Production simulation and ball materials.
@MainActor
final class CueSpinPreviewCaptureTests: XCTestCase {
    private let size = CGSize(width: 1080, height: 1600)
    private let panelSize = CGSize(width: 1080, height: 340)
    private let fps = 60
    private let rate: Float = 1.0 / 5.0
    private let end: Float = 0.65
    private let spins: [Float] = [0.5, 0, -0.5]
    private let titles = ["高击点", "中心击点", "低击点"]

    func testAppRenderParity() async throws {
        let env=ProcessInfo.processInfo.environment
        guard let path=env["CUE_SPIN_DIR"] ?? env["TEST_RUNNER_CUE_SPIN_DIR"] else { throw XCTSkip("Opt-in app rendering comparison") }
        let out=URL(fileURLWithPath:path);try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        var images:[UIImage]=[];var metadata:[[String:Any]]=[]
        for (index,daily,perspective) in [(0,false,false),(1,false,true),(2,true,false),(3,true,true)] {
            let scene=AngleTrainingScene()
            if daily { scene.configureDailyClearanceRendering() }
            scene.setupScene()
            XCTAssertTrue(scene.applyTableStyle(.charcoal,showsSights:true));XCTAssertTrue(scene.applyClothColor(.green))
            scene.setCameraMode(.perspective3D,animated:false)
            scene.hideAllBalls();scene.hideCueStick()
            let point=SCNVector3(-0.3,scene.surfaceY+BallPhysics.radius,0.4)
            scene.showBall(key:PositionPlayBall.cueKey,scenePosition:point)
            scene.setCueBallHomeOrientation(simd_quatf(angle:.pi/4,axis:SIMD3<Float>(0,1,0)))
            let cam=try XCTUnwrap(scene.cameraNode)
            func pose() {
                cam.camera?.usesOrthographicProjection = !perspective
                cam.camera?.orthographicScale=0.047
                cam.camera?.projectionDirection = .vertical
                cam.camera?.fieldOfView=CGFloat(2*atan(0.047/sqrt(0.075*0.075+0.28*0.28))*180/Double.pi)
                cam.camera?.zNear=0.005
                cam.position=SCNVector3(point.x,point.y+0.075,point.z+0.28);cam.look(at:point)
                SCNTransaction.flush()
            }
            pose()
            let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=scene;renderer.pointOfView=cam
            renderer.delegate=scene.contactOcclusion
            let size=CGSize(width:700,height:600)
            for _ in 0..<3 { _=renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X) }
            let rendered=renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
            images.append(rendered)
            try XCTUnwrap(rendered.pngData()).write(to:out.appendingPathComponent("variant-\(index).png"))
            metadata.append(["index":index,"daily":daily,"perspective":perspective,"exposure":cam.camera!.exposureOffset,
                "profile":String(describing:scene.renderingProfile),"roomVisible":!(scene.rootNode.childNode(withName:"reference_room",recursively:false)?.isHidden ?? true)])
            if index==3 {
                let root=AngleSceneView(scene:scene,cameraMode:.constant(.perspective3D),interactionMode:.none)
                let host=UIHostingController(rootView:root.ignoresSafeArea())
                let windowScene=try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
                let previous=windowScene.windows.first { $0.isKeyWindow }
                let window=UIWindow(windowScene:windowScene)
                window.frame=CGRect(x:0,y:0,width:350,height:300);window.rootViewController=host;window.makeKeyAndVisible()
                defer { window.isHidden=true;previous?.makeKeyAndVisible() }
                host.view.frame=window.bounds;host.view.layoutIfNeeded()
                try await Task.sleep(nanoseconds:500_000_000)
                pose()
                try await Task.sleep(nanoseconds:500_000_000)
                func find(_ v:UIView)->SCNView? { if let s=v as? SCNView { return s };return v.subviews.compactMap { find($0) }.first }
                let view=try XCTUnwrap(find(host.view))
                XCTAssertTrue(view.scene === scene);XCTAssertTrue(view.pointOfView === cam)
                let onscreen=view.snapshot()
                try XCTUnwrap(onscreen.pngData()).write(to:out.appendingPathComponent("app-component.png"))
                let format=UIGraphicsImageRendererFormat();format.scale=2
                let hierarchy=UIGraphicsImageRenderer(size:window.bounds.size,format:format).image { _ in
                    window.drawHierarchy(in:window.bounds,afterScreenUpdates:true)
                }
                try XCTUnwrap(hierarchy.pngData()).write(to:out.appendingPathComponent("app-window.png"))
                let after=renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
                try XCTUnwrap(after.pngData()).write(to:out.appendingPathComponent("export-after-host.png"))
            }
        }
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let board=UIGraphicsImageRenderer(size:CGSize(width:1400,height:1400),format:format).image { ctx in
            UIColor.black.setFill();ctx.fill(CGRect(x:0,y:0,width:1400,height:1400))
            for j in 0..<4 {
                let x=(j%2)*700,y=(j/2)*700
                images[j].draw(in:CGRect(x:x,y:y+90,width:700,height:600))
                let title=["原导出配置 · 正交","通用 App 配置 · 透视","每日清台配置 · 正交","每日清台配置 · 透视"][j]
                (title as NSString).draw(at:CGPoint(x:x+22,y:y+28),withAttributes:[.font:UIFont.systemFont(ofSize:28,weight:.semibold),.foregroundColor:UIColor.white])
            }
        }
        try XCTUnwrap(board.pngData()).write(to:out.appendingPathComponent("comparison.png"))
        try JSONSerialization.data(withJSONObject:["version":"app-parity-v1","variants":metadata],options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("manifest.json"))
    }

    func testExistingLookAngles() throws {
        let env=ProcessInfo.processInfo.environment
        guard let path=env["CUE_SPIN_DIR"] ?? env["TEST_RUNNER_CUE_SPIN_DIR"] else { throw XCTSkip("Opt-in framing study") }
        let out=URL(fileURLWithPath:path);try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        let scene=AngleTrainingScene()
        let daily=env["CUE_SPIN_LOOK"] != "video" && env["TEST_RUNNER_CUE_SPIN_LOOK"] != "video"
        if daily { scene.configureDailyClearanceRendering() };scene.setupScene()
        scene.setCameraMode(.perspective3D,animated:false)
        XCTAssertTrue(scene.applyTableStyle(.charcoal,showsSights:true));XCTAssertTrue(scene.applyClothColor(.green))
        scene.hideAllBalls();scene.hideCueStick()
        let point=SCNVector3(-0.3,scene.surfaceY+BallPhysics.radius,0.4)
        scene.showBall(key:PositionPlayBall.cueKey,scenePosition:point)
        scene.setCueBallHomeOrientation(simd_quatf(angle:.pi/4,axis:SIMD3<Float>(0,1,0)))
        let cam=SCNNode();cam.camera=try XCTUnwrap(scene.cameraNode?.camera)
        scene.rootNode.addChildNode(cam)
        cam.camera?.usesOrthographicProjection=false;cam.camera?.projectionDirection = .vertical
        cam.camera?.fieldOfView=30;cam.camera?.zNear=0.005
        let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=scene;renderer.pointOfView=cam;renderer.delegate=scene.contactOcclusion
        var images:[UIImage]=[]
        for (i,degrees) in [15.0,35,55,75].enumerated() {
            let angle=Float(degrees * .pi/180),distance:Float=0.34
            cam.transform=SCNMatrix4Identity
            cam.position=SCNVector3(point.x,point.y+sin(angle)*distance,point.z+cos(angle)*distance)
            cam.look(at:point,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
            SCNTransaction.flush()
            for _ in 0..<3 { _=renderer.snapshot(atTime:0,with:CGSize(width:700,height:500),antialiasingMode:.multisampling4X) }
            let image=renderer.snapshot(atTime:0,with:CGSize(width:700,height:500),antialiasingMode:.multisampling4X)
            images.append(image);try XCTUnwrap(image.pngData()).write(to:out.appendingPathComponent("angle-\(i).png"))
        }
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let board=UIGraphicsImageRenderer(size:CGSize(width:1400,height:1200),format:format).image { ctx in
            UIColor(white:0.045,alpha:1).setFill();ctx.fill(CGRect(x:0,y:0,width:1400,height:1200))
            for i in 0..<4 {
                let x=(i%2)*700,y=(i/2)*600
                images[i].draw(in:CGRect(x:x,y:y+80,width:700,height:500))
                let title=["15° · 低机位","35° · 斜俯视","55° · 较高机位","75° · 接近俯视"][i]
                (title as NSString).draw(at:CGPoint(x:x+25,y:y+25),withAttributes:[.font:UIFont.systemFont(ofSize:27,weight:.semibold),.foregroundColor:UIColor.white])
            }
        }
        try XCTUnwrap(board.pngData()).write(to:out.appendingPathComponent("angles.png"))
        try JSONSerialization.data(withJSONObject:["version":"existing-look-angles-v2","profile":String(describing:scene.renderingProfile),"exposure":cam.camera!.exposureOffset,"fov":30,"distance":0.34,"elevations":[15,35,55,75]],options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("manifest.json"))
    }

    func testStaticMaterialStudy() throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["CUE_SPIN_DIR"] ?? env["TEST_RUNNER_CUE_SPIN_DIR"] else { throw XCTSkip("Opt-in static study") }
        let out = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false, mobileRendering: true)
        XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
        XCTAssertTrue(scene.applyClothColor(.green))
        scene.hideAllBalls(); scene.hideCueStick()
        let position = SCNVector3(-0.3,scene.surfaceY+BallPhysics.radius,0.4)
        scene.showBall(key: PositionPlayBall.cueKey, scenePosition: position)
        scene.setCueBallHomeOrientation(simd_quatf(angle: .pi/4, axis: SIMD3<Float>(0,1,0)))
        let ball = try XCTUnwrap(scene.cueBallNode)
        let camera = try XCTUnwrap(scene.cameraNode)
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 0.047
        camera.camera?.zNear = 0.005
        camera.camera?.wantsExposureAdaptation = false
        camera.position = SCNVector3(position.x,position.y+0.075,position.z+0.28)
        camera.look(at:position)
        let renderer = SCNRenderer(device:nil,options:nil)
        renderer.scene=scene; renderer.pointOfView=camera
        renderer.delegate=scene.contactOcclusion
        let renderSize=CGSize(width:700,height:600)
        func snapshot(_ name:String) throws -> UIImage {
            SCNTransaction.flush()
            for _ in 0..<3 { _=renderer.snapshot(atTime:0,with:renderSize,antialiasingMode:.multisampling4X) }
            let image=renderer.snapshot(atTime:0,with:renderSize,antialiasingMode:.multisampling4X)
            try XCTUnwrap(image.pngData()).write(to:out.appendingPathComponent(name+".png"))
            return image
        }
        var materials:[SCNMaterial]=[]
        func gather(_ n:SCNNode) { materials += n.geometry?.materials ?? [] }
        gather(ball);ball.enumerateChildNodes { n,_ in gather(n) }
        XCTAssertFalse(materials.isEmpty)
        let a=try snapshot("a-current")
        var modified=0
        for m in materials {
            if let shader=m.shaderModifiers?[.surface],shader.contains("float roughness=0.34;") {
                var modifiers=m.shaderModifiers ?? [:]
                modifiers[.surface]=shader.replacingOccurrences(of:"float roughness=0.34;",with:"float roughness=0.10;")
                m.shaderModifiers=modifiers;modified += 1
            }
        }
        XCTAssertGreaterThan(modified,0)
        let b=try snapshot("b-gloss-only")
        // Preview-only native PBR experiment, isolated from shared materials and lights.
        scene.rootNode.enumerateChildNodes { n,_ in n.light?.categoryBitMask=1 }
        ball.categoryBitMask=2;ball.enumerateChildNodes { n,_ in n.categoryBitMask=2 }
        // A high-resolution sphere is used only for the video close-up study.
        // Radius and node pose stay identical; remove the low-resolution asset surface.
        let finish=SCNMaterial();finish.lightingModel = .physicallyBased
        finish.diffuse.contents=UIColor.white;finish.roughness.contents=Float(0.12)
        finish.metalness.contents=Float(0)
        finish.shaderModifiers=[.surface:"""
        #pragma body
        float3 localNormal=normalize((scn_node.inverseModelViewTransform*float4(_surface.normal,0.0)).xyz);
        float marker=max(abs(localNormal.x),max(abs(localNormal.y),abs(localNormal.z)));
        float redMask=smoothstep(cos(0.19),cos(0.175),marker);
        _surface.diffuse.rgb=mix(float3(0.90),float3(0.62,0.018,0.025),redMask);
        """]
        let sphere=SCNSphere(radius:CGFloat(BallPhysics.radius));sphere.segmentCount=128;sphere.materials=[finish]
        ball.childNodes.forEach { $0.removeFromParentNode() }
        ball.geometry=sphere;ball.scale=SCNVector3(1,1,1)
        scene.lightingEnvironment.intensity=0.12
        func area(_ offset:SCNVector3,_ width:Float,_ height:Float,_ intensity:CGFloat) {
            let node=SCNNode();let light=SCNLight()
            light.type = .area;light.areaType = .rectangle
            light.areaExtents=SIMD3<Float>(width,height,0)
            light.intensity=intensity;light.color=UIColor.white
            light.categoryBitMask=2;light.drawsArea=false
            node.light=light
            node.position=SCNVector3(position.x+offset.x,position.y+offset.y,position.z+offset.z)
            node.look(at:position);scene.rootNode.addChildNode(node)
        }
        func directional(_ offset:SCNVector3,_ intensity:CGFloat) {
            let node=SCNNode();let light=SCNLight();light.type = .directional
            light.intensity=intensity;light.color=UIColor.white;light.categoryBitMask=2
            node.light=light;node.position=SCNVector3(position.x+offset.x,position.y+offset.y,position.z+offset.z)
            node.look(at:position);scene.rootNode.addChildNode(node)
        }
        directional(SCNVector3(-0.3,0.4,0.3),250)
        directional(SCNVector3(0.3,0.04,0.2),70)
        area(SCNVector3(-0.20,0.25,0.22),0.16,0.075,20000)
        area(SCNVector3(0.18,0.03,0.12),0.14,0.16,1700)
        let c=try snapshot("c-shaped-light")
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let board=UIGraphicsImageRenderer(size:CGSize(width:2100,height:720),format:format).image { ctx in
            UIColor(white:0.035,alpha:1).setFill();ctx.fill(CGRect(x:0,y:0,width:2100,height:720))
            for (j,image) in [a,b,c].enumerated() {
                image.draw(in:CGRect(x:j*700,y:100,width:700,height:600))
                let title=["原版 · 发灰的宽明暗带","只降低粗糙度","近景候选 · 侧上方主光"][j]
                (title as NSString).draw(at:CGPoint(x:j*700+28,y:28),withAttributes:[.font:UIFont.systemFont(ofSize:30,weight:.semibold),.foregroundColor:UIColor.white])
            }
        }
        try XCTUnwrap(board.pngData()).write(to:out.appendingPathComponent("comparison.png"))
        try "static-material-v4".write(to:out.appendingPathComponent("version.txt"),atomically:true,encoding:.utf8)
    }

    func testCapture() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["TEST_RUNNER_CUE_SPIN_DIR"] ?? env["CUE_SPIN_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_CUE_SPIN_DIR for the visual preview")
        }
        let out = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let sideSpin = Float(env["TEST_RUNNER_CUE_SPIN_SIDE"] ?? env["CUE_SPIN_SIDE"] ?? "0") ?? 0
        let spins: [Float] = sideSpin == 0 ? self.spins : [0.4, 0, -0.4]
        let sideName = sideSpin > 0 ? "左塞" : (sideSpin < 0 ? "右塞" : "无侧旋")
        let export = (env["TEST_RUNNER_CUE_SPIN_VIDEO"] ?? env["CUE_SPIN_VIDEO"]) == "1"
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false, mobileRendering: true)
        scene.setCameraMode(.perspective3D, animated: false)
        XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
        XCTAssertTrue(scene.applyClothColor(.green))
        scene.setTableGridVisible(true)
        scene.hideAllBalls()
        scene.hideCueStick()
        let r = BallPhysics.radius
        XCTAssertEqual(r, 0.028575, accuracy: 0.000001)
        let start = SCNVector3(-1.05, scene.surfaceY + r, 0.4)
        let aim = SCNVector3(1, 0, 0)
        scene.showBall(key: PositionPlayBall.cueKey, scenePosition: start)
        let home = simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(0, 1, 0))
        scene.setCueBallHomeOrientation(home)
        let ball = try XCTUnwrap(scene.cueBallNode)
        let camera = SCNNode()
        camera.camera = try XCTUnwrap(scene.cameraNode?.camera)
        scene.rootNode.addChildNode(camera)
        camera.camera?.usesOrthographicProjection = false
        camera.camera?.projectionDirection = .vertical
        let upperViewExtra: CGFloat = 80
        let captureSize = CGSize(width: panelSize.width, height: panelSize.height + upperViewExtra)
        let captureFOV = CGFloat(2 * atan(tan(Double.pi / 12) * Double(captureSize.height / panelSize.height)) * 180 / Double.pi)
        camera.camera?.fieldOfView = captureFOV
        let elevationDegrees = Float(env["TEST_RUNNER_CUE_SPIN_ELEVATION"] ?? env["CUE_SPIN_ELEVATION"] ?? "25") ?? 25
        let elevation: Float = elevationDegrees * .pi / 180
        let cameraDistance: Float = 0.34
        let cueView = (env["TEST_RUNNER_CUE_SPIN_VIEW"] ?? env["CUE_SPIN_VIEW"]) == "cue"
        camera.camera?.zNear = 0.005
        camera.camera?.zFar = 30
        camera.camera?.wantsExposureAdaptation = false
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        renderer.delegate = scene.contactOcclusion
        renderer.autoenablesDefaultLighting = false
        var playbacks: [TrajectoryPlayback] = []
        var cueSpeeds: [Float] = []
        for spin in spins {
            XCTAssertLessThanOrEqual(sqrt(spin*spin + sideSpin*sideSpin), CuePhysics.miscueLimitFraction + 0.000001)
            let cueSpeed: Float = 2.5
            let strike = CueBallStrike.executeStrike(aimDirection: aim, velocity: cueSpeed, spinX: sideSpin, spinY: spin)
            XCTAssertGreaterThan(strike.velocity.length(), 0)
            if spin != 0 { XCTAssertLessThan(strike.angularVelocity.z * spin, 0) }
            let prediction = ShotPredictor.simulateFree(cueBall: start, aimDir: aim, velocity: cueSpeed,
                spinX: sideSpin, spinY: spin, surfaceY: scene.surfaceY, balls: [], maxEvents: 100, maxTime: 1,
                includePresentation: true)
            let recorder = try XCTUnwrap(prediction.recorder)
            playbacks.append(TrajectoryPlayback(recorder: recorder, surfaceY: start.y))
            cueSpeeds.append(cueSpeed)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1; format.opaque = true
        let canvas = UIGraphicsImageRenderer(size: size, format: format)
        let count = 270
        let writer = export ? try VideoWriter(url: out.appendingPathComponent("cue-spin-preview.mp4"), size: size, fps: fps) : nil
        var orientations = spins.map { _ in home }
        var previousOmega = try playbacks.map { try XCTUnwrap($0.stateAt(ballName: ShotInput.cueBallName, time: 0)).angularVelocity }
        var lastTime: Float = 0
        var ledger: [[String: Any]] = []
        let keys: Set<Int> = [0, 24, 60, 120, 210, 269]
        for i in 0..<count {
            let wall = Double(i) / Double(fps)
            let t = min(end, max(0, Float(wall - 0.4) * rate))
            var panels: [UIImage] = []
            var states: [PlaybackBallState] = []
            for j in spins.indices {
                let state = try XCTUnwrap(playbacks[j].stateAt(ballName: ShotInput.cueBallName, time: t))
                XCTAssertGreaterThan(state.velocity.x, 0)
                XCTAssertLessThan(abs(state.position.z), 0.6)
                XCTAssertEqual(state.position.y, start.y, accuracy: 0.00001)
                XCTAssertLessThan(abs(state.position.x), 1.1)
                SCNTransaction.begin(); SCNTransaction.disableActions = true
                ball.position = state.position
                ball.simdOrientation = orientations[j]
                BallSpinIntegrator.advance(node: ball, from: previousOmega[j], to: state.angularVelocity, dt: t-lastTime)
                orientations[j] = ball.simdOrientation
                previousOmega[j] = state.angularVelocity
                camera.transform = SCNMatrix4Identity
                camera.position = cueView
                    ? SCNVector3(state.position.x - cos(elevation)*cameraDistance, state.position.y + sin(elevation)*cameraDistance, state.position.z)
                    : SCNVector3(state.position.x, state.position.y + sin(elevation)*cameraDistance, state.position.z + cos(elevation)*cameraDistance)
                camera.look(at: state.position, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,-1))
                SCNTransaction.commit(); SCNTransaction.flush()
                if export || keys.contains(i) {
                    if i == 0 { for _ in 0..<3 { _ = renderer.snapshot(atTime: 0, with: captureSize, antialiasingMode: .multisampling4X) } }
                    let full = renderer.snapshot(atTime: wall, with: captureSize, antialiasingMode: .multisampling4X)
                    let cropped = try XCTUnwrap(full.cgImage?.cropping(to: CGRect(origin: .zero, size: panelSize)))
                    panels.append(UIImage(cgImage: cropped))
                    let center = renderer.projectPoint(state.position)
                    let right = renderer.projectPoint(cueView
                        ? SCNVector3(state.position.x,state.position.y,state.position.z+r)
                        : SCNVector3(state.position.x+r,state.position.y,state.position.z))
                    XCTAssertEqual(center.x, Float(panelSize.width/2), accuracy: 1)
                    XCTAssertGreaterThan(abs(right.x-center.x), 50)
                    XCTAssertLessThan(abs(right.x-center.x), 58)
                }
                states.append(state)
                let q = ball.simdOrientation.vector
                ledger.append(["frame": i, "row": j, "time": wall, "physicsTime": t, "spinY": spins[j], "spinX":sideSpin,
                    "cueSpeed": cueSpeeds[j], "position": [state.position.x,state.position.y,state.position.z],
                    "velocity": [state.velocity.x,state.velocity.y,state.velocity.z],
                    "omega": [state.angularVelocity.x,state.angularVelocity.y,state.angularVelocity.z],
                    "orientation": [q.x,q.y,q.z,q.w], "phase": String(describing: state.motionState)])
            }
            lastTime = t
            if export || keys.contains(i) {
                let frame = canvas.image { context in
                    UIColor(red: 0.025, green: 0.05, blue: 0.045, alpha: 1).setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                    func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ n: CGFloat, _ color: UIColor = .white) {
                        (s as NSString).draw(at: CGPoint(x:x,y:y), withAttributes: [.font: UIFont.systemFont(ofSize:n,weight:.semibold), .foregroundColor:color])
                    }
                    text("母球，到底怎么转？", 48, 48, 54)
                    text("杆速2.5 m/s · \(sideName) · 1/5 慢放", 50, 126, 27, UIColor(white:0.72,alpha:1))
                    for j in spins.indices {
                        let y = CGFloat(224 + j * 420)
                        panels[j].draw(in: CGRect(x:0,y:y+52,width:1080,height:340))
                        text(titles[j] + (sideSpin == 0 ? "" : " · " + sideName), 48, y, 30)
                        let w = states[j].angularVelocity.z
                        let stateLabel = abs(w) < 0.35 ? "近乎无旋转" : (w < 0 ? "前旋" : "后旋")
                        text(stateLabel, sideSpin == 0 ? 270 : 370, y+3, 29, UIColor(red:1,green:0.8,blue:0.42,alpha:1))
                        text(cueView ? "向前方行进 ↑" : "前进 →", cueView ? 770 : 830, y+6, 25, UIColor(white:0.8,alpha:1))
                        let c = context.cgContext
                        let center = CGPoint(x:115,y:y+208), rr: CGFloat = 45
                        c.setFillColor(UIColor.white.cgColor)
                        c.fillEllipse(in:CGRect(x:center.x-rr,y:center.y-rr,width:rr*2,height:rr*2))
                        c.setStrokeColor(UIColor(red:0.82,green:0.1,blue:0.14,alpha:1).cgColor); c.setLineWidth(1)
                        c.move(to:CGPoint(x:center.x-rr,y:center.y)); c.addLine(to:CGPoint(x:center.x+rr,y:center.y))
                        c.move(to:CGPoint(x:center.x,y:center.y-rr)); c.addLine(to:CGPoint(x:center.x,y:center.y+rr)); c.strokePath()
                        c.setFillColor(UIColor(red:0.95,green:0.14,blue:0.1,alpha:1).cgColor)
                        c.fillEllipse(in:CGRect(x:center.x-CGFloat(sideSpin)*rr-7,y:center.y-CGFloat(spins[j])*rr-7,width:14,height:14))
                        text("击点", 89,y+271,22)
                    }
                    text(String(format:"实际行进 %.2f 秒",t), 48, 1510, 25, UIColor(white:0.72,alpha:1))
                    text("旋转近景 · 视觉验证", 730, 1510, 25, UIColor(white:0.72,alpha:1))
                }
                if keys.contains(i) { try XCTUnwrap(frame.pngData()).write(to:out.appendingPathComponent(String(format:"frame-%03d.png",i))) }
                if let writer { try writer.append(try XCTUnwrap(frame.cgImage)) }
            }
            if i % 60 == 0 { print("CUE_SPIN frame \(i)/\(count)"); await Task.yield() }
        }
        if let writer { try await writer.finish() }
        let lowStart = try XCTUnwrap(playbacks[2].stateAt(ballName: ShotInput.cueBallName, time: 0))
        let lowEnd = try XCTUnwrap(playbacks[2].stateAt(ballName: ShotInput.cueBallName, time: end))
        XCTAssertGreaterThan(lowStart.angularVelocity.z, 0)
        // Stronger strokes need longer to reverse: require backspin decay, not an early sign flip.
        XCTAssertLessThan(lowEnd.angularVelocity.z, lowStart.angularVelocity.z)
        try JSONSerialization.data(withJSONObject: ["version":"cue-spin-r13", "spinX":sideSpin, "view":cueView ? "cue-direction" : "side", "upperViewExtra":upperViewExtra, "ballCenterY":captureSize.height/2, "tableGrid":"production-4x8", "cameraElevation":elevationDegrees, "cameraDistance":cameraDistance, "fov":captureFOV, "exposure":camera.camera!.exposureOffset, "renderingProfile":String(describing:scene.renderingProfile), "fps":fps, "frames":count, "rate":rate, "samples":ledger], options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("manifest.json"))
    }
}
