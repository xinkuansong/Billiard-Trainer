import XCTest
import SwiftUI
@testable import QiuJi

/// `BTShotHUDBar` 导出路径回归（ADR-P11-13）。
///
/// 该组件由 `SequenceVideoExporter.makeHUDImage`（离屏 `ImageRenderer`）与 App 内
/// `DrillSceneView` 共用。导出档必须保持「固定宽度力度条 + `fixedSize` 展开」的
/// 像素契约：条高恰为 `80 * k`，且文本不被压窄竖排折行（宽度须远大于高度）。
@MainActor
final class BTShotHUDBarRenderTests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/hud-bar-render"
    )

    override func setUpWithError() throws {
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    /// 教学视频档：`hudStripHeight = 120` ⇒ `k = 1.5`，与 `Options.teachingVideo()` 同参。
    func test_exportPreset_rendersExpectedStripGeometry() throws {
        let k: CGFloat = 120 / 80
        let renderer = ImageRenderer(content: BTShotHUDBar(
            spinX: -0.2, spinY: 0.3, velocity: 3.4,
            k: k, powerBarWidth: 220 * k, fixedWidth: true
        ))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage, "导出档 HUD 条应能离屏渲染")

        XCTAssertEqual(image.height, 120, "条高须恰为 80·k，否则 composeWithHUD 会错位")
        XCTAssertGreaterThan(image.width, 600, "文本被压窄竖排折行时宽度会塌陷")

        try write(image, name: "export-k1.5")
    }

    /// App 内窄容器档：力度条自适应剩余宽度，整条宽度受外部约束。
    func test_appPreset_adaptivePowerBarFitsNarrowContainer() throws {
        let k: CGFloat = 0.62
        let renderer = ImageRenderer(content: BTShotHUDBar(
            spinX: 0, spinY: 0, velocity: 1.5,
            k: k, powerBarWidth: nil, fixedWidth: false
        ).frame(width: 359))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage, "App 档 HUD 条应能渲染")

        XCTAssertEqual(image.width, 359, "自适应档须完全贴合给定容器宽度，不得溢出")
        XCTAssertEqual(image.height, Int((80 * k).rounded()), accuracy: 1, "条高须为 80·k")

        try write(image, name: "app-k0.62-w359")
    }

    private func write(_ image: CGImage, name: String) throws {
        let data = try XCTUnwrap(UIImage(cgImage: image).pngData())
        try data.write(to: outDir.appendingPathComponent("\(name).png"))
    }
}
