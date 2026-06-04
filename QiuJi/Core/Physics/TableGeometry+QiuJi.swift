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
        let cushions = TableGeometry.chineseEightBallCushions(y: y)
        var linear = cushions.linear

        // 真实袋口物理（P10 Track B-1，throat 模型）：在每个袋口的 jaw 尖端（mouth）后方挤出
        // 一个**喉腔**（两条侧壁 + 一道后壁，均为可反弹线性库）。球穿过 mouth 进入喉腔后：
        // 撞侧壁/后壁按库反弹 → 过快或偏斜的球可能弹回从 mouth 逃出（= rattle）；对准的球抵达
        // 喉腔内的落袋孔 P 即落袋。rattle 由几何+角度+速度自然涌现，而非靠放大捕获圈。
        let centers = AngleSceneCalculator.pocketPositions(surfaceY: y)
        let jaws = AngleSceneCalculator.pocketJaws(surfaceY: y)
        for i in 0..<centers.count {
            let p = SCNVector3(centers[i].x, y, centers[i].z)
            linear.append(contentsOf: throatCushions(jaw: jaws[i], pocket: p, y: y))
        }

        // 6 个落袋孔：圆心取自 AngleSceneCalculator（与黄色标记一致），半径＝**物理落袋孔**
        // （球心进入孔内即落袋；rattle 由喉腔库边产生，不靠此半径放大）。
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

    /// 由 mouth（两 jaw 尖端 j.0 / j.1）沿喉轴 n=单位(P−M) 挤出 `throatDepth`，构成喉腔的
    /// 两条侧壁（沿 n）+ 一道后壁（⊥ n）。法线一律指向喉腔内部（朝落袋孔 P 一侧），
    /// 使腔内球被正确弹回。mouth 本身不设壁（开口），故球可从此逃出 = rattle。
    private static func throatCushions(jaw: (SCNVector3, SCNVector3), pocket p: SCNVector3, y: Float)
        -> [LinearCushionSegment] {
        let j0 = SCNVector3(jaw.0.x, y, jaw.0.z)
        let j1 = SCNVector3(jaw.1.x, y, jaw.1.z)
        let mx = (j0.x + j1.x) / 2, mz = (j0.z + j1.z) / 2
        var nx = p.x - mx, nz = p.z - mz
        let nlen = sqrtf(nx * nx + nz * nz)
        guard nlen > 1e-5 else { return [] }
        nx /= nlen; nz /= nlen
        // 喉深：取「mouth→P 距离」再加一段余量（让后壁落在 P 之后），夹在合理范围。
        let throatDepth = max(nlen + 0.030, 0.055)
        let bl = SCNVector3(j0.x + nx * throatDepth, y, j0.z + nz * throatDepth)
        let br = SCNVector3(j1.x + nx * throatDepth, y, j1.z + nz * throatDepth)

        func seg(_ a: SCNVector3, _ b: SCNVector3) -> LinearCushionSegment {
            let mid = SCNVector3((a.x + b.x) / 2, y, (a.z + b.z) / 2)
            var dx = b.x - a.x, dz = b.z - a.z
            let len = sqrtf(dx * dx + dz * dz)
            dx /= len; dz /= len
            // 垂直于线段的两个法线候选，取指向落袋孔 P 一侧的那个（喉腔内部）。
            var nX = -dz, nZ = dx
            if (nX * (p.x - mid.x) + nZ * (p.z - mid.z)) < 0 { nX = -nX; nZ = -nZ }
            return LinearCushionSegment(start: a, end: b, normal: SCNVector3(nX, 0, nZ))
        }
        return [seg(j0, bl), seg(j1, br), seg(bl, br)]
    }
}
