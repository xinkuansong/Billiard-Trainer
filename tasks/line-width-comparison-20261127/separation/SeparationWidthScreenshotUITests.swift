
final class SeparationWidthScreenshotUITests: XCTestCase {
    private func node(_ app: XCUIApplication,_ id:String)->XCUIElement {
        app.descendants(matching:.any).matching(identifier:id).firstMatch
    }
    private func more(_ app:XCUIApplication) {
        app.buttons["freeplay.moreMenu"].tap()
        XCTAssertTrue(node(app,"dailyClearance.menuPanel").waitForExistence(timeout:5))
    }
    private func item(_ app:XCUIApplication,_ id:String)->XCUIElement {
        let x=app.buttons[id]
        for _ in 0..<4 {
            if x.exists && x.isHittable { return x }
            app.scrollViews["dailyClearance.menuScroll"].swipeUp()
        }
        XCTAssertTrue(x.isHittable,id);return x
    }
    private func close(_ app:XCUIApplication) {
        if app.buttons["dailyClearance.menuClose"].exists { app.buttons["dailyClearance.menuClose"].tap() }
        else { app.buttons["关闭菜单"].firstMatch.coordinate(withNormalizedOffset:.init(dx:0.1,dy:0.5)).tap() }
        XCTAssertTrue(app.scrollViews["dailyClearance.menuScroll"].waitForNonExistence(timeout:5))
    }
    private func settled(_ app:XCUIApplication) {
        let diag=node(app,"v63.cameraDiagnostics")
        let wait=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            (diag.value as? String)?.split(separator:" ").contains("twoViewComputing=false") == true
        },object:diag)
        XCTAssertEqual(XCTWaiter.wait(for:[wait],timeout:30),.completed)
        XCTAssertTrue(app.buttons["dailyClearance.strike"].isEnabled)
    }
    func testNativeSeparationWidths() throws {
        continueAfterFailure=false
        var boards:[String:Any] = [:]
        for profile in ["A","B","C"] {
            XCUIDevice.shared.orientation = .portrait
            let app=XCUIApplication.launchClean(extraArgs:["-forcePremium","-v50.inMemoryStore","-v54.forceDark","-dailyLayout.probe","-3dDrag.probe","-v63.cameraDiagnostics","-widthCompare="+profile,"-drillTryout.hasSeenGestureHint","YES"])
            app.switchTab(.angle)
            let tab=app.buttons["angleHomeTab_走位"];XCTAssertTrue(tab.waitForExistence(timeout:10));tab.tap()
            let card=app.buttons["分离角与走位"];XCTAssertTrue(card.waitForExistence(timeout:10))
            XCUIDevice.shared.orientation = .landscapeLeft;card.tap()
            XCTAssertTrue(node(app,"composer.landscape").waitForExistence(timeout:30))
            XCTAssertTrue(node(app,"composer.landscape").label.contains("分离角与走位"))
            settled(app)
            for dimension in ["2D","3D"] {
                more(app)
                let mode=app.buttons["freeplay.cameraMode"]
                if mode.value as? String != dimension { mode.tap() }
                XCTAssertEqual(mode.value as? String,dimension)
                item(app,"dailyClearance.trajectoryMenu").tap()
                item(app,"dailyClearance.trajectory.0").tap()
                close(app);settled(app)
                // Let the native camera transition and hint dismissal finish.
                Thread.sleep(forTimeInterval:3.5)
                let raw=try XCTUnwrap(node(app,"table.scene").value as? String)
                let scene=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(raw.utf8)) as? [String:Any])
                let balls=try XCTUnwrap(scene["balls"] as? [[String:Any]])
                let world=try Dictionary(uniqueKeysWithValues:balls.map { (try XCTUnwrap($0["key"] as? String),try XCTUnwrap($0["world"] as? [Double])) })
                if profile == "A" { boards[dimension]=world }
                else { XCTAssertEqual(NSDictionary(dictionary:world),NSDictionary(dictionary:try XCTUnwrap(boards[dimension] as? [String:[Double]]))) }
                let image=XCTAttachment(screenshot:XCUIScreen.main.screenshot());image.name="separation-\(dimension)-\(profile)";image.lifetime = .keepAlways;add(image)
                let state:[String:Any]=["profile":profile,"dimension":dimension,"scene":scene,"inputs":node(app,"dailyLayout.controlsProbe").value as? String ?? "","camera":node(app,"v63.cameraDiagnostics").value as? String ?? ""]
                let metadata=XCTAttachment(data:try JSONSerialization.data(withJSONObject:state,options:.sortedKeys),uniformTypeIdentifier:"public.json")
                metadata.name="separation-\(dimension)-\(profile)-state";metadata.lifetime = .keepAlways;add(metadata)
            }
            app.terminate()
        }
    }
}
