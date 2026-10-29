import SwiftUI

struct MultiBallPracticeView: View {
    let is3D: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var configuration: MultiBallConfiguration
    @State private var started = false
    @State private var restoreError: String?
    init(is3D: Bool = false) {
        self.is3D = is3D
        _configuration = State(initialValue: .load(is3D: is3D))
    }
    var body: some View {
        Group {
            if started { FreePlayView(multiBallConfiguration: configuration, is3D: is3D) }
            else {
                ProAccessGate(requiresPremium: false) {
                    MultiBallSettingsView(configuration: configuration, isRestart: false, is3D: is3D,
                        onStart: { configuration = $0; started = true }, onCancel: { dismiss() })
                }
            }
        }
        .onAppear {
            do { if try MultiBallPracticeController.hasCheckpoint() { started = true } }
            catch { restoreError = error.localizedDescription }
        }
        .alert("未能恢复练习", isPresented: Binding(get: { restoreError != nil }, set: { if !$0 { restoreError = nil } })) {
            Button("返回") { dismiss() }
        } message: { Text(restoreError ?? "") }
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
            Section("玩法") {
                Picker("玩法", selection: $configuration.game) {
                    ForEach([MultiBallConfiguration.Game.chineseEight, .rotation], id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).accessibilityIdentifier("multiBall.game")
            }
            Section {
                Picker("训练模式", selection: $configuration.positionMode) {
                    ForEach(MultiBallConfiguration.PositionMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).accessibilityIdentifier("multiBall.positionMode")
            } header: { Text("训练模式") }
            Section("练习说明") { BTTrainingSettingsNote(practiceInstructions) }
            Group {
                Section("训练量") {
                    BTTrainingModePicker(count: 3, isPremium: subscription.isPremium, freePractice: Binding(get: { configuration.freePractice }, set: { free in
                        if free && !subscription.isPremium { pendingFreePractice = true; showSubscription = true }
                        else { configuration.freePractice = free }
                    })).accessibilityIdentifier("multiBall.length")
                    if !subscription.isPremium {
                        BTTrainingSettingsNote("今日剩余 \(limiter.remainingToday) 题，2D与3D及所有多球玩法共用")
                            .font(.btCaption).foregroundStyle(.btTextSecondary)
                            .accessibilityIdentifier("multiBall.remaining")
                    }
                }
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
            Section("显示") {
                Toggle("规划球标记", isOn: $configuration.showsPlanningMarkers)
                    .accessibilityIdentifier("multiBall.planningMarkers")
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
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("训练设置").font(.btHeadline).foregroundStyle(.btPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(isRestart ? "取消" : "返回", action: onCancel).accessibilityIdentifier("multiBall.settingsCancel")
            }
            ToolbarItem(placement: .topBarTrailing) {
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
    private var practiceInstructions: String {
        let game = configuration.game == .rotation
            ? "母球自由球上手，按号码从小到大逐颗打进，练习连续走位。"
            : "母球自由球上手，先打完分配给自己的全色球或花色球，最后打黑八；对手球留在桌上作为障碍。"
        return game + (configuration.positionMode == .planned
            ? "提前规划接下来的三颗球，并为第二颗球指定袋口；追分会自动安排球序，每杆结束后查看走位得分。"
            : "不用提前指定下一颗球，按当前玩法自行选择和完成每一杆。")
    }
    private func start() {
        limiter.refreshDay()
        guard subscription.isPremium || (!configuration.freePractice && limiter.remainingToday > 0) else {
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
