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

    /// Pocket opening radii (metres). Angle = corner pocket, middle = side pocket.
    /// Source: `.kiro/steering/table-geometry.md` § 进袋检测数值（中式八球标准）。
    static let cornerPocketRadius: Float = 0.042
    static let middlePocketRadius: Float = 0.043

    /// Pocket-center offsets relative to the playing-area boundary.
    /// Steering 文档（中式八球标准物理几何）给出的是 42mm / 53mm；
    /// 当前 USDZ 模型 `TaiQiuZhuo.usdz` 的袋口洞中心比标准位置略 **靠内**
    /// （朝击球区方向），实测约偏 12mm / 9mm，因此这里在标准值上 **减去**
    /// `cornerPocketModelDelta` / `middlePocketModelDelta`，
    /// 让黄色标记圆盘视觉上正好落在模型袋口洞的几何中心。
    /// 注：调整 USDZ 模型时需重新校准这两个 delta（用 2D 顶视图肉眼对位即可）。
    private static let cornerPocketStandardOffset: Float = 0.042
    private static let middlePocketStandardOffset: Float = 0.053
    private static let cornerPocketModelDelta: Float = 0.012
    private static let middlePocketModelDelta: Float = 0.009
    private static let cornerPocketOffset: Float =
        cornerPocketStandardOffset - cornerPocketModelDelta
    private static let middlePocketOffset: Float =
        middlePocketStandardOffset - middlePocketModelDelta

    /// Six pocket centers at table surface level (real pocket-hole centers, not the
    /// playing-area corners). Used for both aim math (so calculations target the
    /// actual hole) and visual marker placement (so the yellow disc sits on the hole).
    static func pocketPositions(surfaceY: Float) -> [SCNVector3] {
        let halfL = innerLength / 2
        let halfW = innerWidth / 2
        let c = cornerPocketOffset
        let m = middlePocketOffset
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
        // 中袋 mouth 端点：(±0.035, ±0.635) — 长边在中点处的两个开口端
        func middle(sz: Float) -> (SCNVector3, SCNVector3) {
            (
                SCNVector3(-0.035, y, sz * 0.635),
                SCNVector3(+0.035, y, sz * 0.635)
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
        let clearance = ballRadius + aimMargin
        let origin = Vector2(targetBall.x, targetBall.z)
        let pocket = Vector2(nominalPocket.x, nominalPocket.z)
        let naturalVector = pocket - origin
        guard naturalVector.length > 0.0001 else { return nominalPocket }

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

        let targetJawDistance = geometry.mouth.targetJaws.map {
            segmentDistance(origin, pipeEnd, $0.a, $0.b)
        }.min() ?? Float.greatestFiniteMagnitude

        if targetJawDistance < clearance {
            let boundaryTolerance: Float = 0.004
            return ordinary.minDistance <= clearance + boundaryTolerance
        }

        return true
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

    private struct PocketMouth {
        let center: Vector2
        let mouthA: Vector2
        let mouthB: Vector2
        let targetJaws: [Segment2D]
    }

    private struct PipeGeometry {
        let mouth: PocketMouth
        let ordinaryObstacles: [Segment2D]
    }

    private static func buildPipeGeometry(pocketIndex: Int, pocketCenter: Vector2) -> PipeGeometry {
        let mouths = pocketMouths()
        let mouth = mouths[pocketIndex]
        var ordinary: [Segment2D] = []

        func add(_ ax: Float, _ az: Float, _ bx: Float, _ bz: Float) {
            ordinary.append(Segment2D(a: Vector2(ax, az), b: Vector2(bx, bz)))
        }

        add(-1.1671, -0.635, -0.035, -0.635)
        add( 0.035, -0.635,  1.1671, -0.635)
        add(-1.1671,  0.635, -0.035,  0.635)
        add( 0.035,  0.635,  1.1671,  0.635)
        add(-1.270, -0.5321, -1.270,  0.5321)
        add( 1.270, -0.5321,  1.270,  0.5321)

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
                targetJaws: mouth.targetJaws
            ),
            ordinaryObstacles: ordinary
        )
    }

    private static func pocketMouths() -> [PocketMouth] {
        func corner(sx: Float, sz: Float, center: Vector2) -> PocketMouth {
            let longInner = Vector2(sx * 1.2414, sz * 0.6658)
            let longOuter = Vector2(sx * 1.2823, sz * 0.7067)
            let shortInner = Vector2(sx * 1.3008, sz * 0.6064)
            let shortOuter = Vector2(sx * 1.3417, sz * 0.6473)
            return PocketMouth(
                center: center,
                mouthA: longInner,
                mouthB: shortInner,
                targetJaws: [
                    Segment2D(a: longInner, b: longOuter),
                    Segment2D(a: shortInner, b: shortOuter)
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
            PocketMouth(center: Vector2(0, -halfW - middlePocketOffset),
                        mouthA: Vector2(-0.035, -halfW), mouthB: Vector2(0.035, -halfW),
                        targetJaws: []),
            PocketMouth(center: Vector2(0, halfW + middlePocketOffset),
                        mouthA: Vector2(-0.035, halfW), mouthB: Vector2(0.035, halfW),
                        targetJaws: [])
        ]
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

    // MARK: - Thickness name (通称)

    static func thicknessName(cutAngle: Double) -> String {
        if cutAngle < 2 { return "全球" }
        if abs(cutAngle - 7.5) < 3 { return "≈1/4 球" }
        if abs(cutAngle - 10) < 2 { return "≈1/3 球" }
        if abs(cutAngle - 30) < 5 { return "半球" }
        if abs(cutAngle - 48.6) < 5 { return "3/4 球" }
        if cutAngle > 80 { return "极薄球" }
        return "—"
    }
}
