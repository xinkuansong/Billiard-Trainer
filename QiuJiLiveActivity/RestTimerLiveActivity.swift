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
                DynamicIslandExpandedRegion(.leading) {
                    Label("组间休息", systemImage: "timer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.endDate, style: .timer)
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .contentTransition(.numericText())
                        .environment(\.locale, Locale(identifier: "en_US"))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        timerInterval: timerInterval(context.state),
                        countsDown: true
                    )
                    .tint(Self.brandGreen)
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(Self.brandGreen)
                    .font(.caption2)
            } compactTrailing: {
                Text(context.state.endDate, style: .timer)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .environment(\.locale, Locale(identifier: "en_US"))
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(Self.brandGreen)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<RestTimerAttributes>) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: progress(context.state))
                    .stroke(
                        Self.brandGreen,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "timer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Self.brandGreen)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("组间休息")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(timerInterval: timerInterval(context.state), countsDown: true)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .contentTransition(.numericText())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(context.attributes.drillName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("球迹")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Self.brandGreen)
            }
        }
        .padding(16)
        .activityBackgroundTint(Color(.systemBackground))
    }

    // MARK: - Helpers

    private func progress(_ state: RestTimerAttributes.ContentState) -> CGFloat {
        guard state.totalSeconds > 0 else { return 0 }
        let remaining = max(0, state.endDate.timeIntervalSinceNow)
        return CGFloat(remaining) / CGFloat(state.totalSeconds)
    }

    private func timerInterval(_ state: RestTimerAttributes.ContentState) -> ClosedRange<Date> {
        let start = state.endDate.addingTimeInterval(-Double(state.totalSeconds))
        return start...state.endDate
    }
}
