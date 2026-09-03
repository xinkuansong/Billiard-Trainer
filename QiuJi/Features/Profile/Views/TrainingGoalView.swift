import SwiftUI
import SwiftData

/// 周目标 / 月达成率的计数口径（契约 §5.3）。
///
/// ⛔ `kind="tool"` 不计：工具使用只记活跃度，把它算成「训练了一天」会虚高目标完成度。
/// 计入的是 `drill` + `cognitive`。
enum TrainingGoalMetrics {

    struct MonthlyOverview: Equatable {
        let trainingDays: Int
        let durationMinutes: Int
        let longestStreak: Int

        var formattedDuration: String {
            let hours = durationMinutes / 60
            let minutes = durationMinutes % 60
            if hours > 0 { return "\(hours)h\(minutes)m" }
            return "\(minutes)m"
        }
    }

    /// 计入目标的会话子集。
    static func goalCounting(_ sessions: [TrainingSession]) -> [TrainingSession] {
        sessions.filter { TrainingSessionKind.countsTowardGoal($0.kind) }
    }

    /// `since` 之后（含）有计入目标的会话的自然日天数。
    static func daysTrained(_ sessions: [TrainingSession],
                            since: Date,
                            calendar: Calendar) -> Int {
        let days = goalCounting(sessions)
            .filter { $0.date >= since }
            .map { calendar.startOfDay(for: $0.date) }
        return Set(days).count
    }

    /// 当前自然月概览。训练量口径与统计页一致：`drill + cognitive`，排除 `tool`。
    static func monthlyOverview(_ sessions: [TrainingSession],
                                at date: Date,
                                calendar: Calendar) -> MonthlyOverview {
        guard let month = calendar.dateInterval(of: .month, for: date) else {
            return MonthlyOverview(trainingDays: 0, durationMinutes: 0, longestStreak: 0)
        }

        let counted = goalCounting(sessions).filter {
            $0.date >= month.start && $0.date < month.end
        }
        let trainedDays = Set(counted.map { calendar.startOfDay(for: $0.date) })
        let durationMinutes = counted.reduce(0) { $0 + $1.totalDurationMinutes }

        var longestStreak = 0
        var currentStreak = 0
        var previousDay: Date?

        for day in trainedDays.sorted() {
            if let previousDay,
               let expectedDay = calendar.date(byAdding: .day, value: 1, to: previousDay),
               calendar.isDate(day, inSameDayAs: expectedDay) {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
            longestStreak = max(longestStreak, currentStreak)
            previousDay = day
        }

        return MonthlyOverview(
            trainingDays: trainedDays.count,
            durationMinutes: durationMinutes,
            longestStreak: longestStreak
        )
    }
}

struct TrainingGoalView: View {
    let ownerKey: String
    @ObservedObject private var prefs = UserPreferences.shared
    @ObservedObject var profile: OwnerProfileStore
    @Query private var sessions: [TrainingSession]
    @Environment(\.calendar) private var calendar
    @EnvironmentObject private var authState: AuthState
    @State private var reminderError: String?
    @State private var isUpdatingReminder = false
    @State private var reminderAuthorization: TrainingReminderAuthorization = .notDetermined

    init(ownerKey: String = DeviceGuestIdentity.ownerKey(), profile: OwnerProfileStore? = nil) {
        self.ownerKey = ownerKey
        _profile = ObservedObject(wrappedValue: profile ?? OwnerProfileStore(ownerKey: ownerKey))
        _sessions = Query(filter: #Predicate { $0.ownerKey == ownerKey })
    }

    var body: some View {
        ZStack {
            Color.btBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    progressSection
                    weeklyGoalSection
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
        .task { await refreshReminderAuthorization() }
        .alert("无法开启提醒", isPresented: Binding(
            get: { reminderError != nil },
            set: { if !$0 { reminderError = nil } }
        )) {
            Button("知道了", role: .cancel) { reminderError = nil }
        } message: {
            Text(reminderError ?? "请在系统设置中允许球迹发送通知。")
        }
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
                    .animation(BTMotion.springPanel, value: weeklyProgress)

                VStack(spacing: 2) {
                    Text("\(daysTrainedThisWeek)")
                        .font(.btStatNumber)
                        .foregroundStyle(.btPrimary)
                    Text("/ \(profile.weeklyGoalDays) 天")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                }
            }

            HStack(spacing: Spacing.xxl) {
                VStack(spacing: 2) {
                    Text("\(daysTrainedThisWeek) / \(profile.weeklyGoalDays)")
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
                        Task<Void, Never> {
                            await profile.setWeeklyGoalDays(days, authState: authState)
                        }
                    } label: {
                        HStack {
                            Text("\(days) 天")
                                .font(.btBody)
                                .foregroundStyle(.btText)

                            Spacer()

                            if profile.weeklyGoalDays == days {
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

                    Toggle("", isOn: reminderEnabledBinding)
                        .tint(.btPrimary)
                        .labelsHidden()
                        .disabled(isUpdatingReminder)
                        .accessibilityIdentifier("trainingGoal.reminderEnabled")
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

                        DatePicker("", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(.btPrimary)
                            .disabled(isUpdatingReminder)
                            .accessibilityIdentifier("trainingGoal.reminderTime")
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                }

                Divider().padding(.leading, Spacing.lg)

                Text(reminderAuthorizationText)
                    .font(.btCaption)
                    .foregroundStyle(reminderAuthorization == .denied ? Color.btDestructive : .btTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .accessibilityIdentifier("trainingGoal.reminderAuthorization")
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            .animation(BTMotion.easeInOutFast, value: prefs.reminderEnabled)
        }
    }

    private var reminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { prefs.reminderEnabled },
            set: { requested in updateReminder(enabled: requested, time: prefs.reminderTime) }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { prefs.reminderTime },
            set: { newTime in updateReminder(enabled: true, time: newTime) }
        )
    }

    private func updateReminder(enabled: Bool, time: Date) {
        guard !isUpdatingReminder else { return }
        isUpdatingReminder = true
        Task {
            defer { isUpdatingReminder = false }
            guard enabled else {
                TrainingReminderScheduler.shared.disable()
                prefs.persistReminder(enabled: false)
                return
            }
            switch await TrainingReminderScheduler.shared.enable(at: time, calendar: calendar) {
            case .scheduled:
                reminderAuthorization = .allowed
                prefs.persistReminder(enabled: true, time: time)
            case .permissionDenied:
                reminderAuthorization = .denied
                prefs.persistReminder(enabled: false)
                reminderError = "系统通知权限未开启。请前往“设置 > 通知 > 球迹”允许通知后再试。"
            case .failed(let message):
                prefs.persistReminder(enabled: false)
                reminderError = message
            }
        }
    }

    private func refreshReminderAuthorization() async {
        reminderAuthorization = await TrainingReminderScheduler.shared.authorization()
        if reminderAuthorization == .denied, prefs.reminderEnabled {
            prefs.persistReminder(enabled: false)
        }
    }

    private var reminderAuthorizationText: String {
        switch reminderAuthorization {
        case .notDetermined: return "首次开启时会请求系统通知权限"
        case .allowed: return "系统通知权限已开启"
        case .denied: return "系统通知权限未开启，请前往系统设置允许通知"
        }
    }

    // MARK: - Computed Properties

    private var daysTrainedThisWeek: Int {
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return TrainingGoalMetrics.daysTrained(sessions, since: weekStart, calendar: calendar)
    }

    private var weeklyProgress: CGFloat {
        guard profile.weeklyGoalDays > 0 else { return 0 }
        return min(CGFloat(daysTrainedThisWeek) / CGFloat(profile.weeklyGoalDays), 1.0)
    }

    private var monthlyRateText: String {
        let now = Date()
        guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else { return "—" }

        let weeksElapsed = max(1, calendar.dateComponents([.weekOfMonth], from: monthStart, to: now).weekOfMonth ?? 1)
        let totalGoalDays = weeksElapsed * profile.weeklyGoalDays
        guard totalGoalDays > 0 else { return "—" }

        let trainedDays = TrainingGoalMetrics.daysTrained(sessions, since: monthStart, calendar: calendar)
        let rate = Int(min(Double(trainedDays) / Double(totalGoalDays) * 100, 100))
        return "\(rate)%"
    }
}

#Preview("Training Goal") {
    NavigationStack {
        TrainingGoalView()
    }
    .environmentObject(AuthState())
    .modelContainer(for: TrainingSession.self, inMemory: true)
}

#Preview("Training Goal Dark") {
    NavigationStack {
        TrainingGoalView()
    }
    .environmentObject(AuthState())
    .modelContainer(for: TrainingSession.self, inMemory: true)
    .preferredColorScheme(.dark)
}
