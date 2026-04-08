import SwiftUI
import SwiftData

struct ActiveTrainingView: View {
    @StateObject var viewModel: ActiveTrainingViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showShareView = false
    @State private var showingOverview = true
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
                            viewModel.saveTraining(context: modelContext)
                            if viewModel.didSaveSuccessfully {
                                dismiss()
                            }
                        },
                        onGenerateShareImage: {
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
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.trainingPhase)
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
                                Image(systemName: "chevron.left")
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
                DrillPickerSheet { content in
                    viewModel.addDrill(content)
                }
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
                .init(name: $0.nameZh, setsCount: $0.sets.count, madeBalls: $0.totalBallsMade, targetBalls: $0.totalBallsPossible)
            }
        )
    }

    // MARK: - Active Phase Content

    private var activePhaseContent: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.drills.isEmpty {
                emptyState
            } else if showingOverview {
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
                            thumbnailAnimation: drill.animation,
                            totalSets: sets.count,
                            completedSets: sets.filter(\.isCompleted).count,
                            madeBalls: sets.reduce(0) { $0 + $1.madeBalls },
                            targetBalls: sets.reduce(0) { $0 + $1.targetBalls },
                            onTap: {
                                viewModel.currentDrillIndex = index
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showingOverview = false
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
                    Image(systemName: "clock.badge.xmark")
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
                            Image(systemName: "forward.fill")
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
                        Image(systemName: "clock.badge.xmark")
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
                        Button { viewModel.skipRestTimer() } label: {
                            Text("\(viewModel.restSecondsRemaining)s")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(.btAccent)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("跳过休息 \(viewModel.restSecondsRemaining)秒")
                    } else {
                        Button { viewModel.startRestTimer() } label: {
                            Image(systemName: "timer")
                                .font(.btHeadline)
                                .foregroundStyle(.btTextSecondary)
                        }
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("休息设置")
                    }

                    Menu {
                        Button { viewModel.showEndConfirm = true } label: {
                            Label("结束训练", systemImage: "stop.circle")
                        }
                        if !viewModel.isTimerSkipped {
                            Button { viewModel.skipTimer() } label: {
                                Label("跳过计时", systemImage: "forward.fill")
                            }
                        } else {
                            Button { viewModel.unskipTimer() } label: {
                                Label("恢复计时", systemImage: "clock")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.btHeadline)
                            .foregroundStyle(.btTextSecondary)
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("更多选项")

                    Button { viewModel.showEndConfirm = true } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.btTitle)
                            .foregroundStyle(.btPrimary)
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("完成训练")
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.isPlanMode ? "按计划训练" : "自由记录")
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                    if !viewModel.progressText.isEmpty {
                        Text(viewModel.progressText)
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                    }
                }
                Spacer()
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
                        onAddSet: { viewModel.addSet(drillIndex: index) },
                        onCompleteSet: { setIndex in viewModel.completeSet(drillIndex: index, setIndex: setIndex) },
                        onDeleteSet: { setIndex in viewModel.deleteSet(drillIndex: index, setIndex: setIndex) },
                        restDuration: $viewModel.restDuration
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
            toolbarItem(icon: "minus", label: "最小化") {
                router.minimizeTraining(viewModel)
                dismiss()
            }
            .accessibilityLabel("最小化训练")

            Spacer()

            Menu {
                Button { viewModel.showEndConfirm = true } label: {
                    Label("结束训练", systemImage: "stop.circle")
                }
                if !viewModel.isTimerSkipped {
                    Button { viewModel.skipTimer() } label: {
                        Label("跳过计时", systemImage: "forward.fill")
                    }
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "ellipsis")
                        .font(.btTitle2)
                        .foregroundStyle(.btTextSecondary)
                        .frame(height: 28)
                    Text("更多")
                        .font(.btMicro)
                        .foregroundStyle(.btTextSecondary)
                }
                .frame(width: 56)
            }
            .accessibilityLabel("更多选项")

            Spacer()

            VStack(spacing: 2) {
                Button {
                    viewModel.showDrillPicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(BTButtonStyle.iconCircle)
                Text("添加")
                    .font(.btMicro)
                    .foregroundStyle(.btPrimary)
            }
            .accessibilityLabel("添加训练项目")

            Spacer()

            toolbarItem(icon: "square.and.pencil", label: "心得") {
                viewModel.endTraining()
            }
            .accessibilityLabel("记录心得")

            Spacer()

            toolbarItem(
                icon: "arrow.left.arrow.right",
                label: "切换",
                tint: .btPrimary
            ) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showingOverview.toggle()
                }
            }
            .accessibilityLabel(showingOverview ? "切换到单项视图" : "切换到总览视图")
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
            VStack(spacing: 2) {
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
                title: "添加训练项目",
                subtitle: "点击右上角 + 从动作库选择训练项目",
                actionTitle: "选择训练项目",
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
    @State private var addedCount = 0

    let onSelect: (DrillContent) -> Void

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
                Button {
                    onSelect(drill)
                    addedCount += 1
                } label: {
                    HStack {
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

                                Text("\(drill.sets.defaultSets)组 × \(drill.sets.defaultBallsPerSet)球")
                                    .font(.btCaption)
                                    .foregroundStyle(.btTextTertiary)
                            }
                        }

                        Spacer()

                        Image(systemName: "plus.circle")
                            .foregroundStyle(.btPrimary)
                    }
                    .padding(.vertical, Spacing.xs)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "搜索训练项目")
            .navigationTitle("选择训练项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("完成\(addedCount > 0 ? "(\(addedCount))" : "")") {
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
        sets: 3,
        ballsPerSet: 10,
        isCompleted: false
    ),
    TodayDrillItem(
        id: "focused_drill_c011",
        drillId: "drill_c011",
        nameZh: "近台底袋直线",
        phaseType: "focused",
        phaseZh: "专项训练",
        phaseIcon: "target",
        sets: 3,
        ballsPerSet: 10,
        isCompleted: false
    ),
    TodayDrillItem(
        id: "focused_drill_c023",
        drillId: "drill_c023",
        nameZh: "五分点直球",
        phaseType: "focused",
        phaseZh: "专项训练",
        phaseIcon: "target",
        sets: 5,
        ballsPerSet: 15,
        isCompleted: false
    ),
]

#Preview("Plan Mode - Light") {
    ActiveTrainingView(
        viewModel: ActiveTrainingViewModel(mode: .plan(drills: previewPlanDrills))
    )
    .environmentObject(AppRouter())
}

#Preview("Plan Mode - Dark") {
    ActiveTrainingView(
        viewModel: ActiveTrainingViewModel(mode: .plan(drills: previewPlanDrills))
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
