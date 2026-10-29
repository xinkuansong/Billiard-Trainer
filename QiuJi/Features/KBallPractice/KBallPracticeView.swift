import SwiftUI
import SwiftData

struct KBallPracticeView: View {
    @StateObject private var vm: KBallPracticeViewModel
    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    @ObservedObject private var owner = CurrentOwnerContext.shared
    @ObservedObject private var limiter = AngleUsageLimiter.kBallTraining
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @StateObject private var questionNotices = BTRuleNoticeCenter()
    @StateObject private var resultNotices = BTRuleNoticeCenter()
    @StateObject private var operationNotices = BTRuleNoticeCenter()
    @State private var pocketOrientation: PocketDisplay.Orientation = .landscape

    init(is3D: Bool) { _vm = StateObject(wrappedValue: KBallPracticeViewModel(is3D: is3D)) }
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
                KBallPracticeSettings(configuration: vm.record?.configuration ?? .init(), restarting: vm.record != nil,
                    onStart: { vm.start($0, prepared: $1) },
                    onCancel: { if !vm.cancelSettings() { dismiss() } })
                    .id(owner.ownerKey)
            default:
                tablePage.overlay {
                    if vm.phase == .summary {
                    Button { vm.reviewLastQuestion() } label: {
                        Color.black.opacity(0.45).ignoresSafeArea()
                    }.buttonStyle(.plain).accessibilityLabel("返回最后一题")
                        .accessibilityIdentifier("kBall.reviewLast")
                    if let record = vm.record {
                        TrainingFinishContent(metrics: record.finishMetrics,
                            onRestart: { vm.restart() }, onComplete: { dismiss() })
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("kBall.summary")
                    }
                    }
                }
            }
        }
        .onAppear { vm.limiter.isPremium = subscriptionManager.isPremium; vm.attach(context: context) }
        .onReceive(subscriptionManager.$isPremium) { vm.limiter.isPremium = $0; vm.refreshNextQuestion() }
        .onChange(of: limiter.questionsUsedToday) { _, _ in vm.refreshNextQuestion() }
        .onChange(of: owner.ownerKey) { _, _ in vm.ownerChanged() }
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
            if ProcessInfo.processInfo.arguments.contains("-kBall.probe") {
                Color.clear.frame(width: 1, height: 1).accessibilityElement()
                    .accessibilityLabel("K球练习测试状态").accessibilityValue(vm.diagnostic)
                    .accessibilityIdentifier("kBall.probe").allowsHitTesting(false)
            }
            #endif
        }
        .sheet(isPresented: $vm.needsSubscription, onDismiss: { vm.subscriptionDismissed() }) { SubscriptionView() }
        .alert("练习提示", isPresented: Binding(get: { vm.message != nil }, set: { if !$0 { vm.message = nil } })) {
            Button("知道了") { vm.message = nil }
        } message: { Text(vm.message ?? "") }
    }
    private var questionPrompt: String {
        (vm.record?.current?.requirementText ?? "") + " · ①进\(PocketDisplay.name(index: vm.selectedPocketIndex, orientation: pocketOrientation)) · 母球K到②"
    }
    private var resultNoticeID: String? {
        guard (vm.phase == .result || vm.phase == .aiming || vm.phase == .saveFailed),
              let shot = vm.record?.latestShot else { return nil }
        return "\(shot.id.uuidString):\(vm.record?.showingResult == true)"
    }
    private var resultNoticeText: String {
        guard let shot = vm.record?.latestShot else { return "" }
        return (vm.record?.showingResult == false ? "上杆：" : "本杆：") + shot.resultText
    }
    private var information: [BTTeachingInformation] {
        var result: [BTTeachingInformation] = []
        if let notice = operationNotices.message {
            return [.init(text: notice.text, kind: .notice, symbol: "info.circle", identifier: "kBall.notice")]
        }
        if questionNotices.message != nil {
            result.append(.init(text: questionPrompt, kind: .notice, symbol: "info.circle", identifier: "kBall.question"))
        }
        if resultNotices.message != nil, !hidesPendingScore, vm.record?.latestShot != nil {
            result.append(.init(text: resultNoticeText, kind: .readout, symbol: "info.circle", identifier: "kBall.result"))
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
                .init(id: "kBall.trainingSettings", title: "训练设置", disclosure: true, disabled: vm.isBusy,
                      action: { vm.openSettings() }),
                .init(id: "kBall.finish", title: "结束练习", disabled: vm.isBusy, action: { vm.finish() })
            ], refreshTrajectory: {}, onLayoutEditingChanged: vm.layoutEditingChanged,
            layoutEditingBlocked: vm.isBusy,
            onSpinChange: { vm.setSpin($0, $1) }, paletteKeys: vm.record?.current.map { ["_\($0.ballNumber)", "_\($0.secondBallNumber)"] } ?? [], maximumPaletteCount: 2, paletteRoles: vm.paletteRoles, showsPaletteRoleNumbers: true)
    }
    private var tablePage: some View {
        BTTeachingTablePage(vm: vm, titleLabel: vm.title, identifier: "kBall", preferencePage: vm.preferencePage,
            onTrainingViewChange: { vm.switchTrainingView(to: $0) }, velocity: Binding(get: { vm.velocity }, set: { vm.velocity = $0 }),
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
                            .accessibilityIdentifier("kBall.retry")
                            .freeControlItem("shot.undo", name: vm.playsStroke ? "重打" : "重试")
                        BTGeometricReferenceButton(tool: vm.geometryReference,
                            enabled: vm.canAdjust && !vm.cameraTransitionBusy,
                            size: layout.auxiliarySize, identifier: "kBall.geometry",
                            prepare: { vm.prepareGeometryReference() })
                            .freeControlItem("shot.replay", name: "测量")
                    }
                }.frame(width: layout.columnWidth))
            },
            title: { Text(vm.title) }, leftContent: { _ in EmptyView() }, status: { EmptyView() })
            .task(id: vm.record?.current?.id) {
                // Start the notice lifetime after the table mounts, not during settings/loading.
                await Task.yield()
                guard !Task.isCancelled, vm.phase == .aiming, vm.record?.current != nil else { return }
                questionNotices.show(questionPrompt, tone: .info, priority: .selection)
            }
            .onDisappear { questionNotices.clear() }
    }

    private var sidebarInformation: some View {
        KBallSidebarLayout {
            sidebarMetric("题目", value: vm.record?.configuration.freePractice == true
                ? "\(vm.record?.questionNumber ?? 1)" : "\(vm.record?.questionNumber ?? 1)/15",
                identifier: "kBall.questionInfo", compact: false)
            sidebarMetric("成功率", value: hidesPendingScore ? "—" : vm.record?.successRate ?? "—",
                          identifier: "kBall.successRate", compact: false)
            VStack(spacing: Spacing.xs) {
                if let question = vm.record?.current {
                    Text(question.requirementText)
                        .font(.btCaption2).lineLimit(1).minimumScaleFactor(0.85)
                        .accessibilityIdentifier("kBall.requirement")
                }
                Text(vm.cutAngleDegrees.map { "切角 \(Int($0.rounded()))°" } ?? "切角 —").font(.btCaption2)
                ThicknessOverlapIcon(cutAngle: vm.cutAngleDegrees ?? 0).accessibilityHidden(true)
            }.foregroundStyle(HUDStyle.valueMeasured)
            VStack(spacing: Spacing.xs) {
                if vm.shouldShowReference {
                    routeLegend("参考", color: Color(SeparationRouteStyle.reference), dash: SeparationRouteStyle.legendDash)
                        .accessibilityIdentifier("kBall.referenceLegend")
                        .accessibilityValue("中杆中力，无高低杆、无左右塞，杆速2.0")
                }
                if vm.record?.latestShot != nil {
                    routeLegend("实际", color: Color(SeparationRouteStyle.actual), dash: SeparationRouteStyle.legendDash)
                }
            }
            sidebarMetric(vm.record?.latestShot != nil && vm.record?.showingResult == false ? "上杆结果" : "本杆结果",
                          value: hidesPendingScore || vm.record?.latestShot == nil ? "—" : (vm.record?.latestShot?.failure == nil ? "成功" : "未成功"),
                          identifier: "kBall.resultValue", compact: false)
        }
    }
    private var hidesPendingScore: Bool { !vm.isReplaying && vm.phase == .playing }

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
private struct KBallSidebarLayout: Layout {
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
