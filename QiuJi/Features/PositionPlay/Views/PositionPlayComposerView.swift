import SwiftUI
import SceneKit

/// Business hooks for an editable PositionPlay board; rendering and controls remain in the core page.
struct PositionPlayEditorConfiguration {
    var title: String
    var isTryout: Bool
    var setup: () -> Void
    var onInteraction: () -> Void
    var onRearrange: () -> Void
    var aimItems: [DailyHUDMenuItem]?
    var menuItems: [DailyHUDMenuItem]
    var overlay: AnyView
}

/// Free layout / drill tryout retain their board and sequence semantics inside the daily table shell.
struct PositionPlayComposerView: View {
    let initialBoard: BoardSnapshot?
    let initialMode: PositionPlayViewModel.AimMode?
    let sourceDrill: DrillContent?
    let tryoutFormation: DrillTryoutFormation?

    init(initialBoard: BoardSnapshot? = nil,
         initialMode: PositionPlayViewModel.AimMode? = nil,
         sourceDrill: DrillContent? = nil,
         tryoutFormation: DrillTryoutFormation? = nil) {
        self.initialBoard = initialBoard
        self.initialMode = initialMode
        self.sourceDrill = sourceDrill
        self.tryoutFormation = tryoutFormation
    }

    @StateObject private var vm = PositionPlayViewModel()
    @State private var tryoutBoard: BoardSnapshot?
    @State private var showBrief = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showClearTableConfirm = false
    @State private var showResetConfirm = false
    @AppStorage("drillTryout.hasSeenGestureHint") private var hasSeenGestureHint = false
    private var isTryout: Bool { sourceDrill != nil }

    var body: some View {
        FreePlayView(editorModel: vm, editor: .init(
            title: navTitleText, isTryout: isTryout, setup: setupBoard,
            onInteraction: dismissBriefOnInteraction, onRearrange: rearrange,
            aimItems: tryoutAimItems, menuItems: editorMenuItems, overlay: AnyView(briefOverlay)))
        .alert("命名走位序列", isPresented: $showRename) {
            TextField("名称", text: $renameText)
            Button("保存") { vm.renameSequence(renameText) }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog(vm.isRecording ? "清空桌面将丢弃录制中的 \(vm.stepCount) 杆。" : "清空桌面上所有球？",
                            isPresented: $showClearTableConfirm, titleVisibility: .visible) {
            Button("取消", role: .cancel) {}
            Button("清空桌面", role: .destructive) { vm.clearTable(); vm.placeFromPalette(PositionPlayBall.cueKey) }
        }
        .confirmationDialog(vm.isRecording ? "清空并重来将丢弃录制中的 \(vm.stepCount) 杆。" : "回到默认球形并重新开始？",
                            isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("取消", role: .cancel) {}
            Button("清空并重来", role: .destructive) { vm.resetAll() }
        }
        .toolUsageSession(isTryout ? .drillTryout : .freePosition)
    }

    private var navTitleText: String {
        if let sourceDrill { return sourceDrill.nameZh }
        return vm.sequence.name == "未命名走位" ? "自由走位" : vm.sequence.name
    }

    private func setupBoard() {
        if let sourceDrill {
            if let board = tryoutFormation?.initial ?? DrillBoardBuilder.board(for: sourceDrill) {
                tryoutBoard = board
                vm.loadBoard(board)
            }
            if let steps = tryoutFormation?.steps, !steps.isEmpty {
                vm.configureSequence(steps)
                vm.enterSequenceMode()
            } else { vm.setPreferredAimMode(initialMode ?? .free) }
            withAnimation(.easeInOut(duration: 0.35).delay(0.6)) { showBrief = true }
        } else {
            if let initialBoard { vm.loadBoard(initialBoard) }
            if let initialMode { vm.setPreferredAimMode(initialMode) }
        }
    }

    private func dismissBriefOnInteraction() {
        if isTryout, !hasSeenGestureHint { hasSeenGestureHint = true }
        if showBrief { withAnimation(BTMotion.easeChrome) { showBrief = false } }
    }

    private func rearrange() {
        dismissBriefOnInteraction()
        if vm.isSequenceMode { vm.restartSequence() }
        else if let tryoutBoard { vm.loadBoard(tryoutBoard) }
    }

    @ViewBuilder private var briefOverlay: some View {
        if showBrief, let sourceDrill {
            DrillTryoutBriefCard(drill: sourceDrill, formation: tryoutFormation,
                footnote: hasSeenGestureHint ? nil : "拖球摆位 · 设置中切换模式 · 点主按钮试打",
                onClose: dismissBriefOnInteraction)
                .frame(maxWidth: 460)
                .padding(.horizontal, 8)
        }
    }

    private var editorMenuItems: [DailyHUDMenuItem] {
        if isTryout {
            return [.init(id: "tryout.info", title: "试打说明", action: { showBrief.toggle() })]
        }
        let busy = vm.isPlaying || vm.isBreakMode
        return [
            .init(id: "composer.rename", title: "重命名", disabled: busy, action: {
                renameText = vm.sequence.name; showRename = true
            }),
            .init(id: "composer.clear", title: "清空桌面", disabled: busy, action: { showClearTableConfirm = true }),
            .init(id: "composer.reset", title: "清空并重来", disabled: busy, action: { showResetConfirm = true })
        ]
    }

    private enum TryoutMode: String, CaseIterable { case sequence = "序列", pocket = "进袋", free = "自由" }
    private var currentTryoutMode: TryoutMode { vm.isSequenceMode ? .sequence : (vm.aimMode == .free ? .free : .pocket) }
    private var tryoutAimItems: [DailyHUDMenuItem]? {
        guard isTryout, vm.hasSequence else { return nil }
        return TryoutMode.allCases.map { mode in
            .init(id: "tryoutMode_\(mode.rawValue)", title: mode.rawValue, selected: currentTryoutMode == mode,
                  disabled: vm.isPlaying || vm.isSequencePlaying, action: { selectTryoutMode(mode) })
        }
    }
    private func selectTryoutMode(_ mode: TryoutMode) {
        guard !vm.isPlaying, !vm.isSequencePlaying, mode != currentTryoutMode else { return }
        dismissBriefOnInteraction()
        switch mode {
        case .sequence: vm.enterSequenceMode()
        case .pocket, .free:
            vm.exitSequenceMode()
            if let tryoutBoard { vm.loadBoard(tryoutBoard) }
            vm.setPreferredAimMode(mode == .free ? .free : .pocket)
        }
    }
}

#Preview("Dark") {
    NavigationStack { PositionPlayComposerView() }.preferredColorScheme(.dark)
}
