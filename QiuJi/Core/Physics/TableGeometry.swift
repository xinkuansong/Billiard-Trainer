//
//  TableGeometry.swift
//  BilliardTrainer
//
//  程序化球台几何描述
//  角袋几何基于 CAD 精确数据（两独立圆弧圆心 + jaw 直线段）
//

import SceneKit

extension TableGeometry {
    /// Bind an actual mesh cushion contact to an existing finite CAD segment.
    /// This is metadata only: it neither moves the ball nor detects collisions.
    func nearestCushionIndex(to point:SIMD3<Double>)->Int? {
        typealias V=SIMD2<Double>
        let p=V(point.x,point.z)
        var best:(index:Int,distance:Double)?
        func consider(_ index:Int,_ q:V) {
            let d=p-q,distance=d.x*d.x+d.y*d.y
            if distance<(best?.distance ?? .infinity) { best=(index,distance) }
        }
        for (i,line) in linearCushions.enumerated() {
            let a=V(Double(line.start.x),Double(line.start.z)),b=V(Double(line.end.x),Double(line.end.z))
            let d=b-a,denom=d.x*d.x+d.y*d.y
            let t=denom>0 ? max(0,min(1,((p-a).x*d.x+(p-a).y*d.y)/denom)):0
            consider(i,a+d*t)
        }
        let tau=2*Double.pi
        func wrap(_ angle:Double)->Double { let r=angle.truncatingRemainder(dividingBy:tau);return r<0 ? r+tau:r }
        for (i,arc) in circularCushions.enumerated() {
            let center=V(Double(arc.center.x),Double(arc.center.z)),radius=Double(arc.radius)
            let start=Double(arc.startAngle),end=Double(arc.endAngle)
            let angle=atan2(p.y-center.y,p.x-center.x),span=wrap(end-start)
            let index=linearCushions.count+i
            for theta in [start,end] { consider(index,center+radius*V(cos(theta),sin(theta))) }
            if wrap(angle-start)<=span { consider(index,center+radius*V(cos(angle),sin(angle))) }
        }
        return best?.index
    }
}

struct Pocket {
    let id: String
    let center: SCNVector3
    let radius: Float
    let isCorner: Bool
}

struct LinearCushionSegment {
    let start: SCNVector3
    let end: SCNVector3
    let normal: SCNVector3
    /// 该段库边的反弹恢复系数。`nil` ⇒ 使用全局 `TablePhysics.cushionRestitution`。
    /// 袋口喉腔壁（侧壁/后壁）用更低的值（更"死"），使进袋的球能量衰减、settle 落袋，
    /// 过力度球撞后壁弹回 mouth = rattle 弹出（真实袋口行为，取代旧"大捕获圆真空"）。
    var restitution: Float? = nil
}

struct CircularCushionSegment {
    let center: SCNVector3
    let radius: Float
    let startAngle: Float
    let endAngle: Float
    /// 该弧段的反弹恢复系数。`nil` ⇒ 使用全局 `TablePhysics.cushionRestitution`。
    /// 袋口鼻尖圆角（jaw fillet）用更低的值（皮革/橡胶鼻头吸能远大于整条库边），
    /// 使低速沿库球触鼻尖后贴向孔圈而非弹回台内（贴库球进角袋标定，见 DIAG-R）。
    var restitution: Float? = nil
    
    /// Check whether an angle (radians, measured from +X axis CCW in the XZ plane)
    /// falls within this arc segment's angular range.
    func isAngleInRange(_ angle: Float) -> Bool {
        let twoPi = Float.pi * 2
        var a = angle.truncatingRemainder(dividingBy: twoPi)
        if a < 0 { a += twoPi }
        
        var s = startAngle.truncatingRemainder(dividingBy: twoPi)
        if s < 0 { s += twoPi }
        var e = endAngle.truncatingRemainder(dividingBy: twoPi)
        if e < 0 { e += twoPi }
        
        let eps: Float = 0.01
        if s <= e {
            return a >= s - eps && a <= e + eps
        } else {
            return a >= s - eps || a <= e + eps
        }
    }
    
    /// Outward-pointing normal at the given ball position (from arc center toward ball).
    func normal(at ballPosition: SCNVector3) -> SCNVector3 {
        let dx = ballPosition.x - center.x
        let dz = ballPosition.z - center.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 1e-8 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(dx / len, 0, dz / len)
    }
    
    /// Angle (radians) from arc center to the given point in the XZ plane.
    func angle(to point: SCNVector3) -> Float {
        let dx = point.x - center.x
        let dz = point.z - center.z
        var a = atan2f(dz, dx)
        if a < 0 { a += Float.pi * 2 }
        return a
    }
}

// MARK: - Corner Pocket CAD Geometry

/// One corner pocket's jaw geometry: two arcs (long-rail side + short-rail side) and two jaw lines.
/// Defined for RU (right-upper) base pocket, others derived by mirror.
private struct CornerJawGeometry {
    struct Arc {
        let centerX: Float
        let centerZ: Float
        let startAngle: Float  // radians, CCW from +X
        let endAngle: Float    // radians, CCW from +X; arc covers [startAngle, endAngle]
        let radius: Float
        
        /// Point on the arc at the given angle
        func point(at angle: Float) -> (x: Float, z: Float) {
            (centerX + radius * cosf(angle), centerZ + radius * sinf(angle))
        }
        
        /// Point where this arc connects to the main rail
        func railPoint(railSideAngle: Float) -> (x: Float, z: Float) {
            point(at: railSideAngle)
        }
    }
    
    struct JawLine {
        let startX: Float
        let startZ: Float
        let endX: Float
        let endZ: Float
        let normalX: Float
        let normalZ: Float
    }
    
    let longArc: Arc
    let shortArc: Arc
    let longJaw: JawLine
    let shortJaw: JawLine
    /// Which angle of the long arc connects to the main (long) rail
    let longArcRailAngle: Float
    /// Which angle of the short arc connects to the main (short) rail
    let shortArcRailAngle: Float
}

/// Build RU base pocket geometry and derive other corners via mirror.
private func buildCornerJawGeometries() -> [CornerJawGeometry] {
    let R: Float = TablePhysics.cornerPocketFilletRadius  // 0.105 m
    let invSqrt2: Float = 1.0 / sqrtf(2.0)
    
    // RU (right-upper) base data from CAD, units in meters
    let ru = CornerJawGeometry(
        longArc: .init(
            centerX: 1.1671106, centerZ: 0.740,
            startAngle: 3 * .pi / 2,     // 270°
            endAngle: 7 * .pi / 4,       // 315°
            radius: R
        ),
        shortArc: .init(
            centerX: 1.375, centerZ: 0.5321106,
            startAngle: 3 * .pi / 4,     // 135°
            endAngle: .pi,               // 180°
            radius: R
        ),
        longJaw: .init(
            startX: 1.2413568, startZ: 0.6657538,
            endX: 1.2823015, endZ: 0.7066985,
            normalX: -invSqrt2, normalZ: invSqrt2
        ),
        shortJaw: .init(
            startX: 1.3007538, startZ: 0.6063568,
            endX: 1.3416985, endZ: 0.6473015,
            normalX: -invSqrt2, normalZ: invSqrt2
        ),
        longArcRailAngle: 3 * .pi / 2,   // 270° connects to top rail
        shortArcRailAngle: .pi            // 180° connects to right rail
    )
    
    func mirrorX(_ g: CornerJawGeometry) -> CornerJawGeometry {
        func mAngleStart(_ oldEnd: Float) -> Float {
            var a = (.pi - oldEnd).truncatingRemainder(dividingBy: 2 * .pi)
            if a < 0 { a += 2 * .pi }
            return a
        }
        func mAngleEnd(_ oldStart: Float) -> Float {
            var a = (.pi - oldStart).truncatingRemainder(dividingBy: 2 * .pi)
            if a < 0 { a += 2 * .pi }
            return a
        }
        return CornerJawGeometry(
            longArc: .init(
                centerX: -g.longArc.centerX, centerZ: g.longArc.centerZ,
                startAngle: mAngleStart(g.longArc.endAngle),
                endAngle: mAngleEnd(g.longArc.startAngle),
                radius: g.longArc.radius
            ),
            shortArc: .init(
                centerX: -g.shortArc.centerX, centerZ: g.shortArc.centerZ,
                startAngle: mAngleStart(g.shortArc.endAngle),
                endAngle: mAngleEnd(g.shortArc.startAngle),
                radius: g.shortArc.radius
            ),
            longJaw: .init(
                startX: -g.longJaw.startX, startZ: g.longJaw.startZ,
                endX: -g.longJaw.endX, endZ: g.longJaw.endZ,
                normalX: -g.longJaw.normalX, normalZ: g.longJaw.normalZ
            ),
            shortJaw: .init(
                startX: -g.shortJaw.startX, startZ: g.shortJaw.startZ,
                endX: -g.shortJaw.endX, endZ: g.shortJaw.endZ,
                normalX: -g.shortJaw.normalX, normalZ: g.shortJaw.normalZ
            ),
            longArcRailAngle: mAngleEnd(g.longArcRailAngle),
            shortArcRailAngle: mAngleEnd(g.shortArcRailAngle)
        )
    }
    
    func mirrorZ(_ g: CornerJawGeometry) -> CornerJawGeometry {
        func mAngleStart(_ oldEnd: Float) -> Float {
            var a = (2 * .pi - oldEnd).truncatingRemainder(dividingBy: 2 * .pi)
            if a < 0 { a += 2 * .pi }
            return a
        }
        func mAngleEnd(_ oldStart: Float) -> Float {
            var a = (2 * .pi - oldStart).truncatingRemainder(dividingBy: 2 * .pi)
            if a < 0 { a += 2 * .pi }
            return a
        }
        return CornerJawGeometry(
            longArc: .init(
                centerX: g.longArc.centerX, centerZ: -g.longArc.centerZ,
                startAngle: mAngleStart(g.longArc.endAngle),
                endAngle: mAngleEnd(g.longArc.startAngle),
                radius: g.longArc.radius
            ),
            shortArc: .init(
                centerX: g.shortArc.centerX, centerZ: -g.shortArc.centerZ,
                startAngle: mAngleStart(g.shortArc.endAngle),
                endAngle: mAngleEnd(g.shortArc.startAngle),
                radius: g.shortArc.radius
            ),
            longJaw: .init(
                startX: g.longJaw.startX, startZ: -g.longJaw.startZ,
                endX: g.longJaw.endX, endZ: -g.longJaw.endZ,
                normalX: g.longJaw.normalX, normalZ: -g.longJaw.normalZ
            ),
            shortJaw: .init(
                startX: g.shortJaw.startX, startZ: -g.shortJaw.startZ,
                endX: g.shortJaw.endX, endZ: -g.shortJaw.endZ,
                normalX: g.shortJaw.normalX, normalZ: -g.shortJaw.normalZ
            ),
            longArcRailAngle: mAngleEnd(g.longArcRailAngle),
            shortArcRailAngle: mAngleEnd(g.shortArcRailAngle)
        )
    }
    
    let lu = mirrorX(ru)
    let rd = mirrorZ(ru)
    let ld = mirrorX(rd)
    
    // Order: pocket_0(LD), pocket_1(LU), pocket_2(RD), pocket_3(RU)
    return [ld, lu, rd, ru]
}

// MARK: - TableGeometry

struct TableGeometry {
    var linearCushions: [LinearCushionSegment]
    var circularCushions: [CircularCushionSegment]
    var pockets: [Pocket]
    
    /// 构建中式八球的库边（直库 + 角袋 jaw 直线段 + 角袋 jaw 圆弧 + 中袋圆角 + 中袋喉壁）。
    /// **与袋口中心无关**——锚定于同一组内框尺寸（±innerLength/2, ±innerWidth/2）。
    ///
    /// 中袋构造（ADR-P10-09，按 CAD 双切关系精确重建）：
    ///   R30 圆角同时与库线 (z=±0.635) 和喉壁 (x=±0.043) 相切 ⇒ 弧心 (±0.073, ±0.665)，
    ///   直库段终点 x=±0.073（CAD 红色标注 1094 的端点）；喉壁 x=±0.043 与 Φ86 孔
    ///   （心 (0, ±0.688)）相切于孔心高度。库线→孔近沿的 10mm 石板带即 CAD 标注 10.0000。
    ///   （旧实现误将 10mm 读成"袋口缺口宽"，弧心压在库线上形成 10mm 窄缝 + 反向喇叭，
    ///   球心通道被接触圆封死，见 FL 记录。）
    static func chineseEightBallCushions(y: Float) -> (linear: [LinearCushionSegment], circular: [CircularCushionSegment]) {
        let railHalfLength = TablePhysics.innerLength / 2  // 1.27 m
        let railHalfWidth = TablePhysics.innerWidth / 2    // 0.635 m
        let sideFilletRadius = TablePhysics.sidePocketFilletRadius  // 0.030
        let sideThroatHalf = TablePhysics.sidePocketRadius          // 0.043（喉道半宽 = 孔半径）
        let sideMouthEdgeX = sideThroatHalf + sideFilletRadius      // 0.073（直库终点 / 弧心 x）

        // Corner jaw geometries: [LD(0), LU(1), RD(2), RU(3)]
        let corners = buildCornerJawGeometries()
        let ld = corners[0], lu = corners[1], rd = corners[2], ru = corners[3]

        func arcRailPoint(_ arc: CornerJawGeometry.Arc, at angle: Float) -> (x: Float, z: Float) {
            arc.point(at: angle)
        }
        let ruLongRailPt = arcRailPoint(ru.longArc, at: ru.longArcRailAngle)
        let luLongRailPt = arcRailPoint(lu.longArc, at: lu.longArcRailAngle)
        let rdLongRailPt = arcRailPoint(rd.longArc, at: rd.longArcRailAngle)
        let ldLongRailPt = arcRailPoint(ld.longArc, at: ld.longArcRailAngle)
        let ruShortRailPt = arcRailPoint(ru.shortArc, at: ru.shortArcRailAngle)
        let luShortRailPt = arcRailPoint(lu.shortArc, at: lu.shortArcRailAngle)
        let rdShortRailPt = arcRailPoint(rd.shortArc, at: rd.shortArcRailAngle)
        let ldShortRailPt = arcRailPoint(ld.shortArc, at: ld.shortArcRailAngle)

        // --- Main linear cushions (6 segments, endpoints from arc rail points) ---
        var linearCushions: [LinearCushionSegment] = []
        linearCushions.append(LinearCushionSegment(
            start: SCNVector3(luLongRailPt.x, y, railHalfWidth),
            end: SCNVector3(-sideMouthEdgeX, y, railHalfWidth),
            normal: SCNVector3(0, 0, -1)))
        linearCushions.append(LinearCushionSegment(
            start: SCNVector3(sideMouthEdgeX, y, railHalfWidth),
            end: SCNVector3(ruLongRailPt.x, y, railHalfWidth),
            normal: SCNVector3(0, 0, -1)))
        linearCushions.append(LinearCushionSegment(
            start: SCNVector3(ldLongRailPt.x, y, -railHalfWidth),
            end: SCNVector3(-sideMouthEdgeX, y, -railHalfWidth),
            normal: SCNVector3(0, 0, 1)))
        linearCushions.append(LinearCushionSegment(
            start: SCNVector3(sideMouthEdgeX, y, -railHalfWidth),
            end: SCNVector3(rdLongRailPt.x, y, -railHalfWidth),
            normal: SCNVector3(0, 0, 1)))
        linearCushions.append(LinearCushionSegment(
            start: SCNVector3(-railHalfLength, y, ldShortRailPt.z),
            end: SCNVector3(-railHalfLength, y, luShortRailPt.z),
            normal: SCNVector3(1, 0, 0)))
        linearCushions.append(LinearCushionSegment(
            start: SCNVector3(railHalfLength, y, rdShortRailPt.z),
            end: SCNVector3(railHalfLength, y, ruShortRailPt.z),
            normal: SCNVector3(-1, 0, 0)))

        // --- Jaw line segments (8 total: 2 per corner) ---
        for corner in corners {
            linearCushions.append(LinearCushionSegment(
                start: SCNVector3(corner.longJaw.startX, y, corner.longJaw.startZ),
                end: SCNVector3(corner.longJaw.endX, y, corner.longJaw.endZ),
                normal: SCNVector3(corner.longJaw.normalX, 0, corner.longJaw.normalZ)))
            linearCushions.append(LinearCushionSegment(
                start: SCNVector3(corner.shortJaw.startX, y, corner.shortJaw.startZ),
                end: SCNVector3(corner.shortJaw.endX, y, corner.shortJaw.endZ),
                normal: SCNVector3(corner.shortJaw.normalX, 0, corner.shortJaw.normalZ)))
        }

        // --- Corner jaw arcs (8 arcs: 2 per corner) ---
        // 鼻尖圆角用袋口鼻头恢复系数（低速沿库球贴向孔圈而非弹回，见 pocketNoseRestitution）。
        var circularCushions: [CircularCushionSegment] = []
        for corner in corners {
            circularCushions.append(CircularCushionSegment(
                center: SCNVector3(corner.longArc.centerX, y, corner.longArc.centerZ),
                radius: corner.longArc.radius,
                startAngle: corner.longArc.startAngle, endAngle: corner.longArc.endAngle,
                restitution: TablePhysics.pocketNoseRestitution))
            circularCushions.append(CircularCushionSegment(
                center: SCNVector3(corner.shortArc.centerX, y, corner.shortArc.centerZ),
                radius: corner.shortArc.radius,
                startAngle: corner.shortArc.startAngle, endAngle: corner.shortArc.endAngle,
                restitution: TablePhysics.pocketNoseRestitution))
        }

        // --- Side pocket fillet arcs (4 arcs: 2 per side pocket, bottom z<0 then top z>0) ---
        // CAD 双切构造：弧心在库线外侧 filletRadius 处 (±0.073, ±0.665)，
        // 一端切库线 (±0.073, ±0.635)、另一端切喉壁 (±0.043, ±0.665)。
        for sign in [Float(-1), Float(1)] {
            let arcZ = sign * (railHalfWidth + sideFilletRadius)   // ±0.665
            let isTop = sign > 0
            // 左弧：库线切点在弧的正下(上)方，喉壁切点在弧的 +x 方向。
            circularCushions.append(CircularCushionSegment(
                center: SCNVector3(-sideMouthEdgeX, y, arcZ),
                radius: sideFilletRadius,
                startAngle: isTop ? 3 * .pi / 2 : 0,
                endAngle: isTop ? 2 * .pi : .pi / 2))
            // 右弧：喉壁切点在弧的 -x 方向。
            circularCushions.append(CircularCushionSegment(
                center: SCNVector3(sideMouthEdgeX, y, arcZ),
                radius: sideFilletRadius,
                startAngle: isTop ? .pi : .pi / 2,
                endAngle: isTop ? 3 * .pi / 2 : .pi))
        }

        // --- Side pocket throat walls (4 walls: 2 per side pocket) ---
        // CAD：喉壁 x=±0.043 从圆角切点 (z=±0.665) 通到孔心高度 (z=±0.688，与 Φ86 孔相切)。
        // 恢复系数用袋腔衬里值（正常球在触壁前已被孔圈判据收袋，此壁多为 rattle/兜底路径）。
        let throatZNear = railHalfWidth + sideFilletRadius                     // 0.665
        let throatZFar = TablePhysics.sidePocketThroatJoinZ                  // 0.688
        for sign in [Float(-1), Float(1)] {
            linearCushions.append(LinearCushionSegment(
                start: SCNVector3(-sideThroatHalf, y, sign * throatZNear),
                end: SCNVector3(-sideThroatHalf, y, sign * throatZFar),
                normal: SCNVector3(1, 0, 0),
                restitution: TablePhysics.pocketThroatRestitution))
            linearCushions.append(LinearCushionSegment(
                start: SCNVector3(sideThroatHalf, y, sign * throatZNear),
                end: SCNVector3(sideThroatHalf, y, sign * throatZFar),
                normal: SCNVector3(-1, 0, 0),
                restitution: TablePhysics.pocketThroatRestitution))
        }

        return (linearCushions, circularCushions)
    }

    static func chineseEightBall() -> TableGeometry {
        let y = TablePhysics.height
        let cornerPocketCenterOffsetX = TablePhysics.cornerPocketCenterOffsetX
        let cornerPocketCenterOffsetZ = TablePhysics.cornerPocketCenterOffsetZ
        let sidePocketCenterOffsetZ = TablePhysics.sidePocketCenterOffsetZ
        let cornerPocketRadius = TablePhysics.cornerPocketRadius
        let sidePocketRadius = TablePhysics.sidePocketRadius

        // CAD 袋口中心（基于 01.billiard_app 的 CAD 数据，与 USDZ 模型相差 ~17mm）。
        let pockets: [Pocket] = [
            Pocket(id: "pocket_0", center: SCNVector3(-cornerPocketCenterOffsetX, y, -cornerPocketCenterOffsetZ), radius: cornerPocketRadius, isCorner: true),
            Pocket(id: "pocket_1", center: SCNVector3(-cornerPocketCenterOffsetX, y, cornerPocketCenterOffsetZ), radius: cornerPocketRadius, isCorner: true),
            Pocket(id: "pocket_2", center: SCNVector3(cornerPocketCenterOffsetX, y, -cornerPocketCenterOffsetZ), radius: cornerPocketRadius, isCorner: true),
            Pocket(id: "pocket_3", center: SCNVector3(cornerPocketCenterOffsetX, y, cornerPocketCenterOffsetZ), radius: cornerPocketRadius, isCorner: true),
            Pocket(id: "pocket_4", center: SCNVector3(0, y, -sidePocketCenterOffsetZ), radius: sidePocketRadius, isCorner: false),
            Pocket(id: "pocket_5", center: SCNVector3(0, y, sidePocketCenterOffsetZ), radius: sidePocketRadius, isCorner: false)
        ]

        let cushions = chineseEightBallCushions(y: y)
        let geometry = TableGeometry(linearCushions: cushions.linear, circularCushions: cushions.circular, pockets: pockets)
        geometry.validateGeometryConsistency(corners: buildCornerJawGeometries(), y: y)
        return geometry
    }
    
    // MARK: - Geometric Consistency Validation
    
    private func validateGeometryConsistency(corners: [CornerJawGeometry], y: Float) {
        let eps: Float = 0.002  // 2 mm tolerance
        let R = TablePhysics.cornerPocketFilletRadius
        
        for (i, corner) in corners.enumerated() {
            // Arc endpoints should be at distance R from arc center
            for arc in [corner.longArc, corner.shortArc] {
                let startPt = arc.point(at: arc.startAngle)
                let endPt = arc.point(at: arc.endAngle)
                let startDist = sqrtf(powf(startPt.x - arc.centerX, 2) + powf(startPt.z - arc.centerZ, 2))
                let endDist = sqrtf(powf(endPt.x - arc.centerX, 2) + powf(endPt.z - arc.centerZ, 2))
                assert(abs(startDist - R) < eps,
                       "[TableGeometry] Corner \(i) arc startPoint distance from center = \(startDist), expected \(R)")
                assert(abs(endDist - R) < eps,
                       "[TableGeometry] Corner \(i) arc endPoint distance from center = \(endDist), expected \(R)")
            }
            
            // Long arc jaw-side endpoint should match long jaw line start
            let longArcJawAngle = (corner.longArc.startAngle == corner.longArcRailAngle)
                ? corner.longArc.endAngle : corner.longArc.startAngle
            let longArcJawPt = corner.longArc.point(at: longArcJawAngle)
            assert(abs(longArcJawPt.x - corner.longJaw.startX) < eps &&
                   abs(longArcJawPt.z - corner.longJaw.startZ) < eps,
                   "[TableGeometry] Corner \(i) long arc jaw endpoint (\(longArcJawPt)) != jaw start (\(corner.longJaw.startX), \(corner.longJaw.startZ))")
            
            // Short arc jaw-side endpoint should match short jaw line start
            let shortArcJawPt: (x: Float, z: Float)
            if abs(corner.shortArc.endAngle - corner.shortArcRailAngle) < 0.01 {
                shortArcJawPt = corner.shortArc.point(at: corner.shortArc.startAngle)
            } else {
                shortArcJawPt = corner.shortArc.point(at: corner.shortArc.endAngle)
            }
            assert(abs(shortArcJawPt.x - corner.shortJaw.startX) < eps &&
                   abs(shortArcJawPt.z - corner.shortJaw.startZ) < eps,
                   "[TableGeometry] Corner \(i) short arc jaw endpoint (\(shortArcJawPt)) != jaw start (\(corner.shortJaw.startX), \(corner.shortJaw.startZ))")
            
            // Jaw line length should be reasonable (30-60 mm)
            let longJawLen = sqrtf(powf(corner.longJaw.endX - corner.longJaw.startX, 2) +
                                   powf(corner.longJaw.endZ - corner.longJaw.startZ, 2))
            let shortJawLen = sqrtf(powf(corner.shortJaw.endX - corner.shortJaw.startX, 2) +
                                    powf(corner.shortJaw.endZ - corner.shortJaw.startZ, 2))
            assert(longJawLen > 0.03 && longJawLen < 0.08,
                   "[TableGeometry] Corner \(i) long jaw length \(longJawLen) out of expected range")
            assert(shortJawLen > 0.03 && shortJawLen < 0.08,
                   "[TableGeometry] Corner \(i) short jaw length \(shortJawLen) out of expected range")
            
            // Jaw line normal should be unit length
            let longNormLen = sqrtf(corner.longJaw.normalX * corner.longJaw.normalX +
                                    corner.longJaw.normalZ * corner.longJaw.normalZ)
            let shortNormLen = sqrtf(corner.shortJaw.normalX * corner.shortJaw.normalX +
                                     corner.shortJaw.normalZ * corner.shortJaw.normalZ)
            assert(abs(longNormLen - 1.0) < 0.01,
                   "[TableGeometry] Corner \(i) long jaw normal not unit: \(longNormLen)")
            assert(abs(shortNormLen - 1.0) < 0.01,
                   "[TableGeometry] Corner \(i) short jaw normal not unit: \(shortNormLen)")
            
            // Jaw line normal should point toward table center (dot with center direction > 0)
            let longMidX = (corner.longJaw.startX + corner.longJaw.endX) / 2
            let longMidZ = (corner.longJaw.startZ + corner.longJaw.endZ) / 2
            let longToCenterDot = (-longMidX) * corner.longJaw.normalX + (-longMidZ) * corner.longJaw.normalZ
            assert(longToCenterDot > 0,
                   "[TableGeometry] Corner \(i) long jaw normal points away from table center")
            
            let shortMidX = (corner.shortJaw.startX + corner.shortJaw.endX) / 2
            let shortMidZ = (corner.shortJaw.startZ + corner.shortJaw.endZ) / 2
            let shortToCenterDot = (-shortMidX) * corner.shortJaw.normalX + (-shortMidZ) * corner.shortJaw.normalZ
            assert(shortToCenterDot > 0,
                   "[TableGeometry] Corner \(i) short jaw normal points away from table center")
        }
    }
}

/// Finite surface primitive for local pocket contact. Coordinates are world meters.
/// Feature roots are solved along a constant-acceleration segment, independent of render FPS.
struct PocketContactTriangle {
    typealias V = SIMD3<Double>
    let a: V
    let b: V
    let c: V

    private func dot(_ x: V, _ y: V) -> Double { x.x*y.x+x.y*y.y+x.z*y.z }
    private func cross(_ x: V, _ y: V) -> V { V(x.y*y.z-x.z*y.y, x.z*y.x-x.x*y.z, x.x*y.y-x.y*y.x) }
    private var edges: [(V,V)] { [(a,b),(b,c),(c,a)] }

    /// A face witness, distinguished from an edge that merely rounds to the
    /// same sphere distance. Needed when selecting a support manifold.
    func projectedInteriorPoint(to p: V) -> V? {
        let n=cross(b-a,c-a),n2=dot(n,n)
        if n2>1e-24 {
            let projected=p-n*(dot(p-a,n)/n2)
            if dot(cross(b-a,projected-a),n) >= -1e-14*n2 &&
               dot(cross(c-b,projected-b),n) >= -1e-14*n2 &&
               dot(cross(a-c,projected-c),n) >= -1e-14*n2 { return projected }
        }
        return nil
    }

    func closestPoint(to p: V) -> V {
        if let projected=projectedInteriorPoint(to:p) { return projected }
        func edge(_ x:V,_ y:V)->V {
            let e=y-x,length2=dot(e,e)
            let t=length2>1e-24 ? max(0,min(1,dot(p-x,e)/length2)) : 0
            return x+e*t
        }
        var best=edge(a,b)
        let second=edge(b,c)
        if dot(p-second,p-second)<dot(p-best,p-best) { best=second }
        let third=edge(c,a)
        if dot(p-third,p-third)<dot(p-best,p-best) { best=third }
        return best
    }

    struct Hit { let time: Double; let point: V; let normal: V }

    /// Earliest approaching sphere contact. Persistent resting support is handled by the solver.
    func firstContact(position p: V, velocity v: V, acceleration acc: V,
                      radius: Double, horizon: Double, useDistanceBound: Bool = true) -> Hit? {
        guard radius > 0, radius.isFinite, horizon > 0, horizon.isFinite else { return nil }
        let half = acc*0.5
        let coordinateScale=max(1,sqrt(dot(p,p)),sqrt(dot(a,a)),sqrt(dot(b,b)),sqrt(dot(c,c)),radius)
        if useDistanceBound {
            // Distance to a fixed finite triangle is 1-Lipschitz. This displacement
            // bound includes acceleration and reversal throughout the interval.
            let delta=p-closestPoint(to:p),distance=sqrt(dot(delta,delta))
            let reach=sqrt(dot(v,v))*horizon+sqrt(dot(half,half))*horizon*horizon
            let rounding=64*Double.ulpOfOne*max(coordinateScale,distance,reach)
            if distance>radius+reach+rounding { return nil }
        }
        var candidates: [Double] = []
        func roots(_ d: V, _ speed: V, _ h: V) -> [Double] {
            // Orthogonal projection cannot increase displacement. This bound
            // covers the entire interval, including acceleration/reversal.
            let distance=sqrt(dot(d,d))
            let reach=sqrt(dot(speed,speed))*horizon+sqrt(dot(h,h))*horizon*horizon
            let worldScale=max(coordinateScale,distance,reach)
            let rounding=64*Double.ulpOfOne*worldScale
            if distance>radius+reach+rounding { return [] }
            return QuarticSolver.solveQuartic(a: dot(h,h), b: 2*dot(speed,h),
                c: dot(speed,speed)+2*dot(d,h), d: 2*dot(d,speed), e: dot(d,d)-radius*radius)
        }
        let raw = cross(b-a,c-a), n2 = dot(raw,raw)
        if n2 > 1e-24 {
            let n = raw/sqrt(n2)
            for side in [-1.0,1.0] {
                candidates += QuarticSolver.solveQuadraticPublic(a: dot(half,n), b: dot(v,n),
                                                                 c: dot(p-a,n)-side*radius)
            }
        }
        for vertex in [a,b,c] { candidates += roots(p-vertex,v,half) }
        for (x,y) in edges {
            let e = y-x, e2 = dot(e,e)
            guard e2 > 1e-24 else { continue }
            func perpendicular(_ value: V) -> V { value-e*(dot(value,e)/e2) }
            candidates += roots(perpendicular(p-x),perpendicular(v),perpendicular(half))
        }
        var earliest:Hit?
        for seed in candidates.filter({ $0.isFinite && $0 >= 0 && $0 <= horizon }) {
            var time=seed
            // Roots of infinite planes/lines are only seeds. Polish against the
            // finite triangle distance before accepting a contact, otherwise a
            // nearby edge can become a false simultaneous impact at a face hit.
            for _ in 0..<12 {
                let center=p+v*time+half*(time*time)
                let delta=center-closestPoint(to:center)
                let residual=dot(delta,delta)-radius*radius
                let derivative=2*dot(delta,v+acc*time)
                guard derivative != 0 else { break }
                let next=time-residual/derivative
                guard next.isFinite,next>=0,next<=horizon else { break }
                if next==time { break }
                time=next
            }
            let center = p+v*time+half*(time*time)
            let point = closestPoint(to: center), delta = center-point
            let distance = sqrt(dot(delta,delta))
            // Reject roots belonging to infinite edge/plane extensions.
            let roundoff=64*Double.ulpOfOne*max(1,sqrt(dot(center,center)),radius)
            guard distance > 0, abs(distance-radius) <= roundoff else { continue }
            let normal = delta/distance
            guard dot(v+acc*time,normal) < -1e-9 else { continue }
            if earliest == nil || time<earliest!.time { earliest=Hit(time:time,point:point,normal:normal) }
        }
        return earliest
    }
}

/// Immutable spatial index. Queries retain original triangle order so the index
/// changes candidate cost, never the physical contact ordering.
/// Horizontal ownership domain, not a potting/capture criterion. Geometry
/// supplied to this domain must cover its bounds expanded by the ball radius.
struct PocketLocalRegion {
    typealias V=SIMD3<Double>
    let center:V
    let halfExtent:Double
    enum Direction:Equatable { case entering, leaving }

    func contains(_ p:V)->Bool {
        abs(p.x-center.x)<=halfExtent && abs(p.z-center.z)<=halfExtent
    }

    /// First true crossing of the finite rectangle under constant acceleration.
    /// A tangent touch does not switch ownership. Heights remain unrestricted.
    func firstCrossing(position:V,velocity:V,acceleration:V,horizon:Double,direction:Direction)->Double? {
        guard halfExtent>0,halfExtent.isFinite,horizon>0,horizon.isFinite,
              [position,velocity,acceleration,center].allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite}) else { return nil }
        var times=[0.0,horizon]
        for axis in [0,2] {
            for side in [-1.0,1.0] {
                let a=0.5*acceleration[axis],b=velocity[axis],c=position[axis]-center[axis]-side*halfExtent
                if a == 0 {
                    if b != 0 { times.append(-c/b) }
                } else {
                    let disc=b*b-4*a*c
                    if disc>=0 {
                        let root=sqrt(disc),q = -0.5*(b+(b>=0 ? root : -root))
                        if q == 0 { times.append(-b/(2*a)) }
                        else { times.append(q/a);times.append(c/q) }
                    }
                }
            }
        }
        times=Array(Set(times.filter{$0.isFinite})).sorted()
        func inside(_ time:Double)->Bool {
            contains(position+velocity*time+acceleration*(0.5*time*time))
        }
        // Between consecutive roots, rectangle membership is constant.
        // Compare those open intervals instead of adding a time epsilon that
        // could skip a short visit or manufacture a crossing at a tangent.
        for i in times.indices {
            let t=times[i]
            guard t>=0 && t<=horizon else { continue }
            let before=i>0 ? inside(times[i-1]+(t-times[i-1])/2) : inside(t-max(1,abs(t)))
            let after=i+1<times.count ? inside(t+(times[i+1]-t)/2) : inside(t+max(1,abs(t)))
            if direction == .entering && !before && after { return t }
            if direction == .leaving && before && !after { return t }
        }
        return nil
    }
}

struct PocketContactIndex {
    typealias V=SIMD3<Double>
    struct Bounds {
        let low: V; let high: V
        func intersects(_ other:Bounds)->Bool {
            (0..<3).allSatisfy { high[$0]>=other.low[$0] && low[$0]<=other.high[$0] }
        }
    }
    private indirect enum Node {
        case leaf(Bounds,[Int])
        case branch(Bounds,Node,Node)
        var bounds:Bounds { switch self { case .leaf(let b,_),.branch(let b,_,_): return b } }
    }
    private let boxes:[Bounds]
    private let root:Node?
    init(triangles:[PocketContactTriangle]) {
        let boxes=triangles.map { t in
            Bounds(low:V(min(t.a.x,t.b.x,t.c.x),min(t.a.y,t.b.y,t.c.y),min(t.a.z,t.b.z,t.c.z)),
                   high:V(max(t.a.x,t.b.x,t.c.x),max(t.a.y,t.b.y,t.c.y),max(t.a.z,t.b.z,t.c.z)))
        }
        func build(_ ids:[Int])->Node {
            var low=V(repeating:.infinity),high=V(repeating:-.infinity)
            for i in ids { for axis in 0..<3 { low[axis]=min(low[axis],boxes[i].low[axis]);high[axis]=max(high[axis],boxes[i].high[axis]) } }
            let bounds=Bounds(low:low,high:high)
            guard ids.count>8 else { return .leaf(bounds,ids) }
            let axis=(0..<3).max { high[$0]-low[$0]<high[$1]-low[$1] }!
            let sorted=ids.sorted {
                let a=boxes[$0].low[axis]+boxes[$0].high[axis],b=boxes[$1].low[axis]+boxes[$1].high[axis]
                return a==b ? $0<$1 : a<b
            }
            let middle=sorted.count/2
            return .branch(bounds,build(Array(sorted[..<middle])),build(Array(sorted[middle...])))
        }
        self.boxes=boxes;root=boxes.isEmpty ? nil : build(Array(boxes.indices))
    }
    func query(low:V,high:V)->[Int] {
        let query=Bounds(low:low,high:high)
        var result:[Int]=[]
        func visit(_ node:Node) {
            guard node.bounds.intersects(query) else { return }
            switch node {
            case .leaf(_,let ids): result.append(contentsOf:ids.filter { boxes[$0].intersects(query) })
            case .branch(_,let left,let right):visit(left);visit(right)
            }
        }
        if let root { visit(root) }
        return result.sorted()
    }
}

/// Contact response for a homogeneous sphere against a stationary surface.
/// Impulses/forces are per unit mass; I/m = 2 R²/5. Geometry owns contact activation.
enum PocketContactResponse {
    typealias V = SIMD3<Double>
    struct Motion { let velocity: V; let angularVelocity: V }
    struct Acceleration { let linear: V; let angular: V }
    struct ImpactConstraint { let normal: V; let restitution: Double; let friction: Double }
    enum SolveFailure: Error { case jointImpactIterationLimit }
    private static func dot(_ a: V,_ b: V) -> Double { a.x*b.x+a.y*b.y+a.z*b.z }
    private static func cross(_ a: V,_ b: V) -> V { V(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x) }
    private static func limited(_ x: V, to limit: Double) -> V {
        let length = sqrt(dot(x,x)); return length > limit && length > 0 ? x*(limit/length) : x
    }

    /// Surface moments per unit mass for a solid sphere. Rolling mu is defined
    /// by no-slip linear deceleration mu*N; normal spin follows the planar law.
    /// The caller supplies a unit normal and a positive integration duration.
    static func surfaceResistance(omega:V,normal:V,pressure:Double,radius:Double,
                                  duration:Double,rollingFriction:Double,spinFriction:Double)->V {
        guard pressure>0 else { return .zero }
        let spin=dot(omega,normal),tangent=omega-normal*spin,speed=sqrt(dot(tangent,tangent))
        var result=V.zero
        if rollingFriction>0 && speed>0 {
            result -= tangent*(min(3.5*rollingFriction*pressure/radius,3.5*speed/duration)/speed)
        }
        if spinFriction>0 && spin != 0 {
            let magnitude=min(2.5*spinFriction*pressure/radius,abs(spin)/duration)
            result += normal*(spin>0 ? -magnitude : magnitude)
        }
        return result
    }

    /// Simultaneous impulses use a common pre-impact state. Relaxed Jacobi updates
    /// preserve symmetric contacts rather than privileging the first mesh face.
    static func simultaneousImpact(_ initial: Motion, constraints: [ImpactConstraint], radius: Double) throws -> Motion {
        guard !constraints.isEmpty else { return initial }
        let targets=constraints.map { max(0,-dot(initial.velocity,$0.normal))*$0.restitution }
        var normal=Array(repeating:0.0,count:constraints.count)
        var tangent=Array(repeating:V.zero,count:constraints.count)
        var motion=initial
        var lastResidual=0.0,lastMotionResidual=0.0
        let relaxation=1/Double(constraints.count)
        for _ in 0..<4096 {
            var nextNormal=normal,nextTangent=tangent,residual=0.0
            for (i,c) in constraints.enumerated() {
                let n=c.normal,arm = -n*radius
                let desiredNormal=max(0,normal[i]+targets[i]-dot(motion.velocity,n))
                let velocity=motion.velocity+cross(motion.angularVelocity,arm)
                let vt=velocity-n*dot(velocity,n)
                let desiredTangent=limited(tangent[i]-vt/3.5,to:c.friction*desiredNormal)
                nextNormal[i]+=relaxation*(desiredNormal-normal[i])
                nextTangent[i]+=relaxation*(desiredTangent-tangent[i])
                residual=max(residual,abs(desiredNormal-normal[i]),sqrt(dot(desiredTangent-tangent[i],desiredTangent-tangent[i])))
            }
            normal=nextNormal;tangent=nextTangent
            var v=initial.velocity,w=initial.angularVelocity
            for (i,c) in constraints.enumerated() {
                v+=c.normal*normal[i]+tangent[i]
                w+=cross(-c.normal*radius,tangent[i])/(0.4*radius*radius)
            }
            lastMotionResidual=max(sqrt(dot(v-motion.velocity,v-motion.velocity)),radius*sqrt(dot(w-motion.angularVelocity,w-motion.angularVelocity)))
            lastResidual=residual
            motion=Motion(velocity:v,angularVelocity:w)
            if residual<1e-11 { return motion }
        }
        print("[W05 joint residual] force=\(lastResidual) motion=\(lastMotionResidual) initial=\(initial) result=\(motion) constraints=\(constraints)")
        throw SolveFailure.jointImpactIterationLimit
    }

    static func impact(_ motion: Motion, normal: V, radius: Double,
                       restitution: Double, friction: Double) -> Motion {
        precondition(radius > 0 && radius.isFinite && restitution >= 0 && restitution <= 1 && friction >= 0 && friction.isFinite)
        precondition(abs(dot(normal,normal)-1) < 1e-8)
        let vn = dot(motion.velocity,normal)
        guard vn < 0 else { return motion } // A separating contact must not pull the ball back.
        let normalImpulse = -(1+restitution)*vn
        let arm = -normal*radius
        let contactVelocity = motion.velocity+cross(motion.angularVelocity,arm)
        let tangent = contactVelocity-normal*dot(contactVelocity,normal)
        let tangentImpulse = limited(-tangent/3.5,to: friction*normalImpulse)
        return Motion(velocity: motion.velocity+normal*normalImpulse+tangentImpulse,
                      angularVelocity: motion.angularVelocity+cross(arm,tangentImpulse)/(0.4*radius*radius))
    }

    /// Soft-liner dissipation applied after the rigid impulse of an approaching
    /// contact. A hanging leather apron grips the ball: unlike Coulomb friction,
    /// which can only convert about 2/7 of the slip into spin, the liner removes
    /// tangential centre velocity and spin outright. `retention` is the kept
    /// fraction; 1 leaves the rigid result untouched. The normal component is
    /// left to the restitution already applied.
    static func linerSink(_ motion: Motion, normal: V, retention: Double) -> Motion {
        precondition(retention.isFinite && retention >= 0 && retention <= 1)
        precondition(abs(dot(normal,normal)-1) < 1e-8)
        guard retention < 1 else { return motion }
        let vn = dot(motion.velocity,normal)
        let tangential = motion.velocity-normal*vn
        return Motion(velocity: normal*vn+tangential*retention,
                      angularVelocity: motion.angularVelocity*retention)
    }

    /// A sustained contact on a locally planar patch. No restitution is applied.
    /// The caller must release this constraint at the finite edge / loss of support.
    static func planarSupport(_ motion: Motion, gravity: V, normal: V,
                              radius: Double, friction: Double) -> Acceleration {
        precondition(radius > 0 && radius.isFinite && friction >= 0 && friction.isFinite)
        precondition(abs(dot(normal,normal)-1) < 1e-8)
        let pressure = max(0,-dot(gravity,normal))
        guard pressure > 0 else { return Acceleration(linear: gravity,angular: .zero) }
        let arm = -normal*radius
        let contactVelocity = motion.velocity+cross(motion.angularVelocity,arm)
        let slip = contactVelocity-normal*dot(contactVelocity,normal)
        let slipSpeed = sqrt(dot(slip,slip))
        let tangentialGravity = gravity+normal*pressure
        // Static friction enforces no-slip acceleration; kinetic friction opposes slip.
        let force = slipSpeed > 1e-9 ? -slip*(friction*pressure/slipSpeed)
                                    : limited(-tangentialGravity/3.5,to: friction*pressure)
        return Acceleration(linear: tangentialGravity+force,
                            angular: cross(arm,force)/(0.4*radius*radius))
    }
}

/// Numeric envelope of the measured net strands. The cap is an explicit bag
/// closure approximation, not an imported solid face or a capture threshold.
struct PocketBagEnvelope {
    typealias V=SIMD3<Double>
    typealias P=SIMD2<Double>
    struct Configuration {
        var topDepth:Double=0.04
        var layerHeight:Double=0.00125
        var radialSamples:Int=128
        var maximumAngularGap:Double = .pi/6
    }
    enum Failure:Error { case invalidGeometry(String) }
    let pocketID:String
    let rings:[[V]]
    let triangles:[PocketContactTriangle]
    let bottom:Double
    let top:Double
    let sourceTriangleCount:Int
    let selectedTriangleCount:Int

    static func build(pocketID:String,strands:[PocketContactTriangle],surfaceY:Double,
                      radius:Double=Double(BallPhysics.radius),
                      configuration c:Configuration = .init()) throws -> PocketBagEnvelope {
        func fail(_ reason:String)->Failure { .invalidGeometry(reason) }
        guard !pocketID.isEmpty,surfaceY.isFinite,radius>0,radius.isFinite,c.topDepth>0,c.topDepth.isFinite,
              c.layerHeight>0,c.layerHeight.isFinite,(8...512).contains(c.radialSamples),
              c.maximumAngularGap>0,c.maximumAngularGap<=Double.pi,c.maximumAngularGap.isFinite,
              !strands.isEmpty else { throw fail("invalid input") }
        let faces=strands.map{[$0.a,$0.b,$0.c]}
        guard faces.joined().allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite}),
              let bottom=faces.joined().map(\.y).min() else { throw fail("invalid strands") }
        // White also contains shallow, disconnected table fittings. Retain
        // complete strand components that reach the measured lower bag band;
        // do not clip their upper geometry or move the envelope's top edge.
        var parent=Array(faces.indices),vertexOwner:[V:Int]=[:]
        func root(_ index:Int)->Int {
            var i=index
            while parent[i] != i { parent[i]=parent[parent[i]];i=parent[i] }
            return i
        }
        for (i,face) in faces.enumerated() { for vertex in face {
            if let previous=vertexOwner[vertex] { parent[root(i)]=root(previous) }
            else { vertexOwner[vertex]=i }
        } }
        var selectedRoots=Set<Int>()
        for (i,face) in faces.enumerated() where face.contains(where:{$0.y<=bottom+radius}) {
            selectedRoots.insert(root(i))
        }
        let selected=faces.indices.filter{selectedRoots.contains(root($0))}
        let bagFaces=selected.map{faces[$0]}
        let top=surfaceY-c.topDepth,levels=ceil((top-bottom)/c.layerHeight)
        guard levels>=2,levels<=4096 else { throw fail("invalid depth range") }
        func cross(_ a:P,_ b:P)->Double { a.x*b.y-a.y*b.x }
        func hull(_ points:[P])->[P] {
            let sorted=points.sorted{$0.x == $1.x ? $0.y<$1.y : $0.x<$1.x}
            var unique:[P]=[]
            for p in sorted where unique.last != p { unique.append(p) }
            func chain(_ values:[P])->[P] {
                var result:[P]=[]
                for p in values {
                    while result.count>=2 && cross(result.last!-result[result.count-2],p-result.last!)<=0 { result.removeLast() }
                    result.append(p)
                }
                return result
            }
            guard unique.count>=3 else { return [] }
            return Array(chain(unique).dropLast())+Array(chain(Array(unique.reversed())).dropLast())
        }
        var rings:[[V]]=[]
        for j in 0..<Int(levels) {
            let y=top-Double(j)*c.layerHeight
            var points:[P]=[]
            for face in bagFaces { for k in 0..<3 {
                let a=face[k],b=face[(k+1)%3]
                if (a.y<=y && b.y>y) || (b.y<=y && a.y>y) {
                    let t=(y-a.y)/(b.y-a.y)
                    points.append(P(a.x+t*(b.x-a.x),a.z+t*(b.z-a.z)))
                }
            } }
            let boundary=hull(points)
            guard boundary.count>=3 else { break }
            // Polygon area centroid is invariant to extra collinear vertices
            // introduced by triangulation; averaging vertices is not.
            let origin=boundary[0]
            var twiceArea=0.0,weighted=P.zero
            for i in boundary.indices {
                let a=boundary[i]-origin,b=boundary[(i+1)%boundary.count]-origin,w=cross(a,b)
                twiceArea+=w;weighted+=(a+b)*w
            }
            guard twiceArea>0,twiceArea.isFinite else { throw fail("degenerate section") }
            let center=origin+weighted/(3*twiceArea)
            let angles=points.map{atan2($0.y-center.y,$0.x-center.x)}.sorted()
            let gaps=angles.indices.map { i in
                i+1<angles.count ? angles[i+1]-angles[i] : angles[0]+2*Double.pi-angles[i]
            }
            guard (gaps.max() ?? .infinity)<=c.maximumAngularGap else { break }
            var ring:[V]=[]
            for k in 0..<c.radialSamples {
                let angle=2*Double.pi*Double(k)/Double(c.radialSamples),direction=P(cos(angle),sin(angle))
                var nearest=Double.infinity
                for i in boundary.indices {
                    let a=boundary[i],edge=boundary[(i+1)%boundary.count]-a,offset=a-center
                    let denominator=cross(direction,edge)
                    if abs(denominator)<1e-14 { continue }
                    let t=cross(offset,edge)/denominator,u=cross(offset,direction)/denominator
                    if t>=0 && u>=(-1e-10) && u<=1+1e-10 { nearest=min(nearest,t) }
                }
                guard nearest.isFinite,nearest>0 else { throw fail("open radial section") }
                let p=center+direction*nearest
                ring.append(V(p.x,y,p.y))
            }
            rings.append(ring)
        }
        guard rings.count>=2,let last=rings.last,last[0].y>bottom else { throw fail("incomplete net envelope") }
        rings.append(last.map{V($0.x,bottom,$0.z)})
        var triangles:[PocketContactTriangle]=[]
        for j in 0..<(rings.count-1) { for i in 0..<c.radialSamples {
            let k=(i+1)%c.radialSamples,a=rings[j],b=rings[j+1]
            triangles.append(.init(a:a[i],b:b[i],c:b[k]))
            triangles.append(.init(a:a[i],b:b[k],c:a[k]))
        } }
        let floor=rings.last!,center=floor.reduce(V.zero,+)/Double(floor.count)
        for i in floor.indices { triangles.append(.init(a:center,b:floor[i],c:floor[(i+1)%floor.count])) }
        return .init(pocketID:pocketID,rings:rings,triangles:triangles,bottom:bottom,top:top,
                     sourceTriangleCount:faces.count,selectedTriangleCount:bagFaces.count)
    }
}

/// Absorbing soft-bag boundary, below the complete hard pocket geometry.
/// Hard lip/jaw motion remains physical; collection does not simulate net piles.
struct PocketCaptureBoundary {
    typealias V=SIMD3<Double>
    typealias P=SIMD2<Double>
    let pocketID:String
    let centerPlaneY:Double
    let outline:[P]
    let radius:Double
    let restingCenterY:Double

    var geometryVersion:String {
        var hash:UInt64=14695981039346656037
        for value in [centerPlaneY,radius,restingCenterY]+outline.flatMap({[$0.x,$0.y]}) {
            for shift in stride(from:0,to:64,by:8) {
                hash=(hash ^ ((value.bitPattern >> shift) & 255)) &* 1099511628211
            }
        }
        return "soft-bag-v2:"+String(hash,radix:16)
    }

    init(bag:PocketBagEnvelope,hardSurfaces:[PocketContactTriangle],radius:Double) throws {
        let vertices=hardSurfaces.flatMap{[$0.a,$0.b,$0.c]}
        guard radius>0,radius.isFinite,!vertices.isEmpty,
              vertices.allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite}),
              let hardBottom=vertices.map(\.y).min() else {
            throw PocketBagEnvelope.Failure.invalidGeometry("missing capture geometry")
        }
        // The entire sphere must be below hard cloth/leather and the bag mouth.
        let y=min(hardBottom,bag.top)-radius
        guard y>bag.bottom+radius,let upper=bag.rings.indices.dropLast().first(where:{
            bag.rings[$0][0].y>=y && bag.rings[$0+1][0].y<=y
        }) else { throw PocketBagEnvelope.Failure.invalidGeometry("no collection depth") }
        let a=bag.rings[upper],b=bag.rings[upper+1]
        guard a.count>=3,a.count==b.count,a[0].y>b[0].y else {
            throw PocketBagEnvelope.Failure.invalidGeometry("invalid collection section")
        }
        let t=(a[0].y-y)/(a[0].y-b[0].y)
        self.outline=zip(a,b).map { let p=$0+($1-$0)*t;return P(p.x,p.z) }
        self.centerPlaneY=y;self.pocketID=bag.pocketID;self.radius=radius
        self.restingCenterY=bag.bottom+radius
    }

    func containsProjection(_ position:V)->Bool {
        let p=P(position.x,position.z)
        guard p.x.isFinite,p.y.isFinite else { return false }
        for i in outline.indices {
            let a=outline[i],b=outline[(i+1)%outline.count],e=b-a,d=p-a
            if e.x*d.y-e.y*d.x<0 { return false }
        }
        return true
    }

    /// At the collection plane, the sphere's section is a disk of its real
    /// radius. Soft-bag contact can occur while its center is outside the bag.
    func intersectsBallProjection(_ position:V)->Bool {
        if containsProjection(position) { return true }
        let p=P(position.x,position.z)
        guard p.x.isFinite,p.y.isFinite else { return false }
        for i in outline.indices {
            let a=outline[i],b=outline[(i+1)%outline.count],edge=b-a
            let lengthSquared=edge.x*edge.x+edge.y*edge.y
            guard lengthSquared>0 else { continue }
            let offset=p-a
            let t=max(0,min(1,(offset.x*edge.x+offset.y*edge.y)/lengthSquared))
            let distance=p-(a+edge*t)
            if distance.x*distance.x+distance.y*distance.y<=radius*radius { return true }
        }
        return false
    }

    /// Return an exact timeline candidate. The scheduler must also exclude
    /// contact with an active ball before committing the irreversible record.
    func firstCandidate(in span:LocalPocketSimulation.Interval)->LocalPocketSimulation.State? {
        let start=span.start
        guard span.duration>0,start.time.isFinite,span.duration.isFinite else { return nil }
        // Solve in unit interval time and normalize coefficients. An absolute
        // discriminant epsilon can turn tiny support-force residuals into a
        // false root at t=0 while the ball is still well above the bag.
        let a=0.5*span.acceleration.y*span.duration*span.duration
        let b=start.velocity.y*span.duration,c=start.position.y-centerPlaneY
        let scale=max(abs(a),abs(b),abs(c))
        var times:[Double]=[]
        if scale>0,scale.isFinite {
            let aa=a/scale,bb=b/scale,cc=c/scale
            if aa == 0 {
                if bb != 0 { times.append((-cc/bb)*span.duration) }
            } else {
                let discriminant=bb*bb-4*aa*cc
                if discriminant>=0 {
                    let root=sqrt(discriminant)
                    let q = -0.5*(bb+(bb>=0 ? root:-root))
                    if q == 0 { times.append((-bb/(2*aa))*span.duration) }
                    else { times += [(q/aa)*span.duration,(cc/q)*span.duration] }
                }
            }
        }
        if start.position.y<=centerPlaneY,start.velocity.y<=0 { times.append(0) }
        for dt in times.sorted() where dt>=0 && dt<=span.duration {
            guard let s=span.sample(at:start.time+dt,beforeEndpoint:true),s.velocity.y<=0,
                  s.position.y<=centerPlaneY+64*Double.ulpOfOne*max(1,abs(centerPlaneY),abs(s.position.y)),
                  intersectsBallProjection(s.position) else { continue }
            return s
        }
        return nil
    }

    func isClearOfActiveBalls(_ candidate:LocalPocketSimulation.State,
                             others:[LocalPocketSimulation.State],positionUncertainty:Double)->Bool {
        guard positionUncertainty>=0,positionUncertainty.isFinite else { return false }
        return others.allSatisfy { other in
            guard other.time==candidate.time else { return false }
            let delta=other.position-candidate.position
            let d2=delta.x*delta.x+delta.y*delta.y+delta.z*delta.z
            let reach=2*radius+positionUncertainty
            return d2.isFinite && d2>reach*reach
        }
    }
}
