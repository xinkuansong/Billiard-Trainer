import XCTest
import SceneKit
import simd
@testable import QiuJi

final class SpatialPracticeRecoveryTests:XCTestCase {
    typealias R=SpatialPracticeRecord
    private func pose(_ x:Float,_ z:Float,_ disposition:String="bed")->R.Pose {
        .init(position:.init(SCNVector3(x,BTTablePhysics.surfaceY+BallPhysics.radius,z)),rotation:[0,0,0,1],disposition:disposition)
    }
    func testRecoveryPreservesPotsAndPlacesCueAtNearestFreePointDeterministically() throws {
        let cue=PositionPlayBall.cueKey
        let before=[cue:pose(0,0),"_1":pose(0.2,0),"_2":pose(-0.2,0)]
        let after=[cue:pose(2,0,"escaped"),"_1":pose(0,0),"_2":pose(-2,0,"outside"),"_3":pose(1,0,"pocket")]
        let result=SpatialPracticeRecovery.recover(after,before:before)
        let restored=try XCTUnwrap(result.board[cue])
        XCTAssertEqual(restored.disposition,"bed")
        XCTAssertTrue(SpatialPracticeRecovery.isLegal(restored.position.scene,board:result.board))
        XCTAssertEqual(hypot(restored.position.x,restored.position.z),2*BallPhysics.radius+0.0001,accuracy:0.000003)
        XCTAssertNil(result.board["_2"]);XCTAssertEqual(result.board["_3"],after["_3"])
        XCTAssertEqual(result.events.map(\.reason).sorted(),["escaped","outside"])
        let repeated=SpatialPracticeRecovery.recover(result.board,before:before)
        XCTAssertEqual(repeated.board,result.board);XCTAssertTrue(repeated.events.isEmpty)
        let reverse=Dictionary(uniqueKeysWithValues:after.sorted {$0.key>$1.key}.map {($0.key,$0.value)})
        XCTAssertEqual(SpatialPracticeRecovery.recover(reverse,before:before).board,result.board)
        for reason in ["outside","escaped","pocket"] {
            let free=SpatialPracticeRecovery.recover([cue:pose(2,0,reason)],before:before)
            XCTAssertEqual(free.board[cue],before[cue]);XCTAssertEqual(free.events.first?.reason,reason)
        }
    }
    func testNearestPlacementAvoidsPocketsRailsAndDenseNeighbors() throws {
        let r=BallPhysics.radius
        var rows:[[String:Any]]=[]
        for preferred in [SCNVector3(0,0,0),.init(0,0,0.634),.init(1.269,0,0.634),.init(-1.269,0,-0.634)] {
            var board:[String:R.Pose]=[:]
            for i in 0..<15 {
                let angle=Float(i)*2 * .pi/15
                board["_\(i+1)"]=pose(preferred.x+cos(angle)*2*r,preferred.z+sin(angle)*2*r)
            }
            let point=try XCTUnwrap(SpatialPracticeRecovery.nearestLegalPoint(to:preferred,board:board))
            XCTAssertTrue(SpatialPracticeRecovery.isLegal(point,board:board))
            XCTAssertEqual(point.y,BTTablePhysics.surfaceY+r)
            rows.append(["preferred":[preferred.x,preferred.z],"restored":[point.x,point.z],
                "balls":board.keys.sorted().map { [board[$0]!.position.x,board[$0]!.position.z] }])
            let distance=hypot(point.x-preferred.x,point.z-preferred.z)
            for ix in -25...25 { for iz in -25...25 {
                let candidate=SCNVector3(preferred.x+Float(ix)*0.01,point.y,preferred.z+Float(iz)*0.01)
                if SpatialPracticeRecovery.isLegal(candidate,board:board) {
                    XCTAssertLessThanOrEqual(distance,hypot(candidate.x-preferred.x,candidate.z-preferred.z)+0.000004)
                }
            } }
        }
        let report:[String:Any]=["cases":rows,"radius":r,"length":TablePhysics.innerLength,"width":TablePhysics.innerWidth,
            "pockets":AngleSceneCalculator.pocketPositions(surfaceY:BTTablePhysics.surfaceY).map {[$0.x,$0.z]}]
        let data=try JSONSerialization.data(withJSONObject:report,options:.sortedKeys)
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name="v66-actual-recovery-geometry";attachment.lifetime = .keepAlways;add(attachment)
    }
    @MainActor
    func testNativeNearRailFixtureProducesDurableHistory() async throws {
        let suite="v66-native-archive-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer {defaults.removePersistentDomain(forName:suite)}
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {try? FileManager.default.removeItem(at:root)}
        let vm=SpatialPracticeViewModel(defaults:defaults,ownerContext:CurrentOwnerContext(defaults:defaults),archiveRoot:root)
        vm.setupScene();defer {vm.suspendTeachingActivity()}
        vm.scene.cameraRig?.viewportSize=CGSize(width:874,height:402)
        vm.setCameraMode(.perspective3D);vm.clear()
        vm.place(PositionPlayBall.cueKey,at:SCNVector3(0.999949455,0.828575015,0.0005759854))
        vm.updateInput {$0.yaw=0;$0.speed=8;$0.elevation=45}
        for _ in 0..<1000 where vm.previewShot == nil {try await Task.sleep(for:.milliseconds(10))}
        var shot=try XCTUnwrap(vm.previewShot)
        vm.requestSurfaceOverview()
        for _ in 0..<240 {vm.scene.cameraRig?.update(deltaTime:1/120)}
        shot.camera=vm.scene.cameraRig?.trainingBookmark()
        let recovered=SpatialPracticeRecovery.recover(shot.after,before:shot.before)
        shot.recovered=recovered.board;shot.recoveries=recovered.events
        let encoder=PropertyListEncoder();encoder.outputFormat = .binary
        let attachment=XCTAttachment(data:try encoder.encode(shot),uniformTypeIdentifier:"com.apple.property-list")
        attachment.name="v66-native-near-rail-physical-shot";attachment.lifetime = .keepAlways;add(attachment)
        XCTAssertTrue(R.validShot(shot))
        let archive=vm.archiveForTesting
        archive.prepare(shot)
        archive.save(R(board:recovered.board,input:shot.input,lastShot:shot))
        for _ in 0..<300 where archive.pendingHistory {try await Task.sleep(for:.milliseconds(10))}
        XCTAssertEqual(archive.committedHistoryID,shot.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath:archive.historyURL(shot.id).path))
    }
    @MainActor
    func testRealFlyoutWaitsForFullPlaybackAndReplayRestoresDraftAndDurableCamera() async throws {
        let suite="v66-recovery-play-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer {defaults.removePersistentDomain(forName:suite)}
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {if FileManager.default.fileExists(atPath:root.path) {do {try FileManager.default.removeItem(at:root)} catch {XCTFail("Cleanup: \(error)")}}}
        let owner=CurrentOwnerContext(defaults:defaults)
        let vm=SpatialPracticeViewModel(defaults:defaults,ownerContext:owner,archiveRoot:root)
        vm.setupScene();defer {vm.suspendTeachingActivity()}
        vm.scene.cameraRig?.viewportSize=CGSize(width:844,height:390)
        // BTTeachingTablePage performs this after setup; replay captures the
        // actual scene mode, not merely the host's preferred cameraMode property.
        vm.setCameraMode(.perspective3D)
        XCTAssertEqual(vm.scene.currentCameraMode,.perspective3D)
        vm.clear();vm.place(PositionPlayBall.cueKey,at:SCNVector3(1.0,0.828575,0))
        vm.place("_1",at:SCNVector3(-1.0,0.828575,0.3))
        vm.updateInput {$0.yaw=0;$0.speed=8;$0.elevation=50}
        for _ in 0..<1000 where vm.previewShot == nil {try await Task.sleep(for:.milliseconds(10))}
        let shot=try XCTUnwrap(vm.previewShot,vm.message ?? "Missing preview")
        XCTAssertTrue(["outside","escaped"].contains(shot.after[PositionPlayBall.cueKey]?.disposition ?? ""))
        let before=vm.record.board
        let rig=try XCTUnwrap(vm.scene.cameraRig)
        vm.requestSurfaceOverview();for _ in 0..<240 {rig.update(deltaTime:1/120)}
        let original=rig.trainingBookmark()
        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
        renderer.scene=vm.scene;renderer.pointOfView=vm.scene.cameraNode
        vm.strike();XCTAssertTrue(vm.busy)
        let start=CACurrentMediaTime();var sawMoving=false
        while vm.busy && CACurrentMediaTime()-start<60 {
            _=renderer.snapshot(atTime:CACurrentMediaTime(),with:CGSize(width:64,height:64),antialiasingMode:.none)
            if vm.scene.cueBallNode?.hasActions == true {
                if !sawMoving {
                    let cue=try XCTUnwrap(vm.scene.cueStick?.rootNode)
                    XCTAssertFalse(cue.isHidden,"Contact must not abruptly hide the normal follow-through")
                    XCTAssertTrue(cue.hasActions,"The shared stroke must retain its follow-through actions")
                }
                sawMoving=true
                XCTAssertEqual(vm.record.board,before,"Recovery must wait until the whole shot finishes")
                XCTAssertFalse(vm.scene.allBallNodes["_1"]?.hasActions ?? true,"Static balls need no frame action")
            }
            try await Task.sleep(for:.milliseconds(16))
        }
        XCTAssertTrue(sawMoving);XCTAssertFalse(vm.busy)
        XCTAssertEqual(vm.record.lastShot?.after,shot.after)
        XCTAssertEqual(vm.record.board[PositionPlayBall.cueKey],before[PositionPlayBall.cueKey])
        XCTAssertEqual(vm.record.lastShot?.recoveries?.filter {PositionPlayBall.isCue($0.key)}.count,1)
        vm.suspendTeachingActivity()
        let restored=SpatialPracticeViewModel(defaults:defaults,ownerContext:owner,archiveRoot:root)
        restored.setupScene();defer {restored.suspendTeachingActivity()}
        XCTAssertEqual(restored.record.lastShot?.camera?.pose,original.pose)
        let restoredRig=try XCTUnwrap(restored.scene.cameraRig);restoredRig.viewportSize=CGSize(width:844,height:390)
        restored.setCameraMode(.perspective3D)
        XCTAssertEqual(restored.scene.currentCameraMode,.perspective3D)
        restored.updateInput {$0.elevation=20;$0.yaw=1}
        let draft=restored.record.board,input=restored.input
        XCTAssertTrue(restored.requestPlayerView(.thirdPerson));for _ in 0..<240 {restoredRig.update(deltaTime:1/120)}
        let current=restoredRig.trainingBookmark()
        XCTAssertNotEqual(current.pose,original.pose,"The two real viewpoints must differ")
        restored.replay();XCTAssertTrue(restored.busy)
        XCTAssertEqual(restored.displayedInput,shot.input);XCTAssertEqual(restored.input,input)
        let replay=restoredRig.trainingBookmark()
        for (a,b) in zip(replay.pose,original.pose) {XCTAssertEqual(a,b,accuracy:0.0001)}
        restored.stopPlayback();restoredRig.update(deltaTime:1/60)
        XCTAssertEqual(restored.record.board,draft);XCTAssertEqual(restored.input,input)
        for (a,b) in zip(restoredRig.trainingBookmark().pose,current.pose) {XCTAssertEqual(a,b,accuracy:0.0001)}
        XCTAssertEqual(restored.record.lastShot?.after,shot.after)
        renderer.scene=restored.scene;renderer.pointOfView=restored.scene.cameraNode
        restored.replay()
        let replayStart=CACurrentMediaTime()
        while restored.busy && CACurrentMediaTime()-replayStart<60 {
            _=renderer.snapshot(atTime:CACurrentMediaTime(),with:CGSize(width:64,height:64),antialiasingMode:.none)
            try await Task.sleep(for:.milliseconds(16))
        }
        XCTAssertFalse(restored.busy);restoredRig.update(deltaTime:1/60)
        XCTAssertEqual(restored.record.board,draft);XCTAssertEqual(restored.input,input)
        XCTAssertEqual(restored.record.lastShot?.after,shot.after)
        for (a,b) in zip(restoredRig.trainingBookmark().pose,current.pose) {XCTAssertEqual(a,b,accuracy:0.0001)}
    }
}

@MainActor
final class SpatialPracticeArchiveTests:XCTestCase {
    typealias R=SpatialPracticeRecord
    private func shot(id:UUID=UUID(),samples:Int=2)->R.Shot {
        let pose=R.Pose(position:.init(SCNVector3(0,BTTablePhysics.surfaceY+BallPhysics.radius,0)),rotation:[0,0,0,1],disposition:"bed")
        let board=[PositionPlayBall.cueKey:pose]
        return .init(id:id,geometryVersion:SpatialPracticeGeometry.version,input:.init(),before:board,after:board,
            paths:[PositionPlayBall.cueKey:(0..<samples).map {.init(time:Float($0)/Float(samples-1),position:pose.position,rotation:pose.rotation,hidden:false)}],duration:1,maximumHeight:0,landing:nil)
    }
    private func settled(_ archive:SpatialPracticeArchive) async throws {
        for _ in 0..<1000 where archive.pendingHistory {try await Task.sleep(for:.milliseconds(10))}
        XCTAssertFalse(archive.pendingHistory)
    }
    func testImmutableHistorySmallDraftAndRealWriteFailureRetry() async throws {
        let suite="v66-archive-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer {defaults.removePersistentDomain(forName:suite)}
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {if FileManager.default.fileExists(atPath:root.path) {do {try FileManager.default.removeItem(at:root)} catch {XCTFail("Cleanup: \(error)")}}}
        let archive=SpatialPracticeArchive(defaults:defaults,root:root)
        _=archive.begin(owner:"A");defer {archive.end()}
        let first=shot(samples:12000)
        var record=R(board:first.after,input:.init(),lastShot:first)
        archive.save(record);try await settled(archive)
        let original=try Data(contentsOf:archive.historyURL(first.id)),encodes=archive.historyEncodeCount
        for i in 0..<30 {record.input.elevation=Double(i);archive.save(record)}
        XCTAssertEqual(archive.historyEncodeCount,encodes)
        XCTAssertEqual(try Data(contentsOf:archive.historyURL(first.id)),original)
        XCTAssertLessThan(try XCTUnwrap(defaults.data(forKey:archive.draftKey)).count,5000)
        let second=shot();record.lastShot=second
        let obstruction=archive.historyURL(second.id)
        try FileManager.default.createDirectory(at:obstruction,withIntermediateDirectories:true)
        var message:String?;archive.onError={message=$0}
        archive.save(record);try await settled(archive)
        XCTAssertNotNil(message);XCTAssertEqual(archive.committedHistoryID,first.id)
        let read=SpatialPracticeArchive(defaults:defaults,root:root)
        XCTAssertEqual(read.begin(owner:"A")?.lastShot?.id,first.id)
        read.end();_=archive.begin(owner:"A")
        try FileManager.default.removeItem(at:obstruction)
        archive.save(record);try await settled(archive)
        XCTAssertEqual(archive.committedHistoryID,second.id);XCTAssertNil(message)
        let reopened=SpatialPracticeArchive(defaults:defaults,root:root)
        let restored=try XCTUnwrap(reopened.begin(owner:"A"));defer {reopened.end()}
        XCTAssertEqual(restored.input.elevation,29);XCTAssertEqual(restored.lastShot?.id,second.id)
        XCTAssertTrue(restored.valid)
    }
    func testMissingHistoryRetainsDraftAndStaticReplayDoesNotMutateIt() async throws {
        let suite="v66-archive-missing-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer {defaults.removePersistentDomain(forName:suite)}
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {if FileManager.default.fileExists(atPath:root.path) {do {try FileManager.default.removeItem(at:root)} catch {XCTFail("Cleanup: \(error)")}}}
        let context=CurrentOwnerContext(defaults:defaults)
        let archive=SpatialPracticeArchive(defaults:defaults,root:root)
        _=archive.begin(owner:context.ownerKey)
        let history=shot(),record=R(board:[:],input:.init(elevation:73),lastShot:history)
        archive.save(record);try await settled(archive)
        let file=archive.historyURL(history.id),key=archive.draftKey
        archive.end()
        let vm=SpatialPracticeViewModel(defaults:defaults,ownerContext:context,archiveRoot:root)
        vm.setupScene();defer {vm.suspendTeachingActivity()}
        XCTAssertEqual(vm.record.lastShot?.id,history.id)
        vm.replay()
        XCTAssertFalse(vm.busy,"All-static replay must settle once without a frame action")
        XCTAssertTrue(vm.record.board.isEmpty);XCTAssertEqual(vm.input.elevation,73)
        XCTAssertEqual(vm.record.lastShot?.id,history.id)
        vm.suspendTeachingActivity()
        try FileManager.default.removeItem(at:file)
        var notice:String?;archive.onError={notice=$0}
        let loaded=try XCTUnwrap(archive.begin(owner:context.ownerKey));defer {archive.end()}
        XCTAssertNotNil(notice);XCTAssertNotNil(defaults.data(forKey:key+".unreadable"))
        XCTAssertTrue(loaded.board.isEmpty);XCTAssertEqual(loaded.input.elevation,73);XCTAssertNil(loaded.lastShot)
    }
    func testLatestInstanceOwnerAndEndRejectLateHistoryCommits() async throws {
        let suite="v66-archive-owner-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer {defaults.removePersistentDomain(forName:suite)}
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {if FileManager.default.fileExists(atPath:root.path) {do {try FileManager.default.removeItem(at:root)} catch {XCTFail("Cleanup: \(error)")}}}
        let old=SpatialPracticeArchive(defaults:defaults,root:root),new=SpatialPracticeArchive(defaults:defaults,root:root)
        _=old.begin(owner:"A")
        let large=shot(samples:90000),record=R(board:large.after,input:.init(),lastShot:large)
        old.save(record)
        _=new.begin(owner:"A")
        var latest=R(board:[:],input:.init(elevation:72));new.save(latest)
        for _ in 0..<100 {try await Task.sleep(for:.milliseconds(10))}
        old.save(record);old.end()
        let restored=try XCTUnwrap(new.begin(owner:"A"))
        XCTAssertTrue(restored.board.isEmpty);XCTAssertEqual(restored.input.elevation,72);XCTAssertNil(restored.lastShot)
        new.save(record);new.end() // the detached write may finish, but must not publish a reference
        _=new.begin(owner:"B");latest.input.elevation=30;new.save(latest)
        try await Task.sleep(for:.milliseconds(600))
        XCTAssertEqual(new.begin(owner:"B")?.input.elevation,30)
        XCTAssertNil(new.begin(owner:"A")?.lastShot)
        new.end()
    }

    func testNegativeHistoryTimeKeepsStableDraftAndOriginalFile() async throws {
        let suite="v66-archive-negative-time-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer {defaults.removePersistentDomain(forName:suite)}
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {if FileManager.default.fileExists(atPath:root.path) {do {try FileManager.default.removeItem(at:root)} catch {XCTFail("Cleanup: \(error)")}}}
        let archive=SpatialPracticeArchive(defaults:defaults,root:root)
        _=archive.begin(owner:"A");defer {archive.end()}
        let history=shot(),record=R(board:history.after,input:.init(elevation:32),lastShot:history)
        archive.save(record);try await settled(archive)
        let file=archive.historyURL(history.id),key=archive.draftKey
        let originalDraft=try XCTUnwrap(defaults.data(forKey:key))
        var object=try XCTUnwrap(PropertyListSerialization.propertyList(from:Data(contentsOf:file),format:nil) as? [String:Any])
        var paths=try XCTUnwrap(object["paths"] as? [String:[[String:Any]]])
        var samples=try XCTUnwrap(paths[PositionPlayBall.cueKey])
        samples[0]["time"] = -0.5;paths[PositionPlayBall.cueKey]=samples;object["paths"]=paths
        let malformed=try PropertyListSerialization.data(fromPropertyList:object,format:.binary,options:0)
        let decoded=try PropertyListDecoder().decode(R.Shot.self,from:malformed)
        XCTAssertFalse(R.validShot(decoded),"Sorted times alone must not admit a negative first sample")
        try malformed.write(to:file,options:.atomic)
        archive.end()
        var message:String?;archive.onError={message=$0}
        let restored=try XCTUnwrap(archive.begin(owner:"A"))
        XCTAssertEqual(restored.board,record.board);XCTAssertEqual(restored.input,record.input)
        XCTAssertNil(restored.lastShot);XCTAssertNotNil(message)
        XCTAssertEqual(defaults.data(forKey:key+".unreadable"),originalDraft)
        XCTAssertEqual(try Data(contentsOf:file),malformed)
    }
}
