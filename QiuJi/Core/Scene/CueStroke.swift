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
    /// 跟杆终点回杆量上限：杆头越过母球原中心约一颗球（杆头落在 +2R 处）⇒ `pullBack ≈ −3R`。
    /// Forward obstacles may clamp this via `clampedFollowThroughPull` (D3).
    static var followThroughPull: Float { -3 * AngleSceneCalculator.ballRadius }

    /// Clamp the entire finite cue's forward sweep against stationary obstacle balls.
    /// `cueBallPosition` is the render pivot; elevation/inset must match the renderer.
    /// Returns a pull in [-3R, 0]. This is visual clearance, not a push-shot ruling.
    static func clampedFollowThroughPull(
        cueBallPosition: SCNVector3,
        aimDirection: SCNVector3,
        obstacleCenters: [SCNVector3],
        elevation: Float = 0,
        tipInset: Float = 0,
        surfaceY: Float = BTTablePhysics.surfaceY,
        profile: [CueSection] = CueSection.fallback
    ) -> Float {
        let gap = CueClearance.forwardSurfaceGap(
            cueBallPosition: cueBallPosition,
            aimDirection: aimDirection,
            obstacleCenters: obstacleCenters, elevation: elevation, tipInset: tipInset, profile: profile
        )
        let ballLimit = gap == .greatestFiniteMagnitude ? followThroughPull : -min(-followThroughPull, gap)
        guard elevation > 1e-5 else { return ballLimit }
        // At positive elevation the tip is the lowest part of the cue. Stop its
        // finite cross-section above the cloth instead of following through it.
        let tipBottomRadius = CueClearance.tipRadius + 0.001
        let clothLimit = (surfaceY + tipBottomRadius + CueClearance.ballClearance - cueBallPosition.y)
            / sinf(elevation) - CueClearance.tipOffset + tipInset
        return min(0, max(ballLimit, clothLimit))
    }

    /// 触球后送杆量（`pullBack`）：0 → `endPull`，ease-out（触球瞬间最快、随后减速到停）。
    /// - Parameter endPull: defaults to unclamped `followThroughPull` (−3R).
    static func followThrough(at t: TimeInterval, endPull: Float? = nil) -> Float {
        let end = endPull ?? followThroughPull
        let u = Float(min(1, max(0, t / followThroughDuration)))
        let ease = 1 - (1 - u) * (1 - u)        // 减速曲线（ease-out）
        return end * ease
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
    /// - `spinY` 正 = 高杆（`BTSpinPad` 屏幕上 / `CueBallStrike` 同约定）⇒ 击球点抬高 `spinY·R`
    ///   （DR-296：原实现只有横向偏移，高低杆在球杆上不可见）。
    static func strikePosition(cue: SCNVector3, aim: SCNVector3, spinX: Double, spinY: Double = 0) -> SCNVector3 {
        let r = AngleSceneCalculator.ballRadius
        let len = sqrtf(aim.x * aim.x + aim.z * aim.z)
        guard len > 1e-6 else { return cue }
        let ax = aim.x / len, az = aim.z / len
        // right = aim × ŷ；旧实现误用 `+ right·spinX`，左塞杆头落到挤偏同侧（右）。
        let right = SCNVector3(-az, 0, ax)
        let lateral = Float(spinX) * r
        let vertical = Float(spinY) * r
        return SCNVector3(cue.x - right.x * lateral, cue.y + vertical, cue.z - right.z * lateral)
    }

    /// 杆头相对「击球点 + R」需要前伸的量：偏心打点处球面到球心的 aim 向距离是
    /// `R·√(1 − a² − b²)`，不是 R。渲染专用（`CueStick.update(tipInset:)`）；
    /// `CueClearance` 的碰撞搜索仍按名义 `tipOffset`（保守）。
    static func tipInset(spinX: Double, spinY: Double) -> Float {
        let r = AngleSceneCalculator.ballRadius
        let e2 = Float(spinX * spinX + spinY * spinY)
        return r * (1 - sqrtf(max(0, 1 - min(1, e2))))
    }
}

extension AngleTrainingScene {
    /// Obstacle ball centres for cue clearance (all visible balls except the cue ball).
    func cueObstacleCenters(excludingStrikeNear strike: SCNVector3? = nil) -> [SCNVector3] {
        var result: [SCNVector3] = []
        for (key, node) in visibleBalls() {
            if key == "cueBall" { continue }
            if let strike {
                let dx = node.position.x - strike.x
                let dz = node.position.z - strike.z
                if dx * dx + dz * dz < 1e-8 { continue }
            }
            result.append(node.position)
        }
        return result
    }

    /// 运杆 / 出杆 / 跟杆动画（#10，单一权威，实时场景用）：
    /// 回杆 → 蓄力 → 匀加速出杆（触球瞬间杆速 = `velocity`，此刻触发 `onContact` 发球）→
    /// 减速跟杆（杆头越过母球原中心约一颗球，可被前方球钳制）→ 停留 `followThroughHold` → 淡出收杆。
    /// 无球杆节点时立即回调（直接发球）。
    ///
    /// - Parameter strikePosition: 杆头对准的母球击球点（含加塞偏移，见 `CueStroke.strikePosition`）。
    /// - Parameter clearanceProbe: optional; given simulation time **after contact**, returns
    ///   **all** ball centres keyed by stable id (for per-ball separation latch). When non-nil
    ///   and a re-entry collision is predicted, retract early. When `nil`, pullBack timeline
    ///   matches the pre-clearance behaviour (regression red line) aside from the final
    ///   hard-cut hide → short fade.
    /// - Parameter onContact: 触球瞬间于主线程触发，由调用方启动球体轨迹回放；
    ///   **不要**在此 `hideCueStick`——收杆由本方法在跟杆 + 停留后接管。
    func runCueStroke(
        strikePosition: SCNVector3,
        aim: SCNVector3,
        velocity: Float,
        switchesPlayerCameraOnContact: Bool = false,
        clearanceProbe: ((TimeInterval) -> [String: SCNVector3])? = nil,
        onContact: @escaping () -> Void
    ) {
        let contact: () -> Void = { [weak self] in
            if switchesPlayerCameraOnContact { self?.transitionPlayerCameraForShot(aim: aim) }
            onContact()
        }
        guard let stick = cueStick else {
            contact()
            return
        }
        let stickNode = stick.rootNode
        stickNode.removeAction(forKey: "aimTransition")
        let obstacles = cueObstacleCenters(excludingStrikeNear: strikePosition)
        // 击球点与瞄准方向全程固定 ⇒ 仰角恒定；逐帧直接驱动 `CueStick`，绕开 `updateCueStick`
        // （后者会取消 "strokeAnim" 以处理收杆/复位竞态，若经它驱动会自我取消）。
        let access = cueStrikeAccess(aim: aim)
        let flat = CueClearance.normalizeFlat(aim)
        let r = AngleSceneCalculator.ballRadius
        let resolvedPose = access.flatMap { context in
            context.resolvedPose(
                spinX: Double(((strikePosition.x-context.cue.x)*flat.z-(strikePosition.z-context.cue.z)*flat.x)/r),
                spinY: Double((strikePosition.y-context.cue.y)/r))
        }
        let renderStrike = resolvedPose?.pivot ?? strikePosition
        let elevResult = resolvedPose.map { CueElevation.angle($0.elevation) } ?? CueStick.requiredElevation(
            cueBallPosition: renderStrike, aimDirection: aim, obstacleCenters: obstacles, surfaceY: surfaceY
        )
        guard case .angle(let elevation) = elevResult else {
            // Blocked: do not draw a penetrating stick; still fire the shot.
            stick.hide()
            contact()
            return
        }
        let tipInset = resolvedPose?.inset ?? cueTipInset(forStrike: strikePosition) ?? 0
        let endPull = CueStroke.clampedFollowThroughPull(
            cueBallPosition: renderStrike, aimDirection: aim, obstacleCenters: obstacles,
            elevation: elevation, tipInset: tipInset, surfaceY: surfaceY, profile: stick.clearanceProfile
        )
        let animationGeneration = stick.beginStrokeAnimation()
        let drive: (Float) -> Void = { [weak stick] pull in
            stick?.updateStrokeAnimation(animationGeneration, cueBallPosition: renderStrike, aimDirection: aim,
                          pullBack: pull, elevation: elevation, tipInset: tipInset)
        }
        drive(0)
        stick.show()
        stick.setFadeOpacity(1)

        let contactDur = CueStroke.totalDuration(velocity: velocity)
        let toContact = SCNAction.customAction(duration: contactDur) { _, elapsed in
            drive(CueStroke.pullBack(at: TimeInterval(elapsed), velocity: velocity))
        }
        let launch = SCNAction.run { [weak stick] _ in Task { @MainActor in
            guard stick?.isCurrentStrokeAnimation(animationGeneration) == true else { return }
            contact()
        } }

        // Predict first post-contact collision across ALL balls (D2 — not cue-only).
        let collisionT: TimeInterval? = clearanceProbe.flatMap { probe in
            CueClearance.firstCollisionTime(
                strikePosition: renderStrike,
                aimDirection: aim,
                elevation: elevation,
                endPull: endPull,
                holdDuration: CueStroke.followThroughHold,
                ballsAt: probe
            )
        }

        let postContact = Self.makePostContactActions(
            collisionT: collisionT,
            endPull: endPull,
            holdDuration: CueStroke.followThroughHold,
            drive: drive,
            stick: stick,
            animationGeneration: animationGeneration
        )
        stickNode.runAction(.sequence([toContact, launch] + postContact), forKey: "strokeAnim")
    }

    /// The host chooses the accepted shot's contact, capture, or settlement boundary.
    /// A delayed transition uses the shot's original cue position, not its moving ball.
    @discardableResult
    func transitionPlayerCameraForShot(aim: SCNVector3, from cuePosition: SCNVector3? = nil) -> Bool {
        guard currentCameraMode == .perspective3D,
              let rig = cameraRig, rig.usesRailCameraControls, rig.playerView == .firstPerson,
              let cue = cuePosition ?? cueBallNode?.position,
              rig.isPlayerViewFor(cue: cue, aim: aim) else { return false }
        return rig.enterPlayerView(.thirdPerson, cue: cue, aim: aim,
            duration: UIAccessibility.isReduceMotionEnabled ? 0.1 : 0.95)
    }

    /// Build follow-through / hold / retract-or-fade action list after contact.
    private static func makePostContactActions(
        collisionT: TimeInterval?,
        endPull: Float,
        holdDuration: TimeInterval,
        drive: @escaping (Float) -> Void,
        stick: CueStick,
        animationGeneration: UInt64
    ) -> [SCNAction] {
        let followDur = CueStroke.followThroughDuration
        let lead = CueClearance.retractLead
        let fade = CueClearance.retractFade
        let retractExtra = CueClearance.retractPullExtra

        // No predicted collision: normal follow-through + hold + short fade (not hard cut).
        guard let tStar = collisionT else {
            let followThrough = SCNAction.customAction(duration: followDur) { _, elapsed in
                drive(CueStroke.followThrough(at: TimeInterval(elapsed), endPull: endPull))
            }
            let hold = SCNAction.wait(duration: holdDuration)
            let fadeOut = SCNAction.run { [weak stick] _ in
                Task { @MainActor in
                    stick?.withStrokeAnimation(animationGeneration) { stick?.fadeOut(duration: fade) }
                }
            }
            return [followThrough, hold, fadeOut]
        }

        // Retract window starts at max(0, t* − lead).
        let retractStart = max(0, tStar - lead)
        var actions: [SCNAction] = []

        if retractStart > 1e-4 {
            // Play normal motion until retractStart.
            let preDur = retractStart
            let pre = SCNAction.customAction(duration: preDur) { _, elapsed in
                let tau = TimeInterval(elapsed)
                drive(CueClearance.pullBackAfterContact(tau: tau, endPull: endPull))
            }
            actions.append(pre)
        }

        // Capture pull at retract start for lerp.
        let pullAtRetract = CueClearance.pullBackAfterContact(tau: retractStart, endPull: endPull)
        let retract = SCNAction.customAction(duration: fade) { [weak stick] _, elapsed in
            let u = Float(min(1, max(0, elapsed / CGFloat(fade))))
            // Withdraw along back (more positive pullBack) while fading.
            let pull = pullAtRetract + u * (retractExtra - min(0, pullAtRetract))
            drive(pull)
            stick?.withStrokeAnimation(animationGeneration) { stick?.setFadeOpacity(CGFloat(1 - u)) }
        }
        let hide = SCNAction.run { [weak stick] _ in
            Task { @MainActor in
                stick?.hideStrokeAnimation(animationGeneration)
            }
        }
        actions.append(contentsOf: [retract, hide])
        return actions
    }
}
