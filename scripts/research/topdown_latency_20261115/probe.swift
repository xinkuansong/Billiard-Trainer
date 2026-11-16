
// Opt-in latency research. Events stay in memory until the temporary view closes.
final class TemporaryTopDownLatencyProbe: NSObject, SCNSceneRendererDelegate {
    static let shared = TemporaryTopDownLatencyProbe()
    static let enabled: Bool = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-topDown.latencyProbe")
        #else
        false
        #endif
    }()
    private let lock = NSLock()
    private var events: [[String: Any]] = []
    private var activation = 0
    private var start = 0.0
    private var frames = 0

    static func begin() {
        guard enabled else { return }
        let p = shared
        p.lock.lock()
        p.activation += 1
        p.start = CACurrentMediaTime()
        p.frames = 0
        p.events = []
        p.lock.unlock()
        record("begin")
    }

    static func record(_ kind: String, _ values: [String: Any] = [:]) {
        guard enabled else { return }
        let p = shared
        let now = CACurrentMediaTime()
        p.lock.lock()
        defer { p.lock.unlock() }
        guard p.start > 0, p.events.count < 20000 else { return }
        var row = values
        row["event"] = kind
        row["ms"] = (now - p.start) * 1000
        row["activation"] = p.activation
        p.events.append(row)
    }

    static func finish() {
        guard enabled else { return }
        let p = shared
        record("close")
        p.lock.lock()
        guard p.start > 0 else { p.lock.unlock(); return }
        let rows = p.events
        let index = p.activation
        p.start = 0
        p.events = []
        p.lock.unlock()
        do {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("TopDownLatency", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
            try data.write(to: directory.appendingPathComponent("activation-\(index).json"), options: .atomic)
        } catch {
            NSLog("TopDownLatency export failed: %@", String(describing: error))
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        Self.record("overlayWillRender")
    }

    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        lock.lock()
        frames += 1
        let number = frames
        lock.unlock()
        Self.record("overlayDidRender", ["frame": number])
    }
}
