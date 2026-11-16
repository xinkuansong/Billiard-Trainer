from pathlib import Path
import sys

root = Path(sys.argv[1])
here = Path(__file__).resolve().parent

def replace(text, old, new, count=1):
    assert text.count(old) == count, (old, text.count(old), count)
    return text.replace(old, new)

view = root / 'QiuJi/Core/Scene/AngleSceneView.swift'
s = view.read_text()
s = replace(s, 'func updateTemporaryTopDownOverlay() {', 'func updateTemporaryTopDownOverlay(source: String = "unspecified") {\n            let probeStart = TemporaryTopDownLatencyProbe.enabled ? CACurrentMediaTime() : 0\n            defer { if probeStart > 0 { TemporaryTopDownLatencyProbe.record("overlayUpdate", ["source": source, "durationMs": (CACurrentMediaTime() - probeStart) * 1000]) } }')
s = replace(s, 'context.coordinator.updateTemporaryTopDownOverlay()', 'context.coordinator.updateTemporaryTopDownOverlay(source: "swiftUI")')
s = replace(s, 'self.updateTemporaryTopDownOverlay()', 'self.updateTemporaryTopDownOverlay(source: "idleInvalidation")')
s = replace(s, '            updateTemporaryTopDownOverlay()\n            updateFramePacing()', '            updateTemporaryTopDownOverlay(source: "displayLink")\n            updateFramePacing()')
s = replace(s, '            requestInteractiveFrames()\n            updateTemporaryTopDownOverlay()', '            requestInteractiveFrames()\n            updateTemporaryTopDownOverlay(source: "pan")')
s = replace(s, '        func removeTemporaryTopDownOverlay() {', '        func removeTemporaryTopDownOverlay() {\n            if mergedOverlay != nil { TemporaryTopDownLatencyProbe.finish() }')
s = replace(s, '                mergedNodeCopies.removeAll()\n                overlay.scene', '                TemporaryTopDownLatencyProbe.record("buildStart")\n                mergedNodeCopies.removeAll()\n                overlay.scene')
s = replace(s, '                mergedOverlayBuildCount += 1', '                mergedOverlayBuildCount += 1\n                TemporaryTopDownLatencyProbe.record("buildTreeComplete", ["nodes": mergedNodeCopies.count, "builds": mergedOverlayBuildCount])\n                if TemporaryTopDownLatencyProbe.enabled { overlay.delegate = TemporaryTopDownLatencyProbe.shared }')
s = replace(s, '            mergedOverlay = overlay\n', '            mergedOverlay = overlay\n            if rebuild { TemporaryTopDownLatencyProbe.record("overlayAttached") }\n')
view.write_text(s + (here / 'probe.swift').read_text())

scene = root / 'QiuJi/Core/Scene/AngleTrainingScene.swift'
s = scene.read_text()
anchor = '        SCNTransaction.lock()\n        defer { SCNTransaction.unlock() }\n        SCNTransaction.begin()\n        SCNTransaction.disableActions = true\n        defer { SCNTransaction.commit() }\n        // Retain source keys'
new = '''        let probeStart = TemporaryTopDownLatencyProbe.enabled ? CACurrentMediaTime() : 0
        var probeVisited = 0, probeCreated = 0, probeGeometry = 0
        SCNTransaction.lock()
        let probeLocked = probeStart > 0 ? CACurrentMediaTime() : 0
        defer {
            SCNTransaction.unlock()
            if probeStart > 0 {
                TemporaryTopDownLatencyProbe.record("sync", ["waitMs": (probeLocked - probeStart) * 1000,
                    "lockedMs": (CACurrentMediaTime() - probeLocked) * 1000,
                    "visited": probeVisited, "created": probeCreated, "geometryCopies": probeGeometry])
            }
        }
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        defer { SCNTransaction.commit() }
        // Retain source keys'''
s = replace(s, anchor, new)
s = replace(s, '            let id = source\n            seen.insert(id)', '            if probeStart > 0 { probeVisited += 1 }\n            let id = source\n            seen.insert(id)')
s = replace(s, '                // Never invoke subclass clone/copy initializers', '                if probeStart > 0 { probeCreated += 1 }\n                // Never invoke subclass clone/copy initializers')
s = replace(s, '                if priorGeometry !== source.geometry {', '                if priorGeometry !== source.geometry {\n                    if probeStart > 0 { probeGeometry += 1 }')
scene.write_text(s)

rig = root / 'QiuJi/Core/Scene/CameraRig.swift'
s = rig.read_text()
s = replace(s, '        temporaryTopDownActive = true', '        TemporaryTopDownLatencyProbe.begin()\n        temporaryTopDownActive = true')
rig.write_text(s)

tests = root / 'QiuJiUITests/DailyAdaptivePanelUITests.swift'
s = tests.read_text()
anchor = '    func testP01TemporaryTableProjection() throws {'
test = '''    func testTemporaryTopDownLatencyResearch() throws {
        let app = try launchP01(requiresLandscape: false, extraArgs: ["-topDown.latencyProbe"])
        defer { app.terminate() }
        p01More(app)
        app.buttons["freeplay.cameraMode"].tap()
        waitValue(app.buttons["freeplay.cameraMode"], "3D")
        p01CloseMenu(app)
        sleep(3)
        let peek = app.buttons["shotCamera.temporaryTopDown"]
        for cycle in 0..<5 {
            peek.tap()
            sleep(2)
            XCTAssertEqual(peek.value as? String, "已选中")
            if cycle == 2 {
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "temporary-latency-visible"
                shot.lifetime = .keepAlways
                add(shot)
            }
            if cycle >= 3 {
                let scene = try p01Scene(app)
                let balls = try XCTUnwrap(scene["balls"] as? [[String: Any]])
                let cue = try XCTUnwrap(balls.first { $0["key"] as? String == "cueBall" })
                let point = try XCTUnwrap(cue["screen"] as? [Double])
                let table = element(app, "table.scene")
                let start = table.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point[0], dy: point[1]))
                start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 100, dy: 0)), withVelocity: XCUIGestureVelocity(rawValue: 80), thenHoldForDuration: 0.1)
                sleep(2)
            }
            peek.tap()
            sleep(1)
            XCTAssertEqual(peek.value as? String, "未选中")
        }
    }

'''
s = replace(s, anchor, test + anchor)
tests.write_text(s)
