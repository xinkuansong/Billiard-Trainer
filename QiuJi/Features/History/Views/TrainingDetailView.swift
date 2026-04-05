import SwiftUI
import SwiftData

struct TrainingDetailView: View {
    let sessionId: UUID
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var session: TrainingSession?
    @State private var showOverflowMenu = false
    @State private var categoryMapping: [String: String] = [:]

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.btFootnote14.weight(.medium))
                        .foregroundStyle(.btText)
                        .frame(width: 32, height: 32)
                        .background(Color.btBGTertiary.opacity(0.3))
                        .clipShape(Circle())
                }
            }
            ToolbarItem(placement: .principal) {
                Text(sessionTitle)
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
            }
        }
        .task {
            loadSession()
            let drills = await DrillContentService.shared.loadFallbackDrills()
            categoryMapping = Dictionary(uniqueKeysWithValues: drills.map { ($0.id, $0.category) })
        }
    }

    private var sessionTitle: String {
        guard let session else { return "训练详情" }
        let cat = primaryCategory(for: session)
        return cat.trainingNameZh
    }

    private func contentView(_ session: TrainingSession) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    headerSection(session)
                    statsRow(session)

                    VStack(spacing: Spacing.md) {
                        ForEach(
                            session.drillEntries.sorted(by: { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }),
                            id: \.id
                        ) { entry in
                            drillCard(entry)
                        }
                    }

                    if !session.note.isEmpty {
                        noteSection(session.note)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, 100)
            }
            .background(Color.btBG)

            bottomBar(session)
        }
    }

    // MARK: - Header

    private func headerSection(_ session: TrainingSession) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(primaryCategory(for: session).trainingNameZh)
                .font(.btTitle2)
                .foregroundStyle(.btText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Stats Row (horizontal scroll)

    private func statsRow(_ session: TrainingSession) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xxl) {
                statItem(value: "\(totalBallsMade(session))", label: "进球")
                statItem(value: "\(totalSets(session))", label: "组")
                statItem(value: "\(session.totalDurationMinutes)", label: "分钟")
                statItem(value: timeRange(session), label: "时段")
                statItem(value: dateLabel(session.date), label: "日期")
            }
            .padding(.horizontal, Spacing.xs)
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.btTitle)
                .foregroundStyle(.btText)
            Text(label)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }

    // MARK: - Drill Card

    private func drillCard(_ entry: DrillEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                miniTableThumbnail
                Text(entry.drillNameZh)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Spacer()
                let made = entry.sets.reduce(0) { $0 + $1.madeBalls }
                let target = entry.sets.reduce(0) { $0 + $1.targetBalls }
                Text("\(made)/\(target)")
                    .font(.btSubheadline)
                    .foregroundStyle(.btText)
            }

            VStack(spacing: Spacing.md) {
                ForEach(entry.sets.sorted(by: { $0.setNumber < $1.setNumber }), id: \.id) { drillSet in
                    setRow(drillSet)
                }
            }
            .padding(.leading, 52)

            Rectangle()
                .fill(Color.btSeparator)
                .frame(height: 0.5)

            let totalMade = entry.sets.reduce(0) { $0 + $1.madeBalls }
            Text("累计进球 \(totalMade)")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .padding(Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private var miniTableThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.btTableFelt)
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.btTableCushion, lineWidth: 3)
            Circle()
                .fill(Color.btBallCue)
                .frame(width: 6, height: 6)
                .offset(x: -4, y: 6)
            Circle()
                .fill(Color.btBallTarget)
                .frame(width: 6, height: 6)
                .offset(x: 4, y: -4)
        }
        .frame(width: 40, height: 40)
    }

    private func setRow(_ drillSet: DrillSet) -> some View {
        HStack {
            Text("第\(drillSet.setNumber)组")
                .font(.btSubheadline)
                .foregroundStyle(.btTextSecondary)

            Text("\(drillSet.madeBalls)/\(drillSet.targetBalls)")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btText)
                .padding(.leading, Spacing.lg)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.btTitle2)
                .foregroundStyle(.btPrimary)
        }
    }

    // MARK: - Note Section

    private func noteSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("训练心得")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btText)

            Text(note)
                .font(.btSubheadline)
                .foregroundStyle(.btText)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Bottom Bar

    private func bottomBar(_ session: TrainingSession) -> some View {
        HStack(spacing: Spacing.md) {
            Button {} label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "pencil")
                    Text("编辑数据")
                }
            }
            .buttonStyle(BTButtonStyle.primary)
            .frame(maxWidth: .infinity)

            Button {} label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "doc.on.doc")
                    Text("复制到今天")
                }
            }
            .buttonStyle(BTButtonStyle.secondary)
            .frame(maxWidth: .infinity)

            BTOverflowMenu(items: [
                BTMenuItem(icon: "square.and.arrow.up", iconColor: .blue, label: "生成分享图") {},
                BTMenuItem(icon: "calendar", iconColor: .purple, label: "移动到某天") {},
                BTMenuItem(icon: "pencil", iconColor: .btPrimary, label: "编辑心得") {},
                BTMenuItem(icon: "doc.on.doc", iconColor: .btAccent, label: "导入为模版") {},
                BTMenuItem(icon: "trash", iconColor: .btDestructive, label: "删除", isDestructive: true) {},
            ])
            .frame(width: 44, height: 44)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .stroke(Color.btPrimary, lineWidth: 1)
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            Color.btBGSecondary
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.08), radius: 8, x: 0, y: -4)
                .ignoresSafeArea()
        )
    }

    // MARK: - Helpers

    private func loadSession() {
        let target = sessionId
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.id == target }
        )
        session = try? modelContext.fetch(descriptor).first
    }

    private func primaryCategory(for session: TrainingSession) -> DrillCategory {
        var counts: [String: Int] = [:]
        for entry in session.drillEntries {
            let cat = categoryMapping[entry.drillId] ?? "combined"
            counts[cat, default: 0] += 1
        }
        let topCat = counts.max(by: { $0.value < $1.value })?.key ?? "combined"
        return DrillCategory(rawValue: topCat) ?? .combined
    }

    private func totalBallsMade(_ session: TrainingSession) -> Int {
        session.drillEntries.flatMap(\.sets).reduce(0) { $0 + $1.madeBalls }
    }

    private func totalSets(_ session: TrainingSession) -> Int {
        session.drillEntries.reduce(0) { $0 + $1.sets.count }
    }

    private func timeRange(_ session: TrainingSession) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "HH:mm"
        let start = fmt.string(from: session.date)
        let end = fmt.string(from: Calendar.current.date(
            byAdding: .minute, value: session.totalDurationMinutes, to: session.date
        ) ?? session.date)
        return "\(start)–\(end)"
    }

    private func dateLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日"
        return fmt.string(from: date)
    }

    private func overallRate(_ session: TrainingSession) -> Double {
        let totalMade = session.drillEntries.flatMap(\.sets).reduce(0) { $0 + $1.madeBalls }
        let totalTarget = session.drillEntries.flatMap(\.sets).reduce(0) { $0 + $1.targetBalls }
        guard totalTarget > 0 else { return 0 }
        return Double(totalMade) / Double(totalTarget)
    }
}

#Preview {
    NavigationStack {
        TrainingDetailView(sessionId: UUID())
    }
    .modelContainer(for: TrainingSession.self, inMemory: true)
}
