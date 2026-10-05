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

    func testBallInspectionPreservesShotAndManualCamera() async throws {
        let vm = try await readyFreeBoard()
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        let key = try XCTUnwrap(vm.selectedTargetKey)
        let target = try XCTUnwrap(vm.scene.allBallNodes[key])
        let aim = try XCTUnwrap(vm.freeAimDir)
        let pocket = vm.selectedPocketIndex
        ShotPlayCamera.inspectBall(key, on: vm)
        rig.snapToTarget()
        let direction = rig.aimDirectionForCurrentYaw()
        let dx = target.position.x - cue.position.x
        let dz = target.position.z - cue.position.z
        let length = hypotf(dx, dz)
        XCTAssertEqual(direction.x, dx / length, accuracy: 0.0001)
        XCTAssertEqual(direction.z, dz / length, accuracy: 0.0001)
        XCTAssertEqual(vm.freeAimDir?.x, aim.x)
        XCTAssertEqual(vm.freeAimDir?.z, aim.z)
        XCTAssertEqual(vm.selectedTargetKey, key)
        XCTAssertEqual(vm.selectedPocketIndex, pocket)
        rig.handleHorizontalSwipe(delta: 100)
        rig.snapToTarget()
        let manualYaw = rig.targetYaw
        vm.nudgeFreeAim(byDegrees: 1)
        for _ in 0..<120 { rig.update(deltaTime: 1 / 60) }
        XCTAssertEqual(rig.targetYaw, manualYaw)
        ShotPlayCamera.inspectBall(PositionPlayBall.cueKey, on: vm)
        rig.snapToTarget()
        let currentAim = try XCTUnwrap(vm.freeAimDir)
        XCTAssertEqual(rig.aimDirectionForCurrentYaw().x, currentAim.x, accuracy: 0.0001)
        XCTAssertEqual(rig.aimDirectionForCurrentYaw().z, currentAim.z, accuracy: 0.0001)
        let yaw = rig.targetYaw
        ShotPlayCamera.inspectBall("missing", on: vm)
        XCTAssertEqual(rig.targetYaw, yaw)
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


@MainActor
final class DailyPreviewWorkTests: XCTestCase {
    func testRetainedLinesReuseNodesMaterialsAndUnchangedGeometry() throws {
        let scene = AngleTrainingScene()
        scene.setupScene(mobileRendering: true)
        let a = AimCloseupSegment(start: CGPoint(x: -0.4, y: 0), end: CGPoint(x: 0.4, y: 0.1))
        let b = AimCloseupSegment(start: CGPoint(x: -0.4, y: 0), end: CGPoint(x: 0.5, y: 0.2))
        let solid = try XCTUnwrap(scene.setFreeAimPreviewLine(a))
        let dashed = try XCTUnwrap(scene.setIdealObjectLine(a))
        let dash = try XCTUnwrap(dashed.childNodes.first)
        let solidGeometry = try XCTUnwrap(solid.geometry)
        let dashGeometry = try XCTUnwrap(dash.geometry)
        let solidMaterial = try XCTUnwrap(solidGeometry.firstMaterial)
        let dashMaterial = try XCTUnwrap(dashGeometry.firstMaterial)
        for _ in 0..<100 {
            XCTAssertTrue(scene.setFreeAimPreviewLine(a) === solid)
            XCTAssertTrue(scene.setIdealObjectLine(a) === dashed)
            XCTAssertTrue(solid.geometry === solidGeometry)
            XCTAssertTrue(dash.geometry === dashGeometry)
        }
        XCTAssertTrue(scene.setFreeAimPreviewLine(b) === solid)
        XCTAssertTrue(scene.setIdealObjectLine(b) === dashed)
        XCTAssertTrue(dashed.childNodes.first === dash)
        XCTAssertTrue(solid.geometry?.firstMaterial === solidMaterial)
        XCTAssertTrue(dash.geometry?.firstMaterial === dashMaterial)
        scene.hideAllVisualization()
        XCTAssertNil(solid.parent)
        XCTAssertNil(dashed.parent)
        XCTAssertTrue(scene.setFreeAimPreviewLine(b) === solid)
        XCTAssertTrue(scene.setIdealObjectLine(b) === dashed)
        // Completely clipped input must clear old geometry, and re-entry must restore it.
        let outside = AimCloseupSegment(start: CGPoint(x: 5, y: 5), end: CGPoint(x: 6, y: 6))
        _ = scene.setFreeAimPreviewLine(outside)
        _ = scene.setIdealObjectLine(outside)
        XCTAssertNil(solid.geometry)
        XCTAssertNil(dash.geometry)
        _ = scene.setFreeAimPreviewLine(a)
        _ = scene.setIdealObjectLine(a)
        XCTAssertNotNil(solid.geometry)
        XCTAssertNotNil(dash.geometry)
        XCTAssertEqual(scene.rootNode.childNodes.filter { $0.name == "freeAimPreview" }.count, 1)
        XCTAssertEqual(scene.rootNode.childNodes.filter { $0.name == "idealObjectDirection" }.count, 1)
    }

    func testGeometryDependenciesIgnorePowerButInvalidateForAimAndBoard() throws {
        let vm = PositionPlayViewModel()
        vm.setupScene(mobileRendering: true)
        vm.aimMode = .free
        let target = try XCTUnwrap(vm.scene.allBallNodes["_1"])
        vm.handleTableTap(world: target.position)
        vm.recompute(interactive: true) // settle the near-band hysteresis input
        let first = try XCTUnwrap(vm.freeAimContact)
        var emissions = 0
        let subscription = vm.$freeAimContact.dropFirst().sink { _ in emissions += 1 }
        defer { subscription.cancel(); vm.clearTable() }
        for _ in 0..<20 { vm.recompute(interactive: true) }
        vm.velocity += 0.1
        vm.spinX += 0.1
        vm.spinY += 0.1
        XCTAssertEqual(emissions, 0, "Power/spin do not change the first-contact geometry")
        XCTAssertEqual(vm.freeAimContact?.targetKey, first.targetKey)
        vm.nudgeFreeAim(byDegrees: 0.2)
        XCTAssertGreaterThan(emissions, 0)
        let aimEmissions = emissions
        vm.dragMoved(node: target, worldPosition: SCNVector3(target.position.x + 0.01, target.position.y, target.position.z))
        XCTAssertGreaterThan(emissions, aimEmissions)
        vm.clearTable()
        XCTAssertNil(vm.freeAimContact)
        XCTAssertNil(vm.scene.rootNode.childNode(withName: "freeAimPreview", recursively: false))
    }

    func testUnrelatedUpdatesDoNotExtendRenderWindowButActivityDoes() {
        let scene = AngleTrainingScene()
        let coordinator = AngleSceneView.Coordinator(scene: scene, cameraMode: .topDown2DRotated, interactionMode: .cameraControl)
        coordinator.updateContentActivity(false, cameraMode: .topDown2DRotated)
        let initial = coordinator.interactiveUntil
        for _ in 0..<100 { coordinator.updateContentActivity(false, cameraMode: .topDown2DRotated) }
        XCTAssertEqual(coordinator.interactiveUntil, initial)
        coordinator.updateContentActivity(true, cameraMode: .topDown2DRotated)
        XCTAssertGreaterThan(coordinator.interactiveUntil, initial)
        XCTAssertEqual(coordinator.contentIsAnimating, true)
        let playing = coordinator.interactiveUntil
        coordinator.updateContentActivity(true, cameraMode: .perspective3D)
        XCTAssertGreaterThan(coordinator.interactiveUntil, playing)
        coordinator.updateContentActivity(nil, cameraMode: .perspective3D)
        XCTAssertNil(coordinator.contentIsAnimating, "Legacy consumers retain continuous activity")
        coordinator.updateContentActivity(false, cameraMode: .topDown2DRotated)
        coordinator.updateViewport(CGSize(width: 400, height: 700))
        let layout = coordinator.interactiveUntil
        coordinator.updateViewport(CGSize(width: 400, height: 700))
        XCTAssertEqual(coordinator.interactiveUntil, layout)
        coordinator.updateViewport(CGSize(width: 700, height: 400))
        XCTAssertGreaterThan(coordinator.interactiveUntil, layout, "A stationary view must wake to refit after resize")
    }
}

@MainActor
final class DailyPocketCameraTimingTests: XCTestCase {
    private func ready(_ vm: PositionPlayViewModel, until predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(15)
        while !predicate(), Date() < deadline {
            vm.scene.cameraRig?.update(deltaTime: 0.02)
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(predicate(), "Timed out: \(vm.statusText)")
    }

    private func fixture() async throws -> (PositionPlayViewModel, SCNView, UIWindow) {
        let vm = PositionPlayViewModel()
        vm.scene.configureDailyClearanceRendering()
        vm.setupScene(); vm.enablePlayerCameraControls(); vm.clearTable()
        vm.placeFromPalette(PositionPlayBall.cueKey,
            atWorld: SCNVector3(0, vm.scene.surfaceY + BallPhysics.radius, 0.35))
        vm.placeFromPalette("_1",
            atWorld: SCNVector3(0, vm.scene.surfaceY + BallPhysics.radius, -0.1))
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        vm.selectPocket(at: 4); vm.velocity = 1.4
        try await ready(vm) { !vm.isComputing && vm.solvedShot != nil }
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        view.scene = vm.scene; view.pointOfView = vm.scene.cameraNode
        vm.scene.cameraRig?.viewportSize = view.bounds.size
        let window = UIWindow(windowScene: try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene))
        let controller = UIViewController(); controller.view = view
        window.rootViewController = controller; window.makeKeyAndVisible(); view.isPlaying = true
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        try await Task.sleep(for: .milliseconds(600))
        vm.requestPlayerView(.firstPerson)
        try await ready(vm) { !vm.cameraTransitionBusy }
        return (vm, view, window)
    }

    func testTargetCaptureKeepsFirstPersonAfterContactThenStandsAndUndoRestoresIt() async throws {
        let (vm, view, window) = try await fixture()
        defer { vm.cancelDailyAttempt(); view.isPlaying = false; window.isHidden = true }
        let prediction = try XCTUnwrap(vm.solvedShot).prediction
        let capture = try XCTUnwrap(prediction.events.first {
            if case .pocket(let ball, _) = $0.kind { return ball == ShotInput.targetBallName }; return false
        })
        XCTAssertGreaterThan(capture.time, 0.3, "Fixture must leave an observable interval before the pot")
        var settlements = 0
        vm.onShotSettled = { _ in settlements += 1 }
        vm.play()
        try await ready(vm) { vm.statusText == "击球中…" }
        XCTAssertEqual(vm.scene.cameraRig?.playerView, .firstPerson, "Contact must not stand the player up")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(vm.scene.cameraRig?.playerView, .firstPerson)
        let output = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/daily-pocket-camera-20261001/timing")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try XCTUnwrap(view.snapshot().pngData()).write(to: output.appendingPathComponent("before-target-capture.png"))
        let target = try XCTUnwrap(vm.scene.allBallNodes["_1"])
        let deadline = Date().addingTimeInterval(10)
        var samples = 0
        while !target.isHidden, Date() < deadline {
            XCTAssertEqual(vm.scene.cameraRig?.playerView, .firstPerson,
                           "The player must keep watching until the target leaves the table at capture")
            samples += 1
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(target.isHidden, "Actual target capture must occur")
        XCTAssertGreaterThan(samples, 3, "Sample the visible target throughout its approach")
        try await ready(vm) { vm.scene.cameraRig?.playerView == .thirdPerson }
        XCTAssertTrue(vm.isPlaying, "Stand at target capture, while the remaining playback continues")
        try await ready(vm) { !vm.isPlaying && !vm.isComputing }
        try await ready(vm) { !vm.cameraTransitionBusy }
        try XCTUnwrap(view.snapshot().pngData()).write(to: output.appendingPathComponent("after-target-capture.png"))
        XCTAssertEqual(settlements, 1)
        XCTAssertFalse(vm.onTableKeys.contains("_1"))
        vm.replayCurrent()
        XCTAssertEqual(vm.scene.cameraRig?.playerView, .firstPerson, "Undo restores the shot's original view")
    }

    func testMissWaitsUntilSettlementBeforeStanding() async throws {
        let (vm, view, window) = try await fixture()
        defer { vm.cancelDailyAttempt(); view.isPlaying = false; window.isHidden = true }
        vm.aimMode = .free
        vm.handleTableTap(world: SCNVector3(0.5, vm.scene.surfaceY, 0.35)); vm.velocity = 0.5
        try await ready(vm) { !vm.isComputing && vm.solvedShot?.shot.isFree == true }
        XCTAssertTrue(try XCTUnwrap(vm.solvedShot).prediction.pocketedBalls.isEmpty)
        vm.requestPlayerView(.firstPerson)
        try await ready(vm) { !vm.cameraTransitionBusy }
        vm.play()
        try await ready(vm) { vm.statusText == "击球中…" }
        XCTAssertEqual(vm.scene.cameraRig?.playerView, .firstPerson)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(vm.isPlaying)
        XCTAssertEqual(vm.scene.cameraRig?.playerView, .firstPerson)
        try await ready(vm) { !vm.isPlaying }
        XCTAssertEqual(vm.scene.cameraRig?.playerView, .thirdPerson)
    }

    func testCancelledShotCannotStandUpReplacementAttempt() async throws {
        let (vm, view, window) = try await fixture()
        defer { vm.cancelDailyAttempt(); view.isPlaying = false; window.isHidden = true }
        let before = vm.currentSnapshot(), prediction = try XCTUnwrap(vm.solvedShot).prediction
        vm.play()
        try await ready(vm) { vm.statusText == "击球中…" }
        vm.cancelDailyAttempt(); vm.loadBoard(before)
        try await ready(vm) { !vm.isComputing }
        vm.requestPlayerView(.firstPerson)
        try await ready(vm) { !vm.cameraTransitionBusy }
        try await Task.sleep(for: .seconds(Double(prediction.duration) + 0.3))
        XCTAssertFalse(vm.isPlaying)
        XCTAssertEqual(vm.scene.cameraRig?.playerView, .firstPerson)
    }

    func testGlobalAndThirdPersonShotsKeepSelectedView() async throws {
        let (vm, view, window) = try await fixture()
        defer { vm.cancelDailyAttempt(); view.isPlaying = false; window.isHidden = true }
        for global in [true, false] {
            if global { vm.scene.cameraRig?.observeWholeTable() }
            else { vm.requestPlayerView(.thirdPerson) }
            try await ready(vm) { !vm.cameraTransitionBusy }
            vm.play()
            try await ready(vm) { !vm.isPlaying && !vm.isComputing }
            XCTAssertEqual(vm.scene.cameraRig?.playerView, global ? nil : .thirdPerson)
            vm.replayCurrent()
            try await ready(vm) { !vm.isComputing }
        }
    }
}

@MainActor
final class DailyPowerReleaseTests: XCTestCase {
    private func makePocketVM() async throws -> PositionPlayViewModel {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.clearTable()
        vm.usesAutomaticPocketFallback = true
        vm.placeFromPalette(PositionPlayBall.cueKey,
            atWorld: SCNVector3(-0.5, vm.scene.surfaceY + BallPhysics.radius, 0))
        vm.placeFromPalette("_1", atWorld: SCNVector3(0, vm.scene.surfaceY + BallPhysics.radius, 0))
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        try await waitUntil { vm.solvedShot != nil && !vm.isComputing }
        XCTAssertEqual(vm.aimMode, .pocket)
        XCTAssertTrue(vm.isFeasible)
        XCTAssertFalse(try XCTUnwrap(vm.scene.cueStick).rootNode.isHidden)
        return vm
    }

    func testPocketPowerDragKeepsCueAcrossIdleSolveReleaseAndReselection() async throws {
        let vm = try await makePocketVM()
        defer { vm.clearTable() }
        let cue = try XCTUnwrap(vm.scene.cueStick).rootNode
        let target = vm.selectedTargetKey, pocket = vm.selectedPocketIndex
        vm.beginPowerDrag()
        for value in [1.6, 1.7, 1.8] {
            vm.velocity = value
            XCTAssertFalse(cue.isHidden, "Power input must not hide the addressed cue")
            XCTAssertEqual(vm.aimMode, .pocket)
        }
        // A pause while still holding the control delivers the latest preview.
        try await waitUntil { vm.solvedShot?.shot.velocity == 1.8 && !vm.isComputing }
        XCTAssertFalse(cue.isHidden)
        vm.velocity = 1.9
        XCTAssertFalse(cue.isHidden)
        vm.endPowerDrag(commit: false)
        XCTAssertFalse(cue.isHidden)
        try await waitUntil { vm.solvedShot?.shot.velocity == 1.9 && !vm.isComputing }
        XCTAssertEqual(vm.selectedTargetKey, target)
        XCTAssertEqual(vm.selectedPocketIndex, pocket)
        XCTAssertFalse(vm.isPlaying)

        vm.nudgeFreeAim(byDegrees: 1)
        XCTAssertEqual(vm.aimMode, .free)
        vm.beginPowerDrag()
        vm.velocity = 2.0
        XCTAssertFalse(cue.isHidden)
        vm.endPowerDrag(commit: false)
        try await waitUntil { vm.solvedShot?.shot.velocity == 2 && !vm.isComputing }
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        try await waitUntil { vm.solvedShot?.shot.isFree == false && !vm.isComputing }
        XCTAssertEqual(vm.aimMode, .pocket)
        vm.beginPowerDrag()
        vm.velocity = 2.1
        XCTAssertFalse(cue.isHidden, "Reselecting a target must not restore the disappearing-cue bug")
        vm.endPowerDrag(commit: false)
    }

    func testPocketPowerPreviewRejectsChangedBoardAndMissingCue() async throws {
        let vm = try await makePocketVM()
        defer { vm.clearTable() }
        let stick = try XCTUnwrap(vm.scene.cueStick).rootNode
        let target = try XCTUnwrap(vm.scene.allBallNodes["_1"])
        target.position.x += 0.1
        vm.beginPowerDrag()
        vm.velocity = 1.8
        XCTAssertTrue(stick.isHidden, "An old solved direction must not be reused for a changed board")
        vm.endPowerDrag(commit: false)
        vm.removeFromTable(PositionPlayBall.cueKey)
        vm.beginPowerDrag()
        vm.velocity = 1.9
        XCTAssertTrue(stick.isHidden)
        XCTAssertFalse(vm.isPlaying)
    }

    func testPocketPowerCueRenderedBeforeDuringAndAfterDrag() async throws {
        let vm = try await makePocketVM()
        defer { vm.clearTable() }
        vm.scene.setCameraMode(.perspective3D, animated: false)
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = vm.scene
        renderer.pointOfView = vm.scene.cameraNode
        func capture(_ name: String) throws {
            XCTAssertFalse(try XCTUnwrap(vm.scene.cueStick).rootNode.isHidden)
            SCNTransaction.flush()
            let image = renderer.snapshot(atTime: CACurrentMediaTime(),
                with: CGSize(width: 1000, height: 700), antialiasingMode: .multisampling4X)
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        try capture("power-before")
        vm.beginPowerDrag()
        vm.velocity = 1.8
        try capture("power-during")
        vm.endPowerDrag(commit: false)
        try await waitUntil { vm.solvedShot?.shot.velocity == 1.8 && !vm.isComputing }
        try capture("power-after")
    }

    private func makeVM() -> PositionPlayViewModel {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.clearTable()
        vm.placeFromPalette(PositionPlayBall.cueKey,
                            atWorld: SCNVector3(0, vm.scene.surfaceY + BallPhysics.radius, 0))
        vm.aimMode = .free
        vm.handleTableTap(world: SCNVector3(0.5, vm.scene.surfaceY, 0))
        vm.velocity = 0.7
        return vm
    }

    private func waitUntil(_ predicate: () -> Bool, timeout: TimeInterval = 15) async throws {
        let end = Date().addingTimeInterval(timeout)
        while !predicate(), Date() < end { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertTrue(predicate())
    }

    func testPowerPreviewDebounceReplacesEarlierInputWithoutChangingAimDelay() {
        let scheduler = SolveDebounceScheduler()
        var jobs: [(TimeInterval, DispatchWorkItem)] = []
        scheduler.scheduleAfter = { jobs.append(($0, $1)) }
        var fired = 0
        for _ in 0..<5 {
            scheduler.schedule(interactive: true,
                               delayOverride: PositionPlayViewModel.powerPreviewIdleInterval) { fired += 1 }
        }
        XCTAssertEqual(fired, 0)
        XCTAssertEqual(jobs.last?.0, 0.18)
        XCTAssertTrue(jobs.dropLast().allSatisfy { $0.1.isCancelled })
        jobs.last?.1.perform()
        XCTAssertEqual(fired, 1)
        scheduler.schedule(interactive: true) {}
        XCTAssertEqual(jobs.last?.0, 0.5)
    }

    func testReleaseFinishesLatestPreviewWithoutStriking() async throws {
        let vm = makeVM()
        try await waitUntil { vm.solvedShot != nil && !vm.isComputing }
        vm.beginPowerDrag()
        vm.velocity = 0.9
        vm.velocity = 0.8
        vm.endPowerDrag(commit: true)
        XCTAssertFalse(vm.powerReleasePending)
        XCTAssertFalse(vm.isPlaying)
        try await waitUntil { vm.solvedShot?.shot.velocity == 0.8 && !vm.isComputing }
        XCTAssertFalse(vm.isPlaying, "Late solve completion must not fire a released power control")
        vm.endPowerDrag(commit: true)
        XCTAssertFalse(vm.isPlaying, "Duplicate release must not shoot")
        vm.play()
        XCTAssertTrue(vm.isPlaying, "The explicit strike action still starts the stroke")
    }

    func testCancelledDragMayPreviewButNeverStrikes() async throws {
        let vm = makeVM()
        try await waitUntil { vm.solvedShot != nil && !vm.isComputing }
        vm.beginPowerDrag()
        vm.velocity = 0.9
        vm.endPowerDrag(commit: false)
        try await waitUntil { vm.solvedShot?.shot.velocity == 0.9 && !vm.isComputing }
        XCTAssertFalse(vm.isPlaying)
        XCTAssertFalse(vm.powerReleasePending)
    }

    func testNewIntentAndLeavingCancelPendingRelease() async throws {
        let vm = makeVM()
        try await waitUntil { vm.solvedShot != nil && !vm.isComputing }
        vm.beginPowerDrag()
        vm.velocity = 0.9
        vm.endPowerDrag(commit: true)
        vm.spinY = 0.2
        XCTAssertFalse(vm.powerReleasePending)
        try await waitUntil { vm.solvedShot?.shot.spinY == 0.2 && !vm.isComputing }
        XCTAssertFalse(vm.isPlaying)
        vm.beginPowerDrag()
        vm.velocity = 1.0
        vm.endPowerDrag(commit: true)
        vm.cancelPowerRelease()
        try await waitUntil { vm.solvedShot?.shot.velocity == 1.0 && !vm.isComputing }
        XCTAssertFalse(vm.isPlaying)
        XCTAssertFalse(vm.powerReleasePending)
    }
}

@MainActor
final class DailyAimSelectionTests: XCTestCase {
    private func makeVM() -> PositionPlayViewModel {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.clearTable()
        vm.usesAutomaticPocketFallback = true
        vm.placeFromPalette(PositionPlayBall.cueKey,
            atWorld: SCNVector3(-0.5, vm.scene.surfaceY + BallPhysics.radius, 0))
        vm.placeFromPalette("_1", atWorld: SCNVector3(0, vm.scene.surfaceY + BallPhysics.radius, 0))
        vm.placeFromPalette("_9", atWorld: SCNVector3(0.7, vm.scene.surfaceY + BallPhysics.radius, 0.3))
        return vm
    }

    func testIllegalSelectionPreservesAllAimInputsAndEmptyLegalSetRejectsEverything() {
        let vm = makeVM()
        vm.legalAimTargets = { _ in ["_1"] }
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        let target = vm.selectedTargetKey, pocket = vm.selectedPocketIndex, mode = vm.aimMode
        vm.spinX = 0.1
        vm.velocity = 2
        XCTAssertFalse(vm.selectTarget(key: "_9"))
        XCTAssertEqual(vm.selectedTargetKey, target)
        XCTAssertEqual(vm.selectedPocketIndex, pocket)
        XCTAssertEqual(vm.aimMode, mode)
        XCTAssertEqual(vm.spinX, 0.1)
        XCTAssertEqual(vm.velocity, 2)
        vm.legalAimTargets = { _ in [] }
        XCTAssertFalse(vm.selectTarget(key: "_1"))
        vm.refreshLegalAimSelection()
        XCTAssertNil(vm.selectedTargetKey)
    }

    func testDirectionAdjustmentIsTemporaryButExplicitFreeModePersistsAcrossSelection() {
        let vm = makeVM()
        vm.selectTarget(key: "_1")
        XCTAssertEqual(vm.aimMode, .pocket)
        vm.nudgeFreeAim(byDegrees: 1)
        XCTAssertEqual(vm.aimMode, .free)
        XCTAssertEqual(vm.preferredAimMode, .pocket)
        XCTAssertNotNil(vm.temporaryFreeReason)
        vm.selectTarget(key: "_1")
        XCTAssertEqual(vm.aimMode, .pocket)
        XCTAssertNil(vm.temporaryFreeReason)
        vm.toggleAimMode()
        XCTAssertEqual(vm.preferredAimMode, .free)
        vm.selectTarget(key: "_9")
        XCTAssertEqual(vm.aimMode, .free)
        XCTAssertEqual(vm.selectedTargetKey, "_9")
    }

    func testUnavailableExplicitPocketAcceptsIntentAndSwitchesFree() {
        let vm = makeVM()
        vm.selectTarget(key: "_1")
        let invalid = (0..<6).first { !vm.isStraightPocketAvailable($0) }
        XCTAssertNotNil(invalid)
        var notice: String?
        vm.onAimModeNotice = { notice = $0 }
        if let invalid { vm.selectPocket(at: invalid) }
        XCTAssertEqual(vm.selectedPocketIndex, invalid)
        XCTAssertEqual(vm.aimMode, .free)
        XCTAssertEqual(vm.preferredAimMode, .pocket)
        XCTAssertNotNil(notice)
    }

    func testBlockedPocketTemporarilyFallsBackAndNextLegalTargetRestoresPocket() {
        let vm = makeVM()
        // A close ring around the target blocks every straight object-ball path.
        for index in 0..<6 {
            let angle = Float(index) * .pi / 3
            vm.placeFromPalette("_\(index + 2)", atWorld: SCNVector3(
                cos(angle) * 0.07, vm.scene.surfaceY + BallPhysics.radius, sin(angle) * 0.07))
        }
        vm.selectTarget(key: "_1")
        XCTAssertEqual(vm.aimMode, .free)
        XCTAssertEqual(vm.preferredAimMode, .pocket)
        XCTAssertNotNil(vm.temporaryFreeReason)
        vm.selectTarget(key: "_9")
        XCTAssertEqual(vm.aimMode, .pocket)
        XCTAssertNil(vm.temporaryFreeReason)
    }
}

@MainActor
final class RuleNoticeTests: XCTestCase {
    func testModeCannotReplaceFoulAndOldExpiryCannotClearNewNotice() async throws {
        let center = BTRuleNoticeCenter()
        center.show("首次", tone: .info, priority: .mode, duration: 0.05)
        center.show("白球进袋，换手，自由球", tone: .warning, priority: .ruling, duration: 0.25)
        center.show("进袋模式", tone: .info, priority: .mode)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(center.message?.text, "白球进袋，换手，自由球")
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertNil(center.message)
    }
}

@MainActor
final class DailyPlacementAndNoticeTests: XCTestCase {
    func testRepeatedSelectionExtendsNoticeWithoutChangingItsPayload() async throws {
        let center = BTRuleNoticeCenter()
        center.show("当前打全色球", tone: .warning, priority: .selection, duration: 0.08)
        let message = center.message
        try await Task.sleep(for: .milliseconds(40))
        center.show("当前打全色球", tone: .warning, priority: .selection, duration: 0.2)
        XCTAssertEqual(center.message, message)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(center.message?.text, "当前打全色球")
        try await Task.sleep(for: .milliseconds(180))
        XCTAssertNil(center.message)
    }

    func testBallInHandRejectsNoPermissionOverlapOutsideAndHeadString() throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.loadBoard(BoardSnapshot(onTable: [PositionPlayBall.cueKey: CanvasPoint(x: 0.8, y: 0.5),
                                            "_1": CanvasPoint(x: 0.5, y: 0.5)]))
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        let before = cue.position
        let target = try XCTUnwrap(vm.scene.allBallNodes["_1"])
        XCTAssertFalse(vm.moveDailyCue(node: cue, world: SCNVector3(0.9, before.y, 0.2), placement: .none))
        XCTAssertFalse(vm.moveDailyCue(node: cue, world: target.position, placement: .anywhere))
        XCTAssertFalse(vm.moveDailyCue(node: cue, world: SCNVector3(2, before.y, 0), placement: .anywhere))
        XCTAssertFalse(vm.moveDailyCue(node: cue, world: SCNVector3(0.2, before.y, 0.2), placement: .behindHeadString))
        XCTAssertEqual(cue.position.x, before.x)
        XCTAssertEqual(cue.position.z, before.z)
        XCTAssertTrue(vm.moveDailyCue(node: cue, world: SCNVector3(0.9, before.y, 0.2), placement: .behindHeadString))
        XCTAssertTrue(vm.moveDailyCue(node: cue, world: SCNVector3(-0.3, before.y, 0.2), placement: .anywhere))
        vm.cancelDailyAttempt()
    }

    func testRespotAvoidsOccupiedFootSpotAndRestoresPocketedNine() throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.loadBoard(BoardSnapshot(onTable: [PositionPlayBall.cueKey: CanvasPoint(x: 0.8, y: 0.25),
                                            "_1": CanvasPoint(x: 0.25, y: 0.25)]))
        let occupied = try XCTUnwrap(vm.scene.allBallNodes["_1"])
        vm.respotDailyBalls(["_9"])
        let nine = try XCTUnwrap(vm.scene.allBallNodes["_9"])
        XCTAssertFalse(nine.isHidden)
        XCTAssertTrue(vm.onTableKeys.contains("_9"))
        XCTAssertLessThan(nine.position.x, occupied.position.x)
        XCTAssertEqual(occupied.position.x - nine.position.x, 2 * BallPhysics.radius, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual((nine.position - occupied.position).length(), 2 * BallPhysics.radius - 0.0001)
        XCTAssertEqual(nine.position.z, 0, accuracy: 0.0001)
        vm.cancelDailyAttempt()
    }
}

final class DailyCombinationRecommendationTests: XCTestCase {
    private let y = BTTablePhysics.surfaceY

    private func screenshotBoard() -> BoardSnapshot {
        // Screenshot reconstruction: landscape right=+X, down=+Z, metres.
        // Both diagonal corner centres determine the projection, not the cloth rim.
        let pixels: [String: (Double, Double)] = ["cueBall": (1368,404), "_15": (1264,405),
            "_8": (399,361), "_9": (478,369), "_11": (402,463), "_4": (439,410),
            "_2": (475,425), "_13": (584,591), "_10": (815,822)]
        return BoardSnapshot(onTable: pixels.mapValues { x, z in
            let p = SCNVector3(Float((x-909.5)*2.624/1121), y,
                              Float((z-623.5)*1.354/585))
            let n = AngleSceneCalculator.sceneToNormalized(position: p)
            return CanvasPoint(x: Double(n.x), y: Double(n.y))
        })
    }

    func test_combinationUsesContactsNotPocketOrderOrOutcome() {
        let c = ShotInput.cueBallName, t = ShotInput.targetBallName
        func route(_ pairs: [(String,String)]) -> ShotPrediction {
            var p = ShotPrediction()
            p.events = pairs.enumerated().map { i, pair in
                ShotEvent(time: Float(i), kind: .ballBall(ballA: pair.0, ballB: pair.1))
            }
            return p
        }
        XCTAssertTrue(route([(c,t),(t,"_8")]).hasCombinationRoute)
        XCTAssertTrue(route([(c,"_8"),("_8",t)]).hasCombinationRoute)
        XCTAssertFalse(route([(c,t),(c,"_8")]).hasCombinationRoute,
                       "Incidental cue contact after the direct hit is not an object combination")
        var direct = route([(c,t)])
        direct.cuePocketed = true
        direct.objectPocketed = false
        direct.pocketedBalls = ["_8",c]
        XCTAssertFalse(direct.hasCombinationRoute, "Scratch, miss and another pot alone do not select a new target")
        direct.events.append(ShotEvent(time: 1, kind: .pocket(ball: t, pocketId: "pocket_0")))
        direct.events.append(ShotEvent(time: 2, kind: .ballBall(ballA: t, ballB: "_8")))
        XCTAssertFalse(direct.hasCombinationRoute, "Only contacts before the target's pot belong to its route")
    }

    func test_screenshotCombinationIsSkippedForTenWithoutChangingPower() throws {
        let board = screenshotBoard()
        let shot = PlannedShot(targetKey: "_15", pocket: try XCTUnwrap(ShotIntent.pocketId(for: 0)),
                               velocity: 3.37, spinX: 0, spinY: 0)
        let original = try XCTUnwrap(PositionPlayShotSolver.solve(before: board, shot: shot, surfaceY: y))
        XCTAssertTrue(original.hasCombinationRoute)
        let selected = try XCTUnwrap(PositionPlayShotSolver.solveDailyDirectRecommendation(before: board,
            preferred: shot, orderedTargetKeys: ["_15","_10","_13","_9","_11"], surfaceY: y))
        XCTAssertEqual(selected.shot.targetKey, "_10")
        XCTAssertFalse(selected.prediction.hasCombinationRoute)
        XCTAssertEqual(selected.shot.velocity, shot.velocity)
        XCTAssertEqual(selected.shot.spinX, shot.spinX)
        XCTAssertEqual(selected.shot.spinY, shot.spinY)
        print("DIRECT_REVIEW original=15 combination=\(original.hasCombinationRoute) selected=\(selected.shot.targetKey) pot=\(selected.prediction.objectPocketed)")
        let env = ProcessInfo.processInfo.environment
        if let out = env["DIRECT_REVIEW_OUTPUT"] ?? env["TEST_RUNNER_DIRECT_REVIEW_OUTPUT"] {
            let plots: [[String:Any]] = [(shot,original),(selected.shot,selected.prediction)].map { s,p in
                ["target": s.targetKey, "pocket": s.pocket, "combination": p.hasCombinationRoute,
                 "objectPotted": p.objectPocketed, "cuePath": p.cuePath.map { [$0.x,$0.z] },
                 "objectPath": p.objectPath.map { [$0.x,$0.z] },
                 "extras": p.extraBallPaths.mapValues { $0.map { [$0.x,$0.z] } }]
            }
            try JSONSerialization.data(withJSONObject: plots, options: [.prettyPrinted,.sortedKeys])
                .write(to: URL(fileURLWithPath: out).appendingPathComponent("routes.json"))
        }
    }

    func test_allCombinationFallsBackAndCancellationReturnsNoResult() throws {
        let board = screenshotBoard()
        let shot = PlannedShot(targetKey: "_15", pocket: try XCTUnwrap(ShotIntent.pocketId(for: 0)),
                               velocity: 3.37, spinX: 0, spinY: 0)
        let result = try XCTUnwrap(PositionPlayShotSolver.solveDailyDirectRecommendation(before: board,
            preferred: shot, orderedTargetKeys: ["_15"], surfaceY: y))
        XCTAssertEqual(result.shot.targetKey, "_15")
        XCTAssertTrue(result.prediction.hasCombinationRoute)
        let cancellation = PredictionCancellation()
        cancellation.cancel()
        XCTAssertNil(PositionPlayShotSolver.solveDailyDirectRecommendation(before: board,
            preferred: shot, orderedTargetKeys: ["_15","_10"], surfaceY: y, cancellation: cancellation))
    }

    @MainActor
    func test_asyncAutomaticReviewAndManualOwnership() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        defer { vm.cancelDailyAttempt() }
        vm.usesDailyShotRanking = true
        vm.usesAutomaticPocketFallback = true
        vm.legalAimTargets = { $0.intersection(["_9","_10","_11","_13","_15"]) }
        vm.velocity = 3.37
        vm.loadBoard(screenshotBoard())
        func ready() async throws {
            let deadline = Date().addingTimeInterval(15)
            while Date() < deadline && (vm.isComputing || vm.solvedShot == nil) {
                try await Task.sleep(for: .milliseconds(50))
            }
            XCTAssertFalse(vm.isComputing)
        }
        let initialTarget = vm.selectedTargetKey
        try await ready()
        XCTAssertEqual(vm.selectedTargetKey, initialTarget)
        if vm.aimMode == .pocket { XCTAssertEqual(vm.solvedShot?.shot.targetKey, initialTarget) }
        XCTAssertEqual(vm.entryTiming["physicalRecommendationCalls"], 0)
        XCTAssertEqual(vm.entryTiming["bankSearchCalls"], 0)
        let pocket = vm.selectedPocketIndex
        vm.velocity = 2.2
        try await ready()
        XCTAssertEqual(vm.selectedTargetKey, initialTarget)
        XCTAssertEqual(vm.selectedPocketIndex, pocket)
        vm.velocity = 3.37
        XCTAssertTrue(vm.selectTarget(key: "_15"))
        vm.selectPocket(at: 0)
        try await ready()
        XCTAssertEqual(vm.selectedTargetKey, "_15")
        XCTAssertEqual(vm.selectedPocketIndex, 0)
        if vm.aimMode == .pocket { XCTAssertEqual(vm.solvedShot?.shot.targetKey, "_15") }
        XCTAssertEqual(vm.entryTiming["physicalRecommendationCalls"], 0)
        XCTAssertEqual(vm.entryTiming["bankSearchCalls"], 0)
        vm.refreshLegalAimSelection()
        XCTAssertEqual(vm.selectedTargetKey, "_15")
    }
}

final class DailyShotRankingTests: XCTestCase {
    private let y = BTTablePhysics.surfaceY
    private func p(_ x: Float, _ z: Float) -> SCNVector3 { SCNVector3(x, y + AngleSceneCalculator.ballRadius, z) }
    private func c(_ key: String, _ angle: Double, _ pocket: Int = 0) -> AngleSceneCalculator.DailyPocketCandidate {
        .init(targetKey: key, pocketIndex: pocket, aim: p(0, 0), cutDegrees: angle)
    }

    func test_seventyFiveDegreesAcceptedAndStopsBeforeFurtherTargets() {
        var visited: [String] = []
        let result = AngleSceneCalculator.recommendDailyTarget(orderedKeys: ["near", "far"]) {
            visited.append($0)
            return [self.c($0, $0 == "near" ? 75 : 0)]
        }
        XCTAssertEqual(result?.targetKey, "near")
        XCTAssertEqual(visited, ["near"])
    }

    func test_skipsBlockedAndHardTargetsInDistanceOrder() {
        var visited: [String] = []
        let result = AngleSceneCalculator.recommendDailyTarget(orderedKeys: ["blocked", "hard", "acceptable", "further"]) {
            visited.append($0)
            switch $0 {
            case "blocked": return []
            case "hard": return [self.c($0, 75.001)]
            default: return [self.c($0, 40)]
            }
        }
        XCTAssertEqual(result?.targetKey, "acceptable")
        XCTAssertEqual(visited, ["blocked", "hard", "acceptable"])
    }

    func test_allHardUsesSmallestCutAndAllBlockedReturnsNil() {
        let result = AngleSceneCalculator.recommendDailyTarget(orderedKeys: ["near", "far"]) {
            [self.c($0, $0 == "near" ? 85 : 80)]
        }
        XCTAssertEqual(result?.targetKey, "far")
        XCTAssertNil(AngleSceneCalculator.recommendDailyTarget(orderedKeys: ["near"]) { _ in [] })
    }

    func test_manualPocketRankingKeepsHardCandidatesAvailable() {
        let result = AngleSceneCalculator.easiestDailyPocket([c("_1", 80, 0), c("_1", 70, 1)])
        XCTAssertEqual(result?.pocketIndex, 1)
        XCTAssertEqual(result?.cutDegrees, 70)
    }

    func test_jointScoreBalancesAngleAndPocketDistance() {
        var straightLong = c("_1", 10, 0)
        straightLong.cueTargetDistance = Double(AngleSceneCalculator.innerLength) * 0.2
        straightLong.targetPocketDistance = Double(AngleSceneCalculator.innerLength) * 0.8
        var cutShort = c("_1", 40, 1)
        cutShort.cueTargetDistance = straightLong.cueTargetDistance
        cutShort.targetPocketDistance = Double(AngleSceneCalculator.innerLength) * 0.2
        XCTAssertEqual(straightLong.score, (1 - 10.0 / 90) * 0.8 * 0.2, accuracy: 1e-12)
        XCTAssertEqual(AngleSceneCalculator.easiestDailyPocket([straightLong, cutShort])?.pocketIndex, 1)
        cutShort.cueTargetDistance = Double(AngleSceneCalculator.innerLength) * 2
        XCTAssertEqual(cutShort.score, 0)
        XCTAssertTrue(cutShort.score.isFinite)
    }

    func test_comfortablePocketWinsBeforeScoreAndHardFallbackUsesScore() {
        var comfortable = c("_1", 75, 0)
        comfortable.targetPocketDistance = Double(AngleSceneCalculator.innerLength) * 0.95
        let hard = c("_1", 76, 1)
        XCTAssertGreaterThan(hard.score, comfortable.score)
        XCTAssertEqual(AngleSceneCalculator.easiestDailyPocket([hard, comfortable])?.pocketIndex, 0)
        let result = AngleSceneCalculator.recommendDailyTarget(orderedKeys: ["near", "far"]) {
            var candidate = self.c($0, $0 == "near" ? 76 : 80)
            candidate.targetPocketDistance = Double(AngleSceneCalculator.innerLength) * ($0 == "near" ? 0.9 : 0.1)
            return [candidate]
        }
        XCTAssertEqual(result?.targetKey, "far")
    }

    func test_candidateDistancesUseBallCentresAndPocketCentreInMetres() throws {
        let cue = p(-0.4, 0), target = p(0, 0)
        let candidate = try XCTUnwrap(AngleSceneCalculator.dailyPocketCandidate(cue: cue,
            target: target, targetKey: "_1", pocketIndex: 1, obstacles: [], surfaceY: y))
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: y)[1]
        XCTAssertEqual(candidate.cueTargetDistance, 0.4, accuracy: 1e-6)
        XCTAssertEqual(candidate.targetPocketDistance, hypot(Double(pocket.x), Double(pocket.z)), accuracy: 1e-6)
    }

    @MainActor
    func test_dailyBlockedPocketSwitchesFreeWithoutChangingTargetOrPower() async throws {
        let vm = PositionPlayViewModel(); vm.setupScene()
        defer { vm.cancelDailyAttempt() }
        vm.usesDailyShotRanking = true; vm.usesAutomaticPocketFallback = true
        let nominal = AngleSceneCalculator.pocketPositions(surfaceY: y)[1]
        let positions = [PositionPlayBall.cueKey: p(-0.4, 0), "_1": p(0, 0),
                         "_9": p(nominal.x / 2, nominal.z / 2)]
        vm.loadBoard(BoardSnapshot(onTable: positions.mapValues {
            let n = AngleSceneCalculator.sceneToNormalized(position: $0)
            return CanvasPoint(x: Double(n.x), y: Double(n.y))
        }))
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        vm.velocity = 2.2
        vm.selectPocket(at: 1)
        XCTAssertEqual(vm.selectedPocketIndex, 1)
        XCTAssertEqual(vm.aimMode, .free)
        XCTAssertNotNil(vm.freeAimDir)
        try await Task.sleep(for: .milliseconds(750))
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        XCTAssertEqual(vm.selectedPocketIndex, 1)
        XCTAssertEqual(vm.velocity, 2.2)
        XCTAssertEqual(vm.aimMode, .free)
        XCTAssertTrue(vm.bankAlternatives.isEmpty)
    }

    func test_geometryAllowsThinBallButRejectsBothBlockedPaths() throws {
        let cue = p(-0.4, 0.05), target = p(0, 0.25)
        func candidate(_ obstacles: [SCNVector3]) -> AngleSceneCalculator.DailyPocketCandidate? {
            AngleSceneCalculator.dailyPocketCandidate(cue: cue, target: target, targetKey: "_1",
                pocketIndex: 5, obstacles: obstacles, surfaceY: y)
        }
        let thin = try XCTUnwrap(candidate([]))
        XCTAssertGreaterThan(thin.cutDegrees, 60)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: thin.aim,
            ballRadius: AngleSceneCalculator.ballRadius)
        XCTAssertNil(candidate([p((cue.x + ghost.x) / 2, (cue.z + ghost.z) / 2)]))
        XCTAssertNil(candidate([p(0, 0.45)]))
    }

    func test_sixPocketIndicesAndStraightGeometryAreSymmetric() throws {
        for (i, pocket) in AngleSceneCalculator.pocketPositions(surfaceY: y).enumerated() {
            let target = p(pocket.x * 0.5, pocket.z * 0.5)
            let cue = p(pocket.x * 0.2, pocket.z * 0.2)
            let candidate = try XCTUnwrap(AngleSceneCalculator.dailyPocketCandidate(cue: cue,
                target: target, targetKey: "_1", pocketIndex: i, obstacles: [], surfaceY: y))
            XCTAssertEqual(candidate.pocketIndex, i)
            XCTAssertEqual(candidate.cutDegrees, 0, accuracy: 0.01)
        }
    }

    func test_fullBoardGeometryTiming() {
        let balls = (0..<15).map { i in p(-0.9 + Float(i % 5) * 0.4, -0.4 + Float(i / 5) * 0.35) }
        let start = CACurrentMediaTime()
        var count = 0
        for (i, ball) in balls.enumerated() {
            for pocket in 0..<6 {
                if AngleSceneCalculator.dailyPocketCandidate(cue: p(-1.1, 0.5), target: ball,
                    targetKey: "_\(i + 1)", pocketIndex: pocket,
                    obstacles: balls.enumerated().filter { $0.offset != i }.map { $0.element }, surfaceY: y) != nil { count += 1 }
            }
        }
        print("DAILY_GEOMETRY 90 candidates ms=\((CACurrentMediaTime() - start) * 1000) viable=\(count)")
        XCTAssertGreaterThan(count, 0)
    }

    @MainActor
    func test_manualThinPocketSurvivesParametersAndAsyncPrediction() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        defer { vm.cancelDailyAttempt() }
        vm.usesDailyShotRanking = true
        vm.usesAutomaticPocketFallback = true
        vm.clearTable()
        let positions = [PositionPlayBall.cueKey: p(-0.4, 0.05), "_1": p(0, 0.25)]
        vm.loadBoard(BoardSnapshot(onTable: positions.mapValues {
            let n = AngleSceneCalculator.sceneToNormalized(position: $0)
            return CanvasPoint(x: Double(n.x), y: Double(n.y))
        }))
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        XCTAssertTrue(vm.isStraightPocketAvailable(5))
        vm.selectPocket(at: 5)
        vm.velocity = 1.8
        vm.spinY = 0.2
        vm.refreshLegalAimSelection()
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        XCTAssertEqual(vm.selectedPocketIndex, 5)
        XCTAssertEqual(vm.aimMode, .pocket)
    }
}

extension DailyShotRankingTests {
    @MainActor
    func test_dailySkipsBlockedNearestBallAndRespectsManualIntent() throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        defer { vm.cancelDailyAttempt() }
        vm.usesDailyShotRanking = true
        vm.usesAutomaticPocketFallback = true
        vm.legalAimTargets = { $0.intersection(["_1", "_2"]) }
        vm.clearTable()
        var positions: [String: SCNVector3] = [PositionPlayBall.cueKey: p(-0.5, 0), "_1": p(0, 0), "_2": p(0.3, -0.3)]
        for i in 0..<6 {
            let a = Float(i) * .pi / 3
            positions["_\(i + 3)"] = p(0.07 * cosf(a), 0.07 * sinf(a))
        }
        let board = BoardSnapshot(onTable: positions.mapValues {
            let n = AngleSceneCalculator.sceneToNormalized(position: $0)
            return CanvasPoint(x: Double(n.x), y: Double(n.y))
        })
        vm.loadBoard(board)
        vm.refreshLegalAimSelection()
        XCTAssertEqual(vm.selectedTargetKey, "_2", "Blocked nearest target must not force free aim")
        XCTAssertEqual(vm.aimMode, .pocket)
        let pocket = vm.selectedPocketIndex
        vm.selectPocket(at: pocket)
        vm.velocity = 2
        vm.refreshLegalAimSelection()
        XCTAssertEqual(vm.selectedPocketIndex, pocket)
        XCTAssertEqual(vm.selectedTargetKey, "_2")
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        XCTAssertEqual(vm.aimMode, .free, "No direct candidate must provide usable free aim")
        XCTAssertNotNil(vm.temporaryFreeReason)
        XCTAssertEqual(vm.selectedPocketIndex, -1)
        vm.refreshLegalAimSelection()
        XCTAssertEqual(vm.selectedTargetKey, "_1", "Explicit target must remain selected even if blocked")
        vm.legalAimTargets = { $0.intersection(["_2"]) }
        vm.refreshLegalAimSelection()
        XCTAssertEqual(vm.selectedTargetKey, "_2", "Rule legality overrides stale manual intent")
        vm.nudgeFreeAim(byDegrees: 3)
        let direction = try XCTUnwrap(vm.freeAimDir)
        vm.refreshLegalAimSelection()
        XCTAssertEqual(vm.aimMode, .free)
        XCTAssertEqual(vm.freeAimDir?.x, direction.x)
        XCTAssertEqual(vm.freeAimDir?.z, direction.z)
    }
}


extension DailyShotRankingTests {
    func test_railTangentIsNotRejectedForZeroClearance() {
        let z = AngleSceneCalculator.innerWidth / 2 - AngleSceneCalculator.ballRadius
        let corners: [(Int, Float, Float)] = [(0, -1, -1), (1, 1, -1), (2, -1, 1), (3, 1, 1)]
        for (index, sx, sz) in corners {
            XCTAssertNotNil(AngleSceneCalculator.dailyPocketCandidate(cue: p(0.3 * sx, z * sz),
                target: p(0.8 * sx, z * sz), targetKey: "_1", pocketIndex: index, obstacles: [], surfaceY: y))
            let x = AngleSceneCalculator.innerLength / 2 - AngleSceneCalculator.ballRadius
            XCTAssertNotNil(AngleSceneCalculator.dailyPocketCandidate(cue: p(x * sx, 0),
                target: p(x * sx, 0.3 * sz), targetKey: "_1", pocketIndex: index, obstacles: [], surfaceY: y))
        }
    }
}

extension DailyShotRankingTests {
    /// Consumer-contract fixtures deliberately vary outcome flags on one solved
    /// board. They test selection isolation, not physical truth of those outcomes.
    @MainActor
    func test_predictionOutcomesCannotFilterAutomaticOrManualSelection() throws {
        for manual in [false, true] {
            let vm = PositionPlayViewModel()
            vm.setupScene()
            defer { vm.cancelDailyAttempt() }
            vm.usesDailyShotRanking = true
            vm.usesAutomaticPocketFallback = true
            vm.refreshLegalAimSelection()
            let target = try XCTUnwrap(vm.selectedTargetKey)
            let pocket = vm.selectedPocketIndex
            if manual {
                XCTAssertTrue(vm.selectTarget(key: target))
                vm.selectPocket(at: pocket)
            }
            let availability = (0..<6).map { vm.isStraightPocketAvailable($0) }
            let before = vm.currentSnapshot()
            let shot = PlannedShot(targetKey: target, pocket: try XCTUnwrap(ShotIntent.pocketId(for: pocket)),
                                   velocity: vm.velocity, spinX: vm.spinX, spinY: vm.spinY)
            let base = try XCTUnwrap(PositionPlayShotSolver.solve(before: before, shot: shot, surfaceY: y))
            XCTAssertTrue(base.feasible)
            XCTAssertTrue(base.hasFinalTableState)
            for scratch in [false, true] {
                for pot in [false, true] {
                    var outcome = base
                    outcome.cuePocketed = scratch
                    outcome.objectPocketed = pot
                    outcome.simObjectPotted = pot
                    vm.applySolvedShot(.init(before: before, shot: shot, prediction: outcome))
                    XCTAssertEqual(vm.cuePocketed, scratch, "Prediction must still report scratch risk")
                    XCTAssertEqual(vm.objectPocketed, pot, "Prediction must still report this shot's outcome")
                    XCTAssertEqual(vm.selectedTargetKey, target)
                    XCTAssertEqual(vm.selectedPocketIndex, pocket)
                    XCTAssertEqual(vm.aimMode, .pocket)
                    XCTAssertEqual((0..<6).map { vm.isStraightPocketAvailable($0) }, availability)
                    vm.refreshLegalAimSelection()
                    XCTAssertEqual(vm.selectedTargetKey, target)
                    XCTAssertEqual(vm.selectedPocketIndex, pocket)
                }
            }
            var failed = base
            failed.feasible = false
            failed.infeasibleReason = "Injected prediction failure"
            vm.applySolvedShot(.init(before: before, shot: shot, prediction: failed))
            XCTAssertFalse(vm.isFeasible)
            XCTAssertEqual(vm.selectedTargetKey, target)
            XCTAssertEqual(vm.selectedPocketIndex, pocket)
            XCTAssertEqual(vm.aimMode, .pocket)
            XCTAssertEqual((0..<6).map { vm.isStraightPocketAvailable($0) }, availability)
            vm.refreshLegalAimSelection()
            XCTAssertEqual(vm.selectedTargetKey, target)
            XCTAssertEqual(vm.selectedPocketIndex, pocket)
        }
    }
}

extension DailyShotRankingTests {
    func test_nearRailPhysicalPotsAreNotRejectedByRecommendation() throws {
        var checked = 0
        var plots: [[String: Any]] = []
        for (sx, sz, pocket) in [(Float(-1), Float(1), 0), (1, 1, 1), (-1, -1, 2), (1, -1, 3)] {
            for z in [-0.594, -0.58, -0.56, -0.54] as [Float] {
                for x in [0.4, 0.516, 0.7, 0.9] as [Float] {
                    let cue = p(0.067 * sx, -0.313 * sz), target = p(x * sx, z * sz)
                    let candidate = AngleSceneCalculator.dailyPocketCandidate(cue: cue, target: target,
                        targetKey: "_13", pocketIndex: pocket, obstacles: [], surfaceY: y)
                    let prediction = ShotPredictor.predictForPositionSolve(ShotInput(cueBall: cue,
                        targetBall: target, pocketIndex: pocket, velocity: 3.73, spinX: 0, spinY: 0,
                        surfaceY: y, obstacles: []))
                    XCTAssertTrue(prediction.objectPocketed, "Physical near-rail pot P\(pocket), \(x), \(z)")
                    XCTAssertNotNil(candidate, "Recommendation must admit physical pot P\(pocket), \(x), \(z)")
                    checked += 1
                    if x == 0.516 && z == -0.594 {
                        let candidates = (0..<6).compactMap {
                            AngleSceneCalculator.dailyPocketCandidate(cue: cue, target: target,
                                targetKey: "_13", pocketIndex: $0, obstacles: [], surfaceY: y)
                        }
                        XCTAssertEqual(AngleSceneCalculator.easiestDailyPocket(candidates)?.pocketIndex, pocket)
                        plots.append(["pocket": pocket, "cue": [cue.x, cue.z], "target": [target.x, target.z],
                            "objectPath": prediction.objectPath.map { [$0.x, $0.z] },
                            "cuePath": prediction.cuePath.map { [$0.x, $0.z] }, "potted": prediction.objectPocketed,
                            "aim": [prediction.pocketAimPoint.x, prediction.pocketAimPoint.z]])
                    }
                }
            }
        }
        XCTAssertEqual(checked, 64)
        print("RAIL_REGRESSION physicalPots=\(checked) geometryAccepted=\(checked)")
        let env = ProcessInfo.processInfo.environment
        if let folder = env["RAIL_REVIEW_OUTPUT"] ?? env["TEST_RUNNER_RAIL_REVIEW_OUTPUT"] {
            try JSONSerialization.data(withJSONObject: plots, options: [.prettyPrinted, .sortedKeys])
                .write(to: URL(fileURLWithPath: folder).appendingPathComponent("physical-paths.json"))
        }
    }

    @MainActor
    func test_manualNearRailPocketReachesPredictionWithoutChangingIntent() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        defer { vm.cancelDailyAttempt() }
        vm.usesDailyShotRanking = true
        vm.usesAutomaticPocketFallback = true
        vm.clearTable()
        let positions = [PositionPlayBall.cueKey: p(0.067, -0.313), "_13": p(0.516, -0.594)]
        vm.loadBoard(BoardSnapshot(onTable: positions.mapValues {
            let n = AngleSceneCalculator.sceneToNormalized(position: $0)
            return CanvasPoint(x: Double(n.x), y: Double(n.y))
        }))
        XCTAssertTrue(vm.selectTarget(key: "_13"))
        var notices: [String] = []
        vm.onAimSelectionNotice = { notices.append($0) }
        vm.velocity = 3.73
        vm.spinX = 0
        vm.spinY = 0
        // Start without a pocket so accepting the tap is observable independently
        // of the automatic recommendation already having selected P1.
        vm.selectedPocketIndex = -1
        vm.selectPocket(at: 1)
        XCTAssertTrue(notices.isEmpty)
        XCTAssertEqual(vm.selectedPocketIndex, 1)
        XCTAssertEqual(vm.aimMode, .pocket)
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline && (vm.isComputing || vm.solvedShot?.shot.pocket != ShotIntent.pocketId(for: 1)) {
            try await Task.sleep(for: .milliseconds(50))
        }
        let solved = try XCTUnwrap(vm.solvedShot)
        XCTAssertEqual(solved.shot.pocket, ShotIntent.pocketId(for: 1))
        XCTAssertTrue(solved.prediction.objectPocketed)
        XCTAssertEqual(vm.selectedTargetKey, "_13")
        XCTAssertEqual(vm.selectedPocketIndex, 1)
        XCTAssertEqual(vm.velocity, 3.73)
    }

    func test_exportPocketSelectionReview() throws {
        let out = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/output/pocket-selection-review-20261001")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        func xy(_ v: SCNVector3) -> [Float] { [v.x, v.z] }
        var layouts: [(String, SCNVector3, SCNVector3, [SCNVector3])] = [
            ("01 中袋直球", p(0,-0.35), p(0,0.22), []),
            ("02 普通斜球", p(-0.6,-0.2), p(0.3,0.12), []),
            ("03 两球近距离", p(-0.1,-0.1), p(0,0), []),
            ("04 目标靠近中袋", p(-0.45,0.1), p(0.06,0.48), []),
            ("05 长库贴库球", p(0.15,0.606425), p(0.8,0.606425), []),
            ("06 障碍遮住小角度袋", p(0,-0.35), p(0,0.22), [p(0,0.46)])
        ]
        // Deterministic scan: find largest disagreement between recommendation
        // cut and the effective aim point later used by prediction. No physics.
        var mismatches: [(Double, SCNVector3, SCNVector3)] = []
        for tx in [-0.9, -0.3, 0.3, 0.9] as [Float] {
            for tz in [-0.55, -0.25, 0.25, 0.55] as [Float] {
                for cx in [-0.8, 0, 0.8] as [Float] {
                    for cz in [-0.4, 0.4] as [Float] {
                        let cue = p(cx,cz), target = p(tx,tz)
                        guard AngleSceneCalculator.horizontalDistance(cue,target) > 0.07 else { continue }
                        let candidates = (0..<6).compactMap {
                            AngleSceneCalculator.dailyPocketCandidate(cue:cue,target:target,targetKey:"_1",
                                pocketIndex:$0,obstacles:[],surfaceY:y)
                        }
                        guard let best = AngleSceneCalculator.easiestDailyPocket(candidates) else { continue }
                        let effective = AngleSceneCalculator.effectivePocketAimPoint(targetBall:target,
                            pocketIndex:best.pocketIndex,surfaceY:y)
                        let angle = AngleSceneCalculator.cutAngle(cueBall:cue,targetBall:target,pocket:effective)
                        mismatches.append((abs(angle-best.cutDegrees),cue,target))
                    }
                }
            }
        }
        for (index, item) in mismatches.sorted(by: {$0.0 > $1.0}).prefix(2).enumerated() {
            layouts.append(("0\(7+index) 推荐与预测选点差异",item.1,item.2,[]))
        }
        var rows: [[String:Any]] = []
        for (title,cue,target,obstacles) in layouts {
            let candidates = (0..<6).compactMap {
                AngleSceneCalculator.dailyPocketCandidate(cue:cue,target:target,targetKey:"_1",
                    pocketIndex:$0,obstacles:obstacles,surfaceY:y)
            }
            let best = AngleSceneCalculator.easiestDailyPocket(candidates)
            let pockets: [[String:Any]] = (0..<6).map { i in
                let nominal = AngleSceneCalculator.pocketPositions(surfaceY:y)[i]
                let effective = AngleSceneCalculator.effectivePocketAimPoint(targetBall:target,pocketIndex:i,surfaceY:y)
                let candidate = candidates.first {$0.pocketIndex == i}
                return ["index":i,"nominal":xy(nominal),"effective":xy(effective),
                        "nominalAngle":AngleSceneCalculator.cutAngle(cueBall:cue,targetBall:target,pocket:nominal),
                        "effectiveAngle":AngleSceneCalculator.cutAngle(cueBall:cue,targetBall:target,pocket:effective),
                        "viable":candidate != nil,"angle":candidate?.cutDegrees ?? -1,
                        "aim":xy(candidate?.aim ?? nominal)]
            }
            rows.append(["title":title,"cue":xy(cue),"target":xy(target),
                         "obstacles":obstacles.map(xy),"selected":best?.pocketIndex ?? -1,"pockets":pockets])
        }
        let data = try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys])
        try data.write(to:out.appendingPathComponent("results.json"))
        print("POCKET_REVIEW exported \(rows.count) layouts; scan=\(mismatches.count) largestDelta=\(mismatches.map{$0.0}.max() ?? 0)")
        XCTAssertEqual(rows.count,8)
    }
}

@MainActor
final class PocketSelectionUXTests: XCTestCase {
    private func makeVM(daily: Bool = false) -> PositionPlayViewModel {
        let vm = PositionPlayViewModel(); vm.setupScene()
        vm.usesAutomaticPocketFallback = true; vm.usesDailyShotRanking = daily
        let y = vm.scene.surfaceY + AngleSceneCalculator.ballRadius
        let points = [PositionPlayBall.cueKey: SCNVector3(-0.5, y, 0), "_1": SCNVector3(0, y, 0)]
        vm.loadBoard(.init(onTable: points.mapValues {
            let p = AngleSceneCalculator.sceneToNormalized(position: $0)
            return CanvasPoint(x: Double(p.x), y: Double(p.y))
        }))
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        return vm
    }
    private func ready(_ vm: PositionPlayViewModel) async throws {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline && (vm.isComputing || vm.solvedShot == nil) {
            try await Task.sleep(for: .milliseconds(40))
        }
        XCTAssertFalse(vm.isComputing)
        XCTAssertNotNil(vm.solvedShot)
    }

    func testUnavailableClickPreservesDirectionAndRestoresOnlyOnNewValidClick() async throws {
        for daily in [false, true] {
            let vm = makeVM(daily: daily)
            defer { vm.cancelDailyAttempt() }
            try await ready(vm)
            let original = try XCTUnwrap(vm.currentPlayerAim)
            let valid = vm.selectedPocketIndex
            vm.selectPocket(at: 0) // The target would have to travel back towards the cue.
            XCTAssertEqual(vm.aimMode, .free)
            XCTAssertEqual(vm.preferredAimMode, .pocket)
            XCTAssertEqual(vm.selectedPocketIndex, 0)
            let direction = try XCTUnwrap(vm.freeAimDir)
            XCTAssertEqual(direction.x, original.x, accuracy: 1e-5)
            XCTAssertEqual(direction.z, original.z, accuracy: 1e-5)
            try await ready(vm)
            XCTAssertEqual(vm.aimMode, .free)
            XCTAssertEqual(vm.selectedTargetKey, "_1")
            XCTAssertEqual(vm.selectedPocketIndex, 0)
            XCTAssertEqual(vm.entryTiming["bankSearchCalls"], 0)
            XCTAssertEqual(vm.entryTiming["physicalRecommendationCalls"], 0)
            XCTAssertEqual(vm.entryTiming["shotPredictionCalls"], 1)
            vm.selectPocket(at: valid)
            XCTAssertEqual(vm.aimMode, .pocket)
            XCTAssertNil(vm.temporaryFreeReason)
            try await ready(vm)
            XCTAssertEqual(vm.selectedPocketIndex, valid)
        }
    }

    func testAtomicRequestRepeatClickAndModeSwitchCancellation() async throws {
        let vm = makeVM(); defer { vm.cancelDailyAttempt() }
        try await ready(vm)
        let valid = vm.selectedPocketIndex
        vm.selectedPocketIndex = -1
        let requests = vm.entryTiming["solveRequests", default: 0]
        vm.selectPocket(at: valid)
        XCTAssertEqual(vm.entryTiming["solveRequests"], requests + 1)
        let marker = try XCTUnwrap(vm.scene.addPocketMarkers()[valid] as? PocketLeatherMarker)
        let pulse = try XCTUnwrap(marker.childNode(withName: "leather_selectionPulse", recursively: true))
        let firstAction = try XCTUnwrap(pulse.action(forKey: "pocketSelectionPulse"))
        vm.selectPocket(at: valid)
        XCTAssertEqual(vm.entryTiming["solveRequests"], requests + 1, "Repeated intent only acknowledges the click")
        XCTAssertFalse(firstAction === pulse.action(forKey: "pocketSelectionPulse"))
        vm.selectPocket(at: 0)
        XCTAssertFalse(pulse.hasActions, "Only the latest pocket may acknowledge")
        let newPulse = try XCTUnwrap(vm.scene.addPocketMarkers()[0].childNode(withName: "leather_selectionPulse", recursively: true))
        XCTAssertTrue(newPulse.hasActions)
        vm.cameraMode = .perspective3D
        XCTAssertFalse(newPulse.hasActions)
        XCTAssertEqual(vm.selectedPocketIndex, 0)
        vm.selectPocket(at: valid)
        vm.beginPowerDrag()
        XCTAssertFalse(pulse.hasActions)
    }

    func testParameterUpdatesUseCachedGeometryAndNeverRewriteIntent() async throws {
        let vm = makeVM(daily: true); defer { vm.cancelDailyAttempt() }
        try await ready(vm)
        let target = vm.selectedTargetKey, pocket = vm.selectedPocketIndex
        let geometry = vm.entryTiming["geometryEvaluations"]
        vm.velocity = 2.2
        vm.spinX = 0.1
        try await ready(vm)
        XCTAssertEqual(vm.entryTiming["geometryEvaluations"], geometry)
        XCTAssertEqual(vm.selectedTargetKey, target); XCTAssertEqual(vm.selectedPocketIndex, pocket)
        XCTAssertEqual(vm.velocity, 2.2); XCTAssertEqual(vm.spinX, 0.1)
        XCTAssertEqual(vm.entryTiming["physicalRecommendationCalls"], 0)
        XCTAssertEqual(vm.entryTiming["bankSearchCalls"], 0)
    }

    func testUndoKeepsTemporaryAndExplicitFreePreferencesDistinct() throws {
        let vm = makeVM(); defer { vm.cancelDailyAttempt() }
        vm.selectPocket(at: 0)
        let undo = vm.captureDailyUndo()
        vm.selectPocket(at: 1)
        vm.toggleAimMode()
        undo()
        XCTAssertEqual(vm.preferredAimMode, .pocket)
        XCTAssertEqual(vm.aimMode, .free)
        XCTAssertEqual(vm.selectedTargetKey, "_1"); XCTAssertEqual(vm.selectedPocketIndex, 0)
        XCTAssertNotNil(vm.temporaryFreeReason)
        vm.selectPocket(at: 1)
        XCTAssertEqual(vm.aimMode, .pocket)
        vm.toggleAimMode()
        let manualUndo = vm.captureDailyUndo()
        vm.toggleAimMode()
        manualUndo()
        XCTAssertEqual(vm.preferredAimMode, .free)
        vm.selectPocket(at: 1)
        XCTAssertEqual(vm.aimMode, .free)
    }

    func testExplicitFreeControlWhileAlreadyTemporaryFreeRemainsFreeAfterPocketTap() throws {
        let vm = makeVM(); defer { vm.cancelDailyAttempt() }
        vm.selectPocket(at: 0)
        XCTAssertNotNil(vm.temporaryFreeReason)
        vm.setPreferredAimMode(.free)
        XCTAssertNil(vm.temporaryFreeReason)
        XCTAssertEqual(vm.preferredAimMode, .free)
        vm.selectPocket(at: 1)
        XCTAssertEqual(vm.aimMode, .free)
        XCTAssertEqual(vm.preferredAimMode, .free)
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: vm.scene.surfaceY)[1]
        let expected = SCNVector3(pocket.x - cue.position.x, 0, pocket.z - cue.position.z)
        let length = hypotf(expected.x, expected.z)
        XCTAssertEqual(vm.freeAimDir?.x ?? 0, expected.x / length, accuracy: 1e-5)
        XCTAssertEqual(vm.freeAimDir?.z ?? 0, expected.z / length, accuracy: 1e-5)
    }

    func testReplacementBoardRecommendsAgainEvenWhenOldTargetStillExists() throws {
        let vm = makeVM(daily: true); defer { vm.cancelDailyAttempt() }
        vm.legalAimTargets = { $0.intersection(["_1", "_9"]) }
        let y = vm.scene.surfaceY + AngleSceneCalculator.ballRadius
        var points = [PositionPlayBall.cueKey: SCNVector3(-0.5, y, 0), "_1": SCNVector3(0, y, 0),
                      "_9": SCNVector3(0.7, y, 0.3)]
        for index in 0..<6 {
            let a = Float(index) * .pi / 3
            points["_\(index + 2)"] = SCNVector3(cos(a) * 0.07, y, sin(a) * 0.07)
        }
        let requests = vm.entryTiming["solveRequests", default: 0]
        vm.loadBoard(.init(onTable: points.mapValues {
            let p = AngleSceneCalculator.sceneToNormalized(position: $0)
            return CanvasPoint(x: Double(p.x), y: Double(p.y))
        }))
        XCTAssertEqual(vm.selectedTargetKey, "_9")
        XCTAssertEqual(vm.aimMode, .pocket)
        XCTAssertTrue(vm.isStraightPocketAvailable(vm.selectedPocketIndex))
        XCTAssertEqual(vm.entryTiming["solveRequests"], requests + 1)
    }

    func testPersistedSelectionContextRestoresTemporaryFreeAndLegacyStillDecodes() async throws {
        let vm = makeVM(); defer { vm.cancelDailyAttempt() }
        vm.selectPocket(at: 0)
        try await ready(vm)
        let solved = try XCTUnwrap(vm.solvedShot)
        let encoded = try JSONEncoder().encode(solved.shot)
        let decoded = try JSONDecoder().decode(PlannedShot.self, from: encoded)
        XCTAssertTrue(decoded.isFree)
        XCTAssertEqual(decoded.selectionContext?.prefersPocketAssist, true)
        XCTAssertEqual(decoded.selectionContext?.requestedTargetKey, "_1")
        XCTAssertEqual(decoded.selectionContext?.requestedPocketIndex, 0)
        XCTAssertNotNil(decoded.selectionContext?.temporaryFreeReason)
        let legacy = #"{"targetKey":"_1","pocket":"topRight","velocity":1.5,"spinX":0,"spinY":0}"#
        XCTAssertNil(try JSONDecoder().decode(PlannedShot.self, from: Data(legacy.utf8)).selectionContext)
        let restored = PositionPlayViewModel(); restored.setupScene()
        defer { restored.cancelDailyAttempt() }
        restored.usesAutomaticPocketFallback = true
        restored.configureSequence([.init(before: solved.before, shot: decoded, after: solved.before)])
        restored.enterSequenceMode()
        restored.exitSequenceMode()
        XCTAssertEqual(restored.preferredAimMode, .pocket)
        XCTAssertEqual(restored.aimMode, .free)
        XCTAssertEqual(restored.selectedTargetKey, "_1")
        XCTAssertEqual(restored.selectedPocketIndex, 0)
        XCTAssertNotNil(restored.temporaryFreeReason)
    }

    func testS6ManualSelectionAcknowledgesBallAndPocketImmediately() throws {
        let vm = makeVM(); defer { vm.cancelDailyAttempt() }
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        let ball = try XCTUnwrap(vm.scene.allBallNodes["_1"])
        XCTAssertNotNil(ball.action(forKey: TableBallPulse.actionKey))
        let index = vm.selectedPocketIndex
        vm.selectPocket(at:index)
        let marker = try XCTUnwrap(vm.scene.addPocketMarkers()[index] as? PocketLeatherMarker)
        let pulse = try XCTUnwrap(marker.childNode(withName:"leather_selectionPulse",recursively:true))
        XCTAssertEqual(pulse.opacity,1)
        XCTAssertFalse(pulse.isHidden)
        XCTAssertNotNil(pulse.action(forKey:"pocketSelectionPulse"))
    }

    func testAutomaticDefaultAcknowledgesOnceAndParameterRedrawDoesNotReplay() throws {
        let vm = PositionPlayViewModel(); vm.setupScene()
        defer { vm.cancelDailyAttempt() }
        let marker = try XCTUnwrap(vm.scene.addPocketMarkers()[vm.selectedPocketIndex] as? PocketLeatherMarker)
        let pulse = try XCTUnwrap(marker.childNode(withName: "leather_selectionPulse", recursively: true))
        let initial = try XCTUnwrap(pulse.action(forKey: "pocketSelectionPulse"))
        vm.velocity = 2.2
        XCTAssertTrue(initial === pulse.action(forKey: "pocketSelectionPulse"))
        XCTAssertEqual(pulse.opacity, 0, "Default acknowledgement also waits before yellow")
    }

    func testRapidTargetThenUnavailablePocketKeepsVisiblePreviewInsteadOfOldPrediction() async throws {
        let vm = makeVM(); defer { vm.cancelDailyAttempt() }
        let y = vm.scene.surfaceY + AngleSceneCalculator.ballRadius
        vm.placeFromPalette("_9", atWorld: SCNVector3(0.7, y, 0.3))
        try await ready(vm)
        XCTAssertTrue(vm.selectTarget(key: "_9"))
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        let target = try XCTUnwrap(vm.scene.allBallNodes["_9"])
        let candidate = try XCTUnwrap(AngleSceneCalculator.dailyPocketCandidate(cue: cue.position,
            target: target.position, targetKey: "_9", pocketIndex: vm.selectedPocketIndex,
            obstacles: [try XCTUnwrap(vm.scene.allBallNodes["_1"]).position], surfaceY: vm.scene.surfaceY))
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target.position,
            pocket: candidate.aim, ballRadius: AngleSceneCalculator.ballRadius)
        let length = hypotf(ghost.x - cue.position.x, ghost.z - cue.position.z)
        vm.selectPocket(at: 0)
        XCTAssertEqual(vm.aimMode, .free)
        XCTAssertEqual(vm.selectedTargetKey, "_9")
        XCTAssertEqual(vm.freeAimDir?.x ?? 0, (ghost.x - cue.position.x) / length, accuracy: 1e-5)
        XCTAssertEqual(vm.freeAimDir?.z ?? 0, (ghost.z - cue.position.z) / length, accuracy: 1e-5)
        try await ready(vm)
        XCTAssertEqual(vm.selectedTargetKey, "_9")
        XCTAssertEqual(vm.selectedPocketIndex, 0)
        XCTAssertEqual(vm.aimMode, .free)
    }

    func testMissingTargetRejectsPocketAndAllBlockedHasNoFakeRecommendation() throws {
        let vm = makeVM(daily: true); defer { vm.cancelDailyAttempt() }
        for index in 0..<6 {
            let angle = Float(index) * .pi / 3
            vm.placeFromPalette("_\(index + 2)", atWorld: SCNVector3(
                cos(angle) * 0.07, vm.scene.surfaceY + AngleSceneCalculator.ballRadius, sin(angle) * 0.07))
        }
        vm.selectTarget(key: "_1")
        XCTAssertEqual(vm.aimMode, .free)
        XCTAssertEqual(vm.selectedPocketIndex, -1)
        vm.clearTable()
        vm.selectPocket(at: 1)
        XCTAssertEqual(vm.selectedPocketIndex, -1)
        XCTAssertTrue(vm.scene.addPocketMarkers().allSatisfy { !$0.childNode(withName: "leather_selectionPulse", recursively: true)!.hasActions })
    }
}

@MainActor
final class Daily3DTrajectoryVisibilityTests: XCTestCase {
    private func waitForPrediction(_ vm: PositionPlayViewModel) async throws {
        let deadline = Date().addingTimeInterval(15)
        while vm.solvedShot == nil, Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertNotNil(vm.solvedShot, "Exercise the completed prediction, not an empty scene")
    }

    private func assertNoAssists(_ vm: PositionPlayViewModel, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(vm.scene.ghostBallNode?.isHidden == true, file: file, line: line)
        XCTAssertTrue(vm.scene.contactDotNode?.isHidden == true, file: file, line: line)
        XCTAssertNil(vm.scene.idealObjectLine, file: file, line: line)
        XCTAssertNil(vm.closeupSnapshot, file: file, line: line)
        XCTAssertFalse(vm.scene.rootNode.childNodes.contains { ["tableProjectedAssist", "freeAimPreview", "aimPointMarker"].contains($0.name ?? "") }, file: file, line: line)
    }

    func testPreferencePersistsWithoutChangingSharedDetail() throws {
        let name = "daily.3d.trajectory." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = UserPreferences(defaults: defaults)
        XCTAssertFalse(preferences.daily3DTrajectoryHidden)
        preferences.trajectoryDetail = .core
        preferences.daily3DTrajectoryHidden = true
        let restored = UserPreferences(defaults: defaults)
        XCTAssertTrue(restored.daily3DTrajectoryHidden)
        XCTAssertEqual(restored.trajectoryDetail, .core)
    }

    func testSolvedPotVisibilityDoesNotChangeShotAndRestoresIn2D() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        try await waitForPrediction(vm)
        let solved = try XCTUnwrap(vm.solvedShot)
        let target = vm.selectedTargetKey, pocket = vm.selectedPocketIndex
        let power = vm.velocity, spinX = vm.spinX, spinY = vm.spinY
        vm.cameraMode = .perspective3D
        let cueHidden = vm.scene.cueStick?.rootNode.isHidden
        vm.hides3DShotAssists = true
        assertNoAssists(vm)
        XCTAssertEqual(vm.scene.cueStick?.rootNode.isHidden, cueHidden)
        XCTAssertEqual(vm.selectedTargetKey, target)
        XCTAssertEqual(vm.selectedPocketIndex, pocket)
        XCTAssertEqual(vm.velocity, power)
        XCTAssertEqual(vm.spinX, spinX)
        XCTAssertEqual(vm.spinY, spinY)
        XCTAssertEqual(vm.solvedShot?.prediction.aimDirection.x, solved.prediction.aimDirection.x)
        XCTAssertEqual(vm.solvedShot?.prediction.aimDirection.z, solved.prediction.aimDirection.z)
        vm.cameraMode = .topDown2D
        XCTAssertTrue(vm.showsShotAssists)
        XCTAssertFalse(try XCTUnwrap(vm.scene.ghostBallNode).isHidden)
        vm.cameraMode = .perspective3D
        assertNoAssists(vm)
        vm.hides3DShotAssists = false
        XCTAssertFalse(try XCTUnwrap(vm.scene.ghostBallNode).isHidden)
    }

    func testFreeAimPreviewAndLatePredictionStayHiddenButCueStillWorks() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.aimMode = .free
        vm.cameraMode = .perspective3D
        vm.hides3DShotAssists = true
        let target = try XCTUnwrap(vm.scene.allBallNodes["_1"])
        vm.handleTableTap(world: target.position)
        vm.setAimWheelDragging(true)
        vm.nudgeFreeAim(byDegrees: 0.1)
        assertNoAssists(vm)
        XCTAssertFalse(try XCTUnwrap(vm.scene.cueStick).rootNode.isHidden)
        vm.setAimWheelDragging(false)
        // Wait for the new intent rather than accepting setupScene's old result.
        let deadline = Date().addingTimeInterval(15)
        while (vm.solvedShot?.shot.isFree != true || vm.isComputing), Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(vm.solvedShot?.shot.isFree, true)
        assertNoAssists(vm)
        vm.cameraMode = .topDown2D
        vm.nudgeFreeAim(byDegrees: 0.1)
        XCTAssertNotNil(vm.scene.idealObjectLine)
        XCTAssertFalse(try XCTUnwrap(vm.scene.ghostBallNode).isHidden)
    }

    func testReenablingWhileNewAimIsPendingDoesNotDrawPreviousPrediction() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        try await waitForPrediction(vm)
        vm.cameraMode = .perspective3D
        vm.hides3DShotAssists = true
        vm.aimMode = .free
        let target = try XCTUnwrap(vm.scene.allBallNodes["_1"])
        vm.handleTableTap(world: target.position)
        vm.nudgeFreeAim(byDegrees: 0.2)
        let direction = try XCTUnwrap(vm.freeAimDir)
        vm.hides3DShotAssists = false
        XCTAssertFalse(vm.scene.rootNode.childNodes.contains { $0.name == "tableProjectedAssist" },
                       "Only the current geometric preview is valid while the new shot is pending")
        XCTAssertNotNil(vm.scene.idealObjectLine)
        XCTAssertEqual(vm.freeAimDir?.x, direction.x)
        XCTAssertEqual(vm.freeAimDir?.z, direction.z)
    }

    func testOpeningRackGuidesFollowDimensionWithoutChangingBreakIntent() throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.hides3DShotAssists = true
        vm.cameraMode = .perspective3D
        vm.startBreakFlow(game: .nineBall, seed: 42)
        let runner = try XCTUnwrap(vm.breakRunner)
        runner.nudgeAim(byDegrees: 0.2)
        let aim = try XCTUnwrap(runner.aimDir)
        XCTAssertFalse(runner.showsAimAssist)
        assertNoAssists(vm)
        XCTAssertFalse(try XCTUnwrap(vm.scene.cueStick).rootNode.isHidden)
        vm.cameraMode = .topDown2D
        XCTAssertTrue(runner.showsAimAssist)
        XCTAssertTrue(vm.scene.rootNode.childNodes.contains { $0.name == "tableProjectedAssist" })
        XCTAssertEqual(runner.aimDir?.x, aim.x)
        XCTAssertEqual(runner.aimDir?.z, aim.z)
        XCTAssertEqual(runner.seed, 42)
        XCTAssertEqual(runner.phase, .racked)
        vm.cancelBreakFlow()
    }
}

@MainActor
final class ContinuousTrajectoryPreviewTests: XCTestCase {
    private func ready(file: StaticString = #filePath, line: UInt = #line, _ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(15)
        while !predicate(), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(predicate(), "Timed out waiting for preview state", file: file, line: line)
    }

    private func makeVM() async throws -> PositionPlayViewModel {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.clearTable()
        vm.usesContinuousTrajectoryPreview = true
        vm.placeFromPalette(PositionPlayBall.cueKey, atWorld: SCNVector3(-0.5, vm.scene.surfaceY + BallPhysics.radius, 0))
        vm.placeFromPalette("_1", atWorld: SCNVector3(0, vm.scene.surfaceY + BallPhysics.radius, 0))
        vm.aimMode = .free
        vm.handleTableTap(world: SCNVector3(0.5, vm.scene.surfaceY, 0))
        vm.velocity = 1.5
        try await ready { vm.solvedShot != nil && !vm.isComputing }
        return vm
    }

    func testContinuousPowerDeliversBeforeReleaseAndFinalShotMatches() async throws {
        let vm = try await makeVM()
        defer { vm.clearTable() }
        let before = vm.currentSnapshot()
        vm.beginPowerDrag()
        let start = CACurrentMediaTime()
        for i in 0..<70 {
            vm.velocity = 1.5 + Double(i) / 100
            vm.play()
            XCTAssertFalse(vm.isPlaying, "A changing preview must never authorize a shot")
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertGreaterThan(vm.entryTiming["livePreviewDuringDrag", default: 0], 1,
                             "Continuous input must not starve every solve until release")
        let preview = try XCTUnwrap(vm.livePreviewShot)
        XCTAssertTrue(preview.prediction.hasFinalTableState)
        XCTAssertFalse(preview.prediction.extraBallPaths.isEmpty, "The struck object ball also needs its full trajectory")
        XCTAssertEqual(vm.currentSnapshot().onTable.mapValues { [$0.x, $0.y] }, before.onTable.mapValues { [$0.x, $0.y] })
        vm.endPowerDrag(commit: true)
        try await ready { !vm.isComputing && vm.solvedShot?.shot.velocity == vm.velocity }
        XCTAssertFalse(vm.isPlaying)
        let final = try XCTUnwrap(vm.solvedShot)
        let independent = try XCTUnwrap(PositionPlayShotSolver.solve(before: before, shot: final.shot, surfaceY: vm.scene.surfaceY))
        XCTAssertEqual(final.prediction.cuePath.map { [$0.x, $0.y, $0.z] }, independent.cuePath.map { [$0.x, $0.y, $0.z] })
        print("LIVE_POWER deliveries=\(vm.entryTiming["livePreviewDuringDrag", default: 0]) wall=\(CACurrentMediaTime()-start) finalMs=\(vm.entryTiming["directMs", default: 0])")
    }

    func testContinuousDirectionDeliversAndClearRejectsLateResults() async throws {
        let vm = try await makeVM()
        defer { vm.clearTable() }
        vm.setAimWheelDragging(true)
        for _ in 0..<70 {
            vm.nudgeFreeAim(byDegrees: 0.01)
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertGreaterThan(vm.entryTiming["livePreviewDuringDrag", default: 0], 1)
        vm.setAimWheelDragging(false)
        try await ready { !vm.isComputing }
        let shot = try XCTUnwrap(vm.solvedShot?.shot)
        let dir = try XCTUnwrap(vm.freeAimDir)
        let expected = PositionPlayShotSolver.canvasDirection(fromScene: dir)
        XCTAssertEqual(shot.freeAim?.x, expected.x)
        XCTAssertEqual(shot.freeAim?.y, expected.y)
        vm.nudgeFreeAim(byDegrees: 1)
        vm.clearTable()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertNil(vm.livePreviewShot)
        XCTAssertNil(vm.solvedShot)
        XCTAssertFalse(vm.isComputing)
        XCTAssertFalse(vm.isPlaying)
    }

    func testSelectionAndLeavingInvalidatePreview() async throws {
        let vm = try await makeVM()
        defer { vm.clearTable() }
        vm.beginPowerDrag()
        vm.velocity = 2.0
        try await ready { vm.livePreviewShot != nil }
        vm.velocity = 2.1
        vm.cancelPowerRelease()
        vm.usesAutomaticPocketFallback = true
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        XCTAssertNil(vm.livePreviewShot)
        try await ready { !vm.isComputing && vm.solvedShot?.shot.targetKey == "_1" }
        vm.beginPowerDrag()
        vm.velocity = 2.2
        vm.cancelInteractiveTrajectoryPreview()
        let count = vm.entryTiming["livePreviewDeliveries", default: 0]
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertNil(vm.livePreviewShot)
        XCTAssertEqual(vm.entryTiming["livePreviewDeliveries", default: 0], count)
        XCTAssertFalse(vm.isComputing)
        vm.play()
        XCTAssertFalse(vm.isPlaying, "A cancelled preview cannot play a stale solved shot")
    }
}
