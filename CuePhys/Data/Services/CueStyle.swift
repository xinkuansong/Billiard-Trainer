import Foundation

enum CueKind: String, CaseIterable, Identifiable {
    case small, large
    var id: String { rawValue }
    var displayName: String { self == .small ? "小头杆" : "大头杆" }
    var detail: String { self == .small ? "剑纹前节 · 黄铜色先角" : "插花前臂 · 分区握把" }
}

/// Complete visual cue designs. Physics remains independent of cosmetics.
enum CueStyle: String, CaseIterable, Identifiable {
    case original, inkDragon, porcelain, landscape, blackGold, heritage
    case wave, orbit, racing, koi, circuit
    static let preferenceKey = "cueStyle.v1"
    var id: String { rawValue }
    var kind: CueKind? {
        switch self {
        case .original: nil
        case .inkDragon, .porcelain, .landscape, .blackGold, .heritage: .small
        case .wave, .orbit, .racing, .koi, .circuit: .large
        }
    }
    var displayName: String {
        switch self {
        case .original: "原款球杆"
        case .inkDragon: "墨龙"
        case .porcelain: "青花"
        case .landscape: "山水"
        case .blackGold: "黑金几何"
        case .heritage: "复古台球"
        case .wave: "浪潮"
        case .orbit: "星轨"
        case .racing: "赛车条纹"
        case .koi: "锦鲤"
        case .circuit: "赛博电路"
        }
    }
    var detail: String {
        switch self {
        case .original: "保留原款木纹与配色"
        case .inkDragon: "水墨龙纹后把 · 深色剑纹前节"
        case .porcelain: "青花瓷纹镶饰 · 深色剑纹前节"
        case .landscape: "水墨山水镶饰 · 蜜色剑纹前节"
        case .blackGold: "黑金几何后把 · 深色剑纹前节"
        case .heritage: "绿金八号球纹 · 暖木剑纹前节"
        case .wave: "月色浪纹前臂 · 枫木前节 · 线绕握把"
        case .orbit: "星轨行星前臂 · 枫木前节 · 皮握把"
        case .racing: "红黑赛车条纹 · 枫木前节 · 皮握把"
        case .koi: "锦鲤水纹前臂 · 枫木前节 · 线绕握把"
        case .circuit: "青绿电路前臂 · 碳纤维色前节"
        }
    }
    var resourceName: String { "Cue_" + rawValue }
    static func selected(in defaults: UserDefaults = .standard) -> Self {
        Self(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? .original
    }
}
