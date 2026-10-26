import XCTest

final class TwoBallPracticeUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false }
    private func node(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier:id).firstMatch }
    private func ready(_ e: XCUIElement, timeout: TimeInterval = 90) {
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == true AND enabled == true AND hittable == true"),object:e)],timeout:timeout),.completed,e.debugDescription)
    }
    private func capture(_ name: String) {
        let a = XCTAttachment(screenshot:XCUIScreen.main.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)
        let metadata:[String:Any] = ["state":node("twoBall.probe").exists ? ((try? probe()) ?? [:]):[:],"window":String(describing:app.windows.firstMatch.frame),"os":ProcessInfo.processInfo.operatingSystemVersionString]
        if let data=try? JSONSerialization.data(withJSONObject:metadata,options:[.prettyPrinted,.sortedKeys]) {
            let note=XCTAttachment(data:data,uniformTypeIdentifier:"public.json");note.name=name+"-state";note.lifetime = .keepAlways;add(note)
        }
    }
    private func probe() throws -> [String:Any] {
        let value = try XCTUnwrap(node("twoBall.probe").value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with:Data(value.utf8)) as? [String:Any])
    }
    private func waitPhase(_ p: String, timeout: TimeInterval = 90) {
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            (try? self.probe()["phase"] as? String) == p
        },object:app)],timeout:timeout),.completed)
    }
    private func open(is3D: Bool, free: Bool, animated: Bool, largeText: Bool = false, pocketFeedback: Bool = false) {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs:["-v50.inMemoryStore","-freeLayout.ephemeral","-forcePremium","-twoBall.probe","-twoBall.fixedSeed","-AppleInterfaceStyle",largeText ? "Light":"Dark"] + (pocketFeedback ? ["-pocketSelection.probe"] : []) + (largeText ? ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"]:[]))
        app.switchTab(.angle);app.buttons["angleHomeTab_打"].tap()
        let entry = app.buttons[is3D ? "3D两球走位" : "2D两球走位"]
        for _ in 0..<4 where !entry.isHittable { app.swipeUp() }
        ready(entry);capture("twoBall-entries");entry.tap()
        ready(app.buttons["twoBall.start"])
        app.segmentedControls["twoBall.mode"].buttons[free ? "自由走位" : "轨迹走位"].tap()
        let toggle = app.switches["separation.playsStroke"];ready(toggle)
        if (toggle.value as? String == "1") != animated { toggle.coordinate(withNormalizedOffset:.init(dx:0.9,dy:0.5)).tap() }
        capture("twoBall-settings-\(is3D)-\(free)")
        app.buttons["twoBall.start"].tap();ready(app.buttons["twoBall.strike"],timeout:180);waitPhase("aiming")
    }

    func test2DFeasibleSpinPad() throws { try exerciseFeasibleSpinPad(is3D: false) }
    func testComfort85ExecutionOrder2D() throws { try verifyExecutionOrder(is3D: false) }
    func testComfort85ExecutionOrder3D() throws { try verifyExecutionOrder(is3D: true) }
    private func verifyExecutionOrder(is3D: Bool) throws {
        open(is3D: is3D, free: false, animated: false)
        let initial = try probe()
        let scores = try XCTUnwrap(initial["executionDifficulties"] as? [Double])
        let comfort = try XCTUnwrap(initial["referenceComfortScores"] as? [Double])
        let count = try XCTUnwrap(initial["routeCount"] as? Int)
        XCTAssertEqual(scores.count, count); XCTAssertEqual(comfort.count, count)
        XCTAssertEqual(scores, scores.sorted()); XCTAssertTrue(comfort.allSatisfy { $0 >= 85 })
        for i in 0..<count {
            XCTAssertEqual(try probe()["routeIndex"] as? Int, i)
            XCTAssertTrue(node("twoBall.routeInfo").label.contains("\(i+1)/\(count)"))
            XCTAssertEqual(try probe()["executionDifficulties"] as? [Double], scores)
            capture("comfort85-\(is3D ? "3D" : "2D")-route-\(i+1)")
            app.buttons["twoBall.strike"].tap()
            if i == 0 {
                waitPhase("result")
                if count > 1 { app.buttons["twoBall.strike"].tap(); waitPhase("aiming") }
            } else if i < count-1 { waitPhase("aiming") }
        }
        app.terminate()
    }
    func test3DFeasibleSpinPad() throws { try exerciseFeasibleSpinPad(is3D: true) }
    private func exerciseFeasibleSpinPad(is3D: Bool) throws {
        open(is3D: is3D, free: true, animated: false)
        func checkAccess() throws {
            XCTAssertEqual(try probe()["inputAccessible"] as? Bool, true)
        }
        func showPad() {
            let entry = app.buttons["shotStage.spinEntry"]; ready(entry); entry.tap()
            ready(node("spinPad.disc"))
        }
        func closePad() {
            app.buttons["关闭打点"].coordinate(withNormalizedOffset: .init(dx: 0.05, dy: 0.5)).tap()
        }
        showPad()
        let disc = node("spinPad.disc")
        disc.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.97)).tap()
        try checkAccess()
        capture("twoBall-access-low-\(is3D)")
        for label in ["低杆增加 1%", "左塞增加 1%", "右塞增加 1%", "高杆增加 1%", "回中"] {
            app.buttons[label].tap(); try checkAccess()
        }
        capture("twoBall-access-reset-\(is3D)"); closePad()
        app.buttons["twoBall.strike"].tap(); waitPhase("result")
        app.buttons["twoBall.retry"].tap(); waitPhase("aiming"); try checkAccess()
        let input = try probe()["input"] as? [Double]
        let question = try probe()["question"] as? String
        app.buttons["twoBall.playback"].tap(); waitPhase("playing")
        app.buttons["twoBall.strike"].tap(); waitPhase("aiming"); try checkAccess()
        XCUIDevice.shared.press(.home); app.activate(); waitPhase("aiming")
        app.buttons["twoBall.back"].tap()
        let entry = app.buttons[is3D ? "3D两球走位" : "2D两球走位"]; ready(entry); entry.tap()
        ready(app.buttons["twoBall.strike"]); waitPhase("aiming")
        XCTAssertEqual(try probe()["question"] as? String, question)
        XCTAssertEqual(try probe()["input"] as? [Double], input)
        try checkAccess(); showPad(); capture("twoBall-access-restored-\(is3D)"); closePad()
        app.buttons["twoBall.strike"].tap(); waitPhase("result")
        app.buttons["twoBall.strike"].tap(); waitPhase("aiming")
        XCTAssertNotEqual(try probe()["question"] as? String, question)
        showPad(); app.buttons["回中"].tap(); try checkAccess()
        capture("twoBall-access-next-\(is3D)"); closePad()
        app.buttons["twoBall.back"].tap()
    }
    func test2DTrajectoryResultNoticeExpires() throws { try resultNoticeExpires(is3D: false, free: false) }
    func test3DTrajectoryResultNoticeExpires() throws { try resultNoticeExpires(is3D: true, free: false) }
    func test2DFreeResultNoticeExpires() throws { try resultNoticeExpires(is3D: false, free: true) }
    func test3DFreeResultNoticeExpires() throws { try resultNoticeExpires(is3D: true, free: true) }
    private func resultNoticeExpires(is3D: Bool, free: Bool) throws {
        open(is3D: is3D, free: free, animated: !free)
        app.buttons["twoBall.strike"].tap(); waitPhase("result")
        let notice = node("twoBall.result")
        XCTAssertTrue(notice.label.contains("本杆"))
        capture("score-notice-visible-\(is3D)-\(free)")
        XCTAssertTrue(notice.waitForNonExistence(timeout: 5))
        XCTAssertTrue(node("twoBall.latestScore").label.contains("本杆得分"))
        capture("score-notice-expired-\(is3D)-\(free)")
        if free {
            node("twoBall.latestScore").tap(); ready(app.alerts["评分详情"])
            XCTAssertTrue(app.alerts["评分详情"].staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "球距分")).firstMatch.exists)
            capture("score-sidebar-details-\(is3D)")
            app.alerts["评分详情"].buttons["知道了"].tap()
            XCTAssertFalse(notice.exists)
        }
        app.buttons["twoBall.retry"].tap(); waitPhase("aiming")
        XCTAssertTrue(notice.label.contains("上杆"))
        XCTAssertTrue(notice.waitForNonExistence(timeout: 5))
        XCTAssertTrue(node("twoBall.latestScore").label.contains("上杆得分"))
        capture("previous-notice-expired-\(is3D)-\(free)")
        // Adjusting inputs must not resurrect the previous score notice.
        let bar = node("shotStage.powerBar")
        bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.6)).press(forDuration: 0.1,
            thenDragTo: bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.53)))
        XCTAssertFalse(notice.exists)
        app.buttons["twoBall.strike"].tap(); waitPhase("result")
        XCTAssertTrue(notice.label.contains("本杆"))
        XCTAssertTrue(notice.waitForNonExistence(timeout: 5))
        app.buttons["twoBall.playback"].tap(); waitPhase("playing")
        XCTAssertFalse(notice.exists)
        app.buttons["twoBall.strike"].tap(); waitPhase("result")
        XCTAssertTrue(notice.waitForNonExistence(timeout: 5))
        XCTAssertTrue(node("twoBall.latestScore").exists)
    }
    func test2DTrajectoryFlow() throws { try flow(is3D:false,free:false,animated:true) }
    func test3DTrajectoryFlow() throws { try flow(is3D:true,free:false,animated:true) }
    func test2DFreeFlow() throws { try flow(is3D:false,free:true,animated:false) }
    func test3DFreeFlow() throws { try flow(is3D:true,free:true,animated:false) }
    private func flow(is3D:Bool, free:Bool, animated:Bool) throws {
        open(is3D:is3D,free:free,animated:animated,pocketFeedback:true)
        func assertOnlySecondPocketLit() throws {
            let value = try XCTUnwrap(node("table.scene").value as? String)
            let snapshot = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
            let pockets = try XCTUnwrap(snapshot["pockets"] as? [[String: Any]])
            XCTAssertEqual(pockets.count, 6)
            XCTAssertTrue(pockets.allSatisfy { ($0["yellow"] as? Double) == 0 && ($0["pending"] as? Bool) == false })
            let second = try XCTUnwrap(probe()["secondPocket"] as? Int)
            XCTAssertEqual(pockets.first { $0["index"] as? Int == second }?["style"] as? Int, 5)
        }
        app.buttons["twoBall.more"].tap()
        XCTAssertFalse(app.buttons["twoBall.rehearsal"].exists)
        capture("twoBall-menu-no-rehearsal-\(is3D)")
        app.buttons["twoBall.dismissMenu"].tap()
        let first = try probe(), pocket = first["secondPocket"] as? Int
        XCTAssertEqual(first["mode"] as? String,free ? "free":"trajectory")
        XCTAssertEqual(first["targetVisible"] as? Bool,!free)
        XCTAssertEqual((first["secondPosition"] as? [Double])?.count,3)
        XCTAssertEqual(first["primary"] as? String,free ? "提交":"击球")
        XCTAssertTrue(node("twoBall.latestScore").exists)
        XCTAssertFalse(node("twoBall.secondPocket").exists)
        XCTAssertFalse(node("twoBall.validRate").exists)
        XCTAssertTrue(node("twoBall.averageScore").label.contains("均分"))
        XCTAssertTrue(node("paletteBall__8").exists)
        let number = try XCTUnwrap(first["ballNumber"] as? Int)
        XCTAssertTrue((1...15).contains(number)); XCTAssertNotEqual(number, 8)
        XCTAssertEqual(first["secondBallNumber"] as? Int, 8)
        XCTAssertEqual(first["targetNodeName"] as? String, "_\(number)")
        XCTAssertEqual(first["secondNodeName"] as? String, "_8")
        Thread.sleep(forTimeInterval: 3.5)
        try assertOnlySecondPocketLit()
        XCTAssertFalse(node("twoBall.question").exists, "Pocket text is a three-second notice")
        if !free {
            XCTAssertTrue(node("twoBall.routeInfo").label.hasPrefix("轨迹: "))
            XCTAssertLessThan(node("twoBall.cutAngle").frame.maxY, node("twoBall.routeInfo").frame.minY)
            XCTAssertLessThan(node("twoBall.averageScore").frame.maxY, node("twoBall.cutAngle").frame.minY)
            XCTAssertLessThan(node("twoBall.routeInfo").frame.height, 25)
        }
        capture("twoBall-initial-\(is3D)-\(free)")
        if !free {
            let count = try XCTUnwrap(first["routeCount"] as? Int)
            if count > 1 {
                app.buttons["twoBall.strike"].tap();waitPhase("result")
                XCTAssertEqual(try probe()["routeIndex"] as? Int,0)
                XCTAssertEqual(try probe()["primary"] as? String,"新轨迹")
                capture("twoBall-first-default-shot-\(is3D)")
                app.buttons["twoBall.strike"].tap();waitPhase("aiming")
                XCTAssertEqual(try probe()["routeIndex"] as? Int,1)
                XCTAssertEqual(try probe()["primary"] as? String,"跳过")
            }
            let bar = node("shotStage.powerBar");ready(bar)
            bar.coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.6)).press(forDuration:0.1,thenDragTo:bar.coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.52)))
            XCTAssertEqual(try probe()["primary"] as? String,"击球")
        }
        app.buttons["twoBall.strike"].tap();waitPhase("result")
        XCTAssertTrue(node("twoBall.result").label.contains("本杆"))
        XCTAssertFalse(node("twoBall.result").label.contains("第一球进指定袋"))
        do {
            XCTAssertTrue(node("twoBall.routeAverageScore").label.contains(free ? "本题均分" : "轨迹均分"))
            XCTAssertLessThan(node("twoBall.actualLegend").frame.maxY, node("twoBall.routeAverageScore").frame.minY)
            XCTAssertLessThan(node("twoBall.routeAverageScore").frame.maxY, node("twoBall.latestScore").frame.minY)
        }
        XCTAssertLessThanOrEqual(node("twoBall.latestScore").frame.maxY, app.buttons["twoBall.retry"].frame.minY)
        capture("twoBall-result-\(is3D)-\(free)")
        let result = try probe();let attempts = result["attempts"] as? Int
        if animated {
            let reveal = try XCTUnwrap(result["revealedAt"] as? Double)
            let stroke = try XCTUnwrap(result["strokeStartedAt"] as? Double)
            XCTAssertGreaterThan(reveal, 0)
            XCTAssertGreaterThanOrEqual(stroke - reveal, 0)
            XCTAssertLessThan(stroke - reveal, 0.25, "No pre-stroke reveal delay")
        }
        if free {
            XCTAssertEqual(result["secondPocket"] as? Int,pocket);XCTAssertEqual(result["primary"] as? String,"下一题")
            let score = try XCTUnwrap(result["comfortScore"] as? Double)
            XCTAssertEqual(result["comfortVersion"] as? String, "comfort-d2-s3-pocket-angle20-min50-v1")
            XCTAssertTrue((0...100).contains(score))
            XCTAssertTrue(node("twoBall.latestScore").label.contains(String(format: "%.1f", score)))
            XCTAssertFalse(node("twoBall.latestScore").label.contains("难度"))
            node("twoBall.latestScore").tap()
            XCTAssertFalse(app.alerts["评分详情"].waitForExistence(timeout: 1))
            XCTAssertFalse(app.buttons["twoBall.latestScore"].exists)
            for text in ["球距分", "出杆空间分", "角度分", "三项最低分", "几何平均"] {
                XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch.exists)
            }
            XCTAssertTrue(node("twoBall.latestScore").label.contains(String(format: "%.1f", score)))
            capture("comfort-final-only-\(is3D)")
        }
        app.buttons["twoBall.retry"].tap();waitPhase("aiming")
        XCTAssertTrue(node("twoBall.result").label.contains("上杆"))
        XCTAssertTrue(node("twoBall.latestScore").label.contains("上杆得分"))
        XCTAssertEqual(try probe()["ballNumber"] as? Int, number)
        XCTAssertFalse(node("twoBall.question").exists)
        capture("twoBall-retry-\(is3D)-\(free)")
        if free {
            node("twoBall.result").tap()
            XCTAssertFalse(app.alerts["评分详情"].waitForExistence(timeout: 1))
        }
        try assertOnlySecondPocketLit()
        XCTAssertEqual(try probe()["primary"] as? String,animated ? "击球":"提交")
        app.buttons["twoBall.playback"].tap();waitPhase("playing");capture("twoBall-replay-\(is3D)-\(free)")
        app.buttons["twoBall.strike"].tap();waitPhase("aiming")
        XCTAssertEqual(try probe()["attempts"] as? Int,attempts)
        if free { XCTAssertEqual(try probe()["secondPocket"] as? Int,pocket) }
        app.buttons["twoBall.strike"].tap();waitPhase("result")
        XCTAssertEqual(try probe()["attempts"] as? Int,attempts)
        if !free {
            let average = try XCTUnwrap(try probe()["routeAverageScore"] as? Double)
            XCTAssertTrue(node("twoBall.routeAverageScore").label.contains(String(format: "%.1f", average)))
        }
        let oldQuestion = try probe()["question"] as? String
        if !free {
            let current = try probe(), count = try XCTUnwrap(current["routeCount"] as? Int)
            for _ in 0..<count*2 {
                let state = try probe()
                let index = try XCTUnwrap(state["routeIndex"] as? Int)
                let phase = try XCTUnwrap(state["phase"] as? String)
                if index == count-1 && phase == "result" { break }
                app.buttons["twoBall.strike"].tap()
                waitPhase(phase == "aiming" && index == count-1 ? "result" : "aiming")
            }
            XCTAssertEqual(try probe()["routeIndex"] as? Int,count-1)
            XCTAssertEqual(try probe()["phase"] as? String,"result")
        }
        app.buttons["twoBall.strike"].tap();waitPhase("aiming")
        XCTAssertNotEqual(try probe()["question"] as? String,oldQuestion)
        capture("twoBall-next-\(is3D)-\(free)")
        app.buttons["twoBall.more"].tap()
        let finish=app.buttons["twoBall.finish"]
        for _ in 0..<5 where !finish.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(finish);finish.tap();ready(app.buttons["training.complete"])
        capture("twoBall-summary-\(is3D)-\(free)")
        app.buttons["training.complete"].tap();ready(app.buttons["angleHomeTab_打"])
    }
    func test2DControlsAndAdaptation() throws { try expanded(is3D:false) }
    func test3DControlsAndAdaptation() throws { try expanded(is3D:true) }
    private func expanded(is3D: Bool) throws {
        open(is3D:is3D,free:true,animated:false)
        let question = try probe()["question"] as? String
        let primary = app.buttons["twoBall.strike"]
        func menu(_ id: String) {
            app.buttons["twoBall.more"].coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(node("dailyClearance.menuPanel").waitForExistence(timeout: 5))
            let item = app.buttons[id]
            for _ in 0..<5 where !item.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
            ready(item); item.tap()
        }
        menu("twoBall.trainingSettings")
        ready(app.buttons["twoBall.start"])
        app.segmentedControls["twoBall.mode"].buttons["轨迹走位"].tap()
        app.buttons["training.settingsCancel"].tap();waitPhase("aiming")
        XCTAssertEqual(try probe()["mode"] as? String,"free")
        XCTAssertEqual(try probe()["question"] as? String,question)
        menu("twoBall.transparency")
        let slider = app.sliders["dailyClearance.spinTransparencySlider"]
        ready(slider)
        for opacity in [CGFloat(0), 0.5, 1] {
            slider.adjust(toNormalizedSliderPosition: opacity)
            capture("\(is3D ? "3D" : "2D")-transparency-\(opacity)")
        }
        slider.adjust(toNormalizedSliderPosition: 0.5)
        app.buttons["dailyClearance.spinTransparencyDone"].tap()
        // Closing the subpanel keeps the expanded, editable standard pad.
        let up = app.buttons["高杆增加 1%"], side = app.buttons["右塞增加 1%"]
        ready(up); up.tap(); ready(side); side.tap()
        let input = try XCTUnwrap(try probe()["input"] as? [Double])
        XCTAssertGreaterThan(abs(input[0]), 0); XCTAssertGreaterThan(abs(input[1]), 0)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, false)
        XCTAssertFalse(app.staticTexts["计算中"].exists)
        app.buttons["回中"].tap()
        XCTAssertEqual(try probe()["input"] as? [Double], [0, 0, 2.5])
        XCTAssertFalse(node("twoBall.question").exists, "Opening controls must not revive an expired notice")
        capture("expanded-editable-pad")
        app.coordinate(withNormalizedOffset: .init(dx: 0.25, dy: 0.5)).tap()
        let bar = node("shotStage.powerBar")
        ready(bar)
        let beforePower = try XCTUnwrap((try probe()["input"] as? [Double])?.last)
        bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.7)).press(forDuration: 0.1,
            thenDragTo: bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.3)))
        let increased = try XCTUnwrap((try probe()["input"] as? [Double])?.last)
        XCTAssertGreaterThan(increased, beforePower); XCTAssertLessThanOrEqual(increased, 8)
        bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.3)).press(forDuration: 0.1,
            thenDragTo: bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.7)))
        XCTAssertLessThan(try XCTUnwrap((try probe()["input"] as? [Double])?.last), increased)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, false)
        menu("menu.tableGrid")
        capture("grid-enabled-menu")
        XCTAssertFalse(app.buttons["twoBall.rehearsal"].exists)
        app.buttons["twoBall.dismissMenu"].tap()
        menu("controlLayout.open")
        let control = app.buttons["freeLayout.select.shot.strike"]
        ready(control); let original = control.frame
        control.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        app.buttons["freeLayout.larger"].tap()
        XCTAssertGreaterThan(control.frame.width, original.width)
        app.buttons["freeLayout.collapse"].tap()
        let from = control.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(.init(dx: -24, dy: -10)))
        capture("layout-draft-moved")
        app.buttons["freeLayout.cancel"].coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(node("freeLayout.editor").waitForNonExistence(timeout: 5)); ready(primary)
        XCTAssertEqual(primary.frame.midX, original.midX, accuracy: 1)
        menu("controlLayout.open"); ready(control)
        control.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        app.buttons["freeLayout.larger"].tap()
        let saved = control.frame
        app.buttons["freeLayout.save"].tap()
        let field = app.alerts.textFields.firstMatch; ready(field)
        field.tap(); field.typeText("Two Ball UI \(is3D ? "3D" : "2D")")
        app.alerts.buttons["保存"].tap(); ready(primary)
        XCTAssertEqual(primary.frame.width, saved.width, accuracy: 1)
        if min(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height) >= 600 {
            for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
                XCUIDevice.shared.orientation = orientation
                // iPadOS restores the last floating window independently for each
                // orientation. Normalize that system state before testing fullscreen rotation.
                let rotatedWindow = app.windows.firstMatch
                if rotatedWindow.frame.minX > 1 || rotatedWindow.frame.minY > 40 {
                    let before = rotatedWindow.frame
                    rotatedWindow.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
                    if abs(rotatedWindow.frame.width-before.width) < 1 {
                        rotatedWindow.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap()
                    }
                    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                        self.app.windows.firstMatch.frame.minX < 1
                    }, object: nil)], timeout: 10), .completed)
                }
                let rotation = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    let f = self.app.windows.firstMatch.frame
                    return orientation == .portrait ? f.height > f.width : f.width > f.height
                }, object: nil)], timeout: 10)
                print("TWO_BALL_ROTATION requested=\(orientation.rawValue) window=\(app.windows.firstMatch.frame) scene=\(node("table.scene").frame)")
                capture("rotation-\(orientation.rawValue)-actual-window")
                XCTAssertEqual(rotation, .completed)
                ready(primary); XCTAssertTrue(app.windows.firstMatch.frame.contains(primary.frame))
                XCTAssertEqual(try probe()["question"] as? String, question)
                capture(orientation == .portrait ? "ipad-portrait" : "ipad-landscape-return")
            }
            let full = app.windows.firstMatch.frame, fullPrimaryWidth = primary.frame.width
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(.init(dx: full.width-7, dy: full.height-7)).press(forDuration: 0.5,
                thenDragTo: origin.withOffset(.init(dx: full.width*0.7, dy: full.height*0.78)))
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let f = self.app.windows.firstMatch.frame
                return f.width < full.width-80 || f.height < full.height-80
            }, object: nil)], timeout: 10), .completed, "Real system window resizing")
            ready(primary); XCTAssertEqual(try probe()["question"] as? String, question)
            XCTAssertFalse(primary.frame.intersects(bar.frame), "Resized strike must not overlap the power control")
            XCTAssertFalse(app.buttons["twoBall.retry"].frame.intersects(app.buttons["twoBall.playback"].frame))
            if is3D {
                for id in ["shotCamera.firstPerson", "shotCamera.thirdPerson", "shotCamera.temporaryTopDown", "dailyClearance.observeTable"] {
                    XCTAssertFalse(app.buttons[id].frame.intersects(bar.frame), "Camera must not overlap power after resize")
                }
            }
            capture("ipad-real-small-window")
            let window = app.windows.firstMatch, small = window.frame
            window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
            if abs(window.frame.width-small.width) < 1 {
                window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap()
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                abs(self.app.windows.firstMatch.frame.width-full.width) < 1
            }, object: nil)], timeout: 10), .completed)
            ready(primary); XCTAssertEqual(try probe()["question"] as? String, question)
            XCTAssertEqual(primary.frame.width, fullPrimaryWidth, accuracy: 1, "Same window restores the prior displayed layout")
            capture("ipad-full-window-restored")
        }
        if is3D {
            ready(app.buttons["shotCamera.temporaryTopDown"])
            app.buttons["shotCamera.temporaryTopDown"].tap()
            capture("temporary-topdown")
            XCTAssertEqual(try probe()["question"] as? String,question)
            app.buttons["shotCamera.temporaryTopDown"].tap();ready(primary)
            for id in ["shotCamera.firstPerson", "dailyClearance.observeTable", "shotCamera.thirdPerson"] {
                ready(app.buttons[id]); app.buttons[id].tap(); ready(primary); capture(id)
            }
        }
        primary.tap(); waitPhase("result", timeout: 120)
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        capture("moved-primary-real-shot")
        primary.tap(); waitPhase("aiming", timeout: 180)
        XCTAssertNotEqual(try probe()["question"] as? String, question)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, false)
        capture("next-question-clean")
        app.terminate()
    }
    func testLightLargeTextSettingsAndResult() throws {
        for is3D in [false,true] {
            open(is3D:is3D,free:true,animated:false,largeText:true)
            capture("large-text-initial-\(is3D)")
            app.buttons["twoBall.more"].tap()
            let item=app.buttons["twoBall.transparency"]
            for _ in 0..<5 where !item.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
            ready(item);item.tap()
            capture("large-text-expanded-\(is3D)")
            let done=app.buttons["dailyClearance.spinTransparencyDone"]
            for _ in 0..<5 where !done.isHittable { app.scrollViews["dailyClearance.spinTransparencyScroll"].swipeUp() }
            ready(done);done.tap()
            app.coordinate(withNormalizedOffset:.init(dx:0.25,dy:0.5)).tap()
            ready(app.buttons["twoBall.strike"]);app.buttons["twoBall.strike"].tap();waitPhase("result")
            capture("large-text-result-\(is3D)")
            app.terminate()
        }
    }

}
