import SwiftUI
import SwiftData

struct GeometricAngleQuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm: GeometricAngleViewModel
    @State private var showSubscription = false
    /// 条 5：弃系统键盘（弹出遮输入框/确认键），改用 2D 瞄准训练同款数字键盘 HUD。
    @State private var isInputting = false

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
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) { statsCapsule }
        .safeAreaInset(edge: .bottom, spacing: 0) { keypadInset }
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
        AnglePredictionFigure(
            angle: vm.currentAngle,
            showReference: vm.showReferenceGrid,
            showResult: vm.showResult
        )
    }

    // MARK: - Top stats capsule（统一指标条）

    /// 统一左对齐（ADR-P11-08）：与其他暗色场景页的顶部信息胶囊同一基线。
    private var statsCapsule: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                BTReadout(label: "次数", value: "\(vm.practiceCount)")
                divider
                BTReadout(label: "正确率", value: String(format: "%.0f%%", vm.accuracyRate))
                divider
                BTReadout(label: "平均", value: String(format: "%.1f°", vm.averageError))
                if !vm.limiter.isPremium {
                    divider
                    BTReadout(label: "剩余", value: "\(vm.limiter.remainingToday)",
                              emphasis: .adjustable, size: .compact)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .btHudGlass()

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.sm)
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 14)
    }

    // MARK: - 操作胶囊行（统一胶囊语言；置于画布下方避免遮挡表单）

    private var actionChips: some View {
        HStack(spacing: Spacing.sm) {
            actionChip(icon: "die.face.5.fill", title: "换题", filled: false) {
                isInputting = false
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

            // 答题（条 5：交互对齐 2D 瞄准训练——主操作弹数字键盘 HUD）。
            if vm.currentAngle > 0, !vm.showResult, !vm.limiter.isLimitReached, !isInputting {
                actionChip(icon: "pencil.and.list.clipboard", title: "答题", filled: true) {
                    vm.userInput = ""
                    isInputting = true
                }
            }
        }
    }

    // MARK: - 数字键盘 HUD（条 5：复用 2D 瞄准训练的 NumericKeypadHUD，无系统键盘遮挡）

    @ViewBuilder
    private var keypadInset: some View {
        if isInputting, !vm.showResult, !vm.limiter.isLimitReached {
            NumericKeypadHUD(
                input: $vm.userInput,
                title: "估算角度",
                subtitle: "范围 0° – 90°",
                compact: true,   // P5.1：紧凑键盘，不遮挡「换题 / 显示参考」
                onSubmit: {
                    isInputting = false
                    vm.submitAnswer()
                },
                onCancel: {
                    vm.userInput = ""
                    isInputting = false
                }
            )
        }
    }

    /// 场景页主操作胶囊（SPEC §8.1：品牌绿实底胶囊，禁用常规页 BTButtonStyle.primary）。
    /// 禁用态走 §1.7 状态语法：仪表玻璃底 + 文字 30%（治实拍禁用态难辨）。
    private func sceneCapsuleButton(_ title: String, icon: String? = nil,
                                    enabled: Bool = true,
                                    action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .semibold)) }
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(enabled ? .white : .white.opacity(0.3))
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, 11)
            .background(Capsule().fill(enabled ? Color.btPrimary : Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
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

            sceneCapsuleButton("解锁全部内容", icon: "crown.fill") {
                showSubscription = true
            }
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
                    Text("你答了 ") + Text("\(Int(last.userAngle))°").bold().monospacedDigit() +
                    Text("，实际是 ") + Text("\(Int(round(last.actualAngle)))°")
                        .bold().monospacedDigit().foregroundColor(.btPrimary)
                    Text("误差 \(Int(round(last.error)))°")
                        .font(.btTitle)
                        .monospacedDigit()
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
                sceneCapsuleButton("解锁全部内容", icon: "crown.fill") {
                    showSubscription = true
                }
            } else {
                sceneCapsuleButton("下一题") { vm.nextQuestion() }
            }

            // 学↔练闭环（T-P18-51）：偏差较大 → 回看原理补课；随时可去真台把估角落地。
            HStack(spacing: Spacing.lg) {
                if vm.lastErrorRating == .off {
                    NavigationLink(value: AngleRoute.aimingPrinciple) {
                        Label("回看原理", systemImage: "book")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                NavigationLink(value: AngleRoute.sceneAiming2D) {
                    Label("去真台练", systemImage: "target")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }
}

// MARK: - Angle Prediction Figure

/// 角度预测题面（真台化，T-P18-46）：真实台呢特写上，以母球为顶点画出
/// 「参考线 + 角度线」夹角。角度线 = 瞄准线语义（白实线，§1.2）；量角弧 = 品牌绿 + 白读数；
/// 参考线含 90°（原缺），标签钳入画布防裁切（原 75° 被裁）。
private struct AnglePredictionFigure: View {
    let angle: Double
    let showReference: Bool
    let showResult: Bool

    var body: some View {
        // 台呢特写：竖向覆盖约 0.62m 台面 → 球按真实球径成像（约 30pt），射线比例真实。
        BTTableFigure(orientation: .landscape,
                      closeup: (center: .zero, halfHeight: 0.31)) { proj in
            let w = proj.size.width
            let h = proj.size.height
            let rayLen = min(w * 0.74, h * 0.82)
            let vertex = CGPoint(x: w * 0.15, y: h * 0.82)
            let rad = angle * .pi / 180
            let refEnd = CGPoint(x: vertex.x + rayLen, y: vertex.y)
            let angEnd = CGPoint(x: vertex.x + rayLen * cos(rad), y: vertex.y - rayLen * sin(rad))
            let arcR = rayLen * 0.28
            let d = proj.ballDiameter

            ZStack {
                if showReference {
                    // 参考线补 90°（原 [15,30,45,60,75] 无 90，题目量程到 90°）。
                    ForEach([15, 30, 45, 60, 75, 90], id: \.self) { a in
                        let r2 = Double(a) * .pi / 180
                        Path { p in
                            p.move(to: vertex)
                            p.addLine(to: CGPoint(x: vertex.x + rayLen * cos(r2),
                                                  y: vertex.y - rayLen * sin(r2)))
                        }
                        .stroke(FigureLine.hint.opacity(0.3),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        Text("\(a)°")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .position(clamped(
                                CGPoint(x: vertex.x + (rayLen + 12) * cos(r2),
                                        y: vertex.y - (rayLen + 12) * sin(r2)),
                                in: proj.size))
                    }
                }

                // 角度扇形高亮（凸显"夹角"这个重点；品牌绿弱底，§1.2 角度弧家族）。
                if angle > 0 {
                    Path { p in
                        p.move(to: vertex)
                        p.addArc(center: vertex, radius: arcR,
                                 startAngle: .degrees(0), endAngle: .degrees(-angle), clockwise: true)
                        p.closeSubpath()
                    }
                    .fill(FigureLine.contact.opacity(0.13))
                }

                // 参考线（基准 0°）：对照线语义，白细线。
                Path { p in p.move(to: vertex); p.addLine(to: refEnd) }
                    .stroke(FigureLine.hint, lineWidth: proj.lineHintWidth)

                // 角度线：瞄准线语义（白实线 lineMain）。
                Path { p in p.move(to: vertex); p.addLine(to: angEnd) }
                    .stroke(FigureLine.aim, lineWidth: proj.lineMainWidth)

                // 量角弧：品牌绿（§1.2 角度弧 = 绿弧 + 白读数）。
                if angle > 0 {
                    Path { p in
                        p.addArc(center: vertex, radius: arcR,
                                 startAngle: .degrees(0), endAngle: .degrees(-angle), clockwise: true)
                    }
                    .stroke(FigureLine.contact, lineWidth: proj.lineHintWidth)
                }

                BTFigureBall(number: 1, diameter: d).position(angEnd)
                BTFigureBall(diameter: d).position(vertex)

                Text("0°")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .position(x: refEnd.x - 14, y: refEnd.y + 14)

                if showResult {
                    Text("\(Int(round(angle)))°")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.black.opacity(0.45), in: Capsule())
                        .position(x: vertex.x + (arcR + 22) * cos(rad / 2),
                                  y: vertex.y - (arcR + 22) * sin(rad / 2))
                }
            }
        }
    }

    /// 把标签位置钳入画布内（治 75°/90° 标签贴边被裁）。
    private func clamped(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(p.x, 12), size.width - 12),
                y: min(max(p.y, 10), size.height - 10))
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
