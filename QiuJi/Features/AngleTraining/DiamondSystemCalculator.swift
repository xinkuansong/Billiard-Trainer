import Foundation
import SceneKit

/// General **bank / kick-shot solver** for the 反射解球器 page.
///
/// Pure-reflection model (no spin): the ball obeys *incidence = reflection* off each
/// rail. Given an arbitrary cue & target anywhere on the table, the solver finds
/// trajectories that bounce off `N` cushions (in some rail order) and arrive exactly at
/// the target, using the classic **mirror-unfolding** method.
///
/// Coordinate system mirrors `AngleSceneCalculator`:
/// - 长轴 X ∈ [-innerLength/2, +innerLength/2]
/// - 短轴 Z ∈ [-innerWidth/2, +innerWidth/2]
/// In the rotated 2D top-down view the long rails are the left/right (constant-Z) edges
/// and the short rails are the top/bottom (constant-X) edges.
enum DiamondSystemCalculator {

    // MARK: - Table geometry (shared with AngleSceneCalculator)

    static var innerLength: Float { AngleSceneCalculator.innerLength }
    static var innerWidth: Float { AngleSceneCalculator.innerWidth }
    static var halfL: Float { innerLength / 2 }
    static var halfW: Float { innerWidth / 2 }

    static let longRailDiamonds = 8
    static let shortRailDiamonds = 4

    static var railBallInset: Float { AngleSceneCalculator.ballRadius * 1.4 }

    /// Minimum incidence angle (degrees, measured from the rail surface) allowed at the
    /// **first** cushion. Shots that graze the first rail more shallowly than this are
    /// filtered out — they read as unrealistic / unplayable.
    static let minFirstCushionAngleDeg: Float = 15

    // MARK: - Rails

    /// The four cushions. `left`/`right` are constant-Z long rails; `far`/`near` are
    /// constant-X short rails.
    enum Rail: CaseIterable {
        case left   // Z = -halfW
        case right  // Z = +halfW
        case far    // X = -halfL
        case near   // X = +halfL

        var isLong: Bool { self == .left || self == .right }

        /// Short Chinese label for the rail (in screen terms of the rotated 2D view:
        /// long rails are left/right edges, short rails are top/bottom edges).
        var label: String {
            switch self {
            case .left: "左库"
            case .right: "右库"
            case .far: "底库"   // X = -halfL → screen bottom (screen-up = world +X)
            case .near: "顶库"  // X = +halfL → screen top
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

    /// Reflect a point across a rail's line.
    private static func reflect(_ p: SCNVector3, across rail: Rail) -> SCNVector3 {
        if rail.isLong {
            return SCNVector3(p.x, p.y, 2 * railCoord(rail) - p.z)
        } else {
            return SCNVector3(2 * railCoord(rail) - p.x, p.y, p.z)
        }
    }

    /// Intersect the segment `a → b` with a rail line. Returns the point and the
    /// parameter `t` along `a → b` (nil if parallel).
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

    /// Whether a rail-crossing point lies within the physical cushion segment.
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
        /// Polyline [cue, cushion1, …, cushionN, target]. 真实模式下为按缩小因子追迹的实际走位。
        let path: [SCNVector3]
        let length: Float
        /// 理想（入射角=反射角）对照路径；仅真实模式下非 nil，供绘制虚线对照。
        let idealPath: [SCNVector3]?

        /// e.g. "顶库 → 左库 → 底库".
        var railSequenceText: String {
            rails.map(\.label).joined(separator: " → ")
        }
    }

    /// All valid pure-reflection trajectories from `cue` to `target` using 1…`maxCushions`
    /// cushions, sorted by (cushions ascending, then path length ascending) and deduped.
    /// The first element is therefore the **minimum-cushion** (and shortest) solution.
    /// `realMode` = false → 理想镜面反射；true → 用真实物理引擎按 `power`（m/s 发力）模拟
    /// （`EngineCushionTracer`，含速度相关回弹与摩擦衰减，无需手动拟合）。
    static func solveAll(cue: SCNVector3, target: SCNVector3,
                         surfaceY: Float, realMode: Bool = false,
                         power: Float = CushionReflectionSettings.defaultPower,
                         maxCushions: Int = 5, limit: Int = 16) -> [Solution] {
        let y = surfaceY + AngleSceneCalculator.ballRadius
        let cuePt = SCNVector3(cue.x, y, cue.z)
        let targetPt = SCNVector3(target.x, y, target.z)

        // 先求理想（镜像展开）解集，路径与历史版本完全一致。
        var ideal: [Solution] = []
        for n in 1...max(1, maxCushions) {
            for seq in railSequences(length: n) {
                guard let path = solveSequence(cue: cuePt, target: targetPt, rails: seq, y: y) else { continue }
                let len = polylineLength(path)
                let sol = Solution(cushions: n, rails: seq, path: path, length: len, idealPath: nil)
                if !isDuplicate(sol, in: ideal) { ideal.append(sol) }
            }
        }
        ideal.sort { lhs, rhs in
            lhs.cushions != rhs.cushions ? lhs.cushions < rhs.cushions : lhs.length < rhs.length
        }

        guard realMode else {
            return Array(ideal.prefix(limit))
        }

        // 真实模式：对每条理想解的库序，以理想首段方向为种子、按 `power` 发力用真实物理引擎
        // 射击法追迹出实际走位；理想解作为对照。
        // 性能护栏：引擎射击较重（每条解需多次正向模拟），仅精修最有希望的前若干条理想解，
        // 且跳过 ≥4 库的深翻——深翻在真实摩擦下极少能保速穿点，精修收益低、耗时高。
        var real: [Solution] = []
        for sol in ideal.prefix(limit) where sol.cushions <= 3 {
            guard sol.path.count >= 2 else { continue }
            let descriptors = sol.rails.map(descriptor)
            let seed = SCNVector3(sol.path[1].x - sol.path[0].x, 0, sol.path[1].z - sol.path[0].z)
            guard let realPath = EngineCushionTracer.shoot(
                start: cuePt, target: targetPt, seedDir: seed,
                rails: descriptors, speed: power, y: y
            ) else { continue }
            guard firstCushionAngleOK(path: realPath, firstRail: sol.rails[0]) else { continue }
            let rsol = Solution(cushions: sol.cushions, rails: sol.rails,
                                path: realPath, length: polylineLength(realPath),
                                idealPath: sol.path)
            real.append(rsol)
        }
        real.sort { lhs, rhs in
            lhs.cushions != rhs.cushions ? lhs.cushions < rhs.cushions : lhs.length < rhs.length
        }
        return Array(real.prefix(limit))
    }

    // MARK: - Engine kick-solve seeds (W2，20260709 翻袋反射页重构方案 §2.1)

    /// 镜像展开种子路径（引擎 kick 反解第 0 层）：固定库序下母球 → 反弹点… → 目标球心的
    /// 纯几何折线。仅作为 `ShotPredictor` kick 反解的**方向种子**，不再直接上屏。
    static func kickSeedPath(
        cue: SCNVector3, target: SCNVector3, rails: [Rail], surfaceY: Float
    ) -> [SCNVector3]? {
        let y = surfaceY + AngleSceneCalculator.ballRadius
        let cuePt = SCNVector3(cue.x, y, cue.z)
        let targetPt = SCNVector3(target.x, y, target.z)
        return solveSequence(cue: cuePt, target: targetPt, rails: rails, y: y)
    }

    /// 全部合法库序候选（长度 1...maxCushions，相邻不相同不正对）。
    /// 引擎 kick 反解的多解枚举入口（W3 消费；W2 benchmark 用它构造「全枚举」口径）。
    static func candidateRailSequences(maxCushions: Int) -> [[Rail]] {
        var out: [[Rail]] = []
        for n in 1...max(1, maxCushions) {
            out.append(contentsOf: railSequences(length: n))
        }
        return out
    }

    /// Solve one fixed rail sequence by mirror unfolding. Returns [cue, P1…Pk, target]
    /// or nil if any cushion falls outside its rail segment.
    private static func solveSequence(cue: SCNVector3, target: SCNVector3,
                                      rails: [Rail], y: Float) -> [SCNVector3]? {
        let k = rails.count
        guard k >= 1 else { return nil }

        // images[i] = target reflected across rails[k-1], rails[k-2], …, rails[i].
        var images = [SCNVector3](repeating: target, count: k)
        var img = target
        for i in stride(from: k - 1, through: 0, by: -1) {
            img = reflect(img, across: rails[i])
            images[i] = img
        }

        let eps: Float = 1e-4
        var prev = cue
        var pts: [SCNVector3] = [cue]
        for i in 0..<k {
            guard let (p, t) = intersect(prev, images[i], rail: rails[i]) else { return nil }
            guard t > eps, t < 1 - eps else { return nil }
            guard onRailSegment(p, rail: rails[i]) else { return nil }
            let point = SCNVector3(p.x, y, p.z)
            // Reject degenerate zero-length hops (a bounce landing on the previous point).
            if horizontalDistance(point, prev) < AngleSceneCalculator.ballRadius * 0.5 { return nil }
            // Reject cushions that fall inside a pocket mouth — the ball would pot, not bank.
            if hitsPocket(point, surfaceY: y - AngleSceneCalculator.ballRadius) { return nil }
            pts.append(point)
            prev = point
        }
        // Final leg to the target must move forward off the last rail.
        if horizontalDistance(target, prev) < AngleSceneCalculator.ballRadius * 0.5 { return nil }
        pts.append(target)

        // Filter shallow grazing first-cushion shots.
        guard firstCushionAngleOK(path: pts, firstRail: rails[0]) else { return nil }
        return pts
    }

    /// Whether a rail-contact point falls within a pocket mouth (corner or side pocket).
    private static func hitsPocket(_ p: SCNVector3, surfaceY: Float) -> Bool {
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        for (i, pk) in pockets.enumerated() {
            let r = (i < 4 ? AngleSceneCalculator.cornerPocketRadius
                           : AngleSceneCalculator.middlePocketRadius) + AngleSceneCalculator.ballRadius
            if horizontalDistance(p, pk) < r { return true }
        }
        return false
    }

    /// First-cushion incidence angle (from the rail surface) must be ≥ the minimum.
    private static func firstCushionAngleOK(path: [SCNVector3], firstRail: Rail) -> Bool {
        guard path.count >= 2 else { return true }
        let dx0 = path[1].x - path[0].x
        let dz0 = path[1].z - path[0].z
        let len = sqrtf(dx0 * dx0 + dz0 * dz0)
        guard len > 1e-6 else { return false }
        let dx = abs(dx0 / len), dz = abs(dz0 / len)
        // Angle between the incoming direction and the rail's tangent line.
        let angle: Float = firstRail.isLong ? atan2(dz, dx) : atan2(dx, dz)
        return angle >= minFirstCushionAngleDeg * .pi / 180
    }

    /// Two rails are "opposite" when they face each other across the table
    /// (the two long rails, or the two short rails). Bouncing off opposite rails
    /// in succession makes the ball zig-zag straight back and forth — an
    /// unrealistic "N 字" path — so such transitions are disallowed.
    private static func areOpposite(_ a: Rail, _ b: Rail) -> Bool {
        (a == .left && b == .right) || (a == .right && b == .left) ||
        (a == .far && b == .near) || (a == .near && b == .far)
    }

    /// Rail sequences of a given length with no two consecutive rails equal or
    /// opposite (the opposite case would zig-zag back across the table).
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
            existing.path.count == sol.path.count &&
            zip(existing.path, sol.path).allSatisfy { horizontalDistance($0, $1) < 0.01 }
        }
    }

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

    // MARK: - Normalised long-axis parameter (for diamond label placement)

    static func longAxisU(x: Float) -> Float { clamp01((x + halfL) / innerLength) }
    static func x(forU u: Float) -> Float { -halfL + clamp01(u) * innerLength }
    static func x(forRailNumber n: Double) -> Float { x(forU: Float(n) / Float(longRailDiamonds)) }

    // MARK: - Diamond label overlay (rail reference grid)

    struct DiamondLabel {
        let text: String
        let position: SCNVector3
    }

    /// Numeric diamond labels for the two long rails (interior diamonds 1…7 only; the
    /// 0 / 8 corners are skipped so they don't collide with the corner pocket markers).
    static func diamondLabels(surfaceY: Float) -> [DiamondLabel] {
        let y = surfaceY + 0.004
        let inset: Float = 0.05
        var labels: [DiamondLabel] = []
        for n in 1..<longRailDiamonds {
            let lx = x(forRailNumber: Double(n))
            labels.append(DiamondLabel(text: "\(n)", position: SCNVector3(lx, y, -halfW + inset)))
            labels.append(DiamondLabel(text: "\(n)", position: SCNVector3(lx, y, halfW - inset)))
        }
        return labels
    }

    /// Diamond tick positions on the four rails (interior diamonds only).
    static func diamondTicks(surfaceY: Float) -> [SCNVector3] {
        let y = surfaceY + 0.003
        var ticks: [SCNVector3] = []
        for n in 1..<longRailDiamonds {
            let lx = x(forRailNumber: Double(n))
            ticks.append(SCNVector3(lx, y, -halfW))
            ticks.append(SCNVector3(lx, y, halfW))
        }
        for n in 1..<shortRailDiamonds {
            let v = Float(n) / Float(shortRailDiamonds)
            let zPos = -halfW + v * innerWidth
            ticks.append(SCNVector3(-halfL, y, zPos))
            ticks.append(SCNVector3(halfL, y, zPos))
        }
        return ticks
    }

    // MARK: - Helpers

    private static func clamp01(_ v: Float) -> Float { min(1, max(0, v)) }
}
