import SwiftUI
import SwiftData

struct FavoriteDrillsView: View {
    let ownerKey: String
    @Query private var favorites: [DrillFavorite]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @State private var drills: [DrillContent] = []
    @State private var isLoading = true

    init(ownerKey: String = DeviceGuestIdentity.ownerKey()) {
        self.ownerKey = ownerKey
        _favorites = Query(filter: #Predicate { $0.ownerKey == ownerKey })
    }

    var body: some View {
        Group {
            if isLoading {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(0..<6, id: \.self) { _ in
                            BTDrillCardSkeleton()
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .btShimmer()
                }
                .transition(.opacity)
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
                .transition(.opacity)
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
                .transition(.opacity)
            }
        }
        .animation(BTMotion.easeFast, value: isLoading)
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
        withAnimation(BTMotion.easeFast) {
            isLoading = false
        }
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
