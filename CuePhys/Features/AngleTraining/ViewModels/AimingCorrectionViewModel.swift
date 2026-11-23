import Foundation
import SwiftUI

/// 「瞄准修正」交互页 VM（v12 Z1–Z3）：控件 → 去抖 → `AimingCorrectionMath`。
///
/// 性能契约：滑杆/档位变更 → `SolveDebounceScheduler` ~20ms 去抖 + 单飞 + 末班车
/// （对齐 `SeparationAngleAtlasViewModel` / `PositionPlayViewModel` 离散态范式）。
/// Z3：共享控件 = 力度 + 高低杆三档 + 左右塞轴（打滑极限圆盘钳制）。
@MainActor
final class AimingCorrectionViewModel: ObservableObject {

    @Published var velocity: Double = ShotTuning.defaultVelocity
    @Published private(set) var spinX: Double = 0
    @Published var spinYTier: AimingCorrectionMath.SpinYTier = .mid

    @Published private(set) var snapshot: AimingCorrectionMath.Snapshot?
    @Published private(set) var throwSample: AimingCorrectionMath.ThrowDiagramSample?
    @Published private(set) var thicknessTriple: AimingCorrectionMath.ThicknessTriple?
    @Published private(set) var solveComparison: AimingCorrectionMath.SolveComparison?
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

    /// 当前 spinY 下左右塞可调上限（打滑极限圆盘弦长）。
    var spinXMaxAbs: Double {
        let lim = Double(CuePhysics.miscueLimitFraction)
        let sy = abs(spinY)
        let rem = lim * lim - sy * sy
        return rem > 0 ? sqrt(rem) : 0
    }

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
        spinX = Double(AimingCorrectionMath.clampSpinX(Float(spinX), spinY: Float(spinYTier.spinY)))
        scheduleRecompute(interactive: true)
    }

    func setSpinX(_ x: Double) {
        let clamped = Double(AimingCorrectionMath.clampSpinX(Float(x), spinY: Float(spinY)))
        guard abs(clamped - spinX) > 1e-6 else { return }
        spinX = clamped
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

        // 三联依赖力度 + spinX；任一变化才重算。
        let needTriple: Bool = {
            if let existing = thicknessTriple {
                return abs(existing.velocity - v) > 1e-4
                    || abs(existing.spinX - sx) > 1e-4
            }
            return true
        }()
        let needCompare = solveComparison == nil

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
            let cmp = needCompare
                ? AimingCorrectionMath.solveComparison(setup: setup)
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
                if let cmp { self.solveComparison = cmp }
                self.statusText = snap == nil ? "当前参数下几何不可行" : nil
                self.isComputing = false
                if self.predictRerunWanted {
                    self.runCompute()
                }
            }
        }
    }
}
