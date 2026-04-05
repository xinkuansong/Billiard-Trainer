import SwiftUI
import SwiftData

struct AngleHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
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
                    statsGrid
                    BTSegmentedTab(tabs: AngleTimeRange.allCases,
                                   selected: $vm.timeRange) { $0.rawValue }
                    trendSection
                    rangeAnalysis
                }
            }
            .padding(Spacing.lg)
        }
        .background(.btBG)
        .navigationTitle("测试历史")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { vm.configure(context: modelContext) }
        .task { await vm.loadData() }
    }

    // MARK: - 2×2 Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                  spacing: Spacing.lg) {
            statCard(icon: "number", iconColor: .btPrimary,
                     label: "总测试次数", value: "\(vm.totalQuestions)")
            statCard(icon: "arrow.left.arrow.right", iconColor: .btAccent,
                     label: "平均误差", value: String(format: "%.1f°", vm.overallAverageError))
            statCard(icon: "trophy.fill", iconColor: .btPrimary,
                     label: "最佳成绩", value: String(format: "%.1f°", vm.bestScore))
            statCard(icon: "checkmark.circle.fill", iconColor: .btPrimary,
                     label: "正确率", value: String(format: "%.0f%%", vm.accurateRate * 100))
        }
    }

    private func statCard(icon: String, iconColor: Color, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.btCallout)
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .textCase(.uppercase)
            }
            Text(value)
                .font(.btStatNumber)
                .foregroundStyle(.btText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.02),
                radius: 4, x: 0, y: 1)
    }

    // MARK: - Trend Section

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text("误差趋势")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
                Spacer()
                pocketToggle
            }

            if activeTrend.isEmpty {
                Text("数据不足")
                    .font(.btCallout)
                    .foregroundStyle(.btTextTertiary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                TrendLineChart(cornerPoints: vm.cornerTrend,
                               sidePoints: vm.sideTrend,
                               selectedSegment: selectedSegment)
                    .frame(height: 180)
            }

            HStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.xs) {
                    Circle().fill(Color.btPrimary).frame(width: 8, height: 8)
                    Text("角袋").font(.btCaption2).foregroundStyle(.btTextSecondary)
                }
                HStack(spacing: Spacing.xs) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.btAccent.opacity(0.7))
                        .frame(width: 10, height: 2)
                    Text("中袋").font(.btCaption2).foregroundStyle(.btTextSecondary)
                }
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.02),
                radius: 4, x: 0, y: 1)
    }

    private var pocketToggle: some View {
        HStack(spacing: 0) {
            ForEach(["角袋", "中袋"].indices, id: \.self) { idx in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedSegment = idx }
                } label: {
                    Text(idx == 0 ? "角袋" : "中袋")
                        .font(.btCaption)
                        .fontWeight(selectedSegment == idx ? .semibold : .medium)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .foregroundStyle(selectedSegment == idx ? .white : .btTextSecondary)
                        .background(selectedSegment == idx ? Color.btPrimary : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
                }
            }
        }
        .padding(2)
        .background(.btBGTertiary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
    }

    private var activeTrend: [AngleHistoryViewModel.TrendPoint] {
        switch selectedSegment {
        case 0: return vm.cornerTrend
        case 1: return vm.sideTrend
        default: return vm.overallTrend
        }
    }

    // MARK: - Range Analysis

    private var rangeAnalysis: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("角度区间分析")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
                Text("各角度范围正确率分布")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }

            VStack(spacing: Spacing.lg) {
                ForEach(vm.rangeStats) { range in
                    rangeRow(range: range)
                }
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.02),
                radius: 4, x: 0, y: 1)
    }

    private func rangeRow(range: AngleHistoryViewModel.RangeStat) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack {
                Text(range.label)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                Spacer()
                Text(String(format: "%.0f%%", range.accurateRate * 100))
                    .font(.btCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(barColor(for: range.accurateRate))
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: BTRadius.full)
                    .fill(Color.btBGTertiary)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: BTRadius.full)
                            .fill(barColor(for: range.accurateRate))
                            .frame(width: geo.size.width * max(0, min(range.accurateRate, 1)))
                    }
            }
            .frame(height: 8)
        }
    }

    private func barColor(for rate: Double) -> Color {
        if rate >= 0.75 { return .btPrimary }
        if rate >= 0.5 { return .btAccent }
        return .btDestructive
    }
}

// MARK: - Canvas line chart (dual line)

private struct TrendLineChart: View {
    let cornerPoints: [AngleHistoryViewModel.TrendPoint]
    let sidePoints: [AngleHistoryViewModel.TrendPoint]
    let selectedSegment: Int

    var body: some View {
        Canvas { ctx, size in
            let primary = cornerPoints
            let secondary = sidePoints
            guard !primary.isEmpty || !secondary.isEmpty else { return }

            let allErrors = (primary + secondary).map(\.averageError)
            let maxErr = max(allErrors.max() ?? 1, 5)
            let padX: CGFloat = 30
            let padTop: CGFloat = 8
            let padBot: CGFloat = 24
            let chartW = size.width - padX
            let chartH = size.height - padTop - padBot

            for step in stride(from: 0, through: maxErr, by: max(1, (maxErr / 4).rounded(.up))) {
                let y = padTop + chartH * (1 - step / maxErr)
                ctx.draw(Text("\(Int(step))°").font(.btCaption2).foregroundColor(.btTextTertiary),
                         at: CGPoint(x: padX / 2, y: y), anchor: .center)
                var gridLine = Path()
                gridLine.move(to: CGPoint(x: padX, y: y))
                gridLine.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(gridLine, with: .color(Color.btSeparator.opacity(0.3)),
                           style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
            }

            let mainPts = selectedSegment == 1 ? secondary : primary
            let altPts = selectedSegment == 1 ? primary : secondary

            if altPts.count >= 2 {
                drawLine(ctx: ctx, points: altPts, maxErr: maxErr,
                         padX: padX, padTop: padTop, chartW: chartW, chartH: chartH,
                         color: selectedSegment == 1 ? .btPrimary : .btAccent,
                         dashed: true, showDots: false)
            }

            if mainPts.count >= 2 {
                drawLine(ctx: ctx, points: mainPts, maxErr: maxErr,
                         padX: padX, padTop: padTop, chartW: chartW, chartH: chartH,
                         color: selectedSegment == 1 ? .btAccent : .btPrimary,
                         dashed: false, showDots: true)
            }

            let labelPts = mainPts.isEmpty ? altPts : mainPts
            let labelStep = max(1, labelPts.count / 6)
            for i in stride(from: 0, to: labelPts.count, by: labelStep) {
                let x = padX + chartW * CGFloat(i) / CGFloat(max(labelPts.count - 1, 1))
                ctx.draw(Text("\(labelPts[i].groupIndex)").font(.btCaption2).foregroundColor(.btTextTertiary),
                         at: CGPoint(x: x, y: size.height - 4), anchor: .bottom)
            }
        }
    }

    private func drawLine(ctx: GraphicsContext, points: [AngleHistoryViewModel.TrendPoint],
                          maxErr: Double, padX: CGFloat, padTop: CGFloat,
                          chartW: CGFloat, chartH: CGFloat, color: Color,
                          dashed: Bool, showDots: Bool) {
        func xPos(_ i: Int) -> CGFloat {
            padX + chartW * CGFloat(i) / CGFloat(max(points.count - 1, 1))
        }
        func yPos(_ v: Double) -> CGFloat {
            padTop + chartH * (1 - min(v / maxErr, 1))
        }

        var line = Path()
        for (i, p) in points.enumerated() {
            let pt = CGPoint(x: xPos(i), y: yPos(p.averageError))
            if i == 0 { line.move(to: pt) } else { line.addLine(to: pt) }
        }

        let style = dashed
            ? StrokeStyle(lineWidth: 1.5, dash: [4, 2])
            : StrokeStyle(lineWidth: 2)
        ctx.stroke(line, with: .color(dashed ? color.opacity(0.7) : color), style: style)

        if showDots {
            for (i, p) in points.enumerated() {
                let pt = CGPoint(x: xPos(i), y: yPos(p.averageError))
                let r: CGFloat = 4
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r,
                                                width: 2 * r, height: 2 * r)),
                         with: .color(color))
            }
        }
    }
}

// MARK: - Preview

#Preview("Light") {
    NavigationStack { AngleHistoryView() }
        .modelContainer(ModelContainerFactory.makeInMemoryContainer())
}

#Preview("Dark") {
    NavigationStack { AngleHistoryView() }
        .modelContainer(ModelContainerFactory.makeInMemoryContainer())
        .preferredColorScheme(.dark)
}
