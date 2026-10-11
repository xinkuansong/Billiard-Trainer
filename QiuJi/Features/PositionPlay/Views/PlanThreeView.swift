import SwiftUI
import SceneKit

/// Constraint solving keeps its own model and actions inside the shared daily table shell.
struct PlanThreeView: View {
    let initialBoard: BoardSnapshot?
    init(initialBoard: BoardSnapshot? = nil) { self.initialBoard = initialBoard }
    @StateObject private var vm = PlanThreeViewModel()
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
            information: informationItems, usesStandardTitle: true,
            pairedLeftContent: vm.isBreakMode ? { AnyView(breakControls($0)) } : nil,
            title: { EmptyView() },
            leftContent: { size in leftControls(size) },
            status: { EmptyView() }, onPalettePlace: { vm.placeFromPalette($0, atWorld: $1) })
        .toolUsageSession(.planThree)
        .sheet(isPresented: $showBreakPicker) {
            BreakGamePickerSheet { vm.startBreakFlow(game: $0) }
                .presentationDetents([.height(360)]).presentationDragIndicator(.visible)
        }
    }

    private var informationItems: [BTTeachingInformation] {
        var items: [BTTeachingInformation] = [.init(
            text: vm.breakRunner?.statusText(isPerspective: vm.cameraMode == .perspective3D) ?? vm.statusText,
            symbol: !vm.isBreakMode && vm.objectBallCount == 0 ? "checkmark.circle" : nil, identifier: "planthree.status")]
        if !vm.isBreakMode && vm.objectBallCount > 0 {
            items.append(.init(text: roleSummary, kind: .readout, identifier: "planthree.rolesSummary",
                expandedText: PlanThreeRole.order.map { roleTitle($0) + ":" + roleValue($0) }.joined(separator: "\n")))
        }
        return items
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
            instrumentsEnabled: !busy && (vm.isBreakMode || vm.hasSolutions), isAnimating: busy,
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
                        enabled: !busy, next: { vm.nextSolution() }, select: { vm.selectSolution(at: $0) })
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
    }
    private var menuItems: [DailyHUDMenuItem] {
        var items: [DailyHUDMenuItem] = [
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
        switch role { case .ball1: return "①球"; case .pocket1: return "①袋"
        case .ball2: return "②球"; case .pocket2: return "②袋"; case .ball3: return "③球" }
    }
    private func roleValue(_ role: PlanThreeRole) -> String {
        if role.isBall { return vm.ballKey(for: role).map { String($0.dropFirst()) + "号球" } ?? "未选择" }
        let pocket = vm.pocketIndex(for: role)
        return pocket >= 0 ? "袋\(pocket + 1)" : "未选择"
    }
    private var roleSummary: String {
        PlanThreeRole.order.map { roleTitle($0) + ":" + roleValue($0) }.joined(separator: " · ")
    }
    private var roleMenu: some View {
        Menu {
            ForEach(PlanThreeRole.order, id: \.rawValue) { role in
                Button { vm.armRole(role) } label: {
                    Label(roleTitle(role) + " · " + roleValue(role), systemImage: vm.armedRole == role ? "checkmark.circle.fill" : "circle")
                }.disabled(busy)
                    .accessibilityValue(roleValue(role)).accessibilityIdentifier("planthree.role.\(role.rawValue)")
            }
        } label: {
            VStack(spacing: 1) {
                Text("计划").font(.system(size: 10))
                Text(vm.armedRole.map { roleTitle($0) } ?? "已选齐").font(.btCaption)
            }.foregroundStyle(.white).frame(width: 44, height: 44)
                .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        }.overlay(alignment: .topTrailing) { TeachingMenuIndicator() }.disabled(busy).accessibilityIdentifier("planthree.roles")
            .accessibilityValue(roleSummary)
    }
}
