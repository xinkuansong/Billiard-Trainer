//
//  PositioningFormationRenderTests.swift
//  QiuJiTests
//
//  调研用：把从权威教材提取的 positioning 球形（仅摆球布局、不画轨迹）用现有
//  AngleTrainingScene + USDZ 球桌渲染成 2D 顶视 PNG，供肉眼核对球的布局是否合理。
//
//  仅供内容调研，不进运行时。运行：
//    xcodebuild test -scheme QiuJi \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//      -only-testing:QiuJiTests/PositioningFormationRenderTests
//

import XCTest
import SceneKit
import UIKit
@testable import QiuJi

final class PositioningFormationRenderTests: XCTestCase {

    private let outputDir = "/Users/song/projects/13.billiard_trainer/build/positioning_formations"

    /// 一组球形：母球 + 若干编号球，坐标用归一化 Canvas 系（x:0–1, y:0–0.5）。
    private struct Formation {
        let id: String
        let cue: CGPoint
        let balls: [(key: String, p: CGPoint)]
    }

    @MainActor
    func test_renderPositioningFormations() throws {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let formations: [Formation] = [
            // 球形 A — Revised Wagon Wheel（单目标球 + 绕台辐条靶）
            Formation(id: "A_wagonwheel", cue: CGPoint(x: 0.5, y: 0.20), balls: [
                ("_8", CGPoint(x: 0.5, y: 0.375)),
                ("_1", CGPoint(x: 0.625, y: 0.478)),
                ("_2", CGPoint(x: 0.75, y: 0.478)),
                ("_3", CGPoint(x: 0.965, y: 0.375)),
                ("_4", CGPoint(x: 0.965, y: 0.25)),
                ("_5", CGPoint(x: 0.965, y: 0.125)),
                ("_6", CGPoint(x: 0.875, y: 0.022)),
                ("_7", CGPoint(x: 0.75, y: 0.022))
            ]),
            // 球形 B — L-Drill / Around-the-Corner（3 短库 + 2 长库，全打一角）
            Formation(id: "B_Ldrill", cue: CGPoint(x: 0.55, y: 0.30), balls: [
                ("_1", CGPoint(x: 0.965, y: 0.375)),
                ("_2", CGPoint(x: 0.965, y: 0.25)),
                ("_3", CGPoint(x: 0.965, y: 0.125)),
                ("_4", CGPoint(x: 0.75, y: 0.478)),
                ("_5", CGPoint(x: 0.625, y: 0.478))
            ]),
            // 球形 C — 蛇彩 / 中线串珠（交替打上下中袋）
            Formation(id: "C_snake", cue: CGPoint(x: 0.78, y: 0.13), balls: [
                ("_1", CGPoint(x: 0.70, y: 0.25)),
                ("_2", CGPoint(x: 0.55, y: 0.25)),
                ("_3", CGPoint(x: 0.40, y: 0.25))
            ]),
            // 球形 D — 直线球组合走位（c039，线列直球）
            Formation(id: "D_line_c039", cue: CGPoint(x: 0.45, y: 0.30), balls: [
                ("_1", CGPoint(x: 0.55, y: 0.40)),
                ("_2", CGPoint(x: 0.70, y: 0.43)),
                ("_3", CGPoint(x: 0.85, y: 0.46))
            ]),
            // 球形 E — 入位球基础（c037）：key 球进下右角，母球留位打 money 球进上右角
            Formation(id: "E_keyball_c037", cue: CGPoint(x: 0.40, y: 0.20), balls: [
                ("_1", CGPoint(x: 0.55, y: 0.32)),   // key ball → bottomRight
                ("_8", CGPoint(x: 0.85, y: 0.20))    // money ball → topRight
            ]),
            // 球形 F — 不吃库短距离走位（c034）：进 1 号，母球不吃库走到 2 号位
            Formation(id: "F_nocushion_c034", cue: CGPoint(x: 0.42, y: 0.25), balls: [
                ("_1", CGPoint(x: 0.60, y: 0.27)),   // 当前球 → bottomRight
                ("_2", CGPoint(x: 0.78, y: 0.18))    // 下一颗（走位目标参照）
            ])
        ]

        var written: [String] = []
        for f in formations {
            guard let img = render(f), let png = img.pngData(), png.count > 2_000 else {
                XCTFail("渲染失败：\(f.id)")
                continue
            }
            print("FORMATION-SIZE \(f.id) \(Int(img.size.width))x\(Int(img.size.height))")
            let path = "\(outputDir)/\(f.id).png"
            try png.write(to: URL(fileURLWithPath: path))
            written.append(path)
            add(XCTAttachment(image: img))
        }

        print("FORMATION-RENDER done: \(written.count)/\(formations.count) → \(outputDir)")
        written.forEach { print("FORMATION-PNG \($0)") }
        // 自检：球桌外框宽高比 + 球真实占比（不依赖人工确认）。
        let scene = AngleTrainingScene(); scene.setupScene(enhancedRendering: false)
        let (halfL, halfW) = tableOuterHalfExtents(scene)
        let worldWidth = 2 * halfL * 1.04
        let ballFrac = Double(2 * AngleSceneCalculator.ballRadius) / worldWidth
        print(String(format: "SELFCHECK tableAspect=%.3f ballWidthFrac=%.4f (real 0.0571m/%.3fm)",
                     halfL / halfW, ballFrac, worldWidth))
        XCTAssertEqual(written.count, formations.count)
    }

    @MainActor
    private func render(_ f: Formation,
                        pixelHeight: CGFloat = 720,
                        ballScale: Float = 1.0) -> UIImage? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }

        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        guard scene.cameraNode != nil else { return nil }
        let surfaceY = scene.surfaceY

        scene.hideAllBalls()
        scene.hideCueStick()

        func toScene(_ p: CGPoint) -> SCNVector3 {
            AngleSceneCalculator.normalizedToScene(point: p, surfaceY: surfaceY)
        }

        scene.showBall(key: "cueBall", scenePosition: toScene(f.cue))
        for b in f.balls {
            scene.showBall(key: b.key, scenePosition: toScene(b.p))
        }

        // 顶视下真实球偏小 → 略放大可见球节点（仅视觉，不动坐标）。
        for (_, node) in scene.visibleBalls() {
            node.scale = SCNVector3(node.scale.x * ballScale,
                                    node.scale.y * ballScale,
                                    node.scale.z * ballScale)
        }

        // 按球桌真实外框（含木框）测包围盒，定图片宽高比与取景 —— 让台子按真实比例铺满画面。
        let (halfL, halfW) = tableOuterHalfExtents(scene)
        let margin = 1.04
        let aspect = halfL / halfW
        if let rig = scene.cameraRig {
            rig.topDownOrthographicScale = halfW * margin   // 垂直半高 = 半宽 + 余量
            rig.topDownPanOffset = .zero
            rig.applyTopDown2D()
        }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.autoenablesDefaultLighting = false

        let pixelSize = CGSize(width: (pixelHeight * CGFloat(aspect)).rounded(), height: pixelHeight)
        return renderer.snapshot(atTime: 0, with: pixelSize, antialiasingMode: .multisampling4X)
    }

    /// 复刻 AngleTrainingScene.measuredTableOuterHalfExtents（私有）：遍历台桌节点世界包围盒。
    @MainActor
    private func tableOuterHalfExtents(_ scene: AngleTrainingScene) -> (Double, Double) {
        guard let table = scene.tableNode else { return (1.36, 0.78) }
        var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude, maxZ = -Float.greatestFiniteMagnitude
        table.enumerateHierarchy { node, _ in
            guard node.geometry != nil else { return }
            let (bMin, bMax) = node.boundingBox
            for c in [SCNVector3(bMin.x, bMin.y, bMin.z), SCNVector3(bMax.x, bMin.y, bMin.z),
                      SCNVector3(bMin.x, bMin.y, bMax.z), SCNVector3(bMax.x, bMin.y, bMax.z),
                      SCNVector3(bMin.x, bMax.y, bMin.z), SCNVector3(bMax.x, bMax.y, bMin.z),
                      SCNVector3(bMin.x, bMax.y, bMax.z), SCNVector3(bMax.x, bMax.y, bMax.z)] {
                let w = node.convertPosition(c, to: nil)
                minX = min(minX, w.x); maxX = max(maxX, w.x)
                minZ = min(minZ, w.z); maxZ = max(maxZ, w.z)
            }
        }
        guard maxX > minX, maxZ > minZ else { return (1.36, 0.78) }
        return (Double(max(abs(minX), abs(maxX))), Double(max(abs(minZ), abs(maxZ))))
    }
}
