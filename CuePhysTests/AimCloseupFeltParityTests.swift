import SceneKit
import SwiftUI
import XCTest
@testable import QiuJi

/// Compare the actual SwiftUI loupe background against an independently rendered
/// live table. The old plain-pipeline sampled RGB is no longer the reference.
@MainActor
final class AimCloseupFeltParityTests: XCTestCase {

    /// Max per-channel difference (0…1) that still reads as "the same cloth".
    /// Allow ImageRenderer resampling/colour management versus SCNRenderer.
    private let tolerance: CGFloat = 0.05

    func test_loupeFillMatchesRenderedFelt() throws {
        for cloth in ClothColor.allCases {
            try assertParity(cloth: cloth, room: .tournament)
        }
        for room in [RoomStyle.walnut, .eastern] {
            try assertParity(cloth: .green, room: room)
        }
    }

    private func assertParity(cloth: ClothColor, room: RoomStyle) throws {
        let felt = try renderedFeltColor(cloth: cloth, room: room)
        let image = try XCTUnwrap(TableFigureRenderer.closeupFelt(clothColor: cloth, roomStyle: room))
        let loupe = try loupeFillColor(image: image)
        let attachment = XCTAttachment(image: image)
        attachment.name = "felt-\(cloth.rawValue)-\(room.rawValue)"
        attachment.lifetime = .keepAlways
        add(attachment)
        print(String(format: "felt=(%.3f,%.3f,%.3f) loupe=(%.3f,%.3f,%.3f)",
                     felt.0, felt.1, felt.2, loupe.0, loupe.1, loupe.2))

        XCTAssertEqual(loupe.0, felt.0, accuracy: tolerance, "红通道偏离台呢")
        XCTAssertEqual(loupe.1, felt.1, accuracy: tolerance, "绿通道偏离台呢")
        XCTAssertEqual(loupe.2, felt.2, accuracy: tolerance, "蓝通道偏离台呢")

        if cloth == .green {
            XCTAssertGreaterThan(loupe.1, loupe.0)
            XCTAssertGreaterThan(loupe.1, loupe.2)
        }
    }

    func test_clothAndRoomCacheKeysDoNotReuseStaleAppearance() throws {
        TableFigureRenderer.resetCache()
        let green = try XCTUnwrap(TableFigureRenderer.closeupFelt(clothColor: .green, roomStyle: .tournament))
        let blue = try XCTUnwrap(TableFigureRenderer.closeupFelt(clothColor: .tournamentBlue, roomStyle: .tournament))
        let walnut = try XCTUnwrap(TableFigureRenderer.closeupFelt(clothColor: .green, roomStyle: .walnut))
        XCTAssertFalse(green === blue)
        XCTAssertFalse(green === walnut)
        XCTAssertTrue(green === TableFigureRenderer.closeupFelt(clothColor: .green, roomStyle: .tournament))
        let legacy = try XCTUnwrap(TableFigureRenderer.backdrop(orientation: .portrait, aspect: 1,
            closeup: (CGPoint(x: 0, y: CGFloat(AngleSceneCalculator.innerWidth) / 4),
                      CGFloat(AngleSceneCalculator.ballRadius) * AimCloseupBuilder.halfWorldMultiple),
            heightPoints: 128, scale: 3))
        XCTAssertFalse(legacy.image === green, "Historical teaching images must retain a separate cache entry")
    }

    func testMissingMaterialNeverShowsLegacySwatchDuringMount() throws {
        let snapshot = AimCloseupSnapshot(band: .contact, focus: .zero, ballRadius: 0.028575,
                                          halfWorld: 0.09144, showsTargetBall: false)
        let renderer = ImageRenderer(content: BTAimCloseupHUD(snapshot: snapshot)
            .frame(width: 128, height: 128).background(Color(uiColor: .magenta)))
        let color = try medianColor(of: XCTUnwrap(renderer.uiImage), patch: CGRect(x: 44, y: 44, width: 12, height: 12))
        XCTAssertEqual(color.0, 1, accuracy: 0.01)
        XCTAssertEqual(color.1, 0, accuracy: 0.01, "No green/RGB fallback may be drawn before the texture arrives")
        XCTAssertEqual(color.2, 1, accuracy: 0.01)
    }

    func testMaterialIdentityRejectsPreviousClothAndRoomBeforeReplacementArrives() {
        let image = UIImage()
        let old = AimCloseupFeltFrame(clothColor: .green, roomStyle: .tournament, image: image)
        XCTAssertTrue(old.image(matching: .green, room: .tournament) === image)
        XCTAssertNil(old.image(matching: .tournamentBlue, room: .tournament))
        XCTAssertNil(old.image(matching: .green, room: .walnut))
        let replacement = AimCloseupFeltFrame(clothColor: .tournamentBlue, roomStyle: .walnut, image: UIImage())
        XCTAssertNotNil(replacement.image(matching: .tournamentBlue, room: .walnut))
        XCTAssertNil(replacement.image(matching: .green, room: .tournament))
    }

    // MARK: - Renderers

    /// Independent production scene, sampled away from the centre spot.
    private func renderedFeltColor(cloth: ClothColor, room: RoomStyle) throws -> (CGFloat, CGFloat, CGFloat) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("无 Metal 设备")
        }
        let size = CGSize(width: 128, height: 128)
        let scene = AngleTrainingScene()
        scene.setupScene(recipe: .liveReference, roomStyle: room)
        XCTAssertTrue(scene.applyClothColor(cloth))
        let rig = try XCTUnwrap(scene.cameraRig)
        scene.hideAllBalls()
        scene.hideCueStick()
        rig.topDownPanOffset = CGPoint(x: 0, y: CGFloat(AngleSceneCalculator.innerWidth) / 4)
        rig.topDownOrthographicScale = Double(AngleSceneCalculator.ballRadius) * Double(AimCloseupBuilder.halfWorldMultiple)
        rig.applyTopDown2DRotated()

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.autoenablesDefaultLighting = false
        let image = try XCTUnwrap(renderer.snapshot(atTime: 0, with: size,
                                                    antialiasingMode: .multisampling4X))
        return try medianColor(of: image,
                               patch: CGRect(x: 44, y: 44, width: 12, height: 12))
    }

    /// Loupe background only — no ball / line layers.
    private func loupeFillColor(image: UIImage) throws -> (CGFloat, CGFloat, CGFloat) {
        let snapshot = AimCloseupSnapshot(
            band: .contact,
            focus: .zero,
            ballRadius: 0.02625,
            halfWorld: 0.084,
            showsTargetBall: false
        )
        let renderer = ImageRenderer(content:
            BTAimCloseupHUD(snapshot: snapshot, feltImage: image).frame(width: 128, height: 128))
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
