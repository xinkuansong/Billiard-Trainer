import SwiftUI

// MARK: - Page header

/// 球理详情页页头（v30 W1；组件规范 §二，返工 r1 视觉收敛）。
///
/// 收敛口径：整卡就是一张普通 `LearnDocSectionCard` —— 结论主句当卡标题（`.btTitle`，
/// 与 `AimingPrincipleView.termsSection` 等现有学页首卡同层级），结论后半句走
/// `LearnDocText.body`，适用边界走 `LearnDocText.footnote`。⛔ 不再另立字号体系。
///
/// 编号 chip 保留（数据标签，产品要求），但只作**页面标识**：⛔ 不进正文句子
///（v30 红线 3），且对读屏隐藏，避免朗读出「T03」这种内部标签。
struct TheoryPageHeader: View {
    let pageID: TheoryPageID
    /// 结论主句 = 卡标题。取材 vendored `theorem-tags.json` 的 `statement_one_liner`，
    /// 允许口语化转写（禁造新断言），改动点记在转写模板的取舍对照表里。
    let headline: String
    /// 结论剩余部分（原一句话结论的后半句），正文级。
    var detail: String?
    /// 一行适用边界预告（可选），脚注级。
    var caption: String?

    init(pageID: TheoryPageID, headline: String, detail: String? = nil, caption: String? = nil) {
        self.pageID = pageID
        self.headline = headline
        self.detail = detail
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let number = pageID.theoremId {
                Text(number)
                    .font(.btMicro.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.btTextTertiary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Color.btBGTertiary, in: Capsule())
                    .accessibilityHidden(true)
            }

            LearnDocSectionCard(title: headline) {
                if let detail, !detail.isEmpty {
                    LearnDocText.body(detail)
                }
                if let caption, !caption.isEmpty {
                    LearnDocText.footnote(caption)
                }
            }
        }
        .accessibilityIdentifier("theoryHeader_\(pageID.rawValue)")
    }
}

// MARK: - Mistake card

/// 「常见误区」卡（组件规范 §五）：每篇必有一张，放正文末、页尾互链区之前。
///
/// 取材 `theorem-tags.json.<T>.common_errors`（速记短语 → 展开成人话）；
/// ⛔ 不得新增 contracts / 16 原文里没有的误区。
///
/// 视觉口径（v56）：逐条对齐现有学页误区旁注范式 —— `.btWarning` 三角 +
/// 10% accent 底 + `BTRadius.sm`（真源 `AimingPrincipleView` §名词系统旁注）。
struct TheoryMistakeCard: View {
    struct Mistake: Identifiable {
        let id = UUID()
        /// 常见的错误说法 / 错误做法。
        let wrong: String
        /// 为什么错、正确说法是什么。
        let right: String
    }

    let mistakes: [Mistake]

    var body: some View {
        LearnDocSectionCard(title: "常见误区") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(mistakes) { mistake in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.btWarning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mistake.wrong)
                                .font(.btSubheadlineMedium)
                                .foregroundStyle(.btText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(mistake.right)
                                .learnDocFootnoteStyle()
                        }
                    }
                    .padding(Spacing.md)
                    .background(Color.btWarning.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                }
            }
        }
    }
}

// MARK: - Numbered list

/// 序号清单（组件规范 §三「步骤 / 层级 / 清单」）：原生 badge + 文字，不做图片。
///
/// 用于三问清单（T08）、安全球层级（T10）、5 步流程（W4）。
/// 序号圆底口径（返工 r1）：`Color.btPrimary` 实底 + 白字 + 18pt 圆，
/// 与现有学页 `AimingPrincipleView.derivationStep` 一致。
struct TheoryNumberedList: View {
    struct Step: Identifiable {
        let id = UUID()
        let title: String
        var detail: String?

        init(_ title: String, detail: String? = nil) {
            self.title = title
            self.detail = detail
        }
    }

    let steps: [Step]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text("\(index + 1)")
                        .font(.btCaption2)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.btPrimary, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.btSubheadlineMedium)
                            .foregroundStyle(.btText)
                            .fixedSize(horizontal: false, vertical: true)
                        if let detail = step.detail, !detail.isEmpty {
                            Text(detail)
                                .learnDocBodyStyle()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Matrix table

/// 矩阵 / 阈值表（组件规范 §三「矩阵 / 阈值表」）：原生行，不做图片。
///
/// 视觉口径（返工 r1）：对齐现有学页 `ContactPointTableView` 对照表范式 ——
/// `HStack` 行 + `.btCaption2` 表头行（`.btBGTertiary` 底）+ 斑马行 + `BTRadius.md` 裁切。
/// ⛔ 不再用 `Grid`（列宽与现有表格观感不同族）。
struct TheoryMatrixTable: View {
    struct Row: Identifiable {
        let id = UUID()
        let label: String
        let cells: [String]

        init(_ label: String, _ cells: [String]) {
            self.label = label
            self.cells = cells
        }
    }

    /// 首列之外的列名（首列表头恒为空——行名列不需要标题）。
    let columnTitles: [String]
    let rows: [Row]
    /// 行名列宽（pt）。行名较长的表可放宽。
    var labelWidth: CGFloat = 72

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                tableRow(row, isOdd: index.isMultiple(of: 2) == false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text("")
                .font(.btCaption2)
                .frame(width: labelWidth, alignment: .leading)
            ForEach(columnTitles, id: \.self) { title in
                Text(title)
                    .font(.btCaption2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(.btTextSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(.btBGTertiary)
    }

    private func tableRow(_ row: Row, isOdd: Bool) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(row.label)
                .font(.btCaption.weight(.semibold))
                .foregroundStyle(.btTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: labelWidth, alignment: .leading)
            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                Text(cell)
                    .font(.btSubheadline)
                    .foregroundStyle(.btText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(isOdd ? Color.btBGTertiary.opacity(0.5) : Color.clear)
    }
}

// MARK: - Page shell

extension View {
    /// 球理详情页页级壳（组件规范 §一）：与现有 9 张学页同一套外壳，勿另发明。
    func theoryPageChrome(title: String) -> some View {
        self
            .background(.btBG)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
    }
}

#if DEBUG
#Preview("TheoryPageChrome") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            TheoryPageHeader(
                pageID: .t03,
                headline: "碰撞那一瞬间，母球总是先沿切线走",
                detail: "之后偏不偏、偏多少，取决于它此刻带着什么旋转。",
                caption: "切线 = 过两球接触点、垂直于两球连心线的方向。"
            )
            LearnDocSectionCard(title: "三问") {
                TheoryNumberedList(steps: [
                    .init("进得了吗？", detail: "把握不够就别开打。"),
                    .init("走得到位吗？"),
                ])
            }
            LearnDocSectionCard(title: "阈值") {
                TheoryMatrixTable(
                    columnTitles: ["新手", "进阶", "高手"],
                    rows: [.init("进球把握", ["80%", "65%", "50%"])]
                )
            }
            TheoryMistakeCard(mistakes: [
                .init(wrong: "把切线当母球最终方向", right: "只有滑动状态下两者才重合。")
            ])
        }
        .padding(Spacing.lg)
    }
    .background(Color.btBG)
}
#endif
