import ActivityKit
import SwiftUI
import WidgetKit

struct RestTimerLiveActivity: Widget {
    private static let brandGreen = Color(red: 0.102, green: 0.42, blue: 0.235)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Let WidgetKit place the single text row around the camera cutout.
                DynamicIslandExpandedRegion(.leading) {
                    Text("组间休息")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                }
                DynamicIslandExpandedRegion(.bottom) {
                        ProgressView(timerInterval: timerInterval(context.state), countsDown: true) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(Self.brandGreen)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(Self.brandGreen)
                    .font(.caption2)
            } compactTrailing: {
                countdown(context.state)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(Self.brandGreen)
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<RestTimerAttributes>) -> some View {
        HStack(spacing: 16) {
            // The system owns the time-driven fraction while our process is suspended.
            ProgressView(timerInterval: timerInterval(context.state), countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                Image(systemName: "timer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Self.brandGreen)
            }
            .progressViewStyle(.circular)
            .tint(Self.brandGreen)
            .frame(width: 56, height: 56)
            .accessibilityLabel("休息剩余进度")

            VStack(alignment: .leading, spacing: 4) {
                Text("组间休息")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                countdown(context.state)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .contentTransition(.numericText())
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(context.attributes.drillName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("球迹")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Self.brandGreen)
            }
        }
        .padding(16)
        .activityBackgroundTint(Color(.systemBackground))
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
