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
            contact.surface != .liner || linerByBall[contact.ball] == nil || linerByBall[contact.ball] == index
        }.map { _, contact in
            Cue(time: contact.time, kind: ShotSoundKind(surface: contact.surface), speed: contact.approachSpeed)
        }
        // Preserve order for simultaneous contacts after the pocket recording selection.
        return cues.enumerated().filter { $0.element.kind.outputGainScale > 0 && $0.element.time.isFinite && $0.element.time >= 0 && $0.element.speed.isFinite && $0.element.speed > 0 }
            .sorted { $0.element.time == $1.element.time ? $0.offset < $1.offset : $0.element.time < $1.element.time }.map(\.element)
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
