import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @StateObject private var vm = StatisticsViewModel()

    @State private var showSubscription = false

    var body: some View {
        Group {
            if vm.isLoading && vm.sessions.isEmpty && vm.errorMessage == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.errorMessage {
                // F-ST-01：失败与空态分流 + 重试入口。
                BTEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "加载失败",
                    subtitle: error,
                    actionTitle: "重试"
                ) {
                    Task { await vm.loadSessions(context: modelContext) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Spacing.lg)
            } else if !vm.hasTrainingSessions {
                // 只有 `kind="tool"` 会话（或空库）的用户按「无训练数据」处理——
                // 工具使用不是训练量（契约 §5.3）。角度成绩仍在下方聚合区展示。
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        emptyState
                        angleStatsSection
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxxxl)
                }
            } else if !subscriptionManager.isPremium {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        timeRangePicker
                        BTPremiumLock(
                            mode: .fullMask,
                            title: "统计功能为 Pro 专属",
                            subtitle: "升级 Pro 解锁训练统计、趋势图表和分类对比"
                        ) {
                            showSubscription = true
                        } content: {
                            VStack(spacing: Spacing.lg) {
                                overviewCard
                                durationCard
                                successRateCard
                                categoryComparisonSection
                            }
                        }
                        angleStatsSection
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxxxl)
                }
            } else {
                statsContent
            }
        }
        .task {
            // 保活后仅首次无数据时加载，避免切 Tab 假闪（F-HI-04）。
            if vm.sessions.isEmpty && vm.errorMessage == nil {
                await vm.loadSessions(context: modelContext)
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }

    // MARK: - Angle Training Aggregate

    /// Aggregate angle-training stats (误差趋势 / 区间分析 / quiz-type filter)
    /// live in the 统计 Tab so users see the big picture here while the
    /// 历史 Tab keeps each angle training as an individual record row.
    private var angleStatsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("角度训练")
                .font(.btHeadline)
                .foregroundStyle(.btPrimary)
                .padding(.top, Spacing.lg)

            AngleHistorySection()
        }
    }

    private var chartAmberColor: Color {
        Color.btChartSeries
    }

    // MARK: - Empty

    private var emptyState: some View {
        BTEmptyState(
            icon: "chart.bar",
            title: "还没有训练数据",
            subtitle: "完成第一次训练后，统计数据将在这里显示",
            actionTitle: "开始训练"
        ) {
            router.switchTab(.training)
        }
    }

    // MARK: - Content

    private var statsContent: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                timeRangePicker
                overviewCard
                durationCard
                successRateCard
                categoryComparisonSection
                angleStatsSection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
    }

    // MARK: - Time Range

    private var timeRangePicker: some View {
        BTTogglePillGroup(
            options: StatisticsTimeRange.allCases,
            selected: $vm.timeRange
        ) { $0.rawValue }
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("训练概况")
                .font(.btHeadline)
                .foregroundStyle(.btPrimary)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(vm.trainingDays)")
                            .font(.btDisplay)
                            .foregroundStyle(.btText)
                        Text("天")
                            .font(.btTitle)
                            .foregroundStyle(.btTextSecondary)
                    }

                    Text(overviewSubtitle)
                        .font(.btSubheadline)
                        .foregroundStyle(.btTextSecondary)

                    kindBreakdownLine

                    HStack(spacing: Spacing.md) {
                        ForEach(vm.trainingDaysBreakdown.prefix(3), id: \.category) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.category)
                                    .font(.btCaption)
                                    .foregroundStyle(.btTextTertiary)
                                Text("\(item.days)天")
                                    .font(.btSubheadlineMedium)
                                    .foregroundStyle(.btPrimary)
                            }
                        }
                    }
                    .padding(.top, Spacing.sm)
                }

                Spacer()

                miniBarChart
            }
        }
        .statisticsCard()
    }

    /// 按 kind 分开的口径说明（契约 §5.3）：球台成绩与屏内练习分列，
    /// 工具使用单独一行并明示「不计训练量」——它既不进准确率也不计周目标。
    private var kindBreakdownLine: some View {
        let days = vm.daysByKind
        let mins = vm.minutesByKind
        return VStack(alignment: .leading, spacing: 2) {
            Text("球台训练 \(days.drill) 天 · \(mins.drill) 分钟")
            Text("屏内练习 \(days.cognitive) 天 · \(mins.cognitive) 分钟")
            if days.tool > 0 {
                Text("工具使用 \(days.tool) 天 · \(mins.tool) 分钟（不计训练量与成绩）")
                    .foregroundStyle(.btTextTertiary)
            }
        }
        .font(.btCaption)
        .foregroundStyle(.btTextSecondary)
        .padding(.top, 2)
    }

    private var overviewSubtitle: String {
        switch vm.timeRange {
        case .week:  return "本周训练天数"
        case .month: return "本月训练天数"
        case .year:  return "本年训练天数"
        }
    }

    private var miniBarChart: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(vm.durationBarData.suffix(6)) { bar in
                let maxH: CGFloat = 64
                let h = bar.hours > 0 ? max(4, CGFloat(bar.hours / maxBarHours) * maxH) : 2
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.btPrimary.opacity(bar.date > Calendar.current.startOfDay(for: Date()) ? 0.3 : 0.6))
                    .frame(width: 6, height: min(h, maxH))
            }
        }
        .frame(height: 64, alignment: .bottom)
        .padding(.top, Spacing.xxl)
    }

    private var maxBarHours: Double {
        vm.durationBarData.map(\.hours).max() ?? 1
    }

    // MARK: - Duration Card

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("训练时长")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
                Spacer()
                changeIndicator(
                    value: vm.durationChange.value,
                    percent: vm.durationChange.percent,
                    unit: "小时",
                    compareLabel: vm.periodCompareLabel
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("平均训练")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", vm.averageDurationHoursPerPeriod))
                        .font(.btStatNumber)
                        .foregroundStyle(.btText)
                    Text(vm.periodLabel)
                        .font(.btSubheadlineMedium)
                        .foregroundStyle(.btTextSecondary)
                }
                Text(vm.dateRangeLabel)
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }

            durationChart

            chartLegend(color1: chartAmberColor, label1: "总量图", color2: .btText, label2: "均值线")
        }
        .statisticsCard()
    }

    private var durationChart: some View {
        Chart {
            let avg = vm.durationBarData.map(\.hours).reduce(0, +) / max(Double(vm.durationBarData.count), 1)

            ForEach(vm.durationBarData) { bar in
                BarMark(
                    x: .value("时间", bar.label),
                    y: .value("时长", bar.hours)
                )
                .foregroundStyle(chartAmberColor)
                .cornerRadius(2)
            }

            RuleMark(y: .value("均值", avg))
                .foregroundStyle(.btText.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .foregroundStyle(Color.btTextSecondary)
                AxisGridLine()
                    .foregroundStyle(Color.btSeparator)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .foregroundStyle(Color.btTextSecondary)
            }
        }
        .frame(height: 120)
    }

    // MARK: - Success Rate Card（按 category 分组，✅ D-v29-2）

    private var successRateCard: some View {
        StatisticsCategoryRatesCard(
            items: vm.categorySuccessRates,
            dateRangeLabel: vm.dateRangeLabel,
            hasScores: vm.hasDrillScores
        )
    }

    // MARK: - Category Comparison Grid

    @ViewBuilder
    private var categoryComparisonSection: some View {
        let items = vm.categoryComparison
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("各分类对比")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
                    ForEach(items) { item in
                        categoryComparisonCell(item)
                    }
                }
            }
        }
    }

    private func categoryComparisonCell(_ item: CategoryComparisonData) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                if let category = DrillCategory(rawValue: item.id) {
                    BTDrillCategoryIcon(category: category, size: 14, filled: true)
                }
                Text(item.nameZh)
                    .font(.btCaption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.btText)
                Spacer()
                if item.isNew {
                    Text("新")
                        .font(.btMicro)
                        .fontWeight(.bold)
                        .foregroundStyle(.btTextTertiary)
                } else {
                    Text(changeText(item.changePercent))
                        .font(.btMicro)
                        .fontWeight(.bold)
                        .foregroundStyle(item.changePercent >= 0 ? .btPrimary : .btWarning)
                }
            }

            HStack(alignment: .bottom, spacing: 2) {
                miniComparisonBar(value: item.previousValue, maxValue: 100, opacity: 0.3)
                miniComparisonBar(value: (item.previousValue + item.currentValue) / 2, maxValue: 100, opacity: 0.3)
                miniComparisonBar(value: item.currentValue, maxValue: 100, opacity: 1.0)
            }
            .frame(height: 32)
        }
        .padding(Spacing.md)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private func miniComparisonBar(value: Double, maxValue: Double, opacity: Double) -> some View {
        let height = max(2, CGFloat(value / maxValue) * 32)
        return RoundedRectangle(cornerRadius: 2)
            .fill(Color.btPrimary.opacity(opacity))
            .frame(maxWidth: .infinity, maxHeight: height)
            .frame(height: 32, alignment: .bottom)
    }

    // MARK: - Shared Components

    private func changeIndicator(value: Double, percent: Double, unit: String, compareLabel: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(String(format: "%+.1f %@ (%+.0f%%)", value, unit, percent))
                .font(.btFootnote14)
                .fontWeight(.bold)
                // F-HI-06：环比下跌与分类对比拉齐用 btWarning。
                .foregroundStyle(percent >= 0 ? Color.btPrimary : Color.btWarning)
            Text(compareLabel)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }

    private func chartLegend(color1: Color, label1: String, color2: Color, label2: String) -> some View {
        HStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color1)
                    .frame(width: 10, height: 10)
                Text(label1)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }
            HStack(spacing: Spacing.xs) {
                Rectangle()
                    .fill(color2.opacity(0.6))
                    .frame(width: 16, height: 1.5)
                Text(label2)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .padding(.top, Spacing.sm)
    }

    private func changeText(_ change: Double) -> String {
        if abs(change) < 0.5 { return "持平" }
        return String(format: "%+.0f%%", change)
    }
}

// MARK: - Category Success Rates Card（✅ D-v29-2）

/// 按 category 分组的成功率卡。
///
/// ⛔ 这里**没有**「平均成功率」这类跨分类单一比率：不同分类的计量单位（球 / 局 / 次）
/// 加到同一分母无物理意义（契约 §5.4，D-v29-2 已裁定删除）。
///
/// 独立成 internal 视图（而非 `StatisticsView` 的私有 body 片段），是为了能在测试里
/// 用真实数据离屏渲染取证——统计页整体受 Pro 门控（`BTPremiumLock(.fullMask)` 会把
/// 内容 blur 掉），从 App 截图看不清数字。
struct StatisticsCategoryRatesCard: View {
    let items: [CategorySuccessRate]
    let dateRangeLabel: String
    let hasScores: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("分类成功率")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
                Spacer()
                Text(dateRangeLabel)
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }

            Text("按分类分别统计：成功率 = 该分类累计成功 ÷ 累计目标。不同分类单位不同（球/局/次），不做合并。")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)

            if hasScores {
                VStack(spacing: Spacing.md) {
                    ForEach(items) { item in
                        row(item)
                    }
                }
            } else {
                Text("本区间还没有球台训练成绩")
                    .font(.btCallout)
                    .foregroundStyle(.btTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Spacing.md)
            }
        }
        .statisticsCard()
    }

    private func row(_ item: CategorySuccessRate) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                if let category = DrillCategory(rawValue: item.id) {
                    BTDrillCategoryIcon(category: category, size: 14, filled: true)
                }
                Text(item.nameZh)
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btText)
                Spacer()
                Text(String(format: "%.0f%%", item.rate * 100))
                    .font(.btSubheadlineSemibold)
                    .foregroundStyle(.btPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.btPrimary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.btPrimary)
                        .frame(width: max(2, geo.size.width * CGFloat(min(max(item.rate, 0), 1))))
                }
            }
            .frame(height: 6)

            HStack(spacing: Spacing.md) {
                Text(item.countSummary)
                Text("\(item.totalSets) 组")
                if item.hasMixedUnits {
                    Text("单位混合")
                        .foregroundStyle(.btWarning)
                }
            }
            .font(.btCaption)
            .foregroundStyle(.btTextTertiary)
        }
    }
}

// MARK: - Statistics Card Modifier

private struct StatisticsCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(Spacing.xl)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
            .overlay(
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.btPrimary)
                        .frame(width: 3)
                    Spacer()
                }
                .padding(.vertical, Spacing.sm)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
            )
            .shadow(
                color: colorScheme == .dark ? .clear : Color.btPrimary.opacity(0.04),
                radius: 12, x: 0, y: 4
            )
    }
}

extension View {
    fileprivate func statisticsCard() -> some View {
        modifier(StatisticsCardModifier())
    }
}

#Preview("Light") {
    NavigationStack {
        StatisticsView()
    }
    .environmentObject(AppRouter())
    .environmentObject(SubscriptionManager.shared)
    .modelContainer(for: TrainingSession.self, inMemory: true)
}

#Preview("Dark") {
    NavigationStack {
        StatisticsView()
    }
    .environmentObject(AppRouter())
    .environmentObject(SubscriptionManager.shared)
    .modelContainer(for: TrainingSession.self, inMemory: true)
    .preferredColorScheme(.dark)
}
