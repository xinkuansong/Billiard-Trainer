import SwiftUI
import Photos

struct RootView: View {
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var ownerContext: CurrentOwnerContext
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        if let deepLink = Self.uiTestDeepLink {
            deepLink.preferredColorScheme(Self.uiTestDeepLinkColorScheme)
        } else if authState.isLoading {
            AuthLaunchView()
        } else if authState.hasCompletedOnboarding {
            MainTabView(ownerKey: ownerContext.ownerKey)
                .id(ownerContext.ownerKey)
                .preferredColorScheme(mainColorScheme)
        } else {
            OnboardingView()
        }
    }

    /// 测试显式覆盖 > 用户设备偏好 > 系统外观。
    private var mainColorScheme: ColorScheme? {
        Self.resolvedColorScheme(testOverride: Self.uiTestMainColorScheme,
                                 mode: preferences.appearanceMode)
    }

    static func resolvedColorScheme(testOverride: ColorScheme?, mode: AppearanceMode) -> ColorScheme? {
        if let testOverride { return testOverride }
        switch mode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// v49 卡片取证专用：仅显式 Light 参数覆盖主 Tab；生产继续跟随系统外观。
    private static var uiTestMainColorScheme: ColorScheme? {
        ProcessInfo.processInfo.arguments.contains("-v49.forceLight") ? .light : nil
    }

    /// UI 取证深链历史上默认强制 Dark；v49 可显式强制 Light，v51 响应式矩阵则
    /// 跟随 `simctl ui appearance`，保证证据目录标注的 Light / Dark 与实际渲染一致。
    /// 这些参数只存在于测试启动路径，不改变生产外观策略。
    private static var uiTestDeepLinkColorScheme: ColorScheme? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-v49.forceLight") { return .light }
        if args.contains("-v54.forceLight") { return .light }
        if args.contains("-v54.forceDark") { return .dark }
        if args.contains("-v51.followSystemAppearance") { return nil }
        return .dark
    }

    /// UITest 深链（仅 launch arg 存在时生效；生产永不触发）：直接进反解页取证，
    /// 绕过 Tab 导航（SceneKit 页在 CI 冷启动导航偶发卡顿/超时）。PlanThree 的具体
    /// 场景（twoBall/twoBallDimmed/oneBall/cleared）由 `PlanThreeView.onAppear` 读同一 arg 注入。
    private static var uiTestDeepLink: AnyView? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-v50.photoPermissionProbe") {
            return AnyView(V50PhotoPermissionProbeView())
        }
        if args.contains("-deeplink.silu") {
            return AnyView(NavigationStack { SiluTrainerView() })
        }
        if args.contains("-deeplink.freePlay") {
            return AnyView(NavigationStack { FreePlayView() })
        }
        if args.contains("-deeplink.dailyClearance") {
            return AnyView(NavigationStack { FreePlayView(entryMode: .dailyClearance) })
        }
        if args.contains("-deeplink.settings") {
            return AnyView(NavigationStack { SettingsView() })
        }
        // v51 simulator matrix: phone sign-in is intentionally unavailable from the
        // production login sheet, but the retained form still needs compact/iPad/Dark
        // responsive coverage. This route is launch-argument-only and cannot be
        // reached in a normal App launch.
        if args.contains("-v51.phoneLoginPreview") {
            return AnyView(PhoneLoginView())
        }
        if args.contains("-v51.activeTraining") {
            return AnyView(V34W5ActiveTrainingHost(drillId: "drill_c001"))
        }
        if args.contains("-v51.minimizedTraining") {
            return AnyView(V51MinimizedTrainingHost(elapsedSeconds: v51ElapsedSeconds(args)))
        }
        if args.contains("-v51.componentProbe") {
            return AnyView(V51ResponsiveComponentProbe())
        }
        if args.contains(where: { $0.hasPrefix("-v54.todayState=") }) {
            return AnyView(
                NavigationStack { TrainingHomeView() }
                    .environmentObject(SubscriptionManager.shared)
            )
        }
        if let sourceState = args.first(where: { $0.hasPrefix("-v54.historySource=") })?
            .replacingOccurrences(of: "-v54.historySource=", with: ""),
           !sourceState.isEmpty {
            return AnyView(V54HistorySourceFixtureHost(sourceState: sourceState))
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

    fileprivate static func v51ElapsedSeconds(_ args: [String]) -> Int {
        let raw = args.first(where: { $0.hasPrefix("-v51.elapsedSeconds=") })?
            .replacingOccurrences(of: "-v51.elapsedSeconds=", with: "")
        return max(0, Int(raw ?? "") ?? 6)
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

/// v54 frozen-provenance evidence host. It creates one isolated in-memory
/// session only when a UI-test launch argument is present; production startup
/// and persisted stores cannot reach this path.
private struct V54HistorySourceFixtureHost: View {
    let sourceState: String

    @Environment(\.modelContext) private var modelContext
    @State private var sessionID: UUID?

    var body: some View {
        NavigationStack {
            if let sessionID {
                TrainingDetailView(sessionId: sessionID)
            } else {
                ProgressView("正在准备训练记录…")
            }
        }
        .task {
            guard sessionID == nil else { return }
            let session = TrainingSession()
            session.totalDurationMinutes = 38
            session.sourcePayloadVersion = 1
            session.sourceTitleSnapshot = sourceState == "official"
                ? "中袋直线出杆与底袋直线出杆" : "赛前热身模版"
            session.sourceSubtitleSnapshot = sourceState == "official" ? "基本功 · 第 1 阶段" : nil
            if sourceState == "official" {
                session.planId = "plan_beginner"
                session.sourceKind = TodayScheduleSourceKind.officialLesson
                session.sourceParentId = "plan_beginner"
                session.sourceId = "plan_beginner.stage01.lesson01"
                session.lessonId = "plan_beginner.stage01.lesson01"
            } else {
                session.sourceKind = TodayScheduleSourceKind.template
                session.sourceId = UUID().uuidString
            }

            let entry = DrillEntry(drillId: "drill_c012", drillNameZh: "中袋直线球")
            entry.sets = [DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 7)]
            session.drillEntries = [entry]
            modelContext.insert(session)
            try? modelContext.save()
            sessionID = session.id
        }
    }
}

private struct AuthLaunchView: View {
    var body: some View {
        ZStack {
            Color.btBG.ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                BTBrandLogo(size: 72)
                ProgressView("正在恢复账号…")
                    .tint(.btPrimary)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .accessibilityIdentifier("auth.launching")
    }
}

/// v50 模拟器权限矩阵专用探针。只有显式 UI 测试启动参数才可到达，生产导航
/// 没有入口；请求仍由宿主 App 真实调用 Photos API，以便验证系统弹框和最终状态。
private struct V50PhotoPermissionProbeView: View {
    @State private var status = Self.label(
        for: PHPhotoLibrary.authorizationStatus(for: .addOnly)
    )

    var body: some View {
        VStack(spacing: 24) {
            Text("相册权限探针")
                .font(.title.bold())
            Text(status)
                .accessibilityIdentifier("v50.photoPermission.status")
            Button("请求相册权限") {
                Task {
                    let updated = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                    status = Self.label(for: updated)
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("v50.photoPermission.request")
        }
        .padding()
    }

    private static func label(for status: PHAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "相册权限：未决定"
        case .restricted: return "相册权限：受限制"
        case .denied: return "相册权限：已拒绝"
        case .authorized, .limited: return "相册权限：已允许"
        @unknown default: return "相册权限：未知"
        }
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
            .onAppear {
                viewModel.elapsedSeconds = RootView.v51ElapsedSeconds(ProcessInfo.processInfo.arguments)
            }
    }
}

/// v51 响应式矩阵入口：直接装载“已最小化训练 + 五 Tab”，避免依赖计时等待和点按竞态。
/// 仅显式测试参数可达，生产启动路径不变。
private struct V51MinimizedTrainingHost: View {
    let elapsedSeconds: Int
    @StateObject private var router = AppRouter()
    @StateObject private var viewModel: ActiveTrainingViewModel

    init(elapsedSeconds: Int) {
        self.elapsedSeconds = elapsedSeconds
        let drillId = "drill_c001"
        let content = DrillContentService.decodeDrillFromBundle(id: drillId)
        let options = TrainingDoseResolver.formationOptions(forDrillId: drillId)
        let resolved = TrainingDoseResolver.resolve(content: content, formationOptions: options)
        let unit = DrillUnitLabel.label(
            category: content?.category ?? "",
            subcategory: content?.subcategory ?? ""
        )
        let item = TodayDrillItem(
            id: "v51_minimized_\(drillId)",
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
            wrappedValue: ActiveTrainingViewModel(
                mode: .plan(drills: [item], planId: "v51_minimized_fixture")
            )
        )
    }

    var body: some View {
        MainTabView(ownerKey: "preview-owner")
            .environmentObject(router)
            .onAppear {
                guard router.minimizedTrainingVM == nil else { return }
                viewModel.elapsedSeconds = elapsedSeconds
                router.minimizeTraining(viewModel)
            }
    }
}

/// v51 响应式组件探针：用真实共享组件验证球库、长状态与 AX Chip 可达性。
/// 仅 UI 测试启动参数可达，不进入生产导航或持久化流程。
private struct V51ResponsiveComponentProbe: View {
    @State private var selectedChip = 0
    @State private var lastTappedBall = "none"

    private let longStatus = "第 12 个候选解 · 右上角袋 · 两库反射后保留完整状态语义"

    var body: some View {
        GeometryReader { proxy in
            let paletteWidth = ShotStageMetrics.paletteWidth(sceneSize: proxy.size)
            VStack(spacing: Spacing.xl) {
                BTSolverNavStatus(
                    title: "响应式组件探针",
                    statusText: longStatus
                )

                BTChipRow(
                    options: ["落区", "落点", "过点", "摆球"],
                    selection: $selectedChip,
                    scrollable: false
                )
                .frame(maxWidth: min(280, proxy.size.width - Spacing.xxl))

                BTReferenceBallPalette(
                    ballDiameter: ShotStageMetrics.paletteDiameter(sceneSize: proxy.size),
                    libraryWidth: paletteWidth,
                    isOnTable: { _ in false },
                    onTap: { key, _ in lastTappedBall = key }
                )

                Text("最后点击：\(lastTappedBall)")
                    .font(.btFootnote)
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("v51.probe.lastTap")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, Spacing.xxxl)
        }
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
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
