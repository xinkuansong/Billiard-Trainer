import SwiftUI

// MARK: - Supporting Types

struct TrainingSessionSummary {
    let date: Date
    let planName: String
    let durationMinutes: Int
    let completedDrills: Int
    let totalSets: Int
    let overallSuccessRate: Double
    let drills: [DrillResult]

    struct DrillResult: Identifiable {
        let id = UUID()
        let name: String
        let setsCount: Int
        let madeBalls: Int
        let targetBalls: Int

        var successRate: Double {
            guard targetBalls > 0 else { return 0 }
            return Double(madeBalls) / Double(targetBalls)
        }
    }

    var totalBallsMade: Int {
        drills.reduce(0) { $0 + $1.madeBalls }
    }
}

enum ShareCardTheme: String, CaseIterable, Identifiable {
    case defaultGreen = "基础绿"
    case blackWhite = "黑白"
    case nightBlue = "暗夜蓝"
    case deepPurple = "深紫"

    var id: String { rawValue }

    var backgroundColor: Color {
        switch self {
        case .defaultGreen: return Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)
        case .nightBlue: return Color(red: 0x0D / 255.0, green: 0x1B / 255.0, blue: 0x2A / 255.0)
        case .blackWhite: return Color(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x1A / 255.0)
        case .deepPurple: return Color(red: 0x1A / 255.0, green: 0x14 / 255.0, blue: 0x2A / 255.0)
        }
    }

    var accentColor: Color {
        switch self {
        case .defaultGreen: return .btPrimary
        case .nightBlue: return Color(red: 0x4A / 255.0, green: 0x9E / 255.0, blue: 0xFF / 255.0)
        case .blackWhite: return .white
        case .deepPurple: return Color(red: 0xBB / 255.0, green: 0x86 / 255.0, blue: 0xFC / 255.0)
        }
    }

    var previewColor: Color {
        backgroundColor
    }
}

enum ShareCardFont: String, CaseIterable {
    case system = "跟随系统"
    case rounded = "圆角字体"

    var fontDesign: Font.Design {
        switch self {
        case .system: return .default
        case .rounded: return .rounded
        }
    }
}

// MARK: - BTShareCard

struct BTShareCard: View {
    let session: TrainingSessionSummary
    let theme: ShareCardTheme
    var fontChoice: ShareCardFont = .system
    var hideSuccessRate: Bool = false
    var hideBallTable: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            logoHeader
                .padding(.bottom, Spacing.md)

            titleSection
                .padding(.bottom, Spacing.lg)

            separator
                .padding(.bottom, Spacing.lg)

            drillList
                .padding(.bottom, Spacing.lg)

            Spacer(minLength: 0)

            statsGrid
                .padding(.bottom, Spacing.lg)

            brandFooter
        }
        .padding(Spacing.xl)
        .background(theme.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Logo Header

    private var logoHeader: some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: BTRadius.sm)
                .fill(Color.btPrimary)
                .frame(width: 36, height: 36)
                .overlay(
                    Text("Q")
                        .font(.system(size: 20, weight: .bold, design: fontDesign))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("QiuJi 球迹")
                    .font(.system(size: 15, weight: .semibold, design: fontDesign))
                    .foregroundStyle(.white)
                Text(session.date.formatted(.dateTime.year().month().day()) + " · 台球训练")
                    .font(.btCaption)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(session.planName)
                .font(.system(size: 22, weight: .bold, design: fontDesign))
                .foregroundStyle(.white)

            Text("共 \(session.completedDrills) 项 · \(session.durationMinutes) 分钟")
                .font(.btFootnote)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Separator

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(height: 1)
    }

    // MARK: - Drill List

    private var drillList: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(session.drills) { drill in
                HStack {
                    Text(drill.name)
                        .font(.system(size: 15, weight: .medium, design: fontDesign))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text("\(drill.setsCount)组")
                        .font(.btFootnote)
                        .foregroundStyle(.white.opacity(0.6))

                    if !hideSuccessRate {
                        Text("\(Int(drill.successRate * 100))%")
                            .font(.system(size: 15, weight: .bold, design: fontDesign))
                            .foregroundStyle(drillRateColor(drill.successRate))
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm + 2)
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
            }
        }
    }

    private func drillRateColor(_ rate: Double) -> Color {
        if rate >= 0.9 {
            return Color(red: 0x25 / 255.0, green: 0xA2 / 255.0, blue: 0x5A / 255.0)
        } else if rate >= 0.7 {
            return theme.accentColor
        } else {
            return .white.opacity(0.60)
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 0) {
            statColumn(value: "\(session.totalBallsMade)", label: "总进球")
            statColumn(value: "\(session.totalSets)", label: "总组数", showBorders: true)
            if !hideSuccessRate {
                statColumn(
                    value: "\(Int(session.overallSuccessRate * 100))%",
                    label: "平均成功率",
                    valueColor: overallRateColor
                )
            }
        }
    }

    private func statColumn(value: String, label: String, showBorders: Bool = false, valueColor: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: fontDesign))
                .foregroundStyle(valueColor ?? .white)
            Text(label)
                .font(.btCaption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            if showBorders {
                Rectangle().fill(.white.opacity(0.12)).frame(width: 1)
            }
        }
        .overlay(alignment: .trailing) {
            if showBorders {
                Rectangle().fill(.white.opacity(0.12)).frame(width: 1)
            }
        }
    }

    private var overallRateColor: Color {
        if session.overallSuccessRate >= 0.9 {
            return Color(red: 0x25 / 255.0, green: 0xA2 / 255.0, blue: 0x5A / 255.0)
        } else if session.overallSuccessRate >= 0.7 {
            return theme.accentColor
        } else {
            return .white.opacity(0.6)
        }
    }

    // MARK: - Brand Footer

    private var brandFooter: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("QiuJi 球迹")
                    .font(.system(size: 13, weight: .bold, design: fontDesign))
                    .foregroundStyle(.white)
                Text("台球训练记录 App")
                    .font(.btCaption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            RoundedRectangle(cornerRadius: 6)
                .fill(.white.opacity(0.9))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "qrcode")
                        .font(.btTitle)
                        .foregroundStyle(.black.opacity(0.4))
                )
        }
        .padding(Spacing.lg)
        .background(.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private var fontDesign: Font.Design {
        fontChoice.fontDesign
    }
}

// MARK: - Preview

private let sampleSession = TrainingSessionSummary(
    date: Date(),
    planName: "力量训练 Day 1",
    durationMinutes: 48,
    completedDrills: 3,
    totalSets: 12,
    overallSuccessRate: 0.72,
    drills: [
        .init(name: "定点红球进袋", setsCount: 4, madeBalls: 31, targetBalls: 40),
        .init(name: "斯诺克直线进袋", setsCount: 3, madeBalls: 28, targetBalls: 30),
        .init(name: "走位练习 A", setsCount: 5, madeBalls: 28, targetBalls: 50),
    ]
)

#Preview("BTShareCard Themes") {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            ForEach(ShareCardTheme.allCases) { theme in
                BTShareCard(session: sampleSession, theme: theme)
                    .frame(height: 480)
            }
        }
        .padding(Spacing.xxl)
    }
    .background(Color.btBG)
}

#Preview("BTShareCard Rounded Font") {
    BTShareCard(session: sampleSession, theme: .defaultGreen, fontChoice: .rounded)
        .frame(height: 480)
        .padding(Spacing.xxl)
        .background(Color.btBG)
}

#Preview("BTShareCard Dark") {
    VStack(spacing: Spacing.lg) {
        BTShareCard(session: sampleSession, theme: .defaultGreen)
            .frame(height: 480)
        BTShareCard(session: sampleSession, theme: .nightBlue)
            .frame(height: 480)
    }
    .padding(Spacing.xxl)
    .background(Color.btBG)
    .preferredColorScheme(.dark)
}
