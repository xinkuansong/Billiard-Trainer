import SceneKit
import simd

/// Business recovery after the complete physical shot. Never changes a path or pot verdict.
enum SpatialPracticeRecovery {
    typealias Record = SpatialPracticeRecord
    struct Event: Codable, Equatable {
        let key:String
        let reason:String
        let destination:Record.Pose?
    }
    struct Result {
        let board:[String:Record.Pose]
        let events:[Event]
    }
    static func recover(_ after:[String:Record.Pose],before:[String:Record.Pose])->Result {
        var board=after,events:[Event]=[]
        for key in after.keys.sorted() where !PositionPlayBall.isCue(key) {
            guard let pose=after[key],["outside","escaped"].contains(pose.disposition) else { continue }
            board.removeValue(forKey:key)
            events.append(.init(key:key,reason:pose.disposition,destination:nil))
        }
        let cue=PositionPlayBall.cueKey
        if let pose=after[cue],pose.disposition != "bed" {
            board.removeValue(forKey:cue)
            let preferred=before[cue]?.position.scene ?? SCNVector3(-0.65,BTTablePhysics.surfaceY+BallPhysics.radius,0)
            let destination=nearestLegalPoint(to:preferred,board:board).map {
                Record.Pose(position:.init($0),rotation:before[cue]?.rotation ?? [0,0,0,1],disposition:"bed")
            }
            board[cue]=destination
            events.append(.init(key:cue,reason:pose.disposition,destination:destination))
        }
        return .init(board:board,events:events)
    }

    private struct Circle { let center:SIMD2<Double>;var radius:Double }
    private static func circles(_ board:[String:Record.Pose])->[Circle] {
        let radius=Double(BallPhysics.radius)
        return board.keys.sorted().compactMap { key -> Circle? in
            guard let pose=board[key],pose.disposition == "bed",!PositionPlayBall.isCue(key) else { return nil }
            return .init(center:.init(Double(pose.position.x),Double(pose.position.z)),radius:2*radius+0.0001)
        } + AngleSceneCalculator.pocketPositions(surfaceY:BTTablePhysics.surfaceY).map {
            Circle(center:.init(Double($0.x),Double($0.z)),radius:2*radius+0.005)
        }
    }
    static func isLegal(_ position:SCNVector3,board:[String:Record.Pose])->Bool {
        let p=SIMD2(Double(position.x),Double(position.z))
        let x=Double(TablePhysics.innerLength/2-BallPhysics.radius),z=Double(TablePhysics.innerWidth/2-BallPhysics.radius)
        return p.x.isFinite && p.y.isFinite && abs(p.x)<=x && abs(p.y)<=z &&
            circles(board).allSatisfy { simd_length_squared(p-$0.center)>=$0.radius*$0.radius }
    }

    /// The nearest feasible point lies at the preferred point, a boundary projection,
    /// or a boundary intersection. Enumerating those covers the rectangle minus the
    /// union of ball/pocket exclusion circles; unlike a grid, narrow gaps are retained.
    /// Candidate circles include a Float round-trip guard; the legal predicate does not relax.
    static func nearestLegalPoint(to preferred:SCNVector3,board:[String:Record.Pose])->SCNVector3? {
        let y=BTTablePhysics.surfaceY+BallPhysics.radius
        if isLegal(preferred,board:board) { return SCNVector3(preferred.x,y,preferred.z) }
        guard preferred.x.isFinite,preferred.z.isFinite else { return nil }
        let p=SIMD2(Double(preferred.x),Double(preferred.z))
        let x=Double((TablePhysics.innerLength/2-BallPhysics.radius).nextDown)
        let z=Double((TablePhysics.innerWidth/2-BallPhysics.radius).nextDown)
        let roundTrip=Double(Float.ulpOfOne*max(1,TablePhysics.innerLength)*8)
        let circles=circles(board).map { Circle(center:$0.center,radius:$0.radius+roundTrip) }
        var candidates=[SIMD2(max(-x,min(x,p.x)),max(-z,min(z,p.y)))]
        for a in [-x,x] { for b in [-z,z] { candidates.append(.init(a,b)) } }
        for (i,c) in circles.enumerated() {
            let delta=p-c.center,d=simd_length(delta)
            if d>0 { candidates.append(c.center+delta*(c.radius/d)) }
            else { for direction in [SIMD2<Double>(1,0),.init(-1,0),.init(0,1),.init(0,-1)] {
                candidates.append(c.center+direction*c.radius)
            } }
            for edge in [-x,x] {
                let q=c.radius*c.radius-pow(edge-c.center.x,2)
                if q>=0 { let h=sqrt(q);candidates.append(.init(edge,c.center.y+h));candidates.append(.init(edge,c.center.y-h)) }
            }
            for edge in [-z,z] {
                let q=c.radius*c.radius-pow(edge-c.center.y,2)
                if q>=0 { let h=sqrt(q);candidates.append(.init(c.center.x+h,edge));candidates.append(.init(c.center.x-h,edge)) }
            }
            for other in circles.prefix(i) {
                let delta=other.center-c.center,d=simd_length(delta)
                guard d>0,d<=c.radius+other.radius,d>=abs(c.radius-other.radius) else { continue }
                let a=(c.radius*c.radius-other.radius*other.radius+d*d)/(2*d)
                let h=sqrt(max(0,c.radius*c.radius-a*a)),axis=delta/d
                let center=c.center+axis*a,offset=SIMD2(-axis.y,axis.x)*h
                candidates.append(center+offset);candidates.append(center-offset)
            }
        }
        return candidates.compactMap { candidate -> SCNVector3? in
            let point=SCNVector3(Float(candidate.x),y,Float(candidate.y))
            return isLegal(point,board:board) ? point:nil
        }.min { a,b in
            let pa=SIMD2(Double(a.x),Double(a.z)),pb=SIMD2(Double(b.x),Double(b.z))
            let da=simd_length_squared(pa-p),db=simd_length_squared(pb-p)
            return da==db ? (a.x==b.x ? a.z<b.z:a.x<b.x):da<db
        }
    }
}
