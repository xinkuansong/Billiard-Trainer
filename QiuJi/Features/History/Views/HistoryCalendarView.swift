import SwiftUI
import SwiftData

enum HistoryRoute: Hashable {
    case detail(sessionId: UUID)
    case statistics
}

struct HistoryCalendarView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = HistoryViewModel()
    @State private var showSubscription = false

    private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                calendarSection
                dailySessionList
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .background(Color.btBG.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    router.historyPath.append(HistoryRoute.statistics)
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundStyle(.btPrimary)
                }
            }
        }
        .task {
            await vm.loadSessions(context: modelContext)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(spacing: Spacing.md) {
            monthNavigator
            weekdayHeader
            calendarGrid
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private var monthNavigator: some View {
        HStack {
            Button(action: vm.previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.btBodyMedium)
                    .foregroundStyle(.btPrimary)
            }
            Spacer()
            Text(vm.monthTitle)
                .font(.btHeadline)
                .foregroundStyle(.btText)
            Spacer()
            Button(action: vm.nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.btBodyMedium)
                    .foregroundStyle(.btPrimary)
            }
        }
        .padding(.horizontal, Spacing.sm)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(Array(vm.weeksInMonth.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { index in
                        if index < week.count, let date = week[index] {
                            dayCell(date)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 40)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let day = Calendar.current.component(.day, from: date)
        let hasSes = vm.hasSession(on: date)
        let selected = vm.isSelected(date)
        let today = vm.isToday(date)

        return Button {
            vm.selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(today ? .btBodyMedium : .btBody)
                    .foregroundStyle(selected ? .white : today ? .btPrimary : .btText)

                Circle()
                    .fill(hasSes ? (selected ? Color.white : Color.btPrimary) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                selected
                    ? RoundedRectangle(cornerRadius: BTRadius.sm).fill(Color.btPrimary)
                    : nil
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session List

    @ViewBuilder
    private var dailySessionList: some View {
        let daySessions = vm.selectedDateSessions

        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(selectedDateTitle)
                .font(.btHeadline)
                .foregroundStyle(.btText)

            if daySessions.isEmpty {
                noSessionHint
            } else {
                ForEach(daySessions, id: \.id) { session in
                    let accessible = HistoryAccessController.isAccessible(session, isPremium: subscriptionManager.isPremium)
                    Button {
                        if accessible {
                            router.historyPath.append(HistoryRoute.detail(sessionId: session.id))
                        } else {
                            showSubscription = true
                        }
                    } label: {
                        sessionRow(session, locked: !accessible)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var selectedDateTitle: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日 EEEE"
        return fmt.string(from: vm.selectedDate)
    }

    private var noSessionHint: some View {
        HStack {
            Spacer()
            VStack(spacing: Spacing.sm) {
                Image(systemName: "moon.zzz")
                    .font(.system(size: 24))
                    .foregroundStyle(.btTextTertiary)
                Text("当天无训练记录")
                    .font(.btCallout)
                    .foregroundStyle(.btTextSecondary)
            }
            .padding(.vertical, Spacing.xxl)
            Spacer()
        }
    }

    private func sessionRow(_ session: TrainingSession, locked: Bool = false) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(sessionTime(session.date))
                    .font(.btBodyMedium)
                    .foregroundStyle(locked ? .btTextTertiary : .btText)

                Text("\(session.drillEntries.count) 个训练项目")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }

            Spacer()

            if locked {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                    Text("Pro")
                        .font(.btCaption2)
                }
                .foregroundStyle(.btAccent)
            } else {
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text("\(session.totalDurationMinutes) 分钟")
                        .font(.btCallout)
                        .foregroundStyle(.btTextSecondary)

                    if !session.drillEntries.isEmpty {
                        let rate = overallRate(session)
                        Text("\(Int(rate * 100))%")
                            .font(.btHeadline)
                            .foregroundStyle(rateColor(rate))
                    }
                }
            }

            Image(systemName: locked ? "crown.fill" : "chevron.right")
                .font(.btCaption)
                .foregroundStyle(locked ? .btAccent : .btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .opacity(locked ? 0.7 : 1)
    }

    // MARK: - Helpers

    private func sessionTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    private func overallRate(_ session: TrainingSession) -> Double {
        let totalMade = session.drillEntries.flatMap(\.sets).reduce(0) { $0 + $1.madeBalls }
        let totalTarget = session.drillEntries.flatMap(\.sets).reduce(0) { $0 + $1.targetBalls }
        guard totalTarget > 0 else { return 0 }
        return Double(totalMade) / Double(totalTarget)
    }

    private func rateColor(_ rate: Double) -> Color {
        if rate >= 0.8 { return .btSuccess }
        if rate >= 0.5 { return .btPrimary }
        return .btWarning
    }
}

#Preview("Light") {
    NavigationStack {
        HistoryCalendarView()
            .navigationTitle("历史")
    }
    .environmentObject(AppRouter())
    .environmentObject(SubscriptionManager.shared)
    .modelContainer(for: TrainingSession.self, inMemory: true)
}

#Preview("Dark") {
    NavigationStack {
        HistoryCalendarView()
            .navigationTitle("历史")
    }
    .environmentObject(AppRouter())
    .environmentObject(SubscriptionManager.shared)
    .modelContainer(for: TrainingSession.self, inMemory: true)
    .preferredColorScheme(.dark)
}
