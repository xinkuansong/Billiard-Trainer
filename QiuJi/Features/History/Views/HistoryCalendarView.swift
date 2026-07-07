import SwiftUI
import SwiftData

enum HistoryRoute: Hashable {
    case detail(sessionId: UUID)
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
    @State private var selectedAngleSession: AngleTrainingSession?

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
        .sheet(item: $selectedAngleSession) { session in
            NavigationStack {
                AngleSessionDetailView(session: session)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完成") { selectedAngleSession = nil }
                        }
                    }
            }
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
            .padding(.bottom, 96) // 预留底部 Tab 栏高度，避免空状态/列表压到 Tab 栏后方
        }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button(action: vm.previousMonth) {
                Image(systemName: BTIcon.chevronLeft)
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
                Image(systemName: BTIcon.chevronRight)
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
        let markerLabel = hasSession ? vm.markerLabel(for: day.date) : nil

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

                if let label = markerLabel {
                    Text(label)
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
        let dayItems = vm.selectedDateItems

        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(selectedDateTitle)
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btText)

            if !vm.hasAnySessions {
                emptyState
            } else if dayItems.isEmpty {
                noSessionHint
            } else {
                ForEach(dayItems) { item in
                    dayItemRow(item)
                }
            }
        }
    }

    @ViewBuilder
    private func dayItemRow(_ item: HistoryDayItem) -> some View {
        switch item {
        case .session(let session):
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

        case .angle(let angleSession):
            Button {
                selectedAngleSession = angleSession
            } label: {
                angleRow(angleSession)
            }
            .buttonStyle(.plain)
        }
    }

    private var selectedDateTitle: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日 EEEE"
        return fmt.string(from: vm.selectedDate)
    }

    // 紧凑型空状态：内嵌在日历下方，不使用整屏 BTEmptyState（会被 Tab 栏遮挡，见 UR-20260529 U-03）。
    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: BTIcon.calendarPlus)
                .font(.btTitle)
                .foregroundStyle(.btTextTertiary)
            Text("还没有训练记录")
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
            Button {
                router.switchTab(.training)
            } label: {
                Text("去开始第一次练球吧")
                    .font(.btSubheadlineSemibold)
                    .foregroundStyle(.btPrimary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    private var noSessionHint: some View {
        HStack {
            Spacer()
            VStack(spacing: Spacing.sm) {
                Image(systemName: BTIcon.moonZzz)
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
                    Image(systemName: BTIcon.lock)
                        .font(.btCaption)
                    Text("Pro")
                        .font(.btCaption2)
                }
                .foregroundStyle(.btAccent)
            }

            Image(systemName: BTIcon.chevronRight)
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .opacity(locked ? 0.7 : 1)
    }

    private func angleRow(_ session: AngleTrainingSession) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color.btAccent)
                        .frame(width: 10, height: 10)
                    Text(session.quizTypeNameZh)
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                }

                HStack(spacing: Spacing.lg) {
                    Text("\(session.questionCount) 题")
                    Text(String(format: "平均 %.1f°", session.averageError))
                    Text(String(format: "正确率 %.0f%%", session.accurateRate * 100))
                    Text(angleTimeRange(for: session))
                }
                .font(.btFootnote14)
                .foregroundStyle(.btTextSecondary)
            }

            Spacer()

            Image(systemName: BTIcon.chevronRight)
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func angleTimeRange(for session: AngleTrainingSession) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "HH:mm"
        let start = fmt.string(from: session.startDate)
        let end   = fmt.string(from: session.endDate)
        return start == end ? start : "\(start)-\(end)"
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
