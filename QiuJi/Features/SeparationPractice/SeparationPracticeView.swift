import SwiftUI
import SwiftData

struct SeparationPracticeView: View {
    @StateObject private var vm: SeparationPracticeViewModel
    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    @ObservedObject private var owner = CurrentOwnerContext.shared
    @ObservedObject private var limiter = AngleUsageLimiter.separationTraining
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var pocketOrientation: PocketDisplay.Orientation = .landscape
    @StateObject private var questionNotices = BTRuleNoticeCenter()

    init(is3D: Bool) { _vm = StateObject(wrappedValue: SeparationPracticeViewModel(is3D: is3D)) }
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
                    prepareBatch: SeparationQuestionGenerator.Prepared.prepare,
                    onStart: { vm.start($0, prepared: $1) },
                    onCancel: { if !vm.cancelSettings() { dismiss() } })
                    .id(owner.ownerKey)
            default:
                tablePage.overlay {
                    if vm.phase == .summary {
                    Button { vm.reviewLastQuestion() } label: {
                        Color.black.opacity(0.45).ignoresSafeArea()
                    }.buttonStyle(.plain).accessibilityLabel("返回最后一题")
                        .accessibilityIdentifier("separation.reviewLast")
                    if let record = vm.record {
                        TrainingFinishContent(metrics: record.finishMetrics,
                            onRestart: { vm.restart() }, onComplete: { dismiss() })
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("separation.summary")
                    }
                    }
                }
            }
        }
        .onAppear { vm.limiter.isPremium = subscriptionManager.isPremium; vm.attach(context: context) }
        .onReceive(subscriptionManager.$isPremium) { vm.limiter.isPremium = $0 }
        .onChange(of: owner.ownerKey) { _, _ in vm.ownerChanged() }

        .onChange(of: vm.record?.current?.id, initial: true) { _, questionID in
            guard questionID != nil else { questionNotices.clear(); return }
            questionNotices.show(questionPrompt, tone: .info, priority: .selection)
        }
        .onDisappear { questionNotices.clear() }
        .overlay(alignment: .topLeading) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-separation.probe") {
                Color.clear.frame(width: 1, height: 1).accessibilityElement()
                    .accessibilityLabel("分离角测试状态").accessibilityValue(vm.diagnostic)
                    .accessibilityIdentifier("separation.probe").allowsHitTesting(false)
            }
            #endif
        }
        .sheet(isPresented: $vm.needsSubscription, onDismiss: { vm.subscriptionDismissed() }) { SubscriptionView() }
        .alert("练习提示", isPresented: Binding(get: { vm.message != nil }, set: { if !$0 { vm.message = nil } })) {
            Button("知道了") { vm.message = nil }
        } message: { Text(vm.message ?? "") }
    }
    private var questionPrompt: String {
        "第\(vm.record?.questionNumber ?? 1)题 · 调整打点和力度 · \(PocketDisplay.name(index: vm.selectedPocketIndex, orientation: pocketOrientation))"
    }
    private var information: [BTTeachingInformation] {
        var result: [BTTeachingInformation] = []
        if questionNotices.message != nil {
            // Derive the label from the current orientation without restarting its timer.
            result.append(.init(text: questionPrompt, kind: .notice, identifier: "separation.question"))
        }
        if vm.phase == .result {
            result.append(.init(text: vm.outcomeText, kind: .readout, symbol: "info.circle", identifier: "separation.result"))
        }
        return result
    }
    private var controls: BTTablePlanningControls {
        .init(spinX: Binding(get: { Double(vm.input.spinX) }, set: { vm.setSpin($0, Double(vm.input.spinY)) }),
            spinY: Binding(get: { Double(vm.input.spinY) }, set: { vm.setSpin(Double(vm.input.spinX), $0) }),
            transparency: Binding(get: { tablePreferences.snapshot(for: vm.preferencePage)[.transparency] },
                set: { tablePreferences.apply(.transparency, value: $0, to: vm.preferencePage) }),
            velocityRange: ShotTuning.velocityRange, instrumentsEnabled: vm.canAdjust,
            assessmentMode: true, allowsAssessmentSpinEditing: true, allowsAssessmentRehearsal: true,
            defersStrikeAccessUntilSubmission: true,
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
                .init(id: "separation.trainingSettings", title: "训练设置", disclosure: true, disabled: vm.isBusy,
                      action: { vm.openSettings() }),
                .init(id: "separation.finish", title: "结束练习", disabled: vm.isBusy, action: { vm.finish() })
            ], refreshTrajectory: {}, onLayoutEditingChanged: vm.layoutEditingChanged,
            layoutEditingBlocked: vm.isBusy,
            onSpinChange: { vm.setSpin($0, $1) })
    }
    private var tablePage: some View {
        BTTeachingTablePage(vm: vm, titleLabel: vm.title, identifier: "separation", preferencePage: vm.preferencePage,
            fixedView3D: vm.is3D, velocity: Binding(get: { vm.velocity }, set: { vm.velocity = $0 }),
            planning: controls, information: information, usesStandardTitle: true,
            onPocketOrientationChange: { pocketOrientation = $0 },
            pairedLeftContent: { layout in
                AnyView(VStack(spacing: layout.groupSpacing) {
                    // Use the full vacant direction lane without shifting the action slots.
                    VStack(spacing: layout.groupSpacing) {
                        Color.clear.frame(height: layout.topDiameter + 14)
                        BTTeachingAimRulerSpace(layout: layout)
                    }.overlay(alignment: .top) {
                        ViewThatFits(in: .vertical) {
                            sidebarInformation(compact: false)
                            sidebarInformation(compact: true)
                            ScrollView(.vertical) { sidebarInformation(compact: true) }
                                .scrollBounceBehavior(.basedOnSize)
                        }.padding(.bottom, Spacing.sm)
                        .frame(width: layout.columnWidth).frame(maxHeight: .infinity, alignment: .top)
                    }
                    let actions = layout.horizontalActions
                        ? AnyLayout(HStackLayout(spacing: layout.groupSpacing))
                        : AnyLayout(VStackLayout(spacing: layout.groupSpacing))
                    actions {
                        BTHUDCompactAction(title: vm.playsStroke ? "重打" : "重试", symbol: "arrow.uturn.backward", size: layout.auxiliarySize) { vm.retry() }
                            .disabled(!vm.canRetry)
                            .accessibilityIdentifier("separation.retry")
                            .freeControlItem("shot.undo", name: vm.playsStroke ? "重打" : "重试")
                        BTHUDCompactAction(title: vm.playsStroke ? "回放" : "击球", symbol: "play.rectangle", size: layout.auxiliarySize) { vm.replayLastShot() }
                            .disabled(!vm.canPlayback)
                            .accessibilityIdentifier("separation.playback")
                            .freeControlItem("shot.replay", name: vm.playsStroke ? "回放" : "击球")
                    }
                }.frame(width: layout.columnWidth))
            },
            title: { Text(vm.title) }, leftContent: { _ in EmptyView() }, status: { EmptyView() })
    }

    private func sidebarInformation(compact: Bool) -> some View {
        VStack(spacing: 0) {
            sidebarMetric("题目", value: vm.record?.configuration.freePractice == true
                ? "\(vm.record?.questionNumber ?? 1)" : "\(vm.record?.questionNumber ?? 1)/20",
                identifier: "separation.questionInfo", compact: compact)
            sidebarGroupGap
            sidebarMetric("均分", value: displayedAverage.map { String(format: "%.1f", $0) } ?? "—",
                          identifier: "separation.averageScore", compact: compact)
            sidebarGroupGap
            VStack(spacing: 2) {
                Text(vm.cutAngleDegrees.map { "切角 \(Int($0.rounded()))°" } ?? "切角 —")
                ThicknessOverlapIcon(cutAngle: vm.cutAngleDegrees ?? 0)
                    .opacity(vm.cutAngleDegrees == nil ? 0.3 : 1)
                    .accessibilityHidden(true)
            }
            .font(.btCaption2).monospacedDigit().foregroundStyle(HUDStyle.valueMeasured)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("separation.cutAngle")
            sidebarGroupGap
            VStack(spacing: compact ? 2 : Spacing.xs) {
                routeLegend("目标", color: Color(SeparationRouteStyle.target), dash: SeparationRouteStyle.legendDash)
                if vm.showsReference {
                    routeLegend("参考", color: Color(SeparationRouteStyle.reference), dash: SeparationRouteStyle.legendDash)
                        .accessibilityIdentifier("separation.referenceLegend")
                        .accessibilityValue("中杆中力，无高低杆、无左右塞，杆速2.5")
                }
                routeLegend("实际", color: Color(SeparationRouteStyle.actual), dash: SeparationRouteStyle.legendDash)
            }
            sidebarGroupGap
            sidebarMetric("本题均分", value: vm.record?.currentQuestionAverage(
                excluding: hidesPendingScore ? vm.record?.latestShot?.id : nil).map { String(format: "%.1f", $0) } ?? "—",
                          identifier: "separation.questionAverageScore", compact: compact)
            sidebarGroupGap
            sidebarMetric(vm.latestScoreTitle, value: hidesPendingScore ? "—" : vm.record?.latestShot?.score?.formatted ?? "—",
                          identifier: "separation.latestScore", compact: compact)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // Spend spare lane height between groups, while keeping each label/value pair together.
    private var sidebarGroupGap: some View {
        Spacer(minLength: 2).frame(minHeight: 2, idealHeight: 2, maxHeight: Spacing.md)
    }


    private var hidesPendingScore: Bool { !vm.isReplaying && (vm.phase == .revealing || vm.phase == .playing) }
    private var displayedAverage: Double? {
        guard let record = vm.record else { return nil }
        // The submitted first attempt is persisted before animation. Reveal its grade only after playback.
        if hidesPendingScore, let attempt = record.currentAttempt,
           attempt.id == record.latestShot?.id, let score = attempt.score {
            let count = record.totalScoredCount - 1
            return count > 0 ? (record.totalScoreSum - score.value) / Double(count) : nil
        }
        return record.averageScore
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
