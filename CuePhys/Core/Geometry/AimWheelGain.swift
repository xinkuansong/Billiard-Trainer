import Foundation

/// Aim-wheel angular gain helpers (问题集合 v23 / D-v23-4=B).
///
/// Continuous **millimeter-calibrated** gain: finger motion maps to a target
/// lateral displacement at distance `d` (cue → object / ghost), so far/near
/// shots feel equally fine in the scoring unit (`errorMM`).
///
/// \[
/// \delta_{\mathrm{deg/pt}} = \frac{s_{\mathrm{mm/pt}}/1000}{d}\cdot\frac{180}{\pi}
/// \]
///
/// Legacy pages keep `defaultDegreesPerPoint` (0.15°/pt) until W2 opts them in.
enum AimWheelGain {

    /// Pre-v23 fixed fine gain (BTAimWheel historical default).
    static let defaultDegreesPerPoint: Float = 0.15

    /// Target lateral motion at the object ball per point of finger drag (D-v23-4).
    static let targetMillimetersPerPoint: Float = 0.4

    /// Cap near-ball divergence (matches `aimNudgeDegrees` maxGainDegPerPt order).
    static let maxDegreesPerPoint: Float = 0.6

    /// Floor on lever arm so tiny `d` cannot explode gain.
    static let minLeverMeters: Float = 0.08

    /// Degrees per point for continuous mm calibration.
    static func degreesPerPoint(
        distanceMeters d: Float,
        millimetersPerPoint: Float = targetMillimetersPerPoint
    ) -> Float {
        let dClamped = max(d, minLeverMeters)
        let radPerPt = (millimetersPerPoint / 1000) / dClamped
        let deg = radPerPt * 180 / Float.pi
        return min(maxDegreesPerPoint, deg)
    }

    /// Lateral millimeters at distance `d` for a given angular gain (°/pt).
    static func millimetersPerPoint(degreesPerPoint: Float, distanceMeters d: Float) -> Float {
        let dClamped = max(d, minLeverMeters)
        let rad = degreesPerPoint * Float.pi / 180
        return rad * dClamped * 1000
    }
}
