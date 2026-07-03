//
//  TableGeometry+QiuJi.swift
//  QiuJi
//
//  项目13 生产物理桌面工厂。
//
//  v3（ADR-P10-09 真实袋口重建）：袋口几何**全面回归 CAD 单一真源**（`TablePhysics` 袋口常量），
//  取代 v2 的「USDZ 校准袋心 + 大捕获圆 + 前伸喉腔墙」组合：
//
//  - **落袋孔 = CAD 真孔**：角袋 Φ84 心 (±1.312, ±0.677)、中袋 Φ86 心 (0, ±0.688)。
//    落袋判据「球心水平投影入孔圈 ⇒ 失去支撑 ⇒ 落袋」（见 `EventDrivenEngine.resolvePocket`）。
//  - **jaw 与孔无缝**：角袋 jaw 直线段是孔的 45° 切线、外端点恰在孔沿（<1μm）；中袋喉壁
//    x=±0.043 与孔相切。球沿 jaw/喉壁滑到头，球心恰好抵达孔圈——判据与几何零过渡衔接。
//  - **安全喉壁 = 切线延长**：旧 v2 侧壁沿袋轴前伸 45mm，实体越过 jaw 平面 13.8mm
//    （中袋更是深入台内 45mm），在袋口里形成隐形墙（「先吃库边再吃远端 jaw」根因）。
//    新侧壁 = jaw/喉壁切线**向袋内延长**，后壁 = 孔远沿切线——全部与孔圈相切或在其外，
//    绝不侵入合法通道；正常球在触壁前已被孔圈判据收袋，喉壁只兜数值漏检与 rattle 路径。
//  - **视觉分离**：USDZ 标记盘偏移只保留在 `AngleSceneCalculator.pocketMarkerPositions`。
//
//  坐标系：X = 长轴，Z = 短轴，Y = 高度（SceneKit 世界系）。
//

import SceneKit

extension TableGeometry {

    /// 按 CAD 真源构建中式八球生产物理桌面。
    /// - Parameter surfaceY: 台面世界 Y（= `AngleTrainingScene.surfaceY`）。
    static func chineseEightBallQiuJi(surfaceY: Float) -> TableGeometry {
        let y = surfaceY

        // 库边（直库 + 角袋 jaw 直线段/圆弧 + 中袋圆角/喉壁）——CAD 构建器。
        let cushions = TableGeometry.chineseEightBallCushions(y: y)
        var linear = cushions.linear

        // 6 个落袋孔（CAD 真孔：球心入圈即落袋）。
        let cx = TablePhysics.cornerPocketCenterOffsetX   // 1.312
        let cz = TablePhysics.cornerPocketCenterOffsetZ   // 0.677
        let mz = TablePhysics.sidePocketCenterOffsetZ     // 0.688
        let rC = TablePhysics.cornerPocketRadius          // 0.042
        let rM = TablePhysics.sidePocketRadius            // 0.043
        // 顺序与 `AngleSceneCalculator.pocketPositions` 一致：左上/右上/左下/右下/上中/下中。
        // （SceneKit +Z = 顶视图上方；「上」= -Z 侧，与 pocketPositions 注释一致。）
        let pockets: [Pocket] = [
            Pocket(id: "pocket_0", center: SCNVector3(-cx, y, -cz), radius: rC, isCorner: true),
            Pocket(id: "pocket_1", center: SCNVector3( cx, y, -cz), radius: rC, isCorner: true),
            Pocket(id: "pocket_2", center: SCNVector3(-cx, y,  cz), radius: rC, isCorner: true),
            Pocket(id: "pocket_3", center: SCNVector3( cx, y,  cz), radius: rC, isCorner: true),
            Pocket(id: "pocket_4", center: SCNVector3(  0, y, -mz), radius: rM, isCorner: false),
            Pocket(id: "pocket_5", center: SCNVector3(  0, y,  mz), radius: rM, isCorner: false)
        ]

        // 安全喉壁（切线延长式，纯数值兜底）。
        linear.append(contentsOf: cornerThroatWalls(y: y))
        linear.append(contentsOf: sideThroatBackWalls(y: y))

        return TableGeometry(
            linearCushions: linear,
            circularCushions: cushions.circular,
            pockets: pockets
        )
    }

    // MARK: - 安全喉壁（切线延长式）

    /// 角袋袋道内侧壁系：每袋 2 片 jaw 面袋道侧壁 + 2 片衬里延长壁 + 1 道后壁。
    ///
    /// 背景：builder 的 jaw 直线段存储法线朝**台面**一侧，而引擎「只推不拉」护栏
    /// （`resolveBallCushionCollision` 的 v·n<0 检查）会跳过从袋道内侧打到该段的碰撞。
    /// 袋道（两条 45° 平行 jaw 面之间，宽 84mm）内的 rattle 反弹因此需要独立的
    /// **袋道侧孪生壁**：与 jaw 线共线、法线指向袋道轴。
    ///
    /// 三层壁（全部在袋道边界上或其外侧，绝不侵入袋道）：
    ///   1. jaw 面袋道侧（内尖→外尖）：橡皮面，恢复系数用全局库边值（nil）；
    ///   2. 衬里延长（外尖=孔沿切点 → 沿袋道轴再 rHole）：袋兜衬里，低恢复系数；
    ///   3. 后壁（垂直袋道轴、切孔远沿的弦）：袋兜衬里。
    /// 正常球在触及 2/3 前已被「球心入孔圈」判据收袋，它们只兜数值漏检与 rattle 路径。
    ///
    /// 竞态规避（FL-022）：①② 与 builder 的 jaw 直线段**不共面**——沿 jaw 外法向
    /// （背离袋道）偏移 `twinWallOffset`，错开两组事件的接触平面；球从袋道内侧撞 jaw 面时
    /// 视觉穿透 1mm（不可感知），换来事件序列的确定性。
    private static let twinWallOffset: Float = 0.001

    private static func cornerThroatWalls(y: Float) -> [LinearCushionSegment] {
        let rHole = TablePhysics.cornerPocketRadius        // 0.042
        let invSqrt2: Float = 1.0 / sqrtf(2.0)
        let eps = twinWallOffset
        var walls: [LinearCushionSegment] = []
        walls.reserveCapacity(20)

        // RU 基准（与 `buildCornerJawGeometries` 的 CAD 常量一致），其余角袋按符号镜像。
        // jaw 内端点：长边侧 (1.2413568, 0.6657538)、短边侧 (1.3007538, 0.6063568)；
        // jaw 外端点（孔沿切点）：长边侧 (1.2823015, 0.7066985)、短边侧 (1.3416985, 0.6473015)。
        for (sx, sz) in [(Float(1), Float(1)), (-1, 1), (1, -1), (-1, -1)] {
            let jawDir = SCNVector3(sx * invSqrt2, 0, sz * invSqrt2)      // 袋道轴（指向袋内）
            // 长边侧 jaw 面的袋道内向法线 = unit(孔心 − 长边外尖) = (sx, -sz)/√2；短边侧取反。
            let longInward = SCNVector3(sx * invSqrt2, 0, -sz * invSqrt2)
            let shortInward = SCNVector3(-sx * invSqrt2, 0, sz * invSqrt2)
            // 各面沿其外法向（-inward，背离袋道）偏移 eps。
            let longShift = SCNVector3(-longInward.x * eps, 0, -longInward.z * eps)
            let shortShift = SCNVector3(-shortInward.x * eps, 0, -shortInward.z * eps)

            let longInner = SCNVector3(sx * 1.2413568, y, sz * 0.6657538) + longShift
            let shortInner = SCNVector3(sx * 1.3007538, y, sz * 0.6063568) + shortShift
            let longTip = SCNVector3(sx * 1.2823015, y, sz * 0.7066985) + longShift
            let shortTip = SCNVector3(sx * 1.3416985, y, sz * 0.6473015) + shortShift
            let longEnd = longTip + jawDir * rHole
            let shortEnd = shortTip + jawDir * rHole

            // ① jaw 面袋道侧孪生壁（橡皮，全局恢复系数）。
            walls.append(LinearCushionSegment(
                start: longInner, end: longTip, normal: longInward))
            walls.append(LinearCushionSegment(
                start: shortInner, end: shortTip, normal: shortInward))
            // ② 衬里延长壁。
            walls.append(LinearCushionSegment(
                start: longTip, end: longEnd, normal: longInward,
                restitution: TablePhysics.pocketThroatRestitution))
            walls.append(LinearCushionSegment(
                start: shortTip, end: shortEnd, normal: shortInward,
                restitution: TablePhysics.pocketThroatRestitution))
            // ③ 后壁：连接两延长壁末端，法线 = -jawDir（推回袋道）。
            walls.append(LinearCushionSegment(
                start: longEnd, end: shortEnd,
                normal: SCNVector3(-jawDir.x, 0, -jawDir.z),
                restitution: TablePhysics.pocketThroatRestitution))
        }
        return walls
    }

    /// 中袋袋兜：喉壁（builder 已建 z∈[0.665, 0.688] 的 CAD 段）向袋内延长 + 后壁。
    /// 延长段 x=±0.043 z∈[0.688, 0.731]，后壁 z=±0.731 与 Φ86 孔远沿相切。
    private static func sideThroatBackWalls(y: Float) -> [LinearCushionSegment] {
        let xW = TablePhysics.sidePocketRadius                          // 0.043
        let zNear = TablePhysics.sidePocketCenterOffsetZ                // 0.688
        let zFar = zNear + TablePhysics.sidePocketRadius                // 0.731（孔远沿）
        var walls: [LinearCushionSegment] = []
        walls.reserveCapacity(6)
        for sign in [Float(-1), Float(1)] {
            walls.append(LinearCushionSegment(
                start: SCNVector3(-xW, y, sign * zNear),
                end: SCNVector3(-xW, y, sign * zFar),
                normal: SCNVector3(1, 0, 0),
                restitution: TablePhysics.pocketThroatRestitution))
            walls.append(LinearCushionSegment(
                start: SCNVector3(xW, y, sign * zNear),
                end: SCNVector3(xW, y, sign * zFar),
                normal: SCNVector3(-1, 0, 0),
                restitution: TablePhysics.pocketThroatRestitution))
            walls.append(LinearCushionSegment(
                start: SCNVector3(-xW, y, sign * zFar),
                end: SCNVector3(xW, y, sign * zFar),
                normal: SCNVector3(0, 0, -sign),
                restitution: TablePhysics.pocketThroatRestitution))
        }
        return walls
    }
}
