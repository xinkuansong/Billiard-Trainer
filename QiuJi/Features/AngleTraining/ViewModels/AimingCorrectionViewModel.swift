import Foundation
import SwiftUI

/// 「瞄准修正」交互页 VM（v12 Z1/Z2）：控件 → 去抖 → `AimingCorrectionMath`。
///
/// 性能契约：滑杆/档位变更 → `SolveDebounceScheduler` ~20ms 去抖 + 单飞 + 末班车
/// （对齐 `SeparationAngleAtlasViewModel` / `PositionPlayViewModel` 离散态范式）。
/// Z2：共享控件 = 力度滑杆 + 高低杆三档；左右塞轴留给 Z3（`spinX` 固定 0）。
@MainActor
final class AimingCorrectionViewModel: ObservableObject {

    @Published var velocity: Double = ShotTuning.defaultVelocity
    /// Z2 固定无左右塞；Z3 再开放控件轴。
    @Published private(set) var spinX: Double = 0
    @Published var spinYTier: AimingCorrectionMath.SpinYTier = .mid

    @Published private(set) var snapshot: AimingCorrectionMath.Snapshot?
    @Published private(set) var throwSample: AimingCorrectionMath.ThrowDiagramSample?
    @Published private(set) var thicknessTriple: AimingCorrectionMath.ThicknessTriple?
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

    var spinY: Double { Double(spinYTier.spinY) }

    func onAppear() {
        scheduleRecompute(interactive: false)
    }

    func setVelocity(_ v: Double) {
        velocity = min(max(v, ShotTuning.velocityRange.lowerBound),
                       ShotTuning.velocityRange.upperBound)
        scheduleRecompute(interactive: true)
    }

    func setSpinYTier(_ tier: AimingCorrectionMath.SpinYTier) {
        guard tier != spinYTier else { return }
        spinYTier = tier
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
        let sy = Float(spinYTier.spinY)
        let setup = self.setup

        // 三联只依赖力度（与当前高低杆档无关）——力度未变时复用，减轻滚动/切档时的解析负载。
        let needTriple: Bool = {
            if let existing = thicknessTriple {
                return abs(existing.velocity - v) > 1e-4
            }
            return true
        }()

        predictQueue.async { [weak self] in
            let snap = AimingCorrectionMath.compute(
                velocity: v, spinX: sx, spinY: sy, setup: setup
            )
            let throwS = AimingCorrectionMath.throwDiagramSample(
                velocity: v, spinX: sx, spinY: sy, setup: setup
            )
            let triple = needTriple
                ? AimingCorrectionMath.thicknessTriple(velocity: v, spinX: sx, setup: setup)
                : nil
            DispatchQueue.main.async {
                guard let self else { return }
                self.predictInFlight = false
                guard gen == self.predictGeneration else {
                    if self.predictRerunWanted { self.runCompute() }
                    return
                }
                self.snapshot = snap
                self.throwSample = throwS
                if let triple { self.thicknessTriple = triple }
                self.statusText = snap == nil ? "当前参数下几何不可行" : nil
                self.isComputing = false
                if self.predictRerunWanted {
                    self.runCompute()
                }
            }
        }
    }
}
