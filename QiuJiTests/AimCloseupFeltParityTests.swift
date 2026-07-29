import SceneKit
import SwiftUI
import XCTest
@testable import QiuJi

/// The loupe fakes the table with a flat fill, so "does it look like the felt"
/// is a measurable question, not a taste one: render both through the same
/// plain (non-enhanced) pipeline the 2D aim pages use and compare pixels.
///
/// Guards UR-20260728: the fill used the `btTableFelt` UI token, which is ~40/255
/// bluer than the rendered cloth and read as a teal sticker on the table.
@MainActor
final class AimCloseupFeltParityTests: XCTestCase {

    /// Max per-channel difference (0…1) that still reads as "the same cloth".
    /// Flat fill (v23.8) should land well inside this; keep room for ImageRenderer
    /// colour-management drift vs SCNRenderer.
    private let tolerance: CGFloat = 0.05

    func test_loupeFillMatchesRenderedFelt() throws {
        let felt = try renderedFeltColor()
        let loupe = try loupeFillColor()
        print(String(format: "felt=(%.3f,%.3f,%.3f) loupe=(%.3f,%.3f,%.3f)",
                     felt.0, felt.1, felt.2, loupe.0, loupe.1, loupe.2))

        XCTAssertEqual(loupe.0, felt.0, accuracy: tolerance, "红通道偏离台呢")
        XCTAssertEqual(loupe.1, felt.1, accuracy: tolerance, "绿通道偏离台呢")
        XCTAssertEqual(loupe.2, felt.2, accuracy: tolerance, "蓝通道偏离台呢")

        // Hue order of billiard cloth: green ≫ red > blue. Catches a fill that
        // lands inside the tolerance box but drifts toward teal.
        XCTAssertGreaterThan(loupe.1, loupe.0)
        XCTAssertGreaterThan(loupe.0, loupe.2)
    }

    // MARK: - Renderers

    /// Table felt as the 2D aim pages actually render it (plain pipeline,
    /// rotated top-down), sampled as the median of a patch left of the centre
    /// spot so table markings do not bias it.
    private func renderedFeltColor() throws -> (CGFloat, CGFloat, CGFloat) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("无 Metal 设备")
        }
        let size = CGSize(width: 400, height: 800)
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        let rig = try XCTUnwrap(scene.cameraRig)
        scene.hideAllBalls()
        scene.hideCueStick()
        rig.topDownPanOffset = .zero
        rig.fitRotatedTable(viewSize: size)
        rig.applyTopDown2DRotated()

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.autoenablesDefaultLighting = false
        let image = try XCTUnwrap(renderer.snapshot(atTime: 0, with: size,
                                                    antialiasingMode: .none))
        return try medianColor(of: image,
                               patch: CGRect(x: size.width * 0.32, y: size.height * 0.34,
                                             width: 24, height: 24))
    }

    /// Loupe background only — no ball / line layers.
    private func loupeFillColor() throws -> (CGFloat, CGFloat, CGFloat) {
        let snapshot = AimCloseupSnapshot(
            band: .contact,
            focus: .zero,
            ballRadius: 0.02625,
            halfWorld: 0.084,
            showsTargetBall: false
        )
        let renderer = ImageRenderer(content:
            BTAimCloseupHUD(snapshot: snapshot).frame(width: 128, height: 128))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage)
        // Off-centre patch: dead centre is where markers would sit.
        return try medianColor(of: image,
                               patch: CGRect(x: 44, y: 44, width: 12, height: 12))
    }

    // MARK: - Pixel sampling

    private func medianColor(of image: UIImage,
                             patch: CGRect) throws -> (CGFloat, CGFloat, CGFloat) {
        let cg = try XCTUnwrap(image.cgImage)
        let w = cg.width, h = cg.height
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let ctx = try XCTUnwrap(CGContext(
            data: &buffer, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var reds: [CGFloat] = [], greens: [CGFloat] = [], blues: [CGFloat] = []
        for y in Int(patch.minY)..<Int(patch.maxY) where y >= 0 && y < h {
            for x in Int(patch.minX)..<Int(patch.maxX) where x >= 0 && x < w {
                let o = (y * w + x) * 4
                reds.append(CGFloat(buffer[o]) / 255)
                greens.append(CGFloat(buffer[o + 1]) / 255)
                blues.append(CGFloat(buffer[o + 2]) / 255)
            }
        }
        XCTAssertFalse(reds.isEmpty, "采样区为空")
        func median(_ v: [CGFloat]) -> CGFloat { v.sorted()[v.count / 2] }
        return (median(reds), median(greens), median(blues))
    }
}
