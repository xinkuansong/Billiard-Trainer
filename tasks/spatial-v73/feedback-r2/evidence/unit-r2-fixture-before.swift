import XCTest
import SwiftData
import SceneKit
@testable import CuePhys

@MainActor
final class SpatialQuizIntegrationTests: XCTestCase {
    func testDemonstrationSeatsReferenceThirdPersonBeforeStrokeAndRestoresObservation() async throws {
        for mode in SpatialQuizMode.allCases {
            let suite="SpatialQuizDemoCamera."+UUID().uuidString
            let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
            defer { defaults.removePersistentDomain(forName:suite) }
            let limiter=AngleUsageLimiter(defaults:defaults,namespace:mode.kind,limit:15);limiter.isPremium=true
            let vm=SpatialQuizViewModel(mode:mode,limiter:limiter,settingsDefaults:defaults)
            let container=ModelContainerFactory.makeInMemoryContainer()
            vm.attach(context:container.mainContext)
            for _ in 0..<200 where vm.loading { try await Task.sleep(for:.milliseconds(20)) }
            XCTAssertFalse(vm.loading);vm.start(.init(playsStroke:false));vm.setupScene()
            let rig=try XCTUnwrap(vm.scene.cameraRig)
            rig.viewportSize=CGSize(width:874,height:402)
            let reference=try XCTUnwrap(vm.record?.current.source.reference)
            vm.updateInput { $0=reference };vm.strike()
            for _ in 0..<500 where vm.session?.activity != .idle { try await Task.sleep(for:.milliseconds(20)) }
            XCTAssertTrue(vm.canDemonstrate)
            let first=try XCTUnwrap(vm.record?.firstAnswers.first?.id)
            for view in [CameraRig.PlayerView.firstPerson,.thirdPerson] {
                XCTAssertTrue(vm.requestPlayerView(view,animated:false,resetThirdPerson:true))
                if view == .thirdPerson { rig.handlePinch(scale:1.4);rig.handleObservationPan(deltaX:0.3) }
                let previous=rig.trainingBookmark()
                vm.demonstrate()
                for _ in 0..<500 where vm.activeShot == nil && vm.busy { try await Task.sleep(for:.milliseconds(10)) }
                let shot=try XCTUnwrap(vm.activeShot,vm.message ?? "No demonstration stroke")
                // No renderer ticks are advanced here: this is the instant play()
                // schedules cue stroke, not a later settled animation frame.
                XCTAssertEqual(rig.twoViewMode,.thirdPerson)
                XCTAssertFalse(rig.isTransitioning,"Camera must be seated before cue stroke")
                let frame=try XCTUnwrap(rig.p01Snapshot)
                let cue=try XCTUnwrap(shot.before[ShotInput.cueBallName]).position.scene
                XCTAssertEqual(frame.shot.cue.x,cue.x,accuracy:1e-6)
                XCTAssertEqual(frame.shot.cue.z,cue.z,accuracy:1e-6)
                XCTAssertEqual(frame.shot.aim.x,shot.input.aim.x,accuracy:1e-6)
                XCTAssertEqual(frame.shot.aim.z,shot.input.aim.z,accuracy:1e-6)
                XCTAssertEqual(frame.shot.elevation,shot.input.radians,accuracy:1e-6)
                XCTAssertEqual(frame.state.distance,P01CameraMotion.State().distance,accuracy:1e-6)
                XCTAssertEqual(frame.state.height,P01CameraMotion.State().height,accuracy:1e-6)
                XCTAssertEqual(frame.state.observationYaw,0,accuracy:1e-6)
                XCTAssertNil(frame.state.thirdPersonZoomPitchOffset)
                vm.stopPlayback()
                let restored=rig.trainingBookmark()
                XCTAssertEqual(restored.mode,previous.mode)
                for (actual,expected) in zip(restored.pose,previous.pose) { XCTAssertEqual(actual,expected,accuracy:1e-5) }
                XCTAssertEqual(vm.record?.firstAnswers.first?.id,first)
                XCTAssertEqual(vm.record?.firstAnswers.count,1)
            }
            // Cancellation while solving must never later enter the reference view.
            XCTAssertTrue(vm.requestPlayerView(.firstPerson,animated:false))
            let previous=rig.trainingBookmark()
            vm.demonstrate();vm.stopPlayback()
            try await Task.sleep(for:.milliseconds(300))
            XCTAssertNil(vm.activeShot);XCTAssertEqual(vm.session?.activity,.idle)
            XCTAssertEqual(rig.trainingBookmark().pose,previous.pose)
            vm.suspendTeachingActivity()
        }
    }
    func testBothRealViewModelsClipOnlyTargetAndBuildAnswerIndependentCloseup() async throws {
        for mode in SpatialQuizMode.allCases {
            let suite="SpatialQuizGuides."+UUID().uuidString
            let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
            defer { defaults.removePersistentDomain(forName:suite) }
            let limiter=AngleUsageLimiter(defaults:defaults,namespace:mode.kind,limit:15);limiter.isPremium=true
            let vm=SpatialQuizViewModel(mode:mode,limiter:limiter,settingsDefaults:defaults)
            let container=ModelContainerFactory.makeInMemoryContainer()
            vm.attach(context:container.mainContext)
            for _ in 0..<200 where vm.loading { try await Task.sleep(for:.milliseconds(20)) }
            XCTAssertFalse(vm.loading);vm.start(.init());vm.setupScene()
            let cue=try XCTUnwrap(vm.scene.cueBallNode),target=try XCTUnwrap(vm.targetNode)
            let obstacle=try XCTUnwrap(vm.scene.allBallNodes["_8"]),y=vm.scene.surfaceY+BallPhysics.radius
            cue.position = .init(-0.7,y,0.2);target.position = .init(0.2,y,0.2);obstacle.position = .init(-0.2,y,0.2)
            vm.updateInput { $0.yaw=0;$0.elevation=45 }
            let line=try XCTUnwrap(vm.aimingLine)
            XCTAssertEqual(line.end.x,CGFloat(target.position.x-BallPhysics.radius),accuracy:1e-6)
            XCTAssertEqual(line.end.y,CGFloat(target.position.z),accuracy:1e-6)
            XCTAssertGreaterThan(line.end.x,CGFloat(obstacle.position.x+BallPhysics.radius),"Black eight must not clip the guide")
            XCTAssertNotNil(vm.scene.rootNode.childNode(withName:"freeAimPreview",recursively:true))
            let closeup=try XCTUnwrap(vm.closeupSnapshot)
            XCTAssertEqual(closeup.aimLine,line);XCTAssertNil(closeup.ghost);XCTAssertNil(closeup.potLine)
            XCTAssertNil(closeup.idealLine);XCTAssertNil(closeup.contactMarker)
            vm.updateInput { $0.yaw = .pi/4 }
            let miss=try XCTUnwrap(vm.aimingLine)
            let rail=AngleSceneCalculator.rayToInnerRail(from:cue.position,dir:vm.input.aim)
            XCTAssertEqual(miss.end.x,CGFloat(rail.x),accuracy:1e-6)
            XCTAssertEqual(miss.end.y,CGFloat(rail.z),accuracy:1e-6)
            XCTAssertNil(vm.closeupSnapshot)
            vm.suspendTeachingActivity()
        }
    }
    func testRealViewModelCancellationResumesFrozenAttemptAndReleasesScene() async throws {
        for mode in SpatialQuizMode.allCases {
            let suite="SpatialQuizVM."+UUID().uuidString,container=ModelContainerFactory.makeInMemoryContainer()
            let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
            defer { defaults.removePersistentDomain(forName:suite) }
            let limiter=AngleUsageLimiter(defaults:defaults,namespace:mode.kind,limit:15);limiter.isPremium=true
            var vm:SpatialQuizViewModel?=SpatialQuizViewModel(mode:mode,limiter:limiter,settingsDefaults:defaults)
            weak var released=vm
            vm?.attach(context:container.mainContext)
            for _ in 0..<200 where vm?.loading == true { try await Task.sleep(for:.milliseconds(20)) }
            XCTAssertFalse(try XCTUnwrap(vm).loading)
            vm?.start(.init(playsStroke:false));vm?.setupScene()
            let reference=try XCTUnwrap(vm?.record?.current.source.reference)
            vm?.updateInput { $0=reference }
            XCTAssertTrue(try XCTUnwrap(vm).cueAccessible)
            vm?.strike();let pending=try XCTUnwrap(vm?.record?.pending)
            vm?.suspendTeachingActivity()
            try await Task.sleep(for:.milliseconds(100))
            XCTAssertEqual(vm?.record?.pending?.id,pending.id)
            XCTAssertEqual(vm?.record?.firstAnswers.count,0)
            XCTAssertEqual(vm?.session?.activity,.unconfirmed)
            XCTAssertTrue(try XCTUnwrap(vm).scene.isPaused)
            vm?.resumeTeachingActivity();vm?.strike()
            for _ in 0..<500 where vm?.session?.activity != .idle { try await Task.sleep(for:.milliseconds(20)) }
            XCTAssertEqual(vm?.record?.firstAnswers.count,1)
            XCTAssertEqual(vm?.record?.latestShot?.id,pending.id)
            XCTAssertEqual(vm?.record?.latestShot?.outcome.succeeded,true)
            vm?.suspendTeachingActivity();vm=nil
            for _ in 0..<100 where released != nil { try await Task.sleep(for:.milliseconds(20)) }
            XCTAssertNil(released,"Scene callbacks and completed tasks must not retain the page VM")
        }
    }
    enum Injected: Error { case save }
    private func record(_ mode: SpatialQuizMode, owner: String = "guest:spatial-b4", answered: Bool = true, date: Date = Date()) throws -> SpatialQuizRecord {
        let bank = try SpatialQuizBank.load(mode)
        var value = SpatialQuizRecord(owner: owner, mode: mode, configuration: .init(), bank: bank,
            questions: Array(bank.questions.prefix(15)), now: date)
        if answered {
            let question = value.current
            let pending = SpatialQuizRecord.Pending(id: UUID(), questionID: question.id,
                input: question.source.reference, submittedAt: date, premium: true)
            value.pending = pending; value.draft = pending.input; value.phase = .calculating
            let result = SpatialQuizPhysics.solve(board: question.source.board, input: pending.input)
            XCTAssertTrue(result.outcome.succeeded)
            value.accept(try SpatialQuizShot.make(result, pending: pending, question: question))
        }
        value.activeSeconds = 125
        return value
    }
    private func row(_ record: SpatialQuizRecord, in context: ModelContext) throws -> TrainingSession {
        let row = TrainingSession(kind: record.mode.kind, ownerKey: record.ownerKey)
        row.id=record.id; row.date=record.startedAt; row.sourceId=record.mode.kind
        row.sourceKind=record.mode.kind; row.sourcePayloadVersion=SpatialQuizRecord.version
        row.sourceTitleSnapshot=record.displayName; row.sourcePayloadSnapshot=try record.encodedPayload()
        row.totalDurationMinutes=Int(record.activeSeconds/60)
        context.insert(row); return row
    }
    private func changed(_ record: SpatialQuizRecord, fields: [String: Any]) throws -> SpatialQuizRecord {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String:Any])
        fields.forEach { json[$0.key]=$0.value }
        return try JSONDecoder().decode(SpatialQuizRecord.self, from: JSONSerialization.data(withJSONObject: json))
    }
    func testHistoryMonthlyOverviewExcludesDraftsAndKeepsTwoKindsSeparate() throws {
        let container=ModelContainerFactory.makeInMemoryContainer(), context=container.mainContext
        var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!
        let day=calendar.date(from:DateComponents(year:2026,month:11,day:15))!
        let masse=try record(.masse,date:day),jump=try record(.jump,date:day.addingTimeInterval(86400))
        _=try row(masse,in:context);_=try row(jump,in:context)
        _=try row(record(.masse,answered:false,date:day.addingTimeInterval(172800)),in:context)
        let bad=TrainingSession(kind:TrainingSessionKind.jumpPractice,ownerKey:masse.ownerKey)
        bad.sourcePayloadSnapshot=Data([1,2,3]);bad.date=day.addingTimeInterval(259200);bad.totalDurationMinutes=99;context.insert(bad)
        let rows=try context.fetch(FetchDescriptor<TrainingSession>())
        let history=HistoryViewModel.assembleSpatialSessions(sessions:rows)
        XCTAssertEqual(history.records.count,2);XCTAssertEqual(history.unreadableCount,1)
        XCTAssertEqual(Set(history.records.map(\.mode)),Set(SpatialQuizMode.allCases))
        XCTAssertEqual(history.records.map(\.totalCount),[1,1]);XCTAssertEqual(history.records.map(\.successCount),[1,1])
        XCTAssertTrue(history.records.allSatisfy { $0.historyDetail.contains("成功1题") })
        let summary=TrainingGoalMetrics.monthlyOverview(rows,at:day,calendar:calendar)
        XCTAssertEqual(summary.trainingDays,2);XCTAssertEqual(summary.durationMinutes,4);XCTAssertEqual(summary.longestStreak,2)
        XCTAssertTrue(TrainingGoalMetrics.goalCounting(rows).isEmpty)
        XCTAssertTrue(rows.allSatisfy { !TrainingSessionKind.countsTowardAccuracy($0.kind) })
        let vm=HistoryViewModel();vm.spatialSessions=history.records;vm.selectedDate=day
        XCTAssertEqual(vm.selectedDateItems.count,1);XCTAssertTrue(vm.hasAnySessions)
        XCTAssertEqual(vm.selectedDateItems.first?.id,"massePractice_"+masse.id.uuidString)
    }
    func testOldRulingAndBankPreserveHistoricalFirstAnswerButCannotResume() throws {
        for mode in SpatialQuizMode.allCases {
            var old=try changed(record(mode),fields:["judgementVersion":"spatial-quiz-v1","bankFingerprint":"old-bank"])
            let first=try XCTUnwrap(old.firstAnswers.first)
            // Compatibility fixture: an older rubric rejected this now-successful stroke.
            old.firstAnswers=[.init(id:first.id,questionID:first.questionID,input:first.input,facts:first.facts,
                outcome:.failure(.obstacleContact),receipt:first.receipt)]
            old.status = .completed
            let restored=try SpatialQuizRecord.decodePayload(old.encodedPayload())
            XCTAssertFalse(restored.isCurrentCompatible);XCTAssertEqual(restored.successCount,0)
            XCTAssertEqual(restored.firstAnswers.first?.facts,first.facts)
            XCTAssertTrue(SpatialQuizJudgement.evaluate(first.facts).succeeded)
            let container=ModelContainerFactory.makeInMemoryContainer()
            let history=HistoryViewModel.assembleSpatialSessions(sessions:[try row(restored,in:container.mainContext)])
            XCTAssertEqual(history.records.count,1);XCTAssertEqual(history.records.first?.successCount,0)
            let oldGeometry=try changed(restored,fields:["geometryVersion":"historical-geometry"])
            XCTAssertNoThrow(try SpatialQuizRecord.decodePayload(oldGeometry.encodedPayload()))
            var future=old;future.version=99;XCTAssertThrowsError(try future.encodedPayload())
        }
    }
    func testResumeSkipsUnsupportedRowsWithoutDeletingOrMaskingCompatibleSession() throws {
        let suite="SpatialB4."+UUID().uuidString
        let defaults=UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let owner=CurrentOwnerContext(defaults:defaults),container=ModelContainerFactory.makeInMemoryContainer()
        let context=container.mainContext,repo=LocalSpatialQuizRepository(context:context,owner:owner,enqueue:{_,_ in})
        for mode in SpatialQuizMode.allCases {
            let good=try record(mode,owner:owner.ownerKey)
            try repo.save(good)
            let old=try changed(record(mode,owner:owner.ownerKey),fields:["judgementVersion":"old-rule"])
            _=try row(old,in:context)
            let incompatible=try changed(record(mode,owner:owner.ownerKey),fields:["bankFingerprint":"old-bank"])
            _=try row(incompatible,in:context)
            let bad=TrainingSession(kind:mode.kind,ownerKey:owner.ownerKey);bad.sourceId=mode.kind
            let bytes=Data([0x53,0x51,0x39,0x39,1,2]);bad.sourcePayloadSnapshot=bytes;context.insert(bad);try context.save()
            let limiter=AngleUsageLimiter(defaults:defaults,namespace:"b4-"+mode.rawValue,limit:15)
            let session=SpatialQuizSession(mode:mode,repository:repo,limiter:limiter)
            try session.restore(bank:SpatialQuizBank.load(mode))
            XCTAssertEqual(session.record?.id,good.id);XCTAssertEqual(repo.unreadableCount,1);XCTAssertEqual(repo.incompatibleCount,2)
            XCTAssertNotNil(session.message);XCTAssertEqual(bad.sourcePayloadSnapshot,bytes)
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<TrainingSession>()).count,8)
    }
    func testOwnerTransferRewritesBothPayloadsAndRollsBackAllOnSaveFailure() throws {
        let container=ModelContainerFactory.makeInMemoryContainer(),context=container.mainContext
        let source="guest:spatial-b4",destination="account:spatial-b4"
        let rows=try SpatialQuizMode.allCases.map { try row(record($0,owner:source),in:context) }
        let unknown=TrainingSession(kind:"future-spatial-kind",ownerKey:source)
        unknown.sourcePayloadSnapshot=Data([9,8,7]);context.insert(unknown)
        let legacy=TrainingSession(kind:TrainingSessionKind.tool,ownerKey:source);context.insert(legacy);try context.save()
        let snapshots=rows.map(\.sourcePayloadSnapshot)
        XCTAssertThrowsError(try OwnerTransferService(context:context,saveAction:{_ in throw Injected.save}).transfer(from:source,to:destination))
        for (row,data) in zip(rows,snapshots) { XCTAssertEqual(row.ownerKey,source);XCTAssertEqual(row.sourcePayloadSnapshot,data) }
        XCTAssertEqual(unknown.ownerKey,source);XCTAssertEqual(legacy.ownerKey,source)
        XCTAssertEqual(try OwnerTransferService(context:context).transfer(from:source,to:destination).sessions,4)
        for row in rows {
            let saved=try SpatialQuizRecord.decodePayload(XCTUnwrap(row.sourcePayloadSnapshot))
            XCTAssertEqual(saved.ownerKey,destination);XCTAssertEqual(row.ownerKey,destination);XCTAssertEqual(saved.id,row.id)
        }
        XCTAssertEqual(unknown.sourcePayloadSnapshot,Data([9,8,7]));XCTAssertEqual(legacy.kind,TrainingSessionKind.tool)
        XCTAssertEqual(try OwnerTransferService(context:context).transfer(from:source,to:destination).sessions,0)
    }
    func testMalformedKnownPayloadAbortsOwnerTransferAndPreservesBytes() throws {
        let container=ModelContainerFactory.makeInMemoryContainer(),context=container.mainContext
        let good=try row(record(.masse),in:context),bad=TrainingSession(kind:TrainingSessionKind.jumpPractice,ownerKey:good.ownerKey)
        bad.sourcePayloadSnapshot=Data([1,2,3]);context.insert(bad);try context.save()
        let source=good.ownerKey,bytes=good.sourcePayloadSnapshot
        XCTAssertThrowsError(try OwnerTransferService(context:context).transfer(from:source,to:"account:b4"))
        XCTAssertEqual(good.ownerKey,source);XCTAssertEqual(good.sourcePayloadSnapshot,bytes)
        XCTAssertEqual(bad.ownerKey,source);XCTAssertEqual(bad.sourcePayloadSnapshot,Data([1,2,3]))
    }
    func testRealDTOBase64RoundtripAndExportForIsolatedHTTPDatabase() throws {
        let container=ModelContainerFactory.makeInMemoryContainer(),context=container.mainContext
        var dtos:[TrainingSessionDTO]=[]
        for mode in SpatialQuizMode.allCases {
            let r=try record(mode),stored=try row(r,in:context),dto=TrainingSessionDTO(from:stored)
            let bytes=try JSONEncoder().encode(dto),roundtrip=try JSONDecoder().decode(TrainingSessionDTO.self,from:bytes)
            XCTAssertEqual(roundtrip.kind,mode.kind);XCTAssertEqual(roundtrip.sourcePayloadSnapshot,stored.sourcePayloadSnapshot)
            XCTAssertEqual(try SpatialQuizRecord.decodePayload(XCTUnwrap(roundtrip.sourcePayloadSnapshot)).firstAnswers.first?.id,r.firstAnswers.first?.id)
            XCTAssertLessThan(bytes.count,2*1024*1024);dtos.append(dto)
            print("SPATIAL_B4_DTO \(mode.rawValue) payload=\(stored.sourcePayloadSnapshot!.count) json=\(bytes.count)")
        }
        let unknown=TrainingSession(kind:"future-spatial-kind",ownerKey:"guest:spatial-b4")
        unknown.sourcePayloadSnapshot=Data([0,255,1,2,3]);dtos.append(TrainingSessionDTO(from:unknown))
        let encoder=JSONEncoder();encoder.dateEncodingStrategy = .iso8601
        let a=XCTAttachment(data:try encoder.encode(dtos),uniformTypeIdentifier:"public.json")
        a.name="spatial-b4-real-dtos";a.lifetime = .keepAlways;add(a)
    }
    private actor SyncFixture: SyncBackend, SyncRestoreBackend {
        var rows: [String:TrainingSessionDTO] = [:]
        var failNextUpload = true
        var failNextDelete = true
        func uploadSession(_ dto:TrainingSessionDTO, accountID:String) async throws {
            if failNextUpload { failNextUpload=false;throw URLError(.notConnectedToInternet) }
            rows[dto.clientId]=dto
        }
        func uploadAngleTest(_ dto:AngleTestDTO, accountID:String) async throws { XCTFail("Spatial quizzes must not upload AngleTest scores") }
        func deleteSession(clientId:String, accountID:String) async throws {
            if failNextDelete { failNextDelete=false;throw URLError(.networkConnectionLost) }
            rows.removeValue(forKey:clientId)
        }
        func fetchSessions(after:Date?, accountID:String) async throws -> [SyncedRecord<TrainingSessionDTO>] {
            try rows.values.map { dto in
                var json = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(dto)) as? [String:Any])
                json["updatedAt"]=Date().timeIntervalSinceReferenceDate
                return try JSONDecoder().decode(SyncedRecord<TrainingSessionDTO>.self,from:JSONSerialization.data(withJSONObject:json))
            }
        }
        func fetchAngleTests(after:Date?, accountID:String) async throws -> [SyncedRecord<AngleTestDTO>] { [] }
    }
    private struct AuthFixture: AuthSessionBackend, AuthCredentialStore {
        var hasRefreshToken:Bool { false }
        func clearAll() {}
        func logout() async {}
        func fetchProfile() async throws -> UserDTO { throw AppError.authRequired }
    }
    func testExistingQueueRetryRestoreAndPendingDeletePreserveBothKindsAndUnknownPayload() async throws {
        let suite="SpatialB4Sync."+UUID().uuidString,container=ModelContainerFactory.makeInMemoryContainer()
        let defaults=UserDefaults(suiteName:suite)!,context=container.mainContext
        let user="spatial-b4-user",owner=CurrentOwnerContext.shared
        let queue=SyncQueueManager.shared,restore=SyncRestoreService.shared,backend=SyncFixture()
        let originalDefaults=restore.defaults
        owner.useAccount(userID:user);queue.configure(context:context);restore.configure(context:context)
        queue.backend=backend;restore.backend=backend;restore.defaults=defaults
        defer {
            queue.backend=LiveSyncBackend();restore.backend=LiveSyncRestoreBackend();restore.defaults=originalDefaults
            owner.useGuest();defaults.removePersistentDomain(forName:suite)
        }
        let auth=AuthState(backend:AuthFixture(),credentials:AuthFixture(),defaults:defaults,ownerContext:owner)
        auth.login(user:AppUser(id:user,provider:.apple));auth.setCloudSyncEnabled(true)
        let repo=LocalSpatialQuizRepository(context:context)
        for mode in SpatialQuizMode.allCases { try repo.save(record(mode,owner:owner.ownerKey)) }
        let unknown=TrainingSession(kind:"future-spatial-kind",ownerKey:owner.ownerKey)
        unknown.sourcePayloadSnapshot=Data([9,0,255]);context.insert(unknown);try context.save()
        queue.enqueue(entityType:"TrainingSession",entityId:unknown.id,operation:"update",ownerKey:owner.ownerKey)
        let before=try context.fetch(FetchDescriptor<TrainingSession>())
        let bytes=Dictionary(uniqueKeysWithValues:before.map { ($0.id,$0.sourcePayloadSnapshot) })
        let first=await queue.processQueue(authState:auth)
        XCTAssertGreaterThan(first.failedItems,0);XCTAssertGreaterThan(queue.pendingCount(),0)
        let retried=await queue.processQueue(authState:auth)
        XCTAssertEqual(retried.failedItems,0);XCTAssertEqual(queue.pendingCount(),0)
        before.forEach(context.delete);try context.save()
        let restored=await restore.restore(userId:user,mode:.full)
        XCTAssertEqual(restored.insertedSessions,3);XCTAssertFalse(restored.hasFailures)
        let after=try context.fetch(FetchDescriptor<TrainingSession>())
        for row in after { XCTAssertEqual(row.sourcePayloadSnapshot,bytes[row.id]!) }
        XCTAssertEqual(HistoryViewModel.assembleSpatialSessions(sessions:after).records.count,2)
        let history=LocalTrainingSessionRepository(context:context)
        for row in after where row.kind != "future-spatial-kind" { try await history.delete(row) }
        let failedDelete=await queue.processQueue(authState:auth)
        XCTAssertGreaterThan(failedDelete.failedItems,0);XCTAssertGreaterThan(queue.pendingCount(),0)
        let blockedRestore=await restore.restore(userId:user,mode:.full)
        XCTAssertEqual(blockedRestore.insertedSessions,0,"A pending deletion must not resurrect from the server")
        let deletionRetry=await queue.processQueue(authState:auth)
        XCTAssertEqual(deletionRetry.failedItems,0);XCTAssertEqual(queue.pendingCount(),0)
        let finalRestore=await restore.restore(userId:user,mode:.full)
        XCTAssertEqual(finalRestore.insertedSessions,0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TrainingSession>()).map(\.kind),["future-spatial-kind"])
    }

}
