import Foundation
import SceneKit
import Darwin
func cpuSeconds() -> Double {
    var t = timespec(); clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &t)
    return Double(t.tv_sec) + Double(t.tv_nsec) / 1e9
}

// Research entry only. All rack/strike/collision/pocket/settlement code is production code.
func emit(_ prefix: String, _ object: Any) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    FileHandle.standardOutput.write(Data((prefix + "\t" + String(decoding: data, as: UTF8.self) + "\n").utf8))
}
func vec(_ v: SCNVector3) -> [Double] { [Double(v.x),Double(v.y),Double(v.z)] }
func vec3(_ v: SCNVector4) -> [Double] { [Double(v.x),Double(v.y),Double(v.z)] }
func evolved(_ f: BallFrame, dt: Float) -> BallFrame {
    let w=SCNVector3(f.angularVelocity.x,f.angularVelocity.y,f.angularVelocity.z)
    var p=f.position,v=f.velocity,omega=w
    switch f.state {
    case .sliding:
        let q=AnalyticalMotion.evolveSliding(position:p,velocity:v,angularVelocity:w,dt:dt);p=q.position;v=q.velocity;omega=q.angularVelocity
    case .rolling:
        let q=AnalyticalMotion.evolveRolling(position:p,velocity:v,angularVelocity:w,dt:dt);p=q.position;v=q.velocity;omega=q.angularVelocity
    case .spinning:
        let q=AnalyticalMotion.evolveSpinning(position:p,angularVelocity:w,dt:dt);p=q.position;omega=q.angularVelocity
    case .stationary,.pocketed: break
    }
    return BallFrame(time:f.time+dt,position:p,velocity:v,angularVelocity:SCNVector4(omega.x,omega.y,omega.z,0),state:f.state)
}

let profile = AccuracyTipSelector.renderedProfile()
let length = Double(TablePhysics.innerLength), width = Double(TablePhysics.innerWidth)
let radius = Double(BallPhysics.radius), surface = BTTablePhysics.surfaceY
try emit("READY", ["pid": ProcessInfo.processInfo.processIdentifier, "length": length,
                   "width": width, "radius": radius, "surfaceY": Double(surface),
                   "pockets": AngleSceneCalculator.pocketPositions(surfaceY: surface).map { [Double($0.x), Double($0.z)] }])
while let line = readLine() {
    do {
        try autoreleasepool {
            let input = try JSONSerialization.jsonObject(with: Data(line.utf8)) as! [String: Any]
            let n = input["n"] as! Int, seed = UInt64(input["seed"] as! String)!
            let game: RackGame = n == 15 ? .chineseEightBall : (n == 9 ? .nineBall : .zhuifen(balls: n))
            let originalRack = RackLayout.make(game, seed: seed)
            let variant = input["variant"] as? String ?? "baseline"
            precondition(variant == "baseline" || variant == "toward" || variant.hasPrefix("g"))
            var candidateBalls = originalRack.balls
            let groups = [[0,1,2],[4,7,8],[3,5,6,9],[11,12,13],[10,14]]
            let mask = variant.hasPrefix("g") ? Int(variant.dropFirst())! : 0
            precondition(mask >= 0 && mask < 32)
            let spacing = BallPhysics.radius * 2 + RackLayout.gap
            let rowOffset = spacing * sqrt(3.0) / 2.0
            var slot = 0
            for rr in 0..<5 {
                for cc in 0...rr {
                    let b = originalRack.balls[slot]
                    let nx = -TablePhysics.innerLength / 4 - Float(rr) * rowOffset
                    let nz = (Float(rr) / 2 - Float(cc)) * spacing
                    var p = b.position
                    if variant == "toward" && groups[1].contains(slot) {
                        p.x = nx + abs(p.x - nx)
                    } else if variant.hasPrefix("g") {
                        let g = groups.firstIndex(where: { $0.contains(slot) })!
                        let sign: Float = (mask & (1 << g)) != 0 ? 1 : -1
                        if g == 2 || g == 4 {
                            // Positive = outward from the long axis; negative = inward.
                            let side: Float = nz > 0 ? 1 : -1
                            p.z = nz + sign * side * abs(p.z - nz)
                        } else {
                            // Positive = toward cue (+X); negative = away (-X).
                            p.x = nx + sign * abs(p.x - nx)
                        }
                    }
                    candidateBalls[slot] = RackBall(key: b.key, number: b.number, position: p)
                    slot += 1
                }
            }
            let rack = Rack(game: game, cue: originalRack.cue, balls: candidateBalls, surfaceY: originalRack.surfaceY)
            let cue = SCNVector3(Float(input["x"] as! Double), surface + BallPhysics.radius, Float(input["z"] as! Double))
            let power = Float(input["power"] as! Double)
            let aim = BreakSimulator.aimAtApex(rack: rack, from: cue)
            let safe = AngleSceneCalculator.clampAwayFromPockets(cue, surfaceY: surface)
            let access = CueStrikeAccess(cue: cue, aim: aim, obstacles: rack.balls.map(\.position), surfaceY: surface, profile: profile)
            let pose = access.resolvedPose(spinX: 0, spinY: 0)
            var row: [String: Any] = ["input": input, "rack": rack.balls.map { ["number": $0.number, "x": Double($0.position.x), "z": Double($0.position.z)] },
                                      "cue": [Double(cue.x), Double(cue.z)], "power": Double(power),
                                      "direction": [Double(aim.x), Double(aim.z)], "spin": [0, 0], "simulatedElevation": 0]
            let validBox = cue.x >= TablePhysics.innerLength / 4 && cue.x <= TablePhysics.innerLength / 2 - BallPhysics.radius && abs(cue.z) <= TablePhysics.innerWidth / 2 - BallPhysics.radius
            if !validBox || (safe - cue).length() > 0.000001 || pose == nil {
                row["status"] = "invalid_input"
                row["reason"] = !validBox ? "outside_break_box" : ((safe - cue).length() > 0.000001 ? "pocket_clearance" : "cue_access")
            } else {
                row["accessElevation"] = Double(pose!.elevation)
                let start = DispatchTime.now().uptimeNanoseconds
                let cpuStart = cpuSeconds()
                let result = BreakSimulator.breakShot(rack: rack, cuePosition: cue, aimDirection: aim,
                    power: power, spinX: 0, spinY: 0, maxEvents: 8000, maxTime: 30)
                row["seconds"] = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9
                row["cpuSeconds"] = cpuSeconds() - cpuStart
                row["status"] = result.settled ? "settled" : "incomplete"
                row["termination"] = String(describing: result.termination)
                row["pocketed"] = result.pocketed
                row["cueScratched"] = result.cueScratched
                row["duration"] = Double(result.recorder.duration)
                row["board"] = result.board.onTable.mapValues { [$0.x, $0.y] }
                let names = [PositionPlayBall.cueKey] + rack.balls.map(\.key)
                let rec = result.recorder
                let sounds = rec.contactSounds
                let t0 = sounds.first(where: { $0.surface == .ball })!.time
                let frames = names.map { rec.framesByBallName[$0]! }
                precondition(frames.allSatisfy { $0.count == frames[0].count })
                row["t0"] = Double(t0)
                row["names"] = names
                row["contacts"] = sounds.map { ["t": Double($0.time-t0), "a": $0.ball, "b": $0.other, "kind": $0.surface.rawValue, "approach": Double($0.approachSpeed)] as [String: Any] }
                var traces: [[String: Any]] = []
                for k in 1..<frames[0].count {
                    let t = frames[0][k].time
                    if t < t0 { continue }; if t > t0 + 0.02 { break }
                    var changed: [[String: Any]] = []
                    for i in names.indices {
                        let prev = frames[i][k-1], post = frames[i][k]
                        precondition(post.time == t)
                        let pre = evolved(prev, dt: t-prev.time)
                        let dv = post.velocity-pre.velocity
                        if dv.length() > 0.00001 {
                            changed.append(["slot": i-1, "p": vec(post.position), "preV": vec(pre.velocity), "postV": vec(post.velocity), "preW": vec3(pre.angularVelocity), "postW": vec3(post.angularVelocity)])
                        }
                    }
                    if !changed.isEmpty { traces.append(["t": Double(t-t0), "changed": changed]) }
                }
                row["impulseTrace"] = traces
                var samples: [[String: Any]] = []
                for delay: Float in [0.001,0.005,0.02,0.05,0.1] {
                    let target = t0 + delay
                    let states = frames.map { list -> [String: Any] in
                        let prev = list.last(where: { $0.time <= target })!
                        let f = evolved(prev, dt: target-prev.time)
                        return ["p": vec(f.position), "v": vec(f.velocity), "w": vec3(f.angularVelocity), "state": f.state.rawValue]
                    }
                    samples.append(["delay": Double(delay), "states": states])
                }
                row["samples"] = samples
                row["firstContacts"] = rec.firstBallContacts.mapValues { c in ["time": Double(c.time-t0), "other": c.other.name, "incomingV": vec(c.incoming.velocity), "otherV": vec(c.other.velocity)] as [String: Any] }

            }
            try emit("RESULT", row)
        }
    } catch {
        try emit("ERROR", ["error": String(describing: error)])
        exit(1)
    }
}
