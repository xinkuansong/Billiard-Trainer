from pathlib import Path
import sys
src=Path(sys.argv[1]);dst=Path(sys.argv[2]);s=src.read_text()
s=s.replace('    struct State: Codable, Equatable {','    enum GeneralTiming: String, Codable { case selectionMatchedV1 }\n    struct State: Codable, Equatable {\n        // nil decodes old recordings with their original timing.\n        var generalTiming: GeneralTiming? = nil',1)
s=s.replace('    struct Transition: Codable {','''    struct Destination: Codable, Equatable {
        var context: UUID
        var state: State
        var shot: Shot
        var layout: Layout
        var target: Pose
        var resetThirdPerson: Bool?
    }
    struct Transition: Codable {''',1)
s=s.replace('        var rampSeconds: Double? = nil\n\n        func blend', '''        var rampSeconds: Double? = nil
        // Cumulative channel time at uniformly sampled path parameters. Stored in
        // snapshots so restoration and replay never depend on render cadence.
        var channelTimes: [Double]? = nil
        var destination: Destination? = nil

        func blend(at time: Double) -> Float {
            let distance = timeBlend(at: time)
            guard let times = channelTimes, times.count > 1, let total = times.last,
                  total > 0, distance > 0, distance < 1 else { return distance }
            let wanted = Double(distance) * total
            var low = 0, high = times.count - 1
            while high - low > 1 {
                let mid = (low + high) / 2
                if times[mid] < wanted { low = mid } else { high = mid }
            }
            let span = times[high] - times[low]
            let local = span > 0 ? (wanted - times[low]) / span : 1
            return Float((Double(low) + local) / Double(times.count - 1))
        }
        private func timeBlend''',1)
s=s.replace('          firstPersonSetback: Float? = nil) {','          firstPersonSetback: Float? = nil, generalTiming: GeneralTiming? = nil) {',1)
s=s.replace('let initial = State(anchoredTransitions:', 'let initial = State(generalTiming: generalTiming, anchoredTransitions:',1)
s=s.replace('if accept(next, animated: animated) {','if accept(next, animated: animated, generalTimingAllowed: false) {',1)
s=s.replace('clear:clear,framing: framing, turnPace: turnPace)','clear:clear,framing: framing, turnPace: turnPace, resetThirdPerson: resetThirdPerson)',1)
s=s.replace('framing: FramingPath? = nil, turnPace: TurnPace? = nil) -> Bool {', 'framing: FramingPath? = nil, turnPace: TurnPace? = nil,\n                                 resetThirdPerson: Bool? = nil, generalTimingAllowed: Bool = true) -> Bool {',1)
needle='''        if animated {
            if restart || transition == nil || (transition?.framing != nil && framing == nil) {'''
replace='''        let usesGeneral = next.generalTiming == .selectionMatchedV1 && generalTimingAllowed
        let destination = Destination(context: context, state: state, shot: shot, layout: layout,
                                      target: target, resetThirdPerson: resetThirdPerson)
        if usesGeneral && animated && restart {
            if transition?.destination == destination { return true }
            if simd_distance(pose.eye, target.eye) < 0.00001,
               abs(Self.angleDelta(pose.yaw, target.yaw)) < 0.00001,
               abs(pose.pitch - target.pitch) < 0.00001,
               abs(pose.verticalFOV - target.verticalFOV) < 0.0001 {
                pose = target; transition = nil; return true
            }
        }
        if animated {
            if restart || transition == nil || (transition?.framing != nil && framing == nil) {'''
assert needle in s;s=s.replace(needle,replace,1)
s=s.replace('                if let turnPace, let framedPath {','                var channelTimes: [Double]?\n                if let turnPace, let framedPath {',1)
s=s.replace('''                } else if let framedPath {
                    seconds = max(seconds, Self.framedDuration''','''                } else if usesGeneral {
                    channelTimes = Self.channelTimes(from: pose, to: target, framing: framedPath, layout: layout)
                    if let total = channelTimes?.last {
                        seconds = max(0.32, total + 0.16)
                    }
                } else if let framedPath {
                    seconds = max(seconds, Self.framedDuration''',1)
s=s.replace('rampSeconds: turnPace?.rampSeconds)','rampSeconds: turnPace?.rampSeconds ?? (channelTimes == nil ? nil : 0.16),\n                                   channelTimes: channelTimes, destination: usesGeneral ? destination : nil)',1)
needle='    private static func framedDuration('
addition='''    /// Independent channels preserve the accepted orbit speed. In particular,
    /// tangential eye travel is not subjected to the old 1.8 m/s chord limit.
    private static func channelTimes(from origin: Pose, to target: Pose, framing: FramingPath?,
                                     layout: Layout) -> [Double]? {
        let steps = 96
        var times = [0.0]
        var previous = origin
        for step in 1...steps {
            let u = Float(step) / Float(steps)
            let current: Pose
            var travel: Double
            if let framing {
                guard let p = framedPose(from: origin, to: target, along: framing, at: u, layout: layout) else { return nil }
                current = p
                let a = previous.eye - framing.point(at: Float(step - 1) / Float(steps))
                let b = current.eye - framing.point(at: u)
                let orbit = abs(angleDelta(atan2(a.z, a.x), atan2(b.z, b.x)))
                let radial = abs(hypot(b.x, b.z) - hypot(a.x, a.z))
                let anchor = simd_distance(framing.start, framing.end) / Float(steps)
                travel = max(Double(orbit) / TurnPace.selection120.radiansPerSecond,
                             Double(radial) / 3, Double(anchor) / 3)
            } else {
                current = .looking(eye: simd_mix(origin.eye, target.eye, SIMD3(repeating: u)),
                    yaw: origin.yaw + angleDelta(origin.yaw, target.yaw) * u,
                    pitch: origin.pitch + (target.pitch - origin.pitch) * u,
                    verticalFOV: origin.verticalFOV + (target.verticalFOV - origin.verticalFOV) * u)
                travel = Double(simd_distance(current.eye, previous.eye)) / 1.8
            }
            travel = max(travel,
                Double(abs(angleDelta(previous.yaw, current.yaw))) / TurnPace.selection120.radiansPerSecond,
                Double(abs(current.eye.y - previous.eye.y)) / 1.8,
                Double(abs(current.pitch - previous.pitch)) / (.pi / 2),
                Double(abs(current.verticalFOV - previous.verticalFOV)) / 40)
            times.append(times.last! + travel)
            previous = current
        }
        return times
    }

'''
assert needle in s;s=s.replace(needle,addition+needle,1)
dst.parent.mkdir(parents=True,exist_ok=True);dst.write_text(s)
