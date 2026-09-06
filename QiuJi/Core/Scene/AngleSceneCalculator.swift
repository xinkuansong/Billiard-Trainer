import Foundation
import SceneKit

/// Maps between AngleCalculator's normalised 2D coordinates (x: 0→1, y: 0→0.5)
/// and SceneKit world coordinates used by AngleTrainingScene.
enum AngleSceneCalculator {

    // MARK: - Table dimensions (Chinese 8-ball, metres)

    static let innerLength: Float = 2.54
    static let innerWidth: Float  = 1.27
    static let ballRadius: Float  = 0.028575  // 57.15mm diameter

    // MARK: - Coordinate mapping

    /// Convert AngleCalculator normalised point to SceneKit world position.
    /// Normalised x ∈ [0, 1] maps to scene X ∈ [-innerLength/2, +innerLength/2].
    /// Normalised y ∈ [0, 0.5] maps to scene Z ∈ [-innerWidth/2, +innerWidth/2].
    static func normalizedToScene(point: CGPoint, surfaceY: Float) -> SCNVector3 {
        let sceneX = Float(point.x) * innerLength - innerLength / 2
        let sceneZ = Float(point.y) * 2.0 * innerWidth - innerWidth / 2
        return SCNVector3(sceneX, surfaceY + ballRadius, sceneZ)
    }

    /// Convert SceneKit world position back to normalised point.
    static func sceneToNormalized(position: SCNVector3) -> CGPoint {
        let nx = (position.x + innerLength / 2) / innerLength
        let ny = (position.z + innerWidth / 2) / (2.0 * innerWidth)
        return CGPoint(x: CGFloat(nx), y: CGFloat(ny))
    }

    /// Ghost ball center: `targetCenter - 2R * normalize(pocket - targetCenter)`.
    /// Per 45-aiming-principles.mdc, the ghost ball sits on the pocket-line extension
    /// opposite to the pocket, at distance 2R from the target ball.
    static func ghostBallPosition(
        targetBall: SCNVector3,
        pocket: SCNVector3,
        ballRadius: Float
    ) -> SCNVector3 {
        let dx = pocket.x - targetBall.x
        let dz = pocket.z - targetBall.z
        let dist = sqrtf(dx * dx + dz * dz)
        guard dist > 0.0001 else { return targetBall }
        let dirX = dx / dist
        let dirZ = dz / dist
        return SCNVector3(
            targetBall.x - 2 * ballRadius * dirX,
            targetBall.y,
            targetBall.z - 2 * ballRadius * dirZ
        )
    }

    /// d/R = 2sin(α). Lateral displacement in ball-radius units.
    static func lateralDisplacement(cutAngle: Double) -> Double {
        2.0 * sin(cutAngle * .pi / 180.0)
    }

    /// Lateral displacement in millimetres: d = 2R × sin(α).
    static func lateralDisplacementMM(cutAngle: Double, ballRadius: Double) -> Double {
        2.0 * ballRadius * sin(cutAngle * .pi / 180.0)
    }

    /// Contact point offset = sin(α), as fraction of R (derived quantity).
    static func contactPointOffset(cutAngle: Double) -> Double {
        sin(cutAngle * .pi / 180.0)
    }

    // MARK: - Pocket geometry (SceneKit world coords)

    /// 落袋孔半径（= CAD 真孔：角袋 Φ84、中袋 Φ86）。物理判据（ADR-P10-09）：
    /// 球心水平投影进入孔圈即落袋；视觉标记盘也用同一半径。
    static let cornerPocketRadius: Float = 0.042
    static let middlePocketRadius: Float = 0.043

    /// 给定袋号的落袋孔半径（ADR-P10-09 起 = 真孔半径，与标记盘一致；
    /// 旧「大捕获圆」70/75mm 语义已随两段式判据一并移除）。
    static func pocketDropRadius(index: Int) -> Float {
        index < 4 ? cornerPocketRadius : middlePocketRadius
    }

    /// CAD 孔心相对击球区边界的偏移（物理/瞄准真源，ADR-P10-09）：
    /// 角袋孔心 (±1.312, ±0.677)，中袋孔心 (0, ±0.688)。
    /// 整套袋口构造链（jaw 45° 切线 / R30 双切 / 喉壁）与这些孔心互为切线、数值闭合，
    /// 物理层禁止再混入 USDZ 视觉偏移（那会在 jaw 末端与孔沿之间撕开 3.3mm 死缝）。
    private static let cornerPocketOffset: Float = 0.042
    private static let middlePocketOffset: Float = 0.053

    /// 当前 USDZ 模型 `TaiQiuZhuo.usdz` 的袋口洞**视觉**中心比 CAD 孔心略靠台内
    /// （实测约 12mm / 9mm）。仅供渲染层（黄色标记盘）使用；调整 USDZ 模型时重新校准。
    private static let cornerPocketModelDelta: Float = 0.012
    private static let middlePocketModelDelta: Float = 0.009

    /// Six pocket centers at table surface level（CAD 真孔心，物理引擎 + 瞄准数学的唯一真源）。
    static func pocketPositions(surfaceY: Float) -> [SCNVector3] {
        pocketCenters(surfaceY: surfaceY,
                      c: cornerPocketOffset,
                      m: middlePocketOffset)
    }

    /// 袋口**视觉标记盘**中心（CAD 孔心 + USDZ 视觉校准偏移）。仅供渲染层使用。
    static func pocketMarkerPositions(surfaceY: Float) -> [SCNVector3] {
        pocketCenters(surfaceY: surfaceY,
                      c: cornerPocketOffset - cornerPocketModelDelta,
                      m: middlePocketOffset - middlePocketModelDelta)
    }

    private static func pocketCenters(surfaceY: Float, c: Float, m: Float) -> [SCNVector3] {
        let halfL = innerLength / 2
        let halfW = innerWidth / 2
        let y = surfaceY
        return [
            SCNVector3(-halfL - c, y, -halfW - c),  // 左上 (top-left)
            SCNVector3( halfL + c, y, -halfW - c),  // 右上 (top-right)
            SCNVector3(-halfL - c, y,  halfW + c),  // 左下 (bottom-left)
            SCNVector3( halfL + c, y,  halfW + c),  // 右下 (bottom-right)
            SCNVector3(        0, y, -halfW - m),   // 上中 (top-center)
            SCNVector3(        0, y,  halfW + m),   // 下中 (bottom-center)
        ]
    }

    /// Marker disc radius for the pocket overlay: 42mm corners / 43mm middles per steering.
    static func pocketMarkerRadius(index: Int) -> Float {
        index < 4 ? cornerPocketRadius : middlePocketRadius
    }

    // MARK: - Pocket Jaws (cushion nose tips defining each pocket "mouth")

    /// Inner endpoints of the two cushion-nose jaws bounding each pocket's mouth.
    /// 中式八球：角袋有 2 段 jaw（长边侧 + 短边侧），中袋为长边在中点的两侧端点。
    /// 源自 `.kiro/steering/table-geometry.md` § 角袋 jaw 直线段 + 长边库边。
    /// 顺序与 `pocketPositions` 完全一致（0..5）。
    static func pocketJaws(surfaceY: Float) -> [(SCNVector3, SCNVector3)] {
        let y = surfaceY
        // 角袋 jaw 内端点（最靠近击球区）：长边侧 (±1.2414, ±0.6658)、短边侧 (±1.3008, ±0.6064)
        func corner(sx: Float, sz: Float) -> (SCNVector3, SCNVector3) {
            (
                SCNVector3(sx * 1.2414, y, sz * 0.6658),
                SCNVector3(sx * 1.3008, y, sz * 0.6064)
            )
        }
        // 中袋 mouth 端点：R30 鼻尖（圆角与喉壁的切点）(±0.043, ±0.665)——CAD 双切构造。
        func middle(sz: Float) -> (SCNVector3, SCNVector3) {
            (
                SCNVector3(-0.043, y, sz * 0.665),
                SCNVector3(+0.043, y, sz * 0.665)
            )
        }
        return [
            corner(sx: -1, sz: -1),  // 0: 左上
            corner(sx: +1, sz: -1),  // 1: 右上
            corner(sx: -1, sz: +1),  // 2: 左下
            corner(sx: +1, sz: +1),  // 3: 右下
            middle(sz: -1),          // 4: 上中
            middle(sz: +1),          // 5: 下中
        ]
    }

    /// Safety buffer added to ball radius for pocket-clearance math.
    /// 球心避开任何鼻子的最小距离 = `ballRadius + aimMargin`，给真实击打留 3mm 余量
    /// （也回避浮点精度问题）。
    private static let aimMargin: Float = 0.003

    /// 贴库豁免的浮点保护量（0.5mm）。目标球球心距最近库 `d < ballRadius + aimMargin`
    /// （贴库或距库仅 1–2mm）时，管道余量整体放宽为 `d − railFrozenSlack`：
    /// 沿库滚进袋是**零余量的合法物理**，3mm 余量会把这类球的全部线路误判为不可行；
    /// 放宽后管道最多与球当前位置一样贴库，仍禁止比球现在更扎进库（slack 仅防浮点噪声）。
    /// 必须整体放宽而非只豁免主库段：近端 jaw 圆角弧与库面相切，沿库线路到弧的
    /// 距离同样 ≈ d，只豁免主库仍会被 jaw 判定拒绝。
    private static let railFrozenSlack: Float = 0.0005

    /// Effective aim point — dynamically adjusts based on target ball position.
    ///
    /// 算法核心：把进球线视为「进球管道」而不是一条无厚度的线。目标球球心沿
    /// 中心线移动时，中心线两侧各有 `ballRadius + aimMargin` 的扫掠半径；这条
    /// 管道不能碰到库边或非目标袋口的 jaw。
    ///
    /// 规则：
    ///   1. 如果自然方向 T→C（袋口中心）对应的管道安全，进球点 = C。
    ///   2. 如果目标球贴库且自然方向扎进库，沿库平行（你已确认这部分正确）。
    ///   3. 其他情况在 T→C 周围采样候选方向，选择「管道安全」且「袋口中心到管道
    ///      中心线距离最小」的方向；进球点 = C 投影到该方向的中心线上。
    ///
    /// 这样能保证所有袋口、所有方向都用同一套管道判定：靠库越近，中心线越受库边
    /// 约束；离库越远，进球点逐渐回到袋口中心。
    static func effectivePocketAimPoint(
        targetBall: SCNVector3,
        pocketIndex: Int,
        surfaceY: Float
    ) -> SCNVector3 {
        let positions = pocketPositions(surfaceY: surfaceY)
        guard pocketIndex >= 0, pocketIndex < positions.count else {
            return positions.first ?? SCNVector3(0, surfaceY, 0)
        }
        return effectiveAimPoint(
            targetBall: targetBall,
            nominalPocket: positions[pocketIndex],
            geometry: buildPipeGeometry(
                pocketIndex: pocketIndex,
                pocketCenter: Vector2(positions[pocketIndex].x, positions[pocketIndex].z)
            )
        )
    }

    /// Core math for `effectivePocketAimPoint`. Uses the pipe model described above.
    private static func effectiveAimPoint(
        targetBall: SCNVector3,
        nominalPocket: SCNVector3,
        geometry: PipeGeometry
    ) -> SCNVector3 {
        let origin = Vector2(targetBall.x, targetBall.z)
        // 贴库豁免：球心距最近主库 d < 标准余量时，余量放宽为 d − slack（见 railFrozenSlack 注释）。
        // 下限钳到 ballRadius − slack：即便快照数据让球微嵌库（d < R），也不允许管道穿库。
        let standardClearance = ballRadius + aimMargin
        let railDist = mainCushionSegments.map { pointSegmentDistance(origin, $0) }.min()
            ?? Float.greatestFiniteMagnitude
        let clearance = railDist < standardClearance
            ? max(railDist - railFrozenSlack, ballRadius - railFrozenSlack)
            : standardClearance
        let pocket = Vector2(nominalPocket.x, nominalPocket.z)
        let naturalVector = pocket - origin
        guard naturalVector.length > 0.0001 else { return nominalPocket }

        // 选点优先级（管道法）：
        // 1) 正对袋心若能「干净穿过」两片 jaw（完全不擦任一 jaw、不吃主库）→ 直接用，
        //    保持既有干净直线进球不变。
        if cleanPipeMargin(
            origin: origin, aim: pocket, geometry: geometry, clearance: clearance
        ) != nil {
            return nominalPocket
        }
        // 2) 正对袋心会擦 jaw → 在袋口喉口（两 jaw 内沿 mouthA↔mouthB）内扫描，找一条
        //    「干净穿过两 jaw 且离两侧 jaw 都最远（最居中）」的进球点。这是 Case 1 的最优解：
        //    目标球走最直、完全不擦 jaw。避免之前「挑可行域最靠 jaw 的边缘点」导致橙线擦 jaw 拐弯。
        if geometry.mouth.targetJaws.count == 2 {
            let mA = geometry.mouth.mouthA
            let mB = geometry.mouth.mouthB
            let samples = 48
            var bestAim: Vector2?
            var bestMargin = -Float.greatestFiniteMagnitude
            for i in 0...samples {
                let t = Float(i) / Float(samples)
                let candidate = mA * (1 - t) + mB * t
                if let margin = cleanPipeMargin(
                    origin: origin, aim: candidate, geometry: geometry, clearance: clearance
                ), margin > bestMargin {
                    bestMargin = margin
                    bestAim = candidate
                }
            }
            if let bestAim {
                return SCNVector3(bestAim.x, nominalPocket.y, bestAim.z)
            }
        }
        // 3) 任何方向都无法干净穿过 → 只能靠远端 jaw 反弹（Case 2，擦一下不可避免）。
        //    先看正对袋心是否为合法 Case 2，再退回螺旋搜索取最靠袋心的反弹点。
        if aimPointIsPipeSafe(
            origin: origin, aim: pocket, geometry: geometry, clearance: clearance
        ) {
            return nominalPocket
        }

        let baseAngle = atan2f(naturalVector.z, naturalVector.x)
        let maxAdjust: Float = max(cornerPocketRadius, middlePocketRadius) * 2.6
        let radiusStep: Float = 0.0025
        let angleStep: Float = 5 * .pi / 180

        var bestAim: Vector2?
        var bestScore = Float.greatestFiniteMagnitude

        var radius: Float = radiusStep
        while radius <= maxAdjust {
            var foundAtThisRadius = false
            var angle: Float = 0
            while angle < 2 * .pi {
                let candidate = pocket + Vector2(cosf(angle), sinf(angle)) * radius
                if aimPointIsPipeSafe(
                    origin: origin, aim: candidate, geometry: geometry, clearance: clearance
                ) {
                    foundAtThisRadius = true
                    let dir = (candidate - origin)
                    let dirAngle = atan2f(dir.z, dir.x)
                    let angleDelta = abs(normalizeAngle(dirAngle - baseAngle))
                    let score = radius + angleDelta * 0.0001
                    if score < bestScore {
                        bestScore = score
                        bestAim = candidate
                    }
                }
                angle += angleStep
            }
            if foundAtThisRadius { break }
            radius += radiusStep
        }

        guard let bestAim else { return nominalPocket }
        return SCNVector3(bestAim.x, nominalPocket.y, bestAim.z)
    }

    private static func aimPointIsPipeSafe(
        origin: Vector2,
        aim: Vector2,
        geometry: PipeGeometry,
        clearance: Float
    ) -> Bool {
        let vector = aim - origin
        let length = vector.length
        guard length > 0.0001 else { return false }
        let dir = vector / length
        let pipeEnd = origin + dir * (length + clearance)

        let ordinary = ordinaryClearance(
            origin: origin, end: pipeEnd, dir: dir,
            obstacles: geometry.ordinaryObstacles, clearance: clearance
        )
        guard ordinary.safe else { return false }

        // 近/远端 jaw 区分（几何稳健版，不依赖脆弱的直线段最近点分类）：
        // 以「袋心 → 台心」为袋口轴线，其横向法线 perp 把袋口分成两侧。
        // 与目标球同侧的 jaw = 近端（球自身一侧，碰到 → 弹回台面 → 情形3 不可行）；
        // 异侧 = 远端（可被擦到 → 情形2 反弹进袋）。
        let jaws = geometry.mouth.targetJaws
        let comps = geometry.mouth.compositeJaws
        if jaws.count == 2, comps.count == 2 {
            let pc = geometry.mouth.center
            var axis = Vector2(-pc.x, -pc.z)
            let axisLen = axis.length
            axis = axisLen > 1e-6 ? axis / axisLen : Vector2(0, 1)
            let perp = Vector2(-axis.z, axis.x)
            let ballSide = (origin - pc).dot(perp)
            let side0 = (jaws[0].a - pc).dot(perp)   // jaw0(长库侧)内尖在哪侧
            let nearIdx = (side0 * ballSide >= 0) ? 0 : 1

            // 近端 jaw 必须按真实复合轮廓（弧 + 线）整段清空（含袋口圆弧），余量 clearance。
            // 擦到近端 jaw（含其圆弧）→ 会先撞近端弹回台面，违反「碰远端 jaw 前走直线」→ 不可行。
            if centerlineCompositeJawDistance(origin: origin, pipeEnd: pipeEnd, jaw: comps[nearIdx]) < clearance {
                return false
            }
            // 远端 jaw 允许擦（合法 Case 2 反弹进袋）；管子在碰远端前不吃主库 / 它袋 jaw 已由
            // ordinary.safe 保证，不吃近端 jaw 已由上面判定保证。
            return true
        } else if !jaws.isEmpty {
            // 退化兜底（非两片 jaw，例如未来几何变更）：沿用旧的就近放行逻辑。
            let targetJawDistance = jaws.map {
                segmentDistance(origin, pipeEnd, $0.a, $0.b)
            }.min() ?? Float.greatestFiniteMagnitude
            if targetJawDistance < clearance {
                let boundaryTolerance: Float = 0.004
                return ordinary.minDistance <= clearance + boundaryTolerance
            }
        }

        return true
    }

    /// 「干净穿管」度量：候选进球点的管子能否**完全不擦任一 jaw、不吃主库**地穿过袋口。
    /// - 返回 `nil`：擦到某片 jaw 或吃主库（非干净穿过）。
    /// - 返回间隙值：管子到最近障碍（两片 jaw + 主库取最小）的距离，越大越居中、目标球越走直线。
    ///   `effectiveAimPoint` 取该值最大的进球点 = 可行方向锥的「中线」，而非靠 jaw 的边缘。
    private static func cleanPipeMargin(
        origin: Vector2,
        aim: Vector2,
        geometry: PipeGeometry,
        clearance: Float
    ) -> Float? {
        let vector = aim - origin
        let length = vector.length
        guard length > 0.0001 else { return nil }
        let dir = vector / length
        let pipeEnd = origin + dir * (length + clearance)

        let ordinary = ordinaryClearance(
            origin: origin, end: pipeEnd, dir: dir,
            obstacles: geometry.ordinaryObstacles, clearance: clearance
        )
        guard ordinary.safe else { return nil }

        let comps = geometry.mouth.compositeJaws
        if comps.count == 2 {
            // 真实轮廓（弧+线）距离：贴库/小切角的球沿圆角弧滑入，必须用弧而非直线段量距。
            let d0 = centerlineCompositeJawDistance(origin: origin, pipeEnd: pipeEnd, jaw: comps[0])
            let d1 = centerlineCompositeJawDistance(origin: origin, pipeEnd: pipeEnd, jaw: comps[1])
            // 干净穿过 = 两片 jaw 都被清空（都不擦）。任一被擦到即非干净。
            guard d0 >= clearance, d1 >= clearance else { return nil }
            return min(d0, d1, ordinary.minDistance)
        }
        // 退化兜底（无复合轮廓的未来几何）：ordinary.safe 即为干净穿过。
        return ordinary.minDistance
    }

    private struct Vector2 {
        let x: Float
        let z: Float

        init(_ x: Float, _ z: Float) {
            self.x = x
            self.z = z
        }

        var length: Float { sqrtf(x * x + z * z) }

        static func + (lhs: Vector2, rhs: Vector2) -> Vector2 {
            Vector2(lhs.x + rhs.x, lhs.z + rhs.z)
        }

        static func - (lhs: Vector2, rhs: Vector2) -> Vector2 {
            Vector2(lhs.x - rhs.x, lhs.z - rhs.z)
        }

        static func * (lhs: Vector2, rhs: Float) -> Vector2 {
            Vector2(lhs.x * rhs, lhs.z * rhs)
        }

        static func / (lhs: Vector2, rhs: Float) -> Vector2 {
            Vector2(lhs.x / rhs, lhs.z / rhs)
        }

        func dot(_ other: Vector2) -> Float {
            x * other.x + z * other.z
        }
    }

    private struct Segment2D {
        let a: Vector2
        let b: Vector2
    }

    /// 角袋圆角弧段（袋口橡胶圆角）：圆心 + 半径 + 两端点角（取两角之间的劣弧）。
    /// 参数与 `TableGeometry` 的 `CornerJawGeometry`（CAD 真值，fillet 半径 0.105m）一致。
    private struct ArcSeg {
        let center: Vector2
        let radius: Float
        let angA: Float   // 端点角（弧线连接主库一端）
        let angB: Float   // 端点角（弧线连接 jaw 内尖一端）
    }

    /// 单片 jaw 的真实复合轮廓：圆角弧（主库 → 内尖）+ 直线段（内尖 → 外尖）。
    private struct CompositeJaw {
        let arc: ArcSeg
        let line: Segment2D
    }

    private struct PocketMouth {
        let center: Vector2
        let mouthA: Vector2
        let mouthB: Vector2
        let targetJaws: [Segment2D]
        /// 与 `targetJaws` 同序的复合轮廓（弧+线）。角袋：[长库侧, 短库侧]；中袋：[左, 右]。
        let compositeJaws: [CompositeJaw]
    }

    private struct PipeGeometry {
        let mouth: PocketMouth
        let ordinaryObstacles: [Segment2D]
    }

    /// 六段主库击球面线段（贴库检测 + 管道障碍共用真源）。
    private static let mainCushionSegments: [Segment2D] = [
        Segment2D(a: Vector2(-1.1671, -0.635), b: Vector2(-0.073, -0.635)),
        Segment2D(a: Vector2( 0.073, -0.635), b: Vector2( 1.1671, -0.635)),
        Segment2D(a: Vector2(-1.1671,  0.635), b: Vector2(-0.073,  0.635)),
        Segment2D(a: Vector2( 0.073,  0.635), b: Vector2( 1.1671,  0.635)),
        Segment2D(a: Vector2(-1.270, -0.5321), b: Vector2(-1.270,  0.5321)),
        Segment2D(a: Vector2( 1.270, -0.5321), b: Vector2( 1.270,  0.5321)),
    ]

    private static func buildPipeGeometry(pocketIndex: Int, pocketCenter: Vector2) -> PipeGeometry {
        let mouths = pocketMouths()
        let mouth = mouths[pocketIndex]
        var ordinary: [Segment2D] = mainCushionSegments

        for (index, pocket) in mouths.enumerated() where index != pocketIndex {
            for jaw in pocket.targetJaws {
                ordinary.append(jaw)
            }
        }

        return PipeGeometry(
            mouth: PocketMouth(
                center: pocketCenter,
                mouthA: mouth.mouthA,
                mouthB: mouth.mouthB,
                targetJaws: mouth.targetJaws,
                compositeJaws: mouth.compositeJaws
            ),
            ordinaryObstacles: ordinary
        )
    }

    /// 角袋圆角弧半径（与 `TableGeometry.TablePhysics.cornerPocketFilletRadius` 一致）。
    private static let cornerPocketFilletRadius: Float = 0.105

    private static func pocketMouths() -> [PocketMouth] {
        let fillet = cornerPocketFilletRadius

        func corner(sx: Float, sz: Float, center: Vector2) -> PocketMouth {
            // 直线段（内尖 → 外尖），与 CAD/TableGeometry 一致。
            let longInner = Vector2(sx * 1.2413568, sz * 0.6657538)
            let longOuter = Vector2(sx * 1.2823015, sz * 0.7066985)
            let shortInner = Vector2(sx * 1.3007538, sz * 0.6063568)
            let shortOuter = Vector2(sx * 1.3416985, sz * 0.6473015)
            // 圆角弧（主库点 → 内尖），圆心/半径取自 TableGeometry CAD 真值。
            let longArcCenter = Vector2(sx * 1.1671106, sz * 0.740)
            let longArcRail = Vector2(sx * 1.1671106, sz * 0.635)   // 270° 接上库
            let shortArcCenter = Vector2(sx * 1.375, sz * 0.5321106)
            let shortArcRail = Vector2(sx * 1.270, sz * 0.5321106)  // 180° 接短库
            func arc(_ c: Vector2, _ railPt: Vector2, _ innerTip: Vector2) -> ArcSeg {
                let a = railPt - c, b = innerTip - c
                return ArcSeg(center: c, radius: fillet,
                              angA: atan2f(a.z, a.x), angB: atan2f(b.z, b.x))
            }
            return PocketMouth(
                center: center,
                mouthA: longInner,
                mouthB: shortInner,
                targetJaws: [
                    Segment2D(a: longInner, b: longOuter),
                    Segment2D(a: shortInner, b: shortOuter)
                ],
                compositeJaws: [
                    CompositeJaw(arc: arc(longArcCenter, longArcRail, longInner),
                                 line: Segment2D(a: longInner, b: longOuter)),
                    CompositeJaw(arc: arc(shortArcCenter, shortArcRail, shortInner),
                                 line: Segment2D(a: shortInner, b: shortOuter))
                ]
            )
        }

        // 中袋（CAD 双切构造，ADR-P10-09）：mouth 端点 = R30 鼻尖（圆角与喉壁切点）
        // (±0.043, ±0.665)；composite jaw = R30 圆角弧（心 (±0.073, ±0.665)）+ 喉壁
        // 直线段（x=±0.043, z∈[±0.665, ±0.688]）。有了 targetJaws/compositeJaws 后，
        // 中袋与角袋共用「mouth 扫描选最净入线」逻辑（旧版为空导致只会螺旋搜擦角）。
        func middle(sz: Float, center: Vector2) -> PocketMouth {
            let noseL = Vector2(-0.043, sz * 0.665)
            let noseR = Vector2(0.043, sz * 0.665)
            let throatL = Segment2D(a: noseL, b: Vector2(-0.043, sz * 0.688))
            let throatR = Segment2D(a: noseR, b: Vector2(0.043, sz * 0.688))
            let arcCenterL = Vector2(-0.073, sz * 0.665)
            let arcCenterR = Vector2(0.073, sz * 0.665)
            let railPtL = Vector2(-0.073, sz * 0.635)
            let railPtR = Vector2(0.073, sz * 0.635)
            func arc(_ c: Vector2, _ railPt: Vector2, _ nose: Vector2) -> ArcSeg {
                let a = railPt - c, b = nose - c
                return ArcSeg(center: c, radius: 0.030,
                              angA: atan2f(a.z, a.x), angB: atan2f(b.z, b.x))
            }
            return PocketMouth(
                center: center,
                mouthA: noseL,
                mouthB: noseR,
                targetJaws: [throatL, throatR],
                compositeJaws: [
                    CompositeJaw(arc: arc(arcCenterL, railPtL, noseL), line: throatL),
                    CompositeJaw(arc: arc(arcCenterR, railPtR, noseR), line: throatR)
                ]
            )
        }

        let halfL = innerLength / 2
        let halfW = innerWidth / 2
        return [
            corner(sx: -1, sz: -1, center: Vector2(-halfL - cornerPocketOffset, -halfW - cornerPocketOffset)),
            corner(sx:  1, sz: -1, center: Vector2( halfL + cornerPocketOffset, -halfW - cornerPocketOffset)),
            corner(sx: -1, sz:  1, center: Vector2(-halfL - cornerPocketOffset,  halfW + cornerPocketOffset)),
            corner(sx:  1, sz:  1, center: Vector2( halfL + cornerPocketOffset,  halfW + cornerPocketOffset)),
            middle(sz: -1, center: Vector2(0, -halfW - middlePocketOffset)),
            middle(sz: 1, center: Vector2(0, halfW + middlePocketOffset))
        ]
    }

    // MARK: - Composite jaw (arc + line) distance

    /// 点到圆角弧的距离：投影角落在弧内 → ||p−圆心|−半径|；否则取两端点较近者。
    private static func pointToArc(_ p: Vector2, _ arc: ArcSeg) -> Float {
        let v = p - arc.center
        let ang = atan2f(v.z, v.x)
        if arcContainsAngle(arc, ang) {
            return abs(v.length - arc.radius)
        }
        let ea = arc.center + Vector2(cosf(arc.angA), sinf(arc.angA)) * arc.radius
        let eb = arc.center + Vector2(cosf(arc.angB), sinf(arc.angB)) * arc.radius
        return min((p - ea).length, (p - eb).length)
    }

    /// 角 `t` 是否落在弧 `[angA, angB]` 的劣弧范围内。
    private static func arcContainsAngle(_ arc: ArcSeg, _ t: Float) -> Bool {
        func norm(_ x: Float) -> Float {
            var v = fmodf(x, 2 * .pi)
            if v < -.pi { v += 2 * .pi }
            if v > .pi { v -= 2 * .pi }
            return v
        }
        let d = norm(arc.angB - arc.angA)
        let o = norm(t - arc.angA)
        if d >= 0 { return o >= -1e-4 && o <= d + 1e-4 }
        return o <= 1e-4 && o >= d - 1e-4
    }

    /// 点到单片复合 jaw（弧 + 线段）的最近距离。
    private static func pointToCompositeJaw(_ p: Vector2, _ jaw: CompositeJaw) -> Float {
        min(pointToArc(p, jaw.arc), pointSegmentDistance(p, jaw.line))
    }

    /// 管道中心线段（origin→pipeEnd）到复合 jaw 的最近距离。
    /// jaw 集中在袋口处，故只在管道末段（靠近袋口的 0.30m）密采样即可，兼顾精度与开销。
    private static func centerlineCompositeJawDistance(
        origin: Vector2, pipeEnd: Vector2, jaw: CompositeJaw
    ) -> Float {
        let seg = pipeEnd - origin
        let len = seg.length
        guard len > 1e-5 else { return pointToCompositeJaw(origin, jaw) }
        let dir = seg / len
        let tailStart = max(0, len - 0.30)
        let step: Float = 0.002
        var best = Float.greatestFiniteMagnitude
        var s = tailStart
        while s <= len + 1e-4 {
            best = min(best, pointToCompositeJaw(origin + dir * s, jaw))
            s += step
        }
        return min(best, pointToCompositeJaw(pipeEnd, jaw))
    }


    private static func ordinaryClearance(
        origin: Vector2,
        end: Vector2,
        dir: Vector2,
        obstacles: [Segment2D],
        clearance: Float
    ) -> (safe: Bool, minDistance: Float) {
        var minDistance = Float.greatestFiniteMagnitude
        for obstacle in obstacles {
            let startClosest = closestPointOnSegment(point: origin, segment: obstacle)
            let away = (origin - startClosest).dot(dir) >= -1e-5
            let startDistance = (origin - startClosest).length
            if startDistance < clearance, away {
                minDistance = min(minDistance, startDistance)
                continue
            }

            let dist = segmentDistance(origin, end, obstacle.a, obstacle.b)
            minDistance = min(minDistance, dist)
            if dist < clearance { return (false, minDistance) }
        }
        return (true, minDistance)
    }

    private static func normalizeAngle(_ angle: Float) -> Float {
        var value = angle
        while value > .pi { value -= 2 * .pi }
        while value < -.pi { value += 2 * .pi }
        return value
    }

    private static func closestPointOnSegment(point: Vector2, segment: Segment2D) -> Vector2 {
        let v = segment.b - segment.a
        let lenSq = v.dot(v)
        guard lenSq > 1e-8 else { return segment.a }
        let t = max(0, min(1, (point - segment.a).dot(v) / lenSq))
        return segment.a + v * t
    }

    private static func segmentDistance(_ a: Vector2, _ b: Vector2, _ c: Vector2, _ d: Vector2) -> Float {
        if segmentsIntersect(a, b, c, d) { return 0 }
        return min(
            min(pointSegmentDistance(a, Segment2D(a: c, b: d)),
                pointSegmentDistance(b, Segment2D(a: c, b: d))),
            min(pointSegmentDistance(c, Segment2D(a: a, b: b)),
                pointSegmentDistance(d, Segment2D(a: a, b: b)))
        )
    }

    private static func pointSegmentDistance(_ point: Vector2, _ segment: Segment2D) -> Float {
        (point - closestPointOnSegment(point: point, segment: segment)).length
    }

    private static func segmentsIntersect(_ a: Vector2, _ b: Vector2, _ c: Vector2, _ d: Vector2) -> Bool {
        func orient(_ a: Vector2, _ b: Vector2, _ c: Vector2) -> Float {
            (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)
        }
        let o1 = orient(a, b, c)
        let o2 = orient(a, b, d)
        let o3 = orient(c, d, a)
        let o4 = orient(c, d, b)
        return (o1 > 0) != (o2 > 0) && (o3 > 0) != (o4 > 0)
    }

    // MARK: - Pocket reachability (hint only, not infeasibility)

    /// Whether the dynamically-adjusted aim point lands within `1.5 × pocketRadius`
    /// of the pocket marker — used as a **soft hint** to flag "贴库困难球"。
    ///
    /// 这个判定**不影响** `isFeasible`（即不会让袋口被标为不可进），
    /// 仅用于 UI 在数据面板上提示用户"该球位贴库较深，进球点偏离袋口中心"。
    static func isPocketReachable(
        target: SCNVector3,
        pocketIndex: Int,
        surfaceY: Float
    ) -> Bool {
        let positions = pocketPositions(surfaceY: surfaceY)
        guard pocketIndex >= 0, pocketIndex < positions.count else { return false }
        let pocket = positions[pocketIndex]
        let aim = effectivePocketAimPoint(
            targetBall: target, pocketIndex: pocketIndex, surfaceY: surfaceY
        )
        let pocketR = pocketIndex < 4 ? cornerPocketRadius : middlePocketRadius
        let dx = aim.x - pocket.x
        let dz = aim.z - pocket.z
        return sqrtf(dx * dx + dz * dz) <= pocketR * 1.5
    }

    // MARK: - Cut angle (degrees)

    /// Cut angle α between the pocket line (target→pocket) and the strike line (cue→ghost).
    /// Returns value in degrees [0, 90].
    static func cutAngle(cueBall: SCNVector3, targetBall: SCNVector3, pocket: SCNVector3) -> Double {
        let pocketDirX = Double(pocket.x - targetBall.x)
        let pocketDirZ = Double(pocket.z - targetBall.z)
        let pocketDist = sqrt(pocketDirX * pocketDirX + pocketDirZ * pocketDirZ)
        guard pocketDist > 0.0001 else { return 0 }

        let ghost = ghostBallPosition(targetBall: targetBall, pocket: pocket, ballRadius: ballRadius)
        let strikeDirX = Double(ghost.x - cueBall.x)
        let strikeDirZ = Double(ghost.z - cueBall.z)
        let strikeDist = sqrt(strikeDirX * strikeDirX + strikeDirZ * strikeDirZ)
        guard strikeDist > 0.0001 else { return 0 }

        let pnX = pocketDirX / pocketDist
        let pnZ = pocketDirZ / pocketDist
        let snX = strikeDirX / strikeDist
        let snZ = strikeDirZ / strikeDist

        let dot = max(-1, min(1, pnX * snX + pnZ * snZ))
        let angle = acos(dot) * 180.0 / .pi
        return min(angle, 90)
    }

    // MARK: - Feasibility

    // 自动选择袋口/可行性判断的最大切球角阈值。
    // 物理极限是 90°（动量传递 = 0），但 acos 在边界附近浮点抖动严重，
    // 用 89° 兼顾"几何允许"与"数值稳定"。
    static let maxCutAngle: Double = 89

    /// Whether a pocket is viable for the given ball configuration.
    static func isFeasible(cueBall: SCNVector3, targetBall: SCNVector3, pocket: SCNVector3) -> Bool {
        let angle = cutAngle(cueBall: cueBall, targetBall: targetBall, pocket: pocket)
        if angle >= maxCutAngle { return false }
        if isCueBallBlocking(cueBall: cueBall, targetBall: targetBall, pocket: pocket) { return false }
        return true
    }

    /// Whether the cue ball sits on the pocket line between target and pocket,
    /// blocking the target ball's path into the pocket.
    static func isCueBallBlocking(cueBall: SCNVector3, targetBall: SCNVector3, pocket: SCNVector3) -> Bool {
        let lineX = pocket.x - targetBall.x
        let lineZ = pocket.z - targetBall.z
        let lineLenSq = lineX * lineX + lineZ * lineZ
        guard lineLenSq > 0.0001 else { return false }

        let toX = cueBall.x - targetBall.x
        let toZ = cueBall.z - targetBall.z
        let t = (toX * lineX + toZ * lineZ) / lineLenSq
        guard t > 0, t < 1 else { return false }

        let projX = targetBall.x + t * lineX
        let projZ = targetBall.z + t * lineZ
        let distSq = (cueBall.x - projX) * (cueBall.x - projX) + (cueBall.z - projZ) * (cueBall.z - projZ)
        return distSq < (2.5 * ballRadius) * (2.5 * ballRadius)
    }

    /// Whether any obstacle ball blocks a moving ball travelling from `from` to `to`
    /// (centre path). Collision condition: obstacle centre within `2R` of the path
    /// segment (X–Z plane). Projection is clamped to [0, 1] so obstacles hugging
    /// either endpoint also count as blocking (conservative gate for auto-selection).
    static func isPathBlocked(
        from: SCNVector3,
        to: SCNVector3,
        obstacles: [SCNVector3],
        clearance: Float = 2 * ballRadius
    ) -> Bool {
        let lineX = to.x - from.x
        let lineZ = to.z - from.z
        let lineLenSq = lineX * lineX + lineZ * lineZ
        guard lineLenSq > 0.0001 else { return false }
        let clearanceSq = clearance * clearance

        for obstacle in obstacles {
            let toX = obstacle.x - from.x
            let toZ = obstacle.z - from.z
            let t = max(0, min(1, (toX * lineX + toZ * lineZ) / lineLenSq))
            let projX = from.x + t * lineX
            let projZ = from.z + t * lineZ
            let dx = obstacle.x - projX
            let dz = obstacle.z - projZ
            if dx * dx + dz * dz < clearanceSq { return true }
        }
        return false
    }

    // MARK: - Snooker coverage (角度张角遮挡判定)

    /// 「做斯诺克」遮挡度量（X–Z 平面，世界系）。
    ///
    /// 判的不是「球心连线被挡」（那是 `isPathBlocked` 的保守自动选袋闸），而是**对手能否从母球
    /// 看到被困球的任意一点**：母球（半径 R）沿直线击出，球心扫过被困球（半径 R）即算「看得见」，
    /// 故可见方向是一个**张角扇形**，半角 `α = asin(2R / d_被困)`。障碍球同样在母球处张开半角
    /// `β = asin(2R / d_障碍)`，方向与被困球方向相差 `Δθ`。
    ///
    /// **完全斯诺克 ⟺ 障碍的角区间完整包住被困球可见区间，且障碍比被困球近**（先被拦截）。
    /// 闭式：`coverage = β − α − |Δθ|`（弧度）。`coverage ≥ 0 ∧ d_障碍 < d_被困` ⇒ 完全挡死；
    /// `coverage` 转度即「覆盖余量」（正 = 还多挡几度、越大越难薄擦解开；负 = 仍露出多少度）。
    struct SnookerCoverage {
        /// 覆盖余量（度）：正 = 完全挡死且多挡 N°；负 = 仍露出 N°（半斯诺克）。
        let marginDegrees: Float
        /// 障碍是否比被困球更近（更近才会先拦截母球）。
        let blockerCloser: Bool
        /// 被困球相对母球的可见半张角（度，仅供文案/调试）。
        let visibleHalfAngleDegrees: Float
        /// 是否构成完全斯诺克。
        var isFullSnooker: Bool { blockerCloser && marginDegrees >= 0 }
    }

    /// 计算母球终点 `cue` 看向被困球 `snookered`、被 `blocker` 遮挡的覆盖度量（均为世界系球心）。
    /// 三点退化（距离 ≤ 2R 的接触态）按 asin 定义域钳制（贴球 ⇒ 障碍张角趋近 90°，物理上确实遮挡极大）。
    static func snookerCoverage(
        cue: SCNVector3, snookered: SCNVector3, blocker: SCNVector3,
        ballRadius: Float = ballRadius
    ) -> SnookerCoverage {
        let twoR = 2 * ballRadius
        let dT = horizontalDistance(cue, snookered)
        let dB = horizontalDistance(cue, blocker)
        // 角度按 SceneKit 水平角 atan2(z, x)。
        let aT = atan2f(snookered.z - cue.z, snookered.x - cue.x)
        let aB = atan2f(blocker.z - cue.z, blocker.x - cue.x)
        // 最小角差（归一化到 [−π, π]，规避 ±π 环绕）。
        let dTheta = atan2f(sinf(aB - aT), cosf(aB - aT))
        let alpha = asinf(min(0.999, twoR / max(twoR, dT)))
        let beta = asinf(min(0.999, twoR / max(twoR, dB)))
        let coverage = beta - alpha - abs(dTheta)
        let toDeg: Float = 180 / .pi
        return SnookerCoverage(
            marginDegrees: coverage * toDeg,
            blockerCloser: dB < dT,
            visibleHalfAngleDegrees: alpha * toDeg
        )
    }

    // MARK: - Defense (V8：多被困球 + 多遮挡球联合可见性 + 对手进球难度)

    /// 单颗被困球被**多颗候选遮挡球**评估：取「最能挡死」的那颗（完全斯诺克优先，
    /// 都不完全时取覆盖余量最大者 = 最接近全遮）。坐标：世界系 X–Z 球心。
    /// 注意：只有比被困球**更近**（`blockerCloser`）的遮挡球才可能先拦截母球视线，
    /// 更远的遮挡球即便张角大也挡不住（其覆盖余量对本颗不成立），排序时按此过滤。
    static func snookerCoverageMulti(
        cue: SCNVector3, snookered: SCNVector3, blockers: [(key: String, pos: SCNVector3)],
        ballRadius: Float = ballRadius
    ) -> SnookerCoverage {
        var best: SnookerCoverage?
        for b in blockers {
            let cov = snookerCoverage(cue: cue, snookered: snookered, blocker: b.pos,
                                      ballRadius: ballRadius)
            if best == nil || defenseRank(cov) > defenseRank(best!) { best = cov }
        }
        return best ?? SnookerCoverage(marginDegrees: -180, blockerCloser: false,
                                       visibleHalfAngleDegrees: 0)
    }

    /// 遮挡候选排序键：完全斯诺克（更近 + 余量≥0）绝对优先；否则「更近 + 余量」大者更接近全遮，
    /// 更远的遮挡球给一个显著的负基准（挡不住）。用于 `snookerCoverageMulti` 取最优遮挡。
    private static func defenseRank(_ c: SnookerCoverage) -> Float {
        if c.isFullSnooker { return 1000 + c.marginDegrees }        // 完全挡死：余量越大越稳
        if c.blockerCloser { return c.marginDegrees }               // 更近但未全遮：余量（负）越大越接近
        return -1000 + c.marginDegrees                              // 更远：挡不住
    }

    /// 一颗对方球从母球终位看的防守评估（V8）。
    struct DefenseBallCoverage {
        let key: String
        /// 是否被某颗球完全挡死（完全斯诺克）。
        let blocked: Bool
        /// 最佳遮挡余量（度）：`blocked` 时 ≥0 且越大越稳；未遮挡时为「最接近全遮」的度量（多为负）。
        let coverageMarginDeg: Float
        /// 未遮挡时对手从母球终位把这颗球打进的**难度** [0,1]（长台 + 大切角 + 可行袋越少 → 越难 → 防守越好）；
        /// `blocked` 记为 1（对手根本看不到，等价最难）。
        let pottingDifficulty: Double
    }

    // MARK: 防守难度权重（V8 可跑 v1，待实测调优 —— 回写真源由主控做）

    /// 未遮挡球「进球难度」中切角项权重（切角越大越难瞄准）。
    static let defenseCutWeight = 0.6
    /// 未遮挡球「进球难度」中球距项权重（长台越远越难）。
    static let defenseDistanceWeight = 0.4
    /// 球距难度归一参考长度（米）：满台长边 ≈ innerLength。
    static var defenseDistanceReference: Float { innerLength }

    /// 多颗对方球联合防守评估：对每颗对方球，用「除它与母球外的全部非母球」做遮挡候选取最佳遮挡；
    /// 未被挡死的球计算对手进球难度（长台/大切角/可行袋）。
    /// - Parameters:
    ///   - cueFinal: 母球终位（世界系球心）。
    ///   - opponents: 需要隐藏的对方球（key + 终位）。
    ///   - nonCueBalls: 全部非母球终位（含对方球本身，可互相遮挡；也含我方球/8 号作遮挡体）。
    ///   - surfaceY: 台面 Y。
    static func defenseCoverage(
        cueFinal: SCNVector3,
        opponents: [(key: String, pos: SCNVector3)],
        nonCueBalls: [(key: String, pos: SCNVector3)],
        surfaceY: Float
    ) -> [DefenseBallCoverage] {
        let pockets = pocketPositions(surfaceY: surfaceY)
        return opponents.map { opp in
            let blockers = nonCueBalls.filter { $0.key != opp.key }
            let cov = snookerCoverageMulti(cue: cueFinal, snookered: opp.pos, blockers: blockers)
            if cov.isFullSnooker {
                return DefenseBallCoverage(key: opp.key, blocked: true,
                                           coverageMarginDeg: cov.marginDegrees,
                                           pottingDifficulty: 1.0)
            }
            let diff = opponentPottingDifficulty(
                cue: cueFinal, ball: opp.pos, pockets: pockets,
                others: blockers.map { $0.pos })
            return DefenseBallCoverage(key: opp.key, blocked: false,
                                       coverageMarginDeg: cov.marginDegrees,
                                       pottingDifficulty: diff)
        }
    }

    /// 对手从母球终位把一颗可见球打进的难度 [0,1]。取「最易袋」（可行袋中切角最小者）：
    /// 无任何可行袋 ⇒ 1（打不进 = 防守极好）；否则按切角 + 球距加权。`others` 用于袋线遮挡剔除。
    static func opponentPottingDifficulty(
        cue: SCNVector3, ball: SCNVector3, pockets: [SCNVector3], others: [SCNVector3]
    ) -> Double {
        var bestCutDeg: Double?
        for pocket in pockets {
            // 可行：切角 < 上限，且袋线（球→袋）未被其它球挡死。
            guard isFeasible(cueBall: cue, targetBall: ball, pocket: pocket) else { continue }
            let aim = SCNVector3(pocket.x, ball.y, pocket.z)
            if isPathBlocked(from: ball, to: aim, obstacles: others) { continue }
            let cut = cutAngle(cueBall: cue, targetBall: ball, pocket: pocket)
            if bestCutDeg == nil || cut < bestCutDeg! { bestCutDeg = cut }
        }
        guard let cut = bestCutDeg else { return 1.0 }   // 无可行袋 ⇒ 对手打不进
        let cutTerm = min(1.0, cut / 90.0)
        let dist = Double(horizontalDistance(cue, ball))
        let distTerm = min(1.0, dist / Double(defenseDistanceReference))
        let d = defenseCutWeight * cutTerm + defenseDistanceWeight * distTerm
        return min(1.0, max(0.0, d))
    }

    // MARK: - Contact point position

    /// Contact point on the target ball surface at the moment of impact.
    /// At impact the cue ball center sits at the ghost-ball position, so the contact
    /// point lies on the line from target → ghost (i.e. opposite the pocket direction),
    /// at distance R from the target center. Independent of the cue ball's current position.
    static func contactPointPosition(targetBall: SCNVector3, pocket: SCNVector3) -> SCNVector3 {
        let dx = pocket.x - targetBall.x
        let dz = pocket.z - targetBall.z
        let dist = sqrtf(dx * dx + dz * dz)
        guard dist > 0.001 else { return targetBall }
        return SCNVector3(
            targetBall.x - ballRadius * (dx / dist),
            targetBall.y,
            targetBall.z - ballRadius * (dz / dist)
        )
    }

    // MARK: - Ball overlap / distance checks

    /// Horizontal distance between two ball positions (ignoring Y).
    static func horizontalDistance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x
        let dz = a.z - b.z
        return sqrtf(dx * dx + dz * dz)
    }

    /// Whether two balls overlap (center distance < 2R).
    static func ballsOverlap(_ a: SCNVector3, _ b: SCNVector3) -> Bool {
        horizontalDistance(a, b) < 2 * ballRadius
    }

    /// Clamp a position so it stays >= 2R from the other ball and inside table bounds.
    static func clampBallPosition(_ pos: SCNVector3, otherBall: SCNVector3, surfaceY: Float) -> SCNVector3 {
        let halfL = innerLength / 2
        let halfW = innerWidth / 2
        let r = ballRadius
        var x = max(-halfL + r, min(halfL - r, pos.x))
        var z = max(-halfW + r, min(halfW - r, pos.z))

        let dx = x - otherBall.x
        let dz = z - otherBall.z
        let dist = sqrtf(dx * dx + dz * dz)
        let minDist: Float = 2 * r + 0.001
        if dist < minDist, dist > 0.0001 {
            x = otherBall.x + (dx / dist) * minDist
            z = otherBall.z + (dz / dist) * minDist
            x = max(-halfL + r, min(halfL - r, x))
            z = max(-halfW + r, min(halfW - r, z))
        }

        return SCNVector3(x, surfaceY + ballRadius, z)
    }

    /// Clamp a position so it stays > 2R from any pocket center.
    static func clampAwayFromPockets(_ pos: SCNVector3, surfaceY: Float) -> SCNVector3 {
        let pockets = pocketPositions(surfaceY: surfaceY)
        var x = pos.x
        var z = pos.z
        let minDist: Float = 2 * ballRadius + 0.005
        for p in pockets {
            let dx = x - p.x
            let dz = z - p.z
            let dist = sqrtf(dx * dx + dz * dz)
            if dist < minDist, dist > 0.0001 {
                x = p.x + (dx / dist) * minDist
                z = p.z + (dz / dist) * minDist
            }
        }
        let halfL = innerLength / 2
        let halfW = innerWidth / 2
        let r = ballRadius
        x = max(-halfL + r, min(halfL - r, x))
        z = max(-halfW + r, min(halfW - r, z))
        return SCNVector3(x, pos.y, z)
    }

    // MARK: - Free-aim first contact (P18 B2：自由瞄准首碰纯几何预览)

    /// 自由瞄准首碰结果：沿瞄准射线第一颗被碰球 + 接触瞬间母球球心（= 假想球）+ 切球角。
    struct FreeAimContact {
        let targetKey: String
        /// 接触瞬间母球球心（假想球位置，场景坐标）。
        let ghost: SCNVector3
        /// 切球角 α（0° = 正撞全球，→90° 极薄）。
        let cutAngleDeg: Double
    }

    /// 沿瞄准射线的第一颗被碰球（纯几何，主线程逐帧可用）：母球球心沿 `dir` 前进，
    /// 与某球球心距离首次到达 2R 即接触；切球角 = 瞄准方向与撞击线（假想球→目标球心）夹角。
    /// 坐标契约：场景 XZ 平面，`dir` 为单位向量；返回 nil = 射线不与任何球相交（空杆）。
    static func freeAimFirstContact(
        cue: SCNVector3, dir: SCNVector3, balls: [(key: String, pos: SCNVector3)]
    ) -> FreeAimContact? {
        let twoR = 2 * ballRadius
        var best: (key: String, t: Float, pos: SCNVector3)?
        for (key, p) in balls {
            let dx = p.x - cue.x, dz = p.z - cue.z
            let proj = dx * dir.x + dz * dir.z
            guard proj > 0 else { continue }                    // 球在身后
            let perpSq = dx * dx + dz * dz - proj * proj
            let radSq = twoR * twoR - perpSq
            guard radSq > 0 else { continue }                   // 射线走廊之外
            let t = proj - sqrtf(radSq)
            guard t > 0.0005 else { continue }
            if best == nil || t < best!.t { best = (key, t, p) }
        }
        guard let hit = best else { return nil }
        let ghost = SCNVector3(cue.x + dir.x * hit.t, cue.y, cue.z + dir.z * hit.t)
        let ix = hit.pos.x - ghost.x, iz = hit.pos.z - ghost.z
        let ilen = sqrtf(ix * ix + iz * iz)
        guard ilen > 1e-5 else { return nil }
        let cosA = max(-1, min(1, (ix * dir.x + iz * dir.z) / ilen))
        return FreeAimContact(targetKey: hit.key, ghost: ghost,
                              cutAngleDeg: Double(acosf(cosA)) * 180 / .pi)
    }

    /// 瞄准轮增益的杠杆臂（米）：母球 → 首碰球心；无首碰（空杆）时取射线**前方**最近球，
    /// 前方无球则回落到最近球；桌上无其他球返回 nil（调用方用默认档）。
    ///
    /// 坐标契约：场景 XZ 平面，`dir` 单位向量。杠杆臂直接喂 `AimWheelGain.degreesPerPoint`
    /// 使同样一指位移在目标球处产生等毫米横移（v23 D-v23-4=B / W2）。
    static func aimLeverMeters(
        cue: SCNVector3, dir: SCNVector3?, balls: [(key: String, pos: SCNVector3)]
    ) -> Float? {
        guard !balls.isEmpty else { return nil }
        func planarDistance(_ p: SCNVector3) -> Float {
            hypotf(p.x - cue.x, p.z - cue.z)
        }
        if let dir, let contact = freeAimFirstContact(cue: cue, dir: dir, balls: balls),
           let hit = balls.first(where: { $0.key == contact.targetKey }) {
            return planarDistance(hit.pos)
        }
        if let dir {
            let ahead = balls.filter { b in
                (b.pos.x - cue.x) * dir.x + (b.pos.z - cue.z) * dir.z > 0
            }
            if let nearest = ahead.map({ planarDistance($0.pos) }).min() { return nearest }
        }
        return balls.map { planarDistance($0.pos) }.min()
    }

    /// 瞄准方向 → 屏幕罗盘角（topDown2DRotated 取景：screen-up = world +X、
    /// screen-right = world +Z；0° = 屏幕正上方，顺时针为正）。
    /// 坐标契约：`dir` 为场景 XZ 单位向量，bearing = atan2(z, x)。
    static func bearingDeg(of dir: SCNVector3) -> Float {
        var deg = atan2f(dir.z, dir.x) * 180 / .pi
        if deg < 0 { deg += 360 }
        return deg
    }

    /// 把 XZ 方向按屏幕顺时针（bearing 增）旋转 `delta` 度：
    /// newX = x·cosΔ − z·sinΔ，newZ = x·sinΔ + z·cosΔ。幅值过小时返回原方向。
    static func rotatedAim(_ dir: SCNVector3, byDegrees delta: Float) -> SCNVector3 {
        let r = delta * .pi / 180
        let nx = dir.x * cosf(r) - dir.z * sinf(r)
        let nz = dir.x * sinf(r) + dir.z * cosf(r)
        let len = sqrtf(nx * nx + nz * nz)
        guard len > 1e-5 else { return dir }
        return SCNVector3(nx / len, 0, nz / len)
    }

    /// G13 空白处拖动 = 「先选中瞄准线、再相对旋转」：把一段屏幕拖动换算成绕**母球屏幕投影**
    /// 的角位移（度），供 `nudgeFreeAim` / `rotatedAim` 消费。第一落点不调用本函数（只选中不转向）。
    ///
    /// 坐标契约（几何任务，钉死后再落码）：
    /// - 入参 `cueScreen` / `prev` / `cur` 均为 **SCNView 本地屏幕点**（原点左上、+x 右、+y 下，单位 pt）。
    /// - 返回度数沿用「**屏幕顺时针为正**」约定，与 `rotatedAim(_:byDegrees:)`、`bearingDeg(of:)` 一致：
    ///   y 朝下时 `atan2(dy, dx)` 递增即屏幕顺时针；两 2D 顶视相机均为**垂直俯拍**台面平面
    ///   （所有台面点等深）⇒ 平面→屏幕为相似变换（等比、无镜像）⇒ 屏幕角位移 == 世界瞄准 bearing 角位移，
    ///   可直接喂给 `rotatedAim`。
    ///
    /// 增益与「随母球距离缩放」（G13 目标 2）：采用**绕母球公转**模型——手指绕母球转过多少角度，
    /// 瞄准线就转过多少（"抓住线甩"），故径向拖动不转向、切向拖动才转向，且天然随杠杆缩放：
    /// 手指离母球越远（杠杆越长）同样位移旋转越小（细调），越近越粗。近母球处角增益发散，
    /// 用 `maxGainDegPerPt` 封顶——等价最小杠杆臂 `minLever = (180/π)/maxGainDegPerPt`：
    /// 手指落在 minLever 内时角位移按 `r/minLever` 线性衰减，令切向增益不超过 `maxGainDegPerPt` 度/pt。
    /// - Parameter maxGainDegPerPt: 近母球封顶的最大切向角增益（度/pt）。默认 0.6（粗调，约为
    ///   `BTAimWheel` 细调 0.15 度/pt 的 4 倍；远离母球时按 (180/π)/r 递减，典型 r≈200pt ⇒ ≈0.29 度/pt）。
    static func aimNudgeDegrees(cueScreen: CGPoint, from prev: CGPoint, to cur: CGPoint,
                                maxGainDegPerPt: CGFloat = 0.6) -> Float {
        let minLever = CGFloat(180.0 / Double.pi) / maxGainDegPerPt
        let vPrev = CGPoint(x: prev.x - cueScreen.x, y: prev.y - cueScreen.y)
        let vCur  = CGPoint(x: cur.x  - cueScreen.x, y: cur.y  - cueScreen.y)
        let rPrev = hypot(vPrev.x, vPrev.y)
        let rCur  = hypot(vCur.x, vCur.y)
        // 任一端点贴母球（半径退化到 <1pt）无法定义可靠角度 ⇒ 不旋转。
        guard rPrev > 1, rCur > 1 else { return 0 }
        var dPhi = atan2(Double(vCur.y), Double(vCur.x)) - atan2(Double(vPrev.y), Double(vPrev.x))
        // 归一化到 [-π, π]，避免越过 ±180° 分支时的整圈突跳。
        while dPhi > .pi { dPhi -= 2 * .pi }
        while dPhi < -.pi { dPhi += 2 * .pi }
        let atten = Double(min(1, min(rPrev, rCur) / minLever))
        return Float(dPhi * 180 / .pi * atten)
    }

    /// 沿射线求与「库内边界（各方向缩一颗球半径）」的首个交点，用于空杆瞄准线延伸到库边。
    /// 坐标契约：长库 = 常 Z（±(innerWidth/2 − R)）、短库 = 常 X（±(innerLength/2 − R)），
    /// 与 `clampMultiBall` 同式。方向近乎零或无交点时返回起点。
    /// `inset = 0` reaches the cloth edge for instructional guide lines.
    static func rayToInnerRail(from p: SCNVector3, dir: SCNVector3,
                               inset: Float = ballRadius) -> SCNVector3 {
        let halfL = innerLength / 2 - inset
        let halfW = innerWidth / 2 - inset
        var t = Float.greatestFiniteMagnitude
        if dir.x > 1e-5 { t = min(t, (halfL - p.x) / dir.x) }
        if dir.x < -1e-5 { t = min(t, (-halfL - p.x) / dir.x) }
        if dir.z > 1e-5 { t = min(t, (halfW - p.z) / dir.z) }
        if dir.z < -1e-5 { t = min(t, (-halfW - p.z) / dir.z) }
        if !t.isFinite || t < 0 { t = 0 }
        return SCNVector3(p.x + dir.x * t, p.y, p.z + dir.z * t)
    }

    // MARK: - Ball thickness (经典球厚度通称 · 单一真源)

    /// Classic ball-thickness naming: name ↔ cut angle ↔ overlap ↔ d/R.
    ///
    /// Angle contract (see `geometry-spatial-reasoning` + `table-geometry.md`):
    /// - θ = geometric cut angle (degrees) between cue aim and object→pocket line.
    /// - `overlap` ∈ [0, 1] = fraction of object-ball diameter still overlapping the
    ///   cue silhouette when viewed along the aim (1 = full ball, 0 = grazing).
    /// - Identity: `sin(θ) = 1 − overlap` (classic thickness), θ ∈ [0°, 90°].
    /// - Aim-line lateral offset in ball radii: `d/R = 2·sin(θ) = 2·(1 − overlap)`.
    ///
    /// D1 (问题集合 v7): 「3/4 球」= overlap 0.75 → sinθ=0.25 → θ≈14.5°（非 48.6° 偏移口径）.
    struct NamedBallThickness: Equatable, Sendable {
        let name: String
        /// Overlap fraction of ball diameter (classic thickness).
        let overlap: Double
        /// Display cut angle in degrees (1 decimal), from `asin(1 − overlap)`.
        let cutAngleDegrees: Double
        /// Lateral displacement in ball-radius units: `2·sin(θ)`.
        let dOverR: Double

        /// Build from classic overlap; cut angle and d/R are derived.
        static func classic(name: String, overlap: Double) -> NamedBallThickness {
            let clamped = min(1, max(0, overlap))
            let sinTheta = 1 - clamped
            let thetaDeg = asin(sinTheta) * 180 / .pi
            let display = (thetaDeg * 10).rounded() / 10
            return NamedBallThickness(
                name: name,
                overlap: clamped,
                cutAngleDegrees: display,
                dOverR: 2 * sinTheta
            )
        }
    }

    static let fullBall = NamedBallThickness.classic(name: "全球", overlap: 1.0)
    static let threeQuarterBall = NamedBallThickness.classic(name: "3/4 球", overlap: 0.75)
    static let halfBall = NamedBallThickness.classic(name: "半球", overlap: 0.5)
    static let quarterBall = NamedBallThickness.classic(name: "1/4 球", overlap: 0.25)
    static let thinBall = NamedBallThickness.classic(name: "极薄球", overlap: 0.0)

    /// Canonical named thicknesses (classic overlap definition).
    static let namedBallThicknesses: [NamedBallThickness] = [
        fullBall, threeQuarterBall, halfBall, quarterBall, thinBall
    ]

    static func namedBallThickness(name: String) -> NamedBallThickness? {
        namedBallThicknesses.first { $0.name == name }
    }

    /// Nearest named thickness within `tolerance` degrees, if any.
    static func namedBallThickness(cutAngleDegrees: Double, tolerance: Double = 2.5) -> NamedBallThickness? {
        namedBallThicknesses
            .map { ($0, abs($0.cutAngleDegrees - cutAngleDegrees)) }
            .filter { $0.1 <= tolerance }
            .min(by: { $0.1 < $1.1 })?
            .0
    }

    /// Display nickname for a cut angle. Classic-thickness naming only (D1);
    /// legacy offset-fraction approximations (7.5°→"≈1/4 球", 10°→"≈1/3 球")
    /// were removed — they are wrong under the classic overlap convention.
    static func thicknessName(cutAngle: Double) -> String {
        if let named = namedBallThickness(cutAngleDegrees: cutAngle, tolerance: 2.5) {
            return named.name
        }
        // Wide tail for near-grazing cuts (legacy HUD behaviour).
        if cutAngle > 80 { return thinBall.name }
        return "—"
    }
}
