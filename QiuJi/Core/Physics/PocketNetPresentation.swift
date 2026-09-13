//
//  PocketNetPresentation.swift
//  QiuJi
//
//  W17-B/D (v63, DR-294): presentation-only descent of a planar-potted ball into the
//  pocket net, ending at a deterministic resting slot. The pot verdict is the planar
//  drop-circle rule (DR-293); nothing here feeds back into physics or scoring.
//
//  Coordinate contract: SceneKit world, X–Z horizontal, Y up, metres. Pocket centres and
//  drop radii come from `TableGeometry.pockets` (TablePhysics constants); the net profile
//  below was measured from the bundled USDZ bag envelope (`PocketGeometryAsset`) at
//  surfaceY = 0.8 (probe 2026-09-14) and is verified against it by
//  `PocketNetPresentationTests.testProfileMatchesBundledBagEnvelope`.
//

import Foundation
import SceneKit

/// Net (bag) profile used for the scripted descent. Depths are metres below the cloth
/// surface; radii are envelope (inner wall) radii, so the ball-centre reach is `r - R`.
struct PocketNetProfile {
    struct Ring {
        /// Depth below `surfaceY`.
        let depth:Double
        /// Bag axis offset from the planar pocket centre along the mirror-consistent
        /// inward axes: `dx` along −sign(centre.x)·X, `dz` along −sign(centre.z)·Z
        /// (both point toward the table centre). Corner bags lean inward with depth;
        /// middle bags flare outward (negative `dz`) at the mouth.
        let dx:Double
        let dz:Double
        /// Mean envelope radius at this depth.
        let radius:Double
    }
    let rings:[Ring]
    /// Depth of the resting ball centre for the lowest slot.
    let restingDepth:Double
    /// Depth of the net mouth (top ring). Above it the slate hole is modelled as a
    /// cylinder of the planar drop radius around the pocket centre.
    var mouthDepth:Double { rings[0].depth }

    /// Corner pockets (asset probe: top 0.760, bottom 0.66874, resting centre 0.69731).
    static let corner=PocketNetProfile(rings:[
        Ring(depth:0.0400,dx:0.0069,dz:0.0039,radius:0.0565),
        Ring(depth:0.0700,dx:0.0082,dz:0.0049,radius:0.0494),
        Ring(depth:0.1000,dx:0.0132,dz:0.0031,radius:0.0400),
        Ring(depth:0.1225,dx:0.0164,dz:0.0000,radius:0.0330)
    ],restingDepth:0.10269)
    /// Middle pockets (asset probe: bottom 0.66802, resting centre 0.69660).
    static let middle=PocketNetProfile(rings:[
        Ring(depth:0.0400,dx:0,dz:-0.0149,radius:0.0579),
        Ring(depth:0.0700,dx:0,dz:-0.0050,radius:0.0507),
        Ring(depth:0.1000,dx:0,dz: 0.0006,radius:0.0403),
        Ring(depth:0.1225,dx:0,dz:-0.0011,radius:0.0335)
    ],restingDepth:0.10340)

    static func forPocket(isCorner:Bool)->PocketNetProfile { isCorner ? corner : middle }

    /// Linear interpolation at `depth`, clamped to the first/last ring.
    func ring(atDepth depth:Double)->Ring {
        if depth<=rings[0].depth { return rings[0] }
        if depth>=rings[rings.count-1].depth { return rings[rings.count-1] }
        var i=0
        while i+1<rings.count-1 && rings[i+1].depth<depth { i+=1 }
        let a=rings[i],b=rings[i+1]
        let u=(depth-a.depth)/(b.depth-a.depth)
        return Ring(depth:depth,dx:a.dx+(b.dx-a.dx)*u,dz:a.dz+(b.dz-a.dz)*u,radius:a.radius+(b.radius-a.radius)*u)
    }
}

/// Builds and attaches the scripted net descent for every planar pot in a recorder.
enum PocketNetPresentation {
    typealias V=SIMD3<Double>
    typealias State=LocalPocketSimulation.State

    /// Fixed presentation step. 240 Hz keeps the wall projection error far below a pixel
    /// at any playback speed while a 1.5 s descent stays under 400 samples.
    static let sampleStep:Double=1/240
    /// Hard cap on the scripted fall; a ball not resting by then is eased to its slot.
    static let maxDescentDuration:Double=1.5
    /// Eased settle onto the exact slot after the scripted wall/floor contact.
    static let settleDuration:Double=0.12
    /// Slots per net before the oldest ball is recycled (FIFO). The bundled bag is
    /// ~0.09 m deep (3.2 R): two balls fit, the second already protruding into the hole.
    static let netCapacity=2
    /// Horizontal lean of the upper slot from the lower one, toward the net mouth axis.
    static let upperSlotLean:Double=0.018

    struct NetPocket {
        let id:String
        let center:V
        let dropRadius:Double
        /// Inward unit axes (toward the table centre), see `PocketNetProfile.Ring`.
        let axisX:V
        let axisZ:V
        let profile:PocketNetProfile
        init(pocket:Pocket,surfaceY:Double) {
            id=pocket.id
            center=V(Double(pocket.center.x),surfaceY,Double(pocket.center.z))
            dropRadius=Double(pocket.radius)
            profile=PocketNetProfile.forPocket(isCorner:pocket.isCorner)
            axisX=V(pocket.center.x>0 ? -1 : 1,0,0)
            axisZ=V(0,0,pocket.center.z>0 ? -1 : 1)
        }
        /// Bag axis point and ball-centre wall reach at world height `y`.
        func wall(at y:Double,ballRadius:Double)->(axis:V,reach:Double) {
            let depth=center.y-y
            let r=profile.ring(atDepth:depth)
            var axis=center+axisX*r.dx+axisZ*r.dz
            var reach=max(0.001,r.radius-ballRadius)
            if depth<profile.mouthDepth {
                // Slate hole → net mouth: a funnel from the planar drop circle (centre on the
                // pocket axis) down to the first measured ring, so the wall has no step.
                let u=max(0,depth)/profile.mouthDepth
                axis=center+(axis-center)*u
                reach=dropRadius+(reach-dropRadius)*u
            }
            return (V(axis.x,y,axis.z),reach)
        }
        /// Deterministic resting slots, lowest first. The upper ball rests on the lower
        /// one (centre distance 2R), leaning toward the mouth axis.
        func slots(ballRadius:Double)->[V] {
            let bottom=wall(at:center.y-profile.restingDepth,ballRadius:ballRadius).axis
            let mouth=wall(at:center.y-profile.mouthDepth,ballRadius:ballRadius).axis
            var dir=V(mouth.x-bottom.x,0,mouth.z-bottom.z)
            let len=length(dir)
            dir=len>1e-9 ? dir/len : axisX
            let lean=PocketNetPresentation.upperSlotLean
            let rise=sqrt(max(0,4*ballRadius*ballRadius-lean*lean))
            let upper=V(bottom.x,bottom.y+rise,bottom.z)+dir*lean
            return [bottom,upper]
        }
    }

    /// Script one ball's fall from its planar capture snapshot to `slot`.
    /// Gravity, zero-restitution liner and `TablePhysics.pocketLinerRetention` are the same
    /// constants the spatial model uses (DR-292); the geometry is the measured net profile.
    static func descent(from start:State,pocket:NetPocket,slot:V,ballRadius:Double,gravity:Double,
                        retention:Double)->[State] {
        var s=start,samples=[start]
        let dt=sampleStep
        let end=start.time+maxDescentDuration
        while s.time<end {
            var v=s.velocity,omega=s.omega,contacted=false
            v.y-=gravity*dt
            var p=s.position+v*dt
            // Floor of the slot (net bottom or the ball below): no bounce, soft grip.
            if p.y<=slot.y {
                p.y=slot.y;v.y=0
                v.x*=retention;v.z*=retention
                contacted=true
            }
            // Cylinder/cone wall: project back, kill the normal component, retain the
            // tangential fraction (soft liner, DR-292).
            let w=pocket.wall(at:p.y,ballRadius:ballRadius)
            let d=V(p.x-w.axis.x,0,p.z-w.axis.z)
            let dist=length(d)
            if dist>w.reach {
                let n=d/dist
                p.x=w.axis.x+n.x*w.reach;p.z=w.axis.z+n.z*w.reach
                let vn=dot(v,n)
                if vn>0 { v=(v-n*vn)*retention }
                contacted=true
            }
            if contacted { omega*=retention }
            s=State(time:s.time+dt,position:p,velocity:v,omega:omega)
            samples.append(s)
            if p.y<=slot.y+1e-9 && length(v)<0.02 { break }
        }
        // Eased settle onto the exact slot (position only; residual spin decays with it).
        let from=s
        let steps=max(1,Int((settleDuration/dt).rounded(.up)))
        for k in 1...steps {
            let u=Double(k)/Double(steps),e=1-(1-u)*(1-u)
            samples.append(State(time:from.time+settleDuration*u,position:from.position+(slot-from.position)*e,
                                 velocity:.zero,omega:from.omega*(1-u)))
        }
        return samples
    }

    /// Short eased move used when a resting ball slides down after a FIFO eviction.
    static func shift(from start:State,to slot:V)->[State] {
        let dt=sampleStep,steps=max(1,Int((settleDuration/dt).rounded(.up)))
        var samples=[start]
        for k in 1...steps {
            let u=Double(k)/Double(steps),e=1-(1-u)*(1-u)
            samples.append(State(time:start.time+settleDuration*u,position:start.position+(slot-start.position)*e,
                                 velocity:.zero,omega:.zero))
        }
        return samples
    }

    /// Attach net tails for every planar pocket entry that has none yet. Idempotent.
    /// Failures are printed (never swallowed) and leave the legacy fade path in place.
    static func attach(to recorder:TrajectoryRecorder) {
        let entries=recorder.pocketEntries.filter { recorder.collectionTailsByBallName[$0.ball.name]==nil }
        guard !entries.isEmpty else { return }
        let ballRadius=Double(BallPhysics.radius),gravity=Double(TablePhysics.gravity)
        let retention=Double(TablePhysics.pocketLinerRetention)
        // Every snapshot carries the planar geometry it was judged against; its pocket
        // centres sit on the cloth surface (TableGeometry.chineseEightBallQiuJi(surfaceY:)).
        // `TrajectoryPlayback.surfaceY` is the ball-centre plane and is deliberately not used.
        var pockets:[String:NetPocket]=[:]
        for entry in recorder.pocketEntries {
            for pocket in entry.geometry.pockets where pockets[pocket.id]==nil {
                pockets[pocket.id]=NetPocket(pocket:pocket,surfaceY:Double(pocket.center.y))
            }
        }
        // Planar tails already in this recorder occupy slots (FIFO order by entry time).
        var queues:[String:[(ball:String,slot:Int,time:Double)]]=[:]
        for (name,tail) in recorder.collectionTailsByBallName where tail.samples != nil && tail.fadeStart==nil {
            guard let entry=recorder.pocketEntries.last(where:{$0.ball.name==name}),let pocket=pockets[entry.pocketID] else { continue }
            let slots=pocket.slots(ballRadius:ballRadius)
            let slot=slots.indices.min { length(slots[$0]-tail.end.position)<length(slots[$1]-tail.end.position) } ?? 0
            queues[entry.pocketID,default:[]].append((name,slot,Double(entry.time)))
        }
        for pocketID in queues.keys { queues[pocketID]?.sort { $0.time<$1.time } }
        for entry in entries.sorted(by:{ $0.time<$1.time }) {
            guard let pocket=pockets[entry.pocketID] else {
                print("[W17 net presentation] unknown pocket \(entry.pocketID) for \(entry.ball.name)")
                continue
            }
            let b=entry.ball
            let start=State(time:Double(entry.time),
                            position:V(Double(b.position.x),pocket.center.y+ballRadius,Double(b.position.z)),
                            velocity:V(Double(b.velocity.x),0,Double(b.velocity.z)),
                            omega:V(Double(b.angularVelocity.x),Double(b.angularVelocity.y),Double(b.angularVelocity.z)))
            let slots=pocket.slots(ballRadius:ballRadius)
            var queue=queues[entry.pocketID] ?? []
            do {
                if queue.count>=netCapacity {
                    // FIFO: the oldest ball is recycled the moment the new one starts falling;
                    // everyone above it slides down one slot.
                    let evicted=queue.removeFirst()
                    if let old=recorder.collectionTailsByBallName[evicted.ball],let samples=old.samples {
                        try recorder.recordPlanarCollectionTail(ballName:evicted.ball,
                            tail:PocketCollectionTail(samples:samples,gravity:gravity,fadeStart:start.time))
                    }
                    for i in queue.indices where queue[i].slot>0 {
                        let name=queue[i].ball
                        guard let old=recorder.collectionTailsByBallName[name],var samples=old.samples else { continue }
                        var from=old.end
                        from.time=max(old.end.time,start.time)
                        if from.time>old.end.time { samples.append(from) }
                        samples.append(contentsOf:shift(from:from,to:slots[queue[i].slot-1]).dropFirst())
                        try recorder.recordPlanarCollectionTail(ballName:name,tail:PocketCollectionTail(samples:samples,gravity:gravity))
                        queue[i].slot-=1
                    }
                }
                let slotIndex=min(queue.count,slots.count-1)
                let samples=descent(from:start,pocket:pocket,slot:slots[slotIndex],ballRadius:ballRadius,gravity:gravity,retention:retention)
                try recorder.recordPlanarCollectionTail(ballName:b.name,tail:PocketCollectionTail(samples:samples,gravity:gravity))
                queue.append((b.name,slotIndex,start.time))
                queues[entry.pocketID]=queue
            } catch {
                print("[W17 net presentation] failed for \(b.name) in \(entry.pocketID): \(error)")
            }
        }
    }
}
