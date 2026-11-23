import XCTest
import SceneKit
@testable import QiuJi

/// Q7.1（问题集合 v5）2D 瞄准点训练白线绘制与红点显隐几何金标准。
///
/// 坐标契约：纯 2D 平面（本测以 x 右、y = 第二轴；对应消费方 SceneKit 水平面 x→x、z→y）。
/// R = 中八球半径 0.028575m。覆盖三情形：
///   1. 线不触球（垂距 ≥ R）→ 白线延伸到库边（`railEnd`）、无红点；
///   2. 垂足红点显隐边界（垂距 R 上下翻转 touchesBall）；
///   3. 线接触球（垂距 < R）→ 接触点 = 射线与球面第一交点。
final class AimLineGeometryTests: XCTestCase {

    private let R = CGFloat(AngleSceneCalculator.ballRadius)   // 0.028575

    func test_instructionalRay_reachesClothEdgeWithoutChangingDirection() {
        let origins = [SCNVector3(0, 0.828575, 0), SCNVector3(0.8, 0.828575, -0.3)]
        for origin in origins {
            for degrees in stride(from: 0, to: 360, by: 5) {
                let angle = Float(degrees) * .pi / 180
                let direction = SCNVector3(cos(angle), 0, sin(angle))
                let end = AngleSceneCalculator.rayToInnerRail(from: origin, dir: direction, inset: 0)
                let halfL = AngleSceneCalculator.innerLength / 2
                let halfW = AngleSceneCalculator.innerWidth / 2
                XCTAssertLessThanOrEqual(abs(end.x), halfL + 1e-5)
                XCTAssertLessThanOrEqual(abs(end.z), halfW + 1e-5)
                XCTAssertLessThan(min(abs(abs(end.x) - halfL), abs(abs(end.z) - halfW)), 1e-5)
                let dx = end.x - origin.x, dz = end.z - origin.z
                XCTAssertEqual(dx * direction.z - dz * direction.x, 0, accuracy: 1e-5)
                XCTAssertGreaterThan(dx * direction.x + dz * direction.z, 0)
                XCTAssertEqual(end.y, origin.y)
            }
        }
    }

    // MARK: - 情形 1：不触球 → 延伸库边

    func test_lineMissesBall_extendsToRail_noDots() {
        // 母球在 (-0.5, 0.05)，沿 +x 瞄准；目标球心到该线垂距 = 0.05 > R ⇒ 不触球。
        let cue = CGPoint(x: -0.5, y: 0.05)
        let target = CGPoint.zero
        let dir = CGPoint(x: 1, y: 0)
        let rail = CGPoint(x: 1.241425, y: 0.05)   // 哨兵库边终点

        let res = AimLineGeometry.resolve(cue: cue, dir: dir, target: target,
                                          ballRadius: R, railEnd: rail)
        XCTAssertFalse(res.touchesBall, "垂距 0.05 > R ⇒ 不触球")
        XCTAssertNil(res.contactPoint, "不触球时无接触点红点")
        XCTAssertEqual(res.lineEnd.x, rail.x, accuracy: 1e-9, "白线终点 = 库边（非 2R 捕捉）")
        XCTAssertEqual(res.lineEnd.y, rail.y, accuracy: 1e-9)
        // 垂足仍可计算（= (0, 0.05)），但因不触球不作红点。
        XCTAssertEqual(res.aimPoint.x, 0, accuracy: 1e-9)
        XCTAssertEqual(res.aimPoint.y, 0.05, accuracy: 1e-9)
    }

    /// 与真实 `rayToInnerRail`（V1 共享）联动：延伸终点确为库内边界点。
    func test_lineMissesBall_railEndMatchesRayToInnerRail() {
        let cueV = SCNVector3(-0.5, 0, 0.05)
        let dirV = SCNVector3(1, 0, 0)
        let railV = AngleSceneCalculator.rayToInnerRail(from: cueV, dir: dirV)
        // 短库（常 X）：innerLength/2 − R。
        let expectedX = AngleSceneCalculator.innerLength / 2 - AngleSceneCalculator.ballRadius
        XCTAssertEqual(railV.x, expectedX, accuracy: 1e-5)
        XCTAssertEqual(railV.z, 0.05, accuracy: 1e-5)

        let res = AimLineGeometry.resolve(
            cue: CGPoint(x: CGFloat(cueV.x), y: CGFloat(cueV.z)),
            dir: CGPoint(x: CGFloat(dirV.x), y: CGFloat(dirV.z)),
            target: .zero, ballRadius: R,
            railEnd: CGPoint(x: CGFloat(railV.x), y: CGFloat(railV.z)))
        XCTAssertFalse(res.touchesBall)
        XCTAssertEqual(res.lineEnd.x, CGFloat(expectedX), accuracy: 1e-5)
    }

    // MARK: - 情形 2：垂足红点显隐边界（垂距 R 上下翻转）

    func test_footRedDot_showHideBoundary() {
        let target = CGPoint.zero
        let dir = CGPoint(x: 1, y: 0)
        let rail = CGPoint(x: 1.2, y: 0)

        // 垂距略小于 R ⇒ 触球（显红点）；垂足在 (0, R−ε)。
        let below = AimLineGeometry.resolve(cue: CGPoint(x: -0.5, y: R - 0.001),
                                            dir: dir, target: target, ballRadius: R, railEnd: rail)
        XCTAssertTrue(below.touchesBall, "垂距 < R ⇒ 显示垂足红点")
        XCTAssertEqual(below.aimPoint.y, R - 0.001, accuracy: 1e-9)
        XCTAssertEqual(below.aimPoint.x, 0, accuracy: 1e-9)

        // 垂距略大于 R ⇒ 不触球（隐红点）。
        let above = AimLineGeometry.resolve(cue: CGPoint(x: -0.5, y: R + 0.001),
                                            dir: dir, target: target, ballRadius: R, railEnd: rail)
        XCTAssertFalse(above.touchesBall, "垂距 > R ⇒ 隐藏垂足红点")
        XCTAssertNil(above.contactPoint)
        XCTAssertEqual(above.lineEnd.x, rail.x, accuracy: 1e-9)
    }

    // MARK: - 情形 3：接触点 = 射线与球面第一交点

    func test_contactPoint_firstRaySphereIntersection() {
        // 母球 (-0.5, 0.02)，沿 +x；垂距 0.02 < R ⇒ 触球。
        // 手算：x² + 0.02² = R² ⇒ x = ±sqrt(R²−0.0004)；射线从 x=−0.5 向 +x，
        // 第一交点取近端 x = −sqrt(R²−0.0004)。
        let cue = CGPoint(x: -0.5, y: 0.02)
        let target = CGPoint.zero
        let dir = CGPoint(x: 1, y: 0)
        let rail = CGPoint(x: 1.2, y: 0.02)

        let res = AimLineGeometry.resolve(cue: cue, dir: dir, target: target,
                                          ballRadius: R, railEnd: rail)
        XCTAssertTrue(res.touchesBall)
        let expectedX = -sqrt(R * R - 0.02 * 0.02)   // ≈ −0.020409
        XCTAssertNotNil(res.contactPoint)
        XCTAssertEqual(res.contactPoint!.x, expectedX, accuracy: 1e-6)
        XCTAssertEqual(res.contactPoint!.y, 0.02, accuracy: 1e-6)
        // 触球时白线终点 = 接触点（非库边）。
        XCTAssertEqual(res.lineEnd.x, expectedX, accuracy: 1e-6)
        XCTAssertEqual(res.lineEnd.y, 0.02, accuracy: 1e-6)
        // 接触点在目标球面上：到球心距离 = R。
        let d = hypot(res.contactPoint!.x - target.x, res.contactPoint!.y - target.y)
        XCTAssertEqual(d, R, accuracy: 1e-6)
        // 垂足红点在球内（距球心 = 0.02 < R）。
        let footDist = hypot(res.aimPoint.x - target.x, res.aimPoint.y - target.y)
        XCTAssertEqual(footDist, 0.02, accuracy: 1e-9)
        XCTAssertLessThan(footDist, R)
    }

    /// 目标球在身后（射线反向）时无前向接触点。
    func test_firstRaySphereIntersection_targetBehind_returnsNil() {
        let hit = AimLineGeometry.firstRaySphereIntersection(
            origin: CGPoint(x: 0.5, y: 0.0), dir: CGPoint(x: 1, y: 0),
            center: .zero, radius: R)
        XCTAssertNil(hit, "目标球在身后 ⇒ 无前向交点")
    }
}
