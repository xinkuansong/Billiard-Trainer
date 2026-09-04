import SwiftUI

/// Single-session angle training detail. Mirrors the structure of
/// `TrainingDetailView` (drill-based) so the two kinds of "training records"
/// feel consistent when opened from `HistoryCalendarView`:
///
///   • header: training name + date
///   • stat grid: totals (题数 / 平均误差 / 最佳 / 正确率)
///   • per-question list (actual / user / error)
///
/// Everything is computed from the `CognitiveSessionItem` value type — the
/// view has no external side-effects and no SwiftData dependencies.
///
/// v29 W6：载体从 `AngleTrainingSession` 内存投影换成 `kind="cognitive"` 的真会话，
/// 标题用会话名快照（契约 §6.5），时长用会话真字段。
struct AngleSessionDetailView: View {
    let session: CognitiveSessionItem

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                header
                statsGrid
                questionsSection
            }
            .padding(Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .background(.btBG)
        .navigationTitle(session.displayNameZh)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: AngleQuizType(rawValue: session.quizType).iconSystemName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.btPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.btPrimary.opacity(colorScheme == .dark ? 0.15 : 0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayNameZh)
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                    Text(headerSubtitle)
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                }
            }
        }
    }

    private var headerSubtitle: String {
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "zh_CN")
        dateFmt.dateFormat = "yyyy年M月d日"
        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "zh_CN")
        timeFmt.dateFormat = "HH:mm"
        let day = dateFmt.string(from: session.startDate)
        let start = timeFmt.string(from: session.startDate)
        let end   = timeFmt.string(from: session.endDate)
        let range = start == end ? start : "\(start)-\(end)"
        return "\(day) · \(range) · \(session.durationMinutes) 分钟"
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                  spacing: Spacing.lg) {
            statCard(icon: "number", iconColor: .btPrimary,
                     label: "总题数", value: "\(session.questionCount)")
            statCard(icon: "arrow.left.arrow.right", iconColor: .btDataSecondary,
                     label: "平均误差", value: String(format: "%.1f°", session.averageError))
            statCard(icon: "trophy.fill", iconColor: .btPrimary,
                     label: "最佳成绩", value: String(format: "%.1f°", session.bestError))
            statCard(icon: "checkmark.circle.fill", iconColor: .btPrimary,
                     label: "正确率", value: String(format: "%.0f%%", session.accurateRate * 100))
        }
    }

    private func statCard(icon: String, iconColor: Color, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.btCallout)
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .textCase(.uppercase)
            }
            Text(value)
                .font(.btStatNumber)
                .foregroundStyle(.btText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.02),
                radius: 4, x: 0, y: 1)
    }

    // MARK: - Questions

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("题目明细")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
                Spacer()
                Text("\(session.results.count) 题")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }

            VStack(spacing: Spacing.sm) {
                ForEach(Array(questionsSortedByTime.enumerated()), id: \.element.id) { idx, result in
                    questionRow(index: idx + 1, result: result)
                }
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.02),
                radius: 4, x: 0, y: 1)
    }

    private var questionsSortedByTime: [AngleTestResult] {
        session.results.sorted { $0.date < $1.date }
    }

    private func questionRow(index: Int, result: AngleTestResult) -> some View {
        HStack(spacing: Spacing.md) {
            Text("#\(index)")
                .font(.btCaption)
                .fontWeight(.medium)
                .foregroundStyle(.btTextTertiary)
                .frame(width: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.md) {
                    valueLabel("实际", value: String(format: "%.0f°", result.actualAngle))
                    valueLabel("你答", value: String(format: "%.0f°", result.userAngle))
                }
                Text(pocketLabel(for: result))
                    .font(.btCaption2)
                    .foregroundStyle(.btTextTertiary)
            }

            Spacer()

            errorBadge(result.error)
        }
        .padding(.vertical, Spacing.xs)
    }

    private func valueLabel(_ label: String, value: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.btCaption2)
                .foregroundStyle(.btTextTertiary)
            Text(value)
                .font(.btCaption)
                .fontWeight(.medium)
                .foregroundStyle(.btText)
        }
    }

    private func errorBadge(_ error: Double) -> some View {
        let color: Color = {
            if error <= 3 { return .btSuccess }
            if error <= 10 { return .btWarning }
            return .btDestructive
        }()
        return Text(String(format: "±%.1f°", error))
            .font(.btCaption)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func pocketLabel(for result: AngleTestResult) -> String {
        switch result.pocketType {
        case "corner": return "角袋"
        case "side":   return "中袋"
        case "geometric": return "几何"
        default:       return result.pocketType
        }
    }
}

#Preview("Light") {
    NavigationStack {
        AngleSessionDetailView(session: CognitiveSessionItem.preview)
    }
}

#Preview("Dark") {
    NavigationStack {
        AngleSessionDetailView(session: CognitiveSessionItem.preview)
    }
    .preferredColorScheme(.dark)
}

private extension CognitiveSessionItem {
    static var preview: CognitiveSessionItem {
        let now = Date()
        let results: [AngleTestResult] = (0..<8).map { i in
            let r = AngleTestResult(
                actualAngle: Double.random(in: 10...80),
                userAngle: Double.random(in: 10...80),
                pocketType: i % 2 == 0 ? "corner" : "side",
                quizType: "scene2D"
            )
            r.date = now.addingTimeInterval(-Double(8 - i) * 60)
            return r
        }
        return CognitiveSessionItem(
            id: UUID(),
            displayNameZh: "2D 角度训练",
            quizType: "scene2D",
            startDate: results.first?.date ?? now,
            endDate: results.last?.date ?? now,
            durationMinutes: 8,
            results: results
        )
    }
}
