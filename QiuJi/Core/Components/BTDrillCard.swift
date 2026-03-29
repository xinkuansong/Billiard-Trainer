import SwiftUI

struct BTDrillCard: View {
    let drill: DrillContent
    let isFavorited: Bool
    var onFavoriteTap: (() -> Void)? = nil

    private var level: DrillLevel {
        DrillLevel(rawValue: drill.level) ?? .L0
    }

    private var categoryName: String {
        DrillCategory(rawValue: drill.category)?.nameZh ?? drill.category
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
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    BTLevelBadge(level: level)

                    Text(drill.nameZh)
                        .font(.btHeadline)
                        .foregroundStyle(drill.isPremium ? .btTextTertiary : .btText)
                        .lineLimit(1)
                }

                HStack(spacing: Spacing.xs) {
                    Text(categoryName)
                        .font(.btFootnote)
                        .foregroundStyle(.btTextSecondary)

                    Text("·")
                        .foregroundStyle(.btTextTertiary)

                    Text(ballTypeLabel)
                        .font(.btFootnote)
                        .foregroundStyle(.btTextSecondary)

                    Spacer()

                    difficultyDots
                }

                Text("\(drill.sets.defaultSets)组×\(drill.sets.defaultBallsPerSet)球")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }

            Spacer(minLength: 0)

            VStack {
                if drill.isPremium {
                    Image(systemName: "lock.fill")
                        .font(.btCallout)
                        .foregroundStyle(.btTextTertiary)
                } else if let onFavoriteTap {
                    Button(action: onFavoriteTap) {
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                            .font(.btCallout)
                            .foregroundStyle(isFavorited ? .btAccent : .btTextTertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private var difficultyDots: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= drill.difficulty ? Color.btPrimary : Color.btBGQuaternary)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

#Preview("Light") {
    let sample = DrillContent(
        id: "drill_c001", nameZh: "半台直线球", nameEn: "Half-Table Straight",
        category: "accuracy", subcategory: "straight", ballType: ["chinese8"],
        level: "L0", difficulty: 1, isPremium: false,
        description: "测试", coachingPoints: ["1"], standardCriteria: "15球进10球",
        sets: .init(defaultSets: 3, defaultBallsPerSet: 15),
        animation: DrillAnimation(
            cueBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.25), path: [PathPoint(x: 0.5, y: 0.45)]),
            targetBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.43), path: [PathPoint(x: 0.5, y: 0.5268)]),
            pocket: "bottomCenter", cueDirection: CanvasPoint(x: 0.5, y: 0.0)
        )
    )
    VStack(spacing: Spacing.sm) {
        BTDrillCard(drill: sample, isFavorited: false, onFavoriteTap: {})
        BTDrillCard(drill: sample, isFavorited: true, onFavoriteTap: {})
    }
    .padding()
    .background(.btBG)
}

#Preview("Dark") {
    let premium = DrillContent(
        id: "drill_c099", nameZh: "高级蛇彩清台", nameEn: "Advanced Runout",
        category: "combined", subcategory: "runout", ballType: ["chinese8"],
        level: "L3", difficulty: 4, isPremium: true,
        description: "测试", coachingPoints: ["1"], standardCriteria: "清台",
        sets: .init(defaultSets: 2, defaultBallsPerSet: 15),
        animation: DrillAnimation(
            cueBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.25), path: [PathPoint(x: 0.5, y: 0.45)]),
            targetBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.43), path: [PathPoint(x: 0.5, y: 0.5268)]),
            pocket: "bottomCenter", cueDirection: CanvasPoint(x: 0.5, y: 0.0)
        )
    )
    VStack(spacing: Spacing.sm) {
        BTDrillCard(drill: premium, isFavorited: false)
    }
    .padding()
    .background(.btBG)
    .preferredColorScheme(.dark)
}
