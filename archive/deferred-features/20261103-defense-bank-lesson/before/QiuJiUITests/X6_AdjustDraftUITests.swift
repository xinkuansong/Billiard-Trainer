import XCTest

/// v8 X6：K12 求解范围菜单截图 + K13 打点全向微调实操截图。
/// 产物落盘 `build/x6-screenshots/`（禁止写 `docs/ui-polish/`）。
final class X6_AdjustDraftUITests: XCTestCase {

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer-wt-x6/build/x6-screenshots")
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let url = shotDir.appendingPathComponent("\(name).png")
        try? shot.pngRepresentation.write(to: url)
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    private func moreButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == '更多'")).firstMatch
    }

    private func openMoreAndSnap(_ app: XCUIApplication, _ name: String) {
        let more = moreButton(app)
        XCTAssertTrue(more.waitForExistence(timeout: 8), "\(name): 三点菜单")
        more.tap()
        sleep(1)
        snap(app, name)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
        usleep(400_000)
    }

    /// PlanThree / Snooker：三点菜单无「求解范围」；Silu：保留。
    func testX6_solveRangeMenus() {
        // PlanThree — no solve-range section
        var app = XCUIApplication.launchClean(extraArgs: ["-deeplink.planThree"])
        _ = app.buttons["摆球"].waitForExistence(timeout: 20)
        openMoreAndSnap(app, "x6-menu-planthree-no-solve-range")
        app.terminate()

        // Snooker — no solve-range section
        app = XCUIApplication.launchClean(extraArgs: ["-deeplink.snooker"])
        _ = app.buttons["摆球"].waitForExistence(timeout: 20)
        openMoreAndSnap(app, "x6-menu-snooker-no-solve-range")
        app.terminate()

        // Silu — keep solve-range
        app = XCUIApplication.launchClean(extraArgs: ["-deeplink.silu"])
        _ = app.buttons["摆球"].waitForExistence(timeout: 20)
        openMoreAndSnap(app, "x6-menu-silu-keeps-solve-range")
        app.terminate()
    }

    /// Silu：求解后开打点盘，拖到上/下塞区域，截瞄准线随 spinX 变化。
    func testX6_spinPadFullAxisAdjust() {
        let app = XCUIApplication.launchClean(extraArgs: ["-deeplink.silu"])
        let placeChip = app.buttons["摆球"]
        XCTAssertTrue(placeChip.waitForExistence(timeout: 20), "Silu 应出现")

        let region = app.buttons["落区"]
        if region.waitForExistence(timeout: 5) { region.tap(); usleep(400_000) }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.42))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.55))
        start.press(forDuration: 0.15, thenDragTo: end)
        sleep(1)

        let solve = app.buttons["求解"]
        XCTAssertTrue(solve.waitForExistence(timeout: 5) && solve.isEnabled, "应可求解")
        solve.tap()
        sleep(5)
        snap(app, "x6-silu-solved-before-adjust")

        // Open spin pad via instrument column mini (accessibility often "打点").
        let spinEntry = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS '打点' OR identifier CONTAINS 'spin'")
        ).firstMatch
        if spinEntry.waitForExistence(timeout: 4) {
            spinEntry.tap()
        } else {
            // Fallback: tap lower-right instrument stack (spin mini sits above power).
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.62)).tap()
        }
        sleep(1)
        snap(app, "x6-silu-spin-pad-open")

        // Single drag into lower-left quadrant (spinY− + spinX+) — proves full-axis fine-tune;
        // status shows「微调 · 低杆左塞」and aim updates via forward re-predict.
        let padStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.52))
        let padLowLeft = app.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: 0.64))
        padStart.press(forDuration: 0.12, thenDragTo: padLowLeft)
        sleep(4)
        snap(app, "x6-silu-spin-low-left-aim-linked")
        app.terminate()
    }
}
