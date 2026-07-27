//
//  TrajectoryPlayback.swift
//  BilliardTrainer
//
//  基于事件快照 + AnalyticalMotion 解析演进的轨迹回放器
//  物理积分路径零改动：在任意时刻 t 精确计算球的位置和旋转
//

import SceneKit
import simd

struct PlaybackBallState {
    let position: SCNVector3
    let velocity: SCNVector3
    let motionState: BallMotionState
    /// 引擎解析演进出的瞬时角速度（SceneKit 世界系，rad/s）。
    ///
    /// 球体姿态由它逐帧积分驱动（v17）：竖轴分量 `y` 即加塞自转，滑动段的转/滑不匹配
    /// （低杆倒旋、定杆不转）也只在这里体现。旧口径「位移弧长 / R + 轴 = ŷ × v̂」只能表达
    /// 纯滚动，会把加塞与倒旋全部丢弃。
    let angularVelocity: SCNVector3
    /// 瞬时运动方向（轨迹/入洞方向用；姿态不再依赖它）
    let moveDirection: SCNVector3
}

/// 球体自转积分（v17）：把世界系角速度 ω 在 Δt 内的转动表示成四元数增量。
///
/// 用法固定为**左乘**——`node.simdOrientation = delta * node.simdOrientation`——因为 ω 在
/// 世界系（球节点父节点即场景根，无旋转），世界系增量须作用在既有姿态之外侧。
/// 不对 ω 做任何视觉缩放（D-v17-3：如实渲染，需要看清用回放倍率慢放）。
enum BallSpinIntegrator {

    static func delta(angularVelocity: SCNVector3, dt: Float) -> simd_quatf {
        let w = simd_float3(angularVelocity.x, angularVelocity.y, angularVelocity.z)
        let mag = simd_length(w)
        guard dt > 0, mag > 1e-6 else { return simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)) }
        return simd_quatf(angle: mag * dt, axis: w / mag)
    }

    /// 逐帧推进球节点姿态。`from`/`to` 取**平均角速度**（梯形积分），使减速段的积分与
    /// 真实转过的角度一致；四元数每帧归一化，防止长回放累积漂移。
    static func advance(node: SCNNode, from: SCNVector3, to: SCNVector3, dt: Float) {
        guard dt > 0 else { return }
        let mean = SCNVector3((from.x + to.x) * 0.5, (from.y + to.y) * 0.5, (from.z + to.z) * 0.5)
        let q = delta(angularVelocity: mean, dt: dt)
        node.simdOrientation = simd_normalize(q * node.simdOrientation)
    }

    /// 复位球体姿态（S5）：回放会把姿态转到任意角度，复位/重新摆球时必须一并归零，
    /// 否则同一杆反复播放的起始姿态逐次漂移，截图取证与教学演示都无法复现。
    static func resetPose(_ node: SCNNode) {
        node.simdOrientation = simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))
    }
}

final class TrajectoryPlayback {
    
    let recorder: TrajectoryRecorder
    let surfaceY: Float
    
    /// 每个球的帧数据缓存（按时间排序，来自 recorder）
    private let sortedFrames: [String: [BallFrame]]
    
    /// 已触发进袋的球名称集合（防止重复触发）
    private(set) var pocketedBalls: Set<String> = []
    
    /// 已触发淡出动画的球（进袋后需要一小段淡出时间）
    private(set) var fadingBalls: [String: Float] = [:]
    
    private let fadeOutDuration: Float = 0.25

    /// 进袋入洞段（#4 v2）单段行程时长上限：入洞以**进袋时真实速度匀速**冲入，不应提前减速；
    /// 上限只为慢速 settle 兜底，避免拖太久。
    static let pocketEntryLegMaxDuration: TimeInterval = 0.30
    /// 撞远端袋弧后回落到袋心的短促 settle 时长。
    static let pocketSettleBackDuration: TimeInterval = 0.12
    /// 入洞段最小视觉速度 (m/s)：jaw settle / 慢滚进袋的球也要有可见的入洞动作。
    static let pocketMinEntrySpeed: Float = 0.4
    /// 进袋后先停顿一拍再淡出（直接消失体验差）：球落到袋心静置 `pocketPauseDuration` 秒后才开始淡出。
    static let pocketPauseDuration: TimeInterval = 0.35
    /// 进袋淡出时长（停顿之后）。
    static let pocketFadeDuration: TimeInterval = 0.25
    /// 进袋收尾总时长上限（入洞 + 回落 + 停顿 + 淡出），供回放/导出收尾对齐。
    static var pocketSettleDuration: TimeInterval {
        pocketEntryLegMaxDuration + pocketSettleBackDuration + pocketPauseDuration + pocketFadeDuration
    }

    // MARK: - Pocket entry (#4 v2：捕获点 → 远端袋弧 → 袋心)

    /// 入洞段路标：依次 move 的目标点与时长。`eased = true` 表示该段 easeOut（撞弧后回落）。
    struct PocketEntryLeg {
        let to: SCNVector3
        let duration: TimeInterval
        let eased: Bool
    }

    /// 求进袋入洞段（显示层，与物理引擎解耦）。
    ///
    /// 引擎在球心抵达落袋孔圈（0.042/0.043m，ADR-P10-09）时捕获球并停止记录，
    /// 「捕获点 → 洞内」这段需要显示层补：球以**进袋时的真实水平速度匀速**冲入洞内
    /// （绝不提前减速）；若速度射线穿过袋口圆，则先在**远端袋弧**处撞壁，再短促回落到袋心；
    /// 射线不穿圆（慢速 settle / 方向缺失）则直接匀速滑到袋心。
    /// - Parameter speedScale: 回放速度倍率（与轨迹回放一致，保证入洞速度视觉连续）。
    static func solvePocketEntry(
        capture: SCNVector3,
        velocity: SCNVector3,
        pocketCenter: SCNVector3,
        pocketRadius: Float,
        speedScale: Float
    ) -> [PocketEntryLeg] {
        let y = capture.y
        let center = SCNVector3(pocketCenter.x, y, pocketCenter.z)
        let vLen = sqrtf(velocity.x * velocity.x + velocity.z * velocity.z)
        let speed = max(pocketMinEntrySpeed, vLen) * max(0.05, speedScale)

        // 入洞方向：优先沿进袋时速度方向；速度缺失（settle）退化为指向袋心。
        var dirX = velocity.x, dirZ = velocity.z
        if vLen < 0.05 {
            dirX = center.x - capture.x
            dirZ = center.z - capture.z
        }
        let dLen = sqrtf(dirX * dirX + dirZ * dirZ)
        guard dLen > 1e-4 else {
            return [PocketEntryLeg(to: center, duration: pocketSettleBackDuration, eased: true)]
        }
        dirX /= dLen; dirZ /= dLen

        // 远端袋弧碰撞点：射线 capture + t·dir 与「球心可达弧」（袋口圆半径收 0.3R，
        // 球鼻触壁时球心略在弧内）的远交点。
        let rHit = pocketRadius - 0.3 * AngleSceneCalculator.ballRadius
        let fx = capture.x - center.x
        let fz = capture.z - center.z
        let b = fx * dirX + fz * dirZ
        let c = fx * fx + fz * fz - rHit * rHit
        let disc = b * b - c
        var legs: [PocketEntryLeg] = []
        if disc > 0 {
            let tFar = -b + sqrtf(disc)
            if tFar > 1e-3 {
                let hit = SCNVector3(capture.x + dirX * tFar, y, capture.z + dirZ * tFar)
                legs.append(PocketEntryLeg(
                    to: hit,
                    duration: min(TimeInterval(tFar / speed), pocketEntryLegMaxDuration),
                    eased: false
                ))
                legs.append(PocketEntryLeg(to: center, duration: pocketSettleBackDuration, eased: true))
                return legs
            }
        }
        // 射线不穿袋口圆：直接匀速滑到袋心。
        let dist = sqrtf(fx * fx + fz * fz)
        return [PocketEntryLeg(
            to: center,
            duration: min(TimeInterval(dist / speed), pocketEntryLegMaxDuration),
            eased: false
        )]
    }

    /// 入洞段在真实播放秒 `real` 时的位置（导出器逐帧驱动用，与 SCNAction 版同源）。
    /// 超过总时长后停在最后一个路标（袋心）。
    static func pocketEntryPosition(
        start: SCNVector3, legs: [PocketEntryLeg], at real: TimeInterval
    ) -> SCNVector3 {
        var from = start
        var t = real
        for leg in legs {
            if t < leg.duration, leg.duration > 1e-6 {
                var u = Float(t / leg.duration)
                if leg.eased { u = 1 - (1 - u) * (1 - u) }   // easeOut，与 SCNAction 版一致
                return SCNVector3(from.x + (leg.to.x - from.x) * u,
                                  from.y,
                                  from.z + (leg.to.z - from.z) * u)
            }
            t -= leg.duration
            from = leg.to
        }
        return legs.last?.to ?? start
    }

    /// 入洞段总时长。
    static func pocketEntryDuration(_ legs: [PocketEntryLeg]) -> TimeInterval {
        legs.reduce(0) { $0 + $1.duration }
    }

    /// 最近袋口（CAD 孔心 + 孔半径）。入洞动画起点取进袋前一帧真实位置，
    /// 目标按最近袋口查找。
    static func nearestPocket(to p: SCNVector3, surfaceY: Float) -> (center: SCNVector3, radius: Float) {
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        var bestIndex = 0
        var bestDist = Float.greatestFiniteMagnitude
        for (i, c) in pockets.enumerated() {
            let dx = c.x - p.x, dz = c.z - p.z
            let d = dx * dx + dz * dz
            if d < bestDist { bestDist = d; bestIndex = i }
        }
        return (pockets[bestIndex], AngleSceneCalculator.pocketMarkerRadius(index: bestIndex))
    }
    
    var duration: Float { recorder.duration }

    /// All recorded ball names (cue + object + colliders) for clearance probes.
    var ballNames: [String] { Array(sortedFrames.keys) }

    /// World centres of **every** ball at simulation time `t`, keyed by ball name
    /// (cue clearance D2 — ids required for per-ball separation latch).
    func allBallCentersByName(at time: Float) -> [String: SCNVector3] {
        var result: [String: SCNVector3] = [:]
        for name in ballNames {
            if let p = stateAt(ballName: name, time: time)?.position {
                result[name] = p
            }
        }
        return result
    }
    
    init(recorder: TrajectoryRecorder, surfaceY: Float) {
        self.recorder = recorder
        self.surfaceY = surfaceY
        
        var sorted: [String: [BallFrame]] = [:]
        for (name, frames) in recorder.framesByBallName {
            sorted[name] = frames.sorted { $0.time < $1.time }
        }
        self.sortedFrames = sorted
    }
    
    /// 查询指定球在时刻 t 的精确状态
    func stateAt(ballName: String, time: Float) -> PlaybackBallState? {
        guard let frames = sortedFrames[ballName], !frames.isEmpty else { return nil }
        
        let t = max(0, time)
        
        if frames.count == 1 {
            let f = frames[0]
            return PlaybackBallState(
                position: SCNVector3(f.position.x, surfaceY, f.position.z),
                velocity: f.velocity,
                motionState: f.state,
                angularVelocity: Self.omega(f),
                moveDirection: SCNVector3Zero
            )
        }
        
        if t <= frames[0].time {
            let f = frames[0]
            return PlaybackBallState(
                position: SCNVector3(f.position.x, surfaceY, f.position.z),
                velocity: f.velocity,
                motionState: f.state,
                angularVelocity: Self.omega(f),
                moveDirection: f.velocity.length() > 0.001 ? f.velocity.normalized() : SCNVector3Zero
            )
        }
        
        // 二分查找：找到最后一个 frame.time <= t 的索引
        let idx = binarySearchFloor(frames: frames, time: t)
        let baseFrame = frames[idx]
        
        if baseFrame.state == .pocketed {
            return PlaybackBallState(
                position: SCNVector3(baseFrame.position.x, surfaceY, baseFrame.position.z),
                velocity: SCNVector3Zero,
                motionState: .pocketed,
                angularVelocity: SCNVector3Zero,
                moveDirection: SCNVector3Zero
            )
        }
        
        if baseFrame.state == .stationary {
            return PlaybackBallState(
                position: SCNVector3(baseFrame.position.x, surfaceY, baseFrame.position.z),
                velocity: SCNVector3Zero,
                motionState: .stationary,
                angularVelocity: SCNVector3Zero,
                moveDirection: SCNVector3Zero
            )
        }
        
        // 解析演进：从 baseFrame 推进 dt 到时刻 t
        let dt = t - baseFrame.time
        
        // 限制 dt 不超过下一帧时刻（防止越过事件）
        let maxDt: Float
        if idx + 1 < frames.count {
            maxDt = frames[idx + 1].time - baseFrame.time
        } else {
            maxDt = dt
        }
        let clampedDt = min(dt, maxDt)
        
        let angularVel3 = Self.omega(baseFrame)
        
        let evolved: (position: SCNVector3, velocity: SCNVector3, angularVelocity: SCNVector3)
        
        switch baseFrame.state {
        case .sliding:
            evolved = AnalyticalMotion.evolveSliding(
                position: baseFrame.position,
                velocity: baseFrame.velocity,
                angularVelocity: angularVel3,
                dt: clampedDt
            )
        case .rolling:
            evolved = AnalyticalMotion.evolveRolling(
                position: baseFrame.position,
                velocity: baseFrame.velocity,
                angularVelocity: angularVel3,
                dt: clampedDt
            )
        case .spinning:
            let result = AnalyticalMotion.evolveSpinning(
                position: baseFrame.position,
                angularVelocity: angularVel3,
                dt: clampedDt
            )
            evolved = (result.position, baseFrame.velocity, result.angularVelocity)
        case .stationary, .pocketed:
            evolved = (baseFrame.position, baseFrame.velocity, angularVel3)
        }
        
        let segmentDisplacement = evolved.position - baseFrame.position
        let segmentDistance = segmentDisplacement.length()
        
        let moveDir: SCNVector3
        if evolved.velocity.length() > 0.001 {
            moveDir = evolved.velocity.normalized()
        } else if segmentDistance > 0.0001 {
            moveDir = segmentDisplacement.normalized()
        } else {
            moveDir = SCNVector3Zero
        }
        
        return PlaybackBallState(
            position: SCNVector3(evolved.position.x, surfaceY, evolved.position.z),
            velocity: evolved.velocity,
            motionState: baseFrame.state,
            angularVelocity: evolved.angularVelocity,
            moveDirection: moveDir
        )
    }
    
    /// 帧内角速度取三分量（`SCNVector4` 的 `w` 位在记录侧未使用）。
    private static func omega(_ frame: BallFrame) -> SCNVector3 {
        SCNVector3(frame.angularVelocity.x, frame.angularVelocity.y, frame.angularVelocity.z)
    }
    
    /// 生成平滑回放动作（推荐替代 `TrajectoryRecorder.action`）。
    ///
    /// `TrajectoryRecorder` 只在**物理事件**（碰撞/吃库/停止）处记录快照，事件之间可能
    /// 跨越很长一段减速/曲线运动。若对事件帧做 `SCNAction.move` 线性插值（或固定步长预烘焙
    /// 关键帧），都会在低速段出现「分段匀速 + 端点突变」的卡顿——尤其末段减速到停。
    ///
    /// 这里改用 `SCNAction.customAction`：在**每一渲染帧**用 `stateAt` 的 `AnalyticalMotion`
    /// 解析解直接求当前时刻位置，按显示刷新率（ProMotion 可达 120Hz）连续插值，任何速度都顺滑；
    /// 球体姿态用引擎角速度 ω 逐帧四元数积分驱动（v17：加塞竖轴自转、低杆倒旋、定杆不转
    /// 都随之上屏，`.spinning` 段位置不动也照转）；进袋时淡出并移除。
    /// 求值与所绘轨迹折线同源、完全吻合。
    /// - Parameter removeOnPocket: 进袋后是否把节点从父节点移除。默认 `true`（一次性回放，
    ///   球进袋即消失）。**可复用回放场景（如分离角页：播放后要复位重显原球）应传 `false`**——
    ///   否则末尾的 `removeFromParentNode` 会与「播放结束复位」竞态，导致目标球被移除后无法恢复
    ///   （reset/拖动均无法重新挂回父节点 → 球永久消失）。`false` 时只淡出、保留节点。
    /// - Parameter maxSimTime: 截断回放的模拟时长上限（秒，模拟时间轴）。默认 `nil` = 整段
    ///   `duration`。**G15：回放/渲染一律播到引擎自然静止（`recorder.duration`），不做
    ///   0.07 m/s 感知截断**——旧「感知静止截断」会把仍在 creep 的球冻在非终点位置，随后
    ///   收尾快照瞬移到真实落点（肉眼「最后一跳」）；播满自然静止后落点已一致，无瞬移。
    ///   各调用方均传 `duration`（等价 `nil`）；此参数保留作通用截断能力。
    func action(for node: SCNNode, ballName: String, speed: Float = 1.0,
                removeOnPocket: Bool = true, maxSimTime: Float? = nil) -> SCNAction? {
        guard let frames = sortedFrames[ballName], frames.count > 1, duration > 1e-4 else { return nil }

        let cap = min(duration, maxSimTime ?? duration)
        let spd = max(0.05, speed)
        let realDuration = TimeInterval(cap / spd)
        let willPocket = willBePocketed(ballName)

        // 逐帧回放需要跨帧的可变状态（上一帧模拟时刻与角速度 / 是否已触发淡出）。
        let cursor = PlaybackCursor()
        cursor.lastAngularVelocity = stateAt(ballName: ballName, time: 0)?.angularVelocity ?? SCNVector3Zero

        // 强引用 self：动画存续期间（绑定在节点上）保证 playback 不被释放；
        // playback 不持有节点，节点 `removeAllActions` 后即解除引用，无循环。
        let evaluate = SCNAction.customAction(duration: realDuration) { node, elapsed in
            // 进袋后位置/透明度由「沉入 → 停顿 → 淡出」子动作接管，逐帧求值不再覆盖。
            if cursor.didFade { return }

            let tSim = min(Float(elapsed) * spd, cap)
            guard let s = self.stateAt(ballName: ballName, time: tSim) else { return }

            if s.motionState == .pocketed {
                cursor.didFade = true
                // 入洞（#4 v2）：以进袋时的真实速度匀速冲入洞内（不提前减速），
                // 穿圆则先撞远端袋弧再短促回落袋心；球心到袋心后停顿一拍（#9）再淡出。
                let pocket = Self.nearestPocket(to: node.position, surfaceY: self.surfaceY)
                let legs = Self.solvePocketEntry(
                    capture: node.position, velocity: cursor.lastVelocity,
                    pocketCenter: pocket.center, pocketRadius: pocket.radius, speedScale: spd
                )
                var seq: [SCNAction] = legs.map { leg in
                    let move = SCNAction.move(to: leg.to, duration: leg.duration)
                    move.timingMode = leg.eased ? .easeOut : .linear
                    return move
                }
                seq.append(.wait(duration: Self.pocketPauseDuration))
                seq.append(.fadeOut(duration: Self.pocketFadeDuration))
                node.runAction(.sequence(seq))
                return
            }

            node.position = SCNVector3(s.position.x, self.surfaceY, s.position.z)
            cursor.lastVelocity = s.velocity

            // 姿态按**模拟时间**积分 ω：慢放（speed < 1）时转速同比放慢，与位移一致。
            // 这里不设「有位移才转」的门槛——纯自转（`.spinning`）恰恰是位移为零的那一段。
            BallSpinIntegrator.advance(node: node, from: cursor.lastAngularVelocity,
                                       to: s.angularVelocity, dt: tSim - cursor.lastSimTime)
            cursor.lastSimTime = tSim
            cursor.lastAngularVelocity = s.angularVelocity
        }

        if willPocket && removeOnPocket {
            // 留够「沉入 + 停顿 + 淡出」时间再移除节点，保证进袋过程可见。
            return SCNAction.sequence([
                evaluate,
                .wait(duration: Self.pocketSettleDuration),
                .removeFromParentNode()
            ])
        }
        return evaluate
    }

    /// 逐帧回放的跨帧可变游标（`customAction` 闭包按帧调用，需在闭包外保存状态）。
    private final class PlaybackCursor {
        /// 上一帧的模拟时刻（秒）——姿态积分的 Δt 来源。
        var lastSimTime: Float = 0
        /// 上一帧的角速度（梯形积分取两帧均值）。
        var lastAngularVelocity = SCNVector3Zero
        /// 最近一帧的真实速度（进袋瞬间用作入洞方向与速度）。
        var lastVelocity = SCNVector3Zero
        var didFade = false
    }

    /// 标记球已进袋并开始淡出
    func markPocketed(_ ballName: String, at time: Float) {
        guard !pocketedBalls.contains(ballName) else { return }
        pocketedBalls.insert(ballName)
        fadingBalls[ballName] = time
    }
    
    /// 获取球当前应有的不透明度（进袋淡出）
    func opacity(for ballName: String, at time: Float) -> Float {
        guard let fadeStart = fadingBalls[ballName] else { return 1.0 }
        let elapsed = time - fadeStart
        if elapsed >= fadeOutDuration { return 0.0 }
        return 1.0 - (elapsed / fadeOutDuration)
    }
    
    /// 检查球是否会在轨迹中被进袋
    func willBePocketed(_ ballName: String) -> Bool {
        recorder.isBallPocketed(ballName)
    }
    
    /// 检查回放是否已完成（所有球到达最终状态）
    func isComplete(at time: Float) -> Bool {
        return time >= duration
    }

    // MARK: - Binary Search
    
    /// 找到最后一个 frame.time <= targetTime 的索引
    private func binarySearchFloor(frames: [BallFrame], time targetTime: Float) -> Int {
        var lo = 0
        var hi = frames.count - 1
        var result = 0
        
        while lo <= hi {
            let mid = (lo + hi) / 2
            if frames[mid].time <= targetTime {
                result = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        
        return result
    }
}
