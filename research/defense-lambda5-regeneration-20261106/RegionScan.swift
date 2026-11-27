import Foundation
import SceneKit
// 50 x 25 centres (~5 cm), advisory search guidance only; never a continuous maximum proof.
func defenseScan(_ q:DefenseBankQuestion)throws->[String:Any] {
    typealias P=DefenseAttackAssessment.P
    var geometry=DefenseAttackAssessment()
    let enemy=q.balls.first{$0.number==q.opponentBallNumber}!.position
    let target=P(enemy),blockers=q.balls.filter{$0.number != q.ownBallNumber && $0.number != q.opponentBallNumber}.map{P($0.position)}
    // Scoring consumes the Float scene coordinate; warm the exact same cache key.
    let sceneTarget=target.scn
    let windowTarget=P(Double(sceneTarget.x),Double(sceneTarget.z))
    for i in 0..<6 {_=geometry.window(windowTarget,i)}
    let r=geometry.rad,hx=geometry.hx-r,hz=geometry.hz-r,nx=50,nz=25
    let dx=2*hx/Double(nx),dz=2*hz/Double(nz)
    func point(_ v:SCNVector3)->P{P(Double(v.x),Double(v.z))}
    func valid(_ p:P)->Bool {
        guard (p-target).length>=0.30,blockers.allSatisfy({(p-$0).length>=2*r+1e-5}),!geometry.table.pockets.contains(where:{$0.containsCapture(p.scn)}) else{return false}
        for line in geometry.table.linearCushions {if geometry.dist(p,point(line.start),point(line.end))<r{return false}}
        for arc in geometry.table.circularCushions {
            let c=point(arc.center),rr=Double(arc.radius),a=atan2(p.z-c.z,p.x-c.x)
            var d=min((p-(c+P(cos(Double(arc.startAngle)),sin(Double(arc.startAngle)))*rr)).length,(p-(c+P(cos(Double(arc.endAngle)),sin(Double(arc.endAngle)))*rr)).length)
            if arc.isAngleInRange(Float(a)){d=min(d,abs((p-c).length-rr))};if d<r{return false}
        };return true
    }
    var rows=[[String:Any]](),maximum:Double = -1
    for z in 0..<nz {for x in 0..<nx {
        let x0 = -hx+Double(x)*dx,z0 = -hz+Double(z)*dz,p=point(P(x0+dx/2,z0+dz/2).scn)
        var row:[String:Any] = ["bounds":[x0,z0,x0+dx,z0+dz],"x":p.x,"z":p.z]
        if valid(p) {
            let effect=try DefenseEffect.regionState(cue:p.scn,target:target.scn,blockers:blockers.map{$0.scn},windows:geometry,opponent:q.opponentBallNumber)
            guard let s=effect.score,s.isFinite,(0...100).contains(s),effect.unavailableReason==nil else{throw NSError(domain:"invalid-map-score",code:1)}
            row["score"]=s;maximum=max(maximum,s)
        };rows.append(row)
    }}
    return ["target":enemy,"rows":rows,"maximumSampled":maximum,"has85Region":maximum>=85,"grid":[nx,nz],"spacing":[dx,dz],"radius":r,"scope":"Sampled potential with static blockers only. No layout rejection; dynamic own-ball blocking searched independently."]
}
