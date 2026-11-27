import XCTest
import UIKit

final class SpatialQuizUITests: XCTestCase {
    private var app:XCUIApplication!
    override func setUp() { continueAfterFailure=false }
    override func tearDown() { app?.terminate();XCUIDevice.shared.orientation = .portrait }
    private func element(_ id:String)->XCUIElement { app.descendants(matching:.any).matching(identifier:id).firstMatch }
    private func ready(_ e:XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == true AND hittable == true AND enabled == true"),object:e)],timeout:60),.completed,e.debugDescription)
    }
    private func probe(_ id:String)->[String:Any] {
        let text=element(id == "masseJump" ? id+".previewProbe" : id+".probe").value as? String ?? "{}"
        return (try? JSONSerialization.jsonObject(with:Data(text.utf8))) as? [String:Any] ?? [:]
    }
    private func renderer()->[String:Any] {
        let text=element("table.scene").value as? String ?? "{}"
        return (try? JSONSerialization.jsonObject(with:Data(text.utf8))) as? [String:Any] ?? [:]
    }
    private func wait(_ id:String,_ condition:@escaping ([String:Any])->Bool) {
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in condition(self.probe(id)) },object:app)],timeout:90),.completed,probe(id).description)
    }
    private func capture(_ name:String) {
        let a=XCTAttachment(screenshot:XCUIScreen.main.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)
        let camera=element("v63.cameraDiagnostics"),state=element(name.hasPrefix("masse") ? "massePractice.probe" : "jumpPractice.probe")
        let diagnostics=(camera.exists ? camera.value as? String ?? "" : "settings: no scene")+"\n"+(state.exists ? state.value as? String ?? "" : "")
        let d=XCTAttachment(string:diagnostics);d.name=name+"-diagnostics";d.lifetime = .keepAlways;add(d)
        if element("table.scene").exists {
            let r=XCTAttachment(string:element("table.scene").value as? String ?? "")
            r.name=name+"-renderer";r.lifetime = .keepAlways;add(r)
        }
    }
    private func settled(_ id:String) {
        var previous:[CGRect]=[],since=Date()
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let frames=[self.app.windows.firstMatch.frame]+["elevation","strike","replay","retry"].map { self.element(id+"."+$0).frame }
            guard !frames.contains(where: \.isEmpty) else { return false }
            if frames != previous { previous=frames;since=Date();return false }
            return Date().timeIntervalSince(since)>=1
        },object:app)],timeout:30),.completed)
    }
    private func camera(_ mode:String) {
        let value=element("v63.cameraDiagnostics")
        var observed="missing camera"
        // A predicate on XCUIElement asks XCTest to dump the whole hierarchy on
        // every unsuccessful poll. iOS17's runtime-log callback can crash under
        // that volume. Read only the diagnostic value, retaining the same checks.
        let result=XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            observed=value.value as? String ?? "missing camera"
            return observed.contains("twoViewMode="+mode) && observed.contains("twoViewMoving=false")
        },object:app)],timeout:40)
        if result != .completed { capture("camera-"+mode+"-failed") }
        XCTAssertEqual(result,.completed,observed)
    }
    private func open(_ title:String,id:String,reference:Bool,miss:Bool=false,search:Bool=true,premium:Bool=true,benchmark:String?=nil,extra:[String]=[],beforeStart:(()->Void)?=nil) {
        app=XCUIApplication()
        app.launchEnvironment["SPATIAL_TEST_SESSION"]=UUID().uuidString
        app.launchArguments=["-hasCompletedOnboarding","YES","-firstRun.profileFlow.v1","completed","-v50.inMemoryStore",
            "-freeLayout.ephemeral",premium ? "-forcePremium" : "-forceNonPremium","-spatialQuiz.probe","-v63.cameraDiagnostics","-3dDrag.probe"]
        app.launchArguments += extra
        if let benchmark { app.launchEnvironment["SPATIAL_BENCHMARK_MODE"]=benchmark }
        if reference { app.launchArguments.append("-spatialQuiz.referenceInput") }
        if miss { app.launchArguments.append("-spatialQuiz.missInput") }
        app.launch()
        let system = XCUIApplication(bundleIdentifier:"com.apple.springboard")
        let later = system.alerts.buttons["以后"]
        if later.waitForExistence(timeout:2) { later.tap() }
        app.switchTab(.angle)
        if search {
            let field=app.textFields["librarySearchField"];ready(field);field.tap();field.typeText(title)
        } else {
            let advanced=app.buttons["angleHomeTab_进阶"];ready(advanced);advanced.tap()
            // The ordered advanced grid can put the later answer cards below the viewport.
            for _ in 0..<4 {
                if app.buttons[title].exists && app.buttons[title].isHittable { break }
                app.swipeUp()
            }
        }
        ready(app.buttons[title]);app.buttons[title].tap()
        if id != "masseJump" {
            ready(element(id+".start"));capture(id+"-settings-before-start")
            beforeStart?();element(id+".start").tap()
            wait(id) { $0["phase"] as? String == "aiming" && $0["profile"] as? String == "R" }
        } else { wait(id) { $0["ready"] as? Bool == true } }
        ready(element(id+".elevation"));ready(element(id+".strike"))
        settled(id)
    }
    private func menu(_ id:String,_ item:String) {
        let scroll=app.scrollViews["dailyClearance.menuScroll"]
        if !scroll.exists {
            let more=element(id+".more");ready(more)
            more.coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.5)).tap()
        }
        XCTAssertTrue(scroll.waitForExistence(timeout:10),app.debugDescription)
        reveal(item).tap()
    }
    private func reveal(_ id:String)->XCUIElement {
        let value=element(id),scroll=app.scrollViews["dailyClearance.menuScroll"]
        for _ in 0..<7 { if value.isHittable { break };scroll.swipeUp() }
        ready(value);return value
    }
    private func cameraEye()->[Double] {
        let text=element("v63.cameraDiagnostics").value as? String ?? ""
        return ["twoViewEyeX","twoViewEyeY","twoViewEyeZ"].map { key in
            text.split(separator:" ").first(where:{$0.hasPrefix(key+"=")}).flatMap { Double($0.dropFirst(key.count+1)) } ?? .nan
        }
    }
    private func sideSwipe() {
        let scene=element("table.scene")
        scene.coordinate(withNormalizedOffset:.init(dx:0.40,dy:0.30)).press(forDuration:0.1,
            thenDragTo:scene.coordinate(withNormalizedOffset:.init(dx:0.57,dy:0.30)))
    }
    func testThreeSpatialPagesDragOnlyObservesAndRulerKeepsSideCamera() throws {
        for (title,id) in [("扎杆与跳球","masseJump"),("扎杆练习","massePractice"),("跳球练习","jumpPractice")] {
            open(title,id:id,reference:false,search:false,extra:["-masseJump.probe"])
            if id == "massePractice" { XCTAssertEqual(probe(id)["elevation"] as? Double,25) }
            if id == "jumpPractice" { XCTAssertEqual(probe(id)["elevation"] as? Double,45) }
            camera("thirdPerson")
            let yaw=try XCTUnwrap(probe(id)["yaw"] as? Double), before=cameraEye()
            sideSwipe()
            condition("Scene drag must change the third-person eye") { zip(self.cameraEye(),before).contains { abs($0-$1)>0.0001 } }
            XCTAssertEqual(probe(id)["yaw"] as? Double,yaw)
            let observed=cameraEye(),direction=element(id+".aimWheel");ready(direction)
            direction.coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.6)).press(forDuration:0.1,
                thenDragTo:direction.coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.4)))
            wait(id) { $0["yaw"] as? Double != yaw }
            for (a,b) in zip(cameraEye(),observed) { XCTAssertEqual(a,b,accuracy:0.001) }
            capture(id+"-side-observation-ruler")
            app.terminate()
        }
    }
    func testBothFormalPagesControlsCameraAndSettingsCancel() throws {
        for (title,id) in [("扎杆练习","massePractice"),("跳球练习","jumpPractice")] {
            open(title,id:id,reference:false)
            let original=probe(id),question=try XCTUnwrap(original["question"] as? String)
            let host=try XCTUnwrap(renderer()["rendererID"] as? String)
            XCTAssertEqual(app.descendants(matching:.any).matching(identifier:"table.scene").count,1)
            let balls=try XCTUnwrap(renderer()["balls"] as? [[String:Any]])
            XCTAssertEqual(balls.count,3);XCTAssertTrue(balls.allSatisfy { $0["draggable"] as? Bool == false })
            XCTAssertEqual(original["recipe"] as? String,"liveReference");XCTAssertEqual(original["p01"] as? Bool,true)
            XCTAssertEqual(original["attempts"] as? Int,0);XCTAssertEqual(original["unlocked"] as? Bool,false)
            XCTAssertFalse(element(id+".retry").isEnabled);XCTAssertFalse(element(id+".replay").isEnabled)
            XCTAssertFalse(element("break.entry").exists)
            let direction=element(id+".aimWheel");ready(direction)
            direction.coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.7)).press(forDuration:0.1,thenDragTo:direction.coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.3)))
            wait(id) { $0["yaw"] as? Double != original["yaw"] as? Double }
            let power=element("shotStage.powerBar");ready(power)
            power.coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.65)).press(forDuration:0.1,thenDragTo:power.coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.35)))
            wait(id) { $0["speed"] as? Double != original["speed"] as? Double }
            let spin=element("shotStage.spinEntry");ready(spin);spin.tap()
            let disc=element("spinPad.disc");ready(disc)
            disc.coordinate(withNormalizedOffset:.init(dx:0.58,dy:0.42)).tap()
            wait(id) { abs($0["spinX"] as? Double ?? 0)+abs($0["spinY"] as? Double ?? 0)>0.01 }
            capture(id+"-spin-input")
            app.buttons["关闭打点"].coordinate(withNormalizedOffset:.init(dx:0.05,dy:0.05)).tap()
            XCTAssertTrue(disc.waitForNonExistence(timeout:5))
            let wheel=element(id+".elevation")
            XCTAssertGreaterThan(wheel.frame.width,wheel.frame.height)
            XCTAssertGreaterThanOrEqual(wheel.frame.minX,element(id+".replay").frame.maxX-1)
            let elevation=try XCTUnwrap(original["elevation"] as? Double)
            wheel.coordinate(withNormalizedOffset:.init(dx:0.2,dy:0.5)).press(forDuration:0.05,thenDragTo:wheel.coordinate(withNormalizedOffset:.init(dx:0.8,dy:0.5)))
            wait(id) { ($0["elevation"] as? Double ?? 0)>elevation }
            capture(id+"-four-input-layout")
            ready(element("shotCamera.firstPerson"));element("shotCamera.firstPerson").tap();camera("firstPerson");capture(id+"-first-person")
            ready(element("shotCamera.thirdPerson"));element("shotCamera.thirdPerson").tap();camera("thirdPerson")
            ready(element("shotCamera.temporaryTopDown"));element("shotCamera.temporaryTopDown").tap()
            wait(id) { $0["topDown"] as? Bool == true };capture(id+"-read-only-overhead")
            XCTAssertFalse(element(id+".strike").isEnabled)
            element("shotCamera.temporaryTopDown").tap();wait(id) { $0["topDown"] as? Bool == false }
            XCTAssertEqual(renderer()["rendererID"] as? String,host)
            menu(id,id+".settings");ready(element("training.settingsCancel"));capture(id+"-settings-return")
            element("training.settingsCancel").tap();ready(element(id+".elevation"))
            XCTAssertEqual(probe(id)["question"] as? String,question)
            XCTAssertEqual(probe(id)["attempts"] as? Int,0)
            element("shotCamera.firstPerson").tap();camera("firstPerson")
            ready(element(id+".back"));element(id+".back").tap()
            ready(app.buttons[title]);app.buttons[title].tap()
            wait(id) { $0["phase"] as? String == "aiming" }
            ready(element(id+".elevation"));settled(id);camera("thirdPerson")
            XCTAssertEqual(probe(id)["question"] as? String,question)
            capture(id+"-reentry-default-third-person")
            let resumed=probe(id)
            XCUIDevice.shared.press(.home);app.activate();ready(element(id+".elevation"));settled(id)
            XCTAssertEqual(probe(id)["question"] as? String,question)
            XCTAssertEqual(probe(id)["elevation"] as? Double,resumed["elevation"] as? Double)
            if UIDevice.current.userInterfaceIdiom == .pad {
                for orientation in [UIDeviceOrientation.landscapeLeft,.portrait] {
                    XCUIDevice.shared.orientation=orientation
                    ready(element(id+".strike"));ready(element(id+".elevation"))
                    settled(id)
                    capture(id+"-pad-\(orientation.rawValue)")
                    XCTAssertEqual(probe(id)["question"] as? String,question)
                }
            }
            app.terminate()
        }
    }
    func testBothPagesSuccessfulStrokeReplayDemoAndRetry() throws {
        for (title,id) in [("扎杆练习","massePractice"),("跳球练习","jumpPractice")] {
            open(title,id:id,reference:true)
            capture(id+"-reference-input-before-stroke")
            element(id+".strike").tap()
            wait(id) { $0["phase"] as? String == "result" && $0["activity"] as? String == "idle" }
            let result=probe(id),latest=try XCTUnwrap(result["latest"] as? String)
            XCTAssertEqual(result["successes"] as? Int,1);XCTAssertEqual(result["unlocked"] as? Bool,true)
            XCTAssertEqual(element(id+".result").label,"成功")
            capture(id+"-success-result")
            ready(element("shotCamera.firstPerson"));element("shotCamera.firstPerson").tap();camera("firstPerson")
            capture(id+"-before-demo-first-person")
            menu(id,id+".lastShot");reveal(id+".slow").tap()
            element(id+".more").coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.5)).tap()
            ready(element(id+".demonstration"));element(id+".demonstration").tap()
            wait(id) { $0["activity"] as? String == "demonstrating" };camera("thirdPerson")
            let demoEye=cameraEye(),demoInput=probe(id)
            sideSwipe()
            condition("Demonstration must allow side observation") { zip(self.cameraEye(),demoEye).contains { abs($0-$1)>0.0001 } }
            for key in ["yaw","speed","spinX","spinY","elevation"] { XCTAssertEqual(probe(id)[key] as? Double,demoInput[key] as? Double,key) }
            capture(id+"-read-only-demonstration")
            XCTAssertFalse(element(id+".elevation").isEnabled)
            ready(element(id+".strike"));element(id+".strike").tap()
            wait(id) { $0["activity"] as? String == "idle" }
            XCTAssertEqual(probe(id)["latest"] as? String,latest)
            camera("firstPerson")
            menu(id,id+".lastShot");reveal(id+".playerReplay").tap()
            wait(id) { $0["activity"] as? String == "replaying" }
            element(id+".strike").tap();wait(id) { $0["activity"] as? String == "idle" }
            ready(element(id+".retry"));element(id+".retry").tap()
            wait(id) { $0["phase"] as? String == "aiming" }
            XCTAssertEqual(probe(id)["attempts"] as? Int,1);XCTAssertEqual(probe(id)["latest"] as? String,latest)
            capture(id+"-retry-player-input-restored")
            app.terminate()
        }
    }
    func testBothPagesCurrentAimCloseupOnlyDuringDirectionGesture() throws {
        for (title,id,mode) in [("扎杆练习","massePractice","masse"),("跳球练习","jumpPractice","jump")] {
            open(title,id:id,reference:false,search:false,benchmark:mode)
            let original=probe(id)
            // Deterministic frozen board, normal public initial direction toward
            // target. No answer input or injected loupe is used.
            func setCloseup(_ enabled:Bool) {
                let more=element(id+".more");ready(more)
                more.coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.5)).tap()
                let toggle=reveal("menu.aimCloseup")
                if (toggle.value as? String == "已选") != enabled { toggle.tap() }
                XCTAssertEqual(toggle.value as? String,enabled ? "已选":"未选")
                more.coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.5)).tap()
            }
            for enabled in [true,false] {
                setCloseup(enabled)
                XCTAssertFalse(element("aimCloseup.hud").exists)
                let wheel=element(id+".aimWheel");ready(wheel)
                FileHandle.standardOutput.write(Data("SPATIAL_CLOSEUP_HOLD \(id)-\(enabled ? "enabled":"disabled")\n".utf8))
                let start=wheel.coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.5))
                start.press(forDuration:0.1,thenDragTo:start.withOffset(.init(dx:0,dy:enabled ? 2:-2)),
                    withVelocity:.slow,thenHoldForDuration:8)
                XCTAssertFalse(element("aimCloseup.hud").exists,"Release must hide the shared loupe")
                capture(id+"-closeup-released-\(enabled)")
            }
            setCloseup(true)
            element("shotStage.spinEntry").tap();ready(element("spinPad.disc"))
            XCTAssertFalse(element("aimCloseup.hud").exists)
            app.buttons["关闭打点"].coordinate(withNormalizedOffset:.init(dx:0.05,dy:0.05)).tap()
            XCUIDevice.shared.press(.home);app.activate();ready(element(id+".elevation"))
            XCTAssertFalse(element("aimCloseup.hud").exists)
            XCTAssertEqual(probe(id)["question"] as? String,original["question"] as? String)
            XCTAssertEqual(probe(id)["attempts"] as? Int,0)
            app.terminate()
        }
    }
    func testBothPagesThreeRealMissesUnlockOnlyOnResult() throws {
        for (title,id) in [("扎杆练习","massePractice"),("跳球练习","jumpPractice")] {
            open(title,id:id,reference:false,miss:true)
            var previous=""
            for number in 1...3 {
                ready(element(id+".strike"));element(id+".strike").tap()
                wait(id) { $0["phase"] as? String == "result" && $0["activity"] as? String == "idle" }
                let result=probe(id),latest=try XCTUnwrap(result["latest"] as? String)
                XCTAssertFalse(latest.isEmpty);XCTAssertNotEqual(latest,previous);previous=latest
                XCTAssertEqual(result["lastSucceeded"] as? Bool,false)
                XCTAssertEqual(result["attempts"] as? Int,1)
                XCTAssertEqual(result["unlocked"] as? Bool,number == 3)
                XCTAssertEqual(element(id+".demonstration").exists,number == 3,"Unlocked demonstration must be visible without a menu")
                capture(id+"-real-miss-\(number)")
                if number<3 { ready(element(id+".retry"));element(id+".retry").tap();wait(id) { $0["phase"] as? String == "aiming" } }
            }
            app.terminate()
        }
    }
    func testBothPagesKeepPersonalElevationLayoutWhenUsingDefault() throws {
        for (title,id) in [("扎杆练习","massePractice"),("跳球练习","jumpPractice")] {
            open(title,id:id,reference:false)
            let original=probe(id),question=try XCTUnwrap(original["question"] as? String)
            menu(id,"controlLayout.open")
            let key=element("freeLayout.select.shot.elevation");ready(key)
            let originalFrame=key.frame
            key.tap();ready(element("freeLayout.larger"));element("freeLayout.larger").tap()
            let editedFrame=key.frame
            XCTAssertGreaterThan(editedFrame.width,originalFrame.width)
            element("freeLayout.save").tap()
            let field=app.alerts.textFields.firstMatch;ready(field);field.tap()
            if let text=field.value as? String,!text.isEmpty,text != field.placeholderValue {
                field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:text.count))
            }
            let name=title+"横尺验收";field.typeText(name);app.alerts.buttons["保存"].tap()
            ready(element(id+".elevation"));capture(id+"-personal-layout")
            menu(id,"controlLayout.open");ready(key)
            XCTAssertEqual(key.frame.width,editedFrame.width,accuracy:1)
            element("freeLayout.templates").tap();ready(element("freeLayout.defaultActions"));element("freeLayout.defaultActions").tap()
            ready(element("freeLayout.useDefault"));element("freeLayout.useDefault").tap()
            XCTAssertTrue(element("freeLayout.editor").waitForNonExistence(timeout:10))
            ready(element(id+".elevation"));capture(id+"-default-layout-restored")
            menu(id,"controlLayout.open");ready(key)
            XCTAssertEqual(key.frame.width,originalFrame.width,accuracy:1)
            element("freeLayout.templates").tap()
            let actions=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@ AND label CONTAINS %@","freeLayout.templateActions.",name)).firstMatch
            ready(actions);actions.tap();ready(element("freeLayout.useTemplate"));element("freeLayout.useTemplate").tap()
            XCTAssertTrue(element("freeLayout.editor").waitForNonExistence(timeout:10))
            menu(id,"controlLayout.open");ready(key)
            XCTAssertEqual(key.frame.width,editedFrame.width,accuracy:1)
            element("freeLayout.cancel").tap();ready(element(id+".elevation"))
            XCTAssertEqual(probe(id)["question"] as? String,question)
            XCTAssertEqual(probe(id)["elevation"] as? Double,original["elevation"] as? Double)
            XCTAssertEqual(probe(id)["attempts"] as? Int,0)
            app.terminate()
        }
    }
    func testBothHistoriesShowFrozenFirstAnswerAfterRetryAndReentry() throws {
        for (title,id) in [("扎杆练习","massePractice"),("跳球练习","jumpPractice")] {
            open(title,id:id,reference:true,search:false)
            element(id+".strike").tap()
            wait(id) { $0["phase"] as? String == "result" && $0["activity"] as? String == "idle" }
            XCTAssertEqual(probe(id)["successes"] as? Int,1)
            ready(element(id+".retry"));element(id+".retry").tap()
            wait(id) { $0["phase"] as? String == "aiming" }
            ready(element(id+".back"));element(id+".back").tap()
            capture(id+"-history-navigation-return")
            app.switchTab(.history)
            let row=element("history."+id);ready(row)
            capture(id+"-history-first-answer")
            XCTAssertTrue(row.label.contains(title+" · 模拟练习"),row.debugDescription)
            XCTAssertTrue(row.label.contains("已练1题") && row.label.contains("成功1题"),row.label)
            app.terminate()
        }
    }

    private func condition(_ message:String,timeout:Double=30,_ body:@escaping ()->Bool) {
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in body() },object:app)],timeout:timeout),.completed,message)
    }
    private func runtime()->[String:Any] {
        let text=element("spatial.runtime").value as? String ?? "{}"
        return (try? JSONSerialization.jsonObject(with:Data(text.utf8))) as? [String:Any] ?? [:]
    }
    private func json(_ value:Any,_ name:String) throws {
        let data=try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys])
        let a=XCTAttachment(data:data,uniformTypeIdentifier:"public.json");a.name=name;a.lifetime = .keepAlways;add(a)
    }
    func testBothModesFifteenthAnswerQuotaAndPurchaseCancellation() throws {
        for (title,id,theme) in [("扎杆练习","massePractice","Dark"),("跳球练习","jumpPractice","Light")] {
            open(title,id:id,reference:false,miss:true,search:false,premium:false,extra:["-v54.force"+theme],beforeStart:{
                let free=self.app.buttons["持续练习"];self.ready(free);free.tap()
                let close=self.element("subscription.close");self.ready(close);close.tap()
                self.ready(self.app.buttons["15题"])
                XCTAssertTrue(self.app.buttons["15题"].isSelected)
                self.capture(id+"-purchase-cancel-"+theme)
            })
            XCTAssertEqual(probe(id)["quotaUsed"] as? Int,0)
            for number in 1...15 {
                ready(element(id+".strike"));element(id+".strike").tap()
                wait(id) { $0["phase"] as? String == "result" && $0["activity"] as? String == "idle" }
                XCTAssertEqual(probe(id)["attempts"] as? Int,number)
                XCTAssertEqual(probe(id)["quotaUsed"] as? Int,number)
                if number<15 { element(id+".strike").tap();wait(id) { $0["phase"] as? String == "aiming" } }
            }
            capture(id+"-fifteenth-result")
            XCTAssertEqual(element(id+".strike").label,"查看总结")
            element(id+".retry").tap();wait(id) { $0["phase"] as? String == "aiming" }
            element(id+".strike").tap();wait(id) { $0["phase"] as? String == "result" && $0["activity"] as? String == "idle" }
            XCTAssertEqual(probe(id)["attempts"] as? Int,15);XCTAssertEqual(probe(id)["quotaUsed"] as? Int,15)
            element(id+".strike").tap();ready(element(id+".summary"));capture(id+"-fifteenth-summary")
            ready(app.buttons["重新开始"]);app.buttons["重新开始"].tap()
            ready(element(id+".start"));element(id+".start").tap()
            ready(element("subscription.close"));element("subscription.close").tap()
            ready(element("training.settingsCancel"));element("training.settingsCancel").tap()
            XCTAssertEqual(probe(id)["attempts"] as? Int,15);XCTAssertEqual(probe(id)["quotaUsed"] as? Int,15)
            app.terminate()
        }
    }
    func testBothModesHighElevationReadOnlyAndRealPadResize() throws {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom,.pad)
        for (title,id) in [("扎杆练习","massePractice"),("跳球练习","jumpPractice")] {
            open(title,id:id,reference:false,search:false)
            app.maximizeTrainingTestWindow();ready(element(id+".elevation"));settled(id)
            let question=probe(id)["question"] as? String,wheel=element(id+".elevation")
            for _ in 0..<12 where (probe(id)["elevation"] as? Double ?? 0)<75 {
                wheel.coordinate(withNormalizedOffset:.init(dx:0.1,dy:0.5)).press(forDuration:0.05,
                    thenDragTo:wheel.coordinate(withNormalizedOffset:.init(dx:0.9,dy:0.5)))
            }
            XCTAssertEqual(probe(id)["elevation"] as? Double,75)
            element("shotCamera.firstPerson").tap();camera("firstPerson");capture(id+"-pad-75-first-person")
            func cameraNumber(_ key:String)->Double {
                let text=element("v63.cameraDiagnostics").value as? String ?? ""
                return text.split(separator:" ").first(where:{$0.hasPrefix(key+"=")}).flatMap { Double($0.dropFirst(key.count+1)) } ?? .nan
            }
            let eyeKeys=["twoViewEyeX","twoViewEyeY","twoViewEyeZ"],eye=eyeKeys.map(cameraNumber),fov=cameraNumber("twoViewFOV")
            element("table.scene").pinch(withScale:1.25,velocity:1)
            condition("First-person pinch must advance the shared camera") {
                zip(eyeKeys.map(cameraNumber),eye).contains { abs($0-$1)>0.0001 }
            }
            camera("firstPerson");XCTAssertEqual(cameraNumber("twoViewFOV"),fov,accuracy:0.0001)
            element("shotCamera.firstPerson").tap();camera("firstPerson")
            for axis in eye.indices { XCTAssertEqual(cameraNumber(eyeKeys[axis]),eye[axis],accuracy:0.001) }
            XCTAssertEqual(probe(id)["elevation"] as? Double,75)
            element("shotCamera.thirdPerson").tap();camera("thirdPerson")
            element("shotCamera.temporaryTopDown").tap();wait(id) { $0["topDown"] as? Bool == true }
            let before=try XCTUnwrap(renderer()["balls"] as? [[String:Any]])
            let ball=try XCTUnwrap(before.first),screen=try XCTUnwrap(ball["screen"] as? [Double])
            let origin=element("table.scene").coordinate(withNormalizedOffset:.zero)
            let location=origin.withOffset(.init(dx:screen[0],dy:screen[1]))
            location.press(forDuration:0.2,thenDragTo:location.withOffset(.init(dx:40,dy:30)))
            let after=try XCTUnwrap(renderer()["balls"] as? [[String:Any]])
            XCTAssertEqual(before.compactMap {$0["world"] as? [Double]},after.compactMap {$0["world"] as? [Double]})
            XCTAssertEqual(renderer()["grabCount"] as? Int,0)
            element("shotCamera.temporaryTopDown").tap();wait(id) { $0["topDown"] as? Bool == false }
            for orientation in [UIDeviceOrientation.portrait,.landscapeLeft] {
                XCUIDevice.shared.orientation=orientation;ready(wheel);settled(id);capture(id+"-pad-75-\(orientation.rawValue)")
            }
            func viewport()->[Double] { (element(id+".viewport").value as? String ?? "").split(separator:",").compactMap {Double($0)} }
            let window=app.windows.firstMatch,original=window.frame,content=viewport()
            let originalRender=try XCTUnwrap(renderer()["displayedViewport"] as? [Double])
            XCTAssertEqual(content.count,2)
            app.coordinate(withNormalizedOffset:.init(dx:0.985,dy:0.99)).press(forDuration:1,
                thenDragTo:app.coordinate(withNormalizedOffset:.init(dx:0.62,dy:0.72)),withVelocity:.slow,thenHoldForDuration:0.5)
            condition("Actual OS window must resize") { abs(window.frame.width-original.width)>30 || abs(window.frame.height-original.height)>30 }
            condition("Actual SwiftUI viewport must resize") {
                let v=viewport();return v.count==2 && (abs(v[0]-content[0])>30 || abs(v[1]-content[1])>30)
            }
            ready(wheel);settled(id);capture(id+"-pad-real-small-window")
            for key in ["elevation","strike","retry","replay"] { XCTAssertTrue(window.frame.contains(element(id+"."+key).frame),key) }
            XCTAssertEqual(probe(id)["elevation"] as? Double,75);XCTAssertEqual(probe(id)["question"] as? String,question)
            let smallContent=viewport(),smallWindow=window.frame
            app.maximizeTrainingTestWindow();ready(wheel);settled(id)
            capture(id+"-pad-maximized-return")
            let restoredRender=try XCTUnwrap(renderer()["displayedViewport"] as? [Double])
            try json(["originalWindow":NSCoder.string(for:original),"smallWindow":NSCoder.string(for:smallWindow),
                "restoredWindow":NSCoder.string(for:window.frame),"originalContent":content,"smallContent":smallContent,
                "restoredContent":viewport(),"originalRenderer":originalRender,"restoredRenderer":restoredRender],id+"-actual-window-cycle")
            // iPadOS may change the status-bar safe inset after maximizing. The
            // owning OS window and actual SceneKit table viewport must both restore.
            XCTAssertEqual(window.frame.width,original.width,accuracy:1)
            XCTAssertEqual(window.frame.height,original.height,accuracy:1)
            XCTAssertEqual(restoredRender.count,originalRender.count)
            for axis in originalRender.indices { XCTAssertEqual(restoredRender[axis],originalRender[axis],accuracy:1) }
            app.terminate()
        }
    }
    func testBothModesSlowReplayDemoBackgroundAndMenus() throws {
        for (title,id,theme) in [("扎杆练习","massePractice","Light"),("跳球练习","jumpPractice","Dark")] {
            open(title,id:id,reference:true,search:false,extra:["-v54.force"+theme,"-spatialQuiz.metrics","-dailyLayout.probe"])
            menu(id,"menu.tableGrid")
            // Dismiss the retained menu through its original toggle.
            element(id+".more").coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.5)).tap()
            ready(element(id+".strike"));element(id+".strike").tap()
            wait(id) { $0["activity"] as? String == "playing" }
            XCTAssertFalse(element(id+".elevation").isEnabled)
            XCUIDevice.shared.press(.home);app.activate()
            wait(id) { $0["activity"] as? String == "idle" && $0["phase"] as? String == "result" }
            let first=probe(id);capture(id+"-stroke-background-return")
            menu(id,id+".lastShot");reveal(id+".slow").tap()
            element(id+".more").coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.5)).tap()
            menu(id,id+".lastShot");reveal(id+".playerReplay").tap()
            wait(id) { $0["activity"] as? String == "replaying" }
            XCTAssertEqual(probe(id)["playbackSpeed"] as? Double,0.25)
            capture(id+"-quarter-speed-replay");XCUIDevice.shared.press(.home);app.activate()
            wait(id) { $0["activity"] as? String == "idle" }
            ready(element(id+".demonstration"));element(id+".demonstration").tap()
            wait(id) { $0["activity"] as? String == "demonstrating" }
            XCUIDevice.shared.press(.home);app.activate();wait(id) { $0["activity"] as? String == "idle" }
            XCTAssertEqual(probe(id)["latest"] as? String,first["latest"] as? String)
            XCTAssertEqual(probe(id)["attempts"] as? Int,1)
            ready(element(id+".back"));element(id+".back").tap()
            condition("Quiz VM and detached worker must release") { (self.runtime()["live"] as? [String])?.isEmpty == true }
            try json(runtime(),id+"-released-after-backgrounds")
            app.terminate()
        }
    }
    func testBothModesAlwaysPlayAndShowActualRoutes() throws {
        for (title,id) in [("扎杆练习","massePractice"),("跳球练习","jumpPractice")] {
            open(title,id:id,reference:true,search:false,benchmark:id) {
                let form=self.app.collectionViews.firstMatch
                form.swipeUp();form.swipeUp()
                XCTAssertFalse(self.element(id+".playsStroke").exists)
                XCTAssertFalse(self.app.staticTexts["演示"].exists)
                self.capture(id+"-settings-no-demonstration")
            }
            XCTAssertEqual(probe(id)["routeNodes"] as? Int,0)
            ready(element(id+".strike"));element(id+".strike").tap()
            wait(id) { $0["activity"] as? String == "playing" && ($0["routeNodes"] as? Int ?? 0)>0 }
            XCTAssertEqual(probe(id)["routeSolidSegments"] as? Int,1)
            XCTAssertGreaterThanOrEqual(probe(id)["routeDashedSegments"] as? Int ?? 0,2)
            capture(id+"-actual-routes-playing")
            wait(id) { $0["activity"] as? String == "idle" && $0["phase"] as? String == "result" }
            XCTAssertGreaterThan(probe(id)["routeNodes"] as? Int ?? 0,0)
            capture(id+"-actual-routes-result")
            ready(element(id+".retry"));element(id+".retry").tap()
            wait(id) { $0["phase"] as? String == "aiming" }
            XCTAssertGreaterThan(probe(id)["routeNodes"] as? Int ?? 0,0)
            capture(id+"-historical-route-retry")
            ready(element(id+".strike"));element(id+".strike").tap()
            wait(id) { $0["activity"] as? String == "idle" && $0["phase"] as? String == "result" }
            ready(element(id+".strike"));element(id+".strike").tap()
            wait(id) { $0["phase"] as? String == "aiming" && $0["questionIndex"] as? Int == 2 }
            XCTAssertEqual(probe(id)["routeNodes"] as? Int,0)
            app.terminate()
        }
    }
    func testBothModesDisplayAndLastShotMenusPreservePlayerState() throws {
        for (title,id) in [("扎杆练习","massePractice"),("跳球练习","jumpPractice")] {
            open(title,id:id,reference:true,search:false)
            let before=probe(id)
            menu(id,id+".transparency")
            let slider=app.sliders["dailyClearance.spinTransparencySlider"];ready(slider)
            for value in [0.0,1.0,0.5] {
                slider.adjust(toNormalizedSliderPosition:value)
                if value != 0.5 { XCTAssertEqual(slider.value as? String,"\(Int(value*100))%") }
            }
            element("dailyClearance.spinTransparencyDone").tap()
            let close=app.buttons["关闭打点"];ready(close)
            close.coordinate(withNormalizedOffset:.init(dx:0.05,dy:0.05)).tap()
            XCTAssertFalse(element("spinPad.disc").exists)
            for key in ["yaw","speed","spinX","spinY","elevation"] {
                XCTAssertEqual(probe(id)[key] as? Double,before[key] as? Double,key)
            }
            ready(element(id+".strike"));element(id+".strike").tap()
            wait(id) { $0["phase"] as? String == "result" && $0["activity"] as? String == "idle" }
            let latest=probe(id)["latest"] as? String
            wait(id) { ($0["routeNodes"] as? Int ?? 0)>0 }
            menu(id,id+".lastShot");reveal(id+".route").tap()
            wait(id) { $0["routeNodes"] as? Int == 0 }
            reveal(id+".route").tap();wait(id) { ($0["routeNodes"] as? Int ?? 0)>0 }
            reveal(id+".details").tap()
            let closeDetail=app.buttons["关闭上一杆详情"];ready(closeDetail)
            capture(id+"-frozen-player-details")
            closeDetail.coordinate(withNormalizedOffset:.init(dx:0.05,dy:0.05)).tap()
            XCTAssertTrue(closeDetail.waitForNonExistence(timeout:5))
            XCTAssertEqual(probe(id)["latest"] as? String,latest)
            XCTAssertEqual(probe(id)["attempts"] as? Int,1)
            menu(id,id+".lastShot");reveal(id+".normal").tap()
            XCTAssertEqual(probe(id)["playbackSpeed"] as? Double,1)
            element(id+".more").coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.5)).tap()
            menu(id,id+".finish");ready(element(id+".summary"))
            XCTAssertEqual(probe(id)["attempts"] as? Int,1)
            app.terminate()
        }
    }
    func testMatchedFreeAndQuizInputRenderIdleAndRelease() throws {
        var reports:[[String:Any]]=[]
        for mode in ["masse","jump"] {
            for free in [false,true] {
                let id=free ? "masseJump" : (mode == "masse" ? "massePractice":"jumpPractice")
                let title=free ? "扎杆与跳球" : (mode == "masse" ? "扎杆练习":"跳球练习")
                open(title,id:id,reference:true,search:false,benchmark:mode,
                    extra:["-spatialQuiz.metrics","-dailyLayout.probe","-masseJump.probe","-masseJump.timing"])
                if UIDevice.current.userInterfaceIdiom == .pad {
                    XCUIDevice.shared.orientation = .landscapeLeft
                    app.maximizeTrainingTestWindow();ready(element(id+".elevation"));settled(id)
                }
                let sampledWindow=app.windows.firstMatch.frame
                condition("Renderer sleeps when stationary",timeout:60) { self.renderer()["rendererActive"] as? Bool == false }
                let baseline=runtime(),initial=probe(id),world=renderer(),began=Date()
                condition("Five-second idle sample",timeout:10) { Date().timeIntervalSince(began)>5 }
                let idle=runtime()
                func rows()->[[String:Double]] {
                    let text=element(id+".timingProbe").value as? String ?? "[]"
                    return (try? JSONSerialization.jsonObject(with:Data(text.utf8))) as? [[String:Double]] ?? []
                }
                let wheel=element(id+".elevation")
                for i in 0..<8 {
                    let count=rows().count,start=wheel.coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.5))
                    start.press(forDuration:0.05,thenDragTo:start.withOffset(.init(dx:i.isMultiple(of:2) ? 8:-8,dy:0)))
                    condition("Actual post-input renderer receipt",timeout:60) { rows().count>count }
                    if free { wait(id) { $0["ready"] as? Bool == true } }
                }
                let inputRows=rows()
                let poseText=element(id+".poseTimingProbe").value as? String ?? "[]"
                let poseRows=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(poseText.utf8)) as? [[String:Double]])
                XCTAssertGreaterThanOrEqual(poseRows.count,8)
                // Native touch delivery is continuous, so +/- drags need not
                // cancel bit-for-bit. Re-enter the same frozen fixture for an
                // exact matched strike; never round production input to pass.
                element(id+".back").tap();ready(app.buttons[title]);app.buttons[title].tap()
                ready(element(id+".elevation"));settled(id)
                if free { wait(id) { $0["ready"] as? Bool == true } }
                for key in ["yaw","speed","spinX","spinY","elevation"] {
                    XCTAssertEqual(try XCTUnwrap(probe(id)[key] as? Double),try XCTUnwrap(initial[key] as? Double),accuracy:0.0001,key)
                }
                element(id+".strike").tap()
                if free { wait(id) { $0["phase"] as? String == "playing" } }
                else { wait(id) { $0["activity"] as? String == "playing" || $0["phase"] as? String == "result" } }
                let loaded=runtime()
                if element(id+".strike").label == "停止" { element(id+".strike").tap() }
                ready(element(id+".back"));element(id+".back").tap()
                condition("No retained VM/worker after navigation",timeout:60) { (self.runtime()["live"] as? [String])?.isEmpty == true }
                let released=runtime()
                reports.append(["mode":mode,"page":id,"window":NSCoder.string(for:sampledWindow),
                    "input":initial,"world":world,"baseline":baseline,"idle":idle,"inputs":inputRows,"poseInputs":poseRows,"loaded":loaded,"released":released])
                try json(reports,"b5-matched-runtime-partial")
                app.terminate()
            }
        }
        try json(reports,"b5-matched-runtime-final")
    }

}
