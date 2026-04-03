import SwiftUI
import SwiftData

struct TrainingHomeView: View {
    @StateObject private var viewModel = TrainingHomeViewModel()
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var modelContext
    @State private var activeTrainingMode: TrainingMode?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let session = viewModel.todaySession {
                    todayPlanContent(session)
                } else {
                    noPlanContent
                }
            }
            .padding(.vertical, Spacing.lg)
        }
        .background(.btBG)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.trainingPath.append(TrainingRoute.planList)
                } label: {
                    Label("训练计划", systemImage: "list.bullet.rectangle.portrait")
                }
            }
        }
        .task {
            await viewModel.load(context: modelContext)
        }
        .fullScreenCover(item: $activeTrainingMode) {
            Task { await viewModel.load(context: modelContext) }
        } content: { mode in
            ActiveTrainingView(viewModel: ActiveTrainingViewModel(mode: mode))
        }
    }

    // MARK: - No Active Plan

    private var noPlanContent: some View {
        VStack(spacing: Spacing.xxxl) {
            BTEmptyState(
                icon: "calendar.badge.plus",
                title: "还没有激活训练计划",
                subtitle: "选择一个官方计划开始系统训练，或直接开始自由记录",
                actionTitle: "选择训练计划",
                action: {
                    router.trainingPath.append(TrainingRoute.planList)
                }
            )

            freeRecordButton
                .padding(.horizontal, Spacing.xxl)
        }
    }

    // MARK: - Today's Plan Content

    private func todayPlanContent(_ session: TodaySessionInfo) -> some View {
        VStack(spacing: Spacing.xl) {
            planHeaderCard(session)
                .padding(.horizontal, Spacing.lg)

            if session.isAllCompleted {
                allCompletedBanner
                    .padding(.horizontal, Spacing.lg)
            } else {
                startTrainingButton(session)
                    .padding(.horizontal, Spacing.lg)
            }

            todayDrillList(session)
                .padding(.horizontal, Spacing.lg)

            freeRecordButton
                .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Plan Header Card

    private func planHeaderCard(_ session: TodaySessionInfo) -> some View {
        VStack(spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(session.planNameZh)
                        .font(.btTitle)
                        .foregroundStyle(.btText)

                    Text("第 \(session.weekNumber) 周 · 第 \(session.dayNumber) 天")
                        .font(.btSubheadline)
                        .foregroundStyle(.btTextSecondary)
                }

                Spacer()

                progressRing(session)
            }

            HStack(spacing: Spacing.md) {
                infoChip(icon: "book.pages", text: session.weekTheme)
                Spacer()
                infoChip(icon: "clock", text: "\(session.totalMinutes) 分钟")
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func progressRing(_ session: TodaySessionInfo) -> some View {
        ZStack {
            Circle()
                .stroke(.btBGTertiary, lineWidth: 6)

            Circle()
                .trim(from: 0, to: session.progress)
                .stroke(.btPrimary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring, value: session.progress)

            VStack(spacing: 0) {
                Text("\(session.completedCount)")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
                Text("/\(session.totalCount)")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .frame(width: 56, height: 56)
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.btCaption)
                .foregroundStyle(.btPrimary)
            Text(text)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }

    // MARK: - Start Training CTA

    private func startTrainingButton(_ session: TodaySessionInfo) -> some View {
        Button {
            activeTrainingMode = .plan(drills: session.drills)
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16))

                Text("开始今日训练")
                    .font(.btHeadline)

                Spacer()

                Text("\(session.totalCount - session.completedCount) 项待完成")
                    .font(.btCaption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .foregroundStyle(.white)
            .padding(Spacing.lg)
            .background(.btPrimary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        }
    }

    // MARK: - All Completed Banner

    private var allCompletedBanner: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 28))
                .foregroundStyle(.btSuccess)

            VStack(alignment: .leading, spacing: 2) {
                Text("今日训练已完成")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Text("做得不错！明天继续加油")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .background(Color.btSuccess.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Today's Drill List

    private func todayDrillList(_ session: TodaySessionInfo) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("今日训练")
                .font(.btTitle2)
                .foregroundStyle(.btText)

            let grouped = Dictionary(grouping: session.drills) { $0.phaseType }
            let orderedPhases = ["warmup", "focused", "combined", "review"]

            ForEach(orderedPhases, id: \.self) { phase in
                if let drills = grouped[phase], !drills.isEmpty {
                    phaseDrillSection(drills: drills)
                }
            }
        }
    }

    private func phaseDrillSection(drills: [TodayDrillItem]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let first = drills.first {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: first.phaseIcon)
                        .font(.btCaption)
                        .foregroundStyle(.btPrimary)
                    Text(first.phaseZh)
                        .font(.btSubheadlineMedium)
                        .foregroundStyle(.btTextSecondary)
                }
                .padding(.leading, Spacing.sm)
            }

            ForEach(drills) { drill in
                drillRow(drill)
            }
        }
    }

    private func drillRow(_ drill: TodayDrillItem) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(drill.isCompleted ? Color.btSuccess.opacity(0.15) : Color.btBGTertiary)
                    .frame(width: 36, height: 36)

                Image(systemName: drill.isCompleted ? "checkmark" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(drill.isCompleted ? .btSuccess : .btTextTertiary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(drill.nameZh)
                    .font(.btBody)
                    .foregroundStyle(drill.isCompleted ? .btTextSecondary : .btText)
                    .strikethrough(drill.isCompleted, color: .btTextTertiary)

                Text("\(drill.sets) 组 × \(drill.ballsPerSet) 球")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }

            Spacer()

            if drill.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.btSuccess)
            }
        }
        .padding(Spacing.md)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Free Record Button

    private var freeRecordButton: some View {
        Button {
            activeTrainingMode = .free
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.btAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("自由记录")
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                    Text("不按计划，自由选择训练项目")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.btCallout)
                    .foregroundStyle(.btTextTertiary)
            }
            .padding(Spacing.lg)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("With Plan") {
    NavigationStack {
        TrainingHomeView()
            .navigationTitle("训练")
    }
    .modelContainer(ModelContainerFactory.makeInMemoryContainer())
    .environmentObject(AppRouter())
}

#Preview("No Plan - Dark") {
    NavigationStack {
        TrainingHomeView()
            .navigationTitle("训练")
    }
    .modelContainer(ModelContainerFactory.makeInMemoryContainer())
    .environmentObject(AppRouter())
    .preferredColorScheme(.dark)
}
