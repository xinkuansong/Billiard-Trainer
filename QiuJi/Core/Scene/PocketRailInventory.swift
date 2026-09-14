//
//  PocketRailInventory.swift
//  QiuJi
//
//  W17-D (v63, DR-299): potted balls stay on the pocket return rails across shots.
//
//  There are only ever 16 balls. The table's ball nodes belong to the board (every page's
//  finish handler hides, resets or re-racks them), so a potted ball is shown on the rail
//  by a visual CLONE owned by this inventory, tied to the board node it came from.
//  Rules:
//    • a clone appears when its ball is potted and stays there — the rail is the ball store;
//    • the moment that board ball is back on the table (visible again), its clone leaves and
//      every ball behind it rolls one slot forward (1,2,3,4 − 2 → 1,3,4);
//    • if a chain is physically full (`NetPocket.slots`), the oldest resident is recycled
//      FIFO when a new ball starts falling (safety net, the chain is ~3 balls long);
//    • a table rebuild clears everything.
//  Presentation only: never feeds back into physics, rules or scoring.
//
//  Coordinate contract: clones live in the scene root, positions are SceneKit world
//  metres (the same frame as `PocketCollectionTail` samples).
//

import Foundation
import SceneKit

/// Main-thread only (SceneKit node graph); not actor-isolated so `TrajectoryPlayback` can hold it.
final class PocketRailInventory {
    final class Resident {
        let clone: SCNNode
        weak var source: SCNNode?
        let ballName: String
        let pocketID: String
        /// Slot index on the rail chain (0 = against the end stop).
        var slot: Int
        init(clone: SCNNode, source: SCNNode, ballName: String, pocketID: String, slot: Int) {
            self.clone = clone; self.source = source; self.ballName = ballName; self.pocketID = pocketID; self.slot = slot
        }
    }

    private weak var root: SCNNode?
    /// Residents per pocket id, oldest first (slot order).
    private(set) var residents: [String: [Resident]] = [:]
    /// Rail slot chain per pocket (lowest slot first), remembered from the last commit.
    private var chains: [String: [SIMD3<Double>]] = [:]
    /// Real-time durations used when a resident leaves and the others roll forward.
    var fadeDuration: TimeInterval = 0.25
    var shiftDuration: TimeInterval = 0.35

    init(root: SCNNode) { self.root = root }

    /// Balls resting on each rail right now (after releasing any whose board ball is back on the table).
    var occupancyByPocket: [String: Int] {
        reconcile()
        return residents.mapValues(\.count)
    }

    func occupancy(of pocketID: String) -> Int { occupancyByPocket[pocketID] ?? 0 }

    /// Clone of a board ball about to ride a net tail. Hidden until the playback reaches the
    /// tail; any earlier clone of the same board ball leaves first (a ball exists once).
    func makeClone(of source: SCNNode, at position: SCNVector3) -> SCNNode {
        if let old = resident(of: source) { release(old, animated: false) }
        let clone = source.clone()
        clone.name = (source.name ?? "ball") + "#rail"
        clone.removeAllActions()
        clone.isHidden = true
        clone.opacity = 1
        clone.position = position
        root?.addChildNode(clone)
        return clone
    }

    /// Register a clone as the newest resident of `pocketID` at `slot` and start watching its
    /// board ball: as soon as that ball is visible on the table again the clone leaves.
    func commit(_ clone: SCNNode, source: SCNNode, ballName: String, pocketID: String, slot: Int, slots: [SIMD3<Double>]) {
        chains[pocketID] = slots
        let resident = Resident(clone: clone, source: source, ballName: ballName, pocketID: pocketID, slot: slot)
        residents[pocketID, default: []].append(resident)
        startWatching()
    }

    /// Main-thread poll while anything rests on a rail. A SceneKit action would force the
    /// renderer to run every frame forever; a 10 Hz timer costs nothing and the fade it
    /// triggers wakes the renderer by itself.
    private var watchTimer: Timer?
    private func startWatching() {
        guard watchTimer == nil else { return }
        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.reconcile()
            if self.residents.values.allSatisfy(\.isEmpty) { self.watchTimer?.invalidate(); self.watchTimer = nil }
        }
    }

    deinit { watchTimer?.invalidate() }

    /// Drop a clone that faded out inside its own playback (recorder-side FIFO).
    func discard(_ clone: SCNNode) {
        for key in residents.keys { residents[key]?.removeAll { $0.clone === clone } }
        clone.removeAllActions()
        clone.removeFromParentNode()
    }

    /// FIFO eviction of the `count` oldest residents of `pocketID`, scheduled `delay` seconds of
    /// real time from now: they fade out and leave, everybody behind rolls `count` slots forward.
    func evict(pocketID: String, count: Int, slots: [SIMD3<Double>], delay: TimeInterval) {
        guard count > 0, let queue = residents[pocketID], !queue.isEmpty else { return }
        chains[pocketID] = slots
        let leaving = Array(queue.prefix(count))
        residents[pocketID] = Array(queue.dropFirst(count))
        for resident in leaving { leave(resident, delay: delay, animated: true) }
        rollForward(pocketID: pocketID, by: count, delay: delay)
    }

    /// Remove every clone (table rebuilt).
    func clear() {
        for resident in residents.values.joined() {
            resident.clone.removeAllActions()
            resident.clone.removeFromParentNode()
        }
        residents.removeAll()
    }

    /// Release every resident whose board ball is back on the table (synchronous form of the watcher).
    func reconcile() {
        for resident in Array(residents.values.joined()) where Self.isOnTable(resident.source) {
            release(resident, animated: true)
        }
    }

    // MARK: - Internals

    private func resident(of source: SCNNode) -> Resident? {
        residents.values.joined().first { $0.source === source }
    }

    /// A board ball counts as "on the table" when it is attached, not hidden (itself or via an
    /// ancestor) and not faded out.
    static func isOnTable(_ node: SCNNode?) -> Bool {
        guard let node, node.parent != nil, node.opacity > 0.5 else { return false }
        var cursor: SCNNode? = node
        while let n = cursor { if n.isHidden { return false }; cursor = n.parent }
        return true
    }

    /// The ball is back on the table: its clone leaves and later residents roll one slot forward.
    private func release(_ resident: Resident, animated: Bool) {
        guard var queue = residents[resident.pocketID], let index = queue.firstIndex(where: { $0 === resident }) else { return }
        queue.remove(at: index)
        residents[resident.pocketID] = queue
        leave(resident, delay: 0, animated: animated)
        rollForward(pocketID: resident.pocketID, by: 1, delay: 0, from: index)
    }

    private func leave(_ resident: Resident, delay: TimeInterval, animated: Bool) {
        if animated {
            resident.clone.runAction(.sequence([.wait(duration: delay), .fadeOut(duration: fadeDuration), .removeFromParentNode()]))
        } else {
            resident.clone.removeAllActions()
            resident.clone.removeFromParentNode()
        }
    }

    /// Residents from `from` onwards move `count` slots towards the end stop.
    private func rollForward(pocketID: String, by count: Int, delay: TimeInterval, from: Int = 0) {
        guard let queue = residents[pocketID], let slots = chains[pocketID] else { return }
        for resident in queue.dropFirst(from) {
            resident.slot = max(0, resident.slot - count)
            guard slots.indices.contains(resident.slot) else { continue }
            let target = slots[resident.slot]
            let move = SCNAction.move(to: SCNVector3(Float(target.x), Float(target.y), Float(target.z)), duration: shiftDuration)
            move.timingMode = .easeOut
            resident.clone.runAction(.sequence([.wait(duration: delay), move]), forKey: "railShift")
        }
    }
}
