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
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var vm = HistoryViewModel()
    @State private var activeTab: HistoryTab = .history
    @State private var showSubscription = false
    @State private var selectedSessionId: UUID?

    private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("记录")
                    .font(.btLargeTitle)
                    .foregroundStyle(.btText)
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)

            BTSegmentedTab(tabs: HistoryTab.allCases, selected: $activeTab) { $0.rawValue }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)

            if activeTab == .history {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    historyContent
                }
            } else {
                StatisticsView()
            }
        }
        .background(Color.btBG.ignoresSafeArea())
        .task {
            await vm.loadSessions(context: modelContext)
        }
        .sheet(isPresented: Binding(
            get: { selectedSessionId != nil },
            set: { if !$0 { selectedSessionId = nil } }
        )) {
            if let id = selectedSessionId {
                NavigationStack {
                    TrainingDetailView(sessionId: id)
                }
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }

    // MARK: - History Content

    private var historyContent: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                monthNavigator
                calendarCard
                dailySessionList
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button(action: vm.previousMonth) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.btTextSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            Spacer()
            Text(vm.monthTitle)
                .font(.btHeadline)
                .foregroundStyle(.btText)
            Spacer()
            Button(action: vm.nextMonth) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.btTextSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Calendar Card

    private var calendarCard: some View {
        VStack(spacing: Spacing.md) {
            weekdayHeader
            calendarGrid
        }
        .padding(Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.04), radius: 8, x: 0, y: 2)
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
                    ForEach(week) { day in
                        dayCell(day)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: CalendarDay) -> some View {
        let dayNum = Calendar.current.component(.day, from: day.date)
        let hasSession = day.isCurrentMonth && vm.hasSession(on: day.date)
        let selected = day.isCurrentMonth && vm.isSelected(day.date)
        let today = day.isCurrentMonth && vm.isToday(day.date)
        let category = hasSession ? vm.categoryForDate(day.date) : nil

        return Button {
            if day.isCurrentMonth {
                vm.selectedDate = day.date
            }
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    if today {
                        Circle()
                            .fill(Color.btPrimary)
                            .frame(width: 36, height: 36)
                    } else if selected {
                        Circle()
                            .strokeBorder(Color.btPrimary, lineWidth: 2)
                            .frame(width: 36, height: 36)
                    }

                    Text("\(dayNum)")
                        .font(.btSubheadline)
                        .fontWeight((today || selected) ? .semibold : .regular)
                        .foregroundStyle(
                            !day.isCurrentMonth ? .btTextTertiary.opacity(0.6) :
                            today ? .white :
                            selected ? .btPrimary :
                            .btText
                        )
                }
                .frame(width: 36, height: 36)

                if let cat = category {
                    Text(cat.shortNameZh)
                        .font(.btMicro)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.btPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Color.clear.frame(height: 14)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(.plain)
        .disabled(!day.isCurrentMonth)
    }

    // MARK: - Session List

    @ViewBuilder
    private var dailySessionList: some View {
        let daySessions = vm.selectedDateSessions

        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(selectedDateTitle)
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btText)

            if !vm.hasAnySessions {
                emptyState
            } else if daySessions.isEmpty {
                noSessionHint
            } else {
                ForEach(daySessions, id: \.id) { session in
                    let accessible = HistoryAccessController.isAccessible(
                        session, isPremium: subscriptionManager.isPremium
                    )
                    Button {
                        if accessible {
                            selectedSessionId = session.id
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

    private var emptyState: some View {
        BTEmptyState(
            icon: "calendar.badge.plus",
            title: "还没有训练记录",
            subtitle: "去开始第一次练球吧",
            actionTitle: "开始训练"
        ) {
            router.switchTab(.training)
        }
    }

    private var noSessionHint: some View {
        HStack {
            Spacer()
            VStack(spacing: Spacing.sm) {
                Image(systemName: "moon.zzz")
                    .font(.btTitle)
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
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(locked ? Color.btAccent : Color.btPrimary)
                        .frame(width: 10, height: 10)
                    Text(vm.displayName(for: session))
                        .font(.btHeadline)
                        .foregroundStyle(locked ? .btTextTertiary : .btText)
                }

                HStack(spacing: Spacing.lg) {
                    Text("\(session.drillEntries.count) 项目")
                    Text("\(vm.totalSets(for: session)) 组")
                    Text("\(session.totalDurationMinutes) 分钟")
                    Text(vm.timeRange(for: session))
                }
                .font(.btFootnote14)
                .foregroundStyle(.btTextSecondary)
            }

            Spacer()

            if locked {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "lock.fill")
                        .font(.btCaption)
                    Text("Pro")
                        .font(.btCaption2)
                }
                .foregroundStyle(.btAccent)
            }

            Image(systemName: "chevron.right")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .opacity(locked ? 0.7 : 1)
    }
}

#Preview("Light") {
    NavigationStack {
        HistoryCalendarView()
            .navigationTitle("记录")
    }
    .environmentObject(AppRouter())
    .environmentObject(SubscriptionManager.shared)
    .modelContainer(for: TrainingSession.self, inMemory: true)
}

#Preview("Dark") {
    NavigationStack {
        HistoryCalendarView()
            .navigationTitle("记录")
    }
    .environmentObject(AppRouter())
    .environmentObject(SubscriptionManager.shared)
    .modelContainer(for: TrainingSession.self, inMemory: true)
    .preferredColorScheme(.dark)
}
