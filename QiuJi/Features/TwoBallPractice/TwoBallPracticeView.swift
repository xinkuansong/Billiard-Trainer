import SwiftUI
import SwiftData

struct TwoBallPracticeView: View {
    @StateObject private var vm: TwoBallPracticeViewModel
    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    @ObservedObject private var owner = CurrentOwnerContext.shared
    @ObservedObject private var limiter = AngleUsageLimiter.twoBallTraining
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @StateObject private var questionNotices = BTRuleNoticeCenter()
    @StateObject private var resultNotices = BTRuleNoticeCenter()
    @State private var pocketOrientation: PocketDisplay.Orientation = .landscape

    init(is3D: Bool) { _vm = StateObject(wrappedValue: TwoBallPracticeViewModel(is3D: is3D)) }
    var body: some View {
        ProAccessGate(requiresPremium: !vm.isBusy && (vm.is3D || (vm.phase != .settings && vm.record?.configuration.freePractice == true))) {
            content
        }
    }
    private var content: some View {
        Group {
            switch vm.phase {
            case .loading:
                ProgressView("正在读取练习…")
            case .settings:
                SceneTrainingSettings(route: vm.route, configuration: vm.record?.configuration ?? .init(),
                    restarting: vm.record != nil, showsSpinOptions: true,
                    strokePlayback: Binding(get: { vm.playsStroke }, set: { vm.setPlaysStroke($0) }),
                    centerReference: Binding(get: { vm.showsReference }, set: { vm.setShowsReference($0) }),
                    twoBallMode: $vm.selectedMode,
                    prepareBatch: TwoBallQuestionPreparer.Prepared.prepare,
                    onStart: { vm.start($0, prepared: $1) },
                    onCancel: { if !vm.cancelSettings() { dismiss() } })
                    .id(owner.ownerKey)
            default:
                tablePage.overlay {
                    if vm.phase == .summary {
                    Button { vm.reviewLastQuestion() } label: {
                        Color.black.opacity(0.45).ignoresSafeArea()
                    }.buttonStyle(.plain).accessibilityLabel("返回最后一题")
                        .accessibilityIdentifier("twoBall.reviewLast")
                    if let record = vm.record {
                        TrainingFinishContent(metrics: record.finishMetrics,
                            onRestart: { vm.restart() }, onComplete: { dismiss() })
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("twoBall.summary")
                    }
                    }
                }
            }
        }
        .task { await TwoBallQuestionPreparer.prewarm() }
        .onAppear { vm.limiter.isPremium = subscriptionManager.isPremium; vm.attach(context: context) }
        .onReceive(subscriptionManager.$isPremium) { vm.limiter.isPremium = $0; vm.refreshNextQuestion() }
        .onChange(of: limiter.questionsUsedToday) { _, _ in vm.refreshNextQuestion() }
        .onChange(of: owner.ownerKey) { _, _ in vm.ownerChanged() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            TwoBallBankStore.releaseDecodedShards()
        }

        .onChange(of: vm.record?.current?.id, initial: true) { _, questionID in
            guard questionID != nil else { questionNotices.clear(); return }
            questionNotices.show(questionPrompt, tone: .info, priority: .selection)
        }
        .onChange(of: vm.record?.current?.routeIndex) { _, _ in
            questionNotices.show(questionPrompt, tone: .info, priority: .selection)
        }
        // Result feedback is an event, not a persistent copy of the sidebar.
        .onChange(of: resultNoticeID, initial: true) { _, event in
            guard event != nil else { resultNotices.clear(); return }
            resultNotices.show(resultNoticeText, tone: .info, priority: .ruling)
        }
        .onDisappear { questionNotices.clear(); resultNotices.clear() }
        .overlay(alignment: .topLeading) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-twoBall.probe") {
                Color.clear.frame(width: 1, height: 1).accessibilityElement()
                    .accessibilityLabel("两球走位测试状态").accessibilityValue(vm.diagnostic)
                    .accessibilityIdentifier("twoBall.probe").allowsHitTesting(false)
            }
            #endif
        }
        .sheet(isPresented: $vm.needsSubscription, onDismiss: { vm.subscriptionDismissed() }) { SubscriptionView() }
        .alert("练习提示", isPresented: Binding(get: { vm.message != nil }, set: { if !$0 { vm.message = nil } })) {
            Button("知道了") { vm.message = nil }
        } message: { Text(vm.message ?? "") }
    }
    private var questionPrompt: String {
        "①进\(PocketDisplay.name(index: vm.selectedPocketIndex, orientation: pocketOrientation)) · ②走\(PocketDisplay.name(index: vm.record?.current?.secondPocket ?? 0, orientation: pocketOrientation))"
    }
    private var resultNoticeID: String? {
        guard (vm.phase == .result || vm.phase == .aiming || vm.phase == .saveFailed),
              let shot = vm.record?.latestShot else { return nil }
        return "\(shot.id.uuidString):\(vm.record?.showingResult == true)"
    }
    private var resultNoticeText: String {
        guard let shot = vm.record?.latestShot else { return "" }
        let previous = vm.record?.showingResult == false && !vm.isReplaying
        let prefix = previous ? "上杆" : "本杆"
        let text: String
        if let failure = shot.failure {
            text = "\(prefix)得分 0.0 分 · \(failure)"
        } else if vm.mode == .trajectory {
            text = "\(prefix)得分 \(String(format: "%.1f", shot.trajectoryScore)) 分"
        } else if let score = shot.freeScore {
            text = "\(prefix)得分 \(String(format: "%.1f", score)) 分"
        } else if let difficulty = shot.difficulty {
            text = "旧版难度 \(String(format: "%.3f", difficulty.value))"
        } else { text = "\(prefix)无正向直击线路" }
        return text
    }
    private var information: [BTTeachingInformation] {
        var result: [BTTeachingInformation] = []
        if questionNotices.message != nil {
            result.append(.init(text: questionPrompt, kind: .notice, symbol: "info.circle", identifier: "twoBall.question"))
        }
        if resultNotices.message != nil, !hidesPendingScore, vm.record?.latestShot != nil {
            result.append(.init(text: resultNoticeText, kind: .readout, symbol: "info.circle", identifier: "twoBall.result"))
        }
        return result
    }
    private var controls: BTTablePlanningControls {
        .init(spinX: Binding(get: { Double(vm.input.spinX) }, set: { vm.setSpin($0, Double(vm.input.spinY)) }),
            spinY: Binding(get: { Double(vm.input.spinY) }, set: { vm.setSpin(Double(vm.input.spinX), $0) }),
            transparency: Binding(get: { tablePreferences.snapshot(for: vm.preferencePage)[.transparency] },
                set: { tablePreferences.apply(.transparency, value: $0, to: vm.preferencePage) }),
            velocityRange: ShotTuning.velocityRange, instrumentsEnabled: vm.canAdjust,
            assessmentMode: true, allowsAssessmentSpinEditing: true,
            defersStrikeAccessUntilSubmission: false,
            locksSceneInteraction: vm.isBusy, isAnimating: vm.isBusy, paletteEnabled: false,
            allowsPocketSelection: false, primaryTitle: vm.primaryTitle,
            primaryEnabled: (vm.isReplaying || !vm.isBusy || vm.phase == .saveFailed)
                && !vm.cameraTransitionBusy && !vm.temporaryTopDownActive,
            onPrimary: {
                if vm.isReplaying { vm.stopPlayback() }
                else if vm.phase == .saveFailed { vm.retrySave() }
                else if vm.phase == .result { vm.next() }
                else { vm.strike() }
            }, onPaletteTap: { _ in },
            menuItems: [
                .init(id: "twoBall.trainingSettings", title: "训练设置", disclosure: true, disabled: vm.isBusy,
                      action: { vm.openSettings() }),
                .init(id: "twoBall.finish", title: "结束练习", disabled: vm.isBusy, action: { vm.finish() })
            ], refreshTrajectory: {}, onLayoutEditingChanged: vm.layoutEditingChanged,
            layoutEditingBlocked: vm.isBusy,
            onSpinChange: { vm.setSpin($0, $1) })
    }
    private var tablePage: some View {
        BTTeachingTablePage(vm: vm, titleLabel: vm.title, identifier: "twoBall", preferencePage: vm.preferencePage,
            fixedView3D: vm.is3D, velocity: Binding(get: { vm.velocity }, set: { vm.velocity = $0 }),
            planning: controls, information: information, usesStandardTitle: true, fitsLongTitle: true, showsPalette: true,
            onPocketOrientationChange: { pocketOrientation = $0 },
            pairedLeftContent: { layout in
                AnyView(VStack(spacing: layout.groupSpacing) {
                    // Use the full vacant direction lane without shifting the action slots.
                    VStack(spacing: layout.groupSpacing) {
                        Color.clear.frame(height: layout.topDiameter + 14)
                        BTTeachingAimRulerSpace(layout: layout)
                    }.overlay(alignment: .top) {
                        GeometryReader { geometry in
                            ScrollView(.vertical) {
                                sidebarInformation
                                    .frame(minHeight: geometry.size.height, alignment: .top)
                            }.scrollBounceBehavior(.basedOnSize)
                        }.padding(.bottom, Spacing.sm)
                        .frame(width: layout.columnWidth)
                    }
                    let actions = layout.horizontalActions
                        ? AnyLayout(HStackLayout(spacing: layout.groupSpacing))
                        : AnyLayout(VStackLayout(spacing: layout.groupSpacing))
                    actions {
                        BTHUDCompactAction(title: vm.playsStroke ? "重打" : "重试", symbol: "arrow.uturn.backward", size: layout.auxiliarySize) { vm.retry() }
                            .disabled(!vm.canRetry)
                            .accessibilityIdentifier("twoBall.retry")
                            .freeControlItem("shot.undo", name: vm.playsStroke ? "重打" : "重试")
                        BTHUDCompactAction(title: vm.playsStroke ? "回放" : "击球", symbol: "play.rectangle", size: layout.auxiliarySize) { vm.replayLastShot() }
                            .disabled(!vm.canPlayback)
                            .accessibilityIdentifier("twoBall.playback")
                            .freeControlItem("shot.replay", name: vm.playsStroke ? "回放" : "击球")
                    }
                }.frame(width: layout.columnWidth))
            },
            title: { Text(vm.title) }, leftContent: { _ in EmptyView() }, status: { EmptyView() })
    }

    private var sidebarInformation: some View {
        TwoBallSidebarLayout {
            sidebarMetric("题目", value: vm.record?.configuration.freePractice == true
                ? "\(vm.record?.questionNumber ?? 1)" : "\(vm.record?.questionNumber ?? 1)/20",
                identifier: "twoBall.questionInfo", compact: false)
            sidebarMetric("均分", value: displayedAverage.map { String(format: "%.1f", $0) } ?? "—",
                          identifier: "twoBall.averageScore", compact: false)
            VStack(spacing: Spacing.xs) {
                VStack(spacing: 2) {
                    Text(vm.cutAngleDegrees.map { "切角 \(Int($0.rounded()))°" } ?? "切角 —")
                    ThicknessOverlapIcon(cutAngle: vm.cutAngleDegrees ?? 0)
                        .opacity(vm.cutAngleDegrees == nil ? 0.3 : 1).accessibilityHidden(true)
                }
                .font(.btCaption2).monospacedDigit().foregroundStyle(HUDStyle.valueMeasured)
                .accessibilityElement(children: .combine).accessibilityIdentifier("twoBall.cutAngle")
                if vm.mode == .trajectory, let question = vm.record?.current {
                    Text("轨迹: \(question.routeIndex + 1)/\(question.routes.count)")
                        .font(.btCaption2).monospacedDigit().foregroundStyle(HUDStyle.valueMeasured)
                        .fixedSize(horizontal: true, vertical: false).accessibilityIdentifier("twoBall.routeInfo")
                }
            }
            VStack(spacing: Spacing.xs) {
                if vm.mode == .trajectory {
                    routeLegend("目标", color: Color(SeparationRouteStyle.target), dash: SeparationRouteStyle.legendDash)
                }
                if vm.shouldShowReference {
                    routeLegend("参考", color: Color(SeparationRouteStyle.reference), dash: SeparationRouteStyle.legendDash)
                        .accessibilityIdentifier("twoBall.referenceLegend")
                        .accessibilityValue("中杆中力，无高低杆、无左右塞，杆速2.0")
                }
                if vm.record?.latestShot != nil {
                    routeLegend("实际", color: Color(SeparationRouteStyle.actual), dash: SeparationRouteStyle.legendDash)
                        .accessibilityIdentifier("twoBall.actualLegend")
                }
            }
            sidebarMetric(vm.mode == .trajectory ? "轨迹均分" : "本题均分", value: vm.record?.currentRouteAverage(
                excluding: hidesPendingScore ? vm.record?.latestShot?.id : nil).map { String(format: "%.1f", $0) } ?? "—",
                identifier: "twoBall.routeAverageScore", compact: false)
            sidebarMetric(vm.latestScoreTitle, value: latestValue, identifier: "twoBall.latestScore", compact: false)
        }
    }

    private var latestValue: String {
        guard !hidesPendingScore, let shot = vm.record?.latestShot else { return "—" }
        if vm.mode == .trajectory { return String(format: "%.1f", shot.trajectoryScore) }
        return shot.freeScore.map { String(format: "%.1f", $0) } ?? "—"
    }

    private var hidesPendingScore: Bool { !vm.isReplaying && vm.phase == .playing }
    private var displayedAverage: Double? {
        guard !hidesPendingScore else { return nil }
        return vm.record?.averageScore
    }

    private func sidebarMetric(_ title: String, value: String, identifier: String, compact: Bool) -> some View {
        VStack(spacing: compact ? 0 : 2) {
            Text(title).font(.btCaption2).foregroundStyle(HUDStyle.labelColor)
            Text(value).font(.btCaption.weight(.semibold)).monospacedDigit().foregroundStyle(.white).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func routeLegend(_ label: String, color: Color, dash: [CGFloat]) -> some View {
        HStack(spacing: Spacing.xs) {
            Path { path in path.move(to: .init(x: 0, y: 1)); path.addLine(to: .init(x: 14, y: 1)) }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: dash))
                .frame(width: 14, height: 2).accessibilityHidden(true)
            Text(label).font(.btCaption2).foregroundStyle(.white)
        }.accessibilityElement(children: .combine)
    }
}

/// Measures uncompressed groups first, then spends spare lane height between them.
/// A short window scrolls the information without moving or obscuring the action slots.
private struct TwoBallSidebarLayout: Layout {
    private func sizes(_ subviews: Subviews, width: CGFloat?) -> [CGSize] {
        subviews.map { $0.sizeThatFits(.init(width: width, height: nil)) }
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = sizes(subviews, width: proposal.width)
        let minimum = sizes.reduce(CGFloat.zero) { $0 + $1.height } + CGFloat(max(0, sizes.count-1))*2
        return .init(width: proposal.width ?? sizes.map(\.width).max() ?? 0,
                     height: max(minimum, proposal.height ?? minimum))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = sizes(subviews, width: bounds.width)
        let extra = bounds.height-sizes.reduce(CGFloat.zero) { $0+$1.height }
        let gap = min(Spacing.md, max(2, extra/CGFloat(max(1, sizes.count-1))))
        var y = bounds.minY
        for (index, view) in subviews.enumerated() {
            view.place(at: .init(x: bounds.midX, y: y), anchor: .top,
                       proposal: .init(width: bounds.width, height: sizes[index].height))
            y += sizes[index].height+gap
        }
    }
}
