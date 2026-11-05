import XCTest
import SceneKit
@testable import QiuJi

@MainActor
final class PocketToleranceTests: XCTestCase {
    private func window(_ x: Float, _ z: Float, _ pocket: Int, table: Bool = false) throws -> PocketToleranceGeometry.Window {
        guard case .window(let w) = PocketToleranceGeometry.evaluate(x: x, z: z, pocket: pocket, useTable: table) else {
            throw NSError(domain: "Expected positive window", code: 1)
        }
        return w
    }
    func testSixPocketsHaveTangentOuterEdgesAndMatchingFullAngle() throws {
        let r = Double(AngleSceneCalculator.ballRadius)
        for pocket in 0..<6 {
            let w = try window(0, 0, pocket)
            XCTAssertEqual(w.edges.count, 2)
            var directions: [(Double, Double)] = []
            for e in w.edges {
                let x = Double(e.startX), z = Double(e.startZ)
                let dx = Double(e.endX - e.startX), dz = Double(e.endZ - e.startZ)
                let length = hypot(dx, dz)
                XCTAssertEqual(hypot(x, z), r, accuracy: 0.000001)
                XCTAssertEqual((x * dx + z * dz) / length, 0, accuracy: 0.000001)
                directions.append((dx / length, dz / length))
            }
            let a = directions[0], b = directions[1]
            let angle = abs(atan2(a.0*b.1-a.1*b.0, a.0*b.0+a.1*b.1)) * 180 / .pi
            XCTAssertEqual(angle, w.degrees, accuracy: 0.00002)
        }
    }
    func testNearerMiddlePocketWidensWindowAndMirrorMatches() throws {
        let far = try window(0, 0.3, 4), near = try window(0, -0.3, 4)
        XCTAssertGreaterThan(near.degrees, far.degrees)
        XCTAssertEqual(near.degrees, try window(0, 0.3, 5).degrees, accuracy: 0.0001)
    }
    func testTableAndExactAgreeOnInteriorSamples() throws {
        for (x,z) in [(Float(0.1),Float(0.2)),(-0.3,-0.2),(0.5,0.1)] {
            for p in 0..<6 {
                XCTAssertEqual(try window(x,z,p,table:true).degrees, try window(x,z,p).degrees, accuracy: 0.001)
            }
        }
    }
    func testInvalidInputAndTinyPositiveFormatting() {
        for (x,z,p) in [(Float.nan,Float(0),0),(3,0,0),(0,0,6)] {
            guard case .unavailable = PocketToleranceGeometry.evaluate(x:x,z:z,pocket:p) else { return XCTFail("Invalid input accepted") }
        }
        XCTAssertEqual(PocketToleranceGeometry.displayDegrees(0.003202), "0.003°")
        XCTAssertEqual(PocketToleranceGeometry.displayDegrees(0.0001), "<0.001°")
    }
    func testSelectionRemembersEachPocketAndOtherBallsDoNotChangeAngle() async throws {
        let vm = PocketToleranceViewModel(); vm.setupScene()
        defer { vm.suspendTeachingActivity() }
        XCTAssertTrue(vm.scene.cueBallNode?.isHidden == true)
        vm.selectPocket(at: 4)
        try await settled(vm)
        let original = vm.angleText
        vm.placeFromPalette("_1")
        XCTAssertEqual(vm.selectedTargetKey, "_1"); XCTAssertEqual(vm.selectedPocketIndex, -1)
        vm.selectPocket(at: 2)
        vm.selectTarget(key: "_3")
        XCTAssertEqual(vm.selectedPocketIndex, 4)
        try await settled(vm)
        XCTAssertEqual(vm.angleText, original); XCTAssertEqual(vm.boundaryCount, 2)
        vm.selectTarget(key: "_1"); XCTAssertEqual(vm.selectedPocketIndex, 2)
        vm.removeFromTable("_1")
        XCTAssertEqual(vm.selectedTargetKey, "_3"); XCTAssertEqual(vm.selectedPocketIndex, 4)
        vm.removeFromTable("_3")
        XCTAssertNil(vm.selectedTargetKey); XCTAssertEqual(vm.boundaryCount, 0); XCTAssertEqual(vm.angleText, "—")
    }
    func testDragKeepsPocketAndSuspensionRejectsPendingResult() async throws {
        let vm = PocketToleranceViewModel(); vm.setupScene()
        vm.selectPocket(at: 4)
        let target = try XCTUnwrap(vm.targetNode)
        vm.dragBegan(node:target)
        vm.dragMoved(node:target,worldPosition:SCNVector3(0.2,0,-0.2))
        vm.dragEnded(node:target)
        XCTAssertEqual(vm.selectedPocketIndex,4)
        vm.selectPocket(at:5); vm.selectPocket(at:4)
        try await settled(vm)
        XCTAssertEqual(vm.angleText, PocketToleranceGeometry.displayDegrees(try window(target.position.x,target.position.z,4,table:true).degrees))
        vm.selectPocket(at:5);vm.suspendTeachingActivity()
        try await Task.sleep(nanoseconds:100_000_000)
        XCTAssertEqual(vm.boundaryCount,0)
        vm.resumeTeachingActivity();try await settled(vm)
        XCTAssertEqual(vm.boundaryCount,2)
        vm.suspendTeachingActivity()
    }
    func testKnownCornerCoverageGapDoesNotBecomePositiveWindow() {
        guard case .noStraightWindow = PocketToleranceGeometry.evaluate(x: -1.2274777889, z: -0.4381169081, pocket: 0) else {
            return XCTFail("The existing C model gap must remain explicit")
        }
    }
    func testObjectOnlyOverviewDoesNotRequireCueShot() throws {
        let vm = PocketToleranceViewModel(); vm.setupScene()
        defer { vm.suspendTeachingActivity() }
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = CGSize(width: 800, height: 400)
        XCTAssertNil(vm.currentPlayerAim)
        XCTAssertFalse(rig.usesSurfaceCamera)
        XCTAssertTrue(rig.enterMergedGlobal(aim: nil))
        XCTAssertTrue(rig.keepsWholeTableFramed)
    }
    func testObjectOverviewRequestedBeforeLayoutFitsAndSurvivesRoundTrip() throws {
        let vm = PocketToleranceViewModel();vm.setupScene()
        defer { vm.suspendTeachingActivity() }
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        vm.setCameraMode(.topDown2D)
        vm.setCameraMode(.perspective3D)
        XCTAssertTrue(rig.keepsWholeTableFramed)
        let view = SCNView(frame:CGRect(x:0,y:0,width:667,height:375))
        view.scene = vm.scene;view.pointOfView = vm.scene.cameraNode
        rig.viewportSize = view.bounds.size
        for _ in 0..<600 { rig.update(deltaTime:1/60) }
        vm.setCameraMode(.topDown2D);vm.setCameraMode(.perspective3D)
        SCNTransaction.flush();view.layoutIfNeeded()
        for x in [-Float(rig.tableOuterHalfLength),Float(rig.tableOuterHalfLength)] {
            for z in [-Float(rig.tableOuterHalfWidth),Float(rig.tableOuterHalfWidth)] {
                let p = view.projectPoint(SCNVector3(x,vm.scene.surfaceY,z))
                XCTAssertGreaterThanOrEqual(p.x,0);XCTAssertLessThanOrEqual(p.x,667)
                XCTAssertGreaterThanOrEqual(p.y,0);XCTAssertLessThanOrEqual(p.y,375)
                XCTAssertGreaterThan(p.z,0);XCTAssertLessThan(p.z,1)
            }
        }
    }
    func testObjectOverviewReachesIdleAtPhoneAndPadSizes() throws {
        let sizes = [CGSize(width:667,height:375),CGSize(width:1210,height:834),CGSize(width:834,height:1210)]
        for (size,fps) in sizes.flatMap({ size in [Float(30),60,120].map { (size,$0) } }) {
            let vm = PocketToleranceViewModel();vm.setupScene()
            let rig = try XCTUnwrap(vm.scene.cameraRig)
            rig.viewportSize = size;vm.setCameraMode(.perspective3D)
            XCTAssertTrue(rig.hasPendingDamping)
            for _ in 0..<1800 { rig.update(deltaTime:1/fps) }
            let state = Mirror(reflecting:rig).children.filter { ["currentOrbit","targetOrbit","currentYaw","targetYaw","currentPivot","targetPivot"].contains($0.label ?? "") }.map { "\($0.label!):\($0.value)" }.joined(separator:"; ")
            XCTAssertFalse(rig.hasPendingDamping,"\(size): \(state)")
            vm.suspendTeachingActivity()
        }
    }
    private func settled(_ vm: PocketToleranceViewModel) async throws {
        for _ in 0..<200 {
            if vm.boundaryCount == 2 { return }
            try await Task.sleep(nanoseconds:10_000_000)
        }
        XCTFail("No latest geometry result: \(vm.message)")
    }
}
