import Foundation
enum SpinPhysics { static let slidingFriction:Float=0.2 }
// Research translation of pooltool Mathavan 2010 impulse integration.
// Coordinates: right-handed X tangent, Y toward cushion, Z up.
// Step refinement deliberately matches upstream for independent parity checks.
enum ResearchMathavan {
 static func solve(_ q0:[Double], R:Double, M:Double, h:Double, e:Double, mu:Double, step:Double)->[Double] {
  let s=(h-R)/R,c=sqrt(1-s*s),ms=Double(SpinPhysics.slidingFriction)
  func angles(_ q:[Double])->(Double,Double) {
   var a=atan2(-q[1]*s+q[2]*R,q[0]+q[3]*R*s-q[4]*R*c)
   var b=atan2(q[1]+q[2]*R,q[0]-q[3]*R)
   if a<0 {a += 2*Double.pi};if b<0 {b += 2*Double.pi};return(a,b)
  }
  func next(_ q:[Double],_ dp:Double)->[Double] {
   let (a,b)=angles(q),sa=sin(a),ca=cos(a),sb=sin(b),cb=cos(b),k=s+mu*sa*c,f=5/(2*M*R)
   return [q[0]-((1/M)*(mu*ca+ms*cb*k)*dp),
           q[1]-((1/M)*(c-mu*s*sa+ms*sb*k)*dp),
           q[2]+(-f*(mu*sa+ms*sb*k)*dp),
           q[3]+(-f*(mu*ca*s-ms*cb*k)*dp),
           q[4]+(f*(mu*ca*c)*dp)]
  }
  var q=q0,work=0.0,count=0
  let dp=max(M*q[1]/5000,step)
  while q[1]>0 {
   let test=next(q,dp)
   if test[1]<=0 {
    var d=dp
    for _ in 0..<8 {d /= 2;let trial=next(q,d);if trial[1]<=0 {continue};q=trial;work += d*abs(q[1])*c}
    break
   }
   q=test;work += dp*abs(q[1])*c;count += 1;precondition(count<=50000)
  }
  let target=e*e*work,dr=max(target/5000,step)
  work=0;count=0
  while work<target {
   let dw=dr*abs(q[1])*c
   if work+dw>target {q=next(q,(target-work)/(abs(q[1])*c));break}
   q=next(q,dr);work += dr*abs(q[1])*c;count += 1;precondition(count<=50000)
  }
  return q
 }
}

let data=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))
let rows=try JSONSerialization.jsonObject(with:data) as! [[String:Any]]
let output=rows.map { row -> [Double] in ResearchMathavan.solve(row["input"] as! [Double],R:Double(Float(0.028575)),M:Double(Float(0.17)),h:Double(Float(0.037)),e:0.85,mu:0.2,step:Double(CommandLine.arguments[2])!) }
print(String(data:try JSONSerialization.data(withJSONObject:output),encoding:.utf8)!)
