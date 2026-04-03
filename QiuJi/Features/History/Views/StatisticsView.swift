import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @StateObject private var vm = StatisticsViewModel()

    var body: some View {
        Group {
            if vm.sessions.isEmpty && !vm.isLoading {
                emptyState
            } else {
                statsContent
            }
        }
        .background(Color.btBG.ignoresSafeArea())
        .navigationTitle("统计")
        .navigationBarTitleDisplayMode(.inline)
        .premiumGate(isPremium: true)
        .task {
            await vm.loadSessions(context: modelContext)
        }
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
                timeRangePicker
                summaryCards
                frequencyChart
                categoryChart
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
    }

    // MARK: - Time Range

    private var timeRangePicker: some View {
        Picker("时间范围", selection: $vm.timeRange) {
            ForEach(StatisticsTimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: Spacing.md) {
            summaryCard(icon: "calendar", value: "\(vm.trainingDays)", label: "训练天数")
            summaryCard(icon: "clock", value: vm.formattedDuration, label: "总时长")
            summaryCard(icon: "square.stack", value: "\(vm.totalSets)", label: "总组数")
        }
    }

    private func summaryCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.btPrimary)
            Text(value)
                .font(.btTitle)
                .foregroundStyle(.btText)
            Text(label)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Frequency Chart

    private var frequencyChart: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("训练频率")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            Chart(vm.frequencyData) { point in
                LineMark(
                    x: .value("日期", point.label),
                    y: .value("次数", point.count)
                )
                .foregroundStyle(Color.btPrimary)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("日期", point.label),
                    y: .value("次数", point.count)
                )
                .foregroundStyle(Color.btPrimary)

                AreaMark(
                    x: .value("日期", point.label),
                    y: .value("次数", point.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.btPrimary.opacity(0.3), Color.btPrimary.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel()
                        .foregroundStyle(Color.btTextSecondary)
                    AxisGridLine()
                        .foregroundStyle(Color.btSeparator)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .foregroundStyle(Color.btTextSecondary)
                }
            }
            .frame(height: 200)
            .padding(Spacing.lg)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    // MARK: - Category Chart

    @ViewBuilder
    private var categoryChart: some View {
        let rates = vm.categorySuccessRates

        if !rates.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("分类成功率")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)

                Chart(rates) { item in
                    BarMark(
                        x: .value("成功率", item.rate),
                        y: .value("类别", item.nameZh)
                    )
                    .foregroundStyle(barColor(item.rate))
                    .annotation(position: .trailing, spacing: 4) {
                        Text("\(Int(item.rate * 100))%")
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                    }
                }
                .chartXScale(domain: 0...1)
                .chartXAxis {
                    AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v * 100))%")
                                    .font(.btCaption2)
                                    .foregroundStyle(Color.btTextTertiary)
                            }
                        }
                        AxisGridLine()
                            .foregroundStyle(Color.btSeparator)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .foregroundStyle(Color.btTextSecondary)
                    }
                }
                .frame(height: CGFloat(rates.count) * 44 + 20)
                .padding(Spacing.lg)
                .background(.btBGSecondary)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            }
        }
    }

    private func barColor(_ rate: Double) -> Color {
        if rate >= 0.8 { return .btSuccess }
        if rate >= 0.5 { return .btPrimary }
        return .btWarning
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
