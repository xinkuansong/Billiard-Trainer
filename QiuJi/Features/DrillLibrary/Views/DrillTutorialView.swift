import SwiftUI

struct DrillTutorialView: View {
    let drill: DrillContent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header
                
                if let tutorial = drill.tutorial {
                    ForEach(Array(tutorial.sections.enumerated()), id: \.offset) { index, section in
                        sectionCard(section, index: index)
                    }
                }
            }
            .padding(.bottom, Spacing.xxl)
        }
        .background(.btBG)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("精讲")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Text(DrillCategory(rawValue: drill.category)?.nameZh ?? drill.category)
                    .font(.btCaption2)
                    .foregroundStyle(.btPrimary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 3)
                    .background(.btPrimary.opacity(0.12))
                    .clipShape(Capsule())

                BTLevelBadge(level: DrillLevel(rawValue: drill.level) ?? .L0)
            }

            Text(drill.nameZh)
                .font(.btTitle)
                .foregroundStyle(.btText)

            Text(drill.description)
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    // MARK: - Section Card

    private static let sectionIcons: [String: String] = [
        "技术原理": "lightbulb.fill",
        "动作要领": "figure.pool.swim",
        "常见错误与纠正": "exclamationmark.triangle.fill",
        "进阶练习": "arrow.up.right.circle.fill",
    ]

    private static let sectionColors: [String: Color] = [
        "技术原理": .blue,
        "动作要领": .btPrimary,
        "常见错误与纠正": .orange,
        "进阶练习": .purple,
    ]

    private func sectionCard(_ section: TutorialSection, index: Int) -> some View {
        let icon = Self.sectionIcons[section.title] ?? "doc.text.fill"
        let accentColor = Self.sectionColors[section.title] ?? .btPrimary

        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.btFootnote14)
                    .foregroundStyle(accentColor)
                    .frame(width: 28, height: 28)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Circle())

                Text(section.title)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
            }

            Text(section.content)
                .font(.btCallout)
                .foregroundStyle(.btText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.horizontal, Spacing.lg)
    }
}

#Preview("Light") {
    NavigationStack {
        DrillTutorialView(drill: DrillContent(
            id: "drill_c001",
            nameZh: "半台直线球",
            nameEn: "Half-Table Straight Shot",
            category: "accuracy",
            subcategory: "straight",
            ballType: ["chinese8"],
            level: "L0",
            difficulty: 1,
            isPremium: false,
            description: "将目标球从半台距离沿直线打入下中袋，训练基础瞄准稳定性与出杆方向。",
            coachingPoints: ["保持出杆方向与瞄准线严格一致"],
            standardCriteria: "15球进10球",
            sets: .init(defaultSets: 3, defaultBallsPerSet: 15),
            animation: DrillAnimation(
                cueBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.25), path: []),
                targetBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.43), path: []),
                pocket: "bottomCenter",
                cueDirection: CanvasPoint(x: 0.5, y: 0.0)
            ),
            tutorial: DrillTutorial(sections: [
                TutorialSection(title: "技术原理", content: "示例内容"),
                TutorialSection(title: "动作要领", content: "示例内容"),
                TutorialSection(title: "常见错误与纠正", content: "示例内容"),
                TutorialSection(title: "进阶练习", content: "示例内容"),
            ])
        ))
    }
}
