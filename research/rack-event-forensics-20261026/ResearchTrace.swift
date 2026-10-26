import Foundation
import SceneKit
import simd

enum ResearchTrace {
    static var rows:[[String:Any]]=[]
    static var first:Float?=nil
    static func reset(){rows=[];first=nil}
    static func active(_ t:Float)->Bool { t <= (first ?? 0.1)+0.020001 }
    static func v(_ x:SCNVector3)->[Double]{[Double(x.x),Double(x.y),Double(x.z)]}
    static func d(_ x:SCNVector3)->SIMD3<Double>{SIMD3(Double(x.x),Double(x.y),Double(x.z))}
    static func state(_ b:BallState)->[String:Any]{["name":b.name,"p":v(b.position),"v":v(b.velocity),"w":v(b.angularVelocity),"state":b.state.rawValue,"accel":v(EngineNumerics.acceleration(for:b))]}
    static func pair(_ phase:String,a:BallState,b:BallState,now:Float){
        if first == nil {first=now}
        guard active(now) else{return}
        let dp=d(b.position)-d(a.position),dv=d(b.velocity)-d(a.velocity)
        var row:[String:Any]=["phase":phase,"now":Double(now),"a":state(a),"b":state(b),"gap":simd_length(dp)-2*Double(BallPhysics.radius),"approach":-dot(dp,dv)/simd_length(dp)]
        if phase == "beforeImpulse" {
            let x=CollisionResolver.resolveBallBallPure(posA:a.position,posB:b.position,velA:a.velocity,velB:b.velocity,angVelA:a.angularVelocity,angVelB:b.angularVelocity)
            let y=CollisionResolver.resolveBallBallPure(posA:b.position,posB:a.position,velA:b.velocity,velB:a.velocity,angVelA:b.angularVelocity,angVelB:a.angularVelocity)
            row["swapVelocityDelta"] = max(Double((x.velA-y.velB).length()),Double((x.velB-y.velA).length()))
            row["swapSpinDelta"] = max(Double((x.angVelA-y.angVelB).length()),Double((x.angVelB-y.angVelA).length()))
        }
        rows.append(row)
    }
    static func candidate(_ source:String,a:BallState,b:BallState,dt:Float,now:Float,horizon:Float){
        guard active(now) else{return}
        let dp=d(a.position)-d(b.position),dv=d(a.velocity)-d(b.velocity),da=d(EngineNumerics.acceleration(for:a))-d(EngineNumerics.acceleration(for:b))
        let coeff=[dot(da,da)/4,dot(da,dv),dot(dv,dv)+dot(da,dp),2*dot(dv,dp),dot(dp,dp)-4*pow(Double(BallPhysics.radius),2)]
        let t=Double(dt);let pos=dp+dv*t+da*(0.5*t*t),vel=dv+da*t
        var row:[String:Any]=["phase":"candidate","source":source,"now":Double(now),"dt":t,"horizon":Double(horizon),"a":state(a),"b":state(b),"coefficients":coeff,"predictedGap":simd_length(pos)-2*Double(BallPhysics.radius),"predictedApproach":-dot(pos,vel)/simd_length(pos),"polynomialResidual":coeff.reduce(0){$0*t+$1}]
        if source == "quartic" {
            row["ferrariRoots"] = QuarticSolver.solveQuartic(a:coeff[0],b:coeff[1],c:coeff[2],d:coeff[3],e:coeff[4]).filter{$0.isFinite}
            row["boundedRoots"] = QuarticSolver.boundedRealRoots(coefficients:coeff,maxTime:Double(horizon)).filter{$0.isFinite}
        }
        rows.append(row)
    }
    static func selected(_ event:PhysicsEvent?,now:Float){
        guard active(now) else{return}
        var row:[String:Any]=["phase":"selected","now":Double(now)]
        if let e=event {
            row["dt"]=Double(e.time);row["priority"]=e.priority
            switch e.type {
            case .ballBall(let a,let b):row["kind"]="ball";row["a"]=a;row["b"]=b
            case .ballCushion(let a,_,_):row["kind"]="cushion";row["a"]=a
            case .pocket(let a,_):row["kind"]="pocket";row["a"]=a
            case .transition(let a,_,_):row["kind"]="transition";row["a"]=a
            }
        }else{row["kind"]="none"}
        rows.append(row)
    }
}
