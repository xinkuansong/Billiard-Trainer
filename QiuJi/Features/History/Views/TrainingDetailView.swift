import SwiftUI
import SwiftData

struct TrainingDetailView: View {
    let sessionId: UUID
    @Environment(\.modelContext) private var modelContext

    @State private var session: TrainingSession?

    var body: some View {
        Group {
            if let session {
                contentView(session)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.btBG.ignoresSafeArea())
        .navigationTitle("训练详情")
        .navigationBarTitleDisplayMode(.inline)
        .task { loadSession() }
    }

    private func contentView(_ session: TrainingSession) -> some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                headerSection(session)
                statsGrid(session)
                drillSection(session)
                if !session.note.isEmpty {
                    noteSection(session.note)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
    }

    // MARK: - Header

    private func headerSection(_ session: TrainingSession) -> some View {
        VStack(spacing: Spacing.sm) {
            Text(formattedDate(session.date))
                .font(.btHeadline)
                .foregroundStyle(.btText)

            Text(formattedTime(session.date))
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.lg)
    }

    // MARK: - Stats

    private func statsGrid(_ session: TrainingSession) -> some View {
        let rate = overallRate(session)

        return HStack(spacing: Spacing.md) {
            statCard(value: "\(session.totalDurationMinutes)", label: "分钟", icon: "clock")
            statCard(value: "\(session.drillEntries.count)", label: "训练项目", icon: "list.bullet")
            statCard(
                value: "\(Int(rate * 100))%",
                label: "成功率",
                icon: "percent",
                valueColor: rateColor(rate)
            )
        }
    }

    private func statCard(value: String, label: String, icon: String, valueColor: Color = .btText) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.btPrimary)
            Text(value)
                .font(.btTitle2)
                .foregroundStyle(valueColor)
            Text(label)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Drill List

    private func drillSection(_ session: TrainingSession) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("训练项目")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            ForEach(session.drillEntries.sorted(by: { $0.successRate > $1.successRate }), id: \.id) { entry in
                drillEntryRow(entry)
            }
        }
    }

    private func drillEntryRow(_ entry: DrillEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(entry.drillNameZh)
                    .font(.btBodyMedium)
                    .foregroundStyle(.btText)
                Spacer()
                Text("\(Int(entry.successRate * 100))%")
                    .font(.btHeadline)
                    .foregroundStyle(rateColor(entry.successRate))
            }

            HStack(spacing: Spacing.sm) {
                ForEach(entry.sets.sorted(by: { $0.setNumber < $1.setNumber }), id: \.id) { set in
                    setTag(set)
                }
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private func setTag(_ set: DrillSet) -> some View {
        Text("进\(set.madeBalls)/\(set.targetBalls)")
            .font(.btCaption)
            .foregroundStyle(.btTextSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(.btBGTertiary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
    }

    // MARK: - Note

    private func noteSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("心得备注", systemImage: "note.text")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            Text(note)
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Helpers

    private func loadSession() {
        let target = sessionId
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.id == target }
        )
        session = try? modelContext.fetch(descriptor).first
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年M月d日 EEEE"
        return fmt.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "HH:mm 开始"
        return fmt.string(from: date)
    }

    private func overallRate(_ session: TrainingSession) -> Double {
        let totalMade = session.drillEntries.flatMap(\.sets).reduce(0) { $0 + $1.madeBalls }
        let totalTarget = session.drillEntries.flatMap(\.sets).reduce(0) { $0 + $1.targetBalls }
        guard totalTarget > 0 else { return 0 }
        return Double(totalMade) / Double(totalTarget)
    }

    private func rateColor(_ rate: Double) -> Color {
        if rate >= 0.8 { return .btSuccess }
        if rate >= 0.5 { return .btPrimary }
        return .btWarning
    }
}

#Preview {
    NavigationStack {
        TrainingDetailView(sessionId: UUID())
    }
    .modelContainer(for: TrainingSession.self, inMemory: true)
}
