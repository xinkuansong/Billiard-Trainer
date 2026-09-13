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

    // MARK: - Profile constants are gated against the bundled bag envelope

    func testProfileMatchesBundledBagEnvelope() throws {
        let asset = try PocketGeometryAsset.load()
        XCTAssertEqual(asset.surfaceY, surfaceY, accuracy: 1e-6, "profile was measured at surfaceY 0.8")
        let bags = try asset.bagEnvelopes(), boundaries = try asset.captureBoundaries()
        var checked = 0
        for pocket in geometry.pockets {
            let bag = try XCTUnwrap(bags[pocket.id]), boundary = try XCTUnwrap(boundaries[pocket.id])
            let net = PocketNetPresentation.NetPocket(pocket: pocket, surfaceY: Double(surfaceY))
            XCTAssertEqual(bag.top, Double(surfaceY) - net.profile.mouthDepth, accuracy: 5e-4, pocket.id)
            XCTAssertEqual(boundary.restingCenterY, Double(surfaceY) - net.profile.restingDepth, accuracy: 5e-4, pocket.id)
            for ring in net.profile.rings {
                let y = Double(surfaceY) - ring.depth
                // Nearest measured ring (layer height 1.25 mm).
                let measured = try XCTUnwrap(bag.rings.min { abs($0[0].y - y) < abs($1[0].y - y) })
                XCTAssertEqual(measured[0].y, y, accuracy: 1e-3, pocket.id)
                let cx = measured.map(\.x).reduce(0, +) / Double(measured.count)
                let cz = measured.map(\.z).reduce(0, +) / Double(measured.count)
                let radii = measured.map { hypot($0.x - cx, $0.z - cz) }
                let meanRadius = radii.reduce(0, +) / Double(radii.count)
                let wall = net.wall(at: y, ballRadius: ballRadius)
                XCTAssertEqual(wall.axis.x, cx, accuracy: 3e-3, "\(pocket.id) depth \(ring.depth) axis x")
                XCTAssertEqual(wall.axis.z, cz, accuracy: 3e-3, "\(pocket.id) depth \(ring.depth) axis z")
                XCTAssertEqual(wall.reach + ballRadius, meanRadius, accuracy: 4e-3, "\(pocket.id) depth \(ring.depth) radius")
                checked += 1
            }
        }
        XCTAssertEqual(checked, 24)
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
                let wall = net.wall(at: slot.y, ballRadius: ballRadius)
                XCTAssertLessThanOrEqual(hypot(slot.x - wall.axis.x, slot.z - wall.axis.z), wall.reach + 1e-9, "\(pocket.id) slot inside wall")
                XCTAssertLessThan(slot.y, Double(surfaceY) - net.profile.mouthDepth + 2 * ballRadius, "\(pocket.id) slot below the hole")
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
                            let wall = net.wall(at: s.position.y, ballRadius: ballRadius)
                            XCTAssertLessThanOrEqual(hypot(s.position.x - wall.axis.x, s.position.z - wall.axis.z), wall.reach + 1e-6,
                                                     "\(pocket.id) v=\(speed) a=\(angle) t=\(s.time) inside the wall")
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
