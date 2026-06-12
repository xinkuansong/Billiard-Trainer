import Foundation
import SceneKit

/// 走位序列单杆离线求解（ADR-P11-03）：把「前快照 + 作者意图」翻译成 `ShotPredictor` 调用。
/// 序列播放器、视频导出器共用此入口（编排台实时路径持有场景节点，单独组装）。
///
/// 坐标契约：快照为归一化系（x∈[0,1]、y∈[0,0.5]，`AngleSceneCalculator.sceneToNormalized` 真源：
/// canvasX 增 = sceneX 增，canvasY 增 = sceneZ 增；因 innerLength = 2×innerWidth，方向向量
/// 在两系间为均匀缩放且符号保持）。
enum PositionPlayShotSolver {

    /// 求解一杆。袋口模式走 `ShotPredictor.predict`（闭环瞄准），自由模式走 `simulateFree`（直瞄）。
    /// 返回 nil = 快照/意图不完整（缺母球、缺目标球、袋口非法）。
    static func solve(before: BoardSnapshot, shot: PlannedShot, surfaceY: Float) -> ShotPrediction? {
        guard let cuePt = before.onTable[PositionPlayBall.cueKey] else { return nil }
        let cue = scenePoint(cuePt, surfaceY: surfaceY)

        if let aim = shot.freeAim {
            let balls: [ObstacleBall] = before.onTable.compactMap { key, pt in
                guard key != PositionPlayBall.cueKey else { return nil }
                return ObstacleBall(name: key, position: scenePoint(pt, surfaceY: surfaceY))
            }
            return ShotPredictor.simulateFree(
                cueBall: cue,
                aimDir: sceneDirection(fromCanvas: aim),
                velocity: Float(shot.velocity),
                spinX: Float(shot.spinX), spinY: Float(shot.spinY),
                surfaceY: surfaceY, balls: balls
            )
        }

        guard let targetPt = before.onTable[shot.targetKey],
              let pocketIndex = ShotIntent.pocketIndex(for: shot.pocket) else { return nil }
        let target = scenePoint(targetPt, surfaceY: surfaceY)
        let obstacles: [ObstacleBall] = before.onTable.compactMap { key, pt in
            guard key != PositionPlayBall.cueKey, key != shot.targetKey else { return nil }
            return ObstacleBall(name: key, position: scenePoint(pt, surfaceY: surfaceY))
        }
        let input = ShotInput(
            cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
            velocity: Float(shot.velocity), spinX: Float(shot.spinX), spinY: Float(shot.spinY),
            surfaceY: surfaceY, obstacles: obstacles
        )
        return ShotPredictor.predict(input)
    }

    /// 桌面球键 → 引擎球名（自由模式 `targetKey` 为空串，所有非母球保留原键名）。
    static func predName(boardKey: String, shot: PlannedShot) -> String {
        if boardKey == PositionPlayBall.cueKey { return ShotInput.cueBallName }
        if !shot.isFree, boardKey == shot.targetKey { return ShotInput.targetBallName }
        return boardKey
    }

    // MARK: - Pot-line extension (#8)

    /// 把进袋目标球的轨迹末端延伸到**袋口圆边缘**：
    /// 引擎对带速正对的进球会把球心吸到袋心（轨迹已达袋内，不动）；而慢速 settle / 擦 jaw 落袋
    /// 的轨迹会停在喉口附近，视觉上「进球线太短、提前消失」。此处沿「末点 → 袋心」方向补一段，
    /// 使线终点恰落在袋口圆（视觉标记圆）边缘——jaw / 袋弧碰撞由真实模拟轨迹自带，不在此修饰。
    static func extendPathToPocketRim(
        _ pts: [SCNVector3], pocketIndex: Int, surfaceY: Float
    ) -> [SCNVector3] {
        guard let last = pts.last else { return pts }
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        guard pocketIndex >= 0, pocketIndex < pockets.count else { return pts }
        let pc = pockets[pocketIndex]
        let rim = AngleSceneCalculator.pocketMarkerRadius(index: pocketIndex)
        let dx = pc.x - last.x, dz = pc.z - last.z
        let dist = sqrtf(dx * dx + dz * dz)
        // 末点已在袋口圆内（如落袋吸心到袋心）则无需延伸。
        guard dist > rim + 0.001 else { return pts }
        let ux = dx / dist, uz = dz / dist
        let end = SCNVector3(pc.x - ux * rim, last.y, pc.z - uz * rim)
        return pts + [end]
    }

    // MARK: - Coordinate bridging

    /// 归一化点 → 场景世界坐标（台面高度）。
    static func scenePoint(_ pt: CanvasPoint, surfaceY: Float) -> SCNVector3 {
        AngleSceneCalculator.normalizedToScene(point: CGPoint(x: pt.x, y: pt.y), surfaceY: surfaceY)
    }

    /// 归一化系方向 → 场景 XZ 单位方向（符号保持，均匀缩放 ⇒ 直接归一化即可）。
    static func sceneDirection(fromCanvas dir: CanvasPoint) -> SCNVector3 {
        let len = (dir.x * dir.x + dir.y * dir.y).squareRoot()
        guard len > 1e-9 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(Float(dir.x / len), 0, Float(dir.y / len))
    }

    /// 场景 XZ 方向 → 归一化系单位方向。
    static func canvasDirection(fromScene dir: SCNVector3) -> CanvasPoint {
        let len = sqrtf(dir.x * dir.x + dir.z * dir.z)
        guard len > 1e-9 else { return CanvasPoint(x: 1, y: 0) }
        return CanvasPoint(x: Double(dir.x / len), y: Double(dir.z / len))
    }
}
