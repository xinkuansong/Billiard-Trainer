import SwiftUI
import SwiftData
import SceneKit

struct BankPracticeView: View {
    @StateObject private var vm: BankPracticeViewModel
    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    @ObservedObject private var owner = CurrentOwnerContext.shared
    @ObservedObject private var limiter = AngleUsageLimiter.bankTraining
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @StateObject private var questionNotices = BTRuleNoticeCenter()
    @StateObject private var resultNotices = BTRuleNoticeCenter()
    @StateObject private var operationNotices = BTRuleNoticeCenter()

    init(is3D: Bool) { _vm = StateObject(wrappedValue: BankPracticeViewModel(is3D: is3D)) }
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
                BankPracticeSettings(configuration: vm.record?.configuration ?? .init(), restarting: vm.record != nil,
                    onStart: { vm.start($0, prepared: $1) },
                    onCancel: { if !vm.cancelSettings() { dismiss() } })
                    .id(owner.ownerKey)
            default:
                tablePage.overlay {
                    if vm.phase == .summary {
                    Button { vm.reviewLastQuestion() } label: {
                        Color.black.opacity(0.45).ignoresSafeArea()
                    }.buttonStyle(.plain).accessibilityLabel("返回最后一题")
                        .accessibilityIdentifier("bank.reviewLast")
                    if let record = vm.record {
                        TrainingFinishContent(metrics: record.finishMetrics,
                            onRestart: { vm.restart() }, onComplete: { dismiss() })
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("bank.summary")
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
            if ProcessInfo.processInfo.arguments.contains("-bank.probe") {
                Color.clear.frame(width: 1, height: 1).accessibilityElement()
                    .accessibilityLabel("翻袋练习测试状态").accessibilityValue(vm.diagnostic)
                    .accessibilityIdentifier("bank.probe").allowsHitTesting(false)
            }
            #endif
        }
        .sheet(isPresented: $vm.needsSubscription, onDismiss: { vm.subscriptionDismissed() }) { SubscriptionView() }
        .alert("练习提示", isPresented: Binding(get: { vm.message != nil }, set: { if !$0 { vm.message = nil } })) {
            Button("知道了") { vm.message = nil }
        } message: { Text(vm.message ?? "") }
    }
    private var questionPrompt: String {
        vm.record?.current?.requirementText ?? ""
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
            return [.init(text: notice.text, kind: .notice, symbol: "info.circle", identifier: "bank.notice")]
        }
        if questionNotices.message != nil {
            result.append(.init(text: questionPrompt, kind: .notice, symbol: "info.circle", identifier: "bank.question"))
        }
        if !hidesPendingScore, resultNotices.message != nil {
            result.append(.init(text: resultNoticeText, kind: .readout, symbol: "info.circle", identifier: "bank.result"))
        }
        return result
    }
    private var controls: BTTablePlanningControls {
        .init(spinX: Binding(get: { Double(vm.instrumentInput.spinX) }, set: { vm.setSpin($0, Double(vm.input.spinY)) }),
            spinY: Binding(get: { Double(vm.instrumentInput.spinY) }, set: { vm.setSpin(Double(vm.input.spinX), $0) }),
            transparency: Binding(get: { tablePreferences.snapshot(for: vm.preferencePage)[.transparency] },
                set: { tablePreferences.apply(.transparency, value: $0, to: vm.preferencePage) }),
            velocityRange: ShotTuning.velocityRange, instrumentsEnabled: vm.canAdjust,
            showsReadOnlyDemonstration: vm.demonstrationInput != nil,
            assessmentMode: true, allowsAssessmentAimCloseup: true, allowsAssessmentSpinEditing: true,
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
                .init(id: "bank.trainingSettings", title: "训练设置", disclosure: true, disabled: vm.isBusy,
                      action: { vm.openSettings() }),
                .init(id: "bank.finish", title: "结束练习", disabled: vm.isBusy, action: { vm.finish() })
            ], refreshTrajectory: {}, onLayoutEditingChanged: vm.layoutEditingChanged,
            layoutEditingBlocked: vm.isBusy, onAimNudged: { vm.nudgeAim($0) },
            closeupSnapshot: vm.canAdjust ? vm.closeupSnapshot : nil,
            onSpinChange: { vm.setSpin($0, $1) },
            paletteKeys: vm.record?.current.map { ["_\($0.ballNumber)"] } ?? [], maximumPaletteCount: 1, paletteRoles: vm.paletteRoles,
            headerTrailing: vm.record?.configuration.showsRailColors == true
                ? { diameter in AnyView(PracticeRailSequence(segments: vm.record?.current?.railSegments ?? [], cueDiameter: diameter, identifier: "bank.railSequence", observedBallKey: "_1", observedBallLabel: "目标球")) } : nil)
    }
    private var tablePage: some View {
        BTTeachingTablePage(vm: vm, titleLabel: vm.title, identifier: "bank", preferencePage: vm.preferencePage,
            insufficientSpaceMessage: "扩大窗口后继续翻袋练习",
            onTrainingViewChange: { vm.switchTrainingView(to: $0) }, velocity: Binding(get: { Double(vm.instrumentInput.velocity) }, set: { vm.velocity = $0 }),
            planning: controls, information: information, usesStandardTitle: true, fitsLongTitle: true, showsPalette: true,
            pairedLeftContent: { layout in
                AnyView(VStack(spacing: layout.groupSpacing) {
                    VStack(spacing: 0) {
                        Text("题目").foregroundStyle(HUDStyle.labelColor)
                        Text(vm.record?.configuration.freePractice == true
                            ? "\(vm.record?.questionNumber ?? 1)" : "\(vm.record?.questionNumber ?? 1)/15")
                        Text("成功率").foregroundStyle(HUDStyle.labelColor)
                        Text(hidesPendingScore ? "—" : vm.record?.successRate ?? "—")
                    }.font(.btCaption2).monospacedDigit().foregroundStyle(.white)
                        .frame(height: layout.topDiameter + 14)
                        .accessibilityElement(children: .combine).accessibilityIdentifier("bank.questionInfo")
                    BTTeachingAimRuler(layout: layout, enabled: vm.canAdjust, onNudge: { vm.nudgeAim($0) },
                        degreesPerPoint: AimWheelGain.degreesPerPoint(distanceMeters: cueDistance))
                        .accessibilityIdentifier("bank.aimWheel")
                    let actions = layout.horizontalActions
                        ? AnyLayout(HStackLayout(spacing: layout.groupSpacing))
                        : AnyLayout(VStackLayout(spacing: layout.groupSpacing))
                    actions {
                        BTHUDCompactAction(title: vm.playsStroke ? "重打" : "重试", symbol: "arrow.uturn.backward", size: layout.auxiliarySize) { vm.retry() }
                            .disabled(!vm.canRetry)
                            .accessibilityIdentifier("bank.retry")
                            .freeControlItem("shot.undo", name: vm.playsStroke ? "重打" : "重试")
                        if vm.canReplayReference || vm.demonstrationInput != nil {
                            BTPracticeDemonstrationButton(enabled: vm.canReplayReference, size: layout.auxiliarySize,
                                identifier: "bank.referenceReplay", action: vm.replayReference)
                        } else {
                            BTGeometricReferenceButton(tool: vm.geometryReference,
                                enabled: vm.canAdjust && !vm.cameraTransitionBusy, size: layout.auxiliarySize,
                                identifier: "bank.geometry", prepare: { vm.prepareGeometryReference() })
                                .freeControlItem("shot.replay", name: "测量")
                        }
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

    private var hidesPendingScore: Bool { !vm.isReplaying && vm.phase == .playing }
    private var cueDistance: Float {
        guard let board = vm.record?.current?.board else { return 1 }
        return hypot(board.cue.x-board.target.x, board.cue.z-board.target.z)
    }
}
