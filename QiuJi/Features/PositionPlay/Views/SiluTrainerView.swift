import SwiftUI
import SceneKit

/// Constraint solving keeps its own model and actions inside the shared daily table shell.
struct SiluTrainerView: View {
    let initialBoard: BoardSnapshot?
    init(initialBoard: BoardSnapshot? = nil) { self.initialBoard = initialBoard }
    @State private var informationPanel: PlanningPanel?
    @StateObject private var vm = SiluTrainerViewModel()
    @State private var showBreakPicker = false
    @State private var drawingConstraint = false
    @Environment(\.scenePhase) private var scenePhase
    private var busy: Bool { vm.isPlaying || vm.isComputing || vm.breakRunner?.isBusy == true }
    private var toolName: String {
        switch vm.activeTool { case .none: return "摆球"; case .region: return "落区"; case .restPoint: return "落点"; case .passPoint: return "过点" }
    }

    @AppStorage("silu.allowSideSpin") private var savedAllowSideSpin = true
    @AppStorage("silu.basicPositionOnly") private var savedBasicPositionOnly = false
    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    private var spinTransparency: Double {
        get { tablePreferences.snapshot(for: .silu)[.transparency] }
        nonmutating set { tablePreferences.apply(.transparency, value: newValue, to: .silu) }
    }
    private var hides3DAssists: Bool { !tablePreferences.snapshot(for: .silu).enabled(.shows3DTrajectory) }
    var body: some View {
        BTTeachingTablePage(vm: vm, titleLabel: "思路训练", identifier: "silu", preferencePage: .silu,
            velocity: velocity, planning: controls,
            usesStandardTitle: true,
            pairedLeftContent: vm.isBreakMode ? { AnyView(breakControls($0)) } : nil,
            title: { EmptyView() },
            leftContent: { size in leftControls(size) },
            status: { informationOverlay }, onPalettePlace: { vm.placeFromPalette($0, atWorld: $1) })
        .sheet(isPresented: $showBreakPicker) {
            BreakGamePickerSheet { vm.startBreakFlow(game: $0) }
                .presentationDetents([.height(360)]).presentationDragIndicator(.visible)
        }
        .sheet(item: $informationPanel) { panel in
            PlanningInformationSheet(panel: panel, sections: informationSections(panel))
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { drawingConstraint = false } }
        .onDisappear { drawingConstraint = false }
        #if DEBUG
        .overlay(alignment: .bottom) {
            if DailyLayoutProbe.enabled {
                Color.clear.frame(width: 1, height: 1).allowsHitTesting(false)
                    .accessibilityElement().accessibilityIdentifier("silu.layoutState")
                    .accessibilityValue("target=\(vm.selectedTargetKey ?? "none") pocket=\(vm.selectedPocketIndex) tool=\(vm.activeTool) solutions=\(vm.solutions.count) index=\(vm.currentIndex) adjusted=\(vm.isSolutionAdjusted) spinX=\(vm.spinX) spinY=\(vm.spinY) velocity=\(vm.velocity) break=\(vm.isBreakMode)")
            }
        }
        #endif
    }

    private func breakControls(_ metrics: BTTeachingInstrumentLayout) -> some View {
        VStack(spacing: metrics.groupSpacing) {
            BTTeachingInstrumentEntry(layout: metrics, label: "开球") {
                Button {
                    vm.breakRunner?.reRack()
                    if vm.cameraMode == .perspective3D { vm.requestPlayerView(.thirdPerson) }
                } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 22)).foregroundStyle(.white)
                        .frame(width: metrics.topDiameter, height: metrics.topDiameter)
                        .background { BTHUDControlBackground(shape: Circle()) }
                }.buttonStyle(BTHUDPressStyle()).disabled(busy || vm.temporaryTopDownActive)
                    .opacity(busy || vm.temporaryTopDownActive ? 0.3 : 1)
                    .accessibilityLabel("重开").accessibilityIdentifier("break.rerack")
            }
            .freeControlItem("break.rerack", name: "重开")
            BTTeachingAimRuler(layout: metrics, enabled: !busy && !vm.temporaryTopDownActive,
                onNudge: { vm.breakRunner?.nudgeAim(byDegrees: $0) },
                degreesPerPoint: vm.breakRunner?.aimWheelDegreesPerPoint ?? AimWheelGain.defaultDegreesPerPoint)
        }
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
            hides3DAssists: Binding(get: { hides3DAssists }, set: { tablePreferences.apply(.shows3DTrajectory, value: $0 ? 0 : 1, to: .silu) }),
            velocityRange: vm.isBreakMode ? BreakFlowRunner.breakVelocityRange : ShotTuning.velocityRange,
            instrumentsEnabled: (!busy || vm.isAdjustingSolution) && (vm.isBreakMode || vm.hasSolutions), isAnimating: busy,
            paletteEnabled: !busy && !vm.isBreakMode,
            primaryTitle: vm.breakRunner.map { $0.showsConfirm ? "完成" : "开球" } ?? (vm.isComputing ? "计算中" : "击球"),
            primaryEnabled: vm.isBreakMode ? !busy : vm.canStrike,
            onPrimary: {
                if let runner = vm.breakRunner {
                    if runner.showsConfirm { runner.confirmSettled() } else { runner.breakNow() }
                } else { vm.play() }
            }, primaryControlID: vm.isBreakMode ? (vm.breakRunner?.showsConfirm == true ? "break.confirm" : "break.strike") : "shot.strike", onPaletteTap: { key in
                if vm.onTableKeys.contains(key) { vm.pulseTableBall(key) } else { vm.placeFromPalette(key) }
            }, menuItems: menuItems, refreshTrajectory: { vm.redrawTrajectory() },
            applyPreferences: { vm.hides3DShotAssists = !$0.enabled(.shows3DTrajectory) }, onSetup: { vm.allowSideSpin = savedAllowSideSpin; vm.basicPositionOnly = savedBasicPositionOnly; vm.hides3DShotAssists = hides3DAssists; if let initialBoard { vm.loadBoard(initialBoard) } },
            onDisappear: { vm.stopForDismissal() },
            layoutEditingBlocked: drawingConstraint || vm.breakRunner?.showsConfirm == true,
            onAimNudged: vm.isBreakMode ? { vm.breakRunner?.nudgeAim(byDegrees: $0) } : nil,
            closeupSnapshot: vm.canStrike ? vm.solvedContactCloseup : nil,
            closeupUnavailableReason: vm.canStrike && vm.solvedContactCloseup != nil ? nil : "当前首碰暂无特写",
            onSpinChange: { x, y in
                if let runner = vm.breakRunner { runner.spinX = x; runner.spinY = y }
                else { vm.adjustCurrentSolution(spinX: x, spinY: y) }
            },
            overlay: { projector, frame in
                if !vm.isBreakMode && !busy && vm.activeTool != .none {
                    return AnyView(SolveConstraintDrawingOverlay(coordinateSpaceName: "silu", sceneFrame: frame,
                        unproject: { projector.unproject?($0) }, onDrag: {
                            vm.toolDrag(startNormalized: $0, currentNormalized: $1, ended: $2)
                        }, onDragActiveChanged: { drawingConstraint = $0 }))
                }
                return AnyView(EmptyView())
            })
    }

    private func leftControls(_ size: CGSize) -> some View {
        FreeControlColumn {
            VStack(spacing: 4) {
                if !vm.isBreakMode {
                    Menu {
                        BTChoiceMenuItem(title: "落区", selected: vm.activeTool == .region) { vm.activeTool = .region }
                        BTChoiceMenuItem(title: "落点", selected: vm.activeTool == .restPoint) { vm.activeTool = .restPoint }
                        BTChoiceMenuItem(title: "过点", selected: vm.activeTool == .passPoint) { vm.activeTool = .passPoint }
                        BTChoiceMenuItem(title: "摆球", selected: vm.activeTool == .none) { vm.activeTool = .none }
                    } label: {
                        Text(toolName).font(.btCaption).foregroundStyle(.white).frame(width: 44, height: 44)
                            .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                    }.overlay(alignment: .topTrailing) { TeachingMenuIndicator() }.disabled(busy)
                        .opacity(busy ? 0.4 : 1).accessibilityIdentifier("silu.tool")
                        .freeControlItem("planning.constraintTool", name: "约束工具")
                    action("清除", "eraser", "silu.clearConstraint", enabled: !busy && vm.hasConstraint) { vm.clearConstraint() }
                        .freeControlItem("planning.clearConstraint", name: "清除约束")
                    action("求解", TeachingSolverSymbols.solve, "solver.solve", enabled: !busy && vm.hasConstraint) { vm.solve() }
                        .freeControlItem("planning.solve", name: "求解")
                    TeachingSolutionButton(count: vm.solutions.count, currentIndex: vm.currentIndex,
                        enabled: !busy, next: { vm.nextSolution() },
                        isModified: vm.isSolutionAdjusted)
                        .freeControlItem("planning.nextSolution", name: "下一解")
                    action("重打", "arrow.uturn.backward", "silu.undo", enabled: !busy && !vm.temporaryTopDownActive && vm.canUndoShot) { vm.undoLastShot() }
                        .freeControlItem("shot.undo", name: "重打")
                    action("回放", "play.rectangle", "silu.replay", enabled: !busy && !vm.temporaryTopDownActive && vm.canPlayback) { vm.replayLastShot() }
                        .freeControlItem("shot.replay", name: "回放")
                }
            }.frame(maxWidth: .infinity)
        }.frame(width: size.width, height: min(size.height, vm.isBreakMode ? 232 : 284), alignment: .top)
    }
    private func action(_ title: String, _ icon: String, _ id: String, enabled: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 1) { Image(systemName: icon).font(.system(size: 17)); Text(title).font(.system(size: 10)) }
                .frame(width: 44, height: 44).background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        }.buttonStyle(BTHUDPressStyle()).disabled(!enabled).opacity(enabled ? 1 : 0.4).accessibilityLabel(title).accessibilityIdentifier(id)
            .accessibilityHint(id == "solver.solve" && !enabled ? (compactPrompt ?? "请查看更多中的操作说明") : "")
    }
    private var menuItems: [DailyHUDMenuItem] {
        var items: [DailyHUDMenuItem] = [
            .init(id: "silu.help", title: "操作说明", disclosure: true, disabled: vm.isBreakMode, action: { informationPanel = .help }),
            .init(id: "silu.solveOptions", title: "求解范围"),
            .init(id: "silu.sideSpin", title: "允许左右塞", selected: vm.allowSideSpin, disabled: busy || vm.isBreakMode, action: { vm.allowSideSpin.toggle(); savedAllowSideSpin = vm.allowSideSpin }),
            .init(id: "silu.basicOnly", title: "仅基础走位（≤1库）", selected: vm.basicPositionOnly, disabled: busy || vm.isBreakMode, action: { vm.basicPositionOnly.toggle(); savedBasicPositionOnly = vm.basicPositionOnly })]
        if vm.isBreakMode {
            items.append(.init(id: "silu.cancelBreak", title: "取消开球", disabled: busy, action: { vm.cancelBreakFlow() }))
        } else {
            items += [.init(id: "break.entry", title: "开球", disclosure: true, disabled: busy, action: { showBreakPicker = true }),
                .init(id: "silu.clear", title: "清空桌面", disabled: busy, action: { vm.clearTable() }),
                .init(id: "silu.reset", title: "恢复默认球形", disabled: busy, action: { vm.resetAll() })]
        }
        return items
    }
    @ViewBuilder private var informationOverlay: some View {
        if let runner = vm.breakRunner {
            BTTeachingInformationLayer(items: [.init(text: runner.statusText(isPerspective: vm.cameraMode == .perspective3D))])
        } else {
            PlanningInformationOverlay(page: "silu", event: vm.informationEvent, prompt: compactPrompt,
                solution: vm.currentSolution, defense: false, busy: busy,
                setupComplete: vm.hasConstraint && vm.selectedTargetKey != nil && vm.selectedPocketIndex >= 0, introduction: "拖球摆位，选择目标球、目标袋和约束；更多操作可查看说明。")
        }
    }
    private var compactPrompt: String? {
        if !vm.onTableKeys.contains(PositionPlayBall.cueKey) { return "请摆上母球" }
        if vm.selectedTargetKey == nil { return "选择目标球" }
        if vm.selectedPocketIndex < 0 { return "选择目标袋" }
        guard !vm.hasConstraint else { return nil }
        switch vm.activeTool {
        case .none: return nil
        case .region: return "拖出落区"
        case .restPoint: return "点选落点"
        case .passPoint: return "点选过点"
        }
    }
    private func informationSections(_ panel: PlanningPanel) -> [(String, String)] {
        var sections: [(String, String)] = []
        if vm.informationEvent.kind == .failure { sections.append(("当前问题", vm.informationEvent.text)) }
        else if let prompt = compactPrompt { sections.append(("当前步骤", prompt)) }
        sections += [
            ("摆球与选择", "拖动球调整球形；点选目标球和目标袋。完成选择与约束后求解。"),
            ("约束工具", "落区：拖出母球期望停下的区域。\n落点：点选母球期望停下的位置；琥珀十字表示目标，圆环表示容差。\n过点：点选母球需要经过的位置。\n切回“摆球”可继续选择目标球和袋口。"),
            ("方案与微调", "轻点解按钮切换下一解，按钮显示当前序号和总数。调整打点、杆速后，当前方案标记“微调”。不满足约束或超出筛选范围的方案仍保留提示。")
        ]
        return sections
    }
}
