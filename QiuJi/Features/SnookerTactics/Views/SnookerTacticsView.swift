import SwiftUI
import SceneKit

/// Defense retains its legal target and coverage solver inside the shared table shell.
struct SnookerTacticsView: View {
    let initialBoard: BoardSnapshot?
    init(initialBoard: BoardSnapshot? = nil) { self.initialBoard = initialBoard }
    @StateObject private var vm = SnookerTacticsViewModel()
    @AppStorage("snooker.spinTransparency") private var spinTransparency = 0.5
    @AppStorage("snooker.hides3DAssists") private var hides3DAssists = false
    private var busy: Bool { vm.isPlaying || vm.isComputing }

    var body: some View {
        BTTeachingTablePage(vm: vm, titleLabel: "防守", identifier: "snooker", velocity: velocity,
            planning: controls,
            information: [.init(text: vm.statusText, identifier: "snooker.status")], usesStandardTitle: true,
            title: { EmptyView() },
            leftContent: { size in leftControls(size) },
            status: { EmptyView() }, onPalettePlace: { vm.placeFromPalette($0, atWorld: $1) })
    }
    private var velocity: Binding<Double> {
        Binding(get: { vm.velocity }, set: { vm.adjustCurrentSolution(velocity: $0) })
    }
    private var controls: BTTablePlanningControls {
        BTTablePlanningControls(
            spinX: Binding(get: { vm.spinX }, set: { vm.adjustCurrentSolution(spinX: $0) }),
            spinY: Binding(get: { vm.spinY }, set: { vm.adjustCurrentSolution(spinY: $0) }),
            transparency: $spinTransparency,
            hides3DAssists: Binding(get: { hides3DAssists }, set: { hides3DAssists = $0; vm.hides3DShotAssists = $0 }),
            velocityRange: ShotTuning.velocityRange, instrumentsEnabled: !busy && vm.hasSolutions,
            isAnimating: busy, paletteEnabled: !busy, allowsPocketSelection: false,
            primaryTitle: vm.isComputing ? "计算中" : "击球", primaryEnabled: vm.canStrike,
            onPrimary: { vm.play() }, onPaletteTap: { key in
                if vm.onTableKeys.contains(key) { vm.pulseTableBall(key) } else { vm.placeFromPalette(key) }
            }, menuItems: [
                .init(id: "snooker.board", title: "球形"),
                .init(id: "snooker.clear", title: "清空桌面", disabled: busy, action: { vm.clearTable() }),
                .init(id: "snooker.reset", title: "恢复默认球形", disabled: busy, action: { vm.resetAll() })
            ], refreshTrajectory: { vm.redrawTrajectory() }, onSetup: {
                vm.hides3DShotAssists = hides3DAssists
                if let initialBoard { vm.loadBoard(initialBoard) }
                for scenario in ["full", "partial", "none"] where ProcessInfo.processInfo.arguments.contains("-snooker.\(scenario)") {
                    vm.uiTestConfigure(scenario); break
                }
            }, onDisappear: { vm.stopForDismissal() })
    }
    private func leftControls(_ size: CGSize) -> some View {
        ScrollView(.vertical) {
            VStack(spacing: 4) {
                Menu {
                    Button("目标球") { vm.activeTool = .selectTarget }
                    Button("摆球") { vm.activeTool = .none }
                } label: {
                    Text(vm.activeTool == .selectTarget ? "目标球" : "摆球").font(.btCaption).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                }.overlay(alignment: .topTrailing) { TeachingMenuIndicator() }.disabled(busy)
                    .opacity(busy ? 0.4 : 1).accessibilityIdentifier("snooker.tool")
                action("清除", "eraser", "snooker.clearSelection", enabled: !busy && vm.selectedTargetKey != nil) { vm.clearSelection() }
                action("求解", "function", "solver.solve", enabled: !busy && vm.canSolve) { vm.solve() }
                TeachingSolutionButton(count: vm.solutions.count, currentIndex: vm.currentIndex,
                        enabled: !busy, next: { vm.nextSolution() }, select: { vm.selectSolution(at: $0) })
                action("重打", "arrow.uturn.backward", "snooker.undo", enabled: !busy && !vm.temporaryTopDownActive && vm.canUndoShot) { vm.undoLastShot() }
                action("回放", "play.rectangle", "snooker.replay", enabled: !busy && !vm.temporaryTopDownActive && vm.canPlayback) { vm.replayLastShot() }
            }.frame(maxWidth: .infinity)
        }.scrollIndicators(.hidden).frame(width: size.width, height: min(size.height, 284))
    }
    private func action(_ title: String, _ icon: String, _ id: String, enabled: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 1) { Image(systemName: icon).font(.system(size: 17)); Text(title).font(.system(size: 10)) }
                .frame(width: 44, height: 44).background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        }.buttonStyle(BTHUDPressStyle()).disabled(!enabled).opacity(enabled ? 1 : 0.4).accessibilityLabel(title).accessibilityIdentifier(id)
    }
}
