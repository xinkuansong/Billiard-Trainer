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

/// 翻袋 / 反射两页共享的**力度**设置（持久化于 UserDefaults，两页通用）。
/// W4 引擎反解后「理想/真实」概念消亡（`realMode` 已退役删除，20260709 翻袋反射页
/// 重构方案 §4.2）：力度是求解输入，改力度 → 重求解。
enum CushionReflectionSettings {
    /// Compatibility alias — raw value lives in `PracticeStorageKey` (C24).
    static var powerKey: String { PracticeStorageKey.cushionReflectionPower }

    /// 力度（m/s）合法区间与默认值。
    static let minPower: Float = 1.0
    static let maxPower: Float = 4.5
    static let defaultPower: Float = 2.4

    static func clampPower(_ p: Float) -> Float { min(maxPower, max(minPower, p)) }

    /// 力度（m/s，默认 `defaultPower`）：引擎反解的求解输入。
    static var power: Float {
        get {
            let stored = UserDefaults.standard.object(forKey: PracticeStorageKey.cushionReflectionPower) as? Double
            return clampPower(Float(stored ?? Double(defaultPower)))
        }
        set {
            UserDefaults.standard.set(
                Double(clampPower(newValue)),
                forKey: PracticeStorageKey.cushionReflectionPower
            )
        }
    }
}

/// **真实物理引擎反射追迹 / 射击法求解核心**（翻袋 #1 / 反射 #2）。
///
/// 取代 `CushionReflectionSolver` 的「常数缩小因子」近似（`tan θ_out = factor · tan θ_in`，
/// 用户需手动拟合）：本核心直接用事件驱动物理引擎 `EventDrivenEngine`（含 Han 2005 库边
/// 模型、速度相关回弹、滚动摩擦衰减）正向模拟单颗球的真实走位，并用**射击法**反解发球角，
/// 让球在按指定库序反弹后穿过目标点。真实翻库随**发力**变化（力大→接近镜面，力小→偏短），
/// 故求解需传入发力 `speed`（m/s）。
///
/// 坐标系与 `AngleSceneCalculator` 一致：长轴 X、短轴 Z、Y 为高度。
enum EngineCushionTracer {

    typealias Rail = CushionReflectionSolver.Rail

    static var R: Float { AngleSceneCalculator.ballRadius }
    static var halfL: Float { AngleSceneCalculator.innerLength / 2 }
    static var halfW: Float { AngleSceneCalculator.innerWidth / 2 }

    private static let ballName = "bank"

    // MARK: - Rail classification (from cushion normal)

    /// 把一次库边事件的法向量分类到四条**平库**之一（XZ）。法向指向台内：
    /// 长库（常 Z）法向沿 ±Z，短库（常 X）法向沿 ±X。jaw 弧 / 中袋 fillet 的斜法向返回 nil
    /// （说明球擦到袋口弧，不是干净的平库翻弹 → 该解的库序判定失败、被剔除）。
    static func railFor(normal n: SCNVector3) -> Rail? {
        let len = sqrtf(n.x * n.x + n.z * n.z)
        guard len > 1e-5 else { return nil }
        let ux = n.x / len, uz = n.z / len
        let purity: Float = 0.94   // 近轴对齐才算平库
        if abs(uz) >= purity && abs(ux) <= 0.30 {
            // 长库：法向 +Z = 左库(Z=-halfW)；-Z = 右库(Z=+halfW)。
            return Rail(isLong: true, coord: uz > 0 ? -halfW : halfW)
        }
        if abs(ux) >= purity && abs(uz) <= 0.30 {
            // 短库：法向 +X = 底库(X=-halfL)；-X = 顶库(X=+halfL)。
            return Rail(isLong: false, coord: ux > 0 ? -halfL : halfL)
        }
        return nil
    }

    // MARK: - Forward launch (real engine)

    /// 单球正向模拟结果。
    struct Launch {
        /// 折线 `[start, b1, …, bM, end]`：起点 + 各库反弹点 + 终点（自然停点或落袋点）。
        let polyline: [SCNVector3]
        /// 与反弹点一一对应的平库（长度 M）；遇到斜法向（jaw 弧）即在该点截断。
        let rails: [Rail]
        /// 是否落袋（true 时 `polyline.last` = 袋心）。
        let potted: Bool
        /// 落袋袋号（potted 时非 nil）。
        let pottedPocket: Int?
    }

    /// 从 `start` 以单位方向 `dir`、发力 `speed`（m/s）发射一颗**自然滚动**球，
    /// 返回其真实走位折线（按库边事件切分）。
    static func launch(start: SCNVector3, dir: SCNVector3, speed: Float, y: Float) -> Launch {
        let surfaceY = y - R
        let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
        let v = SCNVector3(dir.x * speed, 0, dir.z * speed)
        let up = SCNVector3(0, 1, 0)
        let w = up.cross(v) * (1.0 / BallPhysics.radius)   // 自然滚动角速度（无英式塞）
        engine.setBall(BallState(position: SCNVector3(start.x, y, start.z),
                                 velocity: v, angularVelocity: w,
                                 state: .rolling, name: ballName))
        engine.simulate(maxEvents: 400, maxTime: 30, highFidelityBounds: true)
        let rec = engine.getTrajectoryRecorder()

        var polyline: [SCNVector3] = [SCNVector3(start.x, y, start.z)]
        var rails: [Rail] = []
        for (e, t) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
            switch e {
            case let .ballCushion(_, _, normal):
                let p = rec.stateAt(ballName: ballName, time: t)?.position ?? polyline.last!
                polyline.append(SCNVector3(p.x, y, p.z))
                guard let rail = railFor(normal: normal) else {
                    // 擦到 jaw 弧 / fillet：截断（后续不再是干净平库翻弹）。
                    return Launch(polyline: polyline, rails: rails, potted: false, pottedPocket: nil)
                }
                rails.append(rail)
            case let .pocket(_, pid):
                let center = pocketCenter(pid, surfaceY: surfaceY) ?? polyline.last!
                polyline.append(SCNVector3(center.x, y, center.z))
                return Launch(polyline: polyline, rails: rails, potted: true,
                              pottedPocket: pocketIndex(pid))
            default:
                break
            }
        }
        // 自然停点。
        if let last = rec.framesByBallName[ballName]?.max(by: { $0.time < $1.time }) {
            polyline.append(SCNVector3(last.position.x, y, last.position.z))
        }
        return Launch(polyline: polyline, rails: rails, potted: false, pottedPocket: nil)
    }

    // MARK: - Shooting solve (one fixed rail sequence)

    /// 对固定库序 `rails`，以 `seedDir`（理想解的首段方向）为种子，用射击法反解发球角，
    /// 使球按该库序真实反弹后穿过 `target`。返回 `[start, b1…bK, target]`，无解返回 nil。
    ///
    /// - 评分：第 K 次（= rails.count）反弹后，球的离库方向到 `target` 的带符号垂距（叉积），
    ///   为零即对准。先以种子做 secant，失败再在 ±`maxOffsetDeg` 内粗扫找变号区间二分。
    /// - 物理校验：① 前 K 次反弹库恰为库序；② target 在末段前方且**球能真正抵达**（不中途停 /
    ///   不在抵达前撞到别的库 / 不中途落袋）。
    static func shoot(start: SCNVector3, target: SCNVector3, seedDir: SCNVector3,
                      rails: [Rail], speed: Float, y: Float) -> [SCNVector3]? {
        let k = rails.count
        guard k >= 1 else { return nil }
        let seedLen = sqrtf(seedDir.x * seedDir.x + seedDir.z * seedDir.z)
        guard seedLen > 1e-6 else { return nil }
        let seed = SCNVector3(seedDir.x / seedLen, 0, seedDir.z / seedLen)

        // signed miss（仅库序匹配时有定义）。
        func miss(_ offset: Float) -> Float? {
            let l = launch(start: start, dir: rotateY(seed, offset), speed: speed, y: y)
            guard l.rails.count >= k else { return nil }
            for i in 0..<k where !l.rails[i].matches(rails[i]) { return nil }
            // 第 K 次反弹点 = polyline[k]；其后一个顶点给出末段方向。
            guard l.polyline.count >= k + 2 else { return nil }
            let bK = l.polyline[k]
            let nxt = l.polyline[k + 1]
            let dx = nxt.x - bK.x, dz = nxt.z - bK.z
            let dl = sqrtf(dx * dx + dz * dz)
            guard dl > 1e-6 else { return nil }
            let ux = dx / dl, uz = dz / dl
            let tx = target.x - bK.x, tz = target.z - bK.z
            let tl = sqrtf(tx * tx + tz * tz)
            guard tl > 1e-6 else { return 0 }
            return ux * (tz / tl) - uz * (tx / tl)
        }

        let maxOffset: Float = 7 * .pi / 180

        // 1) 种子 secant（快路径：种子取自理想解，≤3 库时拓扑通常保持，几步即收敛）。
        if let root = secant(miss, x0: 0, x1: 1.0 * .pi / 180, bound: maxOffset),
           let path = build(start: start, target: target, seed: seed, offset: root,
                            rails: rails, speed: speed, y: y) {
            return path
        }
        // 2) 粗扫找变号区间 + 二分兜底（仅 secant 失败时）。第一个有效根即返回。
        let steps = 18
        var prevOff = -maxOffset
        var prevMiss = miss(prevOff)
        for i in 1...steps {
            let off = -maxOffset + (2 * maxOffset) * Float(i) / Float(steps)
            let m = miss(off)
            defer { prevOff = off; prevMiss = m }
            guard let a = prevMiss, let b = m, (a <= 0) != (b <= 0) else { continue }
            guard let root = bisect(miss, lo: prevOff, hi: off, fLo: a) else { continue }
            if let path = build(start: start, target: target, seed: seed, offset: root,
                                rails: rails, speed: speed, y: y) {
                return path
            }
        }
        return nil
    }

    /// 用收敛后的偏移重建并校验完整折线 `[start, b1…bK, target]`。
    private static func build(start: SCNVector3, target: SCNVector3, seed: SCNVector3,
                             offset: Float, rails: [Rail], speed: Float, y: Float) -> [SCNVector3]? {
        let k = rails.count
        let l = launch(start: start, dir: rotateY(seed, offset), speed: speed, y: y)
        guard l.rails.count >= k, l.polyline.count >= k + 2 else { return nil }
        for i in 0..<k where !l.rails[i].matches(rails[i]) { return nil }
        let bK = l.polyline[k]
        let nxt = l.polyline[k + 1]
        let dx = nxt.x - bK.x, dz = nxt.z - bK.z
        let legLen = sqrtf(dx * dx + dz * dz)
        guard legLen > 1e-6 else { return nil }
        let ux = dx / legLen, uz = dz / legLen
        let tx = target.x - bK.x, tz = target.z - bK.z
        let proj = tx * ux + tz * uz            // 末段方向上到 target 的投影
        let perp = abs(ux * tz - uz * tx)       // 垂距（对准误差）
        guard proj > R * 0.5 else { return nil }            // 必须前方、非退化
        guard perp < 0.014 else { return nil }              // 对准误差（米）
        // target 必须在抵达下一个顶点之前（否则球先撞别的库 / 先停 / 先落袋 → 走不到 target）。
        guard proj <= legLen + R else { return nil }
        var pts = Array(l.polyline.prefix(k + 1))           // [start, b1…bK]
        pts.append(SCNVector3(target.x, y, target.z))
        return pts
    }

    // MARK: - Root finding

    private static func secant(_ f: (Float) -> Float?, x0: Float, x1: Float, bound: Float) -> Float? {
        guard var f0 = f(x0) else { return nil }
        var a = x0, b = x1
        guard var f1 = f(b) else { return nil }
        for _ in 0..<12 {
            let denom = f1 - f0
            guard abs(denom) > 1e-9 else { break }
            let next = b - f1 * (b - a) / denom
            if next.isNaN || abs(next) > bound { return nil }
            guard let fn = f(next) else { return nil }
            a = b; f0 = f1; b = next; f1 = fn
            if abs(fn) < 1e-4 { return next }
        }
        return abs(f1) < 1e-3 ? b : nil
    }

    /// 二分：调用方已知 `lo` 处函数值符号（`fLo`），区间内单调变号。避免每轮重启引擎评估端点。
    private static func bisect(_ f: (Float) -> Float?, lo: Float, hi: Float, fLo: Float) -> Float? {
        var a = lo, b = hi
        let signA = fLo <= 0
        for _ in 0..<22 {
            let m = (a + b) / 2
            guard let fm = f(m) else { return nil }
            if (fm <= 0) == signA { a = m } else { b = m }
            if abs(b - a) < 2e-4 { break }
        }
        return (a + b) / 2
    }

    // MARK: - Helpers

    private static func rotateY(_ v: SCNVector3, _ angle: Float) -> SCNVector3 {
        let c = cosf(angle), s = sinf(angle)
        return SCNVector3(v.x * c - v.z * s, 0, v.x * s + v.z * c)
    }

    private static func pocketIndex(_ pid: String) -> Int? {
        guard let n = pid.split(separator: "_").last, let i = Int(n) else { return nil }
        return i
    }

    private static func pocketCenter(_ pid: String, surfaceY: Float) -> SCNVector3? {
        guard let i = pocketIndex(pid) else { return nil }
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        guard i >= 0, i < pockets.count else { return nil }
        return pockets[i]
    }
}
