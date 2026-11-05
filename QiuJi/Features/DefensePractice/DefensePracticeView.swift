import SwiftUI
import SwiftData
import SceneKit

struct DefensePracticeView: View {
    @StateObject private var vm: DefensePracticeViewModel
    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    @ObservedObject private var owner = CurrentOwnerContext.shared
    @ObservedObject private var limiter = AngleUsageLimiter.defenseTraining
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @StateObject private var questionNotices = BTRuleNoticeCenter()
    @StateObject private var resultNotices = BTRuleNoticeCenter()
    @StateObject private var operationNotices = BTRuleNoticeCenter()

    init(is3D: Bool) { _vm = StateObject(wrappedValue: DefensePracticeViewModel(is3D: is3D)) }
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
                DefensePracticeSettings(configuration: vm.record?.configuration ?? .init(), restarting: vm.record != nil,
                    onStart: { vm.start($0, prepared: $1) },
                    onCancel: { if !vm.cancelSettings() { dismiss() } })
                    .id(owner.ownerKey)
            default:
                tablePage.overlay {
                    if vm.phase == .summary {
                    Button { vm.reviewLastQuestion() } label: {
                        Color.black.opacity(0.45).ignoresSafeArea()
                    }.buttonStyle(.plain).accessibilityLabel("返回最后一题")
                        .accessibilityIdentifier("defense.reviewLast")
                    if let record = vm.record {
                        TrainingFinishContent(metrics: record.finishMetrics,
                            onRestart: { vm.restart() }, onComplete: { dismiss() })
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("defense.summary")
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
            if ProcessInfo.processInfo.arguments.contains("-defense.probe") {
                Color.clear.frame(width: 1, height: 1).accessibilityElement()
                    .accessibilityLabel("防守练习测试状态").accessibilityValue(vm.diagnostic)
                    .accessibilityIdentifier("defense.probe").allowsHitTesting(false)
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
            return [.init(text: notice.text, kind: .notice, symbol: "info.circle", identifier: "defense.notice")]
        }
        if questionNotices.message != nil {
            result.append(.init(text: questionPrompt, kind: .notice, symbol: "info.circle", identifier: "defense.question"))
        }
        if !hidesPendingScore, resultNotices.message != nil {
            result.append(.init(text: resultNoticeText, kind: .readout, symbol: "info.circle", identifier: "defense.result"))
        }
        return result
    }
    private var controls: BTTablePlanningControls {
        .init(spinX: Binding(get: { Double(vm.input.spinX) }, set: { vm.setSpin($0, Double(vm.input.spinY)) }),
            spinY: Binding(get: { Double(vm.input.spinY) }, set: { vm.setSpin(Double(vm.input.spinX), $0) }),
            transparency: Binding(get: { tablePreferences.snapshot(for: vm.preferencePage)[.transparency] },
                set: { tablePreferences.apply(.transparency, value: $0, to: vm.preferencePage) }),
            velocityRange: ShotTuning.velocityRange, instrumentsEnabled: vm.canAdjust,
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
                .init(id: "defense.trainingSettings", title: "训练设置", disclosure: true, disabled: vm.isBusy,
                      action: { vm.openSettings() })
            ], refreshTrajectory: {}, onLayoutEditingChanged: vm.layoutEditingChanged,
            layoutEditingBlocked: !vm.canAdjust, onAimNudged: { vm.nudgeAim($0) },
            closeupSnapshot: vm.canAdjust ? vm.closeupSnapshot : nil,
            onSpinChange: { vm.setSpin($0, $1) },
            paletteKeys: vm.record?.current?.source.keys ?? [], maximumPaletteCount: 3, paletteRoles: vm.paletteRoles,
            showsPaletteRoleNumbers: false, paletteRoleDescription: { key in
                guard let q = vm.record?.current else { return nil }
                if q.source.ownBallNumber == q.source.opponentBallNumber { return "双方目标球" }
                if key == "_\(q.source.ownBallNumber)" { return "我方目标球" }
                return key == "_\(q.source.opponentBallNumber)" ? "对方目标球" : "8号球"
            })

    }
    private var tablePage: some View {
        BTTeachingTablePage(vm: vm, titleLabel: vm.title, identifier: "defense", preferencePage: vm.preferencePage,
            insufficientSpaceMessage: "扩大窗口后继续防守练习",
            onTrainingViewChange: { vm.switchTrainingView(to: $0) }, velocity: Binding(get: { vm.velocity }, set: { vm.velocity = $0 }),
            planning: controls, information: information, usesStandardTitle: true, fitsLongTitle: true, showsPalette: true,
            pairedLeftContent: { layout in
                AnyView(VStack(spacing: layout.groupSpacing) {
                    VStack(spacing: 0) {
                        Text("题目").foregroundStyle(HUDStyle.labelColor)
                        Text(vm.record?.configuration.freePractice == true
                            ? "\(vm.record?.questionNumber ?? 1)" : "\(vm.record?.questionNumber ?? 1)/15")
                        Text("防守均分").foregroundStyle(HUDStyle.labelColor)
                        Text(hidesPendingScore ? "—" : vm.record?.average ?? "—")
                    }.font(.btCaption2).monospacedDigit().foregroundStyle(.white)
                        .frame(height: layout.topDiameter + 14)
                        .accessibilityElement(children: .combine).accessibilityIdentifier("defense.questionInfo")
                    if vm.phase == .result || vm.phase == .summary {
                        VStack(spacing: layout.groupSpacing) {
                            ScrollView(.vertical) {
                                VStack(spacing: layout.groupSpacing) {
                                    HStack(spacing: Spacing.xs) {
                                        Text("防守").foregroundStyle(HUDStyle.labelColor)
                                        Text(vm.record?.latestShot?.effect.scoreText ?? "—").foregroundStyle(.white)
                                    }.accessibilityElement(children: .combine)
                                        .accessibilityLabel("本杆防守 \(vm.record?.latestShot?.effect.scoreText ?? "—")")
                                        .accessibilityHint(vm.record?.latestShot?.effect.unavailableReason ?? "")
                                    if vm.record?.configuration.mode == .trajectory {
                                        HStack(spacing: Spacing.xs) {
                                            Text("轨迹").foregroundStyle(HUDStyle.labelColor)
                                            Text(vm.record?.latestShot?.trajectoryScore.map { String(format: "%.1f", $0) } ?? "—").foregroundStyle(.white)
                                        }.accessibilityElement(children: .combine)
                                        routeLegends
                                    }
                                }.frame(maxWidth: .infinity)
                            }
                            .scrollIndicators(.hidden)
                            .frame(minHeight: 0, maxHeight: .infinity)
                            if vm.canReplayReference {
                                BTHUDCompactAction(title: "示范", symbol: "play.rectangle", size: layout.auxiliarySize) { vm.replayReference() }
                                    .accessibilityIdentifier("defense.referenceReplay")
                            }
                        }.font(.btCaption2).monospacedDigit().frame(maxHeight: .infinity)
                            .accessibilityElement(children: .contain).accessibilityIdentifier("defense.scores")
                    } else {
                        BTTeachingAimRuler(layout: layout, enabled: vm.canAdjust, onNudge: { vm.nudgeAim($0) },
                            degreesPerPoint: AimWheelGain.degreesPerPoint(distanceMeters: cueDistance))
                            .accessibilityIdentifier("defense.aimWheel")
                    }
                    let actions = layout.horizontalActions
                        ? AnyLayout(HStackLayout(spacing: layout.groupSpacing))
                        : AnyLayout(VStackLayout(spacing: layout.groupSpacing))
                    actions {
                        BTHUDCompactAction(title: vm.playsStroke ? "重打" : "重试", symbol: "arrow.uturn.backward", size: layout.auxiliarySize) { vm.retry() }
                            .disabled(!vm.canRetry)
                            .accessibilityIdentifier("defense.retry")
                            .freeControlItem("shot.undo", name: vm.playsStroke ? "重打" : "重试")
                        if vm.phase == .result {
                            BTHUDCompactAction(title: "回放", symbol: "play.fill", size: layout.auxiliarySize) { vm.replayLastShot() }
                                .disabled(!vm.canPlayback).accessibilityIdentifier("defense.replay")
                                .freeControlItem("shot.replay", name: "回放")
                        } else {
                            BTGeometricReferenceButton(tool: vm.geometryReference, enabled: vm.canAdjust && !vm.cameraTransitionBusy,
                                size: layout.auxiliarySize, identifier: "defense.geometry", prepare: { vm.prepareGeometryReference() })
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

    private func routeSample(_ color: UIColor) -> some View {
        Path { path in path.move(to: .init(x: 0, y: 1)); path.addLine(to: .init(x: 14, y: 1)) }
            .stroke(Color(color), style: StrokeStyle(lineWidth: 1.5, dash: SeparationRouteStyle.legendDash))
            .frame(width: 14, height: 2).accessibilityHidden(true)
    }
    private func routeLegend(_ key: String, target: Bool) -> some View {
        let cue = key == ShotInput.cueBallName
        let role = target ? "目标" : "实际"
        let ball = cue ? "母球" : "\(PositionPlayBall.number(for: key) ?? 0)号球"
        let color = target ? DefenseRouteStyle.target(for: key)
            : cue ? TrajectoryStyle.aimColor : TrajectoryStyle.potColor(for: key)
        return HStack(spacing: Spacing.xs) {
            routeSample(color)
            Text(role + (cue ? "母" : "\(PositionPlayBall.number(for: key) ?? 0)"))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(role + ball + "路线")
    }
    private var routeLegends: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(vm.referenceRouteKeys, id: \.self) { routeLegend($0, target: true) }
            }.accessibilityIdentifier("defense.targetLegend")
            VStack(alignment: .leading, spacing: 2) {
                ForEach(vm.actualRouteKeys, id: \.self) { routeLegend($0, target: false) }
            }.accessibilityIdentifier("defense.actualLegend")
        }.font(.btCaption2).foregroundStyle(.white)
    }

    private var hidesPendingScore: Bool { !vm.isReplaying && vm.phase == .playing }
    private var cueDistance: Float {
        guard let board = vm.record?.current?.board else { return 1 }
        return hypot(board.cue.x-board.target.x, board.cue.z-board.target.z)
    }
}
