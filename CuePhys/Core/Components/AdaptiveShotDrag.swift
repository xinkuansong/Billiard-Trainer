import Foundation

/// Relative, vertical control input in screen points and seconds. No timer or inertia:
/// only newly received displacement changes the value. Base angle/power calibration
/// remains the host's responsibility. Defaults are an initial device-tuning candidate.
struct AdaptiveShotDrag {
    struct Configuration {
        var minimumGain = 0.1
        var fineSpeed = 24.0
        var coarseSpeed = 220.0
        var accelerationTime = 0.08
        var decelerationTime = 0.025
        var pauseInterval = 0.18
    }

    struct Sample {
        let delta: Double
        let gain: Double

        /// Fine detents remain perceptible, with a lighter impact than coarse movement.
        var hapticIntensity: Double {
            0.60 + 0.25 * min(1, max(0, (gain - 0.1) / 0.9))
        }
    }

    let configuration: Configuration
    private var previousTranslation = 0.0
    private var previousTime: TimeInterval?
    private(set) var gain: Double

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        gain = configuration.minimumGain
    }

    mutating func update(translation: Double, time: TimeInterval) -> Sample {
        guard translation.isFinite, time.isFinite else { return Sample(delta: 0, gain: gain) }
        if let previousTime, time <= previousTime { return Sample(delta: 0, gain: gain) }
        let delta = translation - previousTranslation
        let elapsed = previousTime.map { time - $0 }
        previousTranslation = translation
        previousTime = time
        guard let elapsed, elapsed < configuration.pauseInterval else {
            gain = configuration.minimumGain
            return Sample(delta: delta * gain, gain: gain)
        }

        let speed = abs(delta) / elapsed
        let x = min(1, max(0, (speed - configuration.fineSpeed)
            / (configuration.coarseSpeed - configuration.fineSpeed)))
        let target = configuration.minimumGain + (1 - configuration.minimumGain) * x * x * (3 - 2 * x)
        let tau = target > gain ? configuration.accelerationTime : configuration.decelerationTime
        let decay = exp(-elapsed / tau)
        // Integrate the changing gain over this sample, reducing event-rate dependence.
        let averageGain = target + (gain - target) * tau / elapsed * (1 - decay)
        gain = target + (gain - target) * decay
        return Sample(delta: delta * averageGain, gain: gain)
    }
}

/// Distance hysteresis plus rate limiting; crossings never quantize the value.
struct ShotDragDetents {
    /// Match the accepted metal-roll audition while haptics retain their 100 ms limit.
    static let soundMinimumInterval: TimeInterval = 0.06
    private let minimumInterval: TimeInterval
    private var anchor: Double?
    private var lastTime: TimeInterval?
    private var previousSpacing: Double?

    init(minimumInterval: TimeInterval = 0.1) {
        self.minimumInterval = minimumInterval
    }

    mutating func intensity(position: Double, spacing: Double, sample: AdaptiveShotDrag.Sample,
                            time: TimeInterval) -> Double? {
        guard spacing.isFinite, spacing > 0, position.isFinite else { return nil }
        // Rebase on scale changes. A finer ruler cannot consume previously accumulated
        // coarse travel and produce an impact without a new full fine increment.
        if previousSpacing != spacing {
            previousSpacing = spacing
            anchor = position
            return nil
        }
        guard let anchor else { self.anchor = position; return nil }
        guard sample.hapticIntensity > 0, sample.delta != 0 else {
            self.anchor = position
            return nil
        }
        guard abs(position - anchor) >= spacing else { return nil }
        // Consume suppressed crossings rather than queueing a burst after a pause.
        self.anchor = position
        guard lastTime.map({ time - $0 >= minimumInterval }) ?? true else { return nil }
        lastTime = time
        return sample.hapticIntensity
    }
}

struct PowerDragAdjustment {
    private(set) var fraction: Double
    private var lowerLatched = false
    private var upperLatched = false

    init(velocity: Double, range: ClosedRange<Double>) {
        fraction = ShotTuning.fraction(forVelocity: velocity, in: range)
    }

    /// Clamping each increment discards overshoot, so reversing responds immediately.
    mutating func move(delta: Double, height: Double, range: ClosedRange<Double>)
        -> (velocity: Double, reachedBoundary: Bool) {
        fraction = min(1, max(0, fraction - delta * 0.6 / max(1, height)))
        if fraction > 0.01 { lowerLatched = false }
        if fraction < 0.99 { upperLatched = false }
        var boundary = false
        if fraction == 0, delta > 0, !lowerLatched {
            lowerLatched = true
            boundary = true
        }
        if fraction == 1, delta < 0, !upperLatched {
            upperLatched = true
            boundary = true
        }
        return (ShotTuning.velocity(forFraction: fraction, in: range), boundary)
    }
}

/// Hysteresis and a short dwell keep the ruler stable while gain stays continuous.
/// It deliberately holds its last scale when stationary or between gestures.
struct ShotPrecisionScale {
    private(set) var isFine = false
    private var candidateSince: TimeInterval?

    var magnification: Double { isFine ? 10 : 1 }
    var stepMultiplier: Double { isFine ? 0.1 : 1 }

    mutating func resetTiming() { candidateSince = nil }

    mutating func update(sample: AdaptiveShotDrag.Sample, time: TimeInterval) {
        guard sample.delta != 0 else { return }
        let wantsChange = isFine ? sample.gain > 0.55 : sample.gain < 0.22
        guard wantsChange else { candidateSince = nil; return }
        guard let since = candidateSince else { candidateSince = time; return }
        guard time - since >= 0.12 else { return }
        isFine.toggle()
        candidateSince = nil
    }
}

/// Nested divisions fade in only when there is room. They share the same anchored
/// value axis, so zooming never changes the current value or crowds fine ticks.
struct ShotRulerTicks {
    static func opacity(spacing: Double) -> Double {
        min(1, max(0, (spacing - 3) / 4))
    }
}
