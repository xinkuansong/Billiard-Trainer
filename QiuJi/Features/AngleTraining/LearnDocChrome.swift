import SwiftUI

// MARK: - Text style helpers（L1/L2；供 B2/B3 接入）

/// 文档学页正文/脚注样式口径（问题集合 v14 B1）。
///
/// - 主阅读路径：主色 `.btText` + 明确行距（参照精讲舒适度，**不**抄 items 三标签）。
/// - 脚注 / caption：次级色 `.btTextSecondary`。
enum LearnDocText {
    /// 主阅读路径行距（pt）。与 `DrillTutorialView.paragraphs` 舒适度对齐。
    static let bodyLineSpacing: CGFloat = 5

    /// 主正文：`.btBody` + `.btText` + `bodyLineSpacing`。
    static func body(_ string: String) -> some View {
        Text(string)
            .learnDocBodyStyle()
    }

    /// 脚注 / caption：`.btCaption` + `.btTextSecondary`。
    static func footnote(_ string: String) -> some View {
        Text(string)
            .learnDocFootnoteStyle()
    }
}

extension View {
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
            .foregroundStyle(.btTextSecondary)
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

#if DEBUG
#Preview("LearnDocChrome") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            LearnDocSectionCard(title: "节卡标题") {
                LearnDocText.body("主阅读路径正文：主色 + 行距。供 B2/B3 六学页接入。")
                LearnDocText.footnote("脚注 / caption：次级色，不抢主路径。")
            }
            LearnDocSectionCard(title: "次节", titleLevel: .subsection) {
                Text("也可对任意 Text 使用 .learnDocBodyStyle() / .learnDocFootnoteStyle()。")
                    .learnDocBodyStyle()
            }
        }
        .padding(Spacing.lg)
    }
    .background(Color.btBG)
}
#endif
