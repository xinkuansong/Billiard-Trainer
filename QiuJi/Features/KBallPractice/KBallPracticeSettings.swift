import SwiftUI

struct KBallPracticeSettings: View {
    @State private var draft: KBallConfiguration
    let restarting: Bool
    let onStart: (KBallConfiguration, KBallQuestionPreparer.Prepared) -> Void
    let onCancel: () -> Void
    @EnvironmentObject private var subscription: SubscriptionManager
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var limiter = AngleUsageLimiter.kBallTraining
    @State private var generation: Task<Void, Never>?
    @State private var preparing = false
    @State private var error: String?
    @State private var showSubscription = false
    @State private var pendingFree = false
    @StateObject private var notices = BTRuleNoticeCenter()
    init(configuration: KBallConfiguration, restarting: Bool,
         onStart: @escaping (KBallConfiguration, KBallQuestionPreparer.Prepared) -> Void,
         onCancel: @escaping () -> Void) {
        let saved = UserDefaults.standard.data(forKey: "kBallPractice.configuration")
            .flatMap { try? JSONDecoder().decode(KBallConfiguration.self, from: $0) }
        _draft = State(initialValue: restarting ? configuration : saved ?? configuration)
        self.restarting = restarting; self.onStart = onStart; self.onCancel = onCancel
    }
    var body: some View {
        Form {
            Section("练习说明") {
                BTTrainingSettingsNote("调整打点与力度，让第一球进指定袋，再让母球碰到第二球。两次碰球有先后，第一球落袋与K球的时刻不限。")
            }
            Section("练习方式") {
                BTTrainingModePicker(count: 15, isPremium: subscription.isPremium,
                    freePractice: Binding(get: { draft.freePractice }, set: { requested in
                        if requested && !subscription.isPremium { pendingFree = true; showSubscription = true }
                        else { draft.freePractice = requested }
                    }))
            }
            Section {
                Picker("观察库次", selection: $draft.filter.rail) {
                    Text("综合").tag(Int?.none)
                    ForEach(1...3, id: \.self) { Text("\($0)库").tag(Optional($0)) }
                }
                Picker("K球时机", selection: $draft.filter.timing) {
                    Text("综合").tag(KBallTiming?.none)
                    ForEach(KBallTiming.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                }
                Picker("第一球袋型", selection: $draft.filter.pocket) {
                    Text("综合").tag(KBallBankFilter.Pocket.all)
                    Text("角袋").tag(KBallBankFilter.Pocket.corner)
                    Text("中袋").tag(KBallBankFilter.Pocket.middle)
                }
                Picker("模拟容错", selection: $draft.filter.grade) {
                    Text("综合").tag(Int?.none)
                    Text("宽容").tag(Optional(3)); Text("常规").tag(Optional(2)); Text("敏感").tag(Optional(1))
                }
            } header: { Text("题目条件") } footer: {
                BTTrainingSettingsNote("库次指观察的那一库，入库前与出库后均归该库。模拟容错用于比较参数敏感程度，不代表真人成功率。")
            }
            Section("击球过程") { Toggle("播放击球过程", isOn: $draft.playsStroke).accessibilityIdentifier("kBall.playsStroke") }
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
                    .disabled(preparing).accessibilityIdentifier("kBall.start")
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
            let worker = Task.detached(priority: .userInitiated) { try KBallQuestionPreparer.prepare(frozen) }
            do {
                let prepared = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                guard !Task.isCancelled else { return }
                preparing = false
                if let data = try? JSONEncoder().encode(frozen) { UserDefaults.standard.set(data, forKey: "kBallPractice.configuration") }
                onStart(frozen, prepared)
            } catch {
                guard !Task.isCancelled else { return }
                preparing = false; self.error = error.localizedDescription
            }
        }
    }
}
