import SwiftUI
import SceneKit

/// Business hooks for an editable PositionPlay board; rendering and controls remain in the core page.
struct PositionPlayEditorConfiguration {
    var title: String
    var isTryout: Bool
    var loadsDefaultLayout: Bool = true
    var allowsSeparationAssist: Bool = true
    var setup: () -> Void
    var onInteraction: () -> Void
    var onRearrange: () -> Void
    var modeItem: DailyHUDMenuItem?
    var aimItems: [DailyHUDMenuItem]?
    var menuItems: [DailyHUDMenuItem]
    var overlay: AnyView
    var layoutEditingBlocked: Bool = false
    var formation: CustomFormationSession? = nil
    var onBack: (() -> Void)? = nil
}

/// Free layout / drill tryout retain their board and sequence semantics inside the daily table shell.
struct PositionPlayComposerView: View {
    let initialBoard: BoardSnapshot?
    let initialMode: PositionPlayViewModel.AimMode?
    let sourceDrill: DrillContent?
    let tryoutFormation: DrillTryoutFormation?
    var onBack: (() -> Void)?

    init(initialBoard: BoardSnapshot? = nil,
         initialMode: PositionPlayViewModel.AimMode? = nil,
         sourceDrill: DrillContent? = nil,
         tryoutFormation: DrillTryoutFormation? = nil,
         onBack: (() -> Void)? = nil) {
        self.initialBoard = initialBoard
        self.initialMode = initialMode
        self.sourceDrill = sourceDrill
        self.tryoutFormation = tryoutFormation
        self.onBack = onBack
    }

    @StateObject private var vm = PositionPlayViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var tryoutBoard: BoardSnapshot?
    @State private var tryoutAimPreference: PositionPlayViewModel.AimMode = .pocket
    @State private var showBrief = false
    @State private var showClearTableConfirm = false
    @AppStorage("drillTryout.hasSeenGestureHint") private var hasSeenGestureHint = false
    private var isTryout: Bool { sourceDrill != nil }
    private var openingBoard: BoardSnapshot? {
        if let sourceDrill { return tryoutFormation?.initial ?? DrillBoardBuilder.board(for: sourceDrill) }
        return initialBoard ?? Self.defaultBoard
    }

    var body: some View {
        FreePlayView(editorModel: vm, editor: .init(
            title: navTitleText, isTryout: isTryout, loadsDefaultLayout: openingBoard?.onTable.isEmpty != false,
            allowsSeparationAssist: isTryout, setup: setupBoard,
            onInteraction: dismissBriefOnInteraction, onRearrange: rearrange,
            modeItem: tryoutModeItem, aimItems: tryoutAimItems, menuItems: editorMenuItems, overlay: AnyView(briefOverlay),
            layoutEditingBlocked: showClearTableConfirm, onBack: { if let onBack { onBack() } else { dismiss() } }))
        .confirmationDialog(vm.isRecording ? "清空桌面将丢弃录制中的 \(vm.stepCount) 杆。" : "清空桌面上所有球？",
                            isPresented: $showClearTableConfirm, titleVisibility: .visible) {
            Button("取消", role: .cancel) {}
            Button("清空桌面", role: .destructive) { vm.clearTable(); vm.placeFromPalette(PositionPlayBall.cueKey) }
        }
        .toolUsageSession(isTryout ? .drillTryout : .freePosition)
    }

    /// Requested landscape layout: cue below center, 1 at upper right, 8 at lower left.
    /// Normalized by inner table length; Y grows toward the lower long cushion.
    static let defaultBoard = BoardSnapshot(onTable: [
        PositionPlayBall.cueKey: CanvasPoint(x: 0.62, y: 0.395),
        "_1": CanvasPoint(x: 0.86, y: 0.187),
        "_8": CanvasPoint(x: 0.285, y: 0.367)
    ])

    private var navTitleText: String {
        if let sourceDrill { return sourceDrill.nameZh }
        return "分离角与走位"
    }

    private func setupBoard() {
        if let sourceDrill {
            vm.isGuidedTryout = true
            if let board = tryoutFormation?.initial ?? DrillBoardBuilder.board(for: sourceDrill) {
                tryoutBoard = board
                vm.loadBoard(board)
            }
            if let steps = tryoutFormation?.steps, !steps.isEmpty {
                tryoutAimPreference = steps.first?.shot.isFree == true ? .free : .pocket
                vm.configureSequence(steps)
                vm.enterSequenceMode()
            } else { vm.setPreferredAimMode(initialMode ?? .free) }
            withAnimation(.easeInOut(duration: 0.35).delay(0.6)) { showBrief = true }
        } else {
            if let openingBoard { vm.loadBoard(openingBoard) }
            vm.setPreferredAimMode(initialMode ?? .pocket)
            if initialBoard == nil {
                _ = vm.selectTarget(key: "_1")
                vm.selectPocket(at: 1)
            }
        }
    }

    private func dismissBriefOnInteraction() {
        if isTryout, !hasSeenGestureHint { hasSeenGestureHint = true }
        if showBrief { withAnimation(BTMotion.easeChrome) { showBrief = false } }
    }

    private func rearrange() {
        dismissBriefOnInteraction()
        if vm.isSequenceMode { vm.restartSequence() }
        else if vm.hasSequence { vm.enterTryoutFreeMode(aimMode: vm.preferredAimMode) }
        else if let tryoutBoard { vm.loadBoard(tryoutBoard) }
    }

    @ViewBuilder private var briefOverlay: some View {
        if showBrief, let sourceDrill {
            DrillTryoutBriefCard(drill: sourceDrill, formation: currentTryoutFormation,
                footnote: hasSeenGestureHint ? nil : "拖球摆位 · 设置中切换模式 · 点主按钮试打",
                onClose: dismissBriefOnInteraction)
                .frame(maxWidth: 460)
                .padding(.horizontal, 8)
        }
    }

    private var editorMenuItems: [DailyHUDMenuItem] {
        if isTryout {
            return [.init(id: "tryout.info", title: "试打说明", disclosure: true, action: { showBrief.toggle() })]
        }
        let busy = vm.isPlaying || vm.isBreakMode
        return [.init(id: "composer.clear", title: "清空桌面", disabled: busy, action: { showClearTableConfirm = true })]
    }

    private var currentTryoutFormation: DrillTryoutFormation? {
        guard let formation = tryoutFormation,
              formation.steps.indices.contains(vm.sequenceStepIndex) else { return tryoutFormation }
        let step = formation.steps[vm.sequenceStepIndex]
        return DrillTryoutFormation(token: formation.token, title: formation.title,
            fileName: formation.fileName, initial: step.before, stepCount: formation.stepCount,
            firstShot: step.shot, steps: formation.steps, displayName: formation.displayName)
    }

    private var tryoutModeItem: DailyHUDMenuItem? {
        guard isTryout else { return nil }
        return .init(id: "tryout.mode", title: "击球模式", detail: vm.isSequenceMode ? "序列" : "自由",
                     segments: ["序列", "自由"], disabled: !vm.hasSequence || vm.isPlaying || vm.isSequencePlaying,
                     action: {
            dismissBriefOnInteraction()
            if vm.isSequenceMode {
                vm.enterTryoutFreeMode(aimMode: tryoutAimPreference)
            } else {
                tryoutAimPreference = vm.preferredAimMode
                vm.enterSequenceMode()
            }
        })
    }

    private var tryoutAimItems: [DailyHUDMenuItem]? {
        guard isTryout else { return nil }
        return [("进袋", PositionPlayViewModel.AimMode.pocket), ("自由", .free)].map { title, mode in
            .init(id: "tryoutAim_\(title)", title: title, selected: vm.preferredAimMode == mode,
                  disabled: vm.isSequenceMode || vm.isPlaying || vm.isSequencePlaying, action: {
                tryoutAimPreference = mode
                vm.setPreferredAimMode(mode)
            })
        }
    }

}

#Preview("Dark") {
    NavigationStack { PositionPlayComposerView() }.preferredColorScheme(.dark)
}
