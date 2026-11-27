// Research-only extension appended to the frozen production calculator. XZ metres.
extension AngleSceneCalculator {
    // Analytic segment-to-arc minimum; retain the production arc domain predicate.
    private static func windowArcDistance(_ a: Vector2, _ b: Vector2, _ arc: ArcSeg) -> Float {
        var best = min(pointToArc(a, arc), pointToArc(b, arc))
        for angle in [arc.angA, arc.angB] {
            let p = arc.center + Vector2(cosf(angle), sinf(angle)) * arc.radius
            best = min(best, pointSegmentDistance(p, Segment2D(a:a,b:b)))
        }
        let v=b-a, w=a-arc.center, vv=v.dot(v)
        if vv <= 1e-12 { return best }
        let t = -w.dot(v)/vv
        let q=a+v*t, n=q-arc.center
        if t >= 0 && t <= 1 && n.length > 1e-9 {
            for sign: Float in [-1,1] {
                let p=arc.center+n*(sign*arc.radius/n.length)
                let angle=atan2f(p.z-arc.center.z,p.x-arc.center.x)
                if arcContainsAngle(arc,angle) { best=min(best,pointSegmentDistance(p,Segment2D(a:a,b:b))) }
            }
        }
        let wb=w.dot(v), disc=wb*wb-vv*(w.dot(w)-arc.radius*arc.radius)
        if disc >= 0 {
            for root in [(-wb-sqrtf(disc))/vv,(-wb+sqrtf(disc))/vv] where root >= 0 && root <= 1 {
                let p=a+v*root-arc.center
                if arcContainsAngle(arc,atan2f(p.z,p.x)) { return 0 }
            }
        }
        return best
    }
    static func researchWindow(_ target: SCNVector3, pocketIndex: Int, stepDegrees: Double) -> [String:Any] {
        let pc=pocketPositions(surfaceY:0)[pocketIndex]
        let g=buildPipeGeometry(pocketIndex:pocketIndex,pocketCenter:Vector2(pc.x,pc.z))
        let origin=Vector2(target.x,target.z)
        let base=atan2(Double(pc.z-target.z),Double(pc.x-target.x))
        func delta(_ p:Vector2)->Double { let x=atan2(Double(p.z-origin.z),Double(p.x-origin.x))-base;return atan2(sin(x),cos(x))*180/Double.pi }
        let ends=[delta(g.mouth.mouthA),delta(g.mouth.mouthB)]
        var lo=ends.min()!-5, hi=ends.max()!+5
        func detail(_ angle:Double)->(Bool,Vector2,Float,Float) {
            let a=base+angle*Double.pi/180,dir=Vector2(Float(cos(a)),Float(sin(a)))
            // Unlike a solver seed, a clean window must actually enter this pocket.
            guard let d=g.capture.entryTime(position:SCNVector3(origin.x,0,origin.z),velocity:SCNVector3(dir.x,0,dir.z),acceleration:SCNVector3Zero,maxTime:4) else { return (false,origin,0,0) }
            let end=origin+dir*d
            let rail=ordinaryClearance(origin:origin,end:end,dir:dir,obstacles:g.ordinaryObstacles,clearance:ballRadius)
            let exact=g.mouth.compositeJaws.map { min(windowArcDistance(origin,end,$0.arc),segmentDistance(origin,end,$0.line.a,$0.line.b)) }.min()!
            let raw=cleanPipeMargin(origin:origin,aim:origin+dir*4,geometry:g,clearance:ballRadius) != nil
            return (rail.safe && exact+pipeRoundoff>=ballRadius,end,exact,raw ? 1:0)
        }
        // Near-mouth capture can precede the throat chord. Expand live endpoints
        // instead of clipping a valid window to a fixed throat-based search span.
        while detail(lo).0 && lo > -180 { lo=max(-180,lo-5) }
        while detail(hi).0 && hi < 180 { hi=min(180,hi+5) }
        let count=Int(ceil((hi-lo)/stepDegrees)), step=(hi-lo)/Double(count)
        var ranges=[[Double]](), start:Double?=nil
        var previous=false
        func refine(_ a:Double,_ b:Double,_ leftState:Bool)->Double {
            var l=a,r=b
            for _ in 0..<24 { let m=(l+r)/2;if detail(m).0==leftState {l=m}else{r=m} }
            return (l+r)/2
        }
        for i in 0...count {
            let angle=lo+Double(i)*step, state=detail(angle).0
            if state && !previous {start=i==0 ? angle:refine(angle-step,angle,false)}
            if !state && previous {ranges.append([start!,refine(angle-step,angle,true)]);start=nil}
            previous=state
        }
        if previous {ranges.append([start!,hi])}
        // Explicit seed catches an exactly tangent / sub-grid parallel direction.
        var isolated=[Double]()
        for a in [0.0,90.0,180.0,-90.0] {
            let x=a-base*180/Double.pi, d=atan2(sin(x*Double.pi/180),cos(x*Double.pi/180))*180/Double.pi
            if d>=lo && d<=hi && detail(d).0 && !ranges.contains(where: {d >= $0[0] && d <= $0[1]}) { isolated.append(d) }
        }
        func pt(_ p:Vector2)->[Double] {[Double(p.x),Double(p.z)]}
        let intervals:[[String:Any]]=ranges.map { r in
            let width=r[1]-r[0], mid=(r[0]+r[1])/2
            return ["leftDegrees":r[0],"rightDegrees":r[1],"widthDegrees":width,"leftEnd":pt(detail(r[0]+min(0.0001,width/10)).1),"rightEnd":pt(detail(r[1]-min(0.0001,width/10)).1),"midEnd":pt(detail(mid).1),"midDegrees":mid]
        }
        let geom:[String:Any]=["mouthA":pt(g.mouth.mouthA),"mouthB":pt(g.mouth.mouthB),"center":pt(g.mouth.center),"jaws":g.mouth.compositeJaws.map { ["center":pt($0.arc.center),"radius":Double($0.arc.radius),"angleA":Double($0.arc.angA),"angleB":Double($0.arc.angB),"lineA":pt($0.line.a),"lineB":pt($0.line.b)] as [String:Any] },"rails":mainCushionSegments.map { ["a":pt($0.a),"b":pt($0.b)] }]
        return ["pocket":pocketIndex,"target":[Double(target.x),Double(target.z)],"baseRadians":base,"intervals":intervals,"isolatedDirections":isolated,"totalWidthDegrees":ranges.reduce(0){$0+$1[1]-$1[0]},"stepDegrees":step,"scanBounds":[lo,hi],"edgeStates":[detail(lo).0,detail(hi).0],"geometry":geom]
    }
}
