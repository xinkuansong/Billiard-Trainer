//
//  CollisionResolver.swift
//  BilliardTrainer
//
//  碰撞解析模型（球-球、球-库边）
//

import SceneKit

struct CollisionResolver {
    
    // MARK: - Pure Computation Results
    
    /// Result of a ball-ball collision resolution
    struct BallBallResult {
        let velA: SCNVector3
        let velB: SCNVector3
        let angVelA: SCNVector3
        let angVelB: SCNVector3
    }
    
    /// Result of a ball-cushion collision resolution
    struct CushionResult {
        let velocity: SCNVector3
        let angularVelocity: SCNVector3
    }
    
    // MARK: - Pure Computation Functions (no SCNNode dependency)
    
    /// 球-球摩擦非弹性碰撞 — 忠实移植 pooltool
    /// `physics/resolve/ball_ball/frictional_inelastic` 的 `_resolve_ball_ball`，
    /// 摩擦系数用 Alciatore 拟合曲线（`friction.py` AlciatoreBallBallFriction，
    /// 基于切向接触面相对速度 `tangent_surface_velocity`）。
    ///
    /// 相对旧移植的修正：旧版用自定义冲量记账（`J_n = M(1+e)Δvₙ`、`min(J_t_max, J_t_needed)`
    /// 以及一段自写的滑移反转修正），与 pooltool 的 `D_v1_t = u_b·|Δvₙ_f|·(−v̂₁₂c)` 不一致，
    /// 会令 throw / 分离角偏差。本实现完全照搬 pooltool 的滑移 / 无滑移两分支。
    static func resolveBallBallPure(
        posA: SCNVector3, posB: SCNVector3,
        velA: SCNVector3, velB: SCNVector3,
        angVelA: SCNVector3, angVelB: SCNVector3
    ) -> BallBallResult {
        let unitX = SCNVector3(1, 0, 0)
        let unitXNeg = SCNVector3(-1, 0, 0)

        let delta = posB - posA
        // 连心线与 +x 的夹角（台面在 XZ 平面）。
        let theta = atan2f(delta.z, delta.x)

        // 旋转进入碰撞坐标系（x = 连心线方向）。
        var v1 = rotateY(velA, angle: -theta)
        var v2 = rotateY(velB, angle: -theta)
        var w1 = rotateY(angVelA, angle: -theta)
        var w2 = rotateY(angVelB, angle: -theta)

        let e = BallPhysics.restitution
        let R = BallPhysics.radius

        // u_b：Alciatore 摩擦拟合，基于切向接触面相对速度（pooltool friction.py）。
        let v1t = tangentSurfaceVelocity(linear: v1, angular: w1, radius: R, normal: unitX)
        let v2t = tangentSurfaceVelocity(linear: v2, angular: w2, radius: R, normal: unitXNeg)
        let relSurfaceSpeed = (v1t - v2t).length()
        let u_b: Float = 0.009951 + 0.108 * expf(-1.088 * relSurfaceSpeed)

        // 法向分量（用恢复系数交换），两分支共用。
        let v1n = v1.x
        let v2n = v2.x
        let v1nf = 0.5 * ((1 - e) * v1n + (1 + e) * v2n)
        let v2nf = 0.5 * ((1 + e) * v1n + (1 - e) * v2n)
        let dVnMagnitude = abs(v2nf - v1nf)
        // 角速度法向分量不变。
        let w1nf = w1.x
        let w2nf = w2.x

        // 暂时丢弃法向分量，仅处理切向。
        v1.x = 0; v2.x = 0; w1.x = 0; w2.x = 0
        var v1f = v1, v2f = v2, w1f = w1, w2f = w2

        let v1c = surfaceVelocity(linear: v1, angular: w1, radius: R, normal: unitX)
        let v2c = surfaceVelocity(linear: v2, angular: w2, radius: R, normal: unitXNeg)
        let v12c = v1c - v2c
        let hasRelativeVelocity = v12c.length() > 0.0001

        var slipValid = false
        if hasRelativeVelocity {
            // 滑移分支。
            let v12cHat = v12c.normalized()
            let dV1t = v12cHat * (-u_b * dVnMagnitude)
            let dW1 = unitX.cross(dV1t) * (2.5 / R)
            v1f = v1 + dV1t; w1f = w1 + dW1
            v2f = v2 - dV1t; w2f = w2 + dW1

            let v1cSlip = surfaceVelocity(linear: v1f, angular: w1f, radius: R, normal: unitX)
            let v2cSlip = surfaceVelocity(linear: v2f, angular: w2f, radius: R, normal: unitXNeg)
            let v12cSlip = v1cSlip - v2cSlip
            slipValid = v12c.dot(v12cSlip) > 0
        }

        if !slipValid {
            // 无滑移（滚动）分支。
            let dV1t = (v1 - v2 + (w1 + w2).cross(unitX) * R) * (-(1.0 / 7.0))
            let dW1 = (unitX.cross(v1 - v2) / R + (w1 + w2)) * (-(5.0 / 14.0))
            v1f = v1 + dV1t; w1f = w1 + dW1
            v2f = v2 - dV1t; w2f = w2 + dW1
        }

        // 还原法向分量。
        v1f.x = v1nf; v2f.x = v2nf
        w1f.x = w1nf; w2f.x = w2nf

        // 去除塞致 throw 在竖直方向(scene +y)产生的速度分量（pooltool 去 z 分量）。
        v1f.y = 0; v2f.y = 0

        // 旋转回世界坐标系。
        return BallBallResult(
            velA: rotateY(v1f, angle: theta),
            velB: rotateY(v2f, angle: theta),
            angVelA: rotateY(w1f, angle: theta),
            angVelB: rotateY(w2f, angle: theta)
        )
    }
    
    /// 球-库边碰撞 — 纯计算版本（Han 2005 闭式解，移植自 pooltool）。
    ///
    /// 用 **右手** 接触系做投影 / 重建（修复旧版 `t_horizontal=(-nz,0,nx)` 与 `up`
    /// 构成左手系、可能导致角速度 / throw 符号偏差的隐患）：
    ///   N = 水平法向（指向运动方向），T = U × N（切向，台面内），U = (0,1,0)。
    /// 该三元组满足 N × T = U（右手）。
    static func resolveCushionCollisionPure(
        velocity: SCNVector3,
        angularVelocity: SCNVector3,
        normal: SCNVector3,
        restitution: Float = TablePhysics.cushionRestitution
    ) -> CushionResult {
        let v = velocity
        let w = angularVelocity

        // 水平法向（库面在 XZ 平面）。
        let nHorizontal = SCNVector3(normal.x, 0, normal.z)
        guard nHorizontal.length() > 0.001 else {
            // 近垂直法向（库面理论上不会出现）——原样返回，避免除零。
            return CushionResult(velocity: v, angularVelocity: w)
        }
        var N = nHorizontal.normalized()
        // 确保 N 指向运动方向，使法向接近速度 v·N > 0（Han 要求 rvw_R[1,0] > 0）。
        if v.dot(N) < 0 { N = SCNVector3(-N.x, -N.y, -N.z) }

        let U = SCNVector3(0, 1, 0)
        let T = U.cross(N)  // 右手系切向

        let result = Han2005CushionModel.solve(
            vNormal: v.dot(N),
            vTangent: v.dot(T),
            wNormal: w.dot(N),
            wTangent: w.dot(T),
            wUp: w.dot(U),
            mu: TablePhysics.cushionFriction,
            e: restitution,
            h: TablePhysics.cushionHeight,
            R: BallPhysics.radius,
            M: BallPhysics.mass
        )

        let vN: SCNVector3 = N * result.vNormal
        let vT: SCNVector3 = T * result.vTangent
        let vFinal = vN + vT

        let wN: SCNVector3 = N * result.wNormal
        let wT: SCNVector3 = T * result.wTangent
        let wU: SCNVector3 = U * result.wUp
        let wFinal = wN + wT + wU
        return CushionResult(velocity: vFinal, angularVelocity: wFinal)
    }
    
    // MARK: - SCNNode Wrapper Functions (for SceneKit integration)
    
    /// 球-球碰撞 — SCNNode 包装版本
    static func resolveBallBall(ballA: SCNNode, ballB: SCNNode) {
        guard let bodyA = ballA.physicsBody,
              let bodyB = ballB.physicsBody else { return }
        
        let result = resolveBallBallPure(
            posA: ballA.presentation.position,
            posB: ballB.presentation.position,
            velA: bodyA.velocity,
            velB: bodyB.velocity,
            angVelA: SCNVector3(bodyA.angularVelocity.x, bodyA.angularVelocity.y, bodyA.angularVelocity.z),
            angVelB: SCNVector3(bodyB.angularVelocity.x, bodyB.angularVelocity.y, bodyB.angularVelocity.z)
        )
        
        bodyA.velocity = result.velA
        bodyB.velocity = result.velB
        bodyA.angularVelocity = SCNVector4(result.angVelA.x, result.angVelA.y, result.angVelA.z, 0)
        bodyB.angularVelocity = SCNVector4(result.angVelB.x, result.angVelB.y, result.angVelB.z, 0)
    }
    
    /// 球-库边碰撞 — SCNNode 包装版本
    static func resolveCushionCollision(ball: SCNNode, normal: SCNVector3) {
        guard let body = ball.physicsBody else { return }
        
        let result = resolveCushionCollisionPure(
            velocity: body.velocity,
            angularVelocity: SCNVector3(body.angularVelocity.x, body.angularVelocity.y, body.angularVelocity.z),
            normal: normal
        )
        
        body.velocity = result.velocity
        body.angularVelocity = SCNVector4(result.angularVelocity.x, result.angularVelocity.y, result.angularVelocity.z, 0)
    }
    
    // MARK: - Private Helpers
    
    private static func surfaceVelocity(linear: SCNVector3, angular: SCNVector3, radius: Float, normal: SCNVector3) -> SCNVector3 {
        let r = normal * radius
        return linear + angular.cross(r)
    }

    /// 接触点处的切向表面速度（pooltool `tangent_surface_velocity`）：
    /// `v_t = v - (v·d)d + ω × (R·d)`。
    private static func tangentSurfaceVelocity(linear: SCNVector3, angular: SCNVector3, radius: Float, normal: SCNVector3) -> SCNVector3 {
        let vn = linear.dot(normal)
        let vTangent = linear - normal * vn
        return vTangent + angular.cross(normal * radius)
    }
    
    private static func rotateY(_ v: SCNVector3, angle: Float) -> SCNVector3 {
        let cosA = cosf(angle)
        let sinA = sinf(angle)
        return SCNVector3(v.x * cosA - v.z * sinA, v.y, v.x * sinA + v.z * cosA)
    }
}
