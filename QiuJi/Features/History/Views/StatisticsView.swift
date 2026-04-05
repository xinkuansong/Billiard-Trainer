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
            if vm.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.sessions.isEmpty {
                emptyState
            } else if !subscriptionManager.isPremium {
                BTPremiumLock(mode: .fullMask) {
                    showSubscription = true
                } content: {
                    statsContent
                }
            } else {
                statsContent
            }
        }
        .task {
            await vm.loadSessions(context: modelContext)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }

    private var chartAmberColor: Color {
        colorScheme == .dark ? Color.btAccent : Color.btBallTarget
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

    // MARK: - Success Rate Card

    private var successRateCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("分类成功率")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
                Spacer()
                changeIndicator(
                    value: vm.successRateChange.value,
                    percent: vm.successRateChange.percent,
                    unit: "%",
                    compareLabel: vm.periodCompareLabel
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("平均成功率")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", vm.overallSuccessRate * 100))
                        .font(.btStatNumber)
                        .foregroundStyle(.btText)
                    Text("%")
                        .font(.btSubheadlineMedium)
                        .foregroundStyle(.btTextSecondary)
                }
                Text(vm.dateRangeLabel)
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }

            successRateChart

            chartLegend(color1: .btPrimary, label1: "成功率", color2: .btText, label2: "趋势线")
        }
        .statisticsCard()
    }

    private var successRateChart: some View {
        Chart {
            let avg = vm.successRateBarData.map(\.rate).reduce(0, +) / max(Double(vm.successRateBarData.count), 1)

            ForEach(vm.successRateBarData) { bar in
                BarMark(
                    x: .value("时间", bar.label),
                    y: .value("成功率", bar.rate * 100)
                )
                .foregroundStyle(Color.btPrimary.opacity(0.6))
                .cornerRadius(2)
            }

            RuleMark(y: .value("均值", avg * 100))
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
            HStack {
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
                .foregroundStyle(.btPrimary)
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
