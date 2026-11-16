"""Add first-render boundary markers to an isolated probe, never the working App."""
from pathlib import Path
import subprocess,sys
root=Path(sys.argv[1]);here=Path(__file__).resolve().parent
subprocess.run([sys.executable,here/'instrument_device.py',root],check=True)
p=root/'QiuJi/Core/Scene/AngleSceneView.swift';s=p.read_text();prefix,mark,probe=s.partition('// Opt-in latency research.');assert mark
helper='''    private var markerFD: Int32 = -1
    private var markerSequence: UInt64 = 0
    private var markedFirstWill = false

    // Diagnostic side channel: two small pwrite calls per activation's first frame.
    // Host only starts stack sampling after a first render exceeds 100 ms.
    private func markBoundary(_ phase: UInt64) {
        lock.lock(); defer { lock.unlock() }
        if phase == 1 {
            guard !markedFirstWill else { return }
            markedFirstWill = true
        }
        if phase == 2 && frames != 1 { return }
        if markerFD < 0 {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("TopDownLatency", isDirectory: true)
                .appendingPathComponent(session, isDirectory: true)
            do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
            catch { NSLog("TopDown marker directory failed: %@", String(describing: error)); return }
            markerFD = directory.appendingPathComponent("render-state.bin").path.withCString {
                Darwin.open($0, O_CREAT | O_RDWR, mode_t(0o600))
            }
            guard markerFD >= 0 else { NSLog("TopDown marker open failed: %d", errno); return }
        }
        markerSequence += 1
        let row: [UInt64] = [markerSequence, UInt64(activation), phase,
            Date().timeIntervalSince1970.bitPattern, CACurrentMediaTime().bitPattern,
            UInt64(getpid()), markerSequence]
        let count = row.withUnsafeBytes { Darwin.pwrite(markerFD, $0.baseAddress!, $0.count, 0) }
        if count != 56 { NSLog("TopDown marker write failed: %d", errno) }
    }

'''
assert probe.count('    private var frames = 0')==1
probe=probe.replace('    private var frames = 0','    private var frames = 0\n'+helper)
probe=probe.replace('        p.frames = 0','        p.frames = 0\n        p.markedFirstWill = false')
probe=probe.replace('        Self.record("overlayWillRender")','''        Self.record("overlayWillRender")
        markBoundary(1)
        if activation == 1 && frames == 0 && ProcessInfo.processInfo.arguments.contains("-topDown.watchdogSmoke") {
            Thread.sleep(forTimeInterval: 0.6)
        }''')
probe=probe.replace('        Self.record("overlayDidRender", ["frame": number])','        Self.record("overlayDidRender", ["frame": number])\n        markBoundary(2)')
assert probe.count('markBoundary(1)')==1 and probe.count('markBoundary(2)')==1
p.write_text('import Darwin\n'+prefix+mark+probe)
