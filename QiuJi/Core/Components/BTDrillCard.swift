import SwiftUI

// MARK: - BTDrillCard (Horizontal Row — used in PlanList, FavoriteDrills, etc.)

struct BTDrillCard: View {
    let drill: DrillContent
    let isFavorited: Bool
    var onFavoriteTap: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var level: DrillLevel {
        DrillLevel(rawValue: drill.level) ?? .L0
    }

    private var ballTypeLabel: String {
        drill.ballType.map { type in
            switch type {
            case "chinese8": return "中式"
            case "nineBall": return "9球"
            default: return "通用"
            }
        }.joined(separator: "/")
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            BTDrillThumbnail(drill: drill)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(drill.nameZh)
                        .font(.btHeadline)
                        .foregroundStyle(drill.isPremium ? .btTextTertiary : .btText)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    BTLevelBadge(level: level)
                }

                HStack(spacing: Spacing.xs) {
                    Text(ballTypeLabel)
                        .font(.btFootnote)
                        .foregroundStyle(.btTextSecondary)

                    Text("·")
                        .foregroundStyle(.btTextTertiary)

                    Text("推荐 \(TrainingDoseResolver.resolve(content: drill).totalRounds) 轮")
                        .font(.btFootnote)
                        .foregroundStyle(.btTextSecondary)
                }
            }

            VStack {
                if drill.isPremium {
                    // F-ST-04: list row uses same PRO badge as grid cards.
                    BTProBadge()
                } else if let onFavoriteTap {
                    Button(action: onFavoriteTap) {
                        Image(systemName: isFavorited ? BTIcon.heartFilled : BTIcon.heart)
                            .font(.btCallout)
                            .foregroundStyle(isFavorited ? .btAccent : .btTextTertiary)
                    }
                }

                Spacer()

                Image(systemName: BTIcon.chevronRight)
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        // F-CL-02 / SPEC §6.5：行卡 Dark 描边对齐网格卡；只描边、禁阴影。
        .overlay(
            RoundedRectangle(cornerRadius: BTRadius.md)
                .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0)
        )
    }
}

// MARK: - BTDrillGridCard (2-Column Grid — DrillListView)

struct BTDrillGridCard: View {
    let drill: DrillContent
    let isFavorited: Bool
    /// Ever practiced (appears in any `TrainingSession` / `DrillEntry`).
    var isCompleted: Bool = false
    var onFavoriteTap: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var level: DrillLevel {
        DrillLevel(rawValue: drill.level) ?? .L0
    }

    private var tutorialKind: DrillTutorialKind? {
        DrillTutorialKindResolver.resolve(for: drill)
    }

    var body: some View {
        BTContentGridCard(
            title: drill.nameZh,
            coverAspectRatio: 2.0,
            titleMinHeight: 40,
            titleColor: .btText
        ) {
            tableArea
        } meta: {
            metaRow
        }
    }

    private var tableArea: some View {
        BTBakedDrillTable(drillId: drill.id)
        .btThumbnailFrame(
            cornerRadius: BTRadius.md,
            topCornersOnly: true,
            showsStroke: false,
            colorScheme: colorScheme
        )
        .overlay(alignment: .topLeading) {
            BTLevelBadge(level: level, onDarkSurface: true)
                .padding(Spacing.sm)
        }
        .overlay(alignment: .topTrailing) {
            cardBadge
                .padding(Spacing.sm)
        }
        .overlay(alignment: .bottomTrailing) {
            if isCompleted {
                BTPracticedBadge()
                    .padding(Spacing.sm)
            }
        }
    }

    @ViewBuilder
    private var metaRow: some View {
        let parts = metaParts
        if parts.isEmpty {
            EmptyView()
        } else {
            Text(parts.joined(separator: " · "))
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityLabel(parts.joined(separator: "，"))
        }
    }

    private var metaParts: [String] {
        var parts: [String] = []
        if let tutorialKind {
            parts.append(tutorialKind.cardLabel)
        }
        return parts
    }

    @ViewBuilder
    private var cardBadge: some View {
        if drill.isPremium {
            BTProBadge()
        } else if let onFavoriteTap {
            Button(action: onFavoriteTap) {
                Image(systemName: isFavorited ? BTIcon.heartFilled : BTIcon.heart)
                    .font(.btFootnote14.weight(.medium))
                    .foregroundStyle(isFavorited ? .btAccent : .white.opacity(0.9))
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.35))
                    .clipShape(Circle())
            }
        }
    }

}

/// Cover-corner badge: this drill has been practiced at least once (DR-077).
/// Felt is ~btPrimary Light (`#1B6B3A`); Light primary would vanish on the table.
/// Force Dark so `btPrimary` resolves to `#25A25A`.
struct BTPracticedBadge: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: BTIcon.checkmark)
                .font(.btMicro.weight(.bold))
            Text("已练")
                .font(.btCaption2.weight(.heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Color.btPrimary)
        .clipShape(Capsule())
        .environment(\.colorScheme, .dark)
        .accessibilityLabel("已练过")
        .accessibilityIdentifier("drillCardPracticedBadge")
    }
}

// MARK: - BTDrillThumbnail (shared mini table or fallback icon)

struct BTDrillThumbnail: View {
    let drill: DrillContent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        BTBakedDrillTable(drillId: drill.id)
            .btThumbnailFrame(
                cornerRadius: BTRadius.sm,
                topCornersOnly: false,
                showsStroke: true,
                colorScheme: colorScheme
            )
    }
}

// MARK: - Previews

private let previewSample = DrillContent(
    id: "drill_c001", nameZh: "半台直线球", nameEn: "Half-Table Straight",
    category: "accuracy", subcategory: "straight", ballType: ["chinese8"],
    level: "L0", difficulty: 1, isPremium: false,
    description: "测试", coachingPoints: ["1"], standardCriteria: "15球进10球",
    sets: .init(defaultSets: 3, defaultBallsPerSet: 15),
    animation: DrillAnimation(
        cueBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.25), path: [PathPoint(x: 0.5, y: 0.45)]),
        targetBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.43), path: [PathPoint(x: 0.5, y: 0.5268)]),
        pocket: "bottomCenter", cueDirection: CanvasPoint(x: 0.5, y: 0.0)
    ),
    tutorial: DrillTutorial(sections: [
        TutorialSection(
            title: "技术原理",
            content: "",
            items: [TutorialItem(label: "要点", text: "直线")]
        )
    ])
)

private let previewPremium = DrillContent(
    id: "drill_c099", nameZh: "高级蛇彩清台路线", nameEn: "Advanced Runout",
    category: "combined", subcategory: "runout", ballType: ["chinese8"],
    level: "L3", difficulty: 4, isPremium: true,
    description: "测试", coachingPoints: ["1"], standardCriteria: "清台",
    sets: .init(defaultSets: 2, defaultBallsPerSet: 15),
    animation: DrillAnimation(
        cueBall: BallAnimation(start: CanvasPoint(x: 0.3, y: 0.15), path: [PathPoint(x: 0.7, y: 0.35)]),
        targetBall: BallAnimation(start: CanvasPoint(x: 0.7, y: 0.33), path: [PathPoint(x: 0.95, y: 0.5)]),
        pocket: "topRight", cueDirection: CanvasPoint(x: 0.7, y: 0.0)
    ),
    tutorial: DrillTutorial(sections: [
        TutorialSection(title: "动作要领", content: "legacy pure text"),
        TutorialSection(title: "常见错误", content: "legacy"),
        TutorialSection(title: "进阶变化", content: "legacy"),
        TutorialSection(title: "练习建议", content: "legacy")
    ])
)

#Preview("Row Card") {
    VStack(spacing: Spacing.sm) {
        BTDrillCard(drill: previewSample, isFavorited: false, onFavoriteTap: {})
        BTDrillCard(drill: previewPremium, isFavorited: false)
    }
    .padding()
    .background(.btBG)
}

#Preview("Grid Card Light") {
    let columns = [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible())]
    LazyVGrid(columns: columns, spacing: Spacing.md) {
        BTDrillGridCard(drill: previewSample, isFavorited: false, onFavoriteTap: {})
        BTDrillGridCard(drill: previewPremium, isFavorited: false, isCompleted: true)
        BTDrillGridCard(drill: previewSample, isFavorited: true, isCompleted: true, onFavoriteTap: {})
    }
    .padding()
    .background(.btBG)
}

#Preview("Grid Card Dark") {
    let columns = [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible())]
    LazyVGrid(columns: columns, spacing: Spacing.md) {
        BTDrillGridCard(drill: previewSample, isFavorited: false, onFavoriteTap: {})
        BTDrillGridCard(drill: previewPremium, isFavorited: false, isCompleted: true)
    }
    .padding()
    .background(.btBG)
    .preferredColorScheme(.dark)
}
