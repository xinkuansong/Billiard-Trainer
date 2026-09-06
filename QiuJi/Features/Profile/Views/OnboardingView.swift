import SwiftUI

/// An optional, repeatable tour. Finishing never changes the current account.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0

    private struct Page {
        let title: String
        let subtitle: String
        let image: String
        let caption: String
        let detail: String
        let imageDescription: String
        var isPro = false
    }

    private let pages: [Page] = [
        Page(title: "看懂这一杆", subtitle: "看清瞄准点与接触点，理解击球方向。",
             image: "onboardingContact", caption: "瞄准点对照表",
             detail: "在练习页学习瞄准原理，拖动查看角度与瞄准点的关系。",
             imageDescription: "瞄准点对照图：目标球、假想球、瞄准点、接触点和袋口方向。"),
        Page(title: "带着方法上台练", subtitle: "先看球形与训练要点，再开始练习。",
             image: "onboardingDrill", caption: "动作详情 · 中袋直线出杆",
             detail: "跟随官方计划，或把动作加入今日安排；精讲帮助你理解每一杆。",
             imageDescription: "中袋直线出杆的球形、动作名称与训练说明。"),
        Page(title: "把下一杆，也想清楚", subtitle: "摆出球形，尝试走位，推演后续选择。",
             image: "onboardingPosition", caption: "自由走位 · Pro 功能示例",
             detail: "练习页提供思路训练；Pro 可进一步使用自由走位、多杆规划与防守工具。",
             imageDescription: "自由走位球桌：目标球进袋路线与母球走位路线。", isPro: true),
        Page(title: "练完，留下自己的记录", subtitle: "记录每组结果，也记下练习心得。",
             image: "onboardingRecord", caption: "分组记录 · 示例截图",
             detail: "进球数、训练时间与心得保存在记录中，方便回顾每一次球台练习。",
             imageDescription: "分组记录示例：第一组进球12个，总球15个，成功率80%；后续组等待录入。")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("认识球迹")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Spacer()
                Button("跳过") { dismiss() }
                    .font(.btSubheadline)
                    .foregroundStyle(.btPrimary)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("onboarding.skip")
            }
            .padding(.horizontal, Spacing.xxl)
            .frame(maxWidth: 600)

            GeometryReader { geometry in
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        page(pages[index], index: index, availableHeight: geometry.size.height).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            VStack(spacing: Spacing.sm) {
                HStack(spacing: 0) {
                    ForEach(pages.indices, id: \.self) { index in
                        Button { selectPage(index) } label: {
                            Capsule()
                                .fill(index == currentPage ? Color.btPrimary : Color.btTextTertiary)
                                .frame(width: index == currentPage ? 20 : 8, height: 8)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("第 \(index + 1) 页，\(pages[index].title)")
                        .accessibilityAddTraits(index == currentPage ? .isSelected : [])
                        .accessibilityIdentifier("onboarding.page.\(index)")
                    }
                }
                Button(currentPage == pages.count - 1 ? "开始使用" : "继续") {
                    if currentPage == pages.count - 1 { dismiss() }
                    else { selectPage(currentPage + 1) }
                }
                .buttonStyle(BTButtonStyle.primary)
                .accessibilityIdentifier("onboarding.continue")
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, Spacing.lg)
            .frame(maxWidth: 600)
        }
        .background { BTBlueprintBackground(style: .profile).ignoresSafeArea() }
    }

    private func page(_ item: Page, index: Int, availableHeight: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(item.title)
                    .font(.btTitle)
                    .foregroundStyle(.btText)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("onboarding.title.\(index)")
                Text(item.subtitle)
                    .font(.btSubheadline)
                    .foregroundStyle(.btTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Image(item.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: item.isPro ? max(160, min(400, availableHeight - 240)) : 400)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(item.imageDescription)
                    .accessibilityIdentifier("onboarding.image.\(index)")

                HStack(spacing: Spacing.sm) {
                    if item.isPro {
                        Text("PRO")
                            .font(.btCaption2)
                            .foregroundStyle(.btPremiumForeground)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.btPremiumSurface, in: Capsule())
                    }
                    Text(item.caption)
                        .font(.btFootnote)
                        .foregroundStyle(.btTextSecondary)
                }
                Text(item.detail)
                    .font(.btSubheadline)
                    .foregroundStyle(.btTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }

    private func selectPage(_ index: Int) {
        withAnimation(reduceMotion ? nil : BTMotion.easeInOutChrome) { currentPage = index }
    }
}

#Preview("Light") { OnboardingView() }
#Preview("Dark") { OnboardingView().preferredColorScheme(.dark) }
