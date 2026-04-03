import SwiftUI

struct TrainingSummaryView: View {
    let elapsedSeconds: Int
    let drillCount: Int
    let totalSets: Int
    let overallSuccessRate: Double
    let drillSummaries: [DrillSummary]
    let hasNote: Bool
    let onSave: () -> Void
    let onViewHistory: () -> Void

    private var formattedTime: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                headerSection
                statsGrid
                if !drillSummaries.isEmpty {
                    drillBreakdownSection
                }
                actionButtons
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .background(Color.btBG.ignoresSafeArea())
        .navigationTitle("训练总结")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 48))
                .foregroundStyle(.btPrimary)

            Text("训练完成！")
                .font(.btLargeTitle)
                .foregroundStyle(.btText)

            Text(encouragementText)
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.xxl)
    }

    private var encouragementText: String {
        if overallSuccessRate >= 0.8 {
            return "表现出色，继续保持！"
        } else if overallSuccessRate >= 0.5 {
            return "稳步提升中，坚持就是胜利。"
        } else {
            return "每一次练习都是进步，加油！"
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: Spacing.md) {
            statCard(icon: "clock", value: formattedTime, label: "训练时长")
            statCard(icon: "list.bullet", value: "\(drillCount)", label: "训练项目")
            statCard(icon: "square.stack", value: "\(totalSets)", label: "总组数")
            statCard(
                icon: "percent",
                value: "\(Int(overallSuccessRate * 100))%",
                label: "整体成功率",
                valueColor: rateColor(overallSuccessRate)
            )
        }
    }

    private func statCard(
        icon: String,
        value: String,
        label: String,
        valueColor: Color = .btText
    ) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.btPrimary)

            Text(value)
                .font(.btTitle)
                .foregroundStyle(valueColor)

            Text(label)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Drill Breakdown

    private var drillBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("各项成绩")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            ForEach(drillSummaries) { drill in
                drillRow(drill)
            }
        }
        .padding(.top, Spacing.sm)
    }

    private func drillRow(_ drill: DrillSummary) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(drill.nameZh)
                    .font(.btBodyMedium)
                    .foregroundStyle(.btText)

                Text("\(drill.totalBallsMade) / \(drill.totalBallsPossible) 球")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }

            Spacer()

            Text("\(Int(drill.successRate * 100))%")
                .font(.btTitle2)
                .foregroundStyle(rateColor(drill.successRate))
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private func rateColor(_ rate: Double) -> Color {
        if rate >= 0.8 { return .btSuccess }
        if rate >= 0.5 { return .btPrimary }
        return .btWarning
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: Spacing.md) {
            Button(action: onSave) {
                Label("保存训练", systemImage: "square.and.arrow.down.fill")
            }
            .buttonStyle(BTButtonStyle.primary)

            Button(action: onViewHistory) {
                Label("查看历史", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(BTButtonStyle.text)
        }
        .padding(.top, Spacing.md)
    }
}

// MARK: - Previews

#Preview("Good Result") {
    NavigationStack {
        TrainingSummaryView(
            elapsedSeconds: 2700,
            drillCount: 3,
            totalSets: 9,
            overallSuccessRate: 0.75,
            drillSummaries: [
                DrillSummary(id: UUID(), nameZh: "半台直线球", totalBallsMade: 28, totalBallsPossible: 30),
                DrillSummary(id: UUID(), nameZh: "斜角入底角袋", totalBallsMade: 18, totalBallsPossible: 30),
                DrillSummary(id: UUID(), nameZh: "低杆远台缩杆", totalBallsMade: 12, totalBallsPossible: 30),
            ],
            hasNote: true,
            onSave: {},
            onViewHistory: {}
        )
    }
}

#Preview("Dark Mode") {
    NavigationStack {
        TrainingSummaryView(
            elapsedSeconds: 1800,
            drillCount: 2,
            totalSets: 6,
            overallSuccessRate: 0.42,
            drillSummaries: [
                DrillSummary(id: UUID(), nameZh: "握杆稳定性训练", totalBallsMade: 8, totalBallsPossible: 20),
                DrillSummary(id: UUID(), nameZh: "中杆定杆基础", totalBallsMade: 5, totalBallsPossible: 20),
            ],
            hasNote: false,
            onSave: {},
            onViewHistory: {}
        )
    }
    .preferredColorScheme(.dark)
}
