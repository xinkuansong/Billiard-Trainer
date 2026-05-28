import SwiftUI

/// PhaseTimeline 的纯数据条目；提取到顶层，避免嵌套在泛型 `BTPhaseTimeline<Content>` 内导致的
/// 「PhaseEntry 类型与具体 Content 绑定」问题。
struct BTPhaseEntry: Identifiable {
    let id: String
    let typeKey: String
    let typeZh: String
    let durationMinutes: Int
    let icon: String

    static func from(_ phase: SessionPhase) -> BTPhaseEntry {
        .init(
            id: phase.type,
            typeKey: phase.type,
            typeZh: phase.typeZh,
            durationMinutes: phase.durationMinutes,
            icon: phase.icon
        )
    }
}

/// 训练阶段纵向时间线 — 在训练计划详情页中表达「热身 → 专项 → 综合 → 复盘」的串行节奏。
///
/// 视觉：左侧一条 1pt 虚线，每个 phase 起点放一颗 8pt 染色圆点；圆点用阶段类型上色。
/// 右侧通过 `content` builder 渲染该阶段的具体 drill 列表。
struct BTPhaseTimeline<Content: View>: View {

    let phases: [BTPhaseEntry]
    let content: (Int, BTPhaseEntry) -> Content

    private let dotSize: CGFloat = 8
    private let trackWidth: CGFloat = 16
    private let trailingGap: CGFloat = 12

    init(
        phases: [BTPhaseEntry],
        @ViewBuilder content: @escaping (Int, BTPhaseEntry) -> Content
    ) {
        self.phases = phases
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                phaseRow(phase: phase, index: index, isLast: index == phases.count - 1)
            }
        }
    }

    @ViewBuilder
    private func phaseRow(phase: BTPhaseEntry, index: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: trailingGap) {
            track(typeKey: phase.typeKey, isLast: isLast)
                .frame(width: trackWidth)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                phaseHeader(phase)
                content(index, phase)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func track(typeKey: String, isLast: Bool) -> some View {
        Color.clear
            .overlay(alignment: .top) {
                GeometryReader { geo in
                    if !isLast {
                        Path { path in
                            let x = geo.size.width / 2
                            path.move(to: CGPoint(x: x, y: dotSize + 4))
                            path.addLine(to: CGPoint(x: x, y: geo.size.height + Spacing.lg))
                        }
                        .stroke(
                            Color.btSeparator,
                            style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                        )
                    }

                    Circle()
                        .fill(dotColor(for: typeKey))
                        .frame(width: dotSize, height: dotSize)
                        .position(x: geo.size.width / 2, y: 4 + dotSize / 2)
                }
            }
    }

    private func phaseHeader(_ phase: BTPhaseEntry) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: phase.icon)
                .font(.btCaption2)
                .foregroundStyle(dotColor(for: phase.typeKey))
            Text(phase.typeZh)
                .font(.btCaption.weight(.semibold))
                .foregroundStyle(dotColor(for: phase.typeKey))
            Text("· \(phase.durationMinutes) 分钟")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
                .monospacedDigit()
        }
    }

    private func dotColor(for typeKey: String) -> Color {
        switch typeKey {
        case "warmup":   return .btSuccess
        case "focused":  return .btPrimary
        case "combined": return .btAccent
        case "review":   return .btTextTertiary
        default:         return .btTextSecondary
        }
    }
}

// MARK: - Previews

#Preview("Phase Timeline") {
    BTPhaseTimeline(
        phases: [
            BTPhaseEntry(id: "warmup", typeKey: "warmup", typeZh: "热身", durationMinutes: 10, icon: "flame"),
            BTPhaseEntry(id: "focused", typeKey: "focused", typeZh: "专项训练", durationMinutes: 35, icon: "target"),
            BTPhaseEntry(id: "combined", typeKey: "combined", typeZh: "综合/实战", durationMinutes: 10, icon: "square.grid.3x3"),
            BTPhaseEntry(id: "review", typeKey: "review", typeZh: "复盘记录", durationMinutes: 5, icon: "pencil.and.list.clipboard")
        ]
    ) { _, phase in
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("01").font(.btFootnote).foregroundStyle(.btTextTertiary).monospacedDigit()
                Text("斯托运杆练习").font(.btCallout).foregroundStyle(.btText)
                Spacer()
                Text("3×15").font(.btFootnote).foregroundStyle(.btTextTertiary).monospacedDigit()
            }
            if phase.typeKey == "focused" {
                HStack {
                    Text("02").font(.btFootnote).foregroundStyle(.btTextTertiary).monospacedDigit()
                    Text("发力直线球").font(.btCallout).foregroundStyle(.btText)
                    Spacer()
                    Text("2×15").font(.btFootnote).foregroundStyle(.btTextTertiary).monospacedDigit()
                }
            }
        }
    }
    .padding()
    .background(.btBGTertiary)
}

#Preview("Dark") {
    BTPhaseTimeline(
        phases: [
            BTPhaseEntry(id: "warmup", typeKey: "warmup", typeZh: "热身", durationMinutes: 10, icon: "flame"),
            BTPhaseEntry(id: "focused", typeKey: "focused", typeZh: "专项训练", durationMinutes: 35, icon: "target"),
            BTPhaseEntry(id: "review", typeKey: "review", typeZh: "复盘记录", durationMinutes: 5, icon: "pencil.and.list.clipboard")
        ]
    ) { _, _ in
        Text("Drill row").font(.btCallout).foregroundStyle(.btText)
    }
    .padding()
    .background(.btBGTertiary)
    .preferredColorScheme(.dark)
}
