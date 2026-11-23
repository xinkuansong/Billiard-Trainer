import XCTest

/// Real UIKit touches through the daily host. Held-pose diagnostics are sampled after rig.update
/// while the touch remains active; the main agent separately records the native screen and reviews
/// those held frames. A post-release screenshot is never evidence of the held composition.
final class TwoViewCameraUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
    }

    func testS10GlobalButtonUsesNearestRailDuringBreakAndAllowsFurtherOrbit() {
        let app = launchDaily3D(fixture:"manual",surface:true)
        defer { app.terminate() }
        settled(app,mode:"thirdPerson")
        let aimX = number("twoViewAimX",app), aimZ = number("twoViewAimZ",app)
        var visited = Set<Int>()
        for attempt in 0..<2 {
            let start = actualPose(app).yaw
            // Half sensitivity can keep one swipe within the same 45° sector.
            // Drive actual gestures until the view reaches the next rail's sector.
            for _ in 0..<10 {
                heldDrag(app,from:CGVector(dx:0.22,dy:0.30),to:CGVector(dx:0.70,dy:0.30))
                settled(app,mode:"thirdPerson")
                if abs(angleDifference(actualPose(app).yaw,start)) > .pi / 3 { break }
            }
            let heading = actualPose(app).yaw
            XCTAssertGreaterThan(abs(angleDifference(heading,start)),.pi/4)
            let candidates: [Double] = [0,.pi/2,.pi,-.pi/2]
            let selected = candidates.indices.min {
                abs(self.angleDifference(heading,candidates[$0])) < abs(self.angleDifference(heading,candidates[$1]))
            }!
            app.buttons["dailyClearance.observeTable"].tap()
            settled(app,mode:"thirdPerson")
            XCTAssertEqual(angleDifference(actualPose(app).yaw,candidates[selected]),0,accuracy:0.002)
            XCTAssertEqual(number("surfaceTravel",app),1,accuracy:0.001)
            XCTAssertEqual(number("twoViewAimX",app),aimX,accuracy:0.00001)
            XCTAssertEqual(number("twoViewAimZ",app),aimZ,accuracy:0.00001)
            if selected % 2 == 0 { XCTAssertEqual(actualPose(app).z,0,accuracy:0.002) }
            else { XCTAssertEqual(actualPose(app).x,0,accuracy:0.002) }
            visited.insert(selected)
            attach(app,"s10-break-global-\(attempt)-rail-\(selected)")
            let stopped = actualPose(app)
            app.buttons["dailyClearance.observeTable"].tap()
            settled(app,mode:"thirdPerson")
            assertActualPose(app,equals:stopped)
        }
        XCTAssertTrue(visited.contains { $0 % 2 == 0 },"Visit a short rail")
        XCTAssertTrue(visited.contains { $0 % 2 == 1 },"Visit a long rail")
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app,mode:"thirdPerson")
        assertShotHeading(app)
        XCTAssertEqual(number("surfaceTravel",app),1,accuracy:0.001)
    }

    func testS8RepeatedTargetTapReturnsFromOverview() {
        let app = launchDaily3D(surface:true)
        defer { app.terminate() }
        for attempt in 0..<2 {
            app.buttons["dailyClearance.observeTable"].tap()
            settled(app,mode:"thirdPerson")
            XCTAssertEqual(number("surfaceTravel",app),1,accuracy:0.001)
            let entries = number("twoViewAutomaticEntryCount",app)
            app.buttons["paletteBall__2"].tap()
            waitUntil(app) {
                self.number("twoViewAutomaticEntryCount",app) == entries+1 &&
                self.field("twoViewMoving",app) == "false" && self.field("twoViewComputing",app) == "false"
            }
            XCTAssertEqual(number("surfaceTravel",app),0.5,accuracy:0.001)
            XCTAssertEqual(field("mergedTarget",app),"_2")
            assertShotHeading(app)
            attach(app,"s8-selected-ball-2-attempt-\(attempt)")
        }
    }

    func testS8BreakFarthestThirdPersonAfterRerackAnd2DToggle() {
        let app = launchDaily3D(fixture:"manual",surface:true)
        defer { app.terminate() }
        settled(app,mode:"thirdPerson")
        XCTAssertEqual(number("surfaceTravel",app),1,accuracy:0.001)
        attach(app,"s8-break-initial-far")
        heldDrag(app,from:CGVector(dx:0.28,dy:0.8),to:CGVector(dx:0.28,dy:0.2))
        settled(app,mode:"thirdPerson")
        XCTAssertLessThan(number("surfaceTravel",app),1)
        app.buttons["freeplay.cameraMode"].tap()
        waitUntil(app) { self.field("twoViewOrtho",app) == "true" }
        app.buttons["freeplay.cameraMode"].tap()
        settled(app,mode:"thirdPerson")
        XCTAssertEqual(number("surfaceTravel",app),1,accuracy:0.001)
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app,mode:"thirdPerson")
        XCTAssertEqual(number("surfaceTravel",app),1,accuracy:0.001)
        app.buttons["break.entry"].tap()
        let confirm = app.buttons["dailyClearance.rerackAfterBreak"]
        if confirm.waitForExistence(timeout:2) { confirm.tap() }
        settled(app,mode:"thirdPerson")
        XCTAssertEqual(number("surfaceTravel",app),1,accuracy:0.001)
        attach(app,"s8-break-rerack-far")
    }

    func testSurfaceObserveTravelAndOverlay() {
        let app = launchDaily3D(surface:true)
        defer { app.terminate() }
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app,mode:"thirdPerson")
        XCTAssertEqual(field("surfaceCamera",app),"true")
        XCTAssertEqual(number("simpleDistance",app),1.65,accuracy:0.001)
        let aimX = number("twoViewAimX",app), aimZ = number("twoViewAimZ",app)
        attach(app,"surface-s1-default")
        heldDrag(app,from:CGVector(dx:0.28,dy:0.30),to:CGVector(dx:0.66,dy:0.30))
        settled(app,mode:"thirdPerson")
        XCTAssertEqual(number("twoViewAimX",app),aimX,accuracy:0.00001)
        XCTAssertEqual(number("twoViewAimZ",app),aimZ,accuracy:0.00001)
        XCTAssertEqual(number("simpleDistance",app),1.65,accuracy:0.001)
        XCTAssertEqual(number("simpleHeight",app),0.65,accuracy:0.001)
        assertActualPose(app,equals:heldPose(app))
        attach(app,"surface-s1-side-observation")
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app,mode:"thirdPerson")
        for _ in 0..<4 { heldDrag(app,from:CGVector(dx:0.28,dy:0.85),to:CGVector(dx:0.28,dy:0.12)) }
        settled(app,mode:"thirdPerson")
        XCTAssertEqual(number("surfaceTravel",app),0,accuracy:0.001)
        attach(app,"surface-s1-near")
        let nearHeight = number("twoViewEyeY",app)
        heldDrag(app,from:CGVector(dx:0.25,dy:0.30),to:CGVector(dx:0.50,dy:0.30))
        settled(app,mode:"thirdPerson")
        XCTAssertEqual(number("twoViewEyeY",app),nearHeight,accuracy:0.0001)
        app.buttons["dailyClearance.observeTable"].tap()
        settled(app,mode:"thirdPerson")
        XCTAssertEqual(number("surfaceTravel",app),1,accuracy:0.001)
        XCTAssertEqual(field("mergedGlobal",app),"false")
        attach(app,"surface-s1-outer")
        let outerHeight = number("twoViewEyeY",app)
        heldDrag(app,from:CGVector(dx:0.25,dy:0.30),to:CGVector(dx:0.65,dy:0.30))
        settled(app,mode:"thirdPerson")
        XCTAssertEqual(number("surfaceTravel",app),1,accuracy:0.001)
        XCTAssertEqual(number("twoViewAimX",app),aimX,accuracy:0.00001)
        XCTAssertEqual(number("twoViewAimZ",app),aimZ,accuracy:0.00001)
        XCTAssertEqual(number("twoViewEyeY",app),outerHeight,accuracy:0.0001)
        let outer = actualPose(app)
        app.buttons["shotCamera.temporaryTopDown"].tap()
        waitUntil(app) { self.field("mergedOverlay",app) == "true" }
        attach(app,"surface-s1-topdown")
        app.buttons["shotCamera.temporaryTopDown"].tap()
        waitUntil(app) { self.field("mergedOverlay",app) == "false" }
        assertActualPose(app,equals:outer)
        heldDrag(app,from:CGVector(dx:0.28,dy:0.7),to:CGVector(dx:0.28,dy:0.4))
        settled(app,mode:"thirdPerson")
        XCTAssertLessThan(number("surfaceTravel",app),1)
        attach(app,"surface-s1-return-from-outer")
        let middleHeight = number("twoViewEyeY",app)
        heldDrag(app,from:CGVector(dx:0.25,dy:0.30),to:CGVector(dx:0.50,dy:0.30))
        settled(app,mode:"thirdPerson")
        XCTAssertEqual(number("twoViewEyeY",app),middleHeight,accuracy:0.0001)
        attach(app,"surface-s4-level-middle")
    }

    func testSurfaceS5AxisIsolationAndSmallReversal() {
        let app = launchDaily3D(surface:true)
        defer { app.terminate() }
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app,mode:"thirdPerson")
        let initial = actualPose(app)
        let bearing = number("surfaceBearing",app)
        let aimX = number("twoViewAimX",app), aimZ = number("twoViewAimZ",app)
        let scene = readableStage(app)
        XCTAssertTrue(scene.exists)
        let start = scene.coordinate(withNormalizedOffset:CGVector(dx:0.35,dy:0.30))
        func drag(_ dx: CGFloat, _ dy: CGFloat) {
            start.press(forDuration:0.1,thenDragTo:start.withOffset(CGVector(dx:dx,dy:dy)),
                withVelocity:.slow,thenHoldForDuration:0.4)
            settled(app,mode:"thirdPerson")
        }
        // Deliberate cross-axis drift must not climb out of a horizontal height ring.
        drag(60, 18)
        assertHeldSamples(app,axis:"horizontal")
        XCTAssertEqual(number("surfaceTravel",app),0.5,accuracy:0.00001)
        XCTAssertEqual(number("twoViewEyeY",app),initial.y,accuracy:0.0001)
        XCTAssertGreaterThan(angleDifference(number("surfaceBearing",app),bearing),0.01)
        attach(app,"surface-s5-horizontal-drift")
        let afterHorizontal = number("surfaceBearing",app)
        // Releasing starts a fresh decision. Vertical drift must not orbit.
        drag(12, 40)
        assertHeldSamples(app,axis:"vertical")
        XCTAssertGreaterThan(number("surfaceTravel",app),0.5)
        XCTAssertEqual(number("surfaceBearing",app),afterHorizontal,accuracy:0.00001)
        attach(app,"surface-s5-vertical-drift")
        let distance = number("simpleDistance",app)
        drag(-4, -16)
        assertHeldSamples(app,axis:"vertical")
        XCTAssertLessThan(number("simpleDistance",app),distance-0.005)
        XCTAssertEqual(number("surfaceBearing",app),afterHorizontal,accuracy:0.00001)
        let travel = number("surfaceTravel",app)
        drag(-35, -10)
        assertHeldSamples(app,axis:"horizontal")
        XCTAssertEqual(number("surfaceTravel",app),travel,accuracy:0.00001)
        XCTAssertLessThan(angleDifference(number("surfaceBearing",app),afterHorizontal),-0.005,
                          "Left drag must reverse the signed bearing change")
        XCTAssertEqual(number("twoViewAimX",app),aimX,accuracy:0.00001)
        XCTAssertEqual(number("twoViewAimZ",app),aimZ,accuracy:0.00001)
        attach(app,"surface-s5-small-reverse")
    }

    func testSurfaceRealShotReturnsToLatestReference() {
        let app = launchDaily3D(fixture:"progress",cameraScenario:0,surface:true)
        defer { attach(app,"s8-shot-exit-state"); app.terminate() }
        waitUntil(app) { app.buttons["dailyClearance.strike"].isEnabled && self.field("twoViewComputing",app) == "false" }
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app,mode:"thirdPerson")
        let entries = number("twoViewAutomaticEntryCount",app)
        let solves = number("twoViewCompletedSolves",app)
        let before = dailyStatus(app)
        attach(app,"surface-s1-before-strike")
        app.buttons["dailyClearance.strike"].tap()
        waitUntil(app,timeout:90) {
            self.number("twoViewAutomaticEntryCount",app) == entries+1 &&
            self.number("twoViewCompletedSolves",app) > solves &&
            self.field("twoViewComputing",app) == "false" &&
            self.field("twoViewMoving",app) == "false" && app.buttons["dailyClearance.strike"].isEnabled
        }
        XCTAssertNotEqual(dailyStatus(app),before)
        XCTAssertFalse(dailyStatus(app).contains("目标无"))
        assertShotHeading(app)
        XCTAssertEqual(number("surfaceTravel",app),0.5,accuracy:0.001)
        XCTAssertEqual(number("simpleDistance",app),1.65,accuracy:0.001)
        attach(app,"surface-s1-next-shot")
    }

    func testMergedGlobalAimAndToggleOwnership() {
        let app = launchDaily3D(merged:true)
        defer { app.terminate() }
        XCTAssertFalse(app.buttons["shotCamera.firstPerson"].exists)
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app,mode:"thirdPerson")
        let initialAim = number("twoViewAimX",app)
        app.buttons["dailyClearance.observeTable"].tap()
        sleep(3)
        XCTAssertEqual(field("mergedGlobal",app),"true")
        heldDrag(app,from:CGVector(dx:0.25,dy:0.3),to:CGVector(dx:0.65,dy:0.31))
        sleep(1)
        XCTAssertEqual(field("mergedGlobal",app),"true")
        XCTAssertEqual(number("twoViewAimX",app),initialAim,accuracy:0.00001)
        attach(app,"merged-v5-global")
        let global = actualPose(app)
        app.buttons["shotCamera.temporaryTopDown"].tap()
        waitUntil(app) { self.field("mergedOverlay",app) == "true" }
        attach(app,"merged-v5-global-topdown")
        app.buttons["shotCamera.temporaryTopDown"].tap()
        waitUntil(app) { self.field("mergedOverlay",app) == "false" }
        assertActualPose(app,equals:global)
        XCTAssertEqual(field("mergedGlobal",app),"true")
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app,mode:"thirdPerson")
        heldDrag(app,from:CGVector(dx:0.25,dy:0.3),to:CGVector(dx:0.65,dy:0.31))
        settled(app,mode:"thirdPerson")
        XCTAssertNotEqual(number("twoViewAimX",app),initialAim)
        assertShotHeading(app)
        attach(app,"merged-v5-third-aim")
    }

    func testMergedFourFormationEndpoints() {
        for scenario in 0..<4 {
            let app = launchDaily3D(cameraScenario:scenario,merged:true)
            app.buttons["shotCamera.thirdPerson"].tap()
            settled(app,mode:"thirdPerson")
            attach(app,"merged-v5-formation-\(scenario)-default")
            for _ in 0..<2 { heldDrag(app,from:CGVector(dx:0.28,dy:0.85),to:CGVector(dx:0.29,dy:0.12)) }
            settled(app,mode:"thirdPerson")
            XCTAssertEqual(number("simpleDistance",app),0.9,accuracy:0.001)
            attach(app,"merged-v5-formation-\(scenario)-near")
            for _ in 0..<2 { heldDrag(app,from:CGVector(dx:0.28,dy:0.12),to:CGVector(dx:0.29,dy:0.85)) }
            settled(app,mode:"thirdPerson")
            XCTAssertEqual(number("simpleDistance",app),2,accuracy:0.001)
            attach(app,"merged-v5-formation-\(scenario)-far")
            app.terminate()
        }
    }

    private func overlayCoordinate(_ key: String, _ app: XCUIApplication) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(
            dx:number("overlay_\(key)X",app)-Double(app.frame.minX),
            dy:number("overlay_\(key)Y",app)-Double(app.frame.minY)))
    }

    func testMergedOverlaySelectionStaysOpenAndReturnsToLatestShot() {
        checkOverlaySelection(surface: false)
    }

    func testS6Ordinary2DAimDragRetainsOrthographicProjection() {
        let app = launchDaily3D(surface:true)
        defer { app.terminate() }
        app.buttons["freeplay.cameraMode"].tap()
        waitUntil(app) { self.field("twoViewOrtho",app) == "true" }
        let before = number("ordinary2DAimSamples",app)
        heldDrag(app,from:CGVector(dx:0.4,dy:0.78),to:CGVector(dx:0.7,dy:0.68))
        waitUntil(app) { self.number("ordinary2DAimSamples",app) > before }
        XCTAssertEqual(number("ordinary2DProjectionViolations",app),0,
                       "Every active aim callback must preserve 2D before the display loop can restore it")
        XCTAssertEqual(field("twoViewOrtho",app),"true")
        attach(app,"s6-ordinary-2d-after-held-aim")
        app.buttons["freeplay.cameraMode"].tap()
        waitUntil(app) { self.field("twoViewOrtho",app) == "false" }
        attach(app,"s6-perspective-restored")
    }

    func testS8RepeatedOverlayGeometryReplacement() {
        let app = launchDaily3D(surface:true)
        defer { app.terminate() }
        for cycle in 0..<6 {
            app.buttons["shotCamera.temporaryTopDown"].tap()
            waitUntil(app) { self.field("mergedOverlay",app) == "true" }
            let builds = number("overlayBuilds",app)
            let key = cycle.isMultiple(of:2) ? "_1" : "_2"
            overlayCoordinate(key,app).tap()
            waitUntil(app) { self.field("mergedTarget",app) == key }
            let pocket = cycle % 6
            overlayCoordinate("pocket\(pocket)",app).tap()
            waitUntil(app) {
                self.field("mergedPocket",app) == String(pocket) && self.field("twoViewComputing",app) == "false"
            }
            XCTAssertEqual(number("overlayBuilds",app),builds)
            XCTAssertEqual(app.state,.runningForeground)
            app.buttons["shotCamera.temporaryTopDown"].tap()
            waitUntil(app) { self.field("mergedOverlay",app) == "false" && self.field("twoViewMoving",app) == "false" }
        }
        attach(app,"s8-overlay-six-cycles-complete")
    }

    func testSurfaceOverlaySelectionStaysOpenAndReturnsToLatestShot() {
        checkOverlaySelection(surface: true)
    }

    private func checkOverlaySelection(surface: Bool) {
        let app = launchDaily3D(merged:!surface, surface:surface)
        defer { app.terminate() }
        app.buttons["dailyClearance.observeTable"].tap()
        sleep(3)
        app.buttons["shotCamera.temporaryTopDown"].tap()
        waitUntil(app) { self.field("mergedOverlay",app) == "true" }
        let overlayBuilds = number("overlayBuilds",app)
        let entry = actualPose(app)
        let prior = field("mergedTarget",app)
        let diagnostics = app.descendants(matching:.any)["v63.cameraDiagnostics"].firstMatch.value as? String ?? ""
        let keys: [String] = (1...15).map { "_\($0)" }.filter { $0 != prior && diagnostics.contains("overlay_\($0)X=") }
        XCTAssertFalse(keys.isEmpty)
        overlayCoordinate(keys[0],app).tap()
        waitUntil(app) { self.field("mergedTarget",app) == keys[0] }
        XCTAssertEqual(field("mergedOverlay",app),"true")
        assertActualPose(app,equals:entry)
        attach(app,"merged-v5-topdown-selected-ball")
        waitUntil(app) { self.field("twoViewComputing",app) == "false" }
        XCTAssertEqual(number("overlayBuilds",app),overlayBuilds,"Selection and async prediction must keep the resident overlay")
        app.buttons["shotCamera.temporaryTopDown"].tap()
        waitUntil(app) { self.field("mergedGlobal",app) == "false" && self.field("twoViewMoving",app) == "false" }
        XCTAssertEqual(number("simpleDistance",app),1.65,accuracy:0.001)
        attach(app,"merged-v5-selected-ball-third-person")
        let selectedPose = actualPose(app)
        app.buttons["shotCamera.temporaryTopDown"].tap()
        waitUntil(app) { self.field("mergedOverlay",app) == "true" }
        let pocketBuilds = number("overlayBuilds",app)
        let pocket = (Int(field("mergedPocket",app) ?? "0")!+1)%6
        overlayCoordinate("pocket\(pocket)",app).tap()
        waitUntil(app) { self.field("mergedPocket",app) == String(pocket) }
        XCTAssertEqual(field("mergedOverlay",app),"true")
        assertActualPose(app,equals:selectedPose)
        XCTAssertEqual(number("overlayBuilds",app),pocketBuilds)
        attach(app,"merged-v5-topdown-selected-pocket")
        app.buttons["shotCamera.temporaryTopDown"].tap()
        waitUntil(app) { self.field("mergedOverlay",app) == "false" && self.field("twoViewComputing",app) == "false" }
        // Even when a pocket is infeasible the user's explicit selection survives.
        XCTAssertEqual(field("mergedTarget",app),keys[0])
        XCTAssertEqual(field("mergedPocket",app),String(pocket))
        attach(app,"merged-v5-topdown-edit-exit")
    }

    func testMergedOverlayCuePlacementPermissionsAndGrabOffset() {
        checkOverlayCuePlacement(surface: false)
    }

    func testSurfaceOverlayCuePlacementPermissionsAndGrabOffset() {
        checkOverlayCuePlacement(surface: true)
    }

    private func checkOverlayCuePlacement(surface: Bool) {
        for fixture in ["ballInHand","behindHeadString","selection"] {
            let app = launchDaily3D(fixture:fixture,merged:!surface,surface:surface)
            app.buttons["shotCamera.temporaryTopDown"].tap()
            waitUntil(app) { self.field("mergedOverlay",app) == "true" }
            let x = number("overlay_cueBallX",app), y = number("overlay_cueBallY",app)
            let sign:Double = x > Double(app.frame.midX) ? -1 : 1
            let grab = overlayCoordinate("cueBall",app).withOffset(CGVector(dx:5,dy:2))
            let destination = grab.withOffset(CGVector(dx:sign*45,dy:12))
            grab.press(forDuration:0.1,thenDragTo:destination,withVelocity:.slow,thenHoldForDuration:0.2)
            sleep(1)
            let newX = number("overlay_cueBallX",app), newY = number("overlay_cueBallY",app)
            if fixture == "selection" {
                XCTAssertEqual(newX,x,accuracy:0.5)
                XCTAssertEqual(newY,y,accuracy:0.5)
            } else {
                XCTAssertGreaterThan(hypot(newX-x,newY-y),5)
                if fixture == "ballInHand" {
                    XCTAssertEqual(newX-x,sign*45,accuracy:3)
                    XCTAssertEqual(newY-y,12,accuracy:3)
                }
            }
            XCTAssertEqual(field("mergedOverlay",app),"true")
            attach(app,"merged-v5-topdown-placement-\(fixture)")
            app.buttons["shotCamera.temporaryTopDown"].tap()
            waitUntil(app) { self.field("mergedOverlay",app) == "false" }
            app.terminate()
        }
    }

    func testSimpleCameraCuePalettePreservesPhysicalScale() {
        let app = launchDaily3D(simple: true)
        defer { app.terminate() }
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app, mode: "thirdPerson")
        let scale = number("simpleCueScale", app)
        XCTAssertGreaterThan(scale, 0)
        app.buttons["paletteBall_cueBall"].tap()
        sleep(1)
        attach(app, "simple-v4-cue-after-palette-pulse")
        XCTAssertEqual(number("simpleCueScale", app), scale, accuracy: 0.000001)
    }

    func testSimpleCameraNativeAimTravelAndOverlay() {
        let app = launchDaily3D(simple: true)
        defer { app.terminate() }
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app, mode: "thirdPerson")
        XCTAssertEqual(field("simpleCamera", app), "true")
        XCTAssertEqual(number("simpleDistance",app),1.65,accuracy:0.001)
        attach(app,"simple-v4-default")
        let start=actualPose(app)
        heldDrag(app,from:CGVector(dx:0.22,dy:0.2),to:CGVector(dx:0.60,dy:0.21))
        settled(app,mode:"thirdPerson")
        assertShotHeading(app)
        XCTAssertEqual(number("simpleDistance",app),1.65,accuracy:0.001)
        XCTAssertEqual(actualPose(app).y,start.y,accuracy:0.002)
        XCTAssertGreaterThan(abs(angleDifference(actualPose(app).yaw,start.yaw)),0.02)
        let stopped=actualPose(app)
        sleep(1)
        assertActualPose(app,equals:stopped)
        attach(app,"simple-v4-aim-right")
        heldDrag(app,from:CGVector(dx:0.30,dy:0.75),to:CGVector(dx:0.31,dy:0.22))
        settled(app,mode:"thirdPerson")
        XCTAssertLessThan(number("simpleDistance",app),1.5)
        XCTAssertLessThan(actualPose(app).y,stopped.y)
        XCTAssertEqual(angleDifference(actualPose(app).yaw,stopped.yaw),0,accuracy:0.002)
        attach(app,"simple-v4-near")
        heldDrag(app,from:CGVector(dx:0.30,dy:0.22),to:CGVector(dx:0.31,dy:0.90))
        settled(app,mode:"thirdPerson")
        XCTAssertGreaterThan(number("simpleDistance",app),1.65)
        attach(app,"simple-v4-far")
        let before=actualPose(app)
        app.buttons["shotCamera.temporaryTopDown"].press(forDuration:1.5)
        settled(app,mode:"thirdPerson")
        assertActualPose(app,equals:before)
        attach(app,"simple-v4-overlay-release")
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app,mode:"thirdPerson")
        XCTAssertEqual(number("simpleDistance",app),1.65,accuracy:0.001)
        assertShotHeading(app)
        attach(app,"simple-v4-reset-current-aim")
        app.buttons["shotCamera.firstPerson"].tap()
        settled(app,mode:"firstPerson")
        attach(app,"simple-v4-first-person")
    }

    func testSimpleCameraFourFormationDefaultAndNearImages() {
        for scenario in 0..<4 {
            let app=launchDaily3D(cameraScenario:scenario,simple:true)
            app.buttons["shotCamera.thirdPerson"].tap()
            settled(app,mode:"thirdPerson")
            XCTAssertEqual(number("simpleDistance",app),1.65,accuracy:0.001)
            XCTAssertEqual(number("simpleHeight",app),0.65,accuracy:0.001)
            assertShotHeading(app)
            attach(app,"simple-v4-formation-\(scenario)-default")
            heldDrag(app,from:CGVector(dx:0.28,dy:0.8),to:CGVector(dx:0.29,dy:0.2))
            settled(app,mode:"thirdPerson")
            attach(app,"simple-v4-formation-\(scenario)-near")
            app.terminate()
        }
    }

    // v3.1 keeps TP observation after release; explicit buttons and new selections reframe.
    // Plan §0 replaces the earlier simultaneous diagonal axes,
    // initial full-table framing and global reset. The new obligations below retain actual-pose,
    // measured HUD, accessibility, input routing and shot-intent protections.
    func testIconOnlyNamedViewsUseMeasuredReadableStageAndShotDefault() {
        let app = launchDaily3D()
        defer { app.terminate() }
        let third = app.buttons["shotCamera.thirdPerson"]
        let first = app.buttons["shotCamera.firstPerson"]
        let topDown = app.buttons["shotCamera.temporaryTopDown"]
        XCTAssertEqual(third.label, "第三人称")
        XCTAssertEqual(first.label, "第一人称")
        XCTAssertEqual(topDown.label, "临时俯视球桌")
        XCTAssertFalse(app.buttons["dailyClearance.observeTable"].exists)
        for button in [third, first, topDown] {
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertGreaterThanOrEqual(button.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
            XCTAssertEqual(button.staticTexts.count, 0, "Names remain accessible without visible button text")
        }
        first.tap()
        settled(app, mode: "firstPerson")
        XCTAssertEqual(first.value as? String, "已选中")
        XCTAssertEqual(third.value as? String, "未选中")
        third.tap()
        settled(app, mode: "thirdPerson")
        XCTAssertEqual(third.value as? String, "已选中")
        XCTAssertEqual(first.value as? String, "未选中")
        XCTAssertEqual(topDown.value as? String, "本杆视角")
        assertShotHeading(app)
        assertAtDefault(app)
        let stage = readableStage(app).frame
        XCTAssertEqual(number("twoViewReadableX", app), Double(stage.minX), accuracy: 1)
        XCTAssertEqual(number("twoViewReadableY", app), Double(stage.minY), accuracy: 1)
        XCTAssertEqual(number("twoViewReadableW", app), Double(stage.width), accuracy: 1)
        XCTAssertEqual(number("twoViewReadableH", app), Double(stage.height), accuracy: 1)
        XCTAssertGreaterThan(stage.width, 0)
        XCTAssertGreaterThan(stage.height, 0)
        attach(app, "shot-language-icon-only-along-shaft-default")
    }

    func testThirdPersonHorizontalDominantKeepsPoseAfterReleaseBothDirections() {
        let app = launchDaily3D()
        defer { app.terminate() }
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app, mode: "thirdPerson")
        let baseline = actualPose(app)
        let progress = number("twoViewProgress", app)
        let bearing = number("twoViewRailYaw", app)
        let shot = shotIntent(app)
        var heldOffsets: [Double] = []
        for (index, points) in [
            (CGVector(dx: 0.18, dy: 0.12), CGVector(dx: 0.50, dy: 0.21)),
            (CGVector(dx: 0.53, dy: 0.12), CGVector(dx: 0.21, dy: 0.21))
        ].enumerated() {
            app.buttons["shotCamera.thirdPerson"].tap()
            settled(app, mode: "thirdPerson")
            let dx = number("twoViewPanDX", app), dy = number("twoViewPanDY", app)
            attach(app, "shot-language-horizontal-\(index)-before-touch")
            heldDrag(app, from: points.0, to: points.1)
            settled(app, mode: "thirdPerson")
            assertHeldSamples(app, axis: "horizontal")
            XCTAssertGreaterThan(abs(number("twoViewPanDX", app) - dx), 10)
            XCTAssertEqual(number("twoViewPanDY", app), dy, accuracy: 0.01)
            XCTAssertEqual(number("twoViewHeldProgress", app), progress, accuracy: 0.01)
            let offset = angleDifference(number("twoViewHeldRailYaw", app), bearing)
            XCTAssertGreaterThan(abs(offset), 0.01)
            heldOffsets.append(offset)
            XCTAssertEqual(heldPose(app).fov, baseline.fov, accuracy: 0.05)
            assertActualPose(app, equals: heldPose(app))
            XCTAssertEqual(field("twoViewOwner", app), "manual")
            XCTAssertEqual(shotIntent(app), shot)
            attach(app, "shot-language-horizontal-\(index)-released-held")
        }
        XCTAssertLessThan(heldOffsets[0] * heldOffsets[1], 0, "Opposite drags must orbit in opposite directions")
    }

    func testThirdPersonVerticalDominantKeepsApproachAndRetreatWithoutYawDrift() {
        let app = launchDaily3D()
        defer { app.terminate() }
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app, mode: "thirdPerson")
        let baseline = actualPose(app)
        let progress = number("twoViewProgress", app)
        let bearing = number("twoViewRailYaw", app)
        let dx = number("twoViewPanDX", app), dy = number("twoViewPanDY", app)
        let shot = shotIntent(app)
        attach(app, "shot-language-vertical-before-touch")
        heldDrag(app, from: CGVector(dx: 0.18, dy: 0.78), to: CGVector(dx: 0.22, dy: 0.12))
        settled(app, mode: "thirdPerson")
        assertHeldSamples(app, axis: "vertical")
        XCTAssertEqual(number("twoViewPanDX", app), dx, accuracy: 0.01)
        XCTAssertGreaterThan(abs(number("twoViewPanDY", app) - dy), 10)
        XCTAssertLessThan(number("twoViewHeldProgress", app), progress - 0.01)
        XCTAssertEqual(angleDifference(number("twoViewHeldRailYaw", app), bearing), 0, accuracy: 0.005)
        let held = heldPose(app)
        XCTAssertLessThan(held.y, baseline.y - 0.02)
        XCTAssertLessThan(held.pitch, baseline.pitch - 0.01)
        XCTAssertEqual(held.fov, baseline.fov, accuracy: 0.05)
        assertActualPose(app, equals: heldPose(app))
        XCTAssertEqual(shotIntent(app), shot)
        attach(app, "shot-language-vertical-released-held")

        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app, mode: "thirdPerson")
        assertAtDefault(app)
        let retreatDX = number("twoViewPanDX", app), retreatDY = number("twoViewPanDY", app)
        attach(app, "shot-language-retreat-before-touch")
        heldDrag(app, from: CGVector(dx: 0.18, dy: 0.12), to: CGVector(dx: 0.22, dy: 0.78))
        settled(app, mode: "thirdPerson")
        assertHeldSamples(app, axis: "vertical")
        XCTAssertEqual(number("twoViewPanDX", app), retreatDX, accuracy: 0.01)
        XCTAssertGreaterThan(abs(number("twoViewPanDY", app) - retreatDY), 10)
        XCTAssertGreaterThan(number("twoViewHeldProgress", app), progress + 0.01)
        XCTAssertEqual(angleDifference(number("twoViewHeldRailYaw", app), bearing), 0, accuracy: 0.005)
        let retreat = heldPose(app)
        XCTAssertGreaterThanOrEqual(retreat.y, baseline.y - 0.005)
        XCTAssertGreaterThanOrEqual(retreat.pitch, baseline.pitch - 0.005)
        XCTAssertEqual(retreat.fov, baseline.fov, accuracy: 0.05)
        XCTAssertGreaterThan(hypot(retreat.x - baseline.x, retreat.z - baseline.z), 0.01,
                             "Retreat progress alone cannot prove the actual eye moved")
        assertActualPose(app, equals: heldPose(app))
        XCTAssertEqual(shotIntent(app), shot)
        attach(app, "shot-language-retreat-released-held")
    }

    func testFirstPersonTemporaryHeadTurnKeepsEyeAndShotIntentThenReturnsToShaft() {
        let app = launchDaily3D()
        defer { app.terminate() }
        app.buttons["shotCamera.firstPerson"].tap()
        settled(app, mode: "firstPerson")
        let baseline = actualPose(app)
        let shot = shotIntent(app)
        let dx = number("twoViewPanDX", app), dy = number("twoViewPanDY", app)
        attach(app, "shot-language-first-person-before-touch")
        heldDrag(app, from: CGVector(dx: 0.18, dy: 0.12), to: CGVector(dx: 0.48, dy: 0.20))
        settled(app, mode: "firstPerson")
        assertHeldSamples(app, axis: "horizontal")
        let held = heldPose(app)
        XCTAssertGreaterThan(abs(angleDifference(held.yaw, baseline.yaw)), 0.01)
        XCTAssertEqual(held.x, baseline.x, accuracy: 0.005)
        XCTAssertEqual(held.y, baseline.y, accuracy: 0.005)
        XCTAssertEqual(held.z, baseline.z, accuracy: 0.005)
        XCTAssertEqual(held.fov, baseline.fov, accuracy: 0.05)
        XCTAssertGreaterThan(abs(number("twoViewPanDX", app) - dx), 10)
        XCTAssertEqual(number("twoViewPanDY", app), dy, accuracy: 0.01)
        XCTAssertEqual(shotIntent(app), shot)
        assertActualPose(app, equals: baseline)
        XCTAssertEqual(field("twoViewOwner", app), "automatic")
        XCTAssertEqual(app.buttons["shotCamera.firstPerson"].value as? String, "已选中")
        attach(app, "shot-language-first-person-released-rod-axis")
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app, mode: "thirdPerson")
        assertShotHeading(app)
        assertAtDefault(app)
        attach(app, "shot-language-switch-enters-current-shot-default")
    }

    // The user replaced the main-camera top-down / shaft-up policy with a cutout overlay.
    // Native held video and the original alpha PNG are still required for visual acceptance.
    func testTemporaryTopDownRequiresHoldKeepsPerspectiveUnderCanonicalOverlay() {
        var rightDirections: Set<Int> = []
        for scenario in [0, 5] {
            let app = launchDaily3D(fixture: "progress", cameraScenario: scenario)
            waitUntil(app) { app.buttons["dailyClearance.strike"].isEnabled }
            let topDown = app.buttons["shotCamera.temporaryTopDown"]
            let activation = number("twoView2DActivationCount", app)
            topDown.tap()
            let unexpected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.number("twoView2DActivationCount", app) > activation
            }, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [unexpected], timeout: 1.2), .timedOut,
                           "Short tap must not enter temporary or permanent 2D")
            XCTAssertEqual(field("twoViewTemporary2D", app), "false")
            XCTAssertEqual(field("twoViewOrtho", app), "false")
            for (identifier, mode) in [("shotCamera.thirdPerson", "thirdPerson"),
                                       ("shotCamera.firstPerson", "firstPerson")] {
                app.buttons[identifier].tap()
                settled(app, mode: mode)
                let baseline = actualPose(app)
                let before = number("twoView2DActivationCount", app)
                let shot = shotIntent(app)
                attach(app, "shot-overlay-formation-\(scenario)-\(mode)-before-hold")
                topDown.press(forDuration: 1.5)
                settled(app, mode: mode)
                waitUntil(app) { self.number("twoView2DActivationCount", app) == before + 1 }
                XCTAssertGreaterThan(number("twoView2DHeldSamples", app), 2)
                XCTAssertEqual(field("twoViewOverlayHeldSeen", app), "true")
                XCTAssertEqual(field("twoViewOverlayHeldOrthoChanged", app), "false")
                XCTAssertEqual(number("twoViewOverlayHeldMainMatrixDelta", app), 0, accuracy: 0.0001)
                XCTAssertEqual(number("twoViewOverlayHeldMainFOVDelta", app), 0, accuracy: 0.0001)
                XCTAssertEqual(field("twoViewOverlayHeldRoomVisible", app), "true")
                XCTAssertEqual(number("twoViewOverlayHoldCaptureCount", app), 1,
                               "Stable layout holds one image, not a second continuously rendered view")
                XCTAssertEqual(field("twoViewOverlayResidentRenderer", app), "false")
                XCTAssertGreaterThan(number("twoViewOverlayImageWidth", app), 0)
                XCTAssertGreaterThan(number("twoViewOverlayImageHeight", app), 0)
                assertOverlayLayoutDiagnostics(app)

                // SceneKit X is the table long axis; landscape standard views have +/-X right
                // and +/-Z up. The reference is TP even when the visible base is first-person.
                XCTAssertEqual(number("twoView2DUpX", app), 0, accuracy: 0.0001)
                XCTAssertEqual(abs(number("twoView2DUpZ", app)), 1, accuracy: 0.0001)
                XCTAssertEqual(number("twoView2DScreenRightZ", app), 0, accuracy: 0.0001)
                let rightX = number("twoView2DScreenRightX", app)
                XCTAssertEqual(abs(rightX), 1, accuracy: 0.0001)
                rightDirections.insert(rightX > 0 ? 1 : -1)
                if mode == "thirdPerson" {
                    XCTAssertEqual(field("twoView2DReferenceSource", app), "TP_actual")
                    XCTAssertEqual(angleDifference(number("twoView2DReferenceYaw", app), baseline.yaw),
                                   0, accuracy: 0.005)
                } else {
                    XCTAssertEqual(field("twoView2DReferenceSource", app), "shot_TP_default")
                }
                XCTAssertEqual(field("twoViewTemporary2D", app), "false")
                XCTAssertEqual(field("twoViewOrtho", app), "false")
                XCTAssertEqual(field("twoViewOverlayActive", app), "false")
                XCTAssertEqual(topDown.value as? String, "本杆视角")
                XCTAssertEqual(app.buttons["freeplay.cameraMode"].value as? String, "3D")
                XCTAssertEqual(shotIntent(app), shot)
                assertActualPose(app, equals: baseline)
                attach(app, "shot-overlay-formation-\(scenario)-\(mode)-released-same-perspective")
            }
            app.terminate()
        }
        XCTAssertEqual(rightDirections, Set([-1, 1]), "Opposite real shot views exercise both canonical orientations")
    }

    func testManualNewBallSelectionEntersSolvedShotThirdPersonButPowerKeepsFirstPerson() {
        let app = launchDaily3D()
        defer { app.terminate() }
        waitUntil(app) { app.buttons["dailyClearance.strike"].isEnabled && self.field("twoViewComputing", app) == "false" }
        app.buttons["shotCamera.firstPerson"].tap()
        settled(app, mode: "firstPerson")
        let entries = number("twoViewAutomaticEntryCount", app)
        let solves = number("twoViewCompletedSolves", app)
        let ball = app.buttons["paletteBall__2"]
        XCTAssertTrue(ball.isHittable)
        attach(app, "shot-selection-first-before-real-ball-2")
        ball.tap()
        waitUntil(app) {
            self.number("twoViewCompletedSolves", app) > solves &&
            self.field("twoViewComputing", app) == "false" &&
            self.number("twoViewAutomaticEntryCount", app) == entries + 1 &&
            self.field("twoViewMode", app) == "thirdPerson" && self.field("twoViewMoving", app) == "false"
        }
        XCTAssertTrue(dailyStatus(app).contains("目标_2"))
        XCTAssertTrue(app.buttons["dailyClearance.strike"].isEnabled)
        assertShotHeading(app)
        assertAtDefault(app)
        attach(app, "shot-selection-new-ball-solved-third-default")

        app.buttons["shotCamera.firstPerson"].tap()
        settled(app, mode: "firstPerson")
        let powerEntries = number("twoViewAutomaticEntryCount", app)
        let powerSolves = number("twoViewCompletedSolves", app)
        let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch
        let priorPower = power.value as? String
        XCTAssertTrue(power.isHittable)
        power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).press(forDuration: 0.1,
            thenDragTo: power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)))
        waitUntil(app) {
            (power.value as? String) != priorPower && self.number("twoViewCompletedSolves", app) > powerSolves &&
            self.field("twoViewComputing", app) == "false" && app.buttons["dailyClearance.strike"].isEnabled
        }
        XCTAssertEqual(number("twoViewAutomaticEntryCount", app), powerEntries)
        XCTAssertEqual(field("twoViewMode", app), "firstPerson")
        XCTAssertEqual(app.buttons["shotCamera.firstPerson"].value as? String, "已选中")
        XCTAssertTrue(dailyStatus(app).contains("目标_2"))
        attach(app, "shot-selection-power-recomputed-still-first")
    }

    func testRealShotSettlementRecommendationEntersCurrentShotThirdPerson() {
        let app = launchDaily3D(fixture: "progress", cameraScenario: 0)
        defer { app.terminate() }
        waitUntil(app) { app.buttons["dailyClearance.strike"].isEnabled && self.field("twoViewComputing", app) == "false" }
        app.buttons["shotCamera.firstPerson"].tap()
        settled(app, mode: "firstPerson")
        let entries = number("twoViewAutomaticEntryCount", app)
        let solves = number("twoViewCompletedSolves", app)
        let before = dailyStatus(app)
        XCTAssertTrue(before.contains("剩余 3 球"))
        attach(app, "shot-recommendation-before-real-strike-first")
        app.buttons["dailyClearance.strike"].tap()
        // This is a real physics/rules/solver path. No feasible next shot or terminal/scratch
        // fixture outcome is a failed coverage case to inspect, never an automatic acceptance.
        waitUntil(app, timeout: 90) {
            self.number("twoViewAutomaticEntryCount", app) == entries + 1 &&
            self.number("twoViewCompletedSolves", app) > solves &&
            self.field("twoViewComputing", app) == "false" &&
            self.field("twoViewMode", app) == "thirdPerson" && self.field("twoViewMoving", app) == "false" &&
            app.buttons["dailyClearance.strike"].isEnabled
        }
        XCTAssertNotEqual(dailyStatus(app), before)
        XCTAssertFalse(dailyStatus(app).contains("目标无"))
        assertShotHeading(app)
        assertAtDefault(app)
        attach(app, "shot-recommendation-settled-legal-next-third-default")
    }

    /// These four real formations exercise entry and a native held gesture. Whole-table visibility
    /// and per-ball occlusion are reviewed in original frames, not asserted from the old s=1 model.
    func testCaptureShotDefaultsAndHeldObservationsForLongShortRailAndLargeCut() {
        for (scenario, name) in [(0, "long-table"), (3, "near-short-rail"),
                                 (4, "near-long-rail"), (13, "large-cut-near-corner")] {
            let app = launchDaily3D(fixture: "progress", cameraScenario: scenario)
            waitUntil(app) {
                let hud = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch.value as? String ?? ""
                return hud.contains("剩余 3 球") && app.buttons["dailyClearance.strike"].isEnabled
            }
            app.buttons["shotCamera.thirdPerson"].tap()
            settled(app, mode: "thirdPerson")
            let baseline = actualPose(app)
            let shot = shotIntent(app)
            assertShotHeading(app)
            assertAtDefault(app)
            attach(app, "shot-language-formation-\(scenario)-\(name)-third-default")
            heldDrag(app, from: CGVector(dx: 0.18, dy: 0.12), to: CGVector(dx: 0.48, dy: 0.20))
            settled(app, mode: "thirdPerson")
            assertHeldSamples(app, axis: "horizontal")
            XCTAssertGreaterThan(abs(angleDifference(heldPose(app).yaw, baseline.yaw)), 0.01)
            assertActualPose(app, equals: heldPose(app))
            XCTAssertEqual(shotIntent(app), shot)
            attach(app, "shot-language-formation-\(scenario)-\(name)-third-released-held")

            app.buttons["shotCamera.thirdPerson"].tap()
            settled(app, mode: "thirdPerson")
            assertAtDefault(app)
            attach(app, "landscape-v31-formation-\(scenario)-explicit-reset")
            heldDrag(app, from: CGVector(dx: 0.18, dy: 0.78), to: CGVector(dx: 0.22, dy: 0.12))
            settled(app, mode: "thirdPerson")
            assertActualPose(app, equals: heldPose(app))
            attach(app, "landscape-v31-formation-\(scenario)-approach-held")
            app.buttons["shotCamera.thirdPerson"].tap()
            settled(app, mode: "thirdPerson")
            let bearing = number("twoViewRailYaw", app)
            let progress = number("twoViewProgress", app)
            let retreatDX = number("twoViewPanDX", app), retreatDY = number("twoViewPanDY", app)
            attach(app, "shot-language-formation-\(scenario)-\(name)-retreat-before-touch")
            heldDrag(app, from: CGVector(dx: 0.18, dy: 0.12), to: CGVector(dx: 0.22, dy: 0.78))
            settled(app, mode: "thirdPerson")
            assertHeldSamples(app, axis: "vertical")
            XCTAssertEqual(number("twoViewPanDX", app), retreatDX, accuracy: 0.01)
            XCTAssertGreaterThan(abs(number("twoViewPanDY", app) - retreatDY), 10)
            XCTAssertEqual(angleDifference(number("twoViewHeldRailYaw", app), bearing), 0, accuracy: 0.005)
            let retreat = heldPose(app)
            XCTAssertGreaterThanOrEqual(retreat.y, baseline.y - 0.005)
            XCTAssertGreaterThanOrEqual(retreat.pitch, baseline.pitch - 0.005)
            XCTAssertEqual(retreat.fov, baseline.fov, accuracy: 0.05)
            let displaced = hypot(retreat.x - baseline.x, retreat.z - baseline.z) > 0.01
            let progressed = number("twoViewHeldProgress", app) > progress + 0.01
            let evidence = XCTAttachment(string: "scenario=\(scenario) retreat=\(displaced && progressed ? "observed" : "LIMITED-not-retreat-acceptance") defaultProgress=\(progress) heldProgress=\(number("twoViewHeldProgress", app)) defaultEye=\(baseline.x),\(baseline.y),\(baseline.z) heldEye=\(retreat.x),\(retreat.y),\(retreat.z)")
            evidence.name = "shot-language-formation-\(scenario)-retreat-capability"
            evidence.lifetime = .keepAlways
            add(evidence)
            assertActualPose(app, equals: heldPose(app))
            XCTAssertEqual(shotIntent(app), shot)
            attach(app, "shot-language-formation-\(scenario)-\(name)-retreat-released-held")
            app.buttons["shotCamera.firstPerson"].tap()
            settled(app, mode: "firstPerson")
            XCTAssertEqual(app.buttons["shotCamera.firstPerson"].value as? String, "已选中")
            XCTAssertGreaterThan(actualPose(app).fov, 0)
            attach(app, "shot-language-formation-\(scenario)-\(name)-first-default")
            app.terminate()
        }
    }

    func testLandscapeObservationCombinesAxesAndOverlayRestoresRetainedPose() {
        let app = launchDaily3D()
        defer { app.terminate() }
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app, mode: "thirdPerson")
        let baseline = actualPose(app), shot = shotIntent(app)
        heldDrag(app, from: CGVector(dx:0.18,dy:0.72), to: CGVector(dx:0.20,dy:0.30))
        settled(app, mode:"thirdPerson")
        let progressed = number("twoViewProgress",app)
        XCTAssertLessThan(progressed,number("twoViewDefaultProgress",app)-0.01)
        let released = actualPose(app)
        sleep(1)
        assertActualPose(app,equals:released)
        heldDrag(app, from: CGVector(dx:0.18,dy:0.12), to: CGVector(dx:0.40,dy:0.17))
        settled(app, mode:"thirdPerson")
        XCTAssertEqual(number("twoViewProgress",app),progressed,accuracy:0.0001)
        assertActualPose(app,equals:heldPose(app))
        let retained = actualPose(app)
        XCTAssertGreaterThan(hypot(retained.x-released.x,retained.z-released.z),0.01)
        attach(app,"landscape-v31-combined-retained")
        app.buttons["shotCamera.temporaryTopDown"].press(forDuration:1.5)
        settled(app,mode:"thirdPerson")
        assertActualPose(app,equals:retained)
        XCTAssertEqual(shotIntent(app),shot)
        attach(app,"landscape-v31-overlay-released-retained")
        app.buttons["shotCamera.thirdPerson"].tap()
        settled(app,mode:"thirdPerson")
        assertAtDefault(app)
        assertActualPose(app,equals:baseline)
    }

    func testLandscapeShortMiddlePocketAndReverseTableComposition() {
        for scenario in [1,5,8,12] {
            let app=launchDaily3D(fixture:"progress",cameraScenario:scenario)
            waitUntil(app) { app.buttons["dailyClearance.strike"].isEnabled }
            app.buttons["shotCamera.thirdPerson"].tap()
            settled(app,mode:"thirdPerson")
            assertShotHeading(app)
            attach(app,"landscape-v31-extra-\(scenario)-default")
            heldDrag(app,from:CGVector(dx:0.18,dy:0.78),to:CGVector(dx:0.22,dy:0.12))
            settled(app,mode:"thirdPerson")
            assertActualPose(app,equals:heldPose(app))
            attach(app,"landscape-v31-extra-\(scenario)-approach")
            app.buttons["shotCamera.thirdPerson"].tap()
            settled(app,mode:"thirdPerson")
            heldDrag(app,from:CGVector(dx:0.18,dy:0.12),to:CGVector(dx:0.22,dy:0.78))
            settled(app,mode:"thirdPerson")
            assertActualPose(app,equals:heldPose(app))
            attach(app,"landscape-v31-extra-\(scenario)-retreat")
            app.terminate()
        }
    }

    private func launchDaily3D(fixture: String = "selection", cameraScenario: Int? = nil, simple: Bool = false, merged: Bool = false, surface: Bool = false) -> XCUIApplication {
        var arguments = [
            "-deeplink.dailyClearance", "-dailyClearance.resetState",
            "-dailyClearance.preferredGame.v1", "chineseEightBall",
            "-dailyClearance.fixture=\(fixture)", "-v63.cameraDiagnostics"
        ]
        // Surface scenarios exercise the production default, with no camera feature flags.
        if !surface { arguments.append("-dailyClearance.twoViewCamera") }
        if simple { arguments.append("-dailyClearance.simpleCamera") }
        if merged { arguments.append("-dailyClearance.mergedCamera") }
        if let cameraScenario { arguments.append("-dailyClearance.cameraScenario=\(cameraScenario)") }
        // Same clean-launch contract as the shared helper, with the snapshot export environment
        // installed before launch. Only diagnostics builds with the explicit flag write PNGs.
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                               "-hasCompletedOnboarding", "YES", "-resetDebugPremium"] + arguments
        app.launchEnvironment["TWO_VIEW_OVERLAY_DIAG_DIR"] = "documents"
        app.launch()
        for _ in 0..<2 {
            sleep(3)
            if app.state == .runningForeground { break }
            app.launch()
        }
        XCTAssertEqual(app.state, .runningForeground)
        let toggle = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 20))
        if toggle.value as? String != "3D" { toggle.tap() }
        XCTAssertTrue(app.buttons["shotCamera.thirdPerson"].waitForExistence(timeout: 15))
        waitUntil(app) { self.field("twoViewMode", app) != nil }
        return app
    }

    private func dailyStatus(_ app: XCUIApplication) -> String {
        app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch.value as? String ?? ""
    }

    private func assertOverlayLayoutDiagnostics(_ app: XCUIApplication) {
        // Window-point projection is only a diagnostic: original image and native HUD overlap
        // must be reviewed independently. The working fit uses a 4pt rim, not a new 90% gate.
        let stage = readableStage(app).frame
        let minX = number("twoViewOverlayTableMinX", app), maxX = number("twoViewOverlayTableMaxX", app)
        let minY = number("twoViewOverlayTableMinY", app), maxY = number("twoViewOverlayTableMaxY", app)
        XCTAssertGreaterThan(maxX, minX)
        XCTAssertGreaterThan(maxY, minY)
        XCTAssertGreaterThan(maxX - minX, maxY - minY, "Landscape table long axis is horizontal")
        XCTAssertGreaterThanOrEqual(minX, Double(stage.minX) - 2)
        XCTAssertLessThanOrEqual(maxX, Double(stage.maxX) + 2)
        XCTAssertGreaterThanOrEqual(minY, Double(stage.minY) - 2)
        XCTAssertLessThanOrEqual(maxY, Double(stage.maxY) + 2)
        XCTAssertEqual((minX + maxX) / 2, Double(stage.midX), accuracy: 2)
        XCTAssertEqual((minY + maxY) / 2, Double(stage.midY), accuracy: 2)
        let horizontalGap = Double(stage.width) - (maxX - minX)
        let verticalGap = Double(stage.height) - (maxY - minY)
        XCTAssertEqual(min(horizontalGap, verticalGap), 8, accuracy: 3,
                       "At least one axis reaches the working four-point inset on both sides")
        XCTAssertGreaterThan(number("twoViewOverlayFrameWidth", app), 0)
        XCTAssertGreaterThan(number("twoViewOverlayFrameHeight", app), 0)
    }

    private func readableStage(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["freeplay.stage"].firstMatch
    }

    private func heldDrag(_ app: XCUIApplication, from: CGVector, to: CGVector) {
        let stage = readableStage(app)
        // Synchronous XCUI injection cannot query AX mid-touch. Native recording supplies the
        // held images; persistent diagnostics supply the actual samples from this active gesture.
        stage.coordinate(withNormalizedOffset: from).press(forDuration: 0.1,
            thenDragTo: stage.coordinate(withNormalizedOffset: to), withVelocity: .slow,
            thenHoldForDuration: 1.5)
        XCTAssertEqual(app.state, .runningForeground)
    }

    private func assertHeldSamples(_ app: XCUIApplication, axis: String) {
        XCTAssertEqual(field("twoViewGestureAxis", app), axis)
        XCTAssertGreaterThan(number("twoViewHeldSamples", app), 5,
                             "Must have actual samples while the native touch was still down")
    }

    private func assertShotHeading(_ app: XCUIApplication) {
        let x = number("twoViewAimX", app), z = number("twoViewAimZ", app)
        XCTAssertGreaterThan(hypot(x, z), 0.0001)
        XCTAssertEqual(angleDifference(number("twoViewHeading", app), atan2(-z, -x)), 0,
                       accuracy: 0.01, "Entry gaze follows the current shaft, not a remembered orbit")
    }

    private func assertAtDefault(_ app: XCUIApplication) {
        assertActualPose(app, equals: defaultPose(app))
        XCTAssertEqual(number("twoViewProgress", app), number("twoViewDefaultProgress", app), accuracy: 0.01)
    }

    private func shotIntent(_ app: XCUIApplication) -> [String?] {
        let values = [app.descendants(matching: .any)["shotStage.powerBar"].firstMatch.value as? String,
                      app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch.value as? String,
                      field("twoViewAimX", app), field("twoViewAimZ", app)]
        for value in values { XCTAssertNotNil(value, "Shot comparison requires real HUD/power/aim values") }
        return values
    }

    private func settled(_ app: XCUIApplication, mode: String) {
        waitUntil(app) {
            self.field("twoViewMode", app) == mode && self.field("twoViewMoving", app) == "false"
        }
    }

    private func waitUntil(_ app: XCUIApplication, timeout: TimeInterval = 15, _ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: app)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result != .completed { attach(app,"camera-wait-timeout") }
        XCTAssertEqual(result, .completed)
    }

    private func field(_ name: String, _ app: XCUIApplication) -> String? {
        let diagnostics = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch
        guard let text = diagnostics.value as? String else { return nil }
        return text.split(separator: " ").first { $0.hasPrefix(name + "=") }
            .map { String($0.dropFirst(name.count + 1)) }
    }

    private func number(_ name: String, _ app: XCUIApplication) -> Double {
        guard let text = field(name, app), let value = Double(text), value.isFinite else {
            XCTFail("Missing finite diagnostic \(name)")
            return .nan
        }
        return value
    }

    private struct ActualPose {
        let x, y, z, yaw, pitch, fov: Double
    }

    private func actualPose(_ app: XCUIApplication) -> ActualPose {
        pose(app, prefix: "twoView", heading: "twoViewHeading", pitch: "twoViewPitchDown", fov: "twoViewFOV")
    }

    private func heldPose(_ app: XCUIApplication) -> ActualPose {
        pose(app, prefix: "twoViewHeld", heading: "twoViewHeldHeading", pitch: "twoViewHeldPitchDown", fov: "twoViewHeldFOV")
    }

    private func defaultPose(_ app: XCUIApplication) -> ActualPose {
        pose(app, prefix: "twoViewDefault", heading: "twoViewDefaultHeading", pitch: "twoViewDefaultPitchDown", fov: "twoViewDefaultFOV")
    }

    private func pose(_ app: XCUIApplication, prefix: String, heading: String, pitch: String, fov: String) -> ActualPose {
        ActualPose(x: number(prefix + "EyeX", app), y: number(prefix + "EyeY", app),
                   z: number(prefix + "EyeZ", app), yaw: number(heading, app),
                   pitch: number(pitch, app), fov: number(fov, app))
    }

    private func angleDifference(_ lhs: Double, _ rhs: Double) -> Double {
        atan2(sin(lhs - rhs), cos(lhs - rhs))
    }

    private func assertActualPose(_ app: XCUIApplication, equals expected: ActualPose,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let actual = actualPose(app)
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.z, expected.z, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(angleDifference(actual.yaw, expected.yaw), 0, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.pitch, expected.pitch, accuracy: 0.005, file: file, line: line)
        XCTAssertEqual(actual.fov, expected.fov, accuracy: 0.05, file: file, line: line)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let diagnostics = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch
        let pose = XCTAttachment(string: diagnostics.value as? String ?? "missing diagnostics")
        pose.name = name + "-actual-and-held-pose"
        pose.lifetime = .keepAlways
        add(pose)
    }
}
