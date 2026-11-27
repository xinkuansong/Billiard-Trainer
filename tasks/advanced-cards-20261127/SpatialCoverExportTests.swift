import XCTest
import SceneKit
@testable import CuePhys

/// Reproducible production-art export using the app scene and admitted physics.
final class SpatialCoverExportTests: XCTestCase {
    @MainActor func testExportSpatialCovers() throws {
        for mode in SpatialQuizMode.allCases {
            let questions = try SpatialQuizBank.load(mode).questions
            var q = try XCTUnwrap(questions.first)
            if mode == .masse {
                var best = 0.0
                for candidate in questions.filter({ $0.reference.elevation >= 15 }).prefix(100) {
                    let result = SpatialQuizPhysics.solve(board: candidate.board, input: candidate.reference)
                    let deviation = result.facts.technique?.chordDeviation ?? 0
                    if result.outcome.succeeded && deviation / candidate.distance > best { q = candidate; best = deviation / candidate.distance }
                }
                print("COVER masse deviation \(best), question \(q.id)")
            }
            let solved = SpatialQuizPhysics.solve(board: q.board, input: q.reference)
            XCTAssertTrue(solved.outcome.succeeded)
            let shot = try XCTUnwrap(SpatialPracticeRecord.freeze(prediction: solved.prediction,
                input: q.reference.spatialInput, before: SpatialQuizInstance(q).board))
            let scene = AngleTrainingScene()
            scene.setupScene(recipe: .liveReference)
            scene.setCameraMode(.perspective3D, animated: false)
            scene.hideAllBalls(); scene.hideAllVisualization()
            for (key, pose) in shot.before { scene.showBall(key: key, scenePosition: pose.position.scene) }
            scene.configureBallInstances([q.board.targetName, "_8"])
            let path = SCNNode()
            SpatialShotRendering.appendBallRoute(shot, key: PositionPlayBall.cueKey, detail: .minimal, to: path, scene: scene)
            scene.rootNode.addChildNode(path)
            if mode == .jump {
                let peak = try XCTUnwrap(shot.paths[PositionPlayBall.cueKey]?.filter { $0.time <= (shot.firstContactTime ?? 0) }.max { $0.position.y < $1.position.y })
                scene.cueBallNode?.position = peak.position.scene
            } else {
                scene.updateCueStick(cueBallPosition: q.board.cue, aimDirection: q.reference.aim,
                    elevationOverride: q.reference.radians, updatesCamera: false)
            }
            let center = SCNVector3((q.board.cue.x + q.board.target.x)/2, scene.surfaceY + 0.05,
                (q.board.cue.z + q.board.target.z)/2)
            let camera = SCNNode();camera.camera = scene.cameraNode.camera?.copy() as? SCNCamera
            camera.camera?.zNear = 0.01;camera.camera?.zFar = 50;camera.camera?.fieldOfView = 42
            scene.rootNode.addChildNode(camera)
            let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
            renderer.scene = scene; renderer.pointOfView = camera; renderer.delegate = scene.contactOcclusion
            for variant in 0..<(mode == .jump ? 2 : 1) {
                let dx = q.board.target.x - q.board.cue.x, dz = q.board.target.z - q.board.cue.z
                let length = sqrt(dx*dx+dz*dz)
                let ux = dx/length, uz = dz/length
                var focus = center
                if mode == .masse {
                    focus = SCNVector3(q.board.cue.x+ux*0.42, scene.surfaceY+0.03, q.board.cue.z+uz*0.42)
                    camera.position = SCNVector3(q.board.cue.x-ux*0.38-uz*0.45, scene.surfaceY+0.9, q.board.cue.z-uz*0.38+ux*0.45)
                } else if variant == 0 {
                    focus = SCNVector3(q.board.obstacle.x, scene.surfaceY+0.08, q.board.obstacle.z)
                    camera.position = SCNVector3(focus.x-ux*0.22+uz*0.64, scene.surfaceY+0.26, focus.z-uz*0.22-ux*0.64)
                } else {
                    focus = SCNVector3(q.board.cue.x+ux*0.32, scene.surfaceY+0.05, q.board.cue.z+uz*0.32)
                    camera.position = SCNVector3(q.board.cue.x-ux*0.5-uz*0.44, scene.surfaceY+0.65, q.board.cue.z-uz*0.5+ux*0.44)
                    scene.cueBallNode?.position = q.board.cue
                    scene.updateCueStick(cueBallPosition: q.board.cue, aimDirection: q.reference.aim,
                        elevationOverride: q.reference.radians, updatesCamera: false)
                }
                camera.look(at: focus)
                SCNTransaction.flush()
                _ = renderer.snapshot(atTime: 0, with: CGSize(width: 400,height: 300), antialiasingMode: .multisampling4X)
                let image = renderer.snapshot(atTime: 1, with: CGSize(width: 1600,height: 1200), antialiasingMode: .multisampling4X)
                let attachment = XCTAttachment(image: image)
                attachment.name = mode == .masse ? "coverPracticeMasseExercise" : variant == 0 ? "coverPracticeJumpExercise" : "coverPracticeMasseJump"
                attachment.lifetime = .keepAlways;add(attachment)
            }
            let source = try JSONEncoder().encode(q)
            let metadata = XCTAttachment(data: source, uniformTypeIdentifier: "public.json")
            metadata.name = "cover-source-" + mode.rawValue;metadata.lifetime = .keepAlways;add(metadata)
        }
    }
}
