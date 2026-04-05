import SwiftUI

struct TrainingSummaryView: View {
    let elapsedSeconds: Int
    let drillCount: Int
    let totalSets: Int
    let totalBallsMade: Int
    let overallSuccessRate: Double
    let drillSummaries: [DrillSummary]
    let trainingNote: String
    let onSave: () -> Void
    let onGenerateShareImage: () -> Void
    let onViewHistory: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var durationMinutes: Int { elapsedSeconds / 60 }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    statsGrid
                    drillBreakdownSection
                    if !trainingNote.isEmpty {
                        noteSection
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }

            bottomActionBar
        }
        .background(Color.btBG.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                shareButton
            }
        }
    }

    // MARK: - Stats Grid (2×2 + 1 full-width)

    private var statsGrid: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                statCard(label: "训练时长", value: "\(durationMinutes)", unit: "分钟", icon: "clock.fill", iconColor: .btPrimary)
                statCard(label: "完成项目", value: "\(drillCount)", unit: "项", icon: "checklist", iconColor: .btPrimary)
            }
            HStack(spacing: Spacing.md) {
                statCard(label: "总组数", value: "\(totalSets)", unit: "组", icon: "square.grid.3x3.fill", iconColor: .btPrimary)
                statCard(label: "总进球", value: "\(totalBallsMade)", unit: "球", icon: "circle.inset.filled", iconColor: .btBallTarget)
            }
            successRateCard
        }
    }

    private func statCard(label: String, value: String, unit: String, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label)
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
                Spacer()
                Image(systemName: icon)
                    .font(.btHeadline)
                    .foregroundStyle(iconColor)
            }

            Spacer(minLength: Spacing.lg)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(value)
                    .font(.btStatNumber).fontWeight(.heavy)
                    .foregroundStyle(.btText)
                Text(unit)
                    .font(.btFootnote).fontWeight(.semibold)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    private var successRateCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("平均成功率")
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(overallSuccessRate * 100))")
                    .font(.btLargeTitle)
                    .foregroundStyle(.btText)
                Text("%")
                    .font(.btCallout).fontWeight(.bold)
                    .foregroundStyle(.btTextSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.btBGTertiary)
                    Capsule()
                        .fill(Color.btPrimary)
                        .frame(width: geo.size.width * overallSuccessRate)
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
        }
        .padding(Spacing.xl)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    // MARK: - Drill Breakdown

    private var drillBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("训练明细")
                .font(.btHeadline)
                .foregroundStyle(.btText)
                .padding(.horizontal, 2)

            ForEach(drillSummaries) { drill in
                drillCard(drill)
            }
        }
    }

    private func drillCard(_ drill: DrillSummary) -> some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: Spacing.md) {
                drillThumbnail
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.sm) {
                        Text(drill.nameZh)
                            .font(.btSubheadlineMedium).fontWeight(.bold)
                            .foregroundStyle(.btText)
                            .lineLimit(1)
                        if let level = drill.level {
                            BTLevelBadge(level: level)
                        }
                    }
                    Text("\(drill.sets.count) 组 · \(drill.totalBallsMade)/\(drill.totalBallsPossible) 球")
                        .font(.btCaption)
                        .foregroundStyle(.btTextTertiary)
                }
                Spacer()
                Text("\(Int(drill.successRate * 100))%")
                    .font(.btHeadline).fontWeight(.bold)
                    .foregroundStyle(drillRateColor(drill.successRate))
            }
            .padding(Spacing.lg)

            // Separator + set rows
            Rectangle()
                .fill(Color.btSeparator.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: 0) {
                ForEach(drill.sets) { set in
                    setRow(set)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: BTRadius.lg)
                .stroke(Color.btSeparator.opacity(colorScheme == .dark ? 0.3 : 0.15), lineWidth: 1)
        )
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.02), radius: 4, x: 0, y: 1)
    }

    private var drillThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: BTRadius.sm)
                .fill(Color.btPrimaryMuted)
            Image(systemName: "figure.pool.swim")
                .font(.btTitle2)
                .foregroundStyle(.btPrimary)
        }
        .frame(width: 48, height: 48)
        .overlay(
            RoundedRectangle(cornerRadius: BTRadius.sm)
                .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0)
        )
    }

    private func setRow(_ set: DrillSummary.SetResult) -> some View {
        HStack {
            Text("第 \(set.id) 组")
                .font(.btFootnote14)
                .foregroundStyle(.btTextSecondary)
            Spacer()
            Text("\(set.madeBalls)/\(set.targetBalls)")
                .font(.btFootnote14)
                .foregroundStyle(.btText)
            Image(systemName: "checkmark.circle.fill")
                .font(.btCallout)
                .foregroundStyle(.btPrimary)
        }
        .padding(.vertical, Spacing.sm)
    }

    private var shareButton: some View {
        Button(action: onGenerateShareImage) {
            Image(systemName: "square.and.arrow.up")
                .font(.btBody)
                .foregroundStyle(.btPrimary)
        }
    }

    private func drillRateColor(_ rate: Double) -> Color {
        if rate >= 0.7 { return .btPrimary }
        return colorScheme == .dark ? .btTextSecondary : .btWarning
    }

    // MARK: - Training Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "square.and.pencil")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
                Text("训练心得")
                    .font(.btCallout).fontWeight(.bold)
                    .foregroundStyle(.btText)
            }

            Text(trainingNote)
                .font(.btFootnote14).fontWeight(.medium)
                .foregroundStyle(.btTextSecondary)
                .lineSpacing(4)
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: BTRadius.lg)
                .stroke(Color.btSeparator.opacity(colorScheme == .dark ? 0.3 : 0.15), lineWidth: 1)
        )
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: Spacing.md) {
            Button(action: onSave) {
                Text("保存训练")
            }
            .buttonStyle(BTButtonStyle.primary)

            Button(action: onGenerateShareImage) {
                Label("生成分享图", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(BTButtonStyle.secondary)

            Button(action: onViewHistory) {
                Text("查看历史记录")
                    .font(.btFootnote)
                    .fontWeight(.bold)
                    .foregroundStyle(.btTextTertiary)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xl)
        .background(
            Color.btBGSecondary
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 8, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Previews

private let previewSummaries: [DrillSummary] = [
    DrillSummary(
        id: UUID(), nameZh: "定点红球进袋", level: .L1,
        totalBallsMade: 31, totalBallsPossible: 40,
        sets: [
            .init(id: 1, madeBalls: 8, targetBalls: 10),
            .init(id: 2, madeBalls: 7, targetBalls: 10),
            .init(id: 3, madeBalls: 8, targetBalls: 10),
            .init(id: 4, madeBalls: 8, targetBalls: 10),
        ]
    ),
    DrillSummary(
        id: UUID(), nameZh: "斯诺克直线进袋", level: .L0,
        totalBallsMade: 28, totalBallsPossible: 30,
        sets: [
            .init(id: 1, madeBalls: 10, targetBalls: 10),
            .init(id: 2, madeBalls: 9, targetBalls: 10),
            .init(id: 3, madeBalls: 9, targetBalls: 10),
        ]
    ),
    DrillSummary(
        id: UUID(), nameZh: "走位练习 A", level: .L2,
        totalBallsMade: 28, totalBallsPossible: 50,
        sets: [
            .init(id: 1, madeBalls: 6, targetBalls: 10),
            .init(id: 2, madeBalls: 5, targetBalls: 10),
            .init(id: 3, madeBalls: 6, targetBalls: 10),
            .init(id: 4, madeBalls: 5, targetBalls: 10),
            .init(id: 5, madeBalls: 6, targetBalls: 10),
        ]
    ),
]

#Preview("Light") {
    NavigationStack {
        TrainingSummaryView(
            elapsedSeconds: 2880,
            drillCount: 3,
            totalSets: 12,
            totalBallsMade: 87,
            overallSuccessRate: 0.72,
            drillSummaries: previewSummaries,
            trainingNote: "今天练习走位感觉明显进步，斯诺克直线进袋成功率很高，走位A还需要加强，下组尝试控制力道。",
            onSave: {},
            onGenerateShareImage: {},
            onViewHistory: {}
        )
        .navigationTitle("训练总结")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Dark") {
    NavigationStack {
        TrainingSummaryView(
            elapsedSeconds: 2880,
            drillCount: 3,
            totalSets: 12,
            totalBallsMade: 87,
            overallSuccessRate: 0.72,
            drillSummaries: previewSummaries,
            trainingNote: "今天练习走位感觉明显进步，斯诺克直线进袋成功率很高，走位A还需要加强，下组尝试控制力道。",
            onSave: {},
            onGenerateShareImage: {},
            onViewHistory: {}
        )
        .navigationTitle("训练总结")
        .navigationBarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
}

#Preview("No Note") {
    NavigationStack {
        TrainingSummaryView(
            elapsedSeconds: 1800,
            drillCount: 2,
            totalSets: 6,
            totalBallsMade: 42,
            overallSuccessRate: 0.42,
            drillSummaries: [
                DrillSummary(
                    id: UUID(), nameZh: "握杆稳定性训练", level: .L0,
                    totalBallsMade: 8, totalBallsPossible: 20,
                    sets: [
                        .init(id: 1, madeBalls: 4, targetBalls: 10),
                        .init(id: 2, madeBalls: 4, targetBalls: 10),
                    ]
                ),
                DrillSummary(
                    id: UUID(), nameZh: "中杆定杆基础", level: .L0,
                    totalBallsMade: 5, totalBallsPossible: 20,
                    sets: [
                        .init(id: 1, madeBalls: 2, targetBalls: 10),
                        .init(id: 2, madeBalls: 3, targetBalls: 10),
                    ]
                ),
            ],
            trainingNote: "",
            onSave: {},
            onGenerateShareImage: {},
            onViewHistory: {}
        )
        .navigationTitle("训练总结")
        .navigationBarTitleDisplayMode(.inline)
    }
}
