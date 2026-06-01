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
        BTAimTableView(style: .feltOnly) { felt in
            AnglePredictionFigure(
                angle: vm.currentAngle,
                showReference: vm.showReferenceGrid,
                showResult: vm.showResult,
                felt: felt
            )
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

// MARK: - Angle Prediction Figure

/// 角度预测图形：在拟真台面上，以母球为顶点画出「参考线 + 角度线」夹角，
/// 配精致量角弧、可选刻度参考与结果角度数；目标球落在角度线末端，贴近真实一杆。
private struct AnglePredictionFigure: View {
    let angle: Double
    let showReference: Bool
    let showResult: Bool
    let felt: CGRect

    var body: some View {
        let minDim = min(felt.width, felt.height)
        let rayLen = min(felt.width * 0.74, felt.height * 0.82)
        let vertex = CGPoint(x: felt.minX + felt.width * 0.15, y: felt.minY + felt.height * 0.82)
        let rad = angle * .pi / 180
        let refEnd = CGPoint(x: vertex.x + rayLen, y: vertex.y)
        let angEnd = CGPoint(x: vertex.x + rayLen * cos(rad), y: vertex.y - rayLen * sin(rad))
        let arcR = rayLen * 0.28
        let cueD = minDim * 0.10
        let targetD = minDim * 0.085

        ZStack {
            if showReference {
                ForEach([15, 30, 45, 60, 75], id: \.self) { a in
                    let r2 = Double(a) * .pi / 180
                    Path { p in
                        p.move(to: vertex)
                        p.addLine(to: CGPoint(x: vertex.x + rayLen * cos(r2), y: vertex.y - rayLen * sin(r2)))
                    }
                    .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    Text("\(a)°")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .position(x: vertex.x + (rayLen + 12) * cos(r2),
                                  y: vertex.y - (rayLen + 12) * sin(r2))
                }
            }

            // 角度扇形高亮（凸显"夹角"这个重点）
            if angle > 0 {
                Path { p in
                    p.move(to: vertex)
                    p.addArc(center: vertex, radius: arcR,
                             startAngle: .degrees(0), endAngle: .degrees(-angle), clockwise: true)
                    p.closeSubpath()
                }
                .fill(Color.yellow.opacity(0.16))
            }

            // 参考线（基准 0°）
            Path { p in p.move(to: vertex); p.addLine(to: refEnd) }
                .stroke(Color.white.opacity(0.85), lineWidth: 2)

            // 角度线
            Path { p in p.move(to: vertex); p.addLine(to: angEnd) }
                .stroke(Color.white, lineWidth: 3)

            // 量角弧
            if angle > 0 {
                Path { p in
                    p.addArc(center: vertex, radius: arcR,
                             startAngle: .degrees(0), endAngle: .degrees(-angle), clockwise: true)
                }
                .stroke(Color.yellow, lineWidth: 3)
            }

            BTRealisticBall(kind: .target, diameter: targetD).position(angEnd)
            BTRealisticBall(kind: .cue, diameter: cueD).position(vertex)

            Text("0°")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .position(x: refEnd.x - 14, y: refEnd.y + 14)

            if showResult {
                Text("\(Int(round(angle)))°")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.black.opacity(0.45), in: Capsule())
                    .position(x: vertex.x + (arcR + 22) * cos(rad / 2),
                              y: vertex.y - (arcR + 22) * sin(rad / 2))
            }
        }
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
