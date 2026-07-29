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
