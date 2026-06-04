import Foundation
import SceneKit

/// 共享的「真实反射」正向追迹 + 射击法求解核心，供 `BankShotCalculator`（翻袋）与
/// `DiamondSystemCalculator`（反射解球器）共用。
///
/// **物理模型**：球碰库时，法向速度分量翻转、**切向分量 × factor**。
/// `factor ∈ [0.50, 1.00]`，`1.0` = 理想镜面反射（入射角 = 反射角）。几何上
/// `tan θ_out = factor · tan θ_in`（θ 相对库面法线），故 `factor < 1` 时反射「偏短」——
/// 对应真实球台「翻库回不到镜像位」的现象。
///
/// **求解**：镜像展开法仅在 `factor = 1` 成立。本核心改用**正向射线追迹 + 射击法**：
/// 对一条固定库序，扫描出发角找到「命中目标」的解，并在每次反弹时校验命中的库恰为库序中的库
/// （保证物理正确，自动剔除真实模式下不再成立的库序）。
///
/// 坐标系与 `AngleSceneCalculator` 一致：长轴 X、短轴 Z、Y 为高度（求解时忽略）。
enum CushionReflectionSolver {

    // MARK: - Geometry (shared with AngleSceneCalculator)

    static var innerLength: Float { AngleSceneCalculator.innerLength }
    static var innerWidth: Float { AngleSceneCalculator.innerWidth }
    static var halfL: Float { innerLength / 2 }
    static var halfW: Float { innerWidth / 2 }
    static var ballRadius: Float { AngleSceneCalculator.ballRadius }

    /// 缩小因子合法区间（与滑块一致）。
    static let minFactor: Float = 0.50
    static let maxFactor: Float = 1.0

    /// `factor` 是否近似为理想（≈1），用于切换解析/数值分支。
    static func isIdeal(_ factor: Float) -> Bool { factor >= 0.999 }

    static func clampFactor(_ factor: Float) -> Float {
        min(maxFactor, max(minFactor, factor))
    }

    // MARK: - Rail descriptor

    /// 轻量库描述符：`isLong` 为长库（常 Z = ±halfW），否则短库（常 X = ±halfL）。
    struct Rail {
        let isLong: Bool
        let coord: Float

        func matches(_ other: Rail) -> Bool {
            isLong == other.isLong && abs(coord - other.coord) < 1e-3
        }
    }

    /// 台面四条库（顺序无关，仅用于「最近命中库」判定）。
    private static func tableRails() -> [Rail] {
        [
            Rail(isLong: true, coord: -halfW),   // 左库
            Rail(isLong: true, coord: halfW),    // 右库
            Rail(isLong: false, coord: -halfL),  // 底库
            Rail(isLong: false, coord: halfL)    // 顶库
        ]
    }

    // MARK: - Reflection (tangential shrink)

    /// 按 factor 缩放切向分量后的出射方向（单位向量，XZ 平面）。
    static func reflect(dir d: SCNVector3, rail: Rail, factor: Float) -> SCNVector3 {
        let raw: SCNVector3
        if rail.isLong {
            // 长库：法向沿 Z，切向沿 X。
            raw = SCNVector3(factor * d.x, 0, -d.z)
        } else {
            // 短库：法向沿 X，切向沿 Z。
            raw = SCNVector3(-d.x, 0, factor * d.z)
        }
        let len = sqrtf(raw.x * raw.x + raw.z * raw.z)
        guard len > 1e-6 else { return d }
        return SCNVector3(raw.x / len, 0, raw.z / len)
    }

    // MARK: - Public solve (one fixed rail sequence)

    /// 对固定库序求「从 `start` 出发、按 factor 反射、命中 `target`」的折线。
    /// 返回 `[start, P1…Pk, target]`（Y 统一为 `y`），无解返回 nil。
    static func shoot(start: SCNVector3, target: SCNVector3,
                      rails: [Rail], factor: Float, y: Float) -> [SCNVector3]? {
        let k = rails.count
        guard k >= 1 else { return nil }
        let s = SCNVector3(start.x, y, start.z)
        let t = SCNVector3(target.x, y, target.z)

        // 粗扫出发角，找 signed-miss 变号区间，再二分求根。
        let coarse = 360
        var prevTheta: Float = 0
        var prevMiss: Float = .nan
        var bestPath: [SCNVector3]?
        var bestPerp = Float.greatestFiniteMagnitude

        for i in 0...coarse {
            let theta = Float(i) / Float(coarse) * 2 * .pi
            let miss = signedMiss(start: s, target: t, rails: rails, factor: factor, theta: theta)
            defer { prevTheta = theta; prevMiss = miss }
            guard i > 0, prevMiss.isFinite, miss.isFinite else { continue }
            guard (prevMiss <= 0) != (miss <= 0) else { continue }
            guard let theta0 = bisect(start: s, target: t, rails: rails, factor: factor,
                                      lo: prevTheta, hi: theta) else { continue }
            guard let path = buildAndValidate(start: s, target: t, rails: rails,
                                              factor: factor, theta: theta0, y: y) else { continue }
            // 选末段对准误差最小的解。
            let perp = finalLegPerp(path: path)
            if perp < bestPerp { bestPerp = perp; bestPath = path }
        }
        return bestPath
    }

    // MARK: - Trace

    /// 单次追迹：从 `start` 沿 `theta` 出发，依序碰 `rails` 中每条库（按 factor 反射）。
    /// 成功返回 (反弹点含起点, 末点, 末向)，任一约束不满足返回 nil。
    private static func trace(start: SCNVector3, rails: [Rail], factor: Float,
                             theta: Float) -> (points: [SCNVector3], end: SCNVector3, dir: SCNVector3)? {
        var p = start
        var d = SCNVector3(cosf(theta), 0, sinf(theta))
        var pts: [SCNVector3] = [start]

        for rail in rails {
            guard let hit = nearestRailHit(from: p, dir: d) else { return nil }
            // 命中的库必须正是库序中的这条（物理正确性）。
            guard hit.rail.matches(rail) else { return nil }
            // 反弹点不能落进袋口嘴（否则球落袋而非翻库）。
            if hitsPocket(hit.point) { return nil }
            // 拒绝退化的零长跳。
            if horizontalDistance(hit.point, p) < ballRadius * 0.5 { return nil }
            pts.append(hit.point)
            d = reflect(dir: d, rail: rail, factor: factor)
            p = hit.point
        }
        return (pts, p, d)
    }

    /// 末点对准 target 的带符号偏差（XZ 叉积 z 分量 ≈ 末向与「指向 target」夹角的 sin）。
    private static func signedMiss(start: SCNVector3, target: SCNVector3,
                                   rails: [Rail], factor: Float, theta: Float) -> Float {
        guard let r = trace(start: start, rails: rails, factor: factor, theta: theta) else { return .nan }
        let tx = target.x - r.end.x
        let tz = target.z - r.end.z
        let len = sqrtf(tx * tx + tz * tz)
        guard len > 1e-6 else { return 0 }
        return r.dir.x * (tz / len) - r.dir.z * (tx / len)
    }

    private static func bisect(start: SCNVector3, target: SCNVector3, rails: [Rail],
                               factor: Float, lo: Float, hi: Float) -> Float? {
        var a = lo, b = hi
        let fa = signedMiss(start: start, target: target, rails: rails, factor: factor, theta: a)
        guard fa.isFinite else { return nil }
        var signA = fa <= 0
        for _ in 0..<40 {
            let m = (a + b) / 2
            let fm = signedMiss(start: start, target: target, rails: rails, factor: factor, theta: m)
            guard fm.isFinite else { return nil }
            if (fm <= 0) == signA { a = m } else { b = m }
            signA = signedMiss(start: start, target: target, rails: rails, factor: factor, theta: a) <= 0
            if abs(b - a) < 1e-6 { break }
        }
        return (a + b) / 2
    }

    /// 用收敛后的出发角重建完整折线，并做末段有效性校验（前向 / 对准 / 末段不先撞库）。
    private static func buildAndValidate(start: SCNVector3, target: SCNVector3, rails: [Rail],
                                         factor: Float, theta: Float, y: Float) -> [SCNVector3]? {
        guard let r = trace(start: start, rails: rails, factor: factor, theta: theta) else { return nil }
        let end = r.end
        let d = r.dir
        let tx = target.x - end.x
        let tz = target.z - end.z
        let proj = tx * d.x + tz * d.z            // 末向上的投影 ≈ 到 target 的距离
        guard proj > ballRadius * 0.5 else { return nil }       // 必须前向且非退化
        let perp = abs(d.x * tz - d.z * tx)
        guard perp < 0.012 else { return nil }                  // 对准误差（米）
        // 末段在到达 target 之前不得先撞到其它库。
        if let railHit = nearestRailHit(from: end, dir: d), railHit.t < proj - 1e-3 { return nil }
        var pts = r.points
        pts.append(SCNVector3(target.x, y, target.z))
        return pts
    }

    private static func finalLegPerp(path: [SCNVector3]) -> Float {
        guard path.count >= 2 else { return .greatestFiniteMagnitude }
        let a = path[path.count - 2], b = path[path.count - 1]
        return horizontalDistance(a, b)   // 仅作排序用，越短优先
    }

    // MARK: - Ray / rail intersection

    private struct RailHit { let point: SCNVector3; let t: Float; let rail: Rail }

    /// 从 `p` 沿 `dir`（单位向量）射出，返回最先命中的台面库（在物理线段内、t>eps）。
    private static func nearestRailHit(from p: SCNVector3, dir d: SCNVector3) -> RailHit? {
        let eps: Float = 1e-4
        var best: RailHit?
        for rail in tableRails() {
            let t: Float
            let hit: SCNVector3
            if rail.isLong {
                guard abs(d.z) > 1e-6 else { continue }
                t = (rail.coord - p.z) / d.z
                guard t > eps else { continue }
                let hx = p.x + t * d.x
                guard hx >= -halfL - eps, hx <= halfL + eps else { continue }
                hit = SCNVector3(hx, p.y, rail.coord)
            } else {
                guard abs(d.x) > 1e-6 else { continue }
                t = (rail.coord - p.x) / d.x
                guard t > eps else { continue }
                let hz = p.z + t * d.z
                guard hz >= -halfW - eps, hz <= halfW + eps else { continue }
                hit = SCNVector3(rail.coord, p.y, hz)
            }
            if best == nil || t < best!.t {
                best = RailHit(point: hit, t: t, rail: rail)
            }
        }
        return best
    }

    /// 反弹点是否落入某个袋口嘴。
    private static func hitsPocket(_ p: SCNVector3) -> Bool {
        let surfaceY = p.y - ballRadius
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        for (i, pk) in pockets.enumerated() {
            let r = (i < 4 ? AngleSceneCalculator.cornerPocketRadius
                           : AngleSceneCalculator.middlePocketRadius) + ballRadius
            if horizontalDistance(p, pk) < r { return true }
        }
        return false
    }

    private static func horizontalDistance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x, dz = a.z - b.z
        return sqrtf(dx * dx + dz * dz)
    }
}

/// 翻袋 / 反射两页共享的「真实反射模式」设置（持久化于 UserDefaults，两页通用）。
/// 用户拟合一次缩小因子，两个解球器同时生效。
enum CushionReflectionSettings {
    static let realModeKey = "cushionReflectionRealMode"
    static let factorKey = "cushionReflectionFactor"

    /// 是否启用真实模式（默认 false = 理想模式）。
    static var realMode: Bool {
        get { UserDefaults.standard.bool(forKey: realModeKey) }
        set { UserDefaults.standard.set(newValue, forKey: realModeKey) }
    }

    /// 缩小因子（0.50–1.00，默认 1.00）。
    static var factor: Float {
        get {
            let stored = UserDefaults.standard.object(forKey: factorKey) as? Double
            return CushionReflectionSolver.clampFactor(Float(stored ?? 1.0))
        }
        set { UserDefaults.standard.set(Double(CushionReflectionSolver.clampFactor(newValue)), forKey: factorKey) }
    }

    /// 求解实际使用的因子：真实模式取 `factor`，否则 1.0（理想）。
    static var effectiveFactor: Float { realMode ? factor : 1.0 }
}
