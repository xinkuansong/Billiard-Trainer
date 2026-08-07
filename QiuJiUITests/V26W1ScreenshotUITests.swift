import XCTest

/// v26 W1：四条试点精讲页截图 → `build/v26-w1-screenshots/r3/`（DR-063 三轮）
final class V26W1ScreenshotUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v26-w1-screenshots/r3"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testW1_c032_tutorial() {
        captureTutorial(
            categorySidebar: "sidebar_准度训练",
            categoryFallback: "准度",
            search: "中台角度",
            nameContains: "中台角度球入袋",
            drillId: "drill_c032",
            file: "01-c032-tutorial"
        )
    }

    func testW1_c053_tutorial() {
        captureTutorial(
            categorySidebar: "sidebar_准度训练",
            categoryFallback: "准度",
            search: "中袋角度",
            nameContains: "中袋角度精准",
            drillId: "drill_c053",
            file: "02-c053-tutorial",
            formationContains: "球形2"
        )
    }

    func testW1_c008_tutorial() {
        captureTutorial(
            categorySidebar: "sidebar_基础功",
            categoryFallback: "基础功",
            search: "手架",
            nameContains: "手架练习",
            drillId: "drill_c008",
            file: "03-c008-tutorial"
        )
    }

    func testW1_c065_tutorial() {
        captureTutorial(
            categorySidebar: "sidebar_综合球形",
            categoryFallback: "综合球形",
            search: "Ghost",
            nameContains: "Ghost Game",
            drillId: "drill_c065",
            file: "04-c065-tutorial-ruleset"
        )
    }

    private func captureTutorial(
        categorySidebar: String,
        categoryFallback: String,
        search: String,
        nameContains: String,
        drillId: String,
        file: String,
        formationContains: String? = nil
    ) {
        app.switchTab(.drillLibrary)
        sleep(2)

        let sidebar = app.descendants(matching: .any)[categorySidebar]
        if sidebar.waitForExistence(timeout: 5) {
            sidebar.tap()
        } else {
            let fallback = app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@", categoryFallback)
            ).firstMatch
            XCTAssertTrue(fallback.waitForExistence(timeout: 5), "应能切到 \(categoryFallback)")
            fallback.tap()
        }
        sleep(1)

        let searchField = app.textFields["搜索动作"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "搜索框应存在")
        searchField.tap()
        searchField.typeText(search)
        sleep(2)

        let card = app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "identifier == %@ OR label CONTAINS %@",
                "drillCard_\(drillId)",
                nameContains
            ))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8), "应找到 \(drillId)")
        card.tap()
        sleep(2)

        let tutorialTab = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '精讲' OR label CONTAINS '图文' OR label CONTAINS '讲解'")
        ).firstMatch
        if tutorialTab.waitForExistence(timeout: 4) {
            tutorialTab.tap()
            sleep(1)
        } else {
            let anyTutorial = app.staticTexts["精讲"].firstMatch
            if anyTutorial.waitForExistence(timeout: 2) {
                anyTutorial.tap()
                sleep(1)
            }
        }

        if let formationContains {
            let segment = app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@", formationContains)
            ).firstMatch
            if segment.waitForExistence(timeout: 3) {
                segment.tap()
                sleep(1)
            }
        }

        // 滚到含袋口名的逐杆节（或规则课中部），便于验收 DR-063 屏幕系袋口名
        if drillId == "drill_c032" || drillId == "drill_c053" {
            app.swipeUp()
            sleep(1)
            app.swipeUp()
            sleep(1)
        } else if drillId == "drill_c065" {
            app.swipeUp()
            sleep(1)
        }

        savePNG(file)
    }

    private func savePNG(_ name: String) {
        let shot = app.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
        let data = shot.pngRepresentation
        try? data.write(to: outDir.appendingPathComponent("\(name).png"))
    }
}
