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
        let titles=["自由击球","自由走位","分离角与走位","思路训练","2D 角度训练","3D 角度训练","2D 瞄准点训练","3D 瞄准点训练","角度与瞄准","分离角图谱","加塞吃库图谱","翻袋解球","颗星解球","防守"]
        for (index,title) in titles.enumerated() {
            let app=launch();open(title,in:app)
            if title.contains("角度训练") {
                let start=app.buttons["开始训练"]
                XCTAssertTrue(start.waitForExistence(timeout:15));start.tap()
            }
            assertTable(app)
            Thread.sleep(forTimeInterval:1)
            if title == "颗星解球" || title == "防守" {
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


final class Shared3DBallDragUITests: XCTestCase {
    private struct Probe: Decodable {
        struct Ball: Decodable { let key: String; let screen: [Double]; let world: [Double]; let draggable: Bool }
        let balls: [Ball]
        let camera: [Double]
    }
    private func probe(_ table: XCUIElement) throws -> Probe {
        try JSONDecoder().decode(Probe.self, from: Data(try XCTUnwrap(table.value as? String).utf8))
    }
    private func capture(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/3d-drag-20260915/" + (ProcessInfo.processInfo.environment["DRAG_PHASE"] ?? "after"))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
        try XCUIApplication().debugDescription.write(to: directory.appendingPathComponent(name + ".txt"), atomically: true, encoding: .utf8)
        let table = XCUIApplication().descendants(matching: .any)["table.scene"].firstMatch
        if let value = table.value as? String {
            try value.write(to: directory.appendingPathComponent(name + ".json"), atomically: true, encoding: .utf8)
        }
        let attachment = XCTAttachment(screenshot: shot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func runRoute(_ title: String, prefix: String, extra: [String] = [], selectFreeMode: Bool = false, verifyTargetAndCamera: Bool = false) throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-forcePremium", "-3dDrag.probe"] + extra)
        if extra.isEmpty {
            app.switchTab(.angle)
            let search = app.textFields["librarySearchField"]
            XCTAssertTrue(search.waitForExistence(timeout: 15)); search.tap(); search.typeText(title)
            let card = app.buttons[title]; XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
        }
        let capturePrefix = title == "每日清台" ? "daily" : prefix
        let table = app.descendants(matching: .any)["table.scene"].firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 20))
        if selectFreeMode { app.buttons["tryoutMode_自由"].tap() }
        let mode = app.buttons[prefix + ".cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 10))
        if mode.value as? String != "3D" { mode.tap() }
        XCTAssertEqual(mode.value as? String, "3D")
        Thread.sleep(forTimeInterval: 2)
        let before = try probe(table)
        let ball = try XCTUnwrap(before.balls.first { $0.key == "cueBall" && $0.screen[2] >= 0 && $0.screen[2] <= 1 }
            ?? before.balls.first { $0.draggable })
        try capture(capturePrefix + "-before-drag")
        let origin = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: table.frame.minX, dy: table.frame.minY))
        let start = origin.withOffset(CGVector(dx: ball.screen[0], dy: ball.screen[1]))
        let direction = ball.screen[0] > table.frame.width / 2 ? -1.0 : 1.0
        start.press(forDuration: 0.15, thenDragTo: origin.withOffset(CGVector(dx: ball.screen[0] + 110 * direction, dy: ball.screen[1])))
        Thread.sleep(forTimeInterval: 1)
        let after = try probe(table)
        try capture(capturePrefix + "-after-drag")
        let moved = try XCTUnwrap(after.balls.first { $0.key == ball.key })
        XCTAssertGreaterThan(hypot(moved.world[0] - ball.world[0], moved.world[2] - ball.world[2]), 0.005)
        XCTAssertEqual(moved.world[1], ball.world[1], accuracy: 0.0001)
        for (a,b) in zip(before.camera, after.camera) { XCTAssertEqual(a,b,accuracy: 0.0001, "Dragging a ball must not move the camera") }
        mode.tap(); XCTAssertEqual(mode.value as? String, "2D")
        Thread.sleep(forTimeInterval: 1)
        let returned = try XCTUnwrap(try probe(table).balls.first { $0.key == ball.key })
        for (a,b) in zip(moved.world, returned.world) { XCTAssertEqual(a,b,accuracy: 0.0001) }
        try capture(capturePrefix + "-2d-retained")
        if verifyTargetAndCamera {
            let topDown = try probe(table)
            let cue = try XCTUnwrap(topDown.balls.first { $0.key == ball.key })
            let topOrigin = table.coordinate(withNormalizedOffset: .zero)
            topOrigin.withOffset(CGVector(dx: cue.screen[0], dy: cue.screen[1]))
                .press(forDuration: 0.15, thenDragTo: topOrigin.withOffset(CGVector(dx: cue.screen[0] - 110, dy: cue.screen[1])))
            Thread.sleep(forTimeInterval: 1)
            let topMoved = try XCTUnwrap(try probe(table).balls.first { $0.key == cue.key })
            XCTAssertGreaterThan(hypot(topMoved.world[0] - cue.world[0], topMoved.world[2] - cue.world[2]), 0.005)
            try capture(capturePrefix + "-2d-drag")
            mode.tap()
            Thread.sleep(forTimeInterval: 2)
            let targetBefore = try probe(table)
            let target = try XCTUnwrap(targetBefore.balls.first { $0.key != "cueBall" && $0.draggable })
            let targetOrigin = table.coordinate(withNormalizedOffset: .zero)
            targetOrigin.withOffset(CGVector(dx: target.screen[0], dy: target.screen[1]))
                .press(forDuration: 0.15, thenDragTo: targetOrigin.withOffset(CGVector(dx: target.screen[0] - 110, dy: target.screen[1])))
            Thread.sleep(forTimeInterval: 1)
            var targetAfter = try probe(table)
            let movedTarget = try XCTUnwrap(targetAfter.balls.first { $0.key == target.key })
            XCTAssertGreaterThan(hypot(movedTarget.world[0] - target.world[0], movedTarget.world[2] - target.world[2]), 0.005)
            for (a,b) in zip(targetBefore.camera, targetAfter.camera) { XCTAssertEqual(a,b,accuracy: 0.0001) }
            try capture(capturePrefix + "-target-drag")
            // Re-grab outside the visible ball, inside the shared 48pt allowance.
            targetOrigin.withOffset(CGVector(dx: movedTarget.screen[0], dy: movedTarget.screen[1] + 30))
                .press(forDuration: 0.15, thenDragTo: targetOrigin.withOffset(CGVector(dx: movedTarget.screen[0] + 110, dy: movedTarget.screen[1] + 30)))
            Thread.sleep(forTimeInterval: 1)
            let nearbyAfter = try probe(table)
            let nearbyTarget = try XCTUnwrap(nearbyAfter.balls.first { $0.key == target.key })
            XCTAssertGreaterThan(hypot(nearbyTarget.world[0] - movedTarget.world[0], nearbyTarget.world[2] - movedTarget.world[2]), 0.005)
            for (a,b) in zip(targetAfter.camera, nearbyAfter.camera) { XCTAssertEqual(a,b,accuracy: 0.0001) }
            targetAfter = nearbyAfter
            try capture(capturePrefix + "-target-nearby-drag")
            table.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.15))
                .press(forDuration: 0.15, thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.15)))
            Thread.sleep(forTimeInterval: 1)
            let rotated = try probe(table)
            XCTAssertTrue(zip(targetAfter.camera, rotated.camera).contains { abs($0 - $1) > 0.001 })
            for ball in targetAfter.balls {
                let afterRotation = try XCTUnwrap(rotated.balls.first { $0.key == ball.key })
                for (a,b) in zip(ball.world, afterRotation.world) { XCTAssertEqual(a,b,accuracy: 0.0001) }
            }
            try capture(capturePrefix + "-camera-orbit")
        }
        app.terminate()
    }
    func testAngle() throws { try runRoute("角度与瞄准", prefix: "angleDynamic") }
    func testTargetDragAndEmptySpaceCamera() throws { try runRoute("角度与瞄准", prefix: "angleDynamic", verifyTargetAndCamera: true) }
    func testTryoutFree() throws { try runRoute("试打", prefix: "tryout", extra: ["-deeplink.tryout=drill_c042"], selectFreeMode: true) }
    func testDaily() throws { try runRoute("每日清台", prefix: "freeplay", extra: ["-deeplink.dailyClearance", "-dailyClearance.resetState", "-dailyClearance.fixture=progress", "-dailyClearance.fixtureSettled"]) }
    func testTryoutSequenceStaysReadOnly() throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-forcePremium", "-3dDrag.probe", "-deeplink.tryout=drill_c042"])
        let table = app.descendants(matching: .any)["table.scene"].firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 20))
        let mode = app.buttons["tryout.cameraMode"]; XCTAssertTrue(mode.waitForExistence(timeout: 10))
        if mode.value as? String != "3D" { mode.tap() }
        Thread.sleep(forTimeInterval: 2)
        let before = try probe(table)
        XCTAssertFalse(before.balls.isEmpty)
        XCTAssertTrue(before.balls.allSatisfy { !$0.draggable })
        let ball = try XCTUnwrap(before.balls.first { $0.key == "cueBall" })
        let origin = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: table.frame.minX, dy: table.frame.minY))
        origin.withOffset(CGVector(dx: ball.screen[0], dy: ball.screen[1]))
            .press(forDuration: 0.15, thenDragTo: origin.withOffset(CGVector(dx: ball.screen[0] + 110, dy: ball.screen[1])))
        let after = try probe(table)
        for ball in before.balls {
            let retained = try XCTUnwrap(after.balls.first { $0.key == ball.key })
            for (a,b) in zip(ball.world, retained.world) { XCTAssertEqual(a,b,accuracy: 0.0001) }
        }
        try capture("tryout-sequence-readonly")
        app.terminate()
    }
    func testSeparation() throws { try runRoute("分离角图谱", prefix: "separationAngleAtlas") }
    func testCushion() throws { try runRoute("加塞吃库图谱", prefix: "cushionEnglishAtlas") }
    func testFreePlay() throws { try runRoute("自由击球", prefix: "freeplay") }
    func testComposer() throws { try runRoute("自由走位", prefix: "composer") }
    func testShotSimulation() throws { try runRoute("分离角与走位", prefix: "shotSimulation") }
    func testSilu() throws { try runRoute("思路训练", prefix: "silu") }
    func testPlanThree() throws { try runRoute("打一走二想三", prefix: "planthree", extra: ["-planThree.twoBall"]) }
    func testDefense() throws { try runRoute("防守", prefix: "snooker") }
    func testBank() throws { try runRoute("翻袋解球", prefix: "bankshot") }
    func testDiamond() throws { try runRoute("颗星解球", prefix: "reflection") }
}
