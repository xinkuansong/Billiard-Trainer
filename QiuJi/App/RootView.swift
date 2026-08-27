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
                    title: "还没有模版",
                    subtitle: "创建你自己的训练方案",
                    actionTitle: "新建模版",
                    actionStyle: .secondary,
                    action: {}
                )
                .background(Color.btBG)
            )
        }
        // v28 序列演示控件取证：直达试打页序列模式（动作库列表元素过多，
        // XCUI 逐卡查询在本机会 query timeout，故沿用既有深链绕过导航）。
        if let drillId = args.first(where: { $0.hasPrefix("-deeplink.tryout=") })?
            .replacingOccurrences(of: "-deeplink.tryout=", with: ""),
           let drill = DrillContentService.shared.loadFallbackDrills()
            .first(where: { $0.id == drillId }) {
            let formation = DrillTryoutBoardStore.representative(for: drillId)
            return AnyView(NavigationStack {
                PositionPlayComposerView(sourceDrill: drill, tryoutFormation: formation)
            })
        }
        // v34 W4：直达动作详情（建议训练量逐球形取证）。
        if let drillId = args.first(where: { $0.hasPrefix("-deeplink.drillDetail=") })?
            .replacingOccurrences(of: "-deeplink.drillDetail=", with: ""),
           !drillId.isEmpty {
            return AnyView(NavigationStack {
                DrillDetailView(drillId: drillId)
            })
        }
        // v34 W5：直达计划详情（逐球形剂量明细取证）。
        if let planId = args.first(where: { $0.hasPrefix("-deeplink.planDetail=") })?
            .replacingOccurrences(of: "-deeplink.planDetail=", with: ""),
           !planId.isEmpty {
            return AnyView(NavigationStack {
                PlanDetailView(planId: planId)
                    .environmentObject(SubscriptionManager.shared)
            })
        }
        // v34 W5：直达自由训练并预置一条动作（进度指示 / 分节 / 添加一组取证）。
        if let drillId = args.first(where: { $0.hasPrefix("-deeplink.activeTraining=") })?
            .replacingOccurrences(of: "-deeplink.activeTraining=", with: ""),
           !drillId.isEmpty {
            return AnyView(V34W5ActiveTrainingHost(drillId: drillId))
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

/// UITest-only host：按计划模式装载单条动作（v34 W5）。
/// 走 `loadDrills` 的 `.plan` 路径，避免自由模式预置与 `.task` 竞态。
private struct V34W5ActiveTrainingHost: View {
    @StateObject private var viewModel: ActiveTrainingViewModel
    @StateObject private var router = AppRouter()

    init(drillId: String) {
        let content = DrillContentService.decodeDrillFromBundle(id: drillId)
        let options = TrainingDoseResolver.formationOptions(forDrillId: drillId)
        let resolved = TrainingDoseResolver.resolve(content: content, formationOptions: options)
        let unit = DrillUnitLabel.label(
            category: content?.category ?? "",
            subcategory: content?.subcategory ?? ""
        )
        let item = TodayDrillItem(
            id: "uitest_\(drillId)",
            drillId: drillId,
            nameZh: content?.nameZh ?? drillId,
            phaseType: "focused",
            phaseZh: "专项训练",
            phaseIcon: "target",
            plannedSets: resolved.plannedSets,
            volumeText: resolved.volumeText(unitLabel: unit),
            isCompleted: false
        )
        _viewModel = StateObject(
            wrappedValue: ActiveTrainingViewModel(mode: .plan(drills: [item], planId: "uitest_w5"))
        )
    }

    var body: some View {
        ActiveTrainingView(viewModel: viewModel)
            .environmentObject(router)
            .environmentObject(SubscriptionManager.shared)
            .accessibilityIdentifier("v34w5ActiveTrainingHost")
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
