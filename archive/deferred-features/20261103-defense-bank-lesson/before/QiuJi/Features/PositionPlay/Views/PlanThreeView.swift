import SwiftUI
import SceneKit

/// Constraint solving keeps its own model and actions inside the shared daily table shell.
struct PlanThreeView: View {
    let initialBoard: BoardSnapshot?
    init(initialBoard: BoardSnapshot? = nil) { self.initialBoard = initialBoard }
    @State private var informationPanel: PlanningPanel?
    @StateObject private var vm = PlanThreeViewModel()
    @State private var pocketOrientation = PocketDisplay.Orientation.landscape
    @AppStorage("planThree.breakGameBallCount") private var breakGameBallCount = 15
    private var busy: Bool { vm.isPlaying || vm.isComputing || vm.breakRunner?.isBusy == true }

    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    private var spinTransparency: Double {
        get { tablePreferences.snapshot(for: .planThree)[.transparency] }
        nonmutating set { tablePreferences.apply(.transparency, value: newValue, to: .planThree) }
    }
    private var hides3DAssists: Bool { !tablePreferences.snapshot(for: .planThree).enabled(.shows3DTrajectory) }
    var body: some View {
        BTTeachingTablePage(vm: vm, titleLabel: "打一走二想三", identifier: "planthree", preferencePage: .planThree,
            velocity: velocity, planning: controls,
            usesStandardTitle: true,
            onPocketOrientationChange: { pocketOrientation = $0 },
            pairedLeftContent: { layout in
                vm.isBreakMode ? AnyView(breakControls(layout)) : AnyView(planningControls(layout))
            },
            title: { EmptyView() },
            leftContent: { _ in EmptyView() },
            status: { informationOverlay }, onPalettePlace: { vm.placeFromPalette($0, atWorld: $1) })
        .toolUsageSession(.planThree)
        #if DEBUG
        .overlay(alignment: .bottom) {
            if DailyLayoutProbe.enabled {
                Color.clear.frame(width: 1, height: 1).allowsHitTesting(false)
                    .accessibilityElement().accessibilityIdentifier("planthree.layoutState")
                    .accessibilityValue("target=\(vm.ball1Key ?? "none") second=\(vm.ball2Key ?? "none") third=\(vm.ball3Key ?? "none") pocket=\(vm.pocket1Index) secondPocket=\(vm.pocket2Index) armed=\(vm.armedRole?.rawValue ?? -1) tool=\(vm.activeTool) constraint=\(String(describing: vm.draft)) solutions=\(vm.solutions.count) index=\(vm.currentIndex) adjusted=\(vm.isSolutionAdjusted) spinX=\(vm.spinX) spinY=\(vm.spinY) velocity=\(vm.velocity) rings=\(vm.scene.rootNode.childNodes.filter { $0.name?.hasPrefix("planthree.roleRing.") == true }.count) recommended=\(vm.recommendedRegion != nil) break=\(vm.isBreakMode)")
            }
        }
        #endif
        .sheet(item: $informationPanel) { panel in
            PlanningInformationSheet(panel: panel, sections: informationSections(panel))
        }
    }

    private func breakControls(_ metrics: BTTeachingInstrumentLayout) -> some View {
        VStack(spacing: metrics.groupSpacing) {
            breakEntry(metrics)
            BTTeachingAimRuler(layout: metrics, enabled: !busy && !vm.temporaryTopDownActive,
                onNudge: { vm.breakRunner?.nudgeAim(byDegrees: $0) },
                degreesPerPoint: vm.breakRunner?.aimWheelDegreesPerPoint ?? AimWheelGain.defaultDegreesPerPoint)
        }
    }

    private func breakEntry(_ layout: BTTeachingInstrumentLayout) -> some View {
        Button {
            if let runner = vm.breakRunner { runner.reRack() }
            else { vm.startBreakFlow(game: BreakFlowRunner.game(forBallCount: breakGameBallCount)) }
            if vm.cameraMode == .perspective3D { vm.requestPlayerView(.thirdPerson) }
        } label: {
            VStack(spacing: 2) {
                BreakRackGlyph(color: HUDStyle.valueMeasured, size: layout.topDiameter - 1, hollowBalls: true)
                    .btHUDActionContent()
                    .frame(width: layout.topDiameter, height: layout.topDiameter)
                    .background { BTHUDControlBackground(shape: Circle()) }
                    .overlay(Circle().stroke(HUDStyle.hairline, lineWidth: 1))
                Text(vm.isBreakMode ? "重开" : "开球").font(.btMicro).btHUDActionContent()
            }.frame(width: layout.columnWidth).contentShape(Rectangle())
        }
        .buttonStyle(BTHUDPressStyle())
        .disabled(busy || vm.temporaryTopDownActive || vm.cameraTransitionBusy)
        .opacity(busy || vm.temporaryTopDownActive || vm.cameraTransitionBusy ? 0.3 : 1)
        .accessibilityLabel(vm.isBreakMode ? "重开" : "开球")
        .accessibilityValue(BreakFlowRunner.title(for: vm.breakRunner?.game ?? BreakFlowRunner.game(forBallCount: breakGameBallCount)))
        .accessibilityIdentifier(vm.isBreakMode ? "break.rerack" : "break.entry")
        .freeControlItem(vm.isBreakMode ? "break.rerack" : "break.entry", name: "开球")
    }

    private var velocity: Binding<Double> {
        Binding(get: { vm.breakRunner?.velocity ?? vm.velocity }, set: {
            if let runner = vm.breakRunner { runner.velocity = $0 }
            else { vm.adjustCurrentSolution(velocity: $0) }
        })
    }
    private var spinX: Binding<Double> {
        Binding(get: { vm.breakRunner?.spinX ?? vm.spinX }, set: {
            if let runner = vm.breakRunner { runner.spinX = $0 }
            else { vm.adjustCurrentSolution(spinX: $0) }
        })
    }
    private var spinY: Binding<Double> {
        Binding(get: { vm.breakRunner?.spinY ?? vm.spinY }, set: {
            if let runner = vm.breakRunner { runner.spinY = $0 }
            else { vm.adjustCurrentSolution(spinY: $0) }
        })
    }
    private var controls: BTTablePlanningControls {
        BTTablePlanningControls(spinX: spinX, spinY: spinY, transparency: Binding(get: { spinTransparency }, set: { spinTransparency = $0 }),
            hides3DAssists: Binding(get: { hides3DAssists }, set: { tablePreferences.apply(.shows3DTrajectory, value: $0 ? 0 : 1, to: .planThree) }),
            velocityRange: vm.isBreakMode ? BreakFlowRunner.breakVelocityRange : ShotTuning.velocityRange,
            instrumentsEnabled: (!busy || vm.isAdjustingSolution) && (vm.isBreakMode || vm.hasSolutions), isAnimating: busy,
            paletteEnabled: !busy && !vm.isBreakMode,
            primaryTitle: vm.isBreakMode ? "开球" : vm.primaryActionTitle,
            primaryEnabled: !busy && !vm.temporaryTopDownActive && !vm.cameraTransitionBusy,
            onPrimary: {
                if let runner = vm.breakRunner {
                    runner.breakNow()
                } else { vm.requestPrimaryAction() }
            }, primaryControlID: vm.isBreakMode ? "break.strike" : "shot.strike", onPaletteTap: { key in
                if vm.onTableKeys.contains(key) {
                    if PositionPlayBall.isCue(key) { vm.pulseTableBall(key) }
                    else { vm.selectPaletteBall(key) }
                } else { vm.placeFromPalette(key) }
            }, menuItems: menuItems, refreshTrajectory: { vm.redrawTrajectory() },
            applyPreferences: { vm.hides3DShotAssists = !$0.enabled(.shows3DTrajectory) }, onSetup: { vm.hides3DShotAssists = hides3DAssists; if let initialBoard { vm.loadBoard(initialBoard) }; applyUITestHooksIfNeeded(); vm.activeTool = .none },
            onDisappear: { vm.stopForDismissal() },
            layoutEditingBlocked: informationPanel != nil || vm.breakRunner?.showsConfirm == true,
            onAimNudged: vm.isBreakMode ? { vm.breakRunner?.nudgeAim(byDegrees: $0) } : nil,
            showsAimCloseupSetting: false,
            showsTrajectorySetting: false,
            showsSeparationSetting: false,
            onSpinChange: { x, y in
                if let runner = vm.breakRunner { runner.spinX = x; runner.spinY = y }
                else { vm.adjustCurrentSolution(spinX: x, spinY: y) }
            },
            paletteRoles: vm.paletteRoles, paletteRoleDescription: { vm.paletteRoleDescription($0, orientation: pocketOrientation) },
            onPaletteClearRole: { vm.clearPaletteRole($0) }, breakGameSelection: Binding(get: { breakGameBallCount }, set: { count in
                breakGameBallCount = count
                vm.selectBreakGame(BreakFlowRunner.game(forBallCount: count))
            }))
    }

    private func planningControls(_ layout: BTTeachingInstrumentLayout) -> some View {
        VStack(spacing: layout.groupSpacing) {
            VStack(spacing: layout.groupSpacing) {
                breakEntry(layout).frame(height: layout.topDiameter + 14)
                BTTeachingAimRulerSpace(layout: layout)
                    .frame(height: layout.rulerLength + 30)
                    .overlay(alignment: .bottom) {
                        TeachingSolutionButton(count: vm.solutions.count, currentIndex: vm.currentIndex,
                            enabled: !busy && !vm.temporaryTopDownActive, next: { vm.nextSolution() },
                            isModified: vm.isSolutionAdjusted)
                            .freeControlItem("planning.nextSolution", name: "下一解")
                            .frame(width: layout.horizontalActions ? layout.auxiliarySize * 2 + layout.groupSpacing : layout.columnWidth, alignment: layout.horizontalActions ? .leading : .center)
                            .frame(width: layout.columnWidth, alignment: layout.horizontalActions ? .trailing : .center)
                    }
            }
            let actions = layout.horizontalActions
                ? AnyLayout(HStackLayout(spacing: layout.groupSpacing))
                : AnyLayout(VStackLayout(spacing: layout.groupSpacing))
            actions {
                BTHUDCompactAction(title: vm.canGoToPreviousStep || !vm.canUndoShot ? "上一步" : "重打",
                    symbol: "arrow.uturn.backward", size: layout.auxiliarySize) {
                    if vm.canGoToPreviousStep { vm.goToPreviousStep() } else { vm.undoLastShot() }
                }.disabled(busy || vm.temporaryTopDownActive || !(vm.canGoToPreviousStep || vm.canUndoShot))
                    .accessibilityIdentifier("planthree.undo")
                    .freeControlItem("shot.undo", name: vm.canGoToPreviousStep || !vm.canUndoShot ? "上一步" : "重打")
                BTHUDCompactAction(title: "回放", symbol: "play.rectangle", size: layout.auxiliarySize) { vm.replayLastShot() }
                    .disabled(busy || vm.temporaryTopDownActive || !vm.canPlayback)
                    .accessibilityIdentifier("planthree.replay")
                    .freeControlItem("shot.replay", name: "回放")
            }
        }.frame(width: layout.columnWidth)
    }

    private var menuItems: [DailyHUDMenuItem] {
        var items: [DailyHUDMenuItem] = []
        items.append(.init(id: "planthree.help", title: "操作说明", disclosure: true, disabled: vm.isBreakMode,
                           action: { informationPanel = .help }))
        return items
    }

    private func applyUITestHooksIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        for scenario in ["threeBall", "threeBallDimmed", "twoBallDimmed", "twoBall", "oneBall", "cleared", "cornerReturn"]
            where args.contains("-planThree.\(scenario)") {
            vm.uiTestConfigure(scenario)
            return
        }
    }
    @ViewBuilder private var informationOverlay: some View {
        if let runner = vm.breakRunner {
            if let message = runner.actionRequiredMessage {
                BTTeachingInformationLayer(items: [.init(text: message)])
            }
        } else {
            PlanningInformationOverlay(page: "planthree", event: vm.informationEvent, prompt: nil,
                solution: vm.informationEvent.text.isEmpty ? nil : vm.currentSolution, defense: false, busy: busy,
                setupComplete: true, introduction: "")
        }
    }
    private var compactPrompt: String? { vm.missingSelection }
    private func informationSections(_ panel: PlanningPanel) -> [(String, String)] {
        var sections: [(String, String)] = []
        if vm.informationEvent.kind == .failure { sections.append(("当前问题", vm.informationEvent.text)) }
        else if let prompt = compactPrompt { sections.append(("当前步骤", prompt)) }
        sections += [
            ("计划", "依次点球库里的当前球、当前袋口、下一球、下一袋口和后续球。要改选，先点球库中对应的已选球，再点替换球或袋口。第三球不需要选袋；长按球库中已选球可清除该项。"),
            ("摆球与求解", "未击球时可直接拖动球或从球库摆球。按台面剩余球数选齐计划后自动求解；亮琥珀色虚线为自动推荐落区。暂无推荐区域时可调整球形或袋口。求解完成后可点击击球；改球形或计划后自动更新方案。计划未完整时，点击击球查看缺项提示。"),
            ("上一步与重打", "上一步按第三球、第二颗球袋口、第二颗球、第一颗球袋口、第一颗球逐步返回，每次清除后续选择及标记，桌上的球保持原位。击球后承接的球和袋口仍可修改。退到第一步后，有上一杆时按钮变为重打，恢复上一杆击打前的球形、计划和方案；回放结束后恢复进入回放前的草稿。"),
            ("方案", "轻点解按钮切换下一解，按钮显示当前序号和总数。打点和杆速调整后显示“微调”。")
        ]
        return sections
    }
}
