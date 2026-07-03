import Foundation
import SceneKit
import SwiftUI

// MARK: - Roles

/// 「打一走二想三」计划的五个角色，按引导填充顺序排列。
enum PlanThreeRole: Int, CaseIterable {
    case ball1, pocket1, ball2, pocket2, ball3

    var isBall: Bool { self == .ball1 || self == .ball2 || self == .ball3 }
    var isPocket: Bool { self == .pocket1 || self == .pocket2 }

    static let order: [PlanThreeRole] = [.ball1, .pocket1, .ball2, .pocket2, .ball3]
}

// MARK: - Sector (pure geometry)

/// 二号球的「白球停球扇形」——纯几何引导区（不反解、不跑物理）。
/// `inner`/`outer` 沿切角 5°→20° 取样的内外弧端点（场景 XZ，y 已抬到台面上方）。
struct PlanThreeSector {
    let inner: [SCNVector3]
    let outer: [SCNVector3]
    var isValid: Bool { inner.count >= 2 && inner.count == outer.count }
}

enum PlanThreeSectorSolver {
    /// 「正角度」区间（度）：用户拍板 5–20°。
    static let cutMinDeg: Float = 5
    static let cutMaxDeg: Float = 20
    /// 停球点距假想球的最近/最远距离（米）。
    static let sMin: Float = 0.11
    static let sMax: Float = 0.55
    /// 离库余量（米，含球半径外的净空）。
    static let railMargin: Float = 0.10
    static let samples = 14

    private static func rotate(_ x: Float, _ z: Float, byDeg deg: Float) -> (Float, Float) {
        let r = deg * .pi / 180
        return (x * cosf(r) - z * sinf(r), x * sinf(r) + z * cosf(r))
    }

    /// 生成扇形：`ball3 == nil` → 两侧完整扇形；否则收缩到朝三号那一侧。
    /// `aim2` = 二号球→二号袋的有效进球点。
    static func compute(ball2 t2: SCNVector3, aim2: SCNVector3,
                        ball3: SCNVector3?, surfaceY: Float) -> [PlanThreeSector] {
        let ux0 = aim2.x - t2.x, uz0 = aim2.z - t2.z
        let ulen = sqrtf(ux0 * ux0 + uz0 * uz0)
        guard ulen > 1e-5 else { return [] }
        let ux = ux0 / ulen, uz = uz0 / ulen

        let r = AngleSceneCalculator.ballRadius
        let gx = t2.x - 2 * r * ux, gz = t2.z - 2 * r * uz   // 假想球

        guard let t3 = ball3 else {
            // 无三号：两侧各一片。
            return [+1, -1].compactMap { buildSector(sign: $0, ux: ux, uz: uz, gx: gx, gz: gz, surfaceY: surfaceY) }
        }

        // 有三号：按「分离切线·朝三号」点积取大侧（不脑算手性）。
        var wx = t3.x - t2.x, wz = t3.z - t2.z
        let wlen = sqrtf(wx * wx + wz * wz)
        guard wlen > 1e-5 else { return [] }
        wx /= wlen; wz /= wlen
        func score(sign: Float) -> Float {
            let mid = (cutMinDeg + cutMaxDeg) / 2
            let (dx, dz) = rotate(ux, uz, byDeg: sign * mid)
            let dot = dx * ux + dz * uz
            let px = dx - dot * ux, pz = dz - dot * uz
            let plen = sqrtf(px * px + pz * pz)
            guard plen > 1e-6 else { return -2 }
            return (px / plen) * wx + (pz / plen) * wz
        }
        let sign: Float = score(sign: 1) >= score(sign: -1) ? 1 : -1
        return [buildSector(sign: sign, ux: ux, uz: uz, gx: gx, gz: gz, surfaceY: surfaceY)].compactMap { $0 }
    }

    /// 构建单侧扇形（沿切角 5°→20° 取样，离库裁剪）。
    private static func buildSector(sign: Float, ux: Float, uz: Float,
                                    gx: Float, gz: Float, surfaceY: Float) -> PlanThreeSector? {
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let m = railMargin + AngleSceneCalculator.ballRadius
        let xmin = -halfL + m, xmax = halfL - m
        let zmin = -halfW + m, zmax = halfW - m

        var inner: [SCNVector3] = []
        var outer: [SCNVector3] = []
        let y = surfaceY + 0.003

        for i in 0...samples {
            let frac = Float(i) / Float(samples)
            let deg = cutMinDeg + (cutMaxDeg - cutMinDeg) * frac
            let (dx, dz) = rotate(ux, uz, byDeg: sign * deg)   // 入射方向 d
            let dirx = -dx, dirz = -dz                          // 假想球 → 停点

            var sMaxRay = sMax
            if dirx > 1e-6 { sMaxRay = min(sMaxRay, (xmax - gx) / dirx) }
            else if dirx < -1e-6 { sMaxRay = min(sMaxRay, (xmin - gx) / dirx) }
            if dirz > 1e-6 { sMaxRay = min(sMaxRay, (zmax - gz) / dirz) }
            else if dirz < -1e-6 { sMaxRay = min(sMaxRay, (zmin - gz) / dirz) }
            guard sMaxRay > sMin + 0.02 else { continue }

            let ix = gx + dirx * sMin, iz = gz + dirz * sMin
            guard ix >= xmin, ix <= xmax, iz >= zmin, iz <= zmax else { continue }
            let ox = gx + dirx * sMaxRay, oz = gz + dirz * sMaxRay

            inner.append(SCNVector3(ix, y, iz))
            outer.append(SCNVector3(ox, y, oz))
        }
        guard inner.count >= 2 else { return nil }
        return PlanThreeSector(inner: inner, outer: outer)
    }
}

// MARK: - ViewModel

/// 「打一走二想三」走位规划卡（增强版走位训练）。
///
/// 整合「思路训练器」反解能力：摆球 → 选 ①一号球+①袋 / ②二号球+②袋 / ③三号球（右侧角色轨）；
/// ② + ②袋(+③) 自动画**白球停球扇形（引导）**；再用工具画真正的**落区/落点/过点**约束，
/// 由 `PositionPlaySolver` 反解出「打一」的塞与力度，可「下一解」翻档、击球。
/// 打进①后白球停下、窗口前滑（老②→新①、老②袋→新①袋、老③→新②）续打；角色随时可改派。
@MainActor
final class PlanThreeViewModel: ObservableObject {

    // MARK: - Tools (复用思路训练器约束工具)

    enum Tool: Equatable { case none, region, restPoint, passPoint }
    enum RegionShape: String, CaseIterable { case rect = "矩形", circle = "圆" }
    enum Draft {
        case region(SolveRegion)
        case restPoint(CanvasPoint)
        case passPoint(CanvasPoint)
    }

    // MARK: - Scene

    let scene = AngleTrainingScene()
    private var pocketMarkers: [SCNNode] = []
    private var trajectoryNodes: [SCNNode] = []
    private var constraintNodes: [SCNNode] = []
    private var selectionNodes: [SCNNode] = []   // 角色环 + 扇形 + 几何预览

    // MARK: - Published board / roles

    @Published private(set) var onTableKeys: [String] = []
    @Published private(set) var ball1Key: String?
    @Published private(set) var ball2Key: String?
    @Published private(set) var ball3Key: String?
    @Published private(set) var pocket1Index: Int = -1
    @Published private(set) var pocket2Index: Int = -1
    @Published private(set) var armedRole: PlanThreeRole? = .ball1

    // MARK: - Published tool state

    @Published var activeTool: Tool = .none { didSet { if oldValue != activeTool { statusText = hintForState() } } }
    @Published var regionShape: RegionShape = .rect
    @Published private(set) var hasConstraint = false
    var draft: Draft?
    var passVMin: Double = 0.3
    var pointTolerance: Double = 0.02

    // MARK: - Published solve options

    @Published var allowSideSpin: Bool = true { didSet { if oldValue != allowSideSpin { invalidateSolutions() } } }
    @Published var basicPositionOnly: Bool = false { didSet { if oldValue != basicPositionOnly { invalidateSolutions() } } }

    // MARK: - Published shot params (当前解只读指示)

    @Published private(set) var velocity: Double = 3.0
    @Published private(set) var spinX: Double = 0
    @Published private(set) var spinY: Double = 0

    // MARK: - Published solve state

    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2DRotated
    @Published private(set) var isPlaying = false
    @Published private(set) var isComputing = false
    @Published private(set) var solutions: [PositionPlaySolution] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var statusText = "点右侧①，再点桌上球设为一号球"

    var currentSolution: PositionPlaySolution? {
        solutions.indices.contains(currentIndex) ? solutions[currentIndex] : nil
    }
    var hasSolutions: Bool { !solutions.isEmpty }
    var canStrike: Bool {
        !isPlaying && !isComputing && (currentSolution?.prediction.feasible ?? false)
            && (currentSolution?.prediction.duration ?? 0) > 0.05
    }

    // MARK: - Internals

    var lastAimDirection: SCNVector3?
    let solveQueue = DispatchQueue(label: "com.qiuji.planthree-solve", qos: .userInitiated)
    var solveGeneration = 0
    var surfaceY: Float { scene.surfaceY }

    static let color1 = UIColor(red: 0.36, green: 0.92, blue: 0.55, alpha: 1)
    static let color2 = UIColor(red: 0.20, green: 0.85, blue: 0.95, alpha: 1)
    static let color3 = UIColor(red: 1.0, green: 0.78, blue: 0.28, alpha: 1)

    // MARK: - Setup

    func setupScene() {
        scene.setupScene()
        scene.setupVisualizationNodes()
        pocketMarkers = scene.addPocketMarkers()
        scene.hideAllBalls()
        scene.hideCueStick()
        scene.cameraRig?.topDownPanOffset = .zero
        applyDefaultLayout()
    }

    private func applyDefaultLayout() {
        place(key: PositionPlayBall.cueKey, normalized: CanvasPoint(x: 0.24, y: 0.30))
        place(key: "_1", normalized: CanvasPoint(x: 0.52, y: 0.16))
        place(key: "_2", normalized: CanvasPoint(x: 0.70, y: 0.34))
        place(key: "_3", normalized: CanvasPoint(x: 0.86, y: 0.16))
        place(key: "_4", normalized: CanvasPoint(x: 0.46, y: 0.40))
        refreshOnTableKeys()
        armedRole = .ball1
        refreshOverlays()
    }

    /// 导入外部球形（球形生成器 / 拍照建球形交付的散开快照）。清空角色与约束，回到「选①」起点。
    func loadBoard(_ snapshot: BoardSnapshot) {
        guard !isPlaying, !snapshot.onTable.isEmpty else { return }
        scene.hideAllBalls()
        clearConstraint()
        for (key, pt) in snapshot.onTable { place(key: key, normalized: pt) }
        refreshOnTableKeys()
        ball1Key = nil; ball2Key = nil; ball3Key = nil
        pocket1Index = -1; pocket2Index = -1
        armedRole = .ball1
        activeTool = .none
        statusText = hint(for: .ball1)
        refreshOverlays()
        invalidateSolutions()
    }

    // MARK: - Board queries

    func currentSnapshot() -> BoardSnapshot {
        var dict: [String: CanvasPoint] = [:]
        for key in onTableKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let n = AngleSceneCalculator.sceneToNormalized(position: node.position)
            dict[key] = CanvasPoint(x: Double(n.x), y: Double(n.y))
        }
        return BoardSnapshot(onTable: dict)
    }

    var draggableBalls: [SCNNode] { onTableKeys.compactMap { scene.allBallNodes[$0] } }
    var selectableBalls: [SCNNode] {
        onTableKeys.filter { !PositionPlayBall.isCue($0) }.compactMap { scene.allBallNodes[$0] }
    }

    // MARK: - Palette place / remove / drag

    private func refreshOnTableKeys() {
        onTableKeys = PositionPlayBall.allKeys.filter { !(scene.allBallNodes[$0]?.isHidden ?? true) }
    }

    func placeFromPalette(_ key: String) {
        guard !isPlaying else { return }
        place(key: key, normalized: freeNormalizedSlot())
        refreshOnTableKeys()
        invalidateSolutions()
    }

    func placeFromPalette(_ key: String, atWorld world: SCNVector3) {
        guard !isPlaying, let node = scene.allBallNodes[key] else { return }
        let clamped = clampMultiBall(world, movingNode: node)
        let n = AngleSceneCalculator.sceneToNormalized(position: clamped)
        place(key: key, normalized: CanvasPoint(x: Double(n.x), y: Double(n.y)))
        refreshOnTableKeys()
        invalidateSolutions()
    }

    func removeFromTable(_ key: String) {
        guard !isPlaying else { return }
        scene.hideBall(key: key)
        clearRolesReferencing(key)
        refreshOnTableKeys()
        invalidateSolutions()
    }

    private func place(key: String, normalized: CanvasPoint) {
        let scenePos = AngleSceneCalculator.normalizedToScene(
            point: CGPoint(x: normalized.x, y: normalized.y), surfaceY: surfaceY)
        scene.showBall(key: key, scenePosition: scenePos)
    }

    private func freeNormalizedSlot() -> CanvasPoint {
        let candidates: [CanvasPoint] = stride(from: 0.15, through: 0.85, by: 0.1).flatMap { x in
            stride(from: 0.12, through: 0.40, by: 0.08).map { y in CanvasPoint(x: x, y: y) }
        }
        for c in candidates {
            let scenePos = AngleSceneCalculator.normalizedToScene(
                point: CGPoint(x: c.x, y: c.y), surfaceY: surfaceY)
            if !overlapsExisting(scenePos, excluding: nil) { return c }
        }
        return CanvasPoint(x: 0.5, y: 0.25)
    }

    private func overlapsExisting(_ pos: SCNVector3, excluding key: String?) -> Bool {
        for k in onTableKeys where k != key {
            guard let node = scene.allBallNodes[k], !node.isHidden else { continue }
            if AngleSceneCalculator.horizontalDistance(pos, node.position) < 2.2 * AngleSceneCalculator.ballRadius {
                return true
            }
        }
        return false
    }

    func dragBegan(node: SCNNode) {
        guard !isPlaying else { return }
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.15, duration: 0.1), forKey: "dragPulse")
    }

    func dragMoved(node: SCNNode, worldPosition: SCNVector3) {
        guard !isPlaying else { return }
        node.position = clampMultiBall(worldPosition, movingNode: node)
        refreshOverlays()
    }

    func dragEnded(node: SCNNode) {
        guard !isPlaying else { return }
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.0 / 1.15, duration: 0.15))
        invalidateSolutions()
    }

    private func clampMultiBall(_ pos: SCNVector3, movingNode: SCNNode) -> SCNVector3 {
        var p = AngleSceneCalculator.clampAwayFromPockets(pos, surfaceY: surfaceY)
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let r = AngleSceneCalculator.ballRadius
        let minDist: Float = 2 * r + 0.001
        for _ in 0..<6 {
            var moved = false
            for k in onTableKeys {
                guard let other = scene.allBallNodes[k], other !== movingNode, !other.isHidden else { continue }
                let dx = p.x - other.position.x, dz = p.z - other.position.z
                let dist = sqrtf(dx * dx + dz * dz)
                if dist < minDist {
                    if dist > 0.0001 {
                        p.x = other.position.x + (dx / dist) * minDist
                        p.z = other.position.z + (dz / dist) * minDist
                    } else { p.x += minDist }
                    moved = true
                }
            }
            p.x = max(-halfL + r, min(halfL - r, p.x))
            p.z = max(-halfW + r, min(halfW - r, p.z))
            if !moved { break }
        }
        return SCNVector3(p.x, surfaceY + r, p.z)
    }

}

// MARK: - Role selection + constraint tools + solve

extension PlanThreeViewModel {

    /// 装填某角色（点芯片）。自动切回「摆球」态以便点桌面赋值。
    func armRole(_ role: PlanThreeRole) {
        guard !isPlaying else { return }
        activeTool = .none
        armedRole = role
        statusText = hint(for: role)
    }

    /// 点桌上球（场景回调，仅 .none 工具态生效）：赋给当前装填的球角色。
    func selectBall(node: SCNNode) {
        guard !isPlaying, let key = scene.ballKey(for: node), !PositionPlayBall.isCue(key) else { return }
        guard let role = armedRole, role.isBall else {
            statusText = "请先点右侧「球」角色芯片"
            return
        }
        assignBall(key, to: role)
    }

    /// 点袋口（场景回调）：赋给当前装填的袋角色。
    func selectPocket(at index: Int) {
        guard !isPlaying else { return }
        guard let role = armedRole, role.isPocket else {
            statusText = "请先点右侧「袋」角色芯片"
            return
        }
        if role == .pocket1 { pocket1Index = index } else { pocket2Index = index }
        advanceAndArm()
    }

    private func assignBall(_ key: String, to role: PlanThreeRole) {
        if ball1Key == key, role != .ball1 { ball1Key = nil }
        if ball2Key == key, role != .ball2 { ball2Key = nil }
        if ball3Key == key, role != .ball3 { ball3Key = nil }
        switch role {
        case .ball1: ball1Key = key
        case .ball2: ball2Key = key
        case .ball3: ball3Key = key
        default: return
        }
        advanceAndArm()
    }

    private func advanceAndArm() {
        armedRole = nextEmptyRole()
        if let role = armedRole { statusText = hint(for: role) }
        else { statusText = "齐了 · 用上方工具画落区/落点/过点，再「求解」" }
        invalidateSolutions()
    }

    private func nextEmptyRole() -> PlanThreeRole? { PlanThreeRole.order.first { !isFilled($0) } }

    func isFilled(_ role: PlanThreeRole) -> Bool {
        switch role {
        case .ball1: return ball1Key != nil
        case .pocket1: return pocket1Index >= 0
        case .ball2: return ball2Key != nil
        case .pocket2: return pocket2Index >= 0
        case .ball3: return ball3Key != nil
        }
    }

    func ballKey(for role: PlanThreeRole) -> String? {
        switch role {
        case .ball1: return ball1Key
        case .ball2: return ball2Key
        case .ball3: return ball3Key
        default: return nil
        }
    }

    func pocketIndex(for role: PlanThreeRole) -> Int {
        role == .pocket1 ? pocket1Index : (role == .pocket2 ? pocket2Index : -1)
    }

    func clearPlan() {
        guard !isPlaying else { return }
        ball1Key = nil; ball2Key = nil; ball3Key = nil
        pocket1Index = -1; pocket2Index = -1
        armedRole = .ball1
        activeTool = .none
        statusText = hint(for: .ball1)
        invalidateSolutions()
    }

    private func clearRolesReferencing(_ key: String) {
        if ball1Key == key { ball1Key = nil }
        if ball2Key == key { ball2Key = nil }
        if ball3Key == key { ball3Key = nil }
        if armedRole == nil { armedRole = nextEmptyRole() }
    }

    /// 点击球库中已在桌的球 → 桌上对应球放大脉冲提示位置。
    func pulseTableBall(_ key: String) {
        guard !isPlaying, let node = scene.allBallNodes[key], !node.isHidden else { return }
        node.removeAction(forKey: "libraryPulse")
        let up = SCNAction.scale(to: 1.7, duration: 0.18); up.timingMode = .easeOut
        let down = SCNAction.scale(to: 1.0, duration: 0.24); down.timingMode = .easeIn
        node.runAction(SCNAction.sequence([up, down]), forKey: "libraryPulse")
    }

    // MARK: Constraint drawing

    func toolDrag(startNormalized start: CanvasPoint, currentNormalized cur: CanvasPoint, ended: Bool) {
        guard !isPlaying else { return }
        switch activeTool {
        case .none: return
        case .passPoint: draft = .passPoint(cur)
        case .restPoint: draft = .restPoint(cur)
        case .region:
            switch regionShape {
            case .rect:
                let cx = (start.x + cur.x) / 2, cy = (start.y + cur.y) / 2
                let hw = max(0.01, abs(cur.x - start.x) / 2)
                let hh = max(0.005, abs(cur.y - start.y) / 2)
                draft = .region(.rect(center: CanvasPoint(x: cx, y: cy), halfWidth: hw, halfHeight: hh))
            case .circle:
                let dx = cur.x - start.x, dy = cur.y - start.y
                let r = max(0.01, (dx * dx + dy * dy).squareRoot())
                draft = .region(.circle(center: start, radius: r))
            }
        }
        hasConstraint = draft != nil
        renderConstraint()
        if ended, currentConstraint() != nil { statusText = "约束就绪，点「求解」反解打一杆法" }
    }

    func clearConstraint() {
        draft = nil
        hasConstraint = false
        clearConstraintNodes()
        invalidateSolutions()
        statusText = hintForState()
    }

    func currentConstraint() -> SolveConstraint? {
        switch draft {
        case .region(let r): return .restRegion(r)
        case .restPoint(let p): return .restRegion(.point(center: p, tolerance: pointTolerance))
        case .passPoint(let p): return .passThrough(point: p, vMin: passVMin)
        case nil: return nil
        }
    }

    // MARK: Solve

    func invalidateSolutions() {
        solveGeneration += 1
        isComputing = false
        solutions = []
        currentIndex = 0
        clearTrajectory()
        scene.hideCueStick()
        velocity = 3.0; spinX = 0; spinY = 0
        refreshOverlays()
        if currentConstraint() != nil { statusText = "约束就绪，点「求解」反解打一杆法" }
        else { statusText = hintForState() }
    }

    func solve() {
        guard !isPlaying else { return }
        guard let targetKey = ball1Key, pocket1Index >= 0,
              let pocketId = ShotIntent.pocketId(for: pocket1Index),
              let constraint = currentConstraint() else {
            statusText = hintForState()
            return
        }
        let before = currentSnapshot()
        let y = surfaceY
        let params = searchParams(for: constraint)
        solveGeneration += 1
        let gen = solveGeneration
        isComputing = true
        statusText = "求解中…"
        clearTrajectory()
        scene.hideCueStick()

        solveQueue.async { [weak self] in
            let result = PositionPlaySolver.solve(
                before: before, targetKey: targetKey, pocket: pocketId,
                constraint: constraint, surfaceY: y, params: params)
            DispatchQueue.main.async {
                guard let self, self.solveGeneration == gen, !self.isPlaying else { return }
                self.isComputing = false
                self.solutions = result
                self.currentIndex = 0
                if result.isEmpty {
                    self.statusText = "未找到解（试着放大区域或换①目标袋）"
                    self.velocity = 3.0; self.spinX = 0; self.spinY = 0
                } else {
                    self.showSolution(at: 0)
                }
            }
        }
    }

    private func searchParams(for constraint: SolveConstraint) -> PositionPlaySolver.SearchParams {
        var params: PositionPlaySolver.SearchParams
        switch constraint {
        case .restRegion: params = .standard
        case .passThrough: params = .passThrough
        }
        if !allowSideSpin { params.spinXValues = [0] }
        params.maxCushions = basicPositionOnly ? 1 : nil
        return params
    }

    func nextSolution() {
        guard !solutions.isEmpty else { return }
        currentIndex = (currentIndex + 1) % solutions.count
        showSolution(at: currentIndex)
    }

    private func showSolution(at index: Int) {
        guard solutions.indices.contains(index) else { return }
        let sol = solutions[index]
        velocity = sol.shot.velocity
        spinX = sol.shot.spinX
        spinY = sol.shot.spinY
        statusText = solutionStatus(sol)
        drawTrajectory(sol.prediction, shot: sol.shot)
        updateCueStickAiming(sol.prediction)
        renderConstraint()
        refreshOverlays()
    }

    private func solutionStatus(_ sol: PositionPlaySolution) -> String {
        let prefix = solutions.count > 1 ? "解 \(currentIndex + 1)/\(solutions.count) · " : ""
        let advanced = sol.beyondCushionBudget ? "进阶 · " : ""
        if !sol.satisfiesConstraint { return prefix + advanced + "最接近解 · " + sol.summary }
        return prefix + advanced + sol.summary
    }

    // MARK: Hints

    func hintForState() -> String {
        if scene.allBallNodes[PositionPlayBall.cueKey]?.isHidden ?? true { return "请把母球摆上桌" }
        if let role = nextEmptyRole() { return hint(for: role) }
        if currentConstraint() == nil { return "用上方工具画落区/落点/过点，再「求解」" }
        return "约束就绪，点「求解」反解打一杆法"
    }

    func hint(for role: PlanThreeRole) -> String {
        switch role {
        case .ball1: return "点桌上的球，设为①一号球"
        case .pocket1: return "点袋口，设为①一号球目标袋"
        case .ball2: return "点桌上的球，设为②二号球"
        case .pocket2: return "点袋口，设为②二号球目标袋"
        case .ball3: return "点桌上的球，设为③三号球（决定扇形朝向）"
        }
    }
}

// MARK: - Rendering (role rings + sector + ① preview + constraint + trajectory)

extension PlanThreeViewModel {

    func refreshOverlays() {
        scene.clearResultNodes(nodes: &selectionNodes)
        guard !isPlaying else { return }
        let showingSolution = currentSolution != nil && !isComputing

        drawRoleRing(ball1Key, color: Self.color1)
        drawRoleRing(ball2Key, color: Self.color2)
        drawRoleRing(ball3Key, color: Self.color3)
        drawPocketRing(pocket1Index, color: Self.color1)
        drawPocketRing(pocket2Index, color: Self.color2)
        drawSector()

        if showingSolution { return }   // ghost/aim by trajectory layer
        drawBall1Preview()
    }

    private func drawRoleRing(_ key: String?, color: UIColor) {
        guard let key, let n = scene.allBallNodes[key], !n.isHidden else { return }
        strokeCircle(center: n.position, radius: AngleSceneCalculator.ballRadius * 1.75,
                     color: color.withAlphaComponent(0.95), into: &selectionNodes)
    }

    private func drawPocketRing(_ index: Int, color: UIColor) {
        guard index >= 0 else { return }
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        guard pockets.indices.contains(index) else { return }
        strokeCircle(center: pockets[index], radius: AngleSceneCalculator.ballRadius * 2.2,
                     color: color.withAlphaComponent(0.9), into: &selectionNodes)
    }

    /// ② 停球扇形引导（无③ → 两侧；有③ → 收缩到朝③那侧）。
    private func drawSector() {
        guard let b2 = ball2Key, let n2 = scene.allBallNodes[b2], !n2.isHidden, pocket2Index >= 0 else { return }
        let aim2 = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: n2.position, pocketIndex: pocket2Index, surfaceY: surfaceY)
        var b3pos: SCNVector3?
        if let b3 = ball3Key, let n3 = scene.allBallNodes[b3], !n3.isHidden { b3pos = n3.position }
        let sectors = PlanThreeSectorSolver.compute(
            ball2: n2.position, aim2: aim2, ball3: b3pos, surfaceY: surfaceY)
        for s in sectors { addSector(s, color: Self.color2) }
    }

    private func addSector(_ s: PlanThreeSector, color: UIColor) {
        guard s.isValid else { return }
        if let fill = makeSectorFill(s, color: color.withAlphaComponent(0.16)) {
            scene.rootNode.addChildNode(fill)
            selectionNodes.append(fill)
        }
        let edge = color.withAlphaComponent(0.9)
        let n = s.inner.count
        for i in 0..<(n - 1) {
            selectionNodes.append(scene.addLine(from: s.outer[i], to: s.outer[i + 1], color: edge, radius: 0.0024))
            selectionNodes.append(scene.addLine(from: s.inner[i], to: s.inner[i + 1],
                                                color: color.withAlphaComponent(0.5), radius: 0.0016))
        }
        selectionNodes.append(scene.addLine(from: s.inner[0], to: s.outer[0], color: edge, radius: 0.0024))
        selectionNodes.append(scene.addLine(from: s.inner[n - 1], to: s.outer[n - 1], color: edge, radius: 0.0024))
    }

    private func makeSectorFill(_ s: PlanThreeSector, color: UIColor) -> SCNNode? {
        var verts: [SCNVector3] = []
        verts.reserveCapacity(s.inner.count * 2)
        for i in 0..<s.inner.count { verts.append(s.inner[i]); verts.append(s.outer[i]) }
        guard verts.count >= 3 else { return nil }
        let src = SCNGeometrySource(vertices: verts)
        let idx = (0..<verts.count).map { UInt16($0) }
        let elem = SCNGeometryElement(indices: idx, primitiveType: .triangleStrip)
        let geo = SCNGeometry(sources: [src], elements: [elem])
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .constant
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        m.readsFromDepthBuffer = false
        geo.materials = [m]
        let node = SCNNode(geometry: geo)
        node.renderingOrder = -10
        return node
    }

    private func drawBall1Preview() {
        guard let tkey = ball1Key, let tn = scene.allBallNodes[tkey], !tn.isHidden,
              pocket1Index >= 0,
              let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden else {
            scene.ghostBallNode?.isHidden = true
            return
        }
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        guard pockets.indices.contains(pocket1Index) else { scene.ghostBallNode?.isHidden = true; return }
        let aim = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: tn.position, pocketIndex: pocket1Index, surfaceY: surfaceY)
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: tn.position, pocket: aim, ballRadius: AngleSceneCalculator.ballRadius)
        selectionNodes.append(scene.addLine(from: cue.position, to: ghost,
                                            color: UIColor.white.withAlphaComponent(0.45),
                                            radius: TrajectoryStyle.aimRadius))
        selectionNodes.append(scene.addLine(from: tn.position, to: pockets[pocket1Index],
                                            color: TrajectoryStyle.potColor(for: tkey, alpha: 0.55),
                                            radius: TrajectoryStyle.aimRadius))
        if let g = scene.ghostBallNode {
            g.position = SCNVector3(ghost.x, surfaceY + AngleSceneCalculator.ballRadius, ghost.z)
            g.isHidden = false
        }
    }

    // MARK: Trajectory

    func drawTrajectory(_ p: ShotPrediction, shot: PlannedShot) {
        clearTrajectory()
        guard p.feasible else { scene.hideCueStick(); return }
        addPolyline(p.cuePath, color: TrajectoryStyle.aimColor, radius: TrajectoryStyle.aimRadius)
        var objPath = p.objectPath
        if p.objectPocketed, let pocketIndex = ShotIntent.pocketIndex(for: shot.pocket) {
            objPath = PositionPlayShotSolver.extendPathToPocketRim(objPath, pocketIndex: pocketIndex, surfaceY: surfaceY)
        }
        addPolyline(objPath, color: TrajectoryStyle.potColor(for: shot.targetKey), radius: TrajectoryStyle.potRadius)
        for (key, pts) in p.extraBallPaths {
            addPolyline(pts, color: TrajectoryStyle.potColor(for: key, alpha: 0.85), radius: TrajectoryStyle.potRadius)
        }
        if let ghost = scene.ghostBallNode {
            ghost.position = SCNVector3(p.ghost.x, surfaceY + AngleSceneCalculator.ballRadius, p.ghost.z)
            ghost.isHidden = false
        }
        if UserPreferences.shared.showSeparationAngle {
            scene.addSeparationAngleLine(for: p, into: &trajectoryNodes)
        }
    }

    private func addPolyline(_ pts: [SCNVector3], color: UIColor, radius: Float) {
        guard pts.count >= 2 else { return }
        for i in 0..<(pts.count - 1) {
            trajectoryNodes.append(scene.addLine(from: pts[i], to: pts[i + 1], color: color, radius: radius))
        }
    }

    func clearTrajectory() {
        scene.clearResultNodes(nodes: &trajectoryNodes)
        scene.hideAllVisualization()
    }

    // MARK: Constraint rendering (青/琥珀，与角色色区分)

    func renderConstraint() {
        clearConstraintNodes()
        let color = UIColor(red: 0.2, green: 0.85, blue: 0.95, alpha: 0.95)
        let y = surfaceY + 0.002
        switch draft {
        case .region(let region):
            switch region {
            case let .circle(center, radius):
                let c = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: center.x, y: center.y), surfaceY: y)
                strokeCircle(center: c, radius: Float(radius) * SolveRegion.sceneScale, color: color, into: &constraintNodes)
            case let .rect(center, hw, hh):
                let c = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: center.x, y: center.y), surfaceY: y)
                strokeRect(center: c, halfX: Float(hw) * SolveRegion.sceneScale,
                           halfZ: Float(hh) * SolveRegion.sceneScale, color: color, into: &constraintNodes)
            case let .point(center, tol):
                let c = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: center.x, y: center.y), surfaceY: y)
                strokeCircle(center: c, radius: Float(tol) * SolveRegion.sceneScale, color: color, into: &constraintNodes)
            }
        case .passPoint(let pt):
            let c = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: pt.x, y: pt.y), surfaceY: y)
            strokeCircle(center: c, radius: AngleSceneCalculator.ballRadius, color: color, into: &constraintNodes)
            let r = AngleSceneCalculator.ballRadius * 1.6
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x - r, c.y, c.z),
                                                  to: SCNVector3(c.x + r, c.y, c.z), color: color, radius: 0.0022))
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x, c.y, c.z - r),
                                                  to: SCNVector3(c.x, c.y, c.z + r), color: color, radius: 0.0022))
        case .restPoint(let pt):
            let amber = UIColor(red: 1.0, green: 0.78, blue: 0.28, alpha: 0.95)
            let c = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: pt.x, y: pt.y), surfaceY: y)
            strokeCircle(center: c, radius: Float(pointTolerance) * SolveRegion.sceneScale, color: amber, into: &constraintNodes)
            let r = AngleSceneCalculator.ballRadius * 1.4
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x - r, c.y, c.z),
                                                  to: SCNVector3(c.x + r, c.y, c.z), color: amber, radius: 0.0024))
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x, c.y, c.z - r),
                                                  to: SCNVector3(c.x, c.y, c.z + r), color: amber, radius: 0.0024))
        case nil:
            break
        }
    }

    private func strokeCircle(center: SCNVector3, radius: Float, color: UIColor, into nodes: inout [SCNNode]) {
        let segments = 36
        var prev: SCNVector3?
        for i in 0...segments {
            let a = Float(i) / Float(segments) * 2 * .pi
            let p = SCNVector3(center.x + radius * cosf(a), center.y, center.z + radius * sinf(a))
            if let pr = prev { nodes.append(scene.addLine(from: pr, to: p, color: color, radius: 0.0022)) }
            prev = p
        }
    }

    private func strokeRect(center: SCNVector3, halfX: Float, halfZ: Float, color: UIColor, into nodes: inout [SCNNode]) {
        let c = center
        let corners = [
            SCNVector3(c.x - halfX, c.y, c.z - halfZ), SCNVector3(c.x + halfX, c.y, c.z - halfZ),
            SCNVector3(c.x + halfX, c.y, c.z + halfZ), SCNVector3(c.x - halfX, c.y, c.z + halfZ)
        ]
        for i in 0..<4 {
            nodes.append(scene.addLine(from: corners[i], to: corners[(i + 1) % 4], color: color, radius: 0.0022))
        }
    }

    private func clearConstraintNodes() { scene.clearResultNodes(nodes: &constraintNodes) }
}

// MARK: - Cue stick + strike + rolling window

extension PlanThreeViewModel {

    func updateCueStickAiming(_ p: ShotPrediction) {
        guard !isPlaying, p.feasible,
              let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden,
              let aim = aimDirection(path: p.cuePath, from: cue.position) else {
            scene.hideCueStick(); lastAimDirection = nil; return
        }
        lastAimDirection = aim
        scene.updateCueStick(cueBallPosition: strikePosition(cue: cue.position), aimDirection: aim)
    }

    private func strikePosition(cue: SCNVector3) -> SCNVector3 {
        guard let aim = lastAimDirection else { return cue }
        return CueStroke.strikePosition(cue: cue, aim: aim, spinX: spinX)
    }

    private func aimDirection(path: [SCNVector3], from cue: SCNVector3) -> SCNVector3? {
        for pt in path {
            let dx = pt.x - cue.x, dz = pt.z - cue.z
            let d = sqrtf(dx * dx + dz * dz)
            if d > 0.02 { return SCNVector3(dx / d, 0, dz / d) }
        }
        return nil
    }

    func play() {
        guard canStrike, let sol = currentSolution,
              let recorder = sol.prediction.recorder,
              let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
              let aim = lastAimDirection ?? aimDirection(path: sol.prediction.cuePath, from: cueNode.position)
        else { return }
        isPlaying = true
        statusText = "运杆…"
        clearConstraintNodes()
        let strikePos = strikePosition(cue: cueNode.position)
        scene.runCueStroke(strikePosition: strikePos, aim: aim, velocity: Float(sol.shot.velocity)) { [weak self] in
            self?.launchBalls(sol: sol, recorder: recorder)
        }
    }

    private func launchBalls(sol: PositionPlaySolution, recorder: TrajectoryRecorder) {
        statusText = "击球中…"
        clearTrajectory()
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let settle = playback.perceptibleSettleTime()
        var cueAction: SCNAction?
        for key in onTableKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let name = PositionPlayShotSolver.predName(boardKey: key, shot: sol.shot)
            let action = playback.action(for: node, ballName: name, speed: 1.0,
                                         removeOnPocket: false, maxSimTime: settle)
            if key == PositionPlayBall.cueKey { cueAction = action }
            else if let action { node.runAction(action) }
        }
        let tail: TimeInterval = sol.prediction.pocketedBalls.isEmpty ? 0 : TrajectoryPlayback.pocketSettleDuration + 0.1
        if let cueAction, let cueNode = scene.allBallNodes[PositionPlayBall.cueKey] {
            cueNode.runAction(cueAction) { [weak self] in
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(tail * 1_000_000_000))
                    self?.finishStrike(sol: sol)
                }
            }
            // 音效在全部球体动画挂载后起播：避免音频引擎冷启动阻塞主线程时，跟杆先于球推进。
            ShotAudioScheduler.shared.play(prediction: sol.prediction)
        } else {
            finishStrike(sol: sol)
        }
    }

    /// 回放结束：球停在终点。进袋球离场；若①进袋则**窗口前滑**（老②→新①、老②袋→新①袋、老③→新②），
    /// 否则保留原计划。解/约束随旧布局失效。
    private func finishStrike(sol: PositionPlaySolution) {
        ShotAudioScheduler.shared.cancel()
        for key in onTableKeys { scene.allBallNodes[key]?.removeAllActions() }
        let potted = Set(sol.prediction.pocketedBalls.map { boardKey(forPredName: $0, shot: sol.shot) })
        for key in potted { scene.hideBall(key: key) }
        if sol.prediction.cuePocketed { scene.hideBall(key: PositionPlayBall.cueKey) }

        isPlaying = false
        refreshOnTableKeys()

        let ball1Potted = sol.prediction.objectPocketed
        if ball1Potted { rollWindow() } else { dropMissingRoles() }

        solveGeneration += 1
        solutions = []
        currentIndex = 0
        draft = nil
        hasConstraint = false
        activeTool = .none
        velocity = 3.0; spinX = 0; spinY = 0
        clearTrajectory()
        clearConstraintNodes()
        scene.hideCueStick()
        refreshOverlays()

        let cueGone = scene.allBallNodes[PositionPlayBall.cueKey]?.isHidden ?? true
        if cueGone {
            statusText = "母球进袋（scratch）· 重新摆母球或「恢复默认」"
        } else if ball1Potted {
            statusText = armedRole.map { "①进袋 · 窗口前滑 · " + hint(for: $0) }
                ?? "①进袋 · 窗口前滑 · 继续规划下一杆"
        } else {
            statusText = "①未进袋 · 计划保留，可重画约束再求解"
        }
    }

    /// 窗口前滑：老②→新①、老②袋→新①袋、老③→新②；新②袋/新③清空待选。
    private func rollWindow() {
        let onTable = Set(onTableKeys)
        let nb1 = ball2Key.flatMap { onTable.contains($0) ? $0 : nil }
        let nb2 = ball3Key.flatMap { onTable.contains($0) ? $0 : nil }
        ball1Key = nb1
        pocket1Index = nb1 != nil ? pocket2Index : -1
        ball2Key = nb2
        pocket2Index = -1
        ball3Key = nil
        armedRole = PlanThreeRole.order.first { !isFilled($0) }
    }

    /// ①未进袋：仅清掉已离场的角色引用。
    private func dropMissingRoles() {
        let onTable = Set(onTableKeys)
        if let k = ball1Key, !onTable.contains(k) { ball1Key = nil }
        if let k = ball2Key, !onTable.contains(k) { ball2Key = nil }
        if let k = ball3Key, !onTable.contains(k) { ball3Key = nil }
        if armedRole == nil { armedRole = PlanThreeRole.order.first { !isFilled($0) } }
    }

    private func boardKey(forPredName name: String, shot: PlannedShot) -> String {
        if name == ShotInput.cueBallName { return PositionPlayBall.cueKey }
        if name == ShotInput.targetBallName { return shot.targetKey }
        return name
    }

    // MARK: Reset

    func clearTable() {
        guard !isPlaying else { return }
        scene.hideAllBalls()
        ball1Key = nil; ball2Key = nil; ball3Key = nil
        pocket1Index = -1; pocket2Index = -1
        armedRole = .ball1
        refreshOnTableKeys()
        clearConstraint()
        invalidateSolutions()
    }

    func resetAll() {
        guard !isPlaying else { return }
        scene.hideAllBalls()
        clearConstraint()
        applyDefaultLayout()
        invalidateSolutions()
    }
}
