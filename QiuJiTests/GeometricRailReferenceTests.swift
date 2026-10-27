import XCTest
import SceneKit
import simd
@testable import QiuJi

final class GeometricRailReferenceTests: XCTestCase {
    typealias G = GeometricRailReference
    private func context(_ sign: Float = 1) throws -> G.Context {
        try XCTUnwrap(G.Context(cue: .init(-0.6, 0, -0.25 * sign),
            target: .init(0, 0, 0), pocket: .init(1.27, 0, 0.635 * sign)))
    }
    func testDefaultTangentAndMirroredSides() throws {
        let a = try context(), b = try context(-1)
        XCTAssertEqual(simd_dot(try XCTUnwrap(a.tangent), a.potDirection), 0, accuracy: 1e-12)
        XCTAssertTrue(a.allows(try XCTUnwrap(a.defaultFirst)))
        XCTAssertFalse(a.allows(a.pocket))
        let p = try XCTUnwrap(a.defaultFirst), q = try XCTUnwrap(b.defaultFirst)
        XCTAssertEqual(p.x, q.x, accuracy: 1e-8); XCTAssertEqual(p.y, -q.y, accuracy: 1e-8)
    }
    func testDraggingCannotCrossIntoPocketSideOrPocketGaps() throws {
        for sign: Float in [-1, 1] {
            let c = try context(sign)
            for x in stride(from: -2.0, through: 2, by: 0.1) {
                for z in stride(from: -1.0, through: 1, by: 0.1) {
                    let p = try XCTUnwrap(c.constrain(.init(x, z)))
                    XCTAssertTrue(c.allows(p)); XCTAssertNotNil(G.rail(at: p))
                    XCTAssertLessThanOrEqual(G.cross(c.incoming, p-c.ghost) * c.pocketSide, 1e-8)
                }
            }
        }
    }
    func testOneThroughFiveReflectionsAndEqualAngles() throws {
        let c = try context()
        // Choose a legal first contact whose five-bounce itinerary avoids pockets.
        let first = try XCTUnwrap(railSamples(divisions: 20)
            .first { c.allows($0) && G.path(context: c, first: $0, reflections: 5).count == 7 })
        for n in 1...5 {
            let route = G.path(context: c, first: first, reflections: n)
            XCTAssertEqual(route.count, n+2)
            for i in 1..<(route.count-1) {
                let normal = try XCTUnwrap(G.rail(at: route[i])).normal
                let incoming = try XCTUnwrap(G.unit(route[i]-route[i-1]))
                let outgoing = try XCTUnwrap(G.unit(route[i+1]-route[i]))
                XCTAssertEqual(simd_distance(G.reflected(incoming, normal: normal), outgoing), 0, accuracy: 1e-7)
            }
        }
    }
    func testRadiusInsetAndGapTermination() throws {
        for rail in G.rails {
            let p = (rail.start+rail.end)/2
            let edge = abs(rail.normal.x) > 0.5 ? Double(TablePhysics.innerLength/2) : Double(TablePhysics.innerWidth/2)
            let coordinate = abs(rail.normal.x) > 0.5 ? abs(p.x) : abs(p.y)
            XCTAssertEqual(edge-coordinate, Double(BallPhysics.radius), accuracy: 1e-7)
        }
        let c = try context()
        XCTAssertNil(G.rail(at: .init(0, Double(TablePhysics.innerWidth/2-BallPhysics.radius))))
        let candidate = try XCTUnwrap(railSamples(divisions: 200)
            .first { c.allows($0) && G.path(context: c, first: $0, reflections: 5).count < 7 })
        let route = G.path(context: c, first: candidate, reflections: 5)
        XCTAssertGreaterThan(route.count, 2); XCTAssertNil(G.rail(at: try XCTUnwrap(route.last)))
    }
    private func railSamples(divisions: Int) -> [SIMD2<Double>] {
        var points: [SIMD2<Double>] = []
        for rail in G.rails {
            let delta = rail.end - rail.start
            for index in 1..<divisions {
                let fraction = Double(index) / Double(divisions)
                points.append(rail.start + delta * fraction)
            }
        }
        return points
    }
    func testDegenerateInputsDoNotInventSeparationDirection() throws {
        XCTAssertNil(G.Context(cue: .init(-1,0,0), target: .init(0,0,0), pocket: .init(0,0,0)))
        let straight = try XCTUnwrap(G.Context(cue: .init(-1,0,0), target: .init(0,0,0), pocket: .init(1,0,0)))
        XCTAssertNil(straight.tangent); XCTAssertNil(straight.defaultFirst)
        XCTAssertNil(straight.constrain(.init(.nan, 0)))
        XCTAssertNil(G.Context(cue: .init(1,0,0), target: .init(0,0,0), pocket: .init(1.27,0,0)))
    }
    @MainActor
    func testShotSnapshotRestoresDraggedPointAndNextShotRequiresOptIn() throws {
        let scene = AngleTrainingScene()
        // Keep the scene alive for the full tool lifecycle.
        let live = GeometricReferenceTool(scene: scene)
        live.update(identity: "first", cue: .init(-0.6,0,-0.25), target: .init(0,0,0), pocketIndex: 3)
        live.select(3); XCTAssertTrue(live.visible)
        live.drag(to: .init(-1.2,0,-0.5))
        let draft = live.draft
        live.freeze(); XCTAssertTrue(live.draggableNodes.isEmpty)
        live.complete(); XCTAssertFalse(live.visible)
        live.restore(); XCTAssertEqual(live.draft, draft); XCTAssertTrue(live.visible)
        live.nextShot(); XCTAssertEqual(live.draft.reflections, 0); XCTAssertFalse(live.visible)
        live.update(identity: "second", cue: .init(-0.7,0,-0.3), target: .init(0,0,0), pocketIndex: 3)
        XCTAssertEqual(live.draft.reflections, 0)
        live.restore(); XCTAssertEqual(live.draft, draft)
        live.reset()
        live.update(identity: "straight", cue: .init(0,0,0.3), target: .init(0,0,0), pocketIndex: 4)
        live.select(1); XCTAssertTrue(live.needsFirstPoint)
        live.freeze(); live.nextShot(); live.restore()
        XCTAssertTrue(live.needsFirstPoint, "Undo restores the manual-selection instruction as well as the point")
    }
}
