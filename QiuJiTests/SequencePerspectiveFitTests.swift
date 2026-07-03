//
//  SequencePerspectiveFitTests.swift
//  QiuJiTests
//
//  3D 静态斜视角取景 fit 几何验证（ADR-P11-15）。
//
//  独立复算（不复用 solver 内部投影）以交叉验证 `solvePerspectiveCamera`：
//   1. 球桌外框 8 角点（库顶高）全部落入视锥 + fitMargin 余量 → 保证「全台可见」不变量；
//   2. 解出的距离是「最小可行」（至少一角点贴近余量边界，未过度后退）；
//   3. 相机→近端球的视线在近库顶之上（俯角不至于被近库遮挡近端球）。
//
//  几何技能要求：结论以可批量断言的不变量表达，而非肉眼「看着对」。
//

import XCTest
import SceneKit
@testable import QiuJi

final class SequencePerspectiveFitTests: XCTestCase {

    private let halfL: Float = SequenceVideoExporter.tableOuterHalfLength
    private let halfW: Float = SequenceVideoExporter.tableOuterHalfWidth
    private let surfaceY: Float = 0.80   // TablePhysics 台面高（与 solver 入参口径一致）

    private let phone = CGSize(width: 720, height: 1280)
    private let hi = CGSize(width: 1440, height: 2560)

    // MARK: - 不变量 1+2：外框全可见 且 距离最小可行

    func test_allCornersFitWithinFrustum_phone() {
        assertCornersFit(config: .init(), size: phone)
    }

    func test_allCornersFitWithinFrustum_hi() {
        assertCornersFit(config: .init(), size: hi)
    }

    /// 竖屏取向下换不同俯角/FOV 仍恒满足全可见（随机批量不变量）。
    func test_allCornersFit_acrossPitchAndFov() {
        for pitch: Float in [28, 30, 34, 40, 45] {
            for fov: Float in [42, 46, 50] {
                var cfg = SequenceVideoExporter.Perspective3DConfig()
                cfg.pitchDeg = pitch
                cfg.fovDeg = fov
                assertCornersFit(config: cfg, size: phone, label: "θ=\(pitch) fov=\(fov)")
            }
        }
    }

    private func assertCornersFit(
        config: SequenceVideoExporter.Perspective3DConfig,
        size: CGSize,
        label: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let sol = SequenceVideoExporter.solvePerspectiveCamera(
            config: config, renderSize: size, surfaceY: surfaceY
        )
        // 解出的距离应落在合理区间（不贴脸、不退到天边）。
        XCTAssertGreaterThan(sol.distance, 2.0, "距离过近 \(label)", file: file, line: line)
        XCTAssertLessThan(sol.distance, 9.0, "距离过远 \(label)", file: file, line: line)

        let aspect = Float(size.width / size.height)
        let vfov = config.fovDeg * .pi / 180
        let hfov = 2 * atan(aspect * tan(vfov / 2))
        let halfV = vfov / 2
        let halfH = hfov / 2
        let limit = Float(1 - config.fitMargin)

        // 相机基（与 solver 同约定独立复算）。
        let f = (sol.lookAt - sol.position).normalized()
        let right = f.cross(SCNVector3(0, 1, 0)).normalized()
        let upC = right.cross(f).normalized()

        // 全台可见不变量：库顶平面 + 桌腿底平面（地面）8 角点全部入框。
        let railTop = surfaceY + 0.05
        let legBottom = config.fitFullTableHeight ? surfaceY - BTTablePhysics.height : railTop
        let corners: [SCNVector3] = [railTop, legBottom].flatMap { y in
            [SCNVector3(-halfL, y, -halfW), SCNVector3(-halfL, y, halfW),
             SCNVector3( halfL, y, -halfW), SCNVector3( halfL, y, halfW)]
        }
        var maxRatio: Float = 0
        for p in corners {
            let v = p - sol.position
            let depth = v.dot(f)
            XCTAssertGreaterThan(depth, 0, "角点在相机背后 \(label)", file: file, line: line)
            let ax = abs(atan2(v.dot(right), depth))
            let ay = abs(atan2(v.dot(upC), depth))
            // 必须落在「FOV×(1−margin)」内（留安全余量，不贴边裁切）。
            XCTAssertLessThanOrEqual(ax, halfH * limit + 1e-4, "横向出框 \(label)", file: file, line: line)
            XCTAssertLessThanOrEqual(ay, halfV * limit + 1e-4, "纵向出框 \(label)", file: file, line: line)
            maxRatio = max(maxRatio, max(ax / (halfH * limit), ay / (halfV * limit)))
        }
        // 最小可行：至少一角点贴近余量边界（说明没有过度后退浪费画幅）。
        XCTAssertGreaterThan(maxRatio, 0.97, "取景过松（距离非最小可行）\(label)", file: file, line: line)
    }

    // MARK: - 不变量 3：近库不遮挡近端球

    func test_nearRailDoesNotOccludeNearBall() {
        let cfg = SequenceVideoExporter.Perspective3DConfig()  // θ=30 默认
        let sol = SequenceVideoExporter.solvePerspectiveCamera(
            config: cfg, renderSize: phone, surfaceY: surfaceY
        )
        // 相机在 +X 端：近端球在 +X playfield 内极限 ≈ +1.24，球心高 = surfaceY+ballRadius。
        let ballX: Float = 1.24
        let ballY = surfaceY + AngleSceneCalculator.ballRadius
        let railX: Float = 1.34          // 近端短库顶近似 X
        let railTop = surfaceY + 0.05    // 近似库顶高

        // 相机→近端球的视线在 railX 处的高度，应高于库顶。
        let cam = sol.position
        let t = (cam.x - railX) / (cam.x - ballX)
        let sightY = cam.y + t * (ballY - cam.y)
        XCTAssertGreaterThan(sightY, railTop,
                             "θ=\(cfg.pitchDeg)° 近库遮挡近端球：sightY=\(sightY) ≤ railTop=\(railTop)")
    }

    // MARK: - 取景端切换对称性

    func test_nearEndFlipIsMirrored() {
        var plus = SequenceVideoExporter.Perspective3DConfig(); plus.nearEnd = .plusX
        var minus = SequenceVideoExporter.Perspective3DConfig(); minus.nearEnd = .minusX
        let sp = SequenceVideoExporter.solvePerspectiveCamera(config: plus, renderSize: phone, surfaceY: surfaceY)
        let sm = SequenceVideoExporter.solvePerspectiveCamera(config: minus, renderSize: phone, surfaceY: surfaceY)
        XCTAssertEqual(sp.distance, sm.distance, accuracy: 1e-3, "两端取景距离应对称相等")
        XCTAssertEqual(sp.position.x, -sm.position.x, accuracy: 1e-3, "两端相机 X 应镜像")
    }
}
