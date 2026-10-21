import SwiftUI

/// Cancel discards this form's draft; a validated batch is required before starting.
struct SceneTrainingSettings<Batch>: View {
    let route: String
    let restarting: Bool
    let prepareBatch: (SceneTrainingConfiguration) throws -> Batch
    let showsSpinOptions: Bool
    let onStart: (SceneTrainingConfiguration, Batch) -> Void
    let onCancel: () -> Void
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var showSubscription = false
    @State private var draft: SceneTrainingConfiguration
    @State private var preparing = false
    @State private var conditionsExpanded = true
    @State private var error: String?
    @State private var generation: Task<Void, Never>?
    init(route: String, configuration: SceneTrainingConfiguration, restarting: Bool,
         showsSpinOptions: Bool = false,
         prepareBatch: @escaping (SceneTrainingConfiguration) throws -> Batch,
         onStart: @escaping (SceneTrainingConfiguration, Batch) -> Void,
         onCancel: @escaping () -> Void) {
        self.route = route; self.restarting = restarting; self.onStart = onStart; self.onCancel = onCancel
        self.prepareBatch = prepareBatch; self.showsSpinOptions = showsSpinOptions
        _draft = State(initialValue: configuration)
    }
    var body: some View {
        Form {
            Section("练习模式") {
                Picker("练习模式", selection: Binding(get: { draft.freePractice }, set: { requested in
                    if requested && !subscription.isPremium { showSubscription = true }
                    else { draft.freePractice = requested }
                })) {
                    Text("20题").tag(false); Text("自由练习").tag(true)
                }.pickerStyle(.segmented).accessibilityIdentifier("training.length")
            }
            if !subscription.isPremium {
                Section {
                    Text("今天剩余 \(AngleUsageLimiter.training(route: route).remainingToday) 题 · 每个2D训练每天20题")
                        .font(.btCaption).foregroundStyle(.btTextSecondary)
                }
            }
            Section("角度范围") {
                ForEach(SceneTrainingConfiguration.AngleRange.allCases) { range in
                    Button { SceneTrainingConfiguration.toggle(range, random: .mixed, in: &draft.angleSelection) } label: {
                        HStack {
                            Text(range.label).foregroundStyle(.btText)
                            Spacer()
                            BTSelectionIndicator(isSelected: draft.angleSelection.contains(range))
                        }
                    }.accessibilityIdentifier("training.range." + range.rawValue)
                        .accessibilityValue(draft.angleSelection.contains(range) ? "已选" : "未选")
                        .accessibilityAddTraits(draft.angleSelection.contains(range) ? .isSelected : [])
                }
            }
            Section {
                DisclosureGroup("球形条件", isExpanded: $conditionsExpanded) {
                    TrainingMultiSelectRow(title: "母球距离", identifier: "training.cueDistance",
                        selection: $draft.cueDistanceSelection, choices: SceneTrainingConfiguration.Distance.allCases,
                        random: .mixed, label: { $0.label(cue: true) }, summaryLabel: { $0.shortLabel })
                    TrainingMultiSelectRow(title: "目标球距袋", identifier: "training.pocketDistance",
                        selection: $draft.pocketDistanceSelection, choices: SceneTrainingConfiguration.Distance.allCases,
                        random: .mixed, label: { $0.label(cue: false) }, summaryLabel: { $0.shortLabel })
                    TrainingMultiSelectRow(title: "袋口类型", identifier: "training.pockets",
                        selection: $draft.pocketSelection, choices: SceneTrainingConfiguration.Pockets.allCases,
                        random: .mixed, label: { $0.label })
                    TrainingMultiSelectRow(title: "库边距离", identifier: "training.railDistance",
                        selection: $draft.railDistanceSelection, choices: SceneTrainingConfiguration.RailDistance.allCases,
                        random: .mixed, label: { $0.label })
                }
                Text("母球距离按两球中心计算；距袋按目标球到有效进袋瞄点计算。半贴库指目标球表面离库不超过10厘米，贴库单独选择。")
                    .font(.btCaption).foregroundStyle(.btTextSecondary)
            }
            if showsSpinOptions {
                Section {
                    Toggle("允许高低杆", isOn: $draft.allowsVerticalSpin)
                        .accessibilityIdentifier("training.verticalSpin")
                    Toggle("允许左右塞", isOn: $draft.allowsSideSpin)
                        .accessibilityIdentifier("training.sideSpin")
                } header: { Text("出题杆法") } footer: {
                    Text("开启后，题目会指定相应打点。练习中只调整方向和力度，打点不可更改。")
                }
            }
            if let error {
                Section {
                    Text(error).foregroundStyle(.btDestructive).accessibilityIdentifier("training.generationError")
                    Button("重新生成", action: prepare)
                }
            }
            if preparing { ProgressView("正在检查球形条件…") }
        }
        .disabled(preparing)
        .navigationTitle("训练设置").navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(restarting ? "重新开始" : "开始训练", action: prepare)
                    .disabled(preparing).accessibilityIdentifier(route.hasPrefix("accuracy") ? "accuracy.start" : (route.hasPrefix("aimPoint") ? "aimPointTraining.start" : "angleTraining.start"))
            }
            ToolbarItem(placement: .cancellationAction) {
                Button(restarting ? "取消" : "返回") { generation?.cancel(); onCancel() }
                    .accessibilityIdentifier("training.settingsCancel")
            }
        }
        .onAppear {
            if !restarting { draft = .load(for: route) }
            if !subscription.isPremium { draft.freePractice = false }
        }
        .onChange(of: subscription.isPremium) { _, premium in if !premium { draft.freePractice = false } }
        .sheet(isPresented: $showSubscription) { SubscriptionView() }
        .onDisappear { generation?.cancel() }
    }
    private func prepare() {
        let limiter = AngleUsageLimiter.training(route: route)
        limiter.refreshDay(); limiter.isPremium = subscription.isPremium
        guard subscription.isPremium || (!draft.freePractice && !limiter.isLimitReached && !route.hasSuffix("3D")) else {
            showSubscription = true; return
        }
        preparing = true; error = nil
        let configuration = draft
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
                configuration.save(for: route)
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
                return try bank.baseBatch(configuration, seed: UInt64.random(in: 0...UInt64.max)).map(\.question)
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
        choices.filter { selection.contains($0) }.map { summaryLabel?($0) ?? label($0) }.joined(separator: "、")
    }
    var body: some View {
        Button { expanded = true } label: {
            HStack {
                Text(title).foregroundStyle(.btText)
                Spacer(minLength: Spacing.md)
                Text(summary).foregroundStyle(.btPrimary).multilineTextAlignment(.trailing)
                Image(systemName: BTIcon.chevronRight).foregroundStyle(.btPrimary)
            }.frame(minHeight: 44).contentShape(Rectangle())
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
                            Text(label(choice)).foregroundStyle(.btText)
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
