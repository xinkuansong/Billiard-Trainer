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
        return nil
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
