import SwiftUI

struct BTExerciseRow: View {
    let drillName: String
    let thumbnailAnimation: DrillAnimation?
    let totalSets: Int
    let completedSets: Int
    let madeBalls: Int
    let targetBalls: Int
    var onTap: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                thumbnail
                centerInfo
                Spacer()
                rightInfo
            }
            .padding(Spacing.md)
            .frame(height: 80)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0)
            )
            .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(drillName), \(completedSets)/\(totalSets) 组, \(madeBalls)/\(targetBalls) 球")
    }

    // MARK: - Thumbnail

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: BTRadius.md)
                .fill(Color.btPrimaryMuted)
            Image(systemName: "figure.pool.swim")
                .font(.btTitle)
                .foregroundStyle(.btPrimary)
        }
        .frame(width: 56, height: 56)
    }

    // MARK: - Center

    private var centerInfo: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(drillName)
                .font(.btHeadline)
                .foregroundStyle(.btText)
                .lineLimit(1)

            HStack(spacing: Spacing.xs) {
                Text("\(totalSets)组")
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)

                progressDots
            }
        }
    }

    private var progressDots: some View {
        HStack(spacing: 3) {
            ForEach(0..<totalSets, id: \.self) { index in
                Circle()
                    .fill(index < completedSets ? Color.btPrimary : Color.btBGQuaternary)
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Right

    private var rightInfo: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            Text("\(madeBalls)/\(targetBalls)")
                .font(.btSubheadline)
                .foregroundStyle(.btTextSecondary)

            Image(systemName: "gearshape")
                .font(.btFootnote14)
                .foregroundStyle(.btTextTertiary)
        }
    }
}

// MARK: - Preview

#Preview("BTExerciseRow Light") {
    VStack(spacing: Spacing.sm) {
        BTExerciseRow(
            drillName: "直线球 - 中袋",
            thumbnailAnimation: nil,
            totalSets: 5,
            completedSets: 3,
            madeBalls: 45,
            targetBalls: 180
        )
        BTExerciseRow(
            drillName: "斯诺克连续进攻",
            thumbnailAnimation: nil,
            totalSets: 3,
            completedSets: 0,
            madeBalls: 0,
            targetBalls: 90
        )
        BTExerciseRow(
            drillName: "K 球走位",
            thumbnailAnimation: nil,
            totalSets: 4,
            completedSets: 3,
            madeBalls: 72,
            targetBalls: 120
        )
    }
    .padding(Spacing.lg)
    .background(Color.btBG)
}

#Preview("BTExerciseRow Dark") {
    VStack(spacing: Spacing.sm) {
        BTExerciseRow(
            drillName: "直线球 - 中袋",
            thumbnailAnimation: nil,
            totalSets: 5,
            completedSets: 3,
            madeBalls: 45,
            targetBalls: 180
        )
        BTExerciseRow(
            drillName: "斯诺克连续进攻",
            thumbnailAnimation: nil,
            totalSets: 3,
            completedSets: 0,
            madeBalls: 0,
            targetBalls: 90
        )
    }
    .padding(Spacing.lg)
    .background(Color.btBG)
    .preferredColorScheme(.dark)
}
