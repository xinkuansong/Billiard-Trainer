//
//  PositionPlaySequenceExportRunnerTests.swift
//  QiuJiTests
//
//  走位序列 JSON → 教学素材默认配方 离线出片 runner（ADR-P11-04 / P11-10 / P11-11，#11）。
//
//  用法：
//    1. 模拟器上用走位编排台「录制」，结束后 JSON 自动直写 `content/position_play/sequences/`
//       （真相源，进 git）；临时试渲也可手动丢 JSON 进 `build/position_play_sequences/` 收件箱；
//    2. 项目根执行 `cd scripts && make position-export`（自动同步内容库 → 收件箱后渲染；
//       或 Xcode 直接跑本测试，只消费收件箱）；
//    3. 产物按默认配方输出到 `build/position_play_export/seq_<id8>/`：
//         cover.png               卡片风格封面（球放大，首杆 before + 预告线，1280×640）
//         preview/frame_NN.png    卡片风格动画帧序列（整段抽样 12 帧，1280×640）
//         initial.png / final.png 开局 / 终局布局（竖版真实风格 1440×2560，长轴沿屏幕长边）
//         sNN_still.png           每杆击球前静帧（带预告线，竖版教学配图 1440×2720）
//         full.mp4                整段视频（2D 顶视 1440×2720；每杆预告线静帧→出杆线消失→运动→收尾）
//         sNN.mp4                 单杆视频（2D 顶视 1440×2720）
//         full.gif                整段分享 GIF（竖版 2D 顶视 720×1280）
//         full_3d.mp4 / sNN_3d.mp4  3D 静态斜视角视频（手机档 1440×2720，App 内竖屏播放）
//         full_3d@2160.mp4        3D 高分档整段视频（4K 竖版 2160×4080，外站备用）
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

    /// 超重序列（杆数 ≥ 阈值）跳过 4K `full_3d@2160.mp4`：13 杆 4K(2160×4080) 逐帧离屏渲染实测
    /// 会耗尽模拟器内 App 内存/触发测试超时而崩溃（5 杆可渲、8 杆起崩），故超重序列不出「外站备用」
    /// 4K；App 内竖屏播放用的手机档 `full_3d.mp4` 仍正常产出。见 content/position_play/README.md。
    private let heavy4KSkipThreshold = 6

    private func exports4K(_ sequence: PositionPlaySequence) -> Bool {
        sequence.steps.count < heavy4KSkipThreshold
    }

    @MainActor
    func test_exportAllSequences() async throws {
        let fm = FileManager.default
        // 续跑开关：环境变量在 `xcodebuild test` 下无法透传进模拟器 App 进程，
        // 故同时支持在输出目录放置 `.resume` 标志文件触发（确定性，不依赖环境变量传播）。
        let resumeCompleted = ProcessInfo.processInfo.environment["POSITION_EXPORT_RESUME"] == "1"
            || fm.fileExists(atPath: "\(outputDir)/.resume")
        try? fm.createDirectory(atPath: inputDir, withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let jsonFiles = (try? fm.contentsOfDirectory(atPath: inputDir))?
            .filter { $0.lowercased().hasSuffix(".json") }
            .sorted() ?? []
        try XCTSkipIf(jsonFiles.isEmpty,
                      "无输入：把走位序列 JSON 放进 \(inputDir) 后重跑（make position-export）")

        // 与编排台 `PositionPlaySequenceArchive` 编码策略对齐（iso8601 日期）。
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var ok = 0
        var failed: [String] = []
        for file in jsonFiles {
            let inURL = URL(fileURLWithPath: "\(inputDir)/\(file)")
            let baseName = inURL.deletingPathExtension().lastPathComponent
            // 资产键目录：`seq_<id8>-<名称>-<N>杆` → `seq_<id8>`；不合约定的文件名整体作目录名。
            let dirName = baseName.hasPrefix("seq_")
                ? baseName.split(separator: "-").first.map(String.init) ?? baseName
                : baseName
            do {
                let sequence = try decoder.decode(PositionPlaySequence.self,
                                                  from: Data(contentsOf: inURL))
                guard !sequence.steps.isEmpty else {
                    failed.append("\(file)(空序列)")
                    continue
                }

                let outDir = URL(fileURLWithPath: outputDir).appendingPathComponent(dirName)
                if resumeCompleted, exportIsComplete(sequence: sequence, at: outDir) {
                    ok += 1
                    print("SEQ-EXPORT ⏭️ \(dirName)（\(baseName)）：完整产物已存在，续跑跳过")
                    continue
                }
                try? fm.removeItem(at: outDir)
                try fm.createDirectory(at: outDir.appendingPathComponent("preview"),
                                       withIntermediateDirectories: true)

                // 教学静帧（真实风格）：initial / sNN_still / final。
                for (name, image) in SequenceVideoExporter.renderStills(sequence: sequence) {
                    try writePNG(image, to: outDir.appendingPathComponent("\(name).png"))
                }

                // 卡片素材（卡片风格，球放大）：封面 + 动画帧序列。
                if let cover = SequenceVideoExporter.renderCover(sequence: sequence) {
                    try writePNG(cover, to: outDir.appendingPathComponent("cover.png"))
                }
                let previewFrames = try SequenceVideoExporter.renderPreviewFrames(sequence: sequence)
                for (i, frame) in previewFrames.enumerated() {
                    let name = String(format: "preview/frame_%02d.png", i + 1)
                    try writePNG(frame, to: outDir.appendingPathComponent(name))
                }

                // 整段视频 + 分享 GIF（2D 顶视，真实风格）。
                let fullMp4 = try await SequenceVideoExporter.exportVideo(sequence: sequence)
                try moveReplacing(fullMp4, to: outDir.appendingPathComponent("full.mp4"))
                let fullGif = try SequenceVideoExporter.exportGIF(sequence: sequence)
                try moveReplacing(fullGif, to: outDir.appendingPathComponent("full.gif"))

                // 单杆视频（2D 顶视，真实风格）。
                for i in sequence.steps.indices {
                    let sub = SequenceVideoExporter.subSequence(sequence, stepIndex: i)
                    let mp4 = try await SequenceVideoExporter.exportVideo(sequence: sub)
                    let name = String(format: "s%02d.mp4", i + 1)
                    try moveReplacing(mp4, to: outDir.appendingPathComponent(name))
                }

                // 3D 静态斜视角视频（ADR-P11-15，与 2D 并存）：
                // 手机档整段 + 单杆 → App 内竖屏播放；高分档（2160×3840 4K）仅整段 → 外站备用。
                let full3d = try await SequenceVideoExporter.exportVideo(
                    sequence: sequence, options: .teachingVideo3D())
                try moveReplacing(full3d, to: outDir.appendingPathComponent("full_3d.mp4"))
                for i in sequence.steps.indices {
                    let sub = SequenceVideoExporter.subSequence(sequence, stepIndex: i)
                    let mp4 = try await SequenceVideoExporter.exportVideo(
                        sequence: sub, options: .teachingVideo3D())
                    try moveReplacing(mp4, to: outDir.appendingPathComponent(String(format: "s%02d_3d.mp4", i + 1)))
                }
                if exports4K(sequence) {
                    let full3dHi = try await SequenceVideoExporter.exportVideo(
                        sequence: sequence, options: .teachingVideo3DHi())
                    try moveReplacing(full3dHi, to: outDir.appendingPathComponent("full_3d@2160.mp4"))
                }

                ok += 1
                let hi4K = exports4K(sequence) ? "full_3d@2160.mp4" : "（超重序列跳过 4K）"
                print("SEQ-EXPORT ✅ \(dirName)（\(baseName)）：\(sequence.steps.count) 杆 → "
                      + "静帧 \(2 + sequence.steps.count) + cover + preview \(previewFrames.count) 帧 + "
                      + "full.mp4/gif + 单杆 mp4 ×\(sequence.steps.count) + "
                      + "3D full_3d.mp4 + 单杆 3D ×\(sequence.steps.count) + \(hi4K)")
            } catch {
                failed.append("\(file)(\(error.localizedDescription))")
            }
        }

        print("SEQ-EXPORT done: \(ok)/\(jsonFiles.count) → \(outputDir)")
        if !failed.isEmpty { print("SEQ-EXPORT failures: \(failed.joined(separator: ", "))") }
        XCTAssertTrue(failed.isEmpty, "序列出片失败：\(failed.joined(separator: ", "))")
    }

    // MARK: - Helpers

    private func writePNG(_ image: CGImage, to url: URL) throws {
        guard let data = UIImage(cgImage: image).pngData() else {
            throw NSError(domain: "SeqExport", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "PNG 编码失败: \(url.lastPathComponent)"])
        }
        try data.write(to: url)
    }

    private func moveReplacing(_ src: URL, to dst: URL) throws {
        try? FileManager.default.removeItem(at: dst)
        try FileManager.default.moveItem(at: src, to: dst)
    }

    /// 续跑只复用同一次引擎版本生成的完整目录。默认不开启，避免引擎升级后误用旧资产。
    private func exportIsComplete(sequence: PositionPlaySequence, at directory: URL) -> Bool {
        var relativePaths = [
            "cover.png",
            "initial.png",
            "final.png",
            "full.mp4",
            "full.gif",
            "full_3d.mp4"
        ]
        // 超重序列不出 4K，完整性判定亦不要求该文件（否则续跑会永远重渲）。
        if exports4K(sequence) { relativePaths.append("full_3d@2160.mp4") }
        relativePaths += (1...12).map { String(format: "preview/frame_%02d.png", $0) }
        for index in sequence.steps.indices {
            let number = index + 1
            relativePaths += [
                String(format: "s%02d_still.png", number),
                String(format: "s%02d.mp4", number),
                String(format: "s%02d_3d.mp4", number)
            ]
        }

        return relativePaths.allSatisfy { relativePath in
            let url = directory.appendingPathComponent(relativePath)
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]) else {
                return false
            }
            return values.isRegularFile == true && (values.fileSize ?? 0) > 0
        }
    }
}
