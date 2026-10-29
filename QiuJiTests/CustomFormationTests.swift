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
        let keys = (1...3).map { PositionPlayBall.instanceKey(number: $0) }
        var board = [PositionPlayBall.cueKey: CanvasPoint(x: 0.25, y: 0.35)]
        for (i, key) in keys.enumerated() { board[key] = CanvasPoint(x: 0.35 + Double(i) * 0.12, y: 0.25) }
        return .init(name: "三颗不同号球", ballKeys: keys, board: .init(onTable: board))
    }

    func testBuiltInLayoutsHaveUniqueBallsClearanceAndExpectedShapes() throws {
        for template in BuiltInCustomFormations.templates {
            try template.validateForPractice()
            XCTAssertEqual(template.ballKeys.compactMap(PositionPlayBall.number), Array(1...15))
            let cue = try XCTUnwrap(template.board.onTable[PositionPlayBall.cueKey])
            XCTAssertEqual(cue.x, 0.5)
            XCTAssertEqual(cue.y, 0.25)
            let points = Array(template.board.onTable.values)
            let radius = Double(AngleSceneCalculator.ballRadius / AngleSceneCalculator.innerLength)
            for (i, p) in points.enumerated() {
                XCTAssertGreaterThanOrEqual(min(p.x, 1 - p.x, p.y, 0.5 - p.y), radius - 1e-8)
                for q in points.dropFirst(i + 1) {
                    XCTAssertGreaterThan(hypot(p.x - q.x, p.y - q.y), 2 * radius)
                }
            }
        }
        let four = BuiltInCustomFormations.templates[0]
        let groups = Dictionary(grouping: four.ballKeys.map { four.board.onTable[$0]! }) {
            "\($0.x > 0.5)-\($0.y > 0.25)"
        }
        XCTAssertEqual(groups.values.map(\.count).sorted(), [3, 4, 4, 4])
        let lShape = BuiltInCustomFormations.templates[1]
        let points = lShape.ballKeys.map { lShape.board.onTable[$0]! }
        XCTAssertEqual(points.filter { abs($0.x - 0.25) < 1e-8 }.count, 8)
        XCTAssertEqual(points.filter { abs($0.y - 0.25) < 1e-8 }.count, 8)
        let radius = Double(AngleSceneCalculator.ballRadius) / Double(AngleSceneCalculator.innerLength)
        XCTAssertEqual(0.5 - points[0].y, radius, accuracy: 1e-8)
        XCTAssertEqual(points[14].x, radius, accuracy: 1e-8)
    }

    func test4443GroupsPreserveSpacingAndOneBallLongCushionGap() throws {
        let template = BuiltInCustomFormations.templates[0]
        let groups = Dictionary(grouping: template.ballKeys.map { template.board.onTable[$0]! }) { "\($0.x > 0.5)-\($0.y > 0.25)" }
        for group in groups.values {
            let ys = group.map(\.y).sorted(), upper = ys[0] < 0.25
            let edgeDistance = (upper ? ys[0] : 0.5 - ys.last!) * 2.54
            XCTAssertEqual(edgeDistance - 0.028575, 0.05715, accuracy: 1e-7)
            for (a,b) in zip(ys, ys.dropFirst()) { XCTAssertEqual((b-a)*2.54, 0.1143, accuracy: 1e-7) }
        }
    }

    func testBuiltInStartAndRestartAimAtOneFromTableCenter() throws {
        for template in BuiltInCustomFormations.templates {
            let session = CustomFormationSession(template: template, editing: false)
            session.vm.setupScene(loadsDefaultLayout: false)
            session.vm.usesAutomaticPocketFallback = true // Same host contract as FreePlayView.
            defer { session.vm.cancelDailyAttempt() }
            session.setup()
            for restart in [false, true] {
                if restart { session.vm.nudgeFreeAim(byDegrees: 30); session.reset() }
                let one = try XCTUnwrap(session.vm.scene.allBallNodes[template.ballKeys[0]])
                let cue = try XCTUnwrap(session.vm.scene.cueBallNode)
                let aim = try XCTUnwrap(session.vm.freeAimDir)
                XCTAssertEqual(cue.position.x, 0, accuracy: 1e-6)
                XCTAssertEqual(cue.position.z, 0, accuracy: 1e-6)
                let dx = one.position.x - cue.position.x, dz = one.position.z - cue.position.z
                let length = hypotf(dx, dz)
                XCTAssertEqual(aim.x, dx / length, accuracy: 1e-6)
                XCTAssertEqual(aim.z, dz / length, accuracy: 1e-6)
                XCTAssertEqual(session.vm.selectedTargetKey, template.ballKeys[0])
            }
        }
    }

    func testBuiltInsStayReadOnlyAndCopiesUsePersonalArchive() throws {
        let library = CustomFormationLibrary(ownerKey: "guest:builtins", directory: directory)
        let personal = template()
        XCTAssertTrue(library.save(personal))
        for builtIn in BuiltInCustomFormations.templates {
            library.select(builtIn.id)
            library.reload()
            XCTAssertEqual(library.selected?.id, builtIn.id)
            XCTAssertEqual(library.archive.selectedID, personal.id)
            XCTAssertEqual(library.templates.count, 1)
            XCTAssertFalse(library.save(builtIn))
            library.delete(builtIn.id)
            XCTAssertEqual(library.selected?.name, builtIn.name)

            let session = CustomFormationSession(template: builtIn, editing: false)
            session.vm.setupScene(loadsDefaultLayout: false)
            defer { session.vm.cancelDailyAttempt() }
            session.setup()
            let saved = try session.templateForSaving()
            XCTAssertNotEqual(saved.id, builtIn.id)
            session.remove(builtIn.ballKeys[0], permanently: true)
            session.reset()
            XCTAssertEqual(session.vm.currentSnapshot().onTable.count, 16)
            XCTAssertEqual(builtIn.board.onTable.count, 16)
        }
        let builtIn = BuiltInCustomFormations.templates[1]
        library.duplicate(builtIn)
        let copy = try XCTUnwrap(library.selected)
        XCTAssertFalse(BuiltInCustomFormations.contains(copy.id))
        XCTAssertTrue(Set(copy.ballKeys).isDisjoint(with: builtIn.ballKeys))
        library.rename(copy, name: "我的L型")
        let reopened = CustomFormationLibrary(ownerKey: "guest:builtins", directory: directory)
        XCTAssertEqual(reopened.selected?.name, "我的L型")
        XCTAssertEqual(reopened.templates.count, 2)
        XCTAssertEqual(BuiltInCustomFormations.templates[1].name, "L型球形")
    }

    func testDistinctNumbersSurviveAtomicSaveReloadAndCopy() throws {
        let library = CustomFormationLibrary(ownerKey: "guest:test", directory: directory)
        let original = template()
        XCTAssertTrue(library.save(original))
        let reopened = CustomFormationLibrary(ownerKey: "guest:test", directory: directory)
        let loaded = try XCTUnwrap(reopened.selected)
        XCTAssertEqual(loaded.ballKeys, original.ballKeys)
        XCTAssertEqual(loaded.ballKeys.compactMap(PositionPlayBall.number), [1, 2, 3])
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
        for n in 1...3 { s.place("_\(n)",world:nil) }
        XCTAssertEqual(s.lineBallCount,3)
        XCTAssertEqual(s.lineSpacingCM!,50,accuracy:0.0001)
        let sharedID = s.drawing.lines[0].end
        let sharedBall = try XCTUnwrap(s.drawing.lines[0].balls.last)
        s.beginTool(.line)
        s.editorTableTapped(SCNVector3(0.5,0,-0.3)); s.editorTableTapped(SCNVector3(0.5,0,0.4))
        XCTAssertEqual(s.drawing.vertices.count,3)
        XCTAssertEqual(s.drawing.lines[1].start,sharedID)
        s.place("_4",world:nil); s.place("_5",world:nil)
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
    func testReverseDrawnLineSortIdentityAndMembershipReset() throws {
        let s = editor(); defer { s.vm.cancelDailyAttempt() }
        s.beginTool(.line)
        s.editorTableTapped(SCNVector3(0.6,0,-0.3)); s.editorTableTapped(SCNVector3(-0.6,0,-0.3))
        for (number,x) in [(2,Float(0.6)),(1,Float(0)),(3,Float(-0.6))] {
            s.place("_\(number)",world:SCNVector3(x,0,-0.3))
        }
        let original = s.selectedLine!.balls, id = s.selectedLine!.id
        s.sortSelectedLine(startPrecedesEnd:false)
        XCTAssertEqual(s.selectedLine!.balls.compactMap(PositionPlayBall.number),[3,2,1])
        XCTAssertEqual(Set(s.selectedLine!.balls),Set(original))
        s.sortSelectedLine(startPrecedesEnd:false)
        XCTAssertEqual(s.selectedLine!.balls.compactMap(PositionPlayBall.number),[1,2,3])
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
        for n in 1...5 { s.place("_\(n)",world:nil) }
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

    func testFifteenUniqueTargetLimitSaveReloadAndRender() throws {
        let session = editor()
        defer { session.vm.cancelDailyAttempt() }
        for n in 1...15 { session.place("_\(n)",world:nil) }
        XCTAssertEqual(session.keys.count,15)
        XCTAssertEqual(session.vm.onTableKeys.count,16)
        let keys = session.keys
        session.place("_2",world:nil)
        session.place("_2",world:SCNVector3(0,session.vm.scene.surfaceY,0.3))
        XCTAssertEqual(session.keys,keys)
        XCTAssertEqual(session.notice,"每个球号只能有一颗")
        XCTAssertTrue(session.canSave)
        let template = try session.templateForSaving()
        let library = CustomFormationLibrary(ownerKey:"large",directory:directory)
        XCTAssertTrue(library.save(template))
        let reloaded = try XCTUnwrap(CustomFormationLibrary(ownerKey:"large",directory:directory).selected)
        XCTAssertEqual(reloaded.ballKeys.compactMap(PositionPlayBall.number),Array(1...15))
        XCTAssertEqual(session.vm.scene.targetBallNodes.filter { !$0.isHidden }.count,15)
    }

    func testPaletteResolvesExistingBallAndReturnsSameIdentity() throws {
        let original = template()
        for editing in [true, false] {
            let s = CustomFormationSession(template:original,editing:editing)
            s.vm.setupScene(loadsDefaultLayout:false); s.setup()
            defer { s.vm.cancelDailyAttempt() }
            XCTAssertEqual(s.paletteCount("_1"),1)
            XCTAssertEqual(s.paletteActionKey("_1"),original.ballKeys[0])
            s.place("_1",world:nil)
            XCTAssertEqual(s.keys,original.ballKeys)
            s.remove(original.ballKeys[0])
            s.place(s.paletteActionKey("_1"),world:nil)
            XCTAssertEqual(s.keys.count,3)
            XCTAssertEqual(s.paletteCount("_1"),1)
            if !editing { XCTAssertTrue(s.vm.onTableKeys.contains(original.ballKeys[0])) }
        }
    }

    func testLegacyDuplicateTemplateCanBeReadAndRepairedWithoutOverwritingOnFailure() throws {
        var old = template()
        let duplicate = PositionPlayBall.instanceKey(number:1)
        let replaced = old.ballKeys[1]
        old.board.onTable[duplicate] = old.board.onTable.removeValue(forKey:replaced)
        old.ballKeys[1] = duplicate
        let repository = CustomFormationRepository(ownerKey:"legacy-duplicate",directory:directory)
        var archive = CustomFormationRepository.Archive(templates:[old],selectedID:old.id)
        archive.metadata[old.id.uuidString]?.pending = FormationMutation(clientId:old.id,generation:1,baseRevision:0,template:old)
        try repository.save(archive)
        let bytes = try Data(contentsOf:repository.url)
        let library = CustomFormationLibrary(ownerKey:"legacy-duplicate",directory:directory)
        XCTAssertFalse(library.failedToLoad)
        XCTAssertNotNil(library.selected?.practiceIssue)
        XCTAssertNoThrow(try old.validateForSync(), "Pending legacy sync must remain readable")
        XCTAssertFalse(library.save(old))
        XCTAssertFalse(library.save(old.copied()))
        XCTAssertEqual(try Data(contentsOf:repository.url),bytes)
        let s = CustomFormationSession(template:old,editing:true)
        s.vm.setupScene(loadsDefaultLayout:false); s.setup()
        defer { s.vm.cancelDailyAttempt() }
        XCTAssertFalse(s.canSave)
        XCTAssertThrowsError(try s.templateForSaving())
        s.remove(duplicate)
        XCTAssertTrue(s.canSave)
        let repaired = try s.templateForSaving()
        XCTAssertEqual(repaired.id,old.id)
        XCTAssertTrue(library.save(repaired,basedOn:old))
        XCTAssertNil(library.selected?.practiceIssue)
        XCTAssertEqual(library.selected?.ballKeys.count,2)
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
