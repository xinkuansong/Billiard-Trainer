import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.trainingPath) {
                TrainingHomeView()
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
                DrillListView()
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: String.self) { drillId in
                        DrillDetailView(drillId: drillId)
                    }
            }
                .tabItem {
                    Label(AppTab.drillLibrary.title, systemImage: AppTab.drillLibrary.icon)
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
                HistoryCalendarView()
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: HistoryRoute.self) { route in
                        historyDestination(for: route)
                    }
            }
                .tabItem {
                    Label(AppTab.history.title, systemImage: AppTab.history.icon)
                }
                .tag(AppTab.history)

            ProfileView()
                .tabItem {
                    Label(AppTab.profile.title, systemImage: AppTab.profile.icon)
                }
                .tag(AppTab.profile)
        }

            // F-AT-04: same compact float on every tab (including 训练), springPanel handoff.
            // Observe the VM (not just the router slot) so rest/session seconds keep ticking.
            if let vm = router.minimizedTrainingVM {
                MinimizedTrainingChrome(viewModel: vm) {
                    router.resumeMinimizedTraining()
                }
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, 60)
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
    private func trainingDestination(for route: TrainingRoute) -> some View {
        switch route {
        case .planList:
            PlanListView()
        case .planDetail(let planId):
            PlanDetailView(planId: planId)
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
            DrillDetailView(drillId: drillId)
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
            TrainingDetailView(sessionId: sessionId)
        }
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
    MainTabView()
        .environmentObject(AppRouter())
        .environmentObject(AuthState())
        .environmentObject(SubscriptionManager.shared)
}

#Preview("Dark") {
    MainTabView()
        .environmentObject(AppRouter())
        .environmentObject(AuthState())
        .environmentObject(SubscriptionManager.shared)
        .preferredColorScheme(.dark)
}
