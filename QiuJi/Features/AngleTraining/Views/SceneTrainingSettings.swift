import SwiftUI

/// Cancel discards this form's draft; a validated batch is required before starting.
struct SceneTrainingSettings<Batch>: View {
    let route: String
    let restarting: Bool
    let prepareBatch: (SceneTrainingConfiguration) throws -> Batch
    let showsSpinOptions: Bool
    private let strokePlayback: Binding<Bool>?
    private let centerReference: Binding<Bool>?
    private let twoBallMode: Binding<TwoBallMode>?
    @State private var draftMode: TwoBallMode
    @State private var draftShowsReference: Bool
    @State private var draftPlaysStroke: Bool
    @State private var modeDrafts: [TwoBallMode: TwoBallSettingsPreference] = [:]
    @State private var loadedDraft = false
    let onStart: (SceneTrainingConfiguration, Batch) -> Void
    let onCancel: () -> Void
    @EnvironmentObject private var subscription: SubscriptionManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSubscription = false
    @State private var draft: SceneTrainingConfiguration
    @State private var preparing = false
    @State private var error: String?
    @State private var generation: Task<Void, Never>?
    @State private var pendingFreePractice = false
    @State private var pendingStart = false
    @ObservedObject private var limiter: AngleUsageLimiter
    @StateObject private var resetNotice = BTRuleNoticeCenter()
    private var showsAccuracyShotSettings: Bool { route.hasPrefix("accuracy") && showsSpinOptions }
    private var usesFirstShotConditions: Bool { twoBallMode != nil || route.hasPrefix("threeBallPractice") }
    private var angleRangeDisplayOrder: [SceneTrainingConfiguration.AngleRange] {
        [.mixed] + SceneTrainingConfiguration.AngleRange.allCases.filter { $0 != .mixed }
    }
    private var showsReferenceSpin: Bool { showsSpinOptions && !showsAccuracyShotSettings && (twoBallMode == nil || draftMode == .trajectory) }
    init(route: String, configuration: SceneTrainingConfiguration, restarting: Bool,
         showsSpinOptions: Bool = false, strokePlayback: Binding<Bool>? = nil,
         centerReference: Binding<Bool>? = nil, twoBallMode: Binding<TwoBallMode>? = nil,
         prepareBatch: @escaping (SceneTrainingConfiguration) throws -> Batch,
         onStart: @escaping (SceneTrainingConfiguration, Batch) -> Void,
         onCancel: @escaping () -> Void) {
        _limiter = ObservedObject(wrappedValue: AngleUsageLimiter.training(route: route))
        self.route = route; self.restarting = restarting; self.onStart = onStart; self.onCancel = onCancel
        self.prepareBatch = prepareBatch; self.showsSpinOptions = showsSpinOptions
        _draft = State(initialValue: configuration)
        self.centerReference = centerReference
        self.twoBallMode = twoBallMode; _draftMode = State(initialValue: twoBallMode?.wrappedValue ?? SceneTrainingSettingsDefaults.twoBallMode)
        _draftShowsReference = State(initialValue: centerReference?.wrappedValue ?? SceneTrainingSettingsDefaults.showsReference)
        self.strokePlayback = strokePlayback
        _draftPlaysStroke = State(initialValue: strokePlayback?.wrappedValue ?? SceneTrainingSettingsDefaults.playsStroke)
    }
    var body: some View {
        Form {
            if twoBallMode != nil {
                Section("训练模式") {
                    Picker("训练模式", selection: modeSelection) {
                        ForEach(TwoBallMode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("twoBall.mode")
                }
            }
            Section("练习说明") { explanation(practiceInstructions) }
            Section {
                BTTrainingModePicker(count: TrainingProject.ordinaryRoundCount, isPremium: subscription.isPremium, freePractice: Binding(get: { draft.freePractice }, set: { requested in
                    if requested && !subscription.isPremium {
                        pendingFreePractice = true; showSubscription = true
                    }
                    else { draft.freePractice = requested }
                })).accessibilityIdentifier("training.length")
            } header: {
                Text("训练量")
            } footer: {
                if route.hasPrefix("twoBallPractice") {
                    explanation(draftMode == .trajectory
                        ? "均分先汇总每题各轨迹的首答，再按题平均；跳过不计分，重打不覆盖首答。"
                        : "按实际停点的球距、出杆空间和角度评0–100分，越高越好；均分统计首答，本题均分包含重打。")
                } else if route.hasPrefix("separationPractice") {
                    explanation("均分统计各题首答；本题均分统计本题历次出杆。重打不覆盖首答。")
                }
            }
            if showsAccuracyShotSettings {
                Section {
                    Toggle("自行调整高低杆", isOn: $draft.allowsManualVerticalSpin)
                        .accessibilityIdentifier("accuracy.manualVerticalSpin")
                    Toggle("自行调整左右塞", isOn: $draft.allowsManualSideSpin)
                        .accessibilityIdentifier("accuracy.manualSideSpin")
                } header: {
                    Text("击球设置")
                } footer: {
                    spinNote("注：开启后会自动关闭对应的出题设置。")
                        .accessibilityIdentifier("accuracy.shotSettingsNote")
                }
            }
            if showsReferenceSpin { spinSection }
            if !subscription.isPremium {
                Section {
                    explanation("今日剩余 \(limiter.remainingToday) 题，2D与3D共用")
                        .font(.btCaption).foregroundStyle(.btTextSecondary)
                }
            }
            Section(usesFirstShotConditions ? "第一杆角度范围" : "角度范围") {
                ForEach(angleRangeDisplayOrder) { range in
                    Button { SceneTrainingConfiguration.toggle(range, random: .mixed, in: &draft.angleSelection) } label: {
                        HStack {
                            Text(range == .mixed ? "综合 · 0–85°" : range.label).foregroundStyle(.btText)
                            Spacer()
                            BTSelectionIndicator(isSelected: draft.angleSelection.contains(range))
                        }
                    }.accessibilityIdentifier("training.range." + range.rawValue)
                        .accessibilityValue(draft.angleSelection.contains(range) ? "已选" : "未选")
                        .accessibilityAddTraits(draft.angleSelection.contains(range) ? .isSelected : [])
                }
            }
            Section {
                TrainingMultiSelectRow(title: "母球到目标球", identifier: "training.cueDistance",
                    selection: $draft.cueDistanceSelection, choices: SceneTrainingConfiguration.Distance.allCases,
                    random: .mixed, label: { $0.label(cue: true) }, summaryLabel: { $0.shortLabel })
                TrainingMultiSelectRow(title: "目标球到袋口", identifier: "training.pocketDistance",
                    selection: $draft.pocketDistanceSelection, choices: SceneTrainingConfiguration.Distance.allCases,
                    random: .mixed, label: { $0.label(cue: false) }, summaryLabel: { $0.shortLabel })
                TrainingMultiSelectRow(title: "目标袋类型", identifier: "training.pockets",
                    selection: $draft.pocketSelection, choices: SceneTrainingConfiguration.Pockets.allCases,
                    random: .mixed, label: { $0.label })
                TrainingMultiSelectRow(title: "目标球离库", identifier: "training.railDistance",
                    selection: $draft.railDistanceSelection, choices: SceneTrainingConfiguration.RailDistance.allCases,
                    random: .mixed, label: { $0.label })
                explanation("母球距离按两球中心计算；距袋按目标球到有效进袋瞄点计算。半贴库指目标球表面离库不超过10厘米，贴库单独选择。")
                    .font(.btCaption).foregroundStyle(.btTextSecondary)
                    .accessibilityIdentifier("training.conditionsInfo")
            } header: {
                Text(usesFirstShotConditions ? "第一杆球形条件" : "球形条件")
                    .accessibilityIdentifier("training.conditions")
            }
            if TrainingProject.from(route: route) == .aimPoint { aimErrorExplanation }
            if showsAccuracyShotSettings { spinSection }
            if strokePlayback != nil { demonstrationSection }
            if let error {
                Section {
                    explanation(error).foregroundStyle(.btDestructive).accessibilityIdentifier("training.generationError")
                    Button("重新生成", action: prepare)
                }
            }
            if preparing { ProgressView("正在检查球形条件…") }
            BTTrainingSettingsResetSection {
                draft = .defaults(for: route)
                if twoBallMode != nil {
                    modeDrafts = Dictionary(uniqueKeysWithValues: TwoBallMode.allCases.map { ($0, .defaults(for: route)) })
                }
                draftMode = SceneTrainingSettingsDefaults.twoBallMode
                draftShowsReference = SceneTrainingSettingsDefaults.showsReference
                draftPlaysStroke = SceneTrainingSettingsDefaults.playsStroke
                error = nil
                pendingFreePractice = false; pendingStart = false
                resetNotice.show("已恢复默认设置", tone: .success, priority: .mode)
            }
        }
        .disabled(preparing)
        .overlay {
            if let message = resetNotice.message { BTToastBanner(message: message) }
        }
        .navigationTitle("训练设置").navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("训练设置").font(.btHeadline).foregroundStyle(.btPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(restarting ? "重新开始" : "开始训练", action: prepare)
                    .disabled(preparing).accessibilityIdentifier(route.hasPrefix("threeBallPractice") ? "threeBall.start" : route.hasPrefix("twoBallPractice") ? "twoBall.start" : (route.hasPrefix("separationPractice") || route.hasPrefix("twoBallPractice") || route.hasPrefix("threeBallPractice")) ? "separation.start" : route.hasPrefix("accuracy") ? "accuracy.start" : (route.hasPrefix("aimPoint") ? "aimPointTraining.start" : "angleTraining.start"))
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(restarting ? "取消" : "返回") { generation?.cancel(); onCancel() }
                    .accessibilityIdentifier("training.settingsCancel")
            }
        }
        .onAppear {
            limiter.refreshDay()
            if !loadedDraft {
                if twoBallMode != nil {
                    modeDrafts = Dictionary(uniqueKeysWithValues: TwoBallMode.allCases.map { ($0, .load(for: route, mode: $0)) })
                    if restarting { modeDrafts[draftMode] = currentModeDraft }
                    else { applyModeDraft(modeDrafts[draftMode]!) }
                } else if !restarting { draft = .load(for: route) }
                loadedDraft = true
            }
            if !subscription.isPremium { draft.freePractice = false }
        }
        .onChange(of: subscription.isPremium) { _, premium in if !premium { draft.freePractice = false } }
        .sheet(isPresented: $showSubscription, onDismiss: {
            if subscription.isPremium {
                if pendingFreePractice { draft.freePractice = true }
                if pendingStart { prepare() }
            }
            pendingFreePractice = false; pendingStart = false
        }) { SubscriptionView() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { limiter.refreshDay() }
            if phase != .active, (route.hasPrefix("separationPractice") || route.hasPrefix("twoBallPractice") || route.hasPrefix("threeBallPractice")) { generation?.cancel(); preparing = false }
        }
        .onDisappear { generation?.cancel(); resetNotice.clear() }
    }
    private var aimErrorExplanation: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("评级标准").font(.btSubheadlineSemibold)
                VStack(spacing: Spacing.sm) {
                    aimErrorGrade("完美", range: "≤ 0.5 mm")
                    aimErrorGrade("很好", range: "> 0.5 且 ≤ 1 mm")
                    aimErrorGrade("好", range: "> 1 且 ≤ 2 mm")
                    aimErrorGrade("一般", range: "> 2 且 ≤ 5 mm")
                    aimErrorGrade("差", range: "> 5 mm")
                }
                explanation("厚、薄均按误差大小评级；直球显示左或右。")
                    .font(.btFootnote14).foregroundStyle(.btTextSecondary)
                Divider()
                Text("统计规则").font(.btSubheadlineSemibold)
                explanation("误差 ≤ 2 mm 计为答对。\n正确率和平均误差仅统计每题首次作答。")
                    .font(.btCallout)
                explanation("方向反了、瞄错侧或未对准目标球时评为差，计为答错，不计入平均误差。")
                    .font(.btFootnote14).foregroundStyle(.btTextSecondary)
            }
            .foregroundStyle(.btText)
            .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text("瞄准误差说明")
                .accessibilityIdentifier("aimPointTraining.errorExplanation")
        }
    }

    private func aimErrorGrade(_ grade: String, range: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(grade)
            Spacer(minLength: Spacing.md)
            Text(range).monospacedDigit().fixedSize()
        }
        .font(.btCallout)
        .accessibilityElement(children: .combine)
    }

    private var practiceInstructions: String {
        switch TrainingProject.from(route: route) {
        case .angle:
            return "观察母球、目标球和目标袋口，判断这一杆的切角并作答。提交后对照实际角度，找出自己的判断偏差。"
        case .aimPoint:
            return "转动方向尺，让母球瞄向你认为能进球的位置，再提交答案。对照目标瞄准点和实际瞄准线查看误差；不确定时可以先打开辅助，提交后也可以重打。"
        case .accuracy:
            return "按题目给出的球形和打点调整瞄准方向，将目标球打进指定袋口。击球后查看进球结果，再继续下一题。"
        case .separation:
            return "观察目标路线，调整打点和杆速，让母球击中目标球后走出相近的轨迹。第一杆前可以对照中杆轨迹；击球后比较结果，也可以重打寻找更合适的杆法。"
        case .twoBall:
            return draftMode == .trajectory
                ? "对照目标路线调整打点和杆速，在打进第一颗球的同时让母球走出相近的轨迹。比较击球结果后可以重打，或切换目标路线继续练习。"
                : "观察第二颗球和它的指定袋口，再调整第一杆的打点和杆速。打进第一颗球的同时，把母球停在方便打第二颗球的位置，击球后查看走位得分。"
        case .threeBall:
            return "用前两杆完成两次连续走位。前两颗球同属全色或花色，第三颗为黑八；第一杆前为第二颗球选袋，第二杆前为黑八选袋，再调整打点和杆速，把母球停到适合下一杆的位置。两次走位得分取平均，重打不覆盖首答。"
        default: return "按照当前球形和目标完成击球，查看结果后继续练习。"
        }
    }
    private var currentModeDraft: TwoBallSettingsPreference {
        .init(configuration: draft, playsStroke: draftPlaysStroke, showsReference: draftShowsReference)
    }
    private func applyModeDraft(_ value: TwoBallSettingsPreference) {
        draft = value.configuration
        if !subscription.isPremium { draft.freePractice = false }
        draftPlaysStroke = value.playsStroke
        draftShowsReference = value.showsReference
    }
    private var modeSelection: Binding<TwoBallMode> {
        Binding(get: { draftMode }, set: { mode in
            guard mode != draftMode else { return }
            modeDrafts[draftMode] = currentModeDraft
            draftMode = mode
            applyModeDraft(modeDrafts[mode] ?? .load(for: route, mode: mode))
            error = nil
        })
    }
    private var spinSection: some View {
        Section {
            Toggle(showsAccuracyShotSettings ? "系统指定高低杆" : "包含高低杆", isOn: $draft.allowsVerticalSpin)
                .accessibilityIdentifier("training.verticalSpin")
            Toggle(showsAccuracyShotSettings ? "系统指定左右塞" : "包含左右塞", isOn: $draft.allowsSideSpin)
                .accessibilityIdentifier("training.sideSpin")
        } header: { Text(showsAccuracyShotSettings ? "出题设置" : "目标路线杆法") } footer: {
            if showsAccuracyShotSettings {
                spinNote("开启后会自动关闭对应的自行调整选项。")
                    .accessibilityIdentifier("training.spinInfo")
            } else {
                explanation("仅筛选目标路线的杆法。练习时仍可自由调整打点和力度。")
                    .accessibilityIdentifier("training.spinInfo")
            }
        }
    }
    private var demonstrationSection: some View {
        Section {
            if strokePlayback != nil {
                Toggle("击球过程", isOn: $draftPlaysStroke)
                    .accessibilityIdentifier("separation.playsStroke")
            }
        } header: {
            Text("演示").accessibilityIdentifier("separation.shotSettingsHeader")
        } footer: {
            explanation("首次提交前始终显示中杆参考。关闭播放会直接显示击球结果；已进行瞄准补偿。")
                .font(.btCaption).foregroundStyle(.btTextSecondary)
                .accessibilityIdentifier("separation.aimCompensationNote")
        }
    }
    private func spinNote(_ text: String) -> some View {
        explanation(text)
            .font(.btCaption2).foregroundStyle(.btTextSecondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
    private func explanation(_ text: String) -> some View {
        BTTrainingSettingsNote(text)
    }
    private func prepare() {
        let limiter = AngleUsageLimiter.training(route: route)
        limiter.refreshDay(); limiter.isPremium = subscription.isPremium
        guard subscription.isPremium || (!draft.freePractice && !limiter.isLimitReached) else {
            pendingStart = true
            showSubscription = true; return
        }
        preparing = true; error = nil
        let configuration = twoBallMode == nil ? draft : draft.forTwoBallMode(draftMode)
        generation = Task {
            let worker = Task.detached(priority: .userInitiated) { () -> Result<Batch, Error> in
                Result { try prepareBatch(configuration) }
            }
            let outcome = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled else { return }
            preparing = false
            switch outcome {
            case .success(let questions):
                if twoBallMode != nil {
                    modeDrafts[draftMode] = currentModeDraft
                    for (mode, value) in modeDrafts { value.save(for: route, mode: mode) }
                }
                configuration.save(for: route)
                twoBallMode?.wrappedValue = draftMode
                centerReference?.wrappedValue = draftShowsReference
                strokePlayback?.wrappedValue = draftPlaysStroke
                onStart(configuration, questions)
            case .failure(let failure): error = failure.localizedDescription
            }
        }
    }
}

extension SceneTrainingSettings where Batch == [SceneTrainingQuestion] {
    init(route: String, configuration: SceneTrainingConfiguration, restarting: Bool,
         onStart: @escaping (SceneTrainingConfiguration, [SceneTrainingQuestion]) -> Void,
         onCancel: @escaping () -> Void) {
        self.init(route: route, configuration: configuration, restarting: restarting,
            prepareBatch: { configuration in
                let bank = try TrainingBankStore.load()
                return try bank.baseBatch(configuration, seed: UInt64.random(in: 0...UInt64.max), count: TrainingProject.ordinaryRoundCount).map(\.question)
            }, onStart: onStart, onCancel: onCancel)
    }
}

/// Native popover captures outside taps and keeps the draft when dismissed.
/// Choice buttons deliberately leave it open for repeated selection.
struct TrainingMultiSelectRow<Choice: Hashable & Identifiable>: View {
    let title: String
    let identifier: String
    @Binding var selection: Set<Choice>
    let choices: [Choice]
    let random: Choice
    let label: (Choice) -> String
    var summaryLabel: ((Choice) -> String)? = nil
    @State private var expanded = false
    private var summary: String {
        choices.filter { selection.contains($0) }.map { $0 == random ? "综合" : (summaryLabel?($0) ?? label($0)) }.joined(separator: "、")
    }
    var body: some View {
        Button { expanded = true } label: {
            HStack {
                Text(title).foregroundStyle(.btText)
                Spacer(minLength: Spacing.md)
                Text(summary).foregroundStyle(.btPrimary).multilineTextAlignment(.trailing)
                Image(systemName: BTIcon.chevronRight).foregroundStyle(.btPrimary)
            }.contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier).accessibilityValue(summary)
        .popover(isPresented: $expanded) {
            VStack(spacing: 0) {
                ForEach(choices) { choice in
                    Button {
                        SceneTrainingConfiguration.toggle(choice, random: random, in: &selection)
                    } label: {
                        HStack(spacing: Spacing.md) {
                            BTSelectionIndicator(isSelected: selection.contains(choice))
                            Text(choice == random ? "综合" : label(choice)).foregroundStyle(.btText)
                            Spacer(minLength: 0)
                        }.padding(.horizontal, Spacing.lg).frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier(identifier + "." + String(describing: choice.id))
                        .accessibilityValue(selection.contains(choice) ? "已选" : "未选")
                        .accessibilityAddTraits(selection.contains(choice) ? .isSelected : [])
                }
            }.padding(.vertical, Spacing.sm).frame(minWidth: 250, maxWidth: 340)
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// One metric contract for the live readouts and finish panel. Invalid answers
/// count in the denominator, but never contribute an invented numeric error.
struct SceneTrainingMetrics {
    let samples: [SceneTrainingSample]
    let unit: String
    var errors: [Double] { samples.compactMap(\.error).filter { $0.isFinite }.map(abs) }
    var correct: Int { errors.filter { $0 <= (unit == "mm" ? 2 : 3) }.count }
    var rate: String { Self.percentage(correct, of: samples.count) }
    var mean: String { errors.isEmpty ? "—" : String(format: "%.1f%@", errors.reduce(0,+)/Double(errors.count), unit) }
    static func percentage(_ numerator: Int, of total: Int) -> String {
        total == 0 ? "—" : String(format: "%.1f%%", Double(numerator)*100/Double(total))
    }
}

struct SceneTrainingSummary: View {
    let samples: [SceneTrainingSample]
    let unit: String
    let onClose: (() -> Void)?
    var onRestart: (() -> Void)? = nil
    var body: some View {
        let metrics = SceneTrainingMetrics(samples: samples, unit: unit)
        TrainingFinishContent(metrics: [("题数", "\(samples.count)"), ("正确率", metrics.rate), ("均差", metrics.mean)],
                              onRestart: onRestart, onComplete: onClose)
    }
}

/// Same centered scene-decision buttons used by the table pages.
struct TrainingFinishContent: View {
    let metrics: [(String, String)]
    let onRestart: (() -> Void)?
    let onComplete: (() -> Void)?
    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.xl) {
                ForEach(metrics.indices, id: \.self) { index in
                    VStack(spacing: Spacing.xs) {
                        Text(metrics[index].0).font(.btCaption).foregroundStyle(HUDStyle.labelColor)
                        Text(metrics[index].1).font(.btHeadline).monospacedDigit().foregroundStyle(.white)
                    }
                }
            }
            HStack(spacing: Spacing.md) {
                if let onRestart {
                    Button("重新开始", action: onRestart).buttonStyle(BTSceneDecisionActionStyle())
                        .accessibilityIdentifier("training.restart")
                }
                if let onComplete {
                    Button("完成", action: onComplete).buttonStyle(BTSceneDecisionActionStyle(isPrimary: true))
                        .accessibilityIdentifier("training.complete")
                }
            }
        }.padding(Spacing.lg).environment(\.colorScheme, .dark)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("training.summary")
    }
}
