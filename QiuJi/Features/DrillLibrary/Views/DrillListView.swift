import SwiftUI
import SwiftData

struct DrillListView: View {
    @StateObject private var viewModel = DrillListViewModel()
    @Query private var favorites: [DrillFavorite]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    private let gridColumns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md),
    ]

    private var chipActiveFill: Color {
        colorScheme == .dark
            ? Color(red: 0xF2 / 255.0, green: 0xF2 / 255.0, blue: 0xF7 / 255.0)
            : Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)
    }

    private var chipActiveText: Color {
        Color(uiColor: .systemBackground)
    }

    var body: some View {
        VStack(spacing: 0) {
            pageHeader
            searchBar
            ballTypeChips
                .padding(.vertical, Spacing.sm)

            mainContent
        }
        .background(.btBG)
        .task {
            await viewModel.loadDrills()
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        HStack {
            Text("动作库")
                .font(.btLargeTitle)
                .foregroundStyle(.btText)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.btTextTertiary)
            TextField("搜索动作", text: $viewModel.searchText)
                .font(.btCallout)
                .foregroundStyle(.btText)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.btTextTertiary)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.btBGTertiary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Main Content (Sidebar + Grid)

    private var mainContent: some View {
        HStack(alignment: .top, spacing: 0) {
            categorySidebar
            drillGrid
        }
    }

    // MARK: - Category Sidebar

    private var categorySidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                sidebarItem(label: "全部", isSelected: viewModel.categoryFilter == nil) {
                    viewModel.categoryFilter = nil
                }

                ForEach(DrillCategory.allCases) { category in
                    sidebarItem(
                        label: category.nameZh,
                        isSelected: viewModel.categoryFilter == category
                    ) {
                        viewModel.categoryFilter = category
                    }
                }
            }
        }
        .frame(width: 72)
        .background(Color.btBGSecondary)
    }

    private func sidebarItem(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Text(label)
                    .font(isSelected ? .btSubheadlineMedium : .btFootnote)
                    .foregroundStyle(isSelected ? .btPrimary : .btTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(isSelected ? Color.btBG : .clear)
            .overlay(alignment: .leading) {
                if isSelected {
                    Rectangle()
                        .fill(Color.btPrimary)
                        .frame(width: 3)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sidebar_\(label)")
    }

    // MARK: - Drill Grid

    @ViewBuilder
    private var drillGrid: some View {
        if viewModel.isLoading {
            BTDrillListSkeleton()
                .transition(.opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.drillsByCategory.isEmpty {
            gridEmptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.xl, pinnedViews: [.sectionHeaders]) {
                    ForEach(viewModel.drillsByCategory, id: \.category.id) { group in
                        Section {
                            LazyVGrid(columns: gridColumns, spacing: Spacing.md) {
                                ForEach(group.drills) { drill in
                                    NavigationLink(value: drill.id) {
                                        BTDrillGridCard(
                                            drill: drill,
                                            isFavorited: isFavorited(drill.id),
                                            onFavoriteTap: { toggleFavorite(drill.id) }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("drillCard_\(drill.id)")
                                }
                            }
                            .padding(.horizontal, Spacing.md)
                        } header: {
                            sectionHeader(category: group.category)
                        }
                    }
                }
                .padding(.bottom, Spacing.xxxxl)
            }
        }
    }

    private func sectionHeader(category: DrillCategory) -> some View {
        HStack {
            Text(category.nameZh)
                .font(.btTitle2)
                .foregroundStyle(.btText)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.btBG)
    }

    // MARK: - Ball Type Chips

    private var ballTypeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(BallTypeFilter.displayCases) { filter in
                    let isSelected = viewModel.ballTypeFilter == filter
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.ballTypeFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.btSubheadlineMedium)
                            .foregroundStyle(isSelected ? chipActiveText : .btTextSecondary)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(isSelected ? chipActiveFill : Color.btBGSecondary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : Color.btSeparator, lineWidth: 0.5)
                            )
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Empty State

    private var gridEmptyState: some View {
        Group {
            if !viewModel.searchText.isEmpty {
                BTEmptyState(
                    icon: "magnifyingglass",
                    title: "没有找到相关动作",
                    subtitle: "试试其他关键词或浏览分类",
                    actionTitle: "浏览全部动作",
                    action: { viewModel.searchText = "" }
                )
            } else {
                BTEmptyState(
                    icon: "tray",
                    title: "该分类暂无训练项目",
                    subtitle: "试试选择其他分类或球种"
                )
            }
        }
        .frame(maxHeight: .infinity)
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
