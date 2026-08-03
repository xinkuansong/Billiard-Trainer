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

                    Text("推荐 \(drill.sets.defaultSets) 组")
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

    private var tutorialKind: DrillTutorialKindHeuristic {
        DrillTutorialKindResolver.resolve(for: drill)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                // v24 / E1: match baked thumbnail 2:1 so `.fill` does not crop left/right cushions.
                .aspectRatio(2.0, contentMode: .fit)
                .overlay {
                    tableArea
                }
                .clipped()

            // R4: title only — cover annotation already carries distance/pocket/spin;
            // repeating it as a subtitle added height without information.
            Text(drill.nameZh)
                .font(.btHeadline)
                .foregroundStyle(drill.isPremium ? .btTextTertiary : .btText)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
        }
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BTRadius.md)
                .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0)
        )
        .shadow(
            color: colorScheme == .dark ? .clear : Color.black.opacity(0.06),
            radius: 4, x: 0, y: 2
        )
    }

    private var tableArea: some View {
        ZStack(alignment: .bottom) {
            BTBakedDrillTable(drillId: drill.id)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: BTRadius.md,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: BTRadius.md
                )
            )

            LinearGradient(
                colors: [.clear, .black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 36)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
            )
        }
        .overlay(alignment: .topLeading) {
            BTLevelBadge(level: level, onDarkSurface: true)
                .padding(Spacing.sm)
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                cardBadge
                if isCompleted {
                    completedCornerBadge
                }
            }
            .padding(Spacing.sm)
        }
        .overlay(alignment: .bottomLeading) {
            // E20: within-group distinctive annotation (distance / spin / shot count + pocket).
            if let cover = DrillCoverAnnotation.coverLabel(for: drill) {
                Text(cover)
                    .font(.btCaption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(Spacing.sm)
                    .accessibilityLabel("动作特征 \(cover)")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // E19: tutorial presence + version corner badge.
            tutorialCornerBadge
                .padding(Spacing.sm)
        }
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

    private var completedCornerBadge: some View {
        Image(systemName: BTIcon.completeSeal)
            .font(.btCaption.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(Color.btSuccess.opacity(0.9))
            .clipShape(Circle())
            .accessibilityLabel("已完成")
    }

    @ViewBuilder
    private var tutorialCornerBadge: some View {
        switch tutorialKind {
        case .none:
            EmptyView()
        case .modern:
            coverMetaChip(text: "新版", accessibility: "有精讲，新版")
        case .legacy:
            coverMetaChip(text: "旧版", accessibility: "有精讲，旧版")
        }
    }

    private func coverMetaChip(text: String, accessibility: String) -> some View {
        Text(text)
            .font(.btCaption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 2)
            .background(Color.btPrimary.opacity(0.85), in: Capsule())
            .accessibilityLabel(accessibility)
    }

}

// MARK: - BTDrillThumbnail (shared mini table or fallback icon)

struct BTDrillThumbnail: View {
    let drill: DrillContent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        BTBakedDrillTable(drillId: drill.id)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.sm)
                    .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0)
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
