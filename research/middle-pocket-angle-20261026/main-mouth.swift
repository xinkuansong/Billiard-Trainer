import Foundation
import SceneKit
import Darwin

func emit(_ prefix: String, _ object: Any) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    FileHandle.standardOutput.write(Data((prefix + "\t" + String(decoding: data, as: UTF8.self) + "\n").utf8))
}
let surface = BTTablePhysics.surfaceY
let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: surface)
let halfW = Double(TablePhysics.innerWidth)/2
let radius = Double(BallPhysics.radius)
func vector(_ p: SCNVector3) -> [Double] { [Double(p.x), Double(p.y), Double(p.z)] }
try emit("READY", ["pid": ProcessInfo.processInfo.processIdentifier,
    "length": Double(TablePhysics.innerLength), "width": Double(TablePhysics.innerWidth),
    "radius": radius, "surfaceY": Double(surface), "model": "planarReference/appDefault",
    "pockets": geometry.pockets.map { ["id": $0.id, "center": vector($0.center), "radius": Double($0.radius)] },
    "linear": geometry.linearCushions.map { ["start": vector($0.start), "end": vector($0.end), "surface": $0.soundSurface.rawValue] }])
while let line = readLine() {
    do {
        try autoreleasepool {
            let input = try JSONSerialization.jsonObject(with: Data(line.utf8)) as! [String: Any]
            let angle = input["angle"] as! Double, distance = input["distance"] as! Double
            let side = input["side"] as! Double, hand = input["hand"] as! Double
            let speed = input["speed"] as! Double, mode = input["mode"] as! String
            let offsets = input["offsets"] as! [Double]
            let pocketIndex = side < 0 ? 4 : 5, pocket = geometry.pockets[pocketIndex]
            // Position angle is measured at the middle of the cushion line, not at the deep hole center.
            let radians = angle * Double.pi/180
            let start = SCNVector3(Float(hand*distance*sin(radians)), surface+BallPhysics.radius,
                                  Float(side*(halfW-distance*cos(radians))))
            let valid = abs(Double(start.x)) <= Double(TablePhysics.innerLength)/2-radius
                && abs(Double(start.z)) <= halfW-radius
            var row: [String: Any] = ["input": input, "start": vector(start), "valid": valid]
            if valid {
                var results: [[String: Any]] = []
                for offset in offsets {
                    let aim = SCNVector3(Float(offset),start.y,Float(side*halfW))
                    let delta = aim-start, direction = delta*(1/delta.length())
                    let velocity = direction*Float(speed)
                    let omega = mode == "rolling" ? SCNVector3(0,1,0).cross(velocity)*(1/BallPhysics.radius) : SCNVector3Zero
                    let engine = EventDrivenEngine(tableGeometry: geometry)
                    engine.setBall(BallState(position: start, velocity: velocity, angularVelocity: omega,
                                             state: mode == "rolling" ? .rolling : .sliding, name: "_8"))
                    let termination = engine.simulatePrediction(model: .appDefault, maxEvents: 500, maxTime: 45, highFidelityBounds: true)
                    let recorder = engine.getTrajectoryRecorder()
                    let frames = recorder.framesByBallName["_8"] ?? []
                    var events: [[String: Any]] = []
                    var hitPocket: String? = nil, clean = true, jaw = false
                    for (event,time) in zip(engine.resolvedEvents,engine.resolvedEventTimes) {
                        switch event {
                        case .ballCushion(_,let index,_):
                            let p = frames.last(where: { $0.time <= time+1e-6 })!.position
                            let kind = geometry.linearCushions.indices.contains(index) ? geometry.linearCushions[index].soundSurface.rawValue : "jaw"
                            let local = abs(p.x) < 0.16 && abs(Double(p.z)-side*halfW) < 0.16
                            if kind == "cushion" || !local { clean = false }
                            jaw = true
                            events.append(["kind": kind, "index": index, "time": Double(time), "position": vector(p)])
                        case .pocket(_,let id):
                            hitPocket = id
                            events.append(["kind": "pocket", "id": id, "time": Double(time)])
                        default: break
                        }
                    }
                    let direct = hitPocket == pocket.id && clean
                    var result: [String: Any] = ["offset": offset, "aim": vector(aim), "direction": vector(direction),
                        "termination": String(describing: termination), "pocket": hitPocket ?? "none",
                        "direct": direct, "cleanPot": direct && !jaw, "events": events,
                        "final": vector(engine.getBall("_8")!.position)]
                    if input["trace"] as? Bool == true {
                        result["frames"] = frames.map { ["t": Double($0.time), "p": vector($0.position),
                                                          "v": vector($0.velocity), "state": String(describing: $0.state)] }
                    }
                    results.append(result)
                }
                row["results"] = results
            }
            try emit("RESULT",row)
        }
    } catch { try emit("ERROR", ["error": String(describing: error)]); exit(1) }
}
