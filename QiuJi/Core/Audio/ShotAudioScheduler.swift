//
//  ShotAudioScheduler.swift
//  QiuJi
//
//  将一次击球的物理事件流（`ShotPrediction.events` + `recorder`）按**真实时刻**
//  排程为音效。回放为原速（speed=1.0），故事件 `time`（模拟秒）即真实延迟秒，
//  无需倍速换算。
//
//  常规引擎在接触瞬间记录法向接近速度；袋内呈现记录自己的接触时刻。
//  音量曲线属于试听标定，不代表实测声压或撞击冲量。
//

import Foundation
import SceneKit

@MainActor
final class ShotAudioScheduler {
    static let shared = ShotAudioScheduler()

    private var generation = 0
    private var pendingItems: [DispatchWorkItem] = []

    private init() {}

    // MARK: - Public

    /// 起播一次击球的音效流。应在球开始运动（出杆动画结束、`runAction` 时刻）调用。
    /// 会先取消上一杆的残留排程。
    struct Cue: Equatable {
        let time: Float
        let kind: ShotSoundKind
        let speed: Float
    }

    func play(prediction: ShotPrediction) {
        guard let recorder = prediction.recorder else { cancel(); return }
        play(recorder: recorder, legacyEvents: prediction.events)
    }

    /// Both ordinary shots and breaks consume the same recorder after visual tails are attached.
    func play(recorder: TrajectoryRecorder, cueSpeed: Float? = nil, legacyEvents: [ShotEvent] = []) {
        cancel()
        guard UserPreferences.shared.soundEffectsEnabled else { return }
        let bank = ShotSoundBank.shared
        bank.prepare()
        for cue in Self.timeline(recorder: recorder, cueSpeed: cueSpeed, legacyEvents: legacyEvents) {
            schedule(kind: cue.kind, speed: cue.speed, delay: TimeInterval(cue.time), bank: bank)
        }
    }

    static func timeline(recorder: TrajectoryRecorder, cueSpeed: Float? = nil,
                         legacyEvents: [ShotEvent] = []) -> [Cue] {
        let initial = recorder.framesByBallName.values.compactMap { $0.first?.velocity.length() }.max() ?? 0
        var cues = [Cue(time: 0, kind: .cueStrike, speed: cueSpeed ?? recorder.cueStrikeSpeed ?? initial)]
        var contacts = recorder.hasContactSoundFacts ? recorder.contactSounds : []
        if !recorder.hasContactSoundFacts {
            // Historical / experimental recorders have no exact contact facts. Never invent a pot impact.
            for event in legacyEvents {
                switch event.kind {
                case let .ballBall(a,b):
                    let va = preEventVelocity(recorder.framesByBallName[a] ?? [], at: event.time)
                    let vb = preEventVelocity(recorder.framesByBallName[b] ?? [], at: event.time)
                    let pa = recorder.framesByBallName[a]?.first(where: { $0.time >= event.time })?.position
                    let pb = recorder.framesByBallName[b]?.first(where: { $0.time >= event.time })?.position
                    let n = pa.flatMap { p in pb.map { $0-p } }
                    cues.append(.init(time: event.time, kind: .ballHit, speed: normalSpeed(va-vb, normal: n)))
                case let .ballCushion(ball):
                    let v = preEventVelocity(recorder.framesByBallName[ball] ?? [], at: event.time)
                    cues.append(.init(time: event.time, kind: .cushion, speed: event.contactNormal.map { ContactSoundEvent.approach(v, normal: $0) } ?? v.length()))
                case .pocket: break
                }
            }
        }
        for ball in recorder.pocketContactSounds.keys.sorted() {
            contacts += recorder.pocketContactSounds[ball] ?? []
        }
        contacts = contacts.filter { $0.time.isFinite && $0.time >= 0 && $0.approachSpeed.isFinite && $0.approachSpeed > 0 }
        let rackTransfers = suppressedRackTransferIndices(contacts: contacts, recorder: recorder)
        // P03 is a complete pocket recording, not an isolated micro-contact.
        // Replay it only at the strongest liner contact in each captured ball's descent.
        // Keep jaw hits, separate balls and collected-ball contacts independent.
        var linerByBall: [String: Int] = [:]
        for (index, contact) in contacts.enumerated()
            where contact.surface == .liner && recorder.pocketContactSounds[contact.ball] != nil {
            if let previous = linerByBall[contact.ball], contacts[previous].approachSpeed >= contact.approachSpeed { continue }
            linerByBall[contact.ball] = index
        }
        cues += contacts.enumerated().filter { index, contact in
            !rackTransfers.contains(index) &&
                (contact.surface != .liner || linerByBall[contact.ball] == nil || linerByBall[contact.ball] == index)
        }.map { _, contact in
            Cue(time: contact.time, kind: ShotSoundKind(surface: contact.surface), speed: contact.approachSpeed)
        }
        // Preserve order for simultaneous contacts after the pocket recording selection.
        return cues.enumerated().filter { $0.element.kind.outputGainScale > 0 && $0.element.time.isFinite && $0.element.time >= 0 && $0.element.speed.isFinite && $0.element.speed > 0 }
            .sorted { $0.element.time == $1.element.time ? $0.offset < $1.offset : $0.element.time < $1.element.time }.map(\.element)
    }

    /// An audition policy, not a physical contact duration. The clock starts at the
    /// first cue/object impact and never extends as further contacts arrive.
    static let rackTransferMaximumDuration: Float = 0.020

    private struct BallPair: Hashable {
        let a: String
        let b: String
        init(_ a: String, _ b: String) {
            self.a = min(a, b)
            self.b = max(a, b)
        }
    }

    /// Fold the initial tightly packed contact network into the accepted first hit.
    /// Facts remain untouched. Missing initial geometry/legacy recorders fail open.
    /// Only original neighbor edges reached by this impact can be suppressed; a
    /// recorded separation permanently releases an edge, even inside the time cap.
    static func suppressedRackTransferIndices(contacts: [ContactSoundEvent],
                                             recorder: TrajectoryRecorder) -> Set<Int> {
        let ordered = contacts.indices.filter {
            contacts[$0].surface == .ball && contacts[$0].time.isFinite &&
                contacts[$0].time >= 0 && contacts[$0].approachSpeed.isFinite && contacts[$0].approachSpeed > 0
        }.sorted { contacts[$0].time == contacts[$1].time ? $0 < $1 : contacts[$0].time < contacts[$1].time }
        let cue = PositionPlayBall.cueKey
        guard let firstIndex = ordered.first else { return [] }
        let first = contacts[firstIndex]
        guard first.ball == cue || first.other == cue else { return [] }
        let head = first.ball == cue ? first.other : first.ball
        // SceneKit metres; packing gap + both balls' maximum seeded displacement.
        // The final micrometre is Float distance-comparison tolerance only.
        let neighborDistance = 2 * BallPhysics.radius + RackLayout.gap + 2 * RackLayout.jitterRadius + 0.000001
        let initial = recorder.framesByBallName.compactMapValues { frames -> BallFrame? in
            guard let frame = frames.first, frame.time == 0,
                  frame.state == .stationary, frame.velocity.length() == 0,
                  frame.position.length().isFinite else { return nil }
            return frame
        }.filter { $0.key != cue }
        guard initial[head] != nil else { return [] }
        let names = initial.keys.sorted()
        var neighbors: [String: Set<String>] = [:]
        var edges = Set<BallPair>()
        for (i, a) in names.enumerated() {
            for b in names.dropFirst(i + 1) {
                guard let pa = initial[a]?.position, let pb = initial[b]?.position,
                      (pa - pb).length() <= neighborDistance else { continue }
                neighbors[a, default: []].insert(b)
                neighbors[b, default: []].insert(a)
                edges.insert(BallPair(a, b))
            }
        }
        var component: Set<String> = [head]
        var queue = [head]
        while let ball = queue.popLast() {
            for neighbor in neighbors[ball] ?? [] where component.insert(neighbor).inserted {
                queue.append(neighbor)
            }
        }
        // Leave isolated hits and two-object combination shots unchanged.
        guard component.count >= 3 else { return [] }
        edges = edges.filter { component.contains($0.a) && component.contains($0.b) }
        // The cue can also chatter against the head during initial impulse transfer.
        edges.insert(BallPair(cue, head))
        let end = first.time + rackTransferMaximumDuration
        var releasedAt: [BallPair: Float] = [:]
        for edge in edges {
            guard let a = recorder.framesByBallName[edge.a], let b = recorder.framesByBallName[edge.b] else {
                releasedAt[edge] = first.time
                continue
            }
            // The engine records all balls at each snapshot. Merge equal timestamps
            // rather than sampling the next (possibly post-collision) playback frame.
            var i = 0
            var j = 0
            while i < a.count && j < b.count {
                if a[i].time > end || b[j].time > end { break }
                if a[i].time < b[j].time { i += 1; continue }
                if b[j].time < a[i].time { j += 1; continue }
                if a[i].time >= first.time {
                    let distance = (a[i].position - b[j].position).length()
                    if !distance.isFinite || distance > neighborDistance {
                        releasedAt[edge] = a[i].time
                        break
                    }
                }
                i += 1
                j += 1
            }
        }
        var reached: Set<String> = [cue, head]
        var suppressed = Set<Int>()
        for index in ordered.dropFirst() {
            let contact = contacts[index]
            guard contact.time <= end else { break }
            let edge = BallPair(contact.ball, contact.other)
            guard edges.contains(edge), contact.time < (releasedAt[edge] ?? .infinity),
                  reached.contains(contact.ball) || reached.contains(contact.other) else { continue }
            suppressed.insert(index)
            reached.insert(contact.ball)
            reached.insert(contact.other)
        }
        return suppressed
    }

    /// 取消所有未触发的音效（回放被打断 / 复位时调用，避免「球已复位声音还在响」）。
    func cancel() {
        generation &+= 1
        pendingItems.forEach { $0.cancel() }
        pendingItems.removeAll()
        ShotSoundBank.shared.stopAll()
    }

    // MARK: - Scheduling

    private func schedule(kind: ShotSoundKind, speed: Float, delay: TimeInterval, bank: ShotSoundBank) {
        guard delay.isFinite, delay >= 0, speed.isFinite, speed > 0 else { return }
        if delay == 0 {
            bank.play(kind: kind, speed: speed)
            return
        }
        let token = generation
        let item = DispatchWorkItem { [weak self] in
            guard self?.generation == token else { return }
            bank.play(kind: kind, speed: speed)
        }
        pendingItems.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// 投影到真实接触法线；缺失或退化法线时保留旧速率估计。
    static func normalSpeed(_ velocity: SCNVector3, normal: SCNVector3?) -> Float {
        guard velocity.length().isFinite else { return 0 }
        guard let normal, normal.length().isFinite, normal.length() > 1e-6 else { return velocity.length() }
        return abs(velocity.dot(normal)) / normal.length()
    }

    /// 碰撞时刻的 recorder 通常已解算；必须取严格早于事件的最后一帧。
    /// t=0 时只可回退到初帧。相同时刻保持录制顺序。
    static func preEventVelocity(_ frames: [BallFrame], at time: Float) -> SCNVector3 {
        guard time.isFinite, let first = frames.first, first.time <= time else { return SCNVector3Zero }
        return frames.last(where: { $0.time < time })?.velocity ?? first.velocity
    }

}
