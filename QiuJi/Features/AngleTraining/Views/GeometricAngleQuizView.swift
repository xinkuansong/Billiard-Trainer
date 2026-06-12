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

    // 暗色场景语言重做（ADR-P11-07）：黑底 + 顶部指标胶囊 + 右下 FAB，
    // 与 2D/3D 瞄准训练、角度与打点等场景页同一套设计。
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                angleCanvas
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))

                actionChips

                if vm.showResult {
                    resultSection
                } else if vm.limiter.isLimitReached {
                    limitReachedCard
                } else if vm.currentAngle > 0 {
                    inputSection
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) { statsCapsule }
        .navigationTitle("角度预测")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { vm.resetStatistics() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.white.opacity(0.75))
                }
                .accessibilityLabel("重置统计")
            }
        }
        .onAppear {
            vm.configure(context: modelContext)
            vm.generateRandomAngle()
        }
        .onReceive(subscriptionManager.$isPremium) { premium in
            vm.limiter.isPremium = premium
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
                .environmentObject(subscriptionManager)
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

    // MARK: - Top stats capsule（统一指标条）

    /// 统一左对齐（ADR-P11-08）：与其他暗色场景页的顶部信息胶囊同一基线。
    private var statsCapsule: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                capsuleItem(label: "次数", value: "\(vm.practiceCount)")
                divider
                capsuleItem(label: "正确率", value: String(format: "%.0f%%", vm.accuracyRate))
                divider
                capsuleItem(label: "平均", value: String(format: "%.1f°", vm.averageError))
                if !vm.limiter.isPremium {
                    divider
                    Text("剩余 \(vm.limiter.remainingToday)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.btAccent)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.sm)
    }

    private func capsuleItem(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 14)
    }

    // MARK: - 操作胶囊行（统一胶囊语言；置于画布下方避免遮挡表单）

    private var actionChips: some View {
        HStack(spacing: Spacing.sm) {
            actionChip(icon: "die.face.5.fill", title: "换题", filled: true) {
                inputFocused = false
                vm.generateRandomAngle()
            }
            .disabled(vm.limiter.isLimitReached)
            .opacity(vm.limiter.isLimitReached ? 0.4 : 1)

            actionChip(icon: vm.showReferenceGrid ? "eye.slash.fill" : "scope",
                       title: vm.showReferenceGrid ? "隐藏参考" : "显示参考",
                       filled: false) {
                vm.showReferenceGrid.toggle()
            }

            Spacer()
        }
    }

    private func actionChip(icon: String, title: String, filled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(filled ? .white : .white.opacity(0.85))
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 7)
            .background(Capsule().fill(filled ? Color.btPrimary : Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(spacing: Spacing.lg) {
            Text("请估算角度")
                .font(.btHeadline)
                .foregroundStyle(.white)

            HStack(spacing: Spacing.xs) {
                TextField("0", text: $vm.userInput)
                    .keyboardType(.numberPad)
                    .font(.btLargeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .focused($inputFocused)
                Text("°")
                    .font(.btTitle.weight(.regular))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 180, height: 64)
            .background(.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.lg)
                    .stroke(Color.btPrimary, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))

            Text("范围: 0° - 90°")
                .font(.btCaption)
                .foregroundStyle(.white.opacity(0.45))

            Button("确认") {
                inputFocused = false
                vm.submitAnswer()
            }
            .buttonStyle(BTButtonStyle.primary)
            .disabled(vm.userInput.isEmpty)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .onAppear { inputFocused = true }
    }

    // MARK: - Freemium Gate

    private var limitReachedCard: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 32))
                .foregroundStyle(.btAccent)

            Text("今日免费次数已用完")
                .font(.btHeadline)
                .foregroundStyle(.white)

            Text("每日可免费练习 \(AngleUsageLimiter.dailyLimit) 题，升级 Pro 后不限次数。")
                .font(.btSubheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)

            Button {
                showSubscription = true
            } label: {
                Label("解锁全部内容", systemImage: "crown.fill")
            }
            .buttonStyle(BTButtonStyle.primary)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if vm.limiter.isLimitReached {
                Text("今日免费次数已用完")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.white.opacity(0.65))
                Button {
                    showSubscription = true
                } label: {
                    Label("解锁全部内容", systemImage: "crown.fill")
                }
                .buttonStyle(BTButtonStyle.primary)
            } else {
                Button("下一题") { vm.nextQuestion() }
                    .buttonStyle(BTButtonStyle.primary)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
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
