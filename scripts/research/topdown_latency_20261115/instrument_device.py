"""Extend the isolated simulator probe with per-stage device timings."""
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
here = Path(__file__).resolve().parent
subprocess.run([sys.executable, str(here/'instrument.py'), str(root)], check=True)

def edit(path, old, new):
    p = root/path
    s = p.read_text()
    prefix, marker, probe = s.partition('// Opt-in latency research.')
    if marker and old in probe:
        assert probe.count(old) == 1, (path, old, probe.count(old))
        p.write_text(prefix + marker + probe.replace(old, new))
    else:
        assert s.count(old) == 1, (path, old, s.count(old))
        p.write_text(s.replace(old, new))

view = 'QiuJi/Core/Scene/AngleSceneView.swift'
edit(view, '    private var start = 0.0\n    private var frames = 0', '''    private var start = 0.0
    private var frames = 0
    private var rendererIdentity: ObjectIdentifier?
    private let session = UUID().uuidString

    static func bind(_ renderer: SCNSceneRenderer) {
        shared.lock.lock()
        shared.rendererIdentity = ObjectIdentifier(renderer as AnyObject)
        shared.lock.unlock()
    }

    static func measure<T>(_ event: String, _ body: () -> T) -> T {
        guard enabled else { return body() }
        let start = CACurrentMediaTime()
        let result = body()
        record(event, ["durationMs": (CACurrentMediaTime() - start) * 1000])
        return result
    }

    private func isCurrent(_ renderer: SCNSceneRenderer) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return rendererIdentity == ObjectIdentifier(renderer as AnyObject) && start > 0
    }''')
edit(view, '        record("begin")', '        record("begin", ["wallUnix": Date().timeIntervalSince1970, "uptime": CACurrentMediaTime(), "arguments": ProcessInfo.processInfo.arguments])')
edit(view, '        p.frames = 0', '        p.frames = 0\n        p.rendererIdentity = nil')
edit(view, '.appendingPathComponent("TopDownLatency", isDirectory: true)', '.appendingPathComponent("TopDownLatency", isDirectory: true)\n                .appendingPathComponent(p.session, isDirectory: true)')
edit(view, '        Self.record("overlayWillRender")', '        guard isCurrent(renderer) else { return }\n        Self.record("overlayWillRender")')
edit(view, '        lock.lock()\n        frames += 1', '        guard isCurrent(renderer) else { return }\n        lock.lock()\n        frames += 1')
edit(view, 'if TemporaryTopDownLatencyProbe.enabled { overlay.delegate = TemporaryTopDownLatencyProbe.shared }', 'if TemporaryTopDownLatencyProbe.enabled { TemporaryTopDownLatencyProbe.bind(overlay); overlay.delegate = TemporaryTopDownLatencyProbe.shared }')
edit(view, 'let overlay = mergedOverlay ?? SCNView(frame: view.bounds, options: nil)', 'let overlay = mergedOverlay ?? TemporaryTopDownLatencyProbe.measure("createSCNView") { SCNView(frame: view.bounds, options: nil) }')
for statement, event in [
    ('overlay.backgroundColor = .clear', 'backgroundColor'),
    ('overlay.isPlaying = false', 'isPlaying'),
    ('overlay.rendersContinuously = false', 'rendersContinuously'),
    ('overlay.antialiasingMode = view.antialiasingMode', 'antialiasing'),
    ('overlay.autoenablesDefaultLighting = view.autoenablesDefaultLighting', 'autoLighting'),
]:
    edit(view, statement, f'TemporaryTopDownLatencyProbe.measure("{event}") {{ {statement} }}')
edit(view, 'TemporaryTopDownLatencyProbe.record("buildStart")', 'TemporaryTopDownLatencyProbe.record("buildStart", ["staticClothField": scene.staticClothIrradiance != nil, "clothRecipe": String(describing: scene.safeClothSupportState)])')
edit('QiuJi/Core/Scene/CameraRig.swift', 'TemporaryTopDownLatencyProbe.begin()', 'TemporaryTopDownLatencyProbe.record("rigActivated")')
edit('QiuJi/Features/PositionPlay/ViewModels/PositionPlayViewModel.swift', '    func beginTemporaryTopDown() {', '    func beginTemporaryTopDown() {\n        TemporaryTopDownLatencyProbe.begin()')
