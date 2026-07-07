import SwiftUI
import SwiftData

// MARK: - 瞄准点训练（问题集合条 8）
//
// 出题型：给切角 θ 问瞄准点。目标球固定 1 号，用户拖动假想球（虚线圈 + 红心点）
// 绕目标球移动使两球重叠关系符合题目角度；白色瞄准线穿假想球心随动。
// 提交后展示正确瞄准线（红色）；误差以 mm 计（偏大为正、偏小为负），
// 历史统计取绝对值平均，写入 `AngleTestResult`（quizType = "aimPoint"，errorMM 有符号）。

@MainActor
final class AimPointTrainingViewModel: ObservableObject {

    struct Question {
        let angleDegrees: Double
        /// 进球方向在瞄准方向右侧（true）或左侧。
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

    /// 用户当前朝进球侧的横向偏移（mm，可为负 = 拖错侧）。
    var userOffsetMM: Double {
        guard let q = question else { return 0 }
        let lateral = sin(userPhi) * 2 * Self.ballRadiusMM
        return q.cutsRight ? lateral : -lateral
    }

    func correctOffsetMM(for q: Question) -> Double {
        2 * Self.ballRadiusMM * sin(q.angleDegrees * .pi / 180)
    }

    /// 正确 φ（带侧向符号，弧度）。
    var correctPhi: Double {
        guard let q = question else { return 0 }
        let phi = q.angleDegrees * .pi / 180
        return q.cutsRight ? phi : -phi
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
                } else if vm.limiter.isLimitReached {
                    limitCard
                } else if vm.question != nil {
                    promptCard
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
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

    private var statsCapsule: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                BTReadout(label: "次数", value: "\(vm.sessionResults.count)")
                divider
                BTReadout(label: "本次平均",
                          value: vm.sessionResults.isEmpty
                              ? "—" : String(format: "%.1fmm", vm.sessionMeanAbsMM))
                if let hist = vm.historicalMeanAbsMM {
                    divider
                    BTReadout(label: "历史平均", value: String(format: "%.1fmm", hist))
                }
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

    // MARK: - Figure（拖假想球）

    private var figureCard: some View {
        AimPointDragFigure(vm: vm)
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Prompt / Result

    private var promptCard: some View {
        VStack(spacing: Spacing.md) {
            if let q = vm.question {
                Text("切角 θ = \(Int(q.angleDegrees))° · 向\(q.cutsRight ? "右" : "左")切")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("拖动假想球，使其与目标球的重叠关系符合该切角，然后提交")
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

                Text(last.errorMM >= 0 ? "瞄厚了一点（偏移偏大）" : "瞄薄了一点（偏移偏小）")
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
        .buttonStyle(.plain)
    }
}

// MARK: - 拖动假想球的真台特写图

private struct AimPointDragFigure: View {
    @ObservedObject var vm: AimPointTrainingViewModel

    var body: some View {
        let r = CGFloat(AngleSceneCalculator.ballRadius)
        BTTableFigure(orientation: .landscape,
                      closeup: (center: .zero, halfHeight: r * 4.3)) { proj in
            let d = proj.ballDiameter
            let target = CGPoint(x: proj.size.width / 2, y: proj.size.height * 0.40)
            let ghost = ghostCenter(target: target, d: d, phi: vm.userPhi)

            ZStack {
                // 用户瞄准线：白实线，竖直穿假想球心（条 8.3）。
                Path { p in
                    p.move(to: CGPoint(x: ghost.x, y: proj.size.height - 6))
                    p.addLine(to: ghost)
                }
                .stroke(FigureLine.aim, lineWidth: proj.lineMainWidth)

                // 提交后：正确瞄准线（红色，条 8.4）。
                if vm.showResult {
                    let correct = ghostCenter(target: target, d: d, phi: vm.correctPhi)
                    Path { p in
                        p.move(to: CGPoint(x: correct.x, y: proj.size.height - 6))
                        p.addLine(to: correct)
                    }
                    .stroke(Color(uiColor: TrajectoryStyle.aimPointColor),
                            lineWidth: proj.lineMainWidth)
                    BTAimPointDot(diameter: max(5, d * 0.2))
                        .position(correct)
                }

                BTFigureBall(number: 1, diameter: d).position(target)
                BTGhostCircle(diameter: d).position(ghost)
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
            .animation(.easeOut(duration: 0.1), value: vm.userPhi)
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
