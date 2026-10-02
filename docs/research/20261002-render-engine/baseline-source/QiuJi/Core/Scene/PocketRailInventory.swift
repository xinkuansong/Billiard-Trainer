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

/// Value-only presentation state. Keys identify physical board balls, never per-shot aliases.
struct PocketRailSnapshot: Equatable {
    struct Ball: Equatable {
        var key: String
        var pocketID: String
        var slot: Int
        var position: SIMD3<Double>
        var orientation: SIMD4<Float>
    }
    var balls: [Ball] = []
    var chains: [String: [SIMD3<Double>]] = [:]
    var occupancy: [String: Int] { Dictionary(grouping: balls, by: \.pocketID).mapValues(\.count) }
}

/// Immutable, seekable shot presentation. Copies tails so another playback cannot relayout
/// this shot underneath it. Both live SceneKit and offline export sample this same timeline.
struct PocketRailTimeline {
    struct Frame {
        let pocketID: String
        let slot: Int
        let position: SIMD3<Double>
        let opacity: Double
        let rotation: simd_quatf
    }
    struct Track {
        let pocketID: String
        var slot: Int
        var samples: [LocalPocketSimulation.State]
        var fadeStart: Double?

        private var rotations: [simd_quatf] = []

        init(pocketID: String, slot: Int, samples: [LocalPocketSimulation.State], fadeStart: Double? = nil) {
            self.pocketID = pocketID; self.slot = slot; self.samples = samples; self.fadeStart = fadeStart
        }

        func prepared() -> Track {
            var result = self
            result.rotations = [BallSpinIntegrator.identityOrientation]
            for (a, b) in zip(samples, samples.dropFirst()) {
                result.rotations.append(simd_normalize(Self.delta(a.omega, b.omega, b.time - a.time) * result.rotations.last!))
            }
            return result
        }

        private static func delta(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ dt: Double) -> simd_quatf {
            let mean = (a + b) * 0.5
            return BallSpinIntegrator.delta(angularVelocity: SCNVector3(Float(mean.x), Float(mean.y), Float(mean.z)), dt: Float(dt))
        }

        func frame(at time: Double) -> Frame? {
            guard let first = samples.first, time >= first.time else { return nil }
            var lo = 0, hi = samples.count
            while lo < hi {
                let mid = (lo + hi) / 2
                if samples[mid].time <= time { lo = mid + 1 } else { hi = mid }
            }
            let index = max(0, lo - 1)
            let state = samples[index]
            var position = state.position
            var rotation = rotations[index]
            if index + 1 < samples.count {
                let next = samples[index + 1]
                let u = (time - state.time) / (next.time - state.time)
                let omega = state.omega + (next.omega - state.omega) * u
                position += (next.position - state.position) * u
                rotation = simd_normalize(Self.delta(state.omega, omega, time - state.time) * rotation)
            }
            let opacity = fadeStart.map { max(0, min(1, 1 - (time - $0) / TrajectoryPlayback.pocketFadeDuration)) } ?? 1
            return Frame(pocketID: pocketID, slot: slot, position: position, opacity: opacity, rotation: rotation)
        }

    }
    let before: PocketRailSnapshot
    let previous: [String: Track]
    let incoming: [String: Track]
    let chains: [String: [SIMD3<Double>]]
    let duration: Double

    init(before: PocketRailSnapshot, recorder: TrajectoryRecorder) {
        self.before = before
        PocketNetPresentation.attach(to: recorder, preOccupied: before.occupancy)
        let pockets = PocketNetPresentation.netPockets(in: recorder)
        var chains = before.chains
        for (id, pocket) in pockets { chains[id] = pocket.slots(ballRadius: Double(BallPhysics.radius)) }
        self.chains = chains
        var previous: [String: Track] = [:]
        for ball in before.balls {
            previous[ball.key] = Track(pocketID: ball.pocketID, slot: ball.slot,
                samples: [.init(time: 0, position: ball.position, velocity: .zero, omega: .zero)])
        }
        // nil represents a newcomer; its motion is already in the recorder's shared tail.
        var queues: [String: [String?]] = [:]
        for ball in before.balls.sorted(by: { $0.slot < $1.slot }) {
            queues[ball.pocketID, default: []].append(ball.key)
        }
        var incoming: [String: Track] = [:]
        for entry in recorder.pocketEntries.sorted(by: {
            $0.time == $1.time ? $0.ball.name < $1.ball.name : $0.time < $1.time
        }) {
            guard let tail = recorder.collectionTailsByBallName[entry.ball.name], let samples = tail.samples,
                  let pocket = pockets[entry.pocketID], let slots = chains[entry.pocketID] else { continue }
            var queue = queues[entry.pocketID] ?? []
            if queue.count >= slots.count {
                if let key = queue.removeFirst() { previous[key]?.fadeStart = Double(entry.time) }
                for key in queue.compactMap({ $0 }) {
                    guard var track = previous[key], var start = track.samples.last else { continue }
                    track.slot = max(0, track.slot - 1)
                    start.time = max(start.time, Double(entry.time))
                    if start.time > track.samples.last!.time { track.samples.append(start) }
                    track.samples.append(contentsOf: PocketNetPresentation.shift(from: start, to: slots[track.slot]).dropFirst())
                    previous[key] = track
                }
            }
            queue.append(nil)
            queues[entry.pocketID] = queue
            incoming[entry.ball.name] = Track(pocketID: entry.pocketID,
                slot: PocketNetPresentation.slotIndex(of: tail, in: pocket), samples: samples, fadeStart: tail.fadeStart)
        }
        self.previous = previous.mapValues { $0.prepared() }
        self.incoming = incoming.mapValues { $0.prepared() }
        self.duration = (Array(previous.values) + Array(incoming.values)).reduce(Double(recorder.duration)) {
            max($0, $1.samples.last?.time ?? 0, ($1.fadeStart ?? 0) + ($1.fadeStart == nil ? 0 : TrajectoryPlayback.pocketFadeDuration))
        }
    }
}

/// Shared by the main-thread page and SceneKit action callbacks on its rendering queue.
/// SceneKit transactions do not protect our Swift collections. Serialize inventory
/// operations with a recursive lock, including nested calls from page boundaries.
final class PocketRailInventory {
    private let stateLock = NSRecursiveLock()
    final class Shot {
        let id = UUID()
        let timeline: PocketRailTimeline
        var aliases: [String: String] = [:]
        var bases: [String: simd_quatf] = [:]
        init(timeline: PocketRailTimeline) { self.timeline = timeline }
    }
    private final class WeakNode {
        weak var value: SCNNode?
        init(_ value: SCNNode) { self.value = value }
    }
    private var sources: [String: WeakNode] = [:]
    private var ownedClones: [String: SCNNode] = [:]
    private var departingClones: [SCNNode] = []
    private var activeID: UUID?
    private var activeShot: Shot?
    /// Offline consumers reconcile explicitly at board boundaries, never on wall time.
    private var shouldWatchBoard = true
    var watchesBoard: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return shouldWatchBoard }
        set { stateLock.lock(); defer { stateLock.unlock() }; shouldWatchBoard = newValue }
    }

    var visiblePositions: [String: SCNVector3] {
        stateLock.lock(); defer { stateLock.unlock() }
        return ownedClones.reduce(into: [:]) { result, entry in
            if entry.value.parent != nil && !entry.value.isHidden && entry.value.opacity > 0 { result[entry.key] = entry.value.worldPosition }
        }
    }

    func renderedNode(for source: SCNNode) -> SCNNode {
        stateLock.lock(); defer { stateLock.unlock() }
        if source.isHidden, let key = source.name, let clone = ownedClones[key] { return clone }
        return source
    }

    func snapshot() -> PocketRailSnapshot {
        stateLock.lock(); defer { stateLock.unlock() }
        if let activeShot { return activeShot.timeline.before }
        // A shot boundary uses settled slots even if a returned ball's UI shift is in flight.
        reconcile(animated: false)
        for resident in storedResidents.values.joined() {
            if let slots = chains[resident.pocketID], slots.indices.contains(resident.slot) {
                resident.clone.removeAction(forKey: "railShift")
                let p = slots[resident.slot]
                resident.clone.position = SCNVector3(Float(p.x), Float(p.y), Float(p.z))
            }
        }
        return PocketRailSnapshot(balls: storedResidents.values.flatMap { $0 }.map {
            .init(key: $0.source?.name ?? $0.ballName, pocketID: $0.pocketID, slot: $0.slot,
                  position: SIMD3(Double($0.clone.position.x), Double($0.clone.position.y), Double($0.clone.position.z)),
                  orientation: $0.clone.simdOrientation.vector)
        }.sorted { $0.pocketID == $1.pocketID ? $0.slot < $1.slot : $0.pocketID < $1.pocketID }, chains: chains)
    }

    func restore(_ snapshot: PocketRailSnapshot) {
        stateLock.lock(); defer { stateLock.unlock() }
        clear()
        chains = snapshot.chains
        for ball in snapshot.balls.sorted(by: { $0.slot < $1.slot }) {
            guard let source = sources[ball.key]?.value ?? root?.childNode(withName: ball.key, recursively: true) else { continue }
            let clone = makeClone(of: source, at: SCNVector3(Float(ball.position.x), Float(ball.position.y), Float(ball.position.z)))
            clone.isHidden = false
            clone.simdOrientation = simd_quatf(vector: ball.orientation)
            commit(clone, source: source, ballName: ball.key, pocketID: ball.pocketID, slot: ball.slot,
                   slots: snapshot.chains[ball.pocketID] ?? [])
        }
    }

    /// Called at a completed shot boundary before the page removes ball actions.
    /// Equal-duration SceneKit actions do not guarantee their completion callback order.
    func finishPlayback() {
        stateLock.lock(); defer { stateLock.unlock() }
        guard let shot = activeShot else { return }
        render(shot, at: shot.timeline.duration, complete: true)
    }

    func cancelPlayback() {
        stateLock.lock(); defer { stateLock.unlock() }
        guard let shot = activeShot else { return }
        restore(shot.timeline.before)
    }

    func beginShot(recorder: TrajectoryRecorder) -> Shot? {
        stateLock.lock(); defer { stateLock.unlock() }
        cancelPlayback()
        let shot = Shot(timeline: PocketRailTimeline(before: snapshot(), recorder: recorder))
        guard !shot.timeline.incoming.isEmpty else { return nil }
        activeID = shot.id
        activeShot = shot
        return shot
    }

    /// Keep the generation check and source-node update atomic with cancellation.
    func withActiveShot(_ shot: Shot, _ update: () -> Void) {
        stateLock.lock(); defer { stateLock.unlock() }
        guard activeID == shot.id else { return }
        update()
    }

    func isActive(_ shot: Shot) -> Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return activeID == shot.id
    }

    func bind(_ source: SCNNode, alias: String, to shot: Shot) {
        stateLock.lock(); defer { stateLock.unlock() }
        guard isActive(shot), shot.aliases[alias] == nil, let key = source.name else { return }
        shot.aliases[alias] = key
        _ = makeClone(of: source, at: source.position)
    }

    /// Capture the table orientation exactly at the pocket-entry boundary, once.
    func beginTail(alias: String, source: SCNNode, shot: Shot) {
        stateLock.lock(); defer { stateLock.unlock() }
        guard isActive(shot), let key = shot.aliases[alias], shot.bases[key] == nil else { return }
        shot.bases[key] = source.simdOrientation
    }

    /// Seeking is absolute; it never advances a timer or reads presentation nodes as input.
    func render(_ shot: Shot, at time: Double, complete: Bool = false) {
        stateLock.lock(); defer { stateLock.unlock() }
        guard isActive(shot) else { return }
        var frames: [String: (PocketRailTimeline.Frame, simd_quatf)] = [:]
        for ball in shot.timeline.before.balls {
            if let frame = shot.timeline.previous[ball.key]?.frame(at: time) {
                frames[ball.key] = (frame, simd_quatf(vector: ball.orientation))
            }
        }
        for (alias, key) in shot.aliases {
            if let frame = shot.timeline.incoming[alias]?.frame(at: time), let base = shot.bases[key] {
                frames[key] = (frame, base)
            }
        }
        for (key, clone) in ownedClones {
            guard let (frame, base) = frames[key] else { clone.isHidden = true; continue }
            clone.isHidden = frame.opacity <= 0
            clone.opacity = CGFloat(frame.opacity)
            clone.position = SCNVector3(Float(frame.position.x), Float(frame.position.y), Float(frame.position.z))
            clone.simdOrientation = simd_normalize(frame.rotation * base)
        }
        guard complete else { return }
        storedResidents.removeAll()
        chains = shot.timeline.chains
        for (key, value) in frames.sorted(by: { $0.value.0.slot < $1.value.0.slot }) where value.0.opacity > 0 {
            guard let clone = ownedClones[key], let source = sources[key]?.value else { continue }
            storedResidents[value.0.pocketID, default: []].append(Resident(clone: clone, source: source,
                ballName: key, pocketID: value.0.pocketID, slot: value.0.slot))
        }
        let keep = Set(storedResidents.values.flatMap { $0 }.compactMap { $0.source?.name })
        for key in Array(ownedClones.keys) where !keep.contains(key) {
            ownedClones.removeValue(forKey: key)?.removeFromParentNode()
        }
        activeID = nil
        activeShot = nil
        startWatching()
    }
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
    private var storedResidents: [String: [Resident]] = [:]
    var residents: [String: [Resident]] {
        stateLock.lock(); defer { stateLock.unlock() }
        return storedResidents
    }
    /// Rail slot chain per pocket (lowest slot first), remembered from the last commit.
    private var chains: [String: [SIMD3<Double>]] = [:]
    /// Real-time durations used when a resident leaves and the others roll forward.
    var fadeDuration: TimeInterval = 0.25
    var shiftDuration: TimeInterval = 0.35

    init(root: SCNNode) { self.root = root }

    /// Balls resting on each rail right now (after releasing any whose board ball is back on the table).
    var occupancyByPocket: [String: Int] {
        stateLock.lock(); defer { stateLock.unlock() }
        reconcile()
        return storedResidents.mapValues(\.count)
    }

    func occupancy(of pocketID: String) -> Int { occupancyByPocket[pocketID] ?? 0 }

    /// Clone of a board ball about to ride a net tail. Hidden until the playback reaches the
    /// tail; any earlier clone of the same board ball leaves first (a ball exists once).
    func makeClone(of source: SCNNode, at position: SCNVector3) -> SCNNode {
        stateLock.lock(); defer { stateLock.unlock() }
        if let old = resident(of: source) { release(old, animated: false) }
        let clone = source.clone()
        clone.name = (source.name ?? "ball") + "#rail"
        clone.removeAllActions()
        clone.isHidden = true
        clone.opacity = 1
        clone.position = position
        root?.addChildNode(clone)
        if let key = source.name {
            sources[key] = WeakNode(source)
            ownedClones.removeValue(forKey: key)?.removeFromParentNode()
            ownedClones[key] = clone
        }
        return clone
    }

    /// Register a clone as the newest resident of `pocketID` at `slot` and start watching its
    /// board ball: as soon as that ball is visible on the table again the clone leaves.
    func commit(_ clone: SCNNode, source: SCNNode, ballName: String, pocketID: String, slot: Int, slots: [SIMD3<Double>]) {
        stateLock.lock(); defer { stateLock.unlock() }
        chains[pocketID] = slots
        let resident = Resident(clone: clone, source: source, ballName: ballName, pocketID: pocketID, slot: slot)
        storedResidents[pocketID, default: []].append(resident)
        startWatching()
    }

    /// Main-thread poll while anything rests on a rail. A SceneKit action would force the
    /// renderer to run every frame forever; a 10 Hz timer costs nothing and the fade it
    /// triggers wakes the renderer by itself.
    private var watchTimer: Timer?
    private func startWatching() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.startWatching() }
            return
        }
        stateLock.lock(); defer { stateLock.unlock() }
        guard watchesBoard, watchTimer == nil, !storedResidents.values.allSatisfy(\.isEmpty) else { return }
        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.stateLock.lock(); defer { self.stateLock.unlock() }
            self.reconcile()
            if self.storedResidents.values.allSatisfy(\.isEmpty) { self.watchTimer?.invalidate(); self.watchTimer = nil }
        }
    }

    deinit { watchTimer?.invalidate() }

    /// Drop a clone that faded out inside its own playback (recorder-side FIFO).
    func discard(_ clone: SCNNode) {
        stateLock.lock(); defer { stateLock.unlock() }
        ownedClones = ownedClones.filter { $0.value !== clone }
        for key in storedResidents.keys { storedResidents[key]?.removeAll { $0.clone === clone } }
        clone.removeAllActions()
        clone.removeFromParentNode()
    }

    /// FIFO eviction of the `count` oldest residents of `pocketID`, scheduled `delay` seconds of
    /// real time from now: they fade out and leave, everybody behind rolls `count` slots forward.
    func evict(pocketID: String, count: Int, slots: [SIMD3<Double>], delay: TimeInterval) {
        stateLock.lock(); defer { stateLock.unlock() }
        guard count > 0, let queue = storedResidents[pocketID], !queue.isEmpty else { return }
        chains[pocketID] = slots
        let leaving = Array(queue.prefix(count))
        storedResidents[pocketID] = Array(queue.dropFirst(count))
        for resident in leaving { leave(resident, delay: delay, animated: true) }
        rollForward(pocketID: pocketID, by: count, delay: delay)
    }

    /// Remove every clone (table rebuilt).
    func clear() {
        stateLock.lock(); defer { stateLock.unlock() }
        activeID = nil
        activeShot = nil
        watchTimer?.invalidate()
        watchTimer = nil
        for clone in ownedClones.values { clone.removeAllActions(); clone.removeFromParentNode() }
        ownedClones.removeAll()
        for clone in departingClones { clone.removeAllActions(); clone.removeFromParentNode() }
        departingClones.removeAll()
        for resident in storedResidents.values.joined() {
            resident.clone.removeAllActions()
            resident.clone.removeFromParentNode()
        }
        storedResidents.removeAll()
    }

    /// Release every resident whose board ball is back on the table (synchronous form of the watcher).
    func reconcile(animated: Bool? = nil) {
        stateLock.lock(); defer { stateLock.unlock() }
        guard activeID == nil else { return }
        for resident in Array(storedResidents.values.joined()) where Self.isOnTable(resident.source) {
            release(resident, animated: animated ?? watchesBoard)
        }
    }

    // MARK: - Internals

    private func resident(of source: SCNNode) -> Resident? {
        storedResidents.values.joined().first { $0.source === source }
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
        guard var queue = storedResidents[resident.pocketID], let index = queue.firstIndex(where: { $0 === resident }) else { return }
        queue.remove(at: index)
        storedResidents[resident.pocketID] = queue
        leave(resident, delay: 0, animated: animated)
        rollForward(pocketID: resident.pocketID, by: 1, delay: 0, from: index, animated: animated)
    }

    private func leave(_ resident: Resident, delay: TimeInterval, animated: Bool) {
        ownedClones = ownedClones.filter { $0.value !== resident.clone }
        if animated {
            departingClones.removeAll { $0.parent == nil }
            departingClones.append(resident.clone)
            resident.clone.runAction(.sequence([.wait(duration: delay), .fadeOut(duration: fadeDuration), .removeFromParentNode()]))
        } else {
            resident.clone.removeAllActions()
            resident.clone.removeFromParentNode()
        }
    }

    /// Residents from `from` onwards move `count` slots towards the end stop.
    private func rollForward(pocketID: String, by count: Int, delay: TimeInterval, from: Int = 0, animated: Bool = true) {
        guard let queue = storedResidents[pocketID], let slots = chains[pocketID] else { return }
        for resident in queue.dropFirst(from) {
            resident.slot = max(0, resident.slot - count)
            guard slots.indices.contains(resident.slot) else { continue }
            let target = slots[resident.slot]
            if !animated {
                resident.clone.removeAllActions()
                resident.clone.position = SCNVector3(Float(target.x), Float(target.y), Float(target.z))
                continue
            }
            let move = SCNAction.move(to: SCNVector3(Float(target.x), Float(target.y), Float(target.z)), duration: shiftDuration)
            move.timingMode = .easeOut
            resident.clone.runAction(.sequence([.wait(duration: delay), move]), forKey: "railShift")
        }
    }
}
