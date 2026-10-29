import XCTest

final class SixTrainingUnifiedUITests: XCTestCase {
    private var trainingTitle = ""

    func testPracticeReviewCorePagesAndAimRetry() {
        continueAfterFailure = false
        for title in ["2D角度", "2D瞄准点", "2D准度", "3D角度", "3D瞄准点", "3D准度"] {
            let app = open(title)
            let projection = String(title.prefix(2))
            let prefix = title.contains("准度") ? "accuracy" : title.contains("瞄准点") ? "aimPointTraining" : "angleTraining"
            capture("\(projection)-review-\(prefix)-settings")
            app.buttons[prefix + ".start"].tap(); app.selectTrainingView(trainingTitle)
            let action = app.buttons[prefix == "accuracy" ? "accuracy.strike" : prefix == "angleTraining" ? "angleTraining.primaryAction" : "aimPointTraining.submit"]
            ready(action)
            capture("\(projection)-review-\(prefix)-input")
            if prefix == "aimPointTraining" {
                let before = action.frame
                action.tap(); ready(app.buttons["aimPointTraining.next"])
                XCTAssertEqual(before.midY, app.buttons["aimPointTraining.next"].frame.midY, accuracy: 1)
                capture("\(projection)-review-aim-result")
                app.buttons["aimPointTraining.errorInfo"].tap()
                XCTAssertTrue(app.alerts["瞄准误差"].waitForExistence(timeout: 5))
                capture("\(projection)-review-aim-rating-info")
                app.alerts.buttons["知道了"].tap()
                let question = app.descendants(matching: .any)["aimPointTraining.questionInfo"].label
                ready(app.buttons["aimPointTraining.retry"]); app.buttons["aimPointTraining.retry"].tap()
                ready(action); XCUIDevice.shared.press(.home); app.activate(); ready(action); capture("\(projection)-review-aim-retry")
                action.tap(); ready(app.buttons["aimPointTraining.next"])
                XCTAssertEqual(app.descendants(matching: .any)["aimPointTraining.questionInfo"].label, question)
                capture("\(projection)-review-aim-repeat-result")
            }
            if prefix == "accuracy" {
                action.tap(); ready(app.buttons["accuracy.retry"], timeout: 90)
                ready(app.buttons["accuracy.playback"]); app.buttons["accuracy.playback"].tap()
                XCTAssertEqual(action.label, "停止")
                capture("\(projection)-review-accuracy-stop-replay")
                action.tap()
            }
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }

    func testPracticeReviewComposerAndRemovedEntries() {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-freeLayout.ephemeral", "-3dDrag.probe", "-dailyLayout.probe"])
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        app.switchTab(.angle); app.buttons["angleHomeTab_打"].tap()
        let card = app.buttons["分离角与走位"]
        for _ in 0..<5 where !card.isHittable { app.swipeUp() }
        XCTAssertEqual(app.buttons.matching(identifier: "分离角与走位").count, 1)
        XCTAssertFalse(app.buttons["自由击球"].exists)
        capture("review-practice-play-cards")
        ready(card); card.tap(); ready(app.buttons["freeplay.moreMenu"])
        let heading = app.descendants(matching: .any).matching(identifier: "composer.title").firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        let firstBall = app.buttons["paletteBall__1"]
        XCTAssertFalse(heading.frame.intersects(firstBall.frame), "Title must not cover the ball palette")
        XCTAssertTrue(app.frame.contains(heading.frame))
        XCTAssertTrue(app.frame.contains(firstBall.frame))
        // Compact phones and portrait windows retain the shared separate-row layout.
        if app.frame.width >= 800 && app.frame.height < 600 {
            XCTAssertEqual(heading.frame.midY, firstBall.frame.midY, accuracy: 12,
                "A long title must not move the regular landscape palette into another row")
        }
        capture("review-composer-default")
        // Verify navigation before opening a modal, then verify it again after
        // dismissing the menu. This separates a missed backdrop tap from a pop.
        let initialBack = app.buttons["dailyClearance.back"]
        ready(initialBack)
        initialBack.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        capture("review-composer-first-back")
        ready(card)
        XCTAssertFalse(app.buttons["freeplay.moreMenu"].exists)
        card.tap(); ready(app.buttons["freeplay.moreMenu"])
        app.buttons["freeplay.moreMenu"].tap()
        let clear = app.buttons["composer.clear"]
        for _ in 0..<5 where !clear.isHittable {
            let menu = app.descendants(matching: .any).matching(identifier: "dailyClearance.menuPanel").firstMatch
            ready(menu)
            menu.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.8)).press(forDuration: 0.05,
                thenDragTo: menu.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.3)))
        }
        ready(clear)
        XCTAssertFalse(app.buttons["composer.rename"].exists)
        XCTAssertFalse(app.buttons["composer.reset"].exists)
        XCTAssertFalse(app.buttons["freeplay.separation"].exists)
        XCTAssertTrue(app.buttons["composer.clear"].exists)
        capture("review-composer-menu")
        let backdrop = app.buttons["关闭菜单"]
        backdrop.coordinate(withNormalizedOffset: .init(dx: 0.03, dy: 0.7)).tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "dailyClearance.menuPanel").firstMatch.waitForNonExistence(timeout: 5))
        capture("review-composer-menu-closed")
        let back = app.buttons["dailyClearance.back"]
        ready(back)
        back.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        capture("review-composer-after-back")
        ready(app.buttons["分离角与走位"])
        XCTAssertFalse(app.buttons["freeplay.moreMenu"].exists)
    }

    func testAccuracySpinMutualExclusionAndShotControls() {
        continueAfterFailure = false
        XCUIDevice.shared.press(.home)
        for title in ["2D准度", "3D准度"] {
            let app = open(title)
            defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
            func top() { for _ in 0..<3 { app.collectionViews.firstMatch.swipeDown() } }
            func bottom() { for _ in 0..<3 { app.collectionViews.firstMatch.swipeUp() } }
            func set(_ id: String, _ on: Bool) {
                let toggle = app.switches[id].firstMatch
                ready(toggle)
                if (toggle.value as? String == "1") != on {
                    toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap()
                }
                XCTAssertEqual(toggle.value as? String, on ? "1" : "0")
            }
            func startRound() {
                app.buttons["accuracy.start"].tap(); app.selectTrainingView(trainingTitle)
                ready(app.buttons["accuracy.strike"])
                XCTAssertFalse(app.alerts["练习提示"].exists,
                    "自动调整所选条件的出题比例不应打断练习")
            }
            func check(_ id: String, _ on: Bool) {
                XCTAssertEqual(app.switches[id].firstMatch.value as? String, on ? "1" : "0")
            }
            top(); set("accuracy.manualVerticalSpin", true); set("accuracy.manualSideSpin", true)
            capture(title + "-manual-settings-on")
            bottom(); check("training.verticalSpin", false); check("training.sideSpin", false)
            XCTAssertEqual(app.switches["training.verticalSpin"].firstMatch.label, "系统指定高低杆")
            XCTAssertEqual(app.switches["training.sideSpin"].firstMatch.label, "系统指定左右塞")
            set("training.verticalSpin", true)
            top(); check("accuracy.manualVerticalSpin", false); check("accuracy.manualSideSpin", true)
            bottom(); set("training.sideSpin", true)
            top(); check("accuracy.manualVerticalSpin", false); check("accuracy.manualSideSpin", false)
            set("accuracy.manualVerticalSpin", true)
            bottom(); check("training.verticalSpin", false); check("training.sideSpin", true)
            top(); set("accuracy.manualSideSpin", true)
            bottom(); check("training.sideSpin", false)
            capture(title + "-generation-settings-off")
            top(); set("accuracy.manualVerticalSpin", false)
            bottom(); check("training.verticalSpin", false)
            top(); set("accuracy.manualVerticalSpin", true)
            startRound()
            ready(app.buttons["accuracy.strike"])
            XCUIDevice.shared.orientation = .landscapeLeft
            let entry = app.buttons["shotStage.spinEntry"]
            ready(entry); entry.tap()
            let up = app.buttons["高杆增加 1%"], left = app.buttons["左塞增加 1%"]
            ready(up); ready(left)
            let disc = app.descendants(matching: .any).matching(identifier: "spinPad.disc").firstMatch
            func closePad() {
                // Dismissal covers the whole stage: its center overlaps the editable disc.
                // Tap actual backdrop space, then verify dismissal before striking.
                app.buttons["关闭打点"].coordinate(withNormalizedOffset: .init(dx: 0.05, dy: 0.5)).tap()
                XCTAssertTrue(disc.waitForNonExistence(timeout: 3))
            }
            let original = disc.value as? String
            up.tap(); left.tap()
            XCTAssertNotEqual(disc.value as? String, original)
            capture(title + "-manual-spin-adjusted")
            app.buttons["回中"].tap()
            let centered = disc.value as? String
            up.tap(); XCTAssertNotEqual(disc.value as? String, centered)
            let played = disc.value as? String
            closePad()
            app.buttons["accuracy.strike"].tap()
            ready(app.buttons["accuracy.retry"], timeout: 60)
            app.buttons["accuracy.retry"].tap(); ready(entry); entry.tap()
            XCTAssertEqual(disc.value as? String, played)
            closePad()
            app.buttons["accuracy.more"].tap(); ready(app.buttons["accuracy.trainingSettings"])
            app.buttons["accuracy.trainingSettings"].tap()
            top(); check("accuracy.manualVerticalSpin", true); check("accuracy.manualSideSpin", true)
            bottom(); set("training.sideSpin", true)
            top(); check("accuracy.manualVerticalSpin", true); check("accuracy.manualSideSpin", false)
            capture(title + "-mixed-spin-settings")
            startRound()
            ready(entry); entry.tap(); ready(up)
            XCTAssertFalse(left.isEnabled)
            let mixed = disc.value as? String
            up.tap(); XCTAssertNotEqual(disc.value as? String, mixed)
            capture(title + "-mixed-spin-controls")
            closePad()
            // Restore normal defaults for independent UI tests on this managed device.
            app.buttons["accuracy.more"].tap(); ready(app.buttons["accuracy.trainingSettings"])
            app.buttons["accuracy.trainingSettings"].tap()
            top(); set("accuracy.manualSideSpin", true)
            startRound(); ready(app.buttons["accuracy.strike"])
        }
    }
    func testAccuracySettingsScreenshots() {
        continueAfterFailure = false
        for title in ["2D准度", "3D准度"] {
            let app = open(title)
            capture(title + "-settings-top")
            app.swipeUp()
            capture(title + "-settings-bottom")
            app.terminate()
        }
    }

    func testAccuracyCurrentAimCloseupInBothModes() {
        continueAfterFailure = false
        for title in ["2D准度", "3D准度"] {
            let app = open(title)
            defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
            app.swipeUp()
            capture(title + "-settings-info")
            app.buttons["accuracy.start"].tap(); app.selectTrainingView(trainingTitle)
            ready(app.buttons["accuracy.strike"])
            capture(title + "-question-info")
            func node(_ id: String) -> XCUIElement {
                app.descendants(matching: .any).matching(identifier: id).firstMatch
            }
            func menu() { app.buttons["accuracy.more"].tap(); ready(app.buttons["menu.aimCloseup"]) }
            menu()
            let toggle = app.buttons["menu.aimCloseup"]
            if toggle.value as? String != "已选" { toggle.tap() }
            XCTAssertEqual(toggle.value as? String, "已选")
            XCTAssertFalse(app.buttons["accuracy.trajectory"].exists)
            XCTAssertFalse(app.buttons["accuracy.separation"].exists)
            XCTAssertFalse(app.buttons["accuracy.rehearsal"].exists)
            capture(title + "-current-aim-menu")
            app.buttons["accuracy.dismissMenu"].tap()
            XCTAssertFalse(node("aimCloseup.hud").exists)
            let ruler = node("accuracy.aimWheel")
            ready(ruler)
            let start = ruler.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            // The teaching page can rotate inside a portrait host. Follow the
            // ruler's actual screen axis rather than assuming global vertical.
            let travel = ruler.frame.width > ruler.frame.height
                ? CGVector(dx: -50, dy: 0) : CGVector(dx: 0, dy: -50)
            let preparationTravel = CGVector(dx: travel.dx * 1.6, dy: travel.dy * 1.6)
            // Establish a visible offset even at the ruler's 0.1 fine gain.
            // At full gain the total travel remains inside the 3.5R near band.
            for _ in 0..<2 {
                start.press(forDuration: 0.1, thenDragTo: start.withOffset(preparationTravel),
                            withVelocity: XCUIGestureVelocity(rawValue: 200), thenHoldForDuration: 0.1)
            }
            // An external simctl screenshot captures this real held gesture without
            // asking XCTest to wait for the app to become idle during the touch.
            print("ACCURACY_CLOSEUP_CAPTURE \(title) ruler=\(ruler.frame)")
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(travel),
                        withVelocity: XCUIGestureVelocity(rawValue: 200), thenHoldForDuration: 10)
            XCTAssertTrue(node("aimCloseup.hud").waitForNonExistence(timeout: 3))
            capture(title + "-current-aim-released")
            menu(); XCTAssertEqual(toggle.value as? String, "已选")
            toggle.tap(); XCTAssertEqual(toggle.value as? String, "未选")
            app.buttons["accuracy.dismissMenu"].tap()
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(.init(dx: 0, dy: 3)))
            XCTAssertFalse(node("aimCloseup.hud").exists)
            menu(); toggle.tap(); app.buttons["accuracy.dismissMenu"].tap()
            XCUIDevice.shared.press(.home); app.activate()
            ready(app.buttons["accuracy.strike"])
            XCTAssertFalse(node("aimCloseup.hud").exists)
            menu(); XCTAssertEqual(toggle.value as? String, "已选")
            app.buttons["accuracy.dismissMenu"].tap()
            if title.hasPrefix("3D") {
                let top = app.buttons["shotCamera.temporaryTopDown"]
                ready(top); top.tap()
                XCTAssertFalse(node("aimCloseup.hud").exists)
                XCTAssertFalse(app.buttons["accuracy.strike"].isEnabled)
                top.tap(); ready(app.buttons["accuracy.strike"])
            }
            app.buttons["accuracy.strike"].tap()
            XCTAssertFalse(node("aimCloseup.hud").exists)
            ready(app.buttons["accuracy.retry"], timeout: 60)
            XCTAssertFalse(node("aimCloseup.hud").exists)
            capture(title + "-result-info")
            app.buttons["accuracy.retry"].tap(); ready(app.buttons["accuracy.strike"])
            menu(); XCTAssertEqual(toggle.value as? String, "已选")
        }
    }

    func testSixPagesTrainingInformationAndStableRuler() {
        continueAfterFailure = false
        var rulerFrames: [String: CGRect] = [:]
        for title in ["2D角度", "3D角度", "2D瞄准点", "3D瞄准点", "2D准度", "3D准度"] {
            let app = open(title)
            defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
            let accuracy = title.contains("准度"), aimPoint = title.contains("瞄准点")
            let prefix = accuracy ? "accuracy" : aimPoint ? "aimPointTraining" : "angleTraining"
            func node(_ id: String) -> XCUIElement {
                app.descendants(matching: .any).matching(identifier: id).firstMatch
            }
            app.buttons[prefix + ".start"].tap(); app.selectTrainingView(trainingTitle)
            let primary = app.buttons[accuracy ? "accuracy.strike" : aimPoint ? "aimPointTraining.submit" : "angleTraining.primaryAction"]
            ready(primary)
            let expectedTitle = XCUIApplication.trainingCardTitle(title)
            let header = accuracy
                ? app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", expectedTitle)).firstMatch
                : node("training.pageTitle")
            XCTAssertTrue(header.exists); XCTAssertEqual(header.label, expectedTitle)
            XCTAssertFalse(node(prefix + ".remaining").exists)
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "剩余 ")).firstMatch.exists)
            capture(title + "-information-initial")
            if accuracy {
                rulerFrames[title] = node("accuracy.aimWheel").frame
                continue
            }
            let assist = app.buttons[aimPoint ? "aimPointTraining.angleHint" : "angleTraining.assist"]
            ready(assist); XCTAssertEqual(assist.label, "辅助")
            let ruler = node("aimPointTraining.aimWheel")
            let initialFrame = aimPoint ? ruler.frame : .zero
            if aimPoint {
                rulerFrames[title] = initialFrame
                let top = node(prefix + ".questionInfo"), bottom = node(prefix + ".answerInfo")
                XCTAssertTrue(top.label.contains("1/15")); XCTAssertTrue(top.label.contains("正确率"))
                XCTAssertFalse(top.label.contains("均差")); XCTAssertFalse(top.label.contains("作答"))
                XCTAssertTrue(bottom.label.contains("独立")); XCTAssertTrue(bottom.label.contains("均差"))
                XCTAssertLessThanOrEqual(top.frame.maxY, initialFrame.minY)
                XCTAssertGreaterThanOrEqual(bottom.frame.minY, initialFrame.maxY)
            }
            assist.tap(); XCTAssertEqual(assist.label, "辅助"); XCTAssertEqual(assist.value as? String, "已开启")
            if aimPoint {
                XCTAssertTrue(node(prefix + ".answerInfo").label.contains("辅助"))
                XCTAssertEqual(ruler.frame.minY, initialFrame.minY, accuracy: 1)
            }
            capture(title + "-assisted")
            assist.tap(); XCTAssertEqual(assist.value as? String, "已关闭")
            primary.tap()
            if !aimPoint {
                ready(app.buttons["0"].firstMatch); app.buttons["0"].firstMatch.tap()
                app.buttons["提交"].tap()
            }
            let next = app.buttons[aimPoint ? "aimPointTraining.next" : "angleTraining.primaryAction"]
            ready(next)
            if aimPoint {
                let comparison = node("aimCloseup.hud")
                XCTAssertTrue(comparison.waitForExistence(timeout: 5))
                XCTAssertTrue(comparison.label.contains("橙线为目标方向"))
                XCTAssertTrue(node("aimPointTraining.answerLegend").exists)
            } else { XCTAssertTrue(node(prefix + ".result").exists) }
            if aimPoint {
                XCTAssertTrue(node(prefix + ".questionInfo").label.contains("1/15"))
                XCTAssertEqual(ruler.frame.minY, initialFrame.minY, accuracy: 1)
            }
            capture(title + "-submitted")
            next.tap(); ready(assist)
            if aimPoint {
                XCTAssertTrue(node(prefix + ".questionInfo").label.contains("2/15"))
                XCTAssertTrue(node(prefix + ".answerInfo").label.contains("独立"))
                XCTAssertEqual(ruler.frame.minY, initialFrame.minY, accuracy: 1)
            }
        }
        for mode in ["2D", "3D"] {
            XCTAssertEqual(rulerFrames[mode + "瞄准点"]!.minY, rulerFrames[mode + "准度"]!.minY, accuracy: 1)
            XCTAssertEqual(rulerFrames[mode + "瞄准点"]!.height, rulerFrames[mode + "准度"]!.height, accuracy: 1)
        }
    }

    func testAccuracyStandardRetryAndRecordedPlayback() {
        continueAfterFailure = false
        for title in ["2D准度", "3D准度"] {
            let app = open(title)
            defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
            app.buttons["accuracy.start"].tap(); app.selectTrainingView(trainingTitle)
            let strike = app.buttons["accuracy.strike"], retry = app.buttons["accuracy.retry"]
            let playback = app.buttons["accuracy.playback"]
            ready(strike)
            XCTAssertTrue(retry.exists); XCTAssertEqual(retry.label, "重打"); XCTAssertFalse(retry.isEnabled)
            XCTAssertTrue(playback.exists); XCTAssertEqual(playback.label, "回放"); XCTAssertFalse(playback.isEnabled)
            capture(title + "-standard-retry-replay-initial")
            strike.tap(); ready(playback, timeout: 60); ready(retry)
            let info = app.descendants(matching: .any).matching(identifier: "accuracy.questionInfo").firstMatch
            let metrics = info.label
            capture(title + "-standard-retry-replay-ready")
            playback.tap()
            XCTAssertEqual(strike.label, "停止")
            XCTAssertFalse(retry.isEnabled)
            capture(title + "-recorded-playback")
            ready(playback, timeout: 60) // Natural completion restores the result phase.
            XCTAssertEqual(info.label, metrics)
            retry.tap(); ready(strike)
            XCTAssertEqual(strike.label, "击球")
            XCTAssertEqual(info.label, metrics)
            ready(playback); playback.tap(); ready(strike); strike.tap()
            ready(playback)
            XCTAssertEqual(strike.label, "击球")
            XCTAssertEqual(info.label, metrics)
            capture(title + "-replay-stopped-retry-preserved")
            strike.tap(); ready(retry, timeout: 60)
            XCTAssertEqual(info.label, metrics)
            app.buttons["accuracy.more"].tap(); app.buttons["accuracy.finish"].tap()
            ready(app.buttons["training.restart"])
            capture(title + "-replay-first-attempt-summary")
        }
    }

    func testAccuracyQuestionNoticeExpiresAndNextQuestionShowsAgain() {
        continueAfterFailure = false
        for title in ["2D准度", "3D准度"] {
            let app = open(title)
            defer { app.terminate() }
            app.buttons["accuracy.start"].tap(); app.selectTrainingView(trainingTitle)
            // Selecting the view takes longer than the short-lived notice. Start a
            // fresh round in that selected view before observing the notice timer.
            app.buttons["accuracy.more"].tap(); app.buttons["accuracy.trainingSettings"].tap()
            ready(app.buttons["accuracy.start"]); app.buttons["accuracy.start"].tap()
            let notice = app.staticTexts["accuracy.question"]
            XCTAssertTrue(notice.waitForExistence(timeout: 40))
            XCTAssertTrue(notice.label.contains("第1题"))
            capture(title + "-notice-visible")
            XCTAssertTrue(notice.waitForNonExistence(timeout: 5))
            let strike = app.buttons["accuracy.strike"]
            ready(strike)
            capture(title + "-notice-expired")
            let info = app.descendants(matching: .any).matching(identifier: "accuracy.questionInfo").firstMatch
            XCTAssertTrue(info.label.contains("1/15"))
            strike.tap()
            ready(app.buttons["accuracy.retry"], timeout: 60)
            let result = app.staticTexts["accuracy.result"]
            XCTAssertTrue(result.exists)
            XCTAssertTrue(result.waitForNonExistence(timeout: 5), "Result feedback must expire while statistics remain")
            XCTAssertTrue(info.exists)
            capture(title + "-result-expired")
            strike.tap()
            XCTAssertTrue(notice.waitForExistence(timeout: 5))
            XCTAssertTrue(notice.label.contains("第2题"))
            capture(title + "-next-notice")
            XCTAssertTrue(notice.waitForNonExistence(timeout: 5))
            XCTAssertTrue(info.label.contains("2/15"))
            ready(strike)
            capture(title + "-next-expired")
        }
        XCUIDevice.shared.orientation = .portrait
    }
    func testStandardAngle2D() throws { try standardContract("2D角度") }
    func testStandardAngle3D() throws { try standardContract("3D角度") }
    func testStandardAimPoint2D() throws { try standardContract("2D瞄准点") }
    func testStandardAimPoint3D() throws { try standardContract("3D瞄准点") }
    func testStandardAccuracy2D() throws { try standardContract("2D准度") }
    func testStandardAccuracy3D() throws { try standardContract("3D准度") }

    private func standardContract(_ title: String) throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore",
            "-3dDrag.probe", "-dailyLayout.probe", "-freeLayout.ephemeral",
            "-v51.followSystemAppearance", "-appearanceMode", "system"])
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        let accuracy = title.contains("准度"), aimPoint = title.contains("瞄准点")
        let prefix = accuracy ? "accuracy" : aimPoint ? "aimPointTraining" : "angleTraining"
        let primaryID = accuracy ? "accuracy.strike" : aimPoint ? "aimPointTraining.submit" : "答题"
        func node(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
        func probe() throws -> [String: Any] {
            let data = try XCTUnwrap((node(accuracy ? "table.scene" : prefix + ".scene").value as? String)?.data(using: .utf8))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        func balls() throws -> [String: [Double]] {
            let list = try XCTUnwrap(try probe()["balls"] as? [[String: Any]])
            return try Dictionary(uniqueKeysWithValues: list.map {
                (try XCTUnwrap($0["key"] as? String), try XCTUnwrap($0["world"] as? [Double]))
            })
        }
        func menu() {
            let button = app.buttons[prefix + (accuracy ? ".more" : ".settings")]
            ready(button); button.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            ready(app.buttons["menu.tableGrid"])
        }
        func cancelLayout() {
            let cancel = app.buttons["freeLayout.cancel"]
            ready(cancel); cancel.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(node("freeLayout.editor").waitForNonExistence(timeout: 5))
        }
        func chooseMenu(_ id: String) {
            let button = app.buttons[id]
            for _ in 0..<5 where !button.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
            ready(button); button.tap()
        }
        func assertVisible(_ element: XCUIElement) {
            ready(element)
            XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1).contains(element.frame), element.debugDescription)
        }
        app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
        trainingTitle = title
        let card = app.buttons[XCUIApplication.trainingCardTitle(title)]
        for _ in 0..<4 where !card.isHittable { app.swipeUp() }
        ready(card); card.tap()
        ready(app.buttons[prefix + ".start"]); app.buttons[prefix + ".start"].tap(); app.selectTrainingView(trainingTitle)
        let primary = app.buttons[primaryID]
        // The isolated store starts with the actual automatic layout. Saving the
        // default as a template would instead freeze positions for window tests.
        assertVisible(primary)
        let originalBalls = try balls()
        XCTAssertEqual(originalBalls.count, 2)
        capture(title + "-standard-initial")
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .trait]) { issue in
            let detail = XCTAttachment(string: "Issue element: \(issue.element?.debugDescription ?? "nil")\n\(app.debugDescription)")
            detail.name = title + "-accessibility-issue"; detail.lifetime = .keepAlways; self.add(detail)
            return false
        }

        // The system really backgrounds/foregrounds the app; no simulated phase flag.
        XCUIDevice.shared.press(.home); app.activate(); assertVisible(primary)
        XCTAssertEqual(try balls(), originalBalls)
        if accuracy {
            XCTAssertEqual(try probe()["accuracyAimVisible"] as? Bool, true)
            XCTAssertEqual(try probe()["cueVisible"] as? Bool, true)
        }
        capture(title + "-background-return")

        if title.hasPrefix("3D") {
            let top = app.buttons["shotCamera.temporaryTopDown"]
            ready(top); top.tap()
            expectation(for: NSPredicate { _, _ in (try? probe()["standardTemporaryTable"] as? Bool) == true }, evaluatedWith: app)
            waitForExpectations(timeout: 10)
            capture(title + "-temporary-top-down")
            if accuracy { XCTAssertFalse(primary.isEnabled) }
            top.tap(); assertVisible(primary)
            XCTAssertEqual(try balls(), originalBalls)
            top.tap()
            expectation(for: NSPredicate { _, _ in (try? probe()["standardTemporaryTable"] as? Bool) == true }, evaluatedWith: app)
            waitForExpectations(timeout: 10)
            XCUIDevice.shared.press(.home); app.activate(); assertVisible(primary)
            XCTAssertEqual(try probe()["standardTemporaryTable"] as? Bool, false)
            XCTAssertEqual(try balls(), originalBalls)
            capture(title + "-temporary-background-return")
        }

        // Menu interception: tapping the primary's physical location closes only the menu.
        let primaryCenter = primary.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        menu(); ready(app.buttons["menu.tableGrid"])
        let grid = app.buttons["menu.tableGrid"], gridValue = app.buttons["menu.tableGrid"].value as? String
        grid.tap(); ready(grid)
        XCTAssertNotEqual(grid.value as? String, gridValue)
        grid.tap(); XCTAssertEqual(grid.value as? String, gridValue)
        capture(title + "-menu")
        let panel = node("dailyClearance.menuPanel")
        let center = CGPoint(x: primary.frame.midX, y: primary.frame.midY)
        if panel.frame.contains(center) {
            // At accessibility text sizes the menu covers the underlying action.
            // Tapping there would legitimately select a menu row, so use its outside mask.
            app.coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
        } else { primaryCenter.tap() }
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        assertVisible(primary)
        XCTAssertEqual(try balls(), originalBalls)
        XCTAssertFalse(app.buttons["training.restart"].exists)

        // Move and resize a real control, cancel, and confirm the original geometry/state.
        menu(); chooseMenu("controlLayout.open")
        let key = accuracy ? "shot.aim" : aimPoint ? "aimPoint.hint" : "angle.assist"
        let edit = app.buttons["freeLayout.select." + key]
        ready(edit); let original = edit.frame
        edit.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        ready(app.buttons["freeLayout.larger"]); app.buttons["freeLayout.larger"].tap()
        XCTAssertGreaterThan(edit.frame.width, original.width)
        app.buttons["freeLayout.collapse"].tap()
        let start = edit.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(.init(dx: 24, dy: -12)))
        XCTAssertGreaterThan(edit.frame.midX, original.midX + 10)
        XCTAssertEqual(try balls(), originalBalls)
        capture(title + "-layout-moved")
        cancelLayout()
        assertVisible(primary)
        menu(); chooseMenu("controlLayout.open"); ready(edit)
        XCTAssertEqual(edit.frame.width, original.width, accuracy: 1)
        XCTAssertEqual(edit.frame.midX, original.midX, accuracy: 1)
        cancelLayout(); assertVisible(primary)
        XCTAssertEqual(try balls(), originalBalls)

        // iPad rotations must keep the question and the actual action inside the window.
        if min(app.frame.width, app.frame.height) >= 600 {
            for orientation in [UIDeviceOrientation.landscapeLeft, .portrait, .landscapeLeft] {
                XCUIDevice.shared.orientation = orientation
                expectation(for: NSPredicate { _, _ in
                    let f = app.windows.firstMatch.frame
                    return orientation == .portrait ? f.height > f.width : f.width > f.height
                }, evaluatedWith: app)
                waitForExpectations(timeout: 10)
                assertVisible(primary); XCTAssertEqual(try balls(), originalBalls)
                capture(title + "-rotation-" + String(orientation.rawValue))
            }
            let window = app.windows.firstMatch, full = app.windows.firstMatch.frame
            let renderer = try probe()["rendererID"] as? String
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(.init(dx: full.width - 7, dy: full.height - 7)).press(forDuration: 0.5,
                thenDragTo: origin.withOffset(.init(dx: full.width * 0.7, dy: full.height * 0.78)))
            expectation(for: NSPredicate { _, _ in window.frame.width < full.width - 80 }, evaluatedWith: app)
            waitForExpectations(timeout: 10)
            assertVisible(primary); XCTAssertEqual(try balls(), originalBalls)
            let viewport = try XCTUnwrap(try probe()["displayedViewport"] as? [Double])
            XCTAssertLessThanOrEqual(viewport[2], window.frame.width + 1)
            capture(title + "-system-window-small")
            window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
            if abs(window.frame.width - full.width) > 1 {
                window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap()
            }
            expectation(for: NSPredicate { _, _ in abs(window.frame.width - full.width) < 1 }, evaluatedWith: app)
            waitForExpectations(timeout: 10)
            assertVisible(primary); XCTAssertEqual(try balls(), originalBalls)
            XCTAssertEqual(try probe()["rendererID"] as? String, renderer)
            capture(title + "-system-window-restored")
        }

        menu(); chooseMenu(prefix + ".trainingSettings")
        ready(app.buttons["training.settingsCancel"]); app.buttons["training.settingsCancel"].tap()
        assertVisible(primary); XCTAssertEqual(try balls(), originalBalls)
        menu(); chooseMenu(prefix + ".finish")
        ready(app.buttons["training.restart"])
        XCTAssertTrue(app.staticTexts["题数"].exists)
        app.buttons["training.restart"].tap()
        ready(app.buttons["training.settingsCancel"]); app.buttons["training.settingsCancel"].tap()
        ready(app.buttons["training.complete"])
        capture(title + "-cancel-restart-summary")
        app.buttons["training.complete"].tap(); ready(app.buttons["angleHomeTab_练"])
    }
    private func capture(_ name: String) {
        let screen = XCUIScreen.main.screenshot()
        if let path = ProcessInfo.processInfo.environment["V52_SHOT_DIR"] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_V52_SHOT_DIR"] {
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                try screen.pngRepresentation.write(to: URL(fileURLWithPath: path).appendingPathComponent(name + ".png"))
            } catch { XCTFail("Screenshot export: \(error)") }
        }
        let shot = XCTAttachment(screenshot: screen)
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testSixPagesVisualBaseline() {
        continueAfterFailure = false
        for title in ["2D角度", "3D角度", "2D瞄准点", "3D瞄准点", "2D准度", "3D准度"] {
            XCUIDevice.shared.orientation = .portrait
            let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore"])
            app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
            trainingTitle = title
            let card = app.buttons[XCUIApplication.trainingCardTitle(title)]
            if !card.isHittable { app.swipeUp() }
            XCTAssertTrue(card.waitForExistence(timeout: 8)); card.tap()
            let prefix = title.contains("准度") ? "accuracy" : title.contains("瞄准点") ? "aimPointTraining" : "angleTraining"
            XCTAssertTrue(app.buttons[prefix + ".start"].waitForExistence(timeout: 10))
            capture(title + "-settings")
            app.buttons[prefix + ".start"].tap(); app.selectTrainingView(trainingTitle)
            let action = app.buttons[title.contains("准度") ? "accuracy.strike" : title.contains("瞄准点") ? "aimPointTraining.submit" : "答题"]
            XCTAssertTrue(action.waitForExistence(timeout: 40))
            expectation(for: NSPredicate { _, _ in action.isHittable && action.isEnabled }, evaluatedWith: app)
            waitForExpectations(timeout: 15)
            capture(title + "-table")
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }
    private func fillTemplateName(_ field: XCUIElement, app: XCUIApplication, value: String) {
        ready(field); field.tap()
        // A fresh iOS 17 keyboard can cover the field with its QuickPath introduction.
        let keyboardIntro = app.buttons.matching(NSPredicate(format: "label IN %@", ["Continue", "继续"])).firstMatch
        if keyboardIntro.exists && keyboardIntro.isHittable { keyboardIntro.tap(); field.tap() }
        if let current = field.value as? String, current != "模板名称", !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(value)
        XCTAssertEqual(field.value as? String, value)
    }
    private func ready(_ element: XCUIElement, timeout: TimeInterval = 40) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: element)],
            timeout: timeout), .completed, element.debugDescription)
    }
    private func open(_ title: String, free: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: [free ? "-w7.forceDailyLimitNear" : "-forcePremium", "-v50.inMemoryStore"])
        app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
        trainingTitle = title
        let card = app.buttons[XCUIApplication.trainingCardTitle(title)]
        if !card.isHittable { app.swipeUp() }
        ready(card); card.tap()
        return app
    }
    func testFreeModesPaywallCancelAndCompletion() {
        continueAfterFailure = false
        for title in ["2D角度", "2D瞄准点", "2D准度", "3D准度"] {
            let app = open(title, free: true)
            let prefix = title.contains("准度") ? "accuracy" : title.contains("瞄准点") ? "aimPointTraining" : "angleTraining"
            let free = app.otherElements["training.length"].buttons["持续练习"]
            ready(free); XCTAssertEqual(free.value as? String, "需要 Pro"); capture(title + "-mode-lock"); free.tap()
            ready(app.buttons["subscription.close"]); capture(title + "-free-mode-paywall")
            app.buttons["subscription.close"].tap()
            XCTAssertTrue(app.otherElements["training.length"].buttons["15题"].isSelected)
            app.buttons[prefix + ".start"].tap(); app.selectTrainingView(trainingTitle)
            if title.contains("准度") {
                let strike = app.buttons["accuracy.strike"]; ready(strike); strike.tap()
                ready(app.buttons["accuracy.retry"], timeout: 60)
                XCTAssertFalse(app.buttons["training.restart"].exists, "Last free answer remains available for review")
                strike.tap()
            } else if title.contains("瞄准点") {
                ready(app.buttons["aimPointTraining.submit"]); app.buttons["aimPointTraining.submit"].tap()
                ready(app.buttons["aimPointTraining.next"]); app.buttons["aimPointTraining.next"].tap()
            } else {
                ready(app.buttons["答题"]); app.buttons["答题"].tap()
                ready(app.buttons["0"].firstMatch); app.buttons["0"].firstMatch.tap(); app.buttons["提交"].tap()
                ready(app.buttons["angleTraining.primaryAction"])
                XCTAssertFalse(app.buttons["training.restart"].exists, "Last free answer remains available for review")
                app.buttons["angleTraining.primaryAction"].tap()
            }
            ready(app.buttons["training.restart"], timeout: 60)
            XCTAssertTrue(app.staticTexts["题数"].exists)
            XCTAssertEqual(app.buttons["training.restart"].label, "重新开始")
            capture(title + "-quota-finish")
            app.buttons["training.restart"].tap()
            ready(app.buttons["subscription.close"]); app.buttons["subscription.close"].tap()
            ready(app.buttons["training.complete"]); app.buttons["training.complete"].tap()
            ready(app.buttons["angleHomeTab_练"])
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }
    func testAccuracyRetryAndLockedStandardPadInBothModes() {
        continueAfterFailure = false
        for title in ["2D准度", "3D准度"] {
            let app = open(title)
            // The current default allows manual spin on both axes. This case
            // explicitly chooses a fully locked pad through the settings UI.
            for id in ["accuracy.manualVerticalSpin", "accuracy.manualSideSpin"] {
                let toggle = app.switches[id]
                for _ in 0..<10 where !toggle.isHittable { app.swipeUp() }
                ready(toggle)
                if toggle.value as? String == "1" {
                    toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap()
                }
                XCTAssertEqual(toggle.value as? String, "0")
            }
            app.buttons["accuracy.start"].tap(); app.selectTrainingView(trainingTitle)
            let strike = app.buttons["accuracy.strike"]
            ready(strike)
            app.buttons["accuracy.more"].tap()
            ready(app.buttons["accuracy.transparency"]); app.buttons["accuracy.transparency"].tap()
            let slider = app.sliders["dailyClearance.spinTransparencySlider"]
            ready(slider); slider.adjust(toNormalizedSliderPosition: 0)
            // XCTest's normalized drag can stop 1% above the physical endpoint on iPad.
            // Exact zero persistence is separately covered by SixTrainingUnifiedTests.
            let percent = Int(app.staticTexts["dailyClearance.spinTransparencyPercent"].label.replacingOccurrences(of: "%", with: ""))
            XCTAssertNotNil(percent); XCTAssertTrue((0...1).contains(percent ?? -1))
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "spinPad.disc").firstMatch.exists)
            for name in ["高杆增加 1%", "低杆增加 1%", "左塞增加 1%", "右塞增加 1%", "回中"] {
                let button = app.buttons[name]
                XCTAssertTrue(button.exists, name); XCTAssertFalse(button.isEnabled, name)
            }
            capture(title + "-locked-standard-pad")
            // Dismiss the menu and pad using their standard outside interception.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
            ready(strike)
            // Persist a moved real primary button, then fire from its new hit region.
            app.buttons["accuracy.more"].tap()
            let layout = app.buttons["controlLayout.open"]
            for _ in 0..<5 where !layout.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
            ready(layout); layout.tap()
            let control = app.buttons["freeLayout.select.shot.strike"]
            ready(control)
            control.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            app.buttons["freeLayout.larger"].tap()
            app.buttons["freeLayout.collapse"].tap()
            let from = control.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            from.press(forDuration: 0.1, thenDragTo: from.withOffset(.init(dx: -30, dy: -10)))
            let saved = control.frame
            app.buttons["freeLayout.collapse"].tap()
            ready(app.buttons["freeLayout.save"]); app.buttons["freeLayout.save"].tap()
            let name = app.alerts.textFields.firstMatch
            fillTemplateName(name, app: app, value: "Accuracy hit region")
            app.alerts.buttons["保存"].tap()
            ready(strike)
            XCTAssertEqual(strike.frame.midX, saved.midX, accuracy: 1)
            XCTAssertEqual(strike.frame.width, saved.width, accuracy: 1)
            capture(title + "-saved-primary-layout")
            strike.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            ready(app.buttons["accuracy.retry"], timeout: 60)
            let info = app.descendants(matching: .any).matching(identifier: "accuracy.questionInfo").firstMatch
            let firstMetrics = info.label
            XCTAssertTrue(firstMetrics.contains("1/15"))
            XCTAssertTrue(firstMetrics.contains("进球率"))
            XCTAssertTrue(firstMetrics.contains("%"))
            app.buttons["accuracy.retry"].tap()
            ready(strike)
            XCTAssertFalse(app.staticTexts["accuracy.question"].exists, "Retry keeps the same question without reviving its expired notice")
            XCTAssertEqual(info.label, firstMetrics)
            capture(title + "-retry-aiming")
            strike.tap(); ready(app.buttons["accuracy.retry"], timeout: 60)
            XCTAssertEqual(info.label, firstMetrics)
            app.buttons["accuracy.more"].tap(); app.buttons["accuracy.finish"].tap()
            ready(app.buttons["training.restart"])
            XCTAssertTrue(app.staticTexts["题数"].exists)
            XCTAssertTrue(app.staticTexts["进球数量"].exists)
            capture(title + "-first-attempt-summary")
            app.buttons["training.restart"].tap()
            ready(app.buttons["training.settingsCancel"]); app.buttons["training.settingsCancel"].tap()
            ready(app.buttons["training.restart"])
            XCTAssertTrue(app.staticTexts["进球数量"].exists)
            capture(title + "-scored-summary-cancel-restart")
            app.buttons["training.restart"].tap()
            ready(app.buttons["accuracy.start"]); app.buttons["accuracy.start"].tap(); app.selectTrainingView(trainingTitle)
            ready(strike)
            XCTAssertTrue(info.label.contains("1/15"))
            app.buttons["accuracy.more"].tap(); app.buttons["accuracy.finish"].tap()
            app.buttons["training.complete"].tap()
            ready(app.buttons["angleHomeTab_练"])
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }

    func testFreeModeUpgradeSelectsModeWithoutStarting() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-v53.authenticatedProfileFixture"])
        defer { app.terminate() }
        app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
        app.buttons["角度练习"].tap()
        let mode = app.otherElements["training.length"]
        ready(mode.buttons["持续练习"]); mode.buttons["持续练习"].tap()
        ready(app.buttons["subscription.close"])
        let unlock = app.buttons["simulatorUnlockProButton"]
        let scroll = app.scrollViews["subscription.scroll"]
        for _ in 0..<18 where !unlock.isHittable {
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.60))
                .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.10)))
        }
        ready(unlock); unlock.tap()
        ready(app.buttons["angleTraining.start"])
        XCTAssertTrue(mode.buttons["持续练习"].isSelected)
        XCTAssertFalse(app.buttons["答题"].exists)
        capture("free-mode-upgrade-stays-settings")
    }

    func testThreeProjectsAllowNonProToSwitchTo3D() {
        continueAfterFailure = false
        for title in ["3D角度", "3D瞄准点", "3D准度"] {
            let app = open(title, free: true)
            let prefix = title.contains("准度") ? "accuracy" : title.contains("瞄准点") ? "aimPointTraining" : "angleTraining"
            ready(app.buttons[prefix + ".start"])
            XCTAssertFalse(app.buttons["subscription.close"].exists)
            app.buttons[prefix + ".start"].tap()
            app.selectTrainingView(title)
            XCTAssertFalse(app.buttons["subscription.close"].exists)
            app.terminate()
        }
    }
    func testUpgradeReturnsToCompletedRoundAndAllowsRestart() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: ["-w7.forceDailyLimitNear", "-v50.inMemoryStore", "-v53.authenticatedProfileFixture"])
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
        trainingTitle = "2D瞄准点"
        app.buttons["瞄准点练习"].tap()
        ready(app.buttons["aimPointTraining.start"]); app.buttons["aimPointTraining.start"].tap(); app.selectTrainingView(trainingTitle)
        ready(app.buttons["aimPointTraining.submit"]); app.buttons["aimPointTraining.submit"].tap()
        ready(app.buttons["aimPointTraining.next"]); app.buttons["aimPointTraining.next"].tap()
        ready(app.buttons["training.restart"]); app.buttons["training.restart"].tap()
        ready(app.buttons["subscription.close"])
        let unlock = app.buttons["simulatorUnlockProButton"]
        let scroll = app.scrollViews["subscription.scroll"]
        for _ in 0..<18 where !unlock.isHittable {
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.60))
                .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.10)))
        }
        ready(unlock); unlock.tap()
        ready(app.buttons["aimPointTraining.start"]); app.buttons["aimPointTraining.start"].tap(); app.selectTrainingView(trainingTitle)
        ready(app.buttons["aimPointTraining.submit"])
        capture("upgrade-restarted-round")
        app.buttons["aimPointTraining.settings"].tap(); app.buttons["aimPointTraining.finish"].tap()
        ready(app.buttons["training.complete"]); app.buttons["training.complete"].tap()
        ready(app.buttons["angleHomeTab_练"])
    }

}
