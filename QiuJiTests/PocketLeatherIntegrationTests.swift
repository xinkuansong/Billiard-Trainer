import XCTest
import SceneKit
@testable import QiuJi

@MainActor
final class PocketLeatherIntegrationTests: XCTestCase {
    private func markers(_ scene: AngleTrainingScene) throws -> [PocketLeatherMarker] {
        let result = scene.addPocketMarkers().compactMap { $0 as? PocketLeatherMarker }
        XCTAssertNil(scene.pocketLeatherFailure)
        XCTAssertEqual(result.count, 6)
        return result
    }

    func testSixRegionsRestoreAndStayIsolatedAcrossPipelines() throws {
        let plain = AngleTrainingScene(); plain.setupScene()
        let enhanced = AngleTrainingScene(); enhanced.setupScene(enhancedRendering: true)
        let a = try markers(plain), b = try markers(enhanced)
        XCTAssertTrue(zip(a, try markers(plain)).allSatisfy { $0 === $1 })
        for i in 0..<6 {
            for (j, marker) in a.enumerated() { plain.setPocketHighlight(marker, style: i == j ? .selected : .viable) }
            XCTAssertEqual(a.filter { $0.style == .target }.map(\.pocketIndex), [i])
            XCTAssertTrue(b.allSatisfy { $0.style == .original })
            XCTAssertTrue(a.allSatisfy { $0.childNodes.filter { !$0.isHidden }.count == 1 })
            let original = try XCTUnwrap(a[i].childNodes.first?.geometry)
            let other = try XCTUnwrap(b[i].childNodes.first?.geometry)
            XCTAssertFalse(original.materials[0] === other.materials[0])
            XCTAssertEqual(original.elements[0].primitiveCount, i < 4 ? 2342 : 1468)
        }
        plain.clearPocketHighlights()
        XCTAssertTrue(a.allSatisfy { $0.style == .original })
        plain.setupScene()
        let reset = try markers(plain)
        XCTAssertTrue(reset.allSatisfy { $0.style == .original })
        var count = 0
        plain.rootNode.enumerateChildNodes { node,_ in if node is PocketLeatherMarker { count += 1 } }
        XCTAssertEqual(count, 6)
    }

    func testRealHitTestingHolesLeatherBallPriorityAndFixedQuestion() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        scene.setCameraMode(.topDown2DRotated, animated: false)
        let regions = try markers(scene)
        let view = SCNView(frame: CGRect(x:0,y:0,width:900,height:1400))
        view.scene = scene; view.pointOfView = scene.cameraNode
        _ = view.snapshot()
        let coordinator = AngleSceneView.Coordinator(scene:scene,cameraMode:.topDown2DRotated,interactionMode:.tapsOnly)
        coordinator.scnView = view
        var chosen: Int?
        coordinator.onPocketTapped = { chosen = $0 }
        for (i,p) in AngleSceneCalculator.pocketMarkerPositions(surfaceY:scene.surfaceY).enumerated() {
            let screen = view.projectPoint(p)
            chosen = nil
            coordinator.handleTap(at:CGPoint(x:CGFloat(screen.x),y:CGFloat(screen.y)))
            XCTAssertEqual(chosen,i,"hole \(i)")
            XCTAssertEqual(PocketLeatherMarker.index(of:regions[i].childNodes[0]),i)
        }
        let p = AngleSceneCalculator.pocketMarkerPositions(surfaceY:scene.surfaceY)[0]
        let ball = SCNNode(geometry:SCNSphere(radius:0.03)); ball.position=p;scene.rootNode.addChildNode(ball)
        coordinator.selectableBallNodes=[ball]
        var pickedBall=false;coordinator.onBallTapped={ _ in pickedBall=true }
        let screen=view.projectPoint(p);chosen=nil
        coordinator.handleTap(at:CGPoint(x:CGFloat(screen.x),y:CGFloat(screen.y)))
        XCTAssertTrue(pickedBall);XCTAssertNil(chosen)
        ball.removeFromParentNode(); coordinator.selectableBallNodes=[]
        let obstruction=SCNNode(geometry:SCNBox(width:0.25,height:0.03,length:0.25,chamferRadius:0))
        obstruction.position=SCNVector3(p.x,p.y+0.15,p.z);scene.rootNode.addChildNode(obstruction)
        SCNTransaction.flush(); _ = view.snapshot()
        chosen=nil
        coordinator.handleTap(at:CGPoint(x:CGFloat(screen.x),y:CGFloat(screen.y)))
        XCTAssertNil(chosen,"A foreground occluder must block both mesh hits and the projected-hole fallback")
        obstruction.removeFromParentNode()
        coordinator.onPocketTapped=nil
        coordinator.updatePocketAccessibility()
        XCTAssertTrue(view.accessibilityCustomActions?.isEmpty ?? true)
        coordinator.interactionMode = .none; pickedBall=false
        coordinator.handleTap(at:CGPoint(x:CGFloat(screen.x),y:CGFloat(screen.y)))
        XCTAssertFalse(pickedBall)
    }

    func testPlainAndEnhancedRenderingAndDualRoles() throws {
        for enhanced in [false,true] {
            let scene=AngleTrainingScene();scene.setupScene(enhancedRendering:enhanced)
            scene.setCameraMode(.topDown2DRotated,animated:false)
            let regions=try markers(scene)
            let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=scene;renderer.pointOfView=scene.cameraNode
            for index in 0..<6 {
                scene.setPocketRoles(first:index,second:index)
                XCTAssertEqual(regions[index].style,.bothRoles)
                let snapshot=renderer.snapshot(atTime:0,with:CGSize(width:900,height:1400),antialiasingMode:.multisampling4X)
                let dir=URL(fileURLWithPath:ProcessInfo.processInfo.environment["POCKET_EVIDENCE"] ?? URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("output/pocket-leather/W1/render").path)
                try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
                try XCTUnwrap(snapshot.pngData()).write(to:dir.appendingPathComponent("\(enhanced ? "enhanced" : "plain")-both-\(index).png"))
            }
        }
    }

    func testFixedQuestionAdvancesKeepExactlyItsPocketAcrossCameraModes() throws {
        let suite="PocketLeatherQuiz.\(UUID().uuidString)"
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
        defer { defaults.removePersistentDomain(forName:suite) }
        let limiter=AngleUsageLimiter(defaults:defaults);limiter.isPremium=true
        for mode: AngleTrainingScene.CameraMode in [.topDown2DRotated,.perspective3D] {
            let quiz=AimingQuizViewModel(limiter:limiter)
            quiz.setupScene(initialCameraMode:mode)
            let nodes=try markers(quiz.scene)
            for _ in 0..<4 {
                let question=try XCTUnwrap(quiz.currentQuestion)
                XCTAssertEqual(nodes.filter { $0.style == .target }.map(\.pocketIndex),[question.pocketIndex])
                quiz.toggleAimingAssist()
                XCTAssertEqual(nodes.filter { $0.style == .target }.map(\.pocketIndex),[question.pocketIndex])
                quiz.openAnswerInput();quiz.userInput=String(question.actualAngle);quiz.submitAnswer()
                XCTAssertEqual(quiz.sessionResults.last?.question.pocketIndex,question.pocketIndex)
                quiz.advanceToNext()
            }
            let point=AimPointSceneQuizViewModel(limiter:limiter);point.setupScene(cameraMode:mode)
            let pointNodes=try markers(point.scene)
            for _ in 0..<4 {
                XCTAssertEqual(pointNodes.filter { $0.style == .target }.map(\.pocketIndex),[try XCTUnwrap(point.question).pocketIndex])
                point.nextQuestion()
            }
        }
    }

    func testPerspectiveSixPocketHitsAndSelections() throws {
        let directory=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("output/pocket-leather/W4/perspective")
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        for enhanced in [false,true] {
            let scene=AngleTrainingScene();scene.setupScene(enhancedRendering:enhanced)
            let nodes=try markers(scene)
            let camera=SCNNode();camera.camera=SCNCamera();camera.camera?.fieldOfView=50
            camera.position=SCNVector3(0,6,3);scene.rootNode.addChildNode(camera)
            camera.look(at:SCNVector3(0,scene.surfaceY,0))
            let view=SCNView(frame:CGRect(x:0,y:0,width:1000,height:1000));view.scene=scene;view.pointOfView=camera
            SCNTransaction.flush(); _=view.snapshot()
            let coordinator=AngleSceneView.Coordinator(scene:scene,cameraMode:.perspective3D,interactionMode:.tapsOnly)
            coordinator.scnView=view
            var picked:Int?
            coordinator.onPocketTapped={ index in
                picked=index
                for node in nodes { scene.setPocketHighlight(node,style:node.pocketIndex == index ? .selected : .viable) }
            }
            for (index,point) in AngleSceneCalculator.pocketMarkerPositions(surfaceY:scene.surfaceY).enumerated() {
                let screen=view.projectPoint(point);picked=nil
                coordinator.handleTap(at:CGPoint(x:CGFloat(screen.x),y:CGFloat(screen.y)))
                XCTAssertEqual(picked,index)
                XCTAssertEqual(nodes.filter { $0.style == .target }.map(\.pocketIndex),[index])
                SCNTransaction.flush()
                try XCTUnwrap(view.snapshot().pngData()).write(to:directory.appendingPathComponent("\(enhanced ? "enhanced" : "plain")-target-\(index).png"))
            }
        }
    }

    func testMalformedMeshIsDiagnosedWithoutChangingOriginal() throws {
        let table=SCNNode()
        XCTAssertThrowsError(try PocketLeatherMesh.extract(from:table,centers:AngleSceneCalculator.pocketPositions(surfaceY:0.8)))
        let e=SCNGeometryElement(data:Data([1,2,3]),primitiveType:.triangles,primitiveCount:1,bytesPerIndex:4)
        XCTAssertThrowsError(try PocketLeatherMesh.decode(e))
        XCTAssertTrue(table.childNodes.isEmpty)
    }

    func testCompactionPreservesEveryPolygonCornerAttribute() throws {
        let scene=AngleTrainingScene();scene.setupScene()
        let raw=try PocketLeatherMesh.extract(from:try XCTUnwrap(scene.tableNode),centers:AngleSceneCalculator.pocketPositions(surfaceY:scene.surfaceY))
        func values(_ geometry:SCNGeometry) throws -> Data {
            var result=Data()
            for element in geometry.elements {
                for face in try PocketLeatherMesh.decode(element) {
                    var count=UInt32(face.count / element.indicesChannelCount)
                    withUnsafeBytes(of:&count) { result.append(contentsOf:$0) }
                    for base in stride(from:0,to:face.count,by:element.indicesChannelCount) {
                        for (i,source) in geometry.sources.enumerated() {
                            let channel=geometry.geometrySourceChannels?[i].intValue ?? 0
                            let index=Int(face[base+channel])
                            let start=source.dataOffset + index * source.dataStride
                            result.append(source.data[start..<(start + source.bytesPerComponent * source.componentsPerVector)])
                        }
                    }
                }
            }
            return result
        }
        for geometry in raw.parts.map(\.geometry) + raw.replacements.map(\.geometry) {
            let compact=try PocketLeatherMesh.compact(geometry)
            XCTAssertEqual(try values(geometry),try values(compact),"Every corner's position/normal/UV bytes and polygon order must remain exact")
            var positions=Set<UInt32>()
            for element in compact.elements {
                for face in try PocketLeatherMesh.decode(element) {
                    for slot in stride(from:0,to:face.count,by:element.indicesChannelCount) { positions.insert(face[slot]) }
                }
            }
            XCTAssertEqual(positions.count,compact.sources(for:.vertex)[0].vectorCount,"No unused position may reach iOS 17 Deindexing")
        }
    }

    func testNeutralThumbnailAfterSelectedScene() async throws {
        let selected=AngleTrainingScene();selected.setupScene()
        let nodes=try markers(selected);selected.setPocketHighlight(nodes[0],style:.selected)
        let fresh=try XCTUnwrap(TableModelLoader.loadTable())
        var leatherFaces=0
        fresh.visualNode.enumerateChildNodes { node,_ in
            guard let g=node.geometry else { return }
            for (i,e) in g.elements.enumerated() where g.materials[i % g.materials.count].name == "Leather" {
                leatherFaces += e.primitiveCount
                XCTAssertFalse(g.materials[i % g.materials.count].shaderModifiers?[.surface]?.contains("pocketLeatherTint") ?? false)
            }
        }
        XCTAssertEqual(leatherFaces,12304)
        let loaded=await DrillContentService.shared.loadDrillFromBundle(id:"drill_c001")
        let drill=try XCTUnwrap(loaded)
        let thumbnail=try XCTUnwrap(DrillThumbnailRenderer.render(drill:drill))
        let directory=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("output/pocket-leather/W4/neutral")
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        try XCTUnwrap(thumbnail.pngData()).write(to:directory.appendingPathComponent("thumbnail.png"))
    }

    func testArchivedPocketAndFreeSequenceStepsRestoreSelection() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
        let directory=root.appendingPathComponent("content/position_play/sequences")
        let files=try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)
        let mixed=try XCTUnwrap(files.first { $0.lastPathComponent.hasPrefix("drill_c060__") })
        let decoder=JSONDecoder();decoder.dateDecodingStrategy = .iso8601
        let mixedSequence=try decoder.decode(PositionPlaySequence.self,from:Data(contentsOf:mixed))
        XCTAssertTrue(mixedSequence.steps.contains { $0.shot.isFree })
        XCTAssertTrue(mixedSequence.steps.contains { !$0.shot.isFree })
        let other=try XCTUnwrap(files.first { $0.lastPathComponent.hasPrefix("drill_c042__") })
        let pocketSequence=try decoder.decode(PositionPlaySequence.self,from:Data(contentsOf:other))
        let vm=PositionPlayViewModel();vm.setupScene()
        for step in mixedSequence.steps + pocketSequence.steps {
            vm.configureSequence([step]);vm.enterSequenceMode()
            let highlighted=try markers(vm.scene).filter { $0.style == .target }.map(\.pocketIndex)
            if step.shot.isFree { XCTAssertTrue(highlighted.isEmpty) }
            else { XCTAssertEqual(highlighted,[try XCTUnwrap(ShotIntent.pocketIndex(for:step.shot.pocket))]) }
            vm.exitSequenceMode()
        }
        vm.clearTable()
    }

    func testPlanRolesSameDifferentClearAndOneBall() throws {
        let vm=PlanThreeViewModel();vm.setupScene();vm.uiTestConfigure("twoBall")
        let nodes=try markers(vm.scene)
        XCTAssertEqual(nodes[1].style,.firstRole);XCTAssertEqual(nodes[3].style,.secondRole)
        vm.armRole(.pocket2);vm.selectPocket(at:1)
        XCTAssertEqual(nodes[1].style,.bothRoles);XCTAssertEqual(nodes[3].style,.original)
        vm.armRole(.pocket1)
        XCTAssertEqual(nodes[1].style,.bothRoles,"Arming a role must not erase either target")
        vm.selectPocket(at:4)
        XCTAssertEqual(nodes[4].style,.firstRole);XCTAssertEqual(nodes[1].style,.secondRole)
        let shot=PlannedShot(targetKey:"_1",pocket:"topRight",velocity:2,spinX:0,spinY:0)
        let saved=vm.makeUndoContext(shot:shot,prediction:ShotPrediction())
        vm.clearPlan();XCTAssertTrue(nodes.allSatisfy { $0.style == .original })
        vm.restore(from:saved)
        XCTAssertEqual(nodes[4].style,.firstRole);XCTAssertEqual(nodes[1].style,.secondRole)
        vm.startBreakFlow(game:.nineBall)
        XCTAssertTrue(nodes.allSatisfy { $0.style == .original })
        vm.cancelBreakFlow()
        vm.uiTestConfigure("oneBall")
        XCTAssertEqual(nodes[4].style,.firstRole)
        XCTAssertEqual(nodes.filter { $0.style != .original }.count,1)
        vm.uiTestConfigure("cleared")
        XCTAssertTrue(nodes.allSatisfy { $0.style == .original })
    }


    func testPlanRealSolvePlayAndUndoRestoreLeather() async throws {
        let vm=PlanThreeViewModel();vm.setupScene();vm.uiTestConfigure("oneBall")
        let nodes=try markers(vm.scene)
        vm.solve()
        let deadline=Date().addingTimeInterval(15)
        while vm.isComputing && Date() < deadline { try await Task.sleep(nanoseconds:20_000_000) }
        XCTAssertFalse(vm.isComputing)
        let solution=try XCTUnwrap(vm.currentSolution)
        XCTAssertTrue(vm.canStrike)
        let before=nodes.map(\.style)
        vm.play()
        XCTAssertTrue(vm.isPlaying)
        XCTAssertTrue(nodes.allSatisfy { $0.style == .original },"Playback hides planning highlights")
        // Deliver the actual solver result at the production completion boundary;
        // this unit test does not run the wall-clock SCNAction animation.
        vm.finishStrike(sol:solution)
        XCTAssertFalse(vm.isPlaying)
        XCTAssertTrue(vm.canUndoShot)
        vm.undoLastShot()
        XCTAssertEqual(nodes.map(\.style),before)
    }

    func testPlanAdvanceRecolorsOldSecondAsFirstAndRestoreReturnsBoth() throws {
        let vm=PlanThreeViewModel();vm.setupScene();vm.uiTestConfigure("twoBall")
        let nodes=try markers(vm.scene)
        let oldSecond=try XCTUnwrap(vm.ball2Key)
        let shot=PlannedShot(targetKey:try XCTUnwrap(vm.ball1Key),pocket:"topRight",velocity:2,spinX:0,spinY:0)
        var prediction=ShotPrediction()
        prediction.objectPocketed=true
        prediction.pocketedBalls=[ShotInput.targetBallName]
        let saved=vm.makeUndoContext(shot:shot,prediction:prediction)
        let solution=PositionPlaySolution(shot:shot,prediction:prediction,cushionCount:0,potted:true,
            margin:0.1,summary:"deterministic completion",satisfiesConstraint:true,
            beyondCushionBudget:false,difficultyScore:0,difficultyTier:.center,beyondSpinBudget:false,robustness:nil)
        vm.finishStrike(sol:solution)
        XCTAssertEqual(vm.ball1Key,oldSecond)
        XCTAssertEqual(vm.pocket1Index,3)
        XCTAssertEqual(nodes[3].style,.firstRole)
        XCTAssertEqual(nodes[1].style,.original)
        XCTAssertEqual(nodes.filter { $0.style != .original }.count,1)
        vm.restore(from:saved)
        XCTAssertEqual(nodes[1].style,.firstRole)
        XCTAssertEqual(nodes[3].style,.secondRole)
    }

    func testReproduceClearAndBreakStaleSelection() throws {
        let position=PositionPlayViewModel();position.setupScene();position.selectPocket(at:1)
        XCTAssertEqual(try markers(position.scene).filter { $0.style == .target }.count,1)
        position.clearTable()
        XCTAssertTrue(try markers(position.scene).allSatisfy { $0.style == .original },"PositionPlay clear must remove target")
        position.resetAll();position.selectPocket(at:2)
        position.aimMode = .free
        XCTAssertTrue(try markers(position.scene).allSatisfy { $0.style == .original })
        position.aimMode = .pocket
        XCTAssertEqual(try markers(position.scene).filter { $0.style == .target }.map(\.pocketIndex),[2])
        position.startBreakFlow(game:.nineBall)
        XCTAssertTrue(try markers(position.scene).allSatisfy { $0.style == .original })
        position.cancelBreakFlow()
        XCTAssertEqual(try markers(position.scene).filter { $0.style == .target }.count,1)
        position.loadBoard(BoardSnapshot(onTable:[PositionPlayBall.cueKey:CanvasPoint(x:0.3,y:0.3)]))
        XCTAssertTrue(try markers(position.scene).allSatisfy { $0.style == .original })
        let silu=SiluTrainerViewModel();silu.setupScene();silu.selectPocket(at:1);silu.clearTable()
        XCTAssertTrue(try markers(silu.scene).allSatisfy { $0.style == .original },"Silu clear must remove target")
        silu.resetAll();silu.selectPocket(at:3);silu.startBreakFlow(game:.nineBall)
        XCTAssertTrue(try markers(silu.scene).allSatisfy { $0.style == .original })
        silu.cancelBreakFlow()
        XCTAssertEqual(try markers(silu.scene).filter { $0.style == .target }.count,1)
        silu.loadBoard(BoardSnapshot(onTable:[PositionPlayBall.cueKey:CanvasPoint(x:0.3,y:0.3)]))
        XCTAssertTrue(try markers(silu.scene).allSatisfy { $0.style == .original })
    }
}
