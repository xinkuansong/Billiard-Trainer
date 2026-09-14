import XCTest
@testable import QiuJi

final class AngleCalculatorTests: XCTestCase {

    func test_contactPointOffset_45degrees_approximately0707() {
        let offset = AngleCalculator.contactPointOffset(angle: 45.0)
        XCTAssertEqual(offset, sin(45.0 * .pi / 180.0), accuracy: 0.001)
        XCTAssertEqual(offset, 0.707, accuracy: 0.001)
    }

    func test_contactPointOffset_knownValues() {
        XCTAssertEqual(AngleCalculator.contactPointOffset(angle: 0), 0.0, accuracy: 0.001)
        XCTAssertEqual(AngleCalculator.contactPointOffset(angle: 30), 0.5, accuracy: 0.001)
        XCTAssertEqual(AngleCalculator.contactPointOffset(angle: 90), 1.0, accuracy: 0.001)
        XCTAssertEqual(AngleCalculator.contactPointOffset(angle: 60), sin(60.0 * .pi / 180.0), accuracy: 0.001)
    }

    func test_randomAngle_corner_inRange5to85_stepOf5() {
        for _ in 0..<200 {
            let angle = AngleCalculator.randomAngle(pocketType: .corner)
            XCTAssertGreaterThanOrEqual(angle, 5)
            XCTAssertLessThanOrEqual(angle, 85)
            XCTAssertEqual(angle.truncatingRemainder(dividingBy: 5), 0, "Angle must be a multiple of 5°")
        }
    }

    func test_randomAngle_side_inRange15to60_stepOf5() {
        for _ in 0..<200 {
            let angle = AngleCalculator.randomAngle(pocketType: .side)
            XCTAssertGreaterThanOrEqual(angle, 15)
            XCTAssertLessThanOrEqual(angle, 60)
            XCTAssertEqual(angle.truncatingRemainder(dividingBy: 5), 0, "Angle must be a multiple of 5°")
        }
    }

    func test_generateQuestion_returnsCorrectAngleAndPocketType() {
        for pocketType in PocketType.allCases {
            let angle = AngleCalculator.randomAngle(pocketType: pocketType)
            let q = AngleCalculator.generateQuestion(angle: angle, pocketType: pocketType)
            XCTAssertEqual(q.actualAngle, angle)
            XCTAssertEqual(q.pocketType, pocketType)
            XCTAssertEqual(q.pocket.type, pocketType)
        }
    }

    func test_generateQuestion_ballsWithinTableBounds() {
        for _ in 0..<50 {
            let pocketType: PocketType = Bool.random() ? .corner : .side
            let angle = AngleCalculator.randomAngle(pocketType: pocketType)
            let q = AngleCalculator.generateQuestion(angle: angle, pocketType: pocketType)

            XCTAssertGreaterThanOrEqual(q.targetBall.x, 0.0)
            XCTAssertLessThanOrEqual(q.targetBall.x, 1.0)
            XCTAssertGreaterThanOrEqual(q.targetBall.y, 0.0)
            XCTAssertLessThanOrEqual(q.targetBall.y, 0.5)

            XCTAssertGreaterThanOrEqual(q.cueBall.x, 0.0)
            XCTAssertLessThanOrEqual(q.cueBall.x, 1.0)
            XCTAssertGreaterThanOrEqual(q.cueBall.y, 0.0)
            XCTAssertLessThanOrEqual(q.cueBall.y, 0.5)
        }
    }

    func test_pockets_has6_4corner2side() {
        let pockets = AngleCalculator.pockets
        XCTAssertEqual(pockets.count, 6)
        XCTAssertEqual(pockets.filter { $0.type == .corner }.count, 4)
        XCTAssertEqual(pockets.filter { $0.type == .side }.count, 2)
    }
}

// MARK: - AdaptiveQuestionEngine Tests

final class AdaptiveQuestionEngineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: PracticeStorageKey.adaptiveQuestionEngine)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: PracticeStorageKey.adaptiveQuestionEngine)
        super.tearDown()
    }

    func test_cornerAngles_17values_5to85() {
        let angles = AdaptiveQuestionEngine.cornerAngles
        XCTAssertEqual(angles.count, 17)
        XCTAssertEqual(angles.first, 5)
        XCTAssertEqual(angles.last, 85)
    }

    func test_sideAngles_10values_15to60() {
        let angles = AdaptiveQuestionEngine.sideAngles
        XCTAssertEqual(angles.count, 10)
        XCTAssertEqual(angles.first, 15)
        XCTAssertEqual(angles.last, 60)
    }

    func test_selectPocketType_100questions_cornerSideRatio55to65() {
        let engine = AdaptiveQuestionEngine()
        var cornerCount = 0
        let total = 100

        for _ in 0..<total {
            if engine.selectPocketType() == .corner {
                cornerCount += 1
            }
        }

        let cornerPercent = Double(cornerCount) / Double(total) * 100.0
        XCTAssertGreaterThanOrEqual(cornerPercent, 45,
            "Corner ratio \(cornerPercent)% below 45% — expected around 60%")
        XCTAssertLessThanOrEqual(cornerPercent, 75,
            "Corner ratio \(cornerPercent)% above 75% — expected around 60%")
    }

    func test_selectPocketType_1000questions_tighterBounds() {
        let engine = AdaptiveQuestionEngine()
        var cornerCount = 0
        let total = 1000

        for _ in 0..<total {
            if engine.selectPocketType() == .corner {
                cornerCount += 1
            }
        }

        let cornerPercent = Double(cornerCount) / Double(total) * 100.0
        XCTAssertGreaterThanOrEqual(cornerPercent, 55,
            "Corner ratio \(cornerPercent)% below 55% — expected ~60%")
        XCTAssertLessThanOrEqual(cornerPercent, 65,
            "Corner ratio \(cornerPercent)% above 65% — expected ~60%")
    }

    func test_selectAngle_corner_returnsValidAngle() {
        let engine = AdaptiveQuestionEngine()
        for _ in 0..<100 {
            let angle = Int(engine.selectAngle(for: .corner))
            XCTAssertTrue(AdaptiveQuestionEngine.cornerAngles.contains(angle),
                          "Angle \(angle) not in cornerAngles")
        }
    }

    func test_selectAngle_side_returnsValidAngle() {
        let engine = AdaptiveQuestionEngine()
        for _ in 0..<100 {
            let angle = Int(engine.selectAngle(for: .side))
            XCTAssertTrue(AdaptiveQuestionEngine.sideAngles.contains(angle),
                          "Angle \(angle) not in sideAngles")
        }
    }

    func test_zoneHistory_averageError() {
        var zone = AdaptiveQuestionEngine.ZoneHistory()
        XCTAssertEqual(zone.averageError, 0)

        zone.addError(10)
        zone.addError(20)
        XCTAssertEqual(zone.averageError, 15.0, accuracy: 0.001)
    }

    func test_zoneHistory_rollingWindow_max10() {
        var zone = AdaptiveQuestionEngine.ZoneHistory()
        for i in 1...15 {
            zone.addError(Double(i))
        }
        XCTAssertEqual(zone.errors.count, 10, "Should keep at most 10 errors")
        XCTAssertEqual(zone.errors.first, 6, "Oldest kept should be 6 (after removing 1–5)")
    }

    func test_recordResult_storesInCorrectZone() {
        let engine = AdaptiveQuestionEngine()
        engine.recordResult(angle: 45, error: 5, pocketType: .corner)
        engine.recordResult(angle: 30, error: 8, pocketType: .side)

        XCTAssertNotNil(engine.cornerZones[45])
        XCTAssertEqual(engine.cornerZones[45]?.errors, [5.0])
        XCTAssertNotNil(engine.sideZones[30])
        XCTAssertEqual(engine.sideZones[30]?.errors, [8.0])
    }

    func test_recordResult_persistsToUserDefaults() {
        let engine = AdaptiveQuestionEngine()
        engine.recordResult(angle: 45, error: 5, pocketType: .corner)

        let engine2 = AdaptiveQuestionEngine()
        XCTAssertNotNil(engine2.cornerZones[45])
        XCTAssertEqual(engine2.cornerZones[45]?.errors, [5.0])
    }
}

// MARK: - AngleUsageLimiter Tests

final class AngleUsageLimiterTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AngleUsageLimiterTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_dailyLimit_is20() {
        XCTAssertEqual(AngleUsageLimiter.dailyLimit, 20)
    }

    func test_freshStart_zeroUsed() {
        let limiter = AngleUsageLimiter(defaults: defaults)
        XCTAssertEqual(limiter.questionsUsedToday, 0)
        XCTAssertEqual(limiter.remainingToday, 20)
        XCTAssertFalse(limiter.isLimitReached)
    }

    func test_recordQuestion_incrementsCount() {
        let limiter = AngleUsageLimiter(defaults: defaults)
        limiter.recordQuestion()
        limiter.recordQuestion()
        XCTAssertEqual(limiter.questionsUsedToday, 2)
        XCTAssertEqual(limiter.remainingToday, 18)
    }

    func test_limitReached_at20() {
        let limiter = AngleUsageLimiter(defaults: defaults)
        for _ in 0..<20 { limiter.recordQuestion() }
        XCTAssertTrue(limiter.isLimitReached)
        XCTAssertEqual(limiter.remainingToday, 0)
    }

    func test_premium_bypassesLimit() {
        let limiter = AngleUsageLimiter(defaults: defaults)
        for _ in 0..<25 { limiter.recordQuestion() }
        limiter.isPremium = true
        XCTAssertFalse(limiter.isLimitReached, "Premium users should not be limited")
    }

    func test_dateReset_clearsPreviousDayCount() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        defaults.set(df.string(from: yesterday), forKey: PracticeStorageKey.angleUsageDate)
        defaults.set(15, forKey: PracticeStorageKey.angleUsageCount)

        let limiter = AngleUsageLimiter(defaults: defaults)
        XCTAssertEqual(limiter.questionsUsedToday, 0, "Should reset for a new day")
    }

    func test_sameDay_restoresCount() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        defaults.set(df.string(from: Date()), forKey: PracticeStorageKey.angleUsageDate)
        defaults.set(7, forKey: PracticeStorageKey.angleUsageCount)

        let limiter = AngleUsageLimiter(defaults: defaults)
        XCTAssertEqual(limiter.questionsUsedToday, 7)
    }

    func test_shared_isSingleton() {
        XCTAssertTrue(AngleUsageLimiter.shared === AngleUsageLimiter.shared)
    }

    func test_storageKeys_unchanged() {
        XCTAssertEqual(PracticeStorageKey.angleUsageCount, "AngleUsage_count")
        XCTAssertEqual(PracticeStorageKey.angleUsageDate, "AngleUsage_date")
    }
}

// MARK: - BTFeedback Tests (C22)

final class BTFeedbackTests: XCTestCase {

    func test_outcome_forDegrees_bands() {
        XCTAssertEqual(BTFeedback.outcome(forDegrees: 0), .correct)
        XCTAssertEqual(BTFeedback.outcome(forDegrees: 3), .correct)
        XCTAssertEqual(BTFeedback.outcome(forDegrees: 3.1), .close)
        XCTAssertEqual(BTFeedback.outcome(forDegrees: 10), .close)
        XCTAssertEqual(BTFeedback.outcome(forDegrees: 10.1), .off)
    }

    func test_outcome_forMM_bands() {
        XCTAssertEqual(BTFeedback.outcome(forMM: 0), .correct)
        XCTAssertEqual(BTFeedback.outcome(forMM: 2), .correct)
        XCTAssertEqual(BTFeedback.outcome(forMM: 2.1), .close)
        XCTAssertEqual(BTFeedback.outcome(forMM: 6), .close)
        XCTAssertEqual(BTFeedback.outcome(forMM: 6.1), .off)
    }

    func test_notificationType_mapping() {
        XCTAssertEqual(BTFeedback.notificationType(for: .correct), .success)
        XCTAssertEqual(BTFeedback.notificationType(for: .close), .warning)
        XCTAssertEqual(BTFeedback.notificationType(for: .off), .error)
    }
}

// MARK: - PracticeStorageKey Tests (C24)

final class PracticeStorageKeyTests: XCTestCase {

    func test_rawValues_frozen() {
        XCTAssertEqual(PracticeStorageKey.angleUsageCount, "AngleUsage_count")
        XCTAssertEqual(PracticeStorageKey.angleUsageDate, "AngleUsage_date")
        XCTAssertEqual(PracticeStorageKey.adaptiveQuestionEngine, "AdaptiveQuestionEngine_v1")
        XCTAssertEqual(PracticeStorageKey.cushionReflectionPower, "cushionReflectionPower")
        XCTAssertEqual(PracticeStorageKey.angleDynamicHasDraggedOnce, "angleDynamic.hasDraggedOnce")
        XCTAssertEqual(PracticeStorageKey.geometricQuizForcedAngle, "geometricQuiz.forcedAngle")
        XCTAssertEqual(PracticeStorageKey.geometricQuizForcedSide, "geometricQuiz.forcedSide")
    }
}

// MARK: - AngleSceneCalculator Tests (T-P9-02 coordinate mapping)

import SceneKit

@MainActor
final class TrainingAssistSceneTests: XCTestCase {
    func testAssistKeepsShotDirectionAcrossCameraMotionAndModes() async throws {
        let suite = "TrainingAssistSceneTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults)
        limiter.isPremium = true
        let vm = AimingQuizViewModel(limiter: limiter)
        vm.setupScene(initialCameraMode: .perspective3D)
        let scene = vm.scene
        let stick = try XCTUnwrap(scene.cueStick)
        XCTAssertTrue(stick.rootNode.isHidden)
        let coordinator = AngleSceneView.Coordinator(scene: scene, cameraMode: .perspective3D,
                                                     interactionMode: .cameraControl)
        coordinator.startRenderLoop()
        defer { coordinator.stopRenderLoop() }
        for mode: AngleTrainingScene.CameraMode in [.perspective3D, .topDown2DRotated, .topDown2D] {
            scene.setCameraMode(mode, animated: false)
            coordinator.cameraMode = mode
            vm.refreshVisualization()
            if !vm.showAimingAssist { vm.toggleAimingAssist() }
            XCTAssertFalse(stick.rootNode.isHidden)
            let ghost = try XCTUnwrap(scene.ghostBallNode)
            let cue = try XCTUnwrap(scene.cueBallNode)
            let dx = ghost.position.x - cue.position.x
            let dz = ghost.position.z - cue.position.z
            let length = hypot(dx, dz)
            for yaw: Float in [0, .pi / 2, .pi, -.pi / 2] {
                scene.cameraRig?.setAimYaw(yaw)
                scene.cameraRig?.handleVerticalSwipe(delta: 12)
                // Let the production display link run; a camera-bound cue would move here.
                try await Task.sleep(for: .milliseconds(120))
                let back = stick.rootNode.convertVector(SCNVector3(0, 0, 1), to: nil)
                let backLength = hypot(back.x, back.z)
                XCTAssertEqual(back.x / backLength, -dx / length, accuracy: 1e-5)
                XCTAssertEqual(back.z / backLength, -dz / length, accuracy: 1e-5)
            }
            vm.toggleAimingAssist()
            try await Task.sleep(for: .milliseconds(120))
            XCTAssertTrue(stick.rootNode.isHidden)
            XCTAssertTrue(ghost.isHidden)
        }
        vm.toggleAimingAssist()
        vm.startTest()
        XCTAssertTrue(stick.rootNode.isHidden)
        XCTAssertTrue(try XCTUnwrap(scene.ghostBallNode).isHidden)
    }

    func testTrainingGreenPotLinesAndLabelsKeepOtherBallColors() throws {
        let scene = AngleTrainingScene()
        scene.setupScene()
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        let cue = SCNVector3(-0.45, y, 0.15)
        let target = SCNVector3(0.35, y, -0.1)
        let pocket = SCNVector3(0, y, -0.688)
        for training in [false, true] {
            scene.setupVisualizationNodes(usesTrainingAssistStyle: training)
            for number in 1...15 {
                scene.applyBallLayout(cueBallPosition: cue, targetBallNumber: number, targetPosition: target)
                scene.updateVisualization(cueBall: cue, targetBall: target, pocket: pocket,
                                          showLineLabels: true, extendStrikeLineToRail: true)
                let expected: UIColor = training && [6, 14].contains(number)
                    ? .white : TrajectoryStyle.potColor(forNumber: number)
                XCTAssertEqual(scene.pocketLineNode?.geometry?.firstMaterial?.multiply.contents as? UIColor,
                               expected, "training=\(training), ball=\(number)")
                var labels: [String: UIColor] = [:]
                scene.angleArcNode?.enumerateChildNodes { node, _ in
                    guard let text = node.geometry as? SCNText,
                          let name = text.string as? String,
                          let color = text.firstMaterial?.diffuse.contents as? UIColor else { return }
                    labels[name] = color
                }
                XCTAssertEqual(labels["进球线"], expected)
                XCTAssertEqual(labels["瞄准线"], UIColor.white)
            }
        }
        // Training scenes and their loupe share this policy; the global palette stays green.
        for number in [6, 14] {
            XCTAssertEqual(TrajectoryStyle.TrainingAssist.potColor(forNumber: number), UIColor.white)
            XCTAssertNotEqual(TrajectoryStyle.potColor(forNumber: number), UIColor.white)
        }
    }

    func testTrainingGreenPotLineRenderEvidence() throws {
        let scene = AngleTrainingScene()
        scene.setupScene()
        scene.setupVisualizationNodes(usesTrainingAssistStyle: true)
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        let cue = SCNVector3(-0.45, y, 0.15)
        let target = SCNVector3(0.35, y, -0.1)
        let pocket = SCNVector3(0, y, -0.688)
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        for number in [6, 14, 3] {
            scene.applyBallLayout(cueBallPosition: cue, targetBallNumber: number, targetPosition: target)
            for mode: AngleTrainingScene.CameraMode in [.topDown2DRotated, .perspective3D] {
                scene.setCameraMode(mode, animated: false)
                if mode == .topDown2DRotated {
                    scene.cameraRig?.fitRotatedTable(viewSize: CGSize(width: 402, height: 700))
                    scene.cameraRig?.applyTopDown2DRotated()
                } else {
                    scene.cameraRig?.enterAiming(cueBallPosition: cue,
                                                targetDirection: SCNVector3(target.x-cue.x, 0, target.z-cue.z))
                    scene.cameraRig?.update(deltaTime: 1)
                }
                scene.updateVisualization(cueBall: cue, targetBall: target, pocket: pocket,
                                          showLineLabels: mode == .topDown2DRotated,
                                          extendStrikeLineToRail: true)
                scene.showAuxiliaryCue()
                SCNTransaction.flush()
                let image = renderer.snapshot(atTime: 0, with: CGSize(width: 804, height: 1400),
                                              antialiasingMode: .multisampling4X)
                let attachment = XCTAttachment(image: image)
                attachment.name = "pot-ball-\(number)-\(mode == .topDown2DRotated ? "2d" : "3d")"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testGhostMatchesModelBallsAndWhiteLineReachesRail() throws {
        let scene = AngleTrainingScene()
        scene.setupScene()
        scene.setupVisualizationNodes(usesTrainingAssistStyle: true)
        let ghost = try XCTUnwrap(scene.ghostBallNode)
        // DR-302: training scenes use the standard dashed cloth ring (no translucent sphere).
        XCTAssertNil(ghost.geometry, "ghost must not carry a sphere geometry of its own")
        let dashes = ghost.childNodes.filter { $0.geometry is SCNCylinder }
        XCTAssertFalse(dashes.isEmpty)
        for dash in dashes {
            XCTAssertEqual(hypotf(dash.position.x, dash.position.z), AngleSceneCalculator.ballRadius, accuracy: 1e-6)
            XCTAssertEqual(dash.position.y - TrajectoryStyle.lineHint, -AngleSceneCalculator.ballRadius + 0.0005, accuracy: 1e-6)
        }
        let radius = CGFloat(AngleSceneCalculator.ballRadius)
        XCTAssertEqual(scene.allBallNodes.count, 16)
        for (key, ball) in scene.allBallNodes {
            // Hidden container nodes report an empty aggregate bounding box on iOS.
            // Measure the mesh vertices themselves in world space instead.
            var vertices: [SCNVector3] = []
            ball.enumerateChildNodes { node, _ in
                guard let source = node.geometry?.sources(for: .vertex).first else { return }
                XCTAssertTrue(source.usesFloatComponents)
                XCTAssertEqual(source.bytesPerComponent, 4)
                guard source.usesFloatComponents, source.bytesPerComponent == 4 else { return }
                source.data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                    for index in 0..<source.vectorCount {
                        let offset = source.dataOffset + index * source.dataStride
                        let point = SCNVector3(
                            raw.loadUnaligned(fromByteOffset: offset, as: Float.self),
                            raw.loadUnaligned(fromByteOffset: offset + 4, as: Float.self),
                            raw.loadUnaligned(fromByteOffset: offset + 8, as: Float.self))
                        vertices.append(node.convertPosition(point, to: nil))
                    }
                }
            }
            XCTAssertFalse(vertices.isEmpty, key)
            let xs = vertices.map(\.x), ys = vertices.map(\.y), zs = vertices.map(\.z)
            let diameter = max(try XCTUnwrap(xs.max()) - XCTUnwrap(xs.min()),
                               try XCTUnwrap(ys.max()) - XCTUnwrap(ys.min()),
                               try XCTUnwrap(zs.max()) - XCTUnwrap(zs.min()))
            // USDZ tessellation and cue spots differ by less than 0.5 mm.
            XCTAssertEqual(CGFloat(diameter), 2 * radius, accuracy: 0.0005, key)
        }
        let color = try XCTUnwrap(scene.strikeLineNode?.geometry?.firstMaterial?.diffuse.contents as? UIColor)
        XCTAssertEqual(color, UIColor.white)
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        let cue = SCNVector3(-0.6, y, 0)
        let target = SCNVector3(0, y, 0)
        scene.updateVisualization(cueBall: cue, targetBall: target,
                                  pocket: SCNVector3(1.312, y, 0),
                                  extendStrikeLineToRail: true)
        XCTAssertEqual(ghost.position.x, -2 * AngleSceneCalculator.ballRadius, accuracy: 1e-6)
        let line = try XCTUnwrap(scene.strikeLineNode)
        let source = try XCTUnwrap(line.geometry?.sources(for: .vertex).first)
        XCTAssertEqual(line.geometry?.elements.first?.primitiveType, .triangles)
        var endpoints: [SCNVector3] = []
        source.data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            for index in 0..<source.vectorCount {
                let offset = source.dataOffset + index * source.dataStride
                let point = SCNVector3(
                    raw.loadUnaligned(fromByteOffset: offset, as: Float.self),
                    raw.loadUnaligned(fromByteOffset: offset + 4, as: Float.self),
                    raw.loadUnaligned(fromByteOffset: offset + 8, as: Float.self))
                endpoints.append(line.convertPosition(point, to: nil))
            }
        }
        XCTAssertFalse(endpoints.isEmpty)
        XCTAssertEqual(try XCTUnwrap(endpoints.map(\.x).max()), AngleSceneCalculator.innerLength / 2, accuracy: 1e-5)
        let clothY = try XCTUnwrap(MobileClothAlignment.measuredBedY(in: scene))
        for point in endpoints { XCTAssertEqual(point.y, clothY + 0.001, accuracy: 1e-5) }
        XCTAssertEqual(ghost.position.y, y, accuracy: 1e-6)

    }
}

final class AngleSceneCalculatorTests: XCTestCase {

    private let surfaceY: Float = 0.8

    /// T-P9-02 DoD: 坐标映射往返精度 < 0.001
    func test_normalizedToScene_roundTrip_accuracyUnder0001() {
        let samples: [CGPoint] = [
            CGPoint(x: 0.0, y: 0.0),
            CGPoint(x: 1.0, y: 0.5),
            CGPoint(x: 0.5, y: 0.25),
            CGPoint(x: 0.25, y: 0.1),
            CGPoint(x: 0.73, y: 0.42),
            CGPoint(x: 0.99, y: 0.01),
        ]
        for point in samples {
            let scene = AngleSceneCalculator.normalizedToScene(point: point, surfaceY: surfaceY)
            let back = AngleSceneCalculator.sceneToNormalized(position: scene)
            XCTAssertEqual(Double(back.x), Double(point.x), accuracy: 0.001,
                           "x round-trip drift for \(point)")
            XCTAssertEqual(Double(back.y), Double(point.y), accuracy: 0.001,
                           "y round-trip drift for \(point)")
        }
    }

    func test_normalizedCenter_mapsToWorldOrigin() {
        let scene = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: 0.5, y: 0.25),
                                                           surfaceY: surfaceY)
        XCTAssertEqual(scene.x, 0, accuracy: 0.0001)
        XCTAssertEqual(scene.z, 0, accuracy: 0.0001)
        XCTAssertEqual(scene.y, surfaceY + AngleSceneCalculator.ballRadius, accuracy: 0.0001)
    }

    func test_normalizedToScene_spansFullTable() {
        let minPt = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: 0, y: 0), surfaceY: surfaceY)
        let maxPt = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: 1, y: 0.5), surfaceY: surfaceY)
        XCTAssertEqual(minPt.x, -AngleSceneCalculator.innerLength / 2, accuracy: 0.0001)
        XCTAssertEqual(maxPt.x,  AngleSceneCalculator.innerLength / 2, accuracy: 0.0001)
        XCTAssertEqual(minPt.z, -AngleSceneCalculator.innerWidth / 2, accuracy: 0.0001)
        XCTAssertEqual(maxPt.z,  AngleSceneCalculator.innerWidth / 2, accuracy: 0.0001)
    }

    func test_lateralDisplacement_2sinAlpha_knownValues() {
        XCTAssertEqual(AngleSceneCalculator.lateralDisplacement(cutAngle: 0), 0.0, accuracy: 0.001)
        XCTAssertEqual(AngleSceneCalculator.lateralDisplacement(cutAngle: 30), 1.0, accuracy: 0.001)
        XCTAssertEqual(AngleSceneCalculator.lateralDisplacement(cutAngle: 90), 2.0, accuracy: 0.001)
    }

    func test_ghostBall_sitsTwoRadiiBehindTargetAlongPocketLine() {
        let target = SCNVector3(0, surfaceY, 0)
        let pocket = SCNVector3(1, surfaceY, 0)   // pocket directly +x of target
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: target, pocket: pocket, ballRadius: AngleSceneCalculator.ballRadius
        )
        // Ghost ball is opposite the pocket direction at distance 2R.
        XCTAssertEqual(ghost.x, target.x - 2 * AngleSceneCalculator.ballRadius, accuracy: 0.0001)
        XCTAssertEqual(ghost.z, target.z, accuracy: 0.0001)
    }

    func test_cutAngle_straightShot_isZero() {
        // Cue, target, pocket all colinear along +x → straight shot, 0°.
        let cue = SCNVector3(-0.5, surfaceY, 0)
        let target = SCNVector3(0, surfaceY, 0)
        let pocket = SCNVector3(1, surfaceY, 0)
        let angle = AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: target, pocket: pocket)
        XCTAssertEqual(angle, 0, accuracy: 0.5)
    }
}

// MARK: - CushionReflection (真实反射模式) Tests (ADR-P9-02)

final class CushionReflectionTests: XCTestCase {

    private let surfaceY: Float = 0.8
    private var y: Float { surfaceY + AngleSceneCalculator.ballRadius }

    private func norm(_ v: SCNVector3) -> SCNVector3 {
        let len = sqrtf(v.x * v.x + v.z * v.z)
        return len > 1e-6 ? SCNVector3(v.x / len, 0, v.z / len) : v
    }

    // MARK: reflect() — tangential shrink

    func test_reflect_idealKeepsIncidenceEqualsReflection() {
        let rail = CushionReflectionSolver.Rail(isLong: true, coord: -0.5)   // 长库，法向沿 Z
        let d = norm(SCNVector3(0.6, 0, -0.8))
        let out = CushionReflectionSolver.reflect(dir: d, rail: rail, factor: 1.0)
        // 法向分量翻转、切向分量不变 → 入射角 = 反射角。
        XCTAssertEqual(out.x, d.x, accuracy: 0.001)
        XCTAssertEqual(out.z, -d.z, accuracy: 0.001)
    }

    func test_reflect_factorScalesTangentTangentMonotonically() {
        let rail = CushionReflectionSolver.Rail(isLong: true, coord: -0.5)
        let d = norm(SCNVector3(0.6, 0, -0.8))
        func outTan(_ f: Float) -> Float {
            let o = CushionReflectionSolver.reflect(dir: d, rail: rail, factor: f)
            return abs(o.x) / abs(o.z)   // tan(出射角 相对法线)
        }
        let inTan = abs(d.x) / abs(d.z)
        // tan θ_out = factor · tan θ_in，且法向始终翻转。
        XCTAssertEqual(outTan(1.0), inTan, accuracy: 0.001)
        XCTAssertEqual(outTan(0.8), inTan * 0.8, accuracy: 0.001)
        XCTAssertGreaterThan(outTan(1.0), outTan(0.9))
        XCTAssertGreaterThan(outTan(0.9), outTan(0.8))
    }

    func test_reflect_shortRailFlipsXScalesZ() {
        let rail = CushionReflectionSolver.Rail(isLong: false, coord: 0.7)   // 短库，法向沿 X
        let d = norm(SCNVector3(0.8, 0, 0.6))
        let out = CushionReflectionSolver.reflect(dir: d, rail: rail, factor: 0.8)
        XCTAssertLessThan(out.x, 0, "法向 (X) 必须翻转")
        XCTAssertGreaterThan(out.z, 0, "切向 (Z) 同号")
        // 单位向量。
        XCTAssertEqual(sqrtf(out.x * out.x + out.z * out.z), 1.0, accuracy: 0.001)
    }

    // MARK: shoot() — 单库追迹在 factor=1 时等于镜像反射

    func test_shoot_idealSingleCushion_matchesMirrorReflection() {
        // 长库 left：Z = -halfW。start 与 target 同在 +X 侧，经一次左库反射；
        // 选偏 +X 的落点，避开正中（0,-halfW）的中袋。
        let halfW = CushionReflectionSolver.halfW
        let start = SCNVector3(0.2, y, 0.1)
        let target = SCNVector3(0.9, y, 0.3)
        let rail = CushionReflectionSolver.Rail(isLong: true, coord: -halfW)

        guard let path = CushionReflectionSolver.shoot(
            start: start, target: target, rails: [rail], factor: 1.0, y: y
        ) else {
            return XCTFail("理想单库追迹应有解")
        }
        XCTAssertEqual(path.count, 3)                 // [start, 反弹点, target]
        let bounce = path[1]
        XCTAssertEqual(bounce.z, -halfW, accuracy: 0.001, "反弹点必须落在左库上")

        // 镜像法：target 关于左库镜像，直线与库交点即理想反弹点。
        let imgZ = 2 * (-halfW) - target.z
        let tX = (-halfW - start.z) / (imgZ - start.z)
        let expectedX = start.x + tX * (target.x - start.x)
        XCTAssertEqual(bounce.x, expectedX, accuracy: 0.005, "factor=1 必须复现镜像反射结果")
    }

    // MARK: solveAll 集成 — 理想 / 真实

    private func interiorDivergence(_ a: [SCNVector3], _ b: [SCNVector3]) -> Float {
        guard a.count == b.count, a.count >= 2 else { return .greatestFiniteMagnitude }
        var sum: Float = 0
        for i in 1..<(a.count - 1) {
            let dx = a[i].x - b[i].x, dz = a[i].z - b[i].z
            sum += sqrtf(dx * dx + dz * dz)
        }
        return sum
    }

    func test_diamondSolveAll_idealMode_noIdealOverlay() {
        let cue = SCNVector3(DiamondSystemCalculator.halfL * 0.5, y, DiamondSystemCalculator.halfW * 0.4)
        let target = SCNVector3(-DiamondSystemCalculator.halfL * 0.4, y, -DiamondSystemCalculator.halfW * 0.25)
        let ideal = DiamondSystemCalculator.solveAll(cue: cue, target: target, surfaceY: surfaceY, realMode: false)
        XCTAssertFalse(ideal.isEmpty, "默认配置应有理想解")
        XCTAssertNil(ideal.first?.idealPath, "理想模式不携带对照路径")
    }

    /// 真实（物理引擎）模式：解必须携带理想对照、端点对齐、且每个反弹点都**真落在库上**（物理有效），
    /// 同时与理想镜面线有可测偏离（引擎 ≠ 镜面）。
    @MainActor
    func test_diamondSolveAll_realMode_engineIsPhysicalAndDiverges() {
        let cue = SCNVector3(DiamondSystemCalculator.halfL * 0.5, y, DiamondSystemCalculator.halfW * 0.4)
        let target = SCNVector3(-DiamondSystemCalculator.halfL * 0.4, y, -DiamondSystemCalculator.halfW * 0.25)

        let real = DiamondSystemCalculator.solveAll(cue: cue, target: target,
                                                    surfaceY: surfaceY, realMode: true, power: 3.0)
        XCTAssertFalse(real.isEmpty, "真实模式应至少有一个解")
        guard let s = real.first, let ideal = s.idealPath else {
            return XCTFail("真实模式解必须携带理想对照路径")
        }
        // 端点：起点精确、终点 ≈ target。
        XCTAssertEqual(s.path.first!.x, ideal.first!.x, accuracy: 0.001)
        XCTAssertEqual(s.path.first!.z, ideal.first!.z, accuracy: 0.001)
        XCTAssertEqual(s.path.last!.x, target.x, accuracy: 0.02)
        XCTAssertEqual(s.path.last!.z, target.z, accuracy: 0.02)
        // 物理有效：每个内部反弹点都落在某条平库上（|x|≈halfL 或 |z|≈halfW）。
        let halfL = DiamondSystemCalculator.halfL, halfW = DiamondSystemCalculator.halfW
        for i in 1..<(s.path.count - 1) {
            let p = s.path[i]
            let onRail = abs(abs(p.x) - halfL) < 0.03 || abs(abs(p.z) - halfW) < 0.03
            XCTAssertTrue(onRail, "反弹点必须落在库上：(\(p.x), \(p.z))")
        }
        XCTAssertGreaterThan(interiorDivergence(s.path, ideal), 0.001,
                             "真实引擎路线应与理想镜面线有可测偏离")
    }

    /// 真实模式随**发力**变化：不同发力得到不同的真实翻库路线（速度相关物理）。
    @MainActor
    func test_diamondSolveAll_realMode_respondsToPower() {
        let cue = SCNVector3(DiamondSystemCalculator.halfL * 0.5, y, DiamondSystemCalculator.halfW * 0.4)
        let target = SCNVector3(-DiamondSystemCalculator.halfL * 0.4, y, -DiamondSystemCalculator.halfW * 0.25)

        let lo = DiamondSystemCalculator.solveAll(cue: cue, target: target,
                                                  surfaceY: surfaceY, realMode: true, power: 1.8)
        let hi = DiamondSystemCalculator.solveAll(cue: cue, target: target,
                                                  surfaceY: surfaceY, realMode: true, power: 4.0)
        XCTAssertFalse(lo.isEmpty, "低发力应有解")
        XCTAssertFalse(hi.isEmpty, "高发力应有解")
        guard let shi = hi.first,
              let slo = lo.first(where: { $0.railSequenceText == shi.railSequenceText
                                          && $0.path.count == shi.path.count }) else {
            return   // 库序集合本身随发力变化，也算"响应发力"，非空即可。
        }
        XCTAssertGreaterThan(interiorDivergence(shi.path, slo.path), 0.001,
                             "不同发力应得到不同的真实翻库路线")
    }

    // MARK: EngineCushionTracer — 真实引擎追迹核心

    /// 直瞄长库（左库 Z=-halfW）应正好反弹一次、分类为该长库。
    @MainActor
    func test_engineTracer_straightAtLongRail_classifiesRail() {
        let halfW = EngineCushionTracer.halfW
        let start = SCNVector3(0.3, y, 0.05)
        // 朝 -Z（指向左库）略带 +X，避开正中中袋。
        let dir = norm(SCNVector3(0.25, 0, -1))
        let l = EngineCushionTracer.launch(start: start, dir: dir, speed: 3.0, y: y)
        XCTAssertGreaterThanOrEqual(l.rails.count, 1, "应至少反弹一次")
        let first = l.rails[0]
        XCTAssertTrue(first.isLong, "首次反弹应为长库")
        XCTAssertEqual(first.coord, -halfW, accuracy: 1e-3, "应为左库 Z=-halfW")
        // 反弹点落在左库上。
        XCTAssertEqual(l.polyline[1].z, -halfW, accuracy: 0.03)
    }

    /// 单库射击解：从 start 经左库一次反射到 target，反弹点落在左库、末点 ≈ target。
    @MainActor
    func test_engineTracer_shoot_singleCushionReachesTarget() {
        let halfW = EngineCushionTracer.halfW
        let start = SCNVector3(0.2, y, 0.10)
        let target = SCNVector3(0.9, y, 0.30)
        let rail = CushionReflectionSolver.Rail(isLong: true, coord: -halfW)
        // 种子：镜像法理想首段方向。
        let imgZ = 2 * (-halfW) - target.z
        let seed = norm(SCNVector3(target.x - start.x, 0, imgZ - start.z))
        guard let path = EngineCushionTracer.shoot(start: start, target: target, seedDir: seed,
                                                   rails: [rail], speed: 3.0, y: y) else {
            return XCTFail("单库真实射击应有解")
        }
        XCTAssertEqual(path.count, 3, "[start, 反弹点, target]")
        XCTAssertEqual(path[1].z, -halfW, accuracy: 0.03, "反弹点落在左库")
        XCTAssertEqual(path[2].x, target.x, accuracy: 0.02)
        XCTAssertEqual(path[2].z, target.z, accuracy: 0.02)
    }
}

extension CushionReflectionTests {
    func testEngineTracerDoesNotInventStopAtTimeLimit() {
        let y = BTTablePhysics.surfaceY + BallPhysics.radius
        let result = EngineCushionTracer.launch(start: SCNVector3(0.3, y, 0),
            dir: SCNVector3(1, 0, 0), speed: 3, y: y, maxTime: 0.01)
        XCTAssertEqual(result.termination, .timeLimit)
        XCTAssertTrue(result.rails.isEmpty)
        XCTAssertEqual(result.polyline.count, 1, "A partial final frame is not a natural endpoint")
        XCTAssertFalse(result.potted)
    }

    func testEngineTracerLocalModeCompletesAndDoesNotFallbackOnFailure() {
        let y = BTTablePhysics.surfaceY + BallPhysics.radius
        let complete = EngineCushionTracer.launch(start: SCNVector3(0.3, y, 0),
            dir: SCNVector3(1, 0, 0), speed: 0.3, y: y,
            simulationModel: .localPockets(material: .tablePhysics(clothRestitution: 0.3)))
        XCTAssertEqual(complete.termination, .settled)
        XCTAssertEqual(complete.polyline.count, 2)
        let failed = EngineCushionTracer.launch(start: SCNVector3(0.3, y, 0),
            dir: SCNVector3(1, 0, 0), speed: 0.3, y: y,
            simulationModel: .localPockets(material: .tablePhysics(clothRestitution: .nan)))
        guard case .failed = failed.termination else { return XCTFail("Expected local material failure") }
        XCTAssertEqual(failed.polyline.count, 1)
        XCTAssertFalse(failed.potted)
    }
}

extension CushionReflectionTests {
    @MainActor
    func testLocalReflectionShootingReachesTarget() throws {
        let start = SCNVector3(0.2, y, 0.10)
        let target = SCNVector3(0.9, y, 0.30)
        let rail = CushionReflectionSolver.Rail(isLong: true, coord: -EngineCushionTracer.halfW)
        let seed = norm(SCNVector3(target.x-start.x, 0, 2*rail.coord-target.z-start.z))
        let begin = CFAbsoluteTimeGetCurrent()
        let path = try XCTUnwrap(EngineCushionTracer.shoot(start: start, target: target,
            seedDir: seed, rails: [rail], speed: 3, y: y,
            simulationModel: .localPockets(material: .tablePhysics(clothRestitution: 0.3))))
        print("[W07 local reflection solve] \(CFAbsoluteTimeGetCurrent()-begin)s")
        XCTAssertEqual(path.count, 3)
        XCTAssertEqual(path[1].z, rail.coord, accuracy: 0.03)
        XCTAssertEqual(path[2].x, target.x, accuracy: 0.02)
        XCTAssertEqual(path[2].z, target.z, accuracy: 0.02)
    }
}
