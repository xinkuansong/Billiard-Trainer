//
//  TrajectoryRecorder.swift
//  BilliardTrainer
//
//  轨迹记录与回放
//

import SceneKit

struct BallFrame {
    let time: Float
    let position: SCNVector3
    let velocity: SCNVector3
    let angularVelocity: SCNVector4
    let state: BallMotionState
}

/// Immutable state before the legacy capture path snaps/clears the ball.
/// This is NOT a measured loss-of-support event; W05/W06 replace the boundary.
struct PocketEntrySnapshot {
    enum Source { case event, boundsFallback, analyticRollout }
    let time: Float
    let ball: BallState
    let pocketID: String
    let source: Source
    let geometry: TableGeometry
    let modelVersion: String = "planar-capture-v1"
}

/// A contact-free spatial interval. Contacts split intervals; no display-frame integration.
struct SpatialMotionSegment {
    enum Phase { case airborne, pocket }
    enum ValidationError: Error { case invalidInterval, invalidState }
    struct Sample {
        let position: SCNVector3
        let velocity: SCNVector3
        let angularVelocity: SCNVector3
    }
    let ballName: String
    let pocketID: String?
    let phase: Phase
    let startTime: Float
    let duration: Float
    let start: Sample
    let acceleration: SCNVector3

    init(ballName: String, pocketID: String? = nil, phase: Phase,
         startTime: Float, duration: Float, start: Sample,
         acceleration: SCNVector3 = SCNVector3(0, -TablePhysics.gravity, 0)) throws {
        guard startTime.isFinite, duration.isFinite, startTime >= 0, duration > 0,
              (startTime + duration).isFinite, startTime + duration > startTime else {
            throw ValidationError.invalidInterval
        }
        let vectors = [start.position, start.velocity, start.angularVelocity, acceleration]
        guard !ballName.isEmpty, vectors.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else {
            throw ValidationError.invalidState
        }
        self.ballName = ballName; self.pocketID = pocketID; self.phase = phase
        self.startTime = startTime; self.duration = duration
        self.start = start; self.acceleration = acceleration
    }

    /// Absolute shot time. Outside this interval is nil, never silent extrapolation.
    func sample(at time: Float) -> Sample? {
        guard time.isFinite, time >= startTime, time <= startTime + duration else { return nil }
        let dt = time - startTime
        return Sample(position: start.position + start.velocity * dt + acceleration * (0.5 * dt * dt),
                      velocity: start.velocity + acceleration * dt,
                      angularVelocity: start.angularVelocity)
    }
}

/// Short absorbing-bag presentation after the rule outcome is committed.
/// Gravity continues to the measured support height; the soft collector then
/// absorbs motion. No hidden pile/contact solver is involved.
struct PocketCollectionTail {
    typealias V=SIMD3<Double>
    let start:LocalPocketSimulation.State
    let end:LocalPocketSimulation.State
    let gravity:Double
    enum Failure:Error { case invalidInput }

    init(start:LocalPocketSimulation.State,restingCenterY:Double,gravity:Double) throws {
        guard gravity>0,gravity.isFinite,restingCenterY.isFinite,start.time.isFinite,start.time>=0,
              [start.position,start.velocity,start.omega].allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite}),
              start.velocity.y<=0,start.position.y>=restingCenterY else { throw Failure.invalidInput }
        let drop=start.position.y-restingCenterY
        let dt=drop>0 ? 2*drop/(sqrt(start.velocity.y*start.velocity.y+2*gravity*drop)-start.velocity.y) : 0
        var position=start.position+start.velocity*dt+V(0,-gravity,0)*(0.5*dt*dt)
        position.y=restingCenterY
        self.start=start;self.gravity=gravity
        self.end = .init(time:start.time+dt,position:position,velocity:.zero,omega:.zero)
    }

    func sample(at time:Double)->LocalPocketSimulation.State? {
        guard time.isFinite,time>=start.time else { return nil }
        if time>=end.time { var terminal=end;terminal.time=time;return terminal }
        let dt=time-start.time,a=V(0,-gravity,0)
        return .init(time:time,position:start.position+start.velocity*dt+a*(0.5*dt*dt),
                     velocity:start.velocity+a*dt,omega:start.omega)
    }
}

final class TrajectoryRecorder {
    /// Confirmed rule capture is distinct from the continuing visible motion.
    /// The caller must establish capture from physical geometry before recording.
    struct ConfirmedCapture {
        let ballName:String
        let pocketID:String
        let geometryVersion:String
        let state:LocalPocketSimulation.State
    }
    enum CaptureFailure:Error { case invalidRecord,conflictingCapture }
    private var capturesByBall:[String:ConfirmedCapture]=[:]
    private(set) var collectionTailsByBallName:[String:PocketCollectionTail]=[:]
    func recordCollectionTail(ballName:String,tail:PocketCollectionTail) throws {
        guard let capture=capturesByBall[ballName],capture.state.time==tail.start.time,
              capture.state.position==tail.start.position,capture.state.velocity==tail.start.velocity,
              capture.state.omega==tail.start.omega else { throw CaptureFailure.invalidRecord }
        collectionTailsByBallName[ballName]=tail
    }
    func spatialStateAt(ballName:String,time:Double)->LocalPocketSimulation.State? {
        guard time.isFinite,time>=0 else { return nil }
        if let tail=collectionTailsByBallName[ballName],time>=tail.start.time { return tail.sample(at:time) }
        return localIntervalsByBallName[ballName]?.last(where:{$0.start.time<=time && $0.end.time>=time})?.sample(at:time)
    }
    var confirmedCaptures:[ConfirmedCapture] {
        capturesByBall.values.sorted {
            $0.state.time == $1.state.time ? $0.ballName<$1.ballName : $0.state.time<$1.state.time
        }
    }
    func recordConfirmedCapture(_ capture:ConfirmedCapture) throws {
        let s=capture.state
        guard !capture.ballName.isEmpty,!capture.pocketID.isEmpty,!capture.geometryVersion.isEmpty,
              s.time.isFinite,s.time>=0,
              [s.position,s.velocity,s.omega].allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite}) else {
            throw CaptureFailure.invalidRecord
        }
        if let old=capturesByBall[capture.ballName] {
            guard old.pocketID==capture.pocketID,old.geometryVersion==capture.geometryVersion,
                  old.state.time==s.time,old.state.position==s.position,old.state.velocity==s.velocity,old.state.omega==s.omega else {
                throw CaptureFailure.conflictingCapture
            }
            return
        }
        capturesByBall[capture.ballName]=capture
    }
    enum LocalHandoffKind { case entered, returned }
    struct LocalHandoff {
        let ballName:String
        let domain:LocalPocketOwnership.Domain
        var pocketID:String? { domain.pocketID }
        let kind:LocalHandoffKind
        let state:LocalPocketSimulation.State
        init(ballName:String,pocketID:String,kind:LocalHandoffKind,state:LocalPocketSimulation.State) {
            self.init(ballName:ballName,domain:.pocket(pocketID),kind:kind,state:state)
        }
        init(ballName:String,domain:LocalPocketOwnership.Domain,kind:LocalHandoffKind,state:LocalPocketSimulation.State) {
            self.ballName=ballName;self.domain=domain;self.kind=kind;self.state=state
        }
    }
    struct LocalStaticContact {
        let ballName:String
        let geometryID:String
        let contact:LocalPocketSimulation.Contact
    }
    private(set) var localStaticContacts:[LocalStaticContact]=[]
    func recordLocalStaticContact(_ contact:LocalStaticContact) { localStaticContacts.append(contact) }
    private(set) var localHandoffs:[LocalHandoff]=[]
    private(set) var localIntervalsByBallName:[String:[LocalPocketSimulation.Interval]]=[:]
    private(set) var framesByBallName: [String: [BallFrame]] = [:]
    private(set) var duration: Float = 0
    private(set) var pocketEntries: [PocketEntrySnapshot] = []

    func recordLocalHandoff(_ handoff:LocalHandoff) { localHandoffs.append(handoff) }
    func recordLocalIntervals(ballName:String,intervals:[LocalPocketSimulation.Interval]) {
        localIntervalsByBallName[ballName,default:[]].append(contentsOf:intervals)
    }

    func recordPocketEntry(ball: BallState, pocketID: String, time: Float,
                           source: PocketEntrySnapshot.Source, geometry: TableGeometry) {
        pocketEntries.append(PocketEntrySnapshot(time: time, ball: ball, pocketID: pocketID,
                                                source: source, geometry: geometry))
    }
    
    func recordFrame(ballName: String, frame: BallFrame) {
        var list = framesByBallName[ballName] ?? []
        list.append(frame)
        framesByBallName[ballName] = list
        duration = max(duration, frame.time)
    }
    
    func stateAt(ballName: String, time: Float) -> BallFrame? {
        guard let frames = framesByBallName[ballName], !frames.isEmpty else { return nil }
        // 简单线性查找，可后续优化为二分
        var last: BallFrame = frames[0]
        for frame in frames {
            if frame.time >= time { return frame }
            last = frame
        }
        return last
    }
    
    /// 检查指定球是否在轨迹中被进袋
    func isBallPocketed(_ ballName: String,at time:Double?=nil) -> Bool {
        if let time,(!time.isFinite || time<0) { return false }
        if let capture=capturesByBall[ballName] {
            return time.map { capture.state.time<=$0 } ?? true
        }
        // Legacy records retain their former terminal-state semantics.
        guard let frames=framesByBallName[ballName] else { return false }
        let frame=time.flatMap { t in frames.last(where:{Double($0.time)<=t}) } ?? (time == nil ? frames.last:nil)
        return frame?.state == .pocketed
    }
    
    // 回放动作统一由 `TrajectoryPlayback.action(for:ballName:)` 生成（解析解逐帧求值 +
    // 角速度积分自转）。此处旧的「事件帧线性插值 + 位移反推滚动」实现与其唯一调用方
    // `SceneKitBridge` 已于 v17 W2 删除。
}

/// Runtime ownership retains Double states until a validated planar handoff.
/// Revision tokens reject speculative updates computed before another event.
struct LocalPocketOwnership {
    enum Domain:Equatable {
        case pocket(String), airborne
        var pocketID:String? { if case .pocket(let id)=self { return id };return nil }
    }
    struct Entry {
        let domain:Domain
        var pocketID:String? { domain.pocketID }
        let revision:UInt64
        let state:LocalPocketSimulation.State
    }
    enum Failure:Error { case invalidEntry, duplicateOwner, staleUpdate, invalidClock }
    private(set) var entries:[String:Entry]=[:]
    private var nextRevision:UInt64=0

    mutating func enter(ballName:String,pocketID:String,state:LocalPocketSimulation.State) throws {
        try enter(ballName:ballName,domain:.pocket(pocketID),state:state)
    }

    mutating func enter(ballName:String,domain:Domain,state:LocalPocketSimulation.State) throws {
        guard !ballName.isEmpty,domain.pocketID?.isEmpty != true,state.time.isFinite,state.time>=0,
              [state.position,state.velocity,state.omega].allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite}) else {
            throw Failure.invalidEntry
        }
        guard entries[ballName] == nil else { throw Failure.duplicateOwner }
        nextRevision+=1
        entries[ballName]=Entry(domain:domain,revision:nextRevision,state:state)
    }

    /// Validate the entire group before committing any member.
    mutating func commit(states:[String:LocalPocketSimulation.State],revisions:[String:UInt64]) throws {
        guard !states.isEmpty,Set(states.keys)==Set(revisions.keys),let time=states.values.first?.time else { throw Failure.staleUpdate }
        for (name,state) in states {
            guard let owner=entries[name],owner.revision==revisions[name] else { throw Failure.staleUpdate }
            guard state.time.isFinite,state.time>=owner.state.time,state.time==time,
                  [state.position,state.velocity,state.omega].allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite}) else {
                throw Failure.invalidClock
            }
        }
        nextRevision+=1
        for (name,state) in states {
            entries[name]=Entry(domain:entries[name]!.domain,revision:nextRevision,state:state)
        }
    }

    mutating func returnToPlanar(ballName:String,pocketID:String,revision:UInt64,solver:LocalPocketSimulation,
                                 region:PocketLocalRegion,surfaceY:Double) throws -> LocalPocketSimulation.State? {
        guard let owner=entries[ballName],owner.revision==revision else { throw Failure.staleUpdate }
        guard owner.pocketID==pocketID else { throw Failure.invalidEntry }
        guard let state=solver.planarReturn(from:owner.state,region:region,surfaceY:surfaceY) else { return nil }
        entries.removeValue(forKey:ballName)
        return state
    }

    mutating func completeCapture(ballName:String,pocketID:String,revision:UInt64) throws -> LocalPocketSimulation.State {
        guard let owner=entries[ballName],owner.revision==revision else { throw Failure.staleUpdate }
        guard !pocketID.isEmpty,owner.domain == .airborne || owner.pocketID==pocketID else { throw Failure.invalidEntry }
        entries.removeValue(forKey:ballName)
        return owner.state
    }

    mutating func returnAirborneToPlanar(ballName:String,revision:UInt64,solver:LocalPocketSimulation,
                                         surfaceY:Double) throws -> LocalPocketSimulation.State? {
        guard let owner=entries[ballName],owner.revision==revision else { throw Failure.staleUpdate }
        guard owner.domain == .airborne else { throw Failure.invalidEntry }
        guard let state=solver.planarSupport(from:owner.state,surfaceY:surfaceY) else { return nil }
        entries.removeValue(forKey:ballName)
        return state
    }
}

/// Shared spatial contact solver for pocket regions and airborne motion.
struct LocalPocketSimulation {
    typealias V = SIMD3<Double>
    struct Surface {
        let triangle: PocketContactTriangle
        let restitution: Double
        let friction: Double
        let rollingFriction: Double
        let spinFriction: Double
        /// Fraction of the centre's tangential velocity and spin kept after an
        /// approaching impact. 1 is a rigid surface; below 1 models a soft liner
        /// that grips the ball (see `PocketContactResponse.linerSink`).
        let tangentialRetention: Double
        init(triangle:PocketContactTriangle,restitution:Double,friction:Double,
             rollingFriction:Double=0,spinFriction:Double=0,tangentialRetention:Double=1) {
            precondition(rollingFriction>=0 && rollingFriction.isFinite && spinFriction>=0 && spinFriction.isFinite)
            precondition(tangentialRetention.isFinite && (0...1).contains(tangentialRetention))
            self.triangle=triangle;self.restitution=restitution;self.friction=friction
            self.rollingFriction=rollingFriction;self.spinFriction=spinFriction
            self.tangentialRetention=tangentialRetention
        }
    }
    struct State { var time: Double; var position: V; var velocity: V; var omega: V }
    struct Contact { let time: Double; let surface: Int; let normal: V }
    struct Interval {
        let start: State
        let duration: Double
        let acceleration: V
        let angularAcceleration: V
        /// Includes any impulse/projection at the right endpoint.
        let end: State

        /// The left limit at a contact retains the incoming velocity; sampling
        /// the right endpoint normally returns the resolved outgoing state.
        func sample(at time:Double,beforeEndpoint:Bool=false) -> State? {
            guard time.isFinite,time>=start.time,time<=end.time else { return nil }
            if time == end.time && !beforeEndpoint { return end }
            let dt=time-start.time
            return State(time:time,position:start.position+start.velocity*dt+acceleration*(0.5*dt*dt),
                         velocity:start.velocity+acceleration*dt,omega:start.omega+angularAcceleration*dt)
        }
    }
    struct Result {
        let states: [State]; let contacts: [Contact]; let maxCorrection: Double; let rejectedSteps: Int
        let intervals: [Interval]
    }
    struct PairContact {
        let time: Double
        let normal: V // A -> B
        let a: State
        let b: State
    }

    /// Merge two accepted piecewise trajectories on their absolute clock. No
    /// frame resampling: each overlap retains its actual relative acceleration.
    static func firstPairContact(_ a:Result,_ b:Result,radius:Double) throws -> PairContact? {
        guard radius>0,radius.isFinite else { throw Failure.invalidInput }
        func lengthForContact(_ v:V)->Double { sqrt(v.x*v.x+v.y*v.y+v.z*v.z) }
        var i=0,j=0
        while i<a.intervals.count && j<b.intervals.count {
            let x=a.intervals[i],y=b.intervals[j]
            let lo=max(x.start.time,y.start.time),hi=min(x.end.time,y.end.time)
            if hi>lo,let p=x.sample(at:lo,beforeEndpoint:true),let q=y.sample(at:lo,beforeEndpoint:true),
               let hit=try SpatialBallContact.firstContact(position:q.position-p.position,
                    velocity:q.velocity-p.velocity,acceleration:y.acceleration-x.acceleration,
                    radiusSum:2*radius,horizon:hi-lo,
                    positionUncertainty:64*Double.ulpOfOne*max(1,lengthForContact(p.position),lengthForContact(q.position))) {
                let relativeVelocity=q.velocity-p.velocity
                let relativeAcceleration=y.acceleration-x.acceleration
                let rounding=64*Double.ulpOfOne*max(1,lengthForContact(p.velocity),lengthForContact(q.velocity))
                // Sustained-force roundoff can leave a touching pair with a
                // sub-ulp closing drift. Ignore only a zero-time root whose
                // entire interval remains below that arithmetic velocity bound.
                if hit.time == 0 && lengthForContact(relativeVelocity)+lengthForContact(relativeAcceleration)*(hi-lo)<=rounding {
                    if x.end.time<=y.end.time { i+=1 }
                    if y.end.time<=x.end.time { j+=1 }
                    continue
                }
                let time=lo+hit.time
                guard let incomingA=x.sample(at:time,beforeEndpoint:true),
                      let incomingB=y.sample(at:time,beforeEndpoint:true) else { throw Failure.invalidInput }
                return PairContact(time:time,normal:hit.normal,a:incomingA,b:incomingB)
            }
            if x.end.time<=y.end.time { i+=1 }
            if y.end.time<=x.end.time { j+=1 }
        }
        return nil
    }
    enum Failure: Error {
        case invalidInput, iterationLimit, penetration(Double)
        case timeResolution(stage:String,time:Double,step:Double)
        case spatialResolution(time:Double,step:Double,correction:Double,position:V)
        case initialPenetration(time:Double,surface:Int,depth:Double)
        case supportConvergence(time: Double, stage: String, contacts: Int, residual: Double)
    }
    let surfaces: [Surface]
    let radius: Double
    let gravity: V
    let externalAngularAcceleration: V
    let tolerance: Double
    let ballMaterial:SpatialBallContact.MaterialSource
    private let index: PocketContactIndex?
    init(surfaces:[Surface],radius:Double,gravity:V,tolerance:Double,useSpatialIndex:Bool=true,externalAngularAcceleration:V = .zero,
         ballMaterial:SpatialBallContact.MaterialSource = .supplied) {
        self.surfaces=surfaces;self.radius=radius;self.gravity=gravity;self.tolerance=tolerance;self.externalAngularAcceleration=externalAngularAcceleration
        self.ballMaterial=ballMaterial
        index=useSpatialIndex ? PocketContactIndex(triangles:surfaces.map { $0.triangle }) : nil
    }
    /// Reuse immutable geometry and its index for speculative force refreshes.
    private init(base:LocalPocketSimulation,additionalLinear:V,additionalAngular:V) {
        surfaces=base.surfaces;radius=base.radius;tolerance=base.tolerance;index=base.index
        ballMaterial=base.ballMaterial
        gravity=base.gravity+additionalLinear
        externalAngularAcceleration=base.externalAngularAcceleration+additionalAngular
    }
    private func dot(_ a:V,_ b:V)->Double { a.x*b.x+a.y*b.y+a.z*b.z }
    private func cross(_ a:V,_ b:V)->V { V(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x) }
    private func length(_ v:V)->Double { sqrt(dot(v,v)) }

    private func pairMaterial(_ a:State,_ b:State,normal:V,restitution:Double,friction:Double)->(restitution:Double,friction:Double) {
        SpatialBallContact.material(source:ballMaterial,
            a:.init(velocity:a.velocity,angularVelocity:a.omega),b:.init(velocity:b.velocity,angularVelocity:b.omega),
            normal:normal,radius:radius,restitution:restitution,friction:friction)
    }

    /// Return is a support/velocity decision, never merely a region crossing.
    /// The small height adjustment reconciles the measured Float mesh with the
    /// canonical planar bed within the existing spatial correction budget.
    func planarReturn(from state:State,region:PocketLocalRegion,surfaceY:Double)->State? {
        guard surfaceY.isFinite,state.time.isFinite,
              [state.position,state.velocity,state.omega].allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite}) else { return nil }
        let rounding=64*Double.ulpOfOne*max(1,length(state.position))
        let relative=state.position-region.center
        let outgoing=[0,2].contains { axis in
            abs(relative[axis])>=region.halfExtent-rounding && relative[axis]*state.velocity[axis]>0
        }
        guard !region.contains(state.position) || outgoing else { return nil }
        return planarSupport(from:state,surfaceY:surfaceY)
    }

    /// Bed support is also needed to distinguish a stationary local ball from
    /// an unsupported ball that is about to fall, without releasing ownership.
    func planarSupport(from state:State,surfaceY:Double)->State? {
        guard surfaceY.isFinite,state.time.isFinite,
              [state.position,state.velocity,state.omega].allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite}),
              abs(state.position.y-(surfaceY+radius))<=4*tolerance else { return nil }
        let rounding=64*Double.ulpOfOne*max(1,length(state.position))
        let reach=V(repeating:radius+rounding)
        let candidates=index?.query(low:state.position-reach,high:state.position+reach) ?? Array(surfaces.indices)
        var supported=false
        for i in exposedSupportCandidates(candidates,at:state.position) {
            let delta=state.position-surfaces[i].triangle.closestPoint(to:state.position),distance=length(delta)
            guard distance>=radius-rounding else { return nil }
            if distance<=radius+rounding {
                guard distance>0 else { return nil }
                let n=delta/distance
                let triangle=surfaces[i].triangle
                // Large flat bed triangles can have a one-Float-ULP height
                // difference after import. Recognize only that representable
                // slab, not arbitrary faces whose contact normal points up.
                let meshHeightRoundoff=Double(Float(surfaceY).ulp)
                guard n.y>0,[triangle.a,triangle.b,triangle.c].allSatisfy({abs($0.y-surfaceY)<=meshHeightRoundoff}),
                      abs(dot(state.velocity,n))<=64*Double.ulpOfOne*max(1,length(state.velocity)) else { return nil }
                let foot=V(state.position.x,surfaceY,state.position.z)
                let projected=triangle.closestPoint(to:foot)
                guard abs(projected.x-foot.x)<=rounding,abs(projected.z-foot.z)<=rounding else { return nil }
                supported=true
            }
        }
        guard supported else { return nil }
        var result=state
        result.position.y=surfaceY+radius;result.velocity.y=0
        return result
    }

    struct CoupledAdvance {
        let time: Double
        let states: [State]
        /// Only the accepted prefix; no speculative motion after a pair event.
        let intervals: [[Interval]]
        let constraints: [SpatialBallContact.Constraint]
        var rejectedTrials: Int = 0
        var staticContacts:[[Contact]] = []
    }

    /// Advance a local group to its earliest pair interaction or requested end.
    /// Static-only predictions are speculative until the earliest shared event
    /// is selected. Call again from returned states to rebuild the future.
    func advanceTogether(from initial:[State],duration:Double,maxStep:Double,
                         pairRestitution:Double,pairFriction:Double,
                         useSharedErrorControl:Bool=true,useSingleBodyShortcut:Bool=true) throws -> CoupledAdvance {
        guard let first=initial.first,duration>0,duration.isFinite,maxStep>0,maxStep.isFinite else { throw Failure.invalidInput }
        let end=first.time+duration
        guard end.isFinite,end>first.time else { throw Failure.invalidInput }
        var states=try projectContactPositions(initial)
        var time=first.time,intervals=initial.map { _ in [Interval]() },epochs=0,budget=maxStep,rejected=0
        var staticContacts=initial.map { _ in [Contact]() }
        while time<end {
            epochs+=1
            #if DEBUG
            if epochs.isMultiple(of:128) {
                print("[W06 coupled progress] epoch=\(epochs) time=\(time) budget=\(budget) rejected=\(rejected)")
            }
            #endif
            guard epochs<=100000 else { throw Failure.iterationLimit }
            let remaining=end-time,rounding=8*max(end.ulp,time.ulp)
            let dt=remaining<=budget+rounding ? remaining : budget
            let step:CoupledAdvance
            var error=0.0
            do {
                // Fixed group steps are retained as an independent convergence
                // reference; runtime callers use shared error control by default.
                // run() already controls the isolated body's integration error.
                // Retain group projection/rejection, but avoid nesting step
                // doubling when no inter-body force or collision can exist.
                if !useSharedErrorControl || (states.count == 1 && useSingleBodyShortcut) {
                    step=try advanceCoupledTrial(from:states,duration:dt,maxStep:dt,
                                                pairRestitution:pairRestitution,pairFriction:pairFriction)
                } else {
                let whole=try advanceCoupledTrial(from:states,duration:dt,maxStep:dt,
                                                 pairRestitution:pairRestitution,pairFriction:pairFriction)
                guard time+dt/2>time else { throw Failure.timeResolution(stage:"coupled-half",time:time,step:dt) }
                let half=try advanceCoupledTrial(from:states,duration:dt/2,maxStep:dt/2,
                                                pairRestitution:pairRestitution,pairFriction:pairFriction)
                if !half.constraints.isEmpty {
                    step=half
                } else {
                    let remaining=(time+dt)-half.time
                    let tail=try advanceCoupledTrial(from:half.states,duration:remaining,maxStep:remaining,
                                                    pairRestitution:pairRestitution,pairFriction:pairFriction)
                    step=CoupledAdvance(time:tail.time,states:tail.states,
                        intervals:states.indices.map { half.intervals[$0]+tail.intervals[$0] },constraints:tail.constraints,
                        staticContacts:states.indices.map { half.staticContacts[$0]+tail.staticContacts[$0] })
                }
                if whole.constraints.isEmpty != step.constraints.isEmpty {
                    budget=dt/2;rejected+=1
                    #if DEBUG
                    if rejected.isMultiple(of:8) { print("[W06 reject event mismatch] time=\(time) dt=\(dt) whole=\(whole.time)/\(whole.constraints.count) fine=\(step.time)/\(step.constraints.count) states=\(states)") }
                    #endif
                    continue
                }
                let speed=max(1,states.map{length($0.velocity)}.max() ?? 0,
                              whole.states.map{length($0.velocity)}.max() ?? 0,
                              step.states.map{length($0.velocity)}.max() ?? 0)
                error=abs(whole.time-step.time)*speed
                for i in states.indices {
                    error=max(error,length(whole.states[i].position-step.states[i].position),
                              dt*length(whole.states[i].velocity-step.states[i].velocity),
                              radius*dt*length(whole.states[i].omega-step.states[i].omega))
                }
                guard error.isFinite else { throw Failure.invalidInput }
                if error>tolerance {
                    budget=dt*max(0.25,min(0.5,0.8*sqrt(tolerance/error)));rejected+=1
                    #if DEBUG
                    if rejected.isMultiple(of:8) { print("[W06 reject error] time=\(time) dt=\(dt) error=\(error) states=\(states)") }
                    #endif
                    continue
                }
                }
            } catch Failure.penetration(let overlap) {
                budget=dt/2;rejected+=1
                #if DEBUG
                if rejected.isMultiple(of:8) { print("[W06 reject penetration] time=\(time) dt=\(dt) overlap=\(overlap) states=\(states)") }
                #endif
                guard time+budget>time else { throw Failure.timeResolution(stage:"coupled-rejection",time:time,step:budget) }
                continue
            } catch {
                #if DEBUG
                print("[W07 coupled failure] time=\(time) dt=\(dt) error=\(error) states=\(states)")
                #endif
                throw error
            }
            for i in states.indices {
                intervals[i].append(contentsOf:step.intervals[i])
                staticContacts[i].append(contentsOf:step.staticContacts[i])
            }
            if !step.constraints.isEmpty {
                return CoupledAdvance(time:step.time,states:step.states,intervals:intervals,constraints:step.constraints,rejectedTrials:rejected,staticContacts:staticContacts)
            }
            guard step.time>time else { throw Failure.timeResolution(stage:"coupled-accepted",time:time,step:step.time-time) }
            states=step.states;time=step.time
            budget=min(maxStep,dt*(error>0 ? min(2,max(1,0.8*sqrt(tolerance/error))) : 2))
        }
        return CoupledAdvance(time:time,states:states,intervals:intervals,constraints:[],rejectedTrials:rejected,staticContacts:staticContacts)
    }

    enum PressureContact:Equatable { case pair(Int,Int), surface(Int,Int) }
    struct PairForcePlan {
        let accelerations:[SpatialBallContact.Acceleration]
        let pressure:[PressureContact]
    }
    func sustainedPairAcceleration(_ states:[State],friction:Double,duration:Double) throws -> PairForcePlan {
        var supports:[SpatialBallContact.SupportConstraint]=[],references:[PressureContact]=[]
        for a in states.indices {
            let s=states[a],rounding=64*Double.ulpOfOne*max(1,length(s.position),radius)
            let reach=V(repeating:radius+rounding)
            let candidates=index?.query(low:s.position-reach,high:s.position+reach) ?? Array(surfaces.indices)
            for i in candidates {
                let surface=surfaces[i],point=surface.triangle.closestPoint(to:s.position),delta=s.position-point,d=length(delta)
                if d>0 && d<=radius+rounding {
                    let n=delta/d
                    references.append(.surface(a,i))
                    supports.append(.init(contact:.init(a:a,b:nil,normal:n,restitution:0,friction:surface.friction),
                        normalRate:normalRate(surface.triangle,point:point,normal:n,velocity:s.velocity),
                        rollingFriction:surface.rollingFriction,spinFriction:surface.spinFriction))
                }
            }
            for b in states.indices where b>a {
                let delta=s.position-states[b].position,d=length(delta)
                if d>0 && abs(d-2*radius)<=rounding+64*Double.ulpOfOne*max(1,length(states[b].position)) {
                    let n=delta/d,v=s.velocity-states[b].velocity
                    references.append(.pair(a,b))
                    let material=pairMaterial(s,states[b],normal:n,restitution:0,friction:friction)
                    supports.append(.init(contact:.init(a:a,b:b,normal:n,restitution:0,friction:material.friction),
                                          normalRate:(v-n*dot(v,n))/d))
                }
            }
        }
        var result=states.map { _ in SpatialBallContact.Acceleration(linear:.zero,angular:.zero) }
        guard supports.contains(where:{$0.contact.b != nil}) else { return PairForcePlan(accelerations:result,pressure:[]) }
        let response=try SpatialBallContact.resolveSupport(states.map{.init(velocity:$0.velocity,angularVelocity:$0.omega)},
            external:states.map { _ in .init(linear:gravity,angular:externalAngularAcceleration) },constraints:supports,radius:radius,duration:duration)
        // Static forces are recomputed by each local solver; transfer only pair
        // forces and torques, otherwise the table reaction would be counted twice.
        for j in supports.indices {
            let c=supports[j].contact
            guard let b=c.b else { continue }
            let force=response.forcesOnA[j],n=c.normal/length(c.normal),torque=cross(-n,force)*(2.5/radius)
            let a=result[c.a],other=result[b]
            result[c.a] = .init(linear:a.linear+force,angular:a.angular+torque)
            result[b] = .init(linear:other.linear-force,angular:other.angular+torque)
        }
        let pressure=supports.indices.filter { dot(response.forcesOnA[$0],supports[$0].contact.normal)>0 }.map { references[$0] }
        return PairForcePlan(accelerations:result,pressure:pressure)
    }

    func projectPressure(_ original:[State],contacts:[PressureContact],positions:Bool=true) throws -> [State] {
        guard !contacts.isEmpty else { return original }
        var states=original
        let relaxation=1/Double(contacts.count)
        let surfaceCandidates=states.indices.map { a in
            contacts.compactMap { contact -> Int? in
                if case .surface(let body,let index)=contact,body==a { return index }
                return nil
            }
        }
        for _ in 0..<4096 {
            // Re-evaluate finite features at the corrected position. A shared
            // edge covered by an adjacent face is no longer a pressure surface;
            // forcing both equalities can invent a second normal constraint.
            let exposed=states.indices.map { a in
                Set(exposedSupportCandidates(surfaceCandidates[a],at:states[a].position))
            }
            var dp=states.map { _ in V.zero },dv=dp,residual=0.0
            for contact in contacts {
                if case .surface(let body,let index)=contact,!exposed[body].contains(index) { continue }
                let a:Int,b:Int?,delta:V,target:Double
                switch contact {
                case .pair(let x,let y):
                    a=x;b=y;delta=states[x].position-states[y].position;target=2*radius
                case .surface(let x,let index):
                    a=x;b=nil;delta=states[x].position-surfaces[index].triangle.closestPoint(to:states[x].position);target=radius
                }
                let distance=length(delta)
                guard distance>0 else { throw Failure.invalidInput }
                let n=delta/distance,inv=b == nil ? 1.0 : 2.0
                let error=target-distance,relative=states[a].velocity-(b.map{states[$0].velocity} ?? .zero)
                let positionRoundoff=64*Double.ulpOfOne*max(1,length(states[a].position),
                    b.map{length(states[$0].position)} ?? 0)
                // A final velocity-only pass must not restore an old finite
                // feature which the complete geometry solve has released.
                if !positions && abs(error)>positionRoundoff { continue }
                let vn=dot(relative,n)
                if positions {
                    dp[a]+=n*(error/inv)
                    if let b { dp[b]-=n*(error/inv) }
                }
                dv[a]-=n*(vn/inv)
                if let b { dv[b]+=n*(vn/inv) }
                let velocityRoundoff=64*Double.ulpOfOne*max(1,length(states[a].velocity),
                    b.map{length(states[$0].velocity)} ?? 0)
                // These residuals have different units. In particular, world
                // translation must not loosen the normal-velocity criterion
                // used by resolveSupport to activate a resting contact.
                residual=max(residual,positions ? abs(error)/positionRoundoff : 0,abs(vn)/velocityRoundoff)
            }
            if residual<=1 { return states }
            for i in states.indices {
                states[i].position+=dp[i]*relaxation;states[i].velocity+=dv[i]*relaxation
                let correction=length(states[i].position-original[i].position)
                guard correction<=4*tolerance else { throw Failure.penetration(correction) }
            }
        }
        #if DEBUG
        print("[W06 pressure projection limit] original=\(original) states=\(states) contacts=\(contacts)")
        #endif
        throw Failure.iterationLimit
    }

    struct PreparedGroupSupport {
        let states:[State]
        let plan:PairForcePlan
    }

    /// Collapse sub-resolution rebounds in the complete contact space. Doing
    /// this independently per ball can turn a resting neighbour into an impact.
    /// A candidate is accepted only when its micro contacts actually carry load.
    func preparedGroupSupport(_ original:[State],friction:Double,duration:Double) throws -> PreparedGroupSupport {
        func unchanged() throws -> PreparedGroupSupport {
            .init(states:original,plan:try sustainedPairAcceleration(original,friction:friction,duration:duration))
        }
        guard original.count>1 else { return try unchanged() }
        let velocityScale=max(1,original.map{length($0.velocity)}.max() ?? 0)
        let velocityRoundoff=64*Double.ulpOfOne*velocityScale
        var rows:[[Double]]=[],allRows:[[Double]]=[],micro:[PressureContact]=[]
        func row(_ a:Int,_ b:Int?,_ n:V)->[Double] {
            var result=Array(repeating:0.0,count:3*original.count)
            for k in 0..<3 { result[3*a+k]=n[k];if let b { result[3*b+k] = -n[k] } }
            return result
        }
        for a in original.indices {
            let state=original[a],rounding=64*Double.ulpOfOne*max(1,length(state.position))
            let reach=V(repeating:radius+rounding)
            let nearby=index?.query(low:state.position-reach,high:state.position+reach) ?? Array(surfaces.indices)
            let touching=nearby.filter { length(state.position-surfaces[$0].triangle.closestPoint(to:state.position))<=radius+rounding }
            for i in exposedSupportCandidates(touching,at:state.position) {
                let t=surfaces[i].triangle,point=t.closestPoint(to:state.position),delta=state.position-point,d=length(delta)
                guard d>0 else { throw Failure.invalidInput }
                let n=delta/d,vn=dot(state.velocity,n),r=row(a,nil,n)
                allRows.append(r)
                if vn < -velocityRoundoff { return try unchanged() }
                if vn<=velocityRoundoff { rows.append(r);continue }
                let restoring=max(0,-dot(gravity,n)-curvature(t,point:point,normal:n,velocity:state.velocity))
                if restoring>0,vn*vn<=2*restoring*tolerance {
                    rows.append(r);micro.append(.surface(a,i))
                }
            }
            for b in original.indices where b>a {
                let delta=state.position-original[b].position,d=length(delta)
                let bound=rounding+64*Double.ulpOfOne*max(1,length(original[b].position))
                guard d>0,abs(d-2*radius)<=bound else { continue }
                let n=delta/d,vn=dot(state.velocity-original[b].velocity,n),r=row(a,b,n)
                allRows.append(r)
                if vn < -velocityRoundoff { return try unchanged() }
                if vn<=velocityRoundoff { rows.append(r) }
            }
        }
        guard !micro.isEmpty else { return try unchanged() }
        func inner(_ a:[Double],_ b:[Double])->Double { zip(a,b).reduce(0){$0+$1.0*$1.1} }
        var basis:[[Double]]=[]
        for var r in rows {
            // Reorthogonalize to keep nearly dependent mesh normals stable.
            for _ in 0..<2 { for q in basis {
                let amount=inner(r,q);for k in r.indices { r[k]-=amount*q[k] }
            } }
            let magnitude=sqrt(inner(r,r))
            if magnitude>64*Double.ulpOfOne { basis.append(r.map{$0/magnitude}) }
        }
        let incoming=original.flatMap{[$0.velocity.x,$0.velocity.y,$0.velocity.z]}
        var projected=incoming
        for q in basis {
            let amount=inner(incoming,q);for k in projected.indices { projected[k]-=amount*q[k] }
        }
        guard projected.allSatisfy(\.isFinite),
              allRows.allSatisfy({inner(projected,$0)>=(-velocityRoundoff)}),
              rows.allSatisfy({abs(inner(projected,$0))<=velocityRoundoff}),
              inner(projected,projected)<=inner(incoming,incoming)+64*Double.ulpOfOne*max(1,inner(incoming,incoming)) else {
            return try unchanged()
        }
        var candidate=original
        for i in candidate.indices { candidate[i].velocity=V(projected[3*i],projected[3*i+1],projected[3*i+2]) }
        let plan=try sustainedPairAcceleration(candidate,friction:friction,duration:duration)
        guard micro.allSatisfy({plan.pressure.contains($0)}) else { return try unchanged() }
        return .init(states:candidate,plan:plan)
    }

    private func advanceCoupledTrial(from initial:[State],duration:Double,maxStep:Double,
                         pairRestitution:Double,pairFriction:Double) throws -> CoupledAdvance {
        guard let first=initial.first,duration>0,duration.isFinite,
              initial.allSatisfy({$0.time == first.time}),
              pairRestitution.isFinite,(0...1).contains(pairRestitution),
              pairFriction.isFinite,pairFriction>=0 else { throw Failure.invalidInput }
        let prepared=try preparedGroupSupport(initial,friction:pairFriction,duration:duration)
        let pairAcceleration=prepared.plan
        let predictions=try prepared.states.enumerated().map { i,state in
            let solver=LocalPocketSimulation(base:self,additionalLinear:pairAcceleration.accelerations[i].linear,
                                             additionalAngular:pairAcceleration.accelerations[i].angular)
            return try solver.run(from:state,duration:duration,maxStep:maxStep)
        }
        var earliest:Double?
        var predictedPairs:[(time:Double,contact:PressureContact)]=[]
        for a in initial.indices { for b in initial.indices where b>a {
            if pairAcceleration.pressure.contains(where:{ if case .pair(let x,let y)=$0 { return x == a && y == b };return false }) { continue }
            if let hit=try Self.firstPairContact(predictions[a],predictions[b],radius:radius) {
                predictedPairs.append((hit.time,.pair(a,b)))
                earliest=min(earliest ?? hit.time,hit.time)
            }
        } }
        // A new static impact changes the momentum of every ball connected
        // by pressure. Do not finish independent local predictions with the
        // pair forces from before that impact; resolve the shared event first.
        let loadedBodies=Set(pairAcceleration.pressure.flatMap { contact -> [Int] in
            if case .pair(let a,let b)=contact { return [a,b] }
            return []
        })
        for body in loadedBodies {
            if let contact=predictions[body].contacts.first {
                earliest=min(earliest ?? contact.time,contact.time)
            }
        }
        guard let time=earliest else {
            let rawStates=try predictions.map { result -> State in
                guard let end=result.states.last else { throw Failure.invalidInput };return end
            }
            let pressureStates=try projectPressure(rawStates,contacts:pairAcceleration.pressure)
            // Pair pressure correction can enter a static face that was not
            // carrying load at the trial's start. Before accepting this state,
            // restore the full unilateral geometry, not only the old load set.
            let geometryStates=try projectContactPositions(pressureStates)
            // Geometry correction rotates normals, even when its displacement
            // is tiny. Finish velocities on those final normals so the next
            // shared half-step can retain the same sustained contact.
            let states=try projectPressure(geometryStates,contacts:pairAcceleration.pressure,positions:false)
            for i in states.indices {
                let correction=length(states[i].position-rawStates[i].position)
                guard correction<=4*tolerance else { throw Failure.penetration(correction) }
            }
            for a in states.indices { for b in states.indices where b>a {
                let rounding=64*Double.ulpOfOne*max(1,length(states[a].position),length(states[b].position))
                let overlap=2*radius-length(states[a].position-states[b].position)
                guard overlap<=rounding else { throw Failure.penetration(overlap) }
            } }
            let intervals=predictions.enumerated().map { i,result -> [Interval] in
                var spans=result.intervals
                if let last=spans.popLast() {
                    spans.append(Interval(start:last.start,duration:last.duration,acceleration:last.acceleration,
                                          angularAcceleration:last.angularAcceleration,end:states[i]))
                }
                return spans
            }
            return CoupledAdvance(time:first.time+duration,states:states,intervals:intervals,constraints:[],staticContacts:predictions.map(\.contacts))
        }
        let eventIntervals=try predictions.map { result -> Interval in
            guard let span=result.intervals.first(where:{$0.end.time>=time && $0.start.time<=time}) else { throw Failure.invalidInput }
            return span
        }
        var states=try eventIntervals.map { span -> State in
            guard let state=span.sample(at:time,beforeEndpoint:true) else { throw Failure.invalidInput }
            return state
        }
        // Independent curved support predictions drift from the constraints
        // carrying pressure at the start of this accepted prefix. Restore that
        // geometry at an interrupting impact just as at an ordinary endpoint.
        // Preserve incoming momentum: the shared impulse solve owns velocities.
        var eventGeometry=pairAcceleration.pressure
        // Retain the pair that supplied the chosen TOI. Polynomial evaluation
        // can leave a tiny positive gap at its root; re-discovering that pair
        // only from rounded positions loses a valid approaching collision.
        for pair in predictedPairs where pair.time == time {
            if !eventGeometry.contains(pair.contact) { eventGeometry.append(pair.contact) }
        }
        let pressureGeometry=try projectPressure(states,contacts:eventGeometry)
        for i in states.indices { states[i].position=pressureGeometry[i].position }
        let response=try resolveContactGroup(states,accelerations:eventIntervals.map(\.acceleration),
                                             pairRestitution:pairRestitution,pairFriction:pairFriction)
        states=response.states
        let constraints=response.constraints
        let prefixes=predictions.enumerated().map { i,result -> [Interval] in
            var accepted:[Interval]=[]
            for span in result.intervals where span.start.time<=time {
                if span.end.time<time { accepted.append(span);continue }
                accepted.append(Interval(start:span.start,duration:time-span.start.time,acceleration:span.acceleration,
                                         angularAcceleration:span.angularAcceleration,end:states[i]))
                break
            }
            return accepted
        }
        return CoupledAdvance(time:time,states:states,intervals:prefixes,constraints:constraints,
            staticContacts:states.indices.map { i in predictions[i].contacts.filter{$0.time<time}+response.staticContacts[i] })
    }

    /// Resolve a shared event from pre-impact states, irrespective of which
    /// motion solver predicted each ball. Include the complete touching group
    /// and static geometry; callers own clock advancement and cache invalidation.
    func resolveContactGroup(_ initial:[State],accelerations:[V],
                             pairRestitution:Double,pairFriction:Double) throws -> CoupledAdvance {
        func finite(_ v:V)->Bool { v.x.isFinite && v.y.isFinite && v.z.isFinite }
        guard let first=initial.first,accelerations.count==initial.count,
              first.time.isFinite,first.time>=0,
              initial.allSatisfy({$0.time==first.time && finite($0.position) && finite($0.velocity) && finite($0.omega)}),
              accelerations.allSatisfy(finite),
              pairRestitution.isFinite,pairRestitution>=0,pairRestitution<=1,
              pairFriction.isFinite,pairFriction>=0 else { throw Failure.invalidInput }
        var states=try projectContactPositions(initial)
        var constraints:[SpatialBallContact.Constraint]=[]
        var staticContacts=initial.map { _ in [Contact]() }
        var liners:[(ball:Int,normal:V,retention:Double)]=[]
        for a in states.indices {
            let state=states[a],rounding=64*Double.ulpOfOne*max(1,length(state.position),radius)
            let reach=V(repeating:radius+rounding)
            let candidates=index?.query(low:state.position-reach,high:state.position+reach) ?? Array(surfaces.indices)
            for i in candidates {
                let surface=surfaces[i],delta=state.position-surface.triangle.closestPoint(to:state.position),d=length(delta)
                if d>0 && d<=radius+rounding {
                    let normal=delta/d
                    if dot(state.velocity,normal)<(-64*Double.ulpOfOne*max(1,length(state.velocity))) {
                        staticContacts[a].append(.init(time:first.time,surface:i,normal:normal))
                        if surface.tangentialRetention<1 {
                            liners.append((a,normal,surface.tangentialRetention))
                        }
                    }
                    let rebound=max(0,-dot(state.velocity,normal))*surface.restitution
                    let restoringGravity=max(0,-dot(gravity,normal))
                    // Match the standalone local solver's bounded rebound
                    // treatment when this static contact joins a pair event.
                    let restitution=restoringGravity>0 && rebound*rebound<=2*restoringGravity*tolerance ? 0 : surface.restitution
                    constraints.append(.init(a:a,b:nil,normal:normal,
                                             restitution:restitution,friction:surface.friction))
                }
            }
            for b in states.indices where b>a {
                let delta=state.position-states[b].position,d=length(delta)
                if d>0 && abs(d-2*radius)<=rounding+64*Double.ulpOfOne*max(1,length(states[b].position)) {
                    let normal=delta/d,relative=state.velocity-states[b].velocity
                    let normalSpeed=dot(relative,normal)
                    let tangent=relative-normal*normalSpeed
                    let normalAcceleration=dot(accelerations[a]-accelerations[b],normal)
                        + dot(tangent,tangent)/d
                    let material=pairMaterial(state,states[b],normal:normal,restitution:pairRestitution,friction:pairFriction)
                    let rebound=max(0,-normalSpeed)*material.restitution
                    // A restoring relative acceleration brings a sufficiently
                    // small rebound back within the spatial error budget. Treat
                    // that impact as inelastic, then let unilateral forces decide
                    // support/release; never impose a fixed low-speed cutoff.
                    let restitution=normalAcceleration<0 && rebound*rebound<=(-2*normalAcceleration*tolerance) ? 0 : material.restitution
                    constraints.append(.init(a:a,b:b,normal:normal,
                                             restitution:restitution,friction:material.friction))
                }
            }
        }
        guard constraints.contains(where:{$0.b != nil}) else {
            #if DEBUG
            print("[W07 shared event without pair] initial=\(initial) accelerations=\(accelerations) projected=\(states) constraints=\(constraints)")
            #endif
            throw Failure.invalidInput
        }
        let response=try SpatialBallContact.resolveInstant(states.map { .init(velocity:$0.velocity,angularVelocity:$0.omega) },
                                                          constraints:constraints,radius:radius)
        for i in states.indices { states[i].velocity=response.motions[i].velocity;states[i].omega=response.motions[i].angularVelocity }
        // Same liner grip as the single-ball solver, applied after the rigid group response.
        for liner in liners {
            let motion=PocketContactResponse.linerSink(.init(velocity:states[liner.ball].velocity,angularVelocity:states[liner.ball].omega),
                                                       normal:liner.normal,retention:liner.retention)
            states[liner.ball].velocity=motion.velocity;states[liner.ball].omega=motion.angularVelocity
        }
        return CoupledAdvance(time:first.time,states:states,
                              intervals:initial.map { _ in [] },constraints:constraints,staticContacts:staticContacts)
    }

    /// A pair TOI can coincide with a static contact's position correction.
    /// Correct their joint unilateral geometry, preserving incoming velocities
    /// for the subsequent impulse solve. Independent per-ball correction can
    /// otherwise start the next CCD interval already inside its neighbour.
    private func projectContactPositions(_ original:[State]) throws -> [State] {
        var states=original
        let reach=V(repeating:radius+4*tolerance)
        let candidates=original.map { state in
            index?.query(low:state.position-reach,high:state.position+reach) ?? Array(surfaces.indices)
        }
        for _ in 0..<4096 {
            var deltas=states.map { _ in V.zero },counts=states.map { _ in 0 },residual=0.0
            for a in states.indices {
                for i in candidates[a] {
                    let delta=states[a].position-surfaces[i].triangle.closestPoint(to:states[a].position)
                    let d=length(delta)
                    guard d>0 else { throw Failure.invalidInput }
                    if d<radius {
                        deltas[a]+=delta*((radius-d)/d);counts[a]+=1
                        let rounding=64*Double.ulpOfOne*max(1,length(states[a].position))
                        residual=max(residual,(radius-d)/rounding)
                    }
                }
                for b in states.indices where b>a {
                    let delta=states[a].position-states[b].position,d=length(delta)
                    guard d>0 else { throw Failure.invalidInput }
                    if d<2*radius {
                        let correction=delta*((2*radius-d)/(2*d))
                        deltas[a]+=correction;deltas[b]-=correction;counts[a]+=1;counts[b]+=1
                        let rounding=64*Double.ulpOfOne*max(1,length(states[a].position),length(states[b].position))
                        residual=max(residual,(2*radius-d)/rounding)
                    }
                }
            }
            if residual<=1 { return states }
            let relaxation=1/Double(max(1,counts.max() ?? 0))
            for i in states.indices {
                states[i].position+=deltas[i]*relaxation
                let correction=length(states[i].position-original[i].position)
                guard correction<=4*tolerance else { throw Failure.penetration(correction) }
            }
        }
        #if DEBUG
        print("[W06 joint position limit] original=\(original) states=\(states)")
        #endif
        throw Failure.iterationLimit
    }

    /// A face containing the perpendicular foot is closer than a boundary
    /// point covered by that face. Adjacent triangles need not be coplanar:
    /// retaining their shared edge invents a second support when the distances
    /// round equal just after the sphere enters the face interior.
    private func exposedSupportCandidates(_ candidates:[Int],at position:V)->[Int] {
        let rounding=64*Double.ulpOfOne*max(1,length(position))
        let interiors=candidates.compactMap { i -> (Int,V,V)? in
            let t=surfaces[i].triangle,raw=cross(t.b-t.a,t.c-t.a),magnitude=length(raw)
            guard magnitude>0 else { return nil }
            let n=raw/magnitude
            guard let foot=t.projectedInteriorPoint(to:position) else { return nil }
            return (i,n,foot)
        }
        return candidates.filter { i in
            let point=surfaces[i].triangle.closestPoint(to:position)
            return !interiors.contains { j,n,foot in
                guard j != i,abs(dot(point-foot,n))<=rounding else { return false }
                let triangle=surfaces[i].triangle
                if triangle.projectedInteriorPoint(to:position)==nil && length(point-foot)<=rounding { return true }
                // An interior face is strictly nearer than any coplanar edge
                // outside that face, even when squared distances round equal.
                // The edge need not itself be covered by the interior triangle.
                let coplanar=[triangle.a,triangle.b,triangle.c].allSatisfy {
                    abs(dot($0-foot,n))<=rounding
                }
                if coplanar && triangle.projectedInteriorPoint(to:position)==nil { return true }
                return length(point-surfaces[j].triangle.closestPoint(to:point))<=rounding
                    && length(point-foot)>rounding
            }
        }
    }

    private func tangentialSlip(_ state:State,normal:V)->V {
        let slip=state.velocity+cross(state.omega,-normal*radius)
        let tangent=slip-normal*dot(slip,normal)
        // Cross product, addition and tangent projection can leave cancellation
        // noise at rolling contact. Dividing that noise by a tiny event interval
        // invents finite friction. Use the operands' scale, not an absolute speed
        // threshold, so physically distinguishable slow sliding is retained.
        let rounding=16*Double.ulpOfOne*(length(state.velocity)+radius*length(state.omega))
        return length(tangent)<=rounding ? .zero : tangent
    }

    private func curvature(_ triangle:PocketContactTriangle,point:V,normal:V,velocity:V)->Double {
        dot(velocity,normalRate(triangle,point:point,normal:normal,velocity:velocity))
    }

    private func normalRate(_ triangle:PocketContactTriangle,point:V,normal:V,velocity:V)->V {
        let faceNormal=cross(triangle.b-triangle.a,triangle.c-triangle.a)
        let nLength=length(faceNormal)
        if nLength>0, length(cross(faceNormal/nLength,normal))<1e-8 {
            let face=faceNormal/nLength
            let roundoff=64*Double.ulpOfOne*max(1,length(point))
            let leavingEdge=[(triangle.a,triangle.b),(triangle.b,triangle.c),(triangle.c,triangle.a)].contains { a,b in
                let edge=b-a
                return abs(dot(cross(edge,point-a),face))<=roundoff*length(edge)
                    && dot(cross(edge,velocity),face)<0
            }
            if !leavingEdge { return .zero }
        }
        let tangent=velocity-normal*dot(velocity,normal)
        for (a,b) in [(triangle.a,triangle.b),(triangle.b,triangle.c),(triangle.c,triangle.a)] {
            let e=b-a,e2=dot(e,e)
            guard e2>1e-24 else { continue }
            let t=dot(point-a,e)/e2
            if t>0 && t<1, length(point-(a+e*t))<1e-8 {
                return (tangent-e*(dot(tangent,e)/e2))/radius
            }
        }
        return tangent/radius
    }

    /// Step doubling measures local position and velocity/spin displacement error.
    /// Only the accepted two-half-step path contributes states and contact events.
    /// Spatial launch/landing phase only. The caller resumes the existing planar
    /// law after verified cloth support; reaching the time limit never implies rest.
    func runUntilPlanarSupport(from initial:State,duration:Double,maxStep:Double,
                               surfaceY:Double) throws -> (result:Result,planar:State?) {
        guard duration.isFinite,duration>0,maxStep.isFinite,maxStep>0,
              initial.time.isFinite,(initial.time+duration).isFinite,
              initial.time+duration>initial.time else { throw Failure.invalidInput }
        let limit=initial.time+duration
        var state=initial,states=[initial],contacts:[Contact]=[],intervals:[Interval]=[]
        var correction=0.0,rejected=0
        while state.time<limit {
            if let planar=planarSupport(from:state,surfaceY:surfaceY) {
                return (Result(states:states,contacts:contacts,maxCorrection:correction,
                               rejectedSteps:rejected,intervals:intervals),planar)
            }
            let span=try run(from:state,duration:min(maxStep,limit-state.time),maxStep:maxStep)
            guard let next=span.states.last,next.time>state.time else { throw Failure.iterationLimit }
            states.append(contentsOf:span.states.dropFirst());contacts.append(contentsOf:span.contacts)
            intervals.append(contentsOf:span.intervals)
            correction=max(correction,span.maxCorrection);rejected+=span.rejectedSteps;state=next
        }
        return (Result(states:states,contacts:contacts,maxCorrection:correction,
                       rejectedSteps:rejected,intervals:intervals),planarSupport(from:state,surfaceY:surfaceY))
    }

    func run(from initial:State,duration:Double,maxStep:Double,maxIterations:Int=100000) throws -> Result {
        guard duration>0,maxStep>0,tolerance>0,radius>0,
              [duration,maxStep,tolerance,radius,initial.time].allSatisfy({$0.isFinite}) else { throw Failure.invalidInput }
        let reach=V(repeating:radius)
        let initialCandidates=index?.query(low:initial.position-reach,high:initial.position+reach) ?? Array(surfaces.indices)
        for i in initialCandidates {
            let depth=radius-length(initial.position-surfaces[i].triangle.closestPoint(to:initial.position))
            guard depth<=4*tolerance else { throw Failure.initialPenetration(time:initial.time,surface:i,depth:depth) }
        }
        var state=initial,states=[initial],contacts:[Contact]=[],intervals:[Interval]=[]
        var budget=maxStep,iterations=0,rejected=0,correction=0.0
        let end=initial.time+duration
        while state.time<end {
            iterations+=1
            #if DEBUG
            if iterations.isMultiple(of:32) {
                print("[W06 local adaptive] iterations=\(iterations) time=\(state.time) end=\(end) budget=\(budget) rejected=\(rejected)")
            }
            #endif
            guard iterations<=maxIterations else { throw Failure.iterationLimit }
            let remaining=end-state.time
            let clockRoundoff=8*max(end.ulp,state.time.ulp)
            let dt=remaining<=budget+clockRoundoff ? remaining : budget
            guard state.time+dt/2>state.time, state.time+dt/2<state.time+dt else {
                throw Failure.timeResolution(stage:"local-half",time:state.time,step:dt)
            }
            let whole=try integrate(from:state,duration:dt,maxStep:dt,maxIterations:maxIterations,convergenceHorizon:duration)
            // This isolated solver has static geometry and no other moving bodies.
            // An unchanged stationary state is an autonomous equilibrium: there is
            // no future external event that could wake it inside this run.
            if state.velocity == .zero,whole.contacts.isEmpty,
               whole.states.allSatisfy({ $0.position == state.position && $0.velocity == .zero && $0.omega == state.omega }) {
                let start=state
                state.time=end;states.append(state)
                intervals.append(Interval(start:start,duration:end-start.time,acceleration:.zero,
                                          angularAcceleration:.zero,end:state))
                correction=max(correction,whole.maxCorrection)
                rejected+=whole.rejectedSteps
                break
            }
            let first=try integrate(from:state,duration:dt/2,maxStep:dt/2,maxIterations:maxIterations,convergenceHorizon:duration)
            guard let middle=first.states.last else { throw Failure.iterationLimit }
            let second=try integrate(from:middle,duration:(state.time+dt)-middle.time,
                maxStep:dt/2,maxIterations:maxIterations,convergenceHorizon:duration)
            guard let full=whole.states.last,let fine=second.states.last else { throw Failure.iterationLimit }
            let error=max(length(full.position-fine.position),dt*length(full.velocity-fine.velocity),
                          radius*dt*length(full.omega-fine.omega))
            guard error.isFinite else {
                print("[W07 nonfinite integration comparison] full=\(full) fine=\(fine) dt=\(dt)")
                throw Failure.invalidInput
            }
            if error>tolerance {
                let reduced=dt*max(0.25,min(0.5,0.8*sqrt(tolerance/error)))
                guard state.time+reduced>state.time else { throw Failure.timeResolution(stage:"local-rejection",time:state.time,step:reduced) }
                budget=reduced;rejected+=1
                continue
            }
            states.append(contentsOf:first.states.dropFirst())
            states.append(contentsOf:second.states.dropFirst())
            contacts.append(contentsOf:first.contacts);contacts.append(contentsOf:second.contacts)
            intervals.append(contentsOf:first.intervals);intervals.append(contentsOf:second.intervals)
            correction=max(correction,first.maxCorrection,second.maxCorrection)
            rejected+=first.rejectedSteps+second.rejectedSteps
            state=fine
            let growth=error>0 ? min(2,max(1,0.8*sqrt(tolerance/error))) : 2
            budget=min(maxStep,dt*growth)
        }
        return Result(states:states,contacts:contacts,maxCorrection:correction,rejectedSteps:rejected,intervals:intervals)
    }

    private func integrate(from initial:State,duration:Double,maxStep:Double,maxIterations:Int,
                           convergenceHorizon:Double) throws -> Result {
        guard duration>0,maxStep>0,tolerance>0,radius>0,
              [duration,maxStep,tolerance,radius,initial.time].allSatisfy({$0.isFinite}) else {
            print("[W07 invalid integration input] initial=\(initial) duration=\(duration) maxStep=\(maxStep)")
            throw Failure.invalidInput
        }
        var s=initial,history=[initial],contacts:[Contact]=[],intervals:[Interval]=[],maxCorrection=0.0
        let end=initial.time+duration
        var iterations=0, rejectedSteps=0
        var stepBudget=maxStep
        while s.time<end {
            iterations+=1
            #if DEBUG
            if iterations.isMultiple(of:2048) {
                print("[W06 local progress] iterations=\(iterations) time=\(s.time) end=\(end) budget=\(stepBudget)")
            }
            #endif
            guard iterations<=maxIterations else {
                print("[W05 step limit] state=\(s) budget=\(stepBudget) rejections=\(rejectedSteps) contacts=\(contacts.suffix(4))")
                throw Failure.iterationLimit
            }
            let before=s, contactCount=contacts.count, previousCorrection=maxCorrection
            let remaining=end-s.time
            // Addition/subtraction around an absolute clock can make the final
            // interval exceed the requested cap by a few ulps. Integrate that
            // full final interval instead of creating a near-zero friction step.
            let clockRoundoff=8*max(end.ulp,s.time.ulp)
            var dt=remaining<=stepBudget+clockRoundoff ? remaining : stepBudget
            var acc=gravity,angular=externalAngularAcceleration
            // Geometric broad phase: a sphere can travel at most this component-wise bound.
            let reach=V(repeating:radius+tolerance)+V(abs(s.velocity.x),abs(s.velocity.y),abs(s.velocity.z))*dt
                + V(abs(gravity.x),abs(gravity.y),abs(gravity.z))*(0.5*dt*dt)
            func query(_ reach:V)->[Int] {
                index?.query(low:s.position-reach,high:s.position+reach) ?? surfaces.indices.filter { i in
                let t=surfaces[i].triangle
                for axis in 0..<3 {
                    if max(t.a[axis],t.b[axis],t.c[axis])<s.position[axis]-reach[axis] ||
                        min(t.a[axis],t.b[axis],t.c[axis])>s.position[axis]+reach[axis] { return false }
                }
                return true
            }
            }
            var candidates=query(reach)
            // Build the whole resting manifold before changing velocity. Applying a single
            // face projection repeatedly can push the sphere into its neighbour forever.
            var support: [(index: Int, normal: V, curve: Double)] = []
            // Spatial drift tolerance is not contact activation distance. A nearby
            // triangle edge must not exert friction before the sphere touches it.
            let contactRoundoff = 64*Double.ulpOfOne*max(1,length(s.position),radius)
            for i in candidates {
                let point = surfaces[i].triangle.closestPoint(to: s.position)
                let delta = s.position-point, distance = length(delta)
                guard distance > 0, distance <= radius+contactRoundoff else { continue }
                let n = delta/distance
                let vn = dot(s.velocity,n)
                let velocityRoundoff = 64*Double.ulpOfOne*max(1,length(s.velocity))
                let curve = curvature(surfaces[i].triangle,point:point,normal:n,velocity:s.velocity)
                let restoring=max(0,-dot(gravity,n)-curve)
                // A microscopic separation can be generated by another face's
                // impulse at a resting corner. Resolve excursions below the
                // spatial budget as contact, like the existing tiny-rebound rule.
                let unresolvedRebound=vn>0 && restoring>0 && vn*vn<=2*restoring*tolerance
                guard vn <= velocityRoundoff || unresolvedRebound,
                      vn >= -sqrt(2*length(gravity)*tolerance) else { continue }
                // Another contact's reaction (or friction) can load this face
                // even when external gravity alone points away from it. Let the
                // coupled unilateral force solve determine whether it carries load.
                support.append((i,n,curve))
            }
            // Unilateral velocity projection: impulses only push, never pull toward a face.
            let resting=try PocketContactResponse.simultaneousImpact(.init(velocity:s.velocity,angularVelocity:s.omega),
                constraints:support.map { .init(normal:$0.normal,restitution:0,friction:0) },radius:radius)
            s.velocity=resting.velocity
            // Collapse only sub-resolution rebound components, not tangential
            // motion or spin. An orthogonal projection cannot add kinetic
            // energy; reject it if other unilateral constraints become invalid.
            let microSupports=support.filter { contact in
                let vn=dot(s.velocity,contact.normal)
                let restoring=max(0,-dot(gravity,contact.normal)-contact.curve)
                return restoring>0 && vn*vn<=2*restoring*tolerance
            }
            if microSupports.contains(where: { dot(s.velocity,$0.normal)>64*Double.ulpOfOne*max(1,length(s.velocity)) }) {
                // Build the common tangent space directly. Nearly parallel
                // normals can make a full projection remove substantial valid
                // tangent motion; reject that collapse using the same energy
                // budget instead of increasing an iterative projection limit.
                var basis:[V]=[]
                for contact in microSupports {
                    var axis=contact.normal
                    for n in basis { axis-=n*dot(axis,n) }
                    for n in basis { axis-=n*dot(axis,n) }
                    let magnitude=length(axis)
                    if magnitude>64*Double.ulpOfOne { basis.append(axis/magnitude) }
                }
                var projected=s.velocity
                for n in basis { projected-=n*dot(projected,n) }
                let correction=projected-s.velocity
                let rounding=64*Double.ulpOfOne*max(1,length(s.velocity))
                let feasible=support.allSatisfy { dot(projected,$0.normal)>=(-rounding) }
                if feasible && dot(correction,correction)<=2*length(gravity)*tolerance {
                    s.velocity=projected
                }
            }
            // Resolving one constraint can separate another. Only the remaining
            // zero-normal-velocity contacts may carry sustained forces.
            support.removeAll { dot(s.velocity,$0.normal) > 64*Double.ulpOfOne*max(1,length(s.velocity)) }
            for j in support.indices {
                let triangle = surfaces[support[j].index].triangle
                support[j].curve = curvature(triangle,point:triangle.closestPoint(to:s.position),
                                              normal:support[j].normal,velocity:s.velocity)
            }
            // Coincident normal constraints on mesh seams are redundant. Keep the
            // strongest acceleration bound (smallest curvature), not two forces
            // that slowly exchange load between the same physical support plane.
            let unmergedSupport=support
            support=unmergedSupport.enumerated().filter { i,c in
                !unmergedSupport.enumerated().contains { j,other in
                    j != i && length(c.normal-other.normal)<=64*Double.ulpOfOne
                        && surfaces[c.index].friction == surfaces[other.index].friction
                        && (other.curve<c.curve || (other.curve==c.curve && j<i))
                }
            }.map { $0.element }
            var normalForce = Array(repeating: 0.0, count: support.count)
            var tangentForce = Array(repeating: V.zero, count: support.count)
            // Synchronous projected contact forces, per unit mass. The tangential
            // effective inverse mass is 1 + R²/(2R²/5) = 3.5 for a solid sphere.
            var forceConverged = support.isEmpty
            var forceResidual = 0.0
            var motionResidual = 0.0
            var motionDisplacementResidual = Double.infinity
            var lastConstraintResidual = 0.0
            let relaxation=1/Double(max(1,support.count))
            // Safeguarded depth-one Anderson acceleration of the projected force
            // map. The secant extrapolation removes slow shared-load modes; it is
            // accepted only when the actual fixed-point residual decreases.
            // Solve pressure-bounded surface moments against the resulting
            // angular motion, including contact torque. Zero initial spin alone
            // does not imply zero resistance on a loaded slope.
            func resistedRotation(_ nf:[Double],_ tf:[V]) throws -> V {
                var free=externalAngularAcceleration
                for (j,c) in support.enumerated() {
                    free+=cross(-c.normal*radius,tf[j])/(0.4*radius*radius)
                }
                let active=support.indices.filter {
                    let material=surfaces[support[$0].index]
                    return nf[$0]>0 && (material.rollingFriction>0 || material.spinFriction>0)
                }
                guard !active.isEmpty else { return free }
                var moments=Array(repeating:V.zero,count:support.count)
                let weight=1/Double(active.count)
                let rounding=64*Double.ulpOfOne*max(1,length(free),length(s.omega)/dt)
                func project(_ request:V,_ j:Int)->V {
                    let n=support[j].normal,material=surfaces[support[j].index]
                    let spin=dot(request,n)
                    var tangent=request-n*spin
                    let rollLimit=3.5*material.rollingFriction*nf[j]/radius
                    let spinLimit=2.5*material.spinFriction*nf[j]/radius
                    if length(tangent)>rollLimit { tangent*=rollLimit/length(tangent) }
                    return tangent+n*max(-spinLimit,min(spinLimit,spin))
                }
                func mapped(_ values:[V])->[V] {
                    let demand=s.omega/dt+values.reduce(free,+)
                    var next=values
                    for j in active { next[j]+=weight*(project(values[j]-demand,j)-values[j]) }
                    return next
                }
                func merit(_ values:[V])->Double {
                    let next=mapped(values)
                    return active.reduce(0) { $0+dot(next[$1]-values[$1],next[$1]-values[$1]) }
                }
                var residual=Double.infinity,previousMap:[V]?,previousResidual:[V]?
                for _ in 0..<4096 {
                    let next=mapped(moments)
                    let delta=zip(next,moments).map { $0-$1 }
                    residual=(active.map { length(delta[$0])/weight }.max() ?? 0)
                    if residual<=rounding { return next.reduce(free,+) }
                    var accepted=next
                    // Near-parallel contact axes have slow redistribution modes.
                    // Use the same safeguarded secant acceleration as the outer
                    // force solve, retaining each surface's feasible capacity.
                    if let oldMap=previousMap,let oldResidual=previousResidual {
                        let difference=zip(delta,oldResidual).map { $0-$1 }
                        let denominator=active.reduce(0) { $0+dot(difference[$1],difference[$1]) }
                        if denominator>Double.leastNormalMagnitude {
                            let beta=active.reduce(0) { $0+dot(difference[$1],delta[$1]) }/denominator
                            var proposal=next
                            for j in active { proposal[j]=project(next[j]-beta*(next[j]-oldMap[j]),j) }
                            if proposal.allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite}),
                               merit(proposal)<merit(next) { accepted=proposal }
                        }
                    }
                    previousMap=next;previousResidual=delta;moments=accepted
                }
                // F(m)=|omega/dt + free + sum(m)|²/2 is convex on the product
                // of each contact's rolling disk and spin interval. For feasible
                // moments, its Frank-Wolfe gap bounds the objective error; strong
                // convexity in the summed moment gives |alpha-alpha*| <= sqrt(2g).
                // Use the same R*dt² angular-motion accuracy as the integrator,
                // rather than demanding unique, roundoff-level contact loads.
                let finalDemand=s.omega/dt+moments.reduce(free,+)
                var gap=0.0, gapScale=0.0
                for j in active {
                    let n=support[j].normal,material=surfaces[support[j].index]
                    let normalDemand=dot(finalDemand,n)
                    let tangentDemand=finalDemand-n*normalDemand
                    let capacity=3.5*material.rollingFriction*nf[j]/radius*length(tangentDemand)
                        + 2.5*material.spinFriction*nf[j]/radius*abs(normalDemand)
                    let work=dot(finalDemand,moments[j])
                    gap+=work+capacity;gapScale+=abs(work)+capacity
                }
                let gapRounding=64*Double.ulpOfOne*gapScale
                let gapBound=max(0,gap)+gapRounding
                let motionBound=radius*dt*dt*sqrt(2*gapBound)
                if gap >= -gapRounding && motionBound.isFinite && motionBound<=tolerance {
                    return moments.reduce(free,+)
                }
                throw Failure.supportConvergence(time:s.time,stage:"surface-moment",contacts:active.count,residual:residual)
            }
            func forceMap(_ nf:[Double],_ tf:[V]) throws -> ([Double],[V]) {
                var linear=gravity
                let rotation=try resistedRotation(nf,tf)
                for (j,c) in support.enumerated() {
                    linear+=c.normal*nf[j]+tf[j]
                }
                var nextN=nf,nextT=tf
                for (j,c) in support.enumerated() {
                    let n=c.normal,arm = -n*radius
                    let requestedN=max(0,nf[j]-dot(s.velocity,n)/dt-dot(linear,n)-c.curve)
                    let slipT=tangentialSlip(s,normal:n)
                    let triangle=surfaces[c.index].triangle
                    let armRate = -radius*normalRate(triangle,point:triangle.closestPoint(to:s.position),normal:n,velocity:s.velocity)
                    let contactAcceleration=linear+cross(rotation,arm)+cross(s.omega,armRate)
                    var requestedT=tf[j]-(slipT/dt+contactAcceleration-n*dot(contactAcceleration,n))/3.5
                    let limit=surfaces[c.index].friction*requestedN
                    if length(requestedT)>limit { requestedT*=limit/length(requestedT) }
                    nextN[j]+=relaxation*(requestedN-nf[j])
                    nextT[j]+=relaxation*(requestedT-tf[j])
                }
                return (nextN,nextT)
            }
            func packed(_ nf:[Double],_ tf:[V])->[Double] {
                support.indices.flatMap { [nf[$0],tf[$0].x,tf[$0].y,tf[$0].z] }
            }
            func residualSquared(_ nf:[Double],_ tf:[V]) throws -> Double {
                let m=try forceMap(nf,tf)
                return support.indices.reduce(0) { $0+pow(m.0[$1]-nf[$1],2)+dot(m.1[$1]-tf[$1],m.1[$1]-tf[$1]) }
            }
            var previousMap:[Double]?,previousResidual:[Double]?
            for _ in 0..<4096 {
                let mapped=try forceMap(normalForce,tangentForce)
                var nextNormal=mapped.0,nextTangent=mapped.1
                let values=packed(normalForce,tangentForce),mappedValues=packed(mapped.0,mapped.1)
                let residual=zip(mappedValues,values).map { $0-$1 }
                let change=support.indices.map { max(abs(nextNormal[$0]-normalForce[$0]),length(nextTangent[$0]-tangentForce[$0]))/relaxation }.max() ?? 0
                if let oldMap=previousMap,let oldResidual=previousResidual {
                    let difference=zip(residual,oldResidual).map { $0-$1 }
                    let denominator=difference.reduce(0) { $0+$1*$1 }
                    if denominator>Double.leastNormalMagnitude {
                        let beta=zip(difference,residual).reduce(0) { $0+$1.0*$1.1 }/denominator
                        let proposal=zip(mappedValues,oldMap).map { $0-beta*($0-$1) }
                        if proposal.allSatisfy({$0.isFinite}) {
                            var trialN=nextNormal,trialT=nextTangent
                            for (j,c) in support.enumerated() {
                                trialN[j]=max(0,proposal[4*j])
                                var t=V(proposal[4*j+1],proposal[4*j+2],proposal[4*j+3])
                                t-=c.normal*dot(t,c.normal)
                                let limit=surfaces[c.index].friction*trialN[j]
                                if length(t)>limit { t*=limit/length(t) }
                                trialT[j]=t
                            }
                            if try residualSquared(trialN,trialT)<residualSquared(nextNormal,nextTangent) {
                                nextNormal=trialN;nextTangent=trialT
                            }
                        }
                    }
                }
                // A nearly neutral force redistribution can stall Anderson
                // acceleration before a friction constraint becomes active.
                // Follow the current feasible ray to its first cone boundary;
                // accept only an actual residual reduction, never a new model.
                var boundary=Double.infinity
                for (j,c) in support.enumerated() {
                    let n=normalForce[j],dn=mapped.0[j]-n
                    let t=tangentForce[j],dT=mapped.1[j]-t
                    if dn<0 { boundary=min(boundary,-n/dn) }
                    let mu=surfaces[c.index].friction
                    let a=dot(dT,dT)-mu*mu*dn*dn
                    let b=2*(dot(t,dT)-mu*mu*n*dn)
                    let c0=dot(t,t)-mu*mu*n*n
                    let scale=max(abs(a),abs(b),abs(c0))
                    guard scale>0,scale.isFinite else { continue }
                    let aa=a/scale,bb=b/scale,cc=c0/scale
                    var roots:[Double]=[]
                    if aa == 0 {
                        if bb != 0 { roots=[-cc/bb] }
                    } else {
                        let discriminant=bb*bb-4*aa*cc
                        if discriminant>=0 {
                            let q = -0.5*(bb+(bb>=0 ? 1 : -1)*sqrt(discriminant))
                            roots=q == 0 ? [0] : [q/aa,cc/q]
                        }
                    }
                    for alpha in roots where alpha.isFinite && alpha>1 && bb+2*aa*alpha>0 {
                        boundary=min(boundary,alpha)
                    }
                }
                if boundary.isFinite,boundary>1 {
                    var trialN=normalForce,trialT=tangentForce
                    for (j,c) in support.enumerated() {
                        trialN[j]=max(0,normalForce[j]+boundary*(mapped.0[j]-normalForce[j]))
                        var t=tangentForce[j]+boundary*(mapped.1[j]-tangentForce[j])
                        t-=c.normal*dot(t,c.normal)
                        let limit=surfaces[c.index].friction*trialN[j]
                        if length(t)>limit { t*=limit/length(t) }
                        trialT[j]=t
                    }
                    if try residualSquared(trialN,trialT)<min(residualSquared(nextNormal,nextTangent),residualSquared(normalForce,tangentForce)) {
                        nextNormal=trialN;nextTangent=trialT
                    }
                }
                previousMap=mappedValues;previousResidual=residual
                let previousAcceleration=acc,previousAngular=angular
                normalForce=nextNormal;tangentForce=nextTangent
                acc=gravity;angular = try resistedRotation(normalForce,tangentForce)
                for (j,contact) in support.enumerated() {
                    acc+=contact.normal*normalForce[j]+tangentForce[j]
                }
                // These residuals have acceleration units (force per unit mass).
                // Use a relative residual against the actual linear/angular load;
                // the independent spatial/energy budgets still govern each step.
                let forceScale=max(1,length(gravity),length(acc),radius*length(angular))
                motionResidual=max(length(acc-previousAcceleration),radius*length(angular-previousAngular))/forceScale
                motionDisplacementResidual=0.5*motionResidual*forceScale*convergenceHorizon*convergenceHorizon
                forceResidual = change/forceScale
                var constraintResidual=0.0
                for (j,contact) in support.enumerated() {
                    let n=contact.normal,arm = -n*radius
                    let normalAcceleration=dot(s.velocity,n)/dt+dot(acc,n)+contact.curve
                    constraintResidual=max(constraintResidual,normalForce[j]>0 ? abs(normalAcceleration) : max(0,-normalAcceleration))
                    let triangle=surfaces[contact.index].triangle
                    let armRate = -radius*normalRate(triangle,point:triangle.closestPoint(to:s.position),normal:n,velocity:s.velocity)
                    let slipT=tangentialSlip(s,normal:n)
                    let contactAcceleration=acc+cross(angular,arm)+cross(s.omega,armRate)
                    let request=slipT/dt+contactAcceleration-n*dot(contactAcceleration,n)
                    var projected=tangentForce[j]-request/3.5
                    let limit=surfaces[contact.index].friction*normalForce[j]
                    if length(projected)>limit { projected*=limit/length(projected) }
                    constraintResidual=max(constraintResidual,3.5*length(projected-tangentForce[j]))
                }
                lastConstraintResidual=constraintResidual
                // Internal force distributions can be non-unique. Require stable
                // rigid-body motion AND feasible contact constraints. Convert the
                // acceleration residual to a full-interval displacement budget.
                // The contact map divides slip velocity by dt. Near a step end,
                // velocity roundoff therefore sets a floor on its relative
                // acceleration residual; a fixed threshold can be unattainable.
                let velocityRoundoff=64*Double.ulpOfOne*max(1,length(s.velocity),radius*length(s.omega))
                let motionRoundoff=velocityRoundoff/(dt*forceScale)
                if motionResidual<max(1e-10,motionRoundoff) && 0.5*constraintResidual*convergenceHorizon*convergenceHorizon<=tolerance {
                    forceConverged=true;break
                }
            }
            // Non-unique contact loads can keep redistributing after the
            // observable motion and feasible constraints meet the requested
            // accuracy. Preserve the strict solve first, then check both errors
            // in metres rather than failing solely on a relative force delta.
            if !forceConverged,motionDisplacementResidual<=tolerance,
               0.5*lastConstraintResidual*convergenceHorizon*convergenceHorizon<=tolerance {
                forceConverged=true
            }
            guard forceConverged else {
                print("[W05 generalized residual] time=\(s.time) force=\(forceResidual) motion=\(motionResidual) constraint=\(lastConstraintResidual) dt=\(dt) state=\(s) acc=\(acc) alpha=\(angular)")
                for (j,contact) in support.enumerated() {
                    let point = surfaces[contact.index].triangle.closestPoint(to:s.position)
                    print("[W05 support diagnostic] time=\(s.time) face=\(contact.index) gap=\(length(s.position-point)-radius) n=\(contact.normal) curve=\(contact.curve) vn=\(dot(s.velocity,contact.normal)) fn=\(normalForce[j]) ft=\(tangentForce[j])")
                }
                throw Failure.supportConvergence(time:s.time,stage:"force",contacts:support.count,residual:forceResidual)
            }
            let loadedSupport=support.enumerated().filter { normalForce[$0.offset]>0 }.map { $0.element }
            let supported=Set(loadedSupport.map { $0.index })
            for contact in loadedSupport {
                let n = contact.normal, arm = -n*radius
                let slipT=tangentialSlip(s,normal:n)
                let patch=surfaces[contact.index].triangle
                let armRate = -radius*normalRate(patch,point:patch.closestPoint(to:s.position),normal:n,velocity:s.velocity)
                let change = acc+cross(angular,arm)+cross(s.omega,armRate)
                if dot(slipT,change) < 0 {
                    let stop = -dot(slipT,slipT)/dot(slipT,change)
                    if stop > 1e-10 { dt = min(dt,stop) }
                }
                let triangle=surfaces[contact.index].triangle
                let raw=cross(triangle.b-triangle.a,triangle.c-triangle.a)
                let magnitude=length(raw)
                guard magnitude>0 else { continue }
                let face=raw/magnitude
                guard length(cross(face,n))<1e-8 else { continue }
                // The signed in-plane edge coordinate is quadratic in time.
                // Stop exactly at an outward crossing, including internal mesh seams.
                for (a,b) in [(triangle.a,triangle.b),(triangle.b,triangle.c),(triangle.c,triangle.a)] {
                    let edge=b-a
                    let c=dot(cross(edge,s.position-a),face)
                    let bTerm=dot(cross(edge,s.velocity),face)
                    let aTerm=0.5*dot(cross(edge,acc),face)
                    for t in QuarticSolver.solveQuadraticPublic(a:aTerm,b:bTerm,c:c) {
                        if t>64*Double.ulpOfOne*max(1,abs(s.time)), t<dt, bTerm+2*aTerm*t<0 { dt=t }
                    }
                }
            }
            // Support/friction can redirect acceleration into horizontal axes.
            // Requery using the actual solved trajectory before continuous tests.
            let solvedReach=V(repeating:radius+tolerance)+V(abs(s.velocity.x),abs(s.velocity.y),abs(s.velocity.z))*dt
                + V(abs(acc.x),abs(acc.y),abs(acc.z))*(0.5*dt*dt)
            candidates=query(solvedReach)
            var first:(Int,PocketContactTriangle.Hit)?
            var hits: [(Int,PocketContactTriangle.Hit)] = []
            for i in candidates where !supported.contains(i) {
                if let hit=surfaces[i].triangle.firstContact(position:s.position,velocity:s.velocity,
                    acceleration:acc,radius:radius,horizon:dt) {
                    hits.append((i,hit))
                    if first == nil || hit.time<first!.1.time { first=(i,hit) }
                }
            }
            #if DEBUG
            if iterations == maxIterations {
                print("[W07 bounded contact diagnostic] state=\(s) acc=\(acc) support=\(support) forces=\(normalForce) first=\(String(describing:first))")
                for (i, _) in hits {
                    let p=surfaces[i].triangle.closestPoint(to:s.position)
                    print("[W07 bounded contact face] index=\(i) gap=\(length(s.position-p)-radius) triangle=\(surfaces[i].triangle)")
                }
            }
            #endif
            let simultaneous=first.map { earliest in
                hits.filter { abs($0.1.time-earliest.1.time)<=64*Double.ulpOfOne*max(1,abs(s.time)) }
            } ?? []
            let step=first?.1.time ?? dt
            let intervalStart=s
            s.position+=s.velocity*step+acc*(0.5*step*step)
            s.velocity+=acc*step;s.omega+=angular*step;s.time+=step
            if first != nil {
                let constraints=simultaneous.map { i,hit in
                    let restitution=surfaces[i].restitution
                    let rebound=max(0,-dot(s.velocity,hit.normal))*restitution
                    let restoringGravity=max(0,-dot(gravity,hit.normal))
                    let effectiveRestitution=restoringGravity>0 && rebound*rebound<=2*restoringGravity*tolerance ? 0 : restitution
                    return PocketContactResponse.ImpactConstraint(normal:hit.normal,restitution:effectiveRestitution,friction:surfaces[i].friction)
                }
                // Liner grip is decided on the pre-impact approach, then applied after the rigid solve.
                let liners=simultaneous.filter { i,hit in
                    surfaces[i].tangentialRetention<1 && dot(s.velocity,hit.normal)<0
                }
                var motion=try PocketContactResponse.simultaneousImpact(.init(velocity:s.velocity,angularVelocity:s.omega),
                                                                         constraints:constraints,radius:radius)
                for (i,hit) in liners {
                    motion=PocketContactResponse.linerSink(motion,normal:hit.normal,retention:surfaces[i].tangentialRetention)
                }
                s.velocity=motion.velocity;s.omega=motion.angularVelocity
                for (i,hit) in simultaneous { contacts.append(Contact(time:s.time,surface:i,normal:hit.normal)) }
            }
            // Bound accumulated constraint drift; large overlap is a failed solve, never teleportation.
            var rejectedCorrection: Double?
            if first == nil {
                let hasPressure=normalForce.contains { $0>0 }
                // Compare squared distances by their difference, without first
                // adding the common radius squared. Near mesh seams that sum
                // hides real tangential separation and invents extra supports.
                func distanceDifference(_ a:V,_ b:V)->(value:Double,error:Double) {
                    let difference=b-a,sum=(s.position-a)+(s.position-b)
                    let products=difference*sum
                    let scale=max(1,length(s.position),length(a),length(b))
                    return (dot(difference,sum),64*Double.ulpOfOne*(
                        abs(products.x)+abs(products.y)+abs(products.z)+length(difference)*scale))
                }
                func projectionManifold()->[Int] {
                    guard hasPressure else { return [] }
                    let witnesses=candidates.map { ($0,surfaces[$0].triangle.closestPoint(to:s.position)) }
                    let nearest=witnesses.min { distanceDifference($0.1,$1.1).value<0 }
                    let nearestIndices=nearest.map { best in witnesses.filter {
                        let comparison=distanceDifference($0.1,best.1)
                        return comparison.value<=comparison.error
                    }.map { $0.0 } } ?? []
                    return exposedSupportCandidates(nearestIndices,at:s.position)
                }
                // Rebuild the geometric manifold at the new position. An old
                // support triangle may have ended at an internal mesh seam.
                var active=projectionManifold()
                var projectionConverged=active.isEmpty,projectionResidual=0.0
                for _ in 0..<128 {
                    active=projectionManifold()
                    var positionChange=V.zero,velocityChange=V.zero,residual=0.0,count=0
                    for index in active {
                        let triangle=surfaces[index].triangle
                        let point=triangle.closestPoint(to:s.position),delta=s.position-point,d=length(delta)
                        guard d>0 else { continue }
                        let n=delta/d
                        // The solved manifold, not external gravity alone,
                        // determines support. A floor reaction may load an
                        // overhanging face even when gravity points away from it.
                        let correction=abs(radius-d)
                        if correction>tolerance*4 { rejectedCorrection=correction; break }
                        maxCorrection=max(maxCorrection,correction)
                        positionChange+=n*(radius-d)
                        velocityChange-=n*dot(s.velocity,n)
                        residual=max(residual,correction,abs(dot(s.velocity,n)))
                        count+=1
                    }
                    if rejectedCorrection != nil || count==0 { projectionConverged=true; break }
                    s.position+=positionChange/Double(count)
                    s.velocity+=velocityChange/Double(count)
                    projectionResidual=residual
                    if residual<64*Double.ulpOfOne*max(1,length(s.position),length(s.velocity)) { projectionConverged=true; break }
                }
                if !projectionConverged,rejectedCorrection == nil {
                    // Try machine precision first. If projections stagnate,
                    // measure the final manifold against the solver's declared
                    // spatial budget; convert normal speed to displacement over
                    // the same convergence horizon used by the force solve.
                    let witnesses=projectionManifold()
                    projectionConverged = !witnesses.isEmpty && witnesses.allSatisfy { index in
                        let delta=s.position-surfaces[index].triangle.closestPoint(to:s.position)
                        let distance=length(delta)
                        return distance>0 && abs(distance-radius)<=tolerance &&
                            abs(dot(s.velocity,delta/distance))*convergenceHorizon<=tolerance
                    }
                }
                guard projectionConverged else {
                    #if DEBUG
                    print("[W06 support projection geometry] state=\(s) faces=\(active.map{surfaces[$0].triangle})")
                    #endif
                    throw Failure.supportConvergence(time:s.time,stage:"projection",contacts:active.count,residual:projectionResidual)
                }
            }
            for i in candidates {
                let point=surfaces[i].triangle.closestPoint(to:s.position),delta=s.position-point,d=length(delta)
                if d>0 && d<radius {
                    let correction=radius-d
                    if correction>tolerance*4 { rejectedCorrection=correction; break }
                    maxCorrection=max(maxCorrection,correction)
                    s.position+=delta*(correction/d)
                }
            }
            if let correction=rejectedCorrection {
                // A rejected trial must not leak impulses, spin, time or positions
                // into the accepted trajectory. Recompute the entire contact solve.
                let reduced=step*0.5
                guard reduced>0, before.time+reduced>before.time else { throw Failure.penetration(correction) }
                let translated=before.position+before.velocity*reduced+acc*(0.5*reduced*reduced)
                guard translated != before.position else {
                    throw Failure.spatialResolution(time:before.time,step:reduced,correction:correction,position:before.position)
                }
                s=before; contacts.removeLast(contacts.count-contactCount);maxCorrection=previousCorrection
                stepBudget=reduced;rejectedSteps+=1
                continue
            }
            intervals.append(Interval(start:intervalStart,duration:step,acceleration:acc,
                                      angularAcceleration:angular,end:s))
            history.append(s)
            stepBudget=min(maxStep,stepBudget*2)
        }
        return Result(states:history,contacts:contacts,maxCorrection:maxCorrection,rejectedSteps:rejectedSteps,intervals:intervals)
    }
}
