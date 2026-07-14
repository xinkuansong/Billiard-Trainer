import SwiftUI
import SwiftData

// MARK: - 瞄准点训练（问题集合 v3 批次 S3：G1 口径 + P8.1–P8.6）
//
// 出题型：给切角 θ 问瞄准点。目标球固定 1 号，用户拖动假想球（虚线圈，无球心红点）
// 绕目标球移动；白色瞄准线竖直穿假想球心随动。瞄准点按 G1 定义 = 瞄准线与
// 「过目标球心且垂直于瞄准线的直线」（图中水平线）的交点，用红色小点标注。
// 切向口径（P8.4）：「向左切」= 目标球向左移动 ⇒ 母球应打目标球右侧（瞄准点在右侧）。
// 提交后展示正确瞄准线（红色）；误差以 mm 计（偏大为正 = 瞄薄、偏小为负 = 瞄厚），
// 历史统计取绝对值平均，写入 `AngleTestResult`（quizType = "aimPoint"，errorMM 有符号）。

@MainActor
final class AimPointTrainingViewModel: ObservableObject {

    struct Question {
        let angleDegrees: Double
        /// true = 向右切：目标球向右移动 ⇒ 母球打目标球左侧（瞄准点在目标球左侧）。
        let cutsRight: Bool
    }

    struct RoundResult {
        let question: Question
        /// 有符号 mm 误差（偏大为正）。
        let errorMM: Double
    }

    // 中八球径（与瞄准点对照表一致，P9-05）。
    static let ballRadiusMM: Double = 28.575

    @Published private(set) var question: Question?
    /// 用户假想球方位角 φ（弧度）：0 = 正下方（θ=0），右偏为正，范围 ±90°。
    @Published var userPhi: Double = 0
    @Published private(set) var showResult = false
    @Published private(set) var sessionResults: [RoundResult] = []
    /// 历史绝对值平均（mm），含既往会话（条 8.5）。
    @Published private(set) var historicalMeanAbsMM: Double?

    let limiter: AngleUsageLimiter
    private var repository: AngleTestRepositoryProtocol?

    init(limiter: AngleUsageLimiter) {
        self.limiter = limiter
    }

    func configure(context: ModelContext) {
        repository = LocalAngleTestRepository(context: context)
        refreshHistoricalStats()
    }

    // MARK: - Lifecycle

    func nextQuestion() {
        guard !limiter.isLimitReached else { return }
        let angle = Double(Int.random(in: 2...12) * 5) // 10°–60°，5° 步进
        question = Question(angleDegrees: angle, cutsRight: Bool.random())
        userPhi = 0
        showResult = false
    }

    /// 测试注入（AimPointGeometryTests）：绕过随机出题直接设定题目。
    func setQuestionForTesting(_ q: Question) {
        question = q
        userPhi = 0
        showResult = false
    }

    func submit() {
        guard let q = question, !showResult else { return }

        let userMM = userOffsetMM
        let correctMM = correctOffsetMM(for: q)
        // 条 8.5：以「朝进球侧的偏移量」比较，偏大为正、偏小为负。
        let signedError = userMM - correctMM

        sessionResults.append(RoundResult(question: q, errorMM: signedError))
        limiter.recordQuestion()
        showResult = true

        Task {
            let result = AngleTestResult(
                actualAngle: correctMM,
                userAngle: userMM,
                pocketType: "none",
                quizType: "aimPoint",
                errorMM: signedError
            )
            try? await repository?.save(result)
            refreshHistoricalStats()
        }
    }

    // MARK: - Derived

    /// 用户当前朝正确瞄准侧的偏移（mm，可为负 = 拖错侧）。
    /// P8.4 口径：向右切（目标球向右动）⇒ 瞄准侧 = 目标球左侧（φ < 0）。
    /// G1 数值关系：竖直瞄准线到目标球心的垂距 = 2R·|sin φ|，与假想球心横移同值。
    var userOffsetMM: Double {
        guard let q = question else { return 0 }
        let lateral = sin(userPhi) * 2 * Self.ballRadiusMM   // 正 = 右侧
        return q.cutsRight ? -lateral : lateral
    }

    func correctOffsetMM(for q: Question) -> Double {
        2 * Self.ballRadiusMM * sin(q.angleDegrees * .pi / 180)
    }

    /// 正确 φ（带侧向符号，弧度）：向右切 ⇒ 假想球/瞄准点在目标球左侧（φ < 0）。
    var correctPhi: Double {
        guard let q = question else { return 0 }
        let phi = q.angleDegrees * .pi / 180
        return q.cutsRight ? -phi : phi
    }

    var lastError: RoundResult? { sessionResults.last }

    var sessionMeanAbsMM: Double {
        guard !sessionResults.isEmpty else { return 0 }
        return sessionResults.map { abs($0.errorMM) }.reduce(0, +) / Double(sessionResults.count)
    }

    private func refreshHistoricalStats() {
        Task {
            guard let all = try? await repository?.fetchAll() else { return }
            let mine = all.filter { $0.quizType == "aimPoint" }
            guard !mine.isEmpty else { return }
            historicalMeanAbsMM = mine.map { abs($0.errorMM) }.reduce(0, +) / Double(mine.count)
        }
    }
}

// MARK: - View

struct AimPointTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm = AimPointTrainingViewModel(limiter: AngleUsageLimiter())
    @State private var showSubscription = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                figureCard
                if vm.showResult {
                    resultCard
                        .transition(.opacity)
                } else if vm.limiter.isLimitReached {
                    limitCard
                        .transition(.opacity)
                } else if vm.question != nil {
                    promptCard
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
        .navigationTitle("瞄准点训练")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            vm.configure(context: modelContext)
            if vm.question == nil { vm.nextQuestion() }
        }
        .onReceive(subscriptionManager.$isPremium) { premium in
            vm.limiter.isPremium = premium
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView().environmentObject(subscriptionManager)
        }
    }

    // MARK: - Stats

    /// P8.6：统计恒单行（紧凑档 + 短标签 + lineLimit(1)，禁止折行）。
    private var statsCapsule: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                BTReadout(label: "题", value: "\(vm.sessionResults.count)", size: .compact)
                divider
                BTReadout(label: "均差",
                          value: vm.sessionResults.isEmpty
                              ? "—" : String(format: "%.1fmm", vm.sessionMeanAbsMM),
                          size: .compact)
                if let hist = vm.historicalMeanAbsMM {
                    divider
                    BTReadout(label: "历史", value: String(format: "%.1fmm", hist),
                              size: .compact)
                }
                if !vm.limiter.isPremium {
                    divider
                    BTReadout(label: "剩", value: "\(vm.limiter.remainingToday)",
                              emphasis: .adjustable, size: .compact)
                }
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
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

    // MARK: - Figure（拖假想球）

    private var figureCard: some View {
        AimPointDragFigure(vm: vm)
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Prompt / Result

    private var promptCard: some View {
        VStack(spacing: Spacing.md) {
            if let q = vm.question {
                Text("切角 θ = \(Int(q.angleDegrees))° · 向\(q.cutsRight ? "右" : "左")切")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("向\(q.cutsRight ? "右" : "左")切 = 目标球向\(q.cutsRight ? "右" : "左")移动，母球应打目标球\(q.cutsRight ? "左" : "右")侧。拖动假想球，使红色瞄准点符合该切角，然后提交")
                    .font(.btFootnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                Text(String(format: "当前偏移 %.1f mm", vm.userOffsetMM))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.btPrimary)

                sceneCapsuleButton("提交瞄准点") { vm.submit() }
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private var resultCard: some View {
        VStack(spacing: Spacing.md) {
            if let last = vm.lastError, let q = vm.question {
                Text(String(format: "误差 %@%.1f mm",
                            last.errorMM >= 0 ? "+" : "", last.errorMM))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ratingColor(abs(last.errorMM)))

                Text(String(format: "正确偏移 %.1f mm · 你的偏移 %.1f mm",
                            vm.correctOffsetMM(for: q), vm.userOffsetMM))
                    .font(.btFootnote)
                    .foregroundStyle(.white.opacity(0.6))

                Text(last.errorMM >= 0 ? "瞄薄了一点（偏移偏大）" : "瞄厚了一点（偏移偏小）")
                    .font(.btCaption)
                    .foregroundStyle(.white.opacity(0.45))
            }

            if vm.limiter.isLimitReached {
                Text("今日免费次数已用完")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.white.opacity(0.65))
                sceneCapsuleButton("解锁全部内容") { showSubscription = true }
            } else {
                sceneCapsuleButton("下一题") { vm.nextQuestion() }
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private var limitCard: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 32))
                .foregroundStyle(.btAccent)
            Text("今日免费次数已用完")
                .font(.btHeadline)
                .foregroundStyle(.white)
            sceneCapsuleButton("解锁全部内容") { showSubscription = true }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func ratingColor(_ absMM: Double) -> Color {
        if absMM <= 2 { return .btSuccess }
        if absMM <= 6 { return .btWarning }
        return .btDestructive
    }

    private func sceneCapsuleButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, 11)
                .background(Capsule().fill(Color.btPrimary))
        }
        // F-SA-05：场景绿胶囊轻量 press。
        .buttonStyle(BTPressableStyle.capsule)
    }
}

// MARK: - 拖动假想球的真台特写图

private struct AimPointDragFigure: View {
    @ObservedObject var vm: AimPointTrainingViewModel

    var body: some View {
        let r = CGFloat(AngleSceneCalculator.ballRadius)
        // P8.5：特写取景收紧（4.3R → 2.7R 半高），目标球占比放大约 60%。
        BTTableFigure(orientation: .landscape,
                      closeup: (center: .zero, halfHeight: r * 2.7)) { proj in
            let d = proj.ballDiameter
            let target = CGPoint(x: proj.size.width / 2, y: proj.size.height * 0.34)
            let ghost = ghostCenter(target: target, d: d, phi: vm.userPhi)
            // G1 瞄准点 = 竖直瞄准线与过目标球心水平线的交点（垂足）。
            let userAimPoint = CGPoint(x: ghost.x, y: target.y)
            // Q6（问题集合 v5 V4）：白瞄准线/红 ground truth 线与红瞄准点在本页收窄，
            // 仅本页传参，不改全局 `lineMainWidth`/dot 系数真源。此特写 d≈118pt、
            // lineMainWidth 恒被钳到上限 3.2pt，收到 ~1.8pt 仍清晰可辨。
            let aimLineW = max(1.2, proj.lineMainWidth * 0.55)

            ZStack {
                // P8.1：过目标球心的水平线（= G1 定义中垂直于瞄准线的直线）。
                Path { p in
                    p.move(to: CGPoint(x: 6, y: target.y))
                    p.addLine(to: CGPoint(x: proj.size.width - 6, y: target.y))
                }
                .stroke(FigureLine.hint.opacity(0.7),
                        style: StrokeStyle(lineWidth: proj.lineHintWidth, dash: [5, 4]))

                // 用户瞄准线：白实线，竖直穿假想球心，延伸过水平线（G1 交点可见）。
                Path { p in
                    p.move(to: CGPoint(x: ghost.x, y: proj.size.height - 6))
                    p.addLine(to: CGPoint(x: ghost.x, y: target.y - d * 0.9))
                }
                .stroke(FigureLine.aim, lineWidth: aimLineW)

                // 提交后：正确瞄准线（红色）+ 正确瞄准点（水平线上的交点，条 8.3/8.4）。
                if vm.showResult {
                    let correct = ghostCenter(target: target, d: d, phi: vm.correctPhi)
                    Path { p in
                        p.move(to: CGPoint(x: correct.x, y: proj.size.height - 6))
                        p.addLine(to: CGPoint(x: correct.x, y: target.y - d * 0.9))
                    }
                    .stroke(Color(uiColor: TrajectoryStyle.aimPointColor),
                            lineWidth: aimLineW)
                    BTAimPointDot(diameter: max(5, d * 0.075))
                        .position(CGPoint(x: correct.x, y: target.y))
                }

                BTFigureBall(number: 1, diameter: d).position(target)
                // P8.2：假想球不再带球心红点。
                BTGhostCircle(diameter: d, showsAimPoint: false).position(ghost)
                // P8.3：G1 瞄准点用红色小点标注（提交后与正确点同屏对照）。
                BTAimPointDot(diameter: max(4, d * 0.06))
                    .position(userAimPoint)
                    .opacity(vm.showResult ? 0.55 : 1)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        guard !vm.showResult else { return }
                        let vx = value.location.x - target.x
                        let vy = value.location.y - target.y
                        guard abs(vx) + abs(vy) > 0.001 else { return }
                        // φ：0 = 正下方，右偏为正；钳在 ±90° 内（母球始终从下方来）。
                        let phi = atan2(Double(vx), Double(max(vy, 0.0001)))
                        vm.userPhi = min(max(phi, -.pi / 2), .pi / 2)
                    }
            )
            // F-SA-04：拖动跟手 1:1，去掉 value: userPhi 的隐式动画。
        }
    }

    /// 假想球心：目标球心 + 2R×(sin φ, cos φ)（φ=0 正下方）。
    private func ghostCenter(target: CGPoint, d: CGFloat, phi: Double) -> CGPoint {
        CGPoint(x: target.x + d * CGFloat(Foundation.sin(phi)),
                y: target.y + d * CGFloat(Foundation.cos(phi)))
    }
}

#Preview {
    NavigationStack {
        AimPointTrainingView()
            .modelContainer(ModelContainerFactory.makeInMemoryContainer())
            .environmentObject(SubscriptionManager.shared)
    }
    .preferredColorScheme(.dark)
}
