import XCTest

final class PocketToleranceUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false }
    override func tearDown() { app?.terminate(); XCUIDevice.shared.orientation = .portrait }
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier:id).firstMatch }
    private func ready(_ e: XCUIElement) { XCTAssertTrue(e.waitForExistence(timeout:60)) }
    private func waitProbe(_ text: String) {
        let e = element("pocketTolerance.probe")
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"value CONTAINS %@",text),object:e)],timeout:30),.completed)
    }
    private func waitCamera(overview: Bool = false) throws {
        let diagnostic = element("v63.cameraDiagnostics")
        ready(diagnostic)
        let settled = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value CONTAINS %@", "twoViewMoving=false"),object:diagnostic)
        let settledResult = XCTWaiter.wait(for:[settled],timeout:30)
        let text = XCTAttachment(string: diagnostic.value as? String ?? "missing"); text.name = "camera-diagnostic"; text.lifetime = .keepAlways; add(text)
        XCTAssertEqual(settledResult,.completed)
        if overview {
            let data = try tableData()
            let t = try XCTUnwrap(data["displayedTable"] as? [Double])
            let v = try XCTUnwrap(data["displayedViewport"] as? [Double])
            capture("overview-bounds")
            XCTAssertGreaterThanOrEqual(t[0],v[0]-2)
            XCTAssertGreaterThanOrEqual(t[1],v[1]-2)
            XCTAssertLessThanOrEqual(t[2],v[0]+v[2]+2)
            XCTAssertLessThanOrEqual(t[3],v[1]+v[3]+2)
        }
    }
    private func capture(_ name: String) {
        let a = XCTAttachment(screenshot:XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func open() {
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication.launchClean(extraArgs:["-v50.inMemoryStore","-3dDrag.probe","-pocketTolerance.probe","-v63.cameraDiagnostics","-freeLayout.ephemeral"])
        app.switchTab(.angle); app.buttons["angleHomeTab_学"].tap()
        let card = app.buttons["进球容错角"]
        for _ in 0..<7 { if card.isHittable { break }; app.swipeUp() }
        ready(card); card.tap(); ready(app.buttons["pocketTolerance.more"])
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let window = self.app.windows.firstMatch.frame
            return window.width > window.height && self.app.buttons["pocketTolerance.more"].isHittable
        },object:app)],timeout:20),.completed)
    }
    private func tableData() throws -> [String:Any] {
        let t = element("table.scene"); ready(t)
        return try XCTUnwrap(JSONSerialization.jsonObject(with:Data(try XCTUnwrap(t.value as? String).utf8)) as? [String:Any])
    }
    private func tapPocket(_ index: Int) throws {
        let entries = try XCTUnwrap(try tableData()["pockets"] as? [[String:Any]])
        let p = try XCTUnwrap(entries.first { $0["index"] as? Int == index }?["screen"] as? [Double])
        element("table.scene").coordinate(withNormalizedOffset:.zero).withOffset(.init(dx:p[0],dy:p[1])).tap()
        waitProbe("pocket=\(index)")
    }
    private func view(_ mode: String) {
        app.buttons["pocketTolerance.more"].tap()
        let row = app.buttons["pocketTolerance.cameraMode"]; ready(row)
        if row.value as? String != mode { row.tap() }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@",mode),object:row)],timeout:20),.completed)
        capture("pocket-menu-" + mode)
        XCTAssertFalse(app.buttons["controlLayout.open"].exists)
        app.buttons["pocketTolerance.dismissMenu"].tap()
    }
    func testProductionEntrySelectionDragAndBothViews() throws {
        open(); view("2D")
        waitProbe("target=_3 pocket=-1 count=1 edges=0")
        capture("pocket-empty-selection")
        try tapPocket(4); waitProbe("edges=2")
        capture("pocket-2D-window")
        let initial = element("pocketTolerance.angle").value as? String
        let balls = try XCTUnwrap(try tableData()["balls"] as? [[String:Any]])
        let p = try XCTUnwrap(balls.first { $0["key"] as? String == "_3" }?["screen"] as? [Double])
        let origin = element("table.scene").coordinate(withNormalizedOffset:.zero)
        origin.withOffset(.init(dx:p[0],dy:p[1])).press(forDuration:0.15,
            thenDragTo:origin.withOffset(.init(dx:p[0]+65,dy:p[1]+25)),withVelocity:XCUIGestureVelocity(rawValue:150),thenHoldForDuration:0.2)
        waitProbe("pocket=4");waitProbe("edges=2")
        XCTAssertNotEqual(element("pocketTolerance.angle").value as? String, initial)
        capture("pocket-dragged")
        app.buttons["paletteBall__1"].tap();waitProbe("target=_1 pocket=-1 count=2 edges=0")
        try tapPocket(2); waitProbe("edges=2")
        app.buttons["paletteBall__3"].tap();waitProbe("target=_3 pocket=4 count=2 edges=2")
        let before = element("pocketTolerance.angle").value as? String
        view("3D");waitProbe("target=_3 pocket=4 count=2 edges=2")
        XCTAssertEqual(element("pocketTolerance.angle").value as? String,before)
        XCTAssertFalse(app.buttons["shotCamera.firstPerson"].exists)
        ready(app.buttons["shotCamera.target"]);try waitCamera(overview:true);capture("pocket-3D-window")
        app.buttons["shotCamera.target"].tap();try waitCamera();capture("pocket-3D-target")
        app.buttons["paletteBall__1"].tap();waitProbe("target=_1 pocket=2 count=2 edges=2")
        app.buttons["dailyClearance.observeTable"].tap();try waitCamera(overview:true);capture("pocket-3D-overview")
        view("2D"); waitProbe("target=_1 pocket=2 count=2 edges=2")
    }
    func testRemovalBackgroundAndReentry() throws {
        open(); view("2D");try tapPocket(4);waitProbe("edges=2")
        let before = element("pocketTolerance.probe").value as? String
        XCUIDevice.shared.press(.home);app.activate()
        waitProbe("target=_3 pocket=4 count=1 edges=2")
        XCTAssertEqual(element("pocketTolerance.probe").value as? String,before)
        let balls = try XCTUnwrap(try tableData()["balls"] as? [[String:Any]])
        let p = try XCTUnwrap(balls.first { $0["key"] as? String == "_3" }?["screen"] as? [Double])
        element("table.scene").coordinate(withNormalizedOffset:.zero).withOffset(.init(dx:p[0],dy:p[1]))
            .press(forDuration:0.2,thenDragTo:app.buttons["paletteBall__3"].coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.5)),
                withVelocity:XCUIGestureVelocity(rawValue:150),thenHoldForDuration:0.2)
        waitProbe("target=none pocket=-1 count=0 edges=0")
        view("3D");try waitCamera(overview:true)
        XCTAssertFalse(app.buttons["shotCamera.target"].isEnabled)
        capture("pocket-no-balls-3D")
        app.buttons["paletteBall__3"].tap();waitProbe("target=_3 pocket=-1 count=1 edges=0")
        XCTAssertTrue(app.buttons["shotCamera.target"].isEnabled)
        app.buttons["pocketTolerance.back"].tap()
        let card = app.buttons["进球容错角"];ready(card);card.tap()
        waitProbe("target=_3 pocket=-1 count=1 edges=0")
        capture("pocket-reentry")
    }
    func testPadRotationAndMenuState() throws {
        open(); view("2D"); try tapPocket(4);waitProbe("edges=2")
        for mode in ["2D","3D"] {
            view(mode)
            for direction in [UIDeviceOrientation.landscapeLeft,.portrait] {
                XCUIDevice.shared.orientation = direction
                let isPad = UIDevice.current.userInterfaceIdiom == .pad
                if isPad {
                    XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
                        let f = self.app.windows.firstMatch.frame
                        return direction == .portrait ? f.height > f.width : f.width > f.height
                    },object:app)],timeout:15),.completed)
                }
                waitProbe("target=_3 pocket=4 count=1 edges=2")
                XCTAssertTrue(app.windows.firstMatch.frame.contains(element("pocketTolerance.angle").frame))
                if mode == "3D" { try waitCamera(overview:true) }
                capture("pocket-\(mode)-\(direction.rawValue)")
            }
        }
        app.buttons["pocketTolerance.more"].tap();let grid = app.buttons["menu.tableGrid"];ready(grid)
        let before = grid.value as? String;grid.tap();XCTAssertNotEqual(grid.value as? String,before)
        capture("pocket-grid-menu");app.buttons["pocketTolerance.dismissMenu"].tap();capture("pocket-grid-visible")
    }
}
