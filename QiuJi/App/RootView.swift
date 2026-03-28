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
}

#Preview("Dark") {
    RootView()
        .environmentObject(AuthState())
        .environmentObject(AppRouter())
        .preferredColorScheme(.dark)
}
