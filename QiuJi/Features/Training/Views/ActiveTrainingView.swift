import SwiftUI

struct ActiveTrainingView: View {
    @StateObject var viewModel: ActiveTrainingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.btBG.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.drills.isEmpty {
                    emptyState
                } else {
                    trainingContent
                }
            }
            .navigationTitle(viewModel.isPlanMode ? "按计划训练" : "自由记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.btPrimary)
                        }
                    }
                }
            }
            .alert("结束训练？", isPresented: $viewModel.showEndConfirm) {
                Button("继续训练", role: .cancel) {}
                Button("结束", role: .destructive) {
                    viewModel.cleanup()
                    dismiss()
                }
            } message: {
                Text("当前训练进度不会保存，确定要结束吗？")
            }
            .sheet(isPresented: $viewModel.showDrillPicker) {
                DrillPickerSheet { content in
                    viewModel.addDrill(content)
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

            bottomActions
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
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

                setsInfoRow(sets: drill.sets, ballsPerSet: drill.ballsPerSet)
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

    private func setsInfoRow(sets: Int, ballsPerSet: Int) -> some View {
        HStack(spacing: Spacing.lg) {
            infoBlock(value: "\(sets)", label: "组")
            infoBlock(value: "\(ballsPerSet)", label: "球/组")
            infoBlock(value: "\(sets * ballsPerSet)", label: "总球数")
        }
    }

    private func infoBlock(value: String, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.btHeadline)
                .foregroundStyle(.btText)
            Text(label)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private func phaseIcon(_ type: String) -> String {
        switch type {
        case "warmup":   return "flame"
        case "focused":  return "target"
        case "combined": return "square.grid.3x3"
        case "review":   return "pencil.and.list.clipboard"
        default:         return "figure.pool.swim"
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        Button {
            // T-P4-05: navigate to DrillRecordView for current drill
        } label: {
            Label("记录成绩", systemImage: "pencil.line")
        }
        .buttonStyle(BTButtonStyle.primary)
        .disabled(viewModel.drills.isEmpty)
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
                                .font(.btBody)
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
}

#Preview("Free Mode") {
    ActiveTrainingView(
        viewModel: ActiveTrainingViewModel(mode: .free)
    )
}

#Preview("Free Mode - Dark") {
    ActiveTrainingView(
        viewModel: ActiveTrainingViewModel(mode: .free)
    )
    .preferredColorScheme(.dark)
}
