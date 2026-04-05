import SwiftUI
import SwiftData

struct FavoriteDrillsView: View {
    @Query private var favorites: [DrillFavorite]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @State private var drills: [DrillContent] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if drills.isEmpty {
                BTEmptyState(
                    icon: "heart.slash",
                    title: "还没有收藏",
                    subtitle: "去动作库看看吧",
                    actionTitle: "浏览动作库",
                    action: {
                        dismiss()
                        router.switchTab(.drillLibrary)
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(drills) { drill in
                            NavigationLink(value: drill.id) {
                                BTDrillCard(
                                    drill: drill,
                                    isFavorited: true,
                                    onFavoriteTap: { removeFavorite(drill.id) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                }
            }
        }
        .background(.btBG)
        .navigationTitle("我的收藏")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: favorites.count) {
            await loadFavoriteDrills()
        }
    }

    private func loadFavoriteDrills() async {
        isLoading = true
        let service = DrillContentService.shared
        let favoriteIds = Set(favorites.map(\.drillId))
        let allDrills = await service.loadFallbackDrills()
        drills = allDrills.filter { favoriteIds.contains($0.id) }
        isLoading = false
    }

    private func removeFavorite(_ drillId: String) {
        if let fav = favorites.first(where: { $0.drillId == drillId }) {
            modelContext.delete(fav)
        }
    }
}

#Preview("Light") {
    NavigationStack {
        FavoriteDrillsView()
    }
    .environmentObject(AppRouter())
    .modelContainer(for: DrillFavorite.self, inMemory: true)
}

#Preview("Dark") {
    NavigationStack {
        FavoriteDrillsView()
    }
    .environmentObject(AppRouter())
    .modelContainer(for: DrillFavorite.self, inMemory: true)
    .preferredColorScheme(.dark)
}
