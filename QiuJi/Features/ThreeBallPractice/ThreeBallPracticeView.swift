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
            questionNotices.show("请先选择下一球（\(vm.record?.current?.secondBallNumber ?? 8)号）的目标袋口", tone: .info, priority: .selection)
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
            result.append(.init(text: resultNoticeText, kind: .readout, symbol: "info.circle", identifier: "threeBall.result",
                detailText: vm.feedbackShot?.scoreDetails))
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
            paletteKeys: vm.paletteKeys, maximumPaletteCount: 3, paletteRoles: vm.paletteRoles, showsPaletteRoleNumbers: true)
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
                                sidebarInformation(availableHeight: geometry.size.height)
                                    .frame(minHeight: geometry.size.height, alignment: .top)
                            }.scrollBounceBehavior(.basedOnSize)
                                .accessibilityIdentifier("threeBall.sidebarScroll")
                        }.frame(width: layout.columnWidth)
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

    private func sidebarInformation(availableHeight: CGFloat) -> some View {
        ThreeBallSidebarLayout(availableHeight: availableHeight) {
            Text(vm.record?.configuration.freePractice == true
                ? "\(vm.record?.questionNumber ?? 1)" : "\(vm.record?.questionNumber ?? 1)/15")
                .font(.btCaption.weight(.semibold)).monospacedDigit().foregroundStyle(.white)
                .accessibilityLabel("题目")
                .accessibilityValue(vm.record?.configuration.freePractice == true
                    ? "第\(vm.record?.questionNumber ?? 1)题" : "\(vm.record?.questionNumber ?? 1)/15")
                .accessibilityIdentifier("threeBall.questionInfo")
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
            .layoutValue(key: ThreeBallSidebarGap.self, value: Spacing.sm)
            if vm.shouldShowReference || vm.record?.latestShot != nil {
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
            }
            sidebarMetric("本题均分", value: (hidesPendingScore ? nil : vm.record?.questionAverage).map { String(format: "%.1f", $0) } ?? "—",
                identifier: "threeBall.questionAverage", compact: false)
                .layoutValue(key: ThreeBallSidebarGap.self, value: Spacing.sm)
            if !hidesPendingScore, let shot = vm.record?.latestShot {
                BTScoreDetailsButton(detail: shot.scoreDetails, identifier: "threeBall.latestScore", minimumHeight: Spacing.xxxl) {
                    sidebarMetric(vm.latestScoreTitle, value: latestValue, identifier: "threeBall.scoreValue", compact: false, showsInfo: true)
                }
                .layoutValue(key: ThreeBallSidebarGap.self, value: Spacing.xs)
            } else if vm.record?.current?.stage != 1 {
                sidebarMetric(vm.latestScoreTitle, value: latestValue, identifier: "threeBall.latestScore", compact: false)
                    .layoutValue(key: ThreeBallSidebarGap.self, value: Spacing.xs)
            }
            if vm.record?.current?.stage == 1, !hidesPendingScore,
               let first = vm.record?.firstStageCheckpoint?.shot {
                BTScoreDetailsButton(detail: first.scoreDetails, identifier: "threeBall.firstScore", minimumHeight: Spacing.xxxl) {
                    sidebarMetric("首杆", value: String(format: "%.1f", first.freeScore),
                        identifier: "threeBall.firstScoreValue", compact: false, showsInfo: true)
                }
                .layoutValue(key: ThreeBallSidebarGap.self, value: Spacing.sm)
            }
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

    private func sidebarMetric(_ title: String, value: String, identifier: String, compact: Bool, showsInfo: Bool = false) -> some View {
        VStack(spacing: compact ? 0 : 2) {
            HStack(spacing: 2) {
                Text(title)
                if showsInfo { Image(systemName: "info.circle").accessibilityHidden(true) }
            }.font(.btCaption2).foregroundStyle(HUDStyle.labelColor)
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

// Spend spare height at semantic boundaries; never spread every metric equally.
private struct ThreeBallSidebarGap: LayoutValueKey {
    static let defaultValue: CGFloat = 2
}

private struct ThreeBallSidebarLayout: Layout {
    let availableHeight: CGFloat

    private func measurements(width: CGFloat?, subviews: Subviews) -> (sizes: [CGSize], gaps: [CGFloat]) {
        let sizes = subviews.map { $0.sizeThatFits(.init(width: width, height: nil)) }
        let desiredGaps = subviews.indices.map { $0 == 0 ? 0 : subviews[$0][ThreeBallSidebarGap.self] }
        let minimumGaps = desiredGaps.map { min(2, $0) }
        let naturalHeight = sizes.reduce(0) { $0 + $1.height } + minimumGaps.reduce(0, +)
        let extra = zip(desiredGaps, minimumGaps).map { $0 - $1 }
        let budget = extra.reduce(0, +)
        let fraction = budget > 0 ? min(1, max(0, availableHeight - naturalHeight) / budget) : 0
        return (sizes, zip(minimumGaps, extra).map { $0 + $1 * fraction })
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let measured = measurements(width: proposal.width, subviews: subviews)
        return CGSize(width: proposal.width ?? measured.sizes.map(\.width).max() ?? 0,
                      height: measured.sizes.reduce(0) { $0 + $1.height } + measured.gaps.reduce(0, +))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let measured = measurements(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for index in subviews.indices {
            y += measured.gaps[index]
            subviews[index].place(at: CGPoint(x: bounds.midX, y: y), anchor: .top,
                                 proposal: .init(width: bounds.width, height: measured.sizes[index].height))
            y += measured.sizes[index].height
        }
    }
}
