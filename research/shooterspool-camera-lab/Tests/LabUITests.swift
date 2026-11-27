import XCTest

final class LabUITests: XCTestCase {
    let app = XCUIApplication()
    var status: XCUIElement { app.staticTexts["lab.status"] }
    func wait(_ seconds: Double = 25, for condition: @escaping () -> Bool) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: seconds), .completed, app.debugDescription)
    }
    func enter(_ title: String) {
        continueAfterFailure = false
        app.launch()
        let button = app.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 15), app.debugDescription)
        button.tap()
        XCTAssertTrue(status.waitForExistence(timeout: 30), app.debugDescription)
    }
    func choose(_ name: String) {
        app.buttons[name].tap()
        wait { self.status.label.contains(name) }
    }
    func drag() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: 0.57))
        start.press(forDuration: 0.08, thenDragTo: start.withOffset(CGVector(dx: 56, dy: 1)))
    }
    var line: String { status.value as? String ?? "" }
    func capture(_ name: String) {
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = name
        capture.lifetime = .keepAlways
        add(capture)
    }
    func testOpenTable() {
        enter("普通散局")
        wait { self.status.label.contains("进袋") && !self.line.contains("aim=nil") }
        let pocket = line
        drag()
        XCTAssertEqual(line, pocket)
        choose("俯身瞄准")
        capture("俯身进袋")
        let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
        XCTAssertTrue(wheel.exists, app.debugDescription)
        wheel.tap()
        XCTAssertEqual(line, pocket)
        let center = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.64))
        center.press(forDuration: 0.08, thenDragTo: center.withOffset(CGVector(dx: 0, dy: -24)))
        wait { self.status.label.contains("自由") && self.line != pocket }
        let wheelLine = line
        drag()
        wait { self.line != wheelLine }
        let free = line
        choose("全局观察")
        drag()
        XCTAssertEqual(line, free)
        choose("临时俯视")
        app.buttons["临时俯视"].tap()
        wait { self.status.label.contains("全局观察") }
        app.buttons["全局观察"].tap()
        wait { self.status.label.contains("俯身瞄准") }
        XCTAssertEqual(line, free)
        let strike = app.buttons["dailyClearance.strike"]
        wait { strike.exists && strike.isEnabled }
        strike.tap()
        wait(45) { self.line.contains("shots=1") }
        wait { strike.isEnabled }
        strike.tap()
        wait(45) { self.line.contains("shots=2") }
        capture("普通散局连续两杆")
    }
    func testRail() {
        enter("贴库薄球")
        wait { !self.line.isEmpty && !self.line.contains("aim=nil") }
        choose("俯身瞄准")
        capture("贴库薄球")
    }
    func testRack() {
        enter("中八开球")
        let strike = app.buttons["dailyClearance.strike"]
        wait { strike.exists && strike.isEnabled }
        choose("俯身瞄准")
        wait { strike.isEnabled }
        strike.tap()
        choose("全局观察")
        let confirm = app.buttons["dailyClearance.confirmBreak"]
        wait(55) { confirm.exists || !self.status.label.contains("开球") || self.app.buttons["break.confirm"].exists }
        if confirm.exists { confirm.tap() }
        else if app.buttons["break.confirm"].exists { app.buttons["break.confirm"].tap() }
        wait { !self.status.label.contains("开球") }
        XCTAssertTrue(status.label.contains("全局观察"))
        capture("开球散球交接")
        app.buttons["全局观察"].tap()
        wait { self.status.label.contains("站立找线") }
        let before = line
        wait { strike.exists && strike.isEnabled && !self.line.contains("aim=nil") }
        strike.tap()
        wait(50) { !self.line.contains("shots=0") && self.line != before }
    }
}
