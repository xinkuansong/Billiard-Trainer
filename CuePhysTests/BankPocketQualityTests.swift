import XCTest
import SceneKit
@testable import QiuJi

final class BankPocketQualityTests: XCTestCase {
    func test_countsOnlyTargetPocketImpactsBeforeCapture() {
        let target = ShotInput.targetBallName, cue = ShotInput.cueBallName
        let events: [ShotEvent] = [
            .init(time: 0, kind: .ballCushion(ball: target), cushionIndex: 0),
            .init(time: 1, kind: .ballCushion(ball: cue), cushionIndex: 7),
            .init(time: 2, kind: .ballCushion(ball: target), cushionIndex: 6),
            .init(time: 3, kind: .ballCushion(ball: target), cushionIndex: 31),
            .init(time: 4, kind: .pocket(ball: target, pocketId: "pocket_0")),
            .init(time: 5, kind: .ballCushion(ball: target), cushionIndex: 8)
        ]
        XCTAssertEqual(ShotPredictor.bankPocketContactCount(events: events), 2)
    }

    /// Exact old/new production search comparison. The first layout is an approximate
    /// reconstruction of the screenshot, NOT recovered user coordinates.
    func test_realSearchQualityAndRailSequenceCatalog() throws {
        let y: Float = 0.8
        func p(_ x: Float, _ z: Float) -> SCNVector3 { .init(x, y + BallPhysics.radius, z) }
        let cases: [(String, SCNVector3, SCNVector3, Int, Float)] = [
            ("screenshot-approx", p(0,-0.25), p(-0.28,0.22), 0, 2.38),
            ("approx-neighbor-x", p(0,-0.25), p(-0.30,0.22), 0, 2.38),
            ("approx-neighbor-z", p(0,-0.25), p(-0.28,0.24), 0, 2.38),
            ("approx-mirror-x", p(0,-0.25), p(0.28,0.22), 1, 2.38),
            ("approx-mirror-z", p(0,0.25), p(-0.28,-0.22), 2, 2.38),
            ("typical", p(-0.5,-0.2), p(0.1,0.1), 1, 3.6),
            ("middle", p(-0.5,-0.2), p(0.4,0.25), 4, 3.6),
            ("long", p(-0.9,-0.4), p(0.6,0.3), 0, 4.5)
        ]
        var rows: [[String: Any]] = []
        var improved = 0, oldValid = 0, newValid = 0, clean = 0
        func details(_ pred: ShotPrediction) -> [String: Any] {
            let route = BankKickRoute.measured(pred, kick: false)
            return ["valid": BankKickValidity.bank(pred),
                "jaw": ShotPredictor.bankPocketContactCount(events: pred.events),
                "rails": route?.rails.map { $0.label } ?? [],
                "offset": pred.aimOffsetUsed ?? 0,
                "path": (pred.recorder?.framesByBallName[ShotInput.targetBallName] ?? [])
                    .filter { $0.time <= (pred.events.first { if case .pocket(let ball, _) = $0.kind { return ball == ShotInput.targetBallName }; return false }?.time ?? 0) }
                    .map { [$0.time,$0.position.x,$0.position.z] },
                "events": pred.events.map { ["time":$0.time,"kind":String(describing:$0.kind),"index":$0.cushionIndex ?? -1] as [String:Any] }]
        }
        for (name, cue, obj, pocket, speed) in cases {
            var candidates: [[String: Any]] = []
            let start = ProcessInfo.processInfo.systemUptime
            for spin: Float in [0,-0.3,0.3] {
                for rails in BankShotCalculator.candidateRailSequences(maxCushions: 3) {
                    let input = ShotInput(cueBall: cue, targetBall: obj, pocketIndex: pocket,
                        velocity: speed, spinX: spin, spinY: 0, surfaceY: y, bankRails: rails)
                    let old = FrozenBankQualityPredictor20261102.predict(input, includeBankKickPresentation: false)
                    let new = ShotPredictor.predict(input, includeBankKickPresentation: false)
                    // Compare only routes still recommended under the 11-03 parallel-wall policy.
                    let a = BankRouteQuality.accepts(old), b = BankRouteQuality.accepts(new)
                    guard a || b else { continue }
                    if a { oldValid += 1 }; if b { newValid += 1 }
                    XCTAssertFalse(a && !b, "Lost successful seed in \(name): \(rails) / \(spin)")
                    let oldJaw = ShotPredictor.bankPocketContactCount(events: old.events)
                    let newJaw = ShotPredictor.bankPocketContactCount(events: new.events)
                    if a && b && newJaw < oldJaw && BankKickRoute.measured(old, kick: false)?.rails == BankKickRoute.measured(new, kick: false)?.rails { improved += 1 }
                    if a && b && BankKickRoute.measured(old, kick: false)?.rails == BankKickRoute.measured(new, kick: false)?.rails {
                        XCTAssertLessThanOrEqual(newJaw, oldJaw, "Entry quality regressed on the same route")
                    }
                    if b && newJaw == 0 { clean += 1 }
                    candidates.append(["spin":spin,"seed":rails.map { $0.label },"old":details(old),"new":details(new)])
                }
            }
            let catalog = BankKickSolvePipeline.solveBank(cue: cue, object: obj, pocketIndex: pocket,
                surfaceY: y, power: speed, limit: nil)
            for (i, a) in catalog.enumerated() {
                XCTAssertTrue(BankKickValidity.bank(a.prediction))
                for b in catalog.dropFirst(i+1) { XCTAssertNotEqual(a.rails,b.rails) }
            }
            rows.append(["name":name,"cue":[cue.x,cue.z],"object":[obj.x,obj.z],"pocket":pocket,"speed":speed,
                         "ms":(ProcessInfo.processInfo.systemUptime-start)*1000,"candidates":candidates,
                         "catalog":catalog.map { ["spin":$0.spinX,"prediction":details($0.prediction)] as [String:Any] }])
            print("BANK_QUALITY_CASE \(name) catalog=\(catalog.count) jaw=\(catalog.map(\.pocketContacts))")
        }
        let data = try JSONSerialization.data(withJSONObject: rows,options:[.prettyPrinted,.sortedKeys])
        let attachment = XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name = "bank-pocket-quality.json"; attachment.lifetime = .keepAlways; add(attachment)
        print("BANK_QUALITY_SUMMARY oldValid=\(oldValid) newValid=\(newValid) improved=\(improved) clean=\(clean)")
        XCTAssertGreaterThan(improved,0,"Must demonstrate a real rattling pot replaced by a cleaner physical solution")
        XCTAssertGreaterThan(clean,0)
        XCTAssertGreaterThan(newValid,0)
    }
}

final class BankRecontactTests: XCTestCase {
    private let cue = ShotInput.cueBallName
    private let target = ShotInput.targetBallName
    private func hit(_ time: Float, reversed: Bool = false) -> ShotEvent {
        .init(time: time, kind: .ballBall(ballA: reversed ? target : cue, ballB: reversed ? cue : target))
    }
    private func prediction(_ events: [ShotEvent]) -> ShotPrediction {
        var p = ShotPrediction()
        p.feasible = true; p.termination = .settled; p.simObjectPotted = true
        p.objectRailContacts = [.left]; p.events = events
        return p
    }

    func testSingleHitAndPostCaptureEventsRemainValid() {
        let pot = ShotEvent(time: 3, kind: .pocket(ball: target, pocketId: "pocket_0"))
        XCTAssertTrue(BankKickValidity.bank(prediction([hit(1), pot])))
        XCTAssertTrue(BankKickValidity.bank(prediction([hit(1), pot, hit(4, reversed: true)])))
        XCTAssertFalse(BankKickValidity.hasRepeatedCueTargetContact(events: []))
        XCTAssertFalse(BankKickValidity.hasRepeatedCueTargetContact(events: [hit(1),
            .init(time: 2, kind: .ballBall(ballA: cue, ballB: "obstacle")), pot]))
    }

    func testSecondHitIsRejectedByFullAndValidationOnlyPaths() {
        let p = prediction([hit(1), .init(time: 2, kind: .ballCushion(ball: target)),
                            hit(3, reversed: true),
                            .init(time: 4, kind: .pocket(ball: target, pocketId: "pocket_0"))])
        XCTAssertTrue(BankKickValidity.hasRepeatedCueTargetContact(events: p.events))
        XCTAssertFalse(BankKickValidity.bank(p))
        XCTAssertFalse(BankKickValidity.bank(BankKickValidation(p)))
        // Kick's existing validity is independent of the bank-only restriction.
        var kick = p
        kick.events.insert(.init(time: 0, kind: .ballCushion(ball: cue),
                                 contactNormal: SCNVector3(1, 0, 0), cushionIndex: 0), at: 0)
        XCTAssertTrue(BankKickValidity.kick(kick))
    }

    func testRealSearchExcludesRepeatedContactsAndRetainsCleanBanks() throws {
        let surface = BTTablePhysics.surfaceY
        let y = surface + BallPhysics.radius
        let layouts: [(SCNVector3, SCNVector3)] = [
            (.init(-0.22, y, -0.10), .init(-0.70, y, 0.38)),
            (.init(0, y, -0.25), .init(-0.28, y, 0.22)),
            (.init(-0.5, y, -0.2), .init(0.1, y, 0.1))
        ]
        // Recorded real kiss pot from the 2026-11-02 quality audit, replayed through
        // today's full engine at its observed aim offset (not an inferred screenshot).
        let kissInput = ShotInput(cueBall: .init(-0.5, y, -0.2), targetBall: .init(0.1, y, 0.1),
            pocketIndex: 1, velocity: 3.6, spinX: 0, spinY: 0, surfaceY: surface, bankRails: [.right])
        var scratch = ShotPrediction()
        let context = try XCTUnwrap(ShotPredictor.prepareAim(kissInput, into: &scratch))
        let offset: Float = 0.008466586470603943
        let kiss = ShotPredictor.bankKickProbe(input: kissInput, context: context, offset: offset)
        XCTAssertTrue(kiss.simObjectPotted)
        XCTAssertTrue(kiss.hasFinalTableState)
        XCTAssertFalse(kiss.cuePocketed)
        XCTAssertEqual(kiss.cueCushionsBeforeContact, 0)
        XCTAssertFalse(kiss.objectRailContacts.isEmpty)
        XCTAssertTrue(BankKickValidity.hasRepeatedCueTargetContact(events: kiss.events))
        XCTAssertFalse(BankKickValidity.bank(kiss))
        XCTAssertFalse(BankKickValidity.bank(ShotPredictor.bankKickValidation(
            input: kissInput, context: context, offset: offset)))
        XCTAssertNil(BankKickSolvePipeline.bankSolution(input: kissInput, seedRails: [.right],
            prediction: kiss, measureRobustness: false))
        XCTAssertGreaterThanOrEqual(ShotPredictor.bankAimScore(offset: offset,
            input: kissInput, context: context, rails: [.right]), 0,
            "A kiss pot must not receive a successful-pot search score")
        print("BANK_RECONTACT_REAL events=\(kiss.events)")
        var retained = 0
        for (cuePos, object) in layouts {
            for pocket in [0, 2, 4, 5] {
                let catalog = BankKickSolvePipeline.solveBank(cue: cuePos, object: object,
                    pocketIndex: pocket, surfaceY: surface, power: 2.4, spinXValues: [0], limit: nil)
                retained += catalog.count
                for solution in catalog {
                    XCTAssertTrue(BankKickValidity.bank(solution.prediction))
                    XCTAssertFalse(BankKickValidity.hasRepeatedCueTargetContact(events: solution.prediction.events))
                }
            }
        }
        print("BANK_RECONTACT_SUMMARY replayedKiss=1 retained=\(retained)")
        XCTAssertGreaterThan(retained, 0, "Keep ordinary clean banks")
    }

    @MainActor
    func testPathsSurviveStrikeReplayStopAndUndoInBothViews() async throws {
        let vm = BankShotViewModel()
        let power = CushionReflectionSettings.power
        let detail = UserPreferences.shared.trajectoryDetail
        defer { vm.stopForDismissal(); CushionReflectionSettings.power = power; UserPreferences.shared.trajectoryDetail = detail }
        UserPreferences.shared.trajectoryDetail = .full
        vm.setupScene(); vm.reflectionPower = 3.6
        func waitFor(_ predicate: () -> Bool) async throws {
            let deadline = Date().addingTimeInterval(90)
            while !predicate(), Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
            XCTAssertTrue(predicate())
        }
        try await waitFor { !vm.isSolving }
        XCTAssertTrue(vm.canStrike)
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        view.scene = vm.scene; view.pointOfView = vm.scene.cameraNode
        vm.scene.cameraRig?.viewportSize = view.bounds.size
        let window = UIWindow(windowScene: try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene))
        let controller = UIViewController(); controller.view = view
        window.rootViewController = controller; window.makeKeyAndVisible(); view.isPlaying = true
        defer { view.isPlaying = false; window.isHidden = true }
        func paths() throws -> [SCNNode] {
            try XCTUnwrap(Mirror(reflecting: vm).children.first { $0.label == "pathNodes" }?.value as? [SCNNode])
        }
        func verify(_ nodes: [SCNNode]) {
            XCTAssertFalse(nodes.isEmpty)
            for node in nodes { XCTAssertNotNil(node.parent); XCTAssertFalse(node.isHidden) }
        }
        for mode: AngleTrainingScene.CameraMode in [.topDown2DRotated, .perspective3D] {
            vm.setCameraMode(mode)
            let nodes = try paths(); verify(nodes)
            vm.strike(); XCTAssertTrue(vm.isPlaying)
            try await waitFor { vm.scene.cueBallNode?.action(forKey: "strikeDemo") != nil }
            verify(nodes)
            try await Task.sleep(for: .milliseconds(300)); verify(nodes)
            vm.stopStrike(); XCTAssertFalse(vm.isPlaying); verify(try paths())
            vm.replaySolveShot(); XCTAssertTrue(vm.isPlaying)
            let replayNodes = try paths()
            try await waitFor { vm.scene.cueBallNode?.action(forKey: "strikeDemo") != nil }
            verify(replayNodes)
            try await waitFor { !vm.isPlaying }
            verify(try paths())
            vm.undoSolveShot(); verify(try paths())
        }
    }
}
