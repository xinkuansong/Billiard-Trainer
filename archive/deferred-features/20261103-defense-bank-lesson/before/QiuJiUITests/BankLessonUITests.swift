import XCTest
import UIKit

final class BankLessonUITests: XCTestCase {
    private func screenshot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        if let directory = ProcessInfo.processInfo.environment["BANK_LESSON_SHOTS"] {
            do {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                try shot.pngRepresentation.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name + ".png"))
            } catch { XCTFail("Screenshot export: \(error)") }
        }
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<18 {
            if element.exists && element.isHittable { return }
            let scroll = app.scrollViews.allElementsBoundByIndex.max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height } ?? app.scrollViews.firstMatch
            let above = element.exists && element.frame.maxY < scroll.frame.minY + 30
            scroll.coordinate(withNormalizedOffset: .init(dx: 0.07, dy: above ? 0.3 : 0.8))
                .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: .init(dx: 0.07, dy: above ? 0.8 : 0.3)))
        }
        XCTFail("Could not reveal \(element)")
    }

    private func moveToEnd(_ slider: XCUIElement, maximum: Bool) {
        slider.adjust(toNormalizedSliderPosition: maximum ? 1 : 0)
        // XCTest's normalized adjustment may stop just short of a continuous slider endpoint.
        slider.coordinate(withNormalizedOffset: .init(dx: maximum ? 0.97 : 0.03, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: .init(dx: maximum ? 1.15 : -0.15, dy: 0.5)))
    }

    func testLessonFromLearnAndInteractiveSections() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean()
        app.switchTab(.angle)
        let learn = app.buttons["angleHomeTab_学"]
        XCTAssertTrue(learn.waitForExistence(timeout: 8)); learn.tap()
        screenshot("00-learn-entry")
        let lesson = app.buttons["一库翻袋"]
        reveal(lesson, in: app); screenshot("00b-lesson-entry"); lesson.tap()
        XCTAssertTrue(app.navigationBars["一库翻袋"].waitForExistence(timeout: 10))
        let progress = app.sliders["bankLesson.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 15))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: progress)], timeout: 30), .completed)
        screenshot("01-overview")
        moveToEnd(progress, maximum: true)
        XCTAssertEqual(progress.value as? String, "目标球入袋")
        moveToEnd(progress, maximum: false)
        let mirror = app.switches["bankLesson.mirrorToggle"]
        reveal(mirror, in: app); screenshot("02-mirror")
        mirror.tap(); XCTAssertEqual(mirror.value as? String, "0")
        mirror.tap(); XCTAssertEqual(mirror.value as? String, "1")
        let target = app.sliders["bankLesson.target"]
        reveal(target, in: app); moveToEnd(target, maximum: true)
        XCTAssertTrue((target.value as? String ?? "").contains("35"))
        let aim = app.sliders["bankLesson.aim"]
        reveal(aim, in: app); moveToEnd(aim, maximum: true)
        XCTAssertTrue(app.staticTexts["bankLesson.aimFeedback"].label.contains("37 mm"))
        screenshot("03-ghost")
        for identifier in ["bankLesson.ideal", "bankLesson.actual"] {
            let toggle = app.switches[identifier]
            reveal(toggle, in: app); toggle.tap()
            XCTAssertEqual(toggle.value as? String, "0")
            toggle.tap(); XCTAssertEqual(toggle.value as? String, "1")
        }
        screenshot("03b-comparison")
        let power = app.sliders["bankLesson.power"]
        reveal(power, in: app)
        moveToEnd(power, maximum: false)
        let result = app.staticTexts["bankLesson.result"]
        reveal(result, in: app)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS '力度不足'"), object: result)], timeout: 20), .completed)
        screenshot("04-low-power")
        reveal(power, in: app)
        moveToEnd(power, maximum: true)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS '3 次碰库'"), object: result)], timeout: 20), .completed)
        screenshot("05-high-power")
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
            XCTAssertEqual(power.value as? String, "4.0 m/s")
            screenshot("05b-high-power-landscape")
            XCUIDevice.shared.orientation = .portrait
        }
        let comparison = app.switches["bankLesson.reference"]
        reveal(comparison, in: app); comparison.tap()
        XCTAssertEqual(comparison.value as? String, "0")
        comparison.tap(); XCTAssertEqual(comparison.value as? String, "1")
        let closeup = app.descendants(matching: .any).matching(identifier: "bankLesson.pocket").firstMatch
        XCTAssertTrue(TheoryFigureEvidence.scrollFullyIntoView(closeup, app: app, navigationTitle: "一库翻袋"))
        screenshot("05c-pocket-closeup")
        let phase = app.segmentedControls["bankLesson.phase"]
        reveal(phase, in: app); phase.buttons["碰库后"].tap()
        XCTAssertTrue(app.staticTexts["bankLesson.observation"].label.contains("袋口哪一侧"))
        screenshot("06-observe")
        let practice = app.buttons["翻袋练习"].firstMatch
        // NavigationLink may be exposed as a button; use semantic text as a fallback.
        let link = practice.exists ? practice : app.staticTexts["翻袋练习"].firstMatch
        reveal(link, in: app); link.tap()
        XCTAssertTrue(app.buttons["bank.start"].waitForExistence(timeout: 15))
        screenshot("07-practice-destination")
    }
    func testTabletLandscapeReadingLayout() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("Tablet window coverage") }
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: ["-pro.route=bankLesson"])
        XCTAssertTrue(app.navigationBars["一库翻袋"].waitForExistence(timeout: 15))
        XCUIDevice.shared.orientation = .landscapeLeft
        let window = app.windows.firstMatch
        if window.frame.minX > 1 || window.frame.minY > 40 {
            let before = window.frame
            window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
            if abs(window.frame.width - before.width) < 1 {
                window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap()
            }
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            window.frame.width > window.frame.height && window.frame.minX < 1
        }, object: nil)], timeout: 10), .completed)
        screenshot("08-landscape-full-window")
        let mirror = app.descendants(matching: .any).matching(identifier: "bankLesson.mirror").firstMatch
        var visible = false
        for _ in 0..<16 {
            let viewport = TheoryFigureEvidence.viewport(of: app, navigationTitle: "一库翻袋")
            let frame = mirror.frame
            if frame.minY >= viewport.minY + 4 && frame.maxY <= viewport.maxY - 4 { visible = true; break }
            let delta = min(140, max(-140, frame.midY - viewport.midY))
            let start = app.coordinate(withNormalizedOffset: .init(dx: 0.25, dy: 0.55))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(.init(dx: 0, dy: -delta)))
        }
        XCTAssertTrue(visible, mirror.debugDescription)
        screenshot("09-landscape-mirror")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.navigationBars["一库翻袋"].exists)
    }

}
