import XCTest

/// v49 W12：连续走位与多库路线文案的 Light / Dark 取证。
final class V49W12CopyEvidenceUITests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW12_Light_C039() { captureTutorial("drill_c039", "直线球组合走位", "连续八杆都别把简单球走复杂", "Light") }
    func testW12_Dark_C039() { captureTutorial("drill_c039", "直线球组合走位", "连续八杆都别把简单球走复杂", "Dark") }
    func testW12_Light_C040Detail() { captureDetail("drill_c040", "三库走位", "从目标区域反推三次碰库路线", "Light") }
    func testW12_Dark_C040Detail() { captureDetail("drill_c040", "三库走位", "从目标区域反推三次碰库路线", "Dark") }
    func testW12_Light_C042() { captureTutorial("drill_c042", "初级蛇彩", "八次击球只改变母球起点和打法", "Light") }
    func testW12_Dark_C042() { captureTutorial("drill_c042", "初级蛇彩", "八次击球只改变母球起点和打法", "Dark") }

    private func captureTutorial(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let button = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 where !button.exists { app.swipeUp(); usleep(250_000) }
        XCTAssertTrue(button.exists); button.tap()
        XCTAssertTrue(text(app, focus).waitForExistence(timeout: 12))
        save(app, "w12-\(id)-tutorial-\(suffix)")
        for _ in 0..<4 { app.swipeUp(); usleep(200_000) }
        save(app, "w12-\(id)-tutorial-later-\(suffix)")
    }

    private func captureDetail(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let target = text(app, focus)
        for _ in 0..<6 where !target.exists { app.swipeUp(); usleep(200_000) }
        XCTAssertTrue(target.exists)
        save(app, "w12-\(id)-detail-\(suffix)")
    }

    private func launch(_ id: String, _ suffix: String) -> XCUIApplication {
        var args = ["-deeplink.drillDetail=\(id)", "-forcePremium"]
        if suffix == "Light" { args.append("-v49.forceLight") }
        return XCUIApplication.launchClean(extraArgs: args)
    }

    private func text(_ app: XCUIApplication, _ value: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    private func save(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot(); let url = outDir.appendingPathComponent("\(name).png")
        do { try shot.pngRepresentation.write(to: url); print("[V49-W12-SCREENSHOT] \(url.path)") }
        catch { XCTFail("写截图失败 \(name): \(error)") }
    }
}

/// APP-I038: exercise the real detail -> tutorial navigation and reading state.
/// Run with test timeouts enabled so a blocked AX request also fails within 240s.
final class DrillTutorialNavigationRegressionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testC042_FirstFormationDeepScrollCanReturnToTrainingSheet() {
        launchDetail("drill_c042", title: "初级蛇彩")
        // Keep the same process for both visits, without selecting another formation.
        for _ in 0..<2 {
            openTutorial()
            revealSection("第八杆：1号球 · 左侧中袋", maximumSwipes: 18)
            revealSection("进阶练习", maximumSwipes: 8)
            app.windows.firstMatch.swipeDown()
            returnToDetailAndOpenTrainingSheet()
        }
    }

    func testC042_FormationsRetainIndependentPositionsAndReentryStartsAtTop() {
        launchDetail("drill_c042", title: "初级蛇彩")
        openTutorial()
        let initialTop = visibleFrame(of: app.staticTexts["技术原理"].firstMatch)
        let picker = app.segmentedControls["tutorialFormationPicker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.buttons.count, 2)

        let firstTitle = "第七杆：1号球 · 左侧中袋"
        revealSection(firstTitle, maximumSwipes: 18)
        let firstPosition = visibleFrame(of: app.staticTexts[firstTitle].firstMatch)

        selectFormation(1)
        XCTAssertEqual(visibleFrame(of: app.staticTexts["技术原理"].firstMatch).minY,
                       initialTop.minY, accuracy: 2, "An unvisited formation should start at the top")
        let secondTitle = "第四杆：4号球 · 右侧中袋"
        revealSection(secondTitle, maximumSwipes: 14)
        let secondPosition = visibleFrame(of: app.staticTexts[secondTitle].firstMatch)

        selectFormation(0)
        assertReadingPosition(firstTitle, equals: firstPosition)
        selectFormation(1)
        assertReadingPosition(secondTitle, equals: secondPosition)

        returnToDetailAndOpenTrainingSheet()
        openTutorial()
        XCTAssertTrue(picker.buttons.element(boundBy: 0).isSelected,
                      "Reentering should select the first formation")
        XCTAssertEqual(visibleFrame(of: app.staticTexts["技术原理"].firstMatch).minY,
                       initialTop.minY, accuracy: 2, "Reentering should discard the old reading position")
        selectFormation(1)
        XCTAssertEqual(visibleFrame(of: app.staticTexts["技术原理"].firstMatch).minY,
                       initialTop.minY, accuracy: 2, "The second formation should also reset on reentry")
    }

    func testC042_ArrowJumpsKeepIndependentPositionsAndReentryStartsAtTop() {
        let environment = ProcessInfo.processInfo.environment
        let dark = (environment["TUTORIAL_TEST_APPEARANCE"]
                    ?? environment["TEST_RUNNER_TUTORIAL_TEST_APPEARANCE"]) == "dark"
        // The real MainTabView route has no force-dark override. The dark run
        // follows the simulator appearance configured by the review controller.
        launchDetail("drill_c042", title: "初级蛇彩",
                     appearance: dark ? "-v51.followSystemAppearance" : "-v49.forceLight")
        openTutorial()
        let initialTop = visibleFrame(of: app.staticTexts["技术原理"].firstMatch)
        let topID = "tutorialScrollTopButton"
        let bottomID = "tutorialScrollBottomButton"
        for (identifier, label) in [(topID, "回到顶部"), (bottomID, "跳到末尾")] {
            let buttons = app.buttons.matching(identifier: identifier)
            XCTAssertEqual(buttons.count, 1, "Each arrow should have a unique accessibility identifier")
            let button = buttons.firstMatch
            XCTAssertTrue(button.isHittable, "Both floating arrows should remain reachable")
            XCTAssertEqual(button.label, label)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
        assertFloatingArrowLayout()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Tutorial lower-right arrows - \(dark ? "Dark" : "Light")"
        attachment.lifetime = .keepAlways
        add(attachment)

        tapTutorialJump(bottomID, revealing: "进阶练习")
        assertLastParagraphClearOfArrows("先练第 1、3 杆，把低杆回撤和轻高杆跟进区分开；两条路线稳定后，再加入带侧塞的变化。最后可用同一开局尝试连续打 1→2。")
        tapTutorialJump(topID, revealing: "技术原理")
        assertReadingPosition("技术原理", equals: initialTop)

        tapTutorialJump(bottomID, revealing: "进阶练习")
        let firstBottom = visibleFrame(of: app.staticTexts["进阶练习"].firstMatch)
        selectFormation(1)
        assertReadingPosition("技术原理", equals: initialTop)
        tapTutorialJump(bottomID, revealing: "进阶练习")
        assertLastParagraphClearOfArrows("先只打 1→2，翻侧稳了再接换袋。全程只许低杆，看第 4 杆还能不能留住收尾；收尾仍用斯登。")
        let secondBottom = visibleFrame(of: app.staticTexts["进阶练习"].firstMatch)

        selectFormation(0)
        assertReadingPosition("进阶练习", equals: firstBottom)
        tapTutorialJump(topID, revealing: "技术原理")
        assertReadingPosition("技术原理", equals: initialTop)
        selectFormation(1)
        assertReadingPosition("进阶练习", equals: secondBottom)

        returnToDetailAndOpenTrainingSheet()
        openTutorial()
        let picker = app.segmentedControls["tutorialFormationPicker"].firstMatch
        XCTAssertTrue(picker.buttons.element(boundBy: 0).isSelected)
        assertReadingPosition("技术原理", equals: initialTop)
        selectFormation(1)
        assertReadingPosition("技术原理", equals: initialTop)
    }

    func testC078_LongestSingleFormationCanReachLastSectionAndReturn() {
        launchDetail("drill_c078", title: "远台带塞准度")
        openTutorial()
        XCTAssertFalse(app.segmentedControls["tutorialFormationPicker"].exists)
        // Aspect-preserving images make the document taller in wide windows;
        // double the finite swipe budget while retaining the visible-tail assertion.
        revealSection("进阶练习", maximumSwipes: 72)
        returnToDetailAndOpenTrainingSheet()
    }

    func testC001_SingleFormationCanDeepScrollAndReenterAtTop() {
        launchDetail("drill_c001", title: "半台直线球")
        openTutorial()
        XCTAssertFalse(app.segmentedControls["tutorialFormationPicker"].exists,
                       "Single-formation tutorials should not show a picker")
        let initialTop = visibleFrame(of: app.staticTexts["技术原理"].firstMatch)
        revealSection("第五杆：4号球 · 左下角袋", maximumSwipes: 14)
        returnToDetailAndOpenTrainingSheet()
        openTutorial()
        XCTAssertEqual(visibleFrame(of: app.staticTexts["技术原理"].firstMatch).minY,
                       initialTop.minY, accuracy: 2)
    }

    func testC001_ArrowJumpsReachDocumentEdges() {
        let environment = ProcessInfo.processInfo.environment
        let dark = (environment["TUTORIAL_TEST_APPEARANCE"]
                    ?? environment["TEST_RUNNER_TUTORIAL_TEST_APPEARANCE"]) == "dark"
        launchDetail("drill_c001", title: "半台直线球",
                     appearance: dark ? "-v51.followSystemAppearance" : "-v49.forceLight")
        openTutorial()
        XCTAssertFalse(app.segmentedControls["tutorialFormationPicker"].exists,
                       "This must exercise the single-formation scroll container")
        let initialTop = visibleFrame(of: app.staticTexts["技术原理"].firstMatch)
        // drill_c001.json's final section is "进阶练习".
        assertFloatingArrowLayout()
        tapTutorialJump("tutorialScrollBottomButton", revealing: "进阶练习")
        assertLastParagraphClearOfArrows("五个位置都稳了，再把整组移到球桌另一侧。杆法和力度不变，只练换方向。")
        tapTutorialJump("tutorialScrollTopButton", revealing: "技术原理")
        assertReadingPosition("技术原理", equals: initialTop)
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.exists && back.isHittable)
        back.tap()
        waitUntilVisible(app.buttons["addToTrainingButton"],
                         message: "The single-formation tutorial should return to the real detail page")
    }

    private func launchDetail(_ drillID: String, title: String,
                              appearance: String = "-v49.forceLight") {
        app = XCUIApplication.launchClean(extraArgs: [
            "-liveReview.pageId=drill-detail", "-liveReview.contentId=\(drillID)",
            "-v50.inMemoryStore", "-forcePremium", appearance
        ])
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 12),
                      "The real drill detail route should load the requested drill")
        XCTAssertTrue(app.buttons["addToTrainingButton"].waitForExistence(timeout: 5))
        // A back button proves this is a push in MainTabView, not an isolated root host.
        XCTAssertTrue(app.navigationBars[title].buttons.element(boundBy: 0).isHittable)
    }

    private func openTutorial() {
        let entry = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 {
            if entry.exists, entry.isHittable { break }
            swipeDocumentUp()
        }
        XCTAssertTrue(entry.exists && entry.isHittable, "The detail tutorial entry should be reachable")
        entry.tap()
        waitUntilVisible(app.staticTexts["技术原理"].firstMatch,
                         message: "The tutorial should display its first section")
        XCTAssertFalse(app.buttons["addToTrainingButton"].isHittable,
                       "The tutorial must be a distinct pushed page")
    }

    private func selectFormation(_ index: Int) {
        let picker = app.segmentedControls["tutorialFormationPicker"].firstMatch
        XCTAssertTrue(picker.exists && picker.isHittable)
        let button = picker.buttons.element(boundBy: index)
        XCTAssertTrue(button.exists && button.isHittable)
        button.tap()
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in button.isSelected }, object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed,
                       "The requested formation should become selected")
    }

    private func tapTutorialJump(_ identifier: String, revealing title: String) {
        let button = app.buttons[identifier].firstMatch
        XCTAssertTrue(button.exists && button.isHittable,
                      "The floating jump arrow must be reachable without scrolling the document")
        button.tap()
        waitUntilVisible(app.staticTexts[title].firstMatch,
                         message: "One arrow tap should reveal '\(title)'")
    }

    private func assertFloatingArrowLayout() {
        let top = app.buttons["tutorialScrollTopButton"].firstMatch
        let bottom = app.buttons["tutorialScrollBottomButton"].firstMatch
        XCTAssertTrue(top.isHittable && bottom.isHittable)
        let topFrame = top.frame
        let bottomFrame = bottom.frame
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(topFrame) && window.contains(bottomFrame),
                      "Both arrow hit areas should stay inside the visible window")
        XCTAssertGreaterThan(topFrame.minX, window.midX,
                             "The floating arrows should be on the right side")
        XCTAssertGreaterThan(bottomFrame.midY, window.midY,
                             "The arrow stack should be near the bottom")
        XCTAssertEqual(topFrame.midX, bottomFrame.midX, accuracy: 1)
        XCTAssertLessThanOrEqual(topFrame.maxY, bottomFrame.minY,
                                 "The top arrow should sit above the bottom arrow without overlap")
        XCTAssertFalse(topFrame.intersects(bottomFrame))
    }

    private func assertLastParagraphClearOfArrows(_ content: String) {
        let paragraph = app.staticTexts[content].firstMatch
        waitUntilVisible(paragraph, message: "The complete final paragraph should be readable")
        let paragraphFrame = visibleFrame(of: paragraph)
        let topArrow = app.buttons["tutorialScrollTopButton"].firstMatch.frame
        XCTAssertLessThanOrEqual(paragraphFrame.maxY, topArrow.minY,
                                 "The final paragraph should end above the floating arrow stack")
        XCTAssertFalse(paragraphFrame.intersects(topArrow))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Tutorial lower-right arrows - document end"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func returnToDetailAndOpenTrainingSheet() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.exists && back.isHittable, "Deep scrolling must leave Back responsive")
        back.tap()
        let add = app.buttons["addToTrainingButton"]
        waitUntilVisible(add, message: "Returning should restore the detail controls")
        add.tap()
        let today = app.buttons["addToTodayTrainingRow"]
        waitUntilVisible(today, message: "The training sheet should open after returning")
        let cancel = app.navigationBars["加入训练"].buttons["取消"]
        XCTAssertTrue(cancel.exists && cancel.isHittable)
        cancel.tap()
        waitUntilVisible(add, message: "Cancelling should restore the detail page")
        XCTAssertFalse(today.exists, "The sheet should have dismissed")
    }

    private func revealSection(_ title: String, maximumSwipes: Int) {
        let section = app.staticTexts[title].firstMatch
        // Existence alone is insufficient for an eagerly laid out document: use
        // the actual viewport, and never tap a marker (which can auto-scroll).
        for _ in 0..<maximumSwipes {
            if isFullyVisible(section) { return }
            swipeDocumentUp()
        }
        XCTAssertTrue(isFullyVisible(section), "Could not reach section '\(title)' within \(maximumSwipes) swipes")
    }

    private func assertReadingPosition(_ title: String, equals expected: CGRect) {
        let section = app.staticTexts[title].firstMatch
        waitUntilVisible(section, message: "Switching should restore '\(title)'")
        let actual = visibleFrame(of: section)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 2,
                       "Switching formations must preserve the existing reading offset")
    }

    private func waitUntilVisible(_ element: XCUIElement, message: String) {
        let visible = XCTNSPredicateExpectation(
            predicate: NSPredicate { [weak self] _, _ in
                self?.isFullyVisible(element) == true
            }, object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 5), .completed, message)
    }

    private func visibleFrame(of element: XCUIElement) -> CGRect {
        XCTAssertTrue(isFullyVisible(element), "The reading marker must actually be in the viewport")
        return element.frame
    }

    private func isFullyVisible(_ element: XCUIElement) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let frame = element.frame
        return frame.width > 0 && frame.height > 0 && readingViewport.contains(frame)
    }

    private var readingViewport: CGRect {
        var viewport = app.windows.firstMatch.frame
        let bar = app.navigationBars.firstMatch
        if bar.exists {
            let top = max(viewport.minY, bar.frame.maxY)
            viewport.size.height = max(0, viewport.maxY - top)
            viewport.origin.y = top
        }
        let picker = app.segmentedControls["tutorialFormationPicker"].firstMatch
        if picker.exists {
            let top = max(viewport.minY, picker.frame.maxY)
            viewport.size.height = max(0, viewport.maxY - top)
            viewport.origin.y = top
        }
        return viewport
    }

    private func swipeDocumentUp() {
        let window = app.windows.firstMatch
        let viewport = readingViewport
        let x = viewport.midX - window.frame.minX
        let start = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x, dy: viewport.minY - window.frame.minY + viewport.height * 0.85))
        let finish = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x, dy: viewport.minY - window.frame.minY + viewport.height * 0.25))
        start.press(forDuration: 0.01, thenDragTo: finish)
    }
}
