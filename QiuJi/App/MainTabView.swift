import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.trainingPath) {
                TrainingHomeView()
                    .navigationTitle("训练")
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
                    .navigationTitle("动作库")
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
                    .navigationTitle("角度训练")
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
                    .navigationTitle("历史")
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
        }
    }

    @ViewBuilder
    private func historyDestination(for route: HistoryRoute) -> some View {
        switch route {
        case .detail(let sessionId):
            TrainingDetailView(sessionId: sessionId)
        case .statistics:
            StatisticsView()
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
