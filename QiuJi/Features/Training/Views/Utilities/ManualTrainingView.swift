import SwiftUI
import SwiftData

struct ManualTrainingView: View {
    let ownerKey: String
    var existing: TrainingSession? = nil
    var presentsAsSheet = false
    var onSaved: (() -> Void)? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FocusState private var noteFocused: Bool
    @State private var recordID = UUID()
    @State private var date = Date()
    @State private var minutes = ""
    @State private var ballType = "chinese8"
    @State private var content = ""
    @State private var note = ""
    @State private var error: String?
    @State private var saving = false
    @State private var confirmOldDate = false
    @EnvironmentObject private var subscription: SubscriptionManager

    var body: some View {
        ScrollViewReader { proxy in
        Form {
            Section {
                DatePicker("训练日期", selection: $date, in: ...Date(), displayedComponents: .date)
                HStack {
                    Text("训练用时")
                    TextField("分钟", text: $minutes).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("manualTraining.minutes")
                    Text("分钟").foregroundStyle(.btTextSecondary)
                }
                Picker("球种", selection: $ballType) {
                    Text("中式八球").tag("chinese8")
                    Text("美式九球").tag("nineBall")
                    Text("斯诺克").tag("snooker")
                }
            }
            Section {
                TextField("例如：直线球、定杆和走位练习", text: $content, axis: .vertical)
                    .lineLimit(2...4).accessibilityIdentifier("manualTraining.content")
            } header: { Text("训练内容") } footer: { Text("简要记录练了什么，最多 100 字。") }
            Section("训练心得（选填）") {
                TextField("这次有什么收获？下次想注意什么？", text: $note, axis: .vertical)
                    .lineLimit(4...10).focused($noteFocused).id("manualTraining.note")
                    .accessibilityIdentifier("manualTraining.note")
            }
            Section {
                Text("补记计入训练天数和用时，不影响计划进度与成功率。")
                    .font(.btFootnote).foregroundStyle(.btTextSecondary)
            }
        }
        .font(.btBody).tint(.btPrimary)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: noteFocused) { _, focused in
            if focused { withAnimation(BTMotion.easeInOutFast) { proxy.scrollTo("manualTraining.note", anchor: .center) } }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
            if noteFocused { withAnimation(BTMotion.easeInOutFast) { proxy.scrollTo("manualTraining.note", anchor: .center) } }
        }
        }
        .navigationTitle(existing == nil ? "补记训练" : "编辑补记")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    noteFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                } label: { Image(systemName: BTKeyboardDismissMetrics.symbolName) }
                .accessibilityLabel("收起键盘").accessibilityIdentifier("manualTraining.dismissKeyboard")
            }
            if presentsAsSheet {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    if !subscription.isPremium && date < HistoryAccessController.cutoffDate() { confirmOldDate = true }
                    else { save() }
                }.disabled(saving || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Int(minutes) == nil)
                    .accessibilityIdentifier("manualTraining.save")
            }
        }
        .onAppear {
            if let existing {
                date = existing.reportingDate; minutes = String(existing.totalDurationMinutes)
                ballType = existing.ballType; content = existing.sourceTitleSnapshot ?? ""; note = existing.note
            }
        }
        .confirmationDialog("这条记录已超出免费历史范围", isPresented: $confirmOldDate, titleVisibility: .visible) {
            Button("仍然保存") { save() }
            Button("取消", role: .cancel) {}
        } message: { Text("保存后需开通 Pro 才能查看或编辑这条记录及心得。") }
        .alert("未能保存", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("知道了", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private func save() {
        saving = true
        defer { saving = false }
        do {
            try TrainingUtilityStore.saveManual(context: context, ownerKey: ownerKey, existing: existing,
                                                 date: date, minutes: Int(minutes) ?? 0, ballType: ballType, content: content, note: note, isPremium: subscription.isPremium, recordID: recordID)
            onSaved?()
            dismiss()
        } catch { self.error = (error as? TrainingUtilityStore.Failure)?.errorDescription ?? "保存失败，请稍后再试。已保留你的填写内容。" }
    }
}

#Preview("Light") {
    NavigationStack { ManualTrainingView(ownerKey: DeviceGuestIdentity.ownerKey()) }
        .modelContainer(ModelContainerFactory.makeInMemoryContainer()).environmentObject(SubscriptionManager.shared)
}
#Preview("Dark") {
    NavigationStack { ManualTrainingView(ownerKey: DeviceGuestIdentity.ownerKey()) }
        .modelContainer(ModelContainerFactory.makeInMemoryContainer()).environmentObject(SubscriptionManager.shared)
        .preferredColorScheme(.dark)
}
