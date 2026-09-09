import XCTest

/// Observation only: normal FreePlay entry -> break.entry -> raw picker PNG/AX.
/// No picker selection, rack creation, shot, confirmation, or inferred L4 pass.
final class BreakModeObservationDiagnosticUITests: XCTestCase {
    private let expectedDevice = "9DC47676-D81A-4F3D-AF31-352180B69344"
    private var app: XCUIApplication?
    private var output: URL?
    private var sequence = 0
    private struct Stop: Error { let reason: String }

    private func setting(_ key: String) -> String? {
        let values = ProcessInfo.processInfo.environment
        return values[key] ?? values["TEST_RUNNER_" + key]
    }
    override func setUpWithError() throws {
        continueAfterFailure = false
        try require(setting("QD_BREAK_MODE_AUTH") == "NEW_EMPTY_BREAK_MODE_DEVICE", "Dedicated new guest device authorization required")
        try require(setting("QD_BREAK_MODE_DEVICE_UDID")?.uppercased() == expectedDevice &&
                    ProcessInfo.processInfo.environment["SIMULATOR_UDID"]?.uppercased() == expectedDevice,
                    "Dedicated break-mode observation device mismatch")
        guard let root = setting("QD_SHOT_DIR"), root.hasPrefix("/"), root != "/" else {
            throw Stop(reason: "Absolute evidence root required")
        }
        let leaf = URL(fileURLWithPath: root, isDirectory: true)
            .appendingPathComponent("break-mode-observation-" + UUID().uuidString, isDirectory: true)
        try require(!FileManager.default.fileExists(atPath: leaf.path), "Refuse existing observation evidence")
        try FileManager.default.createDirectory(at: leaf, withIntermediateDirectories: true)
        output = leaf
    }

    func testObservationNormalFreePlayBreakEntryPickerForAXReview() throws {
        let application = XCUIApplication()
        app = application
        do {
            try require(application.state == .notRunning, "New dedicated App must not already be running")
            application.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                "-hasCompletedOnboarding", "YES", "-v50.inMemoryStore", "-v51.followSystemAppearance"]
            application.launch()
            try require(application.wait(for: .runningForeground, timeout: 20), "Single normal launch did not reach foreground")
            try tab("我的", in: application)
            let login = application.buttons["profile.login"]
            try require(login.waitForExistence(timeout: 12) && login.label.contains("游客模式") &&
                        !application.buttons["profile.accountHeader"].exists, "Actual normal guest required")
            try capture("guest-before-normal-entry", in: application)

            try tab("练习", in: application)
            try tap(application.buttons["angleHomeTab_打"])
            let card = application.buttons["自由击球"].firstMatch
            try revealHomeCard(card, in: application)
            try capture("normal-freeplay-card", in: application)
            try tap(card)
            try require(application.navigationBars["自由击球"].waitForExistence(timeout: 20), "Normal FreePlay navigation title missing")
            let strike = application.buttons["击球"].firstMatch
            try ready(strike)
            let replay = application.buttons["回放"].firstMatch
            let redo = application.buttons["重打"].firstMatch
            try require(replay.exists && !replay.isEnabled && redo.exists && !redo.isEnabled, "Fresh normal board must have no previous shot")
            let entry = application.buttons["break.entry"]
            try ready(entry)
            try require(!entry.frame.isEmpty && application.windows.firstMatch.frame.contains(entry.frame), "Actual break.entry must be fully on screen")
            try capture("freeplay-before-break-entry", in: application)
            let tapUptime = ProcessInfo.processInfo.systemUptime
            try tap(entry) // Exactly one known normal opening action; no guessed sheet children.
            try require(application.wait(for: .runningForeground, timeout: 10), "App left foreground after entry tap")
            try capture("after-break-entry-picker-observation", in: application)
            let record: [String: Any] = [
                "classification": "observation-only", "device": expectedDevice,
                "entry": "normal practice -> 打 -> 自由击球 -> break.entry", "breakEntryTapCount": 1,
                "tapUptime": tapUptime, "captureCompletedUptime": ProcessInfo.processInfo.systemUptime,
                "requiredReview": ["actual picker opened", "actual game option AX types and identifiers", "visible option geometry"],
                "coverageVerdict": "pending PNG/AX review; no game selected, rack/seed change, shot or delivery tested"
            ]
            try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                .write(to: try XCTUnwrap(output).appendingPathComponent("observation-contract.json"), options: .withoutOverwriting)
        } catch {
            do { try capture("failure-before-termination", in: application) }
            catch let evidenceError { XCTFail("Failure evidence write failed: \(evidenceError)"); throw evidenceError }
            throw error
        }
    }

    override func tearDownWithError() throws {
        guard let app else { return }
        defer { app.terminate() }
        if output != nil { try capture("terminal-before-termination", in: app) }
        // End this observation process, without guessing sheet dismissal controls.
    }
    private func tab(_ name: String, in app: XCUIApplication) throws {
        let item = app.tabBars.buttons[name]
        try tap(item)
        let predicate = NSPredicate(format: "selected == true")
        try require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: item)], timeout: 10) == .completed,
                    "Actual selected tab required: \(name)")
    }
    private func ready(_ element: XCUIElement) throws {
        let predicate = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        try require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 15) == .completed,
                    "Action not ready: \(element)")
    }
    private func tap(_ element: XCUIElement) throws { try ready(element); element.tap() }
    private func revealHomeCard(_ card: XCUIElement, in app: XCUIApplication) throws {
        let tabs = app.tabBars.firstMatch
        try require(tabs.waitForExistence(timeout: 10), "Normal home TabBar required")
        for step in 0...4 {
            let window = app.windows.firstMatch.frame
            let candidates = app.scrollViews.allElementsBoundByIndex.filter {
                $0.buttons.matching(identifier: "自由击球").count == 1
            }
            try require(candidates.count == 1, "Unique content ScrollView containing actual FreePlay card")
            var safe = candidates[0].frame.intersection(window)
            safe.size.height = min(safe.maxY, tabs.frame.minY) - safe.minY
            try require(safe.height > 150, "No usable content viewport")
            if card.exists && !card.frame.isEmpty && safe.contains(card.frame) && card.isHittable { return }
            if step == 4 { break }
            let rect = candidates[0].frame.intersection(safe).insetBy(dx: 12, dy: 12)
            try require(rect.height > 120 && rect.width > 100, "Invalid scroll intersection")
            if card.exists && !card.frame.isEmpty {
                try require(card.frame.height <= rect.height, "Card cannot fully fit; no repeated reveal")
            }
            let base = app.coordinate(withNormalizedOffset: .zero)
            let upper = base.withOffset(CGVector(dx: rect.midX, dy: rect.minY + rect.height * 0.25))
            let lower = base.withOffset(CGVector(dx: rect.midX, dy: rect.minY + rect.height * 0.75))
            if card.exists && card.frame.minY < safe.minY { upper.press(forDuration: 0.05, thenDragTo: lower) }
            else { lower.press(forDuration: 0.05, thenDragTo: upper) }
        }
        throw Stop(reason: "Normal freeplay card not fully exposed after bounded reveal")
    }
    private func capture(_ stage: String, in app: XCUIApplication) throws {
        let folder = try XCTUnwrap(output)
        sequence += 1
        let stem = "\(sequence)-\(stage)"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let path = folder.appendingPathComponent(stem + ".png")
        try png.write(to: path, options: .withoutOverwriting)
        try require(try Data(contentsOf: path) == png, "PNG readback mismatch")
        let shot = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        shot.name = stem; shot.lifetime = .keepAlways; add(shot)
        let ax = app.debugDescription
        try Data(ax.utf8).write(to: folder.appendingPathComponent(stem + "-AX.txt"), options: .withoutOverwriting)
        let text = XCTAttachment(string: ax); text.name = stem + "-AX"; text.lifetime = .keepAlways; add(text)
    }
    private func require(_ condition: Bool, _ message: String, file: StaticString = #filePath, line: UInt = #line) throws {
        guard condition else { XCTFail(message, file: file, line: line); throw Stop(reason: message) }
    }
}
