//
//  TableGeometry+QiuJi.swift
//  QiuJi
//
//  项目13 生产物理桌面工厂。
//
//  基于 ADR-P10-09 的 CAD 袋角；2026-09-10 中袋落袋孔近沿按 USDZ 实测校准。
//  保留孔半径与全部碰撞墙体，不使用扩大捕获圆或前伸墙体：
//
//  - 角袋保持 CAD Φ84；中袋保持 Φ86，近侧孔沿对齐 USDZ 实测，袋角/喉壁不移动。
//    2026-09-29：捕获区域为实际台呢暴露口沿 + 旧深部孔圈；球心跨入口后开始下落。
//  - **jaw 与孔无缝**：角袋 jaw 直线段是孔的 45° 切线、外端点恰在孔沿（<1μm）；中袋喉壁
//    x=±0.043 与校准后的中袋孔相切；侧壁与圆角连接点保持原位。
//  - **安全喉壁 = 切线延长**：旧 v2 侧壁沿袋轴前伸 45mm，实体越过 jaw 平面 13.8mm
//    （中袋更是深入台内 45mm），在袋口里形成隐形墙（「先吃库边再吃远端 jaw」根因）。
//    侧壁为 jaw/喉壁切线延长；中袋后壁保持原 CAD 位置，位于校准孔远沿之外，
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

        // 6 个深部收集圆，下方叠加实测台呢入口；半径不再单独代表最早捕获边界。
        let cx = TablePhysics.cornerPocketCenterOffsetX   // 1.312
        let cz = TablePhysics.cornerPocketCenterOffsetZ   // 0.677
        let mz = TablePhysics.sidePocketCenterOffsetZ     // near rim aligned to the displayed mesh
        let rC = TablePhysics.cornerPocketRadius          // 0.042
        let rM = TablePhysics.sidePocketRadius            // 0.043
        // 顺序与 `AngleSceneCalculator.pocketPositions` 一致：左上/右上/左下/右下/上中/下中。
        // （SceneKit +Z = 顶视图上方；「上」= -Z 侧，与 pocketPositions 注释一致。）
        var pockets: [Pocket] = [
            Pocket(id: "pocket_0", center: SCNVector3(-cx, y, -cz), radius: rC, isCorner: true),
            Pocket(id: "pocket_1", center: SCNVector3( cx, y, -cz), radius: rC, isCorner: true),
            Pocket(id: "pocket_2", center: SCNVector3(-cx, y,  cz), radius: rC, isCorner: true),
            Pocket(id: "pocket_3", center: SCNVector3( cx, y,  cz), radius: rC, isCorner: true),
            Pocket(id: "pocket_4", center: SCNVector3(  0, y, -mz), radius: rM, isCorner: false),
            Pocket(id: "pocket_5", center: SCNVector3(  0, y,  mz), radius: rM, isCorner: false)
        ]

        for i in pockets.indices {
            let sx: Double = pockets[i].center.x < 0 ? -1 : 1
            let sz: Double = pockets[i].center.z < 0 ? -1 : 1
            let base = i < 4 ? Self.measuredCornerLip : Self.measuredMiddleLip
            var lip = base.map { SIMD2($0.x * sx, $0.y * sz) }
            if sx * sz < 0 { lip.reverse() }
            pockets[i].captureLip = lip
        }

        // 安全喉壁（切线延长式，纯数值兜底）。
        linear.append(contentsOf: cornerThroatWalls(y: y))
        linear.append(contentsOf: sideThroatBackWalls(y: y))

        return TableGeometry(
            linearCushions: linear,
            circularCushions: cushions.circular,
            pockets: pockets
        )
    }


    /// Bundled TaiNi exposed lip vertices, measured 2026-09-29. Internal seams
    /// excluded by union coverage. The closing chord lies inside the opening.
    /// Asset regression tests must verify this calibration when the table changes.
    private static let measuredCornerLip: [SIMD2<Double>] = [
        SIMD2(1.2505238056, 0.6648885608),
        SIMD2(1.2512993813, 0.6567158103),
        SIMD2(1.2536286116, 0.6488569379),
        SIMD2(1.2574344873, 0.6416142583),
        SIMD2(1.2652039528, 0.6321011186),
        SIMD2(1.2745693922, 0.6244518161),
        SIMD2(1.2818071842, 0.6206463575),
        SIMD2(1.2896609306, 0.6183149815),
        SIMD2(1.2978134155, 0.6175364256),
        SIMD2(1.3059661388, 0.6183341742),
        SIMD2(1.3138129711, 0.6206859946),
        SIMD2(1.3210593462, 0.6245275140),
        SIMD2(1.3253614902, 0.6280711293),
        SIMD2(1.2612780333, 0.6934692860),
        SIMD2(1.2575404644, 0.6881254315),
        SIMD2(1.2536879778, 0.6808815002),
        SIMD2(1.2513278723, 0.6730376482)
    ]


    /// Bundled TaiNi exposed lip vertices, measured 2026-09-29. Internal seams
    /// excluded by union coverage. The closing chord lies inside the opening.
    /// Asset regression tests must verify this calibration when the table changes.
    private static let measuredMiddleLip: [SIMD2<Double>] = [
        SIMD2(-0.0449813455, 0.6593745947),
        SIMD2(-0.0410947837, 0.6519642472),
        SIMD2(-0.0330508649, 0.6421130896),
        SIMD2(-0.0237892047, 0.6345483065),
        SIMD2(-0.0163746458, 0.6306460500),
        SIMD2(-0.0083441976, 0.6282565594),
        SIMD2(0.0000000000, 0.6274516582),
        SIMD2(0.0083441976, 0.6282565594),
        SIMD2(0.0163746458, 0.6306460500),
        SIMD2(0.0237892047, 0.6345483065),
        SIMD2(0.0330508649, 0.6421130896),
        SIMD2(0.0410947837, 0.6519642472),
        SIMD2(0.0449813455, 0.6593745947)
    ]

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
    /// 双面线性CCD与冲量解析使用同一真实接触侧，不再把袋道侧库面
    /// 后退1mm来避开事件竞态。保留壁索引，已反弹球由逼近方向过滤。
    private static let twinWallOffset: Float = 0

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
            walls.append(LinearCushionSegment(soundSurface: .jaw,
                start: longInner, end: longTip, normal: longInward))
            walls.append(LinearCushionSegment(soundSurface: .jaw,
                start: shortInner, end: shortTip, normal: shortInward))
            // ② 衬里延长壁。
            walls.append(LinearCushionSegment(soundSurface: .liner,
                start: longTip, end: longEnd, normal: longInward,
                restitution: TablePhysics.pocketThroatRestitution))
            walls.append(LinearCushionSegment(soundSurface: .liner,
                start: shortTip, end: shortEnd, normal: shortInward,
                restitution: TablePhysics.pocketThroatRestitution))
            // ③ 后壁：连接两延长壁末端，法线 = -jawDir（推回袋道）。
            walls.append(LinearCushionSegment(soundSurface: .liner,
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
        let zNear = TablePhysics.sidePocketThroatJoinZ                // 0.688
        let zFar = zNear + TablePhysics.sidePocketRadius                // 0.731（孔远沿）
        var walls: [LinearCushionSegment] = []
        walls.reserveCapacity(6)
        for sign in [Float(-1), Float(1)] {
            walls.append(LinearCushionSegment(soundSurface: .liner,
                start: SCNVector3(-xW, y, sign * zNear),
                end: SCNVector3(-xW, y, sign * zFar),
                normal: SCNVector3(1, 0, 0),
                restitution: TablePhysics.pocketThroatRestitution))
            walls.append(LinearCushionSegment(soundSurface: .liner,
                start: SCNVector3(xW, y, sign * zNear),
                end: SCNVector3(xW, y, sign * zFar),
                normal: SCNVector3(-1, 0, 0),
                restitution: TablePhysics.pocketThroatRestitution))
            walls.append(LinearCushionSegment(soundSurface: .liner,
                start: SCNVector3(-xW, y, sign * zFar),
                end: SCNVector3(xW, y, sign * zFar),
                normal: SCNVector3(0, 0, -sign),
                restitution: TablePhysics.pocketThroatRestitution))
        }
        return walls
    }
}
