import SwiftUI

/// 球理索引页（问题集合 v30 W0）：把 12 篇球理按四个主题分组列出。
///
/// - 视觉沿现有学页规范（`LearnDocChrome` 家族 + `.btBG` 页底 + inline 标题）。
/// - **全量列 12 条**（主控裁定）：未在 `MainTabView.theoryDestination` 注册的条目
///   置灰 + 标「即将上线」+ 不可点，避免死链。v30 W4 起 12 条**全部上线**，
///   置灰分支目前无条目命中，但保留给后续新增页（如固定解模块批）。
/// - 正文内容不在本页：每条详情页由 W1–W4 逐页新建并注册。
struct TheoryIndexView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                introSection

                ForEach(TheoryCatalog.groupedEntries, id: \.group) { group, entries in
                    groupSection(group, entries: entries)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xxxxl)
        }
        .background(.btBG)
        .navigationTitle("球理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Intro

    private var introSection: some View {
        LearnDocSectionCard(title: "怎么用这一栏") {
            LearnDocText.body("这里按主题排好了打球时真正会用到的球理：先看碰撞与瞄准，母球碰到目标球以后往哪走；再看杆法与力度如何改写走位；最后是选球与安全球的决策。每篇都给一句话结论、直觉解释、适用边界和常见误区。")
            // 12 条全部上线后不再提「即将上线」（否则是无所指的空洞说明）。
            if TheoryCatalog.entries.contains(where: { !$0.isPublished }) {
                LearnDocText.footnote("标「即将上线」的条目正在制作中，暂时点不开。")
            }
        }
    }

    // MARK: - Group

    private func groupSection(_ group: TheoryGroup, entries: [TheoryIndexEntry]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: group.systemImage)
                    .font(.btSubheadline)
                    .foregroundStyle(.btPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.rawValue)
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                    Text(group.caption)
                        .learnDocFootnoteStyle()
                }
            }

            VStack(spacing: Spacing.sm) {
                ForEach(entries) { entry in
                    row(entry)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("theoryGroup_\(group.rawValue)")
    }

    @ViewBuilder
    private func row(_ entry: TheoryIndexEntry) -> some View {
        if entry.isPublished {
            LearnDocTextLink(
                title: entry.title,
                subtitle: entry.subtitle,
                route: .theoryPage(entry.id)
            )
            .accessibilityIdentifier("theoryEntry_\(entry.id.rawValue)")
        } else {
            upcomingRow(entry)
                .accessibilityIdentifier("theoryEntryUpcoming_\(entry.id.rawValue)")
        }
    }

    /// 未上线条目：置灰、标「即将上线」、**不是** Button/NavigationLink（点不动）。
    private func upcomingRow(_ entry: TheoryIndexEntry) -> some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btTextTertiary)
                Text(entry.subtitle)
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.sm)
            Text("即将上线")
                .font(.btMicro.weight(.semibold))
                .foregroundStyle(.btTextTertiary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 2)
                .background(Color.btBGTertiary, in: Capsule())
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btBGSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title)，即将上线")
    }
}

// v30 W4：12 篇全部上线后，兜底页 `TheoryPagePlaceholderView` 已无任何引用，随本批删除。
// 未上线条目的置灰行（`upcomingRow`）保留——新增 id 时仍走「置灰不可点」而非死链。

#Preview("Light") {
    NavigationStack {
        TheoryIndexView()
    }
}

#Preview("Dark") {
    NavigationStack {
        TheoryIndexView()
    }
    .preferredColorScheme(.dark)
}
