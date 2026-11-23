//
//  CueBallStrike.swift
//  QiuJi
//
//  杆-球碰撞模型 — 忠实移植自 pooltool
//  `physics/resolve/stick_ball/instantaneous_point` (`cue_strike`) + `squirt.py`。
//  参考: Alciatore TP_A-30 / A-31。
//
//  关键修正（相对 01.billiard_app 的旧移植）：
//  pooltool `cue_strike` 的接触点 `Q` 是 **以米为单位**（`Q = R·[ball_a, ball_c, ball_b]`），
//  角速度 `w = v/I_m · vec(Q)` 因此自带一个 R 因子。旧移植用归一化(无量纲)的
//  `ball_a/b/c` 配合 `I_m = 2/5 R²`，导致角速度量级偏大约 `1/R`(≈35×) 且分量符号不一致。
//  本实现完全照搬 pooltool 数学：在 pooltool 自身坐标系（z 朝上、台面=xy）内求解，
//  最后用一次显式坐标映射转换到 SceneKit（y 朝上、台面=xz）。
//
//  坐标映射 pooltool(x,y,z=up) → SceneKit(x,y=up,z)：
//      scene = (pt.x, pt.z, -pt.y)
//  （保持右手系；pt 的“前进=-y”对应 scene 的“前进=-z”，pt 的“上=z”对应 scene 的“上=y”）。
//

import SceneKit

struct CueBallStrike {
    /// Shared contact frame for physics and cue placement. a/b are measured
    /// perpendicular to the cue axis; the returned back/up components are in
    /// the horizontal aim / world-up plane, normalized by ball radius.
    static func contactCoordinates(spinX: Float, spinY: Float, elevation: Float) -> (side: Float, back: Float, up: Float) {
        let c=sqrtf(max(0,1-spinX*spinX-spinY*spinY))
        return (spinX,PhysicsTrigonometry.cos(elevation)*c-PhysicsTrigonometry.sin(elevation)*spinY,
            PhysicsTrigonometry.sin(elevation)*c+PhysicsTrigonometry.cos(elevation)*spinY)
    }

    // MARK: - pooltool cue_strike（z-up 坐标系，所有角度用弧度）

    /// 忠实移植 pooltool `cue_strike`。返回 pooltool 坐标系下的 (v, w)。
    /// - Parameters:
    ///   - V0: 杆头速度 (m/s)
    ///   - phi: 击球方向角 (弧度，xy 平面内)
    ///   - theta: 球杆仰角 (弧度，0 = 水平)
    ///   - a: 水平打点 (-1..1, 正 = 左塞)
    ///   - b: 垂直打点 (-1..1, 正 = 高杆)
    private static func cueStrikePT(
        V0: Float, phi: Float, theta: Float, a: Float, b: Float, preserveVerticalImpulse: Bool = false
    ) -> (v: (Float, Float, Float), w: (Float, Float, Float)) {
        let R = BallPhysics.radius
        let m = BallPhysics.mass
        let M = CuePhysics.mass
        let I_m: Float = (2.0 / 5.0) * R * R

        let cosT = PhysicsTrigonometry.cos(theta)
        let sinT = PhysicsTrigonometry.sin(theta)

        // 接触点从杆坐标系变换到球坐标系（pooltool instantaneous_point.solve）
        let point=contactCoordinates(spinX:a,spinY:b,elevation:theta)
        let ball_a = point.side
        let ball_c = point.back
        let ball_b = point.up

        // Q = R · [ball_a, ball_c, ball_b]（米）；cue_strike 内记为 (A, C, B)
        let A = R * ball_a
        let C = R * ball_c
        let B = R * ball_b

        let temp = A * A
            + (B * cosT) * (B * cosT)
            + (C * sinT) * (C * sinT)
            - 2.0 * B * C * cosT * sinT
        let denominator = 1.0 + m / M + temp / I_m
        let v = 2.0 * V0 / denominator

        // The spatial point impulse is directed down into the cloth. The
        // legacy constrained model intentionally omits this component.
        let vB: (Float, Float, Float) = (0, -v * cosT, preserveVerticalImpulse ? -v * sinT : 0)

        // 球坐标系角速度：w_B = v/I_m · [vec_x, vec_y, vec_z]
        let vecX = -C * sinT + B * cosT
        let vecY = A * sinT
        let vecZ = -A * cosT
        let scale = v / I_m
        let wB: (Float, Float, Float) = (vecX * scale, vecY * scale, vecZ * scale)

        // 旋转到台面参考系：rot = phi + π/2，绕 z(上) 轴
        let rot = phi + .pi / 2
        let vT = rotateZ(vB, rot)
        let wT = rotateZ(wB, rot)
        return (vT, wT)
    }

    /// 绕 pooltool z 轴（上）旋转——等价于 pooltool `coordinate_rotation`。
    private static func rotateZ(_ v: (Float, Float, Float), _ phi: Float) -> (Float, Float, Float) {
        let c = PhysicsTrigonometry.cos(phi), s = PhysicsTrigonometry.sin(phi)
        return (v.0 * c - v.1 * s, v.0 * s + v.1 * c, v.2)
    }

    // MARK: - Squirt（侧塞挤偏）

    /// 忠实移植 pooltool `get_squirt_angle`。返回弧度，负值=向右偏。
    /// - Parameters:
    ///   - a: 水平打点 (-1..1)
    ///   - throttle: 强度缩放 (0 关闭)
    static func squirtAngle(a: Float, throttle: Float = 1.0) -> Float {
        let m_r = BallPhysics.mass / CuePhysics.endMass
        let A = 1.0 - a * a
        let numerator = 2.5 * a * sqrtf(max(0, A))
        let denominator = 1.0 + m_r + 2.5 * A
        return -throttle * atan2f(numerator, denominator)
    }

    // MARK: - 对外便捷接口（SceneKit y-up 坐标系）

    /// 根据瞄准方向、力度、打点计算母球初速与角速度（SceneKit 坐标系）。
    ///
    /// - Parameters:
    ///   - aimDirection: 瞄准方向（XZ 平面，归一化）
    ///   - velocity: 杆头速度 (m/s)
    ///   - spinX: 水平打点 (-1..1, 正 = 左塞)
    ///   - spinY: 垂直打点 (-1..1, 正 = 高杆)
    ///   - elevation: 球杆仰角 (弧度，默认 0)
    /// - Returns: (母球初速, 角速度, squirt 角)
    static func executeStrike(
        aimDirection: SCNVector3,
        velocity: Float,
        spinX: Float,
        spinY: Float,
        elevation: Float = 0
    ) -> (velocity: SCNVector3, angularVelocity: SCNVector3, squirtAngle: Float) {
        strikeModel(aimDirection: aimDirection, velocity: velocity, spinX: spinX,
                    spinY: spinY, elevation: elevation, preserveVerticalImpulse: false)
    }

    enum SpatialStrikeError: Error { case invalidInput }

    /// Point-impact impulse only, before cloth response. This does not by itself
    /// predict jump height or account for finite tip dwell/compression.
    static func executeSpatialStrike(
        aimDirection: SCNVector3, velocity: Float, spinX: Float, spinY: Float, elevation: Float
    ) throws -> (velocity: SCNVector3, angularVelocity: SCNVector3, squirtAngle: Float) {
        guard aimDirection.x.isFinite, aimDirection.y == 0, aimDirection.z.isFinite,
              aimDirection.x != 0 || aimDirection.z != 0,
              velocity.isFinite, velocity >= 0, elevation.isFinite, (0...Float.pi/2).contains(elevation),
              spinX.isFinite, spinY.isFinite, spinX*spinX+spinY*spinY <= 1 else {
            throw SpatialStrikeError.invalidInput
        }
        // Preserve even signed-zero behavior at the old horizontal boundary.
        return strikeModel(aimDirection: aimDirection, velocity: velocity, spinX: spinX,
                           spinY: spinY, elevation: elevation, preserveVerticalImpulse: elevation != 0)
    }

    private static func strikeModel(
        aimDirection: SCNVector3, velocity: Float, spinX: Float, spinY: Float,
        elevation: Float, preserveVerticalImpulse: Bool
    ) -> (velocity: SCNVector3, angularVelocity: SCNVector3, squirtAngle: Float) {
        // pooltool 瞄准角 phi：使映射后的 scene 速度方向 = aimDirection。
        // scene 速度方向 = (cos phi, 0, -sin phi)  ⇒  phi = atan2(-az, ax)
        let phi = atan2f(-aimDirection.z, aimDirection.x)

        var (vT, wT) = cueStrikePT(
            V0: velocity, phi: phi, theta: elevation, a: spinX, b: spinY,
            preserveVerticalImpulse: preserveVerticalImpulse
        )

        // squirt：绕 z(上) 旋转台面速度（pooltool 在 solve() 里只旋转 v，不旋转 w）
        let alpha = squirtAngle(a: spinX)
        vT = rotateZ(vT, alpha)

        // pooltool(x, y, z=up) → SceneKit(x, y=up, z)：scene = (pt.x, pt.z, -pt.y)
        let vScene = SCNVector3(vT.0, vT.2, -vT.1)
        let wScene = SCNVector3(wT.0, wT.2, -wT.1)
        return (vScene, wScene, alpha)
    }

    /// 计算考虑 squirt 后的实际母球运动方向（仅方向，用于瞄准辅助线）。
    static func actualDirection(aimDirection: SCNVector3, spinX: Float) -> SCNVector3 {
        let squirt = squirtAngle(a: spinX)
        guard abs(squirt) > 0.0001 else { return aimDirection }
        // squirt 绕 scene 上轴(+y)旋转方向；pooltool 的 z 正向旋转对应 scene 绕 +y 的反向，
        // 故取 -squirt 保持与 executeStrike 一致。
        return aimDirection.rotatedY(-squirt)
    }
}

// Swift adaptation of Arm optimized-routines math/{sinf.c,cosf.c,sincosf.h,sincosf_data.c}.
// Copyright (c) 2018-2024, Arm Limited. SPDX-License-Identifier: MIT
// See Resources/ArmOptimizedRoutines-LICENSE.txt for the license and source attribution.
// Fixed polynomial/order and integer reduction avoid OS libm and LLVM sincosf fusion.
// Double intermediate operations deliberately remain separate (no addingProduct/FMA).
// The algorithm covers all finite Float arguments; NaN/infinity return NaN.
enum PhysicsTrigonometry {
    static func sin(_ x: Float) -> Float { evaluate(x, cosine: false) }
    static func cos(_ x: Float) -> Float { evaluate(x, cosine: true) }
    private static func evaluate(_ input: Float, cosine: Bool) -> Float {
        let top = (input.bitPattern >> 20) & 0x7ff
        guard input.isFinite else { return .nan }
        if top < 0x398 { return cosine ? 1 : input } // 2^-12
        var x = Double(input)
        var n = 0
        var sign = 0
        if top >= 0x3f4 { // top 12 bits of Float(pi / 4)
            if top < 0x42f { // 120
                let r = x * 0x1.45F306DC9C883p-1
                n = Int(r.rounded(.toNearestOrEven))
                x = x - Double(n) * 0x1.921FB54442D18p0
            } else {
                sign = Int(input.bitPattern >> 31)
                (x, n) = reduceLarge(input.bitPattern)
            }
        }
        let quadrant = (n + sign) & 3
        if quadrant == 1 || quadrant == 2 { x = -x }
        let x2 = x * x
        if (n ^ (cosine ? 1 : 0)) & 1 == 0 {
            let x3 = x * x2
            let s1 = 0x1.1107605230bc4p-7 + x2 * -0x1.994eb3774cf24p-13
            let x5 = x3 * x2
            let s = x + x3 * -0x1.555545995a603p-3
            return Float(s + x5 * s1)
        }
        let flip: Double = quadrant & 2 == 0 ? 1 : -1
        let x4 = x2 * x2
        let c2 = flip * -0x1.6c087e89a359dp-10 + x2 * (flip * 0x1.99343027bf8c3p-16)
        let c1 = flip + x2 * (flip * -0x1.ffffffd0c621cp-2)
        let x6 = x4 * x2
        let c = c1 + x4 * (flip * 0x1.55553e1068f19p-5)
        return Float(c + x6 * c2)
    }
    private static let inversePi: [UInt32] = [
        0xa2,0xa2f9,0xa2f983,0xa2f9836e,0xf9836e4e,0x836e4e44,
        0x6e4e4415,0x4e441529,0x441529fc,0x1529fc27,0x29fc2757,0xfc2757d1,
        0x2757d1f5,0x57d1f534,0xd1f534dd,0xf534ddc0,0x34ddc0db,0xddc0db62,
        0xc0db6295,0xdb629599,0x6295993c,0x95993c43,0x993c4390,0x3c439041]
    private static func reduceLarge(_ bits: UInt32) -> (Double, Int) {
        let offset = Int((bits >> 26) & 15)
        let shift = (bits >> 23) & 7
        let xi = ((bits & 0xffffff) | 0x800000) << shift
        var low = UInt64(xi &* inversePi[offset])
        let middle = UInt64(xi) * UInt64(inversePi[offset + 4])
        let high = UInt64(xi) * UInt64(inversePi[offset + 8])
        low = (high >> 32) | (low << 32)
        low = low &+ middle
        let n = (low &+ (1 << 61)) >> 62
        low = low &- (n << 62)
        return (Double(Int64(bitPattern: low)) * 0x1.921FB54442D18p-62, Int(n))
    }
}
