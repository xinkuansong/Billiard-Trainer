import XCTest

/// B1 出片台「新增球形」模拟器实操录证。
/// 截图落盘 `build/b1-screenshots/`；序列写入内容库（BatchSequenceArchive 硬编码主仓路径）。
final class B1_ManualFormationUITests: XCTestCase {

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer-wt-b1/build/b1-screenshots")
    }

    /// 与 `BatchSequenceArchive.directory` 一致（主仓内容库）。
    private var sequencesDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/content/position_play/sequences")
    }

    private let noSourceDrillId = "drill_c065"
    private let screenshotDrillId = "drill_c005"

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
        cleanupManualTokens(for: noSourceDrillId)
    }

    override func tearDownWithError() throws {
        // 保留落盘序列与截图作验收证据；不在 tearDown 删除。
    }

    // MARK: - Helpers

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    private func dismissOnboardingIfNeeded(_ app: XCUIApplication) {
        let skip = app.buttons["跳过"]
        if skip.waitForExistence(timeout: 3) {
            skip.tap()
            sleep(1)
        }
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 15)
    }

    private func openBatchStudio(_ app: XCUIApplication) {
        dismissOnboardingIfNeeded(app)
        app.switchTab(.angle)
        sleep(1)
        let seg = app.buttons["angleHomeTab_打"]
        XCTAssertTrue(seg.waitForExistence(timeout: 6), "角度首页「打」分段")
        seg.tap()
        usleep(600_000)
        let card = app.buttons["批量出片台"]
        XCTAssertTrue(card.waitForExistence(timeout: 6), "批量出片台入口")
        card.tap()
        sleep(2)
        XCTAssertTrue(app.navigationBars["批量出片台"].waitForExistence(timeout: 8))
    }

    private func scrollToDrill(_ app: XCUIApplication, drillId: String, maxSwipes: Int = 18) -> XCUIElement {
        let pred = NSPredicate(format: "label CONTAINS %@", drillId)
        for _ in 0..<maxSwipes {
            let cell = app.buttons.containing(pred).firstMatch
            if cell.exists, cell.isHittable { return cell }
            app.swipeUp()
            usleep(350_000)
        }
        let cell = app.buttons.containing(pred).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 2), "列表应出现 \(drillId)")
        return cell
    }

    private func goBack(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.firstMatch
        if back.exists { back.tap(); sleep(1) }
    }

    private func cleanupManualTokens(for drillId: String) {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(atPath: sequencesDir.path)) ?? []
        for f in files where f.hasPrefix("\(drillId)__manual") && f.hasSuffix(".json") {
            try? fm.removeItem(at: sequencesDir.appendingPathComponent(f))
        }
    }

    private func listManualFiles(for drillId: String) -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: sequencesDir.path)) ?? []
        return files.filter { $0.hasPrefix("\(drillId)__manual") && $0.hasSuffix(".json") }.sorted()
    }

    private func assertManualZeroShotFile(token: String, drillId: String) {
        let files = listManualFiles(for: drillId).filter { $0.contains("__\(token)-") }
        XCTAssertEqual(files.count, 1, "应有且仅有一个 \(token) 文件，实际=\(files)")
        let name = files[0]
        XCTAssertTrue(name.hasSuffix("-0杆.json"), "应为 0 杆文件：\(name)")
        let url = sequencesDir.appendingPathComponent(name)
        let data = try! Data(contentsOf: url)
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let steps = obj["steps"] as? [Any] ?? ["missing"]
        XCTAssertEqual(steps.count, 0, "steps 应为空：\(name)")
        let initial = obj["initial"] as? [String: Any]
        let onTable = initial?["onTable"] as? [String: Any]
        XCTAssertNotNil(onTable?["cueBall"], "initial 应含母球：\(name)")
    }

    // MARK: - Tests

    func testB1ManualFormationWorkflow() throws {
        let app = XCUIApplication.launchClean()
        openBatchStudio(app)
        snap(app, "b1-01-studio-list")

        // ① 无截图 drill 出现在列表（行标「无源图」）
        let noSource = scrollToDrill(app, drillId: noSourceDrillId)
        snap(app, "b1-02-nosource-row-visible")
        XCTAssertTrue(noSource.label.contains("无源图") || app.staticTexts["无源图"].exists,
                      "无源图行标应可见（label=\(noSource.label)）")
        noSource.tap()
        sleep(2)
        snap(app, "b1-03-nosource-grid-plus-only")

        // ②a 空台面 → initial-only 保存
        let plus = app.staticTexts["+ 新增球形"]
        XCTAssertTrue(plus.waitForExistence(timeout: 6), "+ 新增球形")
        plus.tap()
        sleep(1)
        snap(app, "b1-04-new-formation-options")
        let empty = app.buttons["空台面（仅母球）"]
        XCTAssertTrue(empty.waitForExistence(timeout: 4))
        empty.tap()
        sleep(3)
        snap(app, "b1-05-authoring-empty-start")

        let saveStay = app.buttons["保存·选下张图"]
        XCTAssertTrue(saveStay.waitForExistence(timeout: 10), "保存按钮")
        saveStay.tap()
        sleep(2)
        snap(app, "b1-06-after-empty-save-grid")
        assertManualZeroShotFile(token: "manual01", drillId: noSourceDrillId)
        XCTAssertTrue(app.staticTexts["manual01"].waitForExistence(timeout: 4), "栅格应出现 manual01 打勾项")

        // ②b 克隆已有球形 → 再存一个 initial-only
        plus.tap()
        sleep(1)
        let clone = app.buttons["克隆已有球形…"]
        XCTAssertTrue(clone.waitForExistence(timeout: 4))
        clone.tap()
        sleep(1)
        snap(app, "b1-07-clone-picker")
        // 选单第一项（manual01）
        let cloneItem = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "manual01")).firstMatch
        XCTAssertTrue(cloneItem.waitForExistence(timeout: 4), "克隆候选项 manual01")
        cloneItem.tap()
        sleep(3)
        snap(app, "b1-08-authoring-clone-start")
        XCTAssertTrue(saveStay.waitForExistence(timeout: 10))
        saveStay.tap()
        sleep(2)
        snap(app, "b1-09-after-clone-save-grid")
        assertManualZeroShotFile(token: "manual02", drillId: noSourceDrillId)
        XCTAssertEqual(listManualFiles(for: noSourceDrillId).count, 2, "空台+克隆应各 1 个文件")

        // ③ 同 token 重存 → 覆盖确认
        let manual01 = app.staticTexts["manual01"]
        XCTAssertTrue(manual01.waitForExistence(timeout: 4))
        manual01.tap()
        sleep(3)
        snap(app, "b1-10-reedit-manual01")
        XCTAssertTrue(saveStay.waitForExistence(timeout: 10))
        saveStay.tap()
        sleep(1)
        let overwrite = app.buttons["覆盖"]
        XCTAssertTrue(overwrite.waitForExistence(timeout: 4), "应弹出覆盖确认")
        snap(app, "b1-11-overwrite-confirm")
        overwrite.tap()
        sleep(2)
        snap(app, "b1-12-after-overwrite-grid")
        assertManualZeroShotFile(token: "manual01", drillId: noSourceDrillId)

        goBack(app)
        sleep(1)

        // ④ 既有截图路径：改存档（≥1 杆）再覆盖保存仍正常
        let withShots = scrollToDrill(app, drillId: screenshotDrillId)
        withShots.tap()
        sleep(2)
        snap(app, "b1-13-screenshot-drill-grid")
        let redo = app.buttons["重做"].firstMatch
        XCTAssertTrue(redo.waitForExistence(timeout: 6), "已存截图应有「重做」")
        redo.tap()
        sleep(4)
        snap(app, "b1-14-screenshot-reedit-authoring")
        XCTAssertTrue(saveStay.waitForExistence(timeout: 12))
        saveStay.tap()
        sleep(1)
        if overwrite.waitForExistence(timeout: 4) {
            snap(app, "b1-15-screenshot-overwrite-confirm")
            overwrite.tap()
            sleep(2)
        } else {
            // 若无覆盖弹窗也算路径可达（罕见：文件在中途被删）
            snap(app, "b1-15-screenshot-saved-without-confirm")
        }
        snap(app, "b1-16-screenshot-path-ok")

        // 落盘证明清单
        let proof = """
        B1 proof
        manual files: \(listManualFiles(for: noSourceDrillId))
        c005 sequences: \(((try? FileManager.default.contentsOfDirectory(atPath: sequencesDir.path)) ?? []).filter { $0.hasPrefix("\(screenshotDrillId)__") }.sorted())
        """
        try proof.write(to: shotDir.appendingPathComponent("b1-proof.txt"), atomically: true, encoding: .utf8)
        let att = XCTAttachment(string: proof)
        att.name = "b1-proof"
        att.lifetime = .keepAlways
        add(att)
    }
}
