//
//  PocketNetPresentationTests.swift
//  QiuJiTests
//
//  W17-B/D (v63, DR-294): scripted net descent for planar pots.
//  Coordinate contract: SceneKit world, X–Z horizontal, Y up, metres.
//

import XCTest
import SceneKit
@testable import QiuJi

final class PocketNetPresentationTests: XCTestCase {
    typealias V = SIMD3<Double>
    typealias State = LocalPocketSimulation.State

    private let surfaceY: Float = 0.8
    private var geometry: TableGeometry { TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY) }
    private var ballRadius: Double { Double(BallPhysics.radius) }

    // MARK: - Profile constants are gated against the bundled pocket meshes

    /// Everything a falling ball can touch in one pocket: liner + cushion jaws (from the
    /// full-table contact patches near the pocket) and the net strands.
    private func hardTriangles(asset: PocketGeometryAsset, pocket: Pocket) throws -> [PocketContactTriangle] {
        let roles = try asset.surfaceRoles()
        let c = V(Double(pocket.center.x), 0, Double(pocket.center.z))
        var hard = asset.tablePatches.indices.filter { roles[$0] != .clothBed }.map { asset.tablePatches[$0].triangle }
            .filter { let m = ($0.a + $0.b + $0.c) / 3; return hypot(m.x - c.x, m.z - c.z) < 0.18 }
        hard += asset.bagSourceTrianglesByPocketID[pocket.id] ?? []
        return hard
    }

    /// Depth of the ball body into the nearest hard triangle (0 when clear).
    private func penetration(center q: V, into hard: [PocketContactTriangle]) -> Double {
        var worst = 0.0
        for t in hard {
            let d = length(q - t.closestPoint(to: q))
            if d < ballRadius { worst = max(worst, ballRadius - d) }
        }
        return worst
    }

    func testProfileMatchesBundledPocketMeshes() throws {
        let asset = try PocketGeometryAsset.load()
        XCTAssertEqual(asset.surfaceY, surfaceY, accuracy: 1e-6, "profile was measured at surfaceY 0.8")
        let boundaries = try asset.captureBoundaries()
        var checked = 0
        for pocket in geometry.pockets {
            let boundary = try XCTUnwrap(boundaries[pocket.id])
            let net = PocketNetPresentation.NetPocket(pocket: pocket, surfaceY: Double(surfaceY))
            XCTAssertEqual(boundary.restingCenterY, Double(surfaceY) - net.profile.restingDepth, accuracy: 5e-4, pocket.id)
            let hard = try hardTriangles(asset: asset, pocket: pocket)
            let outward = pocket.isCorner ? -simd_normalize(net.axisX + net.axisZ) : -net.axisZ
            for ring in stride(from: 0, to: net.profile.rings.count, by: 3).map({ net.profile.rings[$0] }) {
                let y = Double(surfaceY) - ring.depth + ballRadius
                let axis = net.axis(at: y, ballRadius: ballRadius)
                // The ring axis and 90 % of the reach in every tabulated direction are free of
                // the meshes (probe grid 2 mm + 0.5 mm ray march: 3 mm tolerance).
                let tolerance = 0.003
                XCTAssertLessThanOrEqual(penetration(center: axis, into: hard), tolerance, "\(pocket.id) depth \(ring.depth) axis")
                for k in 0..<PocketNetProfile.directions {
                    let a = Double(k) / Double(PocketNetProfile.directions) * 2 * .pi
                    let dir = net.axisX * cos(a) + net.axisZ * sin(a)
                    let reach = net.reach(at: y, toward: dir, ballRadius: ballRadius)
                    XCTAssertLessThanOrEqual(penetration(center: axis + dir * (reach * 0.9), into: hard), tolerance,
                                             "\(pocket.id) depth \(ring.depth) dir \(k)")
                    // And the wall really is there: 6 mm beyond the reach is blocked, unless that
                    // direction was capped by the planar drop circle (open toward the table).
                    let beyond = axis + dir * (reach + 0.006)
                    if hypot(beyond.x - net.center.x, beyond.z - net.center.z) <= net.dropRadius {
                        XCTAssertGreaterThan(penetration(center: beyond, into: hard), 0, "\(pocket.id) depth \(ring.depth) dir \(k) wall")
                    }
                }
                _ = outward
                checked += 1
            }
        }
        XCTAssertEqual(checked, 6 * 9)
    }

    // MARK: - Contact mechanics (DR-297)

    func testDescentFallsUnderGravityAfterLinerContact() throws {
        let g = Double(TablePhysics.gravity), retention = Double(TablePhysics.pocketLinerRetention)
        for pocket in geometry.pockets {
            let net = PocketNetPresentation.NetPocket(pocket: pocket, surfaceY: Double(surfaceY))
            let slot = net.slots(ballRadius: ballRadius)[0]
            let outward = pocket.isCorner ? -simd_normalize(net.axisX + net.axisZ) : -net.axisZ
            // Enter across the drop circle from the table side at 1.2 m/s, straight at the liner.
            let start = State(time: 0.5, position: net.center - outward * net.dropRadius + V(0, ballRadius, 0),
                              velocity: outward * 1.2, omega: .zero)
            let samples = PocketNetPresentation.descent(from: start, pocket: net, slot: slot, ballRadius: ballRadius,
                                                        gravity: g, retention: retention)
            // Time to reach the floor: free fall over the drop takes ~0.16 s. The corner cup is
            // near-vertical (≈ free fall); the middle bag has a real overhang below its mouth
            // that redirects the fall, so allow 1.8× (the creeping script needed > 1.5 s).
            let floorTime = samples.first { $0.position.y <= slot.y + 1e-9 }?.time ?? .infinity
            let freeFall = sqrt(2 * (start.position.y - slot.y) / g)
            XCTAssertLessThanOrEqual(floorTime - start.time, 1.8 * freeFall, "\(pocket.id) reached the floor at \(floorTime - start.time)s (free fall \(freeFall)s)")
            // The approach speed is eaten by the liner on arrival: the first sample whose
            // horizontal speed dropped below 95 % of the entry speed is already below 0.1 m/s.
            let contact = try XCTUnwrap(samples.first { hypot($0.velocity.x, $0.velocity.z) < 1.2 * 0.95 }, pocket.id)
            XCTAssertLessThan(hypot(contact.velocity.x, contact.velocity.z), 0.1, "\(pocket.id) arrival at t=\(contact.time)")
            XCTAssertLessThan(contact.time - start.time, 0.1, "\(pocket.id) must meet the liner within the mouth")
            // Vertical velocity is never damped. Away from the wall each step is exactly -g.
            // In sustained contact with a near-vertical, kink-free stretch of wall (|ny| < 0.2,
            // normal turning < 0.1 between samples) the fall must still gain ≥ 0.8 g — the
            // creeping script multiplied vy by the retention on every such step.
            var airborne = 0, freeSteps = 0, verticalContactSteps = 0
            var previous = samples[0], previousNormal: V? = nil
            for s in samples.dropFirst() where previous.position.y > slot.y + 1e-9 && s.position.y > slot.y + 1e-9 {
                let axis = net.axis(at: s.position.y, ballRadius: ballRadius)
                let d = V(s.position.x - axis.x, 0, s.position.z - axis.z), dist = length(d)
                let outward = dist > 1e-12 ? d / dist : net.axisX
                let relaxing = s.time < start.time + PocketNetPresentation.entryRelaxDuration
                let isTouching = dist >= net.reach(at: s.position.y, toward: outward, ballRadius: ballRadius) - 1e-6
                let normal: V? = isTouching ? net.wallNormal(at: s.position.y, outward: outward, ballRadius: ballRadius) : nil
                defer { previous = s; previousNormal = relaxing ? nil : normal }
                let dt = s.time - previous.time
                guard dt > 0, !relaxing else { continue }
                airborne += 1
                let dvy = (s.velocity.y - previous.velocity.y) / dt
                if let n = normal {
                    guard let pn = previousNormal, abs(n.y) < 0.2, length(n - pn) < 0.1 else { continue }
                    verticalContactSteps += 1
                    XCTAssertLessThanOrEqual(dvy, -0.8 * g, "\(pocket.id) t=\(s.time) sliding on a vertical wall: dvy=\(dvy) ny=\(n.y)")
                } else {
                    freeSteps += 1
                    XCTAssertEqual(dvy, -g, accuracy: 1e-6, "\(pocket.id) t=\(s.time) free step must be exactly -g")
                }
            }
            XCTAssertGreaterThan(airborne, 10, pocket.id)
            XCTAssertGreaterThan(freeSteps, 0, "\(pocket.id) the ball should leave the wall somewhere in the flare")
            print("[W17 net] \(pocket.id) floor after \(floorTime - start.time)s (free fall \(freeFall)s), free steps \(freeSteps), vertical-wall sliding steps \(verticalContactSteps)")
        }
    }

    func testDescentBodyStaysOutOfTheBundledMeshes() throws {
        let asset = try PocketGeometryAsset.load()
        let g = Double(TablePhysics.gravity), retention = Double(TablePhysics.pocketLinerRetention)
        var worstOverall = 0.0
        for pocket in geometry.pockets {
            let net = PocketNetPresentation.NetPocket(pocket: pocket, surfaceY: Double(surfaceY))
            let hard = try hardTriangles(asset: asset, pocket: pocket)
            let slot = net.slots(ballRadius: ballRadius)[0]
            let toCenter = simd_normalize(V(-Double(pocket.center.x), 0, -Double(pocket.center.z)))
            for speed in [0.3, 1.2, 2.5] {
                for angle in [-0.6, 0.0, 0.6] {
                    let outward = -toCenter
                    let dir = V(outward.x * cos(angle) - outward.z * sin(angle), 0, outward.x * sin(angle) + outward.z * cos(angle))
                    let start = State(time: 0, position: net.center - dir * net.dropRadius + V(0, ballRadius, 0),
                                      velocity: dir * speed, omega: .zero)
                    let samples = PocketNetPresentation.descent(from: start, pocket: net, slot: slot, ballRadius: ballRadius,
                                                                gravity: g, retention: retention)
                    var worst = 0.0
                    for s in samples where s.time >= PocketNetPresentation.entryRelaxDuration {
                        worst = max(worst, penetration(center: s.position, into: hard))
                    }
                    worstOverall = max(worstOverall, worst)
                    // Ring model residual (see testProfileMatchesBundledPocketMeshes) plus the 2 mm
                    // probe grid: the body may graze the mesh by that much, never sink into it.
                    XCTAssertLessThanOrEqual(worst, pocket.isCorner ? 0.006 : 0.011,
                                             "\(pocket.id) v=\(speed) a=\(angle) body penetrates the mesh by \(worst)")
                }
            }
        }
        print("[W17 net] worst body penetration after entry relaxation: \(worstOverall) m")
    }

    // MARK: - Slots and descent invariants

    func testSlotsLieInsideTheNet() {
        for pocket in geometry.pockets {
            let net = PocketNetPresentation.NetPocket(pocket: pocket, surfaceY: Double(surfaceY))
            let slots = net.slots(ballRadius: ballRadius)
            XCTAssertEqual(slots.count, PocketNetPresentation.netCapacity)
            XCTAssertEqual(length(slots[1] - slots[0]), 2 * ballRadius, accuracy: 1e-9, "upper ball rests on the lower one")
            XCTAssertGreaterThan(slots[1].y, slots[0].y)
            for slot in slots {
                let axis = net.axis(at: slot.y, ballRadius: ballRadius)
                let d = V(slot.x - axis.x, 0, slot.z - axis.z), dist = length(d)
                let reach = dist > 1e-12 ? net.reach(at: slot.y, toward: d / dist, ballRadius: ballRadius) : 1
                XCTAssertLessThanOrEqual(dist, reach + 1e-9, "\(pocket.id) slot inside wall")
                XCTAssertLessThan(slot.y, Double(surfaceY) - ballRadius, "\(pocket.id) slot fully below the cloth")
            }
        }
    }

    func testDescentStaysInsideNetAndEndsOnSlot() {
        let gravity = Double(TablePhysics.gravity), retention = Double(TablePhysics.pocketLinerRetention)
        var runs = 0
        for pocket in geometry.pockets {
            let net = PocketNetPresentation.NetPocket(pocket: pocket, surfaceY: Double(surfaceY))
            let slots = net.slots(ballRadius: ballRadius)
            let toCenter = simd_normalize(V(-Double(pocket.center.x), 0, -Double(pocket.center.z)))
            for speed in [0.15, 0.6, 1.5, 3.0] {
                for angle in [-0.5, 0.0, 0.5] {
                    // Enter on the drop circle, heading roughly away from the table (into the pocket).
                    let outward = -toCenter
                    let dir = V(outward.x * cos(angle) - outward.z * sin(angle), 0, outward.x * sin(angle) + outward.z * cos(angle))
                    let start = State(time: 0.75, position: net.center - dir * net.dropRadius + V(0, ballRadius, 0),
                                      velocity: dir * speed, omega: V(0, 12, 0))
                    for slot in slots {
                        let samples = PocketNetPresentation.descent(from: start, pocket: net, slot: slot, ballRadius: ballRadius,
                                                                    gravity: gravity, retention: retention)
                        runs += 1
                        XCTAssertGreaterThanOrEqual(samples.count, 3)
                        XCTAssertEqual(samples[0].time, start.time)
                        let last = samples[samples.count - 1]
                        XCTAssertEqual(last.position, slot, "\(pocket.id) v=\(speed) a=\(angle) must end exactly on the slot")
                        XCTAssertEqual(last.velocity, .zero)
                        XCTAssertLessThanOrEqual(last.time - start.time,
                                                 PocketNetPresentation.maxDescentDuration + PocketNetPresentation.settleDuration + 1e-9)
                        var previous = samples[0]
                        for s in samples.dropFirst() {
                            XCTAssertGreaterThan(s.time, previous.time)
                            XCTAssertTrue(s.position.x.isFinite && s.position.y.isFinite && s.position.z.isFinite)
                            XCTAssertLessThanOrEqual(s.position.y, previous.position.y + 1e-9, "no bounce: height is monotone")
                            XCTAssertGreaterThanOrEqual(s.position.y, slot.y - 1e-9, "never below the slot floor")
                            XCTAssertLessThanOrEqual(s.velocity.y, 1e-12, "the liner never lifts the ball")
                            if s.time >= start.time + PocketNetPresentation.entryRelaxDuration {
                                let axis = net.axis(at: s.position.y, ballRadius: ballRadius)
                                let d = V(s.position.x - axis.x, 0, s.position.z - axis.z), dist = length(d)
                                let reach = dist > 1e-12 ? net.reach(at: s.position.y, toward: d / dist, ballRadius: ballRadius) : 1
                                XCTAssertLessThanOrEqual(dist, reach + 1e-6, "\(pocket.id) v=\(speed) a=\(angle) t=\(s.time) inside the wall")
                            }
                            previous = s
                        }
                    }
                }
            }
        }
        XCTAssertEqual(runs, 6 * 4 * 3 * 2)
    }

    func testDescentIsDeterministic() {
        let pocket = geometry.pockets[0]
        let net = PocketNetPresentation.NetPocket(pocket: pocket, surfaceY: Double(surfaceY))
        let start = State(time: 1.25, position: net.center + V(0.02, ballRadius, 0.03), velocity: V(-0.4, 0, -0.9), omega: V(3, 0, 1))
        let slot = net.slots(ballRadius: ballRadius)[0]
        let a = PocketNetPresentation.descent(from: start, pocket: net, slot: slot, ballRadius: ballRadius, gravity: 9.81, retention: 0.4)
        let b = PocketNetPresentation.descent(from: start, pocket: net, slot: slot, ballRadius: ballRadius, gravity: 9.81, retention: 0.4)
        XCTAssertEqual(a.count, b.count)
        for (x, y) in zip(a, b) {
            XCTAssertEqual(x.time, y.time); XCTAssertEqual(x.position, y.position); XCTAssertEqual(x.velocity, y.velocity)
        }
    }

    // MARK: - Recorder attachment and FIFO

    private func makePottedRecorder(entries: [(ball: String, pocket: Int, time: Float)]) -> TrajectoryRecorder {
        let recorder = TrajectoryRecorder()
        let geometry = self.geometry
        for e in entries {
            let pocket = geometry.pockets[e.pocket]
            let inward = SCNVector3(-pocket.center.x, 0, -pocket.center.z).normalized()
            let position = pocket.center + inward * pocket.radius
            let velocity = inward * -0.8
            let ball = BallState(position: SCNVector3(position.x, surfaceY + BallPhysics.radius, position.z), velocity: velocity,
                                 angularVelocity: SCNVector3Zero, state: .sliding, name: e.ball)
            recorder.recordFrame(ballName: e.ball, frame: BallFrame(time: 0, position: ball.position - velocity * e.time,
                                                                    velocity: velocity, angularVelocity: SCNVector4Zero, state: .sliding))
            recorder.recordPocketEntry(ball: ball, pocketID: pocket.id, time: e.time, source: .event, geometry: geometry)
            recorder.recordFrame(ballName: e.ball, frame: BallFrame(time: e.time, position: pocket.center, velocity: SCNVector3Zero,
                                                                    angularVelocity: SCNVector4Zero, state: .pocketed))
        }
        return recorder
    }

    func testPlaybackAttachesNetTailForPlanarPot() throws {
        let recorder = makePottedRecorder(entries: [("ball_1", 4, 0.9)])
        XCTAssertTrue(recorder.collectionTailsByBallName.isEmpty)
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: surfaceY)
        let tail = try XCTUnwrap(recorder.collectionTailsByBallName["ball_1"])
        XCTAssertNotNil(tail.samples); XCTAssertNil(tail.fadeStart)
        XCTAssertEqual(tail.start.time, 0.9, accuracy: 1e-6)
        let net = PocketNetPresentation.NetPocket(pocket: geometry.pockets[4], surfaceY: Double(surfaceY))
        XCTAssertEqual(tail.end.position, net.slots(ballRadius: ballRadius)[0])
        // Verdict untouched; presentation follows the tail and never fades.
        XCTAssertTrue(recorder.isBallPocketed("ball_1"))
        XCTAssertTrue(recorder.confirmedCaptures.isEmpty)
        XCTAssertEqual(playback.collectionOpacity(ballName: "ball_1", time: 0), 1)
        XCTAssertEqual(playback.collectionOpacity(ballName: "ball_1", time: 30), 1)
        let resting = try XCTUnwrap(playback.stateAt(ballName: "ball_1", time: Float(tail.end.time) + 1))
        XCTAssertEqual(Double(resting.position.y), tail.end.position.y, accuracy: 1e-5)
        XCTAssertEqual(resting.motionState, .pocketed)
        let falling = try XCTUnwrap(playback.stateAt(ballName: "ball_1", time: 0.95))
        XCTAssertLessThan(Double(falling.position.y), Double(surfaceY) + ballRadius)
        XCTAssertGreaterThan(Double(falling.position.y), tail.end.position.y)
        // Idempotent: a second playback over the same recorder keeps the tail.
        _ = TrajectoryPlayback(recorder: recorder, surfaceY: surfaceY)
        XCTAssertEqual(recorder.collectionTailsByBallName["ball_1"]?.end.position, tail.end.position)
    }

    func testFifoOverflowEvictsOldestAndShiftsTheRestDown() throws {
        let recorder = makePottedRecorder(entries: [("ball_1", 0, 0.5), ("ball_2", 0, 1.0), ("ball_3", 0, 2.0)])
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: surfaceY)
        let net = PocketNetPresentation.NetPocket(pocket: geometry.pockets[0], surfaceY: Double(surfaceY))
        let slots = net.slots(ballRadius: ballRadius)
        let t1 = try XCTUnwrap(recorder.collectionTailsByBallName["ball_1"])
        let t2 = try XCTUnwrap(recorder.collectionTailsByBallName["ball_2"])
        let t3 = try XCTUnwrap(recorder.collectionTailsByBallName["ball_3"])
        // Oldest evicted when the third ball starts falling.
        XCTAssertEqual(t1.fadeStart, 2.0)
        XCTAssertEqual(t1.end.position, slots[0])
        XCTAssertEqual(playback.collectionOpacity(ballName: "ball_1", time: 1.9), 1)
        XCTAssertEqual(playback.collectionOpacity(ballName: "ball_1", time: 2.0 + Float(TrajectoryPlayback.pocketFadeDuration) + 0.01), 0)
        // Second ball rested on the upper slot, then slid down to the lower slot.
        XCTAssertNil(t2.fadeStart)
        let restedUpper = try XCTUnwrap(t2.sample(at: 1.99))
        XCTAssertEqual(restedUpper.position, slots[1])
        XCTAssertEqual(t2.end.position, slots[0])
        XCTAssertEqual(t2.end.time, 2.0 + PocketNetPresentation.settleDuration, accuracy: 1e-9)
        // Third ball lands on the (now) upper slot and stays visible.
        XCTAssertNil(t3.fadeStart)
        XCTAssertEqual(t3.end.position, slots[1])
        XCTAssertEqual(playback.collectionOpacity(ballName: "ball_3", time: 60), 1)
    }

    func testEndToEndDefaultPotRestsInTheNet() throws {
        // Straight shot into the top-right corner from the centre line.
        let y = surfaceY + BallPhysics.radius
        let pocket = geometry.pockets[3]
        let cue = SCNVector3(pocket.center.x - 0.6, y, pocket.center.z - 0.6)
        let aim = SCNVector3(1, 0, 1)
        let result = ShotPredictor.simulateFree(cueBall: cue, aimDir: aim, velocity: 1.6, spinX: 0, spinY: 0, surfaceY: surfaceY, balls: [])
        XCTAssertTrue(result.cuePocketed)
        let recorder = try XCTUnwrap(result.recorder)
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: surfaceY)
        let tail = try XCTUnwrap(recorder.collectionTailsByBallName[ShotInput.cueBallName])
        let net = PocketNetPresentation.NetPocket(pocket: pocket, surfaceY: Double(surfaceY))
        XCTAssertEqual(tail.end.position, net.slots(ballRadius: ballRadius)[0])
        XCTAssertEqual(playback.collectionOpacity(ballName: ShotInput.cueBallName, time: playback.duration + 5), 1)
        XCTAssertGreaterThanOrEqual(playback.duration, Float(tail.end.time))
        // The scripted fall starts from the planar capture snapshot, not from the snapped centre.
        let entry = try XCTUnwrap(recorder.pocketEntries.first)
        XCTAssertEqual(tail.start.position.x, Double(entry.ball.position.x), accuracy: 1e-6)
        XCTAssertEqual(tail.start.position.z, Double(entry.ball.position.z), accuracy: 1e-6)
    }
}
