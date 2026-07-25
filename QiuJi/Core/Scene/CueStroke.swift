import SceneKit

/// 单一权威「运杆 / 出杆」运动学（#10）。
///
/// 所有「有击球」的场景（走位编排台 / 思路训练器 / 斯诺克战术 / 分离角轨迹模拟）
/// 与离线出片导出器（`SequenceVideoExporter`）共用同一套公式：
/// 回杆距离 `d = a + k·v`（线性）→ 回杆 smoothstep（0→d）→ 蓄力停顿（d）→
/// 匀加速出杆（d→0），**触球瞬间杆速恰为目标球速 v**（`a_accel = v²/(2d)`，前推时长 `t = 2d/v`）。
///
/// 实时场景用 `AngleTrainingScene.runCueStroke(...)`（`SCNAction` 驱动）；
/// 导出器逐帧采样用 `pullBack(at:velocity:)`。二者共享下列常量与曲线，杜绝多份漂移。
enum CueStroke {
    /// a：最小回杆距离 (m)。
    static let basePullBack: Float = 0.05
    /// k：每 1 m/s 杆速增加的回杆距离 (s)。
    static let pullBackPerSpeed: Float = 0.035
    /// 回杆时长（慢、带缓动，模拟瞄准后撤杆）。
    static let backswingDuration: TimeInterval = 0.5
    /// 回杆到位后的停顿（出杆前蓄力一拍）。
    static let pauseDuration: TimeInterval = 0.12

    /// 触球后的跟杆（follow-through）减速送杆时长。
    static let followThroughDuration: TimeInterval = 0.2
    /// 实时场景：跟杆到位后的停留时长（停住一拍再收杆，更真实；球也仍在滚动停稳）。导出另用 `exportFollowThroughHold`。
    static let followThroughHold: TimeInterval = 1.5
    /// 导出逐帧：跟杆后的短停（避免教学视频每杆拖沓）。
    static let exportFollowThroughHold: TimeInterval = 0.2
    /// 跟杆终点回杆量：杆头越过母球原中心约一颗球（杆头落在 +2R 处）⇒ `pullBack ≈ −3R`。
    static var followThroughPull: Float { -3 * AngleSceneCalculator.ballRadius }

    /// 触球后送杆量（`pullBack`）：0 → `followThroughPull`，ease-out（触球瞬间最快、随后减速到停）。
    static func followThrough(at t: TimeInterval) -> Float {
        let u = Float(min(1, max(0, t / followThroughDuration)))
        let ease = 1 - (1 - u) * (1 - u)        // 减速曲线（ease-out）
        return followThroughPull * ease
    }

    /// 速度下限，避免极慢杆出现除零 / 超长前推。
    private static func clampedSpeed(_ v: Float) -> Float { max(0.3, v) }

    /// 回杆距离 d = a + k·v。
    static func pullBackDistance(velocity: Float) -> Float {
        basePullBack + pullBackPerSpeed * clampedSpeed(velocity)
    }

    /// 匀加速前推时长 t = 2d / v。
    static func forwardDuration(velocity: Float) -> TimeInterval {
        let v = clampedSpeed(velocity)
        return TimeInterval(2 * pullBackDistance(velocity: v) / v)
    }

    /// 一杆总时长 = 回杆 + 停顿 + 前推。
    static func totalDuration(velocity: Float) -> TimeInterval {
        backswingDuration + pauseDuration + forwardDuration(velocity: velocity)
    }

    /// 经过时间 `t`（秒）时的回杆量：回杆 smoothstep 0→d、停顿 d、出杆匀加速 d→0。
    static func pullBack(at t: TimeInterval, velocity: Float) -> Float {
        let v = clampedSpeed(velocity)
        let d = pullBackDistance(velocity: v)
        let accel = v * v / (2 * d)                          // v² = 2·a_accel·d
        if t < backswingDuration {
            let u = Float(t / backswingDuration)
            return d * (u * u * (3 - 2 * u))                 // 回杆 smoothstep
        } else if t < backswingDuration + pauseDuration {
            return d                                         // 蓄力停顿
        } else {
            let dt = Float(t - backswingDuration - pauseDuration)
            return max(0, d - 0.5 * accel * dt * dt)         // 匀加速出杆 d → 0
        }
    }

    /// 含加塞横向偏移的击球点（杆头对准的母球击球中心）。
    ///
    /// - `spinX` 正 = 左塞（pooltool `a>0` = 球最左侧；与 `BTSpinPad` 屏幕左一致）
    /// - `right = aim × ŷ`（与 `AimingCorrectionMath.rightOfXZ` 同构）；左塞挤偏向 right，
    ///   杆头应在其对侧 ⇒ `cue − right·spinX·R`。
    static func strikePosition(cue: SCNVector3, aim: SCNVector3, spinX: Double) -> SCNVector3 {
        let r = AngleSceneCalculator.ballRadius
        let len = sqrtf(aim.x * aim.x + aim.z * aim.z)
        guard len > 1e-6 else { return cue }
        let ax = aim.x / len, az = aim.z / len
        // right = aim × ŷ；旧实现误用 `+ right·spinX`，左塞杆头落到挤偏同侧（右）。
        let right = SCNVector3(-az, 0, ax)
        let lateral = Float(spinX) * r
        return SCNVector3(cue.x - right.x * lateral, cue.y, cue.z - right.z * lateral)
    }
}

extension AngleTrainingScene {
    /// 运杆 / 出杆 / 跟杆动画（#10，单一权威，实时场景用）：
    /// 回杆 → 蓄力 → 匀加速出杆（触球瞬间杆速 = `velocity`，此刻触发 `onContact` 发球）→
    /// 减速跟杆（杆头越过母球原中心约一颗球）→ 停留 `followThroughHold` → 收杆。
    /// 无球杆节点时立即回调（直接发球）。
    ///
    /// - Parameter strikePosition: 杆头对准的母球击球点（含加塞偏移，见 `CueStroke.strikePosition`）。
    /// - Parameter onContact: 触球瞬间于主线程触发，由调用方启动球体轨迹回放；
    ///   **不要**在此 `hideCueStick`——收杆由本方法在跟杆 + 停留后接管。
    func runCueStroke(strikePosition: SCNVector3, aim: SCNVector3, velocity: Float,
                      onContact: @escaping () -> Void) {
        guard let stick = cueStick else {
            onContact()
            return
        }
        let stickNode = stick.rootNode
        // 击球点与瞄准方向全程固定 ⇒ 仰角恒定；逐帧直接驱动 `CueStick`，绕开 `updateCueStick`
        // （后者会取消 "strokeAnim" 以处理收杆/复位竞态，若经它驱动会自我取消）。
        let elevation = CueStick.requiredElevation(cueBallPosition: strikePosition, aimDirection: aim)
        let drive: (Float) -> Void = { [weak stick] pull in
            stick?.update(cueBallPosition: strikePosition, aimDirection: aim,
                          pullBack: pull, elevation: elevation)
        }
        drive(0)
        stick.show()

        let contactDur = CueStroke.totalDuration(velocity: velocity)
        let toContact = SCNAction.customAction(duration: contactDur) { _, elapsed in
            drive(CueStroke.pullBack(at: TimeInterval(elapsed), velocity: velocity))
        }
        let launch = SCNAction.run { _ in Task { @MainActor in onContact() } }
        let followThrough = SCNAction.customAction(duration: CueStroke.followThroughDuration) { _, elapsed in
            drive(CueStroke.followThrough(at: TimeInterval(elapsed)))
        }
        let hold = SCNAction.wait(duration: CueStroke.followThroughHold)
        let hide = SCNAction.run { [weak stick] _ in Task { @MainActor in stick?.hide() } }
        stickNode.runAction(.sequence([toContact, launch, followThrough, hold, hide]), forKey: "strokeAnim")
    }
}
