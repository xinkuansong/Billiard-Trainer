import SwiftUI

extension TablePreferencePage {
    var layoutTitle: String {
        switch self {
        case .dailyClearance: return "每日清台"
        case .freePlay: return "自由击球"
        case .shotSimulation: return "分离角与走位"
        case .snakePractice: return "蛇彩"
        case .composer: return "自由走位"
        case .drillTryout: return "动作详情试打"
        case .silu: return "思路训练"
        case .planThree: return "打一走二想三"
        case .snookerTactics: return "防守"
        case .bankShot: return "翻袋"
        case .diamondSystem: return "颗星"
        case .angleDynamic: return "角度与瞄准"
        case .separationAngleAtlas: return "分离角图谱"
        case .cushionEnglishAtlas: return "加塞吃库图谱"
        case .sceneAiming2D: return "2D角度训练"
        case .sceneAiming3D: return "3D角度训练"
        case .aimPointScene2D: return "2D瞄准点训练"
        case .aimPointScene3D: return "3D瞄准点训练"
        case .accuracy2D: return "2D准度"
        case .accuracy3D: return "3D准度"
        case .customFormationPractice: return "自定义球形练习"
        case .customFormationEditor: return "自定义球形编辑"
        default: return rawValue
        }
    }
}
extension ControlLayoutFamily {
    var title: String {
        switch self {
        case .shot: return "击球"
        case .planning: return "规划与求解"
        case .teaching: return "交互教学"
        case .angleQuiz: return "角度答题"
        case .aimPointQuiz: return "瞄准点答题"
        }
    }
    var pages: [TablePreferencePage] { TablePreferencePage.allCases.filter { $0.controlLayoutFamily == self } }
}
extension ControlLayoutAddress {
    var summary: String {
        let mode = layer == .common ? "共用" : (layer == .twoD ? "2D" : "3D")
        let field: String
        switch property {
        case .lane: field = "左右位置"
        case .offset: field = "上下位置"
        case .order: field = "组间顺序"
        case .size: field = "尺寸"
        case .cameraSlot: field = "相机位置"
        }
        return "\(domain.title) · \(mode) · \(group.title) · \(field)"
    }
}
