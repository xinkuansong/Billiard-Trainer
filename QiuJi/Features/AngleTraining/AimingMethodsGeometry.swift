import CoreGraphics
import Foundation

/// 「瞄准方法」页几何唯一真源（v11.2 §2.1 勘误口径，FL-026 返工 r1）。
///
/// 记号（世界台面米坐标，X–Z 水平面，+X 右，屏上 = −Z）：
/// - T 目标球心、P 袋口、n = unit(P−T) 进球方向
/// - G = T − 2R·n 假想球心、C = G − L·u(θ) 母球心、θ 切角
/// - 接触点对：Pt = T − R·n（目标球背袋点）、Pc = C + R·n（母球对应点）
/// - Q = (G+T)/2 = Pt：碰撞瞬间两球切点
///
/// 核心恒等式（数值草稿 `build/y1-evidence/y1r1-geometry-draft-selfrun.txt`）：
/// **Pc→Pt ≡ G − C**（同向等长）；碰撞时两球心关于 Q 点对称（2Q − T = G）。
///
/// 管道口径：瞄准线与进球线各扩成半径 = 球半径 R 的管道（管宽 = 球径）；
/// 试瞄管轴 = 段 [C, C+L·u(φ)]，进球管轴 = 射线 [T, n)；两轴最近距 D 对比 2R
/// 判定相交（太厚）/ 相切（正确）/ 相离。相离在极厚脱靶区也会出现（试瞄管
/// 从目标球另一侧穿过后远离），故相离按 φ 与 θ 的大小消歧为太厚/太薄。
struct AimingMethodsGeometry {
    static let ballRadius = CGFloat(AngleSceneCalculator.ballRadius)

    // MARK: - Scene

    struct Scene {
        let target: CGPoint        // T
        let pocket: CGPoint        // P
        let potDir: CGPoint        // n
        let ghost: CGPoint         // G
        let cue: CGPoint           // C
        let aimDir: CGPoint        // u(θ)
        let contact: CGPoint       // Q = (G+T)/2
        let targetContact: CGPoint // Pt
        let cueContact: CGPoint    // Pc
        let cutAngleDeg: CGFloat
        let cueDistance: CGFloat   // L = |CG|
    }

    /// 标准教学球形：目标球 (0.45, −0.12) 瞄右上角袋，母球距假想球 L（默认 0.42m）。
    static func scene(cutAngleDeg: CGFloat,
                      cueDistance: CGFloat = 0.42,
                      target: CGPoint = CGPoint(x: 0.45, y: -0.12),
                      pocket pocketOverride: CGPoint? = nil) -> Scene {
        let r = ballRadius
        let pocket: CGPoint
        if let p = pocketOverride {
            pocket = p
        } else {
            let p3 = AngleSceneCalculator.pocketMarkerPositions(surfaceY: 0)[1] // 右上
            pocket = CGPoint(x: CGFloat(p3.x), y: CGFloat(p3.z))
        }
        let n = unit(from: target, to: pocket)
        let ghost = CGPoint(x: target.x - 2 * r * n.x, y: target.y - 2 * r * n.y)
        let u = rotate(n, byDegrees: cutAngleDeg)
        let cue = CGPoint(x: ghost.x - u.x * cueDistance, y: ghost.y - u.y * cueDistance)
        return Scene(target: target,
                     pocket: pocket,
                     potDir: n,
                     ghost: ghost,
                     cue: cue,
                     aimDir: u,
                     contact: CGPoint(x: (ghost.x + target.x) / 2, y: (ghost.y + target.y) / 2),
                     targetContact: CGPoint(x: target.x - r * n.x, y: target.y - r * n.y),
                     cueContact: CGPoint(x: cue.x + r * n.x, y: cue.y + r * n.y),
                     cutAngleDeg: cutAngleDeg,
                     cueDistance: cueDistance)
    }

    /// 试瞄方向 u(φ)：进球方向 n 旋 φ（与 θ 同一旋向）。
    static func trialAimDir(scene: Scene, trialAngleDeg: CGFloat) -> CGPoint {
        rotate(scene.potDir, byDegrees: trialAngleDeg)
    }

    // MARK: - Pipe tangency

    enum PipeVerdict: Equatable {
        case tooThick   // 相交（或极厚区脱靶相离）
        case tangent    // 外切（φ = θ）
        case tooThin    // 相离（薄侧）
    }

    /// 两管道轴最近距：试瞄管轴 = 段 [C, C+L·u(φ)]，进球管轴 = 射线 [T, n)。
    static func pipeAxesDistance(scene: Scene, trialAngleDeg: CGFloat) -> CGFloat {
        let u = trialAimDir(scene: scene, trialAngleDeg: trialAngleDeg)
        let end = CGPoint(x: scene.cue.x + u.x * scene.cueDistance,
                          y: scene.cue.y + u.y * scene.cueDistance)
        return segmentRayMinDistance(segA: scene.cue, segB: end,
                                     rayOrigin: scene.target, rayDir: scene.potDir)
    }

    /// 三态判定（数值草稿 P3）：|D−2R|≤tol 相切；D<2R 相交=太厚；
    /// D>2R 相离——薄侧为太薄，但极厚脱靶区 D 也会回升 >2R，按 φ<θ 消歧为太厚。
    static func pipeVerdict(scene: Scene, trialAngleDeg: CGFloat,
                            tolerance: CGFloat = 1e-6) -> (distance: CGFloat, verdict: PipeVerdict) {
        let d = pipeAxesDistance(scene: scene, trialAngleDeg: trialAngleDeg)
        let twoR = 2 * ballRadius
        if abs(d - twoR) <= tolerance { return (d, .tangent) }
        if d < twoR { return (d, .tooThick) }
        return (d, trialAngleDeg < scene.cutAngleDeg ? .tooThick : .tooThin)
    }

    // MARK: - Classic ball thickness (overlap ↔ θ)

    /// 经典球厚度：`overlap = 1 − sin(θ°)`，与 `NamedBallThickness` 恒等式一致。
    /// θ 钳到 [0°, 90°]；坐标系无关（标量恒等式）。
    static func classicOverlap(cutAngleDegrees: Double) -> Double {
        let clamped = min(90, max(0, cutAngleDegrees))
        return 1 - sin(clamped * .pi / 180)
    }

    /// 瞄准线横移（球半径单位）：`d/R = 2·sin(θ) = 2·(1 − overlap)`。
    static func classicDOverR(cutAngleDegrees: Double) -> Double {
        2 * (1 - classicOverlap(cutAngleDegrees: cutAngleDegrees))
    }

    // MARK: - Contact-point method

    /// 「心对点」误导角：球心直指 Pt 的方向与真瞄准线 C→G 的夹角（度）。
    static func misleadAngleDeg(scene: Scene) -> CGFloat {
        let v1 = CGPoint(x: scene.targetContact.x - scene.cue.x,
                         y: scene.targetContact.y - scene.cue.y)
        let v2 = CGPoint(x: scene.ghost.x - scene.cue.x,
                         y: scene.ghost.y - scene.cue.y)
        let cosA = dot(v1, v2) / max(length(v1) * length(v2), 1e-12)
        return acos(min(1, max(-1, cosA))) * 180 / .pi
    }

    /// 碰合动画进度 t ∈ [0,1] 时的母球心（C → G 线性平移）。
    static func mergedCueCenter(scene: Scene, progress: CGFloat) -> CGPoint {
        CGPoint(x: scene.cue.x + (scene.ghost.x - scene.cue.x) * progress,
                y: scene.cue.y + (scene.ghost.y - scene.cue.y) * progress)
    }

    /// 动画中母球对应接触点 Pc(t) = 母球心(t) + R·n。
    static func movingCueContact(scene: Scene, progress: CGFloat) -> CGPoint {
        let c = mergedCueCenter(scene: scene, progress: progress)
        return CGPoint(x: c.x + ballRadius * scene.potDir.x,
                       y: c.y + ballRadius * scene.potDir.y)
    }

    // MARK: - Primitives

    /// 2D 段-射线最近距（草稿同源算法：内部相交判 0，否则端点/起点三候选取小）。
    static func segmentRayMinDistance(segA: CGPoint, segB: CGPoint,
                                      rayOrigin: CGPoint, rayDir: CGPoint) -> CGFloat {
        let ab = CGPoint(x: segB.x - segA.x, y: segB.y - segA.y)
        let denom = ab.x * rayDir.y - ab.y * rayDir.x
        if abs(denom) > 1e-15 {
            let ao = CGPoint(x: rayOrigin.x - segA.x, y: rayOrigin.y - segA.y)
            let t = (ao.x * rayDir.y - ao.y * rayDir.x) / denom
            let px = segA.x + t * ab.x - rayOrigin.x
            let py = segA.y + t * ab.y - rayOrigin.y
            let s = abs(rayDir.x) > abs(rayDir.y) ? px / rayDir.x : py / rayDir.y
            if t >= 0, t <= 1, s >= 0 { return 0 }
        }
        return min(pointToRayDistance(segA, origin: rayOrigin, dir: rayDir),
                   min(pointToRayDistance(segB, origin: rayOrigin, dir: rayDir),
                       pointToSegmentDistance(rayOrigin, a: segA, b: segB)))
    }

    static func pointToRayDistance(_ p: CGPoint, origin: CGPoint, dir: CGPoint) -> CGFloat {
        let s = max(0, dot(CGPoint(x: p.x - origin.x, y: p.y - origin.y), dir) / dot(dir, dir))
        return hypot(p.x - (origin.x + dir.x * s), p.y - (origin.y + dir.y * s))
    }

    static func pointToSegmentDistance(_ p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let len2 = dot(ab, ab)
        let t = len2 < 1e-15 ? 0 : min(1, max(0, dot(CGPoint(x: p.x - a.x, y: p.y - a.y), ab) / len2))
        return hypot(p.x - (a.x + ab.x * t), p.y - (a.y + ab.y * t))
    }

    static func rotate(_ v: CGPoint, byDegrees deg: CGFloat) -> CGPoint {
        let a = deg * .pi / 180
        return CGPoint(x: v.x * cos(a) - v.y * sin(a),
                       y: v.x * sin(a) + v.y * cos(a))
    }

    static func unit(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = hypot(dx, dy)
        guard len > 1e-9 else { return .zero }
        return CGPoint(x: dx / len, y: dy / len)
    }

    private static func dot(_ a: CGPoint, _ b: CGPoint) -> CGFloat { a.x * b.x + a.y * b.y }
    private static func length(_ v: CGPoint) -> CGFloat { hypot(v.x, v.y) }
}
