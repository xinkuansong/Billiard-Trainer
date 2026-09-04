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
    /// F-AK-05：重置统计属破坏性清空，仅补确认闸。
    @State private var showResetConfirm = false

    init() {
        _vm = StateObject(wrappedValue: GeometricAngleViewModel(limiter: .shared))
    }

    // 暗色场景语言重做（ADR-P11-07）：黑底 + 顶部指标胶囊 + 右下 FAB，
    // 与 2D/3D 瞄准训练、角度与打点等场景页同一套设计。
    // C31：本页无可配显示项（无 SCN 台面网格）→ 不并三点；重置统计保留独立 trailing。
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    angleCanvas
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))

                    actionChips

                    if vm.showResult {
                        resultSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if vm.limiter.isLimitReached {
                        limitReachedCard
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
                .animation(BTMotion.easeChrome, value: vm.showResult)
                .animation(BTMotion.easeChrome, value: vm.limiter.isLimitReached)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.black.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) { statsCapsule }

            // C30：NumericKeypadHUD 与 SceneAiming 同构——全屏 ZStack 底浮层（不改内容高度）。
            if isInputting, !vm.showResult, !vm.limiter.isLimitReached {
                keypadOverlay
            }
        }
        .animation(BTMotion.easeChrome, value: isInputting)
        .angleSaveErrorBanner(message: vm.saveErrorMessage) { vm.retryFailedSaves() }
        .btDarkToolChrome("角度预测")
        .toolbar {
            ToolbarItem(placement: .principal) {
                BTSolverNavStatus(title: "角度预测")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showResetConfirm = true } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.white.opacity(0.75))
                }
                .accessibilityLabel("重置统计")
            }
        }
        .confirmationDialog("重置统计", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) { vm.resetStatistics() }
        } message: {
            Text("将清空本页练习次数、正确率与平均误差，此操作不可撤销。")
        }
        .onAppear {
            vm.configure(context: modelContext)
            vm.generateRandomAngle()
            // UITest-only 确定性角度（含 0°）。launch 注入多为 String/NSNumber，不能只 as? Double。
            // 例：`-geometricQuiz.forcedAngle 90` / `45` / `0`。未注入时 object==nil，生产不变。
            if let obj = UserDefaults.standard.object(forKey: PracticeStorageKey.geometricQuizForcedAngle) {
                let forced: Double?
                if let d = obj as? Double { forced = d }
                else if let n = obj as? NSNumber { forced = n.doubleValue }
                else if let s = obj as? String { forced = Double(s) }
                else { forced = nil }
                if let forced {
                    vm.currentAngle = min(max(forced, 0), 90)
                    // 未注入 side 时钉右侧，保证截图/取证可复现。
                    vm.currentSide = .right
                }
            }
            if let raw = UserDefaults.standard.string(forKey: PracticeStorageKey.geometricQuizForcedSide)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased(),
               let side = AnglePredictionSide(rawValue: raw) {
                vm.currentSide = side
            }
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
            side: vm.currentSide,
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
        BTHudMetricSeparator()
    }

    // MARK: - 操作胶囊行（统一胶囊语言；置于画布下方避免遮挡表单）

    private var actionChips: some View {
        HStack(spacing: Spacing.sm) {
            actionChip(icon: "die.face.5.fill", title: "换题", filled: false) {
                withAnimation(BTMotion.easeChrome) {
                    isInputting = false
                }
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
                    withAnimation(BTMotion.easeChrome) {
                        isInputting = true
                    }
                }
            }
        }
    }

    // MARK: - 数字键盘 HUD（C30：与 SceneAiming 同构 ZStack 底浮层）

    private var keypadOverlay: some View {
        NumericKeypadHUD(
            input: $vm.userInput,
            title: "估算角度",
            subtitle: "范围 0° – 90°",
            compact: true,   // P5.1：紧凑键盘，不遮挡「换题 / 显示参考」
            onSubmit: {
                withAnimation(BTMotion.easeChrome) {
                    isInputting = false
                }
                vm.submitAnswer()
            },
            onCancel: {
                vm.userInput = ""
                withAnimation(BTMotion.easeChrome) {
                    isInputting = false
                }
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
        .buttonStyle(BTPressableStyle.capsule)
    }

    // MARK: - Freemium Gate

    private var limitReachedCard: some View {
        BTDailyLimitGate { showSubscription = true }
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
                BTDailyLimitGate(compact: true) { showSubscription = true }
            } else {
                BTTextActionButton(title: "下一题", role: .primary, width: 112) {
                    vm.nextQuestion()
                }
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
                    .buttonStyle(BTPressableStyle.capsule)
                }
                NavigationLink(value: AngleRoute.sceneAiming2D) {
                    Label("去真台练", systemImage: "target")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(BTPressableStyle.capsule)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }
}

// MARK: - Angle Prediction Figure

/// 角度预测题面（真台化，T-P18-46 / 竖直 0°）：真实台呢特写上，以母球为顶点画出
/// 「竖直 0° 进球线参考 + 左右摆动的瞄准线」夹角。
/// 角度线 = 瞄准线语义（白实线，§1.2）；量角弧 = 品牌绿 + 白读数；
/// 参考线双侧镜像含 90°；答题无符号（左右同一 θ）。
/// 几何真源：`AnglePredictionGeometry`（SwiftUI：x 右 y 下；0°=(0,−1)）。
private struct AnglePredictionFigure: View {
    let angle: Double
    let side: AnglePredictionSide
    let showReference: Bool
    let showResult: Bool

    private let referenceDegrees = [15, 30, 45, 60, 75, 90]

    var body: some View {
        // 台呢特写：竖向覆盖约 0.62m 台面 → 球按真实球径成像（约 30pt），射线比例真实。
        BTTableFigure(orientation: .landscape,
                      closeup: (center: .zero, halfHeight: 0.31)) { proj in
            let d = proj.ballDiameter
            let ballR = d / 2
            let (vertex, rayLen) = AnglePredictionGeometry.layout(
                canvasSize: proj.size, ballRadius: ballR)
            let refEnd = AnglePredictionGeometry.zeroEnd(from: vertex, length: rayLen)
            let angEnd = AnglePredictionGeometry.point(
                from: vertex, length: rayLen, angleDegrees: angle, side: side)
            let arcR = rayLen * 0.28
            // K2：参考虚线单独缩短至球缘前，避免后绘制的 1 号球遮住刻度。
            let refRayLen = max(rayLen - ballR, rayLen * 0.72)

            ZStack {
                if showReference {
                    ForEach(AnglePredictionSide.allCases, id: \.self) { refSide in
                        ForEach(referenceDegrees, id: \.self) { a in
                            let tip = AnglePredictionGeometry.point(
                                from: vertex, length: refRayLen,
                                angleDegrees: Double(a), side: refSide)
                            let label = AnglePredictionGeometry.point(
                                from: vertex, length: refRayLen + 12,
                                angleDegrees: Double(a), side: refSide)
                            Path { p in
                                p.move(to: vertex)
                                p.addLine(to: tip)
                            }
                            .stroke(FigureLine.hint.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            Text("\(a)°")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                                .position(clamped(label, in: proj.size))
                        }
                    }
                }

                // 角度扇形高亮（夹角；品牌绿弱底）。弧段按几何采样，避免 SwiftUI 弧角约定歧义。
                if angle > 0 {
                    Path { p in
                        p.move(to: vertex)
                        p.addLine(to: AnglePredictionGeometry.zeroEnd(from: vertex, length: arcR))
                        appendArcSamples(&p, vertex: vertex, radius: arcR,
                                         angleDegrees: angle, side: side)
                        p.closeSubpath()
                    }
                    .fill(FigureLine.contact.opacity(0.13))
                }

                // 0° 参考线（竖直进球线语义）：对照线，白细线。
                Path { p in p.move(to: vertex); p.addLine(to: refEnd) }
                    .stroke(FigureLine.hint, lineWidth: proj.lineHintWidth)

                // 角度线：瞄准线语义（白实线 lineMain）。
                Path { p in p.move(to: vertex); p.addLine(to: angEnd) }
                    .stroke(FigureLine.aim, lineWidth: proj.lineMainWidth)

                // 量角弧：品牌绿。
                if angle > 0 {
                    Path { p in
                        p.move(to: AnglePredictionGeometry.zeroEnd(from: vertex, length: arcR))
                        appendArcSamples(&p, vertex: vertex, radius: arcR,
                                         angleDegrees: angle, side: side)
                    }
                    .stroke(FigureLine.contact, lineWidth: proj.lineHintWidth)
                }

                BTFigureBall(number: 1, diameter: d).position(angEnd)
                BTFigureBall(diameter: d).position(vertex)

                Text("0°")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .position(clamped(
                        CGPoint(x: refEnd.x + 16, y: refEnd.y + 2),
                        in: proj.size))

                if showResult {
                    let labelPt = AnglePredictionGeometry.point(
                        from: vertex, length: arcR + 22,
                        angleDegrees: angle / 2, side: side)
                    Text("\(Int(round(angle)))°")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.black.opacity(0.45), in: Capsule())
                        .position(clamped(labelPt, in: proj.size))
                }
            }
        }
    }

    /// 从 0° 沿 `side` 扫到 `angleDegrees` 的折线弧（不含起点，调用方先 move）。
    private func appendArcSamples(_ path: inout Path,
                                  vertex: CGPoint,
                                  radius: CGFloat,
                                  angleDegrees: Double,
                                  side: AnglePredictionSide) {
        let steps = max(8, Int(ceil(angleDegrees)))
        for i in 1...steps {
            let t = angleDegrees * Double(i) / Double(steps)
            path.addLine(to: AnglePredictionGeometry.point(
                from: vertex, length: radius, angleDegrees: t, side: side))
        }
    }

    /// 把标签位置钳入画布内（治贴边被裁）。
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
