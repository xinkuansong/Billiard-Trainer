import SwiftUI

struct DefensePracticeSettings: View {
    @State private var draft: DefenseConfiguration
    let restarting: Bool
    let onStart: (DefenseConfiguration, DefenseQuestionPreparer.Prepared) -> Void
    let onCancel: () -> Void
    @EnvironmentObject private var subscription: SubscriptionManager
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var limiter = AngleUsageLimiter.defenseTraining
    @State private var generation: Task<Void, Never>?
    @State private var preparing = false
    @State private var error: String?
    @State private var showSubscription = false
    @State private var pendingFree = false
    @StateObject private var notices = BTRuleNoticeCenter()
    init(configuration: DefenseConfiguration, restarting: Bool,
         onStart: @escaping (DefenseConfiguration, DefenseQuestionPreparer.Prepared) -> Void,
         onCancel: @escaping () -> Void) {
        let key = "defensePractice.configuration." + CurrentOwnerContext.shared.ownerKey
        var saved: DefenseConfiguration?
        var readError: String?
        if let data = UserDefaults.standard.data(forKey: key) {
            do { saved = try JSONDecoder().decode(DefenseConfiguration.self, from: data) }
            catch { readError = "未能读取上次设置，已显示默认设置。" }
        }
        _draft = State(initialValue: (restarting ? configuration : saved ?? configuration).forCurrentBank)
        _error = State(initialValue: restarting ? nil : readError)
        self.restarting = restarting; self.onStart = onStart; self.onCancel = onCancel
    }
    var body: some View {
        Form {
            Section("练习方式") {
                Picker("模式", selection: $draft.mode) {
                    ForEach(DefenseMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("defense.mode")
                BTTrainingSettingsNote(draft.mode == .trajectory
                    ? "观察目标路线，自行调整方向、打点和力度。亮青虚线表示母球目标路线，玫红虚线表示目标球目标路线；实际母球碰前为白色实线、碰后为白色虚线，目标球实际路线使用球号色。击球后分别查看轨迹得分和防守效果。"
                    : "不提供参考轨迹，自行决定防守方式。按实际终局评估对方的进攻机会。")
            }
            Section("训练题数") {
                BTTrainingModePicker(count: 15, isPremium: subscription.isPremium,
                    freePractice: Binding(get: { draft.freePractice }, set: { requested in
                        if requested && !subscription.isPremium { pendingFree = true; showSubscription = true }
                        else { draft.freePractice = requested }
                    }))
            }
            Section("球形") {
                selectionRow("综合", selected: draft.kind == nil, identifier: "defense.kind.all") { draft.kind = nil }
                ForEach(DefenseKind.allCases, id: \.self) { kind in
                    selectionRow(kind.title, selected: draft.kind == kind, identifier: "defense.kind." + kind.rawValue) { draft.kind = kind }
                }
            }
            Section("演示") { Toggle("击球过程", isOn: $draft.playsStroke).accessibilityIdentifier("defense.playsStroke") }
            if let error { Section { BTTrainingSettingsNote(error).foregroundStyle(.btDestructive) } }
            if preparing { ProgressView("正在选题…") }
            BTTrainingSettingsResetSection {
                draft = .init(); error = nil
                notices.show("已恢复默认设置", tone: .success, priority: .mode)
            }
        }
        .disabled(preparing)
        .navigationTitle("训练设置").navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden().toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) { Text("训练设置").font(.btHeadline).accessibilityAddTraits(.isHeader) }
            ToolbarItem(placement: .topBarLeading) {
                Button(restarting ? "取消" : "返回") { generation?.cancel(); onCancel() }
                    .accessibilityIdentifier("training.settingsCancel")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(restarting ? "重新开始" : "开始训练", action: prepare)
                    .disabled(preparing).accessibilityIdentifier("defense.start")
            }
        }
        .overlay { if let notice = notices.message { BTToastBanner(message: notice) } }
        .sheet(isPresented: $showSubscription, onDismiss: {
            if subscription.isPremium && pendingFree { draft.freePractice = true }
            pendingFree = false
        }) { SubscriptionView() }
        .onAppear { limiter.refreshDay(); if !subscription.isPremium { draft.freePractice = false } }
        .onChange(of: subscription.isPremium) { _, value in if !value { draft.freePractice = false } }
        .onChange(of: scenePhase) { _, value in
            if value != .active { generation?.cancel(); preparing = false }
            else { limiter.refreshDay() }
        }
        .onDisappear { generation?.cancel(); notices.clear() }
    }
    private func selectionRow(_ title: String, selected: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(.btText)
                Spacer()
                BTSelectionIndicator(isSelected: selected)
            }.contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier)
        .accessibilityValue(selected ? "已选" : "未选")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func prepare() {
        limiter.refreshDay()
        guard subscription.isPremium || (!draft.freePractice && !limiter.isLimitReached) else {
            showSubscription = true; return
        }
        let frozen = draft
        preparing = true; error = nil
        generation = Task { @MainActor in
            let worker = Task.detached(priority: .userInitiated) { try DefenseQuestionPreparer.prepare(frozen) }
            do {
                let prepared = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                guard !Task.isCancelled else { return }
                preparing = false
                onStart(frozen, prepared)
            } catch {
                guard !Task.isCancelled else { return }
                preparing = false; self.error = error.localizedDescription
            }
        }
    }
}
