import SwiftUI
import SwiftData

struct DrillListView: View {
    @StateObject private var viewModel = DrillListViewModel()
    @Query private var favorites: [DrillFavorite]
    @Query private var sessions: [TrainingSession]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

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
            searchBar
            ballTypeChips
                .padding(.top, Spacing.sm)
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

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
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

            // R2: badge filters live in a Menu (same pattern as TrainingHomeView overflow Menu).
            badgeFilterMenu
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    private var badgeFilterActiveCount: Int {
        viewModel.badgeFilter == .all ? 0 : 1
    }

    private var badgeFilterMenu: some View {
        Menu {
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
            if viewModel.badgeFilter != .all {
                Button("清除角标筛选", role: .destructive) {
                    withAnimation(BTMotion.easeFast) {
                        viewModel.badgeFilter = .all
                    }
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: BTIcon.filter)
                    .font(.btBody)
                    .foregroundStyle(badgeFilterActiveCount > 0 ? Color.btPrimary : Color.btTextSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .fill(badgeFilterActiveCount > 0 ? Color.btPrimaryMuted : Color.btBGTertiary)
                    )
                    .contentShape(Rectangle())

                if badgeFilterActiveCount > 0 {
                    Text("\(badgeFilterActiveCount)")
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
            badgeFilterActiveCount > 0
                ? "角标筛选，已选 \(viewModel.badgeFilter.menuLabel)"
                : "角标筛选"
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
        HStack(spacing: Spacing.sm) {
            BTDrillCategoryIcon(category: category, size: 22, filled: true)
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
                        withAnimation(BTMotion.easeInOutFast) {
                            viewModel.ballTypeFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.btSubheadlineMedium)
                            .foregroundStyle(chipActiveText(isSelected))
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(isSelected ? chipActiveFill : Color.btBGSecondary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : Color.btSeparator, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(BTPressableStyle.capsule)
                    .accessibilityIdentifier("ballType_\(filter.rawValue)")
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Level Chips (E18 — match Training Tab `filterChips`)

    private var levelChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(DrillLevelFilter.allCases) { filter in
                    levelChipButton(filter)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        // Keep Training Tab chip chrome; tighten vertical rhythm so the grid stays scannable.
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
    }

    private func levelChipButton(_ filter: DrillLevelFilter) -> some View {
        let isSelected = viewModel.levelFilter == filter
        return Button {
            withAnimation(BTMotion.easeFast) {
                viewModel.levelFilter = filter
            }
        } label: {
            Text(filter.rawValue)
                .font(.btFootnote14.weight(.medium))
                .foregroundStyle(trainingStyleChipText(isSelected))
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.sm)
                .background(trainingStyleChipBackground(isSelected))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(trainingStyleChipBorder(isSelected), lineWidth: isSelected ? 0 : 1)
                )
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("levelFilter_\(filter.rawValue)")
    }

    // MARK: - Chip Colors (Training Tab parity for level; ball-type keeps prior style)

    private var chipActiveFill: Color {
        colorScheme == .dark ? .btChipActiveFillDark : .btChipActiveFillLight
    }

    private func chipActiveText(_ isSelected: Bool) -> Color {
        isSelected
            ? (colorScheme == .dark ? .black : .white)
            : .btTextSecondary
    }

    private func trainingStyleChipText(_ isSelected: Bool) -> Color {
        if isSelected {
            return colorScheme == .dark ? .black : Color.btBGSecondary
        }
        return colorScheme == .dark ? .btTextSecondary : .btText
    }

    private func trainingStyleChipBackground(_ isSelected: Bool) -> Color {
        if isSelected {
            return colorScheme == .dark ? .btChipActiveFillDark : .btChipActiveFillLight
        }
        return colorScheme == .dark ? Color.btBGTertiary : Color.btBGSecondary
    }

    private func trainingStyleChipBorder(_ isSelected: Bool) -> Color {
        isSelected ? .clear : .btSeparator
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
