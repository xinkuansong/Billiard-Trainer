import SwiftUI
import SwiftData

struct DrillListView: View {
    @StateObject private var viewModel = DrillListViewModel()
    @Query private var favorites: [DrillFavorite]
    @Query private var sessions: [TrainingSession]
    @Environment(\.modelContext) private var modelContext

    /// Q19.1：侧栏点击回组顶（无记忆）——每次点击分组（含重复点击当前分组）自增，
    /// 触发右侧内容列表滚动到顶部锚点。
    @State private var scrollToken = 0
    private static let gridTopAnchor = "drillGridTop"

    private let gridColumns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md),
    ]

    private var completedDrillIds: Set<String> {
        Set(sessions.flatMap { $0.drillEntries.map(\.drillId) })
    }

    var body: some View {
        VStack(spacing: 0) {
            pageHeader
            BTLibrarySearchBar(placeholder: "搜索动作", text: $viewModel.searchText) {
                libraryFilterMenu
            }
            // v28 W3: keep a single quick-chip row (level), aligned with Training Tab.
            levelChips
                .padding(.bottom, Spacing.xs)

            mainContent
        }
        .background(.btBG)
        .task {
            await viewModel.loadDrills()
        }
        .onAppear {
            viewModel.updateCompletedDrillIds(completedDrillIds)
        }
        .onChange(of: completedDrillIds) { _, newValue in
            viewModel.updateCompletedDrillIds(newValue)
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

    /// Ball type + tutorial/progress filters live in one Menu (v28 W3); badge shows active count.
    private var libraryFilterActiveCount: Int {
        var count = 0
        if viewModel.ballTypeFilter != .all { count += 1 }
        if viewModel.badgeFilter != .all { count += 1 }
        return count
    }

    private var libraryFilterMenu: some View {
        Menu {
            Section("球种") {
                ForEach(BallTypeFilter.displayCases) { filter in
                    Button {
                        withAnimation(BTMotion.easeFast) {
                            viewModel.ballTypeFilter = filter
                        }
                    } label: {
                        if viewModel.ballTypeFilter == filter {
                            Label(filter.rawValue, systemImage: "checkmark")
                        } else {
                            Text(filter.rawValue)
                        }
                    }
                    .accessibilityIdentifier("ballTypeMenu_\(filter.rawValue)")
                }
            }
            Section("精讲与进度") {
                ForEach(DrillBadgeFilter.allCases) { filter in
                    Button {
                        withAnimation(BTMotion.easeFast) {
                            viewModel.badgeFilter = filter
                        }
                    } label: {
                        if viewModel.badgeFilter == filter {
                            Label(filter.menuLabel, systemImage: "checkmark")
                        } else {
                            Text(filter.menuLabel)
                        }
                    }
                }
            }
            if libraryFilterActiveCount > 0 {
                Button("清除筛选", role: .destructive) {
                    withAnimation(BTMotion.easeFast) {
                        viewModel.ballTypeFilter = .all
                        viewModel.badgeFilter = .all
                    }
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: BTIcon.filter)
                    .font(.btBody)
                    .foregroundStyle(libraryFilterActiveCount > 0 ? Color.btPrimary : Color.btTextSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .fill(libraryFilterActiveCount > 0 ? Color.btPrimaryMuted : Color.btBGTertiary)
                    )
                    .contentShape(Rectangle())

                if libraryFilterActiveCount > 0 {
                    Text("\(libraryFilterActiveCount)")
                        .font(.btCaption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.btPrimary, in: Capsule())
                        .offset(x: 4, y: -2)
                }
            }
        }
        .accessibilityIdentifier("badgeFilterMenu")
        .accessibilityLabel(
            libraryFilterActiveCount > 0
                ? "筛选，已选 \(libraryFilterActiveCount) 项"
                : "筛选球种与精讲"
        )
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
                sidebarItem(
                    label: "全部",
                    category: nil,
                    isSelected: viewModel.categoryFilter == nil
                ) {
                    viewModel.categoryFilter = nil
                    scrollToken &+= 1
                }

                ForEach(DrillCategory.allCases) { category in
                    sidebarItem(
                        label: category.nameZh,
                        category: category,
                        isSelected: viewModel.categoryFilter == category
                    ) {
                        viewModel.categoryFilter = category
                        scrollToken &+= 1
                    }
                }
            }
        }
        .frame(width: 76)
        .background(Color.btBGSecondary)
    }

    private func sidebarItem(
        label: String,
        category: DrillCategory?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Group {
                    if let category {
                        BTDrillCategoryIcon(category: category, size: 22, filled: isSelected)
                    } else {
                        Image(systemName: isSelected ? "square.grid.2x2.fill" : "square.grid.2x2")
                            .font(.btSubheadline)
                            .foregroundStyle(isSelected ? .btPrimary : .btTextSecondary)
                    }
                }
                .frame(height: 22)

                Text(label)
                    .font(isSelected ? .btCaption.weight(.semibold) : .btCaption)
                    .foregroundStyle(isSelected ? .btPrimary : .btTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
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
                .transition(.opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.xl, pinnedViews: [.sectionHeaders]) {
                    Color.clear
                        .frame(height: 0)
                        .id(Self.gridTopAnchor)
                    ForEach(viewModel.drillsByCategory, id: \.category.id) { group in
                        Section {
                            LazyVGrid(columns: gridColumns, spacing: Spacing.md) {
                                ForEach(group.drills) { drill in
                                    NavigationLink(value: drill.id) {
                                        BTDrillGridCard(
                                            drill: drill,
                                            isFavorited: isFavorited(drill.id),
                                            isCompleted: completedDrillIds.contains(drill.id),
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
            // Q19.1：点击/重复点击分组即回组顶。立即滚一次（同分组内容不变的情形），
            // 再于筛选去抖（300ms）+ 列表重建后补滚一次（切换分组的情形）。
            .onChange(of: scrollToken) { _, _ in
                withAnimation(BTMotion.easeChrome) {
                    proxy.scrollTo(Self.gridTopAnchor, anchor: .top)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                    withAnimation(BTMotion.easeChrome) {
                        proxy.scrollTo(Self.gridTopAnchor, anchor: .top)
                    }
                }
            }
            .transition(.opacity)
            }
        }
    }

    private func sectionHeader(category: DrillCategory) -> some View {
        BTLibrarySectionHeader(title: category.nameZh) {
            BTDrillCategoryIcon(category: category, size: 22, filled: true)
        }
    }

    // MARK: - Level Chips (shared `BTFilterChip` — Training Tab baseline)

    private var levelChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(DrillLevelFilter.allCases) { filter in
                    BTFilterChip(
                        title: filter.rawValue,
                        isSelected: viewModel.levelFilter == filter,
                        accessibilityIdentifier: "levelFilter_\(filter.rawValue)"
                    ) {
                        withAnimation(BTMotion.easeFast) {
                            viewModel.levelFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        // Keep Training Tab chip chrome; tighten vertical rhythm so the grid stays scannable.
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
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
            } else if viewModel.levelFilter != .all
                        || viewModel.badgeFilter != .all
                        || viewModel.ballTypeFilter != .all
                        || viewModel.categoryFilter != nil {
                BTEmptyState(
                    icon: "line.3.horizontal.decrease",
                    title: "没有符合筛选的动作",
                    subtitle: "试试调整等级、角标、球种或分类",
                    actionTitle: "清除筛选",
                    action: {
                        viewModel.levelFilter = .all
                        viewModel.badgeFilter = .all
                        viewModel.ballTypeFilter = .all
                        viewModel.categoryFilter = nil
                    }
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
        .accessibilityIdentifier("drillListEmptyState")
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
    .modelContainer(for: [DrillFavorite.self, TrainingSession.self], inMemory: true)
}

#Preview("Dark") {
    NavigationStack {
        DrillListView()
            .navigationTitle("动作库")
    }
    .modelContainer(for: [DrillFavorite.self, TrainingSession.self], inMemory: true)
    .preferredColorScheme(.dark)
}
