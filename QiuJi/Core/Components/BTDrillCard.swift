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
            .frame(maxHeight: .infinity)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }
}

// MARK: - BTDrillGridCard (2-Column Grid — DrillListView)

struct BTDrillGridCard: View {
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
        VStack(alignment: .leading, spacing: 0) {
            tableArea

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(drill.nameZh)
                    .font(.btHeadline)
                    .foregroundStyle(drill.isPremium ? .btTextTertiary : .btText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                HStack(spacing: Spacing.xs) {
                    Text(ballTypeLabel)
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)

                    Text("·")
                        .font(.btCaption)
                        .foregroundStyle(.btTextTertiary)

                    Text("推荐 \(drill.sets.defaultSets) 组")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                }
            }
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
            BTMiniTable(animation: drill.animation)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: BTRadius.md,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: BTRadius.md
                    )
                )

            LinearGradient(
                colors: [.clear, .black.opacity(0.25)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)
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
            BTLevelBadge(level: level)
                .padding(Spacing.sm)
        }
        .overlay(alignment: .topTrailing) {
            cardBadge
                .padding(Spacing.sm)
        }
    }

    @ViewBuilder
    private var cardBadge: some View {
        if drill.isPremium {
            HStack(spacing: 2) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("PRO")
                    .font(.system(size: 10, weight: .heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color.btAccent)
            .clipShape(Capsule())
        } else if let onFavoriteTap {
            Button(action: onFavoriteTap) {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isFavorited ? .btAccent : .white.opacity(0.9))
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.35))
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - BTDrillThumbnail (shared mini table or fallback icon)

struct BTDrillThumbnail: View {
    let drill: DrillContent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        BTMiniTable(animation: drill.animation)
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
    )
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
    )
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
        BTDrillGridCard(drill: previewPremium, isFavorited: false)
        BTDrillGridCard(drill: previewSample, isFavorited: true, onFavoriteTap: {})
    }
    .padding()
    .background(.btBG)
}

#Preview("Grid Card Dark") {
    let columns = [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible())]
    LazyVGrid(columns: columns, spacing: Spacing.md) {
        BTDrillGridCard(drill: previewSample, isFavorited: false, onFavoriteTap: {})
        BTDrillGridCard(drill: previewPremium, isFavorited: false)
    }
    .padding()
    .background(.btBG)
    .preferredColorScheme(.dark)
}
