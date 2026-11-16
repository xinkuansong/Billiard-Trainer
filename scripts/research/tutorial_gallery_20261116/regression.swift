
/// Real detail -> tutorial -> media viewer, including UIKit/SwiftUI gesture arbitration.
final class TutorialGalleryGestureUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; executionTimeAllowance = 240; XCUIDevice.shared.orientation = .portrait }
    override func tearDownWithError() throws { app?.terminate(); app = nil; XCUIDevice.shared.orientation = .portrait }

    func testAllSixImagesPageBothDirectionsAndReopenAtTappedImage() {
        openGallery()
        for page in 2...6 { drag(0.8,0.5,0.2,0.5); expectPage(page) }
        capture("sixth-image")
        drag(0.8,0.5,0.2,0.5); expectPage(6)
        for page in stride(from: 5, through: 1, by: -1) { drag(0.2,0.5,0.8,0.5); expectPage(page) }
        drag(0.2,0.5,0.8,0.5); expectPage(1)
        capture("first-image-after-round-trip")
        app.buttons["tutorialMediaClose"].tap()
        expectClosed()
        openPoster("drill_c011_s01")
        expectPage(2)
        drag(0.2,0.5,0.8,0.5); expectPage(1)
    }

    func testDoubleTapPinchPanAndPagingAfterZoomReset() {
        openGallery()
        XCTAssertTrue(activeMedia.waitForExistence(timeout: 5))
        activeMedia.doubleTap(); expectZoom(250)
        capture("double-tap-zoom")
        drag(0.7,0.5,0.3,0.5); expectPage(1); expectZoom(250)
        capture("zoomed-horizontal-pan")
        drag(0.5,0.35,0.5,0.7); expectPage(1); expectZoom(250)
        capture("zoomed-vertical-pan-stays-open")
        activeMedia.doubleTap(); expectZoom(100)
        drag(0.8,0.5,0.2,0.5); expectPage(2)
        activeMedia.pinch(withScale: 2, velocity: 1)
        XCTAssertTrue(wait { self.zoomPercent > 120 }, "Pinch must actually increase zoom")
        capture("pinch-zoom")
        // XCTest's synthesized pinch factor is not the recognizer's measured
        // scale: recognition slop can leave the image above 1x after one pinch.
        for _ in 0..<3 where zoomPercent > 100 {
            let before = zoomPercent
            activeMedia.pinch(withScale: 0.3, velocity: -1)
            XCTAssertTrue(wait { self.zoomPercent < before }, "Each inward pinch must reduce the actual zoom")
        }
        expectZoom(100)
        drag(0.2,0.5,0.8,0.5); expectPage(1)
        capture("pinch-reset-and-previous-image")
        drag(0.5,0.35,0.5,0.72);expectClosed()
    }

    func testShortDownwardAndUpwardDragsDoNotDismissButDownwardDoes() {
        openGallery()
        drag(0.5,0.45,0.5,0.49); expectPage(1)
        capture("short-drag-restored")
        drag(0.5,0.65,0.5,0.3); expectPage(1)
        capture("upward-drag-stays-open")
        drag(0.8,0.5,0.2,0.5); expectPage(2)
        drag(0.5,0.3,0.5,0.7); expectClosed()
        openPoster("drill_c011_initial");expectPage(1)
        app.buttons["tutorialMediaClose"].tap();expectClosed()
    }

    private func openGallery() {
        app=XCUIApplication.launchClean(extraArgs:["-liveReview.pageId=drill-detail","-liveReview.contentId=drill_c011","-v50.inMemoryStore","-forcePremium"])
        let entry=app.buttons["查看精讲"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout:15))
        for _ in 0..<8 where !entry.isHittable {app.swipeUp()}
        entry.tap();openPoster("drill_c011_initial");expectPage(1);capture("initial-image")
    }
    private func openPoster(_ name:String) {
        let label = name == "drill_c011_initial" ? "开局：按图换位，把 8 号球打进左下角袋" : "第1杆：瞄准角约 0.1°"
        let caption=app.staticTexts[label].firstMatch
        for _ in 0..<18 {
            if caption.exists && caption.isHittable {break}
            drag(0.5,0.7,0.5,0.4)
        }
        XCTAssertTrue(caption.exists && caption.isHittable)
        let tapY=caption.frame.minY-80
        XCTAssertGreaterThan(tapY,130)
        app.windows.firstMatch.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:caption.frame.midX,dy:tapY)).tap()
    }
    private func expectPage(_ page:Int,file:StaticString=#filePath,line:UInt=#line) {
        XCTAssertTrue(wait {self.app.staticTexts["\(page) / 6"].exists},"Expected page \(page)",file:file,line:line)
    }
    private var activeMedia: XCUIElement {
        let elements=app.descendants(matching:.any).matching(identifier:"tutorialMediaZoom")
        return elements.allElementsBoundByIndex.first(where: { $0.isHittable }) ?? elements.firstMatch
    }
    private var zoomPercent:Int {
        let value=activeMedia.value as? String ?? ""
        return Int(value.filter(\.isNumber)) ?? -1
    }
    private func expectZoom(_ percent:Int,file:StaticString=#filePath,line:UInt=#line) {
        XCTAssertTrue(wait { self.zoomPercent == percent },"Expected zoom \(percent)%, got \(zoomPercent)",file:file,line:line)
    }
    private func expectClosed(file:StaticString=#filePath,line:UInt=#line) {
        XCTAssertTrue(wait { !self.app.buttons["tutorialMediaClose"].exists && self.app.buttons["tutorialScrollTopButton"].isHittable },"Viewer should return to tutorial",file:file,line:line)
    }
    private func drag(_ x1:CGFloat,_ y1:CGFloat,_ x2:CGFloat,_ y2:CGFloat) {
        let w=app.windows.firstMatch
        w.coordinate(withNormalizedOffset:CGVector(dx:x1,dy:y1)).press(forDuration:0.05,thenDragTo:w.coordinate(withNormalizedOffset:CGVector(dx:x2,dy:y2)))
    }
    private func wait(_ condition:()->Bool)->Bool {let end=Date().addingTimeInterval(6);repeat {if condition(){return true};Thread.sleep(forTimeInterval:0.15)}while Date()<end;return false}
    private func capture(_ name:String) {let a=XCTAttachment(screenshot:XCUIScreen.main.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
}
