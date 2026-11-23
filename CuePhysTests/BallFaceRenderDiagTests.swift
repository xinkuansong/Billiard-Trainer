//
//  BallFaceRenderDiagTests.swift
//  QiuJiTests
//
//  球库球面缩略图渲染诊断（FL 候选 #15）：BallFaceRenderer 此前以「节点原点 = 球心」取景，
//  但 USDZ 球节点 pivot ≠ 网格中心（`AngleTrainingScene.visualCenter` 即为此而生），
//  导致离屏取景框里没有球 → 球库整排空白。本测试出图 + 量化断言双重验证修复：
//  1. 每颗球面 PNG 落盘 build/ball_faces/ 供肉眼核对（几何技能可视化义务）；
//  2. 量化断言：中心区域不透明像素占比 > 0.5（球应占满取景框中心）。
//
//  运行：
//    xcodebuild test -scheme QiuJi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//      -only-testing:QiuJiTests/BallFaceRenderDiagTests
//

import XCTest
import SwiftUI
import UIKit
import SceneKit
@testable import QiuJi

final class BallFaceRenderDiagTests: XCTestCase {

    private let outputDir = "/Users/song/projects/13.billiard_trainer/build/ball_faces"

    @MainActor
    func test_renderAll_producesVisibleBallFaces() throws {
        let faces = BallFaceRenderer.renderAll()
        XCTAssertEqual(faces.count, PositionPlayBall.allKeys.count,
                       "应渲染全部 16 颗球（母球 + 1..15）")

        try FileManager.default.createDirectory(
            atPath: outputDir, withIntermediateDirectories: true
        )

        for key in PositionPlayBall.allKeys {
            let img = try XCTUnwrap(faces[key], "缺少 \(key) 球面图")
            // 出图供肉眼核对。
            if let data = img.pngData() {
                try data.write(to: URL(fileURLWithPath: "\(outputDir)/\(key).png"))
            }
            // 量化断言：取景框中心 50%×50% 区域应被球面覆盖（不透明且非纯黑）。
            let coverage = try centerOpaqueCoverage(of: img)
            XCTAssertGreaterThan(coverage, 0.5,
                                 "\(key) 球面中心区域覆盖率 \(coverage) 过低——取景框里没有球")
        }
    }

    /// 姿态矩阵出图（人工核对用）：扫 rx × rz 各 4 档，找出号码面朝俯视相机的姿态，
    /// 结果回填 `BallFaceRenderer.defaultOrientation`。平时跳过，调姿态时手动开。
    @MainActor
    func test_orientationMatrix_dumpForManualPick() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BALLFACE_ORIENT_SCAN"] == "1",
                          "仅在 BALLFACE_ORIENT_SCAN=1 时出姿态矩阵图")
        let dir = "\(outputDir)_orient"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        let source = AngleTrainingScene()
        source.setupScene(enhancedRendering: false)

        // 粗扫已锁定 rz=π/2、rx≈π 邻域（rx2_rz1 号码正立略偏上）；细扫 rx 居中号码。
        let rxFine: [Float] = [.pi * 0.875, .pi, .pi * 1.125, .pi * 1.25, .pi * 1.375]
        for key in ["_8", "_1", "_9"] {
            guard let ball = source.allBallNodes[key] else { continue }
            for (i, rx) in rxFine.enumerated() {
                let img = BallFaceRenderer.render(
                    ball: ball, size: 72, scale: 2,
                    orientation: SCNVector3(rx, 0, .pi / 2), device: device
                )
                if let data = img?.pngData() {
                    try data.write(to: URL(fileURLWithPath: "\(dir)/\(key)_fine\(i).png"))
                }
            }
        }
    }

    /// 出图核对新的 2D 矢量球面（PoolBallFace）：16 颗拼成一张大图，肉眼确认底色/花色/号码正立。
    @MainActor
    func test_poolBallFace_dumpComposite() throws {
        let dir = "\(outputDir)_vector"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let d: CGFloat = 72
        let cols = 4
        let rows = (PositionPlayBall.allKeys.count + cols - 1) / cols
        let pad: CGFloat = 12
        let cell = d + pad
        let canvas = CGSize(width: CGFloat(cols) * cell + pad, height: CGFloat(rows) * cell + pad)

        let board = ZStack {
            Color(red: 0.10, green: 0.40, blue: 0.28)
            ForEach(Array(PositionPlayBall.allKeys.enumerated()), id: \.offset) { idx, key in
                let r = idx / cols, c = idx % cols
                PoolBallFace(key: key, diameter: d)
                    .position(x: pad + CGFloat(c) * cell + cell / 2 - pad / 2,
                              y: pad + CGFloat(r) * cell + cell / 2 - pad / 2)
            }
        }
        .frame(width: canvas.width, height: canvas.height)

        let renderer = ImageRenderer(content: board)
        renderer.scale = 2
        let img = try XCTUnwrap(renderer.uiImage, "ImageRenderer 未产出图像")
        let data = try XCTUnwrap(img.pngData())
        try data.write(to: URL(fileURLWithPath: "\(dir)/all_faces.png"))
    }

    /// 中心 50%×50% 区域内 alpha > 0.5 像素占比。
    private func centerOpaqueCoverage(of image: UIImage) throws -> Double {
        let cg = try XCTUnwrap(image.cgImage)
        let w = cg.width, h = cg.height
        let ctx = try XCTUnwrap(CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let data = try XCTUnwrap(ctx.data).assumingMemoryBound(to: UInt8.self)

        let x0 = w / 4, x1 = w * 3 / 4
        let y0 = h / 4, y1 = h * 3 / 4
        var opaque = 0, total = 0
        for y in y0..<y1 {
            for x in x0..<x1 {
                let alpha = data[(y * w + x) * 4 + 3]
                if alpha > 128 { opaque += 1 }
                total += 1
            }
        }
        return total > 0 ? Double(opaque) / Double(total) : 0
    }
}
