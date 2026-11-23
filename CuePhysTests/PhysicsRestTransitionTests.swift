import XCTest
import SceneKit
@testable import QiuJi

final class PhysicsRestTransitionTests: XCTestCase {
    func test_zeroDurationTransitionsReachRestWithoutMoving() {
        for state in [BallMotionState.sliding, .rolling, .spinning] {
            let engine = EventDrivenEngine(tableGeometry: .chineseEightBallQiuJi(surfaceY: 0.8))
            let origin = SCNVector3(0,0.8+BallPhysics.radius,0)
            engine.setBall(BallState(position: origin, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: state, name: "ball"))
            engine.simulate(maxTime: 15, highFidelityBounds: true)
            let final = engine.getBall("ball")!
            XCTAssertEqual(final.state, .stationary, "initial state: \(state)")
            XCTAssertEqual(final.position.x, origin.x)
            XCTAssertEqual(final.position.z, origin.z)
            XCTAssertLessThan(engine.currentTime, 0.001, "zero energy must not consume the time budget")
        }
    }

    func test_subThresholdRollingVelocityCompletesAnalyticalTransition() {
        let engine = EventDrivenEngine(tableGeometry: .chineseEightBallQiuJi(surfaceY: 0.8))
        engine.setBall(BallState(position: SCNVector3(0,0.8+BallPhysics.radius,0), velocity: SCNVector3(0.00005,0,0), angularVelocity: SCNVector3(0,0,-0.00005/BallPhysics.radius), state: .rolling, name: "ball"))
        engine.simulate(maxTime: 15, highFidelityBounds: true)
        XCTAssertEqual(engine.getBall("ball")?.state, .stationary)
        XCTAssertLessThan(engine.currentTime, 0.001)
    }

    func test_positiveSpinIsNotStoppedBeforeItsAnalyticalTime() {
        let engine = EventDrivenEngine(tableGeometry: .chineseEightBallQiuJi(surfaceY: 0.8))
        let spin = SCNVector3(0,10,0)
        let expected = AnalyticalMotion.spinToStationaryTime(angularVelocity: spin)
        engine.setBall(BallState(position: SCNVector3(0,0.8+BallPhysics.radius,0), velocity: SCNVector3Zero, angularVelocity: spin, state: .spinning, name: "ball"))
        engine.simulate(maxTime: 15, highFidelityBounds: true)
        XCTAssertEqual(engine.getBall("ball")?.state, .stationary)
        XCTAssertEqual(engine.currentTime, expected, accuracy: 0.0001)
    }
}
