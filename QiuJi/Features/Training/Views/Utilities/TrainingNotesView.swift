import SwiftUI
import SwiftData

/// Empty automatic numbering is presentation-only noise; never rewrite the stored note.
enum TrainingJournalText {
    static func readable(_ text: String) -> String {
        text.components(separatedBy: .newlines).filter {
            $0.trimmingCharacters(in: .whitespaces).range(of: #"^\d+[.．、)]\s*$"#, options: .regularExpression) == nil
        }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func hasNotes(_ session: TrainingSession) -> Bool {
        !readable(session.note).isEmpty || session.drillEntries.contains { !readable($0.note).isEmpty }
    }
    static func title(_ session: TrainingSession) -> String {
        let title = session.sourceTitleSnapshot?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !title.isEmpty { return title }
        let names = entries(session).map(\.drillNameZh).joined(separator: "、")
        return names.isEmpty ? "训练心得" : names
    }
    static func entries(_ session: TrainingSession) -> [DrillEntry] {
        session.drillEntries.enumerated().sorted {
            $0.element.orderIndex == $1.element.orderIndex ? $0.offset < $1.offset : $0.element.orderIndex < $1.element.orderIndex
        }.map(\.element)
    }
    static func days(_ sessions: [TrainingSession], calendar: Calendar = .current) -> [(date: Date, sessions: [TrainingSession])] {
        Dictionary(grouping: sessions, by: { calendar.startOfDay(for: $0.reportingDate) })
            .map { (date: $0.key, sessions: $0.value.sorted { $0.reportingDate > $1.reportingDate }) }
            .sorted { $0.date > $1.date }
    }
}

struct TrainingNotesView: View {
    let ownerKey: String
    @Query private var sessions: [TrainingSession]
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var search = ""
    @State private var showSubscription = false
    @State private var selectedDay: Date?
    @Environment(\.modelContext) private var context

    init(ownerKey: String) {
        self.ownerKey = ownerKey
        _sessions = Query(filter: #Predicate<TrainingSession> { $0.ownerKey == ownerKey && $0.kind == "drill" }, sort: \TrainingSession.date, order: .reverse)
    }
    private var visible: [TrainingSession] {
        sessions.filter { session in
            HistoryAccessController.isAccessible(session, isPremium: subscription.isPremium)
            && TrainingJournalText.hasNotes(session)
            && (search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                ([session.note, TrainingJournalText.title(session)] + session.drillEntries.flatMap { [$0.note, $0.drillNameZh] })
                .contains { $0.localizedCaseInsensitiveContains(search.trimmingCharacters(in: .whitespacesAndNewlines)) })
        }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                if !subscription.isPremium {
                    Button { showSubscription = true } label: {
                        HStack {
                            Text("展示最近 60 天的心得").font(.btFootnote).foregroundStyle(.btTextSecondary)
                            Spacer()
                            BTProBadge(isUnlocked: subscription.isPremium)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                if visible.isEmpty {
                    BTEmptyState(icon: "book.closed", title: search.isEmpty ? "还没有训练心得" : "没有找到相关心得",
                                 subtitle: "训练结束后记下收获，也可以在补记训练时添加心得。")
                }
                ForEach(TrainingJournalText.days(visible), id: \.date) { day in
                    Button { selectedDay = day.date } label: {
                        VStack(alignment: .leading, spacing: Spacing.xl) {
                            JournalDateHeader(date: day.date, count: day.sessions.count)
                            ForEach(Array(day.sessions.prefix(2).enumerated()), id: \.element.id) { index, session in
                                if index > 0 { Divider().overlay(Color.btSeparator) }
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    JournalSessionHeading(session: session)
                                    Text(summary(session)).font(.btBody).lineSpacing(Spacing.xs).lineLimit(3)
                                }
                            }
                            HStack {
                                Text(day.date, format: .dateTime.year().month()).font(.btCaption).foregroundStyle(.btTextSecondary)
                                Spacer()
                                Text(day.sessions.count > 2 ? "翻阅全部 \(day.sessions.count) 次心得" : "翻阅心得")
                                Image(systemName: "chevron.right").font(.btCaption)
                            }.font(.btSubheadlineMedium).foregroundStyle(.btPrimary)
                        }.journalPaper().contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("trainingNotes.day")
                }
            }.padding(Spacing.lg).padding(.bottom, Spacing.sm)
        }.background(Color.btBG)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索心得或训练内容")
        .navigationTitle("训练心得").navigationBarTitleDisplayMode(.inline).tint(.btPrimary)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showSubscription) { SubscriptionView() }
        .task {
            #if DEBUG && targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("-journal.fixture"),
               ProcessInfo.processInfo.arguments.contains("-v50.inMemoryStore") {
                do { try TrainingJournalFixture.seed(context: context, ownerKey: ownerKey) }
                catch { assertionFailure("Journal fixture: \(error)") }
            }
            #endif
        }
        .navigationDestination(item: $selectedDay) { day in
            TrainingNoteCollectionDetail(ownerKey: ownerKey, day: day)
        }
    }
    private func summary(_ session: TrainingSession) -> String {
        let note = TrainingJournalText.readable(session.note)
        let entries = TrainingJournalText.entries(session).filter { !TrainingJournalText.readable($0.note).isEmpty }
        let snippets = entries.map { "\($0.drillNameZh)：\(TrainingJournalText.readable($0.note))" }
        return note.isEmpty ? snippets.joined(separator: "\n") : note
    }
}

private struct TrainingNoteCollectionDetail: View {
    let ownerKey: String
    let day: Date
    @Query private var sessions: [TrainingSession]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var editing = false
    @State private var drafts: [UUID: TrainingJournalDraft] = [:]
    @State private var retainedIDs: Set<UUID> = []
    @State private var focusedField: String?
    @State private var error: String?

    init(ownerKey: String, day: Date) {
        self.ownerKey = ownerKey
        self.day = day
        _sessions = Query(filter: #Predicate<TrainingSession> { $0.ownerKey == ownerKey && $0.kind == "drill" }, sort: \TrainingSession.date, order: .reverse)
    }
    private var records: [TrainingSession] {
        sessions.filter {
            Calendar.current.isDate($0.reportingDate, inSameDayAs: day)
            && HistoryAccessController.isAccessible($0, isPremium: subscription.isPremium)
            && (TrainingJournalText.hasNotes($0) || retainedIDs.contains($0.id))
        }.sorted { $0.reportingDate > $1.reportingDate }
    }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    JournalDateHeader(date: day, count: records.count)
                    ForEach(records) { session in
                        if session.id != records.first?.id { Divider() }
                        VStack(alignment: .leading, spacing: Spacing.xl) {
                            JournalSessionHeading(session: session)
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                sectionTitle("整次训练心得")
                                if editing {
                                    noteEditor(session: session, entry: nil)
                                } else {
                                    let text = TrainingJournalText.readable(session.note)
                                    Text(text.isEmpty ? "暂无整次心得" : text).foregroundStyle(text.isEmpty ? Color.btTextSecondary : Color.btText)
                                }
                            }
                            let entries = TrainingJournalText.entries(session).filter { editing || !TrainingJournalText.readable($0.note).isEmpty }
                            if !entries.isEmpty {
                                VStack(alignment: .leading, spacing: Spacing.lg) {
                                    sectionTitle("动作心得")
                                    ForEach(entries) { entry in
                                        VStack(alignment: .leading, spacing: Spacing.sm) {
                                            Text(entry.drillNameZh).font(.btHeadline)
                                            if editing { noteEditor(session: session, entry: entry) }
                                            else { Text(TrainingJournalText.readable(entry.note)) }
                                        }
                                    }
                                }
                            }
                            if !editing {
                                NavigationLink {
                                    TrainingDetailView(sessionId: session.id, ownerKey: ownerKey)
                                } label: {
                                    HStack {
                                        Text("查看这次训练记录")
                                        Image(systemName: "chevron.right").font(.btCaption)
                                    }.font(.btSubheadlineMedium).foregroundStyle(.btPrimary).frame(minHeight: 44)
                                }.accessibilityIdentifier("trainingNotes.record")
                            }
                        }
                    }
                    if records.isEmpty { Text("这一天暂无可查看的心得。").foregroundStyle(.btTextSecondary) }
                    Text(day, format: .dateTime.year().month().day()).font(.btCaption).foregroundStyle(.btTextSecondary)
                }.font(.btBody).lineSpacing(Spacing.xs).journalPaper().padding(Spacing.lg)
            }.background(Color.btBG).scrollDismissesKeyboard(.interactively)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                if let focusedField { withAnimation { proxy.scrollTo(focusedField, anchor: .center) } }
            }
        }
        .navigationTitle(editing ? "编辑心得" : "心得详情").navigationBarTitleDisplayMode(.inline).tint(.btPrimary)
        .toolbar(.hidden, for: .tabBar).navigationBarBackButtonHidden(editing)
        .toolbar {
            if editing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { focusedField = nil; editing = false; drafts = [:] }
                }
            }
            if editing {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).accessibilityIdentifier("trainingNotes.save")
                }
            } else if !records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: beginEditing) {
                        (Text(Image(systemName: "pencil")) + Text(" 编辑")).font(.btSubheadlineMedium)
                    }.accessibilityIdentifier("trainingNotes.edit")
                }
            }
        }
        .alert("未能保存", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("知道了", role: .cancel) {}
        } message: { Text(error ?? "") }
        .onAppear { if records.isEmpty { dismiss() } }
    }
    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.btSubheadlineSemibold).foregroundStyle(.btPrimary)
    }
    private func noteEditor(session: TrainingSession, entry: DrillEntry?) -> some View {
        let key = entry?.id.uuidString ?? session.id.uuidString
        let identifier = entry.map { "trainingNotes.entry.\($0.orderIndex)" } ?? "trainingNotes.editor"
        return BTNumberedNoteEditor(text: Binding(get: {
            if let entry { return drafts[session.id]?.entryNotes[entry.id] ?? "" }
            return drafts[session.id]?.note ?? ""
        }, set: { value in
            if let entry { drafts[session.id]?.entryNotes[entry.id] = value }
            else { drafts[session.id]?.note = value }
        }), isFocused: Binding(get: { focusedField == key }, set: { value in
            if value { focusedField = key } else if focusedField == key { focusedField = nil }
        }), expandsWithContent: true, identifier: identifier, dismissIdentifier: "trainingNotes.dismissKeyboard")
        .frame(minHeight: 88, alignment: .topLeading).padding(Spacing.md)
        .overlay(RoundedRectangle(cornerRadius: BTRadius.sm).stroke(Color.btSeparator, lineWidth: 0.5))
        .id(key)
    }
    private func beginEditing() {
        retainedIDs = Set(records.map(\.id))
        drafts = Dictionary(uniqueKeysWithValues: records.map { session in
            (session.id, TrainingJournalDraft(sessionID: session.id, note: session.note,
                entryNotes: Dictionary(uniqueKeysWithValues: session.drillEntries.map { ($0.id, $0.note) })))
        })
        editing = true
    }
    private func save() {
        focusedField = nil
        do {
            try TrainingUtilityStore.saveJournal(context: context, ownerKey: ownerKey, drafts: Array(drafts.values), isPremium: subscription.isPremium)
            editing = false
            drafts = [:]
        } catch {
            self.error = (error as? TrainingUtilityStore.Failure)?.errorDescription ?? "保存失败，请稍后再试。已保留你的填写内容。"
        }
    }
}

private struct JournalDateHeader: View {
    let date: Date
    let count: Int
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center, spacing: Spacing.md) {
                Text(String(format: "%02d", Calendar.current.component(.day, from: date))).font(.btJournalDay).foregroundStyle(.btPrimary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(date, format: .dateTime.weekday(.wide)).font(.btBody)
                    Text(date, format: .dateTime.year().month()).font(.btFootnote).foregroundStyle(.btTextSecondary)
                }.accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                Spacer(minLength: Spacing.sm)
                Text("\(count)次训练").font(.btFootnote).foregroundStyle(.btTextSecondary)
            }
            Rectangle().fill(Color.btPrimary).frame(width: Spacing.xxl, height: 1)
        }
    }
}

private struct JournalSessionHeading: View {
    let session: TrainingSession
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                if session.isManualTraining { Text("补记") }
                else { Text(session.date, format: .dateTime.hour().minute()); Text("·") }
                Text("\(session.totalDurationMinutes)分钟")
            }.font(.btFootnote).foregroundStyle(.btTextSecondary)
            Text(TrainingJournalText.title(session)).font(.btHeadline).foregroundStyle(.btText)
        }
    }
}

private extension View {
    func journalPaper() -> some View {
        self.foregroundStyle(Color.btText).padding(Spacing.xl).frame(maxWidth: .infinity, alignment: .leading)
            .background(JournalPaperBackground())
    }
}

private struct JournalPaperBackground: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: BTRadius.md).fill(Color.btJournalPaper)
                .overlay(RoundedRectangle(cornerRadius: BTRadius.md).stroke(Color.btSeparator.opacity(0.35), lineWidth: 0.5))
                .offset(x: 2, y: 4)
            RoundedRectangle(cornerRadius: BTRadius.md).fill(Color.btJournalPaper)
            Canvas { context, size in drawGrain(context: context, size: size) }
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
    private func drawGrain(context: GraphicsContext, size: CGSize) {
        var grain = Path()
        let rows = Int(size.height / 9), columns = Int(size.width / 9)
        for row in 0..<max(0, rows) {
            for column in 0..<max(0, columns) {
                let offsetX = (row * 7 + column * 3) % 7
                let offsetY = (column * 5 + row * 3) % 7
                let x = CGFloat(column * 9 + offsetX), y = CGFloat(row * 9 + offsetY)
                grain.addRect(CGRect(x: x, y: y, width: 0.6, height: 0.6))
            }
        }
        context.fill(grain, with: .color(Color.btText.opacity(0.035)))
    }
}

#Preview("Light") {
    NavigationStack { TrainingNotesView(ownerKey: DeviceGuestIdentity.ownerKey()) }
        .modelContainer(ModelContainerFactory.makeInMemoryContainer()).environmentObject(SubscriptionManager.shared)
}
#Preview("Dark") {
    NavigationStack { TrainingNotesView(ownerKey: DeviceGuestIdentity.ownerKey()) }
        .modelContainer(ModelContainerFactory.makeInMemoryContainer()).environmentObject(SubscriptionManager.shared).preferredColorScheme(.dark)
}

#if DEBUG && targetEnvironment(simulator)
private enum TrainingJournalFixture {
    static func seed(context: ModelContext, ownerKey: String) throws {
        guard try context.fetchCount(FetchDescriptor<TrainingSession>()) == 0 else { return }
        let calendar = Calendar.current
        for (offset, hour, title, note) in [(0, 19, "五分点、小角度带塞", "今天开始放慢出杆节奏。击球后多停一会儿，母球的路线看得更清楚了。"),
                                          (-3, 16, "底袋直线出杆、直线推白球", "重心保持稳定，出杆比上次更顺了。"),
                                          (-3, 10, "五分点、四球走位", "先想好路线，再俯身出杆。"),
                                          (-4, 10, "空编号训练", "1. ")] {
            let record = TrainingSession(ownerKey: ownerKey)
            let day = calendar.date(byAdding: .day, value: offset, to: Date())!
            record.date = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day)!
            record.sourceTitleSnapshot = title; record.totalDurationMinutes = 45; record.note = note
            if offset == 0 {
                record.drillEntries = [DrillEntry(drillId: "fixture-five", drillNameZh: "五分点", orderIndex: 0, note: "瞄准后保持头部稳定，送杆要完整。"),
                                       DrillEntry(drillId: "fixture-spin", drillNameZh: "小角度带塞", orderIndex: 1, note: "先控制力度，再调整旋转。")]
            }
            context.insert(record)
        }
        try context.save()
    }
}
#endif
