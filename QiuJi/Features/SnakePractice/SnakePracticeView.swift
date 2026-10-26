import SwiftUI

struct SnakePracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configuration = SnakePracticeConfiguration.load()
    @State private var started = false

    var body: some View {
        Group {
            if started { FreePlayView(snakeConfiguration: configuration) }
            else {
                SnakePracticeSettingsView(configuration: configuration, isRestart: false,
                    onStart: { configuration = $0; started = true }, onCancel: { dismiss() })
            }
        }
        .onAppear {
            if !started { SnakePracticeHistory.shared.recoverInterruptedAttempt() }
        }
    }
}

struct SnakePracticeSettingsView: View {
    @State var configuration: SnakePracticeConfiguration
    @ObservedObject private var history = SnakePracticeHistory.shared
    @StateObject private var resetNotice = BTRuleNoticeCenter()
    let isRestart: Bool
    let onStart: (SnakePracticeConfiguration) -> Void
    let onCancel: () -> Void

    var body: some View {
        List {
            Section("目标球数") {
                Picker("数量", selection: $configuration.count) {
                    ForEach(SnakePracticeConfiguration.counts, id: \.self) { Text("\($0) 颗").tag($0).accessibilityIdentifier("snake.count.\($0)") }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("snake.count")
            }
            Section("击球顺序") {
                Picker("击球顺序", selection: $configuration.mode) {
                    ForEach(SnakePracticeConfiguration.Mode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("snake.mode")
            }
            Section("最近练习 · 10次") {
                if history.records.isEmpty {
                    Text("暂无训练记录").foregroundStyle(.secondary)
                } else {
                    ForEach(history.records) { record in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(record.count)颗 · \(record.mode.title)")
                                Spacer(minLength: Spacing.sm)
                                Text("\(record.succeeded ? "成功" : "失败") · \(record.completed)/\(record.count)")
                                    .foregroundStyle(record.succeeded ? Color.btSuccess : Color.btTextSecondary)
                            }
                            HStack(alignment: .firstTextBaseline) {
                                Text(record.date, format: .dateTime.month().day().hour().minute())
                                if !record.reason.isEmpty { Text("· \(record.reason)") }
                            }
                            .font(.footnote).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("snake.record.\(record.id.uuidString)")
                    }
                }
            }
            BTTrainingSettingsResetSection {
                configuration = .init()
                resetNotice.show("已恢复默认设置", tone: .success, priority: .mode)
            }
        }
        .overlay {
            if let message = resetNotice.message { BTToastBanner(message: message) }
        }
        .navigationTitle("训练设置")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(isRestart ? "取消" : "返回", action: onCancel)
                    .accessibilityIdentifier("snake.settingsCancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isRestart ? "开始新练习" : "开始练习") {
                    var next = configuration
                    next.regenerate()
                    onStart(next)
                }
                    .fontWeight(.semibold).accessibilityIdentifier("snake.start")
            }
        }
        .onDisappear { resetNotice.clear() }
    }
}

#Preview("Light") { NavigationStack { SnakePracticeView() }.preferredColorScheme(.light) }
#Preview("Dark") { NavigationStack { SnakePracticeView() }.preferredColorScheme(.dark) }
