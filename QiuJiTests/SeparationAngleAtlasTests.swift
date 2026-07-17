import XCTest
import SceneKit
@testable import QiuJi

/// v11 Y3：「分离角图谱」spinY 档位 / 轨迹切片 / 90° 法则不变量。
final class SeparationAngleAtlasTests: XCTestCase {

    func testSpinYLevels_endpointsEqualMiscueLimit() {
        let levels = SeparationAngleAtlasGeometry.spinYLevels()
        XCTAssertEqual(levels.count, 8)
        let limit = CuePhysics.miscueLimitFraction
        XCTAssertEqual(levels.first!, limit, accuracy: 1e-6, "首档 = +miscueLimit（纯高杆）")
        XCTAssertEqual(levels.last!, -limit, accuracy: 1e-6, "末档 = −miscueLimit（纯低杆）")
        // 均匀：相邻差相等
        let step = levels[0] - levels[1]
        for i in 1..<levels.count {
            XCTAssertEqual(levels[i - 1] - levels[i], step, accuracy: 1e-6)
        }
        XCTAssertEqual(SeparationAngleAtlasGeometry.trackColors.count, 8,
                       "页内 8 色板与档位数一致")
    }

    func testPathSlice_startsAtBallBall_endsAtFirstCueCushion() {
        let sY = BTTablePhysics.surfaceY
        let scene = SeparationAngleAtlasGeometry.defaultTeachingScene()
        let y = SeparationAngleAtlasGeometry.sceneKitBallY(surfaceY: sY)
        let cue = SCNVector3(Float(scene.cue.x), y, Float(scene.cue.y))
        let target = SCNVector3(Float(scene.target.x), y, Float(scene.target.y))
        let aim = SCNVector3(Float(scene.aimDir.x), 0, Float(scene.aimDir.y))

        let pred = ShotPredictor.simulateFree(
            cueBall: cue, aimDir: aim, velocity: 2.5,
            spinX: 0, spinY: 0,
            surfaceY: sY,
            balls: [ObstacleBall(name: ShotInput.targetBallName, position: target)]
        )

        let bb = SeparationAngleAtlasGeometry.firstBallBallEvent(in: pred.events)
        let cushion = SeparationAngleAtlasGeometry.firstCueCushionAfterBallBall(in: pred.events)
        XCTAssertNotNil(bb, "应发生球-球碰撞")
        XCTAssertNotNil(cushion, "碰后母球应吃库")
        guard let bb, let cushion else { return }
        XCTAssertGreaterThan(cushion.time, bb.time)

        let slice = SeparationAngleAtlasGeometry.pathAfterContactToFirstCueCushion(pred)
        XCTAssertGreaterThanOrEqual(slice.count, 2, "切片应有折线段")

        if let recorder = pred.recorder,
           let start = recorder.stateAt(ballName: ShotInput.cueBallName, time: bb.time),
           let end = recorder.stateAt(ballName: ShotInput.cueBallName, time: cushion.time) {
            let d0 = hypotf(slice.first!.x - start.position.x, slice.first!.z - start.position.z)
            let d1 = hypotf(slice.last!.x - end.position.x, slice.last!.z - end.position.z)
            XCTAssertLessThan(d0, 0.03, "切片起点应贴近首次球-球碰撞位置")
            XCTAssertLessThan(d1, 0.03, "切片终点应贴近母球首个 ballCushion 位置")
        } else {
            XCTFail("simulateFree 应提供 recorder 与事件")
        }
    }

    /// v11 Y3 返工 r1：低力度纯低杆（1.5 m/s, spinY=−0.5）碰后回拖停球、不吃库，
    /// 切片须降级为「碰撞点 → 停球点」而非返回空（默认态 8 条轨迹齐全的保障）。
    func testPathSlice_lowPowerDraw_noCushion_fallsBackToStopPoint() {
        let sY = BTTablePhysics.surfaceY
        let scene = SeparationAngleAtlasGeometry.defaultTeachingScene()
        let y = SeparationAngleAtlasGeometry.sceneKitBallY(surfaceY: sY)
        let cue = SCNVector3(Float(scene.cue.x), y, Float(scene.cue.y))
        let target = SCNVector3(Float(scene.target.x), y, Float(scene.target.y))
        let aim = SCNVector3(Float(scene.aimDir.x), 0, Float(scene.aimDir.y))

        let pred = ShotPredictor.simulateFree(
            cueBall: cue, aimDir: aim, velocity: 1.5,
            spinX: 0, spinY: -CuePhysics.miscueLimitFraction,
            surfaceY: sY,
            balls: [ObstacleBall(name: ShotInput.targetBallName, position: target)]
        )

        let bb = SeparationAngleAtlasGeometry.firstBallBallEvent(in: pred.events)
        XCTAssertNotNil(bb, "应发生球-球碰撞")
        // 前置条件：本场景碰后确实不吃库（若引擎行为变化导致吃库，此测试场景需重选）
        XCTAssertNil(SeparationAngleAtlasGeometry.firstCueCushionAfterBallBall(in: pred.events),
                     "预期低力度纯低杆碰后停球、不吃库（根因场景复现）")

        let slice = SeparationAngleAtlasGeometry.pathAfterContactToFirstCueCushion(pred)
        XCTAssertGreaterThanOrEqual(slice.count, 2, "未吃库时切片应降级为碰撞点→停球点，不得为空")

        guard let bb, let recorder = pred.recorder,
              let start = recorder.stateAt(ballName: ShotInput.cueBallName, time: bb.time),
              let stop = pred.cuePath.last else {
            XCTFail("simulateFree 应提供 recorder 与轨迹")
            return
        }
        let d0 = hypotf(slice.first!.x - start.position.x, slice.first!.z - start.position.z)
        let d1 = hypotf(slice.last!.x - stop.x, slice.last!.z - stop.z)
        XCTAssertLessThan(d0, 0.03, "切片起点应贴近首次球-球碰撞位置")
        XCTAssertLessThan(d1, 0.03, "切片终点应贴近母球停球点")
    }

    func testStunHighSpeed_postContactDirApproximatelyTangent() {
        let sY = BTTablePhysics.surfaceY
        let scene = SeparationAngleAtlasGeometry.defaultTeachingScene()
        let y = SeparationAngleAtlasGeometry.sceneKitBallY(surfaceY: sY)
        let cue = SCNVector3(Float(scene.cue.x), y, Float(scene.cue.y))
        let target = SCNVector3(Float(scene.target.x), y, Float(scene.target.y))
        let aim = SCNVector3(Float(scene.aimDir.x), 0, Float(scene.aimDir.y))

        // 中杆 + 较高速度：接触时仍接近滑动 → 90° 法则
        let pred = ShotPredictor.simulateFree(
            cueBall: cue, aimDir: aim, velocity: 4.0,
            spinX: 0, spinY: 0,
            surfaceY: sY,
            balls: [ObstacleBall(name: ShotInput.targetBallName, position: target)]
        )
        let slice = SeparationAngleAtlasGeometry.pathAfterContactToFirstCueCushion(pred)
        XCTAssertGreaterThanOrEqual(slice.count, 2, "应有碰后轨迹")
        guard let postDir = SeparationAngleAtlasGeometry.postContactInitialDir(slice) else {
            XCTFail("无法取碰后首段方向")
            return
        }

        let n = SCNVector3(Float(scene.potDir.x), 0, Float(scene.potDir.y))
        let tangent = SeparationAngleAtlasGeometry.tangentDir(aim: aim, lineOfCenters: n)
        let dot = abs(postDir.x * tangent.x + postDir.z * tangent.z)
        // 引擎含球面摩擦/投掷与滚动过渡；容差 ~32°（cos32°≈0.85）仍远优于随机方向。
        // 数值草稿：`build/y3-evidence/y3-stun-tangent-measure.txt`
        XCTAssertGreaterThan(dot, 0.85,
                             "中杆高速碰后首段应近似切线方向（90° 法则），dot=\(dot)")
    }
}
