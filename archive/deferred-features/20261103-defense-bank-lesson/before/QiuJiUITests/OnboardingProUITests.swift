import XCTest
import StoreKitTest

final class OnboardingProUITests: XCTestCase {

    @MainActor
    func testNativeIntroStyleSwitchingAndReference() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-intro.styles", "-v50.inMemoryStore"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        let viewport = app.descendants(matching: .any)["introLab.nativeViewport"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 30))
        XCTAssertTrue(NSPredicate(format: "value BEGINSWITH 'ready;'").evaluate(with: viewport))
        let identity = try XCTUnwrap(viewport.value as? String)
        let menu = app.buttons["introLab.styles"]
        for orientation in (UIDevice.current.userInterfaceIdiom == .pad ? [UIDeviceOrientation.portrait, .landscapeLeft] : [.portrait]) {
            XCUIDevice.shared.orientation = orientation
            for style in ["minimal", "precision", "cinematic", "editorial", "training", "reference"] {
                menu.tap()
                let option = app.buttons["introLab.style.\(style)"]
                XCTAssertTrue(option.waitForExistence(timeout: 5))
                option.tap()
                XCTAssertTrue(app.staticTexts["introLab.title"].waitForExistence(timeout: 5))
                XCTAssertEqual(menu.value as? String, style)
                XCTAssertEqual(viewport.value as? String, identity, "Switching must preserve the same scene and SCNView")
                XCTAssertTrue(app.buttons["introLab.continue"].isHittable)
                if style != "reference", app.frame.height >= 800 {
                    XCTAssertLessThanOrEqual(app.staticTexts["introLab.explanation"].frame.maxY, app.buttons["introLab.continue"].frame.minY - 24, "Copy must fit above the fixed footer")
                }
                try introLabCapture("\(orientation == .portrait ? "portrait" : "landscape")-\(style)", app: app)
            }
        }
        app.buttons["introLab.continue"].tap()
        XCTAssertTrue(app.buttons["introLab.return"].waitForExistence(timeout: 5))
        app.buttons["introLab.return"].tap()
        menu.tap()
        app.buttons["introLab.original"].tap()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 6))
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        XCTAssertEqual(viewport.value as? String, identity)
        app.buttons["introLab.skip"].tap()
        XCTAssertTrue(app.buttons["introLab.return"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNativeIntroAccessibilityText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-intro.styles", "-v50.inMemoryStore", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["introLab.styles"].waitForExistence(timeout: 30))
        for style in ["minimal", "precision", "cinematic", "editorial", "training"] {
            app.buttons["introLab.styles"].tap()
            app.buttons["introLab.style.\(style)"].tap()
            XCTAssertTrue(app.staticTexts["introLab.title"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["introLab.continue"].isHittable)
            try introLabCapture("large-text-\(style)", app: app)
            let scroll = app.scrollViews.firstMatch
            for _ in 0..<3 { scroll.swipeUp() }
            try introLabCapture("large-text-\(style)-scrolled", app: app)
            for _ in 0..<3 { scroll.swipeDown() }
        }
    }

    @MainActor
    private func introLabCapture(_ name: String, app: XCUIApplication) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let env = ProcessInfo.processInfo.environment
        guard let path = env["V50_SHOT_DIR"] ?? env["TEST_RUNNER_V50_SHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(to: dir.appendingPathComponent(name + ".png"))
        let elements = ["title": app.staticTexts["introLab.title"], "button": app.buttons["introLab.continue"], "scene": app.descendants(matching: .any)["introLab.nativeViewport"]]
        let frames = elements.mapValues { e in ["x": e.frame.minX, "y": e.frame.minY, "width": e.frame.width, "height": e.frame.height] }
        try JSONSerialization.data(withJSONObject: frames, options: [.prettyPrinted, .sortedKeys]).write(to: dir.appendingPathComponent(name + "-frames.json"))
    }

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testFirstRunProfileSavePreservesExistingGuestAndReturnsToPersonalInfo() {
        let fixture = "-firstRun.fixture=\(UUID().uuidString)"
        let app = XCUIApplication.launchClean(extraArgs: [fixture, "-v50.inMemoryStore"])
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 15))
        app.buttons["onboarding.skip"].tap()
        for id in ["chinese8", "zhuifen", "both", "other"] {
            XCTAssertTrue(app.buttons["firstRun.sport.\(id)"].exists)
        }
        capture("r6-profile-sport")
        app.buttons["firstRun.sport.zhuifen"].tap()
        XCTAssertTrue(app.buttons["firstRun.years.oneToThree"].waitForExistence(timeout: 5))
        capture("r6-profile-years")
        app.buttons["firstRun.back"].tap()
        XCTAssertTrue(app.buttons["firstRun.sport.zhuifen"].waitForExistence(timeout: 5))
        app.buttons["firstRun.sport.zhuifen"].tap()
        app.buttons["firstRun.years.oneToThree"].tap()
        XCTAssertTrue(app.buttons["firstRun.gender.male"].waitForExistence(timeout: 5))
        capture("r6-profile-gender")
        app.buttons["firstRun.gender.male"].tap()
        XCTAssertTrue(app.buttons["firstRun.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["firstRun.birthday"].exists)
        capture("r6-profile-birthday")
        app.buttons["firstRun.save"].tap()
        // iPad exposes top navigation without a TabBar; verify the destination's content.
        XCTAssertTrue(app.buttons["trainingHome.dailyClearance"].waitForExistence(timeout: 15))
        capture("r6-real-home")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["trainingHome.dailyClearance"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["onboarding.skip"].exists)
        app.terminate()
    }

    @MainActor
    func testFirstRunSkipResumeAndLargeText() {
        let fixture = "-firstRun.fixture=\(UUID().uuidString)"
        let app = XCUIApplication.launchClean(extraArgs: [fixture, "-v50.inMemoryStore",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 15))
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(app.buttons["firstRun.sport.other"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["firstRun.sport.other"].waitForExistence(timeout: 15))
        for _ in 0..<3 { app.buttons["firstRun.skip"].tap() }
        XCTAssertTrue(app.buttons["firstRun.save"].waitForExistence(timeout: 5))
        capture("r6-large-birthday")
        app.buttons["firstRun.skip"].tap()
        XCTAssertTrue(app.buttons["trainingHome.dailyClearance"].waitForExistence(timeout: 15))
        app.terminate()
    }

    @MainActor
    func testTourPresentation() {
        let app = XCUIApplication.launchClean(extraArgs: ["-intro.preview", "-v54.forceLight", "-v50.inMemoryStore"])
        for index in 0..<6 {
            XCTAssertTrue(app.staticTexts["onboarding.title.\(index)"].waitForExistence(timeout: 8))
            let art = app.descendants(matching: .any)["onboarding.image.\(index)"].firstMatch
            XCTAssertTrue(art.exists)
            XCTAssertTrue(app.buttons["onboarding.continue"].isHittable)
            XCTAssertLessThanOrEqual(art.frame.maxX, app.frame.maxX + 1)
            XCTAssertGreaterThanOrEqual(art.frame.minX, app.frame.minX - 1)
            capture("r6-intro-\(index)")
            if index < 5 { app.buttons["onboarding.continue"].tap() }
        }
        app.buttons["onboarding.back"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.title.4"].waitForExistence(timeout: 5))
        app.terminate()
    }

    @MainActor
    func testButtonAndSwipePagingAndConfirmedDefaultBirthday() {
        let fixture = "-firstRun.fixture=\(UUID().uuidString)"
        let app = XCUIApplication.launchClean(extraArgs: [fixture, "-auth.deviceGuestID", UUID().uuidString,
            "-v50.inMemoryStore"])
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["onboarding.title.0"].waitForExistence(timeout: 15))
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["onboarding.title.1"].waitForExistence(timeout: 5))
        app.swipeRight()
        XCTAssertTrue(app.staticTexts["onboarding.title.0"].waitForExistence(timeout: 5))
        app.swipeRight()
        XCTAssertTrue(app.staticTexts["onboarding.title.0"].exists, "First page must not go before the beginning")
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.title.1"].waitForExistence(timeout: 5))
        capture("button-page-forward")
        app.buttons["onboarding.back"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.title.0"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(app.buttons["firstRun.sport.other"].waitForExistence(timeout: 5))
        app.swipeLeft()
        XCTAssertTrue(app.buttons["firstRun.years.oneToThree"].waitForExistence(timeout: 5))
        app.swipeRight()
        XCTAssertTrue(app.buttons["firstRun.sport.other"].waitForExistence(timeout: 5))
        capture("swipe-profile-back-arrow")
        app.swipeUp()
        app.buttons["firstRun.sport.other"].tap()
        app.buttons["firstRun.years.oneToThree"].tap()
        app.buttons["firstRun.gender.female"].tap()
        XCTAssertTrue(app.staticTexts["firstRun.age"].waitForExistence(timeout: 5))
        let calendar = Calendar(identifier: .gregorian)
        let birth = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1))!
        let age = calendar.dateComponents([.year], from: birth, to: Date.now).year!
        XCTAssertEqual(app.staticTexts["firstRun.age"].label, "\(age) 岁")
        let wheels = app.datePickers["firstRun.birthday"].pickerWheels
        let values = wheels.allElementsBoundByIndex.compactMap { $0.value as? String }.joined(separator: "|")
        XCTAssertTrue(values.contains("2000"), values)
        capture("birthday-default-2000")
        // Horizontal navigation never confirms a birthday or submits the final step.
        app.swipeLeft()
        XCTAssertTrue(app.buttons["firstRun.save"].exists)
        app.swipeRight()
        XCTAssertTrue(app.buttons["firstRun.gender.female"].waitForExistence(timeout: 5))
        app.swipeLeft()
        XCTAssertTrue(app.datePickers["firstRun.birthday"].waitForExistence(timeout: 5))
        wheels.element(boundBy: 0).swipeUp()
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "2001年")
        XCTAssertTrue(app.buttons["firstRun.save"].exists, "Wheel scrolling must not turn the page")
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "2000年")
        app.buttons["firstRun.save"].tap()
        XCTAssertTrue(app.buttons["trainingHome.dailyClearance"].waitForExistence(timeout: 15))
        app.switchTab(.profile)
        app.staticTexts["个人信息"].tap()
        let row = app.buttons["personalInfo.age"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("\(age) 岁"), row.label)
        row.tap()
        let saved = app.datePickers["personalInfo.birthDatePicker"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        let savedValues = saved.pickerWheels.allElementsBoundByIndex.compactMap { $0.value as? String }.joined(separator: "|")
        XCTAssertTrue(savedValues.contains("2000"), savedValues)
        capture("birthday-saved-personal-info")
    }

    @MainActor
    func testProBrandTwelvePremiumFeatures() throws {
        let session = try storeSession()
        defer { session.clearTransactions() }
        for appearance in ["-v54.forceLight", "-v54.forceDark"] {
            let app = XCUIApplication.launchClean(extraArgs: [appearance, "-v50.inMemoryStore"])
            defer { app.terminate() }
            app.switchTab(.profile)
            let entry = app.buttons["profile.subscription"]
            reveal(entry, in: app)
            entry.tap()
            XCTAssertTrue(app.buttons["subscription.product.com.xinkuan.qiuji.premium.yearly"].waitForExistence(timeout: 15))
            XCTAssertTrue(app.staticTexts["解锁球迹 Pro"].exists)
            capture("brand-purchase-\(appearance)-top")
            verifyBrandFeatures(in: app, scrollID: "subscription.scroll", unlocked: false,
                                prefix: "brand-purchase-\(appearance)")
            app.terminate()
        }
        _ = try session.buyProduct(productIdentifier: "com.xinkuan.qiuji.premium.lifetime")
        XCUIApplication().terminate() // StoreKitTest may launch the app without our route/identity arguments.
        let app = XCUIApplication.launchClean(extraArgs: ["-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-v54.forceLight"])
        defer { app.terminate() }
        app.switchTab(.profile)
        let membership = app.buttons["profile.subscription"]
        reveal(membership, in: app)
        membership.tap()
        XCTAssertTrue(app.staticTexts["已解锁 Pro"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["永久有效"].exists)
        XCTAssertTrue(app.buttons["管理订阅"].exists)
        XCTAssertFalse(app.buttons["subscription.upgradeLifetime"].exists)
        capture("brand-status-top")
        verifyBrandFeatures(in: app, scrollID: "subscription.statusScroll", unlocked: true,
                            prefix: "brand-status")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(membership.waitForExistence(timeout: 6))
        capture("brand-status-return-profile")
    }

    @MainActor
    private func verifyBrandFeatures(in app: XCUIApplication, scrollID: String, unlocked: Bool, prefix: String) {
        let scroll = app.scrollViews[scrollID]
        let ids = ["drills", "plans", "aiming", "atlases", "snake", "position", "three", "safety", "photo", "history", "bank", "diamond"]
        for (index, id) in ids.enumerated() {
            // Match only the explicit identifier inside this scroll view. The string
            // subscript also asks iOS 17 AX for label/placeholder aliases across
            // the whole app, which can flood the injected XCTest diagnostics.
            let row = scroll.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", "subscription.feature.\(id)"))
                .firstMatch
            revealProElement(row, in: app, scrollID: scrollID)
            XCTAssertTrue(row.exists, id)
            XCTAssertTrue(row.isHittable, id)
            let rowFrame = row.frame
            let scrollFrame = scroll.frame
            let label = row.label
            XCTAssertGreaterThanOrEqual(rowFrame.minX, scrollFrame.minX, id)
            XCTAssertLessThanOrEqual(rowFrame.maxX, scrollFrame.maxX, id)
            XCTAssertTrue(label.contains(unlocked ? "PRO · 已解锁" : "PRO"), label)
            XCTAssertFalse(label.contains("免费使用"), label)
            if [1, 3, 5, 7, 9, 11].contains(index) { capture("\(prefix)-row-\(index + 1)") }
        }
    }

    /// Short, reversible drags avoid skipping a tall card at accessibility sizes.
    @MainActor
    private func revealProElement(_ element: XCUIElement, in app: XCUIApplication,
                                  scrollID: String = "subscription.scroll") {
        let scroll = app.scrollViews[scrollID]
        for _ in 0..<80 {
            let top = scroll.frame.minY + 8
            let purchase = app.buttons["subscription.purchase"]
            let bottom = (purchase.exists ? purchase.frame.minY : scroll.frame.maxY) - 8
            let frame = element.frame
            if element.exists && element.isHittable && frame.minY >= top && frame.maxY <= bottom { return }
            // safeAreaInset overlays part of the UIScrollView's accessibility frame.
            // Keep gestures inside the visible body, especially when the CTA wraps.
            let height = bottom - top
            let offset = element.exists && !frame.isEmpty ? frame.midY - (top + bottom) / 2 : height / 3
            let distance = min(max(offset, -height * 0.6), height * 0.6)
            let start: CGFloat = distance >= 0 ? 0.8 : 0.2
            let origin = scroll.coordinate(withNormalizedOffset: .zero)
            let startY = top - scroll.frame.minY + start * height
            origin.withOffset(CGVector(dx: scroll.frame.width / 2, dy: startY))
                .press(forDuration: 0.05,
                       thenDragTo: origin.withOffset(CGVector(dx: scroll.frame.width / 2, dy: startY - distance)),
                       withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTFail("Pro element never became fully visible: \(element.identifier), frame: \(element.frame)")
    }

    @MainActor
    func testProPresentation() throws {
        let session = try storeSession()
        defer { session.clearTransactions() }
        for appearance in ["-v54.forceLight", "-v54.forceDark"] {
            let pro = XCUIApplication.launchClean(extraArgs: ["-subscription.preview", appearance, "-v50.inMemoryStore"])
            let yearly = pro.buttons["subscription.product.com.xinkuan.qiuji.premium.yearly"]
            XCTAssertTrue(yearly.waitForExistence(timeout: 12))
            capture("\(appearance)-pro-top")
            reveal(yearly, in: pro)
            XCTAssertTrue(yearly.isSelected)
            let monthly = pro.buttons["subscription.product.com.xinkuan.qiuji.premium.monthly"]
            monthly.tap()
            XCTAssertTrue(monthly.isSelected)
            XCTAssertFalse(yearly.isSelected)
            let lifetime = pro.buttons["subscription.product.com.xinkuan.qiuji.premium.lifetime"]
            lifetime.tap()
            XCTAssertTrue(lifetime.isSelected)
            XCTAssertTrue(pro.buttons["subscription.purchase"].label.contains("一次性"))
            capture("\(appearance)-pro-plans")
            // The guest's chosen product survives entering and cancelling login.
            pro.buttons["subscription.purchase"].tap()
            let cancelLogin = pro.buttons["暂不登录，匿名使用"]
            XCTAssertTrue(cancelLogin.waitForExistence(timeout: 6))
            cancelLogin.tap()
            XCTAssertTrue(lifetime.waitForExistence(timeout: 6))
            XCTAssertTrue(lifetime.isSelected)
            pro.terminate()
        }
    }

    @MainActor
    func testOptionalTourReturnsToSameAccount() {
        let app = XCUIApplication.launchClean(extraArgs: ["-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-v51.followSystemAppearance"])
        app.switchTab(.profile)
        let identity = app.descendants(matching: .any)["profile.accountHeader"].firstMatch
        XCTAssertTrue(identity.waitForExistence(timeout: 6))
        let originalIdentity = identity.label
        let entry = app.buttons["profile.onboarding"]
        reveal(entry, in: app)
        capture("profile-intro-entry")
        entry.tap()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        for _ in 0..<5 { app.buttons["onboarding.continue"].tap() }
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        app.swipeDown()
        XCTAssertTrue(identity.waitForExistence(timeout: 5))
        XCTAssertEqual(identity.label, originalIdentity, "Tour must not log out or replace an existing account")
        app.terminate()
    }

    @MainActor
    func testStoreKitPurchaseAndRestore() throws {
        try verifyPurchaseAndRestore(product: "monthly", cadence: "每月")
    }

    @MainActor
    func testStoreKitYearlyPurchaseAndRestore() throws {
        try verifyPurchaseAndRestore(product: "yearly", cadence: "每年")
    }

    @MainActor
    func testStoreKitLifetimePurchaseAndRestore() throws {
        try verifyPurchaseAndRestore(product: "lifetime", cadence: "一次性")
    }

    @MainActor
    private func verifyPurchaseAndRestore(product: String, cadence: String) throws {
        let session = try storeSession()
        defer { session.clearTransactions() }
        var app = XCUIApplication.launchClean(extraArgs: ["-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-v51.followSystemAppearance"])
        app.switchTab(.profile)
        let subscription = app.staticTexts["订阅管理"]
        reveal(subscription, in: app)
        subscription.tap()
        let selected = app.buttons["subscription.product.com.xinkuan.qiuji.premium.\(product)"]
        XCTAssertTrue(selected.waitForExistence(timeout: 12))
        reveal(selected, in: app)
        selected.tap()
        XCTAssertTrue(selected.isSelected)
        XCTAssertTrue(app.buttons["subscription.purchase"].label.contains(cadence))
        app.buttons["subscription.purchase"].tap()
        let membership = app.buttons["profile.subscription"]
        XCTAssertTrue(membership.waitForExistence(timeout: 12), "Successful StoreKit purchase returns to profile")
        XCTAssertTrue(membership.label.contains(product == "lifetime" ? "永久有效" : "有效至"))
        membership.tap()
        XCTAssertTrue(app.staticTexts["已解锁 Pro"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["subscription.upgradeLifetime"].exists, product != "lifetime")
        XCTAssertTrue(app.buttons["管理订阅"].exists)
        XCTAssertFalse(app.buttons["subscription.purchase"].exists)
        XCTAssertEqual(session.allTransactions().filter { $0.productIdentifier == "com.xinkuan.qiuji.premium.\(product)" }.count, 1)
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-subscription.preview", "-v53.authenticatedProfileFixture", "-v50.inMemoryStore"])
        let restore = app.buttons["subscription.restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 10))
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: restore)
        waitForExpectations(timeout: 12)
        restore.tap()
        XCTAssertTrue(app.alerts["恢复购买"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.alerts.staticTexts["已恢复购买，Pro 功能已解锁"].exists)
        capture("storekit-\(product)-restored")
        app.alerts.buttons["确定"].tap()
        app.terminate()
    }

    @MainActor
    func testProLargeTextKeepsPlansLegalStateAndPurchaseReachable() throws {
        let session = try storeSession()
        defer { session.clearTransactions() }
        for appearance in ["-v54.forceLight", "-v54.forceDark"] {
            let app = XCUIApplication.launchClean(extraArgs: ["-subscription.preview", appearance,
                "-v50.inMemoryStore", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
            XCTAssertTrue(app.buttons["subscription.close"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.buttons["subscription.restore"].isHittable)
            capture("\(appearance)-pro-large-top")
            let lifetime = app.buttons["subscription.product.com.xinkuan.qiuji.premium.lifetime"]
            revealProElement(lifetime, in: app)
            XCTAssertTrue(lifetime.isHittable)
            lifetime.tap()
            XCTAssertTrue(lifetime.isSelected)
            let purchase = app.buttons["subscription.purchase"]
            XCTAssertTrue(purchase.isHittable)
            XCTAssertGreaterThanOrEqual(purchase.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(purchase.frame.maxX, app.frame.maxX)
            capture("\(appearance)-pro-large-plans")
            let terms = app.descendants(matching: .any).matching(NSPredicate(format: "label == '服务条款'")).firstMatch
            let unpublished = app.staticTexts["法律文件链接待发布"]
            revealProElement(terms.exists ? terms : unpublished, in: app)
            if terms.exists {
                XCTAssertTrue(terms.isHittable)
                XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == '隐私政策'")).firstMatch.isHittable)
            } else {
                // H-09 is still open. This checks the honest fallback's layout,
                // never substitutes for published legal-link acceptance.
                XCTAssertTrue(unpublished.isHittable)
            }
            capture("\(appearance)-pro-large-legal")
            app.terminate()
        }
    }

    @MainActor
    func testAllElevenProDestinationsLockedWithoutPurchase() throws {
        let session = try storeSession()
        defer { session.clearTransactions() }
        let routes = ["separation", "cushion", "scene3d", "aim3d", "snake", "composer", "photo", "three", "snooker", "bank", "diamond"]
        for route in routes {
            let app = XCUIApplication.launchClean(extraArgs: ["-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-pro.route=\(route)"])
            XCTAssertTrue(app.descendants(matching: .any)["pro.locked"].firstMatch.waitForExistence(timeout: 12), route)
            XCTAssertFalse(app.descendants(matching: .any)["pro.authorized"].firstMatch.exists, route)
            if route == "separation" { capture("pro-route-free") }
            app.terminate()
        }
    }

    @MainActor
    func testAllElevenProDestinationsOpenAfterPurchase() throws {
        let session = try storeSession()
        defer { session.clearTransactions() }
        let routes = ["separation", "cushion", "scene3d", "aim3d", "snake", "composer", "photo", "three", "snooker", "bank", "diamond"]
        _ = try session.buyProduct(productIdentifier: "com.xinkuan.qiuji.premium.monthly")
        XCUIApplication().terminate() // Relaunch with the explicit test route and account fixture.
        for route in routes {
            let app = XCUIApplication.launchClean(extraArgs: ["-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-pro.route=\(route)"])
            XCTAssertTrue(app.descendants(matching: .any)["pro.authorized"].firstMatch.waitForExistence(timeout: 20), route)
            XCTAssertFalse(app.descendants(matching: .any)["pro.locked"].firstMatch.exists, route)
            if route == "separation" { capture("pro-route-purchased") }
            app.terminate()
        }
    }

    @MainActor
    func testBankAndDiamondRealEntriesRespectPro() throws {
        let session = try storeSession()
        defer { session.clearTransactions(); XCUIDevice.shared.orientation = .portrait }
        for purchased in [false, true] {
            if purchased {
                try session.buyProduct(productIdentifier: "com.xinkuan.qiuji.premium.monthly")
                XCUIApplication().terminate()
            }
            for title in ["翻袋解球", "颗星解球"] {
                XCUIDevice.shared.orientation = .portrait
                let app = XCUIApplication.launchClean(extraArgs: ["-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-v54.forceLight"])
                app.switchTab(.angle)
                app.buttons["angleHomeTab_解"].tap()
                let card = app.buttons[title]
                for _ in 0..<5 {
                    if card.exists && card.isHittable { break }
                    app.swipeUp()
                }
                XCTAssertTrue(card.waitForExistence(timeout: 8))
                capture("solver-entry-\(title)-\(purchased ? "paid" : "free")")
                card.tap()
                if purchased {
                    XCTAssertTrue(app.buttons["solver.mode"].waitForExistence(timeout: 20), title)
                    XCTAssertFalse(app.buttons["subscription.close"].exists)
                    XCTAssertFalse(app.descendants(matching: .any)["pro.locked"].firstMatch.exists)
                } else {
                    XCTAssertTrue(app.buttons["subscription.close"].waitForExistence(timeout: 10), title)
                    XCTAssertFalse(app.buttons["solver.mode"].exists)
                    app.buttons["subscription.close"].tap()
                    XCTAssertTrue(card.waitForExistence(timeout: 5))
                    XCTAssertFalse(app.buttons["solver.mode"].exists)
                }
                capture("solver-result-\(title)-\(purchased ? "paid" : "free")")
                app.terminate()
            }
        }
    }

    @MainActor
    func testProRevocationClosesOpenDrillStatisticsAndTool() throws {
        let session = try storeSession()
        defer { session.clearTransactions(); XCUIDevice.shared.orientation = .portrait }
        for destination in ["drill", "statistics", "tool"] {
            session.clearTransactions()
            try session.buyProduct(productIdentifier: "com.xinkuan.qiuji.premium.lifetime")
            XCUIApplication().terminate() // StoreKitTest may launch the app without our route/identity arguments.
            let transaction = try XCTUnwrap(session.allTransactions().first)
            var args = ["-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-v54.forceLight"]
            if destination == "drill" { args.append("-deeplink.drillDetail=drill_c039") }
            if destination == "tool" { args.append("-pro.route=separation") }
            let app = XCUIApplication.launchClean(extraArgs: args)
            defer { app.terminate() }
            if destination == "statistics" {
                app.switchTab(.history)
                let tab = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '统计'")).firstMatch
                XCTAssertTrue(tab.waitForExistence(timeout: 10))
                tab.tap()
            }
            let unlocked = destination == "drill" ? app.buttons["bottomTryoutButton"] : app.descendants(matching: .any)["pro.authorized"].firstMatch
            XCTAssertTrue(unlocked.waitForExistence(timeout: 20), destination)
            capture("revocation-\(destination)-purchased")
            XCUIDevice.shared.press(.home)
            try session.refundTransaction(identifier: transaction.identifier)
            app.activate()
            let locked = destination == "drill" ? app.buttons["unlockProButton"] : app.descendants(matching: .any)["pro.locked"].firstMatch
            XCTAssertTrue(locked.waitForExistence(timeout: 15), destination)
            XCTAssertFalse(unlocked.exists, "Revoked content must leave the accessibility tree: \(destination)")
            if destination != "drill" {
                XCTAssertTrue(app.staticTexts["购买 Pro 或恢复已有的 Apple 购买权益"].exists)
                XCTAssertFalse(app.staticTexts["登录后可购买或恢复已有的 Apple 购买权益"].exists)
            }
            capture("revocation-\(destination)-locked")
            app.terminate()
        }
    }

    @MainActor
    func testProPurchaseRotationAndLargeText() throws {
        let session = try storeSession()
        defer { session.clearTransactions(); XCUIDevice.shared.orientation = .portrait }
        for largeText in [false, true] {
            var args = ["-subscription.preview", "-v54.forceLight", "-v50.inMemoryStore"]
            if largeText { args += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
            let app = XCUIApplication.launchClean(extraArgs: args)
            defer { app.terminate() }
            for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
                XCUIDevice.shared.orientation = orientation
                let close = app.buttons["subscription.close"]
                XCTAssertTrue(close.waitForExistence(timeout: 10))
                XCTAssertTrue(close.isHittable)
                XCTAssertTrue(app.buttons["subscription.restore"].isHittable)
                let plan = app.buttons["subscription.product.com.xinkuan.qiuji.premium.lifetime"]
                XCTAssertTrue(plan.waitForExistence(timeout: 15))
                revealProElement(plan, in: app)
                XCTAssertTrue(plan.isHittable)
                plan.tap()
                XCTAssertTrue(plan.isSelected)
                let purchase = app.buttons["subscription.purchase"]
                XCTAssertTrue(purchase.isHittable)
                XCTAssertTrue(app.frame.insetBy(dx: -1, dy: -1).contains(purchase.frame))
                capture("purchase-rotation-\(orientation.rawValue)-large-\(largeText)")
            }
            app.terminate()
        }
    }

    /// Layout-only fixture: these assertions never stand in for a StoreKit transaction.
    @MainActor
    func testProStatusReturnAppearanceTransitions() {
        XCUIDevice.shared.orientation = .portrait
        for appearance in ["-v54.forceLight", "-v54.forceDark", "-v51.followSystemAppearance"] {
            let app = XCUIApplication.launchClean(extraArgs: [
                "-forcePremium", "-v53.authenticatedProfileFixture", "-v50.inMemoryStore", appearance
            ])
            app.switchTab(.profile)
            let membership = app.buttons["profile.subscription"]
            reveal(membership, in: app)
            capture("return-\(appearance)-profile-before")
            for action in ["button", "cancel-swipe", "swipe"] {
                membership.tap()
                XCTAssertTrue(app.staticTexts["已解锁 Pro"].waitForExistence(timeout: 10))
                capture("return-\(appearance)-\(action)-pro")
                if action == "cancel-swipe" {
                    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
                    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.5))
                    start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.5)
                    XCTAssertTrue(app.staticTexts["已解锁 Pro"].exists)
                    XCTAssertTrue(app.buttons["管理订阅"].isHittable)
                    capture("return-\(appearance)-cancelled-pro")
                    app.navigationBars.buttons.element(boundBy: 0).tap()
                } else if action == "swipe" {
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
                        .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
                } else {
                    app.navigationBars.buttons.element(boundBy: 0).tap()
                }
                XCTAssertTrue(membership.waitForExistence(timeout: 6))
                XCTAssertTrue(membership.isHittable)
                capture("return-\(appearance)-\(action)-profile-after")
            }
            app.terminate()
        }
    }

    /// Layout-only fixture: these assertions never stand in for a StoreKit transaction.
    @MainActor
    func testProStatusFixtureRotationAndLargeText() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        for largeText in [false, true] {
            var args = ["-forcePremium", "-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-v54.forceLight"]
            if largeText { args += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
            let app = XCUIApplication.launchClean(extraArgs: args)
            defer { app.terminate() }
            app.switchTab(.profile)
            let membership = app.buttons["profile.subscription"]
            reveal(membership, in: app)
            membership.tap()
            XCTAssertTrue(app.staticTexts["已解锁 Pro"].waitForExistence(timeout: 10))
            for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
                XCUIDevice.shared.orientation = orientation
                let manage = app.buttons["管理订阅"]
                revealProElement(manage, in: app, scrollID: "subscription.statusScroll")
                XCTAssertTrue(manage.isHittable)
                XCTAssertTrue(app.frame.insetBy(dx: -1, dy: -1).contains(manage.frame))
                let restore = app.buttons["恢复购买"]
                revealProElement(restore, in: app, scrollID: "subscription.statusScroll")
                XCTAssertTrue(restore.isHittable)
                capture("status-fixture-rotation-\(orientation.rawValue)-large-\(largeText)")
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(membership.waitForExistence(timeout: 6))
            capture("status-fixture-return-profile-large-\(largeText)")
            app.terminate()
        }
    }

    @MainActor
    private func storeSession() throws -> SKTestSession {
        let catalog = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: catalog)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            let footer = app.buttons["subscription.purchase"]
            let visibleBottom = footer.exists ? footer.frame.minY : app.frame.maxY - 84
            if element.exists && element.isHittable && element.frame.maxY < visibleBottom { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
