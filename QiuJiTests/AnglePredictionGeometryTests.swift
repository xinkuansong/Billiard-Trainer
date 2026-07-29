import XCTest
import CoreGraphics
@testable import QiuJi

final class AnglePredictionGeometryTests: XCTestCase {

    func test_zeroIsVerticalUp_bothSidesCoincide() {
        let v = CGPoint(x: 100, y: 200)
        let L: CGFloat = 80
        let left = AnglePredictionGeometry.point(from: v, length: L, angleDegrees: 0, side: .left)
        let right = AnglePredictionGeometry.point(from: v, length: L, angleDegrees: 0, side: .right)
        let zero = AnglePredictionGeometry.zeroEnd(from: v, length: L)
        XCTAssertEqual(left, right)
        XCTAssertEqual(left, zero)
        XCTAssertEqual(left.x, 100, accuracy: 1e-9)
        XCTAssertEqual(left.y, 120, accuracy: 1e-9)
    }

    func test_ninetyIsHorizontal_leftAndRight() {
        let v = CGPoint(x: 100, y: 200)
        let L: CGFloat = 80
        let right = AnglePredictionGeometry.point(from: v, length: L, angleDegrees: 90, side: .right)
        let left = AnglePredictionGeometry.point(from: v, length: L, angleDegrees: 90, side: .left)
        XCTAssertEqual(right.x, 180, accuracy: 1e-9)
        XCTAssertEqual(right.y, 200, accuracy: 1e-9)
        XCTAssertEqual(left.x, 20, accuracy: 1e-9)
        XCTAssertEqual(left.y, 200, accuracy: 1e-9)
    }

    func test_fortyFive_symmetricAboutVertical() {
        let v = CGPoint(x: 100, y: 200)
        let L: CGFloat = 80
        let right = AnglePredictionGeometry.point(from: v, length: L, angleDegrees: 45, side: .right)
        let left = AnglePredictionGeometry.point(from: v, length: L, angleDegrees: 45, side: .left)
        XCTAssertEqual(right.x - v.x, v.x - left.x, accuracy: 1e-9)
        XCTAssertEqual(right.y, left.y, accuracy: 1e-9)
        let expectedY = 200 - 80 * CGFloat(cos(Double.pi / 4))
        XCTAssertEqual(right.y, expectedY, accuracy: 1e-6)
    }

    func test_layout_centersFanAndFitsNinety() {
        let size = CGSize(width: 360, height: 320)
        let R: CGFloat = 14.7
        let margin: CGFloat = 20
        let (vertex, rayLen) = AnglePredictionGeometry.layout(
            canvasSize: size, ballRadius: R, margin: margin)

        XCTAssertEqual(vertex.x, size.width / 2, accuracy: 1e-9)
        // Vertical centering: content mid = vertex.y - rayLen/2 == h/2
        XCTAssertEqual(vertex.y - rayLen / 2, size.height / 2, accuracy: 1e-6)

        let tip = AnglePredictionGeometry.point(
            from: vertex, length: rayLen, angleDegrees: 90, side: .right)
        XCTAssertLessThanOrEqual(tip.x + R, size.width - margin + 1e-6)
        XCTAssertGreaterThanOrEqual(tip.x - R, margin - 1e-6)

        let top = AnglePredictionGeometry.zeroEnd(from: vertex, length: rayLen)
        XCTAssertGreaterThanOrEqual(top.y - R, margin - 1e-6)
        XCTAssertLessThanOrEqual(vertex.y + R, size.height - margin + 1e-6)
    }
}
