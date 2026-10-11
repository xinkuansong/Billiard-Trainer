import SwiftUI

// MARK: - Text style helpers（L1/L2；供 B2/B3 接入）

/// 文档学页正文/脚注样式口径（问题集合 v14 B1）。
///
/// - 主阅读路径：主色 `.btText` + 明确行距（参照精讲舒适度，**不**抄 items 三标签）。
/// - 脚注 / caption：保留较小字号层级，必要说明使用 `.btText`。
enum LearnDocText {
    /// 主阅读路径行距（pt）。与 `DrillTutorialView.paragraphs` 舒适度对齐。
    static let bodyLineSpacing: CGFloat = 5

    /// 主正文：`.btBody` + `.btText` + `bodyLineSpacing`。
    static func body(_ string: String) -> some View {
        Text(string)
            .learnDocBodyStyle()
    }

    /// 脚注 / caption：`.btCaption` + `.btText`。
    static func footnote(_ string: String) -> some View {
        Text(string)
            .learnDocFootnoteStyle()
    }
}

private struct LearnReadingNavigation: ViewModifier {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.btBG, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).font(.btHeadline).foregroundStyle(.btText)
                }
            }
            .toolbar(.hidden, for: .tabBar)
    }
}

extension View {
    /// Keep reading navigation independent of the diagram scrolling underneath.
    func learnReadingNavigation(title: String) -> some View {
        modifier(LearnReadingNavigation(title: title))
    }

    /// About forty Chinese body characters per line on tablets; narrow pages use
    /// their full available width. Apply inside ScrollView so scrolling stays full-width.
    func learnDocumentWidth() -> some View {
        frame(maxWidth: 720).frame(maxWidth: .infinity)
    }

    /// 文档学页主阅读路径样式。
    func learnDocBodyStyle() -> some View {
        self
            .font(.btBody)
            .foregroundStyle(.btText)
            .lineSpacing(LearnDocText.bodyLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 文档学页脚注 / caption 样式。
    func learnDocFootnoteStyle() -> some View {
        self
            .font(.btCaption)
            .foregroundStyle(.btText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Section card

/// 文档学页可复用节卡容器（问题集合 v14 B1 / L1）。
///
/// 口径：内边距 `Spacing.lg`、圆角 `BTRadius.lg`、背景 `.btBGSecondary`；
/// 标题用主色；内容由调用方注入（本批不改六页业务文案）。
struct LearnDocSectionCard<Content: View>: View {
    enum TitleLevel {
        /// 节级大标题（`.btTitle`）。
        case section
        /// 次节标题（`.btHeadline`）。
        case subsection

        var font: Font {
            switch self {
            case .section: return .btTitle
            case .subsection: return .btHeadline
            }
        }
    }

    var title: String?
    var titleLevel: TitleLevel
    @ViewBuilder var content: () -> Content

    init(
        title: String? = nil,
        titleLevel: TitleLevel = .section,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.titleLevel = titleLevel
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(titleLevel.font)
                    .foregroundStyle(.btText)
            }
            content()
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }
}

// MARK: - Formula nest（D-v14-5：公式/速查视觉降级）

/// 公式 / 推导 / 速查次级收拢区（问题集合 v14 B3 / D-v14-5）。
///
/// 口径：`.btBGTertiary` + caption 级标题；默认不做 Disclosure。
/// 用于不与「名词 / 切角」等主节卡同级抢阅读权重；**不删**公式内容。
struct LearnDocFormulaNest<Content: View>: View {
    var title: String?
    @ViewBuilder var content: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.btCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.btText)
            }
            content()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btBGTertiary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }
}

// MARK: - Light cross-link（D-v14-6：超出 PracticeCTA 大卡配额时用）

/// 学页轻量互链：文字行 NavigationLink，不占大卡配额。
struct LearnDocTextLink: View {
    let title: String
    let subtitle: String?
    let route: AngleRoute

    init(title: String, subtitle: String? = nil, route: AngleRoute) {
        self.title = title
        self.subtitle = subtitle
        self.route = route
    }

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.btSubheadlineMedium)
                        .foregroundStyle(.btPrimary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.btCaption)
                            .foregroundStyle(.btText)
                    }
                }
                Spacer()
                Image(systemName: BTIcon.chevronRight)
                    .font(.btCaption.weight(.semibold))
                    .foregroundStyle(.btTextTertiary)
            }
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        }
        .buttonStyle(BTPressableStyle.row)
        .accessibilityLabel(title)
    }
}

#if DEBUG
#Preview("LearnDocChrome") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            LearnDocSectionCard(title: "节卡标题") {
                LearnDocText.body("主阅读路径正文：主色 + 行距。供 B2/B3 六学页接入。")
                LearnDocText.footnote("脚注 / caption：较小字号保留层级，文字清晰可读。")
            }
            LearnDocSectionCard(title: "次节", titleLevel: .subsection) {
                Text("也可对任意 Text 使用 .learnDocBodyStyle() / .learnDocFootnoteStyle()。")
                    .learnDocBodyStyle()
            }
            LearnDocFormulaNest(title: "公式速查（次级）") {
                LearnDocText.footnote("d = 2R × sin(θ) — caption 区，不压主阅读。")
            }
        }
        .padding(Spacing.lg)
    }
    .background(Color.btBG)
}
#endif
