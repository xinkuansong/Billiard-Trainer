import SwiftUI
import SwiftData

struct TrainingSourceBreadcrumbModel: Equatable {
    let text: String
    let isNavigable: Bool

    static func make(
        sourceKind: String?,
        title: String?,
        subtitle: String?,
        sourceExists: Bool
    ) -> Self? {
        guard let sourceKind, let title, !title.isEmpty else { return nil }
        let prefix: String
        switch sourceKind {
        case TodayScheduleSourceKind.officialLesson: prefix = "官方计划"
        case TodayScheduleSourceKind.template: prefix = "我的模版"
        case TodayScheduleSourceKind.libraryDrill: prefix = "动作库"
        default: prefix = "训练来源"
        }
        let middle = subtitle.flatMap { $0.isEmpty ? nil : $0 }
        return .init(
            text: ([prefix] + [middle, title].compactMap { $0 }).joined(separator: " › "),
            isNavigable: sourceExists
        )
    }
}

struct TrainingDetailView: View {
    let sessionId: UUID
    let ownerKey: String

    init(sessionId: UUID, ownerKey: String = DeviceGuestIdentity.ownerKey()) {
        self.sessionId = sessionId
        self.ownerKey = ownerKey
    }
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var router: AppRouter
    @State private var session: TrainingSession?
    @State private var showOverflowMenu = false
    @State private var categoryMapping: [String: String] = [:]
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    @State private var showNoteEditor = false
    @State private var showDataEditor = false
    @State private var editingNote = ""
    @State private var actionError: String?
    /// 编辑保存后自增，强制重建正文让派生数字（成功率 / 进球 / 组）跟着刷新。
    @State private var revision = 0

    var body: some View {
        Group {
            if let session {
                contentView(session).id(revision)
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
        .confirmationDialog(
            "删除这条训练记录？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) { deleteSession() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复，本次训练的组数与心得会一并移除。")
        }
        .sheet(isPresented: $showShareSheet) {
            if let session {
                TrainingShareView(session: shareSummary(session))
            }
        }
        .sheet(isPresented: $showNoteEditor) {
            noteEditorSheet
        }
        .sheet(isPresented: $showDataEditor) {
            if let session {
                TrainingDataEditorView(session: session, onSave: saveTrainingData)
            }
        }
        .alert("操作失败", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            if let actionError {
                Text(actionError)
            }
        }
    }

    // MARK: - Note Editor (reuses TrainingNoteView)

    private var noteEditorSheet: some View {
        NavigationStack {
            TrainingNoteView(
                note: $editingNote,
                onSkip: { showNoteEditor = false },
                onComplete: { saveNote() },
                skipTitle: "取消"
            )
            .navigationTitle("编辑心得")
            .navigationBarTitleDisplayMode(.inline)
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
                    sourceBreadcrumb(session)

                    statsRow(session)

                    VStack(spacing: Spacing.md) {
                        ForEach(
                            session.drillEntries.sorted(by: { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }),
                            id: \.id
                        ) { entry in
                            drillCard(entry)
                        }
                    }

                    if let sessionNote = TrainingItemNote.visible(session.note) {
                        noteSection(sessionNote)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, 100)
            }
            .background(Color.btBG)

            bottomBar(session)
        }
    }

    // MARK: - Stats Row (horizontal scroll)
    // F-HI-10：去掉与 toolbar principal 重复的正文大标题。

    private func statsRow(_ session: TrainingSession) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xxl) {
                statItem(value: "\(totalBallsMade(session))", label: "进球")
                statItem(value: "\(totalSets(session))", label: "组")
                // F-TS-06: surface precomputed overallRate alongside summary hero metric.
                statItem(value: "\(Int(overallRate(session) * 100))%", label: "成功率")
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

    // MARK: - Frozen training source

    @ViewBuilder
    private func sourceBreadcrumb(_ session: TrainingSession) -> some View {
        let exists = sourceStillExists(session)
        if let model = TrainingSourceBreadcrumbModel.make(
            sourceKind: session.sourceKind,
            title: session.sourceTitleSnapshot,
            subtitle: session.sourceSubtitleSnapshot,
            sourceExists: exists
        ) {
            Button {
                navigateToSource(session)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: sourceIcon(session.sourceKind))
                        .foregroundStyle(.btPrimary)
                    Text(model.text)
                        .font(.btSubheadline)
                        .foregroundStyle(.btTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: Spacing.sm)
                    if model.isNavigable {
                        Image(systemName: "chevron.right")
                            .font(.btCaption.weight(.semibold))
                            .foregroundStyle(.btTextTertiary)
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.btBGSecondary, in: RoundedRectangle(cornerRadius: BTRadius.md))
            }
            .buttonStyle(.plain)
            .disabled(!model.isNavigable)
            .accessibilityIdentifier("trainingDetail.sourceBreadcrumb")
            .accessibilityLabel(model.isNavigable ? "\(model.text)，可查看来源" : "\(model.text)，来源已删除")
        }
    }

    private func sourceIcon(_ kind: String?) -> String {
        switch kind {
        case TodayScheduleSourceKind.officialLesson: return "book.closed"
        case TodayScheduleSourceKind.template: return "list.bullet.clipboard"
        case TodayScheduleSourceKind.libraryDrill: return "circle.grid.cross"
        default: return "link"
        }
    }

    private func sourceStillExists(_ session: TrainingSession) -> Bool {
        switch session.sourceKind {
        case TodayScheduleSourceKind.officialLesson:
            guard let planID = session.sourceParentId,
                  let lessonID = session.lessonId ?? session.sourceId,
                  let plan = PlanContentService.decodePlanFromBundle(id: planID) else { return false }
            return plan.lessons.contains { $0.id == lessonID }
        case TodayScheduleSourceKind.template:
            guard let rawID = session.sourceId, let id = UUID(uuidString: rawID) else { return false }
            let descriptor = FetchDescriptor<CustomPlan>(predicate: #Predicate {
                $0.ownerKey == ownerKey && $0.id == id
            })
            return ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
        case TodayScheduleSourceKind.libraryDrill:
            guard let id = session.sourceId else { return false }
            return DrillContentService.decodeDrillFromBundle(id: id) != nil
        default:
            return false
        }
    }

    private func navigateToSource(_ session: TrainingSession) {
        guard sourceStillExists(session) else { return }
        switch session.sourceKind {
        case TodayScheduleSourceKind.officialLesson:
            guard let planID = session.sourceParentId else { return }
            router.selectedTab = .training
            router.trainingPath = NavigationPath()
            router.trainingPath.append(TrainingRoute.planDetail(planId: planID))
        case TodayScheduleSourceKind.template:
            guard let rawID = session.sourceId, let id = UUID(uuidString: rawID) else { return }
            router.selectedTab = .training
            router.trainingPath = NavigationPath()
            router.trainingPath.append(TrainingRoute.customPlanEdit(planId: id))
        case TodayScheduleSourceKind.libraryDrill:
            guard let id = session.sourceId else { return }
            router.selectedTab = .drillLibrary
            router.drillLibraryPath = NavigationPath()
            router.drillLibraryPath.append(id)
        default:
            return
        }
    }

    // MARK: - Drill Card

    private func drillCard(_ entry: DrillEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                BTDrillListThumbnail(drillId: entry.drillId)
                Text(entry.drillNameZh)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Spacer()
                let made = entry.sets.reduce(0) { $0 + $1.madeBalls }
                let target = entry.sets.reduce(0) { $0 + $1.targetBalls }
                let rate = target > 0 ? Double(made) / Double(target) : 0
                Text("\(made)/\(target)")
                    .font(.btSubheadline)
                    .foregroundStyle(.btText)
                Text("\(Int(rate * 100))%")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(drillRateColor(rate))
            }

            VStack(spacing: Spacing.md) {
                ForEach(entry.sets.sorted(by: { $0.setNumber < $1.setNumber }), id: \.id) { drillSet in
                    setRow(drillSet)
                }
            }
            .padding(.leading, 52)

            if let itemNote = TrainingItemNote.visible(entry.note) {
                itemNoteRow(itemNote)
                    .padding(.leading, 52)
            }

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

    private func itemNoteRow(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("本项心得")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
            Text(note)
                .font(.btSubheadline)
                .foregroundStyle(.btText)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("本项心得，\(note)")
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
            Button {
                showDataEditor = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "pencil")
                    Text("编辑数据")
                }
            }
            .buttonStyle(BTButtonStyle.primary)
            .frame(maxWidth: .infinity)

            BTOverflowMenu(items: [
                BTMenuItem(icon: "square.and.arrow.up", iconColor: .btPrimary, label: "生成分享图") {
                    showShareSheet = true
                },
                BTMenuItem(icon: "pencil", iconColor: .btPrimary, label: "编辑心得") {
                    editingNote = session.note
                    showNoteEditor = true
                },
                BTMenuItem(icon: "trash", iconColor: .btDestructive, label: "删除", isDestructive: true) {
                    showDeleteConfirm = true
                },
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
            predicate: #Predicate { $0.ownerKey == ownerKey && $0.id == target }
        )
        session = try? modelContext.fetch(descriptor).first
    }

    /// Builds the share-card payload from the persisted record, so the card shows
    /// what was actually stored rather than re-deriving it from drill ids.
    private func shareSummary(_ session: TrainingSession) -> TrainingSessionSummary {
        TrainingSessionSummary(
            date: session.date,
            planName: sessionTitle,
            durationMinutes: session.totalDurationMinutes,
            completedDrills: session.drillEntries.count,
            totalSets: totalSets(session),
            overallSuccessRate: overallRate(session),
            drills: session.drillEntries.map { entry in
                let orderedSets = entry.sets.sorted { $0.setNumber < $1.setNumber }
                return .init(
                    name: entry.drillNameZh,
                    setsCount: entry.sets.count,
                    madeBalls: entry.sets.reduce(0) { $0 + $1.madeBalls },
                    targetBalls: entry.sets.reduce(0) { $0 + $1.targetBalls },
                    drillId: entry.drillId,
                    sets: orderedSets.map {
                        .init(id: $0.setNumber, madeBalls: $0.madeBalls, targetBalls: $0.targetBalls)
                    }
                )
            },
            note: session.note
        )
    }

    private func saveNote() {
        guard let session else { return }
        session.note = editingNote
        do {
            try modelContext.save()
            let sessionId = session.id
            Task { @MainActor in
                SyncQueueManager.shared.enqueue(
                    entityType: "TrainingSession", entityId: sessionId, operation: "update"
                )
            }
            showNoteEditor = false
        } catch {
            actionError = "心得保存失败：\(error.localizedDescription)"
        }
    }

    /// 「编辑数据」保存：只写这条记录自身的成绩面，快照字段不动（契约 §6.5）。
    /// 返回 nil 表示成功；失败时回滚并把原因交回编辑器展示，不吞错。
    private func saveTrainingData(_ draft: TrainingDataDraft) -> String? {
        guard let session else { return "训练记录已不存在。" }
        do {
            try draft.apply(to: session)
            try modelContext.save()
            let id = session.id
            Task { @MainActor in
                SyncQueueManager.shared.enqueue(
                    entityType: "TrainingSession", entityId: id, operation: "update"
                )
            }
            revision += 1
            return nil
        } catch {
            modelContext.rollback()
            loadSession()
            return "成绩保存失败：\(error.localizedDescription)"
        }
    }

    private func deleteSession() {
        guard let target = session else { return }
        // id 必须在 delete 之前取：删除后再读已删除的模型对象会崩。
        let sessionId = target.id
        // Drop the local reference first: the body must not read a deleted model object.
        session = nil
        modelContext.delete(target)
        do {
            try modelContext.save()
            Task { @MainActor in
                SyncQueueManager.shared.enqueue(
                    entityType: SyncEntityType.trainingSession,
                    entityId: sessionId, operation: SyncOperation.delete
                )
            }
            dismiss()
        } catch {
            modelContext.rollback()
            session = target
            actionError = "删除失败：\(error.localizedDescription)"
        }
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

    private func drillRateColor(_ rate: Double) -> Color {
        if rate >= 0.7 { return .btPrimary }
        return colorScheme == .dark ? .btTextSecondary : .btWarning
    }
}

#Preview {
    NavigationStack {
        TrainingDetailView(sessionId: UUID())
    }
    .modelContainer(for: TrainingSession.self, inMemory: true)
    .environmentObject(AppRouter())
}
