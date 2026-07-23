import XCTest

/// v7 W9a（C25–C28）：九个沙盘/求解页左下角与动作列截图取证。
/// 截图写入 `build/w9a-screenshots/`（禁止覆盖 `docs/ui-polish/` 与 DrillThumbnails）。
final class W9a_ShotPagesLayoutUITests: XCTestCase {

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/w9a-screenshots")
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        savePNG(app.screenshot(), name)
    }

    private func savePNG(_ shot: XCUIScreenshot, _ name: String) {
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    // MARK: - 台面区像素 diff（C28 线语言取证）

    /// 归一化台面裁剪区（x 5%–95%、y 30%–75%）：避开状态栏时钟、顶栏、chip 带与底部球库。
    private func tableRegionDiff(_ a: XCUIScreenshot, _ b: XCUIScreenshot) -> Int {
        guard let ga = grayscaleTableRegion(a.image),
              let gb = grayscaleTableRegion(b.image),
              ga.count == gb.count else { return -1 }
        var diff = 0
        for i in 0..<ga.count where abs(Int(ga[i]) - Int(gb[i])) > 24 { diff += 1 }
        return diff
    }

    /// 台面裁剪 → 128×128 灰度位图（降采样吸收渲染噪声）。
    private func grayscaleTableRegion(_ image: UIImage) -> [UInt8]? {
        guard let cg = image.cgImage else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let crop = CGRect(x: w * 0.05, y: h * 0.30, width: w * 0.90, height: h * 0.45)
        guard let sub = cg.cropping(to: crop) else { return nil }
        let size = 128
        var buf = [UInt8](repeating: 0, count: size * size)
        guard let ctx = CGContext(data: &buf, width: size, height: size,
                                  bitsPerComponent: 8, bytesPerRow: size,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(sub, in: CGRect(x: 0, y: 0, width: size, height: size))
        return buf
    }

    private func dismissOnboardingIfNeeded(_ app: XCUIApplication) {
        let skip = app.buttons["跳过"]
        if skip.waitForExistence(timeout: 3) {
            skip.tap()
            sleep(1)
        }
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 15)
    }

    private func switchAngleHomeTab(_ app: XCUIApplication, _ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        guard seg.waitForExistence(timeout: 4) else { return false }
        seg.tap(); usleep(600_000); return true
    }

    private func openCard(_ app: XCUIApplication, homeTab: String, title: String) -> Bool {
        dismissOnboardingIfNeeded(app)
        app.switchTab(.angle)
        sleep(1)
        guard switchAngleHomeTab(app, homeTab) else { return false }
        let card = app.buttons[title]
        guard card.waitForExistence(timeout: 4) else { return false }
        card.tap()
        sleep(3)
        return true
    }

    private func goBack(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.firstMatch
        if back.exists { back.tap(); sleep(1) }
    }

    func testW9aNinePagesLeftSlotAndActionColumn() throws {
        let app = XCUIApplication.launchClean()

        // 1 ShotSim
        XCTAssertTrue(openCard(app, homeTab: "打", title: "分离角与走位"), "ShotSim")
        snap(app, "w9a-01-shotsim")
        goBack(app)

        // 2 Composer（自由走位）
        XCTAssertTrue(openCard(app, homeTab: "打", title: "自由走位"), "Composer")
        snap(app, "w9a-02-composer")
        goBack(app)

        // 3 FreePlay
        XCTAssertTrue(openCard(app, homeTab: "打", title: "自由击球"), "FreePlay")
        snap(app, "w9a-03-freeplay")
        goBack(app)

        // 4 Silu
        XCTAssertTrue(openCard(app, homeTab: "解", title: "思路训练"), "Silu")
        snap(app, "w9a-04-silu")
        goBack(app)

        // 5 PlanThree
        XCTAssertTrue(openCard(app, homeTab: "解", title: "打一走二想三"), "PlanThree")
        snap(app, "w9a-05-planthree")
        goBack(app)

        // 6 Snooker（首页卡文案 = 「防守」）
        XCTAssertTrue(openCard(app, homeTab: "解", title: "防守"), "Snooker")
        snap(app, "w9a-06-snooker")
        goBack(app)

        // 7 Bank
        XCTAssertTrue(openCard(app, homeTab: "解", title: "翻袋解球器"), "Bank")
        snap(app, "w9a-07-bank")
        // C28/D15：轨迹 chip 三档位——不只断言文案切换，还断言场景线语言实际变化
        //（同一态三档截图，台面裁剪区像素 diff 必须超阈值）。
        let traj = app.buttons["轨迹标注档位"]
        if traj.waitForExistence(timeout: 3) {
            // 归一到「轨迹·全」起点（chip 档位跨启动持久化，防前序状态污染）。
            for _ in 0..<3 {
                if (traj.value as? String) == "轨迹·全" { break }
                traj.tap(); sleep(2)
            }
            XCTAssertEqual(traj.value as? String, "轨迹·全", "档位应可归一到轨迹·全")

            let fullShot = app.screenshot()
            savePNG(fullShot, "w9a-07d-bank-traj-full")

            traj.tap(); sleep(2)
            XCTAssertEqual(traj.value as? String, "轨迹·双", "第一次切换应到轨迹·双")
            let coreShot = app.screenshot()
            savePNG(coreShot, "w9a-07e-bank-traj-core")

            traj.tap(); sleep(2)
            XCTAssertEqual(traj.value as? String, "瞄准线", "第二次切换应到瞄准线")
            let minimalShot = app.screenshot()
            savePNG(minimalShot, "w9a-07f-bank-traj-minimal")

            // 台面裁剪区（避开时钟/顶栏/chip 带/底部球库）像素 diff：档位必须实际改变线语言。
            let fullVsMinimal = tableRegionDiff(fullShot, minimalShot)
            let fullVsCore = tableRegionDiff(fullShot, coreShot)
            XCTAssertGreaterThan(fullVsMinimal, 100,
                                 "全↔瞄准线 台面像素差过小（\(fullVsMinimal)）——档位未改变线语言")
            // 全↔双 仅差释义层（金点/库面法线），降采样后量级小：实测 26，
            // 取 15 为下限（同帧重拍噪声实测 ≈0，仍有 15 px 裕度）。
            XCTAssertGreaterThan(fullVsCore, 15,
                                 "全↔双 台面像素差过小（\(fullVsCore)）——释义层未随档位隐去")

            traj.tap(); sleep(1)   // 归位轨迹·全（不污染后续用例/巡游）
        } else {
            XCTFail("Bank 缺少轨迹档位 chip")
        }
        goBack(app)

        // 8 Diamond
        XCTAssertTrue(openCard(app, homeTab: "解", title: "反射解球器"), "Diamond")
        snap(app, "w9a-08-diamond")
        let trajD = app.buttons["轨迹标注档位"]
        if trajD.waitForExistence(timeout: 3) {
            for _ in 0..<3 {
                if (trajD.value as? String) == "轨迹·全" { break }
                trajD.tap(); sleep(2)
            }
            let dFull = app.screenshot()
            savePNG(dFull, "w9a-08b-diamond-traj-full")
            trajD.tap(); sleep(2)   // → 轨迹·双
            trajD.tap(); sleep(2)   // → 瞄准线
            XCTAssertEqual(trajD.value as? String, "瞄准线", "Diamond 档位应循环到瞄准线")
            let dMin = app.screenshot()
            savePNG(dMin, "w9a-08c-diamond-traj-minimal")
            let dDiff = tableRegionDiff(dFull, dMin)
            XCTAssertGreaterThan(dDiff, 60,
                                 "Diamond 全↔瞄准线 台面像素差过小（\(dDiff)）——档位未改变线语言")
            trajD.tap(); sleep(1)   // 归位轨迹·全
        } else {
            XCTFail("Diamond 缺少轨迹档位 chip")
        }
        goBack(app)
    }

    /// BatchAuthoring：打分组「批量出片台」。
    /// 球桌态需经建球形向导（选图→标定→标球→确认→送入），本用例只截列表入口；
    /// 禁用开球占位清零以代码 grep 为准（见 W9a 汇报）。
    func testW9aBatchAuthoringIfReachable() throws {
        let app = XCUIApplication.launchClean()
        XCTAssertTrue(openCard(app, homeTab: "打", title: "批量出片台"), "BatchAuthoring")
        snap(app, "w9a-09-batch-authoring")
    }
}
