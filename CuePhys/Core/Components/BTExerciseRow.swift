import SwiftUI

struct BTExerciseRow: View {
    enum Accessory {
        /// 进度统计 + 齿轮（默认，用于总览列表）
        case settings
        /// 进度统计 + “精讲” 提示，表明点击可查看动作教程
        case tutorial
    }

    let drillName: String
    /// F-CL-05: wire baked thumbnail when drill id is known (replaces dead animation param).
    var drillId: String? = nil
    let totalSets: Int
    let completedSets: Int
    let madeBalls: Int
    let targetBalls: Int
    var accessory: Accessory = .settings
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
            .frame(minHeight: 80)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0)
            )
            .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(BTPressableStyle.row)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(drillName), \(completedSets)/\(totalSets) 组, \(madeBalls)/\(targetBalls) 球")
        .accessibilityHint(accessory == .tutorial ? "查看动作精讲" : "")
    }

    // MARK: - Thumbnail

    private var thumbnail: some View {
        Group {
            if let drillId {
                BTDrillListThumbnail(drillId: drillId)
            } else {
                RoundedRectangle(cornerRadius: BTRadius.sm)
                    .fill(Color.btPrimaryMuted)
                    .frame(width: 90, height: 50)
                    .overlay {
                        BTTrainingIcon(size: 28, filled: true)
                    }
            }
        }
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

    /// v34 后续：一杆 = 一组后组数可达 20+，单行点阵会撑出屏幕。
    /// 按可用宽度自动换行、最多两行；超出两行容量的点不再绘制（组数以左侧「N组」文本为准）。
    private var progressDots: some View {
        DotRowsLayout(spacing: 3, maxRows: 2) {
            ForEach(0..<totalSets, id: \.self) { index in
                Circle()
                    .fill(index < completedSets ? Color.btPrimary : Color.btBGQuaternary)
                    .frame(width: 6, height: 6)
            }
        }
        .clipped()
    }

    // MARK: - Right

    private var rightInfo: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            Text("\(madeBalls)/\(targetBalls)")
                .font(.btSubheadline)
                .foregroundStyle(.btTextSecondary)

            switch accessory {
            case .settings:
                Image(systemName: BTIcon.menuCircle)
                    .font(.btFootnote14)
                    .foregroundStyle(.btTextTertiary)
            case .tutorial:
                HStack(spacing: 2) {
                    Text("精讲")
                        .font(.btCaption)
                    Image(systemName: "chevron.right")
                        .font(.btCaption2.weight(.semibold))
                }
                .foregroundStyle(.btPrimary)
            }
        }
    }
}

// MARK: - Dot Rows Layout

/// 定宽小点的换行布局：按提议宽度算每行容量，逐行排布，最多 `maxRows` 行。
/// 超出容量的子视图放到边界外（配合容器 `.clipped()` 不可见）——点阵只是进度示意，
/// 精确组数由旁边的文本承担，截断不丢信息。
private struct DotRowsLayout: Layout {
    var spacing: CGFloat = 3
    var maxRows: Int = 2

    private func metrics(subviews: Subviews, width: CGFloat) -> (dot: CGSize, perRow: Int) {
        let dot = subviews.first?.sizeThatFits(.unspecified) ?? CGSize(width: 6, height: 6)
        // 理想尺寸探测会给无限宽（Int(∞) 会崩），此时全部点排一行。
        guard width.isFinite else { return (dot, max(1, subviews.count)) }
        let step = dot.width + spacing
        let perRow = max(1, Int(((width + spacing) / step).rounded(.down)))
        return (dot, perRow)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let maxWidth = proposal.width ?? .infinity
        let (dot, perRow) = metrics(subviews: subviews, width: maxWidth)
        let rows = min(maxRows, (subviews.count + perRow - 1) / perRow)
        let widestCount = min(subviews.count, perRow)
        let width = CGFloat(widestCount) * dot.width + CGFloat(max(0, widestCount - 1)) * spacing
        let height = CGFloat(rows) * dot.height + CGFloat(max(0, rows - 1)) * spacing
        return CGSize(width: maxWidth.isFinite ? min(width, maxWidth) : width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let (dot, perRow) = metrics(subviews: subviews, width: bounds.width)
        for (index, subview) in subviews.enumerated() {
            let row = index / perRow
            let column = index % perRow
            guard row < maxRows else {
                // 超出两行容量：放到裁剪边界外隐藏。
                subview.place(
                    at: CGPoint(x: bounds.minX - 1000, y: bounds.minY - 1000),
                    proposal: ProposedViewSize(dot)
                )
                continue
            }
            subview.place(
                at: CGPoint(
                    x: bounds.minX + CGFloat(column) * (dot.width + spacing),
                    y: bounds.minY + CGFloat(row) * (dot.height + spacing)
                ),
                proposal: ProposedViewSize(dot)
            )
        }
    }
}

// MARK: - Preview

#Preview("BTExerciseRow Light") {
    VStack(spacing: Spacing.sm) {
        BTExerciseRow(
            drillName: "直线球 - 中袋",
            drillId: "drill_c006",
            totalSets: 5,
            completedSets: 3,
            madeBalls: 45,
            targetBalls: 180
        )
        BTExerciseRow(
            drillName: "斯诺克连续进攻",
            totalSets: 3,
            completedSets: 0,
            madeBalls: 0,
            targetBalls: 90
        )
        BTExerciseRow(
            drillName: "小角度带塞进袋（多组）",
            totalSets: 28,
            completedSets: 5,
            madeBalls: 40,
            targetBalls: 420
        )
    }
    .padding(Spacing.lg)
    .background(Color.btBG)
}
