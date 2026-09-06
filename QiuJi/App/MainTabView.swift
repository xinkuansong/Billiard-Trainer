import SwiftUI

struct MainTabView: View {
    let ownerKey: String
    @EnvironmentObject private var router: AppRouter
    @State private var tabBarBottomClearance: CGFloat = 0

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.trainingPath) {
                TrainingHomeView(ownerKey: ownerKey)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: TrainingRoute.self) { route in
                        trainingDestination(for: route)
                    }
            }
                .tabItem {
                    if let trainingIcon = BTTrainingIcon.renderForTabBar(
                        filled: router.selectedTab == .training
                    ) {
                        Label {
                            Text(AppTab.training.title)
                        } icon: {
                            Image(uiImage: trainingIcon)
                        }
                    } else {
                        Label(AppTab.training.title, systemImage: "circle")
                    }
                }
                .tag(AppTab.training)

            NavigationStack(path: $router.drillLibraryPath) {
                DrillListView(ownerKey: ownerKey)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: String.self) { drillId in
                        DrillDetailView(drillId: drillId, ownerKey: ownerKey)
                    }
            }
                .tabItem {
                    systemTabLabel(for: .drillLibrary)
                }
                .tag(AppTab.drillLibrary)

            NavigationStack(path: $router.anglePath) {
                AngleHomeView()
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: AngleRoute.self) { route in
                        angleDestination(for: route)
                    }
            }
                .tabItem {
                    Label(AppTab.angle.title, systemImage: AppTab.angle.icon)
                }
                .tag(AppTab.angle)

            NavigationStack(path: $router.historyPath) {
                HistoryCalendarView(ownerKey: ownerKey)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: HistoryRoute.self) { route in
                        historyDestination(for: route)
                    }
            }
                .tabItem {
                    Label(AppTab.history.title, systemImage: AppTab.history.icon)
                }
                .tag(AppTab.history)

            ProfileView(ownerKey: ownerKey)
                .tabItem {
                    systemTabLabel(for: .profile)
                }
                .tag(AppTab.profile)
        }
        .background(
            BTTabBarFrameReader(bottomClearance: $tabBarBottomClearance)
                .frame(width: 0, height: 0)
        )
        .overlay(alignment: .bottomTrailing) {
            if let vm = router.minimizedTrainingVM {
                MinimizedTrainingChrome(viewModel: vm) {
                    router.resumeMinimizedTraining()
                }
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, tabBarBottomClearance + Spacing.sm)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity),
                        removal: .opacity
                    )
                )
                .animation(BTMotion.springPanel, value: router.isTrainingMinimized)
            }
        }
        .fullScreenCover(item: $router.activeTrainingMode) {
            router.onTrainingDismissed()
            NotificationCenter.default.post(name: .didDismissActiveTraining, object: nil)
        } content: { _ in
            if let vm = router.activeTrainingVM {
                ActiveTrainingView(viewModel: vm)
            }
        }
    }

    @ViewBuilder
    private func systemTabLabel(for tab: AppTab) -> some View {
        let symbolName = router.selectedTab == tab ? tab.selectedIcon : tab.icon
        let renderedIcon = tab == .profile
            ? Self.renderProfileTabBarIcon(filled: router.selectedTab == tab)
            : Self.renderTabBarSymbol(named: symbolName)

        if let icon = renderedIcon {
            Label {
                Text(tab.title)
            } icon: {
                Image(uiImage: icon)
            }
        } else {
            Label(tab.title, systemImage: symbolName)
        }
    }

    /// TabView 会为 SF Symbol 自动建议 fill variant。先渲染成模板位图，才能严格保留
    /// 动作库 / 我的的空心未选中态，并由系统 tint 为选中态填充品牌绿。
    @MainActor
    private static func renderTabBarSymbol(named systemName: String, size: CGFloat = 25) -> UIImage? {
        let view = Image(systemName: systemName)
            .symbolVariant(.none)
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(.white)
            .frame(width: size, height: size)

        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        guard let uiImage = renderer.uiImage else { return nil }
        return uiImage.withRenderingMode(.alwaysTemplate)
    }

    @MainActor
    private static func renderProfileTabBarIcon(filled: Bool, size: CGFloat = 25) -> UIImage? {
        let view = BTProfileTabIcon(size: size, filled: filled)
            .frame(width: size, height: size)

        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        guard let uiImage = renderer.uiImage else { return nil }
        return uiImage.withRenderingMode(.alwaysTemplate)
    }

    @ViewBuilder
    private func trainingDestination(for route: TrainingRoute) -> some View {
        switch route {
        case .dailyClearance:
            FreePlayView(entryMode: .dailyClearance)
        case .planList:
            PlanListView(ownerKey: ownerKey)
        case .planDetail(let planId):
            PlanDetailView(planId: planId, ownerKey: ownerKey)
        case .drillDetail(let drillId):
            DrillDetailView(drillId: drillId, ownerKey: ownerKey)
        case .customPlanBuilder:
            CustomPlanBuilderView()
        case .customPlanEdit(let planId):
            CustomPlanBuilderView(editingPlanId: planId)
        }
    }

    @ViewBuilder
    private func angleDestination(for route: AngleRoute) -> some View {
        switch route {
        case .theoryIndex:
            TheoryIndexView()
        case .theoryPage(let pageID):
            theoryDestination(for: pageID)
        case .contactPointTable:
            ContactPointTableView()
        case .aimingPrinciple:
            AimingPrincipleView()
        case .aimingMethods:
            AimingMethodsView()
        case .aimingCorrection:
            AimingCorrectionView()
        case .spinAndEnglish:
            SpinAndEnglishView()
        case .separationAngleAtlas:
            SeparationAngleAtlasView()
        case .cushionEnglishAtlas:
            CushionEnglishAtlasView()
        case .angleDynamic:
            AngleDynamicView()
        case .geometricQuiz:
            GeometricAngleQuizView()
        case .sceneAiming2D:
            // T-P18-48 拆两卡：同一 View 两个 route，视角固定、成绩分记。
            SceneAimingView(initialCameraMode: .topDown2DRotated)
        case .sceneAiming3D:
            SceneAimingView(initialCameraMode: .perspective3D)
        case .aimPointTraining:
            AimPointTrainingView()
        case .aimPointScene2D:
            AimPointSceneTrainingView(initialCameraMode: .topDown2DRotated)
        case .aimPointScene3D:
            AimPointSceneTrainingView(initialCameraMode: .perspective3D)
        case .ballFeel:
            BallFeelView()
        case .bankShot:
            BankShotView()
        case .diamondSystem:
            DiamondSystemView()
        case .shotSimulation:
            ShotSimulationView()
        case .positionPlayComposer:
            PositionPlayComposerView()
        case .freePlay:
            // 自由击球（条 15 / ADR-P18-01 拆页）：球库 + 开球 + 对局的独立页面。
            FreePlayView()
        case .positionPlaySolver:
            SiluTrainerView()
        case .planThree:
            PlanThreeView()
        case .snookerTactics:
            SnookerTacticsView()
        case .ballExtraction:
            BallExtractionView()
        case .batchDrillStudio:
            #if targetEnvironment(simulator)
            BatchDrillStudioView()
            #else
            EmptyView()
            #endif
        case .drillDetail(let drillId):
            DrillDetailView(drillId: drillId, ownerKey: ownerKey)
        }
    }

    /// 球理详情页注册表（v30 W0 骨架，W4 起 12 篇全部注册）。
    ///
    /// 每篇的上线状态**三处成对维护**：这里的 case、`TheoryCatalog` 同 id 的
    /// `isPublished`、以及测试侧上线清单（`TheoryCatalogTests.registeredPageIDs` +
    /// `V30W0TheoryIndexUITests.publishedPageIDs`）。
    /// 12 篇已全部有页，原先兜底未注册 id 的 `TheoryPagePlaceholderView` 已随之删除
    /// （v30 W4；再有新 id 时 switch 的穷尽性会强制补页，不会静默落兜底）。
    @ViewBuilder
    private func theoryDestination(for pageID: TheoryPageID) -> some View {
        switch pageID {
        // v30 W1 试点两篇 + W2 物理定理批四篇 + W3 战术定理批四篇 + W4 流程速查两篇。
        case .t01:
            TheoryT01View()
        case .t02:
            TheoryT02View()
        case .t03:
            TheoryT03View()
        case .t04:
            TheoryT04View()
        case .t05:
            TheoryT05View()
        case .t06:
            TheoryT06View()
        case .t07:
            TheoryT07View()
        case .t08:
            TheoryT08View()
        case .t09:
            TheoryT09View()
        case .t10:
            TheoryT10View()
        case .flow:
            TheoryFlowView()
        case .quickRef:
            TheoryQuickRefView()
        }
    }

    @ViewBuilder
    private func historyDestination(for route: HistoryRoute) -> some View {
        switch route {
        case .detail(let sessionId):
            TrainingDetailView(sessionId: sessionId, ownerKey: ownerKey)
        }
    }
}

/// 从真实 UIKit TabBar 读取窗口底部到 TabBar 上沿的距离，兼容 iOS 17 固定栏、
/// iOS 26 浮动栏与带 Home Indicator 的设备；不依赖 49/60/83pt 常量。
private struct BTTabBarFrameReader: UIViewRepresentable {
    @Binding var bottomClearance: CGFloat

    func makeUIView(context: Context) -> ProbeView {
        ProbeView { measured in
            if abs(bottomClearance - measured) > 0.5 {
                bottomClearance = measured
            }
        }
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        uiView.report()
    }

    final class ProbeView: UIView {
        private let onMeasure: (CGFloat) -> Void

        init(onMeasure: @escaping (CGFloat) -> Void) {
            self.onMeasure = onMeasure
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        func report() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let window, let tabBar = Self.findTabBar(in: window) else { return }
                let frame = tabBar.convert(tabBar.bounds, to: window)
                // iPad 的系统 Tab 栏可能呈现在窗口顶部。此时浮标应回到底部安全区，
                // 而不是用“窗口底部到顶部 Tab 栏”的巨大距离把自己推离屏幕。
                let measured = frame.midY > window.bounds.midY
                    ? max(0, window.bounds.maxY - frame.minY)
                    : window.safeAreaInsets.bottom
                onMeasure(measured)
            }
        }

        private static func findTabBar(in view: UIView) -> UITabBar? {
            if let tabBar = view as? UITabBar { return tabBar }
            for child in view.subviews {
                if let found = findTabBar(in: child) { return found }
            }
            return nil
        }
    }
}

/// 个人 Tab 使用真正的描边 / 填充双态，避免系统 `person` 在未选中时仍显示实心剪影。
private struct BTProfileTabIcon: View {
    let size: CGFloat
    let filled: Bool

    var body: some View {
        Canvas { context, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            let origin = CGPoint(
                x: (canvasSize.width - side) * 0.5,
                y: (canvasSize.height - side) * 0.5
            )
            let color = Color.white
            let lineWidth = side * 0.075

            let headRect = CGRect(
                x: origin.x + side * 0.35,
                y: origin.y + side * 0.10,
                width: side * 0.30,
                height: side * 0.30
            )
            let head = Path(ellipseIn: headRect)

            var shoulders = Path()
            shoulders.move(to: CGPoint(x: origin.x + side * 0.13, y: origin.y + side * 0.90))
            shoulders.addCurve(
                to: CGPoint(x: origin.x + side * 0.87, y: origin.y + side * 0.90),
                control1: CGPoint(x: origin.x + side * 0.17, y: origin.y + side * 0.38),
                control2: CGPoint(x: origin.x + side * 0.83, y: origin.y + side * 0.38)
            )

            if filled {
                context.fill(head, with: .color(color))
                shoulders.addLine(to: CGPoint(x: origin.x + side * 0.13, y: origin.y + side * 0.90))
                shoulders.closeSubpath()
                context.fill(shoulders, with: .color(color))
            } else {
                let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                context.stroke(head, with: .color(color), style: stroke)
                context.stroke(shoulders, with: .color(color), style: stroke)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Subscribes to the live training VM so minimized chrome tracks rest + session clocks.
private struct MinimizedTrainingChrome: View {
    @ObservedObject var viewModel: ActiveTrainingViewModel
    let onTap: () -> Void

    var body: some View {
        BTFloatingIndicator(
            elapsedSeconds: viewModel.floatingIndicatorSeconds,
            title: viewModel.floatingIndicatorTitle
        ) {
            onTap()
        }
    }
}

#Preview("Light") {
    MainTabView(ownerKey: "preview-owner")
        .environmentObject(AppRouter())
        .environmentObject(AuthState())
        .environmentObject(SubscriptionManager.shared)
}

#Preview("Dark") {
    MainTabView(ownerKey: "preview-owner")
        .environmentObject(AppRouter())
        .environmentObject(AuthState())
        .environmentObject(SubscriptionManager.shared)
        .preferredColorScheme(.dark)
}
