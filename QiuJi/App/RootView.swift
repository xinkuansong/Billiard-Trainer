import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authState: AuthState

    var body: some View {
        if let deepLink = Self.uiTestDeepLink {
            deepLink.preferredColorScheme(.dark)
        } else if authState.hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView()
        }
    }

    /// UITest 深链（仅 launch arg 存在时生效；生产永不触发）：直接进反解页取证，
    /// 绕过 Tab 导航（SceneKit 页在 CI 冷启动导航偶发卡顿/超时）。PlanThree 的具体
    /// 场景（twoBall/twoBallDimmed/oneBall/cleared）由 `PlanThreeView.onAppear` 读同一 arg 注入。
    private static var uiTestDeepLink: AnyView? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-deeplink.silu") {
            return AnyView(NavigationStack { SiluTrainerView() })
        }
        let planThreeArgs = ["-deeplink.planThree", "-planThree.twoBallDimmed",
                             "-planThree.twoBall", "-planThree.oneBall", "-planThree.cleared"]
        if planThreeArgs.contains(where: args.contains) {
            return AnyView(NavigationStack { PlanThreeView() })
        }
        // V8 防守：具体三态盘面由 `SnookerTacticsView.onAppear` 读同一 arg 注入。
        let snookerArgs = ["-deeplink.snooker", "-snooker.full", "-snooker.partial", "-snooker.none"]
        if snookerArgs.contains(where: args.contains) {
            return AnyView(NavigationStack { SnookerTacticsView() })
        }
        // W2-9 evidence: toast chrome on a dark scene backdrop (UITest launch-arg only).
        if args.contains("-w29.toast.success") {
            return AnyView(w29ToastDemo(tone: .success, text: "已移回球库"))
        }
        if args.contains("-w29.toast.warning") {
            return AnyView(w29ToastDemo(tone: .warning, text: "按当前规则不能打 3 号球"))
        }
        if args.contains("-w29.dailyLimit") {
            return AnyView(
                ZStack {
                    Color.black.ignoresSafeArea()
                    BTDailyLimitGate {}
                        .padding(Spacing.lg)
                }
                .preferredColorScheme(.dark)
            )
        }
        if args.contains("-w29.skeleton") {
            return AnyView(
                ScrollView {
                    BTDrillListSkeleton()
                        .padding(.top, Spacing.xl)
                }
                .background(Color.btBG)
            )
        }
        if args.contains("-w29.emptyCTA") {
            return AnyView(
                BTEmptyState(
                    icon: "list.bullet.clipboard",
                    title: "还没有自定义计划",
                    subtitle: "创建你自己的训练方案",
                    actionTitle: "创建计划",
                    actionStyle: .secondary,
                    action: {}
                )
                .background(Color.btBG)
            )
        }
        return nil
    }

    private static func w29ToastDemo(tone: BTToastTone, text: String) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("场景台面（toast 取证）")
                .font(.btHeadline)
                .foregroundStyle(.white.opacity(0.35))
            BTToastBanner(message: BTToastMessage(text, tone: tone))
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Light") {
    RootView()
        .environmentObject(AuthState())
        .environmentObject(AppRouter())
        .environmentObject(SubscriptionManager.shared)
}

#Preview("Dark") {
    RootView()
        .environmentObject(AuthState())
        .environmentObject(AppRouter())
        .environmentObject(SubscriptionManager.shared)
        .preferredColorScheme(.dark)
}
