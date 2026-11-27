import XCTest

/// v7 W3/C20：练习首页封面色迁移后 Light/Dark 截图取证。
/// 截图写入 `build/w3-screenshots/`（禁止覆盖 `docs/ui-polish/` 与 DrillThumbnails）。
///
/// 外观切换：不要在用例内反复设 `XCUIDevice.appearance`（易打崩 Runner / 不生效）。
/// 请事先 `xcrun simctl ui <udid> appearance light|dark`，再分别跑 light / dark 用例。
final class W3_HomeCoverUITests: XCTestCase {

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/w3-screenshots")
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    /// 全新模拟器首启可能落在 Onboarding：先跳过再等 TabBar。
    private func dismissOnboardingIfNeeded(_ app: XCUIApplication) {
        let skip = app.buttons["跳过"]
        if skip.waitForExistence(timeout: 3) {
            skip.tap()
            sleep(1)
        }
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 15)
    }

    private func openPracticeHome(_ app: XCUIApplication) {
        dismissOnboardingIfNeeded(app)
        app.switchTab(.angle)
        sleep(1)
        let all = app.buttons["angleHomeTab_全部"]
        if all.waitForExistence(timeout: 4) {
            all.tap()
            usleep(600_000)
        }
    }

    private func snapHomeSeries(_ app: XCUIApplication, suffix: String) {
        openPracticeHome(app)
        snap(app, "w3-c20-01-home-all-\(suffix)")
        let learn = app.buttons["angleHomeTab_基础"]
        if learn.waitForExistence(timeout: 3) {
            learn.tap(); usleep(600_000)
            snap(app, "w3-c20-02-home-learn-\(suffix)")
        }
        let train = app.buttons["angleHomeTab_准度"]
        if train.waitForExistence(timeout: 3) {
            train.tap(); usleep(600_000)
            snap(app, "w3-c20-03-home-train-\(suffix)")
        }
        let solve = app.buttons["angleHomeTab_进阶"]
        if solve.waitForExistence(timeout: 3) {
            solve.tap(); usleep(600_000)
            snap(app, "w3-c20-04-home-solve-\(suffix)")
        }
    }

    func testW3HomeCoverLightScreenshots() throws {
        let app = XCUIApplication.launchClean()
        snapHomeSeries(app, suffix: "light")
    }

    func testW3HomeCoverDarkScreenshots() throws {
        let app = XCUIApplication.launchClean()
        snapHomeSeries(app, suffix: "dark")
    }
    func testDeferredFeaturesAreAbsentAndBankSolverRemainsReachable() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore"])
        app.switchTab(.angle)
        let solve = app.buttons["angleHomeTab_进阶"]
        XCTAssertTrue(solve.waitForExistence(timeout: 15))
        solve.tap()
        XCTAssertTrue(app.buttons["翻袋"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["防守求解"].exists)
        XCTAssertFalse(app.buttons["防守"].exists)
        let solveShot = XCTAttachment(screenshot: app.screenshot())
        solveShot.name = "deferred-solve"; solveShot.lifetime = .keepAlways; add(solveShot)
        let bank = app.buttons["翻袋"]
        bank.tap()
        XCTAssertTrue(app.descendants(matching: .any)["bankshot.template"].waitForExistence(timeout: 30))
        let landscape = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 5), .completed)
        // The navigation route exists before the system rotation animation completes.
        Thread.sleep(forTimeInterval: 2)
        // Capture the display: XCUIApplication may retain the portrait crop after rotation.
        let bankShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        bankShot.name = "preserved-bank-solver"; bankShot.lifetime = .keepAlways; add(bankShot)
        app.terminate()
        let home = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore"])
        home.switchTab(.angle)
        let learn = home.buttons["angleHomeTab_基础"]
        XCTAssertTrue(learn.waitForExistence(timeout: 15)); learn.tap()
        XCTAssertTrue(home.buttons["瞄准原理"].waitForExistence(timeout: 5))
        let learnShot = XCTAttachment(screenshot: home.screenshot())
        learnShot.name = "deferred-learn"; learnShot.lifetime = .keepAlways; add(learnShot)
        // Search the entire category so a lazily unloaded card cannot masquerade as removed.
        let search = home.textFields["搜索练习"]
        XCTAssertTrue(search.exists); search.tap(); search.typeText("一库翻袋")
        XCTAssertFalse(home.buttons["一库翻袋"].exists)
        XCTAssertTrue(home.staticTexts["没有找到相关练习"].waitForExistence(timeout: 5))
    }

    func testAdvancedCardsScreenshots() throws {
        continueAfterFailure = false
        for style in ["Light", "Dark"] {
            XCUIDevice.shared.orientation = .portrait
            let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-v54.force\(style)"])
            app.switchTab(.angle)
            let tab = app.buttons["angleHomeTab_进阶"]
            XCTAssertTrue(tab.waitForExistence(timeout: 15)); tab.tap()
            XCTAssertTrue(app.buttons["翻袋"].waitForExistence(timeout: 8))
            for page in 0..<5 {
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "advanced-\(style)-\(page)"; shot.lifetime = .keepAlways; add(shot)
                if page < 4 {
                    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.72))
                    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.42))
                    start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
                }
            }
            app.terminate()
        }
    }

}

// v75 native production-width verification

final class V75SeparationUITests: XCTestCase {
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
    func testNativeSeparationWidths() throws { try captureNativeSeparation(dark:true) }
    func testNativeSeparationWidthsLight() throws { try captureNativeSeparation(dark:false) }
    private func captureNativeSeparation(dark:Bool) throws {
        continueAfterFailure=false
        for profile in [dark ? "production" : "production-light"] {
            XCUIDevice.shared.orientation = .portrait
            let app=XCUIApplication.launchClean(extraArgs:["-forcePremium","-v50.inMemoryStore",dark ? "-v54.forceDark" : "-v54.forceLight","-dailyLayout.probe","-3dDrag.probe","-v63.cameraDiagnostics","-drillTryout.hasSeenGestureHint","YES"])
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
                let image=XCTAttachment(screenshot:XCUIScreen.main.screenshot());image.name="separation-\(dimension)-\(profile)";image.lifetime = .keepAlways;add(image)
                let state:[String:Any]=["profile":profile,"dimension":dimension,"scene":scene,"inputs":node(app,"dailyLayout.controlsProbe").value as? String ?? "","camera":node(app,"v63.cameraDiagnostics").value as? String ?? ""]
                let metadata=XCTAttachment(data:try JSONSerialization.data(withJSONObject:state,options:.sortedKeys),uniformTypeIdentifier:"public.json")
                metadata.name="separation-\(dimension)-\(profile)-state";metadata.lifetime = .keepAlways;add(metadata)
            }
            app.terminate()
        }
    }
}
