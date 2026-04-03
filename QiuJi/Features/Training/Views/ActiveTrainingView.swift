import SwiftUI
import SwiftData

struct ActiveTrainingView: View {
    @StateObject var viewModel: ActiveTrainingViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
                        drillCount: viewModel.drills.count,
                        elapsedSeconds: viewModel.elapsedSeconds,
                        onSkip: { viewModel.skipNote() },
                        onComplete: { viewModel.submitNote() }
                    )
                case .summary:
                    TrainingSummaryView(
                        elapsedSeconds: viewModel.elapsedSeconds,
                        drillCount: viewModel.drills.count,
                        totalSets: viewModel.totalSets,
                        overallSuccessRate: viewModel.overallSuccessRate,
                        drillSummaries: viewModel.drillSummaries,
                        hasNote: !viewModel.trainingNote.isEmpty,
                        onSave: {
                            viewModel.saveTraining(context: modelContext)
                            if viewModel.didSaveSuccessfully {
                                dismiss()
                            }
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
        }
        .interactiveDismissDisabled()
        .task {
            await viewModel.loadDrills()
            if viewModel.isPlanMode && !viewModel.drills.isEmpty {
                viewModel.startTimer()
            }
        }
        .onDisappear {
            viewModel.cleanup()
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

    // MARK: - Active Phase Content

    private var activePhaseContent: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.drills.isEmpty {
                emptyState
            } else {
                trainingContent
            }
        }
    }

    // MARK: - Training Content

    private var trainingContent: some View {
        VStack(spacing: 0) {
            timerSection
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

            progressSection
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)

            drillCarousel
                .padding(.top, Spacing.md)
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
                                .font(.system(size: 14))
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
                                .font(.system(size: 12))
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

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: Spacing.sm) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.btBGTertiary)
                        .frame(height: 6)

                    Capsule()
                        .fill(Color.btPrimary)
                        .frame(width: geo.size.width * viewModel.progress, height: 6)
                        .animation(.spring(duration: 0.3), value: viewModel.progress)
                }
            }
            .frame(height: 6)

            Text(viewModel.progressText)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }

    // MARK: - Drill Carousel

    private var drillCarousel: some View {
        TabView(selection: $viewModel.currentDrillIndex) {
            ForEach(Array(viewModel.drills.enumerated()), id: \.element.id) { index, drill in
                drillPage(drill)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxHeight: .infinity)
    }

    private func drillPage(_ drill: ActiveDrill) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let animation = drill.animation {
                    BTBilliardTable(animation: animation)
                        .padding(.bottom, Spacing.sm)
                }

                phaseBadge(type: drill.phaseType, label: drill.phaseZh)

                Text(drill.nameZh)
                    .font(.btTitle)
                    .foregroundStyle(.btText)

                if !drill.description.isEmpty {
                    Text(drill.description)
                        .font(.btBody)
                        .foregroundStyle(.btTextSecondary)
                }

                if !drill.coachingPoints.isEmpty {
                    coachingPointsCard(drill.coachingPoints)
                }

                recordingSection(drill: drill)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
    }

    private func phaseBadge(type: String, label: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: phaseIcon(type))
                .font(.system(size: 11))
            Text(label)
                .font(.btCaption)
        }
        .foregroundStyle(.btPrimary)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color.btPrimary.opacity(0.1))
        .clipShape(Capsule())
    }

    private func coachingPointsCard(_ points: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("训练要点")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btText)

            ForEach(points, id: \.self) { point in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Circle()
                        .fill(Color.btPrimary)
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)

                    Text(point)
                        .font(.btCallout)
                        .foregroundStyle(.btTextSecondary)
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Recording Section (U-06)

    private func recordingSection(drill: ActiveDrill) -> some View {
        let drillIdx = viewModel.currentDrillIndex
        let setIdx = viewModel.currentSetIndex
        let isAllDone = viewModel.isCurrentDrillAllSetsCompleted
        let ballsMade = viewModel.currentBallsMade

        return VStack(spacing: Spacing.lg) {
            HStack {
                Text(isAllDone ? "全部完成" : "第 \(setIdx + 1) 组 / 共 \(drill.sets) 组")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btTextSecondary)

                Spacer()

                Text("\(drill.ballsPerSet) 球/组")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }

            if !isAllDone {
                VStack(spacing: Spacing.md) {
                    Text("\(ballsMade)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.btPrimary)
                        .contentTransition(.numericText())
                        .animation(.default, value: ballsMade)

                    Text("进球数")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)

                    HStack(spacing: Spacing.xxxl) {
                        Button {
                            viewModel.decrementBalls()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(ballsMade > 0 ? Color.btWarning : Color.btBGTertiary)
                        }
                        .disabled(ballsMade <= 0)

                        Button {
                            viewModel.incrementBalls()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(ballsMade < drill.ballsPerSet ? Color.btPrimary : Color.btBGTertiary)
                        }
                        .disabled(ballsMade >= drill.ballsPerSet)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
                .background(.btBGSecondary)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))

                Button {
                    viewModel.completeCurrentSet()
                } label: {
                    Label(
                        setIdx < drill.sets - 1 ? "完成本组 → 下一组" : "完成最后一组",
                        systemImage: "checkmark.circle.fill"
                    )
                }
                .buttonStyle(BTButtonStyle.primary)
            } else {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.btSuccess)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("本项训练完成")
                            .font(.btHeadline)
                            .foregroundStyle(.btText)

                        let total = (drillIdx < viewModel.ballsMadeRecords.count)
                            ? viewModel.ballsMadeRecords[drillIdx].reduce(0, +)
                            : 0
                        Text("共进球 \(total) / \(drill.sets * drill.ballsPerSet)")
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                    }

                    Spacer()
                }
                .padding(Spacing.lg)
                .background(Color.btSuccess.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
            }

            setsProgressGrid(drill: drill, drillIdx: drillIdx)
        }
        .padding(.top, Spacing.sm)
    }

    private func setsProgressGrid(drill: ActiveDrill, drillIdx: Int) -> some View {
        let records = drillIdx < viewModel.ballsMadeRecords.count
            ? viewModel.ballsMadeRecords[drillIdx]
            : Array(repeating: 0, count: drill.sets)
        let currentSet = drillIdx < viewModel.currentSetIndices.count
            ? viewModel.currentSetIndices[drillIdx]
            : 0

        return HStack(spacing: Spacing.sm) {
            ForEach(0..<drill.sets, id: \.self) { setIdx in
                VStack(spacing: Spacing.xs) {
                    Text("\(records[setIdx])/\(drill.ballsPerSet)")
                        .font(.btCaption2)
                        .foregroundStyle(setIdx < currentSet ? .btSuccess : .btTextTertiary)
                    Text("第\(setIdx + 1)组")
                        .font(.btCaption2)
                        .foregroundStyle(.btTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(setIdx < currentSet
                    ? Color.btSuccess.opacity(0.08)
                    : setIdx == currentSet ? Color.btPrimary.opacity(0.08) : Color.btBGSecondary)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
            }
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

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        EmptyView()
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

#Preview("Plan Mode") {
    ActiveTrainingView(
        viewModel: ActiveTrainingViewModel(mode: .plan(drills: [
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
        ]))
    )
    .environmentObject(AppRouter())
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
