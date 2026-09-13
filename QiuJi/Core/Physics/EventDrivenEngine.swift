//
//  EventDrivenEngine.swift
//  BilliardTrainer
//
//  Event-driven physics engine implementing P3.1-P3.4
//

import Foundation
import SceneKit

// MARK: - Event-Driven Engine

/// Event-driven physics engine for billiard simulation
class EventDrivenEngine {
    /// Why the requested simulation stopped; a time/event limit is not a rest state.
    enum Termination: Equatable {
        case settled, timeLimit, eventLimit, contactResolved, interestResolved, candidateRejected
        case failed(String)
    }

    enum SimulationModel: Equatable {
        case planarReference
        case localPockets(material:PocketStaticMaterial)

        /// Shared immutable policy for prediction, search, break shots and rule
        /// decisions. v63 W17-A (user decision, 2026-09-14): pocket outcome is
        /// decided by the planar rule "ball centre inside the drop circle", the
        /// criterion all existing solvers were built and calibrated against.
        /// Spatial pocket physics is presentation-only (W17-B/D) and must never
        /// feed back into a verdict. Explicit `spatialPockets` remains available
        /// for that presentation pass and for its own regression tests.
        static let appDefault: SimulationModel = .planarReference
        /// Local spatial pocket solver (DR-292 liner sink, soft-bag capture).
        /// Cloth vertical restitution is the v63 candidate; device calibration is separate.
        static let spatialPockets: SimulationModel = .localPockets(material: .tablePhysics(clothRestitution: 0.3))
    }

    /// Shared prediction entry. A failed local solve never silently substitutes
    /// the planar pocket rule or publishes a successful termination.
    @discardableResult
    func simulatePrediction(model:SimulationModel,maxEvents:Int=1000,maxTime:Float=10,
                            highFidelityBounds:Bool=false,earlyStopBallNames:Set<String>?=nil,
                            stopAfterContactBetween:(String,String)?=nil,maxLocalSteps:Int=100000,
                            rejectCushionBeforeAnyContactFor:String?=nil)->Termination {
        switch model {
        case .planarReference:
            return simulate(maxEvents:maxEvents,maxTime:maxTime,highFidelityBounds:highFidelityBounds,
                earlyStopBallNames:earlyStopBallNames,stopAfterContactBetween:stopAfterContactBetween,
                rejectCushionBeforeAnyContactFor:rejectCushionBeforeAnyContactFor)
        case .localPockets(let material):
            do {
                if spatialTime == nil { separateOverlappingBalls(maxIterations:50) }
                return try simulateMixedWithLocalPockets(maxTime:Double(maxTime),
                    pairRestitution:Double(BallPhysics.restitution),pairFriction:0,maxEvents:maxLocalSteps,
                    collectsPocketedBalls:true,ballMaterial:.ballPhysics,staticMaterial:material,
                    earlyStopBallNames:earlyStopBallNames,stopAfterContactBetween:stopAfterContactBetween,
                    maxResolvedEvents:maxEvents,rejectCushionBeforeAnyContactFor:rejectCushionBeforeAnyContactFor)
            } catch {
                let diagnostic=String(describing:error)
                print("[Physics] Local prediction failed: \(diagnostic)")
                return .failed(diagnostic)
            }
        }
    }

    /// Presentation-only completion after a bounded simulation. This is not an
    /// extension of the collision search budget: all remaining motion must be
    /// independent cloth-normal spin, with no pending spatial ownership.
    func completePlanarSpinTail(after termination: Termination, surfaceY: Float) -> Termination {
        guard termination == .timeLimit, localOwnership.entries.isEmpty,
              pendingLocalResult == nil else { return termination }
        if let pending = pendingMixedStep {
            guard pending.predictions.isEmpty, pending.staticContacts.isEmpty, pending.localEnd.isEmpty,
                  pending.promoted.isEmpty, pending.pairEvents.isEmpty, pending.entry == nil,
                  pending.capture == nil else { return termination }
            if let event = pending.event {
                guard case .transition(_, .spinning, .stationary) = event.type else { return termination }
            }
        }
        let active = ballOrder.compactMap { balls[$0] }.filter { !$0.isPocketed }
        guard !active.isEmpty, active.allSatisfy({ ball in
            (ball.state == .stationary || ball.state == .spinning) &&
            ball.velocity.x == 0 && ball.velocity.y == 0 && ball.velocity.z == 0 &&
            ball.angularVelocity.x == 0 && ball.angularVelocity.z == 0 &&
            ball.angularVelocity.y.isFinite && ball.position.y == surfaceY + BallPhysics.radius
        }) else { return termination }
        do {
            let asset = try PocketGeometryAsset.load()
            guard active.allSatisfy({ ball in
                let point = SIMD3<Double>(Double(ball.position.x), Double(ball.position.y), Double(ball.position.z))
                return !asset.regionsByPocketID.values.contains { $0.contains(point) }
            }) else { return termination }
        } catch {
            return .failed("Spin tail geometry: \(error)")
        }
        let start = currentTime
        var stops: [(name: String, dt: Float)] = []
        for ball in active where ball.state == .spinning {
            stops.append((ball.name, AnalyticalMotion.spinToStationaryTime(angularVelocity: ball.angularVelocity)))
        }
        stops.sort { left, right in
            if left.dt == right.dt { return left.name < right.name }
            return left.dt < right.dt
        }
        guard !stops.isEmpty, stops.allSatisfy({ $0.dt.isFinite && $0.dt >= 0 && (start + $0.dt).isFinite }) else {
            return termination
        }
        // Any retained mixed step now contains only the same analytic spin
        // transitions. Rebuild them from the committed state, never replay it.
        pendingMixedStep = nil
        recordSnapshot()
        for stop in stops {
            let end = start + stop.dt
            for name in ballOrder {
                if let ball = balls[name] { balls[name] = evolvePlanarBall(ball, dt: end - currentTime) }
            }
            currentTime = end
            if spatialTime != nil { spatialTime = Double(end) }
            resolveEvent(PhysicsEvent(type: .transition(ball: stop.name, fromState: .spinning, toState: .stationary),
                                      time: 0, priority: 2))
            recordSnapshot()
        }
        eventCache.clear()
        return .settled
    }

    // Ball states indexed by name
    private var balls: [String: BallState] = [:]

    /// 球名的**插入有序**列表（D-A3 第三梯队：引擎遍历确定性化）。
    /// Swift `Dictionary` 的遍历顺序受每次进程启动的哈希种子随机化影响——同一输入两次运行
    /// 字典遍历顺序可能不同。引擎多处在遍历后做「取最早事件 `candidates.min()`」「按 names 顺序
    /// 逐对推开重叠球」等**对顺序敏感**的操作（min() 在并列时返回首个、separate 顺序影响逐次推位），
    /// 字典随机序会让同一杆每次预测的事件并列裁决/分离顺序漂移（FL-020 残留根因）。改为始终遍历
    /// 本插入有序列表（与 `setBall` 调用顺序一致、跨运行稳定），即可消除该路径的非确定性。
    private var ballOrder: [String] = []

    // Current simulation time
    private(set) var currentTime: Float = 0
    private var localOwnership=LocalPocketOwnership()
    private var pendingLocalResult:(revision:UInt64,pocketID:String,result:LocalPocketSimulation.Result)?
    private struct SpatialCushionEventKey:Hashable { let ball:String;let time:Double;let cushion:Int }
    private var spatialCushionEventKeys:Set<SpatialCushionEventKey>=[]
    private struct PendingMixedStep {
        let start:Double
        let end:Double
        let predictions:[String:LocalPocketSimulation.Result]
        let staticContacts:[String:[LocalPocketSimulation.Contact]]
        let localEnd:[String:LocalPocketSimulation.State]
        let planarStart:[String:BallState]
        let planarEnd:[String:BallState]
        let promoted:[String:LocalPocketOwnership.Domain]
        let pairEvents:[PhysicsEventType]
        let entry:(name:String,id:String)?
        let event:PhysicsEvent?
        let capture:(name:String,id:String,geometryVersion:String)?
        let collectsPocketedBalls:Bool
        let ballMaterial:SpatialBallContact.MaterialSource
        let staticMaterial:PocketStaticMaterial
        let maxStep:Double
        let restitution:Double
        let friction:Double
        let inputRevision:UInt64
        var revisions:[String:UInt64]
        var emittedStaticCounts:[String:Int] = [:]
    }
    private var pendingMixedStep:PendingMixedStep?
    private var ballInputRevision:UInt64=0
    private(set) var spatialTime:Double?

    enum LocalIntegrationFailure:Error {
        case invalidInput, groupIntegrationPending, geometryMismatch, eventBudget, uncoveredCapture
    }

    struct LocalPlanarContact {
        let localBall:String
        let planarBall:String
        let time:Double
        let normal:SIMD3<Double> // local ball -> planar ball
        let localState:LocalPocketSimulation.State
        let planarState:LocalPocketSimulation.State
    }

    /// Speculative cross-owner CCD. The caller must resolve the earlier planar
    /// event first, then rebuild; these predictions never cross that event.
    func firstLocalPlanarContact(local:[String:LocalPocketSimulation.Result],until:Double) throws -> LocalPlanarContact? {
        typealias V=SIMD3<Double>
        func vector(_ v:SCNVector3)->V { V(Double(v.x),Double(v.y),Double(v.z)) }
        let time=spatialTime ?? Double(currentTime)
        guard until.isFinite,until>time,Float(until-time).isFinite,
              Set(local.keys).isSubset(of:Set(ballOrder)) else { throw LocalIntegrationFailure.invalidInput }
        let owners=Set(local.keys)
        let next=findNextEvent(maxTimeRemaining:Float(until-time),excluding:owners)
        let end=min(until,time+Double(next?.time ?? .infinity))
        guard end>time else { return nil }
        for result in local.values {
            guard result.states.first?.time==time,let last=result.states.last,last.time>=end else {
                throw LocalIntegrationFailure.invalidInput
            }
        }
        var earliest:LocalPlanarContact?
        for name in ballOrder where !owners.contains(name) {
            guard let ball=balls[name],!ball.isPocketed else { continue }
            let start=LocalPocketSimulation.State(time:time,position:vector(ball.position),velocity:vector(ball.velocity),
                omega:vector(ball.angularVelocity))
            let evolved=evolvePlanarBall(ball,dt:Float(end-time))
            let finish=LocalPocketSimulation.State(time:end,position:vector(evolved.position),velocity:vector(evolved.velocity),
                omega:vector(evolved.angularVelocity))
            let span=LocalPocketSimulation.Interval(start:start,duration:end-time,
                acceleration:vector(EngineNumerics.acceleration(for:ball)),angularAcceleration:.zero,end:finish)
            let planar=LocalPocketSimulation.Result(states:[start,finish],contacts:[],maxCorrection:0,rejectedSteps:0,intervals:[span])
            for localName in ballOrder {
                guard let prediction=local[localName],let hit=try LocalPocketSimulation.firstPairContact(prediction,planar,radius:Double(BallPhysics.radius)),
                      hit.time<(earliest?.time ?? .infinity) else { continue }
                var planarState=hit.b
                // Spin decay can finish inside a rolling segment. Query the
                // actual planar equation at impact instead of interpolating it.
                planarState.omega=vector(evolvePlanarBall(ball,dt:Float(hit.time-time)).angularVelocity)
                earliest=LocalPlanarContact(localBall:localName,planarBall:name,time:hit.time,normal:hit.normal,
                    localState:hit.a,planarState:planarState)
            }
        }
        return earliest
    }

    /// W06 integration seam. Explicit opt-in while mixed-group scheduling and
    /// authoritative capture are still under validation; the public App path
    /// is not switched until those requirements are complete.
    func simulateWithLocalPockets(maxTime:Double,maxLocalStep:Double=0.0025,maxEvents:Int=10000) throws {
        typealias V=SIMD3<Double>
        func vector(_ v:SCNVector3)->V { V(Double(v.x),Double(v.y),Double(v.z)) }
        func scene(_ v:V)->SCNVector3 { SCNVector3(Float(v.x),Float(v.y),Float(v.z)) }
        let initialTime=spatialTime ?? Double(currentTime)
        guard maxTime.isFinite,Float(maxTime).isFinite,maxTime>=initialTime,maxLocalStep.isFinite,maxLocalStep>0,maxEvents>0 else {
            throw LocalIntegrationFailure.invalidInput
        }
        // Never silently run independent spatial balls while omitting their
        // contacts. This restriction is removed with the shared-group step.
        guard pendingMixedStep == nil else { throw LocalPocketOwnership.Failure.staleUpdate }
        guard ballOrder.count == 1,let name=ballOrder.first else { throw LocalIntegrationFailure.groupIntegrationPending }
        guard maxTime>initialTime else { return }
        let asset=try PocketGeometryAsset.load()
        guard Set(asset.regionsByPocketID.keys)==Set(tableGeometry.pockets.map(\.id)),
              tableGeometry.pockets.allSatisfy({ pocket in
                  guard let region=asset.regionsByPocketID[pocket.id] else { return false }
                  return region.center.x==Double(pocket.center.x) && region.center.z==Double(pocket.center.z)
              }) else { throw LocalIntegrationFailure.geometryMismatch }
        var time=initialTime,epochs=0
        var solvers:[String:LocalPocketSimulation]=[:]
        func solver(_ id:String) throws -> LocalPocketSimulation {
            if let value=solvers[id] { return value }
            guard let mesh=asset.pockets.first(where:{$0.pocketID==id}) else { throw LocalIntegrationFailure.geometryMismatch }
            let value=LocalPocketSimulation(surfaces:mesh.patches.map{.init(triangle:$0.triangle,restitution:0.3,friction:0.2)},
                radius:Double(BallPhysics.radius),gravity:V(0,-Double(TablePhysics.gravity),0),tolerance:1e-6)
            solvers[id]=value;return value
        }
        func publish(_ state:LocalPocketSimulation.State) {
            guard var ball=balls[name] else { return }
            ball.position=scene(state.position);ball.velocity=scene(state.velocity);ball.angularVelocity=scene(state.omega)
            // Motion phase remains in localOwnership; this compatibility mirror
            // must not be used to evolve or capture the spatial ball.
            ball.state = .sliding;balls[name]=ball
            time=state.time;spatialTime=time;currentTime=Float(time)
        }
        recordSnapshot()
        while time<maxTime {
            epochs+=1
            guard epochs<=maxEvents else { throw LocalIntegrationFailure.eventBudget }
            if let owner=localOwnership.entries[name] {
                guard let pocketID=owner.pocketID,let region=asset.regionsByPocketID[pocketID] else { throw LocalIntegrationFailure.geometryMismatch }
                let local=try solver(pocketID)
                if pendingLocalResult == nil,let returned=try localOwnership.returnToPlanar(ballName:name,pocketID:pocketID,
                    revision:owner.revision,solver:local,region:region,surfaceY:Double(asset.surfaceY)) {
                    publish(returned)
                    var ball=balls[name]!
                    ball.state=EngineNumerics.determineMotionState(ball);balls[name]=ball
                    trajectoryRecorder.recordLocalHandoff(.init(ballName:name,pocketID:pocketID,kind:.returned,state:returned))
                    eventCache.clear();recordSnapshot();continue
                }
                let dt=maxLocalStep
                var result:LocalPocketSimulation.Result
                if let pending=pendingLocalResult {
                    guard pending.revision==owner.revision,pending.pocketID==owner.pocketID else {
                        throw LocalPocketOwnership.Failure.staleUpdate
                    }
                    result=pending.result
                } else {
                    do { result=try local.run(from:owner.state,duration:dt,maxStep:maxLocalStep) }
                    catch {
                        #if DEBUG
                        print("[W06 engine local failure] pocket=\(owner.pocketID) state=\(owner.state) dt=\(dt) error=\(error)")
                        #endif
                        throw error
                    }
                    // Cut the speculative local path at its first outgoing
                    // boundary. The next iteration checks actual support.
                    var crossing:Double?
                    for span in result.intervals {
                        if let t=region.firstCrossing(position:span.start.position,velocity:span.start.velocity,
                            acceleration:span.acceleration,horizon:span.duration,direction:.leaving) {
                            let absolute=span.start.time+t
                            if absolute>time { crossing=absolute;break }
                        }
                    }
                    if let crossing,crossing<time+dt {
                        result=try local.run(from:owner.state,duration:crossing-time,maxStep:maxLocalStep)
                    }
                }
                guard let predictedEnd=result.states.last else { throw LocalIntegrationFailure.eventBudget }
                let acceptedTime=min(predictedEnd.time,maxTime)
                var accepted:[LocalPocketSimulation.Interval]=[]
                for span in result.intervals {
                    let begin=max(time,span.start.time),end=min(acceptedTime,span.end.time)
                    guard end>begin,let start=span.sample(at:begin),let finish=span.sample(at:end) else { continue }
                    accepted.append(.init(start:start,duration:end-begin,acceleration:span.acceleration,
                        angularAcceleration:span.angularAcceleration,end:finish))
                }
                guard let end=accepted.last?.end,end.time>time else { throw LocalIntegrationFailure.eventBudget }
                try localOwnership.commit(states:[name:end],revisions:[name:owner.revision])
                if acceptedTime<predictedEnd.time {
                    pendingLocalResult=(localOwnership.entries[name]!.revision,pocketID,result)
                } else { pendingLocalResult=nil }
                trajectoryRecorder.recordLocalIntervals(ballName:name,intervals:accepted)
                publish(end);recordSnapshot();continue
            }
            guard let ball=balls[name],!ball.isPocketed else { break }
            let remaining=maxTime-time
            let acceleration=EngineNumerics.acceleration(for:ball)
            let p=vector(ball.position),v=vector(ball.velocity),a=vector(acceleration)
            var entry:(id:String,dt:Double)?
            for mesh in asset.pockets {
                let region=asset.regionsByPocketID[mesh.pocketID]!
                let departure=region.firstCrossing(position:p,velocity:v,acceleration:a,horizon:remaining,direction:.leaving)
                let crossing=region.contains(p) && departure != 0 ? 0 :
                    region.firstCrossing(position:p,velocity:v,acceleration:a,horizon:remaining,direction:.entering)
                if let crossing,crossing<=remaining,crossing<(entry?.dt ?? .infinity) { entry=(mesh.pocketID,crossing) }
            }
            if entry == nil && ball.state == .stationary { break }
            eventCache.clear()
            let event=findNextEvent(maxTimeRemaining:Float(remaining),excluding:Set(localOwnership.entries.keys))
            let enter=entry.map{$0.dt<=Double(event?.time ?? .infinity)} ?? false
            let dt=enter ? entry!.dt : min(remaining,Double(event?.time ?? .infinity))
            if dt>0 { balls[name]=evolvePlanarBall(ball,dt:Float(dt));time+=dt;currentTime=Float(time);spatialTime=time }
            if enter,let entry {
                let evolved=balls[name]!
                let state=LocalPocketSimulation.State(time:time,position:p+v*dt+a*(0.5*dt*dt),
                    velocity:vector(evolved.velocity),omega:vector(evolved.angularVelocity))
                try localOwnership.enter(ballName:name,pocketID:entry.id,state:state)
                trajectoryRecorder.recordLocalHandoff(.init(ballName:name,pocketID:entry.id,kind:.entered,state:state))
                publish(state)
            } else if let event,Double(event.time)<=dt {
                if case .pocket=event.type { throw LocalIntegrationFailure.uncoveredCapture }
                resolveEvent(event)
            }
            recordSnapshot()
        }
        spatialTime=time;currentTime=Float(time)
    }
    
    /// Mixed-group validation entry. Contact coefficients are explicit until
    /// the spatial material contract is calibrated for production rollout.
    /// Constraint normals point B -> A. Match the cross-owner event contract:
    /// resting or separating support is not a new rule-level collision.
    static func spatialImpactEvents(names:[String],incoming:[LocalPocketSimulation.State],
                                    constraints:[SpatialBallContact.Constraint])->[PhysicsEventType] {
        constraints.compactMap { c in
            guard let b=c.b else { return nil }
            let relative=incoming[c.a].velocity-incoming[b].velocity
            let closing=relative.x*c.normal.x+relative.y*c.normal.y+relative.z*c.normal.z
            guard closing<0 else { return nil }
            return .ballBall(ballA:names[c.a],ballB:names[b])
        }
    }

    @discardableResult
    func simulateMixedWithLocalPockets(maxTime:Double,maxStep:Double=0.0025,
                                      pairRestitution:Double,pairFriction:Double,maxEvents:Int=100000,
                                      collectsPocketedBalls:Bool=false,
                                      ballMaterial:SpatialBallContact.MaterialSource = .supplied,
                                      staticMaterial:PocketStaticMaterial = .prototype,
                                      earlyStopBallNames:Set<String>? = nil,
                                      stopAfterContactBetween:(String,String)? = nil,
                                      maxResolvedEvents:Int? = nil,
                                      rejectCushionBeforeAnyContactFor:String? = nil) throws -> Termination {
        typealias V=SIMD3<Double>
        typealias State=LocalPocketSimulation.State
        func v(_ x:SCNVector3)->V { V(Double(x.x),Double(x.y),Double(x.z)) }
        func scn(_ x:V)->SCNVector3 { SCNVector3(Float(x.x),Float(x.y),Float(x.z)) }
        func length(_ x:V)->Double { sqrt(x.x*x.x+x.y*x.y+x.z*x.z) }
        var time=spatialTime ?? Double(currentTime)
        guard maxTime.isFinite,maxTime>=time,Float(maxTime).isFinite,maxStep.isFinite,maxStep>0,maxEvents>0,
              pairRestitution.isFinite,(0...1).contains(pairRestitution),pairFriction.isFinite,pairFriction>=0,
              pendingLocalResult == nil,(maxResolvedEvents ?? 0)>=0 else { throw LocalIntegrationFailure.invalidInput }
        guard time<maxTime else { return .timeLimit }
        let asset=try PocketGeometryAsset.load(),radius=Double(BallPhysics.radius)
        let surfaceRoles=try asset.surfaceRoles()
        let collection=collectsPocketedBalls ? try asset.captureBoundaries() : [:]
        guard Set(asset.regionsByPocketID.keys)==Set(tableGeometry.pockets.map(\.id)),
              tableGeometry.pockets.allSatisfy({p in
                  guard let r=asset.regionsByPocketID[p.id] else { return false }
                  return r.center.x==Double(p.center.x) && r.center.z==Double(p.center.z)
              }) else { throw LocalIntegrationFailure.geometryMismatch }
        let solver=try asset.localSimulation(material:staticMaterial,ballMaterial:ballMaterial)
        func state(_ ball:BallState,at t:Double)->State {
            .init(time:t,position:v(ball.position),velocity:v(ball.velocity),omega:v(ball.angularVelocity))
        }
        func mirror(_ name:String,_ s:State) {
            var ball=balls[name]!
            ball.position=scn(s.position);ball.velocity=scn(s.velocity);ball.angularVelocity=scn(s.omega)
            ball.state = .sliding;balls[name]=ball
        }
        if pendingMixedStep == nil {
            for name in ballOrder where localOwnership.entries[name] == nil {
                guard let ball=balls[name],!ball.isPocketed else { continue }
                let heightError=abs(Double(ball.position.y)-(Double(asset.surfaceY)+radius))
                if ball.velocity.y != 0 || heightError>4*solver.tolerance {
                    let initial=state(ball,at:time)
                    try localOwnership.enter(ballName:name,domain:.airborne,state:initial)
                    trajectoryRecorder.recordLocalHandoff(.init(ballName:name,domain:.airborne,kind:.entered,state:initial))
                }
            }
        }
        func affected(_ type:PhysicsEventType)->Set<String> {
            switch type {
            case .ballBall(let a,let b): return [a,b]
            case .ballCushion(let ball,_,_),.transition(let ball,_,_),.pocket(let ball,_): return [ball]
            }
        }
        var termination:Termination = .timeLimit
        let firstResolvedEvent=resolvedEvents.count
        var epochs=0
        var phaseClock=MixedLoopPhaseClock()
        defer { phaseClock.flush() }
        recordSnapshot()
        while time<maxTime {
            if rejectsDirectCandidate(cue: rejectCushionBeforeAnyContactFor) {
                termination = .candidateRejected; break
            }
            if let limit=maxResolvedEvents,resolvedEvents.count-firstResolvedEvent>=limit {
                termination = .eventLimit;break
            }
            let tSettle=MixedLoopPhaseClock.now()
            let allLocallySettled = pendingMixedStep == nil && !localOwnership.entries.isEmpty &&
               ballOrder.allSatisfy({ name in
                   guard let ball=balls[name],!ball.isPocketed else { return true }
                   if let owner=localOwnership.entries[name] {
                       // Friction can leave sub-roundoff residuals instead of
                       // exact zero. Compare rim speed in the same units as v.
                       let roundoff=64*Double.ulpOfOne
                       guard length(owner.state.velocity)<=roundoff, length(owner.state.omega)*radius<=roundoff else { return false }
                       if solver.planarSupport(from:owner.state,surfaceY:Double(asset.surfaceY)) != nil { return true }
                       // A pocket lip can support static moment balance without
                       // being a horizontal bed. Require an accepted equilibrium
                       // interval, not merely an instant of zero velocity.
                       guard let span=trajectoryRecorder.localIntervalsByBallName[name]?.last,
                             span.end.time==owner.state.time,span.end.position==owner.state.position,
                             span.duration>0 else { return false }
                       let accelerationRoundoff=roundoff*max(1,Double(TablePhysics.gravity))
                       return length(span.start.velocity)<=roundoff && length(span.start.omega)*radius<=roundoff &&
                           length(span.acceleration)<=accelerationRoundoff &&
                           length(span.angularAcceleration)*radius<=accelerationRoundoff &&
                           length(span.end.position-span.start.position)<=roundoff*max(1,length(span.end.position))
                   }
                   return ball.state == .stationary &&
                       !asset.regionsByPocketID.values.contains(where:{$0.contains(v(ball.position))})
               })
            phaseClock.add(.settleCheck,since:tSettle)
            if allLocallySettled {
                var resting:[String:State]=[:],revisions:[String:UInt64]=[:]
                for (name,owner) in localOwnership.entries {
                    var stopped=owner.state
                    stopped.velocity = .zero;stopped.omega = .zero
                    resting[name]=stopped;revisions[name]=owner.revision
                    mirror(name,stopped);balls[name]!.state = .stationary
                }
                try localOwnership.commit(states:resting,revisions:revisions)
                recordSnapshot()
                termination = .settled;break
            }
            // The planar range proof omits gravitational potential energy.
            // Reuse it only after all active spatial owners have returned.
            if let interest=earlyStopBallNames,pendingMixedStep == nil,localOwnership.entries.isEmpty,
               balls.values.allSatisfy({ball in ball.isPocketed ||
                   (ball.position.y==asset.surfaceY+BallPhysics.radius && ball.velocity.y==0 &&
                    !asset.regionsByPocketID.values.contains(where:{$0.contains(v(ball.position))}))}),
               canEarlyStop(interest:interest) { termination = .interestResolved; break }
            let acceptedEventStart=resolvedEvents.count
            epochs+=1
            guard epochs<=maxEvents else { throw LocalIntegrationFailure.eventBudget }
            if let pending=pendingMixedStep {
                let tCommit=MixedLoopPhaseClock.now()
                phaseClock.tick(.commitEpochs)
                defer { phaseClock.add(.commit,since:tCommit) }
                guard pending.inputRevision==ballInputRevision,pending.maxStep==maxStep,
                      pending.collectsPocketedBalls==collectsPocketedBalls,
                      pending.ballMaterial==ballMaterial,
                      pending.staticMaterial==staticMaterial,
                      pending.restitution==pairRestitution,pending.friction==pairFriction,
                      pending.revisions.allSatisfy({localOwnership.entries[$0.key]?.revision==$0.value}) else {
                    throw LocalPocketOwnership.Failure.staleUpdate
                }
                let stop=min(maxTime,pending.end),complete=stop==pending.end
                var localEnd:[String:State]=[:]
                if complete { localEnd=pending.localEnd }
                else {
                    for (name,result) in pending.predictions {
                        guard let span=result.intervals.first(where:{$0.start.time<=stop && $0.end.time>=stop}),
                              let s=span.sample(at:stop) else { throw LocalIntegrationFailure.invalidInput }
                        localEnd[name]=s
                    }
                }
                var updated=localOwnership
                if complete {
                    for name in ballOrder {
                        if let id=pending.promoted[name],let s=localEnd[name] {
                            try updated.enter(ballName:name,domain:id,state:s)
                        }
                    }
                }
                if !localEnd.isEmpty {
                    let revisions=Dictionary(uniqueKeysWithValues:localEnd.keys.map{($0,updated.entries[$0]!.revision)})
                    try updated.commit(states:localEnd,revisions:revisions)
                }
                localOwnership=updated
                for (name,start) in pending.planarStart {
                    balls[name]=complete ? pending.planarEnd[name]! : evolvePlanarBall(start,dt:Float(stop-pending.start))
                }
                for name in ballOrder {
                    guard let end=localEnd[name] else { continue }
                    if complete,let id=pending.promoted[name] {
                        trajectoryRecorder.recordLocalHandoff(.init(ballName:name,domain:id,kind:.entered,state:end))
                    }
                    if let result=pending.predictions[name] {
                        var accepted:[LocalPocketSimulation.Interval]=[]
                        for span in result.intervals {
                            let begin=max(time,span.start.time),finish=min(stop,span.end.time)
                            guard finish>begin,let a=span.sample(at:begin),let b=span.sample(at:finish) else { continue }
                            accepted.append(.init(start:a,duration:finish-begin,acceleration:span.acceleration,
                                angularAcceleration:span.angularAcceleration,end:finish==stop ? end:b))
                        }
                        trajectoryRecorder.recordLocalIntervals(ballName:name,intervals:accepted)
                    }
                    mirror(name,end)
                }
                var emitted=pending.emittedStaticCounts
                var contacts:[TrajectoryRecorder.LocalStaticContact]=[]
                for name in ballOrder {
                    guard let source=pending.staticContacts[name] else { continue }
                    let begin=emitted[name,default:0]
                    var count=begin
                    for contact in source.dropFirst(begin) {
                        guard contact.time<=stop else { break }
                        contacts.append(.init(ballName:name,geometryID:"table-contact-geometry",contact:contact));count+=1
                    }
                    emitted[name]=count
                }
                for contact in contacts.sorted(by:{$0.contact.time<$1.contact.time}) {
                    trajectoryRecorder.recordLocalStaticContact(contact)
                    guard surfaceRoles[contact.contact.surface] == .cushion else { continue }
                    let t=contact.contact.time,name=contact.ballName,n=contact.contact.normal
                    let horizontal=sqrt(n.x*n.x+n.z*n.z)
                    guard horizontal>0 else { continue }
                    let sample=pending.predictions[name]?.intervals.last(where:{$0.start.time<=t && $0.end.time>=t})?.sample(at:t,beforeEndpoint:true)
                    // Newly promoted neighbours have no earlier local path.
                    let state=sample ?? pending.localEnd[name]
                    guard let state,state.time==t,
                          let cushion=tableGeometry.nearestCushionIndex(to:state.position-n*radius) else {
                        throw LocalIntegrationFailure.invalidInput
                    }
                    if spatialCushionEventKeys.insert(.init(ball:name,time:t,cushion:cushion)).inserted {
                        resolvedEvents.append(.ballCushion(ball:name,cushionIndex:cushion,normal:SCNVector3(Float(n.x/horizontal),0,Float(n.z/horizontal))))
                        resolvedEventTimes.append(Float(t))
                    }
                }
                time=stop;spatialTime=time;currentTime=Float(time);eventCache.clear()
                if complete {
                    pendingMixedStep=nil
                    for event in pending.pairEvents {
                        resolvedEvents.append(event);resolvedEventTimes.append(Float(time))
                        if firstBallBallCollisionTime == nil { firstBallBallCollisionTime=Float(time) }
                    }
                    if let entry=pending.entry {
                        let s=state(balls[entry.name]!,at:time)
                        try localOwnership.enter(ballName:entry.name,pocketID:entry.id,state:s)
                        trajectoryRecorder.recordLocalHandoff(.init(ballName:entry.name,pocketID:entry.id,kind:.entered,state:s))
                    }
                    if let event=pending.event {
                        if case .pocket=event.type { throw LocalIntegrationFailure.uncoveredCapture }
                        resolveEvent(event)
                    }
                    if let capture=pending.capture {
                        guard let owner=localOwnership.entries[capture.name] else { throw LocalIntegrationFailure.invalidInput }
                        let end=try localOwnership.completeCapture(ballName:capture.name,pocketID:capture.id,revision:owner.revision)
                        try trajectoryRecorder.recordConfirmedCapture(.init(ballName:capture.name,pocketID:capture.id,
                            geometryVersion:capture.geometryVersion,state:end))
                        guard let boundary=collection[capture.id] else { throw LocalIntegrationFailure.geometryMismatch }
                        let tail=try PocketCollectionTail(start:end,restingCenterY:boundary.restingCenterY,
                                                          gravity:Double(TablePhysics.gravity))
                        try trajectoryRecorder.recordCollectionTail(ballName:capture.name,tail:tail)
                        balls[capture.name]!.state = .pocketed
                        balls[capture.name]!.velocity=SCNVector3Zero
                        balls[capture.name]!.angularVelocity=SCNVector3Zero
                        resolvedEvents.append(.pocket(ball:capture.name,pocketId:capture.id))
                        resolvedEventTimes.append(Float(time))
                    }
                } else {
                    var remaining=pending
                    remaining.emittedStaticCounts=emitted
                    remaining.revisions=Dictionary(uniqueKeysWithValues:localOwnership.entries.map{($0.key,$0.value.revision)})
                    pendingMixedStep=remaining
                }
                recordSnapshot()
                if resolvedEvents.dropFirst(acceptedEventStart).contains(where:{
                    isContactStopEvent($0,pair:stopAfterContactBetween)
                }) { termination = .contactResolved; break }
                continue
            }
            // A supported ball may return only after leaving its region and
            // separating from the spatial contact group.
            let tReturn=MixedLoopPhaseClock.now()
            for name in ballOrder {
                guard let owner=localOwnership.entries[name] else { continue }
                let touching=localOwnership.entries.contains { other in
                    other.key != name && length(other.value.state.position-owner.state.position)<=2*radius+4*solver.tolerance
                }
                guard !touching else { continue }
                let returned:State?
                switch owner.domain {
                case .airborne:
                    returned=try localOwnership.returnAirborneToPlanar(ballName:name,revision:owner.revision,
                        solver:solver,surfaceY:Double(asset.surfaceY))
                case .pocket(let id):
                    guard let region=asset.regionsByPocketID[id] else { throw LocalIntegrationFailure.geometryMismatch }
                    returned=try localOwnership.returnToPlanar(ballName:name,pocketID:id,
                        revision:owner.revision,solver:solver,region:region,surfaceY:Double(asset.surfaceY))
                }
                if let returned {
                    mirror(name,returned);balls[name]!.state=EngineNumerics.determineMotionState(balls[name]!)
                    trajectoryRecorder.recordLocalHandoff(.init(ballName:name,domain:owner.domain,kind:.returned,state:returned))
                }
            }
            phaseClock.add(.returnCheck,since:tReturn)
            eventCache.clear()
            let owners=Set(localOwnership.entries.keys)
            phaseClock.tick(owners.isEmpty ? .epochsNoLocalOwner : .epochsLocalOwnerActive)
            // Local integration needs small steps only while a local owner is
            // active. Else retain the existing planar motion budget; the exact
            // region crossing below still interrupts before pocket takeover.
            let tPlanar=MixedLoopPhaseClock.now()
            let planarCap=EngineNumerics.adaptiveEvolveCap(balls:getAllBalls(),
                minX:tableBounds.minX,maxX:tableBounds.maxX,
                minZ:tableBounds.minZ,maxZ:tableBounds.maxZ,pockets:tableGeometry.pockets)
            let stepCap=owners.isEmpty ? Double(planarCap) : maxStep
            let event=findNextEvent(maxTimeRemaining:Float(stepCap),excluding:owners)
            phaseClock.add(owners.isEmpty ? .planarEventsIdle : .planarEventsLocalActive,since:tPlanar)
            var horizon=min(stepCap,Double(event?.time ?? .infinity))
            var entry:(name:String,id:String,dt:Double)?
            let tRegion=MixedLoopPhaseClock.now()
            for name in ballOrder where !owners.contains(name) {
                guard let ball=balls[name],!ball.isPocketed else { continue }
                let p=v(ball.position),velocity=v(ball.velocity),a=v(EngineNumerics.acceleration(for:ball))
                for mesh in asset.pockets {
                    let region=asset.regionsByPocketID[mesh.pocketID]!
                    let departure=region.firstCrossing(position:p,velocity:velocity,acceleration:a,horizon:horizon,direction:.leaving)
                    let dt=region.contains(p) && departure != 0 ? 0 : region.firstCrossing(position:p,velocity:velocity,
                        acceleration:a,horizon:horizon,direction:.entering)
                    if let dt,dt<(entry?.dt ?? .infinity) { entry=(name,mesh.pocketID,dt) }
                }
            }
            phaseClock.add(.regionScan,since:tRegion)
            if let entry { horizon=min(horizon,entry.dt) }
            if horizon==0 {
                if let entry,entry.dt==0 {
                    let s=state(balls[entry.name]!,at:time)
                    try localOwnership.enter(ballName:entry.name,pocketID:entry.id,state:s)
                    trajectoryRecorder.recordLocalHandoff(.init(ballName:entry.name,pocketID:entry.id,kind:.entered,state:s))
                }
                if let event,event.time==0,affected(event.type).isDisjoint(with:Set(localOwnership.entries.keys)) {
                    if case .pocket=event.type { throw LocalIntegrationFailure.uncoveredCapture }
                    resolveEvent(event)
                }
                recordSnapshot()
                if resolvedEvents.dropFirst(acceptedEventStart).contains(where:{
                    isContactStopEvent($0,pair:stopAfterContactBetween)
                }) { termination = .contactResolved; break }
                continue
            }
            if owners.isEmpty && entry == nil && balls.values.allSatisfy({$0.isPocketed || $0.state == .stationary}) { termination = .settled; break }
            if !owners.isEmpty { horizon=min(horizon,maxStep) }
            let names=ballOrder.filter{owners.contains($0)}
            var predictions:[String:LocalPocketSimulation.Result]=[:]
            var localEnd:[String:State]=[:]
            var pairEvents:[PhysicsEventType]=[]
            var stop=time+horizon
            let tLocal=MixedLoopPhaseClock.now()
            if !names.isEmpty {
                let start=names.map{localOwnership.entries[$0]!.state}
                let trial=try solver.advanceTogether(from:start,duration:horizon,maxStep:maxStep,
                                                     pairRestitution:pairRestitution,pairFriction:pairFriction)
                stop=trial.time
                if !trial.constraints.isEmpty {
                    let incoming=try names.indices.map { i -> State in
                        if trial.time==start[i].time { return start[i] }
                        guard let span=trial.intervals[i].last(where:{$0.start.time<=trial.time && $0.end.time>=trial.time}),
                              let state=span.sample(at:trial.time,beforeEndpoint:true) else {
                            throw LocalIntegrationFailure.invalidInput
                        }
                        return state
                    }
                    pairEvents=Self.spatialImpactEvents(names:names,incoming:incoming,constraints:trial.constraints)
                }
                for i in names.indices {
                    predictions[names[i]] = .init(states:[start[i],trial.states[i]],contacts:trial.staticContacts[i],maxCorrection:0,
                                                   rejectedSteps:trial.rejectedTrials,intervals:trial.intervals[i])
                    localEnd[names[i]]=trial.states[i]
                }
            }
            phaseClock.add(.localAdvance,since:tLocal)
            var capture:(name:String,id:String,geometryVersion:String,time:Double)?
            let tCapture=MixedLoopPhaseClock.now()
            if collectsPocketedBalls {
                for name in names {
                    guard let owner=localOwnership.entries[name],let prediction=predictions[name] else { continue }
                    let pocketIDs=owner.pocketID.map{[$0]} ?? tableGeometry.pockets.map(\.id)
                    for pocketID in pocketIDs {
                    guard let boundary=collection[pocketID] else { continue }
                    for span in prediction.intervals {
                        guard let candidate=boundary.firstCandidate(in:span),candidate.time<=stop,
                              candidate.time<(capture?.time ?? .infinity) else { continue }
                        var others:[State]=[]
                        for other in ballOrder where other != name && !(balls[other]?.isPocketed ?? true) {
                            if let path=predictions[other] {
                                guard let interval=path.intervals.first(where:{$0.start.time<=candidate.time && $0.end.time>=candidate.time}),
                                      let sampled=interval.sample(at:candidate.time) else { throw LocalIntegrationFailure.invalidInput }
                                others.append(sampled)
                            } else {
                                others.append(state(evolvePlanarBall(balls[other]!,dt:Float(candidate.time-time)),at:candidate.time))
                            }
                        }
                        if boundary.isClearOfActiveBalls(candidate,others:others,positionUncertainty:4*solver.tolerance) {
                            capture=(name,pocketID,boundary.geometryVersion,candidate.time)
                        }
                    }
                    }
                }
                if let capture,capture.time<stop {
                    stop=capture.time;pairEvents=[]
                    for name in names {
                        guard let interval=predictions[name]!.intervals.first(where:{$0.start.time<=stop && $0.end.time>=stop}),
                              let sampled=interval.sample(at:stop) else { throw LocalIntegrationFailure.invalidInput }
                        localEnd[name]=sampled
                    }
                }
            }
            phaseClock.add(.captureScan,since:tCapture)
            let tCross=MixedLoopPhaseClock.now()
            let cross=stop>time && !names.isEmpty ? try firstLocalPlanarContact(local:predictions,until:stop) : nil
            phaseClock.add(.crossDetect,since:tCross)
            if let cross { stop=cross.time;capture=nil }
            let startTime=time
            let dt=stop-time
            let tBook=MixedLoopPhaseClock.now()
            var evolved:[String:BallState]=[:]
            for name in ballOrder where !owners.contains(name) {
                evolved[name]=evolvePlanarBall(balls[name]!,dt:Float(dt))
            }
            phaseClock.add(.bookkeeping,since:tBook)
            var promoted:[String:LocalPocketOwnership.Domain]=[:]
            var promotedContacts:[String:[LocalPocketSimulation.Contact]]=[:]
            let tGroup=MixedLoopPhaseClock.now()
            if let cross {
                var group=names,states:[State]=[],accelerations:[V]=[]
                for name in names {
                    guard let span=predictions[name]!.intervals.first(where:{$0.start.time<=stop && $0.end.time>=stop}),
                          let s=span.sample(at:stop,beforeEndpoint:true) else { throw LocalIntegrationFailure.invalidInput }
                    states.append(s);accelerations.append(span.acceleration)
                }
                // Transitive touching neighbours join the same impulse solve.
                // Full-table geometry supplies their support outside the pocket.
                var i=0
                while i<group.count {
                    for name in ballOrder where !group.contains(name) && !(evolved[name]?.isPocketed ?? true) {
                        var s=state(evolved[name]!,at:stop)
                        if name==cross.planarBall { s=cross.planarState }
                        let rounding=64*Double.ulpOfOne*max(1,length(s.position),length(states[i].position))
                        if name==cross.planarBall || length(s.position-states[i].position)<=2*radius+rounding {
                            let id=name==cross.planarBall ? localOwnership.entries[cross.localBall]!.domain :
                                (localOwnership.entries[group[i]]?.domain ?? promoted[group[i]]!)
                            promoted[name]=id;group.append(name);states.append(s)
                            accelerations.append(v(EngineNumerics.acceleration(for:balls[name]!)))
                        }
                    }
                    i+=1
                }
                let response=try solver.resolveContactGroup(states,accelerations:accelerations,
                    pairRestitution:pairRestitution,pairFriction:pairFriction)
                pairEvents=Self.spatialImpactEvents(names:group,incoming:states,constraints:response.constraints)
                for i in group.indices {
                    let name=group[i]
                    localEnd[name]=response.states[i]
                    if let prediction=predictions[name] {
                        predictions[name] = .init(states:prediction.states,
                            contacts:prediction.contacts.filter{$0.time<stop}+response.staticContacts[i],
                            maxCorrection:prediction.maxCorrection,rejectedSteps:prediction.rejectedSteps,intervals:prediction.intervals)
                    } else { promotedContacts[name]=response.staticContacts[i] }
                }
            }
            phaseClock.add(.contactGroup,since:tGroup)
            let tPending=MixedLoopPhaseClock.now()
            defer { phaseClock.add(.bookkeeping,since:tPending) }
            let dueEntry:(name:String,id:String)? = cross == nil && entry.map({stop==startTime+$0.dt}) == true
                ? (entry!.name,entry!.id) : nil
            var finalOwners=owners.union(promoted.keys)
            if let dueEntry { finalOwners.insert(dueEntry.name) }
            // Independent events remain due even when a different ball enters
            // local ownership or collides at this same absolute instant.
            let dueEvent:PhysicsEvent? = event.flatMap { candidate in
                stop==startTime+Double(candidate.time) && affected(candidate.type).isDisjoint(with:finalOwners) ? candidate:nil
            }
            pendingMixedStep=PendingMixedStep(start:startTime,end:stop,predictions:predictions,
                staticContacts:predictions.mapValues(\.contacts).merging(promotedContacts,uniquingKeysWith:{$1}),localEnd:localEnd,
                planarStart:Dictionary(uniqueKeysWithValues:ballOrder.filter{!owners.contains($0)}.map{($0,balls[$0]!)}),
                planarEnd:evolved,promoted:promoted,pairEvents:pairEvents,entry:dueEntry,event:dueEvent,
                capture:capture.map{($0.name,$0.id,$0.geometryVersion)},collectsPocketedBalls:collectsPocketedBalls,
                ballMaterial:ballMaterial,
                staticMaterial:staticMaterial,
                maxStep:maxStep,restitution:pairRestitution,friction:pairFriction,inputRevision:ballInputRevision,
                revisions:Dictionary(uniqueKeysWithValues:localOwnership.entries.map{($0.key,$0.value.revision)}))

        }
        spatialTime=time;currentTime=Float(time)
        return termination
    }

    // Table geometry bounds
    private let tableBounds: (minX: Float, maxX: Float, minZ: Float, maxZ: Float)
    
    // Event cache
    private let eventCache = EventCache()
    
    // Trajectory recorder
    private let trajectoryRecorder = TrajectoryRecorder()
    
    // Table geometry for collision detection
    private let tableGeometry: TableGeometry
    
    // Resolved events history (for game rules and audio)
    private(set) var resolvedEvents: [PhysicsEventType] = []

    /// 每个 resolvedEvent 对应的绝对模拟时间（与 resolvedEvents 等长，下标一一对应）
    private(set) var resolvedEventTimes: [Float] = []

    /// 首次球-球碰撞的模拟时间（用于相机延迟切换观察视角）
    private(set) var firstBallBallCollisionTime: Float?

    /// Initialize engine with table geometry
    init(tableGeometry: TableGeometry) {
        self.tableGeometry = tableGeometry
        
        // Calculate table bounds from inner dimensions
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        
        tableBounds = (
            minX: -halfLength,
            maxX: halfLength,
            minZ: -halfWidth,
            maxZ: halfWidth
        )
    }
    
    /// Begin a fresh simulation at an existing shot's absolute clock.
    /// This restores time only; callers must supply validated supported ball
    /// states and retain the preceding spatial records separately.
    convenience init(tableGeometry: TableGeometry, startingAt time: Double) throws {
        guard time.isFinite, time >= 0, Float(time).isFinite else {
            throw LocalIntegrationFailure.invalidInput
        }
        self.init(tableGeometry: tableGeometry)
        currentTime = Float(time)
        spatialTime = time
    }

    /// Add or update a ball state
    func setBall(_ ball: BallState) {
        ballInputRevision+=1
        if balls[ball.name] == nil { ballOrder.append(ball.name) }
        balls[ball.name] = ball
    }
    
    /// Get ball state by name
    func getBall(_ name: String) -> BallState? {
        return balls[name]
    }
    
    /// Get all ball states（按插入有序返回，确定性）
    func getAllBalls() -> [BallState] {
        return ballOrder.compactMap { balls[$0] }
    }
    
    /// Run simulation until maxEvents or maxTime is reached.
    /// - Parameter highFidelityBounds: 仅**展示用最终模拟**置 true → 启用近库自适应子步（ADR-P10-07），
    ///   让贴墙帧足够密、回放轨迹不外推穿墙。求解器的数十次短模拟保持 false（用固定 `maxEvolveStep`
    ///   粗步，避免把每杆求解拖慢一个数量级）——其只需结果（进/吃库/方向），且引擎级方向兜底/settle
    ///   收袋（见 `enforceTableBounds`，**始终生效**）已保证结果正确性（球不会停在台外）。
    /// - Parameter earlyStopBallNames: 反解搜索早停（B1，性能优化方案）：非 nil 时，当这些「兴趣球」
    ///   全部落袋/停稳，且其余仍在运动的球按**能量上界行程**（含碰撞链式接力）不可能再触及任何兴趣球
    ///   时提前结束模拟。保守判据 ⇒ **兴趣球的终态与不早停逐位一致**；代价是其余球的末位可能停在
    ///   「仍在滚动」的中间帧（走位反解不消费它们）。展示用最终模拟必须保持 nil。
    /// - Parameter stopAfterContactBetween: 瞄准评分专用早停（B1）：非 nil 时，两球间**首次碰撞**
    ///   解算并记帧后立即结束。瞄准评分只消费「碰前事件 + 碰后第一帧方向」——碰撞发生 ⇒ 之后的
    ///   演进对评分零贡献，直接截断；碰撞不发生 ⇒ 永不触发，回退整程模拟。评分值与整程逐位一致。
    @discardableResult
    func simulate(maxEvents: Int = 1000, maxTime: Float = 10.0, highFidelityBounds: Bool = false,
                  earlyStopBallNames: Set<String>? = nil,
                  stopAfterContactBetween: (String, String)? = nil,
                  rejectCushionBeforeAnyContactFor: String? = nil) -> Termination {
        PerformanceProfiler.begin(ProfilerLabel.simulate)
        defer { PerformanceProfiler.end(ProfilerLabel.simulate) }

        // Run a more thorough initial separation before the first event search.
        // A single pass of 6 iterations is not enough for a densely packed rack where
        // ball positions may carry up to ~16 mm of initial overlap. 50 iterations with
        // a convergence check handles even the worst-case rack layouts.
        separateOverlappingBalls(maxIterations: 50)
        recordSnapshot()
        var eventCount = 0
        var zeroTimeEventStreak = 0
        
        while eventCount < maxEvents && currentTime < maxTime {
            if rejectsDirectCandidate(cue: rejectCushionBeforeAnyContactFor) { return .candidateRejected }
            // Zero-duration transitions can finish a ball at this same instant.
            // Once every ball is at rest, do not append an artificial maxTime tail.
            if balls.values.allSatisfy({ $0.isPocketed || $0.state == .stationary }) { return .settled }
            // Find next event
            PerformanceProfiler.begin(ProfilerLabel.findNextEvent)
            let nextEvent = findNextEvent(maxTimeRemaining: maxTime - currentTime)
            PerformanceProfiler.end(ProfilerLabel.findNextEvent)

            guard let nextEvent else {
                // No more events, advance to maxTime
                let dt = maxTime - currentTime
                evolveAllBalls(dt: dt)
                currentTime = maxTime
                recordSnapshot()
                break
            }
            
            // Advance all balls to event time (relative time)
            let dt = nextEvent.time
            guard dt > 0 else {
                // Event at current time or in past, resolve immediately
                zeroTimeEventStreak += 1
                resolveEvent(nextEvent)
                invalidateCache(for: nextEvent)
                recordSnapshot()
                eventCount += 1
                if isContactStopEvent(nextEvent, pair: stopAfterContactBetween) { return .contactResolved }
                
                // 保护：避免连续零时刻事件导致主线程长时间卡死
                if zeroTimeEventStreak > 80 {
                    let nudge = min(0.0005, maxTime - currentTime)
                    if nudge > 0 {
                        evolveAllBalls(dt: nudge)
                        separateOverlappingBalls()
                        currentTime += nudge
                        recordSnapshot()
                    }
                    zeroTimeEventStreak = 0
                }
                continue
            }
            zeroTimeEventStreak = 0

            // 演进步长上限（ADR-P10-06 + P10-07 近库自适应子步）：若到下一事件的 dt 超过安全步长，
            // 先只推进一个安全步、记一帧、作废事件缓存后重新检测，不直接跨大步推进到事件。
            // 安全步长 = `adaptiveEvolveCap`：默认 maxEvolveStep；但若有球正朝某边界逼近（整步内会触墙），
            // 收紧到位移级（nearWallSafeStep/速度）。三重收益：
            //   (a) 漏检的袋口/jaw/喉腔角缝碰撞会在球贴墙时被重新检出（解析线交点落到有限段外的接缝漏检）；
            //   (b) recorder 帧足够密 → 回放 `TrajectoryPlayback.stateAt` 不会在空档里沿旧速度外推穿墙；
            //   (c) `enforceTableBounds` 每子步兜底，把残留越界球在 < nearWallSafeStep 内拉回并记真实帧。
            // 高保真（展示用最终模拟）：近库自适应子步 → 贴墙帧密、回放不外推穿墙。
            // 非高保真（求解器短模拟）：**不切步**（stepCap = +∞）→ 恢复 ADR-P10-06 前速度。
            //   切步本为「显示密帧 + 漏检兜底」而加；求解器只取结果量（进/方向/吃库），且 cueGhostMinDist
            //   已做段内线段-点采样、enforceTableBounds 每步兜底，无需密帧即可正确判结果。
            let stepCap = highFidelityBounds
                ? EngineNumerics.adaptiveEvolveCap(
                    balls: getAllBalls(),
                    minX: tableBounds.minX, maxX: tableBounds.maxX,
                    minZ: tableBounds.minZ, maxZ: tableBounds.maxZ,
                    pockets: tableGeometry.pockets)
                : Float.greatestFiniteMagnitude
            if dt > stepCap {
                evolveAllBalls(dt: stepCap)
                separateOverlappingBalls()
                currentTime += stepCap
                eventCache.clear()   // 从新位置重新检测：捕回从远处漏检/被 no-collision 缓存跳过的碰撞
                recordSnapshot()
                continue
            }

            PerformanceProfiler.begin(ProfilerLabel.evolveAllBalls)
            evolveAllBalls(dt: dt)
            PerformanceProfiler.end(ProfilerLabel.evolveAllBalls)

            separateOverlappingBalls()
            currentTime += dt
            
            // Resolve event
            PerformanceProfiler.begin(ProfilerLabel.resolveEvent)
            resolveEvent(nextEvent)
            PerformanceProfiler.end(ProfilerLabel.resolveEvent)
            
            // Invalidate cache for affected balls
            invalidateCache(for: nextEvent)
            
            // Record snapshot
            recordSnapshot()
            
            eventCount += 1
            
            // 瞄准评分早停（B1）：两具名球首次碰撞已解算并记帧 ⇒ 评分消费量齐备，截断尾部演进。
            if isContactStopEvent(nextEvent, pair: stopAfterContactBetween) { return .contactResolved }
            
            // 提前终止检查（Ref: pooltool event.time == np.inf → done）：
            // 每 8 步检查一次是否所有活动球已 stationary，以避免不必要的碰撞扫描。
            // 这是最主要的加速手段：开球后若球已全部静止，无需继续跑满 15s。
            if eventCount % 8 == 0 {
                let allAtRest = balls.values.allSatisfy { b in
                    b.isPocketed || b.state == .stationary
                }
                if allAtRest {
                    return .settled
                }
                if let interest = earlyStopBallNames, canEarlyStop(interest: interest) {
                    return .interestResolved
                }
            }
        }
        if balls.values.allSatisfy({$0.isPocketed || $0.state == .stationary}) { return .settled }
        // The early-stop criterion is a state predicate, not an event: a spin-only tail
        // (planar `.spinning`) can outlast `maxTime` with no further events, so the
        // periodic in-loop check never fires. Evaluate it once more before reporting
        // a horizon cutoff (W17-A: planar default made this reachable in search runs).
        if let interest = earlyStopBallNames, canEarlyStop(interest: interest) { return .interestResolved }
        return currentTime>=maxTime ? .timeLimit : .eventLimit
    }

    /// A lower-bound rejection used only once the caller already has a valid
    /// direct candidate. Match runShot's "before any ball-ball event" contract.
    private func rejectsDirectCandidate(cue: String?) -> Bool {
        guard let cue else { return false }
        for event in resolvedEvents {
            switch event {
            case .ballBall: return false
            case .ballCushion(let name, _, _) where name == cue: return true
            default: continue
            }
        }
        return false
    }

    /// 瞄准评分早停判定：本事件是否为 `pair` 两球间的球-球碰撞（无序匹配）。
    private func isContactStopEvent(_ event: PhysicsEvent, pair: (String, String)?) -> Bool {
        isContactStopEvent(event.type,pair:pair)
    }

    private func isContactStopEvent(_ event: PhysicsEventType, pair: (String, String)?) -> Bool {
        guard let (x, y) = pair else { return false }
        if case let .ballBall(a, b) = event {
            return (a == x && b == y) || (a == y && b == x)
        }
        return false
    }

    /// 早停保守判据（B1）：兴趣球全部「落袋或线速度归零（stationary/spinning 原地自转）」，
    /// 且其余运动球的**总行程预算**无法触及任何兴趣球。
    ///
    /// 行程预算 = Σ 每球动能上界行程：E/m = v²/2 + (I/m)·ω²/2 = v²/2 + R²ω²/5，全部转成线动能
    /// 后按**最宽松的滚动摩擦**减速可走 E/(μ_roll·g) 米。等质量碰撞 Σv² 不增（e≤1）、吃库只衰减
    /// ⇒ 链式接力的总路径 ≤ 该预算；接力换球每跳最多把「扰动前沿」额外推进 2R ⇒ 松弛量 = 球数·2R。
    /// 判据不满足则继续模拟——绝不改变兴趣球结果，只放弃可证明无关的尾部滚动。
    private func canEarlyStop(interest: Set<String>) -> Bool {
        let r = BallPhysics.radius
        var interestPositions: [SCNVector3] = []
        for name in interest {
            guard let b = balls[name] else { continue }   // 兴趣球不在场（如无该球）不阻塞
            if b.isPocketed { continue }
            guard b.state == .stationary || b.state == .spinning else { return false }
            interestPositions.append(b.position)
        }
        if interestPositions.isEmpty { return true }   // 兴趣球全落袋 ⇒ 命运已定

        var totalBudget: Float = 0
        var minDist = Float.greatestFiniteMagnitude
        var others = 0
        for name in ballOrder {
            guard let b = balls[name], !b.isPocketed, !interest.contains(name) else { continue }
            others += 1
            guard b.state == .sliding || b.state == .rolling else { continue }   // 原地自转不产生位移
            let v2 = b.velocity.x * b.velocity.x + b.velocity.z * b.velocity.z
            let w = b.angularVelocity
            let w2 = w.x * w.x + w.y * w.y + w.z * w.z
            let energyPerMass = v2 / 2 + r * r * w2 / 5
            totalBudget += energyPerMass / (SpinPhysics.rollingFriction * TablePhysics.gravity)
            for p in interestPositions {
                let dx = b.position.x - p.x, dz = b.position.z - p.z
                minDist = min(minDist, sqrtf(dx * dx + dz * dz))
            }
        }
        if totalBudget <= 0 { return true }   // 无运动球（仅原地自转）⇒ 兴趣球安全
        let slack = Float(others) * 2 * r + 0.05
        return totalBudget + slack < minDist - 2 * r
    }
    
    /// Get trajectory recorder
    func getTrajectoryRecorder() -> TrajectoryRecorder {
        return trajectoryRecorder
    }
    
    // MARK: - Private Methods
    
    /// Find the next event to occur
    func findNextEvent(maxTimeRemaining: Float, excluding:Set<String>=[]) -> PhysicsEvent? {
        var candidates: [PhysicsEvent] = []
        let names=ballOrder.filter { !excluding.contains($0) }
        
        // Align with pooltool: event detection always uses the remaining simulation horizon.
        // Do not shrink the search window heuristically; aggressive truncation can miss valid
        // later collisions and lead to overlap/penetration artifacts.
        let detectionMaxTime = maxTimeRemaining
        
        // Find next transition events. Zero is a valid analytical duration:
        // e.g. a rolling ball with no residual spin must become stationary
        // through spinning at this same instant, rather than remain stuck.
        for name in names {
            guard let ball = balls[name] else { continue }
            guard !ball.isPocketed else { continue }
            
            // Check slide-to-roll transition
            if ball.state == .sliding {
                let transitionType = "slideToRoll"
                if let cached = eventCache.getTransition(ball: name, transitionType: transitionType, currentTime: currentTime) {
                    if cached.time >= 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                } else {
                    let transitionTime = AnalyticalMotion.slideToRollTime(
                        velocity: ball.velocity,
                        angularVelocity: ball.angularVelocity
                    )
                    if transitionTime >= 0 && transitionTime <= detectionMaxTime {
                        let event = PhysicsEvent(
                            type: .transition(ball: name, fromState: .sliding, toState: .rolling),
                            time: transitionTime,
                            priority: 2
                        )
                        eventCache.setTransition(ball: name, transitionType: transitionType, event: event, currentTime: currentTime)
                        candidates.append(event)
                    }
                }
            }
            
            // Check roll-to-spin transition
            if ball.state == .rolling {
                let transitionType = "rollToSpin"
                if let cached = eventCache.getTransition(ball: name, transitionType: transitionType, currentTime: currentTime) {
                    if cached.time >= 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                } else {
                    let transitionTime = AnalyticalMotion.rollToSpinTime(velocity: ball.velocity)
                    if transitionTime >= 0 && transitionTime <= detectionMaxTime {
                        let event = PhysicsEvent(
                            type: .transition(ball: name, fromState: .rolling, toState: .spinning),
                            time: transitionTime,
                            priority: 2
                        )
                        eventCache.setTransition(ball: name, transitionType: transitionType, event: event, currentTime: currentTime)
                        candidates.append(event)
                    }
                }
            }
            
            // Check spin-to-stationary transition
            if ball.state == .spinning {
                let transitionType = "spinToStationary"
                if let cached = eventCache.getTransition(ball: name, transitionType: transitionType, currentTime: currentTime) {
                    if cached.time >= 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                } else {
                    let transitionTime = AnalyticalMotion.spinToStationaryTime(angularVelocity: ball.angularVelocity)
                    if transitionTime >= 0 && transitionTime <= detectionMaxTime {
                        let event = PhysicsEvent(
                            type: .transition(ball: name, fromState: .spinning, toState: .stationary),
                            time: transitionTime,
                            priority: 2
                        )
                        eventCache.setTransition(ball: name, transitionType: transitionType, event: event, currentTime: currentTime)
                        candidates.append(event)
                    }
                }
            }
        }
        
        // Find ball-ball collisions
#if DEBUG
        // Each engine owns its timing start; shared labels race in parallel searches.
        let ballDetectionStart = CACurrentMediaTime()
#endif
        let ballNames = names
        for i in 0..<ballNames.count {
            for j in (i+1)..<ballNames.count {
                let nameA = ballNames[i]
                let nameB = ballNames[j]
                
                guard let ballA = balls[nameA], let ballB = balls[nameB] else { continue }
                guard !ballA.isPocketed && !ballB.isPocketed else { continue }
                
                // 已接触/重叠时立即触发一次碰撞，避免“穿透后只带走一点”
                if EngineNumerics.isBallPairOverlappingOrTouching(ballA, ballB) {
                    let immediate = PhysicsEvent(
                        type: .ballBall(ballA: nameA, ballB: nameB),
                        time: 0,
                        priority: -1
                    )
                    candidates.append(immediate)
                    continue
                }
                
                // 运动学剪裁（Ref: pooltool solve.py skip_ball_ball_collision）：
                // 两球均不平动（stationary/spinning）时不产生碰撞，与 pooltool nontranslating 判断一致。
                // 注意：此处不做空间距离裁剪和方向裁剪——这类裁剪曾导致合法碰撞漏检，
                // 改由四次方程求解器（maxTime 截断）处理无效球对，保证正确性。
                let aIsNontranslating = ballA.state == .stationary || ballA.state == .spinning
                let bIsNontranslating = ballB.state == .stationary || ballB.state == .spinning
                if aIsNontranslating && bIsNontranslating {
                    continue
                }

                // Negative cache check（Ref: pooltool cache[pair] = np.inf）：
                // 已确认此球对在当前运动状态下不会碰撞，直接跳过
                if eventCache.isBallBallNoCollision(ballA: nameA, ballB: nameB,
                                                    stateA: ballA.state, stateB: ballB.state,
                                                    currentTime: currentTime) {
                    continue
                }
                
                // Check cache first
                if let cached = eventCache.getBallBall(ballA: nameA, ballB: nameB, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                    continue
                }
                
                // Compute acceleration for each ball based on state
                let aA = EngineNumerics.acceleration(for: ballA)
                let aB = EngineNumerics.acceleration(for: ballB)
                
                // Find collision time
                if let collisionTime = CollisionDetector.ballBallCollisionTime(
                    p1: ballA.position,
                    p2: ballB.position,
                    v1: ballA.velocity,
                    v2: ballB.velocity,
                    a1: aA,
                    a2: aB,
                    R: Double(BallPhysics.radius),
                    maxTime: Double(detectionMaxTime)
                ) {
                    let event = PhysicsEvent(
                        type: .ballBall(ballA: nameA, ballB: nameB),
                        time: collisionTime,
                        priority: 3
                    )
                    eventCache.setBallBall(ballA: nameA, ballB: nameB, event: event, currentTime: currentTime)
                    candidates.append(event)
                } else if EngineNumerics.shouldRunFallbackBallBallCheck(
                    ballA: ballA,
                    ballB: ballB,
                    aA: aA,
                    aB: aB,
                    maxTime: detectionMaxTime
                ), let fallbackTime = EngineNumerics.fallbackBallBallCollisionTime(
                    ballA: ballA,
                    ballB: ballB,
                    aA: aA,
                    aB: aB,
                    maxTime: detectionMaxTime
                ) {
                    // Quartic missed but discrete fallback found collision.
                    let dist = (ballB.position - ballA.position).length()
                    let event = PhysicsEvent(
                        type: .ballBall(ballA: nameA, ballB: nameB),
                        time: fallbackTime,
                        priority: 3
                    )
                    eventCache.setBallBall(ballA: nameA, ballB: nameB, event: event, currentTime: currentTime)
                    candidates.append(event)
                } else {
                    // 四次方程和 fallback 均未找到碰撞 → 写入 negative cache（Ref: pooltool np.inf 标记）
                    // 下次同一球对直接跳过，无需重新计算（仅对静止/自旋球对有效，见 isBallBallNoCollision）
                    eventCache.setBallBallNoCollision(ballA: nameA, ballB: nameB,
                                                     stateA: ballA.state, stateB: ballB.state,
                                                     currentTime: currentTime)
                }
            }
        }
#if DEBUG
        PerformanceProfiler.recordSample(ProfilerLabel.ballBallDetect,
            ms: (CACurrentMediaTime() - ballDetectionStart) * 1000)
#endif
        
        // Find ball-cushion collisions
#if DEBUG
        // Each engine owns its timing start; shared labels race in parallel searches.
        let cushionDetectionStart = CACurrentMediaTime()
#endif
        for name in names {
            guard let ball = balls[name] else { continue }
            guard !ball.isPocketed else { continue }
            
            let a = EngineNumerics.acceleration(for: ball)
            // A constant center cannot newly reach a fixed boundary. Ball-ball
            // events remain active and a subsequent impact re-evaluates this ball.
            guard ball.velocity.x != 0 || ball.velocity.y != 0 || ball.velocity.z != 0 ||
                  a.x != 0 || a.y != 0 || a.z != 0 else { continue }

            
            // Check linear cushions
            for (index, cushion) in tableGeometry.linearCushions.enumerated() {
                // Negative cache check：已知此球-直线库组合不会碰撞，直接跳过
                // Check cache first
                if let cached = eventCache.getBallCushion(ball: name, cushionIndex: index, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                    continue
                }
                
                // Compute line offset (distance from origin along normal)
                let lineOffset = Double(cushion.normal.dot(cushion.start))
                
                if let collisionTime = CollisionDetector.ballLinearCushionTime(
                    p: ball.position,
                    v: ball.velocity,
                    a: a,
                    lineNormal: cushion.normal,
                    lineOffset: lineOffset,
                    R: Double(BallPhysics.radius),
                    maxTime: Double(detectionMaxTime)
                ) {
                    // Convert infinite-line hit into finite-segment hit.
                    let collisionPos = ball.position
                        + ball.velocity * collisionTime
                        + a * (0.5 * collisionTime * collisionTime)
                    
                    if EngineNumerics.isWithinLinearCushionSegment(point: collisionPos, segment: cushion) {
                        let event = PhysicsEvent(
                            type: .ballCushion(ball: name, cushionIndex: index, normal: cushion.normal),
                            time: collisionTime,
                            priority: 3
                        )
                        eventCache.setBallCushion(ball: name, cushionIndex: index, event: event, currentTime: currentTime)
                        candidates.append(event)
                    }
                }
            }
        }
        
        // Find ball-circular-cushion collisions (pocket jaw arcs)
        let linearCount = tableGeometry.linearCushions.count
        for name in names {
            guard let ball = balls[name] else { continue }
            guard !ball.isPocketed else { continue }
            
            let a = EngineNumerics.acceleration(for: ball)
            // A constant center cannot newly reach a fixed boundary. Ball-ball
            // events remain active and a subsequent impact re-evaluates this ball.
            guard ball.velocity.x != 0 || ball.velocity.y != 0 || ball.velocity.z != 0 ||
                  a.x != 0 || a.y != 0 || a.z != 0 else { continue }

            
            for (arcIdx, arc) in tableGeometry.circularCushions.enumerated() {
                let cushionIndex = linearCount + arcIdx
                
                if let cached = eventCache.getBallCushion(ball: name, cushionIndex: cushionIndex, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                    continue
                }
                
                if let collisionTime = CollisionDetector.ballCircularCushionTime(
                    p: ball.position,
                    v: ball.velocity,
                    a: a,
                    arc: arc,
                    R: BallPhysics.radius,
                    maxTime: Double(detectionMaxTime),
                    pockets: tableGeometry.pockets
                ) {
                    let t = collisionTime
                    let posAtT = ball.position + ball.velocity * t + a * (0.5 * t * t)
                    let normal = arc.normal(at: posAtT)
                    
                    let event = PhysicsEvent(
                        type: .ballCushion(ball: name, cushionIndex: cushionIndex, normal: normal),
                        time: collisionTime,
                        priority: 3
                    )
                    eventCache.setBallCushion(ball: name, cushionIndex: cushionIndex, event: event, currentTime: currentTime)
                    candidates.append(event)
                }
            }
        }
        
        // Find ball-pocket events (CCD quartic solve, XZ-plane only)
        // 注意：必须使用 XZ 2D 分量，不含 Y（球心 Y 恒高于台面，3D 距离永远够不到孔圈半径）。
        // 判据（ADR-P10-09）：球心水平投影抵达孔圈（dist = pocket.radius，即真实落袋孔半径）
        // ⇒ 台面失去支撑 ⇒ 落袋。无速度/方向特判——能否抵达孔圈完全由 jaw/圆角/喉壁物理决定。
        for name in names {
            guard let ball = balls[name] else { continue }
            guard !ball.isPocketed else { continue }
            
            let a = EngineNumerics.acceleration(for: ball)
            // A constant center cannot newly reach a fixed boundary. Ball-ball
            // events remain active and a subsequent impact re-evaluates this ball.
            guard ball.velocity.x != 0 || ball.velocity.y != 0 || ball.velocity.z != 0 ||
                  a.x != 0 || a.y != 0 || a.z != 0 else { continue }

            
            // Check each pocket
            for pocket in tableGeometry.pockets {
                let r = pocket.radius

                // XZ-only: 袋口检测在水平面进行，忽略 Y 轴高度差
                let dpX = ball.position.x - pocket.center.x
                let dpZ = ball.position.z - pocket.center.z
                let dvX = ball.velocity.x
                let dvZ = ball.velocity.z
                let daX = a.x
                let daZ = a.z

                let halfDaX = daX * 0.5
                let halfDaZ = daZ * 0.5

                let halfDaDotHalfDa = Double(halfDaX * halfDaX + halfDaZ * halfDaZ)
                let dvDotHalfDa    = Double(dvX * halfDaX + dvZ * halfDaZ)
                let dvDotDv        = Double(dvX * dvX + dvZ * dvZ)
                let dpDotHalfDa    = Double(dpX * halfDaX + dpZ * halfDaZ)
                let dpDotDv        = Double(dpX * dvX + dpZ * dvZ)
                let dpDotDp        = Double(dpX * dpX + dpZ * dpZ)

                let a4 = halfDaDotHalfDa
                let a3 = 2.0 * dvDotHalfDa
                let a2 = dvDotDv + 2.0 * dpDotHalfDa
                let a1 = 2.0 * dpDotDv
                let a0 = dpDotDp - Double(r * r)

                let roots = QuarticSolver.solveQuartic(a: a4, b: a3, c: a2, d: a1, e: a0)
                if let time = EngineNumerics.smallestPositiveRoot(roots, maxTime: detectionMaxTime) {
                    candidates.append(PhysicsEvent(
                        type: .pocket(ball: name, pocketId: pocket.id),
                        time: time,
                        priority: 2
                    ))
                }
            }
        }
#if DEBUG
        PerformanceProfiler.recordSample(ProfilerLabel.cushionDetect,
            ms: (CACurrentMediaTime() - cushionDetectionStart) * 1000)
#endif
        
        // Return earliest event
        return candidates.min()
    }
    
    /// Shared planar equations without bounds/capture side effects. The hybrid
    /// scheduler stops at ownership entry before calling any legacy capture.
    private func evolvePlanarBall(_ ball:BallState,dt:Float)->BallState {
        let evolved:(position:SCNVector3,velocity:SCNVector3,angularVelocity:SCNVector3)
        switch ball.state {
        case .sliding:
            evolved=AnalyticalMotion.evolveSliding(position:ball.position,velocity:ball.velocity,angularVelocity:ball.angularVelocity,dt:dt)
        case .rolling:
            evolved=AnalyticalMotion.evolveRolling(position:ball.position,velocity:ball.velocity,angularVelocity:ball.angularVelocity,dt:dt)
        case .spinning:
            let value=AnalyticalMotion.evolveSpinning(position:ball.position,angularVelocity:ball.angularVelocity,dt:dt)
            evolved=(value.position,ball.velocity,value.angularVelocity)
        case .stationary,.pocketed:return ball
        }
        return BallState(position:evolved.position,velocity:evolved.velocity,angularVelocity:evolved.angularVelocity,state:ball.state,name:ball.name)
    }

    /// Evolve all balls forward by dt
    private func evolveAllBalls(dt: Float) {
        for name in ballOrder {
            guard let ball = balls[name] else { continue }
            guard !ball.isPocketed else { continue }
            
            guard ball.state != .stationary else { continue }
            var nextState=evolvePlanarBall(ball,dt:dt)

            enforceTableBounds(for: &nextState, stateTime: currentTime + dt)
            balls[name] = nextState
        }
    }

    /// 修正重叠球，减少"穿插后无碰撞"的数值死区
    private func separateOverlappingBalls(maxIterations: Int = 6) {
        let names = ballOrder
        guard names.count >= 2 else { return }
        let twoR = 2 * BallPhysics.radius
        // Trigger only when balls genuinely penetrate (d < 2R).
        // Use (2R)² as the detection threshold to avoid treating make_kiss clearance as overlap.
        let triggerDistSq = twoR * twoR
        // Push to 2R + spacer so after separation d > 2R, preventing Float32 boundary oscillation
        // where d² = (2R)² - epsilon triggers another iteration.
        let spacer: Float = 3e-5   // 0.03 mm clearance beyond 2R
        let targetDist = twoR + spacer

        for _ in 0..<maxIterations {
            var adjusted = false
            
            for i in 0..<(names.count - 1) {
                for j in (i + 1)..<names.count {
                    let aName = names[i]
                    let bName = names[j]
                    guard var a = balls[aName], var b = balls[bName] else { continue }
                    if a.isPocketed || b.isPocketed { continue }
                    
                    let delta = b.position - a.position
                    let d2 = delta.x * delta.x + delta.z * delta.z
                    // Only act on genuine penetration (d < 2R), not on spacer clearance.
                    if d2 >= triggerDistSq { continue }
                    
                    let dist = sqrtf(max(d2, 1e-12))
                    let nx: Float
                    let nz: Float
                    if dist < 1e-6 {
                        nx = 1
                        nz = 0
                    } else {
                        nx = delta.x / dist
                        nz = delta.z / dist
                    }
                    // Compute push needed to reach targetDist (2R + spacer).
                    let push = (targetDist - max(dist, 1e-6)) * 0.5

                    let move = SCNVector3(nx * push, 0, nz * push)
                    
                    a.position = a.position - move
                    b.position = b.position + move
                    // Do NOT call enforceTableBounds here: it can pull a ball back into
                    // overlap range, causing the loop to never converge.
                    
                    balls[aName] = a
                    balls[bName] = b
                    // Invalidate cache for this pair so the next findNextEvent re-solves
                    // their quartic rather than using a stale no-collision or positive entry.
                    eventCache.invalidateBallPair(ballA: aName, ballB: bName)
                    adjusted = true
                }
            }
            
            if !adjusted { break }
        }
    }

    /// 最终静止摆位重叠清理（#4）：球形生成器把开球结果作为「可编辑摆位」输出前调用，
    /// 消除偶发的「停稳后两球轻微穿插」。纯几何分离——只沿球心连线把穿插球对推到
    /// 2R+spacer，不改速度、不触发落袋、不做边界钳制（避免把球误推进袋或来回震荡）。
    /// 多迭代确保收敛（停稳态位移均为亚毫米，对画面无感）。
    func resolveRestingOverlaps(maxIterations: Int = 16) {
        separateOverlappingBalls(maxIterations: maxIterations)
    }

    /// 兜底边界约束：防止极端数值误差导致球“跑出台外”
    private func enforceTableBounds(for state: inout BallState, stateTime: Float) {
        guard !state.isPocketed else { return }
        
        let safeMinX = tableBounds.minX + BallPhysics.radius
        let safeMaxX = tableBounds.maxX - BallPhysics.radius
        let safeMinZ = tableBounds.minZ + BallPhysics.radius
        let safeMaxZ = tableBounds.maxZ - BallPhysics.radius

        // 触发余量（FL 根因修复·吃库竞态，2026-06-12）：库线吃库时球心接触位置 **恰好等于**
        // safe 边界（contact = 库线 ∓ R），CCD 把球精确演进到接触点时浮点噪声可落在边界外
        // ~1e-6 m。该状态是「正要解析的合法吃库」而非「跑出台外」；零容差硬钳会抢在事件前
        // 把法向速度减半反向，随后 Han 解析器按（已退离的）速度方向翻转接触系、把球再次
        // 反射回库内——形成「以 ~2 折出射角贴库滑出」的非物理轨迹（S4 数值确证：入29° 实测
        // 出射 131°，手动复算应为 27°）。真正的接缝漏出会逐子步继续向外推进（近库子步位移
        // 上限 ~10mm/步），远超此余量，安全网兜底能力不受影响。
        let boundsEpsilon: Float = 5e-4   // 0.5mm ≫ Float32 接触噪声(~1e-6 m)，≪ 漏出位移(mm 级)

        let outX = state.position.x < safeMinX - boundsEpsilon || state.position.x > safeMaxX + boundsEpsilon
        let outZ = state.position.z < safeMinZ - boundsEpsilon || state.position.z > safeMaxZ + boundsEpsilon
        guard outX || outZ else { return }
        
        // 球已越出可玩框、且落在某袋口附近（`pocket.radius + 3R` 内，覆盖袋嘴→袋兜全通道）。
        for pocket in tableGeometry.pockets {
            let dx = state.position.x - pocket.center.x
            let dz = state.position.z - pocket.center.z
            let dist = sqrtf(dx * dx + dz * dz)
            guard dist < pocket.radius + BallPhysics.radius * 3 else { continue }

            // ① 球心已入孔圈（数值漏检兜底，正常路径由 CCD .pocket 事件收袋）→ 落袋。
            if dist <= pocket.radius {
                trajectoryRecorder.recordPocketEntry(ball: state, pocketID: pocket.id, time: stateTime,
                                                     source: .boundsFallback, geometry: tableGeometry)
                state.state = .pocketed
                state.velocity = SCNVector3Zero
                state.angularVelocity = SCNVector3Zero
                // 记一次真实落袋事件，使下游 `pottedSelected`（扫 resolvedEvents 的 .pocket）与画面一致。
                resolvedEvents.append(.pocket(ball: state.name, pocketId: pocket.id))
                resolvedEventTimes.append(stateTime)
                return
            }
            // ② 在袋口通道内（孔圈外）：无论速度/朝向均放行（ADR-P10-09）——
            //    rattle 弹出、慢速滑向孔圈、以及**球心停在孔圈外的合法挂袋**都交给真实几何
            //    （jaw 弧/面 + 喉壁 + 孔圈判据）处理。旧「低速即收袋」特判会把挂袋球吸走，已删除。
            return
        }

        // ④ jaw 弧合法接触带豁免（FL 根因修复，2026-06-12）：
        //    圆弧库（角袋 jaw 弧 / 中袋 fillet）的球心接触圆（r_arc + R）**伸出矩形可玩框**
        //    最多数厘米（越靠袋心越多；如左下角弧在 352° 接触点比 safeMinX 深 ~1.3mm）。
        //    球落在任一弧的角度扇区内、且距弧心 ≤ 接触距 + mouthSlack 时，说明它正与该弧
        //    交互（CCD 已能正确检出并解析），真实边界是弧本身——矩形硬钳在此不适用。
        //    不豁免则硬钳抢在已调度的弧碰撞事件之前触发（法向减半反弹、无事件、不作废缓存），
        //    产生「贴库平行滑出 + 末端小钩」的幽灵反弹。
        //    mouthSlack 覆盖逼近条带：略大于近库子步位移上限 nearWallSafeStep（~10mm）。
        //    径向速度门控（防研磨）：只豁免**径向显著运动**（正撞向弧面→弧事件即将解析；
        //    或刚反弹离开→毫秒级回到框内）的球。沿弧切向蹭行（|vr|≈0，如贴长库滚过中袋
        //    fillet 区）不豁免——该状态下弧 CCD 会以微小 dt 反复出事件（zero-time 风暴），
        //    解算器数千次短模拟被拖垮；维持原软钳把它压回框内即可。
        let mouthSlack: Float = 0.012
        let radialGate: Float = 0.02   // m/s
        for arc in tableGeometry.circularCushions {
            let dxA = state.position.x - arc.center.x
            let dzA = state.position.z - arc.center.z
            let dA = sqrtf(dxA * dxA + dzA * dzA)
            guard dA > 1e-6, dA <= arc.radius + BallPhysics.radius + mouthSlack else { continue }
            guard arc.isAngleInRange(atan2f(dzA, dxA)) else { continue }
            let vr = (state.velocity.x * dxA + state.velocity.z * dzA) / dA
            if abs(vr) > radialGate { return }
        }
        // 不在任何袋嘴通道/弧接触带内（或正从接缝漏出）→ 硬钳回库线 + 反弹（数值安全网）。
        
        // Not near any pocket — hard clamp (numerical safety net)
        let restitution: Float = 0.5
        
        if state.position.x < safeMinX {
            state.position.x = safeMinX
            state.velocity.x = abs(state.velocity.x) * restitution
        } else if state.position.x > safeMaxX {
            state.position.x = safeMaxX
            state.velocity.x = -abs(state.velocity.x) * restitution
        }
        
        if state.position.z < safeMinZ {
            state.position.z = safeMinZ
            state.velocity.z = abs(state.velocity.z) * restitution
        } else if state.position.z > safeMaxZ {
            state.position.z = safeMaxZ
            state.velocity.z = -abs(state.velocity.z) * restitution
        }
        
        state.state = EngineNumerics.determineMotionState(state)
        // 硬钳是事件流之外的状态突变：作废该球缓存，避免按钳前轨迹预测的陈旧事件
        // （吃库/球球）在钳后接力触发，造成二次非物理反射。
        eventCache.invalidate(affectedBalls: [state.name])
    }
    
    /// Resolve a physics event
    private func resolveEvent(_ event: PhysicsEvent) {
        if case .ballBall = event.type, firstBallBallCollisionTime == nil {
            // Event.time is relative to its prediction origin. Callers have
            // already advanced currentTime to the absolute impact time.
            firstBallBallCollisionTime = currentTime
        }
        
        switch event.type {
        case .ballBall(let ballA, let ballB):
            resolveBallBallCollision(ballA: ballA, ballB: ballB)
            resolvedEvents.append(event.type)
            resolvedEventTimes.append(currentTime)
            
        case .ballCushion(let ball, let cushionIndex, let normal):
            // 仅在冲量真正施加时记录事件（与 .pocket 同模式）：被「只推不拉」护栏跳过的
            // 过时事件不计入吃库数，避免下游（吃库计数/回放）看到未发生的碰撞。
            let applied = resolveBallCushionCollision(ball: ball, cushionIndex: cushionIndex, normal: normal)
            if applied {
                resolvedEvents.append(event.type)
                resolvedEventTimes.append(currentTime)
            }
            
        case .transition(let ball, let fromState, let toState):
            resolveTransition(ball: ball, fromState: fromState, toState: toState)
            resolvedEvents.append(event.type)
            resolvedEventTimes.append(currentTime)
            
        case .pocket(let ball, let pocketId):
            // Record the event only if the ball was actually pocketed.
            // Previously events were recorded before resolution, causing game-rule layers
            // to see false pockets when resolvePocket's suspicious-pocket guard rejected the event.
            let pocketed = resolvePocket(ball: ball, pocketId: pocketId)
            if pocketed {
                resolvedEvents.append(event.type)
                resolvedEventTimes.append(currentTime)
            }
        }
    }
    
    /// Resolve ball-ball collision using pure computation
    private func resolveBallBallCollision(ballA: String, ballB: String) {
        guard var stateA = balls[ballA], var stateB = balls[ballB] else { return }
        guard !stateA.isPocketed && !stateB.isPocketed else { return }
        
        // Ref: pooltool/physics/resolve/ball_ball/core.py CoreBallBallCollision.make_kiss
        // Precisely position both balls at 2R + MIN_DIST separation before resolving
        // the collision impulse. Without this, floating-point drift from event evolution
        // leaves the balls slightly interpenetrating, causing cascading zero-time events.
        EngineNumerics.makeBallBallKiss(stateA: &stateA, stateB: &stateB)
        
        let result = CollisionResolver.resolveBallBallPure(
            posA: stateA.position,
            posB: stateB.position,
            velA: stateA.velocity,
            velB: stateB.velocity,
            angVelA: stateA.angularVelocity,
            angVelB: stateB.angularVelocity
        )
        
        stateA.velocity = result.velA
        stateA.angularVelocity = result.angVelA
        stateB.velocity = result.velB
        stateB.angularVelocity = result.angVelB
        
        stateA.state = EngineNumerics.determineMotionState(stateA)
        stateB.state = EngineNumerics.determineMotionState(stateB)
        
        balls[ballA] = stateA
        balls[ballB] = stateB
    }
    
    /// Resolve ball-cushion collision using pure computation.
    /// 完整解算编排已抽至 `EngineNumerics.resolveCushionImpact`（B3 单一真源，
    /// 引擎与 `AnalyticShotRollout` 共用）；此处仅做引擎状态表的读写包装。
    /// - Returns: `true` 当冲量真正施加；`false` 当事件因球已退离库面而被跳过。
    @discardableResult
    private func resolveBallCushionCollision(ball: String, cushionIndex: Int, normal: SCNVector3) -> Bool {
        guard var state = balls[ball] else { return false }
        guard !state.isPocketed else { return false }
        let applied = EngineNumerics.resolveCushionImpact(
            state: &state, cushionIndex: cushionIndex, normal: normal, geometry: tableGeometry)
        guard applied else { return false }
        balls[ball] = state
        return true
    }
    
    /// Resolve state transition
    private func resolveTransition(ball: String, fromState: BallMotionState, toState: BallMotionState) {
        guard var state = balls[ball] else { return }
        guard state.state == fromState else { return }
        
        state.state = toState
        
        // When transitioning to rolling, ensure angular velocity matches rolling condition
        if toState == .rolling {
            let up = SCNVector3(0, 1, 0)
            let wRolling = up.cross(state.velocity) * (1.0 / BallPhysics.radius)
            state.angularVelocity = SCNVector3(wRolling.x, state.angularVelocity.y, wRolling.z)
        }
        
        // When transitioning to spinning, zero linear velocity
        if toState == .spinning {
            state.velocity = SCNVector3Zero
        }
        
        // When transitioning to stationary, zero everything
        if toState == .stationary {
            state.velocity = SCNVector3Zero
            state.angularVelocity = SCNVector3Zero
        }
        
        balls[ball] = state
    }
    
    /// Resolve pocket event. Returns true if the ball was actually pocketed, false if rejected.
    @discardableResult
    private func resolvePocket(ball: String, pocketId: String) -> Bool {
        guard var state = balls[ball], !state.isPocketed else { return false }
        
        // 落袋判据（ADR-P10-09，XZ 2D）：球心水平投影进入孔圈（dist ≤ 孔半径）⇒ 台面无法再
        // 提供支撑 ⇒ 必然坠落。CCD 已把球精确演进到孔圈交点，这里只校验事件未过时
        // （排定后状态被改写的陈旧事件按超距拒绝），无任何速度/方向特判。
        if let pocket = tableGeometry.pockets.first(where: { $0.id == pocketId }) {
            let dx = state.position.x - pocket.center.x
            let dz = state.position.z - pocket.center.z
            let dist = sqrtf(dx * dx + dz * dz)
            // 2mm 容差 ≫ 浮点接触噪声，≪ 任何真实位移——只挡陈旧事件，不挡合法入圈。
            if dist > pocket.radius + 0.002 {
                return false
            }
            trajectoryRecorder.recordPocketEntry(ball: state, pocketID: pocketId, time: currentTime,
                                                 source: .event, geometry: tableGeometry)
            // 记录位置吸附到袋心：使轨迹终点明确「进洞」，下游（橙线终点/回放入洞段起点
            // 取进袋前一帧真实位置）与画面一致。
            state.position = SCNVector3(pocket.center.x, state.position.y, pocket.center.z)
        }
        state.state = .pocketed
        state.velocity = SCNVector3Zero
        state.angularVelocity = SCNVector3Zero
        
        balls[ball] = state
        return true
    }
    
    /// Invalidate cache for affected balls in an event
    private func invalidateCache(for event: PhysicsEvent) {
        var affectedBalls: Set<String> = []
        
        switch event.type {
        case .ballBall(let ballA, let ballB):
            affectedBalls.insert(ballA)
            affectedBalls.insert(ballB)
        case .ballCushion(let ball, _, _):
            affectedBalls.insert(ball)
        case .transition(let ball, _, _):
            affectedBalls.insert(ball)
        case .pocket(let ball, _):
            affectedBalls.insert(ball)
        }
        
        eventCache.invalidate(affectedBalls: affectedBalls)
    }
    
    /// Record current state snapshot to trajectory recorder
    private func recordSnapshot() {
        for name in ballOrder {
            guard let ball = balls[name] else { continue }
            let frame = BallFrame(
                time: currentTime,
                position: ball.position,
                velocity: ball.velocity,
                angularVelocity: SCNVector4(ball.angularVelocity.x, ball.angularVelocity.y, ball.angularVelocity.z, 0),
                state: ball.state
            )
            trajectoryRecorder.recordFrame(ballName: name, frame: frame)
        }
    }
}
