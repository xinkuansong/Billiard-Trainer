import Foundation
import SceneKit
import UIKit

/// 「分离角图谱」页几何与轨迹切片真源（v11 Y3）。
///
/// 坐标契约（与 `.kiro/steering/table-geometry.md` 对齐）：
/// - SceneKit 世界系；水平面 **X–Z**，**Y 朝上**；单位米
/// - +X = 右端，+Z = 顶视图上方
/// - spinY 正 = 高杆，负 = 低杆；上下界 = `CuePhysics.miscueLimitFraction`
/// - 轨迹切片：首次 `.ballBall` → 其后母球首个 `.ballCushion`；
///   碰后未吃库时降级为「碰撞点 → 停球点」（低力度纯低杆回拖停球场景）
///
/// 页内 8 色轨迹豁免线语言 v2「线色=球的身份」（见 DR-025）。
enum SeparationAngleAtlasGeometry {

    /// 纵向采样档数（纯高杆 → 纯低杆）。
    static let sampleCount = 8

    /// spinY 在 [+miscueLimit, −miscueLimit] 均匀 8 档（端点含打滑极限）。
    static func spinYLevels(
        miscueLimit: Float = CuePhysics.miscueLimitFraction,
        count: Int = sampleCount
    ) -> [Float] {
        precondition(count >= 2)
        let hi = miscueLimit
        let lo = -miscueLimit
        let step = (hi - lo) / Float(count - 1)
        return (0..<count).map { hi - Float($0) * step }
    }

    /// 页内专用 8 色板（高杆暖 → 低杆冷）。**仅本页**；不改全局 `TrajectoryStyle`。
    static let trackColors: [UIColor] = [
        UIColor(red: 0.95, green: 0.28, blue: 0.22, alpha: 1), // 纯高杆
        UIColor(red: 0.96, green: 0.48, blue: 0.18, alpha: 1),
        UIColor(red: 0.95, green: 0.72, blue: 0.20, alpha: 1),
        UIColor(red: 0.55, green: 0.82, blue: 0.30, alpha: 1),
        UIColor(red: 0.28, green: 0.78, blue: 0.62, alpha: 1),
        UIColor(red: 0.22, green: 0.62, blue: 0.90, alpha: 1),
        UIColor(red: 0.32, green: 0.42, blue: 0.92, alpha: 1),
        UIColor(red: 0.48, green: 0.30, blue: 0.88, alpha: 1), // 纯低杆
    ]

    static func trackColor(at index: Int) -> UIColor {
        trackColors[min(max(index, 0), trackColors.count - 1)]
    }

    // MARK: - Default scene (~30° half-ball)

    /// 默认教学球形：复用 `AimingMethodsGeometry` 半球 θ≈30°。
    static func defaultTeachingScene() -> AimingMethodsGeometry.Scene {
        AimingMethodsGeometry.scene(
            cutAngleDeg: CGFloat(AngleSceneCalculator.halfBall.cutAngleDegrees))
    }

    /// SceneKit 球心 Y = surfaceY + R。
    static func sceneKitBallY(surfaceY: Float) -> Float {
        surfaceY + AngleSceneCalculator.ballRadius
    }

    // MARK: - Path slicing

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

    /// 碰后轨迹切片：「首次球-球碰撞点 → 其后母球首个 ballCushion」。
    /// 碰后未吃库（如低力度纯低杆回拖后停球）时降级为「碰撞点 → 停球点」，
    /// 保证 8 档轨迹在任何力度下都齐全（语义如实：碰后轨迹，未吃库者到停点）。
    /// 无球-球碰撞时返回空。
    static func pathAfterContactToFirstCueCushion(_ pred: ShotPrediction) -> [SCNVector3] {
        guard let bb = firstBallBallEvent(in: pred.events),
              pred.cuePath.count >= 2 else { return [] }

        let cushion = firstCueCushionAfterBallBall(in: pred.events)

        let startPos: SCNVector3
        var endIdx = pred.cuePath.count - 1 // 默认到停球点（折线末端）
        if let recorder = pred.recorder,
           let s = recorder.stateAt(ballName: ShotInput.cueBallName, time: bb.time) {
            startPos = s.position
            if let cushion,
               let e = recorder.stateAt(ballName: ShotInput.cueBallName, time: cushion.time) {
                endIdx = nearestIndex(in: pred.cuePath, to: e.position)
            }
        } else if let contact = pred.firstContact {
            // No recorder: keep post-contact tail (cushion endpoint unknown).
            startPos = contact
        } else {
            return []
        }

        let startIdx = nearestIndex(in: pred.cuePath, to: startPos)
        let lo = min(startIdx, endIdx)
        let hi = max(startIdx, endIdx)
        guard hi > lo else { return [] }
        return Array(pred.cuePath[lo...hi])
    }

    /// 碰后首段水平单位方向（用于 90° 法则断言）。
    /// 沿折线累积约 `minArc` 米后再取方向，避免 120Hz 首采样噪声主导。
    static func postContactInitialDir(_ path: [SCNVector3], minArc: Float = 0.04) -> SCNVector3? {
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

    /// 切线单位方向（stun / 90° 法则）：瞄准方向去掉沿连心线 n 的分量。
    static func tangentDir(aim: SCNVector3, lineOfCenters: SCNVector3) -> SCNVector3 {
        let nLen = sqrtf(lineOfCenters.x * lineOfCenters.x + lineOfCenters.z * lineOfCenters.z)
        guard nLen > 1e-6 else { return SCNVector3(0, 0, 1) }
        let nx = lineOfCenters.x / nLen, nz = lineOfCenters.z / nLen
        let aLen = sqrtf(aim.x * aim.x + aim.z * aim.z)
        guard aLen > 1e-6 else { return SCNVector3(-nz, 0, nx) }
        let ax = aim.x / aLen, az = aim.z / aLen
        let proj = ax * nx + az * nz
        var tx = ax - proj * nx, tz = az - proj * nz
        let tLen = sqrtf(tx * tx + tz * tz)
        if tLen < 1e-6 {
            return SCNVector3(-nz, 0, nx)
        }
        tx /= tLen; tz /= tLen
        return SCNVector3(tx, 0, tz)
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
}
