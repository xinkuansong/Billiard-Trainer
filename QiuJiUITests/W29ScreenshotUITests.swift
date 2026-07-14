import XCTest

/// W2-9 关键改动取证截图（toast / Paywall / 空态 CTA / 骨架 / 日限卡）。
final class W29ScreenshotUITests: XCTestCase {

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/docs/ui-polish/screenshots-w2-9",
            isDirectory: true)
    }

    private func snap(_ name: String, app: XCUIApplication) {
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
        _ = app // keep process alive until write finishes
    }

    private func launch(_ args: [String]) -> XCUIApplication {
        XCUIApplication.launchClean(extraArgs: args)
    }

    func testW29ToastSuccess() {
        let app = launch(["-w29.toast.success"])
        sleep(1)
        snap("toast-success", app: app)
    }

    func testW29ToastWarning() {
        let app = launch(["-w29.toast.warning"])
        sleep(1)
        snap("toast-warning", app: app)
    }

    func testW29DailyLimit() {
        let app = launch(["-w29.dailyLimit"])
        sleep(1)
        snap("daily-limit-gate", app: app)
    }

    func testW29Skeleton() {
        let app = launch(["-w29.skeleton"])
        sleep(1)
        snap("list-skeleton", app: app)
    }

    func testW29EmptyCTA() {
        let app = launch(["-w29.emptyCTA"])
        sleep(1)
        snap("empty-state-cta", app: app)
    }

    func testW29Paywall() {
        let app = launch([])
        app.switchTab(.profile)
        sleep(2)
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Pro' OR label CONTAINS '订阅' OR label CONTAINS '升级'")).firstMatch
        if entry.waitForExistence(timeout: 6) {
            entry.tap()
            sleep(2)
            snap("paywall", app: app)
            let cta = app.buttons.matching(NSPredicate(format: "label CONTAINS '立即'")).firstMatch
            if cta.waitForExistence(timeout: 2) {
                cta.press(forDuration: 0.4)
                snap("paywall-press", app: app)
            }
        } else {
            snap("paywall-entry-missing", app: app)
        }
    }
}
