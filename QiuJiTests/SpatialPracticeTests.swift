import XCTest
import SceneKit
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
        XCTAssertNotNil(solver.planarSupport(from:.init(time:0,position:SIMD3(0,Double(BTTablePhysics.surfaceY+BallPhysics.radius),0),
            velocity:.zero,omega:.zero),surfaceY:Double(BTTablePhysics.surfaceY)))
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
