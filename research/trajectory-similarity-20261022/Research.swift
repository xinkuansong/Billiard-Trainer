// Research-only: appended to a frozen XCTest snapshot. Production files are unchanged.
final class TrajectorySimilarityResearchTests: XCTestCase {
    func testExport() throws {
        let out = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/research/trajectory-similarity-20261022")
        func xy(_ p: SCNVector3) -> [Float] { [p.x,p.z] }
        func evolve(_ f: BallFrame,_ dt: Float) -> SCNVector3 {
            let w = SCNVector3(f.angularVelocity.x,f.angularVelocity.y,f.angularVelocity.z)
            switch f.state {
            case .sliding: return AnalyticalMotion.evolveSliding(position:f.position,velocity:f.velocity,angularVelocity:w,dt:dt).position
            case .rolling: return AnalyticalMotion.evolveRolling(position:f.position,velocity:f.velocity,angularVelocity:w,dt:dt).position
            default: return f.position
            }
        }
        var rows: [[String:Any]] = []
        // These are reproducible research inputs inspired by the supplied scene, not a pixel reconstruction.
        let cue = SCNVector3(-0.40,0,0), target = SCNVector3(0.55,0,-0.18)
        let settings: [(String,Float,Float,Float)] = [
            ("pot_center",1.5,0,0),("pot_repeat",1.5,0,0),
            ("pot_side_small",1.5,0.1,0),("pot_right",1.5,0.5,0),
            ("pot_left",1.5,-0.5,0),("pot_follow",1.5,0,0.5),
            ("pot_draw",1.5,0,-0.5),("pot_fast",3,0,0),
            ("pot_multirail",5.21,0.4,0.4)]
        for s in settings {
            let p = ShotPredictor.predict(ShotInput(cueBall:cue,targetBall:target,pocketIndex:1,velocity:s.1,spinX:s.2,spinY:s.3,surfaceY:0),maxEvents:2000,maxTime:90)
            guard let direction=p.strikeDirection else { XCTFail("No solved direction: \(s.0)"); continue }
            rows.append(try export(s.0,s.1,s.2,s.3,cue,direction,[ObstacleBall(name:ShotInput.targetBallName,position:target)]))
        }
        for (id,speed,degrees) in [("free_short",Float(0.7),Float(22)),("free_medium",1.5,22),("free_long",3,22),("free_multi",4.5,22),("free_angle_small",3,22.5),("free_angle_large",3,35)] {
            let a=degrees * .pi / 180
            rows.append(try export(id,speed,0,0,SCNVector3(-0.8,0,-0.25),SCNVector3(cosf(a),0,sinf(a)),[]))
        }
        func export(_ id:String,_ speed:Float,_ sx:Float,_ sy:Float,_ cue:SCNVector3,_ direction:SCNVector3,_ balls:[ObstacleBall]) throws -> [String:Any] {
            let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:direction,velocity:speed,spinX:sx,spinY:sy,surfaceY:0,balls:balls,maxEvents:2000,maxTime:90,includePresentation:false,recordedStrikeDirection:direction)
            let recorder=try XCTUnwrap(p.recorder)
            let capture=recorder.pocketEntries.first{$0.ball.name==ShotInput.cueBallName}
            let end=capture?.time ?? Float.infinity
            let raw=(recorder.framesByBallName[ShotInput.cueBallName] ?? []).filter{$0.time<=end && $0.state != .pocketed}
            XCTAssertGreaterThan(raw.count,1)
            var frames=raw
            if let capture { frames.append(BallFrame(time:capture.time,position:capture.ball.position,velocity:capture.ball.velocity,angularVelocity:SCNVector4(capture.ball.angularVelocity.x,capture.ball.angularVelocity.y,capture.ball.angularVelocity.z,0),state:capture.ball.state)) }
            var dense:[[Float]]=[],times:[Float]=[],maxPredictionGap:Float=0
            for i in frames.indices {
                let f=frames[i];dense.append(xy(f.position));times.append(f.time)
                if i+1<frames.count {
                    let dt=frames[i+1].time-f.time
                    XCTAssertGreaterThanOrEqual(dt,0)
                    if dt>0 {
                        let predicted=evolve(f,dt)
                        maxPredictionGap=max(maxPredictionGap,hypot(predicted.x-frames[i+1].position.x,predicted.z-frames[i+1].position.z))
                        let n=max(1,Int(ceil(dt/0.001)))
                        for k in 1..<n {let t=dt*Float(k)/Float(n);dense.append(xy(evolve(f,t)));times.append(f.time+t)}
                    }
                }
            }
            var events:[[String:Any]]=[]
            for e in p.events {
                var kind:String?=nil
                switch e.kind {
                case let .ballCushion(n):if n==ShotInput.cueBallName {kind="cushion"}
                case let .ballBall(a,b):if a==ShotInput.cueBallName || b==ShotInput.cueBallName {kind="ball"}
                default:break
                }
                if let kind,let f=frames.last(where:{$0.time<=e.time}) {
                    XCTAssertLessThanOrEqual(abs(f.time-e.time),0.00001)
                    events.append(["kind":kind,"time":e.time,"position":xy(f.position),"rail":e.cushionIndex ?? -1])
                }
            }
            XCTAssertTrue(p.hasFinalTableState,"Incomplete \(id): \(p.termination)")
            XCTAssertLessThan(maxPredictionGap,0.0001,"Dense reconstruction disagrees with engine endpoints \(id)")
            print("TRAJECTORY \(id) frames=\(frames.count) events=\(events.count) gap=\(maxPredictionGap)")
            return ["id":id,"speed":speed,"spinX":sx,"spinY":sy,"cue":xy(cue),"direction":xy(direction),"points_m":dense,"times":times,"rawFrames":frames.map{["time":$0.time,"position":xy($0.position),"velocity":xy($0.velocity),"state":$0.state.rawValue] as [String:Any]},"events":events,"termination":String(describing:p.termination),"settled":p.hasFinalTableState,"scratch":p.cuePocketed,"maxReconstructionGap_m":maxPredictionGap]
        }
        try JSONSerialization.data(withJSONObject:["rows":rows,"unit":"metre","axes":"X,Z","table":[TablePhysics.innerLength,TablePhysics.innerWidth],"source":"ShotPredictor.simulateFree; appDefault; includePresentation=false"],options:[.sortedKeys]).write(to:out.appendingPathComponent("engine-trajectories.json"),options:.atomic)
        XCTAssertEqual(rows.count,15)
    }
}
