
final class TutorialGalleryDiagnosisUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false; executionTimeAllowance = 180 }
    func testOriginalAndWithoutInnerDrag() {
        for disable in [false, true] {
            let app = XCUIApplication.launchClean(extraArgs: ["-liveReview.pageId=drill-detail", "-liveReview.contentId=drill_c011", "-v50.inMemoryStore", "-forcePremium"] + (disable ? ["-gallery.disableInnerDrag"] : []))
            let entry = app.buttons["查看精讲"].firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 15))
            for _ in 0..<8 where !entry.isHittable { app.swipeUp() }
            entry.tap()
            print("GALLERY_AX_AFTER_ENTRY\n" + app.debugDescription)
            let caption = app.staticTexts["开局：按图换位，把 8 号球打进左下角袋"].firstMatch
            for _ in 0..<18 {
                if caption.exists && caption.isHittable { break }
                let w=app.windows.firstMatch
                w.coordinate(withNormalizedOffset: CGVector(dx:0.5,dy:0.7)).press(forDuration:0.05,thenDragTo:w.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.4)))
            }
            XCTAssertTrue(caption.exists && caption.isHittable)
            let tapY = caption.frame.minY - 80
            XCTAssertGreaterThan(tapY, 130)
            app.windows.firstMatch.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:caption.frame.midX,dy:tapY)).tap()
            XCTAssertTrue(app.staticTexts["1 / 6"].waitForExistence(timeout: 8))
            capture(disable ? "control-before" : "original-before")
            let w=app.windows.firstMatch
            for _ in 0..<2 {
                w.coordinate(withNormalizedOffset: CGVector(dx: 0.8,dy: 0.5)).press(forDuration: 0.05, thenDragTo: w.coordinate(withNormalizedOffset: CGVector(dx: 0.2,dy: 0.5)))
                Thread.sleep(forTimeInterval: 0.5)
                if app.staticTexts["2 / 6"].exists { break }
            }
            capture(disable ? "control-after" : "original-after")
            XCTAssertTrue(app.staticTexts[disable ? "2 / 6" : "1 / 6"].exists, "Original should reproduce blocking; removing only inner drag should restore paging")
            print("GALLERY_DIAGNOSIS innerDragDisabled=\(disable) page=\(disable ? 2 : 1)")
            app.terminate()
        }
    }
    private func capture(_ name:String) { let a=XCTAttachment(screenshot:XCUIScreen.main.screenshot());a.name=name;a.lifetime = .keepAlways;add(a) }
}
