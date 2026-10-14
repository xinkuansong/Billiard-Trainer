import XCTest

final class AngleDynamicAssistUITests: XCTestCase {
    private func menuItem(_ key: String, in app: XCUIApplication) -> XCUIElement {
        let item = app.buttons["angleDynamic." + key]
        let scroll = app.scrollViews["dailyClearance.menuScroll"]
        for _ in 0..<3 where !item.isHittable { scroll.swipeUp() }
        XCTAssertTrue(item.isHittable)
        return item
    }

    func testDisplayOptionsAndCameraRoundTrip() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium",
            "-dailyInteraction.sharedPage=angleDynamic", "-v54.forceDark",
            "-angleDynamic.showsAimLine", "YES", "-angleDynamic.showsPotLine", "YES",
            "-angleDynamic.showsGhost3D", "NO", "-angleDynamic.showsAimPipe", "NO", "-angleDynamic.showsPotPipe", "NO"])
        let more = app.buttons["angleDynamic.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 25))
        let metrics = app.descendants(matching: .any).matching(identifier: "angleDynamic.metrics").firstMatch
        let original = metrics.label
        func snap(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; self.add(attachment)
        }
        func menu() { more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        snap("angle-page-2d-off")
        menu()
        snap("angle-page-settings-off")
        for key in ["ghost3D", "aimPipe", "potPipe"] {
            let item = menuItem(key, in: app)
            XCTAssertTrue(item.isHittable)
            XCTAssertEqual(item.value as? String, "")
            item.tap()
            XCTAssertEqual(metrics.label, original)
            menu()
            XCTAssertEqual(item.value as? String, "已选")
        }
        snap("angle-page-settings-on")
        app.buttons["angleDynamic.dismissMenu"].tap()
        snap("angle-page-2d-on")
        menu(); app.buttons["angleDynamic.cameraMode"].tap()
        app.buttons["angleDynamic.dismissMenu"].tap()
        XCTAssertEqual(metrics.label, original)
        snap("angle-page-3d-on")
        menu(); app.buttons["angleDynamic.cameraMode"].tap()
        app.buttons["angleDynamic.dismissMenu"].tap()
        XCTAssertEqual(metrics.label, original)
        snap("angle-page-2d-return")
        for key in ["ghost3D", "aimPipe", "potPipe"] {
            menu(); menuItem(key, in: app).tap()
        }
        snap("angle-page-2d-restored")
        app.terminate()
    }

    func testIndependentLineOptionsAndLabels() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium",
            "-dailyInteraction.sharedPage=angleDynamic", "-v54.forceDark",
            "-angleDynamic.showsAimLine", "YES", "-angleDynamic.showsPotLine", "YES",
            "-angleDynamic.showsGhost3D", "NO", "-angleDynamic.showsAimPipe", "NO", "-angleDynamic.showsPotPipe", "NO"])
        let more = app.buttons["angleDynamic.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 25))
        func menu() { more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        func snap(_ name: String) {
            let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            a.name = name; a.lifetime = .keepAlways; self.add(a)
        }
        func visible(_ index: Int) -> Bool {
            let label = app.staticTexts["angleDiagram.label.\(index)"]
            return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: label)], timeout: 3) == .completed
        }
        func hidden(_ index: Int) -> Bool {
            let label = app.staticTexts["angleDiagram.label.\(index)"]
            return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == false"), object: label)], timeout: 3) == .completed
        }
        menu()
        XCTAssertEqual(menuItem("aimLine", in: app).value as? String, "已选")
        XCTAssertEqual(menuItem("potLine", in: app).value as? String, "已选")
        snap("lines-settings-default-on")
        menuItem("aimLine", in: app).tap()
        snap("lines-pot-only")
        menu()
        XCTAssertEqual(menuItem("aimLine", in: app).value as? String, "")
        app.buttons["angleDynamic.dismissMenu"].tap()
        XCTAssertTrue(hidden(1)); XCTAssertTrue(visible(2)); XCTAssertTrue(visible(0))
        menu(); menuItem("potLine", in: app).tap()
        XCTAssertTrue(hidden(1)); XCTAssertTrue(hidden(2)); XCTAssertTrue(visible(0))
        snap("lines-both-off-ring-retained")
        for key in ["ghost3D", "aimPipe", "potPipe"] { menu(); menuItem(key, in: app).tap() }
        snap("lines-off-pipes-on")
        menu(); app.buttons["angleDynamic.cameraMode"].tap()
        app.buttons["angleDynamic.dismissMenu"].tap()
        XCTAssertTrue(hidden(1)); XCTAssertTrue(hidden(2))
        snap("lines-off-pipes-on-3d")
        menu(); menuItem("aimLine", in: app).tap()
        XCTAssertTrue(visible(1)); XCTAssertTrue(hidden(2))
        snap("lines-aim-only-3d")
        menu(); menuItem("potLine", in: app).tap()
        app.terminate()
    }

    func testOtherTeachingPageHasNoNewOptions() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-dailyInteraction.sharedPage=separation", "-v54.forceLight"])
        let more = app.buttons["separationAngleAtlas.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 25))
        more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["menu.tableGrid"].exists)
        for key in ["aimLine", "potLine", "ghost3D", "aimPipe", "potPipe"] { XCTAssertFalse(app.buttons["angleDynamic." + key].exists) }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "separation-settings-unchanged"; attachment.lifetime = .keepAlways; add(attachment)
        app.terminate()
    }
}
