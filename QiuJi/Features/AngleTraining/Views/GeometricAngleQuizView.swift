import SwiftUI
import SwiftData

struct GeometricAngleQuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm: GeometricAngleViewModel
    @FocusState private var inputFocused: Bool
    @State private var showSubscription = false

    init() {
        _vm = StateObject(wrappedValue: GeometricAngleViewModel(limiter: AngleUsageLimiter()))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                angleCanvas
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))

                controlButtons

                if vm.showResult {
                    resultSection
                } else if vm.currentAngle > 0 {
                    inputSection
                }

                statsPanel
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(.btBG)
        .navigationTitle("角度预测")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            vm.configure(context: modelContext)
            vm.generateRandomAngle()
        }
        .onReceive(subscriptionManager.$isPremium) { premium in
            vm.limiter.isPremium = premium
        }
    }

    // MARK: - Canvas

    private var angleCanvas: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(.btTableFelt))

            let origin = CGPoint(x: 30, y: h - 30)
            let axisLen = min(w, h) - 60

            // Reference grid
            if vm.showReferenceGrid {
                let refAngles: [Double] = [15, 30, 45, 60, 75]
                for angle in refAngles {
                    let rad = angle * .pi / 180
                    let endX = origin.x + axisLen * cos(rad)
                    let endY = origin.y - axisLen * sin(rad)
                    var refLine = Path()
                    refLine.move(to: origin)
                    refLine.addLine(to: CGPoint(x: endX, y: endY))
                    context.stroke(refLine, with: .color(.white.opacity(0.15)),
                                  style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    let labelR = axisLen + 14
                    context.draw(Text("\(Int(angle))°").font(.system(size: 10)).foregroundColor(.white.opacity(0.4)),
                                at: CGPoint(x: origin.x + labelR * cos(rad),
                                           y: origin.y - labelR * sin(rad)))
                }

                // Arc guides
                for r in stride(from: axisLen * 0.25, through: axisLen * 0.75, by: axisLen * 0.25) {
                    var arc = Path()
                    arc.addArc(center: origin, radius: r,
                              startAngle: .degrees(0), endAngle: .degrees(-90), clockwise: true)
                    context.stroke(arc, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
                }
            }

            // X axis
            var xAxis = Path()
            xAxis.move(to: origin)
            xAxis.addLine(to: CGPoint(x: origin.x + axisLen, y: origin.y))
            context.stroke(xAxis, with: .color(.white), lineWidth: 2)

            // Y axis
            var yAxis = Path()
            yAxis.move(to: origin)
            yAxis.addLine(to: CGPoint(x: origin.x, y: origin.y - axisLen))
            context.stroke(yAxis, with: .color(.white), lineWidth: 2)

            // "0°" label
            context.draw(Text("0°").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.7)),
                        at: CGPoint(x: origin.x + axisLen - 10, y: origin.y + 16))

            // Origin dot
            let dotR: CGFloat = 5
            context.fill(Path(ellipseIn: CGRect(x: origin.x - dotR, y: origin.y - dotR,
                                                width: dotR * 2, height: dotR * 2)),
                        with: .color(.white))

            // Angle line
            guard vm.currentAngle > 0 else { return }
            let lineLen = axisLen * 0.85
            let rad = vm.currentAngle * .pi / 180
            let endX = origin.x + lineLen * cos(rad)
            let endY = origin.y - lineLen * sin(rad)

            var angleLine = Path()
            angleLine.move(to: origin)
            angleLine.addLine(to: CGPoint(x: endX, y: endY))
            context.stroke(angleLine, with: .color(.white), lineWidth: 3)

            // Angle arc
            let arcR: CGFloat = 40
            var angleArc = Path()
            angleArc.addArc(center: origin, radius: arcR,
                           startAngle: .degrees(0),
                           endAngle: .degrees(-vm.currentAngle),
                           clockwise: true)
            context.stroke(angleArc, with: .color(.yellow), lineWidth: 2)

            // Result: show actual angle label
            if vm.showResult {
                let labelPos = CGPoint(x: origin.x + (arcR + 20) * cos(rad / 2),
                                       y: origin.y - (arcR + 20) * sin(rad / 2))
                context.draw(
                    Text("\(Int(round(vm.currentAngle)))°")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.yellow),
                    at: labelPos
                )
            }
        }
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: Spacing.md) {
            Button("生成随机角度") {
                vm.generateRandomAngle()
            }
            .buttonStyle(BTButtonStyle.primary)

            Button(vm.showReferenceGrid ? "隐藏参考" : "显示参考") {
                vm.showReferenceGrid.toggle()
            }
            .buttonStyle(BTButtonStyle.secondary)

            Button("重置统计") {
                vm.resetStatistics()
            }
            .font(.btCallout)
            .foregroundStyle(.btDestructive)
        }
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(spacing: Spacing.lg) {
            Text("请估算角度")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            HStack(spacing: Spacing.xs) {
                TextField("0", text: $vm.userInput)
                    .keyboardType(.numberPad)
                    .font(.btLargeTitle)
                    .multilineTextAlignment(.center)
                    .focused($inputFocused)
                Text("°")
                    .font(.btTitle.weight(.regular))
                    .foregroundStyle(.btTextSecondary)
            }
            .frame(width: 180, height: 64)
            .background(.btBGSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.lg)
                    .stroke(Color.btPrimary, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))

            Text("范围: 0° - 90°")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)

            Button("确认") {
                inputFocused = false
                vm.submitAnswer()
            }
            .buttonStyle(BTButtonStyle.primary)
            .disabled(vm.userInput.isEmpty)
        }
        .onAppear { inputFocused = true }
    }

    // MARK: - Result

    private var resultSection: some View {
        VStack(spacing: Spacing.lg) {
            if let last = vm.sessionResults.last {
                HStack {
                    Text(vm.lastErrorRating.label)
                        .font(.btSubheadlineMedium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(vm.lastErrorRating.color)
                        .clipShape(Capsule())
                    Spacer()
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("你答了 ") + Text("\(Int(last.userAngle))°").bold() +
                    Text("，实际是 ") + Text("\(Int(round(last.actualAngle)))°")
                        .bold().foregroundColor(.btPrimary)
                    Text("误差 \(Int(round(last.error)))°")
                        .font(.btTitle)
                        .foregroundStyle(vm.lastErrorRating.color)
                }
                .font(.btBody)
                .foregroundStyle(.btText)
            }

            Button("下一题") { vm.nextQuestion() }
                .buttonStyle(BTButtonStyle.primary)
        }
        .padding(Spacing.xl)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Stats Panel

    private var statsPanel: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
            statCard(title: "练习次数", value: "\(vm.practiceCount)")
            statCard(title: "正确次数", value: "\(vm.accurateCount)", subtitle: "(误差≤3°)")
            statCard(title: "正确率", value: String(format: "%.0f%%", vm.accuracyRate))
            statCard(title: "平均误差", value: String(format: "%.1f°", vm.averageError))
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func statCard(title: String, value: String, subtitle: String? = nil) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: 2) {
                Text(value)
                    .font(.btTitle)
                    .foregroundStyle(.btText)
                if let subtitle {
                    Text(subtitle)
                        .font(.btCaption)
                        .foregroundStyle(.btTextTertiary)
                }
            }
            Text(title)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
    }
}

#Preview("Light") {
    NavigationStack {
        GeometricAngleQuizView()
            .modelContainer(ModelContainerFactory.makeInMemoryContainer())
            .environmentObject(SubscriptionManager.shared)
    }
}

#Preview("Dark") {
    NavigationStack {
        GeometricAngleQuizView()
            .modelContainer(ModelContainerFactory.makeInMemoryContainer())
            .environmentObject(SubscriptionManager.shared)
    }
    .preferredColorScheme(.dark)
}
