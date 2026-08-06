import SwiftUI

/// Shared magazine-grid card shell for Training / Drill / Practice tabs (v28 W0).
///
/// Unifies corner radius, background, dark stroke, title baseline, and meta row rhythm.
/// Cover aspect and cover content stay per-domain (D-v28-3).
struct BTContentGridCard<Cover: View, Meta: View>: View {
    let title: String
    var coverAspectRatio: CGFloat = 4.0 / 3.0
    var titleLineLimit: Int = 2
    var titleMinHeight: CGFloat? = nil
    var titleColor: Color = .btText
    @ViewBuilder var cover: () -> Cover
    @ViewBuilder var meta: () -> Meta

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(coverAspectRatio, contentMode: .fit)
                .overlay { cover() }
                .clipped()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.btHeadline)
                    .foregroundStyle(titleColor)
                    .lineLimit(titleLineLimit)
                    .truncationMode(.tail)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: titleMinHeight,
                        alignment: .topLeading
                    )

                meta()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
}

extension BTContentGridCard where Meta == EmptyView {
    init(
        title: String,
        coverAspectRatio: CGFloat = 4.0 / 3.0,
        titleLineLimit: Int = 2,
        titleMinHeight: CGFloat? = nil,
        titleColor: Color = .btText,
        @ViewBuilder cover: @escaping () -> Cover
    ) {
        self.title = title
        self.coverAspectRatio = coverAspectRatio
        self.titleLineLimit = titleLineLimit
        self.titleMinHeight = titleMinHeight
        self.titleColor = titleColor
        self.cover = cover
        self.meta = { EmptyView() }
    }
}

extension BTContentGridCard where Meta == BTContentGridCardCaption {
    /// Convenience: single-line secondary caption under the title.
    init(
        title: String,
        subtitle: String,
        coverAspectRatio: CGFloat = 4.0 / 3.0,
        titleLineLimit: Int = 2,
        titleMinHeight: CGFloat? = nil,
        titleColor: Color = .btText,
        @ViewBuilder cover: @escaping () -> Cover
    ) {
        self.title = title
        self.coverAspectRatio = coverAspectRatio
        self.titleLineLimit = titleLineLimit
        self.titleMinHeight = titleMinHeight
        self.titleColor = titleColor
        self.cover = cover
        self.meta = { BTContentGridCardCaption(text: subtitle) }
    }
}

/// Shared single-line meta caption used by the subtitle convenience initializer.
struct BTContentGridCardCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.btCaption)
            .foregroundStyle(.btTextSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

// MARK: - Three-sample baseline (W0)

#if DEBUG
#Preview("W0 Surface Grammar · Light") {
    BTContentGridCardSamples()
}

#Preview("W0 Surface Grammar · Dark") {
    BTContentGridCardSamples()
        .preferredColorScheme(.dark)
}

private struct BTContentGridCardSamples: View {
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                BTContentGridCard(
                    title: "新手入门四周",
                    subtitle: "入门 · 4 周",
                    coverAspectRatio: 1.0
                ) {
                    BTPlanCover(
                        planId: "plan_beginner",
                        targetLevel: "L0→L1",
                        issueNumber: 1,
                        mode: .list
                    )
                }

                BTContentGridCard(
                    title: "直线进袋 · 中袋",
                    coverAspectRatio: 2.0,
                    titleMinHeight: 40
                ) {
                    sampleDrillCover
                } meta: {
                    Text("已完成 · 多杆")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                        .lineLimit(1)
                }

                BTContentGridCard(
                    title: "瞄准原理",
                    subtitle: "切入角 · 假想球 · 厚薄球",
                    coverAspectRatio: 4.0 / 3.0
                ) {
                    BTPracticeCover(
                        visual: PracticeCoverCatalog.visual(for: .aimingPrinciple),
                        chip: nil
                    )
                }

                BTContentGridCard(
                    title: "2D 角度训练",
                    subtitle: "俯视真台，练几何角度判断",
                    coverAspectRatio: 4.0 / 3.0
                ) {
                    BTPracticeCover(
                        visual: PracticeCoverCatalog.visual(for: .sceneAiming2D),
                        chip: "2D"
                    )
                }
            }
            .padding(Spacing.lg)
        }
        .background(.btBG)
    }

    private var sampleDrillCover: some View {
        ZStack {
            Color.btTableFelt
            Text("2:1")
                .font(.btCaption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .btThumbnailFrame(
            cornerRadius: BTRadius.md,
            topCornersOnly: true,
            showsStroke: false,
            colorScheme: colorScheme
        )
        .overlay(alignment: .topLeading) {
            BTLevelBadge(level: .L1, onDarkSurface: true)
                .padding(Spacing.sm)
        }
    }
}
#endif
