import XCTest
@testable import QiuJi

final class AdaptiveShotDragTests: XCTestCase {
    func testMetalRollTicksBetweenHapticsWithoutQueueingOrIdleTicks() {
        var sound = ShotDragDetents(minimumInterval: ShotDragDetents.soundMinimumInterval)
        var haptic = ShotDragDetents()
        let moving = AdaptiveShotDrag.Sample(delta: 1, gain: 0.9)
        let stopped = AdaptiveShotDrag.Sample(delta: 0, gain: 0.9)
        for feedback in [true, false] {
            if feedback { _ = sound.intensity(position: 0, spacing: 0.5, sample: moving, time: 0) }
            else { _ = haptic.intensity(position: 0, spacing: 0.5, sample: moving, time: 0) }
        }
        XCTAssertNotNil(sound.intensity(position: 1, spacing: 0.5, sample: moving, time: 0.07))
        XCTAssertNotNil(haptic.intensity(position: 1, spacing: 0.5, sample: moving, time: 0.07))
        XCTAssertNotNil(sound.intensity(position: 2, spacing: 0.5, sample: moving, time: 0.14))
        XCTAssertNil(haptic.intensity(position: 2, spacing: 0.5, sample: moving, time: 0.14))
        XCTAssertNil(sound.intensity(position: 3, spacing: 0.5, sample: moving, time: 0.15))
        XCTAssertNil(sound.intensity(position: 3, spacing: 0.5, sample: stopped, time: 0.3))
        XCTAssertNil(sound.intensity(position: 3.1, spacing: 0.5, sample: moving, time: 0.4))
        XCTAssertNil(sound.intensity(position: 3.1, spacing: 0.05, sample: stopped, time: 0.5))
        XCTAssertNotNil(sound.intensity(position: 3.2, spacing: 0.05, sample: moving, time: 0.6))
    }

    private func travel(speed: Double, distance: Double = 60, hz: Double = 60) -> Double {
        var drag = AdaptiveShotDrag()
        _ = drag.update(translation: 0, time: 0)
        let count = Int((distance / speed * hz).rounded(.up))
        var result = 0.0
        for i in 1...count {
            let t = min(Double(i) / hz, distance / speed)
            result += drag.update(translation: speed * t, time: t).delta
        }
        return result
    }

    func testSameDistanceSlowTravelIsFineAndFastTravelRetainsCoarseRange() {
        XCTAssertEqual(travel(speed: 15), 6, accuracy: 0.001)
        XCTAssertGreaterThan(travel(speed: 300), 35)
        XCTAssertLessThanOrEqual(travel(speed: 300), 60)
        XCTAssertGreaterThan(travel(speed: 100), travel(speed: 15))
    }

    func testEventRateDoesNotChangeConstantSpeedTravel() {
        for speed in [15.0, 100, 300] {
            XCTAssertEqual(travel(speed: speed, hz: 30), travel(speed: speed, hz: 120), accuracy: 0.001)
        }
    }

    func testFastToSlowAndReverseNeverRecalculateEarlierTravel() {
        var drag = AdaptiveShotDrag()
        _ = drag.update(translation: 0, time: 0)
        for i in 1...30 { _ = drag.update(translation: Double(i) * 5, time: Double(i) / 60) }
        for i in 1...10 {
            let sample = drag.update(translation: 150 + Double(i) * 0.2, time: 0.5 + Double(i) / 60)
            XCTAssertGreaterThan(sample.delta, 0)
            XCTAssertLessThanOrEqual(sample.delta, 0.2 + 1e-10)
        }
        XCTAssertLessThan(drag.gain, 0.11)
        let reverse = drag.update(translation: 151.8, time: 0.5 + 11.0 / 60)
        XCTAssertLessThan(reverse.delta, 0)
        XCTAssertEqual(reverse.delta, -0.02, accuracy: 0.001)
    }

    func testPauseAndNewGestureStartFineWithoutJump() {
        var drag = AdaptiveShotDrag()
        _ = drag.update(translation: 0, time: 0)
        _ = drag.update(translation: 30, time: 0.1)
        let resume = drag.update(translation: 31, time: 0.5)
        XCTAssertEqual(resume.delta, 0.1, accuracy: 1e-10)
        XCTAssertEqual(drag.update(translation: 31, time: 0.6).delta, 0)
        drag = AdaptiveShotDrag()
        XCTAssertEqual(drag.update(translation: 0, time: 1).delta, 0)
        XCTAssertEqual(drag.update(translation: 0.2, time: 1.02).delta, 0.02, accuracy: 1e-10)
    }

    func testInvalidOrDuplicateTimestampsDoNotLoseMovement() {
        var drag = AdaptiveShotDrag()
        _ = drag.update(translation: 0, time: 1)
        XCTAssertEqual(drag.update(translation: 1, time: 1).delta, 0)
        XCTAssertEqual(drag.update(translation: .nan, time: 1.1).delta, 0)
        XCTAssertEqual(drag.update(translation: 1, time: 1.1).delta, 0.1, accuracy: 1e-10)
    }

    func testPowerAllowsSubTenthChangesAndTapKeepsExactValue() {
        let range = ShotTuning.velocityRange
        var power = PowerDragAdjustment(velocity: 1.537, range: range)
        XCTAssertEqual(power.move(delta: 0, height: 144, range: range).velocity, 1.537, accuracy: 1e-12)
        let next = power.move(delta: -0.2, height: 144, range: range).velocity
        XCTAssertGreaterThan(next, 1.537)
        XCTAssertLessThan(next - 1.537, 0.01)
    }

    func testPowerBoundsDiscardOvershootAndLatchFeedbackWithHysteresis() {
        for range in [ShotTuning.velocityRange, 2.0...12.0] {
            var power = PowerDragAdjustment(velocity: range.lowerBound, range: range)
            XCTAssertTrue(power.move(delta: -10000, height: 144, range: range).reachedBoundary)
            XCTAssertEqual(power.fraction, 1)
            XCTAssertFalse(power.move(delta: -100, height: 144, range: range).reachedBoundary)
            XCTAssertLessThan(power.move(delta: 0.1, height: 144, range: range).velocity, range.upperBound)
            XCTAssertFalse(power.move(delta: -0.1, height: 144, range: range).reachedBoundary)
            XCTAssertTrue(power.move(delta: 10000, height: 144, range: range).reachedBoundary)
            XCTAssertEqual(power.fraction, 0)
            XCTAssertFalse(power.move(delta: 10, height: 144, range: range).reachedBoundary)
            XCTAssertGreaterThan(power.move(delta: -1, height: 144, range: range).velocity, range.lowerBound)
            XCTAssertTrue(power.move(delta: -10000, height: 144, range: range).reachedBoundary)
        }
    }

    func testFineHapticsRemainLightAndRateLimited() {
        var detents = ShotDragDetents()
        let fine = AdaptiveShotDrag.Sample(delta: 0.001, gain: 0.1)
        let coarse = AdaptiveShotDrag.Sample(delta: 1, gain: 1)
        XCTAssertNil(detents.intensity(position: 1.50, spacing: 0.01, sample: fine, time: 0))
        let intensity = detents.intensity(position: 1.511, spacing: 0.01, sample: fine, time: 0.2)
        XCTAssertNotNil(intensity)
        XCTAssertGreaterThan(intensity ?? 0, 0)
        XCTAssertLessThan(intensity ?? 1, coarse.hapticIntensity)
        XCTAssertNil(detents.intensity(position: 1.51, spacing: 0.01, sample: fine, time: 0.4))
        XCTAssertNil(detents.intensity(position: 1.512, spacing: 0.01, sample: fine, time: 0.6))
        XCTAssertNotNil(detents.intensity(position: 1.522, spacing: 0.01, sample: fine, time: 0.8))
        XCTAssertNil(detents.intensity(position: 1.533, spacing: 0.01, sample: fine, time: 0.81))
        XCTAssertNil(detents.intensity(position: 1.534, spacing: 0.01, sample: fine, time: 1))
    }

    func testChangingScaleAndStoppingCannotProduceHaptics() {
        var detents = ShotDragDetents()
        let moving = AdaptiveShotDrag.Sample(delta: 0.001, gain: 0.1)
        let stationary = AdaptiveShotDrag.Sample(delta: 0, gain: 0.1)
        XCTAssertNil(detents.intensity(position: 1.5, spacing: 0.1, sample: moving, time: 0))
        XCTAssertNil(detents.intensity(position: 1.59, spacing: 0.1, sample: moving, time: 0.2))
        XCTAssertNil(detents.intensity(position: 1.591, spacing: 0.01, sample: moving, time: 0.4))
        XCTAssertNil(detents.intensity(position: 1.591, spacing: 0.01, sample: stationary, time: 0.6))
        XCTAssertNotNil(detents.intensity(position: 1.58, spacing: 0.01, sample: moving, time: 0.8))
    }

    func testPrecisionScaleRequiresDwellHoldsWhenStoppedAndHasHysteresis() {
        var scale = ShotPrecisionScale()
        let fine = AdaptiveShotDrag.Sample(delta: 0.01, gain: 0.1)
        let coarse = AdaptiveShotDrag.Sample(delta: 2, gain: 0.9)
        scale.update(sample: fine, time: 0)
        scale.update(sample: fine, time: 0.05)
        XCTAssertFalse(scale.isFine)
        scale.update(sample: coarse, time: 0.06)
        scale.update(sample: fine, time: 0.1)
        scale.update(sample: fine, time: 0.23)
        XCTAssertTrue(scale.isFine)
        scale.update(sample: .init(delta: 0.01, gain: 0.4), time: 0.5)
        scale.update(sample: .init(delta: 0, gain: 1), time: 10)
        XCTAssertTrue(scale.isFine)
        scale.resetTiming()
        scale.update(sample: coarse, time: 11)
        XCTAssertTrue(scale.isFine)
        scale.update(sample: coarse, time: 11.13)
        XCTAssertFalse(scale.isFine)
    }

    func testFineTicksFadeInOnlyWithLegibleSpacing() {
        XCTAssertEqual(ShotRulerTicks.opacity(spacing: 0.8), 0)
        XCTAssertEqual(ShotRulerTicks.opacity(spacing: 3), 0)
        XCTAssertGreaterThan(ShotRulerTicks.opacity(spacing: 5), 0)
        XCTAssertEqual(ShotRulerTicks.opacity(spacing: 8), 1)
    }

    @MainActor
    func testFreePlayAndBreakAcceptSubThresholdAimUpdates() throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.aimMode = .free
        vm.nudgeFreeAim(byDegrees: 1)
        let before = try XCTUnwrap(vm.freeAimDir)
        vm.nudgeFreeAim(byDegrees: 0.00005)
        let after = try XCTUnwrap(vm.freeAimDir)
        XCTAssertTrue(before.x != after.x || before.z != after.z)
        vm.nudgeFreeAim(byDegrees: .nan)
        XCTAssertEqual(vm.freeAimDir?.x, after.x)
        XCTAssertEqual(vm.freeAimDir?.z, after.z)

        let runner = BreakFlowRunner(scene: vm.scene, game: .chineseEightBall, seed: 7)
        runner.rackUp()
        runner.nudgeAim(byDegrees: 1)
        let breakBefore = try XCTUnwrap(runner.aimDir)
        runner.nudgeAim(byDegrees: 0.00005)
        let breakAfter = try XCTUnwrap(runner.aimDir)
        XCTAssertTrue(breakBefore.x != breakAfter.x || breakBefore.z != breakAfter.z)
    }

    @MainActor
    func testSolverFreeModesAcceptSubThresholdAimUpdates() throws {
        let bank = BankShotViewModel()
        bank.setupScene()
        bank.toggleMode()
        let bankBefore = try XCTUnwrap(bank.observationAim)
        bank.nudgeFreeAim(byDegrees: 0.00005)
        let bankAfter = try XCTUnwrap(bank.observationAim)
        XCTAssertTrue(bankBefore.x != bankAfter.x || bankBefore.z != bankAfter.z)

        let diamond = DiamondSystemViewModel()
        diamond.setupScene()
        diamond.toggleMode()
        let diamondBefore = try XCTUnwrap(diamond.observationAim)
        diamond.nudgeFreeAim(byDegrees: 0.00005)
        let diamondAfter = try XCTUnwrap(diamond.observationAim)
        XCTAssertTrue(diamondBefore.x != diamondAfter.x || diamondBefore.z != diamondAfter.z)
    }
}
