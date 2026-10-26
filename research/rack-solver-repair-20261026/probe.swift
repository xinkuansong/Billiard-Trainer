func repairProbe()->[String:Any] {
 InvarianceTrace.mode=2
 func w(_ v:SCNVector3)->Double{Double(v.x)*Double(v.x)+Double(v.y)*Double(v.y)+Double(v.z)*Double(v.z)}
 func mirrorV(_ v:SCNVector3)->SCNVector3{SCNVector3(v.x,v.y,-v.z)}
 func mirrorW(_ v:SCNVector3)->SCNVector3{SCNVector3(-v.x,-v.y,v.z)}
 var maxEnergyIncrease=0.0,maxOldDelta:Float=0
 for i in 1...300 {
  let theta=Float(i)*0.213,n=SCNVector3(cosf(theta),0,sinf(theta)),t=SCNVector3(-n.z,0,n.x)
  let a=SCNVector3(0.3,0.85,0.1),b=a+n*(2*BallPhysics.radius)
  let va=n*Float(2+i%17)+t*Float(i%5),vb=t*Float(i%3)
  let wa=SCNVector3(Float(i%7)*3,Float(i%13)*5,Float(i%11)*2),wb=SCNVector3(Float(i%5)*7,-Float(i%17)*2,Float(i%3)*11)
  let q=CollisionResolver.resolveBallBallPure(posA:a,posB:b,velA:va,velB:vb,angVelA:wa,angVelB:wb)
  let rev=CollisionResolver.resolveBallBallPure(posA:b,posB:a,velA:vb,velB:va,angVelA:wb,angVelB:wa)
  precondition((q.velA-rev.velB).length()==0 && (q.velB-rev.velA).length()==0)
  precondition((q.angVelA-rev.angVelB).length()==0 && (q.angVelB-rev.angVelA).length()==0)
  let m=CollisionResolver.resolveBallBallPure(posA:mirrorV(a),posB:mirrorV(b),velA:mirrorV(va),velB:mirrorV(vb),angVelA:mirrorW(wa),angVelB:mirrorW(wb))
  precondition((mirrorV(q.velA)-m.velA).length()==0 && (mirrorW(q.angVelA)-m.angVelA).length()==0)
  let R=Double(BallPhysics.radius),before=w(va)+w(vb)+0.4*R*R*(w(wa)+w(wb)),after=w(q.velA)+w(q.velB)+0.4*R*R*(w(q.angVelA)+w(q.angVelB))
  maxEnergyIncrease=max(maxEnergyIncrease,(after-before)/before);precondition(after<=before*(1+1e-6))
  InvarianceTrace.mode=0
  let old=CollisionResolver.resolveBallBallPure(posA:a,posB:b,velA:va,velB:vb,angVelA:wa,angVelB:wb)
  maxOldDelta=max(maxOldDelta,(old.velA-q.velA).length(),(old.velB-q.velB).length())
  InvarianceTrace.mode=2
 }
 let R=BallPhysics.radius,a=BallState(position:SCNVector3(0,0,0),velocity:SCNVector3(5,0,0),angularVelocity:SCNVector3Zero,state:.sliding,name:"a")
 let b=BallState(position:SCNVector3(2*R+0.0002,0,0),velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,state:.stationary,name:"b")
 precondition(!EngineNumerics.isBallPairOverlappingOrTouching(a,b))
 let time=CollisionDetector.ballBallCollisionTime(p1:a.position,p2:b.position,v1:a.velocity,v2:b.velocity,a1:SCNVector3Zero,a2:SCNVector3Zero,R:Double(R),maxTime:1)!
 let expected=(Double(b.position.x)-2*Double(R))/5
 precondition(abs(Double(time)-expected)<1e-10)
 precondition(CollisionDetector.ballBallCollisionTime(p1:a.position,p2:b.position,v1:SCNVector3(-5,0,0),v2:b.velocity,a1:SCNVector3Zero,a2:SCNVector3Zero,R:Double(R),maxTime:1)==nil)
 InvarianceTrace.mode=0
 return ["pairCases":300,"exchangeExact":true,"reflectionExact":true,"maxEnergyIncrease":maxEnergyIncrease,"maxLegacyVelocityDelta":Double(maxOldDelta),"gapTimeActual":Double(time),"gapTimeExpected":expected,"separatingPairHasNoImpact":true]
}
