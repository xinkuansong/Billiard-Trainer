import SwiftUI
import SwiftData

struct DrillListView: View {
    @StateObject private var viewModel = DrillListViewModel()
    @Query private var favorites: [DrillFavorite]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.md)

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if viewModel.drillsByCategory.isEmpty {
                    BTEmptyState(
                        icon: viewModel.searchText.isEmpty
                            ? "tray"
                            : "magnifyingglass",
                        title: viewModel.searchText.isEmpty
                            ? "内容加载中，请稍候"
                            : "没有找到相关训练项目",
                        subtitle: viewModel.searchText.isEmpty
                            ? "动作库内容正在准备中"
                            : "试试换个关键词搜索"
                    )
                } else {
                    drillSections
                }
            }
        }
        .background(.btBG)
        .searchable(text: $viewModel.searchText, prompt: "搜索训练项目")
        .task {
            await viewModel.loadDrills()
        }
    }

    // MARK: - Ball Type Filter

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(BallTypeFilter.allCases) { filter in
                    Button {
                        viewModel.ballTypeFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.btSubheadlineMedium)
                            .foregroundStyle(
                                viewModel.ballTypeFilter == filter ? .white : .btTextSecondary
                            )
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                viewModel.ballTypeFilter == filter
                                    ? Color.btPrimary
                                    : Color.btBGTertiary
                            )
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Drill Sections

    private var drillSections: some View {
        LazyVStack(spacing: Spacing.xl, pinnedViews: [.sectionHeaders]) {
            ForEach(viewModel.drillsByCategory, id: \.category.id) { group in
                Section {
                    VStack(spacing: Spacing.sm) {
                        ForEach(group.drills) { drill in
                            NavigationLink(value: drill.id) {
                                BTDrillCard(
                                    drill: drill,
                                    isFavorited: isFavorited(drill.id),
                                    onFavoriteTap: { toggleFavorite(drill.id) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                } header: {
                    sectionHeader(category: group.category, count: group.drills.count)
                }
            }
        }
    }

    private func sectionHeader(category: DrillCategory, count: Int) -> some View {
        HStack {
            Image(systemName: category.icon)
                .font(.btCallout)
                .foregroundStyle(.btPrimary)

            Text(category.nameZh)
                .font(.btTitle)
                .foregroundStyle(.btText)

            Text("\(count)")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 2)
                .background(.btBGTertiary)
                .clipShape(Capsule())

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(.btBG)
    }

    // MARK: - Favorites

    private func isFavorited(_ drillId: String) -> Bool {
        favorites.contains { $0.drillId == drillId }
    }

    private func toggleFavorite(_ drillId: String) {
        if let existing = favorites.first(where: { $0.drillId == drillId }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(DrillFavorite(drillId: drillId))
        }
    }
}

#Preview("Light") {
    NavigationStack {
        DrillListView()
            .navigationTitle("动作库")
    }
    .modelContainer(for: DrillFavorite.self, inMemory: true)
}

#Preview("Dark") {
    NavigationStack {
        DrillListView()
            .navigationTitle("动作库")
    }
    .modelContainer(for: DrillFavorite.self, inMemory: true)
    .preferredColorScheme(.dark)
}
