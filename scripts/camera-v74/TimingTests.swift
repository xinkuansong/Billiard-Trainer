final class P01CameraTimingV74Tests: XCTestCase {
    private let layout = P01CameraMotion.Layout(viewport: .init(874,402), insets: .init(128,42,128,18),
        surfaceY: 0.8, tableHalfExtents: .init(1.405481,0.7775), roomHalfExtents: .init(3.65,2.65),
        ceilingY: 3.6, ballRadius: 0.028575, aimLensAspect: P01CameraMotion.dailyAimLensAspect)
    private func shot(_ degrees: Float = 0) -> P01CameraMotion.Shot {
        let a = degrees * .pi / 180, p = SIMD3<Float>(0,0.828575,0)
        return .init(cue:p,strike:p,aim:.init(cos(a),0,sin(a)),elevation:0.05)
    }
    private func camera(modern: Bool = true) throws -> P01CameraMotion {
        try XCTUnwrap(P01CameraMotion(shot:shot(),layout:layout,anchoredTransitions:true,
            firstPersonSetback:1.482575,generalTiming:modern ? .selectionMatchedV1 : nil))
    }
    func testSelectionSamplesRemainUnchanged() throws {
        for angle: Float in [0.1,1,5,15,30,90,150,180] {
            var old=try camera(modern:false), new=try camera()
            for c in [false,true] {
                if c { XCTAssertTrue(new.selectTarget(shot:shot(angle),preservesVisiblePose:false,turnPace:.selection120)) }
                else { XCTAssertTrue(old.selectTarget(shot:shot(angle),preservesVisiblePose:false,turnPace:.selection120)) }
            }
            let duration=try XCTUnwrap(old.snapshot().motion).duration
            XCTAssertEqual(try XCTUnwrap(new.snapshot().motion).duration,duration)
            for i in 0...100 {
                let time=duration * Double(i)/100
                old.advance(to:time);new.advance(to:time)
                XCTAssertEqual(new.pose,old.pose,"Selection path and clock must remain bit-identical")
            }
        }
    }
    func testGeneralOrbitMatchesSelectionTiming() throws {
        for angle: Float in [0.1,1,5,15,30,90,150,180] {
            var a=try camera(),b=a
            XCTAssertTrue(a.select(.thirdPerson,shot:shot(angle),resetThirdPerson:true))
            XCTAssertTrue(b.select(.thirdPerson,shot:shot(angle),turnPace:.selection120,resetThirdPerson:true))
            let duration=try XCTUnwrap(a.snapshot().motion).duration
            XCTAssertEqual(duration,try XCTUnwrap(b.snapshot().motion).duration,accuracy:0.00002)
            for i in 0...100 {
                a.advance(to:duration*Double(i)/100);b.advance(to:duration*Double(i)/100)
                XCTAssertLessThan(simd_distance(a.pose.eye,b.pose.eye),0.0001)
            }
        }
    }
    func testInterruptsStartAtVisiblePoseAndDoNotAccumulateDelay() throws {
        for fraction in [0.2,0.5,0.8] {
            var c=try camera()
            XCTAssertTrue(c.selectTarget(shot:shot(150),preservesVisiblePose:false,turnPace:.selection120))
            let first=try XCTUnwrap(c.snapshot().motion)
            c.advance(to:first.duration*fraction)
            c.beginObservation();c.pan(.init(80,25));c.release()
            XCTAssertFalse(c.hasPendingMotion)
            let visible=c.pose
            XCTAssertTrue(c.select(.thirdPerson,resetThirdPerson:true))
            let m=try XCTUnwrap(c.snapshot().motion)
            XCTAssertEqual(m.origin,visible)
            XCTAssertLessThanOrEqual(m.duration,1.17)
            c.advance(to:m.start+m.duration)
            XCTAssertFalse(c.hasPendingMotion)
            for _ in 0..<3 {
                c.pan(.init(80,25));let visible=c.pose
                XCTAssertTrue(c.select(.thirdPerson,resetThirdPerson:true))
                let m=try XCTUnwrap(c.snapshot().motion)
                XCTAssertEqual(m.origin,visible)
                XCTAssertLessThan(m.duration,0.4)
                c.advance(to:m.start+m.duration)
            }
        }
    }
    func testRepeatedRequestKeepsArrivalButChangedTargetRedirects() throws {
        var c=try camera()
        XCTAssertTrue(c.select(.thirdPerson,shot:shot(150),resetThirdPerson:true))
        let original=try XCTUnwrap(c.snapshot().motion)
        for i in 1...10 {
            c.advance(to:Double(i)*0.1)
            XCTAssertTrue(c.select(.thirdPerson,resetThirdPerson:true))
            let m=try XCTUnwrap(c.snapshot().motion)
            XCTAssertEqual(m.start,original.start);XCTAssertEqual(m.duration,original.duration)
        }
        let visible=c.pose
        XCTAssertTrue(c.select(.thirdPerson,shot:shot(-120),resetThirdPerson:true))
        let redirected=try XCTUnwrap(c.snapshot().motion)
        XCTAssertEqual(redirected.start,c.time);XCTAssertEqual(redirected.origin,visible)
        c.advance(to:redirected.start+redirected.duration)
        XCTAssertFalse(c.hasPendingMotion)
        XCTAssertTrue(c.select(.thirdPerson,resetThirdPerson:true));XCTAssertFalse(c.hasPendingMotion)
        c.pan(.init(80,0));XCTAssertTrue(c.select(.thirdPerson,resetThirdPerson:true));XCTAssertTrue(c.hasPendingMotion)
    }
    func testLayoutAndContextAreNotDeduplicated() throws {
        var rebound=try camera()
        XCTAssertTrue(rebound.select(.thirdPerson,shot:shot(150),resetThirdPerson:true))
        rebound.advance(to:0.3)
        rebound.updateShot(shot(90),manuallyAimed:false)
        rebound.updateShot(shot(150),manuallyAimed:false)
        XCTAssertTrue(rebound.select(.thirdPerson,resetThirdPerson:true))
        XCTAssertEqual(rebound.snapshot().motion?.start,0.3,"A shot revision invalidates an earlier request identity")
        var c=try camera()
        XCTAssertTrue(c.select(.thirdPerson,shot:shot(150),resetThirdPerson:true));c.advance(to:0.3)
        var changed=layout;changed.viewport = .init(600,500)
        c.setLayout(changed)
        c.setLayout(layout) // Returning to the old size still represents a new layout revision.
        XCTAssertTrue(c.select(.thirdPerson,resetThirdPerson:true))
        XCTAssertEqual(c.snapshot().motion?.start,0.3)
        let context=UUID();c.setContext(context)
        XCTAssertFalse(c.hasPendingMotion)
        XCTAssertTrue(c.select(.thirdPerson,resetThirdPerson:true))
        XCTAssertEqual(c.snapshot().motion?.destination?.context,context)
    }
    func testRadialHeightLensAndFirstPersonDollyHaveFiniteBudgets() throws {
        for (distance,height,fov) in [(Float(2.6),Float(0.65),Float(0)),(1.65,1.4,0),(1.65,0.65,75)] {
            let base=try camera();var snap=base.snapshot()
            snap.state.distance=distance;snap.state.height=height
            if fov>0 { snap.state.observationHorizontalFOV=fov }
            snap.pose=try XCTUnwrap(P01CameraMotion.evaluate(state:snap.state,shot:snap.shot,layout:layout))
            var c=try XCTUnwrap(P01CameraMotion(recording:.init(geometryID:"v74",initial:snap,layout:layout,inputs:[])))
            XCTAssertTrue(c.select(.thirdPerson,resetThirdPerson:true))
            let m=try XCTUnwrap(c.snapshot().motion)
            XCTAssertGreaterThanOrEqual(m.duration,0.32);XCTAssertLessThan(m.duration,0.6)
            var prior=c.pose
            let dt=m.duration/1000
            for i in 1...1000 {
                c.advance(to:m.start+Double(i)*dt)
                XCTAssertTrue(layout.legalEye(c.pose.eye))
                XCTAssertLessThanOrEqual(abs(c.pose.eye.y-prior.eye.y)/Float(dt),1.81)
                XCTAssertLessThanOrEqual(abs(c.pose.pitch-prior.pitch)/Float(dt),.pi/2+0.02)
                XCTAssertLessThanOrEqual(abs(c.pose.verticalFOV-prior.verticalFOV)/Float(dt),40.1)
                prior=c.pose
            }
        }
        var c=try camera();XCTAssertTrue(c.select(.firstPerson,animated:false));c.pinch(0.5,preservingPitch:true)
        XCTAssertTrue(c.select(.firstPerson));XCTAssertGreaterThanOrEqual(try XCTUnwrap(c.snapshot().motion).duration,0.32)
    }
    func testRecordingAndInFlightSnapshotAreCadenceIndependent() throws {
        let base=try camera()
        let inputs: [P01CameraMotion.Input] = [
            .init(time:0,kind:.view,view:.thirdPerson,shot:shot(150),resetThirdPerson:true),
            .init(time:0.35,kind:.beginObservation),.init(time:0.35,kind:.pan,delta:.init(80,25)),
            .init(time:0.5,kind:.view,view:.thirdPerson,resetThirdPerson:true),
            .init(time:0.7,kind:.view,view:.thirdPerson,resetThirdPerson:true)]
        let recording=P01CameraMotion.Recording(geometryID:"v74",initial:base.snapshot(),layout:layout,inputs:inputs)
        let encoded=try JSONEncoder().encode(recording)
        let decoded=try JSONDecoder().decode(P01CameraMotion.Recording.self,from:encoded)
        let checkpoints=[0.2,0.4,0.6,0.8,1.0,1.2,1.4,2.0]
        var expected:[Double:P01CameraMotion.Pose]=[:]
        for t in checkpoints {
            var reference=try XCTUnwrap(P01CameraMotion(recording:decoded))
            for input in inputs where input.time<=t { reference.apply(input) }
            reference.advance(to:t);expected[t]=reference.pose
        }
        let schedules=[30.0,60,120].map { hz in (0...Int(hz*2)).map { Double($0)/hz } }
            + [[0,0.037,0.113,0.277,0.301,0.411,0.778,1.24,1.256,1.97,2]]
        for schedule in schedules {
            var c=try XCTUnwrap(P01CameraMotion(recording:decoded));var cursor=0
            for t in Set(schedule+checkpoints).sorted() {
                while cursor<inputs.count && inputs[cursor].time<=t { c.apply(inputs[cursor]);cursor+=1 }
                c.advance(to:t)
                if let pose=expected[t] { XCTAssertEqual(c.pose,pose) }
            }
            XCTAssertFalse(c.hasPendingMotion)
        }
        var c=try camera();XCTAssertTrue(c.select(.thirdPerson,shot:shot(150),resetThirdPerson:true));c.advance(to:0.4)
        let saved=P01CameraMotion.Recording(geometryID:"v74",initial:c.snapshot(),layout:layout,inputs:[])
        let replay=try JSONDecoder().decode(P01CameraMotion.Recording.self,from:JSONEncoder().encode(saved))
        var resumed=try XCTUnwrap(P01CameraMotion(recording:replay))
        for time in [0.41,0.55,0.9,1.1,1.41,2] {
            c.advance(to:time);resumed.advance(to:time);XCTAssertEqual(c.pose,resumed.pose)
        }
    }
    func testBoundaryMixedPathsAndMovingAnchorsStayLegal() throws {
        for x: Float in [-1.2,0,1.2] { for z: Float in [-0.57,0.57] {
            for angle: Float in [-175,-90,90,175] {
                var c=try camera();var target=shot(angle)
                target.cue += .init(x,0,z);target.strike=target.cue
                c.pinch(0.5,preservingPitch:true);c.pan(.init(250,120))
                XCTAssertTrue(c.select(.thirdPerson,shot:target,resetThirdPerson:true))
                let m=try XCTUnwrap(c.snapshot().motion)
                XCTAssertLessThan(m.duration,4)
                var previous=c.pose
                var previousCenter=m.framing!.start
                let dt=Float(m.duration/500)
                for i in 0...500 {
                    c.advance(to:m.start+m.duration*Double(i)/500)
                    XCTAssertTrue(layout.legalEye(c.pose.eye))
                    XCTAssertTrue([c.pose.rotation.x,c.pose.rotation.y,c.pose.rotation.z,c.pose.rotation.w].allSatisfy(\.isFinite))
                    XCTAssertTrue(c.pose.verticalFOV.isFinite)
                    let center=m.framing!.point(at:m.blend(at:c.time))
                    XCTAssertGreaterThan(hypot(c.pose.eye.x-center.x,c.pose.eye.z-center.z),0.1)
                    if i>0 {
                        let from=previous.eye-previousCenter,to=c.pose.eye-center
                        let radial=abs(hypot(to.x,to.z)-hypot(from.x,from.z))/dt
                        XCTAssertLessThanOrEqual(radial,3.15,"Sampled radial rate near a clipped boundary")
                        XCTAssertLessThanOrEqual(abs(c.pose.eye.y-previous.eye.y)/dt,1.89)
                        XCTAssertLessThanOrEqual(abs(c.pose.pitch-previous.pitch)/dt,.pi/2*1.05)
                    }
                    previous=c.pose;previousCenter=center
                }
                XCTAssertFalse(c.hasPendingMotion)
            }
        }}
    }
    func testSynchronousFocusCancelsNewMotionAndOldFocusRecordingsKeepTiming() throws {
        var modern=try camera(),old=try camera(modern:false)
        XCTAssertTrue(modern.select(.thirdPerson,shot:shot(150),resetThirdPerson:true))
        modern.advance(to:0.2)
        let input=P01CameraMotion.Input(time:0.2,kind:.focus,animated:false,point:.init(0.4,0.828575,0.3))
        modern.apply(input)
        XCTAssertFalse(modern.hasPendingMotion)
        let expected=try XCTUnwrap(P01CameraMotion.evaluate(state:modern.state,shot:modern.shot,layout:layout))
        XCTAssertEqual(modern.pose,expected)
        old.apply(input)
        XCTAssertTrue(old.hasPendingMotion,"Old recorded focus inputs keep their historical animated behavior")
    }
    func testOldRecordingsAndDedicatedBreakTimingRemainUnchanged() throws {
        var old=try camera(modern:false)
        let data=try JSONEncoder().encode(old.snapshot())
        XCTAssertFalse(String(decoding:data,as:UTF8.self).contains("generalTiming"))
        let decoded=try JSONDecoder().decode(P01CameraMotion.Snapshot.self,from:data)
        var replay=try XCTUnwrap(P01CameraMotion(recording:.init(geometryID:"old",initial:decoded,layout:layout,inputs:[])))
        XCTAssertTrue(replay.select(.thirdPerson,shot:shot(150),resetThirdPerson:true))
        XCTAssertEqual(try XCTUnwrap(replay.snapshot().motion).duration,4.6116,accuracy:0.001)
        var modern=try camera()
        old.pan(.init(200,60));modern.pan(.init(200,60))
        old.watchBreak(animated:true,duration:1.5);modern.watchBreak(animated:true,duration:1.5)
        XCTAssertEqual(modern.snapshot().motion?.duration,1.5)
        for i in 0...100 { let t=Double(i)*1.5/100;old.advance(to:t);modern.advance(to:t);XCTAssertEqual(old.pose,modern.pose) }
        modern.pan(.init(200,0));XCTAssertTrue(modern.select(.thirdPerson,animated:false,resetThirdPerson:true))
        XCTAssertFalse(modern.hasPendingMotion)
    }
}
