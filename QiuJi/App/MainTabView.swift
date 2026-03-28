import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            TrainingPlaceholderView()
                .tabItem {
                    Label(AppTab.training.title, systemImage: AppTab.training.icon)
                }
                .tag(AppTab.training)

            DrillLibraryPlaceholderView()
                .tabItem {
                    Label(AppTab.drillLibrary.title, systemImage: AppTab.drillLibrary.icon)
                }
                .tag(AppTab.drillLibrary)

            AnglePlaceholderView()
                .tabItem {
                    Label(AppTab.angle.title, systemImage: AppTab.angle.icon)
                }
                .tag(AppTab.angle)

            HistoryPlaceholderView()
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
}

// MARK: - Tab 占位视图

private struct TrainingPlaceholderView: View {
    var body: some View {
        NavigationStack {
            PlaceholderContentView(title: "训练", icon: AppTab.training.icon)
                .navigationTitle("训练")
        }
    }
}

private struct DrillLibraryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            PlaceholderContentView(title: "动作库", icon: AppTab.drillLibrary.icon)
                .navigationTitle("动作库")
        }
    }
}

private struct AnglePlaceholderView: View {
    var body: some View {
        NavigationStack {
            PlaceholderContentView(title: "角度训练", icon: AppTab.angle.icon)
                .navigationTitle("角度训练")
        }
    }
}

private struct HistoryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            PlaceholderContentView(title: "历史记录", icon: AppTab.history.icon)
                .navigationTitle("历史")
        }
    }
}


private struct PlaceholderContentView: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.btPrimary)
            Text(title)
                .font(.btTitle)
                .foregroundStyle(.btText)
            Text("功能开发中")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.btBG)
    }
}

#Preview("Light") {
    MainTabView()
        .environmentObject(AppRouter())
        .environmentObject(AuthState())
}

#Preview("Dark") {
    MainTabView()
        .environmentObject(AppRouter())
        .environmentObject(AuthState())
        .preferredColorScheme(.dark)
}
