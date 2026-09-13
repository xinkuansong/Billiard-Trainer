import Foundation

/// Stable, local appearance preference. Number/color semantics stay unchanged.
enum BallStickerStyle: String, CaseIterable, Identifiable {
    case modern, minimal, american, badge, broadcast, vintage

    static let preferenceKey = "ballStickerStyle.v1"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .modern: "现代赛事"
        case .minimal: "极简现代"
        case .american: "经典美式"
        case .badge: "粗描边徽章"
        case .broadcast: "电视竞技"
        case .vintage: "复古怀旧"
        }
    }
    var subtitle: String {
        switch self {
        case .modern: "几何数字 · 精细单圈"
        case .minimal: "大号数字 · 简洁清晰"
        case .american: "修长数字 · 双侧箭饰"
        case .badge: "粗黑描边 · 醒目徽章"
        case .broadcast: "倾斜数字 · 运动风格"
        case .vintage: "衬线数字 · 象牙白底"
        }
    }
    static func selected(in defaults: UserDefaults = .standard) -> Self {
        Self(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? .modern
    }
    func textureName(number: Int) -> String { "BallSticker_\(rawValue)_\(number)" }
    var previewName: String { "BallSticker_\(rawValue)_preview" }
}
