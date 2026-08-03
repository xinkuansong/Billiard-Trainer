import Foundation

/// List-card / filter presentation of a drill's tutorial shape.
///
/// - Note: **W8 将改读 `tutorialKind` 显式字段**；本批仅用
///   `tutorial` 是否存在 + `sections`/`formations` 结构 + `items`/`image` 有无
///   做启发式判定。W8 接入后应只改本类型的 `resolve(for:)` 一处。
enum DrillTutorialKindHeuristic: String, Equatable, CaseIterable {
    /// 无精讲
    case none
    /// 旧版（四段纯文本等，无 `items`/`image` 结构化内容）
    case legacy
    /// 新版（含 `items` 或 `image`）
    case modern
}

enum DrillTutorialKindResolver {

    /// Single replacement point for W8 (`tutorialKind` field).
    ///
    /// W8 将改读 tutorialKind：届时删除下方启发式，改为读 JSON 显式字段。
    static func resolve(for drill: DrillContent) -> DrillTutorialKindHeuristic {
        guard let tutorial = drill.tutorial else { return .none }

        let sections = flattenedSections(of: tutorial)
        guard !sections.isEmpty else { return .none }

        let hasStructuredContent = sections.contains { section in
            if let items = section.items, !items.isEmpty { return true }
            if let image = section.image, !image.isEmpty { return true }
            return false
        }
        return hasStructuredContent ? .modern : .legacy
    }

    private static func flattenedSections(of tutorial: DrillTutorial) -> [TutorialSection] {
        if let formations = tutorial.formations, !formations.isEmpty {
            return formations.flatMap(\.sections)
        }
        return tutorial.sections ?? []
    }
}
