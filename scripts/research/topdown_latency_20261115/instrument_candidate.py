"""Apply only to a private baseline worktree; no production files are edited."""
from pathlib import Path
import subprocess, sys, xml.etree.ElementTree as ET
import shutil
assert shutil.disk_usage(Path(sys.argv[1])).free > 1024**3, "Insufficient space for candidate instrumentation"
root = Path(sys.argv[1]).resolve()
assert 'topdown-candidate-' in str(root)
here = Path(__file__).resolve().parent
subprocess.run([sys.executable, str(here/'instrument_device.py'), str(root)], check=True)
def edit(rel, old, new):
    p=root/rel; s=p.read_text(); assert s.count(old)==1,(rel,old,s.count(old));p.write_text(s.replace(old,new))
v='QiuJi/Core/Scene/AngleSceneView.swift'
edit(v,'        private var mergedOverlay: SCNView?', '''        var candidateWarmup: DispatchWorkItem?
        private var candidateWarmupScheduled = false
        private var mergedOverlay: SCNView?''')
edit(v,'coordinator.removeTemporaryTopDownOverlay()', '''coordinator.candidateWarmup?.cancel()
        TopDownCandidateMetrics.shared.uninstall()
        coordinator.removeTemporaryTopDownOverlay()''')
edit(v,'            self.scene = scene','            self.scene = scene\n            TopDownCandidateMetrics.shared.event("hostCreated")')
edit(v,'            mergedOverlay = overlay\n','            mergedOverlay = overlay\n            TopDownCandidateMetrics.shared.track(overlay)\n')
edit(v,'        func startRenderLoop() {','        func startRenderLoop() {\n            if let view = scnView { TopDownCandidateMetrics.shared.install(on: view) }')
edit(v,'let rebuild = mergedOverlay == nil || mergedOverlayActivation != rig.temporaryTopDownActivationCount', '''let activationChanged = mergedOverlayActivation != rig.temporaryTopDownActivationCount
            let rebuild = mergedOverlay == nil || (!TopDownCandidateMetrics.reuse && activationChanged)''')
edit(v,'let cameraChanged = rebuild || overlay.frame != stage','let cameraChanged = rebuild || activationChanged || overlay.frame != stage\n            mergedOverlayActivation = rig.temporaryTopDownActivationCount')
edit(v,'            TemporaryTopDownLatencyProbe.measure("backgroundColor")', '            if rebuild || !TopDownCandidateMetrics.reuse {\n            TemporaryTopDownLatencyProbe.measure("backgroundColor")')
edit(v,'            if cameraChanged {','            }\n            if cameraChanged {')
edit(v,'            if overlay.superview == nil { view.insertSubview(overlay, at: 0) }', '''            if rig.temporaryTopDownActive {
                TemporaryTopDownLatencyProbe.bind(overlay)
                if overlay.superview == nil { view.insertSubview(overlay, at: 0) }
                if TopDownCandidateMetrics.reuse && activationChanged { overlay.setNeedsDisplay() }
            }''')
edit(v,'            if let overlay = mergedOverlay {','            if let overlay = mergedOverlay, scene.cameraRig?.temporaryTopDownActive == true {')
edit(v,'''                removeTemporaryTopDownOverlay()
                return
            }
            guard view.window != nil''', '''                if TopDownCandidateMetrics.reuse, scene.cameraRig?.usesMergedCamera == true {
                    if mergedOverlay?.superview != nil {
                        TemporaryTopDownLatencyProbe.finish()
                        mergedOverlay?.removeFromSuperview()
                        mergedDiagramLabels?.hide()
                        mergedDragNode = nil
                    }
                    scheduleCandidateWarmup()
                } else { removeTemporaryTopDownOverlay() }
                return
            }
            guard view.window != nil''')
anchor='        private func updateMergedOverlay(view: SCNView, rig: CameraRig, frame: CameraRig.TemporaryTopDownFrame) {'
edit(v,anchor,'''        private func scheduleCandidateWarmup() {
            guard TopDownCandidateMetrics.mode == "prepare", !candidateWarmupScheduled,
                  cameraMode == .perspective3D, let view = scnView, view.window != nil else { return }
            candidateWarmupScheduled = true
            let task = DispatchWorkItem { [weak self] in
                guard let self, let view = self.scnView, view.window != nil,
                      let rig = self.scene.cameraRig, rig.usesMergedCamera,
                      !rig.temporaryTopDownActive, self.mergedOverlay == nil else { return }
                guard let camera = self.scene.cameraNode else { return }
                let pose = TwoViewCamera.Pose(eye: camera.simdPosition,
                    orientation: camera.simdOrientation,
                    fov: Float(camera.camera?.fieldOfView ?? 60))
                guard let frame = CameraRig.temporaryTopDownFrame(referencePose: pose,
                    viewport: view.bounds.size, insets: .zero,
                    halfLength: Float(rig.tableOuterHalfLength), halfWidth: Float(rig.tableOuterHalfWidth),
                    surfaceY: self.scene.surfaceY, previousUp: nil) else { return }
                TopDownCandidateMetrics.shared.event("prepareStart")
                self.updateMergedOverlay(view: view, rig: rig, frame: frame)
                guard let overlay = self.mergedOverlay, let scene = overlay.scene else { return }
                overlay.prepare([scene]) { success in
                    TopDownCandidateMetrics.shared.event("prepareComplete", ["success": success])
                }
            }
            candidateWarmup = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: task)
        }

'''+anchor)
edit(v,'        record("begin", ["wallUnix"', '        TopDownCandidateMetrics.shared.setPhase("visible")\n        record("begin", ["wallUnix"')
edit(v,'        let index = p.activation','''        let index = p.activation
        var summary: [String: Any] = ["activation": index,
            "builds": rows.filter { $0["event"] as? String == "buildTreeComplete" }.count]
        summary["firstDidMs"] = rows.first { $0["event"] as? String == "overlayDidRender" }?["ms"]
        summary["firstWillMs"] = rows.first { $0["event"] as? String == "overlayWillRender" }?["ms"]
        summary["syncMs"] = rows.filter { $0["event"] as? String == "sync" }.reduce(0.0) {
            $0 + ($1["lockedMs"] as? Double ?? 0) + ($1["waitMs"] as? Double ?? 0)
        }
        TopDownCandidateMetrics.shared.event("activation", summary)
        TopDownCandidateMetrics.shared.setPhase("hidden")''')
# Delegate records hidden work even when latency interval is inactive.
edit(v,'        (scene as? AngleTrainingScene)?.frameReceipt.didRender()', '        TopDownCandidateMetrics.shared.frame(overlay: false)\n        (scene as? AngleTrainingScene)?.frameReceipt.didRender()')
edit(v,'''        guard isCurrent(renderer) else { return }
        lock.lock()
        frames += 1''','''        TopDownCandidateMetrics.shared.frame(overlay: true)
        guard isCurrent(renderer) else { return }
        lock.lock()
        frames += 1''')
p=root/v;p.write_text(p.read_text()+(here/'candidate_metrics.swift').read_text())
edit('QiuJi/Data/Services/TablePreferencesStore.swift', '        return result\n    }\n\n    /// Explicit user action:', '''        if page == .composer && ProcessInfo.processInfo.arguments.contains("-topDown.direct3D") {
            result.values[.view3D] = 1
        }
        return result
    }

    /// Explicit user action:''')
edit('QiuJi/App/QiuJiApp.swift','    init() {', '''    init() {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-topDown.candidateCold") {
            let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("com.xinkuan.qiuji/com.apple.metal")
            do {
                if FileManager.default.fileExists(atPath: cache.path) { try FileManager.default.removeItem(at: cache) }
            } catch { fatalError("Research-only cache reset failed: \\(error)") }
        }
        #endif''')
test='QiuJiUITests/DailyAdaptivePanelUITests.swift'
edit(test,'let path = env["DAILY_ADAPTIVITY_DIR"] ?? env["TEST_RUNNER_DAILY_ADAPTIVITY_DIR"]', 'let path = env["DAILY_ADAPTIVITY_DIR"] ?? env["TEST_RUNNER_DAILY_ADAPTIVITY_DIR"] ?? (name.contains("Candidate") ? NSTemporaryDirectory() + "TopDownCandidate" : nil)')
edit(test,'    func testP01TemporaryTableProjection() throws {', (here/'candidate_ui_test.swift').read_text()+'\n    func testP01TemporaryTableProjection() throws {')
for scheme in (root/'QiuJi.xcodeproj').rglob('QiuJi.xcscheme'):
    tree=ET.parse(scheme)
    for parent in list(tree.iter('Testables'))+list(tree.iter('BuildActionEntries')):
        for child in list(parent):
            ref=child.find('BuildableReference')
            if ref is not None and ref.get('BlueprintName')=='QiuJiTests':parent.remove(child)
    tree.write(scheme,encoding='utf-8',xml_declaration=True)
