import Foundation
import SceneKit
import SwiftUI
import Combine

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
        let sign = preferredSide(ux: ux, uz: uz, ball2: t2, ball3: t3)
        return [buildSector(sign: sign, ux: ux, uz: uz, gx: gx, gz: gz, surfaceY: surfaceY)].compactMap { $0 }
    }

    /// 朝三号那一侧的符号（+1/−1）：把中值切角方向对 u 的横向分量投影到「t2→t3」方向，取大者。
    /// `compute`（视觉多段）与 `defaultRegion`（求解 SDF）共用，确保视觉扇形与求解扇形同侧（单一真源）。
    static func preferredSide(ux: Float, uz: Float, ball2 t2: SCNVector3, ball3 t3: SCNVector3) -> Float {
        var wx = t3.x - t2.x, wz = t3.z - t2.z
        let wlen = sqrtf(wx * wx + wz * wz)
        guard wlen > 1e-5 else { return 1 }
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
        return score(sign: 1) >= score(sign: -1) ? 1 : -1
    }

    /// 求解用**默认落区**（Q15.1）：把视觉扇形的**真实几何**打包为 `SolveRegion.sector`。
    ///
    /// 与视觉 `compute` 同源同参（同顶点=②假想球、同半径带 [sMin, sMax]、同角域 5°→20°、同朝③侧选择）。
    /// - 顶点 `apex` = ②号球假想球位 `t2 − 2R·u`（u = ②→②有效进球点单位向量）。
    /// - 停点方向 bearing = `bearing(u) + π + sign·θ`，θ∈[5°,20°]（母球从假想球外侧退出的方向）。
    /// - 无③号 → 两侧两个角区间；有③号 → 朝③单侧一个角区间。
    /// 半径带用**米**（sMin/sMax 物理停球距离，不做归一化）；视觉 `compute` 额外按库边裁剪多段折线，
    /// 求解 SDF 用未裁剪的解析环形扇区（台面外的点物理上母球到不了，故不影响可行解，且更忠实几何）。
    static func defaultRegion(ball2 t2: SCNVector3, aim2: SCNVector3,
                              ball3: SCNVector3?, surfaceY: Float) -> SolveRegion? {
        let ux0 = aim2.x - t2.x, uz0 = aim2.z - t2.z
        let ulen = sqrtf(ux0 * ux0 + uz0 * uz0)
        guard ulen > 1e-5 else { return nil }
        let ux = ux0 / ulen, uz = uz0 / ulen
        let r = AngleSceneCalculator.ballRadius
        let apexScene = SCNVector3(t2.x - 2 * r * ux, surfaceY + r, t2.z - 2 * r * uz)
        let apexN = AngleSceneCalculator.sceneToNormalized(position: apexScene)
        let base = atan2f(uz, ux) + .pi   // 停点基方向 = u 反向的 bearing
        let cmin = cutMinDeg * .pi / 180, cmax = cutMaxDeg * .pi / 180

        func interval(sign: Float) -> SolveRegion.SectorAngleInterval {
            let a = base + sign * cmin, b = base + sign * cmax
            return SolveRegion.SectorAngleInterval(lo: Double(min(a, b)), hi: Double(max(a, b)))
        }
        var intervals: [SolveRegion.SectorAngleInterval] = []
        if let t3 = ball3 {
            intervals = [interval(sign: preferredSide(ux: ux, uz: uz, ball2: t2, ball3: t3))]
        } else {
            intervals = [interval(sign: 1), interval(sign: -1)]
        }
        return .sector(apex: CanvasPoint(x: Double(apexN.x), y: Double(apexN.y)),
                       radiusMin: Double(sMin), radiusMax: Double(sMax), intervals: intervals)
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
/// 整合「思路训练器」反解能力：摆球 → 选 ①一号球+①袋 / ②二号球+②袋 / ③三号球（底部角色横排）；
/// ② + ②袋(+③) 自动画**白球停球扇形（引导）**；再用工具画真正的**落区/落点/过点**约束，
/// 由 `PositionPlaySolver` 反解出「打一」的塞与力度，可「下一解」翻档、击球。
/// 打进①后白球停下、窗口前滑（老②→新①、老②袋→新①袋、老③→新②）续打；角色随时可改派。
@MainActor
final class PlanThreeViewModel: ObservableObject {

    // MARK: - Tools (复用思路训练器约束工具)

    enum Tool: Equatable { case none, region, restPoint, passPoint }
    enum RegionShape: String, CaseIterable { case rect = "矩形", circle = "圆" }
    /// 约束草稿（归一化系）。共享定义见 `SolveConstraintDraft`（G17，跨反解页统一口径）。
    typealias Draft = SolveConstraintDraft

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

    // MARK: - Published solve options (K12: UI removed; snapshot-compat only; solve always full)

    /// Retained for `SolveShotSnapshot` round-trip. Solve ignores this flag (always full capability).
    @Published var allowSideSpin: Bool = true { didSet { if oldValue != allowSideSpin { invalidateSolutions() } } }
    /// Retained for `SolveShotSnapshot` round-trip. Solve ignores this flag (always full capability).
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
    @Published private(set) var statusText = "点下方①，再点桌上球设为一号球"

    // MARK: - Adjustment draft (K13 / X6 — same contract as SiluTrainerViewModel; X5 transplant source)
    //
    // `solutions[]` immutable after solve; `adjustmentDraft` holds forward-recomputed display/strike
    // candidate. `currentSolution` = draft ?? catalog. adjust → Drafted (further tweak on draft);
    // nextSolution / showSolution / invalidate / solve → Clean (draft discarded).

    private var adjustmentDraft: PositionPlaySolution?

    var currentSolution: PositionPlaySolution? {
        guard solutions.indices.contains(currentIndex) else { return nil }
        return adjustmentDraft ?? solutions[currentIndex]
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

    // MARK: - Last shot（条 21.3 + G17：上一杆完整恢复 / 回放）

    /// 打三页「上一杆」完整上下文 = 共享求解快照 + 本页选择模型（①②③ 角色指派）。
    /// 上一杆 = 回到击打前**完整状态**（球形 + ①②③角色 + 约束 + 解 + 打点/力度/瞄准，免重解）。
    /// （internal 而非 private：供单测直接验证「快照→恢复」逐字段一致，见 `PositionPlayUndoSnapshotTests`。）
    struct UndoContext {
        var snapshot: SolveShotSnapshot
        var ball1Key: String?
        var ball2Key: String?
        var ball3Key: String?
        var pocket1Index: Int
        var pocket2Index: Int
        var armedRole: PlanThreeRole?
    }
    private var lastShotContext: UndoContext?
    @Published private(set) var canUndoShot = false
    @Published private(set) var canPlayback = false

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

    // MARK: - Break flow state（T-P18-47，方法见下方 extension）

    /// 开球模式 runner。非 nil = 开球模式：角色计划/约束/求解/摆球交互全部挂起。
    @Published private(set) var breakRunner: BreakFlowRunner?
    var isBreakMode: Bool { breakRunner != nil }
    /// 进开球模式前的桌面（取消开球时恢复）。
    var boardBeforeBreak: BoardSnapshot?
    var breakChangeForwarder: AnyCancellable?
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
            statusText = "请先点下方「球」角色芯片"
            return
        }
        assignBall(key, to: role)
    }

    /// 点袋口（场景回调）：赋给当前装填的袋角色。
    func selectPocket(at index: Int) {
        guard !isPlaying else { return }
        guard let role = armedRole, role.isPocket else {
            statusText = "请先点下方「袋」角色芯片"
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
        statusText = hintForState()
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
        TableBallPulse.pulse(node)
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

    /// 台面在桌目标球数（不含母球）。
    var objectBallCount: Int {
        onTableKeys.filter { !PositionPlayBall.isCue($0) }.count
    }

    /// ②号球+②号袋就绪时的**默认落区扇形**（Q15.1，真实几何）。nil = ② 未就绪。
    var sectorRegion: SolveRegion? {
        guard let b2 = ball2Key, let n2 = scene.allBallNodes[b2], !n2.isHidden, pocket2Index >= 0 else {
            return nil
        }
        let aim2 = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: n2.position, pocketIndex: pocket2Index, surfaceY: surfaceY)
        var b3pos: SCNVector3?
        if let b3 = ball3Key, let n3 = scene.allBallNodes[b3], !n3.isHidden { b3pos = n3.position }
        return PlanThreeSectorSolver.defaultRegion(
            ball2: n2.position, aim2: aim2, ball3: b3pos, surfaceY: surfaceY)
    }

    /// <3 球终局降级（Q15.2）：台面仅剩 ① 一颗目标球时，无②可走位 ⇒ 只求「打进①」，
    /// 落区放开为全台面（任意停点均合格），母球停哪都行。
    var canPotOnly: Bool {
        ball1Key != nil && pocket1Index >= 0 && objectBallCount <= 1
    }

    /// 全台面落区（pot-only 用）：中心 = 台面中心、覆盖整个 playfield。
    private var potOnlyRegion: SolveRegion {
        .rect(center: CanvasPoint(x: 0.5, y: 0.25), halfWidth: 0.5, halfHeight: 0.25)
    }

    /// 当前是否可求解（工具/角色/球数任一路径就绪）。驱动「求解」按钮启用。
    var canSolve: Bool { currentConstraint() != nil }

    /// 扇形当前是否作为默认落区生效（未画自选约束且② 就绪）。用于视觉：默认=高亮、被自选降级=灰。
    var sectorIsDefaultRegion: Bool { draft == nil && sectorRegion != nil }

    func currentConstraint() -> SolveConstraint? {
        switch draft {
        case .region(let r): return .restRegion(r)
        case .restPoint(let p): return .restRegion(.point(center: p, tolerance: pointTolerance))
        case .passPoint(let p): return .passThrough(point: p, vMin: passVMin)
        case nil:
            // 未画自选约束：② 就绪 ⇒ 扇形默认落区；否则 <3 球 pot-only 兜底。
            if let sector = sectorRegion { return .restRegion(sector) }
            if canPotOnly { return .restRegion(potOnlyRegion) }
            return nil
        }
    }

    // MARK: Solve

    func invalidateSolutions() {
        solveGeneration += 1
        isComputing = false
        solutions = []
        currentIndex = 0
        adjustmentDraft = nil
        clearTrajectory()
        scene.hideCueStick()
        velocity = 3.0; spinX = 0; spinY = 0
        refreshOverlays()
        statusText = hintForState()
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
                self.adjustmentDraft = nil
                if result.isEmpty {
                    self.statusText = "未找到解（试着放大区域或换①目标袋）"
                    self.velocity = 3.0; self.spinX = 0; self.spinY = 0
                } else {
                    self.showSolution(at: 0)
                }
            }
        }
    }

    /// K12: always full capability (`allowSideSpin` / `basicPositionOnly` ignored; snapshot-compat only).
    private func searchParams(for constraint: SolveConstraint) -> PositionPlaySolver.SearchParams {
        switch constraint {
        case .restRegion: return .standard
        case .passThrough: return .passThrough
        }
    }

    /// 三档轨迹标注切换后重绘当前解（`BTTrajectoryDetailChip` 触发，条 12.5）。
    func redrawTrajectory() {
        guard !isPlaying, let sol = currentSolution else { return }
        drawTrajectory(sol.prediction, shot: sol.shot)
    }

    func nextSolution() {
        guard !solutions.isEmpty else { return }
        adjustmentDraft = nil
        currentIndex = (currentIndex + 1) % solutions.count
        showSolution(at: currentIndex)
    }

    private func showSolution(at index: Int) {
        guard solutions.indices.contains(index) else { return }
        adjustmentDraft = nil
        presentDisplayedSolution(solutions[index])
    }

    private func presentDisplayedSolution(_ sol: PositionPlaySolution) {
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
        if objectBallCount == 0 { return "清台完成 🎉 · 用「恢复默认」重开一局" }
        if ball1Key == nil { return hint(for: .ball1) }
        if pocket1Index < 0 { return hint(for: .pocket1) }
        // ①+①袋 就绪：优先扇形/自选约束，其次 <3 球 pot-only。
        if draft != nil { return "约束就绪，点「求解」反解打一杆法" }
        if sectorRegion != nil {
            return "扇形为默认落区 · 点「求解」（或用工具画落区/落点/过点自定义）"
        }
        if canPotOnly { return "台面仅剩此球 · 点「求解」直接打进" }
        // ≥2 球但②未就绪：引导设②走位，或自画约束。
        if let role = nextEmptyRole() { return hint(for: role) }
        return "用上方工具画落区/落点/过点，再「求解」"
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
        SceneStroke.strokeCircle(center: n.position, radius: AngleSceneCalculator.ballRadius * 1.75,
                                 color: color.withAlphaComponent(0.95), scene: scene, into: &selectionNodes)
    }

    private func drawPocketRing(_ index: Int, color: UIColor) {
        guard index >= 0 else { return }
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        guard pockets.indices.contains(index) else { return }
        SceneStroke.strokeCircle(center: pockets[index], radius: AngleSceneCalculator.ballRadius * 2.2,
                                 color: color.withAlphaComponent(0.9), scene: scene, into: &selectionNodes)
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
        // Q15.1：无自选约束 ⇒ 扇形为**默认落区**（高亮 color2）；用户自画约束 ⇒ 降级为参考（灰）。
        let dimmed = draft != nil
        let color = dimmed ? UIColor(white: 0.62, alpha: 1) : Self.color2
        for s in sectors { addSector(s, color: color, dimmed: dimmed) }
    }

    private func addSector(_ s: PlanThreeSector, color: UIColor, dimmed: Bool) {
        guard s.isValid else { return }
        let fillAlpha: CGFloat = dimmed ? 0.06 : 0.16
        if let fill = makeSectorFill(s, color: color.withAlphaComponent(fillAlpha)) {
            scene.rootNode.addChildNode(fill)
            selectionNodes.append(fill)
        }
        let edge = color.withAlphaComponent(dimmed ? 0.45 : 0.9)
        let innerColor = color.withAlphaComponent(dimmed ? 0.28 : 0.5)
        let n = s.inner.count
        for i in 0..<(n - 1) {
            selectionNodes.append(scene.addLine(from: s.outer[i], to: s.outer[i + 1], color: edge, radius: 0.0024))
            selectionNodes.append(scene.addLine(from: s.inner[i], to: s.inner[i + 1],
                                                color: innerColor, radius: 0.0016))
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
            scene.hideContactDot()
            return
        }
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        guard pockets.indices.contains(pocket1Index) else {
            scene.ghostBallNode?.isHidden = true
            scene.hideContactDot()
            return
        }
        let aim = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: tn.position, pocketIndex: pocket1Index, surfaceY: surfaceY)
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: tn.position, pocket: aim, ballRadius: AngleSceneCalculator.ballRadius)
        selectionNodes.append(scene.addLine(from: cue.position, to: ghost,
                                            color: UIColor.white.withAlphaComponent(0.45),
                                            radius: TrajectoryStyle.aimRadius))
        // 进球线预览：本色虚线（线语言 v2）。
        scene.addDashedPolyline([tn.position, pockets[pocket1Index]],
                                color: TrajectoryStyle.potColor(for: tkey, alpha: 0.55),
                                radius: TrajectoryStyle.aimRadius, into: &selectionNodes)
        if let g = scene.ghostBallNode {
            g.position = SCNVector3(ghost.x, surfaceY + AngleSceneCalculator.ballRadius, ghost.z)
            g.isHidden = false
            // 重叠标注 L0（T-P18-42）：几何预览同样补齐接触点绿点。
            scene.updateContactDot(ghostCenter: g.position, targetCenter: tn.position)
        }
    }

    // MARK: Trajectory

    func drawTrajectory(_ p: ShotPrediction, shot: PlannedShot) {
        clearTrajectory()
        guard p.feasible else { scene.hideCueStick(); return }
        // 全量口径（C3 / D2）：与 Composer/Silu 同 options。
        TrajectoryRenderer.draw(
            prediction: p,
            options: .positionPlay,
            context: .init(
                prediction: p,
                targetKey: shot.targetKey,
                pocket: shot.pocket,
                surfaceY: surfaceY,
                showGhost: true
            ),
            scene: scene,
            into: &trajectoryNodes
        )
    }

    func clearTrajectory() {
        scene.clearResultNodes(nodes: &trajectoryNodes)
        scene.hideAllVisualization()
    }

    // MARK: Constraint rendering (青/琥珀，与角色色区分)

    func renderConstraint() {
        clearConstraintNodes()
        let color = BTScenePalette.constraintCyan
        let y = surfaceY + 0.002
        switch draft {
        case .region(let region):
            switch region {
            case let .circle(center, radius):
                let c = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: center.x, y: center.y), surfaceY: y)
                SceneStroke.strokeCircle(center: c, radius: Float(radius) * SolveRegion.sceneScale,
                                         color: color, scene: scene, into: &constraintNodes)
            case let .rect(center, hw, hh):
                let c = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: center.x, y: center.y), surfaceY: y)
                SceneStroke.strokeRect(center: c, halfX: Float(hw) * SolveRegion.sceneScale,
                                       halfZ: Float(hh) * SolveRegion.sceneScale, color: color,
                                       scene: scene, into: &constraintNodes)
            case let .point(center, tol):
                let c = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: center.x, y: center.y), surfaceY: y)
                SceneStroke.strokeCircle(center: c, radius: Float(tol) * SolveRegion.sceneScale,
                                         color: color, scene: scene, into: &constraintNodes)
            case .sector:
                // 扇形默认落区由 `renderSelection`/`addSector` 画，不进 draft；此处仅穷尽分支。
                break
            }
        case .passPoint(let pt):
            let c = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: pt.x, y: pt.y), surfaceY: y)
            SceneStroke.strokeCircle(center: c, radius: AngleSceneCalculator.ballRadius,
                                     color: color, scene: scene, into: &constraintNodes)
            let r = AngleSceneCalculator.ballRadius * 1.6
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x - r, c.y, c.z),
                                                  to: SCNVector3(c.x + r, c.y, c.z), color: color,
                                                  radius: SceneStroke.lineRadius))
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x, c.y, c.z - r),
                                                  to: SCNVector3(c.x, c.y, c.z + r), color: color,
                                                  radius: SceneStroke.lineRadius))
        case .restPoint(let pt):
            let amber = UIColor(red: 1.0, green: 0.78, blue: 0.28, alpha: 0.95)
            let c = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: pt.x, y: pt.y), surfaceY: y)
            SceneStroke.strokeCircle(center: c, radius: Float(pointTolerance) * SolveRegion.sceneScale,
                                     color: amber, scene: scene, into: &constraintNodes)
            let r = AngleSceneCalculator.ballRadius * 1.4
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x - r, c.y, c.z),
                                                  to: SCNVector3(c.x + r, c.y, c.z), color: amber, radius: 0.0024))
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x, c.y, c.z - r),
                                                  to: SCNVector3(c.x, c.y, c.z + r), color: amber, radius: 0.0024))
        case nil:
            break
        }
    }

    private func clearConstraintNodes() { scene.clearResultNodes(nodes: &constraintNodes) }

    // MARK: - Break flow（T-P18-47：内置开球，替代球形生成器页；状态见类体）

    /// 进入开球模式：存当前桌面 → 清计划/约束/解 → 摆架。
    func startBreakFlow(game: RackGame) {
        guard !isPlaying, breakRunner == nil else { return }
        activeTool = .none
        boardBeforeBreak = currentSnapshot()
        clearConstraint()
        scene.clearResultNodes(nodes: &selectionNodes)
        scene.hideAllVisualization()
        scene.hideCueStick()
        let runner = BreakFlowRunner(scene: scene, game: game)
        // K6 / D-v8-3a：与 FreePlay 对齐——停稳后取消/重开/完成三态，不自动落座。
        runner.autoDeliverOnSettle = false
        breakChangeForwarder = runner.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
        runner.onSettled = { [weak self] board in
            guard let self else { return }
            self.teardownBreakFlow()
            self.loadBoard(board)
        }
        breakRunner = runner
        runner.rackUp()
    }

    /// 取消开球模式并恢复进场前桌面。
    func cancelBreakFlow() {
        guard let runner = breakRunner else { return }
        runner.cancel()
        let restore = boardBeforeBreak
        teardownBreakFlow()
        if let restore, !restore.onTable.isEmpty {
            loadBoard(restore)
        } else {
            clearTable()
        }
    }

    private func teardownBreakFlow() {
        breakRunner = nil
        breakChangeForwarder = nil
        boardBeforeBreak = nil
    }
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
        // 记录上一杆上下文（条 21.3 + G17）：击打前完整求解快照 + ①②③ 角色指派，供上一杆完整恢复/回放。
        lastShotContext = makeUndoContext(shot: sol.shot, prediction: sol.prediction)
        canUndoShot = false
        canPlayback = false

        isPlaying = true
        statusText = "运杆…"
        clearConstraintNodes()
        let strikePos = strikePosition(cue: cueNode.position)
        scene.runCueStroke(strikePosition: strikePos, aim: aim, velocity: Float(sol.shot.velocity)) { [weak self] in
            self?.launchBalls(sol: sol, recorder: recorder)
        }
    }

    /// 微调当前解（K13 草稿层，与 Silu 同契约）：正向重算写入 `adjustmentDraft`，不改 `solutions[]`。
    func adjustCurrentSolution(velocity v: Double? = nil,
                               spinX sx: Double? = nil, spinY sy: Double? = nil) {
        guard !isPlaying, !isComputing else { return }
        guard solutions.indices.contains(currentIndex) else { return }
        let catalog = solutions[currentIndex]
        let base = adjustmentDraft ?? catalog
        var shot = base.shot
        if let v { shot.velocity = v }
        if let sx { shot.spinX = sx }
        if let sy { shot.spinY = sy }
        let before = currentSnapshot()
        let y = surfaceY
        let idx = currentIndex
        let margin = catalog.margin
        let satisfies = catalog.satisfiesConstraint
        let beyondCushion = catalog.beyondCushionBudget
        let beyondSpin = catalog.beyondSpinBudget
        solveGeneration += 1
        let gen = solveGeneration
        isComputing = true

        solveQueue.async { [weak self] in
            let pred = PositionPlayShotSolver.solve(before: before, shot: shot, surfaceY: y)
            DispatchQueue.main.async {
                guard let self, self.solveGeneration == gen, !self.isPlaying else { return }
                self.isComputing = false
                guard let pred, self.solutions.indices.contains(idx), self.currentIndex == idx else { return }
                let drafted = PositionPlaySolution(
                    shot: shot, prediction: pred,
                    cushionCount: pred.cueCushionCount,
                    potted: pred.simObjectPotted,
                    margin: margin,
                    summary: "微调 · " + ShotSpinLabel.text(spinX: shot.spinX, spinY: shot.spinY)
                        + String(format: " · %.1f m/s", shot.velocity),
                    satisfiesConstraint: satisfies,
                    beyondCushionBudget: beyondCushion,
                    difficultyScore: DifficultyModel.score(
                        spinX: shot.spinX, spinY: shot.spinY, velocity: shot.velocity,
                        cutAngleDeg: pred.cutAngleDeg),
                    difficultyTier: DifficultyModel.tier(spinX: shot.spinX, spinY: shot.spinY),
                    beyondSpinBudget: beyondSpin
                )
                self.adjustmentDraft = drafted
                self.presentDisplayedSolution(drafted)
            }
        }
    }

    /// 上一杆（条 21.3 + G17）：回到上次击打前的**完整状态**——球形、①②③ 角色指派、约束、
    /// 已求出的解（缓存回填，无需重画重求解）、打点/力度/瞄准，均逐字段还原。
    func undoLastShot() {
        guard !isPlaying, canUndoShot, let ctx = lastShotContext else { return }
        restore(from: ctx)
        canUndoShot = false
        canPlayback = false
        lastShotContext = nil
        statusText = ctx.snapshot.solutions.isEmpty
            ? "已退回上一杆击打前"
            : "已退回上一杆击打前 · 球形/①②③/约束/解已还原"
    }

    /// 组装当前状态为「上一杆」完整上下文（击打前调用；`play()` 与单测共用同一处捕获逻辑）。
    func makeUndoContext(shot: PlannedShot, prediction: ShotPrediction) -> UndoContext {
        UndoContext(
            snapshot: SolveShotSnapshot(
                before: currentSnapshot(), shot: shot, prediction: prediction,
                solutions: solutions, currentIndex: currentIndex, draft: draft,
                velocity: velocity, spinX: spinX, spinY: spinY,
                allowSideSpin: allowSideSpin, basicPositionOnly: basicPositionOnly),
            ball1Key: ball1Key, ball2Key: ball2Key, ball3Key: ball3Key,
            pocket1Index: pocket1Index, pocket2Index: pocket2Index, armedRole: armedRole)
    }

    /// 把击打前完整快照原样恢复到场景与状态（不重解）。
    func restore(from ctx: UndoContext) {
        let snap = ctx.snapshot
        // 清动画/叠加，摆回击打前球形。
        scene.hideAllBalls()
        clearTrajectory()
        clearConstraintNodes()
        scene.clearResultNodes(nodes: &selectionNodes)
        scene.hideCueStick()
        for (key, pt) in snap.before.onTable { place(key: key, normalized: pt) }
        refreshOnTableKeys()

        // 求解选项须先于 solutions 恢复（同思路页顺序理由）。
        allowSideSpin = snap.allowSideSpin
        basicPositionOnly = snap.basicPositionOnly

        // 选择模型（①②③ 角色指派）。
        ball1Key = ctx.ball1Key
        ball2Key = ctx.ball2Key
        ball3Key = ctx.ball3Key
        pocket1Index = ctx.pocket1Index
        pocket2Index = ctx.pocket2Index
        armedRole = ctx.armedRole

        // 约束草稿（保留落点/落区/过点的视觉与语义分叉）。
        draft = snap.draft
        hasConstraint = snap.draft != nil
        activeTool = .none

        // 解回填（「解还在」，免重解）。catalog 原样回填；击打若用微调则重建草稿层。
        solveGeneration += 1
        isComputing = false
        solutions = snap.solutions
        currentIndex = snap.currentIndex
        adjustmentDraft = nil

        if solutions.indices.contains(currentIndex) {
            let catalog = solutions[currentIndex]
            if Self.shotParamsDiffer(catalog.shot, snap.shot) {
                adjustmentDraft = PositionPlaySolution(
                    shot: snap.shot, prediction: snap.prediction,
                    cushionCount: snap.prediction.cueCushionCount,
                    potted: snap.prediction.simObjectPotted,
                    margin: catalog.margin,
                    summary: "微调 · " + ShotSpinLabel.text(spinX: snap.shot.spinX, spinY: snap.shot.spinY)
                        + String(format: " · %.1f m/s", snap.shot.velocity),
                    satisfiesConstraint: catalog.satisfiesConstraint,
                    beyondCushionBudget: catalog.beyondCushionBudget,
                    difficultyScore: DifficultyModel.score(
                        spinX: snap.shot.spinX, spinY: snap.shot.spinY, velocity: snap.shot.velocity,
                        cutAngleDeg: snap.prediction.cutAngleDeg),
                    difficultyTier: DifficultyModel.tier(spinX: snap.shot.spinX, spinY: snap.shot.spinY),
                    beyondSpinBudget: catalog.beyondSpinBudget
                )
                presentDisplayedSolution(adjustmentDraft!)
            } else {
                showSolution(at: currentIndex)
            }
        } else {
            velocity = snap.velocity
            spinX = snap.spinX
            spinY = snap.spinY
            renderConstraint()
            refreshOverlays()
        }
    }

    private static func shotParamsDiffer(_ a: PlannedShot, _ b: PlannedShot) -> Bool {
        abs(a.velocity - b.velocity) > 1e-9
            || abs(a.spinX - b.spinX) > 1e-9
            || abs(a.spinY - b.spinY) > 1e-9
    }

    /// 回放上一杆击打过程：退回击打前重播动画，播完回到击打后局面。
    func replayLastShot() {
        guard !isPlaying, canPlayback, let ctx = lastShotContext else { return }
        let snap = ctx.snapshot
        guard let recorder = snap.prediction.recorder, snap.prediction.duration > 0.05 else { return }
        let after = currentSnapshot()
        isPlaying = true
        clearTrajectory()
        clearConstraintNodes()
        scene.clearResultNodes(nodes: &selectionNodes)
        scene.hideCueStick()
        statusText = "回放上一杆…"

        scene.hideAllBalls()
        for (key, pt) in snap.before.onTable { place(key: key, normalized: pt) }
        refreshOnTableKeys()

        guard let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
              let aim = aimDirection(path: snap.prediction.cuePath, from: cueNode.position) else {
            finishPlayback(after: after)
            return
        }
        let strikePos = CueStroke.strikePosition(cue: cueNode.position, aim: aim, spinX: snap.shot.spinX)
        scene.runCueStroke(strikePosition: strikePos, aim: aim,
                           velocity: Float(snap.shot.velocity)) { [weak self] in
            self?.runPlaybackAnimation(snapshot: snap, recorder: recorder, after: after)
        }
    }

    private func runPlaybackAnimation(
        snapshot ctx: SolveShotSnapshot,
        recorder: TrajectoryRecorder, after: BoardSnapshot
    ) {
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let settle = playback.duration   // G15：播到引擎自然静止（不做感知截断）

        var cueAction: SCNAction?
        for key in onTableKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let name = PositionPlayShotSolver.predName(boardKey: key, shot: ctx.shot)
            let action = playback.action(for: node, ballName: name, speed: 1.0,
                                         removeOnPocket: false, maxSimTime: settle)
            if key == PositionPlayBall.cueKey { cueAction = action }
            else if let action { node.runAction(action) }
        }
        let tail: TimeInterval = ctx.prediction.pocketedBalls.isEmpty
            ? 0 : TrajectoryPlayback.pocketSettleDuration + 0.1
        if let cueAction, let cueNode = scene.allBallNodes[PositionPlayBall.cueKey] {
            cueNode.runAction(cueAction) { [weak self] in
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(tail * 1_000_000_000))
                    self?.finishPlayback(after: after)
                }
            }
            ShotAudioScheduler.shared.play(prediction: ctx.prediction)
        } else {
            finishPlayback(after: after)
        }
    }

    private func finishPlayback(after: BoardSnapshot) {
        ShotAudioScheduler.shared.cancel()
        for key in PositionPlayBall.allKeys {
            guard let node = scene.allBallNodes[key] else { continue }
            if node.parent == nil { scene.rootNode.addChildNode(node) }
            node.removeAllActions()
            node.opacity = 1
        }
        isPlaying = false
        scene.hideCueStick()
        let ctx = lastShotContext
        loadBoard(after)
        lastShotContext = ctx
        canUndoShot = ctx != nil
        canPlayback = ctx != nil
        statusText = "回放结束 · 球停在击打后局面"
    }

    private func launchBalls(sol: PositionPlaySolution, recorder: TrajectoryRecorder) {
        statusText = "击球中…"
        clearTrajectory()
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let settle = playback.duration   // G15：播到引擎自然静止（不做感知截断）
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

        canUndoShot = lastShotContext != nil
        canPlayback = lastShotContext?.snapshot.prediction.recorder != nil

        let cueGone = scene.allBallNodes[PositionPlayBall.cueKey]?.isHidden ?? true
        // Q15.2 清台终局：台面无目标球 ⇒ 终局提示（清空后重开）。
        if objectBallCount == 0 {
            statusText = cueGone
                ? "清台完成 🎉（母球也进袋）· 用「恢复默认」重开一局"
                : "清台完成 🎉 · 用「恢复默认」重开一局"
        } else if cueGone {
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

    // MARK: - UITest hooks（仅 UI 测试注入确定性状态；生产无对应 launch arg 时永不触发，行为不变）

    /// 直接指派①②③角色（绕过点选流程），供 UITest 确定性摆好扇形/pot-only 局面取证。
    private func setPlanDirect(ball1: String?, pocket1: Int, ball2: String?, pocket2: Int, ball3: String?) {
        ball1Key = ball1; pocket1Index = pocket1
        ball2Key = ball2; pocket2Index = pocket2
        ball3Key = ball3
        armedRole = nextEmptyRole()
        statusText = hintForState()
        invalidateSolutions()
    }

    /// UITest 场景注入（Q15.1/Q15.2 截图取证）。scenario 见 `PlanThreeView` onAppear。
    func uiTestConfigure(_ scenario: String) {
        guard !isPlaying else { return }
        let cue = CanvasPoint(x: 0.24, y: 0.30)
        let b1 = CanvasPoint(x: 0.52, y: 0.16)
        let b2 = CanvasPoint(x: 0.70, y: 0.34)
        switch scenario {
        case "twoBall", "twoBallDimmed":
            loadBoard(BoardSnapshot(onTable: [PositionPlayBall.cueKey: cue, "_1": b1, "_2": b2]))
            setPlanDirect(ball1: "_1", pocket1: 1, ball2: "_2", pocket2: 3, ball3: nil)
            if scenario == "twoBallDimmed" {
                activeTool = .region
                toolDrag(startNormalized: CanvasPoint(x: 0.40, y: 0.24),
                         currentNormalized: CanvasPoint(x: 0.58, y: 0.40), ended: true)
            }
        case "oneBall":
            loadBoard(BoardSnapshot(onTable: [PositionPlayBall.cueKey: cue, "_1": b1]))
            setPlanDirect(ball1: "_1", pocket1: 4, ball2: nil, pocket2: -1, ball3: nil)
        case "cleared":
            loadBoard(BoardSnapshot(onTable: [PositionPlayBall.cueKey: cue, "_1": b1]))
            setPlanDirect(ball1: "_1", pocket1: 4, ball2: nil, pocket2: -1, ball3: nil)
            removeFromTable("_1")   // 打进最后一颗（母球留台）⇒ 清台终局
        default:
            break
        }
    }
}
