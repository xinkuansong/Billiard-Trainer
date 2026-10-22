import XCTest

final class CustomFormationUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }
    override func tearDownWithError() throws { app?.terminate() }
    private func launch(direct: Bool = true) {
        let env = ProcessInfo.processInfo.environment
        let dark = env["FORMATION_DARK"] == "1" || env["TEST_RUNNER_FORMATION_DARK"] == "1"
        var args = ["-forcePremium", dark ? "-v54.forceDark" : "-v54.forceLight", "-3dDrag.probe"]
        if direct { args += ["-deeplink.customFormation", "-customFormation.owner=ui-\(UUID())"] }
        app = .launchClean(extraArgs: args)
        if !direct {
            app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
            let card = app.buttons["自定义球形"]
            for _ in 0..<5 { if card.exists && card.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
        }
        for _ in 0..<8 {
            if app.buttons["formation.new"].exists && app.buttons["formation.new"].isHittable { break }
            app.swipeUp()
        }
        ready(app.buttons["formation.new"])
    }
    private func ready(_ e: XCUIElement, timeout: TimeInterval = 60) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: e)], timeout: timeout), .completed)
    }
    private func snap(_ name: String) throws {
        let s = XCUIScreen.main.screenshot(), a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
        let env = ProcessInfo.processInfo.environment
        if let path = env["V52_SHOT_DIR"] ?? env["TEST_RUNNER_V52_SHOT_DIR"] {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            try s.pngRepresentation.write(to: URL(fileURLWithPath: path).appendingPathComponent(name + ".png"))
        }
    }
    private var table: XCUIElement { app.descendants(matching: .any)["table.scene"] }
    private func balls() throws -> [[String: Any]] {
        let value = try XCTUnwrap(table.value as? String)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
        return try XCTUnwrap(json["balls"] as? [[String: Any]]).filter { $0["key"] as? String != "cueBall" }
    }
    private func count(_ n: Int) {
        let p = NSPredicate { [weak self] _, _ in (try? self?.balls().count) == n }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: p, object: nil)], timeout: 20), .completed)
    }
    private func menu(_ id: String) {
        app.buttons["freeplay.moreMenu"].tap()
        let e = app.buttons[id]
        for _ in 0..<5 {
            if e.exists && e.isHittable { break }
            app.scrollViews["dailyClearance.menuScroll"].swipeUp()
        }
        ready(e); e.tap()
    }
    private func newTemplate(_ n: Int) {
        app.buttons["formation.new"].tap(); ready(app.buttons["paletteBall__1"])
        if UIDevice.current.userInterfaceIdiom != .pad { XCUIDevice.shared.orientation = .landscapeLeft }
        for i in 0..<n { app.buttons["paletteBall__1"].tap(); count(i + 1) }
    }
    private func setView(_ value: String) {
        app.buttons["freeplay.moreMenu"].tap()
        let view = app.buttons["freeplay.cameraMode"]; ready(view)
        if view.value as? String != value { view.tap() }
        app.buttons["关闭菜单"].tap()
        ready(app.buttons["dailyClearance.strike"])
    }
    private func save(_ name: String) {
        app.buttons["formation.edit.save"].tap()
        let field = app.alerts["保存模板"].textFields.firstMatch; ready(field); field.tap()
        let old = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + name)
        // iOS 26 exposes the same native alert button twice (wrapper and child).
        // Tap the verified first frame, avoiding XCTest's ambiguous name rebinding.
        let save = app.alerts["保存模板"].buttons.matching(identifier: "formation.save.confirm").element(boundBy: 0)
        ready(save); save.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        ready(app.buttons["formation.start"])
    }
    private func probe() throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try XCTUnwrap(table.value as? String).utf8)) as? [String: Any])
    }
    private func tapBall(_ ball: [String: Any]) throws {
        let p = try XCTUnwrap(ball["screen"] as? [Double])
        table.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx:p[0],dy:p[1])).tap()
    }
    private func handles(_ prefix: String = "formation.vertex.") throws -> [[String:Any]] {
        try XCTUnwrap(probe()["formationHandles"] as? [[String:Any]]).filter { ($0["name"] as? String)?.hasPrefix(prefix) == true }
    }
    private func readout(_ id: String) -> XCUIElement { app.descendants(matching:.any)["formation.parameter." + id].firstMatch }
    private func value(_ id: String) throws -> Double { try XCTUnwrap(Double(try XCTUnwrap(readout(id).value as? String))) }
    private func coordinate(_ object: [String:Any]) throws -> XCUICoordinate {
        let p = try XCTUnwrap(object["screen"] as? [Double])
        return table.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:p[0],dy:p[1]))
    }
    private func assertHandleFingerClearance(_ handle: [String:Any], prefix: String, dx: CGFloat) throws {
        let name = try XCTUnwrap(handle["name"] as? String)
        let before = try XCTUnwrap(handle["world"] as? [Double])
        let origin = try coordinate(handle)
        origin.tap()
        func current() throws -> [String:Any] { try XCTUnwrap(handles(prefix).first { $0["name"] as? String == name }) }
        XCTAssertEqual(try current()["world"] as? [Double],before,"Tap must not move or replace a handle")
        origin.press(forDuration:0.15,thenDragTo:origin.withOffset(CGVector(dx:dx > 0 ? 18 : -18,dy:0)))
        let afterShort = try XCTUnwrap(current()["world"] as? [Double])
        for i in 0..<3 { XCTAssertEqual(afterShort[i],before[i],accuracy:0.00001,"Movement inside the 52pt ball clearance must stay still") }
        let screen = try XCTUnwrap(handle["screen"] as? [Double])
        origin.press(forDuration:0.15,thenDragTo:origin.withOffset(CGVector(dx:dx,dy:0)))
        let after = try XCTUnwrap(current()["screen"] as? [Double])
        let moved = (after[0]-screen[0]) * (dx > 0 ? 1 : -1)
        XCTAssertGreaterThan(moved,4)
        XCTAssertLessThanOrEqual(moved,Double(abs(dx))-50,"Handle must trail the finger like a ball")
    }
    private func assertEqualSpacing(_ members: [[String:Any]]) throws {
        let points = try members.map { try XCTUnwrap($0["world"] as? [Double]) }.sorted { $0[0] < $1[0] }
        let gaps = zip(points,points.dropFirst()).map { hypot($1[0]-$0[0],$1[2]-$0[2]) }
        for gap in gaps { XCTAssertEqual(gap,try XCTUnwrap(gaps.first),accuracy:0.001) }
    }
    private func assertLanes(_ right: [String]) {
        let ids = ["formation.tool.line","formation.tool.distance","formation.tool.angle","formation.edit.undo","formation.edit.redo"] + right
        let elements = ids.map { app.descendants(matching:.any)[$0].firstMatch }
        for element in elements {
            XCTAssertTrue(element.exists, element.identifier)
            if !element.identifier.hasPrefix("formation.parameter.") {
                XCTAssertGreaterThanOrEqual(element.frame.height,43)
                XCTAssertLessThanOrEqual(element.frame.height,48,element.identifier + " oversized hit area")
            } else { XCTAssertGreaterThan(element.frame.height,0) }
            XCTAssertTrue(app.frame.contains(element.frame),element.identifier + " outside window")
        }
        for (i,a) in elements.enumerated() { for b in elements.dropFirst(i+1) {
            XCTAssertFalse(a.frame.intersects(b.frame),a.identifier + " \(a.frame) overlaps " + b.identifier + " \(b.frame)")
        }}
        XCTAssertFalse(app.buttons["dailyClearance.strike"].exists)
        XCTAssertFalse(app.buttons["formation.nudge.up"].exists)
    }
    private func assertTitle(_ name: String) {
        let title = app.descendants(matching:.any)["formation.title"].firstMatch
        XCTAssertEqual(title.label,name)
        // Accessibility reports the visible glyph group, excluding unused frame space.
        XCTAssertGreaterThan(title.frame.width,0)
        XCTAssertLessThanOrEqual(title.frame.width,61)
        XCTAssertLessThanOrEqual(title.frame.height,35)
        XCTAssertTrue(app.frame.contains(title.frame))
        XCTAssertFalse(title.frame.intersects(app.buttons["paletteBall__1"].frame))
    }
    func testConnectedLinesEqualSpacingMeasurementsAndPractice() throws {
        launch(direct:false); newTemplate(0)
        assertTitle("未命名球形")
        assertLanes(["formation.edit.save"]); try snap("01-editor-empty")
        app.buttons["formation.tool.line"].tap()
        XCTAssertTrue(app.descendants(matching:.any)["formation.notice"].exists)
        try snap("00-info-hint")
        table.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.70)).tap()
        table.coordinate(withNormalizedOffset:CGVector(dx:0.65,dy:0.70)).tap()
        count(0)
        for i in 0..<3 { app.buttons["paletteBall__1"].tap(); count(i+1) }
        XCTAssertEqual(try value("count"),3)
        XCTAssertEqual(try value("length"),try value("spacing")*2,accuracy:0.11)
        try assertEqualSpacing(balls())
        let firstIDs = Set(try balls().compactMap { $0["key"] as? String })
        var endpoints = try handles().sorted { ($0["world"] as! [Double])[0] < ($1["world"] as! [Double])[0] }
        XCTAssertEqual(endpoints.count,2)
        let jointName = try XCTUnwrap(endpoints.last?["name"] as? String)
        app.buttons["formation.tool.line"].tap()
        try coordinate(endpoints[1]).tap()
        // Connect upward from the same endpoint without replacing the first line.
        let jointScreen = try XCTUnwrap(endpoints[1]["screen"] as? [Double])
        table.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:jointScreen[0],dy:table.frame.height*0.28)).tap()
        XCTAssertEqual(try handles().count,3)
        for i in 0..<2 { app.buttons["paletteBall__2"].tap(); count(4+i) }
        XCTAssertEqual(try value("count"),3)
        assertLanes(["formation.parameter.count","formation.parameter.spacing","formation.parameter.length","formation.edit.sort","formation.edit.delete","formation.edit.save"])
        try snap("02-connected-lines")
        let beforeLength = try value("length")
        let joint = try XCTUnwrap(handles().first { $0["name"] as? String == jointName })
        try assertHandleFingerClearance(joint,prefix:"formation.vertex.",dx:110)
        let afterLength = try value("length")
        XCTAssertGreaterThan(abs(afterLength-beforeLength),0.2)
        XCTAssertEqual(try value("length"),try value("spacing")*2,accuracy:0.11)
        try assertEqualSpacing(balls().filter { firstIDs.contains($0["key"] as? String ?? "") })
        try snap("03-endpoint-drag")
        app.buttons["formation.edit.undo"].tap()
        XCTAssertEqual(try value("length"),beforeLength,accuracy:0.11)
        app.buttons["formation.edit.redo"].tap()
        XCTAssertEqual(try value("length"),afterLength,accuracy:0.11)
        let stableBalls = try balls()
        app.buttons["formation.tool.distance"].tap()
        endpoints = try handles().sorted { ($0["world"] as! [Double])[0] < ($1["world"] as! [Double])[0] }
        try coordinate(endpoints[0]).tap(); try coordinate(endpoints[2]).tap()
        let a = endpoints[0]["world"] as! [Double], b = endpoints[2]["world"] as! [Double]
        XCTAssertEqual(try value("measurement"),hypot(a[0]-b[0],a[2]-b[2])*100,accuracy:0.11)
        assertLanes(["formation.parameter.measurement","formation.edit.clearMeasure","formation.edit.finish"])
        XCTAssertTrue(app.staticTexts["formation.measurement.label"].exists)
        try snap("04-distance")
        let m = try XCTUnwrap(handles("formation.measure.").last)
        let oldDistance = try value("measurement")
        try assertHandleFingerClearance(m,prefix:"formation.measure.",dx:-110)
        XCTAssertGreaterThan(abs(try value("measurement")-oldDistance),0.2)
        try snap("05-distance-drag")
        let distanceBeforeZoom = try value("measurement")
        let label = app.staticTexts["formation.measurement.label"]
        let labelBeforeZoom = label.frame
        table.pinch(withScale:1.2,velocity:1)
        // Wait for the next annotation frame after the camera gesture settles.
        let followsCamera = NSPredicate { _, _ in
            hypot(label.frame.midX-labelBeforeZoom.midX,label.frame.midY-labelBeforeZoom.midY) > 0.5
        }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:followsCamera,object:nil)],timeout:5),.completed)
        XCTAssertTrue(table.frame.contains(label.frame))
        let measuredPoints = try handles("formation.measure.").map { $0["screen"] as! [Double] }
        XCTAssertEqual(label.frame.midX,table.frame.minX + (measuredPoints[0][0]+measuredPoints[1][0])/2,accuracy:2)
        XCTAssertEqual(try value("measurement"),distanceBeforeZoom,accuracy:0.01)
        try snap("05a-distance-zoom")
        menu("formation.fit")
        app.buttons["formation.tool.angle"].tap()
        table.coordinate(withNormalizedOffset:CGVector(dx:0.3,dy:0.3)).tap()
        table.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.31)).tap()
        table.coordinate(withNormalizedOffset:CGVector(dx:0.51,dy:0.55)).tap()
        XCTAssertEqual(try value("measurement"),90,accuracy:0.2)
        XCTAssertTrue(app.staticTexts["formation.measurement.label"].exists)
        XCTAssertEqual(app.staticTexts["formation.measurement.label"].label,"90.0°")
        try snap("06-angle")
        let angleHandle = try XCTUnwrap(handles("formation.measure.").last)
        try assertHandleFingerClearance(angleHandle,prefix:"formation.measure.",dx:110)
        XCTAssertGreaterThan(abs(try value("measurement")-90),5)
        try snap("07-angle-drag")
        XCTAssertEqual(try balls().map { $0["world"] as! [Double] },stableBalls.map { $0["world"] as! [Double] })
        app.buttons["formation.edit.finish"].tap()
        XCTAssertTrue(try handles("formation.measure.").isEmpty)
        XCTAssertEqual(try handles().count,3)
        app.buttons["freeplay.moreMenu"].tap(); ready(app.buttons["formation.snap"])
        XCTAssertFalse(app.buttons["freeplay.cameraMode"].exists)
        try snap("08-settings"); app.buttons["关闭菜单"].tap()
        save("连接线球形")
        app.buttons["formation.start"].tap(); ready(app.buttons["dailyClearance.strike"]); count(5)
        XCTAssertTrue(try handles().isEmpty)
        assertTitle("连接线球形")
        XCTAssertEqual(app.buttons["paletteBall__1"].value as? String,"3颗")
        XCTAssertEqual(app.buttons["paletteBall__2"].value as? String,"2颗")
        XCTAssertFalse(app.buttons["paletteBall__3"].exists)
        try snap("09-practice")
        app.buttons["dailyClearance.strike"].tap(); ready(app.buttons["dailyClearance.undo"])
    }
    func testLineSortThreeStatesAndRestore() throws {
        launch(); newTemplate(0)
        app.buttons["formation.tool.line"].tap()
        table.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.70)).tap()
        table.coordinate(withNormalizedOffset:CGVector(dx:0.75,dy:0.70)).tap()
        for (i,number) in [2,1,3].enumerated() { app.buttons["paletteBall__\(number)"].tap(); count(i+1) }
        func ordered() throws -> [String] {
            try balls().sorted { ($0["screen"] as! [Double])[0] < ($1["screen"] as! [Double])[0] }.map { $0["key"] as! String }
        }
        let original = try ordered()
        let originalNumbers = original.map { String($0.split(separator:"@")[0]) }
        let sort = app.buttons["formation.edit.sort"]
        assertLanes(["formation.parameter.count","formation.parameter.spacing","formation.parameter.length","formation.edit.sort","formation.edit.delete","formation.edit.save"])
        try snap("20-sort-original")
        for (i,expected) in [["_1","_2","_3"],["_3","_2","_1"],originalNumbers].enumerated() {
            sort.tap()
            XCTAssertEqual(try ordered().map { String($0.split(separator:"@")[0]) },expected)
            try assertEqualSpacing(balls())
            assertLanes(["formation.parameter.count","formation.parameter.spacing","formation.parameter.length","formation.edit.sort","formation.edit.deleteLine","formation.edit.save"])
            try snap("21-sort-\(i)")
        }
        XCTAssertEqual(try ordered(),original)
    }
    func testPracticeDragRetrieveReplayUndoAndRestart() throws {
        launch(); newTemplate(0)
        app.buttons["formation.tool.line"].tap()
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.70)).tap()
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.70)).tap()
        for i in 0..<3 { app.buttons["paletteBall__1"].tap(); count(i + 1) }
        save("自由练习回归")
        app.buttons["formation.start"].tap(); ready(app.buttons["dailyClearance.strike"])
        setView("2D"); count(3)
        func board() throws -> [String: [Double]] {
            let entries = try XCTUnwrap(probe()["balls"] as? [[String: Any]])
            return try Dictionary(uniqueKeysWithValues: entries.map {
                (try XCTUnwrap($0["key"] as? String), try XCTUnwrap($0["world"] as? [Double]))
            })
        }
        func assertBoard(_ expected: [String: [Double]], file: StaticString = #filePath, line: UInt = #line) throws {
            let actual = try board()
            XCTAssertEqual(Set(actual.keys), Set(expected.keys), file: file, line: line)
            for (key, position) in expected {
                let current = try XCTUnwrap(actual[key])
                for axis in 0..<3 { XCTAssertEqual(current[axis], position[axis], accuracy: 0.0001, file: file, line: line) }
            }
        }
        let initial = try board()
        XCTAssertFalse(app.buttons["dailyClearance.playback"].exists)
        XCTAssertFalse(app.buttons["formation.tools"].exists)
        XCTAssertFalse(app.buttons["formation.nudge.up"].exists)
        XCTAssertFalse(app.buttons["formation.tool.line"].exists)
        try snap("40-practice-simple")

        let target = try XCTUnwrap(balls().max { ($0["screen"] as! [Double])[0] < ($1["screen"] as! [Double])[0] })
        let key = try XCTUnwrap(target["key"] as? String)
        let origin = try coordinate(target)
        origin.press(forDuration: 0.15, thenDragTo: origin.withOffset(CGVector(dx: 0, dy: -110)))
        let moved = try XCTUnwrap(board()[key])
        XCTAssertGreaterThan(hypot(moved[0] - initial[key]![0], moved[2] - initial[key]![2]), 0.05)
        try snap("41-practice-dragged")

        let movedBall = try XCTUnwrap(balls().first { $0["key"] as? String == key })
        let palette = app.buttons["paletteBall__1"]
        try coordinate(movedBall).press(forDuration: 0.15, thenDragTo: palette.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        count(2)
        XCTAssertNil(try board()[key])
        palette.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).press(forDuration: 0.1,
            thenDragTo: table.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.35)))
        count(3)
        XCTAssertNotNil(try board()[key], "Retrieval must restore the same repeated-ball identity")
        XCTAssertEqual(Set(try board().keys), Set(initial.keys))
        try snap("42-practice-retrieved")

        ready(app.buttons["dailyClearance.strike"])
        let beforeShot = try board()
        app.buttons["dailyClearance.strike"].tap()
        ready(app.buttons["dailyClearance.undo"])
        let afterShot = try board()
        XCTAssertNotEqual(afterShot, beforeShot)
        app.buttons["freeplay.moreMenu"].tap()
        let scroll = app.scrollViews["dailyClearance.menuScroll"]
        for _ in 0..<5 {
            if app.buttons["formation.playback"].isHittable { break }
            scroll.swipeUp()
        }
        for id in ["formation.arrange", "formation.line", "formation.cue", "formation.clear", "formation.settings"] {
            XCTAssertFalse(app.buttons[id].exists, id)
        }
        ready(app.buttons["formation.playback"])
        XCTAssertTrue(app.buttons["formation.save"].exists)
        try snap("43-practice-settings")
        app.buttons["formation.playback"].tap()
        ready(app.buttons["dailyClearance.strike"])
        try assertBoard(afterShot)
        app.buttons["dailyClearance.undo"].tap()
        ready(app.buttons["dailyClearance.strike"])
        try assertBoard(beforeShot)
        XCTAssertFalse(app.buttons["dailyClearance.undo"].isEnabled)
        try snap("44-practice-undo")

        app.buttons["formation.restart"].tap()
        ready(app.buttons["formation.restart.cancel"])
        app.buttons["formation.restart.cancel"].tap()
        try assertBoard(beforeShot)
        app.buttons["formation.restart"].tap()
        ready(app.buttons["formation.restart.confirm"])
        try snap("45-practice-restart-confirm")
        app.buttons["formation.restart.confirm"].tap()
        ready(app.buttons["dailyClearance.strike"]); count(3)
        try assertBoard(initial)
        XCTAssertFalse(app.buttons["dailyClearance.undo"].isEnabled)
        try snap("46-practice-restarted")
        setView("3D")
        XCTAssertFalse(app.buttons["dailyClearance.playback"].exists)
        try assertBoard(initial)
        try snap("47-practice-3d")
        setView("2D")
        try assertBoard(initial)
    }
    func testLocalSyncStatusUsesExistingTemplateRow() throws {
        launch(); newTemplate(3); save("三颗同号球同步模板")
        XCUIDevice.shared.orientation = .portrait
        let status = app.staticTexts["已保存到本机"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["formation.start"].isHittable)
        try snap("30-sync-local-template")
    }
    func testTwentyFiveLimitGroupedPaletteAndNamedPractice() throws {
        launch(); newTemplate(25)
        app.buttons["paletteBall__2"].tap(); count(25)
        XCTAssertTrue(app.descendants(matching:.any)["formation.notice"].exists)
        try snap("10-editor-limit-25")
        assertLanes(["formation.edit.delete","formation.edit.save"])
        let identities = Set(try balls().compactMap { $0["key"] as? String }); XCTAssertEqual(identities.count,25)
        save("二十五颗同号球")
        app.terminate(); app.launch(); ready(app.buttons["formation.start"])
        app.buttons["formation.start"].tap(); ready(app.buttons["dailyClearance.strike"]); count(25)
        XCTAssertEqual(Set(try balls().compactMap { $0["key"] as? String }),identities)
        assertTitle("二十五颗同号球")
        XCTAssertEqual(app.buttons["paletteBall__1"].value as? String,"25颗")
        XCTAssertFalse(app.buttons["paletteBall__2"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@", "paletteBall__")).count,1)
        try snap("11-practice-grouped-25")
        app.buttons["dailyClearance.strike"].tap(); ready(app.buttons["dailyClearance.undo"])
    }
}
