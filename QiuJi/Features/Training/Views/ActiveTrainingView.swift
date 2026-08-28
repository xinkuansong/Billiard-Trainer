import SwiftUI
import SwiftData

struct ActiveTrainingView: View {
    @StateObject var viewModel: ActiveTrainingViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var showShareView = false
    /// F-AT-04: brief shrink-toward-floating-pill transition when minimizing.
    @State private var isMinimizing = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                Color.btBG.ignoresSafeArea()

                switch viewModel.trainingPhase {
                case .active:
                    activePhaseContent
                case .note:
                    TrainingNoteView(
                        note: $viewModel.trainingNote,
                        onSkip: { viewModel.skipNote() },
                        onComplete: { viewModel.submitNote() }
                    )
                case .summary:
                    TrainingSummaryView(
                        elapsedSeconds: viewModel.elapsedSeconds,
                        drillCount: viewModel.drills.count,
                        totalSets: viewModel.totalSets,
                        totalBallsMade: viewModel.totalBallsMade,
                        overallSuccessRate: viewModel.overallSuccessRate,
                        drillSummaries: viewModel.drillSummaries,
                        trainingNote: viewModel.trainingNote,
                        onSave: {
                            // F-TS-02: Summary owns success toast + dismiss; return persistence result.
                            viewModel.saveTraining(context: modelContext)
                            return viewModel.didSaveSuccessfully
                        },
                        onGenerateShareImage: {
                            // Summary persists first (DR-079); this only presents the card.
                            showShareView = true
                        },
                        onViewHistory: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                router.switchTab(.history)
                            }
                        }
                    )
                }

                if viewModel.shouldShowRestOverlay {
                    // F-CL-04: keep W2-6 rest overlay chrome (dual rings, end state,
                    // numericText, card shell). Shared `BTRestTimer` lacks those;
                    // swapping would regress W2-6 — document instead of hard-replace.
                    restCountdownOverlay
                        .transition(.opacity)
                }

                if viewModel.showsMinimizedRestChip {
                    minimizedRestChip
                        .transition(.scale.combined(with: .opacity))
                }
            }
            // F-AT-04: shrink toward the bottom-trailing floating pill when minimizing.
            .scaleEffect(isMinimizing ? 0.92 : 1, anchor: .bottomTrailing)
            .opacity(isMinimizing ? 0.5 : 1)
            .animation(BTMotion.springPanel, value: viewModel.trainingPhase)
            .animation(BTMotion.springPanel, value: viewModel.isRestTimerActive)
            .animation(BTMotion.springPanel, value: viewModel.isRestOverlayMinimized)
            .navigationTitle(phaseTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(
                viewModel.trainingPhase == .active && !viewModel.drills.isEmpty && !viewModel.isLoading
                    ? .hidden : .visible,
                for: .navigationBar
            )
            .toolbar {
                if viewModel.trainingPhase == .active {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("结束") {
                            if viewModel.elapsedSeconds > 0 || !viewModel.drills.isEmpty {
                                viewModel.showEndConfirm = true
                            } else {
                                dismiss()
                            }
                        }
                        .foregroundStyle(.btDestructive)
                    }

                    if !viewModel.isPlanMode {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                viewModel.showDrillPicker = true
                            } label: {
                                Label("添加", systemImage: "plus")
                            }
                        }
                    }
                }

                if viewModel.trainingPhase == .note {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            viewModel.resumeTraining()
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: BTIcon.chevronLeft)
                                    .fontWeight(.semibold)
                                Text("返回")
                            }
                        }
                    }
                }
            }
            .alert("结束训练？", isPresented: $viewModel.showEndConfirm) {
                Button("继续训练", role: .cancel) {}
                Button("结束", role: .destructive) {
                    viewModel.endTraining()
                }
            } message: {
                Text("结束后可以记录本次训练心得。")
            }
            .sheet(isPresented: $viewModel.showDrillPicker) {
                DrillPickerSheet(
                    initiallySelectedIds: Set(viewModel.drills.map(\.drillId)),
                    onSelect: { viewModel.addDrill($0) },
                    onDeselect: { viewModel.removeDrill(drillId: $0.id) }
                )
            }
            .alert("保存失败", isPresented: Binding(
                get: { viewModel.saveError != nil },
                set: { if !$0 { viewModel.saveError = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                if let error = viewModel.saveError {
                    Text(error)
                }
            }
            .sheet(isPresented: $showShareView) {
                TrainingShareView(session: buildShareSession())
            }
        }
        .interactiveDismissDisabled()
        .onChange(of: viewModel.isRestTimerActive) { _, isActive in
            UIApplication.shared.isIdleTimerDisabled = isActive
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshTimers()
            }
        }
        .task {
            await viewModel.loadDrills()
            if viewModel.isPlanMode && !viewModel.drills.isEmpty {
                viewModel.startTimer()
            }
        }
        .onDisappear {
            if !router.isTrainingMinimized {
                viewModel.cleanup()
            }
        }
    }

    private var phaseTitle: String {
        switch viewModel.trainingPhase {
        case .active:
            return viewModel.isPlanMode ? "按计划训练" : "自由记录"
        case .note:
            return "训练心得"
        case .summary:
            return "训练总结"
        }
    }

    private func buildShareSession() -> TrainingSessionSummary {
        let planName: String
        if case .plan = viewModel.mode {
            planName = "训练记录"
        } else {
            planName = "自由训练"
        }
        return TrainingSessionSummary(
            date: Date(),
            planName: planName,
            durationMinutes: viewModel.elapsedSeconds / 60,
            completedDrills: viewModel.drills.count,
            totalSets: viewModel.totalSets,
            overallSuccessRate: viewModel.overallSuccessRate,
            drills: viewModel.drillSummaries.map {
                .init(
                    name: $0.nameZh,
                    setsCount: $0.sets.count,
                    madeBalls: $0.totalBallsMade,
                    targetBalls: $0.totalBallsPossible,
                    drillId: $0.drillId,
                    sets: $0.sets.map { set in
                        .init(id: set.id, madeBalls: set.madeBalls, targetBalls: set.targetBalls)
                    }
                )
            },
            note: viewModel.trainingNote
        )
    }

    // MARK: - Active Phase Content

    private var activePhaseContent: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.drills.isEmpty {
                emptyState
            } else if viewModel.showingOverview {
                overviewContent
            } else {
                drillRecordContent
            }
        }
    }

    // MARK: - Overview Content

    private var overviewContent: some View {
        VStack(spacing: 0) {
            frostedTopBar

            ScrollView {
                VStack(spacing: Spacing.md) {
                    ForEach(Array(viewModel.drills.enumerated()), id: \.element.id) { index, drill in
                        let sets = index < viewModel.drillSetsData.count ? viewModel.drillSetsData[index] : []
                        BTExerciseRow(
                            drillName: drill.nameZh,
                            drillId: drill.drillId,
                            totalSets: sets.count,
                            completedSets: sets.filter(\.isCompleted).count,
                            madeBalls: sets.reduce(0) { $0 + $1.madeBalls },
                            targetBalls: sets.reduce(0) { $0 + $1.targetBalls },
                            onTap: {
                                viewModel.currentDrillIndex = index
                                withAnimation(BTMotion.springPanel) {
                                    viewModel.showingOverview = false
                                }
                            }
                        )
                    }
                    .padding(.horizontal, Spacing.lg)
                }
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxxl)
            }

            bottomToolbar
        }
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(spacing: Spacing.md) {
            if viewModel.isTimerSkipped {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: BTIcon.clockPause)
                        .foregroundStyle(.btTextTertiary)
                    Text("已跳过计时")
                        .font(.btSubheadline)
                        .foregroundStyle(.btTextTertiary)

                    Button("恢复") {
                        viewModel.unskipTimer()
                    }
                    .font(.btCaption)
                    .foregroundStyle(.btPrimary)
                }
                .padding(.vertical, Spacing.md)
            } else {
                Text(viewModel.formattedTime)
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundStyle(.btText)
                    .contentTransition(.numericText())
                    .animation(.default, value: viewModel.elapsedSeconds)

                HStack(spacing: Spacing.xxl) {
                    Button {
                        viewModel.toggleTimer()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: viewModel.isTimerRunning ? "pause.fill" : "play.fill")
                                .font(.btFootnote14)
                            Text(viewModel.isTimerRunning ? "暂停" : "继续")
                                .font(.btSubheadlineMedium)
                        }
                        .foregroundStyle(.btPrimary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.btPrimary.opacity(0.1))
                        .clipShape(Capsule())
                    }

                    Button {
                        viewModel.skipTimer()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: BTIcon.forward)
                                .font(.btCaption)
                            Text("跳过计时")
                                .font(.btSubheadlineMedium)
                        }
                        .foregroundStyle(.btTextSecondary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(.btBGTertiary)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Frosted Top Bar

    private var frostedTopBar: some View {
        VStack(spacing: 0) {
            HStack {
                if viewModel.isTimerSkipped {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: BTIcon.clockPause)
                            .foregroundStyle(.btTextTertiary)
                        Text("已跳过计时")
                            .font(.btSubheadline)
                            .foregroundStyle(.btTextTertiary)
                        Button("恢复") { viewModel.unskipTimer() }
                            .font(.btCaption)
                            .foregroundStyle(.btPrimary)
                    }
                } else {
                    Text(viewModel.formattedTime)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.btPrimary)
                        .contentTransition(.numericText())
                        .animation(.default, value: viewModel.elapsedSeconds)
                }

                Spacer()

                HStack(spacing: Spacing.md) {
                    Button { viewModel.toggleTimer() } label: {
                        Image(systemName: viewModel.isTimerRunning ? "pause.circle" : "play.circle")
                            .font(.btTitle2)
                            .foregroundStyle(.btTextSecondary)
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(viewModel.isTimerRunning ? "暂停计时" : "继续计时")

                    if viewModel.isRestTimerActive {
                        Button {
                            if viewModel.isRestOverlayMinimized {
                                viewModel.expandRestOverlay()
                            } else {
                                viewModel.skipRestTimer()
                            }
                        } label: {
                            Text("\(viewModel.restSecondsRemaining)s")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(.btAccent)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(
                            viewModel.isRestOverlayMinimized
                                ? "展开组间休息 \(viewModel.restSecondsRemaining)秒"
                                : "跳过休息 \(viewModel.restSecondsRemaining)秒"
                        )
                    } else {
                        Button { viewModel.startRestTimer() } label: {
                            Image(systemName: BTIcon.timer)
                                .font(.btHeadline)
                                .foregroundStyle(.btTextSecondary)
                        }
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("休息设置")
                    }

                    Menu {
                        Button { viewModel.showEndConfirm = true } label: {
                            Label("结束训练", systemImage: BTIcon.stopCircle)
                        }
                        if !viewModel.isTimerSkipped {
                            Button { viewModel.skipTimer() } label: {
                                Label("跳过计时", systemImage: BTIcon.forward)
                            }
                        } else {
                            Button { viewModel.unskipTimer() } label: {
                                Label("恢复计时", systemImage: "clock")
                            }
                        }
                    } label: {
                        Image(systemName: BTIcon.menu)
                            .font(.btHeadline)
                            .foregroundStyle(.btTextSecondary)
                    }
                    .buttonStyle(BTPressableStyle.row)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("更多选项")

                    // F-AT-05: brand green = primary action, not "end"; use stop + secondary tint
                    Button { viewModel.showEndConfirm = true } label: {
                        Image(systemName: BTIcon.stopCircle)
                            .font(.btTitle)
                            .foregroundStyle(.btTextSecondary)
                    }
                    .buttonStyle(BTPressableStyle.row)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("结束训练")
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(viewModel.isPlanMode ? "按计划训练" : "自由记录")
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                    // R12：三级进度优先；会话级组进度作次行。
                    if !viewModel.currentSetProgressText.isEmpty {
                        Text(viewModel.currentSetProgressText)
                            .font(.btSubheadlineMedium)
                            .foregroundStyle(.btPrimary)
                            .monospacedDigit()
                            .accessibilityIdentifier("activeTrainingSetProgress")
                            .accessibilityLabel(viewModel.currentSetProgressText)
                    }
                    if !viewModel.progressText.isEmpty {
                        Text(viewModel.progressText)
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                    }
                }
                Spacer()
                // F-AT-10: weak page position (does not change TabView binding)
                if viewModel.drills.count > 1 {
                    Text("\(viewModel.currentDrillIndex + 1) / \(viewModel.drills.count)")
                        .font(.btCaption2)
                        .foregroundStyle(.btTextTertiary)
                        .monospacedDigit()
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.btBGTertiary.opacity(0.7))
                        .clipShape(Capsule())
                        .accessibilityLabel("第 \(viewModel.currentDrillIndex + 1) 项，共 \(viewModel.drills.count) 项")
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Drill Record Content

    private var drillRecordContent: some View {
        VStack(spacing: 0) {
            frostedTopBar

            TabView(selection: $viewModel.currentDrillIndex) {
                ForEach(Array(viewModel.drills.enumerated()), id: \.element.id) { index, drill in
                    DrillRecordView(
                        drill: drill,
                        setsData: viewModel.setsBinding(for: index),
                        note: viewModel.noteBinding(for: index),
                        onAddSet: { viewModel.addSet(drillIndex: index) },
                        onCompleteSet: { setIndex in viewModel.completeSet(drillIndex: index, setIndex: setIndex) },
                        onDeleteSet: { setIndex in viewModel.deleteSet(drillIndex: index, setIndex: setIndex) },
                        restDuration: $viewModel.restDuration,
                        formationOptions: viewModel.formationOptions(at: index),
                        addSetChoices: viewModel.addSetChoices(at: index),
                        onAddSetChoice: { choice, shotIndex in
                            viewModel.addSet(drillIndex: index, choice: choice, shotIndex: shotIndex)
                        }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)

            bottomToolbar
        }
    }

    private func phaseIcon(_ type: String) -> String {
        switch type {
        case "warmup":   return "flame"
        case "focused":  return "target"
        case "combined": return "square.grid.3x3"
        case "review":   return "pencil.and.list.clipboard"
        default:         return "circle.fill"
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            // F-AT-12 / F-AT-04: BTIcon.minus + spring handoff into minimized chrome
            toolbarItem(icon: BTIcon.minus, label: "最小化") {
                minimizeActiveTraining()
            }
            .accessibilityLabel("最小化训练")

            Spacer()

            Menu {
                Button { viewModel.showEndConfirm = true } label: {
                    Label("结束训练", systemImage: BTIcon.stopCircle)
                }
                if !viewModel.isTimerSkipped {
                    Button { viewModel.skipTimer() } label: {
                        Label("跳过计时", systemImage: BTIcon.forward)
                    }
                }
            } label: {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: BTIcon.menu)
                        .font(.btTitle2)
                        .foregroundStyle(.btTextSecondary)
                        .frame(height: 28)
                    Text("更多")
                        .font(.btMicro)
                        .foregroundStyle(.btTextSecondary)
                }
                .frame(width: 56)
            }
            .buttonStyle(BTPressableStyle.row)
            .accessibilityLabel("更多选项")

            Spacer()

            VStack(spacing: Spacing.xs) {
                Button {
                    viewModel.showDrillPicker = true
                } label: {
                    Image(systemName: BTIcon.plus)
                }
                .buttonStyle(BTButtonStyle.iconCircle)
                Text("添加")
                    .font(.btMicro)
                    .foregroundStyle(.btPrimary)
            }
            .accessibilityLabel("添加训练动作")

            Spacer()

            toolbarItem(icon: BTIcon.editPad, label: "心得") {
                viewModel.endTraining()
            }
            .accessibilityLabel("记录心得")

            Spacer()

            toolbarItem(
                icon: BTIcon.arrowLeftRight,
                label: "切换",
                tint: .btPrimary
            ) {
                withAnimation(BTMotion.springPanel) {
                    viewModel.showingOverview.toggle()
                }
            }
            .accessibilityLabel(viewModel.showingOverview ? "切换到单项视图" : "切换到总览视图")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background {
            if colorScheme == .dark {
                Color.btBGSecondary
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
        .overlay(alignment: .top) {
            if colorScheme == .dark {
                Color.btSeparator.frame(height: 0.5)
            }
        }
    }

    private func toolbarItem(icon: String, label: String, tint: Color = .btTextSecondary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.btTitle2)
                    .foregroundStyle(tint)
                    .frame(height: 28)
                Text(label)
                    .font(.btMicro)
                    .foregroundStyle(tint)
            }
            .frame(width: 56)
        }
        .buttonStyle(BTPressableStyle.row)
    }

    // MARK: - Rest Countdown Overlay

    private var restCountdownOverlay: some View {
        // F-TR-03: regular-page chrome tokens + press styles (not scene HUD)
        // F-AT-07: at 0:00 disable +30S to prevent accidental extend during dismiss window
        let restActionsEnabled = viewModel.restSecondsRemaining > 0

        // F-OV-05: modal rest overlay — light scrim (table remains visible).
        return ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 0) {
                    restOverlayTitleBar

                    Color.btSeparator
                        .frame(height: 0.5)

                    Spacer().frame(height: Spacing.xxl)

                    ZStack {
                        Circle()
                            .stroke(Color.btSeparator.opacity(0.3), lineWidth: 12)
                            .frame(width: 200, height: 200)

                        Circle()
                            .trim(from: 0, to: restProgress)
                            .stroke(
                                Color.btPrimary,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: viewModel.restSecondsRemaining)

                        Circle()
                            .stroke(Color.btSeparator.opacity(0.15), lineWidth: 10)
                            .frame(width: 150, height: 150)

                        Circle()
                            .trim(from: 0, to: restProgress)
                            .stroke(
                                Color.btAccent,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: viewModel.restSecondsRemaining)

                        VStack(spacing: Spacing.xs) {
                            Text(restTimeFormatted)
                                .font(.btLargeTitle)
                                .monospacedDigit()
                                .foregroundStyle(.btText)
                                .contentTransition(.numericText())
                                .animation(.default, value: viewModel.restSecondsRemaining)

                            Text(restActionsEnabled ? "组间休息" : "休息结束")
                                .font(.btFootnote)
                                .foregroundStyle(.btTextSecondary)
                        }
                    }

                    Spacer().frame(height: Spacing.xxxl)

                    HStack(spacing: Spacing.md) {
                        Button {
                            viewModel.addRestTime(30)
                        } label: {
                            Text("+30S")
                        }
                        .buttonStyle(BTButtonStyle.secondary)
                        .disabled(!restActionsEnabled)
                        .opacity(restActionsEnabled ? 1 : 0.4)

                        Button {
                            viewModel.skipRestTimer()
                        } label: {
                            Text("完成休息")
                        }
                        .buttonStyle(BTButtonStyle.primary)
                        .disabled(!restActionsEnabled)
                        .opacity(restActionsEnabled ? 1 : 0.4)
                    }
                    .padding(.horizontal, Spacing.xxl)

                    Spacer().frame(height: Spacing.xxl)
                }
                .frame(maxWidth: .infinity)
                .background(Color.btBGSecondary)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                .padding(.horizontal, Spacing.lg)

                Spacer()
            }
        }
    }

    /// P0-05 rest card chrome: title + minimize pill. Overlay covers the
    /// session toolbar, so minimize must live on the card itself.
    private var restOverlayTitleBar: some View {
        HStack(spacing: Spacing.sm) {
            Text("组间休息")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            Spacer(minLength: Spacing.sm)

            Button {
                viewModel.minimizeRestOverlay()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: BTIcon.chevronDown)
                        .font(.btCaption.weight(.semibold))
                    Text("最小化")
                        .font(.btCaption.weight(.semibold))
                }
                .foregroundStyle(.btPrimary)
                .padding(.horizontal, Spacing.sm)
                .frame(height: 28)
                .background(Color.btPrimaryMuted)
                .clipShape(Capsule())
            }
            .buttonStyle(BTPressableStyle.capsule)
            .accessibilityLabel("最小化组间休息")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    /// Collapsed rest chrome — session page only, not the cross-tab pill.
    private var minimizedRestChip: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    viewModel.expandRestOverlay()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: BTIcon.timer)
                            .font(.btCaption.weight(.semibold))
                        Text(restTimeFormatted)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md)
                    .frame(height: 40)
                    .background(Color.btAccent)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(BTPressableStyle.capsule)
                .accessibilityLabel("展开组间休息 \(restTimeFormatted)")
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, 72)
            }
        }
        .allowsHitTesting(true)
    }

    /// F-AT-04: session chrome handoff into the floating pill (other tabs).
    private func minimizeActiveTraining() {
        withAnimation(BTMotion.springPanel) {
            isMinimizing = true
            router.minimizeTraining(viewModel)
        }
        // Let the shrink-toward-pill read before the cover slides away (chrome ≤300ms).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            dismiss()
        }
    }

    private var restProgress: CGFloat {
        guard viewModel.restTotalSeconds > 0 else { return 0 }
        return CGFloat(viewModel.restSecondsRemaining) / CGFloat(viewModel.restTotalSeconds)
    }

    private var restTimeFormatted: String {
        let m = viewModel.restSecondsRemaining / 60
        let s = viewModel.restSecondsRemaining % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    // MARK: - Empty State (Free Mode)

    private var emptyState: some View {
        VStack(spacing: Spacing.xl) {
            timerSection
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

            Spacer()

            BTEmptyState(
                icon: "plus.circle",
                title: "添加训练动作",
                subtitle: "从动作库挑选想练习的动作，开始记录训练",
                action: {
                    viewModel.showDrillPicker = true
                }
            )

            Spacer()
        }
    }
}

// MARK: - Drill Picker Sheet

struct DrillPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var drills: [DrillContent] = []
    @State private var searchText = ""
    @State private var isLoading = true
    /// Selected drill ids — toggle add/remove on each tap.
    @State private var selectedDrillIds: Set<String>

    let onSelect: (DrillContent) -> Void
    let onDeselect: (DrillContent) -> Void

    init(
        initiallySelectedIds: Set<String> = [],
        onSelect: @escaping (DrillContent) -> Void,
        onDeselect: @escaping (DrillContent) -> Void
    ) {
        self._selectedDrillIds = State(initialValue: initiallySelectedIds)
        self.onSelect = onSelect
        self.onDeselect = onDeselect
    }

    private var filteredDrills: [DrillContent] {
        if searchText.isEmpty { return drills }
        return drills.filter {
            $0.nameZh.localizedCaseInsensitiveContains(searchText) ||
            $0.nameEn.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredDrills) { drill in
                let isSelected = selectedDrillIds.contains(drill.id)
                Button {
                    withAnimation(BTMotion.easeFast) {
                        if isSelected {
                            selectedDrillIds.remove(drill.id)
                            onDeselect(drill)
                        } else {
                            selectedDrillIds.insert(drill.id)
                            onSelect(drill)
                        }
                    }
                } label: {
                    HStack(spacing: Spacing.md) {
                        BTDrillListThumbnail(drillId: drill.id)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(drill.nameZh)
                                .font(.btHeadline)
                                .foregroundStyle(.btText)

                            HStack(spacing: Spacing.sm) {
                                Text(DrillCategory(rawValue: drill.category)?.nameZh ?? drill.category)
                                    .font(.btCaption)
                                    .foregroundStyle(.btTextSecondary)

                                Text("·")
                                    .foregroundStyle(.btTextTertiary)

                                Text(TrainingDoseResolver.resolve(content: drill).volumeText(
                                    unitLabel: DrillUnitLabel.label(category: drill.category,
                                                                    subcategory: drill.subcategory)
                                ))
                                    .font(.btCaption)
                                    .foregroundStyle(.btTextTertiary)
                            }
                        }

                        Spacer()

                        Image(systemName: isSelected ? BTIcon.checkmarkCircle : BTIcon.plusCircle)
                            .foregroundStyle(isSelected ? Color.btSuccess : Color.btPrimary)
                    }
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.xs)
                    .background(isSelected ? Color.btSuccess.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                }
                // List rows need .plain for reliable hit-testing; toggle feedback is the
                // plus→checkmark + row tint (press scale via BTPressableStyle breaks List taps).
                .buttonStyle(.plain)
                .accessibilityLabel(isSelected ? "取消选择\(drill.nameZh)" : "添加\(drill.nameZh)")
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "搜索训练动作")
            .navigationTitle("选择训练动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    let count = selectedDrillIds.count
                    Button("完成\(count > 0 ? "(\(count))" : "")") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
        .task {
            isLoading = true
            drills = await DrillContentService.shared.loadFallbackDrills()
            isLoading = false
        }
    }
}

// MARK: - Previews

private let previewPlanDrills = [
    TodayDrillItem(
        id: "warmup_drill_c006",
        drillId: "drill_c006",
        nameZh: "握杆稳定性训练",
        phaseType: "warmup",
        phaseZh: "热身",
        phaseIcon: "flame",
        plannedSets: PlannedTrainingSet.uniform(rounds: 3, targetBalls: 10),
        volumeText: "3 轮 × 10 球",
        isCompleted: false
    ),
    TodayDrillItem(
        id: "focused_drill_c011",
        drillId: "drill_c011",
        nameZh: "近台底袋直线",
        phaseType: "focused",
        phaseZh: "专项训练",
        phaseIcon: "target",
        plannedSets: PlannedTrainingSet.uniform(rounds: 3, targetBalls: 10),
        volumeText: "3 轮 × 10 球",
        isCompleted: false
    ),
    TodayDrillItem(
        id: "focused_drill_c023",
        drillId: "drill_c023",
        nameZh: "五分点直球",
        phaseType: "focused",
        phaseZh: "专项训练",
        phaseIcon: "target",
        plannedSets: PlannedTrainingSet.uniform(rounds: 5, targetBalls: 15),
        volumeText: "5 轮 × 15 球",
        isCompleted: false
    ),
]

#Preview("Plan Mode - Light") {
    ActiveTrainingView(
        viewModel: ActiveTrainingViewModel(mode: .plan(drills: previewPlanDrills, planId: "plan_beginner_12w"))
    )
    .environmentObject(AppRouter())
}

#Preview("Plan Mode - Dark") {
    ActiveTrainingView(
        viewModel: ActiveTrainingViewModel(mode: .plan(drills: previewPlanDrills, planId: "plan_beginner_12w"))
    )
    .environmentObject(AppRouter())
    .preferredColorScheme(.dark)
}

#Preview("Free Mode") {
    ActiveTrainingView(
        viewModel: ActiveTrainingViewModel(mode: .free)
    )
    .environmentObject(AppRouter())
}

#Preview("Free Mode - Dark") {
    ActiveTrainingView(
        viewModel: ActiveTrainingViewModel(mode: .free)
    )
    .environmentObject(AppRouter())
    .preferredColorScheme(.dark)
}
