import SwiftUI

struct BankPracticeSettings: View {
    @State private var draft: BankConfiguration
    private let preferenceKey: String
    let restarting: Bool
    let onStart: (BankConfiguration, BankQuestionPreparer.Prepared) -> Void
    let onCancel: () -> Void
    @EnvironmentObject private var subscription: SubscriptionManager
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var limiter = AngleUsageLimiter.bankTraining
    @State private var generation: Task<Void, Never>?
    @State private var preparing = false
    @State private var error: String?
    @State private var showSubscription = false
    @State private var pendingFree = false
    @StateObject private var notices = BTRuleNoticeCenter()
    init(configuration: BankConfiguration, restarting: Bool,
         onStart: @escaping (BankConfiguration, BankQuestionPreparer.Prepared) -> Void,
         onCancel: @escaping () -> Void) {
        let key = "bankPractice.configuration." + CurrentOwnerContext.shared.ownerKey
        preferenceKey = key
        var saved: BankConfiguration?
        var readError: String?
        if let data = UserDefaults.standard.data(forKey: key) {
            do { saved = try JSONDecoder().decode(BankConfiguration.self, from: data) }
            catch { readError = "未能读取上次设置，已显示默认设置。" }
        }
        _draft = State(initialValue: (restarting ? configuration : saved ?? configuration).forCurrentBank)
        _error = State(initialValue: restarting ? nil : readError)
        self.restarting = restarting; self.onStart = onStart; self.onCancel = onCancel
    }
    var body: some View {
        Form {
            Section("训练模式") {
                BTTrainingModePicker(count: 15, isPremium: subscription.isPremium,
                    freePractice: Binding(get: { draft.freePractice }, set: { requested in
                        if requested && !subscription.isPremium { pendingFree = true; showSubscription = true }
                        else { draft.freePractice = requested }
                    }))
            }
            Section("练习说明") {
                BTTrainingSettingsNote("调整方向、打点和杆速，让母球直接击中目标球，再让目标球按指定顺序碰库，翻进标记袋口。所有指定库都要经过，母球落袋或再次撞击目标球均失败。只统计每题首次作答，重打不改变成绩。")
            }
            Section {
                pocketChoice(nil, title: "综合")
                ForEach(BankPocketType.allCases, id: \.self) { pocketChoice($0, title: $0.title) }
            } header: { Text("目标袋型") } footer: { BTTrainingSettingsNote("底袋指四个角袋。") }
            Section {
                ForEach([0] + Array(BankConfiguration.availableRailCounts), id: \.self) { count in
                    Button { draft.railCount = count == 0 ? nil : count } label: {
                        HStack {
                            Text(count == 0 ? "综合" : "\(count)库").foregroundStyle(.btText)
                            Spacer()
                            BTSelectionIndicator(isSelected: draft.railCount == (count == 0 ? nil : count))
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("bank.railCount.\(count)")
                        .accessibilityValue(draft.railCount == (count == 0 ? nil : count) ? "已选" : "未选")
                }
            } header: { Text("碰库次数") } footer: {
                BTTrainingSettingsNote("按指定库序完成即可，方向、打点和力度不限。只统计每题首次作答，重打不改成绩。")
            }
            Section("显示") {
                Toggle("库边颜色提示", isOn: $draft.showsRailColors)
                    .accessibilityIdentifier("bank.railColors")
            }
            Section("演示") { Toggle("击球过程", isOn: $draft.playsStroke).accessibilityIdentifier("bank.playsStroke") }
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
                    .disabled(preparing).accessibilityIdentifier("bank.start")
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
    private func pocketChoice(_ value: BankPocketType?, title: String) -> some View {
        Button { draft.pocketType = value } label: {
            HStack {
                Text(title).foregroundStyle(.btText)
                Spacer()
                BTSelectionIndicator(isSelected: draft.pocketType == value)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityIdentifier("bank.pocket.\(value?.rawValue ?? "all")")
            .accessibilityValue(draft.pocketType == value ? "已选" : "未选")
    }
    private func prepare() {
        limiter.refreshDay()
        guard subscription.isPremium || (!draft.freePractice && !limiter.isLimitReached) else {
            showSubscription = true; return
        }
        let frozen = draft
        preparing = true; error = nil
        generation = Task { @MainActor in
            let worker = Task.detached(priority: .userInitiated) { try BankQuestionPreparer.prepare(frozen) }
            do {
                let prepared = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                guard !Task.isCancelled else { return }
                preparing = false
                let data = try JSONEncoder().encode(frozen)
                UserDefaults.standard.set(data, forKey: preferenceKey)
                onStart(frozen, prepared)
            } catch {
                guard !Task.isCancelled else { return }
                preparing = false; self.error = error.localizedDescription
            }
        }
    }
}
