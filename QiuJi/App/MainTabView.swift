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
                    Label(AppTab.training.title, systemImage: AppTab.training.icon)
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

            if router.minimizedTrainingVM != nil && router.selectedTab != .training {
                BTFloatingIndicator(elapsedSeconds: router.minimizedTrainingVM?.elapsedSeconds ?? 0) {
                    router.switchTab(.training)
                }
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, 60)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: router.isTrainingMinimized)
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
        case .test:
            AngleTestView(limiter: AngleUsageLimiter())
        case .contactPointTable:
            ContactPointTableView()
        case .history:
            AngleHistoryView()
        case .aimingPrinciple:
            AimingPrincipleView()
        case .angleDynamic:
            AngleDynamicView()
        case .geometricQuiz:
            GeometricAngleQuizView()
        case .scene2DAiming:
            Scene2DAimingView()
        case .scene3DAiming:
            Scene3DAimingView()
        case .ballFeel:
            BallFeelView()
        }
    }

    @ViewBuilder
    private func historyDestination(for route: HistoryRoute) -> some View {
        switch route {
        case .detail(let sessionId):
            TrainingDetailView(sessionId: sessionId)
        case .statistics:
            EmptyView()
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
