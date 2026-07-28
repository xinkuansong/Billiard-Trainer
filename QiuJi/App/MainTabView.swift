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

            // F-AT-04: float shares copy/color/icon with home continue bar; springPanel handoff
            if router.minimizedTrainingVM != nil && router.selectedTab != .training {
                BTFloatingIndicator(
                    elapsedSeconds: router.minimizedTrainingVM?.elapsedSeconds ?? 0,
                    title: "继续训练"
                ) {
                    router.switchTab(.training)
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

    @ViewBuilder
    private func historyDestination(for route: HistoryRoute) -> some View {
        switch route {
        case .detail(let sessionId):
            TrainingDetailView(sessionId: sessionId)
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
