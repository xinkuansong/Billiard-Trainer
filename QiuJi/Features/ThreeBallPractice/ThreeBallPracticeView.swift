import SwiftUI
import SwiftData

struct ThreeBallPracticeView: View {
    @StateObject private var vm: ThreeBallPracticeViewModel
    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    @ObservedObject private var owner = CurrentOwnerContext.shared
    @ObservedObject private var limiter = AngleUsageLimiter.threeBallTraining
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @StateObject private var questionNotices = BTRuleNoticeCenter()
    @StateObject private var resultNotices = BTRuleNoticeCenter()
    @StateObject private var operationNotices = BTRuleNoticeCenter()
    @State private var pocketOrientation: PocketDisplay.Orientation = .landscape

    init(is3D: Bool) { _vm = StateObject(wrappedValue: ThreeBallPracticeViewModel(is3D: is3D)) }
    var body: some View {
        ProAccessGate(requiresPremium: !vm.isBusy && (vm.phase != .settings && vm.record?.configuration.freePractice == true)) {
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
                    restarting: vm.record != nil, showsSpinOptions: false,
                    strokePlayback: Binding(get: { vm.playsStroke }, set: { vm.setPlaysStroke($0) }),
                    centerReference: Binding(get: { vm.showsReference }, set: { vm.setShowsReference($0) }),
                    prepareBatch: ThreeBallQuestionPreparer.Prepared.prepare,
                    onStart: { vm.start($0, prepared: $1) },
                    onCancel: { if !vm.cancelSettings() { dismiss() } })
                    .id(owner.ownerKey)
            default:
                tablePage.overlay {
                    if vm.phase == .summary {
                    Button { vm.reviewLastQuestion() } label: {
                        Color.black.opacity(0.45).ignoresSafeArea()
                    }.buttonStyle(.plain).accessibilityLabel("返回最后一题")
                        .accessibilityIdentifier("threeBall.reviewLast")
                    if let record = vm.record {
                        TrainingFinishContent(metrics: record.finishMetrics,
                            onRestart: { vm.restart() }, onComplete: { dismiss() })
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("threeBall.summary")
                    }
                    }
                }
            }
        }
        .onAppear { vm.limiter.isPremium = subscriptionManager.isPremium; vm.attach(context: context) }
        .onReceive(subscriptionManager.$isPremium) { vm.limiter.isPremium = $0; vm.refreshNextQuestion() }
        .onChange(of: limiter.questionsUsedToday) { _, _ in vm.refreshNextQuestion() }
        .onChange(of: owner.ownerKey) { _, _ in vm.ownerChanged() }
        .onChange(of: vm.pocketRequestID) { _, event in
            guard event != nil else { questionNotices.clear(); return }
            resultNotices.clear()
            questionNotices.show("请先选择绿圈的\(vm.record?.current?.secondBallNumber ?? 8)号球目标袋口", tone: .info, priority: .selection)
        }
        .onChange(of: vm.record?.current?.id) { _, _ in questionNotices.clear() }
        .onChange(of: vm.record?.current?.stage) { _, _ in questionNotices.clear() }
        .onChange(of: vm.record?.current?.plannedPocket) { _, _ in questionNotices.clear() }
        // Result feedback is an event, not a persistent copy of the sidebar.
        .onChange(of: resultNoticeID, initial: true) { _, event in
            guard event != nil else { resultNotices.clear(); return }
            resultNotices.show(resultNoticeText, tone: .info, priority: .ruling)
        }
        .onChange(of: vm.notice) { _, event in
            guard let event else { operationNotices.clear(); return }
            operationNotices.show(event.text, tone: .info, priority: .ruling)
        }
        .onDisappear { questionNotices.clear(); resultNotices.clear(); operationNotices.clear() }
        .overlay(alignment: .topLeading) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-threeBall.probe") {
                Color.clear.frame(width: 1, height: 1).accessibilityElement()
                    .accessibilityLabel("三球走位测试状态").accessibilityValue(vm.diagnostic)
                    .accessibilityIdentifier("threeBall.probe").allowsHitTesting(false)
            }
            #endif
        }
        .sheet(isPresented: $vm.needsSubscription, onDismiss: { vm.subscriptionDismissed() }) { SubscriptionView() }
        .alert("练习提示", isPresented: Binding(get: { vm.message != nil }, set: { if !$0 { vm.message = nil } })) {
            Button("知道了") { vm.message = nil }
        } message: { Text(vm.message ?? "") }
    }
    private var resultNoticeID: UUID? { vm.feedbackShot?.id }
    private var resultNoticeText: String { vm.feedbackShot?.resultText ?? "" }
    private var information: [BTTeachingInformation] {
        var result: [BTTeachingInformation] = []
        if let notice = operationNotices.message {
            return [.init(text: notice.text, kind: .notice, symbol: "info.circle", identifier: "threeBall.notice")]
        }
        if let notice = questionNotices.message {
            result.append(.init(text: notice.text, kind: .notice, symbol: "info.circle", identifier: "threeBall.question"))
        }
        if resultNotices.message != nil, !hidesPendingScore, vm.feedbackShot != nil {
            result.append(.init(text: resultNoticeText, kind: .readout, symbol: "info.circle", identifier: "threeBall.result"))
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
            allowsPocketSelection: vm.canSelectPocket, primaryTitle: vm.primaryTitle,
            primaryEnabled: (vm.isReplaying || vm.canAdjust || vm.phase == .result || vm.phase == .saveFailed)
                && !vm.cameraTransitionBusy && !vm.temporaryTopDownActive,
            onPrimary: {
                if vm.isReplaying { vm.stopPlayback() }
                else if vm.phase == .saveFailed { vm.retrySave() }
                else if vm.phase == .result { vm.next() }
                else { vm.strike() }
            }, onPaletteTap: { _ in },
            menuItems: [
                .init(id: "threeBall.trainingSettings", title: "训练设置", disclosure: true, disabled: vm.isBusy,
                      action: { vm.openSettings() }),
                .init(id: "threeBall.finish", title: "结束练习", disabled: vm.isBusy, action: { vm.finish() })
            ], refreshTrajectory: {}, onLayoutEditingChanged: vm.layoutEditingChanged,
            layoutEditingBlocked: vm.isBusy,
            onSpinChange: { vm.setSpin($0, $1) },
            paletteKeys: vm.paletteKeys, paletteRoles: vm.paletteRoles, showsPaletteRoleNumbers: true)
    }
    private var tablePage: some View {
        BTTeachingTablePage(vm: vm, titleLabel: vm.title, identifier: "threeBall", preferencePage: vm.preferencePage,
            insufficientSpaceMessage: "扩大窗口以显示完整球桌", onTrainingViewChange: { vm.switchTrainingView(to: $0) }, velocity: Binding(get: { vm.velocity }, set: { vm.velocity = $0 }),
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
                            .accessibilityIdentifier("threeBall.retry")
                            .freeControlItem("shot.undo", name: vm.playsStroke ? "重打" : "重试")
                        BTGeometricReferenceButton(tool: vm.geometryReference,
                            enabled: vm.canAdjust && !vm.cameraTransitionBusy,
                            size: layout.auxiliarySize, identifier: "threeBall.geometry",
                            prepare: { vm.prepareGeometryReference() })
                            .freeControlItem("shot.replay", name: "测量")
                    }
                }.frame(width: layout.columnWidth))
            },
            title: { Text(vm.title) }, leftContent: { _ in EmptyView() }, status: { EmptyView() })
    }

    private var sidebarInformation: some View {
        ThreeBallSidebarLayout {
            sidebarMetric("题目", value: vm.record?.configuration.freePractice == true
                ? "\(vm.record?.questionNumber ?? 1)" : "\(vm.record?.questionNumber ?? 1)/15",
                identifier: "threeBall.questionInfo", compact: false)
            sidebarMetric("均分", value: displayedAverage.map { String(format: "%.1f", $0) } ?? "—",
                          identifier: "threeBall.averageScore", compact: false)
            VStack(spacing: Spacing.xs) {
                VStack(spacing: 2) {
                    Text(vm.cutAngleDegrees.map { "切角 \(Int($0.rounded()))°" } ?? "切角 —")
                    ThicknessOverlapIcon(cutAngle: vm.cutAngleDegrees ?? 0)
                        .opacity(vm.cutAngleDegrees == nil ? 0.3 : 1).accessibilityHidden(true)
                }
                .font(.btCaption2).monospacedDigit().foregroundStyle(HUDStyle.valueMeasured)
                .accessibilityElement(children: .combine).accessibilityIdentifier("threeBall.cutAngle")
                Text("第\((vm.record?.current?.stage ?? 0) + 1)/2杆")
                    .font(.btCaption2).foregroundStyle(HUDStyle.valueMeasured)
                    .accessibilityIdentifier("threeBall.stage")
            }
            VStack(spacing: Spacing.xs) {
                if vm.shouldShowReference {
                    routeLegend("参考", color: Color(SeparationRouteStyle.reference), dash: SeparationRouteStyle.legendDash)
                        .accessibilityIdentifier("threeBall.referenceLegend")
                        .accessibilityValue("中杆中力，无高低杆、无左右塞，杆速2.0")
                }
                if vm.record?.latestShot != nil {
                    routeLegend("实际", color: Color(SeparationRouteStyle.actual), dash: SeparationRouteStyle.legendDash)
                        .accessibilityIdentifier("threeBall.actualLegend")
                }
            }
            sidebarMetric("本题均分", value: (hidesPendingScore ? nil : vm.record?.questionAverage).map { String(format: "%.1f", $0) } ?? "—",
                identifier: "threeBall.questionAverage", compact: false)
            if vm.record?.current?.stage == 1 {
                Text("首杆 " + (vm.record?.firstStageScore.map { String(format: "%.1f", $0) } ?? "—"))
                    .font(.btCaption2).monospacedDigit().foregroundStyle(HUDStyle.valueMeasured)
                    .accessibilityIdentifier("threeBall.firstScore")
            }
            sidebarMetric(vm.latestScoreTitle, value: latestValue, identifier: "threeBall.latestScore", compact: false)
        }
    }

    private var latestValue: String {
        guard !hidesPendingScore, let shot = vm.record?.latestShot else { return "—" }
        return String(format: "%.1f", shot.freeScore)
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
private struct ThreeBallSidebarLayout: Layout {
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
