import SwiftUI

// MARK: - Render Constants

/// 2D 球桌归一化渲染常量（库边宽度、球半径、袋口半径、袋口位置）。
/// 仅 `BTAngleTestTable`（角度测验静态示意图）仍在用。
///
/// 历史：动作库/详情页的 2D 球桌渲染已于 2026-06 全面改用「USDZ 球桌 2D 顶视」——
/// 缩略图走离线烘焙 PNG（`BTBakedDrillTable`），详情页走 live 场景（`DrillSceneView`）。
/// 旧的 SwiftUI Canvas 渲染器（`BTBilliardTable` / `BTDrillTableView` / `BTMiniTable`）已退役。
enum TableRender {
    static let cushionWidth: CGFloat = 0.0197
    static let ballRadius: CGFloat = 0.01125
    static let cornerPocketRadius: CGFloat = 0.01654
    static let sidePocketRadius: CGFloat = 0.01693
    static let pathLineWidth: CGFloat = 0.003

    static let pockets: [(x: CGFloat, y: CGFloat, isSide: Bool)] = [
        (-0.0165, -0.0165, false),
        ( 1.0165, -0.0165, false),
        (-0.0165,  0.5165, false),
        ( 1.0165,  0.5165, false),
        ( 0.5,    -0.0268, true),
        ( 0.5,     0.5268, true),
    ]
}
