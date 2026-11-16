
// Diagnostic-copy only. Weak references and counters never own a page or scene.
enum TableLifeProbe {
    static let enabled = ProcessInfo.processInfo.arguments.contains("-tableLife.probe")
    final class Entry {
        weak var object: AnyObject?
        let id = UUID().uuidString
        let kind: String
        var owner: String
        let sceneID: String
        var frames = 0
        var ticks = 0
        var state = "created"
        init(_ object: AnyObject, kind: String, owner: String, sceneID: String) {
            self.object = object; self.kind = kind; self.owner = owner; self.sceneID = sceneID
        }
    }
    private static let lock = NSLock()
    private static var entries: [Entry] = []
    private static var jobs: [String: String] = [:]
    private static var completedJobs = 0
    private static var events: [[String: Any]] = []
    static func track(_ object: AnyObject, kind: String, owner: String = "auxiliary", scene: AngleTrainingScene? = nil) {
        guard enabled else { return }
        lock.lock(); defer { lock.unlock() }
        if let found = entries.first(where: { $0.object === object }) {
            if owner != "auxiliary" { found.owner = owner }
            return
        }
        entries.append(Entry(object, kind: kind, owner: owner,
            sceneID: scene.map { String(describing: ObjectIdentifier($0)) } ?? ""))
    }
    static func bind(_ object: AnyObject, owner: String, scene: AngleTrainingScene) {
        track(object, kind: "vm", owner: owner, scene: scene)
        track(scene, kind: "scene", owner: owner, scene: scene)
    }
    static func event(_ object: AnyObject, _ state: String) {
        guard enabled else { return }
        lock.lock(); defer { lock.unlock() }
        if let entry = entries.first(where: { $0.object === object }) {
            entry.state = state
            events.append(["id": entry.id, "owner": entry.owner, "state": state, "time": CACurrentMediaTime()])
        }
    }
    static func frame(_ object: AnyObject, tick: Bool = false) {
        guard enabled else { return }
        lock.lock(); defer { lock.unlock() }
        if let entry = entries.first(where: { $0.object === object }) {
            if tick { entry.ticks += 1 } else { entry.frames += 1 }
        }
    }
    static func beginJob(_ name: String) -> String {
        guard enabled else { return "" }
        lock.lock(); defer { lock.unlock() }
        let id = UUID().uuidString; jobs[id] = name; return id
    }
    static func endJob(_ id: String) {
        guard enabled else { return }
        lock.lock(); defer { lock.unlock() }
        jobs.removeValue(forKey: id); completedJobs += 1
    }
    static func json() -> String {
        lock.lock(); defer { lock.unlock() }
        let rows: [[String: Any]] = entries.map {
            ["id": $0.id, "kind": $0.kind, "owner": $0.owner, "scene": $0.sceneID,
             "alive": $0.object != nil, "frames": $0.frames, "ticks": $0.ticks, "state": $0.state]
        }
        let value: [String: Any] = ["time": CACurrentMediaTime(), "pid": ProcessInfo.processInfo.processIdentifier,
                                  "objects": rows, "jobs": jobs, "completedJobs": completedJobs, "events": events]
        do { return String(decoding: try JSONSerialization.data(withJSONObject: value, options: .sortedKeys), as: UTF8.self) }
        catch { return "{\"error\":\"probe encoding failed\"}" }
    }
}

struct TableLifeProbePanel: View {
    var body: some View {
        if TableLifeProbe.enabled {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(" ").font(.system(size: 1)).frame(width: 2, height: 2)
                    .accessibilityElement().accessibilityLabel("球桌生命周期诊断")
                    .accessibilityIdentifier("tableLife.probe").accessibilityValue(TableLifeProbe.json())
                    .allowsHitTesting(false)
            }
        }
    }
}
