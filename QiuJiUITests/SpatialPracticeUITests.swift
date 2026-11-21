import XCTest
import UIKit

final class SpatialPracticeUITests:XCTestCase {
    private var app:XCUIApplication!
    override func setUp() { continueAfterFailure=false }
    override func tearDown() { app?.terminate();XCUIDevice.shared.orientation = .portrait }
    private func element(_ id:String)->XCUIElement { app.descendants(matching:.any).matching(identifier:id).firstMatch }
    private func ready(_ e:XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == true AND hittable == true AND enabled == true"),object:e)],timeout:90),.completed,e.debugDescription)
    }
    private func stable(_ e:XCUIElement) {
        ready(e)
        var previous=CGRect.zero,since=Date()
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let frame=e.frame
            if frame != previous { previous=frame;since=Date() }
            return e.isHittable && e.isEnabled && Date().timeIntervalSince(since)>1.5
        },object:app)],timeout:30),.completed)
    }
    private let visibleControlIDs=["masseJump.elevation","masseJump.aimWheel","masseJump.retry","masseJump.replay","masseJump.strike"]
    private func settledTable() {
        // The first hittable control can arrive during UIKit's portrait-to-landscape
        // animation. Compare settled native frames, preserving portrait entry itself.
        var previous:[CGRect]=[]
        var unchangedSince=Date()
        let expectation=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let window=self.app.windows.firstMatch.frame
            let frames=[window]+self.visibleControlIDs.map { self.element($0).frame }
            guard !frames.contains(where: \.isEmpty),
                  UIDevice.current.userInterfaceIdiom == .pad || window.width>window.height else { return false }
            if frames != previous { previous=frames;unchangedSince=Date();return false }
            return Date().timeIntervalSince(unchangedSince)>=1
        },object:app)
        XCTAssertEqual(XCTWaiter.wait(for:[expectation],timeout:30),.completed)
    }
    private func captureControlFrames() {
        var frames:[String:[Double]]=[:]
        for (id,frame) in [("window",app.windows.firstMatch.frame)]+visibleControlIDs.map({ ($0,element($0).frame) }) {
            frames[id]=[frame.minX,frame.minY,frame.width,frame.height].map(Double.init)
        }
        let data=try! JSONSerialization.data(withJSONObject:frames,options:.sortedKeys)
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name="v66-settled-native-control-frames";attachment.lifetime = .keepAlways;add(attachment)
    }
    private func revealMenu(_ id:String)->XCUIElement {
        let item=element(id),scroll=app.scrollViews["dailyClearance.menuScroll"]
        for _ in 0..<6 {
            if item.isHittable { break }
            scroll.swipeUp()
        }
        ready(item);return item
    }
    private func capture(_ name:String) {
        let attachment=XCTAttachment(screenshot:XCUIScreen.main.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
    private func captureMotionTrace(_ name:String) {
        let text=element("masseJump.motionTrace").value as? String ?? ""
        guard let data=text.data(using:.utf8),
              let object=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              let rows=object["rows"] as? [[Double]],rows.count>2 else {
            XCTFail("Missing motion trace: \(text.prefix(100))");return
        }
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
    private func previewProbe()->[String:Any] {
        let text=element("masseJump.previewProbe").value as? String ?? "{}"
        return (try? JSONSerialization.jsonObject(with:Data(text.utf8))) as? [String:Any] ?? [:]
    }
    private func openPractice(_ title:String) {
        let search=app.textFields["librarySearchField"]
        if !search.exists { app.switchTab(.angle) }
        ready(search);search.tap()
        let previous=search.value as? String ?? ""
        if !previous.isEmpty && previous != search.placeholderValue {
            search.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:previous.count))
        }
        search.typeText(title)
        let entry=app.buttons[title];ready(entry);entry.tap()
    }
    func testHorizontalElevationThenRackAssist() throws {
        app=XCUIApplication()
        app.launchEnvironment["SPATIAL_TEST_SESSION"]=UUID().uuidString
        app.launchArguments=["-hasCompletedOnboarding","YES","-firstRun.profileFlow.v1","completed",
                             "-freeLayout.ephemeral","-forcePremium","-masseJump.probe","-v63.cameraDiagnostics"]
        app.launch()
        openPractice("扎杆与跳球")
        let wheel=element("masseJump.elevation")
        ready(wheel);settledTable()
        XCTAssertGreaterThan(wheel.frame.width,wheel.frame.height)
        XCTAssertGreaterThanOrEqual(wheel.frame.minX,element("masseJump.replay").frame.maxX-1)
        let before=try XCTUnwrap(previewProbe()["elevation"] as? Double)
        wheel.coordinate(withNormalizedOffset:.init(dx:0.15,dy:0.5)).press(forDuration:0.05,
            thenDragTo:wheel.coordinate(withNormalizedOffset:.init(dx:0.85,dy:0.5)))
        XCTAssertGreaterThan(try XCTUnwrap(previewProbe()["elevation"] as? Double),before)
        capture("horizontal-elevation-and-table-route")
        let spin=element("shotStage.spinEntry");ready(spin);spin.tap();capture("spin-boundary")
        app.buttons["关闭打点"].coordinate(withNormalizedOffset:.init(dx:0.05,dy:0.05)).tap()
        element("break.entry").tap()
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let p=self.previewProbe()
            return p["breakMode"] as? Bool == true && p["ready"] as? Bool == true && p["routes"] as? Int == 0
        },object:app)],timeout:30),.completed)
        let camera = element("v63.cameraDiagnostics")
        let rackCamera = NSPredicate(format: "value CONTAINS %@ AND value CONTAINS %@",
                                     "twoViewMode=thirdPerson", "twoViewMoving=false")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: rackCamera, object: camera)],
                                      timeout: 40), .completed)
        capture("rack-shared-aim-only")
    }
    func testMovingCueRaisesElevationAndRestoresWheelSetting() throws {
        app = XCUIApplication()
        app.launchEnvironment["SPATIAL_TEST_SESSION"] = UUID().uuidString
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-firstRun.profileFlow.v1", "completed",
                               "-freeLayout.ephemeral", "-forcePremium", "-masseJump.probe"]
        app.launch()
        openPractice("扎杆与跳球")
        let wheel = element("masseJump.elevation")
        ready(wheel)
        settledTable()
        wheel.coordinate(withNormalizedOffset: .init(dx: 0.20, dy: 0.5)).press(forDuration: 0.05,
            thenDragTo: wheel.coordinate(withNormalizedOffset: .init(dx: 0.58, dy: 0.5)))
        let requested = try XCTUnwrap(previewProbe()["elevation"] as? Double)
        let topDown = element("shotCamera.temporaryTopDown")
        func dragCue(to key: String, x: Double, z: Double) throws {
            topDown.tap()
            let probe = element("masseJump.placementProbe")
            func placement() -> [String: [Double]] {
                guard let text = probe.value as? String else { return [:] }
                return (try? JSONDecoder().decode([String: [Double]].self, from: Data(text.utf8))) ?? [:]
            }
            let projected = XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
                let p = placement()
                return p["cue"]?.count == 2 && p[key]?.count == 2
            }, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [projected], timeout: 20), .completed)
            let p = placement()
            let window = app.windows.firstMatch
            let origin = window.coordinate(withNormalizedOffset: .zero)
            func coordinate(_ key: String) throws -> XCUICoordinate {
                let point = try XCTUnwrap(p[key])
                return origin.withOffset(CGVector(dx: point[0] - window.frame.minX, dy: point[1] - window.frame.minY))
            }
            try coordinate("cue").press(forDuration: 0.2, thenDragTo: coordinate(key))
            let arrived = XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
                guard let world = placement()["world"], world.count == 2 else { return false }
                return abs(world[0] - x) < 0.02 && abs(world[1] - z) < 0.02
            }, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [arrived], timeout: 15), .completed)
            topDown.tap()
            ready(element("masseJump.strike"))
            XCTAssertTrue(element("masseJump.strike").isEnabled)
        }
        try dragCue(to: "clearanceTarget", x: 0.685, z: 0)
        XCTAssertGreaterThan(try XCTUnwrap(previewProbe()["displayedElevation"] as? Double), requested)
        capture("raised-to-clear-ball")
        try dragCue(to: "target", x: -0.7, z: 0.25)
        XCTAssertEqual(try XCTUnwrap(previewProbe()["displayedElevation"] as? Double), requested, accuracy: 0.001)
        capture("restored-wheel-elevation")
    }
    private func actualBoard() throws -> [String:[Double]] {
        let value=try XCTUnwrap(element("table.scene").value as? String)
        let object=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(value.utf8)) as? [String:Any])
        return try Dictionary(uniqueKeysWithValues:XCTUnwrap(object["balls"] as? [[String:Any]]).map {
            (try XCTUnwrap($0["key"] as? String),try XCTUnwrap($0["world"] as? [Double]))
        })
    }
    private func visitSpatialAndReturn() {
        openPractice("扎杆与跳球");ready(element("masseJump.elevation"));settledTable()
        let wheel=element("masseJump.elevation")
        let start=wheel.coordinate(withNormalizedOffset:CGVector(dx:0.50,dy:0.5))
        start.press(forDuration:0.05,thenDragTo:start.withOffset(CGVector(dx:8,dy:0)))
        let strike=element("masseJump.strike");ready(strike);strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            self.previewProbe()["phase"] as? String == "playing"
        },object:app)],timeout:60),.completed)
        if strike.label == "停止" { strike.tap() }
        ready(wheel);element("masseJump.back").tap()
    }
    func testLegacyComposerAndSolverContinueAfterSpatialVisit() throws {
        app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-firstRun.profileFlow.v1", "completed",
                               "-forcePremium", "-freeLayout.ephemeral", "-3dDrag.probe", "-masseJump.probe"]
        app.launchEnvironment["BOARD_MEMORY_TEST_DOMAIN"] = UUID().uuidString
        app.launchEnvironment["SPATIAL_TEST_SESSION"] = UUID().uuidString
        app.launch()
        for (title,back) in [("分离角与走位","dailyClearance.back"),("走位求解","silu.back")] {
            openPractice(title);ready(element(back));stable(element("paletteBall__7"))
            element("paletteBall__7").tap()
            XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
                (try? self.actualBoard()["_7"]) != nil
            },object:app)],timeout:20),.completed)
            let expected=try actualBoard()
            element(back).tap();visitSpatialAndReturn()
            openPractice(title);ready(element(back));stable(element("paletteBall__8"))
            let restored=try actualBoard()
            XCTAssertEqual(Set(restored.keys),Set(expected.keys))
            for (key,p) in expected {
                let q=try XCTUnwrap(restored[key]);XCTAssertEqual(q.count,p.count)
                for axis in p.indices { XCTAssertEqual(p[axis],q[axis],accuracy:0.00001,title) }
            }
            XCTAssertFalse(element("masseJump.elevation").exists)
            element("paletteBall__8").tap()
            XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
                (try? self.actualBoard()["_8"]) != nil
            },object:app)],timeout:20),.completed)
            capture("v66-r6-return-and-continue-"+title)
            element(back).tap()
        }
    }
    func testLegacyDailyAndFormationContinueAfterSpatialVisit() throws {
        app=XCUIApplication.launchClean(extraArgs:["-forcePremium","-freeLayout.ephemeral","-3dDrag.probe","-masseJump.probe",
            "-v50.inMemoryStore","-v54.todayState=freeCompleted","-dailyClearance.resetHomeState"])
        func open(_ custom:Bool) {
            if custom {
                openPractice("自定义球形")
                let formation=element("formation.builtin.B4443000-0000-4000-8000-000000000001")
                ready(formation);formation.tap();ready(element("formation.start"));element("formation.start").tap()
            } else {
                app.switchTab(.training)
                let daily=element("trainingHome.dailyClearance");ready(daily);daily.tap()
            }
            stable(element("dailyClearance.strike"))
        }
        func leave(_ custom:Bool) {
            element("dailyClearance.back").tap()
            if custom { ready(element("formation.start"));app.buttons["返回"].firstMatch.tap() }
        }
        for custom in [false,true] {
            open(custom)
            let expected=try actualBoard()
            leave(custom);visitSpatialAndReturn();open(custom)
            let restored=try actualBoard()
            XCTAssertEqual(Set(restored.keys),Set(expected.keys))
            for (key,p) in expected {
                let q=try XCTUnwrap(restored[key]);XCTAssertEqual(q.count,p.count)
                for axis in p.indices { XCTAssertEqual(p[axis],q[axis],accuracy:0.00001) }
            }
            XCTAssertFalse(element("masseJump.elevation").exists)
            element("dailyClearance.strike").tap()
            XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
                (try? self.actualBoard()) != expected
            },object:app)],timeout:60),.completed)
            ready(element("dailyClearance.strike"))
            capture(custom ? "v66-r6-formation-continued":"v66-r6-daily-continued")
            leave(custom)
        }
    }
    func testLegacyAccuracyContinuesAfterSpatialVisit() throws {
        app=XCUIApplication.launchClean(extraArgs:["-forcePremium","-freeLayout.ephemeral","-trainingMerge.probe","-masseJump.probe","-v50.inMemoryStore"])
        func open() {
            openPractice("准度练习");ready(element("accuracy.start"));element("accuracy.start").tap()
            stable(element("accuracy.strike"))
        }
        func state() throws -> [String:Any] {
            let text=try XCTUnwrap(element("accuracy.mergeState").value as? String)
            return try XCTUnwrap(JSONSerialization.jsonObject(with:Data(text.utf8)) as? [String:Any])
        }
        open();let view=try XCTUnwrap(state()["view"] as? String)
        element("accuracy.back").tap()
        // The settings host may remain under its table; dismiss that actual host.
        if element("accuracy.start").waitForExistence(timeout:2) {
            ready(element("training.settingsCancel"));element("training.settingsCancel").tap()
        }
        visitSpatialAndReturn();open()
        XCTAssertEqual(try state()["view"] as? String,view)
        XCTAssertFalse(element("masseJump.elevation").exists)
        let attempts=try XCTUnwrap(state()["attempts"] as? Int)
        element("accuracy.strike").tap()
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            ((try? state()["attempts"] as? Int) ?? 0)>attempts
        },object:app)],timeout:60),.completed)
        capture("v66-r6-accuracy-continued")
    }
    func testIPadHighElevationAndRealWindowResizeReturns() throws {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom,.pad)
        app=XCUIApplication.launchClean(extraArgs:["-forcePremium","-freeLayout.ephemeral","-masseJump.probe"])
        app.maximizeTrainingTestWindow();openPractice("扎杆与跳球")
        ready(element("masseJump.elevation"));settledTable()
        let wheel=element("masseJump.elevation")
        for _ in 0..<12 where (previewProbe()["elevation"] as? Double ?? 0)<75 {
            wheel.coordinate(withNormalizedOffset:CGVector(dx:0.10,dy:0.5)).press(forDuration:0.05,
                thenDragTo:wheel.coordinate(withNormalizedOffset:CGVector(dx:0.90,dy:0.5)))
        }
        XCTAssertEqual(previewProbe()["elevation"] as? Double,75)
        XCUIDevice.shared.orientation = .portrait;ready(wheel);settledTable()
        capture("v66-r6-pad-portrait-75")
        XCUIDevice.shared.orientation = .landscapeLeft;ready(wheel);settledTable()
        let before=previewProbe(),window=app.windows.firstMatch,original=window.frame
        func viewport() throws -> [Double] {
            let text=try XCTUnwrap(element("masseJump.viewport").value as? String)
            let values=text.split(separator:",").compactMap { Double($0) }
            XCTAssertEqual(values.count,2);return values
        }
        let originalContent=try viewport()
        let start=app.coordinate(withNormalizedOffset:CGVector(dx:0.985,dy:0.99))
        start.press(forDuration:1,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.62,dy:0.72)),
            withVelocity:.slow,thenHoldForDuration:0.5)
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            abs(window.frame.width-original.width)>30 || abs(window.frame.height-original.height)>30
        },object:app)],timeout:10),.completed,"Only a real OS window resize qualifies")
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            guard let size=try? viewport(),size.count==2 else { return false }
            return abs(size[0]-originalContent[0])>30 || abs(size[1]-originalContent[1])>30
        },object:app)],timeout:10),.completed,"The actual SwiftUI content must resize, not just the compositor")
        ready(wheel);settledTable();capture("v66-r6-pad-real-small-window")
        XCTAssertEqual(previewProbe()["elevation"] as? Double,75)
        XCTAssertEqual(previewProbe()["cueWorld"] as? [Double],before["cueWorld"] as? [Double])
        for id in visibleControlIDs { XCTAssertTrue(window.frame.contains(element(id).frame),id) }
        app.maximizeTrainingTestWindow();ready(wheel);settledTable()
        let restored=try viewport()
        for axis in 0..<2 { XCTAssertEqual(restored[axis],originalContent[axis],accuracy:1) }
        XCTAssertEqual(previewProbe()["cueWorld"] as? [Double],before["cueWorld"] as? [Double])
        capture("v66-r6-pad-maximized-return")
        element("masseJump.back").tap()
    }
    /// Measures App receipt -> rendered preview / actual cue presentation motion.
    /// XCTest dispatch and accessibility polling time are deliberately excluded.
    func testNativePreviewAndCachedStrokeLatency() throws {
        app=XCUIApplication.launchClean(extraArgs:["-v50.inMemoryStore","-freeLayout.ephemeral","-forcePremium",
            "-masseJump.probe","-masseJump.timing"])
        app.switchTab(.angle)
        let advanced=app.buttons["angleHomeTab_进阶"];ready(advanced);advanced.tap()
        let entry=app.buttons["扎杆与跳球"];ready(entry);entry.tap()
        ready(element("masseJump.elevation"));settledTable()
        func rows()->[[String:Double]] {
            let text=element("masseJump.timingProbe").value as? String ?? "[]"
            return (try? JSONSerialization.jsonObject(with:Data(text.utf8))) as? [[String:Double]] ?? []
        }
        func wait(_ predicate:@escaping ()->Bool) {
            XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in predicate() },object:app)],timeout:60),.completed)
        }
        wait { self.previewProbe()["ready"] as? Bool == true && rows().contains { $0["rendered"] != nil } }
        let initial=rows()
        let wheel=element("masseJump.elevation")
        for i in 0..<21 {
            let before=rows().filter { $0["rendered"] != nil }.count
            let value=previewProbe()["elevation"] as? Double
            let start=wheel.coordinate(withNormalizedOffset:CGVector(dx:0.50,dy:0.5))
            start.press(forDuration:0.05,thenDragTo:start.withOffset(CGVector(dx:i.isMultiple(of:2) ? 8:-8,dy:0)))
            wait { rows().filter { $0["rendered"] != nil }.count>before && self.previewProbe()["ready"] as? Bool == true }
            XCTAssertNotEqual(previewProbe()["elevation"] as? Double,value)
        }
        let afterInputs=rows()
        for _ in 0..<21 {
            wait { self.previewProbe()["ready"] as? Bool == true }
            let before=rows().filter { $0["strokeRendered"] != nil }.count
            let strike=element("masseJump.strike");ready(strike);strike.tap()
            wait { rows().filter { $0["strokeRendered"] != nil }.count>before }
            XCTAssertEqual(rows().last(where:{ $0["strokeRendered"] != nil })?["cached"],1)
            if strike.label == "停止" { strike.tap() }
            ready(wheel)
        }
        let afterStrokes=rows()
        let breakButton=element("break.entry");ready(breakButton);breakButton.tap()
        wait { self.previewProbe()["onTable"] as? Int == 16 && self.previewProbe()["ready"] as? Bool == true }
        for _ in 0..<5 {
            let before=rows().filter { $0["rendered"] != nil }.count
            let rerack=element("break.rerack");ready(rerack);rerack.tap()
            wait { rows().filter { $0["rendered"] != nil }.count>before && self.previewProbe()["ready"] as? Bool == true }
        }
        let afterRacks=rows()
        for _ in 0..<6 {
            let before=rows().filter { $0["strokeRendered"] != nil }.count
            let rerack=element("break.rerack");ready(rerack);rerack.tap()
            // Do not wait for preview readiness. Preserve the observed cache-hit
            // field: accessibility dispatch can still arrive after a fast solve.
            let strike=element("masseJump.strike");strike.tap()
            wait { rows().filter { $0["strokeRendered"] != nil }.count>before }
            if strike.label == "停止" { strike.tap() }
            ready(wheel)
        }
        let data=try JSONSerialization.data(withJSONObject:["initial":initial,"afterInputs":afterInputs,
            "afterStrokes":afterStrokes,"afterRacks":afterRacks,"afterEarlyRackStrikes":rows()],options:[.prettyPrinted,.sortedKeys])
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name="v66-r6-native-input-render-latency";attachment.lifetime = .keepAlways;add(attachment)
        capture("v66-r6-native-latency-rack")
        element("masseJump.back").tap()
    }
    func testSpatialTrajectorySettingsUseSamePrediction() {
        app=XCUIApplication.launchClean(extraArgs:["-v50.inMemoryStore","-freeLayout.ephemeral","-forcePremium","-masseJump.probe"])
        app.switchTab(.angle)
        let advanced=app.buttons["angleHomeTab_进阶"];ready(advanced);advanced.tap()
        let entry=app.buttons["扎杆与跳球"];ready(entry);entry.tap()
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            self.previewProbe()["ready"] as? Bool == true
        },object:app)],timeout:60),.completed)
        let id=previewProbe()["id"] as? String
        XCTAssertGreaterThan(previewProbe()["height"] as? Double ?? 0,0.005)
        let more=element("masseJump.more");ready(more);more.tap()
        let trajectory=element("masseJump.trajectory");ready(trajectory);trajectory.tap()
        for option in ["off","2","1","0"] {
            let item=element("masseJump.trajectory."+option);ready(item);item.tap()
            XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
                let p=self.previewProbe()
                return option=="off" ? (p["routes"] as? Int == 0 && p["hidden"] as? Bool == true) :
                    (p["detail"] as? Int == Int(option) && (p["routes"] as? Int ?? 0)>0 && p["hidden"] as? Bool == false)
            },object:app)],timeout:15),.completed)
            XCTAssertEqual(previewProbe()["id"] as? String,id)
            XCTAssertEqual(item.value as? String,"已选")
            capture("v66-space-route-"+option)
            XCTAssertTrue(item.isHittable,"Choosing a detail must leave the submenu open")
        }
        element("masseJump.dismissMenu").tap()
        element("masseJump.back").tap()
    }
    func testAdvancedEntryControlsStrikeRetryReplayAndReturn() {
        app=XCUIApplication.launchClean(extraArgs:["-v50.inMemoryStore","-freeLayout.ephemeral","-forcePremium","-masseJump.probe"])
        app.switchTab(.angle)
        let advanced=app.buttons["angleHomeTab_进阶"];ready(advanced);advanced.tap()
        capture("v66-advanced-entry")
        let entry=app.buttons["扎杆与跳球"];ready(entry);entry.tap()
        let elevation=element("masseJump.elevation");ready(elevation);settledTable()
        capture("v66-ready");captureControlFrames()
        let visible=app.windows.firstMatch.frame
        for id in visibleControlIDs {
            let frame=element(id).frame
            XCTAssertFalse(frame.isEmpty,id)
            XCTAssertGreaterThanOrEqual(frame.minY,visible.minY-1,id)
            XCTAssertLessThanOrEqual(frame.maxY,visible.maxY+1,id)
        }
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait;ready(elevation);settledTable();capture("v66-ipad-portrait")
            XCUIDevice.shared.orientation = .landscapeLeft;ready(elevation);settledTable();capture("v66-ipad-landscape")
        }
        XCTAssertTrue(previewProbe()["mode3D"] as? Bool == true)
        let viewMenu=element("masseJump.more");ready(viewMenu);viewMenu.tap()
        XCTAssertFalse(element("masseJump.cameraMode").exists)
        XCTAssertFalse(element("masseJump.side").exists)
        XCTAssertFalse(element("masseJump.example.jump").exists)
        element("masseJump.dismissMenu").tap()
        let before=previewProbe()["elevation"] as? Double ?? 0
        elevation.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.5)).press(forDuration:0.1,
            thenDragTo:elevation.coordinate(withNormalizedOffset:CGVector(dx:0.65,dy:0.5)))
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            (self.previewProbe()["elevation"] as? Double ?? 0)>before
        },object:app)],timeout:15),.completed)
        capture("v66-elevation-wheel")
        for _ in 0..<12 where (previewProbe()["elevation"] as? Double ?? 0)<75 {
            elevation.coordinate(withNormalizedOffset:CGVector(dx:0.10,dy:0.5)).press(forDuration:0.05,
                thenDragTo:elevation.coordinate(withNormalizedOffset:CGVector(dx:0.90,dy:0.5)))
        }
        XCTAssertEqual(previewProbe()["elevation"] as? Double,75)
        let top=element("shotCamera.temporaryTopDown");ready(top)
        let beforePeek=previewProbe()["camera"] as? [Double]
        top.tap();top.tap();ready(elevation)
        let afterPeek=previewProbe()["camera"] as? [Double]
        for i in 0..<3 { XCTAssertEqual(beforePeek?[i] ?? -1,afterPeek?[i] ?? -2,accuracy:0.0001) }
        top.tap()
        XCTAssertTrue(previewProbe()["temporaryTopDown"] as? Bool == true)
        XCTAssertFalse(elevation.isEnabled)
        let count=previewProbe()["onTable"] as? Int ?? 0
        let ball=element("paletteBall__3");ready(ball);ball.tap()
        XCTAssertEqual(previewProbe()["onTable"] as? Int,count+1)
        capture("v66-temporary-placement")
        func placement()->[String:Any] {
            let text=element("masseJump.placementProbe").value as? String ?? "{}"
            return (try? JSONSerialization.jsonObject(with:Data(text.utf8))) as? [String:Any] ?? [:]
        }
        let positions=placement()
        guard let cue=positions["cue"] as? [Double],let target=positions["target"] as? [Double] else {
            XCTFail("Missing actual renderer projection");return
        }
        let window=app.windows.firstMatch,origin=window.coordinate(withNormalizedOffset:.zero)
        origin.withOffset(CGVector(dx:cue[0]-window.frame.minX,dy:cue[1]-window.frame.minY))
            .press(forDuration:0.2,thenDragTo:origin.withOffset(CGVector(dx:target[0]-window.frame.minX,dy:target[1]-window.frame.minY)))
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            guard let world=placement()["world"] as? [Double] else { return false }
            return abs(world[0]+0.7)<0.015 && abs(world[1]-0.25)<0.015
        },object:app)],timeout:15),.completed)
        capture("v66-temporary-cue-dragged")
        top.tap();ready(elevation)
        XCTAssertFalse(previewProbe()["temporaryTopDown"] as? Bool == true)
        for camera in ["shotCamera.firstPerson","shotCamera.thirdPerson"] {
            let button=element(camera);ready(button);button.tap();ready(elevation)
            capture("v66-camera-"+camera)
        }
        ready(top);top.tap()
        XCTAssertTrue(previewProbe()["temporaryTopDown"] as? Bool == true)
        capture("v68-camera-temporary-top-down")
        top.tap();ready(elevation)
        XCTAssertFalse(previewProbe()["temporaryTopDown"] as? Bool == true)
        element("masseJump.more").tap();revealMenu("masseJump.reset").tap()
        app.buttons["恢复默认"].firstMatch.tap();ready(elevation)
        XCTAssertEqual(previewProbe()["elevation"] as? Double,45)
        let initialProbe=(element("masseJump.probe").value as? String ?? "").split(separator:"|")
        let baseHeight=initialProbe.count>1 ? Double(initialProbe[1]) ?? 0 : 0
        let strike=element("masseJump.strike");ready(strike);strike.tap()
        let flying=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            guard let text=self.element("masseJump.probe").value as? String,
                  let height=Double(text.split(separator:"|").last ?? "") else { return false }
            return height>baseHeight+0.005
        },object:app)
        XCTAssertEqual(XCTWaiter.wait(for:[flying],timeout:90),.completed)
        capture("v66-rendered-flight-observed")
        let replay=element("masseJump.replay");ready(replay)
        capture("v66-settled")
        captureMotionTrace("v66-normal-motion")
        let replayMenu=element("masseJump.more");ready(replayMenu);replayMenu.tap()
        let last=revealMenu("masseJump.lastShot");last.tap()
        let slow=element("masseJump.speed.slow");ready(slow);slow.tap()
        XCTAssertTrue(slow.isHittable)
        element("masseJump.dismissMenu").tap()
        let beforeReplay=previewProbe()["camera"] as? [Double]
        replay.tap();ready(element("masseJump.retry"))
        let afterReplay=previewProbe()["camera"] as? [Double]
        XCTAssertEqual(beforeReplay?.count,3);XCTAssertEqual(afterReplay?.count,3)
        for i in 0..<3 { XCTAssertEqual(beforeReplay?[i] ?? -1,afterReplay?[i] ?? -2,accuracy:0.0001) }
        captureMotionTrace("v66-slow-motion")
        element("masseJump.retry").tap();ready(strike)
        capture("v66-retry")
        let back=element("masseJump.back");ready(back);back.tap()
        ready(advanced)
        let bank=app.buttons["翻袋练习"]
        for _ in 0..<5 where !bank.isHittable { app.swipeUp() }
        ready(bank);bank.tap();ready(app.buttons["bank.start"])
        capture("v66-legacy-bank-settings")
    }
    func testSpatialBreakDeliversRestoresInputsRetriesAndRemembersGame() {
        app=XCUIApplication.launchClean(extraArgs:["-v50.inMemoryStore","-freeLayout.ephemeral","-forcePremium","-masseJump.probe"])
        app.switchTab(.angle)
        let advanced=app.buttons["angleHomeTab_进阶"];ready(advanced);advanced.tap()
        let entry=app.buttons["扎杆与跳球"];ready(entry);entry.tap()
        let elevation=element("masseJump.elevation");ready(elevation);settledTable()
        element("masseJump.more").tap();revealMenu("masseJump.reset").tap()
        app.buttons["恢复默认"].firstMatch.tap();ready(elevation)
        let start=element("break.entry");ready(start);start.tap()
        ready(element("break.rerack"));ready(element("masseJump.strike"))
        XCTAssertEqual(previewProbe()["onTable"] as? Int,16)
        XCTAssertEqual(previewProbe()["speed"] as? Double,10)
        XCTAssertEqual(previewProbe()["breakMode"] as? Bool,true)
        capture("v66-space-break-sixteen-ready")
        let strike=element("masseJump.strike");XCTAssertEqual(strike.label,"开球");strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            self.previewProbe()["breakMode"] as? Bool == false && self.element("masseJump.retry").isEnabled
        },object:app)],timeout:90),.completed)
        XCTAssertEqual(previewProbe()["speed"] as? Double,2)
        XCTAssertTrue(element("masseJump.strike").isEnabled)
        XCTAssertEqual(previewProbe()["spinX"] as? Double,0)
        XCTAssertEqual(previewProbe()["spinY"] as? Double,0)
        XCTAssertFalse(app.buttons["完成"].exists)
        capture("v66-space-break-delivered")
        element("masseJump.retry").tap();ready(strike)
        XCTAssertEqual(previewProbe()["onTable"] as? Int,16)
        XCTAssertEqual(previewProbe()["speed"] as? Double,10)
        strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            self.element("masseJump.strike").label == "停止"
        },object:app)],timeout:30),.completed)
        strike.tap();ready(element("break.rerack"))
        XCTAssertEqual(previewProbe()["onTable"] as? Int,16)
        element("masseJump.more").tap();revealMenu("break.settings").tap()
        let nine=element("break.game.9");ready(nine);nine.tap()
        element("masseJump.dismissMenu").tap();ready(strike)
        XCTAssertEqual(previewProbe()["onTable"] as? Int,10)
        capture("v66-space-nine-rack")
        element("masseJump.back").tap();ready(advanced);entry.tap();ready(element("break.rerack"));ready(strike)
        XCTAssertEqual(previewProbe()["breakCount"] as? Int,9)
        XCTAssertEqual(previewProbe()["onTable"] as? Int,10)
        XCTAssertEqual(previewProbe()["speed"] as? Double,10)
        capture("v66-space-nine-restored")
        element("masseJump.back").tap()
    }
    func testNativeFlyoutRecoversAfterShotAndReplaysOriginalAfterReentry() {
        app=XCUIApplication.launchClean(extraArgs:["-v50.inMemoryStore","-freeLayout.ephemeral","-forcePremium","-masseJump.probe"])
        app.switchTab(.angle)
        let advanced=app.buttons["angleHomeTab_进阶"];ready(advanced);advanced.tap()
        let entry=app.buttons["扎杆与跳球"];ready(entry);entry.tap()
        let elevation=element("masseJump.elevation");ready(elevation);settledTable()
        element("masseJump.more").tap();revealMenu("masseJump.clear").tap()
        let clear=app.buttons["清空桌面"].firstMatch;ready(clear);clear.tap()
        let strike=element("masseJump.strike")
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            self.previewProbe()["onTable"] as? Int == 0 && strike.label == "放回母球"
        },object:app)],timeout:10),.completed)
        ready(strike);strike.tap();ready(elevation)
        element("masseJump.more").tap();revealMenu("masseJump.reset").tap()
        app.buttons["恢复默认"].firstMatch.tap();ready(elevation)
        let top=element("shotCamera.temporaryTopDown");ready(top);top.tap()
        func placement()->[String:Any] {
            let value=self.element("masseJump.placementProbe").value as? String ?? "{}"
            return (try? JSONSerialization.jsonObject(with:Data(value.utf8))) as? [String:Any] ?? [:]
        }
        // The temporary renderer is created asynchronously. Wait for its real
        // window projection, rather than reading a nil projector immediately
        // after the native button tap. No fallback coordinates are injected.
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let p=placement()
            return self.previewProbe()["temporaryTopDown"] as? Bool == true &&
                ["cue","flyoutTarget"].allSatisfy { key in
                    guard let values=p[key] as? [Double] else {return false}
                    return values.count==2 && values.allSatisfy(\.isFinite)
                }
        },object:app)],timeout:15),.completed,"Temporary renderer must supply actual window projections")
        let p=placement()
        guard let cue=p["cue"] as? [Double],let target=p["flyoutTarget"] as? [Double] else {XCTFail("Missing native projection: \(p)");return}
        let window=app.windows.firstMatch,origin=window.coordinate(withNormalizedOffset:.zero)
        origin.withOffset(CGVector(dx:cue[0]-window.frame.minX,dy:cue[1]-window.frame.minY)).press(forDuration:0.2,
            thenDragTo:origin.withOffset(CGVector(dx:target[0]-window.frame.minX,dy:target[1]-window.frame.minY)))
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            guard let world=placement()["world"] as? [Double] else {return false}
            return abs(world[0]-1)<0.015 && abs(world[1])<0.015
        },object:app)],timeout:15),.completed)
        top.tap();ready(elevation)
        let power=element("shotStage.powerBar");ready(power)
        for _ in 0..<4 where (previewProbe()["speed"] as? Double ?? 0)<8 {
            power.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.9)).press(forDuration:0.1,
                thenDragTo:power.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.05)))
        }
        XCTAssertEqual(previewProbe()["speed"] as? Double,8)
        let before=previewProbe()["cueWorld"] as? [Double]
        ready(top);top.tap()
        XCTAssertTrue(previewProbe()["temporaryTopDown"] as? Bool == true)
        capture("v68-native-flyout-temporary-top-down")
        top.tap();ready(strike)
        XCTAssertFalse(previewProbe()["temporaryTopDown"] as? Bool == true)
        capture("v66-native-flyout-before")
        strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let p=self.previewProbe()
            return p["phase"] as? String == "ready" && p["historyID"] as? String != "" && p["archivePending"] as? Bool == false
        },object:app)],timeout:90),.completed)
        XCTAssertTrue(["outside","escaped"].contains(previewProbe()["historyCueOutcome"] as? String ?? ""))
        XCTAssertEqual(previewProbe()["cueWorld"] as? [Double],before)
        XCTAssertEqual(previewProbe()["recoveryCount"] as? Int,1)
        XCTAssertEqual(previewProbe()["onTable"] as? Int,1)
        let history=previewProbe()["historyID"] as? String
        let durable=XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            self.previewProbe()["archiveCommitted"] as? String == history
        },object:app)],timeout:15)
        let archiveData=try! JSONSerialization.data(withJSONObject:previewProbe(),options:.sortedKeys)
        let archiveAttachment=XCTAttachment(data:archiveData,uniformTypeIdentifier:"public.json")
        archiveAttachment.name="v66-native-flyout-archive";archiveAttachment.lifetime = .keepAlways;add(archiveAttachment)
        XCTAssertEqual(durable,.completed,"The completed shot must be durably referenced before leaving")
        capture("v66-native-flyout-recovered")
        element("masseJump.back").tap();ready(advanced);entry.tap();ready(elevation)
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            self.previewProbe()["historyID"] as? String == history
        },object:app)],timeout:15),.completed,"Reentry must restore the persisted original shot")
        XCTAssertEqual(previewProbe()["historyID"] as? String,history)
        elevation.coordinate(withNormalizedOffset:CGVector(dx:0.70,dy:0.5)).press(forDuration:0.1,
            thenDragTo:elevation.coordinate(withNormalizedOffset:CGVector(dx:0.30,dy:0.5)))
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            guard let value=self.previewProbe()["elevation"] as? Double else {return false}
            return value<45
        },object:app)],timeout:10),.completed)
        let draftElevation=previewProbe()["elevation"] as? Double
        XCTAssertNotEqual(draftElevation,45)
        element("shotCamera.thirdPerson").tap();ready(element("masseJump.replay"))
        // Observe archived inputs during real playback, with enough time for AX snapshots.
        element("masseJump.more").tap();revealMenu("masseJump.lastShot").tap()
        let slow=element("masseJump.speed.slow");ready(slow);slow.tap()
        element("masseJump.dismissMenu").tap();ready(element("masseJump.replay"))
        let currentCamera=previewProbe()["camera"] as? [Double]
        XCTAssertEqual(currentCamera?.count,3)
        element("masseJump.replay").tap()
        var replaySnapshot:[String:Any]?
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let p=self.previewProbe()
            guard p["phase"] as? String == "replaying" else {return false}
            replaySnapshot=p
            return true
        },object:app)],timeout:10),.completed)
        // This shot lasts only 1.25 s at quarter speed. Validate one actual
        // replaying snapshot; a later AX query may correctly see the restored draft.
        XCTAssertEqual(replaySnapshot?["phase"] as? String,"replaying")
        XCTAssertEqual(replaySnapshot?["displayedElevation"] as? Double,45)
        let replayData=try! JSONSerialization.data(withJSONObject:replaySnapshot ?? [:],options:.sortedKeys)
        let replayAttachment=XCTAttachment(data:replayData,uniformTypeIdentifier:"public.json")
        replayAttachment.name="v66-native-active-replay-input";replayAttachment.lifetime = .keepAlways;add(replayAttachment)
        ready(element("masseJump.retry"))
        XCTAssertEqual(previewProbe()["elevation"] as? Double,draftElevation)
        XCTAssertEqual(previewProbe()["displayedElevation"] as? Double,draftElevation)
        XCTAssertEqual(previewProbe()["cueWorld"] as? [Double],before)
        let returnedCamera=previewProbe()["camera"] as? [Double]
        XCTAssertEqual(returnedCamera?.count,3)
        for (a,b) in zip(returnedCamera ?? [],currentCamera ?? []) {XCTAssertEqual(a,b,accuracy:0.0001)}
        XCTAssertEqual(previewProbe()["historyID"] as? String,history)
        capture("v66-native-replay-restored-draft")
        element("masseJump.retry").tap();ready(strike)
        XCTAssertEqual(previewProbe()["cueWorld"] as? [Double],before)
        XCTAssertEqual(previewProbe()["elevation"] as? Double,45)
        strike.tap();XCUIDevice.shared.press(.home);app.activate();ready(elevation)
        XCTAssertEqual(previewProbe()["cueWorld"] as? [Double],before)
        XCTAssertEqual(previewProbe()["phase"] as? String,"ready")
        element("masseJump.back").tap()
    }
    func testZSpatialEmptyTableMenuAndIndependentLayout() {
        app=XCUIApplication.launchClean(extraArgs:["-v50.inMemoryStore","-freeLayout.ephemeral","-forcePremium","-masseJump.probe"])
        app.switchTab(.angle)
        let advanced=app.buttons["angleHomeTab_进阶"];ready(advanced);advanced.tap()
        let entry=app.buttons["扎杆与跳球"];ready(entry);entry.tap()
        let elevation=element("masseJump.elevation");ready(elevation);settledTable()
        let original=elevation.frame,aim=element("masseJump.aimWheel").frame
        XCTAssertGreaterThanOrEqual(original.width+1e-6,44) // Native CGRect floating-point roundoff.
        XCTAssertGreaterThanOrEqual(original.minX,aim.maxX-1)
        element("masseJump.more").tap();revealMenu("controlLayout.open").tap()
        let choice=element("freeLayout.select.shot.elevation");ready(choice);choice.tap()
        let start=choice.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.8))
        start.press(forDuration:0.1,thenDragTo:start.withOffset(CGVector(dx:20,dy:0)))
        let larger=element("freeLayout.larger");ready(larger);larger.tap()
        capture("v66-elevation-layout-preview")
        element("freeLayout.cancel").tap();ready(elevation)
        XCTAssertEqual(elevation.frame.midX,original.midX,accuracy:2)
        XCTAssertEqual(elevation.frame.width,original.width,accuracy:2)
        element("masseJump.more").tap();revealMenu("controlLayout.open").tap()
        ready(choice);choice.tap()
        let saveStart=choice.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.8))
        saveStart.press(forDuration:0.1,thenDragTo:saveStart.withOffset(CGVector(dx:20,dy:0)))
        ready(larger);larger.tap();element("freeLayout.save").tap()
        let name=app.alerts.textFields.firstMatch;ready(name);name.tap()
        if let text=name.value as? String,!text.isEmpty,text != "模板名称" {
            name.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:text.count))
        }
        name.typeText("扎杆跳球验收布局");app.alerts.buttons["保存"].tap()
        ready(elevation);settledTable()
        let saved=elevation.frame
        XCTAssertGreaterThan(saved.width,original.width)
        element("masseJump.back").tap();ready(advanced);entry.tap();ready(elevation);settledTable()
        XCTAssertEqual(elevation.frame.midX,saved.midX,accuracy:2)
        XCTAssertEqual(elevation.frame.width,saved.width,accuracy:2)
        capture("v66-elevation-layout-saved-reentered")
        element("masseJump.more").tap();revealMenu("masseJump.clear").tap()
        let cancel=app.buttons["取消"]
        if cancel.exists { cancel.tap() }
        else {
            // iPad confirmation dialogs dismiss by tapping outside the popover.
            app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.9)).tap()
        }
        XCTAssertTrue(app.buttons["清空桌面"].firstMatch.waitForNonExistence(timeout:5))
        ready(elevation)
        let before=previewProbe()["onTable"] as? Int
        element("masseJump.more").tap();revealMenu("masseJump.clear").tap()
        let clear=app.buttons["清空桌面"].firstMatch;ready(clear);clear.tap()
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            self.previewProbe()["onTable"] as? Int == 0 && self.element("masseJump.strike").label == "放回母球"
        },object:app)],timeout:5),.completed)
        XCTAssertEqual(previewProbe()["onTable"] as? Int,0)
        XCTAssertGreaterThan(before ?? 0,0)
        let strike=element("masseJump.strike");ready(strike)
        XCTAssertEqual(strike.label,"放回母球");strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            self.previewProbe()["onTable"] as? Int == 1 && self.element("masseJump.strike").label == "击球"
        },object:app)],timeout:5),.completed)
        XCTAssertEqual(previewProbe()["onTable"] as? Int,1)
        capture("v66-empty-cue-return")
        element("masseJump.more").tap();revealMenu("masseJump.reset").tap()
        app.buttons["恢复默认"].firstMatch.tap();ready(elevation)
        XCTAssertEqual(previewProbe()["elevation"] as? Double,45)
        XCTAssertEqual(previewProbe()["speed"] as? Double,2)
        XCTAssertEqual(previewProbe()["onTable"] as? Int,1)
        let yaw=previewProbe()["yaw"] as? Double
        let direction=element("masseJump.aimWheel");ready(direction)
        direction.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.7)).press(forDuration:0.1,
            thenDragTo:direction.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.3)))
        XCTAssertNotEqual(previewProbe()["yaw"] as? Double,yaw)
        let power=element("shotStage.powerBar");ready(power)
        power.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.65)).press(forDuration:0.1,
            thenDragTo:power.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.35)))
        XCTAssertNotEqual(previewProbe()["speed"] as? Double,2)
        let spin=element("shotStage.spinEntry");ready(spin);spin.tap()
        let disc=element("spinPad.disc");ready(disc)
        disc.coordinate(withNormalizedOffset:CGVector(dx:0.58,dy:0.42)).tap()
        XCTAssertGreaterThan(abs(previewProbe()["spinX"] as? Double ?? 0)+abs(previewProbe()["spinY"] as? Double ?? 0),0.01)
        capture("v66-spin-selected")
        // The dismissal layer covers the stage, behind the actual disc. Its
        // accessibility frame centre is not a physical close button.
        app.buttons["关闭打点"].coordinate(withNormalizedOffset:CGVector(dx:0.05,dy:0.05)).tap()
        XCTAssertTrue(disc.waitForNonExistence(timeout:5))
        XCTAssertGreaterThan(abs(previewProbe()["spinX"] as? Double ?? 0)+abs(previewProbe()["spinY"] as? Double ?? 0),0.01)
        XCTAssertFalse(element("masseJump.calculating").exists)
        for value in [0.0,0.5,1.0] {
            element("masseJump.more").tap();revealMenu("masseJump.transparency").tap()
            let slider=app.sliders["dailyClearance.spinTransparencySlider"];ready(slider)
            slider.adjust(toNormalizedSliderPosition:value)
            XCTAssertEqual(slider.value as? String,"\(Int(value*100))%")
            capture("v66-spin-transparency-\(Int(value*100))")
            element("dailyClearance.spinTransparencyDone").tap()
            ready(app.buttons["回中"]);app.buttons["回中"].tap()
            XCTAssertEqual(previewProbe()["spinX"] as? Double,0)
            XCTAssertEqual(previewProbe()["spinY"] as? Double,0)
            app.buttons["chevron.up"].tap()
            XCTAssertEqual(previewProbe()["spinY"] as? Double ?? -1,0.01,accuracy:0.00001)
            app.buttons["回中"].tap()
            app.buttons["关闭打点"].coordinate(withNormalizedOffset:CGVector(dx:0.05,dy:0.05)).tap()
        }
        capture("v66-four-inputs-native")
        element("masseJump.back").tap()
    }

}
