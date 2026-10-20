import SwiftUI
import SwiftData

struct AccuracyPracticeView: View {
    @StateObject private var vm: AccuracyPracticeViewModel
    @ObservedObject private var owner = CurrentOwnerContext.shared
    @ObservedObject private var limiter = AngleUsageLimiter.shared
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
            case .summary:
                if let record = vm.record {
                    ScrollView {
                        AccuracyPracticeSummary(record: record)
                        Button("返回训练设置") { vm.openSettings() }
                            .buttonStyle(.borderedProminent).padding(Spacing.lg)
                    }.navigationTitle(vm.title + "总结")
                        .accessibilityIdentifier("accuracy.summary")
                }
            default:
                tablePage
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
            kind: .readout, identifier: "accuracy.question")]
        if vm.phase == .result { result.append(.init(text: vm.outcomeText, kind: .readout, identifier: "accuracy.result")) }
        return result
    }
    private var controls: BTTablePlanningControls {
        .init(spinX: .constant(Double(vm.tip.x)), spinY: .constant(Double(vm.tip.y)),
            transparency: .constant(0), instrumentsEnabled: vm.canAim, assessmentMode: true,
            isAnimating: vm.phase == .playing || vm.phase == .computing, paletteEnabled: false,
            allowsPocketSelection: false, primaryTitle: vm.primaryTitle,
            primaryEnabled: vm.phase != .computing && vm.phase != .playing && !vm.cameraTransitionBusy,
            onPrimary: {
                if vm.phase == .saveFailed { vm.retrySave() }
                else if vm.phase == .result && vm.record?.currentAttempt?.result?.countsAsAttempt == true { vm.next() }
                else if !vm.is3D && limiter.isLimitReached { showSubscription = true }
                else { vm.strike() }
            }, onPaletteTap: { _ in },
            menuItems: [
                .init(id: "accuracy.trainingSettings", title: "训练设置", disabled: vm.isBusy, action: { vm.openSettings() }),
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
                    BTTeachingInstrumentEntry(layout: layout, label: "题目") {
                        Text(vm.record?.configuration.freePractice == true
                             ? "\((vm.record?.cursor ?? 0) + 1)" : "\((vm.record?.cursor ?? 0) + 1)/20")
                            .font(.btCaption).monospacedDigit()
                    }
                    BTTeachingAimRuler(layout: layout, enabled: vm.canAim, onNudge: { vm.nudgeAim($0) },
                        degreesPerPoint: AimWheelGain.degreesPerPoint(distanceMeters: cueDistance))
                        .accessibilityIdentifier("accuracy.aimWheel")
                    Button { vm.replay() } label: {
                        Image(systemName: BTIcon.playCircle).font(.btTitle2).frame(width: 44, height: 44)
                    }.disabled(vm.phase != .result || vm.record?.currentAttempt?.result?.countsAsAttempt != true)
                        .accessibilityLabel("回放本杆").accessibilityIdentifier("accuracy.replay")
                        .freeControlItem("shot.replay", name: "回放本杆")
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

struct AccuracyPracticeSummary: View {
    let record: AccuracyPracticeRecord
    private var attempts: [AccuracyPracticeAttempt] { record.validAttempts }
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text(record.displayName + " · 模拟练习").font(.btTitle2)
            Text("完成 \(record.successCount) / \(attempts.count) 题").font(.btHeadline)
            Text("目标球进指定袋 \(attempts.filter { $0.result?.specifiedPocket == true }.count) / \(attempts.count) · 母球落袋 \(attempts.filter { $0.result?.scratch == true }.count) 次")
            Text("仅统计已完成的实际出杆；待完成 \(record.attempts.count - attempts.count) 题。").font(.btFootnote).foregroundStyle(.btTextSecondary)
            Text("分项记录").font(.btHeadline)
            ForEach(SceneTrainingConfiguration.AngleRange.allCases.filter { $0 != .mixed }) { band in
                row(band.label, matching: { band.degrees.contains(Int($0.board.angle.rounded())) })
            }
            ForEach(SceneTrainingConfiguration.Distance.allCases.filter { $0 != .mixed }) { band in
                row("母球距离 · " + band.shortLabel, matching: { $0.board.cueBand == band })
                row("目标球距袋 · " + band.shortLabel, matching: { $0.board.pocketBand == band })
            }
            row("角袋", matching: { $0.board.pocketIndex < 4 })
            row("中袋", matching: { $0.board.pocketIndex >= 4 })
            row("贴库", matching: { abs($0.railClearance) <= SceneTrainingRailGeometry.contactRoundoff })
            row("半贴库", matching: { $0.railClearance > SceneTrainingRailGeometry.contactRoundoff && $0.railClearance <= 0.10 })
            row("远库", matching: { $0.railClearance > 0.10 })
            ForEach(TrainingFixedTip.allCases, id: \.rawValue) { tip in row(tip.label, matching: { $0.tip == tip }) }
            Text("观察方式").font(.btHeadline)
            Text("常规观察 \(attempts.filter { $0.observations.isEmpty }.count) 题 · 使用俯视、全桌观察或网格 \(attempts.filter { !$0.observations.isEmpty }.count) 题")
                .font(.btFootnote)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(Spacing.lg)
    }
    private func row(_ title: String, matching: (AccuracyPracticeQuestion) -> Bool) -> some View {
        let ids = Set(record.questions.filter(matching).map(\.id))
        let selected = attempts.filter { ids.contains($0.questionID) }
        return Text("\(title)：完成 \(selected.filter { $0.result?.outcome == .success }.count) / \(selected.count) 题" + (selected.count < 5 ? "，样本不足5题" : ""))
            .font(.btFootnote)
    }
}
