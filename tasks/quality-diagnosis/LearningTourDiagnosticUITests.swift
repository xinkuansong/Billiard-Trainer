import XCTest

/// Snapshot-002 normal-entry diagnostic tour. No deep links or production edits.
final class LearningTourDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private let runID = UUID().uuidString

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forcePremium"])
    }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil { try capture("teardown") }
    }
    private func ready(_ e: XCUIElement, timeout: TimeInterval = 20) {
        let p = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: p, object: e)], timeout: timeout), .completed,
                       "Element not actionable: \(e)")
    }
    private func visible(_ e: XCUIElement) -> Bool {
        guard e.exists, e.isHittable else { return false }
        let f = e.frame, a = app.frame
        return f.width > 0 && f.height > 0 && f.midY > a.minY + 110 && f.midY < a.maxY - 90
    }
    private func reveal(_ e: XCUIElement, maximum: Int = 32, backwards: Bool = false) {
        for _ in 0..<maximum {
            if visible(e) { return }
            // Keep scroll inside the document/grid; do not drag the sidebar or system edge.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: backwards ? 0.32 : 0.78))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: backwards ? 0.78 : 0.32)))
        }
        XCTAssertTrue(visible(e), "Expected visible lower-page anchor: \(e)")
    }
    private func text(_ fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }
    private func capture(_ stage: String) throws {
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stem = "learning-\(name.replacingOccurrences(of: "/", with: "_"))-\(stage)-\(runID)"
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        let ax = app.debugDescription
        let hierarchy = XCTAttachment(string: ax); hierarchy.name = stem + "-AX"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent(stem + ".png"))
        try ax.write(to: dir.appendingPathComponent(stem + ".txt"), atomically: true, encoding: .utf8)
    }
    private func enter(_ section: String, _ title: String) throws {
        app.switchTab(.angle)
        let category = app.buttons["angleHomeTab_\(section)"]; ready(category); category.tap()
        let card = app.buttons[title].firstMatch; reveal(card, maximum: 12); ready(card); card.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 30))
        try capture("entered")
    }
    private func finish(_ section: String, _ title: String) throws {
        let back = app.navigationBars.buttons.firstMatch; ready(back); back.tap()
        ready(app.buttons["angleHomeTab_\(section)"])
        let card = app.buttons[title].firstMatch; reveal(card, maximum: 12); ready(card)
        try capture("returned")
    }
    private func readLower(_ heading: String, _ bodyFragment: String) throws {
        reveal(text(heading)); XCTAssertTrue(visible(text(heading)))
        reveal(text(bodyFragment)); XCTAssertTrue(visible(text(bodyFragment)))
        try capture("lower-content")
    }
    private func moveSlider(_ id: String) throws {
        let slider = app.sliders[id]; reveal(slider); ready(slider)
        let before = try XCTUnwrap(slider.value as? String)
        slider.adjust(toNormalizedSliderPosition: 0.82)
        let changed = NSPredicate { _, _ in
            guard let value = slider.value as? String else { return false }
            return value != before
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: changed, object: slider)], timeout: 8), .completed,
                       "Slider must report changed value, not just accept a gesture")
        try capture("slider-changed")
    }
    private func staticTheory(_ title: String, _ heading: String, _ fragment: String) throws {
        try enter("理", title)
        try readLower(heading, fragment)
        try finish("理", title)
    }
    private func thetaTheory(_ title: String, _ id: String, _ heading: String) throws {
        try enter("理", title)
        try moveSlider(id)
        reveal(text(heading)); XCTAssertTrue(visible(text(heading)))
        reveal(text("相关页面")); XCTAssertTrue(visible(text("相关页面")))
        try capture("lower-content")
        try finish("理", title)
    }
    private func atlas(_ title: String, _ id: String) throws {
        try enter("学", title)
        let track = app.buttons[id]; ready(track, timeout: 45)
        XCTAssertEqual(track.value as? String, "已选")
        track.tap()
        XCTAssertEqual(track.value as? String, "未选")
        XCTAssertFalse(track.isSelected)
        try capture("track-hidden")
        track.tap()
        XCTAssertEqual(track.value as? String, "已选")
        XCTAssertTrue(track.isSelected)
        try capture("track-restored")
        try finish("学", title)
    }

    func testLearn01AimingPrincipleLowerContent() throws {
        try enter("学", "瞄准原理")
        try readLower("厚薄球概念", "90° | d/R 2")
        try finish("学", "瞄准原理")
    }
    func testLearn02AimingMethodsSlider() throws {
        try enter("学", "瞄准方法")
        try moveSlider("aimingMethods.thetaSlider")
        try finish("学", "瞄准方法")
    }
    func testLearn03AimingCorrectionSliderAndAdvice() throws {
        try enter("学", "瞄准修正")
        try moveSlider("aimingCorrection.velocitySlider")
        try readLower("实战启示", "边界感知：中杆中速小切角时")
        try finish("学", "瞄准修正")
    }
    func testLearn04SpinStateChangesReadout() throws {
        try enter("学", "旋转与加塞")
        let picker = app.segmentedControls["spinAndEnglish.spinPicker"]
        reveal(picker)
        let draw = picker.buttons["后旋"]; ready(draw); draw.tap()
        XCTAssertTrue(draw.isSelected)
        reveal(text("后旋后弯")); XCTAssertTrue(visible(text("后旋后弯")))
        try capture("draw-readout")
        let stun = picker.buttons["滑动"]
        // Re-reveal the picker if reading its output moved it above the viewport.
        reveal(stun, maximum: 8, backwards: true)
        ready(stun); stun.tap(); XCTAssertTrue(stun.isSelected)
        XCTAssertTrue(text("切线 90°").exists)
        try capture("stun-readout")
        try finish("学", "旋转与加塞")
    }
    func testLearn05AngleDynamicDisplayMenu() throws {
        try enter("学", "角度与瞄准")
        ready(app.buttons["paletteBall__8"], timeout: 45)
        let more = app.buttons["更多"].firstMatch; ready(more); more.tap()
        let grid = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "台面网格 4×8")).firstMatch
        ready(grid)
        try capture("display-menu-expanded")
        // Dismiss outside the popup, away from the ball table and palette.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.09)).tap()
        ready(app.buttons["paletteBall__8"])
        try finish("学", "角度与瞄准")
    }
    func testLearn06SeparationAtlasToggleTrack() throws {
        try atlas("分离角图谱", "separationAngleAtlas.spinLegend.0")
    }
    func testLearn07CushionAtlasToggleTrack() throws {
        try atlas("加塞吃库图谱", "cushionEnglishAtlas.spinLegend.0")
    }
    func testLearn08BallFeelLowerAdvice() throws {
        try enter("学", "浅谈球感")
        try readLower("训练建议", "将练习中建立的记忆带到球桌前。")
        try finish("学", "浅谈球感")
    }
    func testLearn09ContactPointSliderAndCurve() throws {
        try enter("学", "瞄准点对照表")
        try moveSlider("contactPointTable.thetaSlider")
        reveal(text("d/R = 2sin(θ) 曲线")); XCTAssertTrue(visible(text("d/R = 2sin(θ) 曲线")))
        try capture("lower-curve")
        try finish("学", "瞄准点对照表")
    }
    func testTheory01ThirtyDegreeSliderAndScope() throws {
        try thetaTheory("30° 法则", "theoryT01.thetaSlider", "容易失效的几处")
    }
    func testTheory02NinetyDegreeSliderAndScope() throws {
        try thetaTheory("90° 法则", "theoryT02.thetaSlider", "不成立的几处")
    }
    func testTheory03TangentSliderAndScope() throws {
        try thetaTheory("切线法则", "theoryT03.thetaSlider", "两个容易混的说法")
    }
    func testTheory04SpeedLowerScope() throws {
        try staticTheory("母球速度分级", "什么时候这样用", "极慢推杆防守，有时比最轻档还轻")
    }
    func testTheory05BackwardPlanningLowerScope() throws {
        try staticTheory("反向规划", "什么时候要降级", "桌上只剩两颗及以下：规划深度等于剩余球数")
    }
    func testTheory06KeyBallLowerScope() throws {
        try staticTheory("关键球原理", "什么时候成立", "关键球选择会变——前面几杆若失位")
    }
    func testTheory07ClustersLowerScope() throws {
        try staticTheory("球团管理", "什么时候可以松、什么时候别破", "本方没有清台路径时，球团反而是宝贵的母球藏身资源")
    }
    func testTheory08RiskLowerScope() throws {
        try staticTheory("风险报酬决策矩阵", "什么时候可以松一点", "二是球数：如果台上对手的球数已经是自己的两倍以上")
    }
    func testTheory09MinimumEnglishLowerScope() throws {
        try staticTheory("最少加塞原则", "什么时候仍要加塞", "加了塞以后，「30° / 90° / 切线」的输入端都要先按挤偏校正")
    }
    func testTheory10SafetyLowerScope() throws {
        try staticTheory("安全球三维度模型", "什么时候进这条线", "对手水平远高于自己时，弱防守可能反被踢库利用")
    }
    func testTheory11FlowLowerConsequences() throws {
        try staticTheory("清台 5 步决策流程", "跳步会付出什么代价", "失位了还按原计划打，一路雪崩")
    }
    func testTheory12QuickReferenceLowerLines() throws {
        try staticTheory("清台速查手册", "八句能立刻用的话", "把对手的目标球想成太阳，障碍球投下阴影")
    }
}
