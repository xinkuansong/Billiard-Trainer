//
//  TableGeometry.swift
//  BilliardTrainer
//
//  程序化球台几何描述
//  角袋几何基于 CAD 精确数据（两独立圆弧圆心 + jaw 直线段）
//

import SceneKit

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
        let throatZFar = TablePhysics.sidePocketCenterOffsetZ                  // 0.688
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
