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

    // MARK: - 喉腔袋调参（ADR-P10-05 真实袋口物理）

    /// 喉腔后壁相对袋心的外移距离（米）：后壁位于袋心沿袋轴向外 backOffset 处，
    /// 使过力度球越过落袋孔后撞后壁弹回 mouth → rattle 弹出（取代旧"穿库飞出"安全网）。
    private static let throatBackOffset: Float = 0.040
    /// 喉腔侧壁向台内（mouth 之前）的前伸量（米）：侧壁起点从 jaw 尖端沿袋轴**反向**（指向台内）
    /// 前移此距离，封掉「库缺口结束 ↔ 侧壁起点(原在 jaw 尖 z 处)」之间的对角缝——斜向入袋的球
    /// 曾从该缝钻过：到达侧壁所在 x 时其 z 仍低于侧壁起点 → 不在线段内 → 漏检穿出。前伸 ≥1.5R
    /// 覆盖「球心库接触线(内框半幅−R) → mouth 平面」的过渡带。侧壁法线朝袋轴内侧，只挡腔内球，
    /// 不影响沿库滚向袋口的正常球（其在 mouth 外侧、法线背面）。
    private static let throatFrontExtend: Float = 0.045
    /// 喉腔后壁半宽相对 mouth 半宽的外扩量（米）：0 = 侧壁与袋轴平行（不外splay,避免球从后侧逃逸）。
    private static let throatWidthMargin: Float = 0
    /// 喉腔壁（侧壁 + 后壁）恢复系数：比主库（0.85）更"死"，使进袋球能量衰减后 settle 落孔，
    /// 既实现"小力远jaw→近jaw→进"，又避免高恢复系数把对准球弹来弹去导致进袋带碎裂（P10-02 教训）。
    private static let throatRestitution: Float = 0.45

    /// 按当前 USDZ 球台几何构建中式八球物理桌面。
    /// - Parameter surfaceY: 台面世界 Y（= `AngleTrainingScene.surfaceY`）。
    static func chineseEightBallQiuJi(surfaceY: Float) -> TableGeometry {
        let y = surfaceY

        // 库边（直库 + jaw 直线段 + jaw 圆弧 + 中袋圆角）与 CAD 版共用同一构建器。
        // ADR-P10-05 真实袋口物理（喉腔袋模型，回退 P10-02 大捕获圆）：在 jaw 闸口之后补回
        // **喉腔袋**——由两片侧壁（jaw 尖端 → 后壁端点）+ 一道后壁围成的袋腔，恢复系数更低。
        // 配合缩小后的**真实落袋孔**（球心进孔即落袋），让球的进/弹完全由几何与能量决定：
        //   · 对准/力度合适 → 抵达落袋孔 → 进；
        //   · 偏离/擦 jaw → 在 jaw/喉壁间反弹：小力衰减后落孔（远jaw→近jaw→袋心），
        //     大力反复弹撞后壁弹回 mouth → rattle 弹出。后壁同时消除"穿库飞出"（球被袋腔接住）。
        let cushions = TableGeometry.chineseEightBallCushions(y: y)
        var linear = cushions.linear
        let centers = AngleSceneCalculator.pocketPositions(surfaceY: y)
        let jaws = AngleSceneCalculator.pocketJaws(surfaceY: y)

        // 为每个袋口追加喉腔袋（侧壁 ×2 + 后壁 ×1，均带较低恢复系数）。
        for (i, c) in centers.enumerated() {
            linear.append(contentsOf: throatWalls(center: c, jaws: jaws[i], y: y))
        }

        // 6 个落袋孔：圆心取自 AngleSceneCalculator（与黄色标记一致），半径＝**真实落袋孔**
        // （球心进入孔内即落袋；偏离/过力度球由 jaw 闸口 + 喉腔袋拦截弹出，不靠此半径强行进球）。
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

    /// 单个袋口的喉腔袋三片墙：两片侧壁（jaw 尖端 → 后壁端点）+ 一道后壁。
    /// 几何：袋轴 n = unit(袋心)（台心在原点，指向台外），mouth 两端 = 两个 jaw 内端点；
    /// 后壁中点 = 袋心 + n·backOffset，后壁沿 mouth 的横向 t 展开（半宽 = mouth 半宽 + margin）；
    /// 侧壁连接每个 jaw 尖端与最近的后壁端点。三片墙法线均指向袋腔内侧（球只会从腔内侧撞到它们）。
    private static func throatWalls(
        center c: SCNVector3, jaws: (SCNVector3, SCNVector3), y: Float
    ) -> [LinearCushionSegment] {
        let cx = c.x, cz = c.z
        let nlen = max(sqrtf(cx * cx + cz * cz), 1e-5)
        let nx = cx / nlen, nz = cz / nlen          // 袋轴（指向台外）
        let tx = -nz, tz = nx                        // 袋口横向（垂直袋轴）

        // 侧壁起点从 jaw 尖端沿 -n（指向台内）前伸，封掉 mouth 之前的对角缝。
        let j0 = SCNVector3(jaws.0.x - nx * throatFrontExtend, y, jaws.0.z - nz * throatFrontExtend)
        let j1 = SCNVector3(jaws.1.x - nx * throatFrontExtend, y, jaws.1.z - nz * throatFrontExtend)
        // mouth 横向半宽（两 jaw 端点横向间距的一半）+ 外扩。
        let mouthHalf = 0.5 * abs((j0.x - j1.x) * tx + (j0.z - j1.z) * tz)
        let backHalf = mouthHalf + throatWidthMargin
        // 后壁中点与两端。
        let bcx = cx + nx * throatBackOffset, bcz = cz + nz * throatBackOffset
        let e0 = SCNVector3(bcx + tx * backHalf, y, bcz + tz * backHalf)
        let e1 = SCNVector3(bcx - tx * backHalf, y, bcz - tz * backHalf)

        // 侧壁端点配对：每个 jaw 端点接最近的后壁端点。
        func dist2(_ a: SCNVector3, _ b: SCNVector3) -> Float {
            let dx = a.x - b.x, dz = a.z - b.z; return dx * dx + dz * dz
        }
        let (s0a, s0b, s1a, s1b): (SCNVector3, SCNVector3, SCNVector3, SCNVector3) =
            dist2(j0, e0) <= dist2(j0, e1) ? (j0, e0, j1, e1) : (j0, e1, j1, e0)

        // 内向法线 = 指向袋腔轴（袋心方向）的单位向量。
        func inwardWall(_ a: SCNVector3, _ b: SCNVector3) -> LinearCushionSegment {
            let dx = b.x - a.x, dz = b.z - a.z
            let dl = max(sqrtf(dx * dx + dz * dz), 1e-5)
            let ux = dx / dl, uz = dz / dl
            var nX = -uz, nZ = ux                     // 墙的一个法向候选
            let mx = (a.x + b.x) * 0.5, mz = (a.z + b.z) * 0.5
            // 取指向袋心一侧的法向（球在腔内侧）。
            if (nX * (cx - mx) + nZ * (cz - mz)) < 0 { nX = -nX; nZ = -nZ }
            return LinearCushionSegment(start: a, end: b,
                                        normal: SCNVector3(nX, 0, nZ),
                                        restitution: throatRestitution)
        }
        // 后壁法线指向 mouth（-n）。
        let back = LinearCushionSegment(start: e0, end: e1,
                                        normal: SCNVector3(-nx, 0, -nz),
                                        restitution: throatRestitution)
        return [inwardWall(s0a, s0b), inwardWall(s1a, s1b), back]
    }
}
