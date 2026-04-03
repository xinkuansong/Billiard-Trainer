import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authState: AuthState

    var body: some View {
        if authState.hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView()
        }
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
