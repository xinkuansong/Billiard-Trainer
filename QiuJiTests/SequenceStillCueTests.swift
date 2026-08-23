//
//  SequenceStillCueTests.swift
//  QiuJiTests
//
//  精讲静帧须与视频「亮方案」拍同口径：有预告线时摆瞄准位球杆（DR-074）。
//  用同一序列开关 `showCueStroke` 对拍 s01_still，差必须大到能解释为整支杆，
//  而不是抗锯齿噪声。
//

import XCTest
import UIKit
@testable import QiuJi

final class SequenceStillCueTests: XCTestCase {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @MainActor
    func test_renderStills_shotFrameDiffersWhenCueEnabled() throws {
        let sequence = try loadStraightShotSequence()
        var withCue = SequenceVideoExporter.Options.teaching()
        withCue.size = CGSize(width: 360, height: 640)
        withCue.showCueStroke = true
        var noCue = withCue
        noCue.showCueStroke = false

        let withFrames = SequenceVideoExporter.renderStills(sequence: sequence, options: withCue)
        let noFrames = SequenceVideoExporter.renderStills(sequence: sequence, options: noCue)
        XCTAssertFalse(withFrames.isEmpty, "无 Metal / 渲染失败：renderStills 返回空")
        XCTAssertEqual(withFrames.map(\.name), noFrames.map(\.name))

        let withShot = try XCTUnwrap(withFrames.first { $0.name == "s01_still" }?.image)
        let noShot = try XCTUnwrap(noFrames.first { $0.name == "s01_still" }?.image)
        XCTAssertEqual(withShot.width, noShot.width)
        XCTAssertEqual(withShot.height, noShot.height)

        writeEvidence(withShot, name: "s01_with_cue.png")
        writeEvidence(noShot, name: "s01_no_cue.png")
        if let final = withFrames.first(where: { $0.name == "final" })?.image {
            writeEvidence(final, name: "final_after_cue.png")
        }

        let shotDiff = differingOpaquePixels(withShot, noShot)
        let total = withShot.width * withShot.height
        // 顶视一支杆远大于抗锯齿噪声；取 0.15% 为下限（360×640 ≈ 345 px）。
        // 终局图不对拍：`placeBoard` 首次会随机重坐母球朝向，两次独立渲染本就会差一圈球面。
        XCTAssertGreaterThan(
            shotDiff, max(300, total / 700),
            "开杆静帧开关球杆后像素差过小（\(shotDiff)/\(total)），杆可能没画上")
    }

    // MARK: - Helpers

    private func loadStraightShotSequence() throws -> PositionPlaySequence {
        let seqDir = repoRoot.appendingPathComponent("content/position_play/sequences")
        let name = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(atPath: seqDir.path)
                .first { $0.hasPrefix("drill_c001__") && $0.hasSuffix(".json") },
            "缺 c001 序列：\(seqDir.path)")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            PositionPlaySequence.self,
            from: Data(contentsOf: seqDir.appendingPathComponent(name)))
    }

    private func writeEvidence(_ image: CGImage, name: String) {
        let dir = repoRoot.appendingPathComponent("build/still-cue-evidence")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        if let data = UIImage(cgImage: image).pngData() {
            try? data.write(to: url)
        }
    }

    private func differingOpaquePixels(_ a: CGImage, _ b: CGImage) -> Int {
        let width = a.width
        let height = a.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var bufA = [UInt8](repeating: 0, count: height * bytesPerRow)
        var bufB = [UInt8](repeating: 0, count: height * bytesPerRow)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctxA = CGContext(
                data: &bufA, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: space, bitmapInfo: info),
              let ctxB = CGContext(
                data: &bufB, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: space, bitmapInfo: info)
        else { return 0 }
        ctxA.draw(a, in: CGRect(x: 0, y: 0, width: width, height: height))
        ctxB.draw(b, in: CGRect(x: 0, y: 0, width: width, height: height))
        var count = 0
        var i = 0
        while i < bufA.count {
            if bufA[i] != bufB[i] || bufA[i + 1] != bufB[i + 1] || bufA[i + 2] != bufB[i + 2] {
                count += 1
            }
            i += bytesPerPixel
        }
        return count
    }
}
