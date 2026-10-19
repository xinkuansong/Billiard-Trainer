import XCTest
import SceneKit
@testable import QiuJi

@MainActor
final class CustomFormationTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("CustomFormationTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    private func template() -> CustomFormationTemplate {
        let keys = (0..<3).map { _ in PositionPlayBall.instanceKey(number: 1) }
        var board = [PositionPlayBall.cueKey: CanvasPoint(x: 0.25, y: 0.35)]
        for (i, key) in keys.enumerated() { board[key] = CanvasPoint(x: 0.35 + Double(i) * 0.12, y: 0.25) }
        return .init(name: "三颗同号球", ballKeys: keys, board: .init(onTable: board))
    }

    func testRepeatedNumbersSurviveAtomicSaveReloadAndCopy() throws {
        let library = CustomFormationLibrary(ownerKey: "guest:test", directory: directory)
        let original = template()
        XCTAssertTrue(library.save(original))
        let reopened = CustomFormationLibrary(ownerKey: "guest:test", directory: directory)
        let loaded = try XCTUnwrap(reopened.selected)
        XCTAssertEqual(loaded.ballKeys, original.ballKeys)
        XCTAssertEqual(loaded.ballKeys.compactMap(PositionPlayBall.number), [1, 1, 1])
        XCTAssertEqual(loaded.board.onTable.count, 4)
        reopened.duplicate(loaded)
        let copy = try XCTUnwrap(reopened.selected)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertTrue(Set(copy.ballKeys).isDisjoint(with: original.ballKeys))
        reopened.delete(copy.id)
        XCTAssertEqual(reopened.templates.map(\.id), [original.id])
        XCTAssertNil(reopened.selected)
    }

    func testOwnerIsolationAndInvalidSavePreserveExistingTemplate() throws {
        let a = CustomFormationLibrary(ownerKey: "account:a", directory: directory)
        let b = CustomFormationLibrary(ownerKey: "account:b", directory: directory)
        let original = template(); XCTAssertTrue(a.save(original)); XCTAssertTrue(b.templates.isEmpty)
        var invalid = original; invalid.name = "  "
        XCTAssertFalse(a.save(invalid)); XCTAssertNotNil(a.error)
        let loaded = CustomFormationLibrary(ownerKey: "account:a", directory: directory)
        XCTAssertEqual(loaded.selected?.name, original.name)
    }

    func testCorruptArchiveIsNotOverwritten() throws {
        let repository = CustomFormationRepository(ownerKey: "bad", directory: directory)
        let bytes = Data("not JSON".utf8); try bytes.write(to: repository.url)
        let library = CustomFormationLibrary(ownerKey: "bad", directory: directory)
        XCTAssertTrue(library.failedToLoad); XCTAssertFalse(library.save(template()))
        XCTAssertEqual(try Data(contentsOf: repository.url), bytes)
    }

    func testRejectsDuplicateIdentityMissingCueAndInvalidCoordinates() throws {
        var value = template(); value.ballKeys[1] = value.ballKeys[0]
        XCTAssertThrowsError(try value.validated())
        value = template(); value.board.onTable.removeValue(forKey: PositionPlayBall.cueKey)
        XCTAssertThrowsError(try value.validated())
        value = template(); value.board.onTable[value.ballKeys[0]] = CanvasPoint(x: .nan, y: 0.2)
        XCTAssertThrowsError(try value.validated())
        for n in 1...15 { XCTAssertEqual(PositionPlayBall.number(for: "_\(n)"), n) }
        XCTAssertFalse(PositionPlayBall.isInstance("_1@bad"))
        XCTAssertNil(PositionPlayBall.number(for: "_16"))
    }

    func testInstancesRemainIndependentThroughRemovalReturnResetAndTrial() throws {
        let original = template()
        let session = CustomFormationSession(template: original, editing: false)
        session.vm.setupScene(loadsDefaultLayout: false); session.setup()
        defer { session.vm.cancelDailyAttempt() }
        XCTAssertEqual(Set(session.vm.onTableKeys), Set(original.ballKeys + [PositionPlayBall.cueKey]))
        let first = original.ballKeys[0], second = original.ballKeys[1]
        let firstNode = try XCTUnwrap(session.vm.scene.allBallNodes[first])
        let secondNode = try XCTUnwrap(session.vm.scene.allBallNodes[second])
        XCTAssertFalse(firstNode === secondNode)
        let secondPosition = secondNode.position
        session.remove(first)
        XCTAssertFalse(session.vm.onTableKeys.contains(first)); XCTAssertTrue(session.keys.contains(first))
        session.place(first, world: SCNVector3(0.5, session.vm.scene.surfaceY, -0.3))
        XCTAssertEqual(session.keys.count, 3)
        XCTAssertEqual(secondNode.position.x, secondPosition.x)
        XCTAssertEqual(secondNode.position.z, secondPosition.z)
        session.reset()
        XCTAssertEqual(try XCTUnwrap(session.vm.currentSnapshot().onTable[first]).x,
                       try XCTUnwrap(original.board.onTable[first]).x, accuracy: 0.000001)

        let editor = CustomFormationSession(template: original, editing: true)
        editor.vm.setupScene(loadsDefaultLayout: false); editor.setup()
        defer { editor.vm.cancelDailyAttempt() }
        editor.remove(first)
        XCTAssertEqual(editor.keys.count, 2)
        editor.undoEdit()
        XCTAssertEqual(editor.keys, original.ballKeys)
        editor.redoEdit()
        XCTAssertEqual(editor.keys.count, 2)
        XCTAssertFalse(editor.vm.canReplay)
        XCTAssertEqual(original.board.onTable.count, 4)
    }

    func testLineIncludesEndpointsAndSingleBallMidpoint() throws {
        let a = SCNVector3(-0.6,0,0), b = SCNVector3(0.6,0,0)
        for count in [1,2,3,16] {
            let line = try XCTUnwrap(FormationGeometry.line(a:a,b:b,count:count))
            XCTAssertEqual(line.count,count)
            XCTAssertEqual(line.first!.x,count == 1 ? 0 : a.x,accuracy:1e-6)
            XCTAssertEqual(line.last!.x,count == 1 ? 0 : b.x,accuracy:1e-6)
            for pair in zip(line,line.dropFirst()) { XCTAssertGreaterThanOrEqual(pair.1.x-pair.0.x,2*BallPhysics.radius-1e-6) }
        }
        XCTAssertNil(FormationGeometry.line(a:a,b:b,count:Int.max))
    }

    func testMeasurementAnglesAndDegenerateInput() {
        let o = SCNVector3Zero
        XCTAssertEqual(FormationGeometry.angle(SCNVector3(1,0,0),vertex:o,SCNVector3(0,0,1))!,90,accuracy:1e-6)
        XCTAssertEqual(FormationGeometry.angle(SCNVector3(1,0,0),vertex:o,SCNVector3(1,0,1))!,45,accuracy:1e-6)
        XCTAssertEqual(FormationGeometry.angle(SCNVector3(1,0,0),vertex:o,SCNVector3(-1,0,0))!,180,accuracy:1e-6)
        XCTAssertNil(FormationGeometry.angle(o,vertex:o,SCNVector3(1,0,1)))
    }
    private func editor() -> CustomFormationSession {
        let s = CustomFormationSession(template:nil,editing:true)
        s.vm.setupScene(loadsDefaultLayout:false); s.setup(); return s
    }
    func testManualAdditionConnectedEndpointDragAndUndo() throws {
        let s = editor(); defer { s.vm.cancelDailyAttempt() }
        s.beginTool(.line)
        s.editorTableTapped(SCNVector3(-0.5,0,-0.3)); s.editorTableTapped(SCNVector3(0.5,0,-0.3))
        XCTAssertEqual(s.keys.count,0)
        for _ in 0..<3 { s.place("_1",world:nil) }
        XCTAssertEqual(s.lineBallCount,3)
        XCTAssertEqual(s.lineSpacingCM!,50,accuracy:0.0001)
        let sharedID = s.drawing.lines[0].end
        let sharedBall = try XCTUnwrap(s.drawing.lines[0].balls.last)
        s.beginTool(.line)
        s.editorTableTapped(SCNVector3(0.5,0,-0.3)); s.editorTableTapped(SCNVector3(0.5,0,0.4))
        XCTAssertEqual(s.drawing.vertices.count,3)
        XCTAssertEqual(s.drawing.lines[1].start,sharedID)
        s.place("_2",world:nil); s.place("_2",world:nil)
        XCTAssertEqual(s.keys.count,5)
        XCTAssertEqual(s.lineBallCount,3)
        XCTAssertEqual(s.drawing.lines[1].balls.first,sharedBall)
        let handle = try XCTUnwrap(s.precisionHandles.first)
        s.editorDragBegan(handle); s.editorDragMoved(handle,world:SCNVector3(0.7,0,-0.3)); s.editorDragEnded(handle)
        for line in s.drawing.lines {
            let positions = line.balls.map { s.vm.scene.allBallNodes[$0]!.position }
            XCTAssertEqual(AngleSceneCalculator.horizontalDistance(positions[0],positions[1]),AngleSceneCalculator.horizontalDistance(positions[1],positions[2]),accuracy:0.00001)
        }
        XCTAssertEqual(s.vm.scene.allBallNodes[sharedBall]!.position.x,0.7,accuracy:1e-5)
        s.undoEdit(); XCTAssertEqual(s.drawing.vertices.first { $0.id == sharedID }!.x,0.5,accuracy:1e-5)
        s.redoEdit(); XCTAssertEqual(s.drawing.vertices.first { $0.id == sharedID }!.x,0.7,accuracy:1e-5)
        let saved = try s.templateForSaving(), copy = saved.copied()
        XCTAssertEqual(copy.drawing?.lines.count,2)
        XCTAssertTrue(Set(copy.drawing!.lines.flatMap(\.balls)).isSubset(of:Set(copy.ballKeys)))
        let encoded = try JSONEncoder().encode(saved)
        let restored = try JSONDecoder().decode(CustomFormationTemplate.self,from:encoded)
        XCTAssertEqual(restored.drawing,saved.drawing)
    }
    func testSortCyclesPreserveSharedJointsAndUndo() throws {
        let s = editor(); defer { s.vm.cancelDailyAttempt() }
        s.beginTool(.line)
        s.editorTableTapped(SCNVector3(-0.6,0,-0.3)); s.editorTableTapped(SCNVector3(0.6,0,-0.3))
        for (number,x) in [(3,Float(-0.6)),(1,Float(0)),(2,Float(0.6))] {
            s.place("_\(number)",world:SCNVector3(x,0,-0.3))
        }
        let first = s.drawing.lines[0]
        XCTAssertEqual(first.balls.compactMap(PositionPlayBall.number),[3,1,2])
        s.beginTool(.line)
        s.editorTableTapped(SCNVector3(0.6,0,-0.3)); s.editorTableTapped(SCNVector3(0.6,0,0.4))
        s.place("_4",world:SCNVector3(0.6,0,0.4))
        let originalGraph = s.drawing
        let originalBoard = s.vm.currentSnapshot()
        s.selectedLineID = first.id
        for expected in [[1,2,3],[3,2,1],[3,1,2]] {
            s.sortSelectedLine(startPrecedesEnd:true)
            XCTAssertEqual(s.drawing.lines[0].balls.compactMap(PositionPlayBall.number),expected)
            XCTAssertEqual(s.drawing.lines[0].balls.last,s.drawing.lines[1].balls.first)
            XCTAssertEqual(s.keys.count,4)
            for line in s.drawing.lines {
                let a = s.drawing.vertex(line.start,y:0)!, b = s.drawing.vertex(line.end,y:0)!
                for (key,p) in zip(line.balls,FormationGeometry.line(a:a,b:b,count:line.balls.count)!) {
                    let node = s.vm.scene.allBallNodes[key]!
                    XCTAssertEqual(node.position.x,p.x,accuracy:1e-6)
                    XCTAssertEqual(node.position.z,p.z,accuracy:1e-6)
                }
            }
        }
        XCTAssertEqual(s.drawing,originalGraph)
        for (key,p) in originalBoard.onTable {
            XCTAssertEqual(s.vm.currentSnapshot().onTable[key]?.x,p.x)
            XCTAssertEqual(s.vm.currentSnapshot().onTable[key]?.y,p.y)
        }
        s.undoEdit()
        XCTAssertEqual(s.drawing.lines[0].balls.compactMap(PositionPlayBall.number),[3,2,1])
        XCTAssertEqual(s.lineSorts[first.id]?.reversed,true)
        s.redoEdit(); XCTAssertEqual(s.drawing,originalGraph)
        XCTAssertNil(s.lineSorts[first.id])
        XCTAssertNoThrow(try s.templateForSaving().validated())
    }
    func testReverseDrawnLineSortDuplicateIdentityAndMembershipReset() throws {
        let s = editor(); defer { s.vm.cancelDailyAttempt() }
        s.beginTool(.line)
        s.editorTableTapped(SCNVector3(0.6,0,-0.3)); s.editorTableTapped(SCNVector3(-0.6,0,-0.3))
        for (number,x) in [(2,Float(0.6)),(1,Float(0)),(1,Float(-0.6))] {
            s.place("_\(number)",world:SCNVector3(x,0,-0.3))
        }
        let original = s.selectedLine!.balls, id = s.selectedLine!.id
        s.sortSelectedLine(startPrecedesEnd:false)
        XCTAssertEqual(s.selectedLine!.balls.compactMap(PositionPlayBall.number),[2,1,1])
        XCTAssertEqual(Set(s.selectedLine!.balls),Set(original))
        s.sortSelectedLine(startPrecedesEnd:false)
        XCTAssertEqual(s.selectedLine!.balls.compactMap(PositionPlayBall.number),[1,1,2])
        s.sortSelectedLine(startPrecedesEnd:false)
        XCTAssertEqual(s.selectedLine!.balls,original)
        s.sortSelectedLine(startPrecedesEnd:false)
        s.place("_4",world:nil)
        XCTAssertNil(s.lineSorts[id])
        let newOrder = s.selectedLine!.balls
        for _ in 0..<3 { s.sortSelectedLine(startPrecedesEnd:false) }
        XCTAssertEqual(s.selectedLine!.balls,newOrder)
    }
    func testSortUsesScreenDirectionIncludingVertical() {
        XCTAssertTrue(FormationGeometry.startPrecedesEnd(CGPoint(x:10,y:40),CGPoint(x:90,y:10)))
        XCTAssertFalse(FormationGeometry.startPrecedesEnd(CGPoint(x:90,y:10),CGPoint(x:10,y:40)))
        XCTAssertTrue(FormationGeometry.startPrecedesEnd(CGPoint(x:20,y:10),CGPoint(x:20,y:90)))
        XCTAssertFalse(FormationGeometry.startPrecedesEnd(CGPoint(x:20,y:90),CGPoint(x:20,y:10)))
    }
    func testEndpointBoundsAxisSnapRejectionAndManualDetach() throws {
        let s = editor(); defer { s.vm.cancelDailyAttempt() }
        s.beginTool(.line)
        s.editorTableTapped(SCNVector3(-0.6,0,-0.3)); s.editorTableTapped(SCNVector3(0.6,0,-0.28))
        s.cancelTool()
        XCTAssertEqual(s.drawing.vertices[0].z,s.drawing.vertices[1].z)
        for _ in 0..<5 { s.place("_1",world:nil) }
        let line = s.drawing.lines[0], old = s.drawing
        s.moveVertex(line.end,to:SCNVector3(-0.58,0,-0.3))
        XCTAssertEqual(s.drawing,old)
        s.moveVertex(line.end,to:SCNVector3(100,0,-0.3))
        XCTAssertLessThanOrEqual(s.drawing.vertices[1].x,AngleSceneCalculator.innerLength/2-BallPhysics.radius)
        let key = s.keys[2], node = s.vm.scene.allBallNodes[key]!
        s.editorDragBegan(node); s.editorDragMoved(node,world:SCNVector3(0,0,0.3)); s.editorDragEnded(node)
        XCTAssertEqual(s.drawing.lines[0].balls.count,4)
        XCTAssertEqual(node.position.z,0.3,accuracy:1e-5)
        let before = s.vm.currentSnapshot()
        s.beginTool(.distance); s.editorTableTapped(SCNVector3(0,0,0)); s.editorTableTapped(SCNVector3(0.3,0,0.4))
        XCTAssertEqual(s.measurementValue!,50,accuracy:1e-4)
        s.beginTool(.angle); s.editorTableTapped(SCNVector3(0.5,0,0)); s.editorTableTapped(SCNVector3(0,0,0)); s.editorTableTapped(SCNVector3(0,0,0.5))
        XCTAssertEqual(s.measurementValue!,90,accuracy:1e-4)
        for (key,p) in before.onTable { XCTAssertEqual(s.vm.currentSnapshot().onTable[key]?.x,p.x) }
        s.cancelTool(); XCTAssertTrue(s.measurement.isEmpty); XCTAssertEqual(s.drawing.lines.count,1)
        s.clearDrawing(); XCTAssertTrue(s.drawing.lines.isEmpty); XCTAssertEqual(s.keys.count,5)
    }

    func testTwentyFiveTargetLimitSaveReloadAndRender() throws {
        let session = CustomFormationSession(template:nil,editing:true)
        session.vm.setupScene(loadsDefaultLayout:false); session.setup()
        defer { session.vm.cancelDailyAttempt() }
        for _ in 0..<25 { session.place("_1",world:nil) }
        XCTAssertEqual(session.keys.count,25)
        XCTAssertEqual(session.vm.onTableKeys.count,26)
        let keys = session.keys
        session.place("_2",world:nil)
        session.place("_2",world:SCNVector3(0,session.vm.scene.surfaceY,0.3))
        XCTAssertEqual(session.keys,keys)
        XCTAssertEqual(session.notice,"最多添加25颗目标球（母球另计）")
        XCTAssertTrue(session.vm.onTableKeys.contains(PositionPlayBall.cueKey))
        let template = try session.templateForSaving()
        let library = CustomFormationLibrary(ownerKey:"large",directory:directory)
        XCTAssertTrue(library.save(template))
        let reloaded = try XCTUnwrap(CustomFormationLibrary(ownerKey:"large",directory:directory).selected)
        XCTAssertEqual(reloaded.ballKeys.count,25)
        XCTAssertEqual(Set(reloaded.ballKeys).count,25)
        XCTAssertEqual(session.vm.scene.targetBallNodes.filter { !$0.isHidden }.count,25)
    }

    func testGroupedPaletteResolvesMissingInstancesWithoutDuplicatingBalls() throws {
        let original = template()
        let s = CustomFormationSession(template:original,editing:false)
        s.vm.setupScene(loadsDefaultLayout:false); s.setup(); defer { s.vm.cancelDailyAttempt() }
        XCTAssertEqual(s.paletteKeys,["_1"]); XCTAssertEqual(s.paletteCount("_1"),3)
        let removed = original.ballKeys[1]
        s.remove(removed)
        XCTAssertEqual(s.paletteActionKey("_1"),removed)
        s.place(s.paletteActionKey("_1"),world:nil)
        XCTAssertEqual(s.keys,original.ballKeys); XCTAssertTrue(s.vm.onTableKeys.contains(removed))
        XCTAssertEqual(s.paletteCount("_2"),0)
    }
    func testLegacyOversizeTemplateIsPreservedButCannotBeSavedAsNew() throws {
        var old = template()
        for i in 3..<26 {
            let key = PositionPlayBall.instanceKey(number:2); old.ballKeys.append(key)
            old.board.onTable[key] = CanvasPoint(x:0.05+Double(i%10)*0.08,y:0.05+Double(i/10)*0.1)
        }
        let repository = CustomFormationRepository(ownerKey:"legacy",directory:directory)
        try repository.save(.init(templates:[old],selectedID:old.id))
        let bytes = try Data(contentsOf:repository.url)
        let library = CustomFormationLibrary(ownerKey:"legacy",directory:directory)
        XCTAssertFalse(library.failedToLoad); XCTAssertEqual(library.selected?.ballKeys.count,26)
        XCTAssertFalse(library.save(old.copied())); XCTAssertEqual(try Data(contentsOf:repository.url),bytes)
    }
    func testAngleArcAndAxisSnapping() throws {
        let zero = SCNVector3(0,0,0), right = SCNVector3(0.5,0,0), down = SCNVector3(0,0,0.5)
        for pair in [(right,down),(down,right),(right,SCNVector3(-0.5,0,0))] {
            let arc = FormationGeometry.angleArc(pair.0,vertex:zero,pair.1)
            XCTAssertEqual(arc.count,49)
            for p in arc { XCTAssertEqual(hypot(p.x,p.z),0.15,accuracy:1e-5) }
            XCTAssertEqual(arc.first!.x,pair.0.x*0.3,accuracy:1e-5)
            XCTAssertEqual(arc.last!.z,pair.1.z*0.3,accuracy:1e-5)
        }
        XCTAssertTrue(FormationGeometry.angleArc(right,vertex:zero,right).isEmpty)
        let s = editor(); defer { s.vm.cancelDailyAttempt() }
        s.beginTool(.angle)
        s.editorTableTapped(SCNVector3(-0.5,0,-0.3))
        s.editorTableTapped(SCNVector3(0.2,0,-0.28))
        s.editorTableTapped(SCNVector3(0.22,0,0.3))
        XCTAssertEqual(s.measurement[0].z,s.measurement[1].z,accuracy:1e-6)
        XCTAssertEqual(s.measurement[1].x,s.measurement[2].x,accuracy:1e-6)
        XCTAssertEqual(s.measurementValue!,90,accuracy:1e-4)
        let endpoint = s.precisionHandles[2]
        s.editorDragBegan(endpoint); s.editorDragMoved(endpoint,world:SCNVector3(0.9,0,-0.28)); s.editorDragEnded(endpoint)
        XCTAssertEqual(s.measurement[1].z,s.measurement[2].z,accuracy:1e-6)
        XCTAssertEqual(s.measurementValue!,180,accuracy:1e-4)
    }

}
