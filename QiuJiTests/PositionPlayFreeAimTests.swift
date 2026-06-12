//
//  PositionPlayFreeAimTests.swift
//  QiuJiTests
//
//  走位编排台自由瞄准模式（ADR-P11-03）：坐标契约数值验证 + 自由球直瞄模拟不变量。
//
//  坐标契约（代码真源 `AngleSceneCalculator`，已与 table-geometry.md 交叉核对并以代码为准）：
//  canvasX 增 = sceneX 增；canvasY 增 = sceneZ 增；innerLength = 2×innerWidth ⇒ 方向向量
//  在两系间为均匀缩放且符号保持。
//

import XCTest
import SceneKit
@testable import QiuJi

final class PositionPlayFreeAimTests: XCTestCase {

    private let sY = BTTablePhysics.surfaceY
    private var R: Float { AngleSceneCalculator.ballRadius }

    // MARK: - 坐标契约（金标准样例，禁止脑算 → 数值验证）

    func test_canvasSceneDirectionContract() {
        // 金标准 1：canvas +x（向右）↔ scene +X。
        let right = PositionPlayShotSolver.sceneDirection(fromCanvas: CanvasPoint(x: 1, y: 0))
        XCTAssertEqual(right.x, 1, accuracy: 1e-5)
        XCTAssertEqual(right.z, 0, accuracy: 1e-5)

        // 金标准 2：canvas +y ↔ scene +Z（代码真源 sceneToNormalized：ny 随 z 增）。
        let down = PositionPlayShotSolver.sceneDirection(fromCanvas: CanvasPoint(x: 0, y: 1))
        XCTAssertEqual(down.x, 0, accuracy: 1e-5)
        XCTAssertEqual(down.z, 1, accuracy: 1e-5)

        // 金标准 3：与位置转换函数自洽——canvas 点 (0.5,0.25)→(0.75,0.375) 的位移方向
        // 应等于 sceneDirection(canvas(0.25,0.125)·norm)。
        let a = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: 0.5, y: 0.25), surfaceY: sY)
        let b = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: 0.75, y: 0.375), surfaceY: sY)
        let dispLen = sqrtf(powf(b.x - a.x, 2) + powf(b.z - a.z, 2))
        let dispDir = SCNVector3((b.x - a.x) / dispLen, 0, (b.z - a.z) / dispLen)
        let viaContract = PositionPlayShotSolver.sceneDirection(fromCanvas: CanvasPoint(x: 0.25, y: 0.125))
        XCTAssertEqual(dispDir.x, viaContract.x, accuracy: 1e-4)
        XCTAssertEqual(dispDir.z, viaContract.z, accuracy: 1e-4)

        // 往返：scene → canvas → scene 不变。
        let dir = SCNVector3(0.6, 0, -0.8)
        let roundTrip = PositionPlayShotSolver.sceneDirection(
            fromCanvas: PositionPlayShotSolver.canvasDirection(fromScene: dir)
        )
        XCTAssertEqual(roundTrip.x, 0.6, accuracy: 1e-4)
        XCTAssertEqual(roundTrip.z, -0.8, accuracy: 1e-4)
    }

    // MARK: - 自由球直瞄模拟不变量

    func test_simulateFree_followsAimDirection_andStaysInBounds() {
        // 母球在台心，朝 +X 中速中心球：起始段应沿 +X，全部终位不出界。
        let pred = ShotPredictor.simulateFree(
            cueBall: SCNVector3(0, sY + R, 0),
            aimDir: SCNVector3(1, 0, 0),
            velocity: 2.0, spinX: 0, spinY: 0,
            surfaceY: sY, balls: []
        )
        XCTAssertTrue(pred.feasible)
        XCTAssertGreaterThanOrEqual(pred.cuePath.count, 2, "应有母球轨迹")

        let p0 = pred.cuePath[0], p1 = pred.cuePath[1]
        let dx = p1.x - p0.x, dz = p1.z - p0.z
        let len = sqrtf(dx * dx + dz * dz)
        XCTAssertGreaterThan(len, 0.001)
        XCTAssertGreaterThan(dx / len, 0.99, "起始段应沿 +X 方向")

        let halfL = AngleSceneCalculator.innerLength / 2 + 0.1
        let halfW = AngleSceneCalculator.innerWidth / 2 + 0.1
        for (_, p) in pred.finalPositions {
            XCTAssertLessThanOrEqual(abs(p.x), halfL, "终位不出界（含袋口余量）")
            XCTAssertLessThanOrEqual(abs(p.z), halfW, "终位不出界（含袋口余量）")
        }
    }

    func test_simulateFree_movesBlockingBall() {
        // 正前方 0.3m 摆一颗障碍球，直瞄击打应把它撞开。
        let blockerStart = SCNVector3(0.3, sY + R, 0)
        let pred = ShotPredictor.simulateFree(
            cueBall: SCNVector3(0, sY + R, 0),
            aimDir: SCNVector3(1, 0, 0),
            velocity: 2.5, spinX: 0, spinY: 0,
            surfaceY: sY,
            balls: [ObstacleBall(name: "_5", position: blockerStart)]
        )
        let final5 = pred.finalPositions["_5"]
        XCTAssertNotNil(final5, "被撞球应有终位")
        if let f = final5 {
            let moved = sqrtf(powf(f.x - blockerStart.x, 2) + powf(f.z - blockerStart.z, 2))
            XCTAssertGreaterThan(moved, 0.05, "正面直击应使障碍球明显位移")
        }
        XCTAssertNotNil(pred.firstContact, "应发生球-球碰撞")
        XCTAssertFalse(pred.extraBallPaths.isEmpty, "被带动的球应有轨迹折线")
    }

    // MARK: - 求解器分发 + 模型兼容

    func test_solver_freeShot_endToEnd() {
        let before = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.3, y: 0.25),
            "_3": CanvasPoint(x: 0.6, y: 0.25)
        ])
        let shot = PlannedShot(targetKey: "", pocket: "", velocity: 2.2,
                               freeAim: CanvasPoint(x: 1, y: 0))
        let pred = PositionPlayShotSolver.solve(before: before, shot: shot, surfaceY: sY)
        XCTAssertNotNil(pred)
        XCTAssertTrue(pred?.feasible ?? false, "自由球恒可行")
        XCTAssertGreaterThanOrEqual(pred?.cuePath.count ?? 0, 2)
        // 母球朝 +x 直打 0.3m 外同高度的 _3：应发生碰撞并带动它。
        XCTAssertNotNil(pred?.firstContact, "应碰到 _3")
    }

    // MARK: - 球桌外框实测（#3 取景契约：禁止脑算，量出 USDZ 外框）

    @MainActor
    func test_diag_tableOuterBounds() {
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        guard let table = scene.tableNode else { return XCTFail("无球桌节点") }
        var minV = SCNVector3(Float.greatestFiniteMagnitude, .greatestFiniteMagnitude, .greatestFiniteMagnitude)
        var maxV = SCNVector3(-Float.greatestFiniteMagnitude, -.greatestFiniteMagnitude, -.greatestFiniteMagnitude)
        table.enumerateHierarchy { node, _ in
            guard node.geometry != nil else { return }
            let (bMin, bMax) = node.boundingBox
            for corner in [SCNVector3(bMin.x, bMin.y, bMin.z), SCNVector3(bMax.x, bMin.y, bMin.z),
                           SCNVector3(bMin.x, bMin.y, bMax.z), SCNVector3(bMax.x, bMin.y, bMax.z),
                           SCNVector3(bMin.x, bMax.y, bMin.z), SCNVector3(bMax.x, bMax.y, bMin.z),
                           SCNVector3(bMin.x, bMax.y, bMax.z), SCNVector3(bMax.x, bMax.y, bMax.z)] {
                let w = node.convertPosition(corner, to: nil)
                minV = SCNVector3(min(minV.x, w.x), min(minV.y, w.y), min(minV.z, w.z))
                maxV = SCNVector3(max(maxV.x, w.x), max(maxV.y, w.y), max(maxV.z, w.z))
            }
        }
        print(String(format: "TABLE-BBOX x:[%.4f, %.4f] z:[%.4f, %.4f] (innerL/2=%.4f innerW/2=%.4f)",
                     minV.x, maxV.x, minV.z, maxV.z,
                     AngleSceneCalculator.innerLength / 2, AngleSceneCalculator.innerWidth / 2))
        // 取景契约（ADR-P11-08）：rig 实测外框半长/半宽应与场景包围盒一致，
        // 且自适应取景在任意竖屏视口下完整覆盖球桌双轴。
        guard let rig = scene.cameraRig else { return XCTFail("无相机 rig") }
        XCTAssertEqual(rig.tableOuterHalfLength, Double(max(abs(minV.x), abs(maxV.x))),
                       accuracy: 0.001, "rig 回填的外框半长与实测不一致")
        XCTAssertEqual(rig.tableOuterHalfWidth, Double(max(abs(minV.z), abs(maxV.z))),
                       accuracy: 0.001, "rig 回填的外框半宽与实测不一致")
        for size in [CGSize(width: 393, height: 700), CGSize(width: 393, height: 540),
                     CGSize(width: 320, height: 480), CGSize(width: 430, height: 800)] {
            rig.fitRotatedTable(viewSize: size)
            let halfV = rig.topDownOrthographicScale
            let halfH = rig.topDownOrthographicScale * Double(size.width / size.height)
            XCTAssertGreaterThanOrEqual(halfV, rig.tableOuterHalfLength, "竖轴未覆盖外框 \(size)")
            XCTAssertGreaterThanOrEqual(halfH, rig.tableOuterHalfWidth, "横轴未覆盖外框 \(size)")
        }
    }

    // MARK: - 障碍球遮挡判定（自动选袋几何闸，金标准样例）

    func test_isPathBlocked_goldenSamples() {
        // 路径：(0,0)→(1,0) 沿 +X，水平面 X–Z。2R = 0.05715。
        let from = SCNVector3(0, sY + R, 0)
        let to = SCNVector3(1, sY + R, 0)

        // 金标准 1：路径中点旁 z=0.03 < 2R ⇒ 挡。
        XCTAssertTrue(AngleSceneCalculator.isPathBlocked(
            from: from, to: to,
            obstacles: [SCNVector3(0.5, sY + R, 0.03)]
        ))
        // 金标准 2：z=0.06 > 2R ⇒ 不挡（刚好能擦过）。
        XCTAssertFalse(AngleSceneCalculator.isPathBlocked(
            from: from, to: to,
            obstacles: [SCNVector3(0.5, sY + R, 0.06)]
        ))
        // 金标准 3：障碍在线段延长线外（x=1.5）⇒ 投影钳到端点，距离 0.5 ⇒ 不挡。
        XCTAssertFalse(AngleSceneCalculator.isPathBlocked(
            from: from, to: to,
            obstacles: [SCNVector3(1.5, sY + R, 0)]
        ))
        // 金标准 4：贴端点（x=1.03, z=0）距端点 0.03 < 2R ⇒ 挡（保守闸）。
        XCTAssertTrue(AngleSceneCalculator.isPathBlocked(
            from: from, to: to,
            obstacles: [SCNVector3(1.03, sY + R, 0)]
        ))
        // 金标准 5：无障碍 ⇒ 不挡。
        XCTAssertFalse(AngleSceneCalculator.isPathBlocked(from: from, to: to, obstacles: []))
    }

    func test_plannedShot_codable_backwardCompatible() throws {
        // 旧数据（无 freeAim 字段）应能解码且 isFree == false。
        let legacy = #"{"targetKey":"_1","pocket":"topRight","velocity":3.3,"spinX":0,"spinY":0}"#
        let decoded = try JSONDecoder().decode(PlannedShot.self, from: Data(legacy.utf8))
        XCTAssertFalse(decoded.isFree)
        XCTAssertEqual(decoded.targetKey, "_1")

        // 新自由球往返编解码。
        let free = PlannedShot(targetKey: "", pocket: "", velocity: 1.0,
                               freeAim: CanvasPoint(x: 0.6, y: -0.8))
        let data = try JSONEncoder().encode(free)
        let back = try JSONDecoder().decode(PlannedShot.self, from: data)
        XCTAssertTrue(back.isFree)
        XCTAssertEqual(back.freeAim?.x ?? 0, 0.6, accuracy: 1e-9)
    }
}
