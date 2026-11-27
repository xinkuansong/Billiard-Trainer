import Foundation
import SceneKit
struct SourceRegion: Codable { let id:String; let target:[Double]; let blockers:[[Double]]; let kind:String }

/// Exact maximum over the existing 50x25 candidate centres, using valid production
/// attack witnesses to skip cells that provably cannot beat an already scored cell.
/// This is not a continuous-space maximum or a shot-reachability certificate.
func filterRegion(_ input:SourceRegion, prune:Bool=true) throws -> [String:Any] {
    typealias P=DefenseAttackAssessment.P
    let start=ProcessInfo.processInfo.systemUptime
    var geometry=DefenseAttackAssessment()
    let target=P(input.target),blockers=input.blockers.map(P.init)
    var directions=[Double]()
    var witnesses=[(Int,Double,Double)]() // pocket, absolute angle, full pipe width
    for i in 0..<6 {
        let w=geometry.window(target,i),base=w["baseRadians"] as! Double
        for range in w["intervals"] as! [[String:Any]] {
            let left=range["leftDegrees"] as! Double,right=range["rightDegrees"] as! Double
            guard right>left else {continue}
            let count=max(2,Int(ceil((right-left)/0.01)))
            // These exact same indices occur in production pipeAttack.
            for j in Set([0,count/2,count]).sorted() {
                witnesses.append((i,base+(left+(right-left)*Double(j)/Double(count)) * .pi/180,right-left))
            }
        }
        directions.append(base)
    }
    let r=geometry.rad,hx=geometry.hx-r,hz=geometry.hz-r,nx=50,nz=25
    let dx=2*hx/Double(nx),dz=2*hz/Double(nz)
    func point(_ v:SCNVector3)->P{P(Double(v.x),Double(v.z))}
    let rails=geometry.mainRails
    func valid(_ p:P)->Bool {
        guard (p-target).length>=0.30,blockers.allSatisfy({(p-$0).length>=2*r+1e-5}),
              !geometry.table.pockets.contains(where:{$0.containsCapture(p.scn)}) else{return false}
        for line in geometry.table.linearCushions {if geometry.dist(p,point(line.start),point(line.end))<r{return false}}
        for arc in geometry.table.circularCushions {
            let c=point(arc.center),rr=Double(arc.radius),a=atan2(p.z-c.z,p.x-c.x)
            var d=min((p-(c+P(cos(Double(arc.startAngle)),sin(Double(arc.startAngle)))*rr)).length,
                      (p-(c+P(cos(Double(arc.endAngle)),sin(Double(arc.endAngle)))*rr)).length)
            if arc.isAngleInRange(Float(a)){d=min(d,abs((p-c).length-rr))};if d<r{return false}
        };return true
    }
    // Visit boundary centres first, a search ordering only; every remaining centre
    // is either evaluated or has an actual lower-defense attack witness.
    let indices=(0..<(nx*nz)).sorted { a,b in
        func ring(_ k:Int)->Int {min(k%nx,nx-1-k%nx,k/nx,nz-1-k/nx)}
        return ring(a)==ring(b) ? a<b:ring(a)<ring(b)
    }
    var maximum = -1.0, best:P?, bestEffect:DefenseEffect?
    var validCells=0,prunedCells=0,fullCells=0,visited=0,upperBoundReached=false
    for k in indices {
        try Task.checkCancellation();visited+=1
        let p=point(P(-hx+(Double(k%nx)+0.5)*dx,-hz+(Double(k/nx)+0.5)*dz).scn)
        guard valid(p) else{continue};validCells+=1
        var cannotImprove=false
        if prune && maximum>=0 {
            // Thin-cut routes are unlikely to disprove defensive potential; try
            // straight attack directions first, without dropping any candidate.
            let incoming=target-p
            let ordered=witnesses.sorted { a,b in
                incoming.dot(P(cos(a.1),sin(a.1)))>incoming.dot(P(cos(b.1),sin(b.1)))
            }
            for (pocket,angle,width) in ordered {
                let reach=DefenseAttackAssessment.PipeReachability(cue:p,ball:target,obstacles:blockers,pocket:geometry.table.pockets[pocket],rails:rails)
                guard let end=reach.reachableEnd(angle),let comfort=ShotComfortScore.evaluate(cue:(p.x,p.z),ball:(target.x,target.z),aim:(end.x,end.z)) else{continue}
                let cut=DefenseAttackAssessment.cutDegrees(cue:p,ball:target,aim:end)
                let score=DefenseEffect.value(pipeDegrees:width,comfort:comfort.total,cutDegrees:cut)!
                if score<=maximum {cannotImprove=true;break}
            }
        }
        if cannotImprove {prunedCells+=1;continue}
        let e=try DefenseEffect.regionState(cue:p.scn,target:target.scn,blockers:blockers.map(\.scn),windows:geometry)
        guard let s=e.score,s.isFinite,(0...100).contains(s),e.unavailableReason==nil else{throw NSError(domain:"invalid-region-score",code:1)}
        fullCells+=1
        if s>maximum {maximum=s;best=p;bestEffect=e}
        if prune && maximum==100 {upperBoundReached=true;break}
    }
    var out:[String:Any]=["id":input.id,"kind":input.kind,"target":input.target,"blockers":input.blockers,
        "scoringVersion":DefenseEffect.version,"maximumSampled":maximum,"grid":[nx,nz],"spacing":[dx,dz],
        "visited":visited,"validVisited":validCells,"fullEvaluations":fullCells,"pruned":prunedCells,
        "reachedGlobalUpperBound":upperBoundReached,"seconds":ProcessInfo.processInfo.systemUptime-start,
        "thresholds":[70,75,80,85,90,95].filter{maximum>=Double($0)}]
    if let best,let bestEffect {
        out["bestCue"]=best.json
        out["effect"]=try JSONSerialization.jsonObject(with:JSONEncoder().encode(bestEffect))
        out["estimatedMaximum"]=bestEffect.estimateReason != nil || bestEffect.pipeRoute?.zeroWidthEstimate == true
    }
    return out
}
