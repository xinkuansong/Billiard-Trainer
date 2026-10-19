import SwiftUI
import SceneKit

/// Defense retains its legal target and coverage solver inside the shared table shell.
struct SnookerTacticsView: View {
    let initialBoard: BoardSnapshot?
    init(initialBoard: BoardSnapshot? = nil) { self.initialBoard = initialBoard }
    @State private var informationPanel: PlanningPanel?
    @StateObject private var vm = SnookerTacticsViewModel()
    private var busy: Bool { vm.isPlaying || vm.isComputing }

    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    private var spinTransparency: Double {
        get { tablePreferences.snapshot(for: .snookerTactics)[.transparency] }
        nonmutating set { tablePreferences.apply(.transparency, value: newValue, to: .snookerTactics) }
    }
    private var hides3DAssists: Bool { !tablePreferences.snapshot(for: .snookerTactics).enabled(.shows3DTrajectory) }
    var body: some View {
        BTTeachingTablePage(vm: vm, titleLabel: "防守", identifier: "snooker", preferencePage: .snookerTactics, velocity: velocity,
            planning: controls,
            usesStandardTitle: true,
            title: { EmptyView() },
            leftContent: { size in leftControls(size) },
            status: { informationOverlay }, onPalettePlace: { vm.placeFromPalette($0, atWorld: $1) })
        #if DEBUG
        .overlay(alignment: .bottom) {
            if DailyLayoutProbe.enabled {
                Color.clear.frame(width: 1, height: 1).allowsHitTesting(false)
                    .accessibilityElement().accessibilityIdentifier("snooker.layoutState")
                    .accessibilityValue("target=\(vm.selectedTargetKey ?? "none") opponents=\(vm.opponentKeys.sorted().joined(separator: ",")) tool=\(vm.activeTool) solutions=\(vm.solutions.count) index=\(vm.currentIndex) adjusted=\(vm.isSolutionAdjusted) spinX=\(vm.spinX) spinY=\(vm.spinY) velocity=\(vm.velocity)")
            }
        }
        #endif
        .sheet(item: $informationPanel) { panel in
            PlanningInformationSheet(panel: panel, sections: informationSections(panel))
        }
    }
    private var velocity: Binding<Double> {
        Binding(get: { vm.velocity }, set: { vm.adjustCurrentSolution(velocity: $0) })
    }
    private var controls: BTTablePlanningControls {
        BTTablePlanningControls(
            spinX: Binding(get: { vm.spinX }, set: { vm.adjustCurrentSolution(spinX: $0) }),
            spinY: Binding(get: { vm.spinY }, set: { vm.adjustCurrentSolution(spinY: $0) }),
            transparency: Binding(get: { spinTransparency }, set: { spinTransparency = $0 }),
            hides3DAssists: Binding(get: { hides3DAssists }, set: { tablePreferences.apply(.shows3DTrajectory, value: $0 ? 0 : 1, to: .snookerTactics) }),
            velocityRange: ShotTuning.velocityRange, instrumentsEnabled: (!busy || vm.isAdjustingSolution) && vm.hasSolutions,
            isAnimating: busy, paletteEnabled: !busy, allowsPocketSelection: false,
            primaryTitle: vm.isComputing ? "计算中" : "击球", primaryEnabled: vm.canStrike,
            onPrimary: { vm.play() }, onPaletteTap: { key in
                if vm.onTableKeys.contains(key) { vm.pulseTableBall(key) } else { vm.placeFromPalette(key) }
            }, menuItems: [
                .init(id: "snooker.help", title: "操作说明", disclosure: true, action: { informationPanel = .help }),
                .init(id: "snooker.board", title: "球形"),
                .init(id: "snooker.clear", title: "清空桌面", disabled: busy, action: { vm.clearTable() }),
                .init(id: "snooker.reset", title: "恢复默认球形", disabled: busy, action: { vm.resetAll() })
            ], refreshTrajectory: { vm.redrawTrajectory() }, applyPreferences: { vm.hides3DShotAssists = !$0.enabled(.shows3DTrajectory) }, onSetup: {
                vm.hides3DShotAssists = hides3DAssists
                if let initialBoard { vm.loadBoard(initialBoard) }
                for scenario in ["full", "partial", "none"] where ProcessInfo.processInfo.arguments.contains("-snooker.\(scenario)") {
                    vm.uiTestConfigure(scenario); break
                }
            }, onDisappear: { vm.stopForDismissal() },
            layoutEditingBlocked: informationPanel != nil,
            closeupSnapshot: vm.canStrike ? vm.solvedContactCloseup : nil,
            closeupUnavailableReason: vm.canStrike && vm.solvedContactCloseup != nil ? nil : "当前首碰暂无特写",
            onSpinChange: { vm.adjustCurrentSolution(spinX: $0, spinY: $1) })
    }
    private func leftControls(_ size: CGSize) -> some View {
        FreeControlColumn {
            VStack(spacing: 4) {
                Menu {
                    Section("当前选择") {
                        ForEach(targetSummary, id: \.self) { Text($0) }
                    }
                    Button("目标球") { vm.activeTool = .selectTarget }
                    Button("摆球") { vm.activeTool = .none }
                } label: {
                    Text(vm.activeTool == .selectTarget ? "目标球" : "摆球").font(.btCaption).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                }.overlay(alignment: .topTrailing) { TeachingMenuIndicator() }.disabled(busy)
                    .opacity(busy ? 0.4 : 1).accessibilityIdentifier("snooker.tool")
                    .freeControlItem("defense.targetTool", name: "防守目标")
                action("清除", "eraser", "snooker.clearSelection", enabled: !busy && vm.selectedTargetKey != nil) { vm.clearSelection() }
                    .freeControlItem("defense.clearSelection", name: "清除目标")
                action("求解", TeachingSolverSymbols.solve, "solver.solve", enabled: !busy && vm.canSolve) { vm.solve() }
                    .freeControlItem("planning.solve", name: "求解")
                TeachingSolutionButton(count: vm.solutions.count, currentIndex: vm.currentIndex,
                        enabled: !busy, next: { vm.nextSolution() },
                        isModified: vm.isSolutionAdjusted)
                    .freeControlItem("planning.nextSolution", name: "下一解")
                action("重打", "arrow.uturn.backward", "snooker.undo", enabled: !busy && !vm.temporaryTopDownActive && vm.canUndoShot) { vm.undoLastShot() }
                    .freeControlItem("shot.undo", name: "重打")
                action("回放", "play.rectangle", "snooker.replay", enabled: !busy && !vm.temporaryTopDownActive && vm.canPlayback) { vm.replayLastShot() }
                    .freeControlItem("shot.replay", name: "回放")
            }.frame(maxWidth: .infinity)
        }.frame(width: size.width, height: min(size.height, 284), alignment: .top)
    }
    private func action(_ title: String, _ icon: String, _ id: String, enabled: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 1) { Image(systemName: icon).font(.system(size: 17)); Text(title).font(.system(size: 10)) }
                .frame(width: 44, height: 44).background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        }.buttonStyle(BTHUDPressStyle()).disabled(!enabled).opacity(enabled ? 1 : 0.4).accessibilityLabel(title).accessibilityIdentifier(id)
            .accessibilityHint(id == "solver.solve" && !enabled ? (compactPrompt ?? "请查看更多中的操作说明") : "")
    }
    @ViewBuilder private var informationOverlay: some View {
            PlanningInformationOverlay(page: "snooker", event: vm.informationEvent, prompt: compactPrompt,
                solution: vm.currentSolution, defense: true, busy: busy,
                setupComplete: vm.hasSolutions, introduction: "选择首碰目标球，再求解防守；可在目标球菜单核查对方球组。")
    }
    private var compactPrompt: String? {
        if !vm.onTableKeys.contains(PositionPlayBall.cueKey) { return "请摆上母球" }
        if vm.selectedTargetKey == nil { return "选择首碰目标球" }
        if vm.opponentKeys.isEmpty { return "没有需要隐藏的对方球，请调整球形" }
        return nil
    }
    private func informationSections(_ panel: PlanningPanel) -> [(String, String)] {
        var sections: [(String, String)] = []
        if vm.informationEvent.kind == .failure { sections.append(("当前问题", vm.statusText)) }
        else if let prompt = compactPrompt { sections.append(("当前步骤", prompt)) }
        sections += [
            ("首碰目标球", "使用“目标球”工具选择本杆合法首碰的球。按中八规则，从首碰目标球推断对方球组；可在目标球菜单核查球号与数量。台面同时有全色和花色时，不能选择8号为首碰目标。"),
            ("防守方案", "求解尝试让对方球尽量被遮挡。标记“未完全斯诺克”的方案没有完全达到防守目标，请结合轨迹判断。"),
            ("方案与重打", "轻点解按钮切换下一解，按钮显示当前序号和总数。调整打点和杆速后显示“微调”。重打恢复击打前状态；回放结束后停在击打后的局面。")
        ]
        return sections
    }
    private var targetSummary: [String] {
        let target = vm.selectedTargetKey.map { String($0.dropFirst()) + "号球" } ?? "未选择"
        let opponents = vm.opponentKeys.map { String($0.dropFirst()) }.joined(separator: "、")
        let group: String
        switch vm.opponentKeys.first.flatMap({ BallGroup.of($0) }) {
        case .solid: group = "全色"
        case .stripe: group = "花色"
        case .eight: group = "8号球"
        case .none: group = "无"
        }
        return ["首碰：" + target,
                "对方球组：" + group + "（\(vm.opponentKeys.count)颗）",
                "球号：" + (opponents.isEmpty ? "无" : opponents + "号")]
    }
}
