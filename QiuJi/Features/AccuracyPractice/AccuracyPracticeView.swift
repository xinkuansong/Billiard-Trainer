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
    @State private var pocketOrientation: PocketDisplay.Orientation = .landscape

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
                            if limiter.isLimitReached { showSubscription = true }
                            else { vm.openSettings() }
                        }, onComplete: { dismiss() })
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("accuracy.summary")
                    }
                    }
                }
            }
        }
        .onAppear { vm.attach(context: context) }
        .onReceive(subscriptionManager.$isPremium) { vm.limiter.isPremium = $0 }
        .onChange(of: owner.ownerKey) { _, _ in vm.ownerChanged() }
        .onChange(of: vm.temporaryTopDownActive) { _, active in if active { vm.markObservation("topDown") } }
        .sheet(isPresented: $showSubscription) { SubscriptionView() }
        .alert("练习提示", isPresented: Binding(get: { vm.message != nil }, set: { if !$0 { vm.message = nil } })) {
            Button("知道了") { vm.message = nil }
        } message: { Text(vm.message ?? "") }
    }
    private var information: [BTTeachingInformation] {
        var result = [BTTeachingInformation(
            text: "第\((vm.record?.cursor ?? 0) + 1)题 · 指定\(vm.tip.label) · \(PocketDisplay.name(index: vm.selectedPocketIndex, orientation: pocketOrientation))",
            kind: .notice, identifier: "accuracy.question")]
        if vm.phase == .result { result.append(.init(text: vm.outcomeText, kind: .readout, identifier: "accuracy.result")) }
        return result
    }
    private var controls: BTTablePlanningControls {
        .init(spinX: .constant(Double(vm.tip.x)), spinY: .constant(Double(vm.tip.y)),
            transparency: Binding(get: { tablePreferences.snapshot(for: vm.preferencePage)[.transparency] },
                set: { tablePreferences.apply(.transparency, value: $0, to: vm.preferencePage) }), instrumentsEnabled: vm.canAim, assessmentMode: true,
            isAnimating: vm.phase == .playing || vm.phase == .computing, paletteEnabled: false,
            allowsPocketSelection: false, primaryTitle: vm.primaryTitle,
            primaryEnabled: vm.phase != .computing && vm.phase != .playing && !vm.cameraTransitionBusy,
            onPrimary: {
                if vm.phase == .saveFailed { vm.retrySave() }
                else if vm.phase == .result && vm.record?.currentAttempt?.result?.countsAsAttempt == true { vm.next() }
                else if !vm.isRetrying && !vm.is3D && limiter.isLimitReached { showSubscription = true }
                else { vm.strike() }
            }, onPaletteTap: { _ in },
            menuItems: [
                .init(id: "accuracy.trainingSettings", title: "训练设置", disclosure: true, disabled: vm.isBusy, action: { vm.openSettings() }),
                .init(id: "accuracy.finish", title: "结束练习", disabled: vm.isBusy, action: { vm.finish() })
            ], refreshTrajectory: {},
            applyPreferences: { preferences in if preferences.enabled(.grid) { vm.markObservation("grid") } },
            layoutEditingBlocked: vm.isBusy, onAimNudged: { vm.nudgeAim($0) },
            onObservation: { vm.markObservation($0) })
    }
    private var tablePage: some View {
        BTTeachingTablePage(vm: vm, titleLabel: vm.title, identifier: "accuracy", preferencePage: vm.preferencePage,
            fixedView3D: vm.is3D, velocity: Binding(get: { vm.velocity }, set: { vm.velocity = $0 }),
            planning: controls, information: information, usesStandardTitle: true,
            onPocketOrientationChange: { pocketOrientation = $0 },
            pairedLeftContent: { layout in
                AnyView(VStack(spacing: layout.groupSpacing) {
                    VStack(spacing: 0) {
                        Text("题目").foregroundStyle(HUDStyle.labelColor)
                        Text(vm.record?.configuration.freePractice == true
                             ? "\((vm.record?.cursor ?? 0) + 1)" : "\((vm.record?.cursor ?? 0) + 1)/20")
                        Text("进球率").foregroundStyle(HUDStyle.labelColor)
                        Text(vm.potRate)
                    }.font(.btCaption2).monospacedDigit().foregroundStyle(.white)
                        .frame(height: layout.topDiameter + 14)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("accuracy.questionInfo")
                    BTTeachingAimRuler(layout: layout, enabled: vm.canAim, onNudge: { vm.nudgeAim($0) },
                        degreesPerPoint: AimWheelGain.degreesPerPoint(distanceMeters: cueDistance))
                        .accessibilityIdentifier("accuracy.aimWheel")
                    Button { vm.retry() } label: {
                        Image(systemName: BTIcon.replay).font(.btTitle2).frame(width: 44, height: 44)
                    }.disabled(vm.phase != .result || vm.record?.currentAttempt?.result?.countsAsAttempt != true)
                        .accessibilityLabel("重打").accessibilityIdentifier("accuracy.retry")
                        .freeControlItem("shot.replay", name: "重打")
                    if !vm.is3D && !limiter.isPremium {
                        Text("剩余 \(limiter.remainingToday)").font(.btCaption)
                            .accessibilityIdentifier("accuracy.remaining")
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
