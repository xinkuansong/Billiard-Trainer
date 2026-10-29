import SwiftUI
import SwiftData

struct AccuracyPracticeView: View {
    @StateObject private var vm: AccuracyPracticeViewModel
    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    @ObservedObject private var owner = CurrentOwnerContext.shared
    @ObservedObject private var limiter = AngleUsageLimiter.accuracyTraining
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showSubscription = false
    @State private var pendingRestart = false
    @State private var pocketOrientation: PocketDisplay.Orientation = .landscape
    @StateObject private var questionNotices = BTRuleNoticeCenter()
    @StateObject private var resultNotices = BTRuleNoticeCenter()
    @StateObject private var operationNotices = BTRuleNoticeCenter()

    init(is3D: Bool) { _vm = StateObject(wrappedValue: AccuracyPracticeViewModel(is3D: is3D)) }
    var body: some View {
        Group {
            switch vm.phase {
            case .loading:
                ProgressView("正在读取练习…")
            case .settings:
                SceneTrainingSettings(route: vm.route, configuration: vm.record?.configuration ?? .init(),
                    restarting: vm.record != nil, showsSpinOptions: true,
                    prepareBatch: AccuracyPreparedRound.prepare,
                    onStart: { vm.start($0, prepared: $1) },
                    onCancel: { if !vm.cancelSettings() { dismiss() } })
            default:
                tablePage.overlay {
                    if vm.phase == .summary {
                    Button { vm.reviewLastQuestion() } label: {
                        Color.black.opacity(0.45).ignoresSafeArea()
                    }.buttonStyle(.plain).accessibilityLabel("返回最后一题")
                        .accessibilityIdentifier("accuracy.reviewLast")
                    if let record = vm.record {
                        TrainingFinishContent(metrics: accuracyMetrics(record), onRestart: {
                            limiter.refreshDay()
                            if !subscriptionManager.isPremium && limiter.isLimitReached { pendingRestart = true; showSubscription = true }
                            else { vm.openSettings() }
                        }, onComplete: { dismiss() })
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("accuracy.summary")
                    }
                    }
                }
            }
        }
        #if DEBUG
        .overlay(alignment: .topLeading) {
            if ProcessInfo.processInfo.arguments.contains("-trainingMerge.probe") {
                Color.clear.frame(width: 1, height: 1).accessibilityElement()
                    .accessibilityIdentifier("accuracy.mergeState").accessibilityValue(mergeState)
                    .allowsHitTesting(false)
            }
        }
        #endif
        .onAppear { vm.attach(context: context) }
        .onReceive(subscriptionManager.$isPremium) { vm.limiter.isPremium = $0 }
        .onChange(of: owner.ownerKey) { _, _ in vm.ownerChanged() }
        .onChange(of: vm.temporaryTopDownActive) { _, active in if active { vm.markObservation("topDown") } }
        .onChange(of: vm.record?.current?.id, initial: true) { _, questionID in
            guard questionID != nil else { questionNotices.clear(); return }
            questionNotices.show(questionPrompt, tone: .info, priority: .selection)
        }
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
        .sheet(isPresented: $showSubscription, onDismiss: {
            if pendingRestart && subscriptionManager.isPremium { vm.openSettings() }
            pendingRestart = false
        }) { SubscriptionView() }
        .alert("练习提示", isPresented: Binding(get: { vm.message != nil }, set: { if !$0 { vm.message = nil } })) {
            Button("知道了") { vm.message = nil }
        } message: { Text(vm.message ?? "") }
    }
    #if DEBUG
    private var mergeState: String {
        let values: [String: Any] = ["session": vm.record?.id.uuidString ?? "", "question": vm.record?.current?.id.uuidString ?? "",
            "phase": String(describing: vm.phase), "view": vm.is3D ? "3D" : "2D", "used": limiter.questionsUsedToday,
            "attempts": vm.record?.attempts.count ?? 0, "velocity": vm.velocity,
            "aimX": vm.record?.draftDirection.x ?? 0, "aimZ": vm.record?.draftDirection.z ?? 0,
            "spinX": vm.tip.x, "spinY": vm.tip.y, "pocket": vm.selectedPocketIndex]
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: .sortedKeys) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    #endif
    private var questionPrompt: String {
        "第\((vm.record?.cursor ?? 0) + 1)题 · \(vm.tipInstruction) · \(PocketDisplay.name(index: vm.selectedPocketIndex, orientation: pocketOrientation))"
    }
    private var resultNoticeID: String? {
        guard vm.phase == .result, let attempt = vm.record?.currentAttempt else { return nil }
        return attempt.id.uuidString
    }
    private var resultNoticeText: String { vm.outcomeText }
    private var information: [BTTeachingInformation] {
        var result: [BTTeachingInformation] = []
        if let notice = operationNotices.message {
            return [.init(text: notice.text, kind: .notice, symbol: "info.circle", identifier: "accuracy.notice")]
        }
        if questionNotices.message != nil {
            // Derive the label from the current orientation without restarting its timer.
            result.append(.init(text: questionPrompt, kind: .notice, identifier: "accuracy.question"))
        }
        if resultNotices.message != nil, vm.phase == .result {
            result.append(.init(text: vm.outcomeText, kind: .readout, symbol: "info.circle", identifier: "accuracy.result"))
        }
        return result
    }
    private var controls: BTTablePlanningControls {
        .init(spinX: Binding(get: { Double(vm.tip.x) }, set: { vm.updateSpin($0, Double(vm.tip.y)) }),
            spinY: Binding(get: { Double(vm.tip.y) }, set: { vm.updateSpin(Double(vm.tip.x), $0) }),
            transparency: Binding(get: { tablePreferences.snapshot(for: vm.preferencePage)[.transparency] },
                set: { tablePreferences.apply(.transparency, value: $0, to: vm.preferencePage) }), instrumentsEnabled: vm.canAim, assessmentMode: true,
            allowsAssessmentAimCloseup: true,
            allowsAssessmentSpinEditing: vm.allowsVerticalSpinEditing || vm.allowsSideSpinEditing,
            allowsVerticalSpinEditing: vm.allowsVerticalSpinEditing,
            allowsSideSpinEditing: vm.allowsSideSpinEditing,
            isAnimating: vm.phase == .playing || vm.phase == .computing, paletteEnabled: false,
            allowsPocketSelection: false, primaryTitle: vm.primaryTitle,
            primaryEnabled: (vm.isReplaying || (vm.phase != .computing && vm.phase != .playing)) && !vm.cameraTransitionBusy,
            onPrimary: {
                if vm.isReplaying { vm.stopPlayback() }
                else if vm.phase == .saveFailed { vm.retrySave() }
                else if vm.phase == .result && vm.record?.currentAttempt?.result?.countsAsAttempt == true { vm.next() }
                else { vm.strike() }
            }, onPaletteTap: { _ in },
            menuItems: [
                .init(id: "accuracy.trainingSettings", title: "训练设置", disclosure: true, disabled: vm.isBusy, action: { vm.openSettings() }),
                .init(id: "accuracy.finish", title: "结束练习", disabled: vm.isBusy, action: { vm.finish() })
            ], refreshTrajectory: {},
            applyPreferences: { preferences in
                if preferences.enabled(.grid) { vm.markObservation("grid") }
                if preferences.enabled(.closeup) { vm.markObservation("closeup") }
            },
            layoutEditingBlocked: vm.isBusy, onAimNudged: { vm.nudgeAim($0) },
            onObservation: { vm.markObservation($0) },
            closeupSnapshot: vm.canAim ? vm.closeupSnapshot : nil,
            onSpinChange: { vm.updateSpin($0, $1) }, paletteKeys: vm.record?.current.map { ["_\($0.ballNumber)"] } ?? [], maximumPaletteCount: 1)
    }
    private var tablePage: some View {
        BTTeachingTablePage(vm: vm, titleLabel: vm.title, identifier: "accuracy", preferencePage: vm.preferencePage,
            onTrainingViewChange: { vm.switchTrainingView(to: $0) }, velocity: Binding(get: { vm.velocity }, set: { vm.velocity = $0 }),
            planning: controls, information: information, usesStandardTitle: true,
            onPocketOrientationChange: { pocketOrientation = $0 },
            pairedLeftContent: { layout in
                AnyView(VStack(spacing: layout.groupSpacing) {
                    VStack(spacing: 0) {
                        Text("题目").foregroundStyle(HUDStyle.labelColor)
                        Text(vm.record?.configuration.freePractice == true
                             ? "\((vm.record?.cursor ?? 0) + 1)" : "\((vm.record?.cursor ?? 0) + 1)/15")
                        Text("进球率").foregroundStyle(HUDStyle.labelColor)
                        Text(vm.potRate)
                    }.font(.btCaption2).monospacedDigit().foregroundStyle(.white)
                        .frame(height: layout.topDiameter + 14)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("accuracy.questionInfo")
                    BTTeachingAimRuler(layout: layout, enabled: vm.canAim, onNudge: { vm.nudgeAim($0) },
                        degreesPerPoint: AimWheelGain.degreesPerPoint(distanceMeters: cueDistance))
                        .accessibilityIdentifier("accuracy.aimWheel")
                    let actions = layout.horizontalActions
                        ? AnyLayout(HStackLayout(spacing: layout.groupSpacing))
                        : AnyLayout(VStackLayout(spacing: layout.groupSpacing))
                    actions {
                        BTHUDCompactAction(title: "重打", symbol: "arrow.uturn.backward", size: layout.auxiliarySize) { vm.retry() }
                            .disabled(!vm.canRetry)
                            .accessibilityIdentifier("accuracy.retry")
                            .freeControlItem("shot.undo", name: "重打")
                        BTHUDCompactAction(title: "回放", symbol: "play.rectangle", size: layout.auxiliarySize) { vm.replayLastShot() }
                            .disabled(!vm.canPlayback)
                            .accessibilityIdentifier("accuracy.playback")
                            .freeControlItem("shot.replay", name: "回放")
                    }
                }.frame(width: layout.columnWidth))
            },
            title: { Text(vm.title) }, leftContent: { _ in EmptyView() }, status: { EmptyView() })
    }
    private var cueDistance: Float {
        guard let board = vm.record?.current?.board else { return 1 }
        return hypot(board.cue.x - board.target.x, board.cue.z - board.target.z)
    }
}

func accuracyMetrics(_ record: AccuracyPracticeRecord) -> [(String, String)] {
    [("题数", "\(record.validAttempts.count)"), ("进球数量", "\(record.successCount)"),
     ("进球率", SceneTrainingMetrics.percentage(record.successCount, of: record.validAttempts.count))]
}

struct AccuracyPracticeSummary: View {
    let record: AccuracyPracticeRecord
    var body: some View {
        TrainingFinishContent(metrics: accuracyMetrics(record), onRestart: nil, onComplete: nil)
    }
}
