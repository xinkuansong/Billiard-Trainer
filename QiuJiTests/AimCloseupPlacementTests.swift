import SceneKit
import XCTest
import simd
@testable import QiuJi

final class AimCloseupCoordsTests: XCTestCase {

    func test_mapRotated_matchesCameraContract() {
        let focus = CGPoint.zero
        let origin = CGPoint(x: 50, y: 50)
        let scale: CGFloat = 10
        // +X → screen up (smaller y)
        let up = AimCloseupCoords.mapRotated(
            world: CGPoint(x: 1, y: 0), focus: focus, origin: origin, scale: scale)
        XCTAssertEqual(up.x, 50, accuracy: 1e-6)
        XCTAssertEqual(up.y, 40, accuracy: 1e-6)
        // +Z → screen right (larger x)
        let right = AimCloseupCoords.mapRotated(
            world: CGPoint(x: 0, y: 1), focus: focus, origin: origin, scale: scale)
        XCTAssertEqual(right.x, 60, accuracy: 1e-6)
        XCTAssertEqual(right.y, 50, accuracy: 1e-6)
    }
}

final class AimCloseupPlacementTests: XCTestCase {

    func testCompactInstrumentColumnsPreferClearSlotOverCueOverlap() {
        // Captured production SE3 viewport and projected ball centers.
        let size = CGSize(width: 375, height: 463)
        let focus = CGPoint(x: 0.44773246, y: 0.3984)
        let insets = AimCloseupPlacement.SafeInsets(top: 12, leading: 75.506, bottom: 46, trailing: 75.506)
        let corridor = AimCloseupPlacement.SightKeepout(
            potStartNorm: focus, potEndNorm: focus,
            aimStartNorm: CGPoint(x: 0.55226754, y: 0.66933334),
            aimEndNorm: CGPoint(x: 0.46017122, y: 0.41456798), pocketRadius: 0)
        let center = AimCloseupPlacement.center(focusNorm: focus, sceneSize: size,
            diameter: 128, safeInsets: insets, sightKeepout: corridor)
        XCTAssertEqual(AimCloseupPlacement.keepoutOverlap(center: center, diameter: 128,
            sceneSize: size, keepout: corridor), 0, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(center.x - 64, insets.leading - 0.5)
        XCTAssertLessThanOrEqual(center.x + 64, size.width - insets.trailing + 0.5)
    }

    func test_focusNorm_rotatedTopDown_axes() {
        let mid = AimCloseupPlacement.focusNormInRotatedTopDown(
            worldXZ: .zero, halfLength: 1.27, halfWidth: 0.635)
        XCTAssertEqual(mid.x, 0.5, accuracy: 1e-4)
        XCTAssertEqual(mid.y, 0.5, accuracy: 1e-4)

        let up = AimCloseupPlacement.focusNormInRotatedTopDown(
            worldXZ: CGPoint(x: 0.6, y: 0), halfLength: 1.27, halfWidth: 0.635)
        XCTAssertLessThan(up.y, 0.5)

        let right = AimCloseupPlacement.focusNormInRotatedTopDown(
            worldXZ: CGPoint(x: 0, y: 0.3), halfLength: 1.27, halfWidth: 0.635)
        XCTAssertGreaterThan(right.x, 0.5)
    }

    func test_topLeadingFocus_picksBottomTrailing_withoutHysteresis() {
        let c = AimCloseupPlacement.corner(
            focusNorm: CGPoint(x: 0.25, y: 0.25), previous: nil)
        XCTAssertEqual(c, .bottomTrailing)
    }

    func test_corner_oppositeFocus() {
        let c1 = AimCloseupPlacement.corner(
            focusNorm: CGPoint(x: 0.2, y: 0.2), previous: nil)
        XCTAssertEqual(c1, .bottomTrailing)

        let c2 = AimCloseupPlacement.corner(
            focusNorm: CGPoint(x: 0.8, y: 0.8), previous: nil)
        XCTAssertEqual(c2, .topLeading)
    }

    func test_corner_hysteresis_holdsOnlyInsideBand() {
        let stayX = AimCloseupPlacement.corner(
            focusNorm: CGPoint(x: 0.52, y: 0.8), previous: .topTrailing, hysteresis: 0.08)
        XCTAssertEqual(stayX, .topTrailing)

        let flipX = AimCloseupPlacement.corner(
            focusNorm: CGPoint(x: 0.8, y: 0.8), previous: .topTrailing, hysteresis: 0.08)
        XCTAssertEqual(flipX, .topLeading)

        let stayY = AimCloseupPlacement.corner(
            focusNorm: CGPoint(x: 0.2, y: 0.47), previous: .topTrailing, hysteresis: 0.08)
        XCTAssertEqual(stayY, .topTrailing)

        let flipY = AimCloseupPlacement.corner(
            focusNorm: CGPoint(x: 0.2, y: 0.2), previous: .topTrailing, hysteresis: 0.08)
        XCTAssertEqual(flipY, .bottomTrailing)
    }

    func test_corner_neverSharesFocusHalf_outsideBand() {
        for previous in AimCloseupPlacement.Corner.allCases {
            for y in [CGFloat(0.05), 0.2, 0.35, 0.65, 0.8, 0.95] {
                let c = AimCloseupPlacement.corner(
                    focusNorm: CGPoint(x: 0.5, y: y), previous: previous, hysteresis: 0.08)
                XCTAssertEqual(c.isBottom, y < 0.5,
                               "focus y=\(y) previous=\(previous) → \(c)")
            }
        }
    }

    func test_blockedLeadingSide_pinsTrailing() {
        for x in [CGFloat(0.1), 0.49, 0.51, 0.9] {
            let top = AimCloseupPlacement.corner(
                focusNorm: CGPoint(x: x, y: 0.2), previous: nil, blockedSide: .leading)
            XCTAssertEqual(top, .bottomTrailing)

            let bottom = AimCloseupPlacement.corner(
                focusNorm: CGPoint(x: x, y: 0.8), previous: .bottomTrailing,
                blockedSide: .leading)
            XCTAssertEqual(bottom, .topTrailing)
        }
    }

    /// UR-20260728 fail screenshot: ball high / slightly leading, previous was a
    /// top corner → must leave the ball's half (not stick under half-plane hysteresis).
    func test_urScreenshot_topBall_neverStaysTopLeading() {
        let focus = CGPoint(x: 0.28, y: 0.22)
        for previous: AimCloseupPlacement.Corner? in [nil, .topLeading, .topTrailing] {
            let c = AimCloseupPlacement.corner(
                focusNorm: focus, previous: previous, blockedSide: .leading)
            XCTAssertEqual(c, .bottomTrailing, "previous=\(String(describing: previous))")
        }
    }

    func test_screenshotCase_ballTopCentreRight_goesBottomTrailing() {
        let focus = AimCloseupPlacement.focusNormInRotatedTopDown(
            worldXZ: CGPoint(x: 0.79, y: 0.06),
            halfLength: ShotTableLayout.defaultHalfLength,
            halfWidth: ShotTableLayout.defaultHalfWidth)
        XCTAssertLessThan(focus.y, 0.5)
        XCTAssertGreaterThan(focus.x, 0.5)

        let c = AimCloseupPlacement.corner(
            focusNorm: focus, previous: nil, blockedSide: .leading)
        XCTAssertEqual(c, .bottomTrailing)
    }

    /// Center placement: loupe must stay clear of the focus and of the leading wheel column.
    func test_center_clearsFocusAndLeadingWheel() {
        let scene = CGSize(width: 390, height: 720)
        let diameter: CGFloat = 128
        let focusNorm = CGPoint(x: 0.28, y: 0.22)
        let center = AimCloseupPlacement.center(
            focusNorm: focusNorm, sceneSize: scene, diameter: diameter,
            safeInsets: .aimWheelPage, blockedSide: .leading, previous: nil)
        let focus = CGPoint(x: focusNorm.x * scene.width, y: focusNorm.y * scene.height)
        let sep = hypot(center.x - focus.x, center.y - focus.y)
        XCTAssertGreaterThanOrEqual(sep, diameter * 0.92 - 0.5,
                                    "loupe must not sit on the object ball")
        XCTAssertGreaterThanOrEqual(center.x - diameter / 2,
                                    AimCloseupPlacement.SafeInsets.aimWheelPage.leading - 0.5,
                                    "must clear aim-wheel column")
        // Top-leading → open quadrant is bottom-trailing.
        XCTAssertGreaterThan(center.y, focus.y)
        XCTAssertGreaterThan(center.x, focus.x)
        XCTAssertGreaterThan(sep, diameter / 2 + 8)
    }

    /// Center stays near the ball (not teleported to a far screen corner).
    func test_center_staysNearFocus() {
        let scene = CGSize(width: 390, height: 720)
        let diameter: CGFloat = 128
        let focusNorm = CGPoint(x: 0.55, y: 0.30)
        let center = AimCloseupPlacement.center(
            focusNorm: focusNorm, sceneSize: scene, diameter: diameter,
            previous: nil)
        let focus = CGPoint(x: focusNorm.x * scene.width, y: focusNorm.y * scene.height)
        let sep = hypot(center.x - focus.x, center.y - focus.y)
        // Ideal gap ≈ 0.92·d; after clamp still well under a full-screen hop.
        XCTAssertLessThan(sep, diameter * 1.6)
    }

    // MARK: - D-v23-5.1 open quadrant

    func test_edgeClearance_openQuadrant_isDiagonalIntoEmptyCorner() {
        let e = AimCloseupPlacement.EdgeClearance.of(CGPoint(x: 0.2, y: 0.15))
        XCTAssertEqual(e.leading, 0.2, accuracy: 1e-6)
        XCTAssertEqual(e.trailing, 0.8, accuracy: 1e-6)
        XCTAssertEqual(e.top, 0.15, accuracy: 1e-6)
        XCTAssertEqual(e.bottom, 0.85, accuracy: 1e-6)
        let q = e.openQuadrantDirection
        XCTAssertEqual(q.0, 1, accuracy: 1e-6)  // trailing
        XCTAssertEqual(q.1, 1, accuracy: 1e-6)  // bottom
        let run = e.freeRun(along: (1 / sqrt(2), 1 / sqrt(2)),
                            from: CGPoint(x: 0.2, y: 0.15))
        XCTAssertGreaterThan(run, 0.7)
    }

    /// Top-leading focus → loupe into bottom-trailing open quadrant (both axes).
    func test_center_prefersOpenQuadrantDiagonal() {
        let scene = CGSize(width: 390, height: 720)
        let diameter: CGFloat = 128
        let focusNorm = CGPoint(x: 0.22, y: 0.18)
        let center = AimCloseupPlacement.center(
            focusNorm: focusNorm, sceneSize: scene, diameter: diameter,
            safeInsets: .aimWheelPage, blockedSide: .leading, previous: nil)
        let focus = CGPoint(x: focusNorm.x * scene.width, y: focusNorm.y * scene.height)
        XCTAssertGreaterThan(center.y, focus.y + diameter * 0.25,
                             "open quadrant includes bottom")
        XCTAssertGreaterThan(center.x, focus.x + diameter * 0.25,
                             "open quadrant includes trailing")
    }

    /// Aim line keepout: loupe must not sit on cue→target segment.
    func test_center_clearsAimLine_whenKeepoutIncludesAim() {
        let scene = CGSize(width: 390, height: 720)
        let diameter: CGFloat = 128
        let focusNorm = CGPoint(x: 0.55, y: 0.50)
        let keepout = AimCloseupPlacement.SightKeepout(
            potStartNorm: focusNorm,
            potEndNorm: CGPoint(x: 0.55, y: 0.12), // pot up
            aimStartNorm: CGPoint(x: 0.20, y: 0.50), // cue left → target
            aimEndNorm: focusNorm,
            segmentMargin: 10,
            pocketRadius: 24)
        let center = AimCloseupPlacement.center(
            focusNorm: focusNorm, sceneSize: scene, diameter: diameter,
            safeInsets: .aimWheelPage, blockedSide: .leading, previous: nil,
            sightKeepout: keepout)
        let overlap = AimCloseupPlacement.keepoutOverlap(
            center: center, diameter: diameter, sceneSize: scene, keepout: keepout)
        XCTAssertLessThanOrEqual(overlap, 0.5)
        let focus = CGPoint(x: focusNorm.x * scene.width, y: focusNorm.y * scene.height)
        // Horizontal aim + vertical pot ⇒ open space is bottom-trailing diagonal-ish.
        XCTAssertGreaterThan(center.y, focus.y - 1,
                             "should leave the upward pot / leftward aim corridor")
    }

    // MARK: - D-v23-5⁗ sight keepout

    /// Horizontal pot to the trailing side: open-edge / keepout still hard-clears.
    func test_center_clearsPotLineAndPocket_whenKeepoutSet() {
        let scene = CGSize(width: 390, height: 720)
        let diameter: CGFloat = 128
        let focusNorm = CGPoint(x: 0.45, y: 0.50)
        let keepout = AimCloseupPlacement.SightKeepout(
            potStartNorm: focusNorm,
            potEndNorm: CGPoint(x: 0.92, y: 0.50),
            segmentMargin: 10,
            pocketRadius: 24)
        let center = AimCloseupPlacement.center(
            focusNorm: focusNorm, sceneSize: scene, diameter: diameter,
            safeInsets: .aimWheelPage, blockedSide: .leading, previous: nil,
            sightKeepout: keepout)
        let focus = CGPoint(x: focusNorm.x * scene.width, y: focusNorm.y * scene.height)
        let overlap = AimCloseupPlacement.keepoutOverlap(
            center: center, diameter: diameter, sceneSize: scene, keepout: keepout)
        XCTAssertLessThanOrEqual(overlap, 0.5,
                                 "must hard-clear pot segment and pocket disc")
        XCTAssertGreaterThanOrEqual(center.x, focus.x - 0.5)
        XCTAssertGreaterThanOrEqual(
            hypot(center.x - focus.x, center.y - focus.y), diameter * 0.92 - 0.5)
        XCTAssertGreaterThanOrEqual(
            center.x - diameter / 2,
            AimCloseupPlacement.SafeInsets.aimWheelPage.leading - 0.5)
    }

    /// Pot toward top + more open bottom → loupe below focus and clear of pot.
    func test_center_openEdge_and_potKeepout_agreeOnBottom() {
        let scene = CGSize(width: 390, height: 720)
        let diameter: CGFloat = 128
        let focusNorm = CGPoint(x: 0.55, y: 0.45)
        let keepout = AimCloseupPlacement.SightKeepout(
            potStartNorm: focusNorm,
            potEndNorm: CGPoint(x: 0.55, y: 0.08),
            segmentMargin: 10,
            pocketRadius: 24)
        let center = AimCloseupPlacement.center(
            focusNorm: focusNorm, sceneSize: scene, diameter: diameter,
            safeInsets: .aimWheelPage, blockedSide: .leading, previous: nil,
            sightKeepout: keepout)
        let focus = CGPoint(x: focusNorm.x * scene.width, y: focusNorm.y * scene.height)
        XCTAssertGreaterThan(center.y, focus.y, "空旷在下且袋在上 ⇒ 特写在焦点下方")
        let overlap = AimCloseupPlacement.keepoutOverlap(
            center: center, diameter: diameter, sceneSize: scene, keepout: keepout)
        XCTAssertLessThanOrEqual(overlap, 0.5)
    }

    /// No keepout: open quadrant (bottom-trailing for top-leading focus).
    func test_center_withoutKeepout_usesOpenQuadrant() {
        let scene = CGSize(width: 390, height: 720)
        let diameter: CGFloat = 128
        let focusNorm = CGPoint(x: 0.28, y: 0.22)
        let center = AimCloseupPlacement.center(
            focusNorm: focusNorm, sceneSize: scene, diameter: diameter,
            safeInsets: .aimWheelPage, blockedSide: .leading, previous: nil,
            sightKeepout: nil)
        let focus = CGPoint(x: focusNorm.x * scene.width, y: focusNorm.y * scene.height)
        XCTAssertGreaterThan(center.y, focus.y)
        XCTAssertGreaterThan(center.x, focus.x)
        XCTAssertGreaterThanOrEqual(
            hypot(center.x - focus.x, center.y - focus.y), diameter * 0.92 - 0.5)
    }

    /// World factory maps pocket end into the trailing-upper quadrant for +X/+Z.
    func test_sightKeepout_fromWorld_mapsPocketNorm() {
        let halfL = ShotTableLayout.defaultHalfLength
        let halfW = ShotTableLayout.defaultHalfWidth
        let object = CGPoint.zero
        let pocket = CGPoint(x: 0.8, y: 0.4) // +X up-screen, +Z right-screen
        let k = AimCloseupPlacement.SightKeepout.fromWorld(
            object: object, pocket: pocket, halfLength: halfL, halfWidth: halfW)
        XCTAssertEqual(k.potStartNorm.x, 0.5, accuracy: 1e-3)
        XCTAssertEqual(k.potStartNorm.y, 0.5, accuracy: 1e-3)
        XCTAssertLessThan(k.potEndNorm.y, 0.5, "world +X → screen up → smaller y")
        XCTAssertGreaterThan(k.potEndNorm.x, 0.5, "world +Z → screen right → larger x")
    }
}

@MainActor
final class AimCloseupAxisContractTests: XCTestCase {

    func test_rotatedTopDown_screenUpIsWorldPlusX_rightIsPlusZ() throws {
        let size = CGSize(width: 400, height: 800)
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        let camNode = try XCTUnwrap(scene.cameraNode)
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.topDownPanOffset = .zero
        rig.fitRotatedTable(viewSize: size)
        rig.applyTopDown2DRotated()

        let cam = try XCTUnwrap(camNode.camera)
        func project(_ p: SCNVector3) -> CGPoint {
            let view = simd_inverse(simd_float4x4(camNode.worldTransform))
            let proj = simd_float4x4(cam.projectionTransform(withViewportSize: size))
            let clip = proj * (view * simd_float4(p.x, p.y, p.z, 1))
            let w = clip.w == 0 ? 1 : clip.w
            return CGPoint(x: CGFloat((clip.x / w * 0.5 + 0.5) * Float(size.width)),
                           y: CGFloat((1 - (clip.y / w * 0.5 + 0.5)) * Float(size.height)))
        }

        let y = scene.surfaceY
        let origin = project(SCNVector3(0, y, 0))
        let plusX = project(SCNVector3(0.5, y, 0))
        let plusZ = project(SCNVector3(0, y, 0.5))

        XCTAssertLessThan(plusX.y, origin.y - 10, "世界 +X 必须朝屏幕上")
        XCTAssertEqual(plusX.x, origin.x, accuracy: 0.5)
        XCTAssertGreaterThan(plusZ.x, origin.x + 10, "世界 +Z 必须朝屏幕右")
        XCTAssertEqual(plusZ.y, origin.y, accuracy: 0.5)

        let mappedX = AimCloseupCoords.mapRotated(
            world: CGPoint(x: 0.5, y: 0), focus: .zero, origin: origin, scale: 1)
        let mappedZ = AimCloseupCoords.mapRotated(
            world: CGPoint(x: 0, y: 0.5), focus: .zero, origin: origin, scale: 1)
        XCTAssertEqual((mappedX.y - origin.y).sign, (plusX.y - origin.y).sign)
        XCTAssertEqual((mappedZ.x - origin.x).sign, (plusZ.x - origin.x).sign)

        let ptsPerMeterUp = (origin.y - plusX.y) / 0.5
        let ptsPerMeterRight = (plusZ.x - origin.x) / 0.5
        XCTAssertEqual(ptsPerMeterUp, ptsPerMeterRight, accuracy: 0.5)

        let norm = AimCloseupPlacement.focusNormInRotatedTopDown(
            worldXZ: CGPoint(x: 0.5, y: 0.5),
            halfLength: rig.tableOuterHalfLength,
            halfWidth: rig.tableOuterHalfWidth)
        let projected = project(SCNVector3(0.5, y, 0.5))
        XCTAssertLessThan(norm.y, 0.5)
        XCTAssertLessThan(projected.y, origin.y)
        XCTAssertGreaterThan(norm.x, 0.5)
        XCTAssertGreaterThan(projected.x, origin.x)
    }
}

@MainActor
final class AimCloseupProjectionTests: XCTestCase {
    func testProjectionMatchesRendererAcrossCameraPoses() throws {
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 402, height: 700))
        view.scene = scene
        view.pointOfView = scene.cameraNode
        let focus = CGPoint(x: 0.3, y: 0.1)
        let point = CGPoint(x: 0.34, y: 0.16)
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        let snap = AimCloseupSnapshot(band: .contact, focus: focus, ballRadius: 0.028575,
                                      halfWorld: 0.09144, aimPointMarker: point)
        for mode in [AngleTrainingScene.CameraMode.topDown2DRotated, .perspective3D] {
            scene.setCameraMode(mode, animated: false)
            for yaw in [-0.8, 0.0, 0.7] {
                for height in [Float(1.4), 2.4] {
                    if mode == .perspective3D {
                        scene.cameraNode.position = SCNVector3(Float(yaw), height, 1.5)
                        scene.cameraNode.look(at: SCNVector3(0.3, y, 0.1))
                    } else {
                        scene.cameraRig?.fitRotatedTable(viewSize: view.bounds.size)
                        scene.cameraRig?.applyTopDown2DRotated()
                    }
                    SCNTransaction.flush()
                    let projected = try XCTUnwrap(snap.projected(in: view, surfaceY: scene.surfaceY))
                    let f = view.projectPoint(SCNVector3(Float(focus.x), y, Float(focus.y)))
                    let p = view.projectPoint(SCNVector3(Float(point.x), y, Float(point.y)))
                    let marker = try XCTUnwrap(projected.aimPointMarker)
                    let mapped = AimCloseupCoords.mapRotated(world: marker, focus: projected.focus,
                                                           origin: .zero, scale: 1)
                    let dx = CGFloat(p.x - f.x), dy = CGFloat(p.y - f.y)
                    XCTAssertEqual(mapped.x * dy - mapped.y * dx, 0, accuracy: 0.0001)
                    XCTAssertGreaterThan(mapped.x * dx + mapped.y * dy, 0)
                    XCTAssertEqual(try XCTUnwrap(projected.focusNorm).x,
                                   CGFloat(f.x) / view.bounds.width, accuracy: 0.0001)
                }
            }
        }
    }
}

final class DailyCloseupProtectionTests: XCTestCase {
    func testWholeLoupeStaysInside2DTableAndAvoidsDiagonalCue() throws {
        let stage = CGSize(width:700,height:350), table = CGRect(x:30,y:30,width:640,height:290)
        var obstacles = AimCloseupObstacles()
        obstacles.polygons = [.init(vertices:[CGPoint(x:50,y:300),CGPoint(x:56,y:308),
            CGPoint(x:556,y:78),CGPoint(x:550,y:70)])]
        XCTAssertLessThan(obstacles.clearance(at:CGPoint(x:303,y:189)),0)
        for focus in [CGPoint(x:40,y:40),CGPoint(x:650,y:40),CGPoint(x:40,y:310),CGPoint(x:650,y:310)] {
            let result = try XCTUnwrap(AimCloseupPlacement.protectedPlacement(focus:focus,size:stage,
                obstacles:obstacles,placementBounds:table))
            let r = result.diameter/2
            XCTAssertGreaterThanOrEqual(result.center.x-r,table.minX+4)
            XCTAssertLessThanOrEqual(result.center.x+r,table.maxX-4)
            XCTAssertGreaterThanOrEqual(result.center.y-r,table.minY+4)
            XCTAssertLessThanOrEqual(result.center.y+r,table.maxY-4)
            XCTAssertGreaterThanOrEqual(obstacles.clearance(at:result.center),r+2)
        }
    }

    @MainActor
    func testGhostRemainsTangentAcrossCameraYawPitchAndCutAngles() throws {
        let scene = SCNScene(), camera = SCNNode()
        camera.camera = SCNCamera(); camera.camera!.zNear = 0.01; camera.camera!.zFar = 100
        scene.rootNode.addChildNode(camera)
        let view = SCNView(frame:CGRect(x:0,y:0,width:860,height:402))
        view.scene = scene; view.pointOfView = camera
        let r: CGFloat = 0.028575
        var checked = 0
        for yaw in stride(from:0.0,to:360.0,by:45) {
            for pitch in [10.0,30,60,89] {
                let y = yaw * .pi/180, p = pitch * .pi/180
                camera.position = SCNVector3(Float(sin(y)*cos(p)),Float(sin(p)),Float(cos(y)*cos(p)))
                camera.look(at:SCNVector3Zero); SCNTransaction.flush()
                for cut in stride(from:0.0,to:360.0,by:30) {
                    let angle = cut * .pi/180
                    let ghost = CGPoint(x:2*r*cos(angle),y:2*r*sin(angle))
                    let contact = CGPoint(x:ghost.x/2,y:ghost.y/2)
                    let snap = AimCloseupSnapshot(band:.contact,focus:.zero,ballRadius:r,halfWorld:3.2*r,
                        ghost:ghost,contactMarker:contact)
                    let projected = try XCTUnwrap(snap.projected(in:view,surfaceY:0,preservesPlanarTangency:true))
                    let g = try XCTUnwrap(projected.ghost), c = try XCTUnwrap(projected.contactMarker)
                    XCTAssertEqual(hypot(g.x,g.y),2*r,accuracy:1e-7)
                    XCTAssertEqual(hypot(c.x,c.y),r,accuracy:1e-7)
                    XCTAssertEqual(hypot(c.x-g.x,c.y-g.y),r,accuracy:1e-7)
                    XCTAssertEqual(projected.ghostRadiusScale,1)
                    checked += 1
                }
            }
        }
        XCTAssertEqual(checked,384)
    }
    @MainActor
    func testTrajectoryCrossingBehindCameraRetainsVisibleSegment() throws {
        let camera = SCNNode(); camera.camera = SCNCamera()
        camera.camera!.zNear = 0.1; camera.camera!.zFar = 100
        let (a, b) = try XCTUnwrap(DailyCloseupProjection.clippedSegment(
            SCNVector3(0,0,1), SCNVector3(0.3,0,-2), camera: camera))
        XCTAssertEqual(a.z, -0.1001, accuracy: 0.0001)
        XCTAssertEqual(b.z, -2, accuracy: 0.0001)
        XCTAssertEqual(a.x, 0.11001, accuracy: 0.0001)
        XCTAssertNil(DailyCloseupProjection.clippedSegment(SCNVector3(0,0,1), SCNVector3(1,0,2), camera: camera))
    }
    func testRightEdgeLineMovesLoupeIntoAvailableLeftRegion() throws {
        let size = CGSize(width:620,height:350), focus = CGPoint(x:558,y:210)
        var obstacles = AimCloseupObstacles()
        obstacles.discs = [.init(center:focus,radius:12),.init(center:CGPoint(x:576,y:231),radius:12)]
        obstacles.segments = [.init(start:focus,end:CGPoint(x:558,y:35))]
        let result = try XCTUnwrap(AimCloseupPlacement.protectedPlacement(focus:focus,size:size,obstacles:obstacles))
        XCTAssertLessThan(result.center.x,focus.x)
        XCTAssertGreaterThanOrEqual(obstacles.clearance(at:result.center),result.diameter/2+2)
    }

    func testSixPocketsAcrossScreenSizesAndShotDirections() throws {
        var checked = 0
        for size in [CGSize(width:520,height:260),CGSize(width:700,height:350),CGSize(width:1000,height:680)] {
            let pockets = [CGPoint(x:18,y:18),CGPoint(x:size.width/2,y:18),CGPoint(x:size.width-18,y:18),
                           CGPoint(x:18,y:size.height-18),CGPoint(x:size.width/2,y:size.height-18),CGPoint(x:size.width-18,y:size.height-18)]
            for pocket in pockets {
                for x in [0.15,0.5,0.85] { for y in [0.25,0.5,0.75] {
                    let focus = CGPoint(x:size.width*x,y:size.height*y)
                    var obstacles = AimCloseupObstacles()
                    obstacles.discs = pockets.map { .init(center:$0,radius:22) } + [.init(center:focus,radius:14)]
                    // Post-contact cue path goes in another direction and must also stay clear.
                    obstacles.segments = [.init(start:focus,end:pocket),
                        .init(start:CGPoint(x:focus.x-35,y:focus.y+25),end:focus),
                        .init(start:focus,end:CGPoint(x:size.width*0.6,y:size.height-24))]
                    let result = try XCTUnwrap(AimCloseupPlacement.protectedPlacement(focus:focus,size:size,obstacles:obstacles))
                    XCTAssertGreaterThanOrEqual(obstacles.clearance(at:result.center),result.diameter/2+2)
                    checked += 1
                } }
            }
        }
        XCTAssertEqual(checked,162)
    }

    func testNoSpaceHidesInsteadOfCoveringCriticalGeometry() {
        var obstacles = AimCloseupObstacles()
        obstacles.rectangles = [CGRect(x:0,y:0,width:620,height:350)]
        XCTAssertNil(AimCloseupPlacement.protectedPlacement(focus:CGPoint(x:300,y:180),size:CGSize(width:620,height:350),obstacles:obstacles))
    }

    func testNarrowAvailableAreaShrinksLoupe() throws {
        let result = try XCTUnwrap(AimCloseupPlacement.protectedPlacement(
            focus:CGPoint(x:55,y:100),size:CGSize(width:110,height:220),obstacles:AimCloseupObstacles()))
        XCTAssertEqual(result.diameter,96)
    }

    func testStablePositionIsRetainedUntilNewObstacleIntersects() throws {
        let size = CGSize(width:620,height:350), focus = CGPoint(x:320,y:180)
        var obstacles = AimCloseupObstacles()
        obstacles.discs = [.init(center:focus,radius:16)]
        let first = try XCTUnwrap(AimCloseupPlacement.protectedPlacement(focus:focus,size:size,obstacles:obstacles))
        XCTAssertEqual(first,AimCloseupPlacement.protectedPlacement(focus:CGPoint(x:321,y:180),size:size,obstacles:obstacles,previous:first))
        obstacles.discs.append(.init(center:first.center,radius:24))
        let next = try XCTUnwrap(AimCloseupPlacement.protectedPlacement(focus:focus,size:size,obstacles:obstacles,previous:first))
        XCTAssertNotEqual(first,next)
        XCTAssertGreaterThanOrEqual(obstacles.clearance(at:next.center),next.diameter/2+2)
    }

    func testCueProtectionIncludesPostContactUntilFirstCushion() {
        var prediction = ShotPrediction()
        prediction.cuePath = [SCNVector3(0,0.8,0),SCNVector3(0.2,0.8,0),SCNVector3(0.3,0.8,0.3),
                              SCNVector3(0.4,0.8,0.6),SCNVector3(0.41,0.8,0.59),SCNVector3(0.6,0.8,0.3)]
        prediction.firstContact = prediction.cuePath[1]
        prediction.events = [.init(time:0.3,kind:.ballBall(ballA:ShotInput.cueBallName,ballB:"_1")),
                             .init(time:1,kind:.ballCushion(ball:ShotInput.cueBallName))]
        let recorder = TrajectoryRecorder()
        recorder.recordFrame(ballName:ShotInput.cueBallName,frame:BallFrame(time:1,position:prediction.cuePath[3],
            velocity:SCNVector3Zero,angularVelocity:SCNVector4(0,0,0,0),state:.rolling))
        prediction.recorder = recorder
        let full = DailyCloseupTrajectory.protectedCuePath(prediction,detail:.full)
        XCTAssertEqual(full.count,5)
        XCTAssertEqual(full[3].z,0.6)
        XCTAssertEqual(DailyCloseupTrajectory.protectedCuePath(prediction,detail:.minimal).count,2)
        prediction.events = []
        XCTAssertEqual(DailyCloseupTrajectory.protectedCuePath(prediction,detail:.core).count,6)
    }

    @MainActor
    func testProjectionConvertsFullViewportToInsetOverlay() throws {
        let scene = AngleTrainingScene(); scene.setupScene(enhancedRendering:false)
        _ = scene.addPocketMarkers()
        let view = SCNView(frame:CGRect(x:0,y:0,width:860,height:402))
        view.scene = scene; view.pointOfView = scene.cameraNode
        scene.setCameraMode(.topDown2D,animated:false)
        scene.cameraRig?.fitLandscapeTable(viewSize:view.bounds.size)
        SCNTransaction.flush()
        let destination = CGRect(x:78,y:44,width:704,height:358)
        let snap = AimCloseupSnapshot(band:.contact,focus:CGPoint(x:0.3,y:0.1),ballRadius:0.028575,halfWorld:0.09144)
        let result = try XCTUnwrap(snap.projected(in:view,surfaceY:scene.surfaceY,destinationRect:destination))
        let actual = view.projectPoint(SCNVector3(0.3,scene.surfaceY+0.028575,0.1))
        let norm = try XCTUnwrap(result.focusNorm)
        XCTAssertEqual(norm.x*destination.width+destination.minX,CGFloat(actual.x),accuracy:0.001)
        XCTAssertEqual(norm.y*destination.height+destination.minY,CGFloat(actual.y),accuracy:0.001)
        let obstacles = DailyCloseupProjection.obstacles(snapshot:snap,scene:scene,view:view,destination:destination)
        XCTAssertEqual(scene.closeupPocketNodes.count,6)
        XCTAssertEqual(obstacles.rectangles.count,6)
        scene.cueStick?.update(cueBallPosition:SCNVector3(0,scene.surfaceY+0.028575,0),
                              aimDirection:SCNVector3(0.7,0,0.7),elevation:0.05)
        scene.cueStick?.show(); SCNTransaction.flush()
        let withCue = DailyCloseupProjection.obstacles(snapshot:snap,scene:scene,view:view,destination:destination)
        XCTAssertEqual(withCue.polygons.count,1)
        let cue = try XCTUnwrap(scene.cueStick?.rootNode)
        let (lo,hi) = cue.boundingBox
        let middle = view.projectPoint(cue.presentation.convertPosition(SCNVector3((lo.x+hi.x)/2,(lo.y+hi.y)/2,(lo.z+hi.z)/2),to:nil))
        XCTAssertLessThan(withCue.clearance(at:CGPoint(x:CGFloat(middle.x)-destination.minX,y:CGFloat(middle.y)-destination.minY)),0)
        var nodes: [SCNNode] = []
        scene.addObjectTrajectory([SCNVector3(0,scene.surfaceY,0),SCNVector3(0.5,scene.surfaceY,0.2)],ballKey:"_1",into:&nodes)
        var focused = snap; focused.targetBallNumber = 1
        let withObject = DailyCloseupProjection.obstacles(snapshot:focused,scene:scene,view:view,destination:destination)
        XCTAssertEqual(withObject.segments.count,obstacles.segments.count+1)
        scene.closeupCuePath = [SCNVector3Zero]
        scene.hideAllVisualization()
        XCTAssertTrue(scene.closeupObjectPaths.isEmpty)
        XCTAssertTrue(scene.closeupCuePath.isEmpty)
        let table = DailyCloseupProjection.topDownPlayingRect(scene:scene,view:view,destination:destination)
        scene.cameraNode.camera!.orthographicScale *= 1.5
        SCNTransaction.flush()
        let zoomed = DailyCloseupProjection.topDownPlayingRect(scene:scene,view:view,destination:destination)
        XCTAssertEqual(zoomed.width,table.width/1.5,accuracy:0.001)
        XCTAssertEqual(zoomed.height,table.height/1.5,accuracy:0.001)
    }
}
