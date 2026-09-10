import SwiftUI

struct TrainingReminderView: View {
    @ObservedObject private var prefs = UserPreferences.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var enabled = UserPreferences.shared.reminderEnabled
    @State private var time = UserPreferences.shared.localReminderTime
    @State private var weekdays = UserPreferences.shared.reminderWeekdays
    @State private var authorization: TrainingReminderAuthorization = .notDetermined
    @State private var saving = false
    @State private var error: String?
    private let days = [(2, "周一"), (3, "周二"), (4, "周三"), (5, "周四"), (6, "周五"), (7, "周六"), (1, "周日")]

    var body: some View {
        Form {
            Section {
                Toggle("开启训练提醒", isOn: $enabled).accessibilityIdentifier("trainingReminder.enabled")
                if enabled {
                    DatePicker("提醒时间", selection: $time, displayedComponents: .hourAndMinute)
                }
            } footer: { Text("仅在这台设备上提醒。按选定日期的当地时间提醒一次。") }
            if enabled {
                Section("重复日期") {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Spacing.xs) { weekdayButtons }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))], spacing: Spacing.sm) { weekdayButtons }
                    }.padding(.vertical, Spacing.xs)

                }
            }
            if enabled, !weekdays.isEmpty {
                Section {
                    Text(days.filter { weekdays.contains($0.0) }.map(\.1).joined(separator: "、"))
                    if let nextDate {
                        Text("下次提醒：\(nextDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.btFootnote).foregroundStyle(.btTextSecondary)
                    }
                }
            }
            Section {
                if authorization == .denied {
                    Text("系统通知权限未开启").foregroundStyle(.btTextSecondary)
                        .accessibilityIdentifier("trainingReminder.authorization")
                    Button("前往系统设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } else {
                    Text(authorization == .allowed ? "系统通知权限已开启" : "保存并开启提醒时，将请求系统通知权限。")
                        .accessibilityIdentifier("trainingReminder.authorization")
                        .font(.btFootnote).foregroundStyle(.btTextSecondary)
                }
            }
        }.font(.btBody).tint(.btPrimary)
        .navigationTitle("训练提醒").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(saving)
        .interactiveDismissDisabled(saving)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { Task { await save() } }.disabled(saving || (enabled && weekdays.isEmpty))
            }
        }
        .task { authorization = await TrainingReminderScheduler.shared.authorization() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { authorization = await TrainingReminderScheduler.shared.authorization() } }
        }
        .alert("提醒设置", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("知道了", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private var weekdayButtons: some View {
        ForEach(days, id: \.0) { day in
            Button {
                if weekdays.contains(day.0) { weekdays.remove(day.0) } else { weekdays.insert(day.0) }
            } label: {
                Text(day.1).font(.btSubheadlineMedium)
                    .foregroundStyle(weekdays.contains(day.0) ? Color.btPrimary : .btTextSecondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(weekdays.contains(day.0) ? Color.btPrimaryMuted : .btBG)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
            }.buttonStyle(.plain)
                .accessibilityValue(weekdays.contains(day.0) ? "已选择" : "未选择")
        }
    }

    private var nextDate: Date? {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return weekdays.compactMap { weekday in
            Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: components.hour, minute: components.minute, weekday: weekday), matchingPolicy: .nextTime)
        }.min()
    }

    private func save() async {
        saving = true
        defer { saving = false }
        if !enabled {
            TrainingReminderScheduler.shared.disable()
            prefs.persistReminder(enabled: false)
            dismiss()
            return
        }
        switch await TrainingReminderScheduler.shared.enable(at: time, weekdays: weekdays) {
        case .scheduled:
            prefs.reminderWeekdays = weekdays
            prefs.persistReminder(enabled: true, time: time)
            dismiss()
        case .permissionDenied:
            enabled = false
            authorization = .denied
            TrainingReminderScheduler.shared.disable()
            prefs.persistReminder(enabled: false)
            error = "请在系统设置中允许球迹发送通知，然后返回保存。"
        case .failed(let message): error = message
        }
    }
}

#Preview("Light") { NavigationStack { TrainingReminderView() } }
#Preview("Dark") { NavigationStack { TrainingReminderView() }.preferredColorScheme(.dark) }
