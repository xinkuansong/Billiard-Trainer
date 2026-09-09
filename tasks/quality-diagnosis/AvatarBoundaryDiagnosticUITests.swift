import XCTest

/// Unregistered draft: new offline synthetic-account device, normal picker/crop/upload-error UI.
/// Required observation inputs come from THIS device, never copied photo timestamps/coordinates.
final class AvatarBoundaryDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private var output: URL!
    private let token = UUID().uuidString
    private let fixture = "-v53.authenticatedProfileFixture"
    private var sequence = 0
    private var photoLabel = ""
    private var cancelID = ""
    private var observedFrame = CGRect.zero
    private enum Failure: Error { case requirement(String) }
    private func env(_ key: String) -> String? {
        let values = ProcessInfo.processInfo.environment
        return values[key] ?? values["TEST_RUNNER_" + key]
    }
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil && output != nil { try capture("terminal-unclassified") }
    }

    /// Observation only: leaves the real picker open for evidence, then teardown terminates the app.
    /// Does not require or infer an asset label, thumbnail frame, or cancellation identifier.
    func testDiscoverSyntheticAvatarPickerWithoutSelectingOrUploading() throws {
        try require(env("QD_AVATAR_AUTHORIZATION") == "NEW_DEDICATED_OFFLINE_SYNTHETIC_PHOTO_DEVICE", "New dedicated device and authorized synthetic photo required")
        guard let expected = env("QD_EXPECTED_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              env("SIMULATOR_UDID")?.lowercased() == expected.lowercased()
        else { throw Failure.requirement("Runner must match explicitly authorized new UDID") }
        try require(env("QD_ACCOUNT_API_GUARD") == "SNAPSHOT004_REQUESTDATA_PRETRANSPORT_THROW_VERIFIED", "Orchestrator must verify the installed Debug APIClient fixture guard before mutations")
        guard let path = env("QD_SHOT_DIR"), path.hasPrefix("/") else { throw Failure.requirement("Absolute evidence output required") }
        output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        app = XCUIApplication()
        do {
            try launch(fixtureEnabled: false)
            try until("Initial actual guest required") { self.app.buttons["profile.login"].exists }
            try require(app.buttons["profile.login"].label.contains("游客模式") && !app.buttons["profile.accountHeader"].exists, "Refuse a pre-existing signed-in device")
            try capture("discovery-new-device-guest")
            app.terminate()
            try require(app.wait(for: .notRunning, timeout: 10), "Guest process must stop")
            try launch(fixtureEnabled: true)
            try identity()
            try tap(app.buttons["profile.accountHeader"])
            try until("Actual personal information page") { self.app.navigationBars["个人信息"].exists }
            try defaultAvatar(stage: "discovery-initial-default-avatar")
            try openPicker()
            try capture("discovery-picker-awaiting-human-selector-review")
            // No selection, cancellation, crop, upload, or sandbox cleanup in this method.
        } catch {
            try capture("discovery-failure-before-termination")
            throw error
        }
    }

    func testSyntheticPickerAndCropCancelThenOfflineUploadRestoresDefaultAvatar() throws {
        try require(env("QD_AVATAR_AUTHORIZATION") == "NEW_DEDICATED_OFFLINE_SYNTHETIC_PHOTO_DEVICE", "New dedicated device and authorized synthetic photo required")
        guard let expected = env("QD_EXPECTED_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              env("SIMULATOR_UDID")?.lowercased() == expected.lowercased()
        else { throw Failure.requirement("Runner must match explicitly authorized new UDID") }
        try require(env("QD_ACCOUNT_API_GUARD") == "SNAPSHOT004_REQUESTDATA_PRETRANSPORT_THROW_VERIFIED", "Orchestrator must verify the installed Debug APIClient fixture guard before mutations")
        guard let path = env("QD_SHOT_DIR"), path.hasPrefix("/") else { throw Failure.requirement("Absolute evidence output required") }
        output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        // Store observed selector input now; validate it only after picker capture so missing input retains UI.
        photoLabel = env("QD_AVATAR_SYNTHETIC_PHOTO_LABEL") ?? ""
        cancelID = env("QD_AVATAR_OBSERVED_PICKER_CANCEL_ID") ?? ""
        app = XCUIApplication()
        try launch(fixtureEnabled: false)
        try until("Initial actual guest required") { self.app.buttons["profile.login"].exists }
        try require(app.buttons["profile.login"].label.contains("游客模式") && !app.buttons["profile.accountHeader"].exists, "Refuse a pre-existing signed-in device")
        try capture("new-device-guest")
        app.terminate()
        try require(app.wait(for: .notRunning, timeout: 10), "Guest process must stop")
        try launch(fixtureEnabled: true)
        do {
            try identity()
            try tap(app.buttons["profile.accountHeader"])
            try until("Actual personal information page") { self.app.navigationBars["个人信息"].exists }
            try defaultAvatar(stage: "initial-default-avatar")
            try openPicker()
            try cancelPicker()
            try defaultAvatar(stage: "picker-cancel-default")
            try require(!app.alerts["个人资料未保存"].exists, "Picker cancel must not report upload failure")

            try openPicker()
            try chooseObservedSynthetic()
            try cropPage()
            try capture("first-crop-preview-before-cancel")
            try tapUnique(app.navigationBars["裁切头像"].buttons.matching(identifier: "取消"))
            try until("Crop cancel dismisses") { !self.app.navigationBars["裁切头像"].exists }
            try defaultAvatar(stage: "crop-cancel-default")
            try require(!app.alerts["个人资料未保存"].exists, "Crop cancel must not submit upload")

            try openPicker()
            try chooseObservedSynthetic() // SAME label, no alternate image or business-state reset.
            try cropPage()
            try capture("same-image-second-crop-preview")
            try require(app.launchArguments.contains(fixture), "Only fixed-offline fixture may upload")
            try tapUnique(app.navigationBars["裁切头像"].buttons.matching(identifier: "使用"))
            let failure = app.alerts["个人资料未保存"]
            try until("Real upload failure must be visible") { failure.exists }
            try capture("upload-failure-before-dismiss-or-cleanup")
            try tapUnique(failure.buttons.matching(identifier: "知道了"))
            try until("Failure explanation closes") { !failure.exists }
            try defaultAvatar(stage: "offline-failure-default-restored")
            try tap(app.navigationBars.buttons["BackButton"])
            try identity()
            try tap(app.buttons["profile.accountHeader"])
            try defaultAvatar(stage: "reentered-default-and-idle")
            // Demonstrate actual operability after rollback, not only enabled AX.
            try openPicker()
            try cancelPicker()
            try defaultAvatar(stage: "verified-picker-operable-after-failure")
        } catch {
            try capture("failure-before-termination")
            throw error
        }
    }
    private func launch(fixtureEnabled: Bool) throws {
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES", "-v50.inMemoryStore", "-forceNonPremium", "-v51.followSystemAppearance"]
        if fixtureEnabled { app.launchArguments.append(fixture) }
        app.launch()
        try require(app.wait(for: .runningForeground, timeout: 15), "App foreground required")
        try tap(app.tabBars.buttons["我的"])
    }
    private func identity() throws {
        try until("Exact synthetic header required") { self.app.buttons["profile.accountHeader"].exists }
        try require(app.launchArguments.contains(fixture) && app.buttons["profile.accountHeader"].label == "个人信息，服务端球友" && !app.buttons["profile.login"].exists, "Only verified synthetic identity may continue")
    }
    private func defaultAvatar(stage: String) throws {
        try until("Personal information page and idle picker required") {
            self.app.navigationBars["个人信息"].exists && self.app.buttons["personalInfo.avatarPicker"].exists && self.app.buttons["personalInfo.avatarPicker"].isEnabled
        }
        let picker = app.buttons["personalInfo.avatarPicker"]
        let defaults = picker.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "默认头像"))
        try require(picker.label.contains("默认头像") || defaults.count > 0, "Default avatar must have actual source-backed accessibility identity; retain screenshot if merged differently")
        try require(!app.buttons["personalInfo.avatarDelete"].exists, "No uploaded image may remain after cancellation/failure")
        try require(app.buttons["personalInfo.displayNameButton"].label.contains("服务端球友"), "Original profile name must remain")
        try capture(stage) // Visual review still required; AX is not pixel proof of default rendering.
    }
    private func openPicker() throws {
        try require(app.launchArguments.contains(fixture), "Offline fixture required")
        try tap(app.buttons["personalInfo.avatarPicker"])
        try until("Actual system Photos picker identity") { self.app.navigationBars["照片"].exists }
        try capture("system-picker-observation")
    }
    private func cancelPicker() throws {
        try require(!cancelID.isEmpty, "Provide THIS avatar picker observation's Cancel identifier; do not guess unknown UI")
        let controls = app.navigationBars["照片"].buttons.matching(identifier: cancelID)
        try tapUnique(controls)
        try until("System picker must dismiss normally") { !self.app.navigationBars["照片"].exists }
    }
    private func chooseObservedSynthetic() throws {
        try require(!photoLabel.isEmpty, "Provide unique synthetic photo label observed on THIS device")
        guard let raw = env("QD_AVATAR_SYNTHETIC_PHOTO_FRAME_JSON"),
              let frame = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Double],
              let x = frame["x"], let y = frame["y"], let width = frame["width"], let height = frame["height"]
        else { throw Failure.requirement("Observed thumbnail frame JSON x/y/width/height required") }
        try require([x,y,width,height].allSatisfy(\.isFinite) && width > 0 && height > 0, "Observed frame must be finite/nonempty")
        observedFrame = CGRect(x: x, y: y, width: width, height: height)
        let images = app.images.matching(NSPredicate(format: "identifier == %@ AND label == %@", "PXGGridLayout-Info", photoLabel))
        try require(images.count == 1, "Exactly one observed synthetic asset must match; no index fallback")
        let image = images.firstMatch, frameNow = images.firstMatch.frame
        try capture("synthetic-thumbnail-before-selection")
        // Require the actual previously reviewed frame, allowing only rounding of AX points.
        try require(abs(frameNow.minX-observedFrame.minX) <= 1 && abs(frameNow.minY-observedFrame.minY) <= 1 && abs(frameNow.width-observedFrame.width) <= 1 && abs(frameNow.height-observedFrame.height) <= 1, "Thumbnail geometry changed; reobserve rather than guessing")
        try require(!frameNow.isEmpty && app.windows.firstMatch.frame.contains(frameNow) && frameNow.minY >= app.navigationBars["照片"].frame.maxY, "Full synthetic thumbnail must be inside the actual picker viewport")
        // Prior Photo observation found Image hittable unreliable. Use only its unique verified actual frame.
        image.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        try until("Selected photo must leave system picker") { !self.app.navigationBars["照片"].exists }
    }
    private func cropPage() throws {
        try until("Actual crop sheet required") { self.app.navigationBars["裁切头像"].exists }
        let preview = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "头像裁切预览")).firstMatch
        try require(preview.exists && !preview.frame.isEmpty, "Actual crop preview required, not only toolbar")
        try require(app.sliders["avatarCrop.zoom"].exists, "Source-backed crop control must be present")
    }
    private func tapUnique(_ query: XCUIElementQuery) throws { try require(query.count == 1, "Expected one exact control"); try tap(query.firstMatch) }
    private func tap(_ element: XCUIElement) throws {
        try until("Actual control must be enabled and hittable") { element.exists && element.isEnabled && element.isHittable }
        try require(!element.frame.isEmpty && app.windows.firstMatch.frame.contains(element.frame), "Control must be fully within actual window")
        element.tap()
    }
    private func until(_ message: String, _ body: @escaping () -> Bool) throws {
        try require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in body() }, object: nil)], timeout: 15) == .completed, message)
    }
    private func require(_ value: Bool, _ message: String) throws { if !value { throw Failure.requirement(message) } }
    private func capture(_ stage: String) throws {
        sequence += 1
        let stem = "avatar-boundary-\(token)-\(sequence)-\(stage)"
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        try shot.pngRepresentation.write(to: output.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = app.debugDescription
        let text = XCTAttachment(string: ax); text.name = stem + "-AX"; text.lifetime = .keepAlways; add(text)
        try Data(ax.utf8).write(to: output.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
}
