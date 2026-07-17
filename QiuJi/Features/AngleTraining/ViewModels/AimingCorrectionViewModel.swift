import Foundation
import SwiftUI

/// 「瞄准修正」交互页 VM（v12 Z1）：控件 → 去抖 → `AimingCorrectionMath.compute`。
///
/// 性能契约：滑杆变更 → `SolveDebounceScheduler` ~20ms 去抖 + 单飞 + 末班车
/// （对齐 `SeparationAngleAtlasViewModel` / `PositionPlayViewModel` 离散态范式）。
@MainActor
final class AimingCorrectionViewModel: ObservableObject {

    @Published var velocity: Double = ShotTuning.defaultVelocity
    @Published var spinX: Double = 0
    @Published var spinY: Double = 0

    @Published private(set) var snapshot: AimingCorrectionMath.Snapshot?
    @Published private(set) var isComputing = false
    @Published private(set) var statusText: String?

    private let solveScheduler = SolveDebounceScheduler(
        idleInterval: SolveDebounceScheduler.defaultFastInterval,
        fastInterval: SolveDebounceScheduler.defaultFastInterval
    )
    private let predictQueue = DispatchQueue(
        label: "qiuji.aimingCorrection.predict",
        qos: .userInitiated
    )
    private var predictInFlight = false
    private var predictRerunWanted = false
    private var predictGeneration = 0

    let setup = AimingCorrectionMath.teachingSetup()

    func onAppear() {
        scheduleRecompute(interactive: false)
    }

    func setVelocity(_ v: Double) {
        velocity = min(max(v, ShotTuning.velocityRange.lowerBound),
                       ShotTuning.velocityRange.upperBound)
        scheduleRecompute(interactive: true)
    }

    func setSpinX(_ x: Double) {
        let lim = Double(CuePhysics.miscueLimitFraction)
        spinX = min(max(x, -lim), lim)
        scheduleRecompute(interactive: true)
    }

    func setSpinY(_ y: Double) {
        let lim = Double(CuePhysics.miscueLimitFraction)
        spinY = min(max(y, -lim), lim)
        scheduleRecompute(interactive: true)
    }

    func scheduleRecompute(interactive: Bool) {
        solveScheduler.schedule(interactive: interactive) { [weak self] in
            self?.runCompute()
        }
    }

    private func runCompute() {
        if predictInFlight {
            predictRerunWanted = true
            return
        }
        predictInFlight = true
        predictRerunWanted = false
        isComputing = true
        predictGeneration += 1
        let gen = predictGeneration
        let v = Float(velocity)
        let sx = Float(spinX)
        let sy = Float(spinY)
        let setup = self.setup

        predictQueue.async { [weak self] in
            let snap = AimingCorrectionMath.compute(
                velocity: v, spinX: sx, spinY: sy, setup: setup
            )
            DispatchQueue.main.async {
                guard let self else { return }
                self.predictInFlight = false
                guard gen == self.predictGeneration else {
                    if self.predictRerunWanted { self.runCompute() }
                    return
                }
                self.snapshot = snap
                self.statusText = snap == nil ? "当前参数下几何不可行" : nil
                self.isComputing = false
                if self.predictRerunWanted {
                    self.runCompute()
                }
            }
        }
    }
}
