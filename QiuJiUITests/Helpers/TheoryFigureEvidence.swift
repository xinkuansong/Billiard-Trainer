import XCTest

/// 理论页「配图截图取证」共用件（v30 W4，修 X-v30-9）。
///
/// **为什么重写**：W2/W3 的取证策略是「滚到 identifier 可点 → 截全屏 → 只断言
/// 字节 ≠ 页顶截图」。该断言对「滚过头」完全无效——W3 五张里四张实际拍到的是图
/// **下方**的正文，字节当然不同，断言照样绿。
///
/// **本件的口径**（两条，缺一不可）：
/// 1. **先把图完整滚进可视区**，再断言 `figure.frame` 完整落在可视区内
///    （可视区 = 窗口去掉导航栏遮挡的部分）。滚过头 / 没滚到都会失败。
/// 2. **直接截该元素**（`XCUIElement.screenshot()`），落盘的 PNG 就是这张图本身，
///    而不是「某个恰好不同的屏幕」。另存一张全屏作上下文。
enum TheoryFigureEvidence {

    /// 可视区：窗口减去导航栏遮挡（导航栏是浮层，图落在它下面就是被挡住）。
    static func viewport(of app: XCUIApplication, navigationTitle: String) -> CGRect {
        let window = app.windows.firstMatch.frame
        let bar = app.navigationBars[navigationTitle]
        let top = bar.exists ? bar.frame.maxY : window.minY
        return CGRect(x: window.minX, y: top, width: window.width, height: window.maxY - top)
    }

    /// 小步滚动：`down == true` 表示看更下面的内容。
    ///
    /// 实测受控 `press(forDuration:thenDragTo:)` 在本 App 的 `ScrollView` 上不产生滚动
    /// （帧位置逐次不变，见 `build/v30-w4-logs/tests-ui-w4-light.log` 首轮），
    /// 因此改用 `.slow` 速度的真实 swipe：既能滚动，惯性又比默认 `swipeUp()` 小得多，
    /// 配合下面的「每步复核包含关系」不会像 W2/W3 那样一路滑过头。
    static func scrollStep(_ app: XCUIApplication, down: Bool) {
        if down {
            app.swipeUp(velocity: .slow)
        } else {
            app.swipeDown(velocity: .slow)
        }
    }

    /// 把 `figure` 完整滚进可视区。返回是否成功。
    ///
    /// 每滚一小步就复核「图是否完整落在可视区内」——这正是 W2/W3 缺的那一步：
    /// 它们只滚到 `isHittable`（图刚露头或已滑过），从不校验完整可见性。
    /// 图高恒小于可视区高（本仓说明图 ≤ 300pt），所以可行区间很宽，不会来回摆动。
    @discardableResult
    static func scrollFullyIntoView(
        _ figure: XCUIElement,
        app: XCUIApplication,
        navigationTitle: String,
        margin: CGFloat = 4,
        maxAttempts: Int = 16
    ) -> Bool {
        func contained() -> Bool {
            let box = viewport(of: app, navigationTitle: navigationTitle)
            let frame = figure.frame
            return frame.height > 0
                && frame.minY >= box.minY + margin
                && frame.maxY <= box.maxY - margin
        }

        var stuckCount = 0
        var previousMinY = CGFloat.greatestFiniteMagnitude
        for _ in 0..<maxAttempts {
            let box = viewport(of: app, navigationTitle: navigationTitle)
            let frame = figure.frame
            guard frame.height > 0, frame.height + 2 * margin <= box.height else {
                // 图比可视区还高——本仓所有说明图都 ≤ 300pt，出现即是布局异常。
                return false
            }
            if contained() { return true }

            // 页面滚到头（连续两次位置没变）时不再空转。
            stuckCount = abs(frame.minY - previousMinY) < 1 ? stuckCount + 1 : 0
            if stuckCount >= 2 { break }
            previousMinY = frame.minY

            scrollStep(app, down: frame.midY > box.midY)
            usleep(500_000)
        }
        return contained()
    }
}

extension XCTestCase {

    /// 落盘一张截图并挂附件，返回 PNG 字节。
    @discardableResult
    func saveTheoryPNG(_ shot: XCUIScreenshot, name: String, outDir: URL) -> Data {
        let data = shot.pngRepresentation
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        // ⛔ 不用 `try?`：落盘失败必须让用例红，否则「证据丢失」会静默通过（FL-029）。
        do {
            try data.write(to: outDir.appendingPathComponent("\(name).png"))
        } catch {
            XCTFail("截图落盘失败 \(name)：\(error)")
        }
        return data
    }

    /// 配图取证（X-v30-9 修复口径）：滚到图完整可见 → 断言 frame 落在可视区内 →
    /// **截该元素**落盘（另存一张全屏作上下文）。
    ///
    /// - Returns: 元素级截图的 PNG 字节。
    @discardableResult
    func captureTheoryFigure(
        _ identifier: String,
        app: XCUIApplication,
        navigationTitle: String,
        fileStem: String,
        outDir: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Data {
        let figure = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(
            figure.waitForExistence(timeout: 8),
            "页面上找不到说明图 \(identifier)",
            file: file, line: line
        )

        let ok = TheoryFigureEvidence.scrollFullyIntoView(
            figure, app: app, navigationTitle: navigationTitle
        )
        let box = TheoryFigureEvidence.viewport(of: app, navigationTitle: navigationTitle)
        let frame = figure.frame
        XCTAssertTrue(
            ok,
            "说明图 \(identifier) 未能完整滚进可视区：figure=\(frame) viewport=\(box)",
            file: file, line: line
        )
        // 冗余但关键的一条：落盘前再断言一次「图完整在可视区内」，
        // 这正是 W2/W3 的「≠ 页顶字节」断言抓不到的失效模式。
        XCTAssertTrue(
            box.insetBy(dx: -1, dy: -1).contains(frame),
            "说明图 \(identifier) 的 frame 未完整落在可视区内：figure=\(frame) viewport=\(box)",
            file: file, line: line
        )

        let elementShot = figure.screenshot()
        let data = saveTheoryPNG(elementShot, name: fileStem, outDir: outDir)
        saveTheoryPNG(app.screenshot(), name: "\(fileStem)-context", outDir: outDir)
        XCTAssertFalse(data.isEmpty, "\(identifier) 元素截图为空", file: file, line: line)
        return data
    }
}
