import SwiftUI

struct MultiBallPracticeView: View {
    let is3D: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var configuration: MultiBallConfiguration
    @State private var started = false
    init(is3D: Bool = false) {
        self.is3D = is3D
        _configuration = State(initialValue: .load(is3D: is3D))
    }
    var body: some View {
        Group {
            if started { FreePlayView(multiBallConfiguration: configuration, is3D: is3D) }
            else {
                ProAccessGate(requiresPremium: is3D) {
                    MultiBallSettingsView(configuration: configuration, isRestart: false, is3D: is3D,
                        onStart: { configuration = $0; started = true }, onCancel: { dismiss() })
                }
            }
        }
    }
}

struct MultiBallSettingsView: View {
    @State var configuration: MultiBallConfiguration
    @StateObject private var resetNotice = BTRuleNoticeCenter()
    @EnvironmentObject private var subscription: SubscriptionManager
    @ObservedObject private var limiter = AngleUsageLimiter.multiBallTraining
    @State private var showSubscription = false
    @State private var pendingFreePractice = false
    @State private var pendingStart = false
    @Environment(\.scenePhase) private var scenePhase
    let isRestart: Bool
    var is3D = false
    let onStart: (MultiBallConfiguration) -> Void
    let onCancel: () -> Void
    var body: some View {
        Form {
            if !is3D {
                Section("练习模式") {
                    BTTrainingModePicker(count: 3, isPremium: subscription.isPremium, freePractice: Binding(get: { configuration.freePractice }, set: { free in
                        if free && !subscription.isPremium { pendingFreePractice = true; showSubscription = true }
                        else { configuration.freePractice = free }
                    })).accessibilityIdentifier("multiBall.length")
                    if !subscription.isPremium {
                        Text("今日剩余 \(limiter.remainingToday) 题，所有多球玩法共用")
                            .font(.btCaption).foregroundStyle(.btTextSecondary)
                            .accessibilityIdentifier("multiBall.remaining")
                    }
                }
            }
            Section("玩法") {
                Picker("玩法", selection: $configuration.game) {
                    ForEach(MultiBallConfiguration.Game.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).accessibilityIdentifier("multiBall.game")
            }
            Section(configuration.game == .rotation ? "目标球数" : "己方球数（含黑八）") {
                ForEach(configuration.game == .rotation ? MultiBallConfiguration.rotationCounts : Array(4...8), id: \.self) { count in
                    choice("\(count) 颗", selected: configuration.count == count,
                           id: "multiBall.\(configuration.game == .rotation ? "rotationCount" : "ownCount").\(count)") {
                        if configuration.game == .rotation { configuration.rotationCount = count }
                        else { configuration.ownCount = count }
                    }
                }
            }
            if configuration.game == .chineseEight {
                Section("对手球") {
                    choice("0 颗", selected: !configuration.randomOpponents, id: "multiBall.opponents.zero") { configuration.randomOpponents = false }
                    choice("随机 1–7 颗", selected: configuration.randomOpponents, id: "multiBall.opponents.random") { configuration.randomOpponents = true }
                }
            }
            Section("练习方式") {
                Text(configuration.game == .rotation ? "母球自由球上手。按号码从小到大逐颗打进，练习连续走位。" : "母球自由球上手。己方全色或花色随机分配，打完己方球后再打黑八。")
            }
            BTTrainingSettingsResetSection {
                configuration = .init()
                resetNotice.show("已恢复默认设置", tone: .success, priority: .mode)
            }
        }
        .accessibilityIdentifier("multiBall.settingsForm")
        .overlay { if let message = resetNotice.message { BTToastBanner(message: message) } }
        .navigationTitle("训练设置")
        .navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(isRestart ? "取消" : "返回", action: onCancel).accessibilityIdentifier("multiBall.settingsCancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isRestart ? "重新开始" : "开始练习", action: start)
                .fontWeight(.semibold).accessibilityIdentifier("multiBall.start")
            }
        }
        .onAppear { limiter.refreshDay(); if !subscription.isPremium { configuration.freePractice = false } }
        .onChange(of: subscription.isPremium) { _, premium in if !premium { configuration.freePractice = false } }
        .sheet(isPresented: $showSubscription, onDismiss: {
            if pendingFreePractice && subscription.isPremium { configuration.freePractice = true }
            if pendingStart && subscription.isPremium { start() }
            pendingFreePractice = false; pendingStart = false
        }) { SubscriptionView() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { limiter.refreshDay() } }
        .onDisappear { resetNotice.clear() }
    }
    private func start() {
        limiter.refreshDay()
        guard subscription.isPremium || (!is3D && !configuration.freePractice && limiter.remainingToday > 0) else {
            pendingStart = true; showSubscription = true; return
        }
        onStart(configuration)
    }
    private func choice(_ title: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(.btText)
                Spacer()
                BTSelectionIndicator(isSelected: selected)
            }
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier(id)
        .accessibilityValue(selected ? "已选" : "未选")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
