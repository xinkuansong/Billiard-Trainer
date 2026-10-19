import SceneKit

/// 单一权威「运杆 / 出杆」运动学（#10）。
///
/// 所有「有击球」的场景（走位编排台 / 思路训练器 / 斯诺克战术 / 分离角轨迹模拟）
/// 与离线出片导出器（`SequenceVideoExporter`）共用同一套公式：
/// One rehearsal → address pause → final backswing → back pause → delivery.
/// Excursion and preparation tempo vary continuously with the selected cue speed.
/// Delivery reaches that cue speed at contact; it does not drive the ball physics.
///
/// 实时场景用 `AngleTrainingScene.runCueStroke(...)`（`SCNAction` 驱动）；
/// 导出器逐帧采样用 `pullBack(at:velocity:)`。二者共享下列常量与曲线，杜绝多份漂移。
enum CueStroke {
    /// Extra axial gap at address and the end of the rehearsal. Never touch early.
    static let addressPull: Float = 0.003
    static let maximumPullBack: Float = 0.32

    /// Frozen per-shot timing, shared by realtime and frame-by-frame export.
    struct Timing {
        let velocity: Float
        let rehearsalDistance: Float
        let pullBackDistance: Float
        let rehearsalDuration: TimeInterval
        let addressPause: TimeInterval
        let backswingDuration: TimeInterval
        let backPause: TimeInterval

        var rehearsalBackDuration: TimeInterval { rehearsalDuration * 0.55 }
        var backswingStart: TimeInterval { rehearsalDuration + addressPause }
        var backPauseStart: TimeInterval { backswingStart + backswingDuration }
        var deliveryStart: TimeInterval { backPauseStart + backPause }
        var forwardDuration: TimeInterval { 2 * Double(pullBackDistance) / Double(velocity) }
        var contactTime: TimeInterval { deliveryStart + forwardDuration }
    }

    static func timing(velocity: Float, rehearsalEnabled: Bool = true) -> Timing {
        let v = clampedSpeed(velocity)
        // 0.5–10 m/s spans ordinary shots and the existing break-shot control.
        let strength = min(1, max(0, (v - 0.5) / 9.5))
        let excursion = powf(strength, 0.8)
        let finalExcursion = powf(strength, 0.7)
        return Timing(velocity: v,
                      rehearsalDistance: 0.03 + 0.17 * excursion,
                      pullBackDistance: 0.065 + (maximumPullBack - 0.065) * finalExcursion,
                      rehearsalDuration: rehearsalEnabled ? 0.80 + 0.30 * Double(strength) : 0,
                      addressPause: rehearsalEnabled ? 0.25 + 0.10 * Double(strength) : 0,
                      backswingDuration: 0.55 + 0.25 * Double(finalExcursion),
                      backPause: 0.18 + 0.10 * Double(strength))
    }

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

    /// Follow-through starts at the incoming cue speed and decelerates to rest.
    /// A nil velocity retains the envelope-only curve used by geometry callers.
    /// - Parameter endPull: defaults to unclamped `followThroughPull` (−3R).
    static func followThrough(at t: TimeInterval, endPull: Float? = nil, velocity: Float? = nil) -> Float {
        let end = endPull ?? followThroughPull
        guard end < 0 else { return 0 }
        let u = min(1, max(0, t / followThroughDuration))
        let exponent = velocity.map { Double(clampedSpeed($0)) * followThroughDuration / Double(-end) } ?? 2
        return end * Float(1 - pow(1 - u, max(2, exponent)))
    }

    /// Keep the established maximum sweep; soft shots use less of it.
    static func desiredFollowThroughPull(velocity: Float) -> Float {
        let strength = min(1, max(0, (clampedSpeed(velocity) - 0.5) / 9.5))
        return -(0.03 + (-followThroughPull - 0.03) * powf(strength, 0.8))
    }

    /// 速度下限，避免极慢杆出现除零 / 超长前推。
    private static func clampedSpeed(_ v: Float) -> Float { max(0.3, v) }

    /// Final backswing distance, bounded independently of out-of-range input speeds.
    static func pullBackDistance(velocity: Float) -> Float {
        timing(velocity: velocity).pullBackDistance
    }

    /// 匀加速前推时长 t = 2d / v。
    static func forwardDuration(velocity: Float) -> TimeInterval {
        timing(velocity: velocity).forwardDuration
    }

    /// Time to contact, including exactly one rehearsal and both pauses.
    static func totalDuration(velocity: Float, rehearsalEnabled: Bool = true) -> TimeInterval {
        timing(velocity: velocity, rehearsalEnabled: rehearsalEnabled).contactTime
    }

    /// One non-contact rehearsal, address, final backswing, pause, then delivery.
    static func pullBack(at t: TimeInterval, velocity: Float, rehearsalEnabled: Bool = true) -> Float {
        let p = timing(velocity: velocity, rehearsalEnabled: rehearsalEnabled)
        guard t > 0 else { return addressPull }
        func ease(_ u: Double) -> Float {
            let x = Float(min(1, max(0, u)))
            return x * x * (3 - 2 * x)
        }
        if t < p.rehearsalBackDuration {
            return addressPull + p.rehearsalDistance * ease(t / p.rehearsalBackDuration)
        }
        if t < p.rehearsalDuration {
            let u = (t - p.rehearsalBackDuration) / (p.rehearsalDuration - p.rehearsalBackDuration)
            return addressPull + p.rehearsalDistance * (1 - ease(u))
        }
        if t < p.backswingStart { return addressPull }
        if t < p.backPauseStart {
            return addressPull + (p.pullBackDistance - addressPull) * ease((t - p.backswingStart) / p.backswingDuration)
        }
        if t < p.deliveryStart { return p.pullBackDistance }
        if t >= p.contactTime { return 0 }
        let elapsed = t - p.deliveryStart
        let acceleration = Double(p.velocity) * Double(p.velocity) / (2 * Double(p.pullBackDistance))
        return Float(max(0, Double(p.pullBackDistance) - 0.5 * acceleration * elapsed * elapsed))
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
    /// 一次试运 → 球前定杆 → 后拉 → 后点停顿 → 出杆（此刻触发 `onContact` 发球）→
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
        rehearsalEnabled: Bool? = nil,
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
        let generation = stick.cancelAnimations()
        let lifetime = stick.animationLifetime
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
        let clearanceLimit = CueStroke.clampedFollowThroughPull(
            cueBallPosition: renderStrike, aimDirection: aim, obstacleCenters: obstacles,
            elevation: elevation, tipInset: tipInset, surfaceY: surfaceY, profile: stick.clearanceProfile
        )
        let endPull = max(clearanceLimit, CueStroke.desiredFollowThroughPull(velocity: velocity))
        let drive: (Float) -> Void = { [weak stick] pull in
            lifetime.perform(ifCurrent: generation) {
                stick?.update(cueBallPosition: renderStrike, aimDirection: aim,
                              pullBack: pull, elevation: elevation, tipInset: tipInset)
            }
        }
        drive(CueStroke.addressPull)
        stick.show()
        stick.setFadeOpacity(1)

        // Freeze the preference for this shot; a settings change applies to the next one.
        let rehearses = rehearsalEnabled ?? tablePreferences?.enabled(.rehearsal) ?? CueRehearsalPreference.isEnabled()
        let contactDur = CueStroke.totalDuration(velocity: velocity, rehearsalEnabled: rehearses)
        let toContact = SCNAction.customAction(duration: contactDur) { _, elapsed in
            drive(CueStroke.pullBack(at: TimeInterval(elapsed), velocity: velocity, rehearsalEnabled: rehearses))
        }
        let launch = SCNAction.run { _ in
            drive(0)
            Task { @MainActor in
                lifetime.perform(ifCurrent: generation) { contact() }
            }
        }

        // Predict first post-contact collision across ALL balls (D2 — not cue-only).
        let collisionT: TimeInterval? = clearanceProbe.flatMap { probe in
            CueClearance.firstCollisionTime(
                strikePosition: renderStrike,
                aimDirection: aim,
                elevation: elevation,
                endPull: endPull,
                holdDuration: CueStroke.followThroughHold,
                velocity: velocity,
                ballsAt: probe
            )
        }

        let postContact = Self.makePostContactActions(
            collisionT: collisionT,
            endPull: endPull,
            holdDuration: CueStroke.followThroughHold,
            velocity: velocity,
            drive: drive,
            stick: stick,
            generation: generation
        )
        stickNode.runAction(.sequence([toContact, launch] + postContact), forKey: "strokeAnim")
    }

    /// The host chooses the accepted shot's contact, capture, or settlement boundary.
    /// A delayed transition uses the shot's original cue position, not its moving ball.
    @discardableResult
    func transitionPlayerCameraForShot(aim: SCNVector3, from cuePosition: SCNVector3? = nil) -> Bool {
        guard currentCameraMode == .perspective3D,
              let rig = cameraRig, rig.usesRailCameraControls, rig.playerView == .firstPerson,
              !rig.usesTwoViewCameraControls || !rig.twoViewOwnerIsManual,
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
        velocity: Float,
        drive: @escaping (Float) -> Void,
        stick: CueStick,
        generation: UInt64
    ) -> [SCNAction] {
        let lifetime = stick.animationLifetime
        let followDur = CueStroke.followThroughDuration
        let lead = CueClearance.retractLead
        let fade = CueClearance.retractFade
        let retractExtra = CueClearance.retractPullExtra

        // No predicted collision: normal follow-through + hold + short fade (not hard cut).
        guard let tStar = collisionT else {
            let followThrough = SCNAction.customAction(duration: followDur) { _, elapsed in
                drive(CueStroke.followThrough(at: TimeInterval(elapsed), endPull: endPull, velocity: velocity))
            }
            let hold = SCNAction.wait(duration: holdDuration)
            let fadeOut = SCNAction.run { [weak stick] _ in
                Task { @MainActor in
                    lifetime.perform(ifCurrent: generation) { stick?.fadeOut(duration: fade) }
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
                drive(CueClearance.pullBackAfterContact(tau: tau, endPull: endPull, velocity: velocity))
            }
            actions.append(pre)
        }

        // Capture pull at retract start for lerp.
        let pullAtRetract = CueClearance.pullBackAfterContact(tau: retractStart, endPull: endPull, velocity: velocity)
        let retract = SCNAction.customAction(duration: fade) { [weak stick] _, elapsed in
            lifetime.perform(ifCurrent: generation) {
                let u = Float(min(1, max(0, elapsed / CGFloat(fade))))
                // Withdraw along back (more positive pullBack) while fading.
                let pull = pullAtRetract + u * (retractExtra - min(0, pullAtRetract))
                drive(pull)
                stick?.setFadeOpacity(CGFloat(1 - u))
            }
        }
        let hide = SCNAction.run { [weak stick] _ in
            Task { @MainActor in
                lifetime.perform(ifCurrent: generation) { stick?.hide() }
            }
        }
        actions.append(contentsOf: [retract, hide])
        return actions
    }
}
