import SwiftUI

/// Cancel discards this form's draft; a validated batch is required before starting.
struct SceneTrainingSettings: View {
    let route: String
    let restarting: Bool
    let onStart: (SceneTrainingConfiguration, [SceneTrainingQuestion]) -> Void
    let onCancel: () -> Void
    @State private var draft: SceneTrainingConfiguration
    @State private var preparing = false
    @State private var conditionsExpanded = true
    @State private var error: String?
    @State private var generation: Task<Void, Never>?
    init(route: String, configuration: SceneTrainingConfiguration, restarting: Bool,
         onStart: @escaping (SceneTrainingConfiguration, [SceneTrainingQuestion]) -> Void,
         onCancel: @escaping () -> Void) {
        self.route = route; self.restarting = restarting; self.onStart = onStart; self.onCancel = onCancel
        _draft = State(initialValue: configuration)
    }
    var body: some View {
        Form {
            Section("练习模式") {
                Picker("练习模式", selection: $draft.freePractice) {
                    Text("20题").tag(false); Text("自由练习").tag(true)
                }.pickerStyle(.segmented).accessibilityIdentifier("training.length")
            }
            Section("角度范围") {
                ForEach(SceneTrainingConfiguration.AngleRange.allCases) { range in
                    Button { draft.angles = range } label: {
                        HStack {
                            Text(range.label).foregroundStyle(.btText)
                            Spacer()
                            BTSelectionIndicator(isSelected: draft.angles == range)
                        }
                    }.accessibilityIdentifier("training.range." + range.rawValue)
                        .accessibilityValue(draft.angles == range ? "已选" : "未选")
                        .accessibilityAddTraits(draft.angles == range ? .isSelected : [])
                }
            }
            Section {
                DisclosureGroup("球形条件", isExpanded: $conditionsExpanded) {
                    Picker("母球距离", selection: $draft.cueDistance) {
                        ForEach(SceneTrainingConfiguration.Distance.allCases) { Text($0.label(cue: true)).tag($0) }
                    }.accessibilityIdentifier("training.cueDistance")
                    Picker("目标球距袋", selection: $draft.pocketDistance) {
                        ForEach(SceneTrainingConfiguration.Distance.allCases) { Text($0.label(cue: false)).tag($0) }
                    }.accessibilityIdentifier("training.pocketDistance")
                    Picker("袋口类型", selection: $draft.pockets) {
                        ForEach(SceneTrainingConfiguration.Pockets.allCases) { Text($0.label).tag($0) }
                    }.accessibilityIdentifier("training.pockets")
                }
                Text("母球距离按两球中心计算；距袋按目标球到有效进袋瞄点计算。混合只安排可行档位，开始后可在更多菜单查看本轮覆盖。")
                    .font(.btCaption).foregroundStyle(.btTextSecondary)
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
                    .disabled(preparing).accessibilityIdentifier(route.hasPrefix("aimPoint") ? "aimPointTraining.start" : "angleTraining.start")
            }
            ToolbarItem(placement: .cancellationAction) {
                Button(restarting ? "取消" : "返回") { generation?.cancel(); onCancel() }
                    .accessibilityIdentifier("training.settingsCancel")
            }
        }
        .onAppear { if !restarting { draft = .load(for: route) } }
        .onDisappear { generation?.cancel() }
    }
    private func prepare() {
        preparing = true; error = nil
        let configuration = draft
        generation = Task {
            let outcome = await Task.detached(priority: .userInitiated) { () -> Result<[SceneTrainingQuestion], Error> in
                Result {
                    var generator = SceneTrainingGenerator()
                    return try generator.batch(configuration)
                }
            }.value
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

struct SceneTrainingSummary: View {
    let samples: [SceneTrainingSample]
    let unit: String
    let onClose: (() -> Void)?
    private var threshold: Double { unit == "mm" ? 2 : 3 }
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("本轮总结").font(.btTitle2)
            Text("已答 \(samples.count) 题")
            groupSummary(assisted: false)
            groupSummary(assisted: true)
            Text("分项观察（独立作答）").font(.btHeadline)
            ForEach(SceneTrainingConfiguration.AngleRange.allCases.filter { $0 != .mixed }) { range in
                let group = samples.filter { !$0.assisted && range.degrees.contains(Int($0.angle.rounded())) }
                Text("\(range.label)：\(group.count)题" + (group.count < 5 ? "，样本不足5题" : "，达标\(group.filter { ($0.error ?? .infinity) <= threshold }.count)题"))
                    .font(.btCaption)
            }
            let independent = samples.filter { !$0.assisted }.compactMap(\.signedError)
            Text("\(unit == "mm" ? "偏薄" : "估大") \(independent.filter { $0 > 0.05 }.count) · \(unit == "mm" ? "偏厚" : "估小") \(independent.filter { $0 < -0.05 }.count)")
                .font(.btCaption)
            if let onClose {
                Button("返回训练设置", action: onClose).buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("training.summaryClose")
            }
        }.padding(Spacing.lg).frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.primary)
            .background {
                if onClose == nil {
                    RoundedRectangle(cornerRadius: BTRadius.lg).fill(Color.btBGSecondary)
                } else {
                    Color.clear.btHudGlass(in: RoundedRectangle(cornerRadius: BTRadius.lg))
                }
            }
            .accessibilityIdentifier("training.summary")
    }
    private func groupSummary(assisted: Bool) -> some View {
        let group = samples.filter { $0.assisted == assisted }
        let valid = group.compactMap(\.error)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("\(assisted ? "辅助" : "独立")作答 · \(group.count)题").font(.btHeadline)
            Text("达标 \(valid.filter { $0 <= threshold }.count)/\(group.count) · 异常 \(group.count - valid.count)")
            Text(valid.isEmpty ? "平均误差 —（0个有效数值）" : String(format: "平均误差 %.1f%@（%d个有效数值）", valid.reduce(0,+) / Double(valid.count), unit, valid.count))
        }
    }
}
