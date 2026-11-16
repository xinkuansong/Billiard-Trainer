"""Exercise the real page's open action while asynchronous prepare is in flight.

This is an isolated adversarial timing case, not a human touch latency benchmark.
"""
from pathlib import Path
import sys
root=Path(sys.argv[1]).resolve();assert 'topdown-candidate-' in str(root)
def edit(rel,old,new,count=1):
    p=root/rel;s=p.read_text();assert s.count(old)==count,(rel,old,s.count(old));p.write_text(s.replace(old,new))
v='QiuJi/Core/Scene/AngleSceneView.swift'
edit(v,'    var onTemporaryTopDownDismiss: (() -> Void)? = nil',
     '    var onTemporaryTopDownDismiss: (() -> Void)? = nil\n    var onCandidateOpen: (() -> Void)? = nil')
edit(v,'        var onTemporaryTopDownDismiss: (() -> Void)?',
     '        var onTemporaryTopDownDismiss: (() -> Void)?\n        var onCandidateOpen: (() -> Void)?')
edit(v,'        context.coordinator.onTemporaryTopDownDismiss = onTemporaryTopDownDismiss',
     '        context.coordinator.onTemporaryTopDownDismiss = onTemporaryTopDownDismiss\n        context.coordinator.onCandidateOpen = onCandidateOpen',2)
edit(v,'''                    TopDownCandidateMetrics.shared.event("prepareComplete", ["success": success])
                }
            }
            candidateWarmup''','''                    TopDownCandidateMetrics.shared.event("prepareComplete", ["success": success])
                }
                if ProcessInfo.processInfo.arguments.contains("-topDown.openDuringPrepare") {
                    TopDownCandidateMetrics.shared.event("forcedEarlyOpen")
                    self.onCandidateOpen?()
                }
            }
            candidateWarmup''')
edit('QiuJi/Features/PositionPlay/Views/FreePlayView.swift',
     '            onTemporaryTopDownDismiss: { vm.endTemporaryTopDown() },',
     '            onTemporaryTopDownDismiss: { vm.endTemporaryTopDown() },\n            onCandidateOpen: { [weak vm] in vm?.beginTemporaryTopDown() },')
test='''    func testCandidateOpenDuringPrepare() throws {
        for arm in 0..<3 {
            let app = try launchP01(requiresLandscape: true,
                extraArgs: ["-topDown.latencyProbe", "-topDown.direct3D", "-topDown.candidate=prepare",
                    "-topDown.candidateCold", "-topDown.openDuringPrepare"], normalizeView: false)
            let peek = app.buttons["shotCamera.temporaryTopDown"]
            XCTAssertEqual(peek.value as? String, "已选中")
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = "candidate-early-visible-\\(arm)"; shot.lifetime = .keepAlways; add(shot)
            peek.tap(); sleep(2)
            let raw = try XCTUnwrap(element(app, "topDown.candidateMetrics").value as? String)
            let data = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            let rows = try XCTUnwrap(data["rows"] as? [[String: Any]])
            let opens = rows.filter { $0["event"] as? String == "activation" }
            XCTAssertEqual(opens.count, 1)
            XCTAssertNotNil(opens.first?["firstDidMs"])
            XCTAssertTrue(rows.contains { $0["event"] as? String == "forcedEarlyOpen" })
            let metrics = XCTAttachment(data: Data(raw.utf8), uniformTypeIdentifier: "public.json")
            metrics.name = "candidate-early-\\(arm)"; metrics.lifetime = .keepAlways; add(metrics)
            app.terminate()
        }
    }

'''
edit('QiuJiUITests/DailyAdaptivePanelUITests.swift','    func testCandidateImmediateFirstOpen() throws {',test+'    func testCandidateImmediateFirstOpen() throws {')
