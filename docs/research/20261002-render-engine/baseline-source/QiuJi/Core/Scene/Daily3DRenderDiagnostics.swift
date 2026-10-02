import Foundation
import Metal
import SceneKit
import os

/// Explicit, process-local instrumentation. No preferences, gameplay state or frame policy changes.
final class Daily3DRenderDiagnostics: @unchecked Sendable {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-daily3D.diagnostics")
    static let metalLabel = "QiuJi.DailyClearance3D.Scene"
    private static let log = OSLog(subsystem: "com.qiuji.daily3d", category: "render")

    enum Stage: Equatable { case idle, aim, orbit, breaking, shot }
    enum Source: String, Hashable {
        case lifecycle, tablePan, tablePinch, tableTap, aimWheel, power, spin
        case cameraButton, strike, replay, undo, displayLink, sceneRenderer
    }
    enum Name: String {
        case page = "daily3D.page", idle = "daily3D.idle", aim = "daily3D.aim"
        case orbit = "daily3D.orbit", breaking = "daily3D.break", shot = "daily3D.shot"
        case input = "daily3D.input", wake = "daily3D.wake", firstRender = "daily3D.firstRender"
        case configuration = "daily3D.configuration"

        var signpostName: StaticString {
            switch self {
            case .page: return "daily3D.page"
            case .idle: return "daily3D.idle"
            case .aim: return "daily3D.aim"
            case .orbit: return "daily3D.orbit"
            case .breaking: return "daily3D.break"
            case .shot: return "daily3D.shot"
            case .input: return "daily3D.input"
            case .wake: return "daily3D.wake"
            case .firstRender: return "daily3D.firstRender"
            case .configuration: return "daily3D.configuration"
            }
        }
    }
    struct Event {
        enum Kind { case begin, end, event }
        let kind: Kind
        let name: Name
        let id: OSSignpostID
        let pageID: UInt64
        var sequence: UInt64 = 0
        var source: Source = .lifecycle
        var wasIdle = false
        var configuration = ""
    }

    struct RenderConfiguration: Equatable {
        let selectedFPS: Int
        let scheduledFPS: Int
        let antialiasingSamples: Int
        let contentScale: Double
    }

    static func sampleCount(for mode: SCNAntialiasingMode) -> Int {
        switch mode {
        case .none: return 1
        case .multisampling2X: return 2
        case .multisampling4X: return 4
        @unknown default: return 0
        }
    }

    private let enabled: Bool
    private let eventSink: ((Event) -> Void)?
    private let launchFlags: String
    private let lock = NSLock()
    private var visible = false
    private var foreground = false
    private var perspective = false
    private var pageID: OSSignpostID?
    private var stage: (value: Stage, id: OSSignpostID)?
    private var playback: Stage?
    private var rendererActive: Bool?
    private var cameraMoving = false
    private var interactions: [Source: Stage] = [:]
    private var lastIntent: Stage?
    private var inputSequence: UInt64 = 0
    private var pendingWake: Event?
    private var pendingRender: Event?
    private var labelledQueue: MTLCommandQueue?
    private var originalQueueLabel: String?
    private var renderConfiguration: RenderConfiguration?

    init(enabled: Bool = Daily3DRenderDiagnostics.isEnabled, eventSink: ((Event) -> Void)? = nil) {
        self.enabled = enabled
        self.eventSink = eventSink
        let arguments = enabled ? ProcessInfo.processInfo.arguments : []
        #if DEBUG
        launchFlags = "cameraReference=\(arguments.contains("-daily3D.cameraReference")) mergeClothSupport=\(arguments.contains("-daily3D.mergeClothSupport")) factorClothBRDF=\(arguments.contains("-daily3D.factorClothBRDF"))"
        #else
        launchFlags = "cameraReference=false mergeClothSupport=false factorClothBRDF=false"
        #endif
    }

    func setPage(visible: Bool? = nil, foreground: Bool? = nil, perspective: Bool? = nil) {
        guard enabled else { return }
        lock.lock(); defer { lock.unlock() }
        if let visible { self.visible = visible }
        if let foreground { self.foreground = foreground }
        if let perspective { self.perspective = perspective }
        let eligible = self.visible && self.foreground && self.perspective
        if eligible, pageID == nil {
            let id = OSSignpostID(log: Self.log)
            pageID = id
            rendererActive = nil
            emit(Event(kind: .begin, name: .page, id: id, pageID: id.rawValue,
                       configuration: configurationDescription))
        } else if !eligible, let id = pageID {
            endStage()
            emit(Event(kind: .end, name: .page, id: id, pageID: id.rawValue))
            pageID = nil
            interactions.removeAll()
            lastIntent = nil
            cameraMoving = false
            rendererActive = nil
            pendingWake = nil
            pendingRender = nil
            restoreQueueLabel()
        }
        reconcileStage()
    }

    func setRenderConfiguration(_ configuration: RenderConfiguration) {
        guard enabled else { return }
        lock.lock(); defer { lock.unlock() }
        guard configuration != renderConfiguration else { return }
        renderConfiguration = configuration
        if let pageID {
            emit(Event(kind: .event, name: .configuration, id: OSSignpostID(log: Self.log),
                       pageID: pageID.rawValue, configuration: configurationDescription))
        }
    }

    func setPlayback(breaking: Bool, shooting: Bool) {
        guard enabled else { return }
        lock.lock(); defer { lock.unlock() }
        playback = breaking ? .breaking : (shooting ? .shot : nil)
        reconcileStage()
    }

    /// Called before existing input handlers. This does not wake or otherwise alter the renderer.
    func input(_ source: Source, intent: Stage? = nil) {
        guard enabled else { return }
        lock.lock(); defer { lock.unlock() }
        guard let pageID else { return }
        inputSequence += 1
        let event = Event(kind: .event, name: .input, id: OSSignpostID(log: Self.log),
                          pageID: pageID.rawValue, sequence: inputSequence,
                          source: source, wasIdle: rendererActive == false)
        emit(event)
        if pendingWake == nil { pendingWake = event }
        if pendingRender == nil { pendingRender = event }
        if let intent { lastIntent = intent }
    }

    func setInteraction(_ source: Source, stage: Stage, active: Bool) {
        guard enabled else { return }
        lock.lock(); defer { lock.unlock() }
        guard pageID != nil else { return }
        if active {
            interactions[source] = stage
            lastIntent = stage
        } else {
            interactions.removeValue(forKey: source)
        }
        reconcileStage()
    }

    /// Uses the production scheduler's actual decision; an idle interval is never inferred from FPS.
    func rendererState(active: Bool, cameraMoving: Bool) {
        guard enabled else { return }
        lock.lock(); defer { lock.unlock() }
        guard pageID != nil else { return }
        rendererActive = active
        self.cameraMoving = cameraMoving
        if !active { lastIntent = nil }
        reconcileStage()
    }

    /// A CADisplayLink callback is a wake marker, not a displayed/presented frame.
    func displayLinkCallback() {
        guard enabled else { return }
        lock.lock(); defer { lock.unlock() }
        guard let input = pendingWake, pageID != nil else { return }
        emit(Event(kind: .event, name: .wake, id: input.id, pageID: input.pageID,
                   sequence: input.sequence, source: .displayLink, wasIdle: input.wasIdle))
        pendingWake = nil
    }

    /// Called on SceneKit's render thread. Public Metal labels support trace attribution;
    /// whether they reach the trace and identify a present surface must be measured separately.
    func willRender(_ renderer: SCNSceneRenderer) {
        guard enabled else { return }
        lock.lock(); defer { lock.unlock() }
        guard pageID != nil else { return }
        if let queue = renderer.commandQueue {
            if labelledQueue !== queue {
                restoreQueueLabel()
                labelledQueue = queue
                originalQueueLabel = queue.label
            }
            if queue.label != Self.metalLabel { queue.label = Self.metalLabel }
        }
        renderer.currentRenderCommandEncoder?.label = Self.metalLabel
        if let input = pendingRender {
            emit(Event(kind: .event, name: .firstRender, id: input.id, pageID: input.pageID,
                       sequence: input.sequence, source: .sceneRenderer, wasIdle: input.wasIdle))
            pendingRender = nil
        }
    }

    private func reconcileStage() {
        guard pageID != nil else { return }
        let desired: Stage?
        if let playback { desired = playback }
        else if interactions.values.contains(.orbit) { desired = .orbit }
        else if interactions.values.contains(.aim) { desired = .aim }
        else if cameraMoving { desired = lastIntent == .aim ? .aim : .orbit }
        else if rendererActive == false { desired = .idle }
        else if rendererActive == true { desired = lastIntent }
        else { desired = nil }
        guard stage?.value != desired else { return }
        endStage()
        if let desired, let pageID {
            let id = OSSignpostID(log: Self.log)
            stage = (desired, id)
            emit(Event(kind: .begin, name: name(for: desired), id: id, pageID: pageID.rawValue))
        }
    }

    private func endStage() {
        guard let stage, let pageID else { return }
        emit(Event(kind: .end, name: name(for: stage.value), id: stage.id, pageID: pageID.rawValue))
        self.stage = nil
    }

    private func name(for stage: Stage) -> Name {
        switch stage {
        case .idle: return .idle
        case .aim: return .aim
        case .orbit: return .orbit
        case .breaking: return .breaking
        case .shot: return .shot
        }
    }

    private func restoreQueueLabel() {
        if labelledQueue?.label == Self.metalLabel { labelledQueue?.label = originalQueueLabel }
        labelledQueue = nil
        originalQueueLabel = nil
    }

    private var configurationDescription: String {
        guard let configuration = renderConfiguration else { return launchFlags }
        return "\(launchFlags) selectedFPS=\(configuration.selectedFPS) scheduledFPS=\(configuration.scheduledFPS) antialiasingSamples=\(configuration.antialiasingSamples) contentScale=\(configuration.contentScale)"
    }

    private func emit(_ event: Event) {
        if let eventSink { eventSink(event); return }
        let type: OSSignpostType
        switch event.kind {
        case .begin: type = .begin
        case .end: type = .end
        case .event: type = .event
        }
        os_signpost(type, log: Self.log, name: event.name.signpostName, signpostID: event.id,
                    "page=%{public}llu sequence=%{public}llu source=%{public}@ wasIdle=%{public}d configuration=%{public}@",
                    event.pageID, event.sequence, event.source.rawValue as NSString,
                    event.wasIdle ? 1 : 0, event.configuration as NSString)
    }
}

/// Normal launches retain FrameDelegate and do not install a willRenderScene callback.
final class Daily3DFrameDelegate: FrameDelegate {
    private let diagnosticsLock = NSLock()
    private var targetDiagnostics: Daily3DRenderDiagnostics?

    func setDiagnostics(_ diagnostics: Daily3DRenderDiagnostics?) {
        diagnosticsLock.lock(); defer { diagnosticsLock.unlock() }
        targetDiagnostics = diagnostics
    }

    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        diagnosticsLock.lock()
        let diagnostics = targetDiagnostics
        diagnosticsLock.unlock()
        diagnostics?.willRender(renderer)
    }
}
