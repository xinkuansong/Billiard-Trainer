import SwiftUI
import SwiftData
import SceneKit

// Shared range training; submission freezes the user line for geometric comparison.

@MainActor
final class AimPointSceneQuizViewModel: TeachingCameraHost {

    enum Phase { case aiming, showingResult }

    struct RoundResult {
        let errorMM: Double?
    }

    // MARK: - Published

    @Published private(set) var phase: Phase = .aiming
    @Published private(set) var question: AngleQuestion?
    @Published private(set) var targetBallNumber: Int = 8
    @Published private(set) var sessionResults: [RoundResult] = []
    @Published private(set) var lastErrorMM: Double?
    @Published var run = SceneTrainingRun()
    @Published var showSettings = false
    @Published var finished = false
    @Published var generationError: String?
    @Published private(set) var showAngleHint = false
    @Published private(set) var lastScore: SceneAimScore?
    @Published private(set) var answerCloseupSnapshot: AimCloseupSnapshot?
    /// v23：毫米口径轮增益（°/pt）；默认旧值，redraw 后刷新。
    @Published private(set) var aimWheelDegreesPerPoint: Float = AimWheelGain.defaultDegreesPerPoint
    /// v23：近区 ∧ 正在改瞄准时非 nil → 显示特写 HUD。
    @Published private(set) var closeupSnapshot: AimCloseupSnapshot?
    /// v23.4：特写粗角位（chrome 让位 / 动画键）。
    @Published private(set) var closeupCorner: AimCloseupPlacement.Corner = .topTrailing
    /// 落库失败的可见错误态（nil = 无错误）。禁止静默丢题。
    @Published private(set) var saveErrorMessage: String?
    /// 落库失败但已保留的成绩，供重试；用户答案始终留在 `sessionResults`。
    @Published private(set) var unsavedResults: [AngleTestResult] = []

    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2D
    @Published var cameraTransitionBusy = false
    @Published var temporaryTopDownActive = false
    @Published var topDownContentRevision = 0
    var topDownSelectionChanged = false
    var targetNode: SCNNode? { scene.targetBallNodes.first }
    var selectedPocketIndex: Int { question?.pocketIndex ?? -1 }
    var currentPlayerAim: SCNVector3? { question == nil ? nil : aimDir }
    let scene = AngleTrainingScene()
    let limiter: AngleUsageLimiter
    /// "aimPoint2D" / "aimPoint3D"
    var quizTypeLabel = "aimPoint2D"

    private var pocketMarkers: [SCNNode] = []
    private var lineNodes: [SCNNode] = []
    private var repository: AngleTestRepositoryProtocol?
    /// 用户瞄准方向（XZ 单位向量）。
    private var aimDir = SCNVector3(1, 0, 0)
    private var proximityWasNear = false
    private lazy var closeupGate: AimCloseupGate = {
        let gate = AimCloseupGate()
        gate.onSnapshotChange = { [weak self] in self?.closeupSnapshot = $0 }
        return gate
    }()

    init(limiter: AngleUsageLimiter) {
        self.limiter = limiter
    }

    func configure(context: ModelContext) {
        repository = LocalAngleTestRepository(context: context)
    }

    /// 直接注入仓储（测试用失败仓储覆盖保存失败路径）。
    func configure(repository: AngleTestRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Setup

    func setupScene(cameraMode: AngleTrainingScene.CameraMode, autoStart: Bool = true) {
        self.cameraMode = cameraMode
        scene.configureReferenceTableRendering()
        if cameraMode == .perspective3D { scene.configureShotAwareCamera() }
        scene.setupScene(enhancedRendering: false)
        scene.setupVisualizationNodes()
        pocketMarkers = scene.addPocketMarkers()
        if cameraMode == .perspective3D { configureTeachingCamera() }
        scene.setCameraMode(cameraMode, animated: false)
        if autoStart { startTest() }
    }

    // MARK: - Question lifecycle

    func startTest(configuration: SceneTrainingConfiguration = .init(), questions: [SceneTrainingQuestion] = []) {
        run = SceneTrainingRun(configuration: configuration, queue: questions)
        sessionResults = []; finished = false; generationError = nil
        nextQuestion()
    }

    func nextQuestion() {
        answerCloseupSnapshot = nil
        endTemporaryTopDown()
        guard !run.canFinish, !limiter.isLimitReached else { finished = true; return }
        let q: AngleQuestion
        do { q = try run.next(); generationError = nil }
        catch { generationError = error.localizedDescription; return }
        applyQuestion(q)
    }

    private func applyQuestion(_ q: AngleQuestion) {
        clearLines()
        scene.hideCueStick()
        scene.hideAllVisualization()
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

        scene.confirmPocketSelection(at: q.pocketIndex)

        // 条 9.4：瞄准线初始 = 母球-目标球中心连线。
        aimDir = normalizedXZ(from: cuePos, to: targetPos)
        lastErrorMM = nil
        showAngleHint = false
        lastScore = nil
        answerCloseupSnapshot = nil
        proximityWasNear = false
        closeupGate.reset()
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
        closeupGate.noteAimChanged()
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

    func setAimWheelDragging(_ active: Bool) {
        closeupGate.setDragging(active)
    }

    func setAimTableDragging(_ active: Bool) {
        closeupGate.setDragging(active, source: .table)
    }

    // MARK: - Submit（条 9.6/9.7，G1 口径）

    func submit() {
        guard phase == .aiming, !run.submitted, !limiter.isLimitReached, let q = question,
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

        let score = SceneAimScore.measure(cue: cue.position, target: target.position, ghost: ghost, direction: aimDir)
        lastScore = score
        lastErrorMM = score.millimetres
        let metadata = run.metadata(unit: "mm", direction: aimDir, score: score)
        sessionResults.append(RoundResult(errorMM: score.millimetres))
        if quizTypeLabel == "aimPoint2D" { limiter.recordQuestion() }
        run.record(error: score.millimetres.map(abs), signedError: score.straight ? nil : score.millimetres, angle: q.actualAngle)
        BTFeedback.quiz(errorMM: score.millimetres ?? 100)
        phase = .showingResult
        endTemporaryTopDown()
        redrawLines()
        answerCloseupSnapshot = makeCloseupSnapshot(cue: cue.position, target: target.position,
            band: .contact, standardDirection: correctDir)
        // Legacy numeric fields remain finite for old clients; metadata is authoritative for invalid answers.
        let result = AngleTestResult(actualAngle: 0, userAngle: score.millimetres ?? 0,
            pocketType: q.pocketType.rawValue, quizType: quizTypeLabel, errorMM: score.millimetres ?? 0)
        result.trainingMetadataJSON = metadata?.json
        Task { await persist(result) }
        // Even the last answer is reviewed before the user opens the summary.
    }

    func toggleAngleHint() {
        guard phase == .aiming else { return }
        showAngleHint.toggle()
        if showAngleHint { run.assistance.insert("angleHint") }
    }

    func markObservation() {
        if phase == .aiming && cameraMode == .perspective3D { run.assistance.insert("observation") }
    }


    func finish() { endTemporaryTopDown(); finished = true }

    /// 重试此前失败的落库；失败仍会重新置错误态。
    func retryFailedSaves() {
        let pending = unsavedResults
        guard !pending.isEmpty else { return }
        unsavedResults = []
        saveErrorMessage = nil
        Task {
            for result in pending { await persist(result) }
        }
    }

    private func persist(_ result: AngleTestResult) async {
        guard let repository else { return }
        do {
            try await repository.save(result)
        } catch {
            unsavedResults.append(result)
            saveErrorMessage = AngleResultSaveFailure.message(error)
        }
    }

    // MARK: - Line drawing

    private func redrawLines() {
        defer { topDownContentRevision &+= 1 }
        clearLines()
        guard let q = question,
              let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        let surfaceY = scene.surfaceY
        let y = surfaceY + AngleSceneCalculator.ballRadius

        // 进球线（条 9.2）：目标球 → 有效入袋点，绿色球用白线，其余保留球色虚线。
        let aimPoint = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target.position, pocketIndex: q.pocketIndex, surfaceY: surfaceY
        )
        lineNodes.append(scene.addDashedLine(
            from: SCNVector3(target.position.x, y, target.position.z),
            to: SCNVector3(aimPoint.x, y, aimPoint.z),
            color: TrajectoryStyle.TrainingAssist.potColor(forNumber: targetBallNumber), placement: .table
        ))

        // 辅助线（G1）：过目标球心、垂直于**用户瞄准线**，随瞄准旋转，白色细虚线。
        // 它与瞄准线的交点即 G1 瞄准点（垂足）。
        let n = SCNVector3(-aimDir.z, 0, aimDir.x)
        let auxHalf = AngleSceneCalculator.ballRadius * 7
        lineNodes.append(scene.addDashedLine(
            from: SCNVector3(target.position.x - n.x * auxHalf, y, target.position.z - n.z * auxHalf),
            to: SCNVector3(target.position.x + n.x * auxHalf, y, target.position.z + n.z * auxHalf),
            color: TrajectoryStyle.hintColor, radius: 0.0016, dash: TrajectoryStyle.hintDash, gap: TrajectoryStyle.hintGap, placement: .table
        ))

        // 用户瞄准线（Q7.1）：白色实线。未接触目标球 → 延伸库边；接触（垂距 < R）→ 停在
        // 射线与球面第一交点（接触点）；垂足用青蓝小点、接触点用橙黄小点。
        let userRes = aimLineResolution(cue: cue.position, target: target.position, dir: aimDir)
        lineNodes.append(scene.addLine(
            from: SCNVector3(cue.position.x, y, cue.position.z),
            to: scenePoint(userRes.lineEnd, y: y),
            color: TrajectoryStyle.TrainingAssist.aimLine, placement: .table
        ))
        if userRes.touchesBall {
            lineNodes.append(scene.addAimPointMarker(at: scenePoint(userRes.aimPoint, y: y),
                                                     color: TrajectoryStyle.TrainingAssist.aimPoint,
                                                     radius: TrajectoryStyle.TrainingAssist.aimPointRadius, isOverlay: true))
            if let contact = userRes.contactPoint {
                lineNodes.append(scene.addAimPointMarker(at: scenePoint(contact, y: y),
                                                         color: TrajectoryStyle.TrainingAssist.contactPoint,
                                                         radius: TrajectoryStyle.TrainingAssist.aimPointRadius, isOverlay: true))
            }
        }

        // C5 / D-v19-1：瞄准及结果停留阶段同现球杆；沿用户 aim，spinX:0 与出杆一致。
        if phase == .aiming || phase == .showingResult {
            scene.updateCueStick(
                cueBallPosition: CueStroke.strikePosition(cue: cue.position, aim: aimDir, spinX: 0),
                aimDirection: aimDir
            )
        }

        if phase == .aiming {
            updateAimAssistState(cue: cue.position, target: target.position)
        } else {
            proximityWasNear = false
            closeupGate.reset()
            aimWheelDegreesPerPoint = AimWheelGain.defaultDegreesPerPoint
        }
    }

    /// v23 / v23.4：毫米增益 + 近区特写（与 `redrawLines` **同源用户层**，紧取景放大）。
    private func updateAimAssistState(cue: SCNVector3, target: SCNVector3) {
        let cueP = xzPoint(cue)
        let targetP = xzPoint(target)
        let dirP = xzPoint(aimDir)
        let r = CGFloat(AngleSceneCalculator.ballRadius)
        let sample = AimProximityMath.advance(
            cue: cueP, direction: dirP, target: targetP,
            ballRadius: r, previouslyNear: proximityWasNear)
        proximityWasNear = sample.isNear

        let d = hypotf(target.x - cue.x, target.z - cue.z)
        aimWheelDegreesPerPoint = AimWheelGain.degreesPerPoint(distanceMeters: d)

        guard sample.isNear else {
            closeupGate.update(.init(snapshot: nil, isNear: false))
            return
        }

        closeupGate.update(.init(snapshot: makeCloseupSnapshot(cue: cue, target: target, band: sample.band), isNear: true))
    }

    private func makeCloseupSnapshot(cue: SCNVector3, target: SCNVector3,
                                    band: AimProximityMath.Band, standardDirection: SCNVector3? = nil) -> AimCloseupSnapshot? {
        guard let q = question else { return nil }
        let cueP = xzPoint(cue), targetP = xzPoint(target)
        let r = CGFloat(AngleSceneCalculator.ballRadius)
        let userRes = aimLineResolution(cue: cue, target: target, dir: aimDir)
        // AimPoint 场景瞄准态不画假想球圈（仅线 + 垂线 + 触球标记）⇒ HUD 同步不发明 ghost。
        let potEnd = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target, pocketIndex: q.pocketIndex, surfaceY: scene.surfaceY)
        let potEndP = xzPoint(potEnd)
        let halfL = CGFloat(scene.cameraRig?.tableOuterHalfLength
                            ?? ShotTableLayout.defaultHalfLength)
        let halfW = CGFloat(scene.cameraRig?.tableOuterHalfWidth
                            ?? ShotTableLayout.defaultHalfWidth)
        let focusNorm = AimCloseupPlacement.focusNormInRotatedTopDown(
            worldXZ: targetP, halfLength: halfL, halfWidth: halfW)
        // Fresh pick when HUD was hidden — default corner + hysteresis otherwise
        // pins the loupe on the object ball (FL-028). Leading column blocked by
        // the aim wheel / thumb. Center is offset from the focus (D-v23-5‴),
        // not pinned to a screen corner.
        closeupCorner = AimCloseupPlacement.corner(
            focusNorm: focusNorm,
            previous: closeupSnapshot != nil ? closeupCorner : nil,
            blockedSide: .leading)

        let cueInFrame = hypot(cueP.x - targetP.x, cueP.y - targetP.y) < r * 3.2 * 1.35
        // Both answer rays start at the actual cue center. Extend beyond the loupe,
        // never translate a parallel copy of the submitted direction to the answer point.
        let rayLength = hypot(targetP.x - cueP.x, targetP.y - cueP.y) + 2 * r * 3.2
        func answerRay(_ direction: SCNVector3) -> AimCloseupSegment {
            let length = hypot(CGFloat(direction.x), CGFloat(direction.z))
            return AimCloseupSegment(start: cueP, end: CGPoint(
                x: cueP.x + CGFloat(direction.x) / length * rayLength,
                y: cueP.y + CGFloat(direction.z) / length * rayLength))
        }
        let snap = AimCloseupSnapshot(
            band: band,
            focus: targetP,
            ballRadius: r,
            halfWorld: r * 3.2,
            showsTargetBall: true,
            targetBallNumber: targetBallNumber,
            cue: cueInFrame ? cueP : nil,
            aimLine: standardDirection == nil ? AimCloseupSegment(start: cueP, end: userRes.lineEnd) : answerRay(aimDir),
            potLine: AimCloseupSegment(start: targetP, end: potEndP),
            ghost: nil,
            aimPointMarker: userRes.touchesBall ? userRes.aimPoint : nil,
            contactMarker: userRes.touchesBall ? userRes.contactPoint : nil,
            standardAimLine: standardDirection.map(answerRay),
            showMissCaption: standardDirection == nil && band == .skim,
            usesTrainingAssistStyle: true,
            focusNorm: focusNorm,
            // D-v23-5.1：进球线/袋口 + 瞄准线避让；方位走空象限。
            sightKeepout: .fromWorld(
                object: targetP, pocket: potEndP,
                halfLength: halfL, halfWidth: halfW,
                cue: cueP, aimEnd: userRes.lineEnd)
        )
        return snap.withCenterReferences(cue: cueP)
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

    /// 用户/正确瞄准线的白线终点 + 红点解析（Q7.1，纯几何真源 `AimLineGeometry`）。
    /// 未接触目标球时延伸的库边终点用 `rayToInnerRail`（V1 共享，各方向缩一颗球半径）。
    private func aimLineResolution(cue: SCNVector3, target: SCNVector3,
                                   dir: SCNVector3) -> AimLineGeometry.Resolution {
        let railEnd = AngleSceneCalculator.rayToInnerRail(from: cue, dir: dir)
        return AimLineGeometry.resolve(
            cue: xzPoint(cue), dir: xzPoint(dir), target: xzPoint(target),
            ballRadius: CGFloat(AngleSceneCalculator.ballRadius),
            railEnd: xzPoint(railEnd))
    }

    /// SceneKit 水平面 XZ → 平面点（AimPointGeometry 入参约定：x→x，z→y）。
    private func xzPoint(_ v: SCNVector3) -> CGPoint {
        CGPoint(x: CGFloat(v.x), y: CGFloat(v.z))
    }

    /// 平面点（x→X，y→Z）→ SceneKit 世界点（贴台面高度 `y`）。`xzPoint` 的逆。
    private func scenePoint(_ p: CGPoint, y: Float) -> SCNVector3 {
        SCNVector3(Float(p.x), y, Float(p.y))
    }

    // MARK: - Camera（3D 站位视角随题取景）

    func applyAimingPoseIfNeeded() {
        guard cameraMode == .perspective3D else { return }
        requestPlayerView(scene.cameraRig?.twoViewMode ?? .thirdPerson, animated: false)
    }

    func stopTraining() {
        endTemporaryTopDown()
        closeupGate.reset()
    }

    // MARK: - Stats

    var sessionMeanAbsMM: Double {
        guard !sessionResults.isEmpty else { return 0 }
        let values = sessionResults.compactMap { $0.errorMM }.map(abs)
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}

// MARK: - View

struct AimPointSceneTrainingView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var editingControlLayout = false
    @State private var scenePausedBeforeLayout = false
    @State private var observingCamera = false
    @State private var draggingAimWheel = false
    @State private var draggingAimTable = false
    @State private var protectedCloseupFrames: [CGRect] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm = AimPointSceneQuizViewModel(limiter: .aimPointTraining)
    @StateObject private var fps = TableFPSReadoutState()
    @ObservedObject private var preferences = UserPreferences.shared
    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    private var preferencePage: TablePreferencePage { is3D ? .aimPointScene3D : .aimPointScene2D }
    private var pagePreferences: TablePreferenceSnapshot { tablePreferences.snapshot(for: preferencePage) }
    private func applyPagePreferences() {
        vm.scene.tablePreferencePage = preferencePage
        vm.scene.tablePreferences = pagePreferences
        vm.scene.setTableGridVisible(pagePreferences.enabled(.grid))
    }
    private func togglePreference(_ field: TablePreferenceField) {
        tablePreferences.apply(field, value: pagePreferences.enabled(field) ? 0 : 1, to: preferencePage)
        applyPagePreferences()
    }
    @State private var hasStarted = false
    @State private var hasAppeared = false
    @State private var scenePrepared = false
    @State private var showSubscription = false
    @State private var pendingRestart = false
    @State private var showMenu = false
    @State private var portrait = false
    @State private var cameraReadableFrame: CGRect?
    @State private var windowControls = UIEdgeInsets.zero
    @State private var windowSafeArea = UIEdgeInsets.zero
    @State private var systemStatusVisible = false
    private let routeCameraMode: AngleTrainingScene.CameraMode

    init(initialCameraMode: AngleTrainingScene.CameraMode) { routeCameraMode = initialCameraMode }
    private var is3D: Bool { routeCameraMode == .perspective3D }
    private var cameraMode: AngleTrainingScene.CameraMode {
        is3D ? .perspective3D : (portrait ? .topDown2DRotated : .topDown2D)
    }
    private var title: String { is3D ? "3D瞄准点" : "2D瞄准点" }
    private var canAim: Bool { vm.phase == .aiming && !vm.limiter.isLimitReached && !showMenu && !editingControlLayout && !vm.finished && !vm.showSettings }

    private var controlLayoutBusy: Bool {
        observingCamera || draggingAimWheel || draggingAimTable || vm.cameraTransitionBusy || vm.temporaryTopDownActive
            || vm.showSettings || vm.finished || vm.generationError != nil || vm.question == nil || vm.limiter.isLimitReached
    }
    private func endLayoutTouches() {
        observingCamera = false; draggingAimWheel = false; draggingAimTable = false
        vm.setAimWheelDragging(false); vm.setAimTableDragging(false)
    }

    private var showingTable: Bool { hasStarted && !vm.showSettings }

    var body: some View {
        ZStack {
            if showingTable { tableContent }
            else { settingsContent }
        }
        .angleSaveErrorBanner(message: vm.saveErrorMessage) { vm.retryFailedSaves() }
        .trainingBackgroundMusic()
        .preference(key: TrainingActivityPausedKey.self, value: editingControlLayout)
        .onChange(of: editingControlLayout) { _, editing in
            if editing { scenePausedBeforeLayout = vm.scene.isPaused; vm.scene.isPaused = true }
            else { vm.scene.isPaused = scenePausedBeforeLayout }
        }
        .navigationTitle(showingTable ? title : "训练设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(showingTable ? .hidden : .visible, for: .navigationBar)
        .background { if hasStarted { DailyTableOrientation(landscape: !vm.showSettings, allowsTabletRotation: true) } }
        .statusBarHidden(showingTable && UIDevice.current.userInterfaceIdiom != .pad)
        .onChange(of: tablePreferences.revision) { _, _ in applyPagePreferences() }
        .onAppear {
            applyPagePreferences()
            guard !hasAppeared else { return }
            hasAppeared = true
            vm.quizTypeLabel = is3D ? "aimPoint3D" : "aimPoint2D"
            vm.configure(context: modelContext)
            vm.run.configuration = .load(for: vm.quizTypeLabel)
        }
        .onDisappear {
            if editingControlLayout { vm.scene.isPaused = scenePausedBeforeLayout }
            endLayoutTouches(); vm.stopTraining()
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { endLayoutTouches(); vm.endTemporaryTopDown() } }
        .onReceive(subscriptionManager.$isPremium) { vm.limiter.isPremium = $0 }
        .sheet(isPresented: $showSubscription, onDismiss: {
            if pendingRestart && subscriptionManager.isPremium { vm.showSettings = true }
            pendingRestart = false
        }) { SubscriptionView().environmentObject(subscriptionManager) }
        .alert("出题未完成", isPresented: Binding(get: { vm.generationError != nil }, set: { if !$0 { vm.generationError = nil } })) {
            Button("重新生成") { vm.nextQuestion() }
            Button("调整范围") { vm.showSettings = true }
        } message: { Text(vm.generationError ?? "") }
    }

    private var settingsContent: some View {
        SceneTrainingSettings(route: is3D ? "aimPoint3D" : "aimPoint2D", configuration: vm.run.configuration,
            restarting: hasStarted, onStart: { configuration, questions in
                if !scenePrepared { vm.setupScene(cameraMode: cameraMode, autoStart: false); scenePrepared = true }
                vm.startTest(configuration: configuration, questions: questions)
                hasStarted = true; vm.showSettings = false
            }, onCancel: {
                if hasStarted { vm.showSettings = false } else { dismiss() }
            })
    }

    private var tableContent: some View {
        GeometryReader { geo in
            let extraTop = UIDevice.current.userInterfaceIdiom == .pad ? max(0, windowSafeArea.top - geo.safeAreaInsets.top) : 0
            let extraBottom = UIDevice.current.userInterfaceIdiom == .pad ? max(0, windowSafeArea.bottom - geo.safeAreaInsets.bottom) : 0
            let size = CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                              height: max(0, geo.size.height - extraTop - extraBottom))
            tableTemplate(size: size, safe: max(geo.safeAreaInsets.leading, geo.safeAreaInsets.trailing))
                .frame(width: geo.size.width + geo.safeAreaInsets.trailing, alignment: .leading)
                .padding(.top, extraTop).padding(.bottom, extraBottom)
                .offset(x: -geo.safeAreaInsets.leading)
                .ignoresSafeArea(.container, edges: .trailing)
        }
    }

    private func tableTemplate(size: CGSize, safe: CGFloat) -> some View {
        let side = max(4, safe)
        let keys = PositionPlayBall.allKeys.filter { !PositionPlayBall.isCue($0) }
        let halfL = vm.scene.cameraRig?.tableOuterHalfLength ?? CameraRig.defaultTableOuterHalfLength
        let halfW = vm.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth
        let reservation = DailyLayoutMetrics.FoundationReservation(width: size.width - 2 * side,
            targetCount: keys.count, chineseEightBall: true, titleWidth: 92, actionWidth: 138,
            prefersSeparateRow: size.height > size.width || size.height >= 600,
            separateWidth: size.width > size.height && size.height < 600 ? size.width - 2 * (side + 68) : nil)
        let f = DailyLayoutMetrics.Foundation(size: size, leadingSafeArea: safe, trailingSafeArea: safe,
            halfLength: halfL, halfWidth: halfW,
            instrumentHeight: DailyLayoutMetrics.Controls.initialInstrumentHeight, palette: reservation)
        let plan = DailyLayoutMetrics.Palette(size: size, sideInset: side, table: f.table,
            targetCount: keys.count, chineseEightBall: true, obstacles: [
                CGRect(x: side + windowControls.left, y: 0, width: 44, height: 44),
                CGRect(x: side + windowControls.left + 32, y: 5, width: 60, height: 34),
                CGRect(x: size.width - side - windowControls.right - 44, y: 0, width: 44, height: 44), f.left, f.right])
        let ppm = f.table.height / CGFloat(2 * (f.rotated ? halfL : halfW))
        let instruments = BTTeachingInstrumentLayout(foundation: f)
        let teachingLayout = BTTeachingPageLayout(stageSize: f.stage.size, rotated: f.rotated,
            pointsPerMetre: ppm, instruments: instruments, spinPadPresented: false)
        return ZStack(alignment: .topLeading) {
            DailyTemplateHeader(size: size, safe: safe, foundation: f, plan: plan,
                targets: keys, chineseEightBall: true, titleWidth: 60, titleHeight: 34,
                windowControlInsets: windowControls, fps: fps, showsDeviceStatus: !systemStatusVisible,
                title: {
                    HStack(spacing: -12) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left").font(.btTitle2)
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                        }.accessibilityLabel("返回").accessibilityIdentifier("aimPointTraining.back")
                        BTTablePageTitle(title, fitsLongText: true)
                            .accessibilityIdentifier("training.pageTitle")
                    }.fixedSize(horizontal: true, vertical: false)
                }, actions: {
                    Button { showMenu = true } label: {
                        Image(systemName: BTIcon.menuCircle).font(.btTitle2).frame(width: 44, height: 44)
                            .background { BTHUDControlBackground(shape: Circle()) }
                    }.accessibilityLabel("更多").accessibilityIdentifier("aimPointTraining.settings")
                }, ball: { key, diameter, height in
                    let selected = PositionPlayBall.number(for: key) == vm.targetBallNumber
                    PoolBallFace(key: key, diameter: diameter).opacity(selected ? 1 : 0.25)
                        .overlay(Circle().stroke(selected ? HUDStyle.accent : .clear, lineWidth: 1))
                        .frame(width: diameter + 2, height: height)
                        .accessibilityLabel("\(PositionPlayBall.shortLabel(for: key))号球")
                        .accessibilityValue(selected ? "当前目标球" : "参考球")
                        .accessibilityIdentifier("aimPointTraining.ball." + key)
                }, paletteMarker: { Color.clear.accessibilityElement().accessibilityLabel("题目球库").accessibilityIdentifier("aimPointTraining.palette") })
                .background(DailyWindowControlInsets { controls, window, visible in
                    windowControls = controls; windowSafeArea = window; systemStatusVisible = visible
                }.allowsHitTesting(false))
            Color.clear.accessibilityElement().accessibilityLabel("瞄准点训练球桌区域").accessibilityIdentifier("aimPointTraining.stage")
                .frame(width: f.stage.width, height: f.stage.height)
                .background(GeometryReader { g in
                    Color.clear.preference(key: AimPointReadableFrame.self, value: g.frame(in: .global))
                })
                .position(x: f.stage.midX, y: f.stage.midY).allowsHitTesting(false)
            VStack(spacing: instruments.groupSpacing) {
                // Match the shared instrument entry. Statistics must not move the ruler.
                Color.clear.frame(height: instruments.topDiameter + 14)
                    .overlay { questionInformation }
                BTTeachingAimRuler(layout: instruments,
                    enabled: canAim && !vm.temporaryTopDownActive,
                    onNudge: { vm.nudgeAim(byDegrees: $0) }, degreesPerPoint: vm.aimWheelDegreesPerPoint,
                    onDragActiveChanged: { draggingAimWheel = $0; vm.setAimWheelDragging($0) })
                    .accessibilityIdentifier("aimPointTraining.aimWheel")
                answerInformation
            }.fixedSize(horizontal: false, vertical: true)
                .frame(width: f.left.width)
                .controlLayoutGroup(.direction)
                .frame(width: f.left.width, height: f.left.height, alignment: .top)
                .position(x: f.left.midX, y: f.left.midY)
            BTTeachingInformationLayer(items: trainingInformation)
                .environment(\.teachingTableLayout, teachingLayout)
                .frame(width: f.stage.width, height: f.stage.height)
                .position(x: f.stage.midX, y: f.stage.midY)
            if is3D {
                observationColumn.controlLayoutGroup(.camera).position(x: f.right.minX - 26, y: f.table.midY)
            }
            VStack {
                if vm.phase == .showingResult {
                    VStack(alignment: .leading, spacing: 6) {
                        VStack(spacing: 2) {
                            Text(vm.question.map { "切角 \(Int($0.actualAngle.rounded()))°" } ?? "切角 —")
                                .font(.system(size: 12, weight: .medium)).monospacedDigit()
                                .foregroundStyle(.white).lineLimit(1)
                            ThicknessOverlapIcon(cutAngle: vm.question?.actualAngle ?? 0)
                                .opacity(vm.question == nil ? 0.3 : 1)
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity)
                        answerLegendRow("目标", color: Color(uiColor: TrajectoryStyle.TrainingAssist.standardAimLine))
                        answerLegendRow("实际", color: Color(uiColor: TrajectoryStyle.TrainingAssist.aimLine))
                        Text(answerDeviationText)
                            .font(.system(size: 10, weight: .medium)).monospacedDigit()
                            .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("aimPointTraining.answerLegend")
                    .padding(.top, Spacing.md)
                }
                Spacer(minLength: 0)
                if vm.phase == .aiming {
                    Button { vm.toggleAngleHint() } label: {
                        Text("辅助").font(.btSubheadlineSemibold)
                            .frame(width: 52, height: 52)
                    }.buttonStyle(DailyStrikeButtonStyle()).disabled(!canAim)
                        .accessibilityIdentifier("aimPointTraining.angleHint")
                        .accessibilityValue(vm.showAngleHint ? "已开启" : "已关闭")
                    .freeControlItem("aimPoint.hint", name: "辅助")
                    Button { vm.submit() } label: {
                        Text("提交").font(.btSubheadlineSemibold).frame(width: 52, height: 52)
                    }.buttonStyle(DailyStrikeButtonStyle()).disabled(!canAim)
                        .accessibilityIdentifier("aimPointTraining.submit")
                        .freeControlItem("aimPoint.submit", name: "提交")
                } else {
                    Button { vm.nextQuestion() } label: {
                        Text(vm.run.canFinish || vm.limiter.isLimitReached ? "总结" : "下一题")
                            .font(.btSubheadlineSemibold).frame(width: 52, height: 52)
                    }.buttonStyle(DailyStrikeButtonStyle()).accessibilityIdentifier("aimPointTraining.next")
                        .freeControlItem("aimPoint.next", name: "下一题")
                }
            }.frame(width: 60, height: min(200, f.stage.height))
                .padding(.vertical, Spacing.sm).controlLayoutGroup(.primary).position(x: f.right.midX, y: f.table.midY)
            GeometryReader { stage in
                BTAimCloseupOverlay(snapshot: vm.temporaryTopDownActive || showMenu || editingControlLayout || vm.finished || scenePhase != .active
                    ? nil : (vm.answerCloseupSnapshot ?? vm.closeupSnapshot),
                    sceneSize: stage.size, scene: vm.scene, blockedSide: nil,
                    protectsDailySight: true, frameInWindow: stage.frame(in: .global),
                    placementBounds: playingRect(size: stage.size, halfL: halfL, halfW: halfW, rotated: f.rotated),
                    protectedFramesInWindow: protectedCloseupFrames,
                    ignoresPreference: vm.answerCloseupSnapshot != nil)
            }.frame(width: f.stage.width, height: f.stage.height)
                .position(x: f.stage.midX, y: f.stage.midY).allowsHitTesting(false)
            if vm.limiter.isLimitReached && vm.phase == .aiming && !vm.finished {
                BTDailyLimitGate(compact: vm.phase != .aiming) { showSubscription = true }
                    .frame(width: min(400, f.stage.width)).position(x: f.stage.midX, y: f.stage.midY)
            }
            if vm.finished {
                Color.black.opacity(0.32)
                SceneTrainingSummary(samples: vm.run.firstAnswers, unit: "mm", onClose: { dismiss() }, onRestart: {
                    vm.limiter.refreshDay()
                    if !subscriptionManager.isPremium && (is3D || vm.limiter.isLimitReached) { pendingRestart = true; showSubscription = true }
                    else { vm.showSettings = true }
                }).frame(width: min(520, size.width - 16))
                    .position(x: size.width / 2, y: size.height / 2)
            }
            if showMenu {
                Button { showMenu = false } label: { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityLabel("关闭菜单").accessibilityIdentifier("aimPointTraining.dismissMenu")
                DailyHUDMenuPanel(title: nil, items: settingsItems,
                    availableSize: CGSize(width: size.width - 2 * side, height: size.height - DailyLayoutMetrics.Panels.top - 8),
                    onBack: { showMenu = false }, onClose: { showMenu = false })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, DailyLayoutMetrics.Panels.top).padding(.trailing, side + windowControls.right)
            }
        }
        .frame(width: size.width, height: size.height)
        .background {
            GeometryReader { viewport in
                let fullFrame = viewport.frame(in: .global)
                let renderFrame = is3D ? fullFrame : (cameraReadableFrame ?? fullFrame)
                sceneFullscreen.frame(width: renderFrame.width, height: renderFrame.height)
                    .position(x: renderFrame.midX - fullFrame.minX, y: renderFrame.midY - fullFrame.minY)
                    .opacity(is3D || cameraReadableFrame != nil ? 1 : 0).allowsHitTesting(!showMenu)
            }.ignoresSafeArea()
        }
        .background { DailyCarpetBackground(style: preferences.roomStyle, pointsPerMetre: ppm).ignoresSafeArea()
                .accessibilityRepresentation { EmptyView() } }
        .environment(\.colorScheme, .dark).environment(\.dailyHUDControls, true)
        .controlLayoutHost(page: preferencePage, mode: is3D ? .threeD : .twoD, size: size,
            leading: f.left, trailing: f.right, defaultFits: f.fits && plan.fits,
            obstacles: plan.controlLayoutProtectionFrames(table: f.table), busy: controlLayoutBusy,
            editing: $editingControlLayout, rulerHeight: instruments.rulerLength,
            primaryTitle: vm.phase == .aiming ? "提交" : "下一题", editorToolbarTop: f.table.minY)
        .onPreferenceChange(BTCloseupProtectedFramesKey.self) { protectedCloseupFrames = $0 }
        #if DEBUG
        .background {
            if DailyLayoutProbe.enabled {
                Color.clear.accessibilityElement().accessibilityLabel("瞄准点训练状态").accessibilityIdentifier("aimPointTraining.layoutState")
                    .accessibilityValue("run=\(vm.run.id);question=\(String(describing: vm.question));phase=\(vm.phase);aim=\(String(describing: vm.currentPlayerAim));submitted=\(vm.run.submitted);answers=\(vm.run.firstAnswers.count);quiz=\(vm.quizTypeLabel);finished=\(vm.finished);error=\(String(describing: vm.lastErrorMM));assistance=\(vm.run.assistance)")
            }
        }
        #endif
        .onChange(of: size.height > size.width, initial: true) { _, rotated in
            portrait = rotated
            if !is3D, scenePrepared { vm.setCameraMode(rotated ? .topDown2DRotated : .topDown2D) }
            showMenu = false
        }
        .onPreferenceChange(AimPointReadableFrame.self) { cameraReadableFrame = $0 }
    }

    private var answerDeviationText: String {
        guard let score = vm.lastScore, score.status == .valid,
              let millimetres = score.millimetres else { return "—" }
        let direction = score.label.replacingOccurrences(of: "偏", with: "")
        if direction == "一致" { return "0.0mm" }
        return direction + String(format: "%.1fmm", abs(millimetres))
    }

    private func answerLegendRow(_ title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(color).frame(width: 18, height: 2)
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
        }
    }

    @ViewBuilder private var sceneFullscreen: some View {
        if scenePrepared {
            AngleSceneView(scene: vm.scene, cameraMode: .constant(cameraMode),
                pocketDisplayOrientation: .init(portrait: portrait),
                interactionMode: canAim ? (is3D ? .cameraControl : .tapsOnly) : .none,
                autoFitsLandscapeTable: !is3D, backgroundColor: is3D ? .black : .clear,
                onPocketTapped: nil,
                onTableTapped: is3D ? { vm.aimToward(worldPoint: $0) } : nil,
                onAimNudged: is3D ? nil : { vm.nudgeAim(byDegrees: $0) },
                onAimDragActiveChanged: { draggingAimTable = $0; vm.setAimTableDragging($0) },
                contentIsAnimating: vm.cameraTransitionBusy,
                fpsReadoutState: fps, twoViewReadableFrameInWindow: is3D ? cameraReadableFrame : nil,
                onCameraObservationBegan: {
                    observingCamera = true
                    if vm.scene.cameraRig?.twoViewMode == .thirdPerson { vm.markObservation() }
                    vm.beginCameraObservation()
                },
                onCameraObservationEnded: { observingCamera = false; vm.endCameraObservation() },
                onTemporaryTopDownDismiss: { vm.endTemporaryTopDown() },
                topDownContentRevision: vm.topDownContentRevision, usesStandardTemporaryTable: is3D)
                .clipped().accessibilityIdentifier("aimPointTraining.scene")
        }
    }

    @ViewBuilder private var observationColumn: some View {
        if let rig = vm.scene.cameraRig {
            ShotPlayerCameraButtons(controlSpacing: 4, rig: rig,
                isEnabled: !showMenu && !editingControlLayout && !vm.finished && !vm.showSettings,
                onWholeTable: { vm.markObservation(); vm.requestSurfaceOverview() }, usesTwoViewControls: rig.usesTwoViewCameraControls,
                temporaryTopDownActive: vm.temporaryTopDownActive,
                onTemporaryTopDownBegan: { vm.markObservation(); vm.beginTemporaryTopDown() },
                onTemporaryTopDownEnded: { vm.endTemporaryTopDown() },
                onSelect: { if $0 == .thirdPerson { vm.markObservation() }; vm.requestPlayerView($0) })
        }
    }

    private var settingsItems: [DailyHUDMenuItem] {
        let items: [DailyHUDMenuItem] = [.init(id: "aimPointTraining.display", title: "显示"),
         .init(id: "menu.tableGrid", title: "台面网格 4×8", selected: pagePreferences.enabled(.grid), action: {
             togglePreference(.grid)
         }),
         .init(id: "menu.aimCloseup", title: "瞄准特写", selected: pagePreferences.enabled(.closeup), action: {
             togglePreference(.closeup)
         }),
         .init(id: "controlLayout.open", title: "操作布局", detail: controlLayoutBusy ? "请先完成当前操作" : nil, disclosure: true,
            disabled: controlLayoutBusy, action: {
                guard !controlLayoutBusy else { return }
                showMenu = false; editingControlLayout = true
            }),
         .init(id: "aimPointTraining.trainingSettings", title: "训练设置", disclosure: true, action: { showMenu = false; vm.showSettings = true }),
         .init(id: "aimPointTraining.finish", title: "结束练习", action: { showMenu = false; vm.finish() }),
         .init(id: "aimPointTraining.coverage", title: vm.run.coverage)]
        return items.filter { $0.id != "controlLayout.open" || preferencePage.usesFreeControlLayout }
    }

    private var trainingInformation: [BTTeachingInformation] {
        if vm.phase == .aiming, vm.showAngleHint, let question = vm.question {
            return [.init(text: "本题瞄准角：\(Int(question.actualAngle.rounded()))°", identifier: "aimPointTraining.angleHintText")]
        }
        return []
    }

    private var questionInformation: some View {
        let metrics = SceneTrainingMetrics(samples: vm.run.firstAnswers, unit: "mm")
        let number = vm.run.firstAnswers.count + (vm.run.submitted ? 0 : 1)
        return VStack(spacing: 0) {
            Text("题目").foregroundStyle(HUDStyle.labelColor)
            Text("\(max(1, number))" + (vm.run.configuration.freePractice ? "" : "/20"))
            Text("正确率").foregroundStyle(HUDStyle.labelColor)
            Text(metrics.rate)
        }.font(.btCaption2).monospacedDigit().foregroundStyle(.white)
            .accessibilityElement(children: .combine).accessibilityIdentifier("aimPointTraining.questionInfo")
    }

    private var answerInformation: some View {
        let metrics = SceneTrainingMetrics(samples: vm.run.firstAnswers, unit: "mm")
        return VStack(spacing: 0) {
            Text("作答").foregroundStyle(HUDStyle.labelColor)
            Text(vm.run.assistance.isEmpty ? "独立" : "辅助")
            Text("均差").foregroundStyle(HUDStyle.labelColor)
            Text(metrics.mean)
        }.font(.btCaption2).monospacedDigit().foregroundStyle(.white)
            .accessibilityElement(children: .combine).accessibilityIdentifier("aimPointTraining.answerInfo")
    }

    private func playingRect(size: CGSize, halfL: Double, halfW: Double, rotated: Bool) -> CGRect {
        guard let scale = CameraRig.landscapeOrthographicScale(viewSize: size,
            halfLength: rotated ? halfW : halfL, halfWidth: rotated ? halfL : halfW) else { return .zero }
        let points = size.height / CGFloat(2 * scale)
        let width = CGFloat(rotated ? AngleSceneCalculator.innerWidth : AngleSceneCalculator.innerLength) * points
        let height = CGFloat(rotated ? AngleSceneCalculator.innerLength : AngleSceneCalculator.innerWidth) * points
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }
}

private struct AimPointReadableFrame: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) { value = nextValue() ?? value }
}

#Preview("2D · Light") {
    NavigationStack { AimPointSceneTrainingView(initialCameraMode: .topDown2D)
        .modelContainer(ModelContainerFactory.makeInMemoryContainer()).environmentObject(SubscriptionManager.shared) }
        .preferredColorScheme(.light)
}
#Preview("3D · Dark") {
    NavigationStack { AimPointSceneTrainingView(initialCameraMode: .perspective3D)
        .modelContainer(ModelContainerFactory.makeInMemoryContainer()).environmentObject(SubscriptionManager.shared) }
        .preferredColorScheme(.dark)
}
