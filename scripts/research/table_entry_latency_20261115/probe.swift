
// Diagnostic source only: appended to an isolated build by instrument.py.
import ObjectiveC

final class TableEntryProbe: @unchecked Sendable {
    static let shared = TableEntryProbe()
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("-entry.probe") }
    private let lock = NSLock()
    private var events: [[String: Any]] = []
    private var entry = ""
    private var route = ""
    private var started = 0.0
    private var sceneID: ObjectIdentifier?
    private var rendererID: ObjectIdentifier?
    private var counts: [String: Int] = [:]
    private var ready = false
    private var renderingReady = false
    private var hasContentFrame = false
    private var touchBegan = 0.0
    private var touchEnded = 0.0
    private let session = UUID().uuidString
    private let writer = DispatchQueue(label: "qiuji.entry-probe.writer")
    private weak var vm: PositionPlayViewModel?
    private var installed = false
    private var previousControlState = ""

    @MainActor static func install() {
        guard enabled, !shared.installed else { return }
        shared.installed = true
        let a = class_getInstanceMethod(UIApplication.self, #selector(UIApplication.sendEvent(_:)))!
        let b = class_getInstanceMethod(UIApplication.self, #selector(UIApplication.entryProbeSendEvent(_:)))!
        method_exchangeImplementations(a, b)
    }
    static func touch(_ event: UIEvent) {
        guard enabled, let touches = event.allTouches else { return }
        let p = shared; p.lock.lock(); defer { p.lock.unlock() }
        if touches.contains(where: { $0.phase == .began }) { p.touchBegan = event.timestamp }
        if touches.contains(where: { $0.phase == .ended }) { p.touchEnded = event.timestamp }
    }
    @MainActor static func begin(_ route: String) {
        guard enabled else { return }
        flush()
        let p = shared; p.lock.lock()
        p.entry = UUID().uuidString; p.route = route; p.started = CACurrentMediaTime()
        p.events = []; p.counts = [:]; p.sceneID = nil; p.rendererID = nil
        p.ready = false; p.renderingReady = false; p.hasContentFrame = false; p.vm = nil
        p.previousControlState = ""
        let info: [String: Any] = ["wallUnix": Date().timeIntervalSince1970,
            "touchDownToActionMS": (p.started-p.touchBegan)*1000,
            "touchUpToActionMS": (p.started-p.touchEnded)*1000,
            "thermal": ProcessInfo.processInfo.thermalState.rawValue,
            "arguments": ProcessInfo.processInfo.arguments]
        let id = p.entry; p.lock.unlock()
        event("action", info)
        for delay in [3.0, 8.0] {
            DispatchQueue.main.asyncAfter(deadline: .now()+delay) {
                guard shared.entry == id else { return }; flush()
            }
        }
    }
    static func bind(_ scene: AngleTrainingScene) {
        guard enabled else { return }
        shared.lock.lock(); shared.sceneID = ObjectIdentifier(scene); shared.lock.unlock()
    }
    @MainActor static func pageReady(_ vm: PositionPlayViewModel) {
        guard enabled else { return }
        shared.lock.lock(); shared.vm = vm; shared.ready = true; shared.lock.unlock()
        event("pageSetupDone", ["computing": vm.isComputing, "feasible": vm.isFeasible,
              "camera": String(describing: vm.scene.currentCameraMode), "vmTiming": vm.entryTiming,
              "sceneTiming": vm.scene.setupTiming, "cloth": vm.scene.safeClothSupportState.variant,
              "staticField": vm.scene.staticClothIrradiance != nil, "ltc": vm.scene.clothLTCState])
    }
    static func event(_ name: String, _ fields: [String: Any] = [:], limit: Int = 80) {
        guard enabled else { return }
        let p = shared; let now = CACurrentMediaTime(); p.lock.lock(); defer { p.lock.unlock() }
        guard p.started > 0, now-p.started < 15, p.counts[name, default: 0] < limit else { return }
        p.counts[name, default: 0] += 1
        var row = fields; row["event"] = name; row["ms"] = (now-p.started)*1000
        row["uptime"] = now; row["main"] = Thread.isMainThread
        p.events.append(row)
    }
    static func measure<T>(_ name: String, _ body: () throws -> T) rethrows -> T {
        guard enabled else { return try body() }
        let start = CACurrentMediaTime(); event(name+".start")
        defer { event(name+".end", ["durationMS": (CACurrentMediaTime()-start)*1000]) }
        return try body()
    }
    static func frame(_ renderer: SCNSceneRenderer, _ scene: SCNScene, will: Bool) {
        guard enabled else { return }
        let p = shared; p.lock.lock()
        guard p.sceneID == ObjectIdentifier(scene) else { p.lock.unlock(); return }
        let id = ObjectIdentifier(renderer as AnyObject)
        if p.rendererID == nil { p.rendererID = id }
        guard p.rendererID == id else { p.lock.unlock(); return }
        if will { p.renderingReady = p.ready }
        let content = p.renderingReady
        if !will && content { p.hasContentFrame = true }
        p.lock.unlock()
        event(will ? "willRender" : "didRender", ["contentReady": content], limit: 24)
    }
    @MainActor static func display(_ view: SCNView?, _ scene: AngleTrainingScene) {
        guard enabled else { return }
        let p = shared; p.lock.lock()
        let valid = p.sceneID == ObjectIdentifier(scene) && p.hasContentFrame
        let vm = p.vm; p.lock.unlock()
        guard valid, let vm, let view, view.window != nil else { return }
        event("displayLinkAfterContent", ["size": [view.bounds.width, view.bounds.height]], limit: 1)
        let controlState = "\(vm.shotControlsBusy)-\(vm.cameraTransitionBusy)-\(vm.isPlaying)"
        if controlState != p.previousControlState {
            p.previousControlState = controlState
            event("controlState", ["shotBusy": vm.shotControlsBusy, "cameraBusy": vm.cameraTransitionBusy,
                  "playing": vm.isPlaying, "rigTransitioning": scene.cameraRig?.isTransitioning ?? false])
        }
        if !vm.shotControlsBusy && !vm.cameraTransitionBusy && !vm.isPlaying {
            event("controlsReady", ["feasible": vm.isFeasible, "aim": vm.currentPlayerAim != nil,
                  "vmTiming": vm.entryTiming, "camera": String(describing: scene.currentCameraMode)], limit: 1)
        }
    }
    static func flush() {
        guard enabled else { return }
        let p = shared; p.lock.lock()
        guard !p.entry.isEmpty else { p.lock.unlock(); return }
        let id = p.entry
        let data: [String: Any] = ["session": p.session, "entry": id, "route": p.route,
            "pid": ProcessInfo.processInfo.processIdentifier, "events": p.events]
        p.lock.unlock()
        p.writer.async {
            do {
                let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("TableEntryLatency").appendingPathComponent(p.session)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let bytes = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
                try bytes.write(to: dir.appendingPathComponent(id+".json"), options: .atomic)
            } catch { print("[TableEntryProbe] write failed: \(error)") }
        }
    }
}

extension UIApplication {
    @objc fileprivate func entryProbeSendEvent(_ event: UIEvent) {
        TableEntryProbe.touch(event)
        entryProbeSendEvent(event)
    }
}
