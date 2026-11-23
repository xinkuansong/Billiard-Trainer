//
//  SequenceStillCueTests.swift
//  QiuJiTests
//
//  精讲静帧须与视频「亮方案」拍同口径：有预告线时摆瞄准位球杆（DR-074）。
//  用同一序列开关 `showCueStroke` 对拍 s01_still，差必须大到能解释为整支杆，
//  而不是抗锯齿噪声。
//

import XCTest
import UIKit
import SceneKit
@testable import QiuJi

final class SequenceStillCueTests: XCTestCase {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @MainActor
    func test_renderStills_shotFrameDiffersWhenCueEnabled() throws {
        let sequence = try loadStraightShotSequence()
        var withCue = SequenceVideoExporter.Options.teaching()
        withCue.size = CGSize(width: 360, height: 640)
        withCue.showCueStroke = true
        var noCue = withCue
        noCue.showCueStroke = false

        let withFrames = SequenceVideoExporter.renderStills(sequence: sequence, options: withCue)
        let noFrames = SequenceVideoExporter.renderStills(sequence: sequence, options: noCue)
        XCTAssertFalse(withFrames.isEmpty, "无 Metal / 渲染失败：renderStills 返回空")
        XCTAssertEqual(withFrames.map(\.name), noFrames.map(\.name))

        let withShot = try XCTUnwrap(withFrames.first { $0.name == "s01_still" }?.image)
        let noShot = try XCTUnwrap(noFrames.first { $0.name == "s01_still" }?.image)
        XCTAssertEqual(withShot.width, noShot.width)
        XCTAssertEqual(withShot.height, noShot.height)

        writeEvidence(withShot, name: "s01_with_cue.png")
        writeEvidence(noShot, name: "s01_no_cue.png")
        if let final = withFrames.first(where: { $0.name == "final" })?.image {
            writeEvidence(final, name: "final_after_cue.png")
        }

        let shotDiff = differingOpaquePixels(withShot, noShot)
        let total = withShot.width * withShot.height
        // 顶视一支杆远大于抗锯齿噪声；取 0.15% 为下限（360×640 ≈ 345 px）。
        // 终局图不对拍：`placeBoard` 首次会随机重坐母球朝向，两次独立渲染本就会差一圈球面。
        XCTAssertGreaterThan(
            shotDiff, max(300, total / 700),
            "开杆静帧开关球杆后像素差过小（\(shotDiff)/\(total)），杆可能没画上")
    }

    // MARK: - Helpers

    private func loadStraightShotSequence() throws -> PositionPlaySequence {
        let seqDir = repoRoot.appendingPathComponent("content/position_play/sequences")
        let name = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(atPath: seqDir.path)
                .first { $0.hasPrefix("drill_c001__") && $0.hasSuffix(".json") },
            "缺 c001 序列：\(seqDir.path)")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            PositionPlaySequence.self,
            from: Data(contentsOf: seqDir.appendingPathComponent(name)))
    }

    private func writeEvidence(_ image: CGImage, name: String) {
        let dir = repoRoot.appendingPathComponent("build/still-cue-evidence")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        if let data = UIImage(cgImage: image).pngData() {
            try? data.write(to: url)
        }
    }

    private func differingOpaquePixels(_ a: CGImage, _ b: CGImage) -> Int {
        let width = a.width
        let height = a.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var bufA = [UInt8](repeating: 0, count: height * bytesPerRow)
        var bufB = [UInt8](repeating: 0, count: height * bytesPerRow)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctxA = CGContext(
                data: &bufA, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: space, bitmapInfo: info),
              let ctxB = CGContext(
                data: &bufB, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: space, bitmapInfo: info)
        else { return 0 }
        ctxA.draw(a, in: CGRect(x: 0, y: 0, width: width, height: height))
        ctxB.draw(b, in: CGRect(x: 0, y: 0, width: width, height: height))
        var count = 0
        var i = 0
        while i < bufA.count {
            if bufA[i] != bufB[i] || bufA[i + 1] != bufB[i + 1] || bufA[i + 2] != bufB[i + 2] {
                count += 1
            }
            i += bytesPerPixel
        }
        return count
    }
}

// V008: opt-in still capture through the same production SceneKit scene as videos.
extension SequenceStillCueTests {
    @MainActor
    func testCueTipVideoFrames() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["CUE_TIP_CAPTURE_DIR"] ?? env["TEST_RUNNER_CUE_TIP_CAPTURE_DIR"] else {
            throw XCTSkip("Opt-in cue-tip video framing")
        }
        let out = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        SCNTransaction.begin(); SCNTransaction.disableActions = true
        let scene = AngleTrainingScene(); scene.setupScene()
        XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
        scene.applyClothColor(.green)
        scene.hideAllBalls()
        let r = AngleSceneCalculator.ballRadius
        let center = SCNVector3(0, scene.surfaceY+r, 0)
        scene.showBall(key: PositionPlayBall.cueKey, scenePosition: center)
        scene.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0)))
        // Preserve production model, textures, shaders and lights; only the camera
        // and output sampling are adapted to the macro framing.
        let stick = try XCTUnwrap(scene.cueStick)
        XCTAssertTrue(stick.applyStyle(.inkDragon))
        var tipMaterialCount = 0
        stick.rootNode.enumerateChildNodes { node, _ in
            guard let original = node.geometry else { return }
            let geometry = original.copy() as! SCNGeometry
            geometry.materials = original.materials.map { material in
                guard material.name == "PiTou" else { return material }
                tipMaterialCount += 1
                let tip = material.copy() as! SCNMaterial
                tip.diffuse.contents = UIColor(white:0.32,alpha:1)
                tip.multiply.contents = UIColor.white
                tip.metalness.contents = 0
                tip.roughness.contents = 0.85
                return tip
            }
            node.geometry = geometry
        }
        XCTAssertGreaterThan(tipMaterialCount,0)
        XCTAssertNotNil(scene.modelCueStickNode, "This preview requires the actual USDZ cue")
        scene.setCameraMode(.perspective3D, animated: false)
        let camera = try XCTUnwrap(scene.cameraNode)
        let lens = try XCTUnwrap(camera.camera)
        lens.usesOrthographicProjection = true; lens.projectionDirection = .vertical
        lens.orthographicScale = 0.074; lens.zNear = 0.001; lens.zFar = 100
        lens.wantsExposureAdaptation = false; lens.bloomIntensity = 0
        // The default 3m SSAO radius is table-scale, unsuitable for a 57mm close-up.
        lens.screenSpaceAmbientOcclusionRadius = 0.02
        lens.screenSpaceAmbientOcclusionIntensity = 0.15
        lens.screenSpaceAmbientOcclusionBias = 0.001
        lens.exposureOffset = -0.70
        let focus = SCNVector3(-0.010, scene.surfaceY+0.032, 0)
        camera.position = SCNVector3(focus.x, focus.y+0.085, 0.38)
        camera.look(at: focus, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,-1))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene; renderer.pointOfView = camera
        renderer.autoenablesDefaultLighting = false; renderer.delegate = scene.contactOcclusion
        let size = CGSize(width: 1080, height: 1440)
        let eyeHeight=Float(env["CUE_TIP_EYE_HEIGHT"] ?? env["TEST_RUNNER_CUE_TIP_EYE_HEIGHT"] ?? "0.35")!
        let annotationFont = CGFloat(Double(env["TEST_RUNNER_CUE_TIP_LABEL_SIZE"] ?? env["CUE_TIP_LABEL_SIZE"] ?? "40")!)
        let insetBox = CGRect(x:500,y:80,width:540,height:540)
        let insetCamera = SCNNode(); insetCamera.camera = lens.copy() as? SCNCamera
        scene.rootNode.addChildNode(insetCamera)
        // Exact side elevation: parallel rays preserve the contact meridian as
        // the ball silhouette instead of hiding it behind perspective curvature.
        insetCamera.camera!.usesOrthographicProjection = true
        insetCamera.camera!.orthographicScale = 0.070
        insetCamera.position = SCNVector3(0.16,scene.surfaceY+0.0646,-0.43)
        insetCamera.look(at:SCNVector3(0,scene.surfaceY+0.035,-0.43),up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
        let insetRenderer = SCNRenderer(device:nil,options:nil)
        insetRenderer.scene=scene;insetRenderer.pointOfView=insetCamera
        insetRenderer.autoenablesDefaultLighting=false;insetRenderer.delegate=scene.contactOcclusion
        let insetSize=CGSize(width:1080,height:1080)
        lens.usesOrthographicProjection=false;lens.fieldOfView=48
        let cueNode = try XCTUnwrap(scene.cueBallNode)
        let cuePosition = SCNVector3(0,center.y,0)
        cueNode.position = cuePosition
        var ballVertices: [[Float]] = []
        cueNode.enumerateChildNodes { node, _ in
            guard let source = node.geometry?.sources(for:.vertex).first,
                  source.usesFloatComponents,source.bytesPerComponent == 4 else { return }
            source.data.withUnsafeBytes { bytes in
                for i in 0..<source.vectorCount {
                    let o=source.dataOffset+i*source.dataStride
                    let q=node.convertPosition(SCNVector3(bytes.loadUnaligned(fromByteOffset:o,as:Float.self),bytes.loadUnaligned(fromByteOffset:o+4,as:Float.self),bytes.loadUnaligned(fromByteOffset:o+8,as:Float.self)),to:nil)
                    ballVertices.append([q.x-cuePosition.x,q.y-cuePosition.y,q.z-cuePosition.z])
                }
            }
        }
        try JSONSerialization.data(withJSONObject:ballVertices).write(to:out.appendingPathComponent("ball-mesh.json"))
        // Refine only the capture scene's ball mesh; preserve UVs and materials.
        // Project subdivisions onto the same sphere used by tip-contact geometry.
        cueNode.enumerateChildNodes { node, _ in
            guard let old=node.geometry,let positions=old.sources(for:.vertex).first,
                  let texture=old.sources(for:.texcoord).first else { return }
            func component(_ source:SCNGeometrySource,_ index:Int,_ c:Int)->Float {
                source.data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset:source.dataOffset+index*source.dataStride+c*4,as:Float.self) }
            }
            struct Vertex { var p: SIMD3<Float>; var uv: SIMD2<Float> }
            func original(_ i:Int,_ t:Int)->Vertex {
                let p=SCNVector3(component(positions,i,0),component(positions,i,1),component(positions,i,2))
                let w=node.convertPosition(p,to:nil)
                return Vertex(p:SIMD3<Float>(w.x-cuePosition.x,w.y-cuePosition.y,w.z-cuePosition.z),uv:SIMD2<Float>(component(texture,t,0),component(texture,t,1)))
            }
            func mid(_ a:Vertex,_ b:Vertex)->Vertex { Vertex(p:simd_normalize(a.p+b.p)*r,uv:(a.uv+b.uv)/2) }
            var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],uvs:[CGPoint]=[],elements:[SCNGeometryElement]=[]
            let localCenter=node.convertPosition(cuePosition,from:nil)
            func emit(_ v:Vertex) {
                let w=simd_normalize(v.p)*r
                let local=node.convertPosition(SCNVector3(w.x+cuePosition.x,w.y+cuePosition.y,w.z+cuePosition.z),from:nil)
                let normal=simd_normalize(SIMD3<Float>(local.x-localCenter.x,local.y-localCenter.y,local.z-localCenter.z))
                vertices.append(local);normals.append(SCNVector3(normal));uvs.append(CGPoint(x:CGFloat(v.uv.x),y:CGFloat(v.uv.y)))
            }
            func triangle(_ a:Vertex,_ b:Vertex,_ c:Vertex,_ depth:Int) {
                if depth==0 { emit(a);emit(b);emit(c);return }
                let ab=mid(a,b),bc=mid(b,c),ca=mid(c,a)
                triangle(a,ab,ca,depth-1);triangle(ab,b,bc,depth-1)
                triangle(ca,bc,c,depth-1);triangle(ab,bc,ca,depth-1)
            }
            let channels=old.geometrySourceChannels ?? old.sources.map { _ in NSNumber(value:0) }
            let pc=channels[old.sources.firstIndex(where:{$0.semantic == .vertex})!].intValue
            let tc=channels[old.sources.firstIndex(where:{$0.semantic == .texcoord})!].intValue
            for element in old.elements {
                let start=vertices.count
                guard let faces=try? PocketLeatherMesh.decode(element) else { XCTFail("Ball mesh decoding failed");return }
                let stride=element.indicesChannelCount
                for face in faces {
                    let corners=face.count/stride
                    guard corners>=3 else { continue }
                    func corner(_ i:Int)->Vertex { original(Int(face[i*stride+pc]),Int(face[i*stride+tc])) }
                    for i in 1..<(corners-1) { triangle(corner(0),corner(i),corner(i+1),3) }
                }
                elements.append(SCNGeometryElement(indices:(start..<vertices.count).map(UInt32.init),primitiveType:.triangles))
            }
            var maxVertexError:Float=0,maxFaceSag:Float=0
            var spherePoints:[SIMD3<Float>]=[]
            for vertex in vertices {
                let q=node.convertPosition(vertex,to:nil)
                let relative=SIMD3<Float>(q.x-cuePosition.x,q.y-cuePosition.y,q.z-cuePosition.z)
                spherePoints.append(relative)
                maxVertexError=max(maxVertexError,abs(simd_length(relative)-r))
            }
            for i in Swift.stride(from:0,to:spherePoints.count,by:3) {
                maxFaceSag=max(maxFaceSag,r-simd_length((spherePoints[i]+spherePoints[i+1]+spherePoints[i+2])/3))
            }
            XCTAssertLessThan(maxVertexError,0.000001)
            XCTAssertLessThan(maxFaceSag,0.00002)
            print("ROUNDNESS ERROR meters",maxVertexError,"triangle centroid sag",maxFaceSag)
            let refined=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uvs)],elements:elements)
            refined.materials=old.materials;refined.name=old.name
            node.geometry=refined
            print("REFINED BALL",positions.vectorCount,"->",vertices.count,"radius",r)
        }
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY:scene.surfaceY)[5]
        let distance = hypot(pocket.x-cuePosition.x,pocket.z-cuePosition.z)
        let dx = (pocket.x-cuePosition.x)/distance, dz = (pocket.z-cuePosition.z)/distance
        guard case .angle(let autoElevation) = CueStick.requiredElevation(
            cueBallPosition:cuePosition,aimDirection:SCNVector3(dx,0,dz)
        ) else { return XCTFail("Cue blocked") }
        let railDistance = AngleSceneCalculator.innerWidth/2
        let elevation = atan2(tan(autoElevation)*railDistance+0.014,railDistance)
        let tilt = simd_quatf(angle:-elevation,axis:SIMD3<Float>(0,0,1))
        func world(_ p:SCNVector3)->SCNVector3 {
            let q = tilt.act(SIMD3<Float>(p.x,p.y-center.y,p.z))
            return SCNVector3(cuePosition.x+dx*q.x-dz*q.z,center.y+q.y,cuePosition.z+dz*q.x+dx*q.z)
        }
        let yaw = -atan2(dz,dx)
        camera.position = SCNVector3(0,scene.surfaceY+eyeHeight,-0.65)
        camera.look(at:SCNVector3(-0.12,center.y,0.323),up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
        scene.showBall(key:"_8",scenePosition:SCNVector3(0,center.y,0.38))
        insetCamera.position = SCNVector3(0.30,center.y,0)
        insetCamera.look(at:SCNVector3(0,center.y,0),up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))

        SCNTransaction.commit(); SCNTransaction.flush()
        let rasterSize = CGSize(width: 2160, height: 2880)
        let movie = (env["CUE_TIP_MOVIE"] ?? env["TEST_RUNNER_CUE_TIP_MOVIE"]) == "1"
        let fps = 60, frameCount = 600
        let writer = movie ? try VideoWriter(url: out.appendingPathComponent("cue-tip-preview.mp4"), size: size, fps: fps) : nil
        var states: [(String,String,Float)] = [("high","高杆",0.014)]
        if movie {
            states = (0..<frameCount).map { i in
                let t = Double(i)/Double(fps)
                func ease(_ u: Double) -> Double { let x=max(0,min(1,u));return x*x*(3-2*x) }
                let height: Float
                if t < 4 { height = Float(0.014*(1-ease((t-1)/3))) }
                else if t < 5 { height = 0 }
                else { height = Float(-0.014*ease((t-5)/3)) }
                return (String(format:"frame-%04d",i),abs(height)<0.00001 ? "中杆" : (height>0 ? "高杆" : "低杆"),height)
            }
        }
        var records: [[String:Any]] = []
        for (frame, state) in states.enumerated() {
            let (name,title,h) = state
            stick.update(cueBallPosition: SCNVector3(center.x,center.y+h,center.z), aimDirection: SCNVector3(1,0,0), elevation: 0)
            stick.show(); SCNTransaction.flush()
            var shift = Float.infinity
            var closest = SCNVector3Zero
            var count = 0
            var meshPoints: [SCNVector3] = []
            // For translation toward +X, the first mesh vertex to reach the sphere
            // minimizes x_left(sphere cross section)-x_vertex. No physics changes.
            stick.rootNode.enumerateChildNodes { node, _ in
                guard let source = node.geometry?.sources(for: .vertex).first,
                      source.usesFloatComponents, source.bytesPerComponent == 4 else { return }
                source.data.withUnsafeBytes { bytes in
                    for i in 0..<source.vectorCount {
                        let offset = source.dataOffset+i*source.dataStride
                        let x = bytes.loadUnaligned(fromByteOffset: offset, as: Float.self)
                        let y = bytes.loadUnaligned(fromByteOffset: offset+4, as: Float.self)
                        let z = bytes.loadUnaligned(fromByteOffset: offset+8, as: Float.self)
                        let p = node.convertPosition(SCNVector3(x,y,z), to: nil)
                        meshPoints.append(p)
                    }
                }
            }
            // The asset's total bounding box is not its shaft centerline. Center the
            // symmetric front cap cross-section for the requested physical axis height.
            let frontX = try XCTUnwrap(meshPoints.map(\.x).max())
            let cap = meshPoints.filter { $0.x > frontX-0.003 }
            let capY = (try XCTUnwrap(cap.map(\.y).min()) + XCTUnwrap(cap.map(\.y).max()))/2
            let capZ = (try XCTUnwrap(cap.map(\.z).min()) + XCTUnwrap(cap.map(\.z).max()))/2
            let adjustY = center.y+h-capY, adjustZ = center.z-capZ
            stick.rootNode.position.y += adjustY; stick.rootNode.position.z += adjustZ
            for raw in meshPoints {
                let p = SCNVector3(raw.x,raw.y+adjustY,raw.z+adjustZ)
                let dy = p.y-center.y, dz = p.z-center.z
                let radial = dy*dy+dz*dz
                if radial < r*r {
                    let delta = center.x-sqrt(r*r-radial)-p.x
                    if delta < shift { shift = delta; closest = p }
                    count += 1
                }
            }
            // Interpolate the actual meridian profile between mesh rings so the
            // contact marker moves continuously instead of hopping vertex to vertex.
            let profile = meshPoints.map { SCNVector3($0.x,$0.y+adjustY,$0.z+adjustZ) }
                .filter { abs($0.z-center.z)<0.00002 && $0.x>frontX-0.002 }
                .sorted { $0.y < $1.y }
            for (u,v) in zip(profile,profile.dropFirst()) where v.y-u.y>0.0000001 {
                func candidate(_ t:Float) -> (Float,SCNVector3) {
                    let p=SCNVector3(u.x+(v.x-u.x)*t,u.y+(v.y-u.y)*t,center.z)
                    let dy=p.y-center.y
                    return (center.x-sqrt(max(0,r*r-dy*dy))-p.x,p)
                }
                var lo:Float=0,hi:Float=1
                for _ in 0..<24 {
                    let a=lo+(hi-lo)/3,b=hi-(hi-lo)/3
                    if candidate(a).0<candidate(b).0 { hi=b } else { lo=a }
                }
                let result=candidate((lo+hi)/2)
                if result.0<shift { shift=result.0;closest=result.1 }
            }
            XCTAssertGreaterThan(count, 100); XCTAssertTrue(shift.isFinite)
            stick.rootNode.position.x += shift
            let contact = SCNVector3(closest.x+shift,closest.y,closest.z)
            let axis = SCNVector3(center.x-sqrt(r*r-h*h),center.y+h,center.z)
            let sphereDistance = sqrt(pow(contact.x-center.x,2)+pow(contact.y-center.y,2)+pow(contact.z-center.z,2))
            XCTAssertEqual(sphereDistance,r,accuracy:0.00001)
            // The mesh has an almost-flat apex: contact can equal axis height near
            // center. World-Y addition/subtraction introduces up to two Float ULPs.
            if abs(h)>0.0001 { XCTAssertLessThanOrEqual(abs(contact.y-center.y),abs(h)+2*center.y.ulp) }
            else { XCTAssertLessThan(abs(contact.y-center.y),0.0001) }
            stick.rootNode.position=world(stick.rootNode.position)
            stick.rootNode.simdOrientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0,1,0))*tilt*stick.rootNode.simdOrientation
            var railSamples = 0
            for p in meshPoints {
                let q = world(SCNVector3(p.x+shift,p.y+adjustY,p.z+adjustZ))
                let surfaceDistance = sqrt(pow(q.x-cuePosition.x,2)+pow(q.y-cuePosition.y,2)+pow(q.z-cuePosition.z,2))
                XCTAssertGreaterThanOrEqual(surfaceDistance,r-0.00001,"Cue mesh must not penetrate the ball")
                if q.z <= -AngleSceneCalculator.innerWidth/2 && q.z >= -AngleSceneCalculator.innerWidth/2-0.20 {
                    railSamples += 1
                    XCTAssertGreaterThan(q.y,scene.surfaceY+0.038)
                }
            }
            XCTAssertGreaterThan(railSamples,0)
            SCNTransaction.flush()
            if !movie || frame == 0 {
                for t in 0..<3 { _ = renderer.snapshot(atTime: Double(t)/60, with: rasterSize, antialiasingMode: .multisampling4X) }
            }
            let raw = renderer.snapshot(atTime: movie ? Double(frame)/Double(fps)+1 : 1, with: rasterSize, antialiasingMode: .multisampling4X)
            if !movie { try XCTUnwrap(raw.pngData()).write(to: out.appendingPathComponent("\(name)-clean.png")) }
            func pixel(_ p: SCNVector3) -> CGPoint {
                let q = renderer.projectPoint(p)
                return CGPoint(x: CGFloat(q.x)/2,y:size.height-CGFloat(q.y)/2)
            }
            let detail = insetRenderer.snapshot(atTime:Double(frame)/Double(fps)+1,with:insetSize,antialiasingMode:.multisampling4X)
            func detailPixel(_ p:SCNVector3)->CGPoint {
                let q=insetRenderer.projectPoint(world(p))
                return CGPoint(x:insetBox.minX+CGFloat(q.x)/2,y:insetBox.maxY-CGFloat(q.y)/2)
            }
            let a = detailPixel(axis), b = detailPixel(contact)
            XCTAssertTrue(insetBox.insetBy(dx:15,dy:15).contains(a))
            XCTAssertTrue(insetBox.insetBy(dx:15,dy:15).contains(b))
            let mainCue=renderer.projectPoint(cueNode.position)
            XCTAssertFalse(insetBox.insetBy(dx:-25,dy:-25).contains(CGPoint(x:CGFloat(mainCue.x)/2,y:size.height-CGFloat(mainCue.y)/2)))
            XCTAssertFalse(insetBox.insetBy(dx:-70,dy:-45).contains(pixel(pocket)), "Inset must leave target pocket clear")
            XCTAssertEqual(cueNode.position.z,cuePosition.z,accuracy:0.00001)
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1;fmt.opaque = true
            let image = UIGraphicsImageRenderer(size:size,format:fmt).image { context in
                UIColor.black.setFill();context.fill(CGRect(origin:.zero,size:size));raw.draw(in:CGRect(origin:.zero,size:size))
                let amber=UIColor(red:1,green:0.8,blue:0.2,alpha:1)
                let coral=UIColor(red:1,green:0.3,blue:0.25,alpha:1)
                let cg=context.cgContext
                cg.saveGState()
                UIBezierPath(roundedRect:insetBox,cornerRadius:18).addClip()
                detail.draw(in:insetBox)
                // At ball-height side view the table underside sits below the
                // silhouette. Give the contact label a quiet footer in that area.
                UIColor(white:0.16,alpha:1).setFill()
                cg.fill(CGRect(x:insetBox.minX,y:insetBox.maxY-128,width:insetBox.width,height:128))
                cg.restoreGState()
                UIColor.white.withAlphaComponent(0.65).setStroke()
                let border=UIBezierPath(roundedRect:insetBox,cornerRadius:18);border.lineWidth=2;border.stroke()
                cg.setStrokeColor(amber.cgColor);cg.setLineWidth(2);cg.setLineDash(phase:0,lengths:[12,9]);cg.move(to:detailPixel(SCNVector3(-0.07,center.y+h,0)));cg.addLine(to:a);cg.strokePath();cg.setLineDash(phase:0,lengths:[])
                for (p,color,text) in [(a,amber,"杆头所指点"),(b,coral,"实际接触点")] {
                    let anchor = CGPoint(x:insetBox.minX+25,y:text == "杆头所指点" ? insetBox.minY+55 : insetBox.maxY-annotationFont*1.2-24)
                    cg.setStrokeColor(color.cgColor);cg.setLineWidth(1)
                    cg.move(to:p);cg.addLine(to:CGPoint(x:anchor.x+annotationFont*5,y:anchor.y+annotationFont*1.2+4));cg.addLine(to:CGPoint(x:anchor.x,y:anchor.y+annotationFont*1.2+4));cg.strokePath()
                    let shadow=NSShadow();shadow.shadowColor=UIColor.black.withAlphaComponent(0.7);shadow.shadowBlurRadius=5
                    (text as NSString).draw(at:anchor,withAttributes:[.font:UIFont.systemFont(ofSize:annotationFont,weight:.semibold),.foregroundColor:color,.shadow:shadow])
                    color.setFill()
                    UIBezierPath(ovalIn:CGRect(x:p.x-2,y:p.y-2,width:4,height:4)).fill()
                }
            }
            if let writer { try writer.append(XCTUnwrap(image.cgImage)) }
            if !movie || [0,240,300,599].contains(frame) {
                try XCTUnwrap(image.pngData()).write(to: out.appendingPathComponent("\(name)-video-frame.png"))
            }
            if movie && frame % 60 == 0 { print("CUE TIP VIDEO: \(frame)/\(frameCount)") }
            records.append(["frame":name,"axisHeight":h,"contactHeight":contact.y-center.y,"elevationRadians":elevation,"meshCandidates":count,"contactResidual":sphereDistance-r,"axisPixel":[a.x,a.y],"contactPixel":[b.x,b.y]])
        }
        if let writer { try await writer.finish() }
        XCTAssertEqual(records.count, movie ? frameCount : 1)
        try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("geometry.json"))
    }
}
