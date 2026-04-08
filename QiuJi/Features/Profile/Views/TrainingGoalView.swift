import SwiftUI
import SwiftData

struct TrainingGoalView: View {
    @ObservedObject private var prefs = UserPreferences.shared
    @Query private var sessions: [TrainingSession]
    @Environment(\.calendar) private var calendar

    private let durationOptions = [0, 30, 45, 60, 90, 120]

    var body: some View {
        ZStack {
            Color.btBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    progressSection
                    weeklyGoalSection
                    durationSection
                    reminderSection
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .navigationTitle("训练目标")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Progress Ring

    private var progressSection: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(Color.btPrimary.opacity(0.15), lineWidth: 10)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: weeklyProgress)
                    .stroke(Color.btPrimary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: weeklyProgress)

                VStack(spacing: 2) {
                    Text("\(daysTrainedThisWeek)")
                        .font(.btStatNumber)
                        .foregroundStyle(.btPrimary)
                    Text("/ \(prefs.weeklyGoalDays) 天")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                }
            }

            HStack(spacing: Spacing.xxl) {
                VStack(spacing: 2) {
                    Text("\(daysTrainedThisWeek) / \(prefs.weeklyGoalDays)")
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                    Text("本周训练")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                }

                Divider().frame(height: 32)

                VStack(spacing: 2) {
                    Text(monthlyRateText)
                        .font(.btHeadline)
                        .foregroundStyle(.btAccent)
                    Text("本月达成率")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .padding(.horizontal, Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Weekly Goal

    private var weeklyGoalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("每周训练天数")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                ForEach(1...7, id: \.self) { days in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            prefs.weeklyGoalDays = days
                        }
                    } label: {
                        HStack {
                            Text("\(days) 天")
                                .font(.btBody)
                                .foregroundStyle(.btText)

                            Spacer()

                            if prefs.weeklyGoalDays == days {
                                Image(systemName: "checkmark")
                                    .font(.btSubheadlineMedium)
                                    .foregroundStyle(.btPrimary)
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if days < 7 {
                        Divider().padding(.leading, Spacing.lg)
                    }
                }
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    // MARK: - Session Duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("每次训练时长目标")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                ForEach(durationOptions, id: \.self) { minutes in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            prefs.targetSessionMinutes = minutes
                        }
                    } label: {
                        HStack {
                            Text(minutes == 0 ? "不限" : "\(minutes) 分钟")
                                .font(.btBody)
                                .foregroundStyle(.btText)

                            Spacer()

                            if prefs.targetSessionMinutes == minutes {
                                Image(systemName: "checkmark")
                                    .font(.btSubheadlineMedium)
                                    .foregroundStyle(.btPrimary)
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if minutes != durationOptions.last {
                        Divider().padding(.leading, Spacing.lg)
                    }
                }
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    // MARK: - Reminder

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("训练提醒")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                HStack {
                    Text("开启提醒")
                        .font(.btBody)
                        .foregroundStyle(.btText)

                    Spacer()

                    Toggle("", isOn: $prefs.reminderEnabled)
                        .tint(.btPrimary)
                        .labelsHidden()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)

                if prefs.reminderEnabled {
                    Divider().padding(.leading, Spacing.lg)

                    HStack {
                        Text("提醒时间")
                            .font(.btBody)
                            .foregroundStyle(.btText)

                        Spacer()

                        DatePicker("", selection: $prefs.reminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(.btPrimary)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                }
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            .animation(.easeInOut(duration: 0.2), value: prefs.reminderEnabled)
        }
    }

    // MARK: - Computed Properties

    private var daysTrainedThisWeek: Int {
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        let uniqueDays = Set(sessions.filter { $0.date >= weekStart }.map {
            calendar.startOfDay(for: $0.date)
        })
        return uniqueDays.count
    }

    private var weeklyProgress: CGFloat {
        guard prefs.weeklyGoalDays > 0 else { return 0 }
        return min(CGFloat(daysTrainedThisWeek) / CGFloat(prefs.weeklyGoalDays), 1.0)
    }

    private var monthlyRateText: String {
        let now = Date()
        guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else { return "—" }

        let weeksElapsed = max(1, calendar.dateComponents([.weekOfMonth], from: monthStart, to: now).weekOfMonth ?? 1)
        let totalGoalDays = weeksElapsed * prefs.weeklyGoalDays
        guard totalGoalDays > 0 else { return "—" }

        let uniqueDays = Set(sessions.filter { $0.date >= monthStart }.map {
            calendar.startOfDay(for: $0.date)
        })
        let rate = Int(min(Double(uniqueDays.count) / Double(totalGoalDays) * 100, 100))
        return "\(rate)%"
    }
}

#Preview("Training Goal") {
    NavigationStack {
        TrainingGoalView()
    }
    .modelContainer(for: TrainingSession.self, inMemory: true)
}

#Preview("Training Goal Dark") {
    NavigationStack {
        TrainingGoalView()
    }
    .modelContainer(for: TrainingSession.self, inMemory: true)
    .preferredColorScheme(.dark)
}
