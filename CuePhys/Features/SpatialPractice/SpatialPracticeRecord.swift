import SceneKit
import simd

/// Dedicated local archive. Never decoded as a planar training result or exported sequence.
struct SpatialPracticeRecord: Codable {
    struct Vector: Codable, Equatable {
        var x: Float; var y: Float; var z: Float
        init(_ value: SCNVector3) { x=value.x; y=value.y; z=value.z }
        var scene: SCNVector3 { SCNVector3(x,y,z) }
        var finite: Bool { x.isFinite && y.isFinite && z.isFinite }
    }
    struct Pose: Codable, Equatable {
        var position: Vector
        var rotation: [Float]
        var disposition: String // bed / pocket / outside / escaped
    }
    struct Input: Codable, Equatable {
        static let maximumPracticeElevation:Double = 75
        /// Only editable practice drafts are limited. Archived physical shots
        /// retain their original angle so replay is never silently recomputed.
        func limitingPracticeElevation()->Self {
            var result=self
            if result.elevation.isFinite { result.elevation=min(Self.maximumPracticeElevation,max(0,result.elevation)) }
            return result
        }
        var yaw: Double = 0
        var speed: Double = ShotTuning.defaultVelocity
        var spinX: Double = 0
        var spinY: Double = 0
        var elevation: Double = 45
        /// While clearance overrides the setting, retain it for the next geometry change.
        var preferredElevation: Double? = nil
        var valid: Bool {
            valid(maximumSpeed:8)
        }
        func valid(maximumSpeed:Double)->Bool {
            [yaw,speed,spinX,spinY,elevation].allSatisfy(\.isFinite) &&
            (preferredElevation.map { (0...Self.maximumPracticeElevation).contains($0) } ?? true) &&
            (0.1...maximumSpeed).contains(speed) && (0...85).contains(elevation) && spinX*spinX+spinY*spinY <= 0.64 + 1e-8
        }
        var aim: SCNVector3 { SCNVector3(Float(cos(yaw)),0,Float(sin(yaw))) }
        var radians: Float { Float(elevation * .pi / 180) }
    }
    struct Sample: Codable {
        let time: Float
        let position: Vector
        let rotation: [Float]
        let hidden: Bool
    }
    struct Sound: Codable { let time:Float;let kind:String;let speed:Float }
    struct BreakContext: Codable, Equatable {
        var ordinaryInput:Input
        var prepared:BreakFlowRunner.SavedInput
        var valid:Bool {
            let p=prepared
            return ordinaryInput.valid && [15,9,6,5,4].contains(p.count) &&
                p.cue.x.isFinite && p.cue.y.isFinite && (0...1).contains(p.cue.x) && (0...0.5).contains(p.cue.y) &&
                [p.velocity,p.spinX,p.spinY].allSatisfy(\.isFinite) && (0.1...10).contains(p.velocity) &&
                p.spinX*p.spinX+p.spinY*p.spinY<=0.64+1e-8 &&
                (p.direction.map { $0.count==3 && $0.allSatisfy(\.isFinite) } ?? true)
        }
    }
    struct Shot: Codable {
        var recovered:[String:Pose]? = nil
        var recoveries:[SpatialPracticeRecovery.Event]? = nil
        var selectedTargetKey:String? = nil
        var camera:CameraRig.TrainingBookmark? = nil
        var breakContext:BreakContext? = nil
        var sounds:[Sound]? = nil
        var firstContactTime:Float? = nil
        var firstContactKeys:[String]? = nil
        let id: UUID
        let geometryVersion: String
        let input: Input
        let before: [String: Pose]
        let after: [String: Pose]
        let paths: [String: [Sample]]
        let duration: Float
        let maximumHeight: Float
        let landing: Vector?
    }
    var selectedTargetKey:String? = nil
    var version = 2
    var board: [String: Pose]
    var input: Input
    var lastShot: Shot?
    var breakContext:BreakContext? = nil
    var breakGameBallCount:Int? = nil

    private static func validBoard(_ board:[String:Pose])->Bool {
        board.count<=16 && board.allSatisfy { key,pose in
            PositionPlayBall.allKeys.contains(key) && pose.position.finite &&
            SpatialPracticeGeometry.contains(SIMD3(Double(pose.position.x),Double(pose.position.y),Double(pose.position.z))) &&
            pose.rotation.count==4 && pose.rotation.allSatisfy(\.isFinite) &&
            ["bed","pocket","outside","escaped"].contains(pose.disposition)
        }
    }
    var valid: Bool {
        guard [1,2].contains(version),input.valid(maximumSpeed:breakContext == nil ? 8 : 10),
              breakContext?.valid != false,Self.validBoard(board),
              breakGameBallCount.map({ [15,9,6,5,4].contains($0) }) ?? true else { return false }
        return lastShot.map(Self.validShot) ?? true
    }
    static func validShot(_ shot:Shot)->Bool {
        if let board=shot.recovered {
            let expected=SpatialPracticeRecovery.recover(shot.after,before:shot.before)
            guard Self.validBoard(board),board==expected.board,shot.recoveries==expected.events else { return false }
        }
        if let events=shot.recoveries {
            guard Set(events.map(\.key)).count==events.count,events.allSatisfy({
                PositionPlayBall.allKeys.contains($0.key) && ["outside","escaped","pocket"].contains($0.reason) &&
                ($0.destination.map { Self.validBoard([PositionPlayBall.cueKey:$0]) && $0.disposition == "bed" } ?? true)
            }) else { return false }
        }
        if let camera=shot.camera {
            guard camera.pose.count==8,camera.orbit.count==8,camera.viewing.count==3,
                (camera.pose+camera.orbit+camera.viewing).allSatisfy(\.isFinite),
                (1...179).contains(camera.pose[7]),CameraRig.PlayerView(rawValue:camera.mode) != nil else { return false }
        }
        guard shot.geometryVersion==SpatialPracticeGeometry.version,shot.duration.isFinite,
              (0...45).contains(shot.duration),shot.input.valid(maximumSpeed:shot.breakContext == nil ? 8 : 10),
              shot.breakContext?.valid != false,Self.validBoard(shot.before),Self.validBoard(shot.after),
              shot.maximumHeight.isFinite,shot.maximumHeight>=0,shot.paths.count<=16 else { return false }
        return shot.paths.allSatisfy { key,samples in
            guard PositionPlayBall.allKeys.contains(key),!samples.isEmpty,samples.count<=100000 else { return false }
            var previous:Float = -1
            for sample in samples {
                guard sample.time.isFinite,sample.time>=0,sample.time>=previous,sample.time<=shot.duration,
                      sample.position.finite,sample.rotation.count==4,sample.rotation.allSatisfy(\.isFinite) else { return false }
                previous=sample.time
            }
            return true
        } && (shot.sounds ?? []).allSatisfy { $0.time.isFinite && $0.time>=0 && $0.time<=shot.duration &&
            $0.speed.isFinite && $0.speed>=0 && ShotSoundKind(rawValue:$0.kind) != nil }
    }

    mutating func migrateRecoveredBoard() {
        board=SpatialPracticeRecovery.recover(board,before:lastShot?.before ?? board).board
        if var shot=lastShot,shot.recovered == nil {
            let result=SpatialPracticeRecovery.recover(shot.after,before:shot.before)
            shot.recovered=result.board;shot.recoveries=result.events;lastShot=shot
        }
        version=2
    }

    /// Exact accepted contact times, with the existing soft impact sample as an
    /// explicit auditory approximation for cloth / wood / floor (not a measured recording).
    static func spatialSounds(_ recorder:TrajectoryRecorder)->[Sound] {
        guard let roles=try? PocketGeometryAsset.load().surfaceRoles() else { return [] }
        var emitted:[String:Double]=[:],sounds:[Sound]=[]
        for event in recorder.localStaticContacts.sorted(by:{$0.contact.time<$1.contact.time}) {
            let c=event.contact
            if roles.indices.contains(c.surface),roles[c.surface] == .cushion { continue } // legacy timeline already carries these
            guard c.time>0,let span=recorder.localInterval(ballName:event.ballName,time:c.time,incoming:true),
                  let state=span.sample(at:c.time,beforeEndpoint:true) else { continue }
            let speed=max(0,-simd_dot(state.velocity,c.normal))
            guard speed>0.04,c.time-(emitted[event.ballName] ?? -1)>1e-6 else { continue }
            emitted[event.ballName]=c.time
            sounds.append(.init(time:Float(c.time),kind:ShotSoundKind.cushion.rawValue,speed:Float(speed)))
        }
        return sounds
    }

    /// Use the incoming state of an accepted cloth contact: the endpoint state
    /// already contains the upward rebound and cannot identify the first landing.
    static func firstLanding(_ recorder:TrajectoryRecorder)->Vector? {
        guard let roles=try? PocketGeometryAsset.load().surfaceRoles() else { return nil }
        let spans=recorder.localIntervalsByBallName[ShotInput.cueBallName] ?? []
        let bed=Double(BTTablePhysics.surfaceY+BallPhysics.radius)
        for event in recorder.localStaticContacts.sorted(by:{$0.contact.time<$1.contact.time}) where event.ballName==ShotInput.cueBallName {
            let c=event.contact
            guard roles.indices.contains(c.surface),roles[c.surface] == .clothBed,
                  let span=recorder.localInterval(ballName:ShotInput.cueBallName,time:c.time,incoming:true),
                  let incoming=span.sample(at:c.time,beforeEndpoint:true),incoming.velocity.y < -0.001 else { continue }
            let wasAirborne=spans.contains { interval in
                guard interval.start.time<c.time else { return false }
                let duration=min(interval.end.time,c.time)-interval.start.time
                let apex=interval.acceleration.y<0 ? min(duration,max(0,-interval.start.velocity.y/interval.acceleration.y)) : duration
                let peak=interval.sample(at:interval.start.time+apex,beforeEndpoint:true)?.position.y ?? interval.start.position.y
                return max(interval.start.position.y,peak)>bed+0.0001
            }
            if wasAirborne {
                return Vector(SCNVector3(Float(incoming.position.x),Float(incoming.position.y),Float(incoming.position.z)))
            }
        }
        return nil
    }

    /// Presentation sampling only: physics is solved once. Include committed event times,
    /// with a 240 Hz ceiling between events (gravity chord error <= 0.022 mm).
    static func freeze(prediction: ShotPrediction, input: Input, before: [String: Pose],
                       cancellation:PredictionCancellation? = nil) -> Shot? {
        guard cancellation?.isCancelled != true,prediction.hasFinalTableState, let recorder=prediction.recorder,
              prediction.duration.isFinite, prediction.duration <= 45 else { return nil }
        recorder.prepareLocalIntervalIndex()
        let playback=TrajectoryPlayback(recorder:recorder,surfaceY:BTTablePhysics.surfaceY+BallPhysics.radius)
        let duration=playback.duration
        guard duration.isFinite, duration <= 45 else { return nil }
        var times=Set((0...Int(ceil(Double(duration)*240))).map { min(duration,Float($0)/240) })
        for frames in recorder.framesByBallName.values { times.formUnion(frames.map(\.time).filter { $0 <= duration }) }
        for spans in recorder.localIntervalsByBallName.values {
            times.formUnion(spans.flatMap { [Float($0.start.time),Float($0.end.time)] }.filter { $0 <= duration })
        }
        times.formUnion(recorder.spatialDomainExits.values.map {Float($0.time)}.filter {$0>=0 && $0<=duration})
        let sorted=times.sorted()
        var paths:[String:[Sample]]=[:], after=before
        var peak:Float=0
        let landing=firstLanding(recorder)
        for key in before.keys.sorted() where before[key]?.disposition != "pocket" && before[key]?.disposition != "escaped" {
            guard cancellation?.isCancelled != true else { return nil }
            let name=PositionPlayBall.isCue(key) ? ShotInput.cueBallName : key
            let exit=recorder.spatialDomainExits[name]
            var rotation=simd_quatf(vector:SIMD4(before[key]!.rotation[0],before[key]!.rotation[1],before[key]!.rotation[2],before[key]!.rotation[3]))
            var previous:PlaybackBallState?, lastTime:Float=0, samples:[Sample]=[]
            for (sampleIndex,time) in sorted.enumerated() {
                if sampleIndex.isMultiple(of:64),cancellation?.isCancelled == true { return nil }
                guard var state=playback.stateAt(ballName:name,time:time) else { continue }
                if time >= prediction.duration,let final=prediction.finalPositions[name] {
                    state=PlaybackBallState(position:final,velocity:SCNVector3Zero,motionState:.stationary,
                        angularVelocity:SCNVector3Zero,moveDirection:SCNVector3Zero)
                }
                if let exit,time>=Float(exit.time) {
                    state=PlaybackBallState(position:SCNVector3(Float(exit.position.x),Float(exit.position.y),Float(exit.position.z)),velocity:SCNVector3Zero,
                        motionState:.stationary,angularVelocity:SCNVector3Zero,moveDirection:SCNVector3Zero)
                }
                if let previous {
                    rotation=simd_normalize(BallSpinIntegrator.delta(angularVelocity:(previous.angularVelocity+state.angularVelocity)*0.5,
                        dt:time-lastTime)*rotation)
                }
                let q=rotation.vector
                let sample=Sample(time:time,position:.init(state.position),rotation:[q.x,q.y,q.z,q.w],
                    hidden:recorder.isBallPocketed(name,at:Double(time)) || exit.map { time>=Float($0.time) } == true)
                // Only exact constant spans are compacted. Keep both endpoints,
                // including the last static instant before the next movement.
                // Moving/spinning samples and every visibility change survive.
                if samples.count>=2,
                   samePresentation(samples[samples.count-2],samples[samples.count-1]),
                   samePresentation(samples[samples.count-1],sample) {
                    samples[samples.count-1]=sample
                } else { samples.append(sample) }
                if PositionPlayBall.isCue(key) {
                    let height=state.position.y-BTTablePhysics.surfaceY-BallPhysics.radius
                    peak=max(peak,height)
                }
                previous=state;lastTime=time
            }
            guard let final=prediction.finalPositions[name], let last=samples.last else { return nil }
            let disposition=exit != nil ? "escaped" : prediction.pocketedBalls.contains(name) ? "pocket" : (SpatialPracticeGeometry.isOnBed(final) ? "bed" : "outside")
            after[key] = .init(position:.init(final),rotation:last.rotation,disposition:disposition)
            paths[key]=samples
        }
        let contact=firstCueContact(prediction.events)
        return Shot(firstContactTime:contact?.time,firstContactKeys:contact?.keys,id:UUID(),geometryVersion:SpatialPracticeGeometry.version,input:input,before:before,after:after,
            paths:paths,duration:duration,maximumHeight:peak,landing:landing)
    }

    /// Connected same-time contact group, independent of event enumeration order.
    static func firstCueContact(_ events:[ShotEvent])->(time:Float,keys:[String])? {
        let cue=ShotInput.cueBallName
        guard let time=events.filter({ event in
            if case let .ballBall(a,b)=event.kind { return a==cue || b==cue };return false
        }).map(\.time).min() else { return nil }
        let contacts=events.filter { abs($0.time-time)<=1e-6 }
        var names:Set<String>=[cue],changed=true
        while changed {
            changed=false
            for event in contacts {
                guard case let .ballBall(a,b)=event.kind,names.contains(a) || names.contains(b) else { continue }
                changed = names.insert(a).inserted || changed
                changed = names.insert(b).inserted || changed
            }
        }
        return (time,names.filter { $0 != cue }.sorted())
    }

    static func visibleRoute(_ shot:Shot,key:String,detail:TrajectoryDetail)->[SCNVector3] {
        let cue=PositionPlayBall.isCue(key)
        guard detail == .full || cue || (detail == .core && (shot.firstContactKeys ?? []).contains(key)) else { return [] }
        let cutoff=detail == .minimal ? (shot.firstContactTime ?? shot.duration) : shot.duration
        let points=(shot.paths[key] ?? []).prefix { !$0.hidden && $0.time<=cutoff }.map { $0.position.scene }
        guard let first=points.first,points.contains(where:{ abs($0.x-first.x)+abs($0.y-first.y)+abs($0.z-first.z)>0.00001 }) else { return [] }
        return points
    }

    /// Presentation-only polyline reduction. Every source vertex remains within
    /// 0.05 mm of its replacement segment; frozen physics/playback is untouched.
    static func reducedRoute(_ points:[SCNVector3],tolerance:Float=0.00005)->[SCNVector3] {
        guard points.count>2 else { return points }
        var keep:Set<Int>=[0,points.count-1],stack=[(0,points.count-1)]
        while let (a,b)=stack.popLast() {
            guard b>a+1 else { continue }
            let p=SIMD3(points[a].x,points[a].y,points[a].z),q=SIMD3(points[b].x,points[b].y,points[b].z)
            let d=q-p,length=simd_length_squared(d)
            var worst=tolerance*tolerance,index:Int?
            for i in (a+1)..<b {
                let v=SIMD3(points[i].x,points[i].y,points[i].z)
                let t=length>0 ? min(1,max(0,simd_dot(v-p,d)/length)) : 0
                let error=simd_length_squared(v-(p+d*t))
                if error>worst { worst=error;index=i }
            }
            if let index { keep.insert(index);stack.append((a,index));stack.append((index,b)) }
        }
        return keep.sorted().map { points[$0] }
    }

    static func samePresentation(_ a:Sample,_ b:Sample)->Bool {
        a.position==b.position && a.rotation==b.rotation && a.hidden==b.hidden
    }
}
