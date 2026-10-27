import XCTest

final class TrainingSettingsResetUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = .launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-freeLayout.ephemeral",
                                      "-twoBall.probe", "-twoBall.fixedSeed", "-v54.forceDark"])
    }

    override func tearDown() { app.terminate(); XCUIDevice.shared.orientation = .portrait }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    /// Captures the native header through real entry points, including both tablet orientations.
    func testSettingsHeaderBaseline() {
        reviewHeaders(assertPlacement: false)
    }

    func testSettingsHeaderPlacement() {
        reviewHeaders(assertPlacement: true)
    }

    func testSettingsLightAndLargeText() {
        app.terminate()
        app = .launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-freeLayout.ephemeral",
            "-v54.forceLight", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        for title in ["2D准度", "2D两球走位"] {
            open(title)
            capture("large-light-\(title)-top")
            let heading = app.navigationBars.staticTexts["训练设置"].firstMatch
            XCTAssertTrue(heading.isHittable)
            XCTAssertFalse(app.tabBars.firstMatch.isHittable)
            let reset = app.buttons["training.resetDefaults"]
            reveal(reset)
            capture("large-light-\(title)-bottom")
            XCTAssertGreaterThanOrEqual(reset.frame.height, 44)
            app.buttons["training.settingsCancel"].tap()
        }
    }

    private func reviewHeaders(assertPlacement: Bool) {
        let entries = ["2D角度", "3D角度", "2D瞄准点", "3D瞄准点", "2D准度", "3D准度",
                       "2D分离角", "3D分离角", "2D两球走位", "3D两球走位", "2D三球走位", "3D三球走位",
                       "2D多球走位", "3D多球走位", "蛇彩练习", "自定义球形"]
        let tablet = UIDevice.current.userInterfaceIdiom == .pad
        for title in entries {
            app.switchTab(.angle)
            let play = ["分离角", "两球", "三球", "多球"].contains { title.contains($0) }
            app.buttons["angleHomeTab_" + (play ? "打" : "练")].tap()
            let card = app.buttons[title]; reveal(card); card.tap()
            let startID = title.contains("多球") ? "multiBall.start" : title.contains("三球") ? "threeBall.start" : title.contains("两球") ? "twoBall.start" : title.contains("分离角") ? "separation.start" : title.contains("准度") ? "accuracy.start" : title.contains("瞄准点") ? "aimPointTraining.start" : title.contains("角度") ? "angleTraining.start" : title == "蛇彩练习" ? "snake.start" : "formation.start"
            let start = app.buttons[startID]
            XCTAssertTrue(start.waitForExistence(timeout: 15))
            for orientation in tablet ? [UIDeviceOrientation.portrait, .landscapeLeft] : [.portrait] {
                XCUIDevice.shared.orientation = orientation
                if tablet {
                    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                        (self.app.frame.width > self.app.frame.height) == (orientation == .landscapeLeft)
                    }, object: nil)], timeout: 8), .completed)
                }
                let expectedTitle = assertPlacement && title == "自定义球形" ? "选择球形" : "训练设置"
                let heading = app.navigationBars.staticTexts[expectedTitle].firstMatch
                XCTAssertTrue(heading.waitForExistence(timeout: 5))
                capture("header-\(title)-\(orientation.rawValue)")
                let report = XCTAttachment(string: "window=\(app.frame) title=\(heading.frame) start=\(start.frame)")
                report.name = "header-frames-\(title)-\(orientation.rawValue)"; report.lifetime = .keepAlways; add(report)
                if assertPlacement {
                    XCTAssertTrue(heading.isHittable, "The title must be visible, not covered by the iPad tab bar")
                    XCTAssertFalse(app.tabBars.firstMatch.isHittable, "Training settings owns the entire navigation bar")
                    XCTAssertEqual(heading.frame.midX, app.frame.midX, accuracy: 4, title)
                    XCTAssertEqual(heading.frame.midY, start.frame.midY, accuracy: 4, title)
                    XCTAssertGreaterThan(start.frame.minX, heading.frame.maxX, title)
                    XCTAssertLessThanOrEqual(start.frame.maxX, app.frame.maxX, title)
                }
            }
            app.navigationBars.buttons.matching(NSPredicate(format: "label == '返回'")).firstMatch.tap()
            XCUIDevice.shared.orientation = .portrait
        }
    }

    private func ready(_ element: XCUIElement, timeout: TimeInterval = 10) {
        if element.exists && element.isHittable && element.isEnabled { return }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true AND enabled == true"),
            object: element)], timeout: timeout), .completed, element.debugDescription)
    }

    private func reveal(_ element: XCUIElement, down: Bool = true) {
        for _ in 0..<24 {
            var scrollDown = down
            if element.exists {
                let frame = element.frame
                let window = app.frame
                let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY + 4 : window.minY + 70
                let tabs = app.tabBars.firstMatch
                let bottom = tabs.exists && tabs.frame.minY > window.midY
                    ? tabs.frame.minY - 4 : window.maxY - 20
                if element.isHittable && frame.minY >= top && frame.maxY <= bottom { break }
                if !frame.isEmpty { scrollDown = frame.maxY > bottom }
            }
            let start = app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: scrollDown ? 0.72 : 0.42))
            let end = app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: scrollDown ? 0.42 : 0.72))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        ready(element)
    }

    private func top() {
        reveal(app.otherElements["training.length"], down: false)
        app.swipeDown()
    }

    private func open(_ title: String) {
        app.switchTab(.angle)
        app.buttons["angleHomeTab_" + ((title.contains("分离角") || title.contains("两球")) ? "打" : "练")].tap()
        let card = app.buttons[title]
        reveal(card); card.tap()
        ready(app.buttons[title == "蛇彩练习" ? "snake.settingsCancel" : "training.settingsCancel"])
    }

    private func setSwitch(_ id: String, _ value: Bool, down: Bool = true) {
        let toggle = app.switches[id]
        reveal(toggle, down: down)
        if (toggle.value as? String == "1") != value {
            toggle.coordinate(withNormalizedOffset: .init(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, value ? "1" : "0")
    }

    private func reset(_ name: String) {
        let button = app.buttons["training.resetDefaults"]
        reveal(button)
        XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        // Tap the row's whitespace to verify its full hit area on wide forms.
        button.coordinate(withNormalizedOffset: .init(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["已恢复默认设置"].waitForExistence(timeout: 2))
        capture(name)
        XCTAssertTrue(app.staticTexts["已恢复默认设置"].waitForNonExistence(timeout: 6))
    }

    func testAngleAndAimSettingsRestoreDefaults() {
        assertSceneDefaults(["2D角度", "3D角度", "2D瞄准点", "3D瞄准点"])
    }

    func testAccuracySettingsRestoreDefaults() {
        assertSceneDefaults(["2D准度", "3D准度"])
    }

    func testTrajectorySettingsRestoreDefaults() {
        assertSceneDefaults(["2D分离角", "3D分离角", "2D两球走位", "3D两球走位"])
    }

    private func assertSceneDefaults(_ titles: [String]) {
        for title in titles {
            open(title)
            let trajectory = title.contains("分离角") || title.contains("两球")
            app.otherElements["training.length"].buttons["持续练习"].tap()
            if title.contains("两球") {
                app.segmentedControls["twoBall.mode"].buttons["自由走位"].tap()
                XCTAssertFalse(app.switches["training.verticalSpin"].exists)
                XCTAssertFalse(app.switches["training.sideSpin"].exists)
                app.segmentedControls["twoBall.mode"].buttons["轨迹走位"].tap()
            }
            if trajectory {
                setSwitch("separation.playsStroke", false)
                setSwitch("separation.showsReference", true)
                top()
            }
            let thin = app.buttons["training.range.thin"]
            reveal(thin); thin.tap()
            if title == "2D准度" || title == "2D两球走位" {
                for (field, choice) in [("cueDistance", "long"), ("pocketDistance", "short"),
                                        ("pockets", "side"), ("railDistance", "frozen")] {
                    let row = app.buttons["training." + field]
                    reveal(row); row.tap()
                    let option = app.buttons["training." + field + "." + choice]
                    ready(option); option.tap()
                    app.navigationBars.firstMatch.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                    XCTAssertTrue(option.waitForNonExistence(timeout: 3))
                }
            }
            if title.contains("准度") || trajectory {
                if trajectory { top() }
                setSwitch("training.verticalSpin", !trajectory)
                setSwitch("training.sideSpin", !trajectory)
            }
            reset(title + "-reset-bottom")
            if title.contains("准度") || trajectory {
                reveal(app.switches["training.verticalSpin"], down: false)
                XCTAssertEqual(app.switches["training.verticalSpin"].value as? String, trajectory ? "1" : "0")
                XCTAssertEqual(app.switches["training.sideSpin"].value as? String, trajectory ? "1" : "0")
            }
            // iOS 17 lazily removes offscreen rows from AX; start above the conditions.
            top()
            for field in ["cueDistance", "pocketDistance", "pockets", "railDistance"] {
                let row = app.buttons["training." + field]
                reveal(row)
                XCTAssertEqual(row.value as? String, "综合")
            }
            top()
            XCTAssertTrue(app.otherElements["training.length"].buttons["20题"].isSelected)
            if title.contains("两球") { XCTAssertTrue(app.segmentedControls["twoBall.mode"].buttons["轨迹走位"].isSelected) }
            if trajectory {
                reveal(app.switches["separation.playsStroke"])
                XCTAssertEqual(app.switches["separation.playsStroke"].value as? String, "1")
                XCTAssertEqual(app.switches["separation.showsReference"].value as? String, "0")
            }
            if title.contains("准度") {
                reveal(app.switches["accuracy.manualVerticalSpin"], down: false)
                XCTAssertEqual(app.switches["accuracy.manualVerticalSpin"].value as? String, "1")
                XCTAssertEqual(app.switches["accuracy.manualSideSpin"].value as? String, "1")
            }
            top()
            for range in ["straight", "small", "medium", "large", "thin", "mixed"] {
                let row = app.buttons["training.range." + range]
                reveal(row)
                XCTAssertEqual(row.value as? String, (trajectory ? ["straight", "small", "medium"].contains(range) : range == "mixed") ? "已选" : "未选")
            }
            reset(title + "-reset-again")
            app.buttons["training.settingsCancel"].tap()
        }
    }

    private func twoBallSettings() {
        ready(app.buttons["twoBall.more"], timeout: 120); app.buttons["twoBall.more"].tap()
        ready(app.buttons["twoBall.trainingSettings"]); app.buttons["twoBall.trainingSettings"].tap()
        ready(app.buttons["twoBall.start"])
        let heading = app.navigationBars.staticTexts["训练设置"].firstMatch
        XCTAssertTrue(heading.isHittable)
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        XCTAssertEqual(heading.frame.midX, app.frame.midX, accuracy: 4)
        XCTAssertGreaterThan(app.buttons["twoBall.start"].frame.minX, heading.frame.maxX)
        if UIDevice.current.userInterfaceIdiom != .pad { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    private func twoBallProbe() throws -> [String: Any] {
        let node = app.descendants(matching: .any).matching(identifier: "twoBall.probe").firstMatch
        let value = try XCTUnwrap(node.value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
    }

    func testSceneResetCancelPreservesRoundAndStartCommitsDefaults() throws {
        open("2D两球走位")
        reset("transaction-initial-defaults"); top()
        app.segmentedControls["twoBall.mode"].buttons["自由走位"].tap()
        app.otherElements["training.length"].buttons["持续练习"].tap()
        setSwitch("separation.playsStroke", false); setSwitch("separation.showsReference", true)
        app.buttons["twoBall.start"].tap()
        ready(app.buttons["twoBall.strike"], timeout: 180)
        let initial = try twoBallProbe()
        twoBallSettings()
        reset("transaction-reset-before-cancel")
        app.buttons["training.settingsCancel"].tap()
        ready(app.buttons["twoBall.strike"])
        let cancelled = try twoBallProbe()
        for key in ["question", "mode"] { XCTAssertEqual(cancelled[key] as? String, initial[key] as? String) }
        XCTAssertEqual(cancelled["playsStroke"] as? Bool, false)
        XCTAssertEqual(cancelled["showsReference"] as? Bool, true)
        twoBallSettings(); top()
        XCTAssertTrue(app.segmentedControls["twoBall.mode"].buttons["自由走位"].isSelected)
        XCTAssertTrue(app.otherElements["training.length"].buttons["持续练习"].isSelected)
        reset("transaction-reset-before-start")
        app.buttons["twoBall.start"].tap()
        ready(app.buttons["twoBall.strike"], timeout: 180)
        XCTAssertEqual(try twoBallProbe()["playsStroke"] as? Bool, true)
        XCTAssertEqual(try twoBallProbe()["showsReference"] as? Bool, false)
        twoBallSettings(); top()
        XCTAssertTrue(app.segmentedControls["twoBall.mode"].buttons["轨迹走位"].isSelected)
        XCTAssertTrue(app.otherElements["training.length"].buttons["20题"].isSelected)
        app.buttons["training.settingsCancel"].tap()
    }

    func testTwoBallModesKeepIndependentDraftsAndConfirmedPreferences() throws {
        open("2D两球走位")
        reset("modes-reset"); top()
        setSwitch("training.verticalSpin", false)
        let small = app.buttons["training.range.small"]
        reveal(small); small.tap()
        setSwitch("separation.playsStroke", false)
        top()
        app.segmentedControls["twoBall.mode"].buttons["自由走位"].tap()
        XCTAssertFalse(app.switches["training.verticalSpin"].exists)
        XCTAssertFalse(app.switches["training.sideSpin"].exists)
        reveal(small); XCTAssertEqual(small.value as? String, "已选")
        setSwitch("separation.showsReference", true)
        capture("two-ball-free-settings")
        top(); app.segmentedControls["twoBall.mode"].buttons["轨迹走位"].tap()
        reveal(app.switches["training.verticalSpin"])
        XCTAssertEqual(app.switches["training.verticalSpin"].value as? String, "0")
        reveal(small); XCTAssertEqual(small.value as? String, "未选")
        setSwitch("separation.playsStroke", false)
        top(); app.segmentedControls["twoBall.mode"].buttons["自由走位"].tap()
        app.buttons["twoBall.start"].tap()
        ready(app.buttons["twoBall.strike"], timeout: 180)
        let initial = try twoBallProbe()
        XCTAssertEqual(initial["playsStroke"] as? Bool, true)
        XCTAssertEqual(initial["showsReference"] as? Bool, true)
        twoBallSettings(); top()
        app.segmentedControls["twoBall.mode"].buttons["轨迹走位"].tap()
        setSwitch("training.verticalSpin", true)
        app.buttons["training.settingsCancel"].tap()
        ready(app.buttons["twoBall.strike"])
        XCTAssertEqual(try twoBallProbe()["question"] as? String, initial["question"] as? String)
        twoBallSettings(); top()
        app.segmentedControls["twoBall.mode"].buttons["轨迹走位"].tap()
        reveal(app.switches["training.verticalSpin"])
        XCTAssertEqual(app.switches["training.verticalSpin"].value as? String, "0")
        reveal(small); XCTAssertEqual(small.value as? String, "未选")
        reveal(app.switches["separation.playsStroke"])
        XCTAssertEqual(app.switches["separation.playsStroke"].value as? String, "0")
        capture("two-ball-trajectory-settings-restored")
        app.buttons["training.settingsCancel"].tap()
    }

    func testSnakeResetCancelAndStartPersistence() {
        open("蛇彩练习")
        app.buttons["snake.count"].tap(); app.buttons["snake.count.6"].tap()
        app.segmentedControls["snake.mode"].buttons["按号"].tap()
        app.buttons["snake.start"].tap()
        ready(app.buttons["freeplay.moreMenu"], timeout: 120)
        if UIDevice.current.userInterfaceIdiom != .pad { XCUIDevice.shared.orientation = .landscapeLeft }
        func settings() {
            app.buttons["freeplay.moreMenu"].tap(); app.buttons["snake.settings"].tap()
            ready(app.buttons["snake.start"])
        }
        settings()
        let records = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'snake.record.'"))
        let savedRecords = records.allElementsBoundByIndex.map(\.label)
        reset("snake-reset-before-cancel")
        XCTAssertEqual(records.allElementsBoundByIndex.map(\.label), savedRecords)
        app.buttons["snake.settingsCancel"].tap()
        ready(app.buttons["freeplay.moreMenu"]); settings()
        XCTAssertTrue((app.buttons["snake.count"].label + (app.buttons["snake.count"].value as? String ?? "")).contains("6"))
        XCTAssertTrue(app.segmentedControls["snake.mode"].buttons["按号"].isSelected)
        reset("snake-reset-before-start")
        app.buttons["snake.start"].tap()
        ready(app.buttons["freeplay.moreMenu"]); settings()
        XCTAssertTrue((app.buttons["snake.count"].label + (app.buttons["snake.count"].value as? String ?? "")).contains("5"))
        XCTAssertTrue(app.segmentedControls["snake.mode"].buttons["从右到左"].isSelected)
        app.buttons["snake.settingsCancel"].tap()
        app.terminate(); app.launch()
        open("蛇彩练习")
        XCTAssertTrue((app.buttons["snake.count"].label + (app.buttons["snake.count"].value as? String ?? "")).contains("5"))
        XCTAssertTrue(app.segmentedControls["snake.mode"].buttons["从右到左"].isSelected)
        // A reset followed by Back must not persist an edited draft, either.
        app.buttons["snake.count"].tap(); app.buttons["snake.count.6"].tap()
        app.buttons["snake.settingsCancel"].tap()
        open("蛇彩练习")
        XCTAssertTrue((app.buttons["snake.count"].label + (app.buttons["snake.count"].value as? String ?? "")).contains("5"))
    }

    func testCustomFormationManagerHasNoResetAction() {
        app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
        let entry = app.buttons["自定义球形"]; reveal(entry); entry.tap()
        ready(app.buttons["formation.new"])
        app.swipeUp(); app.swipeUp()
        XCTAssertFalse(app.buttons["training.resetDefaults"].exists)
        capture("formation-no-reset")
    }

    private func assertPortrait(_ portrait: Bool) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = self.app.windows.firstMatch.frame
            return portrait ? frame.height > frame.width : frame.width > frame.height
        }, object: nil)], timeout: 10), .completed)
    }

    private func launchSettingsReference() {
        app.terminate()
        app.launchArguments.removeAll { $0 == "-v54.forceDark" }
        app.launchArguments.append("-v54.forceLight")
        app.launch()
    }

    private func assertFullSettingsPage(cancel: String, tableMenu: String) {
        assertPortrait(true)
        ready(app.buttons[cancel])
        let bar = app.navigationBars.firstMatch
        XCTAssertTrue(bar.exists)
        XCTAssertLessThan(bar.frame.maxY, app.frame.height * 0.2, "Settings must use the top navigation bar, not a bottom sheet")
        XCTAssertFalse(app.buttons[tableMenu].exists, "The table must be replaced by the full settings page")
    }

    func testRackSettingsPortraitAndTableReturn() {
        for title in ["2D多球走位", "3D多球走位", "蛇彩练习"] {
            launchSettingsReference()
            app.switchTab(.angle)
            app.buttons["angleHomeTab_" + (title == "蛇彩练习" ? "练" : "打")].tap()
            let card = app.buttons[title]; reveal(card); card.tap()
            let prefix = title == "蛇彩练习" ? "snake" : "multiBall"
            ready(app.buttons[prefix + ".start"])
            app.buttons[prefix + ".start"].tap()
            assertPortrait(false)
            ready(app.buttons["freeplay.moreMenu"], timeout: 120)
            let state = app.descendants(matching: .any).matching(identifier: prefix + ".landscape").firstMatch
            let initialState = state.value as? String
            XCTAssertNotNil(initialState)
            func settings() {
                app.buttons["freeplay.moreMenu"].tap()
                let menu = app.scrollViews["dailyClearance.menuScroll"]
                XCTAssertTrue(menu.waitForExistence(timeout: 5))
                for _ in 0..<8 {
                    let item = app.buttons[prefix + ".settings"]
                    if item.exists && item.isHittable && item.frame.maxY < app.frame.maxY - 20 { break }
                    let x = item.exists && !item.frame.isEmpty ? item.frame.midX / app.frame.width : 0.8
                    app.coordinate(withNormalizedOffset: .init(dx: x, dy: 0.75))
                        .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: .init(dx: x, dy: 0.3)))
                }
                ready(app.buttons[prefix + ".settings"]); app.buttons[prefix + ".settings"].tap()
                assertFullSettingsPage(cancel: prefix + ".settingsCancel", tableMenu: "freeplay.moreMenu")
            }
            settings(); capture(title + "-portrait-settings")
            app.buttons[prefix + ".settingsCancel"].tap()
            assertPortrait(false); ready(app.buttons["freeplay.moreMenu"])
            XCTAssertEqual(state.value as? String, initialState)
            settings()
            app.buttons[prefix + ".start"].tap()
            assertPortrait(false); ready(app.buttons["freeplay.moreMenu"])
            capture(title + "-table-after-settings")
        }
    }

    func testAngleAndAimSettingsPortraitAndTableReturn() {
        for title in ["2D角度", "3D角度", "2D瞄准点", "3D瞄准点"] {
            launchSettingsReference()
            open(title)
            let prefix = title.contains("瞄准点") ? "aimPointTraining" : "angleTraining"
            app.buttons[prefix + ".start"].tap()
            assertPortrait(false); ready(app.buttons[prefix + ".settings"], timeout: 120)
            app.buttons[prefix + ".settings"].tap()
            ready(app.buttons[prefix + ".trainingSettings"]); app.buttons[prefix + ".trainingSettings"].tap()
            assertFullSettingsPage(cancel: "training.settingsCancel", tableMenu: prefix + ".settings")
            capture(title + "-portrait-settings")
            app.buttons["training.settingsCancel"].tap()
            assertPortrait(false); ready(app.buttons[prefix + ".settings"])
            app.buttons[prefix + ".settings"].tap()
            ready(app.buttons[prefix + ".trainingSettings"]); app.buttons[prefix + ".trainingSettings"].tap()
            assertFullSettingsPage(cancel: "training.settingsCancel", tableMenu: prefix + ".settings")
            app.buttons[prefix + ".start"].tap()
            assertPortrait(false); ready(app.buttons[prefix + ".settings"])
            capture(title + "-table-after-settings")
        }
    }
}
