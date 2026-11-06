import XCTest
import SceneKit
@testable import QiuJi

@MainActor
final class BankKickAutomaticSolveTests: XCTestCase {
    private func idle(_ vm: any SolverStageHosting) async throws {
        let deadline = Date().addingTimeInterval(90)
        while vm.isSolving && Date() < deadline { try await Task.sleep(for: .milliseconds(30)) }
        XCTAssertFalse(vm.isSolving)
    }

    func testBankAutomaticSolveLifecycle() async throws { try await lifecycle(BankShotViewModel()) }
    func testKickAutomaticSolveLifecycle() async throws { try await lifecycle(DiamondSystemViewModel()) }

    private func lifecycle(_ vm: any SolverStageHosting) async throws {
        let power = CushionReflectionSettings.power
        defer { vm.stopForDismissal(); CushionReflectionSettings.power = power }
        vm.setupScene()
        vm.reflectionPower = 3.6
        vm.selectCushions(1)
        vm.selectCushions(nil)
        XCTAssertTrue(vm.isSolving)
        XCTAssertEqual(vm.primaryActionTitle, "计算中")
        XCTAssertFalse(vm.canStrike)
        try await idle(vm)
        XCTAssertTrue(vm.hasSolution)
        XCTAssertEqual(vm.primaryActionTitle, "击球")
        let count = vm.solutionCount
        vm.setCameraMode(.perspective3D)
        vm.setCameraMode(.topDown2DRotated)
        XCTAssertEqual(vm.solutionCount, count)
        XCTAssertFalse(vm.isSolving)
        vm.adjustCurrentSolution(velocity: 3.4, spinX: nil, spinY: nil)
        try await idle(vm)
        XCTAssertEqual(vm.reflectionPower, 3.4, accuracy: 0.0001)
        vm.adjustCurrentSolution(velocity: 3.3, spinX: nil, spinY: nil)
        vm.selectCushions(1)
        XCTAssertFalse(vm.isSolving, "A filter cancels a pending draft and never starts a new search")
        vm.selectCushions(nil)
        XCTAssertEqual(vm.solutionCount, count)
        XCTAssertEqual(vm.reflectionPower, 3.6, accuracy: 0.0001, "Filtering must restore catalog power, not relabel its prediction with draft power")
        vm.adjustCurrentSolution(velocity: 0.01, spinX: nil, spinY: nil)
        try await idle(vm)
        XCTAssertNotNil(vm.tableStatusText)
        vm.selectCushions(99)
        XCTAssertTrue(vm.tableStatusText?.hasPrefix("该库数下无解") == true,
                      "An empty filter must clear the discarded draft's failure notice")
        vm.selectCushions(nil)
        XCTAssertNil(vm.tableStatusText)
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        vm.dragBegan(node: cue)
        XCTAssertFalse(vm.canStrike)
        XCTAssertEqual(vm.solutionCount, 0)
        vm.dragEnded(node: cue)
        try await idle(vm)
        XCTAssertTrue(vm.canStrike, "Releasing the ball automatically restores an unchanged cached solution")
        vm.toggleMode()
        vm.toggleMode()
        try await idle(vm)
        XCTAssertTrue(vm.hasSolution)
        vm.placeObstacle("_1", atWorld: nil)
        XCTAssertTrue(vm.isSolving)
        XCTAssertFalse(vm.canStrike)
        vm.removeObstacle("_1")
        try await idle(vm)
        XCTAssertTrue(vm.hasSolution)
        vm.reflectionPower = 0.01
        try await idle(vm)
        XCTAssertFalse(vm.hasSolution)
        XCTAssertNotNil(vm.tableStatusText)
        XCTAssertEqual(vm.primaryActionTitle, "击球")
        vm.requestPrimaryAction()
        XCTAssertFalse(vm.isPlaying)
        XCTAssertFalse(vm.isSolving, "The strike button must not start another search")
    }

    func testCancelledSearchCannotPublishIntoDraggedOrSuspendedBoard() async throws {
        let power = CushionReflectionSettings.power
        defer { CushionReflectionSettings.power = power }
        for vm: any SolverStageHosting in [BankShotViewModel(), DiamondSystemViewModel()] {
            vm.setupScene()
            vm.reflectionPower = 3.37
            try await Task.sleep(for: .milliseconds(200))
            let cue = try XCTUnwrap(vm.scene.cueBallNode)
            vm.dragBegan(node: cue)
            vm.handleDrag(node: cue, to: SCNVector3(0.1, cue.position.y, 0.1))
            try await Task.sleep(for: .seconds(1))
            XCTAssertEqual(vm.solutionCount, 0)
            XCTAssertFalse(vm.canStrike)
            XCTAssertFalse(vm.isSolving, "Holding a drag must not search or accept the old result")
            vm.dragEnded(node: cue)
            XCTAssertTrue(vm.isSolving)
            vm.stopForDismissal()
            try await Task.sleep(for: .milliseconds(300))
            XCTAssertFalse(vm.isSolving)
            XCTAssertFalse(vm.hasSolution)
        }
    }

    func testBankPocketSelectionAutoSolvesAndKeepsPersistentMarker() async throws {
        let vm = BankShotViewModel()
        let power = CushionReflectionSettings.power
        defer { vm.stopForDismissal(); CushionReflectionSettings.power = power }
        vm.setupScene()
        vm.selectPocket(2)
        vm.selectPocket(3)
        XCTAssertTrue(vm.isSolving)
        try await idle(vm)
        XCTAssertEqual(vm.selectedPocket, 3)
        try await Task.sleep(for: .seconds(4))
        for index in 0..<6 {
            let marker = try XCTUnwrap(vm.scene.rootNode.childNode(withName: "pocketMarker_\(index)", recursively: true) as? PocketLeatherMarker)
            XCTAssertEqual(marker.style, index == 3 ? .practiceCurrent : .original)
        }
        vm.reflectionPower = 3.21
        vm.stopForDismissal()
        vm.resumeTeachingActivity()
        try await idle(vm)
        XCTAssertEqual(vm.selectedPocket, 3)
        XCTAssertEqual(vm.reflectionPower, 3.21, accuracy: 0.0001)
    }

    func testBankTargetSelectionThroughSharedHostPreservesBallIdentity() throws {
        let vm = BankShotViewModel()
        defer { vm.stopForDismissal() }
        vm.setupScene()
        vm.toggleMode()
        vm.placeObstacle("_1", atWorld: nil)
        let host: any SolverStageHosting = vm
        let old = try XCTUnwrap(vm.scene.allBallNodes["_8"])
        let new = try XCTUnwrap(vm.scene.allBallNodes["_1"])
        let oldPose = BallRestState(node: old), newPose = BallRestState(node: new)
        XCTAssertEqual(host.selectableBalls.count, 2)
        host.selectTarget(key: "_1")
        XCTAssertEqual(host.selectedTargetKey, "_1")
        XCTAssertTrue(host.targetNode === new)
        XCTAssertEqual(vm.scene.currentTargetNumber, 1)
        XCTAssertEqual(vm.onTableObstacleKeys, ["_8"])
        for (node, pose) in [(old, oldPose), (new, newPose)] {
            XCTAssertFalse(node.isHidden)
            XCTAssertEqual(node.position.x, pose.position.x)
            XCTAssertEqual(node.position.z, pose.position.z)
            XCTAssertEqual(node.simdOrientation.vector, pose.orientation.vector)
        }
        host.removeFromTable("_1")
        XCTAssertFalse(new.isHidden, "The current target is protected, regardless of its number")
        host.removeFromTable("_8")
        XCTAssertTrue(old.isHidden, "The former target can return to the palette")
        host.placeFromPalette("_8")
        XCTAssertFalse(old.isHidden)
        host.selectTarget(key: "_8")
        XCTAssertEqual(host.selectedTargetKey, "_8")
        XCTAssertEqual(vm.onTableObstacleKeys, ["_1"])
        for key in ["cueBall", "_2", "missing"] { host.selectTarget(key: key) }
        XCTAssertEqual(host.selectedTargetKey, "_8")
        XCTAssertFalse(vm.isSolving, "Free mode selection does not start a bank search")
    }

    func testBankTargetSelectionInvalidatesPendingSearchAndRestoresSnapshotRole() async throws {
        let vm = BankShotViewModel()
        let power = CushionReflectionSettings.power
        defer { vm.stopForDismissal(); CushionReflectionSettings.power = power }
        vm.setupScene(); vm.reflectionPower = 3.6
        try await idle(vm)
        let original = try XCTUnwrap(vm.makeSolveUndo())
        let originalTarget = try XCTUnwrap(vm.scene.targetBallNodes.first)
        let position = originalTarget.position
        vm.toggleMode()
        vm.placeObstacle("_1", atWorld: nil)
        vm.selectTarget(key: "_1")
        vm.removeFromTable("_8")
        let target = try XCTUnwrap(vm.scene.targetBallNodes.first)
        vm.dragBegan(node: target)
        vm.handleDrag(node: target, to: position)
        vm.dragEnded(node: target)
        vm.toggleMode()
        XCTAssertTrue(vm.isSolving)
        XCTAssertFalse(vm.canStrike)
        try await idle(vm)
        let selected = try XCTUnwrap(vm.makeSolveUndo())
        XCTAssertEqual(selected.board.targetKey, "_1")
        let pathStart = try XCTUnwrap(vm.currentSolution?.prediction.objectPath.first)
        XCTAssertEqual(pathStart.x, target.position.x, accuracy: 0.001)
        XCTAssertEqual(pathStart.z, target.position.z, accuracy: 0.001)
        vm.restoreSolve(from: original)
        XCTAssertEqual(vm.selectedTargetKey, "_8")
        XCTAssertTrue(vm.scene.targetBallNodes.first === originalTarget)
        XCTAssertTrue(target.isHidden)
        vm.restoreSolve(from: selected)
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        XCTAssertTrue(vm.scene.targetBallNodes.first === target)
        XCTAssertFalse(target.isHidden)
        XCTAssertTrue(originalTarget.isHidden)
        XCTAssertTrue(vm.canStrike)
        vm.placeObstacle("_8", atWorld: nil)
        XCTAssertTrue(vm.isSolving)
        vm.selectTarget(key: "_8")
        XCTAssertFalse(vm.hasSolution)
        XCTAssertFalse(vm.canStrike)
        vm.selectTarget(key: "_1")
        vm.removeFromTable("_8")
        try await idle(vm)
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        XCTAssertTrue(vm.canStrike)
        vm.toggleMode()
        vm.restoreSolveSnapshot()
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        vm.reset()
        XCTAssertEqual(vm.selectedTargetKey, "_8")
        XCTAssertEqual(vm.scene.currentTargetNumber, 8)
    }

    func testKickSharedHostKeepsFixedTargetContract() {
        let vm = DiamondSystemViewModel()
        defer { vm.stopForDismissal() }
        vm.setupScene(); vm.toggleMode(); vm.placeObstacle("_1", atWorld: nil)
        let host: any SolverStageHosting = vm
        host.selectTarget(key: "_1")
        XCTAssertEqual(host.selectedTargetKey, "_8")
        XCTAssertTrue(host.selectableBalls.isEmpty)
        XCTAssertEqual(host.onTableObstacleKeys, ["_1"])
    }

    func testRemovedKickPreferencesIgnoreLegacyValuesWithoutChangingBank() throws {
        let name = "BankKickAutomaticSolveTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let archive: [String: Any] = ["version": 1, "general": ["closeup": 1, "separation": 1],
            "pages": ["diamondSystem": ["closeup": 1, "separation": 1]]]
        defaults.set(try JSONSerialization.data(withJSONObject: archive), forKey: TablePreferencesStore.storageKey)
        let store = TablePreferencesStore(defaults: defaults)
        for field: TablePreferenceField in [.closeup, .separation] {
            XCTAssertFalse(store.snapshot(for: .diamondSystem).enabled(field))
            XCTAssertTrue(store.snapshot(for: .bankShot).enabled(field))
        }
    }
}

final class KickRouteQualityTests: XCTestCase {
    private let cue = ShotInput.cueBallName
    private func rail(_ n: Int, _ normal: SCNVector3, ball: String? = nil) -> ShotEvent {
        .init(time: 0.1, kind: .ballCushion(ball: ball ?? cue), contactNormal: normal, cushionIndex: n)
    }
    private var hit: ShotEvent { .init(time: 1, kind: .ballBall(ballA: cue, ballB: ShotInput.targetBallName)) }

    func testParallelPairsAreExcludedButPerpendicularTurnsRemain() {
        let cases: [([BankShotCalculator.Rail], Bool)] = [([], false), ([.left, .right], true), ([.near, .far], true), ([.left], false), ([.left, .left], false),
            ([.left, .right, .left], true), ([.right, .left, .right], true),
            ([.near, .far, .near], true), ([.far, .near, .far], true),
            ([.left, .near, .left], false), ([.left, .near, .right], false),
            ([.left, .near, .far, .near], true)]
        for (rails, expected) in cases { XCTAssertEqual(BankKickRouteQuality.hasConsecutiveParallelRails(rails), expected) }
    }

    func testQualityUsesAllPreContactEventsAndIgnoresPostContactAndOtherBalls() {
        let left = rail(0, .init(0, 0, 1)), right = rail(2, .init(0, 0, -1))
        let near = rail(5, .init(-1, 0, 0))
        let jaw = rail(8, .init(-1, 0, 0))
        XCTAssertEqual(KickRouteQuality.rejection(events: [left, jaw, hit]), .pocketCushion)
        XCTAssertEqual(KickRouteQuality.rejection(events: [jaw, left, hit]), .pocketCushion)
        XCTAssertEqual(KickRouteQuality.rejection(events: [left, right, left, hit]), .consecutiveParallelRails)
        XCTAssertEqual(KickRouteQuality.rejection(events: [left, right, hit]), .consecutiveParallelRails)
        XCTAssertNil(KickRouteQuality.rejection(events: [left, near, hit, jaw, left, right]))
        XCTAssertNil(KickRouteQuality.rejection(events: [rail(8, .init(1, 0, 0), ball: "obstacle"), left, hit]))
        XCTAssertNil(KickRouteQuality.rejection(events: [left, left, near, hit]))
    }

    func testRealOldCandidatesAreRejectedWithExplicitReasons() {
        let surface = BTTablePhysics.surfaceY, y = surface + BallPhysics.radius
        var rejected: [String: Int] = [:]
        for (cue, target) in [(SCNVector3(-0.5, y, -0.2), SCNVector3(0.4, y, 0.25)),
                              (SCNVector3(0.70, y, 0.28), SCNVector3(-0.57, y, -0.19))] {
            for spin: Float in [-0.3, 0, 0.3] {
                let input = ShotInput(cueBall: cue, targetBall: target, pocketIndex: 0,
                    velocity: 3.6, spinX: spin, spinY: 0, surfaceY: surface)
                let old = FrozenBankQualityPredictor20261102.predictKickAll(input, includePresentation: false)
                for (rails, prediction) in old {
                    if let reason = KickRouteQuality.rejection(events: prediction.events) {
                        rejected[reason.rawValue, default: 0] += 1
                        XCTAssertTrue(prediction.hasFinalTableState && !prediction.cuePocketed
                            && ShotPredictor.kickContactInfo(events: prediction.events).contacted,
                            "Physical target contact is distinct from legal/recommendable kick success")
                        XCTAssertNil(BankKickSolvePipeline.kickSolution(input: input,
                            seedRails: rails, prediction: prediction, measureRobustness: false))
                    }
                }
            }
        }
        XCTAssertGreaterThan(rejected["pocketCushion", default: 0], 0)
        XCTAssertGreaterThan(rejected["consecutiveParallelRails", default: 0], 0)
        print("KICK_QUALITY_OLD_REJECTIONS \(rejected)")
    }

    func testRealCatalogsAreCleanAndKeepNormalRoutesAcrossMirrors() throws {
        let surface = BTTablePhysics.surfaceY, y = surface + BallPhysics.radius
        var total = 0
        for sx: Float in [-1, 1] {
            for sz: Float in [-1, 1] {
                let cue = SCNVector3(-0.5 * sx, y, -0.2 * sz)
                let target = SCNVector3(0.4 * sx, y, 0.25 * sz)
                let solutions = BankKickSolvePipeline.solveKick(cue: cue, target: target,
                    surfaceY: surface, power: 3.6, limit: nil)
                XCTAssertFalse(solutions.isEmpty)
                for sol in solutions {
                    XCTAssertTrue(sol.prediction.hasFinalTableState)
                    XCTAssertTrue(BankKickValidity.kick(sol.prediction))
                    XCTAssertNil(KickRouteQuality.rejection(events: sol.prediction.events))
                    // Independent wall-axis check against actual route metadata.
                    let walls = sol.rails
                    for i in walls.indices where i + 1 < walls.count {
                        let long: Set<DiamondSystemCalculator.Rail> = [.left, .right]
                        XCTAssertFalse(walls[i] != walls[i + 1]
                            && long.contains(walls[i]) == long.contains(walls[i + 1]))
                    }
                }
                total += solutions.count
            }
        }
        print("KICK_QUALITY_CATALOG_ACCEPTED \(total)")
    }
}

@MainActor
final class PlanningAutomaticSolveTests: XCTestCase {
    private func idle(_ busy: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(90)
        while busy() && Date() < deadline { try await Task.sleep(for: .milliseconds(30)) }
        XCTAssertFalse(busy())
    }

    func testSiluDrawCompletionClearDragAndPersistentPocket() async throws {
        let vm = SiluTrainerViewModel(); vm.setupScene()
        defer { vm.stopForDismissal() }
        vm.loadBoard(.init(onTable: [PositionPlayBall.cueKey: .init(x: 0.5, y: 0.36),
                                    "_1": .init(x: 0.5, y: 0.16)]))
        vm.selectPocket(at: 4)
        XCTAssertFalse(vm.isComputing)
        XCTAssertFalse(vm.hasSolutions)
        XCTAssertEqual(vm.activeTool, .region)
        let start = CanvasPoint(x: 0.02, y: 0.02), end = CanvasPoint(x: 0.98, y: 0.48)
        vm.toolDrag(startNormalized: start, currentNormalized: end, ended: false)
        XCTAssertFalse(vm.isComputing)
        XCTAssertFalse(vm.canStrike)
        vm.toolDrag(startNormalized: start, currentNormalized: end, ended: true)
        XCTAssertTrue(vm.isComputing)
        try await idle { vm.isComputing }
        XCTAssertTrue(vm.hasSolutions)
        XCTAssertTrue(vm.canStrike)
        let marker = try XCTUnwrap(vm.scene.rootNode.childNode(withName: "pocketMarker_4", recursively: true) as? PocketLeatherMarker)
        try await Task.sleep(for: .seconds(4))
        XCTAssertEqual(marker.style, .practiceCurrent)
        XCTAssertFalse(vm.draggableBalls.isEmpty)
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        vm.dragBegan(node: cue)
        XCTAssertFalse(vm.canStrike)
        XCTAssertFalse(vm.hasSolutions)
        vm.dragEnded(node: cue)
        XCTAssertTrue(vm.isComputing)
        vm.clearConstraint()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(vm.isComputing)
        XCTAssertFalse(vm.hasSolutions)
        XCTAssertFalse(vm.hasConstraint)
        XCTAssertEqual(marker.style, .practiceCurrent)
    }

    func testPlanIncompleteStrikeUsesExistingHintAndCompletedPlanAutoSolves() async throws {
        let vm = PlanThreeViewModel(); vm.setupScene()
        defer { vm.stopForDismissal() }
        vm.loadBoard(.init(onTable: [PositionPlayBall.cueKey: .init(x: 0.24, y: 0.30),
            "_1": .init(x: 0.52, y: 0.16), "_2": .init(x: 0.70, y: 0.34),
            "_3": .init(x: 0.86, y: 0.16)]))
        XCTAssertEqual(vm.primaryActionTitle, "击球")
        vm.requestPrimaryAction()
        XCTAssertEqual(vm.statusText, vm.missingSelection)
        XCTAssertFalse(vm.isPlaying)
        XCTAssertFalse(vm.isComputing)
        vm.selectPaletteBall("_1"); vm.selectPocket(at: 1)
        vm.selectPaletteBall("_2"); vm.selectPocket(at: 3)
        XCTAssertNotNil(vm.missingSelection)
        XCTAssertFalse(vm.isComputing)
        vm.requestPrimaryAction()
        XCTAssertEqual(vm.statusText, vm.missingSelection)
        vm.selectPaletteBall("_3")
        XCTAssertNil(vm.missingSelection)
        XCTAssertTrue(vm.isComputing)
        vm.stopForDismissal()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(vm.hasSolutions)
        XCTAssertFalse(vm.isComputing)
    }

    func testPlanLastBallAutomaticallySolvesAndBackRevokesIt() async throws {
        let vm = PlanThreeViewModel(); vm.setupScene()
        defer { vm.stopForDismissal() }
        vm.uiTestConfigure("oneBall")
        XCTAssertTrue(vm.isComputing)
        try await idle { vm.isComputing }
        XCTAssertTrue(vm.canStrike)
        XCTAssertTrue(vm.hasSolutions)
        XCTAssertEqual(vm.primaryActionTitle, "击球")
        vm.goToPreviousStep()
        XCTAssertFalse(vm.hasSolutions)
        XCTAssertFalse(vm.isComputing)
        vm.requestPrimaryAction()
        XCTAssertFalse(vm.isPlaying)
        XCTAssertEqual(vm.statusText, vm.missingSelection)
    }
}
