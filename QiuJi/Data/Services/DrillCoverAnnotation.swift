import Foundation

/// E20 list-card cover / subtitle annotation derived only from drill true-source fields.
///
/// Sources (in priority order for the leading token):
/// 1. Multi-shot count — `shotIntent.shots.count` or tutorial sections titled `第…杆` (≥2)
/// 2. Spin class — first `shotIntent.shots[].spin` via existing `ShotSpinLabel` (skip「中心球」)
/// 3. Cue–target distance — measured in canvas table-length units (`.kiro/steering/table-geometry.md`),
///    shown as one decimal (`0.3台`)
/// 4. Target pocket — `shotIntent.shots[0].pocket` or `animation.pocket` (schema pocket IDs)
///
/// Missing ingredients are omitted (缺省优于编造). No per-drill name lookup / pretty subcategory map.
enum DrillCoverAnnotation {

    /// Compact cover capsule (≤2 tokens). `nil` when nothing derivable.
    static func coverLabel(for drill: DrillContent) -> String? {
        let tokens = distinctiveTokens(for: drill)
        guard !tokens.isEmpty else { return nil }
        return tokens.prefix(2).joined(separator: "·")
    }

    // MARK: - Token derivation

    private static func distinctiveTokens(for drill: DrillContent) -> [String] {
        var tokens: [String] = []

        if let shots = multiShotCount(for: drill) {
            tokens.append("\(shots)杆")
        } else if let spin = distinctiveSpinLabel(for: drill) {
            tokens.append(spin)
        } else if let dist = cueTargetDistanceLabel(for: drill) {
            tokens.append(dist)
        }

        if let pocket = pocketShortLabel(pocketID(for: drill)) {
            // Avoid "下中袋·下中袋" if distance missing and pocket already chosen as primary.
            if tokens.last != pocket {
                tokens.append(pocket)
            }
        } else if tokens.isEmpty, let dist = cueTargetDistanceLabel(for: drill) {
            tokens.append(dist)
        }

        return tokens
    }

    /// Prefer `shotIntent` ball count; also count tutorial sections named `第N杆`.
    private static func multiShotCount(for drill: DrillContent) -> Int? {
        let intentCount = drill.shotIntent?.shots.count ?? 0
        let tutorialCount = tutorialNumberedShotCount(for: drill)
        let n = max(intentCount, tutorialCount)
        return n >= 2 ? n : nil
    }

    private static func tutorialNumberedShotCount(for drill: DrillContent) -> Int {
        guard let tutorial = drill.tutorial else { return 0 }
        let sections: [TutorialSection]
        if let formations = tutorial.formations, !formations.isEmpty {
            sections = formations.flatMap(\.sections)
        } else {
            sections = tutorial.sections ?? []
        }
        return sections.reduce(0) { count, section in
            let title = section.title
            let isNumberedShot = title.hasPrefix("第") && title.contains("杆")
            return count + (isNumberedShot ? 1 : 0)
        }
    }

    private static func distinctiveSpinLabel(for drill: DrillContent) -> String? {
        guard let spin = drill.shotIntent?.shots.first?.spin else { return nil }
        let text = ShotSpinLabel.text(spinX: spin.x, spinY: spin.y)
        return text == "中心球" ? nil : text
    }

    /// Canvas units = fraction of table length (2.54 m); see table-geometry steering.
    private static func cueTargetDistanceLabel(for drill: DrillContent) -> String? {
        guard let meters = cueTargetDistanceInTableLengths(for: drill) else { return nil }
        return String(format: "%.1f", meters) + "台"
    }

    static func cueTargetDistanceInTableLengths(for drill: DrillContent) -> Double? {
        let cue: CanvasPoint
        let target: CanvasPoint
        if let shot = drill.shotIntent?.shots.first {
            cue = shot.cue
            target = shot.target
        } else {
            cue = drill.animation.cueBall.start
            target = drill.animation.targetBall.start
        }
        let dx = cue.x - target.x
        let dy = cue.y - target.y
        let d = (dx * dx + dy * dy).squareRoot()
        guard d.isFinite, d > 0 else { return nil }
        return d
    }

    private static func pocketID(for drill: DrillContent) -> String? {
        if let pocket = drill.shotIntent?.shots.first?.pocket, !pocket.isEmpty {
            return pocket
        }
        let pocket = drill.animation.pocket
        return pocket.isEmpty ? nil : pocket
    }

    /// Schema pocket ID → short Chinese (ID decode, not a per-drill glossary).
    static func pocketShortLabel(_ pocket: String?) -> String? {
        guard let pocket else { return nil }
        switch pocket {
        case "topLeft": return "左上袋"
        case "topRight": return "右上袋"
        case "topCenter": return "上中袋"
        case "bottomLeft": return "左下袋"
        case "bottomRight": return "右下袋"
        case "bottomCenter": return "下中袋"
        default: return nil
        }
    }
}
