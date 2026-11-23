import SwiftUI

struct KickPracticeSettings: View {
    @State private var draft: KickConfiguration
    let restarting: Bool
    let onStart: (KickConfiguration, KickQuestionPreparer.Prepared) -> Void
    let onCancel: () -> Void
    @EnvironmentObject private var subscription: SubscriptionManager
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var limiter = AngleUsageLimiter.kickTraining
    @State private var generation: Task<Void, Never>?
    @State private var preparing = false
    @State private var error: String?
    @State private var showSubscription = false
    @State private var pendingFree = false
    @StateObject private var notices = BTRuleNoticeCenter()
    init(configuration: KickConfiguration, restarting: Bool,
         onStart: @escaping (KickConfiguration, KickQuestionPreparer.Prepared) -> Void,
         onCancel: @escaping () -> Void) {
        let saved = UserDefaults.standard.data(forKey: "kickPractice.configuration")
            .flatMap { try? JSONDecoder().decode(KickConfiguration.self, from: $0) }
        _draft = State(initialValue: restarting ? configuration : saved ?? configuration)
        self.restarting = restarting; self.onStart = onStart; self.onCancel = onCancel
    }
    var body: some View {
        Form {
            Section("练习说明") {
                BTTrainingSettingsNote("调整方向、打点与力度，让母球按指定顺序先碰库，再碰到目标球。碰球后，母球或目标球至少有一球再次碰库；直接碰球、碰球后无球碰库或母球落袋均判犯规。")
            }
            Section("练习方式") {
                BTTrainingModePicker(count: 15, isPremium: subscription.isPremium,
                    freePractice: Binding(get: { draft.freePractice }, set: { requested in
                        if requested && !subscription.isPremium { pendingFree = true; showSubscription = true }
                        else { draft.freePractice = requested }
                    }))
            }
            Section {
                ForEach(0...4, id: \.self) { count in
                    Button { draft.railCount = count == 0 ? nil : count } label: {
                        HStack {
                            Text(count == 0 ? "综合" : "\(count)库").foregroundStyle(.btText)
                            Spacer()
                            BTSelectionIndicator(isSelected: draft.railCount == (count == 0 ? nil : count))
                        }
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("kick.railCount.\(count)")
                        .accessibilityValue(draft.railCount == (count == 0 ? nil : count) ? "已选" : "未选")
                }
            } header: { Text("碰库次数") } footer: {
                BTTrainingSettingsNote("按指定库序完成即可，方向、打点和力度不限。只统计每题首次作答，重打不改成绩。")
            }
            Section("碰库提示") {
                Toggle("库边颜色提示", isOn: $draft.showsRailColors)
                    .accessibilityIdentifier("kick.railColors")
            }
            Section("击球过程") { Toggle("播放击球过程", isOn: $draft.playsStroke).accessibilityIdentifier("kick.playsStroke") }
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
                    .disabled(preparing).accessibilityIdentifier("kick.start")
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
    private func prepare() {
        limiter.refreshDay()
        guard subscription.isPremium || (!draft.freePractice && !limiter.isLimitReached) else {
            showSubscription = true; return
        }
        let frozen = draft
        preparing = true; error = nil
        generation = Task { @MainActor in
            let worker = Task.detached(priority: .userInitiated) { try KickQuestionPreparer.prepare(frozen) }
            do {
                let prepared = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                guard !Task.isCancelled else { return }
                preparing = false
                if let data = try? JSONEncoder().encode(frozen) { UserDefaults.standard.set(data, forKey: "kickPractice.configuration") }
                onStart(frozen, prepared)
            } catch {
                guard !Task.isCancelled else { return }
                preparing = false; self.error = error.localizedDescription
            }
        }
    }
}
