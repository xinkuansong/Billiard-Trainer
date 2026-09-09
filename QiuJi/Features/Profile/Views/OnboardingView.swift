import SwiftUI
import UIKit

/// Optional product introduction. The A2 artwork is illustrative; navigation and copy are native.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var currentPage = 0

    private static let background = Color("btIntroBackground")
    private static let foreground = Color("btIntroForeground")
    private static let rule = Color("btIntroRule")

    private struct Page {
        let title: String
        let subtitle: String
        let artwork: CGRect
        let description: String
        var caption: String? = nil
    }

    // Pixel bounds within the approved 1909 × 824 A2 storyboard. Crop only the artwork:
    // titles, paging dots and buttons are rendered natively and never baked into controls.
    private static let pages: [Page] = [
        Page(title: "看懂这一杆。", subtitle: "瞄准点与接触点，一眼看清。",
             artwork: CGRect(x: 20, y: 232, width: 342, height: 444),
             description: "瞄准点、接触点、假想球与袋口方向的关系。"),
        Page(title: "把判断，\n练成直觉。", subtitle: "先判断，再验证。",
             artwork: CGRect(x: 381, y: 289, width: 372, height: 328),
             description: "站位视角下的母球与目标球。", caption: "3D 判断训练 · Pro 功能示例"),
        Page(title: "把下一杆，\n也想清楚。", subtitle: "调整打点与力度，推演母球走位。",
             artwork: CGRect(x: 788, y: 245, width: 340, height: 437),
             description: "自由走位 Pro 功能示例：目标球进袋线与母球走位路线。", caption: "自由走位 · Pro 功能示例"),
        Page(title: "每次上台，\n都有方向。", subtitle: "跟着课程练，按自己的节奏进阶。",
             artwork: CGRect(x: 1153, y: 270, width: 362, height: 232),
             description: "横向蛇彩围8：六颗彩球在一侧排列，8号在另一侧。"),
        Page(title: "让练习，\n有迹可循。", subtitle: "记录每组结果，留住练习心得。",
             artwork: CGRect(x: 1548, y: 346, width: 345, height: 228),
             description: "示例记录：12个进球，总球15个，成功率80%；后续组尚未填写。", caption: "示例记录")
    ]

    private static let artworkImages: [UIImage?] = {
        guard let sheet = UIImage(named: "onboardingA2")?.cgImage else { return pages.map { _ in nil } }
        return pages.map { page in sheet.cropping(to: page.artwork).map { UIImage(cgImage: $0) } }
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("涨球记").font(.btHeadline)
                Spacer()
                Button("跳过") { dismiss() }
                    .font(.btSubheadline).frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("onboarding.skip")
            }
            .padding(.horizontal, Spacing.xxl)
            .frame(maxWidth: 600)

            GeometryReader { geometry in
                TabView(selection: $currentPage) {
                    ForEach(Self.pages.indices, id: \.self) { index in
                        page(index, height: geometry.size.height).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            VStack(spacing: Spacing.xs) {
                HStack(spacing: 0) {
                    ForEach(Self.pages.indices, id: \.self) { index in
                        Button { selectPage(index) } label: {
                            Circle().fill(Self.foreground.opacity(index == currentPage ? 1 : 0.3))
                                .frame(width: 8, height: 8)
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("第 \(index + 1) 页，\(Self.pages[index].title)")
                        .accessibilityAddTraits(index == currentPage ? .isSelected : [])
                        .accessibilityIdentifier("onboarding.page.\(index)")
                    }
                }
                Button(currentPage == Self.pages.count - 1 ? "开始使用" : "继续") {
                    if currentPage == Self.pages.count - 1 { dismiss() }
                    else { selectPage(currentPage + 1) }
                }
                .font(.btBodyMedium)
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(Capsule())
                .overlay(Capsule().strokeBorder(Self.rule, lineWidth: 1))
                .accessibilityIdentifier("onboarding.continue")
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, Spacing.lg)
            .frame(maxWidth: 600)
        }
        .foregroundStyle(Self.foreground)
        .tint(Self.foreground)
        .background(Self.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func page(_ index: Int, height: CGFloat) -> some View {
        let item = Self.pages[index]
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(item.title).font(.btIntroTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("onboarding.title.\(index)")
                Text(item.subtitle).font(.btSubheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.sm)
                if index == 4 { caption("示例记录") }
                if let artwork = Self.artworkImages[index] {
                    Image(uiImage: artwork).resizable().scaledToFit()
                        .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? 220 : max(160, height * 0.53))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(item.description)
                        .accessibilityIdentifier("onboarding.image.\(index)")
                }
                if index == 3 {
                    HStack {
                        Text("横向蛇彩围 8").font(.btTitle)
                        Spacer()
                        Text("L3 高级").font(.btCaption)
                    }
                    Text("彩球与8号交替击打，在两区之间练习连续走位。")
                        .font(.btSubheadline).fixedSize(horizontal: false, vertical: true)
                    Text("今日安排 · 动作精讲").font(.btFootnote)
                } else if let text = item.caption, index != 4 && index != 2 {
                    caption(text)
                }
                Spacer(minLength: Spacing.sm)
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.sm)
            .frame(maxWidth: 600)
            .frame(minHeight: height, alignment: .top)
            .frame(maxWidth: .infinity)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.btFootnote).foregroundStyle(Self.foreground.opacity(0.85))
    }

    private func selectPage(_ index: Int) {
        withAnimation(reduceMotion ? nil : BTMotion.easeInOutChrome) { currentPage = index }
    }
}

#Preview("Light") { OnboardingView() }
#Preview("Dark") { OnboardingView().preferredColorScheme(.dark) }
