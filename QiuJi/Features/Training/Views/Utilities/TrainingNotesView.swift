import SwiftUI
import SwiftData

struct TrainingNotesView: View {
    let ownerKey: String
    @Query private var sessions: [TrainingSession]
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var search = ""
    @State private var showSubscription = false
    @State private var selected: TrainingSession?

    init(ownerKey: String) {
        self.ownerKey = ownerKey
        _sessions = Query(filter: #Predicate<TrainingSession> { $0.ownerKey == ownerKey && $0.kind == "drill" }, sort: \TrainingSession.date, order: .reverse)
    }

    private var visible: [TrainingSession] {
        sessions.filter { session in
            HistoryAccessController.isAccessible(session, isPremium: subscription.isPremium)
            && ([session.note] + session.drillEntries.map(\.note)).contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && (search.isEmpty || ([session.note, session.sourceTitleSnapshot ?? ""] + session.drillEntries.flatMap { [$0.note, $0.drillNameZh] }).contains { $0.localizedCaseInsensitiveContains(search) })
        }.sorted { $0.reportingDate > $1.reportingDate }
    }

    var body: some View {
        List {
            if !subscription.isPremium {
                Button { showSubscription = true } label: {
                    HStack {
                        Text("展示最近 60 天的心得").font(.btFootnote).foregroundStyle(.btTextSecondary)
                        Spacer()
                        BTProBadge(isUnlocked: subscription.isPremium)
                    }
                }.buttonStyle(.plain)
            }
            if visible.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "book.closed").font(.btTitle).foregroundStyle(.btPrimary)
                    Text(search.isEmpty ? "还没有训练心得" : "没有找到相关心得").font(.btHeadline)
                    Text("训练结束后记下收获，也可以在补记训练时添加心得。")
                        .font(.btSubheadline).foregroundStyle(.btTextSecondary)
                }.frame(maxWidth: .infinity).padding(.vertical, Spacing.lg)
            }
            ForEach(visible) { session in
                Button { selected = session } label: {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text(session.reportingDate, format: .dateTime.year().month().day()).font(.btSubheadlineMedium)
                            Spacer()
                            if session.isManualTraining { Text("补记").font(.btFootnote).foregroundStyle(.btPrimary) }
                        }
                        Text(session.sourceTitleSnapshot ?? session.drillEntries.sorted { $0.orderIndex < $1.orderIndex }.map(\.drillNameZh).joined(separator: "、"))
                            .font(.btFootnote).foregroundStyle(.btTextSecondary).lineLimit(2)
                        if !session.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(session.note).font(.btBody).lineLimit(3)
                        }
                        ForEach(session.drillEntries.sorted { $0.orderIndex < $1.orderIndex }.filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { entry in
                            Text("\(entry.drillNameZh)：\(entry.note)").font(.btSubheadline).lineLimit(2)
                        }
                    }.foregroundStyle(.btText).padding(.vertical, Spacing.sm).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索心得或训练内容")
        .navigationTitle("训练心得").navigationBarTitleDisplayMode(.inline).tint(.btPrimary)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showSubscription) { SubscriptionView() }
        .sheet(item: $selected) { session in
            NavigationStack { TrainingNoteCollectionDetail(session: session) }
        }
    }
}

private struct TrainingNoteCollectionDetail: View {
    let session: TrainingSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var editing = false
    @State private var entryID: UUID?
    @State private var draft = ""
    @State private var focused = false
    @State private var error: String?
    var body: some View {
        List {
            if !HistoryAccessController.isAccessible(session, isPremium: subscription.isPremium) {
                Text("这条心得已超出当前可查看的历史范围。")
            } else {
            Section {
                Text(session.reportingDate, format: .dateTime.year().month().day())
                Text("\(session.totalDurationMinutes) 分钟").foregroundStyle(.btTextSecondary)
            }
            Section("整次训练心得") {
                Text(session.note.isEmpty ? "暂无心得" : session.note)
                Button("编辑心得") { entryID = nil; draft = session.note; editing = true }
            }
            ForEach(session.drillEntries.sorted { $0.orderIndex < $1.orderIndex }.filter { !$0.note.isEmpty }) { entry in
                Section(entry.drillNameZh) {
                    Text(entry.note)
                    Button("编辑动作心得") { entryID = entry.id; draft = entry.note; editing = true }
                }
            }
            Section {
                NavigationLink("查看训练记录") { TrainingDetailView(sessionId: session.id, ownerKey: session.ownerKey) }
            }
            }
        }.font(.btBody).tint(.btPrimary).navigationTitle("心得详情").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
        .onAppear { if session.modelContext == nil { dismiss() } }
        .sheet(isPresented: $editing) {
            NavigationStack {
                BTNumberedNoteEditor(text: $draft, isFocused: $focused, identifier: "trainingNotes.editor")
                    .padding(Spacing.lg).background(Color.btBGSecondary)
                    .navigationTitle("编辑心得").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("取消") { editing = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") {
                                do {
                                    try TrainingUtilityStore.saveNote(context: context, session: session, entryID: entryID, text: draft, isPremium: subscription.isPremium)
                                    editing = false
                                } catch { self.error = (error as? TrainingUtilityStore.Failure)?.errorDescription ?? "保存失败，请稍后再试。已保留你的填写内容。" }
                            }
                        }
                    }
                    .alert("未能保存", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                        Button("知道了", role: .cancel) {}
                    } message: { Text(error ?? "") }
            }.tint(.btPrimary)
        }
    }
}

#Preview("Light") {
    NavigationStack { TrainingNotesView(ownerKey: DeviceGuestIdentity.ownerKey()) }
        .modelContainer(ModelContainerFactory.makeInMemoryContainer())
        .environmentObject(SubscriptionManager.shared)
}
#Preview("Dark") {
    NavigationStack { TrainingNotesView(ownerKey: DeviceGuestIdentity.ownerKey()) }
        .modelContainer(ModelContainerFactory.makeInMemoryContainer())
        .environmentObject(SubscriptionManager.shared).preferredColorScheme(.dark)
}
