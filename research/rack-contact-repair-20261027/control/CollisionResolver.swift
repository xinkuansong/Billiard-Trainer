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
        let u_b = BallPhysics.contactFriction(relativeSurfaceSpeed:relSurfaceSpeed)

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

/// Equal-radius, equal-mass spatial ball contact. The planar resolver retains its
/// existing constrained-table contract; this response does not erase vertical velocity.
enum SpatialBallContact {
    typealias V = SIMD3<Double>
    typealias Motion = PocketContactResponse.Motion
    enum MaterialSource:Hashable { case supplied, ballPhysics }

    /// Constraint normal B -> A; contact arms are -R*n and +R*n.
    /// Material coefficients are shared with the planar engine. The spatial
    /// impulse solver still preserves three-dimensional momentum and spin.
    static func material(source:MaterialSource,a:Motion,b:Motion,normal:V,radius:Double,
                         restitution:Double,friction:Double)->(restitution:Double,friction:Double) {
        guard source == .ballPhysics else { return (restitution,friction) }
        let n=normal/length(normal)
        let relative=a.velocity-cross(a.angularVelocity,n*radius)-b.velocity-cross(b.angularVelocity,n*radius)
        let tangent=relative-n*dot(relative,n)
        return (Double(BallPhysics.restitution),Double(BallPhysics.contactFriction(relativeSurfaceSpeed:Float(length(tangent)))))
    }
    struct Hit { let time:Double; let normal:V } // A -> B
    struct Response { let a:Motion; let b:Motion; let impulseOnA:V }
    enum Failure:Error { case invalidInput }
    private static func dot(_ a:V,_ b:V)->Double { a.x*b.x+a.y*b.y+a.z*b.z }
    private static func cross(_ a:V,_ b:V)->V { V(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x) }
    private static func length(_ v:V)->Double { sqrt(dot(v,v)) }
    private static func finite(_ v:V)->Bool { v.x.isFinite && v.y.isFinite && v.z.isFinite }

    /// Inputs are B minus A, along a constant-relative-acceleration interval.
    static func firstContact(position p:V,velocity v:V,acceleration a:V,
                             radiusSum:Double,horizon:Double,positionUncertainty:Double=0) throws -> Hit? {
        guard finite(p),finite(v),finite(a),radiusSum>0,radiusSum.isFinite,
              horizon>=0,horizon.isFinite,positionUncertainty>=0,positionUncertainty.isFinite else { throw Failure.invalidInput }
        var roots=boundedRoots([dot(p,p)-radiusSum*radiusSum,2*dot(p,v),
            dot(v,v)+dot(p,a),dot(v,a),0.25*dot(a,a)],horizon:horizon)
        // Relative coordinates alone cannot recover rounding incurred when two
        // world-space positions were subtracted. The trajectory caller supplies
        // that positional uncertainty; it is not an integration-error tolerance.
        let rounding=max(positionUncertainty,64*Double.ulpOfOne*max(1,length(p),radiusSum))
        if abs(length(p)-radiusSum)<=rounding { roots.append(0) }
        var earliest:Hit?
        for seed in roots where seed.isFinite && seed>=0 && seed<=horizon {
            var t=seed
            for _ in 0..<12 {
                let delta=p+v*t+a*(0.5*t*t)
                let derivative=2*dot(delta,v+a*t)
                guard derivative != 0 else { break }
                let next=t-(dot(delta,delta)-radiusSum*radiusSum)/derivative
                guard next.isFinite,next>=0,next<=horizon,next != t else { break }
                t=next
            }
            let delta=p+v*t+a*(0.5*t*t),distance=length(delta)
            guard distance>0,abs(distance-radiusSum)<=rounding else { continue }
            let n=delta/distance
            guard dot(v+a*t,n)<0 else { continue }
            if earliest == nil || t<earliest!.time { earliest=Hit(time:t,normal:n) }
        }
        return earliest
    }

    /// Isolate roots between derivative roots, where the polynomial is monotone.
    /// Coefficients are in ascending order. In particular, no absolute time
    /// tolerance merges a separating t=0 root with a subsequent impact.
    private static func boundedRoots(_ coefficients:[Double],horizon:Double)->[Double] {
        var c=coefficients
        while c.count>1 && c.last == 0 { c.removeLast() }
        guard c.count>1 else { return [] }
        if c.count == 2 {
            let root = -c[0]/c[1]
            return root.isFinite && root>=0 && root<=horizon ? [root] : []
        }
        func value(_ x:Double)->Double {
            c.reversed().reduce(0) { $0*x+$1 }
        }
        let derivative=(1..<c.count).map { Double($0)*c[$0] }
        let critical=boundedRoots(derivative,horizon:horizon)
        let knots=Array(Set([0,horizon]+critical)).sorted()
        var roots=knots.filter { value($0) == 0 }
        for (left,right) in zip(knots,knots.dropFirst()) {
            var lo=left,hi=right
            var flo=value(lo)
            let fhi=value(hi)
            guard flo != 0,fhi != 0,flo.sign != fhi.sign else { continue }
            // Binary subdivision terminates at adjacent representable times,
            // rather than a fixed absolute epsilon that could erase short flights.
            while lo.nextUp<hi {
                let mid=lo+(hi-lo)*0.5
                guard mid>lo,mid<hi else { break }
                let fm=value(mid)
                if fm == 0 { lo=mid; hi=mid; break }
                if fm.sign == flo.sign { lo=mid; flo=fm } else { hi=mid }
            }
            roots.append(abs(value(lo))<=abs(value(hi)) ? lo : hi)
        }
        return Array(Set(roots)).sorted()
    }

    /// Impulses are per unit mass; I/m = 2R²/5. The two free spheres' tangential
    /// effective inverse mass is 2 + 5 = 7. Support constraints are resolved by the
    /// caller's coupled event system, never by silently flattening either velocity.
    static func resolve(a:Motion,b:Motion,normal:V,radius:Double,
                        restitution:Double,friction:Double) throws -> Response {
        guard finite(a.velocity),finite(a.angularVelocity),finite(b.velocity),finite(b.angularVelocity),
              finite(normal),length(normal)>0,radius>0,radius.isFinite,
              restitution.isFinite,(0...1).contains(restitution),friction>=0,friction.isFinite else { throw Failure.invalidInput }
        let n=normal/length(normal)
        let relative=a.velocity+cross(a.angularVelocity,n*radius)-b.velocity-cross(b.angularVelocity,-n*radius)
        let closing=dot(relative,n)
        guard closing>0 else { return Response(a:a,b:b,impulseOnA:.zero) }
        let normalImpulse=0.5*(1+restitution)*closing
        var tangentImpulse = -(relative-n*closing)/7
        let limit=friction*normalImpulse
        if length(tangentImpulse)>limit { tangentImpulse*=limit/length(tangentImpulse) }
        let impulse = -n*normalImpulse+tangentImpulse
        let spinChange=cross(n,impulse)*(2.5/radius)
        return Response(a:Motion(velocity:a.velocity+impulse,angularVelocity:a.angularVelocity+spinChange),
                        b:Motion(velocity:b.velocity-impulse,angularVelocity:b.angularVelocity+spinChange),impulseOnA:impulse)
    }
}

extension SpatialBallContact {
    /// `normal` points from B/static support toward A. All moving bodies share
    /// the requested radius/mass. A nil B is a fixed surface.
    struct Constraint {
        let a:Int
        let b:Int?
        let normal:V
        let restitution:Double
        let friction:Double
    }
    enum CoupledFailure:Error { case invalidInput, convergence(residual:Double) }

    struct InstantResponse {
        let motions: [Motion]
        /// Each entry is a response at the same absolute time, not a time step.
        let rounds: [[Motion]]
    }

    /// Resolve all geometrically touching candidates before advancing time.
    /// Positions and normals remain fixed throughout the instantaneous response.
    /// The caller must supply the complete touching set, including separating
    /// candidates which another impulse may make approaching.
    static func resolveInstant(_ initial:[Motion], constraints:[Constraint], radius:Double,
                               maxRounds:Int=128) throws -> InstantResponse {
        guard maxRounds>0 else { throw CoupledFailure.invalidInput }
        var states=try resolveCoupled(initial,constraints:constraints,radius:radius)
        var rounds=[states]
        let scale=max(1,initial.map { max(length($0.velocity),radius*length($0.angularVelocity)) }.max() ?? 0)
        for round in 1...maxRounds {
            var approaching=0.0
            for c in constraints {
                let n=c.normal/length(c.normal)
                var v=states[c.a].velocity+cross(states[c.a].angularVelocity,-n*radius)
                if let b=c.b { v-=states[b].velocity+cross(states[b].angularVelocity,n*radius) }
                approaching=max(approaching,-dot(v,n))
            }
            // Use the coupled solver's numerical residual contract, rather than
            // a perceptual resting threshold or a fabricated positive time step.
            if approaching<=64*Double.ulpOfOne*scale { return InstantResponse(motions:states,rounds:rounds) }
            guard round<maxRounds else { throw CoupledFailure.convergence(residual:approaching) }
            states=try resolveCoupled(states,constraints:constraints,radius:radius)
            rounds.append(states)
        }
        preconditionFailure("The bounded response loop always returns or throws")
    }

    static func resolveCoupled(_ initial:[Motion],constraints:[Constraint],radius:Double) throws -> [Motion] {
        guard radius>0,radius.isFinite,initial.allSatisfy({finite($0.velocity) && finite($0.angularVelocity)}),
              constraints.allSatisfy({ c in initial.indices.contains(c.a) && (c.b == nil || (initial.indices.contains(c.b!) && c.b != c.a))
                  && finite(c.normal) && length(c.normal)>0 && c.restitution.isFinite && (0...1).contains(c.restitution)
                  && c.friction>=0 && c.friction.isFinite }) else { throw CoupledFailure.invalidInput }
        guard !constraints.isEmpty else { return initial }
        // A sphere's static contact Jacobian is determined by its body and
        // normal (arm = -R*n). Identical material laws on coincident mesh
        // features therefore describe one constraint, regardless of how many
        // triangles share that feature. Retaining duplicates slows the global
        // Jacobi relaxation without adding a physical degree of freedom.
        // Use exact equality only: distinct normals/materials remain distinct.
        var unique:[Constraint]=[]
        for c in constraints {
            if c.b == nil && unique.contains(where:{
                $0.b == nil && $0.a == c.a && $0.normal == c.normal &&
                $0.restitution == c.restitution && $0.friction == c.friction
            }) { continue }
            unique.append(c)
        }
        if unique.count != constraints.count {
            return try resolveCoupled(initial,constraints:unique,radius:radius)
        }
        let normals=constraints.map { $0.normal/length($0.normal) }
        func relative(_ states:[Motion],_ j:Int)->V {
            let c=constraints[j],n=normals[j]
            var v=states[c.a].velocity+cross(states[c.a].angularVelocity,-n*radius)
            if let b=c.b { v-=states[b].velocity+cross(states[b].angularVelocity,n*radius) }
            return v
        }
        // A geometrically touching but separating surface cannot supply support
        // during this impact. Including it in the restitution solve can inject
        // energy. The event scheduler must revisit contacts made approaching by
        // this response at the same absolute time, before advancing motion.
        let active=constraints.indices.filter { dot(relative(initial,$0),normals[$0])<=0 }
        if active.count != constraints.count {
            return try resolveCoupled(initial,constraints:active.map { constraints[$0] },radius:radius)
        }
        let target=constraints.indices.map { max(0,-dot(relative(initial,$0),normals[$0]))*constraints[$0].restitution }
        var normalImpulse=Array(repeating:0.0,count:constraints.count)
        var tangentImpulse=Array(repeating:V.zero,count:constraints.count)
        var states=initial,residual=Double.infinity
        let relaxation=1/Double(constraints.count)
        let scale=max(1,initial.map { max(length($0.velocity),radius*length($0.angularVelocity)) }.max() ?? 0)
        func motion(_ nf:[Double],_ tf:[V])->[Motion] {
            var result=initial
            for j in constraints.indices {
                let c=constraints[j],n=normals[j],impulse=n*nf[j]+tf[j]
                let spin=cross(-n,impulse)*(2.5/radius),a=result[c.a]
                result[c.a]=Motion(velocity:a.velocity+impulse,angularVelocity:a.angularVelocity+spin)
                if let b=c.b {
                    let body=result[b]
                    result[b]=Motion(velocity:body.velocity-impulse,angularVelocity:body.angularVelocity+spin)
                }
            }
            return result
        }
        func mapped(_ nf:[Double],_ tf:[V])->([Double],[V]) {
            let current=motion(nf,tf)
            var nextN=nf,nextT=tf
            for j in constraints.indices {
                let c=constraints[j],n=normals[j],v=relative(current,j),inverseMass=c.b == nil ? 1.0 : 2.0
                let requestedN=max(0,nf[j]+(target[j]-dot(v,n))/inverseMass)
                var requestedT=tf[j]-(v-n*dot(v,n))/(3.5*inverseMass)
                let limit=c.friction*requestedN
                if length(requestedT)>limit { requestedT*=limit/length(requestedT) }
                nextN[j]+=relaxation*(requestedN-nf[j])
                nextT[j]+=relaxation*(requestedT-tf[j])
            }
            return (nextN,nextT)
        }
        func packed(_ nf:[Double],_ tf:[V])->[Double] {
            constraints.indices.flatMap{[nf[$0],tf[$0].x,tf[$0].y,tf[$0].z]}
        }
        func residualSquared(_ nf:[Double],_ tf:[V])->Double {
            let m=mapped(nf,tf)
            return constraints.indices.reduce(0){$0+pow(m.0[$1]-nf[$1],2)+dot(m.1[$1]-tf[$1],m.1[$1]-tf[$1])}
        }
        var previousMap:[Double]?,previousResidual:[Double]?
        for _ in 0..<4096 {
            let m=mapped(normalImpulse,tangentImpulse)
            var nextN=m.0,nextT=m.1
            let values=packed(normalImpulse,tangentImpulse),mapValues=packed(m.0,m.1)
            let fixedResidual=zip(mapValues,values).map{$0-$1}
            // Safeguarded depth-one Anderson extrapolation. It changes only
            // the iteration path, never the contact law or acceptance budget.
            if let oldMap=previousMap,let oldResidual=previousResidual {
                let difference=zip(fixedResidual,oldResidual).map{$0-$1}
                let denominator=difference.reduce(0){$0+$1*$1}
                if denominator>Double.leastNormalMagnitude {
                    let beta=zip(difference,fixedResidual).reduce(0){$0+$1.0*$1.1}/denominator
                    let proposal=zip(mapValues,oldMap).map{$0-beta*($0-$1)}
                    if proposal.allSatisfy({$0.isFinite}) {
                        var trialN=nextN,trialT=nextT
                        for j in constraints.indices {
                            trialN[j]=max(0,proposal[4*j])
                            var t=V(proposal[4*j+1],proposal[4*j+2],proposal[4*j+3])
                            t-=normals[j]*dot(t,normals[j])
                            let limit=constraints[j].friction*trialN[j]
                            if length(t)>limit { t*=limit/length(t) }
                            trialT[j]=t
                        }
                        if residualSquared(trialN,trialT)<residualSquared(nextN,nextT) {
                            nextN=trialN;nextT=trialT
                        }
                    }
                }
            }
            previousMap=mapValues;previousResidual=fixedResidual
            let previous=states
            normalImpulse=nextN;tangentImpulse=nextT;states=motion(nextN,nextT)
            residual=0
            for j in constraints.indices {
                let c=constraints[j],n=normals[j],v=relative(states,j),inverseMass=c.b == nil ? 1.0 : 2.0
                let normalError=dot(v,n)-target[j]
                // Natural complementarity residual, in velocity units. A
                // relaxed impulse can decay to the smallest subnormal without
                // becoming exactly zero; testing lambda>0 would then incorrectly
                // demand zero separation velocity from a released contact.
                let projectedNormal=max(0,normalImpulse[j]-normalError/inverseMass)
                residual=max(residual,inverseMass*abs(projectedNormal-normalImpulse[j]))
                var projected=tangentImpulse[j]-(v-n*dot(v,n))/(3.5*inverseMass)
                let limit=c.friction*normalImpulse[j]
                if length(projected)>limit { projected*=limit/length(projected) }
                residual=max(residual,3.5*inverseMass*length(projected-tangentImpulse[j]))
            }
            let change=states.indices.map { max(length(states[$0].velocity-previous[$0].velocity),
                radius*length(states[$0].angularVelocity-previous[$0].angularVelocity)) }.max() ?? 0
            // Do not demand a unique distribution among redundant contacts.
            // The moving states and all contact constraints must both converge.
            if change<=64*Double.ulpOfOne*scale && residual<=64*Double.ulpOfOne*scale { return states }
        }
        #if DEBUG
        print("[W06 impulse convergence] residual=\(residual) initial=\(initial) constraints=\(constraints)")
        #endif
        throw CoupledFailure.convergence(residual:residual)
    }
}

extension SpatialBallContact {
    struct SupportConstraint {
        let contact: Constraint
        let normalRate: V
        let rollingFriction: Double
        let spinFriction: Double
        init(contact:Constraint,normalRate:V,rollingFriction:Double=0,spinFriction:Double=0) {
            self.contact=contact;self.normalRate=normalRate
            self.rollingFriction=rollingFriction;self.spinFriction=spinFriction
        }
    }
    struct Acceleration { let linear:V; let angular:V }
    struct SupportResponse { let accelerations:[Acceleration]; let forcesOnA:[V] }

    /// Sustained unilateral contact forces per unit mass, including Coulomb
    /// sliding and static friction. Geometry supplies the normal derivative.
    /// Impacts must be resolved first; separating contacts carry no force.
    static func resolveSupport(_ motions:[Motion],external:[Acceleration],constraints:[SupportConstraint],
                               radius:Double,duration:Double?=nil) throws -> SupportResponse {
        guard radius>0,radius.isFinite,motions.count == external.count,
              duration.map{$0>0 && $0.isFinite} ?? true,
              motions.allSatisfy({finite($0.velocity) && finite($0.angularVelocity)}),
              external.allSatisfy({finite($0.linear) && finite($0.angular)}),
              constraints.allSatisfy({ s in let c=s.contact
                  return motions.indices.contains(c.a) && (c.b == nil || (motions.indices.contains(c.b!) && c.b != c.a))
                    && finite(c.normal) && length(c.normal)>0 && finite(s.normalRate)
                    && c.friction>=0 && c.friction.isFinite
                    && s.rollingFriction>=0 && s.rollingFriction.isFinite
                    && s.spinFriction>=0 && s.spinFriction.isFinite
                    && ((s.rollingFriction == 0 && s.spinFriction == 0)
                        || (c.b == nil && duration.map{$0>0 && $0.isFinite} == true))
              }) else { throw CoupledFailure.invalidInput }
        let normals=constraints.map{$0.contact.normal/length($0.contact.normal)}
        func relativeLinear(_ values:[V],_ c:Constraint)->V { values[c.a]-(c.b.map{values[$0]} ?? .zero) }
        let velocities=motions.map(\.velocity)
        let active=constraints.indices.map { j -> Bool in
            let c=constraints[j].contact,v=relativeLinear(velocities,c)
            let rounding=64*Double.ulpOfOne*max(1,length(motions[c.a].velocity),c.b.map{length(motions[$0].velocity)} ?? 0)
            return abs(dot(v,normals[j]))<=rounding
        }
        let slips=constraints.indices.map { j -> V in
            let c=constraints[j].contact,n=normals[j]
            let u=relativeLinear(velocities,c)-cross(motions[c.a].angularVelocity+(c.b.map{motions[$0].angularVelocity} ?? .zero),n*radius)
            let tangent=u-n*dot(u,n)
            let scale=length(motions[c.a].velocity)+radius*length(motions[c.a].angularVelocity) +
                (c.b.map{length(motions[$0].velocity)+radius*length(motions[$0].angularVelocity)} ?? 0)
            return length(tangent)<=16*Double.ulpOfOne*scale ? .zero : tangent
        }
        let relaxation=1/Double(max(1,constraints.count))
        let externalScale=max(1,external.map{max(length($0.linear),radius*length($0.angular))}.max() ?? 0)
        // Finite-step friction subtracts slip/dt in acceleration units. Its
        // rounding error follows that operand, not gravity alone; retaining the
        // same ULP multiplier avoids demanding digits lost in this subtraction.
        let slipRateScale=duration.map { dt in slips.map { length($0)/dt }.max() ?? 0 } ?? 0
        let scale=max(externalScale,slipRateScale)
        func rebuilt(_ normalForce:[Double],_ tangentForce:[V])->[Acceleration] {
            var acceleration=external
            for j in constraints.indices {
                let c=constraints[j].contact,n=normals[j],force=n*normalForce[j]+tangentForce[j]
                let torque=cross(-n,force)*(2.5/radius),a=acceleration[c.a]
                acceleration[c.a]=Acceleration(linear:a.linear+force,angular:a.angular+torque +
                    PocketContactResponse.surfaceResistance(omega:motions[c.a].angularVelocity,normal:n,
                        pressure:normalForce[j],radius:radius,duration:duration ?? 1,
                        rollingFriction:constraints[j].rollingFriction,spinFriction:constraints[j].spinFriction))
                if let b=c.b { let value=acceleration[b]
                    acceleration[b]=Acceleration(linear:value.linear-force,angular:value.angular+torque)
                }
            }
            return acceleration
        }
        func mapped(_ normalForce:[Double],_ tangentForce:[V])->([Double],[V],Double) {
            let acceleration=rebuilt(normalForce,tangentForce)
            var residual=0.0
            var nextN=normalForce,nextT=tangentForce
            residual=0
            for j in constraints.indices where active[j] {
                let s=constraints[j],c=s.contact,n=normals[j],inverseMass=c.b == nil ? 1.0 : 2.0
                let relativeAcceleration=acceleration[c.a].linear-(c.b.map{acceleration[$0].linear} ?? .zero)
                let curvature=dot(relativeLinear(velocities,c),s.normalRate)
                let normalRate=duration.map{dot(relativeLinear(velocities,c),n)/$0} ?? 0
                let requestedN=max(0,normalForce[j]-(normalRate+dot(relativeAcceleration,n)+curvature)/inverseMass)
                let limit=c.friction*requestedN
                var requestedT:V
                if slips[j] != .zero && duration == nil {
                    requestedT = -slips[j]*(limit/length(slips[j]))
                } else {
                    let alpha=acceleration[c.a].angular+(c.b.map{acceleration[$0].angular} ?? .zero)
                    let omega=motions[c.a].angularVelocity+(c.b.map{motions[$0].angularVelocity} ?? .zero)
                    let derivative=relativeAcceleration-cross(alpha,n*radius)-cross(omega,s.normalRate*radius)
                    // Match local surface integration: solve the endpoint slip
                    // inside the Coulomb disk, including a stop within this step.
                    let slipRate=duration.map{slips[j]/$0} ?? .zero
                    requestedT=tangentForce[j]-(slipRate+derivative-n*dot(derivative,n))/(3.5*inverseMass)
                    if length(requestedT)>limit { requestedT*=limit/length(requestedT) }
                }
                residual=max(residual,inverseMass*abs(requestedN-normalForce[j]),
                             3.5*inverseMass*length(requestedT-tangentForce[j]))
                nextN[j]+=relaxation*(requestedN-normalForce[j])
                nextT[j]+=relaxation*(requestedT-tangentForce[j])
            }

            return (nextN,nextT,residual)
        }
        func packed(_ nf:[Double],_ tf:[V])->[Double] {
            constraints.indices.flatMap{[nf[$0],tf[$0].x,tf[$0].y,tf[$0].z]}
        }
        var normalForce=Array(repeating:0.0,count:constraints.count),tangentForce=Array(repeating:V.zero,count:constraints.count)
        var residual=Double.infinity,previousMap:[Double]?,previousResidual:[Double]?
        for _ in 0..<4096 {
            let m=mapped(normalForce,tangentForce);residual=m.2
            if residual<=64*Double.ulpOfOne*scale {
                return SupportResponse(accelerations:rebuilt(normalForce,tangentForce),forcesOnA:constraints.indices.map{normals[$0]*normalForce[$0]+tangentForce[$0]})
            }
            var nextN=m.0,nextT=m.1
            let values=packed(normalForce,tangentForce),mapValues=packed(nextN,nextT)
            let fixedResidual=zip(mapValues,values).map{$0-$1}
            if let oldMap=previousMap,let oldResidual=previousResidual {
                let d=zip(fixedResidual,oldResidual).map{$0-$1},den=d.reduce(0){$0+$1*$1}
                if den>Double.leastNormalMagnitude {
                    let beta=zip(d,fixedResidual).reduce(0){$0+$1.0*$1.1}/den
                    let proposal=zip(mapValues,oldMap).map{$0-beta*($0-$1)}
                    if proposal.allSatisfy({$0.isFinite}) {
                        var trialN=nextN,trialT=nextT
                        for j in constraints.indices {
                            trialN[j]=max(0,proposal[4*j])
                            var t=V(proposal[4*j+1],proposal[4*j+2],proposal[4*j+3])
                            t-=normals[j]*dot(t,normals[j])
                            let limit=constraints[j].contact.friction*trialN[j]
                            if length(t)>limit { t*=limit/length(t) }
                            trialT[j]=t
                        }
                        if mapped(trialN,trialT).2<mapped(nextN,nextT).2 {nextN=trialN;nextT=trialT}
                    }
                }
            }
            // Probe feasible load-transfer endpoints; the original complementarity
            // residual remains the acceptance criterion for every candidate.
            var bestResidual=mapped(nextN,nextT).2
            for i in constraints.indices where nextN[i]>0 {
                for j in constraints.indices where j != i && active[j] &&
                    constraints[i].contact.a == constraints[j].contact.a &&
                    constraints[i].contact.b == constraints[j].contact.b {
                    var trialN=nextN,trialT=nextT
                    let force=normals[i]*nextN[i]+nextT[i]+normals[j]*nextN[j]+nextT[j]
                    trialN[i]=0;trialT[i] = .zero
                    trialN[j]=max(0,dot(force,normals[j]))
                    var tangent=force-normals[j]*dot(force,normals[j])
                    let limit=constraints[j].contact.friction*trialN[j]
                    if length(tangent)>limit { tangent*=limit/length(tangent) }
                    trialT[j]=tangent
                    let candidateResidual=mapped(trialN,trialT).2
                    if candidateResidual<bestResidual {
                        nextN=trialN;nextT=trialT;bestResidual=candidateResidual
                    }
                }
            }
            previousMap=mapValues;previousResidual=fixedResidual
            normalForce=nextN;tangentForce=nextT
        }

        #if DEBUG
        print("[W06 force convergence] residual=\(residual) duration=\(String(describing:duration)) motions=\(motions) external=\(external) constraints=\(constraints)")
        print("[W07 force operand scale] external=\(externalScale) slipRate=\(slipRateScale)")
        #endif
        throw CoupledFailure.convergence(residual:residual)
    }
}
