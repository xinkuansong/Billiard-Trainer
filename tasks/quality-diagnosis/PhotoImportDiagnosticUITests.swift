import XCTest

/// Normal synthetic-photo navigation; never bypasses selection, calibration or marking.
final class PhotoImportDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        let expected = try XCTUnwrap(env["QD_PHOTO_DEVICE_UDID"] ?? env["TEST_RUNNER_QD_PHOTO_DEVICE_UDID"])
        XCTAssertEqual(env["SIMULATOR_UDID"], expected)
        XCTAssertEqual(expected, "E19E17B9-F412-49D1-9BE0-EB12E58FC8F2")
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES", "-v50.inMemoryStore", "-forcePremium", "-v51.followSystemAppearance"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
    }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil { try capture("terminal") }
    }
    private func tap(_ element: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true AND enabled == true"), object: element)], timeout: 15), .completed)
        element.tap()
    }
    private func enterPhoto() throws {
        let tab = app.tabBars.buttons["练习"]
        tap(tab)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: tab)], timeout: 8), .completed)
        tap(app.buttons["angleHomeTab_打"])
        let card = app.buttons["拍照建球形"].firstMatch
        for _ in 0..<4 {
            if card.exists && card.isHittable && card.frame.maxY < app.tabBars.firstMatch.frame.minY { break }
            app.swipeUp()
        }
        XCTAssertTrue(card.exists)
        XCTAssertLessThan(card.frame.maxY, app.tabBars.firstMatch.frame.minY)
        tap(card)
        XCTAssertTrue(app.navigationBars["拍照建球形"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["选择照片"].exists)
        try capture("normal-photo-entry")
    }
    func testNormalPhotoEntryPresentsSystemPicker() throws {
        try enterPhoto()
        tap(app.buttons["选择照片"])
        // Discovery checkpoint: preserve actual system controls before choosing/cancelling.
        XCTAssertTrue(app.navigationBars["照片"].waitForExistence(timeout: 15))
        try capture("system-picker-controls")
    }
    func testPickerCancelThenSelectKnownSyntheticImage() throws {
        try enterPhoto()
        tap(app.buttons["选择照片"])
        let picker = app.navigationBars["照片"]
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        tap(picker.buttons["Cancel"])
        XCTAssertTrue(picker.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["选择照片"].exists)
        XCTAssertFalse(app.buttons["下一步"].exists)
        try capture("picker-cancel-keeps-empty-input")
        tap(app.buttons["选择照片"])
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        // Full previous screenshot identified this exact asset as QD004-PHOTO-001.
        // Simulator also contains six stock sample images; never choose by index.
        let synthetic = app.images.matching(NSPredicate(format: "identifier == %@ AND label == %@", "PXGGridLayout-Info", "照片, 9月08日, 17:03"))
        XCTAssertEqual(synthetic.count, 1)
        tap(synthetic.firstMatch)
        XCTAssertTrue(picker.waitForNonExistence(timeout: 15))
        XCTAssertTrue(app.buttons["重新选图"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["左上"].exists)
        XCTAssertTrue(app.staticTexts["右下"].exists)
        XCTAssertTrue(app.buttons["下一步"].isEnabled)
        try capture("known-synthetic-default-calibration")
    }
    func testKnownSyntheticThumbnailLoadsCalibration() throws {
        try enterPhoto()
        tap(app.buttons["选择照片"])
        let picker = app.navigationBars["照片"]
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        // Full previous screenshot identified this exact asset as QD004-PHOTO-001.
        // Simulator also contains six stock sample images; never choose by index.
        let synthetic = app.images.matching(NSPredicate(format: "identifier == %@ AND label == %@", "PXGGridLayout-Info", "照片, 9月08日, 17:03"))
        XCTAssertEqual(synthetic.count, 1)
        let thumbnail = synthetic.firstMatch
        let frame = thumbnail.frame
        print("[QD-Photo] thumbnail exists=\(thumbnail.exists) enabled=\(thumbnail.isEnabled) hittable=\(thumbnail.isHittable) frame=\(frame)")
        XCTAssertEqual(frame.origin.x, 0, accuracy: 1)
        XCTAssertEqual(frame.origin.y, 292, accuracy: 1)
        XCTAssertEqual(frame.width, 132.9, accuracy: 1)
        XCTAssertEqual(frame.height, 133, accuracy: 1)
        try capture("known-thumbnail-before-coordinate-selection")
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 15))
        XCTAssertTrue(app.buttons["重新选图"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["左上"].exists)
        XCTAssertTrue(app.staticTexts["右下"].exists)
        XCTAssertTrue(app.buttons["下一步"].isEnabled)
        try capture("known-synthetic-default-calibration")
    }
    func testSyntheticFourCornersAndEmptyMarkingStep() throws {
        try testKnownSyntheticThumbnailLoadsCalibration()
        let images = app.images.allElementsBoundByIndex.filter {
            abs($0.frame.width - 378) < 1 && abs($0.frame.height - 302.4) < 1
        }
        XCTAssertEqual(images.count, 1)
        let fitted = try XCTUnwrap(images.first).frame
        XCTAssertEqual(fitted.minX, 12, accuracy: 1)
        XCTAssertEqual(fitted.minY, 295, accuracy: 1)
        let labels = ["左上", "右上", "右下", "左下"]
        let uv = [CGPoint(x: 0.1, y: 0.25), CGPoint(x: 0.9, y: 0.25), CGPoint(x: 0.9, y: 0.75), CGPoint(x: 0.1, y: 0.75)]
        let origin = app.coordinate(withNormalizedOffset: .zero)
        // Image uv is left-top origin, x right/y down; Canvas mapping tested separately.
        // Actual labels are 24pt above their handles, confirmed in source and full screenshot.
        for (i, label) in labels.enumerated() {
            let element = app.staticTexts[label]
            XCTAssertTrue(element.exists)
            let frame = element.frame
            let start = CGPoint(x: frame.midX, y: frame.midY + 24)
            let target = CGPoint(x: fitted.minX + uv[i].x * fitted.width, y: fitted.minY + uv[i].y * fitted.height)
            print("[QD-Photo] corner \(label) from=\(start) to=\(target)")
            origin.withOffset(CGVector(dx: start.x, dy: start.y)).press(forDuration: 0.2, thenDragTo: origin.withOffset(CGVector(dx: target.x, dy: target.y)))
            let actual = element.frame
            XCTAssertEqual(actual.midX, target.x, accuracy: 2)
            XCTAssertEqual(actual.midY + 24, target.y, accuracy: 2)
        }
        XCTAssertTrue(app.buttons["长库（长边）"].isSelected)
        XCTAssertTrue(app.buttons["下一步"].isEnabled)
        try capture("four-corners-on-synthetic-inner-edges")
        tap(app.buttons["下一步"])
        XCTAssertTrue(app.staticTexts["已标 0 颗"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["下一步"].isEnabled)
        try capture("normal-empty-marking-step")
    }
    func testSyntheticTwoMarksUndoRedoAndConfirm() throws {
        try testSyntheticFourCornersAndEmptyMarkingStep()
        let images = app.images.allElementsBoundByIndex.filter { abs($0.frame.width - 378) < 1 && abs($0.frame.height - 528) < 1 }
        XCTAssertEqual(images.count, 1)
        let container = try XCTUnwrap(images.first).frame
        XCTAssertEqual(container.minX, 12, accuracy: 1)
        XCTAssertEqual(container.minY, 178.7, accuracy: 1)
        // The mark-step AX image is its full gesture container. Source aspect-fits
        // 1000x800 pixels; full prior screenshot confirms vertically centred image.
        let h = container.width * 0.8
        let fitted = CGRect(x: container.minX, y: container.midY - h / 2, width: container.width, height: h)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        for (index, uv) in [CGPoint(x: 0.3, y: 0.35), CGPoint(x: 0.7, y: 0.65)].enumerated() {
            let pt = CGPoint(x: fitted.minX + uv.x * fitted.width, y: fitted.minY + uv.y * fitted.height)
            print("[QD-Photo] actual mark \(index) at=\(pt)")
            origin.withOffset(CGVector(dx: pt.x, dy: pt.y)).tap()
            XCTAssertTrue(app.staticTexts["已标 \(index + 1) 颗"].waitForExistence(timeout: 8))
        }
        try capture("two-normal-contact-marks")
        tap(app.buttons["arrow.uturn.backward"])
        XCTAssertTrue(app.staticTexts["已标 1 颗"].exists)
        tap(app.buttons["arrow.uturn.forward"])
        XCTAssertTrue(app.staticTexts["已标 2 颗"].exists)
        try capture("two-marks-after-undo-redo")
        tap(app.buttons["下一步"])
        XCTAssertTrue(app.buttons["送入…"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["重新标记"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "paletteBall_cueBall").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "paletteBall__1").firstMatch.exists)
        try capture("normal-two-ball-confirmation")
    }
    private func sceneBall(_ key: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", key)).firstMatch
    }
    func testNormalConfirmRenameAndSendToThreeTools() throws {
        try testSyntheticTwoMarksUndoRedoAndConfirm()
        let first = sceneBall("_1")
        XCTAssertTrue(first.exists)
        let before = first.frame
        XCTAssertEqual(before.midX, 268.85, accuracy: 2)
        XCTAssertEqual(before.midY, 334.85, accuracy: 2)
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: before.midX, dy: before.midY)).tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "已选 1 号")).firstMatch.waitForExistence(timeout: 8))
        tap(app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", "paletteBall__2")).firstMatch)
        XCTAssertFalse(sceneBall("_1").exists)
        XCTAssertTrue(sceneBall("_2").exists)
        let changed = sceneBall("_2").frame
        XCTAssertEqual(changed.midX, before.midX, accuracy: 2)
        XCTAssertEqual(changed.midY, before.midY, accuracy: 2)
        try capture("normal-one-to-two-rename-keeps-position")
        for title in ["自由走位", "思路训练", "打一走二想三"] {
            tap(app.buttons["送入…"])
            tap(app.buttons[title])
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 15))
            let target = sceneBall("_2"), cue = sceneBall("cueBall")
            XCTAssertTrue(target.waitForExistence(timeout: 10))
            XCTAssertTrue(cue.exists)
            XCTAssertFalse(sceneBall("_1").exists)
            XCTAssertLessThan(cue.frame.midX, target.frame.midX)
            XCTAssertGreaterThan(cue.frame.midY, target.frame.midY)
            try capture("delivered-" + title)
            tap(app.navigationBars[title].buttons.firstMatch)
            XCTAssertTrue(app.buttons["送入…"].waitForExistence(timeout: 10))
            XCTAssertTrue(sceneBall("_2").exists)
            XCTAssertTrue(sceneBall("cueBall").exists)
        }
        try capture("three-destinations-returned-to-confirmation")
    }
    func testNormalTwoBallPhotoBoardSentToThreeTools() throws {
        try testSyntheticTwoMarksUndoRedoAndConfirm()
        for title in ["自由走位", "思路训练", "打一走二想三"] {
            tap(app.buttons["送入…"])
            tap(app.buttons[title])
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 15))
            let target = sceneBall("_1"), cue = sceneBall("cueBall")
            XCTAssertTrue(target.waitForExistence(timeout: 10))
            XCTAssertTrue(cue.exists)
            XCTAssertLessThan(target.frame.width, 30)
            XCTAssertLessThan(cue.frame.width, 30)
            XCTAssertLessThan(cue.frame.midX, target.frame.midX)
            XCTAssertGreaterThan(cue.frame.midY, target.frame.midY)
            try capture("original-two-ball-delivered-" + title)
            tap(app.navigationBars[title].buttons.firstMatch)
            XCTAssertTrue(app.buttons["送入…"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts["桌上 2 颗 · 拖动球可移位 · 点选可改号/移除"].exists)
        }
        try capture("three-original-board-destinations-returned")
    }
    private func capture(_ stage: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let id = "photo-" + stage + "-" + UUID().uuidString
        let a = XCTAttachment(screenshot: shot); a.name = id; a.lifetime = .keepAlways; add(a)
        let text = app.debugDescription
        let ax = XCTAttachment(string: text); ax.name = id + "-AX"; ax.lifetime = .keepAlways; add(ax)
        let env = ProcessInfo.processInfo.environment
        let p = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        let dir = URL(fileURLWithPath: p, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent(id + ".png"))
        try text.write(to: dir.appendingPathComponent(id + ".txt"), atomically: true, encoding: .utf8)
    }
}
