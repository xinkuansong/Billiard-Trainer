import Foundation
import SceneKit

/// **翻袋（bank-shot）求解器**：把*目标球*经过 N 次库边纯反射后送进指定袋口，
/// 再反推母球应当如何瞄准（幽灵球 / 接触点 / 瞄准线）。
///
/// 与 `DiamondSystemCalculator`（反射解球器，求母球→目标球的走位）不同，本求解器
/// 关心的是 **目标球的进袋路线**：用户选定一个袋口，目标球需要先撞 1/2/3 库，再落袋。
///
/// 纯反射模型（无塞、无速度衰减）：每次碰库遵循「入射角 = 反射角」。求解使用经典的
/// **镜像展开法**——把袋口沿要碰的库边依次做镜像，连成直线即可解出每个反弹点。
///
/// 坐标系与 `AngleSceneCalculator` 一致：长轴 X，短轴 Z，Y 为高度（计算时忽略）。
enum BankShotCalculator {

    // MARK: - Table geometry (shared with AngleSceneCalculator)

    static var innerLength: Float { AngleSceneCalculator.innerLength }
    static var innerWidth: Float { AngleSceneCalculator.innerWidth }
    static var halfL: Float { innerLength / 2 }
    static var halfW: Float { innerWidth / 2 }
    static var ballRadius: Float { AngleSceneCalculator.ballRadius }

    /// 首库入射角（相对库面）下限：太平的擦库不现实，过滤掉。
    static let minFirstCushionAngleDeg: Float = 15

    /// 母球可击打的最大切球角（与瞄准训练一致，用 89° 兼顾几何允许与数值稳定）。
    static let maxCutAngleDeg: Double = 80

    // MARK: - Rails

    /// 四条库：`left`/`right` 为长库（常 Z），`far`/`near` 为短库（常 X）。
    enum Rail: CaseIterable {
        case left   // Z = -halfW
        case right  // Z = +halfW
        case far    // X = -halfL
        case near   // X = +halfL

        var isLong: Bool { self == .left || self == .right }

        /// 旋转 2D 顶视图下的中文标签（屏幕上长库为左右边，短库为上下边）。
        var label: String {
            switch self {
            case .left: "左库"
            case .right: "右库"
            case .far: "底库"   // X = -halfL → 屏幕下
            case .near: "顶库"  // X = +halfL → 屏幕上
            }
        }
    }

    private static func railCoord(_ rail: Rail) -> Float {
        switch rail {
        case .left: -halfW
        case .right: halfW
        case .far: -halfL
        case .near: halfL
        }
    }

    /// 映射到共享真实反射核心的库描述符。
    private static func descriptor(_ rail: Rail) -> CushionReflectionSolver.Rail {
        CushionReflectionSolver.Rail(isLong: rail.isLong, coord: railCoord(rail))
    }

    /// 把一个点沿某条库边做镜像。
    private static func reflect(_ p: SCNVector3, across rail: Rail) -> SCNVector3 {
        if rail.isLong {
            return SCNVector3(p.x, p.y, 2 * railCoord(rail) - p.z)
        } else {
            return SCNVector3(2 * railCoord(rail) - p.x, p.y, p.z)
        }
    }

    /// 线段 `a → b` 与库边直线求交，返回交点与沿 `a → b` 的参数 t（平行返回 nil）。
    private static func intersect(_ a: SCNVector3, _ b: SCNVector3, rail: Rail) -> (SCNVector3, Float)? {
        let c = railCoord(rail)
        if rail.isLong {
            let denom = b.z - a.z
            guard abs(denom) > 1e-6 else { return nil }
            let t = (c - a.z) / denom
            return (SCNVector3(a.x + t * (b.x - a.x), a.y, c), t)
        } else {
            let denom = b.x - a.x
            guard abs(denom) > 1e-6 else { return nil }
            let t = (c - a.x) / denom
            return (SCNVector3(c, a.y, a.z + t * (b.z - a.z)), t)
        }
    }

    /// 反弹点是否落在该库的物理线段内。
    private static func onRailSegment(_ p: SCNVector3, rail: Rail) -> Bool {
        let eps: Float = 1e-4
        if rail.isLong {
            return p.x >= -halfL - eps && p.x <= halfL + eps
        } else {
            return p.z >= -halfW - eps && p.z <= halfW + eps
        }
    }

    // MARK: - Solution

    struct Solution: Identifiable {
        let id = UUID()
        let cushions: Int
        let rails: [Rail]
        let pocketIndex: Int

        /// 目标球的进袋折线 [目标球, 反弹点1, …, 反弹点k, 袋口]。真实模式下为按缩小因子追迹的实际进袋线。
        let objectPath: [SCNVector3]
        /// 理想（入射角=反射角）对照进袋线；仅真实模式下非 nil，供绘制虚线对照。
        var idealObjectPath: [SCNVector3]? = nil
        /// 母球瞄准用的幽灵球中心（= 目标球沿出发方向反向偏移 2R）。
        let ghost: SCNVector3
        /// 母球与目标球的接触点（目标球表面，= 目标球沿出发方向反向偏移 R）。
        let contact: SCNVector3
        /// 切球角 α（瞄准线与目标球出发方向的夹角，度）。
        let cutAngle: Double
        /// 进袋路径长度（用于排序，越短越优）。
        let length: Float

        /// 反弹点（不含目标球与袋口）。
        var cushionPoints: [SCNVector3] {
            guard objectPath.count > 2 else { return [] }
            return Array(objectPath[1..<(objectPath.count - 1)])
        }

        /// e.g. "底库 → 左库"。
        var railSequenceText: String {
            rails.map(\.label).joined(separator: " → ")
        }
    }

    // MARK: - Public solve

    /// 求出母球 `cue`、目标球 `object` 下，把目标球翻进 `pocketIndex` 袋的所有解，
    /// 按（库数升序、路径长度升序）排序并去重。第一条即「最少库 / 最短」解。
    /// `realMode` = false → 理想镜面反射；true → 用真实物理引擎按 `power`（m/s 发力）模拟翻库
    /// （`EngineCushionTracer`，含速度相关回弹与摩擦衰减，无需手动拟合）。
    static func solveAll(
        cue: SCNVector3,
        object: SCNVector3,
        pocketIndex: Int,
        surfaceY: Float,
        realMode: Bool = false,
        power: Float = CushionReflectionSettings.defaultPower,
        maxCushions: Int = 3,
        limit: Int = 12
    ) -> [Solution] {
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        guard pocketIndex >= 0, pocketIndex < pockets.count else { return [] }

        let y = surfaceY + ballRadius
        let cuePt = SCNVector3(cue.x, y, cue.z)
        let objPt = SCNVector3(object.x, y, object.z)

        // 先求理想（镜像展开）解集，路径与历史版本完全一致。
        var ideal: [Solution] = []
        for n in 1...max(1, maxCushions) {
            for seq in railSequences(length: n) {
                guard let path = solveSequence(object: objPt, pocketIndex: pocketIndex, rails: seq, y: y,
                                               surfaceY: surfaceY) else { continue }
                guard let sol = makeSolution(cue: cuePt, path: path, rails: seq,
                                             pocketIndex: pocketIndex, y: y) else { continue }
                if !isDuplicate(sol, in: ideal) { ideal.append(sol) }
            }
        }
        ideal.sort { lhs, rhs in
            lhs.cushions != rhs.cushions ? lhs.cushions < rhs.cushions : lhs.length < rhs.length
        }

        guard realMode else {
            return Array(ideal.prefix(limit))
        }

        // 真实模式：对每条理想解的库序，从目标球以理想首段方向为种子、按 `power` 发力用真实
        // 物理引擎射击法追迹出实际进袋线，再据实际出发方向反推母球瞄准；理想线作为对照。
        // 性能护栏：仅精修最有希望的前若干条理想解（引擎射击较重，每条需多次正向模拟）。
        var real: [Solution] = []
        for sol in ideal.prefix(limit) {
            guard let aim = sol.objectPath.last, sol.objectPath.count >= 2 else { continue }
            let descriptors = sol.rails.map(descriptor)
            let seed = SCNVector3(sol.objectPath[1].x - sol.objectPath[0].x, 0,
                                  sol.objectPath[1].z - sol.objectPath[0].z)
            guard let realPath = EngineCushionTracer.shoot(
                start: sol.objectPath[0], target: aim, seedDir: seed,
                rails: descriptors, speed: power, y: y
            ) else { continue }
            guard firstCushionAngleOK(path: realPath, firstRail: sol.rails[0]) else { continue }
            guard var rsol = makeSolution(cue: cuePt, path: realPath, rails: sol.rails,
                                          pocketIndex: pocketIndex, y: y) else { continue }
            rsol.idealObjectPath = sol.objectPath
            real.append(rsol)
        }
        real.sort { lhs, rhs in
            lhs.cushions != rhs.cushions ? lhs.cushions < rhs.cushions : lhs.length < rhs.length
        }
        return Array(real.prefix(limit))
    }

    // MARK: - Engine bank-solve seeds (W1，20260709 翻袋反射页重构方案 §2.1)

    /// 镜像展开种子路径（引擎反解第 0 层）：固定库序下目标球 → 反弹点… → 进球点的
    /// 纯几何折线。仅作为 `ShotPredictor` bank 反解的**方向种子**，不再直接上屏。
    static func bankSeedPath(
        object: SCNVector3, pocketIndex: Int, rails: [Rail], surfaceY: Float
    ) -> [SCNVector3]? {
        let y = surfaceY + ballRadius
        let objPt = SCNVector3(object.x, y, object.z)
        return solveSequence(object: objPt, pocketIndex: pocketIndex, rails: rails,
                             y: y, surfaceY: surfaceY)
    }

    /// 全部合法库序候选（长度 1...maxCushions，相邻不相同不正对）。
    /// 引擎反解的多解枚举入口（W3 消费；W1 benchmark 用它构造「单袋全枚举」口径）。
    static func candidateRailSequences(maxCushions: Int) -> [[Rail]] {
        var out: [[Rail]] = []
        for n in 1...max(1, maxCushions) {
            out.append(contentsOf: railSequences(length: n))
        }
        return out
    }

    // MARK: - Sequence solving (mirror unfolding)

    /// 解一个固定库序：目标球 → rails → 袋口。返回 [目标球, P1…Pk, 进球点] 或 nil。
    ///
    /// 进球点**不固定为袋口中心**：复用 `AngleSceneCalculator.effectivePocketAimPoint`
    /// 的「进球管道」模型——以末库反弹点作为目标球进袋前的来向，反推一个让球能顺利
    /// 入袋（不蹭库 / 不撞 jaw）的进球点；再用该点重新镜像展开。迭代几次让反弹点与
    /// 进球点收敛，避免中袋 / 角袋的末段「直接撞库」。
    private static func solveSequence(
        object: SCNVector3, pocketIndex: Int, rails: [Rail], y: Float, surfaceY: Float
    ) -> [SCNVector3]? {
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        guard pocketIndex >= 0, pocketIndex < pockets.count else { return nil }
        var target = SCNVector3(pockets[pocketIndex].x, y, pockets[pocketIndex].z)

        var path: [SCNVector3]?
        for _ in 0..<3 {
            // 若细化后的进球点解不出有效折线，保留上一次有效解（避免丢解）。
            guard let p = unfold(object: object, target: target, rails: rails, y: y, surfaceY: surfaceY) else {
                break
            }
            path = p
            // 末库反弹点 = 目标球进袋前的最后一个落点（即进袋来向的起点）。
            let lastCushion = p[p.count - 2]
            let aim = AngleSceneCalculator.effectivePocketAimPoint(
                targetBall: lastCushion, pocketIndex: pocketIndex, surfaceY: surfaceY
            )
            let aimPt = SCNVector3(aim.x, y, aim.z)
            if horizontalDistance(aimPt, target) < 0.001 { break }
            target = aimPt
        }
        return path
    }

    /// 固定库序 + 固定终点的镜像展开，返回 [目标球, P1…Pk, 终点] 或 nil。
    private static func unfold(
        object: SCNVector3, target: SCNVector3, rails: [Rail], y: Float, surfaceY: Float
    ) -> [SCNVector3]? {
        let k = rails.count
        guard k >= 1 else { return nil }

        // images[i] = 终点依次对 rails[k-1], …, rails[i] 做镜像。
        var images = [SCNVector3](repeating: target, count: k)
        var img = target
        for i in stride(from: k - 1, through: 0, by: -1) {
            img = reflect(img, across: rails[i])
            images[i] = img
        }

        let eps: Float = 1e-4
        var prev = object
        var pts: [SCNVector3] = [object]
        for i in 0..<k {
            guard let (p, t) = intersect(prev, images[i], rail: rails[i]) else { return nil }
            guard t > eps, t < 1 - eps else { return nil }
            guard onRailSegment(p, rail: rails[i]) else { return nil }
            let point = SCNVector3(p.x, y, p.z)
            // 拒绝退化的零长跳。
            if horizontalDistance(point, prev) < ballRadius * 0.5 { return nil }
            // 反弹点不能落进袋口嘴（否则目标球直接进袋而非翻库）。
            if hitsPocket(point, surfaceY: surfaceY) { return nil }
            pts.append(point)
            prev = point
        }
        // 末段到进球点必须有正向位移。
        if horizontalDistance(target, prev) < ballRadius * 0.5 { return nil }
        pts.append(target)

        guard firstCushionAngleOK(path: pts, firstRail: rails[0]) else { return nil }
        return pts
    }

    /// 由目标球进袋折线反推母球瞄准信息；切球角过大返回 nil。
    private static func makeSolution(
        cue: SCNVector3, path: [SCNVector3], rails: [Rail], pocketIndex: Int, y: Float
    ) -> Solution? {
        guard path.count >= 2 else { return nil }
        let object = path[0]
        let firstHop = path[1]

        // 目标球出发方向（XZ 单位向量）。
        let depX = firstHop.x - object.x
        let depZ = firstHop.z - object.z
        let depLen = sqrtf(depX * depX + depZ * depZ)
        guard depLen > 1e-5 else { return nil }
        let dir = SCNVector3(depX / depLen, 0, depZ / depLen)

        let ghost = SCNVector3(object.x - 2 * ballRadius * dir.x, y, object.z - 2 * ballRadius * dir.z)
        let contact = SCNVector3(object.x - ballRadius * dir.x, y, object.z - ballRadius * dir.z)

        // 切球角 = 瞄准线（母球→幽灵球）与目标球出发方向的夹角。
        let strikeX = ghost.x - cue.x
        let strikeZ = ghost.z - cue.z
        let strikeLen = sqrtf(strikeX * strikeX + strikeZ * strikeZ)
        guard strikeLen > 1e-5 else { return nil }
        let dot = max(-1, min(1, (strikeX / strikeLen) * dir.x + (strikeZ / strikeLen) * dir.z))
        let cut = acos(Double(dot)) * 180 / .pi
        guard cut < maxCutAngleDeg else { return nil }

        // 母球占位避让：目标球碰库返回后不能撞到仍停在台面的母球。
        // 两球球心间距 < 2R 即碰撞；只检查「首段之后」的路段（首段是离开母球方向）。
        guard objectPathClearsCue(cue: cue, path: path) else { return nil }

        return Solution(
            cushions: rails.count,
            rails: rails,
            pocketIndex: pocketIndex,
            objectPath: path,
            ghost: ghost,
            contact: contact,
            cutAngle: min(cut, 90),
            length: polylineLength(path)
        )
    }

    // MARK: - Filters

    /// 反弹点是否落入某个袋口嘴。
    private static func hitsPocket(_ p: SCNVector3, surfaceY: Float) -> Bool {
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        for (i, pk) in pockets.enumerated() {
            let r = (i < 4 ? AngleSceneCalculator.cornerPocketRadius
                           : AngleSceneCalculator.middlePocketRadius) + ballRadius
            if horizontalDistance(p, pk) < r { return true }
        }
        return false
    }

    /// 首库入射角（相对库面）必须 ≥ 下限。
    private static func firstCushionAngleOK(path: [SCNVector3], firstRail: Rail) -> Bool {
        guard path.count >= 2 else { return true }
        let dx0 = path[1].x - path[0].x
        let dz0 = path[1].z - path[0].z
        let len = sqrtf(dx0 * dx0 + dz0 * dz0)
        guard len > 1e-6 else { return false }
        let dx = abs(dx0 / len), dz = abs(dz0 / len)
        let angle: Float = firstRail.isLong ? atan2(dz, dx) : atan2(dx, dz)
        return angle >= minFirstCushionAngleDeg * .pi / 180
    }

    /// 两条库是否「正对」（两长库或两短库）。连续撞正对库会来回「N 字」往返，不现实。
    private static func areOpposite(_ a: Rail, _ b: Rail) -> Bool {
        (a == .left && b == .right) || (a == .right && b == .left) ||
        (a == .far && b == .near) || (a == .near && b == .far)
    }

    /// 长度为 n 的库序，相邻两库既不相同也不正对。
    private static func railSequences(length n: Int) -> [[Rail]] {
        var result: [[Rail]] = []
        func extend(_ current: [Rail]) {
            if current.count == n { result.append(current); return }
            for rail in Rail.allCases {
                if let last = current.last, last == rail || areOpposite(last, rail) { continue }
                extend(current + [rail])
            }
        }
        extend([])
        return result
    }

    private static func isDuplicate(_ sol: Solution, in list: [Solution]) -> Bool {
        list.contains { existing in
            existing.objectPath.count == sol.objectPath.count &&
            zip(existing.objectPath, sol.objectPath).allSatisfy { horizontalDistance($0, $1) < 0.01 }
        }
    }

    /// 目标球进袋折线（首段除外）是否与母球（半径 R）保持 ≥ 2R 的球心间距。
    /// 首段（目标球 → 首库）是离开母球的方向，接触瞬间母球本就贴在目标球后方，不计。
    private static func objectPathClearsCue(cue: SCNVector3, path: [SCNVector3]) -> Bool {
        guard path.count >= 3 else { return true }
        let minCenterDist: Float = 2 * ballRadius + 0.001
        for i in 1..<(path.count - 1) {
            if pointSegmentDistance(cue, path[i], path[i + 1]) < minCenterDist { return false }
        }
        return true
    }

    /// 点 `p` 到线段 `a→b` 的水平（XZ）距离。
    private static func pointSegmentDistance(_ p: SCNVector3, _ a: SCNVector3, _ b: SCNVector3) -> Float {
        let abx = b.x - a.x, abz = b.z - a.z
        let lenSq = abx * abx + abz * abz
        guard lenSq > 1e-9 else { return horizontalDistance(p, a) }
        var t = ((p.x - a.x) * abx + (p.z - a.z) * abz) / lenSq
        t = max(0, min(1, t))
        let cx = a.x + t * abx, cz = a.z + t * abz
        let dx = p.x - cx, dz = p.z - cz
        return sqrtf(dx * dx + dz * dz)
    }

    // MARK: - Helpers

    private static func polylineLength(_ path: [SCNVector3]) -> Float {
        guard path.count >= 2 else { return 0 }
        var total: Float = 0
        for i in 0..<(path.count - 1) { total += horizontalDistance(path[i], path[i + 1]) }
        return total
    }

    private static func horizontalDistance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x, dz = a.z - b.z
        return sqrtf(dx * dx + dz * dz)
    }
}
