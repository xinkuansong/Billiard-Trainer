import SwiftUI
import SceneKit

/// Constraint solving keeps its own model and actions inside the shared daily table shell.
struct PlanThreeView: View {
    let initialBoard: BoardSnapshot?
    init(initialBoard: BoardSnapshot? = nil) { self.initialBoard = initialBoard }
    @State private var selectedRolePrompt: PlanThreeRole?
    @State private var informationPanel: PlanningPanel?
    @StateObject private var vm = PlanThreeViewModel()
    @State private var pocketOrientation = PocketDisplay.Orientation.landscape
    @State private var showBreakPicker = false
    @AppStorage("planthree.spinTransparency") private var spinTransparency = 0.5
    @AppStorage("planthree.hides3DAssists") private var hides3DAssists = false
    private var busy: Bool { vm.isPlaying || vm.isComputing || vm.breakRunner?.isBusy == true }
    private var toolName: String {
        switch vm.activeTool { case .none: return "摆球"; case .region: return "落区"; case .restPoint: return "落点"; case .passPoint: return "过点" }
    }

    var body: some View {
        BTTeachingTablePage(vm: vm, titleLabel: "打一走二想三", identifier: "planthree",
            velocity: velocity, planning: controls,
            usesStandardTitle: true,
            onPocketOrientationChange: { pocketOrientation = $0 },
            pairedLeftContent: vm.isBreakMode ? { AnyView(breakControls($0)) } : nil,
            title: { EmptyView() },
            leftContent: { size in leftControls(size) },
            status: { informationOverlay }, onPalettePlace: { vm.placeFromPalette($0, atWorld: $1) })
        .toolUsageSession(.planThree)
        .onChange(of: vm.armedRole) { _, role in
            if role != selectedRolePrompt { selectedRolePrompt = nil }
        }
        .onChange(of: vm.activeTool) { _, tool in
            if tool != .none { selectedRolePrompt = nil }
        }
        .sheet(isPresented: $showBreakPicker) {
            BreakGamePickerSheet { vm.startBreakFlow(game: $0) }
                .presentationDetents([.height(360)]).presentationDragIndicator(.visible)
        }
        .sheet(item: $informationPanel) { panel in
            PlanningInformationSheet(panel: panel, sections: informationSections(panel))
        }
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
        BTTablePlanningControls(spinX: spinX, spinY: spinY, transparency: $spinTransparency,
            hides3DAssists: Binding(get: { hides3DAssists }, set: { hides3DAssists = $0; vm.hides3DShotAssists = $0 }),
            velocityRange: vm.isBreakMode ? BreakFlowRunner.breakVelocityRange : ShotTuning.velocityRange,
            instrumentsEnabled: (!busy || vm.isAdjustingSolution) && (vm.isBreakMode || vm.hasSolutions), isAnimating: busy,
            paletteEnabled: !busy && !vm.isBreakMode,
            primaryTitle: vm.breakRunner.map { $0.showsConfirm ? "完成" : "开球" } ?? (vm.isComputing ? "计算中" : "打一"),
            primaryEnabled: vm.isBreakMode ? !busy : vm.canStrike,
            onPrimary: {
                if let runner = vm.breakRunner {
                    if runner.showsConfirm { runner.confirmSettled() } else { runner.breakNow() }
                } else { vm.play() }
            }, onPaletteTap: { key in
                if vm.onTableKeys.contains(key) { vm.pulseTableBall(key) } else { vm.placeFromPalette(key) }
            }, menuItems: menuItems, refreshTrajectory: { vm.redrawTrajectory() },
            onSetup: { vm.hides3DShotAssists = hides3DAssists; if let initialBoard { vm.loadBoard(initialBoard) }; applyUITestHooksIfNeeded() },
            onDisappear: { vm.stopForDismissal() },
            onAimNudged: vm.isBreakMode ? { vm.breakRunner?.nudgeAim(byDegrees: $0) } : nil,
            closeupSnapshot: vm.canStrike ? vm.solvedContactCloseup : nil,
            closeupUnavailableReason: vm.canStrike && vm.solvedContactCloseup != nil ? nil : "当前首碰暂无特写",
            onSpinChange: { x, y in
                if let runner = vm.breakRunner { runner.spinX = x; runner.spinY = y }
                else { vm.adjustCurrentSolution(spinX: x, spinY: y) }
            },
            overlay: { projector, frame in
                if !vm.isBreakMode && !busy && vm.activeTool != .none {
                    return AnyView(SolveConstraintDrawingOverlay(coordinateSpaceName: "planthree", sceneFrame: frame,
                        unproject: { projector.unproject?($0) }, onDrag: {
                            vm.toolDrag(startNormalized: $0, currentNormalized: $1, ended: $2)
                        }))
                }
                return AnyView(EmptyView())
            })
    }

    private func leftControls(_ size: CGSize) -> some View {
        ScrollView(.vertical) {
            VStack(spacing: 4) {
                if !vm.isBreakMode {
                    roleMenu
                    Menu {
                        Button("落区") { vm.activeTool = .region }
                        Button("落点") { vm.activeTool = .restPoint }
                        Button("过点") { vm.activeTool = .passPoint }
                        Button("摆球") { vm.activeTool = .none }
                    } label: {
                        Text(toolName).font(.btCaption).foregroundStyle(.white).frame(width: 44, height: 44)
                            .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                    }.overlay(alignment: .topTrailing) { TeachingMenuIndicator() }.disabled(busy)
                        .opacity(busy ? 0.4 : 1).accessibilityIdentifier("planthree.tool")
                    action("清除", "eraser", "planthree.clearConstraint", enabled: !busy && vm.hasConstraint) { vm.clearConstraint() }
                    action("求解", "function", "solver.solve", enabled: !busy && vm.canSolve) { vm.solve() }
                    TeachingSolutionButton(count: vm.solutions.count, currentIndex: vm.currentIndex,
                        enabled: !busy, next: { vm.nextSolution() }, select: { vm.selectSolution(at: $0) },
                        onDetails: { informationPanel = .details }, isModified: vm.isSolutionAdjusted)
                    action("重打", "arrow.uturn.backward", "planthree.undo", enabled: !busy && !vm.temporaryTopDownActive && vm.canUndoShot) { vm.undoLastShot() }
                    action("回放", "play.rectangle", "planthree.replay", enabled: !busy && !vm.temporaryTopDownActive && vm.canPlayback) { vm.replayLastShot() }
                }
            }.frame(maxWidth: .infinity)
        }.scrollIndicators(.hidden).frame(width: size.width, height: min(size.height, vm.isBreakMode ? 232 : 332))
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
            .init(id: "planthree.help", title: "操作说明", disabled: vm.isBreakMode, action: { informationPanel = .help }),
            .init(id: "planthree.plan", title: "计划"),
            .init(id: "planthree.clearPlan", title: "清空计划", disabled: busy || vm.isBreakMode,
                  action: { vm.clearPlan() })]
        if vm.isBreakMode {
            items.append(.init(id: "planthree.cancelBreak", title: "取消开球", disabled: busy, action: { vm.cancelBreakFlow() }))
        } else {
            items += [.init(id: "break.entry", title: "开球", disabled: busy, action: { showBreakPicker = true }),
                .init(id: "planthree.clear", title: "清空桌面", disabled: busy, action: { vm.clearTable() }),
                .init(id: "planthree.reset", title: "恢复默认球形", disabled: busy, action: { vm.resetAll() })]
        }
        return items
    }

    private func applyUITestHooksIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        for scenario in ["threeBallDimmed", "twoBallDimmed", "twoBall", "oneBall", "cleared"]
            where args.contains("-planThree.\(scenario)") {
            vm.uiTestConfigure(scenario)
            return
        }
    }
    private func roleTitle(_ role: PlanThreeRole) -> String {
        switch role { case .ball1: return "①球"; case .pocket1: return "第1杆目标袋"
        case .ball2: return "②球"; case .pocket2: return "第2杆目标袋"; case .ball3: return "③球" }
    }
    private func roleValue(_ role: PlanThreeRole) -> String {
        if role.isBall { return vm.ballKey(for: role).map { String($0.dropFirst()) + "号球" } ?? "未选择" }
        let pocket = vm.pocketIndex(for: role)
        return pocket >= 0 ? PocketDisplay.name(index: pocket, orientation: pocketOrientation) : "未选择"
    }
    private var roleSummary: String {
        PlanThreeRole.order.map { roleTitle($0) + ":" + roleValue($0) }.joined(separator: " · ")
    }
    private var roleMenu: some View {
        Menu {
            ForEach(PlanThreeRole.order, id: \.rawValue) { role in
                Button { vm.armRole(role); selectedRolePrompt = role } label: {
                    Label(roleTitle(role) + " · " + roleValue(role), systemImage: vm.armedRole == role ? "checkmark.circle.fill" : "circle")
                }.disabled(busy)
                    .accessibilityValue(roleValue(role)).accessibilityIdentifier("planthree.role.\(role.rawValue)")
            }
        } label: {
            VStack(spacing: 1) {
                Text(vm.armedRole?.isBall == false ? "目标袋" : "计划").font(.system(size: 10))
                Text(vm.armedRole.map { role in
                    switch role {
                    case .pocket1: return "第1杆"
                    case .pocket2: return "第2杆"
                    default: return roleTitle(role)
                    }
                } ?? "已选齐").font(.btCaption)
            }.foregroundStyle(.white).frame(width: 44, height: 44)
                .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        }.overlay(alignment: .topTrailing) { TeachingMenuIndicator() }.disabled(busy).accessibilityIdentifier("planthree.roles")
            .accessibilityLabel("计划，" + (vm.armedRole.map { roleTitle($0) } ?? "已选齐"))
            .accessibilityValue(roleSummary)
    }
    @ViewBuilder private var informationOverlay: some View {
        if let runner = vm.breakRunner {
            BTTeachingInformationLayer(items: [.init(text: runner.statusText(isPerspective: vm.cameraMode == .perspective3D))])
        } else {
            PlanningInformationOverlay(page: "planthree", event: vm.informationEvent, prompt: compactPrompt,
                solution: vm.currentSolution, defense: false, busy: busy,
                setupComplete: vm.hasSolutions, introduction: vm.sectorIsDefaultRegion ? "扇形为默认落区，也可用约束工具自定义。" : "在计划菜单设置目标球和目标袋，也可自定约束。")
        }
    }
    private var compactPrompt: String? {
        if !vm.onTableKeys.contains(PositionPlayBall.cueKey) { return "请摆上母球" }
        if vm.objectBallCount == 0 { return "清台完成" }
        if !vm.hasConstraint && vm.activeTool != .none {
            switch vm.activeTool {
            case .region: return "拖出落区"
            case .restPoint: return "点选落点"
            case .passPoint: return "点选过点"
            case .none: break
            }
        }
        guard !vm.canSolve || selectedRolePrompt != nil else { return nil }
        guard let role = selectedRolePrompt ?? vm.armedRole else { return "选择约束工具" }
        switch role {
        case .ball1: return "选择第1杆目标球"
        case .pocket1: return "选择第1杆目标袋"
        case .ball2: return "选择第2杆目标球"
        case .pocket2: return "选择第2杆目标袋"
        case .ball3: return "选择第3杆目标球"
        }
    }
    private func informationSections(_ panel: PlanningPanel) -> [(String, String)] {
        if panel == .details {
            return [("当前方案", PlanningSolutionDetails.text(vm.currentSolution, index: vm.currentIndex,
                count: vm.solutions.count, adjusted: vm.isSolutionAdjusted, defense: false))]
        }
        var sections: [(String, String)] = []
        if vm.informationEvent.kind == .failure { sections.append(("当前问题", vm.informationEvent.text)) }
        else if let prompt = compactPrompt { sections.append(("当前步骤", prompt)) }
        sections += [
            ("计划", "在“计划”菜单选择当前要设置的球或袋，再点桌面。①是本杆目标球，②是下一杆目标球，③用于决定扇形朝向。完整角色和值可随时在计划菜单查看。"),
            ("默认落区与自定义约束", "计划具备所需条件后，扇形作为默认落区。也可选择落区、落点或过点工具自定约束。落点的十字表示目标，圆环表示容差。台面球数较少时按实际可用计划求解，无需强行补齐五个角色。"),
            ("击球与重打", "①进袋后计划顺延；未进袋则保留原计划。重打恢复上一杆击打前的球形、角色、约束和方案。回放结束后显示击打后的局面。"),
            ("方案", "轻点方案按钮切换解；长按选择方案或查看详情。打点和杆速调整后显示“微调”。")
        ]
        return sections
    }
}
