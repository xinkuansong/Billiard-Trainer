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
    struct Pose: Codable {
        var position: Vector
        var rotation: [Float]
        var disposition: String // bed / pocket / outside / escaped
    }
    struct Input: Codable {
        var yaw: Double = 0
        var speed: Double = 3
        var spinX: Double = 0
        var spinY: Double = 0
        var elevation: Double = 45
        var valid: Bool {
            [yaw,speed,spinX,spinY,elevation].allSatisfy(\.isFinite) &&
            (0.1...8).contains(speed) && (0...85).contains(elevation) && spinX*spinX+spinY*spinY <= 0.64 + 1e-8
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
    struct Shot: Codable {
        var sounds:[Sound]? = nil
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
    var version = 1
    var board: [String: Pose]
    var input: Input
    var lastShot: Shot?

    private static func validBoard(_ board:[String:Pose])->Bool {
        board.count<=16 && board.allSatisfy { key,pose in
            PositionPlayBall.allKeys.contains(key) && pose.position.finite &&
            SpatialPracticeGeometry.contains(SIMD3(Double(pose.position.x),Double(pose.position.y),Double(pose.position.z))) &&
            pose.rotation.count==4 && pose.rotation.allSatisfy(\.isFinite) &&
            ["bed","pocket","outside","escaped"].contains(pose.disposition)
        }
    }
    var valid: Bool {
        guard version==1,input.valid,Self.validBoard(board) else { return false }
        guard let shot=lastShot else { return true }
        guard shot.geometryVersion==SpatialPracticeGeometry.version,shot.duration.isFinite,
              (0...45).contains(shot.duration),shot.input.valid,Self.validBoard(shot.before),Self.validBoard(shot.after),
              shot.maximumHeight.isFinite,shot.maximumHeight>=0,shot.paths.count<=16 else { return false }
        return shot.paths.allSatisfy { key,samples in
            guard PositionPlayBall.allKeys.contains(key),!samples.isEmpty,samples.count<=100000 else { return false }
            var previous:Float = -1
            for sample in samples {
                guard sample.time.isFinite,sample.time>=previous,sample.time<=shot.duration,
                      sample.position.finite,sample.rotation.count==4,sample.rotation.allSatisfy(\.isFinite) else { return false }
                previous=sample.time
            }
            return true
        } && (shot.sounds ?? []).allSatisfy { $0.time.isFinite && $0.time>=0 && $0.time<=shot.duration &&
            $0.speed.isFinite && $0.speed>=0 && ShotSoundKind(rawValue:$0.kind) != nil }
    }

    /// Exact accepted contact times, with the existing soft impact sample as an
    /// explicit auditory approximation for cloth / wood / floor (not a measured recording).
    static func spatialSounds(_ recorder:TrajectoryRecorder)->[Sound] {
        guard let roles=try? PocketGeometryAsset.load().surfaceRoles() else { return [] }
        var emitted:[String:Double]=[:],sounds:[Sound]=[]
        for event in recorder.localStaticContacts.sorted(by:{$0.contact.time<$1.contact.time}) {
            let c=event.contact
            if roles.indices.contains(c.surface),roles[c.surface] == .cushion { continue } // legacy timeline already carries these
            guard c.time>0,let span=recorder.localIntervalsByBallName[event.ballName]?.first(where:{$0.start.time<c.time && $0.end.time>=c.time}),
                  let state=span.sample(at:c.time,beforeEndpoint:true) else { continue }
            let speed=max(0,-simd_dot(state.velocity,c.normal))
            guard speed>0.04,c.time-(emitted[event.ballName] ?? -1)>1e-6 else { continue }
            emitted[event.ballName]=c.time
            sounds.append(.init(time:Float(c.time),kind:ShotSoundKind.cushion.rawValue,speed:Float(speed)))
        }
        return sounds
    }

    /// Presentation sampling only: physics is solved once. Include committed event times,
    /// with a 240 Hz ceiling between events (gravity chord error <= 0.022 mm).
    static func freeze(prediction: ShotPrediction, input: Input, before: [String: Pose]) -> Shot? {
        guard prediction.hasFinalTableState, let recorder=prediction.recorder,
              prediction.duration.isFinite, prediction.duration <= 45 else { return nil }
        let playback=TrajectoryPlayback(recorder:recorder,surfaceY:BTTablePhysics.surfaceY+BallPhysics.radius)
        let duration=playback.duration
        guard duration.isFinite, duration <= 45 else { return nil }
        var times=Set((0...Int(ceil(Double(duration)*240))).map { min(duration,Float($0)/240) })
        for frames in recorder.framesByBallName.values { times.formUnion(frames.map(\.time).filter { $0 <= duration }) }
        for spans in recorder.localIntervalsByBallName.values {
            times.formUnion(spans.flatMap { [Float($0.start.time),Float($0.end.time)] }.filter { $0 <= duration })
        }
        let sorted=times.sorted()
        var paths:[String:[Sample]]=[:], after=before
        var peak:Float=0, landing:Vector?
        var flew=false
        for key in before.keys.sorted() where before[key]?.disposition != "pocket" && before[key]?.disposition != "escaped" {
            let name=PositionPlayBall.isCue(key) ? ShotInput.cueBallName : key
            let exit=recorder.spatialDomainExits[name]
            var rotation=simd_quatf(vector:SIMD4(before[key]!.rotation[0],before[key]!.rotation[1],before[key]!.rotation[2],before[key]!.rotation[3]))
            var previous:PlaybackBallState?, lastTime:Float=0, samples:[Sample]=[]
            for time in sorted {
                guard var state=playback.stateAt(ballName:name,time:time) else { continue }
                if time >= prediction.duration,let final=prediction.finalPositions[name] {
                    state=PlaybackBallState(position:final,velocity:SCNVector3Zero,motionState:.stationary,
                        angularVelocity:SCNVector3Zero,moveDirection:SCNVector3Zero)
                }
                if let exit,Double(time)>=exit.time {
                    state=PlaybackBallState(position:SCNVector3(Float(exit.position.x),Float(exit.position.y),Float(exit.position.z)),velocity:SCNVector3Zero,
                        motionState:.stationary,angularVelocity:SCNVector3Zero,moveDirection:SCNVector3Zero)
                }
                if let previous {
                    rotation=simd_normalize(BallSpinIntegrator.delta(angularVelocity:(previous.angularVelocity+state.angularVelocity)*0.5,
                        dt:time-lastTime)*rotation)
                }
                let q=rotation.vector
                samples.append(.init(time:time,position:.init(state.position),rotation:[q.x,q.y,q.z,q.w],
                    hidden:recorder.isBallPocketed(name,at:Double(time)) || exit.map { Double(time)>=$0.time } == true))
                if PositionPlayBall.isCue(key) {
                    let height=state.position.y-BTTablePhysics.surfaceY-BallPhysics.radius
                    peak=max(peak,height)
                    if height>0.0001 { flew=true }
                    if flew, landing == nil, SpatialPracticeGeometry.isOnBed(state.position), state.velocity.y <= 0 {
                        landing = .init(state.position)
                    }
                }
                previous=state;lastTime=time
            }
            guard let final=prediction.finalPositions[name], let last=samples.last else { return nil }
            let disposition=exit != nil ? "escaped" : prediction.pocketedBalls.contains(name) ? "pocket" : (SpatialPracticeGeometry.isOnBed(final) ? "bed" : "outside")
            after[key] = .init(position:.init(final),rotation:last.rotation,disposition:disposition)
            paths[key]=samples
        }
        return Shot(id:UUID(),geometryVersion:SpatialPracticeGeometry.version,input:input,before:before,after:after,
            paths:paths,duration:duration,maximumHeight:peak,landing:landing)
    }
}
