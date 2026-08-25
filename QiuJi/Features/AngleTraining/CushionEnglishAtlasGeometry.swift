import Foundation
import SceneKit
import UIKit

/// 「加塞吃库图谱」页几何与轨迹切片真源（v20 W1）。
///
/// 坐标契约（与 `.kiro/steering/table-geometry.md` 对齐；动代码前已按
/// `geometry-spatial-reasoning` 钉死）：
/// - SceneKit 世界系；水平面 **X–Z**，**Y 朝上**；单位米
/// - +X = 右端，+Z = 顶视图上方；台面中心 (0, 0.80, 0)
/// - `spinX` 正 = **左塞**，负 = 右塞；`spinY` 正 = **高杆**，负 = **低杆**
///   （接触点偏移/R，与 `BTSpinPad` 同一契约）
/// - 打滑圆：√(spinX² + spinY²) ≤ `CuePhysics.miscueLimitFraction`（0.5R）
/// - 选定高低杆后，左右塞上下界 = 该 `spinY` 处打滑圆的水平弦半长
///   `allowedSpinXLimit = √(L² − spinY²)`；8 档在 [+limit, −limit] 均匀采样
/// - 挤偏补偿（E3 / §七）：`α = CueBallStrike.squirtAngle(a: spinX)`，
///   `aim' = geometricAim.rotatedY(+α)`，使
///   `CueBallStrike.actualDirection(aim', spinX) ≈ geometricAim`
/// - 轨迹切片（E2 / D-v20-2）：碰目标球后母球**首个** `.ballCushion`
///   → 下一 `.ballCushion`；无二库则固定弧长 **0.40 m**（或至停点取短者）
///
/// 页内 8 色轨迹豁免线语言 v2「线色=档位身份」（左右塞轴；仿 Y3 `trackColors`）。
enum CushionEnglishAtlasGeometry {

    /// 横向采样档数（纯左塞 → 纯右塞）。
    static let sampleCount = 8

    /// 无二库时库后切片的固定弧长上限（米）。
    static let postCushionArcLimit: Float = 0.40

    /// 给定高低杆，打滑圆上剩余的左右塞幅值（弦半长）。
    /// `|spinY| ≥ L` 时为 0（满高/满低无加塞余地）。
    static func allowedSpinXLimit(
        spinY: Float,
        miscueLimit: Float = CuePhysics.miscueLimitFraction
    ) -> Float {
        let y = min(abs(spinY), miscueLimit)
        let inner = miscueLimit * miscueLimit - y * y
        return inner > 0 ? sqrt(inner) : 0
    }

    /// spinX 在该 `spinY` 的允许弦上均匀 8 档（端点含弦端，即打滑圆上）。
    /// `spinY == 0` 时退化为 [+miscueLimit, −miscueLimit]（历史中杆默认）。
    /// 顺序：左塞（正）→ 右塞（负），与左缘迷你盘「左→右」语义一致。
    static func spinXLevels(
        spinY: Float = 0,
        miscueLimit: Float = CuePhysics.miscueLimitFraction,
        count: Int = sampleCount
    ) -> [Float] {
        precondition(count >= 2)
        let hi = allowedSpinXLimit(spinY: spinY, miscueLimit: miscueLimit)
        if hi < 1e-6 {
            return Array(repeating: 0, count: count)
        }
        let lo = -hi
        let step = (hi - lo) / Float(count - 1)
        return (0..<count).map { hi - Float($0) * step }
    }

    /// 页内专用 8 色板（左塞暖 → 右塞冷）。**仅本页**；不改全局 `TrajectoryStyle`。
    /// 语义：索引 0 = 最左塞（+miscue），索引 7 = 最右塞（−miscue）。
    static let trackColors: [UIColor] = [
        UIColor(red: 0.95, green: 0.28, blue: 0.22, alpha: 1), // 纯左塞
        UIColor(red: 0.96, green: 0.48, blue: 0.18, alpha: 1),
        UIColor(red: 0.95, green: 0.72, blue: 0.20, alpha: 1),
        UIColor(red: 0.55, green: 0.82, blue: 0.30, alpha: 1),
        UIColor(red: 0.28, green: 0.78, blue: 0.62, alpha: 1),
        UIColor(red: 0.22, green: 0.62, blue: 0.90, alpha: 1),
        UIColor(red: 0.32, green: 0.42, blue: 0.92, alpha: 1),
        UIColor(red: 0.48, green: 0.30, blue: 0.88, alpha: 1), // 纯右塞
    ]

    static func trackColor(at index: Int) -> UIColor {
        trackColors[min(max(index, 0), trackColors.count - 1)]
    }

    // MARK: - Squirt compensation (E3)

    /// 挤偏逆补偿瞄准：使实际出发方向对齐同一几何切角。
    /// `aim' = geometric.rotatedY(+squirtAngle(spinX))`。
    static func aimDirCompensatingSquirt(geometric: SCNVector3, spinX: Float) -> SCNVector3 {
        let alpha = CueBallStrike.squirtAngle(a: spinX)
        guard abs(alpha) > 1e-6 else { return geometric }
        return geometric.rotatedY(+alpha)
    }

    // MARK: - Default teaching scene (D-v20-3)

    /// 专用教学盘面：默认力度下 8 档左右塞皆「球-球后吃到长库」。
    /// 不复用 Y3 半球——该盘面在 1.5 m/s 中杆下碰后行程不足以稳定吃库。
    /// 盘面经 `simulateFree` 实测锁定（见 `build/v20-evidence/`）：
    /// 默认力度下首库贴 **+Z 上长库**（|Z|≈0.606 = halfW−R）。
    static func defaultTeachingScene() -> AimingMethodsGeometry.Scene {
        // 目标偏台心下方；右下角袋切角 ≈32°；中杆碰后母球实测上行吃上长库。
        AimingMethodsGeometry.scene(
            cutAngleDeg: 32,
            cueDistance: 0.36,
            target: CGPoint(x: 0.05, y: -0.30),
            pocket: CGPoint(x: 1.312, y: -0.677)
        )
    }

    /// SceneKit 球心 Y = surfaceY + R。
    static func sceneKitBallY(surfaceY: Float) -> Float {
        surfaceY + AngleSceneCalculator.ballRadius
    }

    // MARK: - Path slicing (E2 / D-v20-2)

    /// 首次球-球碰撞事件（按时间）。
    static func firstBallBallEvent(in events: [ShotEvent]) -> ShotEvent? {
        events.first {
            if case .ballBall = $0.kind { return true }
            return false
        }
    }

    /// 首次球-球之后，母球的首个吃库事件。
    static func firstCueCushionAfterBallBall(in events: [ShotEvent]) -> ShotEvent? {
        guard let bb = firstBallBallEvent(in: events) else { return nil }
        return events.first { e in
            guard e.time > bb.time else { return false }
            if case .ballCushion(let ball) = e.kind {
                return ball == ShotInput.cueBallName
            }
            return false
        }
    }

    /// 首库之后，母球的下一个吃库事件。
    static func secondCueCushionAfterFirst(
        in events: [ShotEvent],
        after firstCushion: ShotEvent
    ) -> ShotEvent? {
        events.first { e in
            guard e.time > firstCushion.time else { return false }
            if case .ballCushion(let ball) = e.kind {
                return ball == ShotInput.cueBallName
            }
            return false
        }
    }

    /// 库后出射切片：「碰后首个 ballCushion → 下一 ballCushion」；
    /// 无二库则自首库起沿折线取 `postCushionArcLimit`（0.40 m）或至停点取短者。
    /// 无首库时诚实降级为停点附近短弧（保证仍有线可画）；无球-球则空。
    static func pathAfterFirstCueCushion(_ pred: ShotPrediction) -> [SCNVector3] {
        // Require a prior ball-ball so the cushion is post-contact (D-v20-A).
        guard firstBallBallEvent(in: pred.events) != nil,
              pred.cuePath.count >= 2 else { return [] }

        guard let cushion1 = firstCueCushionAfterBallBall(in: pred.events) else {
            return degradedShortArcNearStop(pred)
        }

        let startPos: SCNVector3
        if let recorder = pred.recorder,
           let s = recorder.stateAt(ballName: ShotInput.cueBallName, time: cushion1.time) {
            startPos = s.position
        } else {
            return []
        }

        let startIdx = nearestIndex(in: pred.cuePath, to: startPos)
        let cushion2 = secondCueCushionAfterFirst(in: pred.events, after: cushion1)

        let endIdx: Int
        if let cushion2,
           let recorder = pred.recorder,
           let e = recorder.stateAt(ballName: ShotInput.cueBallName, time: cushion2.time) {
            endIdx = nearestIndex(in: pred.cuePath, to: e.position)
        } else {
            endIdx = endIndexByArcLimit(
                path: pred.cuePath,
                from: startIdx,
                arcLimit: postCushionArcLimit
            )
        }

        let lo = min(startIdx, endIdx)
        let hi = max(startIdx, endIdx)
        guard hi > lo else { return [] }
        return Array(pred.cuePath[lo...hi])
    }

    /// 无首库降级：停点前回溯一小段弧，保证有折线可画。
    private static func degradedShortArcNearStop(_ pred: ShotPrediction) -> [SCNVector3] {
        let path = pred.cuePath
        guard path.count >= 2 else { return [] }
        let endIdx = path.count - 1
        // Walk backward up to postCushionArcLimit/2 so the stub is visible but short.
        let limit = postCushionArcLimit * 0.5
        var traveled: Float = 0
        var startIdx = endIdx
        var i = endIdx
        while i > 0 {
            let p0 = path[i - 1], p1 = path[i]
            traveled += hypotf(p1.x - p0.x, p1.z - p0.z)
            startIdx = i - 1
            if traveled >= limit { break }
            i -= 1
        }
        guard endIdx > startIdx else { return [] }
        return Array(path[startIdx...endIdx])
    }

    /// 自 `from` 沿折线累积弧长至 `arcLimit`（或折线末端）的终点索引。
    static func endIndexByArcLimit(
        path: [SCNVector3],
        from startIdx: Int,
        arcLimit: Float
    ) -> Int {
        guard startIdx < path.count - 1 else { return startIdx }
        var traveled: Float = 0
        var i = startIdx
        while i < path.count - 1 {
            let p0 = path[i], p1 = path[i + 1]
            traveled += hypotf(p1.x - p0.x, p1.z - p0.z)
            i += 1
            if traveled >= arcLimit { break }
        }
        return i
    }

    /// 库后首段水平单位方向（用于开/闭手性草稿）。
    /// 沿折线累积约 `minArc` 米后再取方向，避免 120Hz 首采样噪声主导。
    static func postCushionInitialDir(_ path: [SCNVector3], minArc: Float = 0.04) -> SCNVector3? {
        guard path.count >= 2 else { return nil }
        let a = path[0]
        var traveled: Float = 0
        var b = path[1]
        for i in 1..<path.count {
            let p0 = path[i - 1], p1 = path[i]
            let seg = hypotf(p1.x - p0.x, p1.z - p0.z)
            traveled += seg
            b = p1
            if traveled >= minArc { break }
        }
        let dx = b.x - a.x, dz = b.z - a.z
        let len = hypotf(dx, dz)
        guard len > 1e-5 else { return nil }
        return SCNVector3(dx / len, 0, dz / len)
    }

    /// XZ 折线弧长。
    static func pathArcLengthXZ(_ path: [SCNVector3]) -> Float {
        guard path.count >= 2 else { return 0 }
        var sum: Float = 0
        for i in 1..<path.count {
            sum += hypotf(path[i].x - path[i - 1].x, path[i].z - path[i - 1].z)
        }
        return sum
    }

    /// 是否贴近长库（|Z| 接近 playfield 半宽 − R）。
    static func isNearLongCushion(_ position: SCNVector3, tol: Float = 0.04) -> Bool {
        let halfW = Float(TablePhysics.innerWidth) / 2
        let r = BallPhysics.radius
        let railZ = halfW - r
        return abs(abs(position.z) - railZ) < tol
    }

    // MARK: - Helpers

    static func nearestIndex(in path: [SCNVector3], to point: SCNVector3) -> Int {
        var best = 0
        var bestDist = Float.greatestFiniteMagnitude
        for (i, p) in path.enumerated() {
            let dx = p.x - point.x, dz = p.z - point.z
            let d = dx * dx + dz * dz
            if d < bestDist { bestDist = d; best = i }
        }
        return best
    }

    static func nearestPoint(on path: [SCNVector3], to point: SCNVector3) -> SCNVector3 {
        path[nearestIndex(in: path, to: point)]
    }

    /// 两水平单位方向的夹角（度，[0, 180]）。
    static func angleDegBetween(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let la = hypotf(a.x, a.z), lb = hypotf(b.x, b.z)
        guard la > 1e-8, lb > 1e-8 else { return 180 }
        let dot = max(-1, min(1, (a.x * b.x + a.z * b.z) / (la * lb)))
        return acosf(dot) * 180 / .pi
    }

    /// 水平方向从 `from` 到 `to` 的有符号偏转角（度，CCW 为正，俯视 +Y）。
    /// atan2(z, x) 为 SceneKit 水平角契约。
    static func signedYawDeg(from: SCNVector3, to: SCNVector3) -> Float {
        let a0 = atan2f(from.z, from.x)
        let a1 = atan2f(to.z, to.x)
        var d = a1 - a0
        while d > .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        return d * 180 / .pi
    }
}
