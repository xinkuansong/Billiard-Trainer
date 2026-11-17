import XCTest

final class SpatialPracticeUITests:XCTestCase {
    private var app:XCUIApplication!
    override func setUp() { continueAfterFailure=false }
    override func tearDown() { app?.terminate();XCUIDevice.shared.orientation = .portrait }
    private func element(_ id:String)->XCUIElement { app.descendants(matching:.any).matching(identifier:id).firstMatch }
    private func ready(_ e:XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == true AND hittable == true AND enabled == true"),object:e)],timeout:90),.completed,e.debugDescription)
    }
    private func capture(_ name:String) {
        let attachment=XCTAttachment(screenshot:XCUIScreen.main.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
    func testAdvancedEntryControlsStrikeRetryReplayAndReturn() {
        app=XCUIApplication.launchClean(extraArgs:["-v50.inMemoryStore","-freeLayout.ephemeral","-forcePremium"])
        app.switchTab(.angle)
        let advanced=app.buttons["angleHomeTab_进阶"];ready(advanced);advanced.tap()
        capture("v66-advanced-entry")
        let entry=app.buttons["扎杆与跳球"];ready(entry);entry.tap()
        let elevation=element("masseJump.elevation");ready(elevation)
        capture("v66-ready")
        elevation.tap()
        let slider=element("masseJump.elevationSlider");ready(slider)
        slider.adjust(toNormalizedSliderPosition:0.59)
        capture("v66-elevation")
        app.buttons["完成"].tap()
        let strike=element("masseJump.strike");ready(strike);strike.tap()
        let replay=element("masseJump.replay");ready(replay)
        capture("v66-settled")
        replay.tap();ready(element("masseJump.retry"))
        element("masseJump.retry").tap();ready(strike)
        capture("v66-retry")
        let back=element("masseJump.back");ready(back);back.tap()
        ready(advanced)
        let bank=app.buttons["翻袋练习"]
        for _ in 0..<5 where !bank.isHittable { app.swipeUp() }
        ready(bank);bank.tap();ready(app.buttons["bank.start"])
        capture("v66-legacy-bank-settings")
    }
}
