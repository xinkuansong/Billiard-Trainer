import SwiftUI
import SwiftData

enum HistoryRoute: Hashable {
    case detail(sessionId: UUID)
}

struct HistoryCalendarView: View {
    let ownerKey: String
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var vm = HistoryViewModel()
    @State private var activeTab: HistoryTab = .history
    @State private var showSubscription = false
    @State private var selectedSessionId: UUID?
    @State private var selectedCognitiveSession: CognitiveSessionItem?

    private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    init(ownerKey: String = DeviceGuestIdentity.ownerKey()) {
        self.ownerKey = ownerKey
    }

    var body: some View {
        VStack(spacing: 0) {
            BTSegmentedTab(tabs: HistoryTab.allCases, selected: $activeTab) { $0.rawValue }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)

            // F-HI-04：保活历史与统计，避免切 Tab 重建闪 ProgressView。
            ZStack {
                historyPane
                    .opacity(activeTab == .history ? 1 : 0)
                    .allowsHitTesting(activeTab == .history)
                StatisticsView()
                    .opacity(activeTab == .statistics ? 1 : 0)
                    .allowsHitTesting(activeTab == .statistics)
            }
        }
        .background(Color.btBG.ignoresSafeArea())
        .task {
            await vm.loadSessions(context: modelContext)
        }
        .sheet(isPresented: Binding(
            get: { selectedSessionId != nil },
            set: { if !$0 { selectedSessionId = nil } }
        ), onDismiss: {
            // Detail sheet can delete the record or edit its note — reload so the
            // calendar and day list stop showing stale data.
            Task { await vm.loadSessions(context: modelContext) }
        }) {
            if let id = selectedSessionId {
                NavigationStack {
                    TrainingDetailView(sessionId: id, ownerKey: ownerKey)
                }
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .sheet(item: $selectedCognitiveSession) { session in
            NavigationStack {
                AngleSessionDetailView(session: session)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完成") { selectedCognitiveSession = nil }
                        }
                    }
            }
        }
    }

    // MARK: - History Content

    @ViewBuilder
    private var historyPane: some View {
        if vm.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.errorMessage {
            // F-HI-03：失败与空态分流，可读展示 + 重试。
            VStack(spacing: Spacing.lg) {
                BTEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "加载失败",
                    subtitle: error,
                    actionTitle: "重试"
                ) {
                    Task { await vm.loadSessions(context: modelContext) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Spacing.lg)
        } else {
            historyContent
        }
    }

    private var historyContent: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                monthNavigator
                calendarCard
                dailySessionList
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, 96) // 预留底部 Tab 栏高度，避免空状态/列表压到 Tab 栏后方
            .animation(BTMotion.springPanel, value: vm.selectedDate)
            .animation(BTMotion.springPanel, value: vm.currentMonth)
        }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button {
                withAnimation(BTMotion.springPanel) { vm.previousMonth() }
            } label: {
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
            Button {
                withAnimation(BTMotion.springPanel) { vm.nextMonth() }
            } label: {
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
        let marker = hasSession ? vm.marker(for: day.date) : nil

        return Button {
            if day.isCurrentMonth {
                withAnimation(BTMotion.springPanel) {
                    vm.selectedDate = day.date
                }
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

                if let marker {
                    // v29 W6：tool 活跃用淡色标记与训练标记区分——工具使用不是训练量、
                    // 不进任何成绩聚合（契约 §5.3）。
                    Text(marker.label)
                        .font(.btMicro)
                        .fontWeight(.medium)
                        .foregroundStyle(marker.isToolActivity ? Color.btTextSecondary : .white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(marker.isToolActivity
                                    ? Color.btPrimary.opacity(0.18)
                                    : Color.btPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
                } else {
                    Color.clear.frame(height: 14)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        // F-HI-02：日格按压；FL-004 保持 plain 基底语义（BTPressableStyle 无 tint）。
        .buttonStyle(BTPressableStyle.row)
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
            .buttonStyle(BTPressableStyle.row)

        case .cognitive(let cognitiveSession):
            Button {
                selectedCognitiveSession = cognitiveSession
            } label: {
                cognitiveRow(cognitiveSession)
            }
            .buttonStyle(BTPressableStyle.row)

        case .tool(let toolSession):
            // ⛔ 无成绩、无详情可看（契约 §5.3 只记日期与时长），故不可点。
            toolRow(toolSession)
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
                    // F-HI-05：锁定行 btTextTertiary 弱化、常规行 btPrimary；角度行沿用 btAccent 区分。
                    Circle()
                        .fill(locked ? Color.btTextTertiary : Color.btPrimary)
                        .frame(width: 10, height: 10)
                    Text(vm.displayName(for: session))
                        .font(.btHeadline)
                        .foregroundStyle(locked ? .btTextTertiary : .btText)
                        .lineLimit(1)
                }

                HStack(spacing: Spacing.lg) {
                    if let category = vm.categoryLabel(for: session) {
                        Text(category)
                    }
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
                BTProBadge()
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

    /// 认知练习行。名称取会话 `note` 快照（契约 §6.5），不回查当前文案表。
    private func cognitiveRow(_ session: CognitiveSessionItem) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color.btAccent)
                        .frame(width: 10, height: 10)
                    Text(session.displayNameZh)
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                }

                HStack(spacing: Spacing.lg) {
                    Text("\(session.questionCount) 题")
                    Text(String(format: "平均 %.1f°", session.averageError))
                    Text(String(format: "正确率 %.0f%%", session.accurateRate * 100))
                    Text(timeRange(from: session.startDate, to: session.endDate))
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

    /// 工具使用行：淡色、无成绩、无箭头，与训练记录明确区分。
    private func toolRow(_ session: ToolSessionItem) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color.btTextTertiary.opacity(0.5))
                        .frame(width: 10, height: 10)
                    Text(session.displayNameZh)
                        .font(.btSubheadlineMedium)
                        .foregroundStyle(.btTextSecondary)
                }

                HStack(spacing: Spacing.lg) {
                    Text("工具使用")
                    Text("\(session.durationMinutes) 分钟")
                    Text(timeRange(from: session.date, to: session.date))
                }
                .font(.btFootnote14)
                .foregroundStyle(.btTextTertiary)
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .background(Color.btBGSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private func timeRange(from start: Date, to end: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "HH:mm"
        let s = fmt.string(from: start)
        let e = fmt.string(from: end)
        return s == e ? s : "\(s)-\(e)"
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
