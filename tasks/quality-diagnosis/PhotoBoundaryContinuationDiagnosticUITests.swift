import XCTest

/// Draft on the EXISTING dedicated synthetic-photo device; no user's photo library.
final class PhotoBoundaryContinuationDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private var output: URL!
    private var sequence = 0
    private struct Stop: Error { let reason: String }
    private func env(_ key: String) -> String? {
        let e = ProcessInfo.processInfo.environment
        return e[key] ?? e["TEST_RUNNER_" + key]
    }
    override func setUpWithError() throws {
        continueAfterFailure = false
        try require(env("QD_PHOTO_CONTINUATION_AUTH") == "EXISTING_QD004_SYNTHETIC_ONLY_DEVICE", "Existing isolated synthetic library authorization required")
        let expected = "E19E17B9-F412-49D1-9BE0-EB12E58FC8F2"
        try require(env("QD_PHOTO_DEVICE_UDID") == expected && env("SIMULATOR_UDID")?.uppercased() == expected, "Only the previously observed synthetic device is allowed")
        guard let root = env("QD_SHOT_DIR"), root.hasPrefix("/") else { throw Stop(reason: "Absolute new evidence root required") }
        output = URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent("photo-boundary-" + UUID().uuidString, isDirectory: true)
        try require(!FileManager.default.fileExists(atPath: output.path), "Fresh evidence leaf required")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-v50.inMemoryStore", "-forcePremium", "-v51.followSystemAppearance"]
        app.launch()
        try require(app.wait(for: .runningForeground, timeout: 15), "Actual foreground required")
        tap(app.tabBars.buttons["我的"])
        try require(app.buttons["profile.login"].waitForExistence(timeout: 10) && app.buttons["profile.login"].label.contains("游客模式") && !app.buttons["profile.accountHeader"].exists, "Actual guest only")
    }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil && output != nil { try capture("terminal-before-termination") }
    }
    private func require(_ v: Bool, _ why: String) throws { if !v { throw Stop(reason: why) } }
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
    private func loadSyntheticCalibration() throws {
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
    private func calibrateAndEnterMarks() throws {
        try loadSyntheticCalibration()
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
    private func markAndConfirm() throws {
        try calibrateAndEnterMarks()
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
    func testRenumberedSyntheticBallIsDeliveredToFreePositionAndReturns() throws {
        do {
            try markAndConfirm()
            let before = try ballRoot("_1").frame
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: before.midX, dy: before.midY)).tap()
            try require(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "已选 1 号")).firstMatch.waitForExistence(timeout: 8), "Actual 1-ball selection required")
            let palette = app.descendants(matching: .any).matching(identifier: "paletteBall__2")
            try require(palette.count == 1, "Unique actual palette number 2 required")
            tap(palette.firstMatch)
            try require(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "已选 2 号")).firstMatch.waitForExistence(timeout: 8), "Actual selected number must become 2")
            let changed = try ballRoot("_2").frame
            try require(abs(changed.midX - before.midX) <= 2 && abs(changed.midY - before.midY) <= 2, "Renumbering must preserve observed screen position")
            // Actual source/UI shows selection text instead of count while a ball is selected.
            // Tap the observed same 2-ball again to deselect, then retain the exact count assertion.
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: changed.midX, dy: changed.midY)).tap()
            try require(app.staticTexts["桌上 2 颗 · 拖动球可移位 · 点选可改号/移除"].waitForExistence(timeout: 8), "Renumber must retain two-ball count after normal deselection")
            try capture("renumbered-two-at-original-position-visual-review-required")
            tap(app.buttons["送入…"])
            let destinations = app.buttons.matching(identifier: "自由走位")
            try require(destinations.count == 1, "Unique actual delivery destination required")
            tap(destinations.firstMatch)
            try require(app.navigationBars["自由走位"].waitForExistence(timeout: 15), "Actual free-position destination required")
            let target = try ballRoot("_2"), cue = try ballRoot("cueBall")
            try require(cue.frame.midX < target.frame.midX && cue.frame.midY > target.frame.midY, "Delivered cue-left/below-target relationship must remain")
            try capture("renumbered-delivered-free-position-visual-review-required")
            let nav = app.navigationBars["自由走位"]
            let back = nav.buttons.matching(identifier: "BackButton")
            try require(back.count == 1, "Require observed runtime BackButton, no first-button guessing")
            tap(back.firstMatch)
            try require(app.buttons["送入…"].waitForExistence(timeout: 10), "Return must reach actual confirmation")
            _ = try ballRoot("_2"); _ = try ballRoot("cueBall")
            try require(app.staticTexts["桌上 2 颗 · 拖动球可移位 · 点选可改号/移除"].exists, "Return must retain two balls")
            try capture("verified-renumbered-one-destination-returned")
        } catch { try capture("failure-before-cleanup"); throw error }
    }

    /// Intended singular input. AX rounding cannot itself prove the 1e-12 model predicate.
    /// A still-enabled result must be triaged as input precision vs product, never silently passed.
    func testIntendedCollinearCalibrationRefusesProgress() throws {
        do {
            try loadSyntheticCalibration()
            let images = app.images.allElementsBoundByIndex.filter { abs($0.frame.width - 378) < 1 && abs($0.frame.height - 302.4) < 1 }
            try require(images.count == 1, "Previously observed actual synthetic image frame required")
            let fitted = images[0].frame
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let labels = ["左上", "右上", "右下", "左下"]
            // Same actual image centre x for all four; separated y prevents overlapping handles.
            for (i, name) in labels.enumerated() {
                let q = app.staticTexts.matching(identifier: name)
                try require(q.count == 1, "One actual corner label required")
                let frame = q.firstMatch.frame
                let target = CGPoint(x: fitted.midX, y: fitted.minY + fitted.height * CGFloat(0.15 + Double(i) * 0.22))
                try require(app.windows.firstMatch.frame.contains(target), "Measured drag end must lie inside actual image/window")
                origin.withOffset(CGVector(dx: frame.midX, dy: frame.midY + 24)).press(forDuration: 0.2, thenDragTo: origin.withOffset(CGVector(dx: target.x, dy: target.y)))
                try require(abs(q.firstMatch.frame.midX - target.x) <= 2 && abs(q.firstMatch.frame.midY + 24 - target.y) <= 2, "Actual corner handle must follow the intended gesture")
            }
            try capture("intended-collinear-corners-before-verdict")
            let xs = labels.map { app.staticTexts[$0].frame.midX }
            print("[QD-PhotoBoundary] actual AX corner x=\(xs); model coordinates are not exposed")
            try require((xs.max()! - xs.min()!) <= 0.01, "AX centres are not collinear; input precision unresolved, not a product rejection failure")
            let next = app.buttons.matching(identifier: "下一步")
            try require(next.count == 1, "One actual calibration Next required")
            try require(!next.firstMatch.isEnabled, "Intended degenerate input still enabled: preserve evidence; AX precision does not prove actual model singularity")
            try require(app.buttons["重新选图"].exists && !app.staticTexts["已标 0 颗"].exists, "Must remain on calibration without entering marking")
            try capture("verified-calibration-disabled-for-intended-collinear-input")
        } catch { try capture("failure-before-cleanup"); throw error }
    }
    private func ballRoot(_ key: String) throws -> XCUIElement {
        // Archived SceneKit AX has outer semantic key before same-key mesh descendants.
        // Hidden old mesh descendants retain small frames: never assert their global absence.
        let q = app.descendants(matching: .any).matching(identifier: key)
        try require(q.count > 0, "Actual semantic ball root missing: " + key)
        let root = q.firstMatch
        try require(root.frame.width > 0 && root.frame.height > 0 && root.frame.width < 30 && root.frame.height < 30 && app.windows.firstMatch.frame.contains(root.frame), "Actual outer ball root must have ball-sized visible-frame evidence")
        return root
    }
    private func capture(_ stage: String) throws {
        sequence += 1
        let stem = "\(sequence)-\(stage)"
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        try shot.pngRepresentation.write(to: output.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = app.debugDescription
        let text = XCTAttachment(string: ax); text.name = stem + "-AX"; text.lifetime = .keepAlways; add(text)
        try Data(ax.utf8).write(to: output.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
}
