import SwiftUI

struct TrainingSummaryView: View {
    let elapsedSeconds: Int
    let drillCount: Int
    let totalSets: Int
    let totalBallsMade: Int
    let overallSuccessRate: Double
    let drillSummaries: [DrillSummary]
    let trainingNote: String
    /// Returns `true` when the session was persisted successfully.
    let onSave: () -> Bool
    let onGenerateShareImage: () -> Void
    let onViewHistory: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false
    @State private var hasSaved = false
    @State private var showSavedToast = false
    @State private var animatedRate: Double = 0
    @State private var statsRevealed = false

    /// F-TS-11: honest duration copy for sub-minute sessions.
    private var durationDisplay: (value: String, unit: String) {
        if elapsedSeconds < 60 {
            return ("不足 1", "分钟")
        }
        return ("\(elapsedSeconds / 60)", "分钟")
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: Spacing.xxl) {
                        statsGrid
                        drillBreakdownSection
                        if TrainingItemNote.visible(trainingNote) != nil {
                            noteSection
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl)
                }

                bottomActionBar
            }

            if showSavedToast {
                savedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, Spacing.md)
            }
        }
        .background(Color.btBG.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                shareButton
            }
        }
        .onAppear {
            // F-TS-01: restrained ceremony — bar grows, numbers transition in.
            withAnimation(BTMotion.springPanel) {
                animatedRate = overallSuccessRate
                statsRevealed = true
            }
        }
    }

    // MARK: - Saved Toast (F-TS-02)

    private var savedToast: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: BTIcon.checkmarkCircle)
                .foregroundStyle(.btSuccess)
            Text("已保存")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btText)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.08), radius: 8, y: 2)
    }

    // MARK: - Stats Grid (2×2 + 1 full-width)

    private var statsGrid: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                statCard(
                    label: "训练时长",
                    value: durationDisplay.value,
                    unit: durationDisplay.unit,
                    icon: "clock.fill",
                    iconColor: .btPrimary
                )
                statCard(label: "完成项目", value: "\(drillCount)", unit: "项", icon: "checklist", iconColor: .btPrimary)
            }
            HStack(spacing: Spacing.md) {
                statCard(label: "总组数", value: "\(totalSets)", unit: "组", icon: "square.grid.3x3.fill", iconColor: .btPrimary)
                statCard(label: "总进球", value: "\(totalBallsMade)", unit: "球", icon: "circle.inset.filled", iconColor: .btAccent)
            }
            successRateCard
        }
    }

    private func statCard(label: String, value: String, unit: String, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label)
                    .font(.btFootnote)
                    .foregroundStyle(.btTextTertiary)
                Spacer()
                Image(systemName: icon)
                    .font(.btHeadline)
                    .foregroundStyle(iconColor)
            }

            Spacer(minLength: Spacing.lg)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(statsRevealed ? value : "—")
                    .font(.btStatNumber).fontWeight(.heavy)
                    .foregroundStyle(.btText)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.btFootnote).fontWeight(.semibold)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.03), radius: 6, x: 0, y: 2)
        .opacity(statsRevealed ? 1 : 0.85)
    }

    private var successRateCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("平均成功率")
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(animatedRate * 100))")
                    .font(.btLargeTitle)
                    .foregroundStyle(.btText)
                    .contentTransition(.numericText())
                Text("%")
                    .font(.btCallout).fontWeight(.bold)
                    .foregroundStyle(.btTextSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.btBGTertiary)
                    Capsule()
                        .fill(Color.btPrimary)
                        .frame(width: geo.size.width * animatedRate)
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
        }
        .padding(Spacing.xl)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    // MARK: - Drill Breakdown

    private var drillBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("训练明细")
                .font(.btHeadline)
                .foregroundStyle(.btText)
                .padding(.horizontal, 2)

            ForEach(drillSummaries) { drill in
                drillCard(drill)
            }
        }
    }

    private func drillCard(_ drill: DrillSummary) -> some View {
        let itemNote = TrainingItemNote.visible(drill.note)
        return VStack(spacing: 0) {
            // Header row
            HStack(spacing: Spacing.md) {
                drillThumbnail(drillId: drill.drillId)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.sm) {
                        Text(drill.nameZh)
                            .font(.btSubheadlineMedium).fontWeight(.bold)
                            .foregroundStyle(.btText)
                            .lineLimit(1)
                        if let level = drill.level {
                            BTLevelBadge(level: level)
                        }
                    }
                    Text("\(drill.sets.count) 组 · \(drill.totalBallsMade)/\(drill.totalBallsPossible) 球")
                        .font(.btCaption)
                        .foregroundStyle(.btTextTertiary)
                }
                Spacer()
                Text("\(Int(drill.successRate * 100))%")
                    .font(.btHeadline).fontWeight(.bold)
                    .foregroundStyle(drillRateColor(drill.successRate))
            }
            .padding(Spacing.lg)

            // Separator + set rows
            Rectangle()
                .fill(Color.btSeparator.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: 0) {
                ForEach(drill.sets) { set in
                    setRow(set)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, itemNote == nil ? Spacing.lg : Spacing.sm)

            if let itemNote {
                itemNoteRow(itemNote)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
            }
        }
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: BTRadius.lg)
                .stroke(Color.btSeparator.opacity(colorScheme == .dark ? 0.3 : 0.15), lineWidth: 1)
        )
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.02), radius: 4, x: 0, y: 1)
    }

    private func drillThumbnail(drillId: String) -> some View {
        BTDrillListThumbnail(drillId: drillId)
    }

    private func itemNoteRow(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("本项心得")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
            Text(note)
                .font(.btFootnote14)
                .fontWeight(.medium)
                .foregroundStyle(.btText)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("本项心得，\(note)")
    }

    private func setRow(_ set: DrillSummary.SetResult) -> some View {
        HStack {
            Text("第 \(set.id) 组")
                .font(.btFootnote14)
                .foregroundStyle(.btTextSecondary)
            Spacer()
            Text("\(set.madeBalls)/\(set.targetBalls)")
                .font(.btFootnote14)
                .foregroundStyle(.btText)
            Image(systemName: "checkmark.circle.fill")
                .font(.btCallout)
                .foregroundStyle(.btPrimary)
        }
        .padding(.vertical, Spacing.sm)
    }

    private var shareButton: some View {
        Button(action: handleShare) {
            Image(systemName: "square.and.arrow.up")
                .font(.btBody)
                .foregroundStyle(.btPrimary)
        }
        .disabled(isSaving)
    }

    private func drillRateColor(_ rate: Double) -> Color {
        if rate >= 0.7 { return .btPrimary }
        return colorScheme == .dark ? .btTextSecondary : .btWarning
    }

    // MARK: - Training Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "square.and.pencil")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
                Text("训练心得")
                    .font(.btCallout).fontWeight(.bold)
                    .foregroundStyle(.btText)
            }

            Text(TrainingItemNote.visible(trainingNote) ?? trainingNote)
                .font(.btFootnote14).fontWeight(.medium)
                .foregroundStyle(.btTextSecondary)
                .lineSpacing(4)
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: BTRadius.lg)
                .stroke(Color.btSeparator.opacity(colorScheme == .dark ? 0.3 : 0.15), lineWidth: 1)
        )
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: Spacing.md) {
            Button(action: handleSave) {
                Text(saveButtonTitle)
            }
            .buttonStyle(BTButtonStyle.primary)
            .disabled(isSaving || showSavedToast)

            Button(action: handleShare) {
                Label("生成分享图", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(BTButtonStyle.secondary)
            .disabled(isSaving || showSavedToast)

            Button(action: onViewHistory) {
                Text("查看历史记录")
                    .font(.btFootnote)
                    .fontWeight(.bold)
                    .foregroundStyle(.btTextTertiary)
            }
            .disabled(isSaving || showSavedToast)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xl)
        .background(
            Color.btBGSecondary
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 8, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Save (F-TS-02) + Share (DR-079)

    private var saveButtonTitle: String {
        if isSaving { return "保存中…" }
        if hasSaved { return "完成" }
        return "保存训练"
    }

    /// Persist once. Share and save share this path so generating a card
    /// also writes the session; a later tap does not insert a duplicate.
    @discardableResult
    private func persistIfNeeded() -> Bool {
        if hasSaved { return true }
        isSaving = true
        let succeeded = onSave()
        isSaving = false
        if succeeded { hasSaved = true }
        return succeeded
    }

    private func handleSave() {
        guard !isSaving, !showSavedToast else { return }
        guard persistIfNeeded() else { return }
        withAnimation(BTMotion.springPanel) {
            showSavedToast = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            dismiss()
        }
    }

    /// Generate share image and persist the session in the same gesture.
    private func handleShare() {
        guard !isSaving else { return }
        guard persistIfNeeded() else { return }
        onGenerateShareImage()
    }
}

// MARK: - Previews

private let previewSummaries: [DrillSummary] = [
    DrillSummary(
        id: UUID(), drillId: "drill_c001", nameZh: "定点红球进袋", level: .L1,
        totalBallsMade: 31, totalBallsPossible: 40,
        sets: [
            .init(id: 1, madeBalls: 8, targetBalls: 10),
            .init(id: 2, madeBalls: 7, targetBalls: 10),
            .init(id: 3, madeBalls: 8, targetBalls: 10),
            .init(id: 4, madeBalls: 8, targetBalls: 10),
        ],
        note: "低杆容易扎杆，下一组改中杆"
    ),
    DrillSummary(
        id: UUID(), drillId: "drill_c002", nameZh: "斯诺克直线进袋", level: .L0,
        totalBallsMade: 28, totalBallsPossible: 30,
        sets: [
            .init(id: 1, madeBalls: 10, targetBalls: 10),
            .init(id: 2, madeBalls: 9, targetBalls: 10),
            .init(id: 3, madeBalls: 9, targetBalls: 10),
        ]
    ),
    DrillSummary(
        id: UUID(), drillId: "drill_c003", nameZh: "走位练习 A", level: .L2,
        totalBallsMade: 28, totalBallsPossible: 50,
        sets: [
            .init(id: 1, madeBalls: 6, targetBalls: 10),
            .init(id: 2, madeBalls: 5, targetBalls: 10),
            .init(id: 3, madeBalls: 6, targetBalls: 10),
            .init(id: 4, madeBalls: 5, targetBalls: 10),
            .init(id: 5, madeBalls: 6, targetBalls: 10),
        ]
    ),
]

#Preview("Light") {
    NavigationStack {
        TrainingSummaryView(
            elapsedSeconds: 2880,
            drillCount: 3,
            totalSets: 12,
            totalBallsMade: 87,
            overallSuccessRate: 0.72,
            drillSummaries: previewSummaries,
            trainingNote: "今天练习走位感觉明显进步，斯诺克直线进袋成功率很高，走位A还需要加强，下组尝试控制力道。",
            onSave: { true },
            onGenerateShareImage: {},
            onViewHistory: {}
        )
        .navigationTitle("训练总结")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Dark") {
    NavigationStack {
        TrainingSummaryView(
            elapsedSeconds: 2880,
            drillCount: 3,
            totalSets: 12,
            totalBallsMade: 87,
            overallSuccessRate: 0.72,
            drillSummaries: previewSummaries,
            trainingNote: "今天练习走位感觉明显进步，斯诺克直线进袋成功率很高，走位A还需要加强，下组尝试控制力道。",
            onSave: { true },
            onGenerateShareImage: {},
            onViewHistory: {}
        )
        .navigationTitle("训练总结")
        .navigationBarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
}

#Preview("No Note") {
    NavigationStack {
        TrainingSummaryView(
            elapsedSeconds: 45,
            drillCount: 2,
            totalSets: 6,
            totalBallsMade: 42,
            overallSuccessRate: 0.42,
            drillSummaries: [
                DrillSummary(
                    id: UUID(), drillId: "drill_c004", nameZh: "握杆稳定性训练", level: .L0,
                    totalBallsMade: 8, totalBallsPossible: 20,
                    sets: [
                        .init(id: 1, madeBalls: 4, targetBalls: 10),
                        .init(id: 2, madeBalls: 4, targetBalls: 10),
                    ]
                ),
                DrillSummary(
                    id: UUID(), drillId: "drill_c005", nameZh: "中杆定杆基础", level: .L0,
                    totalBallsMade: 5, totalBallsPossible: 20,
                    sets: [
                        .init(id: 1, madeBalls: 2, targetBalls: 10),
                        .init(id: 2, madeBalls: 3, targetBalls: 10),
                    ]
                ),
            ],
            trainingNote: "",
            onSave: { true },
            onGenerateShareImage: {},
            onViewHistory: {}
        )
        .navigationTitle("训练总结")
        .navigationBarTitleDisplayMode(.inline)
    }
}
