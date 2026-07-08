import SwiftUI
import SwiftData
import SceneKit

// MARK: - 2D/3D 瞄准点训练（问题集合 v3 批次 S3：G1 口径）
//
// 瞄准训练最终版：给定母球/目标球/袋口并**展示进球线**（虚线，绑目标球色）；
// 瞄准线初始 = 两球心连线；手指粗调 + 刻度轮微调。
// G1 口径：瞄准点 = 瞄准线与「过目标球心且垂直于瞄准线的直线」的交点（垂足）；
// 辅助线（白色细虚线）随用户瞄准线旋转、恒与其垂直。误差 = 用户瞄准点与正确瞄准点
// 相对目标球心的有符号偏移之差（mm，偏大为正 = 瞄薄）；正确瞄准点提交后以红色小点
// 标注；3 秒后按用户瞄准线物理击球，然后下一题。

@MainActor
final class AimPointSceneQuizViewModel: ObservableObject {

    enum Phase { case aiming, showingResult, striking }

    struct RoundResult {
        let errorMM: Double
    }

    // MARK: - Published

    @Published private(set) var phase: Phase = .aiming
    @Published private(set) var question: AngleQuestion?
    @Published private(set) var targetBallNumber: Int = 8
    @Published private(set) var sessionResults: [RoundResult] = []
    @Published private(set) var lastErrorMM: Double?

    let scene = AngleTrainingScene()
    let limiter: AngleUsageLimiter
    /// "aimPoint2D" / "aimPoint3D"
    var quizTypeLabel = "aimPoint2D"

    private var pocketMarkers: [SCNNode] = []
    private var lineNodes: [SCNNode] = []
    private var repository: AngleTestRepositoryProtocol?
    /// 用户瞄准方向（XZ 单位向量）。
    private var aimDir = SCNVector3(1, 0, 0)
    private var strikeTask: Task<Void, Never>?

    init(limiter: AngleUsageLimiter) {
        self.limiter = limiter
    }

    func configure(context: ModelContext) {
        repository = LocalAngleTestRepository(context: context)
    }

    // MARK: - Setup

    func setupScene(cameraMode: AngleTrainingScene.CameraMode) {
        scene.setupScene(enhancedRendering: false)
        scene.setupVisualizationNodes()
        pocketMarkers = scene.addPocketMarkers()
        scene.setCameraMode(cameraMode, animated: false)
        nextQuestion()
    }

    // MARK: - Question lifecycle

    func nextQuestion() {
        strikeTask?.cancel()
        guard !limiter.isLimitReached else { return }
        clearLines()
        scene.hideCueStick()
        scene.hideAllVisualization()

        let angle = Double(Int.random(in: 2...16) * 5) // 10°–80°
        let q = AngleCalculator.generateQuestion(
            angle: angle, pocketType: nil,
            targetPocketDistanceRange: 0.15...0.55
        )
        question = q
        targetBallNumber = Int.random(in: 1...15)

        let surfaceY = scene.surfaceY
        let cuePos = AngleSceneCalculator.normalizedToScene(point: q.cueBall, surfaceY: surfaceY)
        let targetPos = AngleSceneCalculator.normalizedToScene(point: q.targetBall, surfaceY: surfaceY)
        scene.applyBallLayout(cueBallPosition: cuePos, targetBallNumber: targetBallNumber,
                              targetPosition: targetPos)

        for (i, marker) in pocketMarkers.enumerated() {
            scene.highlightPocket(marker, highlighted: i == q.pocketIndex)
        }

        // 条 9.4：瞄准线初始 = 母球-目标球中心连线。
        aimDir = normalizedXZ(from: cuePos, to: targetPos)
        lastErrorMM = nil
        phase = .aiming
        redrawLines()
        applyAimingPoseIfNeeded()
    }

    // MARK: - Aiming input

    /// 手指粗调：朝台面世界点瞄准（条 9.3 / §1.5 指哪打哪）。
    func aimToward(worldPoint: SCNVector3) {
        guard phase == .aiming, let cue = scene.cueBallNode else { return }
        let dir = normalizedXZ(from: cue.position, to: worldPoint)
        guard dir.x != 0 || dir.z != 0 else { return }
        aimDir = dir
        redrawLines()
    }

    /// 刻度轮微调（度）。
    func nudgeAim(byDegrees delta: Float) {
        guard phase == .aiming else { return }
        let rad = delta * .pi / 180
        let cosD = cosf(rad), sinD = sinf(rad)
        aimDir = SCNVector3(aimDir.x * cosD - aimDir.z * sinD, 0,
                            aimDir.x * sinD + aimDir.z * cosD)
        redrawLines()
    }

    // MARK: - Submit（条 9.6/9.7，G1 口径）

    func submit() {
        guard phase == .aiming, let q = question,
              let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        let surfaceY = scene.surfaceY

        // 正确瞄准方向：母球 → 假想球（有效入袋点模型）。
        let aimPoint = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target.position, pocketIndex: q.pocketIndex, surfaceY: surfaceY
        )
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: target.position, pocket: aimPoint,
            ballRadius: AngleSceneCalculator.ballRadius
        )
        let correctDir = normalizedXZ(from: cue.position, to: ghost)

        // G1 瞄准点：目标球心到各瞄准线的垂足（XZ 平面，AimPointGeometry 唯一真源）。
        let cueP = xzPoint(cue.position)
        let targetP = xzPoint(target.position)
        let userFoot = AimPointGeometry.aimPoint(
            lineOrigin: cueP, direction: xzPoint(aimDir), targetCenter: targetP)
        let correctFoot = AimPointGeometry.aimPoint(
            lineOrigin: cueP, direction: xzPoint(correctDir), targetCenter: targetP)

        // 参考法向 = 目标球心 → 正确瞄准点（正确解所在侧为正，可区分瞄错侧）。
        // 直球退化（正确垂距 ≈ 0）时以用户侧为正，误差 = 用户垂距（恒偏大）。
        var normal = CGPoint(x: correctFoot.x - targetP.x, y: correctFoot.y - targetP.y)
        if hypot(normal.x, normal.y) < 1e-6 {
            normal = CGPoint(x: userFoot.x - targetP.x, y: userFoot.y - targetP.y)
        }
        let sCorrect = Double(hypot(correctFoot.x - targetP.x, correctFoot.y - targetP.y))
        let sUser = hypot(normal.x, normal.y) < 1e-9
            ? 0
            : Double(AimPointGeometry.signedOffset(
                lineOrigin: cueP, direction: xzPoint(aimDir),
                targetCenter: targetP, positiveNormal: normal))
        // 偏大为正（= 瞄薄，与瞄准点训练同约定）。
        let errorMM = (sUser - sCorrect) * 1000

        lastErrorMM = errorMM
        sessionResults.append(RoundResult(errorMM: errorMM))
        limiter.recordQuestion()

        phase = .showingResult
        redrawLines(correctDir: correctDir)

        Task {
            let result = AngleTestResult(
                actualAngle: sCorrect * 1000,
                userAngle: sUser * 1000,
                pocketType: q.pocketType.rawValue,
                quizType: quizTypeLabel,
                errorMM: errorMM
            )
            try? await repository?.save(result)
        }

        // 条 9.8：停留 3 秒 → 按用户瞄准线物理击球 → 下一题。
        strikeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.strike()
        }
    }

    // MARK: - Strike（物理击球）

    private func strike() {
        guard phase == .showingResult,
              let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        phase = .striking
        clearLines()

        let surfaceY = scene.surfaceY
        let prediction = ShotPredictor.simulateFree(
            cueBall: cue.position, aimDir: aimDir,
            velocity: 1.5, spinX: 0, spinY: 0,
            surfaceY: surfaceY,
            balls: [ObstacleBall(name: "object", position: target.position)]
        )
        guard let recorder = prediction.recorder, prediction.duration > 0.05 else {
            advanceAfterStrike()
            return
        }

        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let settle = playback.perceptibleSettleTime()

        let targetAction = playback.action(for: target, ballName: "object",
                                           removeOnPocket: false, maxSimTime: settle)
        if let targetAction { target.runAction(targetAction) }

        if let cueAction = playback.action(for: cue, ballName: ShotInput.cueBallName,
                                           removeOnPocket: false, maxSimTime: settle) {
            cue.runAction(cueAction) { [weak self] in
                Task { @MainActor in self?.advanceAfterStrike() }
            }
        } else {
            advanceAfterStrike()
        }
    }

    private func advanceAfterStrike() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            self?.nextQuestion()
        }
    }

    // MARK: - Line drawing

    private func redrawLines(correctDir: SCNVector3? = nil) {
        clearLines()
        guard let q = question,
              let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        let surfaceY = scene.surfaceY
        let y = surfaceY + AngleSceneCalculator.ballRadius

        // 进球线（条 9.2）：目标球 → 有效入袋点，绑球色虚线。
        let aimPoint = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target.position, pocketIndex: q.pocketIndex, surfaceY: surfaceY
        )
        lineNodes.append(scene.addDashedLine(
            from: SCNVector3(target.position.x, y, target.position.z),
            to: SCNVector3(aimPoint.x, y, aimPoint.z),
            color: TrajectoryStyle.potColor(forNumber: targetBallNumber)
        ))

        // 辅助线（G1）：过目标球心、垂直于**用户瞄准线**，随瞄准旋转，白色细虚线。
        // 它与瞄准线的交点即 G1 瞄准点（垂足）。
        let n = SCNVector3(-aimDir.z, 0, aimDir.x)
        let auxHalf = AngleSceneCalculator.ballRadius * 7
        lineNodes.append(scene.addDashedLine(
            from: SCNVector3(target.position.x - n.x * auxHalf, y, target.position.z - n.z * auxHalf),
            to: SCNVector3(target.position.x + n.x * auxHalf, y, target.position.z + n.z * auxHalf),
            color: TrajectoryStyle.hintColor, radius: 0.0016, dash: 0.018, gap: 0.014
        ))

        // 用户瞄准线：白实线，至目标球（假想球心）或库边（条 9.3）。
        let userEnd = aimLineEnd(cue: cue.position, target: target.position, dir: aimDir)
        lineNodes.append(scene.addLine(
            from: SCNVector3(cue.position.x, y, cue.position.z),
            to: SCNVector3(userEnd.x, y, userEnd.z),
            color: .white
        ))

        // 提交后：正确瞄准线（红）+ 正确瞄准点红色小点（G1 垂足）。
        if let correctDir {
            let correctEnd = aimLineEnd(cue: cue.position, target: target.position, dir: correctDir)
            lineNodes.append(scene.addLine(
                from: SCNVector3(cue.position.x, y, cue.position.z),
                to: SCNVector3(correctEnd.x, y, correctEnd.z),
                color: TrajectoryStyle.aimPointColor
            ))
            let foot = AimPointGeometry.aimPoint(
                lineOrigin: xzPoint(cue.position), direction: xzPoint(correctDir),
                targetCenter: xzPoint(target.position))
            lineNodes.append(addDotNode(
                at: SCNVector3(Float(foot.x), y, Float(foot.y)),
                color: TrajectoryStyle.aimPointColor
            ))
        }
    }

    /// 瞄准点标记小点（贴台面的小圆片）。
    private func addDotNode(at position: SCNVector3, color: UIColor) -> SCNNode {
        let geo = SCNCylinder(radius: 0.007, height: 0.001)
        geo.radialSegmentCount = 16
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color
        mat.lightingModel = .constant
        geo.materials = [mat]
        let node = SCNNode(geometry: geo)
        node.position = position
        scene.rootNode.addChildNode(node)
        return node
    }

    private func clearLines() {
        for node in lineNodes { node.removeFromParentNode() }
        lineNodes.removeAll()
    }

    // MARK: - Geometry helpers

    private func normalizedXZ(from a: SCNVector3, to b: SCNVector3) -> SCNVector3 {
        let dx = b.x - a.x, dz = b.z - a.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 1e-5 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(dx / len, 0, dz / len)
    }

    /// 瞄准线终点：与「以目标球心为圆心、2R 为半径的圆」相交则停在交点（假想球心位），
    /// 否则延伸到库边。
    private func aimLineEnd(cue: SCNVector3, target: SCNVector3, dir: SCNVector3) -> SCNVector3 {
        let r2 = 2 * AngleSceneCalculator.ballRadius
        let fx = cue.x - target.x, fz = cue.z - target.z
        let b = 2 * (fx * dir.x + fz * dir.z)
        let c = fx * fx + fz * fz - r2 * r2
        let disc = b * b - 4 * c
        if disc >= 0 {
            let t = (-b - sqrtf(disc)) / 2
            if t > 0 {
                return SCNVector3(cue.x + dir.x * t, cue.y, cue.z + dir.z * t)
            }
        }
        // 库边裁剪。
        let halfL = AngleSceneCalculator.innerLength / 2 - AngleSceneCalculator.ballRadius
        let halfW = AngleSceneCalculator.innerWidth / 2 - AngleSceneCalculator.ballRadius
        var tMax = Float.greatestFiniteMagnitude
        if dir.x > 1e-5 { tMax = min(tMax, (halfL - cue.x) / dir.x) }
        if dir.x < -1e-5 { tMax = min(tMax, (-halfL - cue.x) / dir.x) }
        if dir.z > 1e-5 { tMax = min(tMax, (halfW - cue.z) / dir.z) }
        if dir.z < -1e-5 { tMax = min(tMax, (-halfW - cue.z) / dir.z) }
        if tMax == .greatestFiniteMagnitude { tMax = 0 }
        return SCNVector3(cue.x + dir.x * tMax, cue.y, cue.z + dir.z * tMax)
    }

    /// SceneKit 水平面 XZ → 平面点（AimPointGeometry 入参约定：x→x，z→y）。
    private func xzPoint(_ v: SCNVector3) -> CGPoint {
        CGPoint(x: CGFloat(v.x), y: CGFloat(v.z))
    }

    // MARK: - Camera（3D 站位视角随题取景）

    private func applyAimingPoseIfNeeded() {
        guard scene.currentCameraMode == .perspective3D,
              let cue = scene.cueBallNode else { return }
        scene.cameraRig?.enterAiming(cueBallPosition: cue.position, targetDirection: aimDir)
    }

    // MARK: - Stats

    var sessionMeanAbsMM: Double {
        guard !sessionResults.isEmpty else { return 0 }
        return sessionResults.map { abs($0.errorMM) }.reduce(0, +) / Double(sessionResults.count)
    }
}

// MARK: - View

struct AimPointSceneTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm = AimPointSceneQuizViewModel(limiter: AngleUsageLimiter())
    @State private var hasAppeared = false
    @State private var showSubscription = false

    private let cameraMode: AngleTrainingScene.CameraMode

    init(initialCameraMode: AngleTrainingScene.CameraMode) {
        self.cameraMode = initialCameraMode
    }

    private var is3D: Bool { cameraMode == .perspective3D }

    var body: some View {
        ZStack {
            sceneFullscreen
            controlOverlay
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) { topInset }
        .navigationTitle(is3D ? "3D 瞄准点训练" : "2D 瞄准点训练")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.quizTypeLabel = is3D ? "aimPoint3D" : "aimPoint2D"
                vm.configure(context: modelContext)
                vm.setupScene(cameraMode: cameraMode)
            }
        }
        .onReceive(subscriptionManager.$isPremium) { premium in
            vm.limiter.isPremium = premium
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView().environmentObject(subscriptionManager)
        }
    }

    private var sceneFullscreen: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: .constant(cameraMode),
            interactionMode: vm.phase == .aiming ? .tapsOnly : .none,
            locksCueBallScreenAnchor: is3D,
            onPocketTapped: { _ in /* 袋口由题目固定 */ },
            onAimDragged: { world in vm.aimToward(worldPoint: world) }
        )
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Top inset

    @ViewBuilder
    private var topInset: some View {
        HStack(spacing: Spacing.sm) {
            if vm.phase == .showingResult, let err = vm.lastErrorMM {
                resultHUD(errorMM: err)
            } else {
                statsPill
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .animation(.easeInOut(duration: 0.2), value: vm.phase)
    }

    private var statsPill: some View {
        HStack(spacing: Spacing.md) {
            BTReadout(label: "题", value: "\(vm.sessionResults.count)")
            divider
            BTReadout(label: "均差",
                      value: vm.sessionResults.isEmpty
                          ? "—" : String(format: "%.1fmm", vm.sessionMeanAbsMM))
            if !vm.limiter.isPremium {
                divider
                BTReadout(label: "剩", value: "\(vm.limiter.remainingToday)",
                          emphasis: .adjustable, size: .compact)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .btHudGlass()
    }

    private func resultHUD(errorMM: Double) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle().fill(ratingColor(abs(errorMM))).frame(width: 7, height: 7)
            Text(String(format: "误差 %@%.1f mm", errorMM >= 0 ? "+" : "", errorMM))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(errorMM >= 0 ? "偏薄" : "偏厚")
                .font(.btCaption)
                .foregroundStyle(.white.opacity(0.6))
            divider
            Text("3 秒后自动击球验证")
                .font(.btCaption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .btHudGlass()
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 14)
    }

    private func ratingColor(_ absMM: Double) -> Color {
        if absMM <= 2 { return .btSuccess }
        if absMM <= 6 { return .btWarning }
        return .btDestructive
    }

    // MARK: - Controls（右列：刻度轮微调 + 提交）

    private var controlOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
            if vm.phase == .aiming, !vm.limiter.isLimitReached {
                VStack(spacing: Spacing.md) {
                    BTAimWheel { delta in vm.nudgeAim(byDegrees: delta) }
                        .frame(width: 44, height: 170)
                    BTTextActionButton(title: "提交", role: .primary) {
                        vm.submit()
                    }
                }
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, Spacing.xl + 40)
                .transition(.opacity)
            } else if vm.limiter.isLimitReached, vm.phase == .aiming {
                limitCard
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.phase)
    }

    private var limitCard: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 28))
                .foregroundStyle(.btAccent)
            Text("今日免费次数已用完")
                .font(.btHeadline)
                .foregroundStyle(.white)
            Button {
                showSubscription = true
            } label: {
                Text("解锁全部内容")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.btPrimary))
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.xl)
        .btHudGlass(in: RoundedRectangle(cornerRadius: BTRadius.xl))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("2D") {
    NavigationStack {
        AimPointSceneTrainingView(initialCameraMode: .topDown2DRotated)
            .modelContainer(ModelContainerFactory.makeInMemoryContainer())
            .environmentObject(SubscriptionManager.shared)
    }
    .preferredColorScheme(.dark)
}
