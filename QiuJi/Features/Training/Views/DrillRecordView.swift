import SwiftUI

struct DrillRecordView: View {
    let drill: ActiveDrill
    @Binding var setsData: [DrillSetData]
    /// 本 drill 的训练心得，落 `DrillEntry.note`（契约 §8.7）。
    @Binding var note: String
    var onAddSet: () -> Void
    var onCompleteSet: (Int) -> Void
    var onDeleteSet: ((Int) -> Void)?
    @Binding var restDuration: Int
    var showRestTimerSetting: Bool = true
    /// 多球形 drill 的可选球形；为空表示单球形，不出选择 UI。
    var formationOptions: [DrillFormationOption] = []
    /// 「添加一组」结构化选项（球形 × 杆）；非空时加号出选择菜单。
    var addSetChoices: [DrillAddSetChoice] = []
    var onAddSetChoice: ((DrillAddSetChoice, Int?) -> Void)? = nil

    /// Default expanded (球台示意).
    @State private var showBallTable = true
    @State private var showSetTimer = true
    @State private var showSuccessRate = true
    @State private var showRestPicker = false
    @State private var activeSetStartTime: Date?
    @State private var tutorialDrill: DrillContent?
    @State private var tableDrillContent: DrillContent?
    @State private var showTutorialUnavailable = false
    @Environment(\.colorScheme) private var colorScheme

    private var totalMade: Int {
        setsData.reduce(0) { $0 + $1.madeBalls }
    }

    private var totalTarget: Int {
        setsData.reduce(0) { $0 + $1.targetBalls }
    }

    private var successRate: Double {
        guard totalTarget > 0 else { return 0 }
        return Double(totalMade) / Double(totalTarget)
    }

    private var isAllCompleted: Bool {
        !setsData.isEmpty && setsData.allSatisfy { $0.isCompleted }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                drillInfoHeader

                noteInputRow

                if showRestTimerSetting {
                    restSettingsRow
                    trainingToggles
                }

                if !formationOptions.isEmpty {
                    formationHint
                }

                BTSetInputGrid(
                    sets: $setsData,
                    onAddSet: onAddSet,
                    onComplete: handleCompleteSet,
                    onDeleteSet: onDeleteSet,
                    showSetTimer: showSetTimer,
                    showSuccessRate: showSuccessRate,
                    formationOptions: formationOptions,
                    sectionByFormation: true,
                    addSetChoices: addSetChoices,
                    onAddSetChoice: onAddSetChoice
                )

                if totalTarget > 0 {
                    liveStatsBanner
                }

                ballTableSection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .task(id: drill.drillId) {
            tableDrillContent = await DrillContentService.shared.loadDrillFromBundle(id: drill.drillId)
        }
        .onAppear {
            if showSetTimer {
                activeSetStartTime = Date()
            }
        }
        .onChange(of: showSetTimer) { _, newValue in
            activeSetStartTime = newValue ? Date() : nil
        }
        // F-TU-05: keep sheet presentation; unify chrome (close + detent + drag indicator).
        .sheet(item: $tutorialDrill) { content in
            NavigationStack {
                DrillTutorialView(drill: content)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                tutorialDrill = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.btTextSecondary)
                                    .font(.btTitle2)
                            }
                            .accessibilityLabel("关闭")
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // F-TU-11: honest feedback when bundle load returns nil
        .alert("暂时无法打开精讲", isPresented: $showTutorialUnavailable) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("当前训练项的精讲内容暂不可用，请稍后再试。")
        }
    }

    // MARK: - Drill Info Header

    private var drillInfoHeader: some View {
        BTExerciseRow(
            drillName: drill.nameZh,
            drillId: drill.drillId,
            totalSets: setsData.count,
            completedSets: setsData.filter { $0.isCompleted }.count,
            madeBalls: totalMade,
            targetBalls: totalTarget,
            accessory: .tutorial,
            onTap: openTutorial
        )
    }

    private func openTutorial() {
        let drillId = drill.drillId
        Task {
            let content = await DrillContentService.shared.loadDrillFromBundle(id: drillId)
            await MainActor.run {
                if let content {
                    tutorialDrill = content
                } else {
                    showTutorialUnavailable = true
                }
            }
        }
    }

    // MARK: - Live Stats Banner

    private var liveStatsBanner: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: isAllCompleted ? BTIcon.completeSeal : BTIcon.chartBarFilled)
                .font(.btStatNumber)
                .foregroundStyle(isAllCompleted ? .btSuccess : .btPrimary)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(isAllCompleted ? "本项训练完成" : "训练进行中")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)

                HStack(spacing: Spacing.xs) {
                    // F-AT-09: numericText on made/target as well as rate
                    Text("共进球 \(totalMade)/\(totalTarget)")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                        .contentTransition(.numericText())
                        .animation(BTMotion.easeFast, value: totalMade)

                    if totalTarget > 0 {
                        Text("·")
                            .foregroundStyle(.btTextTertiary)
                        Text("\(Int(successRate * 100))%")
                            .font(.btCaption)
                            .fontWeight(.medium)
                            .foregroundStyle(successRateColor)
                            .contentTransition(.numericText())
                            .animation(BTMotion.easeFast, value: totalMade)
                    }
                }
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .background(isAllCompleted ? Color.btSuccess.opacity(0.1) : Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .animation(BTMotion.easeFast, value: isAllCompleted)
    }

    // MARK: - Note Input

    private var noteInputRow: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "doc.text")
                .font(.btCallout)
                .foregroundStyle(.btTextTertiary)

            TextField("记录本项心得...", text: $note, axis: .vertical)
                .font(.btCallout)
                .foregroundStyle(.btText)
                .lineLimit(1...4)
        }
        .padding(Spacing.md)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .shadow(
            color: colorScheme == .dark ? .clear : Color.black.opacity(0.04),
            radius: 4, x: 0, y: 1
        )
    }

    /// 多球形动作：提示逐组在「球形」列选择本组打的球形。
    private var formationHint: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "square.stack.3d.up")
                .font(.btCaption)
                .foregroundStyle(.btPrimary)
            Text("本动作有 \(formationOptions.count) 个球形，已按球形分节；也可在「球形」列调整")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Rest Settings Row

    private var restSettingsRow: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "timer")
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)

            Text("休息设置")
                .font(.btCallout)
                .foregroundStyle(.btText)

            Spacer()

            Text("\(restDuration)s")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btPrimary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color.btPrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))

            Button {
                showRestPicker = true
            } label: {
                Text("设置")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btPrimary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .sheet(isPresented: $showRestPicker) {
            restDurationPicker
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
    }

    private var restDurationPicker: some View {
        VStack(spacing: Spacing.lg) {
            Text("休息时长")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            Picker("休息时长", selection: $restDuration) {
                Text("30s").tag(30)
                Text("45s").tag(45)
                Text("60s").tag(60)
                Text("90s").tag(90)
                Text("120s").tag(120)
            }
            .pickerStyle(.wheel)

            Button("确定") {
                showRestPicker = false
            }
            .buttonStyle(BTButtonStyle.primary)
            .padding(.horizontal, Spacing.xxl)
        }
        .padding(.vertical, Spacing.lg)
    }

    // MARK: - Training Toggles

    private var trainingToggles: some View {
        HStack(spacing: Spacing.xl) {
            toggleItem(label: "每组计时", isOn: $showSetTimer)
            toggleItem(label: "显示成功率", isOn: $showSuccessRate)
            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
    }

    private func toggleItem(label: String, isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation(BTMotion.easeFast) {
                isOn.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: isOn.wrappedValue ? BTIcon.checkmark : "")
                    .font(.btCaption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.btPrimary)
                    .frame(width: 16, height: 16)

                Text(label)
                    .font(.btFootnote14)
                    .foregroundStyle(isOn.wrappedValue ? .btText : .btTextSecondary)
            }
        }
        .buttonStyle(BTPressableStyle.row)
    }

    // MARK: - Ball Table

    private var ballTableSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // F-AT-03: single chevron + rotation; content transition via springPanel
            Button {
                withAnimation(BTMotion.springPanel) {
                    showBallTable.toggle()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text("球台示意")
                        .font(.btSubheadlineMedium)
                        .foregroundStyle(.btText)
                    Image(systemName: BTIcon.chevronDown)
                        .font(.btCaption.weight(.medium))
                        .foregroundStyle(.btTextTertiary)
                        .rotationEffect(.degrees(showBallTable ? 180 : 0))
                }
            }
            .buttonStyle(BTPressableStyle.row)

            if showBallTable {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    // Live detail preview: true-size balls (ballScale 1.0), full table — not baked 1.8× thumbnails.
                    if let content = tableDrillContent {
                        DrillSceneView(drill: content)
                    } else {
                        BTBakedDrillTable(drillId: drill.drillId, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                    }

                    if !drill.description.isEmpty {
                        Text(drill.description)
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .shadow(
            color: colorScheme == .dark ? .clear : Color.black.opacity(0.04),
            radius: 4, x: 0, y: 1
        )
    }

    private var successRateColor: Color {
        if successRate >= 0.9 { return .btSuccess }
        if successRate >= 0.7 { return .btPrimary }
        return .btTextSecondary
    }

    // MARK: - Set Completion with Timer

    private func handleCompleteSet(_ index: Int) {
        if showSetTimer && !setsData[index].isCompleted {
            if let startTime = activeSetStartTime {
                setsData[index].duration = Date().timeIntervalSince(startTime)
            }
        } else if setsData[index].isCompleted {
            setsData[index].duration = nil
        }
        onCompleteSet(index)
        if showSetTimer {
            activeSetStartTime = Date()
        }
    }
}

// MARK: - Preview

#Preview("DrillRecordView Light") {
    DrillRecordPreview()
        .background(Color.btBG)
}

#Preview("DrillRecordView Dark") {
    DrillRecordPreview()
        .background(Color.btBG)
        .preferredColorScheme(.dark)
}

private struct DrillRecordPreview: View {
    @State private var sets: [DrillSetData] = [
        DrillSetData(id: 1, madeBalls: 8, targetBalls: 10, isCompleted: true, isWarmup: true),
        DrillSetData(id: 2, madeBalls: 15, targetBalls: 18, isCompleted: true),
        DrillSetData(id: 3, madeBalls: 13, targetBalls: 18),
        DrillSetData(id: 4, targetBalls: 15),
        DrillSetData(id: 5, targetBalls: 15),
    ]
    @State private var restDuration = 60
    @State private var note = ""

    var body: some View {
        DrillRecordView(
            drill: ActiveDrill(
                drillId: "drill_c023",
                nameZh: "五分点直球",
                description: "母球定点击打目标球进袋",
                coachingPoints: ["保持出杆平稳", "瞄准球的中心"],
                sets: 5,
                ballsPerSet: 15,
                phaseType: "focused",
                phaseZh: "专项训练",
                animation: DrillAnimation(
                    cueBall: BallAnimation(
                        start: CanvasPoint(x: 0.5, y: 0.35),
                        path: [PathPoint(x: 0.5, y: 0.15)]
                    ),
                    targetBall: BallAnimation(
                        start: CanvasPoint(x: 0.5, y: 0.15),
                        path: [PathPoint(x: 0.5, y: -0.02)]
                    ),
                    pocket: "topCenter",
                    cueDirection: CanvasPoint(x: 0, y: -1)
                )
            ),
            setsData: $sets,
            note: $note,
            onAddSet: { sets.append(DrillSetData(id: sets.count + 1, targetBalls: 15)) },
            onCompleteSet: { sets[$0].isCompleted.toggle() },
            onDeleteSet: { sets.remove(at: $0) },
            restDuration: $restDuration,
            formationOptions: [
                DrillFormationOption(token: "manual01", name: "五分点直球 · 球形1"),
                DrillFormationOption(token: "manual02", name: "五分点直球 · 球形2"),
            ]
        )
    }
}
