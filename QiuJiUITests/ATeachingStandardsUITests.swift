import XCTest

/// W1-A native evidence. The audit case intentionally records the baseline
/// before a repair; acceptance assertions live in separate cases.
final class ATeachingStandardsUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }

    private func launch(_ args: [String] = []) {
        app?.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-v62.fixture", "-3dDrag.probe", "-appearanceMode", "system"] + args)
    }
    private func capture(_ name: String) {
        usleep(name.contains("temporary") || name.contains("3D-one-track") ? 1_000_000 : 350_000) // Allow camera and label transitions to settle.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func geometry(_ ids: [String], name: String) throws {
        var values: [String: [String: Any]] = [:]
        for id in ids {
            let e = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(e.exists, id)
            values[id] = ["frame": [e.frame.minX,e.frame.minY,e.frame.width,e.frame.height],
                          "label": e.label, "value": String(describing: e.value), "hittable": e.isHittable]
        }
        let data = try JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys])
        let a = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        a.name = name; a.lifetime = .keepAlways; add(a)
    }
    func testAuditAtlasTargetsAndTeachingNotice() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        for (page,prefix) in [("separation","separationAngleAtlas"),("cushion","cushionEnglishAtlas")] {
            launch(["-dailyInteraction.sharedPage=\(page)"])
            XCTAssertTrue(app.buttons[prefix + ".more"].waitForExistence(timeout: 25))
            let ids = (0..<8).map { prefix + ".spinLegend.\($0)" }
            try geometry(ids + [prefix + ".metrics",prefix + ".trackCount"], name: page + "-baseline-frames")
            capture(page + "-baseline-eight")
            for i in 0..<8 {
                let item = app.buttons[ids[i]]
                XCTAssertTrue(item.isHittable); item.tap(); XCTAssertEqual(item.value as? String, "未选")
                item.tap(); XCTAssertEqual(item.value as? String, "已选")
            }
        }
        launch(["-dailyInteraction.sharedPage=angleDynamic", "-angleDynamic.hasDraggedOnce", "NO"])
        XCTAssertTrue(app.buttons["angleDynamic.more"].waitForExistence(timeout: 25))
        XCTAssertTrue(app.staticTexts["母球和目标球都可以拖动，指标实时联动"].waitForExistence(timeout: 5))
        capture("ad01-baseline-first-drag-notice")
    }
    func testAuditMissingTargetNotices() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        for (page,prefix) in [("separation","separationAngleAtlas"),("cushion","cushionEnglishAtlas")] {
            launch(["-dailyInteraction.sharedPage=\(page)"])
            XCTAssertTrue(app.buttons[prefix + ".more"].waitForExistence(timeout: 25))
            app.buttons["paletteBall__8"].tap()
            XCTAssertTrue(app.staticTexts["请摆好母球与目标球"].waitForExistence(timeout: 10))
            capture(page + "-baseline-missing-target")
        }
    }

    private func openTraining(_ title: String) {
        XCUIDevice.shared.orientation = .portrait
        launch()
        app.switchTab(.angle)
        let practice = app.buttons["angleHomeTab_练"]
        XCTAssertTrue(practice.waitForExistence(timeout: 8)); practice.tap()
        let card = app.buttons[title]
        if card.waitForExistence(timeout: 5) { card.tap() }
        else { app.staticTexts[title].tap() }
    }

    func testAngleTrainingBothModes() throws {
        for mode in ["2D", "3D"] {
            openTraining(mode + "角度")
            let start = app.buttons["angleTraining.start"]
            XCTAssertTrue(start.waitForExistence(timeout: 10))
            capture(mode + "-settings-system")
            start.tap()
            let action = app.buttons["angleTraining.primaryAction"]
            XCTAssertTrue(action.waitForExistence(timeout: 10))
            let assist = app.buttons["angleTraining.assist"]
            XCTAssertEqual(assist.frame.width, assist.frame.height, accuracy: 1)
            XCTAssertGreaterThanOrEqual(assist.frame.width, 44)
            capture(mode + "-actions-neutral")
            assist.tap(); capture(mode + "-assist-enabled")
            action.tap()
            let submit = app.buttons["提交"]
            XCTAssertTrue(submit.waitForExistence(timeout: 5))
            XCTAssertFalse(submit.isEnabled)
            capture(mode + "-keypad-empty-system")
            app.buttons["4"].tap(); app.buttons["5"].tap()
            XCTAssertTrue(submit.isEnabled)
            capture(mode + "-keypad-value-system")
            app.buttons["取消"].tap()
            XCTAssertTrue(action.waitForExistence(timeout: 5)); action.tap()
            app.buttons["4"].tap(); app.buttons["5"].tap(); app.buttons["提交"].tap()
            XCTAssertTrue(app.buttons["下一题"].waitForExistence(timeout: 8))
            capture(mode + "-next-neutral")
            app.buttons["下一题"].tap()
            XCTAssertTrue(app.buttons["答题"].waitForExistence(timeout: 8))
            app.buttons["angleTraining.settings"].tap()
            let display = app.staticTexts["显示"].firstMatch
            let settings = app.buttons["angleTraining.trainingSettings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 5))
            XCTAssertLessThan(display.frame.minY, settings.frame.minY)
            capture(mode + "-display-first-menu")
            settings.tap()
            XCTAssertTrue(app.buttons["angleTraining.settingsClose"].waitForExistence(timeout: 5))
            capture(mode + "-settings-sheet-system")
        }
    }

    func testAimPointBothModes() throws {
        for mode in ["2D", "3D"] {
            openTraining(mode + "瞄准点")
            let submit = app.buttons["aimPointTraining.submit"]
            XCTAssertTrue(submit.waitForExistence(timeout: 15))
            let ruler = app.descendants(matching: .any).matching(identifier: "aimPointTraining.aimWheel").firstMatch
            try geometry(["aimPointTraining.aimWheel", "aimPointTraining.questionInfo", "aimPointTraining.submit"], name: mode + "-ruler-frames")
            capture(mode + "-ruler-and-submit")
            if mode == "3D" {
                let top = app.buttons["shotCamera.temporaryTopDown"]
                top.tap(); capture(mode + "-temporary-top")
                top.tap(); capture(mode + "-temporary-return")
            }
            ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
                .press(forDuration: 0.1, thenDragTo: ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)))
            submit.tap()
            let info = app.descendants(matching: .any).matching(identifier: "aimPointTraining.verificationInfo").firstMatch
            XCTAssertTrue(info.waitForExistence(timeout: 2))
            XCTAssertLessThan(info.frame.midY, app.windows.firstMatch.frame.midY)
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "aimPointTraining.questionInfo").firstMatch.label.contains("误差"))
            capture(mode + "-verification-top-error-retained")
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: submit)], timeout: 5), .completed)
            XCTAssertTrue(submit.waitForExistence(timeout: 45))
            capture(mode + "-next-question")
        }
    }

    func testAtlasSingleColumnAndNotices() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        for (page,prefix) in [("separation","separationAngleAtlas"),("cushion","cushionEnglishAtlas")] {
            launch(["-dailyInteraction.sharedPage=\(page)"])
            XCTAssertTrue(app.buttons[prefix + ".more"].waitForExistence(timeout: 25))
            let ids = (0..<8).map { prefix + ".spinLegend.\($0)" }
            try geometry(ids + [prefix + ".trackCount"], name: page + "-final-eight-frames")
            capture(page + "-final-eight")
            for i in 0..<8 {
                let item = app.buttons[ids[i]]
                XCTAssertTrue(item.isHittable); XCTAssertFalse(item.label.isEmpty)
                XCTAssertTrue(app.windows.firstMatch.frame.contains(item.frame))
                if i > 0 { XCTAssertLessThanOrEqual(app.buttons[ids[i-1]].frame.maxY, item.frame.minY) }
                item.tap(); XCTAssertEqual(item.value as? String, "未选")
                item.tap(); XCTAssertEqual(item.value as? String, "已选")
            }
            for i in 0..<7 { app.buttons[ids[i]].tap() }
            app.buttons[ids[7]].tap()
            XCTAssertEqual(app.buttons[ids[7]].value as? String, "已选")
            XCTAssertEqual(app.staticTexts[prefix + ".trackCount"].label, "1/8")
            capture(page + "-one-track-retained")
            app.buttons[prefix + ".more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            app.buttons[prefix + ".cameraMode"].tap()
            app.buttons[prefix + ".dismissMenu"].tap()
            let top = app.buttons["shotCamera.temporaryTopDown"]
            XCTAssertTrue(top.waitForExistence(timeout: 8))
            capture(page + "-3D-one-track")
            top.tap()
            let scene = app.descendants(matching: .any).matching(identifier: "table.scene").firstMatch
            func snapshot() throws -> [String: Any] {
                try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try XCTUnwrap(scene.value as? String).utf8)) as? [String: Any])
            }
            var previous = try snapshot()
            var stable = false
            for _ in 0..<8 {
                usleep(250_000)
                let current = try snapshot()
                if current["diagramSurface"] as? String == "temporaryTopDown",
                   (current["camera"] as? [Double]) == (previous["camera"] as? [Double]),
                   (current["displayedTable"] as? [Double]) == (previous["displayedTable"] as? [Double]) {
                    stable = true; break
                }
                previous = current
            }
            XCTAssertTrue(stable, "Temporary overlay and camera/table projection must settle")
            XCTAssertEqual(try snapshot()["standardTemporaryTable"] as? Bool, false, "Non-planning atlas retains its existing legacy temporary projection")
            try geometry(["table.scene"], name: page + "-temporary-stable-probe")
            capture(page + "-temporary-one-track")
            top.tap()
            XCTAssertEqual(app.buttons[ids[7]].value as? String, "已选")
            app.buttons[prefix + ".more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            app.buttons[prefix + ".cameraMode"].tap()
            app.buttons[prefix + ".dismissMenu"].tap()
            app.buttons["paletteBall__8"].tap()
            let notice = app.descendants(matching: .any).matching(identifier: prefix + ".status").firstMatch
            XCTAssertTrue(notice.waitForExistence(timeout: 10))
            XCTAssertLessThan(notice.frame.midY, app.windows.firstMatch.frame.midY)
            capture(page + "-missing-target-top")
        }
    }

    func testAngleDynamicNoticeAtTop() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launch(["-dailyInteraction.sharedPage=angleDynamic", "-angleDynamic.hasDraggedOnce", "NO"])
        XCTAssertTrue(app.buttons["angleDynamic.more"].waitForExistence(timeout: 25))
        let notice = app.descendants(matching: .any).matching(identifier: "angleDynamic.status").firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertLessThan(notice.frame.midY, app.windows.firstMatch.frame.midY)
        capture("ad01-first-drag-notice-top")
        let table = app.descendants(matching: .any).matching(identifier: "table.scene").firstMatch
        let metrics = app.descendants(matching: .any).matching(identifier: "angleDynamic.metrics").firstMatch
        let before = metrics.label
        let probe = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(table.value as? String).utf8)) as? [String: Any])
        let balls = try XCTUnwrap(probe["balls"] as? [[String: Any]])
        let ball = try XCTUnwrap(balls.first { $0["key"] as? String == "_8" })
        let point = try XCTUnwrap(ball["screen"] as? [Double])
        let origin = table.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: point[0], dy: point[1])).press(forDuration: 0.2,
            thenDragTo: origin.withOffset(CGVector(dx: point[0] + 110, dy: point[1] + 40)),
            withVelocity: XCUIGestureVelocity(rawValue: 150), thenHoldForDuration: 0.2)
        XCTAssertNotEqual(metrics.label, before)
        // NSArgumentDomain's NO override is intentionally fixed during this
        // launch. Drop it on relaunch to verify the drag persisted completion.
        launch(["-dailyInteraction.sharedPage=angleDynamic"])
        XCTAssertTrue(app.buttons["angleDynamic.more"].waitForExistence(timeout: 25))
        let restoredNotice = app.descendants(matching: .any).matching(identifier: "angleDynamic.status").firstMatch
        XCTAssertFalse(restoredNotice.exists && restoredNotice.label.contains("母球和目标球都可以拖动"))
        capture("ad01-after-drag-relaunch-guidance-cleared")
    }

    func testAimPointFreeReadoutCapacity() throws {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-w7.forceDailyLimitNear", "-v50.inMemoryStore", "-v62.fixture", "-appearanceMode", "system"])
        app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
        let card = app.buttons["2D瞄准点"]
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        XCTAssertTrue(app.buttons["aimPointTraining.submit"].waitForExistence(timeout: 15))
        let remaining = app.staticTexts["aimPointTraining.remaining"]
        XCTAssertTrue(remaining.exists)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(remaining.frame))
        let question = app.descendants(matching: .any).matching(identifier: "aimPointTraining.questionInfo").firstMatch
        let track = app.descendants(matching: .any).matching(identifier: "aimPointTraining.aimWheel").firstMatch
        XCTAssertTrue(track.exists)
        XCTAssertEqual(track.frame.width, 44, accuracy: 1)
        XCTAssertLessThanOrEqual(question.frame.maxY, track.frame.minY)
        XCTAssertLessThanOrEqual(track.frame.maxY, remaining.frame.minY)
        try geometry(["aimPointTraining.questionInfo", "aimPointTraining.remaining", "aimPointTraining.aimWheel"], name: "2D-free-capacity-44-hit")
        capture("2D-free-remaining-and-ruler")
    }

}
