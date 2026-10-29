import Foundation
import Combine
import SceneKit

/// Shared lifecycle surface for fixed-rack practices hosted by the daily table shell.
@MainActor
protocol RackPracticeControlling: AnyObject {
    var canPlaceCue: Bool { get }
    var canStrike: Bool { get }
    var isComplete: Bool { get }
    var targetKey: String? { get }
    var legalKeys: Set<String> { get }
    var paletteKeys: [String] { get }
    var notice: String { get }
    var showFailureChoice: Bool { get set }
    var showSettings: Bool { get set }
    func attach(to host: PositionPlayViewModel)
    func restart()
    func nextRack()
    func undo()
    func finishAttempt(reason: String)
}

extension SnakePracticeController: RackPracticeControlling {
    var legalKeys: Set<String> { targetKey.map { [$0] } ?? [] }
    var paletteKeys: [String] { configuration.keys }
}

enum MultiBallRuling: Equatable {
    case continued(Set<String>), failed(String)
    static func judge(game: MultiBallConfiguration.Game, remaining: Set<String>,
                      first: String?, potted: Set<String>, complete: Bool) -> Self {
        guard complete else { return .failed("本杆未完成") }
        guard !potted.contains(PositionPlayBall.cueKey) else { return .failed("母球落袋") }
        if game == .rotation {
            guard let target = remaining.min(by: { Int($0.dropFirst())! < Int($1.dropFirst())! }), first == target else { return .failed("未先碰最小号球") }
            guard potted == [target] else { return .failed(potted.isEmpty ? "目标球未进" : "请按号码顺序逐颗打进") }
        } else {
            let colored = remaining.subtracting(["_8"])
            let legal = colored.isEmpty ? Set(["_8"]) : colored
            if potted.contains("_8") && !colored.isEmpty { return .failed("黑八提前落袋") }
            guard let first, legal.contains(first) else { return .failed("未先碰己方目标球") }
            guard !potted.isDisjoint(with: legal) else { return .failed("己方目标球未进") }
        }
        return .continued(remaining.subtracting(potted))
    }
    static func judge(game: MultiBallConfiguration.Game, remaining: Set<String>, solved: PositionPlayViewModel.SolvedShot) -> Self {
        func key(_ name: String) -> String {
            if name == ShotInput.cueBallName { return PositionPlayBall.cueKey }
            if !solved.shot.isFree && name == ShotInput.targetBallName { return solved.shot.targetKey }
            return name
        }
        var first: String?
        for event in solved.prediction.events.sorted(by: { $0.time < $1.time }) {
            if case let .ballBall(a, b) = event.kind {
                if key(a) == PositionPlayBall.cueKey { first = key(b); break }
                if key(b) == PositionPlayBall.cueKey { first = key(a); break }
            }
        }
        return judge(game: game, remaining: remaining, first: first,
                     potted: Set(solved.prediction.pocketedBalls.map(key)), complete: solved.prediction.hasFinalTableState)
    }
}

/// Scores the actual settled board. Pocket identity is frozen before the stroke.
enum MultiBallPositionScore {
    struct Result: Equatable, Codable {
        let value: Double
        let reason: String?
        var comfort: TwoBallComfortScore.Result? = nil
        var direction: MiddlePocketDirectionScore.Result? = nil
        var details: String { TwoBallComfortScore.details(comfort, total: value, reason: reason, direction: direction) }
        var text: String {
            String(format: "本杆走位 %.1f 分", value) + (reason.map { " · " + $0 } ?? "")
        }
    }
    static func evaluate(positions: [String: SCNVector3], target: String, pocket: Int,
                         third: String? = nil, failure: String? = nil, surfaceY: Float) -> Result {
        if let failure { return .init(value: 0, reason: failure) }
        guard (0..<6).contains(pocket), let cue = positions[PositionPlayBall.cueKey],
              let ball = positions[target] else { return .init(value: 0, reason: "下一球已不在桌上") }
        guard positions.values.allSatisfy({ $0.x.isFinite && $0.z.isFinite }) else {
            return .init(value: 0, reason: "本杆位置不可评分")
        }
        // X/Z metres, Y up. Use the production direct-shot aim for obstruction;
        // the two-ball score retains its own frozen pocket-distance anchors.
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: ball, pocketIndex: pocket, surfaceY: surfaceY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: ball, pocket: aim, ballRadius: BallPhysics.radius)
        let obstacles = positions.filter { $0.key != target && $0.key != PositionPlayBall.cueKey }.map(\.value)
        if AngleSceneCalculator.isPathBlocked(from: cue, to: ghost, obstacles: obstacles)
            || AngleSceneCalculator.isPathBlocked(from: ball, to: aim, obstacles: obstacles) {
            return .init(value: 0, reason: "下一球线路被遮挡")
        }
        guard let score = TwoBallComfortScore.evaluateFreePosition(cue: (Double(cue.x), Double(cue.z)),
            ball: (Double(ball.x), Double(ball.z)), pocket: pocket) else {
            return .init(value: 0, reason: "下一球无正向直击线路")
        }
        let direction = third.flatMap { positions[$0] }.flatMap { thirdBall in
            MiddlePocketDirectionScore.evaluate(cue: (Double(cue.x), Double(cue.z)),
                ball: (Double(ball.x), Double(ball.z)), third: (Double(thirdBall.x), Double(thirdBall.z)), pocket: pocket)
        }
        return .init(value: score.total * (direction?.coefficient ?? 1), reason: nil, comfort: score, direction: direction)
    }
}

@MainActor
final class MultiBallPracticeController: ObservableObject, RackPracticeControlling {
    @Published private(set) var configuration: MultiBallConfiguration
    @Published private(set) var rack: MultiBallRack?
    @Published private(set) var remaining: Set<String> = []
    @Published private(set) var hasStruck = false
    @Published private(set) var failure: String?
    @Published private(set) var isComplete = false
    @Published var showFailureChoice = false
    @Published var showSettings = false
    @Published var showDailyLimit = false
    @Published var showUpgrade = false
    @Published var showSessionEnd = false
    @Published private(set) var questionNumber = 0
    var is3D: Bool { presentation.current.is3D }
    @Published private(set) var presentation: TrainingPresentation
    @Published private(set) var checkpointError: String?
    private var runID = UUID()
    private var rackID = UUID()
    private var ownerKey = CurrentOwnerContext.shared.ownerKey
    private var checkpointObserver: AnyCancellable?
    private var perspectiveBookmark: CameraRig.TrainingBookmark?
    private var restoring = false
    private var sessionEnded = false
    private let limiter: AngleUsageLimiter
    var premiumProvider: () -> Bool = { false }
    private var pendingNewSession = false
    var newSessionRequiresPro: Bool { !premiumProvider() && (configuration.freePractice || limiter.remainingToday == 0) }
    func requestNewSession() {
        limiter.refreshDay()
        if newSessionRequiresPro { pendingNewSession = true; showUpgrade = true }
        else { showSettings = true }
    }
    func subscriptionDismissed() {
        if pendingNewSession && premiumProvider() { showSettings = true }
        pendingNewSession = false
    }
    private var requiresPremium: Bool { configuration.freePractice }
    private var authorized: Bool { !requiresPremium || premiumProvider() }
    var progressTitle: String { configuration.freePractice ? "" : "第 \(questionNumber)/3 题 · " }

    private weak var host: PositionPlayViewModel?
    private let defaults: UserDefaults
    private let checkpointRoot: URL?
    private var awaiting = false
    struct Plan: Equatable, Codable {
        let current: String
        let next: String
        let pocket: Int
        var third: String? = nil
    }
    struct CurrentSelection: Equatable, Codable {
        var target: String?
        var pocket: Int?
    }
    @Published private(set) var currentSelection = CurrentSelection()
    fileprivate struct Previous: Codable {
        var board: BoardSnapshot? = nil
        var input: PositionPlayViewModel.TrainingInput? = nil
        let remaining: Set<String>
        let hasStruck: Bool
        let plan: Plan?
        let scores: [MultiBallPositionScore.Result]
        let next: String?
        let third: String?
        let lockedPocket: Int?
        let step: PlanThreeRole
        var currentSelection: CurrentSelection? = nil
    }
    @Published private(set) var plan: Plan?
    @Published private(set) var selectingContinuation = false
    @Published private(set) var draftNextKey: String?
    @Published private(set) var thirdKey: String?
    @Published private(set) var planningStep: PlanThreeRole = .ball2
    var editingRole: Int {
        switch planningStep {
        case .ball1, .pocket1: 0
        case .ball2, .pocket2: 1
        case .ball3: 2
        }
    }
    private var editableSteps: [PlanThreeRole] {
        PlanThreeRole.order.filter { step in
            if lockedCurrentPocket != nil && (step == .ball1 || step == .pocket1) { return false }
            if configuration.game == .rotation && step.isBall { return false }
            if remaining.count < 2 && step.rawValue >= PlanThreeRole.ball2.rawValue { return false }
            if remaining.count < 3 && step == .ball3 { return false }
            return true
        }
    }
    var canGoToPreviousStep: Bool {
        guard isPlanning, canStrike, !awaiting, host?.isPlaying != true,
              let index = editableSteps.firstIndex(of: planningStep) else { return false }
        return index > 0
    }
    func goToPreviousStep() {
        guard canGoToPreviousStep, let index = editableSteps.firstIndex(of: planningStep) else { return }
        planningStep = editableSteps[index - 1]
        selectingContinuation = editingRole > 0
        showResult(planningStepPrompt)
    }
    var planningStepPrompt: String {
        switch planningStep {
        case .ball1: "请选择第一颗球"
        case .pocket1: "请选择第一颗球的袋口"
        case .ball2: "请选择第二颗球"
        case .pocket2: "请选择第二颗球的袋口"
        case .ball3: "请选择第三颗球"
        }
    }
    @Published private(set) var lockedCurrentPocket: Int?
    private var roleNodes: [SCNNode] = []
    @Published private(set) var scores: [MultiBallPositionScore.Result] = []
    @Published private(set) var resultNotice: String?
    private var resultTask: Task<Void, Never>?
    private var nextAim: Plan?
    private var previous: Previous?
    private var initialBoard: BoardSnapshot?
    private var completionTask: Task<Void, Never>?
    @Published private var completionVisible = false
    init(configuration: MultiBallConfiguration = .load(), defaults: UserDefaults = .standard,
         is3D: Bool = false, limiter: AngleUsageLimiter = .multiBallTraining) {
        self.configuration = configuration; self.defaults = defaults
        if defaults === UserDefaults.standard { checkpointRoot = nil }
        else {
            let key = "multiBall.testCheckpointID"
            let id = defaults.string(forKey: key) ?? UUID().uuidString
            defaults.set(id, forKey: key)
            checkpointRoot = FileManager.default.temporaryDirectory.appendingPathComponent("multiBall-tests-" + id)
        }
        self.presentation = .init(is3D: is3D); self.limiter = limiter
    }
    var paletteKeys: [String] { rack?.paletteKeys ?? [] }
    private func eligibleKeys(excluding excluded: Set<String>) -> Set<String> {
        guard !isComplete, failure == nil, let rack else { return [] }
        let rest = remaining.intersection(rack.ownKeys).subtracting(excluded)
        if configuration.game == .rotation {
            return rest.min(by: { Int($0.dropFirst())! < Int($1.dropFirst())! }).map { [$0] } ?? []
        }
        let colored = rest.subtracting(["_8"])
        return colored.isEmpty ? rest : colored
    }
    var legalKeys: Set<String> { eligibleKeys(excluding: []) }
    func paletteDescription(_ key: String) -> String? {
        let parts = [isPlanning ? paletteRoleDescription(key) : nil, ownershipDescription(key)].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: "，")
    }
    func ownershipDescription(_ key: String) -> String? {
        guard configuration.game == .chineseEight, let rack else { return nil }
        if rack.opponentKeys.contains(key) { return "对方球，不可选择" }
        guard rack.ownKeys.contains(key) else { return nil }
        return key == "_8" ? "黑八，己方球清完后击打" : "己方球"
    }
    var targetKey: String? { legalKeys.sorted().first }
    var canPlaceCue: Bool { authorized && rack != nil && !hasStruck && failure == nil && !isComplete }
    var isPlanning: Bool { configuration.positionMode == .planned }
    var currentTarget: String? { isPlanning ? currentSelection.target : (host?.selectedTargetKey ?? targetKey) }
    private var hasCurrentSelection: Bool {
        currentTarget != nil && currentSelection.pocket.map { (0..<6).contains($0) } == true
    }
    var needsContinuation: Bool { isPlanning && remaining.count > 1 && !isComplete }
    var continuationKeys: Set<String> {
        guard let currentTarget else { return [] }
        return eligibleKeys(excluding: [currentTarget])
    }
    var thirdKeys: Set<String> {
        guard let currentTarget, let draftNextKey else { return [] }
        return eligibleKeys(excluding: [currentTarget, draftNextKey])
    }
    var hasValidPlan: Bool {
        guard let plan else { return false }
        return plan.current == currentTarget && continuationKeys.contains(plan.next)
            && (remaining.count < 3 || (thirdKey.map { thirdKeys.contains($0) } == true))
    }
    var canStrike: Bool { checkpointError == nil && authorized && rack != nil && failure == nil && !isComplete }
    var averageScore: Double? { scores.isEmpty ? nil : scores.map(\.value).reduce(0, +) / Double(scores.count) }
    var completionSummary: String {
        guard isPlanning, let averageScore else { return "已清台" }
        return String(format: "已清台 · 平均走位 %.1f 分", averageScore)
    }
    /// The action stays available; an incomplete plan never reaches the shot transaction.
    func requestStrike() -> Bool {
        guard canStrike else { return false }
        if isPlanning && !hasCurrentSelection {
            planningStep = currentTarget == nil ? .ball1 : .pocket1
            selectingContinuation = false
            showResult(planningStepPrompt)
            return false
        }
        guard !needsContinuation || hasValidPlan else {
            if draftNextKey == nil { planningStep = .ball2; showResult("请选择第二颗球") }
            else if plan == nil { planningStep = .pocket2; showResult("请选择第二颗球的袋口") }
            else { planningStep = .ball3; showResult("请选择第三颗球") }
            return false
        }
        return true
    }
    func beginPlanning() { selectRole(1) }
    func cancelPlanning() { selectingContinuation = false }
    func selectRole(_ role: Int) {
        guard isPlanning, canStrike, host?.isPlaying != true, role >= 0, role < min(3, remaining.count) else { return }
        if role > 0 && !hasCurrentSelection {
            planningStep = currentTarget == nil ? .ball1 : .pocket1
            selectingContinuation = false
            showResult(planningStepPrompt)
            return
        }
        if role == 0 && lockedCurrentPocket != nil {
            showResult("当前球和袋口沿用上一杆规划，点击重打后调整"); return
        }
        planningStep = role == 0 ? (configuration.game == .rotation ? .pocket1 : .ball1)
            : role == 1 ? (draftNextKey == nil ? .ball2 : .pocket2)
            : draftNextKey == nil ? .ball2 : plan == nil ? .pocket2 : .ball3
        selectingContinuation = editingRole > 0
        if role == 0 && lockedCurrentPocket != nil { showResult("当前球和袋口沿用上一杆规划，点击重打后调整") }
    }
    func roleKey(_ role: Int) -> String? {
        role == 0 ? currentTarget : role == 1 ? draftNextKey : thirdKey
    }
    func selectPaletteBall(_ key: String) {
        guard isPlanning, canStrike, !awaiting, host?.isPlaying != true, remaining.contains(key) else { return }
        if let role = (0..<3).first(where: { roleKey($0) == key }) {
            selectRole(role)
            // A locked role is still locatable, but selecting it cannot edit the plan.
            host?.scene.confirmBallSelection(key: key)
        }
        else if !selectPlanningBall(key) { showResult("请选择当前顺序中可用的己方球") }
    }
    func paletteRoleDescription(_ key: String) -> String? {
        guard let role = (0..<3).first(where: { roleKey($0) == key }) else { return nil }
        return BallRoleStyle(rawValue: role)!.label + (role == 0 && lockedCurrentPocket != nil ? "，已锁定，重打后可调整" : "")
    }
    @discardableResult func selectPlanningBall(_ key: String) -> Bool {
        guard isPlanning, canStrike, host?.isPlaying != true, !awaiting else { return false }
        if configuration.game == .rotation {
            guard remaining.contains(key) else { return false }
            host?.scene.confirmBallSelection(key: key)
            return true
        }
        if editingRole == 0 {
            guard lockedCurrentPocket == nil, legalKeys.contains(key) else { return false }
            let changed = currentTarget != key
            guard host?.selectTarget(key: key) ?? true else { return false }
            currentSelection.target = key
            if changed { currentSelection.pocket = nil; plan = nil; draftNextKey = nil; thirdKey = nil }
            currentTargetChanged(); planningStep = .pocket1; selectingContinuation = false
            showResult(planningStepPrompt)
            return true
        }
        if editingRole == 1 { return selectContinuationBall(key) }
        guard plan != nil, thirdKeys.contains(key) else { return false }
        thirdKey = key
        if let old = plan { plan = Plan(current: old.current, next: old.next, pocket: old.pocket, third: key) }
        planningStep = .ball3; selectingContinuation = true
        resultTask?.cancel(); resultNotice = nil; refreshPresentation()
        host?.scene.confirmBallSelection(key: key)
        return true
    }
    @discardableResult func selectContinuationBall(_ key: String) -> Bool {
        guard isPlanning, hasCurrentSelection, configuration.game == .chineseEight, continuationKeys.contains(key),
              host?.isPlaying != true, !awaiting else { return false }
        if draftNextKey != key { plan = nil; draftNextKey = key; thirdKey = nil }
        planningStep = .pocket2
        selectingContinuation = true
        resultTask?.cancel(); resultNotice = nil; refreshPresentation()
        host?.scene.confirmBallSelection(key: key)
        return true
    }
    @discardableResult func selectContinuationPocket(_ pocket: Int) -> Bool {
        guard isPlanning, hasCurrentSelection, needsContinuation, (0..<6).contains(pocket), let currentTarget,
              let next = draftNextKey, continuationKeys.contains(next), host?.isPlaying != true, !awaiting else { return false }
        plan = Plan(current: currentTarget, next: next, pocket: pocket, third: thirdKey)
        planningStep = configuration.game == .chineseEight && remaining.count >= 3 ? .ball3 : .pocket2
        resultTask?.cancel(); resultNotice = nil; refreshPresentation()
        host?.scene.confirmRolePocketSelection(at: pocket)
        return true
    }
    func selectPlanningPocket(_ pocket: Int) {
        guard isPlanning, canStrike, !awaiting, host?.isPlaying != true, (0..<6).contains(pocket) else { return }
        if editingRole == 0 {
            guard lockedCurrentPocket == nil else { showResult("当前球和袋口沿用上一杆规划，点击重打后调整"); return }
            guard currentTarget != nil else { showResult("请先选择第一颗球"); return }
            host?.selectPocket(at: pocket)
            guard host == nil || host?.selectedPocketIndex == pocket else { return }
            currentSelection.pocket = pocket
            planningStep = needsContinuation ? (draftNextKey == nil ? .ball2 : .pocket2) : .pocket1
            selectingContinuation = needsContinuation; refreshPresentation()
        } else if !selectContinuationPocket(pocket) && needsContinuation {
            showResult("请先选择第二颗球")
        }
    }
    func currentTargetChanged() {
        guard !awaiting else { return }
        if let plan, plan.current != currentTarget { self.plan = nil; draftNextKey = nil; thirdKey = nil }
        if let next = draftNextKey, !continuationKeys.contains(next) { draftNextKey = nil; thirdKey = nil; plan = nil }
        if configuration.game == .rotation {
            draftNextKey = continuationKeys.first; thirdKey = thirdKeys.first
        }
        refreshPresentation()
    }
    func refreshPresentation() {
        roleNodes.forEach { $0.removeFromParentNode() }; roleNodes = []
        guard let host else { return }
        host.practiceUsesPlanningRoles = isPlanning
        host.continuationPocketIndex = plan?.pocket
        guard isPlanning, !awaiting, !host.isPlaying, !isComplete else { return }
        host.refreshPracticePresentation()
        guard configuration.showsPlanningMarkers else { return }
        for role in BallRoleStyle.allCases {
            guard let key = roleKey(role.rawValue), remaining.contains(key),
                  let ball = host.scene.allBallNodes[key], !ball.isHidden else { continue }
            let ring = Self.planningRing(role: role)
            ring.name = "multiBall.planningRing.\(role.rawValue)"
            ring.position = SCNVector3(ball.position.x, host.scene.surfaceY + 0.0007, ball.position.z)
            host.scene.rootNode.addChildNode(ring)
            roleNodes.append(ring)
        }
    }

    /// XZ annulus in metres, independent of the spinning/scaling USDZ ball.
    /// The inner radius is the real unscaled ball radius; third role is dashed.
    static func planningRing(role: BallRoleStyle) -> SCNNode {
        let inner = Float(AngleSceneCalculator.ballRadius), outer = inner + 0.004
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        for i in 0..<96 where role != .upcoming || i % 12 < 7 {
            let a = Float(i) * 2 * .pi / 96, b = Float(i + 1) * 2 * .pi / 96
            let base = Int32(vertices.count)
            vertices += [SCNVector3(inner * cos(a), 0, inner * sin(a)),
                         SCNVector3(outer * cos(a), 0, outer * sin(a)),
                         SCNVector3(inner * cos(b), 0, inner * sin(b)),
                         SCNVector3(outer * cos(b), 0, outer * sin(b))]
            indices += [base, base + 2, base + 1, base + 1, base + 2, base + 3]
        }
        let geometry = SCNGeometry(sources: [.init(vertices: vertices)],
            elements: [.init(indices: indices, primitiveType: .triangles)])
        let material = SCNMaterial()
        material.lightingModel = .constant; material.diffuse.contents = role.uiColor
        material.isDoubleSided = true; material.readsFromDepthBuffer = true; material.writesToDepthBuffer = false
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry); node.castsShadow = false
        return node
    }
    private func showResult(_ text: String) {
        resultTask?.cancel(); resultNotice = text
        resultTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            self?.resultNotice = nil
        }
    }
    /// Called after the host commits the table and rules, before its automatic selection.
    func advancePlannedAim() -> Bool {
        guard let nextAim else { return false }
        self.nextAim = nil
        guard remaining.contains(nextAim.next), failure == nil else {
            lockedCurrentPocket = nil; draftNextKey = nil; thirdKey = nil
            guard failure == nil, !isComplete else { currentTargetChanged(); return false }
            // A legal multi-pot can remove the promised next ball. Start a new explicit
            // choice instead of keeping a potted target or silently inserting a recommendation.
            currentSelection = .init(target: configuration.game == .rotation ? targetKey : nil)
            host?.practiceLockedTarget = nil; host?.practiceLockedPocket = nil
            host?.clearPracticeAimSelection()
            if let target = currentSelection.target { _ = host?.selectTarget(key: target) }
            planningStep = currentTarget == nil ? .ball1 : .pocket1
            selectingContinuation = false
            currentTargetChanged(); showResult(planningStepPrompt)
            return true
        }
        host?.practiceLockedTarget = nil; host?.practiceLockedPocket = nil
        if let host {
            guard host.selectTarget(key: nextAim.next) else { return false }
            host.selectPocket(at: nextAim.pocket)
        }
        lockedCurrentPocket = nextAim.pocket
        currentSelection = .init(target: nextAim.next, pocket: nextAim.pocket)
        host?.practiceLockedTarget = nextAim.next; host?.practiceLockedPocket = nextAim.pocket
        draftNextKey = nextAim.third.flatMap { remaining.contains($0) ? $0 : nil }
        thirdKey = nil
        planningStep = draftNextKey != nil || configuration.game == .rotation ? .pocket2 : .ball2
        selectingContinuation = true
        currentTargetChanged()
        return true
    }
    var notice: String {
        if let checkpointError { return "未能保存练习：" + checkpointError }
        if let failure { return isPlanning && previous?.plan != nil ? "本杆走位 0 分 · " + failure : failure }
        return completionVisible ? completionSummary : ""
    }
    var groupTitle: String {
        guard let rack, configuration.game == .chineseEight else { return "按号码顺序清台" }
        return rack.ownKeys.contains(where: { $0 != "_8" && (Int($0.dropFirst()) ?? 8) < 8 }) ? "己方全色 · 最后打黑八" : "己方花色 · 最后打黑八"
    }
    func attach(to vm: PositionPlayViewModel) {
        host = vm
        vm.legalAimTargets = { [weak self] keys in self?.legalKeys.intersection(keys) ?? [] }
        vm.onShotSettled = nil; vm.onAimModeNotice = nil; vm.onAimSelectionNotice = nil
        vm.practiceCanStartShot = { [weak self] in self?.requestStrike() == true }
        vm.onPracticeReadyForNextShot = { [weak self] in self?.advancePlannedAim() == true }
        vm.onShotWillStart = { [weak self] in self?.prepareShot() }
        vm.onCommittedPracticeShot = { [weak self] in self?.settle($0) }
        let preferred = (defaults === UserDefaults.standard ? TablePreferencesStore.shared : TablePreferencesStore(defaults: defaults)).beginTraining(.multiBall, source3D: is3D)
        presentation.current = .init(is3D: preferred)
        do {
            if let saved = try checkpointStore.latest(where: { $0.configuration.isValid }) { restore(saved) }
            else { start(configuration) }
        } catch { checkpointError = error.localizedDescription; showSettings = false }
        checkpointObserver = vm.objectWillChange.debounce(for: .milliseconds(250), scheduler: RunLoop.main).sink { [weak self] in
            MainActor.assumeIsolated { self?.saveCheckpoint() }
        }
    }
    func start(_ value: MultiBallConfiguration) { loadRack(value, resettingSession: true) }
    private func loadRack(_ value: MultiBallConfiguration, resettingSession: Bool) {
        guard host?.isPlaying != true else { return }
        let premium = premiumProvider()
        limiter.refreshDay()
        if !premium {
            guard !value.freePractice else { showUpgrade = true; return }
            guard limiter.questionsUsedToday < limiter.limit else { showDailyLimit = true; return }
        }
        do {
            let next = try MultiBallBank.shared.draw(configuration: value, excluding: rack?.sourceID)
            let id = UUID(), nextRun = resettingSession ? UUID() : runID
            limiter.isPremium = premium
            guard limiter.reserve(questionID: id) else { showDailyLimit = true; return }
            var views = resettingSession ? TrainingPresentation(is3D: is3D) : presentation
            let formalView = views.current
            views.observe(formalView, questionID: id)
            views.accept(questionID: id, at: Date(), premium: premium)
            let candidate = Checkpoint(runID: nextRun, rackID: id, configuration: value, rack: next,
                initialBoard: next.board, board: next.board, presentation: views,
                questionNumber: resettingSession ? 1 : questionNumber + 1, remaining: next.ownKeys)
            do { try checkpointStore.save(candidate, id: nextRun) }
            catch { limiter.release(questionID: id); throw error }
            runID = nextRun; rackID = id; presentation = views
            if let receipt = views.receipts[id], !limiter.reconcile(receipt) { checkpointError = limiter.quotaError }
            questionNumber = resettingSession ? 1 : questionNumber + 1
            sessionEnded = false; showSessionEnd = false; showDailyLimit = false
            configuration = value; value.save(defaults: defaults, is3D: is3D); rack = next; initialBoard = next.board
            restart(); showSettings = false
        } catch { failure = MultiBallBank.BankError.unavailable.localizedDescription; showFailureChoice = false }
    }
    func restart() {
        guard authorized, host?.isPlaying != true, let rack, let initialBoard else { return }
        completionTask?.cancel(); completionVisible = false
        remaining = rack.ownKeys; hasStruck = false; failure = nil; isComplete = false
        previous = nil; awaiting = false; showFailureChoice = false
        plan = nil; nextAim = nil; cancelPlanning(); scores = []
        draftNextKey = nil; thirdKey = nil; lockedCurrentPocket = nil
        currentSelection = .init(target: configuration.game == .rotation ? targetKey : nil)
        planningStep = configuration.game == .rotation ? .pocket1 : .ball1
        host?.practiceRequiresExplicitAim = isPlanning
        host?.practiceLockedTarget = nil; host?.practiceLockedPocket = nil
        resultTask?.cancel(); resultNotice = nil; host?.continuationPocketIndex = nil
        host?.geometryReference.reset()
        host?.loadBoard(initialBoard)
        if isPlanning, let target = currentSelection.target { _ = host?.selectTarget(key: target) }
        else if !isPlanning { host?.refreshLegalAimSelection() }
        currentTargetChanged(); saveCheckpoint()
        if isPlanning { showResult(planningStepPrompt) }
    }
    func nextRack() {
        guard host?.isPlaying != true else { return }
        if !configuration.freePractice && questionNumber >= 3 {
            sessionEnded = true; showSessionEnd = true; saveCheckpoint(); return
        }
        loadRack(configuration, resettingSession: false)
    }
    func prepareShot() {
        guard requestStrike(), !awaiting else { return }
        host?.prepareGeometryReference(); host?.geometryReference.freeze()
        previous = Previous(board: host?.currentSnapshot(), input: host?.trainingInput, remaining: remaining, hasStruck: hasStruck, plan: plan, scores: scores, next: draftNextKey, third: thirdKey, lockedPocket: lockedCurrentPocket, step: planningStep)
        previous?.currentSelection = currentSelection
        resultTask?.cancel(); resultNotice = nil
        if !hasStruck, let board = host?.currentSnapshot() { initialBoard = board }
        saveCheckpoint()
        hasStruck = true; awaiting = true
        roleNodes.forEach { $0.removeFromParentNode() }; roleNodes = []
    }
    func settle(_ solved: PositionPlayViewModel.SolvedShot) {
        guard awaiting else { return }; awaiting = false
        defer { saveCheckpoint() }
        host?.geometryReference.nextShot()
        let ruling = MultiBallRuling.judge(game: configuration.game, remaining: remaining, solved: solved)
        if isPlanning, let plan = previous?.plan {
            let failureReason: String?
            if case .failed(let reason) = ruling { failureReason = reason } else { failureReason = nil }
            let potted = Set(solved.prediction.pocketedBalls)
            var positions: [String: SCNVector3] = [:]
            for (name, position) in solved.prediction.finalPositions where !potted.contains(name) {
                let key = name == ShotInput.cueBallName ? PositionPlayBall.cueKey
                    : (!solved.shot.isFree && name == ShotInput.targetBallName ? solved.shot.targetKey : name)
                positions[key] = position
            }
            let score = MultiBallPositionScore.evaluate(positions: positions, target: plan.next,
                pocket: plan.pocket, third: plan.third, failure: failureReason, surfaceY: host?.scene.surfaceY ?? 0)
            scores.append(score); showResult(score.text)
            nextAim = plan
        }
        plan = nil; host?.continuationPocketIndex = nil; cancelPlanning()
        host?.practiceLockedTarget = nil; host?.practiceLockedPocket = nil; lockedCurrentPocket = nil
        switch ruling {
        case .continued(let next):
            remaining = next; isComplete = next.isEmpty
            if isComplete {
                completionVisible = true
                completionTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(3))
                    if !Task.isCancelled { self?.completionVisible = false }
                }
            }
        case .failed(let reason): failure = reason; showFailureChoice = true
        }
        if host == nil { _ = advancePlannedAim(); currentTargetChanged() }
    }
    func undo() {
        guard authorized, host?.isPlaying != true, let previous else { return }
        completionTask?.cancel(); completionVisible = false
        remaining = previous.remaining; hasStruck = previous.hasStruck
        failure = nil; isComplete = false; showFailureChoice = false; awaiting = false
        scores = previous.scores; plan = previous.plan; nextAim = nil; cancelPlanning()
        resultTask?.cancel(); resultNotice = nil
        draftNextKey = previous.next; thirdKey = previous.third; lockedCurrentPocket = previous.lockedPocket
        currentSelection = previous.currentSelection ?? .init(target: previous.input?.target ?? previous.plan?.current,
            pocket: previous.lockedPocket ?? previous.input?.pocket)
        host?.practiceLockedTarget = nil; host?.practiceLockedPocket = nil
        self.previous = nil
        if host?.canReplay == true { host?.replayCurrent() }
        else if let board = previous.board {
            host?.loadBoard(board)
            if let input = previous.input { host?.restoreTrainingInput(input) }
        }
        host?.practiceLockedTarget = lockedCurrentPocket == nil ? nil : currentTarget
        host?.practiceLockedPocket = lockedCurrentPocket
        planningStep = previous.step; refreshPresentation()
        host?.geometryReference.restore(); saveCheckpoint()
    }
    func finishAttempt(reason: String) {
        saveCheckpoint()
        host?.geometryReference.reset()
        awaiting = false; completionTask?.cancel(); showFailureChoice = false
        resultTask?.cancel(); resultNotice = nil; cancelPlanning()
        roleNodes.forEach { $0.removeFromParentNode() }; roleNodes = []
    }
    #if DEBUG
    var mergeDiagnostic: String {
        let data: [String: Any] = ["session": runID.uuidString, "question": rackID.uuidString,
            "view": is3D ? "3D" : "2D", "used": limiter.questionsUsedToday,
            "number": questionNumber, "remaining": remaining.sorted(), "scoreCount": scores.count,
            "geometry": host?.geometryReference.diagnostic ?? [:]]
        return (try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
    #endif
    struct Checkpoint: Codable {
        let runID, rackID: UUID
        let configuration: MultiBallConfiguration
        let rack: MultiBallRack
        let initialBoard, board: BoardSnapshot
        var presentation: TrainingPresentation
        let questionNumber: Int
        var remaining: Set<String>
        var hasStruck = false
        var failure: String? = nil
        var complete = false
        var ended = false
        var plan: Plan? = nil
        var nextAim: Plan? = nil
        var scores: [MultiBallPositionScore.Result] = []
        var next, third: String?
        var lockedPocket: Int?
        var step: PlanThreeRole = .ball2
        var currentSelection: CurrentSelection? = nil
        var target: String?
        var pocket = -1
        var velocity = ShotTuning.defaultVelocity
        var spinX = 0.0, spinY = 0.0
        var geometry: GeometricReferenceTool.Snapshot?
        var input: PositionPlayViewModel.TrainingInput?
        fileprivate var previous: Previous?
        var bookmark: CameraRig.TrainingBookmark?
    }
    private var checkpointStore: TrainingCheckpointStore<Checkpoint> {
        .init(project: .multiBall, owner: ownerKey, root: checkpointRoot)
    }
    static func hasCheckpoint() throws -> Bool {
        try TrainingCheckpointStore<Checkpoint>(project: .multiBall, owner: CurrentOwnerContext.shared.ownerKey)
            .latest(where: { $0.configuration.isValid }) != nil
    }
    var canUndo: Bool { previous != nil && host?.isPlaying != true && host?.isComputing != true }
    func saveCheckpoint() {
        guard !restoring, !awaiting, let host, !host.isPlaying, !host.isComputing,
              ownerKey == CurrentOwnerContext.shared.ownerKey, let rack, let initialBoard else { return }
        var value = Checkpoint(runID: runID, rackID: rackID, configuration: configuration, rack: rack,
            initialBoard: initialBoard, board: host.currentSnapshot(), presentation: presentation,
            questionNumber: questionNumber, remaining: remaining)
        value.hasStruck = hasStruck; value.failure = failure; value.complete = isComplete
        value.ended = sessionEnded
        value.nextAim = nextAim
        value.plan = plan; value.scores = scores; value.next = draftNextKey; value.third = thirdKey
        value.lockedPocket = lockedCurrentPocket; value.step = planningStep
        value.currentSelection = currentSelection
        value.target = host.selectedTargetKey; value.pocket = host.selectedPocketIndex
        value.velocity = host.velocity; value.spinX = host.spinX; value.spinY = host.spinY
        value.input = host.trainingInput
        value.geometry = host.geometryReference.snapshot; value.previous = previous
        if host.cameraMode == .perspective3D, !host.temporaryTopDownActive {
            perspectiveBookmark = host.scene.cameraRig?.trainingBookmark()
        }
        value.bookmark = perspectiveBookmark
        do {
            try checkpointStore.save(value, id: runID)
            checkpointError = nil
            for receipt in presentation.receipts.values where !limiter.reconcile(receipt) { checkpointError = limiter.quotaError }
        }
        catch { checkpointError = error.localizedDescription }
    }
    private func restore(_ value: Checkpoint) {
        restoring = true; defer { restoring = false }
        perspectiveBookmark = value.bookmark
        runID = value.runID; rackID = value.rackID; configuration = value.configuration
        rack = value.rack; initialBoard = value.initialBoard; presentation = value.presentation
        questionNumber = value.questionNumber; remaining = value.remaining; hasStruck = value.hasStruck
        sessionEnded = value.ended; showSessionEnd = value.ended
        failure = value.failure; isComplete = value.complete; showFailureChoice = value.failure != nil
        nextAim = value.nextAim
        plan = value.plan; scores = value.scores; draftNextKey = value.next; thirdKey = value.third
        lockedCurrentPocket = value.lockedPocket; planningStep = value.step; previous = value.previous
        // Keep existing deliberate plans/played racks; an untouched legacy opening starts unselected.
        currentSelection = value.currentSelection ?? ((value.hasStruck || value.plan != nil)
            ? .init(target: value.target, pocket: value.pocket >= 0 ? value.pocket : nil)
            : .init(target: configuration.game == .rotation ? targetKey : nil))
        host?.practiceRequiresExplicitAim = isPlanning
        host?.loadBoard(value.board)
        if let key = isPlanning ? currentSelection.target : value.target { _ = host?.selectTarget(key: key) }
        if let pocket = isPlanning ? currentSelection.pocket : (value.pocket >= 0 ? value.pocket : nil) { host?.selectPocket(at: pocket) }
        if value.currentSelection != nil || !isPlanning || hasCurrentSelection,
           let input = value.input { host?.restoreTrainingInput(input) }
        if isPlanning && !hasCurrentSelection { planningStep = currentTarget == nil ? .ball1 : .pocket1 }
        host?.velocity = value.velocity; host?.spinX = value.spinX; host?.spinY = value.spinY
        host?.practiceLockedTarget = value.lockedPocket == nil ? nil : value.target
        host?.practiceLockedPocket = value.lockedPocket
        if let host {
            _ = ShotPlayCamera.setMode(is3D ? .perspective3D : .topDown2D, on: host)
            if let bookmark = value.bookmark, let cue = host.scene.cueBallNode?.position, let aim = host.currentPlayerAim {
                host.scene.cameraRig?.restoreTrainingBookmark(bookmark, cue: cue, aim: aim)
            }
            if let geometry = value.geometry { host.geometryReference.restore(geometry) }
        }
        for receipt in presentation.receipts.values where !limiter.reconcile(receipt) { checkpointError = limiter.quotaError }
        if nextAim != nil { _ = advancePlannedAim() }
        currentTargetChanged()
    }
    @discardableResult func switchTrainingView(to is3D: Bool) -> Bool {
        guard let host, !host.isPlaying, !host.isComputing, !host.cameraTransitionBusy,
              !host.temporaryTopDownActive else { return false }
        host.geometryReference.endDrag()
        let old = presentation
        presentation.current = .init(is3D: is3D)
        // Rack quota is accepted at activation; observations remain a per-rack union.
        presentation.observed[rackID, default: []].insert(.init(is3D: is3D))
        saveCheckpoint()
        guard checkpointError == nil else { presentation = old; return false }
        return true
    }
    func observeTemporaryTopDown() {
        presentation.observed[rackID, default: []].insert(.twoD); saveCheckpoint()
    }
    func ownerChanged() {
        checkpointObserver?.cancel(); host?.cancelPowerRelease()
        rack = nil; initialBoard = nil; previous = nil; remaining = []; plan = nil; scores = []
        ownerKey = CurrentOwnerContext.shared.ownerKey; host?.clearTable(); showSettings = true
        sessionEnded = false; showSessionEnd = false
        runID = UUID(); rackID = UUID(); presentation = .init(is3D: is3D)
    }

}
