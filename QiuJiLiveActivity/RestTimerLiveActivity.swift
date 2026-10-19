import ActivityKit
import SwiftUI
import WidgetKit

struct RestTimerLiveActivity: Widget {
    private enum Style {
        static let background = Color("restActivityBackground")
        static let primary = Color("restActivityPrimary")
        static let secondary = Color("restActivitySecondary")
        static let accent = Color("restActivityAccent")
        static let inset: CGFloat = 16
        static let contentSpacing: CGFloat = 12
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Let WidgetKit place the single text row around the camera cutout.
                DynamicIslandExpandedRegion(.leading) {
                    Label("组间休息", systemImage: "timer")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Style.accent)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(Style.primary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.attributes.drillName)
                            .font(.caption)
                            .foregroundStyle(Style.secondary)
                            .lineLimit(2)
                        ProgressView(timerInterval: timerInterval(context.state), countsDown: true) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(Style.accent)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(Style.accent)
                    .font(.caption2)
            } compactTrailing: {
                countdown(context.state)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Style.primary)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(Style.accent)
            }
            // Keep the expanded content inside the island's curved clipping edge.
            // Compact/minimal and lock-screen layouts retain their own margins.
            .contentMargins(.horizontal, 28, for: .expanded)
            .contentMargins(.top, 20, for: .expanded)
            .contentMargins(.bottom, 20, for: .expanded)
        }
    }

    private func lockScreenView(context: ActivityViewContext<RestTimerAttributes>) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Style.contentSpacing) {
                progressRing(context.state)
                VStack(alignment: .leading, spacing: 4) {
                    restTitle
                    drillName(context.attributes.drillName)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                lockScreenCountdown(context.state)
            }
            // Let content capacity, rather than device model, select the narrow layout.
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: Style.contentSpacing) {
                    progressRing(context.state)
                    restTitle
                    Spacer(minLength: 0)
                    lockScreenCountdown(context.state)
                }
                drillName(context.attributes.drillName)
            }
        }
        .padding(Style.inset)
        // The host may use a different appearance from the app. Pair explicit
        // foregrounds with one surface palette instead of inheriting host colors.
        .activityBackgroundTint(Style.background)
        .activitySystemActionForegroundColor(Style.primary)
    }

    private var restTitle: some View {
        Text("组间休息")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Style.primary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func drillName(_ name: String) -> some View {
        Text(name)
            .font(.caption)
            .foregroundStyle(Style.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func lockScreenCountdown(_ state: RestTimerAttributes.ContentState) -> some View {
        countdown(state)
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .foregroundStyle(Style.primary)
            .contentTransition(.numericText())
            .layoutPriority(1)
    }

    private func progressRing(_ state: RestTimerAttributes.ContentState) -> some View {
        // The system owns the time-driven fraction while our process is suspended.
        ProgressView(timerInterval: timerInterval(state), countsDown: true) {
            EmptyView()
        } currentValueLabel: {
            Image(systemName: "timer")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Style.accent)
        }
        .progressViewStyle(.circular)
        .tint(Style.accent)
        .frame(width: 44, height: 44)
        .accessibilityLabel("休息剩余进度")
    }

    private func timerInterval(_ state: RestTimerAttributes.ContentState) -> ClosedRange<Date> {
        let start = state.endDate.addingTimeInterval(-Double(max(0, state.totalSeconds)))
        return start...state.endDate
    }

    /// Date-relative Text expands to its proposal. Measure ordinary monospaced text
    /// first so it cannot consume the drill-name column or widen the compact island.
    private func countdown(_ state: RestTimerAttributes.ContentState) -> some View {
        Text("\(max(0, state.totalSeconds) / 60):00")
            .monospacedDigit()
            .fixedSize()
            .hidden()
            .overlay {
                Text(timerInterval: timerInterval(state), countsDown: true, showsHours: false)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
            }
    }
}
