import SwiftUI

/// 横向「周进度时间线」— 训练计划详情页用，将 N 个周序号可视化为节点串。
///
/// 四态：
/// - `.completed`  已完成 = 实心 `btSuccess`
/// - `.current`    进行中 = 描边 `btAccent` + 0.6Hz pulse
/// - `.upcoming`   未来   = 描边 `btSeparator`
/// - `.locked`     付费锁 = 描边 + `lock.fill` 图标
///
/// 用 `.dash` style 1pt 虚线连接相邻节点。
struct BTPlanWeekTimeline: View {

    enum WeekState: Equatable {
        case completed
        case current
        case upcoming
        case locked
    }

    struct WeekItem: Identifiable {
        let id: Int
        let state: WeekState
    }

    let items: [WeekItem]

    @State private var pulse: Bool = false

    private let dotSize: CGFloat = 12
    private let labelSpacing: CGFloat = 6
    private let segmentWidth: CGFloat = 36

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    weekNode(item)
                    if index < items.count - 1 {
                        connector(from: item.state, to: items[index + 1].state)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.83).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var accessibilityLabel: String {
        let completed = items.filter { $0.state == .completed }.count
        let total = items.count
        return "周进度，已完成 \(completed) 周，共 \(total) 周"
    }

    @ViewBuilder
    private func weekNode(_ item: WeekItem) -> some View {
        VStack(spacing: labelSpacing) {
            ZStack {
                Circle()
                    .fill(fillColor(item.state))
                    .frame(width: dotSize, height: dotSize)

                Circle()
                    .strokeBorder(borderColor(item.state), lineWidth: borderWidth(item.state))
                    .frame(width: dotSize, height: dotSize)
                    .opacity(item.state == .current && pulse ? 0.4 : 1.0)

                if item.state == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                } else if item.state == .locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.btTextTertiary)
                }
            }
            .frame(width: 18, height: 18)

            Text("\(item.id)")
                .font(.btMicro)
                .foregroundStyle(labelColor(item.state))
                .monospacedDigit()
        }
        .frame(width: 24)
    }

    @ViewBuilder
    private func connector(from: WeekState, to: WeekState) -> some View {
        let isSolid = (from == .completed && (to == .completed || to == .current))

        Path { path in
            path.move(to: CGPoint(x: 0, y: 9))
            path.addLine(to: CGPoint(x: segmentWidth, y: 9))
        }
        .stroke(
            connectorColor(from: from, to: to),
            style: StrokeStyle(
                lineWidth: 1,
                dash: isSolid ? [] : [2, 2]
            )
        )
        .frame(width: segmentWidth, height: 18)
        .padding(.bottom, 14)
    }

    private func fillColor(_ s: WeekState) -> Color {
        switch s {
        case .completed: return .btSuccess
        case .current:   return .clear
        case .upcoming:  return .clear
        case .locked:    return .clear
        }
    }

    private func borderColor(_ s: WeekState) -> Color {
        switch s {
        case .completed: return .btSuccess
        case .current:   return .btAccent
        case .upcoming:  return .btSeparator
        case .locked:    return .btSeparator
        }
    }

    private func borderWidth(_ s: WeekState) -> CGFloat {
        switch s {
        case .completed: return 0
        case .current:   return 1.5
        default:         return 1
        }
    }

    private func labelColor(_ s: WeekState) -> Color {
        switch s {
        case .completed: return .btTextSecondary
        case .current:   return .btText
        case .upcoming:  return .btTextTertiary
        case .locked:    return .btTextTertiary
        }
    }

    private func connectorColor(from: WeekState, to: WeekState) -> Color {
        if from == .completed && (to == .completed || to == .current) {
            return .btSuccess.opacity(0.6)
        }
        return .btSeparator
    }
}

// MARK: - Builder Helpers

extension BTPlanWeekTimeline {
    /// 根据当前周/总周数/Premium 锁定，生成默认四态序列。
    /// - Parameters:
    ///   - total: 总周数
    ///   - currentWeek: 1-based 当前周序号；0 或 nil 表示未激活，全部 upcoming
    ///   - premiumUnlockedFromWeek: 仅前 N 周可见，第 N+1 周起为 .locked；nil 不锁
    static func build(
        total: Int,
        currentWeek: Int?,
        premiumUnlockedFromWeek: Int? = nil
    ) -> [WeekItem] {
        let cw = currentWeek ?? 0
        return (1...max(total, 1)).map { week in
            let isLocked: Bool = {
                guard let limit = premiumUnlockedFromWeek else { return false }
                return week > limit
            }()

            let state: WeekState
            if isLocked {
                state = .locked
            } else if week < cw {
                state = .completed
            } else if week == cw {
                state = .current
            } else {
                state = .upcoming
            }
            return WeekItem(id: week, state: state)
        }
    }
}

// MARK: - Previews

#Preview("Active - 8 weeks") {
    VStack(spacing: 24) {
        BTPlanWeekTimeline(items: BTPlanWeekTimeline.build(total: 8, currentWeek: 3))
        BTPlanWeekTimeline(items: BTPlanWeekTimeline.build(total: 8, currentWeek: 1))
        BTPlanWeekTimeline(items: BTPlanWeekTimeline.build(total: 8, currentWeek: 8))
    }
    .padding()
    .background(.btBG)
}

#Preview("Premium Locked") {
    BTPlanWeekTimeline(items: BTPlanWeekTimeline.build(total: 12, currentWeek: 1, premiumUnlockedFromWeek: 1))
        .padding()
        .background(.btBG)
}

#Preview("Dark") {
    VStack(spacing: 24) {
        BTPlanWeekTimeline(items: BTPlanWeekTimeline.build(total: 8, currentWeek: 4))
        BTPlanWeekTimeline(items: BTPlanWeekTimeline.build(total: 4, currentWeek: nil))
    }
    .padding()
    .background(.btBG)
    .preferredColorScheme(.dark)
}
