import XCTest

/// One launch on the previously authorized, subsequently disabled Allow guest.
/// OS pending-request verification is a separate hosted method run by the orchestrator afterwards.
final class NotificationTimeDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private var output: URL!
    private var trace: [[String: Any]] = []
    private var discrepancies: [String] = []
    private let token = UUID().uuidString
    private var captureIndex = 0
    private enum Failure: Error { case precondition(String), target(String) }
    private func env(_ key: String) -> String? {
        let values = ProcessInfo.processInfo.environment
        return values[key] ?? values["TEST_RUNNER_" + key]
    }
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil && output != nil { try capture("teardown-unclassified") }
    }

    func testAuthorizedReminderSingleMinuteAdjustmentPersists2017() throws {
        try require(env("QD_NOTIFICATION_TIME_AUTHORIZATION") == "EXISTING_ALLOW_GUEST_AUTHORIZED_DISABLED_OS_VERIFIED", "Explicit prior OS authorized/disabled/count0 verification required")
        let expected = "CB246F30-E917-492B-B0C4-511F473D8C15"
        try require(env("QD_EXPECTED_DEVICE_UDID")?.uppercased() == expected && env("SIMULATOR_UDID")?.uppercased() == expected, "Only the explicitly authorized original Allow UDID may run")
        try require(TimeZone.current.identifier == "Asia/Shanghai", "Keep the observed timezone; do not modify the clock")
        guard let directory = env("QD_SHOT_DIR"), directory.hasPrefix("/") else { throw Failure.precondition("Absolute evidence directory required") }
        output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES", "-v50.inMemoryStore", "-forceNonPremium", "-v51.followSystemAppearance"]
        app.launch()
        try require(app.wait(for: .runningForeground, timeout: 15), "Single launch must reach foreground")
        do {
            try tap(app.tabBars.buttons["我的"])
            try until("Actual guest required") { self.app.buttons["profile.login"].exists }
            try require(app.buttons["profile.login"].label.contains("游客模式") && !app.buttons["profile.accountHeader"].exists, "No real account or synthetic authenticated fixture")
            try openGoal()
            let toggle = app.switches["trainingGoal.reminderEnabled"]
            try reveal(toggle)
            try until("Start disabled, already authorized") { toggle.exists && toggle.isEnabled && toggle.value as? String == "0" }
            try allowed()
            try capture("initial-authorized-disabled")
            try tap(toggle)
            try until("Normal enable must finish") { toggle.exists && toggle.isEnabled && toggle.value as? String == "1" }
            try allowed()
            let picker = app.datePickers["trainingGoal.reminderTime"]
            try reveal(picker)
            try until("Enabled real DatePicker required") { picker.exists && picker.isEnabled }
            let initial = try timeNode(picker)
            try require(parseTime(initial.value as? String) != nil, "Initial displayed time must be strictly readable")
            log("initial-time", ["raw": initial.value as? String ?? "nil"])
            try capture("enabled-before-picker")
            try tap(picker)
            try require(app.pickerWheels.count == 2, "Exactly two actual wheels required")
            let hour = app.pickerWheels.element(boundBy: 0)
            let minute = app.pickerWheels.element(boundBy: 1)
            try require(hour.isEnabled && minute.isEnabled && hour.isHittable && minute.isHittable, "Both wheels must be actionable")
            try require(!hour.frame.isEmpty && !minute.frame.isEmpty && hour.frame.midX < minute.frame.midX && hour.frame.intersects(CGRect(x: hour.frame.minX, y: minute.frame.minY, width: hour.frame.width, height: minute.frame.height)), "Observed left hour/right minute wheel geometry required")
            try require(number(hour.value as? String, suffix: "点", range: 0...23) != nil && number(minute.value as? String, suffix: "分钟", range: 0...59) != nil, "Only exact numeric values with optional known units allowed")
            try capture("opened-two-wheels")
            if number(hour.value as? String, suffix: "点", range: 0...23) != 20 {
                log("adjust-hour-once", ["requested": "20"])
                hour.adjust(toPickerWheelValue: "20")
            } else { log("hour-already20-no-adjust", [:]) }
            let hourState = try stableWheels(picker: picker, stage: "after-hour")
            if let pair = hourState, pair.0 == 20 {
                log("adjust-minute-once", ["requested": "17"])
                minute.adjust(toPickerWheelValue: "17")
                let final = try stableWheels(picker: picker, stage: "after-minute")
                if final?.0 != 20 || final?.1 != 17 { mismatch("Minute adjustment did not produce stable20/17") }
            } else {
                mismatch("Hour did not stabilize at20; minute not adjusted without its prerequisite")
            }
            try capture(discrepancies.isEmpty ? "wheels2017-observed" : "failed-input-wheels")
            try noUnexpectedAlerts()
            let dismiss = app.buttons.matching(identifier: "PopoverDismissRegion")
            try require(dismiss.count == 1, "Unique actual popover dismiss control required")
            try tap(dismiss.firstMatch)
            try until("Wheels must close normally") { self.app.pickerWheels.count == 0 }
            let closed = try stableTime(picker: picker, stage: "closed")
            if closed != "20:17" { mismatch("Closed time is not stable20:17") }
            try capture(discrepancies.isEmpty ? "closed2017" : "failed-target-closed-observation")
            try tap(app.navigationBars.buttons["BackButton"])
            try until("Normal profile return") { !self.app.navigationBars["训练目标"].exists && self.app.buttons["profile.login"].exists }
            try openGoal()
            try allowed()
            try until("Reminder must remain enabled after reentry") { toggle.exists && toggle.isEnabled && toggle.value as? String == "1" }
            try reveal(picker)
            let reentered = try stableTime(picker: picker, stage: "reentered")
            if reentered != "20:17" { mismatch("Reentered time is not stable20:17") }
            try capture(discrepancies.isEmpty ? "UI2017-await-independent-OS" : "failed-target-reentry-OS-still-required")
            if !discrepancies.isEmpty {
                let reason = discrepancies.joined(separator: "; ")
                XCTFail(reason)
                throw Failure.target(reason)
            }
        } catch {
            try capture("failure-before-termination")
            throw error
        }
    }

    // Sampling cadence is bounded by a monotonic clock; waiting alone never constitutes success.
    private func stableWheels(picker: XCUIElement, stage: String) throws -> (Int, Int)? {
        var previous: String?, previousTime = -Double.infinity
        var answer: (Int, Int)?, fatal: String?
        let predicate = NSPredicate { _, _ in
            let now = ProcessInfo.processInfo.systemUptime
            guard now - previousTime >= 0.5 else { return false }
            previousTime = now
            guard self.app.pickerWheels.count == 2 else { fatal = "Wheel collection changed during observation"; return true }
            let h = self.app.pickerWheels.element(boundBy: 0), m = self.app.pickerWheels.element(boundBy: 1)
            let hr = h.value as? String, mr = m.value as? String
            self.log(stage, ["hourRaw": hr ?? "nil", "minuteRaw": mr ?? "nil", "pickerEnabled": picker.isEnabled])
            guard let hour = self.number(hr, suffix: "点", range: 0...23), let minute = self.number(mr, suffix: "分钟", range: 0...59) else { fatal = "Unparseable wheel value"; return true }
            let key = "\(hour):\(minute)"
            if picker.isEnabled && h.isEnabled && m.isEnabled {
                if previous == key { answer = (hour, minute); return true }
                previous = key
            } else { previous = nil }
            return false
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 8)
        if let fatal { throw Failure.precondition(fatal) }
        try noUnexpectedAlerts()
        return result == .completed ? answer : nil
    }
    private func stableTime(picker: XCUIElement, stage: String) throws -> String? {
        var previous: String?, previousTime = -Double.infinity, answer: String?, fatal: String?
        let predicate = NSPredicate { _, _ in
            let now = ProcessInfo.processInfo.systemUptime
            guard now - previousTime >= 0.5 else { return false }
            previousTime = now
            do {
                let node = try self.timeNode(picker)
                let raw = node.value as? String
                self.log(stage, ["raw": raw ?? "nil", "pickerEnabled": picker.isEnabled])
                guard let value = self.parseTime(raw) else { fatal = "Unparseable displayed time"; return true }
                if picker.isEnabled {
                    if previous == value { answer = value; return true }
                    previous = value
                } else { previous = nil }
            } catch { fatal = String(describing: error); return true }
            return false
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 8)
        if let fatal { throw Failure.precondition(fatal) }
        try noUnexpectedAlerts()
        return result == .completed ? answer : nil
    }
    private func number(_ raw: String?, suffix: String, range: ClosedRange<Int>) -> Int? {
        guard let raw, raw.range(of: "^[0-9]{1,2}(" + suffix + ")?$", options: .regularExpression) != nil else { return nil }
        let digits = raw.hasSuffix(suffix) ? String(raw.dropLast(suffix.count)) : raw
        guard let result = Int(digits), range.contains(result) else { return nil }
        return result
    }
    private func parseTime(_ raw: String?) -> String? {
        guard let raw, raw.range(of: "^[0-9]{1,2}:[0-9]{2}$", options: .regularExpression) != nil else { return nil }
        let parts = raw.split(separator: ":")
        guard let h = Int(parts[0]), let m = Int(parts[1]), (0...23).contains(h), (0...59).contains(m) else { return nil }
        return String(format: "%02d:%02d", h, m)
    }
    private func timeNode(_ picker: XCUIElement) throws -> XCUIElement {
        let candidates = picker.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "时间选择器")).allElementsBoundByIndex.filter { $0.value as? String != nil }
        try require(candidates.count == 1, "Exactly one readable time node required, no assumed AX type")
        return candidates[0]
    }
    private func openGoal() throws {
        let row = app.staticTexts["训练目标"].firstMatch
        try reveal(row); try tap(row)
        try until("Actual goal page") { self.app.navigationBars["训练目标"].exists }
    }
    private func allowed() throws {
        try noUnexpectedAlerts()
        let status = app.staticTexts["trainingGoal.reminderAuthorization"]
        try until("Previously allowed OS status must remain visible") { status.exists && status.label == "系统通知权限已开启" }
    }
    private func noUnexpectedAlerts() throws {
        try require(app.alerts.count == 0 && XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.count == 0, "Unexpected alert: do not act on a new permission choice")
    }
    private func reveal(_ element: XCUIElement) throws {
        for _ in 0..<12 {
            let window = app.windows.firstMatch.frame
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : window.minY
            let bottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : window.maxY
            if element.exists && element.isHittable && !element.frame.isEmpty && window.contains(element.frame) && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            let candidates = app.scrollViews.allElementsBoundByIndex.filter { $0.frame.height > $0.frame.width && $0.frame.width > window.width * 0.8 }
            try require(candidates.count == 1, "Unique actual vertical scroll container required")
            let scroll = candidates[0], upper = max(top, candidates[0].frame.minY), lower = min(bottom, candidates[0].frame.maxY)
            try require(lower > upper, "Usable viewport required")
            let delta = (lower - upper) / 8, direction: CGFloat = element.exists && element.frame.minY < upper ? -1 : 1
            let origin = scroll.coordinate(withNormalizedOffset: .zero), center = (lower + upper) / 2 - scroll.frame.minY
            origin.withOffset(CGVector(dx: scroll.frame.width / 2, dy: center + direction * delta / 2)).press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: scroll.frame.width / 2, dy: center - direction * delta / 2)))
        }
        throw Failure.precondition("Bounded reveal failed; no guessed screen tap")
    }
    private func tap(_ element: XCUIElement) throws {
        try noUnexpectedAlerts()
        try until("Actual control must be actionable") { element.exists && element.isEnabled && element.isHittable }
        element.tap()
    }
    private func until(_ message: String, _ body: @escaping () -> Bool) throws {
        try require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in body() }, object: nil)], timeout: 12) == .completed, message)
    }
    private func require(_ value: Bool, _ message: String) throws { if !value { throw Failure.precondition(message) } }
    private func mismatch(_ message: String) { discrepancies.append(message); log("FAILED-TARGET", ["reason": message]) }
    private func log(_ stage: String, _ values: [String: Any]) {
        var entry = values; entry["stage"] = stage; entry["uptime"] = ProcessInfo.processInfo.systemUptime
        trace.append(entry); print("[QD-NotificationTime] \(entry)")
    }
    private func capture(_ stage: String) throws {
        captureIndex += 1
        let stem = "notification-time-\(token)-\(captureIndex)-\(stage)"
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        try shot.pngRepresentation.write(to: output.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = app.debugDescription + "\nSYSTEM ALERTS\n" + XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.debugDescription
        let text = XCTAttachment(string: ax); text.name = stem + "-AX"; text.lifetime = .keepAlways; add(text)
        try Data(ax.utf8).write(to: output.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
        let data = try JSONSerialization.data(withJSONObject: ["trace": trace, "targetDiscrepancies": discrepancies], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: output.appendingPathComponent(stem + ".json"), options: .withoutOverwriting)
    }
}
