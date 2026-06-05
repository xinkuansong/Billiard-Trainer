//
//  TableGeometry+QiuJi.swift
//  QiuJi
//
//  项目13 专用的球台物理几何——与渲染用的 USDZ 球台对齐。
//
//  与 vendored `TableGeometry.chineseEightBall()`（基于 01.billiard_app 的 CAD 数据）不同，
//  本工厂直接复用 `AngleSceneCalculator` 的袋口中心 / 袋口半径 / jaw 端点（这些值已按
//  当前 USDZ 模型 `TaiQiuZhuo.usdz` 实测校准），从而让物理模拟的反弹点 / 进袋判定与
//  屏幕上看到的桌面保持一致——这是把 pooltool 引擎接到项目13 的关键桥接点。
//
//  v2（探针·几何统一）：复用 `chineseEightBallCushions(y:)` 的完整库边
//  （6 直库 + 8 角袋 jaw 直线段 + 8 角袋 jaw 圆弧 + 4 中袋圆角），袋口中心 / 半径
//  取自 `AngleSceneCalculator`（与黄色标记、USDZ 模型一致）。库边几何锚定于同一组
//  内框尺寸（±innerLength/2, ±innerWidth/2），与 USDZ 袋口天然兼容；这样模拟反弹点 /
//  进袋判定与屏幕保持一致，且不再需要 ShotPredictor 里 60mm 的双真源容差。
//
//  坐标系（与 AngleSceneCalculator 一致）：X = 长轴，Z = 短轴，Y = 高度。
//

import SceneKit

extension TableGeometry {

    /// 按当前 USDZ 球台几何构建中式八球物理桌面。
    /// - Parameter surfaceY: 台面世界 Y（= `AngleTrainingScene.surfaceY`）。
    static func chineseEightBallQiuJi(surfaceY: Float) -> TableGeometry {
        let y = surfaceY

        // 库边（直库 + jaw 直线段 + jaw 圆弧 + 中袋圆角）与 CAD 版共用同一构建器。
        // P10 漏斗模型 v3：**不再**叠加喉腔「弹珠箱」（侧壁/后壁）——实测发现高恢复系数的
        // 喉腔反弹会把对准的球在腔内弹来弹去，只有恰好穿过 23mm 小孔才落袋，导致进袋带碎裂
        // （同一切角/力度下瞄准偏移每变 0.1° 就在「进/不进」间跳变，物理上不真实）。
        // 改为：保留 jaw 库（鼻尖直线段 + 鼻端圆弧）作闸口，落袋由「覆盖袋口开口的捕获圆」
        // 完成（见 AngleSceneCalculator.*PocketDropRadius）。球撞 jaw → 反弹（rattle/未进）；
        // 干净进入开口 → 落袋。进袋带因此连续而宽，符合真实袋口的导球行为。
        let cushions = TableGeometry.chineseEightBallCushions(y: y)
        let linear = cushions.linear
        let centers = AngleSceneCalculator.pocketPositions(surfaceY: y)

        // 6 个落袋孔：圆心取自 AngleSceneCalculator（与黄色标记一致），半径＝**物理落袋孔**
        // （球心进入孔内即落袋；偏离球由 jaw 闸口拦截，不靠此半径强行进球）。
        var pockets: [Pocket] = []
        pockets.reserveCapacity(centers.count)
        for (i, c) in centers.enumerated() {
            let isCorner = i < 4
            pockets.append(Pocket(
                id: "pocket_\(i)",
                center: SCNVector3(c.x, y, c.z),
                radius: AngleSceneCalculator.pocketDropRadius(index: i),
                isCorner: isCorner
            ))
        }

        return TableGeometry(
            linearCushions: linear,
            circularCushions: cushions.circular,
            pockets: pockets
        )
    }
}
