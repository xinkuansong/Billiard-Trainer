import SwiftUI

/// Approved r6 introduction. Artwork is the user's engine capture; chrome remains native.
struct OnboardingView: View {
    var onFinish: (() -> Void)? = nil
    var initialPage: Int = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0

    private static let chapters = ["瞄准", "分离角", "加塞", "走位", "清台", "训练计划与记录"]
    private static let copy = ["看清角度，瞄准更有把握。", "不同杆法，母球不同走向。",
                               "改变打点，看懂加塞走线。", "打进这一颗，留好下一杆。",
                               "选好球序，一杆接着一杆。", "练得有计划，进步有记录。"]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                IntroHeader(skipTitle: "跳过介绍", skipID: "onboarding.skip", skip: finish)
                HStack {
                    IntroBackButton { select(currentPage - 1) }
                        .opacity(currentPage == 0 ? 0 : 1).disabled(currentPage == 0)
                        .accessibilityIdentifier("onboarding.back")
                    Spacer()
                }.padding(.horizontal, 24)
                IntroPager(selection: currentPage, count: 6,
                           onSwipeForward: next, onSwipeBack: { select(currentPage - 1) }) { page in
                    VStack(spacing: 0) {
                        Text(String(format: "%02d / %@", page + 1, Self.chapters[page]))
                            .font(.btOnboardingChapter).foregroundStyle(.btPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 28)
                            .accessibilityIdentifier("onboarding.title.\(page)")
                            .accessibilityAddTraits(.isHeader)
                        GeometryReader { area in
                            ScrollView {
                                VStack(spacing: 0) {
                                    Text(Self.copy[page])
                                        .font(.btOnboardingMessage).foregroundStyle(.btText)
                                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, minHeight: max(64, area.size.height * 0.22))
                                        .padding(.horizontal, 28)
                                    IntroArtwork(page: page)
                                        .frame(maxWidth: min(area.size.width - 32, max(240, area.size.height * 0.74) * IntroArtwork.aspectRatio(page)))
                                        .frame(maxWidth: .infinity)
                                        .padding(.bottom, 12)
                                }.frame(minHeight: area.size.height, alignment: .top)
                            }
                        }
                    }
                }
                IntroProgress(count: 6, selection: currentPage)
                    .padding(.vertical, 16)
                Button(currentPage == 5 ? (onFinish == nil ? "开始使用" : "继续，认识一下你") : "继续") {
                    next()
                }
                .buttonStyle(IntroPrimaryButtonStyle())
                .accessibilityIdentifier("onboarding.continue")
                .padding(.horizontal, 28).padding(.bottom, 16)
            }
            .frame(maxWidth: 600).frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(IntroBackground())
        .preferredColorScheme(.dark)
        .onAppear { currentPage = min(5, max(0, initialPage)) }
    }

    private func next() { currentPage == 5 ? finish() : select(currentPage + 1) }

    private func select(_ page: Int) {
        guard (0..<6).contains(page) else { return }
        withAnimation(reduceMotion ? nil : BTMotion.easeInOutChrome) { currentPage = page }
    }
    private func finish() { if let onFinish { onFinish() } else { dismiss() } }
}

#Preview { OnboardingView() }
