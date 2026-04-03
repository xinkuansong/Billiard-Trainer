import SwiftUI
import SwiftData

struct DrillDetailView: View {
    let drillId: String

    @State private var drill: DrillContent?
    @State private var animationProgress: CGFloat = 0
    @Query private var favorites: [DrillFavorite]
    @Environment(\.modelContext) private var modelContext

    private var isFavorited: Bool {
        favorites.contains { $0.drillId == drillId }
    }

    var body: some View {
        ScrollView {
            if let drill {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    tableSection(drill)
                    infoSection(drill)
                    coachingSection(drill)
                    criteriaSection(drill)
                    videoPlaceholder
                }
                .padding(.bottom, Spacing.xxxl)
                .premiumGate(isPremium: drill.isPremium)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
        .background(.btBG)
        .navigationTitle(drill?.nameZh ?? "加载中")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorited ? .btAccent : .btTextSecondary)
                }
            }
        }
        .task {
            await loadDrill()
            withAnimation(.easeInOut(duration: 1.4)) {
                animationProgress = 1
            }
        }
    }

    // MARK: - Table Canvas

    private func tableSection(_ drill: DrillContent) -> some View {
        VStack(spacing: Spacing.md) {
            BTBilliardTable(animation: drill.animation, animationProgress: $animationProgress)
                .padding(.horizontal, Spacing.lg)

            Button {
                animationProgress = 0
                withAnimation(.easeInOut(duration: 1.4)) {
                    animationProgress = 1
                }
            } label: {
                Label("重放", systemImage: "arrow.counterclockwise")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btPrimary)
            }
        }
    }

    // MARK: - Info

    private func infoSection(_ drill: DrillContent) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                BTLevelBadge(level: DrillLevel(rawValue: drill.level) ?? .L0)

                Text(DrillCategory(rawValue: drill.category)?.nameZh ?? drill.category)
                    .font(.btSubheadline)
                    .foregroundStyle(.btTextSecondary)

                Spacer()

                difficultyDots(drill.difficulty)
            }

            Text(drill.description)
                .font(.btBody)
                .foregroundStyle(.btText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Coaching Points

    private func coachingSection(_ drill: DrillContent) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("教学要点")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(Array(drill.coachingPoints.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Text("\(index + 1)")
                            .font(.btCaption2)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(.btPrimary)
                            .clipShape(Circle())

                        Text(point)
                            .font(.btCallout)
                            .foregroundStyle(.btText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Standard Criteria

    private func criteriaSection(_ drill: DrillContent) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("达标标准")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            HStack(spacing: Spacing.md) {
                Image(systemName: "target")
                    .font(.btTitle)
                    .foregroundStyle(.btPrimary)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(drill.standardCriteria)
                        .font(.btBodyMedium)
                        .foregroundStyle(.btText)

                    Text("默认 \(drill.sets.defaultSets) 组 × \(drill.sets.defaultBallsPerSet) 球")
                        .font(.btFootnote)
                        .foregroundStyle(.btTextSecondary)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Video Placeholder

    private var videoPlaceholder: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "video.slash")
                .font(.system(size: 32))
                .foregroundStyle(.btTextTertiary)

            Text("视频内容即将上线")
                .font(.btFootnote)
                .foregroundStyle(.btTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Helpers

    private func difficultyDots(_ difficulty: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= difficulty ? Color.btPrimary : Color.btBGQuaternary)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func loadDrill() async {
        let service = DrillContentService.shared
        drill = await service.loadDrillFromBundle(id: drillId)
    }

    private func toggleFavorite() {
        if let existing = favorites.first(where: { $0.drillId == drillId }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(DrillFavorite(drillId: drillId))
        }
    }
}

#Preview("Light") {
    NavigationStack {
        DrillDetailView(drillId: "drill_c001")
    }
    .modelContainer(for: DrillFavorite.self, inMemory: true)
}

#Preview("Dark") {
    NavigationStack {
        DrillDetailView(drillId: "drill_c001")
    }
    .modelContainer(for: DrillFavorite.self, inMemory: true)
    .preferredColorScheme(.dark)
}
