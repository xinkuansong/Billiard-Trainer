import Foundation

/// One-shot acknowledgment of a frame that began after a table mutation.
/// A render already in flight cannot consume a newly armed receipt.
final class TableFrameReceipt {
    private let lock = NSLock()
    private var revision = UUID()
    private var rendering: UUID?
    private var callback: (@MainActor () -> Void)?
    func arm(_ action: @escaping @MainActor () -> Void) {
        lock.lock(); defer { lock.unlock() }
        revision = UUID(); callback = action
    }
    func cancel() {
        lock.lock(); defer { lock.unlock() }
        revision = UUID(); callback = nil
    }
    func willRender() {
        lock.lock(); defer { lock.unlock() }
        rendering = revision
    }
    func didRender() {
        lock.lock()
        let action = rendering == revision ? callback : nil
        if action != nil { callback = nil }
        lock.unlock()
        if let action { Task { @MainActor in action() } }
    }
}

#if DEBUG
import SceneKit

/// Opt-in measurement of renderer acknowledgments, separate from the production
/// first-frame receipt. Timestamps are captured on the producing thread, not
/// when an asynchronous UI observer happens to receive them.
final class TableInteractionTimingProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var previewID: UUID?
    private var preview: [String: Double] = [:]
    private var armed: UUID?
    private var rendering: UUID?
    private var stroke: (start: Double, cached: Bool, position: SIMD3<Float>)?
    private var results: [[String: Double]] = []
    static var now: Double { ProcessInfo.processInfo.systemUptime }

    func beginPreview(id: UUID, start: Double, balls: Int) {
        lock.lock(); defer { lock.unlock() }
        previewID=id; armed=nil
        preview=["start":start,"balls":Double(balls)]
    }
    func mark(_ name: String, id: UUID) {
        let time=Self.now
        lock.lock(); defer { lock.unlock() }
        guard id==previewID else { return }
        preview[name]=time
    }
    func routesReady(id: UUID) {
        let time=Self.now
        lock.lock(); defer { lock.unlock() }
        guard id==previewID else { return }
        preview["routesReady"]=time; armed=id
    }
    func beginStroke(cached: Bool, node: SCNNode?) {
        let time=Self.now
        guard let node else { return }
        SCNTransaction.lock()
        let position=node.presentation.simdWorldPosition
        SCNTransaction.unlock()
        lock.lock(); defer { lock.unlock() }
        stroke=(time,cached,position)
    }
    func willRender() {
        lock.lock(); defer { lock.unlock() }
        rendering=armed
    }
    func didRender(cue: SCNNode?) {
        let time=Self.now
        lock.lock()
        let observesStroke=stroke != nil
        lock.unlock()
        var position: SIMD3<Float>?
        if observesStroke,let cue {
            SCNTransaction.lock();position=cue.presentation.simdWorldPosition;SCNTransaction.unlock()
        }
        lock.lock(); defer { lock.unlock() }
        if let armed,rendering==armed,armed==previewID {
            preview["rendered"]=time
            results.append(preview)
            self.armed=nil; previewID=nil
        }
        if let stroke,let position,simd_distance(position,stroke.position)>0.000001 {
            results.append(["start":stroke.start,"strokeRendered":time,"cached":stroke.cached ? 1:0])
            self.stroke=nil
        }
        if results.count>200 { results.removeFirst(results.count-200) }
    }
    func cancelStroke() {
        lock.lock(); defer { lock.unlock() }; stroke=nil
    }
    var json: String {
        lock.lock();let snapshot=results;lock.unlock()
        do { return String(decoding:try JSONSerialization.data(withJSONObject:snapshot),as:UTF8.self) }
        catch { return "{\"error\":\"timing serialization failed\"}" }
    }
}
#endif
