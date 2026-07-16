import Foundation

/// Human-readable spin summary for solution tweak chips.
enum ShotSpinLabel {
    static func text(spinX: Double, spinY: Double) -> String {
        let lim = Double(CuePhysics.miscueLimitFraction)
        let h = Int((spinX / lim * 100).rounded())
        let v = Int((spinY / lim * 100).rounded())
        if h == 0 && v == 0 { return "中心球" }
        var parts: [String] = []
        if v > 0 { parts.append("高杆") } else if v < 0 { parts.append("低杆") }
        if h > 0 { parts.append("左塞") } else if h < 0 { parts.append("右塞") }
        return parts.isEmpty ? "中心球" : parts.joined()
    }
}
