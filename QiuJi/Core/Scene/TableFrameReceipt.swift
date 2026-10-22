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
