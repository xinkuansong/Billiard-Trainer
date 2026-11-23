import XCTest

/// v49 W1：c001 / c011 / c012 文案样张的真实 App 取证。
///
/// 外观由执行脚本先通过 `simctl ui <udid> appearance light|dark` 设置，再分别运行
/// Light / Dark 用例。截图落盘 `build/v49-screenshots/`。
final class V49W1CopyEvidenceUITests: XCTestCase {

    private func openCopyDetail(_ id: String, name: String) -> XCUIApplication {
        let env = ProcessInfo.processInfo.environment
        let click = env["COPY_REVIEW_CLICK_ROUTE"] == "1"
            || env["TEST_RUNNER_COPY_REVIEW_CLICK_ROUTE"] == "1"
        if !click { return XCUIApplication.launchClean(extraArgs: copyDetailArguments(id)) }
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-v49.forceLight"])
        app.switchTab(.drillLibrary)
        let search = app.textFields["搜索动作"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText(name)
        let card = app.descendants(matching: .any).matching(identifier: "drillCard_" + id).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        return app
    }

    private func copyDetailArguments(_ id: String) -> [String] {
        let env = ProcessInfo.processInfo.environment
        let useProductionRoute = env["COPY_REVIEW_PRODUCTION_ROUTE"] == "1"
            || env["TEST_RUNNER_COPY_REVIEW_PRODUCTION_ROUTE"] == "1"
        let route = useProductionRoute
            ? ["-liveReview.pageId=drill-detail", "-liveReview.contentId=\(id)"]
            : ["-deeplink.drillDetail=\(id)"]
        return route + ["-forcePremium", "-v50.inMemoryStore", "-v49.forceLight"]
    }

    /// Current copy review: reads an explicit host-side manifest and visits every section.
    /// Kept separate from historical W1 expectations; no resource generation or saves.
    func testCurrentCopyReviewManifest() throws {
        let root = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/output/drill-copy-full-20261016/native")
        let env = ProcessInfo.processInfo.environment
        let inputName = env["COPY_REVIEW_INPUT"] ?? env["TEST_RUNNER_COPY_REVIEW_INPUT"] ?? "input.json"
        let input = try Data(contentsOf: root.appendingPathComponent(inputName))
        let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: input) as? [[String: Any]])
        let label = env["COPY_REVIEW_DEVICE"] ?? env["TEST_RUNNER_COPY_REVIEW_DEVICE"] ?? "unspecified"
        let output = root.appendingPathComponent(label)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        XCUIDevice.shared.orientation = .portrait
        var visited: [[String: Any]] = []
        func capture(_ app: XCUIApplication, _ name: String) throws {
            try app.screenshot().pngRepresentation.write(to: output.appendingPathComponent(name + ".png"))
        }
        for row in rows {
            let id = try XCTUnwrap(row["id"] as? String)
            let name = try XCTUnwrap(row["name"] as? String)
            let description = try XCTUnwrap(row["description"] as? String)
            let point = try XCTUnwrap(row["point"] as? String)
            let forms = try XCTUnwrap(row["formations"] as? [[String: Any]])
            let app = openCopyDetail(id, name: name)
            XCTAssertTrue(app.staticTexts[name].firstMatch.waitForExistence(timeout: 15))
            XCTAssertTrue(app.staticTexts[description].firstMatch.waitForExistence(timeout: 8), "Candidate description must be loaded from bundle")
            try capture(app, id + "-detail-top")
            var sawPoint = false
            for scroll in 0..<12 {
                if app.staticTexts[point].firstMatch.isHittable { sawPoint = true }
                try capture(app, id + "-detail-\(scroll)")
                let button = app.buttons["查看精讲"].firstMatch
                if button.isHittable && sawPoint { button.tap(); break }
                app.swipeUp()
            }
            XCTAssertTrue(sawPoint, "First coaching point should be visible")
            XCTAssertTrue(app.buttons["tutorialScrollBottomButton"].waitForExistence(timeout: 12))
            if env["COPY_REVIEW_AX_PROBE"] == "1" || env["TEST_RUNNER_COPY_REVIEW_AX_PROBE"] == "1" {
                try app.debugDescription.write(to: output.appendingPathComponent(id + "-accessibility.txt"), atomically: true, encoding: .utf8)
                try capture(app, id + "-accessibility")
                app.terminate()
                return
            }
            for (fi, form) in forms.enumerated() {
                if forms.count > 1 {
                    let picker = app.segmentedControls["tutorialFormationPicker"].firstMatch
                    XCTAssertTrue(picker.exists)
                    picker.buttons.element(boundBy: fi).tap()
                }
                let titles = try XCTUnwrap(form["titles"] as? [String])
                let captions = try XCTUnwrap(form["captions"] as? [String])
                let expected = Set(titles + captions)
                let expectedImages = Set(form["images"] as? [String] ?? [])
                let imageSections = form["imageSections"] as? [String: String] ?? [:]
                XCTAssertEqual(Set(imageSections.keys), expectedImages)
                var seen = Set<String>()
                var seenImages = Set<String>()
                var pages = 0
                for page in 0..<100 {
                    // One tree read avoids repeatedly filtering every offscreen label on iOS 17.
                    // Visible candidates still require the original hittability assertions below.
                    let viewportFrame = app.scrollViews.firstMatch.frame.intersection(app.windows.firstMatch.frame)
                    var visibleLabels = Set<String>()
                    var visibleButtons = Set<String>()
                    func collect(_ node: XCUIElementSnapshot) {
                        let intersection = node.frame.intersection(viewportFrame)
                        if !intersection.isNull && intersection.width > 0 && intersection.height > 0 {
                            if node.elementType == .staticText { visibleLabels.insert(node.label) }
                            if node.elementType == .button { visibleButtons.insert(node.identifier) }
                        }
                        for child in node.children { collect(child) }
                    }
                    collect(try app.snapshot())
                    for text in expected where !seen.contains(text) {
                        if visibleLabels.contains(text) && app.staticTexts[text].firstMatch.isHittable { seen.insert(text) }
                    }
                    for image in expectedImages where !seenImages.contains(image) {
                        // SwiftUI propagates the section identifier to its poster button on iOS 26.
                        // The placeholder has no button; bind the observed button to the manifest's section.
                        let title = try XCTUnwrap(imageSections[image])
                        let poster = app.buttons["tutorialSection_\(title)"].firstMatch
                        if visibleButtons.contains("tutorialSection_\(title)") && poster.exists && poster.isHittable { seenImages.insert(image) }
                    }
                    try capture(app, "\(id)-f\(fi + 1)-p\(page)")
                    pages += 1
                    if seen == expected && seenImages == expectedImages { break }
                    let viewport = app.scrollViews.firstMatch
                    viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.80))
                        .press(forDuration: 0.05, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
                }
                XCTAssertEqual(seen, expected, "Every title and caption must actually enter the viewport: \(id)/\(fi)")
                XCTAssertEqual(seenImages, expectedImages, "Every referenced image must load and enter the viewport: \(id)/\(fi)")
                app.buttons["tutorialScrollBottomButton"].tap()
                try capture(app, "\(id)-f\(fi + 1)-bottom")
                visited.append(["id": id, "formation": fi + 1, "pages": pages, "seen": seen.sorted(), "missing": expected.subtracting(seen).sorted(), "images": seenImages.sorted()])
                try JSONSerialization.data(withJSONObject: visited, options: [.prettyPrinted, .sortedKeys])
                    .write(to: output.appendingPathComponent("visited.json"), options: .atomic)
            }
            app.terminate()
        }
        try JSONSerialization.data(withJSONObject: visited, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("visited.json"))
    }

    /// Additional final-copy consumers; independent of the full tutorial traversal above.
    func testCurrentTryoutScreenEvidence() throws {
        let root = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/output/drill-copy-full-20261016/native")
        let env = ProcessInfo.processInfo.environment
        let label = env["COPY_REVIEW_DEVICE"] ?? env["TEST_RUNNER_COPY_REVIEW_DEVICE"] ?? "screen-unspecified"
        let output = root.appendingPathComponent(label)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("reuse-input.json"))) as? [String: Any])
        let id = try XCTUnwrap(config["reuseDrill"] as? String)
        let point = try XCTUnwrap(config["reusePoint"] as? String)
        XCUIDevice.shared.orientation = .portrait
        let app = openCopyDetail(id, name: "中袋直线出杆")
        let button = app.buttons["上手试打"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts[point].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[point].firstMatch.isHittable)
        // Capture the whole display, avoiding app-frame cropping during a rotated scene.
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: output.appendingPathComponent("tryout-whole-screen.png"))
        try app.debugDescription.write(to: output.appendingPathComponent("tryout-whole-screen-ax.txt"), atomically: true, encoding: .utf8)
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
    }

    /// Additional final-copy consumers; independent of the full tutorial traversal above.
    func testCurrentCopyReuseAndFullscreen() throws {
        let root = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/output/drill-copy-full-20261016/native")
        let env = ProcessInfo.processInfo.environment
        let label = env["COPY_REVIEW_DEVICE"] ?? env["TEST_RUNNER_COPY_REVIEW_DEVICE"] ?? "reuse-unspecified"
        let output = root.appendingPathComponent(label)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let data = try Data(contentsOf: root.appendingPathComponent("reuse-input.json"))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cases = try XCTUnwrap(config["details"] as? [[String: Any]])
        XCUIDevice.shared.orientation = .portrait
        func snap(_ app: XCUIApplication, _ name: String) throws {
            try app.screenshot().pngRepresentation.write(to: output.appendingPathComponent(name + ".png"))
        }
        func reveal(_ app: XCUIApplication, _ element: XCUIElement) -> Bool {
            for _ in 0..<30 {
                if element.exists && element.isHittable { return true }
                app.swipeUp()
            }
            return element.exists && element.isHittable
        }
        for row in cases {
            let id = try XCTUnwrap(row["id"] as? String)
            let texts = try XCTUnwrap(row["texts"] as? [String])
            let manifest = try Data(contentsOf: root.appendingPathComponent("final74-input.json"))
            let all = try XCTUnwrap(JSONSerialization.jsonObject(with: manifest) as? [[String: Any]])
            let name = try XCTUnwrap(all.first(where: { $0["id"] as? String == id })?["name"] as? String)
            let app = openCopyDetail(id, name: name)
            XCTAssertTrue(app.staticTexts[texts[0]].firstMatch.waitForExistence(timeout: 15))
            var seen = Set<String>()
            for page in 0..<30 {
                var readable = app.scrollViews.firstMatch.frame.intersection(app.windows.firstMatch.frame)
                let navigation = app.navigationBars.firstMatch
                if navigation.exists {
                    let top = max(readable.minY, navigation.frame.maxY)
                    readable = CGRect(x: readable.minX, y: top, width: readable.width, height: max(0, readable.maxY - top))
                }
                let footer = app.buttons["上手试打"].firstMatch
                if footer.exists && footer.isHittable {
                    readable.size.height = max(0, min(readable.maxY, footer.frame.minY) - readable.minY)
                }
                for text in texts where !seen.contains(text) {
                    let element = app.staticTexts[text].firstMatch
                    if element.isHittable && readable.contains(element.frame) { seen.insert(text) }
                }
                try snap(app, "\(id)-all-detail-\(page)")
                if seen == Set(texts) { break }
                let viewport = app.scrollViews.firstMatch
                viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                    .press(forDuration: 0.05, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40)))
            }
            XCTAssertEqual(seen, Set(texts), "All description/coaching/standard text must enter the viewport")
            if let title = row["posterTitle"] as? String {
                let tutorial = app.buttons["查看精讲"].firstMatch
                // Reading the standard can scroll below the tutorial entry.
                for _ in 0..<30 {
                    if tutorial.exists && tutorial.isHittable { break }
                    app.swipeDown()
                }
                XCTAssertTrue(tutorial.isHittable); tutorial.tap()
                XCTAssertTrue(app.buttons["tutorialScrollBottomButton"].waitForExistence(timeout: 12))
                let poster = app.buttons["tutorialSection_\(title)"].firstMatch
                XCTAssertTrue(reveal(app, poster)); poster.tap()
                let caption = try XCTUnwrap(row["posterCaption"] as? String)
                let counter = try XCTUnwrap(row["posterCounter"] as? String)
                XCTAssertTrue(app.staticTexts[counter].firstMatch.waitForExistence(timeout: 8))
                XCTAssertTrue(app.staticTexts[caption].firstMatch.isHittable)
                try snap(app, id + "-fullscreen")
                try app.debugDescription.write(to: output.appendingPathComponent(id + "-fullscreen-ax.txt"), atomically: true, encoding: .utf8)
            }
            app.terminate()
        }
        let point = try XCTUnwrap(config["reusePoint"] as? String)
        let drill = try XCTUnwrap(config["reuseDrill"] as? String)
        let plan = try XCTUnwrap(config["reusePlan"] as? String)
        for (route, name) in [("-deeplink.tryout=\(drill)", "tryout"), ("-deeplink.planDetail=\(plan)", "plan")] {
            XCUIDevice.shared.orientation = name == "tryout" ? .landscapeLeft : .portrait
            let app = XCUIApplication.launchClean(extraArgs: [route, "-forcePremium", "-v50.inMemoryStore", "-v49.forceLight"])
            if name == "plan" {
                // Current plan rows show dose, then link to the action's copy.
                let currentEntry = app.descendants(matching: .any)["planDrillRow-\(drill)"].firstMatch
                XCTAssertTrue(reveal(app, currentEntry))
                try snap(app, "plan-current-entry")
                currentEntry.tap()
            }
            XCTAssertTrue(app.staticTexts[point].firstMatch.waitForExistence(timeout: 15))
            XCTAssertTrue(reveal(app, app.staticTexts[point].firstMatch))
            try snap(app, name + "-current-coaching")
            app.terminate()
        }
    }

    /// Actual click routes: landscape detail copy and portrait tutorial copy refer to the same pocket.
    func testPocketCopyMatchesDetailAndTutorial() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = openCopyDetail("drill_c033", name: "远台底袋角度球")
        let description = "8 号球靠近左下角袋，母球从远端不同位置进攻。目标球离袋不远，但母球要走较长距离，练习把不同厚薄的瞄准落实到准确的出杆方向。"
        XCTAssertTrue(app.staticTexts[description].waitForExistence(timeout: 15))
        try orientationCapture("c033-detail-table")
        let point = "先看 8 号球到左下角袋的进球线，再站到远处母球后方找准瞄准线；目标球近袋，也不能省掉厚薄判断"
        XCTAssertTrue(orientationReveal(app, app.staticTexts[point]))
        try orientationCapture("c033-detail-point")
        let tutorial = app.buttons["查看精讲"].firstMatch
        XCTAssertTrue(orientationReveal(app, tutorial)); tutorial.tap()
        XCTAssertTrue(app.buttons["tutorialScrollBottomButton"].waitForExistence(timeout: 12))
        let firstShot = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "第一杆", "右下角袋")).firstMatch
        XCTAssertTrue(orientationReveal(app, firstShot))
        try orientationCapture("c033-tutorial-portrait")
        app.terminate()
    }

    func testPocketCopyFollowsTryoutTableOrientation() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = openCopyDetail("drill_c033", name: "远台底袋角度球")
        let start = app.buttons["上手试打"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 15)); start.tap()
        let env = ProcessInfo.processInfo.environment
        let isPad = env["COPY_ORIENTATION_PAD"] == "1" || env["TEST_RUNNER_COPY_ORIENTATION_PAD"] == "1"
        let prefix = "先看 8 号球到"
        let suffix = "的进球线，再站到远处母球后方找准瞄准线；目标球近袋，也不能省掉厚薄判断"
        if isPad {
            XCUIDevice.shared.orientation = .portrait
            XCTAssertTrue(app.staticTexts[prefix + "右下角袋" + suffix].waitForExistence(timeout: 15))
            try orientationCapture("c033-tryout-portrait")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        let horizontal = app.staticTexts[prefix + "左下角袋" + suffix]
        if !horizontal.waitForExistence(timeout: 8) {
            let info = app.buttons["tryout.info"].firstMatch
            XCTAssertTrue(info.waitForExistence(timeout: 8)); info.tap()
        }
        XCTAssertTrue(horizontal.waitForExistence(timeout: 12))
        XCTAssertTrue(horizontal.isHittable)
        try orientationCapture("c033-tryout-landscape")
        if isPad {
            XCUIDevice.shared.orientation = .portrait
            XCTAssertTrue(app.staticTexts[prefix + "右下角袋" + suffix].waitForExistence(timeout: 12))
            try orientationCapture("c033-tryout-portrait-return")
        }
        app.terminate(); XCUIDevice.shared.orientation = .portrait
    }

    func testCueStartMarkerLessons() throws {
        for (id, name) in [("drill_c009", "底袋直线出杆"), ("drill_c012", "中袋直线出杆")] {
            XCUIDevice.shared.orientation = .portrait
            let app = openCopyDetail(id, name: name)
            let tutorial = app.buttons["查看精讲"].firstMatch
            XCTAssertTrue(orientationReveal(app, tutorial)); tutorial.tap()
            XCTAssertTrue(app.buttons["tutorialScrollBottomButton"].waitForExistence(timeout: 12))
            XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "不需要先碰目标球")).firstMatch.exists)
            XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "母球不碰目标球")).firstMatch.exists)
            try orientationCapture(id + "-tutorial-intro")
            let setup = app.staticTexts["怎么练"].firstMatch
            XCTAssertTrue(orientationReveal(app, setup))
            app.swipeUp()
            try orientationCapture(id + "-tutorial-setup")
            app.terminate()
        }
    }

    private func orientationReveal(_ app: XCUIApplication, _ element: XCUIElement) -> Bool {
        for _ in 0..<18 {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    private func orientationCapture(_ name: String) throws {
        let env = ProcessInfo.processInfo.environment
        let label = env["COPY_ORIENTATION_DEVICE"] ?? env["TEST_RUNNER_COPY_ORIENTATION_DEVICE"] ?? "unspecified"
        let output = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/output/drill-copy-orientation-20261016/native/" + label)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: output.appendingPathComponent(name + ".png"))
    }

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots"
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW1_Light_01_C011Detail() { captureC011Detail(suffix: "Light") }
    func testW1_Light_02_C001Tutorial() { captureC001Tutorial(suffix: "Light") }
    func testW1_Light_03_C012Tutorial() { captureC012Tutorial(suffix: "Light") }
    func testW1_Light_04_Tryout() { captureTryout(suffix: "Light") }
    func testW1_Light_05_Plan() { capturePlan(suffix: "Light") }
    func testW1_Light_06_Record() { captureDrillRecord(suffix: "Light") }

    func testW1_Dark_01_C011Detail() { captureC011Detail(suffix: "Dark") }
    func testW1_Dark_02_C001Tutorial() { captureC001Tutorial(suffix: "Dark") }
    func testW1_Dark_03_C012Tutorial() { captureC012Tutorial(suffix: "Dark") }
    func testW1_Dark_04_Tryout() { captureTryout(suffix: "Dark") }
    func testW1_Dark_05_Plan() { capturePlan(suffix: "Dark") }
    func testW1_Dark_06_Record() { captureDrillRecord(suffix: "Dark") }

    func testW1_SmallLight_01_C001Tutorial() {
        captureC001Tutorial(suffix: "Small-Light")
    }

    func testW1_SmallLight_02_C012Tutorial() {
        captureC012Tutorial(suffix: "Small-Light")
    }

    private func captureC001Tutorial(suffix: String) {
        captureTutorial(
            drillId: "drill_c001",
            expectedTitle: "半台直线球",
            expectedPrinciple: "这组练换位后的直线出杆",
            suffix: suffix,
            bottomSwipes: 4
        )
    }

    private func captureC012Tutorial(suffix: String) {
        captureTutorial(
            drillId: "drill_c012",
            expectedTitle: "中袋直线出杆",
            expectedPrinciple: "进不进中袋，直接能看出",
            suffix: suffix,
            bottomSwipes: 7
        )
    }

    private func captureC011Detail(suffix: String) {
        let app = launch(extraArgs: ["-deeplink.drillDetail=drill_c011"], suffix: suffix)
        XCTAssertTrue(app.staticTexts["近台小角度进球"].waitForExistence(timeout: 12))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "每换一次位置，都重新找瞄准点")
            ).firstMatch.waitForExistence(timeout: 6),
            "c011 详情应显示新的最小训练命题"
        )
        savePNG(app, "w1-c011-detail-top-\(suffix)")

        let firstPoint = "先看 8 号球的进球线，再定母球该撞哪儿"
        XCTAssertTrue(scrollToText(app, firstPoint), "c011 详情应显示首要点")
        savePNG(app, "w1-c011-detail-coaching-\(suffix)")
    }

    private func captureTutorial(
        drillId: String,
        expectedTitle: String,
        expectedPrinciple: String,
        suffix: String,
        bottomSwipes: Int
    ) {
        let app = launch(extraArgs: ["-deeplink.drillDetail=\(drillId)"], suffix: suffix)
        XCTAssertTrue(app.staticTexts[expectedTitle].waitForExistence(timeout: 12))

        let tutorial = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 where !tutorial.exists {
            app.swipeUp()
            usleep(350_000)
        }
        XCTAssertTrue(tutorial.exists, "\(drillId) 应有精讲入口")
        tutorial.tap()

        XCTAssertTrue(app.staticTexts["技术原理"].waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", expectedPrinciple)
            ).firstMatch.waitForExistence(timeout: 8),
            "\(drillId) 精讲应显示本轮技术原理"
        )
        savePNG(app, "w1-\(drillId)-tutorial-top-\(suffix)")

        for _ in 0..<bottomSwipes {
            app.swipeUp()
            usleep(300_000)
        }
        savePNG(app, "w1-\(drillId)-tutorial-later-\(suffix)")
    }

    private func captureTryout(suffix: String) {
        let focus = "换个位置，就从袋口重新拉线，再站上去"
        let app = launch(extraArgs: ["-deeplink.tryout=drill_c012"], suffix: suffix)
        XCTAssertTrue(app.staticTexts["训练重点"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[focus].waitForExistence(timeout: 8))
        savePNG(app, "w1-c012-tryout-brief-\(suffix)")
    }

    private func capturePlan(suffix: String) {
        let quote = "换个位置，就从袋口重新拉线，再站上去"
        let app = launch(extraArgs: ["-deeplink.planDetail=plan_beginner"], suffix: suffix)
        XCTAssertTrue(app.staticTexts[quote].waitForExistence(timeout: 15))
        savePNG(app, "w1-c012-plan-coaching-\(suffix)")
    }

    private func captureDrillRecord(suffix: String) {
        let description = "从半台五个位置打直线球。每次换位都重新站线，把球杆直着送出去。"
        let app = launch(extraArgs: ["-deeplink.activeTraining=drill_c001"], suffix: suffix)
        XCTAssertTrue(
            app.descendants(matching: .any)["v34w5ActiveTrainingHost"]
                .waitForExistence(timeout: 12)
        )
        let switchButton = app.buttons["切换到单项视图"].firstMatch
        if switchButton.waitForExistence(timeout: 5), switchButton.isHittable {
            switchButton.tap()
            usleep(500_000)
        }
        XCTAssertTrue(scrollToText(app, description, attempts: 10), "训练记录页应显示 c001 描述")
        savePNG(app, "w1-c001-drill-record-\(suffix)")
    }

    private func scrollToText(
        _ app: XCUIApplication,
        _ text: String,
        attempts: Int = 8
    ) -> Bool {
        let element = app.staticTexts[text].firstMatch
        if element.waitForExistence(timeout: 4) { return true }
        for _ in 0..<attempts {
            app.swipeUp()
            usleep(350_000)
            if element.exists { return true }
        }
        return element.exists
    }

    private func launch(extraArgs: [String], suffix: String) -> XCUIApplication {
        var args = extraArgs
        if suffix.contains("Light") {
            args.append("-v49.forceLight")
        }
        return XCUIApplication.launchClean(extraArgs: args)
    }

    private func savePNG(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let url = outDir.appendingPathComponent("\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            print("[V49-W1-SCREENSHOT] \(url.path)")
        } catch {
            XCTFail("写截图失败 \(name): \(error)")
        }
    }
}
