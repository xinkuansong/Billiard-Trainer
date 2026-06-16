//
//  ShotAudioScheduler.swift
//  QiuJi
//
//  将一次击球的物理事件流（`ShotPrediction.events` + `recorder`）按**真实时刻**
//  排程为音效。回放为原速（speed=1.0），故事件 `time`（模拟秒）即真实延迟秒，
//  无需倍速换算。
//
//  力度（决定音量/选样本）由事件时刻 recorder 中相关球的速度估算——这是
//  「听感响度」的近似，非物理精确撞击冲量；对音效足够（详见 ADR）。
//

import Foundation
import SceneKit

@MainActor
final class ShotAudioScheduler {
    static let shared = ShotAudioScheduler()

    /// 参考最大速度（≈ 接近开球级），用于把速度归一到 [0,1] 力度。
    private static let referenceSpeed: Float = 4.5

    private var pendingItems: [DispatchWorkItem] = []

    private init() {}

    // MARK: - Public

    /// 起播一次击球的音效流。应在球开始运动（出杆动画结束、`runAction` 时刻）调用。
    /// 会先取消上一杆的残留排程。
    func play(prediction: ShotPrediction) {
        cancel()
        guard UserPreferences.shared.soundEffectsEnabled else { return }
        guard let recorder = prediction.recorder else { return }

        let bank = ShotSoundBank.shared
        bank.prepare()

        // 击球音：t=0（此刻即杆-母球接触瞬间）。力度取全场首帧最大初速（被击球最快）。
        schedule(kind: .cueStrike,
                 intensity: normalize(launchSpeed(recorder)),
                 delay: 0, bank: bank)

        for event in prediction.events {
            let kind: ShotSoundKind
            let intensity: Float
            switch event.kind {
            case let .ballBall(ballA, ballB):
                kind = .ballHit
                intensity = normalize(relativeImpactSpeed(recorder, ballA, ballB, at: event.time))
            case let .ballCushion(ball):
                kind = .cushion
                intensity = normalize(speed(recorder, ball, at: event.time))
            case .pocket:
                kind = .pocket
                intensity = 0.7   // 落袋听感与速度相关弱，取中等固定值
            }
            schedule(kind: kind, intensity: intensity, delay: TimeInterval(event.time), bank: bank)
        }
    }

    /// 取消所有未触发的音效（回放被打断 / 复位时调用，避免「球已复位声音还在响」）。
    func cancel() {
        pendingItems.forEach { $0.cancel() }
        pendingItems.removeAll()
    }

    // MARK: - Scheduling

    private func schedule(kind: ShotSoundKind, intensity: Float, delay: TimeInterval, bank: ShotSoundBank) {
        if delay <= 0 {
            bank.play(kind: kind, intensity: intensity)
            return
        }
        let item = DispatchWorkItem { bank.play(kind: kind, intensity: intensity) }
        pendingItems.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    // MARK: - Intensity estimation

    private func normalize(_ speed: Float) -> Float {
        max(0, min(1, speed / Self.referenceSpeed))
    }

    /// 全场所有球首帧（t≈0）的最大初速 —— 被击母球最快，代表这一杆力度。
    private func launchSpeed(_ recorder: TrajectoryRecorder) -> Float {
        var maxSpeed: Float = 0
        for (_, frames) in recorder.framesByBallName {
            if let first = frames.min(by: { $0.time < $1.time }) {
                maxSpeed = max(maxSpeed, first.velocity.length())
            }
        }
        return maxSpeed
    }

    /// 某球在 `t` 时刻（取 ≤ t 的最近记录帧）的速度大小。
    private func speed(_ recorder: TrajectoryRecorder, _ name: String, at t: Float) -> Float {
        velocityBefore(recorder, name, at: t).length()
    }

    /// 球-球碰撞响度近似：两球进入碰撞前速度差的大小（沿连心线分量更精确，
    /// 但速度差大小已是足够的听感代理）。
    private func relativeImpactSpeed(_ recorder: TrajectoryRecorder, _ a: String, _ b: String, at t: Float) -> Float {
        let va = velocityBefore(recorder, a, at: t)
        let vb = velocityBefore(recorder, b, at: t)
        return (va - vb).length()
    }

    /// 取 `name` 球在 ≤ t 的最近记录帧速度（即「进入该事件前」的运动状态）。
    private func velocityBefore(_ recorder: TrajectoryRecorder, _ name: String, at t: Float) -> SCNVector3 {
        guard let frames = recorder.framesByBallName[name], !frames.isEmpty else { return SCNVector3Zero }
        let sorted = frames.sorted { $0.time < $1.time }
        var result = sorted[0].velocity
        for frame in sorted {
            if frame.time <= t + 1e-4 { result = frame.velocity } else { break }
        }
        return result
    }
}
