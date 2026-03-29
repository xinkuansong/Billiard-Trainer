import SwiftUI
import SwiftData

struct FavoriteDrillsView: View {
    @Query private var favorites: [DrillFavorite]
    @Environment(\.modelContext) private var modelContext
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
                    subtitle: "在动作库中点击心形图标收藏训练项目"
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
        .navigationTitle("收藏夹")
        .navigationBarTitleDisplayMode(.large)
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
    .modelContainer(for: DrillFavorite.self, inMemory: true)
}

#Preview("Dark") {
    NavigationStack {
        FavoriteDrillsView()
    }
    .modelContainer(for: DrillFavorite.self, inMemory: true)
    .preferredColorScheme(.dark)
}
