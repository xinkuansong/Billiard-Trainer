import SwiftUI

struct OneCushionBankLessonView: View {
    @State private var simulation = BankLessonSimulation()
    @State private var reference: BankLessonModel.Shot?
    @State private var computed: BankLessonModel.Shot?
    @State private var failure: String?
    @State private var speedIndex = 15.0
    @State private var progress = 0.0
    @State private var targetX = Double(BankLessonModel.target.x)
    @State private var aimDegrees = 0.0
    @State private var showsMirror = true
    @State private var showsIdeal = true
    @State private var showsActual = true
    @State private var showsReference = true
    @State private var observesAfter = false

    private var current: BankLessonModel.Shot? {
        computed?.speedIndex == Int(speedIndex) ? computed : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                overviewSection
                mirrorSection
                ghostSection
                comparisonSection
                powerSection
                observationSection
                LearnDocSectionCard(title: "接着练一练") {
                    LearnDocTextLink(title: "翻袋练习", subtitle: "选择一库，把这条路线练熟。", route: .bankPractice2D)
                    LearnDocTextLink(title: "翻袋解球", subtitle: "换一个球形，观察吃库点怎样变化。", route: .bankShot)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xxxxl)
            .learnDocumentWidth()
        }
        .background(Color.btBG)
        .background { DailyTableOrientation(landscape: false, allowsTabletRotation: true) }
        .learnReadingNavigation(title: "一库翻袋")
        .task(id: Int(speedIndex)) {
            let requested = Int(speedIndex)
            failure = nil
            do {
                // Coalesce slider changes; cancellation prevents old work publishing into a new selection.
                if reference != nil { try await Task.sleep(for: .milliseconds(80)) }
                let baseline = try await simulation.shot(speedIndex: 15)
                try Task.checkCancellation()
                reference = baseline
                let shot = requested == 15 ? baseline : try await simulation.shot(speedIndex: requested)
                try Task.checkCancellation()
                computed = shot
            } catch is CancellationError {
                // The new slider selection (or page departure) owns the next result.
            } catch {
                failure = "当前路线暂未算完，请调整力度后重试。"
            }
        }
    }

    private var overviewSection: some View {
        LearnDocSectionCard(title: "先看目标球怎么进袋") {
            LearnDocText.body("一库翻袋，是让目标球先碰一次库边，再进入指定球袋。这一球，我们把 1 号球翻进对面的中袋。")
            BankLessonFigure(kind: .overview, reference: reference, progress: progress)
                .accessibilityIdentifier("bankLesson.overview")
            legend([("瞄准线", .aim, false), ("母球轨迹", .aim, true), ("目标球轨迹", .pot(number: 1), true)])
            controlTitle("查看击球过程", value: playbackLabel)
            Slider(value: $progress, in: 0...1)
                .disabled(reference == nil)
                .accessibilityLabel("查看击球过程")
                .accessibilityValue(playbackLabel)
                .accessibilityIdentifier("bankLesson.progress")
            LearnDocText.footnote("示范条件：中杆、无侧塞，杆速 1.5 m/s。")
        }
    }

    private var playbackLabel: String {
        guard let reference else { return failure ?? "正在计算示范路线" }
        if progress == 0 { return "出杆前" }
        let time = Float(progress) * (reference.objectPocketTime ?? reference.duration)
        if progress == 1 { return reference.objectPocket == "pocket_4" ? "目标球入袋" : "示范结束" }
        if time < (reference.contactTime ?? 0) { return "母球接近目标球" }
        return time < (reference.cushionTimes.first ?? .infinity) ? "目标球走向库边" : "目标球反弹入袋"
    }

    private var mirrorSection: some View {
        LearnDocSectionCard(title: "把目标球映到库外") {
            LearnDocText.body("在库外找一颗与目标球对称的镜像球，把镜像球的球心与目标袋口连起来。连线与反弹基准线的交点，就是几何参考吃库点。")
            BankLessonFigure(kind: .mirror, targetX: targetX, showsMirror: showsMirror)
                .accessibilityIdentifier("bankLesson.mirror")
            Toggle("显示镜像辅助线", isOn: $showsMirror)
                .font(.btFootnote14).accessibilityIdentifier("bankLesson.mirrorToggle")
            controlTitle("左右移动目标球", value: abs(targetX - Double(BankLessonModel.target.x)) < 0.002 ? "示范位置" : "距长边中点 \(Int((-targetX * 100).rounded())) cm")
            Slider(value: $targetX, in: -0.85 ... -0.35, step: 0.001)
                .accessibilityLabel("左右移动目标球")
                .accessibilityValue("距长边中点 \(Int((-targetX * 100).rounded())) 厘米")
                .accessibilityIdentifier("bankLesson.target")
            LearnDocText.footnote("移动只作用于本图。基准线按球心反弹位置画出，与库边相差一个球半径。")
            LearnDocText.body("目标球换了位置，参考吃库点也会跟着变。先理解这条折线，再寻找母球的瞄准方向。")
        }
    }

    private var ghostSection: some View {
        LearnDocSectionCard(title: "找到母球该到的位置") {
            LearnDocText.body("沿目标球到吃库点的方向，向后放一颗与目标球相切的假想母球。母球瞄准这颗假想球的球心，就得到了几何参考方向。")
            BankLessonFigure(kind: .ghost, aimDegrees: aimDegrees)
                .accessibilityIdentifier("bankLesson.ghost")
            legend([("参考瞄准线", .hint, true), ("当前瞄准线", .aim, false)])
            controlTitle("试着左右微调", value: aimDegrees == 0 ? "参考方向" : String(format: "%@ %.1f°", aimDegrees > 0 ? "左偏" : "右偏", abs(aimDegrees)))
            Slider(value: $aimDegrees, in: -4...4, step: 0.1)
                .accessibilityLabel("试着左右微调")
                .accessibilityIdentifier("bankLesson.aim")
            Text(aimDegrees == 0 ? "试瞄线穿过假想球球心。" : "试瞄线偏离假想球球心约 \(Int(BankLessonModel.trial(degrees: aimDegrees).missMM.rounded())) mm。先回到参考方向，再体会这点差别。")
                .font(.btFootnote14).foregroundStyle(Color.btPrimary)
                .accessibilityIdentifier("bankLesson.aimFeedback")
            LearnDocText.footnote("局部放大 · 本图只判断几何瞄准关系。")
        }
    }

    private var comparisonSection: some View {
        LearnDocSectionCard(title: "几何参考，还要用出杆验证") {
            LearnDocText.body("镜像法帮你找到起点。实际击球时，球的旋转、速度和库边反弹都会影响路线，不能只凭一条对称线保证进球。")
            BankLessonFigure(kind: .compare, reference: reference, showsIdeal: showsIdeal, showsActual: showsActual)
            Toggle("几何参考", isOn: $showsIdeal).accessibilityIdentifier("bankLesson.ideal")
            Toggle("示范路线", isOn: $showsActual).accessibilityIdentifier("bankLesson.actual")
            LearnDocText.body("这杆示范用了中杆、无侧塞。两条路线很接近，可以分别开关对照。下面保持瞄准方向不变，只调整力度，看看目标球怎样走。")
        }
        .font(.btFootnote14)
    }

    private var powerSection: some View {
        LearnDocSectionCard(title: "同一个瞄准，换一种力度") {
            LearnDocText.body("先用 1.5 m/s 这杆作对照。往左减力、往右加力，观察目标球能否到达库边、反弹后走向哪里，以及最终有没有进目标袋。")
            controlTitle("力度 · 杆速", value: String(format: "%.1f m/s", speedIndex / 10))
            Slider(value: $speedIndex, in: 6...40, step: 1)
                .accessibilityLabel("力度，杆速")
                .accessibilityValue(String(format: "%.1f m/s", speedIndex / 10))
                .accessibilityIdentifier("bankLesson.power")
            BankLessonFigure(kind: .power, reference: reference, current: current, showsReference: showsReference)
                .accessibilityIdentifier("bankLesson.powerFigure")
            legend([("1.5 m/s 对照", .hint, true), ("当前力度轨迹", .pot(number: 1), true)])
            Text(failure ?? current?.result ?? "正在计算当前力度路线…")
                .font(.btFootnote14).foregroundStyle(current?.isOneBank == true ? Color.btPrimary : Color.btText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("bankLesson.result")
            Toggle("显示 1.5 m/s 对照线", isOn: $showsReference)
                .font(.btFootnote14).accessibilityIdentifier("bankLesson.reference")
            Text("中袋附近 · 放大看").font(.btFootnote14)
            BankLessonFigure(kind: .pocket, reference: reference, current: current, showsReference: showsReference)
                .accessibilityIdentifier("bankLesson.pocket")
            LearnDocText.body("加力不只是让球多走一段。母球碰球时的转动状态、碰撞传递和吃库反弹也会影响路线。把入袋前的细微差别放大，才容易看清。")
            LearnDocText.footnote("球位、瞄准方向、中杆与无侧塞保持不变。每 0.1 m/s 一档，不随力度自动修正瞄准。这里展示模拟结果，练习时还要结合实际球台验证。")
        }
    }

    private var observationSection: some View {
        LearnDocSectionCard(title: "没进时，分两段看") {
            Picker("观察哪一段路线", selection: $observesAfter) {
                Text("碰库前").tag(false)
                Text("碰库后").tag(true)
            }
            .pickerStyle(.segmented).accessibilityIdentifier("bankLesson.phase")
            BankLessonFigure(kind: .observe, reference: reference, observesAfter: observesAfter)
            LearnDocText.body(observesAfter ? "吃库点接近预期，再看反弹后从袋口哪一侧经过。保持球形与出杆一致，逐步检查力度和意外带塞。" : "先看目标球有没有经过你预计的吃库点。如果这一段就偏了，先检查瞄准与击球厚薄。")
                .accessibilityIdentifier("bankLesson.observation")
            LearnDocText.footnote("练习时尽量一次只改一个条件，才能知道偏差从哪里来。")
        }
    }

    private func controlTitle(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.btFootnote14)
            Spacer(minLength: Spacing.sm)
            Text(value).font(.btCaption).foregroundStyle(Color.btTextSecondary).monospacedDigit()
        }
    }

    private func legend(_ entries: [(String, Color, Bool)]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.lg) { legendEntries(entries) }
            VStack(alignment: .leading, spacing: Spacing.xs) { legendEntries(entries) }
        }
        .frame(maxWidth: .infinity)
    }

    private func legendEntries(_ entries: [(String, Color, Bool)]) -> some View {
        ForEach(entries.indices, id: \.self) { index in
            let entry = entries[index]
            HStack(spacing: Spacing.xs) {
                Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: 20, y: 0)) }
                    .stroke(entry.1 == FigureLine.pot(number: 1) ? entry.1 : Color.btTextSecondary,
                            style: StrokeStyle(lineWidth: 2, dash: entry.2 ? [4, 3] : []))
                    .frame(width: 20, height: 2).accessibilityHidden(true)
                Text(entry.0).font(.btCaption).foregroundStyle(Color.btTextSecondary)
            }
        }
    }
}

private extension Color {
    static var aim: Color { FigureLine.aim }
    static var hint: Color { FigureLine.hint }
    static func pot(number: Int) -> Color { FigureLine.pot(number: number) }
}

#Preview("Light") { NavigationStack { OneCushionBankLessonView() }.preferredColorScheme(.light) }
#Preview("Dark") { NavigationStack { OneCushionBankLessonView() }.preferredColorScheme(.dark) }
