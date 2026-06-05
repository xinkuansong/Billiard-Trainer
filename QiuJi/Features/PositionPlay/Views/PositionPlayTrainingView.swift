import SwiftUI
import SwiftData

/// 走位训练（ADR-P11-01）：列出已保存的走位序列，进入多杆播放器逐杆推演练习。
/// 没有序列时引导用户去「走位编排台」创建。
struct PositionPlayTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PositionPlaySequenceEntity.updatedAt, order: .reverse)
    private var entities: [PositionPlaySequenceEntity]

    var body: some View {
        Group {
            if sequences.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(.btBG)
        .navigationTitle("走位训练")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sequences: [PositionPlaySequence] {
        entities.compactMap { $0.decoded() }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                ForEach(sequences) { sequence in
                    NavigationLink {
                        PositionPlaySequencePlayerView(sequence: sequence)
                    } label: {
                        sequenceCard(sequence)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.lg)
        }
    }

    private func sequenceCard(_ sequence: PositionPlaySequence) -> some View {
        HStack(spacing: Spacing.lg) {
            BTIconBadge(systemName: "flag.checkered", size: 48, glyphRatio: 0.46, weight: .medium)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(sequence.name)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Text("\(sequence.steps.count) 杆 · \(formatted(sequence.updatedAt))")
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .contextMenu {
            Button("删除", systemImage: "trash", role: .destructive) {
                delete(sequence.id)
            }
        }
    }

    private var emptyState: some View {
        BTEmptyState(
            icon: "flag.checkered",
            title: "还没有走位序列",
            subtitle: "去「走位编排台」自由摆球、逐杆编排，保存后即可在这里逐杆练习。"
        )
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: date)
    }

    private func delete(_ id: UUID) {
        try? PositionPlaySequenceStore(context: modelContext).delete(id: id)
    }
}
