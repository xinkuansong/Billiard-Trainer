import XCTest

final class PocketLeatherFlowUITests: XCTestCase {
    private var evidence: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["POCKET_UI_EVIDENCE"] ?? URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("output/pocket-leather/W4/standard").path)
    }
    private let args=["-v50.inMemoryStore","-v53.authenticatedProfileFixture","-forcePremium"]
    override func setUpWithError() throws { continueAfterFailure=false }
    private func table(_ app: XCUIApplication) -> XCUIElement { app.descendants(matching:.any)["table.scene"].firstMatch }
    private func launch(_ extra: [String]=[]) -> XCUIApplication { XCUIApplication.launchClean(extraArgs:args+extra) }
    private func open(_ title: String, in app: XCUIApplication) {
        app.switchTab(.angle)
        let search=app.textFields["librarySearchField"]
        XCTAssertTrue(search.waitForExistence(timeout:15));search.tap();search.typeText(title)
        let card=app.buttons[title];XCTAssertTrue(card.waitForExistence(timeout:10));card.tap()
    }
    private func snap(_ app: XCUIApplication,_ name: String, requiresTable: Bool = true) throws {
        try FileManager.default.createDirectory(at:evidence,withIntermediateDirectories:true)
        XCTAssertEqual(app.state,.runningForeground)
        if requiresTable { XCTAssertTrue(table(app).exists) }
        let image=XCUIScreen.main.screenshot()
        try image.pngRepresentation.write(to:evidence.appendingPathComponent(name+".png"))
        try app.debugDescription.write(to:evidence.appendingPathComponent(name+".txt"),atomically:true,encoding:.utf8)
        let attachment=XCTAttachment(screenshot:image);attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
    private func assertTable(_ app: XCUIApplication) {
        XCTAssertTrue(table(app).waitForExistence(timeout:20),app.debugDescription)
        XCTAssertGreaterThan(table(app).frame.height,100)
    }

    func testAllSingleTargetAndNeutralRoutes() throws {
        let titles=["自由击球","自由走位","分离角与走位","思路训练","2D 角度训练","3D 角度训练","2D 瞄准点训练","3D 瞄准点训练","角度与瞄准","分离角图谱","加塞吃库图谱","翻袋解球器","反射解球器","防守"]
        for (index,title) in titles.enumerated() {
            let app=launch();open(title,in:app)
            if title.contains("角度训练") {
                let start=app.buttons["开始训练"]
                XCTAssertTrue(start.waitForExistence(timeout:15));start.tap()
            }
            assertTable(app)
            Thread.sleep(forTimeInterval:1)
            if title == "反射解球器" || title == "防守" {
                XCTAssertEqual(table(app).value as? String,"未选择目标袋")
            }
            try snap(app,String(format:"route-%02d",index)+"-"+title)
            app.terminate()
        }
    }

    func testDailyAndPlanRoles() throws {
        var app=launch(["-deeplink.dailyClearance","-dailyClearance.resetState","-dailyClearance.fixture=progress","-dailyClearance.fixtureSettled"])
        XCTAssertTrue(app.descendants(matching:.any)["dailyClearance.hud"].waitForExistence(timeout:20));assertTable(app)
        try snap(app,"daily-selected")
        app.terminate()
        app=launch(["-planThree.twoBall"])
        XCTAssertTrue(app.buttons["清空计划"].waitForExistence(timeout:20));assertTable(app)
        XCTAssertTrue((table(app).value as? String ?? "").contains("①目标"))
        XCTAssertTrue((table(app).value as? String ?? "").contains("②目标"))
        try snap(app,"plan-different")
        let second=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","②袋")).firstMatch
        XCTAssertTrue(second.exists,app.debugDescription);second.tap()
        // Project the CAD corner through the documented rotated orthographic
        // framing, accounting for the actual viewport on phones and tablets.
        let scene=table(app)
        let aspect = scene.frame.width / scene.frame.height
        let scale = max(1.50, 0.7995 * 1.012 / aspect)
        scene.coordinate(withNormalizedOffset:CGVector(dx:0.5 - 0.665 / (2 * scale * aspect),dy:0.5 - 1.30 / (2 * scale))).tap()
        XCTAssertTrue((scene.value as? String ?? "").contains("①②共同目标"),app.debugDescription)
        try snap(app,"plan-same")
        app.buttons["清空计划"].tap()
        XCTAssertEqual(scene.value as? String,"未选择目标袋")
        try snap(app,"plan-cleared")
    }

    func testExternalFormationDestinations() throws {
        for (index,title) in ["自由走位","思路训练","打一走二想三"].enumerated() {
            let app=launch(["-extract.confirmDemo"]);open("拍照建球形",in:app)
            let send=app.buttons["送入…"];XCTAssertTrue(send.waitForExistence(timeout:20));send.tap()
            let action=app.buttons[title];XCTAssertTrue(action.waitForExistence(timeout:5));action.tap()
            assertTable(app);try snap(app,"external-\(index)");app.terminate()
        }
    }

    func testTryoutAndSequenceModes() throws {
        let app=launch(["-deeplink.tryout=drill_c042"])
        let sequence=app.buttons["tryoutMode_序列"]
        XCTAssertTrue(sequence.waitForExistence(timeout:20));assertTable(app)
        try snap(app,"tryout-sequence")
        let free=app.buttons["tryoutMode_自由"];XCTAssertTrue(free.exists);free.tap()
        XCTAssertEqual(table(app).value as? String,"未选择目标袋")
        try snap(app,"tryout-free")
        let pocket=app.buttons["tryoutMode_进袋"];XCTAssertTrue(pocket.exists);pocket.tap()
        XCTAssertNotEqual(table(app).value as? String,"未选择目标袋")
        try snap(app,"tryout-pocket")
        sequence.tap();try snap(app,"tryout-sequence-restored")
    }

    func testDrillDetailAndTryoutEntry() throws {
        let app=launch(["-deeplink.drillDetail=drill_c001","-v54.forceLight"])
        let entry=app.buttons["bottomTryoutButton"]
        XCTAssertTrue(entry.waitForExistence(timeout:20))
        XCTAssertTrue(app.buttons["drillPlayButton"].exists)
        try snap(app,"drill-detail-neutral",requiresTable:false)
        entry.tap()
        assertTable(app)
        try snap(app,"drill-detail-tryout")
    }

    func testBatchAuthoringWithoutSaving() throws {
        let app=launch();open("批量出片台",in:app)
        let row=app.buttons.matching(NSPredicate(format:"label CONTAINS %@","drill_c065")).firstMatch
        for _ in 0..<18 { if row.exists && row.isHittable { break };app.swipeUp() }
        XCTAssertTrue(row.exists && row.isHittable);row.tap()
        let plus=app.staticTexts["+ 新增球形"];XCTAssertTrue(plus.waitForExistence(timeout:8));plus.tap()
        let empty=app.buttons["空台面（仅母球）"];XCTAssertTrue(empty.waitForExistence(timeout:5));empty.tap()
        assertTable(app);XCTAssertEqual(table(app).value as? String,"未选择目标袋")
        try snap(app,"batch-empty")
        // Do not press any save/export control: production content is outside this test.
    }
}
