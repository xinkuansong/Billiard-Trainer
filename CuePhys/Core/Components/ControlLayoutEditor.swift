import Foundation

// Legacy metadata retained for archive conversion; the old editor is retired.
extension ControlLayoutGroup {
    var title: String {
        switch self {
        case .direction: return "方向"
        case .instrument: return "杆速与打点"
        case .primary: return "主动作"
        case .replay: return "重打与回放"
        case .planning: return "规划工具"
        case .camera: return "相机"
        case .information: return "信息与读数"
        case .keyboard: return "答题键盘"
        }
    }
}
extension ControlLayoutDomain {
    var title: String {
        switch self { case .phoneLandscape: return "手机横屏"; case .padLandscape: return "平板横屏"; case .padPortrait: return "平板竖屏" }
    }
}
