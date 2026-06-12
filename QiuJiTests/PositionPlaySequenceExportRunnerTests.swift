//
//  PositionPlaySequenceExportRunnerTests.swift
//  QiuJiTests
//
//  走位序列 JSON → 视频/GIF 离线复现 runner（ADR-P11-04，#11）。
//
//  用法：
//    1. 把走位编排台「录制」分享出的序列 JSON 放进 `build/position_play_sequences/`；
//    2. 项目根执行 `cd scripts && make position-export`（或 Xcode 直接跑本测试）；
//    3. 产物（<名称>.mp4 + <名称>.gif）输出到 `build/position_play_export/`。
//
//  原理：解码 `PositionPlaySequence` → `SequenceVideoExporter` 逐 Step 用物理引擎
//  （`PositionPlayShotSolver` → `ShotPredictor`）真实复现轨迹 → SceneKit 离屏逐帧渲染。
//

import XCTest
import UIKit
@testable import QiuJi

final class PositionPlaySequenceExportRunnerTests: XCTestCase {

    private let inputDir = "/Users/song/projects/13.billiard_trainer/build/position_play_sequences"
    private let outputDir = "/Users/song/projects/13.billiard_trainer/build/position_play_export"

    @MainActor
    func test_exportAllSequences() async throws {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: inputDir, withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let jsonFiles = (try? fm.contentsOfDirectory(atPath: inputDir))?
            .filter { $0.lowercased().hasSuffix(".json") }
            .sorted() ?? []
        try XCTSkipIf(jsonFiles.isEmpty,
                      "无输入：把走位序列 JSON 放进 \(inputDir) 后重跑（make position-export）")

        // 与编排台 `shareSequenceJSON` 编码策略对齐（iso8601 日期）。
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var ok = 0
        var failed: [String] = []
        for file in jsonFiles {
            let inURL = URL(fileURLWithPath: "\(inputDir)/\(file)")
            let baseName = inURL.deletingPathExtension().lastPathComponent
            do {
                let sequence = try decoder.decode(PositionPlaySequence.self,
                                                  from: Data(contentsOf: inURL))
                guard !sequence.steps.isEmpty else {
                    failed.append("\(file)(空序列)")
                    continue
                }

                let mp4 = try await SequenceVideoExporter.exportVideo(sequence: sequence)
                let mp4Out = URL(fileURLWithPath: "\(outputDir)/\(baseName).mp4")
                try? fm.removeItem(at: mp4Out)
                try fm.moveItem(at: mp4, to: mp4Out)

                let gif = try SequenceVideoExporter.exportGIF(sequence: sequence)
                let gifOut = URL(fileURLWithPath: "\(outputDir)/\(baseName).gif")
                try? fm.removeItem(at: gifOut)
                try fm.moveItem(at: gif, to: gifOut)

                ok += 1
                print("SEQ-EXPORT ✅ \(baseName)：\(sequence.steps.count) 杆 → mp4 + gif")
            } catch {
                failed.append("\(file)(\(error.localizedDescription))")
            }
        }

        print("SEQ-EXPORT done: \(ok)/\(jsonFiles.count) → \(outputDir)")
        if !failed.isEmpty { print("SEQ-EXPORT failures: \(failed.joined(separator: ", "))") }
        XCTAssertTrue(failed.isEmpty, "序列复现失败：\(failed.joined(separator: ", "))")
    }
}
