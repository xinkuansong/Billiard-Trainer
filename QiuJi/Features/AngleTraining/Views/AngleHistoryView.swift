import SwiftUI
import SwiftData

struct AngleHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = AngleHistoryViewModel()
    @State private var selectedSegment = 0

    var body: some View {
        ScrollView {

            VStack(spacing: Spacing.xxl) {
                if vm.allResults.isEmpty {
                    BTEmptyState(icon: "chart.line.uptrend.xyaxis",
                                 title: "暂无测试记录",
                                 subtitle: "完成角度测试后，误差趋势将在这里显示")
                } else {
                    statsCards
                    segmentPicker
                    trendChart
                }
            }
            .padding(Spacing.lg)
        }
        .background(.btBG)
        .navigationTitle("测试历史")
        .navigationBarTitleDisplayMode(.inline)
        .premiumGate(isPremium: true)
        .onAppear { vm.configure(context: modelContext) }
        .task { await vm.loadData() }
    }

    // MARK: - Stats

    private var statsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                  spacing: Spacing.md) {
            card(title: "总题数", value: "\(vm.totalQuestions)")
            card(title: "平均误差", value: String(format: "%.1f°", vm.overallAverageError))
            card(title: "精准率", value: String(format: "%.0f%%", vm.accurateRate * 100))
        }
    }

    private func card(title: String, value: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.btTitle2)
                .foregroundStyle(.btPrimary)
            Text(title)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Segment

    private var segmentPicker: some View {
        Picker("", selection: $selectedSegment) {
            Text("全部").tag(0)
            Text("角袋").tag(1)
            Text("中袋").tag(2)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Chart

    private var activeTrend: [AngleHistoryViewModel.TrendPoint] {
        switch selectedSegment {
        case 1: return vm.cornerTrend
        case 2: return vm.sideTrend
        default: return vm.overallTrend
        }
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("误差趋势（每 5 题平均）")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            if activeTrend.isEmpty {
                Text("数据不足")
                    .font(.btCallout)
                    .foregroundStyle(.btTextTertiary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                TrendLineChart(points: activeTrend)
                    .frame(height: 180)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }
}

// MARK: - Canvas line chart

private struct TrendLineChart: View {
    let points: [AngleHistoryViewModel.TrendPoint]

    var body: some View {
        Canvas { ctx, size in
            guard points.count >= 2 else { return }

            let maxErr = max(points.map(\.averageError).max() ?? 1, 5)
            let padX: CGFloat = 30
            let padTop: CGFloat = 8
            let padBot: CGFloat = 24
            let chartW = size.width - padX
            let chartH = size.height - padTop - padBot

            // Y-axis labels
            for step in stride(from: 0, through: maxErr, by: max(1, (maxErr / 4).rounded(.up))) {
                let y = padTop + chartH * (1 - step / maxErr)
                ctx.draw(Text("\(Int(step))°").font(.btCaption2).foregroundColor(.btTextTertiary),
                         at: CGPoint(x: padX / 2, y: y), anchor: .center)
                var gridLine = Path()
                gridLine.move(to: CGPoint(x: padX, y: y))
                gridLine.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(gridLine, with: .color(Color.btSeparator.opacity(0.5)),
                           style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
            }

            func xPos(_ i: Int) -> CGFloat {
                padX + chartW * CGFloat(i) / CGFloat(points.count - 1)
            }
            func yPos(_ v: Double) -> CGFloat {
                padTop + chartH * (1 - min(v / maxErr, 1))
            }

            // Line
            var line = Path()
            for (i, p) in points.enumerated() {
                let pt = CGPoint(x: xPos(i), y: yPos(p.averageError))
                if i == 0 { line.move(to: pt) } else { line.addLine(to: pt) }
            }
            ctx.stroke(line, with: .color(.btPrimary), style: StrokeStyle(lineWidth: 2))

            // Dots
            for (i, p) in points.enumerated() {
                let pt = CGPoint(x: xPos(i), y: yPos(p.averageError))
                let r: CGFloat = 4
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(.btPrimary))
            }

            // X labels (every few points)
            let labelStep = max(1, points.count / 6)
            for i in stride(from: 0, to: points.count, by: labelStep) {
                let x = xPos(i)
                ctx.draw(Text("\(points[i].groupIndex)").font(.btCaption2).foregroundColor(.btTextTertiary),
                         at: CGPoint(x: x, y: size.height - 4), anchor: .bottom)
            }
        }
    }
}

// MARK: - Preview

#Preview("Light") {
    NavigationStack { AngleHistoryView() }
        .modelContainer(ModelContainerFactory.makeInMemoryContainer())
}
