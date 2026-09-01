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
            VStack(spacing: Spacing.xl) {
                timeRangeContext
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

    private var timeRangeContext: some View {
        VStack(spacing: Spacing.sm) {
            timeRangePicker

            HStack {
                Text("统计区间")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                Spacer()
                Text(vm.dateRangeLabel)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        ZStack(alignment: .topTrailing) {
            StatisticsEngineeringMark(color: .btPrimary)
                .frame(width: 156, height: 96)
                .opacity(colorScheme == .dark ? 0.06 : 0.04)

            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("训练概况")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: Spacing.xl) {
                        trainingDaysMetric
                        Spacer(minLength: Spacing.md)
                        overviewMetric(value: "\(vm.totalDurationMinutes)", label: "分钟 · 总时长")
                        overviewMetric(value: "\(vm.totalSets)", label: "训练组数")
                    }

                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        trainingDaysMetric
                        HStack(spacing: Spacing.xxl) {
                            overviewMetric(value: "\(vm.totalDurationMinutes)", label: "分钟 · 总时长")
                            overviewMetric(value: "\(vm.totalSets)", label: "训练组数")
                        }
                    }
                }

                Divider()
                    .overlay(Color.btSeparator)

                kindBreakdownStrip
            }
        }
        .statisticsCard(emphasized: true)
    }

    private var trainingDaysMetric: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text("\(vm.trainingDays)")
                    .font(.btDisplay)
                    .foregroundStyle(.btText)
                Text("天")
                    .font(.btTitle)
                    .foregroundStyle(.btTextSecondary)
            }
            .monospacedDigit()

            Text(overviewSubtitle)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }

    private func overviewMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.btStatNumber)
                .foregroundStyle(.btText)
                .monospacedDigit()
            Text(label)
                .font(.btCaption2)
                .foregroundStyle(.btTextTertiary)
        }
    }

    /// 按 kind 分开的口径说明（契约 §5.3）：球台成绩与屏内练习分列，
    /// 工具使用单独一行并明示「不计训练量」——它既不进准确率也不计周目标。
    private var kindBreakdownStrip: some View {
        let days = vm.daysByKind
        let mins = vm.minutesByKind
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xxl) {
                kindMetric(label: "球台训练", days: days.drill, minutes: mins.drill)
                kindMetric(label: "屏内练习", days: days.cognitive, minutes: mins.cognitive)
            }
            if days.tool > 0 {
                Text("工具使用 \(days.tool) 天 · \(mins.tool) 分钟（不计训练量与成绩）")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextTertiary)
            }
        }
    }

    private func kindMetric(label: String, days: Int, minutes: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.btCaption2)
                .foregroundStyle(.btTextTertiary)
            Text("\(days) 天 · \(minutes) 分钟")
                .font(.btFootnote14.weight(.semibold))
                .foregroundStyle(.btTextSecondary)
                .monospacedDigit()
        }
    }

    private var overviewSubtitle: String {
        switch vm.timeRange {
        case .week:  return "本周训练天数"
        case .month: return "本月训练天数"
        case .year:  return "本年训练天数"
        }
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
    let emphasized: Bool

    func body(content: Content) -> some View {
        content
            .padding(Spacing.xl)
            .background(
                emphasized
                    ? Color.btPrimary.opacity(colorScheme == .dark ? 0.10 : 0.045)
                    : Color.btBGSecondary
            )
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: BTRadius.lg)
                    .stroke(
                        colorScheme == .dark ? Color.btSeparator : Color.btPrimary.opacity(0.08),
                        lineWidth: colorScheme == .dark ? 0.5 : 1
                    )
            }
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.025),
                radius: 8, x: 0, y: 3
            )
    }
}

extension View {
    fileprivate func statisticsCard(emphasized: Bool = false) -> some View {
        modifier(StatisticsCardModifier(emphasized: emphasized))
    }
}

/// Page-local v47 data-page signature in screen-local normalized coordinates.
/// It suggests cue-ball → contact → target construction without claiming table geometry.
private struct StatisticsEngineeringMark: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let cue = CGPoint(x: size.width * 0.08, y: size.height * 0.78)
            let contact = CGPoint(x: size.width * 0.50, y: size.height * 0.52)
            let target = CGPoint(x: size.width * 0.92, y: size.height * 0.20)

            var route = Path()
            route.move(to: cue)
            route.addLine(to: contact)
            route.addLine(to: target)
            context.stroke(route, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

            context.fill(
                Path(ellipseIn: CGRect(x: cue.x - 5, y: cue.y - 5, width: 10, height: 10)),
                with: .color(color)
            )
            context.stroke(
                Path(ellipseIn: CGRect(x: contact.x - 6, y: contact.y - 6, width: 12, height: 12)),
                with: .color(color),
                lineWidth: 1
            )
            context.fill(
                Path(ellipseIn: CGRect(x: target.x - 3, y: target.y - 3, width: 6, height: 6)),
                with: .color(color)
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
