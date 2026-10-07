import SceneKit
import Combine

/// Camera rig for angle training scenes.
/// Supports orbit mode (3D) with observation/aiming views,
/// and orthographic pan/zoom (2D top-down).
final class CameraRig: ObservableObject {

    // MARK: - Config

    struct Config {
        let aimFov: CGFloat
        let standFov: CGFloat
        let minRadius: Float
        let maxRadius: Float
        let minHeight: Float
        let maxHeight: Float
        let aimPitchRad: Float
        let standPitchRad: Float
        let dampingFactor: Float
        var usesDailyZoomBoundary = false

        static let `default` = Config(
            aimFov: AimingCameraConfig.aimFov,
            standFov: AimingCameraConfig.standFov,
            minRadius: AimingCameraConfig.aimRadius,
            maxRadius: AimingCameraConfig.standRadius,
            minHeight: AimingCameraConfig.aimHeight,
            maxHeight: AimingCameraConfig.standHeight,
            aimPitchRad: AimingCameraConfig.aimPitchRad,
            standPitchRad: AimingCameraConfig.standPitchRad,
            dampingFactor: AimingCameraConfig.dampingFactor
        )

        /// Narrower lens with a compensating dolly, preserving pivot-plane framing.
        static var dailyClearance: Config {
            let base = Self.default
            let aim: CGFloat = 28, stand: CGFloat = 32
            let nearScale = Float(tan(base.aimFov * .pi / 360) / tan(aim * .pi / 360))
            let farScale = Float(tan(base.standFov * .pi / 360) / tan(stand * .pi / 360))
            return Config(aimFov: aim, standFov: stand,
                          minRadius: base.minRadius * nearScale, maxRadius: base.maxRadius * farScale,
                          minHeight: base.minHeight * nearScale, maxHeight: base.maxHeight * farScale,
                          aimPitchRad: base.aimPitchRad, standPitchRad: -35 * .pi / 180,
                          dampingFactor: base.dampingFactor, usesDailyZoomBoundary: true)
        }
    }

    // MARK: - Smooth Pose (for animated transitions)

    struct SmoothPose {
        var yaw: Float
        var pitch: Float
        var radius: Float
        var pivot: SCNVector3
        var fov: Float
        var height: Float
    }

    enum ViewMode {
        case observation
        case aiming
    }

    enum PlayerView: String { case firstPerson, thirdPerson }
    @Published private(set) var playerView: PlayerView?
    private var playerReference: (cue: SCNVector3, aim: SCNVector3)?
    /// Opt-in for interactive shot pages; export and teaching cameras keep their configuration.
    var usesRailCameraControls = false
    /// Daily clearance owns its lens and shot-relative eye model. Other hosts keep their presets.
    var usesShotAwareCamera = false
    /// Daily clearance's continuous surface stack. Other hosts and exports keep their rig.
    var usesTwoViewCameraControls = false
    var usesSimpleCueCamera = false
    var usesMergedCamera = false
    var usesSurfaceCamera = false
    private(set) var presentsTopDown = false

    /// Explicit presentation ownership; cue updates never leave a 2D view.
    func resumePerspectivePresentation() { presentsTopDown = false }
    @Published private(set) var mergedGlobalActive = false
    var usesTwoViewPoseControl: Bool { usesTwoViewCameraControls && !mergedGlobalActive }

    @discardableResult
    func enterMergedGlobal(aim: SCNVector3?, cue: SCNVector3? = nil) -> Bool {
        guard usesMergedCamera, !temporaryTopDownActive else { return false }
        if usesSurfaceCamera {
            // Read the actually displayed heading before any fallback shot is seeded.
            // The input target or business aim can be elsewhere during a drag/transition.
            let back = cameraNode.simdOrientation.act(SIMD3<Float>(0,0,1))
            let bearing = CameraSurface.nearestOverviewBearing(yaw: atan2(back.z,back.x))
            if let cue, let aim { twoViewShotReference = (cue, aim) }
            guard let reference = twoViewShotReference else { return false }
            if twoViewCamera?.simpleShot?.surface == nil {
                guard enterPlayerView(.thirdPerson, cue: reference.cue, aim: aim ?? reference.aim, duration: 0) else { return false }
            }
            return activeTwoViewCamera().retreatSurface(cue: SIMD3(reference.cue.x,reference.cue.y,reference.cue.z),
                duration: UIAccessibility.isReduceMotionEnabled ? 0.1 : nil, bearing: bearing)
        }
        // Seed the production orbit from the actual shot camera before handing it ownership.
        beginManualOrbit()
        mergedGlobalActive = true
        return observeDailyWholeTable(aimDirection: aim)
    }

    private var twoViewCamera: TwoViewCamera?
    private var twoViewReadableInsets: UIEdgeInsets = .zero
    private var twoViewViewingContext = UUID()
    private var twoViewShotReference: (cue: SCNVector3, aim: SCNVector3)?
    var twoViewCurrentAim: SCNVector3? { twoViewShotReference?.aim }
    private struct ShotRailKey: Equatable {
        let context: UUID
        let values: [Float]
        let viewport: CGSize
        let insets: UIEdgeInsets
    }
    private var shotRailCache: (key: ShotRailKey, rail: TwoViewCamera.ShotRailProfile)?
    /// An explicit automatic entry remains an intent until it reaches the latest measured layout.
    /// Manual observations and ordinary returns never acquire this token.
    private struct PendingTwoViewEntry {
        let cue: SCNVector3
        let aim: SCNVector3
        let context: UUID
        let duration: Float
    }
    private var pendingTwoViewEntry: PendingTwoViewEntry?

    private func finishPendingTwoViewEntry(notify: Bool) {
        guard pendingTwoViewEntry != nil else { return }
        pendingTwoViewEntry = nil
        if notify { onPlayerTransitionEnded?() }
    }
    private(set) var temporaryTopDownActive = false
    private var frozenMergedFrame: TemporaryTopDownFrame?
    private var temporaryTopDownReferencePose: TwoViewCamera.Pose?
    private var temporaryTopDownLandscapeUp = SIMD3<Float>(0, 0, -1)
    private var temporaryTopDownPortraitUp = SIMD3<Float>(1, 0, 0)
    private(set) var temporaryTopDownActivationCount = 0
    private(set) var temporaryTopDownHeldSamples = 0
    private(set) var temporaryTopDownLastUp = SIMD3<Float>(1, 0, 0)
    private(set) var temporaryTopDownReferenceYaw: Float = 0
    private(set) var temporaryTopDownReferenceSource = "TP actual"
    /// World-space segment visibility through the actual table subtree; used only at FP entry.
    var twoViewTableSightlinesClear: ((SIMD3<Float>, [SIMD3<Float>]) -> Bool)?
    var twoViewMode: PlayerView { twoViewCamera?.mode ?? .thirdPerson }
    var twoViewOwnerIsManual: Bool { twoViewCamera?.owner == .manual }
    var twoViewRequestRevision: UInt64 { twoViewCamera?.requestRevision ?? 0 }
    var twoViewSnapshot: TwoViewCamera.Snapshot? { twoViewCamera?.snapshot() }
    var twoViewLayoutContainsSubjects: Bool? { twoViewCamera?.layoutContainsSubjects }

    func setTwoViewViewingContext(_ context: UUID) {
        guard context != twoViewViewingContext else { return }
        let hadPendingEntry = pendingTwoViewEntry != nil
        let wasTransitioning = twoViewCamera?.isTransitioning == true
        pendingTwoViewEntry = nil
        twoViewViewingContext = context
        twoViewCamera?.setViewingContext(context)
        if hadPendingEntry || (wasTransitioning && twoViewCamera?.isTransitioning == false) {
            onPlayerTransitionEnded?()
        }
    }

    func setTwoViewReadableInsets(_ insets: UIEdgeInsets) {
        guard insets != twoViewReadableInsets else { return }
        twoViewReadableInsets = insets
        refreshTwoViewProfileForLayout()
    }

    private func refreshTwoViewProfileForLayout() {
        guard usesTwoViewPoseControl, let camera = twoViewCamera else { return }
        let wasTransitioning = camera.isTransitioning
        camera.revalidateLayout(viewport: viewportSize, insets: twoViewReadableInsets)
        if usesSimpleCueCamera {
            if usesMergedCamera, !usesSurfaceCamera, let shot = twoViewShotReference { followSimpleAim(cue: shot.cue, strike: cuePose?.strike ?? shot.cue, aim: shot.aim) }
            return
        }
        if let entry = pendingTwoViewEntry {
            guard entry.context == twoViewViewingContext, camera.mode == .thirdPerson,
                  camera.owner == .automatic, !camera.temporaryObserving,
                  let profile = makeShotRail(cue: entry.cue, aim: entry.aim),
                  camera.enterShotThirdPerson(profile, duration: entry.duration) else {
                // No legal destination: cancellation is complete, not a successful camera arrival.
                finishPendingTwoViewEntry(notify: true)
                return
            }
        } else if wasTransitioning && !camera.isTransitioning {
            // Layout intentionally holds manual observation / ordinary returns; release the host's busy state.
            onPlayerTransitionEnded?()
        }
    }

    private func activeTwoViewCamera() -> TwoViewCamera {
        if let twoViewCamera { return twoViewCamera }
        let pose = TwoViewCamera.Pose(eye: cameraNode.simdPosition,
                                      orientation: cameraNode.simdOrientation,
                                      fov: Float(cameraNode.camera?.fieldOfView ?? config.standFov))
        let camera = TwoViewCamera(pose: pose)
        camera.setViewingContext(twoViewViewingContext)
        camera.revalidateLayout(viewport: viewportSize, insets: twoViewReadableInsets)
        twoViewCamera = camera
        return camera
    }

    private func applyTwoViewPose() {
        guard !presentsTopDown else { return }
        if temporaryTopDownActive { applyTemporaryTopDown(); return }
        guard let pose = twoViewCamera?.pose else { return }
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        if cameraNode.simdTransform != pose.transform { cameraNode.simdTransform = pose.transform }
        if cameraNode.camera?.fieldOfView != CGFloat(pose.fov) { cameraNode.camera?.fieldOfView = CGFloat(pose.fov) }
        cameraNode.camera?.usesOrthographicProjection = false
        SCNTransaction.commit()
    }

    /// Table rail orientation is recovered from the eye, independently of the gaze heading.
    private var twoViewOrbitBearing: Float {
        if let snapshot = twoViewCamera?.snapshot(), let profile = snapshot.profile,
           snapshot.mode == .thirdPerson {
            let offset = snapshot.pose.eye - profile.anchor
            return atan2(offset.z, offset.x)
        }
        let eye = cameraNode.simdPosition
        return hypot(eye.x, eye.z) > 0.001 ? atan2(eye.z, eye.x) : CameraRig.overviewYaw
    }

    /// Rebuild stale layout samples only on an effective TP input, retaining the visible eye.
    private func prepareTwoViewRailForInput() -> Bool {
        let camera = activeTwoViewCamera()
        guard !temporaryTopDownActive else { return false }
        guard camera.mode == .thirdPerson else { return true }
        if usesSimpleCueCamera, camera.simpleShot != nil { return true }
        if let existing = camera.shotProfile {
            if existing.context == twoViewViewingContext,
               existing.railViewport == viewportSize, existing.railInsets == twoViewReadableInsets { return true }
            guard let reference = twoViewShotReference,
                  let replacement = makeShotRail(cue: reference.cue, aim: reference.aim) else { return false }
            return camera.rebaseShotThirdPersonPreservingPose(replacement)
        }
        guard let existing = camera.profile else { return false }
        let center = SIMD3<Float>(0, tableSurfaceY, 0)
        let halfExtents = SIMD2<Float>(Float(tableOuterHalfLength), Float(tableOuterHalfWidth))
        if existing.anchor == center, existing.tableHalfExtents == halfExtents,
           existing.railViewport == viewportSize, existing.railInsets == twoViewReadableInsets,
           existing.layoutMatchesRail { return true }
        guard let generated = TwoViewCamera.RailProfile.candidate(anchor: center,
            halfExtents: halfExtents, viewport: viewportSize, insets: twoViewReadableInsets) else { return false }
        return camera.replaceThirdPersonProfilePreservingPose(generated)
    }

    private func makeShotRail(cue: SCNVector3, aim: SCNVector3) -> TwoViewCamera.ShotRailProfile? {
        let strike = cuePose?.strike ?? cue
        let subjects = observationCandidates + (observationPocket.map { [$0.position] } ?? []) + observationPocketMouth()
        let key = ShotRailKey(context: twoViewViewingContext,
            values: [cue.x, cue.y, cue.z, strike.x, strike.y, strike.z, aim.x, aim.z,
                     cuePose?.elevation ?? 0.05, tableSurfaceY,
                     Float(tableOuterHalfLength), Float(tableOuterHalfWidth)]
                + subjects.flatMap { [$0.x, $0.y, $0.z] },
            viewport: viewportSize, insets: twoViewReadableInsets)
        if let cached = shotRailCache, cached.key == key { return cached.rail }
        guard let baseline = makeShotBaseline(cue: cue, aim: aim) else { return nil }
        guard let rail = TwoViewCamera.ShotRailProfile.candidate(defaultPose: baseline,
            cue: SIMD3(cue.x, cue.y, cue.z),
            target: observationCandidates.last.flatMap { point in
                (point - cue).length() > 0.001 ? SIMD3(point.x, point.y, point.z) : nil
            },
            pocket: observationPocket.map { SIMD3($0.position.x, $0.position.y, $0.position.z) },
            pocketMouth: observationPocketMouth().map { SIMD3($0.x, $0.y, $0.z) },
            anchor: SIMD3(0, tableSurfaceY, 0),
            halfExtents: SIMD2(Float(tableOuterHalfLength), Float(tableOuterHalfWidth)),
            viewport: viewportSize, insets: twoViewReadableInsets, context: twoViewViewingContext,
            clear: twoViewTableSightlinesClear) else { return nil }
        shotRailCache = (key, rail)
        return rail
    }

    /// Reuse the daily stance and lens, while keeping the horizontal gaze on the cue axis.
    private func makeShotBaseline(cue: SCNVector3, aim: SCNVector3) -> TwoViewCamera.Pose? {
        guard let initial = Self.dailyPlayerPose(view: .thirdPerson, cue: cue,
            strike: cuePose?.strike ?? cue, aim: aim, elevation: cuePose?.elevation ?? 0.05,
            surfaceY: tableSurfaceY, viewport: viewportSize, context: observationCandidates,
            fitsObservationContext: false, pocket: observationPocket?.position,
            pocketRadius: observationPocket.map { AngleSceneCalculator.pocketMarkerRadius(index: $0.index) } ?? 0.043,
            pocketMouth: observationPocketMouth(), centersCueAxis: true) else { return nil }
        let safe = roomSafeDailyPose(initial)
        var eye = SIMD3(safe.pivot.x + cos(safe.yaw) * safe.radius,
                        tableSurfaceY + safe.height, safe.pivot.z + sin(safe.yaw) * safe.radius)
        if let clear = twoViewTableSightlinesClear {
            let balls = [SIMD3(cue.x,cue.y,cue.z)] + observationCandidates.filter {
                ($0-cue).length()>0.001
            }.map { SIMD3($0.x,$0.y,$0.z) }
            func visible(_ height: Float) -> Bool {
                let candidate=SIMD3(eye.x,height,eye.z)
                return clear(candidate,TwoViewCamera.ballSilhouettes(eye:candidate,centers:balls))
            }
            if !visible(eye.y) {
                var low=eye.y, high=max(eye.y,min(3.25,tableSurfaceY+1.8))
                guard visible(high) else { return nil }
                for _ in 0..<12 {
                    let middle=(low+high)/2
                    if visible(middle) { high=middle } else { low=middle }
                }
                eye.y=min(3.25,high+0.01)
            }
        }
        var result=TwoViewCamera.Pose.looking(eye: eye, yaw: safe.yaw, pitch: safe.pitch, fov: safe.fov)
        if eye.y > tableSurfaceY + safe.height + 0.0001 {
            // A visibility-driven eye correction changes the shot's angular extent.
            // Refit this baseline once; retaining the old lens can leave no orbit margin.
            let centers = [cue] + observationCandidates
            let r=BallPhysics.radius
            var points: [SIMD3<Float>] = []
            for center in centers {
                for x in [-r,r] { for y in [-r,r] { for z in [-r,r] {
                    points.append(SIMD3(center.x+x,center.y+y,center.z+z))
                } } }
            }
            points += observationPocketMouth().map { SIMD3($0.x,$0.y,$0.z) }
            let angles=points.map { point -> Float in
                let d=point-eye
                return atan2(d.y,-d.x*cos(safe.yaw)-d.z*sin(safe.yaw))
            }
            result = .looking(eye:eye,yaw:safe.yaw,
                pitch:((angles.min() ?? safe.pitch)+(angles.max() ?? safe.pitch))/2,fov:safe.fov)
            let halfX=Float(1-2*max(twoViewReadableInsets.left,twoViewReadableInsets.right)/viewportSize.width)
            let halfY=Float(1-2*max(twoViewReadableInsets.top,twoViewReadableInsets.bottom)/viewportSize.height)
            guard halfX>0,halfY>0 else { return nil }
            let aspect=Float(viewportSize.width/viewportSize.height)
            var tangent: Float=0
            for point in points {
                let local=result.orientation.inverse.act(point-eye), depth = -local.z
                guard depth>0.01 else { return nil }
                tangent=max(tangent,abs(local.x)/(depth*aspect*halfX),abs(local.y)/(depth*halfY))
            }
            result.fov=max(safe.fov,2*atan(tangent*1.08)*180 / .pi)
            guard result.fov<=70 else { return nil }
        }
        return result
    }

    @discardableResult
    func prepareTemporaryObservation(cue: SCNVector3, aim: SCNVector3) -> Bool {
        guard usesTwoViewCameraControls, !temporaryTopDownActive else { return false }
        twoViewShotReference = (cue, aim)
        let camera = activeTwoViewCamera()
        if camera.mode == .thirdPerson, !usesSimpleCueCamera {
            guard let profile = makeShotRail(cue: cue, aim: aim),
                  camera.rebaseShotThirdPersonPreservingPose(profile) else { return false }
        }
        guard camera.beginTemporaryObservation() else { return false }
        finishPendingTwoViewEntry(notify: true)
        return true
    }

    func endTemporaryObservation() {
        guard usesTwoViewCameraControls, !temporaryTopDownActive else { return }
        twoViewCamera?.endTemporaryObservation(duration: UIAccessibility.isReduceMotionEnabled ? 0.1 : 0.8)
    }

    /// Immutable independent overlay camera; never the main perspective camera.
    struct TemporaryTopDownFrame {
        let eye: SIMD3<Float>
        let target: SIMD3<Float>
        let up: SIMD3<Float>
        let orthographicScale: Double
        let viewport: CGSize
        let readableRect: CGRect
        var center: SIMD3<Float> { target }
        var scale: Double { orthographicScale }
        // Orthographic screen mapping: UIKit origin top-left, SceneKit XZ metres/Y-up.
        func world(at point: CGPoint, viewport: CGSize) -> SIMD3<Float> {
            let metresPerPoint = Float(2 * orthographicScale / max(1, viewport.height))
            let right = SIMD3<Float>(-up.z, 0, up.x)
            return target + right * Float(point.x - viewport.width/2) * metresPerPoint
                + up * Float(viewport.height/2 - point.y) * metresPerPoint
        }
        func screen(point: SIMD3<Float>, viewport: CGSize) -> CGPoint {
            let pointsPerMetre = Float(viewport.height / (2 * orthographicScale))
            let delta = point - target
            let right = SIMD3<Float>(-up.z, 0, up.x)
            return CGPoint(x: viewport.width/2 + CGFloat(simd_dot(delta,right) * pointsPerMetre),
                y: viewport.height/2 - CGFloat(simd_dot(delta,up) * pointsPerMetre))
        }

    }

    /// Largest canonical table fit inside the measured HUD, with a four-point rim.
    /// X is the table long axis. Landscape has screen-right +/-X; portrait has screen-up +/-X.
    static func temporaryTopDownFrame(referencePose: TwoViewCamera.Pose, viewport: CGSize,
                                      insets: UIEdgeInsets, halfLength: Float, halfWidth: Float,
                                      surfaceY: Float = 0.8, previousUp: SIMD3<Float>? = nil) -> TemporaryTopDownFrame? {
        let width = Float(viewport.width), height = Float(viewport.height)
        let readableWidth = width - Float(insets.left + insets.right)
        let readableHeight = height - Float(insets.top + insets.bottom)
        guard width.isFinite, height.isFinite, width > 24, height > 24,
              readableWidth.isFinite, readableHeight.isFinite,
              insets.left.isFinite, insets.right.isFinite, insets.top.isFinite, insets.bottom.isFinite,
              insets.left >= 0, insets.right >= 0, insets.top >= 0, insets.bottom >= 0,
              readableWidth > 24, readableHeight > 24,
              halfLength.isFinite, halfWidth.isFinite, halfLength > 0, halfWidth > 0,
              surfaceY.isFinite, referencePose.eye.x.isFinite, referencePose.eye.y.isFinite,
              referencePose.eye.z.isFinite, referencePose.orientation.vector.x.isFinite,
              referencePose.orientation.vector.y.isFinite, referencePose.orientation.vector.z.isFinite,
              referencePose.orientation.vector.w.isFinite else { return nil }
        let landscape = width >= height
        let canonicalUp = landscape ? SIMD3<Float>(0, 0, -1) : SIMD3<Float>(1, 0, 0)
        let referenceAxis = referencePose.orientation.act(landscape ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0))
        // Use the actual projected +X direction if both ends are in front of the lens.
        // At an end-on view the direction is ambiguous: retain the last canonical sign.
        func projectedLongEnd(_ x: Float) -> SIMD2<Float>? {
            let local = referencePose.orientation.inverse.act(SIMD3(x, surfaceY, 0) - referencePose.eye)
            guard -local.z > 0.01 else { return nil }
            return SIMD2(local.x / -local.z, local.y / -local.z)
        }
        var component = referenceAxis.x
        if let plus = projectedLongEnd(halfLength), let minus = projectedLongEnd(-halfLength) {
            let delta = plus - minus
            let length = simd_length(delta)
            if length > 0.00001 { component = (landscape ? delta.x : delta.y) / length }
        }
        let rememberedSign: Float = previousUp.map { simd_dot($0, canonicalUp) < 0 ? -1 : 1 } ?? 1
        let sign: Float = abs(component) <= 0.08 ? rememberedSign : (component < 0 ? -1 : 1)
        let up = canonicalUp * sign
        let right = SIMD3<Float>(-up.z, 0, up.x)
        let halfVertical = landscape ? halfWidth : halfLength
        let halfHorizontal = landscape ? halfLength : halfWidth
        let rim: Float = 4 // Display breathing room; not a geometry or physics margin.
        let scale = max(halfVertical * height / (readableHeight - 2 * rim),
                        halfHorizontal * height / (readableWidth - 2 * rim))
        let offsetX = Float(insets.left - insets.right) * 0.5
        let offsetY = Float(insets.top - insets.bottom) * 0.5
        var center = (-right * offsetX + up * offsetY) * (2 * scale / height)
        center.y = surfaceY
        return TemporaryTopDownFrame(eye: center + SIMD3(0, 5, 0), target: center, up: up,
            orthographicScale: Double(scale), viewport: viewport,
            readableRect: CGRect(x: insets.left, y: insets.top,
                width: CGFloat(readableWidth), height: CGFloat(readableHeight)))
    }

    /// Refit on layout changes using the activation's actual pose, so repeated sampling cannot flip the table.
    var temporaryTopDownOverlayFrame: TemporaryTopDownFrame? {
        guard temporaryTopDownActive, let reference = temporaryTopDownReferencePose else { return nil }
        if usesMergedCamera, let frozenMergedFrame, frozenMergedFrame.viewport == viewportSize { return frozenMergedFrame }
        return Self.temporaryTopDownFrame(referencePose: reference, viewport: viewportSize,
            insets: twoViewReadableInsets, halfLength: Float(tableOuterHalfLength),
            halfWidth: Float(tableOuterHalfWidth), surfaceY: tableSurfaceY,
            previousUp: viewportSize.width >= viewportSize.height ? temporaryTopDownLandscapeUp : temporaryTopDownPortraitUp)
    }

    @discardableResult
    func beginTemporaryTopDown(aim: SCNVector3) -> Bool {
        // Keep the caller's signature; orientation belongs to the actual camera, not the cue direction.
        guard usesTwoViewCameraControls, !temporaryTopDownActive else { return false }
        let actual = TwoViewCamera.Pose(eye: cameraNode.simdPosition, orientation: cameraNode.simdOrientation,
            fov: Float(cameraNode.camera?.fieldOfView ?? config.standFov))
        let reference: TwoViewCamera.Pose
        let source: String
        if twoViewCamera?.mode == .firstPerson {
            if usesSimpleCueCamera, var shot = twoViewCamera?.simpleShot {
                shot.distance = 1.65
                reference = shot.pose
                source = "simple TP default"
            } else if let profile = twoViewCamera?.shotProfile, profile.context == twoViewViewingContext {
                reference = profile.defaultPose
                source = "shot TP default"
            } else if let shot = twoViewShotReference, let baseline = makeShotBaseline(cue: shot.cue, aim: shot.aim) {
                reference = baseline
                source = "shot TP default"
            } else if let aim = twoViewShotReference?.aim, hypot(aim.x, aim.z) > 0.0001 {
                reference = .looking(eye: actual.eye, yaw: atan2(-aim.z, -aim.x),
                    pitch: -atan2(0.90 - BallPhysics.radius, 1.65), fov: actual.fov)
                source = "shot TP axis"
            } else { return false }
        } else {
            reference = actual
            source = "TP actual"
        }
        guard Self.temporaryTopDownFrame(referencePose: reference, viewport: viewportSize,
            insets: twoViewReadableInsets, halfLength: Float(tableOuterHalfLength),
            halfWidth: Float(tableOuterHalfWidth), surfaceY: tableSurfaceY,
            previousUp: viewportSize.width >= viewportSize.height ? temporaryTopDownLandscapeUp : temporaryTopDownPortraitUp) != nil else { return false }
        temporaryTopDownReferencePose = reference
        temporaryTopDownReferenceYaw = atan2(-reference.forward.z, -reference.forward.x)
        temporaryTopDownReferenceSource = source
        temporaryTopDownActive = true
        if usesMergedCamera {
            frozenMergedFrame = temporaryTopDownOverlayFrame
            if !mergedGlobalActive, let camera = twoViewCamera { camera.restore(camera.snapshot()) }
            else { targetYaw = currentYaw; targetPivot = currentPivot; targetOrbit = currentOrbit; overviewYawSpeed = nil }
            onPlayerTransitionEnded?()
        }
        temporaryTopDownActivationCount += 1
        temporaryTopDownHeldSamples = 0
        applyTemporaryTopDown()
        return true
    }

    private func applyTemporaryTopDown() {
        guard let frame = temporaryTopDownOverlayFrame else { return }
        temporaryTopDownLastUp = frame.up
        if viewportSize.width >= viewportSize.height { temporaryTopDownLandscapeUp = frame.up }
        else { temporaryTopDownPortraitUp = frame.up }
        temporaryTopDownHeldSamples += 1
        // Overlay owns its independent camera. Main transform, lens and projection remain untouched.
    }

    func endTemporaryTopDown() {
        guard temporaryTopDownActive else { return }
        temporaryTopDownActive = false
        frozenMergedFrame = nil
        temporaryTopDownReferencePose = nil
    }

    @discardableResult
    private func enterTwoViewThirdPerson(wholeTable: Bool, yaw: Float, duration: Float) -> Bool {
        let center = SIMD3<Float>(0, tableSurfaceY, 0)
        let halfExtents = SIMD2<Float>(Float(tableOuterHalfLength), Float(tableOuterHalfWidth))
        let profile: TwoViewCamera.RailProfile
        if let existing = twoViewCamera?.profile,
           existing.anchor == center, existing.tableHalfExtents == halfExtents,
           existing.railViewport == viewportSize, existing.railInsets == twoViewReadableInsets,
           existing.viewport == viewportSize, existing.readableInsets == twoViewReadableInsets {
            profile = existing
        } else {
            guard let generated = TwoViewCamera.RailProfile.candidate(anchor: center,
                halfExtents: halfExtents, viewport: viewportSize, insets: twoViewReadableInsets) else { return false }
            profile = generated
        }
        let entryProgress: Float = wholeTable ? 1 : profile.entryProgress(yaw: yaw)
        guard profile.legalPose(yaw: yaw, progress: entryProgress) != nil else { return false }
        disableSmoothPoseControl()
        currentOrbit = nil
        targetOrbit = nil
        activeTwoViewCamera().enterThirdPerson(profile, yaw: yaw, duration: duration,
            progress: entryProgress)
        playerView = .thirdPerson
        keepsWholeTableFramed = entryProgress >= 0.999
        currentViewMode = .observation
        return true
    }

    #if DEBUG
    // Explicitly enabled by the daily-clearance preview host only. Nil preserves production.
    enum DailyPreviewProfile: Int, CaseIterable {
        case current, classic, standing
        var title: String {
            switch self {
            case .current: return "A · 每日现状"
            case .classic: return "B · 旧版站位"
            case .standing: return "C · 蛇彩站位"
            }
        }
    }
    var dailyOverviewPreviewDegrees: Float?
    var dailyPreviewProfile: DailyPreviewProfile?
    var dailyPreviewSteadyInput = false
    private var dailyPreviewIsObserver = false

    static func dailyPreviewPose(profile: DailyPreviewProfile, cue: SCNVector3,
                                 aim: SCNVector3, surfaceY: Float,
                                 halfLength: Float, halfWidth: Float) -> SmoothPose? {
        guard profile != .current,
              var pose = playerPose(view: .thirdPerson, cue: cue, aim: aim,
                  surfaceY: surfaceY, halfLength: halfLength, halfWidth: halfWidth) else { return nil }
        if profile == .standing {
            let direction = SCNVector3(aim.x, 0, aim.z).normalized()
            // Same backwards-ray intersection as classic. Move 12 cm back and gaze 25 cm farther.
            pose.radius += 0.12 + 0.25
            pose.pivot = SCNVector3(cue.x + direction.x * 0.60, surfaceY,
                                    cue.z + direction.z * 0.60)
            pose.height = 0.80
            pose.pitch = -atan2(pose.height, pose.radius)
        }
        return pose
    }
    #endif
    var observationCandidates: [SCNVector3] = []
    var observationPocket: (index: Int, position: SCNVector3)?
    private var cuePose: (strike: SCNVector3, aim: SCNVector3, elevation: Float)?
    private var railZoomMaximumFOV: Float?
    var onPlayerTransitionEnded: (() -> Void)?
    var onManualCameraControl: (() -> Void)?
    private var retainsExactTransitionPose = false
    /// Daily 3D opts in. Keep the existing per-frame path for other hosts and exports.
    var avoidsRedundantPerspectiveWrites = false {
        didSet { if !avoidsRedundantPerspectiveWrites { appliedPerspectiveTransform = nil } }
    }

    private struct PerspectiveTransformInput: Equatable {
        let pivot: SIMD3<Float>
        let yaw: Float
        let zoom: Float
        let orbit: OrbitState?
    }

    private struct AppliedPerspectiveTransform {
        let input: PerspectiveTransformInput
        let transform: SCNMatrix4
        let camera: SCNCamera?
        let fieldOfView: CGFloat?
        let usesOrthographicProjection: Bool?
    }

    private var appliedPerspectiveTransform: AppliedPerspectiveTransform?

    /// Limit horizontal coverage on wide viewports; portrait retains a comfortable vertical lens.
    static func dailyFOV(viewport: CGSize, close: Bool = false) -> Float {
        let aspect = max(0.1, Float(viewport.width / max(1, viewport.height)))
        let horizontal: Float = close ? 26 : 56
        return min(close ? 18 : 40, 2 * atan(tan(horizontal * .pi / 360) / aspect) * 180 / .pi)
    }

    /// XZ metres, Y up. Eye is above the actual shaft; backswing does not move the head.
    static func dailyPlayerPose(view: PlayerView, cue: SCNVector3, strike: SCNVector3,
                                aim: SCNVector3, elevation: Float, surfaceY: Float,
                                viewport: CGSize, focus: SCNVector3? = nil,
                                context: [SCNVector3] = [], fitsObservationContext: Bool = true,
                                pocket: SCNVector3? = nil, pocketRadius: Float = 0.043,
                                pocketMouth: [SCNVector3] = [], centersCueAxis: Bool = false) -> SmoothPose? {
        let length = hypot(aim.x, aim.z)
        guard length > 0.0001, length.isFinite, elevation.isFinite,
              cue.x.isFinite, cue.y.isFinite, cue.z.isFinite else { return nil }
        if view == .thirdPerson, !fitsObservationContext, pocket != nil || centersCueAxis {
            return dailyObservationPose(cue: cue, strike: strike, aim: aim, elevation: elevation,
                surfaceY: surfaceY, viewport: viewport, target: context.last ?? focus ?? cue,
                pocket: pocket, pocketRadius: pocketRadius, pocketMouth: pocketMouth,
                centersCueAxis: centersCueAxis)
        }
        let dx = aim.x / length, dz = aim.z / length
        let alongShaft: Float = 0.90
        let eyeGap: Float = 0.13
        let horizontal = view == .firstPerson ? alongShaft * cos(elevation) : 1.65
        let eyeY = view == .firstPerson
            ? strike.y + alongShaft * sin(elevation) + eyeGap
            : max(surfaceY + 0.90, strike.y + horizontal * tan(elevation) + 0.35)
        let pivot = focus ?? cue
        let eye = SCNVector3(strike.x - dx * horizontal, eyeY, strike.z - dz * horizontal)
        let offset = eye - pivot
        let radius = hypot(offset.x, offset.z)
        let distance = offset.length()
        let fov = dailyFOV(viewport: viewport)
        var pitch = -atan2(offset.y, radius)
        let yaw = atan2(offset.z, offset.x)
        if view == .firstPerson, let target = context.last,
           (target.x - cue.x) * dx + (target.z - cue.z) * dz > BallPhysics.radius * 2 {
            let targetPitch = atan2(target.y - eye.y, hypot(target.x - eye.x, target.z - eye.z))
            // A raised cue needs a little upward gaze, not a lower eye or a wider lens.
            // Keep the cue within the central 65% of the vertical field even on steep shots.
            pitch += max(0, min((targetPitch - pitch) * 0.5, fov * .pi / 360 * 0.65))
        }
        var fittedDistance = distance
        if view == .thirdPerson, fitsObservationContext {
            // Keep both balls clear of the edge HUD when the target becomes the centre.
            let right = SCNVector3(-sin(yaw), 0, cos(yaw))
            let up = SCNVector3(-cos(yaw) * sin(-pitch), cos(-pitch), -sin(yaw) * sin(-pitch))
            let back = offset.normalized()
            let tanV = tan(fov * .pi / 360) * 0.65
            let tanH = tanV * Float(viewport.width / max(1, viewport.height))
            for point in [cue, pivot] + context {
                let v = point - pivot
                let depth = v.x * back.x + v.y * back.y + v.z * back.z
                let x = abs(v.x * right.x + v.y * right.y + v.z * right.z) + 0.08
                let y = abs(v.x * up.x + v.y * up.y + v.z * up.z) + 0.08
                fittedDistance = max(fittedDistance, depth + x / max(0.01, tanH), depth + y / tanV)
            }
        }
        let scale = fittedDistance / max(0.001, distance)
        return SmoothPose(yaw: yaw, pitch: pitch, radius: radius * scale, pivot: pivot,
                          fov: fov, height: pivot.y - surfaceY + offset.y * scale)
    }

    /// Frame the shot's two balls and pocket marker envelope, rather than locking gaze to the cue.
    /// Keep the eye above the shaft; near a cushion shorten setback to clear the ball's lower edge.
    private static func dailyObservationPose(cue: SCNVector3, strike: SCNVector3, aim: SCNVector3,
                                             elevation: Float, surfaceY: Float, viewport: CGSize,
                                             target: SCNVector3, pocket: SCNVector3?,
                                             pocketRadius: Float, pocketMouth: [SCNVector3],
                                             centersCueAxis: Bool = false) -> SmoothPose? {
        let length = hypot(aim.x, aim.z), aspect = max(0.1, Float(viewport.width / max(1, viewport.height)))
        let dx = aim.x / length, dz = aim.z / length
        let halfX = AngleSceneCalculator.innerLength / 2, halfZ = AngleSceneCalculator.innerWidth / 2
        let tx = abs(dx) > 0.0001 ? ((dx > 0 ? -halfX : halfX) - cue.x) / -dx : Float.infinity
        let tz = abs(dz) > 0.0001 ? ((dz > 0 ? -halfZ : halfZ) - cue.z) / -dz : Float.infinity
        let railDistance = max(0, min(tx, tz))
        let lowerY = cue.y - BallPhysics.radius * 0.9
        let railY = surfaceY + BTTablePhysics.cushionHeight
        var setback: Float = 1.65
        func eyeHeight(_ setback: Float) -> Float {
            max(surfaceY + 0.90, strike.y + setback * tan(elevation) + 0.35)
        }
        if railY > lowerY, railDistance > 0 {
            for _ in 0..<8 {
                setback = min(setback, railDistance * (eyeHeight(setback) - lowerY) / (railY - lowerY))
            }
        }
        func eyeAt(_ horizontal: Float) -> SCNVector3 {
            SCNVector3(strike.x - dx * horizontal, eyeHeight(horizontal), strike.z - dz * horizontal)
        }
        func outlineSeparation(from eye: SCNVector3) -> Float {
            let a = cue - eye, b = target - eye
            let al = a.length(), bl = b.length()
            guard al > BallPhysics.radius, bl > BallPhysics.radius else { return 0 }
            let dot = (a.x*b.x + a.y*b.y + a.z*b.z) / (al*bl)
            let angle = acos(max(-1, min(1, dot)))
            return angle / (asin(BallPhysics.radius/al) + asin(BallPhysics.radius/bl))
        }
        // Lens/gaze changes do not remove one ball blocking another. For short shots,
        // move closer to give a steeper sightline; prefer at least 0.65 outline separation.
        // This is a bounded visibility preference, not a promise of zero sphere overlap.
        let minimumSetback = min(setback, Float(0.90))
        if (target - cue).length() >= BallPhysics.radius * 2, outlineSeparation(from: eyeAt(setback)) < 0.65 {
            if outlineSeparation(from: eyeAt(minimumSetback)) < 0.65 {
                setback = minimumSetback
            } else {
                var low = minimumSetback, high = setback
                for _ in 0..<20 {
                    let middle = (low+high)/2
                    if outlineSeparation(from: eyeAt(middle)) >= 0.65 { low = middle } else { high = middle }
                }
                setback = low
            }
        }
        let eye = eyeAt(setback)
        func frame(from eye: SCNVector3) -> SmoothPose? {
            var subjects: [(SCNVector3, Float)] = [(cue, BallPhysics.radius), (target, BallPhysics.radius)]
            if let pocket { subjects.append((pocket, pocketRadius)) }
            subjects.append(contentsOf: pocketMouth.map { ($0, Float(0.003)) })
            let referenceYaw = atan2(-dz, -dx)
            func unwrap(_ angle: Float) -> Float {
                referenceYaw + atan2(sin(angle - referenceYaw), cos(angle - referenceYaw))
            }
            let bearings = subjects.map { point, radius -> (Float, Float) in
                let distance = hypot(eye.x - point.x, eye.z - point.z)
                let angle = unwrap(atan2(eye.z - point.z, eye.x - point.x))
                let margin = asin(min(0.99, radius / max(radius, distance)))
                return (angle - margin, angle + margin)
            }
            let yaw = centersCueAxis ? referenceYaw
                : (bearings.map { $0.0 }.min()! + bearings.map { $0.1 }.max()!) / 2
            let forward = SCNVector3(-cos(yaw), 0, -sin(yaw))
            func dot(_ a: SCNVector3, _ b: SCNVector3) -> Float { a.x*b.x + a.y*b.y + a.z*b.z }
            let vertical = subjects.map { point, radius -> (Float, Float) in
                let v = point - eye
                let angle = atan2(v.y, dot(v, forward))
                let margin = asin(min(0.99, radius / max(radius, v.length())))
                return (angle - margin, angle + margin)
            }
            let pitch = (vertical.map { $0.0 }.min()! + vertical.map { $0.1 }.max()!) / 2
            guard pitch < -0.001 else { return nil }
            let depression = -pitch
            let back = SCNVector3(cos(yaw)*cos(depression), sin(depression), sin(yaw)*cos(depression))
            let up = SCNVector3(-cos(yaw)*sin(depression), cos(depression), -sin(yaw)*sin(depression))
            let right = SCNVector3(-sin(yaw), 0, cos(yaw))
            var tanV = tan(min(Float.pi / 4, 2 * atan(tan(70 * .pi / 360) / aspect)) / 2)
            for (point, radius) in subjects {
                let v = point - eye, depth = -dot(v, back) - radius
                guard depth > 0.001 else { return nil }
                tanV = max(tanV, (abs(dot(v, up)) + radius) / depth / 0.65,
                           (abs(dot(v, right)) + radius) / depth / aspect / 0.65)
            }
            let radius = (eye.y - cue.y) / tan(depression)
            let pivot = SCNVector3(eye.x - cos(yaw)*radius, cue.y, eye.z - sin(yaw)*radius)
            let fov = 2 * atan(tanV) * 180 / .pi
            guard radius.isFinite, radius > 0, fov.isFinite, yaw.isFinite else { return nil }
            return SmoothPose(yaw: yaw, pitch: pitch, radius: radius, pivot: pivot,
                              fov: fov, height: eye.y - surfaceY)
        }
        func isNatural(_ pose: SmoothPose) -> Bool {
            let horizontal = 2 * atan(tan(pose.fov * .pi / 360) * aspect) * 180 / .pi
            return horizontal <= 85 && pose.fov <= 55
        }
        guard let baseline = frame(from: eye) else { return nil }
        if isNatural(baseline) { return baseline }
        // A wide shot on a squarer viewport can need an excessive lens. Change
        // local standing position, rather than zooming out indefinitely or clipping a subject.
        let lowerEdge = cue - SCNVector3(0, BallPhysics.radius * 0.9, 0)
        func clearsRail(_ candidate: SCNVector3) -> Bool {
            for (start, end, extent) in [(candidate.x, lowerEdge.x, halfX), (candidate.z, lowerEdge.z, halfZ)] {
                for boundary in [-extent, extent] where abs(end-start) > 0.000001 {
                    let t = (boundary-start)/(end-start)
                    if t <= 0 || t >= 1 { continue }
                    let point = candidate + (lowerEdge-candidate)*t
                    if abs(point.x) <= halfX + 0.00001 && abs(point.z) <= halfZ + 0.00001,
                       point.y < railY - 0.00002 { return false }
                }
            }
            return true
        }
        var best: SmoothPose?, bestMovement = Float.infinity
        let sideDirection = SCNVector3(-dz, 0, dx)
        // Along-cue entry cannot use a lateral eye shift without moving the cue off its horizontal axis.
        for sideStep in (centersCueAxis ? 0...0 : -4...4) {
            for riseStep in 0...3 {
                let side = Float(sideStep)*0.1, rise = Float(riseStep)*0.1
                let movement = side*side + rise*rise
                guard movement < bestMovement else { continue }
                let candidate = eye + sideDirection*side + SCNVector3(0,rise,0)
                guard abs(candidate.x) <= BakedTrainingRoom.cameraSafeHalfExtents.x,
                      abs(candidate.z) <= BakedTrainingRoom.cameraSafeHalfExtents.y,
                      clearsRail(candidate),
                      outlineSeparation(from: candidate) >= 0.65,
                      let pose = frame(from: candidate), isNatural(pose) else { continue }
                best = pose; bestMovement = movement
            }
        }
        // Impossible/invalid contexts leave the current valid camera intact.
        return best
    }

    func followSimpleAim(cue: SCNVector3, strike: SCNVector3, aim: SCNVector3) {
        guard usesSimpleCueCamera, !mergedGlobalActive, !temporaryTopDownActive else { return }
        twoViewShotReference = (cue, aim)
        twoViewCamera?.updateSimpleShot(cue: SIMD3(cue.x,cue.y,cue.z),
            strike: SIMD3(strike.x,strike.y,strike.z), aim: SIMD3(aim.x,aim.y,aim.z),
            nearPose: usesMergedCamera && !usesSurfaceCamera ? mergedNearPose(cue: cue, aim: aim) : nil)
        applyTwoViewPose()
    }

    func updateCuePose(strike: SCNVector3, aim: SCNVector3, elevation: Float, cue: SCNVector3? = nil) {
        let old = cuePose
        cuePose = (strike, aim, elevation)
        if usesTwoViewPoseControl, let cue {
            twoViewShotReference = (cue, aim)
            if usesSimpleCueCamera, !mergedGlobalActive, !temporaryTopDownActive {
                twoViewCamera?.updateSimpleShot(cue: SIMD3(cue.x,cue.y,cue.z),
                    strike: SIMD3(strike.x,strike.y,strike.z), aim: SIMD3(aim.x,aim.y,aim.z),
            nearPose: usesMergedCamera && !usesSurfaceCamera ? mergedNearPose(cue: cue, aim: aim) : nil)
                applyTwoViewPose()
            }
        }
        guard !usesTwoViewPoseControl else { return }
        guard usesShotAwareCamera, playerView == .firstPerson, let reference = playerReference,
              old.map({ ($0.strike - strike).length() > 0.0001 || ($0.aim - aim).length() > 0.0001
                  || abs($0.elevation - elevation) > 0.0001 }) == true else { return }
        enterPlayerView(.firstPerson, cue: cue ?? reference.cue, aim: aim, duration: 0.18)
    }

    /// XZ metres, Y up. Intersect the backwards shot ray with the OUTER rail rectangle.
    static func playerPose(view: PlayerView, cue: SCNVector3, aim: SCNVector3,
                           surfaceY: Float, halfLength: Float, halfWidth: Float) -> SmoothPose? {
        let length = hypot(aim.x, aim.z)
        guard length > 0.0001, length.isFinite, cue.x.isFinite, cue.z.isFinite,
              halfLength > 0, halfWidth > 0 else { return nil }
        let dx = aim.x / length, dz = aim.z / length
        let tx = abs(dx) > 0.0001 ? ((dx > 0 ? -halfLength : halfLength) - cue.x) / -dx : Float.infinity
        let tz = abs(dz) > 0.0001 ? ((dz > 0 ? -halfWidth : halfWidth) - cue.z) / -dz : Float.infinity
        let railDistance = max(0, min(tx, tz))
        let height: Float = view == .firstPerson ? 0.16 : 0.84
        let setback: Float = view == .firstPerson ? 0.25 : 0.38
        let lookAhead: Float = 0.35
        let radius = railDistance + setback + lookAhead
        let pivot = SCNVector3(cue.x + dx * lookAhead, surfaceY + BallPhysics.radius, cue.z + dz * lookAhead)
        return SmoothPose(yaw: atan2(-dz, -dx),
                          pitch: -atan2(height - BallPhysics.radius, radius),
                          radius: radius, pivot: pivot,
                          fov: view == .firstPerson ? 42 : 48, height: height)
    }

    private func observationPocketMouth() -> [SCNVector3] {
        guard let pocket = observationPocket else { return [] }
        let holes = AngleSceneCalculator.pocketPositions(surfaceY: tableSurfaceY)
        let jaws = AngleSceneCalculator.pocketJaws(surfaceY: tableSurfaceY + BTTablePhysics.cushionHeight)
        guard holes.indices.contains(pocket.index) else { return [] }
        let radius = AngleSceneCalculator.pocketDropRadius(index: pocket.index)
        return [jaws[pocket.index].0, jaws[pocket.index].1] + (0..<16).map { step in
            let angle = Float(step) * .pi / 8
            return holes[pocket.index] + SCNVector3(cos(angle)*radius, 0, sin(angle)*radius)
        }
    }

    private func mergedNearPose(cue: SCNVector3, aim: SCNVector3) -> TwoViewCamera.Pose? {
        guard let entry = Self.dailyPlayerPose(view: .firstPerson, cue: cue,
            strike: cuePose?.strike ?? cue, aim: aim, elevation: cuePose?.elevation ?? 0.05,
            surfaceY: tableSurfaceY, viewport: viewportSize, context: observationCandidates),
            let clear = twoViewTableSightlinesClear else { return nil }
        let safe = roomSafeDailyPose(entry)
        let eye = SIMD3(safe.pivot.x + cos(safe.yaw) * safe.radius,
            tableSurfaceY + safe.height, safe.pivot.z + sin(safe.yaw) * safe.radius)
        let reference = TwoViewCamera.Pose.looking(eye: eye, yaw: safe.yaw, pitch: safe.pitch, fov: safe.fov)
        let strike = cuePose?.strike ?? cue
        return TwoViewCamera.firstPersonEntry(reference: reference,
            cue: SIMD3(cue.x,cue.y,cue.z), strike: SIMD3(strike.x,strike.y,strike.z),
            target: observationCandidates.last.map { SIMD3($0.x,$0.y,$0.z) },
            viewport: viewportSize, insets: twoViewReadableInsets,
            maximumEyeY: tableSurfaceY + 1.8, clear: clear)
    }

    @discardableResult
    func enterPlayerView(_ view: PlayerView, cue: SCNVector3, aim: SCNVector3,
                         duration: Float = 0.95, focus: SCNVector3? = nil, surfaceTravel: Float = 0.5) -> Bool {
        let view: PlayerView = usesMergedCamera ? .thirdPerson : view
        if usesTwoViewCameraControls {
            guard !temporaryTopDownActive else { return false }
            resumePerspectivePresentation()
            if mergedGlobalActive { twoViewCamera = nil; mergedGlobalActive = false }
            twoViewShotReference = (cue, aim)
            if view == .thirdPerson, usesSimpleCueCamera {
                guard hypot(aim.x,aim.z) > 0.0001 else { return false }
                let strike = cuePose?.strike ?? cue
                disableSmoothPoseControl(); currentOrbit = nil; targetOrbit = nil
                let surface: CameraSurface? = usesSurfaceCamera ? CameraSurface(
                    cue: SIMD2(cue.x,cue.z), surfaceY: tableSurfaceY, viewport: viewportSize,
                    bearing: CameraSurface.bearing(cue: SIMD2(cue.x,cue.z), backwards: SIMD2(-aim.x,-aim.z)),
                    travel: surfaceTravel) : nil
                activeTwoViewCamera().enterSimpleShot(.init(cue: SIMD3(cue.x,cue.y,cue.z),
                    strike: SIMD3(strike.x,strike.y,strike.z), aim: SIMD3(aim.x,aim.y,aim.z),
                    surfaceY: tableSurfaceY, viewport: viewportSize,
                    nearPose: usesMergedCamera && !usesSurfaceCamera ? mergedNearPose(cue: cue, aim: aim) : nil,
                    usesMergedRange: usesMergedCamera, surface: surface),
                    duration: usesSurfaceCamera
                        ? (duration <= 0 || UIAccessibility.isReduceMotionEnabled ? duration : nil)
                        : min(duration,0.3))
                playerView = .thirdPerson; playerReference = (cue,aim.normalized())
                keepsWholeTableFramed = false; currentViewMode = .observation
                return true
            }
            if view == .thirdPerson {
                guard let profile = makeShotRail(cue: cue, aim: aim) else { return false }
                disableSmoothPoseControl()
                currentOrbit = nil
                targetOrbit = nil
                guard activeTwoViewCamera().enterShotThirdPerson(profile, duration: duration) else { return false }
                pendingTwoViewEntry = PendingTwoViewEntry(cue: cue, aim: aim,
                    context: twoViewViewingContext, duration: duration)
                playerView = .thirdPerson
                playerReference = (cue, aim.normalized())
                keepsWholeTableFramed = false
                currentViewMode = .observation
                return true
            }
            guard let entry = Self.dailyPlayerPose(view: .firstPerson, cue: cue,
                strike: cuePose?.strike ?? cue, aim: aim, elevation: cuePose?.elevation ?? 0.05,
                surfaceY: tableSurfaceY, viewport: viewportSize, context: observationCandidates) else { return false }
            let safe = roomSafeDailyPose(entry)
            let eye = SIMD3(safe.pivot.x + cos(safe.yaw) * safe.radius,
                            tableSurfaceY + safe.height, safe.pivot.z + sin(safe.yaw) * safe.radius)
            let reference = TwoViewCamera.Pose.looking(eye: eye, yaw: safe.yaw, pitch: safe.pitch, fov: safe.fov)
            guard let clear = twoViewTableSightlinesClear,
                  let base = TwoViewCamera.firstPersonEntry(reference: reference,
                    cue: SIMD3(cue.x, cue.y, cue.z),
                    strike: SIMD3((cuePose?.strike ?? cue).x, (cuePose?.strike ?? cue).y, (cuePose?.strike ?? cue).z),
                    target: observationCandidates.last.map { SIMD3($0.x, $0.y, $0.z) },
                    viewport: viewportSize, insets: twoViewReadableInsets,
                    maximumEyeY: tableSurfaceY + 1.8, clear: clear) else { return false }
            disableSmoothPoseControl()
            currentOrbit = nil
            targetOrbit = nil
            activeTwoViewCamera().enterFirstPerson(base, duration: duration)
            playerView = .firstPerson
            playerReference = (cue, aim.normalized())
            keepsWholeTableFramed = false
            currentViewMode = .aiming
            return true
        }
        var proposed: SmoothPose?
        if usesShotAwareCamera {
            proposed = Self.dailyPlayerPose(view: view, cue: cue, strike: cuePose?.strike ?? cue,
                aim: aim, elevation: cuePose?.elevation ?? 0.05, surfaceY: tableSurfaceY,
                viewport: viewportSize, focus: focus, context: observationCandidates,
                fitsObservationContext: !config.usesDailyZoomBoundary,
                pocket: config.usesDailyZoomBoundary ? observationPocket?.position : nil,
                pocketRadius: observationPocket.map { AngleSceneCalculator.pocketMarkerRadius(index: $0.index) } ?? 0.043,
                pocketMouth: config.usesDailyZoomBoundary ? observationPocketMouth() : [])
        } else {
            proposed = Self.playerPose(view: view, cue: cue, aim: aim, surfaceY: tableSurfaceY,
                halfLength: Float(tableOuterHalfLength), halfWidth: Float(tableOuterHalfWidth))
        }
        #if DEBUG
        if usesShotAwareCamera, view == .thirdPerson,
           let profile = dailyPreviewProfile, profile != .current {
            proposed = Self.dailyPreviewPose(profile: profile, cue: cue, aim: aim,
                surfaceY: tableSurfaceY, halfLength: Float(tableOuterHalfLength),
                halfWidth: Float(tableOuterHalfWidth))
        }
        dailyPreviewIsObserver = usesShotAwareCamera && dailyPreviewProfile != nil && view == .thirdPerson
        #endif
        guard let proposedPose = proposed else { return false }
        let pose = roomSafeDailyPose(proposedPose)
        smoothToPose(pose, duration: duration)
        if config.usesDailyZoomBoundary, view == .thirdPerson {
            let height = pose.height - (pose.pivot.y - tableSurfaceY)
            dailyObservationControls = observationPocket != nil
            dailyObservationSubjects = [cue, observationCandidates.last ?? focus ?? cue]
                + (observationPocket.map { [$0.position] } ?? []) + observationPocketMouth()
            dailyObservationMaximumDistance = hypot(pose.radius, height) * Self.dailyObservationZoomOutScale
        }
        retainsExactTransitionPose = true
        railZoomMaximumFOV = pose.fov
        playerView = view
        playerReference = (cue, aim.normalized())
        currentViewMode = view == .firstPerson ? .aiming : .observation
        return true
    }

    func isPlayerViewFor(cue: SCNVector3, aim: SCNVector3) -> Bool {
        guard playerView != nil, let reference = playerReference else { return false }
        return (reference.cue - cue).length() < 0.002 && (reference.aim - aim.normalized()).length() < 0.002
    }

    // MARK: - Observation Constants
    //
    // Mirrors `AimingCameraConfig`'s stand-pose so that:
    //   • `enterObservation` lands at `zoom == 1`, and the post-transition
    //     `applyCameraTransform` (which derives radius/height/pitch/fov from
    //     `currentZoom`) reproduces the *exact* observation pose. Otherwise
    //     the camera "comes closer" right after the transition — that was
    //     the visual regression the user reported (#1).
    //   • Vertical-swipe up to the upper bound = observation pose. So the
    //     observation toggle and the swipe gesture agree on the high view.

    private enum ObservationConfig {
        static let zoom: Float = 1.0
        static var radius: Float { AimingCameraConfig.standRadius }
        static var height: Float { AimingCameraConfig.standHeight }
        static var fov: Float { Float(AimingCameraConfig.standFov) }
        static var pitchRad: Float { AimingCameraConfig.standPitchRad }
        static let transitionSpeed: Float = 3.0
        static let returnToAimDuration: Float = 0.5
    }

    // MARK: - Properties

    private let cameraNode: SCNNode
    private let tableSurfaceY: Float
    private let config: Config

    var targetPivot: SCNVector3
    var targetZoom: Float
    var targetYaw: Float

    private(set) var currentPivot: SCNVector3
    private(set) var currentZoom: Float
    private(set) var currentYaw: Float

    var zoom: Float { currentZoom }

    /// Independent user orbit. Preset transitions keep their existing pose ladder.
    struct OrbitState: Equatable {
        var distance: Float
        var elevation: Float
        var pitchOffset: Float
        var fov: Float
    }
    private var currentOrbit: OrbitState?
    private var targetOrbit: OrbitState?
    private var overviewYawSpeed: Float?
    private var framesTableDuringOverviewTurn = false
    private var dailyZoomBaseDistance: Float?
    private var dailyObservationMaximumDistance: Float?
    private var dailyObservationControls = false
    private var dailyObservationSubjects: [SCNVector3] = []
    @Published private(set) var keepsWholeTableFramed = false
    var viewportSize: CGSize = .zero {
        didSet {
            if usesTwoViewPoseControl {
                if viewportSize != oldValue { refreshTwoViewProfileForLayout() }
                return
            }
            guard viewportSize != oldValue, keepsWholeTableFramed else { return }
            let speed = overviewYawSpeed
            let framesDuringTurn = framesTableDuringOverviewTurn
            observeWholeTable(yaw: targetYaw)   // re-fit only; a resize must not swing the view
            overviewYawSpeed = speed
            framesTableDuringOverviewTurn = framesDuringTurn
        }
    }
    private var fittedOrbitDistance: Float = 0
    var orbitDistance: Float { currentOrbit?.distance ?? hypot(captureCurrentPose().radius, captureCurrentPose().height) }
    var orbitElevation: Float { currentOrbit?.elevation ?? atan2(captureCurrentPose().height, captureCurrentPose().radius) }


    private(set) var currentViewMode: ViewMode = .observation

    // MARK: - Smooth Transition State

    private var smoothTarget: SmoothPose?
    private var smoothOrigin: SmoothPose?
    private var smoothProgress: Float = 1.0
    private var smoothDuration: Float = 0.5
    /// Last pose written to the camera node during a smooth transition.
    /// `captureCurrentPose()` returns this when an animation is in flight,
    /// so a mid-transition `smoothToPose(_:duration:)` call sees the actual
    /// visible pose as its starting origin instead of snapping back to a
    /// stale `currentZoom`-derived pose.
    private var currentInterpolatedPose: SmoothPose?
    var isTransitioning: Bool { usesTwoViewPoseControl ? (twoViewCamera?.isTransitioning ?? false) : smoothProgress < 1.0 }
    /// Automatic HUD anchoring must not translate a user-controlled observation pivot.
    var allowsCueScreenAnchor: Bool { !usesTwoViewPoseControl && currentOrbit == nil && !isTransitioning }

    /// Numerical settling floors in scene metres, yaw radians and normalized
    /// zoom; the damping law itself is unchanged. Allow Float rounding at large
    /// accumulated yaw so idle can still converge.
    var hasPendingDamping: Bool {
        if usesTwoViewPoseControl { return twoViewCamera?.hasPendingMotion ?? false }
        let precision: Float = 0.00001
        let yawPrecision = max(precision, max(abs(currentYaw), abs(targetYaw)) * Float.ulpOfOne * 32)
        let orbitPending: Bool
        if let currentOrbit, let targetOrbit {
            orbitPending = abs(currentOrbit.distance - targetOrbit.distance) > precision
                || abs(currentOrbit.elevation - targetOrbit.elevation) > precision
                || abs(currentOrbit.pitchOffset - targetOrbit.pitchOffset) > precision
                || abs(currentOrbit.fov - targetOrbit.fov) > precision
        } else { orbitPending = false }
        return orbitPending || abs(shortestAngleDelta(from: currentYaw, to: targetYaw)) > yawPrecision
            || abs(currentZoom - targetZoom) > precision
            || abs(currentPivot.x - targetPivot.x) > precision
            || abs(currentPivot.y - targetPivot.y) > precision
            || abs(currentPivot.z - targetPivot.z) > precision
    }


    /// View-only state: keeps damping and an interrupted smooth move intact across 2D.
    struct PerspectiveState {
        fileprivate let currentPivot, targetPivot: SCNVector3
        fileprivate let currentYaw, targetYaw, currentZoom, targetZoom: Float
        fileprivate let viewMode: ViewMode
        fileprivate let origin, target, interpolated: SmoothPose?
        fileprivate let progress, duration: Float
        fileprivate let transform: SCNMatrix4
        fileprivate let fieldOfView: CGFloat
        fileprivate let currentOrbit, targetOrbit: OrbitState?
        fileprivate let keepsWholeTableFramed: Bool
        fileprivate let playerView: PlayerView?
        fileprivate let playerReference: (cue: SCNVector3, aim: SCNVector3)?
        fileprivate let retainsExactTransitionPose: Bool
        fileprivate let railZoomMaximumFOV: Float?
        fileprivate let overviewYawSpeed: Float?
        fileprivate let framesTableDuringOverviewTurn: Bool
        fileprivate let dailyZoomBaseDistance: Float?
        fileprivate let dailyObservationMaximumDistance: Float?
        fileprivate let dailyObservationControls: Bool
        fileprivate let dailyObservationSubjects: [SCNVector3]
        fileprivate let mergedGlobal: Bool
        fileprivate let twoView: TwoViewCamera.Snapshot?
    }

    func capturePerspectiveState() -> PerspectiveState {
        PerspectiveState(currentPivot: currentPivot, targetPivot: targetPivot,
                         currentYaw: currentYaw, targetYaw: targetYaw,
                         currentZoom: currentZoom, targetZoom: targetZoom,
                         viewMode: currentViewMode, origin: smoothOrigin,
                         target: smoothTarget, interpolated: currentInterpolatedPose,
                         progress: smoothProgress, duration: smoothDuration,
                         transform: cameraNode.transform,
                         fieldOfView: cameraNode.camera?.fieldOfView ?? config.standFov,
                         currentOrbit: currentOrbit, targetOrbit: targetOrbit,
                         keepsWholeTableFramed: keepsWholeTableFramed, playerView: playerView,
                         playerReference: playerReference, retainsExactTransitionPose: retainsExactTransitionPose,
                         railZoomMaximumFOV: railZoomMaximumFOV,
                         overviewYawSpeed: overviewYawSpeed,
                         framesTableDuringOverviewTurn: framesTableDuringOverviewTurn,
                         dailyZoomBaseDistance: dailyZoomBaseDistance,
                         dailyObservationMaximumDistance: dailyObservationMaximumDistance,
                         dailyObservationControls: dailyObservationControls,
                         dailyObservationSubjects: dailyObservationSubjects,
                         mergedGlobal: mergedGlobalActive,
                         twoView: usesTwoViewPoseControl ? twoViewCamera?.snapshot() : nil)
    }

    func restorePerspectiveState(_ state: PerspectiveState) {
        resumePerspectivePresentation()
        mergedGlobalActive = usesMergedCamera && state.mergedGlobal
        if usesTwoViewCameraControls, let snapshot = state.twoView {
            pendingTwoViewEntry = nil
            activeTwoViewCamera().restore(snapshot)
            refreshTwoViewProfileForLayout()
            playerView = snapshot.mode
            keepsWholeTableFramed = snapshot.progress >= 0.999 && snapshot.mode == .thirdPerson
            playerReference = state.playerReference
            applyTwoViewPose()
            onPlayerTransitionEnded?()
            return
        }
        keepsWholeTableFramed = state.keepsWholeTableFramed
        playerView = state.playerView
        playerReference = state.playerReference
        retainsExactTransitionPose = state.retainsExactTransitionPose
        railZoomMaximumFOV = state.railZoomMaximumFOV
        overviewYawSpeed = state.overviewYawSpeed
        framesTableDuringOverviewTurn = state.framesTableDuringOverviewTurn
        dailyZoomBaseDistance = state.dailyZoomBaseDistance
        dailyObservationMaximumDistance = state.dailyObservationMaximumDistance
        dailyObservationControls = state.dailyObservationControls
        dailyObservationSubjects = state.dailyObservationSubjects
        currentOrbit = state.currentOrbit
        targetOrbit = state.targetOrbit
        currentPivot = state.currentPivot
        targetPivot = state.targetPivot
        currentYaw = state.currentYaw
        targetYaw = state.targetYaw
        currentZoom = state.currentZoom
        targetZoom = state.targetZoom
        currentViewMode = state.viewMode
        smoothOrigin = state.origin
        smoothTarget = state.target
        currentInterpolatedPose = state.interpolated
        smoothProgress = state.progress
        smoothDuration = state.duration
        cameraNode.transform = state.transform
        cameraNode.camera?.fieldOfView = state.fieldOfView
        cameraNode.camera?.usesOrthographicProjection = false
        if config.usesDailyZoomBoundary {
            if var live = currentInterpolatedPose, isTransitioning {
                live = roomSafeDailyPose(live)
                currentInterpolatedPose = live
                cameraNode.position = SCNVector3(currentPivot.x + cos(live.yaw) * live.radius,
                    tableSurfaceY + live.height, currentPivot.z + sin(live.yaw) * live.radius)
            } else { applyCameraTransform() }
        }
    }

    // MARK: - 2D Mode State

    /// Orthographic half-height in scene units. For rotated 2D view, this is along
    /// the table's long axis (innerLength = 2.54m), so use innerLength/2 + padding.
    var topDownOrthographicScale: Double = Double(AngleSceneCalculator.innerLength) * 0.6
    var topDownPanOffset: CGPoint = .zero

    // MARK: - Rotated top-down auto fit（统一取景，ADR-P11-08）

    /// USDZ 球桌外框实测兜底值；装桌后会由 `AngleTrainingScene` 的实测结果覆盖实例值。
    static let defaultTableOuterHalfLength: Double = 1.4055
    static let defaultTableOuterHalfWidth: Double = 0.7995
    static let defaultTableOuterAspect =
        defaultTableOuterHalfLength / defaultTableOuterHalfWidth

    /// 球桌外框半长（世界 X，rotated 顶视屏幕竖轴）。
    var tableOuterHalfLength: Double = CameraRig.defaultTableOuterHalfLength
    /// 球桌外框半宽（世界 Z，rotated 顶视屏幕横轴）。
    var tableOuterHalfWidth: Double = CameraRig.defaultTableOuterHalfWidth
    /// 取景安全余量（比例）：避免抗锯齿/阴影边缘贴边裁切。
    static let rotatedFitMargin: Double = 1.012

    /// 跨页统一球桌大小（#10）的统一正交 scale 下限。各 2D 球桌页的可视区高度受各自
    /// 顶/底控件影响而不同，纯自适应取景会让球桌「能多大就多大」⇒ 跨页大小不一。用一个
    /// 不低于常见视口自适应值的统一 scale 作为下限：常规页一律取此值 ⇒ 球桌呈现一致大小
    /// （顶/底留等量极小黑边）；仅极端窄高视口自适应值超过它时回退自适应，保证完整可见不裁切。
    /// 取值须 ≥ `tableOuterHalfLength × rotatedFitMargin`（竖轴约束），当前 ≈ 1.423。
    static let rotatedUnifiedScale: Double = 1.50

    /// 按视口宽高比把 rotated 顶视正交 scale 调到「球桌完整可见 + 双轴居中」的值。
    /// 竖轴约束：scale ≥ 半长×余量；横轴约束：scale×(W/H) ≥ 半宽×余量。再以统一 scale
    /// 兜底（取三者最大）⇒ 跨页球桌大小一致。所有 2D 球桌页共用此取景。
    func fitRotatedTable(viewSize: CGSize) {
        guard viewSize.width > 1, viewSize.height > 1 else { return }
        let fitVertical = tableOuterHalfLength * Self.rotatedFitMargin
        let fitHorizontal = tableOuterHalfWidth * Self.rotatedFitMargin
            * Double(viewSize.height / viewSize.width)
        topDownFitScale = max(fitVertical, fitHorizontal, Self.rotatedUnifiedScale)
        topDownOrthographicScale = topDownFitScale! / topDownZoom
        clampTopDownPan(viewSize: viewSize, rotated: true)
    }

    // MARK: - 2D zoom / pan (DR-296)

    /// User zoom on top of the fitted scale. 1 = whole table (the fit is the minimum size);
    /// the table can only grow. Pages that set `topDownOrthographicScale` manually keep `fit == nil`.
    private(set) var topDownZoom: Double = 1
    private(set) var topDownFitScale: Double?
    static let topDownMaxZoom: Double = 4

    /// Pinch about a focal point. `focalOffset` is the gesture centre relative to the view
    /// centre in points (+x right, +y down); the world point under it stays put.
    func applyTopDownZoom(factor: Float, focalOffset: CGPoint, viewSize: CGSize, rotated: Bool) {
        guard factor.isFinite, factor > 0.01, viewSize.height > 1 else { return }
        let before = topDownOrthographicScale
        // Pages without auto-fit set the scale themselves; their current whole-table
        // framing is the minimum size (user rule: the table never gets smaller than now).
        let fit = topDownFitScale ?? before
        topDownFitScale = fit
        topDownZoom = max(1, min(Self.topDownMaxZoom, topDownZoom * Double(factor)))
        topDownOrthographicScale = fit / topDownZoom
        // World metres per screen point before/after; keep the focal world point fixed.
        let kBefore = 2 * before / Double(viewSize.height)
        let kAfter = 2 * topDownOrthographicScale / Double(viewSize.height)
        let dk = kBefore - kAfter
        if rotated {
            // screen right = +Z, screen down = −X: world under focal = (panX − oy·k, panZ + ox·k)
            topDownPanOffset.x -= focalOffset.y * CGFloat(dk)
            topDownPanOffset.y += focalOffset.x * CGFloat(dk)
        } else {
            // screen right = +X, screen down = +Z
            topDownPanOffset.x += focalOffset.x * CGFloat(dk)
            topDownPanOffset.y += focalOffset.y * CGFloat(dk)
        }
        clampTopDownPan(viewSize: viewSize, rotated: rotated)
    }

    /// Finger translation in points → camera pan so the content follows the finger.
    func applyTopDownScreenPan(dx: CGFloat, dy: CGFloat, viewSize: CGSize, rotated: Bool) {
        guard viewSize.height > 1 else { return }
        let k = 2 * topDownOrthographicScale / Double(viewSize.height)
        if rotated {
            // screen right = +Z, screen up = +X
            topDownPanOffset.y -= dx * CGFloat(k)
            topDownPanOffset.x += dy * CGFloat(k)
        } else {
            // screen right = +X, screen up = −Z
            topDownPanOffset.x -= dx * CGFloat(k)
            topDownPanOffset.y -= dy * CGFloat(k)
        }
        clampTopDownPan(viewSize: viewSize, rotated: rotated)
    }

    /// Keep the table edge from leaving the viewport; at the fitted scale the pan is zero.
    func clampTopDownPan(viewSize: CGSize, rotated: Bool) {
        guard viewSize.width > 1, viewSize.height > 1 else { return }
        let aspect = Double(viewSize.width / viewSize.height)
        let visibleHalfV = topDownOrthographicScale
        let visibleHalfH = topDownOrthographicScale * aspect
        let maxX = max(0, (rotated ? tableOuterHalfLength - visibleHalfV : tableOuterHalfLength - visibleHalfH))
        let maxZ = max(0, (rotated ? tableOuterHalfWidth - visibleHalfH : tableOuterHalfWidth - visibleHalfV))
        topDownPanOffset.x = max(-CGFloat(maxX), min(CGFloat(maxX), topDownPanOffset.x))
        topDownPanOffset.y = max(-CGFloat(maxZ), min(CGFloat(maxZ), topDownPanOffset.y))
    }

    /// Double-tap: back to the whole-table fit.
    func resetTopDownZoom() {
        topDownZoom = 1
        topDownPanOffset = .zero
        if let fit = topDownFitScale { topDownOrthographicScale = fit }
    }

    /// 横向顶视按真实外框与视口比例自适应：屏幕竖轴对应世界 Z，横轴对应世界 X。
    /// 返回正交半高，双轴均保留 `rotatedFitMargin` 安全余量，避免固定 scale 裁掉木框。
    static func landscapeOrthographicScale(
        viewSize: CGSize,
        halfLength: Double,
        halfWidth: Double
    ) -> Double? {
        guard viewSize.width > 1, viewSize.height > 1 else { return nil }
        let fitVertical = halfWidth * rotatedFitMargin
        let fitHorizontal = halfLength * rotatedFitMargin
            * Double(viewSize.height / viewSize.width)
        return max(fitVertical, fitHorizontal)
    }

    func fitLandscapeTable(viewSize: CGSize, rotated: Bool = false) {
        guard let scale = Self.landscapeOrthographicScale(
            viewSize: viewSize,
            halfLength: rotated ? tableOuterHalfWidth : tableOuterHalfLength,
            halfWidth: rotated ? tableOuterHalfLength : tableOuterHalfWidth
        ) else { return }
        topDownFitScale = scale
        topDownOrthographicScale = scale / topDownZoom
        clampTopDownPan(viewSize: viewSize, rotated: rotated)
    }

    // MARK: - Init

    init(cameraNode: SCNNode, tableSurfaceY: Float, config: Config = .default) {
        self.cameraNode = cameraNode
        self.tableSurfaceY = tableSurfaceY
        self.config = config

        targetPivot = SCNVector3(0, tableSurfaceY, 0)
        targetZoom = 0.5
        targetYaw = Self.overviewYaw
        currentPivot = targetPivot
        currentZoom = targetZoom
        currentYaw = targetYaw

        cameraNode.camera?.fieldOfView = config.standFov
        applyCameraTransform()
    }

    // MARK: - Input handlers (3D mode)

    func handleSurfacePan(delta: SIMD2<Float>) {
        guard usesSurfaceCamera, usesTwoViewPoseControl, prepareTwoViewRailForInput(),
              activeTwoViewCamera().surfacePan(delta: delta) else { return }
        finishPendingTwoViewEntry(notify: true)
        keepsWholeTableFramed = false
        onManualCameraControl?()
    }

    func handleHorizontalSwipe(delta: Float) {
        if usesSurfaceCamera { handleSurfacePan(delta: SIMD2(delta, 0)); return }
        if usesTwoViewPoseControl {
            if delta.isFinite, delta != 0, !prepareTwoViewRailForInput() { return }
            if activeTwoViewCamera().horizontal(delta: delta) {
                if usesSurfaceCamera { applyTwoViewPose() }
                finishPendingTwoViewEntry(notify: true)
                keepsWholeTableFramed = false
                onManualCameraControl?()
            }
            return
        }
        beginManualOrbit()
        // Sensitivity 0.0025 — half of the previous value. Crucially we
        // only update `targetYaw`, not `currentYaw`: the per-frame damping
        // in `update(deltaTime:)` (dampingFactor 0.12) then eases
        // `currentYaw` toward target, giving a soft inertial follow that
        // dramatically reduces jitter compared to writing both at once.
        var sensitivity: Float = 0.0025
        #if DEBUG
        if dailyPreviewIsObserver, dailyPreviewSteadyInput { sensitivity *= 0.55 }
        #endif
        targetYaw += delta * sensitivity * observationSensitivity
    }

    func handleVerticalSwipe(delta: Float) {
        if usesSurfaceCamera { handleSurfacePan(delta: SIMD2(0, delta)); return }
        if usesTwoViewPoseControl {
            if delta.isFinite, delta != 0, !prepareTwoViewRailForInput() { return }
            if activeTwoViewCamera().vertical(delta: delta) {
                if usesSimpleCueCamera { applyTwoViewPose() }
                finishPendingTwoViewEntry(notify: true)
                keepsWholeTableFramed = false
                onManualCameraControl?()
            }
            return
        }
        beginManualOrbit()
        guard var orbit = targetOrbit else { return }
        #if DEBUG
        if dailyPreviewIsObserver, dailyPreviewSteadyInput {
            // Look up/down from the existing eye, without moving it along a vertical orbit.
            let pitch = max(-Float.pi / 3, min(-Float.pi / 45,
                -orbit.elevation + orbit.pitchOffset - delta * 0.0016 * observationSensitivity))
            orbit.pitchOffset = pitch + orbit.elevation
            targetOrbit = orbit
            return
        }
        #endif
        if dailyObservationControls {
            // Look up/down without lowering the eye through the cue or cushion.
            var lower = -Float.pi / 3, upper = -Float.pi / 90
            let eye = targetPivot + SCNVector3(cos(targetYaw)*cos(orbit.elevation), sin(orbit.elevation),
                                              sin(targetYaw)*cos(orbit.elevation)) * orbit.distance
            let forward = SCNVector3(-cos(targetYaw), 0, -sin(targetYaw))
            // Optical zoom is an explicit request to inspect a local area. Do not
            // pin its gaze to a nearly zero interval just to keep the whole shot visible.
            let isInspectingDetail = orbit.fov < (railZoomMaximumFOV ?? orbit.fov) - 0.05
            let subjects = isInspectingDetail ? [] : dailyObservationSubjects
            let halfField = orbit.fov * .pi / 360 * 0.82
            for point in subjects {
                let v = point - eye
                let depth = v.x*forward.x + v.z*forward.z
                guard depth > 0 else { continue }
                let angle = atan2(v.y, depth)
                let margin = asin(min(0.99, 0.043 / max(0.043, v.length())))
                lower = max(lower, angle + margin - halfField)
                upper = min(upper, angle - margin + halfField)
            }
            if lower > upper { lower = -Float.pi / 3; upper = -Float.pi / 90 }
            let pitch = max(lower, min(upper,
                -orbit.elevation + orbit.pitchOffset - delta * 0.0016 * observationSensitivity))
            orbit.pitchOffset = pitch + orbit.elevation
            targetOrbit = orbit
            return
        }
        // Full overhead is available; the lower bound retains the preset clearance.
        let minimumElevation = usesRailCameraControls ? Float(0.035) : atan2(config.minHeight, config.maxRadius)
        let maximumElevation = .pi / 2 + min(0, orbit.pitchOffset)
        orbit.elevation = max(minimumElevation, min(maximumElevation, orbit.elevation + delta * 0.0035 * observationSensitivity))
        targetOrbit = orbit
    }

    func handlePinch(scale: Float) {
        if usesTwoViewPoseControl {
            if scale.isFinite, scale > 0, scale != 1, !prepareTwoViewRailForInput() { return }
            if activeTwoViewCamera().pinch(scale: scale) {
                finishPendingTwoViewEntry(notify: true)
                keepsWholeTableFramed = false
                onManualCameraControl?()
            }
            return
        }
        beginManualOrbit()
        guard var orbit = targetOrbit else { return }
        #if DEBUG
        if dailyPreviewIsObserver, dailyPreviewSteadyInput {
            // Preview a bounded lens adjustment, with no re-centering or implicit mode switch.
            orbit.fov = max(24, min(60, orbit.fov / max(0.01, scale)))
            targetOrbit = orbit
            return
        }
        #endif
        if usesRailCameraControls {
            if usesShotAwareCamera, config.usesDailyZoomBoundary {
                targetOrbit = boundedDailyZoom(orbit, scale: scale)
                return
            }
            // Optical zoom inspects distant balls without dollying through the cushion.
            if railZoomMaximumFOV == nil { railZoomMaximumFOV = orbit.fov }
            if usesShotAwareCamera, scale < 0.99, orbit.fov >= railZoomMaximumFOV! - 0.01 {
                observeWholeTable(yaw: targetYaw)
                return
            }
            let minimum = usesShotAwareCamera ? Self.dailyFOV(viewport: viewportSize, close: true) : 18
            orbit.fov = max(minimum, min(railZoomMaximumFOV!, orbit.fov / max(0.01, scale)))
            targetOrbit = orbit
            return
        }
        let maximumDistance = max(fittedOrbitDistance,
                                  max(hypot(config.maxRadius, config.maxHeight),
                                      2 * hypot(Float(tableOuterHalfLength), Float(tableOuterHalfWidth))))
        orbit.distance = max(config.minRadius,
                             min(maximumDistance, orbit.distance / max(0.01, scale)))
        targetOrbit = orbit
    }

    private var observationSensitivity: Float {
        guard usesShotAwareCamera, let orbit = targetOrbit else { return 1 }
        return min(1, tan(orbit.fov * .pi / 360) / tan(Self.dailyFOV(viewport: viewportSize) * .pi / 360))
    }

    /// Resolve once at pinch start. Smoothly reorient around the chosen ball without a dolly.
    func beginObservationPinch(at point: SCNVector3?) {
        guard !usesTwoViewPoseControl else { return }
        #if DEBUG
        if dailyPreviewIsObserver, dailyPreviewSteadyInput { return }
        #endif
        guard usesShotAwareCamera else { return }
        beginManualOrbit()
        guard !dailyObservationControls, let point, var orbit = targetOrbit else { return }
        let offset = cameraNode.position - point
        guard offset.length() > 0.05 else { return }
        targetPivot = point
        targetYaw = atan2(offset.z, offset.x)
        let subjectDistanceRatio = offset.length() / orbit.distance
        if let base = dailyZoomBaseDistance { dailyZoomBaseDistance = base * subjectDistanceRatio }
        if let maximum = dailyObservationMaximumDistance { dailyObservationMaximumDistance = maximum * subjectDistanceRatio }
        orbit.distance = offset.length()
        orbit.elevation = atan2(offset.y, hypot(offset.x, offset.z))
        orbit.pitchOffset = 0
        targetOrbit = orbit
    }

    /// A gesture takes ownership from automatic framing at the currently visible pose.
    private func beginManualOrbit() {
        if overviewYawSpeed != nil {
            targetYaw = currentYaw
            targetPivot = currentPivot
            targetOrbit = currentOrbit
            dailyZoomBaseDistance = currentOrbit?.distance
        }
        overviewYawSpeed = nil
        framesTableDuringOverviewTurn = false
        onManualCameraControl?()
        playerView = nil
        playerReference = nil
        keepsWholeTableFramed = false
        if currentOrbit == nil {
            let pose = captureCurrentPose()
            let relativeHeight = pose.height - (pose.pivot.y - tableSurfaceY)
            let elevation = atan2(relativeHeight, pose.radius)
            let orbit = OrbitState(distance: hypot(pose.radius, relativeHeight), elevation: elevation,
                                   pitchOffset: pose.pitch + elevation, fov: pose.fov)
            currentOrbit = orbit
            targetOrbit = orbit
            dailyZoomBaseDistance = orbit.distance
            currentYaw = pose.yaw
            targetYaw = pose.yaw
            currentPivot = pose.pivot
            targetPivot = pose.pivot
        }
        disableSmoothPoseControl()
        currentViewMode = .observation
    }

    /// Observation is a camera intent; it has no access to selected balls or shot parameters.
    func observe(at point: SCNVector3) {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite else { return }
        beginManualOrbit()
        targetPivot = point
        targetOrbit?.pitchOffset = 0
    }

    /// Default 3D overview yaw (DR-296). `back = (cos yaw, ·, sin yaw)` ⇒ π puts the camera
    /// on the −X (foot) end looking toward +X, so the head string / break line is at the far
    /// (top) edge — the same up direction as the rotated 2D table (screen-up = +X).
    /// The old 0 looked from the head end and showed the table upside down relative to 2D.
    static let overviewYaw: Float = .pi

    /// User-selected C preset (2026-09-28): 18% dolly back from the fitted overview.
    /// Separate from the 2D fit margin and from player/aiming camera poses.
    static let overviewDistanceScale: Float = 1.18
    static let dailyOverviewAngularSpeed: Float = .pi / 3 // 60 degrees/second
    static let dailyMaximumZoomOutScale: Float = 1.08
    static let dailyObservationZoomOutScale: Float = 1.15

    /// Nearest long rail from the visible heading; cue direction breaks an exact tie.
    static func dailyOverviewYaw(currentYaw: Float, aimDirection: SCNVector3?) -> Float {
        func delta(_ from: Float, _ to: Float) -> Float { atan2(sin(to - from), cos(to - from)) }
        let positive = Float.pi / 2, negative = -Float.pi / 2
        let a = abs(delta(currentYaw, positive)), b = abs(delta(currentYaw, negative))
        if abs(a - b) > 0.00001 { return a < b ? positive : negative }
        if let aim = aimDirection, aim.x.isFinite, aim.z.isFinite, hypot(aim.x, aim.z) > 0.0001 {
            let cueYaw = atan2(-aim.z, -aim.x)
            return abs(delta(cueYaw, positive)) <= abs(delta(cueYaw, negative)) ? positive : negative
        }
        return positive
    }

    @discardableResult
    func observeDailyWholeTable(aimDirection: SCNVector3?) -> Bool {
        if usesTwoViewPoseControl {
            return enterTwoViewThirdPerson(wholeTable: true, yaw: twoViewOrbitBearing, duration: 0.5)
        }
        let center = SCNVector3(0, tableSurfaceY + BallPhysics.radius, 0)
        let wasFramed = keepsWholeTableFramed && (currentPivot - center).length() < 0.001
            && (currentOrbit?.distance ?? 0) >= wholeTableOrbit(yaw: currentYaw).distance - 0.001
        let yaw = Self.dailyOverviewYaw(currentYaw: captureCurrentPose().yaw, aimDirection: aimDirection)
        guard observeWholeTable(yaw: yaw) else { return false }
        overviewYawSpeed = Self.dailyOverviewAngularSpeed
        framesTableDuringOverviewTurn = wasFramed
        return true
    }

    /// Fits the playable table envelope, including ball height, to the actual viewport.
    /// Returns false before layout; no guessed screen aspect is substituted.
    /// - Parameter yaw: overview heading; defaults to `overviewYaw` so every "全桌" lands on
    ///   the 2D-consistent orientation. Pass `targetYaw` to re-fit without turning.
    @discardableResult
    func observeWholeTable(yaw: Float? = CameraRig.overviewYaw) -> Bool {
        if usesTwoViewPoseControl {
            return enterTwoViewThirdPerson(wholeTable: true, yaw: yaw ?? twoViewOrbitBearing, duration: 0.5)
        }
        #if DEBUG
        dailyPreviewIsObserver = false
        #endif
        guard viewportSize.width > 1, viewportSize.height > 1 else { return false }
        beginManualOrbit()
        if let yaw, yaw.isFinite { targetYaw = yaw }
        let orbit = wholeTableOrbit(yaw: targetYaw)
        dailyObservationMaximumDistance = nil
        dailyObservationControls = false
        dailyObservationSubjects = []
        railZoomMaximumFOV = orbit.fov
        fittedOrbitDistance = orbit.distance
        keepsWholeTableFramed = true
        targetPivot = SCNVector3(0, tableSurfaceY + BallPhysics.radius, 0)
        targetOrbit = orbit
        dailyZoomBaseDistance = orbit.distance
        return true
    }

    private func wholeTableOrbit(yaw: Float) -> OrbitState {
        var orbit = OrbitState(distance: 0, elevation: 0, pitchOffset: 0, fov: 0)
        orbit.elevation = abs(config.standPitchRad)
        #if DEBUG
        if config.usesDailyZoomBoundary, let degrees = dailyOverviewPreviewDegrees,
           [30, 35, 40, 45].contains(degrees) { orbit.elevation = degrees * .pi / 180 }
        #endif
        orbit.pitchOffset = 0
        orbit.fov = usesShotAwareCamera ? Self.dailyFOV(viewport: viewportSize) : Float(config.standFov)
        let back = SCNVector3(cos(yaw) * cos(orbit.elevation), sin(orbit.elevation),
                             sin(yaw) * cos(orbit.elevation))
        let right = SCNVector3(-sin(yaw), 0, cos(yaw))
        let up = SCNVector3(-cos(yaw) * sin(orbit.elevation), cos(orbit.elevation),
                           -sin(yaw) * sin(orbit.elevation))
        let tanV = tan(orbit.fov * .pi / 360)
        let tanH = tanV * Float(viewportSize.width / viewportSize.height)
        func dot(_ a: SCNVector3, _ b: SCNVector3) -> Float { a.x*b.x + a.y*b.y + a.z*b.z }
        var distance = config.minRadius
        for x in [-Float(tableOuterHalfLength), Float(tableOuterHalfLength)] {
            for z in [-Float(tableOuterHalfWidth), Float(tableOuterHalfWidth)] {
                for y in [-BallPhysics.radius, BallPhysics.radius] {
                    let offset = SCNVector3(x,y,z)
                    let depthOffset = dot(offset, back)
                    distance = max(distance, depthOffset + abs(dot(offset,right))/tanH,
                                   depthOffset + abs(dot(offset,up))/tanV)
                }
            }
        }
        orbit.distance = distance * Float(Self.rotatedFitMargin) * Self.overviewDistanceScale
        if config.usesDailyZoomBoundary {
            let center = SCNVector3(0, tableSurfaceY + BallPhysics.radius, 0)
            orbit.distance = roomSafeDailyRadius(orbit.distance * cos(orbit.elevation),
                                                 pivot: center, yaw: yaw) / cos(orbit.elevation)
            orbit.fov = max(orbit.fov, wholeTableFOV(orbit: orbit, pivot: center, yaw: yaw))
        }
        return orbit
    }

    /// Fit the outer-table corners from the actual eye when a room wall limits retreat.
    /// A wider lens keeps the complete table visible without moving the eye through a wall.
    private func wholeTableFOV(orbit: OrbitState, pivot: SCNVector3, yaw: Float) -> Float {
        let pitch = orbit.elevation - orbit.pitchOffset
        let back = SCNVector3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch))
        let right = SCNVector3(-sin(yaw), 0, cos(yaw))
        let up = SCNVector3(-cos(yaw) * sin(pitch), cos(pitch), -sin(yaw) * sin(pitch))
        let eye = pivot + SCNVector3(cos(yaw) * cos(orbit.elevation), sin(orbit.elevation),
                                     sin(yaw) * cos(orbit.elevation)) * orbit.distance
        let aspect = Float(viewportSize.width / viewportSize.height)
        func dot(_ a: SCNVector3, _ b: SCNVector3) -> Float { a.x*b.x + a.y*b.y + a.z*b.z }
        var tangent: Float = 0
        for x in [-Float(tableOuterHalfLength), Float(tableOuterHalfLength)] {
            for z in [-Float(tableOuterHalfWidth), Float(tableOuterHalfWidth)] {
                for y in [tableSurfaceY, tableSurfaceY + 2 * BallPhysics.radius] {
                    let offset = SCNVector3(x,y,z) - eye
                    let depth = max(0.001, -dot(offset,back))
                    tangent = max(tangent, abs(dot(offset,right)) / (depth * aspect),
                                  abs(dot(offset,up)) / depth)
                }
            }
        }
        return 2 * atan(tangent * Float(Self.rotatedFitMargin) * Self.overviewDistanceScale) * 180 / .pi
    }

    /// Full outer-table bounding span / viewport span, before screen clipping.
    /// X–Z table, Y up; pitchOffset changes the gaze independently of orbit elevation.
    private func tableScreenScale(orbit: OrbitState, pivot: SCNVector3, yaw: Float) -> Float? {
        let pitch = orbit.elevation - orbit.pitchOffset
        let eye = pivot + SCNVector3(cos(yaw) * cos(orbit.elevation), sin(orbit.elevation),
                                    sin(yaw) * cos(orbit.elevation)) * orbit.distance
        let back = SCNVector3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch))
        let right = SCNVector3(-sin(yaw), 0, cos(yaw))
        let up = SCNVector3(-cos(yaw) * sin(pitch), cos(pitch), -sin(yaw) * sin(pitch))
        let tanV = tan(orbit.fov * .pi / 360)
        let tanH = tanV * Float(viewportSize.width / max(1, viewportSize.height))
        func dot(_ a: SCNVector3, _ b: SCNVector3) -> Float { a.x*b.x + a.y*b.y + a.z*b.z }
        let x = Float(tableOuterHalfLength), z = Float(tableOuterHalfWidth)
        var points: [SIMD2<Float>] = []
        for (px, pz) in [(-x,-z),(x,-z),(x,z),(-x,z)] {
            let relative = SCNVector3(px, tableSurfaceY, pz) - eye
            let depth = -dot(relative, back)
            guard depth > 0.001 else { return nil }
            points.append(SIMD2(dot(relative,right) / (depth*tanH), dot(relative,up) / (depth*tanV)))
        }
        let width = (points.map(\.x).max()! - points.map(\.x).min()!) / 2
        let height = (points.map(\.y).max()! - points.map(\.y).min()!) / 2
        let scale = max(width, height)
        return scale.isFinite ? scale : nil
    }

    /// Optical zoom first, then continuous dolly, with the same minimum table scale
    /// as the long-rail overview. A pinch never changes the subject, yaw or pitch.
    private func boundedDailyZoom(_ orbit: OrbitState, scale: Float) -> OrbitState {
        guard scale.isFinite, scale > 0, viewportSize.width > 1, viewportSize.height > 1 else { return orbit }
        let normalFOV = dailyObservationControls ? (railZoomMaximumFOV ?? orbit.fov) : Self.dailyFOV(viewport: viewportSize)
        let nearFOV = Self.dailyFOV(viewport: viewportSize, close: true)
        let baseDistance = dailyZoomBaseDistance ?? orbit.distance
        dailyZoomBaseDistance = baseDistance
        func zoomed(_ factor: Float) -> OrbitState {
            var result = orbit
            var lensFactor = factor
            if factor < 1, orbit.distance > baseDistance {
                result.distance = max(baseDistance, orbit.distance * factor)
                lensFactor = factor * orbit.distance / result.distance
            }
            let desiredTan = tan(orbit.fov * .pi / 360) * lensFactor
            let maximumTan = tan(max(normalFOV, orbit.fov) * .pi / 360)
            let lensTan = max(tan(nearFOV * .pi / 360), min(maximumTan, desiredTan))
            result.fov = 2 * atan(lensTan) * 180 / .pi
            if factor > 1 { result.distance *= max(1, desiredTan / lensTan) }
            return result
        }
        let factor = 1 / max(0.01, scale)
        guard factor > 1 else { return zoomed(factor) }
        var reference = wholeTableOrbit(yaw: .pi / 2)
        reference.distance *= Self.dailyMaximumZoomOutScale
        let center = SCNVector3(0, tableSurfaceY + BallPhysics.radius, 0)
        guard let minimumScale = tableScreenScale(orbit: reference, pivot: center, yaw: .pi / 2) else { return orbit }
        if let startScale = tableScreenScale(orbit: orbit, pivot: targetPivot, yaw: targetYaw), startScale < minimumScale {
            return orbit
        }
        // A close eye may have table corners behind it. Bound that case by the
        // reference eye's enclosing distance until all corners can be projected.
        let fallbackDistance = max(orbit.distance, reference.distance + (targetPivot - center).length())
        func isAllowed(_ value: OrbitState) -> Bool {
            if let maximum = dailyObservationMaximumDistance, value.distance > maximum { return false }
            if let scale = tableScreenScale(orbit: value, pivot: targetPivot, yaw: targetYaw) { return scale >= minimumScale }
            return value.distance <= fallbackDistance
        }
        let candidate = zoomed(factor)
        if isAllowed(candidate) { return candidate }
        // Solve the pinch fraction at the boundary instead of jumping to another pose.
        var low: Float = 1, high = factor
        for _ in 0..<24 {
            let middle = (low + high) / 2
            if isAllowed(zoomed(middle)) {
                low = middle
            } else { high = middle }
        }
        return zoomed(low)
    }

    // MARK: - Input handlers (2D mode)


    // MARK: - Observation / Aiming

    func enterObservation(cueBallPosition: SCNVector3, aimDirection: SCNVector3) {
        currentViewMode = .observation
        targetPivot = SCNVector3(cueBallPosition.x, tableSurfaceY, cueBallPosition.z)

        let flatAim = SCNVector3(aimDirection.x, 0, aimDirection.z)
        let len = sqrtf(flatAim.x * flatAim.x + flatAim.z * flatAim.z)
        if len > 0.0001 {
            targetYaw = atan2(-flatAim.z / len, -flatAim.x / len)
        }

        let targetPose = SmoothPose(
            yaw: targetYaw,
            pitch: config.standPitchRad,
            radius: config.maxRadius,
            pivot: targetPivot,
            fov: Float(config.standFov),
            height: config.maxHeight
        )
        smoothToPose(targetPose, duration: 0.6)
    }

    func enterAiming(cueBallPosition: SCNVector3, targetDirection: SCNVector3, entryZoom: Float = 0.5) {
        currentViewMode = .aiming
        targetPivot = SCNVector3(cueBallPosition.x, tableSurfaceY, cueBallPosition.z)

        let flatAim = SCNVector3(targetDirection.x, 0, targetDirection.z)
        let len = sqrtf(flatAim.x * flatAim.x + flatAim.z * flatAim.z)
        if len > 0.0001 {
            targetYaw = atan2(-flatAim.z / len, -flatAim.x / len)
        }

        // Default callers enter at the midpoint; explicit cue inspection can enter lower.
        // Reset deterministically for this intent; gestures retain the full [0, 1] range.
        // Keep currentZoom intact until smoothToPose captures the visible starting pose.
        let entryZoom = min(1, max(0, entryZoom))
        let prevZoom = currentZoom
        let targetPose = SmoothPose(
            yaw: targetYaw,
            pitch: lerp(config.aimPitchRad, config.standPitchRad, entryZoom * entryZoom),
            radius: lerp(config.minRadius, config.maxRadius, entryZoom),
            pivot: targetPivot,
            fov: lerp(Float(config.aimFov), Float(config.standFov), entryZoom),
            height: lerp(config.minHeight, config.maxHeight, entryZoom)
        )
        #if DEBUG
        print(String(format:
            "[CameraRig.enterAiming] pivot=(%.3f,%.3f,%.3f) yaw=%.3f entryZoom=%.2f prevZoom=%.2f radius=%.3f height=%.3f (wasTransitioning=%d)",
            targetPivot.x, targetPivot.y, targetPivot.z, targetYaw,
            entryZoom, prevZoom, targetPose.radius, targetPose.height,
            isTransitioning ? 1 : 0))
        #endif
        // 0.6s matches `enterObservation`. Δheight ≈ 1m and Δpitch ≈ 30°,
        // so a shorter duration shows up as a perceptible "snap" mid-motion.
        smoothToPose(targetPose, duration: 0.6)
    }

    func handleObservationPan(deltaX: Float) {
        beginManualOrbit()
        let sensitivity: Float = 0.006
        targetYaw += deltaX * sensitivity
    }

    func handleObservationPinch(scale: Float) {
        handlePinch(scale: scale)
    }

    func setAimYaw(_ yaw: Float) {
        targetYaw = yaw
        currentYaw = yaw
    }

    func aimDirectionForCurrentYaw() -> SCNVector3 {
        SCNVector3(-cosf(currentYaw), 0, -sinf(currentYaw))
    }

    // MARK: - Smooth Pose Transition

    func smoothToPose(_ pose: SmoothPose, duration: Float) {
        overviewYawSpeed = nil
        framesTableDuringOverviewTurn = false
        dailyZoomBaseDistance = nil
        dailyObservationMaximumDistance = nil
        dailyObservationControls = false
        dailyObservationSubjects = []
        retainsExactTransitionPose = false
        playerView = nil
        playerReference = nil
        keepsWholeTableFramed = false
        let currentPose = captureCurrentPose()
        currentOrbit = nil
        targetOrbit = nil
        smoothOrigin = currentPose
        smoothTarget = roomSafeDailyPose(pose)
        if usesShotAwareCamera { currentInterpolatedPose = currentPose }
        smoothProgress = 0
        smoothDuration = max(0.1, duration)
    }

    /// Cancel any in-flight `smoothToPose(_:duration:)` animation and let the
    /// caller take direct control of `targetYaw / targetZoom / targetPivot`.
    /// Used by `AngleTrainingScene` before driving the camera through a
    /// 2D⇄3D mode-switch transaction.
    func disableSmoothPoseControl() {
        pendingTwoViewEntry = nil
        smoothOrigin = nil
        smoothTarget = nil
        smoothProgress = 1.0
        currentInterpolatedPose = nil
        retainsExactTransitionPose = false
        onPlayerTransitionEnded?()
    }

    /// Translate the orbit pivot by an XZ delta. With `immediate: true` both
    /// `targetPivot` and `currentPivot` are snapped (no easing), matching the
    /// reference rig's anchor-lock semantics — the cue ball stays pinned to
    /// its on-screen position while the world slides under the camera.
    func translatePivot(deltaXZ: SCNVector3, immediate: Bool) {
        let delta = SCNVector3(deltaXZ.x, 0, deltaXZ.z)
        targetPivot = SCNVector3(
            targetPivot.x + delta.x,
            targetPivot.y,
            targetPivot.z + delta.z
        )
        if immediate {
            currentPivot = SCNVector3(
                currentPivot.x + delta.x,
                currentPivot.y,
                currentPivot.z + delta.z
            )
            applyCameraTransform()
        }
    }

    func captureCurrentPose() -> SmoothPose {
        if usesTwoViewPoseControl, let pose = twoViewCamera?.pose {
            let forward = pose.forward
            let distance = forward.y < -0.0001
                ? max(0.05, (pose.eye.y - tableSurfaceY - BallPhysics.radius) / -forward.y) : 1
            let pivot = pose.eye + forward * distance
            return SmoothPose(yaw: atan2(-forward.z, -forward.x),
                pitch: asin(max(-1, min(1, forward.y))), radius: hypot(pose.eye.x - pivot.x, pose.eye.z - pivot.z),
                pivot: SCNVector3(pivot.x, pivot.y, pivot.z), fov: pose.fov, height: pose.eye.y - tableSurfaceY)
        }
        if let orbit = currentOrbit {
            return SmoothPose(yaw: currentYaw, pitch: -orbit.elevation + orbit.pitchOffset,
                              radius: orbit.distance * cos(orbit.elevation), pivot: currentPivot,
                              fov: orbit.fov,
                              height: currentPivot.y - tableSurfaceY + orbit.distance * sin(orbit.elevation))
        }
        // While a smooth transition is in flight, return the last
        // interpolated pose so that re-entering smoothToPose does not snap
        // the camera back to a stale `currentZoom`-derived starting point.
        if let live = currentInterpolatedPose, smoothProgress < 1.0 {
            return live
        }
        let z = max(0, min(1, currentZoom))
        let radius = lerp(config.minRadius, config.maxRadius, z)
        let height = lerp(config.minHeight, config.maxHeight, z)
        let pitch = lerp(config.aimPitchRad, config.standPitchRad, z * z)
        let fov = lerp(Float(config.aimFov), Float(config.standFov), z)
        return roomSafeDailyPose(SmoothPose(yaw: currentYaw, pitch: pitch, radius: radius,
            pivot: currentPivot, fov: fov, height: config.usesDailyZoomBoundary ? max(0.3, height) : height))
    }

    // MARK: - Update

    func update(deltaTime: Float) {
        // Legacy hosts prepare an explicit focus while still in 2D, before switching
        // presentation. Only the two-view controller competes with 2D cue updates.
        guard !(presentsTopDown && usesTwoViewCameraControls) else { return }
        if temporaryTopDownActive { applyTemporaryTopDown(); return }
        if usesTwoViewPoseControl, let camera = twoViewCamera {
            let wasTransitioning = camera.isTransitioning
            camera.update(deltaTime: deltaTime)
            applyTwoViewPose()
            if wasTransitioning, !camera.isTransitioning {
                finishPendingTwoViewEntry(notify: false)
                onPlayerTransitionEnded?()
            } else if pendingTwoViewEntry != nil, !camera.isTransitioning {
                // Covers cancellation by another explicit facade path before the next display update.
                finishPendingTwoViewEntry(notify: true)
            }
            return
        }
        if smoothProgress < 1.0, let origin = smoothOrigin, let target = smoothTarget {
            smoothProgress += deltaTime / smoothDuration
            smoothProgress = min(1.0, smoothProgress)
            // smootherstep (5th-order, C2-continuous): no discontinuous
            // acceleration at the endpoints, so the camera glides in / out
            // of motion instead of "tugging".
            let t = smootherStep(smoothProgress)

            currentYaw = origin.yaw + shortestAngleDelta(from: origin.yaw, to: target.yaw) * t
            currentPivot = lerpVec(origin.pivot, target.pivot, t)
            let visible = roomSafeDailyPose(SmoothPose(yaw: currentYaw,
                pitch: lerp(origin.pitch, target.pitch, t), radius: lerp(origin.radius, target.radius, t),
                pivot: currentPivot, fov: lerp(origin.fov, target.fov, t),
                height: lerp(origin.height, target.height, t)))
            let radius = visible.radius, height = visible.height
            let pitch = visible.pitch, fov = visible.fov

            // Cache the live pose so a mid-transition smoothToPose call has
            // a non-stale starting origin (see captureCurrentPose).
            currentInterpolatedPose = SmoothPose(
                yaw: currentYaw, pitch: pitch, radius: radius,
                pivot: currentPivot, fov: fov, height: height
            )

            let cameraY = tableSurfaceY + max(retainsExactTransitionPose ? 0.08 : 0.3, height)
            let forwardXZ = SCNVector3(-cosf(currentYaw), 0, -sinf(currentYaw))
            let position = SCNVector3(
                currentPivot.x - forwardXZ.x * radius,
                cameraY,
                currentPivot.z - forwardXZ.z * radius
            )
            let lookDir = (currentPivot - position).normalized()
            let yawEuler = atan2f(-lookDir.x, -lookDir.z)

            cameraNode.position = position
            cameraNode.eulerAngles = SCNVector3(pitch, yawEuler, 0)
            cameraNode.camera?.fieldOfView = CGFloat(fov)
            cameraNode.camera?.usesOrthographicProjection = false

            if smoothProgress >= 1.0 {
                targetYaw = currentYaw
                targetPivot = currentPivot
                let newZoom = (radius - config.minRadius) / max(0.001, config.maxRadius - config.minRadius)
                targetZoom = max(0, min(1, newZoom))
                currentZoom = targetZoom
                if retainsExactTransitionPose {
                    let relativeHeight = height - (currentPivot.y - tableSurfaceY)
                    let elevation = atan2(relativeHeight, radius)
                    let orbit = OrbitState(distance: hypot(radius, relativeHeight), elevation: elevation,
                                           pitchOffset: pitch + elevation, fov: fov)
                    currentOrbit = orbit
                    targetOrbit = orbit
                    retainsExactTransitionPose = false
                    onPlayerTransitionEnded?()
                }
                smoothOrigin = nil
                smoothTarget = nil
                currentInterpolatedPose = nil
            }
            return
        }

        let frameScale = max(0.25, min(2.0, deltaTime * 60))
        let t = min(1, config.dampingFactor * frameScale)

        if var orbit = currentOrbit, let target = targetOrbit {
            orbit.distance = lerp(orbit.distance, target.distance, t)
            orbit.elevation = lerp(orbit.elevation, target.elevation, t)
            orbit.pitchOffset = lerp(orbit.pitchOffset, target.pitchOffset, t)
            orbit.fov = lerp(orbit.fov, target.fov, t)
            currentOrbit = orbit
        }
        currentZoom += (targetZoom - currentZoom) * t
        let yawDelta = shortestAngleDelta(from: currentYaw, to: targetYaw)
        if let speed = overviewYawSpeed {
            let step = min(abs(yawDelta), speed * max(0, deltaTime))
            currentYaw += yawDelta < 0 ? -step : step
            if step >= abs(yawDelta) { overviewYawSpeed = nil }
        } else {
            currentYaw += yawDelta * t
        }
        currentPivot = currentPivot + (targetPivot - currentPivot) * t
        if framesTableDuringOverviewTurn, keepsWholeTableFramed, var orbit = currentOrbit {
            orbit.distance = max(orbit.distance, wholeTableOrbit(yaw: currentYaw).distance)
            currentOrbit = orbit
            if overviewYawSpeed == nil { framesTableDuringOverviewTurn = false }
        }

        applyCameraTransform()
    }

    func applyTopDown2D() {
        presentsTopDown = true
        cameraNode.camera?.usesOrthographicProjection = true
        cameraNode.camera?.orthographicScale = topDownOrthographicScale

        let panX = Float(topDownPanOffset.x)
        let panZ = Float(topDownPanOffset.y)
        cameraNode.position = SCNVector3(panX, tableSurfaceY + 5.0, panZ)
        cameraNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
    }

    /// Top-down 2D view with the table's long axis (X) appearing vertically on screen,
    /// so the table fits the phone's portrait orientation (long edge along long edge).
    func applyTopDown2DRotated() {
        presentsTopDown = true
        cameraNode.camera?.usesOrthographicProjection = true
        cameraNode.camera?.orthographicScale = topDownOrthographicScale

        let panX = Float(topDownPanOffset.x)
        let panZ = Float(topDownPanOffset.y)
        cameraNode.position = SCNVector3(panX, tableSurfaceY + 5.0, panZ)
        // Look straight down at the table center, with world +X as the screen "up" direction.
        // Using look(at:up:) avoids the euler-angle order pitfall where Rz(π/2) applied AFTER
        // Rx(-π/2) would re-orient the forward vector sideways instead of keeping it down.
        cameraNode.look(
            at: SCNVector3(panX, tableSurfaceY, panZ),
            up: SCNVector3(1, 0, 0),
            localFront: SCNVector3(0, 0, -1)
        )
    }

    func snapToTarget() {
        overviewYawSpeed = nil
        framesTableDuringOverviewTurn = false
        if let targetOrbit { currentOrbit = targetOrbit }
        currentZoom = targetZoom
        currentYaw = targetYaw
        currentPivot = targetPivot
        applyCameraTransform()
    }

    /// Sync the rig's internal pose state directly to the aim pose without
    /// running any animation. Called by `AngleTrainingScene.transitionToPerspective`
    /// once the SCNTransaction has visually placed the camera in aim pose:
    /// without this, the rig would still think it's at whatever zoom /
    /// yaw / pivot it had before the 2D toggle, and the next `update(_:)`
    /// frame would overwrite the camera's actual pose with the stale
    /// internal state — which is the visible "snap from observation to
    /// aim" wobble the user reported when toggling 2D → 3D.
    /// - Skips `applyCameraTransform()` because the caller (SCNTransaction)
    ///   has already set the camera node to the desired pose; we only
    ///   need to align internal state for future input handling.
    func snapToAimPose(pivot: SCNVector3, aimDirection: SCNVector3) {
        currentOrbit = nil
        targetOrbit = nil
        let flatAim = SCNVector3(aimDirection.x, 0, aimDirection.z)
        let len = sqrtf(flatAim.x * flatAim.x + flatAim.z * flatAim.z)
        let yaw = len > 0.0001 ? atan2(-flatAim.z / len, -flatAim.x / len) : currentYaw

        targetPivot = SCNVector3(pivot.x, tableSurfaceY, pivot.z)
        targetYaw = yaw
        targetZoom = 0
        currentPivot = targetPivot
        currentYaw = yaw
        currentZoom = 0
        currentViewMode = .aiming

        // Cancel any in-flight smooth transition so it doesn't fight the
        // freshly-snapped state.
        smoothOrigin = nil
        smoothTarget = nil
        smoothProgress = 1.0
        currentInterpolatedPose = nil
    }

    // MARK: - Private

    /// Room inner walls are authored at X ±4 / Z ±3 metres. Keep the eye
    /// 35 cm inside them, including during orbit and preset interpolation.
    /// Shorten the pivot-to-eye ray so heading and viewing angle are preserved.
    private func roomSafeDailyRadius(_ radius: Float, pivot: SCNVector3, yaw: Float) -> Float {
        guard config.usesDailyZoomBoundary else { return radius }
        let limits = BakedTrainingRoom.cameraSafeHalfExtents
        var maximum = radius
        for (coordinate, direction, extent) in [(pivot.x, cos(yaw), limits.x),
                                                 (pivot.z, sin(yaw), limits.y)] {
            if abs(direction) > 0.00001 {
                let boundary = direction > 0 ? extent : -extent
                maximum = min(maximum, max(0.01, (boundary - coordinate) / direction))
            }
        }
        return maximum
    }

    private func roomSafeDailyPose(_ pose: SmoothPose) -> SmoothPose {
        guard config.usesDailyZoomBoundary else { return pose }
        var result = pose
        result.radius = roomSafeDailyRadius(pose.radius, pivot: pose.pivot, yaw: pose.yaw)
        guard result.radius < pose.radius else { return pose }
        let relativeHeight = pose.height - (pose.pivot.y - tableSurfaceY)
        result.height = pose.pivot.y - tableSurfaceY + relativeHeight * result.radius / max(0.001, pose.radius)
        return result
    }

    private func roomSafeDailyOrbit(_ orbit: OrbitState, pivot: SCNVector3, yaw: Float) -> OrbitState {
        var result = orbit
        let cosine = cos(orbit.elevation)
        if cosine > 0.00001 {
            result.distance = roomSafeDailyRadius(orbit.distance * cosine, pivot: pivot, yaw: yaw) / cosine
        }
        let center = SCNVector3(0, tableSurfaceY + BallPhysics.radius, 0)
        if keepsWholeTableFramed, (pivot - center).length() < 0.001,
           abs(orbit.elevation - abs(config.standPitchRad)) < 0.001,
           abs(orbit.pitchOffset) < 0.001 {
            result.fov = max(result.fov, wholeTableFOV(orbit: result, pivot: pivot, yaw: yaw))
        }
        return result
    }

    private func applyCameraTransform() {
        if config.usesDailyZoomBoundary {
            if let orbit = currentOrbit { currentOrbit = roomSafeDailyOrbit(orbit, pivot: currentPivot, yaw: currentYaw) }
            if let orbit = targetOrbit { targetOrbit = roomSafeDailyOrbit(orbit, pivot: targetPivot, yaw: targetYaw) }
        }
        // Preserve the exact damping updates above. Only skip a transform whose
        // complete inputs and last-written SceneKit output are still identical.
        // Checking the output also handles external camera edits and a 2D round trip.
        let input: PerspectiveTransformInput?
        if avoidsRedundantPerspectiveWrites {
            let next = PerspectiveTransformInput(
                pivot: SIMD3(currentPivot.x, currentPivot.y, currentPivot.z),
                yaw: currentYaw, zoom: currentZoom, orbit: currentOrbit
            )
            if let applied = appliedPerspectiveTransform,
               applied.input == next,
               applied.camera === cameraNode.camera,
               applied.fieldOfView == cameraNode.camera?.fieldOfView,
               applied.usesOrthographicProjection == cameraNode.camera?.usesOrthographicProjection,
               SCNMatrix4EqualToMatrix4(applied.transform, cameraNode.transform) {
                return
            }
            input = next
        } else {
            input = nil
        }
        defer {
            if let input {
                appliedPerspectiveTransform = AppliedPerspectiveTransform(
                    input: input, transform: cameraNode.transform, camera: cameraNode.camera,
                    fieldOfView: cameraNode.camera?.fieldOfView,
                    usesOrthographicProjection: cameraNode.camera?.usesOrthographicProjection
                )
            }
        }
        if let orbit = currentOrbit {
            let radius = orbit.distance * cos(orbit.elevation)
            cameraNode.position = SCNVector3(currentPivot.x + cos(currentYaw) * radius,
                                             currentPivot.y + orbit.distance * sin(orbit.elevation),
                                             currentPivot.z + sin(currentYaw) * radius)
            let look = SCNVector3(-cos(currentYaw), 0, -sin(currentYaw))
            cameraNode.eulerAngles = SCNVector3(-orbit.elevation + orbit.pitchOffset,
                                                atan2(-look.x, -look.z), 0)
            cameraNode.camera?.fieldOfView = CGFloat(orbit.fov)
            cameraNode.camera?.usesOrthographicProjection = false
            return
        }
        let z = max(0, min(1, currentZoom))
        let visible = roomSafeDailyPose(SmoothPose(yaw: currentYaw,
            pitch: lerp(config.aimPitchRad, config.standPitchRad, z * z),
            radius: lerp(config.minRadius, config.maxRadius, z), pivot: currentPivot,
            fov: lerp(Float(config.aimFov), Float(config.standFov), z),
            height: max(0.3, lerp(config.minHeight, config.maxHeight, z))))
        let radius = visible.radius
        let cameraY = tableSurfaceY + max(0.08, visible.height)
        let pitch = visible.pitch

        let forwardXZ = SCNVector3(-cosf(currentYaw), 0, -sinf(currentYaw))
        let position = SCNVector3(
            currentPivot.x - forwardXZ.x * radius,
            cameraY,
            currentPivot.z - forwardXZ.z * radius
        )

        let lookDir = (currentPivot - position).normalized()
        let yawEuler = atan2f(-lookDir.x, -lookDir.z)

        cameraNode.position = position
        cameraNode.eulerAngles = SCNVector3(pitch, yawEuler, 0)

        let fov = CGFloat(lerp(Float(config.aimFov), Float(config.standFov), z))
        cameraNode.camera?.fieldOfView = fov
        cameraNode.camera?.usesOrthographicProjection = false
    }

    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * max(0, min(1, t))
    }

    private func lerpVec(_ a: SCNVector3, _ b: SCNVector3, _ t: Float) -> SCNVector3 {
        SCNVector3(
            a.x + (b.x - a.x) * t,
            a.y + (b.y - a.y) * t,
            a.z + (b.z - a.z) * t
        )
    }

    private func smoothStep(_ t: Float) -> Float {
        let x = max(0, min(1, t))
        return x * x * (3 - 2 * x)
    }

    /// 5th-order smootherstep (Ken Perlin). C2-continuous — first **and**
    /// second derivatives are zero at the endpoints, eliminating the slight
    /// "tug" the cubic smoothstep produces when starting/stopping a motion.
    private func smootherStep(_ t: Float) -> Float {
        let x = max(0, min(1, t))
        return x * x * x * (x * (x * 6 - 15) + 10)
    }

    private func shortestAngleDelta(from: Float, to: Float) -> Float {
        var delta = to - from
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return delta
    }
}

// MARK: - SCNVector3 helpers
//
// `normalized()` / `+` / `-` / `*` 现由 `Core/Physics/SCNVector3+Physics.swift`
// 提供模块级实现（物理引擎移植时引入）。此处原有的 file-private 扩展会与之
// 产生同签名重载歧义，故移除，统一复用模块级版本。
