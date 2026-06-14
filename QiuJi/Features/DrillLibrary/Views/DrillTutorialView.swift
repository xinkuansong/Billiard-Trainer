import SwiftUI
import UIKit

/// 运行时加载图文精讲配图（`Resources/DrillTutorials/<name>.png`）。内存缓存，缺图回退占位。
enum DrillTutorialImageStore {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(named name: String) -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png",
                                        subdirectory: "DrillTutorials"),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        cache.setObject(image, forKey: name as NSString)
        return image
    }
}

struct DrillTutorialView: View {
    let drill: DrillContent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header
                
                if let tutorial = drill.tutorial {
                    ForEach(Array(tutorial.sections.enumerated()), id: \.offset) { index, section in
                        sectionCard(section, index: index)
                    }
                }
            }
            .padding(.bottom, Spacing.xxl)
        }
        .background(.btBG)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("精讲")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Text(DrillCategory(rawValue: drill.category)?.nameZh ?? drill.category)
                    .font(.btCaption2)
                    .foregroundStyle(.btPrimary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 3)
                    .background(.btPrimary.opacity(0.12))
                    .clipShape(Capsule())

                BTLevelBadge(level: DrillLevel(rawValue: drill.level) ?? .L0)
            }

            Text(drill.nameZh)
                .font(.btTitle)
                .foregroundStyle(.btText)

            Text(drill.description)
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    // MARK: - Section Card

    private static let sectionIcons: [String: String] = [
        "技术原理": "lightbulb.fill",
        "动作要领": "scope",
        "常见错误与纠正": "exclamationmark.triangle.fill",
        "进阶练习": "arrow.up.right.circle.fill",
    ]

    private static let sectionColors: [String: Color] = [
        "技术原理": .blue,
        "动作要领": .btPrimary,
        "常见错误与纠正": .orange,
        "进阶练习": .purple,
    ]

    /// 条目标签配色（ADR-P11-15「应用课」模板：为什么/怎么打/自检；其余标签用中性色）。
    private static let itemLabelColors: [String: Color] = [
        "为什么": .blue,
        "怎么打": .btPrimary,
        "自检": .orange,
    ]

    private func sectionCard(_ section: TutorialSection, index: Int) -> some View {
        let icon = Self.sectionIcons[section.title] ?? "doc.text.fill"
        let accentColor = Self.sectionColors[section.title] ?? .btPrimary

        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.btFootnote14)
                    .foregroundStyle(accentColor)
                    .frame(width: 28, height: 28)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Circle())

                Text(section.title)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
            }

            if !section.content.isEmpty {
                paragraphs(section.content)
            }

            if let params = section.params {
                paramsRow(params)
            }

            if let items = section.items {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(items) { item in
                        itemRow(item)
                    }
                }
            }

            if let imageName = section.image,
               let uiImage = DrillTutorialImageStore.image(named: imageName) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: BTRadius.sm)
                                .stroke(.btSeparator, lineWidth: 0.5)
                        )
                    if let caption = section.caption {
                        Text(caption)
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Section building blocks

    /// 正文：按空行分段渲染，段内支持 inline markdown（**加粗** 等）。
    private func paragraphs(_ content: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(content.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, para in
                Text(Self.inlineMarkdown(para))
                    .font(.btCallout)
                    .foregroundStyle(.btText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(5)
            }
        }
    }

    private static func inlineMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }

    /// 「标签 + 正文」条目行：彩色小标签胶囊 + 段落。
    private func itemRow(_ item: TutorialItem) -> some View {
        let color = Self.itemLabelColors[item.label] ?? Color.btTextSecondary
        return HStack(alignment: .top, spacing: Spacing.sm) {
            Text(item.label)
                .font(.btCaption2)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 3)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
                .padding(.top, 1)

            Text(Self.inlineMarkdown(item.text))
                .font(.btCallout)
                .foregroundStyle(.btText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(5)
        }
    }

    /// 击球参数行：打点小图标（真实比例，与导出 HUD 同口径）+ 打点读数 + 力度胶囊。
    private func paramsRow(_ params: TutorialShotParams) -> some View {
        HStack(spacing: Spacing.sm) {
            BTSpinMiniIcon(spinX: params.spinX, spinY: params.spinY,
                           diameter: 40, trueScale: true)

            paramChip(SpinDisplay.readout(spinX: params.spinX, spinY: params.spinY))
            paramChip("\(PowerDisplay.name(params.velocity)) · \(String(format: "%.1f", params.velocity)) m/s")

            Spacer(minLength: 0)
        }
    }

    private func paramChip(_ text: String) -> some View {
        Text(text)
            .font(.btCaption)
            .monospacedDigit()
            .foregroundStyle(.btText)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(.btBGTertiary)
            .clipShape(Capsule())
    }
}

#Preview("Light") {
    NavigationStack {
        DrillTutorialView(drill: DrillContent(
            id: "drill_c001",
            nameZh: "半台直线球",
            nameEn: "Half-Table Straight Shot",
            category: "accuracy",
            subcategory: "straight",
            ballType: ["chinese8"],
            level: "L0",
            difficulty: 1,
            isPremium: false,
            description: "将目标球从半台距离沿直线打入下中袋，训练基础瞄准稳定性与出杆方向。",
            coachingPoints: ["保持出杆方向与瞄准线严格一致"],
            standardCriteria: "15球进10球",
            sets: .init(defaultSets: 3, defaultBallsPerSet: 15),
            animation: DrillAnimation(
                cueBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.25), path: []),
                targetBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.43), path: []),
                pocket: "bottomCenter",
                cueDirection: CanvasPoint(x: 0.5, y: 0.0)
            ),
            tutorial: DrillTutorial(sections: [
                TutorialSection(title: "技术原理", content: "示例内容"),
                TutorialSection(title: "动作要领", content: "示例内容"),
                TutorialSection(title: "常见错误与纠正", content: "示例内容"),
                TutorialSection(title: "进阶练习", content: "示例内容"),
            ])
        ))
    }
}
