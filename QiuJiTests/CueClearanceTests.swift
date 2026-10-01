//
//  CueClearanceTests.swift
//  QiuJiTests
//
//  Geometry / clearance unit tests for cue elevation, collision guard,
//  follow-through clamp. Evidence drafts: build/cue-clearance-evidence/
//
//  Run:
//    xcodebuild test -scheme QiuJi \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//      -only-testing:QiuJiTests/CueClearanceTests
//

import XCTest
import SceneKit
import SwiftUI
@testable import QiuJi

final class CueClearanceTests: XCTestCase {

    private let r = AngleSceneCalculator.ballRadius
    private let y: Float = 0.8286  // tableSurfaceY + R

    // MARK: - A. Elevation / occlusion

    /// Rear ball clearance must hold on the shaft surface throughout the stroke.
    func test_elevation_ballSixCmBehind() {
        let cue = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)  // back = −X
        let obstacle = SCNVector3(-0.06, y, 0)
        let result = CueStick.requiredElevation(
            cueBallPosition: cue, aimDirection: aim, obstacleCenters: [obstacle]
        )
        guard case .angle(let elev) = result else {
            return XCTFail("expected angle, got blocked")
        }
        assertClearsBall(pivot: cue, aim: aim, elevation: elev, obstacle: obstacle)
        XCTAssertGreaterThan(elev, CueStick.minElevationRadians)
        XCTAssertLessThan(elev, CueStick.maxElevationRadians)
    }

    /// Lateral 10 cm at s=6 cm → no ball occlusion → cushion/min baseline.
    func test_elevation_farLateralNoOcclusion() {
        let cue = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let obstacle = SCNVector3(-0.06, y, 0.10)
        let withBall = CueStick.requiredElevation(
            cueBallPosition: cue, aimDirection: aim, obstacleCenters: [obstacle]
        )
        let baseline = CueStick.requiredElevation(
            cueBallPosition: cue, aimDirection: aim, obstacleCenters: []
        )
        XCTAssertEqual(withBall, baseline, "far lateral must not raise elevation")
    }

    /// A centre strike with a touching ball behind still fits below the 60° cap.
    func test_elevation_legalTouchingBehind_belowSixty() {
        let cue = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let obstacle = SCNVector3(-2 * r, y, 0)  // legal touching behind
        let result = CueStick.requiredElevation(
            cueBallPosition: cue, aimDirection: aim, obstacleCenters: [obstacle]
        )
        guard case .angle(let elev) = result else {
            return XCTFail("legal touching-behind must not block; got \(result)")
        }
        assertClearsBall(pivot: cue, aim: aim, elevation: elev, obstacle: obstacle)
        XCTAssertLessThan(elev, CueStick.maxElevationRadians)
    }

    /// Synthetic overlapping centres (s=0.02 < 2R) → elev > 60° → `.blocked`.
    ///
    /// **Not a legal layout**: centre distance 2 cm ≪ 2R = 5.715 cm (balls would interpenetrate).
    /// This case exercises the defensive branch without a legal-layout assumption.
    func test_elevation_closeObstacleBlocked() {
        let cue = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let obstacle = SCNVector3(-0.02, y, 0)
        let result = CueStick.requiredElevation(
            cueBallPosition: cue, aimDirection: aim, obstacleCenters: [obstacle]
        )
        XCTAssertEqual(result, .blocked)
    }

    private func assertClearsBall(pivot: SCNVector3, aim: SCNVector3, elevation: Float,
                                  obstacle: SCNVector3, file: StaticString = #filePath, line: UInt = #line) {
        for pull in [CueStroke.followThroughPull, Float(0), 0.15, 0.4] {
            // Use the most-forward allowed inset, independently sample the rendered shaft.
            let segment = CueClearance.shaftSegment(strikePosition: pivot, aimDirection: aim,
                elevation: elevation, pullBack: pull - r)
            for i in 0...200 {
                let u = Float(i) / 200
                let p = SCNVector3(segment.tip.x + (segment.butt.x-segment.tip.x)*u,
                                   segment.tip.y + (segment.butt.y-segment.tip.y)*u,
                                   segment.tip.z + (segment.butt.z-segment.tip.z)*u)
                let distance = sqrtf(powf(p.x-obstacle.x,2)+powf(p.y-obstacle.y,2)+powf(p.z-obstacle.z,2))
                XCTAssertGreaterThanOrEqual(distance, r + CueClearance.shaftRadius(alongShaftU:u), file:file,line:line)
            }
        }
    }

    func testLowStrikeRaisesCueAndClearsRearBallThroughoutStroke() throws {
        let aim = SCNVector3(1,0,0), obstacle = SCNVector3(-2*r,y,0)
        var previous: Float = 0
        for spin in [0.5, 0, -0.5] {
            let pivot = CueStroke.strikePosition(cue:SCNVector3(0,y,0),aim:aim,spinX:0,spinY:spin)
            let angle = try XCTUnwrap(CueStick.requiredElevation(cueBallPosition:pivot,
                aimDirection:aim,obstacleCenters:[obstacle]).radians)
            XCTAssertGreaterThan(angle,previous)
            assertClearsBall(pivot:pivot,aim:aim,elevation:angle,obstacle:obstacle)
            previous=angle
        }
    }

    func testNearRailSpinAndObliqueStrokeMatrix() throws {
        var minimumGap = Float.infinity
        var cases = 0
        for side in 0..<4 {
            for distance: Float in [r,0.03,0.05,0.1] {
                for spin in [-0.5,0,0.5] {
                    for degrees: Float in [-80,-45,0,45,80] {
                        let a=degrees * .pi/180
                        let aim: SCNVector3
                        let cue: SCNVector3
                        switch side {
                        case 0: cue=SCNVector3(-1.27+distance,y,0.2); aim=SCNVector3(cosf(a),0,sinf(a))
                        case 1: cue=SCNVector3(1.27-distance,y,0.2); aim=SCNVector3(-cosf(a),0,sinf(a))
                        case 2: cue=SCNVector3(0.3,y,-0.635+distance); aim=SCNVector3(sinf(a),0,cosf(a))
                        default: cue=SCNVector3(0.3,y,0.635-distance); aim=SCNVector3(sinf(a),0,-cosf(a))
                        }
                        let pivot=CueStroke.strikePosition(cue:cue,aim:aim,spinX:0,spinY:spin)
                        let elevation=try XCTUnwrap(CueStick.requiredElevation(cueBallPosition:pivot,aimDirection:aim).radians)
                        let inset=CueStroke.tipInset(spinX:0,spinY:spin)
                        for pull in [CueStroke.followThroughPull,Float(0),0.15,0.4] {
                            let segment=CueClearance.shaftSegment(strikePosition:pivot,aimDirection:aim,
                                elevation:elevation,pullBack:pull-inset)
                            for i in 0...200 {
                                let u=Float(i)/200
                                let p=SCNVector3(segment.tip.x+(segment.butt.x-segment.tip.x)*u,
                                    segment.tip.y+(segment.butt.y-segment.tip.y)*u,
                                    segment.tip.z+(segment.butt.z-segment.tip.z)*u)
                                let radius=CueClearance.shaftRadius(alongShaftU:u)+0.001
                                // Euclidean distance to each closed rail solid, not the solver's angle formula.
                                for gap in [1.27-p.x,1.27+p.x,0.635-p.z,0.635+p.z] as [Float] {
                                    let d=hypotf(max(0,gap),max(0,p.y-(0.8+0.038)))-radius
                                    minimumGap=min(minimumGap,d)
                                }
                            }
                        }
                        cases += 1
                    }
                }
            }
        }
        XCTAssertGreaterThanOrEqual(minimumGap,0)
        print("[CueRailMatrix] cases=\(cases), minimum surface gap=\(minimumGap*1000) mm")
    }

    func testRailHeightTranslationAndSubFiveCentimetreResponse() throws {
        let aim=SCNVector3(1,0,0)
        func angle(_ distance: Float,_ surface: Float) throws -> Float {
            try XCTUnwrap(CueStick.requiredElevation(
                cueBallPosition:SCNVector3(-1.27+distance,surface+r*0.5,0),
                aimDirection:aim,surfaceY:surface).radians)
        }
        XCTAssertGreaterThan(try angle(0.03,0.8),try angle(0.05,0.8))
        XCTAssertEqual(try angle(0.03,0.8),try angle(0.03,1.2),accuracy:1e-5)
    }

    func testElevatedFollowThroughStopsAboveCloth() throws {
        let aim=SCNVector3(1,0,0)
        for spin in [-0.5,0,0.5] {
            for angle: Float in [0.05,0.4,0.8,1.0471976] {
                let strike=CueStroke.strikePosition(cue:SCNVector3(0,y,0),aim:aim,spinX:0,spinY:spin)
                let inset=CueStroke.tipInset(spinX:0,spinY:spin)
                let end=CueStroke.clampedFollowThroughPull(cueBallPosition:strike,aimDirection:aim,
                    obstacleCenters:[],elevation:angle,tipInset:inset,surfaceY:0.8)
                XCTAssertGreaterThanOrEqual(end,CueStroke.followThroughPull)
                XCTAssertLessThanOrEqual(end,0)
                for i in 0...100 {
                    let pull=CueStroke.followThrough(at:Double(i)/100*CueStroke.followThroughDuration,endPull:end)
                    let segment=CueClearance.shaftSegment(strikePosition:strike,aimDirection:aim,
                        elevation:angle,pullBack:pull-inset)
                    XCTAssertGreaterThan(segment.tip.y-CueClearance.tipRadius,0.8)
                }
            }
        }
    }

    @MainActor
    func testLoadedCueNearRailGeometryAndSnapshots() throws {
        let scene=AngleTrainingScene()
        scene.configureDailyClearanceRendering()
        scene.setupScene()
        scene.setCameraMode(.perspective3D,animated:false)
        scene.hideAllBalls()
        let camera=SCNNode(); camera.camera=SCNCamera()
        camera.camera?.fieldOfView=36; camera.camera?.zNear=0.001
        scene.rootNode.addChildNode(camera)
        let renderer=SCNRenderer(device:nil,options:nil)
        renderer.scene=scene;renderer.pointOfView=camera
        let aim=SCNVector3(1,0,0)
        var minimumGap=Float.infinity
        for distance: Float in [0.03,0.05] {
            let cue=SCNVector3(-1.27+distance,scene.surfaceY+r,0.2)
            scene.showBall(key:PositionPlayBall.cueKey,scenePosition:cue)
            let strike=CueStroke.strikePosition(cue:cue,aim:aim,spinX:0,spinY:-0.5)
            let elevation=try XCTUnwrap(CueStick.requiredElevation(cueBallPosition:strike,
                aimDirection:aim,surfaceY:scene.surfaceY).radians)
            let endPull=CueStroke.clampedFollowThroughPull(cueBallPosition:strike,aimDirection:aim,
                obstacleCenters:[],elevation:elevation,tipInset:scene.cueTipInset(forStrike:strike) ?? 0,
                surfaceY:scene.surfaceY)
            for pull: Float in [0,0.15,endPull] {
                scene.updateCueStick(cueBallPosition:strike,aimDirection:aim,pullBack:pull,elevationOverride:elevation)
                let stick=try XCTUnwrap(scene.cueStick)
                XCTAssertFalse(stick.rootNode.isHidden)
                var vertices=0
                stick.rootNode.enumerateHierarchy { node,_ in
                    for source in node.geometry?.sources(for:.vertex) ?? [] {
                        guard source.usesFloatComponents,source.bytesPerComponent==4 else { continue }
                        source.data.withUnsafeBytes { bytes in
                            for i in 0..<source.vectorCount {
                                let offset=source.dataOffset+i*source.dataStride
                                let point=SCNVector3(bytes.loadUnaligned(fromByteOffset:offset,as:Float.self),
                                    bytes.loadUnaligned(fromByteOffset:offset+4,as:Float.self),
                                    bytes.loadUnaligned(fromByteOffset:offset+8,as:Float.self))
                                let p=node.convertPosition(point,to:scene.rootNode)
                                if p.x <= -1.27 { minimumGap=min(minimumGap,p.y-(scene.surfaceY+0.038)) }
                                XCTAssertGreaterThan(p.y,scene.surfaceY,"Loaded cue must not enter cloth")
                                vertices += 1
                            }
                        }
                    }
                }
                XCTAssertGreaterThan(vertices,100,"Must check the bundled cue mesh")
                camera.position=SCNVector3(-1.17,scene.surfaceY+0.24,0.73)
                camera.look(at:SCNVector3(-1.30,scene.surfaceY+0.12,0.2),
                            up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
                SCNTransaction.flush()
                let image=renderer.snapshot(atTime:0,with:CGSize(width:900,height:700),antialiasingMode:.multisampling4X)
                let attachment=XCTAttachment(image:image)
                attachment.name="low-rail-\(Int(distance*1000))mm-pull-\(Int(pull*1000))mm"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        XCTAssertGreaterThan(minimumGap,0)
        print("[LoadedCueRail] minimum vertex gap=\(minimumGap*1000) mm")
    }

    func testStrikeAccessDependsOnDirectionAndRestrictsLowPoints() throws {
        let near=CueStrikeAccess(cue:SCNVector3(-1.21,0.8+r,0.2),aim:SCNVector3(1,0,0),obstacles:[],surfaceY:0.8)
        XCTAssertFalse(near.isAvailable(spinX:0,spinY:-0.5))
        XCTAssertTrue(near.isAvailable(spinX:0,spinY:0.5))
        let along=CueStrikeAccess(cue:near.cue,aim:SCNVector3(0,0,1),obstacles:[],surfaceY:0.8)
        XCTAssertTrue(along.isAvailable(spinX:0,spinY:-0.5),"Near a rail alone is not a ban")
        let far=CueStrikeAccess(cue:SCNVector3(0,0.8+r,0),aim:near.aim,obstacles:[],surfaceY:0.8)
        XCTAssertTrue(far.isAvailable(spinX:0,spinY:-0.5))
        XCTAssertFalse(near.isAvailable(spinX:0,spinY:0.6))
        let tight=CueStrikeAccess(cue:SCNVector3(-1.24,0.8+r,0.2),aim:near.aim,obstacles:[],surfaceY:0.8)
        XCTAssertFalse(tight.isAvailable(spinX:0,spinY:-0.5),"Frozen low spin remains unavailable")
        let high=try XCTUnwrap(tight.constrained(spinX:0,spinY:-0.5))
        XCTAssertGreaterThan(high.y,-0.5,"Frozen low spin must be corrected to a reachable contact")
        XCTAssertTrue(tight.isAvailable(spinX:high.x,spinY:high.y))
        let blocked=CueStrikeAccess(cue:far.cue,aim:far.aim,
            obstacles:[SCNVector3(-0.07,far.cue.y,0)],surfaceY:0.8)
        XCTAssertFalse(blocked.isAvailable(spinX:0,spinY:-0.5),"A ball behind the cue also limits low spin")
        let constrained=try XCTUnwrap(near.constrained(spinX:0,spinY:-0.5))
        XCTAssertTrue(near.isAvailable(spinX:constrained.x,spinY:constrained.y))
        XCTAssertGreaterThan(constrained.y,-0.5)
        XCTAssertNil(near.resolvedPose(spinX:0,spinY:-0.5))
    }

    func testThirtyDegreeAccessAndAutomaticProjection() throws {
        let room=CueStrikeAccess(cue:SCNVector3(-1.17,0.8+r,0.2),aim:SCNVector3(1,0,0),obstacles:[],surfaceY:0.8)
        let low=try XCTUnwrap(room.resolvedPose(spinX:0,spinY:-0.5))
        XCTAssertGreaterThan(low.elevation,15 * .pi/180)
        XCTAssertLessThan(low.elevation,30 * .pi/180)
        XCTAssertEqual(room.constrained(spinX:0,spinY:-0.5)?.y,-0.5)
        let near=CueStrikeAccess(cue:SCNVector3(-1.225,0.8+r,0.2),aim:room.aim,obstacles:[],surfaceY:0.8)
        XCTAssertTrue(near.isAvailable(spinX:0,spinY:0),"Do not reject a reachable raised-cue centre contact")
        XCTAssertFalse(near.isAvailable(spinX:0,spinY:-0.5))
        let automatic=try XCTUnwrap(near.constrained(spinX:0,spinY:-0.5))
        XCTAssertTrue(near.isAvailable(spinX:automatic.x,spinY:automatic.y))
        XCTAssertGreaterThan(automatic.y,-0.5)
        let tightSide=CueStrikeAccess(cue:SCNVector3(0,0.8+r,0),aim:room.aim,
            obstacles:[SCNVector3(-0.03,0.8+r,-sqrtf(4*r*r-0.03*0.03))],surfaceY:0.8)
        XCTAssertFalse(tightSide.isAvailable(spinX:0.5,spinY:0))
        let side=try XCTUnwrap(tightSide.constrained(spinX:0.5,spinY:0))
        XCTAssertTrue(tightSide.isAvailable(spinX:side.x,spinY:side.y))
        XCTAssertLessThan(abs(side.x),0.5)
        XCTAssertEqual(near.constrained(spinX:automatic.x,spinY:automatic.y)?.y,automatic.y)
        // Lateral separation is real clearance, not a head-on obstacle.
        let lateral=CueStrikeAccess(cue:SCNVector3(0,0.8+r,0),aim:room.aim,
            obstacles:[SCNVector3(-0.07,0.8+r,0.043)],surfaceY:0.8)
        XCTAssertTrue(lateral.isAvailable(spinX:0,spinY:0))
    }

    func testAutomaticDefaultBalancesElevationWithoutChangingValidSelection() throws {
        let access=CueStrikeAccess(cue:SCNVector3(-1.225,0.8+r,0.2),aim:SCNVector3(1,0,0),obstacles:[],surfaceY:0.8)
        let nearest=try XCTUnwrap(access.constrained(spinX:0,spinY:-0.5))
        let chosen=try XCTUnwrap(access.automaticPoint(spinX:0,spinY:-0.5))
        let boundary=try XCTUnwrap(access.resolvedPose(spinX:nearest.x,spinY:nearest.y))
        let preferred=try XCTUnwrap(access.resolvedPose(spinX:chosen.x,spinY:chosen.y))
        XCTAssertLessThan(preferred.elevation,boundary.elevation-0.01)
        XCTAssertEqual(access.automaticPoint(spinX:chosen.x,spinY:chosen.y)?.y,chosen.y)
        XCTAssertEqual(access.automaticPoint(spinX:0,spinY:0.5)?.y,0.5)
    }

    @MainActor
    func testAutomaticCorrectionUpdatesPredictionAndCue() async throws {
        let vm=PositionPlayViewModel();vm.setupScene()
        vm.loadBoard(BoardSnapshot(onTable:[PositionPlayBall.cueKey:CanvasPoint(x:0.06/2.54,y:0.25),
            "_1":CanvasPoint(x:0.6,y:0.25)]))
        vm.spinY = -0.5
        for _ in 0..<200 {
            if !vm.isComputing, vm.solvedShot != nil, vm.spinY > -0.5 { break }
            try await Task.sleep(nanoseconds:50_000_000)
        }
        let solved=try XCTUnwrap(vm.solvedShot)
        XCTAssertGreaterThan(vm.spinY,-0.5)
        XCTAssertEqual(solved.shot.spinX,vm.spinX,accuracy:1e-8)
        XCTAssertEqual(solved.shot.spinY,vm.spinY,accuracy:1e-8)
        XCTAssertFalse(try XCTUnwrap(vm.scene.cueStick).rootNode.isHidden)
        let access=try XCTUnwrap(vm.scene.cueAccessSnapshot)
        XCTAssertTrue(access.isAvailable(spinX:vm.spinX,spinY:vm.spinY))
    }

    func testAccessiblePoseKeepsSelectedContactAndClearsRails() throws {
        var count=0
        for distance: Float in [0.03,0.05,0.1,0.2,0.4] {
            let context=CueStrikeAccess(cue:SCNVector3(-1.27+distance,0.8+r,0.2),
                aim:SCNVector3(1,0,0),obstacles:[],surfaceY:0.8)
            for x in stride(from:-0.4,through:0.4,by:0.1) {
                for y in stride(from:-0.4,through:0.4,by:0.1) {
                    guard let pose=context.resolvedPose(spinX:x,spinY:y) else { continue }
                    XCTAssertLessThanOrEqual(pose.elevation,CueStrikeAccess.maximumElevation)
                    let stick=CueStick()
                    stick.update(cueBallPosition:pose.pivot,aimDirection:context.aim,
                        elevation:pose.elevation,tipInset:pose.inset)
                    let tip=stick.rootNode.convertPosition(SCNVector3(0,0,CueClearance.tipOffset-pose.inset),to:nil)
                    let back=SCNVector3(-cosf(pose.elevation),sinf(pose.elevation),0)
                    let n=SCNVector3((pose.contact.x-context.cue.x)/r,(pose.contact.y-context.cue.y)/r,(pose.contact.z-context.cue.z)/r)
                    let rho=CuePhysics.tipCurvatureRadius
                    XCTAssertEqual(tip.y,pose.contact.y+rho*(n.y-back.y)+0.0001*back.y,accuracy:1e-6)
                    XCTAssertEqual(tip.z,pose.contact.z+rho*n.z,accuracy:1e-6)
                    let contact=pose.contact
                    XCTAssertEqual(sqrtf(powf(contact.x-context.cue.x,2)+powf(contact.y-context.cue.y,2)+powf(contact.z-context.cue.z,2)),r,accuracy:1e-6)
                    for i in 0...300 {
                        let t=Float(i)/300*CueClearance.shaftLength
                        let point=stick.rootNode.convertPosition(SCNVector3(0,0,CueClearance.tipOffset-pose.inset+t),to:nil)
                        let gap=hypotf(max(0,point.x+1.27),max(0,point.y-(context.surfaceY+BTTablePhysics.cushionHeight)))
                        XCTAssertGreaterThan(gap,CueClearance.shaftRadius(alongShaftU:Float(i)/300))
                    }
                    count += 1
                }
            }
        }
        XCTAssertGreaterThan(count,50)
        print("[CueAccess] verified accessible poses=\(count)")
    }

    @MainActor
    func testAimAndStrokeKeepSameAccessibleContact() throws {
        let scene=AngleTrainingScene();scene.setupScene();scene.hideAllBalls()
        let cue=SCNVector3(-1.07,scene.surfaceY+r,0.2),aim=SCNVector3(1,0,0)
        scene.showBall(key:PositionPlayBall.cueKey,scenePosition:cue)
        let strike=CueStroke.strikePosition(cue:cue,aim:aim,spinX:0.2,spinY:-0.2)
        scene.updateCueStick(cueBallPosition:strike,aimDirection:aim)
        let stick=try XCTUnwrap(scene.cueStick)
        XCTAssertFalse(stick.rootNode.isHidden)
        let address=stick.rootNode.position,rotation=stick.rootNode.eulerAngles
        scene.runCueStroke(strikePosition:strike,aim:aim,velocity:1.5,onContact:{})
        XCTAssertEqual(stick.rootNode.position.x,address.x,accuracy:1e-6)
        XCTAssertEqual(stick.rootNode.position.y,address.y,accuracy:1e-6)
        XCTAssertEqual(stick.rootNode.eulerAngles.x,rotation.x,accuracy:1e-6)
        scene.hideCueStick()
        XCTAssertNil(scene.cueAccessSnapshot)
    }

    @MainActor
    func testMinimumElevationForHighRailContacts() throws {
        let scene=AngleTrainingScene();scene.setupScene();scene.hideAllBalls()
        let stick=try XCTUnwrap(scene.cueStick)
        print("[CueMinimum] profile first=\(stick.clearanceProfile.prefix(4)) last=\(stick.clearanceProfile.suffix(1))")
        for end: Float in [0.01,0.03,0.1,0.5,1.5] {
            print("[CueMinimum] radius before \(end)=\(stick.clearanceProfile.filter{$0.start<end}.map(\.radius).max() ?? 0)")
        }
        for gap: Float in [0,0.005,0.01,0.02,0.04] {
            let cue=SCNVector3(-1.27+r+gap,scene.surfaceY+r,0.2)
            scene.showBall(key:PositionPlayBall.cueKey,scenePosition:cue)
            let access=try XCTUnwrap(scene.cueStrikeAccess(aim:SCNVector3(1,0,0)))
            for spin: Double in [0,0.25,0.5] {
                let solved=access.resolvedPose(spinX:0,spinY:spin)
                if spin == 0.5 { XCTAssertNotNil(solved,"Highest contact must remain feasible at these rail gaps") }
                guard let pose=solved else {
                    print("[CueMinimum] gap=\(gap) spin=\(spin) blocked");continue
                }
                print("[CueMinimum] gap=\(gap) spin=\(spin) degrees=\(pose.elevation*180 / .pi)")
                XCTAssertTrue(access.clears(pose))
                if spin == 0.5 && gap >= 0.005 { XCTAssertLessThan(pose.elevation,8 * .pi/180) }
                // Independent lower-angle sweep catches an earlier feasible region.
                for degrees in stride(from:3.0,to:Double(pose.elevation*180 / .pi)-0.01,by:0.5) {
                    XCTAssertFalse(access.clears(access.pose(spinX:0,spinY:spin,elevation:Float(degrees) * .pi/180)))
                }
                if pose.elevation > CueStick.minElevationRadians+0.0001 {
                    XCTAssertFalse(access.clears(access.pose(spinX:0,spinY:spin,elevation:pose.elevation-0.0001)))
                }
                if spin == 0.5 {
                    scene.updateCueStick(cueBallPosition:CueStroke.strikePosition(cue:cue,aim:access.aim,spinX:0,spinY:spin),aimDirection:access.aim)
                    let camera=SCNNode();camera.camera=SCNCamera();camera.camera?.fieldOfView=38;camera.camera?.zNear=0.001
                    scene.rootNode.addChildNode(camera)
                    camera.position=SCNVector3(-1.45,scene.surfaceY+0.22,0.95)
                    camera.look(at:SCNVector3(-1.4,scene.surfaceY+0.10,0.2),up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
                    let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=scene;renderer.pointOfView=camera
                    SCNTransaction.flush()
                    let shot=renderer.snapshot(atTime:0,with:CGSize(width:1000,height:700),antialiasingMode:.multisampling4X)
                    let attachment=XCTAttachment(image:shot);attachment.name="high-rail-gap-\(Int(gap*1000))mm"
                    attachment.lifetime = .keepAlways;add(attachment)
                    if gap >= 0.005 {
                        // Retained r2 contact envelope, same ball/contact/camera.
                        var lo=CueStick.minElevationRadians,hi=CueStrikeAccess.maximumElevation
                        for _ in 0..<20 {
                            let mid=(lo+hi)/2, old=access.pose(spinX:0,spinY:spin,elevation:(lo+hi)/2)
                            if CueStick.clearsAtElevation(strike:old.pivot,aim:access.aim,obstacles:[],surfaceY:scene.surfaceY,elevation:mid) { hi=mid } else { lo=mid }
                        }
                        let old=access.pose(spinX:0,spinY:spin,elevation:hi)
                        stick.update(cueBallPosition:old.pivot,aimDirection:access.aim,elevation:hi,tipInset:old.inset)
                        SCNTransaction.flush()
                        let before=renderer.snapshot(atTime:0,with:CGSize(width:1000,height:700),antialiasingMode:.multisampling4X)
                        let ref=XCTAttachment(image:before);ref.name="before-high-rail-gap-\(Int(gap*1000))mm"
                        ref.lifetime = .keepAlways;add(ref)
                    }
                    camera.removeFromParentNode()
                }
            }
        }
    }

    @MainActor
    func testThirtyDegreeLoadedMeshAcrossStroke() throws {
        let scene=AngleTrainingScene();scene.setupScene();scene.hideAllBalls()
        var tested=0, minimumGap=Float.infinity
        for distance: Float in [r,r+0.005,r+0.01,0.06,0.075,0.1,0.15] {
            let cue=SCNVector3(-1.27+distance,scene.surfaceY+r,0.2),aim=SCNVector3(1,0,0)
            scene.showBall(key:PositionPlayBall.cueKey,scenePosition:cue)
            let access=try XCTUnwrap(scene.cueStrikeAccess(aim:aim))
            for requestedY: Double in [-0.5,0,0.5] {
                guard let selected=access.constrained(spinX:0,spinY:requestedY) else { continue }
                let pose=try XCTUnwrap(access.resolvedPose(spinX:selected.x,spinY:selected.y))
                let stick=try XCTUnwrap(scene.cueStick)
                let end=CueStroke.clampedFollowThroughPull(cueBallPosition:pose.pivot,aimDirection:aim,
                    obstacleCenters:[],elevation:pose.elevation,tipInset:pose.inset,surfaceY:scene.surfaceY)
                for pull: Float in [0,0.15,0.4,end/2,end] {
                    stick.update(cueBallPosition:pose.pivot,aimDirection:aim,pullBack:pull,
                        elevation:pose.elevation,tipInset:pose.inset)
                    stick.rootNode.enumerateHierarchy { node,_ in
                        for source in node.geometry?.sources(for:.vertex) ?? [] {
                            guard source.usesFloatComponents,source.bytesPerComponent==4 else { continue }
                            source.data.withUnsafeBytes { bytes in
                                for i in 0..<source.vectorCount {
                                    let offset=source.dataOffset+i*source.dataStride
                                    let local=SCNVector3(bytes.loadUnaligned(fromByteOffset:offset,as:Float.self),
                                        bytes.loadUnaligned(fromByteOffset:offset+4,as:Float.self),
                                        bytes.loadUnaligned(fromByteOffset:offset+8,as:Float.self))
                                    let world=node.convertPosition(local,to:scene.rootNode)
                                    if world.x <= -1.27 {
                                        minimumGap=min(minimumGap,world.y-scene.surfaceY-BTTablePhysics.cushionHeight)
                                        XCTAssertGreaterThan(world.y,scene.surfaceY+BTTablePhysics.cushionHeight)
                                    }
                                    XCTAssertGreaterThan(world.y,scene.surfaceY)
                                    tested += 1
                                }
                            }
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(tested,1000)
        XCTAssertGreaterThanOrEqual(minimumGap,CueStrikeAccess.railSurfaceGap-0.00001)
        print("[CueAccess30] actual mesh vertices verified=\(tested), minimum rail gap=\(minimumGap*1000) mm")
    }

    @MainActor
    func testRearTouchingBreakFindsReachableHighContact() throws {
        let scene=AngleTrainingScene();scene.setupScene()
        let runner=BreakFlowRunner(scene:scene,game:.nineBall,seed:42)
        runner.rackUp()
        let cue=try XCTUnwrap(scene.allBallNodes[PositionPlayBall.cueKey])
        cue.position=SCNVector3(0.7,scene.surfaceY+r,0)
        scene.showBall(key:"_15",scenePosition:SCNVector3(0.7+2*r,scene.surfaceY+r,0))
        let access=try XCTUnwrap(scene.cueStrikeAccess(aim:SCNVector3(-1,0,0)))
        XCTAssertFalse(access.isAvailable(spinX:0,spinY:-0.5))
        XCTAssertNotNil(access.resolvedPose(spinX:0,spinY:0.5))
        runner.spinY = -0.5
        runner.breakNow()
        XCTAssertEqual(runner.phase,.computing)
        XCTAssertGreaterThan(runner.spinY,-0.5)
        XCTAssertTrue(access.isAvailable(spinX:runner.spinX,spinY:runner.spinY))
    }

    @MainActor
    func testSpinPadRestrictionVisuals() throws {
        let access=CueStrikeAccess(cue:SCNVector3(-1.21,0.8+r,0.2),aim:SCNVector3(1,0,0),obstacles:[],surfaceY:0.8)
        for restricted in [false,true] {
            let card=BTSpinPadCard(spinX:.constant(0),spinY:.constant(-0.35),tableWidth:264,
                strikeAccess:restricted ? access : nil,usesFixedLayout:true,onClose:{})
            let host=UIHostingController(rootView:card)
            let window=UIWindow(frame:CGRect(x:0,y:0,width:320,height:320))
            window.rootViewController=host;window.makeKeyAndVisible()
            host.view.frame=window.bounds;host.view.backgroundColor = .darkGray
            host.view.setNeedsLayout();host.view.layoutIfNeeded()
            RunLoop.main.run(until:Date().addingTimeInterval(0.15))
            let image=UIGraphicsImageRenderer(bounds:window.bounds).image { _ in
                host.view.drawHierarchy(in:window.bounds,afterScreenUpdates:true)
            }
            let attachment=XCTAttachment(image:image);attachment.name=restricted ? "restricted-spin-pad" : "baseline-spin-pad"
            attachment.lifetime = .keepAlways;add(attachment)
            window.isHidden=true
        }
    }

    // MARK: - B. Collision guard — separation latch

    /// Soft/normal forward departure from the **strike point** must NOT false-trigger.
    /// Uses the same tipOffset vs (R+tipR+margin) envelope that caused the v≲1.4 regression.
    /// Evidence: build/cue-clearance-evidence/rework_latch_draft.txt
    func test_collision_softForward_noFalsePositive() {
        let strike = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let elev: Float = 0.05
        let endPull = CueStroke.followThroughPull
        let velocities: [Float] = [0.4, 0.6, 0.8, 1.0, 1.2, 1.5, 2.0, 3.0]
        for v in velocities {
            let tStar = CueClearance.firstCollisionTime(
                strikePosition: strike,
                aimDirection: aim,
                elevation: elev,
                endPull: endPull,
                holdDuration: 1.5,
                ballsAt: { t in
                    // Cue starts at strike (τ=0 contact envelope) and coasts +aim then stops.
                    ["cue": Self.ballForwardThenStop(t: t, v: v, y: self.y)]
                }
            )
            XCTAssertNil(tStar, "v=\(v) forward-only must not false-trigger (separation latch)")
        }
    }

    /// After separating forward, cue draws back into the held shaft → non-nil t*.
    func test_collision_drawBackAfterSeparate_captured() {
        let strike = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let elev: Float = 0.05
        let tStar = CueClearance.firstCollisionTime(
            strikePosition: strike,
            aimDirection: aim,
            elevation: elev,
            endPull: CueStroke.followThroughPull,
            holdDuration: 1.5,
            ballsAt: { t in
                ["cue": Self.ballDrawBack(t: t, y: self.y)]
            }
        )
        XCTAssertNotNil(tStar, "draw-back after separation must be captured")
        if let t = tStar {
            XCTAssertGreaterThan(t, 0.15, "must not fire in the contact envelope")
            XCTAssertLessThan(t, 1.7)
        }
    }

    /// Object ball starts outside (latch armed) and returns into the shaft.
    func test_collision_objectBallReturnsIntoShaft() {
        let strike = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let elev: Float = 0.05
        let tStar = CueClearance.firstCollisionTime(
            strikePosition: strike,
            aimDirection: aim,
            elevation: elev,
            endPull: CueStroke.followThroughPull,
            holdDuration: 1.5,
            ballsAt: { t in
                [
                    "cue": SCNVector3(0.20, self.y, 0),  // parked clear of tip
                    "object": SCNVector3(0.50 - 0.40 * Float(t), self.y, 0)
                ]
            }
        )
        XCTAssertNotNil(tStar, "returning object ball into shaft must be detected")
    }

    // MARK: - B2. SceneKit euler cross-check

    /// `CueClearance.shaftSegment` must match a real `SCNNode` with the same
    /// `position` + `eulerAngles = (−elev, yaw, 0)` as the render path.
    func test_shaftSegment_matchesSceneKitNode() {
        let cases: [(yawDeg: Float, elevDeg: Float, pull: Float)] = [
            (0, 5, 0),
            (37, 30, -0.05),
            (-120, 15, CueStroke.followThroughPull)
        ]
        let scene = SCNScene()
        let node = SCNNode()
        scene.rootNode.addChildNode(node)

        for c in cases {
            let yaw = c.yawDeg * .pi / 180
            let elev = c.elevDeg * .pi / 180
            // Reconstruct aim/back from yaw the same way CueStick does:
            // yaw = atan2(back.x, back.z), back = −aim.
            let back = SCNVector3(sin(yaw), 0, cos(yaw))
            let aim = SCNVector3(-back.x, 0, -back.z)
            let pivot = SCNVector3(0.12, y, -0.07)

            node.position = pivot
            node.eulerAngles = SCNVector3(-elev, yaw, 0)

            let tipZ = CueClearance.tipOffset + c.pull
            let buttZ = tipZ + CueClearance.shaftLength
            let scnTip = node.convertPosition(SCNVector3(0, 0, tipZ), to: nil)
            let scnButt = node.convertPosition(SCNVector3(0, 0, buttZ), to: nil)
            let seg = CueClearance.shaftSegment(
                strikePosition: pivot, aimDirection: aim,
                elevation: elev, pullBack: c.pull
            )
            XCTAssertEqual(seg.tip.x, scnTip.x, accuracy: 1e-5, "tip.x yaw=\(c.yawDeg) elev=\(c.elevDeg)")
            XCTAssertEqual(seg.tip.y, scnTip.y, accuracy: 1e-5, "tip.y")
            XCTAssertEqual(seg.tip.z, scnTip.z, accuracy: 1e-5, "tip.z")
            XCTAssertEqual(seg.butt.x, scnButt.x, accuracy: 1e-5, "butt.x")
            XCTAssertEqual(seg.butt.y, scnButt.y, accuracy: 1e-5, "butt.y")
            XCTAssertEqual(seg.butt.z, scnButt.z, accuracy: 1e-5, "butt.z")
        }
    }

    // MARK: - C. Follow-through clamp

    func test_followThrough_clampedByForwardBall() {
        let cue = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let obstacle = SCNVector3(2 * r + 0.01, y, 0)
        let clamped = CueStroke.clampedFollowThroughPull(
            cueBallPosition: cue, aimDirection: aim, obstacleCenters: [obstacle]
        )
        // Tip starts at -29.575mm; target rear surface minus 7.5mm
        // tip+margin is at +31.075mm: 60.65mm travel, less the 0.01mm numerical reserve.
        XCTAssertEqual(clamped, -0.06064, accuracy: 1e-6)
        XCTAssertGreaterThan(clamped, CueStroke.followThroughPull)

        let tipPast = -(CueClearance.tipOffset + clamped)
        let obstacleSurface = (2 * r + 0.01) - r
        XCTAssertLessThan(tipPast, obstacleSurface)
        let tipPos = SCNVector3(tipPast, y, 0)
        let dist = abs(tipPos.x - obstacle.x)
        XCTAssertGreaterThanOrEqual(dist, r + CueClearance.tipRadius - 1e-4)
    }

    func testTouchingBallFollowThroughGeometryMatrix() throws {
        var count=0
        for bearing in stride(from:0.0,through:180.0,by:15) {
            for spinX in [-0.35,0,0.35] {
                for spinY in [-0.35,0,0.35] {
                    let angle=Float(bearing)*Float.pi/180
                    let ball=SCNVector3(2*r*cosf(angle),y,2*r*sinf(angle))
                    let access=CueStrikeAccess(cue:SCNVector3(0,y,0),aim:SCNVector3(1,0,0),obstacles:[ball],surfaceY:0.8)
                    let solved=access.resolvedPose(spinX:spinX,spinY:spinY)
                    if bearing <= 90 { XCTAssertNotNil(solved,"Front/side touching must not falsely block a clear address pose") }
                    guard let pose=solved else { continue }
                    let pull=CueStroke.clampedFollowThroughPull(cueBallPosition:pose.pivot,aimDirection:access.aim,
                        obstacleCenters:[ball],elevation:pose.elevation,tipInset:pose.inset,surfaceY:0.8)
                    let stick=CueStick()
                    for step in 0...20 {
                        stick.update(cueBallPosition:pose.pivot,aimDirection:access.aim,pullBack:pull*Float(step)/20,
                            elevation:pose.elevation,tipInset:pose.inset)
                        // Independent SceneKit transform and finite-segment projection.
                        for section in CueSection.fallback {
                            let a=stick.rootNode.convertPosition(SCNVector3(0,0,CueClearance.tipOffset-pose.inset+section.start),to:nil)
                            let b=stick.rootNode.convertPosition(SCNVector3(0,0,CueClearance.tipOffset-pose.inset+section.end),to:nil)
                            let v=SCNVector3(b.x-a.x,b.y-a.y,b.z-a.z)
                            let d=SCNVector3(ball.x-a.x,ball.y-a.y,ball.z-a.z)
                            let u=max(0,min(1,(d.x*v.x+d.y*v.y+d.z*v.z)/(v.x*v.x+v.y*v.y+v.z*v.z)))
                            let distance=sqrtf(powf(d.x-u*v.x,2)+powf(d.y-u*v.y,2)+powf(d.z-u*v.z,2))
                            XCTAssertGreaterThanOrEqual(distance,r+section.radius+CueClearance.ballClearance-0.00001)
                        }
                    }
                    count += 1
                }
            }
        }
        XCTAssertGreaterThan(count,30)
        print("[TouchingBalls] safe poses=\(count), 21 stroke samples per pose")
    }

    @MainActor
    func testTouchingBallsLoadedMeshAndViews() throws {
        let scene=AngleTrainingScene();scene.setupScene();scene.hideAllBalls()
        let cue=SCNVector3(0,scene.surfaceY+r,0), aim=SCNVector3(1,0,0)
        scene.showBall(key:PositionPlayBall.cueKey,scenePosition:cue)
        let stick=try XCTUnwrap(scene.cueStick)
        var vertices=0,poses=0,minimum=Float.infinity
        for bearing: Float in [0,45,90,135,180] {
            let theta=bearing * .pi/180
            let ball=SCNVector3(2*r*cosf(theta),cue.y,2*r*sinf(theta))
            scene.showBall(key:"_1",scenePosition:ball)
            let access=try XCTUnwrap(scene.cueStrikeAccess(aim:aim))
            for spin: Double in [-0.5,0,0.5] {
                guard let pose=access.resolvedPose(spinX:0,spinY:spin) else { continue }
                let end=CueStroke.clampedFollowThroughPull(cueBallPosition:pose.pivot,aimDirection:aim,
                    obstacleCenters:[ball],elevation:pose.elevation,tipInset:pose.inset,
                    surfaceY:scene.surfaceY,profile:stick.clearanceProfile)
                for pull: Float in [0,0.15,end/2,end] {
                    stick.update(cueBallPosition:pose.pivot,aimDirection:aim,pullBack:pull,elevation:pose.elevation,tipInset:pose.inset)
                    stick.show()
                    stick.rootNode.enumerateHierarchy { node,_ in
                        for source in node.geometry?.sources(for:.vertex) ?? [] {
                            guard source.usesFloatComponents,source.bytesPerComponent==4 else { continue }
                            source.data.withUnsafeBytes { bytes in
                                for i in 0..<source.vectorCount {
                                    let offset=source.dataOffset+i*source.dataStride
                                    let p=node.convertPosition(SCNVector3(bytes.loadUnaligned(fromByteOffset:offset,as:Float.self),
                                        bytes.loadUnaligned(fromByteOffset:offset+4,as:Float.self),bytes.loadUnaligned(fromByteOffset:offset+8,as:Float.self)),to:scene.rootNode)
                                    let gap=sqrtf(powf(p.x-ball.x,2)+powf(p.y-ball.y,2)+powf(p.z-ball.z,2))-r
                                    minimum=min(minimum,gap)
                                    XCTAssertGreaterThanOrEqual(gap,CueClearance.ballClearance-0.00001)
                                    XCTAssertGreaterThan(p.y,scene.surfaceY)
                                    vertices += 1
                                }
                            }
                        }
                    }
                    if spin == 0 && (pull == 0 || pull == end) {
                        let camera=SCNNode();camera.camera=SCNCamera();camera.camera?.zNear=0.001
                        camera.camera?.fieldOfView=34;camera.position=SCNVector3(-0.1,scene.surfaceY+0.25,0.42)
                        scene.rootNode.addChildNode(camera)
                        camera.look(at:SCNVector3(-0.01,scene.surfaceY+0.035,0),up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
                        let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=scene;renderer.pointOfView=camera
                        // This is a stationary-obstacle clearance probe, not a physics
                        // replay. Do not leave the departed cue ball frozen in the shaft.
                        let cueNode=scene.allBallNodes[PositionPlayBall.cueKey]
                        let wasHidden=cueNode?.isHidden ?? false
                        if pull != 0 { cueNode?.isHidden=true }
                        SCNTransaction.flush()
                        let image=renderer.snapshot(atTime:0,with:CGSize(width:900,height:650),antialiasingMode:.multisampling4X)
                        cueNode?.isHidden=wasHidden
                        let attachment=XCTAttachment(image:image)
                        attachment.name="touching-\(Int(bearing))-\(pull == 0 ? "aim" : "follow")"
                        attachment.lifetime = .keepAlways;add(attachment);camera.removeFromParentNode()
                    }
                }
                poses += 1
            }
        }
        XCTAssertGreaterThanOrEqual(poses,8)
        XCTAssertGreaterThan(vertices,10000)
        print("[TouchingMesh] poses=\(poses) vertices=\(vertices) minimumGapMM=\(minimum*1000)")
    }

    @MainActor
    func testCrownContactAndFrozenAccess() throws {
        for model in [false,true] {
            let scene=AngleTrainingScene();scene.setupScene();scene.hideAllBalls()
            let stick=model ? try XCTUnwrap(scene.cueStick) : CueStick()
            let cue=SCNVector3(0,scene.surfaceY+r,0),aim=SCNVector3(1,0,0)
            for degrees:Float in [0,15,30] {
                let access=CueStrikeAccess(cue:cue,aim:aim,obstacles:[],surfaceY:scene.surfaceY,profile:stick.clearanceProfile)
                for (sideSpin,spin) in [(0.0,-0.5),(0,0),(0,0.5),(-0.35,-0.35),(-0.35,0.35),(0.35,-0.35),(0.35,0.35)] {
                    let pose=access.pose(spinX:sideSpin,spinY:spin,elevation:degrees * .pi/180)
                    stick.update(cueBallPosition:pose.pivot,aimDirection:aim,elevation:pose.elevation,tipInset:pose.inset)
                    let back=SCNVector3(-cosf(pose.elevation),sinf(pose.elevation),0)
                    let pole=stick.rootNode.convertPosition(SCNVector3(0,0,CueClearance.tipOffset),to:nil)
                    let rho=CuePhysics.tipCurvatureRadius
                    let center=SCNVector3(pole.x+rho*back.x,pole.y+rho*back.y,pole.z+rho*back.z)
                    XCTAssertEqual(sqrtf(powf(center.x-cue.x,2)+powf(center.y-cue.y,2)+powf(center.z-cue.z,2)),r+rho,accuracy:0.00011)
                    XCTAssertEqual(pose.contact.y, cue.y+r*(sinf(pose.elevation)*sqrtf(1-Float(spin*spin+sideSpin*sideSpin))+cosf(pose.elevation)*Float(spin)),accuracy:1e-6)
                    var nearest=Float.infinity
                    stick.rootNode.enumerateHierarchy { node,_ in
                        for vertex in CueStick.renderedVertices(node) {
                            let v=node.convertPosition(vertex,to:nil)
                            let distance=sqrtf(powf(v.x-cue.x,2)+powf(v.y-cue.y,2)+powf(v.z-cue.z,2))-r
                            nearest=min(nearest,distance)
                            XCTAssertGreaterThanOrEqual(distance,-0.00005,"Rendered crown/body must not enter the cue ball")
                        }
                    }
                    XCTAssertLessThan(nearest,0.0005,"Rendered tip must actually approach contact, not float away")
                }
            }
            for obstacle in [false,true] {
                let position=obstacle ? cue : SCNVector3(-1.27+r,cue.y,0)
                let balls=obstacle ? [SCNVector3(-2*r,cue.y,0)] : []
                let access=CueStrikeAccess(cue:position,aim:aim,obstacles:balls,surfaceY:scene.surfaceY,profile:stick.clearanceProfile)
                let high=try XCTUnwrap(access.resolvedPose(spinX:0,spinY:0.5))
                XCTAssertLessThan(high.elevation,CueStrikeAccess.maximumElevation)
                XCTAssertFalse(access.isAvailable(spinX:0,spinY:-0.5))
                print("[CrownAccess] model=\(model) rearBall=\(obstacle) highDegrees=\(high.elevation*180 / .pi)")
                if model {
                    scene.hideAllBalls();scene.showBall(key:PositionPlayBall.cueKey,scenePosition:position)
                    if let ball=balls.first { scene.showBall(key:"_1",scenePosition:ball) }
                    stick.update(cueBallPosition:high.pivot,aimDirection:aim,elevation:high.elevation,tipInset:high.inset);stick.show()
                    let marker=SCNNode(geometry:SCNSphere(radius:0.0007));marker.geometry?.firstMaterial?.diffuse.contents=UIColor.red
                    marker.position=high.contact;scene.rootNode.addChildNode(marker)
                    let camera=SCNNode();camera.camera=SCNCamera();camera.camera?.fieldOfView=34;camera.camera?.zNear=0.001
                    camera.position=SCNVector3(position.x-0.06,scene.surfaceY+0.17,0.36)
                    scene.rootNode.addChildNode(camera)
                    camera.look(at:SCNVector3(position.x-0.05,scene.surfaceY+0.055,0),up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
                    let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=scene;renderer.pointOfView=camera
                    SCNTransaction.flush()
                    let image=renderer.snapshot(atTime:0,with:CGSize(width:1000,height:700),antialiasingMode:.multisampling4X)
                    let attachment=XCTAttachment(image:image);attachment.name=obstacle ? "crown-rear-touching-high" : "crown-frozen-rail-high"
                    attachment.lifetime = .keepAlways;add(attachment);camera.removeFromParentNode();marker.removeFromParentNode()
                }
            }
        }
    }

    func testTouchingFrontAndSideTravel() {
        let pivot=SCNVector3(0,y,0),aim=SCNVector3(1,0,0)
        let front=CueClearance.forwardSurfaceGap(cueBallPosition:pivot,aimDirection:aim,
            obstacleCenters:[SCNVector3(2*r,y,0)])
        XCTAssertEqual(front,0.05064,accuracy:1e-6)
        let side=CueClearance.forwardSurfaceGap(cueBallPosition:pivot,aimDirection:aim,
            obstacleCenters:[SCNVector3(0,y,2*r)])
        XCTAssertEqual(side,Float.greatestFiniteMagnitude)
        // Moving along an elevated, offset axis changes the real available travel.
        let shifted=CueClearance.forwardSurfaceGap(cueBallPosition:pivot,aimDirection:aim,
            obstacleCenters:[SCNVector3(2*r,y,0)],tipInset:0.004)
        XCTAssertEqual(front-shifted,0.004,accuracy:1e-5)
    }

    func test_followThrough_noObstacleUnclamped() {
        let cue = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let pull = CueStroke.clampedFollowThroughPull(
            cueBallPosition: cue, aimDirection: aim, obstacleCenters: []
        )
        XCTAssertEqual(pull, CueStroke.followThroughPull, accuracy: 1e-6)
    }

    // MARK: - Regression: pullBack literals (v=1.5)

    /// Nail concrete samples from `build/cue-clearance-evidence/rework_latch_draft.txt`
    /// so curve edits are caught (not a self-derived recompute of the same formula).
    func test_regression_pullBackLiteralSamples_v1_5() {
        let v: Float = 1.5
        // d = 0.05 + 0.035·1.5 = 0.1025; total = 0.5 + 0.12 + 2d/v = 0.7566…
        let samples: [(t: Double, expected: Float)] = [
            (0.0,      0.0),
            (0.125,    0.016015625),
            (0.25,     0.05125),
            (0.375,    0.086484375),
            (0.5,      0.1025),          // end of backswing
            (0.56,     0.1025),          // mid pause
            (0.62,     0.1025),          // end pause
            (0.70,     0.06737805),      // mid forward
            (0.756667, 0.0),             // contact
        ]
        for s in samples {
            let p = CueStroke.pullBack(at: s.t, velocity: v)
            XCTAssertEqual(p, s.expected, accuracy: 1e-5, "t=\(s.t)")
        }
        XCTAssertEqual(
            CueStroke.followThrough(at: CueStroke.followThroughDuration),
            CueStroke.followThroughPull, accuracy: 1e-6
        )
    }

    // MARK: - Shaft radius smoke

    func test_shaftRadius_monotoneTipToButt() {
        let rTip = CueClearance.shaftRadius(atDistanceAlongBack: r)
        let rMid = CueClearance.shaftRadius(atDistanceAlongBack: r + 0.5)
        let rButt = CueClearance.shaftRadius(
            atDistanceAlongBack: r + CueClearance.maxPullBack + CueClearance.shaftLength
        )
        XCTAssertEqual(rTip, CueClearance.tipRadius, accuracy: 1e-5)
        XCTAssertEqual(rButt, CueClearance.buttRadius, accuracy: 1e-5)
        XCTAssertLessThan(rTip, rMid)
        XCTAssertLessThan(rMid, rButt)
    }

    // MARK: - Trajectory helpers (realistic contact-neighbourhood kinematics)

    /// Coast +aim with constant decel over 0.4 s, then rest (never returns to origin).
    private static func ballForwardThenStop(t: TimeInterval, v: Float, y: Float) -> SCNVector3 {
        let stopT: Float = 0.4
        let a = v / stopT
        let tf = Float(t)
        let x: Float
        if tf <= stopT {
            x = v * tf - 0.5 * a * tf * tf
        } else {
            x = v * stopT - 0.5 * a * stopT * stopT
        }
        return SCNVector3(x, y, 0)
    }

    /// Forward for 0.25 s at 1.2 m/s (separates from tip), then reverse at 0.55 m/s into shaft.
    private static func ballDrawBack(t: TimeInterval, y: Float) -> SCNVector3 {
        let tRev: Float = 0.25
        let vFwd: Float = 1.2
        let vBack: Float = 0.55
        let tf = Float(t)
        let x: Float
        if tf < tRev {
            x = vFwd * tf
        } else {
            x = vFwd * tRev - vBack * (tf - tRev)
        }
        return SCNVector3(x, y, 0)
    }
}
