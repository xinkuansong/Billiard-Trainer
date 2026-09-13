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

    // MARK: - G13 瞄准拖动相对旋转语义（问题集合 v5 · V1）

    /// 屏幕点：绕轴心 `c`、半径 `r`、屏幕方位角 `degFromScreenRightCW`（+x 轴起、y 朝下顺时针为正）。
    private func screenPoint(around c: CGPoint, radius: CGFloat, deg: Double) -> CGPoint {
        let t = deg * .pi / 180
        return CGPoint(x: c.x + radius * CGFloat(cos(t)), y: c.y + radius * CGFloat(sin(t)))
    }

    /// 金标准：手指绕母球公转 Δ° ⇒ 瞄准相对旋转 Δ°（屏幕顺时针为正），远杠杆区增益 1:1。
    func test_aimNudge_relativeRotation_goldenAngles() {
        let cue = CGPoint(x: 200, y: 300)
        let r: CGFloat = 200   // > minLever(≈95.5) ⇒ 无衰减，公转角 == 旋转角

        // 起手在正上方（-90°）。顺时针公转 +15° ⇒ +15°。
        let up = screenPoint(around: cue, radius: r, deg: -90)
        let cw = screenPoint(around: cue, radius: r, deg: -75)
        XCTAssertEqual(AngleSceneCalculator.aimNudgeDegrees(cueScreen: cue, from: up, to: cw),
                       15, accuracy: 0.05, "顺时针公转 15° 应产生 +15° 相对旋转")

        // 逆时针公转 -15° ⇒ -15°。
        let ccw = screenPoint(around: cue, radius: r, deg: -105)
        XCTAssertEqual(AngleSceneCalculator.aimNudgeDegrees(cueScreen: cue, from: up, to: ccw),
                       -15, accuracy: 0.05, "逆时针公转 15° 应产生 -15° 相对旋转")

        // 径向拖动（沿同一射线远离母球）⇒ 不旋转。
        let radialOut = screenPoint(around: cue, radius: r + 60, deg: -90)
        XCTAssertEqual(AngleSceneCalculator.aimNudgeDegrees(cueScreen: cue, from: up, to: radialOut),
                       0, accuracy: 1e-4, "径向拖动不应改变瞄准方向")
    }

    /// 近母球杠杆封顶：半径 < minLever 时角位移按 r/minLever 线性衰减（避免发散）。
    func test_aimNudge_leverAttenuationNearCue() {
        let cue = CGPoint(x: 200, y: 300)
        let r: CGFloat = 50   // < minLever(≈95.493)
        let minLever = 180.0 / Double.pi / 0.6
        let atten = Double(r) / minLever
        let up = screenPoint(around: cue, radius: r, deg: -90)
        let cw = screenPoint(around: cue, radius: r, deg: -70)   // 顺时针公转 +20°
        let expected = 20 * atten
        XCTAssertEqual(Double(AngleSceneCalculator.aimNudgeDegrees(cueScreen: cue, from: up, to: cw)),
                       expected, accuracy: 0.05, "近母球处 20° 公转应衰减到 \(expected)°")
        XCTAssertLessThan(expected, 20, "衰减后应小于原始公转角")
    }

    /// 相对旋转端到端：给定拖动增量 → `rotatedAim` 后 bearing 变化量 == 该增量（屏幕顺时针为正）。
    func test_aimNudge_appliedViaRotatedAim_matchesBearingDelta() {
        let cue = CGPoint(x: 200, y: 300)
        let r: CGFloat = 220
        let from = screenPoint(around: cue, radius: r, deg: -90)
        let to = screenPoint(around: cue, radius: r, deg: -60)   // +30° 顺时针
        let delta = AngleSceneCalculator.aimNudgeDegrees(cueScreen: cue, from: from, to: to)
        XCTAssertEqual(delta, 30, accuracy: 0.1)

        // 当前瞄准 +X（bearing 0） → 旋转 delta → bearing 应恰好增加 delta。
        let base = SCNVector3(1, 0, 0)
        let rotated = AngleSceneCalculator.rotatedAim(base, byDegrees: delta)
        let b0 = AngleSceneCalculator.bearingDeg(of: base)
        let b1 = AngleSceneCalculator.bearingDeg(of: rotated)
        XCTAssertEqual(b1 - b0, delta, accuracy: 0.1, "bearing 变化量应等于拖动相对增量")
    }

    // MARK: - G14 求解触发去抖时序（拖动不求解、停 0.5s 触发）

    @MainActor
    func test_solveDebounce_dragSuppressesUntilIdle() {
        let sched = SolveDebounceScheduler(idleInterval: 0.5, fastInterval: 0.02)
        var captured: [(delay: TimeInterval, work: DispatchWorkItem)] = []
        sched.scheduleAfter = { delay, work in captured.append((delay, work)) }
        var fireCount = 0

        // 模拟一次连续拖动：5 次交互输入。
        for _ in 0..<5 { sched.schedule(interactive: true) { fireCount += 1 } }

        // 拖动过程中：绝不触发求解。
        XCTAssertEqual(fireCount, 0, "拖动中不应触发求解")
        // 交互态一律用 idle 间隔排程。
        XCTAssertEqual(sched.lastScheduledDelay ?? -1, 0.5, accuracy: 1e-9)
        // 前 4 次已被后续输入取消，只剩最后一次待跑。
        XCTAssertEqual(captured.count, 5)
        for i in 0..<4 { XCTAssertTrue(captured[i].work.isCancelled, "第 \(i) 次待跑应被取消") }
        XCTAssertFalse(captured[4].work.isCancelled, "最后一次待跑应存活")
        XCTAssertTrue(sched.hasPending)

        // 停止输入满 idleInterval：最后一次 work 触发一次求解。
        captured[4].work.perform()
        XCTAssertEqual(fireCount, 1, "停 0.5s（无新输入）后只触发一次求解")
    }

    @MainActor
    func test_solveDebounce_discreteUsesFastInterval() {
        let sched = SolveDebounceScheduler(idleInterval: 0.5, fastInterval: 0.02)
        var lastDelay: TimeInterval?
        sched.scheduleAfter = { delay, _ in lastDelay = delay }
        sched.schedule(interactive: false) { }
        XCTAssertEqual(lastDelay ?? -1, 0.02, accuracy: 1e-9, "离散变更应走快速去抖间隔")
        sched.schedule(interactive: true) { }
        XCTAssertEqual(lastDelay ?? -1, 0.5, accuracy: 1e-9, "交互变更应走 idle 去抖间隔")
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

@MainActor
final class IdealDirectionIntegrationTests: XCTestCase {
    private var previousDetail: TrajectoryDetail = .full
    override func setUp() {
        super.setUp()
        previousDetail = UserPreferences.shared.trajectoryDetail
        UserPreferences.shared.trajectoryDetail = .full
    }
    override func tearDown() {
        UserPreferences.shared.trajectoryDetail = previousDetail
        super.tearDown()
    }
    func testAimPointExercisesNeverExposeIdealDirection() throws {
        let suite = "v61.exercise." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = AimPointSceneQuizViewModel(limiter: AngleUsageLimiter(defaults: defaults))
        for mode in [AngleTrainingScene.CameraMode.topDown2DRotated, .perspective3D] {
            vm.setupScene(cameraMode: mode)
            vm.setAimWheelDragging(true)
            XCTAssertNil(vm.scene.idealObjectLine)
            XCTAssertNil(vm.closeupSnapshot?.idealLine)
            vm.setAimWheelDragging(false)
        }
    }

    func testMinimalDetailOmitsIdealLayer() {
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        UserPreferences.shared.trajectoryDetail = .minimal
        XCTAssertNil(scene.setIdealObjectLine(.init(start: .zero, end: CGPoint(x: 1, y: 0)), detail: .minimal))
        XCTAssertNil(scene.idealObjectLine)
    }

    func testPositionPlayPreviewUpdatesAndIsReplacedByPrediction() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.aimMode = .free
        let target = try XCTUnwrap(vm.scene.allBallNodes["_1"])
        vm.handleTableTap(world: target.position)
        vm.setAimWheelDragging(true)
        vm.nudgeFreeAim(byDegrees: 0.2)
        let first = try XCTUnwrap(vm.scene.idealObjectLine)
        XCTAssertNotNil(vm.closeupSnapshot?.idealLine)
        vm.nudgeFreeAim(byDegrees: 0.2)
        XCTAssertNotEqual(vm.scene.idealObjectLine, first)
        // No UI gesture or loupe is needed to keep the main-scene feedback alive.
        vm.setAimWheelDragging(false)
        let deadline = Date().addingTimeInterval(15)
        while vm.scene.idealObjectLine != nil, Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertNil(vm.scene.idealObjectLine, "Latest physical prediction replaces the geometric line")
        vm.nudgeFreeAim(byDegrees: -0.2)
        XCTAssertNotNil(vm.scene.idealObjectLine)
        vm.aimMode = .pocket
        XCTAssertNil(vm.scene.idealObjectLine)
    }

    func testPreviewParameterBoardAndBreakTransitions() throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.aimMode = .free
        let target = try XCTUnwrap(vm.scene.allBallNodes["_1"])
        vm.handleTableTap(world: target.position)
        let original = try XCTUnwrap(vm.scene.idealObjectLine)
        vm.velocity = 2.4
        vm.spinX = 0.3
        vm.spinY = -0.4
        XCTAssertEqual(vm.scene.idealObjectLine, original, "Power and spin must not change collision-normal geometry")
        let position = target.position
        vm.dragMoved(node: target, worldPosition: SCNVector3(position.x + 0.01, position.y, position.z))
        XCTAssertNotEqual(vm.scene.idealObjectLine, original)
        vm.removeFromTable("_1")
        XCTAssertNil(vm.scene.idealObjectLine)
        vm.placeFromPalette("_1", atWorld: position)
        vm.handleTableTap(world: target.position)
        XCTAssertNotNil(vm.scene.idealObjectLine)
        vm.startBreakFlow(game: .nineBall, seed: 61)
        XCTAssertNil(vm.scene.idealObjectLine)
        vm.cancelBreakFlow()
        vm.handleTableTap(world: target.position)
        XCTAssertNotNil(vm.scene.idealObjectLine)
        vm.clearTable()
        XCTAssertNil(vm.scene.idealObjectLine)
    }

    func testSolversClearIdealLayerOnModeChange() {
        let bank = BankShotViewModel()
        bank.setupScene()
        bank.toggleMode()
        for _ in 0..<360 where bank.scene.idealObjectLine == nil { bank.nudgeFreeAim(byDegrees: 1) }
        XCTAssertNotNil(bank.scene.idealObjectLine)
        bank.toggleMode()
        XCTAssertNil(bank.scene.idealObjectLine)

        let diamond = DiamondSystemViewModel()
        diamond.setupScene()
        diamond.toggleMode()
        for _ in 0..<360 where diamond.scene.idealObjectLine == nil { diamond.nudgeFreeAim(byDegrees: 1) }
        XCTAssertNotNil(diamond.scene.idealObjectLine)
        diamond.toggleMode()
        XCTAssertNil(diamond.scene.idealObjectLine)
    }

    func testSharedLayerClearsWithVisualization() {
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        let line = IdealObjectDirection.preview(target: .zero, ghost: CGPoint(x: -1, y: 0))?.line
        let node = scene.setIdealObjectLine(line)
        XCTAssertNotNil(node?.parent)
        scene.hideAllVisualization()
        XCTAssertNil(node?.parent)
        XCTAssertNil(scene.idealObjectLine)
    }
}

@MainActor
final class ShotSimulationCameraTests: XCTestCase {
    func testRecordedComposerDraftSurvivesPerspectiveRoundTrip() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 375, height: 480))
        view.scene = vm.scene
        view.pointOfView = vm.scene.cameraNode
        vm.scene.cameraRig?.viewportSize = view.bounds.size
        let window = UIWindow(windowScene: try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene))
        let controller = UIViewController()
        controller.view = view
        window.rootViewController = controller
        window.makeKeyAndVisible()
        view.isPlaying = true
        defer { view.isPlaying = false; window.isHidden = true }
        vm.toggleAimMode()
        vm.velocity = 0.6
        let ready = Date().addingTimeInterval(30)
        while vm.isComputing, Date() < ready {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(vm.isComputing)
        XCTAssertNotNil(vm.solvedShot)
        vm.startRecording()
        vm.renameSequence("v63 编辑草稿")
        vm.play()
        let finished = Date().addingTimeInterval(45)
        while vm.isPlaying, Date() < finished {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(vm.isPlaying)
        XCTAssertEqual(vm.sequence.steps.count, 1)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let draft = try encoder.encode(vm.sequence)
        let board = try encoder.encode(vm.currentSnapshot())
        let target = vm.selectedTargetKey
        let pocket = vm.selectedPocketIndex
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        for _ in 0..<3 {
            ShotPlayCamera.setMode(.perspective3D, on: vm)
            XCTAssertTrue(rig.observeWholeTable())
            rig.handleHorizontalSwipe(delta: 40)
            rig.update(deltaTime: 1)
            ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
            XCTAssertTrue(vm.isRecording)
            XCTAssertEqual(try encoder.encode(vm.sequence), draft)
            XCTAssertEqual(try encoder.encode(vm.currentSnapshot()), board)
            XCTAssertEqual(vm.selectedTargetKey, target)
            XCTAssertEqual(vm.selectedPocketIndex, pocket)
        }
        let recorded = try XCTUnwrap(vm.stopRecording())
        XCTAssertEqual(try encoder.encode(recorded), draft)
    }

    func testViewSwitchAndOrbitPreserveShotAndBoard() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        let editedBall = try XCTUnwrap(vm.scene.allBallNodes["_1"])
        let originalPosition = editedBall.position
        // World X/Z table plane, Y up, metres: exercise an actual edit first.
        vm.dragBegan(node: editedBall)
        vm.dragMoved(node: editedBall, worldPosition: SCNVector3(
            originalPosition.x + 0.03, originalPosition.y, originalPosition.z))
        vm.dragEnded(node: editedBall)
        XCTAssertNotEqual(editedBall.position.x, originalPosition.x)
        vm.selectTarget(node: editedBall)
        vm.selectPocket(at: 2)
        vm.toggleAimMode()
        vm.velocity = 2.4
        vm.spinX = 0.2
        vm.spinY = -0.3
        let deadline = Date().addingTimeInterval(20)
        while vm.isComputing, Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(vm.isComputing)
        let prediction = try XCTUnwrap(vm.solvedShot).prediction
        let direction = try XCTUnwrap(vm.freeAimDir)
        let balls = vm.scene.allBallNodes.mapValues { $0.position }
        let target = vm.selectedTargetKey
        let pocket = vm.selectedPocketIndex
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        for _ in 0..<3 {
            ShotPlayCamera.setMode(.perspective3D, on: vm)
            XCTAssertFalse(try XCTUnwrap(vm.scene.cameraNode.camera).usesOrthographicProjection)
            let yaw = rig.currentYaw
            rig.handleHorizontalSwipe(delta: 50)
            rig.handleVerticalSwipe(delta: 30)
            rig.update(deltaTime: 1)
            XCTAssertNotEqual(rig.currentYaw, yaw)
            ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
            XCTAssertTrue(try XCTUnwrap(vm.scene.cameraNode.camera).usesOrthographicProjection)
        }
        let afterDirection = try XCTUnwrap(vm.freeAimDir)
        XCTAssertEqual(afterDirection.x, direction.x)
        XCTAssertEqual(afterDirection.y, direction.y)
        XCTAssertEqual(afterDirection.z, direction.z)
        XCTAssertEqual(vm.selectedTargetKey, target)
        XCTAssertEqual(vm.selectedPocketIndex, pocket)
        XCTAssertEqual(vm.velocity, 2.4)
        XCTAssertEqual(vm.spinX, 0.2)
        XCTAssertEqual(vm.spinY, -0.3)
        let afterPath = try XCTUnwrap(vm.solvedShot).prediction.cuePath
        XCTAssertEqual(afterPath.map { [$0.x, $0.y, $0.z] }, prediction.cuePath.map { [$0.x, $0.y, $0.z] })
        XCTAssertEqual(vm.scene.allBallNodes.mapValues { [$0.position.x, $0.position.y, $0.position.z] },
                       balls.mapValues { [$0.x, $0.y, $0.z] })
        XCTAssertFalse(vm.isPlaying)
        XCTAssertFalse(vm.canReplay)
    }
}


@MainActor
final class CameraModeInterruptionV63Tests: XCTestCase {
    func testInterruptedTopDownCannotOverwriteLatestPerspective() async throws {
        let scene = AngleTrainingScene()
        scene.setupScene()
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 402, height: 600))
        view.scene = scene
        view.pointOfView = scene.cameraNode
        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: windowScene)
        let controller = UIViewController()
        controller.view = view
        window.rootViewController = controller
        window.makeKeyAndVisible()
        view.isPlaying = true
        defer { view.isPlaying = false; window.isHidden = true }
        scene.setCameraMode(.perspective3D, animated: false)
        scene.setCameraMode(.topDown2DRotated, animated: true)
        SCNTransaction.flush()
        try await Task.sleep(for: .milliseconds(100))
        scene.setCameraMode(.perspective3D, animated: false)
        _ = view.snapshot()
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(scene.currentCameraMode, .perspective3D)
        XCTAssertFalse(try XCTUnwrap(scene.cameraNode.camera).usesOrthographicProjection)
        XCTAssertFalse(scene.isCameraModeTransitioning)
    }

    func testInterruptedPerspectiveCannotOverwriteLatestTopDown() async throws {
        let scene = AngleTrainingScene()
        scene.setupScene()
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 402, height: 600))
        view.scene = scene
        view.pointOfView = scene.cameraNode
        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: windowScene)
        let controller = UIViewController()
        controller.view = view
        window.rootViewController = controller
        window.makeKeyAndVisible()
        view.isPlaying = true
        defer { view.isPlaying = false; window.isHidden = true }
        scene.setCameraMode(.topDown2DRotated, animated: false)
        scene.setCameraMode(.perspective3D, animated: true)
        SCNTransaction.flush()
        try await Task.sleep(for: .milliseconds(100))
        scene.setCameraMode(.topDown2DRotated, animated: false)
        _ = view.snapshot()
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(scene.currentCameraMode, .topDown2DRotated)
        XCTAssertTrue(try XCTUnwrap(scene.cameraNode.camera).usesOrthographicProjection)
        XCTAssertFalse(scene.isCameraModeTransitioning)
    }
}


@MainActor
final class PerspectiveStateV63Tests: XCTestCase {
    func testRestorePreservesPendingDampingAndNextFrame() throws {
        let node = SCNNode()
        node.camera = SCNCamera()
        let rig = CameraRig(cameraNode: node, tableSurfaceY: 0.8)
        rig.handleHorizontalSwipe(delta: 120)
        rig.handleVerticalSwipe(delta: 30)
        rig.update(deltaTime: 1.0 / 60)
        let saved = rig.capturePerspectiveState()
        let position = node.position
        let yaw = rig.currentYaw
        rig.update(deltaTime: 1.0 / 60)
        let nextPosition = node.position
        let nextYaw = rig.currentYaw
        rig.applyTopDown2DRotated()
        rig.restorePerspectiveState(saved)
        XCTAssertEqual(node.position.x, position.x, accuracy: 1e-6)
        XCTAssertEqual(node.position.y, position.y, accuracy: 1e-6)
        XCTAssertEqual(node.position.z, position.z, accuracy: 1e-6)
        XCTAssertEqual(rig.currentYaw, yaw)
        XCTAssertTrue(rig.hasPendingDamping)
        rig.update(deltaTime: 1.0 / 60)
        XCTAssertEqual(node.position.x, nextPosition.x, accuracy: 1e-6)
        XCTAssertEqual(node.position.y, nextPosition.y, accuracy: 1e-6)
        XCTAssertEqual(node.position.z, nextPosition.z, accuracy: 1e-6)
        XCTAssertEqual(rig.currentYaw, nextYaw)
    }

    func testPilotRoundTripRestoresObservationInsteadOfRefocusing() throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.handleHorizontalSwipe(delta: 180)
        rig.handleVerticalSwipe(delta: 40)
        rig.snapToTarget()
        let position = vm.scene.cameraNode.position
        let yaw = rig.currentYaw
        let zoom = rig.zoom
        for _ in 0..<3 {
            ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
            ShotPlayCamera.setMode(.perspective3D, on: vm)
            XCTAssertEqual(rig.currentYaw, yaw)
            XCTAssertEqual(rig.zoom, zoom)
            XCTAssertEqual(vm.scene.cameraNode.position.x, position.x, accuracy: 1e-6)
            XCTAssertEqual(vm.scene.cameraNode.position.z, position.z, accuracy: 1e-6)
        }
    }
    private func readyFreeBoard() async throws -> PositionPlayViewModel {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.toggleAimMode()
        let deadline = Date().addingTimeInterval(20)
        while vm.isComputing, Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertFalse(vm.isComputing)
        XCTAssertNotNil(vm.solvedShot)
        return vm
    }

    func testExplicitFocusReplacesSavedObservation() async throws {
        let vm = try await readyFreeBoard()
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.handleHorizontalSwipe(delta: 200)
        rig.snapToTarget()
        let observedYaw = rig.currentYaw
        ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
        ShotPlayCamera.focus(on: vm)
        rig.update(deltaTime: 1)
        let focusedYaw = rig.currentYaw
        XCTAssertNotEqual(focusedYaw, observedYaw)
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        XCTAssertEqual(rig.currentYaw, focusedYaw, accuracy: 1e-5)
        rig.handleHorizontalSwipe(delta: 80)
        rig.snapToTarget()
        let newObservedYaw = rig.currentYaw
        ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        XCTAssertEqual(rig.currentYaw, newObservedYaw, accuracy: 1e-5)
    }

    func testNewBoardInvalidatesOldViewButIgnoredEmptyLoadDoesNot() async throws {
        let vm = try await readyFreeBoard()
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        vm.loadBoard(BoardSnapshot(onTable: [:]))
        XCTAssertTrue(vm.scene.hasPerspectiveView)
        ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
        vm.loadBoard(BoardSnapshot(onTable: [
            "cueBall": CanvasPoint(x: 0.2, y: 0.2),
            "_1": CanvasPoint(x: 0.7, y: 0.25)
        ]))
        XCTAssertFalse(vm.scene.hasPerspectiveView)
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        XCTAssertEqual(rig.currentPivot.x, cue.position.x, accuracy: 1e-5)
        XCTAssertEqual(rig.currentPivot.z, cue.position.z, accuracy: 1e-5)
    }

    func testSwitchDuringStrokePreservesActiveShot() async throws {
        let vm = try await readyFreeBoard()
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        let prediction = try XCTUnwrap(vm.solvedShot).prediction
        vm.play()
        XCTAssertTrue(vm.isPlaying)
        let status = vm.statusText
        let positions = vm.scene.allBallNodes.mapValues { [$0.position.x, $0.position.y, $0.position.z] }
        for _ in 0..<3 {
            ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
            ShotPlayCamera.setMode(.perspective3D, on: vm)
        }
        XCTAssertTrue(vm.isPlaying)
        XCTAssertEqual(vm.statusText, status)
        XCTAssertEqual(vm.scene.allBallNodes.mapValues { [$0.position.x, $0.position.y, $0.position.z] }, positions)
        XCTAssertEqual(try XCTUnwrap(vm.solvedShot).prediction.cuePath.map { [$0.x, $0.y, $0.z] },
                       prediction.cuePath.map { [$0.x, $0.y, $0.z] })
        XCTAssertFalse(vm.canReplay)
    }

    func testSequencePreparationKeepsStepAndIntentAcrossModes() throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        let board = BoardSnapshot(onTable: ["cueBall": CanvasPoint(x: 0.3, y: 0.2)])
        let shot = PlannedShot(targetKey: "", pocket: "", velocity: 1.5,
                               freeAim: CanvasPoint(x: 1, y: 0))
        vm.configureSequence([SequenceStep(before: board, shot: shot, after: board)])
        vm.enterSequenceMode()
        XCTAssertTrue(vm.isSequenceMode)
        let index = vm.sequenceStepIndex
        let positions = vm.scene.allBallNodes.mapValues { [$0.position.x, $0.position.y, $0.position.z] }
        let direction = try XCTUnwrap(vm.freeAimDir)
        for _ in 0..<3 {
            ShotPlayCamera.setMode(.perspective3D, on: vm)
            ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
        }
        XCTAssertTrue(vm.isSequenceMode)
        XCTAssertFalse(vm.isSequencePlaying)
        XCTAssertEqual(vm.sequenceStepIndex, index)
        XCTAssertFalse(vm.sequenceFinished)
        XCTAssertEqual(vm.velocity, shot.velocity)
        XCTAssertEqual(try XCTUnwrap(vm.freeAimDir).x, direction.x)
        XCTAssertEqual(try XCTUnwrap(vm.freeAimDir).z, direction.z)
        XCTAssertEqual(vm.scene.allBallNodes.mapValues { [$0.position.x, $0.position.y, $0.position.z] }, positions)
    }

    func testQuizSubmittedAnswerAndScoreSurviveSharedCameraSwitch() throws {
        let suite = "PerspectiveStateV63Tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults)
        limiter.isPremium = true
        let vm = AimingQuizViewModel(limiter: limiter)
        vm.setupScene(initialCameraMode: .perspective3D)
        vm.userInput = "30"
        vm.submitAnswer()
        let answer = try XCTUnwrap(vm.sessionResults.last)
        let question = try XCTUnwrap(vm.currentQuestion)
        let index = vm.questionIndex
        for _ in 0..<3 {
            vm.scene.setCameraMode(.topDown2DRotated, animated: false)
            vm.scene.setCameraMode(.perspective3D, animated: false)
        }
        XCTAssertEqual(vm.questionIndex, index)
        XCTAssertEqual(vm.userInput, "30")
        XCTAssertEqual(try XCTUnwrap(vm.currentQuestion).cueBall, question.cueBall)
        XCTAssertEqual(try XCTUnwrap(vm.currentQuestion).targetBall, question.targetBall)
        XCTAssertEqual(try XCTUnwrap(vm.sessionResults.last).userAngle, answer.userAngle)
        XCTAssertEqual(try XCTUnwrap(vm.sessionResults.last).error, answer.error)
        XCTAssertEqual(vm.sessionResults.count, 1)
    }

    func testClearResetAndBreakDiscardPreviousViewContext() async throws {
        let vm = try await readyFreeBoard()
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        vm.clearTable()
        XCTAssertFalse(vm.scene.hasPerspectiveView)
        ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        vm.resetAll()
        XCTAssertFalse(vm.scene.hasPerspectiveView)
        ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        vm.startBreakFlow(game: .chineseEightBall, seed: 63)
        XCTAssertNotNil(vm.breakRunner)
        XCTAssertFalse(vm.scene.hasPerspectiveView)
        vm.cancelBreakFlow()
    }

    func testFirstPerspectiveEntryDuringTwoDimensionalBreakUsesWholeTable() throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.startBreakFlow(game: .nineBall, seed: 6302)
        defer { vm.cancelBreakFlow() }
        let runner = try XCTUnwrap(vm.breakRunner)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = CGSize(width: 402, height: 600)
        runner.breakNow()
        XCTAssertEqual(runner.phase, .computing)
        XCTAssertFalse(vm.scene.hasPerspectiveView)
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        rig.snapToTarget()
        XCTAssertEqual(rig.currentPivot.x, 0, accuracy: 1e-6)
        XCTAssertEqual(rig.currentPivot.z, 0, accuracy: 1e-6)
        XCTAssertEqual(rig.orbitElevation, abs(AimingCameraConfig.standPitchRad), accuracy: 1e-6)
        XCTAssertTrue(vm.scene.hasPerspectiveView)
        rig.handleHorizontalSwipe(delta: 120)
        rig.snapToTarget()
        let yaw = rig.currentYaw
        ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        XCTAssertEqual(rig.currentYaw, yaw, accuracy: 1e-6)
        XCTAssertEqual(runner.phase, .computing)
    }

    func testRepeatedModeRequestDoesNotRestoreStaleObservation() throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.handleHorizontalSwipe(delta: 200)
        rig.snapToTarget()
        let yaw = rig.currentYaw
        vm.scene.setCameraMode(.perspective3D)
        XCTAssertEqual(rig.currentYaw, yaw)
        XCTAssertFalse(vm.scene.isCameraModeTransitioning)
    }

    func testObservationTargetsDoNotChangeShotSelection() async throws {
        let vm = try await readyFreeBoard()
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        let target = try XCTUnwrap(vm.selectedTargetKey)
        let pocket = vm.selectedPocketIndex
        let direction = try XCTUnwrap(vm.freeAimDir)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        for key in ["cueBall", target] {
            ShotPlayCamera.observeBall(key, on: vm)
            rig.snapToTarget()
            let node = try XCTUnwrap(vm.scene.allBallNodes[key])
            let center = vm.scene.visualCenter(of: node)
            XCTAssertEqual(rig.currentPivot.x, center.x, accuracy: 1e-5)
            XCTAssertEqual(rig.currentPivot.y, center.y, accuracy: 1e-5)
            XCTAssertEqual(rig.currentPivot.z, center.z, accuracy: 1e-5)
        }
        ShotPlayCamera.observePocket(5, on: vm)
        rig.snapToTarget()
        let focus = AngleSceneCalculator.pocketPositions(surfaceY:vm.scene.surfaceY)[5]
        XCTAssertEqual(rig.currentPivot.z, focus.z, accuracy: 1e-5)
        rig.viewportSize = CGSize(width:402,height:600)
        ShotPlayCamera.observeWholeTable(on: vm)
        rig.snapToTarget()
        XCTAssertEqual(vm.selectedTargetKey, target)
        XCTAssertEqual(vm.selectedPocketIndex, pocket)
        XCTAssertEqual(try XCTUnwrap(vm.freeAimDir).x, direction.x)
        XCTAssertEqual(try XCTUnwrap(vm.freeAimDir).z, direction.z)
        let pivot = rig.currentPivot
        ShotPlayCamera.observePocket(-1, on: vm)
        ShotPlayCamera.observeBall("missing", on: vm)
        XCTAssertEqual(rig.targetPivot.x, pivot.x)
        XCTAssertEqual(rig.targetPivot.z, pivot.z)
    }

}


@MainActor
final class OrbitInputV63Tests: XCTestCase {
    private func rig() -> (CameraRig, SCNNode) {
        let node = SCNNode(); node.camera = SCNCamera()
        return (CameraRig(cameraNode: node, tableSurfaceY: 0.8), node)
    }

    func testPinchChangesDistanceWithoutPitchOrFOV() throws {
        let (rig, node) = rig()
        let elevation = rig.orbitElevation
        let distance = rig.orbitDistance
        let fov = try XCTUnwrap(node.camera).fieldOfView
        let pitch = node.eulerAngles.x
        rig.handlePinch(scale: 1.2)
        rig.snapToTarget()
        XCTAssertLessThan(rig.orbitDistance, distance)
        XCTAssertEqual(rig.orbitElevation, elevation, accuracy: 1e-6)
        XCTAssertEqual(node.eulerAngles.x, pitch, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(node.camera).fieldOfView, fov, accuracy: 1e-5)
    }

    func testVerticalDragChangesElevationWithoutDistance() {
        let (rig, node) = rig()
        let distance = rig.orbitDistance
        let elevation = rig.orbitElevation
        let height = node.position.y
        rig.handleVerticalSwipe(delta: 60)
        rig.snapToTarget()
        XCTAssertEqual(rig.orbitDistance, distance, accuracy: 1e-6)
        XCTAssertGreaterThan(rig.orbitElevation, elevation)
        XCTAssertGreaterThan(node.position.y, height)
    }

    func testGestureCancelsAutomaticMoveAtVisiblePose() {
        let (rig, node) = rig()
        rig.enterAiming(cueBallPosition: SCNVector3(0.3,0.8,0.1), targetDirection: SCNVector3(1,0,0))
        rig.update(deltaTime: 0.2)
        let position = node.position
        rig.handleHorizontalSwipe(delta: 0)
        XCTAssertFalse(rig.isTransitioning)
        rig.snapToTarget()
        XCTAssertEqual(node.position.x, position.x, accuracy: 1e-5)
        XCTAssertEqual(node.position.y, position.y, accuracy: 1e-5)
        XCTAssertEqual(node.position.z, position.z, accuracy: 1e-5)
    }

    func testManualObservationDisablesAutomaticCueAnchorUntilAimReturns() {
        let (rig, _) = rig()
        let cue = SCNVector3(0.3, 0.828575, 0.1)
        let direction = SCNVector3(1, 0, 0)
        rig.enterAiming(cueBallPosition: cue, targetDirection: direction)
        XCTAssertFalse(rig.allowsCueScreenAnchor)
        rig.update(deltaTime: 1)
        XCTAssertTrue(rig.allowsCueScreenAnchor)
        rig.handleHorizontalSwipe(delta: 80)
        rig.snapToTarget()
        XCTAssertFalse(rig.allowsCueScreenAnchor)
        let saved = rig.capturePerspectiveState()
        rig.applyTopDown2DRotated()
        rig.restorePerspectiveState(saved)
        XCTAssertFalse(rig.allowsCueScreenAnchor)
        rig.enterAiming(cueBallPosition: cue, targetDirection: direction)
        rig.update(deltaTime: 1)
        XCTAssertTrue(rig.allowsCueScreenAnchor)
        rig.observe(at: SCNVector3(-1.27, 0.8, -0.635))
        XCTAssertFalse(rig.allowsCueScreenAnchor)
    }

    func testIndependentOrbitRestoresAndSettles() {
        let (rig, _) = rig()
        rig.handleVerticalSwipe(delta: 60)
        rig.handlePinch(scale: 1.2)
        let saved = rig.capturePerspectiveState()
        rig.applyTopDown2DRotated()
        rig.restorePerspectiveState(saved)
        for _ in 0..<200 { rig.update(deltaTime: 1.0 / 60) }
        XCTAssertFalse(rig.hasPendingDamping)
        let distance = rig.orbitDistance
        rig.handleVerticalSwipe(delta: 20)
        rig.snapToTarget()
        XCTAssertEqual(rig.orbitDistance, distance, accuracy: 1e-5)
    }
    func testElevationBoundsKeepOpticalAxisAboveInversion() {
        let (rig, node) = rig()
        rig.enterObservation(cueBallPosition: SCNVector3(0,0.8,0), aimDirection: SCNVector3(1,0,0))
        rig.update(deltaTime: 1)
        for delta: Float in [10000, -10000] {
            rig.handleVerticalSwipe(delta: delta)
            rig.snapToTarget()
            XCTAssertGreaterThanOrEqual(node.eulerAngles.x, -.pi / 2 - 1e-5)
            XCTAssertLessThan(node.eulerAngles.x, 0)
            XCTAssertGreaterThan(node.position.y, 0.8)
        }
    }

    func testObservationCentersActualWorldPoint() throws {
        let (rig, camera) = rig()
        let scene = SCNScene(); scene.rootNode.addChildNode(camera)
        let view = SCNView(frame: CGRect(x:0,y:0,width:402,height:600))
        view.scene = scene; view.pointOfView = camera
        let point = SCNVector3(0.4,0.828575,-0.3)
        rig.observe(at: point); rig.snapToTarget()
        SCNTransaction.flush(); view.layoutIfNeeded(); _ = view.snapshot()
        let projected = view.projectPoint(point)
        XCTAssertEqual(projected.x, 201, accuracy: 1)
        XCTAssertEqual(projected.y, 300, accuracy: 1)
    }

    func testClosestLowestOrbitClearsLoadedTableAcrossPocketPivots() throws {
        let scene = AngleTrainingScene()
        scene.setupScene()
        let table = try XCTUnwrap(scene.tableNode)
        let rig = try XCTUnwrap(scene.cameraRig)
        let camera = try XCTUnwrap(scene.cameraNode.camera)
        let bounds = table.boundingBox
        var highestY = -Float.greatestFiniteMagnitude
        for x in [bounds.min.x, bounds.max.x] {
            for y in [bounds.min.y, bounds.max.y] {
                for z in [bounds.min.z, bounds.max.z] {
                    highestY = max(highestY, table.convertPosition(SCNVector3(x,y,z), to: nil).y)
                }
            }
        }
        let pivots = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY)
            + [SCNVector3(0, scene.surfaceY, 0)]
        for pivot in pivots {
            for yaw: Float in [0, .pi / 2, .pi, 3 * .pi / 2] {
                rig.observe(at: pivot)
                rig.targetYaw = yaw
                rig.handleVerticalSwipe(delta: -10000)
                rig.handlePinch(scale: 100)
                rig.snapToTarget()
                // Bound the whole near plane by its corner radius, including
                // the widest tested viewport (iPad 744 × 900).
                let tanV = tan(Double(camera.fieldOfView) * .pi / 360)
                let tanH = tanV * 744 / 900
                let nearRadius = Float(camera.zNear * sqrt(1 + tanV*tanV + tanH*tanH))
                XCTAssertGreaterThan(scene.cameraNode.position.y - nearRadius, highestY,
                                     "Closest low orbit must stay above the loaded table, pivot=\(pivot), yaw=\(yaw)")
            }
        }
    }

    func testWholeTableFitsActualViewportAcrossYawAndSizes() {
        for size in [CGSize(width:375,height:500), CGSize(width:402,height:650), CGSize(width:744,height:900)] {
            for yaw: Float in [0, .pi/4, .pi/2, .pi] {
                let (rig,camera) = rig()
                let scene = SCNScene(); scene.rootNode.addChildNode(camera)
                let view = SCNView(frame: CGRect(origin:.zero,size:size))
                view.scene = scene; view.pointOfView = camera
                rig.viewportSize = size
                rig.setAimYaw(yaw)
                XCTAssertTrue(rig.observeWholeTable())
                rig.snapToTarget()
                SCNTransaction.flush(); view.layoutIfNeeded(); _ = view.snapshot()
                let opticalCenter = view.projectPoint(rig.currentPivot)
                XCTAssertEqual(opticalCenter.x, Float(size.width/2), accuracy:1)
                XCTAssertEqual(opticalCenter.y, Float(size.height/2), accuracy:1)
                for x in [-Float(rig.tableOuterHalfLength), Float(rig.tableOuterHalfLength)] {
                    for z in [-Float(rig.tableOuterHalfWidth), Float(rig.tableOuterHalfWidth)] {
                        for y: Float in [0.8, 0.8 + 2*BallPhysics.radius] {
                            let p = view.projectPoint(SCNVector3(x,y,z))
                            XCTAssertGreaterThanOrEqual(p.x, 0)
                            XCTAssertLessThanOrEqual(p.x, Float(size.width))
                            XCTAssertGreaterThanOrEqual(p.y, 0)
                            XCTAssertLessThanOrEqual(p.y, Float(size.height))
                            XCTAssertGreaterThan(p.z,0)
                            XCTAssertLessThan(p.z,1)
                        }
                    }
                }
            }
        }
    }

}

extension IdealDirectionIntegrationTests {
    func testIncompleteAimVerificationKeepsAnswerAndQuestion() throws {
        let suite = "v63.verification." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = AimPointSceneQuizViewModel(limiter: AngleUsageLimiter(defaults: defaults))
        vm.setupScene(cameraMode: .topDown2D)
        vm.submit()
        let question = try XCTUnwrap(vm.question)
        let error = vm.lastErrorMM
        let count = vm.sessionResults.count
        var prediction = ShotPredictor.simulateFree(
            cueBall: SCNVector3(0, BTTablePhysics.surfaceY + BallPhysics.radius, 0),
            aimDir: SCNVector3(1, 0, 0), velocity: 0.3, spinX: 0, spinY: 0,
            surfaceY: BTTablePhysics.surfaceY, balls: [])
        XCTAssertTrue(prediction.hasFinalTableState)
        let complete = prediction
        for termination: EventDrivenEngine.Termination? in [nil, .timeLimit, .eventLimit, .failed("test")] {
            prediction.termination = termination
            XCTAssertFalse(vm.acceptVerificationPrediction(prediction))
            XCTAssertEqual(vm.phase, .showingResult)
            XCTAssertEqual(vm.question?.cueBall, question.cueBall)
            XCTAssertEqual(vm.question?.targetBall, question.targetBall)
            XCTAssertEqual(vm.lastErrorMM, error)
            XCTAssertEqual(vm.sessionResults.count, count)
            XCTAssertNotNil(vm.verificationErrorMessage)
        }
        XCTAssertTrue(vm.acceptVerificationPrediction(complete))
        XCTAssertNil(vm.verificationErrorMessage)
        XCTAssertEqual(vm.sessionResults.count, count)
    }
}

@MainActor
final class CueScratchLifecycleV63Tests: XCTestCase {
    func testScratchPlaybackRedoAndPaletteRestoreAcrossViews() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.clearTable()
        vm.toggleAimMode()
        let cueKey = PositionPlayBall.cueKey
        let cuePosition = SCNVector3(0, vm.scene.surfaceY + BallPhysics.radius, -0.45)
        vm.placeFromPalette(cueKey, atWorld: cuePosition)
        vm.velocity = 1.5
        vm.handleTableTap(world: AngleSceneCalculator.pocketPositions(surfaceY: vm.scene.surfaceY)[4])
        let solveDeadline = Date().addingTimeInterval(30)
        while vm.isComputing, Date() < solveDeadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(vm.isComputing)
        let prediction = try XCTUnwrap(vm.solvedShot?.prediction)
        XCTAssertTrue(prediction.hasFinalTableState)
        XCTAssertTrue(prediction.cuePocketed)
        // W17-D: the planar scratch gets a deterministic net tail on playback — cue rests
        // on the lowest slot of the tapped middle pocket and never fades.
        let scratchRecorder = try XCTUnwrap(prediction.recorder)
        let scratchPlayback = TrajectoryPlayback(recorder: scratchRecorder, surfaceY: vm.scene.surfaceY + BallPhysics.radius)
        let scratchTail = try XCTUnwrap(scratchRecorder.collectionTailsByBallName[ShotInput.cueBallName])
        XCTAssertNil(scratchTail.fadeStart)
        let scratchPocket = try XCTUnwrap(TableGeometry.chineseEightBallQiuJi(surfaceY: vm.scene.surfaceY).pockets.first { $0.id == "pocket_4" })
        let scratchNet = PocketNetPresentation.NetPocket(pocket: scratchPocket, surfaceY: Double(vm.scene.surfaceY))
        XCTAssertEqual(scratchTail.end.position, scratchNet.slots(ballRadius: Double(BallPhysics.radius))[0])
        XCTAssertEqual(scratchPlayback.collectionOpacity(ballName: ShotInput.cueBallName, time: scratchPlayback.duration + 2), 1)

        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 402, height: 700))
        view.scene = vm.scene
        view.pointOfView = vm.scene.cameraNode
        let window = UIWindow(windowScene: try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene))
        let controller = UIViewController()
        controller.view = view
        window.rootViewController = controller
        window.makeKeyAndVisible()
        view.isPlaying = true
        defer { view.isPlaying = false; window.isHidden = true }
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        try await Task.sleep(for: .milliseconds(600))
        try XCTUnwrap(vm.scene.cameraRig).snapToTarget()
        let shotView = vm.scene.cameraNode.transform
        let rules = ChineseEightBallRules()
        var settledCount = 0
        vm.onShotSettled = { facts in
            settledCount += 1
            XCTAssertTrue(facts.cuePocketed)
            XCTAssertTrue(rules.judge(facts).ballInHand)
        }
        func waitForPlayback() async throws {
            let deadline = Date().addingTimeInterval(20)
            while vm.isPlaying, Date() < deadline {
                try await Task.sleep(for: .milliseconds(100))
            }
            XCTAssertFalse(vm.isPlaying, "Scene playback must reach its completion callback")
        }
        vm.play()
        XCTAssertTrue(vm.isPlaying)
        ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
        try await waitForPlayback()
        XCTAssertEqual(settledCount, 1)
        XCTAssertFalse(vm.onTableKeys.contains(cueKey))
        XCTAssertTrue(try XCTUnwrap(vm.scene.allBallNodes[cueKey]).isHidden)
        XCTAssertTrue(vm.canPlayback)
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        vm.replayLastShot()
        XCTAssertTrue(vm.isPlaying)
        try await waitForPlayback()
        XCTAssertEqual(settledCount, 1, "Replay must not judge the shot again")
        XCTAssertFalse(vm.onTableKeys.contains(cueKey))
        ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
        try await Task.sleep(for: .milliseconds(600))
        vm.replayCurrent()
        XCTAssertEqual(vm.cameraMode, .topDown2DRotated, "Undo must keep the selected 2D mode")
        XCTAssertTrue(try XCTUnwrap(vm.scene.cameraNode.camera).usesOrthographicProjection)
        XCTAssertTrue(vm.onTableKeys.contains(cueKey))
        let restored = try XCTUnwrap(vm.scene.allBallNodes[cueKey])
        XCTAssertFalse(restored.isHidden)
        XCTAssertEqual(restored.position.z, cuePosition.z, accuracy: 0.0001)
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        XCTAssertTrue(SCNMatrix4EqualToMatrix4(vm.scene.cameraNode.transform, shotView),
                      "Returning to 3D after undo must recover the pre-shot camera")
        vm.removeFromTable(cueKey)
        ShotPlayCamera.setMode(.topDown2DRotated, on: vm)
        vm.placeFromPalette(cueKey)
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        XCTAssertTrue(vm.onTableKeys.contains(cueKey))
        XCTAssertFalse(restored.isHidden)
        XCTAssertEqual(restored.opacity, 1)
        XCTAssertEqual(settledCount, 1)
    }
}
