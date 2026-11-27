import XCTest
import SceneKit
@testable import CuePhys

final class SpatialQuizBankTests: XCTestCase {
    func testExcludedCandidateFactsRemainAuditable() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
        let url=root.appendingPathComponent("tasks/spatial-v73/evidence/B5-qualification/jump-excluded-inputs.json")
        let questions=try JSONDecoder().decode([SpatialQuizQuestion].self,from:Data(contentsOf:url))
        var rows:[[String:Any]]=[]
        for q in questions {
            let result=SpatialQuizPhysics.solve(board:q.board,input:q.reference)
            XCTAssertFalse(result.outcome.succeeded,q.id)
            rows.append(["id":q.id,"outcome":String(describing:result.outcome),
                "facts":try JSONSerialization.jsonObject(with:JSONEncoder().encode(result.facts)),
                "pocketed":result.prediction.pocketedBalls,
                "final":result.prediction.finalPositions.mapValues { [$0.x,$0.y,$0.z] }])
        }
        let data=try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys])
        let a=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        a.name="b5-excluded-physical-facts";a.lifetime = .keepAlways;add(a)
    }
    @MainActor func testAnswerPagesRejectGlobalPredictionPreferencesAndKeepSeparateDisplays() throws {
        let suite="SpatialQuizPreferences."+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
        defer { defaults.removePersistentDomain(forName:suite) }
        let store=TablePreferencesStore(defaults:defaults)
        store.apply(.transparency,value:0.5)
        store.apply(.transparency,value:0.2,to:.massePractice)
        store.apply(.transparency,value:0.8,to:.jumpPractice)
        for page in [TablePreferencePage.massePractice,.jumpPractice] {
            XCTAssertTrue(store.snapshot(for:page).enabled(.closeup),"First use inherits enabled closeup")
        }
        store.apply(.closeup,value:0,to:.massePractice)
        XCTAssertFalse(store.snapshot(for:.massePractice).enabled(.closeup))
        XCTAssertTrue(store.snapshot(for:.jumpPractice).enabled(.closeup))
        for field in [TablePreferenceField.view3D,.trajectory,.shows3DTrajectory,.separation] {
            store.apply(field,value:1)
            for page in [TablePreferencePage.massePractice,.jumpPractice] {
                store.apply(field,value:1,to:page)
                XCTAssertNil(store.snapshot(for:page).values[field])
            }
        }
        store.apply(.grid,value:1,to:.massePractice)
        let restored=TablePreferencesStore(defaults:defaults)
        XCTAssertEqual(restored.snapshot(for:.massePractice)[.transparency],0.2)
        XCTAssertEqual(restored.snapshot(for:.jumpPractice)[.transparency],0.8)
        XCTAssertEqual(restored.snapshot(for:.masseJump)[.transparency],0.5)
        XCTAssertTrue(restored.snapshot(for:.massePractice).enabled(.grid))
        XCTAssertFalse(restored.snapshot(for:.jumpPractice).enabled(.grid))
        XCTAssertEqual(TrainingProject.masse.page2D,TrainingProject.masse.page3D)
        XCTAssertEqual(TrainingProject.jump.page2D,TrainingProject.jump.page3D)
    }
    func testFullMasseReferenceAudit() throws { try auditAllReferences(.masse) }
    func testFullJumpReferenceAudit() throws { try auditAllReferences(.jump) }

    private func auditAllReferences(_ mode: SpatialQuizMode) throws {
        executionTimeAllowance = 3600
        let model = try XCTUnwrap(TableModelLoader.loadTable())
        let profile = CueStick(modelCueStickNode: try XCTUnwrap(model.cueStickNode)).clearanceProfile
        let bank = try SpatialQuizBank.load(mode)
        var rows: [[String: Any]] = []
        var passed = 0, failed = 0, unconfirmed = 0
        let began = ProcessInfo.processInfo.systemUptime
        for (index, question) in bank.questions.enumerated() {
            autoreleasepool {
                let start = ProcessInfo.processInfo.systemUptime
                let accessible = question.referenceAccessible(profile: profile)
                let result = SpatialQuizPhysics.solve(board: question.board, input: question.reference)
                let complete = result.facts.complete && result.facts.issues.isEmpty
                let accepted = accessible && complete && result.outcome.succeeded
                if accepted { passed += 1 } else if !complete { unconfirmed += 1 } else { failed += 1 }
                rows.append(["id": question.id, "sourceLayoutID": question.sourceLayoutID,
                    "targetNumber": question.targetNumber, "accessible": accessible,
                    "complete": complete, "accepted": accepted,
                    "outcome": String(describing: result.outcome), "issues": result.facts.issues,
                    "duration": result.facts.duration,
                    "technique": (try? JSONSerialization.jsonObject(with:JSONEncoder().encode(result.facts.technique))) ?? NSNull(),
                    "solveSeconds": ProcessInfo.processInfo.systemUptime - start])
            }
            if (index + 1) % 100 == 0 {
                print("SPATIAL_B5_PROGRESS \(mode.rawValue) \(index+1)/\(bank.questions.count) passed=\(passed) failed=\(failed) unconfirmed=\(unconfirmed)")
            }
        }
        let report: [String: Any] = ["mode": mode.rawValue, "fingerprint": bank.fingerprint,
            "rule": SpatialQuizJudgement.version, "planned": bank.questions.count,
            "completed": rows.count, "passed": passed, "failed": failed, "unconfirmed": unconfirmed,
            "elapsedSeconds": ProcessInfo.processInfo.systemUptime - began,
            "profileSamples": profile.count, "rows": rows]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "spatial-b5-full-\(mode.rawValue)"; attachment.lifetime = .keepAlways; add(attachment)
        print("SPATIAL_B5_SUMMARY \(mode.rawValue) planned=\(bank.questions.count) completed=\(rows.count) passed=\(passed) failed=\(failed) unconfirmed=\(unconfirmed)")
        XCTAssertEqual(passed, bank.questions.count, "See per-reference audit; never silently drop failed candidates")
    }
    func testBothResourcesValidateAllFieldsAndFourteenBallIdentities() throws {
        for mode in SpatialQuizMode.allCases {
            let bank = try SpatialQuizBank.load(mode)
            XCTAssertGreaterThanOrEqual(bank.questions.count, 20)
            XCTAssertEqual(Set(bank.questions.map(\.targetNumber)), Set((1...15).filter { $0 != 8 }))
            XCTAssertEqual(Set(bank.questions.map { $0.board.targetName }), Set((1...15).filter { $0 != 8 }.map { "_\($0)" }))
            let selected = try bank.draw(count: 15, filter: .init())
            XCTAssertEqual(Set(selected.map(\.id)).count, 15)
            let next = try bank.draw(count: 15, filter: .init(), excluding: Set(selected.map(\.id)))
            XCTAssertTrue(Set(selected.map(\.id)).isDisjoint(with: next.map(\.id)))
            XCTAssertThrowsError(try bank.draw(count: 15, filter: .init(distanceBin: 999)))
            XCTAssertThrowsError(try bank.draw(count: bank.questions.count+1, filter: .init()))
        }
        let a = try SpatialQuizBank.load(.masse), b = try SpatialQuizBank.load(.jump)
        XCTAssertFalse(Set(a.questions.map(\.sourceLayoutID)).isDisjoint(with: b.questions.map(\.sourceLayoutID)))
        XCTAssertNotEqual(a.fingerprint, b.fingerprint)
    }
    func testMissingDamagedAndWrongModePackagesNeverFallback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try SpatialQuizBank.load(.jump, root: root))
        let source = try XCTUnwrap(Bundle.main.resourceURL?.appendingPathComponent("SpatialQuizBank"))
        try FileManager.default.copyItem(at: source.appendingPathComponent("masse-manifest.json"), to: root.appendingPathComponent("jump-manifest.json"))
        XCTAssertThrowsError(try SpatialQuizBank.load(.jump, root: root))
        try FileManager.default.copyItem(at: source.appendingPathComponent("masse-manifest.json"), to: root.appendingPathComponent("masse-manifest.json"))
        try Data([0,1,2]).write(to: root.appendingPathComponent("masse.json.gz"))
        XCTAssertThrowsError(try SpatialQuizBank.load(.masse, root: root))
        try Data(contentsOf:source.appendingPathComponent("masse.json.gz")).write(to:root.appendingPathComponent("masse.json.gz"))
        var manifest=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:source.appendingPathComponent("masse-manifest.json"))) as? [String:Any])
        let originalJudgement = manifest["judgement"]
        manifest["judgement"] = "unverified-rule"
        try JSONSerialization.data(withJSONObject:manifest).write(to:root.appendingPathComponent("masse-manifest.json"))
        XCTAssertThrowsError(try SpatialQuizBank.load(.masse,root:root),"A prior or unknown rule cannot label the current bank")
        manifest["judgement"] = originalJudgement
        manifest.removeValue(forKey:"verification")
        try JSONSerialization.data(withJSONObject:manifest).write(to:root.appendingPathComponent("masse-manifest.json"))
        XCTAssertThrowsError(try SpatialQuizBank.load(.masse,root:root),"An unaudited package must never become a formal bank")
    }
    func testStratifiedReferencesUseCurrentSpacePhysicsAndMeasuredCue() throws {
        let model = try XCTUnwrap(TableModelLoader.loadTable())
        let profile = CueStick(modelCueStickNode: try XCTUnwrap(model.cueStickNode)).clearanceProfile
        XCTAssertFalse(profile.isEmpty)
        for mode in SpatialQuizMode.allCases {
            let bank = try SpatialQuizBank.load(mode)
            var selected: [SpatialQuizQuestion] = []
            func add(_ question: SpatialQuizQuestion?) {
                if let question, !selected.contains(where: { $0.id == question.id }) { selected.append(question) }
            }
            add(bank.questions.first)
            for number in (1...15).filter({ $0 != 8 }) { add(bank.questions.first { $0.targetNumber == number }) }
            for value in bank.manifest.distanceBins { add(bank.questions.first { $0.distanceBin == value }) }
            for value in bank.manifest.sValues { add(bank.questions.first { $0.s == value }) }
            for value in bank.manifest.qValues { add(bank.questions.first { $0.q == value }) }
            for side in [-1,0,1] { add(bank.questions.first { $0.side == side }) }
            // Add both near-rail and central cue positions, then spaced source samples.
            let nearRail = bank.questions.sorted { max(abs($0.cue.x)/1.27,abs($0.cue.z)/0.635) > max(abs($1.cue.x)/1.27,abs($1.cue.z)/0.635) }
            add(nearRail.first); add(nearRail.last)
            for index in stride(from: 0, to: bank.questions.count, by: max(1,bank.questions.count/24)) { add(bank.questions[index]) }
            XCTAssertGreaterThanOrEqual(selected.count, 20)
            for question in selected {
                try autoreleasepool {
                    XCTAssertTrue(question.referenceAccessible(profile: profile), "inaccessible \(question.id)")
                    let result = SpatialQuizPhysics.solve(board: question.board, input: question.reference)
                    print("SPATIAL_B1 technique=\(String(describing:result.facts.technique)) \(question.id) number=\(question.targetNumber) outcome=\(result.outcome)")
                    XCTAssertTrue(result.outcome.succeeded, "\(question.id): \(result.outcome)")
                    XCTAssertTrue(result.facts.issues.isEmpty, "\(question.id): \(result.facts.issues)")
                    XCTAssertEqual(Set(try XCTUnwrap(result.prediction.recorder).framesByBallName.keys), Set(question.board.roles.keys))
                }
            }
            print("SPATIAL_B1_SUMMARY \(mode.rawValue) references=\(selected.count) fingerprint=\(bank.fingerprint)")
        }
    }
}

extension SpatialQuizBankTests {
    func testEdgeJumpReferencesUseNearestTrajectoryPoint() throws {
        let bank = try SpatialQuizBank.load(.jump)
        for id in ["target-110-m059-d7","target-154-m059-d5","target-1210-m132-d6"] {
            let question = try XCTUnwrap(bank.questions.first { $0.sourceLayoutID == id })
            let result = SpatialQuizPhysics.solve(board:question.board,input:question.reference)
            let proof = try XCTUnwrap(result.facts.technique)
            XCTAssertLessThan(proof.chordObstacleClearance,-0.001)
            XCTAssertTrue(proof.jumpedOverObstacle)
            XCTAssertTrue(result.outcome.succeeded,"\(id): \(result.outcome)")
        }
    }
    func testNewKickExclusionsKeepPhysicalFactsAndFailCurrentRule() throws {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
        let input = root.appendingPathComponent("tasks/spatial-v73/feedback-r3/kick-excluded-inputs.json")
        let questions = try JSONDecoder().decode([SpatialQuizQuestion].self,from:Data(contentsOf:input))
        XCTAssertEqual(questions.count,4)
        var rows:[[String:Any]] = []
        for question in questions {
            let result = SpatialQuizPhysics.solve(board:question.board,input:question.reference)
            XCTAssertEqual(result.outcome,.failure(.cushionBeforeTarget),question.id)
            rows.append(["id":question.id,"facts":try JSONSerialization.jsonObject(with:JSONEncoder().encode(result.facts))])
        }
        let attachment = XCTAttachment(data:try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]),
            uniformTypeIdentifier:"public.json")
        attachment.name = "v3-kick-exclusion-facts";attachment.lifetime = .keepAlways;add(attachment)
    }
}
