import XCTest
import SceneKit
@testable import QiuJi

/// v23 W2 接线实证：每个接入页的 VM 真的按「母球→首碰球」杠杆臂给出毫米口径增益，
/// 而不是继续吃 0.15°/pt。只断语义（毫米标定 + 比旧档细），杠杆臂由场景节点独立量出。
///
/// 坐标契约：SceneKit 世界 X–Z 水平面、Y 朝上，单位米；杠杆臂 = XZ 平面球心距。
@MainActor
final class AimWheelGainWiringTests: XCTestCase {

    /// 断言某页增益 = 该杠杆臂下的毫米标定值，且比旧固定档细。
    private func assertMillimeterCalibrated(
        gain: Float, lever: Float, file: StaticString = #filePath, line: UInt = #line
    ) {
        let mm = AimWheelGain.millimetersPerPoint(degreesPerPoint: gain, distanceMeters: lever)
        XCTAssertEqual(mm, AimWheelGain.targetMillimetersPerPoint, accuracy: 0.02,
                       "杠杆臂 \(lever) m 处应约 0.4 mm/pt，实测 \(mm)", file: file, line: line)
        XCTAssertLessThan(gain, AimWheelGain.defaultDegreesPerPoint,
                          "毫米档应比旧 0.15°/pt 细（lever=\(lever)）", file: file, line: line)
    }

    private func planarDistance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        hypotf(a.x - b.x, a.z - b.z)
    }

    private func waitUntil(_ done: @escaping () -> Bool, timeout: TimeInterval = 60) {
        let exp = expectation(description: "idle")
        func poll() {
            if done() { exp.fulfill(); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { poll() }
        }
        poll()
        wait(for: [exp], timeout: timeout)
    }

    // MARK: - FreePlay / Composer / ShotSimulation（共用 PositionPlayViewModel）

    func test_positionPlay_gain_locksOntoAimedBall_notNearestBall() {
        let vm = PositionPlayViewModel()
        vm.setupScene()

        // 母球在 (-0.5, 0)；瞄准方向 +X 正前方 0.95 m 处有 "_8"；
        // 侧后方另有更近的 "_1"（不在射线上）⇒ 杠杆臂必须取被瞄的那颗。
        let y = BTTablePhysics.surfaceY + AngleSceneCalculator.ballRadius
        func norm(_ x: Float, _ z: Float) -> CanvasPoint {
            let n = AngleSceneCalculator.sceneToNormalized(position: SCNVector3(x, y, z))
            return CanvasPoint(x: Double(n.x), y: Double(n.y))
        }
        vm.aimMode = .free
        vm.loadBoard(BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: norm(-0.5, 0),
            "_8": norm(0.45, 0),
            "_1": norm(-0.75, 0.05),
        ]))
        guard let cue = vm.scene.allBallNodes[PositionPlayBall.cueKey],
              let aimed = vm.scene.allBallNodes["_8"],
              let aside = vm.scene.allBallNodes["_1"] else {
            return XCTFail("球形未上桌")
        }
        vm.handleTableTap(world: SCNVector3(aimed.position.x, cue.position.y, aimed.position.z))

        let lever = planarDistance(cue.position, aimed.position)
        XCTAssertLessThan(planarDistance(cue.position, aside.position), lever,
                          "用例前提：侧方那颗更近，否则本测不区分首碰与最近")
        assertMillimeterCalibrated(gain: vm.aimWheelDegreesPerPoint, lever: lever)
    }

    func test_positionPlay_emptyTableFallsBackToLegacyGain() {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.aimMode = .free
        vm.loadBoard(BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.25, y: 0.5),
        ]))
        XCTAssertEqual(vm.aimWheelDegreesPerPoint, AimWheelGain.defaultDegreesPerPoint,
                       accuracy: 1e-6, "桌上只有母球 ⇒ 无杠杆臂 ⇒ 回落旧固定档")
    }

    // MARK: - 翻袋 / 反射解球器（SolverStageChrome 宿主）

    func test_bankShot_gain_isMillimeterCalibrated() {
        let vm = BankShotViewModel()
        vm.setupScene()
        waitUntil({ !vm.isSolving })
        guard let cue = vm.scene.cueBallNode,
              let target = vm.scene.targetBallNodes.first else {
            return XCTFail("翻袋页缺母球/目标球")
        }
        let lever = planarDistance(cue.position, target.position)
        assertMillimeterCalibrated(gain: vm.aimWheelDegreesPerPoint, lever: lever)
    }

    func test_diamondSystem_gain_isMillimeterCalibrated() {
        let vm = DiamondSystemViewModel()
        vm.setupScene()
        waitUntil({ !vm.isSolving })
        guard let cue = vm.scene.cueBallNode,
              let target = vm.scene.targetBallNodes.first else {
            return XCTFail("反射页缺母球/目标球")
        }
        let lever = planarDistance(cue.position, target.position)
        assertMillimeterCalibrated(gain: vm.aimWheelDegreesPerPoint, lever: lever)
    }

    // MARK: - 开球（BreakInstrumentsOverlay 宿主）

    func test_breakFlow_gain_usesRackLever() {
        let scene = AngleTrainingScene()
        scene.setupScene()
        let runner = BreakFlowRunner(scene: scene, game: .chineseEightBall, seed: 7)
        runner.rackUp()
        guard let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden else {
            return XCTFail("开球缺母球")
        }
        // 默认锁顶球（`BreakSimulator.aimAtApex` = x 最大者）⇒ 首碰 = 球堆顶球。
        let rackNodes = scene.allBallNodes
            .filter { !PositionPlayBall.isCue($0.key) && !$0.value.isHidden }
            .map(\.value.position)
        guard let apex = rackNodes.max(by: { $0.x < $1.x }) else {
            return XCTFail("球堆未上桌")
        }
        let lever = planarDistance(cue.position, apex)
        assertMillimeterCalibrated(gain: runner.aimWheelDegreesPerPoint, lever: lever)
    }
}
