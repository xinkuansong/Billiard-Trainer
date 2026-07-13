//
//  BreakSimulator.swift
//  QiuJi
//
//  P17「球形生成器」核心：把一副 `Rack` 用真实物理引擎**开球**（livesim），产出散开后的
//  归一化 `BoardSnapshot` 供编辑器消费 + 回放轨迹供动画（ADR-P17-01）。
//
//  WYSIWYG（用户拍板）：不做「可玩性」筛选/重摆，所见即所得；废局（母球进袋 / 8 号落袋）
//  以 flag 上报由调用方决定是否「换一局」，引擎不自动重开。
//
//  引擎路径与 `BreakRackPhysicsTests` 已验证一致：`EventDrivenEngine` 直跑、母球瞄 −X 砸向
//  球堆顶角、`highFidelityBounds` 开、`maxEvents` 给足头寸（15 球开球实测仅 ~140 事件，
//  默认 8000 为安全上限，断言 `settled` 守住「未被截断」）。
//

import Foundation
import SceneKit

/// 一记开球的结果。
struct BreakResult {
    /// 散开后的归一化桌面（母球若未刮 + 全部未落袋目标球）。
    let board: BoardSnapshot
    /// 全程逐帧轨迹（球名 = 在桌键），供 UI 开球动画回放。
    let recorder: TrajectoryRecorder
    /// 落袋球的在桌键（含母球 scratch），按键排序。
    let pocketed: [String]
    /// 母球是否进袋（刮杆）——废局信号之一。
    let cueScratched: Bool
    /// 中八专用：8 号是否在开球时落袋（按规则需重开）——废局信号之一。
    let eightOnBreak: Bool
    /// 是否完全停稳（未被 `maxEvents` 截断）。`false` 时 board 含残余运动 = 脏数据，应判失败。
    let settled: Bool
    let surfaceY: Float
}

enum BreakSimulator {

    /// 开一杆球。
    /// - Parameters:
    ///   - rack: 摆好的球架（`RackLayout.make`）。
    ///   - cuePosition: 母球在开球区的世界坐标；nil = 用球架默认开球点（正中）。
    ///   - aimDirection: 开球瞄准方向（XZ 单位向量）；nil = **自动锁顶球**（指向球堆顶角球心）。
    ///     G18（问题集合 v5·V6）：开放瞄准后由 `BreakFlowRunner` 传入用户调整过的方向。
    ///   - power: 杆头速度 (m/s)。
    ///   - spinX/spinY: 打点（接触点偏移/R）。
    ///   - maxEvents/maxTime: 模拟预算；默认给足（15 球开球实测远未触顶）。
    static func breakShot(rack: Rack,
                          cuePosition: SCNVector3? = nil,
                          aimDirection: SCNVector3? = nil,
                          power: Float,
                          spinX: Float = 0,
                          spinY: Float = 0,
                          maxEvents: Int = 8000,
                          maxTime: Float = 30) -> BreakResult {
        let cuePos = cuePosition ?? rack.cue
        let strike = CueBallStrike.executeStrike(
            aimDirection: aimDirection ?? aimAtApex(rack: rack, from: cuePos),
            velocity: power, spinX: spinX, spinY: spinY)

        let engine = EventDrivenEngine(
            tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: rack.surfaceY))
        engine.setBall(BallState(position: cuePos, velocity: strike.velocity,
                                 angularVelocity: strike.angularVelocity,
                                 state: .sliding, name: PositionPlayBall.cueKey))
        for b in rack.balls {
            engine.setBall(BallState(position: b.position, velocity: SCNVector3Zero,
                                     angularVelocity: SCNVector3Zero,
                                     state: .stationary, name: b.key))
        }
        engine.simulate(maxEvents: maxEvents, maxTime: maxTime, highFidelityBounds: true)
        // #4：停稳后偶发两球轻微穿插——输出可编辑摆位前做一次几何重叠清理。
        engine.resolveRestingOverlaps()

        var onTable: [String: CanvasPoint] = [:]
        var pocketed: [String] = []
        var cueScratched = false
        var eightOnBreak = false
        var maxAliveSpeed: Float = 0

        for b in engine.getAllBalls() {
            if b.state == .pocketed {
                pocketed.append(b.name)
                if b.name == PositionPlayBall.cueKey { cueScratched = true }
                if b.name == "_8" { eightOnBreak = true }
                continue
            }
            let speed = sqrtf(b.velocity.x * b.velocity.x + b.velocity.z * b.velocity.z)
            maxAliveSpeed = max(maxAliveSpeed, speed)
            let n = AngleSceneCalculator.sceneToNormalized(position: b.position)
            onTable[b.name] = CanvasPoint(x: Double(n.x), y: Double(n.y))
        }

        return BreakResult(
            board: BoardSnapshot(onTable: onTable),
            recorder: engine.getTrajectoryRecorder(),
            pocketed: pocketed.sorted(),
            cueScratched: cueScratched,
            eightOnBreak: rack.game == .chineseEightBall && eightOnBreak,
            settled: maxAliveSpeed < 0.3,
            surfaceY: rack.surfaceY)
    }

    /// 锁顶球瞄准方向（XZ 平面单位向量）：母球指向球堆**顶角球**（最靠近母球一侧、x 最大者）
    /// 的球心。母球居中时退化为标准的 −X 正中开球；母球偏移时自动转向顶角，制造非正中开球角度。
    static func aimAtApex(rack: Rack, from cuePos: SCNVector3) -> SCNVector3 {
        let apex = rack.balls.max { $0.position.x < $1.position.x }?.position
            ?? SCNVector3(cuePos.x - 1, cuePos.y, cuePos.z)
        let dx = apex.x - cuePos.x
        let dz = apex.z - cuePos.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 1e-5 else { return SCNVector3(-1, 0, 0) }
        return SCNVector3(dx / len, 0, dz / len)
    }
}
