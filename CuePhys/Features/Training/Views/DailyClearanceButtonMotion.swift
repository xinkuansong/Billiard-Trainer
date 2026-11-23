import Foundation
import CoreGraphics

/// Decorative dynamics in button-local points: x right, y down. No table physics state.
struct DailyClearanceButtonMotion {
    static let rackSize: CGFloat = 28
    static let sampleRate = 120
    static let rollDuration = 5.2
    static let gatherStart = 0.65 + rollDuration + 0.65
    static let gatherEnd = gatherStart + rollDuration
    static let duration = gatherEnd + 3.5
    let size: CGSize
    let radius: CGFloat
    let home: [CGPoint]
    let rolling: [[CGPoint]]

    init(size: CGSize) {
        self.size = size
        let rootThree = sqrt(CGFloat(3))
        let r = (Self.rackSize / 4 - Self.rackSize * 0.05) / (1 + 2 / rootThree)
        radius = r
        let center = CGPoint(x: 8 + Self.rackSize / 2, y: size.height / 2)
        home = (0..<3).flatMap { row in
            (0...row).map { column in
                CGPoint(x: center.x + CGFloat(2 * column - row) * r,
                        y: center.y - 4 * r / rootThree + CGFloat(row) * rootThree * r)
            }
        }
        rolling = Self.simulate(home: home, radius: r, size: size)
    }

    struct Frame {
        let balls: [CGPoint]
        let rackOpacity: CGFloat
        let rackLift: CGFloat
    }

    func frame(at elapsed: Double) -> Frame {
        let t = max(0, elapsed).truncatingRemainder(dividingBy: Self.duration)
        if t < 0.65 {
            let lift = Self.ease(t / 0.65)
            return Frame(balls: home, rackOpacity: 0.7 * (1 - lift), rackLift: -5 * lift)
        }
        if t < 0.65 + Self.rollDuration { return Frame(balls: positions(at: t - 0.65), rackOpacity: 0, rackLift: -5) }
        if t < Self.gatherStart { return Frame(balls: rolling.last ?? home, rackOpacity: 0, rackLift: -5) }
        if t < Self.gatherEnd {
            // Retrace the simulated path at the same playback speed as the outward roll.
            let time = Self.rollDuration - (t - Self.gatherStart)
            return Frame(balls: positions(at: time), rackOpacity: 0, rackLift: -5)
        }
        let placed = Self.ease((t - Self.gatherEnd) / 0.6)
        return Frame(balls: home, rackOpacity: 0.7 * placed, rackLift: -5 * (1 - placed))
    }

    private func positions(at time: Double) -> [CGPoint] {
        let index = max(0, min(Double(rolling.count - 1), time * Double(Self.sampleRate)))
        let lower = Int(index), upper = min(lower + 1, rolling.count - 1)
        let fraction = CGFloat(index - Double(lower))
        return zip(rolling[lower], rolling[upper]).map { a, b in
            CGPoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction)
        }
    }

    private static func ease(_ x: Double) -> CGFloat {
        let u = CGFloat(min(1, max(0, x)))
        return u * u * (3 - 2 * u)
    }

    private static func simulate(home: [CGPoint], radius: CGFloat, size: CGSize) -> [[CGPoint]] {
        var points = home
        var velocities: [CGPoint] = [
            CGPoint(x: 72, y: -65), CGPoint(x: -45, y: -50), CGPoint(x: 95, y: -40),
            CGPoint(x: -60, y: 40), CGPoint(x: 82, y: 72), CGPoint(x: 100, y: 60)
        ]
        var result = [points]
        let dt: CGFloat = 1 / CGFloat(sampleRate * 4)
        // Only the capsule edge is a static obstacle; balls may cross the title and arrow.
        let cap = size.height / 2
        let limit = cap - radius - 1.5
        guard size.width > size.height, limit > 0 else { return [home] }

        func constrain(_ p: inout CGPoint, _ v: inout CGPoint) {
            let nearest = CGPoint(x: min(size.width - cap, max(cap, p.x)), y: cap)
            let dx = p.x - nearest.x, dy = p.y - nearest.y
            let distance = hypot(dx, dy)
            if distance > limit {
                let nx = dx / distance, ny = dy / distance
                p = CGPoint(x: nearest.x + nx * limit, y: nearest.y + ny * limit)
                let outward = v.x * nx + v.y * ny
                if outward > 0 { v.x -= 2 * outward * nx; v.y -= 2 * outward * ny }
            }
        }

        for tick in 1...Int(rollDuration * Double(sampleRate)) {
            let time = Double(tick) / Double(sampleRate)
            for _ in 0..<4 {
                // Nearly elastic early motion, followed by a visible natural slowdown.
                let drag = CGFloat(time < 2.6 ? 0.08 : 1.6 + (time - 2.6) * 0.9)
                for i in points.indices {
                    velocities[i].x *= exp(-drag * dt)
                    velocities[i].y *= exp(-drag * dt)
                    points[i].x += velocities[i].x * dt
                    points[i].y += velocities[i].y * dt
                }
                for _ in 0..<8 {
                    for i in points.indices { constrain(&points[i], &velocities[i]) }
                    for i in 0..<points.count {
                        for j in (i + 1)..<points.count {
                            let dx = points[j].x - points[i].x, dy = points[j].y - points[i].y
                            let distance = hypot(dx, dy)
                            guard distance < 2 * radius, distance > 0.000001 else { continue }
                            let nx = dx / distance, ny = dy / distance
                            let correction = (2 * radius - distance) / 2
                            points[i].x -= nx * correction; points[i].y -= ny * correction
                            points[j].x += nx * correction; points[j].y += ny * correction
                            let relative = (velocities[j].x - velocities[i].x) * nx
                                + (velocities[j].y - velocities[i].y) * ny
                            if relative < 0 {
                                velocities[i].x += relative * nx; velocities[i].y += relative * ny
                                velocities[j].x -= relative * nx; velocities[j].y -= relative * ny
                            }
                        }
                    }
                }
            }
            result.append(points)
        }
        return result
    }
}
