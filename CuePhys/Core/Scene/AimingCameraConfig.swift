import CoreGraphics
import Foundation

/// Single source of truth for the angle-training `CameraRig`'s pose ladder.
/// Mirrors `TrainingCameraConfig` from
/// `01.billiard_app/BilliardTrainer/Utilities/Constants/PhysicsConstants.swift`,
/// trimmed to what the Qiu Ji rig actually consumes.
///
/// Zoom semantics: `0` = 俯身瞄准 (low/close/wide-fov), `1` = 站立观察 (tall/far/narrow-fov).
/// All four parametric channels (radius / height / pitch / fov) are lerped on zoom.
enum AimingCameraConfig {

    // MARK: - FOV (degrees)
    static let aimFov: CGFloat = 40
    static let standFov: CGFloat = 50

    // MARK: - Radius (camera → cue-ball horizontal distance, metres)
    /// Aiming radius bumped from 1.05 → 1.3: the user wants the aim view to
    /// sit a touch further away so the wider context is visible, not a tight
    /// over-the-shoulder shot.
    static let aimRadius: Float = 1.3
    /// Stand radius bumped from 1.55 → 2.4. This is also the upper end of
    /// the vertical-swipe zoom curve, so a larger value gives the user a
    /// genuinely high overview when swiping up. Matches `Observation` so
    /// `enterObservation` lands cleanly at `zoom = 1` without a post-
    /// transition snap.
    static let standRadius: Float = 2.4

    // MARK: - Height above table surface (metres)
    /// Aim eye-line bumped from 0.22 → 0.45. 0.22m sat very low (slightly
    /// above ball-top) and felt cramped; 0.45m is roughly chin-height
    /// relative to the ball, giving a clearer down-the-line view.
    static let aimHeight: Float = 0.45
    /// Stand height bumped from 0.92 → 1.5 (the upper end of vertical
    /// swipe). Matches `Observation` so the swipe ladder and the
    /// observation pose share their endpoint.
    static let standHeight: Float = 1.5

    // MARK: - Pitch (radians, negative = looking down)
    /// Slightly steeper aim pitch (–15° → –22°) compensates for the higher
    /// eye-line so the cue ball still sits in the same place on screen.
    static let aimPitchRad: Float = -22 * .pi / 180
    /// Stand pitch matches the observation pitch — a clear bird's-eye
    /// looking down the table.
    static let standPitchRad: Float = -45 * .pi / 180

    // MARK: - Sensitivity & damping
    static let aimYawSensitivity: Float = 0.001
    static let standYawSensitivity: Float = 0.005
    static let dampingFactor: Float = 0.12
}
