import XCTest
import SceneKit
import simd
@testable import QiuJi

final class SpatialPracticeTests: XCTestCase {
    @MainActor
    func testSpatialOverlayUpdatesItsOwnContactUniformsWhileDragging() throws {
        let scene=AngleTrainingScene()
        scene.configureReferenceTableRendering();scene.isolatesTemporaryTopDownMaterials=true
        scene.setupScene()
        let renderer=SCNRenderer(device:try XCTUnwrap(MTLCreateSystemDefaultDevice()),options:nil)
        renderer.scene=scene;renderer.pointOfView=scene.cameraNode;renderer.delegate=scene.contactOcclusion
        func renderSource() {
            SCNTransaction.flush()
            _=renderer.snapshot(atTime:CACurrentMediaTime(),with:CGSize(width:64,height:64),antialiasingMode:.none)
        }
        renderSource()
        var copies:[SCNNode:SCNNode]=[:]
        let overlay=scene.makeTemporaryTopDownRenderScene { copies[$0]=$1 }
        var cloth:SCNMaterial?
        scene.tableNode?.enumerateChildNodes { node,_ in
            cloth = cloth ?? node.geometry?.materials.first { $0.name=="TaiNi" }
        }
        let original=try XCTUnwrap(cloth)
        var copiedCloth:SCNMaterial?
        overlay.rootNode.enumerateChildNodes { node,_ in
            copiedCloth = copiedCloth ?? node.geometry?.materials.first { $0.name=="TaiNi" }
        }
        let copied=try XCTUnwrap(copiedCloth)
        XCTAssertFalse(original === copied)
        XCTAssertEqual(original.shaderModifiers,copied.shaderModifiers,
            "Keep the installed lighting recipe; only the dynamic argument is independent")
        let before=try XCTUnwrap(copied.value(forKey:"contactUniforms") as? Data)
        let cue=try XCTUnwrap(scene.cueBallNode)
        SCNTransaction.begin();SCNTransaction.disableActions=true
        cue.position.x += 0.2
        SCNTransaction.commit()
        renderSource()
        XCTAssertEqual(cue.presentation.worldPosition.x,cue.worldPosition.x,accuracy:0.00001,
            "Reconciliation reads the real rendered pose, not an unrendered model edit")
        let originalBytes=try XCTUnwrap(original.value(forKey:"contactUniforms") as? Data)
        scene.synchronizeTemporaryTopDownScene(overlay,copies:&copies)
        let after=try XCTUnwrap(copied.value(forKey:"contactUniforms") as? Data)
        XCTAssertNotEqual(before,after,"Dragging must move the clone's shadow")
        XCTAssertEqual(original.value(forKey:"contactUniforms") as? Data,originalBytes,
            "The overlay must not replace the primary renderer's argument")
    }
    @MainActor
    func testTemporarySpatialRendererOwnsMaterialsAndReconcilesRemovedRoute() throws {
        for isolated in [false,true] {
            let scene=AngleTrainingScene()
            scene.isolatesTemporaryTopDownMaterials=isolated
            let geometry=SCNSphere(radius:0.03),material=SCNMaterial()
            material.lightingModel = .constant;material.diffuse.contents=UIColor.yellow
            geometry.materials=[material]
            let route=SCNNode(geometry:geometry);route.name="spatialPreviewRoute"
            scene.rootNode.addChildNode(route)
            var copies:[SCNNode:SCNNode]=[:]
            let overlay=scene.makeTemporaryTopDownRenderScene { copies[$0]=$1 }
            let copy=try XCTUnwrap(copies[route]),copyGeometry=try XCTUnwrap(copy.geometry)
            XCTAssertFalse(copyGeometry === geometry)
            let copiedMaterial=try XCTUnwrap(copyGeometry.firstMaterial)
            XCTAssertEqual(copiedMaterial === material,!isolated)
            XCTAssertEqual(copiedMaterial.lightingModel,material.lightingModel)
            if isolated {
                material.transparency=0.25
                XCTAssertEqual(copiedMaterial.transparency,1)
            }
            route.removeFromParentNode()
            scene.synchronizeTemporaryTopDownScene(overlay,copies:&copies)
            XCTAssertNil(copy.parent);XCTAssertTrue(copies.isEmpty)
        }
    }
    private func prediction(model:EventDrivenEngine.SimulationModel = .appDefault,elevation:Float=0,side:Float=0)->ShotPrediction {
        ShotPredictor.simulateFree(cueBall:SCNVector3(-0.65,BTTablePhysics.surfaceY+BallPhysics.radius,0),
            aimDir:SCNVector3(1,0,0),velocity:2,spinX:side,spinY:0,surfaceY:BTTablePhysics.surfaceY,
            balls:[],maxTime:25,simulationModel:model,elevation:elevation)
    }
    private func signature(_ prediction:ShotPrediction)->[UInt32] {
        guard let recorder=prediction.recorder else { return [] }
        return recorder.framesByBallName.keys.sorted().flatMap { name in
            recorder.framesByBallName[name]!.flatMap { f in
                [f.time,f.position.x,f.position.y,f.position.z,f.velocity.x,f.velocity.y,f.velocity.z,
                 f.angularVelocity.x,f.angularVelocity.y,f.angularVelocity.z,f.angularVelocity.w].map(\.bitPattern)
            }
        }
    }
    func testLegacyDefaultAndExplicitPlanarRemainBitIdenticalAfterSpatialRequest() {
        XCTAssertEqual(EventDrivenEngine.SimulationModel.appDefault,.planarReference)
        let before=prediction()
        XCTAssertFalse(signature(before).isEmpty)
        let spatial=prediction(model:.spatialPractice,elevation:.pi/4)
        XCTAssertEqual(spatial.termination,.settled)
        XCTAssertEqual(signature(before),signature(prediction()))
        XCTAssertEqual(signature(before),signature(prediction(model:.planarReference,elevation:1)))
    }
    func testLegacyFixtureFamiliesSurviveConcurrentAndCancelledSpatialRequests() {
        let y=BTTablePhysics.surfaceY+BallPhysics.radius
        var fixtures:[(SCNVector3,SCNVector3,Float,Float,Float,[ObstacleBall])]=[]
        for (side,vertical) in [(Float(0),Float(0)),(0,0.4),(0,-0.4),(0.4,0),(-0.4,0)] {
            fixtures.append((SCNVector3(-0.65,y,0),SCNVector3(1,0,0),3,side,vertical,[.init(name:"_1",position:SCNVector3(0,y,0.025))]))
        }
        fixtures.append((SCNVector3(1.1,y,0),SCNVector3(1,0,0),4,0,0,[]))
        fixtures.append((SCNVector3(1.05,y,0.48),SCNVector3(1,0,1).normalized(),4,0,0,[]))
        for game in [RackGame.nineBall,.chineseEightBall] {
            let rack=RackLayout.make(game,seed:66)
            fixtures.append((rack.cue,SCNVector3(-1,0,0),10,0,0,rack.balls.map { .init(name:$0.key,position:$0.position) }))
        }
        func run(_ i:Int)->ShotPrediction {
            let f=fixtures[i]
            return ShotPredictor.simulateFree(cueBall:f.0,aimDir:f.1,velocity:f.2,spinX:f.3,spinY:f.4,
                surfaceY:BTTablePhysics.surfaceY,balls:f.5,maxEvents:8000,maxTime:40)
        }
        func completeSignature(_ p:ShotPrediction)->String {
            let frames=signature(p)
            let states=p.recorder?.framesByBallName.keys.sorted().map { key in
                p.recorder!.framesByBallName[key]!.map { String(describing:$0.state) }.joined(separator:",")
            } ?? []
            let events=p.events.map { "\($0.time.bitPattern):\(String(describing:$0.kind))" }
            return "\(p.duration.bitPattern)|\(String(describing:p.termination))|\(p.pocketedBalls.sorted())|\(frames)|\(states)|\(events)"
        }
        let expected=fixtures.indices.map { completeSignature(run($0)) }
        let lock=NSLock();var actual:[Int:String]=[:]
        DispatchQueue.concurrentPerform(iterations:fixtures.count*2) { index in
            if index.isMultiple(of:2) {
                let i=index/2,value=completeSignature(run(i))
                lock.lock();actual[i]=value;lock.unlock()
            } else {
                let token=PredictionCancellation()
                if index.isMultiple(of:3) { token.cancel() }
                _=ShotPredictor.simulateFree(cueBall:SCNVector3(-0.65,y,0),aimDir:SCNVector3(1,0,0),velocity:4,
                    spinX:0,spinY:0,surfaceY:BTTablePhysics.surfaceY,balls:[],maxEvents:3000,maxTime:40,
                    simulationModel:.spatialPractice,cancellation:token,elevation:50 * .pi/180,buildPolylines:false)
            }
        }
        XCTAssertEqual(actual.count,fixtures.count)
        for i in fixtures.indices {
            XCTAssertEqual(actual[i],expected[i],"Concurrent fixture \(i)")
            XCTAssertEqual(completeSignature(run(i)),expected[i],"After spatial fixture \(i)")
        }
    }
    func testSpatialStrikeLeavesBedAndReturnsWithFiniteCompletedResult() throws {
        let result=prediction(model:.spatialPractice,elevation:.pi/4)
        XCTAssertEqual(result.termination,.settled)
        let recorder=try XCTUnwrap(result.recorder)
        let spans=recorder.localIntervalsByBallName[ShotInput.cueBallName] ?? []
        XCTAssertGreaterThan(spans.map { $0.end.position.y }.max() ?? 0,Double(BTTablePhysics.surfaceY+BallPhysics.radius)+0.005)
        let final=try XCTUnwrap(result.finalPositions[ShotInput.cueBallName])
        XCTAssertTrue(final.x.isFinite && final.y.isFinite && final.z.isFinite)
        XCTAssertTrue(SpatialPracticeGeometry.isOnBed(final))
    }
    func testMirroredMasseHasOppositeCurveAndEqualHeight() throws {
        let a=prediction(model:.spatialPractice,elevation:70 * .pi/180,side:0.5)
        let b=prediction(model:.spatialPractice,elevation:70 * .pi/180,side:-0.5)
        XCTAssertEqual(a.termination,.settled);XCTAssertEqual(b.termination,.settled)
        let pa=try XCTUnwrap(a.finalPositions[ShotInput.cueBallName])
        let pb=try XCTUnwrap(b.finalPositions[ShotInput.cueBallName])
        XCTAssertEqual(pa.x,pb.x,accuracy:0.0002);XCTAssertEqual(pa.z,-pb.z,accuracy:0.0002)
        XCTAssertGreaterThan(abs(pa.z),0.01)
    }
    func testExteriorAndGroundAreRealContactsAndNotPlanarClamp() throws {
        let surfaces=try SpatialPracticeGeometry.exteriorSurfaces()
        XCTAssertGreaterThan(surfaces.count,2)
        let solver=try SpatialPracticeGeometry.solver(asset:PocketGeometryAsset.load(),
            material:.tablePhysics(clothRestitution:0.3),ballMaterial:.ballPhysics)
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:BTTablePhysics.surfaceY))
        engine.setBall(.init(position:SCNVector3(2,0.4,0),velocity:SCNVector3(0,0,0),
            angularVelocity:SCNVector3Zero,state:.sliding,name:"outside"))
        let result=engine.simulatePrediction(model:.spatialPractice,maxTime:8)
        XCTAssertEqual(result,.settled)
        let ball=try XCTUnwrap(engine.getBall("outside"))
        XCTAssertEqual(ball.position.y,BTSceneLayout.groundLevelY+BallPhysics.radius,accuracy:0.00002)
        XCTAssertFalse(SpatialPracticeGeometry.isOnBed(ball.position))
        XCTAssertFalse(engine.getTrajectoryRecorder().localStaticContacts.isEmpty)
        XCTAssertNil(solver.planarSupport(from:.init(time:0,position:SIMD3(Double(ball.position.x),Double(ball.position.y),Double(ball.position.z)),
            velocity:.zero,omega:.zero),surfaceY:Double(BTTablePhysics.surfaceY)))
    }
    func testLandingAcrossClothSeamConvergesWithoutAddingEnergy() throws {
        typealias V=SIMD3<Double>
        let r=Double(BallPhysics.radius)
        let initial=PocketContactResponse.Motion(velocity:V(2.825823995276047,-1.4144279503234098,2.1334377632848204e-7),
            angularVelocity:V(7.4660990601966615e-6,0,-98.89148040075749))
        let constraints:[PocketContactResponse.ImpactConstraint]=[
            .init(normal:V(9.713237507336597e-16,0.999999999999983,1.8435394973509615e-7),restitution:0.3,friction:0.20000000298023224),
            .init(normal:V(0,1,0),restitution:0.3,friction:0.20000000298023224)]
        let solved=try PocketContactResponse.spatialPracticeImpact(initial,constraints:constraints,radius:r)
        let flat=PocketContactResponse.impact(initial,normal:V(0,1,0),radius:r,restitution:0.3,friction:0.20000000298023224)
        XCTAssertEqual(solved.velocity.y,flat.velocity.y,accuracy:1e-6)
        XCTAssertEqual(solved.velocity.x,flat.velocity.x,accuracy:1e-6)
        func energy(_ m:PocketContactResponse.Motion)->Double { simd_length_squared(m.velocity)+0.4*r*r*simd_length_squared(m.angularVelocity) }
        XCTAssertLessThanOrEqual(energy(solved),energy(initial))
    }
    func testDefaultJumpExampleFinishesWithThreeBalls() throws {
        let y=BTTablePhysics.surfaceY+BallPhysics.radius
        let result=ShotPredictor.simulateFree(cueBall:SCNVector3(-0.65,y,0),aimDir:SCNVector3(1,0,0),velocity:4,
            spinX:0,spinY:0,surfaceY:BTTablePhysics.surfaceY,
            balls:[.init(name:"_1",position:SCNVector3(-0.25,y,0)),.init(name:"_2",position:SCNVector3(0.6,y,0))],
            maxEvents:3000,maxTime:40,simulationModel:.spatialPractice,elevation:50 * .pi/180)
        XCTAssertEqual(result.termination,.settled)
        XCTAssertEqual(result.finalPositions.count,3)
        let recorder=try XCTUnwrap(result.recorder)
        let landing=try XCTUnwrap(SpatialPracticeRecord.firstLanding(recorder))
        let spans=recorder.localIntervalsByBallName[ShotInput.cueBallName] ?? []
        let bounce=try XCTUnwrap(spans.first { span in
            span.start.time>0.01 && span.end.velocity.y>0.05 &&
            abs(span.end.position.y-Double(y))<0.00001 &&
            (span.sample(at:span.end.time,beforeEndpoint:true)?.velocity.y ?? 0)<(-0.05)
        })
        XCTAssertEqual(Double(landing.x),bounce.end.position.x,accuracy:0.00001)
        XCTAssertEqual(Double(landing.z),bounce.end.position.z,accuracy:0.00001)
    }
    func testHighBallClearsObjectAndLowBallContactsIt() throws {
        func contacts(height:Float)->Bool {
            let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:BTTablePhysics.surfaceY))
            engine.setBall(.init(position:SCNVector3(-0.3,height,0),velocity:SCNVector3(3,0,0),
                angularVelocity:SCNVector3Zero,state:.sliding,name:"cue"))
            engine.setBall(.init(position:SCNVector3(0,BTTablePhysics.surfaceY+BallPhysics.radius,0),velocity:SCNVector3Zero,
                angularVelocity:SCNVector3Zero,state:.stationary,name:"object"))
            let result=engine.simulatePrediction(model:.spatialPractice,maxTime:0.18)
            XCTAssertTrue(result == .timeLimit || result == .settled,"\(result)")
            return engine.firstBallBallCollisionTime != nil
        }
        XCTAssertFalse(contacts(height:1.05))
        XCTAssertTrue(contacts(height:BTTablePhysics.surfaceY+BallPhysics.radius+0.01))
    }
    @MainActor
    func testPaletteCapacityOverlapAndInterruptedCalculationRestoreStableDraft() async throws {
        let suite="v66-edit-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let vm=SpatialPracticeViewModel(defaults:defaults);vm.setupScene();vm.clear()
        for key in PositionPlayBall.allKeys { vm.placeFromPalette(key) }
        XCTAssertEqual(vm.onTableKeys.count,16)
        let cue=try XCTUnwrap(vm.record.board[PositionPlayBall.cueKey])
        XCTAssertNil(vm.palettePlacement("_1",atWorld:cue.position.scene))
        vm.loadExample(0)
        let before=vm.record.board.mapValues(\.position)
        vm.strike();vm.suspendTeachingActivity()
        try await Task.sleep(for:.milliseconds(500))
        XCTAssertEqual(vm.phase,.ready)
        XCTAssertEqual(vm.record.board.mapValues(\.position),before)
        XCTAssertNil(vm.record.lastShot)
        let restored=SpatialPracticeViewModel(defaults:defaults);restored.setupScene()
        XCTAssertEqual(restored.record.board.mapValues(\.position),before)
        restored.suspendTeachingActivity()
    }
    func testDomainExitFindsCrossingBeforeTheLastAcceptedInterval() throws {
        typealias S=LocalPocketSimulation.State
        for axis in [0,2] { for sign in [-1.0,1.0] {
            let edge=axis==0 ? 3.0:2.0
            var position=SIMD3<Double>(0,0.4,0),velocity=SIMD3<Double>.zero
            position[axis]=sign*(edge-0.01);velocity[axis]=sign*4
            let start=S(time:0,position:position,velocity:velocity,omega:.zero)
            let middle=S(time:0.005,position:position+velocity*0.005,velocity:velocity,omega:.zero)
            let end=S(time:0.01,position:position+velocity*0.01,velocity:velocity,omega:.zero)
            let spans=[LocalPocketSimulation.Interval(start:start,duration:0.005,acceleration:.zero,angularAcceleration:.zero,end:middle),
                .init(start:middle,duration:0.005,acceleration:.zero,angularAcceleration:.zero,end:end)]
            let exit=SpatialPracticeGeometry.exitState(spans,fallback:end)
            XCTAssertTrue(SpatialPracticeGeometry.contains(exit.position))
            XCTAssertEqual(exit.position[axis],sign*edge,accuracy:1e-12)
            XCTAssertEqual(exit.time,0.0025,accuracy:1e-12)
            XCTAssertEqual(exit.velocity,velocity)
        } }
    }
    func testDomainExitIsDistinctFromPocketAndOtherBallsFinish() throws {
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:BTTablePhysics.surfaceY))
        engine.setBall(.init(position:SCNVector3(2.99,0.4,0),velocity:SCNVector3(4,0,0),
            angularVelocity:SCNVector3Zero,state:.sliding,name:"escaped"))
        engine.setBall(.init(position:SCNVector3(0,BTTablePhysics.surfaceY+BallPhysics.radius,0),velocity:SCNVector3(0.1,0,0),
            angularVelocity:SCNVector3Zero,state:.sliding,name:"remaining"))
        XCTAssertEqual(engine.simulatePrediction(model:.spatialPractice,maxTime:8),.settled)
        let recorder=engine.getTrajectoryRecorder()
        let exit=try XCTUnwrap(recorder.spatialDomainExits["escaped"])
        XCTAssertEqual(exit.position.x,3,accuracy:1e-6)
        XCTAssertFalse(recorder.isBallPocketed("escaped"))
        XCTAssertEqual(engine.getBall("remaining")?.state,.stationary)
        XCTAssertGreaterThan(recorder.duration,Float(exit.time))
    }
    func testLandingSoundsUseAcceptedContactTimes() throws {
        let result=prediction(model:.spatialPractice,elevation:.pi/4)
        let recorder=try XCTUnwrap(result.recorder)
        let sounds=SpatialPracticeRecord.spatialSounds(recorder)
        XCTAssertFalse(sounds.isEmpty)
        XCTAssertTrue(sounds.allSatisfy { sound in recorder.localStaticContacts.contains { abs(Float($0.contact.time)-sound.time)<1e-6 } })
    }
    func testBudgetAndCancellationNeverPublishSettledShot() {
        let token=PredictionCancellation();token.cancel()
        let result=ShotPredictor.simulateFree(cueBall:SCNVector3Zero,aimDir:SCNVector3(1,0,0),velocity:3,spinX:0,spinY:0,
            surfaceY:BTTablePhysics.surfaceY,balls:[],simulationModel:.spatialPractice,cancellation:token,elevation:1)
        XCTAssertEqual(result.termination,.cancelled);XCTAssertFalse(result.hasFinalTableState)
        let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:BTTablePhysics.surfaceY))
        engine.setBall(.init(position:SCNVector3(0,1,0),velocity:SCNVector3(1,1,0),angularVelocity:SCNVector3Zero,state:.sliding,name:"cue"))
        XCTAssertEqual(engine.simulatePrediction(model:.spatialPractice,maxTime:0.001),.timeLimit)
    }
    @MainActor
    func testPageArchiveAndPreferencesAreSeparateFromLegacyPages() throws {
        let suite="v66-tests-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let store=TablePreferencesStore(defaults:defaults)
        let previous=store.snapshot(for:.shotSimulation)
        store.apply(.view3D,value:1,to:.masseJump)
        store.apply(.transparency,value:0.9,to:.masseJump)
        XCTAssertEqual(store.snapshot(for:.shotSimulation),previous)
        let vm=SpatialPracticeViewModel(defaults:defaults);vm.setupScene()
        vm.updateInput { $0.elevation=72;$0.speed=2.5;$0.spinX=0.35 }
        vm.clear()
        let restored=SpatialPracticeViewModel(defaults:defaults);restored.setupScene()
        XCTAssertEqual(restored.input.elevation,72);XCTAssertEqual(restored.input.speed,2.5)
        XCTAssertTrue(restored.onTableKeys.isEmpty)
        vm.suspendTeachingActivity();restored.suspendTeachingActivity()
    }
    @MainActor
    func testOwnerSwitchAndCorruptArchiveKeepIndependentRecoverableBoards() throws {
        let suite="v66-owner-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let owner=CurrentOwnerContext(defaults:defaults)
        owner.useAccount(userID:"A")
        let vm=SpatialPracticeViewModel(defaults:defaults,ownerContext:owner);vm.setupScene()
        vm.clear();vm.updateInput { $0.elevation=52 }
        owner.useAccount(userID:"B");vm.ownerChanged()
        XCTAssertEqual(vm.onTableKeys.count,3);XCTAssertEqual(vm.input.elevation,45)
        owner.useAccount(userID:"A");vm.ownerChanged()
        XCTAssertTrue(vm.onTableKeys.isEmpty);XCTAssertEqual(vm.input.elevation,52)
        vm.suspendTeachingActivity()
        let key="spatialPractice.v2."+owner.ownerKey,bad=Data("broken".utf8)
        defaults.set(bad,forKey:key)
        let restored=SpatialPracticeViewModel(defaults:defaults,ownerContext:owner);restored.setupScene()
        XCTAssertEqual(defaults.data(forKey:key+".unreadable"),bad)
        XCTAssertEqual(restored.onTableKeys.count,3)
        XCTAssertNotNil(restored.archiveMessage)
        restored.suspendTeachingActivity()
    }
    @MainActor
    func testLegacyOutsideBallMigratesBackToPaletteWithoutChangingContactGeometry() throws {
        let suite="v66-clearance-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let owner=CurrentOwnerContext(defaults:defaults)
        let cue=SCNVector3(-1.2,BTTablePhysics.surfaceY+BallPhysics.radius,0)
        let outside=SCNVector3(-1.32,0.88,0)
        let input=SpatialPracticeRecord.Input(yaw:0,speed:2,spinX:0,spinY:0,elevation:20)
        let board=[PositionPlayBall.cueKey:SpatialPracticeRecord.Pose(position:.init(cue),rotation:[0,0,0,1],disposition:"bed"),
            "_1":SpatialPracticeRecord.Pose(position:.init(outside),rotation:[0,0,0,1],disposition:"outside")]
        var legacy=SpatialPracticeRecord(board:board,input:input);legacy.version=1
        let bytes=try PropertyListEncoder().encode(legacy),key="spatialPractice.v1."+owner.ownerKey
        defaults.set(bytes,forKey:key)
        let vm=SpatialPracticeViewModel(defaults:defaults,ownerContext:owner);vm.setupScene()
        XCTAssertTrue(CueStick.clearsAtElevation(strike:cue,aim:input.aim,obstacles:[],surfaceY:BTTablePhysics.surfaceY,elevation:input.radians))
        XCTAssertNil(vm.record.board["_1"],"The old outside ball must return to the palette")
        XCTAssertEqual(defaults.data(forKey:key),bytes)
        XCTAssertEqual(defaults.data(forKey:key+".preserved"),bytes)
        XCTAssertTrue(vm.cueAccessible)
        XCTAssertFalse(CueStick.clearsAtElevation(strike:cue,aim:input.aim,obstacles:[outside],surfaceY:BTTablePhysics.surfaceY,elevation:input.radians),"The physical obstacle rule itself remains unchanged")
        vm.updateInput { $0.elevation=70 }
        XCTAssertTrue(vm.cueAccessible)
        vm.suspendTeachingActivity()
    }
    func testFrozenShotRoundTripPreservesThreeDimensionalSamples() throws {
        let result=prediction(model:.spatialPractice,elevation:.pi/4)
        let before=[PositionPlayBall.cueKey:SpatialPracticeRecord.Pose(position:.init(SCNVector3(-0.65,BTTablePhysics.surfaceY+BallPhysics.radius,0)),rotation:[0,0,0,1],disposition:"bed")]
        let frozen=try XCTUnwrap(SpatialPracticeRecord.freeze(prediction:result,input:.init(),before:before))
        let encoder=PropertyListEncoder();encoder.outputFormat = .binary
        let data=try encoder.encode(frozen)
        let decoded=try PropertyListDecoder().decode(SpatialPracticeRecord.Shot.self,from:data)
        XCTAssertEqual(decoded.id,frozen.id)
        XCTAssertGreaterThan(decoded.maximumHeight,0.005)
        XCTAssertNotNil(decoded.landing)
        XCTAssertEqual(decoded.paths[PositionPlayBall.cueKey]?.map(\.position),frozen.paths[PositionPlayBall.cueKey]?.map(\.position))
    }
}


final class SpatialPracticeContinuityTests:XCTestCase {
    func testIndexedIntervalsPreserveInsertionOrderAndMutation() {
        typealias S=LocalPocketSimulation.State
        func span(_ start:Double,_ end:Double,_ marker:Double)->LocalPocketSimulation.Interval {
            .init(start:S(time:start,position:.init(marker,0,0),velocity:.zero,omega:.zero),duration:end-start,
                acceleration:.zero,angularAcceleration:.zero,
                end:S(time:end,position:.init(marker,0,0),velocity:.zero,omega:.zero))
        }
        let cases:[[(Double,Double)]]=[[(0,1),(1,2),(1,2),(3,4)],[(0,5),(1,2)],[(2,4),(0,1)],[(0,1),(.nan,2)]]
        for ranges in cases {
            let recorder=TrajectoryRecorder()
            recorder.recordLocalIntervals(ballName:"a",intervals:ranges.enumerated().map {span($0.element.0,$0.element.1,Double($0.offset))})
            func compare() {
                let spans=recorder.localIntervalsByBallName["a"]!
                for i in -10...100 {
                    let t=Double(i)/10
                    for incoming in [false,true] {
                        let expected=incoming ? spans.first(where:{$0.start.time<t && $0.end.time>=t}) : spans.last(where:{$0.start.time<=t && $0.end.time>=t})
                        let actual=recorder.localInterval(ballName:"a",time:t,incoming:incoming)
                        XCTAssertEqual(actual?.start.position,expected?.start.position)
                        XCTAssertEqual(actual?.end.position,expected?.end.position)
                    }
                }
            }
            compare();recorder.prepareLocalIntervalIndex();compare()
            recorder.recordLocalIntervals(ballName:"a",intervals:[span(0.5,8,99)])
            compare();recorder.prepareLocalIntervalIndex();compare()
        }
    }

    func testTimingProbeRejectsInFlightAndSupersededFrames() throws {
        let probe=TableInteractionTimingProbe(),old=UUID(),latest=UUID()
        probe.beginPreview(id:old,start:TableInteractionTimingProbe.now,balls:3)
        probe.willRender()
        probe.routesReady(id:old)
        probe.didRender(cue:nil)
        XCTAssertEqual(probe.json,"[]","A frame begun before route installation cannot acknowledge it")
        probe.willRender()
        probe.beginPreview(id:latest,start:TableInteractionTimingProbe.now,balls:16)
        probe.mark("obsolete",id:old);probe.routesReady(id:latest)
        probe.didRender(cue:nil)
        XCTAssertEqual(probe.json,"[]","A superseded frame cannot acknowledge the latest request")
        probe.willRender();probe.didRender(cue:nil);probe.didRender(cue:nil)
        let rows=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(probe.json.utf8)) as? [[String:Double]])
        XCTAssertEqual(rows.count,1);XCTAssertEqual(rows.first?["balls"],16)
        XCTAssertNil(rows.first?["obsolete"])
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(rows.first?["rendered"]),try XCTUnwrap(rows.first?["start"]))
    }
    func testRealIndexedQueriesMatchLinearIntervals() throws {
        for (angle,side) in [(0.0,0.0),(50,0),(70,0.55),(70,-0.55)] {
            let recorder=try XCTUnwrap(solve(elevation:angle,side:side).recorder)
            recorder.prepareLocalIntervalIndex()
            for (name,spans) in recorder.localIntervalsByBallName {
                let times=spans.flatMap {[$0.start.time,$0.end.time,($0.start.time+$0.end.time)/2]}
                for t in times {
                    for incoming in [false,true] {
                        let reference=incoming ? spans.first(where:{$0.start.time<t && $0.end.time>=t}) : spans.last(where:{$0.start.time<=t && $0.end.time>=t})
                        let actual=recorder.localInterval(ballName:name,time:t,incoming:incoming)
                        XCTAssertEqual(actual?.sample(at:t,beforeEndpoint:incoming)?.position,reference?.sample(at:t,beforeEndpoint:incoming)?.position)
                        XCTAssertEqual(actual?.sample(at:t,beforeEndpoint:incoming)?.velocity,reference?.sample(at:t,beforeEndpoint:incoming)?.velocity)
                        XCTAssertEqual(actual?.sample(at:t,beforeEndpoint:incoming)?.omega,reference?.sample(at:t,beforeEndpoint:incoming)?.omega)
                    }
                }
            }
        }
    }
    func testFreezeKeepsDomainExitAsExactVisibilityBoundary() throws {
        typealias R=SpatialPracticeRecord
        let cue=SCNVector3(1,BTTablePhysics.surfaceY+BallPhysics.radius,0)
        let input=R.Input(speed:8,elevation:45)
        let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:input.aim,velocity:8,spinX:0,spinY:0,
            surfaceY:BTTablePhysics.surfaceY,balls:[],maxEvents:3000,maxTime:40,simulationModel:.spatialPractice,
            elevation:input.radians,buildPolylines:false)
        let recorder=try XCTUnwrap(p.recorder),exit=try XCTUnwrap(recorder.spatialDomainExits[ShotInput.cueBallName])
        let before=[PositionPlayBall.cueKey:R.Pose(position:.init(cue),rotation:[0,0,0,1],disposition:"bed")]
        let shot=try XCTUnwrap(R.freeze(prediction:p,input:input,before:before))
        let path=try XCTUnwrap(shot.paths[PositionPlayBall.cueKey])
        let firstHidden=try XCTUnwrap(path.first(where:{$0.hidden}))
        XCTAssertEqual(firstHidden.time,Float(exit.time))
        XCTAssertEqual(firstHidden.position.x,Float(exit.position.x))
        XCTAssertEqual(firstHidden.position.y,Float(exit.position.y))
        XCTAssertTrue(path.filter {$0.time<Float(exit.time)}.allSatisfy {!$0.hidden})
        XCTAssertTrue(R.validShot(shot))
    }
    private let y=BTTablePhysics.surfaceY+BallPhysics.radius
    private func solve(elevation:Double,side:Double=0,speed:Double=4,polylines:Bool=false)->ShotPrediction {
        ShotPredictor.simulateFree(cueBall:SCNVector3(-0.65,y,0),aimDir:SCNVector3(1,0,0),velocity:Float(speed),
            spinX:Float(side),spinY:0,surfaceY:BTTablePhysics.surfaceY,
            balls:[.init(name:"_1",position:SCNVector3(-0.25,y,0)),.init(name:"_2",position:SCNVector3(0.6,y,0))],
            maxEvents:3000,maxTime:40,simulationModel:.spatialPractice,elevation:Float(elevation * .pi/180),buildPolylines:polylines)
    }
    private var board:[String:SpatialPracticeRecord.Pose] {
        Dictionary(uniqueKeysWithValues:[(PositionPlayBall.cueKey,Float(-0.65)),("_1",Float(-0.25)),("_2",Float(0.6))].map {
            ($0.0,.init(position:.init(SCNVector3($0.1,y,0)),rotation:[0,0,0,1],disposition:"bed"))
        })
    }

    func testHandoffPublishesRollingMotionAndFrozenPathsStayContinuous() throws {
        for (elevation,side,speed) in [(50.0,0.0,4.0),(70,0.55,2),(70,-0.55,2),(75,0,4)] {
            let p=solve(elevation:elevation,side:side,speed:speed)
            XCTAssertEqual(p.termination,.settled)
            let recorder=try XCTUnwrap(p.recorder), playback=TrajectoryPlayback(recorder:recorder,surfaceY:y)
            var checked=0
            for handoff in recorder.localHandoffs where handoff.kind == .returned {
                let s=handoff.state
                func v(_ p:SIMD3<Double>)->SCNVector3 { SCNVector3(Float(p.x),Float(p.y),Float(p.z)) }
                let ball=BallState(position:v(s.position),velocity:v(s.velocity),angularVelocity:v(s.omega),state:.sliding,name:handoff.ballName)
                guard EngineNumerics.determineMotionState(ball) == .rolling,
                      let next=recorder.framesByBallName[handoff.ballName]?.first(where:{$0.time>Float(s.time)+1e-6}) else { continue }
                let dt=(next.time-Float(s.time))*0.5
                guard dt>1e-5 else { continue }
                let actual=try XCTUnwrap(playback.stateAt(ballName:handoff.ballName,time:Float(s.time)+dt))
                let expected=AnalyticalMotion.evolveRolling(position:ball.position,velocity:ball.velocity,angularVelocity:ball.angularVelocity,dt:dt)
                XCTAssertLessThan((actual.position-expected.position).length(),0.0001,"handoff \(s.time)")
                checked+=1
            }
            XCTAssertGreaterThan(checked,0)
            let input=SpatialPracticeRecord.Input(yaw:0,speed:speed,spinX:side,spinY:0,elevation:elevation)
            let shot=try XCTUnwrap(SpatialPracticeRecord.freeze(prediction:p,input:input,before:board))
            var worst:Float=0
            for (key,path) in shot.paths {
                let name=PositionPlayBall.isCue(key) ? ShotInput.cueBallName:key
                for i in 1..<path.count where !path[i-1].hidden && !path[i].hidden {
                    let a=path[i-1],b=path[i],t=(a.time+b.time)*0.5
                    let exact=try XCTUnwrap(playback.stateAt(ballName:name,time:t))
                    worst=max(worst,((a.position.scene+b.position.scene)*0.5-exact.position).length())
                }
            }
            XCTAssertLessThanOrEqual(worst,0.0001,"\(elevation)° side \(side), max error \(worst)m")
            print("V66_CONTINUITY elevation=\(elevation) side=\(side) handoffs=\(checked) worstM=\(worst)")
        }
    }

    func testAirborneIntervalsMatchIndependentGravityAndContactsStayContinuous() throws {
        let p=solve(elevation:50),recorder=try XCTUnwrap(p.recorder)
        var airborne=0
        for interval in recorder.localIntervalsByBallName.values.flatMap({$0}) {
            let dt=(interval.end.time-interval.start.time)*0.5
            guard dt>0 else { continue }
            let mid=try XCTUnwrap(interval.sample(at:interval.start.time+dt,beforeEndpoint:true))
            if interval.start.position.y>Double(y)+0.001,
               simd_length(interval.acceleration-SIMD3(0,-Double(TablePhysics.gravity),0))<1e-9 {
                let expected=interval.start.position+interval.start.velocity*dt+SIMD3(0,-0.5*Double(TablePhysics.gravity)*dt*dt,0)
                XCTAssertLessThan(simd_length(mid.position-expected),0.0001)
                airborne+=1
            }
            let incoming=try XCTUnwrap(interval.sample(at:interval.end.time,beforeEndpoint:true))
            XCTAssertLessThan(simd_length(incoming.position-interval.end.position),0.0001)
        }
        XCTAssertGreaterThan(airborne,10)
    }

    func testNearRailSeamUsesSpatialResolutionAndCompletesWithoutEnergyGain() throws {
        typealias V=SIMD3<Double>
        let radius=Double(BallPhysics.radius)
        let normals=[V(0,1,0),V(0,0.9999999999980623,-1.9686039990755764e-6)]
        XCTAssertLessThan(radius*simd_length(normals[0]-normals[1]),SpatialPracticeGeometry.contactTolerance)
        let initial=PocketContactResponse.Motion(velocity:V(3.956153392791748,-4.71475935757421,2.9868127171539527e-7),
            angularVelocity:V(1.3249763699402228e-12,0,-1.754984441504348e-5))
        let resolved=try PocketContactResponse.spatialPracticeImpact(initial,
            constraints:normals.map { .init(normal:$0,restitution:0.3,friction:Double(SpinPhysics.slidingFriction)) },radius:radius,
            normalMergeTolerance:SpatialPracticeGeometry.impactNormalMergeTolerance)
        func energy(_ m:PocketContactResponse.Motion)->Double { simd_length_squared(m.velocity)+0.4*radius*radius*simd_length_squared(m.angularVelocity) }
        XCTAssertLessThanOrEqual(energy(resolved),energy(initial))
        let p=ShotPredictor.simulateFree(cueBall:SCNVector3(1.1,y,0),aimDir:SCNVector3(1,0,0),velocity:4,spinX:0,spinY:0,
            surfaceY:BTTablePhysics.surfaceY,balls:[],maxEvents:8000,maxTime:40,simulationModel:.spatialPractice,elevation:50 * .pi/180,buildPolylines:false)
        XCTAssertEqual(p.termination,.settled)
        XCTAssertTrue(p.hasFinalTableState)
    }

    func testOmittingLegacyLinesPreservesCompletedPhysicalResult() throws {
        let full=solve(elevation:50,polylines:true),recordOnly=solve(elevation:50)
        XCTAssertFalse(full.cuePath.isEmpty);XCTAssertTrue(recordOnly.cuePath.isEmpty)
        XCTAssertEqual(full.duration,recordOnly.duration);XCTAssertEqual(full.termination,recordOnly.termination)
        XCTAssertEqual(full.pocketedBalls.sorted(),recordOnly.pocketedBalls.sorted())
        XCTAssertEqual(full.events.map(\.time),recordOnly.events.map(\.time))
        let a=try XCTUnwrap(full.recorder),b=try XCTUnwrap(recordOnly.recorder)
        XCTAssertEqual(a.framesByBallName.keys.sorted(),b.framesByBallName.keys.sorted())
        for key in a.framesByBallName.keys {
            let af=a.framesByBallName[key]!,bf=b.framesByBallName[key]!
            XCTAssertEqual(af.count,bf.count)
            for (x,y) in zip(af,bf) {
                XCTAssertEqual(x.time.bitPattern,y.time.bitPattern)
                XCTAssertEqual(x.position.x.bitPattern,y.position.x.bitPattern)
                XCTAssertEqual(x.position.y.bitPattern,y.position.y.bitPattern)
                XCTAssertEqual(x.position.z.bitPattern,y.position.z.bitPattern)
                XCTAssertEqual(x.state,y.state)
            }
        }
        let token=PredictionCancellation();token.cancel()
        XCTAssertNil(SpatialPracticeRecord.freeze(prediction:recordOnly,input:.init(),before:board,cancellation:token))
    }

    func testFrozenStaticBallStoresEndpointsAndPreservesPose() throws {
        var before=board
        before["_3"] = .init(position:.init(SCNVector3(0,y,0.4)),rotation:[0,0,0,1],disposition:"bed")
        let p=ShotPredictor.simulateFree(cueBall:before[PositionPlayBall.cueKey]!.position.scene,aimDir:SCNVector3(1,0,0),velocity:1,
            spinX:0,spinY:0,surfaceY:BTTablePhysics.surfaceY,
            balls:before.filter { !PositionPlayBall.isCue($0.key) }.map { .init(name:$0.key,position:$0.value.position.scene) },
            maxEvents:3000,maxTime:40,simulationModel:.spatialPractice,elevation:0,buildPolylines:false)
        let shot=try XCTUnwrap(SpatialPracticeRecord.freeze(prediction:p,input:.init(),before:before))
        let path=try XCTUnwrap(shot.paths["_3"])
        XCTAssertEqual(path.count,2)
        XCTAssertEqual(path.first?.time,0);XCTAssertEqual(path.last?.time,shot.duration)
        XCTAssertTrue(path.allSatisfy { $0.position==before["_3"]!.position && $0.rotation==[0,0,0,1] && !$0.hidden })
    }

    func testRecordOnlyWarmLatency() throws {
        typealias R=SpatialPracticeRecord
        let rack=RackLayout.make(.chineseEightBall,seed:66)
        var report:[[String:Any]]=[]
        for label in ["jump","masseLeft","planar","rack16"] {
            let isRack=label == "rack16"
            let input=R.Input(yaw:isRack ? .pi:0,speed:isRack ? 10:(label == "jump" ? 4:2),
                spinX:label == "masseLeft" ? 0.55:0,spinY:0,elevation:label == "jump" ? 50:(label == "masseLeft" ? 70:0))
            var before=board
            if isRack {
                before=Dictionary(uniqueKeysWithValues:rack.balls.map { ($0.key,R.Pose(position:.init($0.position),rotation:[0,0,0,1],disposition:"bed")) })
                before[PositionPlayBall.cueKey] = .init(position:.init(rack.cue),rotation:[0,0,0,1],disposition:"bed")
            }
            for run in 0..<21 {
                let start=ProcessInfo.processInfo.systemUptime
                let p=ShotPredictor.simulateFree(cueBall:before[PositionPlayBall.cueKey]!.position.scene,
                    aimDir:isRack ? SCNVector3(-1,0,0):input.aim,velocity:Float(input.speed),spinX:Float(input.spinX),spinY:0,
                    surfaceY:BTTablePhysics.surfaceY,
                    balls:before.keys.sorted().filter { !PositionPlayBall.isCue($0) }.map { .init(name:$0,position:before[$0]!.position.scene) },
                    maxEvents:8000,maxTime:40,simulationModel:.spatialPractice,elevation:input.radians,buildPolylines:false)
                let solved=ProcessInfo.processInfo.systemUptime
                XCTAssertEqual(p.termination,.settled)
                let shot=try XCTUnwrap(R.freeze(prediction:p,input:input,before:before))
                let frozen=ProcessInfo.processInfo.systemUptime
                let encoder=PropertyListEncoder();encoder.outputFormat = .binary
                let data=try encoder.encode(R(board:shot.after,input:input,lastShot:shot))
                let encoded=ProcessInfo.processInfo.systemUptime
                report.append(["case":label,"run":run,"termination":String(describing:p.termination),
                    "solveMS":(solved-start)*1000,"freezeMS":(frozen-solved)*1000,"encodeMS":(encoded-frozen)*1000,
                    "samples":shot.paths.values.reduce(0) { $0+$1.count },"bytes":data.count])
            }
        }
        let attachment=XCTAttachment(data:try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),uniformTypeIdentifier:"public.json")
        attachment.name="v66-r1-record-only-cost";attachment.lifetime = .keepAlways;add(attachment)
    }
}

/// R0 diagnostics: measurements are evidence, not performance assertions.
final class SpatialPracticeBaselineTests: XCTestCase {
    /// Freeze difficult input fixtures before any production repair. Failed physical
    /// solves remain diagnostic outcomes; they must not be published as completed shots.
    func testBoundaryAndRackBaseline() throws {
        let y=BTTablePhysics.surfaceY+BallPhysics.radius
        let rack=RackLayout.make(.chineseEightBall,seed:66)
        let cases:[(String,SCNVector3,SCNVector3,Float,Float,Float,[ObstacleBall])]=[
            ("microJump",SCNVector3(-0.65,y,0),SCNVector3(1,0,0),2,5,0,[]),
            ("nearRail",SCNVector3(1.1,y,0),SCNVector3(1,0,0),4,50,0,[]),
            ("pocketCorner",SCNVector3(1.05,y,0.48),SCNVector3(1,0,1).normalized(),4,50,0,[]),
            ("externalGround",SCNVector3(2,0.4,0),SCNVector3(1,0,0),0.1,0,0,[]),
            ("domainExit",SCNVector3(2.95,1.2,0),SCNVector3(1,0,0),4,0,0,[]),
            ("rack16",rack.cue,SCNVector3(-1,0,0),10,0,0,rack.balls.map { .init(name:$0.key,position:$0.position) })]
        var rows:[[String:Any]]=[]
        for (label,cue,aim,speed,degrees,side,balls) in cases {
            for run in 0..<3 {
                let start=ProcessInfo.processInfo.systemUptime
                let prediction:ShotPrediction
                if label == "externalGround" || label == "domainExit" {
                    // ShotPredictor intentionally starts the cue on the bed. These are
                    // post-launch engine states, so do not pass height through that API.
                    let engine=EventDrivenEngine(tableGeometry:.chineseEightBallQiuJi(surfaceY:BTTablePhysics.surfaceY))
                    engine.setBall(.init(position:cue,velocity:aim*speed,angularVelocity:SCNVector3Zero,
                        state:.sliding,name:ShotInput.cueBallName))
                    var result=ShotPrediction()
                    result.termination=engine.simulatePrediction(model:.spatialPractice,maxTime:40)
                    result.recorder=engine.getTrajectoryRecorder();result.duration=result.recorder!.duration
                    result.finalPositions=Dictionary(uniqueKeysWithValues:engine.getAllBalls().map { ($0.name,$0.position) })
                    prediction=result
                } else {
                    prediction=ShotPredictor.simulateFree(cueBall:cue,aimDir:aim,velocity:speed,
                        spinX:side,spinY:0,surfaceY:BTTablePhysics.surfaceY,balls:balls,
                        maxEvents:8000,maxTime:40,simulationModel:.spatialPractice,elevation:degrees * .pi/180)
                }
                let elapsed=(ProcessInfo.processInfo.systemUptime-start)*1000
                let recorder=try XCTUnwrap(prediction.recorder)
                let intervals=recorder.localIntervalsByBallName.values.flatMap { $0 }
                var maxEndpointCorrection=0.0
                for interval in intervals {
                    if let incoming=interval.sample(at:interval.end.time,beforeEndpoint:true) {
                        maxEndpointCorrection=max(maxEndpointCorrection,simd_length(incoming.position-interval.end.position))
                    }
                }
                rows.append(["case":label,"run":run,"solveMS":elapsed,
                    "termination":String(describing:prediction.termination),"duration":prediction.duration,
                    "intervals":intervals.count,"endpointCorrectionM":maxEndpointCorrection,
                    "exits":recorder.spatialDomainExits.keys.sorted(),"pocketed":prediction.pocketedBalls.sorted(),
                    "final":prediction.finalPositions.mapValues { [Double($0.x),Double($0.y),Double($0.z)] }])
                print("V66_BOUNDARY \(label) \(run) solve=\(elapsed) termination=\(prediction.termination)")
            }
        }
        let attachment=XCTAttachment(data:try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]),uniformTypeIdentifier:"public.json")
        attachment.name="v66-r0-boundary-rack";attachment.lifetime = .keepAlways;add(attachment)
        XCTAssertEqual(rows.count,18)
    }

    func testMeasureSolveFreezeEncodingAndPlaybackContinuity() throws {
        typealias R = SpatialPracticeRecord
        let y = BTTablePhysics.surfaceY + BallPhysics.radius
        var report: [[String: Any]] = []
        let cases: [(String, Double, Double, Double)] = [
            ("jump", 50, 0, 4), ("masseLeft", 70, 0.55, 2),
            ("masseRight", 70, -0.55, 2), ("highJump", 75, 0, 4),
            ("planar", 0, 0, 2)]
        for (label, elevation, side, speed) in cases {
            for run in 0..<3 {
                let input = R.Input(yaw: 0, speed: speed, spinX: side, spinY: 0, elevation: elevation)
                var board: [String: R.Pose] = [:]
                for (key, x) in [(PositionPlayBall.cueKey, Float(-0.65)), ("_1", Float(-0.25)), ("_2", Float(0.6))] {
                    board[key] = .init(position: .init(SCNVector3(x,y,0)), rotation: [0,0,0,1], disposition: "bed")
                }
                let started = ProcessInfo.processInfo.systemUptime
                let p = ShotPredictor.simulateFree(cueBall: board[PositionPlayBall.cueKey]!.position.scene,
                    aimDir: input.aim, velocity: Float(speed), spinX: Float(side), spinY: 0,
                    surfaceY: BTTablePhysics.surfaceY,
                    balls: [ObstacleBall(name:"_1",position:SCNVector3(-0.25,y,0)), ObstacleBall(name:"_2",position:SCNVector3(0.6,y,0))],
                    maxEvents: 3000, maxTime: 40, simulationModel: .spatialPractice, elevation: input.radians)
                let solved = ProcessInfo.processInfo.systemUptime
                var row: [String: Any] = ["case": label, "run": run, "solveMS": (solved-started)*1000,
                    "termination": String(describing:p.termination), "duration":p.duration]
                if let shot = R.freeze(prediction:p,input:input,before:board), let recorder=p.recorder {
                    let frozen=ProcessInfo.processInfo.systemUptime
                    let record=R(board:shot.after,input:input,lastShot:shot)
                    let encoder=PropertyListEncoder();encoder.outputFormat = .binary
                    let bytes=try encoder.encode(record)
                    let encoded=ProcessInfo.processInfo.systemUptime
                    row["freezeMS"]=(frozen-solved)*1000;row["encodeMS"]=(encoded-frozen)*1000
                    row["bytes"]=bytes.count;row["samples"]=shot.paths.values.reduce(0) { $0+$1.count }
                    row["intervals"]=recorder.localIntervalsByBallName.values.reduce(0) { $0+$1.count }
                    let playback=TrajectoryPlayback(recorder:recorder,surfaceY:y)
                    var worst: Float=0;var worstTime:Float=0;var worstKey=""
                    var continuity: [[String:Any]]=[]
                    for (key,path) in shot.paths {
                        let name=PositionPlayBall.isCue(key) ? ShotInput.cueBallName : key
                        for i in 1..<path.count where !path[i-1].hidden && !path[i].hidden {
                            let a=path[i-1],b=path[i],t=(a.time+b.time)/2
                            guard let exact=playback.stateAt(ballName:name,time:t) else { continue }
                            let linear=(a.position.scene+b.position.scene)*0.5
                            let error=(linear-exact.position).length()
                            if error>worst { worst=error;worstTime=t;worstKey=key }
                            if error>0.001 { continuity.append(["key":key,"a":a.time,"b":b.time,"error":error,
                                "aY":a.position.y,"bY":b.position.y,"exactY":exact.position.y]) }
                        }
                    }
                    row["maxInterpolationErrorM"]=worst;row["worstTime"]=worstTime;row["worstKey"]=worstKey
                    row["discontinuities"]=Array(continuity.prefix(80))
                    if run==0,let path=shot.paths[PositionPlayBall.cueKey] {
                        row["cuePath"]=path.map { [Double($0.time),Double($0.position.x),Double($0.position.y),Double($0.position.z)] }
                    }
                    XCTAssertTrue(shot.validForBaseline)
                }
                report.append(row)
                print("V66_BASELINE \(label) \(run) solve=\(row["solveMS"]!) freeze=\(row["freezeMS"] ?? "none") error=\(row["maxInterpolationErrorM"] ?? "none")")
            }
        }
        let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name="v66-r0-solve-freeze-continuity";attachment.lifetime = .keepAlways;add(attachment)
        XCTAssertEqual(report.count,15)
    }
}

private extension SpatialPracticeRecord.Shot {
    var validForBaseline: Bool {
        duration.isFinite && paths.values.allSatisfy { path in path.allSatisfy { $0.time.isFinite && $0.position.finite } }
    }
}

final class SpatialPracticePreviewTests:XCTestCase {
    @MainActor
    func testPracticeElevationLimitClampsDraftAndRetryButPreservesOriginalShot() async throws {
        typealias R=SpatialPracticeRecord
        let suite="v66-angle-limit-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let owner=CurrentOwnerContext(defaults:defaults),cue=SCNVector3(0,BTTablePhysics.surfaceY+BallPhysics.radius,0)
        let original=R.Input(elevation:85)
        let board=[PositionPlayBall.cueKey:R.Pose(position:.init(cue),rotation:[0,0,0,1],disposition:"bed")]
        let prediction=ShotPredictor.simulateFree(cueBall:cue,aimDir:original.aim,velocity:Float(original.speed),
            spinX:0,spinY:0,surfaceY:BTTablePhysics.surfaceY,balls:[],maxEvents:3000,maxTime:40,
            simulationModel:.spatialPractice,elevation:original.radians,buildPolylines:false)
        let shot=try XCTUnwrap(R.freeze(prediction:prediction,input:original,before:board))
        var archived=R(board:board,input:original,lastShot:shot);archived.version=1
        XCTAssertTrue(archived.valid)
        let encoder=PropertyListEncoder(),key="spatialPractice.v1."+owner.ownerKey
        let originalBytes=try encoder.encode(archived)
        defaults.set(originalBytes,forKey:key)
        let vm=SpatialPracticeViewModel(defaults:defaults,ownerContext:owner)
        vm.setupScene();defer { vm.suspendTeachingActivity() }
        XCTAssertEqual(vm.input.elevation,75)
        XCTAssertEqual(vm.record.lastShot?.input.elevation,85)
        XCTAssertEqual(vm.record.lastShot?.id,shot.id)
        vm.updateInput { $0.elevation = -20 };XCTAssertEqual(vm.input.elevation,0)
        vm.updateInput { $0.elevation = 100 };XCTAssertEqual(vm.input.elevation,75)
        vm.retry();XCTAssertEqual(vm.input.elevation,75);XCTAssertNotNil(vm.message)
        for _ in 0..<500 where vm.archiveForTesting.pendingHistory { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertFalse(vm.archiveForTesting.pendingHistory)
        let preserved=try PropertyListDecoder().decode(R.self,from:XCTUnwrap(defaults.data(forKey:key)))
        XCTAssertEqual(preserved.input.elevation,85,"Migration must preserve the original bytes")
        XCTAssertEqual(defaults.data(forKey:key),originalBytes)
        XCTAssertEqual(defaults.data(forKey:key+".preserved"),originalBytes)
        let restored=SpatialPracticeViewModel(defaults:defaults,ownerContext:owner);restored.setupScene()
        defer { restored.suspendTeachingActivity() }
        XCTAssertEqual(restored.input.elevation,75)
        let stored=try XCTUnwrap(restored.record.lastShot)
        XCTAssertEqual(stored.input,shot.input)
        let canonical=JSONEncoder();canonical.outputFormatting=[.sortedKeys]
        XCTAssertEqual(try canonical.encode(stored.paths),try canonical.encode(shot.paths))
        XCTAssertEqual(stored.after,shot.after)
        XCTAssertNil(defaults.data(forKey:key+".unreadable"))
        vm.resetInputs();XCTAssertEqual(vm.input.elevation,45)
    }
    @MainActor
    func testRackDefaultContactAccessDiagnostic() throws {
        let scene=AngleTrainingScene();scene.setupScene();scene.setupVisualizationNodes()
        var rows:[[String:Any]]=[]
        for option in BreakFlowRunner.gameOptions {
            let rack=RackLayout.make(option.game,seed:66)
            let aim=BreakSimulator.aimAtApex(rack:rack,from:rack.cue)
            let profile=scene.cueStick?.clearanceProfile ?? CueSection.fallback
            var access=CueStrikeAccess(cue:rack.cue,aim:aim,obstacles:rack.balls.map(\.position),
                surfaceY:scene.surfaceY,profile:profile,fixedElevation:0)
            let flat=access.isAvailable(spinX:0,spinY:0)
            let degrees=(0...850).first { step in
                access.fixedElevation=Float(step)*(.pi/1800)
                return access.isAvailable(spinX:0,spinY:0)
            }
            XCTAssertNotNil(degrees)
            rows.append(["count":option.game.ballCount,"zeroAvailable":flat,"firstValidDegrees":Double(degrees ?? -1)/10])
        }
        let attachment=XCTAttachment(data:try JSONSerialization.data(withJSONObject:rows),uniformTypeIdentifier:"public.json")
        attachment.name="v66-rack-fixed-angle-access";attachment.lifetime = .keepAlways;add(attachment)
    }
    @MainActor
    func testTemporaryOverheadAllowsBoardEditingButBlocksShotInputs() throws {
        let suite="v66-overhead-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let vm=SpatialPracticeViewModel(defaults:defaults,ownerContext:CurrentOwnerContext(defaults:defaults))
        vm.setupScene();defer { vm.suspendTeachingActivity() }
        let rig=try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize=CGSize(width:874,height:402)
        vm.setCameraMode(.perspective3D)
        vm.beginTemporaryTopDown()
        XCTAssertTrue(vm.temporaryTopDownActive);XCTAssertTrue(vm.canEdit);XCTAssertFalse(vm.canTune)
        let input=vm.input
        vm.updateInput { $0.elevation=85 };vm.strike()
        XCTAssertEqual(vm.input,input);XCTAssertFalse(vm.busy)
        vm.place("_3",at:SCNVector3(0,BTTablePhysics.surfaceY+BallPhysics.radius,0.3))
        XCTAssertTrue(vm.onTableKeys.contains("_3"));XCTAssertTrue(vm.topDownSelectionChanged)
        vm.removeFromTable("_3");XCTAssertFalse(vm.onTableKeys.contains("_3"))
        vm.endTemporaryTopDown();XCTAssertFalse(vm.temporaryTopDownActive)
        XCTAssertEqual(vm.cameraMode,.perspective3D)
    }
    @MainActor
    func testSpatialDisplayPreferencesDoNotConsumeOrRewriteLegacyView() throws {
        let suite="v66-view-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let archive="{\"version\":1,\"general\":{\"view3D\":0},\"pages\":{\"masseJump\":{\"view3D\":0}}}"
        defaults.set(Data(archive.utf8),forKey:TablePreferencesStore.storageKey)
        let prefs=TablePreferencesStore(defaults:defaults)
        XCTAssertFalse(TablePreferencePage.masseJump.fields.contains(.view3D))
        let before=prefs.snapshot(for:.composer)
        prefs.apply(.trajectory,value:1,to:.masseJump)
        prefs.apply(.view3D,value:1,to:.masseJump)
        XCTAssertEqual(prefs.snapshot(for:.composer),before)
        let json=try XCTUnwrap(JSONSerialization.jsonObject(with:defaults.data(forKey:TablePreferencesStore.storageKey)!) as? [String:Any])
        XCTAssertEqual(((json["pages"] as? [String:[String:Double]])?["masseJump"])?["view3D"],0)
    }
    func testFixedElevationUsesSphericalContactAndNeverResolvesAnotherAngle() throws {
        let cue=SCNVector3(0,BTTablePhysics.surfaceY+BallPhysics.radius,0)
        for angle:Float in [0,0.2,0.8,1.4] {
            let access=CueStrikeAccess(cue:cue,aim:SCNVector3(1,0,0),obstacles:[],surfaceY:BTTablePhysics.surfaceY,fixedElevation:angle)
            for x in [-0.4,0,0.4] { for y in [-0.25,0,0.25] {
                let pose=access.pose(spinX:x,spinY:y,elevation:angle)
                let delta=pose.contact-cue
                XCTAssertEqual(sqrtf(delta.x*delta.x+delta.y*delta.y+delta.z*delta.z),BallPhysics.radius,accuracy:1e-6)
                XCTAssertEqual(access.isAvailable(spinX:x,spinY:y),access.clears(pose))
                if let resolved=access.resolvedPose(spinX:x,spinY:y) { XCTAssertEqual(resolved.elevation,angle);XCTAssertEqual(resolved.inset,0) }
            } }
        }
    }
    func testFixedConstraintReturnsOnlyReachablePointWithoutChangingAngle() {
        let cue=SCNVector3(-1.2,BTTablePhysics.surfaceY+BallPhysics.radius,0)
        let access=CueStrikeAccess(cue:cue,aim:SCNVector3(1,0,0),obstacles:[],surfaceY:BTTablePhysics.surfaceY,fixedElevation:0.1)
        for x in [-0.45,0,0.45] { for y in [-0.4,0,0.4] {
            if let p=access.constrained(spinX:x,spinY:y) {
                XCTAssertTrue(access.isAvailable(spinX:p.x,spinY:p.y))
                XCTAssertEqual(access.resolvedPose(spinX:p.x,spinY:p.y)?.elevation,0.1)
            }
        } }
    }
    func testFirstContactGroupIsOrderIndependentAndExcludesLaterContacts() throws {
        let cue=ShotInput.cueBallName
        let events:[ShotEvent]=[
            .init(time:1,kind:.ballBall(ballA:"_2",ballB:"_3")),
            .init(time:1,kind:.ballBall(ballA:"_1",ballB:"_2")),
            .init(time:1,kind:.ballBall(ballA:cue,ballB:"_1")),
            .init(time:2,kind:.ballBall(ballA:cue,ballB:"_4"))]
        let a=try XCTUnwrap(SpatialPracticeRecord.firstCueContact(events))
        let b=try XCTUnwrap(SpatialPracticeRecord.firstCueContact(events.reversed()))
        XCTAssertEqual(a.time,1);XCTAssertEqual(a.keys,["_1","_2","_3"]);XCTAssertEqual(a.keys,b.keys)
    }
    func testSpaceRoutesKeepHeightAndHonorFirstContactCutoff() throws {
        typealias R=SpatialPracticeRecord
        let input=R.Input(yaw:0,speed:4,spinX:0,spinY:0,elevation:50)
        let cue=SCNVector3(-0.65,BTTablePhysics.surfaceY+BallPhysics.radius,0)
        let board=[PositionPlayBall.cueKey:R.Pose(position:.init(cue),rotation:[0,0,0,1],disposition:"bed")]
        let prediction=ShotPredictor.simulateFree(cueBall:cue,aimDir:input.aim,velocity:4,spinX:0,spinY:0,
            surfaceY:BTTablePhysics.surfaceY,balls:[],maxEvents:3000,maxTime:40,simulationModel:.spatialPractice,elevation:input.radians,buildPolylines:false)
        var shot=try XCTUnwrap(R.freeze(prediction:prediction,input:input,before:board))
        let full=R.visibleRoute(shot,key:PositionPlayBall.cueKey,detail:.full)
        XCTAssertGreaterThan(full.map(\.y).max() ?? 0,cue.y+0.005)
        shot.firstContactTime=0.1
        let minimal=R.visibleRoute(shot,key:PositionPlayBall.cueKey,detail:.minimal)
        XCTAssertEqual(minimal.count,shot.paths[PositionPlayBall.cueKey]!.filter { $0.time<=0.1 && !$0.hidden }.count)
        XCTAssertLessThan(minimal.count,full.count)
    }
    func testSpatialDisplayReductionPreservesCurveWithinFrozenBudget() {
        let points=(0...1000).map { i -> SCNVector3 in
            let t=Float(i)/1000
            return SCNVector3(t,0.9+t-4.905*t*t,0.15*t*t)
        }
        let reduced=SpatialPracticeRecord.reducedRoute(points)
        XCTAssertLessThan(reduced.count,points.count/2)
        for p in points {
            let point=SIMD3(p.x,p.y,p.z)
            let nearest=(1..<reduced.count).map { i -> Float in
                let a=SIMD3(reduced[i-1].x,reduced[i-1].y,reduced[i-1].z),b=SIMD3(reduced[i].x,reduced[i].y,reduced[i].z),d=b-a
                let t=min(1,max(0,simd_dot(point-a,d)/simd_length_squared(d)))
                return simd_distance(point,a+d*t)
            }.min()!
            XCTAssertLessThanOrEqual(nearest,0.0000501)
        }
    }
    @MainActor
    func testBoardAndOwnerInvalidateSpaceResultAndHistory() async throws {
        let suite="v66-preview-owner-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let owner=CurrentOwnerContext(defaults:defaults)
        let vm=SpatialPracticeViewModel(defaults:defaults,ownerContext:owner)
        vm.setupScene();defer { vm.suspendTeachingActivity() }
        for _ in 0..<100 where vm.previewShot == nil { try await Task.sleep(for:.milliseconds(20)) }
        let original=try XCTUnwrap(vm.previewShot)
        vm.showsLastRoute=true
        vm.place("_3",at:SCNVector3(0,BTTablePhysics.surfaceY+BallPhysics.radius,0.3))
        XCTAssertNil(vm.previewShot);XCTAssertFalse(vm.showsLastRoute)
        for _ in 0..<100 where vm.previewShot == nil { try await Task.sleep(for:.milliseconds(20)) }
        let edited=try XCTUnwrap(vm.previewShot)
        XCTAssertNotEqual(edited.id,original.id);XCTAssertNotNil(edited.before["_3"])
        vm.updateInput { $0.speed=4.1 };vm.strike()
        owner.setOwnerKey(OwnerKey.account("preview-other"));vm.ownerChanged()
        for _ in 0..<100 where vm.previewShot == nil { try await Task.sleep(for:.milliseconds(20)) }
        XCTAssertFalse(vm.busy);XCTAssertNil(vm.record.lastShot);XCTAssertNil(vm.previewShot?.before["_3"])
    }
    @MainActor
    func testLatestPreviewCacheReuseAndCancelledStrikeCannotFireLater() async throws {
        let suite="v66-preview-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let vm=SpatialPracticeViewModel(defaults:defaults,ownerContext:CurrentOwnerContext(defaults:defaults))
        vm.setupScene();defer { vm.suspendTeachingActivity() }
        for i in 0..<20 { vm.updateInput { $0.elevation=Double(40+i) } }
        for _ in 0..<100 where vm.previewShot == nil { try await Task.sleep(for:.milliseconds(20)) }
        let shot=try XCTUnwrap(vm.previewShot)
        XCTAssertEqual(shot.input.elevation,59)
        let count=vm.completedSolves
        vm.refreshAim();vm.hidesAssists=true;vm.hidesAssists=false
        XCTAssertEqual(vm.previewShot?.id,shot.id)
        vm.strike();XCTAssertTrue(vm.busy);XCTAssertEqual(vm.completedSolves,count)
        vm.stopPlayback()
        vm.updateInput { $0.speed=3.5 };vm.strike()
        XCTAssertEqual(vm.phase,.calculating)
        vm.updateInput { $0.speed=2.5 }
        for _ in 0..<100 where vm.previewShot == nil { try await Task.sleep(for:.milliseconds(20)) }
        XCTAssertEqual(vm.previewShot?.input.speed,2.5);XCTAssertFalse(vm.busy);XCTAssertEqual(vm.phase,.ready)
        vm.strike();XCTAssertTrue(vm.busy)
        vm.suspendTeachingActivity()
        let stoppedCount=vm.completedSolves
        try await Task.sleep(for:.milliseconds(200))
        XCTAssertNil(vm.previewShot);XCTAssertEqual(vm.completedSolves,stoppedCount);XCTAssertFalse(vm.busy)
    }
    @MainActor
    func testStrikeJoinsTheActualInFlightRackPrediction() async throws {
        let suite="v66-in-flight-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
        defer { defaults.removePersistentDomain(forName:suite) }
        let vm=SpatialPracticeViewModel(defaults:defaults,ownerContext:CurrentOwnerContext(defaults:defaults))
        vm.setupScene();defer { vm.suspendTeachingActivity() }
        vm.prepareBreak(ballCount:15,seed:66)
        vm.scene.cameraRig?.viewportSize=CGSize(width:844,height:390)
        for _ in 0..<240 { vm.scene.cameraRig?.update(deltaTime:1/120) }
        for _ in 0..<1000 where !vm.hasActiveCurrentPrediction { try await Task.sleep(for:.milliseconds(2)) }
        XCTAssertTrue(vm.hasActiveCurrentPrediction,"Observe a real active solve, not a completed cache hit")
        XCTAssertNil(vm.previewShot);XCTAssertTrue(vm.canStrike)
        let started=vm.startedSolves,input=vm.input
        vm.strike()
        XCTAssertEqual(vm.phase,.calculating)
        XCTAssertTrue(vm.hasActiveCurrentPrediction,"The accepted in-flight request must remain uncancelled")
        for _ in 0..<1500 where !vm.busy { try await Task.sleep(for:.milliseconds(20)) }
        XCTAssertTrue(vm.busy);XCTAssertEqual(vm.activeShot?.input,input)
        XCTAssertEqual(vm.activeShot?.before.count,16)
        XCTAssertEqual(vm.startedSolves,started,"Strike must not start a second solver for the same rack")
        vm.stopPlayback()
        XCTAssertEqual(vm.phase,.ready)
        XCTAssertEqual(vm.onTableKeys.count,16)
    }
}

final class SpatialPracticeBreakTests:XCTestCase {
    @MainActor private func settleCamera(_ vm:SpatialPracticeViewModel) {
        vm.scene.cameraRig?.viewportSize=CGSize(width:844,height:390)
        for _ in 0..<240 { vm.scene.cameraRig?.update(deltaTime:1/120) }
    }
    @MainActor private func waitForPreview(_ vm:SpatialPracticeViewModel) async throws -> SpatialPracticeRecord.Shot {
        for _ in 0..<1500 where vm.previewShot == nil { try await Task.sleep(for:.milliseconds(20)) }
        return try XCTUnwrap(vm.previewShot,vm.message ?? "Missing spatial break preview")
    }
    @MainActor
    func testFiveGamesUseSpatialPredictionAndIndependentBreakInput() async throws {
        let suite="v66-break-five-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let vm=SpatialPracticeViewModel(defaults:defaults,ownerContext:CurrentOwnerContext(defaults:defaults))
        vm.setupScene();defer { vm.suspendTeachingActivity() }
        vm.updateInput { $0.elevation=57;$0.speed=2.8;$0.spinX=0.2 }
        let ordinary=vm.input
        for count in [15,9,6,5,4] {
            vm.prepareBreak(ballCount:count,seed:66);settleCamera(vm)
            XCTAssertEqual(vm.onTableKeys.count,count+1)
            XCTAssertEqual(vm.draggableBalls.count,1)
            XCTAssertEqual(vm.input.speed,BreakFlowRunner.defaultBreakVelocity)
            XCTAssertEqual(vm.input.elevation,Double(CueStick.minElevationRadians)*180 / .pi,accuracy:1e-8)
            XCTAssertFalse(vm.input.valid,"Ordinary practice must still reject 10 m/s")
            XCTAssertTrue(vm.canStrike)
            let shot=try await waitForPreview(vm)
            XCTAssertEqual(shot.before.count,count+1);XCTAssertEqual(shot.paths.count,count+1)
            XCTAssertEqual(shot.breakContext?.ordinaryInput,ordinary)
            XCTAssertEqual(shot.breakContext?.prepared.count,count)
            XCTAssertTrue(vm.record.valid)
            let solves=vm.completedSolves
            vm.refreshAim();XCTAssertEqual(vm.previewShot?.id,shot.id);XCTAssertEqual(vm.completedSolves,solves)
        }
        vm.updateInput { $0.elevation=45 }
        let high=try await waitForPreview(vm)
        XCTAssertGreaterThan(high.maximumHeight,0.005,"The prepared rack must execute the spatial model")
        vm.clear();XCTAssertFalse(vm.isBreakMode);XCTAssertEqual(vm.input,ordinary)
        XCTAssertEqual(vm.velocityRange.upperBound,8)
    }
    @MainActor
    func testPreparedRackRestoresSeedManualAimAndOwnerWithoutAddingBalls() throws {
        let suite="v66-break-memory-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let owner=CurrentOwnerContext(defaults:defaults)
        let vm=SpatialPracticeViewModel(defaults:defaults,ownerContext:owner)
        vm.setupScene();defer { vm.suspendTeachingActivity() }
        vm.prepareBreak(ballCount:6,seed:66);settleCamera(vm)
        let cue=try XCTUnwrap(vm.scene.cueBallNode)
        vm.dragBegan(node:cue);vm.dragMoved(node:cue,worldPosition:SCNVector3(-2,0,2));vm.dragEnded(node:cue)
        XCTAssertGreaterThanOrEqual(cue.position.x,TablePhysics.innerLength/4)
        XCTAssertLessThanOrEqual(cue.position.z,TablePhysics.innerWidth/2-BallPhysics.radius)
        vm.nudgeAim(12);let yaw=vm.input.yaw
        vm.dragBegan(node:cue);vm.dragMoved(node:cue,worldPosition:SCNVector3(0.8,0,0));vm.dragEnded(node:cue)
        XCTAssertEqual(vm.input.yaw,yaw,accuracy:1e-6)
        vm.placeFromPalette("_15");XCTAssertEqual(vm.onTableKeys.count,7)
        let board=vm.record.board,context=vm.record.breakContext
        vm.suspendTeachingActivity()
        let restored=SpatialPracticeViewModel(defaults:defaults,ownerContext:owner)
        restored.setupScene();defer { restored.suspendTeachingActivity() }
        XCTAssertEqual(restored.record.board,board);XCTAssertEqual(restored.record.breakContext,context)
        XCTAssertEqual(restored.input.yaw,yaw,accuracy:1e-6);XCTAssertTrue(restored.isBreakMode)
        restored.updateInput { $0.speed=7 }
        restored.prepareBreak(ballCount:6)
        XCTAssertEqual(restored.record.breakContext?.prepared.seed,66)
        XCTAssertEqual(restored.input.speed,7,"Selecting the current gameplay must preserve tuning")
        restored.prepareBreak();XCTAssertEqual(restored.record.breakContext?.prepared.seed,67)
        owner.setOwnerKey(OwnerKey.account("break-other"));restored.ownerChanged()
        XCTAssertFalse(restored.isBreakMode);XCTAssertEqual(restored.breakGameBallCount,15)
    }
    @MainActor
    func testRealSixteenBallPlaybackDeliversThenRetryAndStopRestoreRack() async throws {
        let suite="v66-break-play-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let owner=CurrentOwnerContext(defaults:defaults)
        let vm=SpatialPracticeViewModel(defaults:defaults,ownerContext:owner)
        vm.setupScene();defer { vm.suspendTeachingActivity() }
        vm.scene.cameraRig?.viewportSize=CGSize(width:844,height:390)
        vm.updateInput { $0.elevation=52;$0.speed=2.4;$0.spinY=0.2 }
        let ordinary=vm.input
        vm.prepareBreak(ballCount:15,seed:66);settleCamera(vm)
        let shot=try await waitForPreview(vm),before=vm.record.board
        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
        renderer.scene=vm.scene;renderer.pointOfView=vm.scene.cameraNode
        vm.strike();XCTAssertTrue(vm.busy)
        let start=CACurrentMediaTime()
        while vm.record.lastShot == nil && CACurrentMediaTime()-start<65 {
            _=renderer.snapshot(atTime:CACurrentMediaTime(),with:CGSize(width:64,height:64),antialiasingMode:.none)
            try await Task.sleep(for:.milliseconds(16))
        }
        XCTAssertEqual(vm.record.lastShot?.id,shot.id)
        XCTAssertFalse(vm.busy);XCTAssertFalse(vm.isBreakMode);XCTAssertEqual(vm.input,ordinary)
        XCTAssertEqual(vm.record.board,SpatialPracticeRecovery.recover(shot.after,before:shot.before).board)
        XCTAssertEqual(vm.record.lastShot?.after,shot.after,"Recovery must not rewrite physics")
        XCTAssertTrue(vm.record.valid)
        let historyURL=vm.archiveForTesting.historyURL(shot.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath:historyURL.path))
        let saved=try PropertyListDecoder().decode(SpatialPracticeRecord.Shot.self,from:Data(contentsOf:historyURL))
        XCTAssertEqual(saved.id,shot.id);XCTAssertEqual(saved.paths.values.reduce(0){$0+$1.count},shot.paths.values.reduce(0){$0+$1.count})
        let encodes=vm.archiveForTesting.historyEncodeCount
        for i in 0..<20 { vm.updateInput { $0.elevation=Double(40+i) };vm.save() }
        XCTAssertEqual(vm.archiveForTesting.historyEncodeCount,encodes,"Editing a draft must never re-encode its old trajectory")
        vm.retry();XCTAssertTrue(vm.isBreakMode);XCTAssertEqual(vm.record.board,before)
        XCTAssertEqual(vm.input,shot.input);XCTAssertEqual(vm.record.lastShot?.id,shot.id)
        _=try await waitForPreview(vm)
        vm.strike();XCTAssertTrue(vm.busy);vm.stopPlayback()
        XCTAssertEqual(vm.record.board,before);XCTAssertTrue(vm.isBreakMode)
        XCTAssertEqual(vm.record.lastShot?.id,shot.id)
        vm.suspendTeachingActivity()
        let restored=SpatialPracticeViewModel(defaults:defaults,ownerContext:owner)
        restored.setupScene();defer { restored.suspendTeachingActivity() }
        XCTAssertTrue(restored.isBreakMode);XCTAssertEqual(restored.record.board,before)
        XCTAssertEqual(restored.record.lastShot?.id,shot.id)
    }
}
