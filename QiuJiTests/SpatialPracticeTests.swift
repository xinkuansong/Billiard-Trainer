import XCTest
import SceneKit
import simd
@testable import QiuJi

final class SpatialPracticeTests: XCTestCase {
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
        vm.clear();vm.updateInput { $0.elevation=72 }
        owner.useAccount(userID:"B");vm.ownerChanged()
        XCTAssertEqual(vm.onTableKeys.count,3);XCTAssertEqual(vm.input.elevation,50)
        owner.useAccount(userID:"A");vm.ownerChanged()
        XCTAssertTrue(vm.onTableKeys.isEmpty);XCTAssertEqual(vm.input.elevation,72)
        vm.suspendTeachingActivity()
        let key="spatialPractice.v1."+owner.ownerKey,bad=Data("broken".utf8)
        defaults.set(bad,forKey:key)
        let restored=SpatialPracticeViewModel(defaults:defaults,ownerContext:owner);restored.setupScene()
        XCTAssertEqual(defaults.data(forKey:key+".unreadable"),bad)
        XCTAssertEqual(restored.onTableKeys.count,3)
        XCTAssertNotNil(restored.message)
        restored.suspendTeachingActivity()
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
