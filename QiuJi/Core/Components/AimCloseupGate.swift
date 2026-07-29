import Foundation

/// Visibility gate for the aim closeup loupe (问题集合 v23 / A3：近区 ∧ 正在改瞄准）。
///
/// Owns the two pieces of state every host page needs and nothing else:
/// - the latest **near-band** snapshot (geometry side, from `AimCloseupBuilder`)
/// - whether the user is currently changing the aim (gesture side)
///
/// The HUD shows only when both hold. Aim changes are sticky for
/// `stickyWindow` so a table drag / wheel release does not strobe the loupe.
/// Hosts forward `onSnapshotChange` into their own `@Published` property
/// (nested `ObservableObject` would not republish).
@MainActor
final class AimCloseupGate {

    /// Aim-change stickiness; matches `AimPointSceneQuizViewModel` 的 280 ms 手感。
    static let stickyWindow: TimeInterval = 0.28

    /// Emitted whenever the effective (gated) snapshot changes.
    var onSnapshotChange: ((AimCloseupSnapshot?) -> Void)?

    /// Feed back into `AimCloseupBuilder` as `previouslyNear` (enter 3R / exit 3.5R).
    private(set) var isNear = false

    private var pending: AimCloseupSnapshot?
    private var aiming = false
    private var clearTask: Task<Void, Never>?
    private var published: AimCloseupSnapshot?

    /// Geometry side: latest near-band evaluation for this frame.
    func update(_ result: AimCloseupBuilder.Result) {
        isNear = result.isNear
        pending = result.snapshot
        emit()
    }

    /// Gesture side: the user just changed the aim (wheel drag / table drag / tap).
    func noteAimChanged() {
        aiming = true
        emit()
        scheduleClear()
    }

    /// Wheel drag lifecycle when the host has it: `false` collapses immediately
    /// after the sticky window rather than waiting for the next aim change.
    func setDragging(_ active: Bool) {
        if active {
            clearTask?.cancel()
            aiming = true
            emit()
        } else {
            scheduleClear()
        }
    }

    /// Leaving free aim / playing / result state: hide and forget.
    func reset() {
        clearTask?.cancel()
        clearTask = nil
        aiming = false
        isNear = false
        pending = nil
        emit()
    }

    private func scheduleClear() {
        clearTask?.cancel()
        clearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.stickyWindow * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.aiming = false
            self?.emit()
        }
    }

    private func emit() {
        let next = aiming ? pending : nil
        guard next != published else { return }
        published = next
        onSnapshotChange?(next)
    }
}
