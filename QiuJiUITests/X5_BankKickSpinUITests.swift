import XCTest

/// v8 X5：K11 求解模式打点盘可微调实操截图。
/// 产物落盘 `build/x5-screenshots/`（禁止写 `docs/ui-polish/`）。
final class X5_BankKickSpinUITests: XCTestCase {

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer-x5/build/x5-screenshots")
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

    private func dismissOnboardingIfNeeded(_ app: XCUIApplication) {
        let skip = app.buttons["跳过"]
        if skip.waitForExistence(timeout: 3) {
            skip.tap()
            sleep(1)
        }
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 15)
    }

    private func openSolver(_ app: XCUIApplication, title: String) -> Bool {
        dismissOnboardingIfNeeded(app)
        app.switchTab(.angle)
        sleep(1)
        let seg = app.buttons["angleHomeTab_解"]
        guard seg.waitForExistence(timeout: 6) else { return false }
        seg.tap()
        usleep(600_000)
        let card = app.buttons[title]
        guard card.waitForExistence(timeout: 6) else { return false }
        card.tap()
        sleep(3)
        return true
    }

    private func openSpinPad(_ app: XCUIApplication) -> Bool {
        // BTShotInstrumentColumn spin mini: accessibilityLabel "打点".
        let spinBtn = app.buttons["打点"]
        if spinBtn.waitForExistence(timeout: 8) {
            spinBtn.tap()
            sleep(1)
        } else {
            // Fallback: tap upper portion of instrument column.
            let power = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == 'solver.power'")).firstMatch
            guard power.waitForExistence(timeout: 4) else { return false }
            power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
            sleep(1)
        }
        let pad = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'solver.spinPad'")).firstMatch
        return pad.waitForExistence(timeout: 5)
    }

    func testX5_bank_solveMode_spinPad_adjust() {
        let app = XCUIApplication.launchClean()
        XCTAssertTrue(openSolver(app, title: "翻袋解球器"), "打开翻袋解球器")
        // Wait for solve debounce + engine.
        sleep(4)
        snap(app, "x5-bank-solve-before-spin")

        XCTAssertTrue(openSpinPad(app), "求解模式应能打开打点盘")
        snap(app, "x5-bank-solve-spinpad-open")

        let pad = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'solver.spinPad'")).firstMatch
        pad.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.45)).tap()
        sleep(2)
        snap(app, "x5-bank-solve-spin-adjusted")
    }

    func testX5_diamond_solveMode_spinPad_adjust() {
        let app = XCUIApplication.launchClean()
        XCTAssertTrue(openSolver(app, title: "反射解球器"), "打开反射解球器")
        sleep(4)
        snap(app, "x5-diamond-solve-before-spin")

        XCTAssertTrue(openSpinPad(app), "反射求解模式应能打开打点盘")
        snap(app, "x5-diamond-solve-spinpad-open")

        let pad = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'solver.spinPad'")).firstMatch
        pad.coordinate(withNormalizedOffset: CGVector(dx: 0.28, dy: 0.55)).tap()
        sleep(2)
        snap(app, "x5-diamond-solve-spin-adjusted")
    }
}
