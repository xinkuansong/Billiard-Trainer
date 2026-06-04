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

    // MARK: - pooltool cue_strike（z-up 坐标系，所有角度用弧度）

    /// 忠实移植 pooltool `cue_strike`。返回 pooltool 坐标系下的 (v, w)。
    /// - Parameters:
    ///   - V0: 杆头速度 (m/s)
    ///   - phi: 击球方向角 (弧度，xy 平面内)
    ///   - theta: 球杆仰角 (弧度，0 = 水平)
    ///   - a: 水平打点 (-1..1, 正 = 左塞)
    ///   - b: 垂直打点 (-1..1, 正 = 高杆)
    private static func cueStrikePT(
        V0: Float, phi: Float, theta: Float, a: Float, b: Float
    ) -> (v: (Float, Float, Float), w: (Float, Float, Float)) {
        let R = BallPhysics.radius
        let m = BallPhysics.mass
        let M = CuePhysics.mass
        let I_m: Float = (2.0 / 5.0) * R * R

        let cosT = cosf(theta)
        let sinT = sinf(theta)

        // 接触点从杆坐标系变换到球坐标系（pooltool instantaneous_point.solve）
        let cue_c = sqrtf(max(0, 1.0 - a * a - b * b))
        let ball_a = a
        let ball_c = cosT * cue_c - sinT * b
        let ball_b = sinT * cue_c + cosT * b

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

        // 球坐标系速度：v_B = -v[0, cosθ, 0]
        let vB: (Float, Float, Float) = (0, -v * cosT, 0)

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
        let c = cosf(phi), s = sinf(phi)
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
        // pooltool 瞄准角 phi：使映射后的 scene 速度方向 = aimDirection。
        // scene 速度方向 = (cos phi, 0, -sin phi)  ⇒  phi = atan2(-az, ax)
        let phi = atan2f(-aimDirection.z, aimDirection.x)

        var (vT, wT) = cueStrikePT(
            V0: velocity, phi: phi, theta: elevation, a: spinX, b: spinY
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
