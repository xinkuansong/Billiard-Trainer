import XCTest

/// W1 / 问题集合_v9：训练分享「保存相册」模拟器冒烟（完整路径截图落盘）。
///
/// W1 返工第 1 轮：跑之前须 `simctl privacy reset photos-add`（禁止 grant 预授权），
/// 走真实 TCC 弹框路径——弹框出现、点「允许」、出 toast，全程不崩。
final class W1_ShareSavePhotosUITests: XCTestCase {
    var app: XCUIApplication!
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    private var shotDir: URL {
        URL(
            fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/w1r1-screenshots",
            isDirectory: true
        )
    }

    private func snap(_ name: String) {
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    @discardableResult
    private func tapLabel(_ label: String, timeout: TimeInterval = 6) -> Bool {
        let button = app.buttons[label]
        if button.waitForExistence(timeout: timeout) {
            button.tap()
            return true
        }
        // Some chrome exposes the label on staticTexts / otherElements.
        let text = app.staticTexts[label]
        if text.waitForExistence(timeout: 1) {
            text.tap()
            return true
        }
        return false
    }

    func testW1_saveShareCardToPhotos_showsToastOrPermissionFeedback() throws {
        _ = app.tabBars.buttons["训练"].waitForExistence(timeout: 15)
        app.switchTab(.training)
        sleep(1)

        if !tapLabel("自由记录", timeout: 6) {
            guard tapLabel("开始训练", timeout: 4) else {
                snap("w1-00-no-start")
                XCTFail("未能进入自由记录/开始训练")
                return
            }
        }
        sleep(2)

        if tapLabel("继续", timeout: 6) {
            sleep(3)
        }

        // When drills are present the nav-bar「结束」is hidden; use the timer
        // chrome control with accessibilityLabel「结束训练」(ActiveTrainingView).
        let endTraining = app.buttons["结束训练"]
        let endNav = app.buttons["结束"]
        if endTraining.waitForExistence(timeout: 8) {
            endTraining.tap()
        } else if endNav.waitForExistence(timeout: 4) {
            endNav.tap()
        } else if tapLabel("结束训练", timeout: 2) {
            // tapped via helper
        } else {
            snap("w1-01-no-end")
            XCTFail("未见结束/结束训练按钮")
            return
        }
        sleep(1)
        let confirmEnd = app.alerts.buttons["结束"]
        if confirmEnd.waitForExistence(timeout: 4) {
            confirmEnd.tap()
        }
        sleep(2)

        // Skip note → summary
        let doneButtons = app.buttons.matching(NSPredicate(format: "label == '完成'"))
        if doneButtons.firstMatch.waitForExistence(timeout: 4) {
            doneButtons.firstMatch.tap()
            sleep(1)
            if doneButtons.firstMatch.exists {
                doneButtons.firstMatch.tap()
            }
        }
        // Alternate: 跳过 on note page
        _ = tapLabel("跳过", timeout: 2)
        sleep(2)
        snap("w1-02-summary")

        guard tapLabel("生成分享图", timeout: 6) else {
            snap("w1-03-no-share-entry")
            XCTFail("未见生成分享图")
            return
        }
        sleep(2)
        snap("w1-04-share-sheet")

        let saveById = app.buttons["shareSaveToPhotos"]
        let saveByLabel = app.buttons["保存相册"]
        if saveById.waitForExistence(timeout: 4), saveById.isHittable {
            saveById.tap()
        } else if saveByLabel.waitForExistence(timeout: 2), saveByLabel.isHittable {
            saveByLabel.tap()
        } else if saveById.exists {
            saveById.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            snap("w1-05-no-save-button")
            XCTFail("未见保存相册按钮")
            return
        }

        // Catch「保存中」quickly, then toast / alert (toast ~1.6s — do not sleep past it).
        usleep(400_000)
        snap("w1-06-saving-or-feedback")

        let toast = app.staticTexts["已保存到相册"]
        let saveFailAlert = app.alerts["保存失败"]
        let savingLabel = app.staticTexts["保存中"]

        var sawToast = false
        var sawFailAlert = false
        var sawSaving = savingLabel.exists
        var sawSystemAlert = false

        // The TCC photo prompt is hosted by SpringBoard, not the app.
        func systemPhotoAlert() -> XCUIElement? {
            for host: XCUIApplication in [springboard, app] {
                let alert = host.alerts.firstMatch
                if alert.exists,
                   alert.label.contains("照片") || alert.label.contains("相册")
                    || alert.buttons["允许添加照片"].exists
                    || alert.buttons["允许"].exists
                    || alert.buttons["好"].exists {
                    return alert
                }
            }
            return nil
        }

        var permissionAlert: XCUIElement?
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if toast.exists { sawToast = true; break }
            if saveFailAlert.exists { sawFailAlert = true; break }
            if savingLabel.exists { sawSaving = true }
            if let alert = systemPhotoAlert() {
                sawSystemAlert = true
                permissionAlert = alert
                break
            }
            usleep(200_000)
        }

        // App must still be alive at this point (the pre-fix crash was an
        // immediate TCC kill on requestAuthorization).
        XCTAssertEqual(app.state, .runningForeground, "点保存后 App 不得被 TCC 强杀")

        if sawSystemAlert, let alert = permissionAlert {
            snap("w1-07-permission-alert")
            let allowButtons = ["允许添加照片", "允许", "好", "Allow Adding Photos", "Allow", "OK"]
            for title in allowButtons where alert.buttons[title].exists {
                alert.buttons[title].tap()
                break
            }
            // Toast lives ~1.6s — poll immediately, snapshot the instant it shows.
            let toastDeadline = Date().addingTimeInterval(8)
            while Date() < toastDeadline {
                if toast.exists {
                    sawToast = true
                    snap("w1-08-toast-after-permission")
                    break
                }
                if saveFailAlert.exists {
                    sawFailAlert = true
                    snap("w1-08-fail-alert-after-permission")
                    break
                }
                usleep(100_000)
            }
            XCTAssertTrue(
                sawToast || sawFailAlert,
                "点「允许」后应出现 toast「已保存到相册」或保存失败 alert"
            )
        }

        snap("w1-09-final")
        XCTAssertEqual(app.state, .runningForeground, "保存流程结束后 App 仍应存活")
        XCTAssertTrue(
            sawToast || sawFailAlert || sawSystemAlert || sawSaving,
            "保存后应出现「保存中」/ toast「已保存到相册」/ 保存失败 alert / 系统相册权限提示；不得无反馈永久冻结"
        )
    }
}
